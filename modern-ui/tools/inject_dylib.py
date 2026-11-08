#!/usr/bin/env python3
"""Add one LC_LOAD_DYLIB command to a thin 64-bit Mach-O executable (no dependencies).

    python3 inject_dylib.py <executable> <install path> [--weak]

The new command goes in front of LC_CODE_SIGNATURE (the signature stays the last command, as linkers write it) and uses the
zero padding that every Mach-O leaves between its load commands and the first section.  The existing signature becomes invalid
by this edit: sign the file again afterwards (ldid -S<entitlements> <executable>).
"""
import struct
import sys

LC_LOAD_DYLIB = 0xC
LC_LOAD_WEAK_DYLIB = 0x80000018
LC_CODE_SIGNATURE = 0x1D
LC_SEGMENT_64 = 0x19
MH_MAGIC_64 = 0xFEEDFACF


def inject(data, path, weak=False):
    data = bytearray(data)
    magic = struct.unpack_from("<I", data, 0)[0]
    if magic != MH_MAGIC_64:
        raise SystemExit("not a thin 64-bit little-endian Mach-O (magic %#x)" % magic)
    ncmds, sizeofcmds = struct.unpack_from("<II", data, 16)
    end = 32 + sizeofcmds

    commands = []  # (offset, cmd, size)
    first_section = None
    off = 32
    for _ in range(ncmds):
        cmd, size = struct.unpack_from("<II", data, off)
        commands.append((off, cmd, size))
        if cmd in (LC_LOAD_DYLIB, LC_LOAD_WEAK_DYLIB):
            name_off = struct.unpack_from("<I", data, off + 8)[0]
            name = bytes(data[off + name_off:off + size]).split(b"\0")[0].decode()
            if name == path:
                print("already present:", path)
                return bytes(data), False
        if cmd == LC_SEGMENT_64:
            nsects = struct.unpack_from("<I", data, off + 64)[0]
            so = off + 72
            for _i in range(nsects):
                (soff,) = struct.unpack_from("<I", data, so + 48)
                if soff and (first_section is None or soff < first_section):
                    first_section = soff
                so += 80
        off += size
    assert off == end, "load commands do not add up"

    raw = path.encode() + b"\0"
    size = (24 + len(raw) + 7) & ~7
    new = struct.pack("<IIIIII", LC_LOAD_WEAK_DYLIB if weak else LC_LOAD_DYLIB, size, 24, 2, 0x00010000, 0x00010000)
    new += raw + b"\0" * (size - 24 - len(raw))

    if first_section is None or end + size > first_section:
        raise SystemExit("no room for a new load command (%d bytes needed, %s available)" % (size, None if first_section is None else first_section - end))
    if any(data[end:end + size]):
        raise SystemExit("the padding after the load commands is not empty")

    insert_at = end
    for (o, cmd, s) in commands:
        if cmd == LC_CODE_SIGNATURE and o + s == end:
            insert_at = o
            break
    tail = bytes(data[insert_at:end])
    data[insert_at:insert_at + size + len(tail)] = new + tail
    struct.pack_into("<II", data, 16, ncmds + 1, sizeofcmds + size)
    return bytes(data), True


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 2
    exe, path = argv[1], argv[2]
    weak = "--weak" in argv[3:]
    with open(exe, "rb") as f:
        data = f.read()
    out, changed = inject(data, path, weak)
    if changed:
        with open(exe, "wb") as f:
            f.write(out)
        print("added %s %s to %s" % ("LC_LOAD_WEAK_DYLIB" if weak else "LC_LOAD_DYLIB", path, exe))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
