// 🎛 Unified p5.js Sketch: Combines animated bass/hat/clap shapes with background static texture
let mode = -1;
let bassGain = 0;
let hatGain = 0;
let clapGain = 0;
let potGain = 0;
let isPotsOn = 0;
let activePotId = -1;
let bongoEnvIsRunning = false;
let bongoEnvelopeTime = 0;
let bongoAttackMs = 0.0;
let bongoDecayReleaseMs = 0.0;
let bassBaseX, bassBaseY;
let hatBaseX, hatBaseY;
let squareBaseX, squareBaseY;
let bassCircleColor;
let hatTriangleColor;
let clapRectangleColor;
let bongoAlpha = 255;
let staticAlpha = 0;

let grainGain;
let grainPos;
let grainLength;

let flashes = [];
let buffer;
let bigRadius = 130;

let staticSquares = [];
let cols, rows;
let staticSize = 8;
let staticFlashRate = 3;
let frameCounter = 0;
let staticColors;

function setup() {
  frameRate(24);
  createCanvas(windowWidth, windowHeight);
  rectMode(CENTER);
  noStroke();

  // Initialize positions
  bassBaseX = width / 2;
  bassBaseY = height / 2;
  hatBaseX = 3 * width / 5;
  hatBaseY = height / 3.5;
  squareBaseX = width / 8;
  squareBaseY = height / 3;

  grainGain = 0;
  grainPos = 0;
  grainLength = 0;

  // Random colors
  bassCircleColor = color(random(255), random(255), random(255));
  hatTriangleColor = color(random(255), random(255), random(255));
  clapRectangleColor = color(random(255), random(255), random(255));

  buffer = createGraphics(width, height);

  // Static palette
  staticColors = [
    // color(241, 9, 210),
    // color(100, 90, 99),
    // color(127, 85, 107),
    // color(82, 96, 81),
    // color(199, 133, 209),
    // color(138, 196, 155),
    color(239, 236, 243),
    // color(16, 228, 208),
    // color(254, 240, 49)
  ];

  cols = ceil(width / staticSize);
  rows = ceil(height / staticSize);
  staticSquares = new Array(cols * rows).fill(null);

  let socket = new WebSocket("ws://localhost:8081");
  socket.onmessage = function (event) {
    let msg = JSON.parse(event.data);
    if (msg.address === "/mode") mode = msg.args[0]
    else if (msg.address === "/bassGain") bassGain = msg.args[0];
    else if (msg.address === "/hatGain") hatGain = msg.args[0];
    else if (msg.address === "/clapGain") clapGain = msg.args[0];
    else if (msg.address === "/potGain") {
      isPotsOn = msg.args[0];
      if (isPotsOn) {
        activePotId = msg.args[1];
        potGain = msg.args[2]
      }
    } else if (msg.address === "/granular") {
      grainGain = msg.args[0];
      grainPos = msg.args[1];
      grainLength = msg.args[2];
      if (grainPos > 0.07) {
        staticAlpha = map(grainPos, 0.07, 0.2, 50, grainGain > 0.05 ? 30 : 0)
      } else {
        staticAlpha = map(grainPos, 0.01, 0.07, 255, 50)
      }
    } else if (msg.address === "/kill" ) {
      if (msg.args[0] == 1) {
        potGain = 0;
        hatGain = 0;
        clapGain = 0;
        bassGain = 0;
        isPotsOn = 1;
      }
    }
        // else if (msg.address === "/bongo") flashes.push(new Flash());
    // else if (msg.address === "/bongoEnvParams") {
    //   bongoAttackMs = msg.args[0];
    //   bongoDecayReleaseMs = msg.args[1];
    // } else if (msg.address === "/bongoEnvOn") {
    //   let isOn = msg.args[0];
    //   bongoEnvIsRunning = isOn === 1;
    //   bongoEnvelopeTime = 0;
    //   bongoAlpha = isOn ? 0 : 255;
    // } 
  };
}

function draw() {
  background(0);

  // ======= STATIC BACKGROUND =======
  if (frameCounter % staticFlashRate === 0) {
    for (let i = 0; i < staticSquares.length; i++) {
      let x = i % cols;
      let y = floor(i / cols);
      let distFromCenter = dist(x, y, cols / 2, rows / 2);
      let noiseFactor = noise(x * 0.1, y * 0.1, frameCounter * 0.05);
      let staticLineSpeed = 0;
      let staticLineIntensity = 0;
      if (grainLength < 20) {
        staticLineSpeed = map(grainLength, 0, 20, 3.0, 0.0);
        staticLineIntensity = map(grainLength, 0, 20, 0.5, 0.35)
      } else if (grainLength < 50) {
        staticLineIntensity = map(grainLength, 20, 50, 0.35, 0.2)
      } else if (grainLength < 100) {
        staticLineIntensity = map(grainLength, 50, 100, 0.2, 0.0)
      }

      if (
        noiseFactor >
        map(sin(distFromCenter * 0.15), -1, 1, 0.8, random() * 0.4 + map(grainGain, 0, 1, 0.9, 0.3)) -
          staticLineIntensity * (((i + staticLineSpeed * frameCounter % (cols / 3)) % (cols / 3 + 0.1)) / (cols / 3))
      ) {
        let c = random(staticColors);
        c.setAlpha(random(120, 200));
        staticSquares[i] = c;
      } else {
        staticSquares[i] = null;
      }
    }
  }

  for (let y = 0; y < rows; y++) {
    for (let x = 0; x < cols; x++) {
      let i = y * cols + x;
      if (staticSquares[i]) {
        staticSquares[i].setAlpha(staticAlpha);
        fill(staticSquares[i]);
        rect(x * staticSize, y * staticSize, staticSize, staticSize);
      }
    }
  }

  // ======= BASS (CIRCLE) =======
  let bassOffsetX = random(-bassGain, bassGain);
  let bassOffsetY = random(-bassGain, bassGain);
  let bassNewX = constrain(bassBaseX + bassOffsetX, 50, width - 50);
  let bassNewY = constrain(bassBaseY + bassOffsetY, 50, height - 50);
  bassBaseX = (bassNewX + bassBaseX) / 2;
  bassBaseY = (bassNewY + bassBaseY) / 2;
  fill(bassCircleColor);
  ellipse(bassNewX, bassNewY, 120, 120);

  // ======= HAT (TRIANGLE) =======
  let hatOffsetX = random(-hatGain, hatGain);
  let hatOffsetY = random(-hatGain, hatGain);
  let hatNewX = constrain(hatBaseX + hatOffsetX, 50, width - 50);
  let hatNewY = constrain(hatBaseY + hatOffsetY, 50, height - 50);
  hatBaseX = (hatNewX + hatBaseX) / 2;
  hatBaseY = (hatNewY + hatBaseY) / 2;
  fill(hatTriangleColor);
  let h = 120;
  let s = (2 / Math.sqrt(3)) * h;
  triangle(
    hatNewX, hatNewY - h / 2,
    hatNewX - s / 2, hatNewY + h / 2,
    hatNewX + s / 2, hatNewY + h / 2
  );

  // ======= CLAP or POTS (RECTANGLE) =======
  if (mode == -1) {
    if (isPotsOn) {
      squareBaseX = activePotId * width / 9 + width / 9;
      squareBaseY = 3 * height / 4;
      let potOffsetX = random(-potGain, potGain);
      let potOffsetY = random(-potGain, potGain);
      let potNewX = squareBaseX + potOffsetX;
      let potNewY = squareBaseY + potOffsetY;

      fill(clapRectangleColor);
      rect(potNewX, potNewY, 120, 120);
    }
  } else {
    let clapOffsetX = random(-clapGain, clapGain);
    let clapOffsetY = random(-clapGain, clapGain);
    let clapNewX = constrain(squareBaseX + clapOffsetX, 50, width - 50);
    let clapNewY = constrain(squareBaseY + clapOffsetY, 50, height - 50);
    squareBaseX = (clapNewX + squareBaseX) / 2;
    squareBaseY = (clapNewY + squareBaseY) / 2;
    fill(clapRectangleColor);
    rect(clapNewX, clapNewY, 120, 120);
  }


  // ======= FLASHES (BONGO) =======
  buffer.clear();
  // for (let i = flashes.length - 1; i >= 0; i--) {
  //   flashes[i].update();
  //   flashes[i].draw(buffer);
  //   if (flashes[i].isDone()) flashes.splice(i, 1);
  // }

  // if (bongoEnvIsRunning) {
  //   let attackFrames = bongoAttackMs / 1000 * 60;
  //   let decayFrames = bongoDecayReleaseMs / 1000 * 60;
  //   let totalFrames = attackFrames + decayFrames;
  //   if (bongoEnvelopeTime <= attackFrames) {
  //     bongoAlpha = map(bongoEnvelopeTime, 0, attackFrames, 0, 255);
  //   } else if (bongoEnvelopeTime <= totalFrames) {
  //     bongoAlpha = map(bongoEnvelopeTime, attackFrames, totalFrames, 255, 0);
  //   } else {
  //     bongoAlpha = 0;
  //     bongoEnvIsRunning = false;
  //   }
  //   bongoEnvelopeTime++;
  // }

  // image(buffer, 0, 0);
  frameCounter++;
}

class Flash {
  constructor() {
    this.size = 50;
    let angle = random(TWO_PI);
    let r = sqrt(random()) * (bigRadius - this.size / 2);
    this.x = width / 3 * 2 + cos(angle) * r;
    this.y = height / 3 * 2 + sin(angle) * r;
    this.timeAlive = 0;
  }

  update() {
    this.timeAlive++;
  }

  draw(pg) {
    pg.fill(255, 255, 0, bongoAlpha);
    pg.noStroke();
    pg.ellipse(this.x, this.y, this.size);
  }

  isDone() {
    if (bongoEnvIsRunning) {
      let totalFrames = (bongoAttackMs + bongoDecayReleaseMs) / 1000 * 60;
      return this.timeAlive > totalFrames;
    } else {
      return this.timeAlive > 5;
    }
  }
}

function windowResized() {
  resizeCanvas(windowWidth, windowHeight);
  cols = ceil(width / staticSize);
  rows = ceil(height / staticSize);
  staticSquares = new Array(cols * rows).fill(null);
}
