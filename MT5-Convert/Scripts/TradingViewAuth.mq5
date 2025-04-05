//+------------------------------------------------------------------+
//|                                              TradingViewAuth.mq5 |
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

// Authentication parameters
string g_email = "b.x9.gaming@gmail.com";
string g_password = "Quynh@2020";

// Connection parameters
int g_max_retries = 5;  // Increased from 3 to 5
int g_retry_delay_ms = 3000;  // Increased from 2000 to 3000

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   // Check if running in any testing mode (Strategy Tester, Optimization, or Visual Mode)
   if(MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION) || MQLInfoInteger(MQL_VISUAL_MODE)) {
      Print("ERROR: This script cannot be run in the Strategy Tester. TradingView API requires a live connection.");
      Print("Please run this script on a live chart outside of the Strategy Tester environment.");
      Print("To use this script:");
      Print("1. Open a chart in MetaTrader 5");
      Print("2. Attach this script to the chart");
      Print("3. Make sure you have an active internet connection");
      Print("4. Run the script on a live chart (not in Strategy Tester)");
      return INIT_FAILED;
   }

   // Create API client
   g_api = new CTradingViewAPI();
   
   // Set up event handlers
   g_api.AddConnectedHandler("OnConnected");
   g_api.AddDisconnectedHandler("OnDisconnected");
   g_api.AddLoggedHandler("OnLogged");
   g_api.AddErrorHandler("OnError");
   
   // Connect to TradingView with retry logic
   Print("Attempting to connect to TradingView...");
   
   bool connected = false;
   int retry_count = 0;
   
   while(!connected && retry_count < g_max_retries) {
      Print("Connection attempt ", retry_count + 1, " of ", g_max_retries);
      connected = g_api.Connect();
      
      if(!connected) {
         int error = GetLastError();
         Print("Connection attempt ", retry_count + 1, " failed. Error code: ", error);
         
         // Handle specific error codes
         if(error == 4014) {
            Print("Network operations are not allowed in testing mode.");
            Print("Please run this script on a live chart, not in the Strategy Tester.");
            return INIT_FAILED;
         }
         else if(error == 5274) { // TLS handshake error
            Print("TLS handshake error (5274). This could be due to:");
            Print("1. Outdated SSL/TLS libraries in your MetaTrader 5 installation");
            Print("2. Network restrictions or firewall settings blocking secure connections");
            Print("3. Issues with the TradingView server's SSL certificate");
            Print("4. Proxy or VPN interference with the connection");
            Print("Please try updating MetaTrader 5 to the latest version or check your network settings.");
            Print("If the problem persists, try disabling any VPN or proxy services.");
         }
         else if(error == 4060) { // ERR_SOCKET_CONNECT_FAILED
            Print("Could not connect to server. Please check your internet connection.");
         }
         else if(error == 4018) { // ERR_SERVER_BUSY
            Print("Server is busy. Retrying in ", g_retry_delay_ms/1000, " seconds...");
         }
         else {
            Print("General connection error. Retrying in ", g_retry_delay_ms/1000, " seconds...");
         }
         
         // Increment retry counter and wait before next attempt
         retry_count++;
         if(retry_count < g_max_retries) {
            Print("Waiting ", g_retry_delay_ms/1000, " seconds before next attempt...");
            Sleep(g_retry_delay_ms);
         }
      }
   }
   
   if(!connected) {
      Print("Failed to connect to TradingView after ", g_max_retries, " attempts. Please check your network connection.");
      return INIT_FAILED;
   }
   
   Print("Successfully connected to TradingView");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up resources
   if(g_api != NULL) {
      delete g_api;
      g_api = NULL;
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
//| Event handler for connection                                      |
//+------------------------------------------------------------------+
void OnConnected()
{
   Print("Connected to TradingView");
   
   // Authenticate with email and password
   Print("Attempting to authenticate with email: ", g_email);
   bool authSuccess = g_api.Authenticate(g_email, g_password);
   
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
      
      // Also save to a more readable format
      fileHandle = FileOpen("TradingView_Session_Readable.txt", FILE_WRITE|FILE_TXT);
      if(fileHandle != INVALID_HANDLE) {
         FileWrite(fileHandle, "TradingView Session Information");
         FileWrite(fileHandle, "=============================");
         FileWrite(fileHandle, "Session ID: " + sessionId);
         FileWrite(fileHandle, "Signature: " + signature);
         FileWrite(fileHandle, "=============================");
         FileWrite(fileHandle, "Save this information for future use.");
         FileClose(fileHandle);
         Print("Session information saved to TradingView_Session_Readable.txt");
      } else {
         Print("Failed to save readable session information to file. Error: ", GetLastError());
      }
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
} 