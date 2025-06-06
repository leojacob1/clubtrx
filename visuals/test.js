let staticSquares = [];
let cols, rows;
let staticSize = 6;         // size of each square
let staticFlashRate = 3;     // how often static refreshes (in frames)
let staticColor;
let frameCounter = 0;

function setup() {
  createCanvas(windowWidth, windowHeight);
  noStroke();

  // Color of static (white with some transparency)
  staticColor = color(255, 255, 255, 100);

  // Grid dimensions
  cols = ceil(width / staticSize);
  rows = ceil(height / staticSize);

  // Initialize square activity states
  for (let i = 0; i < cols * rows; i++) {
    staticSquares[i] = false;
  }
}

function draw() {
  background(0); // base background

  // Update static every few frames
  if (frameCounter % staticFlashRate === 0) {
    for (let i = 0; i < staticSquares.length; i++) {
      staticSquares[i] = random() > (0.6 - (
        0.2 * (
          (rows / 3) / (i % cols)
        )
      ));
    }
  }

  fill(staticColor);
  for (let y = 0; y < rows; y++) {
    for (let x = 0; x < cols; x++) {
      if (staticSquares[y * cols + x]) {
        rect(x * staticSize, y * staticSize, staticSize, staticSize);
      }
    }
  }

  frameCounter++;
}

function windowResized() {
  resizeCanvas(windowWidth, windowHeight);

  // Recalculate grid size on resize
  cols = ceil(width / staticSize);
  rows = ceil(height / staticSize);
  staticSquares = new Array(cols * rows).fill(false);
}
