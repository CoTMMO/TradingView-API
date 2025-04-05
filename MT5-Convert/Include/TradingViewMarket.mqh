//+------------------------------------------------------------------+
//|                                              TradingViewMarket.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd.   |
//|                                             https://www.mql5.com   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include "TradingViewAPI.mqh"

//+------------------------------------------------------------------+
//| TradingView Market Data Class                                     |
//+------------------------------------------------------------------+
class CTradingViewMarket
{
private:
   string            m_symbol;
   string            m_session;
   double            m_lastPrice;
   double            m_bid;
   double            m_ask;
   datetime          m_lastUpdate;
   
   // Event handlers
   CArrayObj         m_dataHandlers;
   CArrayObj         m_errorHandlers;
   
   // Reference to API client
   CTradingViewAPI*  m_api;
   
public:
                     CTradingViewMarket(string symbol, string session = "regular")
   {
      m_symbol = symbol;
      m_session = session;
      m_lastPrice = 0;
      m_bid = 0;
      m_ask = 0;
      m_lastUpdate = 0;
      m_api = NULL;
   }
   
                    ~CTradingViewMarket()
   {
      if(m_api != NULL) {
         m_api.UnsubscribeSymbol(m_symbol);
      }
   }
   
   // Market data methods
   bool              Update()
   {
      if(m_api == NULL) return false;
      
      // Subscribe to symbol if not already subscribed
      if(!m_api.SubscribeSymbol(m_symbol)) {
         return false;
      }
      
      return true;
   }
   
   double            GetLastPrice() const { return m_lastPrice; }
   double            GetBid() const { return m_bid; }
   double            GetAsk() const { return m_ask; }
   datetime          GetLastUpdate() const { return m_lastUpdate; }
   
   // Event handlers
   void              OnData(CArrayObj* handler)
   {
      m_dataHandlers.Add(handler);
   }
   
   void              OnError(CArrayObj* handler)
   {
      m_errorHandlers.Add(handler);
   }
   
   // Set API client reference
   void              SetAPI(CTradingViewAPI* api)
   {
      m_api = api;
   }
   
   // Process market data update
   void              ProcessUpdate(string data)
   {
      // Parse JSON data
      JSONParser parser;
      JSONValue json;
      
      if(!parser.parse(data, json)) {
         HandleError("Failed to parse market data");
         return;
      }
      
      // Extract market data
      if(json.has("v")) {
         JSONObject values = json["v"].toObject();
         
         if(values.has("lp")) m_lastPrice = values["lp"].toDouble();
         if(values.has("bid")) m_bid = values["bid"].toDouble();
         if(values.has("ask")) m_ask = values["ask"].toDouble();
         
         m_lastUpdate = TimeCurrent();
         
         // Trigger data event
         for(int i = 0; i < m_dataHandlers.Total(); i++) {
            CArrayObj* handler = m_dataHandlers.At(i);
            if(handler != NULL) handler.Execute();
         }
      }
   }
   
private:
   void              HandleError(string error)
   {
      // Trigger error event
      for(int i = 0; i < m_errorHandlers.Total(); i++) {
         CArrayObj* handler = m_errorHandlers.At(i);
         if(handler != NULL) handler.Execute();
      }
   }
}; 