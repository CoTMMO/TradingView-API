//+------------------------------------------------------------------+
//| QuoteSession class for MQL5                                      |
//+------------------------------------------------------------------+

#include <Web\Json.mqh>
#include "market.mqh"

// Field type enumeration for quote data fields
enum ENUM_QUOTE_FIELD {
   QUOTE_FIELD_BASE_CURRENCY_LOGOID,
   QUOTE_FIELD_CH,
   QUOTE_FIELD_CHP,
   QUOTE_FIELD_CURRENCY_LOGOID,
   QUOTE_FIELD_PROVIDER_ID,
   QUOTE_FIELD_CURRENCY_CODE,
   QUOTE_FIELD_CURRENT_SESSION,
   QUOTE_FIELD_DESCRIPTION,
   QUOTE_FIELD_EXCHANGE,
   QUOTE_FIELD_FORMAT,
   QUOTE_FIELD_FRACTIONAL,
   QUOTE_FIELD_IS_TRADABLE,
   QUOTE_FIELD_LANGUAGE,
   QUOTE_FIELD_LOCAL_DESCRIPTION,
   QUOTE_FIELD_LOGOID,
   QUOTE_FIELD_LP,
   QUOTE_FIELD_LP_TIME,
   QUOTE_FIELD_MINMOV,
   QUOTE_FIELD_MINMOVE2,
   QUOTE_FIELD_ORIGINAL_NAME,
   QUOTE_FIELD_PRICESCALE,
   QUOTE_FIELD_PRO_NAME,
   QUOTE_FIELD_SHORT_NAME,
   QUOTE_FIELD_TYPE,
   QUOTE_FIELD_UPDATE_MODE,
   QUOTE_FIELD_VOLUME,
   QUOTE_FIELD_ASK,
   QUOTE_FIELD_BID,
   QUOTE_FIELD_FUNDAMENTALS,
   QUOTE_FIELD_HIGH_PRICE,
   QUOTE_FIELD_LOW_PRICE,
   QUOTE_FIELD_OPEN_PRICE,
   QUOTE_FIELD_PREV_CLOSE_PRICE,
   QUOTE_FIELD_RCH,
   QUOTE_FIELD_RCHP,
   QUOTE_FIELD_RTC,
   QUOTE_FIELD_RTC_TIME,
   QUOTE_FIELD_STATUS,
   QUOTE_FIELD_INDUSTRY,
   QUOTE_FIELD_BASIC_EPS_NET_INCOME,
   QUOTE_FIELD_BETA_1_YEAR,
   QUOTE_FIELD_MARKET_CAP_BASIC,
   QUOTE_FIELD_EARNINGS_PER_SHARE_BASIC_TTM,
   QUOTE_FIELD_PRICE_EARNINGS_TTM,
   QUOTE_FIELD_SECTOR,
   QUOTE_FIELD_DIVIDENDS_YIELD,
   QUOTE_FIELD_TIMEZONE,
   QUOTE_FIELD_COUNTRY_CODE
};

// Symbol listener structure
struct SymbolListener {
   string            symbolKey;
   int               id;
   bool              active;
};

// Quote Session Bridge structure
struct QuoteSessionBridge {
   string            sessionID;
   SymbolListener    symbolListeners[];
   int               sendFunc;  // function pointer would be implemented differently in real code
};

// Missing callback registration mechanism
struct CallbackEntry {
   string            symbolKey;
   int               callbackFunc;  // Function pointer 
   bool              active;
};

//+------------------------------------------------------------------+
//| QuoteSession class definition                                    |
//+------------------------------------------------------------------+
class QuoteSession {
private:
   string            m_sessionID;
   SymbolListener    m_symbolListeners[];
   
   // Map of market instances for each symbol
   QuoteMarket*      m_marketInstances[];
   
   // Generate a unique session ID
   string            GenerateSessionID();
   
   // Get quote fields based on type
   void              GetQuoteFields(string fieldsType, string &fields[]);
   
   // Parse symbol key to extract symbol and session
   bool              ParseSymbolKey(string symbolKey, string &symbol, string &session);

public:
                     QuoteSession(string fieldsType="all");
                    ~QuoteSession();
   
   // Market class factory
   QuoteMarket*      CreateMarket(string symbol, string session="regular");
   
   // Add symbol to the session
   bool              AddSymbol(string symbol, string session="regular");
   
   // Remove symbol from the session
   bool              RemoveSymbol(string symbol, string session="regular");
   
   // Process incoming packet
   void              ProcessPacket(string packetType, string &packetData);
   
   // Delete the session
   void              Delete();
   
   // Getters
   string            GetSessionID() { return m_sessionID; }

   // Register a symbol listener callback
   bool              RegisterSymbolCallback(string symbol, string session, int callbackFunc);
};

//+------------------------------------------------------------------+
//| Helper function to get quote fields based on type                 |
//+------------------------------------------------------------------+
void QuoteSession::GetQuoteFields(string fieldsType, string &fields[]) {
   if(fieldsType == "price") {
      ArrayResize(fields, 1);
      fields[0] = "lp";
      return;
   }
   
   // All fields
   string allFields[] = {
      "base-currency-logoid", "ch", "chp", "currency-logoid",
      "currency_code", "current_session", "description",
      "exchange", "format", "fractional", "is_tradable",
      "language", "local_description", "logoid", "lp",
      "lp_time", "minmov", "minmove2", "original_name",
      "pricescale", "pro_name", "short_name", "type",
      "update_mode", "volume", "ask", "bid", "fundamentals",
      "high_price", "low_price", "open_price", "prev_close_price",
      "rch", "rchp", "rtc", "rtc_time", "status", "industry",
      "basic_eps_net_income", "beta_1_year", "market_cap_basic",
      "earnings_per_share_basic_ttm", "price_earnings_ttm",
      "sector", "dividends_yield", "timezone", "country_code",
      "provider_id"
   };
   
   int size = ArraySize(allFields);
   ArrayResize(fields, size);
   for(int i=0; i<size; i++)
      fields[i] = allFields[i];
}

//+------------------------------------------------------------------+
//| Generate a unique session ID                                      |
//+------------------------------------------------------------------+
string QuoteSession::GenerateSessionID() {
   string chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
   string id = "qs_";
   
   for(int i=0; i<8; i++)
      id += StringSubstr(chars, MathRand() % StringLen(chars), 1);
      
   return id;
}

//+------------------------------------------------------------------+
//| Parse symbol key into components                                  |
//+------------------------------------------------------------------+
bool QuoteSession::ParseSymbolKey(string symbolKey, string &symbol, string &session) {
   // symbolKey format: ={\"session\":\"regular\",\"symbol\":\"BTCUSD\"}
   
   int sessionPos = StringFind(symbolKey, "session");
   int symbolPos = StringFind(symbolKey, "symbol");
   
   if(sessionPos <= 0 || symbolPos <= 0)
      return false;
      
   // Extract session
   int sessionStart = StringFind(symbolKey, "\"", sessionPos + 8) + 1;
   int sessionEnd = StringFind(symbolKey, "\"", sessionStart);
   if(sessionStart <= 0 || sessionEnd <= 0)
      return false;
      
   session = StringSubstr(symbolKey, sessionStart, sessionEnd - sessionStart);
   
   // Extract symbol
   int symbolStart = StringFind(symbolKey, "\"", symbolPos + 7) + 1;
   int symbolEnd = StringFind(symbolKey, "\"", symbolStart);
   if(symbolStart <= 0 || symbolEnd <= 0)
      return false;
      
   symbol = StringSubstr(symbolKey, symbolStart, symbolEnd - symbolStart);
   
   return true;
}

//+------------------------------------------------------------------+
//| QuoteSession Constructor                                          |
//+------------------------------------------------------------------+
QuoteSession::QuoteSession(string fieldsType="all") {
   m_sessionID = GenerateSessionID();
   
   string fields[];
   GetQuoteFields(fieldsType, fields);
   
   // In a real implementation, this would send messages to the TradingView API
   // For now, we'll just log what would happen
   Print("Creating quote session: ", m_sessionID);
   Print("Setting fields: ", ArraySize(fields), " fields");
}

//+------------------------------------------------------------------+
//| QuoteSession Destructor                                           |
//+------------------------------------------------------------------+
QuoteSession::~QuoteSession() {
   Delete();
}

//+------------------------------------------------------------------+
//| Create a new market instance                                      |
//+------------------------------------------------------------------+
QuoteMarket* QuoteSession::CreateMarket(string symbol, string session="regular") {
   // Create the market instance
   QuoteMarket* market = new QuoteMarket(this, symbol, session);
   
   // Generate the symbol key
   string symbolKey = "={\"session\":\"" + session + "\",\"symbol\":\"" + symbol + "\"}";
   
   // Find an existing or add a new entry in the listeners array
   int listenerIndex = -1;
   
   for(int i=0; i<ArraySize(m_symbolListeners); i++) {
      if(m_symbolListeners[i].symbolKey == symbolKey) {
         listenerIndex = i;
         break;
      }
   }
   
   if(listenerIndex == -1) {
      // Add new listener
      int size = ArraySize(m_symbolListeners);
      ArrayResize(m_symbolListeners, size + 1);
      ArrayResize(m_marketInstances, size + 1);
      
      m_symbolListeners[size].symbolKey = symbolKey;
      m_symbolListeners[size].id = size;
      m_symbolListeners[size].active = true;
      
      m_marketInstances[size] = market;
   }
   else {
      // Update existing listener
      m_symbolListeners[listenerIndex].active = true;
      m_marketInstances[listenerIndex] = market;
   }
   
   return market;
}

//+------------------------------------------------------------------+
//| Add a symbol to the session                                       |
//+------------------------------------------------------------------+
bool QuoteSession::AddSymbol(string symbol, string session="regular") {
   string symbolKey = "={\"session\":\"" + session + "\",\"symbol\":\"" + symbol + "\"}";
   
   // Check if symbol already exists
   for(int i=0; i<ArraySize(m_symbolListeners); i++) {
      if(m_symbolListeners[i].symbolKey == symbolKey && m_symbolListeners[i].active)
         return true; // Already added
   }
   
   // Add new symbol listener
   int size = ArraySize(m_symbolListeners);
   ArrayResize(m_symbolListeners, size + 1);
   m_symbolListeners[size].symbolKey = symbolKey;
   m_symbolListeners[size].id = size;
   m_symbolListeners[size].active = true;
   
   // In a real implementation, send a message to the TradingView API
   Print("Adding symbol to session: ", symbolKey);
   
   return true;
}

//+------------------------------------------------------------------+
//| Remove a symbol from the session                                  |
//+------------------------------------------------------------------+
bool QuoteSession::RemoveSymbol(string symbol, string session="regular") {
   string symbolKey = "={\"session\":\"" + session + "\",\"symbol\":\"" + symbol + "\"}";
   
   for(int i=0; i<ArraySize(m_symbolListeners); i++) {
      if(m_symbolListeners[i].symbolKey == symbolKey && m_symbolListeners[i].active) {
         m_symbolListeners[i].active = false;
         
         // In a real implementation, send a message to the TradingView API
         Print("Removing symbol from session: ", symbolKey);
         return true;
      }
   }
   
   return false; // Symbol not found
}

//+------------------------------------------------------------------+
//| Process an incoming packet                                        |
//+------------------------------------------------------------------+
void QuoteSession::ProcessPacket(string packetType, string &packetData) {
   // Debug output
   if(MQLInfoInteger(MQL_DEBUG))
      Print("QUOTE SESSION DATA: ", packetType, " - ", packetData);
   
   // Parse JSON data
   CJAVal json;
   if(!json.Deserialize(packetData)) {
      Print("Error: Failed to parse packet data as JSON");
      return;
   }
   
   string symbolKey = "";
   
   // Extract the symbol key based on packet type
   if(packetType == "quote_completed") {
      // For quote_completed packets, symbol key is in the second element
      // Format in JS: packet.data[1]
      if(json.Size() >= 2) {
         symbolKey = json[1].ToStr();
      }
   }
   else if(packetType == "qsd") {
      // For qsd packets, symbol key is in data[1].n
      // Format in JS: packet.data[1].n
      if(json.Size() >= 2 && json[1].HasKey("n")) {
         symbolKey = json[1]["n"].ToStr();
      }
   }
   
   // Skip processing if we couldn't identify the symbol
   if(symbolKey == "") {
      Print("Warning: Could not extract symbol key from packet");
      return;
   }
   
   // Find matching symbol listeners
   bool foundListener = false;
   
   for(int i = 0; i < ArraySize(m_symbolListeners); i++) {
      if(m_symbolListeners[i].symbolKey == symbolKey && m_symbolListeners[i].active) {
         foundListener = true;
         
         // Forward this to the associated market instance
         if(i < ArraySize(m_marketInstances) && m_marketInstances[i] != NULL) {
            m_marketInstances[i].ProcessPacket(packetType, packetData);
         }
      }
   }
   
   // If no active listener was found, remove the symbol from the session
   if(!foundListener) {
      Print("No active listener found for symbol: ", symbolKey, " - removing from session");
      
      // Extract the actual symbol and session from the symbolKey
      string symbolStr = "";
      string sessionStr = "regular";
      
      if(ParseSymbolKey(symbolKey, symbolStr, sessionStr)) {
         // Remove the symbol
         Print("Removing symbol from session: ", symbolStr, " (", sessionStr, ")");
         // In a real implementation, you would send a message to TradingView API
      }
   }
}

//+------------------------------------------------------------------+
//| Delete the session                                                |
//+------------------------------------------------------------------+
void QuoteSession::Delete() {
   // In a real implementation, this would send a message to delete the session
   Print("Deleting quote session: ", m_sessionID);
   
   // Clean up symbol listeners
   ArrayFree(m_symbolListeners);
   
   // Clean up market instances
   for(int i = 0; i < ArraySize(m_marketInstances); i++) {
      if(m_marketInstances[i] != NULL) {
         delete m_marketInstances[i];
         m_marketInstances[i] = NULL;
      }
   }
   ArrayFree(m_marketInstances);
}

//+------------------------------------------------------------------+
//| Register a symbol listener callback                               |
//+------------------------------------------------------------------+
bool QuoteSession::RegisterSymbolCallback(string symbol, string session, int callbackFunc) {
   string symbolKey = "={\"session\":\"" + session + "\",\"symbol\":\"" + symbol + "\"}";
   
   // Create callback entry
   int size = ArraySize(m_symbolListeners);
   ArrayResize(m_symbolListeners, size + 1);
   m_symbolListeners[size].symbolKey = symbolKey;
   m_symbolListeners[size].id = size;
   m_symbolListeners[size].active = true;
   
   // In a complete implementation, we would store the callback function pointer
   
   return true;
}