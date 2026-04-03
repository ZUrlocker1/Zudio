import mido
import collections
import statistics
import math

NOTE_NAMES = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B']

def note_name(n):
    return f"{NOTE_NAMES[n % 12]}{n // 12 - 1}"

def find_period(series, max_period=32):
    n = len(series)
    max_period = min(max_period, n // 2)
    best_period = None
    best_score = 0
    for p in range(1, max_period + 1):
        matches = sum(1 for i in range(n - p) if series[i] == series[i + p])
        score = matches / (n - p) if n - p > 0 else 0
        if score > best_score:
            best_score = score
            best_period = p
    return best_period, best_score

def estimate_key(pc_counts):
    major_template = [6.35,2.23,3.48,2.33,4.38,4.09,2.52,5.19,2.39,3.66,2.29,2.88]
    minor_template = [6.33,2.68,3.52,5.38,2.60,3.53,2.54,4.75,3.98,2.69,3.34,3.17]
    total_pc = sum(pc_counts.get(i,0) for i in range(12))
    pc_norm = [pc_counts.get(i,0)/total_pc for i in range(12)] if total_pc else [0]*12
    best_key, best_corr = None, -999
    for root in range(12):
        for scale, tmpl in [('maj', major_template), ('min', minor_template)]:
            corr = sum(pc_norm[i] * tmpl[(i - root) % 12] for i in range(12))
            if corr > best_corr:
                best_corr = corr
                best_key = f"{NOTE_NAMES[root]} {scale}"
    return best_key, best_corr

def analyze_midi(path):
    print("=" * 72)
    print(f"FILE: {path}")
    print("=" * 72)

    mid = mido.MidiFile(path)
    tpb = mid.ticks_per_beat
    print(f"Type: {mid.type}  |  Ticks-per-beat: {tpb}")

    # Collect global tempo and time signature from ALL tracks
    tempo = 500000
    time_sig_num, time_sig_den = 4, 4
    tempos = []
    time_sigs = []

    for track in mid.tracks:
        abs_tick = 0
        for msg in track:
            abs_tick += msg.time
            if msg.type == 'set_tempo':
                tempos.append((abs_tick, msg.tempo))
            elif msg.type == 'time_signature':
                time_sigs.append((abs_tick, msg.numerator, msg.denominator))

    if tempos:
        tempo = tempos[0][1]
    if time_sigs:
        time_sig_num, time_sig_den = time_sigs[0][1], time_sigs[0][2]

    bpm = 60_000_000 / tempo
    print(f"\nTEMPO: {tempo} us/beat = {bpm:.2f} BPM")
    if len(tempos) > 1:
        print(f"  (tempo changes: {[(t, round(60e6/v,1)) for t,v in tempos]})")
    print(f"TIME SIGNATURE: {time_sig_num}/{time_sig_den}")
    if len(time_sigs) > 1:
        print(f"  (sig changes: {time_sigs})")

    beats_per_bar = time_sig_num
    ticks_per_bar = tpb * beats_per_bar

    # Total length
    abs_ticks_all = []
    for track in mid.tracks:
        abs_tick = 0
        for msg in track:
            abs_tick += msg.time
        abs_ticks_all.append(abs_tick)
    total_ticks = max(abs_ticks_all)
    total_seconds = mido.tick2second(total_ticks, tpb, tempo)
    total_bars = total_ticks / ticks_per_bar
    print(f"\nLENGTH: {total_ticks} ticks | {total_bars:.2f} bars | {total_seconds:.2f}s ({total_seconds/60:.2f} min)")
    print(f"\nTRACKS: {len(mid.tracks)}")

    # Per-track analysis
    for ti, track in enumerate(mid.tracks):
        print(f"\n{'─'*60}")
        print(f"Track {ti}: '{track.name}'")

        abs_tick = 0
        note_ons = {}
        notes = []
        channel_set = set()
        program_changes = {}

        for msg in track:
            abs_tick += msg.time
            if msg.type == 'program_change':
                program_changes[msg.channel] = msg.program
            if hasattr(msg, 'channel'):
                channel_set.add(msg.channel)
            if msg.type == 'note_on' and msg.velocity > 0:
                key = (msg.channel, msg.note)
                if key not in note_ons:
                    note_ons[key] = []
                note_ons[key].append((abs_tick, msg.velocity))
            elif msg.type == 'note_off' or (msg.type == 'note_on' and msg.velocity == 0):
                key = (msg.channel, getattr(msg, 'note', 0))
                if key in note_ons and note_ons[key]:
                    on_tick, vel = note_ons[key].pop(0)
                    notes.append((msg.note, getattr(msg,'channel',0), on_tick, abs_tick, vel))

        if not notes:
            print("  (no note events)")
            continue

        print(f"  Channels: {sorted(channel_set)}  |  Programs: {program_changes}")

        pitches   = [n[0] for n in notes]
        vels      = [n[4] for n in notes]
        durations_ticks = [n[3] - n[2] for n in notes]

        # Note range
        lo, hi = min(pitches), max(pitches)
        print(f"\n  NOTE RANGE: {lo} ({note_name(lo)}) to {hi} ({note_name(hi)})  span={hi-lo} semitones")

        # Pitch class histogram
        pc_counts = collections.Counter(p % 12 for p in pitches)
        pc_sorted = sorted(pc_counts.items(), key=lambda x: -x[1])
        pc_str = ', '.join(f"{NOTE_NAMES[pc]}={cnt}" for pc,cnt in pc_sorted[:8])
        print(f"  PITCH CLASSES (top 8): {pc_str}")

        # Velocity stats
        v_min, v_max = min(vels), max(vels)
        v_mean = statistics.mean(vels)
        v_med  = statistics.median(vels)
        try:
            v_mode = statistics.mode(vels)
        except Exception:
            v_mode = "multi"
        print(f"\n  VELOCITY: min={v_min}  max={v_max}  mean={v_mean:.1f}  median={v_med}  mode={v_mode}")

        # Duration stats
        d_min, d_max = min(durations_ticks), max(durations_ticks)
        d_mean = statistics.mean(durations_ticks)
        d_med  = statistics.median(durations_ticks)
        print(f"\n  DURATION (ticks):  min={d_min}  max={d_max}  mean={d_mean:.1f}  median={d_med:.1f}")
        print(f"  DURATION (beats):  min={d_min/tpb:.3f}  max={d_max/tpb:.3f}  mean={d_mean/tpb:.3f}  median={d_med/tpb:.3f}")

        # Duration bucket profile
        total_notes = len(notes)
        buckets = collections.OrderedDict([
            ('<=16th', 0), ('~8th', 0), ('~qtr', 0), ('~half', 0), ('~whole', 0), ('>whole', 0)
        ])
        for d in durations_ticks:
            if d <= tpb // 4:
                buckets['<=16th'] += 1
            elif d <= int(tpb * 0.75):
                buckets['~8th'] += 1
            elif d <= int(tpb * 1.5):
                buckets['~qtr'] += 1
            elif d <= tpb * 3:
                buckets['~half'] += 1
            elif d <= tpb * 5:
                buckets['~whole'] += 1
            else:
                buckets['>whole'] += 1
        bucket_str = '  '.join(f"{k}:{v}({100*v//total_notes}%)" for k,v in buckets.items() if v > 0)
        print(f"  DURATION PROFILE: {bucket_str}")

        # Density
        n_bars = max(1.0, total_ticks / ticks_per_bar)
        notes_per_bar = total_notes / n_bars
        print(f"\n  TOTAL NOTES: {total_notes}")
        print(f"  NOTES/BAR (over {n_bars:.1f} bars): {notes_per_bar:.2f}")

        # Silence ratio
        total_sounding = sum(durations_ticks)
        silence_ratio = 1.0 - min(1.0, total_sounding / total_ticks)
        print(f"  SILENCE RATIO (approx, ignoring polyphony): {silence_ratio:.2%}")

        # Bar-by-bar note counts
        bar_note_counts = collections.Counter()
        for _, _, on_t, _, _ in notes:
            bar_idx = int(on_t // ticks_per_bar)
            bar_note_counts[bar_idx] += 1

        bars_present = sorted(bar_note_counts.keys())
        max_bar = bars_present[-1]
        bar_series = [bar_note_counts.get(b, 0) for b in range(max_bar + 1)]
        print(f"\n  BAR NOTE COUNTS (first 32): {bar_series[:32]}")

        if len(bar_series) >= 4:
            period, score = find_period(bar_series)
            print(f"  LIKELY LOOP PERIOD: {period} bars (score={score:.2f})")

        # Bar-level pitch sets
        bar_pitches = collections.defaultdict(list)
        for pitch, ch, on_t, off_t, vel in notes:
            bar_idx = int(on_t // ticks_per_bar)
            bar_pitches[bar_idx].append(pitch % 12)

        bar_pc_sets = {b: frozenset(pcs) for b, pcs in bar_pitches.items()}
        sorted_bars = sorted(bar_pc_sets.keys())
        changes = sum(1 for i in range(1, len(sorted_bars))
                      if bar_pc_sets[sorted_bars[i]] != bar_pc_sets[sorted_bars[i-1]])
        change_rate = changes / max(1, len(sorted_bars) - 1)
        avg_bars_per_chord = 1.0 / change_rate if change_rate > 0 else float('inf')
        print(f"\n  HARMONIC CHANGE RATE: {change_rate:.2%} of bar transitions change pitch set")
        print(f"  AVG BARS PER HARMONY STATE: {avg_bars_per_chord:.1f}")

        all_pcs = frozenset(p % 12 for p in pitches)
        all_pc_names = sorted(NOTE_NAMES[pc] for pc in all_pcs)
        print(f"  ALL PITCH CLASSES: {all_pc_names}")

        best_key, best_corr = estimate_key(pc_counts)
        print(f"  ESTIMATED KEY: {best_key} (corr={best_corr:.4f})")

        # Section structure: divide into 8-bar sections, count notes
        section_size = 8
        max_section = int(math.ceil(n_bars / section_size))
        section_counts = []
        for s in range(max_section):
            start_bar = s * section_size
            end_bar   = start_bar + section_size
            count = sum(bar_note_counts.get(b, 0) for b in range(start_bar, end_bar))
            section_counts.append(count)
        print(f"\n  SECTION DENSITY (notes per 8-bar section): {section_counts}")

        # Velocity arc over time (first/mid/last third)
        third = len(notes) // 3
        if third > 0:
            v_start = statistics.mean(vels[:third])
            v_mid   = statistics.mean(vels[third:2*third])
            v_end   = statistics.mean(vels[2*third:])
            print(f"  VELOCITY ARC (start/mid/end thirds): {v_start:.1f} / {v_mid:.1f} / {v_end:.1f}")

    print(f"\n{'='*72}\n")

if __name__ == '__main__':
    import sys
    paths = sys.argv[1:] if len(sys.argv) > 1 else []
    if not paths:
        print("Usage: python3 analyze_midi_general.py file1.mid [file2.mid ...]")
        sys.exit(0)
    for path in paths:
        analyze_midi(path)
