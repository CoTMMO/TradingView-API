//+------------------------------------------------------------------+
//|                                             PinePermManager.mqh |
//|                                                                  |
//+------------------------------------------------------------------+
#include <JAson.mqh>
#include "../utils.mqh"

//+------------------------------------------------------------------+
//| Class for managing Pine script permissions                        |
//+------------------------------------------------------------------+
class PinePermManager
{
private:
   string   m_sessionId;
   string   m_signature;
   string   m_pineId;

public:
   // Constructor
   PinePermManager(string sessionId, string signature, string pineId);
   
   // Methods
   bool     GetUsers(CJAVal &results, int limit=10, string order="-created");
   string   AddUser(string username, datetime expiration=0);
   string   ModifyExpiration(string username, datetime expiration=0);
   string   RemoveUser(string username);

private:
   // Helper methods
   string   EncodePineId();
   bool     SendRequest(string url, string postData, CJAVal &response);
   string   DateTimeToISOString(datetime dt);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
PinePermManager::PinePermManager(string sessionId, string signature, string pineId)
{
   if(sessionId == "") 
   {
      Print("Error: Please provide a SessionID");
      return;
   }
   
   if(signature == "") 
   {
      Print("Error: Please provide a Signature");
      return;
   }
   
   if(pineId == "") 
   {
      Print("Error: Please provide a PineID");
      return;
   }
   
   m_sessionId = sessionId;
   m_signature = signature;
   m_pineId = pineId;
}

//+------------------------------------------------------------------+
//| Get list of authorized users                                      |
//+------------------------------------------------------------------+
bool PinePermManager::GetUsers(CJAVal &results, int limit=10, string order="-created")
{
   string url = "https://www.tradingview.com/pine_perm/list_users/?limit=" + 
                IntegerToString(limit) + "&order_by=" + order;
   
   string postData = "pine_id=" + EncodePineId();
   
   CJAVal response;
   if(!SendRequest(url, postData, response))
      return false;
      
   if(response.HasKey("results"))
   {
      results = response["results"];
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Adds an user to the authorized list                               |
//+------------------------------------------------------------------+
string PinePermManager::AddUser(string username, datetime expiration=0)
{
   string url = "https://www.tradingview.com/pine_perm/add/";
   string postData = "pine_id=" + EncodePineId() + "&username_recip=" + username;
   
   if(expiration > 0)
   {
      postData += "&expiration=" + DateTimeToISOString(expiration);
   }
   
   CJAVal response;
   if(!SendRequest(url, postData, response))
      return "";
      
   if(response.HasKey("status"))
      return response["status"].ToStr();
      
   return "";
}

//+------------------------------------------------------------------+
//| Modify an authorization expiration date                           |
//+------------------------------------------------------------------+
string PinePermManager::ModifyExpiration(string username, datetime expiration=0)
{
   string url = "https://www.tradingview.com/pine_perm/modify_user_expiration/";
   string postData = "pine_id=" + EncodePineId() + "&username_recip=" + username;
   
   if(expiration > 0)
   {
      postData += "&expiration=" + DateTimeToISOString(expiration);
   }
   
   CJAVal response;
   if(!SendRequest(url, postData, response))
      return "";
      
   if(response.HasKey("status"))
      return response["status"].ToStr();
      
   return "";
}

//+------------------------------------------------------------------+
//| Removes an user from the authorized list                          |
//+------------------------------------------------------------------+
string PinePermManager::RemoveUser(string username)
{
   string url = "https://www.tradingview.com/pine_perm/remove/";
   string postData = "pine_id=" + EncodePineId() + "&username_recip=" + username;
   
   CJAVal response;
   if(!SendRequest(url, postData, response))
      return "";
      
   if(response.HasKey("status"))
      return response["status"].ToStr();
      
   return "";
}

//+------------------------------------------------------------------+
//| URL encode the Pine ID                                            |
//+------------------------------------------------------------------+
string PinePermManager::EncodePineId()
{
   string result = m_pineId;
   StringReplace(result, ";", "%3B");
   return result;
}

//+------------------------------------------------------------------+
//| Send HTTP request and parse response                              |
//+------------------------------------------------------------------+
bool PinePermManager::SendRequest(string url, string postData, CJAVal &response)
{
   char data[];
   StringToCharArray(postData, data);
   
   char result[];
   string headers = 
      "Content-Type: application/x-www-form-urlencoded\r\n" +
      "Origin: https://www.tradingview.com\r\n" +
      "Cookie: " + genAuthCookies(m_sessionId, m_signature);
   
   string responseHeaders[];
   int res = WebRequest("POST", url, headers, 10000, data, result, responseHeaders);
   
   if(res == -1)
   {
      int error = GetLastError();
      Print("WebRequest failed. Error code: ", error);
      
      // Common error - need to allow URL in settings
      if(error == 4060) 
      {
         Print("Make sure to add the URL to Tools -> Options -> Expert Advisors -> Allow WebRequest for listed URL:");
         Print(url);
      }
      
      return false;
   }
   
   if(res != 200)
   {
      Print("HTTP request failed with code: ", res);
      return false;
   }
   
   string jsonStr = CharArrayToString(result);
   
   // Parse the JSON response
   if(!response.Deserialize(jsonStr))
   {
      Print("Failed to parse JSON response: ", jsonStr);
      return false;
   }
   
   // Check for error details in response
   if(response.HasKey("detail"))
   {
      Print("Error from server: ", response["detail"].ToStr());
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Convert MQL datetime to ISO string format                         |
//+------------------------------------------------------------------+
string PinePermManager::DateTimeToISOString(datetime dt)
{
   // Format: YYYY-MM-DDTHH:MM:SS.000Z
   MqlDateTime tm;
   TimeToStruct(dt, tm);
   
   string result = StringFormat("%04d-%02d-%02dT%02d:%02d:%02d.000Z",
      tm.year, tm.mon, tm.day, tm.hour, tm.min, tm.sec);
   
   return result;
}
