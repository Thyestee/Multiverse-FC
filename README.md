# Multiverse FC

An incremental football (soccer) manager made with Godot 4.7.

You take over a club in the Sunday League. You have to become the best team in the multiverse by
winning the Multiverse Premier, eleven leagues up. The run ends if you go bankrupt or 100 years
pass first. Every run that ends, won, lost or abandoned, earns **shards** and an **echo**, and
those make every later club stronger.

## How a run works

- **Time**: a season is 18 weeks: 14 league games, a three-round cup, and a quiet pre-season week.
  At 1x speed a week takes 3 seconds. Space pauses, and keys 1 to 5 set the speed.
- **Leagues**: eight clubs per league, playing each other home and away. The top two go up and
  the bottom two go down. Every league up has stronger rivals and more money, and rival clubs get a
  little stronger every year.
- **Squad**: 18 players at most. The best fit players start in a 4-3-3. Young players grow towards
  their potential, and players over 30 decline and eventually retire. Wages are fixed when a player signs.
- **Transfers**: new players arrive each season and in week 9, some of them from the league above.
  You can pay to scout for more.
- **Training**: six drills, each with a level and a progress bar. Active drills gain experience every
  week and level up permanently, and higher levels cost more per week. Slots are limited, and an
  intensive session buys half a level at once.
- **Facilities**: stadium, training ground, coaching staff, club shop, marketing, youth academy
  and medical centre. Each upgrade costs a one-off fee plus weekly upkeep.
- **Money**:
  - Income comes from tickets (you set the price), sponsors (better with good form), TV rights,
    the club shop, match bonuses, prize money and player sales.
  - Costs are wages, training, upkeep, transfers and loan interest.
  - Six weeks in a row below $0 means bankruptcy.

## Between runs

- **Shards** depend on the highest league reached, trophies and seasons played. A win pays a lot more.
- **Nexus upgrades** are bought with shards and last forever: more starting money, faster training,
  more income, a stronger starting squad, cheaper wages, extra training slots, starting a league
  higher, 16x speed, and more.
- **Echoes**: at the end of a run you pick one of three small permanent boosts (two picks after a win).
  The same echo can be picked again, and its boost adds up.

## Playing with the launcher

Download `Multiverse-FC-Launcher.exe` from the latest
[release](https://github.com/Thyestee/Multiverse-FC/releases/latest), put it in its own folder and
run it. It installs the game in a `game` folder next to itself, checks GitHub for a newer version
every time it opens, and starts the game with **Play**. Without internet it still starts the
installed version. Saves live in the game's user folder (`%APPDATA%\Godot\app_userdata\Multiverse FC`),
so updates never touch them.

## Publishing a new version

Push a tag that starts with `v`:

```bash
git tag v0.2.0
```

```bash
git push origin v0.2.0
```

The `Release` workflow checks the save round trip, exports the game and the launcher with Godot
4.7.2, and publishes `Multiverse-FC-windows.zip` and `Multiverse-FC-Launcher.exe` as a GitHub
release, using `.github/release-notes.md` as its notes. Launchers pick it up the next time they
open. To build locally, run `tools/build.sh v0.2.0` with `GODOT` set to the Godot executable; the
output goes to `build/`.

## Project layout

- `scripts/data.gd`: every table and formula (leagues, training, facilities, upgrades, echoes, names)
- `scripts/run_state.gd`: one run's simulation: weeks, matches, money, players, saving. It uses no nodes.
- `scripts/meta.gd`: shards, upgrades and echoes kept between runs
- `scripts/game.gd`: autoload that ticks time, saves to `user://`, and connects the UI to the run
- `scripts/ui/`: the screens, all built in code (`main.gd` is the root)
- `tools/sim.gd`: balance check that plays runs with a simple automatic manager
- `tools/test_save.gd`: checks that a saved run reloads and plays on identically
- `tools/build.sh`: exports the game zip and the launcher
- `launcher/`: the launcher, a separate small Godot project

```bash
godot --headless --path . -s tools/sim.gd -- 8 7
```

```bash
godot --headless --path . -s tools/test_save.gd
```

The sim's arguments are the number of runs and a seed; add `v` for a season-by-season money breakdown.
With the current numbers, the automatic manager's first run goes bankrupt in the Cosmic League
around year 45, and later runs win in roughly 17 to 32 years.

Test flags for the game itself (after `--`): `--nosave` (leave the real save alone), `--new=Name`,
`--weeks=N`, `--speed=N`, `--tab=N`, `--abandon`, `--claim`, `--screenshot=file.png`.
