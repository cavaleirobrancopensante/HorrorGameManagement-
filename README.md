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

## The kitchen

- Take meat from the drawers under the grill, rolls from the bread bin, cans from the cooler.
- Put anything down anywhere. Meat cooks wherever it sits on the grill. Put meat and a roll together where they lie, then add sauce: look at a bottle with the food in your hand.
- Food belongs on the grill, the serving counter and the prep board. Elsewhere, customers mind; on the floor or a filthy counter, they refuse it. Wipe counters with cleaning spray. The bin is at the end of the serving counter.
- Customers show a face and a mood bar. Happier customers tip more. If you are out of something, tell them and they order something else.
- Everything runs out: meat, rolls, cans, sauce, spray. Deliveries land at the start of the shift after next. Upgrades (street TV, pro griddle, large bottles, neon sign) are on the computer.

## The soul

- **Temptations** come during the day, one per shift at most, more often when you are stressed. Giving in helps you and eases stress, but goes on your record and pushes the horror toward the demonic. Resisting costs stress, more for the sins you struggle with.
- **St. Brigid's**: walk there from the sign at the end of the church street (open morning to evening). Hear Mass from the pews, then receive Communion or stay in the pew. Pray at the rail, light a candle, talk to Father Columba.
- **Confession** every evening and on Saturday afternoon. A full confession restores the state of grace; holding back a grave sin makes it a bad confession.
- Faithfulness draws the state: a watcher in the church, fines on the way home.

## The horror

A director in `scripts/core/horror.gd` rolls every 20 game minutes. The soul's lean picks the side (sin: the demonic; faith: the state; in between, both); the lean, stress and night set the strength. Events need a minimum strength, some only at night, by day, near the mirror or with customers at the hatch, and each has a cooldown. The church is safe. `scripts/world/horror_director.gd` stages them: shapes seen only in the mirror (render layer 32) or only on the cameras, blackouts, the jumpscare face, the drone, the inspector and the raid.

## Patch notes

The version is on the main menu; press it for every patch's changes. They live in `scripts/core/changelog.gd`, and its first entry must match `config/version` in `project.godot`.

## Tests

`godot --headless --path . -s tests/run_tests.gd`
