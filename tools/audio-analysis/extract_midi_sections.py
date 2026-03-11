#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


def read_u16be(b, o):
    return (b[o] << 8) | b[o + 1], o + 2


def read_u32be(b, o):
    return (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3], o + 4


def read_vlq(data, o):
    v = 0
    while True:
        c = data[o]
        o += 1
        v = (v << 7) | (c & 0x7F)
        if not (c & 0x80):
            return v, o


def parse_track(track_bytes):
    i = 0
    abs_tick = 0
    running = None
    notes = []
    meta = {"track_name": None, "time_sig": None, "tempo": []}
    active = {}

    while i < len(track_bytes):
        delta, i = read_vlq(track_bytes, i)
        abs_tick += delta
        status = track_bytes[i]

        if status < 0x80:
            if running is None:
                raise ValueError("Invalid running status")
            status = running
        else:
            i += 1
            running = status

        if status == 0xFF:
            meta_type = track_bytes[i]
            i += 1
            ln, i = read_vlq(track_bytes, i)
            payload = track_bytes[i:i + ln]
            i += ln
            if meta_type == 0x03:
                try:
                    meta["track_name"] = payload.decode("utf-8", errors="replace")
                except Exception:
                    meta["track_name"] = ""
            elif meta_type == 0x58 and ln >= 4:
                nn = payload[0]
                dd = 2 ** payload[1]
                meta["time_sig"] = [nn, dd]
            elif meta_type == 0x51 and ln == 3:
                us = (payload[0] << 16) | (payload[1] << 8) | payload[2]
                meta["tempo"].append({"tick": abs_tick, "us_per_qn": us})
            continue

        if status in (0xF0, 0xF7):
            ln, i = read_vlq(track_bytes, i)
            i += ln
            continue

        evt = status & 0xF0
        ch = status & 0x0F
        if evt in (0x80, 0x90):
            note = track_bytes[i]
            vel = track_bytes[i + 1]
            i += 2
            key = (ch, note)
            if evt == 0x90 and vel > 0:
                active.setdefault(key, []).append((abs_tick, vel))
            else:
                if key in active and active[key]:
                    st, v = active[key].pop(0)
                    dur = max(1, abs_tick - st)
                    notes.append({"start": st, "dur": dur, "note": note, "vel": v, "ch": ch})
        elif evt in (0xA0, 0xB0, 0xE0):
            i += 2
        elif evt in (0xC0, 0xD0):
            i += 1
        else:
            raise ValueError(f"Unknown event {status:02X}")

    return notes, meta


def parse_midi(path):
    b = Path(path).read_bytes()
    o = 0
    if b[o:o + 4] != b'MThd':
        raise ValueError('Not MIDI')
    o += 4
    hlen, o = read_u32be(b, o)
    fmt, o = read_u16be(b, o)
    ntr, o = read_u16be(b, o)
    div, o = read_u16be(b, o)
    o = 8 + hlen

    tracks = []
    for _ in range(ntr):
        if b[o:o + 4] != b'MTrk':
            raise ValueError('Missing MTrk')
        o += 4
        ln, o = read_u32be(b, o)
        tb = b[o:o + ln]
        o += ln
        notes, meta = parse_track(tb)
        tracks.append({"notes": notes, "meta": meta})

    return {"format": fmt, "tracks": tracks, "ticks_per_beat": div}


def notes_to_steps(notes, ticks_per_beat, start_bar, end_bar, bar_beats=4):
    ticks_per_step = ticks_per_beat / 4.0
    start_tick = int((start_bar - 1) * bar_beats * ticks_per_beat)
    end_tick = int((end_bar - 1) * bar_beats * ticks_per_beat)
    out = []
    for n in notes:
        s = n["start"]
        e = n["start"] + n["dur"]
        if e <= start_tick or s >= end_tick:
            continue
        ss = max(s, start_tick)
        ee = min(e, end_tick)
        step = int(round((ss - start_tick) / ticks_per_step))
        ln = max(1, int(round((ee - ss) / ticks_per_step)))
        out.append({"step": step, "len": ln, "note": n["note"], "vel": n["vel"], "ch": n["ch"]})
    out.sort(key=lambda x: (x["step"], x["note"]))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("midi")
    ap.add_argument("--out-json", required=True)
    ap.add_argument("--sections", default="intro:1-9,preverse:9-13,verse:13-25,bridge:25-33,chorus:33-49")
    ap.add_argument("--track-map", default="rhythm:0,bass:1,texture:2,drums:3")
    args = ap.parse_args()

    m = parse_midi(args.midi)
    tpb = m["ticks_per_beat"]

    section_defs = {}
    for item in args.sections.split(','):
        nm, rng = item.split(':', 1)
        a, b = rng.split('-', 1)
        section_defs[nm] = (int(a), int(b))

    track_map = {}
    for item in args.track_map.split(','):
        nm, idx = item.split(':', 1)
        track_map[nm] = int(idx)

    summary = {
        "midi": str(Path(args.midi)),
        "ticks_per_beat": tpb,
        "tracks": [],
        "sections": {},
    }

    for i, t in enumerate(m["tracks"]):
        summary["tracks"].append({
            "index": i,
            "name": t["meta"]["track_name"],
            "note_count": len(t["notes"]),
        })

    for sec, (sbar, ebar) in section_defs.items():
        sec_data = {}
        for tname, idx in track_map.items():
            notes = m["tracks"][idx]["notes"] if idx < len(m["tracks"]) else []
            sec_data[tname] = notes_to_steps(notes, tpb, sbar, ebar)
        summary["sections"][sec] = {
            "bars": [sbar, ebar],
            "tracks": sec_data,
        }

    Path(args.out_json).write_text(json.dumps(summary, indent=2))
    print(args.out_json)


if __name__ == "__main__":
    main()
