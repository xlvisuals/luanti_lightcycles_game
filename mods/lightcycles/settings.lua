lightcycles = rawget(_G, "lightcycles") or {}

math.randomseed(os.time())


lightcycles.settings = {

    title                         = "Lightcycles v1.0.1",

    arena_center                  = { x = 0, y = 50, z = 0 }, -- built well above ground, self-contained
    arena_size                    = 101,                      -- floor is arena_size x arena_size (101x101) - needs to be uneven for fair distances
    wall_height                   = 10,                       -- height of the surrounding brick wall + trail walls
    floor_y_offset                = 0,                        -- floor sits at arena_center.y
    arena_apron                   = 10,                       -- extra flat stone margin built around the walled

    map_work_area = {
        min = { x = -100, y = 50, z = -100 },
        max = { x = 100, y = 100, z = 100 },
    },

    spawn_point_offsets = {
        { x = 0,   z = -40, dir_x = 0,  dir_z = 1 },  -- 1: north wall, center   -> faces south (opposite wall)
        { x = 0,   z = 40,  dir_x = 0,  dir_z = -1 }, -- 2: south wall, center   -> faces north (opposite wall)
        { x = -40, z = 0,   dir_x = 1,  dir_z = 0 },  -- 3: west wall, center    -> faces east (opposite wall)
        { x = 40,  z = 0,   dir_x = -1, dir_z = 0 },  -- 4: east wall, center    -> faces west (opposite wall)
        { x = 40,  z = -40, dir_x = 0,  dir_z = 1 },  -- 5: northeast corner     -> faces south
        { x = -40, z = 40,  dir_x = 0,  dir_z = -1 }, -- 6: southwest corner     -> faces north
        { x = -40, z = -40, dir_x = 1,  dir_z = 0 },  -- 7: northwest corner     -> faces east
        { x = 40,  z = 40,  dir_x = -1, dir_z = 0 },  -- 8: southeast corner     -> faces west
    },

    default_point_powerup_offsets = {
        { 0, 0 },
        { 10, 10 }, { 10, -10 }, { -10, 10 }, { -10, -10 },
        { 23, 23 }, { 23, -23 }, { -23, 23 }, { -23, -23 },
    },

    tiles                     = {
        arena_floor = "lightcycles_tile_blue.png",  -- floor tile
        arena_wall  = "lightcycles_tile_blue.png",  -- wall tile
    },

    cycle_attach_offset       = { x = -5, y = 6, z = 5 },

    cycle_eye_height          = 1.0,

    base_speed                = 6,    -- nodes/second, normal cruising speed
    boost_delta               = 0.30, -- +/-30% speed while boosting, or while braking with the bar not yet full - applied instantly on press/release, same as a turn
    boost_full_delta          = 0.15, -- +/-15% speed while braking with a full bar
    boost_time                = 8,    -- seconds to fully fill or fully drain the bar

    trail_check_ahead         = 0.35, -- how far ahead (nodes) to look for collisions each step

    mutual_elimination_grace  = 0.2,

    match_max_duration        = 180,

    remove_walls_on_eliminate = false,

    night_time_of_day         = 0.2,

    sky_color                 = "#101010",

    sound                     = {
        engine_gain = 0.5,
        engine_max_hear_distance = 24,
        engine_pitch_normal = 1.0,
        engine_pitch_brake = 0.8,
        engine_pitch_boost = 1.3,
        pickup_gain = 0.8,
        pickup_max_hear_distance = 20,
    },

    colors                    = { "red", "blue", "green", "yellow", "orange", "purple", "cyan", "white" },

    crash_effect              = {
        amount = 40,        -- number of spark particles in the burst
        time = 0.15,        -- how long the spawner stays active (short = instant burst)
        speed = 4,          -- outward velocity range (nodes/sec)
        min_lifetime = 0.3, -- seconds each spark exists for
        max_lifetime = 0.9,
        min_size = 0.8,
        max_size = 2.2,
    },

    placement_points             = { 25, 18, 15, 12, 10, 8, 6, 4, 2, 1 },

    point_powerups_enabled    = true,
    boost_powerups_enabled    = true,
    shield_powerups_enabled   = true,
    ammo_powerups_enabled     = true,
    point_powerup_value       = 3,  -- bonus match points awarded on pickup
    boost_powerup_interval    = 10, -- seconds between boost powerup spawn attempts
    boost_powerup_lifetime    = 20, -- seconds a spawned boost powerup lasts before vanishing unclaimed
    shield_powerup_interval   = 20, -- seconds between shield powerup spawn attempts (rarer than boost - see design note in powerups.lua)
    shield_powerup_lifetime   = 20, -- seconds a spawned shield powerup lasts before vanishing unclaimed
    ammo_powerup_interval     = 20, -- seconds between ammo powerup spawn attempts
    ammo_powerup_lifetime     = 20, -- seconds a spawned ammo powerup lasts before vanishing unclaimed
    ammo_per_pickup           = 2,  -- shots granted per ammo powerup collected

    shot_speed_multiplier     = 3,   -- laser bolt speed, as a multiple of base_speed
    shot_cooldown             = 0.5, -- minimum seconds between shots, per racer
    shot_lifetime             = 6,   -- seconds a bolt travels before despawning unclaimed (comfortably longer than crossing the whole arena)
    kill_by_shot_points       = 5,   -- bonus match points for eliminating another racer with a shot (on top of their own placement points)

    starting_ammo             = 1, -- shots
    starting_shield           = 1, -- charges (each one breaks through one trail wall)
    starting_boost            = 30, -- bar charge, 0-100



    matches_per_session       = 5,

    bot_count                 = 0,
    bot_behavior              = "random",

    build_tool_range          = 10,
}

lightcycles.racers = {}

lightcycles.storage = minetest.get_mod_storage()
