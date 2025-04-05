# TradingView API Client Library for MetaTrader 5

This is a conversion of the TradingView API client library from JavaScript to MQL5 (MetaTrader 5). The library provides a way to interact with TradingView's WebSocket API from within MetaTrader 5.

## Features

- Connect to TradingView's WebSocket API
- Authenticate with TradingView
- Subscribe to market data
- Create and manage chart sessions
- Add and manage studies/indicators
- Event-driven architecture for handling updates

## Files

- `Include/TradingViewAPI.mqh` - Main API client class
- `Include/TradingViewMarket.mqh` - Market data handling class
- `Include/TradingViewChart.mqh` - Chart session management class
- `Include/TradingViewStudy.mqh` - Study/indicator management class
- `Scripts/TradingViewExample.mq5` - Example script demonstrating usage

## Installation

1. Copy the `Include` folder to your MetaTrader 5's `MQL5/Include` directory
2. Copy the `Scripts` folder to your MetaTrader 5's `MQL5/Scripts` directory
3. Restart MetaTrader 5

## Usage

Here's a basic example of how to use the library:

```mql5
#include <TradingViewAPI.mqh>

// Create API client
CTradingViewAPI* api = new CTradingViewAPI();

// Connect and login
if(api.Connect() && api.Login("username", "password")) {
   // Create market data subscription
   CTradingViewMarket* market = new CTradingViewMarket("EURUSD");
   market.SetAPI(api);
   
   // Create chart session
   CTradingViewChart* chart = new CTradingViewChart("EURUSD", TIMEFRAME_TV_60);
   chart.SetAPI(api);
   
   // Create study/indicator
   CTradingViewStudy* study = new CTradingViewStudy("RSI", "RSI", "{\"length\":14}");
   study.SetAPI(api);
   study.Create();
   
   // Cleanup
   delete study;
   delete chart;
   delete market;
   delete api;
}
```

## Event Handling

The library uses an event-driven architecture. You can subscribe to various events:

```mql5
// Market data events
market.OnData(OnMarketData);
market.OnError(OnError);

// Chart events
chart.OnSymbolLoaded(OnSymbolLoaded);
chart.OnUpdate(OnChartUpdate);
chart.OnError(OnError);

// Study events
study.OnCreated(OnStudyCreated);
study.OnUpdate(OnStudyUpdate);
study.OnError(OnError);
```

## Limitations

- WebSocket communication is handled through MetaTrader 5's built-in networking capabilities
- Some advanced features may require additional implementation
- Performance may vary depending on network conditions and MetaTrader 5's resources

## Dependencies

- MetaTrader 5 platform
- MQL5 standard library
- JSON parser (included in the standard library)

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Original JavaScript TradingView API client library
- MetaQuotes Software Corp. for MetaTrader 5 platform
- TradingView for their WebSocket API 