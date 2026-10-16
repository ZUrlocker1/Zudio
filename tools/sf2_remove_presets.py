#!/usr/bin/env python3
"""
sf2_remove_presets.py — remove presets from a SoundFont and free the samples only they used.

    python3 tools/sf2_remove_presets.py                    # the default set, see PRESETS
    python3 tools/sf2_remove_presets.py --dry-run          # report only, write nothing
    python3 tools/sf2_remove_presets.py --sf2 X.sf2 --out Y.sf2 128:56 0:25

The reverse of tools/sf2_copy_presets.py. Every other preset keeps its bank, program, name, zones,
generators and modulators, in its original order. An instrument goes only when no remaining preset
uses it, and a sample only when no remaining instrument does (a stereo pair is kept or removed
together). The sample data that is left is repacked in its original order, each sample followed by
the 46 zero points the spec requires, with start/end/loop offsets rebased. INFO is kept verbatim.

It refuses to run if a requested preset is not in the bank, or if two kept samples overlap without
being identical — a layout this repacking would not preserve.

Verification is built in: after writing, it re-reads the output and confirms the removed presets
are gone and every remaining preset still resolves to byte-identical PCM, loops, tuning and
sample type.
"""

import argparse, struct, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from sf2_copy_presets import (read_sf2, write_sf2, u16, u32, resolve, pcm_hash,
                              PDTA_ORDER, GEN_INSTRUMENT, GEN_SAMPLE_ID, ZERO_PAD)

# Zack, 2026-10-15: the SFX drum kit (helicopter, gunshot, dog...) and the four guitars rejected
# after the Chill Soho audition — Steel, 12-String, Wah and Clean Guitar 2.
PRESETS = [(128, 56), (0, 25), (8, 25), (11, 29), (12, 27)]


def name_of(rec):
    return rec[:20].split(b"\0")[0].decode("latin1")


def remove_presets(sf, unwanted):
    R = sf["recs"]
    P, PB, PG, PM = R["phdr"], R["pbag"], R["pgen"], R["pmod"]
    I, IB, IG, IM, S = R["inst"], R["ibag"], R["igen"], R["imod"], R["shdr"]
    nP, nI = len(P) - 1, len(I) - 1
    # Clamped like resolve(): a bank built by the old strip_sf2.py has EOI/EOP one past the end.
    def pbags(k): return range(u16(P[k], 24), min(u16(P[k + 1], 24), len(PB) - 1))
    def ibags(k): return range(u16(I[k], 20), min(u16(I[k + 1], 20), len(IB) - 1))

    keep_p = [k for k in range(nP) if (u16(P[k], 22), u16(P[k], 20)) not in unwanted]

    # ---- what the kept presets still need
    inst_used = set()
    for k in keep_p:
        for b in pbags(k):
            for g in range(u16(PB[b], 0), u16(PB[b + 1], 0)):
                op, amt = struct.unpack("<HH", PG[g])
                if op == GEN_INSTRUMENT:
                    inst_used.add(amt)
    samp_used = set()
    for ik in inst_used:
        for b in ibags(ik):
            for g in range(u16(IB[b], 0), u16(IB[b + 1], 0)):
                op, amt = struct.unpack("<HH", IG[g])
                if op == GEN_SAMPLE_ID:
                    samp_used.add(amt)
    for s in list(samp_used):                          # stereo partners stay with their pair
        if u16(S[s], 44) in (2, 4, 8):
            samp_used.add(u16(S[s], 42))

    keep_i = [k for k in range(nI) if k in inst_used]
    keep_s = [s for s in range(len(S) - 1) if s in samp_used]
    inst_map = {k: n for n, k in enumerate(keep_i)}
    samp_map = {s: n for n, s in enumerate(keep_s)}

    # ---- sample data: repack the kept regions in original order
    regions = sorted({(u32(S[s], 20), u32(S[s], 24)) for s in keep_s})
    for (a0, a1), (b0, b1) in zip(regions, regions[1:]):
        if b0 < a1:
            sys.exit(f"kept samples overlap ({a0}-{a1} and {b0}-{b1}); refusing to repack")
    smpl, region_map = bytearray(), {}
    for start, end in regions:
        region_map[(start, end)] = len(smpl) // 2
        smpl += sf["smpl"][start * 2:end * 2] + b"\0\0" * ZERO_PAD

    out = {k: [] for k in PDTA_ORDER}
    for s in keep_s:
        rec = bytearray(S[s])
        start, end = u32(rec, 20), u32(rec, 24)
        delta = region_map[(start, end)] - start
        for off in (20, 24, 28, 32):
            struct.pack_into("<I", rec, off, u32(rec, off) + delta)
        if u16(rec, 44) in (2, 4, 8):
            struct.pack_into("<H", rec, 42, samp_map[u16(rec, 42)])
        out["shdr"].append(rec)

    # ---- instruments, zones in order, sample IDs remapped
    for ik in keep_i:
        rec = bytearray(I[ik]); struct.pack_into("<H", rec, 20, len(out["ibag"]))
        out["inst"].append(rec)
        for b in ibags(ik):
            bag = bytearray(IB[b])
            struct.pack_into("<HH", bag, 0, len(out["igen"]), len(out["imod"]))
            out["ibag"].append(bag)
            for g in range(u16(IB[b], 0), u16(IB[b + 1], 0)):
                gen = bytearray(IG[g]); op, amt = struct.unpack("<HH", gen)
                if op == GEN_SAMPLE_ID:
                    struct.pack_into("<H", gen, 2, samp_map[amt])
                out["igen"].append(gen)
            for m in range(u16(IB[b], 2), u16(IB[b + 1], 2)):
                out["imod"].append(bytearray(IM[m]))

    # ---- presets, instrument generator remapped
    for k in keep_p:
        rec = bytearray(P[k]); struct.pack_into("<H", rec, 24, len(out["pbag"]))
        out["phdr"].append(rec)
        for b in pbags(k):
            bag = bytearray(PB[b])
            struct.pack_into("<HH", bag, 0, len(out["pgen"]), len(out["pmod"]))
            out["pbag"].append(bag)
            for g in range(u16(PB[b], 0), u16(PB[b + 1], 0)):
                gen = bytearray(PG[g]); op, amt = struct.unpack("<HH", gen)
                if op == GEN_INSTRUMENT:
                    struct.pack_into("<H", gen, 2, inst_map[amt])
                out["pgen"].append(gen)
            for m in range(u16(PB[b], 2), u16(PB[b + 1], 2)):
                out["pmod"].append(bytearray(PM[m]))

    # ---- terminal records: EOP/EOI point AT the terminal bag, which points one past the end
    eop = bytearray(P[-1]);  struct.pack_into("<H", eop, 24, len(out["pbag"]))
    pbt = bytearray(PB[-1]); struct.pack_into("<HH", pbt, 0, len(out["pgen"]), len(out["pmod"]))
    eoi = bytearray(I[-1]);  struct.pack_into("<H", eoi, 20, len(out["ibag"]))
    ibt = bytearray(IB[-1]); struct.pack_into("<HH", ibt, 0, len(out["igen"]), len(out["imod"]))
    for k, t in (("phdr", eop), ("pbag", pbt), ("inst", eoi), ("ibag", ibt),
                 ("pmod", PM[-1]), ("pgen", PG[-1]), ("imod", IM[-1]), ("igen", IG[-1]),
                 ("shdr", S[-1])):
        out[k].append(t)

    stats = (nP - len(keep_p), nI - len(keep_i), len(S) - 1 - len(keep_s))
    return {"info_raw": sf["info_raw"], "smpl": smpl, "recs": out}, keep_p, stats


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    ap.add_argument("--sf2", default="assets/Zudio.sf2")
    ap.add_argument("--out", default="assets/Zudio.sf2.new")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("presets", nargs="*", help="bank:program, e.g. 128:56")
    a = ap.parse_args()
    unwanted = {tuple(int(x) for x in p.split(":")) for p in a.presets} or set(PRESETS)

    sf = read_sf2(a.sf2)
    P = sf["recs"]["phdr"]
    present = {(u16(P[k], 22), u16(P[k], 20)): name_of(P[k]) for k in range(len(P) - 1)}
    for key in sorted(unwanted):
        if key not in present:
            sys.exit(f"no preset {key[0]}:{key[1]} in {a.sf2}")

    out, keep_p, (np_, ni, ns) = remove_presets(sf, unwanted)
    freed = (len(sf["smpl"]) - len(out["smpl"])) / 1e6
    print(f"removing {np_} presets, {ni} instruments, {ns} samples: -{freed:.2f} MB of sample data")
    for key in sorted(unwanted):
        print(f"   {key[0]:3d}:{key[1]:03d}  {present[key]}")
    if a.dry_run:
        print("dry run — nothing written"); return

    write_sf2(out, a.out)

    # ---- verify by re-reading what was written
    chk = read_sf2(a.out)
    C, problems = chk["recs"]["phdr"], 0
    seen = {(u16(C[k], 22), u16(C[k], 20), bytes(C[k][:20])): k for k in range(len(C) - 1)}
    for key in unwanted:
        if any(s[:2] == key for s in seen):
            print(f"   preset {key[0]}:{key[1]} is still there"); problems += 1
    for k in keep_p:
        key = (u16(P[k], 22), u16(P[k], 20), bytes(P[k][:20]))
        if key not in seen:
            print(f"   MISSING preset {key[0]}:{key[1]}"); problems += 1
        elif pcm_hash(chk, resolve(chk, seen[key])) != pcm_hash(sf, resolve(sf, k)):
            print(f"   CHANGED preset {key[0]}:{key[1]} {name_of(P[k])}"); problems += 1
    print(f"verified {len(keep_p)} remaining presets unchanged and {len(unwanted)} removed — "
          f"{problems} problems")
    print(f"wrote {a.out}  ({Path(a.sf2).stat().st_size/1e6:.1f} MB -> {Path(a.out).stat().st_size/1e6:.1f} MB)")
    if problems:
        sys.exit(1)

if __name__ == "__main__":
    main()
