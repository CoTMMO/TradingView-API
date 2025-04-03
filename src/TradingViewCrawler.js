const { fork } = require('child_process');
const path = require('path');
const os = require('os');
const fs = require('fs').promises;

class TradingViewCrawler {
  constructor(options = {}) {
    this.options = {
      maxWorkers: options.maxWorkers || Math.max(1, os.cpus().length - 1), // Leave one CPU core free
      timeout: options.timeout || 30000, // 30 seconds timeout
      retries: options.retries || 3,
      outputDir: options.outputDir || './data',
      token: options.token || '',
      signature: options.signature || '',
      throttleDelay: options.throttleDelay || 500, // Delay between worker spawns in ms
      maxMemoryUsage: options.maxMemoryUsage || 80, // Max memory usage percentage before throttling
      workerMemoryLimit: options.workerMemoryLimit || 300, // Memory limit per worker in MB
      ...options
    };
    
    this.workerPath = path.join(__dirname, 'CrawlerWorker.js');
    this.activeWorkers = new Map();
    this.taskQueue = [];
    this.running = false;
    this.results = new Map();
    this.errors = new Map();
    this.completionPromise = null;
    this.completionResolver = null;
    this.throttled = false;
    this.taskStats = {
      total: 0,
      completed: 0,
      failed: 0,
      retried: 0
    };
    
    // Setup process event handlers
    this._setupProcessHandlers();
  }

  /**
   * Set up process-wide event handlers
   * @private
   */
  _setupProcessHandlers() {
    // Handle graceful shutdown
    process.on('SIGTERM', () => this._handleShutdown('SIGTERM'));
    process.on('SIGINT', () => this._handleShutdown('SIGINT'));
    
    // Handle uncaught exceptions
    process.on('uncaughtException', (err) => {
      console.error('Uncaught exception in crawler:', err);
      this._handleShutdown('UNCAUGHT_EXCEPTION');
    });
  }

  /**
   * Handle shutdown signals
   * @param {string} signal The signal that triggered shutdown
   * @private
   */
  _handleShutdown(signal) {
    console.log(`Received ${signal} signal. Shutting down crawling gracefully...`);
    this.stop().then(() => {
      console.log('All crawler processes terminated successfully.');
      // Don't exit the process here, let the main application decide
    });
  }

  /**
   * Add symbols to the crawling queue
   * @param {Array<Object>} symbols Array of symbol objects to crawl
   * @param {string} symbols[].symbol The symbol to crawl (e.g., 'BINANCE:BTCEUR')
   * @param {string} symbols[].timeframe Timeframe to use (e.g., 'D', '1', '60')
   * @param {number} symbols[].range Number of candles to fetch
   * @param {Object} symbols[].options Additional options for the symbol
   */
  addSymbols(symbols) {
    if (!Array.isArray(symbols) || symbols.length === 0) {
      console.warn("Warning: No valid symbols provided to addSymbols method");
      return this;
    }
    
    // Validate and filter symbols
    const validSymbols = symbols.filter(s => {
      if (!s || typeof s !== 'object') {
        console.warn("Skipping invalid symbol entry:", s);
        return false;
      }
      if (!s.symbol) {
        console.warn("Skipping symbol without a symbol property:", s);
        return false;
      }
      return true;
    });
    
    console.log(`Adding ${validSymbols.length} symbols to crawl queue`);
    this.taskQueue.push(...validSymbols);
    this.taskStats.total += validSymbols.length;
    return this;
  }

  /**
   * Start the crawling process
   */
  async start() {
    if (this.running) return this;
    
    this.running = true;
    console.log(`Starting crawler with max ${this.options.maxWorkers} workers`);
    
    // Create output directory if it doesn't exist
    try {
      await fs.mkdir(this.options.outputDir, { recursive: true });
    } catch (error) {
      console.error('Error creating output directory:', error);
    }
    
    // Start resource monitoring
    this._startResourceMonitoring();
    
    // Start processing the queue
    this._processQueue();
    
    return this;
  }

  /**
   * Start monitoring system resources
   * @private
   */
  _startResourceMonitoring() {
    this.resourceMonitorInterval = setInterval(() => {
      try {
        const memoryUsage = process.memoryUsage();
        const usedMemoryMB = Math.round(memoryUsage.rss / 1024 / 1024);
        const totalMemoryMB = Math.round(os.totalmem() / 1024 / 1024);
        const memoryUsagePercent = Math.round((memoryUsage.rss / os.totalmem()) * 100);
        
        // Log memory usage every 10 seconds
        if (Date.now() % 10000 < 1000) {
          console.log(`Memory usage: ${usedMemoryMB}MB / ${totalMemoryMB}MB (${memoryUsagePercent}%)`);
          console.log(`Active workers: ${this.activeWorkers.size}, Queued tasks: ${this.taskQueue.length}`);
        }
        
        // Check if memory usage is too high
        if (memoryUsagePercent > this.options.maxMemoryUsage) {
          if (!this.throttled) {
            this.throttled = true;
            console.warn(`Memory usage too high (${memoryUsagePercent}%). Throttling worker creation.`);
          }
        } else if (this.throttled && memoryUsagePercent < this.options.maxMemoryUsage * 0.8) {
          // Resume normal operation if memory usage drops below 80% of max
          this.throttled = false;
          console.log(`Memory usage normalized (${memoryUsagePercent}%). Resuming normal operation.`);
          // Process queue to start workers if there are pending tasks
          this._processQueue();
        }
      } catch (err) {
        console.error('Error monitoring resources:', err);
      }
    }, 1000);
  }

  /**
   * Process the task queue
   * @private
   */
  _processQueue() {
    if (!this.running) return;
    
    // Define a function to spawn a single worker with throttling
    const spawnNextWorker = () => {
      if (!this.running || this.throttled) return;
      
      if (this.activeWorkers.size < this.options.maxWorkers && this.taskQueue.length > 0) {
        const task = this.taskQueue.shift();
        this._spawnWorker(task);
        
        // Throttle worker creation
        setTimeout(spawnNextWorker, this.options.throttleDelay);
      } else {
        this._checkCompletion();
      }
    };
    
    // Start spawning workers
    spawnNextWorker();
  }

  /**
   * Check if all tasks are completed and resolve completion promise if needed
   * @private
   */
  _checkCompletion() {
    if (this.taskQueue.length === 0 && this.activeWorkers.size === 0 && this.running) {
      console.log(`Crawling complete. Processed ${this.taskStats.completed} symbols successfully, ${this.taskStats.failed} failed.`);
      
      // Stop resource monitoring
      if (this.resourceMonitorInterval) {
        clearInterval(this.resourceMonitorInterval);
        this.resourceMonitorInterval = null;
      }
      
      // Set running to false when all tasks are done
      this.running = false;
      
      // Resolve completion promise if exists
      if (this.completionResolver) {
        this.completionResolver({
          results: this.getResults(),
          errors: Object.fromEntries(this.errors),
          stats: this.taskStats
        });
        this.completionResolver = null;
        this.completionPromise = null;
      }
    }
  }

  /**
   * Spawn a worker process for a symbol
   * @param {Object} task The task configuration
   * @private
   */
  _spawnWorker(task) {
    try {
      console.log(`Spawning worker for ${task.symbol} (timeframe: ${task.timeframe}, range: ${task.range})`);
      
      // Pass memory limit to worker
      const workerOptions = [
        `--max-old-space-size=${this.options.workerMemoryLimit}`
      ];
      
      const worker = fork(this.workerPath, workerOptions, {
        silent: false,
        detached: false,
        stdio: 'inherit',
        env: {
          ...process.env,
          NODE_OPTIONS: `--max-old-space-size=${this.options.workerMemoryLimit}`
        }
      });
      
      const id = task.symbol + '_' + Date.now();
      
      this.activeWorkers.set(id, { 
        worker, 
        task, 
        startTime: Date.now(),
        retries: task.retries || 0
      });
      
      worker.on('message', (message) => {
        try {
          if (message.type === 'result') {
            this.taskStats.completed++;
            this.results.set(task.symbol, message.data);
            this._saveResult(task.symbol, message.data);
          } else if (message.type === 'error') {
            console.error(`Error crawling ${task.symbol}:`, message.error);
            this.errors.set(task.symbol, message.error);
            
            // Retry logic
            if ((task.retries || 0) < this.options.retries) {
              this.taskStats.retried++;
              this.taskQueue.push({
                ...task,
                retries: (task.retries || 0) + 1
              });
            } else {
              this.taskStats.failed++;
            }
          } else if (message.type === 'log') {
            console.log(`[${task.symbol}]`, message.data);
          } else if (message.type === 'progress') {
            // Could handle progress updates here
          } else if (message.type === 'memory') {
            // Could track worker memory usage here for better resource management
          }
        } catch (err) {
          console.error('Error processing worker message:', err);
        }
      });
      
      worker.on('error', (err) => {
        console.error(`Worker error for ${task.symbol}:`, err);
        this.errors.set(task.symbol, err.message);
        this.activeWorkers.delete(id);
        
        // Continue processing the queue
        setTimeout(() => this._processQueue(), 100);
      });
      
      worker.on('exit', (code, signal) => {
        const workerInfo = this.activeWorkers.get(id);
        if (workerInfo) {
          const duration = Date.now() - workerInfo.startTime;
          if (code !== 0 && signal !== 'SIGTERM') {
            console.warn(`Worker for ${task.symbol} exited with code ${code} and signal ${signal} after ${duration}ms`);
            
            // If worker crashed and we haven't reached max retries, add back to queue
            if (code !== 0 && (task.retries || 0) < this.options.retries) {
              this.taskStats.retried++;
              this.taskQueue.push({
                ...task,
                retries: (task.retries || 0) + 1
              });
            } else if (code !== 0) {
              this.taskStats.failed++;
              this.errors.set(task.symbol, `Worker exited with code ${code}`);
            }
          } else {
            console.log(`Worker for ${task.symbol} completed in ${duration}ms`);
          }
        }
        
        this.activeWorkers.delete(id);
        
        // Continue processing the queue with a slight delay
        setTimeout(() => this._processQueue(), 100);
      });
      
      // Send the task to the worker
      worker.send({
        type: 'start',
        task: {
          ...task,
          token: this.options.token,
          signature: this.options.signature,
          timeout: this.options.timeout
        }
      }, (err) => {
        if (err) {
          console.error(`Failed to send message to worker for ${task.symbol}:`, err);
          worker.kill();
          this.activeWorkers.delete(id);
          
          // Continue processing the queue
          setTimeout(() => this._processQueue(), 100);
        }
      });
      
      // Set timeout to kill worker if it takes too long
      const timeoutId = setTimeout(() => {
        if (this.activeWorkers.has(id)) {
          console.warn(`Worker for ${task.symbol} timed out after ${this.options.timeout}ms`);
          try {
            worker.send({ type: 'timeout' }); // Give worker a chance to clean up
            
            // Force kill after 2 seconds if not exited
            setTimeout(() => {
              if (this.activeWorkers.has(id)) {
                worker.kill('SIGTERM');
              }
            }, 2000);
          } catch (err) {
            console.error(`Error killing worker for ${task.symbol}:`, err);
          }
          
          // Add back to queue with retry count
          if ((task.retries || 0) < this.options.retries) {
            this.taskStats.retried++;
            this.taskQueue.push({
              ...task,
              retries: (task.retries || 0) + 1
            });
          } else {
            this.taskStats.failed++;
            this.errors.set(task.symbol, 'Task timed out');
          }
        }
      }, this.options.timeout);
      
      // Store timeout ID with worker for cleanup
      this.activeWorkers.get(id).timeoutId = timeoutId;
      
    } catch (err) {
      console.error(`Failed to spawn worker for ${task.symbol}:`, err);
      this.errors.set(task.symbol, err.message);
      
      // Add back to queue with retry count
      if ((task.retries || 0) < this.options.retries) {
        this.taskStats.retried++;
        this.taskQueue.push({
          ...task,
          retries: (task.retries || 0) + 1
        });
      } else {
        this.taskStats.failed++;
      }
      
      // Continue processing the queue
      setTimeout(() => this._processQueue(), 100);
    }
  }

  /**
   * Save result to file
   * @param {string} symbol The symbol
   * @param {Object} data The data to save
   * @private
   */
  async _saveResult(symbol, data) {
    try {
      // Validate the data before saving
      if (!data || (Array.isArray(data) && data.length === 0)) {
        console.warn(`No valid data received for ${symbol}, skipping save`);
        return;
      }
      
      const safeSymbol = symbol.replace(/[:/]/g, '_');
      const filePath = path.join(this.options.outputDir, `${safeSymbol}.json`);
      await fs.writeFile(filePath, JSON.stringify(data, null, 2));
      console.log(`Successfully saved data for ${symbol} to ${filePath}`);
    } catch (error) {
      console.error(`Error saving data for ${symbol}:`, error);
    }
  }

  /**
   * Stop all crawling processes
   */
  async stop() {
    if (!this.running) return this;
    
    console.log('Stopping all crawler processes...');
    this.running = false;
    
    // Stop resource monitoring
    if (this.resourceMonitorInterval) {
      clearInterval(this.resourceMonitorInterval);
      this.resourceMonitorInterval = null;
    }
    
    // Create a promise for each worker to terminate
    const terminationPromises = [];
    
    for (const [id, { worker, timeoutId, task }] of this.activeWorkers.entries()) {
      try {
        // Clear any pending timeout
        if (timeoutId) {
          clearTimeout(timeoutId);
        }
        
        // Send termination signal to worker
        worker.send({ type: 'terminate' });
        
        // Create a promise that resolves when worker exits
        const terminationPromise = new Promise((resolve) => {
          // Set a timeout to force kill worker if it doesn't exit gracefully
          const forceKillTimeout = setTimeout(() => {
            try {
              if (worker.connected) {
                console.warn(`Force killing worker for ${task.symbol} after grace period`);
                worker.kill('SIGKILL');
              }
            } catch (err) {
              console.error(`Error force-killing worker for ${task.symbol}:`, err);
            }
          }, 5000);
          
          // Listen for exit event
          worker.once('exit', () => {
            clearTimeout(forceKillTimeout);
            resolve();
          });
        });
        
        terminationPromises.push(terminationPromise);
      } catch (err) {
        console.error(`Error stopping worker for ${id}:`, err);
      }
    }
    
    // Wait for all workers to terminate
    if (terminationPromises.length > 0) {
      await Promise.all(terminationPromises);
    }
    
    this.activeWorkers.clear();
    
    // If we have a pending completion promise, resolve it
    if (this.completionResolver) {
      this.completionResolver({
        results: this.getResults(),
        errors: Object.fromEntries(this.errors),
        stats: this.taskStats
      });
      this.completionResolver = null;
      this.completionPromise = null;
    }
    
    return this;
  }

  /**
   * Get all collected results
   */
  getResults() {
    return Object.fromEntries(this.results);
  }

  /**
   * Get errors that occurred during crawling
   */
  getErrors() {
    return Object.fromEntries(this.errors);
  }

  /**
   * Get the current status of the crawler
   */
  getStatus() {
    const status = {
      running: this.running,
      activeWorkers: this.activeWorkers.size,
      queuedTasks: this.taskQueue.length,
      completedSymbols: this.results.size,
      failedSymbols: this.errors.size,
      throttled: this.throttled,
      stats: { ...this.taskStats }
    };
    
    // Add memory usage information
    try {
      const memoryUsage = process.memoryUsage();
      status.memory = {
        rss: Math.round(memoryUsage.rss / 1024 / 1024) + 'MB',
        heapTotal: Math.round(memoryUsage.heapTotal / 1024 / 1024) + 'MB',
        heapUsed: Math.round(memoryUsage.heapUsed / 1024 / 1024) + 'MB',
        external: Math.round(memoryUsage.external / 1024 / 1024) + 'MB',
        percentage: Math.round((memoryUsage.rss / os.totalmem()) * 100) + '%'
      };
    } catch (err) {
      status.memory = { error: err.message };
    }
    
    // Add diagnostic information if no results
    if (this.results.size === 0 && this.taskQueue.length === 0 && this.activeWorkers.size === 0) {
      status.message = "No results collected. Check worker logs for possible errors.";
    }
    
    return status;
  }

  /**
   * Returns a promise that resolves when all tasks are completed
   * @returns {Promise} A promise that resolves when all tasks are completed
   */
  waitForCompletion() {
    if (this.taskQueue.length === 0 && this.activeWorkers.size === 0) {
      return Promise.resolve({
        results: this.getResults(),
        errors: Object.fromEntries(this.errors),
        stats: this.taskStats
      });
    }
    
    if (!this.completionPromise) {
      this.completionPromise = new Promise(resolve => {
        this.completionResolver = resolve;
      });
    }
    
    return this.completionPromise;
  }

  /**
   * Clean up resources before exiting
   */
  async cleanup() {
    await this.stop();
    return this;
  }
}

module.exports = TradingViewCrawler;
