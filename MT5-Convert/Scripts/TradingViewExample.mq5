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
string g_symbol = "BINANCE:BTCEUR";
ENUM_TIMEFRAME_TV g_timeframe = TIMEFRAME_TV_60;
int g_range = 100;

// Connection parameters
int g_max_retries = 3;
int g_retry_delay_ms = 2000;
bool g_use_tls = true;  // Flag to control TLS usage
string g_alt_server = "data.tradingview.com";  // Alternative server address
int g_alt_port = 443;  // Alternative port (TLS)
bool g_auto_fallback_to_non_tls = true;  // Automatically try non-TLS if TLS fails

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
   
   // If session ID or signature is empty, try to request them explicitly
   if(sessionId == "" || signature == "") {
      Print("Session ID or signature not obtained during connection. Requesting explicitly...");
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
   
   // Initialize market data handler - create new instances with required parameters
   if(g_market != NULL) delete g_market;  // Delete previous instance if exists
   g_market = new CTradingViewMarket(g_symbol, "");  // Add second required parameter
   g_market.SetAPI(g_api);
   g_market.AddDataHandler(OnMarketDataHandler);
   g_market.AddErrorHandler(OnMarketErrorHandler);
   
   // Initialize study/indicator
   if(g_study != NULL) delete g_study;  // Delete previous instance if exists
   g_study = new CTradingViewStudy("RSI", "RSI", "length=14");
   g_study.SetAPI(g_api);
   g_study.OnCreated(OnStudyCreatedHandler);
   g_study.OnUpdate(OnStudyUpdateHandler);
   g_study.OnError(OnStudyErrorHandler);
   
   // Create the study
   g_study.Create();
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
   
   // Check for TLS-related errors
   if(StringFind(error, "TLS") >= 0 || StringFind(error, "SSL") >= 0) {
      Print("TLS/SSL error detected. Consider setting g_use_tls = false in your script.");
   }
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
   Print("Symbol loaded: ", g_symbol);
}

void OnChartUpdateHandler(string data)
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

void OnStudyErrorHandler(string error)
{
   Print("Study error: ", error);
}

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
   
   Print("Starting initialization...");
   
   // Initialize API
   g_api = new CTradingViewAPI();
   if(g_api == NULL) {
      Print("Failed to create TradingView API object");
      return INIT_FAILED;
   }
   Print("TradingView API object created successfully");
   
   // Set connection parameters
   g_api.SetUseTLS(g_use_tls);
   g_api.SetServer(g_alt_server, g_alt_port);
   g_api.SetRetryParameters(g_max_retries, g_retry_delay_ms);
   g_api.SetAutoFallbackToNonTLS(g_auto_fallback_to_non_tls);
   Print("Connection parameters set: TLS=", g_use_tls, ", Server=", g_alt_server, ":", g_alt_port);
   
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
      return INIT_FAILED;
   }
   Print("Connect() call completed successfully");
   
   // Initialize chart session - similar to JavaScript example
   Print("Initializing chart session...");
   if(g_chart != NULL) delete g_chart;  // Delete previous instance if exists
   g_chart = new CTradingViewChart(g_symbol, g_timeframe, g_range);
   g_chart.SetAPI(g_api);
   g_chart.SetMarket(g_symbol, g_timeframe, g_range);
   // Set up chart event handlers - similar to JavaScript example
   g_chart.OnSymbolLoaded(OnSymbolLoadedHandler);
   g_chart.OnUpdate(OnChartUpdateHandler);
   g_chart.OnError(OnChartErrorHandler);
   Print("Chart session initialized with symbol: ", g_symbol);
   
   // Set up timer for continuous data reading
   EventSetMillisecondTimer(100);
   Print("Timer set up for data reading");
   
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