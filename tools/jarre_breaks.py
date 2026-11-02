#!/usr/bin/env python3
"""jarre_breaks.py — how the Kosmic Space corpus breaks up its own repetition.

Usage:
    python3 tools/jarre_breaks.py [dir] [--only SUBSTR] [--min N]

Uses jarre_deep's role map and half-time corrections. For each piece:

  GAPS     every run of silent bars inside a role's playing span (drums, seq, bass, lead),
           at least --min bars long (default 2): where it starts, how long it lasts, the bar
           it returns on and where that bar sits against the 8- and 16-bar grid and the
           detected section edges, which other roles are silent with it, and whether a drum
           fill or a texture event marks the return
  FILLS    drum bars that break the piece's commonest drum bar (toms, crashes, or four or
           more steps changed), and what the following bar is
  SEQ      the sequencer's commonest bar, the share of bars that play it exactly, and its
           density per detected section with the lead playing or not

Bars are 1-based in the output, counted from the start of the file.
"""
import sys, os, glob, collections, statistics
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from jarre_deep import Song, file_key, ROLE_ORDER, ABBR  # noqa: E402

TOMS = {41, 43, 45, 47, 48, 50}
CRASH = {49, 57, 52, 55}
ROLES = ["drums", "seq", "bass", "lead"]


def sounding_bars(notes, s):
    out = set()
    for n in notes:
        a, b = n[0] // s.bar, (n[0] + n[3] - 1) // s.bar
        out.update(range(a, b + 1))
    return out


def onset_bars(notes, s):
    return {n[0] // s.bar for n in notes}


def activity(s):
    """Bars in which each role sounds. Drums and seq count onsets only: a held note in a
    sequencer part is still a stopped sequencer."""
    act = {}
    for r in s.roles:
        ns = s.notes(r, primary=False)
        act[r] = onset_bars(ns, s) if r in ("drums", "seq") else sounding_bars(ns, s)
    return act


def sections(s):
    """Section edges (0-based bars) by the same rule as jarre_deep --sections."""
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
    segs, start = [], 0
    for b in range(1, nblk + 1):
        if b == nblk:
            segs.append((start, b)); break
        a, d = rows[start]; c, e = rows[b]
        sym = len(a ^ c)
        ratio = (max(d, e) + 0.1) / (min(d, e) + 0.1)
        if sym >= 2 or ratio >= 2.0 or (sym == 1 and ({"drums", "seq", "lead"} & (a ^ c))):
            segs.append((start, b)); start = b
    merged = []
    for a, b in segs:
        if merged and b - a == 1:
            merged[-1] = (merged[-1][0], b)
        else:
            merged.append((a, b))
    return [a * blk for a, _ in merged]


def drum_bars(s):
    ns = sorted(n for p in s.roles.get("drums", []) for n in p)
    g = collections.defaultdict(lambda: {"steps": set(), "notes": set(), "hits": 0})
    for n in ns:
        b = n[0] // s.bar
        g[b]["steps"].add((n[0] % s.bar) // s.step)
        g[b]["notes"].add(n[1])
        g[b]["hits"] += 1
    return g


def fills(s, act):
    g = drum_bars(s)
    if not g:
        return set(), None
    mode = collections.Counter(frozenset(v["steps"]) for v in g.values()).most_common(1)[0][0]
    tom_usual = collections.Counter(bool(v["notes"] & TOMS) for v in g.values())[True] > len(g) / 2
    out = set()
    for b, v in g.items():
        changed = len(v["steps"] ^ mode)
        if (v["notes"] & TOMS and not tom_usual) or v["notes"] & CRASH or changed >= 4:
            out.add(b)
    return out, mode


def grid(bar, origin):
    rel = bar - origin
    tags = []
    if rel % 16 == 0: tags.append("16")
    elif rel % 8 == 0: tags.append("8")
    elif rel % 4 == 0: tags.append("4")
    return tags[0] if tags else "-"


def main():
    args = sys.argv[1:]
    only, minlen = None, 2
    if "--only" in args:
        i = args.index("--only"); only = args[i + 1]; del args[i:i + 2]
    if "--min" in args:
        i = args.index("--min"); minlen = int(args[i + 1]); del args[i:i + 2]
    root = os.path.expanduser(args[0] if args else "~/Downloads/jarre-midi")
    files = sorted(glob.glob(os.path.join(root, "*.mid")) + glob.glob(os.path.join(root, "*.MID")))
    summary = collections.defaultdict(list)
    for path in files:
        if only and only not in os.path.basename(path):
            continue
        if not file_key(path):
            continue
        s = Song(path)
        act = activity(s)
        edges = set(sections(s))
        tex = onset_bars(s.notes("tex", primary=False), s) if "tex" in s.roles else set()
        fill_bars, mode = fills(s, act)
        origin = min(min(v) for v in act.values() if v)
        print("=" * 78)
        print(f"{os.path.basename(path)}  ({s.nbars} bars, {s.tempo:g} bpm, origin bar {origin + 1})")
        print(f"  section edges: {' '.join(str(e + 1) for e in sorted(edges))}")

        # ---- gaps
        for r in ROLES:
            if r not in act or not act[r]:
                continue
            bars = act[r]
            lo, hi = min(bars), max(bars)
            run = None
            gaps = []
            for b in range(lo, hi + 2):
                if b not in bars and b <= hi:
                    run = run if run is not None else b
                elif run is not None:
                    gaps.append((run, b - run)); run = None
            gaps = [g for g in gaps if g[1] >= minlen]
            if not gaps:
                print(f"  {ABBR[r]} GAPS: none ≥{minlen} (plays bars {lo + 1}-{hi + 1}, "
                      f"{len(bars)}/{hi - lo + 1} of its span)")
                continue
            print(f"  {ABBR[r]} GAPS (plays bars {lo + 1}-{hi + 1}):")
            for start, n in gaps:
                ret = start + n
                with_ = [ABBR[o] for o in ROLE_ORDER
                         if o != r and o in act and act[o]
                         and sum(1 for b in range(start, ret) if b not in act[o]) >= 0.75 * n
                         and min(act[o]) < start]
                edge = "edge" if ret in edges else ("edge±4" if any(abs(ret - e) <= 4 for e in edges) else "-")
                fill = "fill" if (ret - 1) in fill_bars else "-"
                tx = "tex" if ({ret - 1, ret} & tex) else "-"
                print(f"    bars {start + 1:3}-{ret:3} ({n:2})  returns {ret + 1:3}  grid {grid(ret, origin):2}  "
                      f"{edge:6} {fill:4} {tx:3}  silent with: {' '.join(with_) or '-'}")
                summary[r].append(dict(n=n, grid=grid(ret, origin), edge=edge, fill=fill, tex=tx,
                                       with_=tuple(with_), piece=s.key, frac=start / s.nbars))

        # ---- fills
        if "drums" in act and act["drums"]:
            dlo, dhi = min(act["drums"]), max(act["drums"])
            inner = sorted(b for b in fill_bars if dlo < b < dhi)
            print(f"  FILLS: {len(inner)} of {dhi - dlo + 1} drum-span bars")
            for b in inner[:24]:
                nxt = b + 1
                returns = [ABBR[o] for o in ROLE_ORDER if o in act and nxt in act[o] and b not in act[o]]
                print(f"    bar {b + 1:3}  next {nxt + 1:3} grid {grid(nxt, origin):2}  "
                      f"{'edge' if nxt in edges else '-':4}  next-bar returns: {' '.join(returns) or '-'}")
            if len(inner) > 24:
                print(f"    ... {len(inner) - 24} more")
            summary["fills"].append((s.key, len(inner), dhi - dlo + 1))

        # ---- sequencer thinning by section
        if "seq" in s.roles:
            ns = s.notes("seq")
            per = collections.defaultdict(set)
            for n in ns:
                per[n[0] // s.bar].add((n[0] % s.bar) // s.step)
            if per:
                common = collections.Counter(frozenset(v) for v in per.values()).most_common(1)[0][0]
                exact = sum(1 for v in per.values() if frozenset(v) == common) / len(per)
                print(f"  SEQ: commonest bar {''.join('x' if i in common else '.' for i in range(16))} "
                      f"({len(common)} notes) in {exact:.0%} of {len(per)} bars")
                lead = act.get("lead", set())
                bounds = sorted(edges | {0, s.nbars})
                for a, b in zip(bounds, bounds[1:]):
                    bars = [x for x in range(a, b) if x in per]
                    if len(bars) < 2:
                        continue
                    dens = statistics.mean(len(per[x]) for x in bars)
                    ex = sum(1 for x in bars if frozenset(per[x]) == common) / len(bars)
                    lshare = sum(1 for x in range(a, b) if x in lead) / (b - a)
                    print(f"    bars {a + 1:3}-{b:3}  seq {len(bars):3}/{b - a:3} bars  "
                          f"{dens:4.1f} notes/bar  commonest {ex:4.0%}  lead in {lshare:4.0%}")

    # ---- corpus summary
    print("=" * 78)
    print("SUMMARY")
    for r in ROLES:
        gs = summary.get(r, [])
        if not gs:
            continue
        lens = collections.Counter(g["n"] for g in gs)
        print(f"  {ABBR[r]} gaps ≥{minlen}: {len(gs)} in {len({g['piece'] for g in gs})} pieces; "
              f"lengths {dict(sorted(lens.items()))}")
        print(f"     return on grid 16/8/4/-: "
              + "/".join(str(sum(1 for g in gs if g['grid'] == t)) for t in ("16", "8", "4", "-"))
              + f"; on section edge {sum(1 for g in gs if g['edge'] == 'edge')}, within 4 "
              + f"{sum(1 for g in gs if g['edge'] == 'edge±4')}; fill before return "
              + f"{sum(1 for g in gs if g['fill'] == 'fill')}; tex at return "
              + f"{sum(1 for g in gs if g['tex'] == 'tex')}")
        w = collections.Counter(x for g in gs for x in g["with_"])
        print(f"     silent with it: {dict(w.most_common())}")
    if summary.get("fills"):
        print("  fills per piece: " + ", ".join(f"{k} {n}/{t}" for k, n, t in summary["fills"]))


if __name__ == "__main__":
    main()
