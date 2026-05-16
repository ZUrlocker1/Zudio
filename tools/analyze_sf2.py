#!/usr/bin/env python3
"""Cluster analysis of unused presets in Zudio.sf2."""
import struct
from collections import defaultdict

SF2 = 'assets/Zudio.sf2'
with open(SF2,'rb') as f: data = f.read()

def parse_riff(data, pos=0, end=None):
    if end is None: end = len(data)
    chunks = {}
    while pos+8 <= end:
        tag = data[pos:pos+4]; size = struct.unpack_from('<I',data,pos+4)[0]
        bs,be = pos+8, pos+8+size
        if tag in (b'RIFF',b'LIST'): chunks.update(parse_riff(data,bs+4,be))
        else: chunks[tag] = (bs, size)
        pos = be + (be%2)
    return chunks

chunks = parse_riff(data)
def get(tag):
    t = tag.encode() if isinstance(tag,str) else tag
    off,sz = chunks[t]; return data[off:off+sz]
def recs(tag,sz): d=get(tag); return [d[i*sz:i*sz+sz] for i in range(len(d)//sz)]

phdr=recs('phdr',38); pbag=recs('pbag',4); pgen=recs('pgen',4)
inst=recs('inst',22); ibag=recs('ibag',4); igen=recs('igen',4); shdr=recs('shdr',46)
NP,NB_P,NG_P = len(phdr),len(pbag),len(pgen)
NI,NB_I,NG_I = len(inst),len(ibag),len(igen)
NS = len(shdr)

u16 = lambda r,o: struct.unpack_from('<H',r,o)[0]
u32 = lambda r,o: struct.unpack_from('<I',r,o)[0]

def pbag_range(p): s=u16(phdr[p],24); e=u16(phdr[p+1],24) if p+1<NP else NB_P; return s,e
def ibag_range(i): s=u16(inst[i],20); e=u16(inst[i+1],20) if i+1<NI else NB_I; return s,e

def preset_insts(p):
    bs,be = pbag_range(p); r=[]
    for b in range(bs, min(be,NB_P-1)):
        for g in range(u16(pbag[b],0), min(u16(pbag[b+1],0),NG_P)):
            if u16(pgen[g],0)==41: r.append(u16(pgen[g],2))
    return r

def inst_samples(i):
    if i >= NI-1: return []
    bs,be = ibag_range(i); r=[]
    for b in range(bs, min(be,NB_I-1)):
        for g in range(u16(ibag[b],0), min(u16(ibag[b+1],0),NG_I)):
            if u16(igen[g],0)==53:
                v = u16(igen[g],2)
                if v < NS: r.append(v)
    return r

def expand_stereo(ss):
    out = set(ss)
    for x in ss:
        lnk = u16(shdr[x],42)
        if lnk and lnk < NS-1: out.add(lnk)
    return out

def sbytes(s): return max(0, u32(shdr[s],24) - u32(shdr[s],20)) * 2

preset_samples = {}
for p in range(NP-1):
    ss = set()
    for i in preset_insts(p):
        for s in inst_samples(i): ss.add(s)
    preset_samples[p] = expand_stereo(ss)

# Zudio used (bank, preset) pairs
raw_prog = [59,66,65,56,71,73,79,78,100,82,46,73,100,68,74,81,62,90,83,63,13081,81,62,90,83,
            11,73,64,57,13,46,24,98,91,99,100,70,84,85,98,90,100,39,30,13088,90,100,39,30,
            95,50,94,88,95,50,89,91,89,50,48,95,94,95,92,50,9,8,98,96,112,5124,8014,
            4,5,17,16,18,39,5,18,28,8038,29,28,39,29,49,92,52,99,90,99,90,86,86,94,89,99,102,
            35,32,33,42,60,54,62,93,39,87,81,34,8038,39,87,34,33,12038,39,87,34,33]
drum_raw = [40,25,32,0,40,25,24,0,8,40,26,8,25,40]

used_bp = set()
for p in raw_prog:
    if p >= 60000 or (230 <= p <= 260): continue
    used_bp.add((p//1000 if p>=1000 else 0, p%1000 if p>=1000 else p))
for p in drum_raw: used_bp.add((128, p))

used_p  = {p for p in range(NP-1) if (u16(phdr[p],22), u16(phdr[p],20)) in used_bp}
unused_p = [p for p in range(NP-1) if p not in used_p]

used_s = set()
for p in used_p: used_s |= preset_samples[p]

pname = lambda p: phdr[p][:20].rstrip(b'\x00').decode('ascii','replace')
pinfo = lambda p: f"b={u16(phdr[p],22):3d} p={u16(phdr[p],20):3d}  {pname(p)}"

# Sample → which presets reference it
all_refs = defaultdict(set)
for p in range(NP-1):
    for s in preset_samples[p]: all_refs[s].add(p)

def freed_by_group(grp):
    gset = set(grp)
    gsamp = set()
    for p in grp: gsamp |= preset_samples[p]
    return {s for s in gsamp if all_refs[s].issubset(gset)}

# Union-find clustering by shared samples
par = {p:p for p in unused_p}
def find(x):
    while par[x] != x: par[x] = par[par[x]]; x = par[x]
    return x
def union(a,b):
    a,b = find(a),find(b)
    if a != b: par[b] = a

for s,ps in all_refs.items():
    ur = [p for p in ps if p in set(unused_p)]
    for i in range(1,len(ur)): union(ur[0], ur[i])

clusters = defaultdict(list)
for p in unused_p: clusters[find(p)].append(p)

# Total recoverable
purely_unused = set()
for p in unused_p: purely_unused |= preset_samples[p]
purely_unused -= used_s

print(f"Zudio.sf2: {len(data)/1024/1024:.2f} MB")
print(f"Presets: {NP-1} total  |  {len(used_p)} used by Zudio  |  {len(unused_p)} unused")
print(f"Max recoverable if ALL unused stripped: {sum(sbytes(s) for s in purely_unused)/1024/1024:.2f} MB\n")

print("="*70)
print("SAMPLE-SHARING CLUSTERS  (strip the whole cluster for stated savings)")
print("="*70)

rows = []
for root,members in clusters.items():
    freed = freed_by_group(members)
    kb = sum(sbytes(s) for s in freed)/1024
    rows.append((kb, members, freed))
rows.sort(reverse=True)

grand_total = 0
for kb,members,freed in rows:
    if kb < 30: continue
    grand_total += kb
    print(f"\n── {kb:.0f} KB freed ────────────────────────────────────────────")
    for p in sorted(members, key=lambda x: (u16(phdr[x],22), u16(phdr[x],20))):
        solo = freed_by_group([p])
        solo_kb = sum(sbytes(s) for s in solo)/1024
        print(f"  {pinfo(p):<44s}  solo={solo_kb:.0f} KB")

print(f"\n{'='*70}")
print(f"Strip all significant clusters  →  {grand_total:.0f} KB  ({grand_total/1024:.2f} MB) savings")
print(f"New estimated file size: ~{(len(data) - grand_total*1024)/1024/1024:.2f} MB")
