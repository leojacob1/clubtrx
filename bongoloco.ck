SndBuf b => dac;
Gain bongoBusLeft => dac.left;
Gain bongoBusRight => dac.right;
Gain bongoBusCenter => ADSR bongoEnv => dac;

bongoEnv.set(0::ms, 0::ms, 1.0, 0::ms);

GameTrak gt;

// Need to cycle through bufs for rapid fire section
60 => int N;
0 => int current;
"kenkeni.aiff" => string path;

// Arrays to hold bufs and panners
SndBuf bufs_bongo_high[N];
Pan2 pans_bongo_high[N];

// Connect each buffer to a pan and to dac
// Need panned buses and a center bus that can handle envelope
for (int i; i < N; i++) {
    bufs_bongo_high[i] => pans_bongo_high[i];
    pans_bongo_high[i].left => bongoBusLeft;
    pans_bongo_high[i].right => bongoBusRight;
    pans_bongo_high[i] => bongoBusCenter;
    path => bufs_bongo_high[i].read;
}

1 => int isRandom; // after rapid fire go into stable rhythm

// fun dur getBeatDur() {
//     // Linearly interpolate between 60 and 220 BPM
//     60.0 + (220.0 - 60.0) * Math.fabs((gt.axis[0] + 1) / 2.0) => float bpm;
//     return (60.0 / bpm)::second; // duration of a beat
// }

// // Function to play SndBuf at tempo
// fun void playAtTempo(SndBuf buf) {
//     while (true) {
//         buf.pos(0);       // rewind
//         getBeatDur() => now; // wait based on tempo
//     }
// }

// Balance gains between panned buses and center bus
fun bongoHighPanMix() {
  while (true) {
    if (!isRandom) {
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

fun dur randomInterval() {
    float randomnessRange;

    3.0 => float curve;

    // Apply eased mapping. more "gt.axis[2]" --> less "sec"
    1.0 - Math.pow(1.0 - gt.axis[2], curve) => float eased;
    0.01 + (1.8 * (1.0 - eased)) => float sec;

    if (gt.axis[2] >= 0.8 || !isRandom) {
        return sec::second;
    }
    
    // add herky jerkiness if isRandom
    1 - (gt.axis[2] / 0.8) => randomnessRange;
    return Std.rand2f(sec * (1 - 0.9 * randomnessRange), sec * (1 + 0.9 * randomnessRange))::second;
}

// Main function to play buffer at random intervals
fun void playRandom() {
    while (true) {
        if (isRandom) {
            Std.rand2f(0.3, 1.0) => bufs_bongo_high[current].gain;
            Std.rand2f(-1.0 * (1 - Math.pow(gt.axis[2], 3)), 1.0 * (1 - Math.pow(gt.axis[2], 3))) => pans_bongo_high[current].pan;
        }

        0.5 + (gt.axis[0] + 1.0) / 2.0 => bufs_bongo_high[current].rate;
        spork ~ triggerSound(bufs_bongo_high[current], current);
        (1 + current) % N => current;
        randomInterval() => now;
    }
}

fun void triggerSound(SndBuf buf, int c) {
    // adjust for rate (manipulated by gt.axis[0])
    buf.pos(1500.0 / buf.rate());
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

spork ~ playRandom();

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
                (isRandom + 1) % 2 => isRandom;
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