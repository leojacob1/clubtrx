OscOut toNode;

"127.0.0.1" => string host;
7777 => int nodePort;

toNode.dest(host, nodePort);

0 => int currentChordIndex;
4 => int NUM_CHORD_VOICES;
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

0 => int mode;

Shred listenGtSh;
Shred trackSynthParamsSh;
Shred mainSh;

// patch it
Gain g => NRev reverb => PoleZero blocker => dac;
// 0 => g.gain;
// connect
// load file into a LiSa (use one LiSa per sound)
SoundFiles soundfiles;

// Load sound files into lisas
LiSa lisas[soundfiles.pluck.size()];
for (int i; i < soundfiles.pluck.size(); i++) {
    load(soundfiles.pluck[i]) @=> lisas[i];
    lisas[i].chan(0) => g;
    <<< soundfiles.pluck[i], "lisa loaded" >>>;
}

// Load sound files into lisaBass
LiSa lisaBass[soundfiles.bass.size()];
for (int i; i < soundfiles.bass.size(); i++) {
    load(soundfiles.bass[i]) @=> lisaBass[i];
    lisaBass[i].chan(0) => g;
    1.5 => lisaBass[i].gain;
    <<<soundfiles.bass[i], "lisa loaded" >>>;
}


int chords[6][2];

[10, 0] @=> chords[0];
[10, 11] @=> chords[1];
[3, 0] @=> chords[2];
[3, 11] @=> chords[3];
[0, 0] @=> chords[4];
[0, 11] @=> chords[5];

0.0 => float keyHz;
0 => int closestKeyIndex;

fun void listenKey()
{
    OscIn oin;
    OscMsg msg;
    8888 => oin.port;
    oin.addAddress( "/key, f" );
    while ( true )
        {
        oin => now;

        while ( oin.recv( msg ) )
        {
            msg.getFloat(0) => keyHz;
            <<< "original", keyHz >>>;
            getTargetHzInOctave(keyHz) => keyHz;
            <<< "octave adjust", keyHz >>>;
            getClosestKeyIndex(keyHz) => closestKeyIndex;
            keyHz / soundfiles.bassHz[closestKeyIndex] => GRAIN_PLAY_RATE;
            <<< "rate", GRAIN_PLAY_RATE >>>;
        }
    }
}

fun void listenMode() {
    OscIn oin;
    OscMsg msg;
    8888 => oin.port;
    oin.addAddress( "/mode, i" );
    while ( true )
        {
        oin => now;

        while ( oin.recv( msg ) )
        {
            msg.getInt(0) => mode;
            // if (mode == 22 || mode == 77) {
            //     spork ~ listenGt() @=> listenGtSh;
            //     spork ~ trackSynthParams() @=> trackSynthParamsSh;
            //     spork ~ main() @=> mainSh;
            // } else {
            //     Machine.remove(listenGtSh.id());
            //     Machine.remove(trackSynthParamsSh.id());
            //     Machine.remove(mainSh.id());
            // }
            <<< "mode", mode >>>;
        }
    }
}

float gt[6];
fun void listenGt() {
    OscIn oin;
    OscMsg msg;
    8888 => oin.port;
    oin.addAddress("/gt, i f");
    while (true) {
        oin => now;
        while (oin.recv(msg)) {
            msg.getInt(0) => int axis;
            msg.getFloat(1) => float value;
            value => gt[axis];
        }
    }
}

// reverb mix
.05 => reverb.mix;
// pole location to block DC and ultra low frequencies
.99 => blocker.blockZero;

spork ~ listenGt() @=> listenGtSh;
spork ~ trackSynthParams() @=> trackSynthParamsSh;
spork ~ main() @=> mainSh;

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
        if (mode != 0 && mode != 22 && mode != 77) {
            100::ms => now;
            continue;
        }
        mapAxis2Range(gt[2], 0.1, 0.5, 0.0, 1.0) => g.gain;
        mapAxis2Range(-gt[5], -0.5, 0.0, 0.01, 0.2) => GRAIN_POSITION;
        // Math.sqrt(Math.pow(gt.axis[4], 1.5) + Math.pow(gt.axis[3], 1.5)) => float rightJoyStickXYInput;
        // <<< rightJoyStickXYInput, gt.axis[4] >>>;
        250 * Math.pow(gt[4], 2) + 500 * gt[4] + 250 => float lengthInput;
        mapAxis2Range(lengthInput, 1.0, 1000.0, 1.0, 1000.0)::ms => GRAIN_LENGTH; // TODO: make this diff scale
        toNode.start( "/granular" );
        g.gain() => toNode.add;
        GRAIN_POSITION => toNode.add;
        GRAIN_LENGTH / ms => toNode.add;
        toNode.send();

        40::ms => now;
    }
}

// -------------------------------gametrack-------------------------------

// main loop
fun void main()
{
    while( true )
    {
        if (mode != 0 && mode != 22 && mode != 77) {
            100::ms => now;
            continue;
        }
        fireGrain(lisaBass[(closestKeyIndex + chords[currentChordIndex][0]) % 12]);
        fireGrain(lisas[(closestKeyIndex + chords[currentChordIndex][1]) % 12]); 
        // fireGrain(lisas[(closestKeyIndex + chords[currentChordIndex][2]) % 12]); 
        // fireGrain(lisas[(closestKeyIndex + chords[currentChordIndex][3]) % 12]);

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
        spork ~ grain( lisa, pos * lisa.duration(), grainLen, rampTime, rampTime, GRAIN_PLAY_RATE );
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

spork ~ listenKey();
spork ~ listenMode();

fun int getClosestKeyIndex(float targetHz) {
    <<< "getting closest key from", targetHz >>>;
    0 => int minIndex;

    Math.fabs(targetHz - soundfiles.bassHz[0]) => float minDiff;
    
    for (1 => int i; i < 12; i++) {
        if (Math.fabs(targetHz - soundfiles.bassHz[i]) < minDiff) {
            i => minIndex;
            Math.fabs(targetHz - soundfiles.bassHz[i]) => minDiff;
        }
    }
    <<< "minindex", minIndex, "mindistance", minDiff >>>;
    return minIndex;
}

fun float getTargetHzInOctave(float targetHz) {
    0 => int isRightOctave;
    while (!isRightOctave) {
        if (targetHz < soundfiles.bassHz[0]) {
            <<< targetHz, "too low!, bumping up" >>>;
            2 * targetHz => targetHz;
        } else if (targetHz > soundfiles.bassHz[0] * 2) {
            <<< "too high! dropping down" >>>;
            0.5 * targetHz => targetHz;
        } else {
            <<< "right octave" >>>;
            1 => isRightOctave;
        }
    }
    return targetHz;
}

eon => now;