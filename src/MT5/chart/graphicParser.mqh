//+------------------------------------------------------------------+
//| TradingView Graphic Parser for MQL5                              |
//+------------------------------------------------------------------+

// Extension type enums
enum ENUM_EXTEND_VALUE {
   EXTEND_RIGHT,  // r
   EXTEND_LEFT,   // l
   EXTEND_BOTH,   // b
   EXTEND_NONE    // n
};

// Y Location enums
enum ENUM_YLOC_VALUE {
   YLOC_PRICE,    // pr
   YLOC_ABOVEBAR, // ab
   YLOC_BELOWBAR  // bl
};

// Label style enums
enum ENUM_LABEL_STYLE_VALUE {
   LABELSTYLE_NONE,            // n
   LABELSTYLE_XCROSS,          // xcr
   LABELSTYLE_CROSS,           // cr
   LABELSTYLE_TRIANGLEUP,      // tup
   LABELSTYLE_TRIANGLEDOWN,    // tdn
   LABELSTYLE_FLAG,            // flg
   LABELSTYLE_CIRCLE,          // cir
   LABELSTYLE_ARROWUP,         // aup
   LABELSTYLE_ARROWDOWN,       // adn
   LABELSTYLE_LABEL_UP,        // lup
   LABELSTYLE_LABEL_DOWN,      // ldn
   LABELSTYLE_LABEL_LEFT,      // llf
   LABELSTYLE_LABEL_RIGHT,     // lrg
   LABELSTYLE_LABEL_LOWER_LEFT,// llwlf
   LABELSTYLE_LABEL_LOWER_RIGHT,// llwrg
   LABELSTYLE_LABEL_UPPER_LEFT,// luplf
   LABELSTYLE_LABEL_UPPER_RIGHT,// luprg
   LABELSTYLE_LABEL_CENTER,    // lcn
   LABELSTYLE_SQUARE,          // sq
   LABELSTYLE_DIAMOND          // dia
};

// Line style enums
enum ENUM_LINE_STYLE_VALUE {
   LINESTYLE_SOLID,      // sol
   LINESTYLE_DOTTED,     // dot
   LINESTYLE_DASHED,     // dsh
   LINESTYLE_ARROW_LEFT, // al
   LINESTYLE_ARROW_RIGHT,// ar
   LINESTYLE_ARROW_BOTH  // ab
};

// Box style enums
enum ENUM_BOX_STYLE_VALUE {
   BOXSTYLE_SOLID,       // sol
   BOXSTYLE_DOTTED,      // dot
   BOXSTYLE_DASHED       // dsh
};

// Size values
enum ENUM_SIZE_VALUE {
   SIZE_AUTO,
   SIZE_HUGE,
   SIZE_LARGE,
   SIZE_NORMAL,
   SIZE_SMALL,
   SIZE_TINY
};

// Vertical alignment
enum ENUM_VALIGN_VALUE {
   VALIGN_TOP,
   VALIGN_CENTER,
   VALIGN_BOTTOM
};

// Horizontal alignment
enum ENUM_HALIGN_VALUE {
   HALIGN_LEFT,
   HALIGN_CENTER,
   HALIGN_RIGHT
};

// Text wrap
enum ENUM_TEXT_WRAP_VALUE {
   TEXTWRAP_NONE,
   TEXTWRAP_AUTO
};

// Table position
enum ENUM_TABLE_POSITION_VALUE {
   TABLEPOS_TOP_LEFT,
   TABLEPOS_TOP_CENTER,
   TABLEPOS_TOP_RIGHT,
   TABLEPOS_MIDDLE_LEFT,
   TABLEPOS_MIDDLE_CENTER,
   TABLEPOS_MIDDLE_RIGHT,
   TABLEPOS_BOTTOM_LEFT,
   TABLEPOS_BOTTOM_CENTER,
   TABLEPOS_BOTTOM_RIGHT
};

// Struct definitions
struct GraphicLabel {
   int               id;           // Drawing ID
   int               x;            // Label x position
   double            y;            // Label y position
   ENUM_YLOC_VALUE   yLoc;         // yLoc mode
   string            text;         // Label text
   ENUM_LABEL_STYLE_VALUE style;   // Label style
   int               color;        // Color
   int               textColor;    // Text color
   ENUM_SIZE_VALUE   size;         // Label size
   ENUM_HALIGN_VALUE textAlign;    // Text horizontal align
   string            toolTip;      // Tooltip text
};

struct GraphicLine {
   int                  id;        // Drawing ID
   int                  x1;        // First x position
   double               y1;        // First y position
   int                  x2;        // Second x position
   double               y2;        // Second y position
   ENUM_EXTEND_VALUE    extend;    // Horizontal extend
   ENUM_LINE_STYLE_VALUE style;    // Line style
   int                  color;     // Line color
   int                  width;     // Line width
};

struct GraphicBox {
   int                  id;        // Drawing ID
   int                  x1;        // First x position
   double               y1;        // First y position
   int                  x2;        // Second x position
   double               y2;        // Second y position
   int                  color;     // Box color
   int                  bgColor;   // Background color
   ENUM_EXTEND_VALUE    extend;    // Horizontal extend
   ENUM_BOX_STYLE_VALUE style;     // Box style
   int                  width;     // Box width
   string               text;      // Text
   ENUM_SIZE_VALUE      textSize;  // Text size
   int                  textColor; // Text color
   ENUM_VALIGN_VALUE    textVAlign;// Text vertical align
   ENUM_HALIGN_VALUE    textHAlign;// Text horizontal align
   ENUM_TEXT_WRAP_VALUE textWrap;  // Text wrap
};

struct TableCell {
   int               id;           // Drawing ID
   string            text;         // Cell text
   int               width;        // Cell width
   int               height;       // Cell height
   int               textColor;    // Text color
   ENUM_HALIGN_VALUE textHAlign;   // Text horizontal align
   ENUM_VALIGN_VALUE textVAlign;   // Text Vertical align
   ENUM_SIZE_VALUE   textSize;     // Text size
   int               bgColor;      // Background color
};

struct GraphicTable {
   int                     id;        // Drawing ID
   ENUM_TABLE_POSITION_VALUE position;// Table position
   int                     rows;      // Number of rows
   int                     columns;   // Number of columns
   int                     bgColor;   // Background color
   int                     frameColor;// Frame color
   int                     frameWidth;// Frame width
   int                     borderColor;// Border color
   int                     borderWidth;// Border width
   TableCell               cells[];   // Table cells array
};

struct GraphicHorizline {
   int               id;            // Drawing ID
   double            level;         // Y position of the line
   int               startIndex;    // Start index of the line
   int               endIndex;      // End index of the line
   bool              extendRight;   // Is the line extended to the right
   bool              extendLeft;    // Is the line extended to the left
};

struct GraphicPoint {
   int               index;         // X position of the point
   double            level;         // Y position of the point
};

struct GraphicPolygon {
   int               id;            // Drawing ID
   GraphicPoint      points[];      // List of polygon points
};

struct GraphicHorizHist {
   int               id;            // Drawing ID
   double            priceLow;      // Low Y position
   double            priceHigh;     // High Y position
   int               firstBarTime;  // First X position
   int               lastBarTime;   // Last X position
   double            rate[];        // List of values
};

// Main GraphicData structure
struct GraphicData {
   GraphicLabel      labels[];
   GraphicLine       lines[];
   GraphicBox        boxes[];
   GraphicTable      tables[];
   GraphicPolygon    polygons[];
   GraphicHorizHist  horizHists[];
   GraphicHorizline  horizLines[];
};

//+------------------------------------------------------------------+
//| GraphicParser class                                              |
//+------------------------------------------------------------------+
class GraphicParser {
private:
   // Translation helper methods
   static ENUM_EXTEND_VALUE TranslateExtend(string value) {
      if(value == "r") return EXTEND_RIGHT;
      if(value == "l") return EXTEND_LEFT;
      if(value == "b") return EXTEND_BOTH;
      return EXTEND_NONE;
   }
   
   static ENUM_YLOC_VALUE TranslateYLoc(string value) {
      if(value == "pr") return YLOC_PRICE;
      if(value == "ab") return YLOC_ABOVEBAR;
      if(value == "bl") return YLOC_BELOWBAR;
      return YLOC_PRICE;
   }
   
   static ENUM_LABEL_STYLE_VALUE TranslateLabelStyle(string value) {
      if(value == "xcr") return LABELSTYLE_XCROSS;
      if(value == "cr") return LABELSTYLE_CROSS;
      if(value == "tup") return LABELSTYLE_TRIANGLEUP;
      if(value == "tdn") return LABELSTYLE_TRIANGLEDOWN;
      if(value == "flg") return LABELSTYLE_FLAG;
      if(value == "cir") return LABELSTYLE_CIRCLE;
      if(value == "aup") return LABELSTYLE_ARROWUP;
      if(value == "adn") return LABELSTYLE_ARROWDOWN;
      if(value == "lup") return LABELSTYLE_LABEL_UP;
      if(value == "ldn") return LABELSTYLE_LABEL_DOWN;
      if(value == "llf") return LABELSTYLE_LABEL_LEFT;
      if(value == "lrg") return LABELSTYLE_LABEL_RIGHT;
      if(value == "llwlf") return LABELSTYLE_LABEL_LOWER_LEFT;
      if(value == "llwrg") return LABELSTYLE_LABEL_LOWER_RIGHT;
      if(value == "luplf") return LABELSTYLE_LABEL_UPPER_LEFT;
      if(value == "luprg") return LABELSTYLE_LABEL_UPPER_RIGHT;
      if(value == "lcn") return LABELSTYLE_LABEL_CENTER;
      if(value == "sq") return LABELSTYLE_SQUARE;
      if(value == "dia") return LABELSTYLE_DIAMOND;
      return LABELSTYLE_NONE;
   }
   
   static ENUM_LINE_STYLE_VALUE TranslateLineStyle(string value) {
      if(value == "sol") return LINESTYLE_SOLID;
      if(value == "dot") return LINESTYLE_DOTTED;
      if(value == "dsh") return LINESTYLE_DASHED;
      if(value == "al") return LINESTYLE_ARROW_LEFT;
      if(value == "ar") return LINESTYLE_ARROW_RIGHT;
      if(value == "ab") return LINESTYLE_ARROW_BOTH;
      return LINESTYLE_SOLID;
   }
   
   static ENUM_BOX_STYLE_VALUE TranslateBoxStyle(string value) {
      if(value == "sol") return BOXSTYLE_SOLID;
      if(value == "dot") return BOXSTYLE_DOTTED;
      if(value == "dsh") return BOXSTYLE_DASHED;
      return BOXSTYLE_SOLID;
   }

public:
   // Main parsing function that would be implemented to parse JSON data from TradingView
   static bool ParseGraphicData(string jsonData, int &indexes[], GraphicData &result);
};

//+------------------------------------------------------------------+
//| Parse graphic data from JSON                                      |
//+------------------------------------------------------------------+
bool GraphicParser::ParseGraphicData(string jsonData, int &indexes[], GraphicData &result) {
   // Parse the JSON string
   JSONValue json;
   if(!json.FromString(jsonData))
      return false;
   
   // Parse labels
   JSONValue dwglabels = json["dwglabels"];
   if(CheckPointer(dwglabels) != POINTER_INVALID && dwglabels.IsObject()) {
      // Get all keys and iterate through them
      string keys[];
      dwglabels.GetKeys(keys);
      int labelsCount = ArraySize(keys);
      
      ArrayResize(result.labels, labelsCount);
      
      for(int i = 0; i < labelsCount; i++) {
         JSONValue label = dwglabels[keys[i]];
         
         result.labels[i].id = (int)label["id"].ToInt();
         result.labels[i].x = indexes[(int)label["x"].ToInt()];
         result.labels[i].y = label["y"].ToDouble();
         result.labels[i].yLoc = TranslateYLoc(label["yl"].ToString());
         result.labels[i].text = label["t"].ToString();
         result.labels[i].style = TranslateLabelStyle(label["st"].ToString());
         result.labels[i].color = (int)label["ci"].ToInt();
         result.labels[i].textColor = (int)label["tci"].ToInt();
         
         // Map size values: auto, huge, large, normal, small, tiny
         string sizeStr = label["sz"].ToString();
         if(sizeStr == "auto") result.labels[i].size = SIZE_AUTO;
         else if(sizeStr == "huge") result.labels[i].size = SIZE_HUGE;
         else if(sizeStr == "large") result.labels[i].size = SIZE_LARGE;
         else if(sizeStr == "normal") result.labels[i].size = SIZE_NORMAL;
         else if(sizeStr == "small") result.labels[i].size = SIZE_SMALL;
         else if(sizeStr == "tiny") result.labels[i].size = SIZE_TINY;
         
         // Map text alignment values
         string alignStr = label["ta"].ToString();
         if(alignStr == "left") result.labels[i].textAlign = HALIGN_LEFT;
         else if(alignStr == "center") result.labels[i].textAlign = HALIGN_CENTER;
         else if(alignStr == "right") result.labels[i].textAlign = HALIGN_RIGHT;
         
         result.labels[i].toolTip = label["tt"].ToString();
      }
   }
   
   // Parse lines
   JSONValue dwglines = json["dwglines"];
   if(CheckPointer(dwglines) != POINTER_INVALID && dwglines.IsObject()) {
      string keys[];
      dwglines.GetKeys(keys);
      int linesCount = ArraySize(keys);
      
      ArrayResize(result.lines, linesCount);
      
      for(int i = 0; i < linesCount; i++) {
         JSONValue line = dwglines[keys[i]];
         
         result.lines[i].id = (int)line["id"].ToInt();
         result.lines[i].x1 = indexes[(int)line["x1"].ToInt()];
         result.lines[i].y1 = line["y1"].ToDouble();
         result.lines[i].x2 = indexes[(int)line["x2"].ToInt()];
         result.lines[i].y2 = line["y2"].ToDouble();
         result.lines[i].extend = TranslateExtend(line["ex"].ToString());
         result.lines[i].style = TranslateLineStyle(line["st"].ToString());
         result.lines[i].color = (int)line["ci"].ToInt();
         result.lines[i].width = (int)line["w"].ToInt();
      }
   }
   
   // Parse boxes
   JSONValue dwgboxes = json["dwgboxes"];
   if(CheckPointer(dwgboxes) != POINTER_INVALID && dwgboxes.IsObject()) {
      string keys[];
      dwgboxes.GetKeys(keys);
      int boxesCount = ArraySize(keys);
      
      ArrayResize(result.boxes, boxesCount);
      
      for(int i = 0; i < boxesCount; i++) {
         JSONValue box = dwgboxes[keys[i]];
         
         result.boxes[i].id = (int)box["id"].ToInt();
         result.boxes[i].x1 = indexes[(int)box["x1"].ToInt()];
         result.boxes[i].y1 = box["y1"].ToDouble();
         result.boxes[i].x2 = indexes[(int)box["x2"].ToInt()];
         result.boxes[i].y2 = box["y2"].ToDouble();
         result.boxes[i].color = (int)box["c"].ToInt();
         result.boxes[i].bgColor = (int)box["bc"].ToInt();
         result.boxes[i].extend = TranslateExtend(box["ex"].ToString());
         result.boxes[i].style = TranslateBoxStyle(box["st"].ToString());
         result.boxes[i].width = (int)box["w"].ToInt();
         result.boxes[i].text = box["t"].ToString();
         
         // Map size values
         string sizeStr = box["ts"].ToString();
         if(sizeStr == "auto") result.boxes[i].textSize = SIZE_AUTO;
         else if(sizeStr == "huge") result.boxes[i].textSize = SIZE_HUGE;
         else if(sizeStr == "large") result.boxes[i].textSize = SIZE_LARGE;
         else if(sizeStr == "normal") result.boxes[i].textSize = SIZE_NORMAL;
         else if(sizeStr == "small") result.boxes[i].textSize = SIZE_SMALL;
         else if(sizeStr == "tiny") result.boxes[i].textSize = SIZE_TINY;
         
         result.boxes[i].textColor = (int)box["tc"].ToInt();
         
         // Map vertical align values
         string vAlignStr = box["tva"].ToString();
         if(vAlignStr == "top") result.boxes[i].textVAlign = VALIGN_TOP;
         else if(vAlignStr == "center") result.boxes[i].textVAlign = VALIGN_CENTER;
         else if(vAlignStr == "bottom") result.boxes[i].textVAlign = VALIGN_BOTTOM;
         
         // Map horizontal align values
         string hAlignStr = box["tha"].ToString();
         if(hAlignStr == "left") result.boxes[i].textHAlign = HALIGN_LEFT;
         else if(hAlignStr == "center") result.boxes[i].textHAlign = HALIGN_CENTER;
         else if(hAlignStr == "right") result.boxes[i].textHAlign = HALIGN_RIGHT;
         
         // Map text wrap values
         string wrapStr = box["tw"].ToString();
         if(wrapStr == "none") result.boxes[i].textWrap = TEXTWRAP_NONE;
         else if(wrapStr == "auto") result.boxes[i].textWrap = TEXTWRAP_AUTO;
      }
   }
   
   // Parse tables and table cells
   JSONValue dwgtables = json["dwgtables"];
   if(CheckPointer(dwgtables) != POINTER_INVALID && dwgtables.IsObject()) {
      string keys[];
      dwgtables.GetKeys(keys);
      int tablesCount = ArraySize(keys);
      
      ArrayResize(result.tables, tablesCount);
      
      for(int i = 0; i < tablesCount; i++) {
         JSONValue table = dwgtables[keys[i]];
         
         result.tables[i].id = (int)table["id"].ToInt();
         
         // Map table position values
         string posStr = table["pos"].ToString();
         if(posStr == "top_left") result.tables[i].position = TABLEPOS_TOP_LEFT;
         else if(posStr == "top_center") result.tables[i].position = TABLEPOS_TOP_CENTER;
         else if(posStr == "top_right") result.tables[i].position = TABLEPOS_TOP_RIGHT;
         else if(posStr == "middle_left") result.tables[i].position = TABLEPOS_MIDDLE_LEFT;
         else if(posStr == "middle_center") result.tables[i].position = TABLEPOS_MIDDLE_CENTER;
         else if(posStr == "middle_right") result.tables[i].position = TABLEPOS_MIDDLE_RIGHT;
         else if(posStr == "bottom_left") result.tables[i].position = TABLEPOS_BOTTOM_LEFT;
         else if(posStr == "bottom_center") result.tables[i].position = TABLEPOS_BOTTOM_CENTER;
         else if(posStr == "bottom_right") result.tables[i].position = TABLEPOS_BOTTOM_RIGHT;
         
         result.tables[i].rows = (int)table["rows"].ToInt();
         result.tables[i].columns = (int)table["cols"].ToInt();
         result.tables[i].bgColor = (int)table["bgc"].ToInt();
         result.tables[i].frameColor = (int)table["frmc"].ToInt();
         result.tables[i].frameWidth = (int)table["frmw"].ToInt();
         result.tables[i].borderColor = (int)table["brdc"].ToInt();
         result.tables[i].borderWidth = (int)table["brdw"].ToInt();
      }
   }
   
   // Parse table cells and assign to tables
   JSONValue dwgtablecells = json["dwgtablecells"];
   if(CheckPointer(dwgtablecells) != POINTER_INVALID && dwgtablecells.IsObject()) {
      string keys[];
      dwgtablecells.GetKeys(keys);
      int cellsCount = ArraySize(keys);
      
      // First count cells for each table
      int tableCellsCount[];
      ArrayResize(tableCellsCount, ArraySize(result.tables));
      ArrayInitialize(tableCellsCount, 0);
      
      for(int i = 0; i < cellsCount; i++) {
         JSONValue cell = dwgtablecells[keys[i]];
         int tableId = (int)cell["tid"].ToInt();
         
         // Find table index for this cell
         for(int t = 0; t < ArraySize(result.tables); t++) {
            if(result.tables[t].id == tableId) {
               tableCellsCount[t]++;
               break;
            }
         }
      }
      
      // Resize cells arrays for each table
      for(int t = 0; t < ArraySize(result.tables); t++) {
         ArrayResize(result.tables[t].cells, tableCellsCount[t]);
         tableCellsCount[t] = 0;  // Reset counter for next loop
      }
      
      // Now fill cells for each table
      for(int i = 0; i < cellsCount; i++) {
         JSONValue cell = dwgtablecells[keys[i]];
         int tableId = (int)cell["tid"].ToInt();
         
         // Find table index for this cell
         for(int t = 0; t < ArraySize(result.tables); t++) {
            if(result.tables[t].id == tableId) {
               int cellIndex = tableCellsCount[t]++;
               
               TableCell &tableCell = result.tables[t].cells[cellIndex];
               tableCell.id = (int)cell["id"].ToInt();
               tableCell.text = cell["t"].ToString();
               tableCell.width = (int)cell["w"].ToInt();
               tableCell.height = (int)cell["h"].ToInt();
               tableCell.textColor = (int)cell["tc"].ToInt();
               
               // Map horizontal align
               string hAlignStr = cell["tha"].ToString();
               if(hAlignStr == "left") tableCell.textHAlign = HALIGN_LEFT;
               else if(hAlignStr == "center") tableCell.textHAlign = HALIGN_CENTER;
               else if(hAlignStr == "right") tableCell.textHAlign = HALIGN_RIGHT;
               
               // Map vertical align
               string vAlignStr = cell["tva"].ToString();
               if(vAlignStr == "top") tableCell.textVAlign = VALIGN_TOP;
               else if(vAlignStr == "center") tableCell.textVAlign = VALIGN_CENTER;
               else if(vAlignStr == "bottom") tableCell.textVAlign = VALIGN_BOTTOM;
               
               // Map text size
               string sizeStr = cell["ts"].ToString();
               if(sizeStr == "auto") tableCell.textSize = SIZE_AUTO;
               else if(sizeStr == "huge") tableCell.textSize = SIZE_HUGE;
               else if(sizeStr == "large") tableCell.textSize = SIZE_LARGE;
               else if(sizeStr == "normal") tableCell.textSize = SIZE_NORMAL;
               else if(sizeStr == "small") tableCell.textSize = SIZE_SMALL;
               else if(sizeStr == "tiny") tableCell.textSize = SIZE_TINY;
               
               tableCell.bgColor = (int)cell["bgc"].ToInt();
               break;
            }
         }
      }
   }
   
   // Parse horizontal lines
   JSONValue horizlines = json["horizlines"];
   if(CheckPointer(horizlines) != POINTER_INVALID && horizlines.IsObject()) {
      string keys[];
      horizlines.GetKeys(keys);
      int hlinesCount = ArraySize(keys);
      
      ArrayResize(result.horizLines, hlinesCount);
      
      for(int i = 0; i < hlinesCount; i++) {
         JSONValue hline = horizlines[keys[i]];
         
         result.horizLines[i].id = (int)hline["id"].ToInt();
         result.horizLines[i].level = hline["level"].ToDouble();
         result.horizLines[i].startIndex = indexes[(int)hline["startIndex"].ToInt()];
         result.horizLines[i].endIndex = indexes[(int)hline["endIndex"].ToInt()];
         result.horizLines[i].extendRight = hline["extendRight"].ToBool();
         result.horizLines[i].extendLeft = hline["extendLeft"].ToBool();
      }
   }
   
   // Parse polygons
   JSONValue polygons = json["polygons"];
   if(CheckPointer(polygons) != POINTER_INVALID && polygons.IsObject()) {
      string keys[];
      polygons.GetKeys(keys);
      int polygonsCount = ArraySize(keys);
      
      ArrayResize(result.polygons, polygonsCount);
      
      for(int i = 0; i < polygonsCount; i++) {
         JSONValue polygon = polygons[keys[i]];
         
         result.polygons[i].id = (int)polygon["id"].ToInt();
         
         // Parse points
         JSONValue points = polygon["points"];
         if(CheckPointer(points) != POINTER_INVALID && points.IsArray()) {
            int pointsCount = points.Size();
            ArrayResize(result.polygons[i].points, pointsCount);
            
            for(int p = 0; p < pointsCount; p++) {
               JSONValue point = points[p];
               
               result.polygons[i].points[p].index = indexes[(int)point["index"].ToInt()];
               result.polygons[i].points[p].level = point["level"].ToDouble();
            }
         }
      }
   }
   
   // Parse horizontal histograms
   JSONValue hhists = json["hhists"];
   if(CheckPointer(hhists) != POINTER_INVALID && hhists.IsObject()) {
      string keys[];
      hhists.GetKeys(keys);
      int hhistsCount = ArraySize(keys);
      
      ArrayResize(result.horizHists, hhistsCount);
      
      for(int i = 0; i < hhistsCount; i++) {
         JSONValue hhist = hhists[keys[i]];
         
         result.horizHists[i].id = (int)hhist["id"].ToInt();
         result.horizHists[i].priceLow = hhist["priceLow"].ToDouble();
         result.horizHists[i].priceHigh = hhist["priceHigh"].ToDouble();
         result.horizHists[i].firstBarTime = indexes[(int)hhist["firstBarTime"].ToInt()];
         result.horizHists[i].lastBarTime = indexes[(int)hhist["lastBarTime"].ToInt()];
         
         // Parse rate values
         JSONValue rate = hhist["rate"];
         if(CheckPointer(rate) != POINTER_INVALID && rate.IsArray()) {
            int rateCount = rate.Size();
            ArrayResize(result.horizHists[i].rate, rateCount);
            
            for(int r = 0; r < rateCount; r++) {
               result.horizHists[i].rate[r] = rate[r].ToDouble();
            }
         }
      }
   }
   
   return true;
}
