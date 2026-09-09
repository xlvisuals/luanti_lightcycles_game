-- ===================== PROJECTILES =====================
-- The laser powerup's laser bolt: a fast, straight-line shot that derezzes
-- whatever it hits (another racer's cycle, or a trail-wall node - not the
-- boundary or other obstacles, which stop it but aren't destroyed). Not
-- tied to any one racer's own per-tick loop (movement.lua) - projectiles
-- are independent entities with their own short lifetime, tracked in
-- lightcycles.projectiles and updated by this file's own globalstep,
-- the same way powerup spawn/expiry timers run independently of the main
-- racer loop.

local S = lightcycles.settings

lightcycles.projectiles = {} -- { { obj=, shooter_name=, spawn_us=, kind="laser"|"rocket", trail_spawner= (rocket only) }, ... }

-- How close (nodes) a bolt needs to be to a cycle to count as a hit - a
-- plain distance check against the cycle's own current position, not a
-- node-based check the way wall/boundary collision works, since a moving
-- cycle isn't grid-aligned to a single cell the way a placed wall node is.
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

-- Fires a shot from pos, heading along yaw, on behalf of `name`. Doesn't
-- check laser/cooldown itself - movement.lua already did before calling
-- this, exactly like check_powerup_pickup expects its caller to have
-- already decided a pickup is happening.
function lightcycles.fire_laser(name, pos, yaw)
    local dir = minetest.yaw_to_dir(yaw)
    -- Spawned a little ahead of the shooter's own position, not exactly on
    -- top of it - otherwise the very first hit-check below could catch the
    -- shooter's own cycle before the bolt has moved anywhere at all.
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

-- Fires a rocket from pos, heading along yaw, on behalf of `name`. Doesn't
-- check rocket ammo/cooldown itself, same contract as fire_laser above -
-- movement.lua (or bots.lua's decision, consumed the same way) already
-- decided a shot is happening before calling this.
function lightcycles.fire_rocket(name, pos, yaw)
    local dir = minetest.yaw_to_dir(yaw)
    local spawn_pos = vector.add(pos, vector.multiply(dir, 1.2))
    spawn_pos.y = pos.y

    local obj = minetest.add_entity(spawn_pos, "lightcycles:rocket")
    if not obj then return end
    obj:set_yaw(yaw)
    local speed = S.base_speed * S.rocket_speed_multiplier
    obj:set_velocity({ x = dir.x * speed, y = 0, z = dir.z * speed })

    -- A little red sparkle trail behind the rocket as it flies - a
    -- particlespawner "attached" to the rocket's own entity, which makes
    -- Luanti re-spawn particles at wherever the rocket currently is every
    -- tick, rather than this file having to track/update a position
    -- itself. time = 0 means "continuous, no fixed end" (runs for as long
    -- as the spawner exists), with `amount` then read as particles/second
    -- instead of "total particles over `time`". Reuses the rocket's own
    -- projectile texture (colorized red, in case the source art isn't
    -- already a pure red) rather than shipping a dedicated spark asset -
    -- same "reuse what's already there" trick spawn_crash_effect uses for
    -- its own particles.
    local trail_spawner = minetest.add_particlespawner({
        attached = obj,
        time = 0,
        amount = 30,
        minpos = { x = 0, y = 0, z = 0 },
        maxpos = { x = 0, y = 0, z = 0 },
        minvel = { x = -0.4, y = -0.2, z = -0.4 },
        maxvel = { x = 0.4, y = 0.4, z = 0.4 },
        minacc = { x = 0, y = -1, z = 0 },
        maxacc = { x = 0, y = -1, z = 0 },
        minexptime = 0.15,
        maxexptime = 0.35,
        minsize = 0.6,
        maxsize = 1.2,
        texture = "lightcycles_rocket_projectile.png^[colorize:red:140",
        glow = 14,
        collisiondetection = false,
    })

    table.insert(lightcycles.projectiles, {
        obj = obj,
        shooter_name = name,
        spawn_us = minetest.get_us_time(),
        kind = "rocket",
        trail_spawner = trail_spawner,
    })

    lightcycles.sounds.play_shoot_rocket(pos)
end

-- How far (in grid cells, each direction) a rocket's blast reaches from
-- its impact cell - 1 means the impact cell plus its 8 neighbors, a 3x3
-- area, matching the design ask of "9 blocks total".
local BLAST_RADIUS = 1

-- Destroys every trail-wall node in the 3x3 area centered on `center`
-- (rounded to the grid, forced to trail height - the same single layer
-- every wall/boundary/floor node normally occupies) and eliminates any
-- racer currently standing in that same area, awarding the shooter a kill
-- bonus for each. Never touches the boundary or the floor: those pass the
-- same "is this walkable" collision check as a trail wall elsewhere in
-- this file, but aren't in the "lightcycles:wall_<color>" name pattern a
-- trail wall is, which is exactly what this checks for - see
-- is_trail_wall's own comment above for why name, not group, is what
-- actually tells a trail wall apart from the boundary.
--
-- shooter_name is excluded from the splash-kill check (same as a direct
-- hit already can't be the shooter's own cycle - see fire_laser/
-- fire_rocket's forward spawn offset) - self-splash off your own rocket
-- would punish exactly the shots most likely to be fired defensively, at
-- point-blank range, against something bearing down on you.
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

-- Removes every currently-active bolt outright (no impact effects) -
-- called at match end, the same "stop everything mid-flight" cleanup
-- trail walls/bots/powerups all get.
function lightcycles.clear_all_projectiles()
    for _, p in ipairs(lightcycles.projectiles) do
        if p.obj then
            pcall(function() p.obj:remove() end)
        end
        if p.trail_spawner then
            pcall(function() minetest.delete_particlespawner(p.trail_spawner) end)
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

            -- Cycle hits: plain distance check against every other still-
            -- racing cycle's current position (excludes the shooter's own -
            -- see fire_laser's forward spawn offset for why that shouldn't
            -- normally matter anyway, but this is a cheap, explicit
            -- safeguard against ever hitting yourself).
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
                    -- Blast centered on the hit racer's own exact cycle
                    -- position (not the rocket's own current pos, which
                    -- could be up to HIT_RADIUS away) - explode_rocket's
                    -- own splash check then catches this racer itself via
                    -- its center cell, same as anyone else caught in the
                    -- blast, so there's no separate direct-hit elimination
                    -- here the way the laser branch below has.
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
                -- Node hits: same hazard rule collision/bots use - any
                -- trail/boundary node, or any other ordinary walkable node.
                -- Only trail walls (name-checked, same as the shield break
                -- mechanic - the boundary shares the same collision group
                -- so group membership alone can't tell them apart) are
                -- actually destroyed; hitting the boundary or some other
                -- obstacle just stops the shot without changing anything -
                -- true for a rocket too: a rocket that reaches the
                -- boundary or another obstacle without ever touching a
                -- cycle or a trail wall just fizzles out, no explosion.
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
            -- Deleting the particlespawner explicitly rather than relying
            -- on it stopping on its own once the attached object is gone:
            -- an "attached" spawner with time = 0 has no natural end of
            -- its own, so leaving this out would leak one live,
            -- perpetually-emitting-nothing spawner per rocket for the
            -- rest of the server's uptime.
            if p.trail_spawner then
                pcall(function() minetest.delete_particlespawner(p.trail_spawner) end)
            end
            table.remove(lightcycles.projectiles, i)
        end
    end
end)
