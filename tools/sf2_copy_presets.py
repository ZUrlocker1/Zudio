#!/usr/bin/env python3
"""
sf2_copy_presets.py — copy presets from one SoundFont into another, leaving everything else alone.

    python3 tools/sf2_copy_presets.py                      # the default guitar set, see PRESETS
    python3 tools/sf2_copy_presets.py --dry-run            # report only, write nothing
    python3 tools/sf2_copy_presets.py --src X.sf2 --dst Y.sf2 --out Z.sf2 0:26 8:25

WHY THIS EXISTS
---------------
Zudio.sf2 was made by stripping GeneralUser GS v1.471 with tools/strip_sf2.py. Re-running that
strip against a newer GeneralUser GS would rebuild EVERY instrument from a different release, so
every style would change. This instead appends only the requested presets — with the instruments,
zones, generators, modulators and sample data they reference — and leaves every existing byte of
the destination's presets, instruments and samples exactly where it was.

What it does:
  - presets   appended before the terminal EOP record, bank and program unchanged
  - zones     pbag/pgen/pmod and ibag/igen/imod copied in order, indices rebased
  - links     generator 41 (instrument) and 53 (sampleID), and shdr sampleLink, remapped
  - samples   16-bit PCM appended to smpl, each followed by the 46 zero points the spec requires;
              start/end/loop offsets rebased. Identical source regions are copied once.
  - INFO      the destination's INFO list is kept verbatim

It refuses to run if a requested preset is missing from the source, already present in the
destination, if either file carries sm24 (24-bit) data, or if a sample is ROM-based.

Verification is built in: after writing, it re-reads the output and confirms that every original
preset still resolves to byte-identical PCM, and every copied preset resolves to the same PCM as
in the source.
"""

import argparse, hashlib, struct, sys
from pathlib import Path

# GeneralUser GS guitars missing from Zudio.sf2 (Zack, 2026-10-15). Guitar Harmonics left out.
# Only Jazz (0:26), Clean (0:27) and Funk (8:28) were kept after the Chill Soho audition; the rest
# were taken out again with tools/sf2_remove_presets.py, so re-running this would re-add them.
PRESETS = [(0, 25), (0, 26), (0, 27), (8, 25), (8, 28), (11, 29), (12, 27)]

SIZES = {"phdr": 38, "pbag": 4, "pmod": 10, "pgen": 4,
         "inst": 22, "ibag": 4, "imod": 10, "igen": 4, "shdr": 46}
PDTA_ORDER = ["phdr", "pbag", "pmod", "pgen", "inst", "ibag", "imod", "igen", "shdr"]
GEN_INSTRUMENT, GEN_SAMPLE_ID = 41, 53
ZERO_PAD = 46                                  # SF2 2.04 §6.1: 46 zero points after each sample


# ---------------------------------------------------------------- reading

def read_sf2(path):
    d = Path(path).read_bytes()
    if d[:4] != b"RIFF" or d[8:12] != b"sfbk":
        sys.exit(f"{path}: not a SoundFont")
    lists, i = {}, 12
    while i < len(d):
        tag, n = d[i:i+4], struct.unpack("<I", d[i+4:i+8])[0]
        if tag == b"LIST":
            kind = d[i+8:i+12].decode()
            subs, j = {}, i + 12
            while j < i + 8 + n:
                t, m = d[j:j+4].decode(), struct.unpack("<I", d[j+4:j+8])[0]
                subs[t] = d[j+8:j+8+m]
                j += 8 + m + (m & 1)
            lists[kind] = (subs, d[i+8:i+8+n])     # parsed sub-chunks, and the raw LIST body
        i += 8 + n + (n & 1)
    sdta = lists["sdta"][0]
    if "sm24" in sdta:
        sys.exit(f"{path}: has sm24 (24-bit) data, which this script does not handle")
    pd = lists["pdta"][0]
    recs = {k: [pd[k][x:x+SIZES[k]] for x in range(0, len(pd[k]), SIZES[k])] for k in PDTA_ORDER}
    return {"info_raw": lists["INFO"][1], "smpl": bytearray(sdta["smpl"]), "recs": recs}


def u16(b, o): return struct.unpack_from("<H", b, o)[0]
def u32(b, o): return struct.unpack_from("<I", b, o)[0]


def preset_index(sf, bank, prog):
    P = sf["recs"]["phdr"]
    for k in range(len(P) - 1):                 # last record is the EOP terminator
        if u16(P[k], 20) == prog and u16(P[k], 22) == bank:
            return k
    return None


def zone_ranges(bags, k_lo, k_hi, gen_off, mod_off):
    """For bags [k_lo, k_hi): their (gen start, gen end) and (mod start, mod end)."""
    return ((u16(bags[k_lo], gen_off), u16(bags[k_hi], gen_off)),
            (u16(bags[k_lo], mod_off), u16(bags[k_hi], mod_off)))


def resolve(sf, pk):
    """Every (sample index) a preset ultimately plays, in a stable order."""
    R = sf["recs"]
    P, PB, PG, I, IB, IG = R["phdr"], R["pbag"], R["pgen"], R["inst"], R["ibag"], R["igen"]
    # Clamped to the last real bag: Zudio.sf2 as built by strip_sf2.py has EOI and EOP pointing
    # one past the terminal bag, so its last instrument and preset run off the end of the table.
    out = []
    for b in range(u16(P[pk], 24), min(u16(P[pk + 1], 24), len(PB) - 1)):
        for g in range(u16(PB[b], 0), u16(PB[b + 1], 0)):
            op, amt = struct.unpack("<HH", PG[g])
            if op != GEN_INSTRUMENT:
                continue
            for ib in range(u16(I[amt], 20), min(u16(I[amt + 1], 20), len(IB) - 1)):
                for ig in range(u16(IB[ib], 0), u16(IB[ib + 1], 0)):
                    op2, amt2 = struct.unpack("<HH", IG[ig])
                    if op2 == GEN_SAMPLE_ID:
                        out.append(amt2)
    return out


def pcm_hash(sf, samples):
    h = hashlib.sha256()
    S = sf["recs"]["shdr"]
    def pcm(s):
        return bytes(sf["smpl"][u32(S[s], 20) * 2:u32(S[s], 24) * 2])
    for s in samples:
        start = u32(S[s], 20)
        h.update(pcm(s))
        # Loop points relative to the sample, so a moved sample still compares equal.
        h.update(struct.pack("<II", u32(S[s], 28) - start, u32(S[s], 32) - start))
        h.update(S[s][36:42] + S[s][44:46])       # rate, pitch, correction, type
        if u16(S[s], 44) in (2, 4, 8):            # stereo partner, compared by its sound
            h.update(hashlib.sha256(pcm(u16(S[s], 42))).digest())
    return h.hexdigest()


# ---------------------------------------------------------------- copying

def copy_presets(src, dst, wanted):
    SR, DR = src["recs"], {k: list(v) for k, v in dst["recs"].items()}
    out = {"info_raw": dst["info_raw"], "smpl": bytearray(dst["smpl"]), "recs": DR}

    # Terminal records are rebuilt at the end; work on the bodies.
    term = {k: DR[k].pop() for k in PDTA_ORDER}

    pk_list = []
    for bank, prog in wanted:
        pk = preset_index(src, bank, prog)
        if pk is None:
            sys.exit(f"source has no preset {bank}:{prog}")
        if preset_index(dst, bank, prog) is not None:
            sys.exit(f"destination already has preset {bank}:{prog} — refusing to overwrite")
        pk_list.append(pk)

    # ---- which instruments and samples are needed, including stereo partners
    inst_needed, samp_needed = [], []
    P, PB, PG = SR["phdr"], SR["pbag"], SR["pgen"]
    I, IB, IG, S = SR["inst"], SR["ibag"], SR["igen"], SR["shdr"]
    for pk in pk_list:
        for b in range(u16(P[pk], 24), u16(P[pk + 1], 24)):
            for g in range(u16(PB[b], 0), u16(PB[b + 1], 0)):
                op, amt = struct.unpack("<HH", PG[g])
                if op == GEN_INSTRUMENT and amt not in inst_needed:
                    inst_needed.append(amt)
    for ik in inst_needed:
        for ib in range(u16(I[ik], 20), u16(I[ik + 1], 20)):
            for ig in range(u16(IB[ib], 0), u16(IB[ib + 1], 0)):
                op, amt = struct.unpack("<HH", IG[ig])
                if op == GEN_SAMPLE_ID and amt not in samp_needed:
                    samp_needed.append(amt)
    k = 0
    while k < len(samp_needed):                   # pull in linked (stereo) partners
        s = samp_needed[k]
        stype, link = u16(S[s], 44), u16(S[s], 42)
        if stype & 0x8000:
            sys.exit(f"sample {s} is ROM-based; cannot copy")
        if stype in (2, 4, 8) and link not in samp_needed:
            samp_needed.append(link)
        k += 1

    # ---- samples: append PCM, rebase offsets
    samp_map, region_map = {}, {}
    for s in samp_needed:
        rec = bytearray(S[s])
        start, end = u32(rec, 20), u32(rec, 24)
        if (start, end) not in region_map:
            new_start = len(out["smpl"]) // 2
            out["smpl"] += src["smpl"][start * 2:end * 2] + b"\0\0" * ZERO_PAD
            region_map[(start, end)] = new_start
        delta = region_map[(start, end)] - start
        for off in (20, 24, 28, 32):              # start, end, startloop, endloop
            struct.pack_into("<I", rec, off, u32(rec, off) + delta)
        samp_map[s] = len(DR["shdr"])
        DR["shdr"].append(rec)
    for s in samp_needed:                         # remap links once every new index is known
        rec = DR["shdr"][samp_map[s]]
        if u16(rec, 44) in (2, 4, 8):
            struct.pack_into("<H", rec, 42, samp_map[u16(rec, 42)])

    # ---- instruments: copy zones in order, rebase bag/gen/mod indices, remap sampleID
    inst_map = {}
    for ik in inst_needed:
        rec = bytearray(I[ik])
        struct.pack_into("<H", rec, 20, len(DR["ibag"]))
        inst_map[ik] = len(DR["inst"])
        DR["inst"].append(rec)
        for ib in range(u16(I[ik], 20), u16(I[ik + 1], 20)):
            bag = bytearray(IB[ib])
            struct.pack_into("<HH", bag, 0, len(DR["igen"]), len(DR["imod"]))
            DR["ibag"].append(bag)
            for ig in range(u16(IB[ib], 0), u16(IB[ib + 1], 0)):
                gen = bytearray(IG[ig])
                op, amt = struct.unpack("<HH", gen)
                if op == GEN_SAMPLE_ID:
                    struct.pack_into("<H", gen, 2, samp_map[amt])
                DR["igen"].append(gen)
            for im in range(u16(IB[ib], 2), u16(IB[ib + 1], 2)):
                DR["imod"].append(bytearray(SR["imod"][im]))

    # ---- presets: same, remapping the instrument generator
    for pk in pk_list:
        rec = bytearray(P[pk])
        struct.pack_into("<H", rec, 24, len(DR["pbag"]))
        DR["phdr"].append(rec)
        for b in range(u16(P[pk], 24), u16(P[pk + 1], 24)):
            bag = bytearray(PB[b])
            struct.pack_into("<HH", bag, 0, len(DR["pgen"]), len(DR["pmod"]))
            DR["pbag"].append(bag)
            for g in range(u16(PB[b], 0), u16(PB[b + 1], 0)):
                gen = bytearray(PG[g])
                op, amt = struct.unpack("<HH", gen)
                if op == GEN_INSTRUMENT:
                    struct.pack_into("<H", gen, 2, inst_map[amt])
                DR["pgen"].append(gen)
            for m in range(u16(PB[b], 2), u16(PB[b + 1], 2)):
                DR["pmod"].append(bytearray(SR["pmod"][m]))

    # ---- terminal records point one past the end of their tables
    eop = bytearray(term["phdr"]);  struct.pack_into("<H", eop, 24, len(DR["pbag"]))
    pbt = bytearray(term["pbag"]);  struct.pack_into("<HH", pbt, 0, len(DR["pgen"]), len(DR["pmod"]))
    eoi = bytearray(term["inst"]);  struct.pack_into("<H", eoi, 20, len(DR["ibag"]))
    ibt = bytearray(term["ibag"]);  struct.pack_into("<HH", ibt, 0, len(DR["igen"]), len(DR["imod"]))
    for k, t in (("phdr", eop), ("pbag", pbt), ("inst", eoi), ("ibag", ibt),
                 ("pmod", term["pmod"]), ("pgen", term["pgen"]),
                 ("imod", term["imod"]), ("igen", term["igen"]), ("shdr", term["shdr"])):
        DR[k].append(t)
    return out, pk_list, len(inst_needed), len(samp_needed), len(region_map)


# ---------------------------------------------------------------- writing

def chunk(tag, body):
    b = tag.encode() + struct.pack("<I", len(body)) + body
    return b + (b"\0" if len(body) & 1 else b"")

def write_sf2(sf, path):
    info = b"LIST" + struct.pack("<I", len(sf["info_raw"])) + sf["info_raw"]
    if len(sf["info_raw"]) & 1: info += b"\0"
    sdta_body = b"sdta" + chunk("smpl", bytes(sf["smpl"]))
    pdta_body = b"pdta" + b"".join(chunk(k, b"".join(bytes(r) for r in sf["recs"][k])) for k in PDTA_ORDER)
    body = b"sfbk" + info + \
           b"LIST" + struct.pack("<I", len(sdta_body)) + sdta_body + \
           b"LIST" + struct.pack("<I", len(pdta_body)) + pdta_body
    Path(path).write_bytes(b"RIFF" + struct.pack("<I", len(body)) + body)


# ---------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    ap.add_argument("--src", default="GeneralUser-GS.sf2")
    ap.add_argument("--dst", default="assets/Zudio.sf2")
    ap.add_argument("--out", default="assets/Zudio.sf2.new")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("presets", nargs="*", help="bank:program, e.g. 0:26")
    a = ap.parse_args()
    wanted = [tuple(int(x) for x in p.split(":")) for p in a.presets] or PRESETS

    src, dst = read_sf2(a.src), read_sf2(a.dst)
    before = {}
    D = dst["recs"]["phdr"]
    for k in range(len(D) - 1):
        key = (u16(D[k], 22), u16(D[k], 20), D[k][:20])
        before[key] = pcm_hash(dst, resolve(dst, k))

    out, pks, n_inst, n_samp, n_regions = copy_presets(src, dst, wanted)
    added_mb = (len(out["smpl"]) - len(dst["smpl"])) / 1e6
    print(f"copying {len(pks)} presets: {n_inst} instruments, {n_samp} samples "
          f"({n_regions} PCM regions), +{added_mb:.2f} MB of sample data")
    for pk in pks:
        r = src["recs"]["phdr"][pk]
        name = r[:20].split(b"\0")[0].decode("latin1")
        print(f"   {u16(r, 22):3d}:{u16(r, 20):03d}  {name}")
    if a.dry_run:
        print("dry run — nothing written"); return

    write_sf2(out, a.out)

    # ---- verify by re-reading what was written
    chk = read_sf2(a.out)
    C, problems = chk["recs"]["phdr"], 0
    seen = {}
    for k in range(len(C) - 1):
        seen[(u16(C[k], 22), u16(C[k], 20), C[k][:20])] = k
    for key, h in before.items():
        if key not in seen:
            print(f"   MISSING existing preset {key[0]}:{key[1]}"); problems += 1
        elif pcm_hash(chk, resolve(chk, seen[key])) != h:
            print(f"   CHANGED existing preset {key[0]}:{key[1]}"); problems += 1
    for pk in pks:
        r = src["recs"]["phdr"][pk]
        key = (u16(r, 22), u16(r, 20), r[:20])
        if key not in seen:
            print(f"   new preset {key[0]}:{key[1]} not found"); problems += 1
        elif pcm_hash(chk, resolve(chk, seen[key])) != pcm_hash(src, resolve(src, pk)):
            print(f"   new preset {key[0]}:{key[1]} does not match the source"); problems += 1
    print(f"verified {len(before)} existing presets unchanged and {len(pks)} copied presets "
          f"identical to source — {problems} problems")
    print(f"wrote {a.out}  ({Path(a.dst).stat().st_size/1e6:.1f} MB -> {Path(a.out).stat().st_size/1e6:.1f} MB)")
    if problems:
        sys.exit(1)

if __name__ == "__main__":
    main()
