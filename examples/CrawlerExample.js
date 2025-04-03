const TradingViewCrawler = require('../src/TradingViewCrawler');
const { getTop40Markets } = require('./Search');

// Initialize the crawler
const crawler = new TradingViewCrawler({
  maxWorkers: 4, // Use 4 workers (processes)
  outputDir: './crawled_data', // Where to save the data
  token: process.env.SESSION || '', // Optional TradingView session token
  signature: process.env.SIGNATURE || '', // Optional TradingView signature
  timeout: 60000, // 60 second timeout per symbol
  retries: 3 // Retry failed symbols 3 times
});

// Add initial symbols to crawl
crawler.addSymbols([
  {
    symbol: 'BINANCE:BTCUSDT',
    timeframe: '15', // Daily timeframe
    range: 500, // Get 500 candles
  },
  {
    symbol: 'BINANCE:ETHUSDT',
    timeframe: '60', // 60 minute timeframe
    range: 1000, // Get 1000 candles
  },
  {
    symbol: 'NASDAQ:AAPL',
    timeframe: '15', // Weekly timeframe
    range: 200, // Get 200 candles
  },
  {
    symbol: 'COMEX:GC1!',
    timeframe: '15', // Weekly timeframe
    range: 200, // Get 200 candles
  },
  // Add more symbols as needed
]);

// Function to start the crawler after adding searched markets
async function startCrawlerWithSearchedMarkets() {
  try {
    // Get the top 40 markets from BINANCE
    const markets = await getTop40Markets('BINANCE:');
    console.log(`Found ${markets.length} markets to add to crawler`);
    
    // Create market objects for the crawler
    const marketSymbols = markets.map(market => ({
      symbol: market.symbol,
      timeframe: '15', // 15 minute timeframe
      range: 300, // Get 300 candles
    }));
    
    // Add the markets to the crawler
    crawler.addSymbols(marketSymbols);
    console.log(`Added ${marketSymbols.length} markets to crawler queue`);
    
    // Start crawling
    crawler.start();
    
    // Print status every 5 seconds
    const statusInterval = setInterval(() => {
      const status = crawler.getStatus();
      console.log('Crawler status:', status);
      
      // If all tasks are complete, stop the crawler and exit
      if (status.running && status.activeWorkers === 0 && status.queuedTasks === 0) {
        clearInterval(statusInterval);
        crawler.stop();
        console.log('Crawling completed. Results saved to', crawler.options.outputDir);
      }
    }, 5000);
    
    // Handle graceful shutdown
    process.on('SIGINT', () => {
      console.log('Stopping crawler...');
      clearInterval(statusInterval);
      crawler.stop();
      process.exit(0);
    });
  } catch (error) {
    console.error('Error starting crawler with searched markets:', error);
  }
}

// Run the async function to start the crawler
startCrawlerWithSearchedMarkets();
