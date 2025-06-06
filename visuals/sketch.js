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
let bigRadius;

function setup() {
  createCanvas(windowWidth, windowHeight);
  rectMode(CENTER);
  bassBaseX = width / 2;
  bassBaseY = height / 2;
  hatBaseX = width / 3;
  hatBaseY = height / 3 * 2;
  clapBaseX = width / 3 * 2;
  clapBaseY = width / 5;
  bassCircleColor = color(random(0, 255), random(0, 255), random(0, 255));
  hatTriangleColor = color(random(0, 255), random(0, 255), random(0, 255));
  clapRectangleColor = color(random(0, 255), random(0, 255), random(0, 255));
  bigRadius = 80;
  buffer = createGraphics(width, height);

  let socket = new WebSocket("ws://localhost:8081");
  socket.onmessage = function (event) {
    let msg = JSON.parse(event.data);
    if (msg.address === "/bassGain") {
      bassGain = msg.args[0];
    } else if (msg.address === "/hatGain") {
      hatGain = msg.args[0];
    } else if (msg.address === "/clapGain") {
      clapGain = msg.args[0];
    } else if (msg.address === "/bongo") { 
        flashes.push(new Flash());
    } else if (msg.address === "/bongoEnvParams") {
      bongoAttackMs = msg.args[0];
      bongoDecayReleaseMs = msg.args[1];
    } else if (msg.address === "/bongoEnvOn") {
      let isOn = msg.args[0];
      isBongoEnvOn = isOn;

      if (isOn === 1) {
        bongoEnvIsRunning = true;
        bongoEnvelopeTime = 0; // start fresh
      } else {
        bongoEnvIsRUnning = false;
        bongoEnvelopeTime = 0;
        globalAlpha = 255;
      }
    }
  };
}

function draw() {
  background(0);

  // Shake ellipse based on bassGain
  let bassOffsetX = random(-bassGain, bassGain);
  let bassOffsetY = random(-bassGain, bassGain);

  let bassNewX = constrain(bassBaseX + bassOffsetX, 50, width - 50);
  let bassNewY = constrain(bassBaseY + bassOffsetY, 50, height - 50);

  bassBaseX = (bassNewX + bassBaseX) / 2;
  bassBaseY = (bassNewY + bassBaseY) / 2;

  fill(bassCircleColor);
  noStroke();
  ellipse(bassNewX, bassNewY, 120, 120);

  // ****** hi hat *******
  let hatOffsetX = random(-hatGain, hatGain);
  let hatOffsetY = random(-hatGain, hatGain);

  let hatNewX = constrain(hatBaseX + hatOffsetX, 50, width - 50);
  let hatNewY = constrain(hatBaseY + hatOffsetY, 50, height - 50);

  hatBaseX = (hatNewX + hatBaseX) / 2;
  hatBaseY = (hatNewY + hatBaseY) / 2;

  fill(hatTriangleColor);
  noStroke();
  let cx = hatNewX;
  let cy = hatNewY;
  let h = 100;
  let s = (2 / Math.sqrt(3)) * h;

  triangle(
    cx, cy - h / 2,             // top
    cx - s / 2, cy + h / 2,     // bottom left
    cx + s / 2, cy + h / 2      // bottom right
  );

  // ******* clap *********

  // ****** hi hat *******
  let clapOffsetX = random(-clapGain, clapGain);
  let clapOffsetY = random(-clapGain, clapGain);

  let clapNewX = constrain(clapBaseX + clapOffsetX, 50, width - 50);
  let clapNewY = constrain(clapBaseY + clapOffsetY, 50, height - 50);

  clapBaseX = (clapNewX + clapBaseX) / 2;
  clapBaseY = (clapNewY + clapBaseY) / 2;

  fill(clapRectangleColor);
  rect(clapNewX, clapNewY, 100, 100);

  // Clear and draw flashes to buffer
  buffer.clear();

  for (let i = flashes.length - 1; i >= 0; i--) {
    flashes[i].update();
    flashes[i].draw(buffer);

    if (flashes[i].isDone()) {
      flashes.splice(i, 1);
    }
  }

  if (bongoEnvIsRunning) {
    let attackFrames = bongoAttackMs / 1000 * 60;
    let decayFrames = bongoDecayReleaseMs / 1000 * 60;
    let totalFrames = attackFrames + decayFrames;

    if (bongoEnvelopeTime <= attackFrames * 2) {
      globalAlpha = map(bongoEnvelopeTime, 0, attackFrames, 0, 255);
    } else if (bongoEnvelopeTime <= totalFrames) {
      globalAlpha = map(bongoEnvelopeTime, attackFrames, totalFrames, 255, 0);
    } else {
      globalAlpha = 0;
      bongoEnvIsRunning = false;
    }

    bongoEnvelopeTime++;
  }

  // Draw flash buffer to screen
  image(buffer, 0, 0);
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
    if (!this.shouldAnimate) return this.timeAlive > 10; // quick full-bright flash
    let totalFrames = (bongoAttackMs + bongoDecayReleaseMs) / 1000 * 60;
    return this.timeAlive > totalFrames;
  }
}



function windowResized() {
  resizeCanvas(windowWidth, windowHeight);
}
