//+------------------------------------------------------------------+
//|                                           TradingViewExample.mq5 |
//|                                         Copyright 2025, Your Name |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Name"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include "TradingViewClient.mqh"
#include "TradingViewSession.mqh"

// Global variables
TVWebSocketClient *client = NULL;
TradingViewSession *session = NULL;

// Price update callback function
void OnPriceUpdate(const string symbol, const OHLCV &data)
{
    // Process the received data
    Print(symbol + " Update: " + 
          "Time: " + TimeToString(data.time) + 
          ", O: " + DoubleToString(data.open, 2) + 
          ", H: " + DoubleToString(data.high, 2) + 
          ", L: " + DoubleToString(data.low, 2) + 
          ", C: " + DoubleToString(data.close, 2) + 
          ", V: " + DoubleToString(data.volume, 2));
           
    // You can store the data in an array, draw on charts, etc.
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("Initializing TradingView client");
    
    // Create TradingView WebSocket client
    // For TradingView's WebSocket server, use "wss://data.tradingview.com/socket.io/websocket"
    client = new TVWebSocketClient("wss://data.tradingview.com/socket.io/websocket?type=chart");
    
    // Connect to TradingView WebSocket server
    if(!client.connect())
    {
        Print("Failed to connect to TradingView WebSocket server");
        delete client;
        client = NULL;
        return INIT_FAILED;
    }
    
    // Create a chart session
    session = client.createChartSession();
    
    // Set the price update callback
    session.setUpdateCallback(OnPriceUpdate);
    
    // Initialize the chart session
    if(!session.initialize())
    {
        Print("Failed to initialize chart session");
        delete client;
        client = NULL;
        return INIT_FAILED;
    }
    
    // Resolve a symbol (e.g., BINANCE:BTCUSDT)
    if(!session.resolveSymbol("BINANCE:BTCUSDT"))
    {
        Print("Failed to resolve symbol");
        delete client;
        client = NULL;
        return INIT_FAILED;
    }
    
    // Create a price series (15-minute timeframe)
    if(!session.createSeries("15"))
    {
        Print("Failed to create series");
        delete client;
        client = NULL;
        return INIT_FAILED;
    }
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clean up
    if(client != NULL)
    {
        client.close();
        delete client;
        client = NULL;
        session = NULL; // Session is managed by client
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Process WebSocket messages
    if(client != NULL && client.isConnected())
    {
        client.processMessages();
        
        // If you want to check specific conditions based on received data:
        if(session != NULL && session.isLoaded())
        {
            OHLCV lastData = session.getLastData();
            SymbolInfo info = session.getSymbolInfo();
            
            // Example: Print the last price every minute
            static datetime lastTime = 0;
            datetime currentTime = TimeCurrent();
            
            if(currentTime - lastTime >= 60)
            {
                Print("Latest " + info.symbol_name + " price: " + DoubleToString(lastData.close, 2));
                lastTime = currentTime;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Custom function to test different symbols                        |
//+------------------------------------------------------------------+
bool ChangeSymbol(string newSymbol)
{
    if(client == NULL || session == NULL || !client.isConnected())
        return false;
        
    // Resolve new symbol
    if(!session.resolveSymbol(newSymbol))
    {
        Print("Failed to resolve symbol: " + newSymbol);
        return false;
    }
    
    // Create a price series for the new symbol
    if(!session.createSeries("15"))
    {
        Print("Failed to create series for: " + newSymbol);
        return false;
    }
    
    return true;
}
