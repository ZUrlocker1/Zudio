#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path('/Users/urlocker/Downloads/Zudio')
AN = ROOT / 'docs/analysis-silly-love-songs-sections.json'
OUT = ROOT / 'assets/midi/motorik/starters/silly-love-songs-derived-v1.json'

D = json.loads(AN.read_text())

# Section windows (bars) inspired by user analysis.
# Windows are relative to extracted section starts and stored as compact starter units.
section_windows = {
    'intro': [('intro_sparse_8bar', 0, 8*16)],
    'preverse': [('preverse_groove_4bar', 0, 4*16)],
    'verse': [('verse_drive_a_4bar', 0, 4*16), ('verse_drive_b_4bar', 4*16, 8*16)],
    'bridge': [('bridge_sparse_8bar', 0, 8*16)],
    'chorus': [('chorus_lift_a_4bar', 0, 4*16), ('chorus_lift_b_4bar', 4*16, 8*16)],
}

def slice_events(events, s, e):
    out = []
    for ev in events:
        st = ev['step']
        en = st + ev['len']
        if en <= s or st >= e:
            continue
        ss = max(st, s)
        ee = min(en, e)
        out.append({
            'step': ss - s,
            'len': max(1, ee - ss),
            'note': ev['note'],
            'vel': ev['vel'],
            'ch': ev.get('ch', 0),
        })
    out.sort(key=lambda x: (x['step'], x['note']))
    return out

result = {
    'name': 'Wings Silly Love Songs Derived Starters',
    'version': 'v1',
    'source': {
        'midi': 'assets/midi/references/wings-silly-love-songs/Wings - Silly Love Songs.mid',
        'track_mapping': {
            'Rhythm': 'Linda (electric piano)',
            'Bass': 'Paul (electric bass)',
            'Texture': 'Percussion (intro-focused)',
            'Drums': 'Drums (rock kit)',
        },
        'note': 'Pop/disco-derived source used as rhythmic and arrangement vocabulary, not harmonic/style cloning.'
    },
    'tracks': {
        'Rhythm': [],
        'Bass': [],
        'Texture': [],
        'Drums': [],
    }
}

for sec_name, section in D['sections'].items():
    bars = section['bars']
    for label, s, e in section_windows.get(sec_name, []):
        for track in ('rhythm', 'bass', 'texture', 'drums'):
            sliced = slice_events(section['tracks'][track], s, e)
            if not sliced:
                continue
            key = track.capitalize()
            result['tracks'][key].append({
                'id': f"{key.lower()}_{label}",
                'section_source': sec_name,
                'bars': int((e - s) / 16),
                'events': sliced,
            })

OUT.write_text(json.dumps(result, indent=2))
print(OUT)
