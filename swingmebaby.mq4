
//+------------------------------------------------------------------+
//|                                           SwingMasterPro.mq4     |
//|                  Professional Swing Trading Signal System        |
//|                    (c) 2026 - Multi-Timeframe Analysis           |
//+------------------------------------------------------------------+
//| MAINTAINABILITY NOTE:                                            |
//| This file is 3400+ lines. For easier maintenance, consider       |
//| splitting into include files:                                    |
//|   - SwingTelegram.mqh  (Telegram send, config, HTML helpers)     |
//|   - SwingPanel.mqh     (Chart panel UI, labels, buttons)         |
//|   - SwingBias.mqh      (Currency strength, bias classification)  |
//|   - SwingOrders.mqh    (Pending orders, trailing, risk mgmt)     |
//|   - SwingNews.mqh      (News filter, live feed, fallback)        |
//| Place .mqh files in MQL4/Include/ and use #include directives.   |
//+------------------------------------------------------------------+
#property copyright "SwingMaster Pro v2.0"
#property link      "https://t.me/SwingMasterPro"
#property version   "2.0"
#property strict

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input double LotSize           = 0.03;    // Fixed lot size for pending orders
input bool   EnableAutoTrading = true;    // Allow auto trading (true para bukas ang auto-trade)
input bool   ManualModeOnly    = false;   // false = auto mode, true = alerts only

// Telegram Settings (LOAD FROM EXTERNAL FILE FOR SECURITY)
input string   TG_CONFIG_FILE     = "SwingBias_Config.txt";  // Config file in MQL4/Files/
// SECURITY: do not ship secrets in source; require external config
string   TG_BOT_TOKEN       = "";  // Loaded from config
string   TG_CHAT_ID         = "";  // Loaded from config
input int MagicNumber = 20260215; // Unique magic number for this EA

// Risk Management
input double   MaxDailyRiskPercent = 5.0;      // Max daily risk %
input double   MaxDrawdownPercent  = 5.0;      // Max drawdown % (stop trading)
input double   DrawdownWarning     = 3.0;      // Drawdown warning %

// Trade Filters
input double   MaxSpreadPips      = 3.2;       // Max spread allowed (pips)
input int      ATRPeriod          = 14;        // ATR period
input double   PendingStaleMaxPips = 80.0;     // Strict cancel if stale pending is too far [Swing: 80]

// Session Filter
input bool     UseLondonSession   = true;      // Trade London session
input bool     UseNYSession       = true;      // Trade NY session
input int      LondonStartHour    = 8;         // London start (GMT)
input int      LondonEndHour      = 16;        // London end (GMT)
input int      NYStartHour        = 13;        // NY start (GMT)
input int      NYEndHour          = 21;        // NY end (GMT)

// Signal Quality Settings
input int      RSI_Period         = 14;        // RSI period
input int      RSI_BuyZoneLow     = 35;        // RSI buy zone low [Swing: 35-55]
input int      RSI_BuyZoneHigh    = 55;        // RSI buy zone high [Swing: 35-55]
input int      RSI_SellZoneLow    = 45;        // RSI sell zone low [Swing: 45-65]
input int      RSI_SellZoneHigh   = 65;        // RSI sell zone high [Swing: 45-65]
input double   EMA_PullbackATR    = 0.5;       // Price within X ATR of EMA

// Trailing Stop Alert Settings
input double   TrailingTriggerPips = 30.0;     // Alert when profit >= this (pips) [Default fallback when no SL]
input double   BreakEvenBufferPips = 15.0;     // Suggested SL buffer beyond entry (pips) [Swing: 15-20]
input bool     UseATRTrailSuggestion = true;   // Use ATR-based trailing suggestion
input double   ATRTrailMult       = 1.5;       // ATR multiplier for trailing suggestion [Swing: 1.5]
input double   ATRTrailMultTight  = 1.0;   // Stage 4: tighter ATR multiplier at 3× SL dist (locks more profit)
input double   TrailStage2Mult    = 1.5;   // Stage 2 trail trigger: X × initial SL distance (default 1.5)
input double   TrailStage2LockPct = 30.0;  // Stage 2: lock X% of current profit as SL buffer (default 30%)
input double   PartialCloseAtPips = 0.0;       // Suggest partial close when profit >= this (0=off)
input double   PartialClosePct    = 50.0;      // Suggested partial close % at TP1 [Swing: 50%]
input bool     AutoPartialClose   = true;      // Auto partial close at trigger (requires auto mode)

// Pair Filtering
input double   MaxSpreadMultiplier = 2.5;      // Max spread vs average spread
input bool     NewsFilterEnabled  = true;      // Enable news time blocking
input bool     UseLiveNewsFeed    = true;      // Use live news feed (JSON endpoint)
input string   NewsApiUrl         = "https://nfs.faireconomy.media/ff_calendar_thisweek.json";        // Live news endpoint URL
input string   NewsApiKey         = "";        // Optional API key/token
input int      NewsFetchMinutes   = 30;        // Refresh interval
input int      NewsBlockBeforeMins = 30;       // Block X minutes before event
input int      NewsBlockAfterMins  = 30;       // Block X minutes after event
input int      NewsLookaheadHours  = 48;       // Cache events ahead
input int      NewsMinImpact       = 3;        // Minimum impact (1=low,2=med,3=high)

// Display & Debug
input bool     ShowChartPanel     = true;      // Show info panel on chart
input bool     DEBUG_PRINT        = true;      // Print debug logs
input color    PanelColor         = clrDarkSlateGray;
input color    TextColor          = clrWhite;
input bool     ShowAlertBadge     = true;      // Show alert badge on chart
input int      AlertBadgeMinutes  = 15;        // How long to keep badge (minutes)
input color    AlertBadgeColor    = clrGold;
input bool     QuietFilterLogs    = true;      // Reduce repeated spread/filter logs
input int      FilterLogCooldownMins = 15;     // Cooldown for repeated filter logs per symbol
input int      PanelRefreshSeconds = 2;        // UI refresh throttle (seconds)
input bool     VerboseTelegramLogs = false;    // Log Telegram success payloads/details
input int      LogVerbosity = 1;               // 0=Errors only, 1=Warnings+Errors, 2=All logs
input int      TelegramMinSendIntervalSec = 1; // Min seconds between Telegram sends (throttle)
input int      TelegramParseErrorCooldownSec = 300; // Force plain text for X sec after HTML parse error

// Safety: manual trading only (prevents any future accidental OrderSend/OrderModify usage)
input int  AutoMagicNumber = 20260216; // Magic number for EA-managed actions (must differ from MagicNumber)
input int  AutoSlippagePips = 3;       // Slippage (pips) for EA-managed actions
input bool AutoTrailStops = true;      // Auto move SL on trailing alert (forced ON while auto trading is active)
input bool   AutoExtendTP    = false;   // Auto extend TP when price is near target
input double TPExtendNearPct = 20.0;   // Trigger extend when remaining distance to TP is <= X% of initial TP distance

input bool AutoCancelPendingOnWideSpread = false; // Auto cancel pending if spread condition fails
input bool AutoCancelPendingOnFarPrice = false; // Auto cancel pending if price too far from entry
input int  PendingHealthCheckSeconds = 30;  // Health check interval for pending orders
input bool AutoCancelPendingOnNews = false; // Auto cancel pendings during news
input bool AutoManageOnlyMagic = false;    // Auto actions only manage EA's magic orders

// Impulse Swing Pending Orders (PerfectPullback logic)
input bool   AutoPlacePending      = true;   // Auto place impulse swing pending orders for Tradeable Now pairs
input int    PendingSL_Pips        = 30;     // Stop loss (pips)
input int    PendingMinTP_Pips     = 50;     // Minimum TP (pips)
input int    PendingExpireHours    = 8;      // Pending order expiry (hours)
input int    PendingImpulseLookback = 50;    // Bars to scan for impulse move (H1)
input int    PendingMinImpulsePips  = 50;    // Min impulse size to qualify (pips)
input int    PendingSR_Lookback    = 200;    // S/R lookback bars (for TP targeting)
input int    PendingSR_Strength    = 3;      // S/R pivot strength (bars each side)
input int    PendingSR_ZonePips    = 5;      // S/R merge tolerance (pips)
input int    PendingMaxPerPair     = 1;      // Max pending orders per pair per direction
input int    PendingMaxEntryDistPips = 150;  // Max distance from current price for pending entry (pips)
input bool   PendingUseFibEntry    = true;   // Use best Fib entry: S/R confluence win, fallback deepest valid (61.8→50→38.2)
input bool   PendingRequireM15Align = false; // Block fib entry only if M15 is a hard counter (INV/neutral = allowed)

// ── Recovery Hedge System (v2.0) ─────────────────────────────────
// Opens opposite trades with TP to chip away at losses instead of full lock.
input bool   RecoveryHedgeEnabled  = true;   // Enable recovery hedge with TP
input double RecoveryTriggerPips   = 20.0;   // Open first recovery hedge when original loses X pips (check bias at -20p, before 30p SL hit)
input double RecoverySpacingPips   = 30.0;   // Open next recovery hedge every X additional pips of loss
input int    RecoveryMinTP_Pips    = 15;     // Minimum TP for recovery hedge (pips)
input string RecoveryComment       = "SMP_Recovery"; // Comment tag for recovery hedge orders

// ── Bias Tuning Parameters (v2.0) ────────────────────────────────
input double TrendGapThreshold     = 0.15;   // ATR gap ratio threshold (0.1=lenient, 0.25=strict)
input bool   UseDoubleBarSlope     = true;   // Require 2-bar EMA slope confirmation (more stable)
input double D1_Weight             = 1.5;    // D1 score multiplier in bias classification
input int    BiasStrongThreshold   = 5;      // Minimum abs score for STRONG label (4-6)
input bool   BiasRSIFilter         = false;  // Downgrade STRONG to INV if RSI overbought/oversold
input double BiasRSI_OB            = 70.0;   // RSI overbought level (STRONG BUY -> INV)
input double BiasRSI_OS            = 30.0;   // RSI oversold level (STRONG SELL -> INV)

bool AutoTradingEnabled() {
   return (!ManualModeOnly && EnableAutoTrading);
}

bool AutoTradingActive() {
   if(!AutoTradingEnabled()) return false;
   datetime now = TimeCurrent();
   if(g_autoTradingCacheValid && g_autoTradingCacheAt == now) return g_autoTradingCacheVal;

   g_autoTradingCacheVal = IsTradeAllowed();
   g_autoTradingCacheAt = now;
   g_autoTradingCacheValid = true;
   return g_autoTradingCacheVal;
}

string GetAutoOffReason() {
   if(ManualModeOnly) return "ManualModeOnly=true";
   if(!EnableAutoTrading) return "EnableAutoTrading=false";
   if(!IsExpertEnabled()) return "AutoTrading button OFF";
   if(!IsConnected()) return "No server connection";
   if(IsTradeContextBusy()) return "Trade context busy";
   if(!IsTradeAllowed()) return "Trade not allowed (terminal/EA)";
   return "Unknown";
}

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
string Currencies[7] = {"AUD","CAD","EUR","GBP","JPY","NZD","USD"};
string MajorPairs[21] = {"EURUSD","GBPUSD","USDJPY","AUDUSD","USDCAD","NZDUSD",
                         "EURJPY","GBPJPY","EURGBP","AUDJPY","EURAUD","AUDNZD",
                         "NZDJPY","GBPAUD","GBPCAD","EURNZD","AUDCAD",
                         "EURCAD","CADJPY","GBPNZD","NZDCAD"};
string Pairs[64];
int    PairsCount = 0;
double AvgSpreads[64];  // Track average spread for each pair

// Per-pair indicator cache — updated once per tick, reused by panel/alerts/orders
struct PairCache {
   double h1_ema20;
   double h1_ema50;
   double h1_atr;
   double h1_close;
   double h1_rsi1;
   double h1_rsi2;
   double m15_ema20;
   double m15_atr;
   double m15_close;
   double m15_rsi1;
   double m15_rsi2;
};
PairCache g_cache[64];
datetime  g_cacheUpdatedAt = 0;

// TF sign trend cache: g_tfSign[pairIndex][tfIdx]
// tfIdx: 0=D1, 1=H4, 2=H1, 3=M30, 4=M15
// Computed once per tick in UpdatePairCache — guarantees consistent bias across all reads.
int g_tfSign[64][5];

// TF index mapping for g_tfSign cache
int TFIdx(int tf) {
   switch(tf) {
      case PERIOD_D1:  return 0;
      case PERIOD_H4:  return 1;
      case PERIOD_H1:  return 2;
      case PERIOD_M30: return 3;
      case PERIOD_M15: return 4;
   }
   return -1;
}

void UpdatePairCache() {
   datetime now = TimeCurrent();
   if(g_cacheUpdatedAt == now) return; // already updated this tick
   g_cacheUpdatedAt = now;
   int tfs[5] = {PERIOD_D1, PERIOD_H4, PERIOD_H1, PERIOD_M30, PERIOD_M15};
   for(int i = 0; i < PairsCount; i++) {
      string sym = Pairs[i];
      // TF sign trends (5 TFs) — cached for CurrencyScoreInt/CurrencyScoreDetail
      for(int t = 0; t < 5; t++)
         g_tfSign[i][t] = GetTFSignTrend(sym, tfs[t]);
      // H1 + M15 indicator cache for panel/alerts/orders
      g_cache[i].h1_ema20  = iMA(sym, PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE, 1);
      g_cache[i].h1_ema50  = iMA(sym, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE, 1);
      g_cache[i].h1_atr    = iATR(sym, PERIOD_H1, ATRPeriod, 1);
      g_cache[i].h1_close  = iClose(sym, PERIOD_H1, 1);
      g_cache[i].h1_rsi1   = iRSI(sym, PERIOD_H1, RSI_Period, PRICE_CLOSE, 1);
      g_cache[i].h1_rsi2   = iRSI(sym, PERIOD_H1, RSI_Period, PRICE_CLOSE, 2);
      g_cache[i].m15_ema20 = iMA(sym, PERIOD_M15, 20, 0, MODE_EMA, PRICE_CLOSE, 1);
      g_cache[i].m15_atr   = iATR(sym, PERIOD_M15, ATRPeriod, 1);
      g_cache[i].m15_close = iClose(sym, PERIOD_M15, 1);
      g_cache[i].m15_rsi1  = iRSI(sym, PERIOD_M15, RSI_Period, PRICE_CLOSE, 1);
      g_cache[i].m15_rsi2  = iRSI(sym, PERIOD_M15, RSI_Period, PRICE_CLOSE, 2);
   }
}

datetime lastScanTime = 0;
datetime lastScorecardSend = 0;
double   dayStartBalance = 0;
datetime g_lastUIRefresh = 0;
datetime g_lastRefillCheck = 0;  // periodic pending refill (catches manual cancels mid-candle)

datetime g_spreadHighLogAt[64];
datetime g_spreadWideLogAt[64];
datetime g_autoTradingCacheAt = 0;
bool     g_autoTradingCacheVal = false;
bool     g_autoTradingCacheValid = false;

// Risk tracking
double   currentRiskAmount = 0;
double   currentRiskPercent = 0;
int      currentRiskNoSLTrades = 0;
int      currentRiskTrackedTrades = 0;

// Trade only these pairs (from MajorPairs list)
bool IsAllowedTradePair(string sym) {
   string baseSym = StringSubstr(sym, 0, 6);
   int total = ArraySize(MajorPairs);
   for(int i = 0; i < total; i++) {
      if(baseSym == MajorPairs[i]) return true;
   }
   return false;
}

// Trailing Stop tracking
datetime lastTrailingCheck = 0;

// Alert badge tracking
datetime lastAlertBadgeTime = 0;

// Expiration tracking
datetime lastPendingHealthCheck = 0;


// News events (high impact)
struct NewsEvent {
   string currency;
   string event;
   datetime time;
   int impact;  // 1=low, 2=medium, 3=high
};
NewsEvent UpcomingNews[20];
int NewsCount = 0;
datetime lastNewsCheck = 0;
datetime newsBlockUntil = 0;
string currentNewsEvent = "";  // Store current news event name
datetime lastNewsFetch = 0;
bool liveNewsLoaded = false;
string lastNewsError = "";
int lastNewsErrorCode = 0;

// Cache news state to prevent repeated side-effect calls in the same tick/scan
bool g_newsNow = false;
datetime g_newsCacheAt = 0;

bool GetNewsNowCached() {
   datetime now = TimeCurrent();
   // cache for 30 seconds
   if(g_newsCacheAt == 0 || (now - g_newsCacheAt) > 30) {
      g_newsNow = IsNewsTime();
      g_newsCacheAt = now;
   }
   return g_newsNow;
}


// ── Recovery Hedge Tracker ──────────────────────────────────────
// Tracks recovery hedge orders opened against losing original trades.
// Each record links a recovery hedge ticket to its parent (original) ticket.
struct RecoveryHedgeRecord {
   int    parentTicket;     // original losing trade ticket
   string symbol;           // pair symbol
   int    recoveryTickets[32]; // recovery hedge tickets (unlimited, practical cap 32)
   int    recoveryCount;    // how many recovery hedges opened so far
   double totalRecoveredPips;   // total pips recovered from closed recovery TPs
   double totalRecoveredProfit; // total $ recovered from closed recovery TPs
};
RecoveryHedgeRecord g_recovery[64];
int g_recoveryCount = 0;
datetime g_lastRecoveryCheck = 0;

// Get recovery record index for a parent ticket (-1 if not found)
int GetRecoveryIndex(int parentTicket) {
   for(int i = 0; i < g_recoveryCount; i++) {
      if(g_recovery[i].parentTicket == parentTicket) return i;
   }
   return -1;
}

// Get or create recovery record for a parent ticket
int GetOrCreateRecovery(int parentTicket, string sym) {
   int idx = GetRecoveryIndex(parentTicket);
   if(idx >= 0) return idx;
   if(g_recoveryCount >= 64) return -1;
   idx = g_recoveryCount;
   g_recovery[idx].parentTicket = parentTicket;
   g_recovery[idx].symbol = sym;
   g_recovery[idx].recoveryCount = 0;
   g_recovery[idx].totalRecoveredPips = 0;
   g_recovery[idx].totalRecoveredProfit = 0;
   g_recoveryCount++;
   return idx;
}

// Count how many recovery hedges are currently OPEN (not yet closed) for a parent
int CountOpenRecoveryHedges(int rIdx) {
   if(rIdx < 0 || rIdx >= g_recoveryCount) return 0;
   int openCount = 0;
   for(int i = 0; i < g_recovery[rIdx].recoveryCount; i++) {
      int tk = g_recovery[rIdx].recoveryTickets[i];
      if(tk > 0 && OrderSelect(tk, SELECT_BY_TICKET, MODE_TRADES) && OrderCloseTime() == 0)
         openCount++;
   }
   return openCount;
}

// Rebuild g_recovery[] from existing open orders on EA init/re-attach.
// Scans all open trades for recovery hedge comments ("SMP_Recovery_<parentTicket>")
// and reconstructs the tracking array so the EA knows what already exists.
void RebuildRecoveryState() {
   g_recoveryCount = 0;
   int totalOrders = OrdersTotal();
   for(int i = 0; i < totalOrders; i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderCloseTime() > 0) continue;
      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;

      string comment = OrderComment();
      // Recovery hedge comments: "SMP_Recovery_<parentTicket>"
      if(StringFind(comment, RecoveryComment + "_") < 0) continue;

      // Extract parent ticket from comment
      int underscorePos = StringFind(comment, "_", StringLen(RecoveryComment) + 1);
      if(underscorePos < 0) underscorePos = StringLen(comment);
      string parentStr = StringSubstr(comment, StringLen(RecoveryComment) + 1,
                                      underscorePos - StringLen(RecoveryComment) - 1);
      int parentTicket = (int)StringToInteger(parentStr);
      if(parentTicket <= 0) continue;

      string sym = OrderSymbol();
      int recoveryTicket = OrderTicket();

      // Get or create recovery record for this parent
      int rIdx = GetOrCreateRecovery(parentTicket, sym);
      if(rIdx < 0) continue;
      if(g_recovery[rIdx].recoveryCount >= 32) continue;

      // Add this recovery ticket to the record
      g_recovery[rIdx].recoveryTickets[g_recovery[rIdx].recoveryCount] = recoveryTicket;
      g_recovery[rIdx].recoveryCount++;
   }

   // Also scan order history for recently closed recovery hedges (tally recovered P/L)
   int totalHistory = OrdersHistoryTotal();
   for(int i = 0; i < totalHistory; i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderCloseTime() == 0) continue;
      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;

      string comment = OrderComment();
      if(StringFind(comment, RecoveryComment + "_") < 0) continue;

      string parentStr = StringSubstr(comment, StringLen(RecoveryComment) + 1);
      int parentTicket = (int)StringToInteger(parentStr);
      if(parentTicket <= 0) continue;

      // Only tally if parent is still tracked (has open recovery hedges or parent still open)
      string histSym = OrderSymbol();
      int rIdx = GetRecoveryIndex(parentTicket);
      if(rIdx < 0) {
         // Parent not yet tracked — check if parent is still open (create record for spacing)
         if(OrderSelect(parentTicket, SELECT_BY_TICKET, MODE_TRADES) && OrderCloseTime() == 0) {
            rIdx = GetOrCreateRecovery(parentTicket, histSym);
         }
         if(rIdx < 0) continue;
      }

      // Re-select the history order — cursor may have changed to parent during check above
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;

      // Count this closed hedge toward recoveryCount (for correct spacing via GetDeepestRecoveryLevel)
      // Add as tallied slot (ticket = 0) so spacing accounts for past hedges
      if(g_recovery[rIdx].recoveryCount < 32) {
         g_recovery[rIdx].recoveryTickets[g_recovery[rIdx].recoveryCount] = 0; // 0 = already tallied
         g_recovery[rIdx].recoveryCount++;
      }

      // Tally recovered P/L from this closed recovery hedge
      double rProfit = OrderProfit() + OrderSwap() + OrderCommission();
      double rPipVal = PipValue(histSym);
      double rPips = 0;
      if(rPipVal > 0) {
         rPips = (type == OP_BUY) ? (OrderClosePrice() - OrderOpenPrice()) / rPipVal
                                   : (OrderOpenPrice() - OrderClosePrice()) / rPipVal;
      }
      g_recovery[rIdx].totalRecoveredPips += rPips;
      g_recovery[rIdx].totalRecoveredProfit += rProfit;
   }

   if(g_recoveryCount > 0) {
      Log("[INIT] Rebuilt " + IntegerToString(g_recoveryCount) + " recovery hedge record(s) from existing orders");
      for(int i = 0; i < g_recoveryCount; i++) {
         Log("  [REC#" + IntegerToString(i) + "] Parent #" + IntegerToString(g_recovery[i].parentTicket) +
             " " + g_recovery[i].symbol + " | Open hedges: " + IntegerToString(CountOpenRecoveryHedges(i)) +
             " / Total: " + IntegerToString(g_recovery[i].recoveryCount) +
             " | Recovered: " + DoubleToStrClean(g_recovery[i].totalRecoveredPips, 1) + "p");
      }
   }
}

// Get the deepest recovery level (how many pips from entry the last recovery was opened)
double GetDeepestRecoveryLevel(int rIdx) {
   // Returns the loss threshold at which the NEXT recovery should trigger
   // E.g., if 2 hedges opened: trigger + spacing*1 already used, next at trigger + spacing*2
   if(rIdx < 0) return RecoveryTriggerPips;
   return RecoveryTriggerPips + RecoverySpacingPips * g_recovery[rIdx].recoveryCount;
}

// Clean up recovery records for parent tickets that are closed.
// IMPORTANT: Do NOT close orphan recovery hedges — they survive as standalone trades
// and can become parents for their own recovery hedges (recursive recovery).
void CleanRecoveryHedges() {
   for(int i = g_recoveryCount - 1; i >= 0; i--) {
      int ptk = g_recovery[i].parentTicket;
      bool parentClosed = false;
      if(!OrderSelect(ptk, SELECT_BY_TICKET, MODE_TRADES))
         parentClosed = true;
      else if(OrderCloseTime() > 0)
         parentClosed = true;

      // Also clean if ALL recovery hedges are closed/tallied AND parent is closed
      bool allRecoveryClosed = true;
      if(!parentClosed) {
         // Parent still open — check if all recovery hedges are done (tallied = 0)
         allRecoveryClosed = true;
         for(int j = 0; j < g_recovery[i].recoveryCount; j++) {
            int rtk = g_recovery[i].recoveryTickets[j];
            if(rtk > 0) { allRecoveryClosed = false; break; }
         }
         if(allRecoveryClosed && g_recovery[i].recoveryCount > 0) {
            // All recovery hedges TP'd/closed but parent still open — keep record for display
            // (shows total recovered in chart panel)
            continue;
         }
      }

      if(parentClosed) {
         // Parent closed — surviving recovery hedges become standalone trades.
         // Log any that are still open so user knows they're now independent.
         for(int j = 0; j < g_recovery[i].recoveryCount; j++) {
            int rtk = g_recovery[i].recoveryTickets[j];
            if(rtk > 0 && OrderSelect(rtk, SELECT_BY_TICKET, MODE_TRADES) && OrderCloseTime() == 0) {
               Log(g_recovery[i].symbol + " [RECOVERY] #" + IntegerToString(rtk) +
                   " now standalone (parent #" + IntegerToString(ptk) + " closed) — eligible for own recovery hedges");
            }
         }
         // Remove record (shift array)
         for(int j = i; j < g_recoveryCount - 1; j++)
            g_recovery[j] = g_recovery[j + 1];
         g_recoveryCount--;
      }
   }
}

string JsonGetString(string json, string key, int fromPos) {
   string needle = "\"" + key + "\"";
   int k = StringFind(json, needle, fromPos);
   if(k < 0) return "";
   int c = StringFind(json, ":", k);
   if(c < 0) return "";
   int q1 = StringFind(json, "\"", c + 1);
   if(q1 < 0) return "";
   int q2 = StringFind(json, "\"", q1 + 1);
   if(q2 < 0) return "";
   return StringSubstr(json, q1 + 1, q2 - q1 - 1);
}

int JsonGetInt(string json, string key, int fromPos, int defaultVal) {
   string needle = "\"" + key + "\"";
   int k = StringFind(json, needle, fromPos);
   if(k < 0) return defaultVal;
   int c = StringFind(json, ":", k);
   if(c < 0) return defaultVal;
   int p = c + 1;
   while(p < StringLen(json)) {
      int ch = StringGetCharacter(json, p);
      if((ch >= '0' && ch <= '9') || ch == '-') break;
      p++;
   }
   int e = p;
   while(e < StringLen(json)) {
      int ch2 = StringGetCharacter(json, e);
      if(!(ch2 >= '0' && ch2 <= '9')) break;
      e++;
   }
   if(e <= p) return defaultVal;
   return (int)StringToInteger(StringSubstr(json, p, e - p));
}

datetime ParseIsoUtcToServer(string iso) {
   if(StringLen(iso) < 16) return 0;
   string y = StringSubstr(iso, 0, 4);
   string m = StringSubstr(iso, 5, 2);
   string d = StringSubstr(iso, 8, 2);
   string hh = StringSubstr(iso, 11, 2);
   string mm = StringSubstr(iso, 14, 2);
   string dt = y + "." + m + "." + d + " " + hh + ":" + mm;
   datetime t = StringToTime(dt);
   if(t <= 0) return 0;
   int offset = (int)(TimeCurrent() - TimeGMT());
   return t + offset;
}

datetime ParseIsoWithOffsetToServer(string iso) {
   if(StringLen(iso) < 19) return 0;
   string y = StringSubstr(iso, 0, 4);
   string m = StringSubstr(iso, 5, 2);
   string d = StringSubstr(iso, 8, 2);
   string hh = StringSubstr(iso, 11, 2);
   string mm = StringSubstr(iso, 14, 2);
   string ss = StringSubstr(iso, 17, 2);

   string dt = y + "." + m + "." + d + " " + hh + ":" + mm + ":" + ss;
   datetime localT = StringToTime(dt);
   if(localT <= 0) return 0;

   int len = StringLen(iso);
   int offsetSignPos = len - 6;
   int offsetMinutes = 0;
   if(offsetSignPos > 0) {
      string sign = StringSubstr(iso, offsetSignPos, 1);
      if(sign == "+" || sign == "-") {
         int offH = (int)StringToInteger(StringSubstr(iso, offsetSignPos + 1, 2));
         int offM = (int)StringToInteger(StringSubstr(iso, offsetSignPos + 4, 2));
         offsetMinutes = offH * 60 + offM;
         if(sign == "-") offsetMinutes = -offsetMinutes;
      }
   }

   // Convert to UTC
   datetime utcT = localT - (offsetMinutes * 60);
   int serverOffset = (int)(TimeCurrent() - TimeGMT());
   return utcT + serverOffset;
}

int ImpactFromString(string s) {
   string t = s;
   StringToUpper(t);
   if(StringFind(t, "HIGH") >= 0) return 3;
   if(StringFind(t, "MED") >= 0) return 2;
   if(StringFind(t, "LOW") >= 0) return 1;
   return 0;
}

bool FetchLiveNews() {
   if(!UseLiveNewsFeed) return false;
   if(NewsApiUrl == "") return false;

   datetime now = TimeCurrent();
   if(lastNewsFetch != 0 && (now - lastNewsFetch) < (NewsFetchMinutes * 60)) return liveNewsLoaded;
   lastNewsFetch = now;

   string url = NewsApiUrl;
   if(NewsApiKey != "") {
      if(StringFind(url, "?") >= 0) url += "&key=" + NewsApiKey;
      else url += "?key=" + NewsApiKey;
   }

   char result[];
   char headers[];
   string respHeaders;
   int timeout = 5000;

   int res = WebRequest("GET", url, "", timeout, headers, result, respHeaders);
   if(res == -1) {
      int error = GetLastError();
      Log("Live news WebRequest failed: " + IntegerToString(error));
      ResetLastError();
      liveNewsLoaded = false;
      lastNewsErrorCode = error;
      lastNewsError = "WebRequest failed";
      return false;
   }

   string json = CharArrayToString(result, 0, -1);
   if(StringLen(json) < 5) {
      liveNewsLoaded = false;
      lastNewsErrorCode = 0;
      lastNewsError = "Empty response";
      return false;
   }

   // Parse events
   NewsCount = 0;
   int pos = 0;
   datetime nowG = TimeCurrent();
   datetime maxTime = nowG + (NewsLookaheadHours * 3600);

   bool hasEventsWrapper = (StringFind(json, "\"events\"") >= 0);

   if(hasEventsWrapper) {
      while(NewsCount < 20) {
         int tpos = StringFind(json, "\"time\"", pos);
         if(tpos < 0) break;

         string timeStr = JsonGetString(json, "time", tpos);
         string curStr = JsonGetString(json, "currency", tpos);
         string titleStr = JsonGetString(json, "title", tpos);
         int impact = JsonGetInt(json, "impact", tpos, 0);

         datetime evt = ParseIsoUtcToServer(timeStr);
         if(evt > 0 && evt <= maxTime && impact >= NewsMinImpact && curStr != "") {
            UpcomingNews[NewsCount].currency = StringSubstr(curStr, 0, 3);
            UpcomingNews[NewsCount].event = titleStr;
            UpcomingNews[NewsCount].time = evt;
            UpcomingNews[NewsCount].impact = impact;
            NewsCount++;
         }

         pos = tpos + 6;
      }
   } else {
      // ForexFactory-style array: [{"title":"...","country":"USD","date":"...-05:00","impact":"High",...}]
      while(NewsCount < 20) {
         int dpos = StringFind(json, "\"date\"", pos);
         if(dpos < 0) break;

         int objStart = -1;
         int searchPos = 0;
         while(true) {
            int p = StringFind(json, "{", searchPos);
            if(p < 0 || p >= dpos) break;
            objStart = p;
            searchPos = p + 1;
         }
         if(objStart < 0) { pos = dpos + 6; continue; }

         string dateStr = JsonGetString(json, "date", objStart);
         string curStr = JsonGetString(json, "country", objStart);
         string titleStr = JsonGetString(json, "title", objStart);
         string impactStr = JsonGetString(json, "impact", objStart);
         int impact = ImpactFromString(impactStr);

         datetime evt = ParseIsoWithOffsetToServer(dateStr);
         if(evt > 0 && evt <= maxTime && impact >= NewsMinImpact && curStr != "") {
            UpcomingNews[NewsCount].currency = StringSubstr(curStr, 0, 3);
            UpcomingNews[NewsCount].event = titleStr;
            UpcomingNews[NewsCount].time = evt;
            UpcomingNews[NewsCount].impact = impact;
            NewsCount++;
         }

         pos = dpos + 6;
      }
   }

   liveNewsLoaded = (NewsCount > 0);
   Log("Live news loaded: " + IntegerToString(NewsCount));
   if(liveNewsLoaded) {
      lastNewsError = "";
      lastNewsErrorCode = 0;
   } else {
      lastNewsError = "No events";
      lastNewsErrorCode = 0;
   }
   return liveNewsLoaded;
}

// --- Alert send state ---
datetime g_tgRateLimitUntil = 0;
datetime g_tgRateLimitLogAt = 0;
bool g_tgLastWasRateLimited = false;
bool g_tgLastBlockedByThrottle = false;
bool g_tgLastWasEmptyMsg = false;    // set when Telegram returns 400 message text is empty
datetime g_tgLastSendAt = 0;
datetime g_tgForcePlainUntil = 0;


//+------------------------------------------------------------------+
//| UTILITY FUNCTIONS                                                 |
//+------------------------------------------------------------------+
void Log(string s) { 
   if(!DEBUG_PRINT) return;

   string t = s;
   StringToUpper(t);

   int level = 2; // info
   if(StringFind(t, "ERROR") >= 0 || StringFind(t, "FAILED") >= 0) level = 0;
   else if(StringFind(t, "WARNING") >= 0 || StringFind(t, "SKIPPED") >= 0 || StringFind(t, "CAUTION") >= 0) level = 1;

   int verbosity = LogVerbosity;
   if(verbosity < 0) verbosity = 0;
   if(verbosity > 2) verbosity = 2;

   if(level <= verbosity) Print("[SwingMasterPro] " + s);
}

//+------------------------------------------------------------------+
//| LOAD TELEGRAM CONFIG FROM EXTERNAL FILE                          |
//+------------------------------------------------------------------+
bool LoadTelegramConfig() {
   string filename = TG_CONFIG_FILE;
   // Use terminal data folder: MQL4/Files (not Common Files)
   int handle = FileOpen(filename, FILE_READ|FILE_TXT);
   
   if(handle == INVALID_HANDLE) {
      Log("WARNING: Config file not found: " + filename);
      Log("Creating template config file...");
      CreateConfigTemplate();
      return false;
   }
   
   while(!FileIsEnding(handle)) {
      string line = FileReadString(handle);
      StringTrimLeft(line);
      StringTrimRight(line);
      
      // Skip empty lines and comments
      if(StringLen(line) == 0 || StringGetCharacter(line, 0) == '#') continue;
      
      // Parse KEY=VALUE format
      int sepPos = StringFind(line, "=");
      if(sepPos > 0) {
         string key = StringSubstr(line, 0, sepPos);
         string value = StringSubstr(line, sepPos + 1);
         StringTrimLeft(key);
         StringTrimRight(key);
         StringTrimLeft(value);
         StringTrimRight(value);
         
         // Remove quotes if present
         StringReplace(value, "\"", "");
         StringReplace(value, "'", "");
         
         if(key == "BOT_TOKEN") {
            TG_BOT_TOKEN = value;
            Log("Loaded BOT_TOKEN (length: " + IntegerToString(StringLen(value)) + ")");
         }
         else if(key == "CHAT_ID") {
            TG_CHAT_ID = value;
            Log("Loaded CHAT_ID: " + value);
         }
      }
   }
   
   FileClose(handle);
   
   // Verify that we got real values, not templates
   if(TG_BOT_TOKEN == "" || TG_CHAT_ID == "" || 
      TG_BOT_TOKEN == "YOUR_BOT_TOKEN_HERE" || 
      TG_CHAT_ID == "YOUR_CHAT_ID_HERE") {
      Log("ERROR: Config file has missing/template values. Please edit: " + TG_CONFIG_FILE);
      // SECURITY: no hardcoded fallback
      TG_BOT_TOKEN = "";
      TG_CHAT_ID = "";
      return false;
   }
   
   // Verify token format (should be numbers:letters)
   if(StringFind(TG_BOT_TOKEN, ":") < 0) {
      Log("ERROR: Invalid BOT_TOKEN format. Should be like: 123456:ABCDEF");
      // SECURITY: no hardcoded fallback
      TG_BOT_TOKEN = "";
      TG_CHAT_ID = "";
      return false;
   }
   
   Log("Telegram config loaded successfully");
   // SECURITY: don't print token contents at all (even prefix)
   // Log("Token starts with: " + StringSubstr(TG_BOT_TOKEN, 0, 10) + "...");
   Log("Chat ID: " + TG_CHAT_ID);
   return true;
}

void CreateConfigTemplate() {
   string filename = TG_CONFIG_FILE;
   // Use terminal data folder: MQL4/Files (not Common Files)
   int handle = FileOpen(filename, FILE_WRITE|FILE_TXT);
   
   if(handle == INVALID_HANDLE) {
      Log("ERROR: Cannot create config file!");
      return;
   }
   
   FileWriteString(handle, "# SwingMasterPro EA - Telegram Configuration\n");
   FileWriteString(handle, "# IMPORTANT: Keep this file secure!\n\n");
   FileWriteString(handle, "# Your Telegram Bot Token (from @BotFather)\n");
   FileWriteString(handle, "BOT_TOKEN=YOUR_BOT_TOKEN_HERE\n\n");
   FileWriteString(handle, "# Your Telegram Chat ID\n");
   FileWriteString(handle, "CHAT_ID=YOUR_CHAT_ID_HERE\n");
   
   FileClose(handle);
   Log("Config template created: " + filename);
   Log("Please edit the file and add your credentials!");
}

string DoubleToStrClean(double value, int digits) {
   return DoubleToString(value, digits);
}

// Truncate string to maxLen chars — prevents label overflow beyond panel width
string TruncStr(string s, int maxLen) {
   if(StringLen(s) <= maxLen) return s;
   return StringSubstr(s, 0, maxLen);
}

// RSI entry-quality tag based on bias direction and M15 RSI value
string GetRSIEntryTag(int dir, double rsi) {
   if(dir == -1) { // SELL bias
      if(rsi < 25)       return "[OS]";
      else if(rsi < 35)  return "[OR]";
      else if(rsi <= 55) return "[PB]";
      else if(rsi <= 75) return "[OK]";
      else               return "[OB]";
   } else if(dir == 1) { // BUY bias
      if(rsi > 75)       return "[OB]";
      else if(rsi > 65)  return "[OR]";
      else if(rsi >= 45) return "[PB]";
      else if(rsi >= 25) return "[OK]";
      else               return "[OS]";
   }
   return "";
}

double PipValue(string sym) {
   double point = MarketInfo(sym, MODE_POINT);
   int digits = (int)MarketInfo(sym, MODE_DIGITS);
   if(digits == 3 || digits == 5) return point * 10;
   return point;
}

// Fixed lot sizing — always uses LotSize input (0.03 default)

int FindPairIndex(string sym) {
   for(int i = 0; i < PairsCount; i++) {
      if(Pairs[i] == sym) return i;
   }
   return -1;
}

double GetSpreadPips(string sym) {
   double spread = MarketInfo(sym, MODE_SPREAD);
   double point = MarketInfo(sym, MODE_POINT);
   int digits = (int)MarketInfo(sym, MODE_DIGITS);
   if(digits == 3 || digits == 5) return spread / 10.0;
   return spread;
}

bool IsSpreadOK(string sym) {
   double currentSpread = GetSpreadPips(sym);
   int symIdx = FindPairIndex(sym);
   datetime now = TimeCurrent();
   int logCooldownSec = FilterLogCooldownMins * 60;
   if(logCooldownSec < 0) logCooldownSec = 0;
   
   // Check against max allowed spread
   if(currentSpread > MaxSpreadPips) {
      bool doLog = true;
      if(QuietFilterLogs && symIdx >= 0) {
         if(logCooldownSec > 0 && g_spreadHighLogAt[symIdx] > 0 && (now - g_spreadHighLogAt[symIdx]) < logCooldownSec) doLog = false;
      }
      if(doLog) {
         Log(sym + " spread too high: " + DoubleToStrClean(currentSpread, 1) + " pips");
         if(symIdx >= 0) g_spreadHighLogAt[symIdx] = now;
      }
      return false;
   }
   
   // Find average spread for this pair
   double avgSpread = 0;
   if(symIdx >= 0) avgSpread = AvgSpreads[symIdx];
   
   // Check for spread widening (news/volatility spike)
   if(avgSpread > 0 && currentSpread > avgSpread * MaxSpreadMultiplier) {
      bool doLog = true;
      if(QuietFilterLogs && symIdx >= 0) {
         if(logCooldownSec > 0 && g_spreadWideLogAt[symIdx] > 0 && (now - g_spreadWideLogAt[symIdx]) < logCooldownSec) doLog = false;
      }
      if(doLog) {
         Log(sym + " spread widening detected: " + DoubleToStrClean(currentSpread, 1) + " vs avg " + DoubleToStrClean(avgSpread, 1));
         if(symIdx >= 0) g_spreadWideLogAt[symIdx] = now;
      }
      return false;
   }
   
   return true;
}

int SlippageToPoints(string sym, int slippagePips) {
   double point = MarketInfo(sym, MODE_POINT);
   double pipVal = PipValue(sym);
   if(point <= 0 || pipVal <= 0) return slippagePips;
   int points = (int)MathRound(slippagePips * (pipVal / point));
   if(points < 1) points = 1;
   return points;
}


bool AutoModifySL(int ticket, double newSL) {
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return false;
   if(AutoManageOnlyMagic && OrderMagicNumber() != AutoMagicNumber && OrderMagicNumber() != MagicNumber) return false;
   int type = OrderType();
   if(type != OP_BUY && type != OP_SELL) return false;
   double currentSL = OrderStopLoss();
   double tp = OrderTakeProfit();
   string sym = OrderSymbol();
   int digits = (int)MarketInfo(sym, MODE_DIGITS);
   newSL = NormalizeDouble(newSL, digits);

   // Only improve SL (never worsen)
   if(type == OP_BUY && currentSL != 0 && newSL <= currentSL) return false;
   if(type == OP_SELL && currentSL != 0 && newSL >= currentSL) return false;

   bool ok = OrderModify(ticket, OrderOpenPrice(), newSL, tp, 0, clrAqua);
   if(!ok) {
      Log("Auto SL modify failed: " + sym + " err=" + IntegerToString(GetLastError()));
      ResetLastError();
   }
   return ok;
}

bool AutoModifyTP(int ticket, double newTP) {
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return false;
   if(AutoManageOnlyMagic && OrderMagicNumber() != AutoMagicNumber && OrderMagicNumber() != MagicNumber) return false;
   int type = OrderType();
   if(type != OP_BUY && type != OP_SELL) return false;
   double currentTP = OrderTakeProfit();
   double sl = OrderStopLoss();
   string sym = OrderSymbol();
   int digits = (int)MarketInfo(sym, MODE_DIGITS);
   newTP = NormalizeDouble(newTP, digits);

   // Only extend TP (never reduce)
   if(type == OP_BUY  && currentTP > 0 && newTP <= currentTP) return false;
   if(type == OP_SELL && currentTP > 0 && newTP >= currentTP) return false;

   bool ok = OrderModify(ticket, OrderOpenPrice(), sl, newTP, 0, clrAqua);
   if(!ok) {
      Log("Auto TP modify failed: " + sym + " err=" + IntegerToString(GetLastError()));
      ResetLastError();
   }
   return ok;
}

bool AutoCancelPending(int ticket) {
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return false;
   if(AutoManageOnlyMagic && OrderMagicNumber() != AutoMagicNumber && OrderMagicNumber() != MagicNumber) return false;
   int type = OrderType();
   if(type != OP_BUYLIMIT && type != OP_BUYSTOP && type != OP_SELLLIMIT && type != OP_SELLSTOP) return false;
   bool ok = OrderDelete(ticket);
   if(!ok) {
      Log("Auto cancel pending failed: " + OrderSymbol() + " err=" + IntegerToString(GetLastError()));
      ResetLastError();
   }
   return ok;
}

bool IsPartialCloseDone(int ticket) {
   string key = "SMP_PC_" + IntegerToString(ticket);
   return GlobalVariableCheck(key);
}

void MarkPartialCloseDone(int ticket) {
   string key = "SMP_PC_" + IntegerToString(ticket);
   GlobalVariableSet(key, (double)TimeCurrent());
}

bool AutoPartialCloseTrade(int ticket, double closeLots) {
   if(!AutoPartialClose || !AutoTradingActive()) return false;
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return false;
   if(AutoManageOnlyMagic && OrderMagicNumber() != AutoMagicNumber && OrderMagicNumber() != MagicNumber) return false;
   int type = OrderType();
   if(type != OP_BUY && type != OP_SELL) return false;

   double minLot = MarketInfo(OrderSymbol(), MODE_MINLOT);
   double lotStep = MarketInfo(OrderSymbol(), MODE_LOTSTEP);
   double lots = OrderLots();
   if(lots <= minLot) return false;
   if(lotStep > 0) closeLots = MathFloor(closeLots / lotStep) * lotStep;
   closeLots = NormalizeDouble(closeLots, 2);
   if(closeLots < minLot) return false;
   if(lots - closeLots < minLot) return false;

   double price = (type == OP_BUY) ? MarketInfo(OrderSymbol(), MODE_BID) : MarketInfo(OrderSymbol(), MODE_ASK);
   int slippage = SlippageToPoints(OrderSymbol(), AutoSlippagePips);
   bool ok = OrderClose(ticket, closeLots, price, slippage, clrAqua);
   if(!ok) {
      Log("Auto partial close failed: " + OrderSymbol() + " err=" + IntegerToString(GetLastError()));
      ResetLastError();
      return false;
   }

   Log("Auto partial close executed: " + OrderSymbol() + " ticket=" + IntegerToString(ticket) + " lots=" + DoubleToStrClean(closeLots, 2));
   return true;
}

//+------------------------------------------------------------------+
//| SYMBOL RESOLUTION                                                 |
//+------------------------------------------------------------------+
string ResolveSymbol(string basePair) {
   int total = SymbolsTotal(true);
   for(int i = 0; i < total; i++) {
      string s = SymbolName(i, true);
      // Match exact basePair at start to avoid false positives (e.g., "XEURUSD")
      if(StringSubstr(s, 0, 6) == basePair) {
         SymbolSelect(s, true);
         return s;
      }
   }
   return "";
}

void PreloadHistory(string sym) {
   int tfs[3] = {PERIOD_H1, PERIOD_H4, PERIOD_D1};
   for(int i = 0; i < 3; i++) {
      iMA(sym, tfs[i], 20, 0, MODE_EMA, PRICE_CLOSE, 1);
      iMA(sym, tfs[i], 50, 0, MODE_EMA, PRICE_CLOSE, 1);
      iRSI(sym, tfs[i], RSI_Period, PRICE_CLOSE, 1);
      iATR(sym, tfs[i], ATRPeriod, 1);
   }
   // M15/M30 EMAs needed by GetBiasLabelLow (used for M15 bias display panel and Telegram scorecard).
   // Without this, CurrencyScoreInt returns 0 for M15/M30 on EA attach/restart.
   iMA(sym, PERIOD_M30, 20, 0, MODE_EMA, PRICE_CLOSE, 1);
   iMA(sym, PERIOD_M30, 50, 0, MODE_EMA, PRICE_CLOSE, 1);
   iMA(sym, PERIOD_M15, 20, 0, MODE_EMA, PRICE_CLOSE, 1);
   iMA(sym, PERIOD_M15, 50, 0, MODE_EMA, PRICE_CLOSE, 1);
}

void BuildPairsUniverse() {
   PairsCount = 0;
   for(int i = 0; i < 7; i++) {
      for(int j = 0; j < 7; j++) {
         if(i != j) {
            string sym = ResolveSymbol(Currencies[i] + Currencies[j]);
            if(sym != "") {
               // Trade only allowed pairs list (IsAllowedTradePair already blocks exotics via MajorPairs[])
               if(!IsAllowedTradePair(sym)) {
                  continue;
               }
               PreloadHistory(sym);
               Pairs[PairsCount] = sym;
               // Calculate average spread over 20 ticks
               AvgSpreads[PairsCount] = CalculateAvgSpread(sym);
               PairsCount++;
            }
         }
      }
   }
   Log("Pairs resolved: " + IntegerToString(PairsCount));
}

double CalculateAvgSpread(string sym) {
   // Take multiple non-blocking samples at init for a more stable baseline.
   // Baseline is refreshed every H1 scan via the spread EMA update loop in OnTick.
   double sp1 = GetSpreadPips(sym);
   double sp2 = GetSpreadPips(sym);
   double sp3 = GetSpreadPips(sym);
   double sum = 0;
   int count = 0;
   if(sp1 > 0) { sum += sp1; count++; }
   if(sp2 > 0) { sum += sp2; count++; }
   if(sp3 > 0) { sum += sp3; count++; }
   return (count > 0) ? (sum / count) : 0;
}

//+------------------------------------------------------------------+
//| CURRENCY STRENGTH CALCULATION                                     |
//+------------------------------------------------------------------+
// 3-check trend detection for currency scoring:
//   Check 1 — EMA Position : EMA20 vs EMA50 (bullish/bearish structure)
//   Check 2 — ATR Gap      : |(EMA20-EMA50)/ATR| > 0.1 (trend strong enough, not ranging)
//   Check 3 — EMA Slope    : EMA20[bar1] vs EMA20[bar2] (momentum still moving same way)
// All 3 must agree → +1 (uptrend) or -1 (downtrend)
// Any check fails  →  0 (ranging — not counted in currency score)
int GetTFSignTrend(string sym, int tf) {
   double ema20_b1 = iMA(sym, tf, 20, 0, MODE_EMA, PRICE_CLOSE, 1);  // bar 1 (closed)
   double ema20_b2 = iMA(sym, tf, 20, 0, MODE_EMA, PRICE_CLOSE, 2);  // bar 2 (prev closed)
   double ema50    = iMA(sym, tf, 50, 0, MODE_EMA, PRICE_CLOSE, 1);  // bar 1 (closed)
   double atr      = iATR(sym, tf, ATRPeriod, 1);                     // bar 1 (closed)
   if(ema20_b1 <= 0 || ema20_b2 <= 0 || ema50 <= 0 || atr == 0) return 0;

   // Check 1: EMA position
   bool bullishStructure = (ema20_b1 > ema50);
   bool bearishStructure = (ema20_b1 < ema50);

   // Check 2: ATR-normalized gap must be significant (v2.0: tunable threshold)
   double gapRatio = (ema20_b1 - ema50) / atr;
   bool strongGap = (MathAbs(gapRatio) > TrendGapThreshold);

   // Check 3: EMA20 slope must agree with structure
   //   v2.0: optional 2-bar slope for extra stability
   bool slopeUp, slopeDown;
   if(UseDoubleBarSlope) {
      double ema20_b3 = iMA(sym, tf, 20, 0, MODE_EMA, PRICE_CLOSE, 3);
      if(ema20_b3 <= 0) return 0;
      slopeUp   = (ema20_b1 > ema20_b2 && ema20_b2 > ema20_b3);
      slopeDown = (ema20_b1 < ema20_b2 && ema20_b2 < ema20_b3);
   } else {
      slopeUp   = (ema20_b1 > ema20_b2);
      slopeDown = (ema20_b1 < ema20_b2);
   }

   if(bullishStructure && strongGap && slopeUp)   return  1;
   if(bearishStructure && strongGap && slopeDown) return -1;
   return 0; // ranging
}

// BIAS LOGIC (V2 — H1 + H4 + D1 integer scores):
// Each TF: sum of +1 (EMA20 > EMA50) / -1 (EMA20 < EMA50) across all pairs → range -6 to +6
//
// STRONG  : highest abs score ≥ +5, no opposing WEAK TF
// WEAK    : highest abs score ≤ -4, no opposing STRONG TF
// INV     : has both a STRONG TF (≥+4) AND a WEAK TF (≤-4) across TFs
//           OR maxAbsScore == exactly +4 (borderline-strong, unreliable)
// NEUTRAL : everything else (-3 to +3 dominant)

// Integer score per currency per TF  (-6 to +6)
// Bullish and bearish counts are tracked separately.
// Only the dominant side is returned; if equal, returns 0.
//   currency = base  → +1 if pair bullish, -1 if pair bearish
//   currency = quote → +1 if pair bearish, -1 if pair bullish
// Ranging pairs (GetTFSignTrend = 0) are excluded from the count.
int CurrencyScoreInt(string cur, int tf) {
   int tfi = TFIdx(tf);
   if(tfi < 0) return 0;
   int bullish = 0;
   int bearish = 0;
   for(int i = 0; i < PairsCount; i++) {
      string p     = Pairs[i];
      string base  = StringSubstr(p, 0, 3);
      string quote = StringSubstr(p, 3, 3);
      if(base != cur && quote != cur) continue;
      int sign = g_tfSign[i][tfi];  // cached TF sign — no indicator calls
      if(sign == 0) continue;       // ranging — skip
      int contribution = (base == cur) ? sign : -sign;
      if(contribution > 0) bullish++;
      else                 bearish--;
   }
   if(MathAbs(bullish) > MathAbs(bearish)) return bullish;
   if(MathAbs(bearish) > MathAbs(bullish)) return bearish;
   return 0;
}

// Returns individual uptrend / downtrend / ranging pair counts for a currency on a given timeframe.
// bull = number of pairs trending UP   for this currency (currency strengthening)
// bear = number of pairs trending DOWN for this currency (currency weakening) — stored as positive, display with '-'
// rang = number of pairs ranging / no clear trend on this TF
void CurrencyScoreDetail(string cur, int tf, int &bull, int &bear, int &rang) {
   int tfi = TFIdx(tf);
   bull = 0; bear = 0; rang = 0;
   if(tfi < 0) return;
   for(int i = 0; i < PairsCount; i++) {
      string p     = Pairs[i];
      string base  = StringSubstr(p, 0, 3);
      string quote = StringSubstr(p, 3, 3);
      if(base != cur && quote != cur) continue;
      int sign = g_tfSign[i][tfi];  // cached TF sign — no indicator calls
      if(sign == 0) { rang++; continue; }
      int contribution = (base == cur) ? sign : -sign;
      if(contribution > 0) bull++;
      else                 bear++;
   }
}

string GetBiasLabel(string cur) {
   int h1 = CurrencyScoreInt(cur, PERIOD_H1);
   int h4 = CurrencyScoreInt(cur, PERIOD_H4);
   int d1 = CurrencyScoreInt(cur, PERIOD_D1);

   // v2.0: Apply D1 weighting (D1 carries more authority in trend classification)
   double d1w = d1 * D1_Weight;

   bool hasStrong = (h1 >= 4 || h4 >= 4 || d1w >= 4.0);
   bool hasWeak   = (h1 <= -4 || h4 <= -4 || d1w <= -4.0);

   // INVALID: conflicting extremes across timeframes
   if(hasStrong && hasWeak) return "INV";

   // Find the score with the highest absolute value across all 3 TFs (D1 weighted)
   double maxAbsScore = (double)h1;
   if(MathAbs((double)h4) > MathAbs(maxAbsScore)) maxAbsScore = (double)h4;
   if(MathAbs(d1w) > MathAbs(maxAbsScore)) maxAbsScore = d1w;

   // Special rule (strong side only): borderline +4 -> INVALID
   if((int)MathRound(maxAbsScore) == 4) return "INV";

   // v2.0: Tunable threshold for STRONG classification
   if(maxAbsScore >= (double)BiasStrongThreshold)  {
      // v2.0: Optional RSI filter -- downgrade STRONG if overbought
      if(BiasRSIFilter) {
         double avgRSI = 0; int rsiCnt = 0;
         for(int pi = 0; pi < PairsCount; pi++) {
            string p = Pairs[pi];
            string pbase = StringSubstr(p, 0, 3);
            string pquote = StringSubstr(p, 3, 3);
            if(pbase != cur && pquote != cur) continue;
            double rsi = iRSI(p, PERIOD_H1, RSI_Period, PRICE_CLOSE, 1);
            if(rsi > 0) { avgRSI += rsi; rsiCnt++; }
         }
         if(rsiCnt > 0) avgRSI /= rsiCnt;
         if(avgRSI > BiasRSI_OB) return "INV"; // overbought -- unreliable STRONG
      }
      return "STRONG";
   }
   if(maxAbsScore <= -(double)BiasStrongThreshold) {
      // v2.0: Optional RSI filter -- downgrade WEAK if oversold
      if(BiasRSIFilter) {
         double avgRSI2 = 0; int rsiCnt2 = 0;
         for(int pi2 = 0; pi2 < PairsCount; pi2++) {
            string p2 = Pairs[pi2];
            string pbase2 = StringSubstr(p2, 0, 3);
            string pquote2 = StringSubstr(p2, 3, 3);
            if(pbase2 != cur && pquote2 != cur) continue;
            double rsi2 = iRSI(p2, PERIOD_H1, RSI_Period, PRICE_CLOSE, 1);
            if(rsi2 > 0) { avgRSI2 += rsi2; rsiCnt2++; }
         }
         if(rsiCnt2 > 0) avgRSI2 /= rsiCnt2;
         if(avgRSI2 < BiasRSI_OS) return "INV"; // oversold -- unreliable WEAK
      }
      return "WEAK";
   }
   return "NEUTRAL";
}

// Low-TF bias label for M15 trading: uses H1 / M30 / M15 scores
// v2.0: now uses BiasStrongThreshold (same tunable param as GetBiasLabel)
string GetBiasLabelLow(string cur) {
   int h1  = CurrencyScoreInt(cur, PERIOD_H1);
   int m30 = CurrencyScoreInt(cur, PERIOD_M30);
   int m15 = CurrencyScoreInt(cur, PERIOD_M15);

   bool hasStrong = (h1 >= 4 || m30 >= 4 || m15 >= 4);
   bool hasWeak   = (h1 <= -4 || m30 <= -4 || m15 <= -4);

   if(hasStrong && hasWeak) return "INV";

   int maxAbsScore = h1;
   if(MathAbs(m30) > MathAbs(maxAbsScore)) maxAbsScore = m30;
   if(MathAbs(m15) > MathAbs(maxAbsScore)) maxAbsScore = m15;

   if(maxAbsScore == 4)  return "INV";
   if(maxAbsScore >= BiasStrongThreshold)  return "STRONG";  // v2.0: tunable (was hardcoded 5)
   if(maxAbsScore <= -BiasStrongThreshold) return "WEAK";
   return "NEUTRAL";
}

// --- Confluence tuning ---

// Check if pair contains JPY
bool IsJPYPair(string sym) {
   return (StringFind(sym, "JPY") >= 0);
}

//+------------------------------------------------------------------+
//| PAIR PRIORITY                                                     |
//+------------------------------------------------------------------+
// Priority: 1 = Strong vs Weak (best)
//           2 = Strong(base) vs Neutral  OR  Neutral(base) vs Strong(quote) — symmetric
//           3 = Weak(base)   vs Neutral  OR  Neutral(base) vs Weak(quote)   — symmetric
int GetPairPriority(string sym) {
   string base = StringSubstr(sym, 0, 3);
   string quote = StringSubstr(sym, 3, 3);
   
   // H1 authority only (D1+H4+H1) — no M15 fallback
   string baseBias  = GetBiasLabel(base);
   string quoteBias = GetBiasLabel(quote);

   // INV on either side = no valid signal (conflicted timeframes)
   if(baseBias == "INV" || quoteBias == "INV") return 0;

   // Strong vs Weak = Priority 1 (best)
   if((baseBias == "STRONG" && quoteBias == "WEAK") || 
      (baseBias == "WEAK" && quoteBias == "STRONG")) {
      return 1;
   }
   
   // Strong(base) vs Neutral = Priority 2  [BUY]
   // Neutral(base) vs Strong(quote) = Priority 2  [SELL — symmetric]
   if((baseBias == "STRONG" && quoteBias == "NEUTRAL") ||
      (baseBias == "NEUTRAL" && quoteBias == "STRONG")) {
      return 2;
   }
   
   // Weak(base) vs Neutral = Priority 3  [SELL]
   // Neutral(base) vs Weak(quote) = Priority 3  [BUY — symmetric]
   if((baseBias == "WEAK" && quoteBias == "NEUTRAL") ||
      (baseBias == "NEUTRAL" && quoteBias == "WEAK")) {
      return 3;
   }
   
   // All other combos (NEUTRAL/NEUTRAL) = no trade
   return 0;
}

//+------------------------------------------------------------------+
//| BIAS ALIGNMENT CHECK (NEW LOGIC)                                  |
//+------------------------------------------------------------------+
bool IsBiasAligned(string sym) {
   return (GetPairPriority(sym) > 0);
}

// Derive trade direction purely from two pre-computed bias labels (no TF fallback logic).
// Used by Tradeable Now panel to evaluate H1-only and M15-only directions independently.
int GetDirectionFromBiasLabels(string baseBias, string quoteBias) {
   if(baseBias == "INV" || quoteBias == "INV") return 0;
   if(baseBias == "STRONG" && (quoteBias == "WEAK"    || quoteBias == "NEUTRAL")) return 1;
   if(baseBias == "WEAK"   && (quoteBias == "STRONG"  || quoteBias == "NEUTRAL")) return -1;
   if(baseBias == "NEUTRAL" && quoteBias == "STRONG") return -1;
   if(baseBias == "NEUTRAL" && quoteBias == "WEAK")   return 1;
   return 0;
}

int GetTradeDirection(string sym) {
   string base = StringSubstr(sym, 0, 3);
   string quote = StringSubstr(sym, 3, 3);

   // H1 authority only (D1+H4+H1) — no M15 fallback
   string baseBias  = GetBiasLabel(base);
   string quoteBias = GetBiasLabel(quote);

   // INV on either side = conflicted timeframes, no trade
   if(baseBias == "INV" || quoteBias == "INV") return 0;

   if(baseBias == "STRONG" && (quoteBias == "WEAK"    || quoteBias == "NEUTRAL")) return 1;
   if(baseBias == "WEAK"   && (quoteBias == "STRONG"  || quoteBias == "NEUTRAL")) return -1;
   if(baseBias == "NEUTRAL" && quoteBias == "STRONG") return -1;
   if(baseBias == "NEUTRAL" && quoteBias == "WEAK")   return 1;

   return 0;
}

//+------------------------------------------------------------------+
//| SIGNAL QUALITY SNAPSHOT                                           |
//+------------------------------------------------------------------+
int GetSignalQuality(string sym) {
   if(!IsBiasAligned(sym)) return 0;
   
   int direction = GetTradeDirection(sym);
   if(direction == 0) return 0;
   
   // Use cached indicator values when available
   int idx = FindPairIndex(sym);
   double close, ema20, ema50, rsi, atr;
   if(idx >= 0 && g_cacheUpdatedAt > 0) {
      close = g_cache[idx].h1_close;
      ema20 = g_cache[idx].h1_ema20;
      ema50 = g_cache[idx].h1_ema50;
      rsi   = g_cache[idx].h1_rsi1;
      atr   = g_cache[idx].h1_atr;
   } else {
      close = iClose(sym, PERIOD_H1, 1);
      ema20 = iMA(sym, PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE, 1);
      ema50 = iMA(sym, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE, 1);
      rsi   = iRSI(sym, PERIOD_H1, RSI_Period, PRICE_CLOSE, 1);
      atr   = iATR(sym, PERIOD_H1, ATRPeriod, 1);
   }
   
   int quality = 0;
   
   // Condition 1: Bias aligned (already checked)
   quality++;
   
   // Condition 2: Price near EMA
   double distToEMA20 = MathAbs(close - ema20);
   double distToEMA50 = MathAbs(close - ema50);
   double minDist = MathMin(distToEMA20, distToEMA50);
   if(minDist <= atr * EMA_PullbackATR) quality++;
   
   // Condition 3: RSI in zone
   if(direction == 1 && rsi >= RSI_BuyZoneLow && rsi <= RSI_BuyZoneHigh) quality++;
   if(direction == -1 && rsi >= RSI_SellZoneLow && rsi <= RSI_SellZoneHigh) quality++;
   
   // Condition 4: Candle rejection (wick > body) — bar 1 (closed candle)
   double open = iOpen(sym, PERIOD_H1, 1);
   double high = iHigh(sym, PERIOD_H1, 1);
   double low = iLow(sym, PERIOD_H1, 1);
   double body = MathAbs(close - open);
   double upperWick = high - MathMax(close, open);
   double lowerWick = MathMin(close, open) - low;
   
   if(direction == 1 && lowerWick > body) quality++;
   if(direction == -1 && upperWick > body) quality++;
   
   return quality;
}

string GetQualityStars(int quality) {
   if(quality >= 5) return "*****";
   if(quality >= 4) return "****";
   if(quality >= 3) return "***";
   if(quality >= 2) return "**";
   if(quality >= 1) return "*";
   return "";
}

string GetMarketStatus() {
   int hour = TimeHour(TimeGMT());
   int dayOfWeek = TimeDayOfWeek(TimeGMT());
   
   if(dayOfWeek == 0 || dayOfWeek == 6) return "CLOSED (Weekend)";
   
   if(hour >= LondonStartHour && hour < LondonEndHour) {
      if(hour >= NYStartHour) return "OPEN (London + NY Overlap)";
      return "OPEN (London Session)";
   }
   if(hour >= NYStartHour && hour < NYEndHour) return "OPEN (NY Session)";
   if(hour >= 0 && hour < 8) return "LOW VOL (Asian Session)";
   
   return "OPEN";
}

//+------------------------------------------------------------------+
//| RISK TRACKING                                                     |
//+------------------------------------------------------------------+
void UpdateRiskTracking() {
   currentRiskAmount = 0;
   currentRiskPercent = 0;
   currentRiskNoSLTrades = 0;
   currentRiskTrackedTrades = 0;

   for(int i = 0; i < OrdersTotal(); i++) {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         int type = OrderType();
         if(type != OP_BUY && type != OP_SELL) continue; // risk = open market positions only

         if(AutoManageOnlyMagic) {
            int mg = OrderMagicNumber();
            if(mg != AutoMagicNumber && mg != MagicNumber) continue;
         }

         double sl = OrderStopLoss();
         double open = OrderOpenPrice();
         double lots = OrderLots();
         string sym = OrderSymbol();

         if(sl == 0) {
            currentRiskNoSLTrades++;
            continue;
         }

         double pipVal = PipValue(sym);
         if(pipVal <= 0) continue;
         double slPips = MathAbs(open - sl) / pipVal;
         double tickValue = MarketInfo(sym, MODE_TICKVALUE);
         double tickSize  = MarketInfo(sym, MODE_TICKSIZE);

         double pipValueMoneyPerLot = 0;
         if(tickValue > 0 && tickSize > 0) {
            // Primary: broker-supplied tick value
            pipValueMoneyPerLot = tickValue * (pipVal / tickSize);
         } else {
            // Fallback: contract size * pip size (works for USD-quoted pairs on USD accounts)
            double contractSize = MarketInfo(sym, MODE_LOTSIZE);
            if(contractSize > 0 && pipVal > 0)
               pipValueMoneyPerLot = contractSize * pipVal;
         }

         if(pipValueMoneyPerLot <= 0 || slPips <= 0 || lots <= 0) continue;

         double orderRisk = slPips * lots * pipValueMoneyPerLot;
         if(orderRisk < 0) orderRisk = MathAbs(orderRisk);
         currentRiskAmount += orderRisk;
         currentRiskTrackedTrades++;
      }
   }

   if(AccountBalance() > 0) currentRiskPercent = (currentRiskAmount / AccountBalance()) * 100.0;
}

double GetRemainingRiskBudget() {
   return (MaxDailyRiskPercent - currentRiskPercent);
}

string GetRiskStatus() {
   double remaining = GetRemainingRiskBudget();
   if(currentRiskTrackedTrades == 0 && currentRiskNoSLTrades > 0) return "UNPROTECTED (NO SL)";
   if(remaining <= 0) return "MAX RISK - NO NEW TRADES";
   if(remaining < 0.5) return "LIMITED (1 small trade left)";
   return "CAN TRADE";
}


//+------------------------------------------------------------------+
//| DRAWDOWN CHECK                                                    |
//+------------------------------------------------------------------+
double GetDailyDrawdown() {
   if(dayStartBalance == 0) return 0;
   double dd = ((dayStartBalance - AccountEquity()) / dayStartBalance) * 100;
   return MathMax(0, dd);
}

bool IsDrawdownOK() {
   return (GetDailyDrawdown() < MaxDrawdownPercent);
}

//+------------------------------------------------------------------+
//| URL ENCODE                                                        |
//| RFC 3986 compliant. Handles ASCII unreserved chars as-is,        |
//| encodes space/newline explicitly, and properly encodes multi-byte |
//| Unicode (UTF-8 2/3/4-byte sequences). Verified complete for all  |
//| codepoints used by Telegram message content.                      |
//+------------------------------------------------------------------+
string UrlEncode(string s) {
   string out = "";
   int n = StringLen(s);
   for(int i = 0; i < n; i++) {
      int c = StringGetCharacter(s, i);
      if((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.' || c == '~')
         out += CharToString((uchar)c);
      else if(c == ' ') out += "%20";
      else if(c == '\n') out += "%0A";
      else if(c <= 0x7F)
         out += "%" + StringFormat("%02X", c);
      else if(c <= 0x7FF) {
         // 2-byte UTF-8: 110xxxxx 10xxxxxx
         out += "%" + StringFormat("%02X", 0xC0 | (c >> 6));
         out += "%" + StringFormat("%02X", 0x80 | (c & 0x3F));
      }
      else if(c < 0xD800 || c > 0xDFFF) {
         // 3-byte UTF-8: 1110xxxx 10xxxxxx 10xxxxxx (BMP non-surrogate)
         out += "%" + StringFormat("%02X", 0xE0 | (c >> 12));
         out += "%" + StringFormat("%02X", 0x80 | ((c >> 6) & 0x3F));
         out += "%" + StringFormat("%02X", 0x80 | (c & 0x3F));
      }
      else if(c >= 0xD800 && c <= 0xDBFF && i + 1 < n) {
         // High surrogate: combine with low surrogate for 4-byte UTF-8
         int c2 = StringGetCharacter(s, i + 1);
         if(c2 >= 0xDC00 && c2 <= 0xDFFF) {
            int cp = 0x10000 + ((c - 0xD800) << 10) + (c2 - 0xDC00);
            out += "%" + StringFormat("%02X", 0xF0 | (cp >> 18));
            out += "%" + StringFormat("%02X", 0x80 | ((cp >> 12) & 0x3F));
            out += "%" + StringFormat("%02X", 0x80 | ((cp >> 6) & 0x3F));
            out += "%" + StringFormat("%02X", 0x80 | (cp & 0x3F));
            i++; // skip low surrogate
         }
      }
      // lone surrogates: skip
   }
   return out;
}

string StripTelegramTags(string s) {
   // Remove all Telegram-supported HTML formatting tags to preserve comparison operators.
   // Covers: bold, italic, underline, strikethrough, code, pre, blockquote, spoiler.
   string out = s;
   StringReplace(out, "<b>", "");    StringReplace(out, "</b>", "");
   StringReplace(out, "<i>", "");    StringReplace(out, "</i>", "");
   StringReplace(out, "<u>", "");    StringReplace(out, "</u>", "");
   StringReplace(out, "<s>", "");    StringReplace(out, "</s>", "");
   StringReplace(out, "<code>", ""); StringReplace(out, "</code>", "");
   StringReplace(out, "<pre>", "");  StringReplace(out, "</pre>", "");
   StringReplace(out, "<tg-spoiler>", ""); StringReplace(out, "</tg-spoiler>", "");
   return out;
}

bool HasVisibleText(string s) {
   int n = StringLen(s);
   for(int i = 0; i < n; i++) {
      int c = StringGetCharacter(s, i);
      if(c == ' ' || c == '\n' || c == '\r' || c == '\t') continue;
      return true;
   }
   return false;
}

string SanitizeTelegramHtml(string s) {
   string out = s;
   // Escape & that are NOT already part of a valid entity
   StringReplace(out, "P&L", "P&amp;L");
   StringReplace(out, "(ADX<", "(ADX lt ");
   StringReplace(out, " < ", " lt ");
   StringReplace(out, " > ", " gt ");
   return out;
}

int ExtractTelegramRetryAfter(string resp) {
   string key = "\"retry_after\":";
   int k = StringFind(resp, key);
   if(k < 0) return 0;
   int p = k + StringLen(key);
   int n = StringLen(resp);
   while(p < n) {
      int ch = StringGetCharacter(resp, p);
      if(ch >= '0' && ch <= '9') break;
      p++;
   }
   int e = p;
   while(e < n) {
      int ch2 = StringGetCharacter(resp, e);
      if(!(ch2 >= '0' && ch2 <= '9')) break;
      e++;
   }
   if(e <= p) return 0;
   return (int)StringToInteger(StringSubstr(resp, p, e - p));
}

//+------------------------------------------------------------------+
//| TELEGRAM SEND (with message splitting for long messages)          |
//+------------------------------------------------------------------+
bool SendTelegramPartWithMode(string text, bool useHtml) {
   g_tgLastWasRateLimited = false;
   g_tgLastBlockedByThrottle = false;
   g_tgLastWasEmptyMsg = false;

   // Respect server retry window to avoid spamming API while rate-limited
   datetime now = TimeLocal();
   string rateKey = "SMP_TG_RATE_LIMIT_UNTIL_" + TG_CHAT_ID;

   // Cross-instance cooldown (multiple charts/EA instances)
   if(GlobalVariableCheck(rateKey)) {
      datetime gvUntil = (datetime)GlobalVariableGet(rateKey);
      if(gvUntil > g_tgRateLimitUntil) g_tgRateLimitUntil = gvUntil;
   }

   if(g_tgRateLimitUntil > now) {
      g_tgLastWasRateLimited = true;
      if(g_tgRateLimitLogAt == 0 || (now - g_tgRateLimitLogAt) >= 10) {
         int waitSec = (int)(g_tgRateLimitUntil - now);
         Log("WARNING: Telegram rate-limit cooldown active (" + IntegerToString(waitSec) + "s)");
         g_tgRateLimitLogAt = now;
      }
      return false;
   }

   // Soft throttle even when not rate-limited
   int minGap = TelegramMinSendIntervalSec;
   if(minGap < 0) minGap = 0;
   if(minGap > 0 && g_tgLastSendAt > 0 && (now - g_tgLastSendAt) < minGap) {
      g_tgLastBlockedByThrottle = true;
      return false;
   }

   // Guard: must have credentials
   if(TG_BOT_TOKEN == "" || TG_CHAT_ID == "") {
      Log("Telegram not configured (missing BOT_TOKEN/CHAT_ID). Skipping send.");
      return false;
   }

   if(useHtml && g_tgForcePlainUntil > now) useHtml = false;
   if(useHtml) {
      text = SanitizeTelegramHtml(text);
   } else {
      string plainText = StripTelegramTags(text);
      if(plainText != "") text = plainText;
   }

   // Guard against empty payloads (Telegram 400: message text is empty)
   // In HTML mode, tags like <b></b> are not visible text, so validate using stripped payload.
   string visibleText = useHtml ? StripTelegramTags(text) : text;
   if(!HasVisibleText(visibleText)) {
      Log("WARNING: Telegram send skipped (empty message after formatting).");
      return false;
   }

   // Use POST to avoid URL length limits (~2000 chars) on long messages
   string url = "https://api.telegram.org/bot" + TG_BOT_TOKEN + "/sendMessage";
   string postBody = "chat_id=" + TG_CHAT_ID +
                     (useHtml ? "&parse_mode=HTML" : "") +
                     "&text=" + UrlEncode(text);
   
   if(DEBUG_PRINT) {
      Log("Sending to Telegram (" + IntegerToString(StringLen(text)) + " chars)");
      Log("Telegram request prepared (token hidden)");
   }

   char postData[];
   StringToCharArray(postBody, postData, 0, StringLen(postBody));
   char result[];
   string respHeaders;
   int timeout = 5000;
   string reqHeaders = "Content-Type: application/x-www-form-urlencoded\r\n";

   int res = WebRequest("POST", url, reqHeaders, timeout, postData, result, respHeaders);
   if(res == -1) {
      int error = GetLastError();
      Log("WebRequest failed: " + IntegerToString(error));
      Log("Make sure WebRequest is enabled for: https://api.telegram.org");
      ResetLastError();
      return false;
   }

   string resp = CharArrayToString(result, 0, -1);
   if(VerboseTelegramLogs) Log("Telegram API Response: " + resp);

   if(res == 429 || StringFind(resp, "\"error_code\":429") >= 0) {
      int retrySec = ExtractTelegramRetryAfter(resp);
      if(retrySec <= 0) retrySec = 30;
      g_tgRateLimitUntil = TimeLocal() + retrySec;
      GlobalVariableSet(rateKey, (double)g_tgRateLimitUntil);
      g_tgLastWasRateLimited = true;
      Log("WARNING: Telegram 429 rate-limit. Backing off for " + IntegerToString(retrySec) + "s.");
      return false;
   }
   
   // Check if response contains "ok":true
   if(StringFind(resp, "\"ok\":true") >= 0) {
      if(VerboseTelegramLogs) Log("[OK] Message sent to Telegram successfully");
      g_tgLastSendAt = now;
      return true;
   } else {
      // If HTML parse entities error occurs, temporarily force plain text mode
      if(StringFind(resp, "can't parse entities") >= 0) {
         int cool = TelegramParseErrorCooldownSec;
         if(cool < 0) cool = 0;
         g_tgForcePlainUntil = TimeLocal() + cool;
      }
      // Abort retries immediately on unrecoverable empty-message 400 error
      if(StringFind(resp, "message text is empty") >= 0) g_tgLastWasEmptyMsg = true;
      Log("[ERR] Telegram API Error: " + resp);
      return false;
   }
}

bool SendTelegramPart(string text) {
   if(SendTelegramPartWithMode(text, true)) return true;
   if(g_tgLastBlockedByThrottle) return false;
   if(g_tgLastWasRateLimited) return false;
   if(g_tgLastWasEmptyMsg) return false;  // don't attempt plain fallback on empty-message error
   // Fallback: if HTML fails, retry as plain text
   string plain = StripTelegramTags(text);
   if(plain == "") plain = text;
   return SendTelegramPartWithMode(plain, false);
}

bool SendTelegram(string text) {
   // URL encoding expands text; keep conservative limit to avoid URL overflow
   int maxLen = 900;
   int textLen = StringLen(text);
   int gapSec = TelegramMinSendIntervalSec;
   if(gapSec < 0) gapSec = 0;
   int sendGapMs = 500;
   if(gapSec > 0 && gapSec * 1000 > sendGapMs) sendGapMs = gapSec * 1000;
   
   if(textLen <= maxLen) {
      for(int a = 0; a < 5; a++) {
         bool okSingle = SendTelegramPart(text);
         if(okSingle) return true;
         if(g_tgLastWasRateLimited) return false;
         if(g_tgLastWasEmptyMsg) return false;  // abort immediately on unrecoverable error
         if(sendGapMs > 0) Sleep(sendGapMs);
      }
      return false;
   }
   
   // Count total parts first
   int totalParts = 0;
   int tempPos = 0;
   while(tempPos < textLen) {
      int tempEnd = tempPos + maxLen;
      if(tempEnd > textLen) tempEnd = textLen;
      
      if(tempEnd < textLen) {
         // Prefer paragraph boundary (blank line), then any newline
         int minPos = tempPos + 20;
         int paraSplit = -1;
         for(int i = tempEnd - 1; i > minPos; i--) {
            if(StringGetCharacter(text, i) == '\n' && StringGetCharacter(text, i - 1) == '\n') {
               paraSplit = i + 1;
               break;
            }
         }
         if(paraSplit > tempPos) tempEnd = paraSplit;
         else {
            for(int j = tempEnd - 1; j > minPos; j--) {
               if(StringGetCharacter(text, j) == '\n') {
                  tempEnd = j + 1;
                  break;
               }
            }
         }
      }
      totalParts++;
      tempPos = tempEnd;
   }
   
   // Now send parts
   int partNum = 1;
   int pos = 0;
   
   while(pos < textLen) {
      int endPos = pos + maxLen;
      if(endPos > textLen) endPos = textLen;
      
      // Find a newline to split at (don't cut mid-line)
      if(endPos < textLen) {
         int bestSplit = -1;
         int minPos = pos + 20;
         // Prefer paragraph boundary (blank line)
         for(int i = endPos - 1; i > minPos; i--) {
            if(StringGetCharacter(text, i) == '\n' && StringGetCharacter(text, i - 1) == '\n') {
               bestSplit = i + 1;
               break;
            }
         }
         // Fallback to any newline
         if(bestSplit <= pos) {
            for(int j = endPos - 1; j > minPos; j--) {
               if(StringGetCharacter(text, j) == '\n') {
                  bestSplit = j + 1;
                  break;
               }
            }
         }
         if(bestSplit > pos) endPos = bestSplit;
      }
      
      string part = StringSubstr(text, pos, endPos - pos);
      if(!HasVisibleText(part)) {
         pos = endPos;
         partNum++;
         continue;
      }
      
      // Add part indicator
      if(totalParts > 1) {
         part = "[" + IntegerToString(partNum) + "/" + IntegerToString(totalParts) + "]\n" + part;
      }

      bool sent = false;
      for(int a = 0; a < 5; a++) {
         sent = SendTelegramPart(part);
         if(sent) break;
         if(g_tgLastWasRateLimited) {
            Log("WARNING: Telegram multipart paused at part " + IntegerToString(partNum) + "/" + IntegerToString(totalParts) + " (rate-limited).");
            return false;
         }
         if(g_tgLastWasEmptyMsg) {
            Log("WARNING: Telegram multipart aborted at part " + IntegerToString(partNum) + "/" + IntegerToString(totalParts) + " (empty message error).");
            return false;
         }
         if(sendGapMs > 0) Sleep(sendGapMs);
      }
      if(!sent) {
         Log("WARNING: Telegram multipart failed at part " + IntegerToString(partNum) + "/" + IntegerToString(totalParts) + ".");
         return false;
      }

      if(sendGapMs > 0) Sleep(sendGapMs);
      
      pos = endPos;
      partNum++;
   }
   
   return true;
}

// --- Telegram tag helpers ---
string TGTag() {
   if(ManualModeOnly || !EnableAutoTrading) return " [MANUAL ONLY]";
   return (AutoTradingActive() ? " [AUTO MODE]" : " [AUTO OFF]");
}


void UpdateAlertBadge() {
   if(!ShowAlertBadge) {
      ObjectDelete(0, "AlertBadge");
      return;
   }

   if(lastAlertBadgeTime == 0 || (TimeCurrent() - lastAlertBadgeTime) > (AlertBadgeMinutes * 60)) {
      ObjectDelete(0, "AlertBadge");
      return;
   }

   int minsLeft = (int)((AlertBadgeMinutes * 60 - (TimeCurrent() - lastAlertBadgeTime)) / 60);
   string text = "ALERT ACTIVE" + (minsLeft > 0 ? " (" + IntegerToString(minsLeft) + "m)" : "");

   if(ObjectFind(0, "AlertBadge") == -1) {
      ObjectCreate(0, "AlertBadge", OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "AlertBadge", OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, "AlertBadge", OBJPROP_YDISTANCE, 10);
   }
   ObjectSetString(0, "AlertBadge", OBJPROP_TEXT, text);
   ObjectSetInteger(0, "AlertBadge", OBJPROP_COLOR, AlertBadgeColor);
   ObjectSetInteger(0, "AlertBadge", OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, "AlertBadge", OBJPROP_FONT, "Arial Black");
}

void MarkAlertBadge() {
   if(!ShowAlertBadge) return;
   lastAlertBadgeTime = TimeCurrent();
   UpdateAlertBadge();
}

//+------------------------------------------------------------------+
//| BUILD BIAS PANEL MESSAGE (mirrors BiasPanelDisplay — 3 sections) |
//+------------------------------------------------------------------+
string BuildBiasPanelMessage() {
   string msg = "<b>== BIAS PANEL ==</b>" + TGTag() + "\n";
   msg += "Time: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + "\n\n";

   // --- Section 1: H1 Chart Bias (D1/H4/H1) ---
   msg += "<b>BIAS (D1/H4/H1):</b>\n";
   for(int i = 0; i < 7; i++) {
      string cur  = Currencies[i];
      string bias = GetBiasLabel(cur);
      string sh   = (bias == "STRONG") ? "^ STR" : (bias == "WEAK") ? "v WK" : (bias == "INV") ? "? INV" : "- NEU";
      int d1b, d1br, d1r, h4b, h4br, h4r, h1b, h1br, h1r;
      CurrencyScoreDetail(cur, PERIOD_D1, d1b, d1br, d1r);
      CurrencyScoreDetail(cur, PERIOD_H4, h4b, h4br, h4r);
      CurrencyScoreDetail(cur, PERIOD_H1, h1b, h1br, h1r);
      msg += cur + ": " + sh
           + " | D1:+" + IntegerToString(d1b) + "/-" + IntegerToString(d1br) + "/" + IntegerToString(d1r)
           + " | H4:+" + IntegerToString(h4b) + "/-" + IntegerToString(h4br) + "/" + IntegerToString(h4r)
           + " | H1:+" + IntegerToString(h1b) + "/-" + IntegerToString(h1br) + "/" + IntegerToString(h1r) + "\n";
   }

   // --- Section 2: M15 Chart Bias (H1/M30/M15) ---
   msg += "\n<b>BIAS (H1/M30/M15):</b>\n";
   for(int j = 0; j < 7; j++) {
      string cur  = Currencies[j];
      string bias = GetBiasLabelLow(cur);
      string sh   = (bias == "STRONG") ? "^ STR" : (bias == "WEAK") ? "v WK" : (bias == "INV") ? "? INV" : "- NEU";
      int mh1b, mh1br, mh1r, mm30b, mm30br, mm30r, mm15b, mm15br, mm15r;
      CurrencyScoreDetail(cur, PERIOD_H1,  mh1b,  mh1br,  mh1r);
      CurrencyScoreDetail(cur, PERIOD_M30, mm30b, mm30br, mm30r);
      CurrencyScoreDetail(cur, PERIOD_M15, mm15b, mm15br, mm15r);
      msg += cur + ": " + sh
           + " | H1:+"  + IntegerToString(mh1b)  + "/-" + IntegerToString(mh1br)  + "/" + IntegerToString(mh1r)
           + " | M30:+" + IntegerToString(mm30b)  + "/-" + IntegerToString(mm30br) + "/" + IntegerToString(mm30r)
           + " | M15:+" + IntegerToString(mm15b)  + "/-" + IntegerToString(mm15br) + "/" + IntegerToString(mm15r) + "\n";
   }

   // --- Section 3: Tradeable Now ---
   msg += "\n<b>TRADEABLE NOW:</b>\n";
   string buyLines = "";
   string sellLines = "";

   for(int pi = 0; pi < PairsCount; pi++) {
      string psym   = Pairs[pi];
      string pbase  = StringSubstr(psym, 0, 3);
      string pquote = StringSubstr(psym, 3, 3);

      int dirH1  = GetDirectionFromBiasLabels(GetBiasLabel(pbase), GetBiasLabel(pquote));
      if(dirH1 == 0) continue;

      int    dir     = dirH1;
      int    dirM15  = GetDirectionFromBiasLabels(GetBiasLabelLow(pbase), GetBiasLabelLow(pquote));
      string pairLbl = psym + (dirM15 == dirH1 ? "[H1/M15]" : "[H1]");

      double tEMA20  = iMA(psym, PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE, 1);
      double tATR    = iATR(psym, PERIOD_H1, ATRPeriod, 1);
      double tClose  = iClose(psym, PERIOD_H1, 1);
      double tRSI1   = iRSI(psym, PERIOD_H1, RSI_Period, PRICE_CLOSE, 1);
      double tRSI2   = iRSI(psym, PERIOD_H1, RSI_Period, PRICE_CLOSE, 2);
      double tEMADist = tClose - tEMA20;
      string tEMATag = (tATR > 0 && MathAbs(tEMADist) <= tATR * EMA_PullbackATR) ? "~" : (tEMADist > 0 ? "^" : "v");
      string tRSIDir = (tRSI1 > tRSI2) ? "^" : (tRSI1 < tRSI2) ? "v" : "-";

      double tEMA20m  = iMA(psym, PERIOD_M15, 20, 0, MODE_EMA, PRICE_CLOSE, 1);
      double tATRm    = iATR(psym, PERIOD_M15, ATRPeriod, 1);
      double tClosem  = iClose(psym, PERIOD_M15, 1);
      double tRSI1m   = iRSI(psym, PERIOD_M15, RSI_Period, PRICE_CLOSE, 1);
      double tRSI2m   = iRSI(psym, PERIOD_M15, RSI_Period, PRICE_CLOSE, 2);
      double tEMADistm = tClosem - tEMA20m;
      string tEMATagm = (tATRm > 0 && MathAbs(tEMADistm) <= tATRm * EMA_PullbackATR) ? "~" : (tEMADistm > 0 ? "^" : "v");
      string tRSIDirm = (tRSI1m > tRSI2m) ? "^" : (tRSI1m < tRSI2m) ? "v" : "-";
      string tEntryTagH1 = GetRSIEntryTag(dir, tRSI1);
      string tEntryTagM15 = GetRSIEntryTag(dir, tRSI1m);

      string line = pairLbl
                  + " | H1:EMA:" + tEMATag + " RSI:" + DoubleToStrClean(tRSI1, 0) + tRSIDir + " " + tEntryTagH1
                  + " M15:EMA:" + tEMATagm + " RSI:" + DoubleToStrClean(tRSI1m, 0) + tRSIDirm + " " + tEntryTagM15 + "\n";

      if(dir == 1) buyLines  += line;
      else         sellLines += line;
   }

   if(buyLines == "" && sellLines == "") {
      msg += "No clear bias on any pair.\n";
   } else {
      if(buyLines  != "") msg += "<b>^ BUY:</b>\n"  + buyLines;
      if(sellLines != "") msg += "<b>v SELL:</b>\n" + sellLines;
   }

   return msg;
}

//+------------------------------------------------------------------+
//| DRAWDOWN ALERT                                                    |
//+------------------------------------------------------------------+
bool drawdownWarningSet = false;
bool drawdownLimitSent = false;

void CheckDrawdownAlerts() {
   double dd = GetDailyDrawdown();
   
   if(dd >= DrawdownWarning && !drawdownWarningSet) {
      drawdownWarningSet = true;
      
      string msg = "<b>! DRAWDOWN WARNING !</b>" + TGTag() + "\n";
      msg += "[TIME] " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + "\n\n";
      msg += "Current Drawdown: " + DoubleToStrClean(dd, 1) + "%\n";
      msg += "Max Allowed: " + DoubleToStrClean(MaxDrawdownPercent, 1) + "%\n\n";
      msg += "Status: CAUTION\n";
      msg += "Action: Consider reducing position sizes\n";
      msg += "Remaining budget: " + DoubleToStrClean(MaxDrawdownPercent - dd, 1) + "%";
      msg += "\nACTION: Reduce size or pause new entries.\n";
      MarkAlertBadge();
      SendTelegram(msg);
   }
   
   if(dd >= MaxDrawdownPercent && !drawdownLimitSent) {
      drawdownLimitSent = true;
      
      string msg = "<b>DAILY LIMIT REACHED</b>" + TGTag() + "\n";
      msg += "[TIME] " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + "\n\n";
      msg += "Daily Drawdown: " + DoubleToStrClean(dd, 1) + "%\n";
      msg += "Max Allowed: " + DoubleToStrClean(MaxDrawdownPercent, 1) + "%\n\n";
      msg += "Status: TRADING PAUSED\n";
      msg += "New signals will resume tomorrow.\n\n";
      msg += "Current Balance: $" + DoubleToStrClean(AccountBalance(), 2);
      msg += "\nACTION: Stop trading for today.\n";
      MarkAlertBadge();
      SendTelegram(msg);
   }
}

//+------------------------------------------------------------------+
//| TRAILING STOP ALERT - Monitor Open Trades                         |
//+------------------------------------------------------------------+
void CheckTrailingStopAlerts() {
   if(TimeCurrent() - lastTrailingCheck < 60) return;   // Check every 1 minute
   lastTrailingCheck = TimeCurrent();
   
   int totalOrders = OrdersTotal();
   if(totalOrders == 0) return;
   
   for(int i = totalOrders - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      
      int ticket = OrderTicket();
      string sym = OrderSymbol();
      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;  // skip pending orders
      if(StringFind(OrderComment(), RecoveryComment) >= 0) continue; // skip recovery hedge orders (managed by recovery system)
      double entry = OrderOpenPrice();
      double sl = OrderStopLoss();
      double tp = OrderTakeProfit();
      double lots = OrderLots();
      double currentPrice = (type == OP_BUY) ? MarketInfo(sym, MODE_BID) : MarketInfo(sym, MODE_ASK);
      double pipVal = PipValue(sym);
      double atr = iATR(sym, PERIOD_H1, ATRPeriod, 1);  // bar 1 (closed) — bar 0 is forming/incomplete
      
      // Calculate profit in pips
      double profitPips = 0;
      if(type == OP_BUY) {
         profitPips = (currentPrice - entry) / pipVal;
      } else {
         profitPips = (entry - currentPrice) / pipVal;
      }
      
      // Dynamic trigger: trail once profit >= actual SL distance (1:1 reached).
      // Fallback to TrailingTriggerPips if the order has no SL set.
      double slDistPips = (sl > 0 && pipVal > 0) ? MathAbs(entry - sl) / pipVal : 0;
      double effectiveTrailTrigger = (slDistPips > 0) ? slDistPips : TrailingTriggerPips;

      // Alert if profit >= trigger and SL not at breakeven yet
      if(profitPips >= effectiveTrailTrigger) {
         double suggestedSL = 0;
         double minLot = MarketInfo(sym, MODE_MINLOT);

         if(PartialClosePct > 0 && PartialCloseAtPips > 0 && profitPips >= PartialCloseAtPips) {
            double lotStep = MarketInfo(sym, MODE_LOTSTEP);
            double closeLotsRaw = lots * (PartialClosePct / 100.0);
            double closeLots = (lotStep > 0) ? MathFloor(closeLotsRaw / lotStep) * lotStep : closeLotsRaw;
            closeLots = NormalizeDouble(closeLots, 2);
            if(lots <= minLot) closeLots = 0;
            if(closeLots > (lots - minLot)) closeLots = lots - minLot;
            double remainingLots = lots - closeLots;

            if(!IsPartialCloseDone(ticket) && closeLots >= minLot && remainingLots >= minLot) {
               if(AutoPartialCloseTrade(ticket, closeLots)) {
                  MarkPartialCloseDone(ticket);
               }
            }
         }

         if(type == OP_BUY) {
            // Bias check: is H1 still bullish on this pair?
            string trBase = StringSubstr(sym, 0, 3), trQuote = StringSubstr(sym, 3, 3);
            int h1TrailDir = GetDirectionFromBiasLabels(GetBiasLabel(trBase), GetBiasLabel(trQuote));
            bool biasLost = (h1TrailDir != 1); // neutral or flipped bearish

            // Stage 1: breakeven lock (profit >= 1× SL dist)
            suggestedSL = entry + (BreakEvenBufferPips * pipVal);
            // Stage 2: partial lock — lock TrailStage2LockPct% of current profit (profit >= TrailStage2Mult× SL dist)
            if(profitPips >= (effectiveTrailTrigger * TrailStage2Mult)) {
               double stage2SL = entry + (profitPips * (TrailStage2LockPct / 100.0) * pipVal);
               if(stage2SL > suggestedSL) suggestedSL = stage2SL;
            }
            // Stage 3: ATR trail — follows price continuously (profit >= 2× SL dist)
            if(UseATRTrailSuggestion && atr > 0 && profitPips >= (effectiveTrailTrigger * 2.0)) {
               double atrSL = currentPrice - (ATRTrailMult * atr);
               if(atrSL > suggestedSL) suggestedSL = atrSL;
            }
            // Stage 4: tight ATR trail — tighter lock at big profits (profit >= 3× SL dist)
            if(UseATRTrailSuggestion && atr > 0 && profitPips >= (effectiveTrailTrigger * 3.0)) {
               double atrSL4 = currentPrice - (ATRTrailMultTight * atr);
               if(atrSL4 > suggestedSL) suggestedSL = atrSL4;
            }
            // Bias lost: force tight ATR trail immediately regardless of profit stage — protect gains
            if(biasLost && UseATRTrailSuggestion && atr > 0) {
               double biasLostSL = currentPrice - (ATRTrailMultTight * atr);
               if(biasLostSL > suggestedSL) {
                  suggestedSL = biasLostSL;
                  Log(sym + " #" + IntegerToString(ticket) + " [BiasLost] H1 neutral/bearish — forcing tight trail SL");
               }
            }
            // Auto extend TP when price is near target (repeats each time price approaches new TP)
            // Uses IsTradeAllowed() directly — AutoExtendTP=true is explicit consent, ManualModeOnly must not block it
            if(AutoExtendTP && IsTradeAllowed() && tp > 0 && pipVal > 0) {
               // Only extend if H1 bias still agrees with trade direction
               string tpBase = StringSubstr(sym, 0, 3), tpQuote = StringSubstr(sym, 3, 3);
               int h1ExtDir = GetDirectionFromBiasLabels(GetBiasLabel(tpBase), GetBiasLabel(tpQuote));
               if(h1ExtDir == 1) { // H1 still bullish — safe to extend BUY TP
                  double tpDistPips = MathAbs(tp - entry) / pipVal; // current TP dist (grows with each extension)
                  double remainingToTP = (tp - currentPrice) / pipVal;
                  if(tpDistPips > 0 && remainingToTP >= 0 && remainingToTP <= (tpDistPips * (TPExtendNearPct / 100.0))) {
                     // Snap to next S/R level above current TP — avoids landing inside resistance
                     double srExt[]; int srExtCnt = FindSRLevelsSym(sym, srExt);
                     double newTP = 0;
                     for(int sri = 0; sri < srExtCnt; sri++) {
                        if(srExt[sri] > tp + pipVal) { newTP = srExt[sri]; break; }
                     }
                     // Fallback: flat ATR extend if no S/R found beyond current TP
                     if(newTP <= tp) newTP = tp + ((atr > 0) ? (ATRTrailMult * atr) : (20.0 * pipVal));
                     AutoModifyTP(ticket, NormalizeDouble(newTP, (int)MarketInfo(sym, MODE_DIGITS)));
                  }
               }
            }
            // TP buffer cap: SL must stay at least 1× ATR below TP (ATR-based, not fixed pips)
            double tpBuffer = (atr > 0) ? atr : (10.0 * pipVal);
            if(tp > 0 && suggestedSL > (tp - tpBuffer))
               suggestedSL = tp - tpBuffer;
            // Price cap: SL must not be at or above current price (MT4 rejects it)
            if(suggestedSL >= currentPrice) suggestedSL = currentPrice - pipVal;
            if(sl == 0 || sl < (suggestedSL - (0.5 * pipVal))) {  // SL still below suggested level by at least 0.5 pip
               if(AutoTrailStops && IsTradeAllowed()) {
                  Log(sym + " #" + IntegerToString(ticket) + " trail SL → " + DoubleToStr(suggestedSL, (int)MarketInfo(sym, MODE_DIGITS)));
                  AutoModifySL(ticket, suggestedSL);
               }
            }
         } else if(type == OP_SELL) {
            // Bias check: is H1 still bearish on this pair?
            string trBase = StringSubstr(sym, 0, 3), trQuote = StringSubstr(sym, 3, 3);
            int h1TrailDir = GetDirectionFromBiasLabels(GetBiasLabel(trBase), GetBiasLabel(trQuote));
            bool biasLost = (h1TrailDir != -1); // neutral or flipped bullish

            // Stage 1: breakeven lock (profit >= 1× SL dist)
            suggestedSL = entry - (BreakEvenBufferPips * pipVal);
            // Stage 2: partial lock — lock TrailStage2LockPct% of current profit (profit >= TrailStage2Mult× SL dist)
            if(profitPips >= (effectiveTrailTrigger * TrailStage2Mult)) {
               double stage2SL = entry - (profitPips * (TrailStage2LockPct / 100.0) * pipVal);
               if(stage2SL < suggestedSL) suggestedSL = stage2SL;
            }
            // Stage 3: ATR trail — follows price continuously (profit >= 2× SL dist)
            if(UseATRTrailSuggestion && atr > 0 && profitPips >= (effectiveTrailTrigger * 2.0)) {
               double atrSL = currentPrice + (ATRTrailMult * atr);
               if(atrSL < suggestedSL) suggestedSL = atrSL;
            }
            // Stage 4: tight ATR trail — tighter lock at big profits (profit >= 3× SL dist)
            if(UseATRTrailSuggestion && atr > 0 && profitPips >= (effectiveTrailTrigger * 3.0)) {
               double atrSL4 = currentPrice + (ATRTrailMultTight * atr);
               if(atrSL4 < suggestedSL) suggestedSL = atrSL4;
            }
            // Bias lost: force tight ATR trail immediately regardless of profit stage — protect gains
            if(biasLost && UseATRTrailSuggestion && atr > 0) {
               double biasLostSL = currentPrice + (ATRTrailMultTight * atr);
               if(biasLostSL < suggestedSL) {
                  suggestedSL = biasLostSL;
                  Log(sym + " #" + IntegerToString(ticket) + " [BiasLost] H1 neutral/bullish — forcing tight trail SL");
               }
            }
            // Auto extend TP when price is near target (repeats each time price approaches new TP)
            // Uses IsTradeAllowed() directly — AutoExtendTP=true is explicit consent, ManualModeOnly must not block it
            if(AutoExtendTP && IsTradeAllowed() && tp > 0 && pipVal > 0) {
               // Only extend if H1 bias still agrees with trade direction
               string tpBase = StringSubstr(sym, 0, 3), tpQuote = StringSubstr(sym, 3, 3);
               int h1ExtDir = GetDirectionFromBiasLabels(GetBiasLabel(tpBase), GetBiasLabel(tpQuote));
               if(h1ExtDir == -1) { // H1 still bearish — safe to extend SELL TP
                  double tpDistPips = MathAbs(tp - entry) / pipVal; // current TP dist (grows with each extension)
                  double remainingToTP = (currentPrice - tp) / pipVal;
                  if(tpDistPips > 0 && remainingToTP >= 0 && remainingToTP <= (tpDistPips * (TPExtendNearPct / 100.0))) {
                     // Snap to next S/R level below current TP — avoids landing inside support
                     double srExt[]; int srExtCnt = FindSRLevelsSym(sym, srExt);
                     double newTP = 0;
                     for(int sri = srExtCnt - 1; sri >= 0; sri--) {
                        if(srExt[sri] < tp - pipVal) { newTP = srExt[sri]; break; }
                     }
                     // Fallback: flat ATR extend if no S/R found beyond current TP
                     if(newTP <= 0 || newTP >= tp) newTP = tp - ((atr > 0) ? (ATRTrailMult * atr) : (20.0 * pipVal));
                     AutoModifyTP(ticket, NormalizeDouble(newTP, (int)MarketInfo(sym, MODE_DIGITS)));
                  }
               }
            }
            // TP buffer cap: SL must stay at least 1× ATR above TP (ATR-based, not fixed pips)
            double tpBuffer = (atr > 0) ? atr : (10.0 * pipVal);
            if(tp > 0 && suggestedSL < (tp + tpBuffer))
               suggestedSL = tp + tpBuffer;
            // Price cap: SL must not be at or below current price (MT4 rejects it)
            if(suggestedSL <= currentPrice) suggestedSL = currentPrice + pipVal;
            if(sl == 0 || sl > (suggestedSL + (0.5 * pipVal))) {  // SL still above suggested level by at least 0.5 pip
               if(AutoTrailStops && IsTradeAllowed()) {
                  Log(sym + " #" + IntegerToString(ticket) + " trail SL → " + DoubleToStr(suggestedSL, (int)MarketInfo(sym, MODE_DIGITS)));
                  AutoModifySL(ticket, suggestedSL);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+

// ── Recovery Hedge System ────────────────────────────────────────
// Opens opposite trades with TP at nearest S/R to chip away losses.

// Find nearest S/R level in the recovery direction for TP placement
double FindRecoveryTP(string sym, int recoveryType, double entryPrice) {
   double srLevels[];
   int srCount = FindSRLevelsSym(sym, srLevels);
   double pipVal = PipValue(sym);
   int digits = (int)MarketInfo(sym, MODE_DIGITS);
   double minTPDist = RecoveryMinTP_Pips * pipVal;
   double bestTP = 0;

   if(recoveryType == OP_BUY) {
      // Recovery BUY → TP above entry, find nearest S/R above
      double bestDist = 999999;
      for(int i = 0; i < srCount; i++) {
         double dist = srLevels[i] - entryPrice;
         if(dist >= minTPDist && dist < bestDist) {
            bestDist = dist;
            bestTP = srLevels[i];
         }
      }
      // Fallback: if no S/R found, use minimum TP
      if(bestTP == 0)
         bestTP = NormalizeDouble(entryPrice + minTPDist, digits);
   } else {
      // Recovery SELL → TP below entry, find nearest S/R below
      double bestDist = 999999;
      for(int i = 0; i < srCount; i++) {
         double dist = entryPrice - srLevels[i];
         if(dist >= minTPDist && dist < bestDist) {
            bestDist = dist;
            bestTP = srLevels[i];
         }
      }
      // Fallback: if no S/R found, use minimum TP
      if(bestTP == 0)
         bestTP = NormalizeDouble(entryPrice - minTPDist, digits);
   }
   return NormalizeDouble(bestTP, digits);
}

// Open a recovery hedge trade against a losing parent
bool OpenRecoveryHedge(int parentTicket, string sym, int parentType, double parentLots) {
   if(!IsTradeAllowed()) return false;

   int recoveryType = (parentType == OP_BUY) ? OP_SELL : OP_BUY;
   int digits = (int)MarketInfo(sym, MODE_DIGITS);
   int slippage = SlippageToPoints(sym, AutoSlippagePips);
   double price = (recoveryType == OP_BUY) ? MarketInfo(sym, MODE_ASK) : MarketInfo(sym, MODE_BID);
   price = NormalizeDouble(price, digits);

   double tp = FindRecoveryTP(sym, recoveryType, price);

   int rIdx = GetOrCreateRecovery(parentTicket, sym);
   if(rIdx < 0) return false;
   if(g_recovery[rIdx].recoveryCount >= 32) return false;  // practical cap

   color clr = (recoveryType == OP_BUY) ? clrDodgerBlue : clrOrangeRed;
   string comment = RecoveryComment + "_" + IntegerToString(parentTicket);

   int tk = OrderSend(sym, recoveryType, parentLots, price, slippage, 0, tp, comment, AutoMagicNumber, 0, clr);
   if(tk > 0) {
      g_recovery[rIdx].recoveryTickets[g_recovery[rIdx].recoveryCount] = tk;
      g_recovery[rIdx].recoveryCount++;

      double pipVal = PipValue(sym);
      double tpPips = (pipVal > 0) ? MathAbs(tp - price) / pipVal : 0;

      // Remove SL from parent trade — recovery hedge is now the defense
      bool slRemoved = false;
      if(OrderSelect(parentTicket, SELECT_BY_TICKET, MODE_TRADES) && OrderCloseTime() == 0) {
         if(OrderStopLoss() != 0) {
            for(int slTry = 0; slTry < 3; slTry++) {
               if(OrderModify(parentTicket, OrderOpenPrice(), 0, OrderTakeProfit(), 0, clrAqua)) {
                  slRemoved = true;
                  Log(sym + " [RECOVERY] Removed SL from parent #" + IntegerToString(parentTicket) + " — recovery hedge is defense");
                  break;
               }
               int modErr = GetLastError();
               Log(sym + " [RECOVERY] SL removal attempt " + IntegerToString(slTry+1) + " failed err=" + IntegerToString(modErr));
               ResetLastError();
               Sleep(200);
               if(!OrderSelect(parentTicket, SELECT_BY_TICKET, MODE_TRADES)) break;
            }
            if(!slRemoved)
               Log(sym + " [RECOVERY WARNING] Could not remove SL from parent #" + IntegerToString(parentTicket) + " after 3 attempts");
         }
      }

      Log(sym + " [RECOVERY HEDGE #" + IntegerToString(g_recovery[rIdx].recoveryCount) + "] " +
          (recoveryType==OP_BUY?"BUY":"SELL") + " " + DoubleToStrClean(parentLots, 2) + "L @ " +
          DoubleToString(price, digits) + " TP:" + DoubleToString(tp, digits) +
          " (" + DoubleToStrClean(tpPips, 0) + "p) | Parent #" + IntegerToString(parentTicket));

      // Telegram alert
      string tgMsg = "<b>[RECOVERY HEDGE #" + IntegerToString(g_recovery[rIdx].recoveryCount) + "]</b>" + TGTag() + "\n";
      tgMsg += sym + " | " + (recoveryType==OP_BUY?"BUY":"SELL") + " " + DoubleToStrClean(parentLots, 2) + " lots\n";
      tgMsg += "Entry: " + DoubleToString(price, digits) + "\n";
      tgMsg += "TP: " + DoubleToString(tp, digits) + " (" + DoubleToStrClean(tpPips, 0) + " pips)\n";
      tgMsg += "Parent: #" + IntegerToString(parentTicket) + (slRemoved ? " (SL removed)" : "");
      SendTelegram(tgMsg);
      MarkAlertBadge();
      return true;
   } else {
      Log(sym + " [RECOVERY HEDGE FAILED] err=" + IntegerToString(GetLastError()) + " parent #" + IntegerToString(parentTicket));
      ResetLastError();
      return false;
   }
}

// Track recovery hedge TP hits — update totalRecoveredPips/Profit
void TrackRecoveryTPHits() {
   for(int i = 0; i < g_recoveryCount; i++) {
      for(int j = 0; j < g_recovery[i].recoveryCount; j++) {
         int rtk = g_recovery[i].recoveryTickets[j];
         if(rtk <= 0) continue;
         // Check if this recovery ticket is closed (TP hit)
         if(OrderSelect(rtk, SELECT_BY_TICKET, MODE_HISTORY) && OrderCloseTime() > 0) {
            // Already closed — tally if not already counted (ticket > 0 means not yet tallied)
            double rProfit = OrderProfit() + OrderSwap() + OrderCommission();
            double rPipVal = PipValue(OrderSymbol());
            double rPips = 0;
            if(rPipVal > 0) {
               int rtype = OrderType();
               rPips = (rtype == OP_BUY) ? (OrderClosePrice() - OrderOpenPrice()) / rPipVal
                                          : (OrderOpenPrice() - OrderClosePrice()) / rPipVal;
            }
            g_recovery[i].totalRecoveredPips += rPips;
            g_recovery[i].totalRecoveredProfit += rProfit;
            g_recovery[i].recoveryTickets[j] = 0;  // mark as tallied (0 = done)

            Log(g_recovery[i].symbol + " [RECOVERY TP HIT] #" + IntegerToString(rtk) +
                " | " + DoubleToStrClean(rPips, 1) + "p ($" + DoubleToStrClean(rProfit, 2) + ")" +
                " | Total recovered: " + DoubleToStrClean(g_recovery[i].totalRecoveredPips, 1) + "p");

            // Telegram alert
            string tgMsg = "<b>[RECOVERY TP HIT]</b>" + TGTag() + "\n";
            tgMsg += g_recovery[i].symbol + " | #" + IntegerToString(rtk) + "\n";
            tgMsg += "Recovered: " + DoubleToStrClean(rPips, 1) + " pips ($" + DoubleToStrClean(rProfit, 2) + ")\n";
            tgMsg += "Total recovered: " + DoubleToStrClean(g_recovery[i].totalRecoveredPips, 1) + " pips ($" +
                     DoubleToStrClean(g_recovery[i].totalRecoveredProfit, 2) + ")";
            SendTelegram(tgMsg);
            MarkAlertBadge();
         }
      }
   }
}

// (CloseRecoveryHedgesForSymbol removed — recovery hedges race to TP, no bias-based closing)

// Master recovery hedge manager (called from OnTick)
void ManageRecoveryHedge() {
   if(!RecoveryHedgeEnabled) return;
   if(!IsTradeAllowed()) return;

   datetime now = TimeCurrent();
   // Check every 5 seconds
   if(g_lastRecoveryCheck != 0 && (now - g_lastRecoveryCheck) < 5) return;
   g_lastRecoveryCheck = now;

   // Step 1: Track TP hits on existing recovery hedges
   TrackRecoveryTPHits();

   // Step 2: Clean up closed parent records
   CleanRecoveryHedges();

   // Step 3: Scan all open trades for recovery hedge triggers
   int totalOrders = OrdersTotal();
   for(int i = totalOrders - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;

      string sym = OrderSymbol();
      int ticket = OrderTicket();
      double lots = OrderLots();
      double entry = OrderOpenPrice();
      double pipVal = PipValue(sym);
      if(pipVal <= 0) continue;

      // Recovery hedges CAN become parents — recursive recovery.
      // A surviving recovery hedge that loses -30 pips gets its own recovery hedge.
      // Only skip if this ticket already HAS an active (open) recovery hedge running.

      // Calculate floating P/L
      double currentPrice = (type == OP_BUY) ? MarketInfo(sym, MODE_BID) : MarketInfo(sym, MODE_ASK);
      double floatingPips = (type == OP_BUY) ? (currentPrice - entry) / pipVal
                                              : (entry - currentPrice) / pipVal;

      // Only trigger on losing trades
      if(floatingPips >= 0) continue;
      double lossPips = MathAbs(floatingPips); // positive number

      // Get or check existing recovery record
      int rIdx = GetRecoveryIndex(ticket);
      double nextTrigger = GetDeepestRecoveryLevel(rIdx);

      // Check if loss has reached the next trigger level
      if(lossPips >= nextTrigger) {
         // Don't open if there's already an open recovery hedge for this parent
         // (wait for current one to TP or get closed before opening next)
         if(rIdx >= 0 && CountOpenRecoveryHedges(rIdx) > 0) continue;

         // Check bias — only open recovery if bias is AGAINST the original trade
         // Either H1 OR M15 bias flip/neutral is enough to trigger recovery hedge
         string base = StringSubstr(sym, 0, 3);
         string quote = StringSubstr(sym, 3, 3);
         int h1Dir  = GetDirectionFromBiasLabels(GetBiasLabel(base), GetBiasLabel(quote));
         int m15Dir = GetDirectionFromBiasLabels(GetBiasLabelLow(base), GetBiasLabelLow(quote));
         int tradeDir = (type == OP_BUY) ? 1 : -1;

         // Open recovery if H1 OR M15 bias is against or neutral (not aligned)
         // Both must still be aligned to skip — if either flipped, hedge now
         if(h1Dir == tradeDir && m15Dir == tradeDir) continue;

         OpenRecoveryHedge(ticket, sym, type, lots);
      }
   }

   // Step 4: NO bias-based closing of recovery hedges.
   // Once open, recovery hedges race to TP against the original/parent trade.
   // Paunahan lang mag-TP — walang bias intervention.
}

//| PENDING ORDER HEALTH CHECK - Auto-cancel invalid pending orders |
//+------------------------------------------------------------------+
void CheckPendingOrderHealth() {
   int healthCheckSeconds = (int)MathMax(10, PendingHealthCheckSeconds);
   if(TimeCurrent() - lastPendingHealthCheck < healthCheckSeconds) return;
   lastPendingHealthCheck = TimeCurrent();

   int totalOrders = OrdersTotal();
   if(totalOrders == 0) return;

   for(int i = totalOrders - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;

      int ticket = OrderTicket();
      int type = OrderType();
      if(type != OP_BUYLIMIT && type != OP_BUYSTOP && type != OP_SELLLIMIT && type != OP_SELLSTOP) continue;

      string sym = OrderSymbol();
      double entry = OrderOpenPrice();
      double pipVal = PipValue(sym);
      double currentPrice = (type == OP_BUYLIMIT || type == OP_BUYSTOP) ? MarketInfo(sym, MODE_ASK) : MarketInfo(sym, MODE_BID);
      double distPips = (pipVal > 0) ? (MathAbs(currentPrice - entry) / pipVal) : 0;

      int orderDir = (type == OP_BUYLIMIT || type == OP_BUYSTOP) ? 1 : -1;
      datetime now = TimeCurrent();

      bool cancel = false;
      string reasons = "";

      // --- H1 + M15 bias check (immediate — no proximity gate) ---
      {
         string base  = StringSubstr(sym, 0, 3);
         string quote = StringSubstr(sym, 3, 3);
         string baseBias  = GetBiasLabel(base);
         string quoteBias = GetBiasLabel(quote);
         bool h1Inv = (baseBias == "INV" || quoteBias == "INV");
         int h1Dir  = GetDirectionFromBiasLabels(baseBias, quoteBias);

         if(h1Inv) {
            cancel = true;
            reasons += "- H1 bias INVALID (conflicting TFs)\n";
         } else if(h1Dir != orderDir) {
            cancel = true;
            string dirLabel = (h1Dir == 0) ? "neutral" : "opposite";
            reasons += "- H1 bias " + dirLabel + " vs order direction\n";
         } else if(PendingRequireM15Align) {
            // Identify order type from comment tag (set when EA placed the order):
            //   "Fib"      → fib-level order → requires M15 alignment to stay
            //   "SwingExt" → swing extreme   → H1 only, M15 ignored
            //   unknown/manual              → default: H1 only (safe — don't over-cancel)
            string oComment  = OrderComment();
            bool   isFibOrder = (StringFind(oComment, "Fib") >= 0);

            // Fib-level orders: cancel if M15 lost alignment
            // Swing extreme or unknown orders: H1 is enough — never cancel on M15 alone
            if(isFibOrder) {
               int m15Dir = GetDirectionFromBiasLabels(GetBiasLabelLow(base), GetBiasLabelLow(quote));
               if(m15Dir != orderDir) {
                  cancel = true;
                  string m15Label = (m15Dir == 0) ? "neutral" : "opposite";
                  reasons += "- Fib order: M15 bias lost alignment (" + m15Label + ")\n";
               }
            }
         }
      }


      if(AutoCancelPendingOnWideSpread && !IsSpreadOK(sym)) {
         cancel = true;
         reasons += "- Spread too high\n";
      }

      // JPY pairs naturally move more pips intraday — allow 2× the stale threshold
      double effectiveStaleMax = (IsJPYPair(sym) ? PendingStaleMaxPips * 2.0 : PendingStaleMaxPips);
      if(AutoCancelPendingOnFarPrice && PendingStaleMaxPips > 0 && distPips > effectiveStaleMax) {
         cancel = true;
         string staleSuffix = IsJPYPair(sym) ? " (JPY 2x=" + DoubleToStrClean(effectiveStaleMax, 0) + "p)" : "";
         reasons += "- Price too far from entry" + staleSuffix + "\n";
      }

      if(!cancel) continue;

      // Bias-flip cancel uses IsTradeAllowed() only — defensive action,
      // does not require EnableAutoTrading or ManualModeOnly=false.
      // This covers both H1 flip AND M15 flip (for fib orders) — both are bias-driven.
      // Spread/news/far-price cancels still respect AutoTradingActive().
      bool biasCancel = (StringFind(reasons, "H1 bias") >= 0 || StringFind(reasons, "M15 bias") >= 0);
      if(biasCancel) {
         if(IsTradeAllowed()) {
            Log(sym + " #" + IntegerToString(ticket) + " pending cancel: " + reasons);
            AutoCancelPending(ticket);
         }
      } else if(AutoTradingActive()) {
         Log(sym + " #" + IntegerToString(ticket) + " pending cancel: " + reasons);
         AutoCancelPending(ticket);
      }

   }
}

//+------------------------------------------------------------------+
//| PENDING ORDER EXPIRATION - Alert on Stale Orders                 |
//+------------------------------------------------------------------+
// Helper: pure time-window check without side effects
bool IsInNewsWindow(int startHourGMT, int startMinGMT, int windowMins) {
   datetime nowG = TimeGMT();
   string d = TimeToString(nowG, TIME_DATE);
   datetime start = StringToTime(d + " " + StringFormat("%02d:%02d", startHourGMT, startMinGMT));
   datetime end = start + windowMins * 60;
   return (nowG >= start && nowG <= end);
}

bool IsNewsTime() {
   if(!NewsFilterEnabled) { currentNewsEvent = ""; return false; }

   // Keep existing block-until behavior, but only as a cooldown once triggered
   if(TimeCurrent() < newsBlockUntil) return true;

   // Live news feed (preferred when enabled)
   if(UseLiveNewsFeed) {
      FetchLiveNews();
      if(liveNewsLoaded && NewsCount > 0) {
         datetime now = TimeCurrent();
         for(int i = 0; i < NewsCount; i++) {
            datetime evt = UpcomingNews[i].time;
            if(evt <= 0) continue;
            datetime start = evt - (NewsBlockBeforeMins * 60);
            datetime end = evt + (NewsBlockAfterMins * 60);
            if(now >= start && now <= end) {
               string cur = UpcomingNews[i].currency;
               string title = UpcomingNews[i].event;
               currentNewsEvent = cur + " News" + (title != "" ? " (" + title + ")" : "");
               newsBlockUntil = end;
               return true;
            }
         }
      }
   }

   int dow = TimeDayOfWeek(TimeGMT());
   int dom = TimeDay(TimeCurrent());

   // IMPORTANT: newsBlockUntil is only pushed FORWARD (never reset on each call).
   // This prevents repeated IsNewsTime() calls from continuously extending the block.
   // Each window sets a fixed end time; once that passes, the block expires naturally.

   // AUD 01:30 -> window 01:00-02:00, block until 02:00
   if(IsInNewsWindow(1, 0, 60)) {
      datetime _end = StringToTime(TimeToString(TimeGMT(), TIME_DATE) + " 02:00");
      if(_end > newsBlockUntil) newsBlockUntil = _end;
      currentNewsEvent = "AUD News (RBA/Employment)"; return true;
   }
   // EUR 07:00 -> window 06:30-07:30, block until 07:30
   if(IsInNewsWindow(6, 30, 60)) {
      datetime _end = StringToTime(TimeToString(TimeGMT(), TIME_DATE) + " 07:30");
      if(_end > newsBlockUntil) newsBlockUntil = _end;
      currentNewsEvent = "EUR News (ECB/German Data)"; return true;
   }
   // GBP 09:30 -> window 09:00-10:00, block until 10:00
   if(IsInNewsWindow(9, 0, 60)) {
      datetime _end = StringToTime(TimeToString(TimeGMT(), TIME_DATE) + " 10:00");
      if(_end > newsBlockUntil) newsBlockUntil = _end;
      currentNewsEvent = "GBP News (BOE/UK Data)"; return true;
   }
   // USD 13:30 -> window 13:00-14:00, block until 14:00
   if(IsInNewsWindow(13, 0, 60)) {
      datetime _end = StringToTime(TimeToString(TimeGMT(), TIME_DATE) + " 14:00");
      if(_end > newsBlockUntil) newsBlockUntil = _end;
      currentNewsEvent = "USD News (CPI/Retail/Claims)"; return true;
   }
   // FOMC Wed ~19:00 -> window 18:30-19:30, block until 19:30
   if(dow == 3 && IsInNewsWindow(18, 30, 60)) {
      datetime _end = StringToTime(TimeToString(TimeGMT(), TIME_DATE) + " 19:30");
      if(_end > newsBlockUntil) newsBlockUntil = _end;
      currentNewsEvent = "FOMC Decision (Check Calendar)"; return true;
   }
   // First Friday NFP 13:30 -> window 13:00-14:00, block until 14:00
   if(dow == 5 && dom <= 7 && IsInNewsWindow(13, 0, 60)) {
      datetime _end = StringToTime(TimeToString(TimeGMT(), TIME_DATE) + " 14:00");
      if(_end > newsBlockUntil) newsBlockUntil = _end;
      currentNewsEvent = "NFP (Non-Farm Payrolls)"; return true;
   }

   currentNewsEvent = "";
   return false;
}

void CheckNewsAlerts() {
   // Check every hour
   if(TimeCurrent() - lastNewsCheck < 3600) return;
   lastNewsCheck = TimeCurrent();
   
   int dayOfWeek = TimeDayOfWeek(TimeCurrent());
   int hour = TimeHour(TimeGMT());
   int day = TimeDay(TimeCurrent());
   
   string newsAlert = "";
   
   // NFP - First Friday at 13:30 GMT
   if(dayOfWeek == 5 && day <= 7) {
      if(hour == 12) newsAlert = "NFP (Non-Farm Payrolls) in 1.5 hours";
   }
   
   // FOMC - Wednesday around 19:00 GMT
   if(dayOfWeek == 3 && hour == 17) {
      newsAlert = "Potential FOMC Decision (check calendar)";
   }
   
   // ECB - Thursday around 12:45 GMT
   if(dayOfWeek == 4 && hour == 11) {
      newsAlert = "Potential ECB Decision (check calendar)";
   }
   
   // CPI - Usually Tuesday/Wednesday 13:30 GMT
   if((dayOfWeek == 2 || dayOfWeek == 3) && hour == 12) {
      newsAlert = "Potential CPI Release (check calendar)";
   }
   
   if(newsAlert != "") {
      SendNewsAlert(newsAlert);
   }
}

void SendNewsAlert(string newsEvent) {
   string msg = "<b>! HIGH IMPACT NEWS ALERT</b>" + TGTag() + "\n\n";
   msg += "<b>Event:</b> " + newsEvent + "\n";
   msg += "<b>Time:</b> " + TimeToString(TimeCurrent(), TIME_MINUTES) + " GMT\n\n";
   
   // Check if user has open positions or pending orders
   int totalOrders = OrdersTotal();
   int marketCount = 0;
   int pendingCount = 0;
   string marketOrders = "";
   string pendingOrders = "";
   
   if(totalOrders > 0) {
      msg += "<b>YOU HAVE ACTIVE TRADES!</b>\n\n";
      
      for(int i = 0; i < totalOrders; i++) {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
         
         int ticket = OrderTicket();
         string sym = OrderSymbol();
         int type = OrderType();
         double entry = OrderOpenPrice();
         double sl = OrderStopLoss();
         double lots = OrderLots();
         int digits = (int)MarketInfo(sym, MODE_DIGITS);
         double pipVal = PipValue(sym);
         double minLot = MarketInfo(sym, MODE_MINLOT);
         
         // MARKET ORDERS (active trades)
         if(type == OP_BUY || type == OP_SELL) {
            marketCount++;
            string direction = (type == OP_BUY) ? "BUY" : "SELL";
            double currentPrice = (type == OP_BUY) ? MarketInfo(sym, MODE_BID) : MarketInfo(sym, MODE_ASK);
            
            // Calculate P&L
            double profitPips = 0;
            if(type == OP_BUY) {
               profitPips = (currentPrice - entry) / pipVal;
            } else {
               profitPips = (entry - currentPrice) / pipVal;
            }
            
            string plStr = (profitPips >= 0 ? "+" : "") + DoubleToStrClean(profitPips, 0) + "p";
            
            // Suggest action based on P&L
            string action = "";
            if(profitPips >= 20) {
               action = "CLOSE NOW at " + DoubleToString(currentPrice, digits) + " (" + plStr + ")";
            } else if(profitPips >= 5) {
               double suggestedSL = (type == OP_BUY) ? entry + (5 * pipVal) : entry - (5 * pipVal);
               action = "Move SL to " + DoubleToString(suggestedSL, digits) + " (breakeven)";
            } else if(profitPips < -15) {
               action = "CLOSE NOW to limit loss (" + plStr + ")";
            } else {
               action = "Close at breakeven: " + DoubleToString(entry, digits);
            }
            
            marketOrders += IntegerToString(marketCount) + ". <code>" + sym + " " + direction + "</code> #" + IntegerToString(ticket) + "\n";
            marketOrders += "   P/L: <b>" + plStr + "</b> | Action: " + action + "\n";
            marketOrders += "   Lot: " + DoubleToStrClean(lots, 2);
            if(lots > 0 && lots < minLot) marketOrders += " (below min " + DoubleToStrClean(minLot, 2) + ")";
            marketOrders += "\n\n";
         }
         
         // PENDING ORDERS
         else if(type == OP_BUYLIMIT || type == OP_SELLLIMIT || type == OP_BUYSTOP || type == OP_SELLSTOP) {
            pendingCount++;
            string orderType = "";
            if(type == OP_BUYLIMIT) orderType = "BUY LIMIT";
            else if(type == OP_SELLLIMIT) orderType = "SELL LIMIT";
            else if(type == OP_BUYSTOP) orderType = "BUY STOP";
            else orderType = "SELL STOP";
            
            pendingOrders += IntegerToString(pendingCount) + ". <code>" + sym + " " + orderType + "</code> #" + IntegerToString(ticket) + "\n";
            pendingOrders += "   Entry: " + DoubleToString(entry, digits) + " | Action: <b>CANCEL</b> (volatility risk)\n";
            pendingOrders += "   Lot: " + DoubleToStrClean(lots, 2);
            if(lots > 0 && lots < minLot) pendingOrders += " (below min " + DoubleToStrClean(minLot, 2) + ")";
            pendingOrders += "\n\n";
         }
      }
      
      // Add market orders to message
      if(marketCount > 0) {
         msg += "<b>OPEN POSITIONS (" + IntegerToString(marketCount) + "):</b>\n";
         msg += marketOrders;
      }
      
      // Add pending orders to message
      if(pendingCount > 0) {
         msg += "<b>PENDING ORDERS (" + IntegerToString(pendingCount) + "):</b>\n";
         msg += pendingOrders;
      }
      
   } else {
      msg += "<b>STATUS:</b> No open trades\n\n";
      msg += "! Avoid new entries until news passes\n\n";
   }
   
   msg += "\n--- WAIT FOR VOLATILITY TO SETTLE ---\n";
   msg += "Affected: " + newsEvent + "\n";
   msg += "ACTION: Avoid new trades; manage open positions per plan.";
   
   MarkAlertBadge();
   SendTelegram(msg);

   // Auto actions during news
   if(AutoTradingActive()) {
      if(AutoCancelPendingOnNews) {
         for(int i = OrdersTotal() - 1; i >= 0; i--) {
            if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
            int type = OrderType();
            if(type == OP_BUYLIMIT || type == OP_BUYSTOP || type == OP_SELLLIMIT || type == OP_SELLSTOP) {
               AutoCancelPending(OrderTicket());
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| SESSION ALERT                                                     |
//+------------------------------------------------------------------+
datetime lastSessionAlert = 0;

void CheckSessionAlert() {
   int hour = TimeHour(TimeGMT());
   datetime today = StringToTime(TimeToString(TimeGMT(), TIME_DATE));
   
   // London open
   if(UseLondonSession && hour == LondonStartHour) {
      if(lastSessionAlert < today + LondonStartHour * 3600) {
         lastSessionAlert = TimeCurrent();
         SendSessionAlert("LONDON");
      }
   }
   
   // NY open
   if(UseNYSession && hour == NYStartHour) {
      if(lastSessionAlert < today + NYStartHour * 3600) {
         lastSessionAlert = TimeCurrent();
         SendSessionAlert("NEW YORK");
      }
   }
}

void SendSessionAlert(string session) {
   string msg = "<b>" + session + " SESSION OPEN</b>" + TGTag() + "\n";
   msg += "[TIME] " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + "\n\n";
   
   // Count active signals
   int buyCount = 0, sellCount = 0;
   string buyPairs = "", sellPairs = "";
   
   for(int i = 0; i < PairsCount; i++) {
      string sym = Pairs[i];
      int quality = GetSignalQuality(sym);
      if(quality < 2) continue;
      
      int dir = GetTradeDirection(sym);
      if(dir == 1) { buyCount++; buyPairs += sym + " " + GetQualityStars(quality) + ", "; }
      if(dir == -1) { sellCount++; sellPairs += sym + " " + GetQualityStars(quality) + ", "; }
   }
   
   msg += "Active Signals:\n";
   msg += "BUY: " + (buyCount > 0 ? buyPairs : "None") + "\n";
   msg += "SELL: " + (sellCount > 0 ? sellPairs : "None") + "\n";
   if(GetNewsNowCached()) msg += "\nNEWS FILTER ACTIVE - No new trades\n";
   msg += "\nACTION: Review signals and wait for entry rules.\n";
   msg += "Good trading!";
   
   MarkAlertBadge();
   SendTelegram(msg);
}

//+------------------------------------------------------------------+
//| TEST ALERT                                                        |
//+------------------------------------------------------------------+
void SendTestAlert() {
   string msg = "<b>SWINGMASTER PRO - TEST</b>" + TGTag() + "\n\n";
   msg += "<b>Time:</b> " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + "\n";
   msg += "<b>Status:</b> Connected OK\n";
   msg += "<b>Chart:</b> " + Symbol() + " " + PeriodToStr(Period()) + "\n";
   msg += "<b>Pairs:</b> " + IntegerToString(PairsCount) + "\n";
   
   datetime nextH1 = iTime(Symbol(), PERIOD_H1, 0) + 3600;
   msg += "Next scan: " + TimeToString(nextH1, TIME_MINUTES);
   msg += "\nACTION: None.";
   
   SendTelegram(msg);
}

string PeriodToStr(int period) {
   switch(period) {
      case PERIOD_M1: return "M1";
      case PERIOD_M5: return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1: return "H1";
      case PERIOD_H4: return "H4";
      case PERIOD_D1: return "D1";
      case PERIOD_W1: return "W1";
      case PERIOD_MN1: return "MN1";
   }
   return "??";
}

//+------------------------------------------------------------------+
//| CHART PANEL                                                       |
//+------------------------------------------------------------------+
void CreateChartPanel() {
   if(!ShowChartPanel) return;
   
   int x = 10, y = 30;
   int width = 620, height = 560;
   
   // Background
   ObjectCreate(0, "PanelBG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "PanelBG", OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, "PanelBG", OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, "PanelBG", OBJPROP_XSIZE, width);
   ObjectSetInteger(0, "PanelBG", OBJPROP_YSIZE, height);
   ObjectSetInteger(0, "PanelBG", OBJPROP_BGCOLOR, PanelColor);
   ObjectSetInteger(0, "PanelBG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   
   // Title
   CreateLabel("PanelTitle", "SwingMaster Pro v2.0", x + 10, y + 10, TextColor, 10);
   ChartRedraw();
}

void CreateLabel(string name, string text, int x, int y, color clr, int size, string font = "Arial") {
   if(ObjectFind(0, name) == -1) {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, name, OBJPROP_FONT, font);
}

void UpdateChartPanel() {
   if(!ShowChartPanel) return;
   
   int x = 20, y = 55;
   int lineHeight = 15;
   int maxChars = 0;

   // Mode
   string modeText = "Mode: MANUAL";
   color modeColor = clrYellow;
   bool autoEnabled = AutoTradingEnabled();
   bool autoActive = AutoTradingActive();
   if(autoEnabled) {
      modeText = autoActive ? "Mode: AUTO" : "Mode: AUTO (OFF)";
      modeColor = autoActive ? clrLime : clrOrange;
   }
   string mgmtText = autoActive ? "TrailSL:FORCED"
                                : "TrailSL:" + string(AutoTrailStops ? "ON" : "OFF");
   modeText += " | " + mgmtText;
   maxChars = MathMax(maxChars, StringLen(modeText));
   CreateLabel("LblMode", modeText, x, y, modeColor, 9, "Arial Black");
   y += lineHeight;

   // Auto-off reason (when enabled but not active)
   if(autoEnabled && !autoActive) {
      string reason = GetAutoOffReason();
      CreateLabel("LblAutoReason", "Reason: " + reason, x, y, clrOrange, 8);
      y += lineHeight;
   } else {
      ObjectDelete(0, "LblAutoReason");
   }
   
   // Account info
   CreateLabel("LblBalance", "Balance: $" + DoubleToStrClean(AccountBalance(), 2), x, y, TextColor, 9);
   y += lineHeight;
   
   // Today's performance
   double todayPL = AccountEquity() - dayStartBalance;
   double todayPercent = (dayStartBalance > 0) ? (todayPL / dayStartBalance) * 100 : 0;
   string plSign = (todayPL >= 0 ? "+" : "");
   color plColor = (todayPL >= 0 ? clrLime : clrRed);
   string todayStats = "Today: " + plSign + "$" + DoubleToStrClean(todayPL, 2) + " (" + plSign + DoubleToStrClean(todayPercent, 1) + "%)";
   maxChars = MathMax(maxChars, StringLen(todayStats));
   CreateLabel("LblToday", todayStats, x, y, plColor, 9);
   y += lineHeight;
   
   CreateLabel("LblEquity", "Equity: $" + DoubleToStrClean(AccountEquity(), 2), x, y, TextColor, 9);
   y += lineHeight + 5;
   
   // Risk
   string riskText;
   color riskLblColor = TextColor;
   if(currentRiskTrackedTrades == 0 && currentRiskNoSLTrades > 0) {
      // All open trades have no SL (or tick data unavailable) — risk is undefined, NOT zero
      riskText = "Risk: ??% / " + DoubleToStrClean(MaxDailyRiskPercent, 1) + "% | NoSL: " + IntegerToString(currentRiskNoSLTrades);
      riskLblColor = clrOrange;
   } else {
      riskText = "Risk: " + DoubleToStrClean(currentRiskPercent, 1) + "% / " + DoubleToStrClean(MaxDailyRiskPercent, 1) + "%";
      if(currentRiskNoSLTrades > 0) riskText += " | NoSL: " + IntegerToString(currentRiskNoSLTrades);
   }
   CreateLabel("LblRisk", riskText, x, y, riskLblColor, 9);
   y += lineHeight;
   CreateLabel("LblStatus", "Status: " + GetRiskStatus(), x, y, 
               (GetRemainingRiskBudget() > 0.5 ? clrLime : clrOrange), 9);
   y += lineHeight;
   y += 5;
   
   // ─────────────────────────────────────────────────────────────────
   // ACTIVE ORDERS — open orders first, then pending sorted by distance
   // ─────────────────────────────────────────────────────────────────
   int totalOrders = OrdersTotal();
   int marketCount = 0, pendingCount = 0;
   double totalPips = 0.0;
   int ordRow = 0;
   int maxOrdRows = 50; // show all orders (up to 50)

   // Collect pending order tickets + distances for sorting
   int    pendTickets[50];
   double pendDists[50];
   int    pendCount2 = 0;
   ArrayInitialize(pendTickets, 0);
   ArrayInitialize(pendDists, 0.0);

   // First pass: count and collect pending
   for(int oi = 0; oi < totalOrders; oi++) {
      if(!OrderSelect(oi, SELECT_BY_POS, MODE_TRADES)) continue;
      int ct = OrderType();
      if(ct == OP_BUY || ct == OP_SELL) {
         marketCount++;
      } else {
         if(pendCount2 < 50) {
            double pPipV = PipValue(OrderSymbol());
            int    pDir  = (ct == OP_BUYLIMIT || ct == OP_BUYSTOP) ? 1 : -1;
            double pCur  = (pDir == 1) ? MarketInfo(OrderSymbol(), MODE_ASK) : MarketInfo(OrderSymbol(), MODE_BID);
            double pDist = (pPipV > 0) ? MathAbs(OrderOpenPrice() - pCur) / pPipV : 999999;
            pendTickets[pendCount2] = OrderTicket();
            pendDists[pendCount2]   = pDist;
            pendCount2++;
            pendingCount++;
         }
      }
   }

   // Bubble-sort pending by distance ascending (closest first)
   for(int si = 0; si < pendCount2 - 1; si++) {
      for(int sj = si + 1; sj < pendCount2; sj++) {
         if(pendDists[sj] < pendDists[si]) {
            double td = pendDists[si]; pendDists[si] = pendDists[sj]; pendDists[sj] = td;
            int    tt = pendTickets[si]; pendTickets[si] = pendTickets[sj]; pendTickets[sj] = tt;
         }
      }
   }

   if(totalOrders > 0) {
      string hdrStr = "-- ORDERS: " + IntegerToString(marketCount) + " open";
      if(pendingCount > 0) hdrStr += " | " + IntegerToString(pendingCount) + " pending";
      hdrStr += " --";
      CreateLabel("LblTrades", hdrStr, x, y, clrAqua, 8);
      y += lineHeight;

      int ordColWidth = 620; // 2-column layout for orders (v2.0: widened for RSI tags)
      int ordColCount = 2;
      int ordStartY   = y;
      int ordMaxRow   = 0; // track max row used per column
      // Pre-clear split-label suffixes so pending→open transitions don't leave ghost labels
      for(int ok = 0; ok < maxOrdRows; ok++) {
         ObjectDelete(0, "LblOrd" + IntegerToString(ok) + "B");
         ObjectDelete(0, "LblOrd" + IntegerToString(ok) + "D");
         ObjectDelete(0, "LblOrd" + IntegerToString(ok) + "S");
      }

      // Pass 1: open (market) orders
      for(int od = 0; od < totalOrders && ordRow < maxOrdRows; od++) {
         if(!OrderSelect(od, SELECT_BY_POS, MODE_TRADES)) continue;
         int    otype  = OrderType();
         if(otype != OP_BUY && otype != OP_SELL) continue;
         string osym   = OrderSymbol();
         int    oticket = OrderTicket();
         double olots  = OrderLots(), oentry = OrderOpenPrice();
         double osl    = OrderStopLoss(), otp = OrderTakeProfit();
         double oPipV  = PipValue(osym);

         string otag = (otype == OP_BUY ? "B" : "S");
         // Fib tag: if order was placed at a fib level, show [BF] or [SF]
         if(StringFind(OrderComment(), "Fib") >= 0)
            otag = (otype == OP_BUY ? "BF" : "SF");
         // Recovery hedge tag: show [RB] or [RS] for recovery hedge orders
         if(StringFind(OrderComment(), RecoveryComment) >= 0)
            otag = (otype == OP_BUY ? "RB" : "RS");
         double ocurPr = (otype == OP_BUY) ? MarketInfo(osym, MODE_BID) : MarketInfo(osym, MODE_ASK);
         double opips  = (oPipV > 0) ? ((otype == OP_BUY) ? (ocurPr - oentry) / oPipV : (oentry - ocurPr) / oPipV) : 0;
         totalPips += opips;
         string psign  = (opips >= 0) ? "+" : "";
         string slStr  = (osl > 0 && oPipV > 0) ? DoubleToStrClean(MathAbs(oentry - osl) / oPipV, 0) + "p" : "---";
         string tpStr  = (otp > 0 && oPipV > 0) ? DoubleToStrClean(MathAbs(otp - oentry) / oPipV, 0) + "p" : "---";
         string obase  = StringSubstr(osym, 0, 3), oquote = StringSubstr(osym, 3, 3);
         int    h1Dir  = GetDirectionFromBiasLabels(GetBiasLabel(obase), GetBiasLabel(oquote));
         int    m15Dir = GetDirectionFromBiasLabels(GetBiasLabelLow(obase), GetBiasLabelLow(oquote));
         string h1Tag  = (h1Dir == 1) ? "BUY" : (h1Dir == -1) ? "SEL" : "---";
         string m15Tag = (m15Dir == 1) ? "BUY" : (m15Dir == -1) ? "SEL" : "---";
         int    ordDir = (otype == OP_BUY) ? 1 : -1;
         color  lclr;
         if(h1Dir == ordDir && m15Dir == ordDir)      lclr = clrLime;
         else if(h1Dir == ordDir || m15Dir == ordDir) lclr = clrYellow;
         else                                         lclr = clrOrangeRed;

         double oEMA20   = iMA(osym, PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE, 1);
         double oATR     = iATR(osym, PERIOD_H1, ATRPeriod, 1);
         double oClose   = iClose(osym, PERIOD_H1, 1);
         double oRSI1    = iRSI(osym, PERIOD_H1, RSI_Period, PRICE_CLOSE, 1);
         double oRSI2    = iRSI(osym, PERIOD_H1, RSI_Period, PRICE_CLOSE, 2);
         double oEMADist = oClose - oEMA20;
         string oEMATag  = (oATR > 0 && MathAbs(oEMADist) <= oATR * EMA_PullbackATR) ? "~" : (oEMADist > 0 ? "^" : "v");
         string oRSIDir  = (oRSI1 > oRSI2) ? "^" : (oRSI1 < oRSI2) ? "v" : "-";
         double oEMA20m  = iMA(osym, PERIOD_M15, 20, 0, MODE_EMA, PRICE_CLOSE, 1);
         double oATRm    = iATR(osym, PERIOD_M15, ATRPeriod, 1);
         double oClosem  = iClose(osym, PERIOD_M15, 1);
         double oRSI1m   = iRSI(osym, PERIOD_M15, RSI_Period, PRICE_CLOSE, 1);
         double oRSI2m   = iRSI(osym, PERIOD_M15, RSI_Period, PRICE_CLOSE, 2);
         double oEMADistm= oClosem - oEMA20m;
         string oEMATagm = (oATRm > 0 && MathAbs(oEMADistm) <= oATRm * EMA_PullbackATR) ? "~" : (oEMADistm > 0 ? "^" : "v");
         string oRSIDirm = (oRSI1m > oRSI2m) ? "^" : (oRSI1m < oRSI2m) ? "v" : "-";
         string oRSITagH1 = GetRSIEntryTag(ordDir, oRSI1);
         string oRSITagM15 = GetRSIEntryTag(ordDir, oRSI1m);
         string oEMARSI  = "H1:EMA:" + oEMATag + " RSI:" + DoubleToStrClean(oRSI1, 0) + oRSIDir + " " + oRSITagH1 +
                           " | M15:EMA:" + oEMATagm + " RSI:" + DoubleToStrClean(oRSI1m, 0) + oRSIDirm + " " + oRSITagM15;

         string ol1 = TruncStr("[" + otag + "] " + osym + " " + DoubleToStrClean(olots, 2) + "L " +
                      psign + DoubleToStrClean(opips, 1) + "p SL:" + slStr + " TP:" + tpStr +
                      " H1:" + h1Tag + " M15:" + m15Tag, 80);
         int ocol = ordRow % ordColCount;
         int orow = ordRow / ordColCount;
         int colOffset = 4 + (ocol * ordColWidth);
         int rowYo = ordStartY + (orow * (lineHeight + 1));
         maxChars = MathMax(maxChars, (colOffset / 7) + StringLen(ol1) + StringLen(oEMARSI) + 2);
         CreateLabel("LblOrd" + IntegerToString(ordRow) + "A", ol1, x + colOffset, rowYo, lclr, 8);
         CreateLabel("LblOrd" + IntegerToString(ordRow) + "B", oEMARSI, x + colOffset + StringLen(ol1) * 5 + 30, rowYo, lclr, 8);
         if(orow > ordMaxRow) ordMaxRow = orow;
         ordRow++;
      }

      // Pass 2: pending orders sorted by distance (closest first)
      for(int pi = 0; pi < pendCount2 && ordRow < maxOrdRows; pi++) {
         if(!OrderSelect(pendTickets[pi], SELECT_BY_TICKET, MODE_TRADES)) continue;
         int    otype  = OrderType();
         string osym   = OrderSymbol();
         double olots  = OrderLots(), oentry = OrderOpenPrice();
         double osl    = OrderStopLoss(), otp = OrderTakeProfit();
         double oPipV  = PipValue(osym);
         double distPips = pendDists[pi];

         string otag;
         if(otype == OP_BUYLIMIT)       otag = "BL";
         else if(otype == OP_SELLLIMIT) otag = "SL";
         else                           otag = "?";
         // Fib tag: if order was placed at a fib level, show [BLF] or [SLF]
         if(StringFind(OrderComment(), "Fib") >= 0) {
            if(otype == OP_BUYLIMIT)       otag = "BLF";
            else if(otype == OP_SELLLIMIT) otag = "SLF";
         }
         string slStr  = (osl > 0 && oPipV > 0) ? DoubleToStrClean(MathAbs(oentry - osl) / oPipV, 0) + "p" : "---";
         string tpStr  = (otp > 0 && oPipV > 0) ? DoubleToStrClean(MathAbs(otp - oentry) / oPipV, 0) + "p" : "---";
         string obase  = StringSubstr(osym, 0, 3), oquote = StringSubstr(osym, 3, 3);
         int    h1Dir  = GetDirectionFromBiasLabels(GetBiasLabel(obase), GetBiasLabel(oquote));
         int    m15Dir = GetDirectionFromBiasLabels(GetBiasLabelLow(obase), GetBiasLabelLow(oquote));
         string h1Tag  = (h1Dir == 1) ? "BUY" : (h1Dir == -1) ? "SEL" : "---";
         string m15Tag = (m15Dir == 1) ? "BUY" : (m15Dir == -1) ? "SEL" : "---";
         int    ordDir = (otype == OP_BUYLIMIT || otype == OP_BUYSTOP) ? 1 : -1;
         color  biasClr;
         if(h1Dir == ordDir && m15Dir == ordDir)      biasClr = clrLime;
         else if(h1Dir == ordDir || m15Dir == ordDir) biasClr = clrYellow;
         else                                          biasClr = clrOrangeRed;
         color  distClr = (distPips <= 5) ? clrRed : (distPips <= 15) ? clrOrange : clrSilver;

         double pEMA20   = iMA(osym, PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE, 1);
         double pATR     = iATR(osym, PERIOD_H1, ATRPeriod, 1);
         double pClose   = iClose(osym, PERIOD_H1, 1);
         double pRSI1    = iRSI(osym, PERIOD_H1, RSI_Period, PRICE_CLOSE, 1);
         double pRSI2    = iRSI(osym, PERIOD_H1, RSI_Period, PRICE_CLOSE, 2);
         double pEMADist = pClose - pEMA20;
         string pEMATag  = (pATR > 0 && MathAbs(pEMADist) <= pATR * EMA_PullbackATR) ? "~" : (pEMADist > 0 ? "^" : "v");
         string pRSIDir  = (pRSI1 > pRSI2) ? "^" : (pRSI1 < pRSI2) ? "v" : "-";
         double pEMA20m  = iMA(osym, PERIOD_M15, 20, 0, MODE_EMA, PRICE_CLOSE, 1);
         double pATRm    = iATR(osym, PERIOD_M15, ATRPeriod, 1);
         double pClosem  = iClose(osym, PERIOD_M15, 1);
         double pRSI1m   = iRSI(osym, PERIOD_M15, RSI_Period, PRICE_CLOSE, 1);
         double pRSI2m   = iRSI(osym, PERIOD_M15, RSI_Period, PRICE_CLOSE, 2);
         double pEMADistm= pClosem - pEMA20m;
         string pEMATagm = (pATRm > 0 && MathAbs(pEMADistm) <= pATRm * EMA_PullbackATR) ? "~" : (pEMADistm > 0 ? "^" : "v");
         string pRSIDirm = (pRSI1m > pRSI2m) ? "^" : (pRSI1m < pRSI2m) ? "v" : "-";
         string pRSITagH1 = GetRSIEntryTag(ordDir, pRSI1);
         string pRSITagM15 = GetRSIEntryTag(ordDir, pRSI1m);
         string pEMARSI  = " H1:EMA:" + pEMATag + " RSI:" + DoubleToStrClean(pRSI1, 0) + pRSIDir + " " + pRSITagH1 +
                           " | M15:EMA:" + pEMATagm + " RSI:" + DoubleToStrClean(pRSI1m, 0) + pRSIDirm + " " + pRSITagM15;

         string preStr  = "[" + otag + "] " + osym + " " + DoubleToStrClean(olots, 2) + "L ";
         string dstStr  = "@" + DoubleToStrClean(distPips, 1) + "p  ";
         string sufStr  = TruncStr(" SL:" + slStr + " TP:" + tpStr + " H1:" + h1Tag + " M15:" + m15Tag,
                                   63 - StringLen(preStr) - StringLen(dstStr));
         int    cW      = 6; // approx px per char at Arial 8
         int    ocol    = ordRow % ordColCount;
         int    orow    = ordRow / ordColCount;
         int    colOffset2 = 4 + (ocol * ordColWidth);
         int    rowY    = ordStartY + (orow * (lineHeight + 1));
         int    sufOffset = (StringLen(preStr) + StringLen(dstStr) + StringLen(sufStr)) * cW;
         maxChars = MathMax(maxChars, (colOffset2 / 7) + StringLen(preStr) + StringLen(dstStr) + StringLen(sufStr) + StringLen(pEMARSI) + 2);
         CreateLabel("LblOrd" + IntegerToString(ordRow) + "A", preStr, x + colOffset2, rowY, biasClr, 8);
         CreateLabel("LblOrd" + IntegerToString(ordRow) + "D", dstStr, x + colOffset2 + StringLen(preStr) * cW, rowY, distClr, 8);
         CreateLabel("LblOrd" + IntegerToString(ordRow) + "S", sufStr, x + colOffset2 + (StringLen(preStr) + StringLen(dstStr)) * cW, rowY, biasClr, 8);
         CreateLabel("LblOrd" + IntegerToString(ordRow) + "B", pEMARSI, x + colOffset2 + (StringLen(preStr) + StringLen(dstStr) + StringLen(sufStr)) * 5 + 60, rowY, biasClr, 8);
         if(orow > ordMaxRow) ordMaxRow = orow;
         ordRow++;
      }

      // Advance y past all order rows
      y = ordStartY + ((ordMaxRow + 1) * (lineHeight + 1));

      for(int ok = ordRow; ok < maxOrdRows; ok++) {
         ObjectDelete(0, "LblOrd" + IntegerToString(ok) + "A");
         ObjectDelete(0, "LblOrd" + IntegerToString(ok) + "B");
         ObjectDelete(0, "LblOrd" + IntegerToString(ok) + "D");
         ObjectDelete(0, "LblOrd" + IntegerToString(ok) + "S");
      }

      if(marketCount > 0) {
         string tsign = (totalPips >= 0) ? "+" : "";
         color  tclr  = (totalPips >= 0) ? clrLime : clrRed;
         CreateLabel("LblPips", "Total P/L: " + tsign + DoubleToStrClean(totalPips, 1) + " pips", x, y, tclr, 9);
         y += lineHeight;
      } else {
         ObjectDelete(0, "LblPips");
      }
      // -- Recovery Hedge Monitor (v2.0) --
      if(g_recoveryCount > 0) {
         CreateLabel("LblRecTitle", "-- RECOVERY HEDGE (" + IntegerToString(g_recoveryCount) + " active) --", x, y, clrMagenta, 8);
         y += lineHeight;
         for(int ri = 0; ri < g_recoveryCount && ri < 10; ri++) {
            string rsym = g_recovery[ri].symbol;
            int openRec = CountOpenRecoveryHedges(ri);
            int totalRec = g_recovery[ri].recoveryCount;
            double recPips = g_recovery[ri].totalRecoveredPips;
            double recProfit = g_recovery[ri].totalRecoveredProfit;

            // Get parent floating P/L
            double parentPips = 0;
            if(OrderSelect(g_recovery[ri].parentTicket, SELECT_BY_TICKET, MODE_TRADES)) {
               int ptype = OrderType();
               double pEntry = OrderOpenPrice();
               double pPipV = PipValue(rsym);
               if(pPipV > 0) {
                  double pPrice = (ptype == OP_BUY) ? MarketInfo(rsym, MODE_BID) : MarketInfo(rsym, MODE_ASK);
                  parentPips = (ptype == OP_BUY) ? (pPrice - pEntry) / pPipV : (pEntry - pPrice) / pPipV;
               }
            }

            // Line 1: pair, parent ticket, floating P/L
            string rLine1 = "[REC] " + rsym + " #" + IntegerToString(g_recovery[ri].parentTicket) +
                            "  Float:" + (parentPips>=0?"+":"") + DoubleToStrClean(parentPips, 1) + "p" +
                            "  Hedges:" + IntegerToString(openRec) + "/" + IntegerToString(totalRec);
            // Line 2: recovered stats
            string rLine2 = "      Recovered: " + DoubleToStrClean(recPips, 1) + "p ($" + DoubleToStrClean(recProfit, 2) + ")" +
                            "  Net:" + (parentPips+recPips>=0?"+":"") + DoubleToStrClean(parentPips+recPips, 1) + "p";
            color rClr = (parentPips + recPips >= 0) ? clrLime : clrMagenta;
            maxChars = MathMax(maxChars, StringLen(rLine1));
            maxChars = MathMax(maxChars, StringLen(rLine2));
            CreateLabel("LblRec" + IntegerToString(ri) + "A", rLine1, x, y, rClr, 8);
            y += lineHeight;
            CreateLabel("LblRec" + IntegerToString(ri) + "B", rLine2, x, y, rClr, 8);
            y += lineHeight;
         }
      } else {
         ObjectDelete(0, "LblRecTitle");
         for(int ri = 0; ri < 10; ri++) {
            ObjectDelete(0, "LblRec" + IntegerToString(ri) + "A");
            ObjectDelete(0, "LblRec" + IntegerToString(ri) + "B");
         }
      }

   } else {
      ObjectDelete(0, "LblTrades");
      ObjectDelete(0, "LblPips");
      for(int ok = 0; ok < maxOrdRows; ok++) {
         ObjectDelete(0, "LblOrd" + IntegerToString(ok) + "A");
         ObjectDelete(0, "LblOrd" + IntegerToString(ok) + "B");
         ObjectDelete(0, "LblOrd" + IntegerToString(ok) + "D");
         ObjectDelete(0, "LblOrd" + IntegerToString(ok) + "S");
      }
   }

   y += 5;

   // Market
   CreateLabel("LblMarket", "Market: " + GetMarketStatus(), x, y, TextColor, 9);
   y += lineHeight;

   // Refresh live news feed for panel status
   if(UseLiveNewsFeed) FetchLiveNews();

   // News feed status
   string newsFeedInfo = "News feed: FALLBACK (reason=Disabled)";
   if(UseLiveNewsFeed) {
      if(lastNewsFetch <= 0) {
         newsFeedInfo = "News feed: FALLBACK (reason=Waiting)";
      } else if(liveNewsLoaded) {
         newsFeedInfo = "News feed: LIVE (count=" + IntegerToString(NewsCount) + ")";
      } else {
         string newsReason = (lastNewsError != "" ? lastNewsError : "No events");
         newsFeedInfo = "News feed: FALLBACK (reason=" + newsReason + ")";
      }
   }
   CreateLabel("LblNewsFeed", newsFeedInfo, x, y, clrAqua, 9);
   y += lineHeight;
   if(UseLiveNewsFeed && lastNewsError != "") {
      string errText = lastNewsError;
      if(lastNewsErrorCode > 0) errText += " (#" + IntegerToString(lastNewsErrorCode) + ")";
      CreateLabel("LblNewsFeedErr", "News error: " + errText, x, y, clrOrange, 8);
      y += lineHeight;
   } else {
      ObjectDelete(0, "LblNewsFeedErr");
   }
   
   // News event display (informational only — no longer blocks trading)
   if(GetNewsNowCached()) {
      CreateLabel("LblNews", "NEWS: " + currentNewsEvent, x, y, clrOrange, 9);
      y += lineHeight + 5;
   } else {
      ObjectDelete(0, "LblNews");
      // Check if news coming soon (within 2 hours)
      int hour = TimeHour(TimeGMT());
      int dayOfWeek = TimeDayOfWeek(TimeGMT());
      int day = TimeDay(TimeCurrent());
      string upcomingNews = "";
      
      // NFP warning
      if(dayOfWeek == 5 && day <= 7 && hour >= 11 && hour < 13) {
         upcomingNews = "NFP in " + IntegerToString(13 - hour) + "h";
      }
      // FOMC warning
      else if(dayOfWeek == 3 && hour >= 16 && hour < 19) {
         upcomingNews = "FOMC possible";
      }
      // USD data warning  
      else if(hour >= 11 && hour < 13) {
         upcomingNews = "USD data possible";
      }
      
      if(upcomingNews != "") {
         CreateLabel("LblNews", "WARNING: " + upcomingNews, x, y, clrOrange, 9);
         y += lineHeight + 5;
      } else {
         ObjectDelete(0, "LblNews");
      }
   }

   
   y += 5;
   
   // Next scan countdown
   datetime nextH1 = iTime(Symbol(), PERIOD_H1, 0) + 3600;
   int secondsUntil = (int)(nextH1 - TimeCurrent());
   int minutesUntil = secondsUntil / 60;
   
   string scanStr = "Next scan: ";
   if(minutesUntil <= 0) {
      scanStr += "Scanning now...";
      CreateLabel("LblNextScan", scanStr, x, y, clrYellow, 9, "Arial Black");
   } else if(minutesUntil < 60) {
      scanStr += IntegerToString(minutesUntil) + " minutes";
      CreateLabel("LblNextScan", scanStr, x, y, clrAqua, 9);
   } else {
      int hours = minutesUntil / 60;
      int mins = minutesUntil % 60;
      scanStr += IntegerToString(hours) + "h " + IntegerToString(mins) + "m";
      CreateLabel("LblNextScan", scanStr, x, y, clrAqua, 9);
   }
   y += lineHeight + 5;
   
   // Currency Bias — H1 Chart (D1 / H4 / H1)
   CreateLabel("LblBiasTitle", "Currency Bias (H1 Chart):", x, y, clrYellow, 9);
   y += lineHeight;

   int rowHeight = 14;
   int colWidth  = 260;
   for(int bi = 0; bi < 7; bi++) {
      string cur = Currencies[bi];
      string bias = GetBiasLabel(cur);
      string shortBias = (bias == "STRONG") ? "STR" : (bias == "WEAK") ? "WK" : (bias == "INV") ? "INV" : "NEU";
      color biasColor  = (bias == "STRONG") ? clrLime : (bias == "WEAK") ? clrRed : (bias == "INV") ? clrOrange : clrGray;
      int d1b, d1br, d1r, h4b, h4br, h4r, h1b, h1br, h1r;
      CurrencyScoreDetail(cur, PERIOD_D1, d1b, d1br, d1r);
      CurrencyScoreDetail(cur, PERIOD_H4, h4b, h4br, h4r);
      CurrencyScoreDetail(cur, PERIOD_H1, h1b, h1br, h1r);
      // Format: EUR:STR  D1:+3/-2/1  H4:+4/-1/1  H1:+3/-2/1
      // +bull / -bear / ranging
      string scoreStr = cur + ":" + shortBias
                      + "  D1:+" + IntegerToString(d1b) + "/-" + IntegerToString(d1br) + "/" + IntegerToString(d1r)
                      + "  H4:+" + IntegerToString(h4b) + "/-" + IntegerToString(h4br) + "/" + IntegerToString(h4r)
                      + "  H1:+" + IntegerToString(h1b) + "/-" + IntegerToString(h1br) + "/" + IntegerToString(h1r);
      int bcol = bi % 3;
      int brow = bi / 3;
      CreateLabel("LblBias" + cur, scoreStr, x + (bcol * colWidth), y + (brow * rowHeight), biasColor, 8);
   }
   y += (rowHeight * 3) + 8;

   // Currency Bias — M15 Chart (H1 / M30 / M15)
   CreateLabel("LblBiasTitleM15", "Currency Bias (M15 Chart):", x, y, clrYellow, 9);
   y += lineHeight;

   for(int mi = 0; mi < 7; mi++) {
      string mcur = Currencies[mi];
      string mbias = GetBiasLabelLow(mcur);
      string mshortBias = (mbias == "STRONG") ? "STR" : (mbias == "WEAK") ? "WK" : (mbias == "INV") ? "INV" : "NEU";
      color mbiasColor  = (mbias == "STRONG") ? clrLime : (mbias == "WEAK") ? clrRed : (mbias == "INV") ? clrOrange : clrGray;
      int mh1b, mh1br, mh1r, mm30b, mm30br, mm30r, mm15b, mm15br, mm15r;
      CurrencyScoreDetail(mcur, PERIOD_H1,  mh1b,  mh1br,  mh1r);
      CurrencyScoreDetail(mcur, PERIOD_M30, mm30b, mm30br, mm30r);
      CurrencyScoreDetail(mcur, PERIOD_M15, mm15b, mm15br, mm15r);
      // Format: EUR:STR  H1:+3/-2/1  M30:+4/-1/1  M15:+3/-2/1
      // +bull / -bear / ranging
      string mscoreStr = mcur + ":" + mshortBias
                       + "  H1:+"  + IntegerToString(mh1b)  + "/-" + IntegerToString(mh1br)  + "/" + IntegerToString(mh1r)
                       + "  M30:+" + IntegerToString(mm30b) + "/-" + IntegerToString(mm30br) + "/" + IntegerToString(mm30r)
                       + "  M15:+" + IntegerToString(mm15b) + "/-" + IntegerToString(mm15br) + "/" + IntegerToString(mm15r);
      int mcol = mi % 3;
      int mrow = mi / 3;
      CreateLabel("LblBiasM15" + mcur, mscoreStr, x + (mcol * colWidth), y + (mrow * rowHeight), mbiasColor, 8);
   }
   y += (rowHeight * 3) + 4;

   // ── Tradeable Pairs (not in open/pending) ────────────────────────
   ObjectDelete(0, "LblTradeable_B");
   ObjectDelete(0, "LblTradeable_S");
   ObjectDelete(0, "LblTradeable_N");

   // Per-pair tradeable data arrays (BUY first, then SELL)
   string tBuyA[], tBuyB[];
   color  tBuyClr[];
   int    tBuyCnt = 0;
   string tSelA[], tSelB[];
   color  tSelClr[];
   int    tSelCnt = 0;
   ArrayResize(tBuyA, PairsCount); ArrayResize(tBuyB, PairsCount); ArrayResize(tBuyClr, PairsCount);
   ArrayResize(tSelA, PairsCount); ArrayResize(tSelB, PairsCount); ArrayResize(tSelClr, PairsCount);

   for(int pi = 0; pi < PairsCount; pi++) {
      string psym = Pairs[pi];
      bool inUse = false;
      for(int oi = 0; oi < OrdersTotal(); oi++) {
         if(!OrderSelect(oi, SELECT_BY_POS, MODE_TRADES)) continue;
         if(OrderSymbol() == psym) { inUse = true; break; }
      }
      if(inUse) continue;

      string pbase  = StringSubstr(psym, 0, 3);
      string pquote = StringSubstr(psym, 3, 3);

      // H1 chart direction (D1+H4+H1) — sole authority
      int dirH1  = GetDirectionFromBiasLabels(GetBiasLabel(pbase), GetBiasLabel(pquote));
      if(dirH1 == 0) continue;

      int    dir     = dirH1;
      int    dirM15  = GetDirectionFromBiasLabels(GetBiasLabelLow(pbase), GetBiasLabelLow(pquote));
      string pairLbl = psym + (dirM15 == dirH1 ? "(H1/M15)" : "(H1)");

      // Read from PairCache — no live indicator calls
      double tEMA20   = g_cache[pi].h1_ema20;
      double tATR     = g_cache[pi].h1_atr;
      double tClose   = g_cache[pi].h1_close;
      double tRSI1    = g_cache[pi].h1_rsi1;
      double tRSI2    = g_cache[pi].h1_rsi2;
      double tEMADist = tClose - tEMA20;
      string tEMATag  = (tATR > 0 && MathAbs(tEMADist) <= tATR * EMA_PullbackATR) ? "~" : (tEMADist > 0 ? "^" : "v");
      string tRSIDir  = (tRSI1 > tRSI2) ? "^" : (tRSI1 < tRSI2) ? "v" : "-";
      double tEMA20m  = g_cache[pi].m15_ema20;
      double tATRm    = g_cache[pi].m15_atr;
      double tClosem  = g_cache[pi].m15_close;
      double tRSI1m   = g_cache[pi].m15_rsi1;
      double tRSI2m   = g_cache[pi].m15_rsi2;
      double tEMADistm= tClosem - tEMA20m;
      string tEMATagm = (tATRm > 0 && MathAbs(tEMADistm) <= tATRm * EMA_PullbackATR) ? "~" : (tEMADistm > 0 ? "^" : "v");
      string tRSIDirm = (tRSI1m > tRSI2m) ? "^" : (tRSI1m < tRSI2m) ? "v" : "-";
      string tEntryTagH1 = GetRSIEntryTag(dir, tRSI1);
      string tEntryTagM15 = GetRSIEntryTag(dir, tRSI1m);

      string lblA = (dir == 1 ? "BUY: " : "SELL: ") + pairLbl;
      string lblB = "H1:EMA:" + tEMATag + " RSI:" + DoubleToStrClean(tRSI1, 0) + tRSIDir + " " + tEntryTagH1 +
                    " M15:EMA:" + tEMATagm + " RSI:" + DoubleToStrClean(tRSI1m, 0) + tRSIDirm + " " + tEntryTagM15;
      color  clrT = (dir == 1) ? clrLime : clrTomato;

      if(dir == 1) { tBuyA[tBuyCnt] = lblA; tBuyB[tBuyCnt] = lblB; tBuyClr[tBuyCnt] = clrT; tBuyCnt++; }
      else         { tSelA[tSelCnt] = lblA; tSelB[tSelCnt] = lblB; tSelClr[tSelCnt] = clrT; tSelCnt++; }
   }

   // Delete old tradeable labels
   for(int tdi = 0; tdi < 30; tdi++) {
      ObjectDelete(0, "LblTrade_" + IntegerToString(tdi) + "A");
      ObjectDelete(0, "LblTrade_" + IntegerToString(tdi) + "B");
      ObjectDelete(0, "LblTradeable_B" + IntegerToString(tdi));
      ObjectDelete(0, "LblTradeable_S" + IntegerToString(tdi));
   }

   CreateLabel("LblTradeableTitle", "Tradeable Now (no open/pending):", x, y, clrYellow, 9);
   y += lineHeight;

   int tradeRow = 0;
   for(int bi = 0; bi < tBuyCnt; bi++) {
      maxChars = MathMax(maxChars, StringLen(tBuyA[bi]) + StringLen(tBuyB[bi]) + 2);
      CreateLabel("LblTrade_" + IntegerToString(tradeRow) + "A", tBuyA[bi], x, y, tBuyClr[bi], 8);
      CreateLabel("LblTrade_" + IntegerToString(tradeRow) + "B", tBuyB[bi], x + StringLen(tBuyA[bi]) * 6 + 8, y, tBuyClr[bi], 8);
      y += lineHeight;
      tradeRow++;
   }
   for(int si = 0; si < tSelCnt; si++) {
      maxChars = MathMax(maxChars, StringLen(tSelA[si]) + StringLen(tSelB[si]) + 2);
      CreateLabel("LblTrade_" + IntegerToString(tradeRow) + "A", tSelA[si], x, y, tSelClr[si], 8);
      CreateLabel("LblTrade_" + IntegerToString(tradeRow) + "B", tSelB[si], x + StringLen(tSelA[si]) * 6 + 8, y, tSelClr[si], 8);
      y += lineHeight;
      tradeRow++;
   }

   if(tBuyCnt == 0 && tSelCnt == 0) {
      CreateLabel("LblTradeable_N", "All pairs in use or no clear bias.", x, y, clrGray, 8);
      y += lineHeight;
   }
   y += 4;

   ObjectDelete(0, "LblNearestSR");

   // ── Dynamically resize panel background to fit all content ──────
   int panelContentH = (y - 30) + 35;
   if(panelContentH < 500) panelContentH = 500;
   int panelW = MathMax(500, maxChars * 7 + 40);
   ObjectSetInteger(0, "PanelBG", OBJPROP_XSIZE, panelW);
   ObjectSetInteger(0, "PanelBG", OBJPROP_YSIZE, panelContentH);

   // ── Reposition buttons just below panel ───────────────────────
   int by0 = 30 + panelContentH + 5;
   int bw2 = 148, bh2 = 26, bgap = 6;
   // Row 1: Scan
   ObjectSetInteger(0, "btnScan",    OBJPROP_CORNER, 0); ObjectSetInteger(0, "btnScan",    OBJPROP_XDISTANCE, 10); ObjectSetInteger(0, "btnScan",    OBJPROP_YDISTANCE, by0);      ObjectSetInteger(0, "btnScan",    OBJPROP_XSIZE, bw2); ObjectSetInteger(0, "btnScan",    OBJPROP_YSIZE, bh2);
   // Row 2: Alerts | Test
   ObjectSetInteger(0, "btnAlerts",  OBJPROP_CORNER, 0); ObjectSetInteger(0, "btnAlerts",  OBJPROP_XDISTANCE, 10);            ObjectSetInteger(0, "btnAlerts",  OBJPROP_YDISTANCE, by0+bh2+bgap); ObjectSetInteger(0, "btnAlerts",  OBJPROP_XSIZE, bw2); ObjectSetInteger(0, "btnAlerts",  OBJPROP_YSIZE, bh2);
   ObjectSetInteger(0, "btnTest",    OBJPROP_CORNER, 0); ObjectSetInteger(0, "btnTest",    OBJPROP_XDISTANCE, 10+bw2+bgap);   ObjectSetInteger(0, "btnTest",    OBJPROP_YDISTANCE, by0+bh2+bgap); ObjectSetInteger(0, "btnTest",    OBJPROP_XSIZE, bw2); ObjectSetInteger(0, "btnTest",    OBJPROP_YSIZE, bh2);
   ChartRedraw();
}

void CreateTestButton() {
   // Buttons are created once here; positions are set every tick in UpdateChartPanel.
   int bw = 148, bh = 26;

   if(ObjectFind(0, "btnScan") == -1) {
      ObjectCreate(0, "btnScan", OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, "btnScan", OBJPROP_XSIZE, bw); ObjectSetInteger(0, "btnScan", OBJPROP_YSIZE, bh);
      ObjectSetString(0, "btnScan",  OBJPROP_TEXT, "[ SCAN ]");
      ObjectSetInteger(0, "btnScan", OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, "btnScan", OBJPROP_BGCOLOR, clrDarkBlue);
   }
   if(ObjectFind(0, "btnAlerts") == -1) {
      ObjectCreate(0, "btnAlerts", OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, "btnAlerts", OBJPROP_XSIZE, bw); ObjectSetInteger(0, "btnAlerts", OBJPROP_YSIZE, bh);
      ObjectSetString(0, "btnAlerts",  OBJPROP_TEXT, "[ ALERTS ]");
      ObjectSetInteger(0, "btnAlerts", OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, "btnAlerts", OBJPROP_BGCOLOR, clrPurple);
   }
   if(ObjectFind(0, "btnTest") == -1) {
      ObjectCreate(0, "btnTest", OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, "btnTest", OBJPROP_XSIZE, bw); ObjectSetInteger(0, "btnTest", OBJPROP_YSIZE, bh);
      ObjectSetString(0, "btnTest",  OBJPROP_TEXT, "[ TEST ]");
      ObjectSetInteger(0, "btnTest", OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, "btnTest", OBJPROP_BGCOLOR, clrDarkGreen);
   }
}

//+------------------------------------------------------------------+
//| IMPULSE SWING PENDING ORDERS (PerfectPullback logic)             |
//+------------------------------------------------------------------+

// Find S/R levels for a symbol on H1 — used for TP targeting
int FindSRLevelsSym(string sym, double &srLevels[]) {
   double tempLevels[];
   int tempCount = 0;
   double pipVal = PipValue(sym);
   int digits    = (int)MarketInfo(sym, MODE_DIGITS);
   double zone   = PendingSR_ZonePips * pipVal;
   int strength  = PendingSR_Strength;
   int lookback  = PendingSR_Lookback;
   int totalBars = iBars(sym, PERIOD_H1);
   if(lookback > totalBars - strength - 1) lookback = totalBars - strength - 1;

   for(int i = strength; i < lookback - strength; i++) {
      double hi = iHigh(sym, PERIOD_H1, i);
      double lo = iLow(sym,  PERIOD_H1, i);

      // Swing high
      bool isSwingHigh = true;
      for(int j = 1; j <= strength; j++) {
         if(hi <= iHigh(sym, PERIOD_H1, i-j) || hi <= iHigh(sym, PERIOD_H1, i+j))
         { isSwingHigh = false; break; }
      }
      if(isSwingHigh) {
         bool isDup = false;
         for(int k = 0; k < tempCount; k++) {
            if(MathAbs(hi - tempLevels[k]) <= zone)
            { tempLevels[k] = (tempLevels[k] + hi) / 2.0; isDup = true; break; }
         }
         if(!isDup) { ArrayResize(tempLevels, tempCount + 1); tempLevels[tempCount] = hi; tempCount++; }
      }

      // Swing low
      bool isSwingLow = true;
      for(int j = 1; j <= strength; j++) {
         if(lo >= iLow(sym, PERIOD_H1, i-j) || lo >= iLow(sym, PERIOD_H1, i+j))
         { isSwingLow = false; break; }
      }
      if(isSwingLow) {
         bool isDup = false;
         for(int k = 0; k < tempCount; k++) {
            if(MathAbs(lo - tempLevels[k]) <= zone)
            { tempLevels[k] = (tempLevels[k] + lo) / 2.0; isDup = true; break; }
         }
         if(!isDup) { ArrayResize(tempLevels, tempCount + 1); tempLevels[tempCount] = lo; tempCount++; }
      }
   }

   // Sort ascending
   for(int i = 0; i < tempCount - 1; i++) {
      for(int j = i + 1; j < tempCount; j++) {
         if(tempLevels[i] > tempLevels[j])
         { double tmp = tempLevels[i]; tempLevels[i] = tempLevels[j]; tempLevels[j] = tmp; }
      }
   }

   ArrayResize(srLevels, tempCount);
   for(int i = 0; i < tempCount; i++)
      srLevels[i] = NormalizeDouble(tempLevels[i], digits);
   return tempCount;
}

// Find best TP level from S/R array
double FindTPLevelSym(string sym, double entryPrice, int direction, double &srLevels[], int srCount) {
   double pipVal    = PipValue(sym);
   int    digits    = (int)MarketInfo(sym, MODE_DIGITS);
   double minTpDist = PendingMinTP_Pips * pipVal;

   if(direction == 1) { // BUY — look for resistance above
      double best = 0;
      for(int i = srCount - 1; i >= 0; i--) {
         if(srLevels[i] > entryPrice && (srLevels[i] - entryPrice) >= minTpDist)
         { best = srLevels[i]; break; }
      }
      if(best == 0) for(int i = srCount - 1; i >= 0; i--)
         { if(srLevels[i] > entryPrice) { best = srLevels[i]; break; } }
      if(best == 0 || (best - entryPrice) < minTpDist) best = entryPrice + minTpDist;
      return NormalizeDouble(best, digits);
   } else { // SELL — look for farthest support below (consistent with BUY picking farthest)
      double best = 0;
      for(int i = 0; i < srCount; i++) {
         if(srLevels[i] < entryPrice && (entryPrice - srLevels[i]) >= minTpDist)
            { best = srLevels[i]; break; } // first match (lowest) IS the farthest support
      }
      if(best == 0) for(int i = 0; i < srCount; i++)
         { if(srLevels[i] < entryPrice) { best = srLevels[i]; break; } } // first (lowest) = farthest below
      if(best == 0 || (entryPrice - best) < minTpDist) best = entryPrice - minTpDist;
      return NormalizeDouble(best, digits);
   }
}

// Detect impulse on H1 using fractal-based swing detection (not just iHighest/iLowest).
// Finds confirmed swing highs/lows with PendingSR_Strength bars on each side,
// then picks the best impulse pair within the lookback window.
// Returns the swing entry level (0 = no valid impulse).
// Also outputs the full impulse range via impLow/impHigh for Fib entry calculation.
double DetectImpulseSym(string sym, int direction, double &impLow, double &impHigh) {
   impLow = 0; impHigh = 0;
   double pipVal  = PipValue(sym);
   double minImpl = PendingMinImpulsePips * pipVal;
   int lookback   = PendingImpulseLookback;
   int strength   = PendingSR_Strength;
   int totalBars  = iBars(sym, PERIOD_H1);
   if(lookback > totalBars - strength - 1) lookback = totalBars - strength - 1;
   if(lookback < strength + 2) return 0;

   // Collect confirmed fractal swing highs and lows within lookback
   double swHiPrices[]; int swHiBars[];  int swHiCnt = 0;
   double swLoPrices[]; int swLoBars[];  int swLoCnt = 0;

   for(int i = strength; i < lookback - strength; i++) {
      double hi = iHigh(sym, PERIOD_H1, i);
      double lo = iLow(sym, PERIOD_H1, i);

      // Fractal swing high: higher than 'strength' bars on each side
      bool isHigh = true;
      for(int j = 1; j <= strength; j++) {
         if(hi <= iHigh(sym, PERIOD_H1, i - j) || hi <= iHigh(sym, PERIOD_H1, i + j))
         { isHigh = false; break; }
      }
      if(isHigh) {
         ArrayResize(swHiPrices, swHiCnt + 1); ArrayResize(swHiBars, swHiCnt + 1);
         swHiPrices[swHiCnt] = hi; swHiBars[swHiCnt] = i; swHiCnt++;
      }

      // Fractal swing low: lower than 'strength' bars on each side
      bool isLow = true;
      for(int j = 1; j <= strength; j++) {
         if(lo >= iLow(sym, PERIOD_H1, i - j) || lo >= iLow(sym, PERIOD_H1, i + j))
         { isLow = false; break; }
      }
      if(isLow) {
         ArrayResize(swLoPrices, swLoCnt + 1); ArrayResize(swLoBars, swLoCnt + 1);
         swLoPrices[swLoCnt] = lo; swLoBars[swLoCnt] = i; swLoCnt++;
      }
   }

   if(direction == -1) { // SELL: find swing high → swing low (drop) with best score
      double bestScore = 0;
      double bestHi = 0, bestLo = 0;
      for(int h = 0; h < swHiCnt; h++) {
         for(int l = 0; l < swLoCnt; l++) {
            // Swing low must be MORE RECENT (smaller bar index) than swing high
            if(swLoBars[l] >= swHiBars[h]) continue;
            double range = swHiPrices[h] - swLoPrices[l];
            if(range < minImpl) continue;
            // v2.0: Recency-weighted scoring — fresh impulses score higher
            // Uses the older swing (high) bar index as the age measure
            double recency = 1.0 - ((double)swHiBars[h] / (double)lookback);
            double score   = range * (0.5 + 0.5 * recency); // 50% range + 50% recency
            if(score > bestScore) {
               bestScore = score;
               bestHi = swHiPrices[h];
               bestLo = swLoPrices[l];
            }
         }
      }
      if(bestScore <= 0) return 0;
      impLow = bestLo; impHigh = bestHi;
      return bestHi; // SELL LIMIT at swing HIGH
   } else { // BUY: find swing low → swing high (rally) with best score
      double bestScore = 0;
      double bestHi = 0, bestLo = 0;
      for(int l = 0; l < swLoCnt; l++) {
         for(int h = 0; h < swHiCnt; h++) {
            // Swing high must be MORE RECENT (smaller bar index) than swing low
            if(swHiBars[h] >= swLoBars[l]) continue;
            double range = swHiPrices[h] - swLoPrices[l];
            if(range < minImpl) continue;
            // v2.0: Recency-weighted scoring — fresh impulses score higher
            double recency = 1.0 - ((double)swLoBars[l] / (double)lookback);
            double score   = range * (0.5 + 0.5 * recency);
            if(score > bestScore) {
               bestScore = score;
               bestHi = swHiPrices[h];
               bestLo = swLoPrices[l];
            }
         }
      }
      if(bestScore <= 0) return 0;
      impLow = bestLo; impHigh = bestHi;
      return bestLo; // BUY LIMIT at swing LOW
   }
}

// Find the closest Fib retracement entry to current price that still has >= PendingMinTP_Pips of TP room.
// Tries: 61.8% → 50% → 38.2% → swing extreme (100%).
// Returns 0 if none qualify.
// Count EA-managed pending orders for a symbol in a given direction
int CountPendingForSym(string sym, int direction) {
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != sym || OrderMagicNumber() != AutoMagicNumber) continue;
      int type = OrderType();
      bool isBuyPend  = (type == OP_BUYLIMIT  || type == OP_BUYSTOP);
      bool isSellPend = (type == OP_SELLLIMIT || type == OP_SELLSTOP);
      if(direction == 1  && isBuyPend)  count++;
      if(direction == -1 && isSellPend) count++;
   }
   return count;
}

// Check if an open (market) trade already exists for sym in given direction
bool HasOpenTradeForSym(string sym, int direction) {
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != sym) continue;
      if(AutoManageOnlyMagic && OrderMagicNumber() != AutoMagicNumber && OrderMagicNumber() != MagicNumber) continue;
      int type = OrderType();
      if(direction == 1  && type == OP_BUY)  return true;
      if(direction == -1 && type == OP_SELL) return true;
   }
   return false;
}

// Check if EA already has a pending near a price level (avoid duplicate orders at same fib)
bool HasPendingNearPrice(string sym, int direction, double price, double tolerancePips) {
   double tol = tolerancePips * PipValue(sym);
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != sym || OrderMagicNumber() != AutoMagicNumber) continue;
      int type = OrderType();
      bool isBuyPend  = (type == OP_BUYLIMIT  || type == OP_BUYSTOP);
      bool isSellPend = (type == OP_SELLLIMIT || type == OP_SELLSTOP);
      if(direction == 1  && !isBuyPend)  continue;
      if(direction == -1 && !isSellPend) continue;
      if(MathAbs(OrderOpenPrice() - price) <= tol) return true;
   }
   return false;
}

// Place impulse swing pending orders for one pair:
//   Pass 1 — Swing extreme (H1 only): placed immediately, always
//   Pass 2 — Best fib level (H1+M15): placed when M15 also aligns
void PlaceImpulsePendingForPair(string sym, int direction) {
   if(!AutoTradingActive()) return;
   if(!AutoPlacePending)    return;
   if(!IsDrawdownOK())      return;
   if(!IsSpreadOK(sym))     return;
   if(HasOpenTradeForSym(sym, direction)) return;
   if(CountPendingForSym(sym, direction) >= PendingMaxPerPair) return;

   double pipVal = PipValue(sym);
   int    digits = (int)MarketInfo(sym, MODE_DIGITS);
   double ask    = MarketInfo(sym, MODE_ASK);
   double bid    = MarketInfo(sym, MODE_BID);

   double impLow = 0, impHigh = 0;
   double extremeEntry = DetectImpulseSym(sym, direction, impLow, impHigh);
   if(extremeEntry <= 0) {
      Log(sym + ": No impulse detected for " + (direction == 1 ? "BUY" : "SELL"));
      return;
   }
   double range = (impHigh > 0 && impLow > 0) ? (impHigh - impLow) : 0;

   // Build S/R levels once — shared by both passes
   double srLevels[];
   int    srCount = FindSRLevelsSym(sym, srLevels);

   int      orderType  = (direction == 1) ? OP_BUYLIMIT : OP_SELLLIMIT;
   datetime expiration = TimeCurrent() + PendingExpireHours * 3600;
   int      slippage   = SlippageToPoints(sym, AutoSlippagePips);
   color    arrowClr   = (direction == 1) ? clrDodgerBlue : clrOrangeRed;

   // ── PASS 1: Swing Extreme — H1 bias only, always place ──────────
   {
      double candidate = NormalizeDouble(extremeEntry, digits);
      if((direction == 1 && candidate < ask) || (direction == -1 && candidate > bid)) {
         // v2.0: Max distance cap — skip entries too far from current price
         double distPips1 = MathAbs(candidate - (direction == 1 ? ask : bid)) / pipVal;
         if(distPips1 > PendingMaxEntryDistPips) {
            Log(sym + ": [SwingExt] Entry too far (" + DoubleToString(distPips1,1) + "p > " + IntegerToString(PendingMaxEntryDistPips) + "p) — skip");
         } else if(!HasPendingNearPrice(sym, direction, candidate, PendingSR_ZonePips)) {
            double tp     = FindTPLevelSym(sym, candidate, direction, srLevels, srCount);
            double tpPips = MathAbs(tp - candidate) / pipVal;
            if(tpPips >= PendingMinTP_Pips) {
               double sl    = (direction == 1) ? NormalizeDouble(candidate - PendingSL_Pips * pipVal, digits)
                                               : NormalizeDouble(candidate + PendingSL_Pips * pipVal, digits);
               string comment = (direction == 1 ? "SMP_Buy_SwingExt" : "SMP_Sell_SwingExt");
               Log(sym + ": [SwingExt] Placing " + (direction==1?"BUY LIMIT":"SELL LIMIT") +
                   " Entry=" + DoubleToString(candidate, digits) +
                   " SL=" + DoubleToString(MathAbs(candidate-sl)/pipVal,1) + "p" +
                   " TP=" + DoubleToString(tpPips,1) + "p");
               double lots = LotSize;
               int tk = OrderSend(sym, orderType, lots, candidate, slippage,
                                  sl, tp, comment, AutoMagicNumber, expiration, arrowClr);
               if(tk > 0) { Log(sym + ": [SwingExt] Placed Ticket=" + IntegerToString(tk)); MarkAlertBadge(); }
               else { Log(sym + ": [SwingExt] FAILED err=" + IntegerToString(GetLastError())); ResetLastError(); }
            } else Log(sym + ": [SwingExt] TP too small (" + DoubleToString(tpPips,1) + "p) — skip");
         } else if(distPips1 <= PendingMaxEntryDistPips) Log(sym + ": [SwingExt] Pending already exists — skip");
      } else Log(sym + ": [SwingExt] Entry wrong side of price — skip");
   }

   // ── PASS 2: Best Fib Level — requires H1 + M15 alignment ────────
   if(!PendingUseFibEntry || range <= 0) return;
   if(CountPendingForSym(sym, direction) >= PendingMaxPerPair) return;

   string pbase  = StringSubstr(sym, 0, 3);
   string pquote = StringSubstr(sym, 3, 3);
   int m15Dir = GetDirectionFromBiasLabels(GetBiasLabelLow(pbase), GetBiasLabelLow(pquote));
   // m15Dir == 0 means INV or neutral (normal during a pullback) — allow it
   // only block when M15 gives a confirmed hard counter signal
   if(PendingRequireM15Align && m15Dir != 0 && m15Dir != direction) {
      Log(sym + ": [Fib] Skipped — M15 is hard counter to H1");
      return;
   }

   double fibs[]      = {0.382, 0.500, 0.618};
   string fibLabels[] = {"38.2%", "50.0%", "61.8%"};

   // ── Step 1: evaluate all 3 fib levels, collect valid candidates ─
   double candPrices[3];
   double candTP[3];
   bool   candValid[3];
   ArrayInitialize(candValid, false);
   for(int f = 0; f < 3; f++) {
      candPrices[f] = NormalizeDouble(
         (direction == 1) ? impHigh - fibs[f] * range
                           : impLow  + fibs[f] * range, digits);
      if(direction == 1  && candPrices[f] >= ask) continue;
      if(direction == -1 && candPrices[f] <= bid) continue;
      // v2.0: Max distance cap for fib entries
      double fibDist = MathAbs(candPrices[f] - (direction == 1 ? ask : bid)) / pipVal;
      if(fibDist > PendingMaxEntryDistPips) continue;
      if(HasPendingNearPrice(sym, direction, candPrices[f], PendingSR_ZonePips)) continue;
      double tp     = FindTPLevelSym(sym, candPrices[f], direction, srLevels, srCount);
      double tpPips = MathAbs(tp - candPrices[f]) / pipVal;
      if(tpPips < PendingMinTP_Pips) continue;
      candValid[f] = true;
      candTP[f]    = tp;
   }

   // ── Step 2: pick best — prefer fib closest to an S/R level (confluence)
   //           fallback: deepest valid fib (61.8% → 50% → 38.2%)
   int    bestIdx    = -1;
   double bestSRDist = DBL_MAX;
   double srTol      = PendingSR_ZonePips * 3.0 * pipVal; // confluence proximity window

   for(int f = 0; f < 3; f++) {
      if(!candValid[f]) continue;
      for(int s = 0; s < srCount; s++) {
         double dist = MathAbs(candPrices[f] - srLevels[s]);
         if(dist < srTol && dist < bestSRDist) {
            bestSRDist = dist;
            bestIdx    = f;
         }
      }
   }
   // No S/R confluence — fallback to deepest valid fib
   if(bestIdx < 0) {
      for(int f = 2; f >= 0; f--) {
         if(candValid[f]) { bestIdx = f; break; }
      }
   }

   if(bestIdx < 0) {
      Log(sym + ": [Fib] No valid fib level found — skip");
      return;
   }

   // ── Step 3: place the single chosen fib order ────────────────────
   double candidate = candPrices[bestIdx];
   double tp2       = candTP[bestIdx];
   double sl        = (direction == 1) ? NormalizeDouble(candidate - PendingSL_Pips * pipVal, digits)
                                       : NormalizeDouble(candidate + PendingSL_Pips * pipVal, digits);
   string tag       = "Fib" + fibLabels[bestIdx];
   string reason    = (bestSRDist < DBL_MAX) ? "SR+Fib" : "FibOnly";
   string comment   = (direction == 1 ? "SMP_Buy_" : "SMP_Sell_") + tag;
   if(StringLen(comment) > 31) comment = StringSubstr(comment, 0, 31);

   Log(sym + ": [" + tag + "/" + reason + "] Placing " + (direction==1?"BUY LIMIT":"SELL LIMIT") +
       " Entry=" + DoubleToString(candidate, digits) +
       " SL=" + DoubleToString(MathAbs(candidate-sl)/pipVal,1) + "p" +
       " TP=" + DoubleToString(MathAbs(tp2-candidate)/pipVal,1) + "p");

   double lots = LotSize;
   int tk = OrderSend(sym, orderType, lots, candidate, slippage,
                      sl, tp2, comment, AutoMagicNumber, expiration, arrowClr);
   if(tk > 0) {
      Log(sym + ": [" + tag + "/" + reason + "] Placed Ticket=" + IntegerToString(tk));
      MarkAlertBadge();
   } else {
      Log(sym + ": [" + tag + "] FAILED err=" + IntegerToString(GetLastError()));
      ResetLastError();
   }
}

// Loop all Tradeable Now pairs and place impulse pending orders
void PlaceImpulsePendingOrders() {
   if(!AutoTradingActive()) return;
   if(!AutoPlacePending)    return;
   for(int i = 0; i < PairsCount; i++) {
      string sym   = Pairs[i];
      string pbase = StringSubstr(sym, 0, 3);
      string pquote= StringSubstr(sym, 3, 3);

      // H1 authority check (always required)
      int h1Dir = GetDirectionFromBiasLabels(GetBiasLabel(pbase), GetBiasLabel(pquote));
      if(h1Dir == 0) continue;

      // NOTE: M15 alignment is checked inside PlaceImpulsePendingForPair() for Pass 2 (Fib) only.
      // Pass 1 (SwingExt) always runs on H1 alone — do NOT gate the whole call here.
      PlaceImpulsePendingForPair(sym, h1Dir);
   }
}

//+------------------------------------------------------------------+
//| INITIALIZATION                                                    |
//+------------------------------------------------------------------+
int OnInit() {
   Log("SwingMaster Pro v2.0 initializing...");
   
   // Load Telegram credentials from external file
   if(!LoadTelegramConfig()) {
      Log("WARNING: Telegram not configured yet. Edit " + TG_CONFIG_FILE + " in MQL4/Files/ then reattach EA.");
      // No hardcoded fallback
   }
   
   // Build pairs
   BuildPairsUniverse();
   ArrayInitialize(g_spreadHighLogAt, 0);
   ArrayInitialize(g_spreadWideLogAt, 0);

   // Initialize balance tracking — use equity (not balance) so Today P/L and
   // drawdown correctly account for any carried-over floating positions.
   dayStartBalance = AccountEquity();

   // Rebuild recovery hedge state from existing open orders (survives EA re-attach)
   RebuildRecoveryState();

   // Create UI
   CreateChartPanel();
   CreateTestButton();
   UpdateChartPanel();

   Log("Initialization complete. Pairs: " + IntegerToString(PairsCount));
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| DEINITIALIZATION                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   // Clean up objects (match actual names/prefixes used by CreateLabel/CreateChartPanel)
   DeleteObjectsByPrefix("Panel");  // PanelBG, PanelTitle, etc.
   DeleteObjectsByPrefix("Lbl");    // LblBalance, LblToday, LblOrd*, LblTrade_*, etc.
   DeleteObjectsByPrefix("SMP_SIG_");
   ObjectDelete(0, "AlertBadge");
   ObjectDelete(0, "btnTest");
   ObjectDelete(0, "btnScan");
   ObjectDelete(0, "btnAlerts");
}

// Helper: delete chart objects by prefix (MQL4 has no native prefix delete)
void DeleteObjectsByPrefix(const string prefix) {
   // Explicit overload to avoid compiler ambiguity
   int total = ObjectsTotal(0, 0, -1); // chart 0, main window, all object types
   for(int i = total - 1; i >= 0; i--) {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix, 0) == 0) ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| MAIN TICK FUNCTION                                                |
//+------------------------------------------------------------------+
void OnTick() {
   // --- Normal operation ---
   UpdatePairCache();  // refresh indicator cache once per tick (reused by panel/alerts/orders)
   UpdateRiskTracking();
   int uiSec = PanelRefreshSeconds;
   if(uiSec < 1) uiSec = 1;
   if(g_lastUIRefresh == 0 || (TimeCurrent() - g_lastUIRefresh) >= uiSec) {
      UpdateChartPanel();
      UpdateAlertBadge();
      g_lastUIRefresh = TimeCurrent();
   }
   CheckDrawdownAlerts();
   CheckTrailingStopAlerts();
   ManageRecoveryHedge();
   CheckPendingOrderHealth();
   CheckNewsAlerts();

   // Periodic pending refill — re-place orders cancelled manually or expired mid-candle.
   // Runs every 5 min independent of H1 close. Safe: PlaceImpulsePendingForPair() has all guards.
   if(AutoPlacePending && AutoTradingActive()) {
      if(g_lastRefillCheck == 0 || (TimeCurrent() - g_lastRefillCheck) >= 300) {
         g_lastRefillCheck = TimeCurrent();
         PlaceImpulsePendingOrders();
      }
   }

   // Bias panel: send every 15 min on new M15 candle
   datetime m15Bar = iTime(Symbol(), PERIOD_M15, 0);
   if(m15Bar != lastScorecardSend) {
      lastScorecardSend = m15Bar;
      SendTelegram(BuildBiasPanelMessage());
   }

   // --- Continue normal tick logic ---

   datetime h1 = iTime(Symbol(), PERIOD_H1, 0);
   if(h1 != lastScanTime) {
      lastScanTime = h1;
      int hour = TimeHour(TimeCurrent());
      if(hour == 0 && TimeDayOfWeek(TimeCurrent()) != 0 && TimeDayOfWeek(TimeCurrent()) != 6) {
         dayStartBalance = AccountEquity(); // equity snapshot so Today P/L = today's actual change
         drawdownWarningSet = false;
         drawdownLimitSent = false;
      }
      if(!IsDrawdownOK()) {
         Log("Trading paused - drawdown limit reached");
         return;
      }
      CheckSessionAlert();

      // Refresh average spreads every H1 scan (EMA-smooth so baseline stays current)
      for(int spi = 0; spi < PairsCount; spi++) {
         double spNow = GetSpreadPips(Pairs[spi]);
         if(spNow > 0) AvgSpreads[spi] = (AvgSpreads[spi] > 0) ? (AvgSpreads[spi] * 0.9 + spNow * 0.1) : spNow;
      }

      // Place impulse swing pending orders for all Tradeable Now pairs
      PlaceImpulsePendingOrders();
   }

}

// Manual on-demand alert scan (bypass internal timers)
void RunAlertChecksNow() {
   // Reset ALL check timers so every function runs immediately
   lastTrailingCheck = 0;
   lastNewsCheck = 0;
   lastPendingHealthCheck = 0;

   CheckTrailingStopAlerts();
   CheckPendingOrderHealth();
   CheckNewsAlerts();
   PlaceImpulsePendingOrders();
}

//+------------------------------------------------------------------+
//| CHART EVENTS                                                      |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
   if(id == CHARTEVENT_OBJECT_CLICK) {

      if(sparam == "btnTest") {
         // Send a connectivity/config test alert to Telegram
         SendTestAlert();
         ObjectSetInteger(0, "btnTest", OBJPROP_STATE, false);
         ChartRedraw();
      }

      else if(sparam == "btnScan") {
         lastScanTime = 0;
         SendTelegram(BuildBiasPanelMessage());
         lastScorecardSend = iTime(Symbol(), PERIOD_M15, 0); // prevent double-send on next tick
         ObjectSetInteger(0, "btnScan", OBJPROP_STATE, false);
         ChartRedraw();
      }

      else if(sparam == "btnAlerts") {
         // Run all alert checks immediately (bypass timers)
         RunAlertChecksNow();
         ObjectSetInteger(0, "btnAlerts", OBJPROP_STATE, false);
         ChartRedraw();
      }

   }
}
//+------------------------------------------------------------------+
