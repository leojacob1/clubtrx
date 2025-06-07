// 🎛 Unified p5.js Sketch: Combines animated bass/hat/clap shapes with background static texture

let bassGain = 0;
let hatGain = 0;
let clapGain = 0;
let bongoEnvIsRunning = false;
let bongoEnvelopeTime = 0;
let bongoAttackMs = 0.0;
let bongoDecayReleaseMs = 0.0;
let bassBaseX, bassBaseY;
let hatBaseX, hatBaseY;
let clapBaseX, clapBaseY;
let bassCircleColor;
let hatTriangleColor;
let clapRectangleColor;
let globalAlpha = 255;

let flashes = [];
let buffer;
let bigRadius = 80;

let staticSquares = [];
let cols, rows;
let staticSize = 6;
let staticFlashRate = 10;
let frameCounter = 0;
let staticColors;

function setup() {
  createCanvas(windowWidth, windowHeight);
  rectMode(CENTER);
  noStroke();

  // Initialize positions
  bassBaseX = width / 2;
  bassBaseY = height / 2;
  hatBaseX = width / 3;
  hatBaseY = height / 3 * 2;
  clapBaseX = width / 3 * 2;
  clapBaseY = height / 5;

  // Random colors
  bassCircleColor = color(random(255), random(255), random(255));
  hatTriangleColor = color(random(255), random(255), random(255));
  clapRectangleColor = color(random(255), random(255), random(255));

  buffer = createGraphics(width, height);

  // Static palette
  staticColors = [
    color(241, 9, 210),
    color(100, 90, 99),
    color(127, 85, 107),
    color(82, 96, 81),
    color(199, 133, 209),
    color(138, 196, 155),
    color(239, 236, 243),
    color(16, 228, 208),
    color(254, 240, 49)
  ];

  cols = ceil(width / staticSize);
  rows = ceil(height / staticSize);
  staticSquares = new Array(cols * rows).fill(null);

  let socket = new WebSocket("ws://localhost:8081");
  socket.onmessage = function (event) {
    let msg = JSON.parse(event.data);
    if (msg.address === "/bassGain") bassGain = msg.args[0];
    else if (msg.address === "/hatGain") hatGain = msg.args[0];
    else if (msg.address === "/clapGain") clapGain = msg.args[0];
    else if (msg.address === "/bongo") flashes.push(new Flash());
    else if (msg.address === "/bongoEnvParams") {
      bongoAttackMs = msg.args[0];
      bongoDecayReleaseMs = msg.args[1];
    } else if (msg.address === "/bongoEnvOn") {
      let isOn = msg.args[0];
      bongoEnvIsRunning = isOn === 1;
      bongoEnvelopeTime = 0;
      globalAlpha = isOn ? 0 : 255;
    }
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
      if (
        noiseFactor >
        map(sin(distFromCenter * 0.15), -1, 1, 0.6, random() * 0.5 + 0.5) -
          0.3 * (((i + 60) % (cols / 3 + 0.1)) / (cols / 3))
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
  let h = 100;
  let s = (2 / Math.sqrt(3)) * h;
  triangle(
    hatNewX, hatNewY - h / 2,
    hatNewX - s / 2, hatNewY + h / 2,
    hatNewX + s / 2, hatNewY + h / 2
  );

  // ======= CLAP (RECTANGLE) =======
  let clapOffsetX = random(-clapGain, clapGain);
  let clapOffsetY = random(-clapGain, clapGain);
  let clapNewX = constrain(clapBaseX + clapOffsetX, 50, width - 50);
  let clapNewY = constrain(clapBaseY + clapOffsetY, 50, height - 50);
  clapBaseX = (clapNewX + clapBaseX) / 2;
  clapBaseY = (clapNewY + clapBaseY) / 2;
  fill(clapRectangleColor);
  rect(clapNewX, clapNewY, 100, 100);

  // ======= FLASHES (BONGO) =======
  buffer.clear();
  for (let i = flashes.length - 1; i >= 0; i--) {
    flashes[i].update();
    flashes[i].draw(buffer);
    if (flashes[i].isDone()) flashes.splice(i, 1);
  }

  if (bongoEnvIsRunning) {
    let attackFrames = bongoAttackMs / 1000 * 60;
    let decayFrames = bongoDecayReleaseMs / 1000 * 60;
    let totalFrames = attackFrames + decayFrames;
    if (bongoEnvelopeTime <= attackFrames) {
      globalAlpha = map(bongoEnvelopeTime, 0, attackFrames, 0, 255);
    } else if (bongoEnvelopeTime <= totalFrames) {
      globalAlpha = map(bongoEnvelopeTime, attackFrames, totalFrames, 255, 0);
    } else {
      globalAlpha = 0;
      bongoEnvIsRunning = false;
    }
    bongoEnvelopeTime++;
  }

  image(buffer, 0, 0);
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
    pg.fill(255, 255, 0, globalAlpha);
    pg.noStroke();
    pg.ellipse(this.x, this.y, this.size);
  }

  isDone() {
    let totalFrames = (bongoAttackMs + bongoDecayReleaseMs) / 1000 * 60;
    return this.timeAlive > totalFrames;
  }
}

function windowResized() {
  resizeCanvas(windowWidth, windowHeight);
  cols = ceil(width / staticSize);
  rows = ceil(height / staticSize);
  staticSquares = new Array(cols * rows).fill(null);
}
