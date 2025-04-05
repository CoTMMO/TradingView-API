//+------------------------------------------------------------------+
//|                                               TradingViewStudy.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd.   |
//|                                             https://www.mql5.com   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include "TradingViewAPI.mqh"

//+------------------------------------------------------------------+
//| TradingView Study/Indicator Class                                 |
//+------------------------------------------------------------------+
class CTradingViewStudy
{
private:
   string            m_name;
   string            m_script;
   string            m_inputs;
   
   // Event handlers
   CArrayObj         m_createdHandlers;
   CArrayObj         m_updateHandlers;
   CArrayObj         m_errorHandlers;
   
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
      m_api = NULL;
      m_valuesCount = 0;
   }
   
                    ~CTradingViewStudy()
   {
      if(m_api != NULL) {
         m_api.RemoveIndicator(m_name);
      }
   }
   
   // Study methods
   bool              Create()
   {
      if(m_api == NULL) return false;
      
      // Create study packet
      string studyData = StringFormat(
         "{\"m\":\"create_study\",\"p\":[\"%s\",\"%s\",%s]}",
         m_name,
         m_script,
         m_inputs
      );
      
      return m_api.SendPacket("study", studyData);
   }
   
   bool              SetInputs(string inputs)
   {
      if(m_api == NULL) return false;
      
      m_inputs = inputs;
      
      // Create update inputs packet
      string inputData = StringFormat(
         "{\"m\":\"update_study_inputs\",\"p\":[\"%s\",%s]}",
         m_name,
         m_inputs
      );
      
      return m_api.SendPacket("study", inputData);
   }
   
   // Event handlers
   void              OnCreated(CArrayObj* handler)
   {
      m_createdHandlers.Add(handler);
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
   
   // Process study data update
   void              ProcessUpdate(string data)
   {
      // Parse JSON data
      JSONParser parser;
      JSONValue json;
      
      if(!parser.parse(data, json)) {
         HandleError("Failed to parse study data");
         return;
      }
      
      // Extract study data
      if(json.has("s")) {
         // Study created
         for(int i = 0; i < m_createdHandlers.Total(); i++) {
            CArrayObj* handler = m_createdHandlers.At(i);
            if(handler != NULL) handler.Execute();
         }
      }
      else if(json.has("d")) {
         // Study data update
         JSONArray values = json["d"].toArray();
         
         // Resize values array if needed
         if(values.size() > m_valuesCount) {
            ArrayResize(m_values, values.size());
            m_valuesCount = values.size();
         }
         
         // Update values data
         for(int i = 0; i < values.size(); i++) {
            m_values[i] = values[i].toDouble();
         }
         
         // Trigger update event
         for(int i = 0; i < m_updateHandlers.Total(); i++) {
            CArrayObj* handler = m_updateHandlers.At(i);
            if(handler != NULL) handler.Execute();
         }
      }
   }
   
   // Get study data
   double*           GetValues() { return m_values; }
   int               GetValuesCount() const { return m_valuesCount; }
   
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