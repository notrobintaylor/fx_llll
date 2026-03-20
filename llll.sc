// =========================================================================
// FxLlll — four lines, a creative multitap delay
// =========================================================================
//
// Signal flow:
//
//   input × gain ──┬──> DelayC (line 1) ──> stereo ──┐
//      + feedback  ├──> DelayC (line 2) ──> stereo ──┤  (gated by activeTaps)
//                  ├──> DelayC (line 3) ──> stereo ──┤
//                  └──> DelayC (line 4) ──> stereo ──┘
//                                                    │
//                            crossfeed (1↔3, 2↔4)    │
//                                                    │
//                               ┌────────────────────┤
//                               │                    │
//   OUTPUT PATH:                │   FEEDBACK PATH:   │
//     Balance2 × level → sum    │   Balance2 × fb → sum
//              │                │              │
//       bandpass filter         │          tanh limiter
//        (always-on BP)         │              │
//              │                │         LocalOut → back
//         saturation            │
//              │                │
//         chorus                │
//              │                │
//             OUT               │
//
// Full stereo path: no mono collapse. Balance2 preserves the input
// stereo image; position 0 = original, ±1 = hard L/R.
// Bandpass-only filter: bottom freq + top freq define the window.
// Bottom=20, Top=20k = bypass. RLPF/RHPF at 12+ dB for resonance.
// Feedback path: raw + tanh safety limiter.
// Crossfeed circulates signal between taps (1↔3, 2↔4).
// DelayC (cubic interp) + pitchGlide lag = pitch-shifting on time changes.
// Feedback up to 105% with tanh safety. Max delay 1s. No ext. UGens.
// =========================================================================

FxLlll : FxBase {

    *new {
        var ret = super.newCopyArgs(nil, \none, (
            time1: 0.5, time2: 0.25, time3: 0.125, time4: 0.0625,
            level1: 0.50, level2: 0.25, level3: 0.10, level4: 0.05,
            bal1: 0.0, bal2: 0.0, bal3: 0.0, bal4: 0.0,
            feedback1: 0.25, feedback2: 0.25, feedback3: 0.25, feedback4: 0.25,
            activeTaps: 1,
            inputGain: 1.0,
            filterSlope: 2,
            filterFreqBottom: 20, filterFreqTop: 2500,
            resonance: 1.0,
            saturation: 0, chorusDepth: 0, chorusRate: 1.0,
            crossfeed: 0,
            pitchGlide: 0.5,
            slew: 0,
        ), nil, 0.5);
        ^ret;
    }

    *initClass { FxSetup.register(this.new); }
    subPath { ^"/fx_llll"; }
    symbol { ^\fxLlll; }

    addSynthdefs {
        SynthDef(\fxLlll, {|inBus, outBus|
            var input, fb, source, slew, pGlide;
            var tap1, tap2, tap3, tap4, active;
            var xfeed, m1, m2, m3, m4;
            var b1, b2, b3, b4;
            var l1, l2, l3, l4, fb1, fb2, fb3, fb4;
            var outSum, fbSum;
            var fSlope, fBot, fTop, rq;
            var bpC1, bpC2, bp6, bp12, bp24, bp36, bp48;
            var filtered, satDrive, saturated;
            var chMix, chRate, chMod, chDel, chorused;

            slew = \slew.kr(0);
            pGlide = \pitchGlide.kr(0.5);
            input = In.ar(inBus, 2) * \inputGain.kr(1.0).lag(slew);
            fb = LocalIn.ar(2);
            source = input + fb;

            // ---- DELAY LINES (stereo throughout) ----
            tap1 = DelayC.ar(source, 1, \time1.kr(0.5).lag(pGlide));
            tap2 = DelayC.ar(source, 1, \time2.kr(0.25).lag(pGlide));
            tap3 = DelayC.ar(source, 1, \time3.kr(0.125).lag(pGlide));
            tap4 = DelayC.ar(source, 1, \time4.kr(0.0625).lag(pGlide));

            // ---- ACTIVE TAPS GATING ----
            active = \activeTaps.kr(1);
            tap2 = tap2 * (active >= 2);
            tap3 = tap3 * (active >= 3);
            tap4 = tap4 * (active >= 4);

            // ---- CROSSFEED (1↔3, 2↔4) ----
            xfeed = \crossfeed.kr(0).lag(slew);
            m1 = tap1 + (tap3 * xfeed);
            m2 = tap2 + (tap4 * xfeed);
            m3 = tap3 + (tap1 * xfeed);
            m4 = tap4 + (tap2 * xfeed);

            // ---- BALANCE (shared between output and feedback) ----
            b1 = Balance2.ar(m1[0], m1[1], \bal1.kr(0.0).lag(slew));
            b2 = Balance2.ar(m2[0], m2[1], \bal2.kr(0.0).lag(slew));
            b3 = Balance2.ar(m3[0], m3[1], \bal3.kr(0.0).lag(slew));
            b4 = Balance2.ar(m4[0], m4[1], \bal4.kr(0.0).lag(slew));

            // ---- READ LEVELS + FEEDBACK ----
            l1 = \level1.kr(0.50).lag(slew);
            l2 = \level2.kr(0.25).lag(slew);
            l3 = \level3.kr(0.10).lag(slew);
            l4 = \level4.kr(0.05).lag(slew);
            fb1 = \feedback1.kr(0.25).lag(slew);
            fb2 = \feedback2.kr(0.25).lag(slew);
            fb3 = \feedback3.kr(0.25).lag(slew);
            fb4 = \feedback4.kr(0.25).lag(slew);

            // ---- OUTPUT SUM ----
            outSum = (b1*l1) + (b2*l2) + (b3*l3) + (b4*l4);

            // ---- BANDPASS FILTER on output (always-on) ----
            fSlope = \filterSlope.kr(2);
            fBot = \filterFreqBottom.kr(20).lag(slew);
            fTop = \filterFreqTop.kr(2500).lag(slew);
            rq = \resonance.kr(1.0).lag(slew);

            // 6 dB: OnePole (no resonance)
            bpC1 = (-2pi * (fBot / SampleRate.ir)).exp;
            bpC2 = (-2pi * (fTop / SampleRate.ir)).exp;
            bp6 = OnePole.ar(outSum - OnePole.ar(outSum, bpC1), bpC2);

            // 12–48 dB: cascaded RLPF + RHPF (resonant)
            bp12 = RLPF.ar(RHPF.ar(outSum, fBot, rq), fTop, rq);
            bp24 = RLPF.ar(RHPF.ar(bp12, fBot, rq), fTop, rq);
            bp36 = RLPF.ar(RHPF.ar(bp24, fBot, rq), fTop, rq);
            bp48 = RLPF.ar(RHPF.ar(bp36, fBot, rq), fTop, rq);

            filtered = Select.ar(fSlope - 1, [bp6, bp12, bp24, bp48]);

            // ---- SATURATION on output ----
            satDrive = 1 + (\saturation.kr(0).lag(slew) * 9);
            saturated = (filtered * satDrive).tanh;

            // ---- CHORUS on output ----
            chMix = \chorusDepth.kr(0).lag(slew) * 0.01;
            chRate = \chorusRate.kr(1.0);
            chMod = SinOsc.ar(chRate) * chMix * 0.005;
            chDel = (0.005 + chMod).max(0.0001);
            chorused = XFade2.ar(saturated, DelayC.ar(saturated, 0.01, chDel), chMix * 2 - 1);

            Out.ar(outBus, chorused);

            // ---- FEEDBACK PATH (raw + tanh safety limiter) ----
            fbSum = (b1*fb1) + (b2*fb2) + (b3*fb3) + (b4*fb4);

            LocalOut.ar(fbSum.tanh);
        }).add;
    }
}
