//+------------------------------------------------------------------+
//|                                                     session.mqh   |
//|                                          TradingView API for MT5  |
//+------------------------------------------------------------------+
#property copyright "TradingView API"
#property link      ""
#property version   "1.00"
#property strict

#include "../utils.mqh"
#include "study.mqh"

// Chart Types enumeration
enum ChartType {
   CHART_TYPE_NORMAL,
   CHART_TYPE_HEIKIN_ASHI,
   CHART_TYPE_RENKO,
   CHART_TYPE_LINE_BREAK,
   CHART_TYPE_KAGI,
   CHART_TYPE_POINT_AND_FIGURE,
   CHART_TYPE_RANGE
};

// Chart Type IDs dictionary
string ChartTypes[7] = {
   "",
   "BarSetHeikenAshi@tv-basicstudies-60!",
   "BarSetRenko@tv-prostudies-40!",
   "BarSetPriceBreak@tv-prostudies-34!",
   "BarSetKagi@tv-prostudies-34!",
   "BarSetPnF@tv-prostudies-34!",
   "BarSetRange@tv-basicstudies-72!"
};

// Price period structure
struct PricePeriod {
   datetime time;    // Period timestamp
   double open;      // Period open value
   double close;     // Period close value
   double high;      // Period max value
   double low;       // Period min value
   double volume;    // Period volume value
};

// Subsession structure
struct Subsession {
   string id;                  // Subsession ID (ex: 'regular')
   string description;         // Subsession description (ex: 'Regular')
   bool isPrivate;             // If private
   string session;             // Session (ex: '24x7')
   string sessionCorrection;   // Session correction
   string sessionDisplay;      // Session display (ex: '24x7')
};

// Market Infos structure
struct MarketInfos {
   string seriesId;            // Used series (ex: 'ser_1')
   string baseCurrency;        // Base currency (ex: 'BTC')
   string baseCurrencyId;      // Base currency ID (ex: 'XTVCBTC')
   string name;                // Market short name (ex: 'BTCEUR')
   string fullName;            // Market full name (ex: 'COINBASE:BTCEUR')
   string proName;             // Market pro name (ex: 'COINBASE:BTCEUR')
   string description;         // Market symbol description (ex: 'BTC/EUR')
   string shortDescription;    // Market symbol short description (ex: 'BTC/EUR')
   string exchange;            // Market exchange (ex: 'COINBASE')
   string listedExchange;      // Market exchange (ex: 'COINBASE')
   string providerId;          // Values provider ID (ex: 'coinbase')
   string currencyId;          // Used currency ID (ex: 'EUR')
   string currencyCode;        // Used currency code (ex: 'EUR')
   string variableTickSize;    // Variable tick size
   int pricescale;             // Price scale
   double pointvalue;          // Point value
   string session;             // Session (ex: '24x7')
   string sessionDisplay;      // Session display (ex: '24x7')
   string type;                // Market type (ex: 'crypto')
   bool hasIntraday;           // If intraday values are available
   bool fractional;            // If market is fractional
   bool isTradable;            // If the market is curently tradable
   double minmov;              // Minimum move value
   double minmove2;            // Minimum move value 2
   string timezone;            // Used timezone
   bool isReplayable;          // If the replay mode is available
   bool hasAdjustment;         // If the adjustment mode is enabled
   bool hasExtendedHours;      // Has extended hours
   string barSource;           // Bar source
   string barTransform;        // Bar transform
   bool barFillgaps;           // Bar fill gaps
   string allowedAdjustment;   // Allowed adjustment (ex: 'none')
   string subsessionId;        // Subsession ID (ex: 'regular')
   string proPerm;             // Pro permission (ex: '')
};

// Chart Input options structure
struct ChartInputs {
   int atrLength;               // Renko/Kagi/PointAndFigure ATR length
   string source;               // Renko/LineBreak/Kagi source
   string style;                // Renko/Kagi/PointAndFigure style
   double boxSize;              // Renko/PointAndFigure box size
   double reversalAmount;       // Kagi/PointAndFigure reversal amount
   string sources;              // Renko/PointAndFigure sources
   bool wicks;                  // Renko wicks
   int lb;                      // LineBreak Line break
   bool oneStepBackBuilding;    // PointAndFigure oneStepBackBuilding
   bool phantomBars;            // Range phantom bars
   double range;                // Range range
};

// Callback function types
typedef void (*SymbolLoadedCallback)();
typedef void (*UpdateCallback)(string&[]);
typedef void (*ReplayLoadedCallback)(string);
typedef void (*ReplayPointCallback)(int);
typedef void (*ReplayResolutionCallback)(string, int);
typedef void (*ReplayEndCallback)();
typedef void (*ErrorCallback)(string);

// ChartSession class
class ChartSession : public Session {
private:
   // Session IDs
   string chartSessionID;       // Chart session ID
   string replaySessionID;      // Replay session ID
   
   // Control flags
   bool replayMode;             // Replay mode flag
   int currentSeries;           // Current series counter
   bool seriesCreated;          // Series created flag
   
   // Data structures
   MarketInfos infos;           // Market infos
   PricePeriod periods[];       // Table of periods values indexed by timestamp
   
   // Study management 
   CHashMap<string, CArrayObj*> studyListeners;
   CHashMap<int, int> indexes;
   
   // Callbacks
   CArrayObj* symbolLoadedCallbacks;
   CArrayObj* updateCallbacks;
   CArrayObj* replayLoadedCallbacks;
   CArrayObj* replayPointCallbacks;
   CArrayObj* replayResolutionCallbacks;
   CArrayObj* replayEndCallbacks;
   CArrayObj* errorCallbacks;
   
   // Client connection reference
   ClientBridge* client;

   // Private methods
   void HandleEvent(string eventName, string data[]);
   void HandleError(string message);
   
public:
   // Constructor and destructor
   ChartSession(ClientBridge* clientBridge);
   ~ChartSession();
   
   // Implement OnData method from Session base class
   virtual void OnData(string packetType, CJAVal &data);
   
   // Chart management methods
   void SetSeries(string timeframe = "240", int range = 100, datetime reference = 0);
   void SetMarket(string symbol, 
                  string timeframe = "",
                  int range = 100,
                  datetime to = 0,
                  string adjustment = "splits",
                  bool backadjustment = false,
                  string sessionType = "",
                  string currency = "",
                  ChartType type = CHART_TYPE_NORMAL,
                  ChartInputs &inputs = NULL,
                  datetime replay = 0);
   
   void SetTimezone(string timezone);
   void FetchMore(int number = 1);
   
   // Replay methods
   bool ReplayStep(int number = 1);
   bool ReplayStart(int interval = 1000);
   bool ReplayStop();
   
   // Event handling methods
   void OnSymbolLoaded(SymbolLoadedCallback callback);
   void OnUpdate(UpdateCallback callback);
   void OnReplayLoaded(ReplayLoadedCallback callback);
   void OnReplayPoint(ReplayPointCallback callback);
   void OnReplayResolution(ReplayResolutionCallback callback);
   void OnReplayEnd(ReplayEndCallback callback);
   void OnError(ErrorCallback callback);
   
   // Data access methods
   MarketInfos GetInfos() { return infos; }
   void GetPeriods(PricePeriod &resultPeriods[]);
   
   // Study management
   Study* CreateStudy();
   
   // Session management
   void Delete();
};

// Constructor implementation
ChartSession::ChartSession(ClientBridge* clientBridge) {
   client = clientBridge;
   chartSessionID = genSessionID("cs");
   replaySessionID = genSessionID("rs");
   replayMode = false;
   currentSeries = 0;
   seriesCreated = false;
   
   // Set base class properties
   type = "chart";
   sessionId = chartSessionID;
   
   // Initialize callback arrays
   symbolLoadedCallbacks = new CArrayObj();
   updateCallbacks = new CArrayObj();
   replayLoadedCallbacks = new CArrayObj();
   replayPointCallbacks = new CArrayObj();
   replayResolutionCallbacks = new CArrayObj();
   replayEndCallbacks = new CArrayObj();
   errorCallbacks = new CArrayObj();
   
   // Register chart session with client
   client.RegisterSession(chartSessionID, this);
   
   // Create chart session
   client.SendPacket("chart_create_session", chartSessionID);
}

// Destructor implementation
ChartSession::~ChartSession() {
   Delete();
   
   // Free callback arrays
   delete symbolLoadedCallbacks;
   delete updateCallbacks;
   delete replayLoadedCallbacks;
   delete replayPointCallbacks;
   delete replayResolutionCallbacks;
   delete replayEndCallbacks;
   delete errorCallbacks;
}

//+------------------------------------------------------------------+
//| Process an incoming packet from the client                        |
//+------------------------------------------------------------------+
void ChartSession::OnData(string packetType, CJAVal &data) {
   // Debug output
   if(MQLInfoInteger(MQL_DEBUG))
      Print("CHART SESSION DATA: ", packetType);
      
   if(packetType == "symbol_resolved") {
      // Update market infos
      infos.seriesId = data[1].ToStr();
      // Extract other info fields from data[2]
      // ...implementation...
      
      // Trigger symbol loaded event
      string dummy[];
      HandleEvent("symbolLoaded", dummy);
      return;
   }
   
   if(packetType == "timescale_update" || packetType == "du") {
      // Process update data
      string changes[];
      
      if(data[1].HasKey("$prices")) {
         CJAVal prices = data[1]["$prices"];
         if(prices.HasKey("s")) {
            CJAVal series = prices["s"];
            for(int i=0; i<series.Size(); i++) {
               CJAVal point = series[i];
               if(point.HasKey("v") && point["v"].Size() >= 6) {
                  int timestamp = (int)point["v"][0].ToDbl();
                  
                  // Create a new period entry
                  int size = ArraySize(periods);
                  ArrayResize(periods, size + 1);
                  
                  periods[size].time = (datetime)timestamp;
                  periods[size].open = point["v"][1].ToDbl();
                  periods[size].high = point["v"][2].ToDbl();
                  periods[size].low = point["v"][3].ToDbl();
                  periods[size].close = point["v"][4].ToDbl();
                  periods[size].volume = point["v"][5].ToDbl();
               }
            }
         }
         
         // Add "$prices" to the changed fields
         ArrayResize(changes, 1);
         changes[0] = "$prices";
      }
      
      // Forward to event handler
      HandleEvent("update", changes);
      return;
   }
   
   if(packetType == "symbol_error") {
      string errorMsg = data[2].ToStr();
      HandleError(StringFormat("Symbol error (%s): %s", data[1].ToStr(), errorMsg));
      return;
   }
   
   if(packetType == "series_error") {
      HandleError("Series error: " + data[3].ToStr());
      return;
   }
   
   if(packetType == "critical_error") {
      HandleError(StringFormat("Critical error: %s - %s", data[1].ToStr(), data[2].ToStr()));
      return;
   }
   
   // Handle replay-related packets if needed
   // ...implementation...
}

// Set chart series implementation
void ChartSession::SetSeries(string timeframe = "240", int range = 100, datetime reference = 0) {
   if(currentSeries == 0) {
      HandleError("Please set the market before setting series");
      return;
   }

   // Reset periods array
   ArrayResize(periods, 0);

   string calcRange[];
   if(reference == 0) {
      // Just use range
      ArrayResize(calcRange, 1);
      calcRange[0] = IntegerToString(range);
   } else {
      // Use bar count with reference timestamp
      ArrayResize(calcRange, 3);
      calcRange[0] = "bar_count";
      calcRange[1] = IntegerToString(reference);
      calcRange[2] = IntegerToString(range);
   }

   string cmd = seriesCreated ? "modify_series" : "create_series";
   string params[];
   ArrayResize(params, 6);
   params[0] = chartSessionID;
   params[1] = "$prices";
   params[2] = "s1";
   params[3] = "ser_" + IntegerToString(currentSeries);
   params[4] = timeframe;
   params[5] = seriesCreated ? "" : JSON::Stringify(calcRange);
   
   client.SendPacket(cmd, params);
   seriesCreated = true;
}

// Set market implementation
void ChartSession::SetMarket(string symbol, 
                string timeframe = "",
                int range = 100,
                datetime to = 0,
                string adjustment = "splits",
                bool backadjustment = false,
                string sessionType = "",
                string currency = "",
                ChartType type = CHART_TYPE_NORMAL,
                ChartInputs &inputs = NULL,
                datetime replay = 0) {
   
   // Reset periods array
   ArrayResize(periods, 0);

   if(replayMode) {
      replayMode = false;
      client.SendPacket("replay_delete_session", replaySessionID);
   }

   // Create symbol initialization object
   JSON::Object symbolInit;
   symbolInit.Set("symbol", symbol == "" ? "BTCEUR" : symbol);
   symbolInit.Set("adjustment", adjustment);
   
   if(backadjustment) symbolInit.Set("backadjustment", "default");
   if(sessionType != "") symbolInit.Set("session", sessionType);
   if(currency != "") symbolInit.Set("currency-id", currency);

   // Handle replay mode
   if(replay > 0) {
      if(!replayMode) {
         replayMode = true;
         client.SendPacket("replay_create_session", replaySessionID);
      }
      
      string replayParams[];
      ArrayResize(replayParams, 4);
      replayParams[0] = replaySessionID;
      replayParams[1] = "req_replay_addseries";
      replayParams[2] = "=" + JSON::Stringify(symbolInit);
      replayParams[3] = timeframe;
      
      client.SendPacket("replay_add_series", replayParams);
      
      string resetParams[];
      ArrayResize(resetParams, 3);
      resetParams[0] = replaySessionID;
      resetParams[1] = "req_replay_reset";
      resetParams[2] = IntegerToString(replay);
      
      client.SendPacket("replay_reset", resetParams);
   }

   // Determine if complex chart initialization is needed
   bool complex = (type != CHART_TYPE_NORMAL || replay > 0);
   JSON::Object chartInit;
   
   if(complex) {
      if(replay > 0) chartInit.Set("replay", replaySessionID);
      chartInit.Set("symbol", symbolInit);
      
      if(type != CHART_TYPE_NORMAL) {
         chartInit.Set("type", ChartTypes[type]);
         
         if(inputs != NULL) {
            JSON::Object inputsObj;
            // For each input property, add to inputs object
            // In a real implementation, would need to check which properties are set
            chartInit.Set("inputs", inputsObj);
         }
      }
   }

   // Increment current series
   currentSeries++;

   // Send resolve symbol request
   string resolveParams[];
   ArrayResize(resolveParams, 3);
   resolveParams[0] = chartSessionID;
   resolveParams[1] = "ser_" + IntegerToString(currentSeries);
   resolveParams[2] = "=" + (complex ? JSON::Stringify(chartInit) : JSON::Stringify(symbolInit));
   
   client.SendPacket("resolve_symbol", resolveParams);

   // Set series with the provided timeframe and range
   SetSeries(timeframe, range, to);
}

// Set timezone implementation
void ChartSession::SetTimezone(string timezone) {
   // Reset periods array
   ArrayResize(periods, 0);
   
   string params[];
   ArrayResize(params, 2);
   params[0] = chartSessionID;
   params[1] = timezone;
   
   client.SendPacket("switch_timezone", params);
}

// Fetch more data implementation
void ChartSession::FetchMore(int number = 1) {
   string params[];
   ArrayResize(params, 3);
   params[0] = chartSessionID;
   params[1] = "$prices";
   params[2] = IntegerToString(number);
   
   client.SendPacket("request_more_data", params);
}

// Replay step implementation
bool ChartSession::ReplayStep(int number = 1) {
   if(!replayMode) {
      HandleError("No replay session");
      return false;
   }
   
   string reqID = genSessionID("rsq_step");
   string params[];
   ArrayResize(params, 3);
   params[0] = replaySessionID;
   params[1] = reqID;
   params[2] = IntegerToString(number);
   
   client.SendPacket("replay_step", params);
   return true;
}

// Replay start implementation
bool ChartSession::ReplayStart(int interval = 1000) {
   if(!replayMode) {
      HandleError("No replay session");
      return false;
   }
   
   string reqID = genSessionID("rsq_start");
   string params[];
   ArrayResize(params, 3);
   params[0] = replaySessionID;
   params[1] = reqID;
   params[2] = IntegerToString(interval);
   
   client.SendPacket("replay_start", params);
   return true;
}

// Replay stop implementation
bool ChartSession::ReplayStop() {
   if(!replayMode) {
      HandleError("No replay session");
      return false;
   }
   
   string reqID = genSessionID("rsq_stop");
   string params[];
   ArrayResize(params, 2);
   params[0] = replaySessionID;
   params[1] = reqID;
   
   client.SendPacket("replay_stop", params);
   return true;
}

// Get periods implementation
void ChartSession::GetPeriods(PricePeriod &resultPeriods[]) {
   int size = ArraySize(periods);
   ArrayResize(resultPeriods, size);
   
   // Sort periods by time (newest first)
   PricePeriod tempPeriods[];
   ArrayCopy(tempPeriods, periods);
   
   // Simple bubble sort
   for(int i = 0; i < size; i++) {
      for(int j = 0; j < size - i - 1; j++) {
         if(tempPeriods[j].time < tempPeriods[j+1].time) {
            PricePeriod temp = tempPeriods[j];
            tempPeriods[j] = tempPeriods[j+1];
            tempPeriods[j+1] = temp;
         }
      }
   }
   
   // Copy sorted periods to result
   ArrayCopy(resultPeriods, tempPeriods);
}

// Handler for handling events
void ChartSession::HandleEvent(string eventName, string data[]) {
   // Implement event handling based on event name
   if(eventName == "symbolLoaded") {
      for(int i = 0; i < symbolLoadedCallbacks.Total(); i++) {
         SymbolLoadedCallback callback = (SymbolLoadedCallback)symbolLoadedCallbacks.At(i);
         if(callback != NULL) callback();
      }
   }
   
   // Additional event handling implementations would go here for other event types
}

// Handler for errors
void ChartSession::HandleError(string message) {
   if(errorCallbacks.Total() == 0) {
      Print("ERROR: ", message);
   } else {
      for(int i = 0; i < errorCallbacks.Total(); i++) {
         ErrorCallback callback = (ErrorCallback)errorCallbacks.At(i);
         if(callback != NULL) callback(message);
      }
   }
}

// Event registration methods
void ChartSession::OnSymbolLoaded(SymbolLoadedCallback callback) {
   symbolLoadedCallbacks.Add(callback);
}

void ChartSession::OnUpdate(UpdateCallback callback) {
   updateCallbacks.Add(callback);
}

void ChartSession::OnReplayLoaded(ReplayLoadedCallback callback) {
   replayLoadedCallbacks.Add(callback);
}

void ChartSession::OnReplayPoint(ReplayPointCallback callback) {
   replayPointCallbacks.Add(callback);
}

void ChartSession::OnReplayResolution(ReplayResolutionCallback callback) {
   replayResolutionCallbacks.Add(callback);
}

void ChartSession::OnReplayEnd(ReplayEndCallback callback) {
   replayEndCallbacks.Add(callback);
}

void ChartSession::OnError(ErrorCallback callback) {
   errorCallbacks.Add(callback);
}

// Create study implementation
Study* ChartSession::CreateStudy() {
   // Create and return a new Study object
   return new Study(chartSessionID, &studyListeners, &indexes, client);
}

// Delete implementation
void ChartSession::Delete() {
   if(replayMode) {
      client.SendPacket("replay_delete_session", replaySessionID);
   }
   
   client.SendPacket("chart_delete_session", chartSessionID);
   client.UnregisterSession(chartSessionID);
   client.UnregisterSession(replaySessionID);
   replayMode = false;
}
