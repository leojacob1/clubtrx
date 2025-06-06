// server.js
const osc = require("osc");
const WebSocket = require("ws");

// WebSocket server for browser
const wss = new WebSocket.Server({ port: 8081 });

// UDP Port for OSC messages (e.g. from ChucK)
const udpPort = new osc.UDPPort({
  localAddress: "127.0.0.1",
  localPort: 7777
});

udpPort.open();

udpPort.on("message", function (oscMsg) {
  console.log("OSC ->", oscMsg);
  wss.clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(JSON.stringify(oscMsg));
    }
  });
});
