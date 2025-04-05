//+------------------------------------------------------------------+
//|                                      TradingViewWebSocketExample.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd.   |
//|                                             https://www.mql5.com   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

// Include required files
#include "../Include/TradingViewAPI.mqh"

// Global variables
CTradingViewAPI* g_api = NULL;
CTradingViewMarket* g_market = NULL;
CTradingViewChart* g_chart = NULL;

// Chart properties
string g_symbol = "EURUSD";
ENUM_TIMEFRAME_TV g_timeframe = TIMEFRAME_TV_60;
int g_range = 100;

// Connection parameters
bool g_use_tls = true;
string g_server = "data.tradingview.com";
int g_port = 443;
int g_max_retries = 3;
int g_retry_delay_ms = 2000;
bool g_auto_fallback_to_non_tls = true;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   // Check if we're in testing mode
   if(MQLInfoInteger(MQL_TESTER)) {
      Print("This script cannot be run in Strategy Tester");
      return INIT_FAILED;
   }
   
   // Initialize API
   g_api = new CTradingViewAPI();
   if(g_api == NULL) {
      Print("Failed to create TradingView API object");
      return INIT_FAILED;
   }
   
   // Set connection parameters
   g_api.SetUseTLS(g_use_tls);
   g_api.SetServer(g_server, g_port);
   g_api.SetRetryParameters(g_max_retries, g_retry_delay_ms);
   g_api.SetAutoFallbackToNonTLS(g_auto_fallback_to_non_tls);
   
   // Set up event handlers
   g_api.AddConnectedHandler("OnConnected");
   g_api.AddDisconnectedHandler("OnDisconnected");
   g_api.AddLoggedHandler("OnLogged");
   g_api.AddErrorHandler("OnError");
   
   // Connect to TradingView
   if(!g_api.Connect()) {
      Print("Failed to connect to TradingView");
      delete g_api;
      g_api = NULL;
      return INIT_FAILED;
   }
   
   // Set up timer for continuous data reading
   EventSetMillisecondTimer(100);
   
   Print("Successfully connected to TradingView");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Stop timer
   EventKillTimer();
   
   // Clean up API object
   if(g_api != NULL) {
      delete g_api;
      g_api = NULL;
   }
   
   // Clean up other objects
   if(g_market != NULL) {
      delete g_market;
      g_market = NULL;
   }
   
   if(g_chart != NULL) {
      delete g_chart;
      g_chart = NULL;
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Main loop - keep the script running
   Sleep(100);
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

//+------------------------------------------------------------------+
//| Event handler for connection                                      |
//+------------------------------------------------------------------+
void OnConnected()
{
   Print("Connected to TradingView");
   
   // Login with email and password
   string email = "your_email@example.com"; // Replace with your email
   string password = "your_password";        // Replace with your password
   
   Print("Attempting to authenticate with email: ", email);
   bool authSuccess = g_api.Authenticate(email, password);
   
   if(authSuccess) {
      Print("Authentication successful!");
      
      // Get and display session ID and signature
      string sessionId = g_api.GetSessionId();
      string signature = g_api.GetSignature();
      
      Print("Session ID: ", sessionId);
      Print("Signature: ", signature);
      
      // Initialize market data handler
      if(g_market != NULL) delete g_market;
      g_market = new CTradingViewMarket(g_symbol, "");
      g_market.SetAPI(g_api);
      g_market.AddDataHandler("OnMarketData");
      g_market.AddErrorHandler("OnMarketError");
      
      // Initialize chart session
      if(g_chart != NULL) delete g_chart;
      g_chart = new CTradingViewChart(g_symbol, g_timeframe, g_range);
      g_chart.SetAPI(g_api);
      g_chart.OnSymbolLoaded("OnSymbolLoaded");
      g_chart.OnUpdate("OnChartUpdate");
      g_chart.OnError("OnChartError");
      
      // Set up the chart
      g_chart.SetMarket(g_symbol, g_timeframe, g_range);
   } else {
      Print("Authentication failed. Please check your credentials.");
   }
}

//+------------------------------------------------------------------+
//| Event handler for disconnection                                   |
//+------------------------------------------------------------------+
void OnDisconnected()
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

//+------------------------------------------------------------------+
//| Event handler for login                                           |
//+------------------------------------------------------------------+
void OnLogged()
{
   Print("Logged in to TradingView");
}

//+------------------------------------------------------------------+
//| Event handler for errors                                          |
//+------------------------------------------------------------------+
void OnError(string error)
{
   Print("Error: ", error);
   
   // Check for TLS-related errors
   if(StringFind(error, "TLS") >= 0 || StringFind(error, "SSL") >= 0) {
      Print("TLS/SSL error detected. Consider setting g_use_tls = false in your script.");
   }
}

//+------------------------------------------------------------------+
//| Event handler for market data                                     |
//+------------------------------------------------------------------+
void OnMarketData(string data)
{
   Print("Market data received: ", data);
   
   // Process market data
   if(g_market != NULL) {
      g_market.ProcessUpdate(data);
   }
}

//+------------------------------------------------------------------+
//| Event handler for market errors                                   |
//+------------------------------------------------------------------+
void OnMarketError(string error)
{
   Print("Market error: ", error);
}

//+------------------------------------------------------------------+
//| Event handler for symbol loaded                                   |
//+------------------------------------------------------------------+
void OnSymbolLoaded()
{
   Print("Symbol loaded: ", g_symbol);
}

//+------------------------------------------------------------------+
//| Event handler for chart updates                                   |
//+------------------------------------------------------------------+
void OnChartUpdate(string data)
{
   Print("Chart update received: ", data);
   
   // Process chart data
   if(g_chart != NULL) {
      g_chart.ProcessUpdate(data);
      
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
      
      // Display the latest price
      if(count > 0) {
         Print("Latest price for ", g_symbol, ": ", rates[0].close);
      }
   }
}

//+------------------------------------------------------------------+
//| Event handler for chart errors                                    |
//+------------------------------------------------------------------+
void OnChartError(string error)
{
   Print("Chart error: ", error);
} 