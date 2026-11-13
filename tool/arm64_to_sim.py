"""Re-tags the arm64 objects of a static library built for iPhone devices so
they link into an arm64 iOS Simulator build (Apple Silicon, iOS 26+).

Each object's LC_VERSION_MIN_IPHONEOS (16 bytes) becomes LC_BUILD_VERSION
with platform IOSSIMULATOR (24 bytes), and every file offset after the load
commands moves along by the 8 bytes inserted. Development builds only.

    python3 -I tool/arm64_to_sim.py in.o out.o
"""
import struct
import sys

LC_SEGMENT_64, LC_SYMTAB, LC_DYSYMTAB = 0x19, 0x2, 0xB
LC_VERSION_MIN_IPHONEOS, LC_BUILD_VERSION = 0x25, 0x32
LINKEDIT_DATA = {0x1D, 0x1E, 0x26, 0x29, 0x2B, 0x2E, 0x33, 0x34}
PLATFORM_IOSSIMULATOR = 7
SHIFT = 8


def patch(data: bytes) -> bytes:
    magic, cpu, sub, ftype, ncmds, sizeofcmds, flags, res = struct.unpack_from('<IiiIIIII', data, 0)
    assert magic == 0xFEEDFACF, 'not a 64-bit Mach-O'
    out = bytearray(data[:32])
    cmds = bytearray()
    at = 32
    found = False
    for _ in range(ncmds):
        cmd, size = struct.unpack_from('<II', data, at)
        body = bytearray(data[at:at + size])
        if cmd == LC_VERSION_MIN_IPHONEOS:
            _, _, minos, sdk = struct.unpack_from('<IIII', body)
            body = bytearray(struct.pack('<IIIIII', LC_BUILD_VERSION, 24, PLATFORM_IOSSIMULATOR,
                                         max(minos, 0x000D0000), sdk, 0))
            found = True
        elif cmd == LC_BUILD_VERSION:
            return data  # already has one; nothing to move
        elif cmd == LC_SEGMENT_64:
            fileoff, filesize = struct.unpack_from('<QQ', body, 40)
            if filesize:
                struct.pack_into('<Q', body, 40, fileoff + SHIFT)
            nsects = struct.unpack_from('<I', body, 64)[0]
            for i in range(nsects):
                s = 72 + i * 80
                offset, align, reloff, nreloc, sflags = struct.unpack_from('<IIIII', body, s + 48)
                zerofill = (sflags & 0xFF) in (0x1, 0xC, 0x12)
                if offset and not zerofill:
                    struct.pack_into('<I', body, s + 48, offset + SHIFT)
                if nreloc:
                    struct.pack_into('<I', body, s + 56, reloff + SHIFT)
        elif cmd == LC_SYMTAB:
            symoff, nsyms, stroff, strsize = struct.unpack_from('<IIII', body, 8)
            struct.pack_into('<IIII', body, 8, symoff + SHIFT if nsyms else symoff, nsyms,
                             stroff + SHIFT if strsize else stroff, strsize)
        elif cmd == LC_DYSYMTAB:
            v = list(struct.unpack_from('<18I', body, 8))
            for off, count in ((6, 7), (8, 9), (10, 11), (12, 13), (14, 15), (16, 17)):
                if v[count]:
                    v[off] += SHIFT
            struct.pack_into('<18I', body, 8, *v)
        elif cmd in LINKEDIT_DATA:
            dataoff, datasize = struct.unpack_from('<II', body, 8)
            if datasize:
                struct.pack_into('<I', body, 8, dataoff + SHIFT)
        cmds += body
        at += size
    if not found:
        return data
    struct.pack_into('<I', out, 20, sizeofcmds + SHIFT)
    out += cmds
    out += data[32 + sizeofcmds:]
    return bytes(out)


if __name__ == '__main__':
    src, dst = sys.argv[1], sys.argv[2]
    with open(src, 'rb') as f:
        data = f.read()
    with open(dst, 'wb') as f:
        f.write(patch(data))
