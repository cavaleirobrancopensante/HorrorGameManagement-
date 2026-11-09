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
  F for the torch, Esc to pause.
- Phone: left thumb moves, drag on the right to look, buttons for Use, Torch and Pause.

## Tests

`godot --headless --path . -s tests/run_tests.gd`
