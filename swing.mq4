//+------------------------------------------------------------------+
//|                                           SwingMasterPro.mq4     |
//|                  Professional Swing Trading Signal System        |
//|                    (c) 2026 - Multi-Timeframe Analysis           |
//+------------------------------------------------------------------+
#property copyright "SwingMaster Pro v1.0"
#property link      "https://t.me/SwingMasterPro"
#property version   "1.0"
#property strict

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
// Telegram Settings (LOAD FROM EXTERNAL FILE FOR SECURITY)
input string   TG_CONFIG_FILE     = "SwingBias_Config.txt";  // Config file in MQL4/Files/
// SECURITY: do not ship secrets in source; require external config
string   TG_BOT_TOKEN       = "";  // Loaded from config
string   TG_CHAT_ID         = "";  // Loaded from config
input int MagicNumber = 20260215; // Unique magic number for this EA
input bool EnableBiasFlipHedge = true; // Enable bias-flip hedge logic
input bool AutoHedgeOnBiasFlip = true; // Auto-place hedge on bias flip

// Risk Management
input double   MaxDailyRiskPercent = 5.0;      // Max daily risk %
input double   MaxRiskPerTradePercent = 2.0;   // Max risk per trade %
input double   MaxDrawdownPercent  = 5.0;      // Max drawdown % (stop trading)
input double   DrawdownWarning     = 3.0;      // Drawdown warning %
input bool     AllowHQRiskBypass   = true;     // Allow HQ signals even if daily risk maxed
input int      HQRiskBypassMinQuality = 4;     // HQ bypass: min quality stars
input int      HQRiskBypassMinSRTouches = 3;   // HQ bypass: min S/R touches
input double   HQRiskBypassMinRR   = 1.5;      // HQ bypass: min R:R
input bool     UseFixedLotLadder   = true;     // Use fixed lot ladder by account size
input double   LotLadderUSDStep    = 1000.0;   // Account step for lot ladder
input double   LotPerLadderStep    = 0.01;     // Lots added per step
input double   LotMinFloor         = 0.0;      // Minimum lot floor (0=use ladder only)
input double   LotMaxCap           = 0.0;      // Maximum lot cap (0=off)

// Drawdown Recovery Mode
input bool     UseDrawdownRecoveryMode   = true;  // Reduce lot size during drawdown recovery
input double   DDRecoveryLotMultiplier   = 0.5;   // Lot multiplier in recovery (0.5 = 50% size)
input double   DDRecoveryThresholdPct    = 80.0;  // Exit recovery when balance is X% of prior peak

// Trade Filters
input int      SignalMode         = 0;        // 0=Relaxed,1=Standard,2=Strict,3=Custom
input double   MaxSpreadPips      = 3.2;       // Max spread allowed (pips)
input double   MinSLPips          = 80.0;      // Optional minimum SL distance (pips), 0=ATR-based only
input double   SL_ATRBaseMult     = 1.5;       // Base ATR multiplier for minimum SL floor
input double   SL_JPYBoost        = 1.10;      // Additional SL floor boost for JPY pairs
input double   SL_OverlapBoost    = 1.15;      // Additional SL floor boost during London-NY overlap
input double   SL_WideSpreadBoost = 1.10;      // Additional SL floor boost when spread is unusually wide
input double   SL_WideSpreadRatio = 1.80;      // Wide spread trigger vs average spread
input double   SL_MaxPipsCap      = 0.0;       // Optional cap for min SL floor in pips (0=off)
input double   StrictMaxSLPips    = 0.0;       // Strict max SL (pips) (0=off)
input double   StrictMinRR        = 1.1;       // Strict minimum R:R (0=off)
input double   MinRR              = 1.1;       // Minimum R:R for signals
input bool     EnableRRFilter     = true;      // Enforce RR rules (MinRR/StrictMinRR/JPY/Correlation RR)
input bool     SkipCorrelatedIfOpen = true;   // Skip signals if correlated open trade exists
input bool     AllowCorrelatedHighQuality = true; // Allow correlated only if HQ
input double   CorrelatedMinRR    = 1.5;       // HQ rule: min R:R for correlated
input int      CorrelatedMinSRTouches = 2;    // HQ rule: S/R touches (>=2 = MODERATE)
input int      CorrelatedMinQuality = 2;      // HQ rule: min quality (stars)
input int      HedgeMinQuality    = 2;        // Hedge rule: min quality (stars)
input double   HedgeMinRR         = 1.2;      // Hedge rule: min R:R
input double   HedgeLotMultiplier = 0.60;     // Hedge size vs current lots
input double   HedgeMinLots       = 0.05;     // Minimum hedge lots (0=off)
input bool     EnableBiasFlipExitAlert = true; // Exit alert when bias flips (no hedge)
input bool     JPY_HQ_Only        = true;     // Only allow high-quality JPY trades
input double   JPY_MinRR          = 1.5;      // JPY HQ rule: min R:R
input int      JPY_MinQuality     = 3;        // JPY HQ rule: min quality (stars)
input int      JPY_MinSRTouches   = 2;        // JPY HQ rule: min S/R touches (>=2 = MODERATE)
input int      MinEntrySRTouches  = 1;        // Minimum S/R touches for entry levels
input int      ATRPeriod          = 14;        // ATR period
input double   TP1_RR             = 1.2;       // Take Profit R:R ratio
input double   MinTP_ATR_Mult     = 1.2;       // Minimum TP (ATR multiplier)
input double   MaxTP_ATR_Mult     = 3.5;       // Maximum TP (ATR multiplier)
input double   MinTPPips          = 18.0;      // Minimum TP in pips (skip if < this)
input bool     UseATRTPFallback   = true;      // Use ATR-based TP when SR TP is missing/too small
input double   MaxLateEntryPips   = 15.0;      // Strict skip if price moves beyond this [Swing: 15]
input double   PendingStaleMaxPips = 80.0;     // Strict cancel if stale pending is too far [Swing: 80]

// Session Filter
input bool     UseLondonSession   = true;      // Trade London session
input bool     UseNYSession       = true;      // Trade NY session
input bool     AllowOffSessionSignals = false;  // Send signals outside session filter
input int      LondonStartHour    = 8;         // London start (GMT)
input int      LondonEndHour      = 16;        // London end (GMT)
input int      NYStartHour        = 13;        // NY start (GMT)
input int      NYEndHour          = 21;        // NY end (GMT)

// Pullback Settings
input int      RSI_Period         = 14;        // RSI period
input int      RSI_BuyZoneLow     = 35;        // RSI buy zone low [Swing: 35-55]
input int      RSI_BuyZoneHigh    = 55;        // RSI buy zone high [Swing: 35-55]
input int      RSI_SellZoneLow    = 45;        // RSI sell zone low [Swing: 45-65]
// --- LOCK HEDGE SYSTEM INPUTS ---
input bool     EnableManualLock      = true;    // Allow manual lock/unlock
input bool     EnableAutoLock        = true;    // Allow auto lock triggers
input double   LockDrawdownPercent  = 5.0;     // Auto lock if drawdown % reached (0=off)
input double   LockDrawdownAmount   = 0.0;     // Auto lock if drawdown $ reached (0=off)
input bool     LockOnBiasFlip       = true;    // Auto lock if bias flips
input int      LockBiasFlipPersistMins = 15;   // Bias-flip must persist for X mins before lock [Swing: 15]
input int      LockCooldownMinutes  = 30;      // Cooldown between lock/unlock state changes [Swing: 30]
input double   LockHedgeMaxSpreadPips = 4.0;   // Max spread to allow lock hedge placement (0=off)
input bool     LockOnNews           = true;    // Auto lock before high-impact news
input bool     EnableManualUnlock   = true;    // Allow manual unlock
input bool     EnableAutoUnlock     = true;    // Allow auto unlock triggers
input bool     UnlockOnBiasRealign  = true;    // Auto unlock if bias realigns
input bool     UnlockIfNoManagedPositions = true; // Auto unlock if only hedge remains (main positions closed)
input bool     UnlockOnProfit       = true;    // Auto unlock if locked position returns to break-even/profit
input double   UnlockProfitBufferPercent = 1.0; // Require this equity buffer above balance for unlock-on-profit
input int      MinLockHoldMinutes   = 90;      // Minimum lock hold time before auto-unlock checks [Swing: 90]
input int      UnlockAfterMinutes   = 0;       // Auto unlock after X minutes (0=off)
input int      RSI_SellZoneHigh   = 65;        // RSI sell zone high [Swing: 45-65]
input double   EMA_PullbackATR    = 0.5;       // Price within X ATR of EMA

// Trailing Stop Alert Settings
input double   TrailingTriggerPips = 60.0;     // Alert when profit >= this (pips) [Swing: 60-80]
input double   BreakEvenBufferPips = 15.0;     // Suggested SL buffer beyond entry (pips) [Swing: 15-20]
input bool     UseATRTrailSuggestion = true;   // Use ATR-based trailing suggestion
input double   ATRTrailMult       = 1.5;       // ATR multiplier for trailing suggestion [Swing: 1.5]
input double   PartialCloseAtPips = 0.0;       // Suggest partial close when profit >= this (0=off)
input double   PartialClosePct    = 50.0;      // Suggested partial close % at TP1 S/R [Swing: 50%]
input bool     AutoPartialClose   = true;      // Auto partial close at trigger (requires auto mode)
input bool     UseSRBasedPartialTP = true;     // Auto partial close 50% at next S/R TP1 level
input bool     EnableSLAlerts     = true;      // Master toggle for SL-related alerts

// Breakout Settings
input int      BreakoutLookback   = 20;        // Candles to find swing high/low
input double   RetestBuffer       = 0.3;       // Retest buffer (ATR multiplier)

// Pair Filtering
input bool     TradeExoticPairs   = false;     // Allow exotic pairs (low liquidity)
input double   MaxSpreadMultiplier = 2.5;      // Max spread vs average spread
input bool     UseNewsFilter      = true;      // Avoid trading during high-impact news
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
input bool     ShowChartSignals   = true;      // Show buy/sell signals on chart
input color    BuySignalColor     = clrLime;
input color    SellSignalColor    = clrRed;
input bool     ShowAlertBadge     = true;      // Show alert badge on chart
input int      AlertBadgeMinutes  = 15;        // How long to keep badge (minutes)
input color    AlertBadgeColor    = clrGold;
input bool     JournalSendDetailed = true;     // Send detailed journal to Telegram
input bool     JournalSendCompact  = false;    // Send compact journal to Telegram
input bool     QuietFilterLogs    = true;      // Reduce repeated spread/filter logs
input int      FilterLogCooldownMins = 15;     // Cooldown for repeated filter logs per symbol
input int      PanelRefreshSeconds = 2;        // UI refresh throttle (seconds)
input bool     VerboseTelegramLogs = false;    // Log Telegram success payloads/details
input int      LogVerbosity = 1;               // 0=Errors only, 1=Warnings+Errors, 2=All logs
input int      TelegramMinSendIntervalSec = 1; // Min seconds between Telegram sends (throttle)
input int      TelegramParseErrorCooldownSec = 300; // Force plain text for X sec after HTML parse error

// Safety: manual trading only (prevents any future accidental OrderSend/OrderModify usage)
input bool ManualModeOnly = false;     // Manual alerts only (no auto trades)
input bool EnableAutoTrading = true;   // Allow auto trading when ManualModeOnly=false
input int  AutoMagicNumber = 20260215; // Magic number for auto trades
input int  AutoSlippagePips = 3;       // Slippage (pips) for auto trades
input bool AutoTrailStops = true;      // Auto move SL on trailing alert
input bool AutoCancelStalePending = true; // Auto cancel stale pending orders
input bool AutoCancelPendingOnBiasFlip = true; // Auto cancel pending if bias no longer aligns
input bool AutoCancelPendingOnNeutralBias = false; // Cancel pending when bias becomes neutral
input int  PendingBiasFlipPersistMins = 5; // Bias mismatch must persist before cancel (0=immediate)
input bool AutoCancelPendingOnWideSpread = false; // Auto cancel pending if spread condition fails
input bool AutoCancelPendingOnFarPrice = true; // Auto cancel pending if price too far from entry
input int  PendingHealthCheckSeconds = 300; // Health check interval for pending orders
input bool AutoTightenSLOnBiasFlip = true; // Auto tighten SL on bias flip
input bool AutoTightenSLOnReversal = true; // Auto tighten SL on reversal warning
input bool AutoCancelPendingOnNews = true; // Auto cancel pendings during news
input bool AutoTightenSLOnNews = false;    // Auto tighten SL during news
input bool AutoManageOnlyMagic = false;    // Auto actions only manage EA's magic orders
input bool AutoBlockOnlyMagic = true;      // Duplicate check only considers EA's magic orders

input double ConfluenceThreshold = 0.45; // used by HasPairTFConfluence()
input int    MinTouchSpacingBars = 6;    // used by CountSRTouches()
input int    SRLookbackBars      = 500;  // S/R lookback window (H1 bars) [Swing: 500 = ~3 weeks]
input double SRToleranceATRMult  = 0.6;  // S/R tolerance multiplier (ATR)
input bool   ForceSRRefreshEachScan = false; // Force S/R refresh every scan

// ADX Trending Filter
input bool   UseADXFilter        = true;  // Enable ADX trending filter (skip ranging markets)
input int    ADXPeriod           = 14;    // ADX period
input double MinADX              = 20.0;  // Minimum ADX for trend (below = ranging, skip signal)
input double StrongTrendADX      = 30.0;  // ADX above this = strong trend (relax SR touches req)

// Max Trades Per Currency (exposure control)
input bool   UseMaxTradesPerCurrency = true; // Limit concurrent trades per currency
input int    MaxTradesPerCurrency    = 2;    // Max open trades sharing same base/quote currency

// Alert Flood Control
input bool   OnlyAlertOnNewSignals   = true;  // Only send scorecard if new/changed signals
input int    SignalChangeCooldownMins = 120;   // Min minutes before re-alerting same pair+direction

// Effective (mode-adjusted) settings
double g_StrictMinRR = StrictMinRR;
double g_MinRR = MinRR;
double g_ConfluenceThreshold = ConfluenceThreshold;
int    g_MinEntrySRTouches = MinEntrySRTouches;
int    g_CorrelatedMinQuality = CorrelatedMinQuality;
int    g_JPY_MinQuality = JPY_MinQuality;
double g_TP1_RR = TP1_RR;
double g_MinTP_ATR_Mult = MinTP_ATR_Mult;
double g_MaxTP_ATR_Mult = MaxTP_ATR_Mult;
double g_MinTPPips = MinTPPips;

bool TradingAllowed() {
   if(ManualModeOnly || !EnableAutoTrading) return false;
   if(!IsDrawdownOK()) return false;
   return true;
}

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

void ApplySignalMode() {
   if(SignalMode == 3) { // Custom
      g_StrictMinRR = StrictMinRR;
      g_MinRR = MinRR;
      g_ConfluenceThreshold = ConfluenceThreshold;
      g_MinEntrySRTouches = MinEntrySRTouches;
      g_CorrelatedMinQuality = CorrelatedMinQuality;
      g_JPY_MinQuality = JPY_MinQuality;
      g_TP1_RR = TP1_RR;
      g_MinTP_ATR_Mult = MinTP_ATR_Mult;
      g_MaxTP_ATR_Mult = MaxTP_ATR_Mult;
      g_MinTPPips = MinTPPips;
      g_lastSignalMode = SignalMode;
      return;
   }

   if(SignalMode == 0) { // Relaxed
      g_StrictMinRR = 1.3;
      g_MinRR = 1.3;
      g_ConfluenceThreshold = 0.30;
      g_MinEntrySRTouches = 1;
      g_CorrelatedMinQuality = 2;
      g_JPY_MinQuality = 2;
      g_TP1_RR = 1.3;
      g_MinTP_ATR_Mult = 1.0;
      g_MaxTP_ATR_Mult = 3.0;
      g_MinTPPips = 30.0;
   } else if(SignalMode == 2) { // Strict
      g_StrictMinRR = 1.5;
      g_MinRR = 1.5;
      g_ConfluenceThreshold = 0.55;
      g_MinEntrySRTouches = 3;
      g_CorrelatedMinQuality = 3;
      g_JPY_MinQuality = 3;
      g_TP1_RR = 1.5;
      g_MinTP_ATR_Mult = 1.5;
      g_MaxTP_ATR_Mult = 4.0;
      g_MinTPPips = 50.0;
   } else { // Standard
      g_StrictMinRR = 1.4;
      g_MinRR = 1.4;
      g_ConfluenceThreshold = 0.45;
      g_MinEntrySRTouches = 2;
      g_CorrelatedMinQuality = 3;
      g_JPY_MinQuality = 3;
      g_TP1_RR = 1.4;
      g_MinTP_ATR_Mult = 1.2;
      g_MaxTP_ATR_Mult = 3.5;
      g_MinTPPips = 40.0;
   }

   g_lastSignalMode = SignalMode;
}

string GetSignalModeLabel() {
   if(SignalMode == 0) return "RELAXED";
   if(SignalMode == 1) return "STANDARD";
   if(SignalMode == 2) return "STRICT";
   return "CUSTOM";
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

datetime lastScanTime = 0;
datetime lastDailySummary = 0;
double   dayStartBalance = 0;
double   weekStartBalance = 0;
double   monthStartBalance = 0;
datetime g_lastUIRefresh = 0;

// Drawdown recovery state
bool     g_inDDRecovery    = false;  // True while in reduced-lot recovery mode
double   g_ddPeakBalance   = 0;     // Highest balance seen (for DD% calculation)

datetime g_spreadHighLogAt[64];
datetime g_spreadWideLogAt[64];
datetime g_volCacheBarTime[64];
bool     g_volCacheValue[64];
datetime g_autoTradingCacheAt = 0;
bool     g_autoTradingCacheVal = false;
bool     g_autoTradingCacheValid = false;
datetime g_pairDirCacheAt = 0;
int      g_pairDirCache[64];
datetime g_openCorrCacheAt = 0;
string   g_openCorrBase[128];
string   g_openCorrQuote[128];
int      g_openCorrCount = 0;

// Daily trade tracking
int todayWins = 0;
int todayLosses = 0;
double todayPips = 0;
// --- LOCK HEDGE STATE ---
bool   IsLockHedgeActive = false;      // True if lock hedge is active
datetime LockHedgeActivatedTime = 0;   // Time lock was activated
string  LockHedgeReason = "";           // Reason for lock activation
double  LockHedgeDrawdownAtLock = 0.0; // Drawdown at lock activation
datetime LastLockStateChangeTime = 0;  // Last lock/unlock timestamp for cooldown

// --- LOCK HEDGE FUNCTIONS ---
bool IsManagedMarketOrder() {
   int type = OrderType();
   if(type != OP_BUY && type != OP_SELL) return false;
   int mg = OrderMagicNumber();
   return (mg == MagicNumber || mg == AutoMagicNumber);
}

bool IsOrderDirectionAlignedWithBias(string sym, int orderType) {
   int biasDir = GetTradeDirection(sym);
   if(biasDir == 0) return false;
   int orderDir = (orderType == OP_BUY) ? 1 : -1;
   return (orderDir == biasDir);
}

string GetBiasMismatchKey(string sym, int orderType) {
   string dir = (orderType == OP_BUY) ? "B" : "S";
   return "SMP_LOCK_MIS_" + sym + "_" + dir;
}

string GetPendingBiasMismatchKey(string sym, int ticket) {
   return "SMP_PEND_MIS_" + sym + "_" + IntegerToString(ticket);
}

bool BiasFlipPersisted(string sym, int orderType, int persistMins) {
   if(persistMins <= 0) return true;
   string key = GetBiasMismatchKey(sym, orderType);
   datetime now = TimeCurrent();

   if(IsOrderDirectionAlignedWithBias(sym, orderType)) {
      if(GlobalVariableCheck(key)) GlobalVariableDel(key);
      return false;
   }

   if(!GlobalVariableCheck(key)) {
      GlobalVariableSet(key, (double)now);
      return false;
   }

   datetime since = (datetime)GlobalVariableGet(key);
   return ((now - since) >= persistMins * 60);
}

void LockHedge(string reason, bool bypassCooldown = false) {
   if(IsLockHedgeActive) return;
   if(!bypassCooldown && LockCooldownMinutes > 0 && LastLockStateChangeTime > 0) {
      if((TimeCurrent() - LastLockStateChangeTime) < LockCooldownMinutes * 60) {
         Log("LockHedge skipped: cooldown active (" + IntegerToString(LockCooldownMinutes) + " min).");
         return;
      }
   }

   // Build net managed exposure per symbol (BUY lots - SELL lots)
   string syms[64];
   double netLots[64];
   double existingHedgeBuy[64];
   double existingHedgeSell[64];
   ArrayInitialize(netLots, 0.0);
   ArrayInitialize(existingHedgeBuy, 0.0);
   ArrayInitialize(existingHedgeSell, 0.0);
   int symCount = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;

      int mg = OrderMagicNumber();
      if(mg != MagicNumber && mg != AutoMagicNumber) continue;

      string s = OrderSymbol();
      int idx = -1;
      for(int k = 0; k < symCount; k++) {
         if(syms[k] == s) { idx = k; break; }
      }
      if(idx < 0) {
         if(symCount >= 64) continue;
         idx = symCount;
         syms[symCount] = s;
         symCount++;
      }

      if(type == OP_BUY) netLots[idx] += OrderLots();
      else netLots[idx] -= OrderLots();
   }

   if(symCount == 0) {
      Log("LockHedge skipped: no managed market exposure.");
      return;
   }

   // Read existing lock-hedge positions (MagicNumber+999)
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;
      if(OrderMagicNumber() != MagicNumber + 999) continue;

      string s = OrderSymbol();
      int idx = -1;
      for(int k = 0; k < symCount; k++) {
         if(syms[k] == s) { idx = k; break; }
      }
      if(idx < 0) {
         if(symCount >= 64) continue;
         idx = symCount;
         syms[symCount] = s;
         symCount++;
      }

      if(type == OP_BUY) existingHedgeBuy[idx] += OrderLots();
      else existingHedgeSell[idx] += OrderLots();
   }

   int hedgesPlaced = 0;
   bool hasNetExposure = false;
   bool allCovered = true;

   // Hedge only missing net exposure (prevents over-hedging)
   for(int i = 0; i < symCount; i++) {
      double net = netLots[i];
      if(MathAbs(net) <= 0.0000001) continue;
      hasNetExposure = true;

      string osym = syms[i];
      int hedgeType = (net > 0) ? OP_SELL : OP_BUY;
      double targetLots = MathAbs(net);
      double existingLots = (hedgeType == OP_BUY) ? existingHedgeBuy[i] : existingHedgeSell[i];

      if(targetLots <= existingLots + 0.0000001) continue;

      if(LockHedgeMaxSpreadPips > 0 && GetSpreadPips(osym) > LockHedgeMaxSpreadPips) {
         allCovered = false;
         continue;
      }

      double needLots = targetLots - existingLots;
      double minLot = MarketInfo(osym, MODE_MINLOT);
      double maxLot = MarketInfo(osym, MODE_MAXLOT);
      double lotStep = MarketInfo(osym, MODE_LOTSTEP);

      if(maxLot > 0 && needLots > maxLot) needLots = maxLot;
      if(lotStep > 0) needLots = MathFloor(needLots / lotStep) * lotStep;
      needLots = NormalizeDouble(needLots, 2);
      if(needLots < minLot) {
         allCovered = false;
         continue;
      }

      double price = (hedgeType == OP_BUY) ? MarketInfo(osym, MODE_ASK) : MarketInfo(osym, MODE_BID);
      int slippage = SlippageToPoints(osym, AutoSlippagePips);
      int ticket = OrderSend(osym, hedgeType, needLots, price, slippage, 0, 0, "LockHedge", MagicNumber+999, 0, clrRed);
      if(ticket > 0) {
         hedgesPlaced++;
         existingLots += needLots;
      } else {
         allCovered = false;
         Log("LockHedge send failed: " + osym + " err=" + IntegerToString(GetLastError()));
         ResetLastError();
      }

      if(targetLots > existingLots + 0.0000001) allCovered = false;
   }

   if(!hasNetExposure) {
      Log("LockHedge skipped: net managed exposure is zero.");
      return;
   }

   // Allow activation if all exposure is already covered (hedgesPlaced may be 0 if pre-existing hedge orders suffice)
   if(hedgesPlaced <= 0 && !allCovered) {
      Log("LockHedge skipped: could not place required hedge orders (spread/lots issue).");
      return;
   }

   IsLockHedgeActive = true;
   LockHedgeActivatedTime = TimeCurrent();
   LastLockStateChangeTime = LockHedgeActivatedTime;
   LockHedgeReason = reason;
   LockHedgeDrawdownAtLock = AccountBalance() - AccountEquity();
   // Pause trading logic handled elsewhere
   // Telegram alert handled elsewhere
}

bool HasOpenLockHedgeOrders() {
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;
      if(OrderMagicNumber() == MagicNumber + 999) return true;
   }
   return false;
}

void UnlockHedge(string reason) {
   if(!IsLockHedgeActive) return;
   int closeAttempts = 0;
   int closeFailures = 0;

   // Close all hedge orders (MagicNumber+999)
   for(int i=OrdersTotal()-1; i>=0; i--) {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         int type = OrderType();
         if(type != OP_BUY && type != OP_SELL) continue;
         if(OrderMagicNumber() != MagicNumber+999) continue;

         string osym = OrderSymbol();
         double price = (type == OP_BUY) ? MarketInfo(osym, MODE_BID) : MarketInfo(osym, MODE_ASK);
         int slippage = SlippageToPoints(osym, AutoSlippagePips);
         closeAttempts++;
         bool ok = OrderClose(OrderTicket(), OrderLots(), price, slippage, clrGreen);
         if(!ok) {
            closeFailures++;
            Log("UnlockHedge close failed ticket=" + IntegerToString(OrderTicket()) + " err=" + IntegerToString(GetLastError()));
            ResetLastError();
         }
      }
   }

   // Verify no hedge orders remain
   int remainingHedges = 0;
   for(int i=OrdersTotal()-1; i>=0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;
      if(OrderMagicNumber() == MagicNumber+999) remainingHedges++;
   }

   if(remainingHedges > 0) {
      // Partial close — do NOT block forever; clear lock state and warn so trader can act manually
      Log("UnlockHedge WARNING: " + IntegerToString(remainingHedges) + " hedge order(s) could not be closed. Lock state cleared — close manually.");
   } else {
      Log("UnlockHedge completed. Attempts=" + IntegerToString(closeAttempts) + ", failures=" + IntegerToString(closeFailures));
   }

   IsLockHedgeActive = false;
   LockHedgeActivatedTime = 0;
   LastLockStateChangeTime = TimeCurrent();
   LockHedgeReason = "";
   LockHedgeDrawdownAtLock = 0.0;
   // Resume trading logic handled elsewhere
   // Telegram alert handled elsewhere
}

// Risk tracking
double   currentRiskAmount = 0;
double   currentRiskPercent = 0;
int      currentRiskNoSLTrades = 0;
int      currentRiskTrackedTrades = 0;

// Breakout tracking
struct BreakoutLevel {
   string symbol;
   double level;
   int    direction; // 1=buy, -1=sell
   datetime breakTime;
   bool   waitingRetest;
   bool   retestConfirmed;
};
BreakoutLevel BreakoutLevels[64];
int BreakoutCount = 0;

// S/R Level tracking
struct SRLevel {
   string symbol;
   double level;
   int    touches;      // Number of times price touched this level
   int    type;         // 1=support, -1=resistance
   datetime lastTouch;  // Last time price touched this level
   bool   isActive;     // Is this level still valid
};
SRLevel SRLevels[1024];  // Store up to 1024 S/R levels across all pairs
int SRCount = 0;

// Correlation pairs
string CorrelatedPairs[10][2] = {
   {"EURUSD", "GBPUSD"},
   {"EURUSD", "USDCHF"},
   {"AUDUSD", "NZDUSD"},
   {"USDJPY", "EURJPY"},
   {"GBPUSD", "GBPJPY"},
   {"AUDUSD", "AUDJPY"},
   {"EURUSD", "EURJPY"},
   {"USDCAD", "USDCHF"},
   {"GBPJPY", "EURJPY"},
   {"NZDUSD", "NZDJPY"}
};

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

// Skip label tracking (chart highlight)
datetime lastSkipLabelTime = 0;
string lastSkipLabelText = "";

// Reversal & Expiration tracking
datetime lastReversalCheck = 0;
datetime lastExpirationCheck = 0;
datetime lastPendingHealthCheck = 0;
datetime lastHedgeCheck = 0;
datetime lastExitCheck = 0;
int pendingOrderMaxHours = 8;       // Alert if pending order not triggered after X hours

// Weekly summary tracking
datetime lastWeeklySummary = 0;
datetime lastMidWeekSummary = 0;  // Wednesday mid-week mini-summary
int weeklyTradesCount = 0;
double weeklyPipsGained = 0;
double weeklyPipsLost = 0;

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
bool isNewsPeriod = false;
datetime newsBlockUntil = 0;
string currentNewsEvent = "";  // Store current news event name
datetime lastNewsFetch = 0;
bool liveNewsLoaded = false;
string lastNewsError = "";
int lastNewsErrorCode = 0;

int g_lastSignalMode = -1;

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

void RefreshPairDirectionCache() {
   datetime now = TimeCurrent();
   if(g_pairDirCacheAt == now) return;
   g_pairDirCacheAt = now;

   for(int i = 0; i < 64; i++) g_pairDirCache[i] = 0;
   for(int i = 0; i < PairsCount; i++) {
      g_pairDirCache[i] = GetTradeDirection(Pairs[i]);
   }
}

void RefreshOpenCorrelationCache() {
   datetime now = TimeCurrent();
   if(g_openCorrCacheAt == now) return;
   g_openCorrCacheAt = now;
   g_openCorrCount = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;

      string other = OrderSymbol();
      if(StringLen(other) < 6) continue;

      if(g_openCorrCount < 128) {
         g_openCorrBase[g_openCorrCount] = StringSubstr(other, 0, 3);
         g_openCorrQuote[g_openCorrCount] = StringSubstr(other, 3, 3);
         g_openCorrCount++;
      }
   }
}

string TrimQuotes(string s) {
   StringTrimLeft(s);
   StringTrimRight(s);
   if(StringLen(s) >= 2) {
      if((StringSubstr(s, 0, 1) == "\"") && (StringSubstr(s, StringLen(s) - 1, 1) == "\"")) {
         s = StringSubstr(s, 1, StringLen(s) - 2);
      }
   }
   return s;
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
         if(sign == "+") offsetMinutes = offsetMinutes; else offsetMinutes = -offsetMinutes;
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

// S/R refresh scheduling (keeps levels current, prevents SRLevels[] exhaustion)
datetime lastSRRefresh = 0;
int SRRefreshHours = 4; // Refresh every 4 hours (swing intraday accuracy)

// Forward declarations (needed because SR refresh helpers call these before their definitions)
void DetectSRLevels(string sym);
void ClearSRLevels(string sym);

// Compact SRLevels[] by removing inactive entries
void CompactSRLevels() {
   int write = 0;
   for(int read = 0; read < SRCount; read++) {
      if(!SRLevels[read].isActive) continue;
      if(write != read) SRLevels[write] = SRLevels[read];
      write++;
   }
   SRCount = write;
}

// Refresh S/R for all pairs periodically (or force on demand)
void RefreshSRLevelsIfNeeded(bool force = false) {
   if(!force && !ForceSRRefreshEachScan && SRCount > 0 && lastSRRefresh != 0 && (TimeCurrent() - lastSRRefresh) < SRRefreshHours * 3600) return;
   lastSRRefresh = TimeCurrent();

   // Mark old levels inactive, then rebuild per symbol
   for(int i = 0; i < PairsCount; i++) {
      ClearSRLevels(Pairs[i]);
      PreloadHistory(Pairs[i]);
      DetectSRLevels(Pairs[i]);
   }

   CompactSRLevels();
   Log("S/R refreshed. Active levels: " + IntegerToString(SRCount));

   if(DEBUG_PRINT) {
      for(int i = 0; i < PairsCount; i++) {
         string sym = Pairs[i];
         int count = 0;
         for(int j = 0; j < SRCount; j++) {
            if(SRLevels[j].symbol == sym && SRLevels[j].isActive) count++;
         }
         Log("S/R levels for " + sym + ": " + IntegerToString(count));
      }
   }
}

// --- Alert cooldown (anti-spam) ---
int AlertCooldownMins = 30;
bool g_manualAlertRun = false;
bool g_manualAlertSent = false;
datetime g_tgRateLimitUntil = 0;
datetime g_tgRateLimitLogAt = 0;
bool g_tgLastWasRateLimited = false;
bool g_tgLastBlockedByThrottle = false;
bool g_tgLastWasEmptyMsg = false;    // set when Telegram returns 400 message text is empty
datetime g_tgLastSendAt = 0;
datetime g_tgForcePlainUntil = 0;

struct AlertStamp {
   string key;
   datetime lastSent;
};
AlertStamp AlertStamps[256];
int AlertStampCount = 0;

// Last pullback confirmation cache (for message enrichment)
string g_lastConfirmSym = "";
int    g_lastConfirmDir = 0;
string g_lastConfirmMsg = "";
string g_lastConfirmInfo = "";

// Signal change tracking for alert flood control
struct SignalStamp {
   string pairDir;     // e.g. "EURUSD_BUY"
   int    quality;     // last quality score sent
   int    priority;    // last priority sent
   datetime lastSent;
   datetime firstSeen; // when this signal was first detected
};
SignalStamp g_signalStamps[256];
int g_signalStampCount = 0;

// Returns true if this pair+direction signal is NEW or CHANGED since last alert
bool IsSignalNewOrChanged(string sym, int direction, int quality, int priority) {
   string key = sym + (direction == 1 ? "_BUY" : "_SELL");
   datetime now = TimeCurrent();
   int cooldownSec = SignalChangeCooldownMins * 60;

   for(int i = 0; i < g_signalStampCount; i++) {
      if(g_signalStamps[i].pairDir == key) {
         bool changed = (g_signalStamps[i].quality != quality || g_signalStamps[i].priority != priority);
         bool cooledDown = ((now - g_signalStamps[i].lastSent) >= cooldownSec);
         if(changed || cooledDown) {
            // Reset firstSeen if quality/priority changed (fresh signal)
            if(changed) g_signalStamps[i].firstSeen = now;
            g_signalStamps[i].quality   = quality;
            g_signalStamps[i].priority  = priority;
            g_signalStamps[i].lastSent  = now;
            return true;
         }
         return false;
      }
   }
   // New entry
   if(g_signalStampCount < 256) {
      g_signalStamps[g_signalStampCount].pairDir   = key;
      g_signalStamps[g_signalStampCount].quality   = quality;
      g_signalStamps[g_signalStampCount].priority  = priority;
      g_signalStamps[g_signalStampCount].lastSent  = now;
      g_signalStamps[g_signalStampCount].firstSeen = now;
      g_signalStampCount++;
   }
   return true;
}

// Returns how long (hours) this signal has been active. 0 if never seen.
double GetSignalAgeHours(string sym, int direction) {
   string key = sym + (direction == 1 ? "_BUY" : "_SELL");
   datetime now = TimeCurrent();
   for(int i = 0; i < g_signalStampCount; i++) {
      if(g_signalStamps[i].pairDir == key) {
         if(g_signalStamps[i].firstSeen <= 0) return 0;
         return (double)(now - g_signalStamps[i].firstSeen) / 3600.0;
      }
   }
   return 0;
}

bool CanSendAlert(const string key, const int cooldownMins) {
   datetime now = TimeCurrent();
   for(int i = 0; i < AlertStampCount; i++) {
      if(AlertStamps[i].key == key) {
         if(!g_manualAlertRun && (now - AlertStamps[i].lastSent) < cooldownMins * 60) return false;
         AlertStamps[i].lastSent = now;
         return true;
      }
   }
   if(AlertStampCount < 256) {
      AlertStamps[AlertStampCount].key = key;
      AlertStamps[AlertStampCount].lastSent = now;
      AlertStampCount++;
      return true;
   }
   // If full, allow (fail-open) to avoid blocking forever
   return true;
}

//+------------------------------------------------------------------+
//| UTILITY FUNCTIONS                                                 |
//+------------------------------------------------------------------+
void Log(string s) { 
   if(!DEBUG_PRINT) return;

   string t = s;
   StringToUpper(t);

   int level = 2; // info
   if(StringFind(t, "ERROR") >= 0 || StringFind(t, "FAILED") >= 0 || StringFind(t, "✗") >= 0) level = 0;
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

double PipValue(string sym) {
   double point = MarketInfo(sym, MODE_POINT);
   int digits = (int)MarketInfo(sym, MODE_DIGITS);
   if(digits == 3 || digits == 5) return point * 10;
   return point;
}

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

bool HasOpenOrderForDirection(string sym, int direction) {
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != sym) continue;
      if(AutoBlockOnlyMagic) {
         int mg = OrderMagicNumber();
         if(mg != AutoMagicNumber && mg != MagicNumber) continue;
      }
      int type = OrderType();
      if(direction == 1) {
         if(type == OP_BUY || type == OP_BUYLIMIT || type == OP_BUYSTOP) return true;
      } else if(direction == -1) {
         if(type == OP_SELL || type == OP_SELLLIMIT || type == OP_SELLSTOP) return true;
      }
   }
   return false;
}

int GetBiasCodeForDirection(string sym, int direction) {
   int curDir = GetTradeDirection(sym);
   int prio = GetPairPriority(sym);
   if(curDir == 0 || prio == 0) return 0; // NONE
   bool aligned = (direction == curDir);
   if(!aligned) return 4; // FLIP
   return prio; // 1=P1, 2=P2, 3=P3
}

string BiasLabelFromCode(int code) {
   if(code == 1) return "P1";
   if(code == 2) return "P2";
   if(code == 3) return "P3";
   if(code == 4) return "FLIP";
   return "NONE";
}

string BiasDirLabel(int dir) {
   if(dir == 1) return "BUY";
   if(dir == -1) return "SELL";
   return "INVALID";
}

void StoreEntrySnapshot(int ticket, string sym, int direction) {
   int biasCode = GetBiasCodeForDirection(sym, direction);
   bool conf = HasPairTFConfluence(sym, direction);
   int biasDir = GetTradeDirection(sym);

   double qEntry = 0, qSL = 0, qTP = 0;
   int quality = GetPullbackQualityV2(sym, qEntry, qSL, qTP);
   int srTouches = 0;
   double srLevel = 0;
   bool atSR = IsPriceAtSR(sym, direction, srLevel, srTouches);
   if(!atSR) {
      srLevel = GetNearestSRLevel(sym, direction, srTouches);
   }
   double pipValSnap = PipValue(sym);
   double slPips = (qEntry > 0 && qSL > 0 && pipValSnap > 0) ? MathAbs(qEntry - qSL) / pipValSnap : 0;
   double tpPips = (qEntry > 0 && qTP > 0 && pipValSnap > 0) ? MathAbs(qTP - qEntry) / pipValSnap : 0;
   double rr = (slPips > 0) ? tpPips / slPips : 0;
   bool filtersOk = IsSpreadOK(sym) && IsVolatilityOK(sym) && !GetNewsNowCached();
   bool hq = (quality >= 3 && srTouches >= 3 && (!EnableRRFilter || rr >= g_MinRR) && filtersOk);

   string key = "SMP_ENTRY_" + IntegerToString(ticket) + "_";
   GlobalVariableSet(key + "BIAS", biasCode);
   GlobalVariableSet(key + "CONF", conf ? 1.0 : 0.0);
   GlobalVariableSet(key + "HQ", hq ? 1.0 : 0.0);
   GlobalVariableSet(key + "DIR", (double)biasDir);
}

bool LoadEntrySnapshot(int ticket, int &biasCode, bool &conf, bool &hq) {
   string key = "SMP_ENTRY_" + IntegerToString(ticket) + "_";
   if(!GlobalVariableCheck(key + "BIAS")) return false;
   biasCode = (int)GlobalVariableGet(key + "BIAS");
   conf = (GlobalVariableCheck(key + "CONF") && GlobalVariableGet(key + "CONF") > 0.5);
   hq = (GlobalVariableCheck(key + "HQ") && GlobalVariableGet(key + "HQ") > 0.5);
   return true;
}

bool LoadEntryBiasDir(int ticket, int &biasDir) {
   string key = "SMP_ENTRY_" + IntegerToString(ticket) + "_";
   if(!GlobalVariableCheck(key + "DIR")) return false;
   biasDir = (int)GlobalVariableGet(key + "DIR");
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

void NormalizeStopsForBroker(string sym, int direction, double refPrice, double &sl, double &tp) {
   int digits = (int)MarketInfo(sym, MODE_DIGITS);
   double point = MarketInfo(sym, MODE_POINT);
   int stopLevelPts = (int)MarketInfo(sym, MODE_STOPLEVEL);
   if(point <= 0 || stopLevelPts <= 0) {
      sl = NormalizeDouble(sl, digits);
      tp = NormalizeDouble(tp, digits);
      return;
   }
   double minDist = stopLevelPts * point;

   if(direction == 1) {
      if(sl > 0 && sl > (refPrice - minDist)) sl = refPrice - minDist;
      if(tp > 0 && tp < (refPrice + minDist)) tp = refPrice + minDist;
   } else if(direction == -1) {
      if(sl > 0 && sl < (refPrice + minDist)) sl = refPrice + minDist;
      if(tp > 0 && tp > (refPrice - minDist)) tp = refPrice - minDist;
   }

   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);
}

bool PlaceAutoMarketOrder(string sym, int direction, double lots, double sl, double tp) {
   if(lots <= 0) return false;
   double price = (direction == 1) ? MarketInfo(sym, MODE_ASK) : MarketInfo(sym, MODE_BID);
   NormalizeStopsForBroker(sym, direction, price, sl, tp);
   int type = (direction == 1) ? OP_BUY : OP_SELL;
   int slippage = SlippageToPoints(sym, AutoSlippagePips);
   int ticket = OrderSend(sym, type, lots, price, slippage, sl, tp, "SMP Auto", AutoMagicNumber, 0, clrAqua);
   if(ticket < 0) {
      Log("Auto trade failed: " + sym + " err=" + IntegerToString(GetLastError()));
      ResetLastError();
      return false;
   }
   StoreEntrySnapshot(ticket, sym, direction);
   Log("Auto trade placed: " + sym + " ticket=" + IntegerToString(ticket));
   return true;
}

bool PlaceAutoPendingOrder(string sym, int direction, double lots, double entry, double sl, double tp) {
   if(lots <= 0 || entry <= 0) return false;
   double currentPrice = (direction == 1) ? MarketInfo(sym, MODE_ASK) : MarketInfo(sym, MODE_BID);
   int type = OP_BUYLIMIT;
   if(direction == 1) {
      type = (entry < currentPrice) ? OP_BUYLIMIT : OP_BUYSTOP;
   } else {
      type = (entry > currentPrice) ? OP_SELLLIMIT : OP_SELLSTOP;
   }
   NormalizeStopsForBroker(sym, direction, entry, sl, tp);
   int slippage = SlippageToPoints(sym, AutoSlippagePips);
   int ticket = OrderSend(sym, type, lots, entry, slippage, sl, tp, "SMP Auto", AutoMagicNumber, 0, clrAqua);
   if(ticket < 0) {
      Log("Auto pending failed: " + sym + " err=" + IntegerToString(GetLastError()));
      ResetLastError();
      return false;
   }
   StoreEntrySnapshot(ticket, sym, direction);
   Log("Auto pending placed: " + sym + " ticket=" + IntegerToString(ticket));
   return true;
}

bool AutoModifySL(int ticket, double newSL) {
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return false;
   if(AutoManageOnlyMagic && OrderMagicNumber() != AutoMagicNumber) return false;
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

bool AutoCancelPending(int ticket) {
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return false;
   if(AutoManageOnlyMagic && OrderMagicNumber() != AutoMagicNumber) return false;
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
   if(AutoManageOnlyMagic && OrderMagicNumber() != AutoMagicNumber) return false;
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

bool IsBiasFlipHedgeDone(int ticket) {
   string key = "SMP_HEDGE_" + IntegerToString(ticket);
   return GlobalVariableCheck(key);
}

//+------------------------------------------------------------------+
//| SR-BASED PARTIAL TP (close 50% at first S/R target)              |
//+------------------------------------------------------------------+
bool CheckSRBasedPartialTP(int ticket) {
   if(!UseSRBasedPartialTP) return false;
   if(!AutoPartialClose || !AutoTradingActive()) return false;
   if(IsPartialCloseDone(ticket)) return false;
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return false;
   if(AutoManageOnlyMagic && OrderMagicNumber() != AutoMagicNumber) return false;

   int type = OrderType();
   if(type != OP_BUY && type != OP_SELL) return false;

   string sym = OrderSymbol();
   double entry = OrderOpenPrice();
   double lots = OrderLots();
   double pipVal = PipValue(sym);
   int direction = (type == OP_BUY) ? 1 : -1;
   double currentPrice = (type == OP_BUY) ? MarketInfo(sym, MODE_BID) : MarketInfo(sym, MODE_ASK);

   // Get next S/R TP1 level
   double srTP1 = GetNextSRForTP(sym, direction, entry);
   if(srTP1 <= 0) return false;

   // Check if price reached TP1 S/R level
   bool reached = false;
   if(type == OP_BUY  && currentPrice >= srTP1) reached = true;
   if(type == OP_SELL && currentPrice <= srTP1) reached = true;
   if(!reached) return false;

   // Calculate partial close lots (use PartialClosePct, default 50%)
   double minLot = MarketInfo(sym, MODE_MINLOT);
   double lotStep = MarketInfo(sym, MODE_LOTSTEP);
   double closePct = (PartialClosePct > 0) ? PartialClosePct : 50.0;
   double closeLots = lots * (closePct / 100.0);
   if(lotStep > 0) closeLots = MathFloor(closeLots / lotStep) * lotStep;
   closeLots = NormalizeDouble(closeLots, 2);
   if(closeLots < minLot || (lots - closeLots) < minLot) return false;

   bool ok = AutoPartialCloseTrade(ticket, closeLots);
   if(ok) {
      MarkPartialCloseDone(ticket);
      double srTP1Pips = (pipVal > 0) ? MathAbs(srTP1 - entry) / pipVal : 0;
      Log("SR Partial TP executed: " + sym + " ticket=" + IntegerToString(ticket) +
          " at S/R " + DoubleToStrClean(srTP1, (int)MarketInfo(sym, MODE_DIGITS)) +
          " (" + DoubleToStrClean(srTP1Pips, 0) + "p) lots=" + DoubleToStrClean(closeLots, 2));
      int digits = (int)MarketInfo(sym, MODE_DIGITS);
      string dir = (type == OP_BUY) ? "BUY" : "SELL";
      string notif = "<b>PARTIAL TP HIT (S/R TP1)</b>" + TGTag() + "\n";
      notif += "<code>" + sym + " " + dir + "</code> #" + IntegerToString(ticket) + "\n";
      notif += "Closed " + DoubleToStrClean(closePct, 0) + "% at S/R TP1: " + DoubleToStrClean(srTP1, digits) + "\n";
      notif += "+" + DoubleToStrClean(srTP1Pips, 0) + " pips locked\n";
      notif += "Remaining: " + DoubleToStrClean(lots - closeLots, 2) + " lots\n";
      notif += "ACTION: Move SL to breakeven. Let remainder run to TP2.\n";
      SendTelegram(notif);
   }
   return ok;
}

void MarkBiasFlipHedgeDone(int ticket) {
   string key = "SMP_HEDGE_" + IntegerToString(ticket);
   GlobalVariableSet(key, (double)TimeCurrent());
}

double ComputeHedgeLots(string sym, double baseLots, bool &forcedMinHedge) {
   forcedMinHedge = false;
   double minLot = MarketInfo(sym, MODE_MINLOT);
   double lotStep = MarketInfo(sym, MODE_LOTSTEP);
   double hedgeLotsRaw = baseLots * HedgeLotMultiplier;
   double hedgeLots = (lotStep > 0) ? MathFloor(hedgeLotsRaw / lotStep) * lotStep : hedgeLotsRaw;
   hedgeLots = NormalizeDouble(hedgeLots, 2);

   if(HedgeMinLots > 0 && hedgeLots < HedgeMinLots) {
      hedgeLots = HedgeMinLots;
      forcedMinHedge = true;
   }
   if(hedgeLots < minLot) {
      hedgeLots = minLot;
      forcedMinHedge = true;
   }
   if(lotStep > 0) hedgeLots = MathFloor(hedgeLots / lotStep) * lotStep;
   hedgeLots = NormalizeDouble(hedgeLots, 2);
   return hedgeLots;
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

bool IsExoticPair(string sym) {
   // Compare exact 6-char base against majors (no substring matching)
   string baseSym = StringSubstr(sym, 0, 6);
   int total = ArraySize(MajorPairs);
   for(int i = 0; i < total; i++) {
      if(baseSym == MajorPairs[i]) return false;
   }
   return true;
}

void PreloadHistory(string sym) {
   int tfs[3] = {PERIOD_H1, PERIOD_H4, PERIOD_D1};
   for(int i = 0; i < 3; i++) {
      iMA(sym, tfs[i], 20, 0, MODE_EMA, PRICE_CLOSE, 1);
      iMA(sym, tfs[i], 50, 0, MODE_EMA, PRICE_CLOSE, 1);
      iRSI(sym, tfs[i], RSI_Period, PRICE_CLOSE, 1);
      iATR(sym, tfs[i], ATRPeriod, 1);
   }
}

void BuildPairsUniverse() {
   PairsCount = 0;
   for(int i = 0; i < 7; i++) {
      for(int j = 0; j < 7; j++) {
         if(i != j) {
            string sym = ResolveSymbol(Currencies[i] + Currencies[j]);
            if(sym != "") {
               // Filter exotic pairs if disabled
               if(!TradeExoticPairs && IsExoticPair(sym)) {
                  Log("Skipping exotic pair: " + sym);
                  continue;
               }
               // Trade only allowed pairs list
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
   // Single spread sample at init to avoid blocking Sleep during OnInit.
   // Baseline is refreshed every H1 scan via the spread EMA update loop in OnTick.
   double sp = GetSpreadPips(sym);
   return (sp > 0) ? sp : 0;
}

//+------------------------------------------------------------------+
//| CURRENCY STRENGTH CALCULATION (Weighted)                          |
//+------------------------------------------------------------------+
double GetEMADiff(string sym, int tf) {
   double ema20 = iMA(sym, tf, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
   double ema50 = iMA(sym, tf, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
   double atr = iATR(sym, tf, ATRPeriod, 0);
   if(atr == 0) return 0;
   return (ema20 - ema50) / atr; // Normalized
}

int GetTFSign(string sym, int tf) {
   double diff = GetEMADiff(sym, tf);
   if(diff > 0.1) return 1;
   if(diff < -0.1) return -1;
   return 0;
}

// Weighted currency strength: D1*3 + H4*2 + H1*1
double CurrencyStrength(string cur, int tf) {
   double sum = 0;
   for(int i = 0; i < PairsCount; i++) {
      string p = Pairs[i];
      string base = StringSubstr(p, 0, 3);
      string quote = StringSubstr(p, 3, 3);
      double diff = GetEMADiff(p, tf);
      if(base == cur) sum += diff;
      if(quote == cur) sum -= diff;
   }
   return sum;
}

double WeightedCurrencyStrength(string cur) {
   double d1 = CurrencyStrength(cur, PERIOD_D1) * 3;
   double h4 = CurrencyStrength(cur, PERIOD_H4) * 2;
   double h1 = CurrencyStrength(cur, PERIOD_H1) * 1;
   return d1 + h4 + h1;
}

double CurrencyTFScoreNorm(string cur, int tf) {
   double sum = 0;
   int count = 0;
   for(int i = 0; i < PairsCount; i++) {
      string p = Pairs[i];
      string base = StringSubstr(p, 0, 3);
      string quote = StringSubstr(p, 3, 3);
      int sign = GetTFSign(p, tf);
      if(sign == 0) continue;

      if(base == cur) { sum += sign; count++; }
      else if(quote == cur) { sum -= sign; count++; }
   }
   return (count > 0) ? (sum / count) : 0.0;
}

// NEW LOGIC: STRONG if any TF >= +4, WEAK if any TF <= -4
string GetBiasLabel(string cur) {
   double d1 = CurrencyTFScoreNorm(cur, PERIOD_D1);
   double h4 = CurrencyTFScoreNorm(cur, PERIOD_H4);
   double h1 = CurrencyTFScoreNorm(cur, PERIOD_H1);

   double maxScore = MathMax(d1, MathMax(h4, h1));
   double minScore = MathMin(d1, MathMin(h4, h1));

   // Thresholds tuned for normalized score
   bool hasStrong = (maxScore >= 0.35);
   bool hasWeak   = (minScore <= -0.35);

   if(hasStrong && hasWeak) {
      if(MathAbs(maxScore) >= MathAbs(minScore)) return "STRONG";
      else return "WEAK";
   }
   if(hasStrong) return "STRONG";
   if(hasWeak) return "WEAK";
   return "NEUTRAL";
}

string GetBiasEmoji(string cur) {
   string bias = GetBiasLabel(cur);
   if(bias == "STRONG") return "^";
   if(bias == "WEAK") return "v";
   return "-";
}

// --- Confluence tuning ---

bool HasPairTFConfluence(string sym, int direction) {
   string base = StringSubstr(sym, 0, 3);
   string quote = StringSubstr(sym, 3, 3);

   double bD1 = CurrencyTFScoreNorm(base, PERIOD_D1);
   double bH4 = CurrencyTFScoreNorm(base, PERIOD_H4);
   double bH1 = CurrencyTFScoreNorm(base, PERIOD_H1);

   double qD1 = CurrencyTFScoreNorm(quote, PERIOD_D1);
   double qH4 = CurrencyTFScoreNorm(quote, PERIOD_H4);
   double qH1 = CurrencyTFScoreNorm(quote, PERIOD_H1);

   if(direction == 1) { // BUY: base strong across TFs AND quote weak across TFs
      if(bD1 >= g_ConfluenceThreshold && bH4 >= g_ConfluenceThreshold && bH1 >= g_ConfluenceThreshold &&
         qD1 <= -g_ConfluenceThreshold && qH4 <= -g_ConfluenceThreshold && qH1 <= -g_ConfluenceThreshold)
         return true;
   } else if(direction == -1) { // SELL: base weak AND quote strong
      if(bD1 <= -g_ConfluenceThreshold && bH4 <= -g_ConfluenceThreshold && bH1 <= -g_ConfluenceThreshold &&
         qD1 >= g_ConfluenceThreshold && qH4 >= g_ConfluenceThreshold && qH1 >= g_ConfluenceThreshold)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| MULTI-TIMEFRAME CONFLUENCE CHECK                                  |
//+------------------------------------------------------------------+
// Returns true if ALL timeframes agree on direction (D1 + H4 + H1)
bool HasTFConfluence(string cur) {
   double d1 = CurrencyTFScoreNorm(cur, PERIOD_D1);
   double h4 = CurrencyTFScoreNorm(cur, PERIOD_H4);
   double h1 = CurrencyTFScoreNorm(cur, PERIOD_H1);
   
   // All positive (STRONG confluence)
   if(d1 >= 0.35 && h4 >= 0.35 && h1 >= 0.35) return true;
   
   // All negative (WEAK confluence)
   if(d1 <= -0.35 && h4 <= -0.35 && h1 <= -0.35) return true;
   
   return false;
}

// Get confluence label for display
string GetConfluenceLabel(string cur) {
   if(HasTFConfluence(cur)) return "[CONFLUENCE]";
   return "";
}

//+------------------------------------------------------------------+
//| CORRELATION WARNING                                               |
//+------------------------------------------------------------------+
// Check if a pair is correlated with another signal
string GetCorrelationWarning(string sym, int direction) {
   string warnings = "";
   RefreshPairDirectionCache();
   
   // Extract currency codes
   string base = StringSubstr(sym, 0, 3);
   string quote = StringSubstr(sym, 3, 3);
   
   // Check for correlated pairs in current signals
   for(int i = 0; i < PairsCount; i++) {
      if(Pairs[i] == sym) continue;  // Skip same pair
      
      string otherBase = StringSubstr(Pairs[i], 0, 3);
      string otherQuote = StringSubstr(Pairs[i], 3, 3);
      
      // Positive correlation: same base or same quote
      bool positiveCorr = (base == otherBase || quote == otherQuote);
      
      // Inverse correlation: EURUSD vs USDCHF
      bool inverseCorr = (base == otherQuote || quote == otherBase);
      
      if(positiveCorr || inverseCorr) {
         int otherDir = g_pairDirCache[i];
         if(otherDir == 0) continue;
         
         // Same direction on positively correlated = warning
         if(positiveCorr && otherDir == direction) {
            warnings = "! Correlated: " + Pairs[i];
            break;
         }
         // Opposite direction on inverse correlation = warning  
         if(inverseCorr && otherDir != direction) {
            warnings = "! Inverse: " + Pairs[i];
            break;
         }
      }
   }
   
   return warnings;
}

// Check if there is an open trade correlated with this symbol
bool HasOpenCorrelatedTrade(string sym) {
   string base = StringSubstr(sym, 0, 3);
   string quote = StringSubstr(sym, 3, 3);
   RefreshOpenCorrelationCache();
   
   for(int i = 0; i < g_openCorrCount; i++) {
      string otherBase = g_openCorrBase[i];
      string otherQuote = g_openCorrQuote[i];
      
      bool positiveCorr = (base == otherBase || quote == otherQuote);
      bool inverseCorr = (base == otherQuote || quote == otherBase);
      
      if(positiveCorr || inverseCorr) return true;
   }
   
   return false;
}

// Check if pair contains JPY
bool IsJPYPair(string sym) {
   return (StringFind(sym, "JPY") >= 0);
}

//+------------------------------------------------------------------+
//| ADX TRENDING FILTER                                               |
//+------------------------------------------------------------------+
// Returns true if market is trending (ADX >= MinADX threshold)
bool IsMarketTrending(string sym) {
   if(!UseADXFilter) return true; // Filter disabled = always allow
   double adx = iADX(sym, PERIOD_H1, ADXPeriod, PRICE_CLOSE, MODE_MAIN, 1);
   return (adx >= MinADX);
}

// Returns true if trend is STRONG (ADX >= StrongTrendADX) — relax SR touches requirement
bool IsStrongTrend(string sym) {
   if(!UseADXFilter) return false;
   double adx = iADX(sym, PERIOD_H1, ADXPeriod, PRICE_CLOSE, MODE_MAIN, 1);
   return (adx >= StrongTrendADX);
}

string GetADXLabel(string sym) {
   if(!UseADXFilter) return "";
   double adx = iADX(sym, PERIOD_H1, ADXPeriod, PRICE_CLOSE, MODE_MAIN, 1);
   if(adx >= StrongTrendADX) return "ADX:" + DoubleToStrClean(adx, 0) + "[STRONG]";
   if(adx >= MinADX)         return "ADX:" + DoubleToStrClean(adx, 0) + "[TREND]";
   return "ADX:" + DoubleToStrClean(adx, 0) + "[RANGING]";
}

//+------------------------------------------------------------------+
//| MAX TRADES PER CURRENCY (EXPOSURE CONTROL)                        |
//+------------------------------------------------------------------+
// Count open market trades that involve a given currency (as base or quote)
int CountOpenTradesForCurrency(string currency) {
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;
      string osym = OrderSymbol();
      if(StringLen(osym) < 6) continue;
      string base  = StringSubstr(osym, 0, 3);
      string quote = StringSubstr(osym, 3, 3);
      if(base == currency || quote == currency) count++;
   }
   return count;
}

// Returns true if allowed to add another trade involving this pair's currencies
bool IsWithinCurrencyExposureLimit(string sym) {
   if(!UseMaxTradesPerCurrency) return true;
   if(StringLen(sym) < 6) return true;
   string base  = StringSubstr(sym, 0, 3);
   string quote = StringSubstr(sym, 3, 3);
   if(CountOpenTradesForCurrency(base)  >= MaxTradesPerCurrency) return false;
   if(CountOpenTradesForCurrency(quote) >= MaxTradesPerCurrency) return false;
   return true;
}

//+------------------------------------------------------------------+
//| H4 CANDLE DIRECTION CONFIRMATION                                  |
//+------------------------------------------------------------------+
// Returns true if H4 last closed candle direction agrees with trade direction
bool IsH4CandleAligned(string sym, int direction) {
   double h4Close = iClose(sym, PERIOD_H4, 1);
   double h4EMA20 = iMA(sym, PERIOD_H4, 20, 0, MODE_EMA, PRICE_CLOSE, 1);
   if(direction == 1)  return (h4Close > h4EMA20); // BUY: H4 price above EMA20
   if(direction == -1) return (h4Close < h4EMA20); // SELL: H4 price below EMA20
   return false;
}

// OLD CORRELATION WARNING (DEPRECATED)
string GetCorrelationWarningOld(string sym, int direction) {
   string warnings = "";
   
   // Define correlated pairs
   string correlations[10][2] = {
      {"EURUSD", "GBPUSD"},
      {"EURUSD", "USDCHF"},
      {"AUDUSD", "NZDUSD"},
      {"USDJPY", "EURJPY"},
      {"GBPUSD", "GBPJPY"},
      {"AUDUSD", "AUDJPY"},
      {"EURUSD", "EURJPY"},
      {"USDCAD", "USDCHF"},
      {"GBPJPY", "EURJPY"},
      {"NZDUSD", "NZDJPY"}
   };
   
   // Extract base pair name (remove suffix)
   string baseSym = StringSubstr(sym, 0, 6);
   
   for(int i = 0; i < 10; i++) {
      string pair1 = correlations[i][0];
      string pair2 = correlations[i][1];
      
      // Check if current symbol matches either pair
      if(StringFind(baseSym, pair1) >= 0 || StringFind(pair1, baseSym) >= 0) {
         // Find the correlated pair in our signals
         for(int j = 0; j < PairsCount; j++) {
            string otherSym = Pairs[j];
            string otherBase = StringSubstr(otherSym, 0, 6);
            
            if(StringFind(otherBase, pair2) >= 0 || StringFind(pair2, otherBase) >= 0) {
               int otherDir = GetTradeDirection(otherSym);
               if(otherDir == direction && otherDir != 0) {
                  warnings = "! Correlated: " + otherSym;
                  break;
               }
            }
         }
      }
      else if(StringFind(baseSym, pair2) >= 0 || StringFind(pair2, baseSym) >= 0) {
         for(int j = 0; j < PairsCount; j++) {
            string otherSym = Pairs[j];
            string otherBase = StringSubstr(otherSym, 0, 6);
            
            if(StringFind(otherBase, pair1) >= 0 || StringFind(pair1, otherBase) >= 0) {
               int otherDir = GetTradeDirection(otherSym);
               if(otherDir == direction && otherDir != 0) {
                  warnings = "! Correlated: " + otherSym;
                  break;
               }
            }
         }
      }
      
      if(warnings != "") break;
   }
   
   return warnings;
}

//+------------------------------------------------------------------+
//| NEW: Get pair priority based on currency bias                     |
//+------------------------------------------------------------------+
// Priority: 1 = Strong vs Weak (best), 2 = Strong vs Neutral, 3 = Weak vs Neutral
int GetPairPriority(string sym) {
   string base = StringSubstr(sym, 0, 3);
   string quote = StringSubstr(sym, 3, 3);
   
   string baseBias = GetBiasLabel(base);
   string quoteBias = GetBiasLabel(quote);
   
   // Strong vs Weak = Priority 1 (best)
   if((baseBias == "STRONG" && quoteBias == "WEAK") || 
      (baseBias == "WEAK" && quoteBias == "STRONG")) {
      return 1;
   }
   
   // Strong vs Neutral = Priority 2
   if((baseBias == "STRONG" && quoteBias == "NEUTRAL") || 
      (baseBias == "NEUTRAL" && quoteBias == "STRONG")) {
      return 2;
   }
   
   // Weak vs Neutral = Priority 3
   if((baseBias == "WEAK" && quoteBias == "NEUTRAL") || 
      (baseBias == "NEUTRAL" && quoteBias == "WEAK")) {
      return 3;
   }
   
   // Neutral vs Neutral = No trade
   return 0;
}

//+------------------------------------------------------------------+
//| BIAS ALIGNMENT CHECK (NEW LOGIC)                                  |
//+------------------------------------------------------------------+
bool IsBiasAligned(string sym) {
   return (GetPairPriority(sym) > 0);
}

int GetTradeDirection(string sym) {
   string base = StringSubstr(sym, 0, 3);
   string quote = StringSubstr(sym, 3, 3);

   string baseBias = GetBiasLabel(base);
   string quoteBias = GetBiasLabel(quote);

   // Only trade when biases form an allowed priority
   int prio = GetPairPriority(sym);
   if(prio == 0) return 0;

   // Strong quote => SELL, Strong base => BUY, otherwise decide by which side is WEAK
   // Priority cases:
   // 1) STRONG vs WEAK: buy if base strong, sell if quote strong
   // 2) STRONG vs NEUTRAL: buy if base strong, sell if quote strong
   // 3) WEAK vs NEUTRAL: sell if base weak, buy if quote weak (since quote weak implies base neutral)
   if(baseBias == "STRONG" && (quoteBias == "WEAK" || quoteBias == "NEUTRAL")) return 1;
   if(quoteBias == "STRONG" && (baseBias == "WEAK" || baseBias == "NEUTRAL")) return -1;

   if(baseBias == "NEUTRAL" && quoteBias == "WEAK") return 1;
   if(baseBias == "WEAK" && quoteBias == "NEUTRAL") return -1;

   return 0;
}

//+------------------------------------------------------------------+
//| PULLBACK DETECTION                                                |
//+------------------------------------------------------------------+
int GetPullbackQuality(string sym) {
   if(!IsBiasAligned(sym)) return 0;
   
   int direction = GetTradeDirection(sym);
   if(direction == 0) return 0;
   
   double close = iClose(sym, PERIOD_H1, 0);
   double ema20 = iMA(sym, PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
   double ema50 = iMA(sym, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
   double rsi = iRSI(sym, PERIOD_H1, RSI_Period, PRICE_CLOSE, 0);
   double atr = iATR(sym, PERIOD_H1, ATRPeriod, 0);
   
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
   
   // Condition 4: Candle rejection (wick > body)
   double open = iOpen(sym, PERIOD_H1, 0);
   double high = iHigh(sym, PERIOD_H1, 0);
   double low = iLow(sym, PERIOD_H1, 0);
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

string GetQualityLabel(int quality) {
   if(quality >= 4) return "Pullback Ready";
   if(quality >= 3) return "Approaching Pullback";
   if(quality >= 2) return "Waiting for Pullback";
   return "";
}

//+------------------------------------------------------------------+
//| SUPPORT & RESISTANCE DETECTION (3+ touches = STRONG)              |
//+------------------------------------------------------------------+
double GetSRTolerance(string sym) {
   double atr = iATR(sym, PERIOD_H1, ATRPeriod, 0);
   if(atr > 0) return atr * SRToleranceATRMult;
   double point = MarketInfo(sym, MODE_POINT);
   int digits = (int)MarketInfo(sym, MODE_DIGITS);
   double pip = (digits == 3 || digits == 5) ? point * 10.0 : point;
   return pip * 25.0;
}

int CountActiveSRForSymbol(string sym) {
   int count = 0;
   for(int i = 0; i < SRCount; i++) {
      if(SRLevels[i].symbol != sym) continue;
      if(!SRLevels[i].isActive) continue;
      count++;
   }
   return count;
}

void AddFallbackSRLevels(string sym, int lookback, double tolerance) {
   int bars = iBars(sym, PERIOD_H1);
   if(bars < 10) return;

   int window = MathMin(lookback, bars - 1);
   if(window < 10) return;

   int hi = iHighest(sym, PERIOD_H1, MODE_HIGH, window, 1);
   int lo = iLowest(sym, PERIOD_H1, MODE_LOW, window, 1);

   if(hi >= 0) AddOrUpdateSRLevel(sym, iHigh(sym, PERIOD_H1, hi), -1, iTime(sym, PERIOD_H1, hi), tolerance);
   if(lo >= 0) AddOrUpdateSRLevel(sym, iLow(sym, PERIOD_H1, lo), 1, iTime(sym, PERIOD_H1, lo), tolerance);
}

void AddSyntheticSRLevels(string sym, double tolerance) {
   double close = iClose(sym, PERIOD_H1, 0);
   double atr = iATR(sym, PERIOD_H1, ATRPeriod, 0);
   double point = MarketInfo(sym, MODE_POINT);
   int digits = (int)MarketInfo(sym, MODE_DIGITS);
   double pip = (digits == 3 || digits == 5) ? point * 10.0 : point;
   double step = (atr > 0 ? atr : pip * 25.0);

   AddOrUpdateSRLevel(sym, close - step, 1, TimeCurrent(), tolerance);
   AddOrUpdateSRLevel(sym, close + step, -1, TimeCurrent(), tolerance);
}

void DetectSRLevels(string sym) {
   int lookback = SRLookbackBars;  // Look back window
   int bars = iBars(sym, PERIOD_H1);
   if(bars < 30) {
      Log("S/R low bars " + sym + ": " + IntegerToString(bars));
   }
   if(bars <= lookback + 2) lookback = MathMax(30, bars - 3);
   double tolerance = GetSRTolerance(sym);  // Tolerance for grouping levels
   
   // --- H1 swing highs/lows ---
   for(int i = 2; i < lookback - 2; i++) {
      double high = iHigh(sym, PERIOD_H1, i);
      double low = iLow(sym, PERIOD_H1, i);
      
      // Check if this is a swing high (resistance)
      bool isSwingHigh = true;
      for(int j = 1; j <= 2; j++) {
         if(iHigh(sym, PERIOD_H1, i-j) >= high || iHigh(sym, PERIOD_H1, i+j) >= high) {
            isSwingHigh = false;
            break;
         }
      }
      
      // Check if this is a swing low (support)
      bool isSwingLow = true;
      for(int j = 1; j <= 2; j++) {
         if(iLow(sym, PERIOD_H1, i-j) <= low || iLow(sym, PERIOD_H1, i+j) <= low) {
            isSwingLow = false;
            break;
         }
      }
      
      if(isSwingHigh) AddOrUpdateSRLevel(sym, high, -1, iTime(sym, PERIOD_H1, i), tolerance);
      if(isSwingLow)  AddOrUpdateSRLevel(sym, low,  1,  iTime(sym, PERIOD_H1, i), tolerance);
   }
   
   // Count touches for H1 levels
   CountSRTouches(sym, lookback, tolerance);

   // --- H4 swing highs/lows (key swing levels) ---
   int h4Bars = iBars(sym, PERIOD_H4);
   int h4Lookback = MathMin(120, h4Bars - 3); // ~20 days of H4
   if(h4Lookback >= 6) {
      double h4Tol = tolerance * 1.5; // slightly wider tolerance for H4
      for(int i = 2; i < h4Lookback - 2; i++) {
         double high = iHigh(sym, PERIOD_H4, i);
         double low  = iLow(sym, PERIOD_H4, i);

         bool isSwingHigh = true;
         for(int j = 1; j <= 2; j++) {
            if(iHigh(sym, PERIOD_H4, i-j) >= high || iHigh(sym, PERIOD_H4, i+j) >= high) { isSwingHigh = false; break; }
         }
         bool isSwingLow = true;
         for(int j = 1; j <= 2; j++) {
            if(iLow(sym, PERIOD_H4, i-j) <= low || iLow(sym, PERIOD_H4, i+j) <= low) { isSwingLow = false; break; }
         }

         if(isSwingHigh) AddOrUpdateSRLevel(sym, high, -1, iTime(sym, PERIOD_H4, i), h4Tol);
         if(isSwingLow)  AddOrUpdateSRLevel(sym, low,  1,  iTime(sym, PERIOD_H4, i), h4Tol);
      }
   }

   // --- D1 swing highs/lows (major weekly levels) ---
   int d1Bars = iBars(sym, PERIOD_D1);
   int d1Lookback = MathMin(60, d1Bars - 3); // ~3 months of D1
   if(d1Lookback >= 6) {
      double d1Tol = tolerance * 2.5; // wider tolerance for D1 key levels
      for(int i = 2; i < d1Lookback - 2; i++) {
         double high = iHigh(sym, PERIOD_D1, i);
         double low  = iLow(sym, PERIOD_D1, i);

         bool isSwingHigh = true;
         for(int j = 1; j <= 2; j++) {
            if(iHigh(sym, PERIOD_D1, i-j) >= high || iHigh(sym, PERIOD_D1, i+j) >= high) { isSwingHigh = false; break; }
         }
         bool isSwingLow = true;
         for(int j = 1; j <= 2; j++) {
            if(iLow(sym, PERIOD_D1, i-j) <= low || iLow(sym, PERIOD_D1, i+j) <= low) { isSwingLow = false; break; }
         }

         if(isSwingHigh) AddOrUpdateSRLevel(sym, high, -1, iTime(sym, PERIOD_D1, i), d1Tol);
         if(isSwingLow)  AddOrUpdateSRLevel(sym, low,  1,  iTime(sym, PERIOD_D1, i), d1Tol);
      }
   }

   // Fallback: if no levels detected, use recent range extremes
   if(CountActiveSRForSymbol(sym) == 0) {
      AddFallbackSRLevels(sym, lookback, tolerance);
      CountSRTouches(sym, lookback, tolerance);
   }

   // Last-resort: if still none, seed synthetic SR around price
   if(CountActiveSRForSymbol(sym) == 0) {
      AddSyntheticSRLevels(sym, tolerance);
      CountSRTouches(sym, lookback, tolerance);
   }
}

void AddOrUpdateSRLevel(string sym, double level, int type, datetime touchTime, double tolerance) {
   // Check if level already exists (within tolerance)
   for(int i = 0; i < SRCount; i++) {
      if(SRLevels[i].symbol == sym && SRLevels[i].type == type) {
         if(MathAbs(SRLevels[i].level - level) <= tolerance) {
            // Update existing level - average the price
            SRLevels[i].level = (SRLevels[i].level + level) / 2;
            SRLevels[i].touches++;
            if(touchTime > SRLevels[i].lastTouch) SRLevels[i].lastTouch = touchTime;
            return;
         }
      }
   }
   
   // Add new level
   if(SRCount < 1024) {
      SRLevels[SRCount].symbol = sym;
      SRLevels[SRCount].level = level;
      SRLevels[SRCount].touches = 1;
      SRLevels[SRCount].type = type;
      SRLevels[SRCount].lastTouch = touchTime;
      SRLevels[SRCount].isActive = true;
      SRCount++;
   }
}

// --- S/R touch spacing (reduce inflation) ---

void CountSRTouches(string sym, int lookback, double tolerance) {
   for(int i = 0; i < SRCount; i++) {
      if(SRLevels[i].symbol != sym) continue;
      if(!SRLevels[i].isActive) continue;

      int touches = 0;
      int lastTouchBar = -1000000; // "no touch yet"

      for(int j = lookback - 1; j >= 0; j--) { // oldest -> newest
         double high = iHigh(sym, PERIOD_H1, j);
         double low  = iLow(sym, PERIOD_H1, j);
         double level = SRLevels[i].level;

         if(!(low <= level + tolerance && high >= level - tolerance)) continue;

         // spacing filter (count only if this touch is far enough from last)
         if(lastTouchBar != -1000000 && (lastTouchBar - j) < MinTouchSpacingBars) continue;

         double close = iClose(sym, PERIOD_H1, j);
         double open  = iOpen(sym, PERIOD_H1, j);

         bool bounce = (SRLevels[i].type == 1) ? (close > open) : (close < open);
         if(!bounce) continue;

         touches++;
         lastTouchBar = j;
      }

      if(touches > 0) SRLevels[i].touches = touches;
   }
}

// Get nearest STRONG S/R level for a symbol
double GetNearestSRLevel(string sym, int direction, int &outTouches) {
   double currentPrice = iClose(sym, PERIOD_H1, 0);
   double nearestLevel = 0;
   double nearestDist = 999999;
   outTouches = 0;
   
   for(int i = 0; i < SRCount; i++) {
      if(SRLevels[i].symbol != sym) continue;
      if(!SRLevels[i].isActive) continue;
      if(SRLevels[i].touches < 1) continue;  // At least 1 touch for nearest level
      
      double level = SRLevels[i].level;
      double dist = MathAbs(currentPrice - level);
      
      // For BUY: look for support below current price
      // For SELL: look for resistance above current price
      if(direction == 1 && SRLevels[i].type == 1 && level < currentPrice) {
         if(dist < nearestDist) {
            nearestDist = dist;
            nearestLevel = level;
            outTouches = SRLevels[i].touches;
         }
      }
      else if(direction == -1 && SRLevels[i].type == -1 && level > currentPrice) {
         if(dist < nearestDist) {
            nearestDist = dist;
            nearestLevel = level;
            outTouches = SRLevels[i].touches;
         }
      }
   }
   
   return nearestLevel;
}

double GetNearestSRLevelMinTouches(string sym, int direction, int minTouches, int &outTouches) {
   double currentPrice = iClose(sym, PERIOD_H1, 0);
   double nearestLevel = 0;
   double nearestDist = 999999;
   outTouches = 0;

   for(int i = 0; i < SRCount; i++) {
      if(SRLevels[i].symbol != sym) continue;
      if(!SRLevels[i].isActive) continue;
      if(SRLevels[i].touches < minTouches) continue;

      double level = SRLevels[i].level;
      double dist = MathAbs(currentPrice - level);

      // For BUY: look for support below current price
      // For SELL: look for resistance above current price
      if(direction == 1 && SRLevels[i].type == 1 && level < currentPrice) {
         if(dist < nearestDist) {
            nearestDist = dist;
            nearestLevel = level;
            outTouches = SRLevels[i].touches;
         }
      }
      else if(direction == -1 && SRLevels[i].type == -1 && level > currentPrice) {
         if(dist < nearestDist) {
            nearestDist = dist;
            nearestLevel = level;
            outTouches = SRLevels[i].touches;
         }
      }
   }

   return nearestLevel;
}

// Get S/R strength label
string GetSRStrength(int touches) {
   if(touches >= 4) return "VERY STRONG";
   if(touches >= 3) return "STRONG";
   if(touches >= 2) return "MODERATE";
   return "WEAK";
}

// Get next S/R level for TP target (opposite type from entry)
double GetNextSRForTP(string sym, int direction, double entryLevel) {
   double nextLevel = 0;
   double nearestDist = 999999;
   
   for(int i = 0; i < SRCount; i++) {
      if(SRLevels[i].symbol != sym) continue;
      if(!SRLevels[i].isActive) continue;
      if(SRLevels[i].touches < 1) continue;
      
      double level = SRLevels[i].level;
      
      // For BUY: look for resistance ABOVE entry (TP target)
      if(direction == 1 && SRLevels[i].type == -1 && level > entryLevel) {
         double dist = level - entryLevel;
         if(dist < nearestDist) {
            nearestDist = dist;
            nextLevel = level;
         }
      }
      // For SELL: look for support BELOW entry (TP target)
      else if(direction == -1 && SRLevels[i].type == 1 && level < entryLevel) {
         double dist = entryLevel - level;
         if(dist < nearestDist) {
            nearestDist = dist;
            nextLevel = level;
         }
      }
   }
   
   return nextLevel;
}

// Check if price is at S/R level
bool IsPriceAtSR(string sym, int direction, double &outLevel, int &outTouches) {
   double currentPrice = iClose(sym, PERIOD_H1, 0);
   double tolerance = GetSRTolerance(sym);  // Within 0.5 ATR of level
   
   outLevel = 0;
   outTouches = 0;
   
   for(int i = 0; i < SRCount; i++) {
      if(SRLevels[i].symbol != sym) continue;
      if(!SRLevels[i].isActive) continue;
      if(SRLevels[i].touches < g_MinEntrySRTouches) continue;
      
      double level = SRLevels[i].level;
      
      // For BUY: check if at support
      if(direction == 1 && SRLevels[i].type == 1) {
         if(MathAbs(currentPrice - level) <= tolerance) {
            outLevel = level;
            outTouches = SRLevels[i].touches;
            return true;
         }
      }
      // For SELL: check if at resistance
      else if(direction == -1 && SRLevels[i].type == -1) {
         if(MathAbs(currentPrice - level) <= tolerance) {
            outLevel = level;
            outTouches = SRLevels[i].touches;
            return true;
         }
      }
   }
   
   return false;
}

bool HasPullbackConfirmation(string sym, int direction) {
   // --- Confirmation details for messaging ---
   string confirmDetails = "";

   // --- Info only: Higher timeframe bias (H4)
   int h4Bias = 0;
   if(StringLen(sym) == 6) {
      string base = StringSubstr(sym, 0, 3);
      string quote = StringSubstr(sym, 3, 3);
      string h4BaseBias = GetBiasLabel(base); // Uses H4 in logic
      string h4QuoteBias = GetBiasLabel(quote); // Uses H4 in logic
      if(h4BaseBias == "STRONG" && (h4QuoteBias == "WEAK" || h4QuoteBias == "NEUTRAL")) h4Bias = 1;
      if(h4QuoteBias == "STRONG" && (h4BaseBias == "WEAK" || h4BaseBias == "NEUTRAL")) h4Bias = -1;
      if(h4BaseBias == "NEUTRAL" && h4QuoteBias == "WEAK") h4Bias = 1;
      if(h4BaseBias == "WEAK" && h4QuoteBias == "NEUTRAL") h4Bias = -1;
   }

   // --- Info only: ADX (trend strength)
   double adx = iADX(sym, PERIOD_H1, 14, PRICE_CLOSE, MODE_MAIN, 1);

   // Store info in global for messaging
   string infoMsg = "";
   if(h4Bias == direction && h4Bias != 0) infoMsg += "H4BiasAlign ";
   else if(h4Bias != 0) infoMsg += "H4BiasDiv ";
   infoMsg += "ADX:" + DoubleToStr(adx,1);
   g_lastConfirmSym = sym;
   g_lastConfirmDir = direction;
   g_lastConfirmInfo = infoMsg;

   double rsi = iRSI(sym, PERIOD_H1, RSI_Period, PRICE_CLOSE, 1);
   bool rsiInZone = false;
   if(direction == 1 && rsi >= RSI_BuyZoneLow && rsi <= RSI_BuyZoneHigh) rsiInZone = true;
   if(direction == -1 && rsi >= RSI_SellZoneLow && rsi <= RSI_SellZoneHigh) rsiInZone = true;

   // Single-candle rejection (wick > body)
   double open1 = iOpen(sym, PERIOD_H1, 1);
   double high1 = iHigh(sym, PERIOD_H1, 1);
   double low1 = iLow(sym, PERIOD_H1, 1);
   double close1 = iClose(sym, PERIOD_H1, 1);
   double body1 = MathAbs(close1 - open1);
   double upperWick1 = high1 - MathMax(close1, open1);
   double lowerWick1 = MathMin(close1, open1) - low1;
   bool rejection = false;
   if(direction == 1 && lowerWick1 > body1 && close1 > open1) rejection = true;
   if(direction == -1 && upperWick1 > body1 && close1 < open1) rejection = true;
   if(rejection) confirmDetails += "Rejection ";

   // Multi-candle pattern: Engulfing (last 2 candles)
   double open2 = iOpen(sym, PERIOD_H1, 2);
   double close2 = iClose(sym, PERIOD_H1, 2);
   bool engulfing = false;
   if(direction == 1 && close2 < open2 && close1 > open1 && close1 > open2 && open1 < close2) engulfing = true; // Bullish engulfing
   if(direction == -1 && close2 > open2 && close1 < open1 && close1 < open2 && open1 > close2) engulfing = true; // Bearish engulfing
   if(engulfing) confirmDetails += "Engulfing ";

   // Pin bar (last candle)
   bool pinbar = false;
   double pinbarBody = body1;
   double pinbarWick = (direction == 1) ? lowerWick1 : upperWick1;
   if(pinbarWick > 2 * pinbarBody) pinbar = true;
   if(pinbar) confirmDetails += "PinBar ";

   // Volume spike (current vs average of last 10 bars)
   long vol1 = iVolume(sym, PERIOD_H1, 1);
   long avgVolRaw = 0;
   for(int i=2; i<=11; i++) avgVolRaw += iVolume(sym, PERIOD_H1, i);
   double avgVol = (double)avgVolRaw / 10.0;
   bool volumeSpike = ((double)vol1 > 1.5 * avgVol);
   if(volumeSpike) confirmDetails += "VolumeSpike ";

   // At least 2 of 3 confirmations (rejection, engulfing/pinbar, volume)
   int confirmCount = 0;
   if(rejection) confirmCount++;
   if(engulfing || pinbar) confirmCount++;
   if(volumeSpike) confirmCount++;

   // Store confirmation details in global for messaging
   g_lastConfirmMsg = confirmDetails;

   return (rsiInZone && confirmCount >= 2);
}

// Clear old S/R levels for a symbol (call before re-detecting)
void ClearSRLevels(string sym) {
   for(int i = 0; i < SRCount; i++) {
      if(SRLevels[i].symbol == sym) {
         SRLevels[i].isActive = false;
      }
   }
}

// Initialize S/R detection for all pairs
void InitializeSRLevels() {
   SRCount = 0;
   for(int i = 0; i < PairsCount; i++) {
      PreloadHistory(Pairs[i]);
      DetectSRLevels(Pairs[i]);
   }
   Log("S/R levels detected: " + IntegerToString(SRCount));
}

//+------------------------------------------------------------------+
//| IMPROVED PULLBACK DETECTION (S/R + RSI)                           |
//+------------------------------------------------------------------+
int GetPullbackQualityV2(string sym, double &outEntry, double &outSL, double &outTP) {
   if(!IsBiasAligned(sym)) return 0;
   
   int direction = GetTradeDirection(sym);
   if(direction == 0) return 0;
   
   double close = iClose(sym, PERIOD_H1, 0);
   double rsi = iRSI(sym, PERIOD_H1, RSI_Period, PRICE_CLOSE, 1);
   double atr = iATR(sym, PERIOD_H1, ATRPeriod, 0);
   
   int quality = 0;
   double srLevel = 0;
   int srTouches = 0;
   
   // Condition 1: Bias aligned (already checked)
   quality++;
   
   // Condition 2: Price at/near S/R level or nearest valid S/R
   bool atSRNow = IsPriceAtSR(sym, direction, srLevel, srTouches);
   if(atSRNow && srTouches < g_MinEntrySRTouches) atSRNow = false;
   bool hasSR = atSRNow;
   if(!hasSR) {
      srLevel = GetNearestSRLevelMinTouches(sym, direction, g_MinEntrySRTouches, srTouches);
      if(srLevel > 0) hasSR = true;
   }
   if(hasSR) {
      quality++;
      if(srTouches >= 3) quality++;  // Bonus for STRONG S/R (3+ touches)
   }
   
   // Condition 3: RSI in zone (confirmation)
   // Relax RSI requirement when entry is pending at S/R (not at S/R yet)
   bool rsiInZone = false;
   if(direction == 1 && rsi >= RSI_BuyZoneLow && rsi <= RSI_BuyZoneHigh) {
      rsiInZone = true;
   }
   if(direction == -1 && rsi >= RSI_SellZoneLow && rsi <= RSI_SellZoneHigh) {
      rsiInZone = true;
   }
   if(atSRNow && rsiInZone) quality++;

   // If price is not yet at S/R, require RSI momentum to keep setup tradable
   // (prevents weak pending setups from passing quality gate on bias+SR alone)
   if(!atSRNow && !rsiInZone && quality > 1) quality = 1;
   
   // Condition 4: Candle rejection at S/R
   if(atSRNow) {
      double open = iOpen(sym, PERIOD_H1, 1);
      double high = iHigh(sym, PERIOD_H1, 1);
      double low = iLow(sym, PERIOD_H1, 1);
      double close1 = iClose(sym, PERIOD_H1, 1);
      double body = MathAbs(close1 - open);
      double upperWick = high - MathMax(close1, open);
      double lowerWick = MathMin(close1, open) - low;
      
      if(direction == 1 && lowerWick > body && close1 > open) quality++;  // Bullish rejection
      if(direction == -1 && upperWick > body && close1 < open) quality++;  // Bearish rejection
   }
   
   // Calculate Entry, SL, TP based on S/R
   if(!hasSR || srLevel <= 0) return 0;

   outEntry = srLevel;  // Entry at S/R level (pending if far)
   int swingLookback = 10;
   if(BreakoutLookback > 0) swingLookback = BreakoutLookback;

   if(direction == 1) {
      // BUY: place SL at recent swing low
      double swingLow = GetSwingLow(sym, swingLookback);
      if(swingLow > 0 && swingLow < outEntry) outSL = swingLow;
      else outSL = srLevel - atr * 1.2;  // fallback
   } else {
      // SELL: place SL at recent swing high
      double swingHigh = GetSwingHigh(sym, swingLookback);
      if(swingHigh > 0 && swingHigh > outEntry) outSL = swingHigh;
      else outSL = srLevel + atr * 1.2;  // fallback
   }

   // Enforce minimum SL distance from entry
   double pipVal = PipValue(sym);
   outSL = AdjustSLByMinPips(sym, outEntry, outSL, direction, pipVal);

   // TP must be next S/R level (fallback to ATR-based TP if enabled)
   double nextSR = GetNextSRForTP(sym, direction, srLevel);
   if(nextSR > 0) {
      outTP = nextSR;

      // Check minimum TP distance; if too small, try next-next S/R
      double tpPips = (pipVal > 0) ? (MathAbs(outTP - outEntry) / pipVal) : 0;
      if(tpPips < g_MinTPPips) {
         double nextNextSR = GetNextSRForTP(sym, direction, nextSR);
         if(nextNextSR > 0) {
            outTP = nextNextSR;
         tpPips = (pipVal > 0) ? (MathAbs(outTP - outEntry) / pipVal) : 0;
         }
         if(tpPips < g_MinTPPips) {
            if(UseATRTPFallback && atr > 0) {
               double atrDist = atr * g_MinTP_ATR_Mult;
               double atrMax = atr * g_MaxTP_ATR_Mult;
               if(atrDist > atrMax) atrDist = atrMax;
               outTP = (direction == 1) ? (outEntry + atrDist) : (outEntry - atrDist);
            } else {
               return 0;  // Skip trade - TP too small
            }
         }
      }
   } else {
      if(UseATRTPFallback && atr > 0) {
         double atrDist = atr * g_MinTP_ATR_Mult;
         double atrMax = atr * g_MaxTP_ATR_Mult;
         if(atrDist > atrMax) atrDist = atrMax;
         outTP = (direction == 1) ? (outEntry + atrDist) : (outEntry - atrDist);
      } else {
         return 0;
      }
   }
   
   return quality;
}

//+------------------------------------------------------------------+
//| BREAKOUT DETECTION                                                |
//+------------------------------------------------------------------+
double GetSwingHigh(string sym, int lookback) {
   double highest = 0;
   for(int i = 1; i <= lookback; i++) {
      double high = iHigh(sym, PERIOD_H1, i);
      if(high > highest) highest = high;
   }
   return highest;
}

double GetSwingLow(string sym, int lookback) {
   double lowest = 999999;
   for(int i = 1; i <= lookback; i++) {
      double low = iLow(sym, PERIOD_H1, i);
      if(low < lowest) lowest = low;
   }
   return lowest;
}

void CheckBreakouts() {
   for(int i = 0; i < PairsCount; i++) {
      string sym = Pairs[i];
      if(!IsBiasAligned(sym)) continue;
      
      int direction = GetTradeDirection(sym);
      if(direction == 0) continue;
      
      double close = iClose(sym, PERIOD_H1, 0);
      double prevClose = iClose(sym, PERIOD_H1, 1);
      double atr = iATR(sym, PERIOD_H1, ATRPeriod, 0);
      
      // Check for new breakout
      if(direction == 1) {
         double swingHigh = GetSwingHigh(sym, BreakoutLookback);
         if(prevClose < swingHigh && close > swingHigh) {
            AddBreakoutLevel(sym, swingHigh, 1);
         }
      }
      else if(direction == -1) {
         double swingLow = GetSwingLow(sym, BreakoutLookback);
         if(prevClose > swingLow && close < swingLow) {
            AddBreakoutLevel(sym, swingLow, -1);
         }
      }
   }
   
   // Check for retests
   CheckRetests();
}

void AddBreakoutLevel(string sym, double level, int dir) {
   // Check if already exists
   for(int i = 0; i < BreakoutCount; i++) {
      if(BreakoutLevels[i].symbol == sym && MathAbs(BreakoutLevels[i].level - level) < PipValue(sym) * 10) {
         return; // Already tracking
      }
   }
   
   if(BreakoutCount < 64) {
      BreakoutLevels[BreakoutCount].symbol = sym;
      BreakoutLevels[BreakoutCount].level = level;
      BreakoutLevels[BreakoutCount].direction = dir;
      BreakoutLevels[BreakoutCount].breakTime = TimeCurrent();
      BreakoutLevels[BreakoutCount].waitingRetest = true;
      BreakoutLevels[BreakoutCount].retestConfirmed = false;
      BreakoutCount++;
      
      // Send breakout detected alert
      SendBreakoutDetectedAlert(sym, level, dir);
   }
}

void CheckRetests() {
   for(int i = 0; i < BreakoutCount; i++) {
      if(!BreakoutLevels[i].waitingRetest) continue;
      if(BreakoutLevels[i].retestConfirmed) continue;
      
      string sym = BreakoutLevels[i].symbol;
      double level = BreakoutLevels[i].level;
      int dir = BreakoutLevels[i].direction;
      double atr = iATR(sym, PERIOD_H1, ATRPeriod, 0);
      double close = iClose(sym, PERIOD_H1, 0);
      double buffer = atr * RetestBuffer;
      
      // Check if price retested the level
      if(dir == 1 && close >= level - buffer && close <= level + buffer) {
         // Check for bounce (bullish candle)
         double open = iOpen(sym, PERIOD_H1, 0);
         if(close > open) {
            BreakoutLevels[i].retestConfirmed = true;
            BreakoutLevels[i].waitingRetest = false;
            SendRetestConfirmedAlert(sym, level, dir);
         }
      }
      else if(dir == -1 && close >= level - buffer && close <= level + buffer) {
         // Check for bounce (bearish candle)
         double open = iOpen(sym, PERIOD_H1, 0);
         if(close < open) {
            BreakoutLevels[i].retestConfirmed = true;
            BreakoutLevels[i].waitingRetest = false;
            SendRetestConfirmedAlert(sym, level, dir);
         }
      }
      
      // Expire old breakouts (24 hours)
      if(TimeCurrent() - BreakoutLevels[i].breakTime > 86400) {
         BreakoutLevels[i].waitingRetest = false;
      }
   }
}

//+------------------------------------------------------------------+
//| SL/TP CALCULATION                                                 |
//+------------------------------------------------------------------+
double CalculateSL(string sym, int direction) {
   double atr = iATR(sym, PERIOD_H1, ATRPeriod, 0);
   int lookback = (BreakoutLookback > 0) ? BreakoutLookback : 10;
   double swingHigh = GetSwingHigh(sym, lookback);
   double swingLow = GetSwingLow(sym, lookback);

   double rawSL = 0;
   if(direction == 1) rawSL = swingLow - atr * 0.5;
   else rawSL = swingHigh + atr * 0.5;

   // Keep breakout SL aligned with global minimum-SL policy
   double entry = (direction == 1) ? MarketInfo(sym, MODE_ASK) : MarketInfo(sym, MODE_BID);
   double pipVal = PipValue(sym);
   return AdjustSLByMinPips(sym, entry, rawSL, direction, pipVal);
}

double CalculateTP(string sym, int direction, double entry, double sl) {
   double risk = MathAbs(entry - sl);
   if(direction == 1) {
      return entry + (risk * g_TP1_RR);
   } else {
      return entry - (risk * g_TP1_RR);
   }
}

double CalculateLotSize(string sym, double slPips) {
   double accountBalance = AccountBalance();
   if(slPips <= 0) return 0;

   // Normalize SL distance with global minimum floor
   double minSLPipsEff = GetAdaptiveMinSLPips(sym);
   if(minSLPipsEff > 0 && slPips < minSLPipsEff) slPips = minSLPipsEff;

   if(UseFixedLotLadder) {
      double steps = MathFloor(accountBalance / LotLadderUSDStep);
      if(steps < 1) steps = 1;

      double minBand = steps * LotPerLadderStep;
      double maxBand = minBand + LotPerLadderStep;

      // Use MIN of band for safer sizing
      double lotSize = minBand;
      if(lotSize < 0.01) lotSize = 0.01;
      if(LotMinFloor > 0 && lotSize < LotMinFloor) lotSize = LotMinFloor;
      if(LotMaxCap > 0 && lotSize > LotMaxCap) lotSize = LotMaxCap;

      double minLot = MarketInfo(sym, MODE_MINLOT);
      double maxLot = MarketInfo(sym, MODE_MAXLOT);
      double lotStep = MarketInfo(sym, MODE_LOTSTEP);

      // Keep ladder sizing within risk budget based on actual SL distance
      double perTradeRisk = accountBalance * (MaxRiskPerTradePercent / 100.0);
      double remainingDailyRisk = GetRemainingRiskAmount();
      double riskAmount = MathMin(perTradeRisk, remainingDailyRisk);
      if(riskAmount <= 0) return 0;

      double tickValue = MarketInfo(sym, MODE_TICKVALUE);
      double tickSize  = MarketInfo(sym, MODE_TICKSIZE);
      double pipSize   = PipValue(sym);
      if(tickValue > 0 && tickSize > 0 && pipSize > 0 && slPips > 0) {
         double pipValueMoneyPerLot = tickValue * (pipSize / tickSize);
         double riskCapLot = riskAmount / (slPips * pipValueMoneyPerLot);
         if(riskCapLot < minLot) return 0;
         lotSize = MathMin(lotSize, riskCapLot);
      }

      lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
      lotSize = MathFloor(lotSize / lotStep) * lotStep;
      // Drawdown recovery: trade at reduced size until balance recovers
      if(UseDrawdownRecoveryMode && g_inDDRecovery && DDRecoveryLotMultiplier > 0)
         lotSize = MathMax(minLot, MathFloor(lotSize * DDRecoveryLotMultiplier / lotStep) * lotStep);
      return lotSize;
   }

   double perTradeRisk = accountBalance * (MaxRiskPerTradePercent / 100.0);
   double remainingDailyRisk = GetRemainingRiskAmount();
   double riskAmount = MathMin(perTradeRisk, remainingDailyRisk);
   if(riskAmount <= 0) return 0;
   
   // Enforce adaptive minimum SL distance
   double minSLPips = minSLPipsEff;
   if(slPips < minSLPips) slPips = minSLPips;

   double tickValue = MarketInfo(sym, MODE_TICKVALUE);
   double tickSize  = MarketInfo(sym, MODE_TICKSIZE);
   double pipSize   = PipValue(sym);
   if(tickValue <= 0 || tickSize <= 0 || pipSize <= 0) return 0;

   double pipValueMoneyPerLot = (tickValue > 0 && tickSize > 0 && pipSize > 0) ? (tickValue * (pipSize / tickSize)) : 0;
   double lotSize = riskAmount / (slPips * pipValueMoneyPerLot);

   // Normalize lot size
   double minLot = MarketInfo(sym, MODE_MINLOT);
   double maxLot = MarketInfo(sym, MODE_MAXLOT);
   double lotStep = MarketInfo(sym, MODE_LOTSTEP);
   
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   // Drawdown recovery: trade at reduced size until balance recovers
   if(UseDrawdownRecoveryMode && g_inDDRecovery && DDRecoveryLotMultiplier > 0)
      lotSize = MathMax(minLot, MathFloor(lotSize * DDRecoveryLotMultiplier / lotStep) * lotStep);
   
   return lotSize;
}

bool IsPriceNear(double price, double target, double pipVal) {
   if(pipVal <= 0) return false;
   return (MathAbs(price - target) <= (0.5 * pipVal));
}

double AdjustSLByMinPips(string sym, double entry, double sl, int direction, double pipVal) {
   if(pipVal <= 0) return sl;
   double minSLPips = GetAdaptiveMinSLPips(sym);
   double slPips = MathAbs(entry - sl) / pipVal;
   if(slPips >= minSLPips) return sl;
   double dist = minSLPips * pipVal;
   return (direction == 1) ? (entry - dist) : (entry + dist);
}

double GetAdaptiveMinSLPips(string sym) {
   double pipVal = PipValue(sym);
   if(pipVal <= 0) return (MinSLPips > 0 ? MinSLPips : 0);

   double atr = iATR(sym, PERIOD_H1, ATRPeriod, 0);
   double atrPips = (atr > 0) ? (atr / pipVal) : 0;
   double mult = SL_ATRBaseMult;

   // JPY pairs are commonly more volatile in pip terms
   if(StringFind(sym, "JPY") >= 0) mult *= SL_JPYBoost;

   // Session volatility boost (GMT)
   int hour = TimeHour(TimeGMT());
   bool overlap = (hour >= NYStartHour && hour < LondonEndHour);
   if(overlap) mult *= SL_OverlapBoost;

   // Spread regime boost
   double avgSpread = 0;
   for(int i = 0; i < PairsCount; i++) {
      if(Pairs[i] == sym) { avgSpread = AvgSpreads[i]; break; }
   }
   double curSpread = GetSpreadPips(sym);
   if(avgSpread > 0 && curSpread > avgSpread * SL_WideSpreadRatio) mult *= SL_WideSpreadBoost;

   double minSLPips = atrPips * mult;
   if(MinSLPips > 0) minSLPips = MathMax(MinSLPips, minSLPips);
   if(SL_MaxPipsCap > 0 && minSLPips > SL_MaxPipsCap) minSLPips = SL_MaxPipsCap;

   return minSLPips;
}

//+------------------------------------------------------------------+
//| SESSION CHECK                                                     |
//+------------------------------------------------------------------+
bool IsSessionActive() {
   if(!UseLondonSession && !UseNYSession) return true;
   
   int hour = TimeHour(TimeGMT());
   
   bool londonActive = (UseLondonSession && hour >= LondonStartHour && hour < LondonEndHour);
   bool nyActive = (UseNYSession && hour >= NYStartHour && hour < NYEndHour);
   
   return (londonActive || nyActive);
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
//| VOLATILITY CHECK                                                  |
//+------------------------------------------------------------------+
bool IsVolatilityOK(string sym) {
   int symIdx = FindPairIndex(sym);
   datetime barTime = iTime(sym, PERIOD_H1, 0);
   if(symIdx >= 0 && barTime > 0 && g_volCacheBarTime[symIdx] == barTime) {
      return g_volCacheValue[symIdx];
   }

   double atr = iATR(sym, PERIOD_H1, ATRPeriod, 0);
   double atrAvg = 0;
   for(int i = 1; i <= 20; i++) {
      atrAvg += iATR(sym, PERIOD_H1, ATRPeriod, i);
   }
   atrAvg /= 20;
   
   // Skip if ATR too low (< 50% of average) or too high (> 200% of average)
   bool ok = !(atr < atrAvg * 0.5 || atr > atrAvg * 2.0);
   if(symIdx >= 0 && barTime > 0) {
      g_volCacheBarTime[symIdx] = barTime;
      g_volCacheValue[symIdx] = ok;
   }
   return ok;
}

//+------------------------------------------------------------------+
//| CORRELATION CHECK                                                 |
//+------------------------------------------------------------------+
// NOTE: Renamed to avoid duplicate with GetCorrelationWarning(sym, direction)
string GetCorrelationPairHint(string sym) {
   for(int i = 0; i < 10; i++) {
      if(CorrelatedPairs[i][0] == sym || CorrelatedPairs[i][1] == sym) {
         string correlated = (CorrelatedPairs[i][0] == sym) ? CorrelatedPairs[i][1] : CorrelatedPairs[i][0];
         // Check if correlated pair has open signal
         return correlated;
      }
   }
   return "";
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
            else {
               currentRiskNoSLTrades++; // can't compute — treat same as no-SL
               continue;
            }
            Log("UpdateRiskTracking: tickValue=0 for " + sym + ", using contract-size fallback.");
         }

         if(pipValueMoneyPerLot > 0 && slPips > 0) {
            double riskAmount = slPips * lots * pipValueMoneyPerLot;
            currentRiskAmount += riskAmount;
            currentRiskTrackedTrades++;
         }
      }
   }

   if(AccountBalance() > 0) currentRiskPercent = (currentRiskAmount / AccountBalance()) * 100.0;
}

double GetRemainingRiskBudget() {
   return (MaxDailyRiskPercent - currentRiskPercent);
}

double GetRemainingRiskAmount() {
   return AccountBalance() * (GetRemainingRiskBudget() / 100.0);
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
   // Remove only known formatting tags to preserve comparison operators.
   string out = s;
   StringReplace(out, "<b>", "");
   StringReplace(out, "</b>", "");
   StringReplace(out, "<i>", "");
   StringReplace(out, "</i>", "");
   StringReplace(out, "<code>", "");
   StringReplace(out, "</code>", "");
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
   // Escape & first (before any other replacements that introduce &)
   // Only escape bare & that are NOT already part of a valid entity
   StringReplace(out, "P&L", "P&amp;L");
   // Escape comparator-like symbols that break HTML parsing
   StringReplace(out, "<=", "&lt;=");
   StringReplace(out, ">=", "&gt;=");
   StringReplace(out, "(ADX<", "(ADX &lt; ");
   StringReplace(out, " < ", " &lt; ");
   StringReplace(out, " > ", " &gt; ");
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

   // Mark manual alert as attempted (regardless of API success/failure)
   if(g_manualAlertRun) g_manualAlertSent = true;

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

   string url = "https://api.telegram.org/bot" + TG_BOT_TOKEN +
                "/sendMessage?chat_id=" + TG_CHAT_ID +
                (useHtml ? "&parse_mode=HTML" : "") +
                "&text=" + UrlEncode(text);
   
   if(DEBUG_PRINT) {
      Log("Sending to Telegram (" + IntegerToString(StringLen(text)) + " chars)");
      Log("Telegram request prepared (token hidden)");
   }

   char result[];
   char headers[];
   string respHeaders;
   int timeout = 5000;

   int res = WebRequest("GET", url, "", timeout, headers, result, respHeaders);
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
      if(VerboseTelegramLogs) Log("✓ Message sent to Telegram successfully");
      g_tgLastSendAt = now;
      if(g_manualAlertRun) g_manualAlertSent = true;
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
      Log("✗ Telegram API Error: " + resp);
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

//+------------------------------------------------------------------+
//| CHART SIGNALS                                                    |
//+------------------------------------------------------------------+
void DrawChartSignal(string sym, int direction, double price, int quality, int priority, string orderTypeShort) {
   if(!ShowChartSignals) return;
   if(sym != Symbol()) return;

   datetime t = iTime(sym, PERIOD_H1, 0);
   string prefix = "SMP_SIG_" + IntegerToString((int)t) + "_" + (direction == 1 ? "B" : "S");
   string arrowName = prefix + "_A";
   string textName = prefix + "_T";

   color c = (direction == 1) ? BuySignalColor : SellSignalColor;
   int arrowCode = (direction == 1) ? 233 : 234;
   double pip = PipValue(sym);
   double textOffset = (pip > 0 ? pip * 10.0 : MarketInfo(sym, MODE_POINT) * 10.0);
   double textPrice = price + (direction == 1 ? textOffset : -textOffset);

   if(ObjectFind(0, arrowName) == -1) {
      ObjectCreate(0, arrowName, OBJ_ARROW, 0, t, price);
   }
   ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, arrowName, OBJPROP_COLOR, c);
   ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 1);

   string prioLabel = (priority == 1) ? "[P1]" : (priority == 2) ? "[P2]" : "[P3]";
   string label = (direction == 1 ? "BUY " : "SELL ") + GetQualityStars(quality) + " " + prioLabel + " " + orderTypeShort;

   if(ObjectFind(0, textName) == -1) {
      ObjectCreate(0, textName, OBJ_TEXT, 0, t, textPrice);
   } else {
      ObjectMove(0, textName, 0, t, textPrice);
   }
   ObjectSetString(0, textName, OBJPROP_TEXT, label);
   ObjectSetInteger(0, textName, OBJPROP_COLOR, c);
   ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 8);
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

void UpdateSkipLabel() {
   if(lastSkipLabelTime == 0) {
      ObjectDelete(0, "SkipLabel");
      return;
   }

   if((TimeCurrent() - lastSkipLabelTime) > (AlertBadgeMinutes * 60)) {
      ObjectDelete(0, "SkipLabel");
      lastSkipLabelTime = 0;
      return;
   }

   if(ObjectFind(0, "SkipLabel") == -1) {
      ObjectCreate(0, "SkipLabel", OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "SkipLabel", OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, "SkipLabel", OBJPROP_YDISTANCE, 26);
      ObjectSetInteger(0, "SkipLabel", OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, "SkipLabel", OBJPROP_FONT, "Arial Black");
   }

   ObjectSetString(0, "SkipLabel", OBJPROP_TEXT, lastSkipLabelText);
   ObjectSetInteger(0, "SkipLabel", OBJPROP_COLOR, clrTomato);
}

void MarkSkipLabel(string text) {
   lastSkipLabelTime = TimeCurrent();
   lastSkipLabelText = text;
   UpdateSkipLabel();
}

void MarkAlertBadge() {
   if(!ShowAlertBadge) return;
   lastAlertBadgeTime = TimeCurrent();
   UpdateAlertBadge();
}

//+------------------------------------------------------------------+
//| BUILD MAIN SCORECARD MESSAGE                                      |
//+------------------------------------------------------------------+
string BuildScorecardMessage() {
   string msg = "==SWINGMASTER PRO - SIGNALS==" + TGTag() + "\n";
   msg += "TIME: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + "\n";
   msg += "Market: " + GetMarketStatus();
   msg += "\nSignal Mode: " + GetSignalModeLabel();

   string newsSource = "FALLBACK";
   string newsReason = "";
   if(UseLiveNewsFeed) {
      if(liveNewsLoaded) {
         newsSource = "LIVE";
      } else {
         newsReason = (lastNewsError != "" ? lastNewsError : "No events");
      }
   } else {
      newsReason = "Disabled";
   }
   msg += "\nNews Feed: " + newsSource;
   if(newsSource == "LIVE") msg += " (count=" + IntegerToString(NewsCount) + ")";
   else msg += " (reason=" + newsReason + ")";

   // Cache news state ONCE per scan to avoid repeated side-effect calls and extra calls
   bool newsNow = GetNewsNowCached();
   if(newsNow) {
      msg += " [NEWS]\n";
      if(currentNewsEvent != "") {
         msg += "! " + currentNewsEvent + " - No new trades\n";
      }
   }
   msg += "\n";

   if(StrictMaxSLPips > 0 || g_StrictMinRR > 0) {
      msg += "<b>STRICT RULES:</b> ";
      if(StrictMaxSLPips > 0) msg += "SL<= " + DoubleToStrClean(StrictMaxSLPips, 0) + "p ";
      if(g_StrictMinRR > 0) msg += "R:R>= " + DoubleToStrClean(g_StrictMinRR, 1) + " ";
      msg += "\n\n";
   }
   
   // Account Status (compact)
   msg += "<b>ACCOUNT:</b> $" + DoubleToStrClean(AccountBalance(), 0);
   double pnl = AccountEquity() - dayStartBalance;
   if(dayStartBalance > 0) {
      double pnlPct = (pnl / dayStartBalance) * 100;
      msg += " (" + (pnl >= 0 ? "+" : "") + DoubleToStrClean(pnlPct, 1) + "%)";
   }
   msg += "\n";
   
   // Risk Budget (compact)
   msg += "<b>RISK:</b> " + DoubleToStrClean(currentRiskPercent, 1) + "%/" + DoubleToStrClean(MaxDailyRiskPercent, 1) + "% | ";
   string riskStatus = (GetRemainingRiskBudget() > 0.5 ? "OK" : (GetRemainingRiskBudget() > 0 ? "LOW" : "FULL"));
   if(currentRiskTrackedTrades == 0 && currentRiskNoSLTrades > 0) riskStatus = "NO-SL";
   msg += "<b>" + riskStatus + "</b>\n";
   if(currentRiskNoSLTrades > 0) msg += "No-SL trades: " + IntegerToString(currentRiskNoSLTrades) + "\n";
   msg += "<b>ACTION:</b> Follow top priority signals only if rules pass.\n";
   
   // Currency Bias
   msg += "\n<b>CURRENCY BIAS:</b>\n";
   
   // Sort currencies by strength
   double strengths[7];
   ArrayInitialize(strengths, 0.0);
   for(int i = 0; i < 7; i++) {
      strengths[i] = WeightedCurrencyStrength(Currencies[i]);
   }
   
   for(int i = 0; i < 7; i++) {
      string cur = Currencies[i];
      double d1 = CurrencyTFScoreNorm(cur, PERIOD_D1);
      double h4 = CurrencyTFScoreNorm(cur, PERIOD_H4);
      double h1 = CurrencyTFScoreNorm(cur, PERIOD_H1);
      string bias = GetBiasLabel(cur);
      string arrow = (bias == "STRONG") ? "^" : (bias == "WEAK" ? "v" : "-");
      
      msg += "<b>" + cur + ":</b> ";
      msg += "D1:" + (d1 >= 0 ? "+" : "") + DoubleToStrClean(d1, 2);
      msg += " | H4:" + (h4 >= 0 ? "+" : "") + DoubleToStrClean(h4, 2);
      msg += " | H1:" + (h1 >= 0 ? "+" : "") + DoubleToStrClean(h1, 2);
      msg += " " + arrow + " <b>" + bias + "</b>\n";
   }
   
   // Identify STRONG, WEAK, NEUTRAL currencies
   string strongCurrencies = "";
   string weakCurrencies = "";
   string neutralCurrencies = "";
   
   for(int i = 0; i < 7; i++) {
      string bias = GetBiasLabel(Currencies[i]);
      if(bias == "STRONG") strongCurrencies += Currencies[i] + " ";
      else if(bias == "WEAK") weakCurrencies += Currencies[i] + " ";
      else neutralCurrencies += Currencies[i] + " ";
   }

   msg += "\n<b>SUMMARY:</b>\n";
   msg += "^ <b>STRONG:</b> " + (strongCurrencies == "" ? "None" : strongCurrencies) + "\n";
   msg += "v <b>WEAK:</b> " + (weakCurrencies == "" ? "None" : weakCurrencies) + "\n";
   msg += "- <b>NEUTRAL:</b> " + (neutralCurrencies == "" ? "None" : neutralCurrencies) + "\n";

   // Open trades summary
   int openCount = 0;
   string openList = "";
   for(int i = 0; i < OrdersTotal(); i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;

      int ticket = OrderTicket();
      string osym = OrderSymbol();
      double entry = OrderOpenPrice();
      double lots = OrderLots();
      double currentPrice = (type == OP_BUY) ? MarketInfo(osym, MODE_BID) : MarketInfo(osym, MODE_ASK);
      double pipVal = PipValue(osym);
      double pips = 0;
      if(pipVal > 0) {
         pips = (type == OP_BUY) ? (currentPrice - entry) / pipVal : (entry - currentPrice) / pipVal;
      }
      string dir = (type == OP_BUY) ? "BUY" : "SELL";
      string pipsStr = (pips >= 0 ? "+" : "") + DoubleToStrClean(pips, 0) + "p";
      string plStr = (OrderProfit() >= 0 ? "+" : "") + DoubleToStrClean(OrderProfit(), 2);

      int curDir = GetTradeDirection(osym);
      int orderDir = (type == OP_BUY) ? 1 : -1;
      int biasNowDir = curDir;
      int biasNowCode = GetBiasCodeForDirection(osym, orderDir);
      string biasNowLabel = BiasLabelFromCode(biasNowCode) + "-" + BiasDirLabel(biasNowDir);
      string confNow = (curDir != 0 && HasPairTFConfluence(osym, curDir)) ? "Y" : "N";

      // Current quality snapshot (for open trades)
      double qEntry = 0, qSL = 0, qTP = 0;
      int quality = GetPullbackQualityV2(osym, qEntry, qSL, qTP);
      string qStars = GetQualityStars(quality);
      int srTouches = 0;
      double srLevel = 0;
      bool atSR = (curDir != 0) ? IsPriceAtSR(osym, curDir, srLevel, srTouches) : false;
      double pipValNow = PipValue(osym);
      double slPips = (qEntry > 0 && qSL > 0 && pipValNow > 0) ? MathAbs(qEntry - qSL) / pipValNow : 0;
      double tpPips = (qEntry > 0 && qTP > 0 && pipValNow > 0) ? MathAbs(qTP - qEntry) / pipValNow : 0;
      double rr = (slPips > 0) ? tpPips / slPips : 0;
      bool filtersOk = IsSpreadOK(osym) && IsVolatilityOK(osym) && !newsNow;
      bool hqNow = (quality >= 3 && srTouches >= 3 && (!EnableRRFilter || rr >= g_MinRR) && filtersOk);
      string hqNowStr = hqNow ? "Y" : "N";

      int entryBiasCode = 0;
      bool entryConf = false;
      bool entryHq = false;
      bool hasEntrySnapshot = LoadEntrySnapshot(ticket, entryBiasCode, entryConf, entryHq);
      if(!hasEntrySnapshot) {
         StoreEntrySnapshot(ticket, osym, orderDir);
         hasEntrySnapshot = LoadEntrySnapshot(ticket, entryBiasCode, entryConf, entryHq);
      }
      int entryBiasCodeSafe = (hasEntrySnapshot ? entryBiasCode : biasNowCode);
      int entryBiasDir = orderDir;
      bool hasEntryBiasDir = LoadEntryBiasDir(ticket, entryBiasDir);
      int entryBiasDirSafe = hasEntryBiasDir ? entryBiasDir : orderDir;
      string entryBiasLabel = BiasLabelFromCode(entryBiasCodeSafe) + "-" + BiasDirLabel(entryBiasDirSafe);
      string entryConfStr = hasEntrySnapshot ? (entryConf ? "Y" : "N") : confNow;
      string entryHqStr = hasEntrySnapshot ? (entryHq ? "Y" : "N") : hqNowStr;

      string biasTag = "Bias:E:" + entryBiasLabel + " | N:" + biasNowLabel;
      string confTag = "Conf:E:" + entryConfStr + "|N:" + confNow;
      string hqTag = "HQ:E:" + entryHqStr + "|N:" + hqNowStr;

      // Actionable status tags for open trades
      string actionTag = (curDir != 0 && curDir != orderDir) ? "Action:REVIEW" : "Action:WAIT";

      // Trail readiness
      bool trailReady = false;
      if(pips >= TrailingTriggerPips) {
         double currentSL = OrderStopLoss();
         double atr = iATR(osym, PERIOD_H1, ATRPeriod, 0);
         double suggestedSL = 0;
         string method = "BREAKEVEN";
         bool autoPartialDone = false;
         string autoPartialNote = "";
         double partialCloseLots = 0;
         double partialRemainingLots = 0;
         if(type == OP_BUY) {
            suggestedSL = entry + (BreakEvenBufferPips * pipVal);
            if(UseATRTrailSuggestion && atr > 0 && pips >= (TrailingTriggerPips * 2.0)) {
               double atrSL = currentPrice - (ATRTrailMult * atr);
               if(atrSL > suggestedSL) { suggestedSL = atrSL; method = "ATR TRAIL"; }
            }
            if(currentSL == 0 || currentSL < (suggestedSL - (0.5 * pipVal))) {  // SL still below suggested level by at least 0.5 pip
               trailReady = true;
               if(AutoTradingActive() && AutoTrailStops) {
                  AutoModifySL(ticket, suggestedSL);
               }
               string key = "trail:" + osym + ":" + IntegerToString(ticket);
               if(CanSendAlert(key, AlertCooldownMins))
                  SendTrailingAlert(osym, type, entry, currentSL, currentPrice, pips, suggestedSL, method, lots,
                                   autoPartialDone, partialCloseLots, partialRemainingLots, autoPartialNote);
            }
         } else if(type == OP_SELL) {
            suggestedSL = entry - (BreakEvenBufferPips * pipVal);
            if(UseATRTrailSuggestion && atr > 0 && pips >= (TrailingTriggerPips * 2.0)) {
               double atrSL = currentPrice + (ATRTrailMult * atr);
               if(atrSL < suggestedSL) { suggestedSL = atrSL; method = "ATR TRAIL"; }
            }
            if(currentSL == 0 || currentSL > (suggestedSL + (0.5 * pipVal))) {  // SL still above suggested level by at least 0.5 pip
               trailReady = true;
               if(AutoTradingActive() && AutoTrailStops) {
                  AutoModifySL(ticket, suggestedSL);
               }
               string key = "trail:" + osym + ":" + IntegerToString(ticket);
               if(CanSendAlert(key, AlertCooldownMins))
                  SendTrailingAlert(osym, type, entry, currentSL, currentPrice, pips, suggestedSL, method, lots,
                                   autoPartialDone, partialCloseLots, partialRemainingLots, autoPartialNote);
            }
         }
      }

      if(trailReady) actionTag = "Action:TRAIL";

      openCount++;
      openList += IntegerToString(openCount) + ". " + osym + " " + dir;
      openList += " | " + pipsStr + " | $" + plStr;
      openList += " | Q:" + qStars;
      openList += " | " + biasTag + " | " + confTag + " | " + hqTag + " | " + actionTag + "\n";
      if(openCount >= 5) { openList += "...\n"; break; }
   }
   if(openCount > 0) {
      msg += "\n<b>OPEN TRADES:</b> " + IntegerToString(openCount) + "\n" + openList;
   }

   // Pending orders summary
   int pendCount = 0;
   string pendList = "";
   for(int i = 0; i < OrdersTotal(); i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      int type = OrderType();
      if(type != OP_BUYLIMIT && type != OP_BUYSTOP && type != OP_SELLLIMIT && type != OP_SELLSTOP) continue;

      string osym = OrderSymbol();
      double entry = OrderOpenPrice();
      double sl = OrderStopLoss();
      double tp = OrderTakeProfit();
      double lots = OrderLots();

      int orderDir = (type == OP_BUYLIMIT || type == OP_BUYSTOP) ? 1 : -1;
      string dir = (orderDir == 1) ? "BUY" : "SELL";
      string ordType = (type == OP_BUYLIMIT) ? "LIMIT" : (type == OP_BUYSTOP) ? "STOP" : (type == OP_SELLLIMIT) ? "LIMIT" : "STOP";

      int curDir = GetTradeDirection(osym);
      int biasNowCode = GetBiasCodeForDirection(osym, orderDir);
      int biasNowDir = curDir;
      string biasNowLabel = BiasLabelFromCode(biasNowCode) + "-" + BiasDirLabel(biasNowDir);
      string confNow = (curDir != 0 && HasPairTFConfluence(osym, orderDir)) ? "Y" : "N";

      // Quality snapshot for pending order
      double qEntry = 0, qSL = 0, qTP = 0;
      int quality = GetPullbackQualityV2(osym, qEntry, qSL, qTP);
      string qStars = GetQualityStars(quality);
      string qLabel = GetQualityLabel(quality);
      int srTouches = 0;
      double srLevel = 0;
      bool atSR = (orderDir != 0) ? IsPriceAtSR(osym, orderDir, srLevel, srTouches) : false;
      double pipVal = PipValue(osym);
      double slPips = (entry > 0 && sl > 0 && pipVal > 0) ? MathAbs(entry - sl) / pipVal : 0;
      double tpPips = (entry > 0 && tp > 0 && pipVal > 0) ? MathAbs(tp - entry) / pipVal : 0;
      double rr = (slPips > 0 && tpPips > 0) ? (tpPips / slPips) : 0;
      bool filtersOk = IsSpreadOK(osym) && IsVolatilityOK(osym) && !newsNow;
      bool hqNow = (quality >= 3 && srTouches >= 3 && (!EnableRRFilter || rr >= g_MinRR) && filtersOk);
      string hqNowStr = hqNow ? "Y" : "N";

      int entryBiasCode = 0;
      bool entryConf = false;
      bool entryHq = false;
      bool hasEntrySnapshot = LoadEntrySnapshot(OrderTicket(), entryBiasCode, entryConf, entryHq);
      if(!hasEntrySnapshot) {
         StoreEntrySnapshot(OrderTicket(), osym, orderDir);
         hasEntrySnapshot = LoadEntrySnapshot(OrderTicket(), entryBiasCode, entryConf, entryHq);
      }
      int entryBiasCodeSafe = hasEntrySnapshot ? entryBiasCode : biasNowCode;
      string entryBiasLabel = BiasLabelFromCode(entryBiasCodeSafe) + "-" + BiasDirLabel(orderDir);
      string entryConfStr = hasEntrySnapshot ? (entryConf ? "Y" : "N") : confNow;
      string entryHqStr = hasEntrySnapshot ? (entryHq ? "Y" : "N") : hqNowStr;

      string biasTag = "Bias:E:" + entryBiasLabel + " | N:" + biasNowLabel;
      string confTag = "Conf:E:" + entryConfStr + "|N:" + confNow;
      string hqTag = "HQ:E:" + entryHqStr + "|N:" + hqNowStr;

      bool aligned = (curDir == orderDir);
      string actionTag = aligned ? "Action:WAIT" : "Action:CANCEL";

      pendCount++;
      pendList += IntegerToString(pendCount) + ". " + osym + " " + dir + " " + ordType + " | Entry " + DoubleToStrClean(entry, (int)MarketInfo(osym, MODE_DIGITS));
      if(sl > 0) pendList += " | SL " + DoubleToStrClean(sl, (int)MarketInfo(osym, MODE_DIGITS));
      if(tp > 0) pendList += " | TP " + DoubleToStrClean(tp, (int)MarketInfo(osym, MODE_DIGITS));
      pendList += " | " + DoubleToStrClean(lots, 2) + " lots";
      pendList += " | Q:" + qStars + " " + qLabel;
      pendList += " | " + biasTag + " | " + confTag + " | " + hqTag + " | " + actionTag + "\n";
      if(pendCount >= 5) { pendList += "...\n"; break; }
   }
   if(pendCount > 0) {
      msg += "\n<b>PENDING ORDERS:</b> " + IntegerToString(pendCount) + "\n" + pendList;
   }
   
   // Collect signals grouped by priority
   string priority1Buy = "";  // Strong vs Weak
   string priority1Sell = "";
   string priority2Buy = "";  // Strong vs Neutral
   string priority2Sell = "";
   string priority3Buy = "";  // Weak vs Neutral
   string priority3Sell = "";
   
   int buyCount = 0;
   int sellCount = 0;

   // Global execution gates
   bool sessionOkGlobal = (IsSessionActive() || AllowOffSessionSignals);
   bool lockOkGlobal = !IsLockHedgeActive;
   
   // CHECK RISK BUDGET FIRST
   double remainingRisk = GetRemainingRiskBudget();
   bool riskBlocked = (remainingRisk <= 0);
   bool drawdownOk = IsDrawdownOK();
   
   if(riskBlocked) {
      msg += "\n<b>! MAX DAILY RISK REACHED</b>\n";
      msg += "Risk used: <b>" + DoubleToStrClean(currentRiskPercent, 1) + "%/" + DoubleToStrClean(MaxDailyRiskPercent, 1) + "%</b>\n";
      msg += "<b>NO NEW TRADES TODAY</b>\n";
      msg += "Reset tomorrow at 00:00 GMT\n\n";
      // Skip signal generation but show summary
   }
   if(!drawdownOk) {
      msg += "\n<b>! DRAWDOWN LIMIT REACHED</b>\n";
      msg += "DD: <b>" + DoubleToStrClean(GetDailyDrawdown(), 1) + "%/" + DoubleToStrClean(MaxDrawdownPercent, 1) + "%</b>\n";
      msg += "<b>NO NEW TRADES UNTIL RESET</b>\n\n";
   }
   if(!sessionOkGlobal) {
      msg += "\n<b>! SESSION FILTER ACTIVE</b>\n";
      msg += "<b>NO NEW TRADES OUTSIDE SESSION</b>\n\n";
   }
   if(!lockOkGlobal) {
      msg += "\n<b>! LOCK HEDGE ACTIVE</b>\n";
      msg += "<b>NEW AUTO ENTRIES PAUSED</b>\n\n";
   }

   // Collect invalid pairs (not in buy/sell due to bias)
   string invalidPairs = "";
   int invalidCount = 0;
   for(int i = 0; i < PairsCount; i++) {
      string sym = Pairs[i];
      if(GetPairPriority(sym) == 0) {
         invalidPairs += sym + " ";
         invalidCount++;
      }
   }
   
   for(int i = 0; i < PairsCount; i++) {
      string sym = Pairs[i];
      int symDigits = (int)MarketInfo(sym, MODE_DIGITS);
      int priority = GetPairPriority(sym);
      if(priority == 0) continue;
      
      int direction = GetTradeDirection(sym);
      if(direction == 0) continue;
      
      // Check filters and build rule status (show FAIL with no-trade action)
      bool spreadOk = IsSpreadOK(sym);
      bool volOk = IsVolatilityOK(sym);
      bool newsOk = !newsNow;
      bool adxOk = IsMarketTrending(sym);
      bool h4Align = IsH4CandleAligned(sym, direction);
      bool currencyExposureOk = IsWithinCurrencyExposureLimit(sym);
      string adxLabel = GetADXLabel(sym);

      // Use NEW S/R + RSI based pullback detection
      double entry = 0, sl = 0, tp = 0;
      int quality = GetPullbackQualityV2(sym, entry, sl, tp);

      double pipVal = PipValue(sym);
      double slPips = (entry > 0 && sl > 0 && pipVal > 0) ? MathAbs(entry - sl) / pipVal : 0;
      double tpPips = (entry > 0 && tp > 0 && pipVal > 0) ? MathAbs(tp - entry) / pipVal : 0;
      double rr = (slPips > 0 && tpPips > 0) ? (tpPips / slPips) : 0;
      bool qualityOk = (quality >= 2);
      bool srOk = (entry > 0 && sl > 0 && tp > 0);
      bool tpOk = (tpPips >= g_MinTPPips);
      bool rrOk = (!EnableRRFilter || rr >= g_MinRR);
      bool strictSlOk = !(StrictMaxSLPips > 0 && slPips > StrictMaxSLPips);
      bool strictRrOk = (!EnableRRFilter || !(g_StrictMinRR > 0 && rr < g_StrictMinRR));
      
      double lotSize = CalculateLotSize(sym, slPips);
      double tickValue = MarketInfo(sym, MODE_TICKVALUE);
      double tickSize  = MarketInfo(sym, MODE_TICKSIZE);
      double pipSize   = pipVal;
      double pipValueMoneyPerLot = (tickValue > 0 && tickSize > 0 && pipSize > 0) ? (tickValue * (pipSize / tickSize)) : 0;
      double riskMoney = (pipValueMoneyPerLot > 0 && slPips > 0) ? (slPips * lotSize * pipValueMoneyPerLot) : 0;
      double riskPct = (AccountBalance() > 0) ? (riskMoney / AccountBalance() * 100.0) : 0;
      double minLot = MarketInfo(sym, MODE_MINLOT);
      
      // Get S/R info for display
      double srLevel = 0;
      int srTouches = 0;
      bool atSR = IsPriceAtSR(sym, direction, srLevel, srTouches);
      if(!atSR) {
         srLevel = GetNearestSRLevel(sym, direction, srTouches);
      }
      string srInfo = (srTouches > 0) ? " [PB-SR-" + GetSRStrength(srTouches) + "]" : " [PB-SR-NO SR]";
      
      // Check for multi-TF confluence
      bool hasConfluence = HasPairTFConfluence(sym, direction);
      string confluenceTag = hasConfluence ? " [CONFLUENCE]" : "";

      // JPY high-quality only filter
      bool jpyOk = true;
      if(JPY_HQ_Only && IsJPYPair(sym)) {
         if(quality < g_JPY_MinQuality) jpyOk = false;
         if(srTouches < JPY_MinSRTouches) jpyOk = false;
         if(EnableRRFilter && rr < JPY_MinRR) jpyOk = false;
      }

      // Skip signals if there's an open correlated trade (unless HQ rule allows)
      bool hasOpenCorr = SkipCorrelatedIfOpen && HasOpenCorrelatedTrade(sym);
      bool allowCorrelated = false;
      if(hasOpenCorr && AllowCorrelatedHighQuality) {
         if(priority <= 3 && quality >= g_CorrelatedMinQuality && srTouches >= CorrelatedMinSRTouches && (!EnableRRFilter || rr >= CorrelatedMinRR)) {
            allowCorrelated = true;
         }
      }
      bool corrOk = !(hasOpenCorr && !allowCorrelated);
      string openCorrWarn = (hasOpenCorr && allowCorrelated) ? "Open correlated trade (HQ allowed)" : "";
      
      // Check for correlation warning
      string correlationWarn = GetCorrelationWarning(sym, direction);
      
      // Check RSI zone warning
      double rsi = iRSI(sym, PERIOD_H1, RSI_Period, PRICE_CLOSE, 0);
      string rsiWarning = "";
      bool rsiInCorrectZone = false;
      
      if(direction == 1) {  // BUY
         if(rsi >= RSI_BuyZoneLow && rsi <= RSI_BuyZoneHigh) {
            rsiInCorrectZone = true;
         } else if(rsi > 70) {
            rsiWarning = "RSI Overbought (" + DoubleToStrClean(rsi, 0) + ") - Risky";
         } else if(rsi < 30) {
            rsiWarning = "RSI Oversold (" + DoubleToStrClean(rsi, 0) + ") - Good";
         } else {
            rsiWarning = "RSI=" + DoubleToStrClean(rsi, 0) + " (Wait " + IntegerToString(RSI_BuyZoneLow) + "-" + IntegerToString(RSI_BuyZoneHigh) + ")";
         }
      } else {  // SELL
         if(rsi >= RSI_SellZoneLow && rsi <= RSI_SellZoneHigh) {
            rsiInCorrectZone = true;
         } else if(rsi < 30) {
            rsiWarning = "RSI Oversold (" + DoubleToStrClean(rsi, 0) + ") - Risky";
         } else if(rsi > 70) {
            rsiWarning = "RSI Overbought (" + DoubleToStrClean(rsi, 0) + ") - Good";
         } else {
            rsiWarning = "RSI=" + DoubleToStrClean(rsi, 0) + " (Wait " + IntegerToString(RSI_SellZoneLow) + "-" + IntegerToString(RSI_SellZoneHigh) + ")";
         }
      }
      
      // Check if entry requires waiting for pullback
      double currentPrice = (direction == 1) ? MarketInfo(sym, MODE_ASK) : MarketInfo(sym, MODE_BID);
      string entryNote = "";
      string orderType = "";
      double pipsToEntry = (entry > 0 && pipVal > 0) ? MathAbs(entry - currentPrice) / pipVal : 0;
      bool atSRNowForConfirm = false;
      if(entry > 0 && pipsToEntry <= MaxLateEntryPips) {
         double srNow = 0;
         int srTouchesNow = 0;
         atSRNowForConfirm = IsPriceAtSR(sym, direction, srNow, srTouchesNow);
      }
      bool confirmNow = (entry > 0 && pipsToEntry <= MaxLateEntryPips && atSRNowForConfirm && HasPullbackConfirmation(sym, direction));

      if(entry > 0) {
         if(direction == 1 && entry < currentPrice && pipsToEntry > MaxLateEntryPips) {
            entryNote = " (Wait for dip)";
            orderType = "PENDING BUY LIMIT @ " + DoubleToStrClean(entry, symDigits);
         } else if(direction == -1 && entry > currentPrice && pipsToEntry > MaxLateEntryPips) {
            entryNote = " (Wait for rally)";
            orderType = "PENDING SELL LIMIT @ " + DoubleToStrClean(entry, symDigits);
         } else if(pipsToEntry <= MaxLateEntryPips) {
            if(confirmNow) {
               // Fetch confirmation details from cache set by HasPullbackConfirmation()
               string confirmMsg = "";
               string infoMsg = "";
               if(g_lastConfirmSym == sym && g_lastConfirmDir == direction) {
                  confirmMsg = g_lastConfirmMsg;
                  infoMsg = g_lastConfirmInfo;
               }
               entryNote = " (NOW)" + ((StringLen(confirmMsg) > 0) ? (" ["+confirmMsg+"]") : "");
               if(StringLen(infoMsg) > 0) entryNote += " | Info: " + infoMsg;
               orderType = (direction == 1) ? "MARKET BUY NOW" : "MARKET SELL NOW";
            } else {
               entryNote = " (Wait confirmation)";
               orderType = "WAIT CONFIRMATION AT SR";
            }
         } else {
            orderType = (direction == 1) ? "PENDING BUY" : "PENDING SELL";
         }
      } else {
         orderType = "N/A";
      }

      string orderTypeShort = (entry > 0 && pipsToEntry <= MaxLateEntryPips && confirmNow) ? "MKT" : "PEND";
      
      string stars = GetQualityStars(quality);
      if(StringLen(stars) < 1) continue; // only show PB signals with at least one star
      string pbTag = "PB[" + (stars == "" ? "-" : stars) + "]";
      string prioLabel = (priority == 1) ? "[P1]" : (priority == 2) ? "[P2]" : "[P3]";

      // Alert flood control: skip if same signal was already sent recently with no changes
      if(OnlyAlertOnNewSignals && !IsSignalNewOrChanged(sym, direction, quality, priority)) continue;

        if(DEBUG_PRINT) {
          string dirLabel = (direction == 1) ? "BUY" : "SELL";
          Log("Signal " + sym + " " + dirLabel + " | Entry " + DoubleToStrClean(entry, symDigits) +
             " TP " + DoubleToStrClean(tp, symDigits) + " RR " + DoubleToStrClean(rr, 2) +
             " SRTouches " + IntegerToString(srTouches));
        }
      
      // Build rule status line
      bool hqRiskBypass = false;
      if(AllowHQRiskBypass && riskBlocked) {
         if(quality >= HQRiskBypassMinQuality && srTouches >= HQRiskBypassMinSRTouches && (!EnableRRFilter || rr >= HQRiskBypassMinRR) &&
            spreadOk && volOk && newsOk && srOk && tpOk && strictSlOk && strictRrOk && jpyOk && corrOk) {
            hqRiskBypass = true;
         }
      }
      bool riskOk = (!riskBlocked || hqRiskBypass);

      string rules = "<b>RULES:</b> ";
      rules += (spreadOk ? "Spread OK" : "Spread FAIL");
      rules += " | " + (volOk ? "Vol OK" : "Vol FAIL");
      rules += " | " + (newsOk ? "News OK" : "News FAIL");
      rules += " | " + (qualityOk ? "Q>=2 OK" : "Q>=2 FAIL");
      rules += " | " + (adxOk ? adxLabel : "ADX FAIL[RANGING]");
      rules += " | " + (h4Align ? "H4 OK" : "H4 FAIL");

      rules += "\n  " + (srOk ? "SR Entry/TP OK" : "SR Entry/TP FAIL");
      rules += " | " + (tpOk ? "TP>=" + DoubleToStrClean(g_MinTPPips, 0) + "p OK" : "TP>=" + DoubleToStrClean(g_MinTPPips, 0) + "p FAIL");
      if(EnableRRFilter) rules += " | " + (rrOk ? "RR>=" + DoubleToStrClean(g_MinRR, 1) + " OK" : "RR>=" + DoubleToStrClean(g_MinRR, 1) + " FAIL");
      else rules += " | RR FILTER OFF";
      rules += " | " + (riskOk ? "Risk OK" : "Risk FAIL");
      rules += " | " + (currencyExposureOk ? "Exposure OK" : "Exposure MAX");

      rules += "\n  " + (drawdownOk ? "DD OK" : "DD FAIL");
      rules += " | " + (sessionOkGlobal ? "Session OK" : "Session FAIL");
      rules += " | " + (lockOkGlobal ? "Lock OFF" : "Lock ON");
      if(JPY_HQ_Only && IsJPYPair(sym)) {
         rules += " | " + (jpyOk ? "JPY HQ OK" : "JPY HQ FAIL");
      }
      rules += " | " + (corrOk ? "Corr OK" : "Corr FAIL");

      bool rulesPass = spreadOk && volOk && newsOk && qualityOk && srOk && tpOk && rrOk && strictSlOk && strictRrOk && jpyOk && corrOk && riskOk && drawdownOk && sessionOkGlobal && lockOkGlobal && adxOk && h4Align && currencyExposureOk;

      string action = "<b>ACTION:</b> ";
      if(rulesPass) {
         if(entry > 0 && pipsToEntry <= MaxLateEntryPips) {
            if(confirmNow) action += "TRADE NOW if rules pass.";
            else action += "WAIT for confirmation candle at S/R before entry.";
         } else {
            action += "Set pending at entry; trade only if price stays within max entry limit.";
         }
      } else {
         if(!drawdownOk) action += "NO TRADE - drawdown limit reached. ";
         if(!sessionOkGlobal) action += "NO TRADE - outside allowed sessions. ";
         if(!lockOkGlobal) action += "NO TRADE - lock hedge active. ";
         if(!riskOk) action += "NO TRADE - max daily risk reached. ";
         if(!newsOk) action += "NO TRADE - news filter active. ";
         else if(!spreadOk) action += "NO TRADE - spread too high. ";
         else if(!volOk) action += "NO TRADE - volatility out of range. ";
         else if(!adxOk) action += "NO TRADE - market ranging (ADX below " + DoubleToStrClean(MinADX, 0) + "). ";
         else if(!h4Align) action += "NO TRADE - H4 candle not aligned. ";
         else if(!currencyExposureOk) action += "NO TRADE - max trades per currency reached. ";
         else if(!srOk) action += "NO TRADE - no valid S/R entry/TP. ";
         else if(!qualityOk) action += "NO TRADE - quality < 2. ";
         else if(!tpOk) action += "NO TRADE - TP below minimum. ";
         else if(!rrOk) action += "NO TRADE - RR below " + DoubleToStrClean(g_MinRR, 1) + ". ";
         else if(!jpyOk) action += "NO TRADE - JPY HQ not met. ";
         else if(!corrOk) action += "NO TRADE - open correlated trade. ";
         else if(!strictSlOk) action += "NO TRADE - SL too wide. ";
         else if(!strictRrOk) action += "NO TRADE - strict RR not met. ";
         else action += "NO TRADE - rule fail.";
      }

      // Auto-trade execution (optional)
      if(rulesPass && AutoTradingActive() && entry > 0 && !HasOpenOrderForDirection(sym, direction)) {
         if(pipsToEntry <= MaxLateEntryPips) {
            if(confirmNow) {
               PlaceAutoMarketOrder(sym, direction, lotSize, sl, tp);
            }
         } else {
            PlaceAutoPendingOrder(sym, direction, lotSize, entry, sl, tp);
         }
      }

      // Compact signal format with S/R info, confluence, and pips
      // --- Signal quality decay: flag signals older than 4 hours ---
      double signalAgeHrs = GetSignalAgeHours(sym, direction);
      bool isStale = (signalAgeHrs >= 4.0);
      string staleTag = isStale ? " ⚠️[STALE " + DoubleToStrClean(signalAgeHrs, 0) + "h]" : "";
      if(isStale) action = "<b>ACTION:</b> ⚠️ STALE SIGNAL (" + DoubleToStrClean(signalAgeHrs, 0) + "h old) - VERIFY BIAS/SR STILL VALID before acting.";

      string signal = "<code>" + sym + "</code> " + pbTag + " " + prioLabel + srInfo + confluenceTag + staleTag + "\n";
      if(adxLabel != "") signal += "  " + adxLabel + (h4Align ? " | H4:OK" : " | H4:FAIL") + "\n";
      if(entry > 0 && sl > 0) {
         signal += "  <b>Entry:</b> " + DoubleToStrClean(entry, symDigits) + entryNote;
         signal += " | <b>SL:</b> " + DoubleToStrClean(sl, symDigits);
         signal += " (" + DoubleToStrClean(slPips, 0) + "p)\n";
      } else {
         signal += "  <b>Entry:</b> N/A | <b>SL:</b> N/A\n";
      }
      if(tp > 0) {
         signal += "  <b>TP:</b> " + DoubleToStrClean(tp, symDigits);
         signal += " (" + DoubleToStrClean(tpPips, 0) + "p)";
      } else {
         signal += "  <b>TP:</b> N/A";
      }
      if(rr > 0) signal += " | R:R <b>" + DoubleToStrClean(rr, 1) + "</b>";
      signal += " | Lot: " + DoubleToStrClean(lotSize, 2);
      signal += " | Risk: $" + DoubleToStrClean(riskMoney, 2) + " (" + DoubleToStrClean(riskPct, 1) + "%)\n";
      if(lotSize > 0 && lotSize < minLot) {
         signal += "  <b>RULE:</b> Skip if lot < minimum (" + DoubleToStrClean(minLot, 2) + ")\n";
      }
      signal += "  <b>ORDER:</b> <i>" + orderType + "</i>";
      signal += "\n  " + action;
      signal += "\n  " + rules;
      if(entry > 0 && pipsToEntry <= MaxLateEntryPips) {
         double maxEntryPrice = entry + ((direction == 1) ? (MaxLateEntryPips * pipVal) : (-MaxLateEntryPips * pipVal));
         signal += "\n  <b>RULE:</b> Skip if price moves > " + DoubleToStrClean(MaxLateEntryPips, 0) + " pips from entry";
         string entryLabel = (direction == 1) ? "MAX ENTRY (BUY)" : "MIN ENTRY (SELL)";
         signal += "\n  <b>" + entryLabel + ":</b> " + DoubleToStrClean(maxEntryPrice, symDigits);
      }
      if(rsiWarning != "") signal += "\n  ! " + rsiWarning;
      if(correlationWarn != "") signal += "\n  ! " + correlationWarn;
      if(openCorrWarn != "") signal += "\n  ! " + openCorrWarn;
      signal += "\n\n";

      DrawChartSignal(sym, direction, entry, quality, priority, orderTypeShort);
      
      if(direction == 1) {
         buyCount++;
         if(priority == 1) priority1Buy += signal;
         else if(priority == 2) priority2Buy += signal;
         else priority3Buy += signal;
      } else {
         sellCount++;
         if(priority == 1) priority1Sell += signal;
         else if(priority == 2) priority2Sell += signal;
         else priority3Sell += signal;
      }
   }
   
   // Add signals to message (grouped by priority)
   msg += "\n==============================\n";
   msg += "==============================\n";
   msg += "<b>INVALID PAIRS</b>: " + (invalidCount > 0 ? invalidPairs : "None") + "\n\n";
   msg += "==============================\n";
   msg += "==============================\n";
   msg += "<b>^ LONG SIGNALS</b>\n";
   if(buyCount == 0) msg += "None\n";
   else {
      if(priority1Buy != "") msg += priority1Buy;
      if(priority2Buy != "") msg += priority2Buy;
      if(priority3Buy != "") msg += priority3Buy;
   }
   
   msg += "\n==============================\n";
   msg += "==============================\n";
   msg += "<b>v SHORT SIGNALS</b>\n";
   if(sellCount == 0) msg += "None\n";
   else {
      if(priority1Sell != "") msg += priority1Sell;
      if(priority2Sell != "") msg += priority2Sell;
      if(priority3Sell != "") msg += priority3Sell;
   }
   
   // Next scan
   datetime nextH1 = iTime(Symbol(), PERIOD_H1, 0) + 3600;
   int minsLeft = (int)((nextH1 - TimeCurrent()) / 60);
   msg += "\nNext scan in: " + IntegerToString(minsLeft) + " minutes";
   
   return msg;
}

//+------------------------------------------------------------------+
//| BREAKOUT ALERTS                                                   |
//+------------------------------------------------------------------+
void SendBreakoutDetectedAlert(string sym, double level, int dir) {
   string key = StringFormat("breakout:%s:%d:%.*f", sym, dir, (int)MarketInfo(sym, MODE_DIGITS), level);
   if(!CanSendAlert(key, AlertCooldownMins)) return;

   string direction = (dir == 1) ? "BUY" : "SELL";
   string action = (dir == 1) ? "broke above" : "broke below";
   
   double currentPrice = (dir == 1) ? MarketInfo(sym, MODE_ASK) : MarketInfo(sym, MODE_BID);
   double pipVal = PipValue(sym);
   double pipsFromLevel = (pipVal > 0) ? (MathAbs(currentPrice - level) / pipVal) : 0;
   double sl = CalculateSL(sym, dir);
   double slPips = (pipVal > 0) ? (MathAbs(currentPrice - sl) / pipVal) : 0;
   double lotSize = (slPips > 0) ? CalculateLotSize(sym, slPips) : 0;
   double tickValue = MarketInfo(sym, MODE_TICKVALUE);
   double tickSize  = MarketInfo(sym, MODE_TICKSIZE);
   double pipSize   = PipValue(sym);
   double pipValueMoneyPerLot = (tickValue > 0 && tickSize > 0 && pipSize > 0) ? (tickValue * (pipSize / tickSize)) : 0;
   double riskMoney = (pipValueMoneyPerLot > 0) ? (slPips * lotSize * pipValueMoneyPerLot) : 0;
   double riskPct = (AccountBalance() > 0) ? (riskMoney / AccountBalance() * 100.0) : 0;
   double minLot = MarketInfo(sym, MODE_MINLOT);

   string msg = "<b>BREAKOUT DETECTED</b>" + TGTag() + "\n\n";
   msg += "<b>" + direction + "</b> <code>" + sym + "</code> " + action + " <b>" + DoubleToStrClean(level, (int)MarketInfo(sym, MODE_DIGITS)) + "</b>\n\n";
   msg += "Current: " + DoubleToStrClean(currentPrice, (int)MarketInfo(sym, MODE_DIGITS)) + "\n";
   msg += "Distance from level: " + DoubleToStrClean(pipsFromLevel, 0) + " pips\n\n";
   msg += "Est. SL: " + DoubleToStrClean(sl, (int)MarketInfo(sym, MODE_DIGITS));
   if(slPips > 0) msg += " (" + DoubleToStrClean(slPips, 0) + " pips)";
   msg += "\n";
   msg += "Est. Lot: " + DoubleToStrClean(lotSize, 2) + "\n";
   if(riskMoney > 0) msg += "Est. Risk: $" + DoubleToStrClean(riskMoney, 2) + " (" + DoubleToStrClean(riskPct, 1) + "%)\n";
   if(lotSize > 0 && lotSize < minLot) {
      msg += "NOTE: Lot below minimum (min " + DoubleToStrClean(minLot, 2) + ")\n";
      msg += "RULE: Skip if lot < minimum\n";
   }
   msg += "\n";
   msg += "<b>Status:</b> WAITING FOR RETEST\n";
   msg += "<b>ACTION:</b> Wait for retest of level then bearish/bullish candle confirmation.\n";
   msg += "<b>STRICT RULE:</b> No entry until retest + confirmation candle.\n";
   
   MarkAlertBadge();
   SendTelegram(msg);
}

void SendRetestConfirmedAlert(string sym, double level, int dir) {
   string key = StringFormat("retest:%s:%d:%.*f", sym, dir, (int)MarketInfo(sym, MODE_DIGITS), level);
   if(!CanSendAlert(key, AlertCooldownMins)) return;

   string direction = (dir == 1) ? "BUY" : "SELL";
   
   double entry = (dir == 1) ? MarketInfo(sym, MODE_ASK) : MarketInfo(sym, MODE_BID);
   double sl = CalculateSL(sym, dir);
   double tp = 0;
   double nextSR = GetNextSRForTP(sym, dir, level);
   if(nextSR > 0) {
      tp = nextSR;
   }
   double pipValRetest = PipValue(sym);
   if(pipValRetest <= 0) pipValRetest = MarketInfo(sym, MODE_POINT);
   if(pipValRetest <= 0) pipValRetest = 0.0001;
   double slPips = MathAbs(entry - sl) / pipValRetest;
   double tpPips = (tp > 0) ? MathAbs(tp - entry) / pipValRetest : 0;
   double rr = (slPips > 0 && tpPips > 0) ? (tpPips / slPips) : 0;
   double lotSize = CalculateLotSize(sym, slPips);
   double tickValue = MarketInfo(sym, MODE_TICKVALUE);
   double tickSize  = MarketInfo(sym, MODE_TICKSIZE);
   double pipSize   = PipValue(sym);
   double pipValueMoneyPerLot = (tickValue > 0 && tickSize > 0 && pipSize > 0) ? (tickValue * (pipSize / tickSize)) : 0;
   double riskMoney = (pipValueMoneyPerLot > 0) ? (slPips * lotSize * pipValueMoneyPerLot) : 0;
   double riskPct = (AccountBalance() > 0) ? (riskMoney / AccountBalance() * 100.0) : 0;
   double minLot = MarketInfo(sym, MODE_MINLOT);

   // Skip retest alerts during news/spread spike or if strict rules fail
   string skipReasons = "";
   if(GetNewsNowCached()) skipReasons += "- News time\n";
   if(!IsSpreadOK(sym)) skipReasons += "- Spread too high\n";
   if(tp <= 0) skipReasons += "- No valid S/R TP\n";
   if(g_MinTPPips > 0 && tpPips < g_MinTPPips) skipReasons += "- TP too small\n";
   if(StrictMaxSLPips > 0 && slPips > StrictMaxSLPips) skipReasons += "- SL too wide\n";
   if(EnableRRFilter && g_MinRR > 0 && rr < g_MinRR) skipReasons += "- RR too low\n";
   if(EnableRRFilter && g_StrictMinRR > 0 && rr < g_StrictMinRR) skipReasons += "- RR too low\n";

   double pipVal = PipValue(sym);
   double distFromLevelPips = 0;
   if(pipVal > 0) distFromLevelPips = MathAbs(entry - level) / pipVal;
   if(pipVal > 0 && MaxLateEntryPips > 0 && distFromLevelPips > MaxLateEntryPips) {
      skipReasons += "- Late retest (beyond max entry)\n";
      MarkSkipLabel("SKIP: Late entry " + sym);
   }

   // JPY HQ rule for breakout retests
   if(JPY_HQ_Only && IsJPYPair(sym)) {
      double srLevel = 0;
      int srTouches = 0;
      bool atSR = IsPriceAtSR(sym, dir, srLevel, srTouches);
      if(!atSR) skipReasons += "- JPY HQ: not at SR\n";
      if(srTouches < JPY_MinSRTouches) skipReasons += "- JPY HQ: weak SR touches\n";
      if(EnableRRFilter && rr < JPY_MinRR) skipReasons += "- JPY HQ: RR too low\n";
   }

   if(skipReasons != "") {
      string skipKey = StringFormat("retest-skip:%s:%d:%.*f", sym, dir, (int)MarketInfo(sym, MODE_DIGITS), level);
      if(CanSendAlert(skipKey, AlertCooldownMins)) {
         string dirLabel = (dir == 1) ? "BUY" : "SELL";
         int digits = (int)MarketInfo(sym, MODE_DIGITS);
         string msg = "<b>RETEST SKIPPED</b>" + TGTag() + "\n\n";
         msg += dirLabel + " " + sym + "\n\n";
         msg += "Entry: NOW at " + DoubleToStrClean(entry, digits) + "\n";
         msg += "Level: " + DoubleToStrClean(level, digits) + "\n";
         if(distFromLevelPips > 0) msg += "Distance from level: " + DoubleToStrClean(distFromLevelPips, 0) + " pips\n";
         msg += "SL: " + DoubleToStrClean(sl, digits) + " (" + DoubleToStrClean(slPips, 0) + " pips)\n";
         if(tp > 0) {
            msg += "TP: " + DoubleToStrClean(tp, digits) + " (" + DoubleToStrClean(tpPips, 0) + " pips)\n";
            msg += "R:R: " + DoubleToStrClean(rr, 1) + "\n\n";
         } else {
            msg += "TP: N/A (no valid S/R)\n";
            msg += "R:R: N/A\n\n";
         }
         msg += "Reasons:\n" + skipReasons;
         msg += "\nNOTE: No trade opened.\n";
         msg += "ACTION: No trade. Wait for a clean retest.\n";
         MarkAlertBadge();
         SendTelegram(msg);
      }
      return;
   }
   
   string msg = "<b>RETEST CONFIRMED</b>" + TGTag() + "\n\n";
   msg += direction + " " + sym + "\n\n";
   msg += "Entry: NOW at " + DoubleToStrClean(entry, (int)MarketInfo(sym, MODE_DIGITS)) + "\n";
   msg += "SL: " + DoubleToStrClean(sl, (int)MarketInfo(sym, MODE_DIGITS)) + " (" + DoubleToStrClean(slPips, 0) + " pips)\n";
   msg += "TP: " + DoubleToStrClean(tp, (int)MarketInfo(sym, MODE_DIGITS)) + " (" + DoubleToStrClean(tpPips, 0) + " pips)\n";
   msg += "R:R: " + DoubleToStrClean(rr, 1) + "\n";
   msg += "Lot: " + DoubleToStrClean(lotSize, 2) + " (2% risk)\n";
   if(riskMoney > 0) msg += "Risk: $" + DoubleToStrClean(riskMoney, 2) + " (" + DoubleToStrClean(riskPct, 1) + "%)\n";
   if(lotSize > 0 && lotSize < minLot) {
      msg += "NOTE: Lot below minimum (min " + DoubleToStrClean(minLot, 2) + ")\n";
      msg += "RULE: Skip if lot < minimum\n";
   }
   if(lotSize <= 0) {
      msg += "NOTE: Lot=0 because risk budget used / SL too wide\n";
      msg += "RULE: Skip if Lot=0.00\n";
   }
   msg += "ORDER: MARKET " + direction + " NOW\n";
   double maxEntryPrice = entry + ((dir == 1) ? (MaxLateEntryPips * PipValue(sym)) : (-MaxLateEntryPips * PipValue(sym)));
   msg += "RULE: Skip if price moves > " + DoubleToStrClean(MaxLateEntryPips, 0) + " pips from entry\n";
   string entryLabel = (dir == 1) ? "MAX ENTRY (BUY)" : "MIN ENTRY (SELL)";
   msg += entryLabel + ": " + DoubleToStrClean(maxEntryPrice, (int)MarketInfo(sym, MODE_DIGITS)) + "\n";
   msg += "CHECKLIST:\n";
   msg += "- Price still within entry limit\n";
   msg += "- News/spread OK\n";
   msg += "- Bias/confluence still aligned\n";
   msg += "ACTION: Enter only if checklist passes and price within max entry.\n";
   
   MarkAlertBadge();
   SendTelegram(msg);
}

//+------------------------------------------------------------------+
//| BIAS REVERSAL ALERT                                               |
//+------------------------------------------------------------------+
string lastBiasState[7];

void CheckBiasReversal() {
   for(int i = 0; i < 7; i++) {
      string cur = Currencies[i];
      string currentBias = GetBiasLabel(cur);
      
      if(lastBiasState[i] != "" && lastBiasState[i] != currentBias) {
         SendBiasReversalAlert(cur, lastBiasState[i], currentBias);
      }
      
      lastBiasState[i] = currentBias;
   }
}

void SendBiasReversalAlert(string cur, string oldBias, string newBias) {
   string key = "bias_reversal:" + cur;
   if(!CanSendAlert(key, AlertCooldownMins)) return;
   string msg = "<b>⚠️ BIAS REVERSAL ALERT ⚠️</b>" + TGTag() + "\n";
   msg += "[TIME] " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + "\n\n";
   
   // Currency and change
   msg += "<b>" + cur + ":</b> " + oldBias + " → " + newBias + "\n\n";
   
   // Show current scores
   double d1 = CurrencyTFScoreNorm(cur, PERIOD_D1);
   double h4 = CurrencyTFScoreNorm(cur, PERIOD_H4);
   double h1 = CurrencyTFScoreNorm(cur, PERIOD_H1);
   msg += "Current Scores:\n";
   msg += "D1: " + DoubleToStrClean(d1, 2) + " | H4: " + DoubleToStrClean(h4, 2) + " | H1: " + DoubleToStrClean(h1, 2) + "\n\n";
   
   // Determine action based on change
   string action = "";
   if(oldBias == "STRONG" && (newBias == "NEUTRAL" || newBias == "WEAK")) {
      action = "⚠️ Close BUY positions on " + cur + " pairs";
   } else if(oldBias == "WEAK" && (newBias == "NEUTRAL" || newBias == "STRONG")) {
      action = "⚠️ Close SELL positions on " + cur + " pairs";
   } else if(oldBias == "NEUTRAL" && newBias == "STRONG") {
      action = "📈 Look for BUY opportunities on " + cur + " pairs";
   } else if(oldBias == "NEUTRAL" && newBias == "WEAK") {
      action = "📉 Look for SELL opportunities on " + cur + " pairs";
   }
   
   if(action != "") {
      msg += "<b>ACTION:</b>\n" + action + "\n\n";
   }
   
   // Find affected pairs
   msg += "Affected Pairs:\n";
   int pairCount = 0;
   for(int i = 0; i < PairsCount; i++) {
      string sym = Pairs[i];
      if(StringFind(sym, cur) >= 0) {
         msg += "• " + sym + "\n";
         pairCount++;
         if(pairCount >= 6) {
            msg += "• ...\n";
            break;
         }
      }
   }
   msg += "\nACTION: Reduce exposure on affected pairs.\n";
   
   MarkAlertBadge();
   SendTelegram(msg);
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
      
      SendTelegram(msg);
   }
}

//+------------------------------------------------------------------+
//| TRAILING STOP ALERT - Monitor Open Trades                         |
//+------------------------------------------------------------------+
void CheckTrailingStopAlerts() {
   if(!EnableSLAlerts) return;
   if(TimeCurrent() - lastTrailingCheck < 300) return;  // Check every 5 minutes
   lastTrailingCheck = TimeCurrent();
   
   int totalOrders = OrdersTotal();
   if(totalOrders == 0) return;
   
   for(int i = 0; i < totalOrders; i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      
      int ticket = OrderTicket();
      string sym = OrderSymbol();
      int type = OrderType();
      double entry = OrderOpenPrice();
      double sl = OrderStopLoss();
      double tp = OrderTakeProfit();
      double lots = OrderLots();
      double currentPrice = (type == OP_BUY) ? MarketInfo(sym, MODE_BID) : MarketInfo(sym, MODE_ASK);
      double pipVal = PipValue(sym);
      double atr = iATR(sym, PERIOD_H1, ATRPeriod, 0);
      
      // SR-based partial TP check (before regular trailing)
      if(type == OP_BUY || type == OP_SELL) {
         CheckSRBasedPartialTP(ticket);
      }
      
      // Calculate profit in pips
      double profitPips = 0;
      if(type == OP_BUY) {
         profitPips = (currentPrice - entry) / pipVal;
      } else {
         profitPips = (entry - currentPrice) / pipVal;
      }
      
      // Alert if profit >= trigger and SL not at breakeven yet
      if(profitPips >= TrailingTriggerPips) {
         double suggestedSL = 0;
         string method = "BREAKEVEN";
         bool autoPartialDone = false;
         string autoPartialNote = "";
         double partialCloseLots = 0;
         double partialRemainingLots = 0;
         double minLot = MarketInfo(sym, MODE_MINLOT);

         if(PartialClosePct > 0 && profitPips >= PartialCloseAtPips) {
            double lotStep = MarketInfo(sym, MODE_LOTSTEP);
            double closeLotsRaw = lots * (PartialClosePct / 100.0);
            double closeLots = (lotStep > 0) ? MathFloor(closeLotsRaw / lotStep) * lotStep : closeLotsRaw;
            closeLots = NormalizeDouble(closeLots, 2);
            if(lots <= minLot) closeLots = 0;
            if(closeLots > (lots - minLot)) closeLots = lots - minLot;
            double remainingLots = lots - closeLots;

            partialCloseLots = closeLots;
            partialRemainingLots = remainingLots;

            if(!IsPartialCloseDone(ticket) && closeLots >= minLot && remainingLots >= minLot) {
               if(AutoPartialCloseTrade(ticket, closeLots)) {
                  MarkPartialCloseDone(ticket);
                  autoPartialDone = true;
                  autoPartialNote = "AUTO: Partial close executed (" + DoubleToStrClean(closeLots, 2) + " lots)";
               } else if(AutoPartialClose && AutoTradingActive()) {
                  autoPartialNote = "AUTO: Partial close failed";
               }
            }
         }

         if(type == OP_BUY) {
            suggestedSL = entry + (BreakEvenBufferPips * pipVal);
            if(UseATRTrailSuggestion && atr > 0 && profitPips >= (TrailingTriggerPips * 2.0)) {
               double atrSL = currentPrice - (ATRTrailMult * atr);
               if(atrSL > suggestedSL) { suggestedSL = atrSL; method = "ATR TRAIL"; }
            }
            if(sl == 0 || sl < (suggestedSL - (0.5 * pipVal))) {  // SL still below suggested level by at least 0.5 pip
               if(AutoTradingActive() && AutoTrailStops) {
                  AutoModifySL(ticket, suggestedSL);
               }
               string key = "trail:" + sym + ":" + IntegerToString(ticket);
               if(CanSendAlert(key, AlertCooldownMins))
                  SendTrailingAlert(sym, type, entry, sl, currentPrice, profitPips, suggestedSL, method, lots,
                                   autoPartialDone, partialCloseLots, partialRemainingLots, autoPartialNote);
            }
         } else if(type == OP_SELL) {
            suggestedSL = entry - (BreakEvenBufferPips * pipVal);
            if(UseATRTrailSuggestion && atr > 0 && profitPips >= (TrailingTriggerPips * 2.0)) {
               double atrSL = currentPrice + (ATRTrailMult * atr);
               if(atrSL < suggestedSL) { suggestedSL = atrSL; method = "ATR TRAIL"; }
            }
            if(sl == 0 || sl > (suggestedSL + (0.5 * pipVal))) {  // SL still above suggested level by at least 0.5 pip
               if(AutoTradingActive() && AutoTrailStops) {
                  AutoModifySL(ticket, suggestedSL);
               }
               string key = "trail:" + sym + ":" + IntegerToString(ticket);
               if(CanSendAlert(key, AlertCooldownMins))
                  SendTrailingAlert(sym, type, entry, sl, currentPrice, profitPips, suggestedSL, method, lots,
                                   autoPartialDone, partialCloseLots, partialRemainingLots, autoPartialNote);
            }
         }
      }
   }
}

void SendTrailingAlert(string sym, int type, double entry, double currentSL, double currentPrice, double profitPips, double suggestedSL, string method, double lots,
                       bool autoPartialDone, double partialCloseLots, double partialRemainingLots, string autoPartialNote) {
   string direction = (type == OP_BUY) ? "BUY" : "SELL";
   int digits = (int)MarketInfo(sym, MODE_DIGITS);
   double pipVal = PipValue(sym);
   double slDistancePips = (pipVal > 0) ? (MathAbs(suggestedSL - entry) / pipVal) : 0;
   double tickValue = MarketInfo(sym, MODE_TICKVALUE);
   double tickSize  = MarketInfo(sym, MODE_TICKSIZE);
   double pipSize   = PipValue(sym);
   double pipValueMoneyPerLot = (tickValue > 0 && tickSize > 0 && pipSize > 0) ? (tickValue * (pipSize / tickSize)) : 0;
   double currentSlPips = (pipVal > 0) ? (MathAbs(entry - currentSL) / pipVal) : 0;
   double riskMoney = (pipValueMoneyPerLot > 0 && currentSlPips > 0) ? (currentSlPips * lots * pipValueMoneyPerLot) : 0;
   double riskPct = (AccountBalance() > 0) ? (riskMoney / AccountBalance() * 100.0) : 0;
   double minLot = MarketInfo(sym, MODE_MINLOT);
   
   string msg = "<b>TRAILING STOP ALERT</b>" + TGTag() + "\n";
   msg += "[TIME] " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + "\n\n";
   msg += "<b>" + sym + " " + direction + "</b>\n\n";
   msg += "Entry: " + DoubleToString(entry, digits) + "\n";
   msg += "Current: " + DoubleToString(currentPrice, digits) + "\n";
   msg += "Profit: +" + DoubleToStrClean(profitPips, 0) + " pips\n\n";
   msg += "Position: " + DoubleToStrClean(lots, 2) + " lots";
   if(riskMoney > 0) msg += " | Risk: $" + DoubleToStrClean(riskMoney, 2) + " (" + DoubleToStrClean(riskPct, 1) + "%)";
   msg += "\n";
   if(lots > 0 && lots < minLot) {
      msg += "NOTE: Lot below minimum (min " + DoubleToStrClean(minLot, 2) + ")\n";
      msg += "RULE: Skip if lot < minimum\n";
   }
   msg += "Current SL: " + DoubleToString(currentSL, digits) + "\n";
   msg += "<b>Suggested SL: " + DoubleToString(suggestedSL, digits) + "</b>\n\n";
   if(slDistancePips > 0) msg += "Suggested SL distance: " + DoubleToStrClean(slDistancePips, 0) + " pips\n";
   msg += "Method: " + method + "\n";
   msg += "Action: Move SL to " + DoubleToString(suggestedSL, digits) + " (" + method + ")\n";
   if(PartialClosePct > 0 && profitPips >= PartialCloseAtPips) {
      double lotStep = MarketInfo(sym, MODE_LOTSTEP);
      double closeLotsRaw = lots * (PartialClosePct / 100.0);
      double closeLots = (lotStep > 0) ? MathFloor(closeLotsRaw / lotStep) * lotStep : closeLotsRaw;
      closeLots = NormalizeDouble(closeLots, 2);
      if(lots <= minLot) closeLots = 0;
      if(closeLots > (lots - minLot)) closeLots = lots - minLot;
      double remainingLots = lots;
      if(closeLots >= minLot) remainingLots = lots - closeLots;

      if(partialCloseLots > 0) closeLots = partialCloseLots;
      if(partialRemainingLots > 0) remainingLots = partialRemainingLots;

      if(autoPartialNote != "") msg += autoPartialNote + "\n";

      msg += "OPTION: Partial close " + DoubleToStrClean(PartialClosePct, 0) + "% (" + DoubleToStrClean(closeLots, 2) + " lots)\n";
      if(closeLots >= minLot && !autoPartialDone) {
         msg += "Steps: Open Trade tab > right-click position > Modify > set Volume " + DoubleToStrClean(closeLots, 2) + " > Close\n";
         msg += "Remaining: " + DoubleToStrClean(remainingLots, 2) + " lots\n";
      } else if(closeLots < minLot) {
         msg += "STRICT RULE: Skip partial close if close lots < min lot (" + DoubleToStrClean(minLot, 2) + ")\n";
      } else if(autoPartialDone) {
         msg += "Remaining: " + DoubleToStrClean(remainingLots, 2) + " lots\n";
      }
      msg += "STRICT RULE: Only partial close at +" + DoubleToStrClean(PartialCloseAtPips, 0) + " pips or more\n";
   }
   msg += "Next: Recheck in 1h";
   
   MarkAlertBadge();
   SendTelegram(msg);
}

//+------------------------------------------------------------------+
//| REVERSAL WARNING - Detect Opposite Signals on Open Trades        |
//+------------------------------------------------------------------+
void CheckReversalWarnings() {
   if(!EnableSLAlerts) return;
   if(TimeCurrent() - lastReversalCheck < 600) return;  // Check every 10 minutes
   lastReversalCheck = TimeCurrent();
   
   int totalOrders = OrdersTotal();
   if(totalOrders == 0) return;
   
   for(int i = 0; i < totalOrders; i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      
      int ticket = OrderTicket();
      string sym = OrderSymbol();
      int type = OrderType();
      
      // Only check market orders (not pending)
      if(type != OP_BUY && type != OP_SELL) continue;
      
      string alertKey = "reversal:" + sym + ":" + IntegerToString(ticket);
      if(!CanSendAlert(alertKey, AlertCooldownMins)) continue;
      
      // Get current trade direction from EA analysis
      int currentDirection = GetTradeDirection(sym);
      
      // Check for reversal: BUY order but EA now says SELL (or vice versa)
      bool isReversal = false;
      if(type == OP_BUY && currentDirection == -1) isReversal = true;
      if(type == OP_SELL && currentDirection == 1) isReversal = true;
      
      if(isReversal) {
         // Get quality of opposite signal
         double oppEntry = 0, oppSL = 0, oppTP = 0;
         int oppQuality = GetPullbackQualityV2(sym, oppEntry, oppSL, oppTP);
         
         // Only alert if opposite signal is high quality (3+ stars)
         if(oppQuality >= 3) {
            if(AutoTradingActive() && AutoTightenSLOnReversal) {
               double entry = OrderOpenPrice();
               double currentPrice = (type == OP_BUY) ? MarketInfo(sym, MODE_BID) : MarketInfo(sym, MODE_ASK);
               double pipVal = PipValue(sym);
               double profitPips = (type == OP_BUY) ? (currentPrice - entry) / pipVal : (entry - currentPrice) / pipVal;
               if(profitPips > 5) {
                  double tightenBy = (profitPips / 2.0) * pipVal;
                  double suggestedSL = (type == OP_BUY) ? (currentPrice - tightenBy) : (currentPrice + tightenBy);
                  AutoModifySL(ticket, suggestedSL);
               }
            }
            SendReversalAlert(ticket, sym, type, oppQuality);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| BIAS-FLIP HEDGE ALERT - Suggest hedge on strong opposite setup   |
//+------------------------------------------------------------------+
void CheckBiasFlipHedgeAlerts() {
   if(!EnableBiasFlipHedge) return;
   if(TimeCurrent() - lastHedgeCheck < 600) return;  // Check every 10 minutes
   lastHedgeCheck = TimeCurrent();

   int totalOrders = OrdersTotal();
   if(totalOrders == 0) return;

   for(int i = 0; i < totalOrders; i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;

      int ticket = OrderTicket();
      string sym = OrderSymbol();
      int type = OrderType();
      double lots = OrderLots();

      if(type != OP_BUY && type != OP_SELL) continue;

      // Opposite direction per current bias
      int currentDirection = GetTradeDirection(sym);
      if(currentDirection == 0) continue;

      bool flipAgainstTrade = false;
      if(type == OP_BUY && currentDirection == -1) flipAgainstTrade = true;
      if(type == OP_SELL && currentDirection == 1) flipAgainstTrade = true;
      if(!flipAgainstTrade) continue;

      // Hedge quality gate (opposite setup quality and RR)
      double qEntry = 0, qSL = 0, qTP = 0;
      int hedgeQuality = GetPullbackQualityV2(sym, qEntry, qSL, qTP);
      double pv = PipValue(sym);
      double slPips = (qEntry > 0 && qSL > 0 && pv > 0) ? MathAbs(qEntry - qSL) / pv : 0;
      double tpPips = (qEntry > 0 && qTP > 0 && pv > 0) ? MathAbs(qTP - qEntry) / pv : 0;
      double rr = (slPips > 0) ? (tpPips / slPips) : 0;
      if(hedgeQuality < HedgeMinQuality) continue;
      if(HedgeMinRR > 0 && rr < HedgeMinRR) continue;

      if(IsBiasFlipHedgeDone(ticket)) continue;

      bool forcedMinHedge = false;
      double hedgeLots = ComputeHedgeLots(sym, lots, forcedMinHedge);
      if(hedgeLots <= 0) continue;

      bool autoPlaced = false;
      if(AutoHedgeOnBiasFlip && AutoTradingActive()) {
         autoPlaced = PlaceAutoMarketOrder(sym, currentDirection, hedgeLots, 0, 0);
         if(autoPlaced) MarkBiasFlipHedgeDone(ticket);
      }

      string key = "hedge:" + sym + ":" + IntegerToString(ticket);
      if(!CanSendAlert(key, AlertCooldownMins)) continue;

      SendHedgeAlert(ticket, sym, type, lots, currentDirection, hedgeLots, autoPlaced, forcedMinHedge);
   }
}

void SendHedgeAlert(int ticket, string sym, int type, double lots, int oppDirection, double hedgeLots, bool autoPlaced, bool forcedMinHedge) {
   int digits = (int)MarketInfo(sym, MODE_DIGITS);
   string direction = (type == OP_BUY) ? "BUY" : "SELL";
   string hedgeDir = (oppDirection == 1) ? "BUY" : "SELL";

   string msg = "<b>HEDGE ALERT (BIAS-FLIP)</b>" + TGTag() + "\n\n";
   msg += "<code>" + sym + " " + direction + "</code> (Ticket #" + IntegerToString(ticket) + ")\n";
   msg += "Bias flipped against position. Immediate hedge rule triggered.\n\n";

   msg += "<b>HEDGE DIRECTION:</b> " + hedgeDir + "\n";
   msg += "ORDER: <i>MARKET " + hedgeDir + " NOW</i>\n";
   msg += "SL/TP: NONE (bypass mode)\n";
   msg += "Risk check: BYPASSED\n";

   double hedgePct = (lots > 0) ? (hedgeLots / lots * 100.0) : 0;
   msg += "Size: current " + DoubleToStrClean(lots, 2) + " | hedge " + DoubleToStrClean(hedgeLots, 2) + " lots (" + DoubleToStrClean(hedgePct, 0) + "%)\n";
   if(forcedMinHedge) {
      msg += "NOTE: Hedge size rounded to minimum lot rule.\n";
   }
   if(autoPlaced) msg += "AUTO: Hedge order placed successfully.\n";
   else if(AutoHedgeOnBiasFlip && !AutoTradingActive()) msg += "AUTO: Hedge enabled but auto trading is OFF.\n";
   else msg += "AUTO: Hedge not placed. Review settings/terminal state.\n";

   msg += "Note: Close hedge if bias flips back.\n";

   MarkAlertBadge();
   SendTelegram(msg);
}

//+------------------------------------------------------------------+
//| BIAS-FLIP EXIT ALERT - Suggest exit if no hedge qualifies        |
//+------------------------------------------------------------------+
void CheckBiasFlipExitAlerts() {
   if(!EnableSLAlerts) return;
   if(!EnableBiasFlipExitAlert) return;
   if(TimeCurrent() - lastExitCheck < 600) return;  // Check every 10 minutes
   lastExitCheck = TimeCurrent();

   int totalOrders = OrdersTotal();
   if(totalOrders == 0) return;

   for(int i = 0; i < totalOrders; i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;

      int ticket = OrderTicket();
      string sym = OrderSymbol();
      int type = OrderType();

      if(type != OP_BUY && type != OP_SELL) continue;

      int currentDirection = GetTradeDirection(sym);
      if(currentDirection == 0) continue;

      bool flipAgainstTrade = false;
      if(type == OP_BUY && currentDirection == -1) flipAgainstTrade = true;
      if(type == OP_SELL && currentDirection == 1) flipAgainstTrade = true;
      if(!flipAgainstTrade) continue;

      // If hedge is enabled, skip exit alert (hedge flow handles this)
      bool hedgeEligible = EnableBiasFlipHedge;
      if(hedgeEligible) continue;

      string key = "exit:" + sym + ":" + IntegerToString(ticket);
      if(!CanSendAlert(key, AlertCooldownMins)) continue;

      if(AutoTradingActive() && AutoTightenSLOnBiasFlip) {
         if(OrderSelect(ticket, SELECT_BY_TICKET)) {
            double entry = OrderOpenPrice();
            double currentPrice = (type == OP_BUY) ? MarketInfo(sym, MODE_BID) : MarketInfo(sym, MODE_ASK);
            double pipVal = PipValue(sym);
            double profitPips = (type == OP_BUY) ? (currentPrice - entry) / pipVal : (entry - currentPrice) / pipVal;
            double suggestedSL = 0;
            if(type == OP_BUY) {
               suggestedSL = (profitPips >= 0) ? (entry + (BreakEvenBufferPips * pipVal)) : (currentPrice - (BreakEvenBufferPips * pipVal));
            } else {
               suggestedSL = (profitPips >= 0) ? (entry - (BreakEvenBufferPips * pipVal)) : (currentPrice + (BreakEvenBufferPips * pipVal));
            }
            AutoModifySL(ticket, suggestedSL);
         }
      }

      SendBiasFlipExitAlert(ticket, sym, type);
   }
}

void SendBiasFlipExitAlert(int ticket, string sym, int type) {
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;

   string direction = (type == OP_BUY) ? "BUY" : "SELL";
   double entry = OrderOpenPrice();
   double sl = OrderStopLoss();
   double tp = OrderTakeProfit();
   int digits = (int)MarketInfo(sym, MODE_DIGITS);
   double currentPrice = (type == OP_BUY) ? MarketInfo(sym, MODE_BID) : MarketInfo(sym, MODE_ASK);
   double pipVal = PipValue(sym);
   double profitPips = 0;

   if(type == OP_BUY) profitPips = (currentPrice - entry) / pipVal;
   else profitPips = (entry - currentPrice) / pipVal;

   string profitStr = (profitPips >= 0 ? "+" : "") + DoubleToStrClean(profitPips, 0) + " pips";

   double suggestedSL = 0;
   if(type == OP_BUY) {
      suggestedSL = (profitPips >= 0) ? (entry + (BreakEvenBufferPips * pipVal)) : (currentPrice - (BreakEvenBufferPips * pipVal));
   } else {
      suggestedSL = (profitPips >= 0) ? (entry - (BreakEvenBufferPips * pipVal)) : (currentPrice + (BreakEvenBufferPips * pipVal));
   }

   string msg = "<b>EXIT ALERT (BIAS-FLIP)</b>" + TGTag() + "\n\n";
   msg += "<code>" + sym + " " + direction + "</code> (Ticket #" + IntegerToString(ticket) + ")\n";
   msg += "Bias flipped against position.\n\n";
   msg += "Entry: " + DoubleToString(entry, digits) + "\n";
   msg += "Current: " + DoubleToString(currentPrice, digits) + "\n";
   msg += "P/L: " + profitStr + "\n\n";
   if(sl > 0 || tp > 0) {
      string slText = (sl > 0) ? DoubleToString(sl, digits) : "-";
      string tpText = (tp > 0) ? DoubleToString(tp, digits) : "-";
      msg += "SL/TP: " + slText + " / " + tpText + "\n\n";
   }

   msg += "<b>ACTION OPTIONS:</b>\n";
   msg += "1. Close now at " + DoubleToString(currentPrice, digits) + " (" + profitStr + ")\n";
   msg += "2. Tighten SL to " + DoubleToString(suggestedSL, digits) + "\n";
   msg += "\nAction: If unsure, choose option 2 to reduce risk.\n";
   msg += "Next: Recheck in 1h\n";

   MarkAlertBadge();
   SendTelegram(msg);
}

void SendReversalAlert(int ticket, string sym, int type, int oppQuality) {
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
   
   string direction = (type == OP_BUY) ? "BUY" : "SELL";
   string oppDirection = (type == OP_BUY) ? "SELL" : "BUY";
   double entry = OrderOpenPrice();
   double lots = OrderLots();
   double sl = OrderStopLoss();
   double tp = OrderTakeProfit();
   int digits = (int)MarketInfo(sym, MODE_DIGITS);
   
   double currentPrice = (type == OP_BUY) ? MarketInfo(sym, MODE_BID) : MarketInfo(sym, MODE_ASK);
   double pipVal = PipValue(sym);
   
   // Calculate current P&L
   double profitPips = 0;
   if(type == OP_BUY) {
      profitPips = (currentPrice - entry) / pipVal;
   } else {
      profitPips = (entry - currentPrice) / pipVal;
   }
   
   string profitStr = (profitPips >= 0 ? "+" : "") + DoubleToStrClean(profitPips, 0) + " pips";
   
   // Calculate suggested tighter SL (50% of current profit)
   double suggestedSL = 0;
   if(profitPips > 10) {  // Only if in profit
      double tightenBy = (profitPips / 2) * pipVal;
      if(type == OP_BUY) {
         suggestedSL = currentPrice - tightenBy;
      } else {
         suggestedSL = currentPrice + tightenBy;
      }
   }
   
   string stars = GetQualityStars(oppQuality);
   
   string msg = "<b>! REVERSAL WARNING</b>" + TGTag() + "\n\n";
   msg += "<code>" + sym + " " + direction + "</code> (Ticket #" + IntegerToString(ticket) + ")\n";
   msg += "<b>Entry:</b> " + DoubleToString(entry, digits) + "\n";
   msg += "<b>Current:</b> " + DoubleToString(currentPrice, digits) + "\n";
   msg += "<b>P/L:</b> " + profitStr + "\n\n";
   if(sl > 0 || tp > 0) {
      string slText = (sl > 0) ? DoubleToString(sl, digits) : "-";
      string tpText = (tp > 0) ? DoubleToString(tp, digits) : "-";
      msg += "SL/TP: " + slText + " / " + tpText + "\n\n";
   }
   
   msg += "<b>OPPOSITE SIGNAL DETECTED</b>\n";
   msg += "New " + oppDirection + " setup: " + stars + "\n\n";
   
   msg += "<b>ACTION OPTIONS:</b>\n";
   if(profitPips > 5) {
      msg += "1. Close now at " + DoubleToString(currentPrice, digits) + " (" + profitStr + ")\n";
      if(suggestedSL > 0) {
         msg += "2. Tighten SL to " + DoubleToString(suggestedSL, digits) + " (+" + DoubleToStrClean(profitPips/2, 0) + " pips locked)\n";
      }
   } else if(profitPips < -10) {
      msg += "1. <b>Close now</b> to prevent bigger loss\n";
      msg += "2. Wait for SL hit\n";
   } else {
      msg += "1. Close at breakeven: " + DoubleToString(entry, digits) + "\n";
      msg += "2. Wait for setup to play out\n";
   }
   msg += "\nAction: Pick the option that matches your risk tolerance.\n";
   msg += "Next: Recheck in 1h\n";
   
   MarkAlertBadge();
   SendTelegram(msg);
}

//+------------------------------------------------------------------+
//| PENDING ORDER HEALTH CHECK - Auto-cancel invalid pending orders |
//+------------------------------------------------------------------+
void CheckPendingOrderHealth() {
   int healthCheckSeconds = (int)MathMax(10, PendingHealthCheckSeconds);
   if(TimeCurrent() - lastPendingHealthCheck < healthCheckSeconds) return;
   lastPendingHealthCheck = TimeCurrent();

   int totalOrders = OrdersTotal();
   if(totalOrders == 0) return;

   bool newsNow = GetNewsNowCached();

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
      int curDir = GetTradeDirection(sym);
      datetime now = TimeCurrent();

      bool cancel = false;
      string reasons = "";

      if(AutoCancelPendingOnBiasFlip) {
         bool mismatch = false;
         if(curDir == 0) mismatch = AutoCancelPendingOnNeutralBias;
         else mismatch = (curDir != orderDir);

         string misKey = GetPendingBiasMismatchKey(sym, ticket);
         if(mismatch) {
            bool persisted = (PendingBiasFlipPersistMins <= 0);
            if(!persisted) {
               if(!GlobalVariableCheck(misKey)) {
                  GlobalVariableSet(misKey, (double)now);
               } else {
                  datetime since = (datetime)GlobalVariableGet(misKey);
                  persisted = ((now - since) >= PendingBiasFlipPersistMins * 60);
               }
            }

            if(persisted) {
               cancel = true;
               reasons += "- Bias no longer aligned\n";
            }
         } else {
            if(GlobalVariableCheck(misKey)) GlobalVariableDel(misKey);
         }
      }

      if(AutoCancelPendingOnNews && newsNow) {
         cancel = true;
         reasons += "- News filter active\n";
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

      bool cancelled = false;
      if(AutoTradingActive()) {
         cancelled = AutoCancelPending(ticket);
         if(cancelled) {
            string misKeyDone = GetPendingBiasMismatchKey(sym, ticket);
            if(GlobalVariableCheck(misKeyDone)) GlobalVariableDel(misKeyDone);
         }
      }

      string key = "pending-health:" + sym + ":" + IntegerToString(ticket);
      if(CanSendAlert(key, AlertCooldownMins)) {
         int digits = (int)MarketInfo(sym, MODE_DIGITS);
         string ordType = (type == OP_BUYLIMIT) ? "BUY LIMIT" : (type == OP_BUYSTOP) ? "BUY STOP" : (type == OP_SELLLIMIT) ? "SELL LIMIT" : "SELL STOP";

         string msg = "<b>PENDING AUTO-CHECK</b>" + TGTag() + "\n\n";
         msg += "<code>" + sym + " " + ordType + "</code> (#" + IntegerToString(ticket) + ")\n";
         msg += "Entry: " + DoubleToStrClean(entry, digits) + " | Current: " + DoubleToStrClean(currentPrice, digits) + "\n";
         if(distPips > 0) msg += "Distance: " + DoubleToStrClean(distPips, 0) + " pips\n";
         msg += "Reasons:\n" + reasons;
         if(cancelled) msg += "\nACTION: Pending cancelled.";
         else msg += "\nACTION: Pending NOT cancelled (auto trading OFF / cancel failed).";
         SendTelegram(msg);
      }
   }
}

//+------------------------------------------------------------------+
//| PENDING ORDER EXPIRATION - Alert on Stale Orders                 |
//+------------------------------------------------------------------+
void CheckPendingOrderExpiration() {
   if(TimeCurrent() - lastExpirationCheck < 1800) return;  // Check every 30 minutes
   lastExpirationCheck = TimeCurrent();
   
   int totalOrders = OrdersTotal();
   if(totalOrders == 0) return;
   
   for(int i = 0; i < totalOrders; i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      
      int ticket = OrderTicket();
      int type = OrderType();
      
      // Only check pending orders
      if(type != OP_BUYLIMIT && type != OP_SELLLIMIT && type != OP_BUYSTOP && type != OP_SELLSTOP) continue;
      
      datetime openTime = OrderOpenTime();
      int hoursOpen = (int)((TimeCurrent() - openTime) / 3600);
      
      // Alert if order older than threshold
      if(hoursOpen >= pendingOrderMaxHours) {
         string alertKey = "pending-stale:" + OrderSymbol() + ":" + IntegerToString(ticket);
         if(CanSendAlert(alertKey, AlertCooldownMins)) {
            if(AutoTradingActive() && AutoCancelStalePending) {
               AutoCancelPending(ticket);
            }
            SendExpirationAlert(ticket, hoursOpen);
         }
      }
   }
}

void SendExpirationAlert(int ticket, int hoursOpen) {
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;
   
   string sym = OrderSymbol();
   int type = OrderType();
   double entry = OrderOpenPrice();
   double sl = OrderStopLoss();
   double tp = OrderTakeProfit();
   double lots = OrderLots();
   int digits = (int)MarketInfo(sym, MODE_DIGITS);
   double minLot = MarketInfo(sym, MODE_MINLOT);
   
   string orderTypeStr = "";
   double currentPrice = 0;
   
   if(type == OP_BUYLIMIT) {
      orderTypeStr = "BUY LIMIT";
      currentPrice = MarketInfo(sym, MODE_ASK);
   } else if(type == OP_SELLLIMIT) {
      orderTypeStr = "SELL LIMIT";
      currentPrice = MarketInfo(sym, MODE_BID);
   } else if(type == OP_BUYSTOP) {
      orderTypeStr = "BUY STOP";
      currentPrice = MarketInfo(sym, MODE_ASK);
   } else if(type == OP_SELLSTOP) {
      orderTypeStr = "SELL STOP";
      currentPrice = MarketInfo(sym, MODE_BID);
   }
   
   double pipVal = PipValue(sym);
   double pipsAway = MathAbs(currentPrice - entry) / pipVal;
   
   string msg = "<b>PENDING ORDER STALE</b>" + TGTag() + "\n\n";
   msg += "<code>" + sym + " " + orderTypeStr + "</code>\n";
   msg += "Entry: " + DoubleToString(entry, digits) + "\n";
   msg += "Lot: " + DoubleToStrClean(lots, 2) + "\n";
   if(lots > 0 && lots < minLot) {
      msg += "NOTE: Lot below minimum (min " + DoubleToStrClean(minLot, 2) + ")\n";
      msg += "RULE: Skip if lot < minimum\n";
   }
   if(sl > 0) msg += "SL: " + DoubleToString(sl, digits) + "\n";
   if(tp > 0) msg += "TP: " + DoubleToString(tp, digits) + "\n";
   msg += "Placed: <b>" + IntegerToString(hoursOpen) + " hours ago</b>\n";
   msg += "Current price: " + DoubleToString(currentPrice, digits);
   msg += " (" + DoubleToStrClean(pipsAway, 0) + " pips away)\n\n";

   // R:R check using original SL/TP
   double rr = 0;
   if(sl > 0 && tp > 0) {
      double riskPips = MathAbs(entry - sl) / pipVal;
      double rewardPips = MathAbs(tp - entry) / pipVal;
      if(riskPips > 0) rr = rewardPips / riskPips;
      msg += "R:R: " + DoubleToStrClean(rr, 2) + (rr >= 1.0 ? " (OK)" : " (LOW)") + "\n\n";
   }
   
   msg += "<b>ACTION OPTIONS:</b>\n";
   msg += "1. Cancel - Setup likely invalidated\n";
   msg += "2. Adjust entry to " + DoubleToString(currentPrice, digits) + "\n\n";

   // Show price threshold for strict distance rule
   string priceRule = "";
   if(type == OP_BUYLIMIT || type == OP_BUYSTOP) {
      double minCurrent = entry - (PendingStaleMaxPips * pipVal);
      priceRule = "MIN CURRENT PRICE: " + DoubleToString(minCurrent, digits);
   } else if(type == OP_SELLLIMIT || type == OP_SELLSTOP) {
      double maxCurrent = entry + (PendingStaleMaxPips * pipVal);
      priceRule = "MAX CURRENT PRICE: " + DoubleToString(maxCurrent, digits);
   }

   msg += "<b>STRICT RULE:</b> Cancel if > " + IntegerToString(pendingOrderMaxHours) + " hours OR > " + DoubleToStrClean(PendingStaleMaxPips, 0) + " pips away\n";
   if(priceRule != "") msg += priceRule + "\n";
   msg += "ACTION: Cancel if stale per rule.\n";
   
   msg += "<i>Ticket #" + IntegerToString(ticket) + "</i>";
   
   MarkAlertBadge();
   SendTelegram(msg);
}

//+------------------------------------------------------------------+
//| WEEKLY SUMMARY                                                    |
//+------------------------------------------------------------------+
void CheckWeeklySummary() {
   int dayOfWeek = TimeDayOfWeek(TimeCurrent());
   int hour = TimeHour(TimeCurrent());
   
   // Wednesday mid-week mini-summary (NY close = 21:00 GMT)
   if(dayOfWeek == 3 && hour == NYEndHour) {
      datetime thisWed = iTime(Symbol(), PERIOD_D1, 0);
      if(lastMidWeekSummary < thisWed) {
         lastMidWeekSummary = thisWed;
         SendMidWeekSummary();
      }
   }
   
   // Send weekly summary on Friday at NY close (21:00 GMT)
   if(dayOfWeek == 5 && hour == NYEndHour) {
      datetime thisWeek = iTime(Symbol(), PERIOD_W1, 0);
      if(lastWeeklySummary < thisWeek) {
         lastWeeklySummary = thisWeek;
         SendWeeklySummary();
      }
   }
}

void SendWeeklySummary() {
   string msg = "<b>📊 WEEKLY SUMMARY</b>" + TGTag() + "\n";
   msg += "[WEEK] " + TimeToString(iTime(Symbol(), PERIOD_W1, 0), TIME_DATE) + "\n\n";
   
   // Account Performance
   msg += "<b>ACCOUNT PERFORMANCE:</b>\n";
   msg += "Week Start: $" + DoubleToStrClean(weekStartBalance, 2) + "\n";
   msg += "Current: $" + DoubleToStrClean(AccountEquity(), 2) + "\n";
   
   double weeklyPnL = AccountEquity() - weekStartBalance;
   double weeklyPct = (weekStartBalance > 0) ? (weeklyPnL / weekStartBalance) * 100 : 0;
   msg += "Weekly P/L: " + (weeklyPnL >= 0 ? "+" : "") + "$" + DoubleToStrClean(weeklyPnL, 2);
   msg += " (" + (weeklyPct >= 0 ? "+" : "") + DoubleToStrClean(weeklyPct, 1) + "%)\n\n";
   
   // Currency Performance
   msg += "<b>CURRENCY RANKINGS:</b>\n";
   
   // Sort currencies by strength
   double strengths[7];
   string sortedCur[7];
   ArrayInitialize(strengths, 0.0);
   for(int i = 0; i < 7; i++) {
      strengths[i] = WeightedCurrencyStrength(Currencies[i]);
      sortedCur[i] = Currencies[i];
   }
   
   // Simple bubble sort
   for(int i = 0; i < 6; i++) {
      for(int j = i + 1; j < 7; j++) {
         if(strengths[j] > strengths[i]) {
            double tempS = strengths[i];
            strengths[i] = strengths[j];
            strengths[j] = tempS;
            string tempC = sortedCur[i];
            sortedCur[i] = sortedCur[j];
            sortedCur[j] = tempC;
         }
      }
   }
   
   for(int i = 0; i < 7; i++) {
      string arrow = (strengths[i] > 0) ? "↑" : (strengths[i] < 0) ? "↓" : "→";
      msg += IntegerToString(i+1) + ". " + sortedCur[i] + " " + arrow + " (" + (strengths[i] >= 0 ? "+" : "") + DoubleToStrClean(strengths[i], 1) + ")\n";
   }
   
   msg += "\n<b>BEST PAIR THIS WEEK:</b>\n";
   msg += sortedCur[0] + sortedCur[6] + " (Strong vs Weak)\n\n";
   
   msg += "📅 See you next week! Good trading!";
   msg += "\nACTION: Review winners/losers and set next week focus.";
   
   SendTelegram(msg);
}

void SendMidWeekSummary() {
   string msg = "<b>📊 MID-WEEK CHECK-IN (Wednesday)</b>" + TGTag() + "\n";
   msg += "[" + TimeToString(TimeCurrent(), TIME_DATE) + "]\n\n";

   // Half-week P&L
   double weeklyPnL = AccountEquity() - weekStartBalance;
   double weeklyPct = (weekStartBalance > 0) ? (weeklyPnL / weekStartBalance) * 100 : 0;
   msg += "<b>Week so far:</b> " + (weeklyPnL >= 0 ? "+" : "") + "$" + DoubleToStrClean(weeklyPnL, 2);
   msg += " (" + (weeklyPct >= 0 ? "+" : "") + DoubleToStrClean(weeklyPct, 1) + "%)\n";

   // Current drawdown
   double dd = GetDailyDrawdown();
   msg += "<b>Today's DD:</b> " + DoubleToStrClean(dd, 1) + "% / " + DoubleToStrClean(MaxDrawdownPercent, 1) + "% (daily limit)\n";

   // Top and bottom currency this week
   double strengths[7];
   string sortedCur[7];
   ArrayInitialize(strengths, 0.0);
   for(int i = 0; i < 7; i++) {
      strengths[i] = WeightedCurrencyStrength(Currencies[i]);
      sortedCur[i] = Currencies[i];
   }
   for(int i = 0; i < 6; i++) {
      for(int j = i + 1; j < 7; j++) {
         if(strengths[j] > strengths[i]) {
            double tempS = strengths[i]; strengths[i] = strengths[j]; strengths[j] = tempS;
            string tempC = sortedCur[i]; sortedCur[i] = sortedCur[j]; sortedCur[j] = tempC;
         }
      }
   }
   msg += "\n<b>Strongest:</b> " + sortedCur[0] + " (" + DoubleToStrClean(strengths[0], 1) + ")";
   msg += "  <b>Weakest:</b> " + sortedCur[6] + " (" + DoubleToStrClean(strengths[6], 1) + ")\n";
   msg += "<b>Best setup:</b> " + sortedCur[0] + sortedCur[6] + " (Strong vs Weak)\n\n";

   msg += "📌 Stay disciplined. Two days left — protect gains!";
   msg += "\nACTION: Verify bias still holds. Adjust targets if needed.";
   SendTelegram(msg);
}

// Helper: pure time-window check without side effects
bool IsInNewsWindow(int startHourGMT, int startMinGMT, int windowMins) {
   datetime nowG = TimeGMT();
   string d = TimeToString(nowG, TIME_DATE);
   datetime start = StringToTime(d + " " + StringFormat("%02d:%02d", startHourGMT, startMinGMT));
   datetime end = start + windowMins * 60;
   return (nowG >= start && nowG <= end);
}

bool IsNewsTime() {
   // Honor both toggles
   if(!UseNewsFilter || !NewsFilterEnabled) { currentNewsEvent = ""; return false; }

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

   // Windows are "±30m around", implemented as 60m window starting 30m before release.
   // AUD 01:30 -> window 01:00-02:00
   if(IsInNewsWindow(1, 0, 60)) { newsBlockUntil = TimeCurrent() + 30*60; currentNewsEvent="AUD News (RBA/Employment)"; return true; }

   // EUR 07:00 -> 06:30-07:30 (adjust if you really mean 07:00)
   if(IsInNewsWindow(6, 30, 60)) { newsBlockUntil = TimeCurrent() + 30*60; currentNewsEvent="EUR News (ECB/German Data)"; return true; }

   // GBP 09:30 -> 09:00-10:00
   if(IsInNewsWindow(9, 0, 60)) { newsBlockUntil = TimeCurrent() + 30*60; currentNewsEvent="GBP News (BOE/UK Data)"; return true; }

   // USD 13:30 -> 13:00-14:00 (covers CPI/Claims style)
   if(IsInNewsWindow(13, 0, 60)) { newsBlockUntil = TimeCurrent() + 30*60; currentNewsEvent="USD News (CPI/Retail/Claims)"; return true; }

   // FOMC Wed ~19:00 -> 18:30-19:30
   if(dow == 3 && IsInNewsWindow(18, 30, 60)) { newsBlockUntil = TimeCurrent() + 60*60; currentNewsEvent="FOMC Decision (Check Calendar)"; return true; }

   // First Friday NFP 13:30 -> 13:00-14:00
   if(dow == 5 && dom <= 7 && IsInNewsWindow(13, 0, 60)) { newsBlockUntil = TimeCurrent() + 60*60; currentNewsEvent="NFP (Non-Farm Payrolls)"; return true; }

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
      if(AutoTightenSLOnNews) {
         for(int i = OrdersTotal() - 1; i >= 0; i--) {
            if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
            int type = OrderType();
            if(type != OP_BUY && type != OP_SELL) continue;
            string sym = OrderSymbol();
            double entry = OrderOpenPrice();
            double currentPrice = (type == OP_BUY) ? MarketInfo(sym, MODE_BID) : MarketInfo(sym, MODE_ASK);
            double pipVal = PipValue(sym);
            double profitPips = (type == OP_BUY) ? (currentPrice - entry) / pipVal : (entry - currentPrice) / pipVal;
            if(profitPips > 5) {
               double suggestedSL = (type == OP_BUY) ? (entry + (BreakEvenBufferPips * pipVal)) : (entry - (BreakEvenBufferPips * pipVal));
               AutoModifySL(OrderTicket(), suggestedSL);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| TRADE JOURNAL EXPORT                                              |
//+------------------------------------------------------------------+
void ExportTradeJournal() {
   // Analyze closed trades
   int totalHistory = OrdersHistoryTotal();
   datetime periodStart = iTime(Symbol(), PERIOD_W1, 0); // This week
   
   int totalTrades = 0;
   int wins = 0;
   int losses = 0;
   double totalPips = 0;
   double winPips = 0;
   double lossPips = 0;
   double totalProfit = 0;
   double winProfit = 0;
   double lossProfit = 0;
   
   // Track best and worst trades
   double bestPips = -999999;
   double worstPips = 999999;
   string bestTrade = "";
   string worstTrade = "";
   
   // Track by pair
   int pairTrades[64];
   double pairPips[64];
   ArrayInitialize(pairTrades, 0);
   ArrayInitialize(pairPips, 0.0);
   
   // Analyze history
   for(int i = 0; i < totalHistory; i++) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderCloseTime() < periodStart) continue;
      
      int type = OrderType();
      if(type > OP_SELL) continue; // Skip pending orders
      
      totalTrades++;
      string sym = OrderSymbol();
      double pipVal = PipValue(sym);
      double pips = 0;
      
      if(type == OP_BUY) {
         pips = (OrderClosePrice() - OrderOpenPrice()) / pipVal;
      } else {
         pips = (OrderOpenPrice() - OrderClosePrice()) / pipVal;
      }
      
      totalPips += pips;
      totalProfit += OrderProfit();
      
      // Win/Loss count
      if(pips > 0) {
         wins++;
         winPips += pips;
         winProfit += OrderProfit();
      } else {
         losses++;
         lossPips += MathAbs(pips);
         lossProfit += MathAbs(OrderProfit());
      }
      
      // Track best/worst
      if(pips > bestPips) {
         bestPips = pips;
         string typeStr = (type == OP_BUY) ? "BUY" : "SELL";
         bestTrade = sym + " " + typeStr + " +" + DoubleToStrClean(pips, 0) + "p ($" + DoubleToStrClean(OrderProfit(), 2) + ")";
      }
      
      if(pips < worstPips) {
         worstPips = pips;
         string typeStr2 = (type == OP_BUY) ? "BUY" : "SELL";
         worstTrade = sym + " " + typeStr2 + " " + DoubleToStrClean(pips, 0) + "p ($" + DoubleToStrClean(OrderProfit(), 2) + ")";
      }
      
      // Track by pair
      for(int p = 0; p < PairsCount; p++) {
         if(sym == Pairs[p]) {
            pairTrades[p]++;
            pairPips[p] += pips;
            break;
         }
      }
   }
   
   // Calculate stats
   double winRate = (totalTrades > 0) ? (wins * 100.0 / totalTrades) : 0;
   double avgWin = (wins > 0) ? winPips / wins : 0;
   double avgLoss = (losses > 0) ? lossPips / losses : 0;
   double expectancy = (totalTrades > 0) ? totalPips / totalTrades : 0;
   double expectancyMoney = (totalTrades > 0) ? (totalProfit / totalTrades) : 0;
   double avgWinMoney = (wins > 0) ? (winProfit / wins) : 0;
   double avgLossMoney = (losses > 0) ? (lossProfit / losses) : 0;
   
   // Find best/worst pairs
   string bestPair = "";
   string worstPair = "";
   double bestPairPips = -999999;
   double worstPairPips = 999999;
   int worstPairTrades = 0;
   
   for(int p = 0; p < PairsCount; p++) {
      if(pairTrades[p] > 0) {
         if(pairPips[p] > bestPairPips) {
            bestPairPips = pairPips[p];
            bestPair = Pairs[p] + " (" + IntegerToString(pairTrades[p]) + " trades, +" + DoubleToStrClean(pairPips[p], 0) + "p)";
         }
         if(pairPips[p] < worstPairPips) {
            worstPairPips = pairPips[p];
            worstPairTrades = pairTrades[p];
            worstPair = Pairs[p] + " (" + IntegerToString(pairTrades[p]) + " trades, " + DoubleToStrClean(pairPips[p], 0) + "p)";
         }
      }
   }
   
   // Build comprehensive report
   string msg = "<b>=== SWINGMASTER PRO JOURNAL ===</b>\n\n";
   
   msg += "<b>PERIOD:</b> " + TimeToString(periodStart, TIME_DATE) + " - " + TimeToString(TimeCurrent(), TIME_DATE) + "\n";
   msg += "<b>Account:</b> $" + DoubleToStrClean(AccountBalance(), 2) + "\n\n";
   
   // Overall stats
   msg += "<b>OVERALL STATS:</b>\n";
   msg += "Total trades: <b>" + IntegerToString(totalTrades) + "</b>\n";
   msg += "Wins: " + IntegerToString(wins) + " | Losses: " + IntegerToString(losses) + "\n";
   msg += "Win rate: <b>" + DoubleToStrClean(winRate, 1) + "%</b>\n\n";
   
   // Pips & Profit
   string pipsSign = (totalPips >= 0 ? "+" : "");
   string profitSign = (totalProfit >= 0 ? "+" : "");
   color pipsColor = (totalPips >= 0 ? clrLime : clrRed);
   
   msg += "<b>PERFORMANCE:</b>\n";
   msg += "Total pips: <b>" + pipsSign + DoubleToStrClean(totalPips, 0) + "</b>\n";
   msg += "Total profit: <b>" + profitSign + "$" + DoubleToStrClean(totalProfit, 2) + "</b>\n";
   msg += "Expectancy: " + DoubleToStrClean(expectancy, 1) + " pips/trade";
   msg += " | $" + DoubleToStrClean(expectancyMoney, 2) + "/trade\n\n";
   
   // Risk SNAPSHOT
   msg += "<b>RISK SNAPSHOT:</b>\n";
   msg += "Current Risk: " + DoubleToStrClean(currentRiskPercent, 1) + "% / " + DoubleToStrClean(MaxDailyRiskPercent, 1) + "%\n";
   msg += "Daily Drawdown: " + DoubleToStrClean(GetDailyDrawdown(), 1) + "% (Max " + DoubleToStrClean(MaxDrawdownPercent, 1) + "%)\n";
   msg += "Status: " + (IsDrawdownOK() ? "SAFE" : "EXCEEDED") + "\n\n";
   
   // Win/Loss analysis
   msg += "<b>WIN/LOSS BREAKDOWN:</b>\n";
   msg += "Avg win: +" + DoubleToStrClean(avgWin, 0) + "p\n";
   msg += "Avg loss: -" + DoubleToStrClean(avgLoss, 0) + "p\n";
   if(wins > 0) msg += "Avg win $: +" + DoubleToStrClean(avgWinMoney, 2) + "\n";
   if(losses > 0) msg += "Avg loss $: -" + DoubleToStrClean(avgLossMoney, 2) + "\n";
   if(avgLoss > 0) {
      double profitFactor = avgWin / avgLoss;
      msg += "Profit factor: " + DoubleToStrClean(profitFactor, 2) + "\n";
      msg += "Avg R:R: " + DoubleToStrClean(profitFactor, 2) + "\n";
   }
   msg += "\n";
   
   // Best/Worst trades
   if(totalTrades > 0) {
      msg += "<b>BEST TRADE:</b>\n";
      msg += bestTrade + "\n\n";
      
      msg += "<b>WORST TRADE:</b>\n";
      msg += worstTrade + "\n\n";
   }
   
   // Pair performance
   if(bestPair != "") {
      msg += "<b>BEST PAIR:</b>\n" + bestPair + "\n\n";
   }
   if(worstPair != "" && worstPairPips < 0) {
      msg += "<b>WORST PAIR:</b>\n" + worstPair + "\n\n";
   }
   
   // Recommendations
   msg += "<b>ANALYSIS:</b>\n";
   
   if(totalTrades == 0) {
      msg += "! No trades yet this period\n";
   } else if(winRate >= 60) {
      msg += "Excellent performance! Keep it up!\n";
   } else if(winRate >= 50) {
      msg += "Good performance. Stay disciplined.\n";
   } else if(winRate >= 40) {
      msg += "Below target. Review losing trades.\n";
   } else {
      msg += "! Need improvement. Check strategy adherence.\n";
   }
   
   if(totalTrades > 0 && avgLoss > avgWin * 1.5) {
      msg += "! Warning: Avg loss > avg win. Tighten SL?\n";
   }
   if(totalTrades > 0 && avgLoss > 0) {
      double pfCheck = avgWin / avgLoss;
      if(pfCheck < 1.0) msg += "! Warning: Profit factor < 1.0 (needs improvement)\n";
   }
   
   if(worstPairPips < -50 && worstPairTrades >= 3) {
      msg += "! Consider avoiding worst pair\n";
   }
   
   msg += "\n--- Share this with your coach ---";
   
   // Build compact journal (optional)
   string shortMsg = "<b>=== SWINGMASTER PRO JOURNAL (COMPACT) ===</b>\n\n";
   shortMsg += "<b>PERIOD:</b> " + TimeToString(periodStart, TIME_DATE) + " - " + TimeToString(TimeCurrent(), TIME_DATE) + "\n";
   shortMsg += "<b>Account:</b> $" + DoubleToStrClean(AccountBalance(), 2) + "\n\n";
   shortMsg += "<b>OVERALL:</b> Trades " + IntegerToString(totalTrades) + " | Win% " + DoubleToStrClean(winRate, 1) + "%\n";
   shortMsg += "<b>PERF:</b> " + pipsSign + DoubleToStrClean(totalPips, 0) + "p | " + profitSign + "$" + DoubleToStrClean(totalProfit, 2) + "\n";
   shortMsg += "Expect: " + DoubleToStrClean(expectancy, 1) + "p/" + "$" + DoubleToStrClean(expectancyMoney, 2) + "\n\n";
   shortMsg += "<b>RISK:</b> " + DoubleToStrClean(currentRiskPercent, 1) + "%/" + DoubleToStrClean(MaxDailyRiskPercent, 1) + "% | DD " + DoubleToStrClean(GetDailyDrawdown(), 1) + "%\n\n";
   shortMsg += "<b>W/L:</b> AvgWin +" + DoubleToStrClean(avgWin, 0) + "p | AvgLoss -" + DoubleToStrClean(avgLoss, 0) + "p\n";
   if(avgLoss > 0) {
      double profitFactorShort = avgWin / avgLoss;
      shortMsg += "PF: " + DoubleToStrClean(profitFactorShort, 2) + " | Avg R:R " + DoubleToStrClean(profitFactorShort, 2) + "\n";
   }
   if(bestTrade != "") shortMsg += "Best: " + bestTrade + "\n";
   if(worstTrade != "") shortMsg += "Worst: " + worstTrade + "\n";
   if(totalTrades == 0) shortMsg += "! No trades yet\n";
   else if(winRate >= 60) shortMsg += "Good performance\n";
   else if(winRate >= 50) shortMsg += "Stable performance\n";
   else shortMsg += "Needs improvement\n";
   shortMsg += "Action: Review stats and adjust rules if needed\n";
   shortMsg += "\n--- Share this with your coach ---";

   bool sendDetailed = JournalSendDetailed;
   bool sendCompact = JournalSendCompact;
   if(!sendDetailed && !sendCompact) {
      Log("Journal send settings disabled; defaulting to detailed.");
      sendDetailed = true;
   }

   if(sendDetailed) SendTelegram(msg);
   if(sendCompact) SendTelegram(shortMsg);
   
   Log("Trade journal sent to Telegram");
}

//+------------------------------------------------------------------+
//| DAILY SUMMARY                                                     |
//+------------------------------------------------------------------+
void SendDailySummary() {
   string msg = "<b>DAILY SUMMARY</b>" + TGTag() + "\n";
   msg += "[DATE] " + TimeToString(TimeCurrent(), TIME_DATE) + "\n\n";
   
   // Account Performance
   msg += "<b>ACCOUNT PERFORMANCE:</b>\n";
   msg += "Starting Balance: $" + DoubleToStrClean(dayStartBalance, 2) + "\n";
   msg += "Current Equity: $" + DoubleToStrClean(AccountEquity(), 2) + "\n";
   
   double dailyPnL = AccountEquity() - dayStartBalance;
   double dailyPct = (dayStartBalance > 0) ? (dailyPnL / dayStartBalance) * 100 : 0;
   msg += "Daily P/L: " + (dailyPnL >= 0 ? "+" : "") + "$" + DoubleToStrClean(dailyPnL, 2);
   msg += " (" + (dailyPct >= 0 ? "+" : "") + DoubleToStrClean(dailyPct, 1) + "%)\n\n";
   
   // Drawdown
   msg += "<b>DRAWDOWN STATUS:</b>\n";
   msg += "Max Drawdown Today: " + DoubleToStrClean(GetDailyDrawdown(), 1) + "%\n";
   msg += "Max Allowed: " + DoubleToStrClean(MaxDrawdownPercent, 1) + "%\n";
   msg += "Status: " + (IsDrawdownOK() ? "SAFE" : "EXCEEDED") + "\n\n";
   
   // Strongest/Weakest
   string strongest = "";
   string weakest = "";
   double maxStr = -999, minStr = 999;
   
   for(int i = 0; i < 7; i++) {
      double str = WeightedCurrencyStrength(Currencies[i]);
      if(str > maxStr) { maxStr = str; strongest = Currencies[i]; }
      if(str < minStr) { minStr = str; weakest = Currencies[i]; }
   }
   
   msg += "Strongest: " + strongest + " (+" + DoubleToStrClean(maxStr, 1) + ")\n";
   msg += "Weakest: " + weakest + " (" + DoubleToStrClean(minStr, 1) + ")\n";
   msg += "\nACTION: Review daily performance and adjust plan.";
   
   SendTelegram(msg);
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
      int quality = GetPullbackQuality(sym);
      if(quality < 2) continue;
      
      int dir = GetTradeDirection(sym);
      if(dir == 1) { buyCount++; buyPairs += sym + " " + GetQualityStars(quality) + ", "; }
      if(dir == -1) { sellCount++; sellPairs += sym + " " + GetQualityStars(quality) + ", "; }
   }
   
   msg += "Active Signals:\n";
   msg += "BUY: " + (buyCount > 0 ? buyPairs : "None") + "\n";
   msg += "SELL: " + (sellCount > 0 ? sellPairs : "None") + "\n";
   if(GetNewsNowCached()) msg += "\n⚠️ NEWS FILTER ACTIVE - No new trades\n";
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
   int width = 460, height = 520;
   
   // Background
   ObjectCreate(0, "PanelBG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "PanelBG", OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, "PanelBG", OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, "PanelBG", OBJPROP_XSIZE, width);
   ObjectSetInteger(0, "PanelBG", OBJPROP_YSIZE, height);
   ObjectSetInteger(0, "PanelBG", OBJPROP_BGCOLOR, PanelColor);
   ObjectSetInteger(0, "PanelBG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   
   // Title
   CreateLabel("PanelTitle", "SwingMaster Pro v1.0", x + 10, y + 10, TextColor, 10);
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

   // Mode
   string modeText = "Mode: MANUAL";
   color modeColor = clrYellow;
   if(AutoTradingEnabled()) {
      modeText = AutoTradingActive() ? "Mode: AUTO" : "Mode: AUTO (OFF)";
      modeColor = AutoTradingActive() ? clrLime : clrOrange;
   }
   modeText += " | Signal: " + GetSignalModeLabel();
   CreateLabel("LblMode", modeText, x, y, modeColor, 9, "Arial Black");
   y += lineHeight;

   // Auto-off reason (when enabled but not active)
   if(AutoTradingEnabled() && !AutoTradingActive()) {
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
   if(todayWins > 0 || todayLosses > 0) {
      todayStats += " | " + IntegerToString(todayWins) + "W-" + IntegerToString(todayLosses) + "L";
   }
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
   // DD Recovery mode indicator
   if(UseDrawdownRecoveryMode && g_inDDRecovery) {
      double recPct = (g_ddPeakBalance > 0) ? ((AccountBalance() / g_ddPeakBalance) * 100.0) : 0;
      string ddRecStr = "!! DD RECOVERY: " + DoubleToStrClean(DDRecoveryLotMultiplier * 100, 0) + "% lots (" + DoubleToStrClean(recPct, 1) + "% of peak)";
      CreateLabel("LblDDRecovery", ddRecStr, x, y, clrOrange, 9, "Arial Black");
      y += lineHeight;
   } else {
      ObjectDelete(0, "LblDDRecovery");
   }
   y += 5;
   
   // ─────────────────────────────────────────────────────────────────
   // ACTIVE ORDERS — individual per-order rows
   // ─────────────────────────────────────────────────────────────────
   int totalOrders = OrdersTotal();
   int marketCount = 0, pendingCount = 0;
   double totalPips = 0.0;
   int ordRow = 0;
   int maxOrdRows = 12;

   // First pass: count market vs pending
   for(int oi = 0; oi < totalOrders; oi++) {
      if(!OrderSelect(oi, SELECT_BY_POS, MODE_TRADES)) continue;
      int ctype = OrderType();
      if(ctype == OP_BUY || ctype == OP_SELL) marketCount++;
      else pendingCount++;
   }

   if(totalOrders > 0) {
      // Section header
      string hdrStr = "-- ORDERS: " + IntegerToString(marketCount) + " open";
      if(pendingCount > 0) hdrStr += " | " + IntegerToString(pendingCount) + " pending";
      hdrStr += " --";
      CreateLabel("LblTrades", hdrStr, x, y, clrAqua, 8);
      y += lineHeight;

      // Second pass: per-order detail rows
      for(int od = 0; od < totalOrders && ordRow < maxOrdRows; od++) {
         if(!OrderSelect(od, SELECT_BY_POS, MODE_TRADES)) continue;

         string osym    = OrderSymbol();
         int    otype   = OrderType();
         double olots   = OrderLots();
         double oentry  = OrderOpenPrice();
         double osl     = OrderStopLoss();
         double otp     = OrderTakeProfit();
         bool   oHedge  = (OrderMagicNumber() == MagicNumber + 999);
         int    odigits = (int)MarketInfo(osym, MODE_DIGITS);
         double oPipV   = PipValue(osym);

         // Direction / type tag
         string otag;
         if(otype == OP_BUY)            otag = "BUY";
         else if(otype == OP_SELL)       otag = "SELL";
         else if(otype == OP_BUYLIMIT)   otag = "BUY LMT";
         else if(otype == OP_SELLLIMIT)  otag = "SEL LMT";
         else if(otype == OP_BUYSTOP)    otag = "BUY STP";
         else if(otype == OP_SELLSTOP)   otag = "SEL STP";
         else                             otag = "???";
         if(oHedge) otag = "HEDGE";

         // P/L pips for market orders
         string opipsStr = "";
         color  orowClr  = clrGray;
         if(otype == OP_BUY || otype == OP_SELL) {
            double ocurPr = (otype == OP_BUY) ? MarketInfo(osym, MODE_BID) : MarketInfo(osym, MODE_ASK);
            double opips  = 0.0;
            if(oPipV > 0) opips = (otype == OP_BUY) ? (ocurPr - oentry) / oPipV : (oentry - ocurPr) / oPipV;
            totalPips += opips;
            string psign = (opips >= 0) ? "+" : "";
            opipsStr = "  " + psign + DoubleToStrClean(opips, 1) + "p";
            if(oHedge)            orowClr = clrOrange;
            else if(otype == OP_BUY)  orowClr = clrLime;
            else                   orowClr = clrRed;
         }

         // Single row: [tag] SYMBOL  lots  pips  |  E:X  SL:X  TP:X
         string oslStr = (osl > 0) ? DoubleToStr(osl, odigits) : "---";
         string otpStr = (otp > 0) ? DoubleToStr(otp, odigits) : "---";
         string ol1 = "[" + otag + "] " + osym + "  " + DoubleToStrClean(olots, 2) + "L" + opipsStr +
                      "   E:" + DoubleToStr(oentry, odigits) + " SL:" + oslStr + " TP:" + otpStr;
         CreateLabel("LblOrd" + IntegerToString(ordRow) + "A", ol1, x + 4, y, orowClr, 8);
         ObjectDelete(0, "LblOrd" + IntegerToString(ordRow) + "B");
         y += lineHeight + 1;

         ordRow++;
      }

      // Clean up stale order-row labels from previous tick
      for(int ok = ordRow; ok < maxOrdRows; ok++) {
         ObjectDelete(0, "LblOrd" + IntegerToString(ok) + "A");
         ObjectDelete(0, "LblOrd" + IntegerToString(ok) + "B");
      }

      // Total pips summary
      if(marketCount > 0) {
         string tsign = (totalPips >= 0) ? "+" : "";
         color  tclr  = (totalPips >= 0) ? clrLime : clrRed;
         CreateLabel("LblPips", "Total P/L: " + tsign + DoubleToStrClean(totalPips, 1) + " pips", x, y, tclr, 9);
         y += lineHeight;
      } else {
         ObjectDelete(0, "LblPips");
      }
   } else {
      // No open orders — clean up all order labels
      ObjectDelete(0, "LblTrades");
      ObjectDelete(0, "LblPips");
      for(int ok = 0; ok < maxOrdRows; ok++) {
         ObjectDelete(0, "LblOrd" + IntegerToString(ok) + "A");
         ObjectDelete(0, "LblOrd" + IntegerToString(ok) + "B");
      }
   }
   y += 5;

   // ─────────────────────────────────────────────────────────────────
   // LOCK HEDGE STATUS SECTION
   // ─────────────────────────────────────────────────────────────────
   if(IsLockHedgeActive) {
      // Count lock-hedge orders and sum their floating P/L
      int    lockOrdCount  = 0;
      double lockHedgePips = 0.0;
      for(int hi = 0; hi < OrdersTotal(); hi++) {
         if(!OrderSelect(hi, SELECT_BY_POS, MODE_TRADES)) continue;
         if(OrderMagicNumber() != MagicNumber + 999) continue;
         lockOrdCount++;
         string   hsym   = OrderSymbol();
         int      htype  = OrderType();
         double   hentry = OrderOpenPrice();
         double   hpipV  = PipValue(hsym);
         if(hpipV > 0) {
            double hcur = (htype == OP_BUY) ? MarketInfo(hsym, MODE_BID) : MarketInfo(hsym, MODE_ASK);
            lockHedgePips += (htype == OP_BUY) ? (hcur - hentry) / hpipV : (hentry - hcur) / hpipV;
         }
      }

      // Header
      CreateLabel("LblLockHdr", "[!] HEDGE LOCK ACTIVE", x, y, clrOrange, 9, "Arial Black");
      y += lineHeight;

      // Reason + Duration + DD on one row (wide panel)
      int heldSecs = (int)(TimeCurrent() - LockHedgeActivatedTime);
      int heldMins = heldSecs / 60;
      string heldStr = (heldMins < 60)
         ? IntegerToString(heldMins) + "m"
         : IntegerToString(heldMins / 60) + "h " + IntegerToString(heldMins % 60) + "m";
      string ddAtStr = "$" + DoubleToStrClean(LockHedgeDrawdownAtLock, 2);
      CreateLabel("LblLockInfo", "  " + LockHedgeReason + "  |  Held: " + heldStr + "  |  DD: " + ddAtStr, x, y, clrYellow, 8);
      ObjectDelete(0, "LblLockReason");
      y += lineHeight;

      // Hedge floating P/L
      if(lockOrdCount > 0) {
         string hpSign = (lockHedgePips >= 0) ? "+" : "";
         color  hpClr  = (lockHedgePips >= 0) ? clrLime : clrRed;
         CreateLabel("LblLockPips",
            "  Hedge P/L: " + hpSign + DoubleToStrClean(lockHedgePips, 1) + "p  (" + IntegerToString(lockOrdCount) + " orders)",
            x, y, hpClr, 8);
         y += lineHeight;
      } else {
         ObjectDelete(0, "LblLockPips");
      }
      y += 5;
   } else {
      ObjectDelete(0, "LblLockHdr");
      ObjectDelete(0, "LblLockReason");
      ObjectDelete(0, "LblLockInfo");
      ObjectDelete(0, "LblLockPips");
   }

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
   
   // News Filter Status (use cached)
   if(GetNewsNowCached()) {
      CreateLabel("LblNews", "NEWS: " + currentNewsEvent, x, y, clrRed, 9, "Arial Black");
      y += lineHeight;
      CreateLabel("LblNewsWarn", "! NO NEW TRADES", x, y, clrYellow, 9);
      y += lineHeight + 5;
   } else {
      ObjectDelete(0, "LblNewsWarn");
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
   
   // Currency bias (compact grid to save space)
   CreateLabel("LblBiasTitle", "Currency Bias:", x, y, clrYellow, 9);
   y += lineHeight;

   int colWidth = 108;
   int rowHeight = 14;
   for(int i = 0; i < 7; i++) {
      string cur = Currencies[i];
      string bias = GetBiasLabel(cur);
      string shortBias = (bias == "STRONG") ? "STR" : (bias == "WEAK") ? "WEAK" : "NEU";
      color biasColor = (bias == "STRONG") ? clrLime : (bias == "WEAK") ? clrRed : clrGray;

      int col = i % 4;
      int row = i / 4;
      int bx = x + (col * colWidth);
      int by = y + (row * rowHeight);
      CreateLabel("LblBias" + cur, cur + ":" + shortBias, bx, by, biasColor, 8);
   }
   y += (rowHeight * 2) + 2;

   // Nearest S/R level for the current chart symbol
   string chartSym = Symbol();
   double chartPip = PipValue(chartSym);
   double chartMid = (MarketInfo(chartSym, MODE_ASK) + MarketInfo(chartSym, MODE_BID)) * 0.5;
   double nearestSRDist = 999999.0;
   double nearestSRLevel = 0.0;
   int chartDigits = (int)MarketInfo(chartSym, MODE_DIGITS);
   if(chartPip > 0) {
      for(int si = 0; si < SRCount; si++) {
         if(SRLevels[si].symbol != chartSym) continue;
         if(!SRLevels[si].isActive) continue;
         double d = MathAbs(chartMid - SRLevels[si].level);
         if(d < nearestSRDist) {
            nearestSRDist = d;
            nearestSRLevel = SRLevels[si].level;
         }
      }
   }
   if(nearestSRLevel > 0.0 && chartPip > 0.0) {
      double nearPips = nearestSRDist / chartPip;
      string srTag = (chartMid < nearestSRLevel) ? "R" : "S";
      color srColor = (chartMid < nearestSRLevel) ? clrRed : clrLime;
      string srStr = chartSym + " Nearest " + srTag + ": " + DoubleToStrClean(nearestSRLevel, chartDigits) + " (" + DoubleToStrClean(nearPips, 0) + "p away)";
      CreateLabel("LblNearestSR", srStr, x, y, srColor, 9);
      y += lineHeight;
   } else {
      ObjectDelete(0, "LblNearestSR");
   }

   // ── Dynamically resize panel background to fit all content ──────
   int panelContentH = (y - 30) + 35;
   if(panelContentH < 420) panelContentH = 420;
   ObjectSetInteger(0, "PanelBG", OBJPROP_XSIZE, 460);
   ObjectSetInteger(0, "PanelBG", OBJPROP_YSIZE, panelContentH);

   // ── Reposition buttons just below panel ───────────────────────
   int by0 = 30 + panelContentH + 5;
   int bw2 = 148, bh2 = 26, bgap = 6;
   // Row 1: Lock | Unlock | Scan
   ObjectSetInteger(0, "btnLock",    OBJPROP_CORNER, 0); ObjectSetInteger(0, "btnLock",    OBJPROP_XDISTANCE, 10);               ObjectSetInteger(0, "btnLock",    OBJPROP_YDISTANCE, by0);      ObjectSetInteger(0, "btnLock",    OBJPROP_XSIZE, bw2); ObjectSetInteger(0, "btnLock",    OBJPROP_YSIZE, bh2);
   ObjectSetInteger(0, "btnUnlock",  OBJPROP_CORNER, 0); ObjectSetInteger(0, "btnUnlock",  OBJPROP_XDISTANCE, 10+bw2+bgap);    ObjectSetInteger(0, "btnUnlock",  OBJPROP_YDISTANCE, by0);      ObjectSetInteger(0, "btnUnlock",  OBJPROP_XSIZE, bw2); ObjectSetInteger(0, "btnUnlock",  OBJPROP_YSIZE, bh2);
   ObjectSetInteger(0, "btnScan",    OBJPROP_CORNER, 0); ObjectSetInteger(0, "btnScan",    OBJPROP_XDISTANCE, 10+bw2*2+bgap*2); ObjectSetInteger(0, "btnScan",    OBJPROP_YDISTANCE, by0);      ObjectSetInteger(0, "btnScan",    OBJPROP_XSIZE, bw2); ObjectSetInteger(0, "btnScan",    OBJPROP_YSIZE, bh2);
   // Row 2: Alerts | Journal | Test
   ObjectSetInteger(0, "btnAlerts",  OBJPROP_CORNER, 0); ObjectSetInteger(0, "btnAlerts",  OBJPROP_XDISTANCE, 10);               ObjectSetInteger(0, "btnAlerts",  OBJPROP_YDISTANCE, by0+bh2+bgap); ObjectSetInteger(0, "btnAlerts",  OBJPROP_XSIZE, bw2); ObjectSetInteger(0, "btnAlerts",  OBJPROP_YSIZE, bh2);
   ObjectSetInteger(0, "btnJournal", OBJPROP_CORNER, 0); ObjectSetInteger(0, "btnJournal", OBJPROP_XDISTANCE, 10+bw2+bgap);    ObjectSetInteger(0, "btnJournal", OBJPROP_YDISTANCE, by0+bh2+bgap); ObjectSetInteger(0, "btnJournal", OBJPROP_XSIZE, bw2); ObjectSetInteger(0, "btnJournal", OBJPROP_YSIZE, bh2);
   ObjectSetInteger(0, "btnTest",    OBJPROP_CORNER, 0); ObjectSetInteger(0, "btnTest",    OBJPROP_XDISTANCE, 10+bw2*2+bgap*2); ObjectSetInteger(0, "btnTest",    OBJPROP_YDISTANCE, by0+bh2+bgap); ObjectSetInteger(0, "btnTest",    OBJPROP_XSIZE, bw2); ObjectSetInteger(0, "btnTest",    OBJPROP_YSIZE, bh2);
}

void CreateTestButton() {
   // Buttons are created once here; positions are set every tick in UpdateChartPanel.
   int bw = 148, bh = 26;

   if(ObjectFind(0, "btnLock") == -1) {
      ObjectCreate(0, "btnLock", OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, "btnLock", OBJPROP_XSIZE, bw); ObjectSetInteger(0, "btnLock", OBJPROP_YSIZE, bh);
      ObjectSetString(0, "btnLock",  OBJPROP_TEXT, "[ LOCK ]");
      ObjectSetInteger(0, "btnLock", OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, "btnLock", OBJPROP_BGCOLOR, clrFireBrick);
   }
   if(ObjectFind(0, "btnUnlock") == -1) {
      ObjectCreate(0, "btnUnlock", OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, "btnUnlock", OBJPROP_XSIZE, bw); ObjectSetInteger(0, "btnUnlock", OBJPROP_YSIZE, bh);
      ObjectSetString(0, "btnUnlock",  OBJPROP_TEXT, "[ UNLOCK ]");
      ObjectSetInteger(0, "btnUnlock", OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, "btnUnlock", OBJPROP_BGCOLOR, clrSeaGreen);
   }
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
   if(ObjectFind(0, "btnJournal") == -1) {
      ObjectCreate(0, "btnJournal", OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, "btnJournal", OBJPROP_XSIZE, bw); ObjectSetInteger(0, "btnJournal", OBJPROP_YSIZE, bh);
      ObjectSetString(0, "btnJournal",  OBJPROP_TEXT, "[ JOURNAL ]");
      ObjectSetInteger(0, "btnJournal", OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, "btnJournal", OBJPROP_BGCOLOR, clrDarkOrange);
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
//| INITIALIZATION                                                    |
//+------------------------------------------------------------------+
int OnInit() {
   Log("SwingMaster Pro v1.0 initializing...");
   
   // Load Telegram credentials from external file
   if(!LoadTelegramConfig()) {
      Log("WARNING: Telegram not configured yet. Edit " + TG_CONFIG_FILE + " in MQL4/Files/ then reattach EA.");
      // No hardcoded fallback
   }
   
   // Build pairs
   BuildPairsUniverse();
   ArrayInitialize(g_spreadHighLogAt, 0);
   ArrayInitialize(g_spreadWideLogAt, 0);
   ArrayInitialize(g_volCacheBarTime, 0);
   ArrayInitialize(g_pairDirCache, 0);

   // Apply signal mode presets
   ApplySignalMode();
   
   // Initialize S/R levels for all pairs
   InitializeSRLevels();
   
   // Initialize balance tracking
   dayStartBalance = AccountBalance();
   weekStartBalance = AccountBalance();
   monthStartBalance = AccountBalance();
   // Drawdown recovery: seed peak balance on init (persist across EA restart)
   {
      string ddPeakKey = "SMP_DDPEAK_" + IntegerToString(AccountNumber());
      string ddRecKey  = "SMP_DDREC_"  + IntegerToString(AccountNumber());
      if(UseDrawdownRecoveryMode) {
         if(GlobalVariableCheck(ddPeakKey)) {
            double savedPeak = GlobalVariableGet(ddPeakKey);
            if(savedPeak > AccountBalance()) g_ddPeakBalance = savedPeak;
         }
         if(GlobalVariableCheck(ddRecKey)) g_inDDRecovery = (GlobalVariableGet(ddRecKey) > 0.5);
      }
      if(g_ddPeakBalance <= 0) g_ddPeakBalance = AccountBalance();
   }

   // Recover lock state on EA reattach/restart if lock hedge orders already exist
   if(HasOpenLockHedgeOrders()) {
      IsLockHedgeActive = true;
      LockHedgeActivatedTime = TimeCurrent();
      LastLockStateChangeTime = TimeCurrent();
      LockHedgeReason = "Recovered on init";
      LockHedgeDrawdownAtLock = AccountBalance() - AccountEquity();
      Log("Lock state recovered from existing hedge orders.");
   }
   
   // Create UI
   CreateChartPanel();
   CreateTestButton();
   UpdateChartPanel();
   
   Log("Initialization complete. Pairs: " + IntegerToString(PairsCount) + ", S/R Levels: " + IntegerToString(SRCount));
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| DEINITIALIZATION                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   // Clean up objects (match actual names/prefixes used by CreateLabel/CreateChartPanel)
   DeleteObjectsByPrefix("Panel");  // PanelBG, PanelTitle, etc.
   DeleteObjectsByPrefix("Lbl");    // LblBalance, LblToday, etc.
   DeleteObjectsByPrefix("SMP_SIG_");
   ObjectDelete(0, "AlertBadge");
   ObjectDelete(0, "btnTest");
   ObjectDelete(0, "btnScan");
   ObjectDelete(0, "btnJournal");
   ObjectDelete(0, "btnAlerts");
   ObjectDelete(0, "btnLock");
   ObjectDelete(0, "btnUnlock");
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
   if(SignalMode != g_lastSignalMode) ApplySignalMode();

   // --- LOCK HEDGE SYSTEM: Check unlock triggers ---
   if(IsLockHedgeActive) {
      // Safety: if hedge orders were manually removed, clear stale lock state
      if(!HasOpenLockHedgeOrders()) {
         Log("Lock state cleared: no open lock hedge orders found.");
         IsLockHedgeActive = false;
         LockHedgeActivatedTime = 0;
         LockHedgeReason = "";
         LockHedgeDrawdownAtLock = 0.0;
      }

      if(!IsLockHedgeActive) {
         // lock state was stale and just cleared; continue normal flow below
      } else {
      // 1. Manual unlock (button/flag, handled via input or UI elsewhere)
      // 2. Auto unlock: bias realign, profit, timer
      bool unlock = false;
      string unlockReason = "";
      if(EnableAutoUnlock) {
         bool allAligned = true;
         bool foundManaged = false;
         for(int i=0; i<OrdersTotal(); i++) {
            if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
               if(IsManagedMarketOrder()) {
                  foundManaged = true;
                  string sym = OrderSymbol();
                  if(!IsOrderDirectionAlignedWithBias(sym, OrderType())) allAligned = false;
               }
            }
         }

         // Orphan hedge safety: main positions were manually closed/cancelled
         if(UnlockIfNoManagedPositions && !foundManaged && HasOpenLockHedgeOrders()) {
            unlock = true;
            unlockReason = "No managed positions (orphan hedge)";
         }

         if(!unlock) {
            if(MinLockHoldMinutes > 0 && LockHedgeActivatedTime > 0 && (TimeCurrent() - LockHedgeActivatedTime) < MinLockHoldMinutes * 60) {
               // hold lock for minimum time before standard auto unlock checks
            } else {
               // Unlock on bias realign
               if(UnlockOnBiasRealign) {
                  if(foundManaged && allAligned) { unlock = true; unlockReason = "Bias realigned"; }
               }
               // Unlock on profit
               if(!unlock && UnlockOnProfit) {
                  double target = AccountBalance() * (1.0 + UnlockProfitBufferPercent / 100.0);
                  if(AccountEquity() >= target) { unlock = true; unlockReason = "Equity buffer reached"; }
               }
               // Unlock after X minutes
               if(!unlock && UnlockAfterMinutes > 0 && LockHedgeActivatedTime > 0) {
                  if(TimeCurrent() - LockHedgeActivatedTime >= UnlockAfterMinutes*60) {
                     unlock = true; unlockReason = "Timer elapsed";
                  }
               }
            }
         }
      }
      if(unlock) {
         UnlockHedge(unlockReason);
         if(!IsLockHedgeActive) SendTelegram("<b>HEDGE UNLOCKED</b>" + TGTag() + "\nReason: " + unlockReason);
         else SendTelegram("<b>HEDGE UNLOCK PARTIAL</b>" + TGTag() + "\nReason: " + unlockReason + "\nSome hedge orders could not be closed.");
      }

      // Keep panel/risk telemetry fresh even while trading is paused by lock
      UpdateRiskTracking();
      int uiSecLocked = PanelRefreshSeconds;
      if(uiSecLocked < 1) uiSecLocked = 1;
      if(g_lastUIRefresh == 0 || (TimeCurrent() - g_lastUIRefresh) >= uiSecLocked) {
         UpdateChartPanel();
         UpdateAlertBadge();
         UpdateSkipLabel();
         g_lastUIRefresh = TimeCurrent();
      }

      // While locked, pause trading logic but still maintain pending-order hygiene
      CheckPendingOrderHealth();
      CheckPendingOrderExpiration();
      return; // Trading paused while locked
      }
   }

   // --- Normal operation if not locked ---
   UpdateRiskTracking();
   int uiSec = PanelRefreshSeconds;
   if(uiSec < 1) uiSec = 1;
   if(g_lastUIRefresh == 0 || (TimeCurrent() - g_lastUIRefresh) >= uiSec) {
      UpdateChartPanel();
      UpdateAlertBadge();
      UpdateSkipLabel();
      g_lastUIRefresh = TimeCurrent();
   }
   CheckDrawdownAlerts();
   CheckTrailingStopAlerts();
   CheckReversalWarnings();
   CheckBiasFlipHedgeAlerts();
   CheckBiasFlipExitAlerts();
   CheckPendingOrderHealth();
   CheckPendingOrderExpiration();
   CheckNewsAlerts();

   // --- LOCK HEDGE SYSTEM: Check lock triggers ---
   if(!IsLockHedgeActive && EnableAutoLock) {
      bool lock = false;
      string lockReason = "";
         // Auto lock: drawdown %
         if(LockDrawdownPercent > 0) {
            double ddPct = 100.0 * (AccountBalance() - AccountEquity()) / AccountBalance();
            if(ddPct >= LockDrawdownPercent) { lock = true; lockReason = "Drawdown % reached"; }
         }
         // Auto lock: drawdown $ amount
         if(!lock && LockDrawdownAmount > 0) {
            double ddAmt = AccountBalance() - AccountEquity();
            if(ddAmt >= LockDrawdownAmount) { lock = true; lockReason = "Drawdown $ reached"; }
         }
         // Auto lock: bias flip
         if(!lock && LockOnBiasFlip) {
            for(int i=0; i<OrdersTotal(); i++) {
               if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
                  if(IsManagedMarketOrder()) {
                     string sym = OrderSymbol();
                     if(BiasFlipPersisted(sym, OrderType(), LockBiasFlipPersistMins)) {
                        lock = true; lockReason = "Bias flip"; break;
                     } else {
                        // keep scanning
                     }
                  }
               }
            }
         }
         // Auto lock: news
         if(!lock && LockOnNews && GetNewsNowCached()) {
            lock = true; lockReason = "High-impact news";
         }
      if(lock) {
         LockHedge(lockReason);
         if(IsLockHedgeActive) {
            SendTelegram("<b>HEDGE LOCKED</b>" + TGTag() + "\nReason: " + lockReason);
            return; // Trading paused after lock
         }
      }
   }

   // --- Continue normal tick logic ---
   datetime h1 = iTime(Symbol(), PERIOD_H1, 0);
   if(h1 != lastScanTime) {
      lastScanTime = h1;
      int hour = TimeHour(TimeCurrent());
      if(hour == 0 && TimeDayOfWeek(TimeCurrent()) != 0 && TimeDayOfWeek(TimeCurrent()) != 6) {
         dayStartBalance = AccountBalance();
         drawdownWarningSet = false;
         drawdownLimitSent = false;
         // Drawdown recovery: update peak balance and toggle recovery mode
         if(UseDrawdownRecoveryMode) {
            double bal = AccountBalance();
            // Check if yesterday's session created a significant drawdown from peak
            if(g_ddPeakBalance > 0) {
               double ddFromPeak = ((g_ddPeakBalance - bal) / g_ddPeakBalance) * 100.0;
               if(ddFromPeak >= MaxDrawdownPercent) {
                  if(!g_inDDRecovery) {
                     g_inDDRecovery = true;
                     Print("[DD Recovery] Mode ON — balance ", bal, " vs peak ", g_ddPeakBalance, " (", DoubleToStrClean(ddFromPeak, 1), "% DD)");
                     SendTelegram("<b>DD RECOVERY MODE ON</b>" + TGTag() + "\nBalance dropped " + DoubleToStrClean(ddFromPeak, 1) + "% from peak ($" + DoubleToStrClean(g_ddPeakBalance, 2) + "). Lot size reduced to " + DoubleToStrClean(DDRecoveryLotMultiplier * 100, 0) + "% until recovery.");
                  }
               }
            }
            // Check if recovery threshold met
            if(g_inDDRecovery && g_ddPeakBalance > 0) {
               double recPct = (bal / g_ddPeakBalance) * 100.0;
               if(recPct >= DDRecoveryThresholdPct) {
                  g_inDDRecovery = false;
                  g_ddPeakBalance = bal;
                  Print("[DD Recovery] Mode OFF — balance recovered to ", DoubleToStrClean(recPct, 1), "% of peak");
                  SendTelegram("<b>DD RECOVERY COMPLETE</b>" + TGTag() + "\nBalance recovered to " + DoubleToStrClean(recPct, 1) + "% of peak. Normal lot size restored.");
               }
            }
            // Update peak when not in recovery
            if(!g_inDDRecovery) g_ddPeakBalance = MathMax(g_ddPeakBalance, bal);
            // Persist DD state across EA restarts
            GlobalVariableSet("SMP_DDPEAK_" + IntegerToString(AccountNumber()), g_ddPeakBalance);
            GlobalVariableSet("SMP_DDREC_"  + IntegerToString(AccountNumber()), g_inDDRecovery ? 1.0 : 0.0);
         }
      }
      if(!IsDrawdownOK()) {
         Log("Trading paused - drawdown limit reached");
         return;
      }
      CheckSessionAlert();
      // Update DD peak balance on every H1 scan to capture intraday balance highs
      if(UseDrawdownRecoveryMode && !g_inDDRecovery) {
         double newDDPeak = MathMax(g_ddPeakBalance, AccountBalance());
         if(newDDPeak > g_ddPeakBalance) {
            g_ddPeakBalance = newDDPeak;
            GlobalVariableSet("SMP_DDPEAK_" + IntegerToString(AccountNumber()), g_ddPeakBalance);
         }
      }

      CheckBiasReversal();
      CheckBreakouts();
      RefreshSRLevelsIfNeeded();
      // Refresh average spreads every H1 scan (EMA-smooth so baseline stays current)
      for(int spi = 0; spi < PairsCount; spi++) {
         double spNow = GetSpreadPips(Pairs[spi]);
         if(spNow > 0) AvgSpreads[spi] = (AvgSpreads[spi] > 0) ? (AvgSpreads[spi] * 0.9 + spNow * 0.1) : spNow;
      }
      if(IsSessionActive() || AllowOffSessionSignals) {
         string msg = BuildScorecardMessage();
         SendTelegram(msg);
      }
      if(hour == NYEndHour && lastDailySummary < iTime(Symbol(), PERIOD_D1, 0)) {
         lastDailySummary = iTime(Symbol(), PERIOD_D1, 0);
         SendDailySummary();
      }
      CheckWeeklySummary();
   }
}

// Manual on-demand alert scan (bypass internal timers)
void RunAlertChecksNow() {
   g_manualAlertRun = true;
   g_manualAlertSent = false;

   // Reset ALL check timers so every function runs immediately
   lastTrailingCheck = 0;
   lastReversalCheck = 0;
   lastExpirationCheck = 0;
   lastNewsCheck = 0;
   lastHedgeCheck = 0;
   lastExitCheck = 0;
   lastPendingHealthCheck = 0;

   CheckBiasReversal();
   CheckBreakouts();
   CheckTrailingStopAlerts();
   CheckReversalWarnings();
   CheckBiasFlipHedgeAlerts();
   CheckBiasFlipExitAlerts();
   CheckPendingOrderHealth();
   CheckPendingOrderExpiration();
   CheckNewsAlerts();

   g_manualAlertRun = false;
   // Send 'all clear' only if NO alerts were even attempted (g_manualAlertSent set on attempt, not just success)
   if(!g_manualAlertSent) {
      string msg = "<b>ALERT CHECK COMPLETE</b>" + TGTag() + "\n";
      msg += "No active triggers at this time.\n";
      msg += "Bias, breakouts, pending orders, and news all checked.\n";
      msg += "ACTION: None.";
      SendTelegram(msg);
   }
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
         // Full manual scan: refresh bias, breakouts, S/R levels, then send scorecard
         lastScanTime = 0;           // ensures H1 scan re-triggers on next tick too
         RefreshSRLevelsIfNeeded(true);
         CheckBiasReversal();
         CheckBreakouts();
         string msg = BuildScorecardMessage();
         SendTelegram(msg);
         ObjectSetInteger(0, "btnScan", OBJPROP_STATE, false);
         ChartRedraw();
      }

      else if(sparam == "btnJournal") {
         // Export closed trade history to CSV file
         ExportTradeJournal();
         ObjectSetInteger(0, "btnJournal", OBJPROP_STATE, false);
         ChartRedraw();
      }

      else if(sparam == "btnAlerts") {
         // Run all alert checks immediately (bypass timers)
         RunAlertChecksNow();
         ObjectSetInteger(0, "btnAlerts", OBJPROP_STATE, false);
         ChartRedraw();
      }

      else if(sparam == "btnLock") {
         if(!EnableManualLock) {
            Log("btnLock ignored: EnableManualLock=false.");
         } else if(IsLockHedgeActive) {
            Log("btnLock ignored: hedge lock already active.");
         } else {
            LockHedge("Manual lock button", true); // true = bypass cooldown for manual
            if(IsLockHedgeActive)
               SendTelegram("<b>HEDGE LOCKED</b>" + TGTag() + "\nReason: Manual lock button");
            else {
               // Determine specific reason for failure
               string failReason = "Unknown";
               if(OrdersTotal() == 0) failReason = "No open orders to hedge";
               else {
                  bool anyManaged = false;
                  for(int fi=0; fi<OrdersTotal(); fi++) {
                     if(OrderSelect(fi, SELECT_BY_POS, MODE_TRADES) && IsManagedMarketOrder()) { anyManaged = true; break; }
                  }
                  if(!anyManaged) failReason = "No managed market orders found";
                  else failReason = "Spread too wide or lot size below minimum";
               }
               SendTelegram("<b>HEDGE LOCK FAILED</b>" + TGTag() + "\nReason: " + failReason);
            }
         }
         ObjectSetInteger(0, "btnLock", OBJPROP_STATE, false);
         ChartRedraw();
      }

      else if(sparam == "btnUnlock") {
         if(!EnableManualUnlock) {
            Log("btnUnlock ignored: EnableManualUnlock=false.");
         } else if(!IsLockHedgeActive) {
            Log("btnUnlock ignored: no active hedge lock.");
         } else {
            UnlockHedge("Manual unlock button");
            if(!IsLockHedgeActive)
               SendTelegram("<b>HEDGE UNLOCKED</b>" + TGTag() + "\nReason: Manual unlock button");
            else
               SendTelegram("<b>HEDGE UNLOCK PARTIAL</b>" + TGTag() + "\nSome hedge orders could not be closed. Lock state cleared. Check manually.");
         }
         ObjectSetInteger(0, "btnUnlock", OBJPROP_STATE, false);
         ChartRedraw();
      }
   }
}
//+------------------------------------------------------------------+
