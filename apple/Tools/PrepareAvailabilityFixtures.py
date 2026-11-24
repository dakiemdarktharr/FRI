#!/usr/bin/env python3
"""Write synthetic Files-picker fixtures into an explicitly supplied QA folder.

Use the same local date/time zone as the simulator. This does not alter app storage.
"""
import argparse
import datetime as dt
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("destination", type=Path)
parser.add_argument("--day", type=dt.date.fromisoformat, default=dt.date.today())
args = parser.parse_args()
args.destination.mkdir(parents=True, exist_ok=True)


def window(start, end):
    def timestamp(time):
        return dt.datetime.combine(args.day, dt.time.fromisoformat(time)).astimezone().isoformat()
    return {"start": timestamp(start), "end": timestamp(end)}


for name, windows in {
    "matching": [window("09:30", "10:30"), window("09:30", "10:30"), window("11:00", "11:25")],
    "no-match": [window("18:00", "19:00")],
}.items():
    (args.destination / f"{name}.json").write_text(
        json.dumps({"format": "fri-free-time", "version": 1, "windows": windows}), encoding="utf-8"
    )
(args.destination / "invalid.json").write_text('{"format":"not-fri","version":1,"windows":[]}', encoding="utf-8")
(args.destination / "oversized.json").write_bytes(b" " * 1_000_001)
print(f"Wrote four synthetic fixtures for {args.day} into {args.destination}")
