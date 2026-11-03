//+------------------------------------------------------------------+
//| TREVO SCALPER FX - MT5 Expert Advisor                             |
//| Original EMA/RSI/ATR scalping framework. Demo accounts only.      |
//| Not affiliated with or copied from Scalper X.                     |
//+------------------------------------------------------------------+
#property strict
#property version   "0.1.0"
#property description "TREVO SCALPER FX - demo-only automated trading framework"

#include <Trade/Trade.mqh>
CTrade trade;

input bool   EnableTrading          = false; // Explicit opt-in; OFF by default
input string LicenseKey             = "";    // Customer licence key
input string LicenseApiUrl           = "https://wandering-snowflake-224e.freddyrisenga.workers.dev/";
input int    LicenseRecheckMinutes   = 60;
input ulong  MagicNumber            = 6041104;
input ENUM_TIMEFRAMES SignalTimeframe = PERIOD_M5;
input int    FastEMA                = 9;
input int    SlowEMA                = 21;
input int    RSIPeriod              = 14;
input double BuyRSIMin              = 52.0;
input double SellRSIMax             = 48.0;
input int    ATRPeriod              = 14;
input double StopLossATR            = 1.5;
input double TakeProfitATR          = 1.2;
input double TrailingATR            = 1.0;
input double RiskPercent            = 0.25; // risk per trade, percent of equity
input double MaxDailyLossPercent    = 1.0;  // stop opening trades after daily loss
input int    MaxSpreadPoints        = 25;
input int    StartHour               = 6;   // broker server time
input int    EndHour                 = 20;  // broker server time, exclusive
input int    MaxPositions            = 1;
input int    SlippagePoints          = 10;

int hFast = INVALID_HANDLE, hSlow = INVALID_HANDLE;
int hRsi = INVALID_HANDLE, hAtr = INVALID_HANDLE;
datetime lastBar = 0;
int dayKey = -1;
double dayStartEquity = 0.0;
bool dailyStop = false;
bool licenseValid = false;
datetime lastLicenseCheck = 0;
string lastAction = "Waiting for first closed candle";

bool IsDemoAccount()
{
   return (AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO);
}

int MakeDayKey()
{
   MqlDateTime t; TimeToStruct(TimeCurrent(), t);
   return t.year * 1000 + t.day_of_year;
}

void RefreshDailyGuard()
{
   int k = MakeDayKey();
   if(k != dayKey)
   {
      dayKey = k;
      dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      dailyStop = false;
   }
   if(dayStartEquity > 0.0)
   {
      double lossPct = 100.0 * (dayStartEquity - AccountInfoDouble(ACCOUNT_EQUITY)) / dayStartEquity;
      if(lossPct >= MaxDailyLossPercent) dailyStop = true;
   }
}

bool IsTradingHour()
{
   MqlDateTime t; TimeToStruct(TimeCurrent(), t);
   if(StartHour == EndHour) return true;
   if(StartHour < EndHour) return (t.hour >= StartHour && t.hour < EndHour);
   return (t.hour >= StartHour || t.hour < EndHour);
}

bool IsNewBar()
{
   datetime t = iTime(_Symbol, SignalTimeframe, 0);
   if(t == 0 || t == lastBar) return false;
   lastBar = t;
   return true;
}

bool ReadValue(int handle, int shift, double &value)
{
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(handle, 0, shift, 1, buf) != 1) return false;
   value = buf[0];
   return true;
}

int CountOurPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (ulong)PositionGetInteger(POSITION_MAGIC) == MagicNumber) count++;
   }
   return count;
}

double NormalizeVolume(double lots)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0) return 0;
   lots = MathMax(minLot, MathMin(maxLot, lots));
   lots = MathFloor(lots / step) * step;
   int digits = 2;
   if(step < 0.01) digits = 3;
   if(step < 0.001) digits = 4;
   return NormalizeDouble(lots, digits);
}

double LotsForRisk(double stopDistance)
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskMoney = equity * RiskPercent / 100.0;
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tickValue <= 0) tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0 || tickValue <= 0 || stopDistance <= 0) return 0;
   double lossPerLot = (stopDistance / tickSize) * tickValue;
   if(lossPerLot <= 0) return 0;
   return NormalizeVolume(riskMoney / lossPerLot);
}

bool StopsAreValid(double slDistance, double tpDistance)
{
   int minStop = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = minStop * _Point;
   return (slDistance >= minDistance && tpDistance >= minDistance);
}

void ManageTrailing()
{
   double atr;
   if(!ReadValue(hAtr, 1, atr) || atr <= 0) return;
   double trail = atr * TrailingATR;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      long type = PositionGetInteger(POSITION_TYPE);
      double oldSL = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      if(type == POSITION_TYPE_BUY)
      {
         double candidate = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID) - trail, _Digits);
         if(candidate > oldSL && candidate < SymbolInfoDouble(_Symbol, SYMBOL_BID))
            trade.PositionModify(ticket, candidate, tp);
      }
      else if(type == POSITION_TYPE_SELL)
      {
         double candidate = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK) + trail, _Digits);
         if((oldSL == 0 || candidate < oldSL) && candidate > SymbolInfoDouble(_Symbol, SYMBOL_ASK))
            trade.PositionModify(ticket, candidate, tp);
      }
   }
}

void TryEntry()
{
   RefreshDailyGuard();
   if(!EnableTrading) { lastAction = "Trading disabled in EA inputs"; return; }
   if(!licenseValid) { lastAction = "Blocked: valid online licence required"; return; }
   if(!IsDemoAccount()) { lastAction = "Blocked: demo account required"; return; }
   if(dailyStop) { lastAction = "Daily loss guard reached - entries blocked"; return; }
   if(!IsTradingHour()) { lastAction = "Outside configured trading hours"; return; }
   if((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > MaxSpreadPoints)
   { lastAction = "Spread filter blocked entry"; return; }
   if(CountOurPositions() >= MaxPositions) { lastAction = "Position limit reached"; return; }

   double fast1, fast2, slow1, slow2, rsi, atr;
   if(!ReadValue(hFast, 1, fast1) || !ReadValue(hFast, 2, fast2) ||
      !ReadValue(hSlow, 1, slow1) || !ReadValue(hSlow, 2, slow2) ||
      !ReadValue(hRsi, 1, rsi) || !ReadValue(hAtr, 1, atr) || atr <= 0)
   { lastAction = "Waiting for indicator data"; return; }

   bool buy = (fast2 <= slow2 && fast1 > slow1 && rsi >= BuyRSIMin);
   bool sell = (fast2 >= slow2 && fast1 < slow1 && rsi <= SellRSIMax);
   if(!buy && !sell) { lastAction = "No confirmed EMA/RSI setup"; return; }

   double slDist = atr * StopLossATR, tpDist = atr * TakeProfitATR;
   if(!StopsAreValid(slDist, tpDist)) { lastAction = "Broker minimum stop distance blocks setup"; return; }
   double lots = LotsForRisk(slDist);
   if(lots <= 0) { lastAction = "Position size calculation failed - no order"; return; }

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);
   trade.SetTypeFillingBySymbol(_Symbol);
   bool ok = false;
   if(buy)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      ok = trade.Buy(lots, _Symbol, ask, NormalizeDouble(ask-slDist,_Digits),
                     NormalizeDouble(ask+tpDist,_Digits), "TREVO SCALPER FX BUY");
   }
   else
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      ok = trade.Sell(lots, _Symbol, bid, NormalizeDouble(bid+slDist,_Digits),
                      NormalizeDouble(bid-tpDist,_Digits), "TREVO SCALPER FX SELL");
   }
   lastAction = ok ? (buy ? "BUY order accepted by terminal" : "SELL order accepted by terminal")
                   : "Order rejected: " + trade.ResultRetcodeDescription();
}

int OnInit()
{
   if(!IsDemoAccount())
   {
      Print("TREVO SCALPER FX: live/real accounts are blocked in this initial build.");
      return INIT_FAILED;
   }
   if(FastEMA < 2 || SlowEMA <= FastEMA || RiskPercent <= 0 ||
      MaxDailyLossPercent <= 0 || StopLossATR <= 0 || TakeProfitATR <= 0)
      return INIT_PARAMETERS_INCORRECT;

   hFast = iMA(_Symbol, SignalTimeframe, FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   hSlow = iMA(_Symbol, SignalTimeframe, SlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   hRsi = iRSI(_Symbol, SignalTimeframe, RSIPeriod, PRICE_CLOSE);
   hAtr = iATR(_Symbol, SignalTimeframe, ATRPeriod);
   if(hFast == INVALID_HANDLE || hSlow == INVALID_HANDLE ||
      hRsi == INVALID_HANDLE || hAtr == INVALID_HANDLE) return INIT_FAILED;

   trade.SetExpertMagicNumber(MagicNumber);
   RefreshDailyGuard();
   EventSetTimer(2);
   Print("TREVO SCALPER FX initialised in demo-only mode. Auto trading is OFF until explicitly enabled.");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   if(hFast != INVALID_HANDLE) IndicatorRelease(hFast);
   if(hSlow != INVALID_HANDLE) IndicatorRelease(hSlow);
   if(hRsi != INVALID_HANDLE) IndicatorRelease(hRsi);
   if(hAtr != INVALID_HANDLE) IndicatorRelease(hAtr);
   Comment("");
}

void OnTimer()
{
   RefreshDailyGuard();
   ManageTrailing();
   Comment("TREVO SCALPER FX\n",
           "Mode: DEMO ONLY | Auto: ", (EnableTrading ? "ENABLED" : "DISABLED"), "\n",
           "Symbol: ", _Symbol, " | TF: ", EnumToString(SignalTimeframe), "\n",
           "Equity: ", DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2),
           " | Daily guard: ", (dailyStop ? "TRIGGERED" : "OK"), "\n",
           "Open positions: ", CountOurPositions(), "\n",
           "Status: ", lastAction);
}

void OnTick()
{
   RefreshDailyGuard();
   ManageTrailing();
   if(IsNewBar()) TryEntry();
}
//+------------------------------------------------------------------+
