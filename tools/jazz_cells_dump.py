#!/usr/bin/env python3
# Bar-by-bar dump of chosen MIDI tracks, quantized to 16th steps, with the bass note that opens each bar.
# Usage: python3 -I tools/jazz_cells_dump.py <file.mid> <bassTrack> <track,track> <firstBar> <endBar>
# Output per note: step:pitch/durationSteps. Used to pick lick cells for CHL-LD1-013/014.
import sys, mido
NAMES=['C','Db','D','Eb','E','F','Gb','G','Ab','A','Bb','B']
def notes(m, ti):
    tpb=m.ticks_per_beat; out=[]; on={}; tick=0
    for msg in m.tracks[ti]:
        tick+=msg.time
        if msg.type=='note_on' and msg.velocity>0: on[msg.note]=(tick,msg.velocity)
        elif msg.type in('note_off','note_on') and msg.note in on:
            s,v=on.pop(msg.note); out.append((round(s*4/tpb), max(1,round((tick-s)*4/tpb)), msg.note, v))
    return sorted(out)
p=sys.argv[1]; m=mido.MidiFile(p); bass=int(sys.argv[2]); tracks=[int(x) for x in sys.argv[3].split(',')]
b0,b1=int(sys.argv[4]),int(sys.argv[5])
bn=notes(m,bass)
def root(bar):
    ns=[n for n in bn if bar*16<=n[0]<bar*16+16]
    if not ns: return '--'
    lo=min(ns,key=lambda n:(n[0],n[2])) # first note of bar
    return NAMES[lo[2]%12]
for ti in tracks:
    tn=notes(m,ti); print(f"## track {ti}")
    for bar in range(b0,b1):
        ns=[n for n in tn if bar*16<=n[0]<bar*16+16]
        s=' '.join(f"{n[0]-bar*16}:{NAMES[n[2]%12]}{n[2]//12-1}/{n[1]}" for n in ns)
        if ns: print(f"{bar:3d} [{root(bar):>2}] {s}")
