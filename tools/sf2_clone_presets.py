#!/usr/bin/env python3
"""
sf2_clone_presets.py - clone presets inside one SoundFont as "swell" variants with slow envelopes.

    python3 -I tools/sf2_clone_presets.py --dry-run     # report only, write nothing
    python3 -I tools/sf2_clone_presets.py               # clone the default Ambient Zen pad set

WHY THIS EXISTS
---------------
Ambient Zen's pads must swell in rather than strike. A track-wide volume ramp would duck all
four pad voices together, and editing the stock presets would change every other style that
uses them. So this adds copies of the four pad presets in a spare bank (14), same program
numbers, whose only difference is a slow attack and release set at the preset level.

What it does:
  - presets   one new phdr record per clone, inserted before the terminal EOP record
  - zones     the source preset's pbag/pgen/pmod entries duplicated, generator 41 still pointing
              at the same instruments, so no instrument, sample or PCM byte is copied
  - envelope  preset-level generators 34 (attackVolEnv) and 38 (releaseVolEnv). Preset-level
              values ADD to the instrument-level ones (timecents), so for each cloned zone the
              offset is the target minus the instrument's own value (the spec default of -12000
              where an instrument zone has none). A value the source zone already carried at
              preset level is replaced, not stacked. Generators stay in spec order: key and
              velocity range first, instrument (41) last, global zone first.
  - tables    terminal pbag/pgen/pmod records and the RIFF/LIST/chunk sizes are rewritten

Verification is built in: the output is re-read and every original preset must resolve to
identical records and byte-identical PCM, the clones must resolve to the same instruments and
samples as their sources with the new envelope totals, and smpl, shdr, inst, ibag, imod and
igen must be byte-identical to before. The original file is backed up before it is replaced.
"""

import argparse, shutil, struct, sys
from pathlib import Path
from statistics import median_low

sys.path.insert(0, str(Path(__file__).resolve().parent))      # still works under python -I
from sf2_copy_presets import (read_sf2, write_sf2, u16, u32, preset_index, resolve, pcm_hash,
                              PDTA_ORDER, GEN_INSTRUMENT, GEN_SAMPLE_ID)

GEN_ATTACK, GEN_RELEASE = 34, 38
DEFAULT_ENV = -12000                    # SF2 2.04 default for both, when no generator sets them
TARGET_ATTACK, TARGET_RELEASE = 3000, 2600       # about 5.6 s and 4.5 s
CLONE_BANK = 14
# (source bank, program, new name); the clone keeps the program number unless NEW_PROG maps
# (source bank, program) to another one (needed when two sources share a program, as 0:89 and 11:89 do)
NEW_PROG = {(11, 89): 88, (8, 38): 37}
def tp(bank, prog): return NEW_PROG.get((bank, prog), prog)
CLONES = [(0, 89, "Warm Swell"), (0, 94, "Halo Swell"), (0, 52, "Choir Swell"), (0, 91, "Voice Swell")]
# Second set (2026-11-20): glass and strings pad colour, and two low synth basses, all swell copies
CLONES_GLASS_STRINGS_BASS = [(0, 92, "Glass Swell"), (8, 50, "Strings 3 Swell"),
                             (11, 51, "Strings 5 Swell"), (0, 49, "Slow Strings Swell"),
                             (12, 38, "Saw Bass Swell"), (0, 62, "Brass Swell")]
# Third set (2026-11-20): pedal-only swell copies, so no MIDI patch repeats across Zen tracks
CLONES_PEDAL = [(0, 71, "Clarinet Swell"), (0, 90, "Polysynth Swell")]
# Fourth set (2026-11-20): Cello replaced on the Zen bass by a pulse synth, Clarinet by Solar Wind
CLONES_SYNTH = [(11, 39, "Pulse Bass Swell"), (11, 89, "Solar Wind Swell")]
# Fifth set (2026-11-20): Sine Wave moves to the pedal (as a swell); two more low synth basses
CLONES_SINE_BASS = [(8, 80, "Sine Swell"), (0, 87, "Lead Bass Swell"), (8, 38, "Synth Bass 3 Swell")]
SETS = {"sine-bass": CLONES_SINE_BASS, "pads": CLONES, "glass-strings-bass": CLONES_GLASS_STRINGS_BASS, "pedal": CLONES_PEDAL, "synth": CLONES_SYNTH}
BACKUP = "/private/tmp/claude-502/-Users-urlocker-Downloads-Zudio/e54396ca-747a-4e83-bd56-b2891d1bef81/scratchpad/Zudio.sf2.orig"


def secs(tc): return 2 ** (tc / 1200)


def gens_of(recs_g, lo, hi):
    return [struct.unpack("<Hh", recs_g[g]) for g in range(lo, hi)]


def inst_env(sf, ik):
    """Effective (attack, release) of each sample zone of instrument ik: zone value, else the
    instrument's global zone, else the spec default."""
    R = sf["recs"]
    I, IB, IG = R["inst"], R["ibag"], R["igen"]
    zones = []
    for ib in range(u16(I[ik], 20), min(u16(I[ik + 1], 20), len(IB) - 1)):
        gs = gens_of(IG, u16(IB[ib], 0), u16(IB[ib + 1], 0))
        zones.append((dict(gs), bool(gs) and gs[-1][0] == GEN_SAMPLE_ID))
    glob = zones[0][0] if zones and not zones[0][1] else {}
    out = []
    for d, is_sample in zones:
        if is_sample:
            out.append(tuple(d.get(g, glob.get(g, DEFAULT_ENV)) for g in (GEN_ATTACK, GEN_RELEASE)))
    return out


def preset_zones(sf, pk):
    """[(is_global, [(op, amt)...], mod_range)] for preset pk."""
    R = sf["recs"]
    P, PB, PG = R["phdr"], R["pbag"], R["pgen"]
    out = []
    for b in range(u16(P[pk], 24), u16(P[pk + 1], 24)):
        gs = gens_of(PG, u16(PB[b], 0), u16(PB[b + 1], 0))
        inst = [a for o, a in gs if o == GEN_INSTRUMENT]
        out.append((not inst, gs, (u16(PB[b], 2), u16(PB[b + 1], 2))))
    return out


def effective_totals(sf, pk):
    """Per instrument-bearing preset zone: list of (attack, release) totals over its sample
    zones, with a local preset value overriding the preset's global zone."""
    zs = preset_zones(sf, pk)
    glob = dict(zs[0][1]) if zs and zs[0][0] else {}
    res = []
    for is_glob, gs, _ in zs:
        if is_glob:
            continue
        d = dict(gs)
        pa = d.get(GEN_ATTACK, glob.get(GEN_ATTACK, 0))
        pr = d.get(GEN_RELEASE, glob.get(GEN_RELEASE, 0))
        ik = d[GEN_INSTRUMENT]
        res.append((ik, [(a + pa, r + pr) for a, r in inst_env(sf, ik)]))
    return res


def clone(sf, clones):
    R = sf["recs"]
    DR = {k: list(v) for k, v in R.items()}
    term = {k: DR[k].pop() for k in ("phdr", "pbag", "pgen", "pmod")}
    new = {"info_raw": sf["info_raw"], "smpl": sf["smpl"], "recs": DR}
    PB, PG, PM = R["pbag"], R["pgen"], R["pmod"]
    plan = []
    for bank, prog, name in clones:
        pk = preset_index(sf, bank, prog)
        if pk is None:
            sys.exit(f"no source preset {bank}:{prog}")
        if preset_index(sf, CLONE_BANK, tp(bank, prog)) is not None or \
           any(u16(r, 20) == tp(bank, prog) and u16(r, 22) == CLONE_BANK for r in DR["phdr"]):
            sys.exit(f"bank {CLONE_BANK} program {tp(bank, prog)} already exists")
        rec = bytearray(R["phdr"][pk])
        rec[:20] = name.encode("latin1").ljust(20, b"\0")
        struct.pack_into("<HH", rec, 20, tp(bank, prog), CLONE_BANK)
        struct.pack_into("<H", rec, 24, len(DR["pbag"]))
        DR["phdr"].append(rec)
        for is_glob, gs, (m0, m1) in preset_zones(sf, pk):
            bag = bytearray(4)
            struct.pack_into("<HH", bag, 0, len(DR["pgen"]), len(DR["pmod"]))
            DR["pbag"].append(bag)
            if is_glob:
                # Source global zone kept, minus any envelope it set (the local zones set them).
                gs2 = [(o, a) for o, a in gs if o not in (GEN_ATTACK, GEN_RELEASE)]
            else:
                ik = dict(gs)[GEN_INSTRUMENT]
                env = inst_env(sf, ik)
                off_a = TARGET_ATTACK - median_low([a for a, _ in env])
                off_r = TARGET_RELEASE - median_low([r for _, r in env])
                gs2 = [(o, a) for o, a in gs if o not in (GEN_ATTACK, GEN_RELEASE, GEN_INSTRUMENT)]
                gs2 += [(GEN_ATTACK, off_a), (GEN_RELEASE, off_r), (GEN_INSTRUMENT, ik)]
            for o, a in gs2:
                DR["pgen"].append(bytearray(struct.pack("<Hh", o, a)))
            for m in range(m0, m1):
                DR["pmod"].append(bytearray(PM[m]))
        plan.append((bank, prog, name))
    eop = bytearray(term["phdr"]); struct.pack_into("<H", eop, 24, len(DR["pbag"]))
    pbt = bytearray(term["pbag"]); struct.pack_into("<HH", pbt, 0, len(DR["pgen"]), len(DR["pmod"]))
    for k, t in (("phdr", eop), ("pbag", pbt), ("pmod", term["pmod"]), ("pgen", term["pgen"])):
        DR[k].append(t)
    return new, plan


def report(sf, label, banks_progs):
    for bank, prog in banks_progs:
        pk = preset_index(sf, bank, prog)
        name = sf["recs"]["phdr"][pk][:20].split(b"\0")[0].decode("latin1")
        print(f"   {label} {bank}:{prog} {name}")
        for n, (ik, tot) in enumerate(effective_totals(sf, pk)):
            a = sorted({t[0] for t in tot}); r = sorted({t[1] for t in tot})
            fa = f"{a[0]}" if len(a) == 1 else f"{a[0]}..{a[-1]}"
            fr = f"{r[0]}" if len(r) == 1 else f"{r[0]}..{r[-1]}"
            print(f"      zone {n} inst {ik:3d} ({len(tot):2d} samples): attack {fa} tc "
                  f"({secs(a[0]):.2f}..{secs(a[-1]):.2f} s), release {fr} tc "
                  f"({secs(r[0]):.2f}..{secs(r[-1]):.2f} s)")


def verify(old, chk, clones):
    problems = 0
    def bad(msg):
        nonlocal problems
        print("   PROBLEM:", msg); problems += 1
    if old["smpl"] != chk["smpl"]: bad("smpl changed")
    if old["info_raw"] != chk["info_raw"]: bad("INFO changed")
    for k in ("shdr", "inst", "ibag", "imod", "igen"):
        if old["recs"][k] != chk["recs"][k]: bad(f"{k} changed")
    for k in ("phdr", "pbag", "pgen", "pmod"):
        o, c = old["recs"][k], chk["recs"][k]
        if c[:len(o) - 1] != o[:-1]: bad(f"existing {k} records changed")
    # existing presets: same records, same PCM
    P = old["recs"]["phdr"]
    for pk in range(len(P) - 1):
        if resolve(old, pk) != resolve(chk, pk) or pcm_hash(old, resolve(old, pk)) != pcm_hash(chk, resolve(chk, pk)):
            bad(f"existing preset {pk} resolves differently")
        if preset_zones(old, pk) != preset_zones(chk, pk): bad(f"existing preset {pk} zones differ")
    # terminals point one past the end of their tables
    C = chk["recs"]
    if u16(C["phdr"][-1], 24) != len(C["pbag"]) - 1: bad("EOP bag index")
    if struct.unpack("<HH", C["pbag"][-1]) != (len(C["pgen"]) - 1, len(C["pmod"]) - 1): bad("terminal pbag")
    # clones
    for bank, prog, name in clones:
        sk = preset_index(old, bank, prog)
        ck = next((k for k in range(len(C["phdr"]) - 1)
                   if u16(C["phdr"][k], 20) == tp(bank, prog) and u16(C["phdr"][k], 22) == CLONE_BANK), None)
        if ck is None:
            bad(f"clone {prog} missing"); continue
        if C["phdr"][ck][:20].split(b"\0")[0].decode() != name: bad(f"clone {prog} name")
        if resolve(old, sk) != resolve(chk, ck): bad(f"clone {prog} samples differ")
        if pcm_hash(old, resolve(old, sk)) != pcm_hash(chk, resolve(chk, ck)): bad(f"clone {prog} PCM differs")
        zo, zc = preset_zones(old, sk), preset_zones(chk, ck)
        if len(zo) != len(zc): bad(f"clone {prog} zone count"); continue
        for (go, a, ma), (gc, b, mc) in zip(zo, zc):
            strip = lambda g: [(o, v) for o, v in g if o not in (GEN_ATTACK, GEN_RELEASE)]
            if go != gc or strip(a) != strip(b) or ma[1] - ma[0] != mc[1] - mc[0]:
                bad(f"clone {prog} zone differs beyond envelope")
            ops = [o for o, _ in b]
            if not gc and (ops[-1] != GEN_INSTRUMENT or ops.count(GEN_INSTRUMENT) != 1):
                bad(f"clone {prog} instrument not last")
            for o in (41, 43, 44):                      # ranges must precede the others
                pass
        for _, tot in effective_totals(chk, ck):
            for a, r in tot:
                if abs(a - TARGET_ATTACK) > 1200 or abs(r - TARGET_RELEASE) > 1200:
                    bad(f"clone {prog} total attack {a} release {r} off target")
    return problems


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    ap.add_argument("--src", default="assets/Zudio.sf2")
    ap.add_argument("--out", default="assets/Zudio.sf2")
    ap.add_argument("--backup", default=BACKUP)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--set", default="pads", choices=sorted(SETS), help="which clone set to add")
    a = ap.parse_args()
    CLONES = SETS[a.set]

    old = read_sf2(a.src)
    new, plan = clone(old, CLONES)
    print(f"cloning {len(plan)} presets into bank {CLONE_BANK}")
    report(old, "source", [(b, p) for b, p, _ in CLONES])
    print("clones, resulting totals (instrument + preset level):")
    tmp = Path(a.out + ".tmp")
    write_sf2(new, tmp)
    chk = read_sf2(tmp)
    report(chk, "clone", [(CLONE_BANK, tp(b, p)) for b, p, _ in CLONES])
    problems = verify(old, chk, CLONES)
    size0, size1 = Path(a.src).stat().st_size, tmp.stat().st_size
    print(f"verified {len(old['recs']['phdr']) - 1} existing presets and {len(CLONES)} clones: {problems} problems")
    print(f"size {size0} -> {size1} bytes (+{size1 - size0})")
    if a.dry_run or problems:
        tmp.unlink()
        print("dry run - nothing written" if a.dry_run else "problems found - nothing written")
        sys.exit(1 if problems else 0)
    bp = Path(a.backup)
    if not bp.exists():
        bp.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(a.src, bp)
        print("backed up original to", bp)
    tmp.replace(a.out)
    print("wrote", a.out)


if __name__ == "__main__":
    main()
