#!/usr/bin/env python3
"""
clash_scan.py — count clashing notes in a folder of Zudio .MID + .zudio pairs.

Usage:
    python3 tools/clash_scan.py <folder>            # summary by substyle and rule
    python3 tools/clash_scan.py <folder> --worst 2  # also the N worst songs per substyle

A clash: two notes on different tracks (Lead 1, Lead 2, Pads, Rhythm, Bass) a semitone or
a minor ninth apart, sounding together for at least an 8th, where the later note starts on
a beat or the two overlap a beat or more. Pairs of chord tones (log chord plan, plus the 7th
Chill voices on every chord) are skipped. The clash is counted against the rule
that wrote the note outside the chord; if both are outside, the later note's rule. A song is a problem when one track has
more than 4 (Zack's threshold).

A second measure, persistent rubs, catches what the beat test misses: a note outside the chord
that rubs (a minor 2nd or 9th at any octave, or a major 7th with that note at the bottom;
overlapping a 16th or more) against two
or more other tracks at once, recurring in a run of more than 4 bars (a one-bar gap does not
break the run). That is "clashing with 3 instruments for more than a few bars" (Zack,
2026-11-13). A quick passing tone against one track, or a short run, is colour and not counted.
A song is also a problem when any track has such a run.

Severity (Zack, 2026-11-13, on Quantique Minipod: "not that bad, not like B against Bb"):
  glaring: the two notes are within an octave (a semitone, like B against Bb, or a major 7th
           with the outside note below), or a minor 9th held two beats or more with both
           notes at or above C3. A minor 9th held one beat that steps on (Quantique Minipod's
           lead: E, G#, A over E major, A over the pad's G#3, then B) is mild.
  mild:    everything else: two or more octaves apart (a low bass note under the pad), or a
           minor 9th that is short or has a note in the bass register.
A strong clash is graded by its own interval. A persistent run is glaring when the glaring
rubs alone make a run of more than 4 bars. Problem rates count glaring only; mild songs
(flagged only by mild clashes or runs) are reported in their own column.

Writes <folder>/scan.json. See docs/clash-fix.md.
"""
import sys
import mido,glob,re,collections,bisect,json
D=sys.argv[1]; WORST=int(sys.argv[sys.argv.index("--worst")+1]) if "--worst" in sys.argv else 0
NOTE={'C':0,'C#':1,'Db':1,'D':2,'D#':3,'Eb':3,'E':4,'F':5,'F#':6,'Gb':6,'G':7,'G#':8,'Ab':8,'A':9,'A#':10,'Bb':10,'B':11}
DEG={'1':0,'b2':1,'2':2,'b3':3,'3':4,'4':5,'#4':6,'b5':6,'5':7,'b6':8,'6':9,'b7':10,'7':11}
IV={'major':[0,4,7],'minor':[0,3,7],'sus2':[0,2,7],'sus4':[0,5,7],'add9':[0,4,7,14],'dom7':[0,4,7,10],'min7':[0,3,7,10],'quartal':[0,5,10],'power':[0,7,12],'maj7':[0,4,7,11],'maj9':[0,4,7,11,14],'min9':[0,3,7,10,14],'maj6':[0,4,7,9],'min6':[0,3,7,9],'dom9':[0,4,7,10,14],'min7b5':[0,3,6,10]}
def c7(t): return 11 if t in('major','maj7','maj9') else 9 if t in('maj6','min6') else 10
TRK=['Lead 1','Lead 2','Pads','Rhythm','Bass']
MAP={'LD1':'Lead 1','LD2':'Lead 2','PADS':'Pads','PAD':'Pads','RTHM':'Rhythm','RHY':'Rhythm','ARP':'Rhythm','BASS':'Bass'}
def load(p):
    m=mido.MidiFile(p); tr={}
    for t in m.tracks[1:]:
        if t.name not in TRK: continue
        ab=0;on={};ev=[]
        for x in t:
            ab+=x.time
            if x.type=='note_on' and x.velocity>0: on[x.note]=ab
            elif x.type in('note_off','note_on') and x.note in on:
                s=on.pop(x.note); ev.append((s,ab,x.note))
        tr[t.name]=sorted(ev)
    return m.ticks_per_beat,tr
res=[]
for mid in sorted(glob.glob(D+'/*.MID')):
    z=open(mid[:-4]+'.zudio',errors='replace').read()
    style=re.search(r'^Style:\s*(\S+)',z,re.M)[1]
    sub=(re.search(r'^Substyle:\s*(.*)$',z,re.M) or [0,style+' base'])[1].strip()
    k=re.search(r'^Key:\s+(\S+)',z,re.M); ton=NOTE[k[1]]
    pl={}
    for a,b,r,ty in re.findall(r'Bars\s+(\d+)\s*[–-]\s*(\d+)\s+root=(\S+)\s+type=(\w+)',z):
        rt=(ton+DEG.get(r,0))%12; iv=list(IV.get(ty,[0,4,7]))
        if style=='Chill': iv.append(c7(ty))
        for x in range(int(a),int(b)+1): pl[x]={(rt+i)%12 for i in iv}
    rules={}
    for tag,desc in re.findall(r'^\s+([A-Z]{3}-([A-Z0-9]+)-\d{3})\s',z,re.M) and [(m.group(1),m.group(2)) for m in re.finditer(r'^\s+([A-Z]{3}-([A-Z0-9]+)-\d{3})\s',z,re.M)]:
        t=MAP.get(desc)
        if t and t not in rules: rules[t]=tag
    tpb,tr=load(mid); bar=tpb*4
    cnt=collections.Counter(); gcnt=collections.Counter(); pairs=collections.Counter(); where=collections.defaultdict(list)
    names=[n for n in TRK if n in tr]
    for i,a in enumerate(names):
      for bn in names[i+1:]:
        B=tr[bn]; starts=[x[0] for x in B]; maxd=max([e-s for s,e,p in B] or [0])
        for s1,e1,p1 in tr[a]:
          j=bisect.bisect_left(starts,s1-maxd)
          while j<len(B) and B[j][0]<e1:
            s2,e2,p2=B[j]; j+=1
            d=abs(p1-p2)
            if d not in(1,13): continue
            o=min(e1,e2)-max(s1,s2)
            if o<tpb//2: continue
            st=max(s1,s2)
            if not(st%tpb==0 or o>=tpb): continue
            cs=pl.get(st//bar+1)
            if cs is None: continue
            n1=p1%12 not in cs; n2=p2%12 not in cs
            if not(n1 or n2): continue
            culprit = a if (n1 and not n2) else bn if (n2 and not n1) else (a if s1>=s2 else bn)
            cnt[culprit]+=1
            if d==1 or (o>=2*tpb and min(p1,p2)>=48): gcnt[culprit]+=1
            pairs[a+'/'+bn]+=1; where[culprit].append(st//bar+1)
    # Persistent rubs: bars where a track's note outside the chord rubs against 2+ other tracks.
    # A rub: a minor 2nd or minor 9th (or wider by octaves) either way, or a major 7th with the
    # note outside the chord at the bottom (a wrong bass note under a chord tone). An extension a
    # major 7th above a chord tone (the Rhythm's 13th over the bass's b7) is a voicing, not a rub.
    def rubs(p,p2): return abs(p-p2)%12==1 or (p<p2 and (p2-p)%12==11)
    def close(p,p2): return abs(p-p2)==1 or (p<p2 and p2-p==11)
    idx={n:([x[0] for x in tr[n]],max([e-s for s,e,p in tr[n]] or [0])) for n in names}
    grate={}; ggrate={}
    def runs_of(bs):
        runs=[]
        for b in sorted(bs):
            if runs and b-runs[-1][-1]<=2: runs[-1].append(b)
            else: runs.append([b])
        return [[r[0],r[-1],len(r)] for r in runs if len(r)>4]
    for a in names:
        gb=set(); gg=set()
        for s,e,p in tr[a]:
            cs=pl.get(s//bar+1)
            if cs is None or p%12 in cs: continue
            hits=0; near=False
            for bn in names:
                if bn==a: continue
                B=tr[bn]; starts,maxd=idx[bn]; j=bisect.bisect_left(starts,s-maxd)
                while j<len(B) and B[j][0]<e:
                    s2,e2,p2=B[j]; j+=1
                    o=min(e,e2)-max(s,s2)
                    if o>=tpb//4 and rubs(p,p2):
                        hits+=1; near=near or (o>=tpb//2 and close(p,p2)); break
            if hits>=2:
                gb.add(s//bar+1)
                if near: gg.add(s//bar+1)
        long=runs_of(gb)
        if long: grate[a]=long
        glong=runs_of(gg)
        if glong: ggrate[a]=glong
    res.append(dict(f=mid.split('/')[-1],title=re.search(r'^Title:\s*(.*)$',z,re.M)[1].strip(),sub=sub,rules=rules,cnt=dict(cnt),gcnt=dict(gcnt),ggrate=ggrate,pairs=dict(pairs),where={k:sorted(set(v)) for k,v in where.items()},grate=grate))
json.dump(res,open(D+'/scan.json','w'))

R=res
med=lambda v: sorted(v)[len(v)//2] if v else 0
problem=lambda r: any(v>4 for v in r['gcnt'].values()) or bool(r['ggrate'])
anyflag=lambda r: any(v>4 for v in r['cnt'].values()) or bool(r['grate'])
print('== By substyle: songs, problem songs (glaring: a track >4 glaring clashes or a glaring persistent rub), mild-only songs, median clashes per song (glaring/all); glaring clashes by the track whose rule caused them')
subs=collections.defaultdict(list)
for r in R: subs[r['sub']].append(r)
for s,rs in sorted(subs.items()):
    prob=sum(problem(r) for r in rs); mild=sum(anyflag(r) and not problem(r) for r in rs); pers=sum(bool(r['ggrate']) for r in rs)
    tot=collections.Counter()
    for r in rs: tot.update(r['gcnt'])
    print(f"{s:16s} n={len(rs):3d} problem={prob:3d} ({100*prob//len(rs):2d}%) mild-only={mild:3d} glaring-persistent={pers:3d} median={med([sum(r['gcnt'].values()) for r in rs]):3d}/{med([sum(r['cnt'].values()) for r in rs]):3d}  {dict(tot.most_common())}")
print('\n== By rule that caused the clash (rules in >=5 songs, glaring or mild rate >=15%; glaring = >4 glaring clashes or a glaring persistent rub; mild = flagged by mild ones only)')
rule=collections.defaultdict(list)
for r in R:
    for t,tag in r['rules'].items():
        g=r['gcnt'].get(t,0)>4 or t in r['ggrate']; f=r['cnt'].get(t,0)>4 or t in r['grate']
        rule[(t,tag)].append((g,f and not g,r['gcnt'].get(t,0),r['cnt'].get(t,0)))
rows=[(sum(x[0] for x in v)/len(v),sum(x[1] for x in v)/len(v),k,v) for k,v in rule.items() if len(v)>=5]
for rate,mrate,k,v in sorted(rows,reverse=True):
    gc=[x[2] for x in v]; ac=[x[3] for x in v]
    if rate>=0.15 or mrate>=0.15: print(f"  {k[1]:14s} {k[0]:7s} songs={len(v):3d} glaring: {sum(x[0] for x in v):3d} ({100*rate:3.0f}%) mild-only: {sum(x[1] for x in v):3d} ({100*mrate:3.0f}%) median glaring/all={med(gc):3d}/{med(ac):3d} max={max(gc)}/{max(ac)}")
if WORST:
    print('\n== Worst songs per substyle (track and rule that caused the clashes, count, first bars)')
    for s,rs in sorted(subs.items()):
        for r in sorted(rs,key=lambda r:(-max(r['gcnt'].values() or [0]),-max(r['cnt'].values() or [0])))[:WORST]:
            if not r['cnt']: continue
            c=r['gcnt'] or r['cnt']; t=max(c,key=c.get)
            print(f"  {s:16s} {r['title']:30s} {r['f']:32s} {t:7s} {r['rules'].get(t)} glaring {r['gcnt'].get(t,0)} of {r['cnt'][t]} bars {r['where'][t][:10]}")
    print('\n== Longest persistent rubs per substyle (track, rule, runs as first-last bar)')
    for s,rs in sorted(subs.items()):
        key=lambda r:-max([x[2] for v in r['grate'].values() for x in v] or [0])
        for r in sorted([r for r in rs if r['grate']],key=key)[:WORST]:
            for t,runs in r['grate'].items():
                g='glaring' if t in r['ggrate'] else 'mild'
                print(f"  {s:16s} {r['title']:30s} {r['f']:32s} {t:7s} {r['rules'].get(t)} {g:7s} {[(a,b) for a,b,n in runs]}")
