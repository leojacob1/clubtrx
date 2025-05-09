SndBuf b => dac;
Gain bongoBusLeft => dac.left;
Gain bongoBusRight => dac.right;
Gain bongoBusCenter => ADSR bongoEnv => dac;
BRF bongoBrf;

GameTrak gt;

// Set frequency and Q (bandwidth)
340.0 => bongoBrf.freq;  // notch center frequency
10.0 => bongoBrf.Q;       // quality factor — higher = narrower notch

// Constants
10 => int N;
"kenkeni.aiff" => string path;

// Arrays to hold bufs and panners
SndBuf bufs_bongo_high[N];
Pan2 pans_bongo_high[N];

// Connect each buffer to a pan and to dac
for (int i; i < N; i++) {
    bufs_bongo_high[i] => pans_bongo_high[i];
    pans_bongo_high[i].left => bongoBusLeft;
    pans_bongo_high[i].right => bongoBusRight;
    pans_bongo_high[i] => bongoBusCenter;
    path => bufs_bongo_high[i].read;
}

// Index tracker
0 => int current;

// Load the audio file
"bongo_low.wav" => b.read;

fun dur getBeatDur() {
    // Linearly interpolate between 60 and 220 BPM
    60.0 + (220.0 - 60.0) * Math.fabs((gt.axis[0] + 1) / 2.0) => float bpm;
    return (60.0 / bpm)::second; // duration of a beat
}

// Function to play SndBuf at tempo
fun void playAtTempo(SndBuf buf) {
    while (true) {
        buf.pos(0);       // rewind
        getBeatDur() => now; // wait based on tempo
    }
}

fun bongoHighPanMix() {
  while (true) {
    Math.max(0, 1 - (gt.axis[2] / 0.8)) => bongoBusLeft.gain;
    Math.max(0, 1 - (gt.axis[2] / 0.8)) => bongoBusRight.gain;
    gt.axis[2] / 0.8 => bongoBusCenter.gain;
    10::ms => now;
  }
}

spork ~ bongoHighPanMix();

// Function to map density to interval range
fun dur randomInterval() {
    float randomnessRange;
    // Density 0 = very sparse (max 2 sec); density 1 = dense (min ~50ms)
    if (gt.axis[2] >= 0.8) {
        0 => randomnessRange;
    } else {
        1 - (gt.axis[2] / 0.8) => randomnessRange;
    }

    3.0 => float curve;

    // Apply eased mapping: slow rise toward 1
    1.0 - Math.pow(1.0 - gt.axis[2], curve) => float eased;

    // Map to interval range (0.2s to 2.0s)
    0.01 + (1.8 * (1.0 - eased)) => float sec;

    return Std.rand2f(sec * (1 - 0.9 * randomnessRange), sec * (1 + 0.9 * randomnessRange))::second;
}

// Main function to play buffer at random intervals
fun void playRandom() {
    while (true) {
        // Random gain between 0.3 and 1.0
        Std.rand2f(0.3, 1.0) => bufs_bongo_high[current].gain;

        // Random pan between -1.0 (left) and 1.0 (right)
        Std.rand2f(-1.0 * (1 - Math.pow(gt.axis[2], 3)), 1.0 * (1 - Math.pow(gt.axis[2], 3))) => pans_bongo_high[current].pan;

        // Trigger the sound
        1.33 => bufs_bongo_high[current].rate;
        spork ~ triggerSound(bufs_bongo_high[current], current);
        (1 + current) % 10 => current;

        // Wait random duration based on density
        randomInterval() => now;
    }
}

fun triggerSound(SndBuf buf, int c) {
    buf.pos(1500);
    5000::samp + ((1 - Math.pow(gt.axis[2], 3)) * 6600)::samp => now;
    buf.pos((buf.length() / samp) $ int);
}



// Set sharp attack and quick decay
bongoEnv.set(0::ms, 0::ms, 1.0, 0::ms);

fun void changeBongoHighEnvelope() {
  while (true) {
    bongoEnv.attackTime((20 + (1 - gt.axis[5]) * 350)::ms);
    bongoEnv.decayTime((20 + (1 - gt.axis[5]) * 400)::ms);
    bongoEnv.releaseTime((60 + (1 - gt.axis[5]) * 550)::ms);
    10::ms => now;
  }
}

fun void pulseBongoHighEnvelope() {
  bongoEnv.keyOn();
    while (true) {
        if (gt.axis[5] > 0.2) {
          bongoEnv.keyOn();
          (40 + (1 - gt.axis[5]) * 600)::ms => now;   // brief press
          bongoEnv.keyOff();

          (80 + (1 - gt.axis[5]) * 400)::ms => now; // interval between pulses
        } else {
          bongoEnv.keyOn();
        }
        10::ms => now;
    }
}
// Spork it
spork ~ playRandom();

// spork ~ playAtTempo(b);

spork ~ pulseBongoHighEnvelope();

spork ~ changeBongoHighEnvelope();

0 => float DEADZONE;

// which joystick
0 => int device;
// get from command line
if( me.args() ) me.arg(0) => Std.atoi => device;

// HID objects
Hid trak;
HidMsg msg;

// // open joystick 0, exit on fail
if( !trak.openJoystick( device ) ) me.exit();

// print
<<< "joystick '" + trak.name() + "' ready", "" >>>;

// data structure for gametrak
class GameTrak
{
    // timestamps
    time lastTime;
    time currTime;
    
    // previous axis data
    float lastAxis[6];
    // current axis data
    float axis[6];
}

// gametrack

spork ~ gametrak();

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
                // check which
                if( msg.which >= 0 && msg.which < 6 )
                {
                    // check if fresh
                    if( now > gt.currTime )
                    {
                        // time stamp
                        gt.currTime => gt.lastTime;
                        // set
                        now => gt.currTime;
                    }
                    // save last
                    gt.axis[msg.which] => gt.lastAxis[msg.which];
                    // the z axes map to [0,1], others map to [-1,1]
                    if( msg.which != 2 && msg.which != 5 )
                    { msg.axisPosition => gt.axis[msg.which]; }
                    else
                    {
                        Math.min(0.78, (1 - ((msg.axisPosition + 1) / 2) - DEADZONE) / 0.78) / 0.78=> gt.axis[msg.which];
                        if( gt.axis[msg.which] < 0 ) 0 => gt.axis[msg.which];
                    }
                }
            }
            
            // joystick button down
            else if( msg.isButtonDown() )
            {
                <<< "button", msg.which, "down" >>>;
            }
            
            // joystick button up
            else if( msg.isButtonUp() )
            {
                <<< "button", msg.which, "up" >>>;
            }
        }
    }
}

eon => now;