#!/usr/bin/env python3
"""Sanity-check a packaged IPA against the base IPA (structure only - nothing is executed).

    python3 verify_ipa.py <packaged.ipa> <base.ipa>

Fails (exit 1) unless: the new framework is inside; the executable has exactly one more LC_LOAD_DYLIB, which points at it; its
entitlements are the same as the base executable's; every other file of the base IPA is byte-identical except Info.plist and the
executable.
"""
import hashlib
import plistlib
import re
import struct
import sys
import zipfile

NEW = "Frameworks/BlinkerModernUI.framework/BlinkerModernUI"


def load_dylibs(data):
    ncmds = struct.unpack_from("<I", data, 16)[0]
    off = 32
    names = []
    for _ in range(ncmds):
        cmd, size = struct.unpack_from("<II", data, off)
        if cmd in (0xC, 0x80000018):
            nameoff = struct.unpack_from("<I", data, off + 8)[0]
            names.append(data[off + nameoff:off + size].split(b"\0")[0].decode())
        off += size
    return names


def entitlements(data):
    m = re.search(rb"<\?xml.*?</plist>", data[-200000:], re.S)
    return plistlib.loads(m.group(0)) if m else None


def main(argv):
    packaged, base = zipfile.ZipFile(argv[1]), zipfile.ZipFile(argv[2])
    problems = []
    root = next(n for n in base.namelist() if n.endswith(".app/Info.plist"))[:-len("Info.plist")]
    info = plistlib.loads(base.read(root + "Info.plist"))
    exe = root + info["CFBundleExecutable"]

    if root + NEW not in packaged.namelist():
        problems.append("the framework is not in the IPA")
    else:
        print("framework: %d bytes" % packaged.getinfo(root + NEW).file_size)

    old_libs, new_libs = load_dylibs(base.read(exe)), load_dylibs(packaged.read(exe))
    added = [n for n in new_libs if n not in old_libs]
    print("executable load commands: %d -> %d, added %s" % (len(old_libs), len(new_libs), added))
    if added != ["@rpath/BlinkerModernUI.framework/BlinkerModernUI"] or [n for n in old_libs if n not in new_libs]:
        problems.append("unexpected change of the executable's libraries")

    ent_old, ent_new = entitlements(base.read(exe)), entitlements(packaged.read(exe))
    print("entitlements before:", sorted(ent_old or {}))
    print("entitlements after: ", sorted(ent_new or {}))
    if ent_old != ent_new:
        problems.append("entitlements differ")

    changed = []
    for name in base.namelist():
        if name.endswith("/"):
            continue
        if name not in packaged.namelist():
            problems.append("missing in the packaged IPA: " + name)
        elif hashlib.sha256(base.read(name)).digest() != hashlib.sha256(packaged.read(name)).digest():
            changed.append(name)
    print("files that differ from the base IPA:", [n[len(root):] for n in changed])
    if sorted(n[len(root):] for n in changed) != sorted([info["CFBundleExecutable"], "Info.plist"]):
        problems.append("unexpected files changed")
    new_info = plistlib.loads(packaged.read(root + "Info.plist"))
    print("CFBundleVersion: %s -> %s | bundle id %s" % (info["CFBundleVersion"], new_info["CFBundleVersion"], new_info["CFBundleIdentifier"]))
    if new_info["CFBundleIdentifier"] != info["CFBundleIdentifier"]:
        problems.append("the bundle identifier changed")

    for p in problems:
        print("PROBLEM:", p)
    print("OK" if not problems else "FAILED")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
