"""Controles de integridade e confinamento do OCI antes do scanner."""

import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    "prepare_local_oci",
    Path(__file__).resolve().parents[1] / "scripts/prepare-local-oci.py",
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class OciIntegrityTests(unittest.TestCase):
    def archive(
        self,
        root,
        *,
        user="10001:10001",
        arch="arm64",
        corrupt=False,
        unsafe=False,
        bad_diff=False,
    ):
        blobs = {}

        def blob(content, media):
            raw = json.dumps(content).encode() if isinstance(content, dict) else content
            digest = hashlib.sha256(raw).hexdigest()
            blobs[f"blobs/sha256/{digest}"] = raw
            return {"mediaType": media, "digest": f"sha256:{digest}", "size": len(raw)}

        layer = blob(b"layer-fixture", "application/vnd.oci.image.layer.v1.tar")
        config = blob(
            {
                "os": "linux",
                "architecture": arch,
                "config": {
                    "User": user,
                    "WorkingDir": "/app",
                    "Cmd": [
                        "uvicorn",
                        "main:app",
                        "--host",
                        "0.0.0.0",
                        "--port",
                        "8080",
                    ],
                    "Healthcheck": {"Test": ["CMD", "health"]},
                },
                "rootfs": {
                    "type": "layers",
                    "diff_ids": ["sha256:" + "0" * 64 if bad_diff else layer["digest"]],
                },
            },
            "application/vnd.oci.image.config.v1+json",
        )
        manifest = blob(
            {"schemaVersion": 2, "config": config, "layers": [layer]},
            "application/vnd.oci.image.manifest.v1+json",
        )
        entries = {
            "index.json": json.dumps(
                {"schemaVersion": 2, "manifests": [manifest]}
            ).encode(),
            "oci-layout": b'{"imageLayoutVersion":"1.0.0"}',
            **blobs,
        }
        if corrupt:
            entries[next(iter(blobs))] = b"corrupt"
        if unsafe:
            entries["../outside"] = b"unsafe"
        output = root / "image.tar"
        with tarfile.open(output, "w") as archive:
            for name, content in entries.items():
                entry = tarfile.TarInfo(name)
                entry.size = len(content)
                archive.addfile(entry, io.BytesIO(content))
        return output, config["digest"]

    def test_valid_inventory_bound_to_image_config(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive, config = self.archive(root)
            receipt = module.prepare(archive, root / "layout", "arm64", config)
            self.assertEqual(receipt["config"], config)
            self.assertEqual(receipt["layers"], 1)

    def test_rejects_tampering_platform_user_and_diff_ids(self):
        for options in (
            {"corrupt": True},
            {"unsafe": True},
            {"arch": "amd64"},
            {"user": "0"},
            {"bad_diff": True},
        ):
            with (
                self.subTest(options=options),
                tempfile.TemporaryDirectory() as directory,
            ):
                root = Path(directory)
                archive, config = self.archive(root, **options)
                with self.assertRaises(ValueError):
                    module.prepare(archive, root / "layout", "arm64", config)
                self.assertFalse((root / "outside").exists())

    def test_rejects_other_image_even_with_valid_blobs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive, _ = self.archive(root)
            with self.assertRaises(ValueError):
                module.prepare(archive, root / "layout", "arm64", "sha256:" + "f" * 64)


if __name__ == "__main__":
    unittest.main()
