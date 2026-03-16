# fx_llll

### four lines

A multitap delay that started with a boilerplate and turned into something with its own voice. Four delay lines, each with its own feel, level, pan, and feedback – feeding through a shared chain of filter, saturation, and chorus. A shift register generates evolving patterns. A clock-synced event system creates structural disruptions. The kind of delay that rewards curiosity.

Built for the [norns fx mod framework](https://llllllll.co/t/fx-mod-framework/). Named after the four delay lines – and [llllllll.co](https://llllllll.co/), the lines forum, where norns musicians have been building and sharing since the beginning.

No external UGens required.

---

## How it got here

fx_llll didn't start as fx_llll. I started with a port of justmat's Greyhole reverb script into the fx mod framework – an exercise in understanding how mods work, how SuperCollider talks to Lua via OSC, and where the audio actually goes. That port worked. Then came a Pools port. That worked too. Then the question became: what if instead of porting someone else's effect, I design one from scratch?

The first version was a straightforward multitap delay. Four `DelayL` instances, a lowpass filter in the feedback path, tempo sync via `clock.get_tempo()`. It worked, but it was boring – the kind of delay you set once and forget about. The interesting question wasn't "how do I build a delay" but "how do I build a delay that changes over time in ways I can't fully predict but can still steer?"

That's when the Turing Machine came in. Tom Whitwell's shift register module for Eurorack is one of those designs where the simplicity of the mechanism – shift a register, maybe flip a bit – produces complexity that feels musical rather than arbitrary. Porting that concept to Lua was straightforward. The less obvious part was figuring out what to modulate. Delay times were the first target, but it turned out that modulating feedback amounts, filter frequencies, per-tap levels, and stereo positions was often more interesting – especially when each tap reads the register from a different bit rotation, so four related-but-distinct patterns emerge from a single sequence.

The event system came from a different direction entirely. Monome Teletype's "every X do Y" is a way of thinking about time as something you can program – not just subdivide. The idea of periodically flipping all pan positions, or temporarily muting the send, or briefly destabilizing the shift register's pattern, adds a structural rhythm that sits on top of whatever the delay and modulation are already doing. It's the difference between a texture and a composition.

Per-tap feedback was a late addition that changed everything. When each line has its own feedback amount, the four lines stop being four copies of the same thing and start being four different instruments. Line 1 with 80% feedback becomes a drone generator. Line 4 with 10% feedback becomes a single slapback. Same delay, completely different character per voice.

The filter, saturation, and chorus were originally in the feedback path – meaning the first echo came through clean and only subsequent repetitions were processed. This sounded wrong. In a real tape echo, the first playback head already colors the sound. Moving the processing chain to the output path (where every echo, including the first, passes through) was a small change in the code and a large change in the sound. The tradeoff: processing doesn't accumulate across feedback passes. But that's what the feedback path's tanh limiter is for – it adds its own subtle saturation that builds with each repetition.

The name came last. Four l's. Four lines. Four delay lines. And four vertical strokes that look like a waveform, or like the bars of a delay visualization, or like nothing at all – depending on how you look at them.

---

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

**File structure for reference:**

```
dust/code/fx_llll/
├── lib/
│   └── mod.lua
└── llll.sc
```

---

## Signal flow

```
input --> send level --> + --> delay lines --> split
                         ^                       |
                         |            +----------+----------+
                         |            |                     |
                         |      feedback path          output path
                         |            |                     |
                         |       fb per line         level per line
                         |      pan per line          pan per line
                         |            |                     |
                         |          tanh                 filter
                         |            |                     |
                         +------------+                saturation
                                                            |
                                                         chorus
                                                            |
                                                           out
```

The output path carries every echo through filter, saturation, and chorus – so the first repetition already has full character. The feedback path is raw, with only a tanh safety limiter that soft-clips when feedback exceeds unity gain. This split means: processing colors the sound you hear, while feedback preserves the dynamics needed for natural echo behavior.

When delay times change – whether you turn an encoder, switch subdivisions, or the shift register mutates – you hear pitch sweep as the lines catch up. This 200ms glide is the same behavior as changing motor speed on a tape delay. The Turing Machine exploits this: target "tap time" and listen to the lines pitch-shift in evolving patterns.

---

## Parameters

### Slot

| Parameter | Options |
|-----------|---------|
| **slot** | none / send a / send b / insert |

### Taps

Four lines, always active. Each has its own feel mode that determines how the delay time is derived. Depending on the feel, either **subdiv** or **time** is visible.

| Parameter | Range | Unit | Defaults (1 / 2 / 3 / 4) |
|-----------|-------|------|---------------------------|
| **feedback** | 0–105 | % | 50, 50, 50, 50 |
| **feel** | note / dotted / triplet / msec | – | note |
| **level** | 0–100 | % | 100, 75, 50, 25 |
| **pan** | -1.00 to 1.00 | – | -0.5, 0.5, -0.5, 0.5 |
| **subdiv** | 1/1–1/64 | – | 1/1, 1/2, 1/4, 1/8 |
| **time** | 1–1000 | ms | 1000, 500, 250, 125 |

**feel modes:** **note** = even subdivision locked to tempo, **dotted** = 1.5× the subdivision (the gallop – ubiquitous in dub and ambient), **triplet** = 2/3× (three in the space of two, instant swing), **msec** = free time in milliseconds, independent of tempo. You can mix feel modes across lines: three synced to the clock and one running free, or any other combination.

**On feedback at 105%:** Pushing past unity means the signal grows with each pass. The tanh limiter in the feedback path soft-clips this into warm, saturated self-oscillation – similar to a Space Echo feeding back into distortion. This is a creative tool, not a mistake. But it requires care. See the safety section.

**Maximum delay time** is 1 second per line. Longer subdivision values at slow tempos are clamped.

### Filter

A multimode filter in the output path. Every echo passes through it.

| Parameter | Range | Unit | Default |
|-----------|-------|------|---------|
| **filter type** | low / band / high | – | low |
| **frequency** | 20–20000 | hz | 2500 (low) / 250 (high) |
| **frequency bottom** | 20–20000 | hz | 250 |
| **frequency top** | 20–20000 | hz | 2500 |
| **slope** | 6 / 12 / 24 / 48 | dB | 12 dB |

Switching filter type resets frequency to musical defaults: **low** → 2500 hz, **high** → 250 hz, **band** → 250/2500 hz. For low and high types, a single frequency parameter is shown. For band, separate frequency bottom and top parameters appear – these are cross-clamped so bottom can never exceed top.

Frequency parameters use exponential scaling: fine control at low values, coarser at high values – matching how we perceive pitch. Display adapts to magnitude: integers above 100 hz, one decimal between 10–99 hz, two decimals below 10 hz.

### Saturation

| Parameter | Range | Unit | Default |
|-----------|-------|------|---------|
| **saturation** | 0–100 | % | 0 |

Tanh soft clipping. At 30% you get warmth. At 70% you get crunch. At 100% you get a wall. Because saturation sits in the output path, even the first echo is affected – you don't need feedback for it to color the sound.

### Chorus

| Parameter | Range | Unit | Default |
|-----------|-------|------|---------|
| **depth** | 0–100 | % | 0 |
| **rate** | 0.01–10000 | hz | 1.0 |

A delay-line chorus that modulates all echoes. The range is deliberately extreme. At 0.3 hz and 20% depth, you get classic tape wobble – the echoes shimmer like sunlight on water. At 2000 hz and 60% depth, the delay becomes a ring modulator, each echo transformed into metallic sidebands. The boundary between chorus and FM synthesis is where the interesting things happen, and this parameter range lets you explore all of it.

### Modulation TM

A shift register inspired by Tom Whitwell's [Turing Machine](https://musicthing.co.uk/pages/turing.html). Instead of generating random voltages for a synthesizer, it generates evolving patterns that modulate delay parameters.

Set **steps > 0** to activate. Some parameters are conditionally visible depending on **mod assign**.

| Parameter | Range | Unit | Default | Visibility |
|-----------|-------|------|---------|------------|
| **mod assign** | 10 targets | – | subdiv | always |
| **mod bottom** | 1/1–1/64 | – | 1/4 | subdiv only |
| **mod depth** | 0–100 | % | 100 | not subdiv |
| **mod direction** | + / - / + & - | – | - | not subdiv |
| **mod top** | 1/1–1/64 | – | 1/32 | subdiv only |
| **slew rate** | 0–2000 | ms | 0 | always |
| **step rate** | 1/1–1/16 | – | 1/4 | always |
| **step stability** | 0–100 | % | 50 | always |
| **steps** | off / 1–16 | – | off | always |

**step stability** controls how much the pattern mutates. At 100%, the pattern is completely locked – it repeats exactly every N steps (where N = register length). At 0%, every step is fully random. The interesting territory is in between: at 50%, the pattern is recognizable but slowly drifting, like a musician who keeps almost-but-not-quite playing the same phrase.

**mod depth** limits the swing to ±100% of the base value. A parameter set to 50% can be modulated up to 100% or down to 0%, but not beyond. Absolute parameter limits are always enforced on top of this.

**mod direction** offers three modes: **+** (high register value pushes the parameter up), **-** (high register value pushes it down), and **+ & -** (bipolar – the register swings both ways from the base value).

**slew rate** at 0 ms means instant, hard steps – gate-like modulation. At 500 ms, transitions are smooth. At 2000 ms, the shift register's discrete steps dissolve into slow, flowing movement.

Parameters currently being modulated by the TM are marked with **(M)** in the parameter menu.

**Available targets:**

| Target | What it modulates | Per-line? |
|--------|-------------------|-----------|
| **chorus depth** | Chorus wet/dry | no |
| **chorus rate** | Chorus modulation speed | no |
| **feedback** | Per-line feedback amount | yes |
| **filter** | All filter frequencies | no |
| **saturation** | Drive amount | no |
| **send level** | Input VCA before delay | no |
| **subdiv** | Delay subdivisions | yes |
| **tap level** | Per-line output volume | yes |
| **tap pan** | Per-line stereo position | yes |
| **tap time** | Per-line delay time directly | yes |

For per-line targets, each line reads the shift register from a different bit rotation – four related but distinct modulation values from one pattern.

### Every x/y do z

Clock-synced disruptions inspired by Monome Teletype's "every X do Y" paradigm. A toggle mechanism: every X of Y beats, the action fires. Next X of Y beats, it undoes itself.

| Parameter | Range | Default |
|-----------|-------|---------|
| **temp action** | off / flip pans / mute send / mute taps / all fb min / all fb max / stability -5% / -10% / -25% | off |
| **every** | 1–8 | 1 |
| **of** | 1–32 | 8 |
| **slew rate** | 0–2000 ms | 0 |

The **every** and **of** parameters combine to set the event timing: every 1 of 8 = every 8th beat. Every 3 of 16 = every 3/16 note. Odd denominators are supported – every 1 of 7 creates a 7-beat cycle, every 3 of 5 creates a pattern that phases against 4/4 time.

**slew rate** controls the transition speed for event actions independently of the TM's slew rate. The TM slew is restored after each event undo.

Parameters affected by an active event are marked with **(M)** in the parameter menu.

**Actions:**

- **flip pans** – all pan positions negate. The stereo image mirrors every X of Y beats. (M) on: tap 1–4 pan.
- **mute send** – input VCA drops to zero. Existing echoes ring out but nothing new enters. The delay tail decays cleanly.
- **mute taps** – all line levels drop to zero. Silence, then restoration. (M) on: tap 1–4 level.
- **all fb min** – all feedback snaps to zero. Echoes die immediately. (M) on: tap 1–4 feedback.
- **all fb max** – all feedback snaps to 105%. Sudden, intense resonance. (M) on: tap 1–4 feedback.
- **stability -5% / -10% / -25%** – temporarily reduces the shift register's step stability, injecting more randomness into the TM pattern. Reverts on undo. (M) on: step stability.

---

## Recipes

**Ambient wash.** All four lines in note mode: 1/1, 1/2, 1/4, 1/8. Filter type = low, frequency = 1500 hz, slope = 24 dB. Saturation = 15%. Feedback at 40% per line. Chorus depth = 15%, rate = 0.2 hz. Play sparse notes and let the echoes build into a bed.

**Dub delay.** One line at dotted 1/4, feedback = 60%. Other three lines: level = 0. Filter type = low, frequency = 2000 hz, 12 dB. Saturation = 40%. The classic: sparse phrases with long, darkening echoes that fill the space between notes.

**Rhythmic gate.** Modulation TM steps = 8, mod assign = tap level, mod direction = -, mod depth = 100%, step rate = 1/8, slew rate = 0 ms. Four lines stutter independently in a polyrhythmic pattern. Step stability = 20% for slow evolution. Lock it at 100% when you find a good one.

**Tape degradation.** Saturation = 50%, filter type = low at 1200 hz, slope = 48 dB. Each repetition sounds darker and grittier. Add chorus depth = 10%, rate = 0.5 hz for wobble. This is the sound of a worn machine – every pass through the output path accumulates character.

**Structural rhythm.** Every 1 of 8, temp action = flip pans. Every bar the stereo image mirrors. Combined with the TM on tap levels at a different rate, this creates large-scale rhythmic architecture from two simple mechanisms running at different speeds.

**FM delay.** Chorus rate = 3000 hz, depth = 60%. Filter type = high at 200 hz to strip the fundamentals. The echoes become metallic, bell-like – pure sidebands. The delay stops sounding like a delay and starts sounding like a synthesizer.

**Controlled chaos.** TM steps = 12, mod assign = subdiv, mod bottom = 1/8, mod top = 1/64, step stability = 40%, step rate = 1/4. Every 3 of 7, temp action = stability -25%. The four lines constantly shift subdivisions. Every 3/7 beat cycle, the pattern destabilizes further, then recovers. Music that's always almost falling apart.

**Slapback + drone.** Line 1: feel = msec, time = 80 ms, feedback = 10%, pan = -0.7. A tight slapback on the left. Line 4: feel = note, subdiv = 1/1, feedback = 90%, pan = 0.7. A slow, self-oscillating drone on the right. Same source signal, two completely different instruments.

---

## Safety

fx_llll allows per-line feedback up to 105% – above unity gain. This means the signal grows with each repetition. The tanh limiter in the feedback path prevents digital clipping, but the resulting audio can still be extremely loud and spectrally dense.

At feedback above ~80% per line with multiple lines active, the delay will self-oscillate. This is a feature – it's how many classic ambient and noise textures are created. But it requires awareness.

**Recommendations:**

- **Use a limiter** on the norns output or on the next device in your signal chain.
- **Start at low volume** when experimenting with high feedback. Self-oscillating delays can build gradually and then suddenly peak.
- **Saturation helps.** At 20–30%, the tanh waveshaping adds compression that tames peaks.
- **The event system is your safety net.** Set temp action = "all fb min" at a slow rate as a periodic reset while exploring extreme settings.
- **Protect your hearing.** This is not a disclaimer for legal purposes. It's genuine advice from someone who has startled himself more than once with this effect.

---

## Known issues

- **Send A/B routing** may not produce audible output depending on the host script's audio routing. This is a limitation of the fx mod framework's send bus architecture, not an fx_llll bug. Use insert mode for reliable operation.
- **Insert dry/wet** behavior depends on the fx mod framework's replacer synth. At extreme settings, the crossfade may not behave as expected.
- **Filter CPU:** The multimode filter computes all three types in parallel for runtime switching. At 48 dB slope this runs 12+ filter instances, I believe. If CPU is tight, use 6 or 12 dB.

---

## Dependencies

- [fx mod framework](https://llllllll.co/t/fx-mod-framework/)

---

## Credits

Built on sixolet's [fx mod framework](https://llllllll.co/t/fx-mod-framework/), which made it possible to run custom effects alongside any norns script – the architecture that this entire project depends on.

The modulation TM section is directly inspired by Tom Whitwell's [Turing Machine](https://musicthing.co.uk/pages/turing.html) for Eurorack – a design that showed how a shift register with a probability knob can produce patterns that feel simultaneously structured and unpredictable.

The event system borrows the "every X do Y" paradigm from [Monome Teletype](https://monome.org/docs/teletype/), a device that treats musical time as a programmable resource rather than just a grid to snap to.

The sound and behavior of fx_llll draws from a long line of delays that taught me what makes echoes interesting: the **Roland RE-201 Space Echo**, the grandfather of characterful delay – where degradation, motor speed, and tape saturation aren't flaws but the whole point. **Strymon's Magneto and Volante**, which showed that tape delay emulation can be a creative instrument rather than just nostalgia. **Valhalla Delay** in Ableton Live, where I first discovered what happens when you route an LFO to a delay's parameters – the practice that directly led to the modulation TM concept. The **Loudest Warning Analog Delay**, a pedal that reminded me how much character lives in simplicity and saturation. And the **XAOC Sarajewo** in Eurorack, whose approach to voltage-controlled delay time and feedback convinced me that a delay should be playable, not just configurable.

The name references the four delay lines, and [llllllll.co](https://llllllll.co/) – the lines forum, where we're all hanging out.
