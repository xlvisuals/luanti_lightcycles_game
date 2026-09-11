
lightcycles.paused = false
lightcycles.paused_by = nil

local PAUSE_FLY_PRIVS = { fly = true, fast = true, noclip = true }

local function freeze_all_players()
    for _, pdata in pairs(lightcycles.players) do
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

    freeze_all_players()
    freeze_all_projectiles()

    player:set_detach()
    player:set_physics_override({ speed = 1, jump = 1, gravity = 0 })

    local privs = minetest.get_player_privs(name)
    for priv, _ in pairs(PAUSE_FLY_PRIVS) do
        privs[priv] = true
    end
    minetest.set_player_privs(name, privs)

    minetest.chat_send_all("[Lightcycles] " .. name .. " paused the match to fly around.")
    return true, ""
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
        local off = lightcycles.settings.player_attach_offset
        player:set_attach(pdata.cycle_obj, "",
            { x = off.x, y = off.y, z = off.z }, { x = 0, y = 0, z = 0 })
        player:set_physics_override({ speed = 0, jump = 0, gravity = 0 })
    end

    minetest.chat_send_all("[Lightcycles] " .. name .. " resumed the match.")
    return true, "[Lightcycles] Resumed."
end

function lightcycles.toggle_pause(name)
    local player = minetest.get_player_by_name(name)
    if not player then return false, "Not connected." end

    if lightcycles.paused then
        if lightcycles.paused_by ~= name then
            return false, "Already paused by " .. tostring(lightcycles.paused_by)
                .. " - only they can resume it (re-attaching only makes sense for "
                .. "whoever was actually detached from their own tank)."
        end
        return do_resume(name, player, lightcycles.players[name])
    end

    if lobby_system.state.phase ~= "playing" then
        return false, "No match is currently in progress."
    end

    local pdata = lightcycles.players[name]
    if not (pdata and pdata.alive) then
        return false, "You need to be an active player in the current "
            .. "match to use this - it's specifically for pausing "
            .. "mid-race, not for spectating."
    end

    return do_pause(name, player, pdata)
end

minetest.register_chatcommand("btpause", {
    description = "Admin-only: pause the current match (freezes every "
        .. "racer in place, nobody can be eliminated or collide with "
        .. "anything while paused) and grants yourself fly/fast/noclip so "
        .. "you can move the camera around freely - e.g. to line up a "
        .. "screenshot. Run again to resume. Can also be triggered by "
        .. "pressing the Zoom key",
    func = function(name)
        if not minetest.check_player_privs(name, { lobby_admin = true }) then
            return false, "Needs the lobby_admin priv."
        end
        return lightcycles.toggle_pause(name)
    end,
})

local was_zoom_pressed = {} -- name -> bool, edge-trigger tracking

minetest.register_globalstep(function(_dtime)
    for name, pdata in pairs(lightcycles.players) do
        if not pdata.is_bot and pdata.alive and minetest.check_player_privs(name, { lobby_admin = true }) then
            local player = minetest.get_player_by_name(name)
            if player then
                local controls = player:get_player_control()
                if controls.zoom and not was_zoom_pressed[name] then
                    lightcycles.toggle_pause(name)
                end
                was_zoom_pressed[name] = controls.zoom
            end
        end
    end
end)
minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    if lightcycles.paused and lightcycles.paused_by == name then
        lightcycles.paused = false
        lightcycles.paused_by = nil
        minetest.chat_send_all("[Lightcycles] " .. name
            .. " disconnected while paused - match resumed automatically.")
    end
end)
