#!/usr/bin/env python3
"""jarre_deep.py — role-aware analysis of the Kosmic Space corpus.

Usage:
    python3 tools/jarre_deep.py [dir] [--only SUBSTR] [--sections] [--harmony]
                                [--seq] [--bass] [--lead] [--drums] [--pads] [--tex]
                                [--interplay]
    (no section flags = all of them)

jarre_analyze.py guesses each part's role from register and density, which misfiles
Jarre's parts often (a sequencer bass reads as BASS, a busy lead as RHYTHM). This tool
uses a hand-made ROLES map instead, built from jarre_survey.py, so every measurement is
taken from the part that actually plays that role.

Passes:
  sections  per-4-bar activity of each role, segmented into sections where the set of
            playing roles or the density changes — the form of the piece
  harmony   per-bar chord (root from bass, quality from chordal parts), compressed into
            chord windows: harmonic rhythm, progression as degrees, mode
  seq       sequencer cells: period, notes per cell, pitch vocabulary, the cell's shape
            relative to the chord root, and how often it changes
  bass      bass bar patterns: onsets per bar, rhythm grid, pitch motion
  lead      lead phrases: length, span, intervals, endings, recurring figures, and the
            repetition form (A A B A ...) of the phrases
  drums     per-voice step grids of the commonest bar

Files listed in HALF_TIME were transcribed in double time; their beats are halved so
every figure is in real beats and real bars.
"""
import sys, os, glob, statistics, collections

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from jarre_survey import load_parts, bar_len  # noqa: E402

NAMES = "C Db D Eb E F Gb G Ab A Bb B".split()
DEG = ["I", "bII", "II", "bIII", "III", "IV", "bV", "V", "bVI", "VI", "bVII", "VII"]

# Role map: file-name prefix -> {role: [(track_name, channel), ...]}. The first entry of
# each role is the primary part; the rest are doublings or secondary parts of that role.
ROLES = {
    "Arpegiator": {
        "bass": [("Synth bass", 1)], "seq": [("Synth bass", 4), ("Whistle", 5)],
        "lead": [("Solo bass", 7)], "pads": [("Slow strings", 2)], "drums": [("Drums", 9)],
    },
    "Chronologie_2": {
        "bass": [("Ligne Basse", 5), ("Bass Synthé", 0)], "seq": [("Sequence", 3)],
        "lead": [("Lead", 0)], "lead2": [("Chorus Synth", 1)],
        "pads": [("Nappes", 4), ("Choeurs", 2)], "tex": [("Glissades Chromatiques", 6)],
        "drums": [("Drums", 9), ("Percussions", 9)],
    },
    "Chronologie_4": {
        "bass": [("Bas", 1)], "seq": [("Tic-tac", 6)], "lead": [("Melodie", 3)],
        "lead2": [("Arp", 7)], "pads": [("Nappes-1", 4), ("Nappes-2", 4)],
        "tex": [("Sonnerie", 8), ("Analog Nse", 5), ("Synth-2", 2)],
        "drums": [("Bas-drum", 9), ("Snare drum", 9), ("Clsd HghHt", 9)],
    },
    "Chronologie_5": {
        "bass": [("Double Bass", 7), ("Str. Bass / Bass", 1)], "seq": [("Synthe2", 2), ("Sequence", 4)],
        "lead": [("Solo", 0)], "pads": [("Synthe Intro", 6), ("Nappes", 3), ("Voice Intro", 5)],
        "tex": [("Alarme", 8)],
        "drums": [("Pied", 9), ("Percu", 9), ("Tic-Tac", 9), ("Tic-Tac 2", 9)],
    },
    "Equinoxe": {
        "bass": [("track2", 1)], "seq": [("track4", 3)], "lead": [("track5", 4)],
        "lead2": [("track1", 0)], "pads": [("track3", 2), ("track6", 5)],
        "tex": [("track9", 8)],
        "drums": [("track15", 9), ("track13", 9), ("track11", 9), ("track14", 9), ("track12", 9)],
    },
    "Magnetic_Fields_1": {
        "bass": [("bass", 3)], "seq": [("seq1l", 4)], "lead": [("fiddle", 0)],
        "pads": [("strings", 2), ("choir", 1)], "tex": [("pitch", 6), ("sound", 7)],
        "drums": [("bass", 9), ("open2", 9), ("open", 9), ("pot", 9), ("tussenhih", 9)],
    },
    "Magnetic_Fields_2": {
        "bass": [("bass", 2), ("PPgbass", 8)], "lead": [("SOLO", 0)],
        "lead2": [("lead2 2", 4), ("lead2", 3), ("lead   1", 7)],
        "pads": [("Nappes", 11), ("chord", 5)], "tex": [("Echo", 1), ("live", 10)],
        "drums": [("Percussion", 9), ("drums li", 9)],
    },
    "Magnetic_Fields_4": {
        "bass": [("Bass", 0)], "lead": [("SOLO", 1)], "seq": [("Wah Wah", 3)],
        "pads": [("Brass Accomp", 2), ("String Chords", 4)], "tex": [("Agogo", 5)],
        "drums": [("High Hat Tap", 9), ("Tom Tom", 9), ("Snare", 9), ("Toms", 9)],
    },
    "Magnetic_Fields_5": {
        "bass": [("Bass", 3)], "seq": [("Piano", 4)], "lead": [("SOLO", 0)],
        "drums": [("Drums", 9)],
    },
    "Oxygene_3": {
        "bass": [("track4", 2)], "lead": [("track1", 7)], "pads": [("track3", 1)],
        "tex": [("track2", 15)], "drums": [("track6", 9)],
    },
    "Oxygene_4__Oxygene-_Part-4_-1": {
        "bass": [("track0", 1)], "seq": [("track0", 10)], "lead": [("track0", 4)],
        "lead2": [("track0", 6), ("track0", 3), ("track0", 5)],
        "pads": [("track0", 2), ("track0", 7), ("track0", 11)],
        "tex": [("track0", 12), ("track0", 8)], "drums": [("track0", 9)],
    },
    "Oxygene_4__Oxygene-_Part-4_-2": {
        "bass": [("FRETLESS", 1)], "seq": [("KALIMBA", 2)], "lead": [("SYN STR 2", 7)],
        "lead2": [("SYNBRASS 2", 3), ("SITAR", 10)],
        "pads": [("SYN STR 2", 4), ("BOWEDGLASS", 8)], "drums": [("DRUMS", 9)],
    },
    "Oxygene_6": {
        "bass": [("FRETLESS", 5)], "seq": [("SYN STR 2", 3)], "lead": [("STRINGS", 4)],
        "pads": [("SYN STR 2", 6)], "tex": [("SEASHORE", 1), ("CHOIR AAHS", 2)],
        "drums": [("DRUMS", 9)],
    },
    "Oxygene_8": {
        "bass": [("SYNTHBASS1", 5)], "lead": [("ALTOSAX", 1)], "lead2": [("SHININGSTR", 6)],
        "seq": [("HARPSICHOD", 11), ("REVERSECYL", 10)],
        "pads": [("STRINGS", 4), ("SYNSTRING", 0)], "tex": [("SEASHORE", 7)],
        "drums": [("DRUMS", 9)],
    },
    "Oxygene__Oxygene": {
        "bass": [("Fretless Bass", 3)],
        "pads": [("synth strings 2", 1), ("Slow Strings", 4), ("Strings", 5), ("Bowed Pad", 7), ("Choir Aahs", 2)],
        "tex": [("gun shot", 6)], "drums": [("Drums", 9)],
    },
    "Rendez-Vous_2": {
        "bass": [("STRINGS", 4), ("TROMBONE", 5), ("SYN BASS 1", 8)],
        "seq": [("SYN STR 1", 2), ("SYN STR 2", 1), ("TINKLEBELL", 14)],
        "lead": [("CHOIR AAHS", 6), ("FANTASIA", 11)], "lead2": [("SYNVOX", 13)],
        "pads": [("SYN STR 2", 3), ("SYN STR 2", 15)], "tex": [("GOBLIN", 12)],
        "drums": [("DRUMS", 9)],
    },
}
HALF_TIME = {"Magnetic_Fields_2", "Magnetic_Fields_4"}
ROLE_ORDER = ["drums", "bass", "seq", "pads", "lead", "lead2", "tex"]
ABBR = {"drums": "Dr", "bass": "Bs", "seq": "Sq", "pads": "Pd", "lead": "L1", "lead2": "L2", "tex": "Tx"}

MODES = {
    "Ionian": [0, 2, 4, 5, 7, 9, 11], "Dorian": [0, 2, 3, 5, 7, 9, 10],
    "Phrygian": [0, 1, 3, 5, 7, 8, 10], "Lydian": [0, 2, 4, 6, 7, 9, 11],
    "Mixolydian": [0, 2, 4, 5, 7, 9, 10], "Aeolian": [0, 2, 3, 5, 7, 8, 10],
    "HarmMinor": [0, 2, 3, 5, 7, 8, 11],
}


def file_key(path):
    base = os.path.basename(path)
    for k in sorted(ROLES, key=len, reverse=True):
        if base.startswith(k):
            return k
    return None


class Song:
    def __init__(self, path):
        self.path, self.key = path, file_key(path)
        parts, tpb, tempos, meters, _ = load_parts(path)
        self.half = self.key in HALF_TIME
        self.tpb = tpb * (2 if self.half else 1)        # ticks per REAL beat
        self.step = self.tpb // 4                       # ticks per real sixteenth
        self.bar = self.tpb * 4                         # 4/4 real bars throughout
        self.tempo = (tempos[0][1] if tempos else 120.0) / (2 if self.half else 1)
        self.roles = {}
        for role, keys in ROLES[self.key].items():
            got = [parts[k]["notes"] for k in keys if k in parts and parts[k]["notes"]]
            if got:
                self.roles[role] = got
        allnotes = [n for p in parts.values() for n in p["notes"]]
        self.nbars = max(n[0] + n[3] for n in allnotes) // self.bar + 1
        self.parts = parts

    def notes(self, role, primary=True):
        ps = self.roles.get(role, [])
        if not ps:
            return []
        return ps[0] if primary else sorted(n for p in ps for n in p)


def pc_profile(notes, weight_dur=True):
    h = [0.0] * 12
    for n in notes:
        h[n[1] % 12] += (n[3] if weight_dur else 1)
    return h


def best_mode(hist, tonic_hint=None):
    """Return (tonic_pc, mode, fit) maximising weight inside the scale, with the tonic's
    own weight as tie-breaker."""
    tot = sum(hist) or 1
    best = None
    for t in range(12):
        for name, sc in MODES.items():
            inside = sum(hist[(t + i) % 12] for i in sc) / tot
            score = inside + 0.15 * hist[t] / tot + 0.05 * hist[(t + 7) % 12] / tot
            if tonic_hint is not None and t == tonic_hint:
                score += 0.04
            if best is None or score > best[0]:
                best = (score, t, name, inside)
    return best[1], best[2], best[3]


# ----------------------------------------------------------------------------- sections

def pass_sections(s):
    blk = 4
    nblk = (s.nbars + blk - 1) // blk
    act = {r: [0] * nblk for r in s.roles}
    for r in s.roles:
        for n in s.notes(r, primary=False):
            act[r][(n[0] // s.bar) // blk] += 1
    rows = []
    for b in range(nblk):
        playing = frozenset(r for r in s.roles if act[r][b] >= 2)
        dens = sum(act[r][b] for r in s.roles if r != "drums") / (blk * 4)
        rows.append((playing, dens))
    # segment: new section when the playing set changes by more than one role, or density
    # jumps by 2x, sustained for at least 2 blocks
    segs, start = [], 0
    for b in range(1, nblk + 1):
        if b == nblk:
            segs.append((start, b)); break
        a, d = rows[start]
        c, e = rows[b]
        sym = len(a ^ c)
        ratio = (max(d, e) + 0.1) / (min(d, e) + 0.1)
        if sym >= 2 or ratio >= 2.0 or (sym == 1 and ("drums" in (a ^ c) or "seq" in (a ^ c) or "lead" in (a ^ c))):
            segs.append((start, b)); start = b
    # merge one-block blips into the previous section
    merged = []
    for a, b in segs:
        if merged and b - a == 1:
            merged[-1] = (merged[-1][0], b)
        else:
            merged.append((a, b))
    print(f"  SECTIONS (4-bar blocks, real bars; tempo {s.tempo:g}, {s.nbars} bars, "
          f"{s.nbars * 4 * 60 / s.tempo / 60:.1f} min)")
    for a, b in merged:
        roles = collections.Counter()
        for i in range(a, b):
            roles.update(rows[i][0])
        keep = [ABBR[r] for r in ROLE_ORDER if roles[r] * 2 >= (b - a)]
        dens = statistics.mean(rows[i][1] for i in range(a, b))
        dr = sum(act.get("drums", [0] * nblk)[i] for i in range(a, b)) / ((b - a) * blk * 4)
        print(f"    bars {a * blk + 1:3}-{min(b * blk, s.nbars):3} ({(b - a) * blk:3} bars)  "
              f"{' '.join(keep):22} melodic {dens:4.1f}/beat  drums {dr:4.1f}/beat")


# ----------------------------------------------------------------------------- harmony

QUAL = [
    (frozenset({0, 3, 7, 10, 2}), "m9"), (frozenset({0, 4, 7, 11, 2}), "maj9"),
    (frozenset({0, 4, 7, 10, 2}), "9"), (frozenset({0, 3, 7, 10}), "m7"),
    (frozenset({0, 4, 7, 11}), "maj7"), (frozenset({0, 4, 7, 10}), "7"),
    (frozenset({0, 3, 7, 2}), "madd9"), (frozenset({0, 4, 7, 2}), "add9"),
    (frozenset({0, 3, 7}), "m"), (frozenset({0, 4, 7}), ""),
    (frozenset({0, 5, 7}), "sus4"), (frozenset({0, 2, 7}), "sus2"),
    (frozenset({0, 3, 6}), "dim"), (frozenset({0, 4, 8}), "aug"), (frozenset({0, 7}), "5"),
]


def quality(rel):
    best, sc = "?", -1
    for iv, nm in QUAL:
        if iv <= rel and len(iv) > sc:
            best, sc = nm, len(iv)
    return best


def bar_chords(s):
    bass = s.notes("bass", primary=False)
    chordal = s.notes("pads", primary=False) + s.notes("seq", primary=False)
    out = []
    for b in range(s.nbars):
        lo, hi = b * s.bar, (b + 1) * s.bar

        def w(ns):
            h = [0.0] * 12
            for n in ns:
                st, en = max(n[0], lo), min(n[0] + n[3], hi)
                if en > st:
                    h[n[1] % 12] += en - st
            return h
        bh, ch = w(bass), w(chordal)
        if sum(bh) == 0 and sum(ch) == 0:
            out.append(None); continue
        # root: the bass pitch class sounding longest; fall back to the lowest chordal note
        if sum(bh):
            root = max(range(12), key=lambda p: bh[p])
        else:
            lows = [n for n in chordal if n[0] < hi and n[0] + n[3] > lo]
            root = min(lows, key=lambda n: n[1])[1] % 12
        tot = sum(ch) + sum(bh)
        pcs = {p for p in range(12) if (ch[p] + bh[p]) / tot >= 0.08}
        rel = frozenset((p - root) % 12 for p in pcs) | {0}
        out.append((root, quality(rel)))
    return out


def pass_harmony(s):
    chords = bar_chords(s)
    melodic = [n for r in ("bass", "seq", "pads", "lead", "lead2") for n in s.notes(r, primary=False)]
    tonic, mode, fit = best_mode(pc_profile(melodic))
    # chord windows
    wins = []
    for b, c in enumerate(chords):
        if c is None:
            continue
        if wins and wins[-1][2] == c and wins[-1][1] == b:
            wins[-1][1] = b + 1
        else:
            wins.append([b, b + 1, c])
    # a one-bar window between two equal chords is a passing chord, not a change
    lens = [w[1] - w[0] for w in wins]
    roots = collections.Counter(w[2][0] for w in wins)
    print(f"  HARMONY  key {NAMES[tonic]} {mode} (scale fit {fit:.0%})  "
          f"{len(wins)} chord windows, {len(roots)} distinct roots, "
          f"window length median {statistics.median(lens) if lens else 0} bars "
          f"(p25 {sorted(lens)[len(lens) // 4] if lens else 0}, max {max(lens) if lens else 0})")
    seq = []
    for a, b, (r, q) in wins:
        seq.append(f"{DEG[(r - tonic) % 12]}{q}x{b - a}")
    line, outl = "", []
    for item in seq:
        if len(line) + len(item) > 92:
            outl.append(line); line = ""
        line += item + " "
    outl.append(line)
    for l in outl[:8]:
        print("    " + l)
    if len(outl) > 8:
        print(f"    ... (+{len(outl) - 8} lines)")
    qual = collections.Counter(w[2][1] for w in wins)
    print("    qualities: " + ", ".join(f"{q or 'maj'} {c}" for q, c in qual.most_common(8)))


# ----------------------------------------------------------------------------- sequencer

def period(seq, maxp=32):
    """Smallest period p (2..maxp) such that seq[i] == seq[i+p] for >=85% of i."""
    n = len(seq)
    for p in range(2, maxp + 1):
        if n < 2 * p:
            break
        same = sum(1 for i in range(n - p) if seq[i] == seq[i + p])
        if same / (n - p) >= 0.85:
            return p
    return None


def step_grid(notes, s, bars):
    """{bar: {step: pitch}} for the given bars (highest pitch wins a step)."""
    g = collections.defaultdict(dict)
    for n in notes:
        b, st = n[0] // s.bar, (n[0] % s.bar) // s.step
        if b in bars:
            if st not in g[b] or n[1] > g[b][st]:
                g[b][st] = n[1]
    return g


def pass_seq(s, role="seq"):
    ns = s.notes(role)
    if not ns:
        print(f"  {role.upper()}: none"); return
    chords = bar_chords(s)
    bars = sorted({n[0] // s.bar for n in ns})
    g = step_grid(ns, s, set(bars))
    # step stream over the active span: pitch or -1 for rest
    stream = []
    for b in range(bars[0], bars[-1] + 1):
        for st in range(16):
            stream.append(g[b].get(st, -1) if b in g else -1)
    # pitch-only cell (ignoring rests) catches phasing cells whose rhythm is constant
    pitches = [n[1] for n in ns]
    pp = period(pitches[:400])
    sp = period(stream[:16 * 32])
    onsets_per_bar = statistics.median(len(g[b]) for b in g)
    durs = statistics.median(n[3] / s.step for n in ns)
    pcs_bar = statistics.median(len({p % 12 for p in g[b].values()}) for b in g)
    span_bar = statistics.median(max(g[b].values()) - min(g[b].values()) for b in g if g[b])
    # distinct bar patterns (rhythm and pitch relative to the bar's chord root)
    pats = collections.Counter()
    rhy = collections.Counter()
    for b in g:
        root = chords[b][0] if b < len(chords) and chords[b] else 0
        pats[tuple((st, (p - root) % 12) for st, p in sorted(g[b].items()))] += 1
        rhy[tuple(sorted(g[b]))] += 1
    top_r, top_rc = rhy.most_common(1)[0]
    # change rate: how many consecutive bars repeat exactly (pitch+rhythm, absolute)
    absb = [tuple(sorted(g[b].items())) if b in g else None for b in range(bars[0], bars[-1] + 1)]
    runs, cur = [], 1
    for i in range(1, len(absb)):
        if absb[i] is not None and absb[i] == absb[i - 1]:
            cur += 1
        else:
            runs.append(cur); cur = 1
    runs.append(cur)
    grid = "".join("x" if i in top_r else "." for i in range(16))
    print(f"  {role.upper()}  {len(ns)} notes, register {min(pitches)}-{max(pitches)}, "
          f"{onsets_per_bar} onsets/bar, dur {durs:.1f} steps, {pcs_bar} pitch classes/bar, "
          f"bar span {span_bar} st")
    print(f"    pitch-cell period {pp}  step-cell period {sp}  "
          f"top rhythm {grid} ({top_rc}/{len(g)} bars)  "
          f"distinct bar patterns {len(pats)}  identical-bar runs median {statistics.median(runs)} max {max(runs)}")
    # show the cell shape: first period of pitches, relative to its first note
    if pp:
        start = 0
        cell = pitches[start:start + pp]
        rel = [p - cell[0] for p in cell]
        print(f"    cell shape (semitones from first note): {rel}")
    # also show the commonest bar in relative form
    pat, c = pats.most_common(1)[0]
    print(f"    commonest bar vs chord root ({c}x): " + " ".join(f"{st}:{iv}" for st, iv in pat))


# ----------------------------------------------------------------------------- bass

def pass_bass(s):
    ns = s.notes("bass")
    if not ns:
        print("  BASS: none"); return
    chords = bar_chords(s)
    bars = sorted({n[0] // s.bar for n in ns})
    g = step_grid(ns, s, set(bars))
    pitches = [n[1] for n in ns]
    iv = [abs(b - a) for a, b in zip(pitches, pitches[1:])]
    c = collections.Counter(min(x, 13) for x in iv)
    tot = len(iv) or 1
    rep, step, third4, fifth, leap = (c[0] / tot, (c[1] + c[2]) / tot, (c[3] + c[4] + c[5]) / tot,
                                      (c[6] + c[7]) / tot, sum(c[k] for k in c if k > 7) / tot)
    rhy = collections.Counter(tuple(sorted(g[b])) for b in g)
    top = rhy.most_common(3)
    on_root = 0
    cnt = 0
    for b in g:
        if b < len(chords) and chords[b]:
            for st, p in g[b].items():
                cnt += 1
                on_root += (p % 12 == chords[b][0])
    print(f"  BASS  {len(ns)} notes, register {min(pitches)}-{max(pitches)}, "
          f"{statistics.median(len(g[b]) for b in g)} onsets/bar, dur {statistics.median(n[3] / s.step for n in ns):.1f} steps, "
          f"on chord root {on_root / max(1, cnt):.0%}")
    print(f"    intervals: repeat {rep:.0%}  2nd {step:.0%}  3rd-4th {third4:.0%}  5th {fifth:.0%}  "
          f"octave/leap {leap:.0%}   distinct rhythms {len(rhy)}")
    for r, k in top:
        print(f"    rhythm {''.join('x' if i in r else '.' for i in range(16))}  {k}/{len(g)} bars")


# ----------------------------------------------------------------------------- drums

def pass_drums(s):
    ps = s.roles.get("drums", [])
    if not ps:
        print("  DRUMS: none"); return
    ns = sorted(n for p in ps for n in p)
    by_voice = collections.defaultdict(list)
    for n in ns:
        by_voice[n[1]].append(n)
    bars_with = sorted({n[0] // s.bar for n in ns})
    print(f"  DRUMS  active {len(bars_with)}/{s.nbars} bars, {len(ns) / max(1, len(bars_with)):.1f} hits/bar")
    for v, vs in sorted(by_voice.items(), key=lambda kv: -len(kv[1]))[:6]:
        g = collections.defaultdict(set)
        for n in vs:
            g[n[0] // s.bar].add((n[0] % s.bar) // s.step)
        top, k = collections.Counter(tuple(sorted(x)) for x in g.values()).most_common(1)[0]
        print(f"    note {v:3}  {len(vs) / max(1, len(g)):4.1f}/bar in {len(g):3} bars  "
              f"{''.join('x' if i in top else '.' for i in range(16))} ({k / len(g):.0%} of its bars)")


# ----------------------------------------------------------------------------- lead

def split_phrases(ns, s, gap_steps=4):
    out, cur = [], []
    for n in ns:
        if cur and n[0] - (cur[-1][0] + cur[-1][3]) >= gap_steps * s.step:
            out.append(cur); cur = []
        cur.append(n)
    if cur:
        out.append(cur)
    return out


def pass_lead(s, role="lead"):
    ns = s.notes(role)
    if not ns:
        print(f"  {role.upper()}: none"); return
    # monophonic reduction: highest note per onset
    by_on = {}
    for n in ns:
        if n[0] not in by_on or n[1] > by_on[n[0]][1]:
            by_on[n[0]] = n
    mono = [by_on[k] for k in sorted(by_on)]
    chords = bar_chords(s)
    melodic = [n for r in ("bass", "seq", "pads", "lead") for n in s.notes(r, primary=False)]
    tonic, mode, _ = best_mode(pc_profile(melodic))
    ph = split_phrases(mono, s)
    lens = [len(p) for p in ph]
    spans = [(p[-1][0] + p[-1][3] - p[0][0]) / s.step for p in ph]
    gaps = [(b[0][0] - (a[-1][0] + a[-1][3])) / s.step for a, b in zip(ph, ph[1:])]
    pitches = [n[1] for n in mono]
    iv = [b[1] - a[1] for p in ph for a, b in zip(p, p[1:])]
    a = [abs(x) for x in iv]
    tot = len(a) or 1
    c = collections.Counter(min(x, 13) for x in a)
    pr = lambda ks: sum(c[k] for k in ks) / tot
    end_dur = statistics.median(p[-1][3] / s.step for p in ph)
    body_dur = statistics.median(n[3] / s.step for p in ph for n in p[:-1]) if any(len(p) > 1 for p in ph) else 0
    end_deg = collections.Counter(DEG[(p[-1][1] - tonic) % 12] for p in ph)
    end_chord = 0
    for p in ph:
        b = p[-1][0] // s.bar
        if b < len(chords) and chords[b]:
            r = chords[b][0]
            q = chords[b][1]
            tones = {0, 7, 3 if q.startswith("m") else 4}
            end_chord += ((p[-1][1] - r) % 12) in tones
    contour = collections.Counter()
    for p in ph:
        if len(p) < 3:
            continue
        hi = max(range(len(p)), key=lambda i: p[i][1])
        lo = min(range(len(p)), key=lambda i: p[i][1])
        d = p[-1][1] - p[0][1]
        if 0 < hi < len(p) - 1 and p[hi][1] > max(p[0][1], p[-1][1]):
            contour["arch"] += 1
        elif 0 < lo < len(p) - 1 and p[lo][1] < min(p[0][1], p[-1][1]):
            contour["valley"] += 1
        elif d > 0:
            contour["rise"] += 1
        elif d < 0:
            contour["fall"] += 1
        else:
            contour["level"] += 1
    print(f"  {role.upper()}  {len(mono)} notes, register {min(pitches)}-{max(pitches)} "
          f"(p10-p90 {sorted(pitches)[len(pitches) // 10]}-{sorted(pitches)[len(pitches) * 9 // 10]}), "
          f"{len(ph)} phrases, key {NAMES[tonic]} {mode}")
    print(f"    phrase notes median {statistics.median(lens)} (p25 {sorted(lens)[len(lens) // 4]}, "
          f"p75 {sorted(lens)[len(lens) * 3 // 4]}), span {statistics.median(spans):.0f} steps, "
          f"gap after {statistics.median(gaps) if gaps else 0:.0f} steps (silence:statement "
          f"{(statistics.median(gaps) / statistics.median(spans)) if gaps else 0:.1f}:1)")
    print(f"    intervals: repeat {pr([0]):.0%}  2nd {pr([1, 2]):.0%}  3rd {pr([3, 4]):.0%}  "
          f"4th-5th {pr([5, 6, 7]):.0%}  6th+ {pr(range(8, 12)):.0%}  oct+ {pr([12, 13]):.0%}  "
          f"up {sum(1 for x in iv if x > 0) / tot:.0%}")
    print(f"    note dur median {body_dur:.1f} steps, phrase-final {end_dur:.1f} steps; "
          f"ends on chord tone {end_chord / max(1, len(ph)):.0%}; final degree "
          + ", ".join(f"{d} {k}" for d, k in end_deg.most_common(4)))
    print("    contour: " + ", ".join(f"{k} {v}" for k, v in contour.most_common()))
    # recurring figures: interval 3..5-grams within phrases
    figs = collections.Counter()
    for p in ph:
        ivs = [b[1] - a[1] for a, b in zip(p, p[1:])]
        for k in (3, 4):
            for i in range(len(ivs) - k + 1):
                figs[tuple(ivs[i:i + k])] += 1
    top = [(f, k) for f, k in figs.most_common(40) if any(x != 0 for x in f)][:6]
    print("    recurring figures: " + "  ".join(f"[{' '.join(f'{x:+d}' for x in f)}]x{k}" for f, k in top))
    # phrase form: label phrases by their interval+rhythm signature
    sig_label, labels = {}, []
    for p in ph:
        ivs = tuple(b[1] - a[1] for a, b in zip(p, p[1:]))
        rh = tuple((b[0] - a[0]) // s.step for a, b in zip(p, p[1:]))
        key = (ivs, rh)
        lab = None
        for k2, l2 in sig_label.items():
            if k2 == key:
                lab = l2; break
        if lab is None:
            # near match: same rhythm and same contour signs -> variant
            for k2, l2 in sig_label.items():
                if k2[1] == rh and [x > 0 for x in k2[0]] == [x > 0 for x in ivs] and len(ivs) > 1:
                    lab = l2 + "'"; break
        if lab is None:
            lab = chr(ord("A") + len({v.rstrip("'") for v in sig_label.values()}) % 26)
            sig_label[key] = lab
        labels.append(lab)
    print(f"    phrase form ({len(set(l.rstrip(chr(39)) for l in labels))} distinct ideas): "
          + " ".join(labels[:48]) + (" ..." if len(labels) > 48 else ""))


# ----------------------------------------------------------------------------- pads

def pass_pads(s):
    ps = s.roles.get("pads", [])
    if not ps:
        print("  PADS: none"); return
    ns = ps[0]
    # chords = notes starting within one step of each other
    groups, cur = [], []
    for n in ns:
        if cur and n[0] - cur[0][0] > s.step:
            groups.append(cur); cur = []
        cur.append(n)
    if cur:
        groups.append(cur)
    voices = [len({n[1] for n in g}) for g in groups]
    durs = [max(n[3] for n in g) / s.tpb for g in groups]
    iois = [(b[0][0] - a[0][0]) / s.tpb for a, b in zip(groups, groups[1:])]
    stag = [(g[-1][0] - g[0][0]) / s.step for g in groups if len(g) > 1]
    lo = [min(n[1] for n in g) for g in groups]
    hi = [max(n[1] for n in g) for g in groups]
    starts_on = collections.Counter(((g[0][0] // s.bar) % 4, (g[0][0] % s.bar) // s.step) for g in groups)
    print(f"  PADS  {len(groups)} attacks, voices median {statistics.median(voices)} (max {max(voices)}), "
          f"held {statistics.median(durs):.1f} beats (p90 {sorted(durs)[len(durs) * 9 // 10]:.1f}), "
          f"re-attack every {statistics.median(iois) if iois else 0:.1f} beats, "
          f"voicing {statistics.median(lo):.0f}-{statistics.median(hi):.0f}")
    print("    attack position (bar mod 4, step): "
          + ", ".join(f"{b}:{st} x{k}" for (b, st), k in starts_on.most_common(5)))


# ----------------------------------------------------------------------------- texture

def pass_tex(s):
    for i, ns in enumerate(s.roles.get("tex", [])):
        if not ns:
            continue
        bars = [n[0] / s.bar for n in ns]
        on8 = sum(1 for b in bars if abs(b - round(b / 8) * 8) <= 1.01) / len(bars)
        on4 = sum(1 for b in bars if abs(b - round(b / 4) * 4) <= 0.51) / len(bars)
        print(f"  TEX{i}  {len(ns)} events, dur median {statistics.median(n[3] / s.tpb for n in ns):.1f} beats, "
              f"within 1 bar of an 8-bar boundary {on8:.0%}, within half a bar of a 4-bar boundary {on4:.0%}, "
              f"register {min(n[1] for n in ns)}-{max(n[1] for n in ns)}")
        print("    first onsets (bar): " + " ".join(f"{b + 1:.1f}" for b in bars[:14]))


# ----------------------------------------------------------------------------- interplay

def pass_interplay(s):
    act = {r: {n[0] // s.bar for n in s.notes(r, primary=False)} for r in s.roles}
    pairs = [("lead", "seq"), ("lead", "lead2"), ("lead", "pads"), ("seq", "pads"), ("lead2", "seq")]
    out = []
    for a, b in pairs:
        if a in act and b in act and act[a]:
            both = len(act[a] & act[b])
            out.append(f"{ABBR[a]}+{ABBR[b]} {both / len(act[a]):.0%} of {ABBR[a]} bars")
    lead_share = len(act.get("lead", set())) / s.nbars
    print(f"  INTERPLAY  lead plays {lead_share:.0%} of bars;  " + ";  ".join(out))


def main():
    args = sys.argv[1:]
    only = None
    if "--only" in args:
        i = args.index("--only"); only = args[i + 1]; del args[i:i + 2]
    flags = {a for a in args if a.startswith("--")}
    args = [a for a in args if not a.startswith("--")]
    root = os.path.expanduser(args[0] if args else "~/Downloads/jarre-midi")
    want = lambda f: not flags or f in flags
    files = sorted(glob.glob(os.path.join(root, "*.mid")) + glob.glob(os.path.join(root, "*.MID")))
    for path in files:
        if only and only not in os.path.basename(path):
            continue
        if not file_key(path):
            print(f"(no role map) {os.path.basename(path)}"); continue
        s = Song(path)
        print("=" * 78)
        print(f"{os.path.basename(path)}" + ("   [half-time corrected]" if s.half else ""))
        if want("--sections"): pass_sections(s)
        if want("--harmony"):  pass_harmony(s)
        if want("--seq"):      pass_seq(s)
        if want("--bass"):     pass_bass(s)
        if want("--drums"):    pass_drums(s)
        if want("--pads"):     pass_pads(s)
        if want("--tex"):      pass_tex(s)
        if want("--interplay"): pass_interplay(s)
        if want("--lead"):
            pass_lead(s)
            if "lead2" in s.roles:
                pass_lead(s, "lead2")


if __name__ == "__main__":
    main()
