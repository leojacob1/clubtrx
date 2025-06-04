0 => int currentChordIndex;
1 => int GROUP_NUM; // 1 or 2 based on explosionId
4 => int NUM_CHORD_VOICES;
// overall volume
1 => float MAIN_VOLUME;
// grain duration base
50::ms => dur GRAIN_LENGTH;
// factor relating grain duration to ramp up/down time
.5 => float GRAIN_RAMP_FACTOR;
// playback rate
1 => float GRAIN_PLAY_RATE;
// grain position (0 start; 1 end)
0 => float GRAIN_POSITION;
// grain position randomization
.001 => float GRAIN_POSITION_RANDOM;
// grain jitter (0 == periodic fire rate)
1 => float GRAIN_FIRE_RANDOM;

// max lisa voices
30 => int LISA_MAX_VOICES;

Shred gametrakSh;
Shred trackSynthParamsSh;
Shred mainSh;

// patch it
Gain g => NRev reverb => PoleZero blocker => dac;
// 0 => g.gain;
// connect
// load file into a LiSa (use one LiSa per sound)
SoundFiles soundfiles;
// Define the unused indexes
[7, 15, 16, 17, 18, 20, 22, 23, 25, 27] @=> int UNUSED_PLUCK[];
[2, 7, 8] @=> int UNUSED_BASS[];

// Function to check if an index is in the unused list
fun int isUnused(int unusedIndexes[], int index) {
    for (int i; i < unusedIndexes.size(); i++) {
        if (unusedIndexes[i] == index) return 1;
    }
    return 0;
}

// Load sound files into lisas
LiSa lisas[soundfiles.pluck.size()];
for (int i; i < soundfiles.pluck.size(); i++) {
    if (!isUnused(UNUSED_PLUCK, i)) {
        load(soundfiles.pluck[i]) @=> lisas[i];
        lisas[i].chan(0) => g;
        <<<soundfiles.pluck[i], "lisa loaded" >>>;
    }
}

// Load sound files into lisaBass
LiSa lisaBass[soundfiles.bass.size()];
for (int i; i < soundfiles.bass.size(); i++) {
    if (!isUnused(UNUSED_BASS, i)) {
        load(soundfiles.bass[i]) @=> lisaBass[i];
        lisaBass[i].chan(0) => g;
        <<<soundfiles.bass[i], "lisa loaded" >>>;
    }
}

<<< "LOADED" >>>;

// F
[
lisaBass[3], 
lisas[0], 
lisas[6], 
lisas[3], 
lisas[8]
] @=> LiSa F[];


// d minor
[
lisaBass[1], //d
lisas[1], // D
lisas[6], 
lisas[3],
lisas[9]
] @=> LiSa d[];

// A/C# 
[
    lisaBass[9], 
    lisas[24],   // A-1
    lisas[28], // C#
    lisas[2],  // E
    lisas[6],    // A
] @=> LiSa AC[];


// a minor /C# 
[
    lisaBass[0], //C
    lisas[24],   // A-1
    lisas[0], // C
    lisas[2],  // E
    lisas[6],    // A
] @=> LiSa ac[];


// Fmaj7 with BASSS
[
    lisaBass[3],
    lisas[21],  // F-1
    lisas[2],    // E
    lisas[6],    // A
    lisas[8],   // C2
] @=> LiSa fmaj7[];


// Eb
[
    lisaBass[10],
    lisas[21],  // G-1
    lisas[4],    // G
    lisas[30],    // Bb
    lisas[0],   // D2
] @=> LiSa Eb[];


// C6
[
lisaBass[0],
lisas[0], //C
lisas[4], //G
lisas[8], //C
lisas[10], //E
] @=> LiSa C6[];

// A7
[
lisaBass[6], //A
lisas[4], //G
lisas[29], //C#
lisas[10], //E2
lisas[23], // A-1
] @=> LiSa A7[];


// d6
[
lisaBass[1],
lisas[1], //D
lisas[6], //A
lisas[9], //D2
lisas[11], //F2
] @=> LiSa d6[];


// Eb6
[
lisaBass[10],
lisas[19], //Eb
lisas[30], //Bb
lisas[31], //Eb2
lisas[12], //G2
] @=> LiSa Eb6[];

// AbMaj7
[
lisaBass[5],
lisas[5], //Ab
lisas[8], //C2
lisas[31], //Eb2
lisas[12], //G2
] @=> LiSa AbMaj7[];


// fmin
[
lisaBass[3],
lisas[3], //F
lisas[8], //C2
lisas[11], //F2
lisas[13], //Ab2
] @=> LiSa fmin[];

// C# Maj7
[
lisaBass[9], // C#
lisas[3], //F
lisas[8], //C2
lisas[11], //F2
lisas[13], //Ab2
] @=> LiSa Csharp[];

// CMaj7
[
lisaBass[0], // C
lisas[0], //C
lisas[7], //B
lisas[10], //E2
lisas[12], //G2
] @=> LiSa Cmaj7[];


[
    F,
    d,
    AC,
    ac,
    fmaj7,
    Eb,
    C6,
    A7,
    d6, 
    //Eb6,
    //AbMaj7,
    //fmin,
    Csharp,
    Cmaj7

] @=> LiSa chords[][];



fun void listenExplosion()
{
                spork ~ gametrak() @=> gametrakSh;
            spork ~ trackSynthParams() @=> trackSynthParamsSh;
            spork ~ main() @=> mainSh;
            eon => now;

//   OscIn oin;
//   OscMsg msg;
//   7777 => oin.port;
//   oin.addAddress( "/explosion, i i" );
//   while ( true )
//   {
//     oin => now;

//     while ( oin.recv( msg ) )
//     {
//       if ( msg.getInt(0) == -1)
//       {
//         if (!gametrakSh.running())
//         {
//             <<< "EXPLOSION TIME " >>>;
//             spork ~ gametrak() @=> gametrakSh;
//             spork ~ trackSynthParams() @=> trackSynthParamsSh;
//             spork ~ main() @=> mainSh;
//         }
//       }
//       else if (msg.getInt(0) == -9)
//       {
//         if (gametrakSh.running())
//         { 
//             <<< "PSYCH! Undo explosion" >>>;
//             gametrakSh.exit();
//             trackSynthParamsSh.exit();
//             mainSh.exit();
//         }
//         <<< "Set up for explosion" >>>;
//       }
//       else if (GROUP_NUM == 1)
//       {
//         msg.getInt(0) => currentChordIndex;
//         <<< "Set chord index", currentChordIndex >>>;
//       }
//       else
//       {
//         <<< "error: UNPARSABLE EXPLOSION MESSAGE!" >>>;
//       }
//     }
//   }
}

// "cmaj7" => global string chord;


// reverb mix
.05 => reverb.mix;
// pole location to block DC and ultra low frequencies
.99 => blocker.blockZero;


//  -------------------------------Keyboard and GameTrak setup -------------------------------
Hid hi;
HidMsg msg;

// which joystick
0 => int device;
// get from command line
if( me.args() >= 4 ) me.arg(3) => Std.atoi => device;

// open joystick 0, exit on fail
if( !hi.openKeyboard( device ) ) me.exit();
// log
<<< "keyboard '" + hi.name() + "' ready", "" >>>;


0 => int DEADZONE;
0 => int GAME_TRAK_DEVICE;
Hid trak;
HidMsg msgTrak;

if( !trak.openJoystick( GAME_TRAK_DEVICE ) ) me.exit();
<<< "joystick '" + trak.name() + "' ready", "" >>>;

// keycodes (for MacOS; may need to change for other systems)
45 => int KEY_DASH;
46 => int KEY_EQUAL;
54 => int KEY_COMMA;
55 => int KEY_PERIOD;
79 => int KEY_RIGHT;
80 => int KEY_LEFT;
81 => int KEY_DOWN;
82 => int KEY_UP;

// spork it
// spork ~ print();
//spork ~ kb();

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
GameTrak gt;

// gametrack handling
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
                        1 - ((msg.axisPosition + 1) / 2) - DEADZONE => gt.axis[msg.which];
                        if( gt.axis[msg.which] < 0 ) 0 => gt.axis[msg.which];
                    }
                }
            }
            
            // joystick button down
            else if( msg.isButtonDown())
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

// -------------------------- mapping gt values -------------------------

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


fun void trackSynthParams()
{
    while (true)
    {
        mapAxis2Range(gt.axis[2], 0.1, 0.5, 0.0, 1.0) => g.gain;
        mapAxis2Range(-gt.axis[5], -0.5, 0.0, 0.01, 0.2) => GRAIN_POSITION;
        // Math.sqrt(Math.pow(gt.axis[4], 1.5) + Math.pow(gt.axis[3], 1.5)) => float rightJoyStickXYInput;
        // <<< rightJoyStickXYInput, gt.axis[4] >>>;
        250 * Math.pow(gt.axis[4], 2) + 500 * gt.axis[4] + 250 => float lengthInput;
        mapAxis2Range(lengthInput, 1.0, 1000.0, 1.0, 1000.0)::ms => GRAIN_LENGTH; // TODO: make this diff scale


        20::ms => now;
    }
}

// -------------------------------gametrack-------------------------------

// main loop
fun void main()
{
    while( true )
    {
        if (currentChordIndex >= chords.size()) {
            chords.size() - 1 => currentChordIndex;
        }
        fireGrain(chords[currentChordIndex][0]); // bass note
        fireGrain(chords[currentChordIndex][1 + (0 % NUM_CHORD_VOICES)]); // specific voice

        // amount here naturally controls amount of overlap between grains
        (GRAIN_LENGTH / 2 + Math.random2f(0,GRAIN_FIRE_RANDOM)::ms)/2 => now;
    }
}


// fire!
fun void fireGrain(LiSa lisa)
{
    // grain length
    GRAIN_LENGTH => dur grainLen;
    // ramp time
    GRAIN_LENGTH * GRAIN_RAMP_FACTOR => dur rampTime;
    // play pos
    GRAIN_POSITION + Math.random2f(0,GRAIN_POSITION_RANDOM) => float pos;
    // a grain
    if( lisa != null && pos >= 0 )
    {
        spork ~ grain( lisa, pos * lisa.duration(), grainLen, rampTime, rampTime, 
        GRAIN_PLAY_RATE );
    }
}

// grain sporkee
fun void grain( LiSa @ lisa, dur pos, dur grainLen, dur rampUp, dur rampDown, float rate )
{
    // get a voice to use
    lisa.getVoice() => int voice;
    
    // if available
    if( voice > -1 )
    {
        // set rate
        lisa.rate( voice, rate );
        // set playhead
        lisa.playPos( voice, pos );
        // ramp up
        lisa.rampUp( voice, rampUp );
        // wait
        (grainLen - rampUp) => now;
        // ramp down
        lisa.rampDown( voice, rampDown );
        // wait
        rampDown => now;
    }
}

// print
fun void print()
{
    // time loop
    while( true )
    {
        // values
        <<< "pos:", GRAIN_POSITION, "random:", GRAIN_POSITION_RANDOM,
        "rate:", GRAIN_PLAY_RATE, "size:", GRAIN_LENGTH/second >>>;
        // advance time
        100::ms => now;
    }
}

// keyboard
fun void kb()
{
    // infinite event loop
    while( true )
    {
        // wait on HidIn as event
        hi => now;
        
        // messages received
        while( hi.recv( msg ) )
        {
            // button donw
            if( msg.isButtonDown() )
            {
                if( msg.which == KEY_LEFT )
                {
                    .005 -=> GRAIN_PLAY_RATE;
                    if( GRAIN_PLAY_RATE < 0 ) 0 => GRAIN_PLAY_RATE;
                }
                else if( msg.which == KEY_RIGHT )
                {
                    .005 +=> GRAIN_PLAY_RATE;
                    if( GRAIN_PLAY_RATE > 2 ) 2 => GRAIN_PLAY_RATE;
                }
                else if( msg.which == KEY_DOWN )
                {
                    .01 -=> GRAIN_POSITION;
                    if( GRAIN_POSITION < 0 ) 0 => GRAIN_POSITION;
                }
                else if( msg.which == KEY_UP )
                {
                    .01 +=> GRAIN_POSITION;
                    if( GRAIN_POSITION > 1 ) 1 => GRAIN_POSITION;
                }
                else if( msg.which == KEY_COMMA )
                {
                    .95 *=> GRAIN_LENGTH;
                    if( GRAIN_LENGTH < 1::ms ) 1::ms => GRAIN_LENGTH;
                }
                else if( msg.which == KEY_PERIOD )
                {
                    1.05 *=> GRAIN_LENGTH;
                    if( GRAIN_LENGTH > 1::second ) 1::second => GRAIN_LENGTH;
                }
                else if( msg.which == KEY_DASH )
                {
                    .9 *=> GRAIN_POSITION_RANDOM;
                    if( GRAIN_POSITION_RANDOM < .000001 ) .000001 => GRAIN_POSITION_RANDOM;
                }
                else if( msg.which == KEY_EQUAL )
                {
                    1.1 *=> GRAIN_POSITION_RANDOM;
                    if( GRAIN_POSITION_RANDOM > 1 ) 1 => GRAIN_POSITION_RANDOM;
                }
            }
        }
    }
}

// load file into a LiSa
fun LiSa load( string filename )
{
    // sound buffer
    SndBuf buffy;
    // load it
    filename => buffy.read;
    
    // new LiSa
    LiSa lisa;
    // set duration
    buffy.samples()::samp => lisa.duration;
    
    // transfer values from SndBuf to LiSa
    for( 0 => int i; i < buffy.samples(); i++ )
    {
        // args are sample value and sample index
        // (dur must be integral in samples)
        lisa.valueAt( buffy.valueAt(i), i::samp );        
    }
    
    // set LiSa parameters
    lisa.play( false );
    lisa.loop( false );
    lisa.maxVoices( LISA_MAX_VOICES );
    return lisa;
}

spork ~ listenExplosion();

eon => now;