//+------------------------------------------------------------------+
//|                                           TradingViewTLSTest.mq5   |
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

// Connection parameters
bool g_use_tls = true;  // Flag to control TLS usage
string g_server = "data.tradingview.com";  // Default server
int g_port = 443;  // Default port for TLS
bool g_auto_fallback_to_non_tls = true;  // Automatically try non-TLS if TLS fails
int g_max_retries = 3;
int g_retry_delay_ms = 2000;

//+------------------------------------------------------------------+
//| Script program start function                                      |
//+------------------------------------------------------------------+
void OnStart()
{
   // Check if we're in testing mode
   if(MQLInfoInteger(MQL_TESTER)) {
      Print("This script cannot be run in Strategy Tester");
      return;
   }
   
   // Initialize API
   g_api = new CTradingViewAPI();
   if(g_api == NULL) {
      Print("Failed to create TradingView API object");
      return;
   }
   
   // Set connection parameters
   g_api.SetUseTLS(g_use_tls);
   g_api.SetServer(g_server, g_port);
   g_api.SetRetryParameters(g_max_retries, g_retry_delay_ms);
   g_api.SetAutoFallbackToNonTLS(g_auto_fallback_to_non_tls);
   
   // Add event handlers
   g_api.AddConnectedHandler("OnConnected");
   g_api.AddDisconnectedHandler("OnDisconnected");
   g_api.AddErrorHandler("OnError");
   
   // Test connection with TLS
   Print("Testing connection with TLS...");
   g_use_tls = true;
   g_api.SetUseTLS(true);
   g_port = 443;
   g_api.SetServer(g_server, g_port);
   
   bool tlsResult = g_api.Connect();
   Print("TLS connection result: ", tlsResult ? "SUCCESS" : "FAILED");
   
   // If TLS failed, test without TLS
   if(!tlsResult && g_auto_fallback_to_non_tls) {
      Print("\nTesting connection without TLS...");
      g_use_tls = false;
      g_api.SetUseTLS(false);
      g_port = 80;
      g_api.SetServer(g_server, g_port);
      
      bool nonTlsResult = g_api.Connect();
      Print("Non-TLS connection result: ", nonTlsResult ? "SUCCESS" : "FAILED");
   }
   
   // Test alternative servers
   string altServers[] = {"ws.tradingview.com", "data.tradingview.com", "charts.tradingview.com"};
   
   for(int i = 0; i < ArraySize(altServers); i++) {
      if(altServers[i] == g_server) continue; // Skip already tested server
      
      Print("\nTesting alternative server: ", altServers[i]);
      g_server = altServers[i];
      g_api.SetServer(g_server, g_port);
      
      bool altResult = g_api.Connect();
      Print("Alternative server connection result: ", altResult ? "SUCCESS" : "FAILED");
      
      if(altResult) {
         Print("Successfully connected to alternative server: ", altServers[i]);
         break;
      }
   }
   
   // Clean up
   if(g_api != NULL) {
      delete g_api;
      g_api = NULL;
   }
   
   Print("\nTLS Test completed. Check the Experts tab for results.");
}

//+------------------------------------------------------------------+
//| Event handler for connection                                      |
//+------------------------------------------------------------------+
void OnConnected()
{
   Print("Connected to TradingView");
}

//+------------------------------------------------------------------+
//| Event handler for disconnection                                   |
//+------------------------------------------------------------------+
void OnDisconnected()
{
   Print("Disconnected from TradingView");
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