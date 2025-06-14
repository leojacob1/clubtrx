// 🎛 Unified p5.js Sketch: Combines animated bass/hat/clap shapes with background static texture
let mode = 0;
let bassGain = 0;
let hatGain = 0;
let clapGain = 0;
let potGain = 0;
let isPotsOn = 0;
let activePotId = -1;
let bassBaseX, bassBaseY;
let hatBaseX, hatBaseY;
let squareBaseX, squareBaseY;
let bassCircleColor;
let hatTriangleColor;
let clapRectangleColor;
let staticAlpha = 0;

let textHeight = 0;

let grainGain;
let grainPos;
let grainLength;

let bigRadius = 130;

let staticSquares = [];
let cols, rows;
let staticSize = 8;
let staticFlashRate = 3;
let frameCounter = 0;
let staticColor;

function setup() {
  frameRate(24);
  background(0);
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
  bassCircleColor = color(140, 21, 21);
  hatTriangleColor = color(0, 103, 58);
  clapRectangleColor = color(237, 170, 55);

  // Static palette
  staticColor = color(239, 236, 243);

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
        isPotsOn = 0;
      } else if (msg.args[0] == 2) {
        potGain = 0;
        hatGain = 0;
        clapGain = 0;
        bassGain = 0;
        isPotsOn = 0;
        activePotId = -1;
        // Hide shapes by setting a flag
        window.hideShapes = true;
      }
    } else if (msg.address === "/intro") {
      textHeight = msg.args[0];
    }
  };
}

function draw() {
  background(0)
  // ======= STATIC BACKGROUND =======
  if (frameCounter % staticFlashRate === 0 && mode >= 77) {
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
        let c = staticColor;
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
        staticSquares[i].setAlpha(random() * staticAlpha + (staticAlpha / 2));
        fill(staticSquares[i]);
        rect(x * staticSize, y * staticSize, staticSize, staticSize);
      }
    }
  }

  // ======= Title text =======
  if (mode == 0 || mode == 22) {
    textFont('Times New Roman');
    textSize(256);
    fill(255);
    textAlign(CENTER, CENTER);
    text(`Act ${mode === 0 ? 'I' : 'II'}`, width / 2, (1 - textHeight) * height + 250);
  }

  // Hide all shapes if /kill 2 was received
  if (window.hideShapes) {
    frameCounter++;
    return;
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
  if (mode == 11) {
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
  } else if (mode >= 33) {
    let clapOffsetX = random(-clapGain, clapGain);
    let clapOffsetY = random(-clapGain, clapGain);
    let clapNewX = constrain(squareBaseX + clapOffsetX, 50, width - 50);
    let clapNewY = constrain(squareBaseY + clapOffsetY, 50, height - 50);
    squareBaseX = (clapNewX + squareBaseX) / 2;
    squareBaseY = (clapNewY + squareBaseY) / 2;
    fill(clapRectangleColor);
    rect(clapNewX, clapNewY, 120, 120);
  }

  frameCounter++;
}