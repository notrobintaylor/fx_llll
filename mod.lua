-- =========================================================================
-- fx_llll — four lines
-- a creative multitap delay with modulation and events
-- for the norns fx mod framework
-- =========================================================================

local fx = require("fx/lib/fx")
local mod = require 'core/mods'
local hook = require 'core/hook'
local tab = require 'tabutil'

-- post-init hack
if hook.script_post_init == nil and mod.hook.patched == nil then
    mod.hook.patched = true
    local old_register = mod.hook.register
    local post_init_hooks = {}
    mod.hook.register = function(h, name, f)
        if h == "script_post_init" then
            post_init_hooks[name] = f
        else old_register(h, name, f) end
    end
    mod.hook.register('script_pre_init', '!replace init for fake post init', function()
        local old_init = init
        init = function()
            old_init()
            for i, k in ipairs(tab.sort(post_init_hooks)) do
                local cb = post_init_hooks[k]
                local ok, err = pcall(cb)
                if not ok then print('hook: ' .. k .. ' failed: ' .. err) end
            end
        end
    end)
end

local FxLlll = fx:new{ subpath = "/fx_llll" }

-- =========================================================================
-- constants
-- =========================================================================

local MAX_DELAY = 1
local FEEDBACK_MAX = 1.05  -- 105%

local subdiv_names = {"1/1","1/2","1/4","1/8","1/16","1/32","1/64"}
local subdiv_beats = {4, 2, 1, 0.5, 0.25, 0.125, 0.0625}

local feel_names = {"note", "dotted", "triplet", "msec"}
local feel_mults = {1.0, 1.5, 2/3}

local filter_type_names = {"low", "band", "high"}
local filter_slope_names = {"6 dB", "12 dB", "24 dB", "48 dB"}

local mod_rate_names = {"1/1","1/2","1/4","1/8","1/16"}
local mod_rate_beats = {4, 2, 1, 0.5, 0.25}

local TARGET = {
    CHORUS_DEPTH=1, CHORUS_RATE=2, FEEDBACK=3, FILTER=4,
    SATURATION=5, SEND_LEVEL=6, SUBDIV=7,
    TAP_LEVEL=8, TAP_PAN=9, TAP_TIME=10
}
local target_names = {
    "chorus depth","chorus rate","feedback","filter",
    "saturation","send level","subdiv",
    "tap level","tap pan","tap time"
}

local dir_names = {"+", "-", "+ & -"}

local event_rate_names = {
    "8/1","4/1","2/1","1/1","1/2","1/4","1/8","1/16","1/32","1/64"
}
local event_rate_beats = {32, 16, 8, 4, 2, 1, 0.5, 0.25, 0.125, 0.0625}
local event_action_names = {
    "nothing","flip pans","mute taps","all fb min",
    "all fb max","change -5%","change -10%","change -25%"
}

-- =========================================================================
-- state
-- =========================================================================

local turing = {
    register=0, steps=0, target=TARGET.SUBDIV, prev_target=TARGET.SUBDIV,
    depth=100, direction=-1, probability=50, clock_div=3,
    range_low=3, range_high=6,
}

local event_state = {
    active=false, clock_id=nil, action=1, rate=4,
    saved_prob=0,
}

local base = {
    inputGain=1.0,
    filterFreq=2500, filterFreqBottom=250, filterFreqTop=2500,
    saturation=0, chorusDepth=0, chorusRate=1.0,
}
for i=1,4 do
    base["feedback"..i] = 0.50
    base["level"..i] = ({1.0, 0.75, 0.5, 0.25})[i]
    base["pan"..i] = ({-0.5, 0.5, -0.5, 0.5})[i]
    base["time"..i] = 0
end

local tm_clock_id, tempo_clock_id, last_tempo = nil, nil, 0

-- =========================================================================
-- helpers
-- =========================================================================

local function send(key, val)
    osc.send({"localhost", 57120}, "/fx_llll/set", {key, val})
end

local function tm_active() return turing.steps > 0 end

local function reg_max()
    if turing.steps <= 0 then return 0 end
    return (1 << turing.steps) - 1
end

local function tap_mod(i)
    local m = reg_max()
    if m == 0 then return 0 end
    local r = ((turing.register >> i) | (turing.register << (turing.steps - i))) & m
    return r / m
end

local function apply_mod(raw, bv, lo, hi)
    local d = turing.depth / 100
    local dir = turing.direction
    if dir == 1 then return bv + (hi - bv) * raw * d
    elseif dir == -1 then return bv - (bv - lo) * raw * d
    else
        local bp = (raw * 2 - 1) * d
        if bp >= 0 then return bv + (hi - bv) * bp
        else return bv + (bv - lo) * bp end
    end
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- =========================================================================
-- delay time
-- =========================================================================

local function beat_sec() return 60 / clock.get_tempo() end

local function update_tap(i)
    if tm_active() and (turing.target == TARGET.SUBDIV or turing.target == TARGET.TAP_TIME) then return end
    local feel = params:get("fx_ll_feel_"..i)
    local t
    if feel == 4 then
        t = math.min(params:get("fx_ll_time_"..i) / 1000, MAX_DELAY)
    else
        t = math.min(subdiv_beats[params:get("fx_ll_subdiv_"..i)] * beat_sec() * feel_mults[feel], MAX_DELAY)
    end
    base["time"..i] = t
    send("time"..i, t)
end

local function update_all_taps() for i=1,4 do update_tap(i) end end

-- =========================================================================
-- turing machine
-- =========================================================================

local function tm_subdiv()
    for i=1,4 do
        local feel = params:get("fx_ll_feel_"..i)
        if feel == 4 then send("time"..i, base["time"..i])
        else
            local m = reg_max(); if m == 0 then return end
            local rot = ((turing.register >> i) | (turing.register << (turing.steps - i))) & m
            local rng = turing.range_high - turing.range_low + 1
            local sd = rng <= 0 and turing.range_low or (turing.range_low + (rot % rng))
            send("time"..i, math.min(subdiv_beats[sd] * beat_sec() * feel_mults[feel], MAX_DELAY))
        end
    end
end

local function restore(t)
    if t == TARGET.SUBDIV or t == TARGET.TAP_TIME then update_all_taps()
    elseif t == TARGET.SEND_LEVEL then send("inputGain", base.inputGain)
    elseif t == TARGET.FILTER then
        send("filterFreq", base.filterFreq)
        send("filterFreqBottom", base.filterFreqBottom)
        send("filterFreqTop", base.filterFreqTop)
    elseif t == TARGET.FEEDBACK then
        for i=1,4 do send("feedback"..i, base["feedback"..i]) end
    elseif t == TARGET.TAP_LEVEL then
        for i=1,4 do send("level"..i, base["level"..i]) end
    elseif t == TARGET.TAP_PAN then
        for i=1,4 do send("pan"..i, base["pan"..i]) end
    elseif t == TARGET.CHORUS_DEPTH then send("chorusDepth", base.chorusDepth)
    elseif t == TARGET.CHORUS_RATE then send("chorusRate", base.chorusRate)
    elseif t == TARGET.SATURATION then send("saturation", base.saturation)
    end
end

local function tm_apply()
    if not tm_active() then return end
    local m = reg_max(); if m == 0 then return end
    local t = turing.target
    local raw = turing.register / m

    if t == TARGET.SUBDIV then tm_subdiv(); return end
    if t == TARGET.TAP_TIME then
        for i=1,4 do
            send("time"..i, clamp(apply_mod(tap_mod(i), base["time"..i], 0.001, MAX_DELAY), 0.001, MAX_DELAY))
        end
    elseif t == TARGET.SEND_LEVEL then
        send("inputGain", clamp(apply_mod(raw, 1.0, 0, 2.0), 0, 2))
    elseif t == TARGET.FILTER then
        send("filterFreq", clamp(apply_mod(raw, base.filterFreq, 20, 20000), 20, 20000))
        send("filterFreqBottom", clamp(apply_mod(raw, base.filterFreqBottom, 20, 20000), 20, 20000))
        send("filterFreqTop", clamp(apply_mod(raw, base.filterFreqTop, 20, 20000), 20, 20000))
    elseif t == TARGET.FEEDBACK then
        for i=1,4 do
            send("feedback"..i, clamp(apply_mod(tap_mod(i), base["feedback"..i], 0, FEEDBACK_MAX), 0, FEEDBACK_MAX))
        end
    elseif t == TARGET.TAP_LEVEL then
        for i=1,4 do
            send("level"..i, clamp(apply_mod(tap_mod(i), base["level"..i], 0, 1), 0, 1))
        end
    elseif t == TARGET.TAP_PAN then
        for i=1,4 do
            send("pan"..i, clamp(apply_mod(tap_mod(i), base["pan"..i], -1, 1), -1, 1))
        end
    elseif t == TARGET.CHORUS_DEPTH then
        send("chorusDepth", clamp(apply_mod(raw, base.chorusDepth, 0, 100), 0, 100))
    elseif t == TARGET.CHORUS_RATE then
        send("chorusRate", clamp(apply_mod(raw, base.chorusRate, 0.01, 10000), 0.01, 10000))
    elseif t == TARGET.SATURATION then
        send("saturation", clamp(apply_mod(raw, base.saturation, 0, 1), 0, 1))
    end
end

local function tm_step()
    if not tm_active() then return end
    local m = reg_max()
    local msb = (turing.register >> (turing.steps - 1)) & 1
    turing.register = (turing.register << 1) & m
    if math.random(100) <= turing.probability then
        turing.register = turing.register | (1 - msb)
    else turing.register = turing.register | msb end
    tm_apply()
end

-- =========================================================================
-- event system
-- =========================================================================

local function evt_do()
    local a = event_state.action
    if a == 1 then return end
    if a == 2 then for i=1,4 do send("pan"..i, -base["pan"..i]) end
    elseif a == 3 then for i=1,4 do send("level"..i, 0) end
    elseif a == 4 then for i=1,4 do send("feedback"..i, 0) end
    elseif a == 5 then for i=1,4 do send("feedback"..i, FEEDBACK_MAX) end
    elseif a == 6 then event_state.saved_prob = turing.probability; turing.probability = math.max(0, turing.probability - 5)
    elseif a == 7 then event_state.saved_prob = turing.probability; turing.probability = math.max(0, turing.probability - 10)
    elseif a == 8 then event_state.saved_prob = turing.probability; turing.probability = math.max(0, turing.probability - 25)
    end
end

local function evt_undo()
    local a = event_state.action
    if a == 1 then return end
    if a == 2 then for i=1,4 do send("pan"..i, base["pan"..i]) end
    elseif a == 3 then for i=1,4 do send("level"..i, base["level"..i]) end
    elseif a == 4 or a == 5 then for i=1,4 do send("feedback"..i, base["feedback"..i]) end
    elseif a >= 6 then turing.probability = event_state.saved_prob end
end

local function start_evt_clock()
    if event_state.clock_id then clock.cancel(event_state.clock_id); event_state.clock_id = nil end
    if event_state.action == 1 then return end
    event_state.clock_id = clock.run(function()
        while true do
            clock.sync(event_rate_beats[event_state.rate])
            if event_state.active then evt_undo(); event_state.active = false
            else evt_do(); event_state.active = true end
        end
    end)
end

-- =========================================================================
-- clock management
-- =========================================================================

local function start_tm_clock()
    if tm_clock_id then clock.cancel(tm_clock_id); tm_clock_id = nil end
    if not tm_active() then return end
    tm_clock_id = clock.run(function()
        while true do clock.sync(mod_rate_beats[turing.clock_div]); tm_step() end
    end)
end

local function start_tempo_watch()
    if tempo_clock_id then clock.cancel(tempo_clock_id); tempo_clock_id = nil end
    last_tempo = clock.get_tempo()
    tempo_clock_id = clock.run(function()
        while true do
            clock.sleep(0.2)
            local t = clock.get_tempo()
            if t ~= last_tempo then
                last_tempo = t
                if tm_active() and turing.target == TARGET.SUBDIV then tm_subdiv()
                elseif tm_active() and turing.target == TARGET.TAP_TIME then
                    for i=1,4 do
                        local feel = params:get("fx_ll_feel_"..i)
                        if feel ~= 4 then
                            base["time"..i] = math.min(
                                subdiv_beats[params:get("fx_ll_subdiv_"..i)] * beat_sec() * feel_mults[feel], MAX_DELAY)
                        end
                    end
                else update_all_taps() end
            end
        end
    end)
end

local function cleanup()
    if tm_clock_id then clock.cancel(tm_clock_id); tm_clock_id = nil end
    if tempo_clock_id then clock.cancel(tempo_clock_id); tempo_clock_id = nil end
    if event_state.clock_id then clock.cancel(event_state.clock_id); event_state.clock_id = nil end
end

-- =========================================================================
-- visibility
-- =========================================================================

local function vis_tap(i)
    if params:get("fx_ll_feel_"..i) == 4 then
        params:show("fx_ll_time_"..i); params:hide("fx_ll_subdiv_"..i)
    else
        params:hide("fx_ll_time_"..i); params:show("fx_ll_subdiv_"..i)
    end
    _menu.rebuild_params()
end

local function vis_filter()
    if params:get("fx_ll_filter_type") == 2 then
        params:hide("fx_ll_filter_freq")
        params:show("fx_ll_filter_freq_bottom"); params:show("fx_ll_filter_freq_top")
    else
        params:show("fx_ll_filter_freq")
        params:hide("fx_ll_filter_freq_bottom"); params:hide("fx_ll_filter_freq_top")
    end
    _menu.rebuild_params()
end

local function vis_tm()
    if turing.target == TARGET.SUBDIV then
        params:hide("fx_ll_tm_mod_depth"); params:hide("fx_ll_tm_mod_dir")
        params:show("fx_ll_tm_mod_bottom"); params:show("fx_ll_tm_mod_top")
    else
        params:show("fx_ll_tm_mod_depth"); params:show("fx_ll_tm_mod_dir")
        params:hide("fx_ll_tm_mod_bottom"); params:hide("fx_ll_tm_mod_top")
    end
    _menu.rebuild_params()
end

-- =========================================================================
-- parameters
-- =========================================================================

function FxLlll:add_params()

    -- slot --
    params:add_separator("fx_ll", "fx llll")
    FxLlll:add_slot("fx_ll_slot", "slot")

    -- taps --
    params:add_separator("fx_ll_taps", "taps")

    local default_subdivs = {1, 2, 3, 4}  -- 1/1, 1/2, 1/4, 1/8
    local default_levels = {100, 75, 50, 25}
    local default_fb = {50, 50, 50, 50}
    local default_pans = {-0.5, 0.5, -0.5, 0.5}
    local default_msec = {1000, 500, 250, 125}

    for i=1,4 do
        -- feedback (0–105%)
        params:add_control("fx_ll_feedback_"..i, "tap "..i.." feedback",
            controlspec.new(0, 105, 'lin', 1, default_fb[i], "%"))
        params:set_action("fx_ll_feedback_"..i, function(v)
            base["feedback"..i] = v / 100
            if not (tm_active() and turing.target == TARGET.FEEDBACK) then
                send("feedback"..i, v / 100)
            end
        end)

        -- feel
        params:add_option("fx_ll_feel_"..i, "tap "..i.." feel", feel_names, 1)
        params:set_action("fx_ll_feel_"..i, function() vis_tap(i); update_tap(i) end)

        -- level (0–100%)
        params:add_control("fx_ll_level_"..i, "tap "..i.." level",
            controlspec.new(0, 100, 'lin', 1, default_levels[i], "%"))
        params:set_action("fx_ll_level_"..i, function(v)
            base["level"..i] = v / 100
            if not (tm_active() and turing.target == TARGET.TAP_LEVEL) then
                send("level"..i, v / 100)
            end
        end)

        -- pan
        params:add_control("fx_ll_pan_"..i, "tap "..i.." pan",
            controlspec.new(-1, 1, 'lin', 0.01, default_pans[i]))
        params:set_action("fx_ll_pan_"..i, function(v)
            base["pan"..i] = v
            if not (tm_active() and turing.target == TARGET.TAP_PAN) then
                send("pan"..i, v)
            end
        end)

        -- subdiv
        params:add_option("fx_ll_subdiv_"..i, "tap "..i.." subdiv", subdiv_names, default_subdivs[i])
        params:set_action("fx_ll_subdiv_"..i, function() update_tap(i) end)

        -- time (ms)
        params:add_control("fx_ll_time_"..i, "tap "..i.." time",
            controlspec.new(1, 1000, 'exp', 1, default_msec[i], "ms"))
        params:set_action("fx_ll_time_"..i, function() update_tap(i) end)
    end

    -- filter --
    params:add_separator("fx_ll_flt", "filter")

    -- "filter type" sorts first alphabetically in the filter section
    params:add_option("fx_ll_filter_type", "filter type", filter_type_names, 1)
    params:set_action("fx_ll_filter_type", function(v)
        send("filterType", v)
        -- reset frequency to musical defaults per type
        if v == 1 then     -- low
            params:set("fx_ll_filter_freq", 2500)
        elseif v == 2 then -- band
            params:set("fx_ll_filter_freq_bottom", 250)
            params:set("fx_ll_filter_freq_top", 2500)
        elseif v == 3 then -- high
            params:set("fx_ll_filter_freq", 250)
        end
        vis_filter()
    end)

    params:add_control("fx_ll_filter_freq", "frequency",
        controlspec.new(20, 20000, 'exp', 0, 2500, "hz"))
    params:set_action("fx_ll_filter_freq", function(v)
        base.filterFreq = v
        if not (tm_active() and turing.target == TARGET.FILTER) then send("filterFreq", v) end
    end)

    params:add_control("fx_ll_filter_freq_bottom", "frequency bottom",
        controlspec.new(20, 20000, 'exp', 0, 250, "hz"))
    params:set_action("fx_ll_filter_freq_bottom", function(v)
        base.filterFreqBottom = v
        if v > base.filterFreqTop then params:set("fx_ll_filter_freq_top", v) end
        if not (tm_active() and turing.target == TARGET.FILTER) then send("filterFreqBottom", v) end
    end)

    params:add_control("fx_ll_filter_freq_top", "frequency top",
        controlspec.new(20, 20000, 'exp', 0, 2500, "hz"))
    params:set_action("fx_ll_filter_freq_top", function(v)
        base.filterFreqTop = v
        if v < base.filterFreqBottom then params:set("fx_ll_filter_freq_bottom", v) end
        if not (tm_active() and turing.target == TARGET.FILTER) then send("filterFreqTop", v) end
    end)

    params:add_option("fx_ll_filter_slope", "slope", filter_slope_names, 2)
    params:set_action("fx_ll_filter_slope", function(v) send("filterSlope", v) end)

    -- saturation --
    params:add_separator("fx_ll_sat", "saturation")

    params:add_control("fx_ll_saturation", "saturation",
        controlspec.new(0, 100, 'lin', 1, 0, "%"))
    params:set_action("fx_ll_saturation", function(v)
        base.saturation = v / 100
        if not (tm_active() and turing.target == TARGET.SATURATION) then send("saturation", v / 100) end
    end)

    -- chorus --
    params:add_separator("fx_ll_ch", "chorus")

    params:add_control("fx_ll_chorus_depth", "depth",
        controlspec.new(0, 100, 'lin', 1, 0, "%"))
    params:set_action("fx_ll_chorus_depth", function(v)
        base.chorusDepth = v
        if not (tm_active() and turing.target == TARGET.CHORUS_DEPTH) then send("chorusDepth", v) end
    end)

    params:add_control("fx_ll_chorus_rate", "rate",
        controlspec.new(0.01, 10000, 'exp', 0, 1.0, "hz"))
    params:set_action("fx_ll_chorus_rate", function(v)
        base.chorusRate = v
        if not (tm_active() and turing.target == TARGET.CHORUS_RATE) then send("chorusRate", v) end
    end)

    -- modulation™ --
    params:add_separator("fx_ll_tm", "modulation\u{2122}")

    params:add_control("fx_ll_tm_change_prob", "change probability",
        controlspec.new(0, 100, 'lin', 1, 50, "%"))
    params:set_action("fx_ll_tm_change_prob", function(v) turing.probability = v end)

    -- "mod assign" sorts before "mod bottom/depth/direction" alphabetically
    params:add_option("fx_ll_tm_mod_assign", "mod assign", target_names, TARGET.SUBDIV)
    params:set_action("fx_ll_tm_mod_assign", function(v)
        if tm_active() then restore(turing.prev_target) end
        turing.prev_target = v; turing.target = v
        vis_tm()
        if tm_active() then
            turing.register = math.random(0, reg_max())
            start_tm_clock()
        end
    end)

    params:add_option("fx_ll_tm_mod_bottom", "mod bottom", subdiv_names, 3)
    params:set_action("fx_ll_tm_mod_bottom", function(v)
        turing.range_low = v
        if turing.range_high < v then turing.range_high = v; params:set("fx_ll_tm_mod_top", v) end
    end)

    params:add_control("fx_ll_tm_mod_depth", "mod depth",
        controlspec.new(0, 100, 'lin', 1, 100, "%"))
    params:set_action("fx_ll_tm_mod_depth", function(v) turing.depth = v end)

    params:add_option("fx_ll_tm_mod_dir", "mod direction", dir_names, 2)
    params:set_action("fx_ll_tm_mod_dir", function(v)
        if v == 1 then turing.direction = 1
        elseif v == 2 then turing.direction = -1
        else turing.direction = 0 end
    end)

    params:add_option("fx_ll_tm_mod_rate", "mod rate", mod_rate_names, 3)
    params:set_action("fx_ll_tm_mod_rate", function(v)
        turing.clock_div = v
        if tm_active() then start_tm_clock() end
    end)

    params:add_option("fx_ll_tm_mod_top", "mod top", subdiv_names, 6)
    params:set_action("fx_ll_tm_mod_top", function(v)
        turing.range_high = v
        if turing.range_low > v then turing.range_low = v; params:set("fx_ll_tm_mod_bottom", v) end
    end)

    params:add_control("fx_ll_tm_slew", "slew",
        controlspec.new(0, 2.0, 'lin', 0.01, 0, "s"))
    params:set_action("fx_ll_tm_slew", function(v) send("slew", v) end)

    params:add_control("fx_ll_tm_steps", "steps",
        controlspec.new(0, 16, 'lin', 1, 0))
    params:set_action("fx_ll_tm_steps", function(v)
        local was = tm_active()
        turing.steps = math.floor(v)
        if tm_active() then
            turing.register = math.random(0, reg_max())
            start_tm_clock()
        else
            if was then restore(turing.target) end
            if tm_clock_id then clock.cancel(tm_clock_id); tm_clock_id = nil end
        end
    end)

    -- every x/y temporary do z --
    params:add_separator("fx_ll_evt", "every x/y temporary do z")

    params:add_option("fx_ll_evt_action", "action", event_action_names, 1)
    params:set_action("fx_ll_evt_action", function(v)
        if event_state.active then evt_undo(); event_state.active = false end
        event_state.action = v
        start_evt_clock()
    end)

    params:add_option("fx_ll_evt_rate", "rate", event_rate_names, 4)
    params:set_action("fx_ll_evt_rate", function(v)
        event_state.rate = v
        if event_state.action > 1 then start_evt_clock() end
    end)

    -- initial visibility --
    for i=1,4 do vis_tap(i) end
    vis_filter()
    vis_tm()

    start_tempo_watch()
    update_all_taps()
end

-- =========================================================================
-- hooks
-- =========================================================================

mod.hook.register("script_post_init", "fx llll post init", function()
    FxLlll:add_params()
end)

mod.hook.register("script_post_cleanup", "fx llll cleanup", function()
    if event_state.active then evt_undo() end
    if tm_active() then restore(turing.target) end
    cleanup()
end)

return FxLlll
