--
local function face_textures(color)
    return {
        "lightcycles_cycle_" .. color .. "_top.png",    -- Y+
        "lightcycles_cycle_" .. color .. "_bottom.png", -- Y-
        "lightcycles_cycle_" .. color .. "_right.png",  -- X+
        "lightcycles_cycle_" .. color .. "_left.png",   -- X-
        "lightcycles_cycle_" .. color .. "_back.png",   -- Z-
        "lightcycles_cycle_" .. color .. "_front.png",  -- Z+
    }
end

minetest.register_entity("lightcycles:cycle", {
    initial_properties = {
        visual = "cube",
        visual_size = { x = 0.6, y = 1.0, z = 1.0 },
        textures = face_textures("red"),
        collisionbox = { -0.45, -0.25, -0.65, 0.45, 0.25, 0.65 },
        physical = false, -- no engine collision - we do our own node-based checks
        collide_with_objects = false,
        pointable = false,
        static_save = false, -- never persisted; always (re)spawned by the game itself
        glow = 10,
    },

    on_activate = function(self)
        self.object:set_armor_groups({ immortal = 1 })
        self.object:set_acceleration({ x = 0, y = 0, z = 0 })
    end,
})

function lightcycles.spawn_cycle(player, pdata, color, pos, yaw)
    local obj = minetest.add_entity(pos, "lightcycles:cycle")
    if not obj then return nil end
    obj:set_properties({ textures = face_textures(color) })
    obj:set_yaw(yaw)
    local off = lightcycles.settings.cycle_attach_offset
    player:set_attach(obj, "", { x = off.x, y = off.y, z = off.z }, { x = 0, y = 0, z = 0 })
    player:set_eye_offset({ x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 0 })

    pdata.saved_eye_height = player:get_properties().eye_height
    player:set_properties({ eye_height = lightcycles.settings.cycle_eye_height })

    lobby_system.hide_player_body(player)
    if not lightcycles.names_hidden then
        lobby_system.show_nametag(player)
    end

    player:set_look_horizontal(yaw)
    player:set_look_vertical(0)
    return obj
end

function lightcycles.despawn_cycle(player, pdata)
    if player then
        player:set_detach()
        if pdata and pdata.saved_eye_height then
            player:set_properties({ eye_height = pdata.saved_eye_height })
        end
    end
    if pdata and pdata.cycle_obj then
        pcall(function() pdata.cycle_obj:remove() end)
        pdata.cycle_obj = nil
    end
end

function lightcycles.spawn_bot_cycle(name, color, pos, yaw)
    local obj = minetest.add_entity(pos, "lightcycles:cycle")
    if not obj then return nil end
    obj:set_properties({
        textures = face_textures(color),
        nametag = lightcycles.names_hidden and "" or name,
        nametag_color = "#FFFFFF",
    })
    obj:set_yaw(yaw)
    return obj
end

function lightcycles.spawn_crash_effect(pos, color)
    local S = lightcycles.settings.crash_effect
    minetest.add_particlespawner({
        amount = S.amount,
        time = S.time,
        minpos = vector.add(pos, { x = -0.3, y = -0.1, z = -0.3 }),
        maxpos = vector.add(pos, { x = 0.3, y = 0.5, z = 0.3 }),
        minvel = { x = -S.speed, y = S.speed * 0.4, z = -S.speed },
        maxvel = { x = S.speed, y = S.speed, z = S.speed },
        minacc = { x = 0, y = -9, z = 0 },
        maxacc = { x = 0, y = -9, z = 0 },
        minexptime = S.min_lifetime,
        maxexptime = S.max_lifetime,
        minsize = S.min_size,
        maxsize = S.max_size,
        texture = "lightcycles_wall_" .. color .. "_side.png",
        glow = 12,
        collisiondetection = false,
    })
end
