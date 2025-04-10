//+------------------------------------------------------------------+
//|                                        TradingViewSocketExample.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd.   |
//|                                             https://www.mql5.com   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "TradingView WebSocket API Example"
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
CTradingViewStudy* g_study = NULL;

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
   /*
   // Initialize market data handler
   if(g_market != NULL) delete g_market;
   g_market = new CTradingViewMarket(Symbol, "");
   g_market.SetAPI(g_api);
   g_market.AddDataHandler(OnMarketDataHandler);
   g_market.AddErrorHandler(OnMarketErrorHandler);
   */
   // Initialize chart session
   if(g_chart != NULL) delete g_chart;
   g_chart = new CTradingViewChart(Symbol, (ENUM_TIMEFRAME_TV)Timeframe, Range);
   g_chart.SetAPI(g_api);
   g_chart.SetMarket(Symbol, (ENUM_TIMEFRAME_TV)Timeframe, Range);
   g_chart.OnSymbolLoaded(OnSymbolLoadedHandler);
   g_chart.OnUpdate(OnChartUpdateHandler);
   g_chart.OnError(OnChartErrorHandler);
   /*
   // Initialize study/indicator
   if(g_study != NULL) delete g_study;
   g_study = new CTradingViewStudy("RSI", "RSI", "length=14");
   g_study.SetAPI(g_api);
   g_study.OnCreated(OnStudyCreatedHandler);
   g_study.OnUpdate(OnStudyUpdateHandler);
   g_study.OnError(OnStudyErrorHandler);
   */
   // Create the study
   //g_study.Create();
}

void OnDisconnectedHandler()
{
   Print("Disconnected from TradingView");
   
   // Attempt to reconnect if disconnected unexpectedly
   if(g_api != NULL) {
      Print("Attempting to reconnect...");
      if(g_api.Connect()) {
         Print("Reconnection successful");
      } else {
         Print("Reconnection failed");
      }
   }
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
   Print("Market data received");
   
   // Debug the data
   DebugData(data);
   
   // Parse the market data
   CJAVal json;
   if(json.Deserialize(data)) {
      // Check if this is quote data
      if(json["m"].ToStr() == "qsd") {
         CJAVal p = json["p"];
         if(p.Size() > 1) {
            CJAVal tickData = p[1];
            if(tickData["v"].ToStr() != "null") {
               double bid = tickData["b"].ToDbl();
               double ask = tickData["a"].ToDbl();
               double last = tickData["v"].ToDbl();
               datetime time = (datetime)tickData["t"].ToInt();
               
               Print("Market data - Symbol: ", Symbol, 
                     ", Bid: ", bid, 
                     ", Ask: ", ask, 
                     ", Last: ", last, 
                     ", Time: ", TimeToString(time));
            }
         }
      }
   }
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
   Print("Chart update received");
   
   // Debug the data
   DebugData(data);
   
   // Parse the chart data
   CJAVal json;
   if(json.Deserialize(data)) {
      // Check if this is chart data
      if(json["m"].ToStr() == "cs") {
         CJAVal p = json["p"];
         if(p.Size() > 1) {
            CJAVal bars = p[1];
            if(bars.ToStr() != "null") {
               int count = bars.Size();
               Print("Received ", count, " candles");
               
               // Get chart data
               MqlRates rates[];
               ArraySetAsSeries(rates, true);
               ArrayResize(rates, count);
               
               MqlRates rate;
               for(int i = 0; i < g_chart.GetRatesCount(); i++) {
                  if(g_chart.GetRates(i, rate)) {
                     rates[i] = rate;
                  }
               }
               
               // Display the most recent candles
               int displayCount = MathMin(count, 5); // Show up to 5 candles
               for(int i = 0; i < displayCount; i++) {
                  Print("Candle ", i, " - Time: ", TimeToString(rates[i].time), 
                        ", Open: ", rates[i].open, 
                        ", High: ", rates[i].high, 
                        ", Low: ", rates[i].low, 
                        ", Close: ", rates[i].close, 
                        ", Volume: ", rates[i].tick_volume);
               }
            }
         }
      }
   }
}

void OnChartErrorHandler(string error)
{
   Print("Chart error: ", error);
}

void OnStudyCreatedHandler()
{
   Print("Study created: RSI");
}

void OnStudyUpdateHandler(string data)
{
   Print("Study update received");
   
   // Debug the data
   DebugData(data);
   
   // Parse the study data
   CJAVal json;
   if(json.Deserialize(data)) {
      // Check if this is study data
      if(json["m"].ToStr() == "study_data") {
         CJAVal p = json["p"];
         if(p.Size() > 1) {
            CJAVal values = p[1];
            if(values.ToStr() != "null") {
               int count = values.Size();
               Print("Received ", count, " RSI values");
               
               // Get study data
               double rsiValues[];
               int rsiCount = 0;
               if(g_study.GetValues(rsiCount, rsiValues)) {
                  // Display the most recent RSI values
                  int displayCount = MathMin(rsiCount, 5); // Show up to 5 values
                  for(int i = 0; i < displayCount; i++) {
                     Print("RSI value ", i, ": ", rsiValues[i]);
                  }
               }
            }
         }
      }
   }
}

void OnStudyErrorHandler(string error)
{
   Print("Study error: ", error);
}

//+------------------------------------------------------------------+
//| Debug function to help diagnose issues                             |
//+------------------------------------------------------------------+
void DebugData(string data)
{
   // Print the raw data for debugging
   Print("DEBUG - Raw data: ", data);
   
   // Try to parse as JSON
   CJAVal json;
   if(json.Deserialize(data)) {
      Print("DEBUG - Successfully parsed as JSON");
      
      // Check message type
      string msgType = json["m"].ToStr();
      Print("DEBUG - Message type: ", msgType);
      
      // Check parameters
      if(json["p"].Size() > 0) {
         Print("DEBUG - Parameters count: ", json["p"].Size());
         
         // Print first parameter
         if(json["p"][0].ToStr() != "") {
            Print("DEBUG - First parameter: ", json["p"][0].ToStr());
         }
         
         // Print second parameter if exists
         if(json["p"].Size() > 1) {
            if(json["p"][1].ToStr() != "null") {
               Print("DEBUG - Second parameter: ", json["p"][1].ToStr());
            } else {
               Print("DEBUG - Second parameter is null");
            }
         }
      } else {
         Print("DEBUG - No parameters found");
      }
   } else {
      Print("DEBUG - Failed to parse as JSON");
   }
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
   
   Print("Starting TradingView WebSocket example...");
   
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
   
   // Keep the script running
   Print("Script is now running. Press 'Stop' button to terminate.");
   
   // IMPORTANT: This is the key change - we need to keep the script running
   // until the user manually stops it by clicking the "Stop" button
   // The script will now continue running and receiving data until stopped
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("Script is being terminated. Reason: ", reason);
   
   // Clean up
   EventKillTimer();
   
   // First disconnect the API to prevent callbacks during cleanup
   if(g_api != NULL) {
      g_api.Disconnect();
   }
   
   // Then delete objects in reverse order of creation
   if(g_study != NULL) {
      delete g_study;
      g_study = NULL;
   }
   
   if(g_chart != NULL) {
      delete g_chart;
      g_chart = NULL;
   }
   
   if(g_market != NULL) {
      delete g_market;
      g_market = NULL;
   }
   
   if(g_api != NULL) {
      delete g_api;
      g_api = NULL;
   }
   
   Print("TradingView WebSocket example completed");
}

//+------------------------------------------------------------------+
//| Timer function                                                    |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Call API's OnTimer method to handle continuous data reading
   if(g_api != NULL && g_api.IsConnected()) {
      g_api.OnTimer();
   }
} 