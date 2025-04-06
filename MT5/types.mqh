/**
 * Market symbol type (like: 'BTCEUR' or 'KRAKEN:BTCEUR')
 * Used to identify trading symbols in TradingView
 */
 
/**
 * Timezone enumeration for TradingView charts
 * Valid values: 'Etc/UTC', 'exchange', 'Pacific/Honolulu', 'America/Juneau', 'America/Los_Angeles',
 * 'America/Phoenix', 'America/Vancouver', 'US/Mountain', 'America/El_Salvador', 'America/Bogota',
 * 'America/Chicago', 'America/Lima', 'America/Mexico_City', 'America/Caracas', 'America/New_York',
 * 'America/Toronto', 'America/Argentina/Buenos_Aires', 'America/Santiago', 'America/Sao_Paulo',
 * 'Atlantic/Reykjavik', 'Europe/Dublin', 'Africa/Lagos', 'Europe/Lisbon', 'Europe/London',
 * 'Europe/Amsterdam', 'Europe/Belgrade', 'Europe/Berlin', 'Europe/Brussels', 'Europe/Copenhagen',
 * 'Africa/Johannesburg', 'Africa/Cairo', 'Europe/Luxembourg', 'Europe/Madrid', 'Europe/Malta',
 * 'Europe/Oslo', 'Europe/Paris', 'Europe/Rome', 'Europe/Stockholm', 'Europe/Warsaw', 'Europe/Zurich',
 * 'Europe/Athens', 'Asia/Bahrain', 'Europe/Helsinki', 'Europe/Istanbul', 'Asia/Jerusalem', 'Asia/Kuwait',
 * 'Europe/Moscow', 'Asia/Qatar', 'Europe/Riga', 'Asia/Riyadh', 'Europe/Tallinn', 'Europe/Vilnius',
 * 'Asia/Tehran', 'Asia/Dubai', 'Asia/Muscat', 'Asia/Ashkhabad', 'Asia/Kolkata', 'Asia/Almaty',
 * 'Asia/Bangkok', 'Asia/Jakarta', 'Asia/Ho_Chi_Minh', 'Asia/Chongqing', 'Asia/Hong_Kong',
 * 'Australia/Perth', 'Asia/Shanghai', 'Asia/Singapore', 'Asia/Taipei', 'Asia/Seoul', 'Asia/Tokyo',
 * 'Australia/Brisbane', 'Australia/Adelaide', 'Australia/Sydney', 'Pacific/Norfolk',
 * 'Pacific/Auckland', 'Pacific/Fakaofo', 'Pacific/Chatham'
 */

/**
 * TimeFrame enumeration for TradingView charts
 */
enum ENUM_TV_TIMEFRAME {
    TIMEFRAME_1,     // 1 minute
    TIMEFRAME_3,     // 3 minutes
    TIMEFRAME_5,     // 5 minutes
    TIMEFRAME_15,    // 15 minutes
    TIMEFRAME_30,    // 30 minutes
    TIMEFRAME_45,    // 45 minutes
    TIMEFRAME_60,    // 60 minutes (1 hour)
    TIMEFRAME_120,   // 120 minutes (2 hours)
    TIMEFRAME_180,   // 180 minutes (3 hours)
    TIMEFRAME_240,   // 240 minutes (4 hours)
    TIMEFRAME_1D,    // 1 day
    TIMEFRAME_1W,    // 1 week
    TIMEFRAME_1M     // 1 month
 };