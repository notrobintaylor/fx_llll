-- fx_llll — see README.md for parameters, signal flow, and design notes

local fx = require("fx/lib/fx")
local mod = require 'core/mods'
local hook = require 'core/hook'
local tab = require 'tabutil'

-- post-init hack: fx mod framework lacks script_post_init
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
local FEEDBACK_MAX = 1.05

local timediv_names = {"1/1","1/2","1/4","1/8","1/16","1/32","1/64"}
local timediv_beats = {4, 2, 1, 0.5, 0.25, 0.125, 0.0625}

local feel_names = {"note", "dotted", "triplet", "msec"}
local feel_mults = {1.0, 1.5, 2/3}

local filter_type_names = {"low", "band", "high"}
local filter_slope_names = {"6 dB", "12 dB", "24 dB", "48 dB"}

local step_rate_names = {"4/1","2/1","1/1","1/2","1/4","1/8","1/16"}
local step_rate_beats = {16, 8, 4, 2, 1, 0.5, 0.25}

-- numbered to match target_names index
local TARGET = {
    CHORUS_DEPTH=1, CHORUS_RATE=2, CROSSFEED=3,
    FILTER_FREQ=4, FILTER_RES=5,
    SATURATION=6, SEND_LEVEL=7,
    TAP_BAL=8, TAP_FEEDBACK=9, TAP_LEVEL=10, TAP_TIME=11,
    TIME_DIV=12
}
local target_names = {
    "chorus depth","chorus rate","crossfeed",
    "filter frequency","filter resonance",
    "saturation","send level",
    "tap balance","tap feedback","tap level","tap time",
    "time div"
}

local dir_names = {"+", "-", "+ & -"}

local steps_names = {"off"}
for i = 1, 16 do steps_names[i + 1] = tostring(i) end

local evt_denom_names = {}
local evt_denom_values = {}
for i = 1, 32 do evt_denom_names[i] = tostring(i); evt_denom_values[i] = i end

local event_action_names = {
    "off","all feedback max","all feedback min",
    "flip balance","flip levels","mute send","mute taps",
    "stability -5%","stability -10%","stability -25%"
}

-- avoids three identical branches for actions 8/9/10
local stab_reduce = {[8]=5, [9]=10, [10]=25}

local reset_names = {"off"}
for i = 2, 64 do reset_names[i] = tostring(i) end

local function fmt_pct(param) return param:get() .. " %" end
local function fmt_ms(param) return param:get() .. " ms" end
local function fmt_hz(param)
    local v = param:get()
    if v >= 100 then return string.format("%d hz", math.floor(v + 0.5))
    elseif v >= 10 then return string.format("%.1f hz", v)
    else return string.format("%.2f hz", v) end
end
local function fmt_chance(param)
    local v = param:get()
    return v == 0 and "off" or (v .. " %")
end

-- =========================================================================
-- (M) marker system
-- =========================================================================

local target_param_ids = {}
local original_names = {}

local function mark_ids(ids)
    if not ids then return end
    for _, id in ipairs(ids) do
        local idx = params.lookup[id]
        if idx then
            local p = params.params[idx]
            if not original_names[id] then original_names[id] = p.name end
            if not string.find(p.name, "%(M%)") then
                p.name = "(M) " .. original_names[id]
            end
        end
    end
    _menu.rebuild_params()
end

local function unmark_ids(ids)
    if not ids then return end
    for _, id in ipairs(ids) do
        local idx = params.lookup[id]
        if idx and original_names[id] then
            params.params[idx].name = original_names[id]
        end
    end
    _menu.rebuild_params()
end

local function mark_modulated(target) mark_ids(target_param_ids[target]) end
local function unmark_modulated(target) unmark_ids(target_param_ids[target]) end

-- =========================================================================
-- state — must match SC defaults
-- =========================================================================

local turing = {
    register=0, steps=0, target=TARGET.TIME_DIV, prev_target=TARGET.TIME_DIV,
    depth=100, direction=-1, stability=50, clock_div=5,
    range_low=3, range_high=6,
}

local event_state = {
    active=false, clock_id=nil, action=1,
    every=1, denom=4, slew=0,
    saved_stab=0,
    chance=0, reset_after=0, toggle_count=0,
}

local base = {
    inputGain=1.0,
    filterFreqBottom=20, filterFreqTop=2500,
    resonance=1.0,
    saturation=0, chorusDepth=0, chorusRate=1.0,
    crossfeed=0,
}
for i=1,4 do
    base["feedback"..i] = 0.25
    base["level"..i] = ({0.50, 0.25, 0.10, 0.05})[i]
    base["bal"..i] = 0.0
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
    return (((turing.register >> i) | (turing.register << (turing.steps - i))) & m) / m
end

local function apply_mod(raw, bv, lo, hi)
    local d = turing.depth / 100
    local dir = turing.direction
    local swing = bv * raw * d
    if dir == 1 then return math.max(lo, math.min(hi, bv + swing))
    elseif dir == -1 then return math.max(lo, math.min(hi, bv - swing))
    else return math.max(lo, math.min(hi, bv + bv * (raw * 2 - 1) * d)) end
end

-- sends all event-affected params to base immediately, skipping TM-owned ones
local function force_restore_all()
    send("slew", 0)
    if not (tm_active() and turing.target == TARGET.SEND_LEVEL) then
        send("inputGain", base.inputGain)
    end
    for i=1,4 do
        if not (tm_active() and turing.target == TARGET.TAP_LEVEL) then
            send("level"..i, base["level"..i])
        end
        if not (tm_active() and turing.target == TARGET.TAP_BAL) then
            send("bal"..i, base["bal"..i])
        end
        if not (tm_active() and turing.target == TARGET.TAP_FEEDBACK) then
            send("feedback"..i, base["feedback"..i])
        end
    end
    send("slew", params:get("fx_ll_tm_slew_rate") / 1000)
end

-- =========================================================================
-- delay time
-- =========================================================================

local function beat_sec() return 60 / clock.get_tempo() end

local function update_tap(i)
    local feel = params:get("fx_ll_feel_"..i)
    -- time div only modulates note-feel taps, tap time only msec taps
    if tm_active() and turing.target == TARGET.TIME_DIV and feel ~= 4 then return end
    if tm_active() and turing.target == TARGET.TAP_TIME and feel == 4 then return end
    local t
    if feel == 4 then
        t = math.min(params:get("fx_ll_time_"..i) / 1000, MAX_DELAY)
    else
        t = math.min(timediv_beats[params:get("fx_ll_timediv_"..i)] * beat_sec() * feel_mults[feel], MAX_DELAY)
    end
    base["time"..i] = t
    send("time"..i, t)
end

local function update_all_taps() for i=1,4 do update_tap(i) end end

-- =========================================================================
-- turing machine
-- =========================================================================

local function tm_timediv()
    local m = reg_max(); if m == 0 then return end
    for i=1,4 do
        local feel = params:get("fx_ll_feel_"..i)
        if feel == 4 then
            send("time"..i, base["time"..i])
        else
            local rot = ((turing.register >> i) | (turing.register << (turing.steps - i))) & m
            local rng = turing.range_high - turing.range_low + 1
            local sd = rng <= 0 and turing.range_low or (turing.range_low + (rot % rng))
            send("time"..i, math.min(timediv_beats[sd] * beat_sec() * feel_mults[feel], MAX_DELAY))
        end
    end
end

local function restore(t)
    if t == TARGET.TIME_DIV or t == TARGET.TAP_TIME then update_all_taps()
    elseif t == TARGET.SEND_LEVEL then send("inputGain", base.inputGain)
    elseif t == TARGET.FILTER_FREQ then
        send("filterFreqBottom", base.filterFreqBottom)
        send("filterFreqTop", base.filterFreqTop)
    elseif t == TARGET.FILTER_RES then send("resonance", base.resonance)
    elseif t == TARGET.CROSSFEED then send("crossfeed", base.crossfeed)
    elseif t == TARGET.TAP_FEEDBACK then for i=1,4 do send("feedback"..i, base["feedback"..i]) end
    elseif t == TARGET.TAP_LEVEL then for i=1,4 do send("level"..i, base["level"..i]) end
    elseif t == TARGET.TAP_BAL then for i=1,4 do send("bal"..i, base["bal"..i]) end
    elseif t == TARGET.CHORUS_DEPTH then send("chorusDepth", base.chorusDepth)
    elseif t == TARGET.CHORUS_RATE then send("chorusRate", base.chorusRate)
    elseif t == TARGET.SATURATION then send("saturation", base.saturation)
    end
    unmark_modulated(t)
end

local function tm_apply()
    if not tm_active() then return end
    local m = reg_max(); if m == 0 then return end
    local t = turing.target
    local raw = turing.register / m

    if t == TARGET.TIME_DIV then tm_timediv(); return end
    if t == TARGET.TAP_TIME then
        for i=1,4 do
            if params:get("fx_ll_feel_"..i) == 4 then
                send("time"..i, apply_mod(tap_mod(i), base["time"..i], 0.001, MAX_DELAY))
            end
        end
    elseif t == TARGET.SEND_LEVEL then send("inputGain", apply_mod(raw, 1.0, 0, 2.0))
    elseif t == TARGET.FILTER_FREQ then
        send("filterFreqBottom", apply_mod(raw, base.filterFreqBottom, 20, 20000))
        send("filterFreqTop", apply_mod(raw, base.filterFreqTop, 20, 20000))
    elseif t == TARGET.FILTER_RES then send("resonance", apply_mod(raw, base.resonance, 0.01, 1.0))
    elseif t == TARGET.CROSSFEED then send("crossfeed", apply_mod(raw, base.crossfeed, 0, 1))
    elseif t == TARGET.TAP_FEEDBACK then
        for i=1,4 do send("feedback"..i, apply_mod(tap_mod(i), base["feedback"..i], 0, FEEDBACK_MAX)) end
    elseif t == TARGET.TAP_LEVEL then
        for i=1,4 do send("level"..i, apply_mod(tap_mod(i), base["level"..i], 0, 1)) end
    elseif t == TARGET.TAP_BAL then
        for i=1,4 do send("bal"..i, apply_mod(tap_mod(i), base["bal"..i], -1, 1)) end
    elseif t == TARGET.CHORUS_DEPTH then send("chorusDepth", apply_mod(raw, base.chorusDepth, 0, 100))
    elseif t == TARGET.CHORUS_RATE then send("chorusRate", apply_mod(raw, base.chorusRate, 0.01, 10000))
    elseif t == TARGET.SATURATION then send("saturation", apply_mod(raw, base.saturation, 0, 1))
    end
end

local function tm_step()
    if not tm_active() then return end
    local m = reg_max()
    local msb = (turing.register >> (turing.steps - 1)) & 1
    turing.register = (turing.register << 1) & m
    -- 100% = always copy (locked), 0% = always flip (random)
    if math.random(100) > turing.stability then
        turing.register = turing.register | (1 - msb)
    else turing.register = turing.register | msb end
    tm_apply()
end

-- =========================================================================
-- event system
-- =========================================================================

local function evt_beats()
    return event_state.every * (4 / evt_denom_values[event_state.denom])
end

local evt_action_param_ids = {}

local function evt_do()
    local a = event_state.action
    if a == 1 then return end
    send("slew", event_state.slew / 1000)
    if a == 2 then for i=1,4 do send("feedback"..i, FEEDBACK_MAX) end
    elseif a == 3 then for i=1,4 do send("feedback"..i, 0) end
    elseif a == 4 then for i=1,4 do send("bal"..i, -base["bal"..i]) end
    elseif a == 5 then
        for i=1,4 do send("level"..i, (100 - params:get("fx_ll_level_"..i)) / 100) end
    elseif a == 6 then send("inputGain", 0)
    elseif a == 7 then for i=1,4 do send("level"..i, 0) end
    elseif stab_reduce[a] then
        event_state.saved_stab = turing.stability
        turing.stability = math.max(0, turing.stability - stab_reduce[a])
    end
    mark_ids(evt_action_param_ids[a])
end

local function evt_undo()
    local a = event_state.action
    if a == 1 then return end
    send("slew", event_state.slew / 1000)
    if a == 2 or a == 3 then for i=1,4 do send("feedback"..i, base["feedback"..i]) end
    elseif a == 4 then for i=1,4 do send("bal"..i, base["bal"..i]) end
    elseif a == 5 or a == 7 then for i=1,4 do send("level"..i, base["level"..i]) end
    elseif a == 6 then send("inputGain", base.inputGain)
    elseif stab_reduce[a] then turing.stability = event_state.saved_stab
    end
    unmark_ids(evt_action_param_ids[a])
    send("slew", params:get("fx_ll_tm_slew_rate") / 1000)
end

-- forward-declared: coroutine restarts itself on reset
local start_evt_clock

start_evt_clock = function()
    if event_state.clock_id then clock.cancel(event_state.clock_id); event_state.clock_id = nil end
    if event_state.action == 1 then return end
    event_state.toggle_count = 0
    event_state.clock_id = clock.run(function()
        while true do
            clock.sync(evt_beats())
            if event_state.chance == 0 or math.random(100) <= event_state.chance then
                if event_state.active then evt_undo(); event_state.active = false
                else evt_do(); event_state.active = true end
                if event_state.reset_after > 0 then
                    event_state.toggle_count = event_state.toggle_count + 1
                    if event_state.toggle_count >= event_state.reset_after then break end
                end
            end
        end
        start_evt_clock()
    end)
end

-- =========================================================================
-- clock management
-- =========================================================================

local function start_tm_clock()
    if tm_clock_id then clock.cancel(tm_clock_id); tm_clock_id = nil end
    if not tm_active() then return end
    tm_clock_id = clock.run(function()
        while true do clock.sync(step_rate_beats[turing.clock_div]); tm_step() end
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
                if tm_active() and turing.target == TARGET.TIME_DIV then tm_timediv()
                elseif tm_active() and turing.target == TARGET.TAP_TIME then
                    for i=1,4 do
                        local feel = params:get("fx_ll_feel_"..i)
                        if feel ~= 4 then
                            base["time"..i] = math.min(
                                timediv_beats[params:get("fx_ll_timediv_"..i)] * beat_sec() * feel_mults[feel], MAX_DELAY)
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
    local msec = params:get("fx_ll_feel_"..i) == 4
    if msec then params:show("fx_ll_time_"..i); params:hide("fx_ll_timediv_"..i)
    else params:hide("fx_ll_time_"..i); params:show("fx_ll_timediv_"..i) end
end

local function vis_active_taps()
    local n = params:get("fx_ll_active_taps")
    for i=1,4 do
        local show = i <= n
        for _, suffix in ipairs({"bal_","feedback_","feel_","level_","timediv_","time_"}) do
            if show then params:show("fx_ll_"..suffix..i)
            else params:hide("fx_ll_"..suffix..i) end
        end
        if show then vis_tap(i) end
    end
    _menu.rebuild_params()
end

local function vis_filter()
    if params:get("fx_ll_filter_slope") == 1 then params:hide("fx_ll_resonance")
    else params:show("fx_ll_resonance") end
    _menu.rebuild_params()
end

local function vis_tm()
    local t = turing.target
    local is_timediv = (t == TARGET.TIME_DIV)
    local uses_glide = is_timediv or (t == TARGET.TAP_TIME)

    if is_timediv then
        params:show("fx_ll_tm_mod_bottom"); params:show("fx_ll_tm_mod_top")
        params:hide("fx_ll_tm_mod_depth"); params:hide("fx_ll_tm_mod_dir")
    else
        params:hide("fx_ll_tm_mod_bottom"); params:hide("fx_ll_tm_mod_top")
        params:show("fx_ll_tm_mod_depth"); params:show("fx_ll_tm_mod_dir")
    end

    if uses_glide then
        params:show("fx_ll_tm_pitch_glide"); params:hide("fx_ll_tm_slew_rate")
    else
        params:hide("fx_ll_tm_pitch_glide"); params:show("fx_ll_tm_slew_rate")
    end

    _menu.rebuild_params()
end

-- =========================================================================
-- tm activation/deactivation
-- =========================================================================

local function tm_activate()
    turing.register = math.random(0, reg_max())
    mark_modulated(turing.target)
    start_tm_clock()
end

local function tm_deactivate()
    restore(turing.target)
    if tm_clock_id then clock.cancel(tm_clock_id); tm_clock_id = nil end
end

-- =========================================================================
-- parameters
-- =========================================================================

function FxLlll:add_params()

    params:add_separator("fx_ll", "fx llll")
    FxLlll:add_slot("fx_ll_slot", "slot")

    -- taps --
    params:add_separator("fx_ll_taps", "taps")

    params:add_number("fx_ll_active_taps", "active taps", 1, 4, 1)
    params:set_action("fx_ll_active_taps", function(v)
        send("activeTaps", v)
        vis_active_taps()
    end)

    local default_timedivs = {1, 2, 3, 4}
    local default_fb = {25, 25, 25, 25}
    local default_levels = {50, 25, 10, 5}
    local default_msec = {1000, 500, 250, 125}

    for i=1,4 do
        params:add_control("fx_ll_bal_"..i, "tap "..i.." balance",
            controlspec.new(-1, 1, 'lin', 0.01, 0.0))
        params:set_action("fx_ll_bal_"..i, function(v)
            base["bal"..i] = v
            if not (tm_active() and turing.target == TARGET.TAP_BAL) then send("bal"..i, v) end
        end)

        params:add_number("fx_ll_feedback_"..i, "tap "..i.." feedback", 0, 105, default_fb[i], fmt_pct)
        params:set_action("fx_ll_feedback_"..i, function(v)
            base["feedback"..i] = v / 100
            if not (tm_active() and turing.target == TARGET.TAP_FEEDBACK) then send("feedback"..i, v / 100) end
        end)

        params:add_option("fx_ll_feel_"..i, "tap "..i.." feel", feel_names, 1)
        params:set_action("fx_ll_feel_"..i, function()
            vis_active_taps()
            update_tap(i)
        end)

        params:add_number("fx_ll_level_"..i, "tap "..i.." level", 0, 100, default_levels[i], fmt_pct)
        params:set_action("fx_ll_level_"..i, function(v)
            base["level"..i] = v / 100
            if not (tm_active() and turing.target == TARGET.TAP_LEVEL) then send("level"..i, v / 100) end
        end)

        params:add_number("fx_ll_time_"..i, "tap "..i.." time", 1, 1000, default_msec[i], fmt_ms)
        params:set_action("fx_ll_time_"..i, function() update_tap(i) end)

        params:add_option("fx_ll_timediv_"..i, "tap "..i.." time div", timediv_names, default_timedivs[i])
        params:set_action("fx_ll_timediv_"..i, function() update_tap(i) end)
    end

    -- filter --
    params:add_separator("fx_ll_flt", "filter")

    params:add_option("fx_ll_filter_type", "filter type", filter_type_names, 1)
    params:set_action("fx_ll_filter_type", function(v)
        if v == 1 then     params:set("fx_ll_filter_freq_bottom", 20);  params:set("fx_ll_filter_freq_top", 2500)
        elseif v == 2 then params:set("fx_ll_filter_freq_bottom", 250); params:set("fx_ll_filter_freq_top", 2500)
        elseif v == 3 then params:set("fx_ll_filter_freq_bottom", 250); params:set("fx_ll_filter_freq_top", 20000) end
    end)

    params:add_control("fx_ll_filter_freq_bottom", "frequency bottom",
        controlspec.new(20, 20000, 'exp', 0, 20, "hz"), fmt_hz)
    params:set_action("fx_ll_filter_freq_bottom", function(v)
        base.filterFreqBottom = v
        if v > base.filterFreqTop then params:set("fx_ll_filter_freq_top", v) end
        if not (tm_active() and turing.target == TARGET.FILTER_FREQ) then send("filterFreqBottom", v) end
    end)

    params:add_control("fx_ll_filter_freq_top", "frequency top",
        controlspec.new(20, 20000, 'exp', 0, 2500, "hz"), fmt_hz)
    params:set_action("fx_ll_filter_freq_top", function(v)
        base.filterFreqTop = v
        if v < base.filterFreqBottom then params:set("fx_ll_filter_freq_bottom", v) end
        if not (tm_active() and turing.target == TARGET.FILTER_FREQ) then send("filterFreqTop", v) end
    end)

    params:add_number("fx_ll_resonance", "resonance", 0, 100, 0, fmt_pct)
    params:set_action("fx_ll_resonance", function(v)
        local rq = 10 ^ (-((v / 100) ^ 3) * 2)
        base.resonance = rq
        if not (tm_active() and turing.target == TARGET.FILTER_RES) then send("resonance", rq) end
    end)

    params:add_option("fx_ll_filter_slope", "slope", filter_slope_names, 2)
    params:set_action("fx_ll_filter_slope", function(v)
        send("filterSlope", v)
        vis_filter()
    end)

    -- saturation --
    params:add_separator("fx_ll_sat", "saturation")

    params:add_number("fx_ll_saturation", "saturation", 0, 100, 0, fmt_pct)
    params:set_action("fx_ll_saturation", function(v)
        base.saturation = v / 100
        if not (tm_active() and turing.target == TARGET.SATURATION) then send("saturation", v / 100) end
    end)

    -- chorus --
    params:add_separator("fx_ll_ch", "chorus")

    params:add_number("fx_ll_chorus_depth", "depth", 0, 100, 0, fmt_pct)
    params:set_action("fx_ll_chorus_depth", function(v)
        base.chorusDepth = v
        if not (tm_active() and turing.target == TARGET.CHORUS_DEPTH) then send("chorusDepth", v) end
    end)

    params:add_control("fx_ll_chorus_rate", "rate",
        controlspec.new(0.01, 10000, 'exp', 0, 1.0, "hz"), fmt_hz)
    params:set_action("fx_ll_chorus_rate", function(v)
        base.chorusRate = v
        if not (tm_active() and turing.target == TARGET.CHORUS_RATE) then send("chorusRate", v) end
    end)

    -- crossfeed --
    params:add_separator("fx_ll_xf", "crossfeed")

    params:add_number("fx_ll_crossfeed", "crossfeed", 0, 100, 0, fmt_pct)
    params:set_action("fx_ll_crossfeed", function(v)
        base.crossfeed = v / 100
        if not (tm_active() and turing.target == TARGET.CROSSFEED) then send("crossfeed", v / 100) end
    end)

    -- modulation TM --
    params:add_separator("fx_ll_tm", "modulation TM")

    params:add_option("fx_ll_tm_mod_target", "assign target", target_names, TARGET.TIME_DIV)
    params:set_action("fx_ll_tm_mod_target", function(v)
        if tm_active() then restore(turing.prev_target) end
        turing.prev_target = v; turing.target = v
        vis_tm()
        if tm_active() then tm_activate() end
    end)

    params:add_option("fx_ll_tm_mod_bottom", "mod bottom", timediv_names, 3)
    params:set_action("fx_ll_tm_mod_bottom", function(v)
        turing.range_low = v
        if turing.range_high < v then turing.range_high = v; params:set("fx_ll_tm_mod_top", v) end
    end)

    params:add_number("fx_ll_tm_mod_depth", "mod depth", 0, 100, 100, fmt_pct)
    params:set_action("fx_ll_tm_mod_depth", function(v) turing.depth = v end)

    params:add_option("fx_ll_tm_mod_dir", "mod direction", dir_names, 2)
    params:set_action("fx_ll_tm_mod_dir", function(v)
        if v == 1 then turing.direction = 1
        elseif v == 2 then turing.direction = -1
        else turing.direction = 0 end
    end)

    params:add_option("fx_ll_tm_mod_top", "mod top", timediv_names, 6)
    params:set_action("fx_ll_tm_mod_top", function(v)
        turing.range_high = v
        if turing.range_low > v then turing.range_low = v; params:set("fx_ll_tm_mod_bottom", v) end
    end)

    params:add_number("fx_ll_tm_pitch_glide", "pitch glide", 0, 2500, 500, fmt_ms)
    params:set_action("fx_ll_tm_pitch_glide", function(v) send("pitchGlide", v / 1000) end)

    params:add_number("fx_ll_tm_slew_rate", "slew rate", 0, 2000, 0, fmt_ms)
    params:set_action("fx_ll_tm_slew_rate", function(v) send("slew", v / 1000) end)

    params:add_option("fx_ll_tm_step_rate", "step rate", step_rate_names, 5)
    params:set_action("fx_ll_tm_step_rate", function(v)
        turing.clock_div = v
        if tm_active() then start_tm_clock() end
    end)

    params:add_number("fx_ll_tm_step_stab", "step stability", 0, 100, 50, fmt_pct)
    params:set_action("fx_ll_tm_step_stab", function(v) turing.stability = v end)

    params:add_option("fx_ll_tm_steps", "steps", steps_names, 1)
    params:set_action("fx_ll_tm_steps", function(v)
        local was = tm_active()
        turing.steps = v - 1
        if tm_active() then tm_activate()
        elseif was then tm_deactivate() end
    end)

    -- every x/y do z --
    params:add_separator("fx_ll_evt", "every x/y do z")

    params:add_option("fx_ll_evt_action", "assign target", event_action_names, 1)
    params:set_action("fx_ll_evt_action", function(v)
        if event_state.active then evt_undo(); event_state.active = false end
        unmark_ids(evt_action_param_ids[event_state.action])
        force_restore_all()
        event_state.action = v
        start_evt_clock()
    end)

    params:add_number("fx_ll_evt_chance", "chance", 0, 100, 0, fmt_chance)
    params:set_action("fx_ll_evt_chance", function(v) event_state.chance = v end)

    params:add_number("fx_ll_evt_every", "every", 1, 8, 1)
    params:set_action("fx_ll_evt_every", function(v)
        event_state.every = v
        if event_state.action > 1 then start_evt_clock() end
    end)

    params:add_option("fx_ll_evt_of", "of", evt_denom_names, 8)
    params:set_action("fx_ll_evt_of", function(v)
        event_state.denom = v
        if event_state.action > 1 then start_evt_clock() end
    end)

    params:add_option("fx_ll_evt_reset", "reset after", reset_names, 1)
    params:set_action("fx_ll_evt_reset", function(v)
        event_state.reset_after = v == 1 and 0 or v
        event_state.toggle_count = 0
    end)

    params:add_number("fx_ll_evt_slew_rate", "slew rate", 0, 2000, 0, fmt_ms)
    params:set_action("fx_ll_evt_slew_rate", function(v) event_state.slew = v end)

    -- marker maps --
    target_param_ids[TARGET.CHORUS_DEPTH] = {"fx_ll_chorus_depth"}
    target_param_ids[TARGET.CHORUS_RATE] = {"fx_ll_chorus_rate"}
    target_param_ids[TARGET.CROSSFEED] = {"fx_ll_crossfeed"}
    target_param_ids[TARGET.FILTER_FREQ] = {"fx_ll_filter_freq_bottom","fx_ll_filter_freq_top"}
    target_param_ids[TARGET.FILTER_RES] = {"fx_ll_resonance"}
    target_param_ids[TARGET.SATURATION] = {"fx_ll_saturation"}
    target_param_ids[TARGET.SEND_LEVEL] = {}
    target_param_ids[TARGET.TAP_BAL] = {}
    target_param_ids[TARGET.TAP_FEEDBACK] = {}
    target_param_ids[TARGET.TAP_LEVEL] = {}
    target_param_ids[TARGET.TAP_TIME] = {}
    target_param_ids[TARGET.TIME_DIV] = {}
    for i=1,4 do
        table.insert(target_param_ids[TARGET.TAP_FEEDBACK], "fx_ll_feedback_"..i)
        table.insert(target_param_ids[TARGET.TIME_DIV], "fx_ll_timediv_"..i)
        table.insert(target_param_ids[TARGET.TAP_LEVEL], "fx_ll_level_"..i)
        table.insert(target_param_ids[TARGET.TAP_BAL], "fx_ll_bal_"..i)
        table.insert(target_param_ids[TARGET.TAP_TIME], "fx_ll_time_"..i)
        table.insert(target_param_ids[TARGET.TAP_TIME], "fx_ll_timediv_"..i)
    end

    evt_action_param_ids[2] = {}
    evt_action_param_ids[3] = {}
    evt_action_param_ids[4] = {}
    evt_action_param_ids[5] = {}
    evt_action_param_ids[6] = {}
    evt_action_param_ids[7] = {}
    for i=1,4 do
        table.insert(evt_action_param_ids[2], "fx_ll_feedback_"..i)
        table.insert(evt_action_param_ids[3], "fx_ll_feedback_"..i)
        table.insert(evt_action_param_ids[4], "fx_ll_bal_"..i)
        table.insert(evt_action_param_ids[5], "fx_ll_level_"..i)
        table.insert(evt_action_param_ids[7], "fx_ll_level_"..i)
    end
    evt_action_param_ids[8] = {"fx_ll_tm_step_stab"}
    evt_action_param_ids[9] = {"fx_ll_tm_step_stab"}
    evt_action_param_ids[10] = {"fx_ll_tm_step_stab"}

    vis_active_taps()
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
    if tm_active() then tm_deactivate() end
    cleanup()
end)

return FxLlll
