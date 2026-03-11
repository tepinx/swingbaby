//+------------------------------------------------------------------+
//|                                           BiasPanelDisplay.mq4  |
//|              Currency Bias + Tradeable Pairs Display Panel       |
//|             Extracted from SwingMasterPro V1 — Panel only       |
//+------------------------------------------------------------------+
#property copyright "SwingMaster Pro v1.0"
#property version   "1.0"
#property strict

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input bool   ShowChartPanel      = true;
input color  PanelColor          = clrDarkSlateGray;
input color  TextColor           = clrWhite;
input int    PanelRefreshSeconds = 2;
input int    ATRPeriod           = 14;
input int    RSI_Period          = 14;
input double EMA_PullbackATR     = 0.5;

//+------------------------------------------------------------------+
//| GLOBALS                                                           |
//+------------------------------------------------------------------+
string Currencies[7]  = {"AUD","CAD","EUR","GBP","JPY","NZD","USD"};
string MajorPairs[21] = {"EURUSD","GBPUSD","USDJPY","AUDUSD","USDCAD","NZDUSD",
                         "EURJPY","GBPJPY","EURGBP","AUDJPY","EURAUD","AUDNZD",
                         "NZDJPY","GBPAUD","GBPCAD","EURNZD","AUDCAD",
                         "EURCAD","CADJPY","GBPNZD","NZDCAD"};
string Pairs[64];
int    PairsCount = 0;

datetime g_lastUIRefresh = 0;

//+------------------------------------------------------------------+
//| UTILITIES                                                         |
//+------------------------------------------------------------------+
string DoubleToStrClean(double value, int digits) {
   return DoubleToString(value, digits);
}

string TruncStr(string s, int maxLen) {
   if(StringLen(s) <= maxLen) return s;
   return StringSubstr(s, 0, maxLen);
}

double PipValue(string sym) {
   double point  = MarketInfo(sym, MODE_POINT);
   int    digits = (int)MarketInfo(sym, MODE_DIGITS);
   if(digits == 3 || digits == 5) return point * 10;
   return point;
}

string GetRSIEntryTag(int dir, double rsi) {
   if(dir == -1) {
      if(rsi < 25)       return "[OS]";
      else if(rsi < 35)  return "[OR]";
      else if(rsi <= 55) return "[PB]";
      else if(rsi <= 75) return "[OK]";
      else               return "[OB]";
   } else if(dir == 1) {
      if(rsi > 75)       return "[OB]";
      else if(rsi > 65)  return "[OR]";
      else if(rsi >= 45) return "[PB]";
      else if(rsi >= 25) return "[OK]";
      else               return "[OS]";
   }
   return "";
}

//+------------------------------------------------------------------+
//| SYMBOL RESOLUTION                                                 |
//+------------------------------------------------------------------+
string ResolveSymbol(string basePair) {
   int total = SymbolsTotal(true);
   for(int i = 0; i < total; i++) {
      string s = SymbolName(i, true);
      if(StringSubstr(s, 0, 6) == basePair) {
         SymbolSelect(s, true);
         return s;
      }
   }
   return "";
}

bool IsAllowedTradePair(string sym) {
   string baseSym = StringSubstr(sym, 0, 6);
   for(int i = 0; i < ArraySize(MajorPairs); i++) {
      if(baseSym == MajorPairs[i]) return true;
   }
   return false;
}

void PreloadHistory(string sym) {
   int tfs[3] = {PERIOD_H1, PERIOD_H4, PERIOD_D1};
   for(int i = 0; i < 3; i++) {
      iMA(sym, tfs[i], 20, 0, MODE_EMA, PRICE_CLOSE, 1);
      iMA(sym, tfs[i], 50, 0, MODE_EMA, PRICE_CLOSE, 1);
      iRSI(sym, tfs[i], RSI_Period, PRICE_CLOSE, 1);
      iATR(sym, tfs[i], ATRPeriod, 1);
   }
   // M15/M30 EMAs needed by GetBiasLabelLow (used for M15 bias display section)
   iMA(sym, PERIOD_M30, 20, 0, MODE_EMA, PRICE_CLOSE, 1);
   iMA(sym, PERIOD_M30, 50, 0, MODE_EMA, PRICE_CLOSE, 1);
   iMA(sym, PERIOD_M15, 20, 0, MODE_EMA, PRICE_CLOSE, 1);
   iMA(sym, PERIOD_M15, 50, 0, MODE_EMA, PRICE_CLOSE, 1);
}

void BuildPairsUniverse() {
   PairsCount = 0;
   for(int i = 0; i < 7; i++) {
      for(int j = 0; j < 7; j++) {
         if(i == j) continue;
         string sym = ResolveSymbol(Currencies[i] + Currencies[j]);
         if(sym != "" && IsAllowedTradePair(sym)) {
            PreloadHistory(sym);
            Pairs[PairsCount] = sym;
            PairsCount++;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| CURRENCY STRENGTH / BIAS ENGINE (identical to V1)               |
//+------------------------------------------------------------------+
int GetTFSignTrend(string sym, int tf) {
   double ema20_b1 = iMA(sym, tf, 20, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema20_b2 = iMA(sym, tf, 20, 0, MODE_EMA, PRICE_CLOSE, 2);
   double ema50    = iMA(sym, tf, 50, 0, MODE_EMA, PRICE_CLOSE, 1);
   double atr      = iATR(sym, tf, ATRPeriod, 1);
   if(ema20_b1 <= 0 || ema20_b2 <= 0 || ema50 <= 0 || atr == 0) return 0;

   bool bullishStructure = (ema20_b1 > ema50);
   bool bearishStructure = (ema20_b1 < ema50);
   double gapRatio = (ema20_b1 - ema50) / atr;
   bool strongGap  = (MathAbs(gapRatio) > 0.1);
   bool slopeUp    = (ema20_b1 > ema20_b2);
   bool slopeDown  = (ema20_b1 < ema20_b2);

   if(bullishStructure && strongGap && slopeUp)   return  1;
   if(bearishStructure && strongGap && slopeDown) return -1;
   return 0;
}

int CurrencyScoreInt(string cur, int tf) {
   int bullish = 0, bearish = 0;
   for(int i = 0; i < PairsCount; i++) {
      string p    = Pairs[i];
      string base = StringSubstr(p, 0, 3);
      string quot = StringSubstr(p, 3, 3);
      if(base != cur && quot != cur) continue;
      int sign = GetTFSignTrend(p, tf);
      if(sign == 0) continue;
      int contrib = (base == cur) ? sign : -sign;
      if(contrib > 0) bullish++;
      else            bearish--;
   }
   if(MathAbs(bullish) > MathAbs(bearish)) return bullish;
   if(MathAbs(bearish) > MathAbs(bullish)) return bearish;
   return 0;
}

void CurrencyScoreDetail(string cur, int tf, int &bull, int &bear, int &rang) {
   bull = 0; bear = 0; rang = 0;
   for(int i = 0; i < PairsCount; i++) {
      string p    = Pairs[i];
      string base = StringSubstr(p, 0, 3);
      string quot = StringSubstr(p, 3, 3);
      if(base != cur && quot != cur) continue;
      int sign = GetTFSignTrend(p, tf);
      if(sign == 0) { rang++; continue; }
      int contrib = (base == cur) ? sign : -sign;
      if(contrib > 0) bull++;
      else            bear++;
   }
}

string GetBiasLabel(string cur) {
   int h1 = CurrencyScoreInt(cur, PERIOD_H1);
   int h4 = CurrencyScoreInt(cur, PERIOD_H4);
   int d1 = CurrencyScoreInt(cur, PERIOD_D1);

   bool hasStrong = (h1 >= 4 || h4 >= 4 || d1 >= 4);
   bool hasWeak   = (h1 <= -4 || h4 <= -4 || d1 <= -4);
   if(hasStrong && hasWeak) return "INV";

   int maxAbsScore = h1;
   if(MathAbs(h4) > MathAbs(maxAbsScore)) maxAbsScore = h4;
   if(MathAbs(d1) > MathAbs(maxAbsScore)) maxAbsScore = d1;

   if(maxAbsScore == 4)  return "INV";
   if(maxAbsScore >= 5)  return "STRONG";
   if(maxAbsScore <= -4) return "WEAK";
   return "NEUTRAL";
}

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
   if(maxAbsScore >= 5)  return "STRONG";
   if(maxAbsScore <= -4) return "WEAK";
   return "NEUTRAL";
}

int GetDirectionFromBiasLabels(string baseBias, string quoteBias) {
   if(baseBias == "INV" || quoteBias == "INV") return 0;
   if(baseBias == "STRONG" && (quoteBias == "WEAK"    || quoteBias == "NEUTRAL")) return  1;
   if(baseBias == "WEAK"   && (quoteBias == "STRONG"  || quoteBias == "NEUTRAL")) return -1;
   if(baseBias == "NEUTRAL" && quoteBias == "STRONG")                             return -1;
   if(baseBias == "NEUTRAL" && quoteBias == "WEAK")                               return  1;
   return 0;
}

int GetPairPriority(string sym) {
   string base      = StringSubstr(sym, 0, 3);
   string quot      = StringSubstr(sym, 3, 3);
   // H1 authority only (D1+H4+H1) — no M15 fallback
   string baseBias  = GetBiasLabel(base);
   string quoteBias = GetBiasLabel(quot);
   if(baseBias == "INV" || quoteBias == "INV") return 0;
   if((baseBias == "STRONG" && quoteBias == "WEAK") || (baseBias == "WEAK" && quoteBias == "STRONG")) return 1;
   if((baseBias == "STRONG" && quoteBias == "NEUTRAL") || (baseBias == "NEUTRAL" && quoteBias == "STRONG")) return 2;
   if((baseBias == "WEAK"   && quoteBias == "NEUTRAL") || (baseBias == "NEUTRAL" && quoteBias == "WEAK"))   return 3;
   return 0;
}

int GetTradeDirection(string sym) {
   string base      = StringSubstr(sym, 0, 3);
   string quot      = StringSubstr(sym, 3, 3);
   // H1 authority only (D1+H4+H1) — no M15 fallback
   string baseBias  = GetBiasLabel(base);
   string quoteBias = GetBiasLabel(quot);
   if(GetPairPriority(sym) == 0) return 0;
   if(baseBias == "STRONG" && (quoteBias == "WEAK"    || quoteBias == "NEUTRAL")) return  1;
   if(baseBias == "WEAK"   && (quoteBias == "STRONG"  || quoteBias == "NEUTRAL")) return -1;
   if(baseBias == "NEUTRAL" && quoteBias == "STRONG")                             return -1;
   if(baseBias == "NEUTRAL" && quoteBias == "WEAK")                               return  1;
   return 0;
}

//+------------------------------------------------------------------+
//| PANEL                                                             |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, color clr, int size, string font = "Arial") {
   if(ObjectFind(0, name) == -1)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

void CreateChartPanel() {
   if(ObjectFind(0, "PanelBG") == -1) {
      ObjectCreate(0, "PanelBG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "PanelBG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   }
   ObjectSetInteger(0, "PanelBG", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "PanelBG", OBJPROP_YDISTANCE, 30);
   ObjectSetInteger(0, "PanelBG", OBJPROP_XSIZE, 580);
   ObjectSetInteger(0, "PanelBG", OBJPROP_YSIZE, 260);
   ObjectSetInteger(0, "PanelBG", OBJPROP_BGCOLOR, PanelColor);
   ObjectSetInteger(0, "PanelBG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   CreateLabel("PanelTitle", "Bias Panel Display", 20, 38, TextColor, 10, "Arial Black");
   ChartRedraw();
}

void UpdateChartPanel() {
   if(!ShowChartPanel) return;

   int x          = 20;
   int y          = 55;
   int lineHeight = 15;
   int rowHeight  = 14;
   int colWidth   = 250;
   int maxChars   = 0;

   // ── Section 1: Currency Bias — H1 Chart (D1/H4/H1) ──────────────
   CreateLabel("LblBiasTitle", "Currency Bias (H1/H4/D1):", x, y, clrYellow, 9);
   y += lineHeight;

   for(int bi = 0; bi < 7; bi++) {
      string cur   = Currencies[bi];
      string bias  = GetBiasLabel(cur);
      string sh    = (bias == "STRONG") ? "STR" : (bias == "WEAK") ? "WK" : (bias == "INV") ? "INV" : "NEU";
      color  bc    = (bias == "STRONG") ? clrLime : (bias == "WEAK") ? clrRed : (bias == "INV") ? clrOrange : clrGray;
      int d1b, d1br, d1r, h4b, h4br, h4r, h1b, h1br, h1r;
      CurrencyScoreDetail(cur, PERIOD_D1, d1b, d1br, d1r);
      CurrencyScoreDetail(cur, PERIOD_H4, h4b, h4br, h4r);
      CurrencyScoreDetail(cur, PERIOD_H1, h1b, h1br, h1r);
      string s = cur + ":" + sh
               + "  D1:+" + IntegerToString(d1b)  + "/-" + IntegerToString(d1br)  + "/" + IntegerToString(d1r)
               + "  H4:+" + IntegerToString(h4b)  + "/-" + IntegerToString(h4br)  + "/" + IntegerToString(h4r)
               + "  H1:+" + IntegerToString(h1b)  + "/-" + IntegerToString(h1br)  + "/" + IntegerToString(h1r);
      maxChars = MathMax(maxChars, StringLen(s));
      int bcol = bi % 2, brow = bi / 2;
      CreateLabel("LblBias" + cur, s, x + (bcol * colWidth), y + (brow * rowHeight), bc, 8);
   }
   y += (rowHeight * 4) + 8;

   // ── Section 2: Currency Bias — M15 Chart (H1/M30/M15) ───────────
   CreateLabel("LblBiasTitleM15", "Currency Bias (M15/M30/H1):", x, y, clrYellow, 9);
   y += lineHeight;

   for(int mi = 0; mi < 7; mi++) {
      string cur  = Currencies[mi];
      string bias = GetBiasLabelLow(cur);
      string sh   = (bias == "STRONG") ? "STR" : (bias == "WEAK") ? "WK" : (bias == "INV") ? "INV" : "NEU";
      color  bc   = (bias == "STRONG") ? clrLime : (bias == "WEAK") ? clrRed : (bias == "INV") ? clrOrange : clrGray;
      int mh1b, mh1br, mh1r, mm30b, mm30br, mm30r, mm15b, mm15br, mm15r;
      CurrencyScoreDetail(cur, PERIOD_H1,  mh1b,  mh1br,  mh1r);
      CurrencyScoreDetail(cur, PERIOD_M30, mm30b, mm30br, mm30r);
      CurrencyScoreDetail(cur, PERIOD_M15, mm15b, mm15br, mm15r);
      string s = cur + ":" + sh
               + "  H1:+"  + IntegerToString(mh1b)  + "/-" + IntegerToString(mh1br)  + "/" + IntegerToString(mh1r)
               + "  M30:+" + IntegerToString(mm30b)  + "/-" + IntegerToString(mm30br) + "/" + IntegerToString(mm30r)
               + "  M15:+" + IntegerToString(mm15b)  + "/-" + IntegerToString(mm15br) + "/" + IntegerToString(mm15r);
      maxChars = MathMax(maxChars, StringLen(s));
      int mcol = mi % 2, mrow = mi / 2;
      CreateLabel("LblBiasM15" + cur, s, x + (mcol * colWidth), y + (mrow * rowHeight), bc, 8);
   }
   y += (rowHeight * 4) + 8;

   // ── Section 3: Tradeable Now ─────────────────────────────────────
   CreateLabel("LblTradeableTitle", "Tradeable Now Currency Pairs:", x, y, clrYellow, 9);
   y += lineHeight;

   string tBuyA[64], tBuyB[64]; color tBuyClr[64]; int tBuyCnt = 0;
   string tSelA[64], tSelB[64]; color tSelClr[64]; int tSelCnt = 0;

   for(int pi = 0; pi < PairsCount; pi++) {
      string psym   = Pairs[pi];
      string pbase  = StringSubstr(psym, 0, 3);
      string pquote = StringSubstr(psym, 3, 3);

      int dirH1  = GetDirectionFromBiasLabels(GetBiasLabel(pbase),    GetBiasLabel(pquote));
      int dirM15 = GetDirectionFromBiasLabels(GetBiasLabelLow(pbase), GetBiasLabelLow(pquote));

      // H1 is the sole direction authority — skip if H1 has no clear bias
      if(dirH1 == 0) continue;
      int    dir     = dirH1;
      string pairLbl = psym + (dirM15 == dirH1 ? "(H1/M15)" : "(H1)");

      double tEMA20  = iMA(psym, PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE, 1);
      double tATR    = iATR(psym, PERIOD_H1, ATRPeriod, 1);
      double tClose  = iClose(psym, PERIOD_H1, 1);
      double tRSI1   = iRSI(psym, PERIOD_H1, RSI_Period, PRICE_CLOSE, 1);
      double tRSI2   = iRSI(psym, PERIOD_H1, RSI_Period, PRICE_CLOSE, 2);
      double tEMADist = tClose - tEMA20;
      string tEMATag = (tATR > 0 && MathAbs(tEMADist) <= tATR * EMA_PullbackATR) ? "~" : (tEMADist > 0 ? "^" : "v");
      string tRSIDir = (tRSI1 > tRSI2) ? "^" : (tRSI1 < tRSI2) ? "v" : "-";

      double tEMA20m = iMA(psym, PERIOD_M15, 20, 0, MODE_EMA, PRICE_CLOSE, 1);
      double tATRm   = iATR(psym, PERIOD_M15, ATRPeriod, 1);
      double tClosem = iClose(psym, PERIOD_M15, 1);
      double tRSI1m  = iRSI(psym, PERIOD_M15, RSI_Period, PRICE_CLOSE, 1);
      double tRSI2m  = iRSI(psym, PERIOD_M15, RSI_Period, PRICE_CLOSE, 2);
      double tEMADistm = tClosem - tEMA20m;
      string tEMATagm = (tATRm > 0 && MathAbs(tEMADistm) <= tATRm * EMA_PullbackATR) ? "~" : (tEMADistm > 0 ? "^" : "v");
      string tRSIDirm = (tRSI1m > tRSI2m) ? "^" : (tRSI1m < tRSI2m) ? "v" : "-";
      string tEntryTag = GetRSIEntryTag(dir, tRSI1m);

      string lblA = (dir == 1 ? "BUY:  " : "SELL: ") + pairLbl;
      string lblB = "H1:EMA:" + tEMATag + " RSI:" + DoubleToStrClean(tRSI1, 0) + tRSIDir +
                    "  M15:EMA:" + tEMATagm + " RSI:" + DoubleToStrClean(tRSI1m, 0) + tRSIDirm + " " + tEntryTag;
      color  clrT = (dir == 1) ? clrLime : clrTomato;
      maxChars = MathMax(maxChars, StringLen(lblA) + StringLen(lblB) + 2);

      if(dir == 1) { tBuyA[tBuyCnt] = lblA; tBuyB[tBuyCnt] = lblB; tBuyClr[tBuyCnt] = clrT; tBuyCnt++; }
      else         { tSelA[tSelCnt] = lblA; tSelB[tSelCnt] = lblB; tSelClr[tSelCnt] = clrT; tSelCnt++; }
   }

   for(int tdi = 0; tdi < 64; tdi++) {
      ObjectDelete(0, "LblTrade_" + IntegerToString(tdi) + "A");
      ObjectDelete(0, "LblTrade_" + IntegerToString(tdi) + "B");
   }

   int tradeRow = 0;
   for(int bi = 0; bi < tBuyCnt; bi++, tradeRow++) {
      CreateLabel("LblTrade_" + IntegerToString(tradeRow) + "A", tBuyA[bi], x,                                     y, tBuyClr[bi], 8);
      CreateLabel("LblTrade_" + IntegerToString(tradeRow) + "B", tBuyB[bi], x + StringLen(tBuyA[bi]) * 6 + 8,     y, tBuyClr[bi], 8);
      y += lineHeight;
   }
   for(int si = 0; si < tSelCnt; si++, tradeRow++) {
      CreateLabel("LblTrade_" + IntegerToString(tradeRow) + "A", tSelA[si], x,                                     y, tSelClr[si], 8);
      CreateLabel("LblTrade_" + IntegerToString(tradeRow) + "B", tSelB[si], x + StringLen(tSelA[si]) * 6 + 8,     y, tSelClr[si], 8);
      y += lineHeight;
   }
   if(tBuyCnt == 0 && tSelCnt == 0) {
      CreateLabel("LblTradeable_N", "No clear bias on any pair.", x, y, clrGray, 8);
      y += lineHeight;
   } else {
      ObjectDelete(0, "LblTradeable_N");
   }

   y += 4;

   // ── Resize panel to fit content exactly ─────────────────────────
   int panelH = (y - 30) + 20;
   if(panelH < 120) panelH = 120;
   int panelW = MathMax(500, maxChars * 7 + 40);
   ObjectSetInteger(0, "PanelBG", OBJPROP_XSIZE, panelW);
   ObjectSetInteger(0, "PanelBG", OBJPROP_YSIZE, panelH);

   ChartRedraw();
}

void DeleteAllPanelObjects() {
   ObjectDelete(0, "PanelBG");
   ObjectDelete(0, "PanelTitle");
   ObjectDelete(0, "LblBiasTitle");
   ObjectDelete(0, "LblBiasTitleM15");
   ObjectDelete(0, "LblTradeableTitle");
   ObjectDelete(0, "LblTradeable_N");
   for(int i = 0; i < 7; i++) {
      ObjectDelete(0, "LblBias"    + Currencies[i]);
      ObjectDelete(0, "LblBiasM15" + Currencies[i]);
   }
   for(int i = 0; i < 64; i++) {
      ObjectDelete(0, "LblTrade_" + IntegerToString(i) + "A");
      ObjectDelete(0, "LblTrade_" + IntegerToString(i) + "B");
   }
}

//+------------------------------------------------------------------+
//| EA LIFECYCLE                                                      |
//+------------------------------------------------------------------+
int OnInit() {
   BuildPairsUniverse();
   CreateChartPanel();
   UpdateChartPanel();
   return INIT_SUCCEEDED;
}

void OnTick() {
   if(!ShowChartPanel) return;
   if(TimeCurrent() - g_lastUIRefresh < PanelRefreshSeconds) return;
   g_lastUIRefresh = TimeCurrent();
   UpdateChartPanel();
}

void OnDeinit(const int reason) {
   DeleteAllPanelObjects();
}
