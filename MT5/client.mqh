//+------------------------------------------------------------------+
//|                                                    client.mqh     |
//+------------------------------------------------------------------+
#include <Arrays\List.mqh>
#include "include\JAson.mqh"
#include "include\websocket.mqh"
#include "include\winhttp.mqh"
#include "protocol.mqh"
#include "utils.mqh"
#include "quote/session.mqh"
#include "chart/session.mqh"
#include "miscRequests.mqh"

// Forward declarations
class QuoteSession;
class ChartSession;

//+------------------------------------------------------------------+
//| Session base class                                               |
//+------------------------------------------------------------------+
class Session {
public:
   string            type;          // Session type: 'quote', 'chart', 'replay'
   string            sessionId;     // Session ID assigned by server
   
   // Enhanced OnData method that receives packet type and data
   virtual void      OnData(string packetType, CJAVal &data) { }
   
   // Original OnData method for backward compatibility
   virtual void      OnData(CJAVal &data) { 
      // Default implementation calls the new method with empty type
      OnData("", data);
   }
};

//+------------------------------------------------------------------+
//| Session list management                                          |
//+------------------------------------------------------------------+
class SessionList {
private:
   CArrayObj         m_sessions;    // Array of Session objects
   
public:
                     SessionList() { m_sessions.FreeMode(false); }
                    ~SessionList() { Clear(); }
                    
   void              Clear() { m_sessions.Clear(); }
   bool              Add(Session *session) { return m_sessions.Add(session); }
   int               Total() const { return m_sessions.Total(); }
   Session*          GetByIndex(int index) { return (Session*)m_sessions.At(index); }
   Session*          FindById(string id);
};

//+------------------------------------------------------------------+
//| Find session by ID                                               |
//+------------------------------------------------------------------+
Session* SessionList::FindById(string id) {
   for(int i=0; i<m_sessions.Total(); i++) {
      Session* session = GetByIndex(i);
      if(session.sessionId == id)
         return session;
   }
   return NULL;
}

//+------------------------------------------------------------------+
//| Client options structure                                         |
//+------------------------------------------------------------------+
struct ClientOptions {
   string            token;         // User auth token (in 'sessionid' cookie)
   string            signature;     // Token signature (in 'sessionid_sign' cookie)
   bool              debugMode;     // Enable debug mode
   string            server;        // Server type: "data", "prodata", "widgetdata"
   string            location;      // Auth page location
};

//+------------------------------------------------------------------+
//| ClientBridge for passing to sessions                             |
//+------------------------------------------------------------------+
class ClientBridge {
private:
   SessionList*      m_sessions;
   int               m_sendCallback;
   
public:
                     ClientBridge(SessionList* sessions, int sendCallback) {
                        m_sessions = sessions;
                        m_sendCallback = sendCallback;
                     }
   
   SessionList*      GetSessions() { return m_sessions; }
   void              Send(string type, string &params[]);
};

//+------------------------------------------------------------------+
//| Client event types                                               |
//+------------------------------------------------------------------+
enum ENUM_CLIENT_EVENT {
   CLIENT_EVENT_CONNECTED,
   CLIENT_EVENT_DISCONNECTED,
   CLIENT_EVENT_LOGGED,
   CLIENT_EVENT_PING,
   CLIENT_EVENT_DATA,
   CLIENT_EVENT_ERROR,
   CLIENT_EVENT_CUSTOM
};

//+------------------------------------------------------------------+
//| Callback function type definitions                               |
//+------------------------------------------------------------------+
typedef void (*VoidCallback)();                    // Callback with no parameters
typedef void (*SessionCallback)(string data);      // Callback with session data
typedef void (*IntCallback)(int value);            // Callback with integer parameter
typedef void (*DataCallback)(string data);         // Callback for data events
typedef void (*ErrorCallback)(string errorMsg);    // Callback for error events
typedef void (*EventCallback)(ENUM_CLIENT_EVENT eventType, string data); // Callback for generic events

//+------------------------------------------------------------------+
//| Main TradingView API Client class                                |
//+------------------------------------------------------------------+
class Client {
private:
   CWebSocket*      m_ws;           // WebSocket connection
   bool             m_logged;       // Login state
   SessionList      m_sessions;     // Session list
   string           m_token;        // Auth token
   string           m_signature;    // Auth signature
   ClientOptions    m_options;      // Client options
   ClientBridge*    m_bridge;       // Bridge for sessions
   
   // Send queue variables
   string           m_sendQueue[];  // Queue for packets to send
   int              m_queueSize;    // Current queue size
   
   // Callback arrays
   VoidCallback     m_onConnected[];
   VoidCallback     m_onDisconnected[];
   SessionCallback  m_onLogged[];
   IntCallback      m_onPing[];
   DataCallback     m_onData[];
   ErrorCallback    m_onError[];
   EventCallback    m_onEvent[];

   // Private methods
   void              HandleEvent(ENUM_CLIENT_EVENT ev, string &data);
   void              HandleError(string errorMsg);
   void              ParsePacket(string data);
   void              SendQueue();
   bool              Connect();
   bool              GetUser(string token, string signature, string location);

public:
                     Client(ClientOptions &options);
                    ~Client();

   // Event registration methods
   void              OnConnected(VoidCallback callback);
   void              OnDisconnected(VoidCallback callback);
   void              OnLogged(SessionCallback callback);
   void              OnPing(IntCallback callback);
   void              OnData(DataCallback callback);
   void              OnError(ErrorCallback callback);
   void              OnEvent(EventCallback callback);

   // Public methods
   bool              Send(string type, string &params[]);
   void              End();

   // Getters
   bool              IsLogged()  { return m_logged; }
   bool              IsOpen()    { return m_ws != NULL && m_ws.IsConnected(); }
   
   // Session factories
   QuoteSession*     CreateQuoteSession(QuoteSessionOptions &options);
   ChartSession*     CreateChartSession();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
Client::Client(ClientOptions &options) : m_sessions() {
   m_logged = false;
   m_token = options.token;
   m_signature = options.signature;
   m_options = options;
   m_queueSize = 0;
   
   // Create ClientBridge for sessions
   m_bridge = new ClientBridge(&m_sessions, GetPointer(this));
   
   // Set debug mode if requested
   if(options.debugMode) {
      // Set global debug flag
      Print("TradingView Client: Debug mode enabled");
   }
   
   Connect();
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
Client::~Client() {
   End();
   if(m_bridge != NULL) delete m_bridge;
}

//+------------------------------------------------------------------+
//| Connect to TradingView WebSocket server                          |
//+------------------------------------------------------------------+
bool Client::Connect() {
   string server = (m_options.server != "") ? m_options.server : "data";
   string wsUrl = "wss://" + server + ".tradingview.com/socket.io/websocket?type=chart";
   
   // Create WebSocket if it doesn't exist
   if(m_ws == NULL) m_ws = new CWebSocket();
   
   // Connect to WebSocket server
   if(!m_ws.Connect(wsUrl, 443, "TradingView MT5 Client", true)) {
      HandleError("Failed to connect to WebSocket server: " + m_ws.LastErrorMessage());
      return false;
   }
   
   // Handle successful connection
   HandleEvent(CLIENT_EVENT_CONNECTED, "");
   
   // Set auth token
   if(m_token != "") {
      // Get user authentication token
      if(!GetUser(m_token, m_signature, m_options.location)) {
         HandleError("Failed to get user authentication");
         return false;
      }
   } else {
      // Add unauthorized token to send queue
      string params[];
      ArrayResize(params, 1);
      params[0] = "unauthorized_user_token";
      
      // Send authentication packet
      Send("set_auth_token", params);
      
      m_logged = true;
      SendQueue();
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Get user authentication details                                   |
//+------------------------------------------------------------------+
bool Client::GetUser(string token, string signature, string location) {
   // Use the getUser function from miscRequests.mqh
   User user;
   if(!getUser(user, token, signature, location)) {
      return false;
   }
   
   // Send authentication packet with the auth token from the user structure
   string params[];
   ArrayResize(params, 1);
   params[0] = user.authToken;
   
   // Send authentication packet
   Send("set_auth_token", params);
   
   m_logged = true;
   
   return true;
}

//+------------------------------------------------------------------+
//| Close WebSocket connection                                        |
//+------------------------------------------------------------------+
void Client::End() {
   if(m_ws != NULL) {
      m_ws.Close();
      delete m_ws;
      m_ws = NULL;
   }
   m_logged = false;
   HandleEvent(CLIENT_EVENT_DISCONNECTED, "");
}

//+------------------------------------------------------------------+
//| Parse WebSocket packet                                            |
//+------------------------------------------------------------------+
void Client::ParsePacket(string data) {
   if(!IsOpen()) return;
   
   // Parse the WebSocket packet
   string packets[];
   Protocol::ParseWSPacket(data, packets);
   
   for(int i=0; i<ArraySize(packets); i++) {
      string packet = packets[i];
      
      if(m_options.debugMode) {
         Print("CLIENT PACKET: ", packet);
      }
      
      // Check if packet is a ping
      if(StringSubstr(packet, 0, 3) == "~h~") {
         // Extract ping number
         int pingNum = (int)StringToInteger(StringSubstr(packet, 3));
         
         // Send pong response
         m_ws.SendString(Protocol::FormatWSPacket("~h~" + IntegerToString(pingNum)));
         
         // Trigger ping event
         HandleEvent(CLIENT_EVENT_PING, IntegerToString(pingNum));
         continue;
      }
      
      // Parse JSON packet
      CJAVal json;
      if(!json.Deserialize(packet)) {
         HandleError("Failed to parse packet: " + packet);
         continue;
      }
      
      // Check for protocol error
      if(json["m"].ToStr() == "protocol_error") {
         HandleError("Client critical error: " + json["p"].ToStr());
         m_ws.Close();
         return;
      }
      
      // Handle normal packet
      if(json["m"].ToStr() != "" && json["p"].ToStr() != "") {
         string type = json["m"].ToStr();
         CJAVal data = json["p"];
         
         // Check if packet belongs to a session
         if(data.Size() > 0) {
            string sessionId = data[0].ToStr();
            
            // Try to find session by ID
            Session* session = m_sessions.FindById(sessionId);
            if(session != NULL) {
               // Call the enhanced OnData method with type and data
               session.OnData(type, data);
               continue;
            }
         }
         
         // If we get here, this packet wasn't handled by any session
         HandleEvent(CLIENT_EVENT_DATA, packet);
      }
      
      // If not logged in yet, handle this as login packet
      if(!m_logged) {
         HandleEvent(CLIENT_EVENT_LOGGED, packet);
         m_logged = true;
         SendQueue(); // Send any queued packets after logging in
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Send a packet to the server                                      |
//+------------------------------------------------------------------+
bool Client::Send(string type, string &params[]) {
   if(m_options.debugMode) {
      string debugMsg = "SENDING: " + type + " with params: ";
      for(int i=0; i<ArraySize(params); i++) {
         debugMsg += params[i] + ", ";
      }
      Print(debugMsg);
   }
   
   string packet = Protocol::FormatWSPacket(type, params);
   
   ArrayResize(m_sendQueue, m_queueSize + 1);
   m_sendQueue[m_queueSize++] = packet;
   
   if(m_logged) SendQueue();
   
   return true;
}

//+------------------------------------------------------------------+
//| Send all queued packets                                          |
//+------------------------------------------------------------------+
void Client::SendQueue() {
   while(IsOpen() && m_logged && m_queueSize > 0) {
      string packet = m_sendQueue[0];
      
      // Remove first item from queue
      for(int i=1; i<m_queueSize; i++) {
         m_sendQueue[i-1] = m_sendQueue[i];
      }
      m_queueSize--;
      
      // Send packet
      if(!m_ws.SendString(packet)) {
         HandleError("Failed to send packet: " + m_ws.LastErrorMessage());
      }
      
      if(m_options.debugMode) {
         Print("SENT: ", packet);
      }
   }
}

//+------------------------------------------------------------------+
//| Handle client events                                             |
//+------------------------------------------------------------------+
void Client::HandleEvent(ENUM_CLIENT_EVENT ev, string &data) {
   // Call appropriate callbacks based on event type
   switch(ev) {
      case CLIENT_EVENT_CONNECTED:
         for(int i=0; i<ArraySize(m_onConnected); i++) {
            if(m_onConnected[i] != NULL) m_onConnected[i]();
         }
         break;
         
      case CLIENT_EVENT_DISCONNECTED:
         for(int i=0; i<ArraySize(m_onDisconnected); i++) {
            if(m_onDisconnected[i] != NULL) m_onDisconnected[i]();
         }
         break;
         
      case CLIENT_EVENT_LOGGED:
         for(int i=0; i<ArraySize(m_onLogged); i++) {
            if(m_onLogged[i] != NULL) m_onLogged[i](data);
         }
         break;
         
      case CLIENT_EVENT_PING:
         int pingVal = (int)StringToInteger(data);
         for(int i=0; i<ArraySize(m_onPing); i++) {
            if(m_onPing[i] != NULL) m_onPing[i](pingVal);
         }
         break;
         
      case CLIENT_EVENT_DATA:
         for(int i=0; i<ArraySize(m_onData); i++) {
            if(m_onData[i] != NULL) m_onData[i](data);
         }
         break;
         
      case CLIENT_EVENT_ERROR:
         for(int i=0; i<ArraySize(m_onError); i++) {
            if(m_onError[i] != NULL) m_onError[i](data);
         }
         break;
   }
   
   // Also call generic event handlers
   for(int i=0; i<ArraySize(m_onEvent); i++) {
      if(m_onEvent[i] != NULL) m_onEvent[i](ev, data);
   }
}

//+------------------------------------------------------------------+
//| Handle error events                                              |
//+------------------------------------------------------------------+
void Client::HandleError(string errorMsg) {
   if(ArraySize(m_onError) == 0) {
      Print("ERROR: ", errorMsg);
   } else {
      HandleEvent(CLIENT_EVENT_ERROR, errorMsg);
   }
}

//+------------------------------------------------------------------+
//| Create a new quote session                                       |
//+------------------------------------------------------------------+
QuoteSession* Client::CreateQuoteSession(QuoteSessionOptions &options) {
   QuoteSession* session = new QuoteSession(m_bridge, options);
   m_sessions.Add(session);
   return session;
}

//+------------------------------------------------------------------+
//| Create a new chart session                                       |
//+------------------------------------------------------------------+
ChartSession* Client::CreateChartSession() {
   ChartSession* session = new ChartSession(m_bridge);
   m_sessions.Add(session);
   return session;
}

//+------------------------------------------------------------------+
//| Event registration methods                                       |
//+------------------------------------------------------------------+
void Client::OnConnected(VoidCallback callback) {
   int size = ArraySize(m_onConnected);
   ArrayResize(m_onConnected, size + 1);
   m_onConnected[size] = callback;
}

void Client::OnDisconnected(VoidCallback callback) {
   int size = ArraySize(m_onDisconnected);
   ArrayResize(m_onDisconnected, size + 1);
   m_onDisconnected[size] = callback;
}

void Client::OnLogged(SessionCallback callback) {
   int size = ArraySize(m_onLogged);
   ArrayResize(m_onLogged, size + 1);
   m_onLogged[size] = callback;
}

void Client::OnPing(IntCallback callback) {
   int size = ArraySize(m_onPing);
   ArrayResize(m_onPing, size + 1);
   m_onPing[size] = callback;
}

void Client::OnData(DataCallback callback) {
   int size = ArraySize(m_onData);
   ArrayResize(m_onData, size + 1);
   m_onData[size] = callback;
}

void Client::OnError(ErrorCallback callback) {
   int size = ArraySize(m_onError);
   ArrayResize(m_onError, size + 1);
   m_onError[size] = callback;
}

void Client::OnEvent(EventCallback callback) {
   int size = ArraySize(m_onEvent);
   ArrayResize(m_onEvent, size + 1);
   m_onEvent[size] = callback;
}
