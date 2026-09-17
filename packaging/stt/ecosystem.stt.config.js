module.exports = {
  apps: [
    {
      // Set BUNDLE_DIR to the extracted platform dir, e.g.
      //   BUNDLE_DIR=/opt/nanobot-stt/macos-arm64 pm2 start ecosystem.stt.config.js
      // or: BUNDLE_DIR=/opt/nanobot-stt/linux-x64 pm2 start ecosystem.stt.config.js
      name: process.env.STT_NAME || "whisper-server",
      script: `${process.env.BUNDLE_DIR}/start-whisper.sh`,
      args: [
        `${process.env.STT_MODEL || `${process.env.BUNDLE_DIR}/../ggml-medium.bin`}`,
        process.env.STT_PORT || "9090",
        process.env.STT_HOST || "127.0.0.1",
      ],
      interpreter: "bash",
      autorestart: true,
      max_restarts: 10,
      min_uptime: "10s",
      out_file: `${process.env.LOG_DIR || "."}/whisper-server-out.log`,
      error_file: `${process.env.LOG_DIR || "."}/whisper-server-err.log`,
    },
  ],
};
