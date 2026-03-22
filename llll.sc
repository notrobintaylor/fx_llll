// =========================================================================
// FxLlll — four-tap stereo delay for the norns fx mod framework
// =========================================================================
//
//   input × gain ──┬──> DelayC × 4 (stereo) ──> active taps gate
//      + feedback  │                                    |
//                  │                              crossfeed (1↔3, 2↔4)
//                  │                                    |
//                  │                              Balance2 (position)
//                  │                                    |
//                  │                +-------------------+
//                  │                |                   |
//                  │          feedback path        output path
//                  │                |                   |
//                  │           fb × Balance2      level × Balance2
//                  │                |                   |
//                  │              tanh             bandpass filter
//                  │                |                   |
//                  +────────────────+              saturation
//                                                      |
//                                                   chorus
//                                                      |
//                                                     OUT
//
// Design decisions:
//   - Full stereo throughout: Balance2 preserves input image, no mono collapse
//   - Processing in output path only: first echo already has character
//   - Feedback path is raw + tanh: dynamics preserved for natural decay
//   - Bandpass-only: two frequencies replace the type selector (LP=20/x, HP=x/20k)
//   - RLPF/RHPF at 12+ dB: both band edges can resonate independently
//   - Crossfeed is additive (not energy-conserving): tanh catches runaway
//   - pitchGlide on DelayC.lag: varispeed tape behavior on time changes
// =========================================================================

FxLlll : FxBase {

    // defaults sent to SC on boot — must match Lua base state
    *new {
        var ret = super.newCopyArgs(nil, \none, (
            time1: 0.5, time2: 0.25, time3: 0.125, time4: 0.0625,
            level1: 0.50, level2: 0.25, level3: 0.10, level4: 0.05,
            bal1: 0.0, bal2: 0.0, bal3: 0.0, bal4: 0.0,
            feedback1: 0.25, feedback2: 0.25, feedback3: 0.25, feedback4: 0.25,
            activeTaps: 1,
            inputGain: 1.0,
            filterSlope: 2,            // 12 dB default
            filterFreqBottom: 20,
            filterFreqTop: 2500,       // matches filter type = low
            resonance: 1.0,            // rq=1.0 = flat (no peak)
            saturation: 0, chorusDepth: 0, chorusRate: 1.0,
            crossfeed: 0,
            pitchGlide: 0.5,          // 500ms lag on delay time changes
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

            // ---- DELAY LINES ----
            // stereo in, stereo out — no Mix.ar, no mono collapse
            // .lag(pGlide) = varispeed: read head accelerates/decelerates through buffer
            tap1 = DelayC.ar(source, 1, \time1.kr(0.5).lag(pGlide));
            tap2 = DelayC.ar(source, 1, \time2.kr(0.25).lag(pGlide));
            tap3 = DelayC.ar(source, 1, \time3.kr(0.125).lag(pGlide));
            tap4 = DelayC.ar(source, 1, \time4.kr(0.0625).lag(pGlide));

            // ---- ACTIVE TAPS ----
            // BinaryOpUGen: 0 or 1, no branch, no CPU waste on inactive taps' DSP
            active = \activeTaps.kr(1);
            tap2 = tap2 * (active >= 2);
            tap3 = tap3 * (active >= 3);
            tap4 = tap4 * (active >= 4);

            // ---- CROSSFEED (1↔3, 2↔4) ----
            // additive: total energy can exceed input at high xfeed + feedback
            xfeed = \crossfeed.kr(0).lag(slew);
            m1 = tap1 + (tap3 * xfeed);
            m2 = tap2 + (tap4 * xfeed);
            m3 = tap3 + (tap1 * xfeed);
            m4 = tap4 + (tap2 * xfeed);

            // ---- BALANCE ----
            // computed once, shared by output sum and feedback sum
            b1 = Balance2.ar(m1[0], m1[1], \bal1.kr(0.0).lag(slew));
            b2 = Balance2.ar(m2[0], m2[1], \bal2.kr(0.0).lag(slew));
            b3 = Balance2.ar(m3[0], m3[1], \bal3.kr(0.0).lag(slew));
            b4 = Balance2.ar(m4[0], m4[1], \bal4.kr(0.0).lag(slew));

            l1 = \level1.kr(0.50).lag(slew);
            l2 = \level2.kr(0.25).lag(slew);
            l3 = \level3.kr(0.10).lag(slew);
            l4 = \level4.kr(0.05).lag(slew);
            fb1 = \feedback1.kr(0.25).lag(slew);
            fb2 = \feedback2.kr(0.25).lag(slew);
            fb3 = \feedback3.kr(0.25).lag(slew);
            fb4 = \feedback4.kr(0.25).lag(slew);

            // ---- OUTPUT PATH ----
            outSum = (b1*l1) + (b2*l2) + (b3*l3) + (b4*l4);

            // bandpass filter: 6 dB = OnePole (no resonance), 12+ dB = RLPF/RHPF
            fSlope = \filterSlope.kr(2);
            fBot = \filterFreqBottom.kr(20).lag(slew);
            fTop = \filterFreqTop.kr(2500).lag(slew);
            rq = \resonance.kr(1.0).lag(slew);

            bpC1 = (-2pi * (fBot / SampleRate.ir)).exp;
            bpC2 = (-2pi * (fTop / SampleRate.ir)).exp;
            bp6 = OnePole.ar(outSum - OnePole.ar(outSum, bpC1), bpC2);

            // 12→24→36→48 dB: each stage adds 12 dB of slope
            bp12 = RLPF.ar(RHPF.ar(outSum, fBot, rq), fTop, rq);
            bp24 = RLPF.ar(RHPF.ar(bp12, fBot, rq), fTop, rq);
            bp36 = RLPF.ar(RHPF.ar(bp24, fBot, rq), fTop, rq);
            bp48 = RLPF.ar(RHPF.ar(bp36, fBot, rq), fTop, rq);

            filtered = Select.ar(fSlope - 1, [bp6, bp12, bp24, bp48]);

            satDrive = 1 + (\saturation.kr(0).lag(slew) * 9);
            saturated = (filtered * satDrive).tanh;

            chMix = \chorusDepth.kr(0).lag(slew) * 0.01;
            chRate = \chorusRate.kr(1.0);
            chMod = SinOsc.ar(chRate) * chMix * 0.005;
            chDel = (0.005 + chMod).max(0.0001);
            chorused = XFade2.ar(saturated, DelayC.ar(saturated, 0.01, chDel), chMix * 2 - 1);

            Out.ar(outBus, chorused);

            // ---- FEEDBACK PATH ----
            // raw signal + tanh limiter only — no processing accumulation
            fbSum = (b1*fb1) + (b2*fb2) + (b3*fb3) + (b4*fb4);
            LocalOut.ar(fbSum.tanh);
        }).add;
    }
}
