
lightcycles_stats = rawget(_G, "lightcycles_stats") or {}

local FORMNAME = "lightcycles_stats:highscores"
local HEADER_COLOR = "#FFD700"

local function header_cell(text)
    return minetest.formspec_escape(minetest.colorize(HEADER_COLOR, text))
end

local function header_row(labels)
    local cells = {}
    for i, label in ipairs(labels) do
        local text = (i < #labels) and (label .. " |") or label
        table.insert(cells, header_cell(text))
    end
    return cells
end

local function cell(text)
    return minetest.formspec_escape(tostring(text))
end

local function pct_cell(pct)
    if not pct then return "--" end
    return string.format("%.0f%%", pct)
end

local function duration_cell(seconds)
    return tostring(seconds) .. "s"
end

local MP_COLUMNS = 6
local SOLO_COLUMNS = 4

local function mp_table_rows()
    local rows = header_row({
        "Player Name", "Games Played", "Games Won", "Total Points", "Laser Hit %", "Rocket Hit %",
    })

    local leaderboard = lightcycles_stats.get_multiplayer_leaderboard()
    if #leaderboard == 0 then
        table.insert(rows, cell("(no multiplayer races recorded yet)"))
        for _ = 2, MP_COLUMNS do table.insert(rows, cell("")) end
    else
        for _, entry in ipairs(leaderboard) do
            table.insert(rows, cell(entry.name))
            table.insert(rows, cell(entry.stats.games_played))
            table.insert(rows, cell(entry.stats.games_won))
            table.insert(rows, cell(entry.stats.total_points))
            table.insert(rows, pct_cell(entry.laser_hit_percent))
            table.insert(rows, pct_cell(entry.rocket_hit_percent))
        end
    end

    return table.concat(rows, ",")
end

local function solo_table_rows()
    local rows = header_row({
        "Player Name", "Map Name", "Point Powerups Collected", "Match Duration",
    })

    local leaderboard = lightcycles_stats.get_solo_leaderboard()
    if #leaderboard == 0 then
        table.insert(rows, cell("(no soloplayer runs recorded yet)"))
        for _ = 2, SOLO_COLUMNS do table.insert(rows, cell("")) end
    else
        for _, r in ipairs(leaderboard) do
            table.insert(rows, cell(r.player_name))
            table.insert(rows, cell(r.map_display))
            table.insert(rows, cell(r.points))
            table.insert(rows, duration_cell(r.duration))
        end
    end

    return table.concat(rows, ",")
end

local function highscores_formspec()
    return table.concat({
        "formspec_version[4]",
        "size[13.6,12.3]",
        "bgcolor[#000000AD]", -- Background. Default is bgcolor[#000000AA]
        "label[0.4,0.5;Lightcycles - High Scores]",
        "button_exit[11.4,0.3;2,0.6;lcs_close;Close]",

        "label[0.4,1.25;Multiplayer (sorted by Total Points)]",
        "tablecolumns[text,align=left;text,align=center;text,align=center;"
            .. "text,align=center;text,align=center;text,align=center]",
        "table[0.4,1.65;12.8,4.55;lcs_mp_table;" .. mp_table_rows() .. ";0]",

        "label[0.4,6.55;Soloplayer (sorted by fastest clear time)]",
        "tablecolumns[text,align=left;text,align=left;text,align=center;text,align=center]",
        "table[0.4,6.95;12.8,4.85;lcs_solo_table;" .. solo_table_rows() .. ";0]",
    }, "")
end

function lightcycles_stats.show(name)
    minetest.show_formspec(name, FORMNAME, highscores_formspec())
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= FORMNAME then return end
    local name = player:get_player_name()
    lobby_system.gui.show(name)
    return true
end)
