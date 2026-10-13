#!/usr/bin/env python3
"""soho_sustained.py — what a sophisti-pop lead phrase built on a SUSTAINED note looks like.

CHL-LD1-011 Sustained Tone played one long note per phrase and nothing else, which was too
static to work as a solo. Before inventing an answer figure, measure one: find every melodic
phrase in the corpus that contains a genuinely long note, and report how many notes sit with it,
where the long note falls, how long the others are, and what intervals they take.

Usage: python3 tools/soho_sustained.py [dir]
"""
import sys, os, glob, collections, statistics

try:
    import mido
except ImportError:
    sys.exit("mido not installed. Try: python3 -m pip install mido")

LEADISH = set(range(56, 64)) | set(range(64, 72)) | set(range(72, 80)) | set(range(80, 88))
LONG_STEPS = 12        # 3 beats in 16th steps — a genuinely held tone
PHRASE_GAP = 8         # 2 beats of silence starts a new phrase


def notes_by_channel(path):
    mid = mido.MidiFile(path)
    tpb = mid.ticks_per_beat
    prog, on, out = {}, {}, collections.defaultdict(list)
    for track in mid.tracks:
        t = 0
        for msg in track:
            t += msg.time
            if msg.type == "program_change":
                prog[msg.channel] = msg.program
            elif msg.type == "note_on" and msg.velocity > 0:
                on.setdefault((msg.channel, msg.note), []).append(t)
            elif msg.type == "note_off" or (msg.type == "note_on" and msg.velocity == 0):
                st = on.get((msg.channel, msg.note))
                if st:
                    s = st.pop(0)
                    step = lambda x: round(x / tpb * 4)
                    out[msg.channel].append((step(s), msg.note, max(1, step(t) - step(s))))
    return {c: sorted(v) for c, v in out.items() if prog.get(c, 0) in LEADISH and c != 9}


sizes, positions, shortdurs, intervals, gaps, longdurs = (collections.Counter() for _ in range(6))
examples, phrase_total = [], 0

for path in sorted(glob.glob(os.path.join(sys.argv[1] if len(sys.argv) > 1
                                          else os.path.expanduser("~/Downloads/soho-midi"), "*.mid"))):
    for ch, notes in notes_by_channel(path).items():
        phrase = []
        for n in notes:
            if phrase and n[0] - (phrase[-1][0] + phrase[-1][2]) > PHRASE_GAP:
                yield_phrase = phrase
                phrase = []
                longs = [i for i, x in enumerate(yield_phrase) if x[2] >= LONG_STEPS]
                if longs and len(yield_phrase) <= 8:
                    phrase_total += 1
                    i = longs[0]
                    sizes[len(yield_phrase)] += 1
                    longdurs[min(yield_phrase[i][2] // 4 * 4, 64)] += 1
                    positions["first" if i == 0 else
                              "last" if i == len(yield_phrase) - 1 else "middle"] += 1
                    for j, x in enumerate(yield_phrase):
                        if j == i:
                            continue
                        shortdurs[min(x[2], 10)] += 1
                        intervals[max(-12, min(12, x[1] - yield_phrase[i][1]))] += 1
                    for a, b in zip(yield_phrase, yield_phrase[1:]):
                        gaps[min(b[0] - a[0], 24)] += 1
                    if 2 <= len(yield_phrase) <= 4 and len(examples) < 14:
                        base = yield_phrase[0][0]
                        examples.append(f"{os.path.basename(path)[:26]:28s} " + " ".join(
                            f"{x[0]-base:+d}/{x[1]-yield_phrase[i][1]:+d}/d{x[2]}" for x in yield_phrase))
            phrase.append(n)

def top(c, n=8, key=None):
    return "  ".join(f"{k}:{v}" for k, v in sorted(c.items(), key=key or (lambda kv: -kv[1]))[:n])

print(f"PHRASES containing a note >= {LONG_STEPS} steps (3 beats): {phrase_total}")
print("notes per phrase :", top(sizes, 8, lambda kv: kv[0]))
print("long note sits   :", top(positions))
print("long note length :", top(longdurs, 8, lambda kv: kv[0]))
print("other note dur   :", top(shortdurs, 10, lambda kv: kv[0]))
print("interval to long :", top(intervals, 12, lambda kv: kv[0]))
print("onset gaps       :", top(gaps, 10, lambda kv: kv[0]))
print("\nEXAMPLES  (offset/interval-from-long/duration)")
for e in examples:
    print(" ", e)
