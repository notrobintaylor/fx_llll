# fx_llll

### four lines

A multitap delay that started with a boilerplate and turned into something with its own voice. Four delay lines, each with its own feel, level, balance, and feedback, feeding through a shared chain of filter, saturation, and chorus. A shift register generates evolving patterns. A clock-synced event system creates structural disruptions. The kind of delay that rewards curiosity.

Built for the [norns fx mod framework](https://llllllll.co/t/fx-mod/62726/99)). Named after the four delay lines and [llllllll.co](https://llllllll.co/), the lines forum, where norns musicians have been building and sharing since the beginning.

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

**feel modes:** **note** = even subdivision locked to tempo, **dotted** = 1.5×, **triplet** = 2/3×, **msec** = free time, independent of tempo. Mix modes across lines freely.

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

## User stories

### 1.0

**Taps**

- I want four independent delay lines so that I can create polyrhythmic echo textures from a single source.
- I want per-tap feedback control so that each line can have a different character, from tight slapback to self-oscillating drone.
- I want to choose between note, dotted, triplet, and msec feel per tap so that I can mix clock-synced and free-running delay times.
- I want dotted feel so that I get the classic dub/ambient gallop without manual calculation.
- I want triplet feel so that I can create swing-like echo patterns locked to tempo.
- I want msec feel so that I can set delay times independent of tempo for sound design purposes.
- I want per-tap level control so that I can set the volume hierarchy across the four lines.
- I want per-tap pan control so that I can distribute echoes across the stereo field.
- I want feedback up to 105% with tanh limiting so that I can push lines into self-oscillation without digital clipping.

**Filter**

- I want a multimode filter in the output path so that every echo, including the first, is already colored.
- I want to switch between lowpass, bandpass, and highpass so that I can shape the echo spectrum to fit the mix.
- I want filter slope options from 6 to 48 dB so that I can choose between gentle rolloff and aggressive cuts.

**Saturation**

- I want tanh saturation in the output path so that I can add warmth or crunch to every echo.

**Chorus**

- I want a chorus with extreme rate range so that I can go from subtle tape wobble to ring modulation.

**Modulation TM**

- I want a Turing Machine shift register so that I get evolving, semi-random modulation patterns that feel musical.
- I want adjustable step stability so that I can lock a pattern, let it drift, or go fully random.
- I want to assign the TM to different parameters so that the same pattern can modulate delay times, feedback, levels, filter, or other targets.
- I want per-tap bit rotation on the register so that four lines get related but distinct modulation values from one pattern.
- I want mod depth control so that I can limit how far the TM swings a parameter from its base value.
- I want mod direction (+, -, bipolar) so that I can control whether the register pushes values up, down, or both ways.
- I want time division modulation with top/bottom range so that the TM picks from a defined set of subdivisions.
- I want a slew rate on TM modulation so that I can smooth discrete steps into flowing transitions.
- I want a step rate control so that I can set how fast the register advances relative to tempo.
- I want (M) markers on modulated parameters so that I can see at a glance which params the TM is currently affecting.

**Events**

- I want a clock-synced event system so that structural disruptions happen at musically meaningful intervals.
- I want the toggle mechanism (do/undo) so that every event action automatically reverts, keeping the performance stable.
- I want "every X of Y" timing so that I can create event cycles that phase against the time signature.
- I want odd denominators so that events create asymmetric rhythmic patterns (7-beat cycles, 5-beat cycles).
- I want flip pans as an event action so that the stereo image periodically mirrors itself.
- I want mute send as an event action so that the delay tail rings out cleanly while new input is temporarily silenced.
- I want mute taps as an event action so that I get periodic silence followed by restoration.
- I want all feedback min/max as event actions so that I can create sudden echo death or intense resonance bursts.
- I want stability reduction as an event action so that the TM pattern periodically destabilizes and recovers.
- I want event slew rate so that event transitions can be instant or gradual, independent of TM slew.
- I want (M) markers on event-affected params so that I can see which parameters are currently overridden.

**Infrastructure**

- I want the mod to work with any script via the fx mod framework so that I don't have to choose between fx_llll and my favorite sequencer.
- I want tempo-synced delay times that update when BPM changes so that echoes stay in time without manual adjustment.
- I want clean state restoration on script cleanup so that switching scripts doesn't leave stale audio or feedback.

### 2.0

**Architecture**

- I want a full stereo signal path so that the input's spatial character survives into every echo instead of being collapsed to mono.
- I want Balance2 instead of Pan2 so that stereo sources stay wide at balance 0 instead of being mono-summed and repositioned.
- I want to choose how many taps are active (1 to 4) so that I can start simple and add complexity as needed.
- I want inactive taps muted at the SynthDef level so that unused lines don't waste CPU or clutter the parameter menu.
- I want the default to be one centered delay line so that the first experience is clean and inviting, not four lines at full volume.

**Filter**

- I want the filter to always be a bandpass with two frequency knobs so that I can carve a window from both ends simultaneously.
- I want filter type as a convenience shortcut that sets starting frequencies so that I can quickly jump to low/band/high without losing the ability to fine-tune.
- I want resonance on both edges of the bandpass so that the low cutoff and high cutoff can sing independently.
- I want a cubic resonance mapping so that most of the knob range is musically useful and self-oscillation doesn't start until around 75%.
- I want resonance hidden at 6 dB slope so that I don't see a parameter that has no effect.

**Crossfeed**

- I want crossfeed between tap pairs (1↔3, 2↔4) so that signal circulates between lines, creating feedback paths longer than any single delay.
- I want crossfeed to be additive so that the interaction between lines is audible even at low settings.

**Pitch glide**

- I want pitch glide as a parameter so that delay time changes produce controllable varispeed tape behavior.
- I want pitch glide range up to 2500 ms so that I can create anything from quick chirps to slow, sustained detuning.
- I want pitch glide and slew rate to be mutually exclusive so that time-based and parameter-based transitions don't interfere with each other.

**Modulation**

- I want crossfeed as a TM target so that the interaction between tap pairs evolves over time.
- I want filter resonance as a TM target so that the filter peak sweeps with the shift register.
- I want time div modulation to only affect note-feel taps so that my msec taps stay at their manual settings.
- I want tap time modulation to only affect msec-feel taps so that my clock-synced taps stay at their subdivisions.
- I want step rates of 4/1 and 2/1 so that the register can shift at geological speed for long ambient sessions.

**Events**

- I want flip levels as an event action so that the volume hierarchy periodically inverts (quiet taps become loud and vice versa).
- I want a chance parameter on events so that some triggers are probabilistically skipped, creating unpredictable event durations.
- I want reset after so that the event clock re-syncs after a set number of toggles, preventing indefinite drift from skipped triggers.
- I want force-restore when switching event actions so that changing or disabling an action immediately returns all affected parameters to their base values without stale state.

**Defaults and naming**

- I want quieter defaults (levels 50/25/10/5, feedback 25%) so that the first encounter is inviting rather than overwhelming.
- I want all pans centered by default so that a single active tap starts in the middle, not offset to one side.
- I want "balance" instead of "pan" so that the parameter name reflects its actual stereo behavior.
- I want "time div" instead of "subdiv" so that the parameter name is immediately clear without musical jargon.
- I want parameters sorted alphabetically within each section so that I can find things predictably.
- I want context-dependent parameter visibility so that I only see parameters relevant to my current settings.

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

- [fx mod framework](https://llllllll.co/t/fx-mod/62726/99)

## Credits

Built on sixolet's [fx mod framework](https://llllllll.co/t/fx-mod/62726/99).

Modulation inspired by Tom Whitwell's [Turing Machine](https://musicthing.co.uk/pages/turing.html). Event system borrows the "every X do Y" paradigm from [Monome Teletype](https://monome.org/docs/teletype/).

Sound and behavior draws from: the **Roland RE-201 Space Echo**, **Strymon Magneto and Volante**, **Valhalla Delay**, the **Loudest Warning Analog Delay**, the **XAOC Sarajewo**, and the **SOMA Cosmos**.

The name references the four delay lines, and [llllllll.co](https://llllllll.co/). the lines forum, where we're all hanging out.
