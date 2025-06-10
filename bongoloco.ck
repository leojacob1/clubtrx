OscOut toNode, toChuck;

"127.0.0.1" => string host;
7777 => int nodePort;
8888 => int chuckPort;

toNode.dest(host, nodePort);
toChuck.dest(host, chuckPort);

Gain bongoBusLeft => dac.left;
Gain bongoBusRight => dac.right;
Gain bongoBusCenter => Gain gain_bongo => Gain gain_bongo_slider => ADSR bongoEnv => LPF lpf_bongo => JCRev rev_bongo => Pan2 pan_bongo_instrument => dac;

// ROOM ADJUSTMENT VARS

1.0 => float bassAdjustment;
1.0 => float clapAdjustment;
1.0 => float hatAdjustment;

10000 => lpf_bongo.freq;
0.0 => rev_bongo.mix;
bongoEnv.set(0::ms, 0::ms, 1.0, 0::ms);

GameTrak gt;

// Need to cycle through bufs for rapid fire section
48 => int N;
0 => int current;
"kenkeni.aiff" => string kenkeni_path;
"bip.wav" => string hat_path;
"bip_1.wav" => string clap_path;
"bleep.wav" => string bleep_path;
"printingpress.wav" => string printing_path;
"progbass3.wav" => string bass_path;

// Sndbufs for rhythmic elements in second part
SndBuf buf_print => Gain gain_print => Pan2 pan_print => dac;
SndBuf buf_bass => Gain gain_bass_slider => Gain gain_monitor_bass => Gain gain_bass => dac;
SndBuf buf_hat => Gain gain_hat_slider => Gain gain_hat => JCRev rev_hat => Gain gain_monitor_hat => dac;
SndBuf buf_clap => Gain gain_clap_slider => Gain gain_clap => JCRev rev_clap => Gain gain_monitor_clap => dac;
SndBuf buf_bleep => JCRev rev_bleep => Gain gain_bleep => dac;

1.2 => float GAIN_BUF_BONGO => gain_bongo.gain;
1.2 * bassAdjustment => buf_bass.gain;
1.0 * clapAdjustment => buf_clap.gain;
0.2 * hatAdjustment => buf_hat.gain;
0.2 => buf_print.gain;

0.05 => rev_bleep.mix;
0.0 => rev_hat.mix;
0.0 => rev_clap.mix;

// Arrays to hold bufs and panners
SndBuf bufs_bongo_high[N];
ADSR adsr_bongo_high[N];
Pan2 pans_bongo_high[N];

"sounds/" + printing_path => buf_print.read;
"sounds/" + bass_path => buf_bass.read;
"sounds/" + hat_path => buf_hat.read;
"sounds/" + clap_path => buf_clap.read;
"sounds/" + bleep_path => buf_bleep.read;

buf_print.samples() => buf_print.pos;
buf_bass.samples() => buf_bass.pos;
buf_hat.samples() => buf_hat.pos;
buf_clap.samples() => buf_clap.pos;
buf_bleep.samples() => buf_bleep.pos;

for (int i; i < N; i++) {
    adsr_bongo_high[i].set(5::ms, 0::ms, 1.0, 5::ms);
    bufs_bongo_high[i] => adsr_bongo_high[i] => pans_bongo_high[i];
    pans_bongo_high[i].left => bongoBusLeft;
    pans_bongo_high[i].right => bongoBusRight;
    pans_bongo_high[i] => bongoBusCenter;
    "sounds/" + kenkeni_path => bufs_bongo_high[i].read;
    bufs_bongo_high[i].samples() => bufs_bongo_high[i].pos;
}

int padState[64];
int padStateRaw[64];

0 => int printOverrideStatus; // 0 - normal, 1 - all on, 2 - all off
0 => int bassOverrideStatus; // 0 - normal, 1 - all on, 2 - all off
0 => int hatOverrideStatus; // 0 - normal, 1 - all on, 2 - all off
0 => int clapOverrideSTatus; // 0 - normal, 1 - all on, 2 - all off

0 => int mode;
/*
0 ---> Act I
11 ---> 220b
22 --> Act II
33 --> FREESTYLE (random hits)
44 --> MELODIC (consistent hits, discretized rates based on frequency ratios)
55 --> Back to freestyle
66 --> OFF: rhythmic
77 --> arpeggio bongo instrument
*/
720.0 => float quarterIntervalMs;
0.0 => float discretizedGt0;
25::ms => dur bongoInterval;
25::ms => dur bongoIntervalBase;

// Balance gains between panned buses and center bus (center bus takes over afte mode 0)
fun bongoHighPanMix() {
    while (mode < 44) {
        if (mode == 33) {
            Math.max(0, 1 - (gt.axis[2] / 0.8)) => bongoBusLeft.gain;
            Math.max(0, 1 - (gt.axis[2] / 0.8)) => bongoBusRight.gain;
            gt.axis[2] / 0.8 => bongoBusCenter.gain; 
        }
            
        10::ms => now;
    } 
    0.0 => bongoBusLeft.gain;
    0.0 => bongoBusRight.gain;
    1.0 => bongoBusCenter.gain;
}

fun void setBongoIntervalFreestyle() {
    // Apply eased mapping. more "gt.axis[2]" --> less "sec"
    while (true) {
        if (mode == 44 || mode >= 66) {
            10::ms => now;
            continue;
        }

        3.0 => float curve;
        gt.axis[2] => float gtAxis2;
        1.0 - Math.pow(1.0 - gt.axis[2], curve) => float eased;

        25/2 => float topOfMapping;
        if (mode == 55) noteToBongoInterval(5) / ms => topOfMapping;
        topOfMapping + (1800 * (1.0 - eased)) => float intervalMs;

        if (gt.axis[2] >= 0.8 || mode != 33) {
            // intervalMs * 3 => quarterIntervalMs; // assume interval is a triplet
            intervalMs::ms => bongoInterval;
        } else {
            // add herky jerkiness if mode = 33
            1 - (gt.axis[2] / 0.8) => float randomnessRange;
            Std.rand2f(intervalMs * (1 - 0.9 * randomnessRange), intervalMs * (1 + 0.9 * randomnessRange))::ms => bongoInterval;
        }
        
        10::ms => now;
    }
}

fun void percussionReverb() {
    while (true) {
        if (mode == 77) {
            mapAxis2Range(gt.axis[3], -1, 1, 0, 0.5) => rev_hat.mix;
            mapAxis2Range(gt.axis[3], -1, 1, 0, 0.5) => rev_clap.mix;

        } else if (mode == 88) {
            0 => rev_hat.mix;
            0 => rev_clap.mix;
        }
        20::ms => now;

    }
}

// Main function to play buffer at random intervals
fun void playHits() {
    while (true) {
        if (mode != 44 && gt.axis[2] < 0.1) {
            10::ms => now;
            continue;
        } else if (mode == 33) {
            Std.rand2f(0.4, 0.9) => bufs_bongo_high[current].gain;
            Std.rand2f(-1.0 * (1 - Math.pow(gt.axis[2], 3)), 1.0 * (1 - Math.pow(gt.axis[2], 3))) => pans_bongo_high[current].pan;
        } else if (mode >= 44) {
            1.1 => bufs_bongo_high[current].gain;
        }
        spork ~ triggerSound(bufs_bongo_high[current], current);
        (1 + current) % N => current;
        bongoInterval => now;
    }
}

fun void triggerSound(SndBuf buf, int c) {
    buf.pos(1500);
    adsr_bongo_high[c].keyOn();
    // toNode.start( "/bongo" );
    // 1 => toNode.add;
    // toNode.send();
    12000::samp => now;
    adsr_bongo_high[c].keyOff();
    buf.pos((buf.length() / samp) $ int);
}

fun void changeBongoHighEnvelope() {
  while (true) {
    if (mode == 33) {
        <<< "Env diff: " + (discretizedGt0 - 0.84) >>>;
        Math.max(0, gt.axis[0]) => discretizedGt0;
    }
    bongoEnv.attackTime((20 + (1 - discretizedGt0) * 350)::ms);
    bongoEnv.decayTime((20 + (1 - Math.pow(discretizedGt0, 0.8)) * 300)::ms);
    bongoEnv.releaseTime((60 + (1 - Math.pow(discretizedGt0, 0.8)) * 500)::ms);
    10::ms => now;
  }
}


fun void pulseBongoHighEnvelope() {
    bongoEnv.keyOn();
    0 => int i;
    while (true) {
        if (Math.max(0, discretizedGt0) > 0.1) {
            bongoEnv.keyOn();
            (20 + (1 - Math.max(0, discretizedGt0)) * 600)::ms => now; 
            bongoEnv.keyOff();
            if (mode >= 77) {
                noteToBongoInterval(i % 3) / 2 => bongoInterval;
                (i % 9) / 9.0 * 2.0 - 1.0 => pan_bongo_instrument.pan;
                i + 2 => i;
            }
            (40 + (1 - Math.max(0, discretizedGt0)) * 500)::ms => now; 
        } else {
            bongoEnv.keyOn();
            10::ms => now;
        }
    }

}

fun playPrint() {
    (buf_print.samples() / 44100.0) / (quarterIntervalMs * 8 / 1000) => buf_print.rate;
    while (true) {
        0 => int hasPlayed;
        for (56 => int i; i < 64; i++) {
            if (padState[i]) {
                1 => hasPlayed;
                Math.fabs(4.0 - (i - 56.0)) / 4.0 * 1.8 - 0.9 => pan_print.pan;
                buf_print.pos(buf_print.samples() / 8 * (i - 56));
                quarterIntervalMs::ms => now;
            } else {
                buf_print.pos(buf_print.samples());
                quarterIntervalMs::ms => now;
            }
        }
        if (!hasPlayed) quarterIntervalMs::ms => now;
    }
}

fun playBassOnce() {
    0 => buf_bass.pos;
}

fun void playBass() {
    spork ~ graphicBass();
    while (true) {
        for (48 => int i; i < 56; i++) {
            if (!padState[i]) {
                quarterIntervalMs::ms => now;
            } else if (padState[i] == 1) {
                spork ~ playBassOnce();
                (quarterIntervalMs)::ms => now;
            } else if (padState[i] == 2) {
                (quarterIntervalMs / 2)::ms => now;
                spork ~ playBassOnce();
                (quarterIntervalMs / 2)::ms => now;
            }
        }
    }
}

fun void graphicBass() {
    while (true) {
        toNode.start( "/bassGain" );
        gain_monitor_bass.last() => float bassGain;
        
        Math.pow(Math.min(0.5, Math.fabs(bassGain)), 3) => bassGain;
        if (bassGain < 0.0000001 * bassAdjustment) {
            0 / bassAdjustment => bassGain;
        } else if (bassGain < 0.1 * bassAdjustment) {
            0.006 / bassAdjustment => bassGain;
        }
        bassGain * 350 / bassAdjustment => toNode.add;
        toNode.send();
        10::ms => now;
    }
}

fun void graphicHat() {
    while (true) {
        toNode.start( "/hatGain" );
        gain_monitor_hat.last() => float hatGain;
        Math.fabs(hatGain) * 2000 / hatAdjustment => hatGain;
        hatGain => toNode.add;
        toNode.send();
        20::ms => now;
    }
}

fun void graphicClap() {
    while (true) {
        toNode.start( "/clapGain" );
        gain_monitor_clap.last() => float clapGain;
        Math.fabs(clapGain) * 1100 / clapAdjustment => clapGain;
        clapGain => toNode.add;
        toNode.send();
        20::ms => now;
    }
}

fun playClapOnce() {
  0 => buf_clap.pos;
}

fun void playClap() {
    spork ~ graphicClap();
    while (true) {
        for (32 => int i; i < 40; i++) {
            if (!padState[i]) {
                quarterIntervalMs::ms => now;
            } else if (padState[i] == 1) {
                1.0 => gain_clap.gain;
                spork ~ playClapOnce();
                quarterIntervalMs::ms => now;
            } else if (padState[i] == 2) {
                1.0 => gain_clap.gain;
                spork ~ playClapOnce();
                (quarterIntervalMs / 2)::ms => now;
                0.7 => gain_clap.gain;
                spork ~ playClapOnce();
                (quarterIntervalMs / 2)::ms => now;
            } else if (padState[i] == 3) {
                1.0 => gain_clap.gain;
                spork ~ playClapOnce();
                (quarterIntervalMs / 3)::ms => now;
                0.7 => gain_clap.gain;
                spork ~ playClapOnce();
                (quarterIntervalMs / 3)::ms => now;
                0.65 => gain_clap.gain;
                spork ~ playClapOnce();
                (quarterIntervalMs / 3)::ms => now;
            }
        }
    }
}

fun playHatOnce() {
    0 => buf_hat.pos;
}

fun void playHat() {
    spork ~ graphicHat();
    while (true) {
        for (40 => int i; i < 48; i++) {
            if (!padState[i]) {
                quarterIntervalMs::ms => now;
            } else if (padState[i] == 1) {
                spork ~ playHatOnce();
                quarterIntervalMs::ms => now;
            } else if (padState[i] == 2) {
                0.8 => gain_hat.gain;
                spork ~ playHatOnce();
                (quarterIntervalMs / 2)::ms => now;
                0.6 => gain_hat.gain;
                spork ~ playHatOnce();
                (quarterIntervalMs / 2)::ms => now;
            } else if (padState[i] == 3) {
                0.85 => gain_hat.gain;
                spork ~ playHatOnce();
                (quarterIntervalMs / 4)::ms => now;
                0.6 => gain_hat.gain;
                spork ~ playHatOnce();
                (quarterIntervalMs / 4)::ms => now;
                0.75 => gain_hat.gain;
                spork ~ playHatOnce();
                (quarterIntervalMs / 4)::ms => now;
                0.5 => gain_hat.gain;
                spork ~ playHatOnce();
                (quarterIntervalMs / 4)::ms => now;
            }
        }
    }
}

// ------------ PAD ------------

0 => int pad_device;
if( me.args() ) me.arg(0) => Std.atoi => pad_device;

MidiIn min;
MidiOut mout;
MidiMsg pad_msg;

/* --------- MIDI SETUP --------- */

144 => int NOTE_ON;
128 => int NOTE_OFF;
176 => int SLIDER;

0 => int OFF;
3 => int RED;
9 => int GREEN;

0 => int isShifted; // is shift currently pressed

Shred pulseBongoHighEnvelopeSpork;
fun void runPad() {
    while (true) {
        min => now;
        while (min.recv(pad_msg)) {
            pad_msg.data1 => int inputType; // pad number
            pad_msg.data2 => int pad;
            pad_msg.data3 => int velocity;
            // <<< inputType, pad, velocity >>>;
            if (mode == 44 && pad >= 0 && pad < 6 && inputType == NOTE_ON) {
                // Play melody of bongo instrument using 8th row (bottom row)
                1 => padState[pad];
                for (int i; i < 6; i++) {
                    if (i == pad) {
                        1 => padState[pad];
                        mout.send(NOTE_ON, pad, GREEN);
                        noteToBongoInterval(pad) => bongoInterval;
                    } else {
                        0 => padState[i];
                        mout.send(NOTE_ON, i, RED);
                    }
                }
            } else if (mode == 44 && pad >= 8 && pad < 12) {
                // Play rhythm of bongo instrument using 7th row
                Machine.remove(pulseBongoHighEnvelopeSpork.id());
                spork ~ pulseBongoHighEnvelope() @=> pulseBongoHighEnvelopeSpork;
                getDiscretizedGt0(pad - 8) => discretizedGt0;
                1 => padState[pad];
                for (8 => int i; i < 12; i++) {
                    if (i == pad) {
                        1 => padState[pad];
                        mout.send(NOTE_ON, pad, GREEN);
                    } else {
                        0 => padState[i];
                        mout.send(NOTE_ON, i, RED);
                    }
                }
            } else if (32 <= pad && pad < 40 && inputType == NOTE_ON) {
                // clap
                (padState[pad] + 1) % 4 => int nextState;
                if (isShifted) 0 => nextState;
                nextState => padState[pad];

                if (nextState == 0) {
                    mout.send(NOTE_ON, pad, OFF);
                } else if (nextState == 1) {
                    mout.send(NOTE_ON, pad, RED);
                } else if (nextState == 2) {
                    mout.send(NOTE_ON, pad, GREEN);
                } else if (nextState == 3) {
                    spork ~ flashButton(pad);
                }
            } else if (40 <= pad && pad < 48 && inputType == NOTE_ON) {
                // hi hat
                (padState[pad] + 1) % 4 => int nextState;
                if (isShifted) 0 => nextState;
                nextState => padState[pad];

                if (nextState == 0) {
                    mout.send(NOTE_ON, pad, OFF);
                } else if (nextState == 1) {
                    mout.send(NOTE_ON, pad, RED);
                } else if (nextState == 2) {
                    mout.send(NOTE_ON, pad, GREEN);
                } else if (nextState == 3) {
                    spork ~ flashButton(pad);
                }
            } else if (56 <= pad && pad < 64 && inputType == NOTE_ON) {
                // printing
                if (!padState[pad]) {
                    1 => padState[pad];
                    mout.send(NOTE_ON, pad, RED);
                } else {
                    0 => padState[pad];
                    mout.send(NOTE_ON, pad, OFF);
                }
            } else if (pad >= 48 && pad < 56 && inputType == NOTE_ON) {
                // Bass single rhythms
                (padState[pad] + 1) % 3 => int nextState;
                if (isShifted) 0 => nextState;
                nextState => padState[pad];

                if (nextState == 0) {
                    mout.send(NOTE_ON, pad, OFF);
                } else if (nextState == 1) {
                    mout.send(NOTE_ON, pad, RED);
                } else if (nextState == 2) {
                    mout.send(NOTE_ON, pad, GREEN);
                }
            } else if (pad == 89) {
                if (inputType == NOTE_ON) {
                    0.0 => gain_bongo.gain;
                    mout.send(NOTE_ON, 89, RED);
                } else if (inputType == NOTE_OFF) {
                    GAIN_BUF_BONGO => gain_bongo.gain;
                    mout.send(NOTE_ON, 89, OFF);
                }
            } else if (pad == 98) {
                if (inputType == NOTE_ON) {
                    1 => isShifted;
                    mout.send(NOTE_ON, 98, RED);
                } else if (inputType == NOTE_OFF) {
                    0 => isShifted;
                    mout.send(NOTE_ON, 98, OFF);
                }
            } else if (pad == 86 && inputType == NOTE_ON) {
                0 => buf_bleep.pos;
            } else if (inputType == SLIDER) {
                if (pad == 56) {
                    Math.pow(velocity / 127.0, 2) => gain_print.gain;
                } else if (pad == 49) {
                    Math.pow(velocity / 127.0, 2) => gain_bass_slider.gain;
                } else if (pad == 50) {
                    Math.pow(velocity / 127.0, 2) => gain_hat_slider.gain;
                } else if (pad == 51) {
                    Math.pow(velocity / 127.0, 2) => gain_clap_slider.gain;
                } else if (pad == 56) {
                    Math.pow(velocity / 127.0, 2) => gain_bongo_slider.gain;
                }
            } else if (mode > 44 && pad == 24 && inputType == NOTE_ON) {
                if (printOverrideStatus != 1) {
                    mout.send(NOTE_ON, 24, GREEN);
                    mout.send(NOTE_ON, 31, OFF);
                    for (56 => int i; i < 64; i++) {
                        if (printOverrideStatus == 0) padState[i] => padStateRaw[i];
                        1 => padState[i];
                        mout.send(NOTE_ON, i, RED);
                    }
                    1 => printOverrideStatus;
                } else {
                    0 => printOverrideStatus;
                    mout.send(NOTE_ON, 24, OFF);
                    for (56 => int i; i < 64; i++) {
                        padStateRaw[i] => padState[i];
                        padStateToColor(padStateRaw[i]) => int color;
                        if (color == -1) {
                            spork ~ flashButton(i);
                        } else {
                            mout.send(NOTE_ON, i, color);
                        }
                    }
                }
            } else if (mode > 44 && pad == 31 && inputType == NOTE_ON) {
                if (printOverrideStatus != 2) {
                    mout.send(NOTE_ON, 31, RED);
                    mout.send(NOTE_ON, 24, OFF);
                    for (56 => int i; i < 64; i++) {
                        if (printOverrideStatus == 0) padState[i] => padStateRaw[i];
                        0 => padState[i];
                        mout.send(NOTE_ON, i, OFF);
                    }
                    2 => printOverrideStatus;
                } else {
                    0 => printOverrideStatus;
                    mout.send(NOTE_ON, 31, OFF);
                    for (56 => int i; i < 64; i++) {
                        padStateRaw[i] => padState[i];
                        padStateToColor(padStateRaw[i]) => int color;
                        if (color == -1) {
                            spork ~ flashButton(i);
                        } else {
                            mout.send(NOTE_ON, i, color);
                        }
                    }
                }
            }

            // BASS OVERRIDE (pads 26/23, pads 48-55)
            else if (mode > 44 && pad == 26 && inputType == NOTE_ON) {
                if (bassOverrideStatus != 1) {
                    mout.send(NOTE_ON, 26, GREEN);
                    mout.send(NOTE_ON, 23, OFF);
                    for (48 => int i; i < 56; i++) {
                        if (bassOverrideStatus == 0) padState[i] => padStateRaw[i];
                        1 => padState[i];
                        mout.send(NOTE_ON, i, RED);
                    }
                    1 => bassOverrideStatus;
                } else {
                    0 => bassOverrideStatus;
                    mout.send(NOTE_ON, 26, OFF);
                    for (48 => int i; i < 56; i++) {
                        padStateRaw[i] => padState[i];
                        padStateToColor(padStateRaw[i]) => int color;
                        if (color == -1) {
                            spork ~ flashButton(i);
                        } else {
                            mout.send(NOTE_ON, i, color);
                        }
                    }
                }
            } else if (mode > 44 && pad == 23 && inputType == NOTE_ON) {
                bassOverrideOff();
            }

            // HAT OVERRIDE (pads 8/15, pads 40-47)
            else if (mode > 44 && pad == 8 && inputType == NOTE_ON) {
                if (hatOverrideStatus != 1) {
                    mout.send(NOTE_ON, 8, GREEN);
                    mout.send(NOTE_ON, 15, OFF);
                    for (40 => int i; i < 48; i++) {
                        if (hatOverrideStatus == 0) padState[i] => padStateRaw[i];
                        1 => padState[i];
                        mout.send(NOTE_ON, i, RED);
                    }
                    1 => hatOverrideStatus;
                } else {
                    0 => hatOverrideStatus;
                    mout.send(NOTE_ON, 8, OFF);
                    for (40 => int i; i < 48; i++) {
                        padStateRaw[i] => padState[i];
                        padStateToColor(padStateRaw[i]) => int color;
                        if (color == -1) {
                            spork ~ flashButton(i);
                        } else {
                            mout.send(NOTE_ON, i, color);
                        }
                    }
                }
            } else if (mode > 44 && pad == 15 && inputType == NOTE_ON) {
                if (hatOverrideStatus != 2) {
                    mout.send(NOTE_ON, 15, RED);
                    mout.send(NOTE_ON, 8, OFF);
                    for (40 => int i; i < 48; i++) {
                        if (hatOverrideStatus == 0) padState[i] => padStateRaw[i];
                        0 => padState[i];
                        mout.send(NOTE_ON, i, OFF);
                    }
                    2 => hatOverrideStatus;
                } else {
                    0 => hatOverrideStatus;
                    mout.send(NOTE_ON, 15, OFF);
                    for (40 => int i; i < 48; i++) {
                        padStateRaw[i] => padState[i];
                        padStateToColor(padStateRaw[i]) => int color;
                        if (color == -1) {
                            spork ~ flashButton(i);
                        } else {
                            mout.send(NOTE_ON, i, color);
                        }
                    }
                }
            }

            // CLAP OVERRIDE (pads 0/7, pads 32-39)
            else if (mode > 44 && pad == 0 && inputType == NOTE_ON) {
                if (clapOverrideSTatus != 1) {
                    mout.send(NOTE_ON, 0, GREEN);
                    mout.send(NOTE_ON, 7, OFF);
                    for (32 => int i; i < 40; i++) {
                        if (clapOverrideSTatus == 0) padState[i] => padStateRaw[i];
                        1 => padState[i];
                        mout.send(NOTE_ON, i, RED);
                    }
                    1 => clapOverrideSTatus;
                } else {
                    0 => clapOverrideSTatus;
                    mout.send(NOTE_ON, 0, OFF);
                    for (32 => int i; i < 40; i++) {
                        padStateRaw[i] => padState[i];
                        padStateToColor(padStateRaw[i]) => int color;
                        if (color == -1) {
                            spork ~ flashButton(i);
                        } else {
                            mout.send(NOTE_ON, i, color);
                        }
                    }
                }
            } else if (mode > 44 && pad == 7 && inputType == NOTE_ON) {
                if (clapOverrideSTatus != 2) {
                    mout.send(NOTE_ON, 7, RED);
                    mout.send(NOTE_ON, 0, OFF);
                    for (32 => int i; i < 40; i++) {
                        if (clapOverrideSTatus == 0) padState[i] => padStateRaw[i];
                        0 => padState[i];
                        mout.send(NOTE_ON, i, OFF);
                    }
                    2 => clapOverrideSTatus;
                } else {
                    0 => clapOverrideSTatus;
                    mout.send(NOTE_ON, 7, OFF);
                    for (32 => int i; i < 40; i++) {
                        padStateRaw[i] => padState[i];
                        padStateToColor(padStateRaw[i]) => int color;
                        if (color == -1) {
                            spork ~ flashButton(i);
                        } else {
                            mout.send(NOTE_ON, i, color);
                        }
                    }
                }
            } else if (pad == 88 && inputType == NOTE_ON) {
                0 => gain_print.gain;                
                toNode.start("/kill");
                2 => toNode.add;
                toNode.send();
                0.0 => bongoBusCenter.gain;
            }
        }
    }
}

Shred sendIntroParamsSh;
fun void sendIntroParams() {  
  while (true) {
    if (mode == 0 || mode == 22) {
      toNode.start( "/intro" );
      gt.axis[2] => toNode.add;
      toNode.send();
    }
    50::ms => now;
  }
} spork ~ sendIntroParams() @=> sendIntroParamsSh;

// ----------- GAMETRAK -----------

0 => float DEADZONE;

0 => int gt_device;
if( me.args() ) me.arg(0) => Std.atoi => gt_device;

Hid trak;
HidMsg msg;

if( !trak.openJoystick( gt_device ) ) me.exit();

<<< "joystick '" + trak.name() + "' ready", "" >>>;

class GameTrak
{
    time lastTime;
    time currTime;
    float lastAxis[6];
    float axis[6];
}

Shred slowBongoInstrumentSh;
Shred percussionReverbSh;
Shred playHitsSh;
Shred setBongoIntervalFreestyleSh;
Shred changeBongoHighEnvelopeSh;
fun void gametrak()
{
    while( true )
    {
        // wait on HidIn as event
        trak => now;
        // messages received
        while( trak.recv( msg ) )
        {
            // joystick axis motion
            if( msg.isAxisMotion() )
            {            
                if( msg.which >= 0 && msg.which < 6 )
                {
                    if( now > gt.currTime )
                    {
                        gt.currTime => gt.lastTime;
                        now => gt.currTime;
                    }
                    gt.axis[msg.which] => gt.lastAxis[msg.which];
                    if( msg.which != 2 && msg.which != 5 )
                    { msg.axisPosition => gt.axis[msg.which]; }
                    else
                    {
                        // max out at top of my reach for Z axis (2 and 5)
                        Math.min(0.78, (1 - ((msg.axisPosition + 1) / 2) - DEADZONE) / 0.78) / 0.78=> gt.axis[msg.which];
                        if( gt.axis[msg.which] < 0 ) 0 => gt.axis[msg.which];
                    }
                    toChuck.start( "/gt" );
                    msg.which => toChuck.add;
                    gt.axis[msg.which] => toChuck.add;
                    toChuck.send();
                }
            }
            
            // joystick button down
            else if( msg.isButtonDown() )
            {
                if (mode == 0) {
                    Machine.remove(sendIntroParamsSh.id());
                } else if (mode == 11) {
                    spork ~ sendIntroParams() @=> sendIntroParamsSh;
                } else if (mode == 22) {
                    Machine.remove(sendIntroParamsSh.id());
                    spork ~ setUp();
                    spork ~ runPad();
                    spork ~ bongoHighPanMix();

                    spork ~ setBongoIntervalFreestyle() @=> setBongoIntervalFreestyleSh;

                    spork ~ playHits() @=> playHitsSh;

                    spork ~ pulseBongoHighEnvelope() @=> pulseBongoHighEnvelopeSpork;

                    spork ~ changeBongoHighEnvelope() @=> changeBongoHighEnvelopeSh;
                } else if (mode == 33) {
                    spork ~ prepMelodyMode();
                    spork ~ playPrint();
                    spork ~ playBass();
                    spork ~ playHat();
                    spork ~ playClap();

                } else if (mode == 44) {
                    spork ~ slowBongoInstrument() @=> slowBongoInstrumentSh;
                    for (0 => int i; i < 6; i++) {
                        0 => padState[i];
                        mout.send(NOTE_ON, i, OFF);
                    }
                    for (8 => int i; i < 12; i++) {
                        0 => padState[i];
                        mout.send(NOTE_ON, i, OFF);
                    }
                } else if (mode == 55) {
                    Machine.remove(slowBongoInstrumentSh.id());
                    Machine.remove(pulseBongoHighEnvelopeSpork.id());
                    Machine.remove(playHitsSh.id());
                    Machine.remove(setBongoIntervalFreestyleSh.id());
                    Machine.remove(changeBongoHighEnvelopeSh.id());
                    0.0 => gain_bongo.gain;
                } else if (mode == 66) {
                    spork ~ percussionReverb() @=> percussionReverbSh;
                } else if (mode == 77) {
                    // GO BIG
                    0 => hatOverrideStatus;
                    mout.send(NOTE_ON, 8, OFF);
                    for (40 => int i; i < 48; i++) {
                        <<< "go single", i >>>;
                        1 => padState[i];
                        mout.send(NOTE_ON, i, RED);
                    }
                    for (32 => int i; i < 40; i++) {
                        0 => padState[i];
                        mout.send(NOTE_ON, i, OFF);
                    }
                    for (48 => int i; i < 56; i++) {
                        0 => padState[i];
                    }
                    0 => bassOverrideStatus;
                    mout.send(NOTE_ON, 23, OFF);
                    1 => padState[48];
                    mout.send(NOTE_ON, 48, RED);
                    2 => padState[49];
                    mout.send(NOTE_ON, 49, GREEN);
                    1 => padState[51];
                    mout.send(NOTE_ON, 51, RED);
                } else if (mode == 88) {
                    // GO SMALL AGAIN
                    for (40 => int i; i < 48; i++) {
                        3 => padState[i];
                        spork ~ flashButton(i);
                    }
                    for (32 => int i; i < 40; i++) {
                        i % 2 => padState[i];
                        mout.send(NOTE_ON, i, padStateToColor(padState[i]));
                    }
                }
                if (mode < 88) {
                    mode + 11 => mode;
                } else if (mode == 88) {
                    mode - 11 => mode;
                }
                toChuck.start( "/mode" );
                toNode.start("/mode");
                mode => toChuck.add;
                mode => toNode.add;
                toChuck.send();
                toNode.send();
                <<< "NEW MODE: ", mode >>>;

            }
            
            // joystick button up
            else if( msg.isButtonUp() )
            {
                // <<< "button", msg.which, "up" >>>;
            }
        }
    }
}
spork ~ gametrak();


// ----------- HELPERS -----------

/* Go from rhythm index (derived from pad value) to discretizedGt0
    which can be used for ADSR values and keyOn keyOff durations */
fun float getDiscretizedGt0(int i) {
    quarterIntervalMs / 2 => float newIntervalMs;
    if (i == 0) {
        // Nothing. just an eight note
    } else if (i == 1) {
        quarterIntervalMs / 3 => newIntervalMs;
    } else if (i == 2) {
        quarterIntervalMs / 4 => newIntervalMs;
    } else if (i == 3) {
        quarterIntervalMs / 6 => newIntervalMs;
    }
    return 1-((newIntervalMs-60)/1100);
}

fun dur noteToBongoInterval(int i) {
    if (i == 1) {
        return (8.0 / 9.0) * bongoIntervalBase; // (second)
    } else if (i == 2) {
        return (5.0 / 6.0) * bongoIntervalBase; // (minor third)
    } else if (i == 3) {
        return (2.0 / 3.0) * bongoIntervalBase; //  (perfect fifth)
    } else if (i == 4) {
        return (5.0 / 8.0) * bongoIntervalBase; //  (minor sixth)
    } else if (i == 5) {
        return (1.0 / 2.0) * bongoIntervalBase; //  (octave)
    }
    return bongoIntervalBase; // (root)
}

fun void prepMelodyMode() {
    // Lock in base envelope and pitch for bongo instrument
    // default is eight notes
    ((20 + (1 - Math.max(0, discretizedGt0)) * 600) + (40 + (1 - Math.max(0, discretizedGt0)) * 500)) * 2 => quarterIntervalMs; 
    bongoInterval => bongoIntervalBase;
    <<< "Sending /key ", bongoIntervalBase, (1000.0)::ms / bongoIntervalBase >>>;
    toChuck.start( "/key" );
    (1000.0)::ms / bongoIntervalBase => toChuck.add;
    toChuck.send();

    mout.send(NOTE_ON, 0, GREEN);
    for (1 => int i; i < 6; i++) {
        mout.send(NOTE_ON, i, RED);
    }
    mout.send(NOTE_ON, 8, GREEN);
    for (9 => int i; i < 12; i++) {
        mout.send(NOTE_ON, i, RED);
    }
}

fun void slowBongoInstrument() {
    while (true) {
        mapAxis2Range(gt.axis[0], -1.0, 1.0, 0, getDiscretizedGt0(3)) => discretizedGt0;
        bongoEnv.attackTime((20 + (1 - discretizedGt0) * 350)::ms);
        bongoEnv.decayTime((20 + (1 - Math.pow(discretizedGt0, 0.8)) * 300)::ms);
        bongoEnv.releaseTime((60 + (1 - Math.pow(discretizedGt0, 0.8)) * 500)::ms);

        (gt.axis[1] + 1.0) / 2.0 * 10000.0 => lpf_bongo.freq;
        10::ms => now;
    }
}

fun void flashButton(int pad) {
    while (padState[pad] == 3) {
        mout.send(NOTE_ON, pad, GREEN);
        125::ms => now;
        mout.send(NOTE_ON, pad, OFF);
        125::ms => now;
    }
}

fun int padStateToColor(int padState) {
    if (padState == 0) {
        return OFF;
    } else if (padState == 1) {
        return RED;
    } else if (padState == 2) {
        return GREEN;
    } else if (padState == 3) {
        return  -1;
    }
    return OFF; // default
}

fun void bassOverrideOff() {
    if (bassOverrideStatus != 2) {
        mout.send(NOTE_ON, 23, RED);
        mout.send(NOTE_ON, 22, OFF);
        for (48 => int i; i < 56; i++) {
            if (bassOverrideStatus == 0) padState[i] => padStateRaw[i];
            0 => padState[i];
            mout.send(NOTE_ON, i, OFF);
        }
        2 => bassOverrideStatus;
    } else {
        0 => bassOverrideStatus;
        mout.send(NOTE_ON, 23, OFF);
        for (48 => int i; i < 56; i++) {
            padStateRaw[i] => padState[i];
            padStateToColor(padStateRaw[i]) => int color;
            if (color == -1) {
                spork ~ flashButton(i);
            } else {
                mout.send(NOTE_ON, i, color);
            }
        }
    }
}

fun float mapAxis2Range( float input, float lo, float hi, float outLo, float outHi )
{
    // sanity check
    if( outLo >= outHi )
    {
        // error
        <<< "WARNING: unreasonable output lo/hi range in mapAxis2Range()" >>>;
        // done
        return outLo;
    }
    
    // sanity check
    if( lo >= hi )
    {
        // error
        <<< "WARNING: unreasonable input lo/hi range in mapAxis2Range()" >>>;
        // done
        return outLo;
    }
    
    // clamp
    if( input < lo ) lo => input;
    else if( input > hi ) hi => input;
    
    // percentage
    (input - lo) / (hi - lo) => float percent;
    
    // done
    return outLo + ( percent * (outHi - outLo) );
}

fun void setUp() {
    if( !mout.open(0) ) me.exit();
    if( !min.open( pad_device ) ) me.exit();

    for (56 => int i; i < 64; i++) {
        0 => padState[i];
    }
    1 => padState[60];
    1 => padState[61];
    1 => padState[62];
    1 => padState[63];
    for (48 => int i; i < 56; i++) {
        0 => padState[i];
    }
    1 => padState[48];
    2 => padState[49];
    1 => padState[51];

    for (40 => int i; i < 48; i++) {
        0 => padState[i];
    }
    for (32 => int i; i < 40; i++) {
        0 => padState[i];
    }
    for (24 => int i; i < 32; i++) {
        0 => padState[i];
    }
    for (16 => int i; i < 24; i++) {
        0 => padState[i];
    }
    for (8 => int i; i < 16; i++) {
        0 => padState[i];
    }
    for (0 => int i; i < 8; i++) {
        0 => padState[i];
    }
    mout.send(NOTE_ON, 82, OFF);
    mout.send(NOTE_ON, 83, OFF);
    mout.send(NOTE_ON, 84, OFF);
    mout.send(NOTE_ON, 85, OFF);
    mout.send(NOTE_ON, 16, OFF);
    mout.send(NOTE_ON, 23, OFF);
    mout.send(NOTE_ON, 8, OFF);
    mout.send(NOTE_ON, 15, OFF);
    mout.send(NOTE_ON, 0, OFF);
    mout.send(NOTE_ON, 7, OFF);
    mout.send(NOTE_ON, 89, OFF);
    mout.send(NOTE_ON, 88, OFF);

    // Use padStateToColor for all pads to ensure correct light alignment
    for (int i; i < 64; i++) {
        padStateToColor(padState[i]) => int color;
        if (color == -1) {
            spork ~ flashButton(i);
        } else {
            mout.send(NOTE_ON, i, color);
        }
    }
}

eon => now;