//+------------------------------------------------------------------+
//| TradingView API - ChartStudy class                               |
//+------------------------------------------------------------------+
#include "../utils.mqh"
#include "../protocol.mqh"
#include "graphicParser.mqh"
#include "../classes/PineIndicator.mqh"
#include "../classes/BuiltInIndicator.mqh"

// Trade entry structure
struct TradeEntry {
   string            name;       // Trade name
   string            type;       // Entry type (long/short)
   double            value;      // Entry price value
   datetime          time;       // Entry timestamp
};

// Trade exit structure
struct TradeExit {
   string            name;       // Trade name ('' if false exit)
   double            value;      // Exit price value
   datetime          time;       // Exit timestamp
};

// Relative/Absolute Value structure
struct RelAbsValue {
   double            absolute;   // Absolute value
   double            percent;    // Percentage value
};

// Trade report structure
struct TradeReport {
   TradeEntry        entry;      // Trade entry
   TradeExit         exit;       // Trade exit
   double            quantity;   // Trade quantity
   RelAbsValue       profit;     // Trade profit
   RelAbsValue       cumulative; // Trade cumulative profit
   RelAbsValue       runup;      // Trade run-up
   RelAbsValue       drawdown;   // Trade drawdown
};

// Performance report structure
struct PerfReport {
   double            avgBarsInTrade;       // Average bars in trade
   double            avgBarsInWinTrade;    // Average bars in winning trade
   double            avgBarsInLossTrade;   // Average bars in losing trade
   double            avgTrade;             // Average trade gain
   double            avgTradePercent;      // Average trade performance
   double            avgLosTrade;          // Average losing trade gain
   double            avgLosTradePercent;   // Average losing trade performance
   double            avgWinTrade;          // Average winning trade gain
   double            avgWinTradePercent;   // Average winning trade performance
   double            commissionPaid;       // Commission paid
   double            grossLoss;            // Gross loss value
   double            grossLossPercent;     // Gross loss percent
   double            grossProfit;          // Gross profit
   double            grossProfitPercent;   // Gross profit percent
   double            largestLosTrade;      // Largest losing trade gain
   double            largestLosTradePercent; // Largest losing trade performance (percentage)
   double            largestWinTrade;      // Largest winning trade gain
   double            largestWinTradePercent; // Largest winning trade performance (percentage)
   int               marginCalls;          // Margin calls
   int               maxContractsHeld;     // Max Contracts Held
   double            netProfit;            // Net profit
   double            netProfitPercent;     // Net performance (percentage)
   int               numberOfLosingTrades; // Number of losing trades
   int               numberOfWiningTrades; // Number of winning trades
   double            percentProfitable;    // Strategy winrate
   double            profitFactor;         // Profit factor
   double            ratioAvgWinAvgLoss;   // Ratio Average Win / Average Loss
   int               totalOpenTrades;      // Total open trades
   int               totalTrades;          // Total trades
};

// FromTo structure
struct FromTo {
   datetime          from;       // From timestamp
   datetime          to;         // To timestamp
};

// Date range structure
struct DateRange {
   FromTo            backtest;   // Date range for backtest
   FromTo            trade;      // Date range for trade
};

// Settings structure
struct StrategySettings {
   DateRange         dateRange;  // Backtester date range
};

// History chart structure
struct HistoryChart {
   double            buyHold[];         // Buy hold values
   double            buyHoldPercent[];  // Buy hold percent values
   double            drawDown[];        // Drawdown values
   double            drawDownPercent[]; // Drawdown percent values
   double            equity[];          // Equity values
   double            equityPercent[];   // Equity percent values
};

// Performance structure
struct StrategyPerformance {
   PerfReport        all;                // Strategy long/short performances
   PerfReport        long;               // Strategy long performances
   PerfReport        short;              // Strategy short performances
   double            buyHoldReturn;      // Strategy Buy & Hold Return
   double            buyHoldReturnPercent; // Strategy Buy & Hold Return percent
   double            maxDrawDown;        // Strategy max drawdown
   double            maxDrawDownPercent; // Strategy max drawdown percent
   double            openPL;             // Strategy Open P&L (Profit And Loss)
   double            openPLPercent;      // Strategy Open P&L (Profit And Loss) percent
   double            sharpeRatio;        // Strategy Sharpe Ratio
   double            sortinoRatio;       // Strategy Sortino Ratio
};

// Strategy report structure
struct StrategyReport {
   string            currency;           // Selected currency
   StrategySettings  settings;           // Backtester settings
   TradeReport       trades[];           // Trade list starting by the last
   HistoryChart      history;            // History Chart value
   StrategyPerformance performance;      // Strategy performance
};

// Chart Period 
struct ChartPeriod {
   datetime          time;     // Period timestamp
   double            values[]; // Period values
};

// Event callback function typedefs
typedef void (*StudyCompletedCallback)();
typedef void (*UpdateCallback)(string changes[]);
typedef void (*ErrorCallback)(string message);
typedef void (*EventCallback)(string eventType, string data);

// Helper function to get pine inputs
string GetInputs(PineIndicator *pineIndicator, BuiltInIndicator *builtInIndicator, bool &isPine) {
   CJAVal inputs;
   
   if(pineIndicator != NULL) {
      isPine = true;
      inputs["text"] = pineIndicator.GetScript();
      
      string pineId = pineIndicator.GetPineId();
      string pineVersion = pineIndicator.GetPineVersion();
      
      if(pineId != "") inputs["pineId"] = pineId;
      if(pineVersion != "") inputs["pineVersion"] = pineVersion;
      
      // Would need to implement input conversion here
      // This is a simplified version
      
      return inputs.Serialize();
   }
   else if(builtInIndicator != NULL) {
      isPine = false;
      // Convert built-in indicator options to JSON
      IndicatorOptions *options = builtInIndicator.GetOptions();
      
      // Simplified conversion - in full implementation would need to convert all options
      if(options.rowsLayout != "") inputs["rowsLayout"] = options.rowsLayout;
      if(options.rows > 0) inputs["rows"] = options.rows;
      if(options.volume != "") inputs["volume"] = options.volume;
      if(options.vaVolume > 0) inputs["vaVolume"] = options.vaVolume;
      inputs["subscribeRealtime"] = options.subscribeRealtime;
      
      return inputs.Serialize();
   }
   
   return "";
}

// Helper function to parse trades
void ParseTrades(CJAVal &tradesJson, TradeReport &trades[]) {
   int size = tradesJson.Size();
   if(size <= 0) return;
   
   ArrayResize(trades, size);
   
   // Process in reverse order
   for(int i = 0; i < size; i++) {
      CJAVal trade = tradesJson[size - i - 1]; // Reverse the order
      
      // Parse entry
      CJAVal entry = trade["e"];
      trades[i].entry.name = entry["c"].ToStr();
      trades[i].entry.type = (StringSubstr(entry["tp"].ToStr(), 0, 1) == "s") ? "short" : "long";
      trades[i].entry.value = entry["p"].ToDbl();
      trades[i].entry.time = (datetime)entry["tm"].ToInt();
      
      // Parse exit
      CJAVal exit = trade["x"];
      trades[i].exit.name = exit["c"].ToStr();
      trades[i].exit.value = exit["p"].ToDbl();
      trades[i].exit.time = (datetime)exit["tm"].ToInt();
      
      // Parse other values
      trades[i].quantity = trade["q"].ToDbl();
      
      // Parse profit
      trades[i].profit.absolute = trade["tp"].ToDbl();
      // Note: percent value would need to be calculated or retrieved from extended data
      
      // Parse cumulative
      trades[i].cumulative.absolute = trade["cp"].ToDbl();
      // Note: percent value would need to be calculated or retrieved from extended data
      
      // Parse runup and drawdown
      trades[i].runup.absolute = trade["rn"].ToDbl();
      trades[i].drawdown.absolute = trade["dd"].ToDbl();
   }
}

//+------------------------------------------------------------------+
//| ChartStudy class                                                 |
//+------------------------------------------------------------------+
class ChartStudy {
private:
   string            m_studyId;
   PineIndicator*    m_pineIndicator;
   BuiltInIndicator* m_builtInIndicator;
   bool              m_isPineIndicator;
   
   // Periods storage
   ChartPeriod       m_periods[];
   int               m_indexes[];
   GraphicData       m_graphic;
   StrategyReport    m_strategyReport;
   
   // Callbacks
   StudyCompletedCallback m_onCompletedCallbacks[];
   UpdateCallback    m_onUpdateCallbacks[];
   ErrorCallback     m_onErrorCallbacks[];
   EventCallback     m_onEventCallbacks[];
   
   // Session reference
   void*             m_chartSession;
   
   // Helper method to fire completion callbacks
   void FireCompletedCallbacks() {
      for(int i = 0; i < ArraySize(m_onCompletedCallbacks); i++) {
         if(m_onCompletedCallbacks[i] != NULL) {
            m_onCompletedCallbacks[i]();
         }
      }
   }
   
   // Helper method to fire update callbacks
   void FireUpdateCallbacks(string &changes[]) {
      for(int i = 0; i < ArraySize(m_onUpdateCallbacks); i++) {
         if(m_onUpdateCallbacks[i] != NULL) {
            m_onUpdateCallbacks[i](changes);
         }
      }
   }
   
   // Helper method to fire error callbacks
   void FireErrorCallbacks(string message) {
      if(ArraySize(m_onErrorCallbacks) == 0) {
         Print("ERROR: ", message);
      } else {
         for(int i = 0; i < ArraySize(m_onErrorCallbacks); i++) {
            if(m_onErrorCallbacks[i] != NULL) {
               m_onErrorCallbacks[i](message);
            }
         }
      }
   }
   
   // Helper method to fire event callbacks
   void FireEventCallbacks(string eventType, string data = "") {
      for(int i = 0; i < ArraySize(m_onEventCallbacks); i++) {
         if(m_onEventCallbacks[i] != NULL) {
            m_onEventCallbacks[i](eventType, data);
         }
      }
   }
   
   // Sort periods by time (newest first)
   void SortPeriods() {
      // Sort periods by timestamp in descending order (newest first)
      ArraySort(m_periods, WHOLE_ARRAY, 0, MODE_DESCEND);
   }
   
   // Convert string color to MQL color
   color StringToColor(string colorStr) {
      // Handle hex format #RRGGBB or #RRGGBBAA
      if(StringGetCharacter(colorStr, 0) == '#') {
         string hexColor = StringSubstr(colorStr, 1);
         int r = (int)StringToInteger(StringSubstr(hexColor, 0, 2), 16);
         int g = (int)StringToInteger(StringSubstr(hexColor, 2, 2), 16);
         int b = (int)StringToInteger(StringSubstr(hexColor, 4, 2), 16);
         
         // Optional alpha component
         if(StringLen(hexColor) >= 8) {
            int a = (int)StringToInteger(StringSubstr(hexColor, 6, 2), 16);
            return (color)((r << 16) | (g << 8) | b); // Alpha is not used in MQL5 color
         }
         
         return (color)((r << 16) | (g << 8) | b);
      }
      
      // Handle named colors
      if(colorStr == "red") return clrRed;
      if(colorStr == "green") return clrGreen;
      if(colorStr == "blue") return clrBlue;
      if(colorStr == "black") return clrBlack;
      if(colorStr == "white") return clrWhite;
      if(colorStr == "yellow") return clrYellow;
      if(colorStr == "orange") return clrOrange;
      // Add more named colors as needed
      
      return clrNONE; // Default color
   }
   
   // Parse line style from string
   ENUM_LINE_STYLE ParseLineStyle(string style) {
      if(style == "solid") return STYLE_SOLID;
      if(style == "dash") return STYLE_DASH;
      if(style == "dot") return STYLE_DOT;
      if(style == "dashdot") return STYLE_DASHDOT;
      if(style == "dashdotdot") return STYLE_DASHDOTDOT;
      
      return STYLE_SOLID; // Default style
   }
   
   // Remove a graphic item by ID from an array
   template<typename T>
   void RemoveGraphicItemById(T &items[], int id) {
      int size = ArraySize(items);
      for(int i = 0; i < size; i++) {
         if(items[i].id == id) {
            // Remove item by shifting all elements
            for(int j = i; j < size - 1; j++) {
               items[j] = items[j + 1];
            }
            ArrayResize(items, size - 1);
            break;
         }
      }
   }
   
   // Decompress Base64 encoded data
   string DecompressBase64Data(string compressedData) {
      // In practice, this would use a decompression library
      // For MQL5, custom implementation would be needed for this
      
      // This is a simplified placeholder
      return compressedData; // In real implementation, this would decompress the data
   }
   
   // Parse performance metrics section
   void ParsePerformanceSection(CJAVal &source, PerfReport &target) {
      if(source.IsNull()) return;
      
      target.avgBarsInTrade = source["avgBarsInTrade"].ToDbl();
      target.avgBarsInWinTrade = source["avgBarsInWinTrade"].ToDbl();
      target.avgBarsInLossTrade = source["avgBarsInLossTrade"].ToDbl();
      target.avgTrade = source["avgTrade"].ToDbl();
      target.avgTradePercent = source["avgTradePercent"].ToDbl();
      target.avgLosTrade = source["avgLosTrade"].ToDbl();
      target.avgLosTradePercent = source["avgLosTradePercent"].ToDbl();
      target.avgWinTrade = source["avgWinTrade"].ToDbl();
      target.avgWinTradePercent = source["avgWinTradePercent"].ToDbl();
      target.commissionPaid = source["commissionPaid"].ToDbl();
      target.grossLoss = source["grossLoss"].ToDbl();
      target.grossLossPercent = source["grossLossPercent"].ToDbl();
      target.grossProfit = source["grossProfit"].ToDbl();
      target.grossProfitPercent = source["grossProfitPercent"].ToDbl();
      target.largestLosTrade = source["largestLosTrade"].ToDbl();
      target.largestLosTradePercent = source["largestLosTradePercent"].ToDbl();
      target.largestWinTrade = source["largestWinTrade"].ToDbl();
      target.largestWinTradePercent = source["largestWinTradePercent"].ToDbl();
      target.marginCalls = source["marginCalls"].ToInt();
      target.maxContractsHeld = source["maxContractsHeld"].ToInt();
      target.netProfit = source["netProfit"].ToDbl();
      target.netProfitPercent = source["netProfitPercent"].ToDbl();
      target.numberOfLosingTrades = source["numberOfLosingTrades"].ToInt();
      target.numberOfWiningTrades = source["numberOfWiningTrades"].ToInt();
      target.percentProfitable = source["percentProfitable"].ToDbl();
      target.profitFactor = source["profitFactor"].ToDbl();
      target.ratioAvgWinAvgLoss = source["ratioAvgWinAvgLoss"].ToDbl();
      target.totalOpenTrades = source["totalOpenTrades"].ToInt();
      target.totalTrades = source["totalTrades"].ToInt();
   }
   
public:
   // Constructor
   ChartStudy(PineIndicator *pineIndicator, BuiltInIndicator *builtInIndicator = NULL) {
      m_studyId = genSessionID("st");
      
      if(pineIndicator == NULL && builtInIndicator == NULL) {
         FireErrorCallbacks("Indicator argument must be an instance of PineIndicator or BuiltInIndicator");
         return;
      }
      
      m_pineIndicator = pineIndicator;
      m_builtInIndicator = builtInIndicator;
      m_isPineIndicator = (pineIndicator != NULL);
      
      // Initialize other members
      ZeroMemory(m_strategyReport);
      
      // Create study (Note: actual WebSocket communication would be handled by the session)
      bool isPine;
      string inputsJson = GetInputs(pineIndicator, builtInIndicator, isPine);
      
      // In a real implementation, this would send a message through WebSocket
      // chartSession.send("create_study", [sessionID, studyID, "st1", "$prices", indicatorType, inputsJson]);
   }
   
   // Destructor
   ~ChartStudy() {
      // Clean up resources and remove study if needed
      Remove();
   }
   
   // Get the indicator instance
   bool IsPineIndicator() const {
      return m_isPineIndicator;
   }
   
   // Get pine indicator
   PineIndicator* GetPineIndicator() {
      return m_pineIndicator;
   }
   
   // Get built-in indicator
   BuiltInIndicator* GetBuiltInIndicator() {
      return m_builtInIndicator;
   }
   
   // Set new indicator
   void SetIndicator(PineIndicator *pineIndicator, BuiltInIndicator *builtInIndicator = NULL) {
      if(pineIndicator == NULL && builtInIndicator == NULL) {
         FireErrorCallbacks("Indicator argument must be an instance of PineIndicator or BuiltInIndicator");
         return;
      }
      
      m_pineIndicator = pineIndicator;
      m_builtInIndicator = builtInIndicator;
      m_isPineIndicator = (pineIndicator != NULL);
      
      // In a real implementation, this would send a message to modify the study
      bool isPine;
      string inputsJson = GetInputs(pineIndicator, builtInIndicator, isPine);
      
      // Send message to modify study through the chart session
      if(m_chartSession != NULL) {
         // Create JSON message for modify_study command
         CJAVal params;
         params.Add(0, "chartSession.GetSessionID()");
         params.Add(1, m_studyId);
         params.Add(2, "st1");
         params.Add(3, inputsJson);
         
         // Send message through WebSocket (implementation dependent)
         // chartSession.Send("modify_study", params);
      }
   }
   
   // Get study ID
   string GetStudyId() const {
      return m_studyId;
   }
   
   // Get periods
   ChartPeriod* GetPeriods(int &size) {
      size = ArraySize(m_periods);
      return m_periods;
   }
   
   // Get graphic data
   GraphicData* GetGraphic() {
      return &m_graphic;
   }
   
   // Get strategy report
   StrategyReport* GetStrategyReport() {
      return &m_strategyReport;
   }
   
   // Register callback for study completion
   void OnReady(StudyCompletedCallback callback) {
      int size = ArraySize(m_onCompletedCallbacks);
      ArrayResize(m_onCompletedCallbacks, size + 1);
      m_onCompletedCallbacks[size] = callback;
   }
   
   // Register callback for updates
   void OnUpdate(UpdateCallback callback) {
      int size = ArraySize(m_onUpdateCallbacks);
      ArrayResize(m_onUpdateCallbacks, size + 1);
      m_onUpdateCallbacks[size] = callback;
   }
   
   // Register callback for errors
   void OnError(ErrorCallback callback) {
      int size = ArraySize(m_onErrorCallbacks);
      ArrayResize(m_onErrorCallbacks, size + 1);
      m_onErrorCallbacks[size] = callback;
   }
   
   // Register callback for events
   void OnEvent(EventCallback callback) {
      int size = ArraySize(m_onEventCallbacks);
      ArrayResize(m_onEventCallbacks, size + 1);
      m_onEventCallbacks[size] = callback;
   }
   
   // Handle incoming packet data
   void HandlePacket(CJAVal &packet) {
      string packetType = packet["type"].ToStr();
      
      if(packetType == "study_completed") {
         FireCompletedCallbacks();
         return;
      }
      
      if(packetType == "timescale_update" || packetType == "du") {
         string changes[];
         
         // Parse study data
         CJAVal data = packet["data"][1][m_studyId];
         
         // Process plot data
         if(!data["st"].IsNull() && !data["st"][0].IsNull()) {
            int stSize = data["st"].Size();
            for(int i = 0; i < stSize; i++) {
               CJAVal periodData = data["st"][i];
               CJAVal plotValues = periodData["v"];
               
               // Create a new period struct
               ChartPeriod period;
               
               // First value is always timestamp
               period.time = (datetime)plotValues[0].ToInt();
               
               // The rest are plot values
               int valueSize = plotValues.Size();
               ArrayResize(period.values, valueSize - 1);
               
               for(int j = 1; j < valueSize; j++) {
                  period.values[j - 1] = plotValues[j].ToDbl();
               }
               
               // Store period by timestamp
               int periodIdx = ArraySize(m_periods);
               ArrayResize(m_periods, periodIdx + 1);
               m_periods[periodIdx] = period;
            }
            
            // Sort periods by timestamp
            SortPeriods();
            
            // Mark that plots have changed
            ArrayResize(changes, ArraySize(changes) + 1);
            changes[ArraySize(changes) - 1] = "plots";
         }
         
         // Process graphic data if present
         if(!data["ns"].IsNull() && !data["ns"]["d"].IsNull()) {
            string graphicDataStr = data["ns"]["d"].ToStr();
            
            // Parse graphic commands JSON
            CJAVal graphicData;
            if(graphicData.Deserialize(graphicDataStr)) {
               // Process erase commands
               if(!graphicData["graphicsCmds"].IsNull() && !graphicData["graphicsCmds"]["erase"].IsNull()) {
                  CJAVal eraseCommands = graphicData["graphicsCmds"]["erase"];
                  int eraseSize = eraseCommands.Size();
                  
                  for(int i = 0; i < eraseSize; i++) {
                     CJAVal instruction = eraseCommands[i];
                     string action = instruction["action"].ToStr();
                     
                     if(action == "all") {
                        // Clear all graphics or specific type
                        if(instruction["type"].IsNull()) {
                           // Clear all graphic types
                           ZeroMemory(m_graphic);
                        } else {
                           // Clear specific graphic type
                           string type = instruction["type"].ToStr();
                           if(type == "line") {
                              ArrayFree(m_graphic.lines);
                           } else if(type == "horizontalLine") {
                              ArrayFree(m_graphic.horizontalLines);
                           } else if(type == "verticalLine") {
                              ArrayFree(m_graphic.verticalLines);
                           } else if(type == "text") {
                              ArrayFree(m_graphic.texts);
                           } else if(type == "box") {
                              ArrayFree(m_graphic.boxes);
                           } else if(type == "triangle") {
                              ArrayFree(m_graphic.triangles);
                           } else if(type == "polygone") {
                              ArrayFree(m_graphic.polygons);
                           } else if(type == "label") {
                              ArrayFree(m_graphic.labels);
                           } else if(type == "table") {
                              ArrayFree(m_graphic.tables);
                           }
                        }
                     } else if(action == "one") {
                        // Delete specific graphic item
                        string type = instruction["type"].ToStr();
                        int id = instruction["id"].ToInt();
                        
                        // Remove specific item by ID
                        if(type == "line") {
                           RemoveGraphicItemById(m_graphic.lines, id);
                        } else if(type == "horizontalLine") {
                           RemoveGraphicItemById(m_graphic.horizontalLines, id);
                        } else if(type == "verticalLine") {
                           RemoveGraphicItemById(m_graphic.verticalLines, id);
                        } else if(type == "text") {
                           RemoveGraphicItemById(m_graphic.texts, id);
                        } else if(type == "box") {
                           RemoveGraphicItemById(m_graphic.boxes, id);
                        } else if(type == "triangle") {
                           RemoveGraphicItemById(m_graphic.triangles, id);
                        } else if(type == "polygone") {
                           RemoveGraphicItemById(m_graphic.polygons, id);
                        } else if(type == "label") {
                           RemoveGraphicItemById(m_graphic.labels, id);
                        } else if(type == "table") {
                           RemoveGraphicItemById(m_graphic.tables, id);
                        }
                     }
                  }
               }
               
               // Process create commands
               if(!graphicData["graphicsCmds"].IsNull() && !graphicData["graphicsCmds"]["create"].IsNull()) {
                  CJAVal createCommands = graphicData["graphicsCmds"]["create"];
                  int createSize = createCommands.Size();
                  
                  for(int i = 0; i < createSize; i++) {
                     CJAVal instruction = createCommands[i];
                     string type = instruction["type"].ToStr();
                     
                     // Handle different graphic element types
                     if(type == "line") {
                        // Create a line
                        GraphicLine line;
                        line.id = instruction["id"].ToInt();
                        line.x1 = instruction["x1"].ToDbl();
                        line.y1 = instruction["y1"].ToDbl();
                        line.x2 = instruction["x2"].ToDbl();
                        line.y2 = instruction["y2"].ToDbl();
                        line.color = StringToColor(instruction["color"].ToStr());
                        line.linewidth = instruction["linewidth"].ToInt();
                        line.linestyle = ParseLineStyle(instruction["linestyle"].ToStr());
                        line.text = instruction["text"].ToStr();
                        line.extendLeft = instruction["extendLeft"].ToBool();
                        line.extendRight = instruction["extendRight"].ToBool();
                        
                        // Add to graphic lines array
                        int size = ArraySize(m_graphic.lines);
                        ArrayResize(m_graphic.lines, size + 1);
                        m_graphic.lines[size] = line;
                     }
                     else if(type == "horizontalLine") {
                        // Create horizontal line
                        GraphicHLine hline;
                        hline.id = instruction["id"].ToInt();
                        hline.y = instruction["y"].ToDbl();
                        hline.color = StringToColor(instruction["color"].ToStr());
                        hline.linewidth = instruction["linewidth"].ToInt();
                        hline.linestyle = ParseLineStyle(instruction["linestyle"].ToStr());
                        hline.text = instruction["text"].ToStr();
                        
                        // Add to horizontal lines array
                        int size = ArraySize(m_graphic.horizontalLines);
                        ArrayResize(m_graphic.horizontalLines, size + 1);
                        m_graphic.horizontalLines[size] = hline;
                     }
                     else if(type == "verticalLine") {
                        // Create vertical line
                        GraphicVLine vline;
                        vline.id = instruction["id"].ToInt();
                        vline.x = instruction["x"].ToDbl();
                        vline.color = StringToColor(instruction["color"].ToStr());
                        vline.linewidth = instruction["linewidth"].ToInt();
                        vline.linestyle = ParseLineStyle(instruction["linestyle"].ToStr());
                        vline.text = instruction["text"].ToStr();
                        
                        // Add to vertical lines array
                        int size = ArraySize(m_graphic.verticalLines);
                        ArrayResize(m_graphic.verticalLines, size + 1);
                        m_graphic.verticalLines[size] = vline;
                     }
                     else if(type == "text") {
                        // Create text
                        GraphicText text;
                        text.id = instruction["id"].ToInt();
                        text.x = instruction["x"].ToDbl();
                        text.y = instruction["y"].ToDbl();
                        text.text = instruction["text"].ToStr();
                        text.color = StringToColor(instruction["color"].ToStr());
                        text.fontsize = instruction["fontsize"].ToInt();
                        text.fontfamily = instruction["fontfamily"].ToStr();
                        
                        // Add to texts array
                        int size = ArraySize(m_graphic.texts);
                        ArrayResize(m_graphic.texts, size + 1);
                        m_graphic.texts[size] = text;
                     }
                     else if(type == "box" || type == "rectangle") {
                        // Create box/rectangle
                        GraphicBox box;
                        box.id = instruction["id"].ToInt();
                        box.x1 = instruction["x1"].ToDbl();
                        box.y1 = instruction["y1"].ToDbl();
                        box.x2 = instruction["x2"].ToDbl();
                        box.y2 = instruction["y2"].ToDbl();
                        box.color = StringToColor(instruction["color"].ToStr());
                        box.bgcolor = StringToColor(instruction["bgcolor"].ToStr());
                        box.linewidth = instruction["linewidth"].ToInt();
                        box.linestyle = ParseLineStyle(instruction["linestyle"].ToStr());
                        box.text = instruction["text"].ToStr();
                        
                        // Add to boxes array
                        int size = ArraySize(m_graphic.boxes);
                        ArrayResize(m_graphic.boxes, size + 1);
                        m_graphic.boxes[size] = box;
                     }
                     else if(type == "triangle") {
                        // Create triangle
                        GraphicTriangle triangle;
                        triangle.id = instruction["id"].ToInt();
                        triangle.x1 = instruction["x1"].ToDbl();
                        triangle.y1 = instruction["y1"].ToDbl();
                        triangle.x2 = instruction["x2"].ToDbl();
                        triangle.y2 = instruction["y2"].ToDbl();
                        triangle.x3 = instruction["x3"].ToDbl();
                        triangle.y3 = instruction["y3"].ToDbl();
                        triangle.color = StringToColor(instruction["color"].ToStr());
                        triangle.bgcolor = StringToColor(instruction["bgcolor"].ToStr());
                        triangle.linewidth = instruction["linewidth"].ToInt();
                        triangle.linestyle = ParseLineStyle(instruction["linestyle"].ToStr());
                        
                        // Add to triangles array
                        int size = ArraySize(m_graphic.triangles);
                        ArrayResize(m_graphic.triangles, size + 1);
                        m_graphic.triangles[size] = triangle;
                     }
                     else if(type == "polygone" || type == "polygon") {
                        // Create polygon
                        GraphicPolygon polygon;
                        polygon.id = instruction["id"].ToInt();
                        polygon.color = StringToColor(instruction["color"].ToStr());
                        polygon.bgcolor = StringToColor(instruction["bgcolor"].ToStr());
                        polygon.linewidth = instruction["linewidth"].ToInt();
                        polygon.linestyle = ParseLineStyle(instruction["linestyle"].ToStr());
                        
                        // Parse points
                        CJAVal points = instruction["points"];
                        int pointsCount = points.Size();
                        ArrayResize(polygon.points, pointsCount);
                        
                        for(int j = 0; j < pointsCount; j++) {
                           GraphicPoint point;
                           point.x = points[j]["x"].ToDbl();
                           point.y = points[j]["y"].ToDbl();
                           polygon.points[j] = point;
                        }
                        
                        // Add to polygons array
                        int size = ArraySize(m_graphic.polygons);
                        ArrayResize(m_graphic.polygons, size + 1);
                        m_graphic.polygons[size] = polygon;
                     }
                     else if(type == "label") {
                        // Create label
                        GraphicLabel label;
                        label.id = instruction["id"].ToInt();
                        label.x = instruction["x"].ToDbl();
                        label.y = instruction["y"].ToDbl();
                        label.text = instruction["text"].ToStr();
                        label.color = StringToColor(instruction["color"].ToStr());
                        label.fontsize = instruction["fontsize"].ToInt();
                        label.fontfamily = instruction["fontfamily"].ToStr();
                        label.bgcolor = StringToColor(instruction["bgcolor"].ToStr());
                        
                        // Add to labels array
                        int size = ArraySize(m_graphic.labels);
                        ArrayResize(m_graphic.labels, size + 1);
                        m_graphic.labels[size] = label;
                     }
                     else if(type == "table") {
                        // Create table
                        GraphicTable table;
                        table.id = instruction["id"].ToInt();
                        table.x = instruction["x"].ToDbl();
                        table.y = instruction["y"].ToDbl();
                        
                        // Parse cells
                        CJAVal cells = instruction["cells"];
                        int rowCount = cells.Size();
                        ArrayResize(table.cells, rowCount);
                        
                        for(int r = 0; r < rowCount; r++) {
                           CJAVal row = cells[r];
                           int colCount = row.Size();
                           ArrayResize(table.cells[r], colCount);
                           
                           for(int c = 0; c < colCount; c++) {
                              CJAVal cell = row[c];
                              table.cells[r][c].text = cell["text"].ToStr();
                              table.cells[r][c].color = StringToColor(cell["color"].ToStr());
                              table.cells[r][c].bgcolor = StringToColor(cell["bgcolor"].ToStr());
                           }
                        }
                        
                        // Add to tables array
                        int size = ArraySize(m_graphic.tables);
                        ArrayResize(m_graphic.tables, size + 1);
                        m_graphic.tables[size] = table;
                     }
                  }
               }
               
               // Parse strategy report data if present
               if(!graphicData["dataCompressed"].IsNull() || 
                  (!graphicData["data"].IsNull() && !graphicData["data"]["report"].IsNull())) {
                  
                  CJAVal reportData;
                  
                  // Handle compressed data if present
                  if(!graphicData["dataCompressed"].IsNull()) {
                     string compressedData = graphicData["dataCompressed"].ToStr();
                     string decompressedData = DecompressBase64Data(compressedData);
                     
                     if(!reportData.Deserialize(decompressedData)) {
                        FireErrorCallbacks("Failed to parse compressed report data");
                        return;
                     }
                  } 
                  else if(!graphicData["data"].IsNull() && !graphicData["data"]["report"].IsNull()) {
                     reportData = graphicData["data"]["report"];
                  }
                  
                  // Parse report data
                  if(!reportData.IsNull()) {
                     // Parse currency
                     if(!reportData["currency"].IsNull()) {
                        m_strategyReport.currency = reportData["currency"].ToStr();
                     }
                     
                     // Parse settings
                     if(!reportData["settings"].IsNull()) {
                        CJAVal settings = reportData["settings"];
                        
                        // Parse date range
                        if(!settings["dateRange"].IsNull()) {
                           CJAVal dateRange = settings["dateRange"];
                           
                           if(!dateRange["backtest"].IsNull()) {
                              m_strategyReport.settings.dateRange.backtest.from = (datetime)dateRange["backtest"]["from"].ToInt();
                              m_strategyReport.settings.dateRange.backtest.to = (datetime)dateRange["backtest"]["to"].ToInt();
                           }
                           
                           if(!dateRange["trade"].IsNull()) {
                              m_strategyReport.settings.dateRange.trade.from = (datetime)dateRange["trade"]["from"].ToInt();
                              m_strategyReport.settings.dateRange.trade.to = (datetime)dateRange["trade"]["to"].ToInt();
                           }
                        }
                     }
                     
                     // Parse performance data
                     if(!reportData["performance"].IsNull()) {
                        CJAVal perf = reportData["performance"];
                        
                        // Parse all performance metrics
                        ParsePerformanceSection(perf["all"], m_strategyReport.performance.all);
                        ParsePerformanceSection(perf["long"], m_strategyReport.performance.long);
                        ParsePerformanceSection(perf["short"], m_strategyReport.performance.short);
                        
                        // Parse other performance metrics
                        m_strategyReport.performance.buyHoldReturn = perf["buyHoldReturn"].ToDbl();
                        m_strategyReport.performance.buyHoldReturnPercent = perf["buyHoldReturnPercent"].ToDbl();
                        m_strategyReport.performance.maxDrawDown = perf["maxDrawDown"].ToDbl();
                        m_strategyReport.performance.maxDrawDownPercent = perf["maxDrawDownPercent"].ToDbl();
                        m_strategyReport.performance.openPL = perf["openPL"].ToDbl();
                        m_strategyReport.performance.openPLPercent = perf["openPLPercent"].ToDbl();
                        m_strategyReport.performance.sharpeRatio = perf["sharpeRatio"].ToDbl();
                        m_strategyReport.performance.sortinoRatio = perf["sortinoRatio"].ToDbl();
                     }
                     
                     // Parse trades data
                     if(!reportData["trades"].IsNull()) {
                        ParseTrades(reportData["trades"], m_strategyReport.trades);
                     }
                     
                     // Parse history chart data
                     if(!reportData["history"].IsNull()) {
                        CJAVal history = reportData["history"];
                        
                        // Parse buy & hold
                        if(!history["buyHold"].IsNull()) {
                           CJAVal buyHold = history["buyHold"];
                           int size = buyHold.Size();
                           ArrayResize(m_strategyReport.history.buyHold, size);
                           
                           for(int i = 0; i < size; i++) {
                              m_strategyReport.history.buyHold[i] = buyHold[i].ToDbl();
                           }
                        }
                        
                        // Parse buy & hold percent
                        if(!history["buyHoldPercent"].IsNull()) {
                           CJAVal buyHoldPercent = history["buyHoldPercent"];
                           int size = buyHoldPercent.Size();
                           ArrayResize(m_strategyReport.history.buyHoldPercent, size);
                           
                           for(int i = 0; i < size; i++) {
                              m_strategyReport.history.buyHoldPercent[i] = buyHoldPercent[i].ToDbl();
                           }
                        }
                        
                        // Parse drawdown
                        if(!history["drawDown"].IsNull()) {
                           CJAVal drawDown = history["drawDown"];
                           int size = drawDown.Size();
                           ArrayResize(m_strategyReport.history.drawDown, size);
                           
                           for(int i = 0; i < size; i++) {
                              m_strategyReport.history.drawDown[i] = drawDown[i].ToDbl();
                           }
                        }
                        
                        // Parse drawdown percent
                        if(!history["drawDownPercent"].IsNull()) {
                           CJAVal drawDownPercent = history["drawDownPercent"];
                           int size = drawDownPercent.Size();
                           ArrayResize(m_strategyReport.history.drawDownPercent, size);
                           
                           for(int i = 0; i < size; i++) {
                              m_strategyReport.history.drawDownPercent[i] = drawDownPercent[i].ToDbl();
                           }
                        }
                        
                        // Parse equity
                        if(!history["equity"].IsNull()) {
                           CJAVal equity = history["equity"];
                           int size = equity.Size();
                           ArrayResize(m_strategyReport.history.equity, size);
                           
                           for(int i = 0; i < size; i++) {
                              m_strategyReport.history.equity[i] = equity[i].ToDbl();
                           }
                        }
                        
                        // Parse equity percent
                        if(!history["equityPercent"].IsNull()) {
                           CJAVal equityPercent = history["equityPercent"];
                           int size = equityPercent.Size();
                           ArrayResize(m_strategyReport.history.equityPercent, size);
                           
                           for(int i = 0; i < size; i++) {
                              m_strategyReport.history.equityPercent[i] = equityPercent[i].ToDbl();
                           }
                        }
                     }
                  }
                  
                  // Mark report components as changed
                  string reportComponents[] = {"report.currency", "report.settings", 
                                             "report.perf", "report.trades", "report.history"};
                  
                  for(int i = 0; i < ArraySize(reportComponents); i++) {
                     ArrayResize(changes, ArraySize(changes) + 1);
                     changes[ArraySize(changes) - 1] = reportComponents[i];
                  }
               }
               
               // Mark that graphic has changed
               ArrayResize(changes, ArraySize(changes) + 1);
               changes[ArraySize(changes) - 1] = "graphic";
            }
         }
         
         // Process indexes if present
         if(!data["ns"].IsNull() && !data["ns"]["indexes"].IsNull()) {
            // Update indexes - implementation would depend on how indexes are stored
         }
         
         // Fire update callbacks
         if(ArraySize(changes) > 0) {
            FireUpdateCallbacks(changes);
         }
         
         return;
      }
      
      if(packetType == "study_error") {
         string errorMsg = packet["data"][3].ToStr() + ": " + packet["data"][4].ToStr();
         FireErrorCallbacks(errorMsg);
      }
   }
   
   // Remove study
   void Remove() {
      // In actual implementation, this would send a message to remove the study
      // chartSession.send("remove_study", [sessionID, studyID]);
   }
};