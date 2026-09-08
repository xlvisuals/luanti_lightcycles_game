
lightcycles.paused = false
lightcycles.paused_by = nil

local PAUSE_FLY_PRIVS = { fly = true, fast = true, noclip = true }

local function freeze_all_racers()
    for _, pdata in pairs(lightcycles.racers) do
        if pdata.alive and pdata.cycle_obj then
            pdata.cycle_obj:set_velocity({ x = 0, y = 0, z = 0 })
        end
    end
end

local function freeze_all_projectiles()
    for _, p in ipairs(lightcycles.projectiles) do
        if p.obj then
            p.velocity_before_pause = p.obj:get_velocity()
            p.obj:set_velocity({ x = 0, y = 0, z = 0 })
        end
    end
end

local function unfreeze_all_projectiles()
    for _, p in ipairs(lightcycles.projectiles) do
        if p.obj and p.velocity_before_pause then
            p.obj:set_velocity(p.velocity_before_pause)
            p.velocity_before_pause = nil
        end
    end
end

local function do_pause(name, player, pdata)
    lightcycles.paused = true
    lightcycles.paused_by = name

    freeze_all_racers()
    freeze_all_projectiles()

    player:set_detach()
    player:set_physics_override({ speed = 1, jump = 1, gravity = 0 })

    local privs = minetest.get_player_privs(name)
    for priv, _ in pairs(PAUSE_FLY_PRIVS) do
        privs[priv] = true
    end
    minetest.set_player_privs(name, privs)

    minetest.chat_send_all("[Lightcycles] " .. name .. " paused the match to fly around.")
    return true, "[Lightcycles] Match paused - fly/fast/noclip granted. "
        .. "Press K to actually start flying (the privilege alone doesn't turn it on). "
        .. "Run /lcpause again to resume."
end

local function do_resume(name, player, pdata)
    lightcycles.paused = false
    lightcycles.paused_by = nil
    unfreeze_all_projectiles()

    local privs = minetest.get_player_privs(name)
    for priv, _ in pairs(PAUSE_FLY_PRIVS) do
        privs[priv] = nil
    end
    minetest.set_player_privs(name, privs)

    if pdata and pdata.alive and pdata.cycle_obj then
        local off = lightcycles.settings.cycle_attach_offset
        player:set_attach(pdata.cycle_obj, "",
            { x = off.x, y = off.y, z = off.z }, { x = 0, y = 0, z = 0 })
        player:set_physics_override({ speed = 0, jump = 0, gravity = 0 })
    end

    minetest.chat_send_all("[Lightcycles] " .. name .. " resumed the match.")
    return true, "[Lightcycles] Resumed."
end

minetest.register_chatcommand("lcpause", {
    description = "Admin-only: pause the current match (freezes every "
        .. "racer in place, nobody can be eliminated or collide with "
        .. "anything while paused) and grants yourself fly/fast/noclip so "
        .. "you can move the camera around freely - e.g. to line up a "
        .. "screenshot. Run again to resume.",
    func = function(name)
        if not minetest.check_player_privs(name, { lobby_admin = true }) then
            return false, "Needs the lobby_admin priv."
        end

        local player = minetest.get_player_by_name(name)
        if not player then return false, "Not connected." end

        if lightcycles.paused then
            if lightcycles.paused_by ~= name then
                return false, "Already paused by " .. tostring(lightcycles.paused_by)
                    .. " - only they can resume it (re-attaching only makes sense for "
                    .. "whoever was actually detached from their own cycle)."
            end
            return do_resume(name, player, lightcycles.racers[name])
        end

        if lobby_system.state.phase ~= "playing" then
            return false, "No match is currently in progress."
        end

        local pdata = lightcycles.racers[name]
        if not (pdata and pdata.alive) then
            return false, "You need to be an active racer in the current "
                .. "match to use this - it's specifically for pausing "
                .. "mid-race, not for spectating."
        end

        return do_pause(name, player, pdata)
    end,
})

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    if lightcycles.paused and lightcycles.paused_by == name then
        lightcycles.paused = false
        lightcycles.paused_by = nil
        minetest.chat_send_all("[Lightcycles] " .. name
            .. " disconnected while paused - match resumed automatically.")
    end
end)
