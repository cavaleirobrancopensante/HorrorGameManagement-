# Daily Bread (working title)

A Catholic horror food-stand game for phones, computers and the browser, made in
Godot 4.7.2.

Open `project.godot` in Godot 4.7.2 and press Play. The run scene is the main menu.

## Play in the browser

Every push to `main` builds the web version and publishes it to GitHub Pages:
https://cavaleirobrancopensante.github.io/HorrorGameManagement-/

Pages must be switched on once: repository Settings, Pages, Source: GitHub Actions.

## Controls

- Computer: WASD to move, mouse to look (click to start), E or left click to use,
  F for the torch, C to plan the day, Esc to pause.
- Phone: left thumb moves, drag on the right to look, buttons for Use, Torch, Day and Pause.

## Calendar

The game starts on Saturday 15 January 2050 at 20:00. Each day has six
four-hour shifts: morning, noon, afternoon, evening, night and the dead shift.
Play a shift freely, or spend it on work, rest, sleep, prayer or Mass from the
day planner (wall calendar, C, or the Day button). Missing Sunday Mass costs the
state of grace; the Saturday evening vigil counts.

## The soul

- **Temptations** come during the day, one per shift at most, more often when you are stressed. Giving in helps you and eases stress, but goes on your record and pushes the horror toward the demonic. Resisting costs stress, more for the sins you struggle with.
- **St. Brigid's**: walk there from the sign at the end of the church street (open morning to evening). Hear Mass from the pews, then receive Communion or stay in the pew. Pray at the rail, light a candle, talk to Father Columba.
- **Confession** every evening and on Saturday afternoon. A full confession restores the state of grace; holding back a grave sin makes it a bad confession.
- Faithfulness draws the state: a watcher in the church, fines on the way home.

## Patch notes

The version is on the main menu; press it for every patch's changes. They live in `scripts/core/changelog.gd`, and its first entry must match `config/version` in `project.godot`.

## Tests

`godot --headless --path . -s tests/run_tests.gd`
