"""Smoke HTTP real, restrito ao loopback da VM e sem credenciais Jira/AWS."""

import argparse
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time
import urllib.request
from urllib.parse import urlsplit


def probe(url, version):
    parsed = urlsplit(url)
    if (
        parsed.scheme != "http"
        or parsed.hostname != "127.0.0.1"
        or not parsed.port
        or parsed.path
        or parsed.query
        or parsed.fragment
        or parsed.username
    ):
        raise ValueError("Somente HTTP em 127.0.0.1 com porta explícita")
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    for endpoint, expected in (
        ("health", {"status": "ok", "version": version}),
        ("ready", {"ready": True}),
        ("", {"message": "hello from sample-api", "version": version}),
    ):
        with opener.open(f"{url}/{endpoint}", timeout=5) as response:
            if response.status != 200 or json.load(response) != expected:
                raise RuntimeError(f"Resposta inesperada: {endpoint}")
    with opener.open(f"{url}/metrics", timeout=5) as response:
        if response.status != 200 or b"sample_api_ready" not in response.read():
            raise RuntimeError("Métricas ausentes")
    print(
        json.dumps(
            {
                "url": url,
                "version": version,
                "health": True,
                "ready": True,
                "root": True,
                "metrics": True,
            }
        )
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url")
    parser.add_argument("--version", required=True)
    args = parser.parse_args()
    if args.url:
        probe(args.url, args.version)
        return
    environment = {
        k: v
        for k, v in os.environ.items()
        if not k.startswith(("AWS_", "GH_", "GITHUB_"))
    }
    environment.update(APP_VERSION=args.version, FAILURE_RATE="0")
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        sock.listen()
        port = sock.getsockname()[1]
        process = subprocess.Popen(
            [sys.executable, "-m", "uvicorn", "main:app", "--fd", str(sock.fileno())],
            cwd=Path(__file__).resolve().parents[2] / "apps/sample-api/app",
            env=environment,
            pass_fds=(sock.fileno(),),
        )
        try:
            for _ in range(60):
                if process.poll() is not None:
                    raise RuntimeError("API encerrou antes do smoke")
                try:
                    probe(f"http://127.0.0.1:{port}", args.version)
                    break
                except (OSError, ValueError, RuntimeError):
                    time.sleep(0.25)
            else:
                raise RuntimeError("Timeout no smoke")
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)


if __name__ == "__main__":
    main()
