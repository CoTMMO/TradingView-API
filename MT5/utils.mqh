//+------------------------------------------------------------------+
//| Utility functions for the TradingView API                        |
//+------------------------------------------------------------------+
class Utils {
public:

/**
 * Generates a session id
 * @param string type Session type
 * @return string Generated session ID
 */
string genSessionID(string type="xs") {
   string r = "";
   string c = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
   int len = StringLen(c);
   
   for(int i = 0; i < 12; i++) {
      int randomIndex = MathRand() % len;
      r += StringSubstr(c, randomIndex, 1);
   }
   
   return type + "_" + r;
}

/**
 * Generates authentication cookies
 * @param string sessionId Session ID
 * @param string signature Session signature
 * @return string Generated cookies string
 */
string genAuthCookies(string sessionId="", string signature="") {
   if(sessionId == "") return "";
   if(signature == "") return "sessionid=" + sessionId;
   return "sessionid=" + sessionId + ";sessionid_sign=" + signature;
}

};
//+------------------------------------------------------------------+
//| End of Utils class                                              |