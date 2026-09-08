
local S = lightcycles.settings
local alive_count = 0

local function starting_value(enabled, value)
    return enabled and value or 0
end

local finish_match

lightcycles.elimination_batches = {}


local function spawn_bots(real_count)
    if S.bot_count <= 0 then return end

    local spawn_points = lightcycles.spawn_points()
    local max_total = math.min(#spawn_points, #S.colors)
    local bot_total = math.max(0, math.min(S.bot_count, max_total - real_count))
    if bot_total <= 0 then return end

    for i = 1, bot_total do
        local index = max_total - i + 1
        if index <= real_count then break end
        local sp = spawn_points[index]
        if not sp then break end

        local behavior = lightcycles.bots.resolve_behavior(i)
        local bot_name = "Bot " .. i .. " (" .. lightcycles.bots.behavior_letter(behavior) .. ")"
        local color = S.colors[index]


        local pdata = {
            color = color,
            alive = true,
            racing = true,
            yaw = sp.yaw,
            boost = starting_value(S.boost_powerups_enabled, S.starting_boost),
            was_left = false,
            was_right = false,
            last_wall_pos = vector.round(sp.pos),
            cycle_obj = nil,
            engine_pitch_state = "normal",
            ammo = starting_value(S.ammo_powerups_enabled, S.starting_ammo),
            shot_cooldown_remaining = 0,
            shield = starting_value(S.shield_powerups_enabled, S.starting_shield),
            is_bot = true,
            bot_behavior = behavior,
            race_rank = 0,
            race_score = 0,
        }
        lightcycles.racers[bot_name] = pdata
        alive_count = alive_count + 1

        pdata.cycle_obj = lightcycles.spawn_bot_cycle(bot_name, color, sp.pos, sp.yaw)
        if pdata.cycle_obj then
            local obj = pdata.cycle_obj
            minetest.after(0.2, function()
                if pdata.alive and pdata.cycle_obj == obj and obj:get_pos() then
                    lightcycles.sounds.start_engine_loop(obj, bot_name)
                end
            end)
        end
    end
end

local function despawn_all_bots()
    for name, pdata in pairs(lightcycles.racers) do
        if pdata.is_bot then
            lightcycles.sounds.stop_engine_loop(name)
            lightcycles.despawn_cycle(nil, pdata)
            lightcycles.racers[name] = nil
        end
    end
end


local function mark_eliminated(name, custom_message)
    local pdata = lightcycles.racers[name]
    if not pdata or not pdata.alive then return end

    pdata.alive = false
    alive_count = alive_count - 1

    if S.remove_walls_on_eliminate then
        lightcycles.clear_color_trail(pdata.color)
    end

    local player = minetest.get_player_by_name(name)
    local crash_pos = pdata.cycle_obj and pdata.cycle_obj:get_pos()
    lightcycles.sounds.stop_engine_loop(name)
    lightcycles.despawn_cycle(player, pdata)
    if crash_pos then
        lightcycles.spawn_crash_effect(crash_pos, pdata.color)
    end
    if player then
        player:set_velocity({ x = 0, y = 0, z = 0 })
        lightcycles.enter_spectate(player, pdata)
    end

    lobby_system.player_died(name, custom_message or (name .. " was derezzed"))
end

local pending_decision = false

local function finalize_decision()
    pending_decision = false
    if lobby_system.state.phase ~= "playing" then return end -- already ended some other way

    local winner = nil
    local alive_now = 0
    local still_alive = {}
    local human_alive = false
    for n, p in pairs(lightcycles.racers) do
        if p.alive then
            alive_now = alive_now + 1
            winner = n
            table.insert(still_alive, n)
            if not p.is_bot then human_alive = true end
        end
    end

    if alive_now <= 1 then
        lightcycles.end_match(winner) -- nil (draw) if alive_now == 0
    elseif not human_alive then
        finish_match(still_alive, "No humans left racing - " .. #still_alive .. " bot"
            .. (#still_alive == 1 and "" or "s") .. " tie for the win.")
    end
end

local function any_human_alive()
    for n, p in pairs(lightcycles.racers) do
        if p.alive and not p.is_bot then return true end
    end
    return false
end

local function check_for_winner()
    if not pending_decision and (alive_count <= 1 or not any_human_alive()) then
        pending_decision = true
        minetest.after(S.mutual_elimination_grace, finalize_decision)
    end
end

local function assign_race_rank(names)
    for _, name in ipairs(names) do
        local pdata = lightcycles.racers[name]
        if pdata and pdata.alive then
            pdata.race_rank = alive_count
        end
    end
end

function lightcycles.eliminate(name, custom_message)
    assign_race_rank({ name })
    mark_eliminated(name, custom_message)
    table.insert(lightcycles.elimination_batches, { name })
    lightcycles.hud.update_race_table()
    check_for_winner()
end

function lightcycles.eliminate_batch(names)
    assign_race_rank(names)
    for _, name in ipairs(names) do
        mark_eliminated(name)
    end
    table.insert(lightcycles.elimination_batches, names)
    lightcycles.hud.update_race_table()
    check_for_winner()
end


local function count_racers()
    local n = 0
    for _ in pairs(lightcycles.racers) do n = n + 1 end
    return n
end

local function award_match_points(top_tier_names)
    if top_tier_names == nil then return end

    local tiers = { top_tier_names }
    for i = #lightcycles.elimination_batches, 1, -1 do
        table.insert(tiers, lightcycles.elimination_batches[i])
    end

    for tier_index, names in ipairs(tiers) do
        local points = S.placement_points[tier_index] or 0
        for _, name in ipairs(names) do
            if points > 0 then
                lobby_system.add_score(name, points)
                local pdata = lightcycles.racers[name]
                if pdata then
                    pdata.race_score = pdata.race_score + points
                end
            end
        end
    end
end


lightcycles.match_generation = 0

local match_start_us = nil      -- set in on_match_prepare, i.e. roughly when Start was clicked
local last_match_duration = nil -- seconds (integer), the most recently *completed* match's duration

local function elapsed_race_seconds()
    if not match_start_us then return 0 end
    local elapsed = (minetest.get_us_time() - match_start_us) / 1000000 - lobby_system.settings.countdown_seconds
    return math.max(0, math.floor(elapsed))
end

lobby_system.set_match_counter_suffix(function()
    local phase = lobby_system.state.phase
    if phase == "playing" or phase == "countdown" then
        local elapsed = elapsed_race_seconds()
        if S.match_max_duration then
            return math.max(0, S.match_max_duration - elapsed) .. "s"
        end
        return elapsed .. "s"
    elseif last_match_duration then
        return last_match_duration .. "s"
    end
    return nil
end)

lobby_system.set_scoreboard_filter_fn(function(name)
    return lobby_system.state.lobby[name] or lobby_system.state.racers[name] or false
end)

local timeout_job = nil
local clock_tick_job = nil

local function match_clock_tick(generation)
    if lightcycles.match_generation ~= generation then return end
    local phase = lobby_system.state.phase
    if phase ~= "playing" and phase ~= "countdown" then return end
    lobby_system.hud.update_all_scoreboards()
    lightcycles.hud.update_race_table()
    clock_tick_job = minetest.after(1, function() match_clock_tick(generation) end)
end

finish_match = function(top_tier_names, message)
    if timeout_job then
        timeout_job:cancel(); timeout_job = nil
    end
    if clock_tick_job then
        clock_tick_job:cancel(); clock_tick_job = nil
    end
    lightcycles.stop_boost_powerup_loop()
    lightcycles.stop_shield_powerup_loop()
    lightcycles.stop_ammo_powerup_loop()
    lightcycles.despawn_point_powerup_entities()
    lightcycles.clear_all_projectiles()

    for name, pdata in pairs(lightcycles.racers) do
        pdata.racing = false -- stops movement.lua's globalstep touching them further
        if pdata.cycle_obj then
            pdata.cycle_obj:set_velocity({ x = 0, y = 0, z = 0 })
        end
        lightcycles.sounds.stop_engine_loop(name)
    end
    lightcycles.clear_active_boost_powerup()

    last_match_duration = elapsed_race_seconds()

    if top_tier_names then
        for _, name in ipairs(top_tier_names) do
            local pdata = lightcycles.racers[name]
            if pdata then pdata.race_rank = 1 end
        end
    end

    award_match_points(top_tier_names)
    lobby_system.hud.update_all_scoreboards()
    lightcycles.hud.update_race_table()
    lightcycles.hud.snapshot_race_table()

    local full_message = message .. " (" .. last_match_duration .. "s)"

    local overall_message = lobby_system.check_overall_winner()
    if overall_message then
        full_message = full_message .. "\n" .. overall_message
    end
    local game_over_message = lobby_system.check_matches_per_game_winner()
    if game_over_message then
        full_message = full_message .. "\n" .. game_over_message
    end
    local session_ended = overall_message or game_over_message

    local return_delay = session_ended and 10 or 6

    local flash_duration = return_delay

    if top_tier_names and #top_tier_names == 1 then
        lobby_system.player_won(top_tier_names[1], full_message, 0, flash_duration)
    else
        lobby_system.match_draw(full_message, flash_duration)
    end

    minetest.after(return_delay, function()
        lightcycles.clear_trails()
        lobby_system.game_over()
        despawn_all_bots()
    end)
end

function lightcycles.end_match(winner)
    local top_tier
    if winner then
        top_tier = { winner }
    elseif count_racers() > 1 then
        top_tier = {}
    end -- else: solo draw, top_tier stays nil - no placement scoring

    local message = winner and (winner .. " wins the match!")
        or "No survivors - the match ends in a draw."
    finish_match(top_tier, message)
end

function lightcycles.end_match_timeout()
    local still_alive = {}
    for name, pdata in pairs(lightcycles.racers) do
        if pdata.alive then table.insert(still_alive, name) end
    end

    if count_racers() <= 1 then
        finish_match(nil, "Time's up! No survivors bonus for a solo run.")
    else
        finish_match(still_alive, "Time's up! " .. #still_alive .. " rider"
            .. (#still_alive == 1 and "" or "s") .. " tie for the win.")
    end
end

local HELP_FORMNAME = "lightcycles:help"

local function help_formspec()
    local text = table.concat({
        "\n",
        "Lightcycyles is a 3D multiplayer Tron-style lightcycle racing game: leave a trail (jetwall) as you drive, hit any obstacle and you get eliminated (derezzed). Brake or pick up a boost powerup to charge your boost bar for additional speed. Collect shield powerups to break through trails, and ammo powerups to derezz trails or opponents with a laser bolt.\n",
		"\n",
		"<b>Controls</b>\n",
		"- A / D : turn 90 degrees left or right.\n",
		"- S : brake (fills the boost bar).\n",
		"- W : boost (spends the boost bar).\n",
		"- Shift : quick-look behind you while held.\n",
		"- Space or Left-click : fire a shot (requires ammo).\n",
		"- E : Open lobby menu.\n",
		"\n",
		"<b>Scoring</b>\n",
		"Every racer scores points based on where they finished: \n",
		"- 1st place : " .. S.placement_points[1] .. "\n",
		"- 2nd place : " .. S.placement_points[2] .. "\n",
		"- 3rd place : " .. S.placement_points[3] .. "\n",
		"- 4th place : " .. S.placement_points[4] .. "\n",
		"- 5th place : " .. S.placement_points[5] .. "\n",
		"- 6th place : " .. S.placement_points[6] .. "\n",
		"- 7th place : " .. S.placement_points[7] .. "\n",
		"- 8th place : " .. S.placement_points[8] .. "\n",
		"A round with no survivors doesn't award 1st place to anyone, since nobody actually won. Racers that are eliminated simultaneously occupy the same rank, and the next rank down is vacant.\n",
		"Collecting a point powerup awards " .. S.point_powerup_value .. " additional points.\n",
        "Eliminating an opponent with a shot awards " .. S.kill_by_shot_points .. " additional points.\n",
        "\n",
		"<b>Score table</b>\n",
        "The score table shows each racer's name, rank in the current race, race score (including awarded points), and overall game score: \n",
        "- Name : Player name.\n",
        "- RR : Race Rank - the rank in the current race.\n",
		"- RS : Race Score - points earned in the current race. Race Rank points are awarded at the end of the race.\n",
		"- GS : Game Score - sum of all Race Scores.\n",
		"\n",
		"<b>Powerups</b>\n",
		"- Point powerup : collect it for " .. S.point_powerup_value .. " extra points. Does not respawn.\n",
		"- Boost powerup : instantly fills your boost bar.\n",
		"- Shield powerup : lets you break through one trail wall.\n",
		"- Ammo powerup : grants " .. S.ammo_per_pickup .. " shots. \n",
		"\n",
		"<b>Player chat commands</b>\n",
		"- /lc or /lc menu : opens the lobby panel\n",
		"- /lc join : join the lobby.\n",
		"- /lc leave : leave the lobby.\n",
		"- /lc start : start a match.\n",
		"- /lc score : shows your score.\n",
		"- /lc help : opens the in-game help screen\n",
		"\n",
		"<b>Admin chat commands (admin only)</b>\n",
		"- /lcspawns : lists the spawn points of the current map.\n",
		"- /lcspawns <1-8> : teleports you to that exact spawn point, facing the way that racer would.\n",
		"- /lcpause : Pauses game movement and grants free look and move to the admin. Run it again to resume the game. The game clock is not stopped during pause.\n",
		"- /lc show [score|names|race|boost|all] : Show the player names above the lightcycles, the Scores list, and the Race number indicator, and the boost bar, or all (default).\n",
		"- /lc hide [score|names|race|boost|all] : Hide the player names above the lightcycles, the Scores list, and the Race number indicator, and the boost bar, or all.\n",
		"\n",
		"<b>Building custom maps</b>\n",
		"Clicking the 'Build Mode' button in the lobby grants fly/noclip/give permissions and hands you the tools to edit the arena:\n",
		"- Disc : a fast-digging tool.\n",
		"- Wall : bround and boundary block, right-click to place.\n",
		"- point-powerup spawner : place to spawn a point powerup above it.\n",
		"- 8 numbered player-spawn markers : place to spawn a player above it.\n",
		"Place point/player spawners on the ground level - same height as wall blocks, the point powerups and players will spawn above the spawner. Players spawn facing the direction you faced when placing the player spawner.\n",
		"Other powerups (shield, ammo, boost) appear randomly on the map and don't require spawners.\n",
		"Once you're happy with a layout, return to the lobby ('E') and press 'Save Map' to save the nap under a new name. This captures the current arena as a .mts schematic in the world folder. You can then select the map from the map dropdown immediately.\n",
		"\n"
        }, "")
    minetest.log("action", "Lightcycles - Help:\n\n" .. text)

    return {
        "formspec_version[4]",
        "size[9,10]",
        "bgcolor[#000000AD]", -- Background. Default is bgcolor[#000000AA]
        "label[0.4,0.5;Lightcycles - Help]",
        "button_exit[6.6,0.3;2,0.6;lc_help_close;Close]",
        "hypertext[0.4,1.2;8.2,8.3;lc_help_text;" .. minetest.formspec_escape(text) .. "]",
    }
end

function lightcycles.show_help(name)
    minetest.show_formspec(name, HELP_FORMNAME, table.concat(help_formspec(), ""))
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= HELP_FORMNAME then return end
    local name = player:get_player_name()
    lobby_system.gui.show(name)
    return true
end)


local EXPORT_FORMNAME = "lightcycles:export_map"

local function export_map_formspec()
    local prefix = lightcycles.export_map_prefix()

    return {
        "formspec_version[4]",
        "size[8,4.2]",
        "bgcolor[#000000AD]", -- Background. Default is bgcolor[#000000AA]
        "label[0.4,0.6;Save Current Map]",
        "label[0.4,1.5;Filename: " .. minetest.formspec_escape(prefix) .. "<name>.mts]",
        "label[0.4,2.2;Name:]",
        "field[1.4,1.9;6.3,0.7;lc_export_name;;]",
        "set_focus[lc_export_name]",
        "button[0.4,3.2;3.6,0.8;lc_export_confirm;Save]",
        "button[4.2,3.2;3.6,0.8;lc_export_cancel;Cancel]",
    }
end

function lightcycles.show_export_map(name)
    minetest.show_formspec(name, EXPORT_FORMNAME, table.concat(export_map_formspec(), ""))
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= EXPORT_FORMNAME then return end
    local name = player:get_player_name()
    local is_admin = minetest.check_player_privs(name, { lobby_admin = true })
    local exporting = false

    if is_admin and (fields.lc_export_confirm or fields.key_enter_field == "lc_export_name") then
        local filename, err = lightcycles.export_map_filename(fields.lc_export_name)
        if filename then
            exporting = true
            minetest.chat_send_player(name, "[Lightcycles] Saving current map as '" .. filename .. "'...")
            lightcycles.export_current_map(filename, function(ok, message)
                minetest.chat_send_all("[Lightcycles] " .. name .. ": " .. message)
                if minetest.get_player_by_name(name) then
                    lobby_system.gui.show(name)
                end
            end)
        else
            minetest.chat_send_player(name, "[Lightcycles] Save failed - " .. err .. ".")
        end
    end

    if not exporting then
        lobby_system.gui.show(name)
    end
    return true
end)


lobby_system.register_game({
    title = S.title or "Lightcycles",
    command = "lc",
    max_players = #S.colors,
    matches_per_game = S.matches_per_session,
    show_help = lightcycles.show_help,
    on_extra_command = function(name, param)
        return lightcycles.handle_ui_command and lightcycles.handle_ui_command(name, param)
    end,

    get_idle_pos = function()
        return lightcycles.lobby_pos(), 0
    end,

    get_spawn = function(index)
        local sp = lightcycles.spawn_points()[index]
        return sp.pos, sp.yaw
    end,

    on_match_prepare = function(count)
        lightcycles.clear_trails()
        alive_count = 0
        lightcycles.elimination_batches = {}
        match_start_us = minetest.get_us_time()
        last_match_duration = nil -- don't show the previous match's stale duration during this one
        lightcycles.match_generation = lightcycles.match_generation + 1
        local this_generation = lightcycles.match_generation

        if timeout_job then
            timeout_job:cancel(); timeout_job = nil
        end
        if clock_tick_job then
            clock_tick_job:cancel(); clock_tick_job = nil
        end

        match_clock_tick(this_generation) -- starts the once-a-second live clock refresh for this match

        if S.match_max_duration then
            timeout_job = minetest.after(lobby_system.settings.countdown_seconds + S.match_max_duration, function()
                if lobby_system.state.phase == "playing" and lightcycles.match_generation == this_generation then
                    lightcycles.end_match_timeout()
                end
            end)
        end

        if S.point_powerups_enabled then
            lightcycles.spawn_point_powerup_entities()
        end
        if S.boost_powerups_enabled then
            lightcycles.start_boost_powerup_loop(this_generation)
        end
        if S.shield_powerups_enabled then
            lightcycles.start_shield_powerup_loop(this_generation)
        end
        if S.ammo_powerups_enabled then
            lightcycles.start_ammo_powerup_loop(this_generation)
        end

        spawn_bots(count)
    end,

    on_racing_started = function()
        for _, player in ipairs(minetest.get_connected_players()) do
            lightcycles.hud.set_race_table_visible(player, true)
        end
    end,

    on_match_start = function(name, index, pos, yaw)
        if lightcycles.is_build_mode_on(name) then
            lightcycles.set_build_mode(name, false)
        end

        local color = S.colors[index]
        local player = minetest.get_player_by_name(name)

        local pdata = {
            color = color,
            alive = true,
            racing = true,
            yaw = yaw,
            boost = starting_value(S.boost_powerups_enabled, S.starting_boost),
            was_left = false,
            was_right = false,
            last_wall_pos = vector.round(pos),
            cycle_obj = nil,
            engine_pitch_state = "normal",
            ammo = starting_value(S.ammo_powerups_enabled, S.starting_ammo),
            shot_cooldown_remaining = 0,
            shield = starting_value(S.shield_powerups_enabled, S.starting_shield),
            race_rank = 0,
            race_score = 0,
        }
        lightcycles.racers[name] = pdata
        alive_count = alive_count + 1

        if player then
            player:set_physics_override({ speed = 0, jump = 0, gravity = 0 })
            pdata.cycle_obj = lightcycles.spawn_cycle(player, pdata, color, pos, yaw)
            lightcycles.hud.add_boost_bar(player)
            lightcycles.hud.set_race_table_visible(player, true)
            lightcycles.hud.update_race_table()
            if lightcycles.boost_hidden then
                lightcycles.hud.set_boost_visible(player, false)
            end
            lightcycles.hud.update_ammo(player, pdata.ammo)
            lightcycles.hud.update_shield(player, pdata.shield)
            lightcycles.hud.update_boost_bar(player, pdata.boost)

            if pdata.cycle_obj then
                local obj = pdata.cycle_obj
                minetest.after(0.2, function()
                    if pdata.alive and pdata.cycle_obj == obj and obj:get_pos() then
                        lightcycles.sounds.start_engine_loop(obj, name)
                    end
                end)
            end
        end

    end,

    on_match_end = function(name)
        local pdata = lightcycles.racers[name]
        local player = minetest.get_player_by_name(name)
        lightcycles.sounds.stop_engine_loop(name)
        lightcycles.despawn_cycle(player, pdata)
        if player then
            lightcycles.hud.remove_boost_bar(player)
        end
        lightcycles.racers[name] = nil
    end,

    on_racing_ended = function()
        lightcycles.hud.update_race_table()
    end,

    extra_formspec = function(name)
        local fs = {}
        local is_admin = minetest.check_player_privs(name, { lobby_admin = true })

        if is_admin then
            local can_rebuild = lobby_system.state.phase == "lobby"
            local can_reset = can_rebuild or lobby_system.state.phase == "ended"

            local discovered = lightcycles.discover_maps()
            local map_names = {}
            local current_key = lightcycles.current_map_key()
            local current_idx = 1
            for i, m in ipairs(discovered) do
                map_names[i] = minetest.formspec_escape(m.display_name)
                if m.key == current_key then current_idx = i end
            end
            if #map_names == 0 then
                table.insert(fs, "label[0.4,4.9;Map: (no valid .mts files found in schems/)]")
            else
                table.insert(fs, "label[0.4,4.95;Map:]")
                table.insert(fs, "dropdown[1.25,4.65;2.95,0.7;lc_map_select;" ..
                    table.concat(map_names, ",") .. ";" .. current_idx .. ";true]")
                table.insert(fs, "button[4.35,4.65;3.70,0.7;lc_load_map;" ..
                    (can_rebuild and "Load Map" or "Load (wait)") .. "]")
            end

            local race_options = { 1, 3, 5, 7, 10, 15, 20 }
            local races_idx = 4 -- default: "7", if nothing below matches better
            for i, n in ipairs(race_options) do
                if n == S.matches_per_session then races_idx = i; break end
            end
            table.insert(fs, "label[0.4,5.8;Races per game:]")
            table.insert(fs, "dropdown[2.8,5.50;1.40,0.7;lc_races_select;" ..
                table.concat(race_options, ",") .. ";" .. races_idx .. ";true]")
            table.insert(fs, "button[4.35,5.5;3.75,0.7;lc_reset_game;" ..
                (can_reset and "Reset Game" or "Reset (wait for lobby)") .. "]")

            local points_label = S.point_powerups_enabled
                and "Point Powerups: ON" or "Point Powerups: off"
            local boost_label = S.boost_powerups_enabled
                and "Boost Powerups: ON" or "Boost Powerups: off"
            table.insert(fs, "button[0.4,6.4;3.75,0.8;lc_point_powerups_toggle;" ..
                minetest.formspec_escape(points_label) .. "]")
            table.insert(fs, "button[4.35,6.4;3.75,0.8;lc_boost_powerups_toggle;" ..
                minetest.formspec_escape(boost_label) .. "]")

            local shield_label = S.shield_powerups_enabled
                and "Shield Powerups: ON" or "Shield Powerups: off"
            local ammo_label = S.ammo_powerups_enabled
                and "Ammo Powerups: ON" or "Ammo Powerups: off"
            table.insert(fs, "button[0.4,7.3;3.75,0.8;lc_shield_powerups_toggle;" ..
                minetest.formspec_escape(shield_label) .. "]")
            table.insert(fs, "button[4.35,7.3;3.75,0.8;lc_ammo_powerups_toggle;" ..
                minetest.formspec_escape(ammo_label) .. "]")

            local walls_label = S.remove_walls_on_eliminate
                and "On derez: ERASE trails"
                or "On derez: KEEP trails"
            table.insert(fs, "button[0.4,8.2;3.75,0.8;lc_walls_toggle;" ..
                minetest.formspec_escape(walls_label) .. "]")

            table.insert(fs, "label[0.4,9.45;Bots:]")
            table.insert(fs, "dropdown[1.25,9.15;1.5,0.7;lc_bot_count;0,1,2,3,4,5,6,7;" ..
                (S.bot_count + 1) .. ";true]")
            local behavior_options = { "random", "passive", "opportunistic", "aggressive" }
            local behavior_idx = 1
            for i, b in ipairs(behavior_options) do
                if b == S.bot_behavior then behavior_idx = i; break end
            end
            table.insert(fs, "label[3.0,9.45;Behavior:]")
            table.insert(fs, "dropdown[4.4,9.15;3.7,0.7;lc_bot_behavior;" ..
                table.concat(behavior_options, ",") .. ";" .. behavior_idx .. ";true]")
            table.insert(fs, "button[0.4,10.8;3.75,0.8;lc_build_mode;Enter Build Mode]")
            table.insert(fs, "button[4.35,10.8;3.75,0.8;lc_export_map;Save Map]")
        else
            local discovered = lightcycles.discover_maps()
            local current_key = lightcycles.current_map_key()
            local map_display = "(none)"
            for _, m in ipairs(discovered) do
                if m.key == current_key then
                    map_display = m.display_name
                    break
                end
            end
            table.insert(fs, "label[0.4,4.95;Map: " .. minetest.formspec_escape(map_display) .. "]")

            table.insert(fs, "label[0.4,5.75;Races per game: " .. S.matches_per_session .. "]")

            table.insert(fs, "label[0.4,6.55;Point Powerups: "
                .. (S.point_powerups_enabled and "ON" or "off") .. "]")
            table.insert(fs, "label[4.35,6.55;Boost Powerups: "
                .. (S.boost_powerups_enabled and "ON" or "off") .. "]")

            table.insert(fs, "label[0.4,7.35;Shield Powerups: "
                .. (S.shield_powerups_enabled and "ON" or "off") .. "]")
            table.insert(fs, "label[4.35,7.35;Ammo Powerups: "
                .. (S.ammo_powerups_enabled and "ON" or "off") .. "]")

            table.insert(fs, "label[0.4,8.15;On derez: "
                .. (S.remove_walls_on_eliminate and "ERASE trails" or "KEEP trails") .. "]")

            table.insert(fs, "label[0.4,8.95;Bots: " .. S.bot_count .. "]")
            if S.bot_count > 0 then
                table.insert(fs, "label[3.0,8.95;Behavior: "
                    .. minetest.formspec_escape(S.bot_behavior) .. "]")
            end
        end

        return table.concat(fs, "")
    end,

    on_extra_fields = function(name, fields)
        local is_admin = minetest.check_player_privs(name, { lobby_admin = true })

        if fields.lc_walls_toggle then
            if is_admin then
                S.remove_walls_on_eliminate = not S.remove_walls_on_eliminate
                minetest.chat_send_all("[Lightcycles] " .. name .. " set eliminated players' walls to "
                    .. (S.remove_walls_on_eliminate and "be REMOVED" or "STAY") .. " on derez.")
                lobby_system.gui.refresh_all()
            end
            return true
        elseif fields.lc_load_map then
            if is_admin and lobby_system.state.phase == "lobby" then
                local idx = tonumber(fields.lc_map_select)
                local map = idx and lightcycles.discover_maps()[idx]
                if map then
                    minetest.chat_send_all("[Lightcycles] " .. name .. " is loading map: " .. map.display_name .. "...")
                    lightcycles.load_map(map.key, function(ok)
                        minetest.chat_send_all(ok
                            and ("[Lightcycles] Map loaded: " .. map.display_name)
                            or ("[Lightcycles] Failed to load map: " .. map.display_name .. " - see server log."))
                        lobby_system.gui.refresh_all()
                    end)
                end
            end
            return true
        elseif fields.lc_export_map then
            if is_admin then
                lightcycles.show_export_map(name)
            end
            return false
        elseif fields.lc_build_mode then
            if is_admin then
                lightcycles.set_build_mode(name, true)
                minetest.chat_send_player(name, "[Lightcycles] Build mode ON - fly/noclip/give granted. "
                    .. "Bring the lobby panel back up (however you normally do) to leave build mode.")
                lobby_system.gui.close(name)
            end
            return false
        elseif fields.lc_point_powerups_toggle then
            if is_admin then
                S.point_powerups_enabled = not S.point_powerups_enabled
                if not S.point_powerups_enabled then
                    lightcycles.despawn_point_powerup_entities()
                end
                minetest.chat_send_all("[Lightcycles] " .. name .. " turned point powerups "
                    .. (S.point_powerups_enabled and "ON" or "off") .. ".")
                lobby_system.gui.refresh_all()
            end
            return true
        elseif fields.lc_boost_powerups_toggle then
            if is_admin then
                S.boost_powerups_enabled = not S.boost_powerups_enabled
                if not S.boost_powerups_enabled then
                    lightcycles.clear_active_boost_powerup()
                end
                minetest.chat_send_all("[Lightcycles] " .. name .. " turned boost powerups "
                    .. (S.boost_powerups_enabled and "ON" or "off") .. ".")
                lobby_system.gui.refresh_all()
            end
            return true
        elseif fields.lc_shield_powerups_toggle then
            if is_admin then
                S.shield_powerups_enabled = not S.shield_powerups_enabled
                if not S.shield_powerups_enabled then
                    lightcycles.clear_active_shield_powerup()
                end
                minetest.chat_send_all("[Lightcycles] " .. name .. " turned shield powerups "
                    .. (S.shield_powerups_enabled and "ON" or "off") .. ".")
                lobby_system.gui.refresh_all()
            end
            return true
        elseif fields.lc_ammo_powerups_toggle then
            if is_admin then
                S.ammo_powerups_enabled = not S.ammo_powerups_enabled
                if not S.ammo_powerups_enabled then
                    lightcycles.clear_active_ammo_powerup()
                end
                minetest.chat_send_all("[Lightcycles] " .. name .. " turned ammo powerups "
                    .. (S.ammo_powerups_enabled and "ON" or "off") .. ".")
                lobby_system.gui.refresh_all()
            end
            return true
        elseif fields.lc_reset_game then
            if is_admin then
                local phase = lobby_system.state.phase
                if phase == "lobby" or phase == "ended" then
                    lobby_system.setup_new_game()
                    lobby_system.hud.update_all_scoreboards()
                    minetest.chat_send_all("[Lightcycles] " .. name
                        .. " reset the game - scores and race count are back to the start.")
                    lobby_system.gui.refresh_all()
                else
                    minetest.chat_send_player(name,
                        "[Lightcycles] Can't reset while a match is in progress - try again once it ends.")
                end
            end
            return true
        elseif fields.lc_bot_count then
            if is_admin then
                local new_count = tonumber(fields.lc_bot_count) - 1 -- dropdown index (1-8) -> count (0-7)
                if new_count and new_count >= 0 and new_count <= 7 then
                    S.bot_count = new_count
                    minetest.chat_send_all("[Lightcycles] " .. name .. " set bot count to "
                        .. S.bot_count .. " (takes effect next match).")
                    lobby_system.gui.refresh_all()
                end
            end
            return true
        elseif fields.lc_bot_behavior then
            if is_admin then
                local behavior_options = { "random", "passive", "opportunistic", "aggressive" }
                local idx = tonumber(fields.lc_bot_behavior)
                local b = idx and behavior_options[idx]
                if b then
                    S.bot_behavior = b
                    minetest.chat_send_all("[Lightcycles] " .. name .. " set bot behavior to "
                        .. b .. " (takes effect next match).")
                    lobby_system.gui.refresh_all()
                end
            end
            return true
        elseif fields.lc_races_select then
            if is_admin then
                local race_options = { 1, 3, 5, 7, 10, 15, 20 }
                local idx = tonumber(fields.lc_races_select)
                local n = idx and race_options[idx]
                if n then
                    S.matches_per_session = n
                    lobby_system.set_matches_per_game(n)
                    minetest.chat_send_all("[Lightcycles] " .. name .. " set races per game to " .. n .. ".")
                    lobby_system.gui.refresh_all()
                end
            end
            return true
        end
        return false
    end,
})


lobby_system.set_joined_lobby_text(function(name, info)
    return name .. " joined the game (" .. info.count .. "/" .. info.max .. ")."
end)
lobby_system.set_left_lobby_text("%s left the lobby.")
lobby_system.set_joined_game_text(function(name)
    return name .. " jumped into the race!"
end)
lobby_system.set_left_game_text("%s disconnected mid-race!")

lobby_system.set_reset_score_on_join(true)

lobby_system.set_new_game_on_second_player(true)

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    if lightcycles.racers[name] and lightcycles.racers[name].alive then
        lightcycles.eliminate(name)
    end
    lightcycles.racers[name] = nil
end)
