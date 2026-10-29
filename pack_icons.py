#!/usr/bin/env python3
"""
Packs 478 villager and NPC icons into a single binary archive `icons_archive.bin`.
Format:
- 16-byte Header:
  - char magic[8] = "REDDICOS"
  - uint32 count
  - uint32 dataOffset
- Table of Contents (count * 24 bytes, sorted by lowercase name):
  - char name[16] (null-padded)
  - uint32 offset (relative to dataOffset)
  - uint32 size
- Data Section:
  - Concatenated raw PNG file bytes
"""

import os
import struct
import sys

def pack_icons():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    icons_dir = os.path.join(script_dir, "layout", "Library", "Application Support", "ReddsTools", "icons")
    output_bin = os.path.join(script_dir, "icons_archive.bin")

    if not os.path.isdir(icons_dir):
        print(f"Error: Icons directory not found: {icons_dir}", file=sys.stderr)
        sys.exit(1)

    filenames = sorted([f for f in os.listdir(icons_dir) if f.lower().endswith(".png")], key=lambda x: x.lower())
    count = len(filenames)
    print(f"Packing {count} PNG icons into {output_bin}...")

    # Header size: 16 bytes
    # Entry size: 16 (name) + 4 (offset) + 4 (size) = 24 bytes
    toc_size = count * 24
    data_offset = 16 + toc_size

    toc_entries = []
    data_blobs = []
    current_offset = 0

    for name in filenames:
        path = os.path.join(icons_dir, name)
        with open(path, "rb") as f:
            data = f.read()

        name_bytes = name.encode("utf-8")
        if len(name_bytes) >= 16:
            raise ValueError(f"Filename {name} is too long for 16-byte field")

        padded_name = name_bytes.ljust(16, b"\x00")
        size = len(data)

        toc_entries.append((padded_name, current_offset, size))
        data_blobs.append(data)
        current_offset += size

    # Write output binary
    with open(output_bin, "wb") as out:
        # Header
        out.write(b"REDDICOS")
        out.write(struct.pack("<II", count, data_offset))

        # TOC
        for name_bytes, offset, size in toc_entries:
            out.write(name_bytes)
            out.write(struct.pack("<II", offset, size))

        # Data
        for blob in data_blobs:
            out.write(blob)

    total_size = os.path.getsize(output_bin)
    print(f"Successfully packed {count} icons into {output_bin} ({total_size:,} bytes / {total_size / (1024*1024):.2f} MB)")

if __name__ == "__main__":
    pack_icons()
