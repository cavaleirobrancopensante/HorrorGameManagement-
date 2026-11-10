"""Daily Bread's soundtrack, written as notes. See docs/music.md for what each piece is meant to be.

Three motifs run through every piece:
  PANEM    the Daily Bread theme, grace and home: a rise of a step and a fourth, then a sigh back down.
  CIVIC    the State's chime: three bright notes falling (5 3 1), friendly and empty.
  WHISPER  the Adversary: the home note, a half step above it, the home note, then the tritone.

Usage: python3 tools/music/compose.py [name ...]   renders assets/music/<name>.ogg (all pieces without names)
Needs numpy, scipy and ffmpeg.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from score import Song, midi, measure  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "music")

# PANEM: the theme, its answer, and a second phrase and answer. Eight bars of 4/4 in any mode.
PANEM = ["1:1.5 2:0.5 4:2", "3:1 2:1 1:2"]
PANEM_ANSWER = ["5:1.5 4:0.5 3:1 2:1", "1:4"]
PANEM_2 = ["4:1.5 5:0.5 6:2", "5:1 4:1 3:2"]
PANEM_2_ANSWER = ["2:1.5 3:0.5 2:1 7,:1", "1:4"]
HYMN = PANEM + PANEM_ANSWER + PANEM_2 + PANEM_2_ANSWER
# WHISPER, in any mode: the half step and the tritone are written as accidentals where the mode lacks them.
WHISPER_DORIAN = ["1:2 2-:2", "1:2 5-:2"]


def civic(s, bar, beat=0.0, inst="radio_chime", vel=0.6, pan=0.6, root=midi("C", 5)):
    """The State's chime: three falling notes of a major chord, dead on time."""
    for i, p in enumerate((root + 7, root + 4, root)):
        s.events.append((s.sec(s.at(bar, beat + i * 0.5)), inst, p, s.sec(0.5), vel, pan, 0.25, None))


def menu():
    """Give Us This Day. The main theme: the chant over the cold hum of the State, the dark under it."""
    s = Song("menu", "Give Us This Day", 60, 4, midi("D", 3), "dorian", reverb=(4.2, 0.42), humanize=0.01, seed=11)
    total = 38
    for b in range(0, total, 4):
        s.note("sub", s.at(b), 16, midi("D", 1), 0.3, 0.0, 0.1)
    # The ground: a cold open fifth, all the way through except where the dark comes up.
    s.chords("pad", 0, [0, 0, 0, 0, 0], 0.32, -1, 0.0, 0.4, voicing=(0, 4, 7), bars_each=4, shape="swell")
    s.chords("pad", 26, [0, 0, 0], 0.28, -1, 0.0, 0.4, voicing=(0, 4, 7), bars_each=4)
    for b in (0, 2, 12, 16, 26, 30, 34, 36):
        s.note("toll", s.at(b), 2, midi("D", 2), 0.55, -0.2, 0.6)
    # The schola sings the theme alone.
    s.mel("chant", 4, HYMN, 0.6, 0, 0.0, 0.55)
    # The organ comes in under it; a second line sings a fifth below, like the old organum.
    roots = [0, 6, 4, 0, 3, 2, 6, 0]
    s.mel("chant", 12, HYMN, 0.62, 0, 0.15, 0.55)
    s.mel("chant_u", 12, HYMN, 0.42, 0, -0.15, 0.55, shift=-4)
    s.chords("organ", 12, roots, 0.42, -1, 0.0, 0.5)
    s.chords("organ", 12, roots, 0.26, -2, 0.0, 0.4, voicing=(0,))
    # The dark comes up from below: a tritone in the strings, the Whisper in the brass, voices that are not there.
    s.note("tremolo", s.at(20), 24, midi("D", 2), 0.4, -0.3, 0.5, "swell")
    s.note("tremolo", s.at(20), 24, midi("Ab", 2), 0.35, 0.3, 0.5, "swell")
    s.mel("low_brass", 20, WHISPER_DORIAN + WHISPER_DORIAN[:1] + ["1:4"], 0.5, -1, 0.0, 0.4)
    s.mel("chant_u", 22, ["1:4", "2-:4"], 0.3, 0, 0.4, 0.7, shape="swell")
    s.scatter("whisper", 20, 6, (1, 2), (0.25, 0.5), send=0.6, beats=3)
    s.note("reverse", s.at(25), 4, midi("D", 3), 0.6, 0.0, 0.5)
    # The light comes back: everything sings the theme, and the bells ring.
    s.mel("chant_a", 26, HYMN, 0.72, 0, 0.1, 0.55)
    s.mel("chant_u", 26, HYMN, 0.5, 0, -0.15, 0.55, shift=-4)
    s.mel("organ", 26, HYMN, 0.32, 1, 0.2, 0.5)
    s.chords("organ", 26, roots, 0.5, -1, 0.0, 0.5)
    s.chords("organ", 26, roots, 0.3, -2, 0.0, 0.4, voicing=(0,))
    peal = [midi("D", 5), midi("F", 5), midi("A", 5), midi("C", 6), midi("D", 6)]
    for b in range(26, 34):
        for k in range(3):
            s.note("bell", s.at(b, float(s.rng.integers(0, 8)) / 2), 1, peal[int(s.rng.integers(0, 5))], 0.28,
                   float(s.rng.uniform(-0.7, 0.7)), 0.6)
    # Amen: the theme's last two notes, an open fifth, the bell.
    s.mel("chant", 34, ["5:2 4:2", "1:4"], 0.6, 0, 0.0, 0.6)
    s.chords("organ", 34, [0, 0], 0.4, -1, 0.0, 0.6, voicing=(0, 4, 7))
    return s


def night_shift():
    """Night Shift. Alone in the trailer after closing: an old piano, rain on the roof, a radio across the street."""
    s = Song("night_shift", "Night Shift", 70, 4, midi("A", 3), "aeolian", reverb=(2.2, 0.6), humanize=0.012, seed=21)
    total = 52
    s.hit("rain", 0, 0.55, 0.0, 0.15, beats=total * 4 + 8)
    s.chords("pad", 0, [0] * 7, 0.26, -1, 0.0, 0.4, voicing=(0, 4), bars_each=8)
    loop_a = [0, 5, 2, 6]
    loop_b = [0, 3, 5, 4]
    melody_a = PANEM + PANEM_ANSWER + ["r:2 3:1 2:1", "1:4", "r:4", "r:4"]
    melody_b = ["5:1 6:1 5:1 3:1", "4:2 3:2", "2:1 3:1 4:1 5:1", "3:4",
                "5:1 6:1 7:1 1':1", "2':2 1':1 7:1", "6:1 5:1 4:1 3:1", "2:4"]
    roots_b = [0, 3, 6, 5, 0, 4, 5, 4]
    s.broken("piano", 2, [0, 0], "0---", 1, 0.3, -1)
    s.broken("piano", 4, loop_a * 2, "0479", 1, 0.3, -1)
    s.mel("piano", 4, melody_a, 0.42, 1, 0.15, 0.4)
    s.broken("piano", 12, loop_a, "0479", 1, 0.28, -1)
    s.hit("static", s.at(13, 2), 0.4, 0.65, 0.2, beats=1.5)
    civic(s, 14, 0.0, vel=0.45)
    # The middle: the harmonium breathes in, the tune opens up.
    for start in (16, 24):
        s.broken("piano", start, roots_b, "0479", 1, 0.3, -1)
        s.chords("harmonium", start, roots_b, 0.22, -1, -0.1, 0.4)
    s.mel("piano", 16, melody_b, 0.45, 1, 0.15, 0.4)
    s.mel("piano", 24, melody_b, 0.48, 1, 0.15, 0.4)
    s.chords("strings", 24, roots_b, 0.16, 0, 0.0, 0.5, voicing=(2, 4))
    s.broken("piano", 32, loop_a * 2, "0479", 1, 0.28, -1)
    s.mel("piano", 32, melody_a, 0.4, 2, 0.2, 0.45)
    s.hit("static", s.at(35, 3), 0.35, 0.7, 0.2, beats=1)
    civic(s, 36, 0.0, vel=0.35, pan=0.75)
    # Late: the tune comes back in pieces and never quite gets home.
    s.broken("piano", 40, loop_a * 2, "0---", 1, 0.26, -1)
    s.mel("piano", 40, ["1:1.5 2:0.5 4:2", "3:1 2:3", "r:4", "r:4", "1:1.5 2:0.5 4:2", "3:4", "r:4", "r:4"],
          0.36, 1, 0.15, 0.5)
    s.note("piano", s.at(50), 4, midi("A", 1), 0.3, -0.1, 0.4)
    return s


def overcast():
    """Overcast. A grey working day: a harmonium, the old piano, and the State on the radio."""
    s = Song("overcast", "Overcast", 84, 4, midi("G", 3), "dorian", reverb=(1.8, 0.55), humanize=0.01, seed=31)
    tune = ["1:1 2:1 4:2", "3:1 2:1 1:1 5,:1", "1:1 2:1 4:1 5:1", "6:2 5:2",
            "4:1 5:1 6:1 4:1", "5:1 4:1 3:1 2:1", "3:1 2:1 1:1 7,:1", "1:4"]
    tune_roots = [0, 0, 3, 1, 3, 2, 6, 0]
    second = ["5:2 6:1 5:1", "4:2 3:2", "2:1 3:1 4:1 2:1", "5:4",
              "6:2 7:1 6:1", "5:2 4:2", "3:1 4:1 5:1 7,:1", "1:4"]
    second_roots = [4, 3, 1, 4, 3, 2, 6, 0]
    s.chords("harmonium", 0, [0, 3], 0.3, -1)

    def verse(bar, melody, roots, vel=0.5, octave=1, mode=None):
        s.chords("harmonium", bar, roots, 0.26, -1, -0.1, 0.35, mode=mode)
        s.broken("piano", bar, roots, "0474", 1, 0.28, -1)
        s.mel("piano", bar, melody, vel, octave, 0.15, 0.3, mode=mode)

    verse(2, tune, tune_roots)
    verse(10, tune, tune_roots)
    s.mel("harmonium", 10, tune, 0.18, 0, -0.2, 0.3)
    verse(18, second, second_roots)
    # The radio cuts in. The tune stops to listen.
    s.hit("static", s.at(25, 2), 0.5, 0.6, 0.2, beats=2)
    civic(s, 26, 0.0, vel=0.6)
    civic(s, 26, 2.0, vel=0.45)
    s.note("pad", s.at(26), 8, midi("G", 2), 0.35, 0.0, 0.4)
    s.note("pad", s.at(26), 8, midi("Ab", 2), 0.25, 0.0, 0.4)
    s.note("sub", s.at(26), 8, midi("G", 1), 0.4)
    # The tune again, colder: its sixth falls a half step.
    verse(28, tune, tune_roots, 0.45, 1, "aeolian")
    verse(36, second, second_roots, 0.5)
    s.chords("strings", 36, second_roots, 0.15, 0, 0.0, 0.45, voicing=(2, 4))
    verse(44, tune[:4], tune_roots[:4], 0.45)
    s.chords("harmonium", 48, [3, 0], 0.26, -1, 0.0, 0.45, bars_each=2)
    s.note("piano", s.at(50), 4, midi("G", 4), 0.35, 0.1, 0.4)
    return s


def outside():
    """Something Outside. Dread: the heartbeat, the Whisper in the low brass, a theme gone wrong."""
    s = Song("outside", "Something Outside", 54, 4, midi("C", 3), "locrian", reverb=(3.6, 0.55), humanize=0.035,
             seed=41)
    whisper = ["1:2 2:2", "1:2 5:2", "1:2 2:2", "1:4"]
    for b in range(0, 24, 4):
        s.note("sub", s.at(b), 16, midi("C", 1), 0.28, 0.0, 0.1)
    for b in range(8, 24, 4):
        s.note("sub", s.at(b), 16, midi("Gb", 1), 0.2, 0.0, 0.1)
    s.scatter("scrape", 0, 8, (0, 1), (0.25, 0.45), send=0.6, beats=6)
    s.note("tremolo", s.at(2), 24, midi("C", 5), 0.24, -0.5, 0.6, "swell")
    s.note("tremolo", s.at(2), 24, midi("Db", 5), 0.2, 0.5, 0.6, "swell")
    for b in range(4, 8):
        s.hit("heartbeat", s.at(b), 0.45, 0.0, 0.1)
    # The Whisper rises from the strings, and the theme comes back wrong on the piano.
    s.mel("strings", 8, whisper * 2, 0.5, 0, -0.2, 0.45)
    s.mel("strings", 8, whisper * 2, 0.3, -1, 0.2, 0.45)
    for b in range(8, 16):
        for beat in (0, 2):
            s.hit("heartbeat", s.at(b, beat), 0.5 + (b - 8) * 0.02, 0.0, 0.1)
    s.scatter("whisper", 8, 8, (0, 2), (0.2, 0.45), send=0.6, beats=3)
    s.mel("piano", 10, PANEM, 0.26, 2, 0.4, 0.6)
    s.mel("piano", 14, PANEM, 0.26, 2, -0.4, 0.6, shift=1)
    # It comes closer: a cluster in the strings, the brass, the booms, the heart racing.
    for p in (midi("C", 3), midi("Db", 3), midi("Gb", 3)):
        s.note("tremolo", s.at(16), 32, p, 0.33, float(s.rng.uniform(-0.5, 0.5)), 0.5, "swell")
    s.mel("low_brass", 16, whisper * 2, 0.55, 0, 0.0, 0.4)
    s.mel("low_brass", 16, whisper * 2, 0.35, -1, 0.0, 0.4)
    for b in (16, 20, 22, 23):
        s.hit("boom", s.at(b), 0.4 + (b - 16) * 0.03, 0.0, 0.35)
    for b in range(16, 24):
        for beat in range(4):
            s.hit("heartbeat", s.at(b, beat), 0.5 + (b - 16) * 0.04, 0.0, 0.1)
    s.scatter("whisper", 16, 8, (1, 3), (0.3, 0.55), send=0.55, beats=2)
    s.note("reverse", s.at(23), 4, midi("C", 3), 0.75, 0.0, 0.4)
    # Then nothing at all. One voice, close.
    s.cuts.append((s.at(24), s.at(25)))
    s.hit("whisper", s.at(24, 1), 0.8, 0.2, 0.15, beats=2.5, top=True)
    # After: the heart slows, a bell far off, a last note on the piano.
    for b in range(25, 32, 4):
        s.note("sub", s.at(b), 14, midi("C", 1), 0.22, 0.0, 0.1)
    for i, b in enumerate(range(25, 29)):
        s.hit("heartbeat", s.at(b), 0.5 - i * 0.1, 0.0, 0.1)
    s.note("toll", s.at(26), 2, midi("C", 2) + 0.4, 0.4, -0.5, 0.7)
    s.note("toll", s.at(30), 2, midi("C", 2) + 0.4, 0.3, 0.5, 0.7)
    s.note("piano", s.at(28), 4, midi("C", 5), 0.2, 0.3, 0.6)
    s.note("piano", s.at(28, 2), 4, midi("Db", 5), 0.15, 0.3, 0.6)
    s.hit("boom", s.at(31), 0.45, 0.0, 0.4)
    return s


def sunday():
    """Sunday. Mass: bells, the organ chorale, the schola, and an Amen."""
    s = Song("sunday", "Sunday", 66, 4, midi("G", 3), "mixolydian", reverb=(4.0, 0.5), humanize=0.008, seed=51)
    roots = [0, 5, 4, 0, 3, 0, 6, 0]
    peal = [midi("G", 5), midi("A", 5), midi("B", 5), midi("D", 6), midi("E", 6)]

    def bells(bar0, nbars, per_bar=6, vel=0.3):
        for b in range(bar0, bar0 + nbars):
            for k in range(per_bar):
                s.note("bell", s.at(b, k * 4 / per_bar), 1, peal[int(s.rng.integers(0, 5))], vel,
                       float(s.rng.uniform(-0.8, 0.8)), 0.6)

    bells(0, 4)
    s.note("toll", s.at(0), 2, midi("G", 2), 0.5)
    s.note("organ", s.at(0), 16, midi("G", 2), 0.35, 0.0, 0.4)
    # The chorale on the organ.
    s.mel("organ", 4, HYMN, 0.48, 0, 0.1, 0.5)
    s.chords("organ", 4, roots, 0.4, -1, 0.0, 0.5)
    s.chords("organ", 4, roots, 0.26, -2, 0.0, 0.4, voicing=(0,))
    # The schola takes the theme.
    s.mel("chant_a", 12, HYMN, 0.65, 0, 0.0, 0.55)
    s.chords("organ", 12, roots, 0.32, -1, 0.0, 0.5)
    # A verse on one reciting note, like a psalm tone, over an open fifth.
    verse = ["5:3 6:1", "5:2 4:1 5:1", "5:3 4:1", "3:2 2:2", "5:3 6:1", "5:2 3:1 4:1", "2:2 3:1 2:1", "1:4"]
    s.mel("chant", 20, verse, 0.62, 0, 0.0, 0.55)
    s.chords("organ", 20, [0, 0], 0.32, -1, 0.0, 0.5, voicing=(0, 4), bars_each=4)
    # Everyone, then the Amen.
    s.mel("organ", 28, HYMN, 0.42, 1, 0.2, 0.5)
    s.mel("chant_a", 28, HYMN, 0.7, 0, -0.05, 0.55)
    s.mel("chant_u", 28, HYMN, 0.45, 0, -0.2, 0.55, shift=-4)
    s.chords("organ", 28, roots, 0.45, -1, 0.0, 0.5)
    s.chords("organ", 28, roots, 0.28, -2, 0.0, 0.4, voicing=(0,))
    bells(28, 8, 2, 0.2)
    s.mel("chant_a", 36, ["4:4", "1:4"], 0.65, 0, 0.0, 0.6)
    s.chords("organ", 36, [3, 0], 0.45, -1, 0.0, 0.6, voicing=(0, 2, 4, 7))
    bells(38, 2, 6, 0.3)
    s.note("toll", s.at(38), 2, midi("G", 2), 0.5)
    return s


def requiem():
    """Requiem. The sting when a life ends: the theme's answer, falling, and a bell."""
    s = Song("requiem", "Requiem", 50, 4, midi("D", 3), "aeolian", reverb=(4.5, 0.65), humanize=0.006, seed=61)
    s.note("toll", s.at(0), 2, midi("D", 2), 0.6)
    s.mel("chant_u", 0, ["5:1 4:1 3:1 2:1", "1:4", "r:4"], 0.6, 0, 0.0, 0.6)
    s.chords("organ", 1, [0, 0], 0.35, -1, 0.0, 0.6, voicing=(0, 2, 4))
    s.note("toll", s.at(2), 2, midi("D", 2), 0.45)
    return s


PIECES = {f.__name__: f for f in (menu, night_shift, overcast, outside, sunday, requiem)}


def main(names):
    for name in names or list(PIECES):
        song = PIECES[name]()
        L, R = song.write(OUT)
        m = measure(L, R)
        print(f"{name:12s} {song.title:20s} {m['seconds']:6.1f} s  rms {m['rms_db']:6.1f} dB  peak {m['peak_db']:5.1f} dB")
        print("   every 10 s:", " ".join(f"{c:.0f}" for c in m["curve"]))


if __name__ == "__main__":
    main(sys.argv[1:])
