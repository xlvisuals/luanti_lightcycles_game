
for _, color in ipairs(lightcycles.settings.colors) do
    minetest.register_node("lightcycles:wall_" .. color, {
        description = "Lightcycle Trail (" .. color .. ")",
        tiles = {
            "lightcycles_wall_" .. color .. "_top.png",
            "lightcycles_wall_" .. color .. "_side.png",
        },
        light_source = 8,
        groups = { lightcycles_wall = 1, cracky = 3, not_in_creative_inventory = 1 },
        is_ground_content = false,
        sounds = {},
    })
end

minetest.register_node("lightcycles:floor", {
    description = "Lightcycle Arena Floor",
    tiles = { lightcycles.settings.tiles.arena_boundary_blue },
    groups = { lightcycles_wall = 1, cracky = 3, not_in_creative_inventory = 1 },
    is_ground_content = false,
    light_source = 4,
    can_dig = function(pos, digger)
        if not digger then return false end
        return lightcycles.is_build_mode_on(digger:get_player_name())
    end,
})

minetest.register_node("lightcycles:boundary", {
    description = "Lightcycle Arena Boundary (blue)",
    tiles = { lightcycles.settings.tiles.arena_boundary_blue },
    groups = { lightcycles_wall = 1, cracky = 3, not_in_creative_inventory = 1 },
    is_ground_content = false,
    light_source = 4,
    can_dig = function(pos, digger)
        if not digger then return false end
        return lightcycles.is_build_mode_on(digger:get_player_name())
    end,
})

minetest.register_node("lightcycles:boundary_silver", {
    description = "Lightcycle Arena Boundary (silver)",
    tiles = { lightcycles.settings.tiles.arena_boundary_silver },
    groups = { lightcycles_wall = 1, cracky = 3, not_in_creative_inventory = 1 },
    is_ground_content = false,
    light_source = 4,
    can_dig = function(pos, digger)
        if not digger then return false end
        return lightcycles.is_build_mode_on(digger:get_player_name())
    end,
})

minetest.register_node("lightcycles:boundary_blue", {
    description = "Lightcycle Arena Boundary (Blue)",
    tiles = { lightcycles.settings.tiles.arena_boundary_blue },
    groups = { lightcycles_wall = 1, cracky = 3, not_in_creative_inventory = 1 },
    is_ground_content = false,
    light_source = 4,
    can_dig = function(pos, digger)
        if not digger then return false end
        return lightcycles.is_build_mode_on(digger:get_player_name())
    end,
})

for n = 1, 8 do
    minetest.register_node("lightcycles:spawnpad_" .. n, {
        description = "Lightcycle Spawn Point " .. n .. " (place facing the direction that racer should start moving)",
        tiles = { "lightcycles_spawnpad_" .. n .. ".png" },
        paramtype2 = "facedir",
        groups = { cracky = 3, not_in_creative_inventory = 1 },
        is_ground_content = false,
        light_source = 4,
        walkable = true,
        can_dig = function(pos, digger)
            if not digger then return false end
            return lightcycles.is_build_mode_on(digger:get_player_name())
        end,
        after_place_node = function(pos, placer)
            if placer and placer:is_player() then
                local param2 = minetest.dir_to_facedir(placer:get_look_dir())
                minetest.swap_node(pos, { name = "lightcycles:spawnpad_" .. n, param2 = param2 })
            end
        end,
    })
end


minetest.register_node("lightcycles:powerup_point_spawner", {
    description = "Lightcycle Point Powerup Spawner (level-designer placed, admin/build-mode only to dig)",
    tiles = { "lightcycles_powerup_point.png" },
    walkable = false,
    light_source = 6, -- dimmer than the actual in-match collectible, so the two read differently
    groups = { cracky = 3, not_in_creative_inventory = 1 },
    is_ground_content = false,
    can_dig = function(pos, digger)
        if not digger then return false end
        return lightcycles.is_build_mode_on(digger:get_player_name())
    end,
})

minetest.register_node("lightcycles:powerup_point", {
    description = "Lightcycle Point Powerup (spawned automatically at match start, never placed by hand)",
    tiles = { "lightcycles_powerup_point.png" },
    walkable = false,
    light_source = 12,
    groups = { cracky = 3, not_in_creative_inventory = 1 },
    is_ground_content = false,
    can_dig = function(pos, digger)
        if not digger then return false end
        return lightcycles.is_build_mode_on(digger:get_player_name())
    end,
})

minetest.register_node("lightcycles:powerup_boost", {
    description = "Lightcycle Boost Powerup (spawned automatically, never placed by hand)",
    tiles = { "lightcycles_powerup_boost.png" },
    walkable = false,
    light_source = 12,
    groups = { cracky = 3, not_in_creative_inventory = 1 },
    is_ground_content = false,
    can_dig = function(pos, digger)
        if not digger then return false end
        return lightcycles.is_build_mode_on(digger:get_player_name())
    end,
})

minetest.register_node("lightcycles:powerup_shield", {
    description = "Lightcycle Shield Powerup (spawned automatically, never placed by hand)",
    tiles = { "lightcycles_powerup_shield.png" },
    walkable = false,
    light_source = 12,
    groups = { cracky = 3, not_in_creative_inventory = 1 },
    is_ground_content = false,
    can_dig = function(pos, digger)
        if not digger then return false end
        return lightcycles.is_build_mode_on(digger:get_player_name())
    end,
})

minetest.register_node("lightcycles:powerup_laser", {
    description = "Lightcycle Laser Powerup (spawned automatically, never placed by hand)",
    tiles = { "lightcycles_powerup_laser.png" },
    walkable = false,
    light_source = 12,
    groups = { cracky = 3, not_in_creative_inventory = 1 },
    is_ground_content = false,
    can_dig = function(pos, digger)
        if not digger then return false end
        return lightcycles.is_build_mode_on(digger:get_player_name())
    end,
})

minetest.register_node("lightcycles:powerup_rocket", {
    description = "Lightcycle Rocket Powerup (spawned automatically, never placed by hand)",
    tiles = { "lightcycles_powerup_rocket.png" },
    walkable = false,
    light_source = 12,
    groups = { cracky = 3, not_in_creative_inventory = 1 },
    is_ground_content = false,
    can_dig = function(pos, digger)
        if not digger then return false end
        return lightcycles.is_build_mode_on(digger:get_player_name())
    end,
})
