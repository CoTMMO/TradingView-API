//+------------------------------------------------------------------+
//|                                        TradingViewSessionExample.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd.   |
//|                                             https://www.mql5.com   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "TradingView Session Generation Example"
#property script_show_inputs

// Include required files
#include "../Include/TradingViewAPI.mqh"

// Input parameters
input string  Server = "data.tradingview.com";  // TradingView server
input int     Port = 443;                       // Port (443 for TLS)
input bool    UseTLS = true;                    // Use TLS connection
input string  Symbol = "BINANCE:BTCEUR";        // Symbol to subscribe
input int     Timeframe = 60;                   // Timeframe in minutes
input int     Range = 100;                      // Number of candles to fetch

// Global variables
CTradingViewAPI* g_api = NULL;
CTradingViewMarket* g_market = NULL;
CTradingViewChart* g_chart = NULL;

// Event handler functions
void OnConnectedHandler()
{
   Print("Connected to TradingView");
   
   // No need to authenticate with email and password
   // The connection is already established with unauthorized_user_token
   Print("Using unauthorized session access");
   
   // Get and display session ID and signature
   string sessionId = g_api.GetSessionId();
   string signature = g_api.GetSignature();
   
   Print("Session ID: ", sessionId);
   Print("Signature: ", signature);
   
   // Generate cookies
   string cookies = genAuthCookies(sessionId, signature);
   Print("Generated cookies: ", cookies);
   
   // Save session information to a file
   int fileHandle = FileOpen("TradingView_Session.txt", FILE_WRITE|FILE_CSV);
   if(fileHandle != INVALID_HANDLE) {
      FileWrite(fileHandle, "SessionID", "Signature", "Cookies");
      FileWrite(fileHandle, sessionId, signature, cookies);
      FileClose(fileHandle);
      Print("Session information saved to TradingView_Session.txt");
   } else {
      Print("Failed to save session information to file. Error: ", GetLastError());
   }
   
   // Initialize market data handler
   if(g_market != NULL) delete g_market;
   g_market = new CTradingViewMarket(Symbol, "");
   g_market.SetAPI(g_api);
   g_market.AddDataHandler(OnMarketDataHandler);
   g_market.AddErrorHandler(OnMarketErrorHandler);
   
   // Initialize chart session
   if(g_chart != NULL) delete g_chart;
   g_chart = new CTradingViewChart(Symbol, (ENUM_TIMEFRAME_TV)Timeframe, Range);
   g_chart.SetAPI(g_api);
   g_chart.SetMarket(Symbol, (ENUM_TIMEFRAME_TV)Timeframe, Range);
   g_chart.OnSymbolLoaded(OnSymbolLoadedHandler);
   g_chart.OnUpdate(OnChartUpdateHandler);
   g_chart.OnError(OnChartErrorHandler);
}

void OnDisconnectedHandler()
{
   Print("Disconnected from TradingView");
}

void OnLoggedHandler()
{
   Print("Logged in to TradingView");
}

void OnErrorHandler(string error)
{
   Print("Error: ", error);
}

void OnMarketDataHandler(string data)
{
   Print("Market data: ", data);
}

void OnMarketErrorHandler(string error)
{
   Print("Market error: ", error);
}

void OnSymbolLoadedHandler()
{
   Print("Symbol loaded: ", Symbol);
}

void OnChartUpdateHandler(string data)
{
   Print("Chart update: ", data);
   
   // Get chart data
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   ArrayResize(rates, 1000);
   int count = 0;
   
   MqlRates rate;
   for(int i = 0; i < g_chart.GetRatesCount(); i++) {
      if(g_chart.GetRates(i, rate)) {
         rates[i] = rate;
         count++;
      }
   }
   
   // Process chart data
   if(count > 0) {
      Print("Received ", count, " candles");
      // Display the most recent candle
      Print("Latest candle - Time: ", TimeToString(rates[0].time), 
            ", Open: ", rates[0].open, 
            ", High: ", rates[0].high, 
            ", Low: ", rates[0].low, 
            ", Close: ", rates[0].close, 
            ", Volume: ", rates[0].tick_volume);
   }
}

void OnChartErrorHandler(string error)
{
   Print("Chart error: ", error);
}

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   // Check if we're in testing mode
   if(MQLInfoInteger(MQL_TESTER)) {
      Print("This script cannot be run in Strategy Tester");
      return;
   }
   
   Print("Starting TradingView Session Generation example...");
   
   // Initialize API
   g_api = new CTradingViewAPI();
   if(g_api == NULL) {
      Print("Failed to create TradingView API object");
      return;
   }
   Print("TradingView API object created successfully");
   
   // Set connection parameters
   g_api.SetUseTLS(UseTLS);
   g_api.SetServer(Server, Port);
   g_api.SetRetryParameters(3, 2000);
   g_api.SetAutoFallbackToNonTLS(true);
   Print("Connection parameters set: TLS=", UseTLS, ", Server=", Server, ":", Port);
   
   // Set up event handlers
   Print("Setting up event handlers...");
   g_api.AddConnectedHandler(OnConnectedHandler);
   g_api.AddDisconnectedHandler(OnDisconnectedHandler);
   g_api.AddLoggedHandler(OnLoggedHandler);
   g_api.AddErrorHandler(OnErrorHandler);
   Print("Event handlers registered");
   
   // Connect to TradingView
   Print("Attempting to connect to TradingView...");
   if(!g_api.Connect()) {
      Print("Failed to connect to TradingView. Error code: ", GetLastError());
      delete g_api;
      g_api = NULL;
      return;
   }
   Print("Connect() call completed successfully");
   
   // Set up timer for continuous data reading
   EventSetMillisecondTimer(100);
   Print("Timer set up for data reading");
   
   // Keep the script running for a while to receive data
   Sleep(30000); // Run for 30 seconds
   
   // Clean up
   EventKillTimer();
   
   if(g_api != NULL) {
      delete g_api;
      g_api = NULL;
   }
   
   if(g_market != NULL) {
      delete g_market;
      g_market = NULL;
   }
   
   if(g_chart != NULL) {
      delete g_chart;
      g_chart = NULL;
   }
   
   Print("TradingView Session Generation example completed");
}

//+------------------------------------------------------------------+
//| Timer function                                                    |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Call API's OnTimer method to handle continuous data reading
   if(g_api != NULL) {
      g_api.OnTimer();
   }
} 