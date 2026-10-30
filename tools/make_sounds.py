"""Generates every original sound effect and the music loop for Little Alien.

All audio is synthesized from scratch (no samples). Run:
    python3 tools/make_sounds.py
Output goes to LittleAlien/Sounds/*.wav (mono, 44100 Hz, 16-bit).
"""
import os
import numpy as np
from scipy.signal import lfilter, butter

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "LittleAlien", "Sounds")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def save(name, x, gain=0.9):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * gain
    pcm = (x * 32767).astype("<i2")
    import wave
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def t_(dur):
    return np.arange(int(dur * SR)) / SR


def env(n, a=0.01, r=0.1, curve=2.0):
    e = np.ones(n)
    na, nr = int(a * SR), int(r * SR)
    if na: e[:na] = np.linspace(0, 1, na)
    if nr: e[-nr:] *= np.linspace(1, 0, nr) ** curve
    return e


def formant(x, freq, bw):
    r = np.exp(-np.pi * bw / SR)
    th = 2 * np.pi * freq / SR
    return lfilter([1 - r], [1, -2 * r * np.cos(th), r * r], x)


def glottal(f0):
    """Band-limited-ish pulse train from a per-sample f0 curve."""
    ph = np.cumsum(f0 / SR)
    saw = 2 * (ph % 1) - 1
    pulse = np.maximum(0, np.sin(2 * np.pi * ph)) ** 3
    return 0.6 * pulse + 0.4 * saw


def vowel(src, formants):
    out = np.zeros_like(src)
    for f, bw, g in formants:
        out += g * formant(src, f, bw)
    return out


def lp(x, fc, order=2):
    b, a = butter(order, fc / (SR / 2), "low")
    return lfilter(b, a, x)


def hp(x, fc, order=2):
    b, a = butter(order, fc / (SR / 2), "high")
    return lfilter(b, a, x)

# ---------------------------------------------------------------- animals

def sheep(i, base):
    dur = 0.75 + 0.15 * i
    t = t_(dur)
    n = len(t)
    # "b" onset then a bleating "aaa" with fast vibrato (the bleat)
    f0 = base * (1 + 0.06 * np.sin(2 * np.pi * 1.2 * t)) * (1 - 0.12 * t / dur)
    f0 *= 1 + 0.035 * np.sin(2 * np.pi * 26 * t)
    src = glottal(f0)
    trem = 0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 13 * t))
    v = vowel(src, [(850, 120, 1.0), (1350, 160, 0.7), (2600, 250, 0.35)]) * trem
    v += 0.04 * rng.standard_normal(n) * env(n, 0.002, dur - 0.01)
    e = env(n, 0.03, 0.25, 1.5)
    e[:int(0.05 * SR)] *= np.linspace(0.2, 1, int(0.05 * SR))
    save(f"sheep_{i}", v * e)


def cow():
    dur = 1.3
    t = t_(dur)
    n = len(t)
    f0 = 105 + 25 * np.sin(np.pi * t / dur) - 15 * t
    src = glottal(f0)
    f1 = np.linspace(350, 650, n)
    out = np.zeros(n)
    # sweep "mmm-ooo": approximate by blending two filtered versions
    a = vowel(src, [(300, 90, 1.0), (900, 150, 0.4), (2300, 200, 0.1)])
    b = vowel(src, [(650, 110, 1.0), (1000, 140, 0.6), (2400, 220, 0.15)])
    mix = np.clip(t / 0.5, 0, 1)
    out = a * (1 - mix) + b * mix
    save("cow", lp(out, 2500) * env(n, 0.12, 0.4, 1.2))


def pig():
    parts = []
    for k in range(3):
        dur = 0.13 + 0.03 * k
        t = t_(dur)
        n = len(t)
        f0 = 170 - 60 * t / dur
        src = glottal(f0) + 0.5 * rng.standard_normal(n)
        v = vowel(src, [(500, 300, 1.0), (1500, 400, 0.5)])
        parts.append(v * env(n, 0.01, 0.06))
        parts.append(np.zeros(int(0.06 * SR)))
    save("pig", np.concatenate(parts))


def dog():
    parts = []
    for k in range(2):
        t = t_(0.14)
        n = len(t)
        f0 = 420 - 500 * t
        src = glottal(f0) + 0.3 * rng.standard_normal(n)
        parts.append(vowel(src, [(700, 200, 1), (1600, 300, 0.6)]) * env(n, 0.005, 0.08))
        parts.append(np.zeros(int(0.09 * SR)))
    save("dog", np.concatenate(parts))


def grumble(i):
    """Fallback grumpy old-man 'hmph / heh' if no voice lines get generated."""
    dur = 0.6
    t = t_(dur)
    n = len(t)
    f0 = (120 - 20 * i) * (1 + 0.05 * np.sin(2 * np.pi * 7 * t)) - 30 * t
    src = glottal(f0) + 0.15 * rng.standard_normal(n)
    v = vowel(src, [(550, 130, 1.0), (1100, 150, 0.5), (2400, 220, 0.2)])
    v *= 0.7 + 0.3 * np.abs(np.sin(2 * np.pi * 9 * t))
    save(f"grumble_{i}", lp(v, 3000) * env(n, 0.04, 0.25))

# ---------------------------------------------------------------- effects

def coin():
    t = t_(0.28)
    n = len(t)
    f = np.where(t < 0.06, 988, 1319)
    ph = np.cumsum(f / SR)
    x = np.sign(np.sin(2 * np.pi * ph)) * 0.5 + np.sin(2 * np.pi * ph)
    save("coin", lp(x, 6000) * env(n, 0.002, 0.2, 1.5), 0.6)


def collect():
    t = t_(0.22)
    n = len(t)
    f = 300 + 900 * (t / 0.22) ** 0.7
    x = np.sin(2 * np.pi * np.cumsum(f / SR))
    save("collect", x * env(n, 0.004, 0.12), 0.7)


def beam_grab():
    t = t_(0.35)
    n = len(t)
    f = 500 + 1400 * t / 0.35
    x = np.sin(2 * np.pi * np.cumsum(f / SR)) * (0.6 + 0.4 * np.sin(2 * np.pi * 40 * t))
    x += 0.2 * hp(rng.standard_normal(n), 3000)
    save("grab", x * env(n, 0.01, 0.2), 0.45)


def hit():
    t = t_(0.5)
    n = len(t)
    noise = lp(rng.standard_normal(n), 1800)
    buzz = np.sign(np.sin(2 * np.pi * np.cumsum((160 - 120 * t) / SR)))
    x = 0.8 * noise * env(n, 0.002, 0.45, 3) + 0.6 * buzz * env(n, 0.002, 0.3, 2)
    save("hit", x)


def explode():
    t = t_(1.0)
    n = len(t)
    noise = rng.standard_normal(n)
    x = lp(noise, 900) * np.exp(-4 * t) + 0.5 * lp(noise, 200) * np.exp(-2 * t)
    save("explode", x)


def powerup():
    notes = [523, 659, 784, 1047, 1319]
    parts = []
    for f in notes:
        t = t_(0.07)
        x = np.sin(2 * np.pi * f * t) + 0.4 * np.sign(np.sin(2 * np.pi * f * t))
        parts.append(x * env(len(t), 0.003, 0.03))
    save("powerup", np.concatenate(parts), 0.6)


def levelup():
    parts = []
    for f in [784, 988, 1175, 1568]:
        t = t_(0.09)
        x = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(4 * np.pi * f * t)
        parts.append(x * env(len(t), 0.003, 0.05))
    save("levelup", np.concatenate(parts), 0.6)


def crash():
    t = t_(1.4)
    n = len(t)
    f = 700 * np.exp(-2.5 * t) + 60
    whistle = np.sin(2 * np.pi * np.cumsum(f / SR)) * (t < 0.8)
    boom = lp(rng.standard_normal(n), 500) * np.exp(-3 * np.maximum(0, t - 0.8)) * (t >= 0.8)
    save("crash", 0.5 * whistle * env(n, 0.01, 0.1) + boom)


def missile():
    t = t_(0.4)
    n = len(t)
    x = hp(rng.standard_normal(n), 1500) * env(n, 0.005, 0.3) * 0.7
    x += np.sin(2 * np.pi * np.cumsum((900 - 600 * t) / SR)) * env(n, 0.005, 0.3) * 0.4
    save("missile", x, 0.5)


def ufo_in():
    t = t_(0.9)
    n = len(t)
    f = 200 + 600 * (1 - t / 0.9) + 40 * np.sin(2 * np.pi * 8 * t)
    x = np.sin(2 * np.pi * np.cumsum(f / SR)) + 0.3 * np.sin(2 * np.pi * np.cumsum(2.01 * f / SR))
    save("ufo_in", x * env(n, 0.05, 0.3), 0.5)


def click():
    t = t_(0.06)
    x = np.sin(2 * np.pi * 1200 * t) * np.exp(-60 * t)
    save("click", x, 0.5)

# ---------------------------------------------------------------- music

def pluck(freq, dur, bright=0.5):
    """Karplus-Strong string pluck (banjo-like)."""
    n = int(dur * SR)
    period = max(2, int(SR / freq))
    buf = rng.uniform(-1, 1, period)
    out = np.zeros(n)
    idx = 0
    for i in range(n):
        out[i] = buf[idx]
        nxt = (idx + 1) % period
        buf[idx] = 0.996 * (bright * buf[idx] + (1 - bright) * buf[nxt]) if i % 2 else 0.996 * 0.5 * (buf[idx] + buf[nxt])
        idx = nxt
    return out * env(n, 0.001, min(0.05, dur / 3))


def note(name):
    names = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3, "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((names[pitch] + 12 * (octave - 4)) / 12)


def music():
    bpm = 132
    beat = 60 / bpm
    bars = 16
    total = int(bars * 4 * beat * SR)
    mix = np.zeros(total + SR)

    def put(x, at, g=1.0):
        s = int(at * SR)
        e = min(len(mix), s + len(x))
        mix[s:e] += g * x[: e - s]

    # Chords: G G C G | D D G G | G G C C | D D G G (country I-IV-V)
    prog = ["G", "G", "C", "G", "D", "D", "G", "G", "G", "G", "C", "C", "D", "D", "G", "G"]
    chord_notes = {"G": ["G3", "B3", "D4"], "C": ["C4", "E4", "G4"], "D": ["D4", "F#4", "A4"]}
    bass_root = {"G": ("G2", "D3"), "C": ("C3", "G2"), "D": ("D3", "A2")}

    # bass: oom-pah on beats 1 and 3, root / fifth
    for b, ch in enumerate(prog):
        r, f = bass_root[ch]
        for k, nn in enumerate([r, f]):
            t = t_(beat * 1.6)
            fr = note(nn)
            x = (np.sin(2 * np.pi * fr * t) + 0.3 * np.sin(4 * np.pi * fr * t)) * np.exp(-3 * t)
            put(x, (b * 4 + k * 2) * beat, 0.55)

    # banjo roll on eighth notes
    for b, ch in enumerate(prog):
        cn = chord_notes[ch]
        roll = [cn[0], cn[1], cn[2], cn[1], cn[0], cn[2], cn[1], cn[2]]
        for k, nn in enumerate(roll):
            fr = note(nn) * (2 if k % 4 == 2 else 1)
            put(pluck(fr, beat * 0.9, 0.55), (b * 4 + k * 0.5) * beat, 0.22)

    # lead melody (original), quarter/eighth notes, two 8-bar phrases
    mel = [
        ("D5", 1), ("B4", .5), ("D5", .5), ("G5", 1), ("D5", 1),
        ("E5", 1), ("D5", .5), ("B4", .5), ("A4", 2),
        ("G4", .5), ("A4", .5), ("B4", 1), ("C5", 1), ("E5", 1),
        ("D5", 1.5), ("B4", .5), ("G4", 2),
        ("A4", 1), ("B4", .5), ("C5", .5), ("D5", 1), ("F#5", 1),
        ("A5", 1), ("F#5", .5), ("D5", .5), ("E5", 2),
        ("D5", .5), ("B4", .5), ("G4", 1), ("A4", 1), ("B4", 1),
        ("G4", 3), (None, 1),
    ]
    pos = 0.0
    for rep in range(2):
        for nn, d in mel:
            if nn:
                fr = note(nn)
                t = t_(d * beat * 0.95)
                vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t)
                ph = np.cumsum(fr * vib / SR)
                x = 0.6 * np.sin(2 * np.pi * ph) + 0.25 * np.sin(4 * np.pi * ph) + 0.1 * np.sign(np.sin(2 * np.pi * ph))
                x *= env(len(t), 0.01, min(0.08, d * beat * 0.4))
                put(x, pos * beat, 0.32 if rep == 0 else 0.38)
            pos += d

    # drums: kick on 1&3, snare-ish brush on 2&4, shaker eighths
    for i in range(bars * 4):
        at = i * beat
        if i % 2 == 0:
            t = t_(0.18)
            put(np.sin(2 * np.pi * np.cumsum((110 * np.exp(-25 * t) + 45) / SR)) * np.exp(-14 * t), at, 0.7)
        else:
            t = t_(0.15)
            put(hp(rng.standard_normal(len(t)), 1200) * np.exp(-22 * t), at, 0.22)
        for h in (0, 0.5):
            t = t_(0.05)
            put(hp(rng.standard_normal(len(t)), 5000) * np.exp(-60 * t), at + h * beat, 0.12)

    mix = mix[:total]
    # gentle compression + fade seams for a clean loop
    mix = np.tanh(mix * 1.4)
    save("music", mix, 0.75)


def menu_music():
    """Slower, spooky-cute night loop for menus."""
    bpm = 96
    beat = 60 / bpm
    bars = 8
    total = int(bars * 4 * beat * SR)
    mix = np.zeros(total + SR)

    def put(x, at, g=1.0):
        s = int(at * SR)
        e = min(len(mix), s + len(x))
        mix[s:e] += g * x[: e - s]

    prog = [["E3", "G3", "B3"], ["C3", "E3", "G3"], ["A2", "C3", "E3"], ["B2", "D#3", "F#3"]] * 2
    for b, ch in enumerate(prog):
        for k in range(8):
            fr = note(ch[[0, 1, 2, 1][k % 4]]) * 2
            put(pluck(fr, beat, 0.6), (b * 4 + k * 0.5) * beat, 0.25)
        t = t_(beat * 4)
        fr = note(ch[0]) / 2
        put(np.sin(2 * np.pi * fr * t) * env(len(t), 0.2, 1.0), b * 4 * beat, 0.35)
    # theremin-like lead
    mel = [("B4", 2), ("G4", 1), ("E4", 1), ("C5", 2), ("B4", 2), ("A4", 2), ("C5", 1), ("E5", 1), ("D#5", 4),
           ("E5", 2), ("B4", 2), ("C5", 2), ("G4", 2), ("A4", 3), ("B4", 1), ("E4", 4)]
    pos = 0
    for nn, d in mel:
        t = t_(d * beat)
        fr = note(nn) * (1 + 0.012 * np.sin(2 * np.pi * 6 * t))
        x = np.sin(2 * np.pi * np.cumsum(fr / SR)) * env(len(t), 0.15, 0.3)
        put(x, pos * beat, 0.3)
        pos += d
    save("menu_music", np.tanh(mix[:total] * 1.3), 0.7)


# ---------------------------------------------------------------- v2 effects

def thunder():
    t = t_(2.6)
    n = len(t)
    crack = hp(rng.standard_normal(n), 800) * np.exp(-18 * t)
    rumble = lp(rng.standard_normal(n), 140) * (np.exp(-1.2 * t) * (0.6 + 0.4 * np.sin(2 * np.pi * 3 * t)))
    save("thunder", 0.6 * crack + 1.4 * rumble)


def shot():
    t = t_(0.45)
    n = len(t)
    x = lp(rng.standard_normal(n), 3000) * np.exp(-14 * t) + 0.5 * np.sin(2 * np.pi * 90 * t) * np.exp(-20 * t)
    save("shot", x)


def plane():
    t = t_(2.2)
    n = len(t)
    f = 95 * (1.12 - 0.24 * t / 2.2)
    ph = np.cumsum(f / SR)
    eng = np.sign(np.sin(2 * np.pi * ph)) * 0.5 + np.sin(4 * np.pi * ph) * 0.3
    eng *= 0.7 + 0.3 * np.sin(2 * np.pi * 28 * t)
    vol = np.sin(np.pi * t / 2.2) ** 1.5
    save("plane", lp(eng, 1800) * vol, 0.6)


def heli():
    t = t_(1.0)
    n = len(t)
    chop = (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 14 * t))) * np.exp(-((t * 14) % 1) * 6)
    x = lp(rng.standard_normal(n), 600) * chop + 0.2 * np.sin(2 * np.pi * 60 * t)
    save("heli", x, 0.6)


def nuke():
    t = t_(2.4)
    n = len(t)
    boom = lp(rng.standard_normal(n), 300) * np.exp(-1.6 * t)
    rise = np.sin(2 * np.pi * np.cumsum((200 + 900 * t / 2.4) / SR)) * np.exp(-2 * t) * 0.3
    crack = hp(rng.standard_normal(n), 2000) * np.exp(-25 * t) * 0.6
    save("nuke", boom * 1.4 + rise + crack)


def chest():
    parts = []
    for f in [523, 659, 784, 1047, 784, 1047, 1319, 1568]:
        tt = t_(0.09)
        x = np.sin(2 * np.pi * f * tt) + 0.35 * np.sin(4 * np.pi * f * tt) + 0.2 * np.sin(6 * np.pi * f * tt)
        parts.append(x * env(len(tt), 0.003, 0.06))
    tail = t_(0.6)
    shimmer = sum(np.sin(2 * np.pi * f * tail) for f in [2093, 2637, 3136]) * np.exp(-5 * tail) * 0.25
    save("chest", np.concatenate(parts + [shimmer]), 0.6)


def achieve():
    notes = [(784, .12), (988, .12), (1175, .12), (1568, .45)]
    parts = []
    for f, d in notes:
        tt = t_(d)
        x = np.sin(2 * np.pi * f * tt) + 0.5 * np.sign(np.sin(2 * np.pi * f * tt)) * 0.3 + 0.3 * np.sin(2 * np.pi * f * 1.5 * tt)
        parts.append(x * env(len(tt), 0.005, min(0.2, d * 0.6)))
    save("achieve", np.concatenate(parts), 0.6)


def siren():
    t = t_(1.6)
    f = 700 + 300 * np.sin(2 * np.pi * 1.25 * t)
    x = np.sin(2 * np.pi * np.cumsum(f / SR)) + 0.3 * np.sign(np.sin(2 * np.pi * np.cumsum(f / SR)))
    save("siren", x * env(len(t), 0.05, 0.3), 0.45)


def mega():
    t = t_(0.7)
    f = 300 + 1500 * (t / 0.7) ** 2
    x = np.sin(2 * np.pi * np.cumsum(f / SR)) * (0.6 + 0.4 * np.sin(2 * np.pi * 30 * t))
    save("mega", x * env(len(t), 0.01, 0.2), 0.6)


def warn():
    parts = []
    for _ in range(3):
        tt = t_(0.12)
        parts.append(np.sign(np.sin(2 * np.pi * 1200 * tt)) * env(len(tt), 0.003, 0.03) * 0.6)
        parts.append(np.zeros(int(0.08 * SR)))
    save("warn", np.concatenate(parts), 0.5)


if __name__ == "__main__":
    for i, b in enumerate([330, 380, 290]):
        sheep(i, b)
    cow(); pig(); dog()
    for i in range(3):
        grumble(i)
    coin(); collect(); beam_grab(); hit(); explode(); powerup(); levelup(); crash(); missile(); ufo_in(); click()
    music(); menu_music()
    thunder(); shot(); plane(); heli(); nuke(); chest(); achieve(); siren(); mega(); warn()
    print("ok", sorted(os.listdir(OUT)))
