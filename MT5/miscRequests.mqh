//+------------------------------------------------------------------+
//|                                                miscRequests.mqh |
//|                      Converted from TradingView-API JavaScript    |
//+------------------------------------------------------------------+
#include <Arrays\ArrayString.mqh>
#include <Arrays\List.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Web\Json.mqh>
#include "utils.mqh"
#include "classes/PineIndicator.mqh"

// Constants
string indicators[] = {"Recommend.Other", "Recommend.All", "Recommend.MA"};
CArrayObj builtInIndicList;

//+------------------------------------------------------------------+
//| Market search result structure                                    |
//+------------------------------------------------------------------+
struct SearchMarketResult {
   string id;                // Market full symbol (e.g. "BINANCE:BTCEUR")
   string exchange;          // Market exchange name
   string fullExchange;      // Market exchange full name
   string symbol;            // Market symbol
   string description;       // Market name
   string type;              // Market type
};

//+------------------------------------------------------------------+
//| Search Indicator Result structure                                 |
//+------------------------------------------------------------------+
struct SearchIndicatorResult {
   string id;                // Script ID
   string version;           // Script version
   string name;              // Script complete name
   int    authorId;          // Author user ID
   string authorUsername;    // Author username
   string image;             // Image ID
   string source;            // Script source (if available)
   string type;              // Script type (study / strategy)
   string access;            // Script access type
};

//+------------------------------------------------------------------+
//| User structure                                                    |
//+------------------------------------------------------------------+
struct User {
   int    id;                // User ID
   string username;          // User username
   string firstName;         // User first name
   string lastName;          // User last name
   double reputation;        // User reputation
   int    following;         // Number of following accounts
   int    followers;         // Number of followers
   int    notificationsUser; // User notifications
   int    notificationsFollowing; // Notification from following accounts
   string session;           // User session
   string sessionHash;       // User session hash
   string signature;         // User session signature
   string privateChannel;    // User private channel
   string authToken;         // User auth token
   datetime joinDate;        // Account creation date
};

//+------------------------------------------------------------------+
//| Drawing point structure                                           |
//+------------------------------------------------------------------+
struct DrawingPoint {
   datetime time_t;          // Point X time position
   double price;             // Point Y price position
   int    offset;            // Point offset
};

//+------------------------------------------------------------------+
//| Drawing structure                                                 |
//+------------------------------------------------------------------+
struct Drawing {
   string id;                // Drawing ID
   string symbol;            // Layout market symbol
   string ownerSource;       // Owner user ID
   string serverUpdateTime;  // Drawing last update timestamp
   string currencyId;        // Currency ID
   string unitId;            // Unit ID
   string type;              // Drawing type
   DrawingPoint points[];    // List of drawing points
   int    zorder;            // Drawing Z order
   string linkKey;           // Drawing link key
};

//+------------------------------------------------------------------+
//| Period structure                                                  |
//+------------------------------------------------------------------+
struct Period {
   double Other;             // Other recommendation
   double All;               // All recommendation
   double MA;                // MA recommendation
};

//+------------------------------------------------------------------+
//| Periods structure                                                 |
//+------------------------------------------------------------------+
struct Periods {
   Period period1;           // 1 minute period
   Period period5;           // 5 minute period
   Period period15;          // 15 minute period
   Period period60;          // 60 minute period
   Period period240;         // 240 minute period
   Period period1D;          // 1 day period
   Period period1W;          // 1 week period
   Period period1M;          // 1 month period
};

//+------------------------------------------------------------------+
//| Validate status helper function                                   |
//+------------------------------------------------------------------+
bool validateStatus(int status) {
   return status < 500;
}

//+------------------------------------------------------------------+
//| Fetch scan data helper function                                   |
//+------------------------------------------------------------------+
bool fetchScanData(CJAVal &result, const string &tickers[], const string &columns[]) {
   string url = "https://scanner.tradingview.com/global/scan";
   string data = "";
   string headers = "Content-Type: application/json\r\n";
   char post[];
   
   // Create JSON payload
   CJAVal json;
   CJAVal symbols;
   CJAVal jsonTickers;
   
   // Add tickers array
   for(int i = 0; i < ArraySize(tickers); i++) {
      jsonTickers[i] = tickers[i];
   }
   symbols["tickers"] = jsonTickers;
   json["symbols"] = symbols;
   
   // Add columns array
   CJAVal jsonColumns;
   for(int i = 0; i < ArraySize(columns); i++) {
      jsonColumns[i] = columns[i];
   }
   json["columns"] = jsonColumns;
   
   // Convert to JSON string
   string jsonString = json.Serialize();
   StringToCharArray(jsonString, post);
   
   // Make the request
   char response[];
   int res = WebRequest("POST", url, headers, 0, post, response, data);
   
   if(res == -1) {
      int errorCode = GetLastError();
      Print("Error in WebRequest: ", errorCode, " - ", ErrorDescription(errorCode));
      return false;
   }
   
   // Parse JSON response
   result.Deserialize(response);
   return true;
}

//+------------------------------------------------------------------+
//| Get technical analysis                                           |
//+------------------------------------------------------------------+
bool getTA(Periods &result, const string id) {
   // Prepare columns
   string timeframes[] = {"1", "5", "15", "60", "240", "1D", "1W", "1M"};
   string cols[];
   int colIndex = 0;
   
   // Create columns array
   for(int t = 0; t < ArraySize(timeframes); t++) {
      for(int i = 0; i < ArraySize(indicators); i++) {
         string col = timeframes[t] != "1D" ? 
            indicators[i] + "|" + timeframes[t] : 
            indicators[i];
         
         ArrayResize(cols, colIndex + 1);
         cols[colIndex++] = col;
      }
   }
   
   // Prepare ticker
   string tickers[1] = {id};
   
   // Fetch data
   CJAVal response;
   if(!fetchScanData(response, tickers, cols)) {
      return false;
   }
   
   // Check for results
   if(!response["data"].IsArray() || response["data"].Size() == 0) {
      return false;
   }
   
   // Process results
   int dataIndex = 0;
   for(int i = 0; i < cols.Size(); i++) {
      string parts[];
      string col = cols[i];
      
      // Split column into name and period
      StringSplit(col, '|', parts);
      string name = parts[0];
      string period = ArraySize(parts) > 1 ? parts[1] : "1D";
      
      // Extract value
      double value = response["data"][0]["d"][i].ToDbl();
      double roundedValue = MathRound(value * 1000) / 500;
      
      // Store in appropriate period structure
      if(period == "1") {
         if(StringFind(name, "Other") >= 0) result.period1.Other = roundedValue;
         else if(StringFind(name, "All") >= 0) result.period1.All = roundedValue;
         else if(StringFind(name, "MA") >= 0) result.period1.MA = roundedValue;
      }
      else if(period == "5") {
         if(StringFind(name, "Other") >= 0) result.period5.Other = roundedValue;
         else if(StringFind(name, "All") >= 0) result.period5.All = roundedValue;
         else if(StringFind(name, "MA") >= 0) result.period5.MA = roundedValue;
      }
      else if(period == "15") {
         if(StringFind(name, "Other") >= 0) result.period15.Other = roundedValue;
         else if(StringFind(name, "All") >= 0) result.period15.All = roundedValue;
         else if(StringFind(name, "MA") >= 0) result.period15.MA = roundedValue;
      }
      else if(period == "60") {
         if(StringFind(name, "Other") >= 0) result.period60.Other = roundedValue;
         else if(StringFind(name, "All") >= 0) result.period60.All = roundedValue;
         else if(StringFind(name, "MA") >= 0) result.period60.MA = roundedValue;
      }
      else if(period == "240") {
         if(StringFind(name, "Other") >= 0) result.period240.Other = roundedValue;
         else if(StringFind(name, "All") >= 0) result.period240.All = roundedValue;
         else if(StringFind(name, "MA") >= 0) result.period240.MA = roundedValue;
      }
      else if(period == "1D") {
         if(StringFind(name, "Other") >= 0) result.period1D.Other = roundedValue;
         else if(StringFind(name, "All") >= 0) result.period1D.All = roundedValue;
         else if(StringFind(name, "MA") >= 0) result.period1D.MA = roundedValue;
      }
      else if(period == "1W") {
         if(StringFind(name, "Other") >= 0) result.period1W.Other = roundedValue;
         else if(StringFind(name, "All") >= 0) result.period1W.All = roundedValue;
         else if(StringFind(name, "MA") >= 0) result.period1W.MA = roundedValue;
      }
      else if(period == "1M") {
         if(StringFind(name, "Other") >= 0) result.period1M.Other = roundedValue;
         else if(StringFind(name, "All") >= 0) result.period1M.All = roundedValue;
         else if(StringFind(name, "MA") >= 0) result.period1M.MA = roundedValue;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Search market v3                                                  |
//+------------------------------------------------------------------+
bool searchMarketV3(SearchMarketResult &results[], const string search, const string filter = "") {
   // Process search string
   string searchUpper = StringUpper(search);
   StringReplace(searchUpper, " ", "+");
   
   string parts[];
   StringSplit(searchUpper, ':', parts);
   
   string url = "https://symbol-search.tradingview.com/symbol_search/v3";
   string params = "?text=" + parts[ArraySize(parts)-1]; // Get last part
   
   if(ArraySize(parts) == 2) {
      params += "&exchange=" + parts[0];
   }
   
   if(filter != "") {
      params += "&search_type=" + filter;
   }
   
   string headers = "Origin: https://www.tradingview.com\r\n";
   string data = "";
   
   // Make the request
   char response[];
   int res = WebRequest("GET", url + params, headers, 0, NULL, response, data);
   
   if(res == -1) {
      int errorCode = GetLastError();
      Print("Error in WebRequest: ", errorCode, " - ", ErrorDescription(errorCode));
      return false;
   }
   
   // Parse JSON response
   CJAVal json;
   if(!json.Deserialize(response)) {
      Print("Error deserializing JSON response");
      return false;
   }
   
   // Process results
   int symbolsCount = json["symbols"].Size();
   ArrayResize(results, symbolsCount);
   
   for(int i = 0; i < symbolsCount; i++) {
      CJAVal symbol = json["symbols"][i];
      string exchange = symbol["exchange"].ToStr();
      
      // Split exchange if necessary
      string exchangeParts[];
      StringSplit(exchange, ' ', exchangeParts);
      string shortExchange = exchangeParts[0];
      
      // Create symbol ID
      string prefix = symbol["prefix"].ToStr();
      string symbolName = symbol["symbol"].ToStr();
      
      results[i].id = prefix != "" ? 
         prefix + ":" + symbolName : 
         StringUpper(shortExchange) + ":" + symbolName;
      
      results[i].exchange = shortExchange;
      results[i].fullExchange = exchange;
      results[i].symbol = symbolName;
      results[i].description = symbol["description"].ToStr();
      results[i].type = symbol["type"].ToStr();
   }
   
   return symbolsCount > 0;
}

//+------------------------------------------------------------------+
//| Search indicator                                                 |
//+------------------------------------------------------------------+
bool searchIndicator(SearchIndicatorResult &results[], const string search = "") {
   // If built-in indicator list is empty, populate it
   if(builtInIndicList.Total() == 0) {
      string types[] = {"standard", "candlestick", "fundamental"};
      
      for(int t = 0; t < ArraySize(types); t++) {
         string url = "https://pine-facade.tradingview.com/pine-facade/list";
         string params = "?filter=" + types[t];
         string headers = "";
         string data = "";
         
         // Make the request
         char response[];
         int res = WebRequest("GET", url + params, headers, 0, NULL, response, data);
         
         if(res != -1) {
            CJAVal json;
            if(json.Deserialize(response) && json.IsArray()) {
               for(int i = 0; i < json.Size(); i++) {
                  builtInIndicList.Add(new CJAVal(json[i]));
               }
            }
         }
      }
   }
   
   // Search in public scripts
   string url = "https://www.tradingview.com/pubscripts-suggest-json";
   string searchEncoded = search;
   StringReplace(searchEncoded, " ", "%20");
   string params = "?search=" + searchEncoded;
   string headers = "";
   string data = "";
   
   // Make the request
   char response[];
   int res = WebRequest("GET", url + params, headers, 0, NULL, response, data);
   
   CArrayObj resultsList;
   
   // Helper function to normalize strings for case-insensitive comparison
   string norm(string str) {
      string result = StringUpper(str);
      StringReplace(result, " ", "");
      return result;
   }
   
   // Process built-in indicators
   string searchNorm = norm(search);
   
   for(int i = 0; i < builtInIndicList.Total(); i++) {
      CJAVal* indic = builtInIndicList.At(i);
      
      string scriptName = indic.GetProperty("scriptName").ToStr();
      string shortDesc = indic.GetProperty("extra").GetProperty("shortDescription").ToStr();
      
      if(StringFind(norm(scriptName), searchNorm) >= 0 || 
         StringFind(norm(shortDesc), searchNorm) >= 0) {
         
         // Create result
         SearchIndicatorResult result;
         result.id = indic.GetProperty("scriptIdPart").ToStr();
         result.version = indic.GetProperty("version").ToStr();
         result.name = scriptName;
         result.authorId = -1;
         result.authorUsername = "@TRADINGVIEW@";
         result.image = "";
         result.source = "";
         result.access = "closed_source";
         
         // Determine type
         if(indic.GetProperty("extra").HasKey("kind")) {
            result.type = indic.GetProperty("extra").GetProperty("kind").ToStr();
         } else {
            result.type = "study";
         }
         
         resultsList.Add(new SearchIndicatorResult(result));
      }
   }
   
   // Process public indicators if request succeeded
   if(res != -1) {
      CJAVal json;
      if(json.Deserialize(response)) {
         CJAVal results = json["results"];
         
         for(int i = 0; i < results.Size(); i++) {
            CJAVal ind = results[i];
            
            SearchIndicatorResult result;
            result.id = ind["scriptIdPart"].ToStr();
            result.version = ind["version"].ToStr();
            result.name = ind["scriptName"].ToStr();
            result.authorId = (int)ind["author"]["id"].ToInt();
            result.authorUsername = ind["author"]["username"].ToStr();
            result.image = ind["imageUrl"].ToStr();
            result.source = ind["scriptSource"].ToStr();
            
            // Determine access type
            int access = (int)ind["access"].ToInt();
            if(access == 1) result.access = "open_source";
            else if(access == 2) result.access = "closed_source";
            else if(access == 3) result.access = "invite_only";
            else result.access = "other";
            
            // Determine type
            if(ind.HasKey("extra") && ind["extra"].HasKey("kind")) {
               result.type = ind["extra"]["kind"].ToStr();
            } else {
               result.type = "study";
            }
            
            resultsList.Add(new SearchIndicatorResult(result));
         }
      }
   }
   
   // Convert result list to array
   int count = resultsList.Total();
   ArrayResize(results, count);
   
   for(int i = 0; i < count; i++) {
      results[i] = *(SearchIndicatorResult*)resultsList.At(i);
   }
   
   return count > 0;
}

//+------------------------------------------------------------------+
//| Get indicator                                                    |
//+------------------------------------------------------------------+
PineIndicator* getIndicator(const string id, const string version = "last", 
                          const string session = "", const string signature = "") {
   // Process indicator ID
   string indicID = id;
   StringReplace(indicID, " ", "%25");
   StringReplace(indicID, "%", "%25");
   
   // Prepare request
   string url = "https://pine-facade.tradingview.com/pine-facade/translate/" + 
                indicID + "/" + version;
   
   string headers = "";
   if(session != "") {
      headers = "Cookie: " + genAuthCookies(session, signature) + "\r\n";
   }
   
   string data = "";
   
   // Make the request
   char response[];
   int res = WebRequest("GET", url, headers, 0, NULL, response, data);
   
   if(res == -1) {
      int errorCode = GetLastError();
      Print("Error in WebRequest: ", errorCode, " - ", ErrorDescription(errorCode));
      return NULL;
   }
   
   // Parse JSON response
   CJAVal json;
   if(!json.Deserialize(response)) {
      Print("Error deserializing JSON response");
      return NULL;
   }
   
   // Check for success
   if(!json["success"].ToBool() || !json["result"].HasKey("metaInfo") || 
      !json["result"]["metaInfo"].HasKey("inputs")) {
      string reason = json["reason"].ToStr();
      Print("Inexistent or unsupported indicator: \"", reason, "\"");
      return NULL;
   }
   
   // Create Pine Indicator
   PineIndicator* indicator = new PineIndicator(
      json["result"]["metaInfo"]["scriptIdPart"].ToStr(),
      json["result"]["metaInfo"]["pine"]["version"].ToStr(),
      json["result"]["metaInfo"]["description"].ToStr(),
      json["result"]["metaInfo"]["shortDescription"].ToStr(),
      json["result"]["ilTemplate"].ToStr()
   );
   
   // Process inputs
   CJAVal inputs = json["result"]["metaInfo"]["inputs"];
   for(int i = 0; i < inputs.Size(); i++) {
      CJAVal input = inputs[i];
      string inputId = input["id"].ToStr();
      
      // Skip certain inputs
      if(inputId == "text" || inputId == "pineId" || inputId == "pineVersion") {
         continue;
      }
      
      // Process the input name
      string inputName = input["name"].ToStr();
      string inlineName = input["inline"].ToStr();
      
      if(inlineName == "") {
         inlineName = StringReplace(inputName, " ", "_");
         // Clean up the name
         for(int c = 0; c < StringLen(inlineName); c++) {
            if(!((inlineName[c] >= 'a' && inlineName[c] <= 'z') || 
                 (inlineName[c] >= 'A' && inlineName[c] <= 'Z') || 
                 (inlineName[c] >= '0' && inlineName[c] <= '9') || 
                 inlineName[c] == '_')) {
               StringReplace(inlineName, StringSubstr(inlineName, c, 1), "");
               c--;
            }
         }
      }
      
      string internalID = input["internalID"].ToStr();
      if(internalID == "") {
         internalID = inlineName;
      }
      
      // Create and set the input
      IndicatorInput indicInput;
      indicInput.name = inputName;
      indicInput.inline_name = inlineName;
      indicInput.internalID = internalID;
      indicInput.tooltip = input["tooltip"].ToStr();
      
      // Set type
      string type = input["type"].ToStr();
      if(type == "text") indicInput.type = INPUT_TYPE_TEXT;
      else if(type == "source") indicInput.type = INPUT_TYPE_SOURCE;
      else if(type == "integer") indicInput.type = INPUT_TYPE_INTEGER;
      else if(type == "float") indicInput.type = INPUT_TYPE_FLOAT;
      else if(type == "resolution") indicInput.type = INPUT_TYPE_RESOLUTION;
      else if(type == "bool") indicInput.type = INPUT_TYPE_BOOL;
      else if(type == "color") indicInput.type = INPUT_TYPE_COLOR;
      
      // Set value and other properties
      indicInput.value = input["defval"].ToStr();
      indicInput.isHidden = input["isHidden"].ToBool();
      indicInput.isFake = input["isFake"].ToBool();
      
      // Add options if present
      if(input.HasKey("options")) {
         CJAVal options = input["options"];
         ArrayResize(indicInput.options, options.Size());
         
         for(int o = 0; o < options.Size(); o++) {
            indicInput.options[o] = options[o].ToStr();
         }
      }
      
      // Add the input to the indicator
      indicator.AddInput(inputId, indicInput);
   }
   
   // Process plots
   CJAVal styles = json["result"]["metaInfo"]["styles"];
   for(int i = 0; i < styles.Size(); i++) {
      string plotId = styles[i].m_key;
      string plotTitle = styles[i]["title"].ToStr();
      
      // Clean up the title
      plotTitle = StringReplace(plotTitle, " ", "_");
      for(int c = 0; c < StringLen(plotTitle); c++) {
         if(!((plotTitle[c] >= 'a' && plotTitle[c] <= 'z') || 
              (plotTitle[c] >= 'A' && plotTitle[c] <= 'Z') || 
              (plotTitle[c] >= '0' && plotTitle[c] <= '9') || 
              plotTitle[c] == '_')) {
            StringReplace(plotTitle, StringSubstr(plotTitle, c, 1), "");
            c--;
         }
      }
      
      // Check for duplicate plot titles
      bool duplicate = false;
      for(int j = 0; j < i; j++) {
         string existingTitle;
         if(indicator.GetPlot(styles[j].m_key, existingTitle)) {
            if(existingTitle == plotTitle) {
               duplicate = true;
               int suffix = 2;
               string newTitle;
               do {
                  newTitle = plotTitle + "_" + IntegerToString(suffix);
                  suffix++;
                  
                  // Check if this new title is also a duplicate
                  bool stillDuplicate = false;
                  for(int k = 0; k < i; k++) {
                     string checkTitle;
                     if(indicator.GetPlot(styles[k].m_key, checkTitle) && checkTitle == newTitle) {
                        stillDuplicate = true;
                        break;
                     }
                  }
                  
                  if(!stillDuplicate) {
                     plotTitle = newTitle;
                     duplicate = false;
                  }
               } while(duplicate);
            }
         }
      }
      
      // Add the plot
      indicator.AddPlot(plotId, plotTitle);
   }
   
   // Process secondary plots
   CJAVal plots = json["result"]["metaInfo"]["plots"];
   for(int i = 0; i < plots.Size(); i++) {
      CJAVal plot = plots[i];
      if(!plot.HasKey("target")) {
         continue;
      }
      
      string plotId = plot["id"].ToStr();
      string targetId = plot["target"].ToStr();
      string plotType = plot["type"].ToStr();
      
      string targetTitle;
      if(indicator.GetPlot(targetId, targetTitle)) {
         indicator.AddPlot(plotId, targetTitle + "_" + plotType);
      } else {
         indicator.AddPlot(plotId, targetId + "_" + plotType);
      }
   }
   
   // Set type if needed
   string kind = json["result"]["metaInfo"]["extra"]["kind"].ToStr();
   if(kind == "strategy") {
      indicator.SetType(INDICATOR_TYPE_STRATEGY);
   }
   
   return indicator;
}

//+------------------------------------------------------------------+
//| Helper function to extract value from HTML using pattern          |
//+------------------------------------------------------------------+
string ExtractValue(const string &html, const string &pattern, const string &endPattern, int startPos = 0) {
   int pos = StringFind(html, pattern, startPos);
   if(pos == -1) return "";
   
   int valueStart = pos + StringLen(pattern);
   int valueEnd = StringFind(html, endPattern, valueStart);
   if(valueEnd == -1) return "";
   
   return StringSubstr(html, valueStart, valueEnd - valueStart);
}

//+------------------------------------------------------------------+
//| Helper function to extract numeric value from HTML                |
//+------------------------------------------------------------------+
double ExtractNumericValue(const string &html, const string &pattern, const string &endPattern, int startPos = 0, double defaultValue = 0) {
   string value = ExtractValue(html, pattern, endPattern, startPos);
   if(value == "") return defaultValue;
   
   return StringToDouble(value);
}

//+------------------------------------------------------------------+
//| Get user from sessionid cookie                                    |
//+------------------------------------------------------------------+
bool getUser(User &user, const string session, const string signature = "", 
            const string location = "https://www.tradingview.com/") {
   // Prepare request
   string url = location;
   string headers = "Cookie: " + genAuthCookies(session, signature) + "\r\n";
   string data = "";
   string redirectLocation = "";
   
   // Make the request
   char response[];
   int res = WebRequest("GET", url, headers, 0, NULL, response, data, redirectLocation);
   
   if(res == -1) {
      int errorCode = GetLastError();
      Print("Error in WebRequest: ", errorCode, " - ", ErrorDescription(errorCode));
      return false;
   }
   
   // Convert response to string for parsing
   string htmlContent = CharArrayToString(response);
   
   // Check for auth_token which indicates successful login
   if(StringFind(htmlContent, "auth_token") >= 0) {
      // Extract user information using patterns
      user.id = (int)StringToInteger(ExtractValue(htmlContent, "\"id\":", ","));
      user.username = ExtractValue(htmlContent, "\"username\":\"", "\"");
      user.firstName = ExtractValue(htmlContent, "\"first_name\":\"", "\"");
      user.lastName = ExtractValue(htmlContent, "\"last_name\":\"", "\"");
      user.reputation = StringToDouble(ExtractValue(htmlContent, "\"reputation\":", ","));
      user.following = (int)StringToInteger(ExtractValue(htmlContent, ",\"following\":", ","));
      user.followers = (int)StringToInteger(ExtractValue(htmlContent, ",\"followers\":", ","));
      
      // Extract notification counts
      string notificationStr = ExtractValue(htmlContent, "\"notification_count\":{\"following\":", ",\"user\":");
      user.notificationsFollowing = (int)StringToInteger(notificationStr);
      
      string userNotificationStr = ExtractValue(htmlContent, "\"notification_count\":{\"following\":" + notificationStr + ",\"user\":", "}");
      user.notificationsUser = (int)StringToInteger(userNotificationStr);
      
      // Set session information
      user.session = session;
      user.signature = signature;
      user.sessionHash = ExtractValue(htmlContent, "\"session_hash\":\"", "\"");
      user.privateChannel = ExtractValue(htmlContent, "\"private_channel\":\"", "\"");
      user.authToken = ExtractValue(htmlContent, "\"auth_token\":\"", "\"");
      
      // Convert join date
      string dateJoined = ExtractValue(htmlContent, "\"date_joined\":\"", "\"");
      user.joinDate = StringToTime(dateJoined);
      
      return true;
   }
   
   // Handle redirect
   if(redirectLocation != "" && redirectLocation != location) {
      return getUser(user, session, signature, redirectLocation);
   }
   
   Print("Wrong or expired sessionid/signature");
   return false;
}

//+------------------------------------------------------------------+
//| Login user                                                       |
//+------------------------------------------------------------------+
bool loginUser(User &user, const string username, const string password, 
              bool remember = true, const string UA = "TWAPI/3.0") {
   // Prepare request
   string url = "https://www.tradingview.com/accounts/signin/";
   string postData = "username=" + username + "&password=" + password;
   
   if(remember) {
      postData += "&remember=on";
   }
   
   string osInfo;
   #ifdef __APPLE__
   osInfo = "macOS";
   #elif defined(__WINDOWS__)
   osInfo = "Windows";
   #else
   osInfo = "Linux";
   #endif
   
   string headers = "referer: https://www.tradingview.com\r\n" + 
                   "Content-Type: application/x-www-form-urlencoded\r\n" + 
                   "User-agent: " + UA + " (" + osInfo + ")\r\n";
   
   string cookies;
   string data = "";
   
   // Make the request
   char post[];
   StringToCharArray(postData, post);
   
   char response[];
   int res = WebRequest("POST", url, headers, 0, post, response, cookies);
   
   if(res == -1) {
      int errorCode = GetLastError();
      Print("Error in WebRequest: ", errorCode, " - ", ErrorDescription(errorCode));
      return false;
   }
   
   // Parse cookies
   string session = "";
   string signature = "";
   
   string cookieParts[];
   StringSplit(cookies, '\n', cookieParts);
   
   for(int i = 0; i < ArraySize(cookieParts); i++) {
      if(StringFind(cookieParts[i], "sessionid=") >= 0) {
         string sessionParts[];
         StringSplit(sessionParts[i], ';', sessionParts);
         session = StringSubstr(sessionParts[0], StringFind(sessionParts[0], "=") + 1);
      }
      
      if(StringFind(cookieParts[i], "sessionid_sign=") >= 0) {
         string signParts[];
         StringSplit(cookieParts[i], ';', signParts);
         signature = StringSubstr(signParts[0], StringFind(signParts[0], "=") + 1);
      }
   }
   
   // Parse JSON response
   CJAVal json;
   if(!json.Deserialize(response)) {
      Print("Error deserializing JSON response");
      return false;
   }
   
   // Check for error
   if(json.HasKey("error")) {
      Print("Login error: ", json["error"].ToStr());
      return false;
   }
   
   // Populate user structure
   user.id = (int)json["user"]["id"].ToInt();
   user.username = json["user"]["username"].ToStr();
   user.firstName = json["user"]["first_name"].ToStr();
   user.lastName = json["user"]["last_name"].ToStr();
   user.reputation = json["user"]["reputation"].ToDbl();
   user.following = (int)json["user"]["following"].ToInt();
   user.followers = (int)json["user"]["followers"].ToInt();
   user.notificationsUser = (int)json["user"]["notification_count"]["user"].ToInt();
   user.notificationsFollowing = (int)json["user"]["notification_count"]["following"].ToInt();
   user.session = session;
   user.signature = signature;
   user.sessionHash = json["user"]["session_hash"].ToStr();
   user.privateChannel = json["user"]["private_channel"].ToStr();
   user.authToken = json["user"]["auth_token"].ToStr();
   
   // Convert date string to datetime
   string dateJoined = json["user"]["date_joined"].ToStr();
   user.joinDate = StringToTime(dateJoined);
   
   return true;
}
