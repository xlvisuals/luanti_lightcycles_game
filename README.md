# Lightcycles

![LightCycles game won](screenshots/game_won.png "Game won")

A 3D multiplayer Tron-style lightcycle racing game for [Luanti](https://www.luanti.org/)
(formerly Minetest). Ride a lightcycle around a glowing arena, leaving a
solid trail (jetwall) behind you as you go — hit any obstacle, including
your own trail, anyone else's, or the arena boundary, and you're
eliminated (derezzed). 

Brake or pick up a boost powerup to charge your
boost bar for extra speed; collect shield powerups to break through a
trail wall instead of crashing into it; laser powerups to fire a bolt
that derezzes trails or opponents; and rocket powerups for a slower but
far more destructive shot that blows out a 3x3 area of trails/cycles on
impact.

This is a full standalone **game**, not a mod you add to something else — just install it and play.

## Installing

1. Install [Luanti](https://www.luanti.org/).
2. Run the latest installer for your platform from [Releases](https://github.com/xlvisuals/luanti_lightcycles_game/releases/latest).

Alternatively, you can simply download a .zip of this and copy it's content into a `lightcycles` directory in Luanti's `games/` directory:
   - **Windows**: `%APPDATA%\Minetest\games\lightcycles\`
   - **Linux**: `~/.minetest/games/lightcycles/`
   - **macOS**: `~/Library/Application Support/minetest/games/lightcycles/`
   - **Dedicated server**: `<server install dir>/games/lightcycles/`
   - You can also find the folder by starting Luanti, then clicking on "Open User Data Directory" in the "About" panel.

## Running

1. Launch Luanti
2. Go to **Start Game**, and pick **LightCycles** as the game
3. When running for the first time, click **New** to create a world (any name/seed — the game creates the default map)
4. Click **Play Game**
   - If you want to host a server, check **Host Server** on below `Start Game`


## Playing

Once you're in the world, everyone gets a lobby panel automatically —
press **E** any time you're not actively racing to bring it back up if
you've closed it. From there (or via chat commands, below) you can join
the waiting roster and start a race once there are enough players (an
admin can start solo, for testing).

The very first time anyone starts a race on a fresh world, the arena is
built automatically — this can take a moment the first time, then it's
instant.

### Controls

| Key | Effect |
|---|---|
| **A / D** | Snap-turn 90° left/right — your view snaps with it |
| **W** | Boost: extra speed while your boost bar has charge |
| **S** | Brake: reduces speed, fills your boost bar while held |
| **Shift** | Quick-look: peek directly behind you while held |
| **Space** or **left-click** | Fire a laser shot (requires laser ammo) |
| **E** (Aux key) or **right-click** | Fire a rocket (requires rocket ammo). Outside of a race, instead opens the lobby menu |

You're always moving forward — there's no key to stop. Run into any wall
(yours, someone else's, or the arena boundary) and you're derezzed.

### Scoring

Every racer scores based on how long they lasted, not just the winner. The first player 
to be eliminated places last, the last player racing places first.

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

A race with no survivors doesn't award 1st place to anyone, since nobody
actually won. Racers eliminated simultaneously (e.g. a head-on collision)
share the same placement, and the next rank down is left vacant rather
than shifting up to fill the gap.

On top of placement, collecting a point powerup adds 3 points, and
eliminating an opponent with a laser or rocket shot adds 5 — both on top
of whatever points you get for your place at the end of a race.

Scores reset each game — either when a second player joins after
someone's been playing solo, or after a set number of races (5 by
default, admin-configurable), at which point whoever has the most points
is declared the overall winner and everyone starts fresh. 

A live "Race: N/M" counter (with a running clock) is always visible, and while a
race is in progress it's joined by a live standings table showing everyone's 
rank in the current race, this race's running score, and their overall game score 
— sorted by whoever's still alive first, then by points.
That same table shows the final result at the end of a race or game until the next
one starts.

When one player is playing solo (no other players, no bots) the game ends when the last point powerup was collected - it's a race against time to collect them as fast as possible.

### Score table

The score table shows each racer's name, rank in the current race, race score (including awarded points), and overall game score: 
- Name : Player name.
- RR : Race Rank - the rank in the current race.
- RS : Race Score - points earned in the current race. Race Rank points are awarded at the end of the race.
- GS : Game Score - sum of all Race Scores.

### Powerups

Five kinds may appear on a given map, depending on how it's set up (an
admin can toggle each on/off from the lobby panel):

- **Point powerup** — placed as part of the level itself, worth bonus
  points on pickup (3 by default). Doesn't respawn until the next race.
- **Boost powerup** — spawns at a random spot during a race and vanishes
  if not grabbed in time; instantly refills your boost bar.
- **Shield powerup** — lets you break straight through the next trail
  wall you hit, instead of crashing into it, consuming one charge.
- **Laser powerup** — grants a few shots (2 by default). A laser bolt is
  fast and precise, destroying a single trail node or eliminating a
  single opponent on a direct hit.
- **Rocket powerup** — grants a rocket (1 by default). A rocket is
  slower than a laser bolt, but on impact it destroys a 3x3 area of trail
  walls (never the boundary or floor) and eliminates every racer caught
  standing in that area, not just the one it directly hit.

### Bots

Admins can add bots to singleplayer and multiplayer games. There are three bot behaviors: passive, opportunistic, and aggressive.

- **Passive** - Go straight until obstacle then turn one way. Never seeks a powerup. 
- **Opportunistic** - Commits to the nearest powerup within a limited range (default: 10 nodes) the instant one comes into range, staying committed until it's reached, gone, or blocked.
- **Aggresive** - Commits to the nearest powerup the instant one is spawned, staying committed until it's reached, gone, or blocked.

All behaviors share the same base obstacle avoidance: look ahead along the current heading; if blocked, turn toward whichever side is clear; if both sides are safe, weigh toward whichever has more open room further out.

Bots use shields automatically and use any boost charge they have, but never brake to manually charge the boost bar. Bots do not avoid laser bolts or rockets shot at them.

Bots shoot under two independent conditions:
- another cycle (player or bot) lined up dead ahead within range (an offensive opportunity to take down an opponent), or
- a trail wall ahead with a hazard close on both the left and right (defensive opportunity to clear an escape route).

When either condition is met, a bot fires its laser if it has any ammo left, and only reaches for a rocket once it's completely out of laser shots.

The admin can choose the number of bots in a game and their behavior. Choosing "random" will assign each bot a random behavior from one of the three for the duration of the game. A bot's name shows their assigned behavior in the name: - `(p)` for passive, `(o)` for opportunistic, and `(a)` for aggressive. 
 

### Chat commands

Everyone:

- **`/lc`** or **`/lc menu`** — opens the lobby panel
- **`/lc join`** — join the lobby
- **`/lc leave`** — leave the lobby
- **`/lc start`** — start a race
- **`/lc score`** — shows your current score in chat
- **`/lc help`** — opens the in-game help screen

Admin-only:

- **`/lcspawns`** — lists every spawn point on the current map
- **`/lcspawns <1-8>`** — teleports you to that exact spawn point, facing
  the way that racer would
- **`/lcpause`** — pauses race movement and grants yourself free-look
  and free-move (e.g. to line up a screenshot); run it again to resume.
  The clock keeps running while movement is paused.
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
  each race.
- **8 numbered player-spawn markers** — place these to define exactly
  where (and which direction) each racer starts.

Place spawner and player-spawn blocks at ground level, the same height as
the wall blocks — the powerup or player itself spawns just above the
marker. A player spawns facing whichever direction you were facing when
you placed their marker. Boost, shield, laser, and rocket powerups don't
need spawners at all — they appear at random spots on their own.

Use the `giveme` command to refill any blocks you run out of or lost:
- `/giveme lightcycles:boundary 99`
- `/giveme lightcycles:powerup_point_spawner 99`
- `/giveme lightcycles:spawnpad_1 1`
- `/giveme lightcycles:spawnpad_2 1`
- `/giveme lightcycles:spawnpad_3 1`
- `/giveme lightcycles:spawnpad_4 1`
- `/giveme lightcycles:spawnpad_5 1`
- `/giveme lightcycles:spawnpad_6 1`
- `/giveme lightcycles:spawnpad_7 1`
- `/giveme lightcycles:spawnpad_8 1`
- `/giveme lightcycles:build_pick 1`
  
You might have to check your inventory (**I**) in case the blocks didn't land in a hotbar slot. 
Make sure to only have only one of each spawnpad and that they point in the desired direction.

Once you're happy with a layout, bring the lobby panel back up (**E**)
and press **Save Map** to save it under a new name — this captures the
current arena as a `.mts` schematic in the world folder, and it
immediately becomes selectable from the map dropdown.


## Screenshots

![LightCycles head to head](screenshots/head_to_head.png "Head to Head")

![LightCycles shield breaking trail](screenshots/shield_breaking_trail.png "Shield breaking trail")

![LightCycles build mode](screenshots/build_mode.png "Build mode")

![LightCycles map top](screenshots/map_top.png "Map top")

![LightCycles admin menu](screenshots/menu_admin.png "Admin menu")


## Credits & License

- **Code**: LGPL-2.1-or-later — see [`LICENSE`](LICENSE).
- Built by Xlvisuals, with code architecture, implementation, and some
  placeholder art developed in collaboration with Claude (Anthropic).
