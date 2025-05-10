SndBuf b => dac;
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
Pan2 pans_bongo_high[N];

// Connect each buffer to a pan and to dac
// Need panned buses and a center bus that can handle envelope
for (int i; i < N; i++) {
    0.0 => bufs_bongo_high[i].gain;
    bufs_bongo_high[i] => pans_bongo_high[i];
    pans_bongo_high[i].left => bongoBusLeft;
    pans_bongo_high[i].right => bongoBusRight;
    pans_bongo_high[i] => bongoBusCenter;
    path => bufs_bongo_high[i].read;
}

0 => int state;
/*
0 --> random hits
1 --> consistent hits
2 --> locked bpm (stored in quarterIntervalMs)
3 --> funky beat using buf rate (stored in kenkeniRateRhythm)
*/
600.0 => float quarterIntervalMs;

0.86 => float lowKenkeniHit;
0.9 => float midKenkeniHit;
0.92 => float highKenKeniHit;
[
    lowKenkeniHit, midKenkeniHit, highKenKeniHit, 
    midKenkeniHit, highKenKeniHit, midKenkeniHit,
    lowKenkeniHit, midKenkeniHit, highKenKeniHit, 
    midKenkeniHit, highKenKeniHit, midKenkeniHit,
    lowKenkeniHit, midKenkeniHit, highKenKeniHit, 
    midKenkeniHit, highKenKeniHit, midKenkeniHit,
    highKenKeniHit, highKenKeniHit, midKenkeniHit,
    highKenKeniHit, midKenkeniHit, highKenKeniHit,
] @=> float kenkeniRateRhythm[];

// Balance gains between panned buses and center bus
fun bongoHighPanMix() {
  while (true) {
    if (state) {
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

fun dur getInterval() {
    if (state >= 2) {
        return (quarterIntervalMs / 3)::ms;

        // if (gt.axis[2] < 0.3) {
        //     // Sixteenth notes = 1/4 of quarter
        //     return (quarterIntervalMs / 4)::ms;
        // } else if (gt.axis[2] < 0.5) {
        //     // Triplet eighths = 1/3 of quarter
        //     return (quarterIntervalMs / 3)::ms;
        // } else if (gt.axis[2] < 0.7) {
        //     // Eighth notes = 1/2 of quarter
        //     return (quarterIntervalMs / 2)::ms;
        // }
        // // Quarter notes
        // return quarterIntervalMs::ms;
    }


    // Apply eased mapping. more "gt.axis[2]" --> less "sec"
    3.0 => float curve;
    1.0 - Math.pow(1.0 - gt.axis[2], curve) => float eased;
    10 + (1800 * (1.0 - eased)) => float intervalMs;

    if (gt.axis[2] >= 0.8 || state) {
        intervalMs * 3 => quarterIntervalMs; // assume interval is a triplet
        return intervalMs::ms;
    }
    
    // add herky jerkiness if state = 0
    1 - (gt.axis[2] / 0.8) => float randomnessRange;
    return Std.rand2f(intervalMs * (1 - 0.9 * randomnessRange), intervalMs * (1 + 0.9 * randomnessRange))::ms;
}

// Main function to play buffer at random intervals
fun void playHits() {
    while (true) {
        if (!state && gt.axis[2] < 0.1) {
            10::ms => now;
            continue;
        } else if (!state) {
            Std.rand2f(0.3, 1.0) => bufs_bongo_high[current].gain;
            Std.rand2f(-1.0 * (1 - Math.pow(gt.axis[2], 3)), 1.0 * (1 - Math.pow(gt.axis[2], 3))) => pans_bongo_high[current].pan;
            0.5 + (gt.axis[0] + 1.0) / 2.0 => bufs_bongo_high[current].rate;
        } else if (state == 1) {
            0.8 => bufs_bongo_high[current].gain;
            0.5 + (gt.axis[0] + 1.0) / 2.0 => bufs_bongo_high[current].rate;
        } else if (state == 2) {
            current - 1 => int lockedRateIndex;
            if (current - 1 < 0) {
                24 - 1 => lockedRateIndex;
            }
            bufs_bongo_high[lockedRateIndex].rate() => bufs_bongo_high[current].rate;
            bufs_bongo_high[current].gain() - (current % 3 * 0.2) => bufs_bongo_high[current].gain;
            24 => N;
        } else if (state >= 3) {
            kenkeniRateRhythm[current % 24] => bufs_bongo_high[current].rate;
            bufs_bongo_high[current].gain() - (current % 3 * 0.1) => bufs_bongo_high[current].gain;
        }
        spork ~ triggerSound(bufs_bongo_high[current], current);
        (1 + current) % N => current;
        getInterval() => now;
    }
}

fun void triggerSound(SndBuf buf, int c) {
    // adjust for rate (manipulated by gt.axis[0])
    buf.pos((1500.0 / buf.rate()) $ int);
    (12000.0 / buf.rate())::samp => now;
    // 5000::samp + ((1 - Math.pow(gt.axis[2], 3)) * 6600)::samp => now;
    buf.pos((buf.length() / samp) $ int);
}

fun void changeBongoHighEnvelope() {
  while (true) {
    bongoEnv.attackTime((20 + (1 - gt.axis[5]) * 350)::ms);
    bongoEnv.decayTime((20 + (1 - Math.pow(gt.axis[5], 0.8)) * 300)::ms);
    bongoEnv.releaseTime((60 + (1 - Math.pow(gt.axis[5], 0.8)) * 500)::ms);
    10::ms => now;
  }
}

fun void pulseBongoHighEnvelope() {
    bongoEnv.keyOn();
    while (true) {
        if (gt.axis[5] > 0.2) {
          bongoEnv.keyOn();
          (20 + (1 - gt.axis[5]) * 600)::ms => now; 
          bongoEnv.keyOff();

          (40 + (1 - gt.axis[5]) * 500)::ms => now; 
        } else {
          bongoEnv.keyOn();
        }
        10::ms => now;
    }
}

spork ~ bongoHighPanMix();

spork ~ playHits();

spork ~ pulseBongoHighEnvelope();

spork ~ changeBongoHighEnvelope();

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
                state + 1 => state;
                <<< "NEW STATE", state >>>;
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