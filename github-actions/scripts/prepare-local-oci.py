"""Prepare layout OCI sem extrair o filesystem das camadas no host."""

import argparse
import hashlib
import gzip
import json
from pathlib import Path
import re
import shutil
import tarfile


def prepare(archive, destination, architecture, expected_config):
    destination = Path(destination)
    destination.mkdir()
    seen = set()
    with tarfile.open(archive, "r:") as source:
        for member in source:
            name = member.name.removeprefix("./").rstrip("/")
            if member.isdir() and name in {"", ".", "blobs", "blobs/sha256"}:
                continue
            if (
                not member.isfile()
                or name in seen
                or not (
                    name in {"index.json", "oci-layout"}
                    or re.fullmatch(r"blobs/sha256/[a-f0-9]{64}", name)
                )
            ):
                raise ValueError(f"Entrada externa OCI inválida: {name}")
            seen.add(name)
            target = destination / name
            target.parent.mkdir(parents=True, exist_ok=True)
            with source.extractfile(member) as content, target.open("xb") as output:
                shutil.copyfileobj(content, output)
            if name.startswith("blobs/"):
                with target.open("rb") as content:
                    actual = hashlib.file_digest(content, "sha256").hexdigest()
                if actual != target.name:
                    raise ValueError("Hash de blob OCI divergente")

    def read_blob(entry):
        algorithm, digest = entry["digest"].split(":", 1)
        if algorithm != "sha256" or not re.fullmatch(r"[a-f0-9]{64}", digest):
            raise ValueError("Digest OCI inválido")
        path = destination / "blobs" / algorithm / digest
        if path.stat().st_size != entry["size"]:
            raise ValueError("Tamanho do blob OCI divergente")
        return json.loads(path.read_text())

    index = json.loads((destination / "index.json").read_text())
    if json.loads((destination / "oci-layout").read_text()) != {
        "imageLayoutVersion": "1.0.0"
    }:
        raise ValueError("Versão do layout OCI inesperada")
    manifests = index["manifests"]
    if (
        len(manifests) == 1
        and manifests[0]["mediaType"] == "application/vnd.oci.image.index.v1+json"
    ):
        manifests = read_blob(manifests[0])["manifests"]
    if (
        len(manifests) != 1
        or manifests[0]["mediaType"] != "application/vnd.oci.image.manifest.v1+json"
    ):
        raise ValueError("Esperada uma única imagem OCI")
    images = manifests
    manifest = read_blob(images[0])
    if manifest["config"]["digest"] != expected_config:
        raise ValueError("Configuração OCI não corresponde à imagem puxada por digest")
    config = read_blob(manifest["config"])
    settings = config["config"]
    if (
        (config["os"], config["architecture"]) != ("linux", architecture)
        or settings.get("User") != "10001:10001"
        or settings.get("WorkingDir") != "/app"
        or settings.get("Cmd")
        != ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
    ):
        raise ValueError("Contrato de execução OCI divergente")
    layers = manifest["layers"]
    if len(layers) != len(config["rootfs"]["diff_ids"]):
        raise ValueError("Inventário de camadas OCI incompleto")
    for layer, diff_id in zip(layers, config["rootfs"]["diff_ids"], strict=True):
        algorithm, digest = layer["digest"].split(":", 1)
        if algorithm != "sha256" or not re.fullmatch(r"[a-f0-9]{64}", digest):
            raise ValueError("Digest de camada inválido")
        path = destination / "blobs" / algorithm / digest
        if path.stat().st_size != layer["size"]:
            raise ValueError("Tamanho de camada divergente")
        media = layer["mediaType"]
        if media not in {
            "application/vnd.oci.image.layer.v1.tar",
            "application/vnd.oci.image.layer.v1.tar+gzip",
        }:
            raise ValueError("Formato de camada não validado")
        opener = gzip.open if media.endswith("+gzip") else open
        with opener(path, "rb") as content:
            actual = "sha256:" + hashlib.file_digest(content, "sha256").hexdigest()
        if actual != diff_id:
            raise ValueError("DiffID de camada não corresponde à imagem puxada")
    return {
        "manifest": images[0]["digest"],
        "config": manifest["config"]["digest"],
        "architecture": architecture,
        "layers": len(manifest["layers"]),
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("architecture", choices=["amd64", "arm64"])
    parser.add_argument("--expected-config", required=True)
    parser.add_argument("--receipt", required=True, type=Path)
    args = parser.parse_args()
    receipt = prepare(
        args.archive, args.destination, args.architecture, args.expected_config
    )
    args.receipt.write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps(receipt))
