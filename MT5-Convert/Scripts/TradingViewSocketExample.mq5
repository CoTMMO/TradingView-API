//+------------------------------------------------------------------+
//|                                      TradingViewSocketExample.mq5   |
//|                                  Copyright 2024, MetaQuotes Ltd.   |
//|                                             https://www.mql5.com   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Example of using official MQL5 socket functions for TradingView API"
#property script_show_inputs

// Input parameters
input string Server = "data.tradingview.com";  // TradingView server
input int    Port   = 443;                     // Port (443 for TLS, 80 for non-TLS)
input bool   UseTLS = true;                    // Use TLS connection
input string Symbol = "EURUSD";                // Symbol to request
input int    Timeout = 10000;                  // Connection timeout in milliseconds

// Global variables
int socket = INVALID_HANDLE;
bool isConnected = false;

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
   
   // Create socket
   socket = SocketCreate();
   if(socket == INVALID_HANDLE) {
      Print("Failed to create socket, error ", GetLastError());
      return;
   }
   
   // Connect to server
   Print("Attempting to connect to ", Server, ":", Port);
   if(!SocketConnect(socket, Server, Port, Timeout)) {
      int error = GetLastError();
      Print("Connection failed, error code: ", error);
      
      // Handle specific error codes
      if(error == ERR_NETWORK_OPERATIONS_NOT_ALLOWED) {
         Print("Network operations are not allowed in testing mode.");
         Print("Please run this script on a live chart, not in the Strategy Tester.");
      }
      else if(error == ERR_TLS_HANDSHAKE_FAILED) {
         Print("TLS handshake error (", ERR_TLS_HANDSHAKE_FAILED, "). This could be due to:");
         Print("1. Outdated SSL/TLS libraries in your MetaTrader 5 installation");
         Print("2. Network restrictions or firewall settings blocking secure connections");
         Print("3. Issues with the TradingView server's SSL certificate");
         Print("4. Proxy or VPN interference with the connection");
         Print("5. Time synchronization issues on your system");
         Print("Please try updating MetaTrader 5 to the latest version or check your network settings.");
      }
      else if(error == ERR_SOCKET_CONNECT_FAILED) {
         Print("Could not connect to server. Please check your internet connection.");
      }
      else if(error == ERR_SERVER_BUSY) {
         Print("Server is busy. Please try again later.");
      }
      else {
         Print("Unknown connection error: ", error);
      }
      
      SocketClose(socket);
      socket = INVALID_HANDLE;
      return;
   }
   
   // Connection successful
   isConnected = true;
   Print("Successfully connected to TradingView");
   
   // If using TLS, perform TLS handshake
   if(UseTLS) {
      string subject, issuer, serial, thumbprint;
      datetime expiration;
      
      if(SocketTlsCertificate(socket, subject, issuer, serial, thumbprint, expiration)) {
         Print("TLS certificate:");
         Print("   Owner:  ", subject);
         Print("   Issuer:  ", issuer);
         Print("   Number:  ", serial);
         Print("   Print:   ", thumbprint);
         Print("   Expiration: ", expiration);
      } else {
         Print("Failed to get TLS certificate, error ", GetLastError());
      }
   }
   
   // Send WebSocket handshake request
   string handshake = "GET /socket.io/websocket?type=chart HTTP/1.1\r\n";
   handshake += "Host: " + Server + "\r\n";
   handshake += "Upgrade: websocket\r\n";
   handshake += "Connection: Upgrade\r\n";
   handshake += "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n";
   handshake += "Sec-WebSocket-Version: 13\r\n";
   handshake += "User-Agent: MT5\r\n";
   handshake += "\r\n";
   
   if(!SendRequest(handshake)) {
      Print("Failed to send WebSocket handshake");
      SocketClose(socket);
      socket = INVALID_HANDLE;
      isConnected = false;
      return;
   }
   
   // Receive WebSocket handshake response
   string response;
   if(!ReceiveResponse(response, 5000)) {
      Print("Failed to receive WebSocket handshake response");
      SocketClose(socket);
      socket = INVALID_HANDLE;
      isConnected = false;
      return;
   }
   
   Print("WebSocket handshake response:");
   Print(response);
   
   // Send subscription request for symbol
   string subscribeRequest = "42[\"quote_add_symbols\",\"" + Symbol + "\"]";
   if(!SendRequest(subscribeRequest)) {
      Print("Failed to send subscription request");
      SocketClose(socket);
      socket = INVALID_HANDLE;
      isConnected = false;
      return;
   }
   
   // Receive subscription response
   if(!ReceiveResponse(response, 5000)) {
      Print("Failed to receive subscription response");
      SocketClose(socket);
      socket = INVALID_HANDLE;
      isConnected = false;
      return;
   }
   
   Print("Subscription response:");
   Print(response);
   
   // Close socket
   SocketClose(socket);
   socket = INVALID_HANDLE;
   isConnected = false;
   
   Print("Socket closed");
}

//+------------------------------------------------------------------+
//| Send request to the server                                        |
//+------------------------------------------------------------------+
bool SendRequest(string request)
{
   if(!isConnected || socket == INVALID_HANDLE) {
      Print("Cannot send request: Not connected");
      return false;
   }
   
   char req[];
   int len = StringToCharArray(request, req) - 1;
   if(len < 0) {
      Print("Failed to convert request to char array");
      return false;
   }
   
   // Send data based on connection type
   if(UseTLS) {
      if(SocketTlsSend(socket, req, len) != len) {
         Print("Failed to send TLS request, error ", GetLastError());
         return false;
      }
   } else {
      if(SocketSend(socket, req, len) != len) {
         Print("Failed to send request, error ", GetLastError());
         return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Receive response from the server                                  |
//+------------------------------------------------------------------+
bool ReceiveResponse(string &response, uint timeout)
{
   if(!isConnected || socket == INVALID_HANDLE) {
      Print("Cannot receive response: Not connected");
      return false;
   }
   
   char rsp[];
   response = "";
   uint timeout_check = GetTickCount() + timeout;
   
   // Read data from socket until timeout
   do {
      uint len = SocketIsReadable(socket);
      if(len > 0) {
         int rsp_len;
         
         // Read data based on connection type
         if(UseTLS) {
            rsp_len = SocketTlsRead(socket, rsp, len);
         } else {
            rsp_len = SocketRead(socket, rsp, len, timeout);
         }
         
         // Process response
         if(rsp_len > 0) {
            response += CharArrayToString(rsp, 0, rsp_len);
            return true;
         }
      }
   } while(GetTickCount() < timeout_check && !IsStopped());
   
   return false;
} 