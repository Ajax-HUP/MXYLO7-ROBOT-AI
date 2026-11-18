//+------------------------------------------------------------------+
//| TREVOR SCALPER FX - MT5 Expert Advisor                           |
//| Version 1.0.0 - demo-first, live trading opt-in                  |
//| Attach to one chart per symbol. Uses closed M5/M15 candles.      |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "TREVOR SCALPER FX - EMA/RSI/MACD trend-momentum scalper"

#include <Trade/Trade.mqh>
CTrade trade;

input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M5;
input double InpRiskPercent = 0.50;
input double InpDailyLossLimitPercent = 2.00;
input int InpMaxOpenPositions = 3;
input int InpFastEMA = 9;
input int InpSlowEMA = 21;
input int InpRSIPeriod = 14;
input int InpMACDFast = 12;
input int InpMACDSlow = 26;
input int InpMACDSignal = 9;
input int InpATRPeriod = 14;
input double InpATRStopMultiplier = 1.50;
input double InpRewardRisk = 2.00;
input int InpMaxSpreadPoints = 30;
input ulong InpMagicNumber = 71180526;
input int InpDeviationPoints = 15;

// Live mode is deliberately locked by default. For a real account,
// set InpAllowLiveTrading=true AND enter the exact confirmation phrase.
input bool InpAllowLiveTrading = false;
input string InpLiveConfirmation = "";

int hFastEMA = INVALID_HANDLE;
int hSlowEMA = INVALID_HANDLE;
int hRSI = INVALID_HANDLE;
int hMACD = INVALID_HANDLE;
int hATR = INVALID_HANDLE;
datetime g_lastBar = 0;
int g_dayKey = -1;
double g_dayStartEquity = 0.0;
bool g_dailyLock = false;

int DayKey(datetime when)
{
   MqlDateTime t;
   TimeToStruct(when, t);
   return t.year * 1000 + t.day_of_year;
}

void ResetDailyBaseline()
{
   g_dayKey = DayKey(TimeCurrent());
   g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_dailyLock = false;
}

bool IsLiveAccount()
{
   return (AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_REAL);
}

bool TradingModeAllowed()
{
   if(!IsLiveAccount())
      return true;

   if(!InpAllowLiveTrading || InpLiveConfirmation != "I ACCEPT LIVE RISK")
   {
      Print("TREVOR: live account detected; trading blocked. Enable live mode and enter the exact confirmation phrase only after testing.");
      return false;
   }
   return true;
}

int CountOurPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         count++;
   }
   return count;
}

bool HasOurPositionOnSymbol()
{
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         return true;
   }
   return false;
}

double ClosedPnlToday()
{
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   t.hour = 0; t.min = 0; t.sec = 0;
   datetime dayStart = StructToTime(t);
   if(!HistorySelect(dayStart, TimeCurrent()))
      return 0.0;

   double pnl = 0.0;
   for(int i = 0; i < HistoryDealsTotal(); ++i)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0) continue;
      if((ulong)HistoryDealGetInteger(deal, DEAL_MAGIC) != InpMagicNumber)
         continue;
      pnl += HistoryDealGetDouble(deal, DEAL_PROFIT);
      pnl += HistoryDealGetDouble(deal, DEAL_SWAP);
      pnl += HistoryDealGetDouble(deal, DEAL_COMMISSION);
   }
   return pnl;
}

double FloatingPnl()
{
   double pnl = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      pnl += PositionGetDouble(POSITION_PROFIT);
      pnl += PositionGetDouble(POSITION_SWAP);
   }
   return pnl;
}

void CloseOurPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      trade.PositionClose(ticket);
   }
}

bool DailyLossReached()
{
   double loss = ClosedPnlToday() + FloatingPnl();
   double limit = g_dayStartEquity * InpDailyLossLimitPercent / 100.0;
   if(limit > 0.0 && loss <= -limit)
   {
      if(!g_dailyLock)
      {
         g_dailyLock = true;
         Print("TREVOR: daily loss limit reached. Closing this EA's positions and blocking new entries until the next server day.");
         CloseOurPositions();
      }
      return true;
   }
   return g_dailyLock;
}

double CalculateVolume(ENUM_ORDER_TYPE orderType, double entry, double stop)
{
   double riskCash = AccountInfoDouble(ACCOUNT_EQUITY) * InpRiskPercent / 100.0;
   double oneLotResult = 0.0;
   if(riskCash <= 0.0 || !OrderCalcProfit(orderType, _Symbol, 1.0, entry, stop, oneLotResult))
      return 0.0;

   double riskPerLot = MathAbs(oneLotResult);
   if(riskPerLot <= 0.0) return 0.0;

   double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) return 0.0;

   double volume = MathFloor((riskCash / riskPerLot) / step) * step;
   volume = MathMin(volume, maxVol);
   if(volume < minVol)
   {
      Print("TREVOR: calculated volume is below broker minimum; trade skipped to avoid exceeding configured risk.");
      return 0.0;
   }
   int digits = 2;
   if(step < 0.01) digits = 3;
   if(step < 0.001) digits = 4;
   return NormalizeDouble(volume, digits);
}

bool ReadValue(int handle, int buffer, int shift, double &value)
{
   double data[1];
   if(CopyBuffer(handle, buffer, shift, 1, data) != 1)
      return false;
   value = data[0];
   return MathIsValidNumber(value);
}

void EvaluateEntry()
{
   if(g_dailyLock || DailyLossReached()) return;
   if(!TradingModeAllowed()) return;
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
      return;
   if(CountOurPositions() >= InpMaxOpenPositions || HasOurPositionOnSymbol())
      return;

   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpreadPoints)
      return;

   double fast, slow, rsi, macdNow, macdPrev, atr;
   // Shift 1 and 2 are completed candles; no entry on a forming candle.
   if(!ReadValue(hFastEMA, 0, 1, fast) ||
      !ReadValue(hSlowEMA, 0, 1, slow) ||
      !ReadValue(hRSI, 0, 1, rsi) ||
      !ReadValue(hMACD, 0, 1, macdNow) ||
      !ReadValue(hMACD, 0, 2, macdPrev) ||
      !ReadValue(hATR, 0, 1, atr))
      return;

   bool buySignal = fast > slow && macdNow > macdPrev && rsi >= 52.0 && rsi <= 68.0;
   bool sellSignal = fast < slow && macdNow < macdPrev && rsi >= 32.0 && rsi <= 48.0;
   if(!buySignal && !sellSignal) return;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double brokerStopDistance = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   double stopDistance = MathMax(atr * InpATRStopMultiplier,
                                 MathMax(point * 10.0, brokerStopDistance));
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double entry = buySignal ? tick.ask : tick.bid;
   double sl = buySignal ? entry - stopDistance : entry + stopDistance;
   double tp = buySignal ? entry + stopDistance * InpRewardRisk : entry - stopDistance * InpRewardRisk;
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);

   ENUM_ORDER_TYPE type = buySignal ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double volume = CalculateVolume(type, entry, sl);
   if(volume <= 0.0) return;

   bool sent = false;
   if(buySignal)
      sent = trade.Buy(volume, _Symbol, 0.0, sl, tp, "TREVOR SCALPER FX BUY");
   else
      sent = trade.Sell(volume, _Symbol, 0.0, sl, tp, "TREVOR SCALPER FX SELL");

   if(!sent)
      Print("TREVOR: order request failed: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   else
      Print("TREVOR: order request accepted. Check broker execution result and account history. Ticket: ", trade.ResultOrder());
}

int OnInit()
{
   if(InpRiskPercent <= 0.0 || InpRiskPercent > 2.0 ||
      InpDailyLossLimitPercent <= 0.0 || InpDailyLossLimitPercent > 10.0 ||
      InpMaxOpenPositions < 1 || InpRewardRisk <= 0.0 ||
      InpATRStopMultiplier <= 0.0)
   {
      Print("TREVOR: invalid risk or strategy inputs.");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(!TradingModeAllowed())
      return INIT_FAILED;

   hFastEMA = iMA(_Symbol, InpTimeframe, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   hSlowEMA = iMA(_Symbol, InpTimeframe, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   hRSI = iRSI(_Symbol, InpTimeframe, InpRSIPeriod, PRICE_CLOSE);
   hMACD = iMACD(_Symbol, InpTimeframe, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
   hATR = iATR(_Symbol, InpTimeframe, InpATRPeriod);

   if(hFastEMA == INVALID_HANDLE || hSlowEMA == INVALID_HANDLE ||
      hRSI == INVALID_HANDLE || hMACD == INVALID_HANDLE || hATR == INVALID_HANDLE)
   {
      Print("TREVOR: failed to initialise one or more indicator handles.");
      return INIT_FAILED;
   }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpDeviationPoints);
   trade.SetTypeFillingBySymbol(_Symbol);
   ResetDailyBaseline();

   string mode = IsLiveAccount() ? "LIVE (explicitly unlocked)" : "DEMO / TEST";
   Print("TREVOR SCALPER FX initialised on ", _Symbol, " ", EnumToString(InpTimeframe), " | Mode: ", mode,
         " | Risk: ", DoubleToString(InpRiskPercent, 2), "% | Daily stop: ",
         DoubleToString(InpDailyLossLimitPercent, 2), "%");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(hFastEMA != INVALID_HANDLE) IndicatorRelease(hFastEMA);
   if(hSlowEMA != INVALID_HANDLE) IndicatorRelease(hSlowEMA);
   if(hRSI != INVALID_HANDLE) IndicatorRelease(hRSI);
   if(hMACD != INVALID_HANDLE) IndicatorRelease(hMACD);
   if(hATR != INVALID_HANDLE) IndicatorRelease(hATR);
   Comment("");
}

void OnTick()
{
   if(DayKey(TimeCurrent()) != g_dayKey)
      ResetDailyBaseline();

   if(DailyLossReached())
   {
      Comment("TREVOR SCALPER FX | DAILY LOSS LOCK ACTIVE");
      return;
   }

   datetime barTime = iTime(_Symbol, InpTimeframe, 0);
   if(barTime <= 0 || barTime == g_lastBar) return;
   g_lastBar = barTime;

   EvaluateEntry();
   Comment("TREVOR SCALPER FX | ", _Symbol, " | ", EnumToString(InpTimeframe),
           " | ", (IsLiveAccount() ? "LIVE" : "DEMO / TEST"),
           " | Open positions: ", CountOurPositions(), "/", InpMaxOpenPositions,
           " | Daily P/L: ", DoubleToString(ClosedPnlToday() + FloatingPnl(), 2));
}
//+------------------------------------------------------------------+
