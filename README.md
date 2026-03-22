# fx_llll

### four lines

A multitap delay that started with a boilerplate and turned into something with its own voice. Four delay lines, each with its own feel, level, balance, and feedback, feeding through a shared chain of filter, saturation, and chorus. A shift register generates evolving patterns. A clock-synced event system creates structural disruptions. The kind of delay that rewards curiosity.

Built for the [norns fx mod framework](https://llllllll.co/t/fx-mod-framework/). Named after the four delay lines and [llllllll.co](https://llllllll.co/), the lines forum, where norns musicians have been building and sharing since the beginning.

No external UGens required.

## Install

**Via Maiden (recommended):** Open `http://norns.local/maiden`, type the following into the matron REPL at the bottom:

```
;install https://github.com/notrobintaylor/fx_llll
```

Restart norns, activate under **SYSTEM > MODS**, restart again.

**Via SSH (manual):**

```bash
ssh we@norns.local
cd ~/dust/code
git clone https://github.com/notrobintaylor/fx_llll.git fx_llll
```

Restart norns, activate under **SYSTEM > MODS**, restart again.

## Signal flow

```
input --> send level --> + --> delay lines (stereo) --> active taps gate
                         ^                                    |
                         |                           crossfeed (1↔3, 2↔4)
                         |                                    |
                         |                        Balance2 (stereo position)
                         |                                    |
                         |            +-----------------------+
                         |            |                       |
                         |      feedback path            output path
                         |            |                       |
                         |       fb per line           level per line
                         |            |                       |
                         |          tanh               bandpass filter
                         |            |                       |
                         +------------+                  saturation
                                                              |
                                                           chorus
                                                              |
                                                             out
```

The entire signal path is stereo, no mono collapse at any point. `Balance2` preserves the input's stereo image; position 0 passes the original image through, ±1 shifts to hard left or right.

The output path carries every echo through a bandpass filter, saturation, and chorus, so the first repetition already has full character. The feedback path is raw, with only a tanh safety limiter that soft-clips when feedback exceeds unity gain.

When delay times change. whether you turn an encoder, switch time divisions, or the shift register mutates. you hear pitch sweep as the lines catch up. The **pitch glide** parameter controls this transition time (0–2500 ms, default 500 ms).

## Parameters

Parameters within each section are sorted alphabetically. Context-dependent params appear and disappear based on the current settings.

### Slot

| Parameter | Options |
|-----------|---------|
| **slot** | none / send a / send b / insert |

### Taps

Select how many lines are active with **active taps** (1–4, default 1). Inactive taps are muted and their parameters hidden.

| Parameter | Range | Unit | Defaults (1 / 2 / 3 / 4) | Visibility |
|-----------|-------|------|---------------------------|------------|
| **active taps** | 1–4 |. | 1 | always |
| **balance** | -1.00 to 1.00 |. | 0, 0, 0, 0 | active taps |
| **feedback** | 0–105 | % | 25, 25, 25, 25 | active taps |
| **feel** | note / dotted / triplet / msec |. | note | active taps |
| **level** | 0–100 | % | 50, 25, 10, 5 | active taps |
| **time** | 1–1000 | ms | 1000, 500, 250, 125 | feel = msec |
| **time div** | 1/1–1/64 |. | 1/1, 1/2, 1/4, 1/8 | feel ≠ msec |

**feel modes:** **note** = even subdivision locked to tempo, **dotted** = 1.5× (the gallop. ubiquitous in dub and ambient), **triplet** = 2/3× (instant swing), **msec** = free time, independent of tempo. Mix modes across lines freely.

**balance** preserves the input's stereo image. At 0, the echo sounds wherever the source was in the stereo field. At -1 or 1, the signal shifts hard left or right. Different from a traditional pan: a stereo synth pad stays wide at balance 0.

**On feedback at 105%:** The tanh limiter soft-clips this into warm, saturated self-oscillation. Creative tool, not a mistake. See the safety section.

**Maximum delay time** is 1 second per line.

### Filter

An always-on bandpass filter in the output path. **Filter type** sets frequency starting points; both frequencies remain freely adjustable afterward.

| Parameter | Range | Unit | Default | Visibility |
|-----------|-------|------|---------|------------|
| **filter type** | low / band / high |. | low | always |
| **frequency bottom** | 20–20000 | hz | 20 | always |
| **frequency top** | 20–20000 | hz | 2500 | always |
| **resonance** | 0–100 | % | 0 | slope ≥ 12 dB |
| **slope** | 6 / 12 / 24 / 48 | dB | 12 dB | always |

**Filter type** presets: **low** = 20/2500, **band** = 250/2500, **high** = 250/20000. Bottom and top are cross-clamped: bottom can never exceed top.

**Resonance** uses a cubic mapping for more usable range: most of the musical territory sits between 0–75%. Self-oscillation begins around 75% at 48 dB. Hidden at 6 dB slope (OnePole can't resonate).

### Saturation

| Parameter | Range | Unit | Default |
|-----------|-------|------|---------|
| **saturation** | 0–100 | % | 0 |

Tanh soft clipping in the output path. Even the first echo is affected.

### Chorus

| Parameter | Range | Unit | Default |
|-----------|-------|------|---------|
| **depth** | 0–100 | % | 0 |
| **rate** | 0.01–10000 | hz | 1.0 |

Deliberately extreme range. At 0.3 hz and 20% depth: tape wobble. At 2000 hz and 60% depth: ring modulation.

### Crossfeed

| Parameter | Range | Unit | Default |
|-----------|-------|------|---------|
| **crossfeed** | 0–100 | % | 0 |

Routes a percentage of each tap's output into its partner: line 1 ↔ 3, line 2 ↔ 4. Creates feedback paths longer than any individual delay time. Warning: additive. can lead to rapid buildup with high feedback.

### Modulation TM

A shift register inspired by Tom Whitwell's [Turing Machine](https://musicthing.co.uk/pages/turing.html). Set **steps > 0** to activate. Parameters affected by modulation are marked with **(M)** in the menu.

| Parameter | Range | Unit | Default | Visibility |
|-----------|-------|------|---------|------------|
| **assign target** | 12 targets |. | time div | always |
| **mod bottom** | 1/1–1/64 |. | 1/4 | time div only |
| **mod depth** | 0–100 | % | 100 | not time div |
| **mod direction** | + / - / + & - |. | - | not time div |
| **mod top** | 1/1–1/64 |. | 1/32 | time div only |
| **pitch glide** | 0–2500 | ms | 500 | time div + tap time |
| **slew rate** | 0–2000 | ms | 0 | all other targets |
| **step rate** | 4/1–1/16 |. | 1/4 | always |
| **step stability** | 0–100 | % | 50 | always |
| **steps** | off / 1–16 |. | off | always |

**Pitch glide** and **slew rate** are mutually exclusive. Pitch glide controls varispeed tape behavior for time-based targets. Slew rate controls parameter transition speed for everything else.

**Step stability** at 100% = locked sequence, at 0% = pure random, at 50% = recognizable but slowly drifting.

**Modulation isolation:** "time div" only modulates taps in note/dotted/triplet feel. "tap time" only modulates taps in msec feel. The two don't cross.

**Available targets:**

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
| **tap time** | Per-line delay time (msec only) | yes |
| **time div** | Delay time divisions (note only) | yes |

### Every x/y do z

Clock-synced disruptions inspired by Monome Teletype's "every X do Y" paradigm. Toggle mechanism: action fires, then undoes itself on the next cycle.

| Parameter | Range | Default | Visibility |
|-----------|-------|---------|------------|
| **assign target** | off / 9 actions | off | always |
| **chance** | off / 1–100% | off | always |
| **every** | 1–8 | 1 | always |
| **of** | 1–32 | 8 | always |
| **reset after** | off / 2–64 | off | always |
| **slew rate** | 0–2000 ms | 0 | always |

**Chance** adds a probability gate. A missed trigger means the current state persists. **Reset after** counts successful toggles and restarts the clock as a safety net for chance.

**Actions:** flip balance, mute send, mute taps, all feedback min, all feedback max, stability -5%/-10%/-25%, flip levels.

## Recipes

**Ambient wash.** Active taps = 4, all note feel: 1/1, 1/2, 1/4, 1/8. Filter type = low, top = 1500, slope = 24 dB. Saturation = 15%. Feedback = 40%. Chorus depth = 15%, rate = 0.2 hz.

**Dub delay.** Active taps = 1. Dotted 1/4, feedback = 60%. Filter type = low, top = 2000. Saturation = 40%.

**Rhythmic gate.** Active taps = 4. TM steps = 8, assign target = tap level, direction = -, depth = 100%, step rate = 1/8, slew = 0 ms. Stability = 20%.

**Tape degradation.** Saturation = 50%, filter type = low, top = 1200, slope = 48 dB. Chorus depth = 10%, rate = 0.5 hz.

**Structural rhythm.** Every 1 of 8, assign target = flip balance. Combined with TM on tap levels at a different rate.

**FM delay.** Chorus rate = 3000 hz, depth = 60%. Filter type = high, bottom = 200. Metallic, bell-like echoes.

**Controlled chaos.** Active taps = 4. TM steps = 12, assign target = time div, bottom = 1/8, top = 1/64, stability = 40%, rate = 1/4. Every 3 of 7, assign target = stability -25%, chance = 70%, reset after = 8.

**Slapback + drone.** Active taps = 2. Line 1: msec, 80 ms, feedback = 10%, balance = -0.7. Line 2: note, 1/1, feedback = 90%, balance = 0.7.

**Resonant sweep.** Filter type = band, bottom = 200, top = 800, slope = 24 dB, resonance = 70%. TM steps = 8, assign target = filter frequency, rate = 1/4, slew = 500 ms.

**Crossfeed conversation.** Active taps = 4. Time divs 1/4, 1/8, 1/16, 1/32. Crossfeed = 30%, feedback = 35%.

## Safety

fx_llll allows per-line feedback up to 105%. The tanh limiter prevents digital clipping, but audio can still be extremely loud.

Crossfeed adds another dimension of feedback energy. Even moderate crossfeed with moderate feedback can build up, because the total feedback path is longer than any individual line.

**Recommendations:**

- **Use a limiter** on the norns output or on the next device in your signal chain.
- **Start at low volume** when experimenting with high feedback.
- **Saturation helps.** At 20–30%, the tanh waveshaping adds compression that tames peaks.
- **The event system is your safety net.** Set assign target = "all feedback min" at a slow rate while exploring extreme settings.
- **Be cautious with crossfeed.** Start low.
- **Protect your hearing.** Genuine advice from someone who has startled himself more than once.

## Known issues

- **Send A/B routing** may not produce audible output depending on the host script's audio routing. Use insert mode for reliable operation.
- **Insert dry/wet** behavior depends on the fx mod framework's replacer synth.
- **Filter CPU at 48 dB:** Four cascaded RLPF + RHPF stages. If CPU is tight, use 6 or 12 dB.
- **Crossfeed + high feedback** can produce rapid, loud self-oscillation.

## Changelog

### 2.0

**Architecture**

- Full stereo signal path. No mono collapse. `Balance2` replaces `Mix.ar` + `Pan2.ar`. The input's stereo image survives into every echo. Balance at 0 means "pass through unchanged."
- Bandpass-only filter. The filter type selector (low/band/high) now sets starting frequencies rather than switching filter topology. Two frequency knobs always define the passband window. One chain instead of three parallel chains = significant CPU savings.
- Resonance on the bandpass. RLPF/RHPF at 12 dB and above. Both band edges can resonate independently. Cubic mapping curve: self-oscillation starts around 75% at 48 dB, giving most of the knob range to musically useful territory.
- Active taps parameter. Choose 1–4 active delay lines. Inactive taps are muted at the SynthDef level and their parameters hidden in the menu. Default is 1. a single centered delay as starting point.
- Crossfeed between taps. Pairs 1↔3 and 2↔4. Additive: signal circulates between paired taps, creating feedback paths longer than any individual delay.
- Pitch glide as parameter. Delay time transitions via `.lag()` on `DelayC`. varispeed tape behavior. Range 0–2500 ms (default 500 ms). Mutually exclusive with slew rate in the TM section.

**Modulation**

- 12 TM targets (was 10). New: crossfeed, filter resonance. Renamed: feedback → tap feedback, filter → filter frequency.
- Modulation isolation. "time div" only affects note/dotted/triplet taps. "tap time" only affects msec taps. They don't cross-contaminate.
- Longer step rates: 4/1 and 2/1. At 60 BPM, 4/1 = one step every 16 seconds.
- Pitch glide / slew rate mutual exclusion. Time-based targets show pitch glide, all others show slew rate.

**Events**

- Flip levels action. Mirrors each tap's level around 50%. Self-undoing.
- Chance parameter. Probability gate on event triggers (0 = always, 1–100%).
- Reset after parameter. Counts successful toggles, restarts clock. Safety net for chance.
- Force-restore on action change. Switching or disabling the event action immediately restores all affected parameters to base values. Fixes the stale-feedback bug.

**Defaults**

- Quieter: levels 50/25/10/5 (was 100/75/50/25), feedback 25% (was 50%), all pans centered (was alternating L/R).
- Filter defaults to low (bottom=20, top=2500) instead of bypass.

**Naming**

- pan → balance (reflects stereo behavior, not mono placement)
- subdiv → time div
- mod assign → assign target
- temp action → assign target
- All parameters sorted alphabetically within their sections.

### 1.0

Initial release. Four delay lines, multimode filter, saturation, chorus, Turing Machine modulation, clock-synced event system.

## Dependencies

- [fx mod framework](https://llllllll.co/t/fx-mod-framework/)

## Credits

Built on sixolet's [fx mod framework](https://llllllll.co/t/fx-mod-framework/).

Modulation inspired by Tom Whitwell's [Turing Machine](https://musicthing.co.uk/pages/turing.html). Event system borrows the "every X do Y" paradigm from [Monome Teletype](https://monome.org/docs/teletype/).

Sound and behavior draws from: the **Roland RE-201 Space Echo**, **Strymon Magneto and Volante**, **Valhalla Delay**, the **Loudest Warning Analog Delay**, the **XAOC Sarajewo**, and the **SOMA Cosmos**.

The name references the four delay lines, and [llllllll.co](https://llllllll.co/). the lines forum, where we're all hanging out.
