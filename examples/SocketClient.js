const io = require('socket.io-client');

// Connect to the socket server
const socket = io('http://localhost:3000');

// Handle connection events
socket.on('connect', () => {
  console.log('Connected to server');
});

// Handle available symbols
socket.on('available_symbols', (symbols) => {
  console.log('Available symbols:', symbols);
  
  // If symbols are available, request data for the first one as an example
  if (symbols.length > 0) {
    console.log(`Requesting data for symbol: ${symbols[0]}`);
    socket.emit('get_symbol_data', symbols[0]);
  }
});

// Handle received symbol data
socket.on('symbol_data', (response) => {
  console.log(`Received data for symbol: ${response.symbol}`);
  console.log(`Number of candles: ${response.data.periods?.length || 0}`);
  
  // Show a sample of the data
  if (response.data.periods && response.data.periods.length > 0) {
    console.log('Sample data (first candle):', response.data.periods[0]);
  }
});

// Handle errors
socket.on('error', (error) => {
  console.error('Error:', error.message);
});

// Handle disconnection
socket.on('disconnect', () => {
  console.log('Disconnected from server');
});

// Simple command line interface to request data
process.stdin.on('data', (data) => {
  const input = data.toString().trim();
  
  if (input === 'exit' || input === 'quit') {
    console.log('Exiting...');
    socket.disconnect();
    process.exit(0);
  } else {
    console.log(`Requesting data for symbol: ${input}`);
    socket.emit('get_symbol_data', input);
  }
});

console.log('Type a symbol name to request data, or "exit" to quit');
