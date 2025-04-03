//+------------------------------------------------------------------+
//| TradingView API Protocol functions for MQL5                       |
//+------------------------------------------------------------------+
#include <Web\Json.mqh>

// Missing helper functions for packet handling

//+------------------------------------------------------------------+
//| Convert CJAVal to packet string                                  |
//| @param CJAVal json - The JSON object to convert                   |
//| @return string - JSON string for WebSocket packet                 |
//+------------------------------------------------------------------+
string JSONToPacket(CJAVal &json) {
   return json.Serialize();
}

//+------------------------------------------------------------------+
//| Parse JSON string to CJAVal                                      |
//| @param string str - JSON string                                   |
//| @param CJAVal &json - Output JSON object                          |
//| @return bool - Success or failure                                 |
//+------------------------------------------------------------------+
bool PacketToJSON(string str, CJAVal &json) {
   return json.Deserialize(str);
}

//+------------------------------------------------------------------+
//| Parse websocket packet                                           |
//| @param string str - Websocket raw data                           |
//| @return string[] - Array of parsed packets                       |
//+------------------------------------------------------------------+
string[] ParseWSPacket(string str)
{
   string result[];
   
   // Clean the string by removing "~h~"
   str = StringReplace(str, "~h~", "");
   
   // Split by the pattern ~m~NN~m~
   int pos = 0;
   int startPos = 0;
   int length = StringLen(str);
   string pattern = "~m~";
   int patternLen = StringLen(pattern);
   
   while(pos < length)
   {
      // Find first ~m~
      pos = StringFind(str, pattern, pos);
      if(pos == -1) break;
      
      pos += patternLen;
      
      // Find the number after first ~m~
      string numStr = "";
      while(pos < length && StringGetCharacter(str, pos) >= '0' && StringGetCharacter(str, pos) <= '9')
      {
         numStr += ShortToString(StringGetCharacter(str, pos));
         pos++;
      }
      
      // Skip second ~m~
      pos = StringFind(str, pattern, pos);
      if(pos == -1) break;
      
      pos += patternLen;
      
      // Extract the packet
      int msgLen = (int)StringToInteger(numStr);
      if(pos + msgLen <= length)
      {
         string packet = StringSubstr(str, pos, msgLen);
         
         // Try to parse JSON (in a real implementation, you'd need a JSON parser)
         if(packet != "")
         {
            int size = ArraySize(result);
            ArrayResize(result, size + 1);
            result[size] = packet;
         }
         
         pos += msgLen;
      }
      else
      {
         // Malformed packet, skip
         pos = length;
      }
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Format websocket packet                                          |
//| @param string packet - The packet to format                      |
//| @return string - Formatted websocket data                        |
//+------------------------------------------------------------------+
string FormatWSPacket(string packet)
{
   int length = StringLen(packet);
   return "~m~" + IntegerToString(length) + "~m~" + packet;
}

//+------------------------------------------------------------------+
//| JSON utility functions - basic implementation                    |
//+------------------------------------------------------------------+
// Note: MQL5 does not have native JSON parsing. 
// These are simplified helpers - for complex JSON, use a library

bool IsJSONObject(string str)
{
   str = StringTrimLeft(StringTrimRight(str));
   return StringLen(str) >= 2 && StringGetCharacter(str, 0) == '{' && 
          StringGetCharacter(str, StringLen(str) - 1) == '}';
}

bool IsJSONArray(string str)
{
   str = StringTrimLeft(StringTrimRight(str));
   return StringLen(str) >= 2 && StringGetCharacter(str, 0) == '[' && 
          StringGetCharacter(str, StringLen(str) - 1) == ']';
}

//+------------------------------------------------------------------+
//| Parse compressed data - LIMITED FUNCTIONALITY                    |
//| @param string data - Base64 encoded compressed data              |
//| @return string - Warning about limitations                       |
//+------------------------------------------------------------------+
string ParseCompressed(string data)
{
   // MQL5 does not have built-in ZIP functionality
   // To implement this, you would need:
   // 1. Base64 decode function
   // 2. ZIP decompression (possibly via external DLL)
   
   Print("WARNING: ParseCompressed function requires external ZIP implementation");
   return "ZIP functionality requires external implementation";
}
