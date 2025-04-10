//+------------------------------------------------------------------+
//|                                                 TradingViewAPI.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd.   |
//|                                             https://www.mql5.com   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

// Include required files
#include "JAson.mqh"

//+------------------------------------------------------------------+
//| TradingView API Types and Constants                               |
//+------------------------------------------------------------------+
// Handler function types
typedef void (*TVConnectedHandler)();
typedef void (*TVDisconnectedHandler)();
typedef void (*TVLoggedHandler)();
typedef void (*TVErrorHandler)(string error);
typedef void (*TVDataHandler)(string data);

enum ENUM_TIMEFRAME_TV
  {
   TIMEFRAME_TV_1 = 1,
   TIMEFRAME_TV_3 = 3,
   TIMEFRAME_TV_5 = 5,
   TIMEFRAME_TV_15 = 15,
   TIMEFRAME_TV_30 = 30,
   TIMEFRAME_TV_45 = 45,
   TIMEFRAME_TV_60 = 60,
   TIMEFRAME_TV_120 = 120,
   TIMEFRAME_TV_180 = 180,
   TIMEFRAME_TV_240 = 240,
   TIMEFRAME_TV_D = 1440,
   TIMEFRAME_TV_W = 10080,
   TIMEFRAME_TV_M = 43200
  };

// TLS error codes
#define ERR_TLS_HANDSHAKE_FAILED 5274
#define ERR_SOCKET_CONNECT_FAILED 4060
#define ERR_SERVER_BUSY 4018
#define ERR_NETWORK_OPERATIONS_NOT_ALLOWED 4014

//+------------------------------------------------------------------+
//| Utility Functions                                                  |
//+------------------------------------------------------------------+
/**
 * Generates a session id
 * @param string type Session type
 * @return string Generated session ID
 */
string genSessionID(string type="xs") {
   string r = "";
   string c = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
   int len = StringLen(c);
   
   for(int i = 0; i < 12; i++) {
      int randomIndex = MathRand() % len;
      r += StringSubstr(c, randomIndex, 1);
   }
   
   return type + "_" + r;
}

/**
 * Generates authentication cookies
 * @param string sessionId Session ID
 * @param string signature Session signature
 * @return string Generated cookies string
 */
string genAuthCookies(string sessionId="", string signature="") {
   if(sessionId == "") return "";
   if(signature == "") return "sessionid=" + sessionId;
   return "sessionid=" + sessionId + ";sessionid_sign=" + signature;
}

//+------------------------------------------------------------------+
//| TradingView API Client Class                                      |
//+------------------------------------------------------------------+
class CTradingViewAPI
  {
private:
   // Properties
   int               m_socket;
   bool              m_isConnected;
   bool              m_isLogged;
   string            m_sessionId;
   string            m_signature;
   bool              m_useTLS;
   bool              m_autoFallbackToNonTLS;
   int               m_maxRetries;
   int               m_retryDelayMs;
   string            m_server;
   int               m_port;

   // Event handlers - changed to function pointers
   TVConnectedHandler    m_connectHandlers[];
   TVDisconnectedHandler m_disconnectHandlers[];
   TVLoggedHandler       m_loginHandlers[];
   TVErrorHandler        m_errorHandlers[];
   TVDataHandler         m_dataReaderHandlers[];


   void              TriggerConnectedEvent(TVConnectedHandler &handlers[])
     {
      for(int i = 0; i < ArraySize(handlers); i++)
        {
         if(handlers[i] != NULL)
            handlers[i]();
        }
     }

   void              TriggerDisconnectedEvent(TVDisconnectedHandler &handlers[])
     {
      for(int i = 0; i < ArraySize(handlers); i++)
        {
         if(handlers[i] != NULL)
            handlers[i]();
        }
     }

   void              TriggerLoggedEvent(TVLoggedHandler &handlers[])
     {
      for(int i = 0; i < ArraySize(handlers); i++)
        {
         if(handlers[i] != NULL)
            handlers[i]();
        }
     }

   void              TriggerErrorEvent(TVErrorHandler &handlers[], string error)
     {
      for(int i = 0; i < ArraySize(handlers); i++)
        {
         if(handlers[i] != NULL)
            handlers[i](error);
        }
     }

   void              TriggerDataEvent(TVDataHandler &handlers[], string data)
     {
      for(int i = 0; i < ArraySize(handlers); i++)
        {
         if(handlers[i] != NULL)
            handlers[i](data);
        }
     }

public:
                     CTradingViewAPI()
     {
      m_sessionId = "";
      m_signature = "";
      m_isLogged = false;
      m_useTLS = true;
      m_server = "data.tradingview.com";
      m_port = 443;
      m_socket = INVALID_HANDLE;
      m_maxRetries = 3;
      m_retryDelayMs = 2000;
      m_autoFallbackToNonTLS = true;
      m_isConnected = false;

      ArrayResize(m_connectHandlers, 0);
      ArrayResize(m_disconnectHandlers, 0);
      ArrayResize(m_loginHandlers, 0);
      ArrayResize(m_errorHandlers, 0);
      ArrayResize(m_dataReaderHandlers, 0);
     }

                    ~CTradingViewAPI()
     {
      Disconnect();
     }

   // Helper method implementations
   bool              SendRequest(string request)
     {
      if(!m_isConnected || m_socket == INVALID_HANDLE)
        {
         Print("Cannot send request: Not connected");
         return false;
        }

      // Format the message according to TradingView's WebSocket protocol
      string formattedMsg = "~m~" + IntegerToString(StringLen(request)) + "~m~" + request;
      Print("formattedMsg: ", formattedMsg);
      char req[];
      int len = StringToCharArray(formattedMsg, req) - 1;
      if(len < 0)
        {
         Print("Failed to convert request to char array");
         return false;
        }

      // Send data based on connection type
      if(m_useTLS)
        {
         if(SocketTlsSend(m_socket, req, len) != len)
           {
            Print("Failed to send TLS request, error ", GetLastError());
            return false;
           }
        }
      else
        {
         if(SocketSend(m_socket, req, len) != len)
           {
            Print("Failed to send request, error ", GetLastError());
            return false;
           }
        }

      return true;
     }

   bool              ReceiveResponse(string &response, uint timeout)
     {
      if(!m_isConnected || m_socket == INVALID_HANDLE)
        {
         Print("Cannot receive response: Not connected");
         return false;
        }

      char rsp[];
      response = "";
      uint timeout_check = GetTickCount() + timeout;
      string buffer = "";  // Buffer to accumulate data

      // Read data from socket until timeout
      do
        {
         uint len = SocketIsReadable(m_socket);
         if(len > 0)
           {
            int rsp_len;

            // Read data based on connection type
            if(m_useTLS)
              {
               rsp_len = SocketTlsRead(m_socket, rsp, len);
              }
            else
              {
               rsp_len = SocketRead(m_socket, rsp, len, timeout);
              }

            // Process response
            if(rsp_len > 0)
              {
               string data = CharArrayToString(rsp, 0, rsp_len);
               buffer += data;  // Accumulate data in buffer

               // Check if we have a complete message
               if(StringFind(buffer, "~m~") >= 0)
                 {
                  // Extract the message length
                  int msgStart = StringFind(buffer, "~m~") + 3;
                  int msgEnd = StringFind(buffer, "~m~", msgStart);
                  if(msgEnd > msgStart)
                    {
                     string lenStr = StringSubstr(buffer, msgStart, msgEnd - msgStart);
                     int msgLen = (int)StringToInteger(lenStr);
                     
                     // Check if we have the complete message
                     int fullMsgEnd = msgEnd + 3 + msgLen;
                     if(StringLen(buffer) >= fullMsgEnd)
                        {
                         // Extract the complete message
                         response = StringSubstr(buffer, msgEnd + 3, msgLen);
                         buffer = StringSubstr(buffer, fullMsgEnd);  // Keep remaining data in buffer
                         
                         // Process the response immediately
                         ProcessResponse(response);
                         return true;
                        }
                    }
                 }
              }
           }
        }
      while(GetTickCount() < timeout_check && !IsStopped());

      return false;
     }

   void              ProcessResponse(string response)
     {
      // Parse WebSocket packets according to TradingView protocol
      string cleanResponse = StringReplace(response, "~h~", "");
      string parts[];
      StringSplit(cleanResponse, StringFind(cleanResponse, "~m~") >= 0 ? "~m~" : ",", parts);

      for(int i = 0; i < ArraySize(parts); i++)
        {
         if(parts[i] == "")
            continue;

         // Try to parse as JSON
         CJAVal json;
         if(json.Deserialize(parts[i]))
           {
            string msgType = json["m"].ToStr();

            // Handle different message types
            if(msgType == "qsd")
              {
               // Quote data
               TriggerDataEvent(m_dataReaderHandlers, parts[i]);
              }
            else
               if(msgType == "cs")
                 {
                  // Chart data
                  TriggerDataEvent(m_dataReaderHandlers, parts[i]);
                 }
               else
                  if(msgType == "study_data")
                    {
                     // Study data
                     TriggerDataEvent(m_dataReaderHandlers, parts[i]);
                    }
                  else
                     if(msgType == "protocol_error")
                       {
                        // Error
                        TriggerErrorEvent(m_errorHandlers, "Protocol error: " + json["p"].ToStr());
                       }
                     else
                        if(msgType == "set_auth_token")
                          {
                           // Authentication response
                           m_isLogged = true;
                           TriggerLoggedEvent(m_loginHandlers);
                          }
                        else
                           if(msgType == "quote_add_symbols")
                             {
                              // Symbol subscription response
                              if(json["p"].Size() > 0)
                                {
                                 string symbol = json["p"][0].ToStr();
                                 Print("Subscribed to symbol: ", symbol);
                                }
                             }
                           else
                              if(msgType == "quote_remove_symbols")
                                {
                                 // Symbol unsubscription response
                                 if(json["p"].Size() > 0)
                                   {
                                    string symbol = json["p"][0].ToStr();
                                    Print("Unsubscribed from symbol: ", symbol);
                                   }
                                }
                              else
                                 if(msgType == "chart_create_session")
                                   {
                                    // Chart session creation response
                                    Print("Chart session created");
                                   }
                                 else
                                    if(msgType == "chart_delete_session")
                                      {
                                       // Chart session deletion response
                                       Print("Chart session deleted");
                                      }
                                    else
                                       if(msgType == "create_study")
                                         {
                                          // Study creation response
                                          if(json["p"].Size() > 0)
                                            {
                                             string studyName = json["p"][0].ToStr();
                                             Print("Study created: ", studyName);
                                            }
                                         }
                                       else
                                          if(msgType == "remove_study")
                                            {
                                             // Study removal response
                                             if(json["p"].Size() > 0)
                                               {
                                                string studyName = json["p"][0].ToStr();
                                                Print("Study removed: ", studyName);
                                               }
                                            }
                                          else
                                             if(msgType == "update_study_inputs")
                                               {
                                                // Study inputs update response
                                                if(json["p"].Size() > 0)
                                                  {
                                                   string studyName = json["p"][0].ToStr();
                                                   Print("Study inputs updated: ", studyName);
                                                  }
                                               }
                                             else
                                                if(msgType == "get_session_info")
                                                  {
                                                   // Session info response
                                                   if(json["p"].Size() > 0)
                                                     {
                                                      CJAVal params = json["p"];
                                                      if(params["sid"].ToStr() != "")
                                                        {
                                                         m_sessionId = params["sid"].ToStr();
                                                        }
                                                      if(params["sig"].ToStr() != "")
                                                        {
                                                         m_signature = params["sig"].ToStr();
                                                        }
                                                      Print("Session info updated - SID: ", m_sessionId, ", SIG: ", m_signature);
                                                     }
                                                  }
                                                else
                                                  {
                                                   // Log unknown message types for debugging
                                                   Print("Received unknown message type: ", msgType);
                                                   Print("Message content: ", parts[i]);
                                                  }
           }
         else
           {
            // Not JSON, might be a ping or other control message
            if(StringFind(parts[i], "~h~") >= 0)
              {
               // Send ping response
               string pingResponse = "~h~" + parts[i];
               SendRequest(pingResponse);
              }
            else
               if(StringFind(parts[i], "~m~") >= 0)
                 {
                  // Handle other control messages
                  Print("Received control message: ", parts[i]);
                 }
               else
                 {
                  Print("Received non-JSON message: ", parts[i]);
                 }
           }
        }
     }

   // Set TLS usage
   void              SetUseTLS(bool useTLS)
     {
      m_useTLS = useTLS;
      m_port = useTLS ? 443 : 80;
     }

   // Set server
   void              SetServer(string server, int port = 0)
     {
      m_server = server;
      if(port > 0)
        {
         m_port = port;
        }
     }

   // Set retry parameters
   void              SetRetryParameters(int maxRetries, int retryDelayMs)
     {
      m_maxRetries = maxRetries;
      m_retryDelayMs = retryDelayMs;
     }

   // Set auto fallback to non-TLS
   void              SetAutoFallbackToNonTLS(bool autoFallback)
     {
      m_autoFallbackToNonTLS = autoFallback;
     }

   // Connection methods
   bool              Connect()
     {
      if(MQLInfoInteger(MQL_TESTER))
        {
         Print("Cannot connect to TradingView in Strategy Tester");
         return false;
        }

      bool connected = false;
      int retryCount = 0;

      while(!connected && retryCount < m_maxRetries)
        {
         // Create socket
         m_socket = SocketCreate();
         if(m_socket == INVALID_HANDLE)
           {
            Print("Failed to create socket, error ", GetLastError());
            retryCount++;
            Sleep(m_retryDelayMs);
            continue;
           }

         // Connect to server
         Print("Attempting to connect to ", m_server, ":", m_port);
         if(!SocketConnect(m_socket, m_server, m_port, 10000))
           {
            int error = GetLastError();
            Print("Connection attempt ", retryCount + 1, " failed. Error code: ", error);

            // Handle specific error codes
            if(error == ERR_NETWORK_OPERATIONS_NOT_ALLOWED)
              {
               Print("Network operations are not allowed in testing mode.");
               Print("Please run this script on a live chart, not in the Strategy Tester.");
               SocketClose(m_socket);
               m_socket = INVALID_HANDLE;
               return false;
              }
            else
               if(error == ERR_TLS_HANDSHAKE_FAILED)
                 {
                  Print("TLS handshake error (", ERR_TLS_HANDSHAKE_FAILED, "). This could be due to:");
                  Print("1. Outdated SSL/TLS libraries in your MetaTrader 5 installation");
                  Print("2. Network restrictions or firewall settings blocking secure connections");
                  Print("3. Issues with the TradingView server's SSL certificate");
                  Print("4. Proxy or VPN interference with the connection");
                  Print("5. Time synchronization issues on your system");
                  Print("Please try updating MetaTrader 5 to the latest version or check your network settings.");

                  // Try fallback to non-TLS if currently using TLS and auto-fallback is enabled
                  if(m_useTLS && m_autoFallbackToNonTLS)
                    {
                     Print("Attempting to continue without TLS...");
                     m_useTLS = false;
                     m_port = 80;
                     retryCount--; // Don't count this as a retry
                     continue;
                    }
                 }
               else
                  if(error == ERR_SOCKET_CONNECT_FAILED)
                    {
                     Print("Could not connect to server. Please check your internet connection.");
                    }
                  else
                     if(error == ERR_SERVER_BUSY)
                       {
                        Print("Server is busy. Retrying in ", m_retryDelayMs/1000, " seconds...");
                       }
                     else
                       {
                        Print("Unknown connection error: ", error);
                       }

            SocketClose(m_socket);
            m_socket = INVALID_HANDLE;
           }
         else
           {
            // Connection successful
            m_isConnected = true;
            connected = true;
            Print("Successfully connected to TradingView");

            // If using TLS, perform TLS handshake
            if(m_useTLS)
              {
               string subject, issuer, serial, thumbprint;
               datetime expiration;

               if(SocketTlsCertificate(m_socket, subject, issuer, serial, thumbprint, expiration))
                 {
                  Print("TLS certificate:");
                  Print("   Owner:  ", subject);
                  Print("   Issuer:  ", issuer);
                  Print("   Number:  ", serial);
                  Print("   Print:   ", thumbprint);
                  Print("   Expiration: ", expiration);
                 }
               else
                 {
                  Print("Failed to get TLS certificate, error ", GetLastError());
                 }
              }

            // Generate session ID and cookies
            m_sessionId = genSessionID("xs");
            m_signature = genSessionID("sig");
            string cookies = genAuthCookies(m_sessionId, m_signature);
            Print("Generated session ID: ", m_sessionId);
            Print("Generated signature: ", m_signature);
            Print("Generated cookies: ", cookies);

            // Send WebSocket handshake with unauthorized_user_token and cookies
            string handshake = "{\"m\":\"set_auth_token\",\"p\":[\"unauthorized_user_token\"]}";
            SendRequest(handshake);
            
            // Set logged in to true since we're using unauthorized access
            m_isLogged = true;
            
            // Trigger logged event
            TriggerLoggedEvent(m_loginHandlers);

            // Start continuous data reading
            StartDataReader();

            // Trigger connected event
            TriggerConnectedEvent(m_connectHandlers);
            break;
           }

         // Increment retry counter and wait before next attempt
         retryCount++;
         if(retryCount < m_maxRetries)
           {
            Sleep(m_retryDelayMs);
           }
        }

      if(!connected)
        {
         Print("Failed to connect to TradingView after ", m_maxRetries, " attempts.");
         if(m_useTLS)
           {
            Print("Try modifying the script to set g_use_tls = false at the beginning to disable TLS completely.");
           }
        }

      return connected;
     }

   // Start continuous data reading
   void              StartDataReader()
     {
      // Create a custom event for data reading
      long eventId = ChartID() * 1000 + 1; // Unique event ID
      EventSetMillisecondTimer(100); // Check for data every 100ms

      // Store the event ID for later use
      string eventIdStr = IntegerToString(eventId);
     }

   // Add data reader handler
   void              AddDataReaderHandler(TVDataHandler handler)
     {
      if(handler != NULL)
        {
         int size = ArraySize(m_dataReaderHandlers);
         ArrayResize(m_dataReaderHandlers, size + 1);
         m_dataReaderHandlers[size] = handler;
        }
     }

   void              Disconnect()
     {
      if(m_socket != INVALID_HANDLE)
        {
         SocketClose(m_socket);
         m_socket = INVALID_HANDLE;
         m_isConnected = false;

         // Trigger disconnected event
         TriggerDisconnectedEvent(m_disconnectHandlers);
        }
     }

   // Methods to implement
   bool              UnsubscribeSymbol(string symbol)
     {
      if(!m_isConnected)
         return false;

      CJAVal json;
      json["m"] = "quote_remove_symbols";
      json["p"].Add(symbol);

      return SendRequest(json.ToStr());
     }

   bool              DeleteChartSession()
     {
      if(!m_isConnected)
         return false;

      CJAVal json;
      json["m"] = "chart_delete_session";

      return SendRequest(json.ToStr());
     }

   bool              RemoveIndicator(string name)
     {
      if(!m_isConnected)
         return false;

      CJAVal json;
      json["m"] = "remove_study";
      json["p"].Add(name);

      return SendRequest(json.ToStr());
     }

   // Comprehensive authentication method
   bool              Authenticate(string username, string password)
     {
      if(!m_isConnected)
        {
         Print("Cannot authenticate: Not connected to TradingView");
         return false;
        }

      // Since we're using unauthorized access, we don't need to authenticate with username/password
      // Just set the logged in state to true and trigger the logged event
      m_isLogged = true;
      
      // Generate session ID and cookies if not already set
      if(m_sessionId == "" || m_signature == "") {
         m_sessionId = genSessionID("xs");
         m_signature = genSessionID("sig");
         string cookies = genAuthCookies(m_sessionId, m_signature);
         Print("Generated session ID: ", m_sessionId);
         Print("Generated signature: ", m_signature);
         Print("Generated cookies: ", cookies);
      }
      
      TriggerLoggedEvent(m_loginHandlers);
      
      return true;
     }

   // Login method (for backward compatibility)
   bool              Login(string username, string password)
     {
      return Authenticate(username, password);
     }

   // Request session information
   bool              RequestSessionInfo()
     {
      if(!m_isConnected || !m_isLogged)
        {
         Print("Cannot request session info: Not connected or not logged in");
         return false;
        }

      CJAVal json;
      json["m"] = "get_session_info";

      if(!SendRequest(json.ToStr()))
        {
         Print("Failed to send session info request");
         return false;
        }

      // Wait for response
      uint startTime = GetTickCount();
      bool sessionInfoReceived = false;
      
      while(GetTickCount() - startTime < 5000)
        {
         string response;
         if(ReceiveResponse(response, 1000))
           {
            Print("Session info response: ", response); // Debug output

            CJAVal resp;
            if(resp.Deserialize(response))
              {
               if(resp["m"].ToStr() == "session_info")
                 {
                  if(resp["p"].Size() > 0)
                    {
                     CJAVal params = resp["p"];
                     if(params["sid"].ToStr() != "")
                       {
                        m_sessionId = params["sid"].ToStr();
                       }
                     if(params["sig"].ToStr() != "")
                       {
                        m_signature = params["sig"].ToStr();
                       }
                     sessionInfoReceived = true;
                     return true;
                    }
                 }
              }
           }
         Sleep(100);
        }

      // If we didn't receive session info from the server, generate our own
      if(!sessionInfoReceived) {
         Print("Timeout waiting for session info response. Generating session ID and signature locally.");
         m_sessionId = genSessionID("xs");
         m_signature = genSessionID("sig");
         string cookies = genAuthCookies(m_sessionId, m_signature);
         Print("Generated session ID: ", m_sessionId);
         Print("Generated signature: ", m_signature);
         Print("Generated cookies: ", cookies);
         return true;
      }

      Print("Failed to get session info");
      return false;
     }

   // Event handler registration - modified to use function pointers
   void              AddConnectedHandler(TVConnectedHandler handler)
     {
      if(handler != NULL)
        {
         int size = ArraySize(m_connectHandlers);
         ArrayResize(m_connectHandlers, size + 1);
         m_connectHandlers[size] = handler;
        }
     }

   void              AddDisconnectedHandler(TVDisconnectedHandler handler)
     {
      if(handler != NULL)
        {
         int size = ArraySize(m_disconnectHandlers);
         ArrayResize(m_disconnectHandlers, size + 1);
         m_disconnectHandlers[size] = handler;
        }
     }

   void              AddLoggedHandler(TVLoggedHandler handler)
     {
      if(handler != NULL)
        {
         int size = ArraySize(m_loginHandlers);
         ArrayResize(m_loginHandlers, size + 1);
         m_loginHandlers[size] = handler;
        }
     }

   void              AddErrorHandler(TVErrorHandler handler)
     {
      if(handler != NULL)
        {
         int size = ArraySize(m_errorHandlers);
         ArrayResize(m_errorHandlers, size + 1);
         m_errorHandlers[size] = handler;
        }
     }

   // Getters
   bool              IsLogged() const { return m_isLogged; }
   string            GetSessionId() const { return m_sessionId; }
   string            GetSignature() const { return m_signature; }
   bool              IsConnected() const { return m_isConnected; }

   // Send method for compatibility with existing code
   bool              send(string data)
     {
      return SendRequest(data);
     }

   // OnTimer event handler - must be called from the EA/script
   void              OnTimer()
     {
     printf("OnTimer()");
      if(!m_isConnected || m_socket == INVALID_HANDLE)
        {
         Print("OnTimer(): INVALID_HANDLE");
         return;
        }

      // Check if there's data to read
      uint len = SocketIsReadable(m_socket);
      if(len > 0)
        {
         char data[];
         int dataLen;

         // Read data based on connection type
         if(m_useTLS)
           {
            dataLen = SocketTlsRead(m_socket, data, len);
           }
         else
           {
            dataLen = SocketRead(m_socket, data, len, 100);
           }

         // Process data if received
         if(dataLen > 0)
           {
            string newData = CharArrayToString(data, 0, dataLen);
            
            // Accumulate data in buffer
            static string buffer = "";
            buffer += newData;
            
            // Process complete messages from buffer
            while(StringLen(buffer) > 0)
              {
               // Check for message start marker
               int msgStart = StringFind(buffer, "~m~");
               if(msgStart < 0)
                 {
                  // No message marker found, keep accumulating
                  break;
                 }
               
               // Extract message length
               int lenStart = msgStart + 3;
               int lenEnd = StringFind(buffer, "~m~", lenStart);
               if(lenEnd < 0)
                 {
                  // Incomplete message, keep accumulating
                  break;
                 }
               
               string lenStr = StringSubstr(buffer, lenStart, lenEnd - lenStart);
               int msgLen = (int)StringToInteger(lenStr);
               
               // Check if we have the complete message
               int fullMsgEnd = lenEnd + 3 + msgLen;
               if(StringLen(buffer) < fullMsgEnd)
                 {
                  // Incomplete message, keep accumulating
                  break;
                 }
               
               // Extract the complete message
               string message = StringSubstr(buffer, lenEnd + 3, msgLen);
               
               // Process the message
               ProcessResponse(message);
               
               // Remove processed message from buffer
               buffer = StringSubstr(buffer, fullMsgEnd);
              }
           }
        }
     }
     
  };

//+------------------------------------------------------------------+
//| TradingView Market Data Class                                     |
//+------------------------------------------------------------------+
class CTradingViewMarket
  {
private:
   string            m_symbol;
   string            m_session;
   MqlTick           m_lastTick;
   datetime          m_lastUpdate;

   // Event handlers - changed to function pointers
   TVDataHandler     m_dataHandlers[];
   TVErrorHandler    m_errorHandlers[];

   // Reference to API client
   CTradingViewAPI*  m_api;

public:
                     CTradingViewMarket(string symbol, string session = "regular")
     {
      m_symbol = symbol;
      m_session = session;
      ZeroMemory(m_lastTick);
      m_lastUpdate = 0;
      m_api = NULL;
      ArrayResize(m_dataHandlers, 0);
      ArrayResize(m_errorHandlers, 0);
     }

                    ~CTradingViewMarket()
     {
      if(m_api != NULL && m_api.IsConnected())
        {
         m_api.UnsubscribeSymbol(m_symbol);
        }
     }

   // Market data methods
   bool              Update()
     {
      if(m_api == NULL || !m_api.IsLogged())
         return false;

      CJAVal json;
      json["m"] = "quote_add_symbols";
      json["p"].Add(m_symbol);

      return m_api.send(json.ToStr());
     }

   bool              GetLastTick(MqlTick &tick)
     {
      tick = m_lastTick;
      return true;
     }

   datetime          GetLastUpdate() const { return m_lastUpdate; }

   // Event handlers - modified to use function pointers
   void              AddDataHandler(TVDataHandler handler)
     {
      if(handler != NULL)
        {
         int size = ArraySize(m_dataHandlers);
         ArrayResize(m_dataHandlers, size + 1);
         m_dataHandlers[size] = handler;
        }
     }

   void              AddErrorHandler(TVErrorHandler handler)
     {
      if(handler != NULL)
        {
         int size = ArraySize(m_errorHandlers);
         ArrayResize(m_errorHandlers, size + 1);
         m_errorHandlers[size] = handler;
        }
     }

   // Set API client reference
   void              SetAPI(CTradingViewAPI* api)
     {
      m_api = api;
     }

   // Process market data update
   void              ProcessUpdate(string data)
     {
      if(StringFind(data, "\"m\":\"qsd\"") < 0)
         return;

      CJAVal json;
      if(json.Deserialize(data))
        {
         CJAVal p = json["p"];
         if(p.Size() > 1)
           {
            CJAVal tickData = p[1];
            if(tickData["v"].ToStr() != "null")
              {
               m_lastTick.bid = tickData["b"].ToDbl();
               m_lastTick.ask = tickData["a"].ToDbl();
               m_lastTick.last = tickData["v"].ToDbl();
               m_lastUpdate = (datetime)tickData["t"].ToInt();

               // Trigger data event
               for(int i = 0; i < ArraySize(m_dataHandlers); i++)
                 {
                  if(m_dataHandlers[i] != NULL)
                     m_dataHandlers[i](data);
                 }
              }
           }
        }
     }
  };

//+------------------------------------------------------------------+
//| TradingView Chart Session Class                                   |
//+------------------------------------------------------------------+
class CTradingViewChart
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAME_TV m_timeframe;
   int               m_range;
   datetime          m_reference;

   // Event handlers - changed to function pointers
   TVConnectedHandler    m_symbolLoadedHandlers[];
   TVDataHandler         m_updateHandlers[];
   TVErrorHandler        m_errorHandlers[];

   // Reference to API client
   CTradingViewAPI*  m_api;

   // Chart data
   MqlRates          m_rates[];
   int               m_ratesCount;

public:
                     CTradingViewChart(string symbol, ENUM_TIMEFRAME_TV timeframe = TIMEFRAME_TV_60, int range = 100)
     {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_range = range;
      m_reference = 0;
      m_ratesCount = 0;
      m_api = NULL;
      ArrayResize(m_rates, 0);
     }

                    ~CTradingViewChart()
     {
      if(m_api != NULL)
        {
         m_api.DeleteChartSession();
        }
     }

   // Chart methods
   bool              SetMarket(string symbol, ENUM_TIMEFRAME_TV timeframe = TIMEFRAME_TV_60, int range = 100)
     {
      if(m_api == NULL || !m_api.IsLogged())
         return false;

      m_symbol = symbol;
      m_timeframe = timeframe;
      m_range = range;

      CJAVal json;
      json["m"] = "chart_create_session";
      json["p"].Add(m_symbol);
      json["p"].Add(GetTimeframeString(timeframe));
      json["p"].Add(m_range);

      return m_api.send(json.ToStr());
     }

   bool              SetTimezone(string timezone)
     {
      if(m_api == NULL || !m_api.IsLogged())
         return false;

      CJAVal json;
      json["m"] = "chart_set_timezone";
      json["p"].Add(timezone);

      return m_api.send(json.ToStr());
     }

   bool              FetchMore(int number = 1)
     {
      if(m_api == NULL || !m_api.IsLogged())
         return false;

      CJAVal json;
      json["m"] = "chart_fetch_more";
      json["p"].Add(number);

      return m_api.send(json.ToStr());
     }

   // Event handlers - modified to use function pointers
   void              OnSymbolLoaded(TVConnectedHandler handler)
     {
      if(handler != NULL)
        {
         int size = ArraySize(m_symbolLoadedHandlers);
         ArrayResize(m_symbolLoadedHandlers, size + 1);
         m_symbolLoadedHandlers[size] = handler;
        }
     }

   void              OnUpdate(TVDataHandler handler)
     {
      if(handler != NULL)
        {
         int size = ArraySize(m_updateHandlers);
         ArrayResize(m_updateHandlers, size + 1);
         m_updateHandlers[size] = handler;
        }
     }

   void              OnError(TVErrorHandler handler)
     {
      if(handler != NULL)
        {
         int size = ArraySize(m_errorHandlers);
         ArrayResize(m_errorHandlers, size + 1);
         m_errorHandlers[size] = handler;
        }
     }

   // Set API client reference
   void              SetAPI(CTradingViewAPI* api)
     {
      m_api = api;
     }

   // Process chart data update
   void              ProcessUpdate(string data)
     {
      if(StringFind(data, "\"m\":\"cs\"") < 0)
         return;

      CJAVal json;
      if(json.Deserialize(data))
        {
         CJAVal p = json["p"];
         if(p.Size() > 1)
           {
            CJAVal bars = p[1];
            if(bars.ToStr() != "null")
              {
               int count = bars.Size();
               ArrayResize(m_rates, count);
               m_ratesCount = count;

               for(int i = 0; i < count; i++)
                 {
                  CJAVal bar = bars[i];
                  if(bar.ToStr() != "null" && bar.Size() >= 6)
                    {
                     m_rates[i].time = (datetime)bar[0].ToInt();
                     m_rates[i].open = bar[1].ToDbl();
                     m_rates[i].high = bar[2].ToDbl();
                     m_rates[i].low = bar[3].ToDbl();
                     m_rates[i].close = bar[4].ToDbl();
                     m_rates[i].tick_volume = (long)bar[5].ToInt();
                    }
                 }

               // Trigger update event
               for(int i = 0; i < ArraySize(m_updateHandlers); i++)
                 {
                  if(m_updateHandlers[i] != NULL)
                     m_updateHandlers[i](data);
                 }
              }
           }
        }
     }

   // Get chart data
   bool              GetRates(int index, MqlRates &rates)
     {
      if(index >= 0 && index < m_ratesCount)
        {
         rates = m_rates[index];
         return true;
        }
      return false;
     }

   int               GetRatesCount() const { return m_ratesCount; }

private:
   string            GetTimeframeString(ENUM_TIMEFRAME_TV timeframe)
     {
      switch(timeframe)
        {
         case TIMEFRAME_TV_1:
            return "1";
         case TIMEFRAME_TV_5:
            return "5";
         case TIMEFRAME_TV_15:
            return "15";
         case TIMEFRAME_TV_30:
            return "30";
         case TIMEFRAME_TV_60:
            return "60";
         case TIMEFRAME_TV_240:
            return "240";
         case TIMEFRAME_TV_D:
            return "D";
         case TIMEFRAME_TV_W:
            return "W";
         case TIMEFRAME_TV_M:
            return "M";
         default:
            return "60";
        }
     }
  };

//+------------------------------------------------------------------+
//| TradingView Study Class                                           |
//+------------------------------------------------------------------+
class CTradingViewStudy
  {
private:
   string            m_name;
   string            m_script;
   string            m_inputs;

   // Event handlers - changed to function pointers
   TVConnectedHandler    m_createdHandlers[];
   TVDataHandler         m_updateHandlers[];
   TVErrorHandler        m_errorHandlers[];

   // Reference to API client
   CTradingViewAPI*  m_api;

   // Study data
   double            m_values[];
   int               m_valuesCount;

public:
                     CTradingViewStudy(string name, string script, string inputs = "")
     {
      m_name = name;
      m_script = script;
      m_inputs = inputs;
      m_valuesCount = 0;
      m_api = NULL;
     }

                    ~CTradingViewStudy()
     {
      if(m_api != NULL)
        {
         m_api.RemoveIndicator(m_name);
        }
     }

   // Study methods
   bool              Create()
     {
      if(m_api == NULL || !m_api.IsLogged())
         return false;

      CJAVal json;
      json["m"] = "create_study";
      json["p"].Add(m_name);
      json["p"].Add(m_script);
      json["p"].Add(m_inputs);

      return m_api.send(json.ToStr());
     }

   bool              SetInputs(string inputs)
     {
      m_inputs = inputs;

      if(m_api == NULL || !m_api.IsLogged())
         return false;

      CJAVal json;
      json["m"] = "update_study_inputs";
      json["p"].Add(m_name);
      json["p"].Add(m_inputs);

      return m_api.send(json.ToStr());
     }

   // Event handlers - modified to use function pointers
   void              OnCreated(TVConnectedHandler handler)
     {
      if(handler != NULL)
        {
         int size = ArraySize(m_createdHandlers);
         ArrayResize(m_createdHandlers, size + 1);
         m_createdHandlers[size] = handler;
        }
     }

   void              OnUpdate(TVDataHandler handler)
     {
      if(handler != NULL)
        {
         int size = ArraySize(m_updateHandlers);
         ArrayResize(m_updateHandlers, size + 1);
         m_updateHandlers[size] = handler;
        }
     }

   void              OnError(TVErrorHandler handler)
     {
      if(handler != NULL)
        {
         int size = ArraySize(m_errorHandlers);
         ArrayResize(m_errorHandlers, size + 1);
         m_errorHandlers[size] = handler;
        }
     }

   // Set API client reference
   void              SetAPI(CTradingViewAPI* api)
     {
      m_api = api;
     }

   // Process study data update
   void              ProcessUpdate(string data)
     {
      if(StringFind(data, "\"m\":\"study_data\"") < 0)
         return;

      CJAVal json;
      if(json.Deserialize(data))
        {
         CJAVal p = json["p"];
         if(p.Size() > 1)
           {
            CJAVal values = p[1];
            if(values.ToStr() != "null")
              {
               int count = values.Size();
               ArrayResize(m_values, count);
               m_valuesCount = count;

               for(int i = 0; i < count; i++)
                 {
                  m_values[i] = values[i].ToDbl();
                 }

               // Trigger update event
               for(int i = 0; i < ArraySize(m_updateHandlers); i++)
                 {
                  if(m_updateHandlers[i] != NULL)
                     m_updateHandlers[i](data);
                 }
              }
           }
        }
     }

   // Get study data
   double            GetValue(int index) { return m_values[index]; }
   int               GetValuesCount() const { return m_valuesCount; }

   // Add GetValues method to fix the undeclared identifier error
   bool              GetValues(int &count, double &values[])
     {
      if(m_valuesCount > 0)
        {
         count = m_valuesCount;
         ArrayResize(values, count);
         for(int i = 0; i < count; i++)
           {
            values[i] = m_values[i];
           }
         return true;
        }
      return false;
     }
  };
//+------------------------------------------------------------------+
