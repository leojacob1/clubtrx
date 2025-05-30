Gain bongoBusLeft => dac.left;
Gain bongoBusRight => dac.right;
Gain bongoBusCenter => ADSR bongoEnv => dac;

// SndBuf bufDino => Gain gainDino => Pan2 panDino => dac;
// me.dir() + "processed_dino_screech.wav" => bufDino.read;
// bufDino.samples() => bufDino.pos;

// bufDino.samples() => int numSamples;

// // Get the sample rate (usually 44100 Hz unless changed)
// 44100 => int sampleRate;

// // Convert to milliseconds
// (numSamples * 1000.0 / sampleRate) => float durationMs;
// <<< "DURATION", durationMs >>>;

bongoEnv.set(0::ms, 0::ms, 1.0, 0::ms);

GameTrak gt;

// Need to cycle through bufs for rapid fire section
48 => int N;
0 => int current;
"kenkeni.aiff" => string kenkeni_path;
"triangle_long.wav" => string triangle_long_path;
"triangle_short.wav" => string triangle_short_path;

// Sndbufs for rhythmic elements in second part
SndBuf buf_single_bongo => ADSR adsr_single_bongo => Gain gain_single_bongo => dac;
SndBuf buf_triangle_long => ADSR adsr_triangle_long => Gain gain_triangle_long => dac;
SndBuf buf_triangle_short => ADSR adsr_triangle_short => Gain gain_triangle_short => dac;

// Arrays to hold bufs and panners
SndBuf bufs_bongo_high[N];
ADSR adsr_bongo_high[N];
Pan2 pans_bongo_high[N];

// Connect each buffer to a pan and to dac
// Need panned buses and a center bus that can handle envelope
kenkeni_path => buf_single_bongo.read;
triangle_long_path => buf_triangle_long.read;
triangle_short_path => buf_triangle_short.read;

buf_single_bongo.samples() => buf_single_bongo.pos;
buf_triangle_long.samples() => buf_triangle_long.pos;
buf_triangle_short.samples() => buf_triangle_short.pos;

adsr_single_bongo.set(5::ms, 0::ms, 1.0, 5::ms);
adsr_triangle_long.set(5::ms, 0::ms, 1.0, 5::ms);
adsr_triangle_short.set(5::ms, 0::ms, 1.0, 5::ms);

0.8 => gain_single_bongo.gain;
0.4 => gain_triangle_long.gain;
0.4 => gain_triangle_short.gain;

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
XXXXX table for now -> 2 --> RHYTHMIC (discretized envelope rates at high levels, discretized rates at lower levels based on rhythms)
*/
720.0 => float quarterIntervalMs;
0.0 => float gt0Base;
0.0 => float discretizedGt0;

Shred pulseBongoHighEnvelopeSporkId;
25::ms => dur bongoInterval;
25::ms => dur bongoIntervalBase;

// Balance gains between panned buses and center bus
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
    while (!mode) {
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
        if (!mode && gt.axis[2] < 0.1) {
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
        bongoEnv.attackTime((20 + (1 - discretizedGt0) * 350)::ms);
        bongoEnv.decayTime((20 + (1 - Math.pow(discretizedGt0, 0.8)) * 300)::ms);
        bongoEnv.releaseTime((60 + (1 - Math.pow(discretizedGt0, 0.8)) * 500)::ms);
    }
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

spork ~ pulseBongoHighEnvelope() @=> pulseBongoHighEnvelopeSporkId;

spork ~ changeBongoHighEnvelope();

// ------------ Dino ------------

0 => int isBongoActive;
0 => int isManualBongo;
fun playBongoOnce() {
    1 => isBongoActive;
    1500 => buf_single_bongo.pos;
    adsr_single_bongo.keyOn();
    buf_single_bongo.samples()::samp - 10::ms => now;
    adsr_single_bongo.keyOff();
    0 => isBongoActive;
}

fun void playBongoRhythm() {
    while (true) {
        if (!isManualBongo) {
            for (56 => int i; i < 64; i++) {
                if (isManualBongo) {
                    continue;
                } else if (padState[i]) {
                    if (padState[i] == 1) {
                        spork ~ playBongoOnce();
                        (quarterIntervalMs / 2)::ms => now;
                    } else if (padState[i] == 2) {
                        spork ~ playBongoOnce();
                        (quarterIntervalMs / 4)::ms => now;
                        spork ~ playBongoOnce();
                        (quarterIntervalMs / 4)::ms => now;
                    } else if (padState[i] == 3) {
                        spork ~ playBongoOnce();
                        (quarterIntervalMs / 6)::ms => now;
                        spork ~ playBongoOnce();
                        (quarterIntervalMs / 6)::ms => now;
                        spork ~ playBongoOnce();
                        (quarterIntervalMs / 6)::ms => now;
                    }
                } else {
                    (quarterIntervalMs / 2)::ms => now;
                }
            }
        } else {
            (quarterIntervalMs / 2)::ms => now;
        }
    }
}

// fun playManualDino(int i) {
//     1735.260771 / (quarterIntervalMs * 4) => bufDino.rate;
//     <<< "dino", i >>>;
// //   if (gainPots.gain() > 0.01) pad - 56 => activePotId;
// //   mout.send(144, pad, GREEN);
//     i / 7.0 * 1.8 - 0.9 => panDino.pan;
//     bufDino.pos(bufDino.samples() / 4 * i);
//     (quarterIntervalMs * 4)::ms => now;
//     <<< "dino done", i >>>;
//     bufDino.pos(bufDino.samples());
// //   mout.send(144, pad, OFF);
//     // -1 => activePotId;
// }


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

fun void runPad() {
    // Shred manualDinoSh;
    // int activeManualPad;
    while (true) {
    min => now;
    while (min.recv(pad_msg)) {
        pad_msg.data1 => int inputType; // pad number
        pad_msg.data2 => int pad;
        pad_msg.data3 => int velocity;
        // <<< inputType, pad, velocity >>>;
        if (mode == 1 && pad >= 0 && pad < 7 && inputType == NOTE_ON) {
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
        } else if (mode == 1 && pad >= 8 && pad < 14) {
            // Play rhythm of bongo instrument using 7th row
            pulseBongoHighEnvelopeSporkId.exit();
            spork ~ pulseBongoHighEnvelope() @=> pulseBongoHighEnvelopeSporkId;
            getDiscretizedGt0(pad - 8) => discretizedGt0;
            bongoEnv.attackTime((20 + (1 - discretizedGt0) * 350)::ms);
            bongoEnv.decayTime((20 + (1 - Math.pow(discretizedGt0, 0.8)) * 300)::ms);
            bongoEnv.releaseTime((60 + (1 - Math.pow(discretizedGt0, 0.8)) * 500)::ms);
            1 => padState[pad];
            for (8 => int i; i < 14; i++) {
                if (i == pad) {
                    1 => padState[pad];
                    mout.send(NOTE_ON, pad, GREEN);
                } else {
                    0 => padState[i];
                    mout.send(NOTE_ON, i, RED);
                }
            }
        } else if (mode == 1 && pad >= 56 && pad < 64 && inputType == 144) {
            // Bongo single rhythms
            (padState[pad] + 1) % 4 => int nextState;
            nextState => padState[pad];
            if (nextState == 0) {
                mout.send(144, pad, OFF);
            } else if (nextState == 1) {
                mout.send(144, pad, RED);
            } else if (nextState == 2) {
                mout.send(144, pad, GREEN);
            }
        }/*else if (mode == 1 && pad == 53 && inputType >= 144 && inputType <= 151) {
        // Manual dino?
        if (manualDinoSh.id()) {
            Machine.remove(manualDinoSh.id());
            mout.send(144, activeManualPad, OFF);
        }
        pad => activeManualPad;
        <<< "spork" >>>;
        spork ~ playManualDino(inputType - 144) @=> manualDinoSh;
      }*/
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
                if (mode == 0) spork ~ prepMode1();
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
    quarterIntervalMs => float newIntervalMs;
    if (i == 0) {
        // Nothing. just a quarter note
    } else if (i == 1) {
        // <<< "eighth" >>>;
        quarterIntervalMs / 2 => newIntervalMs;
    } else if (i == 2) {
        // <<< "triplet" >>>;
        quarterIntervalMs / 3 => newIntervalMs;
    } else if (i == 3) {
        // <<< "16" >>>;
        quarterIntervalMs / 4 => newIntervalMs;
    } else if (i == 4) {
        // <<< "32" >>>;
        quarterIntervalMs / 6 => newIntervalMs;
    } else if (i == 5) {
        quarterIntervalMs / 8 => newIntervalMs;
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
    discretizedGt0 => gt0Base;
    (20 + (1 - Math.max(0, gt0Base)) * 600) + (40 + (1 - Math.max(0, gt0Base)) * 500) => quarterIntervalMs; 
    bongoInterval => bongoIntervalBase;
    mout.send(NOTE_ON, 0, GREEN);
    for (1 => int i; i < 5; i++) {
        mout.send(NOTE_ON, i, RED);
    }
    mout.send(NOTE_ON, 8, GREEN);
    for (9 => int i; i < 14; i++) {
        mout.send(NOTE_ON, i, RED);
    }
    playBongoRhythm();
}

fun setUp() {
    for (56 => int i; i < 64; i++) {
        0 => padState[i];
        mout.send(144, i, OFF);
    }
    for (48 => int i; i < 56; i++) {
        0 => padState[i];
        mout.send(144, i, OFF);
    }
    for (40 => int i; i < 48; i++) {
        0 => padState[i];
        mout.send(144, i, OFF);
    }
    for (32 => int i; i < 40; i++) {
        0 => padState[i];
        mout.send(144, i, OFF);
    }
    for (24 => int i; i < 32; i++) {
        0 => padState[i];
        mout.send(144, i, OFF);
    }
    for (16 => int i; i < 24; i++) {
        0 => padState[i];
        mout.send(144, i, OFF);
    }
    for (8 => int i; i < 16; i++) {
        0 => padState[i];
        mout.send(144, i, OFF);
    }
    for (0 => int i; i < 8; i++) {
        0 => padState[i];
        mout.send(144, i, OFF);
    }
    mout.send(144, 82, OFF);
    mout.send(144, 83, OFF);
    mout.send(144, 84, OFF);
    mout.send(144, 85, OFF);
    mout.send(144, 16, OFF);
    mout.send(144, 23, OFF);
    mout.send(144, 8, OFF);
    mout.send(144, 15, OFF);
    mout.send(144, 0, OFF);
    mout.send(144, 7, OFF);
    mout.send(144, 89, OFF);
} spork ~ setUp();

eon => now;