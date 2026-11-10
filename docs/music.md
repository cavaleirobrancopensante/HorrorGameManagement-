# Daily Bread's music

The music is composed in code, the way Holdfast's is: every piece is written as notes in
`tools/music/compose.py`, played by instruments synthesised in `tools/music/instruments.py`, and
rendered by `tools/music/score.py`.

Render everything with `python3 tools/music/compose.py`, or one piece with
`python3 tools/music/compose.py night_shift`. The files go to `assets/music/<name>.ogg`.
Each render prints the piece's length, loudness, peak and a loudness reading every ten seconds.

## The sound of the game

Three worlds meet in the trailer, and each has its own sound.

**The Church.** A pipe organ, a small schola of men chanting, a tolling bell and a peal of bells, a
harmonium. Church modes: dorian, mixolydian. Breathing, human timing.

**The State.** Cold synthesiser pads, a sub drone you feel more than hear, the Civic chime, radio
static. The chime always plays dead on the beat, like a machine.

**The Adversary.** Whispers that never become words, a heartbeat, metal dragged on metal, deep booms,
sounds played backwards, low brass, dark strings. Locrian and the tritone. Loose, unsteady timing.

**Home**, between them: an old upright piano, a little out of tune key by key, and rain on a tin roof.

There are no drum kits, no electric guitars and no heroic fanfares. The horror stays quiet most of
the time, and silence is part of the score: in the trailer, music comes in pieces with half a minute
to a minute and a quarter of only the trailer's hum between them.

## The three motifs

**Panem**, the Daily Bread theme: grace and home. It rises a step and then to the fourth, and sighs
back down by steps to where it began: 1 2 4, 3 2 1. Its answer falls from the fifth: 5 4 3 2, 1.
It is in every piece except where the Adversary has taken over, and there it comes back wrong.

**Civic**, the State's chime: three bright notes falling down a major chord, 5 3 1. Friendly and
empty. It is heard from radios across the street, through static.

**Whisper**, the Adversary: the home note, the half step above it, the home note, then the tritone.
1 2- 1 5-.

## The pieces

### Give Us This Day (menu)

The main menu. D dorian, 60 beats a minute, about 2:40, looping.
A bell tolls over a cold open fifth from the pads and a sub drone. The schola sings Panem alone.
The organ comes in under it, and a second line sings a fifth below, like the old organum.
Then the dark comes up from below: a tritone in tremolo strings, the Whisper in the low brass,
whispers, a reversed swell. The light returns: everyone sings the theme, the organ doubles it, bells
peal. Amen on an open fifth, and the bell.

### Night Shift (night_shift)

Night in the trailer. A aeolian, 70, about 3:15.
Rain on the roof and a cold pad. The old piano plays broken chords and Panem, sparely.
A radio across the street plays the Civic chime through static. In the middle a harmonium breathes
in and the tune opens up, with faint strings. Late, the tune comes back in pieces and never quite
gets home.

### Overcast (overcast)

A grey working day. G dorian, 84, about 2:30.
A harmonium and the piano play a walking tune made from Panem's shape, then a brighter second tune.
The radio cuts in with the Civic chime, twice, over a cold pad with a rubbing half step, and the
tune stops to listen. It comes back colder (aeolian: its sixth falls a half step), then warms again.

### Something Outside (outside)

Dread, for nights when the soul leans toward sin or stress runs high. C locrian, 54, about 2:30,
with loose, unsteady timing.
A sub drone and a high rubbing half step. Scrapes outside. A heartbeat. The Whisper rises in the
strings, and the piano plays Panem high and wrong. Then it comes closer: a cluster in the tremolo
strings, the Whisper in the brass, booms, the heart racing, a reversed swell, and then nothing at all
for one bar but a single voice, close. After it the heart slows, a bell tolls out of tune far away,
and the piano rubs two notes a half step apart.

### Sunday (sunday)

Sunday daytime. G mixolydian, 66, about 2:30.
A peal of bells. The organ plays Panem as a chorale, then the schola sings it. A verse on one
reciting note, like a psalm tone, over an open fifth. Everyone together, bells again, and an Amen
(the plagal cadence, IV to I).

### Requiem (requiem)

The sting when a life ends, about 20 seconds. D aeolian, 50.
A bell, Panem's answer falling in the low voices, a minor chord on the organ, the bell again.

## When each piece plays

`scripts/autoload/sound.gd` plays the music; `TrailerGame.choose_piece` picks it.

- Main menu: Give Us This Day, looping.
- In the trailer, after 8 seconds of quiet and then 30 to 75 seconds of quiet between pieces:
  - Sunday in daylight: Sunday.
  - Daylight: Overcast.
  - Night: Night Shift or Something Outside. The chance of Something Outside starts at 25%, grows
    with the soul's lean toward the demonic and with stress, and halves straight after it has played.
- Death: the Requiem.
- The trailer's hum plays under everything in the trailer as ambience, on the sound effects volume.

## How it was checked

The pieces cannot be listened to while they are made, so each one is measured.

- Loudness every ten seconds follows the plan: the menu theme dips where the dark comes up (about
  80 to 100 seconds) and peaks when the light returns; Night Shift swells in the middle and thins out;
  Something Outside builds to its loudest just before the cut; Sunday dips for the verse.
- In Something Outside, the bar after the climax holds only the close whisper.
- Peaks stay below -1.9 dBFS; nothing clips. Whole pieces sit between about -18 and -19.5 dB RMS.
- Balance: a phone speaker plays almost nothing below 120 Hz, so the low end is kept in check (about
  11 to 13% of the energy in Night Shift, Overcast and Sunday; about 40% in the menu theme and in
  Something Outside, whose heartbeat and booms also have a body around 130 to 240 Hz that phones can play).
- Every melody bar must fill the meter exactly; a wrong bar stops the render.
- `tests/run_tests.gd` checks that every piece the game asks for exists.
