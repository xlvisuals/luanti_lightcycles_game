
lightcycles.sounds = {}

local S = lightcycles.settings.sound
local engine_handles = {}

function lightcycles.sounds.start_engine_loop(obj, name, pitch)
    if engine_handles[name] then return end
    engine_handles[name] = minetest.sound_play("lightcycle_loop", {
        object = obj, gain = S.engine_gain, loop = true,
        max_hear_distance = S.engine_max_hear_distance,
        pitch = pitch or S.engine_pitch_normal,
    })
end

function lightcycles.sounds.set_engine_pitch(obj, name, pitch)
    if engine_handles[name] then
        minetest.sound_stop(engine_handles[name])
        engine_handles[name] = nil
    end
    lightcycles.sounds.start_engine_loop(obj, name, pitch)
end

function lightcycles.sounds.stop_engine_loop(name)
    if engine_handles[name] then
        minetest.sound_stop(engine_handles[name])
        engine_handles[name] = nil
    end
end

function lightcycles.sounds.play_point_pickup(pos)
    minetest.sound_play("pickup_point", {
        pos = pos, gain = S.pickup_gain, max_hear_distance = S.pickup_max_hear_distance,
    }, true)
end

function lightcycles.sounds.play_boost_pickup(pos)
    minetest.sound_play("pickup_boost", {
        pos = pos, gain = S.pickup_gain, max_hear_distance = S.pickup_max_hear_distance,
    }, true)
end

function lightcycles.sounds.play_shield_pickup(pos)
    minetest.sound_play("pickup_shield", {
        pos = pos, gain = S.pickup_gain, max_hear_distance = S.pickup_max_hear_distance,
    }, true)
end

function lightcycles.sounds.play_shield_break(pos)
    minetest.sound_play("shield_break", {
        pos = pos, gain = S.pickup_gain, max_hear_distance = S.pickup_max_hear_distance,
    }, true)
end

function lightcycles.sounds.play_ammo_pickup(pos)
    minetest.sound_play("pickup_ammo", {
        pos = pos, gain = S.pickup_gain, max_hear_distance = S.pickup_max_hear_distance,
    }, true)
end

function lightcycles.sounds.play_shoot(pos)
    minetest.sound_play("shoot", {
        pos = pos, gain = S.pickup_gain, max_hear_distance = S.pickup_max_hear_distance,
    }, true)
end

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    if engine_handles[name] then
        minetest.sound_stop(engine_handles[name])
        engine_handles[name] = nil
    end
end)
