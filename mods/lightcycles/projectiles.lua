
local S = lightcycles.settings

lightcycles.projectiles = {} -- { { obj=, shooter_name=, spawn_us=, kind="laser"|"rocket" }, ... }

local HIT_RADIUS = 0.6

minetest.register_entity("lightcycles:laser_bolt", {
    initial_properties = {
        visual = "cube",
        visual_size = { x = 0.35, y = 0.35, z = 1.4 }, -- elongated along its direction of travel
        textures = {
            "lightcycles_laser_projectile.png", "lightcycles_laser_projectile.png",
            "lightcycles_laser_projectile.png", "lightcycles_laser_projectile.png",
            "lightcycles_laser_projectile.png", "lightcycles_laser_projectile.png",
        },
        physical = false, -- driven entirely by our own velocity/collision handling below, not engine physics
        pointable = false, -- not something a player can punch/select
        static_save = false, -- never persisted - always either mid-match or already gone
        glow = 14,
        collide_with_objects = false,
    },
})

minetest.register_entity("lightcycles:rocket", {
    initial_properties = {
        visual = "cube",
        visual_size = { x = 0.35, y = 0.35, z = 1.4 }, -- elongated along its direction of travel
        textures = {
            "lightcycles_rocket_projectile.png", "lightcycles_rocket_projectile.png",
            "lightcycles_rocket_projectile.png", "lightcycles_rocket_projectile.png",
            "lightcycles_rocket_projectile.png", "lightcycles_rocket_projectile.png",
        },
        physical = false, -- driven entirely by our own velocity/collision handling below, not engine physics
        pointable = false, -- not something a player can punch/select
        static_save = false, -- never persisted - always either mid-match or already gone
        glow = 14,
        collide_with_objects = false,
    },
})

function lightcycles.fire_laser(name, pos, yaw)
    local dir = minetest.yaw_to_dir(yaw)
    local spawn_pos = vector.add(pos, vector.multiply(dir, 1.2))
    spawn_pos.y = pos.y

    local obj = minetest.add_entity(spawn_pos, "lightcycles:laser_bolt")
    if not obj then return end
    obj:set_yaw(yaw)
    local speed = S.base_speed * S.laser_speed_multiplier
    obj:set_velocity({ x = dir.x * speed, y = 0, z = dir.z * speed })

    table.insert(lightcycles.projectiles, {
        obj = obj,
        shooter_name = name,
        spawn_us = minetest.get_us_time(),
        kind = "laser",
    })

    lightcycles.sounds.play_shoot_laser(pos)
end

function lightcycles.fire_rocket(name, pos, yaw)
    local dir = minetest.yaw_to_dir(yaw)
    local spawn_pos = vector.add(pos, vector.multiply(dir, 1.2))
    spawn_pos.y = pos.y

    local obj = minetest.add_entity(spawn_pos, "lightcycles:rocket")
    if not obj then return end
    obj:set_yaw(yaw)
    local speed = S.base_speed * S.rocket_speed_multiplier
    obj:set_velocity({ x = dir.x * speed, y = 0, z = dir.z * speed })

    table.insert(lightcycles.projectiles, {
        obj = obj,
        shooter_name = name,
        spawn_us = minetest.get_us_time(),
        kind = "rocket",
    })

    lightcycles.sounds.play_shoot_rocket(pos)
end

local BLAST_RADIUS = 1

local function explode_rocket(center, shooter_name)
    local cx, cz = center.x, center.z
    local y = S.arena_center.y + 1
    lightcycles.sounds.play_rocket_explosion({ x = cx, y = y, z = cz })

    for dx = -BLAST_RADIUS, BLAST_RADIUS do
        for dz = -BLAST_RADIUS, BLAST_RADIUS do
            local p = { x = cx + dx, y = y, z = cz + dz }
            local node = minetest.get_node(p)
            if node.name:match("^lightcycles:wall_") then
                local wall_color = node.name:match("^lightcycles:wall_(.+)$")
                minetest.set_node(p, { name = "air" })
                lightcycles.spawn_crash_effect(p, wall_color)
            end

            for rname, pdata in pairs(lightcycles.racers) do
                if pdata.alive and pdata.cycle_obj and rname ~= shooter_name then
                    local cpos = pdata.cycle_obj:get_pos()
                    if cpos then
                        local rp = vector.round(cpos)
                        if rp.x == p.x and rp.z == p.z then
                            local shooter_pdata = lightcycles.racers[shooter_name]
                            if shooter_pdata and shooter_pdata.alive then
                                lobby_system.add_score(shooter_name, S.kill_by_shot_points)
                                shooter_pdata.race_score = shooter_pdata.race_score + S.kill_by_shot_points
                                lobby_system.hud.update_all_scoreboards()
                                lightcycles.hud.update_race_table()
                            end
                            lightcycles.eliminate(rname, rname .. " was derezzed by " .. shooter_name
                                .. "'s rocket! (+" .. S.kill_by_shot_points .. " for " .. shooter_name .. ")")
                        end
                    end
                end
            end
        end
    end
end

function lightcycles.clear_all_projectiles()
    for _, p in ipairs(lightcycles.projectiles) do
        if p.obj then
            pcall(function() p.obj:remove() end)
        end
    end
    lightcycles.projectiles = {}
end

minetest.register_globalstep(function(dtime)
    if lobby_system.state.phase ~= "playing" then return end
    if lightcycles.paused then return end -- see pause.lua - a bolt shouldn't keep flying (or hit anything) while the match is supposedly frozen
    if #lightcycles.projectiles == 0 then return end

    for i = #lightcycles.projectiles, 1, -1 do
        local p = lightcycles.projectiles[i]
        local obj = p.obj
        local remove_this = false

        if not obj or not obj:get_pos() then
            remove_this = true
        else
            local pos = obj:get_pos()
            local hit_name = nil

            for rname, pdata in pairs(lightcycles.racers) do
                if pdata.alive and pdata.cycle_obj and rname ~= p.shooter_name then
                    local cpos = pdata.cycle_obj:get_pos()
                    if cpos and vector.distance(pos, cpos) < HIT_RADIUS then
                        hit_name = rname
                        break
                    end
                end
            end

            if hit_name then
                if p.kind == "rocket" then
                    local hit_pdata = lightcycles.racers[hit_name]
                    local hit_pos = hit_pdata and hit_pdata.cycle_obj and hit_pdata.cycle_obj:get_pos()
                    explode_rocket(vector.round(hit_pos or pos), p.shooter_name)
                else
                    local shooter_pdata = lightcycles.racers[p.shooter_name]
                    if shooter_pdata and shooter_pdata.alive then
                        lobby_system.add_score(p.shooter_name, S.kill_by_shot_points)
                        shooter_pdata.race_score = shooter_pdata.race_score + S.kill_by_shot_points
                        lobby_system.hud.update_all_scoreboards()
                        lightcycles.hud.update_race_table()
                    end
                    lightcycles.eliminate(hit_name, hit_name .. " was derezzed by " .. p.shooter_name
                        .. "'s laser! (+" .. S.kill_by_shot_points .. " for " .. p.shooter_name .. ")")
                end
                remove_this = true
            else
                local rounded = vector.round(pos)
                rounded.y = S.arena_center.y + 1
                local node = minetest.get_node(rounded)
                local node_def = minetest.registered_nodes[node.name]
                local is_trail_wall = node.name:match("^lightcycles:wall_") ~= nil
                local is_hazard = minetest.get_item_group(node.name, "lightcycles_wall") == 1
                    or (node_def and node_def.walkable)

                if is_trail_wall then
                    if p.kind == "rocket" then
                        explode_rocket(rounded, p.shooter_name)
                    else
                        local wall_color = node.name:match("^lightcycles:wall_(.+)$")
                        minetest.set_node(rounded, { name = "air" })
                        lightcycles.spawn_crash_effect(rounded, wall_color)
                    end
                    remove_this = true
                elseif is_hazard then
                    remove_this = true
                end
            end

            local lifetime = p.kind == "rocket" and S.rocket_lifetime or S.laser_lifetime
            if not remove_this and (minetest.get_us_time() - p.spawn_us) / 1000000 > lifetime then
                remove_this = true -- traveled long enough without hitting anything - give up on it
            end
        end

        if remove_this then
            if obj then pcall(function() obj:remove() end) end
            table.remove(lightcycles.projectiles, i)
        end
    end
end)
