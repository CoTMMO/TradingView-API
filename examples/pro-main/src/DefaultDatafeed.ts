/**
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at

 * http://www.apache.org/licenses/LICENSE-2.0

 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { KLineData } from 'klinecharts'
import { io, Socket } from 'socket.io-client'

import { Datafeed, SymbolInfo, Period, DatafeedSubscribeCallback } from './types'

export default class DefaultDatafeed implements Datafeed {
  constructor (serverUrl: string = 'http://localhost:3000') {
    this._serverUrl = serverUrl
    this._socket = io(serverUrl)
    
    // Setup socket event handlers
    this._socket.on('connect', () => {
      console.log('Connected to DataSocketServer')
    })
    
    this._socket.on('disconnect', () => {
      console.log('Disconnected from DataSocketServer')
    })
    
    this._socket.on('error', (error) => {
      console.error('Socket error:', error.message)
    })
    
    // Initialize available symbols
    this._socket.on('available_symbols', (symbols) => {
      this._availableSymbols = symbols.map((symbol: string) => ({
        ticker: symbol,
        name: symbol,
        shortName: symbol,
        market: 'LOCAL',
        exchange: 'LOCAL',
        priceCurrency: 'USD',
        type: 'crypto',  // Default type
        logo: ''  // No logo by default
      }))
      console.log('Available symbols updated:', this._availableSymbols.length)
    })
    
    // Storage for callbacks by symbol
    this._callbacks = new Map()
    
    // Handle symbol data events
    this._socket.on('symbol_data', (response) => {
      const callback = this._callbacks.get(response.symbol)
      if (callback && response.data && response.data.periods && response.data.periods.length > 0) {
        // Process each candle and send to the callback
        response.data.periods.forEach((candle: any) => {
          callback({
            timestamp: candle.time * 1000, // Convert to milliseconds if needed
            open: candle.open,
            high: candle.high,
            low: candle.low,
            close: candle.close,
            volume: candle.volume || 0,
            turnover: candle.volume || 0  // Using volume as turnover if not available
          })
        })
      }
    })
  }

  private _serverUrl: string
  private _socket: Socket
  private _availableSymbols: SymbolInfo[] = []
  private _callbacks: Map<string, DatafeedSubscribeCallback>

  async searchSymbols (search?: string): Promise<SymbolInfo[]> {
    // If we don't have symbols yet, wait for them
    if (this._availableSymbols.length === 0) {
      return new Promise((resolve) => {
        this._socket.once('available_symbols', (symbols) => {
          this._availableSymbols = symbols.map((symbol: string) => ({
            ticker: symbol,
            name: symbol,
            shortName: symbol,
            market: 'LOCAL',
            exchange: 'LOCAL',
            priceCurrency: 'USD',
            type: 'crypto',
            logo: ''
          }))
          
          resolve(this._filterSymbols(search))
        })
      })
    }
    
    // We already have symbols, filter and return them
    return Promise.resolve(this._filterSymbols(search))
  }

  private _filterSymbols(search?: string): SymbolInfo[] {
    if (!search) {
      return this._availableSymbols
    }
    
    const searchLower = search.toLowerCase()
    return this._availableSymbols.filter(symbol => 
      symbol.ticker.toLowerCase().includes(searchLower) || 
      (symbol.name?.toLowerCase().includes(searchLower) ?? false)
    )
  }

  async getHistoryKLineData (symbol: SymbolInfo, period: Period, from: number, to: number): Promise<KLineData[]> {
    console.log(`Requesting historical data for ${symbol.ticker}, period: ${period}, from: ${new Date(from).toISOString()}, to: ${new Date(to).toISOString()}`)
    
    return new Promise((resolve) => {
      // Request data for the specific symbol
      this._socket.emit('get_symbol_data', symbol.ticker)
      
      // Setup a one-time listener for the response
      this._socket.once('symbol_data', (response) => {
        console.log(`Received data for ${symbol.ticker}:`, response)
        
        if (response.symbol !== symbol.ticker || !response.data || !response.data.periods) {
          console.warn(`Invalid or empty data received for ${symbol.ticker}`)
          resolve([])
          return
        }
        
        // Convert the data to KLineData format
        const klineData = response.data.periods.map((candle: any) => ({
          timestamp: candle.time * 1000, // Convert to milliseconds if needed
          open: candle.open,
          high: candle.high,
          low: candle.low,
          close: candle.close,
          volume: candle.volume || 0,
          turnover: candle.volume || 0  // Using volume as turnover if not available
        }))
        
        // Filter by time range if necessary
        const filteredData = klineData.filter(
          (candle: KLineData) => candle.timestamp >= from && candle.timestamp <= to
        )
        
        console.log(`Returning ${filteredData.length} candles for ${symbol.ticker}`)
        resolve(filteredData)
      })
      
      // Handle potential error
      this._socket.once('error', (error) => {
        console.error(`Error getting data for ${symbol.ticker}:`, error)
        resolve([])
      })
    })
  }

  subscribe (symbol: SymbolInfo, period: Period, callback: DatafeedSubscribeCallback): void {
    // Store the callback for this symbol
    this._callbacks.set(symbol.ticker, callback)
    
    // Request data for this symbol
    this._socket.emit('get_symbol_data', symbol.ticker)
    
    console.log(`Subscribed to ${symbol.ticker}`)
  }

  unsubscribe(symbol: SymbolInfo, period: Period): void {
    // Remove the callback for this symbol
    this._callbacks.delete(symbol.ticker)
    console.log(`Unsubscribed from ${symbol.ticker}`)
  }
}