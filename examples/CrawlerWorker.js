const TradingView = require('../main');

// Global variables for resource tracking
let activeClient = null;
let activeChart = null;
let activeTimeout = null;
let isExiting = false;

// Proper error handling for unhandled rejections
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  cleanupAndExit(1);
});

// Worker process to handle individual symbol crawling
process.on('message', async (message) => {
  if (message.type === 'start') {
    try {
      await crawlSymbol(message.task);
    } catch (error) {
      process.send({
        type: 'error',
        error: error.message || 'Unknown error occurred'
      });
      cleanupAndExit(1);
    }
  }
});

// Handle termination signals
process.on('SIGTERM', () => {
  process.send({ type: 'log', data: 'Worker received SIGTERM signal' });
  cleanupAndExit(0);
});

process.on('SIGINT', () => {
  process.send({ type: 'log', data: 'Worker received SIGINT signal' });
  cleanupAndExit(0);
});

/**
 * Clean up resources and exit process
 * @param {number} code Exit code
 */
function cleanupAndExit(code) {
  if (isExiting) return; // Prevent multiple cleanup attempts
  isExiting = true;
  
  try {
    // Clear timeout if exists
    if (activeTimeout) {
      clearTimeout(activeTimeout);
      activeTimeout = null;
    }
    
    // End client connection if exists
    if (activeClient) {
      activeClient.end().catch(() => {});
      activeClient = null;
    }
  } catch (err) {
    // Ignore errors during cleanup
  }
  
  // Use nextTick to ensure any pending operations complete
  process.nextTick(() => {
    process.exit(code);
  });
}

/**
 * Crawl data for a specific symbol
 * @param {Object} task The task configuration
 */
async function crawlSymbol(task) {
  const { symbol, timeframe, range, options, token, signature } = task;
  
  process.send({
    type: 'log',
    data: `Starting to crawl ${symbol} on ${timeframe} timeframe`
  });

  try {
    // Create TradingView client
    const client = new TradingView.Client({
      token: token,
      signature: signature
    });
    activeClient = client;

    // Initialize chart session
    const chart = new client.Session.Chart();
    activeChart = chart;
    
    // Track data collection
    const collectedData = {
      symbol,
      timeframe,
      periods: [],
      info: null
    };

    // Set up Promise to resolve when data is collected
    const dataPromise = new Promise((resolve, reject) => {
      // Handle errors
      chart.onError((...err) => {
        const errorMessage = Array.isArray(err) ? err.join(' ') : String(err);
        reject(new Error(`Chart error: ${errorMessage}`));
      });

      // Track when symbol is loaded
      chart.onSymbolLoaded(() => {
        try {
          if (chart.infos) {
            const description = chart.infos.description || symbol;
            process.send({
              type: 'log',
              data: `Symbol loaded: ${description}`
            });
            
            collectedData.info = chart.infos;
          } else {
            process.send({
              type: 'log',
              data: `Symbol loaded: ${symbol} (no info available)`
            });
          }
        } catch (err) {
          process.send({
            type: 'log',
            data: `Error handling symbol loaded: ${err.message}`
          });
        }
      });

      // Track updates
      chart.onUpdate(() => {
        try {
          if (chart.periods && chart.periods.length > 0) {
            collectedData.periods = chart.periods;
            
            process.send({
              type: 'log',
              data: `Collected ${chart.periods.length} candles for ${symbol}`
            });
            
            // If we have enough data or more than we requested, resolve
            if (chart.periods.length >= range) {
              resolve(collectedData);
            }
          }
        } catch (err) {
          process.send({
            type: 'log',
            data: `Error handling chart update: ${err.message}`
          });
        }
      });
    });

    // Set market and fetch data
    const chartOptions = {
      timeframe: timeframe || 'D',
      range: range || 1000,
      ...options
    };
    
    chart.setMarket(symbol, chartOptions);

    // Set up timeout handler - properly integrated with Promise
    const timeoutDuration = task.timeout || 30000;
    let timeoutReached = false;
    
    const timeoutPromise = new Promise((resolve, reject) => {
      activeTimeout = setTimeout(() => {
        timeoutReached = true;
        // If we have some data but not full data, resolve with what we have
        if (chart && chart.periods && chart.periods.length > 0) {
          process.send({
            type: 'log',
            data: `Timeout reached, but returning partial data (${chart.periods.length} candles) for ${symbol}`
          });
          resolve(collectedData);
        } else {
          reject(new Error(`Timeout after ${timeoutDuration}ms while crawling ${symbol}`));
        }
      }, timeoutDuration);
    });

    // Race the data collection against timeout
    const result = await Promise.race([dataPromise, timeoutPromise]);
    
    // Clear timeout if data collection won
    if (activeTimeout && !timeoutReached) {
      clearTimeout(activeTimeout);
      activeTimeout = null;
    }
    
    // Validate result before sending
    if (!result || !result.periods) {
      throw new Error(`Invalid data received for ${symbol}`);
    }

    // Send collected data back to main process
    process.send({
      type: 'result',
      data: result
    });
    
    // Cleanup and exit
    await client.end();
    cleanupAndExit(0);
  } catch (error) {
    process.send({
      type: 'error',
      error: error.message || 'Unknown error'
    });
    
    // Always try to cleanup client
    if (activeClient) {
      try {
        await activeClient.end();
      } catch (err) {
        // Ignore errors during cleanup
      }
    }
    
    cleanupAndExit(1);
  }
}
