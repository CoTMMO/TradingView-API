//+------------------------------------------------------------------+
//|                                              TradingViewExample.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd.   |
//|                                             https://www.mql5.com   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

// Include required files
#include "../Include/TradingViewAPI.mqh"

// Global variables - declare pointers to avoid constructor errors
CTradingViewAPI* g_api = NULL;
CTradingViewMarket* g_market = NULL;  // Changed to pointer
CTradingViewChart* g_chart = NULL;    // Changed to pointer
CTradingViewStudy* g_study = NULL;    // Changed to pointer

// Chart properties
string g_symbol = "EURUSD";
ENUM_TIMEFRAME_TV g_timeframe = TIMEFRAME_TV_60;
int g_range = 100;

// Connection parameters
int g_max_retries = 3;
int g_retry_delay_ms = 2000;
bool g_use_tls = true;  // Flag to control TLS usage
string g_alt_server = "data.tradingview.com";  // Alternative server address
int g_alt_port = 443;  // Alternative port (TLS)
bool g_auto_fallback_to_non_tls = true;  // Automatically try non-TLS if TLS fails

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
   g_api.SetServer(g_alt_server, g_alt_port);
   g_api.SetRetryParameters(g_max_retries, g_retry_delay_ms);
   g_api.SetAutoFallbackToNonTLS(g_auto_fallback_to_non_tls);
   
   // Connect to TradingView
   if(!g_api.Connect()) {
      Print("Failed to connect to TradingView");
      delete g_api;
      g_api = NULL;
      return INIT_FAILED;
   }
   
   // Set up event handlers
   g_api.AddConnectedHandler("OnConnected");
   g_api.AddDisconnectedHandler("OnDisconnected");
   g_api.AddLoggedHandler("OnLogged");
   g_api.AddErrorHandler("OnError");
   
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
   
   if(g_study != NULL) {
      delete g_study;
      g_study = NULL;
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
   string email = "b.x9.gaming@gmail.com";
   string password = "Quynh@2020";
   
   Print("Attempting to authenticate with email: ", email);
   bool authSuccess = g_api.Authenticate(email, password);
   
   if(authSuccess) {
      Print("Authentication successful!");
      
      // Get and display session ID and signature
      string sessionId = g_api.GetSessionId();
      string signature = g_api.GetSignature();
      
      // If session ID or signature is empty, try to request them explicitly
      if(sessionId == "" || signature == "") {
         Print("Session ID or signature not obtained during authentication. Requesting explicitly...");
         if(g_api.RequestSessionInfo()) {
            sessionId = g_api.GetSessionId();
            signature = g_api.GetSignature();
            Print("Successfully obtained session information.");
         } else {
            Print("Failed to obtain session information explicitly.");
         }
      }
      
      Print("Session ID: ", sessionId);
      Print("Signature: ", signature);
      
      // Save session ID and signature to a file for future use
      int fileHandle = FileOpen("TradingView_Session.txt", FILE_WRITE|FILE_CSV);
      if(fileHandle != INVALID_HANDLE) {
         FileWrite(fileHandle, "SessionID", "Signature");
         FileWrite(fileHandle, sessionId, signature);
         FileClose(fileHandle);
         Print("Session information saved to TradingView_Session.txt");
      } else {
         Print("Failed to save session information to file. Error: ", GetLastError());
      }
   } else {
      Print("Authentication failed. Please check your credentials.");
      return;
   }
   
   // Initialize market data handler - create new instances with required parameters
   if(g_market != NULL) delete g_market;  // Delete previous instance if exists
   g_market = new CTradingViewMarket(g_symbol, "");  // Add second required parameter
   g_market.SetAPI(g_api);
   g_market.AddDataHandler("OnMarketData");
   g_market.AddErrorHandler("OnMarketError");
   
   // Initialize chart session
   if(g_chart != NULL) delete g_chart;  // Delete previous instance if exists
   g_chart = new CTradingViewChart(g_symbol, g_timeframe, g_range);
   g_chart.SetAPI(g_api);
   g_chart.OnSymbolLoaded("OnSymbolLoaded");
   g_chart.OnUpdate("OnChartUpdate");
   g_chart.OnError("OnChartError");
   
   // Initialize study/indicator
   if(g_study != NULL) delete g_study;  // Delete previous instance if exists
   g_study = new CTradingViewStudy("RSI", "RSI", "length=14");
   g_study.SetAPI(g_api);
   g_study.OnCreated("OnStudyCreated");
   g_study.OnUpdate("OnStudyUpdate");
   g_study.OnError("OnStudyError");
   
   // Create the study
   g_study.Create();
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
   Print("Market data: ", data);
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
   Print("Chart update: ", data);
   
   // Get chart data
   MqlRates rates[];
   ArraySetAsSeries(rates, true); // Ensure array is set as time series
   ArrayResize(rates, 1000);      // Pre-allocate space for the array
   int count = 0;
   
   // Fix parameter conversion issue by using a single MqlRates variable
   MqlRates rate;
   for(int i = 0; i < g_chart.GetRatesCount(); i++) {
      if(g_chart.GetRates(i, rate)) {
         rates[i] = rate;
         count++;
      }
   }
   
   // Process chart data
   if(count > 0) {
      // Create custom chart
      CreateCustomChart(rates, count);
   }
}

//+------------------------------------------------------------------+
//| Event handler for chart errors                                    |
//+------------------------------------------------------------------+
void OnChartError(string error)
{
   Print("Chart error: ", error);
}

//+------------------------------------------------------------------+
//| Event handler for study created                                   |
//+------------------------------------------------------------------+
void OnStudyCreated()
{
   Print("Study created: RSI");
}

//+------------------------------------------------------------------+
//| Event handler for study updates                                   |
//+------------------------------------------------------------------+
void OnStudyUpdate(string data)
{
   Print("Study update: ", data);
   
   // Get study data
   double values[];
   int count = 0;
   // Change back to GetValues which is likely the correct method name
   if(g_study.GetValues(count, values)) {  // Changed from GetData to GetValues
      // Process study data
      if(count > 0) {
         // Update custom chart with study data
         UpdateCustomChart(values, count);
      }
   }
}

//+------------------------------------------------------------------+
//| Event handler for study errors                                    |
//+------------------------------------------------------------------+
void OnStudyError(string error)
{
   Print("Study error: ", error);
}

//+------------------------------------------------------------------+
//| Create custom chart from rates data                               |
//+------------------------------------------------------------------+
void CreateCustomChart(const MqlRates &rates[], int count)
{
   // Create a new chart
   long chartId = ChartOpen(g_symbol, Period());
   
   if(chartId > 0) {
      // Set chart properties
      ChartSetInteger(chartId, CHART_SHOW_GRID, false);
      ChartSetInteger(chartId, CHART_SHOW_VOLUMES, true);
      ChartSetInteger(chartId, CHART_SHOW_OBJECT_DESCR, true);
      
      // Add rates to chart
      for(int i = 0; i < count; i++) {
         // Add candles as objects instead of using non-existent chart properties
         string candleName = "Candle_" + IntegerToString(i);
         datetime time = rates[i].time;
         
         // Draw candle using rectangle objects
         ObjectCreate(chartId, candleName, OBJ_RECTANGLE, 0, time, rates[i].low, time + PeriodSeconds(), rates[i].high);
         ObjectSetInteger(chartId, candleName, OBJPROP_COLOR, rates[i].close > rates[i].open ? clrGreen : clrRed);
         ObjectSetInteger(chartId, candleName, OBJPROP_FILL, true);
         
         // Draw volume using rectangle objects (replacing OBJ_HISTOGRAM)
         string volumeName = "Volume_" + IntegerToString(i);
         double volumeHeight = NormalizeDouble(rates[i].tick_volume / 100.0, 2); // Scale volume for visibility
         ObjectCreate(chartId, volumeName, OBJ_RECTANGLE, 1, time, 0, 
                     time + PeriodSeconds() * 0.8, volumeHeight); // Create rectangle for volume bar
         ObjectSetInteger(chartId, volumeName, OBJPROP_COLOR, clrBlue);
         ObjectSetInteger(chartId, volumeName, OBJPROP_FILL, true);
         ObjectSetInteger(chartId, volumeName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(chartId, volumeName, OBJPROP_BACK, true); // Put in background
      }
      
      // Redraw chart
      ChartRedraw(chartId);
   }
}

//+------------------------------------------------------------------+
//| Update custom chart with study data                               |
//+------------------------------------------------------------------+
void UpdateCustomChart(const double &values[], int count)
{
   // Get chart ID
   long chartId = ChartFirst();
   
   if(chartId > 0) {
      // Add study values to chart
      for(int i = 0; i < count; i++) {
         // Create indicator line
         string name = "RSI_" + IntegerToString(i);
         ObjectCreate(chartId, name, OBJ_TREND, 0, i, values[i], i+1, values[i]);
         ObjectSetInteger(chartId, name, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(chartId, name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(chartId, name, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(chartId, name, OBJPROP_SELECTABLE, false);
      }
      
      // Redraw chart
      ChartRedraw(chartId);
   }
}