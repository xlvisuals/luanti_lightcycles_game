
lightcycles_stats = rawget(_G, "lightcycles_stats") or {}


local session_id = tostring(minetest.get_us_time())
local current_game_number = 0

local match_is_multiplayer = false
local match_start_us = nil
local match_points_collected = {} -- name -> count, this match only

local function is_bot(name)
    local pdata = lightcycles.players[name]
    return pdata and pdata.is_bot
end

function lightcycles_stats.begin_match(total_participants, is_new_game)
    match_is_multiplayer = (total_participants or 0) > 1
    match_start_us = minetest.get_us_time()
    match_points_collected = {}
    if is_new_game then
        current_game_number = current_game_number + 1
    end
end


local POWERUP_FIELDS = {
    point = "point_powerups",
    laser = "laser_powerups",
    boost = "boost_powerups",
    rocket = "rocket_powerups",
    shield = "shield_powerups",
}

function lightcycles_stats.record_race_start(name)
    if is_bot(name) or not match_is_multiplayer then return end
    local stats = lightcycles_stats.get_mp_stats(name)
    stats.races_played = stats.races_played + 1

    local game_key = session_id .. ":" .. current_game_number
    if stats.last_game_key ~= game_key then
        stats.games_played = stats.games_played + 1
        stats.last_game_key = game_key
    end
    lightcycles_stats.save_mp_stats(name)
end

function lightcycles_stats.record_race_win(name)
    if is_bot(name) or not match_is_multiplayer then return end
    local stats = lightcycles_stats.get_mp_stats(name)
    stats.races_won = stats.races_won + 1
    lightcycles_stats.save_mp_stats(name)
end

function lightcycles_stats.record_game_win(name)
    if is_bot(name) or not match_is_multiplayer then return end
    local stats = lightcycles_stats.get_mp_stats(name)
    stats.games_won = stats.games_won + 1
    lightcycles_stats.save_mp_stats(name)
end

function lightcycles_stats.record_powerup(name, kind)
    if is_bot(name) then return end

    if kind == "point" then
        match_points_collected[name] = (match_points_collected[name] or 0) + 1
    end

    if not match_is_multiplayer then return end -- soloplayer pickups don't feed the persistent MP counters
    local field = POWERUP_FIELDS[kind]
    if not field then return end
    local stats = lightcycles_stats.get_mp_stats(name)
    stats[field] = stats[field] + 1
    lightcycles_stats.save_mp_stats(name)
end

function lightcycles_stats.record_points(name, amount)
    if is_bot(name) or not match_is_multiplayer or not amount or amount == 0 then return end
    local stats = lightcycles_stats.get_mp_stats(name)
    stats.total_points = stats.total_points + amount
    lightcycles_stats.save_mp_stats(name)
end

function lightcycles_stats.record_kill(name)
    if is_bot(name) or not match_is_multiplayer then return end
    local stats = lightcycles_stats.get_mp_stats(name)
    stats.kills = stats.kills + 1
    lightcycles_stats.save_mp_stats(name)
end

function lightcycles_stats.record_death(name)
    if is_bot(name) or not match_is_multiplayer then return end
    local stats = lightcycles_stats.get_mp_stats(name)
    stats.deaths = stats.deaths + 1
    lightcycles_stats.save_mp_stats(name)
end

function lightcycles_stats.record_shot(name, kind)
    if is_bot(name) or not match_is_multiplayer then return end
    local stats = lightcycles_stats.get_mp_stats(name)
    if kind == "laser" then
        stats.lasers_shot = stats.lasers_shot + 1
    elseif kind == "rocket" then
        stats.rockets_shot = stats.rockets_shot + 1
    else
        return
    end
    lightcycles_stats.save_mp_stats(name)
end

function lightcycles_stats.record_hit(name, kind)
    if is_bot(name) or not match_is_multiplayer then return end
    local stats = lightcycles_stats.get_mp_stats(name)
    if kind == "laser" then
        stats.lasers_hit = stats.lasers_hit + 1
    elseif kind == "rocket" then
        stats.rockets_hit = stats.rockets_hit + 1
    else
        return
    end
    lightcycles_stats.save_mp_stats(name)
end


local function current_map_key_and_display()
    local key = lightcycles.current_map_key and lightcycles.current_map_key()
    if not key then return "?", "(unknown map)" end
    for _, m in ipairs(lightcycles.discover_maps()) do
        if m.key == key then return key, m.display_name end
    end
    return key, key
end

function lightcycles_stats.record_solo_clear(name)
    if is_bot(name) or not match_start_us then return end
    local duration = math.max(0, math.floor((minetest.get_us_time() - match_start_us) / 1000000))
    local points = match_points_collected[name] or 0
    local map_key, map_display = current_map_key_and_display()
    lightcycles_stats.record_solo_run(name, map_key, map_display, points, duration)
end


local function hit_percent(hits, shots)
    if not shots or shots <= 0 then return nil end
    return (hits / shots) * 100
end

function lightcycles_stats.get_multiplayer_leaderboard()
    local list = lightcycles_stats.get_all_mp_stats()
    table.sort(list, function(a, b)
        if a.stats.total_points ~= b.stats.total_points then
            return a.stats.total_points > b.stats.total_points
        end
        return a.name < b.name
    end)
    for _, entry in ipairs(list) do
        entry.laser_hit_percent = hit_percent(entry.stats.lasers_hit, entry.stats.lasers_shot)
        entry.rocket_hit_percent = hit_percent(entry.stats.rockets_hit, entry.stats.rockets_shot)
    end
    return list
end

function lightcycles_stats.get_solo_leaderboard()
    local list = lightcycles_stats.get_all_solo_records()
    local sorted = {}
    for _, r in ipairs(list) do table.insert(sorted, r) end
    table.sort(sorted, function(a, b)
        if a.duration ~= b.duration then
            return a.duration < b.duration
        end
        return a.player_name < b.player_name
    end)
    return sorted
end
