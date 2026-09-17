
local modpath = minetest.get_modpath("lightcycles_stats")

lightcycles_stats = rawget(_G, "lightcycles_stats") or {}

dofile(modpath .. "/storage.lua")
dofile(modpath .. "/api.lua")
dofile(modpath .. "/gui.lua")

minetest.register_on_mods_loaded(function()
    local g = lobby_system.state.game
    if g then
        g.show_highscores = lightcycles_stats.show
    else
        minetest.log("warning", "[lightcycles_stats] No lobby_system game registered - "
            .. "High Scores button not added.")
    end
end)

minetest.log("action", "[lightcycles_stats] mod loaded")
