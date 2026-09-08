"""Render real charts to catch installer/chart integration errors without AWS."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("render_values", ROOT / "installers/aws/render-values.py")
renderer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(renderer)


class DistributionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        subprocess.run(["helm", "dependency", "build", str(ROOT / "charts/docsie-platform"), "--skip-refresh"],
                       check=True, capture_output=True)

    def render(self, values):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json") as handle:
            json.dump(values, handle)
            handle.flush()
            result = subprocess.run([
                "helm", "template", "docsie", str(ROOT / "charts/docsie-platform"),
                "--namespace", "customer-space", "-f", handle.name,
            ], check=True, capture_output=True, text=True)
        return [doc for doc in yaml.safe_load_all(result.stdout) if doc]

    def test_install_profiles_enable_enterprise_mode_for_all_docsie_processes(self):
        cases = {
            "kb": {},
            "kb-ai": {"profiles": {"kbAi": True}},
            "full": {"profiles": {"full": True}},
            "aws": self.aws_values(),
        }
        for profile, values in cases.items():
            with self.subTest(profile=profile):
                values["bootstrap"] = {"enabled": True, "adminEmail": "admin@example.test"}
                docs = self.render(values)
                web = next(d for d in docs if d["kind"] == "Deployment"
                           and d["metadata"]["name"] == "docsie-web")
                app_image = web["spec"]["template"]["spec"]["containers"][0]["image"]
                checked = set()
                for resource in docs:
                    if resource["kind"] not in {"Deployment", "StatefulSet", "Job"}:
                        continue
                    for container in resource["spec"]["template"]["spec"]["containers"]:
                        if container["image"] != app_image:
                            continue
                        name = resource["metadata"]["name"]
                        checked.add(name)
                        for key, expected in (("ENTERPRISE_MODE", "true"),
                                              ("DJANGO_SETTINGS_MODULE", "config.settings.onprem")):
                            entries = [e for e in container.get("env", []) if e["name"] == key]
                            self.assertEqual(len(entries), 1, (profile, name, key))
                            self.assertEqual(entries[0].get("value"), expected, (profile, name, key))
                self.assertTrue({"docsie-web", "docsie-migrate", "docsie-bootstrap-admin"} <= checked)
                self.assertTrue(any("celery" in name for name in checked), checked)

    def test_local_install_jobs_and_workloads_share_runtime_contract(self):
        values = yaml.safe_load((ROOT / "examples/local-rehearsal.yaml").read_text())
        docs = self.render(values)
        workloads = [d for d in docs if d["kind"] in {"Deployment", "StatefulSet", "Job"}]
        for workload in workloads:
            self.assertFalse(workload["spec"]["template"]["spec"].get("enableServiceLinks", True),
                             workload["metadata"]["name"])
        jobs = {d["metadata"]["name"]: d for d in docs if d["kind"] == "Job"}
        migration = jobs["docsie-migrate"]
        self.assertEqual(migration["metadata"]["annotations"]["helm.sh/hook"], "post-install,post-upgrade")
        bootstrap = jobs["docsie-bootstrap-admin"]
        self.assertLess(int(migration["metadata"]["annotations"]["helm.sh/hook-weight"]),
                        int(bootstrap["metadata"]["annotations"]["helm.sh/hook-weight"]))
        web = next(d for d in docs if d["kind"] == "Deployment" and d["metadata"]["name"] == "docsie-web")
        app = web["spec"]["template"]["spec"]["containers"][0]
        for job in (migration, bootstrap):
            runtime = job["spec"]["template"]["spec"]["containers"][0]
            self.assertEqual(runtime["image"], app["image"])
            self.assertEqual(runtime["envFrom"], app["envFrom"])

    def test_full_profile_wires_dokuta_service_auth_and_bootstrap(self):
        docs = self.render({"profiles": {"full": True}})
        resources = {(d["kind"], d["metadata"]["name"]): d for d in docs}
        for name in ("dokuta", "dokuta-fastapi", "dokuta-celery", "collaboration-relay", "dokuta-pptx-renderer"):
            self.assertIn(("Deployment", name), resources)
        primary = resources[("Secret", "docsie-platform-secrets")]["stringData"]
        derived = resources[("Secret", "docsie-platform-derived")]["stringData"]
        self.assertEqual(derived["DOKUTA_API_KEY"], primary["DOKUTA_SERVICE_API_KEY"])
        self.assertEqual(derived["DOKUTA_API_URL"], "http://dokuta-fastapi:8880/api/v1")
        job = resources[("Job", "docsie-dokuta-bootstrap")]
        self.assertEqual(job["metadata"]["annotations"]["helm.sh/hook-weight"], "15")
        container = job["spec"]["template"]["spec"]["containers"][0]
        api = resources[("Deployment", "dokuta-fastapi")]["spec"]["template"]["spec"]
        self.assertEqual(container["image"], api["containers"][0]["image"])
        self.assertFalse(api["enableServiceLinks"])
        secrets = {d["metadata"]["name"]: set(d.get("stringData", {})) | set(d.get("data", {}))
                   for d in docs if d["kind"] == "Secret"}
        for name in ("dokuta", "dokuta-fastapi", "dokuta-celery"):
            for app in resources[("Deployment", name)]["spec"]["template"]["spec"]["containers"]:
                for env in app.get("env", []):
                    ref = env.get("valueFrom", {}).get("secretKeyRef", {})
                    if ref and not ref.get("optional"):
                        self.assertIn(ref["key"], secrets[ref["name"]], (name, env["name"]))
        key = next(e for e in container["env"] if e["name"] == "DOKUTA_SERVICE_API_KEY")
        self.assertEqual(key["valueFrom"]["secretKeyRef"],
                         {"name": "docsie-platform-secrets", "key": "DOKUTA_SERVICE_API_KEY"})

    def test_baseline_packages_and_wires_authenticated_app_search(self):
        docs = self.render({})
        resources = {(d['kind'], d['metadata']['name']): d for d in docs}
        self.assertIn(('EnterpriseSearch', 'production'), resources)
        self.assertIn(('Elasticsearch', 'production'), resources)
        bootstrap = resources[('Job', 'docsie-appsearch-bootstrap-1')]
        self.assertNotIn('helm.sh/hook', bootstrap['metadata'].get('annotations', {}))
        app = resources[('Deployment', 'docsie-web')]['spec']['template']['spec']
        env = {item['name']: item for item in app['containers'][0]['env']}
        self.assertEqual(env['APPSEARCH_HOST']['value'], 'production-ent-http:3002/api/as/v1')
        self.assertEqual(env['APPSEARCH_VERIFY_CERTS']['value'], 'true')
        for name in ('APPSEARCH_KEY', 'APPSEARCH_SEARCH_KEY'):
            self.assertEqual(env[name]['valueFrom']['secretKeyRef']['name'], 'docsie-appsearch-runtime')
        ca = next(volume for volume in app['volumes'] if volume['name'] == 'appsearch-ca')
        self.assertEqual(ca['secret']['secretName'], 'production-ent-http-certs-public')
        self.assertIn(('Pod', 'docsie-search-test'), resources)

    def test_external_search_has_no_local_search_dependencies(self):
        docs = self.render({'global': {'appSearch': {'enabled': False}}})
        self.assertFalse(any(doc['kind'] == 'EnterpriseSearch' for doc in docs))
        web = next(doc for doc in docs if doc['kind'] == 'Deployment' and doc['metadata']['name'] == 'docsie-web')
        pod = web['spec']['template']['spec']
        self.assertFalse(any(volume['name'] == 'appsearch-ca' for volume in pod.get('volumes', [])))
        self.assertFalse(any(entry['name'] == 'APPSEARCH_KEY' for entry in pod['containers'][0]['env']))

    def test_full_profile_mounts_the_claim_it_creates(self):
        docs = self.render({'profiles': {'full': True}})
        deployment = next(d for d in docs if d['kind'] == 'Deployment' and d['metadata']['name'] == 'chromadb')
        pod = deployment['spec']['template']['spec']
        claim = next(v for v in pod['volumes'] if v['name'] == 'chroma-data')['persistentVolumeClaim']['claimName']
        self.assertTrue(any(d['kind'] == 'PersistentVolumeClaim' and d['metadata']['name'] == claim for d in docs))
        mount = next(v for v in pod['containers'][0]['volumeMounts'] if v['name'] == 'chroma-data')
        self.assertEqual(mount['mountPath'], '/chroma/chroma')

    def aws_values(self, public=False):
        outputs = {
            "docsie_domain": {"value": "docs.example.test"},
            "workload_irsa_role_arn": {"value": "arn:aws:iam::123456789012:role/docsie-preview"},
            "public_ingress": {"value": public},
        }
        return renderer.render(outputs, "customer-registry")

    def test_aws_uses_managed_services_and_only_external_credentials(self):
        docs = self.render(self.aws_values())
        self.assertFalse(any(d["kind"] == "Secret" and d["metadata"]["name"].startswith("docsie-platform") for d in docs))
        statefulsets = [d["metadata"]["name"] for d in docs if d["kind"] == "StatefulSet"]
        self.assertNotIn("postgresql", statefulsets)
        self.assertNotIn("redis", statefulsets)
        self.assertNotIn("minio", statefulsets)
        self.assertIn("elasticsearch", statefulsets)
        web = next(d for d in docs if d["kind"] == "Deployment" and d["metadata"]["name"] == "docsie-web")
        pod = web["spec"]["template"]["spec"]
        app = pod["containers"][0]
        self.assertEqual(app["envFrom"], [{"secretRef": {"name": "docsie-secret"}}])
        env = {entry["name"]: entry.get("value") for entry in app["env"]}
        self.assertNotIn("REDIS_ENDPOINT", env)
        self.assertNotIn("DJANGO_AWS_S3_ENDPOINT_URL", env)
        self.assertEqual(env["APP_BASE_URL"], "http://docs.example.test")
        self.assertEqual(env["DJANGO_SETTINGS_MODULE"], "config.settings.onprem")
        self.assertIn("@sha256:", app["image"])
        self.assertEqual(pod["serviceAccountName"], "docsie")
        self.assertEqual(pod["imagePullSecrets"], [{"name": "customer-registry"}])
        for workload in docs:
            if workload["kind"] == "Deployment":
                self.assertEqual(workload["spec"]["template"]["spec"]["imagePullSecrets"],
                                 [{"name": "customer-registry"}])
                if workload['metadata']['name'] in {'image-processor', 'pdf-converter'}:
                    pod = workload['spec']['template']['spec']
                    self.assertEqual(pod['serviceAccountName'], 'docsie')
                    for container in pod['containers']:
                        for entry in container.get('env', []):
                            self.assertNotIn('secretKeyRef', entry.get('valueFrom', {}))
                            self.assertNotEqual(entry.get('value'), 'http://minio:9000')

    def test_private_aws_ingress_stays_private(self):
        docs = self.render(self.aws_values())
        ingress = next(d for d in docs if d["kind"] == "Ingress")
        self.assertEqual(ingress["metadata"]["annotations"]["alb.ingress.kubernetes.io/scheme"], "internal")

    def test_local_stores_share_generated_credentials(self):
        docs = self.render({"global": {"hostname": "local.example.test"}})
        primary = next(d for d in docs if d["kind"] == "Secret" and d["metadata"]["name"] == "docsie-platform-secrets")
        derived = next(d for d in docs if d["kind"] == "Secret" and d["metadata"]["name"] == "docsie-platform-derived")
        self.assertIn(primary["stringData"]["POSTGRES_PASSWORD"], derived["stringData"]["DATABASE_URL"])
        self.assertIn(primary["stringData"]["REDIS_PASSWORD"], derived["stringData"]["CELERY_BROKER_URL"])
        names = [d["metadata"]["name"] for d in docs if d["kind"] == "StatefulSet"]
        for name in ("postgresql", "redis", "minio"):
            self.assertIn(name, names)

    def test_profiles_render(self):
        for profiles in ({"kb": True}, {"kb": True, "kbAi": True}, {"kb": True, "kbAi": True, "full": True}):
            with self.subTest(profiles=profiles):
                self.assertTrue(self.render({"profiles": profiles}))

    def test_invalid_outputs_fail_before_install(self):
        with self.assertRaises(ValueError):
            renderer.render({})
        with self.assertRaises(ValueError):
            renderer.render({"docsie_domain": {"value": "example.test\nmalicious: true"}})


if __name__ == "__main__":
    unittest.main()
