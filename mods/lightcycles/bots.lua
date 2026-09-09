
lightcycles.bots = {}

local S = lightcycles.settings

local ALL_BEHAVIORS = { "passive", "opportunistic", "aggressive" }

lobby_system.set_extra_known_names_fn(function()
    local names = {}
    for name, pdata in pairs(lightcycles.racers) do
        if pdata.is_bot then table.insert(names, name) end
    end
    return names
end)

local random_behavior_assignments = {} -- slot number -> behavior string

lobby_system.set_on_new_game_fn(function()
    random_behavior_assignments = {}
end)

function lightcycles.bots.resolve_behavior(slot_number)
    if S.bot_behavior ~= "random" then
        return S.bot_behavior
    end
    if not random_behavior_assignments[slot_number] then
        random_behavior_assignments[slot_number] = ALL_BEHAVIORS[math.random(#ALL_BEHAVIORS)]
    end
    return random_behavior_assignments[slot_number]
end

function lightcycles.bots.behavior_letter(behavior)
    return behavior:sub(1, 1)
end

local LOOKAHEAD = 3

local OPPORTUNISTIC_RANGE = 10

local SHOOT_HEAD_ON_RANGE = 8
local SHOOT_WALL_AHEAD_RANGE = 6
local SHOOT_TRAP_SIDE_RANGE = 4

local function is_hazard_node(node_name)
    local node_def = minetest.registered_nodes[node_name]
    return minetest.get_item_group(node_name, "lightcycles_wall") == 1
        or (node_def and node_def.walkable)
end

local function is_hazard_or_pit_at(pos)
    return is_hazard_node(minetest.get_node(pos).name) or lightcycles.is_pit(pos.x, pos.z)
end

local function path_clear(pos, dir, dist)
    for step = 1, dist do
        local check = vector.round(vector.add(pos, vector.multiply(dir, step)))
        check.y = S.arena_center.y + 1
        if is_hazard_or_pit_at(check) then
            return false
        end
    end
    return true
end

local MAX_OPENNESS_SEARCH = 20

local function measure_openness(pos, dir)
    for step = 1, MAX_OPENNESS_SEARCH do
        local check = vector.round(vector.add(pos, vector.multiply(dir, step)))
        check.y = S.arena_center.y + 1
        if is_hazard_or_pit_at(check) then
            return step - 1
        end
    end
    return MAX_OPENNESS_SEARCH
end

local function decide_passive(pos, dir)
    if path_clear(pos, dir, LOOKAHEAD) then
        return {} -- nothing blocking - keep going straight
    end

    local left_dir = { x = -dir.z, y = 0, z = dir.x }
    local right_dir = { x = dir.z, y = 0, z = -dir.x }

    local left_clear = path_clear(pos, left_dir, LOOKAHEAD)
    local right_clear = path_clear(pos, right_dir, LOOKAHEAD)

    local turn_left
    if left_clear and not right_clear then
        turn_left = true
    elseif right_clear and not left_clear then
        turn_left = false
    elseif left_clear and right_clear then
        local left_open = measure_openness(pos, left_dir)
        local right_open = measure_openness(pos, right_dir)
        if left_open == right_open then
            turn_left = math.random() < 0.5
        else
            turn_left = left_open > right_open
        end
    else
        turn_left = math.random() < 0.5 -- both blocked - trapped either way, pick one
    end

    return turn_left and { left = true } or { right = true }
end

local function find_nearest_powerup(pos, range)
    local best_pos, best_dist_sq = nil, range and (range * range) or math.huge

    local function consider(p)
        if not p then return end
        local dx, dz = p.x - pos.x, p.z - pos.z
        local d = dx * dx + dz * dz
        if d <= best_dist_sq then
            best_pos, best_dist_sq = p, d
        end
    end

    for _, p in ipairs(lightcycles.get_active_point_powerup_positions()) do
        consider(p)
    end
    consider(lightcycles.get_active_boost_powerup_pos())
    consider(lightcycles.get_active_shield_powerup_pos())
    consider(lightcycles.get_active_laser_powerup_pos())
    consider(lightcycles.get_active_rocket_powerup_pos())

    return best_pos
end

local function powerup_still_at(target)
    local check = vector.round(target)
    check.y = S.arena_center.y + 1
    local n = minetest.get_node(check).name
    return n == "lightcycles:powerup_point" or n == "lightcycles:powerup_boost"
        or n == "lightcycles:powerup_shield" or n == "lightcycles:powerup_laser"
        or n == "lightcycles:powerup_rocket"
end

local function steer_towards(pos, dir, target)
    local dx = target.x - pos.x
    local dz = target.z - pos.z
    if math.abs(dx) < 0.5 and math.abs(dz) < 0.5 then
        return {}, true -- close enough that pickup detection will catch it
    end

    local left_dir = { x = -dir.z, y = 0, z = dir.x }
    local right_dir = { x = dir.z, y = 0, z = -dir.x }

    local straight_helps = (dir.x * dx + dir.z * dz) > 0
    if straight_helps and path_clear(pos, dir, LOOKAHEAD) then
        return {}, true
    end

    local left_helps = (left_dir.x * dx + left_dir.z * dz) > 0
    local right_helps = (right_dir.x * dx + right_dir.z * dz) > 0

    if left_helps and path_clear(pos, left_dir, LOOKAHEAD) then
        return { left = true }, true
    end
    if right_helps and path_clear(pos, right_dir, LOOKAHEAD) then
        return { right = true }, true
    end

    return nil, false
end

local function decide_opportunistic(pdata, pos, dir)
    if pdata.bot_target and not powerup_still_at(pdata.bot_target) then
        pdata.bot_target = nil -- collected/expired before we got there
    end

    if not pdata.bot_target then
        pdata.bot_target = find_nearest_powerup(pos, OPPORTUNISTIC_RANGE)
    end

    if pdata.bot_target then
        local controls, still_useful = steer_towards(pos, dir, pdata.bot_target)
        if still_useful then
            return controls
        end
        pdata.bot_target = nil -- path blocked - give up on this one, same as "obstacle encountered"
    end

    return decide_passive(pos, dir)
end

local function decide_aggressive(pdata, pos, dir)
    if pdata.bot_target and not powerup_still_at(pdata.bot_target) then
        pdata.bot_target = nil -- reached/collected/expired
    end

    local generation = lightcycles.powerup_spawn_generation
    if not pdata.bot_target or pdata.bot_target_generation ~= generation then
        pdata.bot_target = find_nearest_powerup(pos, nil)
        pdata.bot_target_generation = generation
    end

    if pdata.bot_target then
        local controls, still_useful = steer_towards(pos, dir, pdata.bot_target)
        if still_useful then
            return controls
        end
        pdata.bot_target = nil -- path blocked - give up on this one, same as opportunistic
    end

    return decide_passive(pos, dir)
end

local function enemy_dead_ahead(self_pdata, pos, dir, range)
    for _, other_pdata in pairs(lightcycles.racers) do
        if other_pdata ~= self_pdata and other_pdata.alive and other_pdata.cycle_obj then
            local other_pos = other_pdata.cycle_obj:get_pos()
            if other_pos then
                local dx, dz = other_pos.x - pos.x, other_pos.z - pos.z
                local forward = dx * dir.x + dz * dir.z
                local lateral = math.abs(dx * dir.z - dz * dir.x)
                if forward > 0 and forward <= range and lateral < 0.6 then
                    return true
                end
            end
        end
    end
    return false
end

local function trail_wall_ahead(pos, dir, range)
    for step = 1, range do
        local check = vector.round(vector.add(pos, vector.multiply(dir, step)))
        check.y = S.arena_center.y + 1
        local node_name = minetest.get_node(check).name
        if node_name:match("^lightcycles:wall_") then
            return true
        elseif is_hazard_node(node_name) or lightcycles.is_pit(check.x, check.z) then
            return false
        end
    end
    return false
end

local function boxed_in_by_wall(pos, dir, wall_range, side_range)
    if not trail_wall_ahead(pos, dir, wall_range) then return false end
    local left_dir = { x = -dir.z, y = 0, z = dir.x }
    local right_dir = { x = dir.z, y = 0, z = -dir.x }
    return not path_clear(pos, left_dir, side_range) and not path_clear(pos, right_dir, side_range)
end

function lightcycles.bots.get_controls(pdata, pos, dir)
    local controls
    if pdata.bot_behavior == "opportunistic" then
        controls = decide_opportunistic(pdata, pos, dir)
    elseif pdata.bot_behavior == "aggressive" then
        controls = decide_aggressive(pdata, pos, dir)
    else
        controls = decide_passive(pos, dir)
    end

    if pdata.boost and pdata.boost > 0 then
        controls.up = true
    end

    if pdata.laser and pdata.laser > 0
        and (not pdata.laser_cooldown_remaining or pdata.laser_cooldown_remaining <= 0)
        and (enemy_dead_ahead(pdata, pos, dir, SHOOT_HEAD_ON_RANGE)
            or boxed_in_by_wall(pos, dir, SHOOT_WALL_AHEAD_RANGE, SHOOT_TRAP_SIDE_RANGE)) then
        controls.jump = true
    elseif pdata.rocket and pdata.rocket > 0
        and (not pdata.rocket_cooldown_remaining or pdata.rocket_cooldown_remaining <= 0)
        and (enemy_dead_ahead(pdata, pos, dir, SHOOT_HEAD_ON_RANGE)
            or boxed_in_by_wall(pos, dir, SHOOT_WALL_AHEAD_RANGE, SHOOT_TRAP_SIDE_RANGE)) then
        controls.aux1 = true
    end

    return controls
end
