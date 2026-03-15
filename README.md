# fx_llll

### four lines

A multitap delay that invites you to treat echoes as compositional material. Four delay lines, each with its own character, feeding through a shared signal path of filter, saturation, and chorus. A shift register generates evolving patterns that modulate nearly any parameter. An event system creates rhythmic disruptions on a clock-synced schedule.

Built for the [norns fx mod framework](https://llllllll.co/t/fx-mod-framework/). Named after the four delay lines — and the [lines forum](https://llllllll.co/), where norns musicians have been sharing ideas since the beginning.

No external UGens required.

---

## Install

```
dust/code/fx_llll/
├── lib/
│   └── mod.lua
└── llll.sc
```

```bash
ssh we@norns.local
mkdir -p ~/dust/code/fx_llll/lib
```

Copy `llll.sc` and `mod.lua` to the paths above. Restart norns, activate under **SYSTEM > MODS**, restart again.

---

## Signal flow

```
input ──> send level ──┬──> line 1 ──> mono ──┐
                       ├──> line 2 ──> mono ──┤
                       ├──> line 3 ──> mono ──┤
                       └──> line 4 ──> mono ──┘
                                              │
                    ┌─────────────────────────┤
                    │                         │
    OUTPUT PATH:    │        FEEDBACK PATH:   │
      × level × pan → sum     × fb × pan → sum
           │                       │
       filter                    tanh
           │                       │
       saturation                back
           │
       chorus
           │
          OUT
```

Effects (filter, saturation, chorus) are in the output path — every echo you hear, including the first, has full character. The feedback path is raw with only a tanh safety limiter, preserving dynamics for natural feedback behavior.

When delay times change — manually or via modulation™ — you hear pitch sweep as the lines catch up. This 200ms glide is the same behavior as changing motor speed on a tape delay.

---

## Parameters

### Slot

| Parameter | Options |
|-----------|---------|
| **slot** | none / send a / send b / insert |

### Taps

| Parameter | Range | Unit | Defaults (1/2/3/4) |
|-----------|-------|------|---------------------|
| **feedback** | 0–105 | % | 50, 50, 50, 50 |
| **feel** | note / dotted / triplet / msec | — | note |
| **level** | 0–100 | % | 100, 75, 50, 25 |
| **pan** | -1.00 to 1.00 | — | -0.5, 0.5, -0.5, 0.5 |
| **subdiv** | 1/1–1/64 | — | 1/1, 1/2, 1/4, 1/8 |
| **time** | 1–1000 | ms | 1000, 500, 250, 125 |

Subdiv is visible when feel ≠ msec. Time is visible when feel = msec.

Feedback at 105% exceeds unity gain — the signal grows with each repetition. The tanh limiter in the feedback path soft-clips this into warm self-oscillation. **Use with caution.** See the safety section below.

### Filter

| Parameter | Range | Unit | Default |
|-----------|-------|------|---------|
| **filter type** | low / band / high | — | low |
| **frequency** | 20–20000 | hz | 2500 (low) / 250 (high) |
| **frequency bottom** | 20–20000 | hz | 250 |
| **frequency top** | 20–20000 | hz | 2500 |
| **slope** | 6 / 12 / 24 / 48 | dB | 12 dB |

Filter type sorts first. Switching type resets frequency to musical defaults (low→2500 Hz, high→250 Hz, band→250/2500 Hz). Frequency is shown for low/high; frequency bottom + top for band. Bottom and top are cross-clamped.

### Saturation

| Parameter | Range | Unit | Default |
|-----------|-------|------|---------|
| **saturation** | 0–100 | % | 0 |

### Chorus

| Parameter | Range | Unit | Default |
|-----------|-------|------|---------|
| **depth** | 0–100 | % | 0 |
| **rate** | 0.01–10000 | hz | 1.0 |

### modulation™

| Parameter | Range | Unit | Default | Visibility |
|-----------|-------|------|---------|------------|
| **change probability** | 0–100 | % | 50 | always |
| **mod assign** | 10 targets | — | subdiv | always |
| **mod bottom** | 1/1–1/64 | — | 1/4 | subdiv only |
| **mod depth** | 0–100 | % | 100 | not subdiv |
| **mod direction** | + / - / + & - | — | - | not subdiv |
| **mod rate** | 1/1–1/16 | — | 1/4 | always |
| **mod top** | 1/1–1/64 | — | 1/32 | subdiv only |
| **slew** | 0–2.0 | s | 0 | always |
| **steps** | 0–16 | — | 0 | always |

### every x/y temporary do z

| Parameter | Options | Default |
|-----------|---------|---------|
| **action** | nothing / flip pans / mute taps / all fb min / all fb max / change -5% / -10% / -25% | nothing |
| **rate** | 8/1–1/64 | 1/1 |

---

## Safety

fx_llll allows per-line feedback up to 105%. At high feedback with multiple lines active, the delay will self-oscillate. The tanh limiter prevents digital clipping but the output can still be very loud.

**Recommendations:**

- Use a limiter on your signal chain.
- Start at low volume when experimenting with high feedback.
- Saturation at 20–30% adds compression that helps tame peaks.
- The event system "all fb min" action is your safety net.
- **Protect your hearing.** Self-oscillating delays can build suddenly.

---

## Known issues

- **Send A/B** may not produce output depending on the host script's audio routing. Use insert mode for reliable operation.
- **Insert dry/wet** behavior depends on the fx mod framework's replacer synth.

---

## Credits

Built on the [fx mod framework](https://llllllll.co/t/fx-mod-framework/). modulation™ inspired by [Music Thing Modular's Turing Machine](https://musicthing.co.uk/pages/turing.html). Event system inspired by [Monome Teletype](https://monome.org/docs/teletype/).
