Gain bongoBusLeft => dac.left;
Gain bongoBusRight => dac.right;
Gain bongoBusCenter => Gain bongoMuter => ADSR bongoEnv => LPF lpf_bongo => JCRev rev_bongo => dac;

10000 => lpf_bongo.freq;
0.0 => rev_bongo.mix;
bongoEnv.set(0::ms, 0::ms, 1.0, 0::ms);

GameTrak gt;

// Need to cycle through bufs for rapid fire section
48 => int N;
0 => int current;
"kenkeni.aiff" => string kenkeni_path;
"triangle_long_1.wav" => string triangle_long_path;
"triangle_short_1.wav" => string triangle_short_path;
"printingpress.wav" => string printing_path;
"progbass3.wav" => string bass_path;
"progbass4.wav" => string bass2_path;

// Sndbufs for rhythmic elements in second part
SndBuf buf_single_bongo => ADSR adsr_single_bongo => Gain gain_single_bongo => dac;
SndBuf buf_triangle_long => ADSR adsr_triangle_long => Gain gain_triangle_long => dac;
SndBuf buf_triangle_short => ADSR adsr_triangle_short => Gain gain_triangle_short => dac;
SndBuf buf_print => Gain gain_print => Pan2 pan_print => dac;
SndBuf buf_bass => Gain gain_bass => dac;
SndBuf buf_bass2 => Gain gain_bass2 => dac;

// Arrays to hold bufs and panners
SndBuf bufs_bongo_high[N];
ADSR adsr_bongo_high[N];
Pan2 pans_bongo_high[N];

// Connect each buffer to a pan and to dac
// Need panned buses and a center bus that can handle envelope
kenkeni_path => buf_single_bongo.read;
triangle_long_path => buf_triangle_long.read;
triangle_short_path => buf_triangle_short.read;
printing_path => buf_print.read;
bass_path => buf_bass.read;
bass2_path => buf_bass2.read;

buf_single_bongo.samples() => buf_single_bongo.pos;
buf_triangle_long.samples() => buf_triangle_long.pos;
buf_triangle_short.samples() => buf_triangle_short.pos;
buf_print.samples() => buf_print.pos;
buf_bass.samples() => buf_bass.pos;
buf_bass2.samples() => buf_bass2.pos;

adsr_single_bongo.set(5::ms, 0::ms, 1.0, 5::ms);
adsr_triangle_long.set(5::ms, 0::ms, 1.0, 5::ms);
adsr_triangle_short.set(5::ms, 0::ms, 1.0, 5::ms);

0.8 => gain_single_bongo.gain;
0.4 => gain_triangle_long.gain;
1.0 => gain_triangle_short.gain;
0.2 => gain_print.gain;
0.7 => gain_bass.gain;
0.7 => gain_bass2.gain;

for (int i; i < N; i++) {
    adsr_bongo_high[i].set(5::ms, 0::ms, 1.0, 5::ms);
    bufs_bongo_high[i] => adsr_bongo_high[i] => pans_bongo_high[i];
    pans_bongo_high[i].left => bongoBusLeft;
    pans_bongo_high[i].right => bongoBusRight;
    pans_bongo_high[i] => bongoBusCenter;
    kenkeni_path => bufs_bongo_high[i].read;
    bufs_bongo_high[i].samples() => bufs_bongo_high[i].pos;
}

int padState[64];
int padStateRaw[64];

0 => int mode;
/*
0 --> FREESTYLE (random hits)
1 --> MELODIC (consistent hits, discretized rates based on frequency ratios)
2 --> Back to freestyle
*/
720.0 => float quarterIntervalMs;
0.0 => float discretizedGt0;
25::ms => dur bongoInterval;
25::ms => dur bongoIntervalBase;

// Balance gains between panned buses and center bus (center bus takes over afte mode 0)
fun bongoHighPanMix() {
  while (true) {
    if (mode) {
        0.0 => bongoBusLeft.gain;
        0.0 => bongoBusRight.gain;
        1.0 => bongoBusCenter.gain;
    } else {
        Math.max(0, 1 - (gt.axis[2] / 0.8)) => bongoBusLeft.gain;
        Math.max(0, 1 - (gt.axis[2] / 0.8)) => bongoBusRight.gain;
        gt.axis[2] / 0.8 => bongoBusCenter.gain; 
    }
    
    10::ms => now;
  }
}

fun void setBongoIntervalFreestyle() {
    // Apply eased mapping. more "gt.axis[2]" --> less "sec"
    while (true) {
        if (mode == 1) {
            10::ms => now;
            continue;
        }
        3.0 => float curve;
        1.0 - Math.pow(1.0 - gt.axis[2], curve) => float eased;
        (50/4) + (1800 * (1.0 - eased)) => float intervalMs;

        if (gt.axis[2] >= 0.8 || mode) {
            // intervalMs * 3 => quarterIntervalMs; // assume interval is a triplet
            intervalMs::ms => bongoInterval;
        } else {
            // add herky jerkiness if mode = 0
            1 - (gt.axis[2] / 0.8) => float randomnessRange;
            Std.rand2f(intervalMs * (1 - 0.9 * randomnessRange), intervalMs * (1 + 0.9 * randomnessRange))::ms => bongoInterval;
        }
        
        10::ms => now;
    }
}

// Main function to play buffer at random intervals
fun void playHits() {
    while (true) {
        if (mode != 1 && gt.axis[2] < 0.1) {
            10::ms => now;
            continue;
        } else if (!mode) {
            Std.rand2f(0.2, 0.7) => bufs_bongo_high[current].gain;
            Std.rand2f(-1.0 * (1 - Math.pow(gt.axis[2], 3)), 1.0 * (1 - Math.pow(gt.axis[2], 3))) => pans_bongo_high[current].pan;
        } else if (mode >= 1) {
            0.5 => bufs_bongo_high[current].gain;
        }
        spork ~ triggerSound(bufs_bongo_high[current], current);
        (1 + current) % N => current;
        bongoInterval => now;
    }
}

fun void triggerSound(SndBuf buf, int c) {
    buf.pos(1500);
    adsr_bongo_high[c].keyOn();
    12000::samp => now;
    adsr_bongo_high[c].keyOff();
    buf.pos((buf.length() / samp) $ int);
}

fun void changeBongoHighEnvelope() {
  while (true) {
    if (!mode) {
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
    while (true) {
        if (Math.max(0, discretizedGt0) > 0.1) {
            bongoEnv.keyOn();
            (20 + (1 - Math.max(0, discretizedGt0)) * 600)::ms => now; 
            bongoEnv.keyOff();

            (40 + (1 - Math.max(0, discretizedGt0)) * 500)::ms => now; 
        } else {
            bongoEnv.keyOn();
            10::ms => now;
        }
    }

}

spork ~ bongoHighPanMix();

spork ~ setBongoIntervalFreestyle();

spork ~ playHits();

spork ~ pulseBongoHighEnvelope() @=> Shred pulseBongoHighEnvelopeSporkId;

spork ~ changeBongoHighEnvelope();

0 => int isManualPrint;
fun playPrint() {
    (buf_print.samples() / 44100.0) / (quarterIntervalMs * 8 / 1000) => buf_print.rate;
    while (true) {
        0 => int hasPlayed;
        if (!isManualPrint) {
        for (48 => int i; i < 56; i++) {
            if (isManualPrint) {
                buf_print.pos(buf_print.samples());
            } else if (padState[i]) {
                1 => hasPlayed;
                Math.fabs(4.0 - (i - 48.0)) / 4.0 * 1.8 - 0.9 => pan_print.pan;
                buf_print.pos(buf_print.samples() / 8 * (i - 48));
                quarterIntervalMs::ms => now;
            } else {
                buf_print.pos(buf_print.samples());
                quarterIntervalMs::ms => now;
            }
        }
        }
        if (!hasPlayed) quarterIntervalMs::ms => now;
    }
}

fun playBassOnce() {
    0 => buf_bass.pos;
}

fun void playBass() {
    while (true) {
        for (56 => int i; i < 64; i++) {
            if (!padState[i]) {
                quarterIntervalMs::ms => now;
            } else if (padState[i] == 1) {
                spork ~ playBassOnce();
                (quarterIntervalMs)::ms => now;
            } else if (padState[i] == 2) {
                (quarterIntervalMs / 2)::ms => now;
                spork ~ playBassOnce();
                (quarterIntervalMs / 2)::ms => now;
            } else if (padState[i] == 3) {
                spork ~ playBassOnce();
                (quarterIntervalMs / 6)::ms => now;
                spork ~ playBassOnce();
                (quarterIntervalMs / 6)::ms => now;
                spork ~ playBassOnce();
                (quarterIntervalMs / 6)::ms => now;
            }
        }
    }
}

fun playTriangleOnce() {
    0 => buf_triangle_short.pos;
    adsr_triangle_short.keyOn();
    buf_triangle_short.samples()::samp - 5::ms => now;
    adsr_triangle_short.keyOff();
    5::ms => now;
}

fun void playTriangle() {
    while (true) {
        for (40 => int i; i < 48; i++) {
            if (!padState[i]) {
                quarterIntervalMs::ms => now;
            } else if (padState[i] == 1) {
                spork ~ playTriangleOnce();
                quarterIntervalMs::ms => now;
            } else if (padState[i] == 2) {
                spork ~ playTriangleOnce();
                (quarterIntervalMs / 2)::ms => now;
                spork ~ playTriangleOnce();
                (quarterIntervalMs / 2)::ms => now;
            } else if (padState[i] == 3) {
                spork ~ playTriangleOnce();
                (quarterIntervalMs / 3)::ms => now;
                spork ~ playTriangleOnce();
                (quarterIntervalMs / 3)::ms => now;
                spork ~ playTriangleOnce();
                (quarterIntervalMs / 3)::ms => now;
            }
        }
    }
}

// ------------ PAD ------------

0 => int pad_device;
if( me.args() ) me.arg(0) => Std.atoi => pad_device;

MidiIn min;
MidiOut mout;

if( !mout.open(0) ) me.exit();
MidiMsg pad_msg;

if( !min.open( pad_device ) ) me.exit();

/* --------- MIDI SETUP --------- */

144 => int NOTE_ON;
128 => int NOTE_OFF;
176 => int SLIDER;

0 => int OFF;
3 => int RED;
9 => int GREEN;

0 => int isShifted; // is shift currently pressed

fun void runPad() {
    while (true) {
        min => now;
        while (min.recv(pad_msg)) {
            pad_msg.data1 => int inputType; // pad number
            pad_msg.data2 => int pad;
            pad_msg.data3 => int velocity;
            // <<< inputType, pad, velocity >>>;
            if (mode >= 1 && pad >= 0 && pad < 7 && inputType == NOTE_ON) {
                // Play melody of bongo instrument using 8th row (bottom row)
                1 => padState[pad];
                for (int i; i < 5; i++) {
                    if (i == pad) {
                        1 => padState[pad];
                        mout.send(NOTE_ON, pad, GREEN);
                        noteToBongoInterval(pad) => bongoInterval;
                    } else {
                        0 => padState[i];
                        mout.send(NOTE_ON, i, RED);
                    }
                }
            } else if (mode >= 1 && pad >= 8 && pad < 12) {
                // Play rhythm of bongo instrument using 7th row
                pulseBongoHighEnvelopeSporkId.exit();
                spork ~ pulseBongoHighEnvelope() @=> pulseBongoHighEnvelopeSporkId;
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
            } else if (40 <= pad && pad < 48 && inputType == NOTE_ON) {
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
            } else if (48 <= pad && pad < 56 && inputType == NOTE_ON) {
                if (!padState[pad]) {
                    1 => padState[pad];
                    mout.send(NOTE_ON, pad, RED);
                } else {
                    0 => padState[pad];
                    mout.send(NOTE_ON, pad, OFF);
                }
            } else if (pad >= 56 && pad < 64 && inputType == NOTE_ON) {
                // Bass single rhythms
                (padState[pad] + 1) % 4 => int nextState;
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
                    0.0 => bongoMuter.gain;
                    mout.send(NOTE_ON, 89, RED);
                } else if (inputType == NOTE_OFF) {
                    1.0 => bongoMuter.gain;
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
            }
        }
    }
}
spork ~ runPad();

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
                }
            }
            
            // joystick button down
            else if( msg.isButtonDown() )
            {
                <<< "button", msg.which, "down" >>>;
                if (mode == 0) {
                    spork ~ prepMode1();
                    spork ~ playPrint();
                    spork ~ playBass();
                    spork ~ playTriangle();

                } else if (mode == 1) {
                    spork ~ slowBongoInstrument();
                }
                mode + 1 => mode;
                
            }
            
            // joystick button up
            else if( msg.isButtonUp() )
            {
                <<< "button", msg.which, "up" >>>;
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
        return (5.0 / 6.0) * bongoIntervalBase; // (minor third)
    } else if (i == 2) {
        return (2.0 / 3.0) * bongoIntervalBase; //  (perfect fifth)
    } else if (i == 3) {
        return (5.0 / 8.0) * bongoIntervalBase; //  (minor sixth)
    } else if (i == 4) {
        return (1.0 / 2.0) * bongoIntervalBase; //  (octave)
    }
    return bongoIntervalBase; // (root)
}

fun void prepMode1() {
    // Lock in base envelope and pitch for bongo instrument
    // default is eight notes
    ((20 + (1 - Math.max(0, discretizedGt0)) * 600) + (40 + (1 - Math.max(0, discretizedGt0)) * 500)) * 2 => quarterIntervalMs; 
    bongoInterval => bongoIntervalBase;
    mout.send(NOTE_ON, 0, GREEN);
    for (1 => int i; i < 5; i++) {
        mout.send(NOTE_ON, i, RED);
    }
    mout.send(NOTE_ON, 8, GREEN);
    for (9 => int i; i < 12; i++) {
        mout.send(NOTE_ON, i, RED);
    }
}

fun void slowBongoInstrument() {
    while (true) {
        (gt.axis[0] + 1.0) / 2.0 => discretizedGt0;
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

fun void setUp() {
    for (56 => int i; i < 64; i++) {
        0 => padState[i];
    }
    1 => padState[56];
    2 => padState[57];
    1 => padState[59];
    for (48 => int i; i < 56; i++) {
        0 => padState[i];
    }
    1 => padState[52];
    1 => padState[53];
    1 => padState[54];
    1 => padState[55];
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

    for (int i; i < 64; i++) {
        if (padState[i] == 0) {
            mout.send(NOTE_ON, i, OFF);
        } else if (padState[i] == 1) {
            mout.send(NOTE_ON, i, RED);
        } else if (padState[i] == 2) {
            mout.send(NOTE_ON, i, GREEN);
        }
    }
} spork ~ setUp();

eon => now;