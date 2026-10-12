#!/usr/bin/env python3
"""sf2_drum_keys.py — which MIDI notes actually sound in each drum kit of a SoundFont.

Usage:
    python3 tools/sf2_drum_keys.py [file.sf2] [--keys 35-82] [--all]

Defaults to assets/Zudio.sf2 and the GM percussion range.

WHY
A drum note that a kit has no sample for plays SILENCE, with no error. Kits in Zudio.sf2 do
not share coverage: Ambient already has to remap Shaker (82) -> Maracas (70) and Claves (75) ->
Triangle (81) when switching between its Percussion Kit and Brush Kit, because each kit lacks
what the other has. Before a rule writes a conga or a shaker, check the kits it can land on.

Reads the SoundFont directly — preset (bank 128 = drums) -> preset zones -> instrument ->
instrument zones -> sample — intersecting key ranges at both levels, and reports the sample
name sounding on each key so a mapped-but-wrong sample is visible too.
"""
import struct, sys, os

GM = {35:"Acoustic Bass Drum",36:"Bass Drum 1",37:"Side Stick",38:"Acoustic Snare",39:"Hand Clap",
      40:"Electric Snare",41:"Low Floor Tom",42:"Closed Hi-Hat",43:"High Floor Tom",44:"Pedal Hi-Hat",
      45:"Low Tom",46:"Open Hi-Hat",47:"Low-Mid Tom",48:"Hi-Mid Tom",49:"Crash 1",50:"High Tom",
      51:"Ride 1",52:"Chinese Cymbal",53:"Ride Bell",54:"Tambourine",55:"Splash",56:"Cowbell",
      57:"Crash 2",58:"Vibraslap",59:"Ride 2",60:"Hi Bongo",61:"Low Bongo",62:"Mute Hi Conga",
      63:"Open Hi Conga",64:"Low Conga",65:"High Timbale",66:"Low Timbale",67:"High Agogo",
      68:"Low Agogo",69:"Cabasa",70:"Maracas",71:"Short Whistle",72:"Long Whistle",
      73:"Short Guiro",74:"Long Guiro",75:"Claves",76:"Hi Wood Block",77:"Low Wood Block",
      78:"Mute Cuica",79:"Open Cuica",80:"Mute Triangle",81:"Open Triangle",82:"Shaker",
      83:"Jingle Bell",84:"Bell Tree",85:"Castanets",86:"Mute Surdo",87:"Open Surdo"}

GEN_KEYRANGE, GEN_INSTRUMENT, GEN_SAMPLEID = 43, 41, 53


def chunks(data, off, end):
    while off < end:
        cid, size = struct.unpack_from("<4sI", data, off)
        yield cid, off + 8, size
        off += 8 + size + (size & 1)


def load(path):
    data = open(path, "rb").read()
    assert data[:4] == b"RIFF" and data[8:12] == b"sfbk", "not a SoundFont"
    pdta = None
    for cid, off, size in chunks(data, 12, len(data)):
        if cid == b"LIST" and data[off:off + 4] == b"pdta":
            pdta = {c: data[o:o + s] for c, o, s in chunks(data, off + 4, off + size)}
    assert pdta, "no pdta chunk"

    def recs(buf, fmt):
        n = struct.calcsize(fmt)
        return [struct.unpack_from(fmt, buf, i) for i in range(0, len(buf) - n + 1, n)]

    phdr = recs(pdta[b"phdr"], "<20sHHHIII")
    pbag = recs(pdta[b"pbag"], "<HH")
    pgen = recs(pdta[b"pgen"], "<HH")
    inst = recs(pdta[b"inst"], "<20sH")
    ibag = recs(pdta[b"ibag"], "<HH")
    igen = recs(pdta[b"igen"], "<HH")
    shdr = recs(pdta[b"shdr"], "<20sIIIIIBbHH")

    def name(b):
        return b.split(b"\0", 1)[0].decode("latin-1").strip()

    def zone_gens(gens, lo, hi):
        out = {}
        for oper, amt in gens[lo:hi]:
            out[oper] = amt
        return out

    def keyrange(g):
        if GEN_KEYRANGE in g:
            v = g[GEN_KEYRANGE]
            return v & 0xFF, (v >> 8) & 0xFF
        return 0, 127

    def inst_map(i):
        """key -> sample name for instrument i."""
        out = {}
        # Guard the ranges. Zudio.sf2 is produced by tools/strip_sf2.py, and a stripped file can
        # leave bag indices that are not strictly monotonic; a stock reader would overrun.
        if i + 1 >= len(inst):
            return out
        b0, b1 = inst[i][1], min(inst[i + 1][1], len(ibag) - 1)
        for z in range(b0, b1):
            g = zone_gens(igen, ibag[z][0], ibag[z + 1][0])
            if GEN_SAMPLEID not in g:
                continue                      # global zone
            lo, hi = keyrange(g)
            sname = name(shdr[g[GEN_SAMPLEID]][0])
            for k in range(lo, hi + 1):
                out.setdefault(k, sname)
        return out

    kits = []
    for p in range(len(phdr) - 1):            # last record is the EOP terminator
        pname, prog, bank, bagi = name(phdr[p][0]), phdr[p][1], phdr[p][2], phdr[p][3]
        if bank != 128:
            continue
        keys = {}
        for z in range(bagi, min(phdr[p + 1][3], len(pbag) - 1)):
            g = zone_gens(pgen, pbag[z][0], pbag[z + 1][0])
            if GEN_INSTRUMENT not in g:
                continue
            plo, phi = keyrange(g)
            for k, s in inst_map(g[GEN_INSTRUMENT]).items():
                if plo <= k <= phi:
                    keys.setdefault(k, s)
        kits.append((prog, pname, keys))
    return sorted(kits)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    path = args[0] if args else os.path.join(os.path.dirname(__file__), "..", "assets", "Zudio.sf2")
    lo, hi = 35, 87
    if "--keys" in sys.argv:
        a, b = sys.argv[sys.argv.index("--keys") + 1].split("-")
        lo, hi = int(a), int(b)
    show_all = "--all" in sys.argv

    kits = load(path)
    print(f"{os.path.basename(path)}: {len(kits)} drum kits (bank 128)\n")
    for prog, pname, keys in kits:
        have = [k for k in range(lo, hi + 1) if k in keys]
        print(f"program {prog:>3}  {pname}   {len(have)}/{hi - lo + 1} keys in {lo}-{hi}")
        for k in range(lo, hi + 1):
            if k in keys:
                if show_all or k >= 60:
                    print(f"     {k:>3} {GM.get(k, '?'):<20} <- {keys[k]}")
            elif show_all or k >= 60:
                print(f"     {k:>3} {GM.get(k, '?'):<20}    -- SILENT --")
        print()


if __name__ == "__main__":
    main()
