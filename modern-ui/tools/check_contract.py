#!/usr/bin/env python3
"""Check Sources/Hooks/BKContract.inc against the Objective-C metadata of a real content_shell_framework.

    python3 objc_dump.py <content_shell_framework> objc.json
    python3 check_contract.py objc.json ../Sources/Hooks/BKContract.inc ../Sources/Hooks/BKContractIME.inc

Every BK_METHOD("Class", "selector", "shape") must exist as an instance method of that class with that signature (type encoding
without frame offsets) and every BK_IVAR("Class", "_name") must be an ivar of it.  Exit status 1 when anything is off, so CI fails
before an IPA is built that would silently fall back to the stock UI.
"""
import json
import re
import sys


def shape(types):
    return re.sub(r"\d+", "", types or "")


def main(argv):
    dump, incs = argv[1], argv[2:]
    meta = json.load(open(dump, encoding="utf-8"))["classes"]
    text = "\n".join(open(inc, encoding="utf-8").read() for inc in incs)
    methods = re.findall(r'^BK_METHOD\("([^"]+)",\s*"([^"]+)",\s*"([^"]+)"\)', text, re.M)
    ivars = re.findall(r'^BK_IVAR\("([^"]+)",\s*"([^"]+)"\)', text, re.M)
    bad = 0
    for cls, sel, want in methods:
        c = meta.get(cls)
        if c is None:
            print("FAIL  class %s is missing (-%s)" % (cls, sel))
            bad += 1
            continue
        found = [m for m in c["methods"] if m[0] == sel]
        if not found:
            # properties are implemented by synthesised accessors, which are in the method list too; anything else is a miss
            print("FAIL  -[%s %s] is missing" % (cls, sel))
            bad += 1
        elif shape(found[0][1]) != want:
            print("FAIL  -[%s %s] has signature %s, expected %s" % (cls, sel, shape(found[0][1]), want))
            bad += 1
    for cls, name in ivars:
        c = meta.get(cls)
        if c is None or not any(i[0] == name for i in c["ivars"]):
            print("FAIL  ivar %s.%s is missing" % (cls, name))
            bad += 1
    print("contract: %d methods, %d ivars checked, %d problems" % (len(methods), len(ivars), bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
