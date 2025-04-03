const TradingView = require('../main');

/**
 * This example tests the searching functions such
 * as 'searchMarketV3' and 'searchIndicator'
 */

// Function to get the first 40 markets for a query
async function getTop40Markets(query = 'BINANCE:') {
  try {
    const markets = await TradingView.searchMarketV3(query);
    return markets.slice(0, 40); // Return only the first 40 markets
  } catch (error) {
    console.error('Error fetching markets:', error);
    return [];
  }
}

// Example usage
TradingView.searchMarketV3('BINANCE:').then((rs) => {
  console.log('Found Markets:', rs);
});

TradingView.searchIndicator('RSI').then((rs) => {
  console.log('Found Indicators:', rs);
});

// Export the function for use in other files
module.exports = {
  getTop40Markets
};
