
local S = lightcycles.settings

lightcycles.powerup_spawn_generation = 0


local active_point_powerups = {}
local had_point_powerups_this_match = false

function lightcycles.despawn_point_powerup_entities()
    for _, pos in ipairs(active_point_powerups) do
        if minetest.get_node(pos).name == "lightcycles:powerup_point" then
            minetest.set_node(pos, { name = "air" })
        end
    end
    active_point_powerups = {}
end

function lightcycles.spawn_point_powerup_entities()
    lightcycles.despawn_point_powerup_entities()
    had_point_powerups_this_match = false

    local b = lightcycles.arena_bounds()
    local collectible_y = b.y0 + 1
    for x = b.min_x, b.max_x do
        for z = b.min_z, b.max_z do
            for y = b.y0, b.y0 + S.wall_height do
                local pos = { x = x, y = y, z = z }
                if minetest.get_node(pos).name == "lightcycles:powerup_point_spawner" then
                    local collectible_pos = { x = x, y = collectible_y, z = z }
                    minetest.set_node(collectible_pos, { name = "lightcycles:powerup_point" })
                    table.insert(active_point_powerups, collectible_pos)
                    had_point_powerups_this_match = true
                    break -- found this column's spawner (if any); don't also match a second one stacked above it
                end
            end
        end
    end

    if had_point_powerups_this_match then
        lightcycles.powerup_spawn_generation = lightcycles.powerup_spawn_generation + 1
    end
end


local function random_open_position()
    local b = lightcycles.arena_bounds()
    local y = b.y0 + 1
    for _ = 1, 20 do
        local x = math.random(b.min_x + 1, b.max_x - 1)
        local z = math.random(b.min_z + 1, b.max_z - 1)
        local pos = { x = x, y = y, z = z }
        if minetest.get_node(pos).name == "air" and not lightcycles.is_pit(x, z) then
            return pos
        end
    end
    return nil -- arena too full of trails to find a spot this attempt; skip this cycle
end

local function make_random_powerup(node_name, enabled_key, interval_key, lifetime_key)
    local active = nil -- { pos = {x=,y=,z=} } or nil
    local spawn_loop_job = nil -- job handle for the currently-scheduled next spawn attempt
    local expiry_job = nil     -- job handle for the currently-active powerup's vanish timer

    local function clear_active()
        if expiry_job then expiry_job:cancel(); expiry_job = nil end
        if active then
            if minetest.get_node(active.pos).name == node_name then
                minetest.set_node(active.pos, { name = "air" })
            end
            active = nil
        end
    end

    local function spawn(generation)
        if lightcycles.match_generation ~= generation then return end
        if not S[enabled_key] or lobby_system.state.phase ~= "playing" then return end
        clear_active() -- shouldn't normally still be one, but just in case
        local pos = random_open_position()
        if pos then
            minetest.set_node(pos, { name = node_name })
            active = { pos = pos }
            lightcycles.powerup_spawn_generation = lightcycles.powerup_spawn_generation + 1
            expiry_job = minetest.after(S[lifetime_key], function()
                if lightcycles.match_generation == generation and lobby_system.state.phase == "playing" then
                    clear_active()
                end
            end)
        end
    end

    local function start_loop(generation)
        active = nil
        if spawn_loop_job then spawn_loop_job:cancel(); spawn_loop_job = nil end -- defensive, shouldn't normally still be one
        local function tick()
            if lightcycles.match_generation ~= generation then return end
            if lobby_system.state.phase ~= "playing" then return end
            spawn(generation)
            spawn_loop_job = minetest.after(S[interval_key], tick)
        end
        spawn_loop_job = minetest.after(S[interval_key], tick)
    end

    local function stop_loop()
        if spawn_loop_job then spawn_loop_job:cancel(); spawn_loop_job = nil end
        clear_active()
    end

    local function get_active_pos()
        return active and { x = active.pos.x, y = active.pos.y, z = active.pos.z } or nil
    end

    return {
        clear_active = clear_active, start_loop = start_loop, stop_loop = stop_loop,
        get_active_pos = get_active_pos,
    }
end

local boost_powerup = make_random_powerup("lightcycles:powerup_boost",
    "boost_powerups_enabled", "boost_powerup_interval", "boost_powerup_lifetime")
local shield_powerup = make_random_powerup("lightcycles:powerup_shield",
    "shield_powerups_enabled", "shield_powerup_interval", "shield_powerup_lifetime")
local laser_powerup = make_random_powerup("lightcycles:powerup_laser",
    "laser_powerups_enabled", "laser_powerup_interval", "laser_powerup_lifetime")
local rocket_powerup = make_random_powerup("lightcycles:powerup_rocket",
    "rocket_powerups_enabled", "rocket_powerup_interval", "rocket_powerup_lifetime")

function lightcycles.clear_active_boost_powerup() boost_powerup.clear_active() end
function lightcycles.start_boost_powerup_loop(generation) boost_powerup.start_loop(generation) end
function lightcycles.stop_boost_powerup_loop() boost_powerup.stop_loop() end

function lightcycles.clear_active_laser_powerup() laser_powerup.clear_active() end
function lightcycles.start_laser_powerup_loop(generation) laser_powerup.start_loop(generation) end
function lightcycles.stop_laser_powerup_loop() laser_powerup.stop_loop() end

function lightcycles.clear_active_rocket_powerup() rocket_powerup.clear_active() end
function lightcycles.start_rocket_powerup_loop(generation) rocket_powerup.start_loop(generation) end
function lightcycles.stop_rocket_powerup_loop() rocket_powerup.stop_loop() end


function lightcycles.get_active_point_powerup_positions()
    local copy = {}
    for _, pos in ipairs(active_point_powerups) do
        table.insert(copy, { x = pos.x, y = pos.y, z = pos.z })
    end
    return copy
end

function lightcycles.get_active_boost_powerup_pos()
    return boost_powerup.get_active_pos()
end

function lightcycles.get_active_shield_powerup_pos()
    return shield_powerup.get_active_pos()
end

function lightcycles.get_active_laser_powerup_pos()
    return laser_powerup.get_active_pos()
end

function lightcycles.get_active_rocket_powerup_pos()
    return rocket_powerup.get_active_pos()
end

function lightcycles.clear_active_shield_powerup() shield_powerup.clear_active() end
function lightcycles.start_shield_powerup_loop(generation) shield_powerup.start_loop(generation) end
function lightcycles.stop_shield_powerup_loop() shield_powerup.stop_loop() end


function lightcycles.check_powerup_pickup(name, pdata, pos)
    local rounded = vector.round(pos)
    rounded.y = lightcycles.arena_bounds().y0 + 1
    local node = minetest.get_node(rounded)

    if S.point_powerups_enabled and node.name == "lightcycles:powerup_point" then
        minetest.set_node(rounded, { name = "air" })
        for i, p in ipairs(active_point_powerups) do
            if vector.equals(p, rounded) then
                table.remove(active_point_powerups, i)
                break
            end
        end

        lobby_system.add_score(name, S.point_powerup_value)
        pdata.race_score = pdata.race_score + S.point_powerup_value
        lobby_system.hud.update_all_scoreboards()
        lightcycles.hud.update_race_table()
        lightcycles.sounds.play_point_pickup(rounded)
        minetest.chat_send_all("[Lightcycles] " .. name .. " picked up +" .. S.point_powerup_value .. " points!")

        local racer_count = 0
        for _ in pairs(lightcycles.racers) do racer_count = racer_count + 1 end
        if racer_count == 1 and had_point_powerups_this_match and #active_point_powerups == 0 then
            lightcycles.end_match(name)
        end
    end

    if S.boost_powerups_enabled and node.name == "lightcycles:powerup_boost" then
        minetest.set_node(rounded, { name = "air" })
        boost_powerup.clear_active()
        pdata.boost = 100
        lightcycles.sounds.play_boost_pickup(rounded)
        minetest.chat_send_all("[Lightcycles] " .. name .. " picked up a boost powerup!")
    end

    if S.shield_powerups_enabled and node.name == "lightcycles:powerup_shield" then
        minetest.set_node(rounded, { name = "air" })
        shield_powerup.clear_active()
        pdata.shield = (pdata.shield or 0) + 1
        lightcycles.hud.update_shield(minetest.get_player_by_name(name), pdata.shield)
        lightcycles.sounds.play_shield_pickup(rounded)
        minetest.chat_send_all("[Lightcycles] " .. name .. " picked up a shield (" .. pdata.shield .. " now).")
    end

    if S.laser_powerups_enabled and node.name == "lightcycles:powerup_laser" then
        minetest.set_node(rounded, { name = "air" })
        laser_powerup.clear_active()
        pdata.laser = (pdata.laser or 0) + S.laser_per_pickup
        lightcycles.hud.update_laser(minetest.get_player_by_name(name), pdata.laser)
        lightcycles.sounds.play_laser_pickup(rounded)
        minetest.chat_send_all("[Lightcycles] " .. name .. " picked up laser (" .. pdata.laser .. " now).")
    end

    if S.rocket_powerups_enabled and node.name == "lightcycles:powerup_rocket" then
        minetest.set_node(rounded, { name = "air" })
        rocket_powerup.clear_active()
        pdata.rocket = (pdata.rocket or 0) + S.rocket_per_pickup
        lightcycles.hud.update_rocket(minetest.get_player_by_name(name), pdata.rocket)
        lightcycles.sounds.play_rocket_pickup(rounded)
        minetest.chat_send_all("[Lightcycles] " .. name .. " picked up rocket (" .. pdata.rocket .. " now).")
    end
end
