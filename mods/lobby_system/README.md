# Lobby System

A reusable multiplayer lobby framework for Luanti games: a formspec panel,
join/leave/start flow with a countdown and a late-join window, persistent
scorekeeping, big on-screen event announcements, and join/win/lose/ambience
sounds. It handles all of that generically; your game just tells it how to
place a player when their match starts, and calls three small functions to
report what's happening (a death, a win, and "the match is fully over").

This mod has **no gameplay of its own** - it doesn't know what a "player
dying" or "winning" means for your game, it doesn't build any level/arena,
and it doesn't spawn any entities. It just manages the lobby lifecycle and
UI around whatever your game actually does. See `lightcycles` (in this same
game package) for a complete real-world example of a game built on top of it.

## Quick start

```lua
-- somewhere in your mod's init, after lobby_system is guaranteed loaded
-- (add "lobby_system" to your mod's depends in mod.conf)

lobby_system.register_game({
    title = "My Game",
    command = "mg",              -- optional; chat command name (default "lobby")
    max_players = 8,              -- optional (default 8)
    min_players = 2,              -- optional (default 2) - non-admins need this many to start
    score_to_win_game = nil,      -- optional (default nil/disabled) - see below
    countdown_seconds = 5,        -- optional (default 5)
    late_join_cutoff = 2,         -- optional (default 2)

    -- Optional: where to put a player who isn't currently racing (waiting,
    -- or back after a match). If you don't supply this, lobby_system uses
    -- a generic fallback position with gravity disabled, so it's safe even
    -- in open/empty space.
    get_idle_pos = function()
        return { x = 0, y = 10, z = 0 }, 0 -- pos, yaw
    end,

    -- Optional: where to place racer number `index` (1..max_players, in
    -- join order) when their match starts. If omitted, everyone just uses
    -- get_idle_pos() instead - fine for simple games, but you'll usually
    -- want distinct spawn points.
    get_spawn = function(index)
        return my_game.spawn_points[index].pos, my_game.spawn_points[index].yaw
    end,

    -- Optional: called once per match, right before any racer is placed
    -- (unlike on_match_start, which runs once per racer) - good for
    -- resetting a level/board to a clean state for the new match.
    on_match_prepare = function(count)
        my_game.reset_level()
    end,

    -- REQUIRED: called once per racer, both for the initial roster when a
    -- match starts and for anyone who joins during the late-join window.
    -- This is where you actually set the player up to play - spawn their
    -- character/vehicle/whatever, track your own per-player game state, etc.
    on_match_start = function(name, index, pos, yaw)
        my_game.players[name] = { index = index, alive = true, score_progress = 0 }
        local player = minetest.get_player_by_name(name)
        if player then
            player:set_pos(pos)
            -- ... whatever your game needs to actually start playing ...
        end
    end,

    -- Optional: called once per racer when lobby_system.game_over() runs -
    -- tear down whatever you set up in on_match_start (remove entities,
    -- stop sounds, clear your own per-player state) BEFORE lobby_system
    -- resets them to the generic idle state.
    on_match_end = function(name)
        my_game.players[name] = nil
    end,

    -- Optional: unlike on_match_start/on_match_end above (once PER
    -- racer), these fire once per MATCH, for every connected player, not
    -- just players - on_racing_started right as the countdown reaches 0
    -- and state.phase actually becomes "playing" (after every racer has
    -- already been placed), on_racing_ended right as game_over() resets
    -- everything back to the lobby. Useful for anything that should
    -- happen exactly once regardless of how many players there are, or
    -- that a spectator who never joined this match should still see too
    -- (lightcycles uses these for its own live in-race standings table,
    -- shown to everyone the same way the countdown text already is).
    on_racing_started = function()
        my_game.show_race_hud_for_everyone()
    end,
    on_racing_ended = function()
        my_game.hide_race_hud_for_everyone()
    end,

    -- Optional: shown when a player runs "/<command> help" - your own
    -- rules/controls/admin-tooling screen (a separate formspec you manage
    -- entirely yourself; lobby_system just routes the chat command to it).
    -- lobby_system has no help content of its own, so if you don't provide
    -- this, the command just says there's none available.
    show_help = function(name)
        minetest.show_formspec(name, "my_game:help", "formspec_version[4]size[6,3]"
            .. "label[0.4,0.5;How to play...]button_exit[2,2;2,0.8;close;Close]")
    end,

    -- Optional: handle a "/<command> <param>" your game defines that
    -- isn't one of the built-in ones (join/leave/start/score/help) -
    -- same extensibility shape as show_help above. Return true if you
    -- recognized and handled param (sending your own chat response
    -- directly, the same way the built-in subcommands do), false/nil to
    -- fall through to the generic "unknown command" usage message.
    on_extra_command = function(name, param)
        if param == "mything" then
            minetest.chat_send_player(name, "Did the thing.")
            return true
        end
        return false
    end,

    -- Optional: append your own rows to the lobby panel (e.g. an
    -- admin-only settings toggle). Return a formspec fragment string, or
    -- nil/nothing to render no extra rows for this player. Position your
    -- content starting at y=4.6 - that's clear of everything the core
    -- panel might render above it.
    extra_formspec = function(name)
        if not minetest.check_player_privs(name, { lobby_admin = true }) then return nil end
        return "button[0.4,4.6;7.7,0.8;mg_toggle_thing;Toggle Thing]"
    end,

    -- Optional: handle fields the core panel doesn't recognize (i.e. from
    -- your own extra_formspec buttons). Return true if you handled it
    -- (the panel will be refreshed for that player), false/nil otherwise.
    on_extra_fields = function(name, fields)
        if fields.mg_toggle_thing then
            my_game.thing_enabled = not my_game.thing_enabled
            return true
        end
        return false
    end,
})
```

Then, whenever your own game logic decides something has happened:

```lua
-- A player died/lost/was eliminated. Personal "you're out" sound, global
-- announcement. Doesn't end the match by itself.
lobby_system.player_died(name, name .. " was eliminated!")  -- message optional

-- Someone won: +1 score (or pass a 3rd arg for a different amount),
-- global announcement + win sound. Doesn't reset the match by itself.
lobby_system.player_won(name, name .. " wins!")

-- Nobody won (e.g. simultaneous elimination). No score awarded.
lobby_system.match_draw("Draw - nobody survived.")

-- The match is fully over - reset everyone to the lobby. Call this
-- whenever YOUR game is ready (e.g. after a short victory-screen delay);
-- lobby_system doesn't impose any timing of its own here.
lobby_system.game_over()
```

## Why three separate report functions, and why doesn't `game_over()` happen automatically?

Different games have different shapes: some might want to show a longer
victory animation before resetting, some might have deaths that don't
necessarily end the match (a battle-royale style game with many
eliminations before a winner emerges), some might end in a way that isn't a
clean "single winner" (co-op success/failure for a whole team). Keeping
these as separate, explicitly-called functions - rather than lobby_system
inferring match-end from a "death count" it doesn't understand - keeps the
framework usable for all of those shapes without needing to know anything
about your specific rules.

## Customizing event text

Four events get a chat announcement + big on-screen flash automatically -
joining/leaving the pre-match lobby, and joining/leaving an active match.
The default wording is generic; override any of them with your own plain
string (containing one `%s` for the player's name) or a function for full
control (some events pass extra context as a second argument):

```lua
lobby_system.set_joined_lobby_text("%s hopped in the queue!")
lobby_system.set_left_lobby_text("%s backed out.")

-- info = { count = <players now in the lobby>, max = <max_players> }
lobby_system.set_joined_lobby_text(function(name, info)
    return name .. " joined (" .. info.count .. "/" .. info.max .. ")"
end)

-- fires when someone joins directly into a match already counting down
-- (info = { index = <their spawn/slot index> })
lobby_system.set_joined_game_text(function(name, info)
    return name .. " jumped into the action!"
end)

-- fires on disconnect while they were an active participant in the current
-- match (this is purely an announcement - lobby_system doesn't know what a
-- mid-match disconnect should mean for your game; handle that yourself via
-- your own on_leaveplayer, e.g. treating it as an elimination)
lobby_system.set_left_game_text("%s rage-quit!")
```

## Other simple settings

```lua
lobby_system.set_countdown_seconds(10)
lobby_system.set_max_players(4)

-- Minimum players for a non-admin to start a match (default 2). An admin
-- can always start with as few as 1 player, regardless of this.
lobby_system.set_min_players(3)

-- If set, the first player to reach this many points/wins ends the whole
-- session: whoever has the most points is declared the overall winner and
-- every score resets to 0. Unset (nil, the default) means scores just
-- accumulate forever with no overall "game".
lobby_system.set_score_to_win_game(5)

-- If true, every player's score resets to 0 the moment they join - new
-- players, returning ones, and everyone after a server restart alike.
-- false (the default) keeps scores persisting across sessions/reconnects
-- (an ongoing "house leaderboard" feel).
lobby_system.set_reset_score_on_join(true)

-- Alternative/complementary way to end a session: after exactly this many
-- matches have been played, declare whoever has the most points the
-- overall winner and reset scores, same as score_to_win_game above
-- (whichever of the two triggers first wins). Also shows a "Race: N/M"
-- counter above the scoreboard the whole time it's set. nil (the default)
-- disables both the counter and this way of ending a session.
lobby_system.set_matches_per_game(5)
```

Equivalent to passing `min_players`/`max_players`/`countdown_seconds`/
`score_to_win_game`/`reset_score_on_join`/`matches_per_game` into
`register_game()`, but callable any time afterward too (e.g. from your own
admin command).

A game can append its own text to the "Race: N/M" counter too - useful for
things like showing how long the last match took:

```lua
-- Called with no arguments each time the counter is rendered; return a
-- string to show as " - <text>" after "Race: N/M", or nil/nothing to
-- append nothing this time.
lobby_system.set_match_counter_suffix(function()
    return my_game.last_match_duration and (my_game.last_match_duration .. "s") or nil
end)
```

If your game manages players that were never real connected players (bots,
for instance), the scoreboard has no way to know about them on its own -
`all_known_players()` only looks at the lobby roster, its own racer
tracking, and currently-connected players. Contribute extra names the same
way:

```lua
-- Called with no arguments each time the scoreboard is built; return an
-- array of extra names to include (or nil/an empty array for none this
-- time).
lobby_system.set_extra_known_names_fn(function()
    return my_game.get_current_bot_names()
end)
```

A game can also run logic right before the panel is actually shown to a
specific player - useful for anything that should end the moment they
bring the panel back up, however they do it (a button click elsewhere in
your own UI, the `/lobby` chat command with no arguments, or whatever a
player has that command bound to - a key of their own choosing, say):

```lua
-- Called with the player's name right before lobby_system.gui.show
-- actually builds and shows the panel to them.
lobby_system.set_before_show_fn(function(name)
    if my_game.is_in_some_special_mode(name) then
        my_game.exit_special_mode(name)
    end
end)
```

## Starting a new game/session vs. a new match

`lobby_system.setup_new_game()` marks the start of a genuinely new
multiplayer session, as distinct from a new **match** (a single round
within an ongoing session, driven by `register_game`'s hooks). It resets
everyone's score and the match counter, but it's deliberately its own
separately-named function precisely so more "fresh session" setup can be
added there later without tangling it up in per-match logic. Call it
yourself any time (e.g. from your own admin command), or turn on:

```lua
-- Automatically calls setup_new_game() the moment a second player joins
-- while only one was previously connected - i.e. going from a lone/solo-
-- testing player to an actual multiplayer session. false (the default)
-- leaves this entirely up to the game to trigger, if at all.
lobby_system.set_new_game_on_second_player(true)
```

A game can run its own reset logic at that same moment too - useful for
anything that's meant to stay stable for a whole session but not carry
over into the next one:

```lua
-- Called with no arguments every time setup_new_game() runs.
lobby_system.set_on_new_game_fn(function()
    my_game.randomize_something_for_this_session()
end)
```

## HUD scale and mobile/touchscreen players

```lua
-- Global multiplier for all lobby_system (and, if a game reuses it,
-- game-specific) HUD text.
lobby_system.settings.hud_scale = 1.28

-- Extra multiplier applied on top of hud_scale specifically for a detected
-- mobile/touchscreen player (e.g. 2/3 to shrink text that otherwise reads
-- too large on a phone screen held close to the eye).
lobby_system.settings.mobile_hud_scale_multiplier = 2 / 3
```

Detection (`lobby_system.is_mobile_player(name)`) is best-effort: it checks
`minetest.get_player_information(name).touch_controls` where available,
falling back to a platform-string check, and finally to "not mobile" if
neither is available. Use `lobby_system.get_hud_scale(name)` (not
`settings.hud_scale` directly) wherever you compute a HUD element's size, so
your own game's HUD scales down the same way.

## Tracking how long each player was in their last match

```lua
-- seconds (float), measured from on_match_start to whichever of
-- player_died/player_won was called for them - nil if they haven't
-- finished a match yet.
local secs = lobby_system.get_last_match_duration(name)
```

## Start confirmation

If a non-admin tries to start while the lobby isn't full and there are
other connected players who haven't joined yet, lobby_system shows them a
confirmation dialog ("N other connected players haven't joined yet - start
anyway?") instead of starting immediately - they might just be waiting on
friends who forgot to join. Admins skip this and start right away. This is
automatic; nothing to configure.

## What lobby_system handles for you

- **Roster / phase state machine**: `lobby` -> `countdown` -> `playing` ->
  `ended` -> back to `lobby`. Player join/leave, starting a match (requires
  `min_players`, default 2, unless an admin overrides it - see Privileges
  below - and shows a confirmation dialog to non-admins if the lobby isn't
  full and other connected players haven't joined), and the countdown timer
  with a configurable late-join window are all built in.
- **The formspec panel**: opens automatically when a player joins and again
  whenever a match resets; closes automatically for the players actually
  entering a match when it starts, but stays open (showing a live "Join
  Race" button) for anyone who could still use the late-join window. If a
  player closes it manually, pressing `aux1` (`E` by default) reopens it -
  but only while they're genuinely idle (not in `state.players`), so it
  won't fight a game that repurposes `aux1` for something else during an
  active match (e.g. cycling a spectator camera).
- **Persistent scoreboard**: a top-right HUD element, always visible, for
  every player who's ever scored or is currently around. "Persistent" here
  means for the current server run, not across a restart - scores are
  plain in-memory state (`lobby_system.state.scores`), the same as
  `match_number`/`lobby`/`players`/everything else `state` holds, and a
  restart deliberately wipes all of it together, consistently. Optionally,
  an overall "game" on top of individual matches: set `score_to_win_game`
  and the first player to reach that many points/wins is declared the
  overall winner and every score resets to 0 (`reset_all_scores()`, also
  callable directly for your own "reset the game" admin action).
  - `check_overall_winner()` (score_to_win_game) and
    `check_matches_per_game_winner()` (matches_per_game) both **return**
    their announcement message (or nil) rather than flashing/chatting it
    themselves. `player_won`/`match_draw`/`game_over` each call the
    relevant one as a fallback so the feature still works out of the box,
    but a game is expected to call whichever applies itself, earlier,
    and fold the result into its own match-end message (see
    `lightcycles.finish_match` for a worked example) - `flash_all` is a
    single shared HUD text element per player, not a stack, so a second,
    separately-timed `flash_all` call replaces whatever the first was
    showing rather than appearing below it, and calling this specific
    check late enough to line up with a UI transition (e.g. right before
    reopening the lobby panel) can mean it's covered by that transition
    for the entire time it would otherwise have been visible. Both are
    real bugs this project hit before switching to the return-a-message
    pattern.
  - Neither actually resets anything immediately anymore either, for a
    closely related reason - both used to call `reset_all_scores()`/
    `setup_new_game()` (which also resets `match_number` to 0) the
    instant they triggered, which meant the match counter and everyone's
    score were already showing 0 throughout the entire victory display
    and the whole lobby period afterward, well before a new session had
    actually, meaningfully begun in any way a player watching would
    recognize as one - a real, reported bug. The actual reset is now
    deferred (`pending_new_game`, an internal flag local to `lobby.lua`)
    until `lobby_system.apply_pending_new_game()` is called - which
    `lobby.start` already does on every game's behalf, immediately before
    that same function's own `match_number` increment, so a genuinely new
    session's first match still correctly becomes match 1 (reset to 0,
    then incremented right after) without a game needing to call this
    itself. Both functions also now guard against re-triggering while
    already pending - without that, since the underlying reset no longer
    happens immediately, the same triggering condition (a score past the
    threshold, or the match count reached) would otherwise still be true
    on a second call (e.g. `game_over()`'s own fallback, running well
    after the first, direct call already fired), recomputing and
    re-announcing the exact same win a second time.
  - `pending_new_game` is a plain Lua variable, not persisted anywhere -
    deliberately so. An earlier version of this deferred-reset design
    persisted scores in mod storage specifically so they'd survive a
    server restart mid-session, which then needed `pending_new_game`
    persisted too (a restart losing track of a still-owed reset was a
    real, reported bug), which then needed a *second* fallback on top of
    that (`state.match_number == 0` on its own also forcing a reset, to
    catch a restart before any threshold was ever reached at all - also a
    real, reported bug, and the one that finally prompted reconsidering
    the whole approach). Three real bugs and two rounds of restart-
    specific patches later, the actual fix was architectural, not another
    patch: stop persisting scores across restarts at all, and let a
    restart wipe them the same way it already, consistently wiped
    everything else in `state`. That single change made both patches
    - and the entire class of bug they were chasing - unnecessary at
    once, rather than fixing them one restart-shaped edge case at a time.
  - `pending_new_game` starts `true`, not `false` - the very first match
    ever played after a fresh server start is, itself, the first match of
    a new game, so `apply_pending_new_game` explicitly runs
    `setup_new_game()` for it too, same as any other new game's first
    match. Without this, that very first reset never actually happened
    through any real code path - `state.scores` simply started as an
    empty table by definition, so there was nothing visibly wrong, but
    nothing was explicitly enforcing it either. An implicit guarantee,
    not an explicit one, and a fragile one to depend on long-term: any
    later change touching `state.scores` before the first match starts (a
    migration step, some new pre-population logic, anything) would have
    silently broken it, with no reset call anywhere in the way to catch
    it - flagged as a real concern before it ever actually caused a
    problem. Explicitly running every new game's first match through the
    exact same reset path removes that gap entirely, rather than leaving
    the first-ever game as a special, implicit case relying on a
    coincidence.
  - `lobby_system.hud.set_scoreboard_hidden(true/false)` and
    `set_match_counter_hidden(true/false)` toggle the scoreboard and
    "Race: N/M" counter off/on globally (affecting what everyone sees,
    not a per-player setting) - e.g. for an admin clearing on-screen UI
    out of the way for a clean screenshot (see lightcycles' `/lc
    show`/`hide` for a worked example built on this).
  - `lobby_system.set_scoreboard_filter_fn(fn)` restricts who actually
    appears on the scoreboard, beyond `all_known_players`'s own default
    of every currently-connected player - `fn(name)` is called once per
    candidate name, return `true` to include it. `all_known_players`
    including every connected player (not just active participants) is a
    reasonable default for a generic "show the leaderboard" scoreboard,
    but not every game wants that before anyone's actually played a
    round yet; lightcycles uses this to only show players currently in
    its lobby queue or actively racing.
- **Match duration tracking**: `get_last_match_duration(name)` returns how
  many seconds `name` spent in their most recently completed match.
- **Big event announcements**: countdown ticks, joins, and whatever your
  game reports via `player_died`/`player_won`/`match_draw` all get a large
  centered on-screen flash in addition to a chat message - much easier to
  notice/read than chat alone, especially on a high-DPI display. Controlled
  by the `hud_scale` setting. `player_won`/`match_draw` both accept an
  optional trailing `flash_duration` argument (default 4 seconds) - worth
  raising (lightcycles uses up to 10) when folding in an overall-game-winner
  message too, since that's more text taking a moment longer to read.
  - `flash_all` itself cancels whichever timer an earlier call already
    scheduled before starting its own - without this, calling it twice in
    close succession (e.g. `player_died`'s own short, fixed flash for the
    racer whose elimination just decided the match, immediately followed
    by `player_won`'s much longer one) left both timers running in
    parallel, and the earlier, shorter one would still fire on its
    original schedule and clear whatever text is *currently* showing,
    even after a completely different, later call has long since replaced
    it - a real, reported bug where a match-win announcement kept getting
    cut short after only a couple of seconds regardless of whatever
    `flash_duration` was actually requested for it.
- **Idle state for non-players**: anyone not currently in a match (waiting,
  or back after one ends) is automatically frozen in place (only
  camera/mouse-look still works) with their body and nametag hidden, and
  placed at `get_idle_pos()` (or a safe generic fallback). Only whatever
  your game actually spawns for an active racer should be visibly moving.
  The lobby roster itself is never cleared when a match starts - a match
  just takes a snapshot of who's in it - so anyone who played is still in
  the roster afterward and doesn't need to rejoin for the next one; they
  can `leave` explicitly (even mid-match, to opt out of the *next* one)
  if they'd rather sit a round out.
- **Sounds**: `joined.ogg`, `won.ogg`, `eliminated.ogg` (personal - only the
  eliminated player hears it) and a per-player `lobby_loop.ogg` ambience
  loop that plays whenever someone isn't racing. All four just need to
  exist in this mod's `sounds/` folder (already included) - swap them for
  your own if you want a different palette; gains are tunable in
  `settings.lua`.

## What your game is responsible for

- Anything about actual gameplay: movement, win conditions, what "dying"
  means, arena/level construction, entities, your own additional sounds/HUD.
- Deciding *when* to call `player_died`/`player_won`/`match_draw`/`game_over` -
  lobby_system only reacts to being told, it never infers this itself.
- Cleaning up your own per-player state/entities in `on_match_end` - called
  once per racer during `game_over()`, before lobby_system resets their
  generic idle state.
- Handling a mid-match player disconnect **yourself** (via your own
  `minetest.register_on_leaveplayer`) if that should affect your match (e.g.
  count as an elimination) - lobby_system only clears its own pre-match
  lobby-roster bookkeeping on disconnect, since it has no notion of what a
  disconnect should mean for your specific match logic.

## Privileges

`lobby_admin` gates starting a match below `min_players` (default 2, so by
default this means a solo start) - you get it automatically in
singleplayer and as the configured server admin; anyone else needs
`/grant <name> lobby_admin`. Feel free to reuse this same privilege for
your own admin-only `extra_formspec` controls rather than registering a
separate one, if that fits your game.

## Limitations / notes for extending this further

- **Single lobby/match at a time.** This mod's state (`lobby_system.state`)
  is one shared table, not one-per-arena. Supporting multiple concurrent
  lobbies (e.g. several simultaneous arenas on one server) would need this
  reworked into per-instance state objects rather than a single global one -
  a deliberate scope decision to keep this simple, not an oversight.
- **One registered game per world.** `register_game()` is meant to be
  called once, by the one game mod that depends on this. It's not designed
  for multiple different games to be registered simultaneously in the same
  world.
- **Score amounts and win semantics are fully up to the calling game** -
  lobby_system just persists and displays whatever `add_score`/`player_won`
  tells it to.
