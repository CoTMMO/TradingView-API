//+------------------------------------------------------------------+
//| TradingView API Protocol functions for MQL5                       |
//+------------------------------------------------------------------+
#include "./include/JAson.mqh"

//+------------------------------------------------------------------+
//| Protocol helper class for websocket packet handling              |
//+------------------------------------------------------------------+
class Protocol {
private:
   static string      m_cleanerRgx;    // ~h~
   static string      m_splitterRgx;   // ~m~[0-9]{1,}~m~

public:
   // Parse websocket packet
   static bool        ParseWSPacket(string data, CJAVal &packets[]);
   
   // Format websocket packet
   static string      FormatWSPacket(CJAVal &packet);
   static string      FormatWSPacket(string text);
   
   // Parse compressed data
   static bool        ParseCompressed(string data, CJAVal &result);
   
   // Helper methods
   static string      CleanPacket(string data);
   static bool        SplitPackets(string data, string &parts[]);
   static bool        ParseJSON(string data, CJAVal &json);
};

//+------------------------------------------------------------------+
//| Parse websocket packet                                           |
//+------------------------------------------------------------------+
bool Protocol::ParseWSPacket(string data, CJAVal &packets[]) {
   // Clean the packet
   string cleaned = CleanPacket(data);
   
   // Split into parts
   string parts[];
   if(!SplitPackets(cleaned, parts))
      return false;
      
   // Parse each part
   int count = ArraySize(parts);
   ArrayResize(packets, count);
   
   for(int i=0; i<count; i++) {
      if(parts[i] == "") continue;
      
      // Try to parse as JSON
      if(!ParseJSON(parts[i], packets[i])) {
         Print("Warning: Cannot parse packet: ", parts[i]);
         continue;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Format websocket packet                                          |
//+------------------------------------------------------------------+
string Protocol::FormatWSPacket(CJAVal &packet) {
   string msg = packet.Serialize();
   return "~m~" + IntegerToString(StringLen(msg)) + "~m~" + msg;
}

//+------------------------------------------------------------------+
//| Format websocket text packet                                     |
//+------------------------------------------------------------------+
string Protocol::FormatWSPacket(string text) {
   return "~m~" + IntegerToString(StringLen(text)) + "~m~" + text;
}

//+------------------------------------------------------------------+
//| Parse compressed data                                            |
//+------------------------------------------------------------------+
bool Protocol::ParseCompressed(string data, CJAVal &result) {
   // Note: This would require external ZIP implementation
   Print("Warning: ParseCompressed requires external ZIP implementation");
   return false;
}

//+------------------------------------------------------------------+
//| Clean packet data                                                |
//+------------------------------------------------------------------+
string Protocol::CleanPacket(string data) {
   return StringReplace(data, "~h~", "");
}

//+------------------------------------------------------------------+
//| Split packet into parts                                          |
//+------------------------------------------------------------------+
bool Protocol::SplitPackets(string data, string &parts[]) {
   int pos = 0;
   int startPos = 0;
   int length = StringLen(data);
   string pattern = "~m~";
   int patternLen = StringLen(pattern);
   
   while(pos < length) {
      // Find first ~m~
      pos = StringFind(data, pattern, pos);
      if(pos == -1) break;
      
      pos += patternLen;
      
      // Find the number after first ~m~
      string numStr = "";
      while(pos < length && StringGetCharacter(data, pos) >= '0' && StringGetCharacter(data, pos) <= '9') {
         numStr += ShortToString(StringGetCharacter(data, pos));
         pos++;
      }
      
      // Skip second ~m~
      pos = StringFind(data, pattern, pos);
      if(pos == -1) break;
      
      pos += patternLen;
      
      // Extract the packet
      int msgLen = (int)StringToInteger(numStr);
      if(pos + msgLen <= length) {
         string packet = StringSubstr(data, pos, msgLen);
         
         int size = ArraySize(parts);
         ArrayResize(parts, size + 1);
         parts[size] = packet;
         
         pos += msgLen;
      }
      else {
         // Malformed packet
         pos = length;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Parse JSON string                                                |
//+------------------------------------------------------------------+
bool Protocol::ParseJSON(string data, CJAVal &json) {
   return json.Deserialize(data);
}
