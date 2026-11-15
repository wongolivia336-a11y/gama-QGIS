from hashlib import sha256
from pathlib import Path


HERE = Path(__file__).resolve().parent
ARCHIVE_NAME = "大学路遮荫数据_20261113_交付.zip"
EXPECTED_SHA256 = "954986FB275E3E0324FCE29C8C373345D0A0B7E45DDC7676616987D71CC72B0B"
PARTS = [HERE / f"{ARCHIVE_NAME}.part{index:03d}" for index in range(1, 5)]
OUTPUT = HERE / ARCHIVE_NAME


def main() -> None:
    missing = [part.name for part in PARTS if not part.is_file()]
    if missing:
        raise FileNotFoundError("Missing archive parts: " + ", ".join(missing))

    archive = b"".join(part.read_bytes() for part in PARTS)
    actual_sha256 = sha256(archive).hexdigest().upper()
    if actual_sha256 != EXPECTED_SHA256:
        raise ValueError(f"Archive SHA-256 mismatch: {actual_sha256}")

    if OUTPUT.exists():
        existing_sha256 = sha256(OUTPUT.read_bytes()).hexdigest().upper()
        if existing_sha256 != EXPECTED_SHA256:
            raise FileExistsError(
                f"Refusing to overwrite different file: {OUTPUT}"
            )
        print(f"Already present and verified: {OUTPUT}")
        return

    OUTPUT.write_bytes(archive)
    print(f"Reassembled and verified: {OUTPUT}")


if __name__ == "__main__":
    main()
