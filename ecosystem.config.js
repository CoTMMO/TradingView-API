module.exports = {
  apps: [
    {
      name: "tradingview-crawler",
      script: "./examples/CrawlerExample.js", // Main entry point
      instances: 1,
      exec_mode: "fork",
      watch: false,
      autorestart: true,
      max_memory_restart: "1G",
      env: {
        NODE_ENV: "development",
        MAX_WORKERS: 4,
        TIMEOUT: 60000,
        RETRIES: 3,
        OUTPUT_DIR: "./data/development"
      },
      env_production: {
        NODE_ENV: "production",
        MAX_WORKERS: 8,
        TIMEOUT: 120000,
        RETRIES: 5,
        OUTPUT_DIR: "./data/production",
        SESSION: "", // Add your TradingView session token for production
        SIGNATURE: "" // Add your TradingView signature for production
      },
      // Disable metrics that require wmic
      disable_metrics: true,
      // Use a different monitoring system that doesn't rely on wmic
      listen_timeout: 5000,
      kill_timeout: 3000,
      restart_delay: 3000
    }
  ]
};
