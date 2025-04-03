const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const fs = require('fs');
const path = require('path');

// Configuration
const PORT = process.env.PORT || 3000;
const DATA_DIR = path.resolve('./crawled_data');

// Initialize Express app and HTTP server
const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*", // Allow all origins for testing
    methods: ["GET", "POST"]
  }
});

// Basic route for server status
app.get('/', (req, res) => {
  res.send('TradingView Data Socket Server is running');
});

// Get available symbols from the data directory
function getAvailableSymbols() {
  try {
    if (!fs.existsSync(DATA_DIR)) {
      return [];
    }
    
    const files = fs.readdirSync(DATA_DIR);
    return files
      .filter(file => file.endsWith('.json'))
      .map(file => path.basename(file, '.json'));
  } catch (error) {
    console.error('Error reading symbols:', error);
    return [];
  }
}

// Get data for a specific symbol
function getSymbolData(symbol) {
  try {
    const filePath = path.join(DATA_DIR, `${symbol}.json`);
    
    if (!fs.existsSync(filePath)) {
      return null;
    }
    
    const data = fs.readFileSync(filePath, 'utf8');
    return JSON.parse(data);
  } catch (error) {
    console.error(`Error reading data for symbol ${symbol}:`, error);
    return null;
  }
}

// Generate a new mock candle for testing real-time updates
function generateMockCandle(symbol, lastCandle) {
  // If we don't have a last candle, create a default one
  if (!lastCandle) {
    const now = Math.floor(Date.now() / 1000);
    return {
      time: now,
      open: 100,
      high: 105,
      low: 95,
      close: 102,
      volume: Math.floor(Math.random() * 1000)
    };
  }

  // Otherwise, create a candle based on the previous one
  const timeIncrement = 60; // 1 minute
  const priceChange = (Math.random() - 0.5) * 5; // Random price movement
  const newClose = lastCandle.close + priceChange;
  const newHigh = Math.max(lastCandle.open, newClose, lastCandle.high);
  const newLow = Math.min(lastCandle.open, newClose, lastCandle.low);

  return {
    time: lastCandle.time + timeIncrement,
    open: lastCandle.close,
    high: newHigh,
    low: newLow,
    close: newClose,
    volume: Math.floor(Math.random() * 1000)
  };
}

// Active subscriptions
const activeSubscriptions = new Map();

// Socket.IO connection handling
io.on('connection', (socket) => {
  console.log(`[${new Date().toISOString()}] Client connected: ${socket.id}`);
  console.log(`[${new Date().toISOString()}] Total clients connected: ${io.engine.clientsCount}`);
  
  // Send list of available symbols to the newly connected client
  const symbols = getAvailableSymbols();
  socket.emit('available_symbols', symbols);
  console.log(`[${new Date().toISOString()}] Sent ${symbols.length} symbols to client ${socket.id}`);
  
  // Handle request for data by symbol
  socket.on('get_symbol_data', (symbol) => {
    console.log(`[${new Date().toISOString()}] Client ${socket.id} requested data for symbol: ${symbol}`);
    
    let data = getSymbolData(symbol);
    
    // If no data file exists, create mock data
    if (!data) {
      data = { periods: [] };
      
      // Generate 100 candles of mock data
      const now = Math.floor(Date.now() / 1000);
      let lastCandle = null;
      
      for (let i = 0; i < 100; i++) {
        lastCandle = generateMockCandle(symbol, lastCandle);
        data.periods.unshift({...lastCandle}); // Add to the beginning
      }
      
      console.log(`[${new Date().toISOString()}] Generated mock data for symbol ${symbol}`);
    }
    
    // Track this subscription
    if (!activeSubscriptions.has(symbol)) {
      activeSubscriptions.set(symbol, { data, sockets: new Set() });
    }
    activeSubscriptions.get(symbol).sockets.add(socket.id);
    
    socket.emit('symbol_data', { symbol, data });
    console.log(`[${new Date().toISOString()}] Sent data for symbol ${symbol} to client ${socket.id}`);
  });
  
  // Handle client disconnection
  socket.on('disconnect', () => {
    console.log(`[${new Date().toISOString()}] Client disconnected: ${socket.id}`);
    console.log(`[${new Date().toISOString()}] Total clients connected: ${io.engine.clientsCount}`);
    
    // Remove socket from all subscriptions
    activeSubscriptions.forEach((sub, symbol) => {
      sub.sockets.delete(socket.id);
      // Remove the subscription entirely if no sockets left
      if (sub.sockets.size === 0) {
        activeSubscriptions.delete(symbol);
      }
    });
  });
});

// Update all active subscriptions with new data every second
setInterval(() => {
  activeSubscriptions.forEach((sub, symbol) => {
    if (sub.sockets.size > 0) {
      const lastCandle = sub.data.periods[sub.data.periods.length - 1];
      const newCandle = generateMockCandle(symbol, lastCandle);
      
      // Add the new candle
      sub.data.periods.push(newCandle);
      
      // Keep only the last 500 candles
      if (sub.data.periods.length > 500) {
        sub.data.periods.shift();
      }
      
      // Send updated data to all subscribed clients
      sub.sockets.forEach(socketId => {
        const socket = io.sockets.sockets.get(socketId);
        if (socket) {
          socket.emit('symbol_data', { 
            symbol, 
            data: { periods: [newCandle] } // Send only the newest candle for efficiency
          });
        }
      });
      
      console.log(`[${new Date().toISOString()}] Updated ${sub.sockets.size} clients with new data for ${symbol}`);
    }
  });
}, 1000); // Update every second

// Start the server
server.listen(PORT, () => {
  console.log(`[${new Date().toISOString()}] ===================================`);
  console.log(`[${new Date().toISOString()}] TradingView Data Socket Server STARTED`);
  console.log(`[${new Date().toISOString()}] Server running on port: ${PORT}`);
  console.log(`[${new Date().toISOString()}] Data directory: ${DATA_DIR}`);
  console.log(`[${new Date().toISOString()}] Available symbols: ${getAvailableSymbols().join(', ')}`);
  console.log(`[${new Date().toISOString()}] Node.js version: ${process.version}`);
  console.log(`[${new Date().toISOString()}] Memory usage: ${JSON.stringify(process.memoryUsage())}`);
  console.log(`[${new Date().toISOString()}] ===================================`);
  
  // Setup periodic health check logging
  setInterval(() => {
    console.log(`[${new Date().toISOString()}] SERVER HEALTH CHECK:`);
    console.log(`[${new Date().toISOString()}] Server uptime: ${process.uptime()} seconds`);
    console.log(`[${new Date().toISOString()}] Connected clients: ${io.engine.clientsCount}`);
    console.log(`[${new Date().toISOString()}] Memory usage: ${JSON.stringify(process.memoryUsage())}`);
  }, 60000); // Log every minute
});

// Add error handling for server
server.on('error', (error) => {
  console.error(`[${new Date().toISOString()}] SERVER ERROR: ${error.message}`);
  console.error(error.stack);
});

// Graceful shutdown handling
process.on('SIGINT', () => {
  console.log(`[${new Date().toISOString()}] Server shutdown initiated...`);
  server.close(() => {
    console.log(`[${new Date().toISOString()}] Server gracefully shut down.`);
    process.exit(0);
  });
});
