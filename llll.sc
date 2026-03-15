// =========================================================================
// FxLlll — four lines, a creative multitap delay
// =========================================================================
//
// Signal flow:
//
//   input × gain ──┬──> DelayC (line 1) ──> mono ──┐
//      + feedback  ├──> DelayC (line 2) ──> mono ──┤
//                  ├──> DelayC (line 3) ──> mono ──┤
//                  └──> DelayC (line 4) ──> mono ──┘
//                                                  │
//                               ┌──────────────────┤
//                               │                  │
//   OUTPUT PATH:                │     FEEDBACK PATH:│
//     mono × level × pan → sum  │     mono × fb × pan → sum
//              │                │              │
//         filter (LP/BP/HP)     │           tanh (limiter)
//              │                │              │
//         saturation            │            LocalOut → back
//              │                │
//         chorus                │
//              │                │
//             OUT               │
//
// Effects are in the OUTPUT path, so every echo (including the first)
// has full character. Feedback is raw + tanh safety limiter.
//
// DelayC (cubic interp) + 0.2s lag = pitch-shifting on time changes.
// Feedback up to 105% with tanh safety. Max delay 1s. No ext. UGens.
// =========================================================================

FxLlll : FxBase {

    *new {
        var ret = super.newCopyArgs(nil, \none, (
            time1: 0.5, time2: 0.25, time3: 0.125, time4: 0.0625,
            level1: 1.0, level2: 0.75, level3: 0.5, level4: 0.25,
            pan1: -0.5, pan2: 0.5, pan3: -0.5, pan4: 0.5,
            feedback1: 0.50, feedback2: 0.50, feedback3: 0.50, feedback4: 0.50,
            inputGain: 1.0,
            filterType: 1, filterSlope: 2,
            filterFreq: 2500, filterFreqBottom: 250, filterFreqTop: 2500,
            saturation: 0, chorusDepth: 0, chorusRate: 1.0,
            slew: 0,
        ), nil, 0.5);
        ^ret;
    }

    *initClass { FxSetup.register(this.new); }
    subPath { ^"/fx_llll"; }
    symbol { ^\fxLlll; }

    addSynthdefs {
        SynthDef(\fxLlll, {|inBus, outBus|
            var input, fb, source, slew;
            var mono1, mono2, mono3, mono4;
            var p1, p2, p3, p4;
            var outSum, fbSum;
            var fType, fSlope, fFreq, fBot, fTop;
            var lpC, lp6, lp12, lp24, lp48, lpOut;
            var hpC, hp6, hp12, hp24, hp48, hpOut;
            var bpBotC, bpTopC, bp6h, bp6, bp12, bp24, bp48, bpOut;
            var filtered, satDrive, saturated;
            var chMix, chRate, chMod, chDel, chSig, chorused;

            slew = \slew.kr(0);
            input = In.ar(inBus, 2) * \inputGain.kr(1.0).lag(slew);
            fb = LocalIn.ar(2);
            source = input + fb;

            // ---- DELAY LINES ----
            mono1 = Mix.ar(DelayC.ar(source, 1, \time1.kr(0.5).lag(0.2))) * 0.5;
            mono2 = Mix.ar(DelayC.ar(source, 1, \time2.kr(0.25).lag(0.2))) * 0.5;
            mono3 = Mix.ar(DelayC.ar(source, 1, \time3.kr(0.125).lag(0.2))) * 0.5;
            mono4 = Mix.ar(DelayC.ar(source, 1, \time4.kr(0.0625).lag(0.2))) * 0.5;

            p1 = \pan1.kr(-0.5).lag(slew);
            p2 = \pan2.kr(0.5).lag(slew);
            p3 = \pan3.kr(-0.5).lag(slew);
            p4 = \pan4.kr(0.5).lag(slew);

            // ---- OUTPUT SUM ----
            outSum = Pan2.ar(mono1 * \level1.kr(1.0).lag(slew), p1)
                   + Pan2.ar(mono2 * \level2.kr(0.75).lag(slew), p2)
                   + Pan2.ar(mono3 * \level3.kr(0.5).lag(slew), p3)
                   + Pan2.ar(mono4 * \level4.kr(0.25).lag(slew), p4);

            // ---- MULTIMODE FILTER on output ----
            fType = \filterType.kr(1);
            fSlope = \filterSlope.kr(2);
            fFreq = \filterFreq.kr(2500).lag(slew);
            fBot = \filterFreqBottom.kr(250).lag(slew);
            fTop = \filterFreqTop.kr(2500).lag(slew);

            lpC = (-2pi * (fFreq / SampleRate.ir)).exp;
            lp6 = OnePole.ar(outSum, lpC);
            lp12 = LPF.ar(outSum, fFreq);
            lp24 = LPF.ar(lp12, fFreq);
            lp48 = LPF.ar(LPF.ar(lp24, fFreq), fFreq);
            lpOut = Select.ar(fSlope - 1, [lp6, lp12, lp24, lp48]);

            hpC = (-2pi * (fFreq / SampleRate.ir)).exp;
            hp6 = outSum - OnePole.ar(outSum, hpC);
            hp12 = HPF.ar(outSum, fFreq);
            hp24 = HPF.ar(hp12, fFreq);
            hp48 = HPF.ar(HPF.ar(hp24, fFreq), fFreq);
            hpOut = Select.ar(fSlope - 1, [hp6, hp12, hp24, hp48]);

            bpBotC = (-2pi * (fBot / SampleRate.ir)).exp;
            bpTopC = (-2pi * (fTop / SampleRate.ir)).exp;
            bp6h = outSum - OnePole.ar(outSum, bpBotC);
            bp6 = OnePole.ar(bp6h, bpTopC);
            bp12 = LPF.ar(HPF.ar(outSum, fBot), fTop);
            bp24 = LPF.ar(HPF.ar(bp12, fBot), fTop);
            bp48 = LPF.ar(HPF.ar(LPF.ar(HPF.ar(bp24, fBot), fTop), fBot), fTop);
            bpOut = Select.ar(fSlope - 1, [bp6, bp12, bp24, bp48]);

            filtered = Select.ar(fType - 1, [lpOut, bpOut, hpOut]);

            // ---- SATURATION on output ----
            satDrive = 1 + (\saturation.kr(0).lag(slew) * 9);
            saturated = (filtered * satDrive).tanh;

            // ---- CHORUS on output ----
            chMix = \chorusDepth.kr(0).lag(slew) * 0.01;
            chRate = \chorusRate.kr(1.0);
            chMod = SinOsc.ar(chRate) * chMix * 0.005;
            chDel = (0.005 + chMod).max(0.0001);
            chSig = DelayC.ar(saturated, 0.01, chDel);
            chorused = (saturated * (1 - chMix)) + (chSig * chMix);

            Out.ar(outBus, chorused);

            // ---- FEEDBACK PATH (raw, no processing) ----
            fbSum = Pan2.ar(mono1 * \feedback1.kr(0.50).lag(slew), p1)
                  + Pan2.ar(mono2 * \feedback2.kr(0.50).lag(slew), p2)
                  + Pan2.ar(mono3 * \feedback3.kr(0.50).lag(slew), p3)
                  + Pan2.ar(mono4 * \feedback4.kr(0.50).lag(slew), p4);

            LocalOut.ar(fbSum.tanh);
        }).add;
    }
}
