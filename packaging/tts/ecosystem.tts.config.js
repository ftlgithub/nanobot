module.exports = {
  apps: [
    {
      // Bundle-relative: PM2 resolves paths from this file's directory.
      // Install: copy the extracted bundle anywhere, then
      //   pm2 start ecosystem.tts.config.js
      name: process.env.TTS_NAME || "nanobot-tts",
      cwd: __dirname + "/service",
      script: "../python/bin/python",
      args: "-m uvicorn main:app --host 127.0.0.1 --port 8081",
      interpreter: "none",
      env: {
        // Offline: model lives in the bundle; never hit the network.
        HF_HOME: __dirname + "/models",
        HF_HUB_OFFLINE: "1",
        TRANSFORMERS_OFFLINE: "1",
        NO_PROXY: "*",
      },
      autorestart: true,
      max_restarts: 10,
      min_uptime: "10s",
    },
  ],
};
