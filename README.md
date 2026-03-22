# fx_llll

### four lines

A multitap delay with a shift register modulator and a clock-synced event system. Four delay lines, each with its own feel, level, balance, and feedback – feeding through a bandpass filter, saturation, and chorus. Built for the [norns fx mod framework](https://llllllll.co/t/fx-mod-framework/). No external UGens required.

Named after the four delay lines – and [llllllll.co](https://llllllll.co/), where norns musicians have been building and sharing since the beginning.

## Install

**Via Maiden:** Open `http://norns.local/maiden`, type the following into the REPL:

```
;install https://github.com/notrobintaylor/fx_llll
```

Restart norns, activate under **SYSTEM > MODS**, restart again.

**Via SSH:**

```bash
ssh we@norns.local
cd ~/dust/code
git clone https://github.com/notrobintaylor/fx_llll.git fx_llll
```

Restart, activate, restart.

## Signal flow

```
input --> send level --> + --> delay lines (stereo) --> active taps gate
                         ^                                    |
                         |                              crossfeed (1↔3, 2↔4)
                         |                                    |
                         |                          Balance2 (stereo position)
                         |                                    |
                         |            +------- ------+--------+
                         |            |                       |
                         |      feedback path            output path
                         |            |                       |
                         |       fb per line           level per line
                         |            |                       |
                         |      bandpass filter          bandpass filter
                         |       (accumulating)          (same settings)
                         |            |                       |
                         |       saturation              saturation
                         |       (accumulating)          (same settings)
                         |            |                       |
                         |          tanh                   chorus
                         |            |                       |
                         +------------+                      out
```

The entire signal path is stereo. `Balance2` preserves the input's stereo image: position 0 = original, ±1 = hard L/R.

Processing lives in both paths. The output path gives every echo – including the first – full character through filter, saturation, and chorus. The feedback path runs the same filter and saturation settings, so processing accumulates across repetitions: each pass darkens and compresses the signal further. Echo 10 is a ghost of echo 1. Chorus is output-only – accumulating pitch modulation would detune the feedback loop.

When delay times change, you hear pitch sweep as the read head catches up to the new position. The **pitch glide** parameter controls this transition time (0–2500 ms).

## Parameters

### Slot

| Parameter | Options |
|-----------|---------|
| **slot** | none / send a / send b / insert |

### Taps

**Active taps** (1–4, default 1) controls how many lines are active. Inactive taps are muted and hidden. Each tap's **feel** determines timing mode: either **time div** or **time** is visible.

| Parameter | Range | Unit | Defaults (1 / 2 / 3 / 4) |
|-----------|-------|------|---------------------------|
| **active taps** | 1–4 | – | 1 |
| **feel** | note / dotted / triplet / msec | – | note |
| **time div** | 1/1–1/64 | – | 1/1, 1/2, 1/4, 1/8 |
| **time** | 1–1000 | ms | 1000, 500, 250, 125 |
| **level** | 0–100 | % | 50, 25, 10, 5 |
| **balance** | -1.00 to 1.00 | – | 0, 0, 0, 0 |
| **feedback** | 0–105 | % | 25, 25, 25, 25 |

**Feel modes:** **note** = subdivision locked to tempo, **dotted** = 1.5× (the gallop), **triplet** = 2/3× (instant swing), **msec** = free time, independent of tempo. Modes can differ per line.

**Balance** preserves the input's stereo image. At 0, the echo inherits the source's position. At ±1 it shifts hard left or right. Unlike pan, a stereo input stays wide at balance 0.

**Feedback at 105%** pushes past unity. The tanh limiter soft-clips this into saturated self-oscillation. Creative, not a mistake – but requires care.

Maximum delay time is 1 second per line. Longer subdivisions at slow tempos are clamped.

### Filter

Always-on bandpass in both the output and feedback paths. **Filter type** sets the frequencies to common starting points; both knobs remain freely adjustable afterward.

| Parameter | Range | Unit | Default |
|-----------|-------|------|---------|
| **filter type** | low / band / high | – | low |
| **frequency bottom** | 20–20000 | hz | 20 |
| **frequency top** | 20–20000 | hz | 2500 |
| **resonance** | 0–100 | % | 0 |
| **slope** | 6 / 12 / 24 / 48 | dB | 12 dB |

**Filter type** values: **low** = 20/2500 hz, **band** = 250/2500 hz, **high** = 250/20000 hz. Bottom and top are cross-clamped.

**Resonance** peaks at both cutoff edges independently. Hidden at 6 dB (OnePole has no resonance). The curve is designed so self-oscillation begins around 75% at 48 dB slope.

### Saturation

| Parameter | Range | Unit | Default |
|-----------|-------|------|---------|
| **saturation** | 0–100 | % | 0 |

Tanh soft clipping in both the output and feedback paths. Every echo is affected, and the effect accumulates across repetitions.

### Chorus

| Parameter | Range | Unit | Default |
|-----------|-------|------|---------|
| **depth** | 0–100 | % | 0 |
| **rate** | 0.01–10000 | hz | 1.0 |

Deliberately extreme range. At low rates and moderate depth: tape wobble. At high rates and high depth: ring modulation, metallic sidebands. The boundary between chorus and FM synthesis is where the interesting things happen.

### Crossfeed

| Parameter | Range | Unit | Default |
|-----------|-------|------|---------|
| **crossfeed** | 0–100 | % | 0 |

Routes signal between paired taps: 1↔3, 2↔4. At 0% the lines are independent. As crossfeed increases, they start responding to each other. With fx_llll's 1-second maximum delay, crossfeed creates dense patterns rather than evolving loops. Crossfeed and high feedback can lead to rapid buildup – start low.

### Modulation TM

A shift register inspired by Tom Whitwell's [Turing Machine](https://musicthing.co.uk/pages/turing.html). Set **steps > 0** to activate. Parameters are conditionally visible depending on **assign target**.

| Parameter | Range | Unit | Default | Visibility |
|-----------|-------|------|---------|------------|
| **assign target** | 12 targets | – | time div | always |
| **mod bottom** | 1/1–1/64 | – | 1/4 | time div only |
| **mod depth** | 0–100 | % | 100 | not time div |
| **mod direction** | + / - / + & - | – | - | not time div |
| **mod top** | 1/1–1/64 | – | 1/32 | time div only |
| **pitch glide** | 0–2500 | ms | 500 | time div + tap time |
| **slew rate** | 0–2000 | ms | 0 | not time div or tap time |
| **step rate** | 4/1–1/16 | – | 1/4 | always |
| **step stability** | 0–100 | % | 50 | always |
| **steps** | off / 1–16 | – | off | always |

**Step stability:** 100% = locked pattern, 0% = fully random, 50% = recognizable but drifting.

**Mod depth** limits swing to ±100% of the base value, clamped to parameter limits. **Mod direction:** + (up), - (down), + & - (bipolar).

**Pitch glide** and **slew rate** are mutually exclusive. Pitch glide controls tape-speed transitions for time-based targets. Slew rate smooths discrete steps for everything else. At 0, both produce instant changes.

**Step rate** ranges from 4/1 (one step per four bars) to 1/16.

Modulated parameters are marked **(M)** in the parameter menu.

**Targets:**

| Target | What it modulates | Per-line? |
|--------|-------------------|-----------|
| **chorus depth** | Chorus wet/dry | no |
| **chorus rate** | Chorus modulation speed | no |
| **crossfeed** | Crossfeed amount | no |
| **filter frequency** | Both filter frequencies | no |
| **filter resonance** | Filter resonance | no |
| **saturation** | Drive amount | no |
| **send level** | Input VCA before delay | no |
| **tap balance** | Per-line stereo position | yes |
| **tap feedback** | Per-line feedback amount | yes |
| **tap level** | Per-line output volume | yes |
| **tap time** | Per-line delay time (msec taps only) | yes |
| **time div** | Delay time divisions (note taps only) | yes |

For per-line targets, each line reads the register from a different bit rotation – four related but distinct values from one pattern. **Time div** and **tap time** respect the feel setting: time div only affects taps in note/dotted/triplet mode, tap time only affects taps in msec mode.

### Every x/y do z

Clock-synced disruptions inspired by [Monome Teletype](https://monome.org/docs/teletype/). A toggle: every X of Y beats the action fires, next X of Y it undoes itself.

| Parameter | Range | Default |
|-----------|-------|---------|
| **assign target** | off / flip balance / mute send / mute taps / all feedback min / all feedback max / stability -5% / -10% / -25% / flip levels | off |
| **chance** | off / 1–100% | off |
| **every** | 1–8 | 1 |
| **of** | 1–32 | 8 |
| **reset after** | off / 2–64 | off |
| **slew rate** | 0–2000 ms | 0 |

**Every** and **of** combine for timing: every 1 of 8 = every 8th beat. Odd denominators create phasing against 4/4. **Slew rate** is independent of the TM's slew; TM slew restores after each undo.

**Chance** gates event triggers probabilistically. A missed trigger extends the current state. **Reset after** counts successful toggles and restarts the clock, preventing indefinite drift.

Affected parameters are marked **(M)**.

**Actions:** **flip balance** mirrors the stereo image. **mute send** stops input, existing echoes ring out. **mute taps** silences all lines. **all feedback min/max** snaps feedback to 0% or 105%. **stability -5%/-10%/-25%** injects randomness into the TM. **flip levels** mirrors each tap's level around 50%.

## Safety

Feedback up to 105% means the signal grows with each repetition. The tanh limiter prevents clipping but the result can be extremely loud. At feedback above ~80% with multiple lines, expect self-oscillation. Crossfeed compounds this – moderate crossfeed with moderate feedback can produce more energy than either alone.

Use a limiter on the norns output. Start at low volume. Saturation at 20–30% adds compression that tames peaks. The event system can serve as a safety net: set assign target to "all feedback min" at a slow rate.

## Known issues

- **Send A/B routing** may not produce output depending on the host script's routing. Use insert mode.
- **Insert dry/wet** behavior depends on the fx mod framework's replacer synth.
- **Filter at 48 dB** runs four cascaded RLPF + RHPF stages in both the output and feedback paths – the most CPU-intensive configuration. If CPU is tight, use 6 or 12 dB.
- **Crossfeed + high feedback** can produce rapid self-oscillation.

## User stories

### 1.0

**Delay fundamentals**

- As a musician, I want four independent delay lines, so that I can create multiple rhythmically offset echoes from a single source.
- As a musician, I want a choice between tempo-synced note values and free milliseconds per tap, so that I can mix clock-locked and free-running delay times within the same effect.
- As a musician, I want four feel modes (note, dotted, triplet, msec), so that I can select straight, dotted, and triplet subdivisions directly alongside free timing.
- As a musician, I want note values from 1/1 to 1/64, so that I can cover a wide range of musically useful delay times.
- As a musician, I want individual level, pan, and feedback values per tap, so that I can shape four distinct delay voices with different character from one effect.
- As a musician, I want a maximum delay time of 1 second per line, so that memory usage on the norns stays manageable.
- As a musician, I want delay times to update automatically on tempo changes, so that no manual adjustments are needed while the clock is running.

**Filter, saturation, chorus**

- As a musician, I want a multimode filter (LP/BP/HP) in the output path, so that every echo – including the first – is tonally shaped.
- As a musician, I want selectable filter slopes (6/12/24/48 dB), so that I can match the filter intensity to the context.
- As a musician, I want separate frequency parameters for top and bottom in bandpass mode, so that I can define a precise frequency window.
- As a musician, I want tanh saturation in the output path, so that I can add warmth or distortion to the echoes.
- As a musician, I want a chorus in the output path with an extreme frequency range, so that I can cover the spectrum from tape wobble to ring modulation.

**Feedback**

- As a musician, I want feedback up to 105%, so that I can use controlled self-oscillation as a creative tool.
- As a musician, I want a tanh limiter in the feedback path, so that feedback above unity gain doesn't produce digital clipping.
- As a musician, I want processing (filter, saturation, chorus) only in the output path, so that even the first echo has full tonal character.

**Turing Machine**

- As a musician, I want a shift register based on the Turing Machine principle, so that parameters evolve over time in patterns that are steerable but not fully predictable.
- As a musician, I want a stability control (0–100%), so that I can determine how much the pattern mutates between exact repetition and full randomness.
- As a musician, I want 10 modulation targets (chorus depth/rate, feedback, filter, saturation, send level, subdiv, tap level, tap pan, tap time), so that I can modulate different aspects of the delay with the shift register.
- As a musician, I want each tap to read the register from a different bit position, so that per-line targets produce four related but distinct modulation values from one pattern.
- As a musician, I want adjustable mod depth and mod direction, so that I can set the modulation range and direction (unipolar/bipolar) per target.
- As a musician, I want selectable step rates (1/1 to 1/16), so that I can match the register's shift speed to the tempo.
- As a musician, I want a slew rate parameter, so that I can smooth the register's discrete steps into flowing transitions.
- As a musician, I want mod bottom and mod top displayed instead of mod depth and direction when the subdiv target is selected, so that I can directly define the range of note values the register picks from.

**Event system**

- As a musician, I want a clock-synced event system (every X of Y, do Z), so that I can trigger structural disruptions – muting, pan flips, feedback extremes – at rhythmic intervals.
- As a musician, I want events to function as toggles (fire once, undo on the next cycle), so that the disruptions are self-regulating.
- As a musician, I want odd denominators (e.g. every 1 of 7), so that I can create cycles that phase against a 4/4 grid.
- As a musician, I want a separate slew rate parameter for events, so that I can control the transition speed independently of the TM slew rate.
- As a musician, I want the actions flip pans, mute send, mute taps, all fb min, all fb max, and stability reductions, so that I have a broad palette of structural interventions.

**UX**

- As a musician, I want modulated parameters marked with (M) in the menu, so that I can see at a glance what the TM and the event system are currently controlling.
- As a musician, I want context-dependent parameters (subdiv/time depending on feel, freq/freq bottom+top depending on filter type) to show and hide automatically, so that the menu only displays relevant options.

### 2.0

**Stereo signal path**

- As a musician, I want a full stereo signal path throughout, so that the spatial character of my input survives into every echo instead of being collapsed to mono and re-panned.
- As a musician, I want balance (stereo image preservation) instead of pan (mono repositioning), so that a stereo source remains wide at the default center setting.

**Feedback path processing**

- As a musician, I want filter and saturation to accumulate in the feedback path, so that each repetition gets progressively darker and more compressed – like a tape delay where echo 10 is a ghost of echo 1.
- As a musician, I want the feedback path to use the same filter and saturation settings as the output path, so that I don't need separate controls for feedback processing.
- As a musician, I want chorus to remain output-only, so that accumulating pitch modulation doesn't detune the feedback loop.

**Active taps**

- As a musician, I want to choose how many taps are active (1–4), so that unused lines don't clutter the sound or the parameter menu.
- As a musician, I want inactive taps to be fully hidden in the menu, so that the parameter list stays concise.
- As a musician, I want quieter defaults (levels 50/25/10/5%, feedback 25%, balance centered), so that the first encounter with the effect is a clean starting point rather than four loud competing lines.

**Filter**

- As a musician, I want a single always-on bandpass with two frequency knobs instead of three parallel filter types, so that the filter uses less CPU and I can carve a frequency window from both ends simultaneously.
- As a musician, I want resonance on both cutoff edges independently, so that the bottom and top of the bandpass can sing at different frequencies.
- As a musician, I want a resonance curve where self-oscillation starts around 75% at 48 dB, so that the majority of the control range is musically usable.
- As a musician, I want resonance hidden at 6 dB slope, so that no parameter is displayed that has no effect with OnePole.
- As a musician, I want a filter type shortcut (low/band/high) that sets the frequencies to common starting points, so that I can quickly reach a familiar configuration without losing manual control.
- As a musician, I want filter type to not lock the frequencies, so that I can freely adjust both frequencies after selecting a type.

**Crossfeed**

- As a musician, I want crossfeed between paired taps (1↔3, 2↔4), so that signal circulates between the delay lines and creates feedback paths longer than individual tap times.

**Pitch glide**

- As a musician, I want pitch glide as an adjustable parameter (0–2500 ms) instead of a hardcoded value, so that I can control whether delay time changes sound like a hard cut, a tape-speed shift, or a slow detuning.
- As a musician, I want pitch glide and slew rate to be mutually exclusive, so that time-based modulation uses pitch glide and all other modulation uses slew rate without confusing interactions.
- As a musician, I want pitch glide only visible when the TM target is time-based (time div or tap time), so that only context-relevant parameters are shown.

**Turing Machine 2.0**

- As a musician, I want crossfeed and filter resonance as additional TM targets, so that the shift register can modulate the spatial interaction between taps and the filter's tonal character.
- As a musician, I want slower step rates (4/1 and 2/1), so that the register can shift at geological speed for ambient work.
- As a musician, I want time div to only modulate taps in note/dotted/triplet mode and tap time to only modulate taps in msec mode, so that the feel setting is respected and both timing modes aren't overridden simultaneously.
- As a musician, I want consistent naming of TM targets (tap feedback, filter frequency, filter resonance), so that the mapping to the actual parameter is unambiguous.

**Event system 2.0**

- As a musician, I want a chance parameter on event triggers, so that disruptions fire probabilistically and event durations become unpredictable.
- As a musician, I want a reset counter, so that the event clock restarts after a set number of toggles and prevents skipped triggers from causing indefinite drift.
- As a musician, I want a flip levels action, so that I can invert the volume hierarchy of the taps – quiet becomes loud, loud becomes quiet.
- As a musician, I want switching event actions while an action is active to correctly restore all affected parameters, so that no state gets stuck (e.g. feedback doesn't stay at 105% when switching from all feedback max to off).

**UX 2.0**

- As a musician, I want parameters sorted alphabetically within each section, so that the parameter order is predictable and consistent.
- As a musician, I want fully spelled-out parameter names instead of abbreviations (where space permits), so that naming is understandable without documentation.
- As a musician, I want the assign target parameter in both TM and event system named identically, so that the assignment function of both sections is immediately recognizable.

## Changelog

### 2.0

**Signal path:** Full stereo throughout. The delay lines no longer collapse to mono – `Balance2` replaces `Pan2`, preserving the input's stereo image into every echo and through the feedback loop.

**Feedback path:** Filter and saturation now run in both the output and feedback paths (same settings). Processing accumulates across repetitions – each pass darkens and compresses the signal further. Chorus remains output-only. In 1.0, the feedback path was raw with only a tanh limiter.

**Filter:** The three parallel filter chains (LP/BP/HP computed simultaneously, one selected at runtime) are replaced by a single always-on bandpass with two frequency parameters. Filter type (low/band/high) is now a convenience shortcut that sets the frequencies. Resonance parameter added (RLPF/RHPF at 12 dB and above). CPU usage drops significantly.

**Taps:** Active taps parameter (1–4, default 1) – only selected taps are audible and visible. Defaults are quieter: levels 50/25/10/5%, feedback 25% all, balance centered. Subdivision renamed to time div.

**Crossfeed:** New. Routes signal between paired taps (1↔3, 2↔4), creating feedback paths longer than individual delay times.

**Pitch glide:** Was hardcoded at 200 ms. Now a parameter (0–2500 ms, default 500 ms), visible only when the TM targets time-based parameters. Mutually exclusive with slew rate to avoid unpredictable interactions.

**Modulation TM:** 12 targets (was 10). Added crossfeed and filter resonance. Renamed feedback → tap feedback, filter → filter frequency. Step rate extended to 4/1 and 2/1. Time div and tap time now respect the feel setting – time div only modulates note/dotted/triplet taps, tap time only modulates msec taps.

**Event system:** Three new features: chance (probability gate on triggers), reset after (restarts the event clock after N toggles), and flip levels (mirrors each tap's level around 50%). Switching actions while an event is active now correctly restores all affected parameters.

### 1.0

Initial release. Four delay lines with mono signal path, multimode filter (LP/BP/HP), per-tap feedback, Turing Machine modulation (10 targets), clock-synced event system.

## Dependencies

- [fx mod framework](https://llllllll.co/t/fx-mod-framework/)

## Credits

Built on sixolet's [fx mod framework](https://llllllll.co/t/fx-mod-framework/).

Modulation TM inspired by Tom Whitwell's [Turing Machine](https://musicthing.co.uk/pages/turing.html). Event system borrows the "every X do Y" paradigm from [Monome Teletype](https://monome.org/docs/teletype/). Crossfeed draws from the [SOMA Cosmos](https://somasynths.com/cosmos/).

Sound and behavior shaped by: **Roland RE-201 Space Echo**, **Strymon Magneto and Volante**, **Valhalla Delay**, **Loudest Warning Analog Delay**, **XAOC Sarajewo**.
