//+------------------------------------------------------------------+
//|                                               TradingViewChart.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd.   |
//|                                             https://www.mql5.com   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include "TradingViewAPI.mqh"

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
   CArrayObj         m_symbolLoadedHandlers;
   CArrayObj         m_updateHandlers;
   CArrayObj         m_errorHandlers;
   
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
      m_api = NULL;
      m_ratesCount = 0;
   }
   
                    ~CTradingViewChart()
   {
      if(m_api != NULL) {
         m_api.DeleteChartSession();
      }
   }
   
   // Chart methods
   bool              SetMarket(string symbol, ENUM_TIMEFRAME_TV timeframe = TIMEFRAME_TV_60, int range = 100)
   {
      if(m_api == NULL) return false;
      
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_range = range;
      
      // Create new chart session
      if(!m_api.CreateChartSession(m_symbol, m_timeframe)) {
         return false;
      }
      
      return true;
   }
   
   bool              SetTimezone(string timezone)
   {
      if(m_api == NULL) return false;
      
      // Create timezone change packet
      string timezoneData = StringFormat(
         "{\"m\":\"switch_timezone\",\"p\":[\"%s\"]}",
         timezone
      );
      
      return m_api.SendPacket("chart", timezoneData);
   }
   
   bool              FetchMore(int number = 1)
   {
      if(m_api == NULL) return false;
      
      // Create fetch more data packet
      string fetchData = StringFormat(
         "{\"m\":\"request_more_data\",\"p\":[\"%s\",%d]}",
         m_symbol,
         number
      );
      
      return m_api.SendPacket("chart", fetchData);
   }
   
   // Event handlers
   void              OnSymbolLoaded(CArrayObj* handler)
   {
      m_symbolLoadedHandlers.Add(handler);
   }
   
   void              OnUpdate(CArrayObj* handler)
   {
      m_updateHandlers.Add(handler);
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
   
   // Process chart data update
   void              ProcessUpdate(string data)
   {
      // Parse JSON data
      JSONParser parser;
      JSONValue json;
      
      if(!parser.parse(data, json)) {
         HandleError("Failed to parse chart data");
         return;
      }
      
      // Extract chart data
      if(json.has("s")) {
         // Symbol loaded
         for(int i = 0; i < m_symbolLoadedHandlers.Total(); i++) {
            CArrayObj* handler = m_symbolLoadedHandlers.At(i);
            if(handler != NULL) handler.Execute();
         }
      }
      else if(json.has("p")) {
         // Price data update
         JSONArray prices = json["p"].toArray();
         
         // Resize rates array if needed
         if(prices.size() > m_ratesCount) {
            ArrayResize(m_rates, prices.size());
            m_ratesCount = prices.size();
         }
         
         // Update rates data
         for(int i = 0; i < prices.size(); i++) {
            JSONArray price = prices[i].toArray();
            
            m_rates[i].time = (datetime)price[0].toInteger();
            m_rates[i].open = price[1].toDouble();
            m_rates[i].high = price[2].toDouble();
            m_rates[i].low = price[3].toDouble();
            m_rates[i].close = price[4].toDouble();
            m_rates[i].tick_volume = price[5].toDouble();
         }
         
         // Trigger update event
         for(int i = 0; i < m_updateHandlers.Total(); i++) {
            CArrayObj* handler = m_updateHandlers.At(i);
            if(handler != NULL) handler.Execute();
         }
      }
   }
   
   // Get chart data
   MqlRates*         GetRates() { return m_rates; }
   int               GetRatesCount() const { return m_ratesCount; }
   
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