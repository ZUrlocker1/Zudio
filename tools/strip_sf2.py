#!/usr/bin/env python3
"""
strip_sf2.py — Strip unused presets from GeneralUser_GS_v1.471.sf2
and write the result as Zudio.sf2.

Run from the project root:
    python3 tools/strip_sf2.py

Output: assets/Zudio.sf2
"""

import struct, os, sys

INPUT  = 'assets/GeneralUser_GS_v1.471 original.sf2'
OUTPUT = 'assets/Zudio.sf2'

# Presets to remove (bank, preset) — top-20 greedy sweep + Cluster 2 + safe small clusters
REMOVE = {
    # ── original top-20 ───────────────────────────────────────────────────────
    (0,   3),   # Honky-Tonk
    (120, 56),  # SFX Kit (b=120 variant)
    (11,  61),  # Brass Section 3
    (0,  110),  # Fiddle
    (8,   19),  # Pipe Organ 2
    (8,   28),  # Funk Guitar
    (0,   41),  # Viola
    (0,   15),  # Dulcimer
    (12,  48),  # Full Orchestra
    (0,  104),  # Sitar
    (0,   69),  # English Horn
    (0,   26),  # Jazz Guitar
    (0,   43),  # Double Bass
    (8,    6),  # Coupled Harpsichord
    (0,   20),  # Reed Organ
    (0,   67),  # Baritone Sax
    (8,  107),  # Taisho Koto
    (0,   53),  # Voice Oohs
    (0,    2),  # Electric Grand
    (120,  48), # Orchestral Perc (b=120 variant)

    # ── Cluster 2: piano family + brass companions (~3 MB) ────────────────────
    (0,    0),  # Stereo Grand
    (0,    1),  # Bright Grand
    (0,   44),  # Stereo Strings Trem
    (0,   58),  # Tuba
    (0,   61),  # Brass Section
    (1,   44),  # Mono Strings Trem
    (1,   48),  # Mono Strings Fast
    (1,   49),  # Mono Strings Slow
    (1,   56),  # Trumpet 2
    (1,   57),  # Trombone 2
    (1,   59),  # Muted Trumpet 2
    (1,   61),  # Brass Section Mono
    (8,    4),  # Chorused Tine EP
    (8,    5),  # Chorused FM EP
    (8,   48),  # Orchestra Pad
    (8,   61),  # Brass Section 2
    (11,   0),  # Piano & Str.-Fade
    (11,   1),  # Piano & Str.-Sus
    (11,   4),  # Tine & FM EPs
    (11,   5),  # Piano & FM EP
    (11,  49),  # Stereo Strings Velo
    (12,   0),  # Bell Piano
    (12,   4),  # Bell Tine EP
    (12,  49),  # Mono Strings Velo

    # ── safe small clusters ────────────────────────────────────────────────────
    (0,   40),  # Violin              (912 KB)
    (0,   19),  # Pipe Organ          (655 KB)
    (0,   25),  # Steel Guitar        ─┐
    (0,   27),  # Clean Guitar         │
    (0,   51),  # Synth Strings 2      │ Guitar cluster
    (0,  103),  # Star Theme           │ (552 KB total)
    (8,   24),  # Ukulele              │
    (8,   25),  # 12-String Guitar     │
    (8,   27),  # Chorused Clean Gt.   │
    (12,  27),  # Clean Guitar 2       │
    (16,  25),  # Mandolin            ─┘
    (0,   21),  # Accordian           ─┐ Accordion cluster
    (0,   23),  # Bandoneon            │ (208 KB total)
    (8,   21),  # Italian Accordian   ─┘
    (0,   72),  # Piccolo             ─┐ Woodwind cluster
    (13,  48),  # Woodwind Choir      ─┘ (150 KB total)
    (0,   45),  # Pizzicato Strings   (132 KB)
    (0,  101),  # Goblin              (120 KB)
    (0,   75),  # Pan Flute            (72 KB)
    (0,  109),  # Bagpipes             (68 KB)
    (0,   55),  # Orchestra Hit        (65 KB)
    (0,   22),  # Harmonica            (60 KB)
    (0,  114),  # Steel Drums          (55 KB)
    (0,   10),  # Music Box            (40 KB)
    (0,   31),  # Guitar Harmonics     (32 KB)

    # ── individual instrument removals ────────────────────────────────────────
    (0,    7),  # Clavinet
    (0,   14),  # Tubular Bells
    (0,   47),  # Timpani
    (0,  105),  # Banjo

    # ── SFX / noise presets (shared with drum cluster — preset headers only) ──
    (0,  119),  # Reverse Cymbal
    (0,  120),  # Fret Noise
    (0,  121),  # Breath Noise
    (1,  120),  # Cut Noise
    (1,  121),  # Fl. Key Click
    (2,  120),  # String Slap
    (8,  115),  # Castanets
    # Sound effects — all banks
    (0,  122),  # Seashore
    (0,  123),  # Birds
    (0,  124),  # Telephone 1
    (0,  125),  # Helicopter
    (0,  126),  # Applause
    (0,  127),  # Gun Shot
    (1,  122),  # Rain
    (1,  123),  # Dog
    (1,  125),  # Car-Engine
    (1,  126),  # Laughing
    (1,  127),  # Machine Gun
    (2,  122),  # Thunder
    (2,  123),  # Horse Gallop
    (2,  124),  # Door Creaking
    (2,  125),  # Car-Stop
    (2,  126),  # Scream
    (2,  127),  # Lasergun
    (3,  122),  # Howling Winds
    (3,  123),  # Bird 2
    (3,  124),  # Door
    (3,  125),  # Car-Pass
    (3,  126),  # Punch
    (3,  127),  # Explosion
    (4,  122),  # Stream
    (4,  123),  # Scratch
    (4,  125),  # Car-Crash
    (4,  126),  # Heart Beat
    (5,  122),  # Bubbles
    (5,  125),  # Siren
    (5,  126),  # Footsteps
    (6,  125),  # Train
    (7,  125),  # Jet Plane
    (9,  125),  # Burst Noise

}

# ── helpers ──────────────────────────────────────────────────────────────────
u16 = lambda b, o: struct.unpack_from('<H', b, o)[0]
u32 = lambda b, o: struct.unpack_from('<I', b, o)[0]
i8  = lambda b, o: struct.unpack_from('<b', b, o)[0]

def parse_riff(data, pos=0, end=None):
    if end is None: end = len(data)
    chunks = {}
    while pos + 8 <= end:
        tag  = data[pos:pos+4]
        size = u32(data, pos+4)
        body_s, body_e = pos+8, pos+8+size
        if tag in (b'RIFF', b'LIST'):
            chunks.update(parse_riff(data, body_s+4, body_e))
            chunks[b'__POS__' + data[body_s:body_s+4]] = pos  # save LIST offset
        else:
            chunks[tag] = (body_s, size)
        pos = body_e + (body_e % 2)
    return chunks

def make_chunk(tag, data):
    pad = b'\x00' if len(data) % 2 else b''
    return tag + struct.pack('<I', len(data)) + data + pad

def make_list(fourcc, body):
    content = fourcc + body
    return b'LIST' + struct.pack('<I', len(content)) + content

def read_recs(data, chunks, tag, rec_sz):
    off, sz = chunks[tag]
    return [data[off + i*rec_sz : off + i*rec_sz + rec_sz] for i in range(sz // rec_sz)]

# ── load ──────────────────────────────────────────────────────────────────────
print(f"Reading {INPUT} …")
with open(INPUT, 'rb') as f:
    raw = f.read()
orig_mb = len(raw) / 1024 / 1024

chunks = parse_riff(raw)

smpl_off, smpl_sz = chunks[b'smpl']
smpl_data = raw[smpl_off : smpl_off + smpl_sz]

phdr = read_recs(raw, chunks, b'phdr', 38)
pbag = read_recs(raw, chunks, b'pbag',  4)
pmod = read_recs(raw, chunks, b'pmod', 10)
pgen = read_recs(raw, chunks, b'pgen',  4)
inst = read_recs(raw, chunks, b'inst', 22)
ibag = read_recs(raw, chunks, b'ibag',  4)
imod = read_recs(raw, chunks, b'imod', 10)
igen = read_recs(raw, chunks, b'igen',  4)
shdr = read_recs(raw, chunks, b'shdr', 46)

NP, NB_P, NM_P, NG_P = len(phdr), len(pbag), len(pmod), len(pgen)
NI, NB_I, NM_I, NG_I = len(inst), len(ibag), len(imod), len(igen)
NS = len(shdr)

print(f"  presets={NP-1}  inst={NI-1}  samples={NS-1}")

# ── decode accessors ──────────────────────────────────────────────────────────
def phdr_bank(r):   return u16(r, 22)
def phdr_preset(r): return u16(r, 20)
def phdr_bag(r):    return u16(r, 24)
def pbag_gen(r):    return u16(r,  0)
def pbag_mod(r):    return u16(r,  2)
def pgen_oper(r):   return u16(r,  0)
def pgen_val(r):    return u16(r,  2)
def inst_bag(r):    return u16(r, 20)
def ibag_gen(r):    return u16(r,  0)
def ibag_mod(r):    return u16(r,  2)
def igen_oper(r):   return u16(r,  0)
def igen_val(r):    return u16(r,  2)
def shdr_start(r):  return u32(r, 20)
def shdr_end(r):    return u32(r, 24)
def shdr_sl(r):     return u32(r, 28)
def shdr_el(r):     return u32(r, 32)
def shdr_link(r):   return u16(r, 42)

OPER_INST   = 41
OPER_SAMPLE = 53

def pbag_range(p_idx):
    s = phdr_bag(phdr[p_idx])
    e = phdr_bag(phdr[p_idx+1]) if p_idx+1 < NP else NB_P
    return s, e

def ibag_range(i_idx):
    s = inst_bag(inst[i_idx])
    e = inst_bag(inst[i_idx+1]) if i_idx+1 < NI else NB_I
    return s, e

def preset_insts(p_idx):
    bag_s, bag_e = pbag_range(p_idx)
    result = []
    for b in range(bag_s, min(bag_e, NB_P-1)):
        for g in range(pbag_gen(pbag[b]), min(pbag_gen(pbag[b+1]), NG_P)):
            if pgen_oper(pgen[g]) == OPER_INST:
                result.append(pgen_val(pgen[g]))
    return result

def inst_samples(i_idx):
    if i_idx >= NI-1: return []
    bag_s, bag_e = ibag_range(i_idx)
    result = []
    for b in range(bag_s, min(bag_e, NB_I-1)):
        for g in range(ibag_gen(ibag[b]), min(ibag_gen(ibag[b+1]), NG_I)):
            if igen_oper(igen[g]) == OPER_SAMPLE:
                v = igen_val(igen[g])
                if v < NS: result.append(v)
    return result

# ── identify what to keep ─────────────────────────────────────────────────────
remove_p  = set()
for p_idx in range(NP-1):
    if (phdr_bank(phdr[p_idx]), phdr_preset(phdr[p_idx])) in REMOVE:
        remove_p.add(p_idx)

# Verify all targets found
found_bp = {(phdr_bank(phdr[p]), phdr_preset(phdr[p])) for p in remove_p}
missing  = REMOVE - found_bp
if missing:
    print(f"WARNING: presets not found in SF2: {missing}")

keep_p = [p for p in range(NP-1) if p not in remove_p]

# Instruments referenced by kept presets
keep_i_set = set()
for p in keep_p:
    keep_i_set.update(preset_insts(p))
keep_i = sorted(keep_i_set)

# Samples referenced by kept instruments (+ stereo links)
keep_s_set = set()
for i in keep_i:
    for s in inst_samples(i):
        keep_s_set.add(s)
        lnk = shdr_link(shdr[s])
        if lnk and lnk < NS-1:
            keep_s_set.add(lnk)
keep_s_sorted = sorted(keep_s_set, key=lambda i: shdr_start(shdr[i]))

removed_s = set(range(NS-1)) - keep_s_set
print(f"  removing {len(remove_p)} presets, {NI-1-len(keep_i)} instruments, {len(removed_s)} samples")

# ── build new SMPL + offset map ───────────────────────────────────────────────
SMPL_PAD = 46   # SF2 spec minimum zeros after each sample

new_smpl    = bytearray()
old_to_new_s = {}   # old sample_idx → new sample_idx (position in new shdr array)
new_shdr_info = []  # (old_idx, new_start, new_end, new_sl, new_el)
cur = 0             # current frame position in new smpl

for new_idx, old_idx in enumerate(keep_s_sorted):
    old_to_new_s[old_idx] = new_idx
    r = shdr[old_idx]
    os_, oe = shdr_start(r), shdr_end(r)
    osl, oel = shdr_sl(r), shdr_el(r)

    audio = smpl_data[os_*2 : oe*2]
    ns = cur
    ne = ns + (oe - os_)
    shift = ns - os_
    # clamp loop points into valid range
    nsl = max(ns, min(ne, osl + shift)) if osl >= os_ else ns
    nel = max(ns, min(ne, oel + shift)) if oel >= os_ else ns

    new_smpl += audio
    new_smpl += bytes(SMPL_PAD * 2)
    cur = ne + SMPL_PAD
    new_shdr_info.append((old_idx, ns, ne, nsl, nel))

if len(new_smpl) % 2:
    new_smpl += b'\x00'

# ── build new SHDR ────────────────────────────────────────────────────────────
new_shdr_bytes = b''
for new_idx, (old_idx, ns, ne, nsl, nel) in enumerate(new_shdr_info):
    r  = bytearray(shdr[old_idx])
    struct.pack_into('<I', r, 20, ns)
    struct.pack_into('<I', r, 24, ne)
    struct.pack_into('<I', r, 28, nsl)
    struct.pack_into('<I', r, 32, nel)
    old_lnk = shdr_link(shdr[old_idx])
    new_lnk = old_to_new_s.get(old_lnk, 0) if old_lnk else 0
    struct.pack_into('<H', r, 42, new_lnk)
    new_shdr_bytes += bytes(r)
new_shdr_bytes += shdr[-1]   # EOS terminal

# ── build new INST / IBAG / IMOD / IGEN ──────────────────────────────────────
old_to_new_i = {old: new for new, old in enumerate(keep_i)}

new_inst_bytes = b''
new_ibag_bytes = b''
new_imod_bytes = b''
new_igen_bytes = b''

for old_iidx in keep_i:
    ir = bytearray(inst[old_iidx])
    struct.pack_into('<H', ir, 20, len(new_ibag_bytes)//4)
    new_inst_bytes += bytes(ir)

    bag_s, bag_e = ibag_range(old_iidx)
    for b in range(bag_s, min(bag_e, NB_I-1)):
        ibr = bytearray(4)
        struct.pack_into('<H', ibr, 0, len(new_igen_bytes)//4)
        struct.pack_into('<H', ibr, 2, len(new_imod_bytes)//10)
        new_ibag_bytes += bytes(ibr)

        g_s, g_e = ibag_gen(ibag[b]), ibag_gen(ibag[b+1])
        for g in range(g_s, min(g_e, NG_I)):
            gr = bytearray(igen[g])
            if igen_oper(igen[g]) == OPER_SAMPLE:
                struct.pack_into('<H', gr, 2, old_to_new_s.get(igen_val(igen[g]), 0))
            new_igen_bytes += bytes(gr)

        m_s, m_e = ibag_mod(ibag[b]), ibag_mod(ibag[b+1]) if b+1 < NB_I else NM_I
        for m in range(m_s, min(m_e, NM_I)):
            new_imod_bytes += imod[m]

# terminal ibag → terminal inst
new_ibag_bytes += struct.pack('<HH', len(new_igen_bytes)//4, len(new_imod_bytes)//10)
new_igen_bytes += igen[-1]
new_imod_bytes += imod[-1]
ti = bytearray(inst[-1])
struct.pack_into('<H', ti, 20, len(new_ibag_bytes)//4)
new_inst_bytes += bytes(ti)

# ── build new PHDR / PBAG / PMOD / PGEN ──────────────────────────────────────
new_phdr_bytes = b''
new_pbag_bytes = b''
new_pmod_bytes = b''
new_pgen_bytes = b''

for p_idx in keep_p:
    pr = bytearray(phdr[p_idx])
    struct.pack_into('<H', pr, 24, len(new_pbag_bytes)//4)
    new_phdr_bytes += bytes(pr)

    bag_s, bag_e = pbag_range(p_idx)
    for b in range(bag_s, min(bag_e, NB_P-1)):
        pbr = bytearray(4)
        struct.pack_into('<H', pbr, 0, len(new_pgen_bytes)//4)
        struct.pack_into('<H', pbr, 2, len(new_pmod_bytes)//10)
        new_pbag_bytes += bytes(pbr)

        g_s, g_e = pbag_gen(pbag[b]), pbag_gen(pbag[b+1])
        for g in range(g_s, min(g_e, NG_P)):
            gr = bytearray(pgen[g])
            if pgen_oper(pgen[g]) == OPER_INST:
                struct.pack_into('<H', gr, 2, old_to_new_i.get(pgen_val(pgen[g]), 0))
            new_pgen_bytes += bytes(gr)

        m_s, m_e = pbag_mod(pbag[b]), pbag_mod(pbag[b+1]) if b+1 < NB_P else NM_P
        for m in range(m_s, min(m_e, NM_P)):
            new_pmod_bytes += pmod[m]

# terminal pbag → terminal phdr
new_pbag_bytes += struct.pack('<HH', len(new_pgen_bytes)//4, len(new_pmod_bytes)//10)
new_pgen_bytes += pgen[-1]
new_pmod_bytes += pmod[-1]
tp = bytearray(phdr[-1])
struct.pack_into('<H', tp, 24, len(new_pbag_bytes)//4)
new_phdr_bytes += bytes(tp)

# ── reassemble SF2 ────────────────────────────────────────────────────────────
# INFO list: copy verbatim from original
info_list_pos = chunks[b'__POS__INFO']
info_list_sz  = u32(raw, info_list_pos+4)
info_list_raw = raw[info_list_pos : info_list_pos+8+info_list_sz]

new_sdta = make_list(b'sdta', make_chunk(b'smpl', bytes(new_smpl)))

new_pdta_body = (
    make_chunk(b'phdr', new_phdr_bytes) +
    make_chunk(b'pbag', new_pbag_bytes) +
    make_chunk(b'pmod', new_pmod_bytes) +
    make_chunk(b'pgen', new_pgen_bytes) +
    make_chunk(b'inst', new_inst_bytes) +
    make_chunk(b'ibag', new_ibag_bytes) +
    make_chunk(b'imod', new_imod_bytes) +
    make_chunk(b'igen', new_igen_bytes) +
    make_chunk(b'shdr', new_shdr_bytes)
)
new_pdta = make_list(b'pdta', new_pdta_body)

sfbk_content = b'sfbk' + info_list_raw + new_sdta + new_pdta
output       = b'RIFF' + struct.pack('<I', len(sfbk_content)) + sfbk_content

# ── write + report ────────────────────────────────────────────────────────────
os.makedirs(os.path.dirname(OUTPUT) or '.', exist_ok=True)
with open(OUTPUT, 'wb') as f:
    f.write(output)

new_mb  = len(output) / 1024 / 1024
saved   = orig_mb - new_mb
print(f"\nOriginal : {orig_mb:.2f} MB")
print(f"Stripped : {new_mb:.2f} MB")
print(f"Saved    : {saved:.2f} MB  ({100*saved/orig_mb:.1f}%)")
print(f"\nWrote {OUTPUT}")
print("Verify in Polyphone or fluidsynth before replacing the app bundle.")
