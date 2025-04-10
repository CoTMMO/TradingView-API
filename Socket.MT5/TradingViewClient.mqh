//+------------------------------------------------------------------+
//|                                               TradingViewClient.mqh |
//|                                         Copyright 2025, Your Name |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Name"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include "ws/wsclient.mqh"
#include <JAson.mqh>
#include "TradingViewSession.mqh"

// WebSocket client implementation for TradingView
class TVWebSocketClient : public WebSocketClient<WebSocketConnectionHybi>
  {
private:
   bool              m_isLogged;
   string            m_authToken;
   string            m_address;
   bool              m_useTLS;
   bool              m_autoFallbackToNonTLS;
   int               m_maxRetries;
   int               m_retryDelayMs;
   TradingViewSession *m_sessions[];

   // Format WebSocket packet according to TradingView protocol
   string            formatWSPacket(string message)
     {
      return "~m~" + IntegerToString(StringLen(message)) + "~m~" + message;
     }

   // Parse WebSocket packet according to TradingView protocol
   bool              parseWSPacket(string message, string &parsedPackets[])
     {
      int index = 0;
      int size = StringLen(message);

      while(index < size)
        {
         // Find packet start
         int startPos = StringFind(message, "~m~", index);
         if(startPos == -1)
            break;

         // Find packet length delimiter
         int lengthDelimPos = StringFind(message, "~m~", startPos + 3);
         if(lengthDelimPos == -1)
            break;

         // Extract packet length
         string lengthStr = StringSubstr(message, startPos + 3, lengthDelimPos - startPos - 3);
         int packetLength = (int)StringToInteger(lengthStr);

         // Extract packet content
         string packet = StringSubstr(message, lengthDelimPos + 3, packetLength);

         // Add to result array
         int arraySize = ArraySize(parsedPackets);
         ArrayResize(parsedPackets, arraySize + 1);
         parsedPackets[arraySize] = packet;

         // Move index to next packet
         index = lengthDelimPos + 3 + packetLength;
        }

      return ArraySize(parsedPackets) > 0;
     }

public:
                     TVWebSocketClient(string address, string authToken = "unauthorized_user_token")
      :              WebSocketClient<WebSocketConnectionHybi>("")  // Initialize with empty address, we'll set it in connect method
     {
      m_isLogged = false;
      m_authToken = authToken;
      m_address = address;
      m_useTLS = true; // Default to using TLS
      m_autoFallbackToNonTLS = true; // Auto fallback to non-TLS if TLS fails
      m_maxRetries = 3; // Maximum connection retry attempts
      m_retryDelayMs = 2000; // Delay between retries in milliseconds
     }

                    ~TVWebSocketClient()
     {
      // Clean up sessions
      for(int i = 0; i < ArraySize(m_sessions); i++)
        {
         if(m_sessions[i] != NULL)
            delete m_sessions[i];
        }
     }

   // Set TLS usage
   void              SetUseTLS(bool useTLS)
     {
      m_useTLS = useTLS;
     }
     
   // Set auto fallback to non-TLS
   void              SetAutoFallbackToNonTLS(bool autoFallback)
     {
      m_autoFallbackToNonTLS = autoFallback;
     }
     
   // Set retry parameters
   void              SetRetryParameters(int maxRetries, int retryDelayMs)
     {
      m_maxRetries = maxRetries;
      m_retryDelayMs = retryDelayMs;
     }

   // Connect to TradingView WebSocket server with auto-fallback and retries
   bool              connect()
     {
      // Parse the server address
      string serverAddress = m_address;
      if(StringFind(serverAddress, "://") >= 0)
        {
         int protocolEnd = StringFind(serverAddress, "://") + 3;
         serverAddress = StringSubstr(serverAddress, protocolEnd);
        }
      
      // Remove any path part
      int pathStart = StringFind(serverAddress, "/");
      if(pathStart > 0)
        {
         serverAddress = StringSubstr(serverAddress, 0, pathStart);
        }
      
      // Extract port if specified
      int colonPos = StringFind(serverAddress, ":");
      if(colonPos > 0)
        {
         serverAddress = StringSubstr(serverAddress, 0, colonPos);
        }
      
      bool connected = false;
      int retryCount = 0;
      
      // Try to connect with fallback from TLS to non-TLS if needed
      while(!connected && retryCount < m_maxRetries)
        {
         // Build the URL based on current protocol settings with EXPLICIT port to avoid incorrect port detection
         string scheme = m_useTLS ? "wss://" : "ws://";
         int port = m_useTLS ? 443 : 80;
         string fullAddress = scheme + serverAddress + ":" + IntegerToString(port);
         
         // Log connection attempt
         Print("Attempt ", retryCount + 1, "/", m_maxRetries, ": ", 
               "Connecting to ", fullAddress, " ", 
               m_useTLS ? "(TLS)" : "(non-TLS)");
         
         // Create a new WebSocket connection with correct URL and port
         string parts[];
         URL::parse(fullAddress, parts);
         scheme = parts[URL_SCHEME];
         string host = parts[URL_HOST];
         string portStr = parts[URL_PORT];
         
         // Debug the URL parsing
         Print("  > URL parts: scheme=", scheme, ", host=", host, ", port=", portStr);
         
         // Set longer timeout
         setTimeOut(10000);
         
         // Custom headers for TradingView
         string headers = "Origin: https://www.tradingview.com";
         
         // Try to open the connection - need to use a different approach
         // We can't use open() directly as it uses the address from construction time
         if(socket) delete socket; // Clean up any existing socket
         
         uint portNum = (uint)StringToInteger(portStr);
         if(portNum == 0) portNum = port; // Fallback to our default if parsing failed
         
         socket = MqlWebSocketTransport::create(scheme, host, portNum, timeOut);
         if(!socket || !socket.isConnected())
           {
            int error = GetLastError();
            Print("Connection failed with error: ", error);
            
            // Check for TLS errors (5274 = TLS handshake failed)
            if((error == 5274 || error == 4060) && m_useTLS && m_autoFallbackToNonTLS)
              {
               Print("TLS handshake failed. Attempting fallback to non-TLS connection on port 80...");
               m_useTLS = false;
               retryCount--; // Don't count this as a retry
              }
            else
              {
               retryCount++;
              }
            
            // Wait before retry
            if(retryCount < m_maxRetries)
              {
               Print("Retrying in ", m_retryDelayMs/1000.0, " seconds...");
               Sleep(m_retryDelayMs);
              }
            continue;
           }
         
         // Complete the WebSocket handshake by creating a connection
         if(socket && socket.isConnected())
           {
            connection = new WebSocketConnectionHybi(&this, socket, false);
            if(!connection.handshake(fullAddress, host, "https://" + host, headers))
              {
               Print("WebSocket handshake failed.");
               delete connection;
               connection = NULL;
               if(socket)
                 {
                  delete socket;
                  socket = NULL;
                 }
               retryCount++;
               continue;
              }
            
            // Connection successful
            connected = true;
            Print("Successfully connected to TradingView WebSocket server");
            
            // Set auth token
            sendRaw(formatWSPacket("{\"m\":\"set_auth_token\",\"p\":[\"" + m_authToken + "\"]}"));
           }
        }
      
      if(!connected)
        {
         Print("Failed to connect to TradingView after ", m_maxRetries, " attempts");
        }
      
      return connected;
     }

   // Create a new chart session
   TradingViewSession* createChartSession()
     {
      TradingViewSession *session = new TradingViewSession(&this);

      // Add to sessions array
      int arraySize = ArraySize(m_sessions);
      ArrayResize(m_sessions, arraySize + 1);
      m_sessions[arraySize] = session;

      return session;
     }

   // Send raw message
   bool              sendRaw(string message)
     {
      Print("📤 SENDING: msg=" + message);
      return send(message);
     }

   // Send packet in TradingView format
   bool              sendPacket(string type, string &params[])
     {
      CJAVal json;
      json["m"] = type;

      CJAVal paramsArray;
      for(int i = 0; i < ArraySize(params); i++)
        {
         paramsArray[i] = params[i];
        }

      json["p"] = paramsArray;

      string jsonStr = json.Serialize();
      return sendRaw(formatWSPacket(jsonStr));
     }

   // Process received messages
   void              processMessages()
     {
      if(!isConnected())
         return;

      IWebSocketMessage *msg = readMessage(false);
      while(msg != NULL)
        {
         string rawMessage = msg.getString();
         Print("📥 RECEIVED RAW: " + rawMessage);
         string parsedPackets[];
         if(parseWSPacket(rawMessage, parsedPackets))
           {
            for(int i = 0; i < ArraySize(parsedPackets); i++)
              {
               processPacket(parsedPackets[i]);
              }
           }
         delete msg;
         msg = readMessage(false);
        }
     }

   // Process a single packet
   void              processPacket(string packet)
     {
      // Check if it's a ping packet
      if(StringSubstr(packet, 0, 3) == "~h~")
        {
         string pingValue = StringSubstr(packet, 3);
         sendRaw(formatWSPacket("~h~" + pingValue));
         Print("Responded to ping: " + pingValue);
         return;
        }

      // Try to parse as JSON
      CJAVal json;
      if(!json.Deserialize(packet))
        {
         Print("Failed to parse packet as JSON: " + packet);
         return;
        }

      // Check if it's a protocol_error
      if(json["m"].ToStr() == "protocol_error")
        {
         Print("Protocol error: " + packet);
         close();
         return;
        }

      // Process normal packet
      if(json["m"].ToStr() != "" && CheckPointer(json.HasKey("p")) != POINTER_INVALID)
        {
         string type = json["m"].ToStr();
         CJAVal paramsArray = json["p"];

         // First connection response
         if(type == "critical_error")
           {
            Print("Critical error: " + packet);
            close();
            return;
           }

         // First connection response contains session_id
         if(json.HasKey("session_id") && !m_isLogged)
           {
            m_isLogged = true;
            Print("Logged in to TradingView");
            return;
           }

         // Dispatch to appropriate session
         if(paramsArray.Size() > 0)
           {
            string sessionId = paramsArray[0].ToStr();
            for(int i = 0; i < ArraySize(m_sessions); i++)
              {
               if(m_sessions[i] != NULL && m_sessions[i].getSessionId() == sessionId)
                 {
                  // Convert params to string array for session processing
                  string params[];
                  ArrayResize(params, paramsArray.Size());
                  for(int j = 0; j < paramsArray.Size(); j++)
                    {
                     params[j] = paramsArray[j].ToStr();
                    }

                  m_sessions[i].processMessage(type, params);
                  break;
                 }
              }
           }
        }
     }

   // Check if logged in
   bool              isLogged() const
     {
      return m_isLogged;
     }
  };
//+------------------------------------------------------------------+
