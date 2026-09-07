import base64
import fnmatch
import ipaddress
import logging
import os
import tempfile
import time
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional
from urllib.parse import urlparse

import requests
import uvicorn
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse


LOG_LEVEL = os.environ.get("CAD_ADAPTER_LOG_LEVEL", "INFO").upper()
logging.basicConfig(level=getattr(logging, LOG_LEVEL, logging.INFO))
logger = logging.getLogger("cad-adapter")

app = FastAPI(title="Docsie CAD Adapter", version="0.1.0")

MAX_DOWNLOAD_MB = int(os.environ.get("CAD_ADAPTER_MAX_DOWNLOAD_MB", "250"))
MAX_DOWNLOAD_BYTES = MAX_DOWNLOAD_MB * 1024 * 1024
REQUEST_TIMEOUT = int(os.environ.get("CAD_ADAPTER_REQUEST_TIMEOUT", "120"))
API_KEY = os.environ.get("CAD_ADAPTER_API_KEY", "").strip()
ALLOWED_HOSTS = [
    item.strip().lower()
    for item in os.environ.get("CAD_ADAPTER_ALLOWED_HOSTS", "").split(",")
    if item.strip()
]

CAD_FORMAT_ALIASES = {
    "3dm": "3dm",
    "rhino": "3dm",
    "step": "step",
    "stp": "step",
    "iges": "iges",
    "igs": "iges",
    "stl": "stl",
    "obj": "obj",
    "glb": "glb",
    "gltf": "gltf",
    "brep": "brep",
    "fcstd": "fcstd",
}


def module_available(module_name: str) -> bool:
    try:
        __import__(module_name)
        return True
    except Exception:
        return False


def authorize(request: Request) -> None:
    if not API_KEY:
        return
    expected = f"Bearer {API_KEY}"
    if request.headers.get("Authorization", "") != expected:
        raise HTTPException(status_code=401, detail="Invalid CAD adapter token")


def is_url_allowed(url: str) -> bool:
    """Constrain adapter downloads to known CAD/file hosts to limit SSRF risk."""
    parsed = urlparse(url)
    if parsed.scheme not in {"http", "https"}:
        return False
    host = (parsed.hostname or "").lower()
    if not host:
        return False

    try:
        ip = ipaddress.ip_address(host)
        if ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_reserved:
            return False
    except ValueError:
        pass

    if not ALLOWED_HOSTS:
        return True
    return any(host == pattern or fnmatch.fnmatch(host, pattern) for pattern in ALLOWED_HOSTS)


def normalize_format(value: str) -> str:
    normalized = str(value or "").strip().lower().lstrip(".")
    return CAD_FORMAT_ALIASES.get(normalized, normalized)


def detect_format(filename: str, explicit_format: str = "") -> str:
    suffix = Path(filename or "").suffix.lower().lstrip(".")
    generic_labels = {"cad", "model", "binary", "octet-stream"}
    explicit = normalize_format(explicit_format)
    if explicit and explicit not in generic_labels and explicit in CAD_FORMAT_ALIASES.values():
        return explicit
    if suffix:
        return normalize_format(suffix)
    if explicit:
        return explicit
    return normalize_format(suffix)


def safe_url_label(url: str) -> str:
    parsed = urlparse(url)
    if not parsed.scheme or not parsed.netloc:
        return ""
    return f"{parsed.scheme}://{parsed.netloc}{parsed.path}"


def decode_file_base64(value: str) -> bytes:
    raw = str(value or "")
    if raw.startswith("data:"):
        raw = raw.split(",", 1)[1]
    return base64.b64decode(raw)


def write_payload_to_file(payload: bytes, directory: str, filename: str) -> str:
    if len(payload) > MAX_DOWNLOAD_BYTES:
        raise HTTPException(status_code=413, detail=f"CAD file exceeds {MAX_DOWNLOAD_MB} MB limit")
    suffix = Path(filename or "model.cad").suffix or ".cad"
    target = tempfile.NamedTemporaryFile(delete=False, suffix=suffix, dir=directory)
    with target:
        target.write(payload)
    return target.name


def download_to_file(url: str, directory: str, filename: str) -> Dict[str, Any]:
    if not is_url_allowed(url):
        raise HTTPException(status_code=400, detail="CAD file URL host is not allowed")

    headers = {"User-Agent": "DocsieCADAdapter/0.1"}
    with requests.get(url, stream=True, timeout=REQUEST_TIMEOUT, headers=headers) as response:
        response.raise_for_status()
        content_length = int(response.headers.get("Content-Length") or 0)
        if content_length > MAX_DOWNLOAD_BYTES:
            raise HTTPException(status_code=413, detail=f"CAD file exceeds {MAX_DOWNLOAD_MB} MB limit")

        suffix = Path(filename or urlparse(url).path or "model.cad").suffix or ".cad"
        target = tempfile.NamedTemporaryFile(delete=False, suffix=suffix, dir=directory)
        size = 0
        with target:
            for chunk in response.iter_content(chunk_size=1024 * 1024):
                if not chunk:
                    continue
                size += len(chunk)
                if size > MAX_DOWNLOAD_BYTES:
                    raise HTTPException(status_code=413, detail=f"CAD file exceeds {MAX_DOWNLOAD_MB} MB limit")
                target.write(chunk)

    return {
        "path": target.name,
        "size": size,
        "content_type": response.headers.get("Content-Type", ""),
    }


def empty_analysis(fmt: str, warnings: Optional[List[str]] = None) -> Dict[str, Any]:
    return {
        "status": "analyzed",
        "format": fmt,
        "units": "",
        "object_count": 0,
        "bounding_box": None,
        "layers": [],
        "materials": [],
        "objects": [],
        "bom": {
            "status": "unavailable",
            "basis": "",
            "items": [],
            "warnings": [],
        },
        "geometry_stats": {},
        "warnings": warnings or [],
    }


def color_to_hex(color: Any) -> str:
    if color is None:
        return ""
    for attrs in (("R", "G", "B"), ("r", "g", "b")):
        if all(hasattr(color, name) for name in attrs):
            try:
                return "#{:02x}{:02x}{:02x}".format(
                    int(getattr(color, attrs[0])),
                    int(getattr(color, attrs[1])),
                    int(getattr(color, attrs[2])),
                )
            except Exception:
                return ""
    return str(color)


def bbox_from_min_max(min_point: Iterable[float], max_point: Iterable[float]) -> Dict[str, Any]:
    min_values = [float(v) for v in min_point]
    max_values = [float(v) for v in max_point]
    return {
        "min": min_values,
        "max": max_values,
        "size": [max_values[i] - min_values[i] for i in range(3)],
        "center": [(max_values[i] + min_values[i]) / 2.0 for i in range(3)],
    }


def merge_bbox(existing: Optional[Dict[str, Any]], bbox: Optional[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    if not bbox:
        return existing
    if not existing:
        return bbox
    min_values = [min(existing["min"][i], bbox["min"][i]) for i in range(3)]
    max_values = [max(existing["max"][i], bbox["max"][i]) for i in range(3)]
    return bbox_from_min_max(min_values, max_values)


def read_user_strings(*targets: Any) -> Dict[str, str]:
    user_strings: Dict[str, str] = {}
    for target in targets:
        if target is None:
            continue
        try:
            values = target.GetUserStrings()
        except Exception:
            values = None
        if not values:
            continue

        if isinstance(values, dict):
            iterable = values.items()
        else:
            iterable = values

        for item in iterable:
            try:
                if isinstance(item, (list, tuple)) and len(item) >= 2:
                    key, value = item[0], item[1]
                elif hasattr(item, "Key") and hasattr(item, "Value"):
                    key, value = item.Key, item.Value
                elif hasattr(item, "key") and hasattr(item, "value"):
                    key, value = item.key, item.value
                else:
                    continue
                key = str(key or "").strip()
                if key:
                    user_strings[key] = str(value or "").strip()
            except Exception:
                continue
    return user_strings


def merge_type_counts(existing: Dict[str, int], incoming: Dict[str, int]) -> Dict[str, int]:
    for key, value in incoming.items():
        existing[key] = existing.get(key, 0) + int(value or 0)
    return existing


def resolve_maybe_callable(value: Any, default: Any = "") -> Any:
    if callable(value):
        try:
            return value()
        except Exception:
            return default
    return value if value is not None else default


def object_dimensions_label(bbox: Optional[Dict[str, Any]]) -> str:
    if not bbox or not bbox.get("size"):
        return ""
    try:
        return " x ".join(f"{float(value):.3g}" for value in bbox["size"][:3])
    except Exception:
        return ""


def build_candidate_bom(
    objects: List[Dict[str, Any]],
    *,
    materials: Optional[List[Dict[str, Any]]] = None,
) -> Dict[str, Any]:
    material_lookup = {
        item.get("index"): str(item.get("name") or "").strip()
        for item in (materials or [])
        if item.get("index") is not None
    }
    material_lookup.update({
        str(item.get("index")): str(item.get("name") or "").strip()
        for item in (materials or [])
        if item.get("index") is not None
    })

    groups: Dict[str, Dict[str, Any]] = {}
    for obj in objects:
        user_strings = obj.get("user_strings") or {}
        explicit_part = (
            str(user_strings.get("part_number") or user_strings.get("PartNumber") or "").strip()
            or str(user_strings.get("component") or user_strings.get("Component") or "").strip()
            or str(obj.get("name") or "").strip()
        )
        layer_name = str(obj.get("layer_path") or obj.get("layer") or "").strip()
        material_index = obj.get("material_index")
        material_name = (
            str(obj.get("material") or "").strip()
            or material_lookup.get(material_index, "")
            or material_lookup.get(str(material_index), "")
        )
        geometry_type = str(obj.get("type") or "Unknown").strip() or "Unknown"

        if explicit_part:
            identity = explicit_part
            source = "object_name"
            confidence = 0.78
        elif layer_name:
            identity = layer_name
            source = "layer"
            confidence = 0.58
        else:
            identity = geometry_type
            source = "geometry_type"
            confidence = 0.25

        key = "|".join([source, identity.lower(), material_name.lower(), geometry_type])
        if key not in groups:
            groups[key] = {
                "source": source,
                "part_number": identity,
                "description": identity,
                "layer": layer_name,
                "material": material_name,
                "quantity": 0,
                "object_count": 0,
                "geometry_type_counts": {},
                "bbox": None,
                "confidence": confidence,
                "notes": [],
            }

        group = groups[key]
        group["quantity"] += 1
        group["object_count"] += 1
        merge_type_counts(group["geometry_type_counts"], {geometry_type: 1})
        group["bbox"] = merge_bbox(group.get("bbox"), obj.get("bbox"))
        if obj.get("name") and obj.get("name") != group["part_number"]:
            note = f"Object: {obj.get('name')}"
            if note not in group["notes"] and len(group["notes"]) < 5:
                group["notes"].append(note)

    items = []
    sorted_groups = sorted(groups.values(), key=lambda item: (item["source"], item["part_number"]))
    for index, group in enumerate(sorted_groups, start=1):
        type_counts = ", ".join(
            f"{name} x{count}" for name, count in sorted(group["geometry_type_counts"].items())
        )
        description = group["description"]
        if type_counts:
            description = f"{description} ({type_counts})"
        item = {
            "item_no": index,
            "part_number": group["part_number"],
            "description": description,
            "quantity": group["quantity"],
            "material": group["material"],
            "layer": group["layer"],
            "dimensions": object_dimensions_label(group.get("bbox")),
            "bbox": group.get("bbox"),
            "source": group["source"],
            "confidence": group["confidence"],
            "notes": group["notes"],
        }
        if group["source"] in {"layer", "geometry_type"}:
            item["notes"].append("Quantity is object count, not confirmed manufacturing quantity.")
        if not group["material"]:
            item["notes"].append("No explicit material assignment found.")
        items.append(item)

    warnings = []
    if not items:
        warnings.append("No CAD objects were available for BOM grouping.")
    if any(item["source"] == "layer" for item in items):
        warnings.append(
            "Some BOM rows are grouped by Rhino layer because object names or block/component names were missing."
        )
    if any(not item.get("material") for item in items):
        warnings.append("Some rows have no explicit material; join with the CRD/PDF BOM or a material glossary.")

    return {
        "status": "candidate" if items else "unavailable",
        "basis": "Grouped by object name when present, otherwise Rhino layer, otherwise geometry type.",
        "items": items,
        "warnings": warnings,
    }


def safe_len(value: Any) -> int:
    try:
        return int(len(value))
    except Exception:
        return 0


def rhino_bbox(geometry: Any) -> Optional[Dict[str, Any]]:
    if geometry is None or not hasattr(geometry, "GetBoundingBox"):
        return None
    bbox = None
    for args in ((True,), tuple()):
        try:
            bbox = geometry.GetBoundingBox(*args)
            break
        except Exception:
            continue
    if not bbox:
        return None
    try:
        min_point = bbox.Min
        max_point = bbox.Max
        return bbox_from_min_max(
            [min_point.X, min_point.Y, min_point.Z],
            [max_point.X, max_point.Y, max_point.Z],
        )
    except Exception:
        return None


def analyze_3dm(path: str, fmt: str) -> Dict[str, Any]:
    result = empty_analysis(fmt)
    try:
        import rhino3dm
    except Exception as exc:
        result["status"] = "unsupported"
        result["warnings"].append(f"rhino3dm is not available: {exc}")
        return result

    model = rhino3dm.File3dm.Read(path)
    if not model:
        result["status"] = "error"
        result["warnings"].append("rhino3dm could not read the 3DM file")
        return result

    try:
        result["units"] = str(model.Settings.ModelUnitSystem)
    except Exception:
        pass

    layers = []
    layer_lookup = {}
    for layer in list(model.Layers):
        layer_index = getattr(layer, "Index", None)
        layer_name = getattr(layer, "Name", "") or ""
        layer_path = resolve_maybe_callable(
            getattr(layer, "FullPath", None) or getattr(layer, "FullPathName", None),
            layer_name,
        ) or layer_name
        item = {
            "index": layer_index,
            "name": layer_name,
            "path": layer_path,
            "visible": bool(getattr(layer, "IsVisible", True)),
            "color": color_to_hex(getattr(layer, "Color", None)),
            "material_index": (
                getattr(layer, "RenderMaterialIndex", None)
                if getattr(layer, "RenderMaterialIndex", None) is not None
                else getattr(layer, "MaterialIndex", None)
            ),
        }
        layers.append(item)
        if item["index"] is not None:
            layer_lookup[item["index"]] = item
    result["layers"] = layers

    materials = []
    material_lookup = {}
    for material in list(model.Materials):
        item = {
            "index": getattr(material, "Index", None),
            "name": getattr(material, "Name", "") or "",
            "diffuse_color": color_to_hex(getattr(material, "DiffuseColor", None)),
        }
        materials.append(item)
        if item["index"] is not None:
            material_lookup[item["index"]] = item
    result["materials"] = materials

    objects = []
    bom_objects = []
    object_type_counts: Dict[str, int] = {}
    overall_bbox = None
    for item in list(model.Objects):
        geometry = getattr(item, "Geometry", None)
        attrs = getattr(item, "Attributes", None)
        object_type = type(geometry).__name__ if geometry is not None else "Unknown"
        object_type_counts[object_type] = object_type_counts.get(object_type, 0) + 1

        layer_index = getattr(attrs, "LayerIndex", None) if attrs else None
        layer_item = layer_lookup.get(layer_index, {})
        material_index = getattr(attrs, "MaterialIndex", None) if attrs else None
        if material_index in (None, -1):
            material_index = layer_item.get("material_index")
        material_item = material_lookup.get(material_index, {})
        group_ids = []
        if attrs and hasattr(attrs, "GetGroupList"):
            try:
                group_ids = list(attrs.GetGroupList() or [])
            except Exception:
                group_ids = []
        bbox = rhino_bbox(geometry)
        overall_bbox = merge_bbox(overall_bbox, bbox)
        object_record = {
            "id": str(getattr(attrs, "Id", "") or "") if attrs else "",
            "name": getattr(attrs, "Name", "") if attrs else "",
            "type": object_type,
            "layer_index": layer_index,
            "layer": layer_item.get("name", ""),
            "layer_path": layer_item.get("path", ""),
            "material_index": material_index,
            "material": material_item.get("name", ""),
            "material_source": str(getattr(attrs, "MaterialSource", "") or "") if attrs else "",
            "groups": group_ids,
            "user_strings": read_user_strings(item, attrs, geometry),
            "bbox": bbox,
        }
        bom_objects.append(object_record)
        if len(objects) < 250:
            objects.append(object_record)

    result["object_count"] = sum(object_type_counts.values())
    result["objects"] = objects
    result["bounding_box"] = overall_bbox
    result["geometry_stats"]["object_types"] = object_type_counts
    result["bom"] = build_candidate_bom(bom_objects, materials=materials)
    return result


def freecad_bbox(bound_box: Any) -> Optional[Dict[str, Any]]:
    if not bound_box:
        return None
    try:
        return bbox_from_min_max(
            [bound_box.XMin, bound_box.YMin, bound_box.ZMin],
            [bound_box.XMax, bound_box.YMax, bound_box.ZMax],
        )
    except Exception:
        return None


def analyze_with_freecad(path: str, fmt: str) -> Dict[str, Any]:
    result = empty_analysis(fmt)
    try:
        import FreeCAD
        import Import
    except Exception as exc:
        result["status"] = "unsupported"
        result["warnings"].append(f"FreeCAD/Open CASCADE is not available: {exc}")
        return result

    doc = None
    try:
        doc_name = f"DocsieCadAnalysis_{int(time.time() * 1000)}"
        doc = FreeCAD.newDocument(doc_name)
        Import.insert(path, doc.Name)
        doc.recompute()
        objects = []
        overall_bbox = None
        total_volume = 0.0
        total_area = 0.0

        for obj in list(doc.Objects):
            shape = getattr(obj, "Shape", None)
            bbox = freecad_bbox(getattr(shape, "BoundBox", None)) if shape else None
            overall_bbox = merge_bbox(overall_bbox, bbox)
            try:
                total_volume += float(getattr(shape, "Volume", 0.0) or 0.0)
                total_area += float(getattr(shape, "Area", 0.0) or 0.0)
            except Exception:
                pass
            if len(objects) < 250:
                objects.append({
                    "name": getattr(obj, "Label", "") or getattr(obj, "Name", ""),
                    "type": getattr(obj, "TypeId", type(obj).__name__),
                    "bbox": bbox,
                })

        result["object_count"] = len(doc.Objects)
        result["objects"] = objects
        result["bounding_box"] = overall_bbox
        result["geometry_stats"] = {
            "total_volume": total_volume,
            "total_area": total_area,
        }
        result["bom"] = build_candidate_bom(objects)
        return result
    except Exception as exc:
        result["status"] = "error"
        result["warnings"].append(f"FreeCAD analysis failed: {exc}")
        return result
    finally:
        if doc is not None:
            try:
                FreeCAD.closeDocument(doc.Name)
            except Exception:
                pass


def analyze_mesh_with_trimesh(path: str, fmt: str) -> Dict[str, Any]:
    result = empty_analysis(fmt)
    try:
        import trimesh
    except Exception as exc:
        result["status"] = "unsupported"
        result["warnings"].append(f"trimesh is not available: {exc}")
        return result

    try:
        loaded = trimesh.load(path, force="scene")
        geometries = []
        if hasattr(loaded, "geometry"):
            geometries = list(loaded.geometry.values())
        elif loaded is not None:
            geometries = [loaded]

        overall_bbox = None
        total_vertices = 0
        total_faces = 0
        objects = []
        for index, mesh in enumerate(geometries):
            bounds = getattr(mesh, "bounds", None)
            bbox = None
            if bounds is not None and len(bounds) == 2:
                bbox = bbox_from_min_max(bounds[0], bounds[1])
            overall_bbox = merge_bbox(overall_bbox, bbox)
            total_vertices += safe_len(getattr(mesh, "vertices", []))
            total_faces += safe_len(getattr(mesh, "faces", []))
            if len(objects) < 250:
                objects.append({
                    "name": getattr(mesh, "metadata", {}).get("name", f"mesh_{index}"),
                    "type": type(mesh).__name__,
                    "bbox": bbox,
                })

        result["object_count"] = len(geometries)
        result["objects"] = objects
        result["bounding_box"] = overall_bbox
        result["geometry_stats"] = {
            "vertices": total_vertices,
            "faces": total_faces,
        }
        result["bom"] = build_candidate_bom(objects)
        return result
    except Exception as exc:
        result["status"] = "error"
        result["warnings"].append(f"Mesh analysis failed: {exc}")
        return result


def build_summary(result: Dict[str, Any]) -> str:
    parts = [f"{result.get('format', 'CAD').upper()} file"]
    object_count = result.get("object_count")
    if object_count is not None:
        parts.append(f"{object_count} objects")
    if result.get("layers"):
        parts.append(f"{len(result['layers'])} layers")
    if result.get("materials"):
        parts.append(f"{len(result['materials'])} materials")
    bbox = result.get("bounding_box") or {}
    size = bbox.get("size")
    if size:
        parts.append("bounding box {:.3g} x {:.3g} x {:.3g}".format(*size))
    return ", ".join(parts)


def analyze_file(path: str, fmt: str) -> Dict[str, Any]:
    if fmt == "3dm":
        result = analyze_3dm(path, fmt)
    elif fmt in {"step", "iges", "brep", "fcstd"}:
        result = analyze_with_freecad(path, fmt)
    elif fmt in {"stl", "obj", "glb", "gltf"}:
        result = analyze_mesh_with_trimesh(path, fmt)
    else:
        result = empty_analysis(fmt, warnings=[f"Format '{fmt}' is accepted but no analyzer is configured"])
        result["status"] = "unsupported"

    result["summary"] = build_summary(result)
    return result


@app.get("/health")
def health() -> Dict[str, Any]:
    return {
        "status": "ok",
        "runtime": {
            "rhino3dm": module_available("rhino3dm"),
            "freecad": module_available("FreeCAD"),
            "trimesh": module_available("trimesh"),
        },
    }


@app.post("/v1/analyze")
async def analyze(request: Request) -> JSONResponse:
    authorize(request)
    body = await request.json()
    file_url = str(body.get("file_url") or "").strip()
    file_base64 = str(body.get("file_base64") or "").strip()
    file_id = str(body.get("file_id") or "").strip()
    filename = str(body.get("filename") or "").strip()
    explicit_format = str(body.get("format") or "").strip()

    if not file_url and not file_base64:
        raise HTTPException(status_code=400, detail="file_url or file_base64 is required")

    if not filename and file_url:
        filename = Path(urlparse(file_url).path).name
    fmt = detect_format(filename, explicit_format)
    if not fmt:
        raise HTTPException(status_code=400, detail="CAD format could not be detected")

    with tempfile.TemporaryDirectory(prefix="docsie-cad-") as tmp_dir:
        if file_base64:
            payload = decode_file_base64(file_base64)
            file_path = write_payload_to_file(payload, tmp_dir, filename or f"model.{fmt}")
            size = len(payload)
            content_type = ""
        else:
            downloaded = download_to_file(file_url, tmp_dir, filename or f"model.{fmt}")
            file_path = downloaded["path"]
            size = downloaded["size"]
            content_type = downloaded["content_type"]

        result = analyze_file(file_path, fmt)
        result["input"] = {
            "file_id": file_id,
            "filename": filename or Path(file_path).name,
            "size": size,
            "content_type": content_type,
            "source_url": safe_url_label(file_url),
        }
        return JSONResponse(result)


if __name__ == "__main__":
    port = int(os.environ.get("CAD_ADAPTER_PORT", "5003"))
    host = os.environ.get("CAD_ADAPTER_HOST", "0.0.0.0")
    uvicorn.run(app, host=host, port=port)
