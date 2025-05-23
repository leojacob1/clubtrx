Gain bongoBusLeft => dac.left;
Gain bongoBusRight => dac.right;
Gain bongoBusCenter => ADSR bongoEnv => dac;

bongoEnv.set(0::ms, 0::ms, 1.0, 0::ms);

GameTrak gt;

// Need to cycle through bufs for rapid fire section
48 => int N;
0 => int current;
"kenkeni.aiff" => string path;

// Arrays to hold bufs and panners
SndBuf bufs_bongo_high[N];
ADSR adsr_bongo_high[N];
Pan2 pans_bongo_high[N];

// Connect each buffer to a pan and to dac
// Need panned buses and a center bus that can handle envelope
for (int i; i < N; i++) {
    0.0 => bufs_bongo_high[i].gain;
    adsr_bongo_high[i].set(5::ms, 0::ms, 1.0, 5::ms);
    bufs_bongo_high[i] => adsr_bongo_high[i] => pans_bongo_high[i];
    pans_bongo_high[i].left => bongoBusLeft;
    pans_bongo_high[i].right => bongoBusRight;
    pans_bongo_high[i] => bongoBusCenter;
    path => bufs_bongo_high[i].read;
}

0 => int mode;
/*
0 --> FREESTYLE (random hits)
1 --> MELODIC (consistent hits, discretized rates based on frequency ratios)
2 --> RHYTHMIC (discretized envelope rates at high levels, discretized rates at lower levels based on rhythms)
*/
720.0 => float quarterIntervalMs;
0.0 => float discretizedGt0;
Event syncEnvelopeRhythm;

25::ms => dur bongoInterval;


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

fun void fetchIntervalPreSync() {
    // Apply eased mapping. more "gt.axis[2]" --> less "sec"
    while (!mode) {
        3.0 => float curve;
        1.0 - Math.pow(1.0 - gt.axis[2], curve) => float eased;
        10 + (1800 * (1.0 - eased)) => float intervalMs;

        if (gt.axis[2] >= 0.8 || mode) {
            // intervalMs * 3 => quarterIntervalMs; // assume interval is a triplet
            intervalMs::ms => bongoInterval;
        }
        
        // add herky jerkiness if mode = 0
        1 - (gt.axis[2] / 0.8) => float randomnessRange;
        Std.rand2f(intervalMs * (1 - 0.9 * randomnessRange), intervalMs * (1 + 0.9 * randomnessRange))::ms => bongoInterval;
        10::ms => now;
    }
}

fun void fetchIntervalPostSync() {
    syncEnvelopeRhythm => now;
    while (true) {
        if (mode == 1) {
            if (gt.axis[2] < 0.1) {
                90::ms => bongoInterval; // 32nd note --> prepare for MODE == 2
            } else if (gt.axis[2] < 0.3) {
                25::ms => bongoInterval; // 40hz (root)
            } else if (gt.axis[2] < 0.5) {
                (125 / 6)::ms => bongoInterval; // 48hz (minor third)
            } else if (gt.axis[2] < 0.7) {
                (50 / 3)::ms => bongoInterval; // 60hz (perfect fifth)
            } else if (gt.axis[2] < 0.9) {
                (125 / 8)::ms => bongoInterval; // 64hz (minor sixth)
            } else {
                (50/4)::ms => bongoInterval; // 80hz (octave)
            }

        } else if (mode == 2) {
            if (gt.axis[2] < 0.3) {
                90::ms => bongoInterval; // 32
            } else if (gt.axis[2] < 0.5) {
                180::ms => bongoInterval; // sixteenth
            } else if (gt.axis[2] < 0.7) {
                240::ms => bongoInterval; // triplet
            } else if (gt.axis[2] < 0.9) {
                360::ms => bongoInterval; // eighth
            } else {
                720::ms => bongoInterval; // quarter 
            }
        }
        360::ms => now; // eighth note
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
        <<< "bongo Interval", bongoInterval >>>;
        bongoInterval => now;
    }
}

fun void triggerSound(SndBuf buf, int c) {
    // adjust for rate (manipulated by gt.axis[0])
    buf.pos(1500);
    adsr_bongo_high[c].keyOn();
    12000::samp => now;
    adsr_bongo_high[c].keyOff();
    // 5000::samp + ((1 - Math.pow(gt.axis[2], 3)) * 6600)::samp => now;
    buf.pos((buf.length() / samp) $ int);
}

fun void changeBongoHighEnvelope() {
  while (true) {
    if (!mode) Math.max(0, gt.axis[0]) => discretizedGt0;
    bongoEnv.attackTime((20 + (1 - discretizedGt0) * 350)::ms);
    bongoEnv.decayTime((20 + (1 - Math.pow(discretizedGt0, 0.8)) * 300)::ms);
    bongoEnv.releaseTime((60 + (1 - Math.pow(discretizedGt0, 0.8)) * 500)::ms);
    10::ms => now;
  }
}


fun void pulseBongoHighEnvelopePreSync() {
    bongoEnv.keyOn();
    while (!mode) {
        if (Math.max(0, gt.axis[0]) > 0.1) {
            bongoEnv.keyOn();
            (20 + (1 - Math.max(0, gt.axis[0])) * 600)::ms => now; 
            bongoEnv.keyOff();

            (40 + (1 - Math.max(0, gt.axis[0])) * 500)::ms => now; 
        } else {
            bongoEnv.keyOn();
            10::ms => now;
        }
    }
}

fun void pulseBongoHighEnvelopePostSync() {
    syncEnvelopeRhythm => now;
    float tempDiscretizedGt0; // in case it changes during envelope
    while (mode == 1) {
        discretizedGt0 => tempDiscretizedGt0;
        bongoEnv.keyOn();
        (20 + (1 - tempDiscretizedGt0) * 600)::ms => now; 
        bongoEnv.keyOff();

        (40 + (1 - tempDiscretizedGt0) * 500)::ms => now; 
    }
    bongoEnv.attackTime(0::ms);
    bongoEnv.keyOn();
}

// Did a lot of math to get these values
// Essentially the discretizedGt0 creates ratio-based rhythms
// when the value is used in pulseBongoHighEnvelope
fun void discretizeEnvelope() {
    syncEnvelopeRhythm => now;
    while (true) {
        Math.max(0, gt.axis[0]) => float positiveGt0;
        if (gt.axis[0] <= -0.5) {
            // <<< "quarter" >>>;
            0.7272727273 => discretizedGt0;
        } else if (gt.axis[0] <= -0.15) {
            // <<< "eight" >>>;

            0.8363636364 => discretizedGt0;
        } else if (positiveGt0 <= 0.15) {
            // <<< "triplet" >>>;
            0.8909090909 => discretizedGt0;
        } else if (gt.axis[0] <= 0.5) {
            // <<< "sixteenth" >>>;
            0.9454545455 => discretizedGt0;
        } else {
            // <<< "32" >>>;
            0.9727272727 => discretizedGt0;
        }
        360::ms => now; // eig TIMING
    }
}

spork ~ bongoHighPanMix();

spork ~ fetchIntervalPreSync();
spork ~ fetchIntervalPostSync();

spork ~ playHits();

spork ~ pulseBongoHighEnvelopePreSync();
spork ~ pulseBongoHighEnvelopePostSync();

spork ~ changeBongoHighEnvelope();

spork ~ discretizeEnvelope();

// ----------- GAMETRAK -----------

0 => float DEADZONE;

0 => int device;
if( me.args() ) me.arg(0) => Std.atoi => device;

Hid trak;
HidMsg msg;

if( !trak.openJoystick( device ) ) me.exit();

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
                mode + 1 => mode;
                <<< "NEW mode", mode >>>;
                if (mode == 1) {
                    syncEnvelopeRhythm.broadcast();
                }
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

eon => now;