//+------------------------------------------------------------------+
//| QuoteMarket class for MQL5                                       |
//+------------------------------------------------------------------+
#include  "session.mqh"
// Event type enumeration
enum ENUM_MARKET_EVENT {
   MARKET_EVENT_LOADED,
   MARKET_EVENT_DATA,
   MARKET_EVENT_ERROR
};

// Callback function typedefs
typedef void (*LoadedCallback)();
typedef void (*DataCallback)(string &data);
typedef void (*EventCallback)(ENUM_MARKET_EVENT event, string &data);
typedef void (*ErrorCallback)(string &errorMsg);

class QuoteMarket {
private:
   // Symbol properties
   string            m_symbol;
   string            m_session;
   string            m_symbolKey;
   int               m_symbolListenerID;
   
   // Data storage
   string            m_lastData;
   
   // Callback arrays
   LoadedCallback    m_loadedCallbacks[];
   DataCallback      m_dataCallbacks[];
   EventCallback     m_eventCallbacks[];
   ErrorCallback     m_errorCallbacks[];
   
   // Session reference - this needs to be properly initialized
   QuoteSession*      m_quoteSession;
   
   // Private methods
   void              HandleEvent(ENUM_MARKET_EVENT ev, string &data);
   void              HandleError(string errorMsg);

public:
   // Modified constructor to accept the session reference
   QuoteMarket(QuoteSession* session, string symbol, string sessionType="regular");
                    ~QuoteMarket();
   
   // Event registration methods
   void              OnLoaded(LoadedCallback callback);
   void              OnData(DataCallback callback);
   void              OnEvent(EventCallback callback);
   void              OnError(ErrorCallback callback);
   
   // Close and cleanup
   void              Close();
   
   // Process incoming packet (would be called by session)
   void              ProcessPacket(string packetType, string &packetData);
   
   // Parse market data from JSON
   bool              ParseMarketData(string &data);
};

//+------------------------------------------------------------------+
//| Constructor with session reference                                |
//+------------------------------------------------------------------+
QuoteMarket::QuoteMarket(QuoteSession* session, string symbol, string sessionType="regular") {
   m_symbol = symbol;
   m_session = sessionType;
   m_symbolKey = "={\"session\":\"" + sessionType + "\",\"symbol\":\"" + symbol + "\"}";
   
   // Store the session reference for later use
   m_quoteSession = session;
   
   // Add the symbol to the session
   if(m_quoteSession != NULL) {
      m_quoteSession.AddSymbol(symbol, sessionType);
   } else {
      Print("Error: Quote session reference is NULL");
   }
   
   // Initialize the listener ID
   m_symbolListenerID = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
QuoteMarket::~QuoteMarket() {
   Close();
}

//+------------------------------------------------------------------+
//| Handle market events                                              |
//+------------------------------------------------------------------+
void QuoteMarket::HandleEvent(ENUM_MARKET_EVENT ev, string &data) {
   // Call appropriate callbacks based on event type
   switch(ev) {
      case MARKET_EVENT_LOADED:
         for(int i=0; i<ArraySize(m_loadedCallbacks); i++)
            if(m_loadedCallbacks[i] != NULL)
               m_loadedCallbacks[i]();
         break;
         
      case MARKET_EVENT_DATA:
         for(int i=0; i<ArraySize(m_dataCallbacks); i++)
            if(m_dataCallbacks[i] != NULL)
               m_dataCallbacks[i](data);
         break;
         
      case MARKET_EVENT_ERROR:
         for(int i=0; i<ArraySize(m_errorCallbacks); i++)
            if(m_errorCallbacks[i] != NULL)
               m_errorCallbacks[i](data);
         break;
   }
   
   // Call general event callbacks
   for(int i=0; i<ArraySize(m_eventCallbacks); i++)
      if(m_eventCallbacks[i] != NULL)
         m_eventCallbacks[i](ev, data);
}

//+------------------------------------------------------------------+
//| Handle errors                                                     |
//+------------------------------------------------------------------+
void QuoteMarket::HandleError(string errorMsg) {
   if(ArraySize(m_errorCallbacks) == 0)
      Print("Error: ", errorMsg);
   else {
      string data = errorMsg;
      HandleEvent(MARKET_EVENT_ERROR, data);
   }
}

//+------------------------------------------------------------------+
//| Register loaded callback                                          |
//+------------------------------------------------------------------+
void QuoteMarket::OnLoaded(LoadedCallback callback) {
   int size = ArraySize(m_loadedCallbacks);
   ArrayResize(m_loadedCallbacks, size + 1);
   m_loadedCallbacks[size] = callback;
}

//+------------------------------------------------------------------+
//| Register data callback                                            |
//+------------------------------------------------------------------+
void QuoteMarket::OnData(DataCallback callback) {
   int size = ArraySize(m_dataCallbacks);
   ArrayResize(m_dataCallbacks, size + 1);
   m_dataCallbacks[size] = callback;
}

//+------------------------------------------------------------------+
//| Register event callback                                           |
//+------------------------------------------------------------------+
void QuoteMarket::OnEvent(EventCallback callback) {
   int size = ArraySize(m_eventCallbacks);
   ArrayResize(m_eventCallbacks, size + 1);
   m_eventCallbacks[size] = callback;
}

//+------------------------------------------------------------------+
//| Register error callback                                           |
//+------------------------------------------------------------------+
void QuoteMarket::OnError(ErrorCallback callback) {
   int size = ArraySize(m_errorCallbacks);
   ArrayResize(m_errorCallbacks, size + 1);
   m_errorCallbacks[size] = callback;
}

//+------------------------------------------------------------------+
//| Process an incoming packet from the session                       |
//+------------------------------------------------------------------+
void QuoteMarket::ProcessPacket(string packetType, string &packetData) {
   // Debug output
   if(MQLInfoInteger(MQL_DEBUG))
      Print("MARKET DATA: ", packetType, " ", packetData);
      
   // Process different packet types
   if(packetType == "qsd") {
      // Parse JSON data
      CJAVal json;
      if(!json.Deserialize(packetData)) {
         HandleError("Failed to parse market data JSON");
         return;
      }
      
      // Check if packet has valid data structure
      if(json.Size() >= 2 && json[1].HasKey("s") && json[1]["s"].ToStr() == "ok") {
         if(json[1].HasKey("v")) {
            CJAVal values = json[1]["v"];
            
            // Extract and store market data from the values object
            if(values.HasKey("lp")) {
               double price = values["lp"].ToDbl();
               // Store price in m_lastData or process it
               // ...
            }
            
            // Similar processing for other fields...
            
            // Notify data listeners
            string data = packetData;
            HandleEvent(MARKET_EVENT_DATA, data);
         }
      }
      else if(json.Size() >= 2 && json[1].HasKey("s") && json[1]["s"].ToStr() == "error") {
         // Handle error
         string errorMsg = "Market error";
         if(json[1].HasKey("errmsg")) {
            errorMsg = json[1]["errmsg"].ToStr();
         }
         HandleError(errorMsg);
      }
   }
   else if(packetType == "quote_completed") {
      string dummy;
      HandleEvent(MARKET_EVENT_LOADED, dummy);
   }
}

//+------------------------------------------------------------------+
//| Parse market data from JSON                                       |
//+------------------------------------------------------------------+
bool QuoteMarket::ParseMarketData(string &data) {
   CJAVal json;
   
   if(!json.Deserialize(data)) {
      HandleError("Failed to parse market data JSON");
      return false;
   }
   
   // Extract data fields from the JSON packet
   // This implementation would depend on the actual packet structure
   
   // Example of extracting price:
   if(json.HasKey("lp")) {
      double price = json["lp"].ToDbl();
      // Process price update
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Close the market connection                                       |
//+------------------------------------------------------------------+
void QuoteMarket::Close() {
   // Remove symbol from quote session
   if(m_quoteSession != NULL) {
      m_quoteSession.RemoveSymbol(m_symbol, m_session);
      Print("Closed market connection for symbol: ", m_symbol);
   } else {
      Print("Error: Cannot close market connection - session reference is NULL");
   }
}
