/* --------- SETUP --------- */
OscOut toNode;
"127.0.0.1" => string host;
7777 => int nodePort;
toNode.dest(host, nodePort);

SndBuf bufPots => Gain gainPots => Gain gain_monitor_pots => Pan2 panPots => dac;
SndBuf bufKick[16];
Gain gainKick => Gain gainKickMaster;
Gain gainKickBpf => BPF bpfKick => gainKickMaster;
gainKickMaster => Gain gain_monitor_bass => dac;

SndBuf bufFadi => ADSR envFadi => PitShift shiftFadi1 => PitShift shiftFadi2 => Gain gainFadi => Gain gain_monitor_fadi => JCRev revFadi => Pan2 panFadi => dac;

1.0 / 18 => gainKick.gain;

// ROOM ADJUSTMENT VARS

1.0 => float kickAdjustment;
1.0 => float fadiAdjustment;
1.0 => float potsAdjustment;

envFadi.set(5::ms, 5::ms, 0.7, 100::ms);
-2 => shiftFadi1.shift;
1.0 => bufFadi.rate;
12.0 * fadiAdjustment => bufFadi.gain;
0.07 => revFadi.mix;
0.4 => revFadi.gain;
  
0.6 * potsAdjustment => bufPots.gain;

20 => bpfKick.Q;

for (int i; i < 16; i++) {
  bufKick[i] => gainKick;
  bufKick[i] => gainKickBpf;
  "sounds/" + "kick.wav" => bufKick[i].read;
  bufKick[i].samples() => bufKick[i].pos;
  100 * kickAdjustment => bufKick[i].gain;
}

"sounds/" + "pots.wav" => bufPots.read;
"sounds/" + "fadi.wav" => bufFadi.read;

bufPots.samples() => bufPots.pos;
bufFadi.samples() => bufFadi.pos;

(bufPots.samples() / 8)::samp => dur eighth;
(bufPots.samples() / 16)::samp => dur sixteenth;

0 => int mode;
fun void listenMode()
{
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
            if (mode == 22) {
              if (isKilled) Machine.remove(runPadSh.id());
            } else if (mode == 11) {
              if( !mout.open(0) ) me.exit();
              if( !min.open( device ) ) me.exit();
              spork ~ runPad() @=> runPadSh;
              spork ~ playPots() @=> playPotsSh;
              spork ~ playKick() @=> playKickSh;
              spork ~ playFadi() @=> playFadiSh;
              clearPadState();
            }
        }
    }
}

0 => int device;
if( me.args() ) me.arg(0) => Std.atoi => device;

MidiIn min;
MidiOut mout;
MidiMsg msg;

144 => int NOTE_ON;
128 => int NOTE_OFF;
176 => int SLIDER;

0 => int OFF;
3 => int RED;
9 => int GREEN;

int padState[64];
int padStateRaw[64];

0 => int potOverrideStatus; // 0 - normal, 1 - all on, 2 - all off
0 => int kickOverrideStatus; // 0 - normal, 1 - all on, 2 - all off
0 => int fadiOverrideStatus; // 0 - normal, 1 - all on, 2 - all off

0 => int isKilled;
Shred runPadSh;
Shred playPotsSh;
Shred playFadiSh;
Shred playKickSh;

// Fill it with 64 zeros
fun void clearPadState() {
  for (0 => int i; i < 64; i++) {
      0 => padState[i];
      mout.send(144, i, OFF);
  }
}


fun setUp() {
  clearPadState();

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
  mout.send(144, 88, OFF);
  mout.send(144, 89, OFF);
} spork ~ setUp();


/* --------- Live audio code --------- */

fun playManualPots(int pad) {
  if (gainPots.gain() > 0.01) pad - 56 => activePotId;
  mout.send(144, pad, GREEN);
  (pad - 56.0) / 7.0 * 1.8 - 0.9 => panPots.pan;
  bufPots.pos(bufPots.samples() / 8 * (pad - 56));
  eighth => now;
  bufPots.pos(bufPots.samples());
  mout.send(144, pad, OFF);
  -1 => activePotId;
}

fun playManualFadi() {
  mout.send(144, 85, RED);
  6000 => bufFadi.pos;
  envFadi.keyOn();
  25::ms => now;
  envFadi.keyOff();
  100::ms => now;
  mout.send(144, 85, OFF);
}

fun void kill() {
  0 => gainKickMaster.gain;
  0 => gainPots.gain;
  0 => gainFadi.gain;
  toNode.start( "/kill" );
  1 => toNode.add;
  toNode.send();
  mout.send(144, 89, RED);
  Machine.remove(playPotsSh.id());
  Machine.remove(playKickSh.id());
  Machine.remove(playFadiSh.id());

  1 => isKilled;
}

fun void unKill() {
  1.0 => gainKickMaster.gain;
  1.0 => gainPots.gain;
  1.0 => gainFadi.gain;

  mout.send(144, 89, OFF);
  spork ~ playPots() @=> playPotsSh;
  spork ~ playKick() @=> playKickSh;
  spork ~ playFadi() @=> playFadiSh;
  toNode.start( "/kill" );
  0 => toNode.add;
  toNode.send();
  0 => isKilled;
}

Shred manualPotsSh;
Shred manualFadiSh;

fun void runPad() {
  int activeManualPad;
  while (true) {
    min => now;
    while (min.recv(msg)) {
        msg.data1 => int inputType; // pad number
        msg.data2 => int pad;
        msg.data3 => int velocity;
        if (pad == 89 && inputType == NOTE_ON) {
          if (isKilled == 0) {
            kill();
          } else {
            unKill();
          }
        } else if (isKilled) {
          continue;
        } else if (inputType == NOTE_ON && isManualPots && 56 <= pad && 64 > pad) {
          if (manualPotsSh.id()) {
            Machine.remove(manualPotsSh.id());
            mout.send(144, activeManualPad, OFF);
          }
          pad => activeManualPad;
          spork ~ playManualPots(pad) @=> manualPotsSh;
        } else if (inputType == NOTE_ON && isManualFadi && pad == 85) {
          if (manualFadiSh.id()) {
            Machine.remove(manualFadiSh.id());
            mout.send(144, 85, 0);
          }
          spork ~ playManualFadi();
        } else if (inputType == SLIDER) {
          if (pad == 56) {
            Math.pow(velocity / 127.0, 2) => gainPots.gain;
          } else if (pad == 49) {
            Math.pow(velocity / 127.0, 2) => gainKickMaster.gain;
          } else if (pad == 50) {
            (1.0 - (velocity / 127.0)) / 18.0 => gainKick.gain;
            velocity / 127.0 => gainKickBpf.gain;
          } else if (pad == 51) {
            70.0 + (Math.pow(velocity / 127.0, 2) * 1930.0) => bpfKick.freq;
          } else if (pad == 52) {
            Math.pow(velocity / 127.0, 2) => gainFadi.gain;
          } else if (pad == 53) {
            Math.pow(2, (velocity / 127.0 * 20.0 - 18.0) / 12.0) => shiftFadi2.shift;
          }
        } else if (32 <= pad && pad < 40 && inputType == NOTE_ON) {
          (padState[pad] + 1) % 3 => int nextState;
          nextState => padState[pad];
          if (nextState == 0) {
            mout.send(144, pad, OFF);
          } else if (nextState == 1) {
            mout.send(144, pad, RED);
          } else if (nextState == 2) {
            mout.send(144, pad, GREEN);
          }
        } else if (40 <= pad && pad < 64 && inputType == NOTE_ON) {
          if (40 <= pad && pad < 48) {
            0 => fadiOverrideStatus;
            mout.send(144, 0, OFF);
            mout.send(144, 7, OFF);
          } else if (48 <= pad && pad < 56) {
            0 => kickOverrideStatus;
            mout.send(144, 8, OFF);
            mout.send(144, 15, OFF);
          } else if (56 <= pad && pad < 64) {
            0 => potOverrideStatus;
            mout.send(144, 16, OFF);
            mout.send(144, 23, OFF);
          }

          if (!padState[pad]) {
            1 => padState[pad];
            mout.send(144, pad, RED);
          } else {
            0 => padState[pad];
            mout.send(144, pad, OFF);
          }
        } else if (pad == 82 && inputType == NOTE_ON) {
          if (isManualPots) {
            if (manualPotsSh.id()) Machine.remove(manualPotsSh.id());
            0 => isManualPots;
            mout.send(144, 82, OFF);
            for (56 => int i; i < 64; i++) {
              if (padState[i]) mout.send(144, i, RED);
            }
          } else {
            1 => isManualPots;
            mout.send(144, 82, GREEN);
            for (56 => int i; i < 64; i++) {
              mout.send(144, i, OFF);
            }
          }
        } else if (pad == 83 && inputType == NOTE_ON) {
          if (isDoubleKick) {
            0 => isDoubleKick;
            mout.send(144, 83, OFF);
          } else {
            1 => isDoubleKick;
            mout.send(144, 83, GREEN);
          }
        } else if (pad == 84 && inputType == NOTE_ON) {
          if (manualFadiSh.id()) Machine.remove(manualFadiSh.id());
          if (isManualFadi) {
            0 => isManualFadi;
            mout.send(144, 84, OFF);
            mout.send(144, 85, OFF);
            for (40 => int i; i < 48; i++) {
              if (padState[i]) mout.send(144, i, RED);
            }
          } else {
            1 => isManualFadi;
            mout.send(144, 84, GREEN);
            for (40 => int i; i < 48; i++) {
              mout.send(144, i, OFF);
            }
          }
        } else if (pad == 16 && inputType == NOTE_ON) {
          if (potOverrideStatus != 1) {
            mout.send(144, 16, GREEN);
            mout.send(144, 23, OFF);
            for (56 => int i; i < 64; i++) {
              if (potOverrideStatus == 0) padState[i] => padStateRaw[i];
              1 => padState[i];
              mout.send(144, i, RED);
            }
            1 => potOverrideStatus;
            0 => isManualPots;
            mout.send(144, 82, OFF);
          } else {
            0 => potOverrideStatus;
            mout.send(144, 16, OFF);
            for (56 => int i; i < 64; i++) {
              padStateRaw[i] => padState[i];
              if (padStateRaw[i]) {
                mout.send(144, i, RED);
              } else {
                mout.send(144, i, OFF);
              }
            }
          }
        } else if (pad == 23 && inputType == NOTE_ON) {
          if (potOverrideStatus != 2) {
            mout.send(144, 23, RED);
            mout.send(144, 16, OFF);
            for (56 => int i; i < 64; i++) {
              if (potOverrideStatus == 0) padState[i] => padStateRaw[i];
              0 => padState[i];
              mout.send(144, i, OFF);
            }
            2 => potOverrideStatus;

          } else {
            0 => potOverrideStatus;
            mout.send(144, 23, OFF);
            for (56 => int i; i < 64; i++) {
              padStateRaw[i] => padState[i];
              if (padStateRaw[i]) {
                mout.send(144, i, RED);
              } else {
                mout.send(144, i, OFF);
              }
            }
          }
        } else if (pad == 8 && inputType == NOTE_ON) {
          if (kickOverrideStatus != 1) {
            mout.send(144, 8, GREEN);
            mout.send(144, 15, OFF);
            for (48 => int i; i < 56; i++) {
              if (kickOverrideStatus == 0) padState[i] => padStateRaw[i];
              1 => padState[i];
              mout.send(144, i, RED);
            }
            1 => kickOverrideStatus;
          } else {
            0 => kickOverrideStatus;
            mout.send(144, 8, OFF);
            for (48 => int i; i < 56; i++) {
              padStateRaw[i] => padState[i];
              if (padStateRaw[i]) {
                mout.send(144, i, RED);
              } else {
                mout.send(144, i, OFF);
              }
            }
          }
        } else if (pad == 15 && inputType == NOTE_ON) {
          if (kickOverrideStatus != 2) {
            mout.send(144, 15, RED);
            mout.send(144, 8, OFF);
            for (48 => int i; i < 56; i++) {
              if (kickOverrideStatus == 0) padState[i] => padStateRaw[i];
              0 => padState[i];
              mout.send(144, i, OFF);
            }
            2 => kickOverrideStatus;

          } else {
            0 => kickOverrideStatus;
            mout.send(144, 15, OFF);
            for (48 => int i; i < 56; i++) {
              padStateRaw[i] => padState[i];
              if (padStateRaw[i]) {
                mout.send(144, i, RED);
              } else {
                mout.send(144, i, OFF);
              }
            }
          }
        } else if (pad == 0 && inputType == NOTE_ON) {
          if (fadiOverrideStatus != 1) {
            mout.send(144, 0, GREEN);
            mout.send(144, 7, OFF);
            for (40 => int i; i < 48; i++) {
              if (fadiOverrideStatus == 0) padState[i] => padStateRaw[i];
              1 => padState[i];
              mout.send(144, i, RED);
            }
            1 => fadiOverrideStatus;
          } else {
            0 => fadiOverrideStatus;
            mout.send(144, 0, OFF);
            for (40 => int i; i < 48; i++) {
              padStateRaw[i] => padState[i];
              if (padStateRaw[i]) {
                mout.send(144, i, RED);
              } else {
                mout.send(144, i, OFF);
              }
            }
          }
        } else if (pad == 7 && inputType == NOTE_ON) {
          if (fadiOverrideStatus != 2) {
            mout.send(144, 7, RED);
            mout.send(144, 0, OFF);
            for (40 => int i; i < 48; i++) {
              if (fadiOverrideStatus == 0) padState[i] => padStateRaw[i];
              0 => padState[i];
              mout.send(144, i, OFF);
            }
            2 => fadiOverrideStatus;

          } else {
            0 => fadiOverrideStatus;
            mout.send(144, 7, OFF);
            for (40 => int i; i < 48; i++) {
              padStateRaw[i] => padState[i];
              if (padStateRaw[i]) {
                mout.send(144, i, RED);
              } else {
                mout.send(144, i, OFF);
              }
            }
          }
        }
    }
  }
}

0 => int isManualPots;
-1 => int activePotId;
fun playPots() {
  spork ~ graphicPots();
  while (true) {
    0 => int hasPlayed;
    if (!isManualPots) {
      for (56 => int i; i < 64; i++) {
        if (isManualPots) {
          bufPots.pos(bufPots.samples());
        } else if (padState[i]) {
          if (gainPots.gain() > 0.01) i - 56 => activePotId;
          1 => hasPlayed;
          (i - 56.0) / 7.0 * 1.8 - 0.9 => panPots.pan;
          bufPots.pos(bufPots.samples() / 8 * (i - 56));
          eighth => now;
          -1 => activePotId;
        } else {
          bufPots.pos(bufPots.samples());
        }
      }
    }
    if (!hasPlayed) eighth => now;
  }
}

0 => int isDoubleKick;
fun playKick() {
  spork ~ graphicKick();
  while (true) {
    for (48 => int i; i < 56; i++) {
      if (padState[i]) {
        if (isDoubleKick) {
          bufKick[i - 48].pos(0);
          sixteenth => now;
          bufKick[i - 48 + 8].pos(0);
          sixteenth => now;
        } else {
          bufKick[i - 48].pos(0);
          eighth => now;
        }
      } else {
        // Always wait a full beat even if pad is off
        eighth => now;
      }
    }
  }
}

fun playFadiOnce() {
  1 => isFadiActive;
  6000 => bufFadi.pos;
  envFadi.keyOn();
  25::ms => now;
  envFadi.keyOff();
  100::ms => now;
  0 => isFadiActive;
}

0 => int isManualFadi;
0 => int isFadiActive;
fun playFadi() {
  spork ~ graphicFadi();
  while (true) {
    if (!isManualFadi) {
      for (40 => int i; i < 48; i++) {
        if (isManualFadi) {
          continue;
        } else if (padState[i]) {
          if (padState[i - 8] == 0) {
            playFadiOnce();
            eighth - 125::ms => now;
          } else if (padState[i - 8] == 1) {
            playFadiOnce();
            sixteenth - 125::ms => now;
            0.8 => shiftFadi1.shift;
            playFadiOnce();
            sixteenth - 125::ms => now;
            -2 => shiftFadi1.shift;
          } else if (padState[i - 8] == 2) {
            6000 => bufFadi.pos;
            envFadi.keyOn();
            25::ms => now;
            envFadi.keyOff();
            (eighth / 3) - 25::ms => now;

            0.8 => shiftFadi1.shift;
            6000 => bufFadi.pos;
            envFadi.keyOn();
            25::ms => now;
            envFadi.keyOff();
            (eighth / 3) - 25::ms => now;

            1.3 => shiftFadi1.shift;
            6000 => bufFadi.pos;
            envFadi.keyOn();
            25::ms => now;
            envFadi.keyOff();
            (eighth / 3) - 25::ms => now;
            -2 => shiftFadi1.shift;
          }
        } else {
          // Always wait a full beat even if pad is off
          eighth => now;
        }
      }
    } else {
      eighth => now;
    }
  }
}

spork ~ clearPadState();
spork ~ listenMode();
/* --------- Live visual code --------- */

// Function to shake the cube
fun void graphicKick() {
  while (true) {
    toNode.start( "/bassGain" );
    Math.fabs(gain_monitor_bass.last()) => float bassGain;

    if (bassGain < 0.3 * kickAdjustment) {
      0 => bassGain;
    }
    bassGain * 40 / kickAdjustment => toNode.add;
    toNode.send();
    10::ms => now;
  }
}

fun void graphicPots() {
  float intensity;
    // Shake loop
  while (true) {
    toNode.start( "/potGain" );
    Math.fabs(gain_monitor_pots.last()) => float potsGain;
    if (activePotId < 0) {
      0 => toNode.add; // should show square?
    } else {
      1 => toNode.add;
      activePotId => toNode.add;
      potsGain * 100 / potsAdjustment => toNode.add;
    }
    toNode.send();
    10::ms => now;
  }
}

fun void graphicFadi() {
  while (true) {
    toNode.start( "/hatGain" );
    Math.fabs(gain_monitor_fadi.last()) => float fadiGain;

    fadiGain * 110 / fadiAdjustment => toNode.add;
    toNode.send();
    10::ms => now;
  }
}

while (mode < 22) {
    100::ms => now;
}

me.exit();