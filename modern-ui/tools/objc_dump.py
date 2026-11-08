"""Minimal Objective-C 2.0 metadata reader for a 64-bit Mach-O dylib (parse only; the file is never run).

    python -I objc_dump.py <macho> <out.json>

Writes {class name: {super, ivars:[[name,type,offset]], methods:[[sel,types,imp]], cmethods:[...], props:[[name,attrs]], protocols:[...]}}
plus categories.  Handles absolute and relative ("small") method lists and non-chained-fixup binaries (pointers are plain vmaddrs).
"""
import json
import struct
import sys

try:
    import lief
except ImportError:  # pragma: no cover
    lief = None


class Img:
    def __init__(self, path):
        self.data = open(path, "rb").read()
        magic, cputype, cpusub, ftype, ncmds, sizeofcmds, flags, _res = struct.unpack_from("<IiiIIIII", self.data, 0)
        assert magic == 0xFEEDFACF, hex(magic)
        self.segs = []
        self.sections = []          # (segname, sectname, addr, size, offset)
        self.chained = False
        off = 32
        for _ in range(ncmds):
            cmd, cmdsize = struct.unpack_from("<II", self.data, off)
            if cmd == 0x19:         # LC_SEGMENT_64
                segname = self.data[off + 8:off + 24].split(b"\x00")[0].decode()
                vmaddr, vmsize, fileoff, filesize, maxprot, initprot, nsects, sflags = struct.unpack_from("<QQQQiiII", self.data, off + 24)
                self.segs.append((vmaddr, vmsize, fileoff, filesize, segname))
                so = off + 72
                for _i in range(nsects):
                    sectname = self.data[so:so + 16].split(b"\x00")[0].decode()
                    sseg = self.data[so + 16:so + 32].split(b"\x00")[0].decode()
                    addr, size, offset = struct.unpack_from("<QQI", self.data, so + 32)
                    self.sections.append((sseg, sectname, addr, size, offset))
                    so += 80
            elif cmd == 0x80000034:  # LC_DYLD_CHAINED_FIXUPS
                self.chained = True
            off += cmdsize
        self.binds = {}
        try:
            if lief is None:
                raise RuntimeError('lief is not installed')
            fat = lief.MachO.parse(path)
            m = next(iter(fat))
            for b in m.bindings:
                try:
                    self.binds[b.address] = b.symbol.name
                except Exception:
                    pass
        except Exception as e:
            print("(bindings unavailable: %s)" % e)

    def off(self, va):
        for (v, vs, fo, fs, n) in self.segs:
            if v <= va < v + max(vs, fs):
                return fo + (va - v)
        return None

    def u64(self, va):
        o = self.off(va)
        return struct.unpack_from("<Q", self.data, o)[0] if o is not None else None

    def u32(self, va):
        o = self.off(va)
        return struct.unpack_from("<I", self.data, o)[0] if o is not None else None

    def i32(self, va):
        o = self.off(va)
        return struct.unpack_from("<i", self.data, o)[0] if o is not None else None

    def cstr(self, va):
        o = self.off(va)
        if o is None:
            return None
        e = self.data.index(b"\0", o)
        return self.data[o:e].decode("utf-8", "replace")

    def ptr(self, va):
        """read a pointer field at va; returns (target vmaddr or None, bound symbol or None)"""
        v = self.u64(va)
        if v is None:
            return None, None
        if va in self.binds:
            return None, self.binds[va]
        return v & 0x0000007FFFFFFFFF if v else 0, None


def parse(path):
    im = Img(path)
    class Sec:
        def __init__(self, t):
            self.virtual_address, self.size = t[2], t[3]
    classlist = None
    catlist = None
    for t in im.sections:
        if t[1] == "__objc_classlist":
            classlist = Sec(t)
        elif t[1] == "__objc_catlist":
            catlist = Sec(t)
    out = {"classes": {}, "categories": [], "chained": im.chained}
    if classlist is None:
        return out

    def meths(lst):
        res = []
        if not lst:
            return res
        esz = im.u32(lst)
        cnt = im.u32(lst + 4)
        flags = esz & 0xFFFF0000
        small = bool(esz & 0x80000000)
        size = esz & 0xFFFC
        base = lst + 8
        for i in range(cnt):
            e = base + i * size
            if small:
                name_ref = e + im.i32(e)
                sel_ptr = im.u64(name_ref)           # selector refs point to the string
                sel = im.cstr(sel_ptr & 0x0000007FFFFFFFFF) if sel_ptr else None
                types = im.cstr(e + 4 + im.i32(e + 4))
                imp = e + 8 + im.i32(e + 8)
            else:
                n = im.u64(e) & 0x0000007FFFFFFFFF
                t = im.u64(e + 8) & 0x0000007FFFFFFFFF
                imp = im.u64(e + 16) & 0x0000007FFFFFFFFF
                sel, types = im.cstr(n), im.cstr(t)
            res.append([sel, types, imp])
        return res

    def ivars(lst):
        res = []
        if not lst:
            return res
        esz = im.u32(lst) & 0xFFFC
        cnt = im.u32(lst + 4)
        for i in range(cnt):
            e = lst + 8 + i * esz
            offp = im.u64(e) & 0x0000007FFFFFFFFF
            name = im.cstr(im.u64(e + 8) & 0x0000007FFFFFFFFF)
            typ = im.cstr(im.u64(e + 16) & 0x0000007FFFFFFFFF)
            res.append([name, typ, im.u32(offp) if offp else None])
        return res

    def props(lst):
        res = []
        if not lst:
            return res
        esz = im.u32(lst) & 0xFFFC
        cnt = im.u32(lst + 4)
        for i in range(cnt):
            e = lst + 8 + i * esz
            res.append([im.cstr(im.u64(e) & 0x0000007FFFFFFFFF), im.cstr(im.u64(e + 8) & 0x0000007FFFFFFFFF)])
        return res

    def protos(lst):
        res = []
        if not lst:
            return res
        cnt = im.u64(lst)
        for i in range(cnt):
            p = im.u64(lst + 8 + 8 * i) & 0x0000007FFFFFFFFF
            res.append(im.cstr(im.u64(p + 8) & 0x0000007FFFFFFFFF))
        return res

    def ro_of(cls_va):
        data = im.u64(cls_va + 32) & 0x0000007FFFFFFFF8
        return data

    n = classlist.size // 8
    for i in range(n):
        cva_slot = classlist.virtual_address + 8 * i
        cva = im.u64(cva_slot) & 0x0000007FFFFFFFFF
        if not cva:
            continue
        ro = ro_of(cva)
        name = im.cstr(im.u64(ro + 24) & 0x0000007FFFFFFFFF)
        sup_t, sup_sym = im.ptr(cva + 8)
        sup = sup_sym
        if sup is None and sup_t:
            sro = ro_of(sup_t)
            sup = im.cstr(im.u64(sro + 24) & 0x0000007FFFFFFFFF)
        isa_t, _ = im.ptr(cva)
        mro = ro_of(isa_t) if isa_t else None
        out["classes"][name] = {
            "super": sup,
            "ivars": ivars(im.u64(ro + 48) & 0x0000007FFFFFFFFF),
            "methods": meths(im.u64(ro + 32) & 0x0000007FFFFFFFFF),
            "cmethods": meths(im.u64(mro + 32) & 0x0000007FFFFFFFFF) if mro else [],
            "props": props(im.u64(ro + 64) & 0x0000007FFFFFFFFF),
            "protocols": protos(im.u64(ro + 40) & 0x0000007FFFFFFFFF),
        }
    if catlist is not None:
        for i in range(catlist.size // 8):
            c = im.u64(catlist.virtual_address + 8 * i) & 0x0000007FFFFFFFFF
            cname = im.cstr(im.u64(c) & 0x0000007FFFFFFFFF)
            cls_t, cls_sym = im.ptr(c + 8)
            cls = cls_sym
            if cls is None and cls_t:
                cls = im.cstr(im.u64(ro_of(cls_t) + 24) & 0x0000007FFFFFFFFF)
            out["categories"].append({"name": cname, "class": cls,
                                      "methods": meths(im.u64(c + 16) & 0x0000007FFFFFFFFF),
                                      "cmethods": meths(im.u64(c + 24) & 0x0000007FFFFFFFFF)})
    return out


if __name__ == "__main__":
    res = parse(sys.argv[1])
    json.dump(res, open(sys.argv[2], "w", encoding="utf-8"), indent=1)
    print("classes:", len(res["classes"]), "categories:", len(res["categories"]), "chained fixups:", res["chained"])
