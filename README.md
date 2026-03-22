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
                         |            +---------------+-------+
                         |            |                       |
                         |      feedback path            output path
                         |            |                       |
                         |       fb per line           level per line
                         |            |                       |
                         |          tanh                 bandpass filter
                         |            |                       |
                         +------------+                  saturation
                                                              |
                                                           chorus
                                                              |
                                                             out
```

The entire signal path is stereo. `Balance2` preserves the input's stereo image: position 0 = original, ±1 = hard L/R. The output path carries every echo through filter, saturation, and chorus – the first repetition already has full character. The feedback path is raw with a tanh safety limiter.

When delay times change, you hear pitch sweep as the read head catches up. The **pitch glide** parameter controls this transition time (0–250 ms).

## Parameters

### Slot

| Parameter | Options |
|-----------|---------|
| **slot** | none / send a / send b / insert |

### Taps

**Active taps** (1–4, default 1) controls how many lines are active. Inactive taps are muted and hidden. Each tap's **feel** determines timing mode: either **subdiv** or **time** is visible.

| Parameter | Range | Unit | Defaults (1 / 2 / 3 / 4) |
|-----------|-------|------|---------------------------|
| **active taps** | 1–4 | – | 1 |
| **feedback** | 0–105 | % | 25, 25, 25, 25 |
| **feel** | note / dotted / triplet / msec | – | note |
| **level** | 0–100 | % | 50, 25, 10, 5 |
| **balance** | -1.00 to 1.00 | – | 0, 0, 0, 0 |
| **subdiv** | 1/1–1/64 | – | 1/1, 1/2, 1/4, 1/8 |
| **time** | 1–1000 | ms | 1000, 500, 250, 125 |

**Feel modes:** **note** = subdivision locked to tempo, **dotted** = 1.5× (the gallop), **triplet** = 2/3× (instant swing), **msec** = free time, independent of tempo. Modes can differ per line.

**Balance** preserves the input's stereo image. At 0, the echo inherits the source's position. At ±1 it shifts hard left or right. Unlike pan, a stereo input stays wide at balance 0.

**Feedback at 105%** pushes past unity. The tanh limiter soft-clips this into saturated self-oscillation. Creative, not a mistake – but requires care.

Maximum delay time is 1 second per line. Longer subdivisions at slow tempos are clamped.

### Filter

Always-on bandpass in the output path. Two frequency parameters define the passband window.

| Parameter | Range | Unit | Default |
|-----------|-------|------|---------|
| **frequency bottom** | 20–20000 | hz | 20 |
| **frequency top** | 20–20000 | hz | 20000 |
| **slope** | 6 / 12 / 24 / 48 | dB | 12 dB |
| **resonance** | 0–100 | % | 0 |
| **feedback filter** | 200–20000 | hz | 6000 |

With bottom at 20 hz and top at 20 khz, the filter is effectively a bypass. Narrow the window from either end to shape the echoes. Bottom and top are cross-clamped.

**Resonance** peaks at both cutoff edges independently. Hidden at 6 dB (OnePole has no resonance).

**Feedback filter** is a separate OnePole lowpass in the feedback path. It controls how quickly echoes darken over successive passes. At 6000 hz (default), the effect is subtle. At lower values, each repetition loses more highs.

### Saturation

| Parameter | Range | Unit | Default |
|-----------|-------|------|---------|
| **saturation** | 0–100 | % | 0 |

Tanh soft clipping in the output path. Every echo is affected, including the first.

### Chorus

| Parameter | Range | Unit | Default |
|-----------|-------|------|---------|
| **depth** | 0–100 | % | 0 |
| **rate** | 0.01–10000 | hz | 1.0 |

Deliberately extreme range. At low rates and moderate depth: tape wobble. At high rates and high depth: ring modulation. The boundary between chorus and FM synthesis is where the interesting things happen.

### Crossfeed

| Parameter | Range | Unit | Default |
|-----------|-------|------|---------|
| **crossfeed** | 0–100 | % | 0 |

Routes signal between paired taps: 1↔3, 2↔4. At 0% the lines are independent. As crossfeed increases, they start responding to each other. Crossfeed and high feedback can lead to rapid buildup – start low.

### Modulation TM

A shift register inspired by Tom Whitwell's [Turing Machine](https://musicthing.co.uk/pages/turing.html). Set **steps > 0** to activate. Parameters are conditionally visible depending on **mod assign**.

| Parameter | Range | Unit | Default | Visibility |
|-----------|-------|------|---------|------------|
| **mod assign** | 10 targets | – | subdiv | always |
| **mod bottom** | 1/1–1/64 | – | 1/4 | subdiv only |
| **mod depth** | 0–100 | % | 100 | not subdiv |
| **mod direction** | + / - / + & - | – | - | not subdiv |
| **mod top** | 1/1–1/64 | – | 1/32 | subdiv only |
| **pitch glide** | 0–250 | ms | 200 | always |
| **slew rate** | 0–2000 | ms | 0 | always |
| **step rate** | 4/1–1/16 | – | 1/4 | always |
| **step stability** | 0–100 | % | 50 | always |
| **steps** | off / 1–16 | – | off | always |

**Step stability:** 100% = locked pattern, 0% = fully random, 50% = recognizable but drifting.

**Mod depth** limits swing to ±100% of the base value, clamped to parameter limits. **Mod direction:** + (up), - (down), + & - (bipolar).

**Pitch glide** controls tape-speed transitions when delay times change. **Slew rate** smooths discrete steps for all targets.

**Step rate** ranges from 4/1 (one step per four bars) to 1/16.

Modulated parameters are marked **(M)** in the parameter menu.

**Targets:**

| Target | What it modulates | Per-line? |
|--------|-------------------|-----------|
| **chorus depth** | Chorus wet/dry | no |
| **chorus rate** | Chorus modulation speed | no |
| **feedback** | Per-line feedback amount | yes |
| **filter** | Both filter frequencies | no |
| **saturation** | Drive amount | no |
| **send level** | Input VCA before delay | no |
| **subdiv** | Delay subdivisions | yes |
| **tap balance** | Per-line stereo position | yes |
| **tap level** | Per-line output volume | yes |
| **tap time** | Per-line delay time directly | yes |

For per-line targets, each line reads the register from a different bit rotation – four related but distinct values from one pattern.

### Every x/y do z

Clock-synced disruptions inspired by [Monome Teletype](https://monome.org/docs/teletype/). A toggle: every X of Y beats the action fires, next X of Y it undoes itself.

| Parameter | Range | Default |
|-----------|-------|---------|
| **temp action** | off / flip balance / mute send / mute taps / all fb min / all fb max / stability -5% / -10% / -25% / flip levels | off |
| **every** | 1–8 | 1 |
| **of** | 1–32 | 8 |
| **slew rate** | 0–2000 ms | 0 |
| **chance** | off / 1–100% | off |
| **reset after** | off / 2–64 | off |

**Every** and **of** combine for timing: every 1 of 8 = every 8th beat. Odd denominators create phasing against 4/4. **Slew rate** is independent of the TM's slew; TM slew restores after each undo.

**Chance** gates event triggers probabilistically. A missed trigger extends the current state. **Reset after** counts successful toggles and restarts the clock, preventing indefinite drift.

Affected parameters are marked **(M)**.

**Actions:** **flip balance** mirrors the stereo image. **mute send** stops input, existing echoes ring out. **mute taps** silences all lines. **all fb min/max** snaps feedback to 0% or 105%. **stability -5%/-10%/-25%** injects randomness into the TM. **flip levels** mirrors each tap's level around 50%.

## Safety

Feedback up to 105% means the signal grows with each repetition. The tanh limiter prevents clipping but the result can be extremely loud. At feedback above ~80% with multiple lines, expect self-oscillation. Crossfeed compounds this – moderate crossfeed with moderate feedback can produce more energy than either alone.

Use a limiter on the norns output. Start at low volume. Saturation at 20–30% adds compression that tames peaks. The event system can serve as a safety net: set temp action to "all fb min" at a slow rate.

## Known issues

- **Send A/B routing** may not produce output depending on the host script's routing. Use insert mode.
- **Insert dry/wet** behavior depends on the fx mod framework's replacer synth.
- **Filter at 48 dB** runs four cascaded RLPF + RHPF stages – the most CPU-intensive configuration.
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

**Active taps**

- As a musician, I want to choose how many taps are active (1–4), so that unused lines don't clutter the sound or the parameter menu.
- As a musician, I want inactive taps to be fully hidden in the menu, so that the parameter list stays concise.
- As a musician, I want quieter defaults (levels 50/25/10/5%, feedback 25%, balance centered), so that the first encounter with the effect is a clean starting point rather than four loud competing lines.

**Filter**

- As a musician, I want a single always-on bandpass with two frequency knobs instead of three parallel filter types, so that the filter uses less CPU and I can carve a frequency window from both ends simultaneously.
- As a musician, I want resonance on both cutoff edges independently, so that the bottom and top of the bandpass can sing at different frequencies.
- As a musician, I want a separate feedback filter in the feedback path, so that echoes darken progressively over successive passes.

**Crossfeed**

- As a musician, I want crossfeed between paired taps (1↔3, 2↔4), so that signal circulates between the delay lines and creates feedback paths longer than individual tap times.

**Pitch glide**

- As a musician, I want pitch glide as an adjustable parameter (0–250 ms) instead of a hardcoded value, so that I can control whether delay time changes sound like a hard cut or a tape-speed shift.

**Turing Machine 2.0**

- As a musician, I want slower step rates (4/1 and 2/1), so that the register can shift at geological speed for ambient work.

**Event system 2.0**

- As a musician, I want a chance parameter on event triggers, so that disruptions fire probabilistically and event durations become unpredictable.
- As a musician, I want a reset counter, so that the event clock restarts after a set number of toggles and prevents skipped triggers from causing indefinite drift.
- As a musician, I want a flip levels action, so that I can invert the volume hierarchy of the taps – quiet becomes loud, loud becomes quiet.

## Changelog

### 2.0

**Signal path:** Full stereo throughout. `Balance2` replaces `Pan2`, preserving the input's stereo image into every echo and through the feedback loop. No mono collapse.

**Filter:** Three parallel filter chains replaced by a single always-on bandpass with two frequency parameters. Resonance added (RLPF/RHPF at 12 dB and above). Separate feedback filter (OnePole LP) in the feedback path for progressive echo darkening.

**Taps:** Active taps parameter (1–4, default 1) – only selected taps are audible and visible. Quieter defaults: levels 50/25/10/5%, feedback 25%, balance centered.

**Crossfeed:** New. Routes signal between paired taps (1↔3, 2↔4).

**Pitch glide:** Was hardcoded at 200 ms. Now a parameter (0–250 ms).

**Modulation TM:** Step rate extended to 4/1 and 2/1.

**Event system:** Three new features: chance (probability gate), reset after (clock re-sync after N toggles), flip levels (inverts tap volume hierarchy).

### 1.0

Initial release. Four delay lines with mono signal path (Mix.ar + Pan2), multimode filter (LP/BP/HP), per-tap feedback, Turing Machine modulation (10 targets), clock-synced event system.

## Dependencies

- [fx mod framework](https://llllllll.co/t/fx-mod-framework/)

## Credits

Built on sixolet's [fx mod framework](https://llllllll.co/t/fx-mod-framework/).

Modulation TM inspired by Tom Whitwell's [Turing Machine](https://musicthing.co.uk/pages/turing.html). Event system borrows the "every X do Y" paradigm from [Monome Teletype](https://monome.org/docs/teletype/). Crossfeed draws from the [SOMA Cosmos](https://somasynths.com/cosmos/).

Sound and behavior shaped by: **Roland RE-201 Space Echo**, **Strymon Magneto and Volante**, **Valhalla Delay**, **Loudest Warning Analog Delay**, **XAOC Sarajewo**.
