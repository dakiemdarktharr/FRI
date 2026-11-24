#!/usr/bin/env python3
"""Write synthetic sidebar photo fixtures to an explicitly chosen QA folder."""
import argparse
import base64
import datetime
import json
from pathlib import Path
import struct
import zlib


def png(width, height):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    # Horizontal bands make centered cover cropping and tint easy to inspect.
    colors = [(240, 60, 40), (250, 200, 40), (40, 180, 130), (30, 100, 230)]
    pixels = b"".join(b"\0" + bytes(colors[min(3, y * 4 // height)]) * width for y in range(height))
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(pixels)) + chunk(b"IEND", b"")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder", type=Path)
    args = parser.parse_args()
    args.folder.mkdir(parents=True, exist_ok=True)
    photo = png(800, 1200)
    (args.folder / "sidebar-bands.png").write_bytes(photo)
    today = datetime.date.today().isoformat()
    state = {"version": 1, "tasks": [], "drafts": [], "active": today, "tabs": [today],
             "settings": {"sidebar": "image", "motion": False, "image": "data:image/png;base64," + base64.b64encode(photo).decode()},
             "widgets": ["upnext"], "collections": [], "finished": []}
    (args.folder / "sidebar-desktop-backup.json").write_text(json.dumps({"format": "fri-backup", "schema": 1, "state": state}))
    print(args.folder)


if __name__ == "__main__":
    main()
