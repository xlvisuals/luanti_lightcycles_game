
local S = lightcycles.settings
local HALF_PI = math.pi / 2

function lightcycles.enter_race_physics(player)
    player:set_physics_override({
        speed = 1, jump = 0, gravity = 0, sneak = false, sneak_glitch = false,
    })
end

local function wall_pos_at(pos)
    return { x = pos.x, y = S.arena_center.y + 1, z = pos.z }
end

local function snap_to_grid(obj)
    local pos = obj:get_pos()
    if pos then
        obj:set_pos(vector.round(pos))
    end
end

minetest.register_globalstep(function(dtime)
    if lobby_system.state.phase ~= "playing" then return end
    if lightcycles.paused then return end

    local to_eliminate = {}

    local cycle_collision_handled = {}

    for name, pdata in pairs(lightcycles.racers) do
        if lobby_system.state.phase ~= "playing" or not pdata.racing then break end

        if pdata.alive and pdata.cycle_obj then
            local player = pdata.is_bot and nil or minetest.get_player_by_name(name)
            local obj = pdata.cycle_obj
            if obj and obj:get_pos() and (pdata.is_bot or (player and player:is_player())) then
                local controls
                if pdata.is_bot then
                    local pos_now = obj:get_pos()
                    local dir_now = minetest.yaw_to_dir(pdata.yaw)
                    controls = lightcycles.bots.get_controls(pdata, pos_now, dir_now)
                else
                    controls = player:get_player_control()
                end

                if controls.left and not pdata.was_left then
                    pdata.yaw = pdata.yaw + HALF_PI
                    if player then player:set_look_horizontal(pdata.yaw) end
                    snap_to_grid(obj)
                end
                if controls.right and not pdata.was_right then
                    pdata.yaw = pdata.yaw - HALF_PI
                    if player then player:set_look_horizontal(pdata.yaw) end
                    snap_to_grid(obj)
                end
                pdata.was_left = controls.left
                pdata.was_right = controls.right
                pdata.yaw = pdata.yaw % (2 * math.pi)

                if player then
                    if controls.sneak then
                        player:set_look_horizontal(pdata.yaw + math.pi)
                    elseif pdata.was_sneak then
                        player:set_look_horizontal(pdata.yaw)
                    end
                end
                pdata.was_sneak = controls.sneak

                local speed_mult = 1.0
                local pitch_state = "normal"
                if controls.down then
                    if pdata.boost < 100 then
                        speed_mult = 1 - S.boost_delta
                        pdata.boost = math.min(100, pdata.boost + (100 / S.boost_time) * dtime)
                    else
                        speed_mult = 1 - (S.boost_full_delta or S.boost_delta)
                    end
                    pitch_state = "brake"
                elseif controls.up and pdata.boost > 0 then
                    speed_mult = 1 + S.boost_delta
                    pitch_state = "boost"
                    pdata.boost = math.max(0, pdata.boost - (100 / S.boost_time) * dtime)
                end

                if pitch_state ~= pdata.engine_pitch_state then
                    pdata.engine_pitch_state = pitch_state
                    local pitch = (S.sound["engine_pitch_" .. pitch_state]) or S.sound.engine_pitch_normal
                    lightcycles.sounds.set_engine_pitch(obj, name, pitch)
                end

                if player then
                    lightcycles.hud.update_boost_bar(player, pdata.boost)
                    lightcycles.hud.update_speed(player, speed_mult * 100)
                end

                local dir = minetest.yaw_to_dir(pdata.yaw)
                local speed = S.base_speed * speed_mult
                obj:set_velocity({ x = dir.x * speed, y = 0, z = dir.z * speed })
                obj:set_yaw(pdata.yaw)

                local pos = obj:get_pos()
                pos.y = S.arena_center.y + 1

                if pdata.laser_cooldown_remaining and pdata.laser_cooldown_remaining > 0 then
                    pdata.laser_cooldown_remaining = pdata.laser_cooldown_remaining - dtime
                end
                if (controls.dig or controls.jump) and pdata.laser and pdata.laser > 0
                    and (not pdata.laser_cooldown_remaining or pdata.laser_cooldown_remaining <= 0) then
                    pdata.laser = pdata.laser - 1
                    pdata.laser_cooldown_remaining = S.laser_cooldown
                    lightcycles.fire_laser(name, pos, pdata.yaw)
                    if player then
                        lightcycles.hud.update_laser(player, pdata.laser)
                    end
                    minetest.chat_send_all("[Lightcycles] " .. name .. " fired a shot! (" .. pdata.laser .. " left)")
                end

                if pdata.rocket_cooldown_remaining and pdata.rocket_cooldown_remaining > 0 then
                    pdata.rocket_cooldown_remaining = pdata.rocket_cooldown_remaining - dtime
                end
                if (controls.aux1 or controls.place) and pdata.rocket and pdata.rocket > 0
                    and (not pdata.rocket_cooldown_remaining or pdata.rocket_cooldown_remaining <= 0) then
                    pdata.rocket = pdata.rocket - 1
                    pdata.rocket_cooldown_remaining = S.rocket_cooldown
                    lightcycles.fire_rocket(name, pos, pdata.yaw)
                    if player then
                        lightcycles.hud.update_rocket(player, pdata.rocket)
                    end
                    minetest.chat_send_all("[Lightcycles] " .. name .. " fired a rocket! (" .. pdata.rocket .. " left)")
                end

                local ahead = vector.add(pos, vector.multiply(dir, S.trail_check_ahead))
                local ahead_rounded = vector.round(ahead)
                ahead_rounded.y = S.arena_center.y + 1
                local node = minetest.get_node(ahead_rounded)
                local node_def = minetest.registered_nodes[node.name]

                local is_hazard = minetest.get_item_group(node.name, "lightcycles_wall") == 1
                    or (node_def and node_def.walkable)

                local is_pit = lightcycles.is_pit(ahead_rounded.x, ahead_rounded.z)

                if is_hazard then
                    local is_trail_wall = node.name:match("^lightcycles:wall_") ~= nil
                    if pdata.shield > 0 and is_trail_wall then
                        local wall_color = node.name:match("^lightcycles:wall_(.+)$")
                        minetest.set_node(ahead_rounded, { name = "air" })
                        lightcycles.spawn_crash_effect(ahead_rounded, wall_color)
                        pdata.shield = pdata.shield - 1
                        is_hazard = false

                        local player_obj = minetest.get_player_by_name(name)
                        lightcycles.hud.update_shield(player_obj, pdata.shield)
                        lightcycles.sounds.play_shield_break(ahead_rounded)
                        minetest.chat_send_all("[Lightcycles] " .. name .. "'s shield broke through the wall! ("
                            .. pdata.shield .. " left)")
                    else
                        table.insert(to_eliminate, name)
                    end
                end

                if is_pit then
                    table.insert(to_eliminate, name)
                end

                local is_cycle_collision = false
                if not cycle_collision_handled[name] then
                    for other_name, other_pdata in pairs(lightcycles.racers) do
                        if other_name ~= name and other_pdata.alive and other_pdata.cycle_obj
                            and not cycle_collision_handled[other_name] then
                            local other_pos = other_pdata.cycle_obj:get_pos()
                            local other_rounded = vector.round(other_pos)
                            if other_rounded.x == ahead_rounded.x and other_rounded.z == ahead_rounded.z then
                                is_cycle_collision = true
                                cycle_collision_handled[name] = true
                                cycle_collision_handled[other_name] = true
                                table.insert(to_eliminate, name)
                                table.insert(to_eliminate, other_name)
                                minetest.chat_send_all("[Lightcycles] " .. name .. " and " .. other_name
                                    .. " collided head-on!")
                                break
                            end
                        end
                    end
                end

                local eliminated_this_tick = is_hazard or is_pit or is_cycle_collision

                local rounded = vector.round(pos)
                rounded.y = S.arena_center.y + 1
                if not vector.equals(rounded, pdata.last_wall_pos) then
                    lightcycles.check_powerup_pickup(name, pdata, pos)

                    local placed_at = wall_pos_at(pdata.last_wall_pos)
                    minetest.set_node(placed_at, {
                        name = "lightcycles:wall_" .. pdata.color,
                    })
                    pdata.last_wall_pos = rounded
                elseif eliminated_this_tick then
                    local placed_at = wall_pos_at(pdata.last_wall_pos)
                    minetest.set_node(placed_at, {
                        name = "lightcycles:wall_" .. pdata.color,
                    })
                end
            end
        end
    end

    if #to_eliminate > 0 then
        lightcycles.eliminate_batch(to_eliminate)
    end
end)
