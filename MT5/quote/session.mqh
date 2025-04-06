//+------------------------------------------------------------------+
//| QuoteSession class for MQL5                                      |
//+------------------------------------------------------------------+

#include "../include/JAson.mqh"
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
class QuoteSession : public Session {
private:
   string            m_sessionID;
   SymbolListener    m_symbolListeners[];
   QuoteMarket*      m_marketInstances[];
   
   // Quote fields
   string            m_fields[];
   
   // Session options
   struct QuoteSessionOptions {
      string         fieldsType;      // 'all' or 'price'
      string         customFields[];  // Custom fields if specified
   } m_options;
   
   // Private methods
   void              InitializeFields();
   bool              AddSymbolListener(string symbolKey);
   bool              RemoveSymbolListener(string symbolKey);
   void              CleanupMarkets();

public:
                     QuoteSession(QuoteSessionOptions &options);
                    ~QuoteSession();
   
   // Implement OnData method from Session base class
   virtual void      OnData(string packetType, CJAVal &data);
   
   // Market management
   QuoteMarket*      CreateMarket(string symbol, string session="regular");
   bool              AddSymbol(string symbol, string session="regular");
   bool              RemoveSymbol(string symbol, string session="regular");
   
   // Session management
   void              Delete();
   
   // Getters
   string            GetSessionID() const { return m_sessionID; }
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
QuoteSession::QuoteSession(QuoteSessionOptions &options) {
   m_sessionID = genSessionID("qs");
   m_options = options;
   
   // Initialize fields based on options
   InitializeFields();
   
   // Send session creation messages
   CJAVal createParams;
   createParams.Add(m_sessionID);
   Client::Send("quote_create_session", createParams);
   
   // Set fields
   CJAVal setFieldsParams;
   setFieldsParams.Add(m_sessionID);
   for(int i=0; i<ArraySize(m_fields); i++) {
      setFieldsParams.Add(m_fields[i]);
   }
   Client::Send("quote_set_fields", setFieldsParams);
}

//+------------------------------------------------------------------+
//| Initialize quote fields based on options                          |
//+------------------------------------------------------------------+
void QuoteSession::InitializeFields() {
   if(ArraySize(m_options.customFields) > 0) {
      // Use custom fields
      ArrayCopy(m_fields, m_options.customFields);
   }
   else {
      // Use predefined fields based on type
      if(m_options.fieldsType == "price") {
         ArrayResize(m_fields, 1);
         m_fields[0] = "lp";
      }
      else {
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
         
         ArrayCopy(m_fields, allFields);
      }
   }
}

//+------------------------------------------------------------------+
//| Process incoming data                                             |
//+------------------------------------------------------------------+
void QuoteSession::OnData(string packetType, CJAVal &data) {
   if(packetType == "quote_completed") {
      string symbolKey = data[1].ToStr();
      
      // Find and notify listeners
      for(int i=0; i<ArraySize(m_symbolListeners); i++) {
         if(m_symbolListeners[i].symbolKey == symbolKey) {
            if(m_marketInstances[i] != NULL) {
               m_marketInstances[i].ProcessPacket(packetType, data);
            }
         }
      }
   }
   else if(packetType == "qsd") {
      string symbolKey = data[1]["n"].ToStr();
      
      // Find and notify listeners
      for(int i=0; i<ArraySize(m_symbolListeners); i++) {
         if(m_symbolListeners[i].symbolKey == symbolKey) {
            if(m_marketInstances[i] != NULL) {
               m_marketInstances[i].ProcessPacket(packetType, data);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Create market instance                                            |
//+------------------------------------------------------------------+
QuoteMarket* QuoteSession::CreateMarket(string symbol, string session="regular") {
   string symbolKey = "={\"session\":\"" + session + "\",\"symbol\":\"" + symbol + "\"}";
   
   // Add symbol listener if needed
   if(AddSymbolListener(symbolKey)) {
      int index = ArraySize(m_symbolListeners) - 1;
      m_marketInstances[index] = new QuoteMarket(this, symbol, session);
      return m_marketInstances[index];
   }
   
   return NULL;
}

//+------------------------------------------------------------------+
//| Add symbol listener                                               |
//+------------------------------------------------------------------+
bool QuoteSession::AddSymbolListener(string symbolKey) {
   // Check if already exists
   for(int i=0; i<ArraySize(m_symbolListeners); i++) {
      if(m_symbolListeners[i].symbolKey == symbolKey) {
         return false;
      }
   }
   
   // Add new listener
   int size = ArraySize(m_symbolListeners);
   ArrayResize(m_symbolListeners, size + 1);
   ArrayResize(m_marketInstances, size + 1);
   
   m_symbolListeners[size].symbolKey = symbolKey;
   m_symbolListeners[size].id = size;
   m_symbolListeners[size].active = true;
   
   // Send add symbol message
   CJAVal params;
   params.Add(m_sessionID);
   params.Add(symbolKey);
   Client::Send("quote_add_symbols", params);
   
   return true;
}

//+------------------------------------------------------------------+
//| Remove symbol listener                                            |
//+------------------------------------------------------------------+
bool QuoteSession::RemoveSymbolListener(string symbolKey) {
   for(int i=0; i<ArraySize(m_symbolListeners); i++) {
      if(m_symbolListeners[i].symbolKey == symbolKey) {
         // Send remove symbol message
         CJAVal params;
         params.Add(m_sessionID);
         params.Add(symbolKey);
         Client::Send("quote_remove_symbols", params);
         
         // Cleanup market instance
         if(m_marketInstances[i] != NULL) {
            delete m_marketInstances[i];
            m_marketInstances[i] = NULL;
         }
         
         m_symbolListeners[i].active = false;
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Delete session                                                    |
//+------------------------------------------------------------------+
void QuoteSession::Delete() {
   // Send delete session message
   CJAVal params;
   params.Add(m_sessionID);
   Client::Send("quote_delete_session", params);
   
   // Cleanup markets
   CleanupMarkets();
}

//+------------------------------------------------------------------+
//| Cleanup market instances                                          |
//+------------------------------------------------------------------+
void QuoteSession::CleanupMarkets() {
   for(int i=0; i<ArraySize(m_marketInstances); i++) {
      if(m_marketInstances[i] != NULL) {
         delete m_marketInstances[i];
         m_marketInstances[i] = NULL;
      }
   }
   
   ArrayFree(m_marketInstances);
   ArrayFree(m_symbolListeners);
}