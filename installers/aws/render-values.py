#!/usr/bin/env python3
"""Translate non-secret Terraform outputs into the platform chart's exact schema."""
import argparse
import json
import re
import sys


def render(outputs, pull_secret="", certificate_arn=""):
    def value(key):
        result = outputs.get(key, {}).get("value")
        if not isinstance(result, str) or not result:
            raise ValueError(f"Missing Terraform output: {key}")
        return result

    hostname = value("docsie_domain")
    if not re.fullmatch(r"[a-zA-Z0-9](?:[a-zA-Z0-9.-]*[a-zA-Z0-9])?", hostname):
        raise ValueError("docsie_domain must be a hostname, without scheme, path or port")
    role = value("workload_irsa_role_arn")
    if not re.fullmatch(r"arn:[a-z-]+:iam::\d{12}:role/[\w+=,.@/-]+", role):
        raise ValueError("Invalid workload IRSA role ARN")
    public = outputs.get("public_ingress", {}).get("value", False)
    annotations = {
        "alb.ingress.kubernetes.io/scheme": "internet-facing" if public else "internal",
        "alb.ingress.kubernetes.io/target-type": "ip",
        "alb.ingress.kubernetes.io/listen-ports": '[{"HTTP":80}]',
        "alb.ingress.kubernetes.io/healthcheck-path": "/onboarding/v3/login/",
        "alb.ingress.kubernetes.io/success-codes": "200-399",
    }
    if certificate_arn:
        if not re.fullmatch(r"arn:[a-z-]+:acm:[a-z0-9-]+:\d{12}:certificate/[a-f0-9-]+", certificate_arn):
            raise ValueError("Invalid ACM certificate ARN")
        annotations.update({
            "alb.ingress.kubernetes.io/certificate-arn": certificate_arn,
            "alb.ingress.kubernetes.io/listen-ports": '[{"HTTP":80},{"HTTPS":443}]',
            "alb.ingress.kubernetes.io/ssl-redirect": "443",
        })
    app = {
        "manualSecret": {"name": "docsie-secret", "generate": {"enabled": False}},
        "workload": {"extraEnvFrom": []},
        "plainEnv": {
            # null removes local defaults during Helm values coalescing. AWS
            # settings arrive exclusively from the ExternalSecret, preserving IRSA.
            "DJANGO_AWS_S3_ENDPOINT_URL": None,
            "REDIS_ENDPOINT": None,
        },
        "serviceAccount": {
            "create": True, "name": "docsie", "automount": True,
            "annotations": {"eks.amazonaws.com/role-arn": role},
        },
        "ingress": {
            "enabled": True, "className": "alb", "annotations": annotations,
            "hosts": [{"host": hostname, "paths": [{"path": "/", "pathType": "Prefix"}]}],
        },
    }
    for key in (
        "DJANGO_AWS_STORAGE_BUCKET_NAME", "DJANGO_AWS_UPLOAD_BUCKET_NAME",
        "DJANGO_AWS_IMAGE_CONVERTER_BUCKET_NAME", "DJANGO_AWS_TEMP_BUCKET_NAME",
        "DJANGO_AWS_FEEDBACK_BUCKET_NAME", "DJANGO_AWS_PORTAL_BUCKET_NAME",
        "DOCSIE_CDN_BUCKET_NAME", "DJANGO_AWS_S3_REGION_NAME",
        "DJANGO_AWS_S3_ADDRESSING_STYLE", "REDIS_PORT",
    ):
        app["plainEnv"][key] = None
    for component in ("web", "celery", "celeryBackground", "celerySsr", "celeryRewrite", "celeryBeat"):
        app[component] = {"nodeSelector": {"workload": "docsie-core"}}
    result = {
        "global": {
            "selfHosted": True, "hostname": hostname,
            "scheme": "https" if certificate_arn else "http",
            "secretProvider": "manual", "imagePullSecret": pull_secret,
            "imagePullSecrets": [{"name": pull_secret}] if pull_secret else [],
        },
        "storage": {"mode": "managed", **{k: {"enabled": False} for k in ("postgresql", "redis", "minio")}},
        "profiles": {"kb": True, "kbAi": False, "full": False},
        "docsie": app,
    }
    region = outputs.get("aws_region", {}).get("value", "us-east-1")
    buckets = outputs.get("s3_buckets", {}).get("value", {})
    for component in ("image-processor", "pdf-converter"):
        result[component] = {
            "serviceAccountName": "docsie", "secretEnv": None,
            "env": {"S3_ENDPOINT_URL": "", "S3_REGION": region},
        }
    if buckets.get("uploads"):
        result["image-processor"]["env"]["SOURCE_BUCKET"] = buckets["uploads"]
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pull-secret", default="")
    parser.add_argument("--certificate-arn", default="")
    args = parser.parse_args()
    try:
        print(json.dumps(render(json.load(sys.stdin), args.pull_secret, args.certificate_arn), indent=2))
    except (ValueError, KeyError, TypeError) as error:
        parser.exit(2, f"Cannot render AWS values: {error}\n")
