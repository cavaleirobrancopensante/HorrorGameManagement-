# Daily Bread (working title)

A Catholic food-stand game of virtue under persecution for phones, computers and the browser, made in
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

## Virtue

The game is built around virtue, as Aquinas builds the moral life: on habit (`scripts/core/virtue.gd`).

- **Six virtues**: Patience, Honesty (justice), Charity, Fortitude, Temperance, Prudence. Each act adds a little, less the further the habit has come; a failure takes a little away and leaves a regret. Each temperament has one that comes easily; in creation you choose one or two **struggles**, which start at nothing and grow slowly at first. Struggles give no bonus.
- **What virtue gives** is ease, never power: patience softens insults, honesty builds trust (more regulars, better tips), charity makes gifts do more for the parish, fortitude steadies fear, temperance slows the needs, prudence brings warnings before raids, gangs and drones.
- **Moments** (`scripts/core/moments.gd`) replace temptations: a choice between two goods, or between a hard good and an easy failure. The tests check that a failure never gains money, stock, trust or parish, never eases a need, always leaves a regret, and that any moment with a failure keeps the faith out of it.
- **No grave-sin buttons, no state of grace, no reward for wrongdoing.**

## The parish and the sacraments

- **St. Brigid's** (`scripts/core/parish.gd`): its strength is the life of the community. Mass, the poor box, standing by the priest build it; the persecution wears it down. A weak parish under a watchful state can lose Father Columba for weeks; at nothing, it is closed.
- **Mass, Communion, confession** are quiet scenes with no meters or buffs (`scripts/core/soul.gd`). Confession is mercy: the regrets you carry are laid down, with no penalty and no counter.

## A life

`scripts/core/life.gd`: you age from the Age you chose (24, 38 or 56). From 62 a last illness may begin each day, more likely each year; send for the priest and you die with the sacraments. The ending tells how you died, whether the parish outlives you, and the virtues you built. At bed you can let a week, a month or a season pass in a summary. The pause menu shows **Your life**.

## The horror

The horror is human. A director in `scripts/core/horror.gd` rolls every 20 game minutes. The state's **attention** (raised by Mass, confession, helping the priest; lowered by time and by paying the compliance contribution), stress, the years and the night set the strength. Events: drones, someone at your bins seen only on the cameras, surcharges, the knock at night, seized feeds, inspectors, power cuts, a watcher under the lamp, the informant, and raids (a warning in time saves the candles and most stock). The church is safe. Nothing supernatural is shown.

### Pacing

Small events build dread; a big one (power cut, raid) needs at least two since the last, then a calm of random length follows. Someone the state ignores, calm, sees nothing big.

### The night

Close the window shutter before you sleep. Burglars come more for cash, mostly give up at a closed shutter, and can be fought (Endurance, Vigilance) or let be.

## Combat

R, the mouse wheel or the Arm button cycles bat, slingshot and empty hands; with a weapon out, use attacks (doors and shutters still work when you stand right at them). The slingshot uses steel shot from the shop; Marksmanship sets its spread and damage, stress widens it. Endurance adds to the bat and softens hits. Bandages from the first aid box in the bathroom heal.

Gangs come some nights (thugs bash the door; shooters fire through open windows and the hatch). Civic drones hunt the faithful through any opening, and ram the shutter or door when everything is shut. Closing up takes range away from both sides and forces a fight at the door. Barricade it with the planks on the freezer lid for three times the bashing. A compliance contribution on the computer's Standing tab keeps the state away for three days. Rules: `scripts/core/combat.gd`; enemies: `scripts/world/enemy.gd`; weapons: `scripts/world/fighter.gd`.

## People

Everyone is built from Quaternius's CC0 Ultimate Modular Men and Women packs (`assets/people/`, see its LICENSE.md). Each outfit has Head, Body, Legs and Feet on one skeleton, so `scripts/world/people.gd` mixes parts across outfits, recolours skin, hair and clothes, and adds code-made extras (cassock, headscarf, hood, face cloth, hats, apron, props). `scripts/world/person_rig.gd` animates them in code: it finds each joint's turning axes itself, then drives walking, paying, eating, holding, swinging, aiming, bashing, flinching and falling.

## Test log

`GameLog` (an autoload) records events marked good or bad, slow frames with what happened just before them, lighting changes and engine errors (through an `OS` logger). F3 or the pause menu opens `LogPanel`; Copy log / Download log exports it, and each session is written to `user://logs/` (last five kept). `TrailerGame._warm_up` draws every place once behind the opening fade so shaders are ready before play.

## Help and tooltips

Every menu and creation control has a tooltip (`UiKit.tip`), also shown in a help line at the bottom for touch screens. In the game, holding the crosshair on something for about two thirds of a second shows what it is; the texts live in `scripts/core/tips.gd`. Character creation picks face, top, trousers and shoes from the outfit parts (`GameData.BODY_PARTS`) and shows the result in 3D (`LookPreview`). The wardrobe at home (`WardrobePanel`) changes clothes and apron later.

The apron (`People._apron`) is draped over the body's own surface, skinned on the CPU, and narrowed to stay clear of the arms. Checked against every pose and action: no arm passes through it.

## Picture

Settings has Sharp, Crisp (default) and Retro, for the size of the game's pixels. Textures are generated in code at four times their old detail with grime and relief maps.

## Patch notes

The version is on the main menu; press it for every patch's changes. They live in `scripts/core/changelog.gd`, and its first entry must match `config/version` in `project.godot`.

## Tests

`godot --headless --path . -s tests/run_tests.gd`
