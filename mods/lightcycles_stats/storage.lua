
lightcycles_stats = rawget(_G, "lightcycles_stats") or {}

local storage = minetest.get_mod_storage()

local MP_KEY = "mp_stats"
local SOLO_KEY = "solo_records"

local DEFAULT_MP_STATS = {
    races_played = 0,
    races_won = 0,
    games_played = 0,
    games_won = 0,
    point_powerups = 0,
    laser_powerups = 0,
    boost_powerups = 0,
    rocket_powerups = 0,
    shield_powerups = 0,
    kills = 0,
    deaths = 0,
    total_points = 0,
    lasers_shot = 0,
    lasers_hit = 0,
    rockets_shot = 0,
    rockets_hit = 0,
    last_game_key = "",
}

local function with_defaults(t)
    t = t or {}
    for k, v in pairs(DEFAULT_MP_STATS) do
        if t[k] == nil then t[k] = v end
    end
    return t
end

local mp_stats     -- name -> stats table, loaded lazily
local solo_records -- array of record tables, loaded lazily

local function load_mp_stats()
    if mp_stats then return mp_stats end
    mp_stats = {}
    local raw = storage:get_string(MP_KEY)
    if raw and raw ~= "" then
        local ok, decoded = pcall(minetest.parse_json, raw)
        if ok and type(decoded) == "table" then
            for name, t in pairs(decoded) do
                mp_stats[name] = with_defaults(t)
            end
        else
            minetest.log("warning", "[lightcycles_stats] Failed to parse stored "
                .. "multiplayer stats - starting fresh.")
        end
    end
    return mp_stats
end

local function save_mp_stats_blob()
    storage:set_string(MP_KEY, minetest.write_json(mp_stats))
end

local function load_solo_records()
    if solo_records then return solo_records end
    solo_records = {}
    local raw = storage:get_string(SOLO_KEY)
    if raw and raw ~= "" then
        local ok, decoded = pcall(minetest.parse_json, raw)
        if ok and type(decoded) == "table" then
            solo_records = decoded
        else
            minetest.log("warning", "[lightcycles_stats] Failed to parse stored "
                .. "solo records - starting fresh.")
        end
    end
    return solo_records
end

local function save_solo_records_blob()
    storage:set_string(SOLO_KEY, minetest.write_json(solo_records))
end


function lightcycles_stats.get_mp_stats(name)
    local all = load_mp_stats()
    if not all[name] then
        all[name] = with_defaults({})
    end
    return all[name]
end

function lightcycles_stats.save_mp_stats(name)
    load_mp_stats() -- ensure it's loaded (should always already be, via get_mp_stats)
    save_mp_stats_blob()
end

function lightcycles_stats.get_all_mp_stats()
    local all = load_mp_stats()
    local list = {}
    for name, stats in pairs(all) do
        table.insert(list, { name = name, stats = stats })
    end
    return list
end


function lightcycles_stats.record_solo_run(player_name, map_key, map_display, points, duration)
    local records = load_solo_records()
    for _, r in ipairs(records) do
        if r.player_name == player_name and r.map_key == map_key then
            if duration < r.duration then
                r.map_display = map_display
                r.points = points
                r.duration = duration
                save_solo_records_blob()
            end
            return
        end
    end
    table.insert(records, {
        player_name = player_name,
        map_key = map_key,
        map_display = map_display,
        points = points,
        duration = duration,
    })
    save_solo_records_blob()
end

function lightcycles_stats.get_all_solo_records()
    return load_solo_records()
end
