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

   // Event handlers
   string            m_connectHandlers[];
   string            m_disconnectHandlers[];
   string            m_loginHandlers[];
   string            m_errorHandlers[];
   string            m_dataReaderHandlers[];

   // Methods
   //bool              SendRequest(string data);
   bool              ReceiveResponse(string &response, int timeout = 1000);
   //void              ProcessResponse(string response);
   //void              TriggerEvent(string &handlers[], string data);
   //void              StartDataReader();
   //void              AddDataReaderHandler(string handler);

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
               response += data;

               // Process the response immediately
               ProcessResponse(data);
               return true;
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
               TriggerEvent(m_loginHandlers, parts[i]);
              }
            else
               if(msgType == "cs")
                 {
                  // Chart data
                  TriggerEvent(m_loginHandlers, parts[i]);
                 }
               else
                  if(msgType == "study_data")
                    {
                     // Study data
                     TriggerEvent(m_loginHandlers, parts[i]);
                    }
                  else
                     if(msgType == "protocol_error")
                       {
                        // Error
                        TriggerEvent(m_errorHandlers, "Protocol error: " + json["p"].ToStr());
                       }
                     else
                        if(msgType == "set_auth_token")
                          {
                           // Authentication response
                           m_isLogged = true;
                           TriggerEvent(m_loginHandlers, parts[i]);
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

   void              TriggerEvent(string &handlers[], string data)
     {
      for(int i = 0; i < ArraySize(handlers); i++)
        {
         if(handlers[i] != "")
           {
            // Use proper event mechanism
            int eventId = StringToInteger(handlers[i]);
            if(eventId > 0)
               EventChartCustom(0, eventId, 0, 0, data);
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

            // Send WebSocket handshake
            string handshake = "{\"m\":\"set_auth_token\",\"p\":[\"unauthorized_user_token\"]}";
            SendRequest(handshake);

            // Start continuous data reading
            StartDataReader();

            // Trigger connected event
            TriggerEvent(m_connectHandlers, "Connected");
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
      int eventId = ChartID() * 1000 + 1; // Unique event ID
      EventSetMillisecondTimer(100); // Check for data every 100ms

      // Store the event ID for later use
      string eventIdStr = IntegerToString(eventId);
      AddDataReaderHandler(eventIdStr);
     }

   // Add data reader handler
   void              AddDataReaderHandler(string handler)
     {
      if(handler != "")
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
         TriggerEvent(m_disconnectHandlers, "Disconnected");
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

      // Step 1: Send login credentials
      CJAVal json;
      json["m"] = "quote_add_symbols";
      json["p"].Add(username);
      json["p"].Add(password);

      if(!SendRequest(json.ToStr()))
        {
         Print("Failed to send authentication request");
         return false;
        }

      // Step 2: Wait for login response and extract session info
      uint startTime = GetTickCount();
      bool authSuccess = false;

      while(GetTickCount() - startTime < 10000)   // Increased timeout for authentication
        {
         string response;
         if(ReceiveResponse(response, 1000))
           {
            Print("Auth response: ", response); // Debug output

            CJAVal resp;
            if(resp.Deserialize(response))
              {
               // Check various response formats for authentication success
               if(resp["s"].ToStr() == "ok")
                 {
                  m_isLogged = true;
                  authSuccess = true;

                  // Extract session ID and signature if available
                  if(resp["p"].Size() > 0)
                    {
                     CJAVal params = resp["p"];
                     if(params.Size() > 0)
                       {
                        m_sessionId = params[0].ToStr();
                       }
                     if(params.Size() > 1)
                       {
                        m_signature = params[1].ToStr();
                       }
                    }
                 }
               else
                  if(resp["m"].ToStr() == "qsd")
                    {
                     if(resp["p"].Size() > 1)
                       {
                        CJAVal params = resp["p"];
                        if(params[1].Size() > 0)
                          {
                           CJAVal data = params[1];
                           if(data["s"].ToStr() == "ok")
                             {
                              m_isLogged = true;
                              authSuccess = true;
                              if(data["sid"].ToStr() != "")
                                {
                                 m_sessionId = data["sid"].ToStr();
                                }
                              if(data["sig"].ToStr() != "")
                                {
                                 m_signature = data["sig"].ToStr();
                                }
                             }
                          }
                       }
                    }
                  else
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
                          }
                       }
              }

            // If we have both session ID and signature, we're done
            if(m_sessionId != "" && m_signature != "")
              {
               break;
              }
           }
         Sleep(100);
        }

      // Step 3: If we don't have session info yet, request it explicitly
      if(authSuccess && (m_sessionId == "" || m_signature == ""))
        {
         Print("Authentication successful but session info missing. Requesting explicitly...");
         RequestSessionInfo();
        }

      return authSuccess;
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
                     return true;
                    }
                 }
              }
           }
         Sleep(100);
        }

      Print("Timeout waiting for session info response");
      return false;
     }

   // Event handler registration
   void              AddConnectedHandler(string handler)
     {
      if(handler != "")
        {
         int size = ArraySize(m_connectHandlers);
         ArrayResize(m_connectHandlers, size + 1);
         m_connectHandlers[size] = handler;
        }
     }

   void              AddDisconnectedHandler(string handler)
     {
      if(handler != "")
        {
         int size = ArraySize(m_disconnectHandlers);
         ArrayResize(m_disconnectHandlers, size + 1);
         m_disconnectHandlers[size] = handler;
        }
     }

   void              AddLoggedHandler(string handler)
     {
      if(handler != "")
        {
         int size = ArraySize(m_loginHandlers);
         ArrayResize(m_loginHandlers, size + 1);
         m_loginHandlers[size] = handler;
        }
     }

   void              AddErrorHandler(string handler)
     {
      if(handler != "")
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
      printf("OnTimer");
      if(!m_isConnected || m_socket == INVALID_HANDLE)
        {
         printf("OnTimer(): INVALID_HANDLE");
         return;
        }

      printf("OnTimer(): Data Recieved");
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
            printf("OnTimer(): dataLen > 0");
            string response = CharArrayToString(data, 0, dataLen);
            ProcessResponse(response);
           }
         else
           {
            printf("OnTimer(): dataLen < 0");
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

   // Event handlers
   string            m_dataHandlers[];
   string            m_errorHandlers[];

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
      if(m_api != NULL)
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

   // Event handlers
   void              AddDataHandler(string handler)
     {
      if(handler != "")
        {
         int size = ArraySize(m_dataHandlers);
         ArrayResize(m_dataHandlers, size + 1);
         m_dataHandlers[size] = handler;
        }
     }

   void              AddErrorHandler(string handler)
     {
      if(handler != "")
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
                  if(m_dataHandlers[i] != "")
                    {
                     int eventId = StringToInteger(m_dataHandlers[i]);
                     if(eventId > 0)
                        EventChartCustom(0, eventId, 0, 0, data);
                    }
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

   // Event handlers
   string            m_symbolLoadedHandlers[];
   string            m_updateHandlers[];
   string            m_errorHandlers[];

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

   // Event handlers
   void              OnSymbolLoaded(string handler)
     {
      if(handler != "")
        {
         int size = ArraySize(m_symbolLoadedHandlers);
         ArrayResize(m_symbolLoadedHandlers, size + 1);
         m_symbolLoadedHandlers[size] = handler;
        }
     }

   void              OnUpdate(string handler)
     {
      if(handler != "")
        {
         int size = ArraySize(m_updateHandlers);
         ArrayResize(m_updateHandlers, size + 1);
         m_updateHandlers[size] = handler;
        }
     }

   void              OnError(string handler)
     {
      if(handler != "")
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
                  if(m_updateHandlers[i] != "")
                    {
                     int eventId = (int)StringToInteger(m_updateHandlers[i]);
                     if(eventId > 0)
                        EventChartCustom(0, eventId, 0, 0, data);
                    }
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

   // Event handlers
   string            m_createdHandlers[];
   string            m_updateHandlers[];
   string            m_errorHandlers[];

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

   // Event handlers
   void              OnCreated(string handler)
     {
      if(handler != "")
        {
         int size = ArraySize(m_createdHandlers);
         ArrayResize(m_createdHandlers, size + 1);
         m_createdHandlers[size] = handler;
        }
     }

   void              OnUpdate(string handler)
     {
      if(handler != "")
        {
         int size = ArraySize(m_updateHandlers);
         ArrayResize(m_updateHandlers, size + 1);
         m_updateHandlers[size] = handler;
        }
     }

   void              OnError(string handler)
     {
      if(handler != "")
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
                  if(m_updateHandlers[i] != "")
                    {
                     int eventId = StringToInteger(m_updateHandlers[i]);
                     if(eventId > 0)
                        EventChartCustom(0, eventId, 0, 0, data);
                    }
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
