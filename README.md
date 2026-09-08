# Lightcycles

![LightCycles game won](screenshots/game_won.png "Game won")

A 3D multiplayer Tron-style lightcycle racing game for [Luanti](https://www.luanti.org/)
(formerly Minetest). Ride a lightcycle around a glowing arena, leaving a
solid trail (jetwall) behind you as you go — hit any obstacle, including
your own trail, anyone else's, or the arena boundary, and you're
eliminated (derezzed). 

Brake or pick up a boost powerup to charge your
boost bar for extra speed; collect shield powerups to break through a
trail wall instead of crashing into it, and ammo powerups to fire a laser
bolt that derezzes trails or opponents.

This is a full standalone **game**, not a mod you add to something else — just install it and play.

## Installing

1. Copy this whole folder into Luanti's `games/` directory (rename it to
   whatever you like — the folder name becomes the internal game id):
   - **Windows**: `%APPDATA%\Luanti\games\lightcycles\` (or `...\.minetest\games\...`
     for older Minetest installs)
   - **Linux**: `~/.minetest/games/lightcycles/` (or `~/.luanti/games/lightcycles/`)
   - **macOS**: `~/Library/Application Support/minetest/games/lightcycles/`
   - **Dedicated server**: `<server install dir>/games/lightcycles/`
   - You can also find the folder by starting Luanti, the clicking on "Open User Data Directory" in the "About" panel.
2. Launch Luanti, go to **Start Game**, and pick **LightCycles** as the game
   when creating a new world.
3. Create the world (any name/seed — the game creates the default map) and play.


## Playing

Once you're in the world, everyone gets a lobby panel automatically —
press **E** any time you're not actively racing to bring it back up if
you've closed it. From there (or via chat commands, below) you can join
the waiting roster and start a match once there are enough players (an
admin can start solo, for testing).

The very first time anyone starts a match on a fresh world, the arena is
built automatically — this can take a moment the first time, then it's
instant.

### Controls

| Key | Effect |
|---|---|
| **A / D** | Snap-turn 90° left/right — your view snaps with it |
| **W** | Boost: extra speed while your boost bar has charge |
| **S** | Brake: reduces speed, fills your boost bar while held |
| **Shift** | Quick-look: peek directly behind you while held |
| **Space** or **left-click** | Fire a shot (requires ammo) |
| **E** | Open the lobby menu |

You're always moving forward — there's no key to stop. Run into any wall
(yours, someone else's, or the arena boundary) and you're derezzed.

### Scoring

Every racer scores based on where they finished, not just the winner:

| Placement | Points |
|---|---|
| 1st | 25 |
| 2nd | 18 |
| 3rd | 15 |
| 4th | 12 |
| 5th | 10 |
| 6th | 8 |
| 7th | 6 |
| 8th | 4 |

A round with no survivors doesn't award 1st place to anyone, since nobody
actually won. Racers eliminated simultaneously (e.g. a head-on collision)
share the same placement, and the next rank down is left vacant rather
than shifting up to fill the gap.

On top of placement, collecting a point powerup adds 3 points, and
eliminating an opponent with a shot adds 5 — both on top of whatever
you eventually place.

Scores reset each session — either when a second player joins after
someone's been playing solo, or after a set number of matches (5 by
default, admin-configurable), at which point whoever has the most points
is declared the overall winner and everyone starts fresh. A live
"Race: N/M" counter (with a running clock) is always visible, and while a
race is actually in progress it's joined by a live standings table
showing everyone's current rank, this race's running score, and their
overall score — sorted by whoever's still alive first, then by points.
Once a race ends, that same table shows the final result until the next
one starts.

### Score table

The score table shows each racer's name, rank in the current race, race score (including awarded points), and overall game score: 
- Name : Player name.
- RR : Race Rank - the rank in the current race.
- RS : Race Score - points earned in the current race. Race Rank points are awarded at the end of the race.
- GS : Game Score - sum of all Race Scores.


### Powerups

Four kinds may appear on a given map, depending on how it's set up (an
admin can toggle each on/off from the lobby panel):

- **Point powerup** — placed as part of the level itself, worth bonus
  points on pickup (3 by default). Doesn't respawn until the next match.
- **Boost powerup** — spawns at a random spot during a match and vanishes
  if not grabbed in time; instantly refills your boost bar.
- **Shield powerup** — lets you break straight through the next trail
  wall you hit, instead of crashing into it, consuming one charge.
- **Ammo powerup** — grants a few shots (2 by default) for your laser.

### Chat commands

Everyone:

- **`/lc`** or **`/lc menu`** — opens the lobby panel
- **`/lc join`** — join the lobby
- **`/lc leave`** — leave the lobby
- **`/lc start`** — start a match
- **`/lc score`** — shows your current score in chat
- **`/lc help`** — opens the in-game help screen

Admin-only:

- **`/lcspawns`** — lists every spawn point on the current map
- **`/lcspawns <1-8>`** — teleports you to that exact spawn point, facing
  the way that racer would
- **`/lcpause`** — pauses match movement and grants yourself free-look
  and free-move (e.g. to line up a screenshot); run it again to resume.
  The match clock keeps running while paused.
- **`/lc show [score|names|race|boost|all]`** — shows the scoreboard,
  player names above cycles, the race counter, the boost bar, or
  everything (the default)
- **`/lc hide [score|names|race|boost|all]`** — hides the same

## Building custom maps

Admins can build custom arena layouts using an in-game "build mode."
Click **Enter Build Mode** in the lobby panel to get fly/noclip/give
privileges and a set of tools for editing the arena:

- **Disc** — a fast-digging tool.
- **Wall** — the ground and boundary block; right-click to place.
- **Point-powerup spawner** — place one to spawn a point powerup above it
  each match.
- **8 numbered player-spawn markers** — place these to define exactly
  where (and which direction) each racer starts.

Place spawner and player-spawn blocks at ground level, the same height as
the wall blocks — the powerup or player itself spawns just above the
marker. A player spawns facing whichever direction you were facing when
you placed their marker. Boost, shield, and ammo powerups don't need
spawners at all — they appear at random spots on their own.

Once you're happy with a layout, bring the lobby panel back up (**E**)
and press **Save Map** to save it under a new name — this captures the
current arena as a `.mts` schematic in the world folder, and it
immediately becomes selectable from the map dropdown.

See [`README-DEV.md`](README-DEV.md) for the full technical guide
(architecture, admin tooling reference, and contribution notes).

## Screenshots

![LightCycles head to head](screenshots/head_to_head.png "Head to Head")

![LightCycles shield breaking trail](screenshots/shield_breaking_trail.png "Shield breaking trail")

![LightCycles build mode](screenshots/build_mode_.png "Build mode")

![LightCycles map top](screenshots/map_top.png "Map top")

![LightCycles admin menu](screenshots/menu_admin.png "Admin menu")


## Credits & License

- **Code**: LGPL-2.1-or-later — see [`LICENSE`](LICENSE).
- Built by Xlvisuals, with code architecture, implementation, and some
  placeholder art developed in collaboration with Claude (Anthropic).
