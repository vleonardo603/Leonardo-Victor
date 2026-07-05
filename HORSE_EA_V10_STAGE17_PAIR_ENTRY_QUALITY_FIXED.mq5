//+------------------------------------------------------------------+
//|                                      HORSE EA.mq5  |
//|                     HORSE EA - PROP CHALLENGE EDITION   |
//|                         V10 â€” PERFECT ENGINE 10/10               |
//+------------------------------------------------------------------+
#property strict
#property version   "10.01"
#property description "HORSE EA"
#property description "SmartExit corrigido: CLOSE_BUY WR4%â†’fix | PartialClose $18â†’$10 | MinProfit $20â†’$35"


// HORSE EA - self-contained trade wrapper.
// This avoids compile failure when the local MT5 standard library file
// MQL5/Include/Trade/Trade.mqh is missing or corrupted.
class CTrade
{
private:
   ulong                   m_magic;
   uint                    m_deviation;
   ENUM_ORDER_TYPE_FILLING m_filling;
   MqlTradeResult          m_result;

   bool IsOkRetcode(uint retcode)
   {
      return (retcode == TRADE_RETCODE_DONE ||
              retcode == TRADE_RETCODE_PLACED ||
              retcode == TRADE_RETCODE_DONE_PARTIAL);
   }

   bool SendDeal(ENUM_ORDER_TYPE orderType,
                 double volume,
                 string symbol,
                 double price,
                 double sl,
                 double tp,
                 string comment,
                 ulong positionTicket)
   {
      if(symbol == "") symbol = _Symbol;

      MqlTradeRequest request;
      ZeroMemory(request);
      ZeroMemory(m_result);

      request.action    = TRADE_ACTION_DEAL;
      request.symbol    = symbol;
      request.volume    = volume;
      request.type      = orderType;
      request.magic     = m_magic;
      request.deviation = m_deviation;
      request.sl        = sl;
      request.tp        = tp;
      request.comment   = comment;
      if(positionTicket > 0)
         request.position = positionTicket;

      if(price <= 0.0)
      {
         if(orderType == ORDER_TYPE_BUY)
            price = SymbolInfoDouble(symbol, SYMBOL_ASK);
         else
            price = SymbolInfoDouble(symbol, SYMBOL_BID);
      }
      request.price = price;
      request.type_filling = m_filling;

      bool sent = OrderSend(request, m_result);
      return (sent && IsOkRetcode(m_result.retcode));
   }

public:
   CTrade()
   {
      m_magic     = 0;
      m_deviation = 10;
      m_filling   = ORDER_FILLING_FOK;
      ZeroMemory(m_result);
   }

   void SetExpertMagicNumber(ulong magic)
   {
      m_magic = magic;
   }

   void SetDeviationInPoints(int deviation)
   {
      if(deviation < 0) deviation = 0;
      m_deviation = (uint)deviation;
   }

   void SetTypeFilling(ENUM_ORDER_TYPE_FILLING filling)
   {
      m_filling = filling;
   }

   bool Buy(double volume,
            string symbol = "",
            double price = 0.0,
            double sl = 0.0,
            double tp = 0.0,
            string comment = "")
   {
      return SendDeal(ORDER_TYPE_BUY, volume, symbol, price, sl, tp, comment, 0);
   }

   bool Sell(double volume,
             string symbol = "",
             double price = 0.0,
             double sl = 0.0,
             double tp = 0.0,
             string comment = "")
   {
      return SendDeal(ORDER_TYPE_SELL, volume, symbol, price, sl, tp, comment, 0);
   }

   bool PositionModify(ulong ticket, double sl, double tp)
   {
      if(!PositionSelectByTicket(ticket))
      {
         ZeroMemory(m_result);
         m_result.retcode = TRADE_RETCODE_INVALID;
         return false;
      }

      string symbol = PositionGetString(POSITION_SYMBOL);

      MqlTradeRequest request;
      ZeroMemory(request);
      ZeroMemory(m_result);

      request.action   = TRADE_ACTION_SLTP;
      request.position = ticket;
      request.symbol   = symbol;
      request.sl       = sl;
      request.tp       = tp;
      request.magic    = m_magic;

      bool sent = OrderSend(request, m_result);
      return (sent && IsOkRetcode(m_result.retcode));
   }

   bool PositionClose(ulong ticket)
   {
      if(!PositionSelectByTicket(ticket))
      {
         ZeroMemory(m_result);
         m_result.retcode = TRADE_RETCODE_INVALID;
         return false;
      }

      string symbol = PositionGetString(POSITION_SYMBOL);
      double volume = PositionGetDouble(POSITION_VOLUME);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      if(posType == POSITION_TYPE_BUY)
         return SendDeal(ORDER_TYPE_SELL, volume, symbol, 0.0, 0.0, 0.0, "CLOSE_BUY", ticket);

      return SendDeal(ORDER_TYPE_BUY, volume, symbol, 0.0, 0.0, 0.0, "CLOSE_SELL", ticket);
   }

   ulong ResultOrder()
   {
      return m_result.order;
   }

   ulong ResultDeal()
   {
      return m_result.deal;
   }

   uint ResultRetcode()
   {
      return m_result.retcode;
   }

   string ResultRetcodeDescription()
   {
      return IntegerToString((int)m_result.retcode);
   }
};

CTrade trade;

// FIX3.2 - Forward declarations for unified close routing
bool RequestV4ExitOrchestrator(ulong ticket, string module, string reason, double netProfit, bool isCriticalExit, bool isSevereReversal);
bool ClosePositionV4(ulong ticket, string closeReason);
bool V10_IsMagicAccepted(long magic);
bool V10_ExitAuthority(ulong ticket, string proposedReason, string proposedFunction, string &denyReason);
void Stage17_DualSideOnTick();
bool Stage17_CanOpenPair();
bool Stage17_OpenPair();
void Stage17_UpdatePairState();
void Stage17_CompareSides();
bool Stage17_CloseWeakSide();
bool Stage17_CloseBothNoWinner();
bool Stage17_CanOpenWinnerLayer();
bool Stage17_OpenWinnerLayer();
bool Stage17_ConfirmWinnerQuality(ulong winnerTicket, string &reason, string &rawClass, string &finalClass, double &profitMoney, double &mfeMoney, double &maeMoney, double &givebackPct, double &basketProfit, bool &beActive, bool &lockActive, bool &realSLConfirmed, bool &trendAlive, bool &severeReversal);
void Stage17_UpdateLayer1State();
void Stage17_ProfitExtractionManager();
bool Stage17_PairEntryQualityGate();
bool Stage17_NoWinnerFastAbort();

input bool   UseStage17DualSideConfirmation = true;

input double Stage17_DualSideProbeLot = 0.05;
input int    Stage17_MaxActivePairs = 1;
input int    Stage17_MaxDecisionSeconds = 300;
input int    Stage17_MinSecondsBetweenPairs = 180;

input bool   Stage17_EnableCloseWeakSide = true;
input double Stage17_WeakSideMaxLossMoney = -8.0;
input int    Stage17_WeakSideMaxNoMFESeconds = 120;
input double Stage17_WeakSideMinMFEToSurvive = 3.0;

input bool   Stage17_CloseBothIfNoWinner = true;
input int    Stage17_CloseBothAfterSeconds = 420;
input double Stage17_CloseBothIfBasketBelowMoney = -12.0;

input double Stage17_StrongSideMinProfitMoney = 3.0;
input double Stage17_StrongSideMinMFEMoney = 8.0;

input bool   Stage17_RequireTrendAliveForWinner = true;
input bool   Stage17_BlockOnSevereReversal = true;
input bool   Stage17_BlockInRange = true;
input bool   Stage17_BlockInChoppy = true;

input int    Stage17_MaxSpreadPoints = 45;
input double Stage17_BlockIfDailyDDAbovePercent = 0.50;

input bool   Stage17_OnlyWinnerCanLayer = true;
input bool   Stage17_LayerOnlyAfterWeakSideClosed = true;

input double Stage17_WinnerLayer1Lot = 0.25;
input double Stage17_WinnerLayer2Lot = 0.40;

input double Stage17_Layer1_MinProfitMoney = 8.0;
input double Stage17_Layer1_MinMFEMoney = 15.0;
input double Stage17_Layer2_MinProfitMoney = 20.0;
input double Stage17_Layer2_MinMFEMoney = 45.0;

input bool   Stage17_RequireRealSLConfirmedBeforeLayer = true;
input bool   Stage17_RequireBEBeforeLayer = true;
input bool   Stage17_RequireLockOrBEBeforeLayer = true;
input bool   Stage17_BlockLayerIfBasketNegative = true;

input bool   Stage17_ForceLegacyHedgeAirbagOff = true;
input bool   Stage17_DebugLogs = true;

// STAGE17 PAIR ENTRY QUALITY PATCH:
// gate opens the BUY+SELL probe pair only when the market shows real winner/runner potential.
input bool   Stage17_EnablePairEntryQualityGate = true;
input double Stage17_MinADXForPair = 18.0;                  // HorseDetectMarketRegime: >=18 = moderate trend
input double Stage17_MinDirectionalStrengthForPair = 55.0;  // max(g_buyStrengthScore, g_sellStrengthScore)
input double Stage17_MinMomentumForPair = 35.0;             // aligned with MinMomentumScore
input double Stage17_MinDirectionGapForPair = 7.0;          // aligned with AdaptiveDirectionNeutralThresholdV4
input double Stage17_MinATRForPair = 120.0;                 // aligned with HealthyATRMinPoints
input double Stage17_MaxATRForPair = 450.0;                 // aligned with HealthyATRMaxPoints
input int    Stage17_MaxSpreadForPair = 35;                 // pair pays spread twice: tighter than Stage17_MaxSpreadPoints
input bool   Stage17_BlockPairInChoppy = true;
input bool   Stage17_BlockPairInRange = true;
input bool   Stage17_RequireRunnerPotentialForPair = true;

// STAGE17 NO WINNER FAST ABORT:
// close both probe sides early when the pair bleeds cost and no winner is being born.
input bool   Stage17_EnableNoWinnerFastAbort = true;
input int    Stage17_NoWinnerFastAbortSeconds = 150;        // faster than Stage17_MaxDecisionSeconds/CloseBothAfterSeconds
input double Stage17_NoWinnerFastAbortMaxBasketLoss = -6.0; // faster than Stage17_CloseBothIfBasketBelowMoney
input double Stage17_NoWinnerFastAbortMinMFE = 3.0;         // aligned with Stage17_WeakSideMinMFEToSurvive

const int STAGE17_PAIR_IDLE = 0;
const int STAGE17_PAIR_ACTIVE = 1;
const int STAGE17_PAIR_DECIDED_WEAK_CLOSED = 2;
const int STAGE17_PAIR_CLOSED_NO_WINNER = 3;
const int STAGE17_PAIR_FAILED = 4;
const int STAGE17_PAIR_COMPLETED = 5;

const int STAGE17_SIDE_NONE = -1;
const int STAGE17_SIDE_BUY = 0;
const int STAGE17_SIDE_SELL = 1;

struct Stage17PairControl
{
   long pairId;
   ulong buyTicket;
   ulong sellTicket;
   datetime openTime;
   int pairState;
   int winnerSide;
   int loserSide;
   bool decisionMade;
   bool weakClosed;
   bool winnerLayer1Opened;
   bool winnerLayer2Opened;
   bool weakClosedByStage17;
   bool survivorUnconfirmed;
   bool winnerConfirmed;
   ulong winnerLayer1Ticket;
   bool winnerLayer1Alive;
   bool winnerLayer1Closed;
   bool winnerLayer1Failed;
   double winnerLayer1Profit;
   double winnerLayer1MFE;
};

Stage17PairControl g_stage17Pair;
long     g_stage17NextPairId = 0;
datetime g_stage17LastPairOpenTime = 0;
datetime g_stage17LastLegacyAirbagLogTime = 0;
bool     g_stage17LegacyBlockThisTick = false;
int      g_stage17ApprovedLayerNumber = 0;
double   g_stage17ApprovedLayerLot = 0.0;

// ==================================================
// HORSE EA - PROP CHALLENGE EDITION
// ETAPA 1 - CORE BASE
// ==================================================

input string EA_Name = "HORSE EA";
input long   MagicNumber = 20260608;

input bool AllowLiveTrading = true;
input bool UseDiagnosticMode = false;
input bool PrintDetailedLogs = true;
input bool ShowDashboard = true;

// Symbol / Timeframe
input bool   RestrictToGoldSymbol = true;
input string AllowedSymbolKeyword1 = "XAUUSD";
input string AllowedSymbolKeyword2 = "GOLD";
input bool AllowM1 = true;
input bool AllowM5 = false;

// Dashboard
input int DashboardCorner = 0;
input int DashboardX = 20;
input int DashboardY = 20;
input int DashboardFontSize = 8;
input bool UseCompactDashboard = true;
input int DashboardPage = 7;
input int DashboardLineHeight = 14;

// Log Control
input int MinSecondsBetweenRepeatedLogs = 30;

// Future Risk Inputs Placeholder
input int MaxPositionsPerBasket = 3;
input double MaxLossPerTradeMoney = 200.0;
input double DailyLossLimitPercent = 1.5;

// ==================================================
// ETAPA 5 - ENTRY BASE SCORE
// ==================================================

// Spread Filter
input bool UseSpreadFilter = true;
input int MaxSpreadPoints = 45;
input int ExtremeSpreadPoints = 80;

// Session Filter
input bool UseSessionFilter = true;   // V10: ativo â€” bloqueia horas ruins (01h-04h, 17h)
input int TradingStartHour = 5;       // V10: inicia com abertura de Londres
input int TradingEndHour = 22;        // V10: encerra apÃ³s fechamento NY
input bool UseServerTimeForSession = true;

// Cooldown Filter
input bool UseCooldownFilter = true;
input int CooldownSecondsAfterBlock = 30;
input int CooldownSecondsAfterCycle = 180;

// Anti Flood Base
input bool UseAntiFloodBase = true;
input int MinSecondsBetweenActions = 10;

// Margin Diagnostic
input bool UseMarginDiagnostic = true;
input bool StrictMarginDiagnostic = false;
input double DiagnosticLotForMarginCheck = 0.01;

// Tick / Price Validation
input bool UsePriceValidation = true;
input int MaxTickAgeSeconds = 10;

// Account Safety Diagnostic
input bool UseAccountSafetyDiagnostic = true;
input double MinFreeMarginPercent = 50.0;

// ==================================================
// ETAPA 5 - ENTRY BASE SCORE
// ==================================================

// ATR Settings
input bool UseATRVolatilityEngine = true;
input int ATRPeriodM1 = 14;
input int ATRPeriodM5 = 14;
input bool UseClosedCandleForMarketAnalysis = true;

// Volatility thresholds in points
input double MinATRPointsForActiveMarket = 80.0;
input double HealthyATRMinPoints = 120.0;
input double HealthyATRMaxPoints = 450.0;
input double ExplosiveATRPoints = 650.0;
input double DangerousATRPoints = 900.0;

// Candle Analysis
input int CandleLookbackForAverageRange = 10;
input double MinCandleRangePoints = 50.0;
input double StrongCandleBodyRatio = 0.55;
input double SmallCandleBodyRatio = 0.25;
input double LargeWickRatio = 0.45;

// Market Classification
input bool UseMarketClassification = true;
input int MarketClassificationLookback = 12;
input double SidewaysRangeMultiplier = 1.20;
input double TrendRangeMultiplier = 1.80;
input double ExplosiveRangeMultiplier = 2.50;
input double ErraticWickThreshold = 0.55;

// Diagnostic Logs
input bool PrintMarketDiagnostics = true;
input int MinSecondsBetweenMarketLogs = 30;

// ==================================================
// ETAPA 5 - ENTRY BASE SCORE
// ==================================================

// Flow Engine
input bool UseFlowEngine = true;
input int FlowLookbackCandles = 5;
input bool UseClosedCandleForFlowAnalysis = true;

// Momentum / Acceleration
input int MomentumLookbackCandles = 3;
input double MinMomentumScore = 35.0;
input double StrongMomentumScore = 70.0;
input double MinAccelerationScore = 25.0;
input double StrongAccelerationScore = 65.0;

// Buy/Sell Strength
input double MinDirectionalStrength = 35.0;
input double StrongDirectionalStrength = 70.0;
input double DominanceDifferenceThreshold = 18.0;

// Rejection / Wick Logic
input bool UseRejectionAnalysis = true;
input double MinRejectionScore = 35.0;
input double StrongRejectionScore = 70.0;
input double RejectionWickRatioThreshold = 0.45;

// Imbalance Logic
input bool UseImbalanceAnalysis = true;
input double MinImbalanceScore = 30.0;
input double StrongImbalanceScore = 65.0;

// Flow Safety
input double MaxDangerousFlowScore = 75.0;
input double MaxBalancedFlowDifference = 12.0;
input bool BlockDangerousFlow = true;
input bool BlockBalancedFlow = false;
input bool StrictFlowFilter = false;

// Diagnostic Logs
input bool PrintFlowDiagnostics = true;
input int MinSecondsBetweenFlowLogs = 30;

// ==================================================
// ETAPA 5 - ENTRY BASE SCORE ENGINE
// ==================================================

input bool UseEntryBaseScoreEngine = true;
input bool EntryBaseDiagnosticOnly = true;

input double MinEntryBaseScore = 65.0;
input double StrongEntryBaseScore = 78.0;
input double ExcellentEntryBaseScore = 88.0;

input double MinBuyEntryScore = 65.0;
input double MinSellEntryScore = 65.0;
input double DirectionalAdvantageThreshold = 20.0;

input double WeightSecurityFilters = 10.0;
input double WeightATRVolatility = 15.0;
input double WeightMarketMode = 10.0;
input double WeightMarketStrength = 10.0;
input double WeightFlowQuality = 20.0;
input double WeightDirectionalStrength = 15.0;
input double WeightMomentum = 10.0;
input double WeightRejection = 5.0;
input double WeightImbalance = 5.0;

input double PenaltyHighSpread = 10.0;
input double PenaltyMarketSideways = 8.0;
input double PenaltyFlowBalanced = 10.0;
input double PenaltyWeakMomentum = 8.0;
input double PenaltyDangerousMarket = 30.0;
input double PenaltyDangerousFlow = 30.0;

input bool BlockEntryScoreWhenMarketBlocked = true;
input bool BlockEntryScoreWhenSecurityBlocked = true;
input bool BlockEntryScoreWhenFlowDangerous = true;

input bool PrintEntryScoreDiagnostics = true;
input int MinSecondsBetweenEntryScoreLogs = 30;

// ==================================================
// ETAPA 6 - ENTRY DECISION DIAGNOSTIC ENGINE
// ==================================================

input bool UseEntryDecisionEngine = true;
input bool EntryDecisionDiagnosticOnly = true;

input double MinDecisionScore = 75.0;
input double StrongDecisionScore = 80.0;
input double ExcellentDecisionScore = 90.0;

input double MinDecisionScoreDifference = 18.0;
input double StrongDecisionScoreDifference = 15.0;

input bool RequireEntryBaseOKForDecision = true;
input bool RequireFlowDirectionForDecision = true;
input bool RequireMarketTradableForDecision = true;
input bool RequireSecurityOKForDecision = true;

input bool AllowWeakFlowDecision = false;
input bool AllowBalancedDecision = false;
input bool AllowDecisionWhenDiagnosticOnly = true;

input double MaxBuySellConflictDifference = 6.0;
input bool BlockDecisionOnConflict = true;

input bool BlockDecisionWhenSpreadHigh = true;
input bool BlockDecisionWhenMarketDangerous = true;
input bool BlockDecisionWhenFlowDangerous = true;
input bool BlockDecisionWhenEntryPenaltyHigh = true;
input double MaxAllowedEntryPenaltyForDecision = 35.0;

input bool PrintEntryDecisionDiagnostics = true;
input int MinSecondsBetweenEntryDecisionLogs = 30;

// ==================================================
// ETAPA 7 - VIRTUAL ENTRY SIMULATION ENGINE
// ==================================================

input bool UseVirtualEntrySimulation = true;
input bool VirtualEntryDiagnosticOnly = true;

input bool StartVirtualEntryOnlyOnValidDecision = true;
input bool AllowVirtualEntryOnDiagnosticDecision = true;
input bool AllowVirtualBuySimulation = true;
input bool AllowVirtualSellSimulation = true;

input bool UseATRVirtualStops = true;
input double VirtualSL_ATR_Multiplier = 1.20;
input double VirtualTP_ATR_Multiplier = 1.80;
input double FixedVirtualSLPoints = 250.0;
input double FixedVirtualTPPoints = 400.0;
input double MinVirtualSLPoints = 120.0;
input double MaxVirtualSLPoints = 600.0;
input double MinVirtualTPPoints = 150.0;
input double MaxVirtualTPPoints = 900.0;

input double VirtualLotForMoneySimulation = 0.01;
input bool UseSymbolTickValueForVirtualMoney = true;

input int MaxVirtualEntrySeconds = 300;
input int MaxVirtualEntryBars = 5;

input bool InvalidateVirtualEntryOnOppositeFlow = true;
input bool InvalidateVirtualEntryOnDangerousFlow = true;
input bool InvalidateVirtualEntryOnMarketDanger = true;
input bool InvalidateVirtualEntryOnEntryDecisionFlip = true;
input bool CancelVirtualEntryOnSecurityBlock = true;

input bool OneVirtualEntryAtATime = true;
input bool PreventMultipleVirtualEntriesSameCandle = true;
input int CooldownSecondsAfterVirtualEntryEnd = 60;

input bool PrintVirtualEntryDiagnostics = true;
input int MinSecondsBetweenVirtualEntryLogs = 30;

// ==================================================
// ETAPA 8 - PRE-EXECUTION RISK GATE ENGINE
// ==================================================

input bool UsePreExecutionRiskGate = true;
input bool PreExecutionDiagnosticOnly = true;

input double MinPreExecutionScore = 72.0;
input double StrongPreExecutionScore = 82.0;
input double ExcellentPreExecutionScore = 92.0;

input bool RequireVirtualEntryConfirmation = true;
input bool RequireVirtualEntryWinForApproval = false;
input bool AllowActiveVirtualEntryForApproval = true;
input bool AllowTimeoutVirtualEntryIfProfitable = true;
input double MinVirtualResultScoreForApproval = 60.0;
input double MinVirtualRRForApproval = 1.20;

input bool RequireValidEntryDecisionForPreExecution = true;
input bool RequireEntryDecisionDirectionMatch = true;
input bool RequireEntryBaseForPreExecution = true;

input bool UseFixedEstimatedLot = true;
input double FixedEstimatedLot = 0.01;
input bool UseRiskPercentEstimatedLot = false;
input double EstimatedRiskPercentPerTrade = 0.20;
input double MaxPreExecutionRiskPercent = 0.35;
input double MaxPreExecutionRiskMoney = 350.0;

input bool UseDailyRiskPreCheck = true;
input double MaxDailyRiskPercentPreCheck = 1.50;
input double MaxDailyEstimatedLossMoney = 1500.0;
input double MinEquityProtectionPercent = 98.50;

input bool UseSpreadCostPreCheck = true;
input double MaxEstimatedSpreadCostMoney = 35.0;
input double CommissionBufferPerLot = 7.0;

input bool UseMarginPreExecutionCheck = true;
input double MinFreeMarginAfterEstimatedTradePercent = 40.0;
input double MinMarginLevelForPreExecution = 300.0;

input bool BlockIfVirtualLoss = true;
input bool BlockIfVirtualInvalidated = true;
input bool BlockIfVirtualCancelled = false;
input bool BlockIfVirtualTimeoutNegative = true;
input bool BlockIfRiskScoreLow = true;
input bool BlockIfRRTooLow = true;

input bool PrintPreExecutionDiagnostics = true;
input int MinSecondsBetweenPreExecutionLogs = 30;

// ==================================================
// ETAPA 9 - EXECUTION DRY-RUN / PERMISSION ENGINE
// ==================================================
input bool UseExecutionDryRun = true;
input bool ExecutionDryRunDiagnosticOnly = true;
input double MinDryRunScore = 75.0;
input double StrongDryRunScore = 85.0;
input double ExcellentDryRunScore = 93.0;
input bool RequirePreExecutionApprovedForDryRun = true;
input bool RequireValidDecisionForDryRun = true;
input bool RequireVirtualEntryForDryRun = true;
input bool RequireSecurityForDryRun = true;
input bool RequireMarketForDryRun = true;
input bool RequireFlowForDryRun = true;
input bool AllowDryRunBuy = true;
input bool AllowDryRunSell = true;
input bool RequireDirectionMatchAcrossEngines = true;
input bool UseDryRunDuplicateProtection = true;
input bool PreventDryRunSameCandle = true;
input int MinSecondsBetweenDryRunApprovals = 60;
input bool UseDryRunRiskPermission = true;
input double MaxDryRunRiskMoney = 350.0;
input double MaxDryRunRiskPercent = 0.35;
input double MaxDryRunSpreadCostMoney = 35.0;
input double MinDryRunRR = 1.10;
input bool BlockDryRunIfPreExecutionBlocked = true;
input bool BlockDryRunIfRiskDanger = true;
input bool BlockDryRunIfVirtualLoss = true;
input bool BlockDryRunIfVirtualInvalidated = true;
input bool BlockDryRunIfDecisionConflict = true;
input bool BlockDryRunIfFlowDangerous = true;
input bool BlockDryRunIfMarketDangerous = true;
input bool PrintExecutionDryRunDiagnostics = true;
input int MinSecondsBetweenDryRunLogs = 30;

// ==================================================
// ETAPA 12 FIX2 - EXECUTION DIAGNOSTIC OVERRIDE / FIRST REAL ORDER
// ==================================================
input bool UseRealExecutionEngine = true;
input bool EnableRealExecution = true;
input bool RealExecutionSimulationOnly = false;
input bool AllowRealExecutionInDiagnosticMode = false;

input bool RequireDryRunApprovedForRealExecution = true;
input bool RequirePreExecutionApprovedForRealExecution = true;
input bool RequirePlannedOrderForRealExecution = true;
input bool UsePlannedLotForRealExecution = true;
input bool UsePlannedSLTPForRealExecution = true;
input bool UseCurrentBidAskForRealEntry = true;
input bool RevalidateSLTPAgainstCurrentPrice = true;

input bool AllowRealBuyExecution = true;
input bool AllowRealSellExecution = true;
input bool RequireDryRunDirectionForRealExecution = true;

input bool UseRealExecutionRiskCheck = true;
input double MaxRealExecutionRiskMoney = 10.0;
input double MaxRealExecutionRiskPercent = 0.01;
input double MinRealExecutionRR = 1.00;
input double MaxRealExecutionLot = 0.08;   // V5.1G Etapa1: entrada principal
input double MinRealExecutionLot = 0.08;   // V5.1G Etapa1: entrada principal fixa 0.08

input bool UseRealExecutionDuplicateProtection = true;
input bool BlockIfAnyPositionOpenSameSymbolMagic = true;
input bool BlockIfAnyPendingOrderSameSymbolMagic = true;
input bool PreventRealExecutionSameCandle = true;
input int MinSecondsBetweenRealExecutions = 300;
input int MaxRealExecutionAttemptsPerSignal = 1;
input bool BlockRealExecutionAfterFailedAttempt = true;

input bool UseBrokerStopLevelValidation = true;
input bool UseBrokerFreezeLevelValidation = true;
input bool UseRealMarginCheck = true;
input bool UseRealSpreadCheck = true;
input int MaxRealExecutionSpreadPoints = 70;
input int MaxRealExecutionSlippagePoints = 30;

input string RealExecutionComment = "HORSE EA";
input int RealExecutionDeviationPoints = 30;
input bool UseServerSideSLTP = true;

input bool CloseNothingInStage10 = true;
input bool ModifyNothingInStage10 = true;
input bool DisableRealExecutionAfterOneTrade = true;

input bool PrintRealExecutionDiagnostics = true;
input int MinSecondsBetweenRealExecutionLogs = 10;

// ==================================================
// STAGE 12 FIX2 - EXECUTION DIAGNOSTIC OVERRIDE
// Aggressive safe functional test mode. Default OFF keeps old behavior.
// ==================================================
input bool   ForceFunctionalExecutionTest                 = false;
input bool   ForceFunctionalIgnoreEntryDiagnostic         = true;
input bool   ForceFunctionalIgnorePreExecutionDiagnostic  = true;
input bool   ForceFunctionalIgnoreDryRunDiagnostic        = true;
input bool   ForceFunctionalAllowRealExecution            = true;
input bool   ForceFunctionalAllowLayerExecution           = true;
input bool   ForceFunctionalKeepSpreadProtection          = true;
input bool   ForceFunctionalKeepMarginProtection          = true;
input bool   ForceFunctionalKeepStopLevelProtection       = true;
input bool   ForceFunctionalKeepExposureProtection        = true;
input bool   ForceFunctionalKeepNoHedgeProtection         = true;
input bool   ForceFunctionalKeepNoMartingaleProtection    = true;
input bool   ForceFunctionalKeepDailyRiskProtection       = true;
input int    ForceFunctionalMaxTotalPositions             = 3;
input double ForceFunctionalFixedLot                      = 0.01;
input double ForceFunctionalMaxSymbolExposureLots         = 0.03;
input double ForceFunctionalMaxLayerExposureLots          = 0.03;
input bool   ForceFunctionalAggressiveEntryCycle          = true;
input bool   ForceFunctionalAllowManySequentialTrades     = true;
input int    ForceFunctionalMaxDirectionalLayers          = 2;
input int    ForceFunctionalMaxTradesPerDay               = 200;
input int    ForceFunctionalMinSecondsBetweenCycles       = 1;
input bool   ForceFunctionalAllowSameCandleNewCycle       = true;
input bool   ForceFunctionalRearmAfterPositionClose       = true;
input int    ForceFunctionalRearmSecondsAfterClose        = 1;
input bool   ForceFunctionalBuildPlanFromDryRun           = true;
input bool   ForceFunctionalBuildPlanFromEntryDecision    = true;
input bool   ForceFunctionalExecuteImmediatelyAfterDryRun = true;


// ==================================================
// ETAPA 12 FIX2 - EXECUTION DIAGNOSTIC OVERRIDE / SMART POSITION CONTROL
// ==================================================
input bool UsePositionManager = true;
input bool EnablePositionManagerActions = true;   // V10: ERA false â€” ativado para BE e trailing reais
input bool PositionManagerSimulationOnly = false; // V10: ERA true â€” desativado, aÃ§Ãµes reais agora
input bool AllowPositionModify = true;            // V10: ERA false â€” permite modificar SL/TP
input bool AllowPositionManagerInDiagnosticMode = false;

input bool ManageOnlyCurrentSymbol = true;
input bool ManageOnlyMagicNumber = true;
input bool ManageOnlyOnePosition = true;
input bool IgnoreOtherManualPositions = true;

input bool UseBreakEvenEngine = true;
input bool AllowBreakEvenModify = true;
input double BreakEvenTriggerPoints = 120.0;  // V10: era 180 â†’ mais rÃ¡pido â€” BE ativa em 120pts
input double BreakEvenOffsetPoints  = 15.0;   // V10: era 20 â†’ buffer menor, BE mais justo
input bool BreakEvenOnlyOnce = true;

input bool UseSmartTrailingStop = true;
input bool AllowTrailingModify = true;
input double TrailingStartPoints    = 150.0;  // V10: era 250 â†’ trailing comeÃ§a mais cedo
input double TrailingDistancePoints = 120.0;  // V10: era 180 â†’ distÃ¢ncia menor, protege mais
input double TrailingStepPoints     = 25.0;   // V10: era 40 â†’ passo menor, trailing mais suave
input bool TrailOnlyAfterBreakEven  = true;   // Trailing sÃ³ apÃ³s BE = correto

input bool UseProfitProtection = true;
input double ProfitProtectionTriggerMoney = 5.0;
input double ProfitProtectionMinLockMoney = 1.0;
input double ProfitRetraceClosePercent = 60.0;
input bool AllowProfitProtectionClose = false;

input bool UseEmergencyPositionProtection = true;
input bool AllowEmergencyPositionClose = false;
input double MaxPositionLossMoney = 10.0;
input double MaxPositionLossPercent = 0.01;
input double MaxPositionAdversePoints = 600.0;

input bool UsePositionTimeProtection = false;
input int MaxPositionMinutes = 120;
input bool AllowTimeBasedClose = false;

input bool RequirePositionSL = true;
input bool RequirePositionTP = true;
input bool RepairMissingSLTP = false;
input bool AllowSLTPRepairModify = false;

input bool ValidateStopsBeforeModify = true;
input bool ValidateFreezeBeforeModify = true;
input int PositionModifyDeviationPoints = 30;

input bool PrintPositionManagerDiagnostics = true;
input int MinSecondsBetweenPositionLogs = 10;

// Visual / Audit State Hold
input bool UsePositionManagerStateHold = true;
input int PositionManagerStateHoldSeconds = 8;

// ==================================================
// FIX3 V3.1 - SMART EXIT REAL ENGINE
// ==================================================
input bool   UseSmartExitRealEngine              = true;
input bool   SmartExitSimulationOnly             = false;
input bool   AllowSmartExitRealModify            = true;
input bool   AllowSmartExitRealClose             = true;

input bool   UseBreakEvenReal                    = true;
input bool   BreakEvenRequirePositiveProfit      = true;

input bool   UseSmartTrailingReal                = true;
input bool   TrailNeverWidenStop                 = true;

input bool   UseATRDynamicExit                   = true;
input int    ExitATRPeriod                       = 14;
input double ATRDynamicTPMultiplier              = 1.50;
input int    MinDynamicTPPoints                  = 180;
input int    MaxDynamicTPPoints                  = 650;
input int    MinTPModifyDifferencePoints         = 30;

input bool   UseProfitProtectionReal             = true;

input bool   UseBasketSmartClose                 = true;
input bool   AllowBasketSmartClose               = false;
input double BasketProfitTargetMoney             = 8.00;
input double BasketMinProfitToProtectMoney       = 4.00;
input double BasketMaxProfitRetracePercent       = 55.0;
input double BasketEmergencyLossMoney            = -15.00;
input bool   AllowBasketEmergencyClose           = false;

input bool   UseWeaknessExit                     = true;
input bool   AllowWeaknessExitClose              = false;
input int    WeaknessLookbackCandles             = 3;
input int    WeaknessMinProfitPoints             = 80;
input int    WeaknessCloseIfAgainstPoints        = 220;
input bool   WeaknessExitOnlyIfBasketPositive    = true;

input int    MinSecondsBetweenPositionModifies   = 3;
input int    MinSecondsBetweenSmartCloses        = 3;
input int    MaxPositionModifyRetries            = 2;


// =====================================================
// FIX3 V3.2 - ENTRY QUALITY + PROFIT DISTRIBUTION RUNNER
// =====================================================
input bool UseV32EntryQualityProfitDistribution = true;
input bool V32_GlobalDiagnosticOnly             = false;
input bool V32_AllowRealEntryBlocking           = false;
input bool V32_AllowRealProfitDistributionClose = false;
input bool V32_AllowRunnerRealManagement        = true;

input bool   UseEntryQualityV32                  = true;
input bool   EntryQualityV32_DiagnosticOnly      = true;
input double MinEntryQualityV32                  = 65.0;
input double StrongEntryQualityV32               = 78.0;
input double ExcellentEntryQualityV32            = 88.0;
input double WeightTrendAlignmentV32             = 25.0;
input double WeightMomentumV32                   = 20.0;
input double WeightVolatilityV32                 = 15.0;
input double WeightCandleConfirmationV32         = 15.0;
input double WeightAntiRangeV32                  = 15.0;
input double WeightSpreadCostV32                 = 10.0;

input bool UseMTFTrendFilterV32                  = true;
input bool MTFTrendFilterV32_DiagnosticOnly      = true;
input ENUM_TIMEFRAMES TrendTF1                   = PERIOD_M5;
input ENUM_TIMEFRAMES TrendTF2                   = PERIOD_M15;
input int  TrendEMA_Fast                         = 9;
input int  TrendEMA_Medium                       = 21;
input int  TrendEMA_Slow                         = 50;
input int  TrendADXPeriod                        = 14;
input double MinTrendADXV32                      = 18.0;
input double StrongTrendADXV32                   = 25.0;

input bool UseAntiOvertradeV32                   = true;
input bool AntiOvertradeV32_DiagnosticOnly       = true;
input int  MaxTradesPer100Candles                = 60;
input int  MaxCyclesPer100Candles                = 25;
input int  MinSecondsBetweenNewCyclesV32         = 10;
input int  MaxConsecutiveLossesBeforePauseV32    = 6;
input int  PauseMinutesAfterLossStreakV32        = 15;
input bool ReduceTradingInRangeV32               = true;

input bool UseDirectionalBiasControlV32              = true;
input bool DirectionalBiasControlV32_DiagnosticOnly  = true;
input double MaxBuySellRatioV32                      = 2.20;
input int BiasLookbackTradesV32                      = 200;
input bool BlockNewBuyIfBuyBiasExtremeV32            = true;
input bool BlockNewSellIfSellBiasExtremeV32          = true;

input bool UseMarketRegimeFilterV32              = true;
input bool MarketRegimeFilterV32_DiagnosticOnly  = true;
input int  RegimeATRPeriodV32                    = 14;
input double MinHealthyATRPointsV32              = 70.0;
input double MaxDangerATRPointsV32               = 1200.0;
input int  RangeLookbackCandlesV32               = 30;
input double MaxRangeCompressionRatioV32         = 0.45;
input bool BlockChoppyMarketV32                  = true;
input bool BlockExtremeVolatilityV32             = true;

// =====================================================
// V3.2 - BALANCED RELAXED / CHOPPY MARKET BYPASS
// =====================================================
input bool   UseBalancedRelaxedV32                    = true;
input bool   AllowHighQualityEntryInChoppyMarketV32   = true;
input double MinQualityToBypassChoppyV32              = 68.0;
input double MaxRangeCompressionRatioRelaxedV32       = 0.25;
input int    MaxChoppyBypassTradesPer100CandlesV32    = 35;
input int    MinSecondsBetweenChoppyBypassV32         = 5;
input bool   BlockExtremeChoppyEvenWithHighScoreV32   = true;
input bool   RequireAntiOvertradeOkForChoppyBypassV32 = true;
input bool   RequireSpreadOkForChoppyBypassV32        = true;
input bool   RequireHealthyATRForChoppyBypassV32      = true;
input bool   BlockStrongAgainstTrendBypassV32         = true;

// =====================================================
// V3.2 â€” BALANCED RELAXED FIX1 / SCORE 70 + BIAS + TREND BONUS
// =====================================================
input double StrongQualityToBypassChoppyV32           = 72.0;
input double MinQualityForCompressedRangeV32          = 70.0;
input double MinQualityForModerateRangeV32            = 68.0;
input double ExtremeCompressionBlockV32               = 0.15;
input double ModerateCompressionBypassV32             = 0.25;
input bool   DebugBypassChoppyAlwaysLogV32            = true;
input int    MinTradesBeforeBiasBlockV32              = 8;
input int    MinSameDirectionTradesForBiasV32         = 4;
input double MaxBuySellRatioRelaxedV32                = 3.00;
input bool   AllowBiasBypassWhenTrendAlignedV32       = true;

input bool UseLayerQualityGateV32                = true;
input bool LayerQualityGateV32_DiagnosticOnly    = true;
input double MinLayerQualityScoreV32             = 68.0;
input bool RequireMainPositionNotDeepNegativeV32 = true;
input double MaxMainAdverseMoneyForLayerV32      = 3.00;
input int MaxMainAdversePointsForLayerV32        = 280;
input bool RequireTrendStillAlignedForLayerV32   = true;
input bool RequireNoExtremeSpreadForLayerV32     = true;

input bool UseProfitDistributionV32              = true;
input bool ProfitDistributionV32_DiagnosticOnly  = true;
input bool AllowProfitDistributionRealCloseV32   = false;
input double MainTargetMoneyV32                  = 2.50;
input double Layer1TargetMoneyV32                = 5.00;
input double RunnerTargetMoneyV32                = 12.00;
input int MainTargetPointsV32                    = 120;
input int Layer1TargetPointsV32                  = 220;
input int RunnerTargetPointsV32                  = 450;
input bool CloseMainAtSmallProfitV32             = true;
input bool CloseLayer1AtMediumProfitV32          = true;
input bool LetRunnerRunV32                       = true;

input bool UseRunnerEngineV32                    = true;
input bool RunnerEngineV32_DiagnosticOnly        = false;
input bool AllowRunnerRealModifyV32              = true;
input int RunnerTrailingStartPointsV32           = 260;
input int RunnerTrailingDistancePointsV32        = 520;
input int RunnerTrailingStepPointsV32            = 60;
input int RunnerBreakEvenTriggerPointsV32        = 160;
input int RunnerBreakEvenOffsetPointsV32         = 30;
input double RunnerMinProfitMoneyToProtectV32    = 4.00;
input double RunnerProfitRetracePercentV32       = 50.0;
input double RunnerPromotionMinProfitPointsV32   = 180.0;
input double RunnerPromotionMinADXV32            = 21.0;
input double RunnerATRMultV32                    = 3.20;
input double StrongRunnerATRMultV32              = 3.80;
input double ExceptionalRunnerATRMultV32         = 4.50;

input bool UseAdaptiveBasketCloseV32             = true;
input bool AdaptiveBasketCloseV32_DiagnosticOnly = true;
input bool AllowAdaptiveBasketCloseRealV32       = false;
input double BasketTargetSmallV32                = 4.00;
input double BasketTargetMediumV32               = 8.00;
input double BasketTargetStrongV32               = 15.00;
input double BasketRunnerModeTargetV32           = 20.00;
input bool HoldBasketLongerIfRunnerStrongV32     = true;
input double MinBasketProfitToHoldRunnerV32      = 5.00;



// ==================================================
// ETAPA 12 FIX2 - EXECUTION DIAGNOSTIC OVERRIDE
// ==================================================

// Master
input bool UseReentryLayerEngine = true;
input bool EnableLayerExecution = true;   // PATCH_LAYER_010_025_040: permitir execuÃ§Ã£o real de camadas quando demais gates aprovarem
input bool LayerSimulationOnly = false;   // PATCH_LAYER_010_025_040: sair do modo simulaÃ§Ã£o
input bool AllowLayerOrders = true;   // PATCH_LAYER_010_025_040: permitir envio real de ordens de layer
input bool AllowLayerInDiagnosticMode = false;

// Layer Direction
input bool AllowBuyLayers = true;
input bool AllowSellLayers = true;
input bool LayerOnlySameDirectionAsMainPosition = true;
input bool BlockOppositeLayerDirection = true;

// Layer Limits
input int MaxTotalLayers = 2;   // PATCH_LAYER_010_025_040: somente Layer 1 + Layer 2; main nÃ£o conta como camada
input int MaxLayersPerDirection = 2;   // PATCH_LAYER_010_025_040: mÃ¡ximo 2 camadas por direÃ§Ã£o
input bool CountMainPositionAsLayer = false;   // PATCH_LAYER_010_025_040: permitir main + 2 camadas
input bool DisableLayerAfterOneSuccess = false;   // PATCH_LAYER_010_025_040: nÃ£o bloquear Layer 2 apÃ³s Layer 1

// Lot Control
input bool UseFixedLayerLot = true;
input double FixedLayerLot = 0.40;   // fallback legado; PATCH_LAYER_010_025_040 usa lote por Ã­ndice
input double Layer1LotByIndex = 0.25;   // PATCH_LAYER_010_025_040: lote Layer 1
input double Layer2LotByIndex = 0.40;   // PATCH_LAYER_010_025_040: lote Layer 2
input bool AllowLayerOnProfit = true;   // PATCH_LAYER_010_025_040: scale em lucro
input bool AllowControlledPullbackLayer = true;   // PATCH_LAYER_010_025_040: reentrada em pullback controlado
input double MaxFloatingLossMoneyForPullbackLayer1 = 15.0;   // PATCH_LAYER_010_025_040
input double MaxBasketFloatingLossMoneyForLayer2 = 25.0;   // PATCH_LAYER_010_025_040
input double MinScoreLayer1 = 75.0;   // PATCH_LAYER_010_025_040
input double MinScoreLayer2 = 85.0;   // PATCH_LAYER_010_025_040
input double MinScorePullbackLayer1 = 80.0;   // PATCH_LAYER_010_025_040
input double MaxTotalLayerLotsPerDirection = 0.75;   // PATCH_LAYER_010_025_040: main + L1 + L2
input double MaxLayerLot = 0.40;   // teto do Layer 2
input double MinLayerLot = 0.01;
input bool UseLayerLotMultiplier = false;
input double LayerLotMultiplier = 1.0;
input bool BlockMartingaleLotIncrease = true;   // PATCH_LAYER_010_025_040: bloquear martingale oculto

// Distance Control
input bool UseMinLayerDistance = true;
input double MinLayerDistancePoints = 180.0;
input double MinLayerDistanceATRMultiplier = 0.80;
input bool UseATRLayerDistance = true;

// Profit / Protection Conditions
input bool RequireMainPositionProfitForLayer = true;
input double MinMainPositionProfitMoneyForLayer = 5.00;   // PATCH_LAYER_010_025_040: lucro mÃ­nimo real antes de scale em lucro
input double MinMainPositionProfitPointsForLayer = 80.0;
input bool RequireBreakEvenBeforeLayer = true;
input bool RequireTrailingBeforeLayer = false;
input bool BlockLayerIfMainPositionNegative = false;   // PATCH_LAYER_010_025_040: pullback controlado permitido por regra prÃ³pria
input double MaxMainPositionLossMoneyForLayer = 15.00;   // PATCH_LAYER_010_025_040: pullback controlado mÃ¡ximo
input double MaxMainPositionAdversePointsForLayer = 120.0;

// Signal Confirmation
input bool RequireFlowConfirmationForLayer = true;
input double MinFlowStrengthForLayer = 58.0;
input double MinEntryScoreForLayer = 75.0;   // PATCH_LAYER_010_025_040: score mÃ­nimo Layer 1
input bool RequireSameDryRunDirectionForLayer = true;
input bool RequirePreExecutionApprovedForLayer = true;

// Risk Control
input bool UseLayerRiskControl = true;
input double MaxLayerRiskMoney = 210.0;   // V5.1G: teto ~200 USD/op + folga
input double MaxLayerRiskPercent = 0.25;   // PATCH_LAYER_010_025_040: 0.25% por layer, evitando bloqueio por 0.005%
input double MaxTotalLayerExposureLots = 0.65;   // PATCH_LAYER_010_025_040: Layer1 0.25 + Layer2 0.40
input double MaxTotalSymbolExposureLots = 0.75;   // PATCH_LAYER_010_025_040: Main 0.10 + 0.25 + 0.40
input bool BlockLayerIfEquityDrawdown = true;
input double MaxEquityDrawdownPercentForLayer = 1.0;

// SL/TP Control
input bool UseLayerOwnSLTP = true;
input bool UseMainPositionSLTPForLayer = false;
input double LayerSL_ATR_Multiplier = 1.00;
input double LayerTP_ATR_Multiplier = 1.40;
input double MinLayerRR = 1.00;
input bool RevalidateLayerSLTP = true;
input bool UseServerSideLayerSLTP = true;

// Broker / Execution Safety
input bool UseLayerSpreadFilter = true;
input double MaxLayerSpreadPoints = 60.0;
input bool UseLayerMarginCheck = true;
input bool UseLayerStopLevelValidation = true;
input bool UseLayerFreezeLevelValidation = true;
input int LayerDeviationPoints = 30;
input int MinSecondsBetweenLayers = 300;
input bool PreventLayerSameCandle = true;

// Account Mode Safety
input bool RequireHedgingAccountForRealLayers = true;
input bool BlockRealLayerOnNettingAccount = true;

// Logs
input bool PrintLayerDiagnostics = true;
input int MinSecondsBetweenLayerLogs = 10;
input string LayerOrderComment = "HORSE EA LAYER";




// ==================================================
// HORSE EA - FIX3 SMART EXIT RUNNER CALIBRATION ENGINE
// Primary decision engine + Legacy override + Smart exit + Runner
// ==================================================

input bool UseV4AsPrimaryDecisionEngine = true;
input bool UseV4AuditMode = true;
input bool UseV4DirectPlanBuilder = true;
input bool UseAggressiveResultEngineV4 = true;
input bool UseMainLayerRunnerV4 = true;
input bool UseBigRunnerV4 = true;
input bool UseControlledSLV4 = true;
input bool UseSmartProfitPotentialExitV4 = true;
input bool UseLossStreakControlV4 = true;
input bool UseProfitGivebackExitV4 = true;
input bool UseTimeNoProgressExitV4 = true;
input bool BlockSameDirectionAfterSmartExitV4 = true;

input double PropBaseLotV4        = 0.08;   // V5.1N: entrada principal (MAIN)
input double PropLayerLotV4       = 0.40;   // V7: reentrada 0.40 lot
input double PropRunnerLotV4      = 0.40;   // V5.1N: 2a+ reentrada (LAYER_2/runner)
input double PropMaxExposureLotV4 = 1.20;   // V7: cobre MAIN(0.08)+LAYER(0.40)+RUNNER(0.40) com folga

input double SmallWinMoneyV4   = 25.0;
input double MediumWinMoneyV4  = 85.0;
input double BigWinMoneyV4     = 250.0;
input double RunnerWinMoneyV4  = 550.0;

input double MainSLMoneyV4   = -45.0;
input double LayerSLMoneyV4  = -90.0;
input double RunnerSLMoneyV4 = -140.0;
input double BasketEmergencySLMoneyV4 = -280.0;

input double DemoBaseLotV4        = 0.10;
input double DemoLayerLotV4       = 0.10;
input double DemoRunnerLotV4      = 0.10;
input double DemoMaxExposureLotV4 = 0.30;

input double DemoSmallWinMoneyV4   = 80.0;
input double DemoMediumWinMoneyV4  = 180.0;
input double DemoBigWinMoneyV4     = 450.0;
input double DemoRunnerWinMoneyV4  = 850.0;
input double DemoSmallLossMoneyV4      = -80.0;
input double DemoControlledLossMoneyV4 = -180.0;
input double DemoEmergencyLossMoneyV4  = -350.0;

input double MinAggressiveEntryScoreV4 = 68.0;
input double StrongAggressiveEntryScoreV4 = 75.0;
input double PriorityAggressiveEntryScoreV4 = 82.0;
input double BlockAggressiveEntryBelowScoreV4 = 60.0;
input double AdaptiveDirectionNeutralThresholdV4 = 7.0;   // diferenÃ§a mÃ­nima entre BUY_SCORE e SELL_SCORE; abaixo disso = NO_TRADE
input double AdaptiveDirectionMinValidScoreV4 = 30.0;     // se ambos os lados ficarem abaixo disso = NO_TRADE
input bool UseAdaptiveDirectionNoTradeV4 = true;          // nunca escolher BUY/SELL por fallback em cenÃ¡rio neutro

input int MainSLPointsV4   = 250;
input int LayerSLPointsV4  = 350;
input int RunnerSLPointsV4 = 500;
input int MainTPPointsV4   = 250;
input int LayerTPPointsV4  = 550;
input int RunnerTPPointsV4 = 1200;
input int MaxPositionsV4 = 4;   // V5.1M: teto de 4 posicoes (stop-and-reverse)

input int RunnerStartProtectPointsV4 = 400;
input int RunnerTrailDistancePointsV4 = 300;
input int RunnerTrailStepPointsV4 = 80;
input double RunnerPeakGivebackPercentV4 = 40.0;
input double RunnerProtectBigProfitV4 = 120.0;

input double MinProfitPotentialScoreV4 = 62.0;
input double EmergencyNoPotentialScoreV4 = 40.0;  // AUDIT FIX: 30â†’40 â€” evita saÃ­da por queda momentÃ¢nea de score
input int MaxCandlesWithoutProgressV4 = 3;
input int MaxSecondsWithoutProgressV4 = 180;
input double MaxProfitGivebackPercentV4 = 45.0;
input double CloseNoPotentialLossMoneyV4 = -35.0; // AUDIT FIX: -25â†’-35 â€” nÃ£o fechar antes do SL real
input double CloseNoPotentialProfitMoneyV4 = -8.0;  // AUDIT FIX: -2â†’-8 â€” nÃ£o fechar na zona de spread noise
input int MainMinHoldSecondsBeforeSmartExitV4   = 150;
input int LayerMinHoldSecondsBeforeSmartExitV4  = 45;
input int RunnerMinHoldSecondsBeforeSmartExitV4 = 240;
input int MainMaxCandlesWithoutProgressV4 = 2;
input double MainCloseNoPotentialLossV4 = -35.0;   // AUDIT FIX: -25â†’-35 â€” MAIN nÃ£o fecha no ruÃ­do de spread
input double MainProtectSmallProfitV4 = 10.0;
input int LayerMaxCandlesWithoutProgressV4 = 3;
input double LayerCloseNoPotentialLossV4 = -55.0;
input double LayerProtectProfitV4 = 25.0;
input double RunnerEmergencyNoPotentialScoreV4 = 40.0;
input int RunnerMinTrendHoldSecondsV4 = 180;
input double RunnerCloseNoPotentialLossV4 = -90.0;
input int MaxSpreadForSmartExitV4 = 60;
input int CooldownAfterNoPotentialCloseSecondsV4 = 180;
input int MinSecondsBetweenCloseAttemptsV4 = 10;

input double MinProfitToActivateGivebackV4 = 15.0;
input double MainMaxGivebackPercentV4 = 35.0;
input double LayerMaxGivebackPercentV4 = 40.0;
input double RunnerMaxGivebackPercentV4 = 45.0;
input int  MaxSecondsMainNoProgressV4 = 120;
input int  MaxSecondsLayerNoProgressV4 = 180;
input int  MaxSecondsRunnerNoProgressV4 = 300;
input int MainMinProgressPointsV4   = 80;
input int LayerMinProgressPointsV4  = 120;
input int RunnerMinProgressPointsV4 = 180;
input double MainMinProgressMoneyV4   = 8.0;
input double LayerMinProgressMoneyV4  = 15.0;
input double RunnerMinProgressMoneyV4 = 25.0;

input int MaxLossStreakV4 = 6;
input int LossStreakPauseMinutesV4 = 5;
input bool AllowHighQualityAfterLossStreakV4 = true;
input double MinScoreAfterLossStreakV4 = 78.0;
input bool ResetLossStreakAfterNoTradesWindowV4 = true;
input int ResetLossStreakNoTradesMinutesV4 = 30;
input string RealExecutionCommentV4 = "HORSE EA";

// ==================================================
// FIX2 - Minimal Robust Filter Engine controls
// ==================================================
input bool UseNewsFilter = true;  // V10: ativo â€” PCE, GDP, NFP bloqueados automaticamente
input bool UseLegacyFilterOverrideV4 = true;
input bool UseSmartExitV4 = true;
input bool UseRunnerV4 = true;
input bool UseExitOrchestratorV4 = true;
input bool UseResultClassificationV4 = true;
input bool UseV4FinalReasonValidation = true;


// ==================================================
// FIX3 - Smart Exit & Runner Calibration Engine controls
// Exit-only update. Do NOT change FIX2 entry logic.
// ==================================================
input bool   UseRunnerBreakEvenV4             = true;
input double RunnerBreakEvenStartMoneyV4      = 25.0;
input double RunnerBreakEvenLockMoneyV4       = 3.0;
input bool   UseRunnerProfitPeakTrailV4       = true;
input double RunnerMinPeakToTrailMoneyV4      = 80.0;
input double RunnerGivebackPercentV4          = 65.0;
input int    SmartExitMinConfirmationsV4      = 5;    // AUDIT: mantido em 5 â€” combinado com EmergencyScore=40 protege melhor

// â”€â”€ V8: DYNAMIC ZONE TP ENGINE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Sistema de saÃ­da por zonas de lucro â€” substitui SmartExit reativo.
// Cada zona tem regra prÃ³pria de trailing e proteÃ§Ã£o.
input double V8_Zone0MaxMoney   = 3.50;  // Zona morta: spread. NUNCA fechar aqui.
input double V8_Zone1MaxMoney   = 10.0;  // Micro scalp $3.5-$10: sÃ³ reversÃ£o severa
input double V8_Zone2MaxMoney   = 30.0;  // Scalp bom $10-$30: trailing ATR 1.5x
input double V8_Zone3MaxMoney   = 100.0; // Swing $30-$100: trailing ATR 2.0x + runner nasce
// Zona 4: acima de Zone3MaxMoney = RUNNER, trailing ATR 3.0x, ilimitado
input double V8_Zone2MinScore   = 25.0;  // Score mÃ­nimo para manter na zona 2

// â”€â”€ V9: CHANDELIER EXIT ADAPTATIVO â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// SL = Peak_profit - (N Ã— ATR_atual). Nunca desce. Protege lucro de forma inteligente.
// N varia conforme o lucro cresce â€” quanto maior o runner, mais fÃ´lego ele tem.
input bool   V9_UseChandelierExit          = true;   // Ativar Chandelier Exit V9
input double V9_ChandelierN_Zone1          = 1.5;    // $3.50-$10:  SL = peak - 1.5Ã—ATR
input double V9_ChandelierN_Zone2          = 2.0;    // $10-$30:    SL = peak - 2.0Ã—ATR
input double V9_ChandelierN_Zone3          = 3.0;    // $30-$100:   SL = peak - 3.0Ã—ATR
input double V9_ChandelierN_Zone4          = 5.0;    // V10: era 4.0 â†’ 5.0Ã—ATR (runner grande)
// V10: Zona 5 â€” BIG_RUNNER acima de Stage15_BigRunnerMinMoney ($150+)
input double V9_ChandelierN_BigRunner      = 7.0;    // $150+: SL = peak - 7.0Ã—ATR (mÃ¡ximo fÃ´lego $1500)
input double V9_ChandelierMinPeakToActivate= 5.0;    // Peak mÃ­nimo para Chandelier comeÃ§ar a calcular
// â”€â”€ V9: FECHAMENTO PARCIAL (PARTIAL CLOSE) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Fecha 50% da posiÃ§Ã£o quando entra na Zona 2 ($10-$30).
// Garante lucro real. Os 50% restantes continuam como runner.
input bool   V9_UsePartialClose            = true;
input double V9_PartialCloseTriggerMoney   = 10.0;   // AUDIT FIX: 18â†’10 â€” partial close mais cedo (WR 100%)
input double V9_PartialClosePercent        = 40.0;   // V10: era 50% â†’ 40% â€” deixa mais no runner
input bool   V9_PartialCloseOncePerTrade   = true;   // sÃ³ 1 vez por trade
// V10: BIG_RUNNER nÃ£o faz partial close â€” precisa de volume completo para capturar $1500
input double V9_PartialCloseMaxProfit      = 120.0;  // Acima de $120 = BIG_RUNNER, nÃ£o faz partial
// ATR multipliers por zona (trailing virtual baseado no ATR M1 atual)
// Zona 1: sem trailing (proteÃ§Ã£o por hold+reversÃ£o severa)
// Zona 2: 1.5x ATR_M1 de giveback mÃ¡ximo desde o peak
// Zona 3: 2.0x ATR_M1 de giveback mÃ¡ximo desde o peak
// Zona 4: 3.0x ATR_M1 de giveback mÃ¡ximo desde o peak
input int    SmartExitNoProgressSecondsV4     = 180;
input double SmartExitMinProfitToProtectV4    = 25.0;
input bool   UseGivebackProtectionV4          = true;
input double GivebackWarningPercentV4         = 40.0;
input double GivebackClosePercentV4           = 35.0;
input bool   UseExitCalibrationDiagnosticV4   = false;

// ==================================================
// FIX3.1 - Early Close Diagnostic & Profit Holding controls
// Exit-only update. Do NOT change FIX2/FIX3 entry logic.
// ==================================================
input bool   UseMinProfitHoldV4                    = true;
input double MinProfitToAllowPositiveCloseV4       = 35.0;  // AUDIT FIX: 20â†’35 â€” bloqueia saÃ­da prematura em lucro pequeno
input int    MinSecondsBeforePositiveCloseV4       = 120;
input bool   BlockMicroProfitCloseV4               = true;
input double MinBasketProfitToCloseV4              = 80.0;  // AUDIT FIX: 60â†’80 â€” basket fecha apenas com lucro consolidado
input int    MinBasketAgeSecondsV4                 = 120;
input int    SmartExitPositiveCloseConfirmationsV4 = 4;
input int    TimeNoProgressMinSecondsV4            = 240;
input double TimeNoProgressMinAdverseMoneyV4       = -20.0; // AUDIT FIX: -10â†’-20 â€” time exit sÃ³ em perda real
input double TimeNoProgressIgnoreIfProfitV4        = 5.0;
input double RunnerAssignMinProfitV4               = 12.0;  // AUDIT FIX: 5â†’12 â€” runner promovido com lucro real
input int    RunnerAssignMinSecondsV4              = 20;
input bool   UseEarlyCloseDiagnosticOnlyV4         = false;


// V4 profiles and states
enum ENUM_AGGRESSIVE_PROFILE_V4
{
   PROFILE_PROP_AGGRESSIVE_SAFE = 0,
   PROFILE_DEMO_BENCHMARK_ULTRA = 1
};

input ENUM_AGGRESSIVE_PROFILE_V4 AggressiveProfileV4 = PROFILE_PROP_AGGRESSIVE_SAFE;

enum ENUM_RESULT_CLASS_V4
{
   RESULT_NONE_V4 = 0,
   RESULT_SMALL_WIN_V4,
   RESULT_MEDIUM_WIN_V4,
   RESULT_BIG_WIN_V4,
   RESULT_RUNNER_WIN_V4,
   RESULT_SMALL_LOSS_V4,
   RESULT_CONTROLLED_LOSS_V4,
   RESULT_EMERGENCY_LOSS_V4
};

enum ENUM_EXIT_PRIORITY_V4
{
   EXIT_NONE_V4 = 0,
   EXIT_EMERGENCY_SL_V4 = 1,
   EXIT_BASKET_RISK_V4 = 2,
   EXIT_SMART_NO_POTENTIAL_V4 = 3,
   EXIT_GIVEBACK_PROTECTION_V4 = 4,
   EXIT_RESULT_TARGET_V4 = 5,
   EXIT_RUNNER_TRAILING_V4 = 6
};


// FIX3 - Single exit decision by ticket. Priority order is encoded by values.
enum ENUM_V4_EXIT_REASON
{
   EXIT_NONE = 0,
   EXIT_BASKET_EMERGENCY_SL = 1,
   EXIT_DAILY_RISK = 2,
   EXIT_MARGIN_PROTECTION = 3,
   EXIT_RUNNER_BREAK_EVEN = 4,
   EXIT_RUNNER_GIVEBACK = 5,
   EXIT_SMART_EXIT_CONFIRMED = 6,
   EXIT_BASKET_PROFIT = 7,
   EXIT_SMALL_WIN = 8,
   EXIT_TIME_NO_PROGRESS = 9
};

enum ENUM_TRADE_STATE_V4
{
   TRADE_STATE_NEW_V4 = 0,
   TRADE_STATE_EVALUATING_V4 = 1,
   TRADE_STATE_PROTECTED_V4 = 2,
   TRADE_STATE_RUNNER_MODE_V4 = 3,
   TRADE_STATE_EXIT_PENDING_V4 = 4,
   TRADE_STATE_CLOSED_V4 = 5
};

// FIX2 - Filter Matrix Action
enum ENUM_V4_FILTER_ACTION
{
   FILTER_KEEP_ABSOLUTE_BLOCK = 0,
   FILTER_CONVERT_TO_SCORE    = 1,
   FILTER_EXIT_ONLY           = 2,
   FILTER_REMOVE_FROM_FLOW    = 3
};

struct V4FinalDecision
{
   bool allowEntry;
   bool allowExit;
   bool absoluteBlock;
   string direction;
   string finalReason;
   double entryScore;
   double profitPotentialScore;
   string legacyReason;
   string legacyAction;
};

struct TicketRoleV4
{
   ulong ticket;
   string role;
   datetime openTime;
   double entryPrice;
   double initialLot;
};

struct TicketProfitPeakV4
{
   ulong ticket;
   double peakProfit;
   datetime lastUpdate;
};

struct TicketExitLockV4
{
   ulong ticket;
   datetime lastCloseAttempt;
   string lastReason;
};


// FIX3 - Per-ticket exit state. Never use global profit peak for all trades.
struct V4TicketExitState
{
   ulong ticket;
   string symbol;
   long magic;
   bool isRunner;
   bool breakEvenActivated;
   bool closeAlreadyRequestedThisTick;
   double profitPeakMoney;
   double maxAdverseMoney;        // V10 LIVE EXIT: MAE monetario por ticket (valor mais negativo observado)
   double lastProfitMoney;
   datetime lastPeakTime;
   datetime lastExitDecisionTime;
   string lastExitReason;
   string liveExitClass;          // V10 LIVE EXIT: WEAK/MODERATE/GOOD/RUNNER/BIG_RUNNER
   string previousExitClass;
   bool lockActivated;
   bool trailingActivated;
   datetime classChangedTime;
};

// ==================================================
// Enums prepared for future stages
// ==================================================

enum ENUM_MARKET_MODE
{
   MARKET_UNKNOWN,
   MARKET_DEAD,
   MARKET_SIDEWAYS,
   MARKET_TREND_BUY,
   MARKET_TREND_SELL,
   MARKET_EXPLOSIVE,
   MARKET_ERRATIC,
   MARKET_SPREAD_DANGER
};

enum ENUM_FLOW_DIRECTION
{
   FLOW_NONE,
   FLOW_BUY_WEAK,
   FLOW_BUY_STRONG,
   FLOW_SELL_WEAK,
   FLOW_SELL_STRONG,
   FLOW_BALANCED,
   FLOW_DANGEROUS
};

enum ENUM_MARKET_STRENGTH
{
   MARKET_STRENGTH_UNKNOWN,
   MARKET_STRENGTH_WEAK,
   MARKET_STRENGTH_MEDIUM,
   MARKET_STRENGTH_STRONG
};

enum ENUM_CYCLE_STATE
{
   CYCLE_NONE,
   CYCLE_WAITING,
   CYCLE_BUY_SELL_OPENED,
   CYCLE_EVALUATING,
   CYCLE_BUY_DOMINANT,
   CYCLE_SELL_DOMINANT,
   CYCLE_HEDGED,
   CYCLE_PROTECTED,
   CYCLE_CLOSING,
   CYCLE_LOCKED
};

enum ENUM_EQUITY_PROTECTION_MODE
{
   EQUITY_NORMAL,
   EQUITY_SOFT_PROTECTION,
   EQUITY_RISK_REDUCTION,
   EQUITY_HEDGE_ALLOWED,
   EQUITY_CRITICAL_PROTECTION,
   EQUITY_EMERGENCY_CLOSE,
   EQUITY_DAILY_LOCKED
};

enum ENUM_ENTRY_DECISION
{
   ENTRY_DECISION_NONE = 0,
   ENTRY_DECISION_BUY,
   ENTRY_DECISION_SELL,
   ENTRY_DECISION_WAIT,
   ENTRY_DECISION_BLOCKED,
   ENTRY_DECISION_CONFLICT
};

enum ENUM_VIRTUAL_ENTRY_STATE
{
   VIRTUAL_ENTRY_NONE = 0,
   VIRTUAL_ENTRY_ACTIVE,
   VIRTUAL_ENTRY_WIN,
   VIRTUAL_ENTRY_LOSS,
   VIRTUAL_ENTRY_TIMEOUT,
   VIRTUAL_ENTRY_INVALIDATED,
   VIRTUAL_ENTRY_CANCELLED
};

enum ENUM_VIRTUAL_ENTRY_DIRECTION
{
   VIRTUAL_DIR_NONE = 0,
   VIRTUAL_DIR_BUY,
   VIRTUAL_DIR_SELL
};

enum ENUM_PRE_EXECUTION_STATE
{
   PRE_EXECUTION_DISABLED = 0,
   PRE_EXECUTION_WAIT,
   PRE_EXECUTION_APPROVED,
   PRE_EXECUTION_BLOCKED,
   PRE_EXECUTION_RISK_DANGER
};

enum ENUM_EXECUTION_DRY_RUN_STATE
{
   DRY_RUN_DISABLED = 0,
   DRY_RUN_WAIT,
   DRY_RUN_APPROVED,
   DRY_RUN_BLOCKED,
   DRY_RUN_BUY_READY,
   DRY_RUN_SELL_READY,
   DRY_RUN_RISK_BLOCK,
   DRY_RUN_DUPLICATE_BLOCK
};

enum ENUM_DRY_RUN_DIRECTION
{
   DRY_RUN_DIR_NONE = 0,
   DRY_RUN_DIR_BUY,
   DRY_RUN_DIR_SELL
};


enum ENUM_REAL_EXECUTION_STATE
{
   REAL_EXEC_DISABLED = 0,
   REAL_EXEC_SIMULATION_ONLY,
   REAL_EXEC_WAIT,
   REAL_EXEC_READY,
   REAL_EXEC_BUY_SENT,
   REAL_EXEC_SELL_SENT,
   REAL_EXEC_BLOCKED,
   REAL_EXEC_RISK_BLOCK,
   REAL_EXEC_DUPLICATE_BLOCK,
   REAL_EXEC_BROKER_BLOCK,
   REAL_EXEC_ERROR
};

enum ENUM_REAL_EXECUTION_DIRECTION
{
   REAL_EXEC_DIR_NONE = 0,
   REAL_EXEC_DIR_BUY,
   REAL_EXEC_DIR_SELL
};


enum ENUM_POSITION_MANAGER_STATE
{
   POS_MANAGER_DISABLED = 0,
   POS_MANAGER_NO_POSITION,
   POS_MANAGER_MONITORING,
   POS_MANAGER_SIMULATION_ONLY,
   POS_MANAGER_BE_READY,
   POS_MANAGER_BE_APPLIED,
   POS_MANAGER_TRAILING_READY,
   POS_MANAGER_TRAILING_APPLIED,
   POS_MANAGER_PROFIT_PROTECTED,
   POS_MANAGER_EMERGENCY_BLOCK,
   POS_MANAGER_EMERGENCY_CLOSED,
   POS_MANAGER_ERROR
};

enum ENUM_MANAGED_POSITION_DIRECTION
{
   MANAGED_POS_NONE = 0,
   MANAGED_POS_BUY,
   MANAGED_POS_SELL
};


enum ENUM_LAYER_STATE
{
   LAYER_DISABLED = 0,
   LAYER_WAIT,
   LAYER_NO_MAIN_POSITION,
   LAYER_MONITORING,
   LAYER_READY,
   LAYER_SIMULATION_ONLY,
   LAYER_BLOCKED,
   LAYER_RISK_BLOCK,
   LAYER_DISTANCE_BLOCK,
   LAYER_SIGNAL_BLOCK,
   LAYER_EXPOSURE_BLOCK,
   LAYER_BROKER_BLOCK,
   LAYER_BUY_READY,
   LAYER_SELL_READY,
   LAYER_BUY_SENT,
   LAYER_SELL_SENT,
   LAYER_ERROR
};

enum ENUM_LAYER_DIRECTION
{
   LAYER_DIR_NONE = 0,
   LAYER_DIR_BUY,
   LAYER_DIR_SELL
};


// ==================================================
// Structs prepared for future stages
// ==================================================

struct FlowData
{
   double atrPoints;
   double candleBodyPoints;
   double upperWickPoints;
   double lowerWickPoints;
   double buyStrength;
   double sellStrength;
   double momentumScore;
   double accelerationScore;
   double rejectionScore;
   double imbalanceScore;
   ENUM_FLOW_DIRECTION direction;
};

struct MarketData
{
   ENUM_MARKET_MODE mode;
   ENUM_MARKET_STRENGTH strength;
   double volatilityScore;
   double trendScore;
   double dangerScore;
   double spreadScore;
   bool isTradable;
   string reason;
};

struct BasketData
{
   datetime startTime;
   double startEquity;
   double netProfit;
   double maxDrawdown;
   double buyLots;
   double sellLots;
   double totalLots;
   int totalPositions;
   int hedgeCount;
   int reentryCount;
   string dominantSide;
   string lastReason;
};

struct RiskData
{
   double dailyStartEquity;
   double dailyHighEquity;
   double dailyDrawdownPercent;
   double dailyProfitMoney;
   ENUM_EQUITY_PROTECTION_MODE protectionMode;
   bool tradingLocked;
   string lockReason;
};

struct VirtualEntryData
{
   ENUM_VIRTUAL_ENTRY_STATE state;
   ENUM_VIRTUAL_ENTRY_DIRECTION direction;

   datetime startTime;
   datetime endTime;
   datetime startBarTime;

   int ageSeconds;
   int ageBars;

   double entryPrice;
   double currentPrice;
   double stopLossPrice;
   double takeProfitPrice;

   double virtualRiskPoints;
   double virtualRewardPoints;
   double virtualRR;

   double currentProfitPoints;
   double currentProfitMoney;
   double maxFavorablePoints;
   double maxAdversePoints;

   double decisionScoreAtStart;
   double entryBaseScoreAtStart;
   double buyScoreAtStart;
   double sellScoreAtStart;
   double flowQualityAtStart;
   double atrAtStart;
   int spreadAtStart;

   string startReason;
   string endReason;
   string statusText;
};

struct PreExecutionRiskData
{
   ENUM_PRE_EXECUTION_STATE state;

   bool approved;
   bool blocked;
   bool waiting;
   bool riskDanger;

   datetime lastUpdateTime;

   double preExecutionScore;
   double riskScore;
   double virtualConfirmationScore;
   double accountSafetyScore;
   double tradeCostScore;
   double rrScore;
   double dailyRiskScore;

   double estimatedLot;
   double estimatedRiskMoney;
   double estimatedRewardMoney;
   double estimatedRiskPercent;
   double estimatedSpreadCostMoney;
   double estimatedCommissionBufferMoney;

   double accountBalance;
   double accountEquity;
   double accountFreeMargin;
   double accountMarginLevel;

   double minRequiredScore;
   double maxAllowedRiskMoney;
   double maxAllowedRiskPercent;

   string direction;
   string statusText;
   string reason;
   string blockReason;
};

struct ExecutionDryRunData
{
   ENUM_EXECUTION_DRY_RUN_STATE state;
   ENUM_DRY_RUN_DIRECTION direction;
   bool approved;
   bool blocked;
   bool waiting;
   bool buyReady;
   bool sellReady;
   bool riskBlock;
   bool duplicateBlock;
   datetime lastUpdateTime;
   datetime plannedBarTime;
   datetime lastApprovedTime;
   double dryRunScore;
   double permissionScore;
   double directionScore;
   double riskPermissionScore;
   double duplicateSafetyScore;
   double executionCostScore;
   double plannedLot;
   double plannedEntryPrice;
   double plannedSL;
   double plannedTP;
   double plannedRiskPoints;
   double plannedRewardPoints;
   double plannedRR;
   double plannedRiskMoney;
   double plannedRewardMoney;
   double plannedRiskPercent;
   double plannedSpreadCostMoney;
   double plannedCommissionMoney;
   string plannedOrderType;
   string statusText;
   string reason;
   string blockReason;
   string permissionReason;
};


struct RealExecutionData
{
   ENUM_REAL_EXECUTION_STATE state;
   ENUM_REAL_EXECUTION_DIRECTION direction;

   bool ready;
   bool blocked;
   bool simulationOnly;
   bool riskBlock;
   bool duplicateBlock;
   bool brokerBlock;
   bool orderSent;
   bool buySent;
   bool sellSent;
   bool error;

   datetime lastUpdateTime;
   datetime lastExecutionTime;
   datetime lastExecutionBarTime;
   datetime lastAttemptTime;

   int attemptCount;

   ulong lastOrderTicket;
   ulong lastDealTicket;
   ulong lastPositionTicket;

   double executionLot;
   double executionEntryPrice;
   double executionSL;
   double executionTP;
   double executionRiskMoney;
   double executionRewardMoney;
   double executionRiskPercent;
   double executionRR;
   double executionSpreadPoints;
   double executionMarginRequired;

   string executionOrderType;
   string statusText;
   string reason;
   string blockReason;
   string brokerReason;
   string lastErrorText;
};


struct PositionManagerData
{
   ENUM_POSITION_MANAGER_STATE state;
   ENUM_MANAGED_POSITION_DIRECTION direction;

   bool hasPosition;
   bool monitoring;
   bool simulationOnly;
   bool breakEvenReady;
   bool breakEvenApplied;
   bool trailingReady;
   bool trailingApplied;
   bool profitProtected;
   bool emergencyBlock;
   bool emergencyClosed;
   bool error;

   ulong positionTicket;
   long positionType;
   long positionMagic;

   datetime openTime;
   datetime lastUpdateTime;
   datetime lastModifyTime;
   datetime lastCloseTime;

   double volume;
   double openPrice;
   double currentPrice;
   double currentSL;
   double currentTP;
   double proposedSL;
   double proposedTP;

   double profitMoney;
   double swapMoney;
   double commissionMoney;
   double netProfitMoney;

   double profitPoints;
   double adversePoints;
   double favorablePoints;
   double maxProfitMoney;
   double maxAdverseMoney;
   double maxFavorablePoints;
   double maxAdversePoints;

   double distanceToSLPoints;
   double distanceToTPPoints;
   double riskMoneyAtSL;
   double rewardMoneyAtTP;

   string statusText;
   string reason;
   string blockReason;
   string actionReason;
   string lastErrorText;
};




struct ReentryLayerData
{
   ENUM_LAYER_STATE state;
   ENUM_LAYER_DIRECTION direction;

   bool active;
   bool hasMainPosition;
   bool layerReady;
   bool layerBlocked;
   bool simulationOnly;
   bool layerSent;
   bool buyLayerReady;
   bool sellLayerReady;
   bool riskApproved;
   bool distanceApproved;
   bool signalApproved;
   bool exposureApproved;
   bool brokerApproved;
   bool error;

   ulong mainPositionTicket;
   ulong lastLayerTicket;

   datetime lastUpdateTime;
   datetime lastLayerTime;
   datetime lastLayerCandleTime;

   int currentLayerCount;
   int buyLayerCount;
   int sellLayerCount;
   int maxLayersAllowed;

   double mainPositionOpenPrice;
   double mainPositionCurrentPrice;
   double mainPositionProfitMoney;
   double mainPositionProfitPoints;
   double mainPositionSL;
   double mainPositionTP;

   double plannedLayerLot;
   double plannedLayerEntry;
   double plannedLayerSL;
   double plannedLayerTP;
   double plannedLayerRiskMoney;
   double plannedLayerRewardMoney;
   double plannedLayerRR;
   double distanceFromLastLayerPoints;
   double totalLayerLots;
   double totalSymbolLots;
   double currentSpreadPoints;

   string statusText;
   string reason;
   string blockReason;
   string actionReason;
   string lastErrorText;
};

// ==================================================
// Global objects and data
// ==================================================

FlowData g_flow;
MarketData g_market;
BasketData g_basket;
RiskData g_risk;
VirtualEntryData g_virtualEntry;
PreExecutionRiskData g_preExecution;
ExecutionDryRunData g_executionDryRun;
RealExecutionData g_realExecution;
PositionManagerData g_positionManager;
ReentryLayerData g_reentryLayer;

// V4 runtime state
V4FinalDecision g_v4FinalDecision;
TicketRoleV4 g_v4TicketRoles[];
TicketProfitPeakV4 g_v4TicketPeaks[];
TicketExitLockV4 g_v4ExitLocks[];

V4TicketExitState g_v4TicketExitStates[];
int g_v4SmartExitCloseCount          = 0;
int g_v4RunnerCloseCount             = 0;
int g_v4GivebackCloseCount           = 0;
int g_v4BreakEvenCloseCount          = 0;
int g_v4BasketProfitCloseCount       = 0;
int g_v4EmergencyCloseCount          = 0;
int g_v4RunnerProtectedCount         = 0;
int g_v4EarlyClosePreventedCount     = 0;
int g_v4DuplicateClosePreventedCount = 0;

int g_v4MicroProfitCloseBlockedCount = 0;
int g_v4MicroProfitCloseAllowedCount = 0;
int g_v4EarlySmallWinBlockedCount = 0;
int g_v4EarlyBasketCloseBlockedCount = 0;
int g_v4EarlyTimeExitBlockedCount = 0;
int g_v4RunnerMicroCloseBlockedCount = 0;
datetime g_v4LastHistoryScanTime = 0;
datetime g_v4LossStreakPauseUntil = 0;
datetime g_v4LastSmartExitCloseTime = 0;
string g_v4LastSmartExitDirection = "NONE";
string g_v4LastLegacyReason = "NONE";
string g_v4LastLegacyAction = "NONE";
string g_v4LastFinalReason = "NONE";
string g_v4LastExitReason = "NONE";
string g_v4LastExitPriority = "NONE";
string g_v4LastResultClass = "NONE";
string g_v4LastTradeState = "NONE";
double g_v4LastBuyScore = 0.0;
double g_v4LastSellScore = 0.0;
double g_v4LastEntryScore = 0.0;
double g_v4LastPotentialScore = 0.0;
int g_v4SmallWinCount = 0;
int g_v4MediumWinCount = 0;
int g_v4BigWinCount = 0;
int g_v4RunnerWinCount = 0;
int g_v4SmallLossCount = 0;
int g_v4ControlledLossCount = 0;
int g_v4EmergencyLossCount = 0;
double g_v4TotalWinMoney = 0.0;
double g_v4TotalLossMoney = 0.0;
double g_v4LargestWin = 0.0;
double g_v4LargestLoss = 0.0;
int g_v4ClosedWinCount = 0;
int g_v4ClosedLossCount = 0;



datetime g_lastDayReset = 0;
datetime g_lastTickTime = 0;

string g_eaStatus = "INITIALIZING";
string g_lastBlockReason = "NONE";
string g_lastEntryReason = "NONE";
string g_lastExitReason = "NONE";
string g_lastAction = "NONE";

bool g_environmentOK = false;
bool g_symbolOK = false;
bool g_timeframeOK = false;
bool g_dashboardCreated = false;

// Diagnostic environment state
bool g_terminalConnected = false;
bool g_mqlTradeAllowed = false;
bool g_accountTradeAllowed = false;
bool g_liveTradingAllowed = false;
bool g_priceFeedOK = false;

// Anti repeated log control
string g_lastLoggedBlockReason = "";
datetime g_lastRepeatedLogTime = 0;

// ETAPA 2 - Security Filter State
bool g_spreadOK = false;
bool g_sessionOK = false;
bool g_cooldownOK = false;
bool g_marginOK = false;
bool g_priceOK = false;
bool g_accountSafetyOK = false;
bool g_securityFiltersOK = false;

int g_currentSpreadPoints = 0;
datetime g_lastActionTime = 0;
datetime g_lastBlockTime = 0;
datetime g_lastValidTickTime = 0;

string g_spreadStatus = "UNKNOWN";
string g_sessionStatus = "UNKNOWN";
string g_cooldownStatus = "UNKNOWN";
string g_marginStatus = "UNKNOWN";
string g_priceStatus = "UNKNOWN";
string g_accountSafetyStatus = "UNKNOWN";
string g_securityFilterReason = "NOT CHECKED";

// ETAPA 3 - ATR / Volatility / Market State
int g_atrHandleM1 = INVALID_HANDLE;
int g_atrHandleM5 = INVALID_HANDLE;

double g_atrM1Points = 0.0;
double g_atrM5Points = 0.0;

double g_currentCandleRangePoints = 0.0;
double g_currentCandleBodyPoints = 0.0;
double g_upperWickPoints = 0.0;
double g_lowerWickPoints = 0.0;
double g_averageRangePoints = 0.0;

double g_bodyRatio = 0.0;
double g_upperWickRatio = 0.0;
double g_lowerWickRatio = 0.0;

string g_volatilityStatus = "UNKNOWN";
string g_marketModeStatus = "UNKNOWN";
string g_marketStrengthStatus = "UNKNOWN";
string g_marketDiagnosticReason = "NOT CHECKED";

datetime g_lastMarketLogTime = 0;
string g_lastMarketLoggedReason = "";

// ETAPA 4 - Flow Engine State
double g_buyStrengthScore = 0.0;
double g_sellStrengthScore = 0.0;
double g_momentumScore = 0.0;
double g_accelerationScore = 0.0;
double g_rejectionScore = 0.0;
double g_buyRejectionScore = 0.0;
double g_sellRejectionScore = 0.0;
double g_imbalanceScore = 0.0;
double g_buyImbalanceScore = 0.0;
double g_sellImbalanceScore = 0.0;
double g_flowDangerScore = 0.0;
double g_flowQualityScore = 0.0;

bool g_flowOK = false;
bool g_buyFlowDominant = false;
bool g_sellFlowDominant = false;
bool g_flowBalanced = false;
bool g_flowDangerous = false;

string g_flowStatus = "UNKNOWN";
string g_flowReason = "NOT CHECKED";
string g_flowDirectionText = "NONE";
string g_flowDiagnosticReason = "NOT CHECKED";

datetime g_lastFlowLogTime = 0;
string g_lastFlowLoggedReason = "";

// ETAPA 5 - Entry Base Score State
double g_entryBaseScore = 0.0;
double g_buyEntryBaseScore = 0.0;
double g_sellEntryBaseScore = 0.0;

double g_securityComponentScore = 0.0;
double g_volatilityComponentScore = 0.0;
double g_marketModeComponentScore = 0.0;
double g_marketStrengthComponentScore = 0.0;
double g_flowQualityComponentScore = 0.0;

double g_directionalComponentScore = 0.0;
double g_momentumComponentScore = 0.0;
double g_rejectionComponentScore = 0.0;
double g_imbalanceComponentScore = 0.0;

double g_buyDirectionalComponentScore = 0.0;
double g_sellDirectionalComponentScore = 0.0;
double g_buyRejectionComponentScore = 0.0;
double g_sellRejectionComponentScore = 0.0;
double g_buyImbalanceComponentScore = 0.0;
double g_sellImbalanceComponentScore = 0.0;

double g_totalEntryPenalty = 0.0;

bool g_entryBaseOK = false;
bool g_buyEntryCandidate = false;
bool g_sellEntryCandidate = false;
bool g_entryScoreStrong = false;
bool g_entryScoreExcellent = false;

string g_entryBaseStatus = "UNKNOWN";
string g_entryBaseReason = "NOT CHECKED";
string g_entryBaseDirection = "NONE";
string g_entryDiagnosticReason = "NOT CHECKED";

datetime g_lastEntryScoreLogTime = 0;
string g_lastEntryScoreLoggedReason = "";

// ETAPA 6 - Entry Decision Diagnostic State
ENUM_ENTRY_DECISION g_entryDecision = ENTRY_DECISION_NONE;

double g_entryDecisionScore = 0.0;
double g_buyDecisionScore = 0.0;
double g_sellDecisionScore = 0.0;
double g_decisionScoreDifference = 0.0;

bool g_entryDecisionOK = false;
bool g_buyDecisionCandidate = false;
bool g_sellDecisionCandidate = false;
bool g_entryDecisionStrong = false;
bool g_entryDecisionExcellent = false;
bool g_entryDecisionConflict = false;
bool g_entryDecisionBlocked = false;

string g_entryDecisionStatus = "UNKNOWN";
string g_entryDecisionReason = "NOT CHECKED";
string g_entryDecisionDirection = "NONE";
string g_entryDecisionText = "ENTRY_DECISION_NONE";
string g_entryDecisionDiagnosticReason = "NOT CHECKED";

datetime g_lastEntryDecisionLogTime = 0;
string g_lastEntryDecisionLoggedReason = "";

// ETAPA 7 - Virtual Entry Simulation State
bool g_virtualEntryActive = false;
bool g_virtualEntryCompleted = false;
bool g_virtualEntryWin = false;
bool g_virtualEntryLoss = false;
bool g_virtualEntryTimeout = false;
bool g_virtualEntryInvalidated = false;
bool g_virtualEntryCancelled = false;

bool g_virtualBuyCandidate = false;
bool g_virtualSellCandidate = false;

double g_virtualEntryScore = 0.0;
double g_virtualEntryResultScore = 0.0;
double g_virtualEntryQualityAtStart = 0.0;

int g_virtualWins = 0;
int g_virtualLosses = 0;
int g_virtualTimeouts = 0;
int g_virtualInvalidations = 0;
int g_virtualCancellations = 0;
int g_virtualTotalSimulations = 0;

datetime g_lastVirtualEntryEndTime = 0;
datetime g_lastVirtualEntryLogTime = 0;
datetime g_lastVirtualEntryStartBarTime = 0;

string g_virtualEntryStatus = "UNKNOWN";
string g_virtualEntryReason = "NOT CHECKED";
string g_virtualEntryDirectionText = "NONE";
string g_lastVirtualEntryLoggedReason = "";

// ETAPA 8 - Pre-Execution Risk Gate State
bool g_preExecutionApproved = false;
bool g_preExecutionBlocked = false;
bool g_preExecutionWaiting = false;
bool g_preExecutionRiskDanger = false;

double g_preExecutionScore = 0.0;
double g_preExecutionRiskScore = 0.0;
double g_preExecutionVirtualScore = 0.0;
double g_preExecutionAccountScore = 0.0;
double g_preExecutionCostScore = 0.0;
double g_preExecutionRRScore = 0.0;
double g_preExecutionDailyRiskScore = 0.0;

double g_estimatedExecutionLot = 0.0;
double g_estimatedRiskMoney = 0.0;
double g_estimatedRewardMoney = 0.0;
double g_estimatedRiskPercent = 0.0;
double g_estimatedSpreadCostMoney = 0.0;
double g_estimatedCommissionBufferMoney = 0.0;

string g_preExecutionStatus = "UNKNOWN";
string g_preExecutionReason = "NOT CHECKED";
string g_preExecutionBlockReason = "NONE";
string g_preExecutionDirection = "NONE";

datetime g_lastPreExecutionLogTime = 0;
string g_lastPreExecutionLoggedReason = "";

// ETAPA 9 - Execution Dry-Run State
bool g_dryRunApproved = false;
bool g_dryRunBlocked = false;
bool g_dryRunWaiting = false;
bool g_dryRunBuyReady = false;
bool g_dryRunSellReady = false;
bool g_dryRunRiskBlock = false;
bool g_dryRunDuplicateBlock = false;
double g_dryRunScore = 0.0;
double g_dryRunPermissionScore = 0.0;
double g_dryRunDirectionScore = 0.0;
double g_dryRunRiskPermissionScore = 0.0;
double g_dryRunDuplicateSafetyScore = 0.0;
double g_dryRunExecutionCostScore = 0.0;
double g_plannedExecutionLot = 0.0;
double g_plannedExecutionEntryPrice = 0.0;
double g_plannedExecutionSL = 0.0;
double g_plannedExecutionTP = 0.0;
double g_plannedExecutionRiskMoney = 0.0;
double g_plannedExecutionRewardMoney = 0.0;
double g_plannedExecutionRiskPercent = 0.0;
datetime g_lastDryRunApprovalTime = 0;
datetime g_lastDryRunApprovalBarTime = 0;
datetime g_lastDryRunLogTime = 0;
string g_dryRunStatus = "UNKNOWN";
string g_dryRunReason = "NOT CHECKED";
string g_dryRunBlockReason = "NONE";
string g_dryRunDirectionText = "NONE";
string g_lastDryRunLoggedReason = "";


// ETAPA 10 - Real Execution Engine State
bool g_realExecutionReady = false;
bool g_realExecutionBlocked = false;
bool g_realExecutionSimulationOnly = false;
bool g_realExecutionRiskBlock = false;
bool g_realExecutionDuplicateBlock = false;
bool g_realExecutionBrokerBlock = false;
bool g_realOrderSent = false;
bool g_realBuySent = false;
bool g_realSellSent = false;
bool g_realExecutionError = false;

double g_realExecutionLot = 0.0;
double g_realExecutionEntryPrice = 0.0;
double g_realExecutionSL = 0.0;
double g_realExecutionTP = 0.0;
double g_realExecutionRiskMoney = 0.0;
double g_realExecutionRewardMoney = 0.0;
double g_realExecutionRiskPercent = 0.0;
double g_realExecutionRR = 0.0;
double g_realExecutionMarginRequired = 0.0;

datetime g_lastRealExecutionTime = 0;
datetime g_lastRealExecutionBarTime = 0;
datetime g_lastRealExecutionAttemptTime = 0;
datetime g_lastRealExecutionLogTime = 0;

int g_realExecutionAttemptCount = 0;

ulong g_lastRealOrderTicket = 0;
ulong g_lastRealDealTicket = 0;
ulong g_lastRealPositionTicket = 0;

string g_realExecutionStatus = "UNKNOWN";
string g_realExecutionReason = "NOT CHECKED";
string g_realExecutionBlockReason = "NONE";
string g_realExecutionDirectionText = "NONE";
string g_lastRealExecutionLoggedReason = "";
string g_lastRealExecutionErrorText = "";

bool g_functionalSafetyApproved = false;
string g_functionalSafetyReason = "NOT CHECKED";
string g_functionalRealExecutionStatus = "NOT CHECKED";
string g_functionalLayerExecutionStatus = "NOT CHECKED";

// FIX3 V3 - Aggressive execution cycle debug/counters
datetime g_fix3LastTradeTime = 0;
datetime g_fix3LastCycleTime = 0;
datetime g_fix3LastPositionCloseTime = 0;
int      g_fix3TradesToday = 0;
int      g_fix3TradeDayKey = -1;
string   g_fix3AggressiveCycleReason = "NOT CHECKED";
string   g_fix3LastOrderPlanReason = "NOT CHECKED";
string   g_fix3LastBlockReason = "NONE";
bool     g_fix3OrderPlanReady = false;
ENUM_ORDER_TYPE g_fix3LastOrderPlanDirection = (ENUM_ORDER_TYPE)-1;
datetime g_fix3LastOrderPlanBuildTime = 0;
datetime g_fix3LastOrderPlanBarTime = 0;
string   g_fix3LastOrderPlanSymbol = "";
long     g_fix3LastOrderPlanMagic = 0;

// V5.1K - reverse-after-close state. This does not open hedge; it only arms
// the next direction after the opposite position has been closed by the EA/broker.
bool     g_pendingReverseAfterClose = false;
ENUM_ORDER_TYPE g_pendingReverseDirection = (ENUM_ORDER_TYPE)-1;
datetime g_pendingReverseCreatedAt = 0;
string   g_pendingReverseReason = "NONE";
int      g_pendingReverseTimeoutSeconds = 60;

// V5.1L AGGRESSIVE BUY EXECUTION FIX
// Captures any BUY selected by the V4 adaptive direction engine and forces the
// next real execution plan to remain BUY for a short TTL. This prevents the
// classic tester problem: Journal shows DIRECTION_SELECTED=BUY, but a later
// stale SELL plan/gate still sends SELL.
bool     g_v4AggressiveBuyLatchActive = false;
datetime g_v4AggressiveBuyLatchTime = 0;
datetime g_v4AggressiveBuyLatchBarTime = 0;
double   g_v4AggressiveBuyLatchScore = 0.0;
string   g_v4AggressiveBuyLatchSource = "NONE";
int      g_v4AggressiveBuyLatchTTLSeconds = 120;

bool     g_fix3AggressiveCycleActive = false;
string g_realExecutionBrokerReason = "NONE";

// ETAPA 11 - Position Manager State
bool g_positionManagerActive = false;
bool g_positionManagerSimulationOnly = false;
bool g_managedPositionFound = false;
bool g_breakEvenReady = false;
bool g_breakEvenApplied = false;
bool g_trailingReady = false;
bool g_trailingApplied = false;
bool g_profitProtectionActive = false;
bool g_positionEmergencyBlock = false;
bool g_positionEmergencyClosed = false;
bool g_positionManagerError = false;

ulong g_managedPositionTicket = 0;

double g_managedPositionVolume = 0.0;
double g_managedPositionOpenPrice = 0.0;
double g_managedPositionCurrentPrice = 0.0;
double g_managedPositionSL = 0.0;
double g_managedPositionTP = 0.0;
double g_managedPositionProfitMoney = 0.0;
double g_managedPositionProfitPoints = 0.0;
double g_positionProposedSL = 0.0;
double g_positionProposedTP = 0.0;
double g_positionMaxProfitMoney = 0.0;
double g_positionMaxAdverseMoney = 0.0;

datetime g_lastPositionManagerUpdateTime = 0;
datetime g_lastPositionModifyTime = 0;
datetime g_lastPositionCloseTime = 0;
datetime g_lastPositionLogTime = 0;

string g_positionManagerStatus = "UNKNOWN";
string g_positionManagerReason = "NOT CHECKED";
string g_positionManagerBlockReason = "NONE";
string g_positionManagerActionReason = "NONE";
string g_lastPositionManagerLoggedReason = "";
string g_positionManagerLastErrorText = "";

// ETAPA 11 FIX3 - Position Manager Visual State Hold
datetime g_positionManagerStateHoldUntil = 0;
ENUM_POSITION_MANAGER_STATE g_positionManagerHoldState = POS_MANAGER_MONITORING;
string g_positionManagerHoldReason = "NONE";


// ETAPA 12 - Reentry / Layer Engine State
bool g_layerEngineActive = false;
bool g_layerSimulationOnly = true;
bool g_layerReady = false;
bool g_layerBlocked = false;
bool g_layerSent = false;
bool g_layerRiskApproved = false;
bool g_layerDistanceApproved = false;
bool g_layerSignalApproved = false;
bool g_layerExposureApproved = false;
bool g_layerBrokerApproved = false;
bool g_layerError = false;

ulong g_lastLayerTicket = 0;

int g_currentLayerCount = 0;
int g_buyLayerCount = 0;
int g_sellLayerCount = 0;

double g_plannedLayerLot = 0.0;
double g_plannedLayerEntry = 0.0;
double g_plannedLayerSL = 0.0;
double g_plannedLayerTP = 0.0;
double g_plannedLayerRiskMoney = 0.0;
double g_plannedLayerRewardMoney = 0.0;
double g_plannedLayerRR = 0.0;
double g_totalLayerLots = 0.0;
double g_totalSymbolExposureLots = 0.0;
double g_layerDistanceFromLastEntryPoints = 0.0;

datetime g_lastLayerUpdateTime = 0;
datetime g_lastLayerExecutionTime = 0;
datetime g_lastLayerCandleTime = 0;
datetime g_lastLayerLogTime = 0;

string g_layerStatus = "UNKNOWN";
string g_layerReason = "NOT CHECKED";
string g_layerBlockReason = "NONE";
string g_layerActionReason = "NONE";
string g_lastLayerLoggedReason = "";
string g_layerLastErrorText = "";

// Dashboard settings
string DASH_PREFIX = "HGAI_STAGE12_";
int DASH_LINE_HEIGHT = 16;
int DASH_TOTAL_LINES = 360;

//+------------------------------------------------------------------+
//| Utility conversion functions                                     |
//+------------------------------------------------------------------+
string BoolToText(bool value)
{
   return (value ? "TRUE" : "FALSE");
}

string UlongToText(ulong value)
{
   return StringFormat("%I64u", value);
}

string SecurityBoolStatus(bool value)
{
   return (value ? "OK" : "BLOCKED");
}

string TimeframeToText(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M2:  return "M2";
      case PERIOD_M3:  return "M3";
      case PERIOD_M4:  return "M4";
      case PERIOD_M5:  return "M5";
      case PERIOD_M6:  return "M6";
      case PERIOD_M10: return "M10";
      case PERIOD_M12: return "M12";
      case PERIOD_M15: return "M15";
      case PERIOD_M20: return "M20";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H2:  return "H2";
      case PERIOD_H3:  return "H3";
      case PERIOD_H4:  return "H4";
      case PERIOD_H6:  return "H6";
      case PERIOD_H8:  return "H8";
      case PERIOD_H12: return "H12";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
      default:         return "UNKNOWN";
   }
}

string ProtectionModeToText(ENUM_EQUITY_PROTECTION_MODE mode)
{
   switch(mode)
   {
      case EQUITY_NORMAL:              return "EQUITY_NORMAL";
      case EQUITY_SOFT_PROTECTION:     return "EQUITY_SOFT_PROTECTION";
      case EQUITY_RISK_REDUCTION:      return "EQUITY_RISK_REDUCTION";
      case EQUITY_HEDGE_ALLOWED:       return "EQUITY_HEDGE_ALLOWED";
      case EQUITY_CRITICAL_PROTECTION: return "EQUITY_CRITICAL_PROTECTION";
      case EQUITY_EMERGENCY_CLOSE:     return "EQUITY_EMERGENCY_CLOSE";
      case EQUITY_DAILY_LOCKED:        return "EQUITY_DAILY_LOCKED";
      default:                         return "UNKNOWN";
   }
}

string MarketModeToText(ENUM_MARKET_MODE mode)
{
   switch(mode)
   {
      case MARKET_UNKNOWN:       return "MARKET_UNKNOWN";
      case MARKET_DEAD:          return "MARKET_DEAD";
      case MARKET_SIDEWAYS:      return "MARKET_SIDEWAYS";
      case MARKET_TREND_BUY:     return "MARKET_TREND_BUY";
      case MARKET_TREND_SELL:    return "MARKET_TREND_SELL";
      case MARKET_EXPLOSIVE:     return "MARKET_EXPLOSIVE";
      case MARKET_ERRATIC:       return "MARKET_ERRATIC";
      case MARKET_SPREAD_DANGER: return "MARKET_SPREAD_DANGER";
      default:                   return "UNKNOWN";
   }
}

string MarketStrengthToText(ENUM_MARKET_STRENGTH strength)
{
   switch(strength)
   {
      case MARKET_STRENGTH_UNKNOWN: return "MARKET_STRENGTH_UNKNOWN";
      case MARKET_STRENGTH_WEAK:    return "MARKET_STRENGTH_WEAK";
      case MARKET_STRENGTH_MEDIUM:  return "MARKET_STRENGTH_MEDIUM";
      case MARKET_STRENGTH_STRONG:  return "MARKET_STRENGTH_STRONG";
      default:                      return "UNKNOWN";
   }
}

string CycleStateToText(ENUM_CYCLE_STATE state)
{
   switch(state)
   {
      case CYCLE_NONE:             return "CYCLE_NONE";
      case CYCLE_WAITING:          return "CYCLE_WAITING";
      case CYCLE_BUY_SELL_OPENED:  return "CYCLE_BUY_SELL_OPENED";
      case CYCLE_EVALUATING:       return "CYCLE_EVALUATING";
      case CYCLE_BUY_DOMINANT:     return "CYCLE_BUY_DOMINANT";
      case CYCLE_SELL_DOMINANT:    return "CYCLE_SELL_DOMINANT";
      case CYCLE_HEDGED:           return "CYCLE_HEDGED";
      case CYCLE_PROTECTED:        return "CYCLE_PROTECTED";
      case CYCLE_CLOSING:          return "CYCLE_CLOSING";
      case CYCLE_LOCKED:           return "CYCLE_LOCKED";
      default:                     return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| Logging                                                          |
//+------------------------------------------------------------------+
bool CanPrintRepeatedLog(string reason)
{
   datetime now = TimeCurrent();

   if(reason != g_lastLoggedBlockReason)
   {
      g_lastLoggedBlockReason = reason;
      g_lastRepeatedLogTime = now;
      return true;
   }

   if((now - g_lastRepeatedLogTime) >= MinSecondsBetweenRepeatedLogs)
   {
      g_lastRepeatedLogTime = now;
      return true;
   }

   return false;
}

void AuditLog(string module, string message)
{
   if(!PrintDetailedLogs)
      return;

   Print("[HORSE EA][", module, "] ", message);
}

void AuditBlock(string module, string reason)
{
   g_lastBlockReason = reason;

   if(CanPrintRepeatedLog(module + ":" + reason))
      AuditLog("BLOCK", module + " - " + reason);
}

void AuditEntry(string direction, double score, string reason)
{
   g_lastEntryReason = direction + " | Score=" + DoubleToString(score, 2) + " | " + reason;
   AuditLog("ENTRY", "PLACEHOLDER ONLY - " + g_lastEntryReason);
}

void AuditExit(string reason, double profit)
{
   g_lastExitReason = reason + " | Profit=" + DoubleToString(profit, 2);
   AuditLog("EXIT", "PLACEHOLDER ONLY - " + g_lastExitReason);
}

//+------------------------------------------------------------------+
//| Core initialization                                              |
//+------------------------------------------------------------------+
void InitializeCoreData()
{
   g_flow.atrPoints = 0.0;
   g_flow.candleBodyPoints = 0.0;
   g_flow.upperWickPoints = 0.0;
   g_flow.lowerWickPoints = 0.0;
   g_flow.buyStrength = 0.0;
   g_flow.sellStrength = 0.0;
   g_flow.momentumScore = 0.0;
   g_flow.accelerationScore = 0.0;
   g_flow.rejectionScore = 0.0;
   g_flow.imbalanceScore = 0.0;
   g_flow.direction = FLOW_NONE;

   g_buyStrengthScore = 0.0;
   g_sellStrengthScore = 0.0;
   g_momentumScore = 0.0;
   g_accelerationScore = 0.0;
   g_rejectionScore = 0.0;
   g_buyRejectionScore = 0.0;
   g_sellRejectionScore = 0.0;
   g_imbalanceScore = 0.0;
   g_buyImbalanceScore = 0.0;
   g_sellImbalanceScore = 0.0;
   g_flowDangerScore = 0.0;
   g_flowQualityScore = 0.0;
   g_flowOK = false;
   g_buyFlowDominant = false;
   g_sellFlowDominant = false;
   g_flowBalanced = false;
   g_flowDangerous = false;
   g_flowStatus = "FLOW ENGINE INITIALIZING";
   g_flowReason = "FLOW NOT CHECKED";
   g_flowDirectionText = "FLOW_NONE";
   g_flowDiagnosticReason = "FLOW NOT CHECKED";

   g_market.mode = MARKET_UNKNOWN;
   g_market.strength = MARKET_STRENGTH_UNKNOWN;
   g_market.volatilityScore = 0.0;
   g_market.trendScore = 0.0;
   g_market.dangerScore = 0.0;
   g_market.spreadScore = 0.0;
   g_market.isTradable = false;
   g_market.reason = "MARKET ENGINE INITIALIZING IN STAGE 05";

   g_basket.startTime = 0;
   g_basket.startEquity = 0.0;
   g_basket.netProfit = 0.0;
   g_basket.maxDrawdown = 0.0;
   g_basket.buyLots = 0.0;
   g_basket.sellLots = 0.0;
   g_basket.totalLots = 0.0;
   g_basket.totalPositions = 0;
   g_basket.hedgeCount = 0;
   g_basket.reentryCount = 0;
   g_basket.dominantSide = "NONE";
   g_basket.lastReason = "BASKET ENGINE NOT IMPLEMENTED IN STAGE 05";

   g_risk.dailyStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_risk.dailyHighEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_risk.dailyDrawdownPercent = 0.0;
   g_risk.dailyProfitMoney = 0.0;
   g_risk.protectionMode = EQUITY_NORMAL;
   g_risk.tradingLocked = false;
   g_risk.lockReason = "NONE";

   g_eaStatus = "INITIALIZING";
   g_lastBlockReason = "NONE";
   g_lastEntryReason = "NONE";
   g_lastExitReason = "NONE";
   g_lastAction = "CORE DATA INITIALIZED";

   g_environmentOK = false;
   g_symbolOK = false;
   g_timeframeOK = false;

   g_terminalConnected = false;
   g_mqlTradeAllowed = false;
   g_accountTradeAllowed = false;
   g_liveTradingAllowed = AllowLiveTrading;
   g_priceFeedOK = false;

   g_spreadOK = false;
   g_sessionOK = false;
   g_cooldownOK = false;
   g_marginOK = false;
   g_priceOK = false;
   g_accountSafetyOK = false;
   g_securityFiltersOK = false;
   g_currentSpreadPoints = 0;
   g_lastActionTime = 0;
   g_lastBlockTime = 0;
   g_lastValidTickTime = 0;
   g_spreadStatus = "UNKNOWN";
   g_sessionStatus = "UNKNOWN";
   g_cooldownStatus = "UNKNOWN";
   g_marginStatus = "UNKNOWN";
   g_priceStatus = "UNKNOWN";
   g_accountSafetyStatus = "UNKNOWN";
   g_securityFilterReason = "NOT CHECKED";

   g_atrHandleM1 = INVALID_HANDLE;
   g_atrHandleM5 = INVALID_HANDLE;
   g_atrM1Points = 0.0;
   g_atrM5Points = 0.0;
   g_currentCandleRangePoints = 0.0;
   g_currentCandleBodyPoints = 0.0;
   g_upperWickPoints = 0.0;
   g_lowerWickPoints = 0.0;
   g_averageRangePoints = 0.0;
   g_bodyRatio = 0.0;
   g_upperWickRatio = 0.0;
   g_lowerWickRatio = 0.0;
   g_volatilityStatus = "UNKNOWN";
   g_marketModeStatus = "UNKNOWN";
   g_marketStrengthStatus = "UNKNOWN";
   g_marketDiagnosticReason = "NOT CHECKED";
   g_lastMarketLogTime = 0;
   g_lastMarketLoggedReason = "";
}

//+------------------------------------------------------------------+
//| Validation functions                                             |
//+------------------------------------------------------------------+
bool IsAllowedSymbol()
{
   if(!RestrictToGoldSymbol)
   {
      g_symbolOK = true;
      return true;
   }

   string symbol = _Symbol;
   string key1 = AllowedSymbolKeyword1;
   string key2 = AllowedSymbolKeyword2;

   StringToUpper(symbol);
   StringToUpper(key1);
   StringToUpper(key2);

   if(StringFind(symbol, key1) >= 0 || StringFind(symbol, key2) >= 0)
   {
      if(!g_symbolOK)
         AuditLog("CORE", "SYMBOL VALIDATED: " + _Symbol);

      g_symbolOK = true;
      return true;
   }

   g_symbolOK = false;
   g_lastBlockReason = "INVALID SYMBOL: " + _Symbol;

   if(CanPrintRepeatedLog(g_lastBlockReason))
      AuditLog("BLOCK", "INVALID SYMBOL: " + _Symbol);

   return false;
}

bool IsAllowedTimeframe()
{
   ENUM_TIMEFRAMES currentTF = (ENUM_TIMEFRAMES)_Period;
   bool allowed = false;

   if(currentTF == PERIOD_M1 && AllowM1)
      allowed = true;

   if(currentTF == PERIOD_M5 && AllowM5)
      allowed = true;

   if(allowed)
   {
      if(!g_timeframeOK)
         AuditLog("CORE", "TIMEFRAME VALIDATED: " + TimeframeToText(currentTF));

      g_timeframeOK = true;
      return true;
   }

   g_timeframeOK = false;
   g_lastBlockReason = "INVALID TIMEFRAME: " + TimeframeToText(currentTF);

   if(CanPrintRepeatedLog(g_lastBlockReason))
      AuditLog("BLOCK", "INVALID TIMEFRAME: " + TimeframeToText(currentTF));

   return false;
}

bool IsTradingEnvironmentOK()
{
   g_terminalConnected = (TerminalInfoInteger(TERMINAL_CONNECTED) != 0);
   g_mqlTradeAllowed = (MQLInfoInteger(MQL_TRADE_ALLOWED) != 0);
   g_accountTradeAllowed = (AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) != 0);
   g_liveTradingAllowed = AllowLiveTrading;

   double bid = 0.0;
   double ask = 0.0;
   bool bidOK = SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   bool askOK = SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);

   g_priceFeedOK = (bidOK && askOK && bid > 0.0 && ask > 0.0);

   bool criticalOK = true;

   if(!g_terminalConnected)
   {
      g_lastBlockReason = "TRADING ENVIRONMENT BLOCKED: TERMINAL DISCONNECTED";
      if(CanPrintRepeatedLog(g_lastBlockReason))
         AuditLog("BLOCK", g_lastBlockReason);
      criticalOK = false;
   }

   if(!g_priceFeedOK)
   {
      g_lastBlockReason = "TRADING ENVIRONMENT BLOCKED: INVALID BID/ASK";
      if(CanPrintRepeatedLog(g_lastBlockReason))
         AuditLog("BLOCK", g_lastBlockReason);
      criticalOK = false;
   }

   // Diagnostic only in Stage 05. The EA does not trade in this stage.
   if(!g_mqlTradeAllowed)
   {
      string reason = "MQL TRADE NOT ALLOWED - DIAGNOSTIC ONLY IN STAGE 05";
      if(CanPrintRepeatedLog(reason))
         AuditLog("WARNING", reason);
   }

   if(!g_accountTradeAllowed)
   {
      string reason = "ACCOUNT TRADE NOT ALLOWED - DIAGNOSTIC ONLY IN STAGE 05";
      if(CanPrintRepeatedLog(reason))
         AuditLog("WARNING", reason);
   }

   if(!g_liveTradingAllowed)
   {
      string reason = "ALLOW LIVE TRADING INPUT IS FALSE - DIAGNOSTIC ONLY IN STAGE 05";
      if(CanPrintRepeatedLog(reason))
         AuditLog("WARNING", reason);
   }

   g_environmentOK = criticalOK;

   if(criticalOK)
   {
      if(!g_mqlTradeAllowed || !g_accountTradeAllowed || !g_liveTradingAllowed)
         g_eaStatus = "READY - STAGE 05 DIAGNOSTIC WARNING";
      else if(CanPrintRepeatedLog("TRADING ENVIRONMENT OK"))
         AuditLog("CORE", "TRADING ENVIRONMENT OK");
   }

   return criticalOK;
}

//+------------------------------------------------------------------+
//| Stage 05 - Security filters                                      |
//+------------------------------------------------------------------+
int GetCurrentSpreadPoints()
{
   double ask = 0.0;
   double bid = 0.0;

   bool askOK = SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
   bool bidOK = SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);

   if(!askOK || !bidOK || ask <= 0.0 || bid <= 0.0 || _Point <= 0.0)
   {
      g_currentSpreadPoints = 999999;
      return g_currentSpreadPoints;
   }

   int spread = (int)MathRound((ask - bid) / _Point);

   if(spread < 0)
      spread = 999999;

   g_currentSpreadPoints = spread;
   return spread;
}

bool IsPriceDataOK(string &reason)
{
   if(!UsePriceValidation)
   {
      g_priceOK = true;
      g_priceStatus = "DISABLED";
      return true;
   }

   double bid = 0.0;
   double ask = 0.0;
   bool bidOK = SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
   bool askOK = SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(!bidOK || bid <= 0.0)
   {
      reason = "INVALID BID PRICE";
      g_priceOK = false;
      g_priceStatus = reason;
      return false;
   }

   if(!askOK || ask <= 0.0)
   {
      reason = "INVALID ASK PRICE";
      g_priceOK = false;
      g_priceStatus = reason;
      return false;
   }

   if(_Point <= 0.0)
   {
      reason = "INVALID POINT VALUE";
      g_priceOK = false;
      g_priceStatus = reason;
      return false;
   }

   if(tickSize <= 0.0)
   {
      reason = "INVALID TICK SIZE";
      g_priceOK = false;
      g_priceStatus = reason;
      return false;
   }

   datetime now = TimeCurrent();
   if(now <= 0)
   {
      reason = "STALE TICK DATA";
      g_priceOK = false;
      g_priceStatus = reason;
      return false;
   }

   g_lastValidTickTime = now;

   if(MaxTickAgeSeconds > 0 && g_lastValidTickTime > 0 && (now - g_lastValidTickTime) > MaxTickAgeSeconds)
   {
      reason = "STALE TICK DATA";
      g_priceOK = false;
      g_priceStatus = reason;
      return false;
   }

   reason = "PRICE DATA OK";
   g_priceOK = true;
   g_priceStatus = "OK";
   return true;
}

bool IsSpreadOK(string &reason)
{
   if(!UseSpreadFilter)
   {
      g_spreadOK = true;
      g_spreadStatus = "DISABLED";
      return true;
   }

   int spread = GetCurrentSpreadPoints();

   if(spread >= 999999)
   {
      reason = "INVALID BID ASK FOR SPREAD";
      g_spreadOK = false;
      g_spreadStatus = reason;
      return false;
   }

   if(spread >= ExtremeSpreadPoints)
   {
      reason = "EXTREME SPREAD";
      g_spreadOK = false;
      g_spreadStatus = reason + " (" + IntegerToString(spread) + ")";
      return false;
   }

   if(spread > MaxSpreadPoints)
   {
      reason = "SPREAD TOO HIGH";
      g_spreadOK = false;
      g_spreadStatus = reason + " (" + IntegerToString(spread) + ")";
      return false;
   }

   reason = "SPREAD OK";
   g_spreadOK = true;
   g_spreadStatus = "OK (" + IntegerToString(spread) + ")";
   return true;
}

bool IsSessionOK(string &reason)
{
   if(!UseSessionFilter)
   {
      g_sessionOK = true;
      g_sessionStatus = "DISABLED";
      return true;
   }

   int startHour = TradingStartHour;
   int endHour = TradingEndHour;

   if(startHour < 0) startHour = 0;
   if(startHour > 23) startHour = 23;
   if(endHour < 0) endHour = 0;
   if(endHour > 23) endHour = 23;

   if(startHour == endHour)
   {
      reason = "SESSION OK - 24H MODE";
      g_sessionOK = true;
      g_sessionStatus = reason;
      return true;
   }

   datetime currentTime = (UseServerTimeForSession ? TimeCurrent() : TimeLocal());
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   int hour = dt.hour;

   bool inside = false;

   if(startHour < endHour)
      inside = (hour >= startHour && hour < endHour);
   else
      inside = (hour >= startHour || hour < endHour);

   if(!inside)
   {
      reason = "OUTSIDE TRADING SESSION";
      g_sessionOK = false;
      g_sessionStatus = reason;
      return false;
   }

   reason = "SESSION OK";
   g_sessionOK = true;
   g_sessionStatus = "OK";
   return true;
}

bool IsCooldownOK(string &reason)
{
   if(!UseCooldownFilter)
   {
      g_cooldownOK = true;
      g_cooldownStatus = "DISABLED";
      return true;
   }

   datetime now = TimeCurrent();

   if(g_lastBlockTime > 0 && CooldownSecondsAfterBlock > 0)
   {
      int elapsedBlock = (int)(now - g_lastBlockTime);
      if(elapsedBlock < CooldownSecondsAfterBlock)
      {
         reason = "COOLDOWN AFTER BLOCK ACTIVE";
         g_cooldownOK = false;
         g_cooldownStatus = reason + " (" + IntegerToString(CooldownSecondsAfterBlock - elapsedBlock) + "s)";
         return false;
      }
   }

   if(UseAntiFloodBase && g_lastActionTime > 0 && MinSecondsBetweenActions > 0)
   {
      int elapsedAction = (int)(now - g_lastActionTime);
      if(elapsedAction < MinSecondsBetweenActions)
      {
         reason = "MIN SECONDS BETWEEN ACTIONS ACTIVE";
         g_cooldownOK = false;
         g_cooldownStatus = reason + " (" + IntegerToString(MinSecondsBetweenActions - elapsedAction) + "s)";
         return false;
      }
   }

   reason = "COOLDOWN OK";
   g_cooldownOK = true;
   g_cooldownStatus = "OK";
   return true;
}

bool IsMarginDiagnosticOK(string &reason)
{
   if(!UseMarginDiagnostic)
   {
      g_marginOK = true;
      g_marginStatus = "DISABLED";
      return true;
   }

   double ask = 0.0;
   double bid = 0.0;
   SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
   SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);

   if(ask <= 0.0 || bid <= 0.0 || DiagnosticLotForMarginCheck <= 0.0)
   {
      reason = "MARGIN DIAGNOSTIC WARNING";
      g_marginOK = !StrictMarginDiagnostic;
      g_marginStatus = (StrictMarginDiagnostic ? "BLOCKED" : "WARNING");

      if(StrictMarginDiagnostic)
         return false;

      return true;
   }

   double buyMargin = 0.0;
   double sellMargin = 0.0;
   bool buyCalc = OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, DiagnosticLotForMarginCheck, ask, buyMargin);
   bool sellCalc = OrderCalcMargin(ORDER_TYPE_SELL, _Symbol, DiagnosticLotForMarginCheck, bid, sellMargin);

   if(!buyCalc || !sellCalc)
   {
      reason = "MARGIN DIAGNOSTIC WARNING";
      g_marginOK = !StrictMarginDiagnostic;
      g_marginStatus = (StrictMarginDiagnostic ? "BLOCKED" : "WARNING");

      if(StrictMarginDiagnostic)
      {
         AuditLog("BLOCK", "MARGIN DIAGNOSTIC FAILED - STRICT MODE");
         return false;
      }

      if(CanPrintRepeatedLog("MARGIN DIAGNOSTIC FAILED - NON STRICT MODE"))
         AuditLog("WARNING", "MARGIN DIAGNOSTIC FAILED - NON STRICT MODE");

      return true;
   }

   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double requiredMargin = MathMax(buyMargin, sellMargin);

   if(freeMargin < requiredMargin)
   {
      reason = "LOW FREE MARGIN FOR DIAGNOSTIC LOT";
      g_marginOK = false;
      g_marginStatus = reason;
      return false;
   }

   reason = "MARGIN OK";
   g_marginOK = true;
   g_marginStatus = "OK";
   return true;
}

bool IsAccountSafetyOK(string &reason)
{
   if(!UseAccountSafetyDiagnostic)
   {
      g_accountSafetyOK = true;
      g_accountSafetyStatus = "DISABLED";
      return true;
   }

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

   if(equity <= 0.0)
   {
      reason = "INVALID ACCOUNT EQUITY";
      g_accountSafetyOK = false;
      g_accountSafetyStatus = reason;
      return false;
   }

   if(balance <= 0.0)
   {
      reason = "INVALID ACCOUNT BALANCE";
      g_accountSafetyOK = false;
      g_accountSafetyStatus = reason;
      return false;
   }

   double freeMarginPercent = (freeMargin / equity) * 100.0;

   if(freeMarginPercent < MinFreeMarginPercent)
   {
      reason = "LOW FREE MARGIN PERCENT";
      g_accountSafetyOK = false;
      g_accountSafetyStatus = reason + " (" + DoubleToString(freeMarginPercent, 2) + "%)";
      return false;
   }

   reason = "ACCOUNT SAFETY OK";
   g_accountSafetyOK = true;
   g_accountSafetyStatus = "OK (" + DoubleToString(freeMarginPercent, 2) + "%)";
   return true;
}

void RegisterBlockEvent(string reason)
{
   bool allowUpdate = false;

   if(reason != g_lastBlockReason)
      allowUpdate = true;

   if(CanPrintRepeatedLog("REGISTER_BLOCK:" + reason))
      allowUpdate = true;

   // Do not renew block cooldown because of the cooldown message itself.
   if(reason == "COOLDOWN AFTER BLOCK ACTIVE" || reason == "MIN SECONDS BETWEEN ACTIONS ACTIVE")
      allowUpdate = false;

   if(allowUpdate)
   {
      g_lastBlockTime = TimeCurrent();
      g_lastBlockReason = reason;
      AuditBlock("SECURITY", reason);
   }
   else
   {
      g_lastBlockReason = reason;
   }
}

void RegisterActionEvent(string action)
{
   g_lastActionTime = TimeCurrent();
   g_lastAction = action;

   if(CanPrintRepeatedLog("ACTION:" + action))
      AuditLog("SECURITY", action);
}

bool CanPassSecurityFilters(string &reason)
{
   string localReason = "";

   if(!IsPriceDataOK(localReason))
   {
      reason = localReason;
      g_securityFiltersOK = false;
      g_securityFilterReason = reason;
      RegisterBlockEvent(reason);
      return false;
   }

   if(!IsSpreadOK(localReason))
   {
      reason = localReason;
      g_securityFiltersOK = false;
      g_securityFilterReason = reason;
      RegisterBlockEvent(reason);
      return false;
   }

   if(!IsSessionOK(localReason))
   {
      reason = localReason;
      g_securityFiltersOK = false;
      g_securityFilterReason = reason;
      RegisterBlockEvent(reason);
      return false;
   }

   if(!IsCooldownOK(localReason))
   {
      reason = localReason;
      g_securityFiltersOK = false;
      g_securityFilterReason = reason;
      RegisterBlockEvent(reason);
      return false;
   }

   if(!IsMarginDiagnosticOK(localReason))
   {
      reason = localReason;
      g_securityFiltersOK = false;
      g_securityFilterReason = reason;
      RegisterBlockEvent(reason);
      return false;
   }

   if(!IsAccountSafetyOK(localReason))
   {
      reason = localReason;
      g_securityFiltersOK = false;
      g_securityFilterReason = reason;
      RegisterBlockEvent(reason);
      return false;
   }

   reason = "SECURITY FILTERS OK";
   g_securityFiltersOK = true;
   g_securityFilterReason = reason;

   if(CanPrintRepeatedLog(reason))
      AuditLog("SECURITY", reason);

   return true;
}

void UpdateSecurityFilters()
{
   string reason = "";
   bool result = CanPassSecurityFilters(reason);
   g_securityFiltersOK = result;
   g_securityFilterReason = reason;

   if(!result)
      g_lastBlockReason = reason;
}

//+------------------------------------------------------------------+
//| Daily reset                                                      |
//+------------------------------------------------------------------+
void ResetDailyStatsIfNeeded()
{
   datetime now = TimeCurrent();
   MqlDateTime nowStruct;
   TimeToStruct(now, nowStruct);

   bool mustReset = false;

   if(g_lastDayReset == 0)
      mustReset = true;
   else
   {
      MqlDateTime lastStruct;
      TimeToStruct(g_lastDayReset, lastStruct);

      if(nowStruct.year != lastStruct.year || nowStruct.day_of_year != lastStruct.day_of_year)
         mustReset = true;
   }

   if(!mustReset)
      return;

   g_lastDayReset = now;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   g_risk.dailyStartEquity = equity;
   g_risk.dailyHighEquity = equity;
   g_risk.dailyProfitMoney = 0.0;
   g_risk.dailyDrawdownPercent = 0.0;
   g_risk.protectionMode = EQUITY_NORMAL;
   g_risk.tradingLocked = false;
   g_risk.lockReason = "NONE";

   AuditLog("CORE", "DAILY STATS RESET | Equity=" + DoubleToString(equity, 2));
}

//+------------------------------------------------------------------+
//| Placeholders for future stages                                   |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Stage 05 - ATR / Volatility / Market                             |
//+------------------------------------------------------------------+
bool CanPrintMarketLog(string reason)
{
   datetime now = TimeCurrent();

   if(reason != g_lastMarketLoggedReason)
   {
      g_lastMarketLoggedReason = reason;
      g_lastMarketLogTime = now;
      return true;
   }

   if((now - g_lastMarketLogTime) >= MinSecondsBetweenMarketLogs)
   {
      g_lastMarketLogTime = now;
      return true;
   }

   return false;
}

void AuditMarket(string message)
{
   if(!PrintMarketDiagnostics)
      return;

   if(CanPrintMarketLog(message))
      AuditLog("MARKET", message);
}

bool InitializeATRHandles()
{
   bool ok = true;

   if(g_atrHandleM1 != INVALID_HANDLE)
      IndicatorRelease(g_atrHandleM1);

   if(g_atrHandleM5 != INVALID_HANDLE)
      IndicatorRelease(g_atrHandleM5);

   g_atrHandleM1 = iATR(_Symbol, PERIOD_M1, ATRPeriodM1);
   g_atrHandleM5 = iATR(_Symbol, PERIOD_M5, ATRPeriodM5);

   if(g_atrHandleM1 == INVALID_HANDLE)
   {
      ok = false;
      g_marketDiagnosticReason = "ATR M1 HANDLE WARNING";
      AuditLog("WARNING", "ATR M1 HANDLE WARNING");
   }

   if(g_atrHandleM5 == INVALID_HANDLE)
   {
      ok = false;
      AuditLog("WARNING", "ATR M5 HANDLE WARNING - CONTEXT ONLY");
   }

   if(g_atrHandleM1 != INVALID_HANDLE && g_atrHandleM5 != INVALID_HANDLE)
      AuditLog("MARKET", "ATR HANDLES INITIALIZED");

   return ok;
}

void ReleaseATRHandles()
{
   if(g_atrHandleM1 != INVALID_HANDLE)
   {
      IndicatorRelease(g_atrHandleM1);
      g_atrHandleM1 = INVALID_HANDLE;
   }

   if(g_atrHandleM5 != INVALID_HANDLE)
   {
      IndicatorRelease(g_atrHandleM5);
      g_atrHandleM5 = INVALID_HANDLE;
   }

   AuditLog("MARKET", "ATR HANDLES RELEASED");
}

double GetATRPoints(int handle)
{
   if(handle == INVALID_HANDLE || _Point <= 0.0)
      return 0.0;

   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);

   int copied = CopyBuffer(handle, 0, 0, 1, atrBuffer);

   if(copied <= 0)
      return 0.0;

   double atrValue = atrBuffer[0];

   if(atrValue <= 0.0)
      return 0.0;

   return (atrValue / _Point);
}

bool UpdateATRData()
{
   if(!UseATRVolatilityEngine)
   {
      g_atrM1Points = 0.0;
      g_atrM5Points = 0.0;
      g_flow.atrPoints = 0.0;
      g_volatilityStatus = "ATR ENGINE DISABLED";
      return true;
   }

   g_atrM1Points = GetATRPoints(g_atrHandleM1);
   g_atrM5Points = GetATRPoints(g_atrHandleM5);
   g_flow.atrPoints = g_atrM1Points;

   if(g_atrM1Points <= 0.0)
   {
      g_marketDiagnosticReason = "ATR M1 UNAVAILABLE";
      g_volatilityStatus = "ATR M1 UNAVAILABLE";
      if(CanPrintMarketLog("ATR M1 UNAVAILABLE"))
         AuditLog("BLOCK", "ATR M1 UNAVAILABLE");
      return false;
   }

   if(g_atrM5Points <= 0.0)
   {
      if(CanPrintMarketLog("ATR M5 UNAVAILABLE - CONTEXT ONLY"))
         AuditLog("WARNING", "ATR M5 UNAVAILABLE - CONTEXT ONLY");
   }

   AuditMarket("ATR DATA UPDATED");
   return true;
}

double GetCandleRangePoints(int shift)
{
   double highValue = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);
   double lowValue = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);

   if(highValue <= 0.0 || lowValue <= 0.0 || highValue < lowValue || _Point <= 0.0)
      return 0.0;

   return ((highValue - lowValue) / _Point);
}

double GetCandleBodyPoints(int shift)
{
   double openValue = iOpen(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);
   double closeValue = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);

   if(openValue <= 0.0 || closeValue <= 0.0 || _Point <= 0.0)
      return 0.0;

   return (MathAbs(closeValue - openValue) / _Point);
}

double GetUpperWickPoints(int shift)
{
   double openValue = iOpen(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);
   double closeValue = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);
   double highValue = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);

   if(openValue <= 0.0 || closeValue <= 0.0 || highValue <= 0.0 || _Point <= 0.0)
      return 0.0;

   double topBody = MathMax(openValue, closeValue);
   double wick = highValue - topBody;

   if(wick < 0.0)
      wick = 0.0;

   return (wick / _Point);
}

double GetLowerWickPoints(int shift)
{
   double openValue = iOpen(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);
   double closeValue = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);
   double lowValue = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);

   if(openValue <= 0.0 || closeValue <= 0.0 || lowValue <= 0.0 || _Point <= 0.0)
      return 0.0;

   double bottomBody = MathMin(openValue, closeValue);
   double wick = bottomBody - lowValue;

   if(wick < 0.0)
      wick = 0.0;

   return (wick / _Point);
}

double GetAverageRangePoints(int lookback)
{
   int safeLookback = lookback;

   if(safeLookback <= 0)
      safeLookback = 1;

   double totalRange = 0.0;
   int counted = 0;

   for(int shift = 1; shift <= safeLookback; shift++)
   {
      double rangePoints = GetCandleRangePoints(shift);

      if(rangePoints > 0.0)
      {
         totalRange += rangePoints;
         counted++;
      }
   }

   if(counted <= 0)
      return 0.0;

   return (totalRange / (double)counted);
}

void UpdateCandleMetrics()
{
   int shift = (UseClosedCandleForMarketAnalysis ? 1 : 0);

   g_currentCandleRangePoints = GetCandleRangePoints(shift);
   g_currentCandleBodyPoints = GetCandleBodyPoints(shift);
   g_upperWickPoints = GetUpperWickPoints(shift);
   g_lowerWickPoints = GetLowerWickPoints(shift);
   g_averageRangePoints = GetAverageRangePoints(CandleLookbackForAverageRange);

   if(g_currentCandleRangePoints > 0.0)
   {
      g_bodyRatio = g_currentCandleBodyPoints / g_currentCandleRangePoints;
      g_upperWickRatio = g_upperWickPoints / g_currentCandleRangePoints;
      g_lowerWickRatio = g_lowerWickPoints / g_currentCandleRangePoints;
   }
   else
   {
      g_bodyRatio = 0.0;
      g_upperWickRatio = 0.0;
      g_lowerWickRatio = 0.0;
   }

   g_flow.candleBodyPoints = g_currentCandleBodyPoints;
   g_flow.upperWickPoints = g_upperWickPoints;
   g_flow.lowerWickPoints = g_lowerWickPoints;

   AuditMarket("CANDLE METRICS UPDATED");
}

bool IsVolatilityDead()
{
   return (UseATRVolatilityEngine && g_atrM1Points > 0.0 && g_atrM1Points < MinATRPointsForActiveMarket);
}

bool IsVolatilityHealthy()
{
   return (UseATRVolatilityEngine && g_atrM1Points >= HealthyATRMinPoints && g_atrM1Points <= HealthyATRMaxPoints);
}

bool IsVolatilityExplosive()
{
   return (UseATRVolatilityEngine && g_atrM1Points >= ExplosiveATRPoints);
}

bool IsVolatilityDangerous()
{
   return (UseATRVolatilityEngine && g_atrM1Points >= DangerousATRPoints);
}

ENUM_MARKET_STRENGTH DetectMarketStrength()
{
   if(!UseMarketClassification)
      return MARKET_STRENGTH_UNKNOWN;

   if(g_atrM1Points <= 0.0 || g_currentCandleRangePoints <= 0.0)
      return MARKET_STRENGTH_UNKNOWN;

   if(g_atrM1Points >= DangerousATRPoints)
      return MARKET_STRENGTH_STRONG;

   if(g_atrM1Points < MinATRPointsForActiveMarket ||
      g_currentCandleRangePoints < MinCandleRangePoints ||
      g_bodyRatio < SmallCandleBodyRatio)
      return MARKET_STRENGTH_WEAK;

   bool strongRange = (g_averageRangePoints > 0.0 && g_currentCandleRangePoints > (g_averageRangePoints * TrendRangeMultiplier));

   if(g_atrM1Points >= HealthyATRMaxPoints || (strongRange && g_bodyRatio >= StrongCandleBodyRatio))
      return MARKET_STRENGTH_STRONG;

   if(g_atrM1Points >= HealthyATRMinPoints && g_atrM1Points <= HealthyATRMaxPoints && g_bodyRatio >= SmallCandleBodyRatio)
      return MARKET_STRENGTH_MEDIUM;

   return MARKET_STRENGTH_WEAK;
}

ENUM_MARKET_MODE DetectMarketMode()
{
   if(!UseMarketClassification)
      return MARKET_UNKNOWN;

   if(g_currentSpreadPoints >= ExtremeSpreadPoints)
      return MARKET_SPREAD_DANGER;

   if(g_atrM1Points <= 0.0)
      return MARKET_UNKNOWN;

   if(g_atrM1Points < MinATRPointsForActiveMarket ||
      (g_averageRangePoints > 0.0 && g_averageRangePoints < MinCandleRangePoints))
      return MARKET_DEAD;

   if(g_atrM1Points >= DangerousATRPoints)
      return MARKET_EXPLOSIVE;

   if(g_atrM1Points >= ExplosiveATRPoints ||
      (g_averageRangePoints > 0.0 && g_currentCandleRangePoints > (g_averageRangePoints * ExplosiveRangeMultiplier)))
      return MARKET_EXPLOSIVE;

   bool erraticWicks = (g_upperWickRatio >= ErraticWickThreshold || g_lowerWickRatio >= ErraticWickThreshold ||
                        g_upperWickRatio >= LargeWickRatio || g_lowerWickRatio >= LargeWickRatio);

   if(erraticWicks && g_bodyRatio <= SmallCandleBodyRatio)
      return MARKET_ERRATIC;

   bool rangeNearAverage = (g_averageRangePoints > 0.0 && g_currentCandleRangePoints <= (g_averageRangePoints * SidewaysRangeMultiplier));

   if(rangeNearAverage && g_bodyRatio < StrongCandleBodyRatio)
      return MARKET_SIDEWAYS;

   int shift = (UseClosedCandleForMarketAnalysis ? 1 : 0);
   double openValue = iOpen(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);
   double closeValue = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);
   bool trendRange = (g_averageRangePoints > 0.0 && g_currentCandleRangePoints >= (g_averageRangePoints * TrendRangeMultiplier));

   if(openValue > 0.0 && closeValue > 0.0 && g_bodyRatio >= StrongCandleBodyRatio && trendRange)
   {
      if(closeValue > openValue)
         return MARKET_TREND_BUY;

      if(closeValue < openValue)
         return MARKET_TREND_SELL;
   }

   return MARKET_SIDEWAYS;
}

bool IsMarketTradableByVolatility(string &reason)
{
   if(!UseATRVolatilityEngine)
   {
      reason = "ATR VOLATILITY ENGINE DISABLED";
      return true;
   }

   if(g_atrM1Points <= 0.0)
   {
      reason = "ATR M1 UNAVAILABLE";
      return false;
   }

   if(IsVolatilityDead())
   {
      reason = "VOLATILITY DEAD";
      return false;
   }

   if(IsVolatilityDangerous())
   {
      reason = "VOLATILITY DANGEROUS";
      return false;
   }

   if(UseMarketClassification && g_market.mode == MARKET_ERRATIC)
   {
      reason = "MARKET ERRATIC";
      return false;
   }

   reason = "MARKET TRADABLE BY VOLATILITY";
   return true;
}

void UpdateMarketData()
{
   bool atrOK = UpdateATRData();

   UpdateCandleMetrics();

   if(!UseATRVolatilityEngine)
   {
      g_market.mode = MARKET_UNKNOWN;
      g_market.strength = MARKET_STRENGTH_UNKNOWN;
      g_market.volatilityScore = 0.0;
      g_market.trendScore = 0.0;
      g_market.dangerScore = 0.0;
      g_market.spreadScore = (g_currentSpreadPoints > 0 ? (double)g_currentSpreadPoints : 0.0);
      g_market.isTradable = true;
      g_market.reason = "ATR VOLATILITY ENGINE DISABLED";
      g_volatilityStatus = "DISABLED";
      g_marketModeStatus = MarketModeToText(g_market.mode);
      g_marketStrengthStatus = MarketStrengthToText(g_market.strength);
      g_marketDiagnosticReason = g_market.reason;
      return;
   }

   if(!atrOK)
   {
      g_market.mode = MARKET_UNKNOWN;
      g_market.strength = MARKET_STRENGTH_UNKNOWN;
      g_market.volatilityScore = 0.0;
      g_market.trendScore = 0.0;
      g_market.dangerScore = 100.0;
      g_market.spreadScore = (double)g_currentSpreadPoints;
      g_market.isTradable = false;
      g_market.reason = "ATR M1 UNAVAILABLE";
      g_volatilityStatus = "ATR M1 UNAVAILABLE";
      g_marketModeStatus = MarketModeToText(g_market.mode);
      g_marketStrengthStatus = MarketStrengthToText(g_market.strength);
      g_marketDiagnosticReason = g_market.reason;
      return;
   }

   if(!UseMarketClassification)
   {
      g_market.mode = MARKET_UNKNOWN;
      g_market.strength = MARKET_STRENGTH_UNKNOWN;
      g_market.isTradable = (!IsVolatilityDead() && !IsVolatilityDangerous());
      g_market.reason = "MARKET CLASSIFICATION DISABLED - BASIC VOLATILITY ONLY";
   }
   else
   {
      g_market.strength = DetectMarketStrength();
      g_market.mode = DetectMarketMode();

      string reason = "";
      g_market.isTradable = IsMarketTradableByVolatility(reason);
      g_market.reason = reason;
   }

   if(IsVolatilityDangerous())
      g_volatilityStatus = "VOLATILITY DANGEROUS";
   else if(IsVolatilityExplosive())
      g_volatilityStatus = "VOLATILITY EXPLOSIVE";
   else if(IsVolatilityHealthy())
      g_volatilityStatus = "VOLATILITY HEALTHY";
   else if(IsVolatilityDead())
      g_volatilityStatus = "VOLATILITY DEAD";
   else
      g_volatilityStatus = "VOLATILITY MODERATE";

   g_marketModeStatus = MarketModeToText(g_market.mode);
   g_marketStrengthStatus = MarketStrengthToText(g_market.strength);
   g_marketDiagnosticReason = g_market.reason;

   g_market.volatilityScore = MathMin(100.0, (g_atrM1Points / MathMax(HealthyATRMaxPoints, 1.0)) * 100.0);
   g_market.trendScore = MathMin(100.0, g_bodyRatio * 100.0);
   g_market.dangerScore = 0.0;

   if(IsVolatilityDangerous())
      g_market.dangerScore += 70.0;

   if(g_market.mode == MARKET_ERRATIC)
      g_market.dangerScore += 30.0;

   if(g_market.mode == MARKET_SPREAD_DANGER)
      g_market.dangerScore += 50.0;

   if(g_market.dangerScore > 100.0)
      g_market.dangerScore = 100.0;

   g_market.spreadScore = (double)g_currentSpreadPoints;

   AuditMarket(g_marketStrengthStatus);
   AuditMarket(g_marketModeStatus);
   AuditMarket(g_volatilityStatus);
}

//+------------------------------------------------------------------+
//| Stage 05 - Flow Engine                                            |
//+------------------------------------------------------------------+
int GetFlowShift()
{
   return (UseClosedCandleForFlowAnalysis ? 1 : 0);
}

double ClampFlowScore(double value)
{
   if(value < 0.0)
      return 0.0;

   if(value > 100.0)
      return 100.0;

   return value;
}

double NormalizeFlowScore(double value, double minValue, double maxValue)
{
   if(maxValue <= minValue)
      return 0.0;

   double score = ((value - minValue) / (maxValue - minValue)) * 100.0;
   return ClampFlowScore(score);
}

bool CanPrintFlowLog(string reason)
{
   datetime now = TimeCurrent();

   if(reason != g_lastFlowLoggedReason)
   {
      g_lastFlowLoggedReason = reason;
      g_lastFlowLogTime = now;
      return true;
   }

   if((now - g_lastFlowLogTime) >= MinSecondsBetweenFlowLogs)
   {
      g_lastFlowLogTime = now;
      return true;
   }

   return false;
}

void AuditFlow(string message)
{
   if(!PrintFlowDiagnostics)
      return;

   if(CanPrintFlowLog(message))
      AuditLog("FLOW", message);
}

string FlowDirectionToText(ENUM_FLOW_DIRECTION direction)
{
   switch(direction)
   {
      case FLOW_NONE:        return "FLOW_NONE";
      case FLOW_BUY_WEAK:    return "FLOW_BUY_WEAK";
      case FLOW_BUY_STRONG:  return "FLOW_BUY_STRONG";
      case FLOW_SELL_WEAK:   return "FLOW_SELL_WEAK";
      case FLOW_SELL_STRONG: return "FLOW_SELL_STRONG";
      case FLOW_BALANCED:    return "FLOW_BALANCED";
      case FLOW_DANGEROUS:   return "FLOW_DANGEROUS";
      default:               return "FLOW_UNKNOWN";
   }
}

double CalculateBuyStrength()
{
   int shift = GetFlowShift();
   double openValue = iOpen(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);
   double highValue = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);
   double lowValue = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);
   double closeValue = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);

   if(openValue <= 0.0 || highValue <= 0.0 || lowValue <= 0.0 || closeValue <= 0.0 || highValue <= lowValue)
      return 0.0;

   double rangePoints = GetCandleRangePoints(shift);
   double bodyPoints = GetCandleBodyPoints(shift);
   double upperWickPoints = GetUpperWickPoints(shift);
   double lowerWickPoints = GetLowerWickPoints(shift);

   if(rangePoints <= 0.0)
      return 0.0;

   double bodyRatio = bodyPoints / rangePoints;
   double closeLocation = (closeValue - lowValue) / (highValue - lowValue);
   double score = 0.0;

   if(closeValue > openValue)
      score += 22.0;

   if(bodyRatio >= StrongCandleBodyRatio)
      score += 18.0;
   else if(bodyRatio >= SmallCandleBodyRatio)
      score += 8.0;

   if(closeLocation >= 0.66)
      score += 18.0;
   else if(closeLocation >= 0.50)
      score += 8.0;

   if(lowerWickPoints > upperWickPoints)
      score += 12.0;

   if(g_averageRangePoints > 0.0 && rangePoints > g_averageRangePoints)
      score += 12.0;

   if(IsVolatilityHealthy())
      score += 10.0;
   else if(IsVolatilityExplosive() && !IsVolatilityDangerous())
      score += 6.0;

   if(g_market.mode == MARKET_TREND_BUY)
      score += 8.0;

   return ClampFlowScore(score);
}

double CalculateSellStrength()
{
   int shift = GetFlowShift();
   double openValue = iOpen(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);
   double highValue = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);
   double lowValue = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);
   double closeValue = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);

   if(openValue <= 0.0 || highValue <= 0.0 || lowValue <= 0.0 || closeValue <= 0.0 || highValue <= lowValue)
      return 0.0;

   double rangePoints = GetCandleRangePoints(shift);
   double bodyPoints = GetCandleBodyPoints(shift);
   double upperWickPoints = GetUpperWickPoints(shift);
   double lowerWickPoints = GetLowerWickPoints(shift);

   if(rangePoints <= 0.0)
      return 0.0;

   double bodyRatio = bodyPoints / rangePoints;
   double closeLocation = (closeValue - lowValue) / (highValue - lowValue);
   double score = 0.0;

   if(closeValue < openValue)
      score += 22.0;

   if(bodyRatio >= StrongCandleBodyRatio)
      score += 18.0;
   else if(bodyRatio >= SmallCandleBodyRatio)
      score += 8.0;

   if(closeLocation <= 0.34)
      score += 18.0;
   else if(closeLocation <= 0.50)
      score += 8.0;

   if(upperWickPoints > lowerWickPoints)
      score += 12.0;

   if(g_averageRangePoints > 0.0 && rangePoints > g_averageRangePoints)
      score += 12.0;

   if(IsVolatilityHealthy())
      score += 10.0;
   else if(IsVolatilityExplosive() && !IsVolatilityDangerous())
      score += 6.0;

   if(g_market.mode == MARKET_TREND_SELL)
      score += 8.0;

   return ClampFlowScore(score);
}

double CalculateMomentumScore()
{
   int lookback = MomentumLookbackCandles;

   if(lookback < 1)
      lookback = 1;

   int shift = GetFlowShift();
   double currentClose = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);
   double oldClose = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, shift + lookback);

   if(currentClose <= 0.0 || oldClose <= 0.0 || _Point <= 0.0)
      return 0.0;

   double displacementPoints = MathAbs(currentClose - oldClose) / _Point;
   double atrReference = MathMax(g_atrM1Points, 1.0);
   double score = NormalizeFlowScore(displacementPoints, 0.0, atrReference);

   int bullish = 0;
   int bearish = 0;

   for(int i = shift; i < shift + lookback; i++)
   {
      double openValue = iOpen(_Symbol, (ENUM_TIMEFRAMES)_Period, i);
      double closeValue = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, i);

      if(openValue <= 0.0 || closeValue <= 0.0)
         continue;

      if(closeValue > openValue)
         bullish++;
      else if(closeValue < openValue)
         bearish++;
   }

   int directionalCount = MathMax(bullish, bearish);
   double consistency = ((double)directionalCount / (double)MathMax(lookback, 1)) * 25.0;
   score += consistency;

   double recentAverage = GetAverageRangePoints(lookback);

   if(g_averageRangePoints > 0.0 && recentAverage > g_averageRangePoints)
      score += 10.0;

   if(score >= StrongMomentumScore)
      score += 5.0;
   else if(score < MinMomentumScore)
      score -= 5.0;

   return ClampFlowScore(score);
}

double CalculateAccelerationScore()
{
   int shift = GetFlowShift();
   int lookback = MomentumLookbackCandles;

   if(lookback < 2)
      lookback = 2;

   double currentRange = GetCandleRangePoints(shift);
   double currentBody = GetCandleBodyPoints(shift);

   if(currentRange <= 0.0)
      return 0.0;

   double previousRangeTotal = 0.0;
   double previousBodyTotal = 0.0;
   int counted = 0;

   for(int i = shift + 1; i <= shift + lookback; i++)
   {
      double rangePoints = GetCandleRangePoints(i);
      double bodyPoints = GetCandleBodyPoints(i);

      if(rangePoints > 0.0)
      {
         previousRangeTotal += rangePoints;
         previousBodyTotal += bodyPoints;
         counted++;
      }
   }

   if(counted <= 0)
      return 0.0;

   double averagePreviousRange = previousRangeTotal / (double)counted;
   double averagePreviousBody = previousBodyTotal / (double)counted;
   double score = 0.0;

   if(averagePreviousRange > 0.0)
      score += NormalizeFlowScore(currentRange, averagePreviousRange * 0.70, averagePreviousRange * 1.80) * 0.45;

   if(averagePreviousBody > 0.0)
      score += NormalizeFlowScore(currentBody, averagePreviousBody * 0.70, averagePreviousBody * 1.80) * 0.35;

   if(IsVolatilityExplosive() && !IsVolatilityDangerous())
      score += 15.0;
   else if(IsVolatilityHealthy())
      score += 8.0;

   if(score >= StrongAccelerationScore)
      score += 5.0;
   else if(score < MinAccelerationScore)
      score -= 5.0;

   return ClampFlowScore(score);
}

double CalculateBuyRejectionScore()
{
   if(!UseRejectionAnalysis)
      return 0.0;

   int shift = GetFlowShift();
   double openValue = iOpen(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);
   double highValue = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);
   double lowValue = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);
   double closeValue = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);
   double rangePoints = GetCandleRangePoints(shift);

   if(openValue <= 0.0 || highValue <= 0.0 || lowValue <= 0.0 || closeValue <= 0.0 || rangePoints <= 0.0 || highValue <= lowValue)
      return 0.0;

   double lowerWickPoints = GetLowerWickPoints(shift);
   double upperWickPoints = GetUpperWickPoints(shift);
   double lowerWickRatio = lowerWickPoints / rangePoints;
   double closeLocation = (closeValue - lowValue) / (highValue - lowValue);
   double score = 0.0;

   if(lowerWickRatio >= RejectionWickRatioThreshold)
      score += 35.0;

   if(closeValue > openValue)
      score += 20.0;

   if(closeLocation >= 0.66)
      score += 20.0;

   if(lowerWickPoints > upperWickPoints)
      score += 15.0;

   if(score >= StrongRejectionScore)
      score += 10.0;
   else if(score < MinRejectionScore)
      score -= 5.0;

   return ClampFlowScore(score);
}

double CalculateSellRejectionScore()
{
   if(!UseRejectionAnalysis)
      return 0.0;

   int shift = GetFlowShift();
   double openValue = iOpen(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);
   double highValue = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);
   double lowValue = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);
   double closeValue = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);
   double rangePoints = GetCandleRangePoints(shift);

   if(openValue <= 0.0 || highValue <= 0.0 || lowValue <= 0.0 || closeValue <= 0.0 || rangePoints <= 0.0 || highValue <= lowValue)
      return 0.0;

   double upperWickPoints = GetUpperWickPoints(shift);
   double lowerWickPoints = GetLowerWickPoints(shift);
   double upperWickRatio = upperWickPoints / rangePoints;
   double closeLocation = (closeValue - lowValue) / (highValue - lowValue);
   double score = 0.0;

   if(upperWickRatio >= RejectionWickRatioThreshold)
      score += 35.0;

   if(closeValue < openValue)
      score += 20.0;

   if(closeLocation <= 0.34)
      score += 20.0;

   if(upperWickPoints > lowerWickPoints)
      score += 15.0;

   if(score >= StrongRejectionScore)
      score += 10.0;
   else if(score < MinRejectionScore)
      score -= 5.0;

   return ClampFlowScore(score);
}

double CalculateRejectionScore()
{
   g_buyRejectionScore = CalculateBuyRejectionScore();
   g_sellRejectionScore = CalculateSellRejectionScore();
   g_flow.rejectionScore = MathMax(g_buyRejectionScore, g_sellRejectionScore);
   return g_flow.rejectionScore;
}

double CalculateBuyImbalanceScore()
{
   if(!UseImbalanceAnalysis)
      return 0.0;

   int lookback = FlowLookbackCandles;

   if(lookback < 1)
      lookback = 1;

   int shift = GetFlowShift();
   int bullish = 0;
   int closesAscending = 0;
   int lowsAscending = 0;
   double bodyTotal = 0.0;
   int bodyCount = 0;

   for(int i = shift; i < shift + lookback; i++)
   {
      double openValue = iOpen(_Symbol, (ENUM_TIMEFRAMES)_Period, i);
      double closeValue = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, i);
      double previousClose = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, i + 1);
      double lowValue = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, i);
      double previousLow = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, i + 1);

      if(openValue <= 0.0 || closeValue <= 0.0)
         continue;

      if(closeValue > openValue)
         bullish++;

      if(previousClose > 0.0 && closeValue > previousClose)
         closesAscending++;

      if(previousLow > 0.0 && lowValue > previousLow)
         lowsAscending++;

      bodyTotal += MathAbs(closeValue - openValue) / _Point;
      bodyCount++;
   }

   double score = 0.0;
   score += ((double)bullish / (double)MathMax(lookback, 1)) * 25.0;
   score += ((double)closesAscending / (double)MathMax(lookback, 1)) * 20.0;
   score += ((double)lowsAscending / (double)MathMax(lookback, 1)) * 20.0;

   if(bodyCount > 0 && g_averageRangePoints > 0.0)
   {
      double averageBody = bodyTotal / (double)bodyCount;
      score += NormalizeFlowScore(averageBody, 0.0, g_averageRangePoints) * 0.15;
   }

   if(g_buyStrengthScore > g_sellStrengthScore)
      score += 12.0;

   if(g_momentumScore >= MinMomentumScore)
      score += 8.0;

   if(score >= StrongImbalanceScore)
      score += 5.0;
   else if(score < MinImbalanceScore)
      score -= 5.0;

   return ClampFlowScore(score);
}

double CalculateSellImbalanceScore()
{
   if(!UseImbalanceAnalysis)
      return 0.0;

   int lookback = FlowLookbackCandles;

   if(lookback < 1)
      lookback = 1;

   int shift = GetFlowShift();
   int bearish = 0;
   int closesDescending = 0;
   int highsDescending = 0;
   double bodyTotal = 0.0;
   int bodyCount = 0;

   for(int i = shift; i < shift + lookback; i++)
   {
      double openValue = iOpen(_Symbol, (ENUM_TIMEFRAMES)_Period, i);
      double closeValue = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, i);
      double previousClose = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, i + 1);
      double highValue = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, i);
      double previousHigh = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, i + 1);

      if(openValue <= 0.0 || closeValue <= 0.0)
         continue;

      if(closeValue < openValue)
         bearish++;

      if(previousClose > 0.0 && closeValue < previousClose)
         closesDescending++;

      if(previousHigh > 0.0 && highValue < previousHigh)
         highsDescending++;

      bodyTotal += MathAbs(closeValue - openValue) / _Point;
      bodyCount++;
   }

   double score = 0.0;
   score += ((double)bearish / (double)MathMax(lookback, 1)) * 25.0;
   score += ((double)closesDescending / (double)MathMax(lookback, 1)) * 20.0;
   score += ((double)highsDescending / (double)MathMax(lookback, 1)) * 20.0;

   if(bodyCount > 0 && g_averageRangePoints > 0.0)
   {
      double averageBody = bodyTotal / (double)bodyCount;
      score += NormalizeFlowScore(averageBody, 0.0, g_averageRangePoints) * 0.15;
   }

   if(g_sellStrengthScore > g_buyStrengthScore)
      score += 12.0;

   if(g_momentumScore >= MinMomentumScore)
      score += 8.0;

   if(score >= StrongImbalanceScore)
      score += 5.0;
   else if(score < MinImbalanceScore)
      score -= 5.0;

   return ClampFlowScore(score);
}

double CalculateImbalanceScore()
{
   g_buyImbalanceScore = CalculateBuyImbalanceScore();
   g_sellImbalanceScore = CalculateSellImbalanceScore();
   g_flow.imbalanceScore = MathMax(g_buyImbalanceScore, g_sellImbalanceScore);
   return g_flow.imbalanceScore;
}

double CalculateFlowDangerScore()
{
   double score = 0.0;

   if(g_market.mode == MARKET_ERRATIC)
      score += 25.0;

   if(g_market.mode == MARKET_SPREAD_DANGER)
      score += 25.0;

   if(IsVolatilityDangerous())
      score += 35.0;

   if(g_upperWickRatio >= LargeWickRatio && g_lowerWickRatio >= LargeWickRatio)
      score += 20.0;

   if(g_bodyRatio <= SmallCandleBodyRatio)
      score += 15.0;

   if(MathAbs(g_buyStrengthScore - g_sellStrengthScore) <= MaxBalancedFlowDifference)
      score += 10.0;

   if(g_currentSpreadPoints >= ExtremeSpreadPoints)
      score += 25.0;

   if(g_averageRangePoints > 0.0 && g_currentCandleRangePoints > g_averageRangePoints * ExplosiveRangeMultiplier && g_bodyRatio < SmallCandleBodyRatio)
      score += 20.0;

   return ClampFlowScore(score);
}

double CalculateFlowQualityScore()
{
   double directionalStrength = MathMax(g_buyStrengthScore, g_sellStrengthScore);
   double dominance = MathAbs(g_buyStrengthScore - g_sellStrengthScore);

   double quality =
      directionalStrength * 0.35 +
      g_momentumScore * 0.20 +
      g_accelerationScore * 0.15 +
      g_rejectionScore * 0.10 +
      g_imbalanceScore * 0.15 +
      dominance * 0.05 -
      g_flowDangerScore * 0.30;

   g_flowQualityScore = ClampFlowScore(quality);
   return g_flowQualityScore;
}

ENUM_FLOW_DIRECTION DetectFlowDirection()
{
   double diff = MathAbs(g_buyStrengthScore - g_sellStrengthScore);

   if(g_flowDangerScore >= MaxDangerousFlowScore)
      return FLOW_DANGEROUS;

   if(diff <= MaxBalancedFlowDifference)
      return FLOW_BALANCED;

   if(g_buyStrengthScore > g_sellStrengthScore)
   {
      if(g_buyStrengthScore >= StrongDirectionalStrength)
         return FLOW_BUY_STRONG;

      return FLOW_BUY_WEAK;
   }

   if(g_sellStrengthScore > g_buyStrengthScore)
   {
      if(g_sellStrengthScore >= StrongDirectionalStrength)
         return FLOW_SELL_STRONG;

      return FLOW_SELL_WEAK;
   }

   return FLOW_NONE;
}

bool IsFlowBalanced()
{
   double diff = MathAbs(g_buyStrengthScore - g_sellStrengthScore);

   if(diff <= MaxBalancedFlowDifference)
      return true;

   if(g_flow.direction == FLOW_BALANCED)
      return true;

   if(g_buyStrengthScore < MinDirectionalStrength && g_sellStrengthScore < MinDirectionalStrength)
      return true;

   return false;
}

bool IsFlowDangerous()
{
   if(g_flowDangerScore >= MaxDangerousFlowScore)
      return true;

   if(g_flow.direction == FLOW_DANGEROUS)
      return true;

   if(g_market.mode == MARKET_ERRATIC || g_market.mode == MARKET_SPREAD_DANGER)
      return true;

   if(IsVolatilityDangerous())
      return true;

   if(g_currentSpreadPoints >= ExtremeSpreadPoints)
      return true;

   return false;
}

bool IsFlowTradable(string &reason)
{
   if(!UseFlowEngine)
   {
      reason = "FLOW DISABLED - PASS";
      return true;
   }

   if(BlockDangerousFlow && IsFlowDangerous())
   {
      reason = "FLOW DANGEROUS";
      return false;
   }

   if(IsFlowBalanced())
   {
      reason = "FLOW BALANCED";

      if(BlockBalancedFlow)
         return false;

      return true;
   }

   if(g_flowQualityScore < MinDirectionalStrength)
   {
      reason = "FLOW QUALITY TOO LOW";

      if(StrictFlowFilter)
         return false;

      return true;
   }

   if(!g_buyFlowDominant && !g_sellFlowDominant)
   {
      reason = "NO FLOW DOMINANCE";

      if(StrictFlowFilter)
         return false;

      return true;
   }

   reason = "FLOW OK";
   return true;
}

void UpdateFlowData()
{
   if(!UseFlowEngine)
   {
      g_buyStrengthScore = 0.0;
      g_sellStrengthScore = 0.0;
      g_momentumScore = 0.0;
      g_accelerationScore = 0.0;
      g_rejectionScore = 0.0;
      g_buyRejectionScore = 0.0;
      g_sellRejectionScore = 0.0;
      g_imbalanceScore = 0.0;
      g_buyImbalanceScore = 0.0;
      g_sellImbalanceScore = 0.0;
      g_flowDangerScore = 0.0;
      g_flowQualityScore = 0.0;

      g_flow.buyStrength = 0.0;
      g_flow.sellStrength = 0.0;
      g_flow.momentumScore = 0.0;
      g_flow.accelerationScore = 0.0;
      g_flow.rejectionScore = 0.0;
      g_flow.imbalanceScore = 0.0;
      g_flow.direction = FLOW_NONE;

      g_flowOK = true;
      g_buyFlowDominant = false;
      g_sellFlowDominant = false;
      g_flowBalanced = false;
      g_flowDangerous = false;
      g_flowStatus = "FLOW ENGINE DISABLED";
      g_flowReason = "FLOW DISABLED - PASS";
      g_flowDirectionText = "FLOW_NONE";
      g_flowDiagnosticReason = g_flowReason;
      return;
   }

   g_buyStrengthScore = CalculateBuyStrength();
   g_sellStrengthScore = CalculateSellStrength();
   g_momentumScore = CalculateMomentumScore();
   g_accelerationScore = CalculateAccelerationScore();
   g_rejectionScore = CalculateRejectionScore();
   g_imbalanceScore = CalculateImbalanceScore();
   g_flowDangerScore = CalculateFlowDangerScore();
   g_flowQualityScore = CalculateFlowQualityScore();

   g_flow.buyStrength = g_buyStrengthScore;
   g_flow.sellStrength = g_sellStrengthScore;
   g_flow.momentumScore = g_momentumScore;
   g_flow.accelerationScore = g_accelerationScore;
   g_flow.rejectionScore = g_rejectionScore;
   g_flow.imbalanceScore = g_imbalanceScore;
   g_flow.direction = DetectFlowDirection();

   double dominance = MathAbs(g_buyStrengthScore - g_sellStrengthScore);
   g_buyFlowDominant = (g_buyStrengthScore > g_sellStrengthScore && dominance >= DominanceDifferenceThreshold);
   g_sellFlowDominant = (g_sellStrengthScore > g_buyStrengthScore && dominance >= DominanceDifferenceThreshold);
   g_flowBalanced = IsFlowBalanced();
   g_flowDangerous = IsFlowDangerous();
   g_flowDirectionText = FlowDirectionToText(g_flow.direction);

   string reason = "";
   g_flowOK = IsFlowTradable(reason);
   g_flowReason = reason;
   g_flowDiagnosticReason = reason;

   if(g_flowOK)
      g_flowStatus = "FLOW OK";
   else
      g_flowStatus = "FLOW BLOCKED";

   if(g_flow.direction == FLOW_BUY_STRONG)
      AuditFlow("BUY FLOW STRONG");
   else if(g_flow.direction == FLOW_SELL_STRONG)
      AuditFlow("SELL FLOW STRONG");
   else if(g_flow.direction == FLOW_BUY_WEAK)
      AuditFlow("BUY FLOW WEAK");
   else if(g_flow.direction == FLOW_SELL_WEAK)
      AuditFlow("SELL FLOW WEAK");
   else if(g_flow.direction == FLOW_BALANCED)
      AuditFlow("FLOW BALANCED");
   else if(g_flow.direction == FLOW_DANGEROUS)
      AuditFlow("FLOW DANGEROUS");

   AuditFlow(g_flowReason);
   AuditFlow("FLOW DATA UPDATED");
}

bool CanStartFlowEngine()
{
   return false;
}

bool CanStartEntryScoreEngine()
{
   return g_entryBaseOK;
}

double GetBuyFlowScore()
{
   return g_buyStrengthScore;
}

double GetSellFlowScore()
{
   return g_sellStrengthScore;
}

double GetFlowQualityScore()
{
   return g_flowQualityScore;
}

ENUM_FLOW_DIRECTION GetCurrentFlowDirection()
{
   return g_flow.direction;
}

double GetVolatilityScore()
{
   return g_market.volatilityScore;
}

double GetMarketTrendScore()
{
   return g_market.trendScore;
}

double GetMarketDangerScore()
{
   return g_market.dangerScore;
}

void UpdateBasketData()
{
   // Placeholder for future basket management. Stage 05 is diagnostic only.
   g_basket.netProfit = 0.0;
   g_basket.totalPositions = 0;
   g_basket.lastReason = "BASKET ENGINE NOT IMPLEMENTED IN STAGE 05";
}

void UpdateRiskData()
{
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   // Atualiza pico diÃ¡rio
   if(equity > g_risk.dailyHighEquity)
      g_risk.dailyHighEquity = equity;

   // Lucro/perda do dia em dinheiro
   if(g_risk.dailyStartEquity > 0.0)
      g_risk.dailyProfitMoney = equity - g_risk.dailyStartEquity;

   // V8 FIX: DD diÃ¡rio calculado corretamente desde dailyStartEquity
   // (nÃ£o desde o balance atual, que ignora lucros do dia)
   if(g_risk.dailyStartEquity > 0.0 && equity < g_risk.dailyStartEquity)
      g_risk.dailyDrawdownPercent = ((g_risk.dailyStartEquity - equity) / g_risk.dailyStartEquity) * 100.0;
   else
      g_risk.dailyDrawdownPercent = 0.0;

   // V8 FIX: Ativar tradingLocked quando DD diÃ¡rio atinge o limite
   // Antes: tradingLocked nunca era setado como true â€” proteÃ§Ã£o nÃ£o funcionava
   if(!g_risk.tradingLocked && DailyLossLimitPercent > 0.0
      && g_risk.dailyDrawdownPercent >= DailyLossLimitPercent)
   {
      g_risk.tradingLocked = true;
      g_risk.lockReason    = StringFormat("DAILY_DD_LIMIT_%.2f%%_REACHED_%.2f%%",
                                          DailyLossLimitPercent,
                                          g_risk.dailyDrawdownPercent);
      g_risk.protectionMode = EQUITY_DAILY_LOCKED;
      AuditLog("RISK", "[V8_DD_LOCK] Trading bloqueado por DD diÃ¡rio: "
             + DoubleToString(g_risk.dailyDrawdownPercent,2) + "% >= limite "
             + DoubleToString(DailyLossLimitPercent,2) + "%");
   }

   // Modo de proteÃ§Ã£o de equity (para dashboard e auditoria)
   if(g_risk.tradingLocked)
      g_risk.protectionMode = EQUITY_DAILY_LOCKED;
   else if(g_risk.dailyDrawdownPercent >= DailyLossLimitPercent * 0.80)
      g_risk.protectionMode = EQUITY_NORMAL; // 80% do limite = modo cautela (sem enum separado)
   else
      g_risk.protectionMode = EQUITY_NORMAL;
}

bool IsBasketActive()
{
   return false;
}

//+------------------------------------------------------------------+
//| ETAPA 5 - Entry Base Score Engine                                |
//+------------------------------------------------------------------+
double ClampEntryScore(double value)
{
   if(value < 0.0)
      return 0.0;

   if(value > 100.0)
      return 100.0;

   return value;
}

double NormalizeEntryScore(double value, double minValue, double maxValue)
{
   if(maxValue <= minValue)
      return 0.0;

   double score = ((value - minValue) / (maxValue - minValue)) * 100.0;
   return ClampEntryScore(score);
}

bool CanPrintEntryScoreLog(string reason)
{
   datetime now = TimeCurrent();

   if(reason != g_lastEntryScoreLoggedReason)
   {
      g_lastEntryScoreLoggedReason = reason;
      g_lastEntryScoreLogTime = now;
      return true;
   }

   if((now - g_lastEntryScoreLogTime) >= MinSecondsBetweenEntryScoreLogs)
   {
      g_lastEntryScoreLogTime = now;
      return true;
   }

   return false;
}

void AuditEntryScore(string message)
{
   if(!PrintEntryScoreDiagnostics)
      return;

   if(CanPrintEntryScoreLog(message))
      AuditLog("ENTRY_SCORE", message);
}

double CalculateSecurityComponentScore()
{
   double score = 0.0;
   int checks = 0;

   if(UseSpreadFilter)
   {
      checks++;
      if(g_spreadOK)
         score += 100.0;
   }

   if(UseSessionFilter)
   {
      checks++;
      if(g_sessionOK)
         score += 100.0;
   }

   if(UseCooldownFilter)
   {
      checks++;
      if(g_cooldownOK)
         score += 100.0;
   }

   if(UsePriceValidation)
   {
      checks++;
      if(g_priceOK)
         score += 100.0;
   }

   if(UseMarginDiagnostic)
   {
      checks++;
      if(g_marginOK)
         score += 100.0;
   }

   if(UseAccountSafetyDiagnostic)
   {
      checks++;
      if(g_accountSafetyOK)
         score += 100.0;
   }

   if(checks <= 0)
      g_securityComponentScore = (g_securityFiltersOK ? 100.0 : 0.0);
   else
      g_securityComponentScore = ClampEntryScore(score / (double)checks);

   if(!g_securityFiltersOK)
      g_securityComponentScore = MathMin(g_securityComponentScore, 40.0);

   return g_securityComponentScore;
}

double CalculateVolatilityComponentScore()
{
   if(!UseATRVolatilityEngine)
   {
      g_volatilityComponentScore = 100.0;
      return g_volatilityComponentScore;
   }

   if(g_atrM1Points <= 0.0)
   {
      g_volatilityComponentScore = 0.0;
      return g_volatilityComponentScore;
   }

   if(IsVolatilityDangerous())
      g_volatilityComponentScore = 0.0;
   else if(IsVolatilityDead())
      g_volatilityComponentScore = 10.0;
   else if(IsVolatilityHealthy())
      g_volatilityComponentScore = 100.0;
   else if(g_atrM1Points > HealthyATRMaxPoints && g_atrM1Points < DangerousATRPoints)
      g_volatilityComponentScore = 85.0 - NormalizeEntryScore(g_atrM1Points, HealthyATRMaxPoints, DangerousATRPoints) * 0.25;
   else
      g_volatilityComponentScore = NormalizeEntryScore(g_atrM1Points, MinATRPointsForActiveMarket, HealthyATRMinPoints) * 0.60;

   g_volatilityComponentScore = ClampEntryScore(g_volatilityComponentScore);
   return g_volatilityComponentScore;
}

double CalculateMarketModeComponentScore()
{
   if(!UseMarketClassification)
   {
      g_marketModeComponentScore = 70.0;
      return g_marketModeComponentScore;
   }

   switch(g_market.mode)
   {
      case MARKET_DEAD:          g_marketModeComponentScore = 0.0;  break;
      case MARKET_SIDEWAYS:      g_marketModeComponentScore = 45.0; break;
      case MARKET_TREND_BUY:     g_marketModeComponentScore = 85.0; break;
      case MARKET_TREND_SELL:    g_marketModeComponentScore = 85.0; break;
      case MARKET_EXPLOSIVE:     g_marketModeComponentScore = 65.0; break;
      case MARKET_ERRATIC:       g_marketModeComponentScore = 0.0;  break;
      case MARKET_SPREAD_DANGER: g_marketModeComponentScore = 0.0;  break;
      case MARKET_UNKNOWN:       g_marketModeComponentScore = 50.0; break;
      default:                   g_marketModeComponentScore = 50.0; break;
   }

   return g_marketModeComponentScore;
}

double CalculateMarketStrengthComponentScore()
{
   if(!UseMarketClassification)
   {
      g_marketStrengthComponentScore = 70.0;
      return g_marketStrengthComponentScore;
   }

   switch(g_market.strength)
   {
      case MARKET_STRENGTH_UNKNOWN: g_marketStrengthComponentScore = 50.0; break;
      case MARKET_STRENGTH_WEAK:    g_marketStrengthComponentScore = 35.0; break;
      case MARKET_STRENGTH_MEDIUM:  g_marketStrengthComponentScore = 75.0; break;
      case MARKET_STRENGTH_STRONG:  g_marketStrengthComponentScore = 90.0; break;
      default:                      g_marketStrengthComponentScore = 50.0; break;
   }

   return g_marketStrengthComponentScore;
}

double CalculateFlowQualityComponentScore()
{
   if(!UseFlowEngine)
   {
      g_flowQualityComponentScore = 70.0;
      return g_flowQualityComponentScore;
   }

   g_flowQualityComponentScore = ClampEntryScore(g_flowQualityScore);

   if(g_flowDangerous)
      g_flowQualityComponentScore = MathMin(g_flowQualityComponentScore, 30.0);

   if(g_flowBalanced)
      g_flowQualityComponentScore = MathMin(g_flowQualityComponentScore, 55.0);

   if(!g_flowOK && StrictFlowFilter)
      g_flowQualityComponentScore = MathMin(g_flowQualityComponentScore, 25.0);

   return g_flowQualityComponentScore;
}

double CalculateDirectionalComponentScore(string direction)
{
   double score = 0.0;

   if(direction == "BUY")
   {
      score = g_buyStrengthScore;

      if(g_buyStrengthScore > g_sellStrengthScore)
         score += MathMin(MathAbs(g_buyStrengthScore - g_sellStrengthScore), 20.0);

      if(g_flow.direction == FLOW_BUY_STRONG)
         score += 15.0;
      else if(g_flow.direction == FLOW_BUY_WEAK)
         score += 7.0;
      else if(g_flow.direction == FLOW_SELL_STRONG)
         score -= 20.0;

      g_buyDirectionalComponentScore = ClampEntryScore(score);
      g_directionalComponentScore = g_buyDirectionalComponentScore;
      return g_buyDirectionalComponentScore;
   }

   if(direction == "SELL")
   {
      score = g_sellStrengthScore;

      if(g_sellStrengthScore > g_buyStrengthScore)
         score += MathMin(MathAbs(g_sellStrengthScore - g_buyStrengthScore), 20.0);

      if(g_flow.direction == FLOW_SELL_STRONG)
         score += 15.0;
      else if(g_flow.direction == FLOW_SELL_WEAK)
         score += 7.0;
      else if(g_flow.direction == FLOW_BUY_STRONG)
         score -= 20.0;

      g_sellDirectionalComponentScore = ClampEntryScore(score);
      g_directionalComponentScore = g_sellDirectionalComponentScore;
      return g_sellDirectionalComponentScore;
   }

   return 0.0;
}

double CalculateMomentumComponentScore()
{
   if(g_momentumScore >= StrongMomentumScore)
      g_momentumComponentScore = 100.0;
   else if(g_momentumScore >= MinMomentumScore)
      g_momentumComponentScore = 60.0 + NormalizeEntryScore(g_momentumScore, MinMomentumScore, StrongMomentumScore) * 0.25;
   else
      g_momentumComponentScore = NormalizeEntryScore(g_momentumScore, 0.0, MinMomentumScore) * 0.50;

   g_momentumComponentScore = ClampEntryScore(g_momentumComponentScore);
   return g_momentumComponentScore;
}

double CalculateRejectionComponentScore(string direction)
{
   double raw = 0.0;

   if(direction == "BUY")
      raw = g_buyRejectionScore;
   else if(direction == "SELL")
      raw = g_sellRejectionScore;
   else
      return 0.0;

   double score = 0.0;

   if(raw >= StrongRejectionScore)
      score = 100.0;
   else if(raw >= MinRejectionScore)
      score = 60.0 + NormalizeEntryScore(raw, MinRejectionScore, StrongRejectionScore) * 0.25;
   else
      score = NormalizeEntryScore(raw, 0.0, MinRejectionScore) * 0.50;

   score = ClampEntryScore(score);

   if(direction == "BUY")
      g_buyRejectionComponentScore = score;
   else
      g_sellRejectionComponentScore = score;

   g_rejectionComponentScore = score;
   return score;
}

double CalculateImbalanceComponentScore(string direction)
{
   double raw = 0.0;

   if(direction == "BUY")
      raw = g_buyImbalanceScore;
   else if(direction == "SELL")
      raw = g_sellImbalanceScore;
   else
      return 0.0;

   double score = 0.0;

   if(raw >= StrongImbalanceScore)
      score = 100.0;
   else if(raw >= MinImbalanceScore)
      score = 60.0 + NormalizeEntryScore(raw, MinImbalanceScore, StrongImbalanceScore) * 0.25;
   else
      score = NormalizeEntryScore(raw, 0.0, MinImbalanceScore) * 0.50;

   score = ClampEntryScore(score);

   if(direction == "BUY")
      g_buyImbalanceComponentScore = score;
   else
      g_sellImbalanceComponentScore = score;

   g_imbalanceComponentScore = score;
   return score;
}

double CalculateEntryPenalty()
{
   double penalty = 0.0;

   if(g_currentSpreadPoints > MaxSpreadPoints)
      penalty += PenaltyHighSpread;

   if(g_market.mode == MARKET_SIDEWAYS)
      penalty += PenaltyMarketSideways;

   if(g_flowBalanced)
      penalty += PenaltyFlowBalanced;

   if(g_momentumScore < MinMomentumScore)
      penalty += PenaltyWeakMomentum;

   if(g_market.mode == MARKET_ERRATIC || g_market.mode == MARKET_SPREAD_DANGER)
      penalty += PenaltyDangerousMarket;

   if(IsVolatilityDangerous())
      penalty += PenaltyDangerousMarket;

   if(g_flowDangerous)
      penalty += PenaltyDangerousFlow;

   g_totalEntryPenalty = ClampEntryScore(penalty);
   return g_totalEntryPenalty;
}

double CalculateDirectionalEntryScore(string direction)
{
   if(direction != "BUY" && direction != "SELL")
      return 0.0;

   double totalWeight =
      WeightSecurityFilters +
      WeightATRVolatility +
      WeightMarketMode +
      WeightMarketStrength +
      WeightFlowQuality +
      WeightDirectionalStrength +
      WeightMomentum +
      WeightRejection +
      WeightImbalance;

   if(totalWeight <= 0.0)
   {
      g_entryBaseReason = "INVALID ENTRY WEIGHTS";
      return 0.0;
   }

   double directionalComponent = CalculateDirectionalComponentScore(direction);
   double rejectionComponent = CalculateRejectionComponentScore(direction);
   double imbalanceComponent = CalculateImbalanceComponentScore(direction);

   double weighted =
      g_securityComponentScore * WeightSecurityFilters +
      g_volatilityComponentScore * WeightATRVolatility +
      g_marketModeComponentScore * WeightMarketMode +
      g_marketStrengthComponentScore * WeightMarketStrength +
      g_flowQualityComponentScore * WeightFlowQuality +
      directionalComponent * WeightDirectionalStrength +
      g_momentumComponentScore * WeightMomentum +
      rejectionComponent * WeightRejection +
      imbalanceComponent * WeightImbalance;

   double score = weighted / totalWeight;
   score -= g_totalEntryPenalty;

   return ClampEntryScore(score);
}

bool IsBuyEntryCandidate()
{
   if(g_flowDangerous)
      return false;

   bool flowBuy = (g_flow.direction == FLOW_BUY_STRONG || g_flow.direction == FLOW_BUY_WEAK || !UseFlowEngine);

   return (g_buyEntryBaseScore >= MinBuyEntryScore &&
           g_buyEntryBaseScore > (g_sellEntryBaseScore + DirectionalAdvantageThreshold) &&
           flowBuy &&
           g_buyStrengthScore >= MinDirectionalStrength);
}

bool IsSellEntryCandidate()
{
   if(g_flowDangerous)
      return false;

   bool flowSell = (g_flow.direction == FLOW_SELL_STRONG || g_flow.direction == FLOW_SELL_WEAK || !UseFlowEngine);

   return (g_sellEntryBaseScore >= MinSellEntryScore &&
           g_sellEntryBaseScore > (g_buyEntryBaseScore + DirectionalAdvantageThreshold) &&
           flowSell &&
           g_sellStrengthScore >= MinDirectionalStrength);
}

double CalculateEntryBaseScore()
{
   g_entryBaseScore = MathMax(g_buyEntryBaseScore, g_sellEntryBaseScore);

   double diff = MathAbs(g_buyEntryBaseScore - g_sellEntryBaseScore);

   if(g_entryBaseScore < MinEntryBaseScore)
      g_entryBaseDirection = "NONE";
   else if(g_buyEntryBaseScore > (g_sellEntryBaseScore + DirectionalAdvantageThreshold))
      g_entryBaseDirection = "BUY";
   else if(g_sellEntryBaseScore > (g_buyEntryBaseScore + DirectionalAdvantageThreshold))
      g_entryBaseDirection = "SELL";
   else if(diff <= DirectionalAdvantageThreshold)
      g_entryBaseDirection = "BALANCED";
   else
      g_entryBaseDirection = "NONE";

   g_buyEntryCandidate = IsBuyEntryCandidate();
   g_sellEntryCandidate = IsSellEntryCandidate();
   g_entryScoreStrong = (g_entryBaseScore >= StrongEntryBaseScore);
   g_entryScoreExcellent = (g_entryBaseScore >= ExcellentEntryBaseScore);

   return g_entryBaseScore;
}

bool IsEntryBaseTradable(string &reason)
{
   if(!UseEntryBaseScoreEngine)
   {
      reason = "ENTRY BASE ENGINE DISABLED";
      return true;
   }

   if(BlockEntryScoreWhenSecurityBlocked && !g_securityFiltersOK)
   {
      reason = "SECURITY FILTER BLOCKED";
      return false;
   }

   if(BlockEntryScoreWhenMarketBlocked && !g_market.isTradable)
   {
      reason = "MARKET FILTER BLOCKED";
      return false;
   }

   if(BlockEntryScoreWhenFlowDangerous && g_flowDangerous)
   {
      reason = "FLOW DANGEROUS";
      return false;
   }

   if(g_entryBaseScore < MinEntryBaseScore)
   {
      reason = "ENTRY SCORE TOO LOW";
      return false;
   }

   if(!g_buyEntryCandidate && !g_sellEntryCandidate)
   {
      reason = "NO ENTRY CANDIDATE";
      return false;
   }

   reason = "ENTRY BASE OK";
   return true;
}

string EntryScoreStatusToText()
{
   if(!UseEntryBaseScoreEngine)
      return "ENTRY BASE DISABLED";

   if(EntryBaseDiagnosticOnly)
      return "DIAGNOSTIC ONLY";

   if(g_entryBaseReason == "INVALID ENTRY WEIGHTS")
      return "INVALID ENTRY WEIGHTS";

   if(g_entryScoreExcellent)
      return "ENTRY BASE EXCELLENT";

   if(g_entryScoreStrong)
      return "ENTRY BASE STRONG";

   if(g_entryBaseOK)
      return "ENTRY BASE OK";

   return "ENTRY SCORE TOO LOW";
}

string EntryDirectionToText()
{
   if(g_entryBaseDirection == "BUY")
      return "BUY";

   if(g_entryBaseDirection == "SELL")
      return "SELL";

   if(g_entryBaseDirection == "BALANCED")
      return "BALANCED";

   return "NONE";
}

void UpdateEntryBaseData()
{
   if(!UseEntryBaseScoreEngine)
   {
      g_entryBaseOK = true;
      g_entryBaseStatus = "ENTRY BASE ENGINE DISABLED";
      g_entryBaseReason = "DISABLED - PASS";
      g_entryBaseDirection = "NONE";
      g_entryDiagnosticReason = g_entryBaseReason;
      g_buyEntryCandidate = false;
      g_sellEntryCandidate = false;
      g_entryScoreStrong = false;
      g_entryScoreExcellent = false;
      g_entryBaseScore = 0.0;
      g_buyEntryBaseScore = 0.0;
      g_sellEntryBaseScore = 0.0;
      g_securityComponentScore = 0.0;
      g_volatilityComponentScore = 0.0;
      g_marketModeComponentScore = 0.0;
      g_marketStrengthComponentScore = 0.0;
      g_flowQualityComponentScore = 0.0;
      g_momentumComponentScore = 0.0;
      g_totalEntryPenalty = 0.0;
      return;
   }

   // Diagnostic score is calculated even when Security, Market or Flow are blocked.
   g_securityComponentScore = CalculateSecurityComponentScore();
   g_volatilityComponentScore = CalculateVolatilityComponentScore();
   g_marketModeComponentScore = CalculateMarketModeComponentScore();
   g_marketStrengthComponentScore = CalculateMarketStrengthComponentScore();
   g_flowQualityComponentScore = CalculateFlowQualityComponentScore();
   g_momentumComponentScore = CalculateMomentumComponentScore();
   g_totalEntryPenalty = CalculateEntryPenalty();

   g_buyEntryBaseScore = CalculateDirectionalEntryScore("BUY");
   g_sellEntryBaseScore = CalculateDirectionalEntryScore("SELL");
   g_entryBaseScore = CalculateEntryBaseScore();

   string reason = "";
   bool entryOK = IsEntryBaseTradable(reason);

   if(EntryBaseDiagnosticOnly && !IsFunctionalExecutionOverrideActive())
   {
      g_entryBaseOK = true;
      g_entryBaseStatus = "DIAGNOSTIC ONLY";
      g_entryBaseReason = reason + " - DIAGNOSTIC ONLY";
      AuditEntryScore("DIAGNOSTIC ONLY - NO TRADING");
   }
   else
   {
      g_entryBaseOK = entryOK;
      g_entryBaseStatus = (entryOK ? EntryScoreStatusToText() : "ENTRY BLOCKED");
      g_entryBaseReason = reason;
      if(EntryBaseDiagnosticOnly && IsFunctionalExecutionOverrideActive() && ForceFunctionalIgnoreEntryDiagnostic)
      {
         g_entryBaseOK = true;
         g_entryBaseStatus = "FUNCTIONAL OVERRIDE";
         g_entryBaseReason = reason + " - FUNCTIONAL OVERRIDE";
         AuditEntryScore("[FUNCTIONAL_OVERRIDE] ENTRY BASE DIAGNOSTIC BYPASSED");
      }
   }

   g_entryDiagnosticReason = g_entryBaseReason;

   if(g_buyEntryCandidate)
      AuditEntryScore("BUY ENTRY CANDIDATE");
   else if(g_sellEntryCandidate)
      AuditEntryScore("SELL ENTRY CANDIDATE");
   else
      AuditEntryScore("NO ENTRY CANDIDATE");

   if(reason == "INVALID ENTRY WEIGHTS")
      AuditEntryScore("INVALID ENTRY WEIGHTS");

   AuditEntryScore("SCORE DIAGNOSTIC UPDATED DESPITE BLOCKS");
   AuditEntryScore("ENTRY SCORE UPDATED");
}

double GetEntryBaseScore()
{
   return g_entryBaseScore;
}

string GetEntryBaseReason()
{
   return g_entryBaseReason;
}


bool CanStartEntryBase()
{
   // Stage 05 entry base data is diagnostic only.
   return g_entryBaseOK;
}

//+------------------------------------------------------------------+
//| ETAPA 6 - Entry Decision Diagnostic Engine                       |
//+------------------------------------------------------------------+
double ClampDecisionScore(double value)
{
   if(value < 0.0)
      return 0.0;

   if(value > 100.0)
      return 100.0;

   return value;
}

double NormalizeDecisionScore(double value, double minValue, double maxValue)
{
   if(maxValue <= minValue)
      return 0.0;

   double score = ((value - minValue) / (maxValue - minValue)) * 100.0;
   return ClampDecisionScore(score);
}

bool IsDecisionMarketDangerous()
{
   if(g_market.mode == MARKET_ERRATIC)
      return true;

   if(g_market.mode == MARKET_SPREAD_DANGER)
      return true;

   if(IsVolatilityDangerous())
      return true;

   return false;
}

double CalculateBuyDecisionScore()
{
   double score = g_buyEntryBaseScore;

   if(g_buyEntryCandidate)
      score += 6.0;

   if(g_entryBaseDirection == "BUY")
      score += 5.0;

   if(g_flow.direction == FLOW_BUY_STRONG)
      score += 8.0;
   else if(g_flow.direction == FLOW_BUY_WEAK && AllowWeakFlowDecision)
      score += 3.0;

   if(g_buyStrengthScore >= StrongDirectionalStrength)
      score += 4.0;

   if(g_buyEntryBaseScore >= StrongEntryBaseScore)
      score += 4.0;

   if(g_buyEntryBaseScore >= ExcellentEntryBaseScore)
      score += 4.0;

   if(g_flow.direction == FLOW_SELL_STRONG)
      score -= 12.0;

   if(MathAbs(g_buyEntryBaseScore - g_sellEntryBaseScore) <= MaxBuySellConflictDifference)
      score -= 5.0;

   if(g_totalEntryPenalty > MaxAllowedEntryPenaltyForDecision)
      score -= 10.0;

   if(IsDecisionMarketDangerous())
      score -= 15.0;

   if(g_flowDangerous)
      score -= 15.0;

   return ClampDecisionScore(score);
}

double CalculateSellDecisionScore()
{
   double score = g_sellEntryBaseScore;

   if(g_sellEntryCandidate)
      score += 6.0;

   if(g_entryBaseDirection == "SELL")
      score += 5.0;

   if(g_flow.direction == FLOW_SELL_STRONG)
      score += 8.0;
   else if(g_flow.direction == FLOW_SELL_WEAK && AllowWeakFlowDecision)
      score += 3.0;

   if(g_sellStrengthScore >= StrongDirectionalStrength)
      score += 4.0;

   if(g_sellEntryBaseScore >= StrongEntryBaseScore)
      score += 4.0;

   if(g_sellEntryBaseScore >= ExcellentEntryBaseScore)
      score += 4.0;

   if(g_flow.direction == FLOW_BUY_STRONG)
      score -= 12.0;

   if(MathAbs(g_sellEntryBaseScore - g_buyEntryBaseScore) <= MaxBuySellConflictDifference)
      score -= 5.0;

   if(g_totalEntryPenalty > MaxAllowedEntryPenaltyForDecision)
      score -= 10.0;

   if(IsDecisionMarketDangerous())
      score -= 15.0;

   if(g_flowDangerous)
      score -= 15.0;

   return ClampDecisionScore(score);
}

double CalculateEntryDecisionScore()
{
   g_buyDecisionScore = CalculateBuyDecisionScore();
   g_sellDecisionScore = CalculateSellDecisionScore();
   g_decisionScoreDifference = MathAbs(g_buyDecisionScore - g_sellDecisionScore);
   g_entryDecisionScore = MathMax(g_buyDecisionScore, g_sellDecisionScore);

   g_entryDecisionStrong = (g_entryDecisionScore >= StrongDecisionScore);
   g_entryDecisionExcellent = (g_entryDecisionScore >= ExcellentDecisionScore);
   g_buyDecisionCandidate = (g_buyDecisionScore >= MinDecisionScore && g_buyDecisionScore > g_sellDecisionScore + MinDecisionScoreDifference);
   g_sellDecisionCandidate = (g_sellDecisionScore >= MinDecisionScore && g_sellDecisionScore > g_buyDecisionScore + MinDecisionScoreDifference);

   return g_entryDecisionScore;
}

bool IsDecisionConflict()
{
   if(g_buyDecisionScore >= MinDecisionScore &&
      g_sellDecisionScore >= MinDecisionScore &&
      MathAbs(g_buyDecisionScore - g_sellDecisionScore) <= MaxBuySellConflictDifference)
   {
      return true;
   }

   if(g_buyDecisionCandidate && g_sellDecisionCandidate)
      return true;

   return false;
}

bool IsDecisionBlocked(string &reason)
{
   if(!UseEntryDecisionEngine)
   {
      reason = "DECISION NOT BLOCKED";
      return false;
   }

   if(RequireSecurityOKForDecision && !g_securityFiltersOK)
   {
      reason = "SECURITY NOT OK";
      return true;
   }

   if(RequireMarketTradableForDecision && !g_market.isTradable)
   {
      reason = "MARKET NOT TRADABLE";
      return true;
   }

   if(RequireEntryBaseOKForDecision && !g_entryBaseOK)
   {
      reason = "ENTRY BASE NOT OK";
      return true;
   }

   if(RequireFlowDirectionForDecision && g_flow.direction == FLOW_NONE)
   {
      reason = "NO FLOW DIRECTION";
      return true;
   }

   if(BlockDecisionWhenSpreadHigh && g_currentSpreadPoints > MaxSpreadPoints)
   {
      reason = "SPREAD TOO HIGH";
      return true;
   }

   if(BlockDecisionWhenMarketDangerous && IsDecisionMarketDangerous())
   {
      reason = "MARKET DANGEROUS";
      return true;
   }

   if(BlockDecisionWhenFlowDangerous && g_flowDangerous)
   {
      reason = "FLOW DANGEROUS";
      return true;
   }

   if(BlockDecisionWhenEntryPenaltyHigh && g_totalEntryPenalty > MaxAllowedEntryPenaltyForDecision)
   {
      reason = "ENTRY PENALTY TOO HIGH";
      return true;
   }

   if(!AllowBalancedDecision && g_entryBaseDirection == "BALANCED")
   {
      reason = "BALANCED ENTRY";
      return true;
   }

   reason = "DECISION NOT BLOCKED";
   return false;
}

bool IsBuyDecisionValid(string &reason)
{
   string blockReason = "";
   if(IsDecisionBlocked(blockReason))
   {
      reason = "BUY BLOCKED BY DANGER";
      return false;
   }

   if(g_entryDecisionConflict)
   {
      reason = "BUY CONFLICT";
      return false;
   }

   if(g_buyDecisionScore < MinDecisionScore)
   {
      reason = "BUY DECISION SCORE LOW";
      return false;
   }

   if(g_buyDecisionScore <= g_sellDecisionScore + MinDecisionScoreDifference)
   {
      reason = "BUY ADVANTAGE LOW";
      return false;
   }

   if(!g_buyEntryCandidate)
   {
      reason = "BUY ENTRY CANDIDATE FALSE";
      return false;
   }

   if(g_buyStrengthScore < MinDirectionalStrength)
   {
      reason = "BUY DECISION SCORE LOW";
      return false;
   }

   if(RequireFlowDirectionForDecision)
   {
      bool flowConfirmed = (g_flow.direction == FLOW_BUY_STRONG ||
                            (AllowWeakFlowDecision && g_flow.direction == FLOW_BUY_WEAK));
      if(!flowConfirmed)
      {
         reason = "BUY FLOW NOT CONFIRMED";
         return false;
      }
   }

   if(g_flowDangerous)
   {
      reason = "BUY BLOCKED BY DANGER";
      return false;
   }

   reason = "BUY DECISION OK";
   return true;
}

bool IsSellDecisionValid(string &reason)
{
   string blockReason = "";
   if(IsDecisionBlocked(blockReason))
   {
      reason = "SELL BLOCKED BY DANGER";
      return false;
   }

   if(g_entryDecisionConflict)
   {
      reason = "SELL CONFLICT";
      return false;
   }

   if(g_sellDecisionScore < MinDecisionScore)
   {
      reason = "SELL DECISION SCORE LOW";
      return false;
   }

   if(g_sellDecisionScore <= g_buyDecisionScore + MinDecisionScoreDifference)
   {
      reason = "SELL ADVANTAGE LOW";
      return false;
   }

   if(!g_sellEntryCandidate)
   {
      reason = "SELL ENTRY CANDIDATE FALSE";
      return false;
   }

   if(g_sellStrengthScore < MinDirectionalStrength)
   {
      reason = "SELL DECISION SCORE LOW";
      return false;
   }

   if(RequireFlowDirectionForDecision)
   {
      bool flowConfirmed = (g_flow.direction == FLOW_SELL_STRONG ||
                            (AllowWeakFlowDecision && g_flow.direction == FLOW_SELL_WEAK));
      if(!flowConfirmed)
      {
         reason = "SELL FLOW NOT CONFIRMED";
         return false;
      }
   }

   if(g_flowDangerous)
   {
      reason = "SELL BLOCKED BY DANGER";
      return false;
   }

   reason = "SELL DECISION OK";
   return true;
}

ENUM_ENTRY_DECISION DetectEntryDecision()
{
   if(!UseEntryDecisionEngine)
      return ENTRY_DECISION_NONE;

   g_entryDecisionDirection = "NONE";
   g_entryDecisionBlocked = false;

   string blockReason = "";
   if(IsDecisionBlocked(blockReason))
   {
      g_entryDecisionBlocked = true;
      g_entryDecisionReason = blockReason;
      return ENTRY_DECISION_BLOCKED;
   }

   g_entryDecisionConflict = IsDecisionConflict();
   if(g_entryDecisionConflict && BlockDecisionOnConflict)
   {
      g_entryDecisionReason = "BUY SELL CONFLICT";
      return ENTRY_DECISION_CONFLICT;
   }

   string buyReason = "";
   string sellReason = "";
   bool buyValid = IsBuyDecisionValid(buyReason);
   bool sellValid = IsSellDecisionValid(sellReason);

   if(buyValid && !sellValid)
   {
      g_entryDecisionDirection = "BUY";
      g_entryDecisionReason = buyReason;
      return ENTRY_DECISION_BUY;
   }

   if(sellValid && !buyValid)
   {
      g_entryDecisionDirection = "SELL";
      g_entryDecisionReason = sellReason;
      return ENTRY_DECISION_SELL;
   }

   if(buyValid && sellValid)
   {
      g_entryDecisionReason = "BUY SELL CONFLICT";
      return ENTRY_DECISION_CONFLICT;
   }

   if(g_entryDecisionScore < MinDecisionScore)
   {
      g_entryDecisionReason = "DECISION SCORE TOO LOW";
      return ENTRY_DECISION_WAIT;
   }

   g_entryDecisionReason = "WAITING BETTER CONFIRMATION";
   return ENTRY_DECISION_WAIT;
}

bool IsEntryDecisionTradable(string &reason)
{
   if(!UseEntryDecisionEngine)
   {
      reason = "ENTRY DECISION ENGINE DISABLED";
      return true;
   }

   if(g_entryDecision == ENTRY_DECISION_BUY)
   {
      reason = "BUY DECISION OK";
      return true;
   }

   if(g_entryDecision == ENTRY_DECISION_SELL)
   {
      reason = "SELL DECISION OK";
      return true;
   }

   if(g_entryDecision == ENTRY_DECISION_WAIT)
   {
      reason = "WAITING BETTER CONFIRMATION";
      return false;
   }

   if(g_entryDecision == ENTRY_DECISION_BLOCKED)
   {
      reason = "ENTRY DECISION BLOCKED";
      return false;
   }

   if(g_entryDecision == ENTRY_DECISION_CONFLICT)
   {
      reason = "BUY SELL CONFLICT";
      return false;
   }

   reason = "NO ENTRY DECISION";
   return false;
}

string EntryDecisionToText(ENUM_ENTRY_DECISION decision)
{
   switch(decision)
   {
      case ENTRY_DECISION_NONE:     return "ENTRY_DECISION_NONE";
      case ENTRY_DECISION_BUY:      return "ENTRY_DECISION_BUY";
      case ENTRY_DECISION_SELL:     return "ENTRY_DECISION_SELL";
      case ENTRY_DECISION_WAIT:     return "ENTRY_DECISION_WAIT";
      case ENTRY_DECISION_BLOCKED:  return "ENTRY_DECISION_BLOCKED";
      case ENTRY_DECISION_CONFLICT: return "ENTRY_DECISION_CONFLICT";
      default:                      return "ENTRY_DECISION_NONE";
   }
}

string EntryDecisionStatusToText()
{
   if(!UseEntryDecisionEngine)
      return "ENTRY DECISION DISABLED";

   if(EntryDecisionDiagnosticOnly)
      return "DIAGNOSTIC ONLY";

   if(g_entryDecision == ENTRY_DECISION_BUY)
      return "BUY DECISION OK";

   if(g_entryDecision == ENTRY_DECISION_SELL)
      return "SELL DECISION OK";

   if(g_entryDecision == ENTRY_DECISION_WAIT)
      return "WAITING BETTER CONFIRMATION";

   if(g_entryDecision == ENTRY_DECISION_BLOCKED)
      return "ENTRY DECISION BLOCKED";

   if(g_entryDecision == ENTRY_DECISION_CONFLICT)
      return "BUY SELL CONFLICT";

   return "NO ENTRY DECISION";
}

string GetEntryDecisionReason()
{
   return g_entryDecisionReason;
}

string GetEntryDecisionDirection()
{
   return g_entryDecisionDirection;
}

bool CanPrintEntryDecisionLog(string reason)
{
   datetime now = TimeCurrent();

   if(reason != g_lastEntryDecisionLoggedReason)
   {
      g_lastEntryDecisionLoggedReason = reason;
      g_lastEntryDecisionLogTime = now;
      return true;
   }

   if((now - g_lastEntryDecisionLogTime) >= MinSecondsBetweenEntryDecisionLogs)
   {
      g_lastEntryDecisionLogTime = now;
      return true;
   }

   return false;
}

void AuditEntryDecision(string message)
{
   if(!PrintDetailedLogs || !PrintEntryDecisionDiagnostics)
      return;

   if(!CanPrintEntryDecisionLog(message))
      return;

   Print("[HORSE EA][ENTRY_DECISION] ", message);
}

void UpdateEntryDecisionData()
{
   if(!UseEntryDecisionEngine)
   {
      g_entryDecisionOK = true;
      g_entryDecisionStatus = "ENTRY DECISION ENGINE DISABLED";
      g_entryDecisionReason = "DISABLED - PASS";
      g_entryDecisionDirection = "NONE";
      g_entryDecisionText = "ENTRY_DECISION_NONE";
      g_entryDecisionDiagnosticReason = g_entryDecisionReason;
      g_entryDecision = ENTRY_DECISION_NONE;
      g_entryDecisionScore = 0.0;
      g_buyDecisionScore = 0.0;
      g_sellDecisionScore = 0.0;
      g_decisionScoreDifference = 0.0;
      g_buyDecisionCandidate = false;
      g_sellDecisionCandidate = false;
      g_entryDecisionStrong = false;
      g_entryDecisionExcellent = false;
      g_entryDecisionConflict = false;
      g_entryDecisionBlocked = false;
      return;
   }

   CalculateEntryDecisionScore();
   g_entryDecision = DetectEntryDecision();
   g_entryDecisionText = EntryDecisionToText(g_entryDecision);
   g_entryDecisionConflict = IsDecisionConflict();
   g_entryDecisionBlocked = (g_entryDecision == ENTRY_DECISION_BLOCKED);

   string decisionReason = "";
   bool decisionOK = IsEntryDecisionTradable(decisionReason);

   if(EntryDecisionDiagnosticOnly && !IsFunctionalExecutionOverrideActive())
   {
      g_entryDecisionOK = true;
      g_entryDecisionStatus = "DIAGNOSTIC ONLY";
      if(StringFind(g_entryDecisionReason, "DIAGNOSTIC ONLY") < 0)
         g_entryDecisionReason = g_entryDecisionReason + " - DIAGNOSTIC ONLY";
      AuditEntryDecision("DIAGNOSTIC ONLY - NO TRADING");
   }
   else
   {
      g_entryDecisionOK = decisionOK;
      g_entryDecisionStatus = EntryDecisionStatusToText();
      if(!decisionOK)
         g_entryDecisionReason = decisionReason;
      if(EntryDecisionDiagnosticOnly && IsFunctionalExecutionOverrideActive() && ForceFunctionalIgnoreEntryDiagnostic)
      {
         g_entryDecisionOK = true;
         g_entryDecisionStatus = "FUNCTIONAL OVERRIDE";
         if(StringFind(g_entryDecisionReason, "FUNCTIONAL OVERRIDE") < 0)
            g_entryDecisionReason = g_entryDecisionReason + " - FUNCTIONAL OVERRIDE";
         AuditEntryDecision("[FUNCTIONAL_OVERRIDE] ENTRY DIAGNOSTIC BYPASSED");
      }
   }

   g_entryDecisionDiagnosticReason = g_entryDecisionReason;

   if(g_entryDecision == ENTRY_DECISION_BUY)
      AuditEntryDecision("BUY DECISION OK");
   else if(g_entryDecision == ENTRY_DECISION_SELL)
      AuditEntryDecision("SELL DECISION OK");
   else if(g_entryDecision == ENTRY_DECISION_CONFLICT)
      AuditEntryDecision("BUY SELL CONFLICT");
   else if(g_entryDecision == ENTRY_DECISION_BLOCKED)
      AuditEntryDecision("ENTRY DECISION BLOCKED");
   else
      AuditEntryDecision("WAITING BETTER CONFIRMATION");

   AuditEntryDecision("SCORE DIAGNOSTIC UPDATED DESPITE BLOCKS");
   AuditEntryDecision("ENTRY DECISION UPDATED");
}


//+------------------------------------------------------------------+
//| ETAPA 7 - Virtual Entry Simulation Engine                        |
//+------------------------------------------------------------------+
void InitializeVirtualEntryData()
{
   ZeroMemory(g_virtualEntry);
   g_virtualEntry.state = VIRTUAL_ENTRY_NONE;
   g_virtualEntry.direction = VIRTUAL_DIR_NONE;
   g_virtualEntry.statusText = "NONE";
   g_virtualEntry.startReason = "NONE";
   g_virtualEntry.endReason = "NONE";

   g_virtualEntryActive = false;
   g_virtualEntryCompleted = false;
   g_virtualEntryWin = false;
   g_virtualEntryLoss = false;
   g_virtualEntryTimeout = false;
   g_virtualEntryInvalidated = false;
   g_virtualEntryCancelled = false;
   g_virtualBuyCandidate = false;
   g_virtualSellCandidate = false;
   g_virtualEntryScore = 0.0;
   g_virtualEntryResultScore = 0.0;
   g_virtualEntryQualityAtStart = 0.0;
   g_virtualEntryStatus = "VIRTUAL ENTRY INITIALIZED";
   g_virtualEntryReason = "NONE";
   g_virtualEntryDirectionText = "NONE";
}

double ClampVirtualValue(double value, double minValue, double maxValue)
{
   if(maxValue < minValue)
      return minValue;
   if(value < minValue)
      return minValue;
   if(value > maxValue)
      return maxValue;
   return value;
}

bool IsVirtualPriceValid(string &reason)
{
   double ask = 0.0;
   double bid = 0.0;
   bool askOK = SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
   bool bidOK = SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);

   if(!askOK || ask <= 0.0)
   {
      reason = "INVALID ASK PRICE";
      return false;
   }

   if(!bidOK || bid <= 0.0)
   {
      reason = "INVALID BID PRICE";
      return false;
   }

   if(_Point <= 0.0)
   {
      reason = "INVALID POINT VALUE";
      return false;
   }

   int spread = GetCurrentSpreadPoints();
   if(spread < 0 || spread >= 999999)
   {
      reason = "INVALID SPREAD";
      return false;
   }

   reason = "VIRTUAL PRICE OK";
   return true;
}

double GetCurrentVirtualPrice(ENUM_VIRTUAL_ENTRY_DIRECTION direction)
{
   double price = 0.0;

   if(direction == VIRTUAL_DIR_BUY)
   {
      if(!SymbolInfoDouble(_Symbol, SYMBOL_BID, price) || price <= 0.0)
         return 0.0;
      return price;
   }

   if(direction == VIRTUAL_DIR_SELL)
   {
      if(!SymbolInfoDouble(_Symbol, SYMBOL_ASK, price) || price <= 0.0)
         return 0.0;
      return price;
   }

   return 0.0;
}

double CalculateVirtualSLPoints()
{
   double sl = FixedVirtualSLPoints;
   if(UseATRVirtualStops && g_atrM1Points > 0.0)
      sl = g_atrM1Points * VirtualSL_ATR_Multiplier;

   return ClampVirtualValue(sl, MinVirtualSLPoints, MaxVirtualSLPoints);
}

double CalculateVirtualTPPoints()
{
   double tp = FixedVirtualTPPoints;
   if(UseATRVirtualStops && g_atrM1Points > 0.0)
      tp = g_atrM1Points * VirtualTP_ATR_Multiplier;

   return ClampVirtualValue(tp, MinVirtualTPPoints, MaxVirtualTPPoints);
}

double CalculateVirtualRiskRewardRatio(double slPoints, double tpPoints)
{
   if(slPoints <= 0.0)
      return 0.0;
   return (tpPoints / slPoints);
}

double CalculateVirtualMoneyFromPoints(double points, double lot)
{
   if(!UseSymbolTickValueForVirtualMoney)
      return points;

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickValue <= 0.0 || tickSize <= 0.0 || _Point <= 0.0 || lot <= 0.0)
      return 0.0;

   return (points * _Point / tickSize) * tickValue * lot;
}

bool CanStartVirtualEntrySimulationNow(string &reason)
{
   if(!UseVirtualEntrySimulation)
   {
      reason = "VIRTUAL ENTRY ENGINE DISABLED";
      return false;
   }

   if(OneVirtualEntryAtATime && g_virtualEntryActive)
   {
      reason = "VIRTUAL ENTRY ALREADY ACTIVE";
      return false;
   }

   if(CooldownSecondsAfterVirtualEntryEnd > 0 && g_lastVirtualEntryEndTime > 0)
   {
      int secondsFromEnd = (int)(TimeCurrent() - g_lastVirtualEntryEndTime);
      if(secondsFromEnd < CooldownSecondsAfterVirtualEntryEnd)
      {
         reason = "VIRTUAL ENTRY COOLDOWN";
         return false;
      }
   }

   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(PreventMultipleVirtualEntriesSameCandle && currentBarTime > 0 && currentBarTime == g_lastVirtualEntryStartBarTime)
   {
      reason = "VIRTUAL ENTRY ALREADY STARTED THIS CANDLE";
      return false;
   }

   bool buyDecision = (g_entryDecision == ENTRY_DECISION_BUY);
   bool sellDecision = (g_entryDecision == ENTRY_DECISION_SELL);

   if(StartVirtualEntryOnlyOnValidDecision)
   {
      if(!buyDecision && !sellDecision)
      {
         if(g_entryDecision == ENTRY_DECISION_WAIT)
            reason = "ENTRY DECISION WAIT";
         else if(g_entryDecision == ENTRY_DECISION_BLOCKED)
            reason = "ENTRY DECISION BLOCKED";
         else if(g_entryDecision == ENTRY_DECISION_CONFLICT)
            reason = "ENTRY DECISION CONFLICT";
         else
            reason = "NO ENTRY DECISION";
         return false;
      }
   }
   else
   {
      bool diagnosticDirectional = (AllowVirtualEntryOnDiagnosticDecision && EntryDecisionDiagnosticOnly &&
                                    (g_entryDecisionDirection == "BUY" || g_entryDecisionDirection == "SELL"));
      if(!buyDecision && !sellDecision && !diagnosticDirectional)
      {
         if(g_entryDecision == ENTRY_DECISION_WAIT)
            reason = "ENTRY DECISION WAIT";
         else if(g_entryDecision == ENTRY_DECISION_BLOCKED)
            reason = "ENTRY DECISION BLOCKED";
         else if(g_entryDecision == ENTRY_DECISION_CONFLICT)
            reason = "ENTRY DECISION CONFLICT";
         else
            reason = "NO ENTRY DECISION";
         return false;
      }
   }

   if((buyDecision || g_entryDecisionDirection == "BUY") && !AllowVirtualBuySimulation)
   {
      reason = "VIRTUAL BUY DISABLED";
      return false;
   }

   if((sellDecision || g_entryDecisionDirection == "SELL") && !AllowVirtualSellSimulation)
   {
      reason = "VIRTUAL SELL DISABLED";
      return false;
   }

   string priceReason = "";
   if(!IsVirtualPriceValid(priceReason))
   {
      reason = "INVALID VIRTUAL PRICE";
      if(StringLen(priceReason) > 0)
         reason = priceReason;
      return false;
   }

   reason = "VIRTUAL ENTRY ALLOWED";
   return true;
}

bool StartVirtualEntrySimulation(string &reason)
{
   if(!CanStartVirtualEntrySimulationNow(reason))
      return false;

   ENUM_VIRTUAL_ENTRY_DIRECTION direction = VIRTUAL_DIR_NONE;
   if(g_entryDecision == ENTRY_DECISION_BUY || g_entryDecisionDirection == "BUY")
      direction = VIRTUAL_DIR_BUY;
   else if(g_entryDecision == ENTRY_DECISION_SELL || g_entryDecisionDirection == "SELL")
      direction = VIRTUAL_DIR_SELL;

   if(direction == VIRTUAL_DIR_NONE)
   {
      reason = "INVALID VIRTUAL DIRECTION";
      return false;
   }

   double entryPrice = 0.0;
   if(direction == VIRTUAL_DIR_BUY)
      SymbolInfoDouble(_Symbol, SYMBOL_ASK, entryPrice);
   else
      SymbolInfoDouble(_Symbol, SYMBOL_BID, entryPrice);

   if(entryPrice <= 0.0 || _Point <= 0.0)
   {
      reason = "INVALID VIRTUAL ENTRY PRICE";
      return false;
   }

   double slPoints = CalculateVirtualSLPoints();
   double tpPoints = CalculateVirtualTPPoints();

   if(slPoints <= 0.0 || tpPoints <= 0.0)
   {
      reason = "INVALID VIRTUAL SL TP";
      return false;
   }

   datetime currentBarTime = iTime(_Symbol, _Period, 0);

   ZeroMemory(g_virtualEntry);
   g_virtualEntry.state = VIRTUAL_ENTRY_ACTIVE;
   g_virtualEntry.direction = direction;
   g_virtualEntry.startTime = TimeCurrent();
   g_virtualEntry.endTime = 0;
   g_virtualEntry.startBarTime = currentBarTime;
   g_virtualEntry.ageSeconds = 0;
   g_virtualEntry.ageBars = 0;
   g_virtualEntry.entryPrice = entryPrice;
   g_virtualEntry.currentPrice = GetCurrentVirtualPrice(direction);
   g_virtualEntry.virtualRiskPoints = slPoints;
   g_virtualEntry.virtualRewardPoints = tpPoints;
   g_virtualEntry.virtualRR = CalculateVirtualRiskRewardRatio(slPoints, tpPoints);

   if(direction == VIRTUAL_DIR_BUY)
   {
      g_virtualEntry.stopLossPrice = entryPrice - (slPoints * _Point);
      g_virtualEntry.takeProfitPrice = entryPrice + (tpPoints * _Point);
      g_virtualBuyCandidate = true;
      g_virtualSellCandidate = false;
   }
   else
   {
      g_virtualEntry.stopLossPrice = entryPrice + (slPoints * _Point);
      g_virtualEntry.takeProfitPrice = entryPrice - (tpPoints * _Point);
      g_virtualBuyCandidate = false;
      g_virtualSellCandidate = true;
   }

   g_virtualEntry.currentProfitPoints = 0.0;
   g_virtualEntry.currentProfitMoney = 0.0;
   g_virtualEntry.maxFavorablePoints = 0.0;
   g_virtualEntry.maxAdversePoints = 0.0;
   g_virtualEntry.decisionScoreAtStart = g_entryDecisionScore;
   g_virtualEntry.entryBaseScoreAtStart = g_entryBaseScore;
   g_virtualEntry.buyScoreAtStart = g_buyDecisionScore;
   g_virtualEntry.sellScoreAtStart = g_sellDecisionScore;
   g_virtualEntry.flowQualityAtStart = g_flowQualityScore;
   g_virtualEntry.atrAtStart = g_atrM1Points;
   g_virtualEntry.spreadAtStart = g_currentSpreadPoints;
   g_virtualEntry.startReason = reason;
   g_virtualEntry.endReason = "NONE";
   g_virtualEntry.statusText = "VIRTUAL ENTRY ACTIVE";

   g_virtualEntryActive = true;
   g_virtualEntryCompleted = false;
   g_virtualEntryWin = false;
   g_virtualEntryLoss = false;
   g_virtualEntryTimeout = false;
   g_virtualEntryInvalidated = false;
   g_virtualEntryCancelled = false;

   g_virtualEntryStatus = "VIRTUAL ENTRY ACTIVE";
   g_virtualEntryReason = reason;
   g_virtualEntryDirectionText = VirtualEntryDirectionToText(direction);
   g_virtualEntryScore = g_entryDecisionScore;
   g_virtualEntryQualityAtStart = g_entryBaseScore;
   g_virtualTotalSimulations++;
   g_lastVirtualEntryStartBarTime = currentBarTime;

   if(direction == VIRTUAL_DIR_BUY)
      AuditVirtualEntry("VIRTUAL BUY STARTED");
   else
      AuditVirtualEntry("VIRTUAL SELL STARTED");

   return true;
}

bool IsVirtualEntryExpired()
{
   if(!g_virtualEntryActive)
      return false;

   if(MaxVirtualEntrySeconds > 0 && g_virtualEntry.ageSeconds >= MaxVirtualEntrySeconds)
      return true;

   if(MaxVirtualEntryBars > 0 && g_virtualEntry.ageBars >= MaxVirtualEntryBars)
      return true;

   return false;
}

bool IsVirtualEntryHitTP()
{
   if(!g_virtualEntryActive || g_virtualEntry.currentPrice <= 0.0 || g_virtualEntry.takeProfitPrice <= 0.0)
      return false;

   if(g_virtualEntry.direction == VIRTUAL_DIR_BUY)
      return (g_virtualEntry.currentPrice >= g_virtualEntry.takeProfitPrice);

   if(g_virtualEntry.direction == VIRTUAL_DIR_SELL)
      return (g_virtualEntry.currentPrice <= g_virtualEntry.takeProfitPrice);

   return false;
}

bool IsVirtualEntryHitSL()
{
   if(!g_virtualEntryActive || g_virtualEntry.currentPrice <= 0.0 || g_virtualEntry.stopLossPrice <= 0.0)
      return false;

   if(g_virtualEntry.direction == VIRTUAL_DIR_BUY)
      return (g_virtualEntry.currentPrice <= g_virtualEntry.stopLossPrice);

   if(g_virtualEntry.direction == VIRTUAL_DIR_SELL)
      return (g_virtualEntry.currentPrice >= g_virtualEntry.stopLossPrice);

   return false;
}

bool IsVirtualEntryInvalidated(string &reason)
{
   if(!g_virtualEntryActive)
   {
      reason = "NO ACTIVE VIRTUAL ENTRY";
      return false;
   }

   if(InvalidateVirtualEntryOnDangerousFlow && g_flowDangerous)
   {
      reason = "FLOW DANGEROUS";
      return true;
   }

   if(InvalidateVirtualEntryOnMarketDanger)
   {
      if(g_market.mode == MARKET_ERRATIC || g_market.mode == MARKET_SPREAD_DANGER || IsVolatilityDangerous())
      {
         reason = "MARKET DANGEROUS";
         return true;
      }
   }

   if(InvalidateVirtualEntryOnOppositeFlow)
   {
      if(g_virtualEntry.direction == VIRTUAL_DIR_BUY && g_flow.direction == FLOW_SELL_STRONG)
      {
         reason = "OPPOSITE FLOW SELL STRONG";
         return true;
      }
      if(g_virtualEntry.direction == VIRTUAL_DIR_SELL && g_flow.direction == FLOW_BUY_STRONG)
      {
         reason = "OPPOSITE FLOW BUY STRONG";
         return true;
      }
   }

   if(InvalidateVirtualEntryOnEntryDecisionFlip)
   {
      if(g_virtualEntry.direction == VIRTUAL_DIR_BUY && g_entryDecision == ENTRY_DECISION_SELL)
      {
         reason = "ENTRY DECISION FLIP TO SELL";
         return true;
      }
      if(g_virtualEntry.direction == VIRTUAL_DIR_SELL && g_entryDecision == ENTRY_DECISION_BUY)
      {
         reason = "ENTRY DECISION FLIP TO BUY";
         return true;
      }
   }

   reason = "VIRTUAL ENTRY NOT INVALIDATED";
   return false;
}

bool IsVirtualEntryCancelled(string &reason)
{
   if(!g_virtualEntryActive)
   {
      reason = "NO ACTIVE VIRTUAL ENTRY";
      return false;
   }

   if(CancelVirtualEntryOnSecurityBlock && !g_securityFiltersOK)
   {
      reason = "SECURITY BLOCKED";
      return true;
   }

   if(!g_symbolOK || !g_timeframeOK || !g_environmentOK)
   {
      reason = "CORE FILTER BLOCKED";
      return true;
   }

   reason = "VIRTUAL ENTRY NOT CANCELLED";
   return false;
}

void UpdateVirtualEntryProfit()
{
   if(!g_virtualEntryActive)
      return;

   double currentPrice = GetCurrentVirtualPrice(g_virtualEntry.direction);
   if(currentPrice <= 0.0 || g_virtualEntry.entryPrice <= 0.0 || _Point <= 0.0)
      return;

   g_virtualEntry.currentPrice = currentPrice;

   double profitPoints = 0.0;
   if(g_virtualEntry.direction == VIRTUAL_DIR_BUY)
      profitPoints = (currentPrice - g_virtualEntry.entryPrice) / _Point;
   else if(g_virtualEntry.direction == VIRTUAL_DIR_SELL)
      profitPoints = (g_virtualEntry.entryPrice - currentPrice) / _Point;

   g_virtualEntry.currentProfitPoints = profitPoints;
   g_virtualEntry.currentProfitMoney = CalculateVirtualMoneyFromPoints(profitPoints, VirtualLotForMoneySimulation);

   if(profitPoints > g_virtualEntry.maxFavorablePoints)
      g_virtualEntry.maxFavorablePoints = profitPoints;

   if(profitPoints < g_virtualEntry.maxAdversePoints)
      g_virtualEntry.maxAdversePoints = profitPoints;
}

void UpdateVirtualEntryStats(ENUM_VIRTUAL_ENTRY_STATE endState)
{
   if(endState == VIRTUAL_ENTRY_WIN)
      g_virtualWins++;
   else if(endState == VIRTUAL_ENTRY_LOSS)
      g_virtualLosses++;
   else if(endState == VIRTUAL_ENTRY_TIMEOUT)
      g_virtualTimeouts++;
   else if(endState == VIRTUAL_ENTRY_INVALIDATED)
      g_virtualInvalidations++;
   else if(endState == VIRTUAL_ENTRY_CANCELLED)
      g_virtualCancellations++;
}

double GetVirtualEntryResultScore()
{
   double score = 0.0;

   if(g_virtualEntry.state == VIRTUAL_ENTRY_WIN)
      score = 100.0;
   else if(g_virtualEntry.state == VIRTUAL_ENTRY_LOSS)
      score = 0.0;
   else if(g_virtualEntry.state == VIRTUAL_ENTRY_TIMEOUT)
      score = (g_virtualEntry.currentProfitPoints >= 0.0 ? 60.0 : 35.0);
   else if(g_virtualEntry.state == VIRTUAL_ENTRY_INVALIDATED)
      score = (g_virtualEntry.currentProfitPoints >= 0.0 ? 55.0 : 25.0);
   else if(g_virtualEntry.state == VIRTUAL_ENTRY_CANCELLED)
      score = 50.0;
   else if(g_virtualEntry.state == VIRTUAL_ENTRY_ACTIVE)
   {
      if(g_virtualEntry.currentProfitPoints == 0.0)
         score = 50.0;
      else if(g_virtualEntry.currentProfitPoints > 0.0)
      {
         double tp = MathMax(g_virtualEntry.virtualRewardPoints, 1.0);
         score = 50.0 + ClampVirtualValue((g_virtualEntry.currentProfitPoints / tp) * 50.0, 0.0, 50.0);
      }
      else
      {
         double sl = MathMax(g_virtualEntry.virtualRiskPoints, 1.0);
         score = 50.0 - ClampVirtualValue((MathAbs(g_virtualEntry.currentProfitPoints) / sl) * 50.0, 0.0, 50.0);
      }
   }
   else
      score = 0.0;

   g_virtualEntryResultScore = ClampVirtualValue(score, 0.0, 100.0);
   return g_virtualEntryResultScore;
}

void EndVirtualEntrySimulation(ENUM_VIRTUAL_ENTRY_STATE endState, string reason)
{
   if(!g_virtualEntryActive && g_virtualEntry.state != VIRTUAL_ENTRY_ACTIVE)
      return;

   g_virtualEntry.state = endState;
   g_virtualEntry.endTime = TimeCurrent();
   g_virtualEntry.endReason = reason;
   g_virtualEntry.statusText = VirtualEntryStateToText(endState);

   g_virtualEntryWin = (endState == VIRTUAL_ENTRY_WIN);
   g_virtualEntryLoss = (endState == VIRTUAL_ENTRY_LOSS);
   g_virtualEntryTimeout = (endState == VIRTUAL_ENTRY_TIMEOUT);
   g_virtualEntryInvalidated = (endState == VIRTUAL_ENTRY_INVALIDATED);
   g_virtualEntryCancelled = (endState == VIRTUAL_ENTRY_CANCELLED);

   UpdateVirtualEntryStats(endState);
   GetVirtualEntryResultScore();

   g_lastVirtualEntryEndTime = TimeCurrent();
   g_virtualEntryActive = false;
   g_virtualEntryCompleted = true;
   g_virtualEntryStatus = VirtualEntryStateToText(endState);
   g_virtualEntryReason = reason;
   g_virtualEntryDirectionText = VirtualEntryDirectionToText(g_virtualEntry.direction);

   if(endState == VIRTUAL_ENTRY_WIN)
      AuditVirtualEntry("VIRTUAL ENTRY WIN");
   else if(endState == VIRTUAL_ENTRY_LOSS)
      AuditVirtualEntry("VIRTUAL ENTRY LOSS");
   else if(endState == VIRTUAL_ENTRY_TIMEOUT)
      AuditVirtualEntry("VIRTUAL ENTRY TIMEOUT");
   else if(endState == VIRTUAL_ENTRY_INVALIDATED)
      AuditVirtualEntry("VIRTUAL ENTRY INVALIDATED");
   else if(endState == VIRTUAL_ENTRY_CANCELLED)
      AuditVirtualEntry("VIRTUAL ENTRY CANCELLED");
}

void UpdateVirtualEntrySimulation()
{
   if(!UseVirtualEntrySimulation)
   {
      g_virtualEntryActive = false;
      g_virtualEntryCompleted = false;
      g_virtualEntryWin = false;
      g_virtualEntryLoss = false;
      g_virtualEntryTimeout = false;
      g_virtualEntryInvalidated = false;
      g_virtualEntryCancelled = false;
      g_virtualEntry.state = VIRTUAL_ENTRY_NONE;
      g_virtualEntry.direction = VIRTUAL_DIR_NONE;
      g_virtualEntry.statusText = "VIRTUAL ENTRY ENGINE DISABLED";
      g_virtualEntryStatus = "VIRTUAL ENTRY ENGINE DISABLED";
      g_virtualEntryReason = "DISABLED - PASS";
      g_virtualEntryDirectionText = "NONE";
      return;
   }

   if(!g_virtualEntryActive)
   {
      string startReason = "";
      if(!StartVirtualEntrySimulation(startReason))
      {
         g_virtualEntryStatus = "VIRTUAL ENTRY WAITING";
         g_virtualEntryReason = startReason;
         g_virtualEntryDirectionText = "NONE";
         g_virtualEntryResultScore = GetVirtualEntryResultScore();
         if(StringFind(startReason, "INVALID") >= 0)
            AuditVirtualEntry("INVALID VIRTUAL PRICE");
         else if(startReason == "VIRTUAL ENTRY ALREADY STARTED THIS CANDLE")
            AuditVirtualEntry("VIRTUAL ENTRY ALREADY STARTED THIS CANDLE");
         else
            AuditVirtualEntry("VIRTUAL ENTRY WAITING");
         return;
      }

      if(VirtualEntryDiagnosticOnly)
         AuditVirtualEntry("DIAGNOSTIC ONLY - NO TRADING");
      return;
   }

   g_virtualEntry.ageSeconds = (int)(TimeCurrent() - g_virtualEntry.startTime);
   int barShift = iBarShift(_Symbol, _Period, g_virtualEntry.startBarTime, false);
   g_virtualEntry.ageBars = (barShift >= 0 ? barShift : 0);

   UpdateVirtualEntryProfit();
   GetVirtualEntryResultScore();

   string checkReason = "";
   if(IsVirtualEntryCancelled(checkReason))
   {
      EndVirtualEntrySimulation(VIRTUAL_ENTRY_CANCELLED, checkReason);
      return;
   }

   if(IsVirtualEntryInvalidated(checkReason))
   {
      EndVirtualEntrySimulation(VIRTUAL_ENTRY_INVALIDATED, checkReason);
      return;
   }

   if(IsVirtualEntryHitSL())
   {
      EndVirtualEntrySimulation(VIRTUAL_ENTRY_LOSS, "VIRTUAL SL HIT");
      return;
   }

   if(IsVirtualEntryHitTP())
   {
      EndVirtualEntrySimulation(VIRTUAL_ENTRY_WIN, "VIRTUAL TP HIT");
      return;
   }

   if(IsVirtualEntryExpired())
   {
      EndVirtualEntrySimulation(VIRTUAL_ENTRY_TIMEOUT, "VIRTUAL ENTRY TIMEOUT");
      return;
   }

   g_virtualEntryStatus = "VIRTUAL ENTRY ACTIVE";
   g_virtualEntryReason = "VIRTUAL ENTRY ACTIVE";
   g_virtualEntryDirectionText = VirtualEntryDirectionToText(g_virtualEntry.direction);
   AuditVirtualEntry("VIRTUAL ENTRY ACTIVE");
}

string VirtualEntryStateToText(ENUM_VIRTUAL_ENTRY_STATE state)
{
   switch(state)
   {
      case VIRTUAL_ENTRY_NONE:        return "VIRTUAL_ENTRY_NONE";
      case VIRTUAL_ENTRY_ACTIVE:      return "VIRTUAL_ENTRY_ACTIVE";
      case VIRTUAL_ENTRY_WIN:         return "VIRTUAL_ENTRY_WIN";
      case VIRTUAL_ENTRY_LOSS:        return "VIRTUAL_ENTRY_LOSS";
      case VIRTUAL_ENTRY_TIMEOUT:     return "VIRTUAL_ENTRY_TIMEOUT";
      case VIRTUAL_ENTRY_INVALIDATED: return "VIRTUAL_ENTRY_INVALIDATED";
      case VIRTUAL_ENTRY_CANCELLED:   return "VIRTUAL_ENTRY_CANCELLED";
      default:                        return "VIRTUAL_ENTRY_UNKNOWN";
   }
}

string VirtualEntryDirectionToText(ENUM_VIRTUAL_ENTRY_DIRECTION direction)
{
   switch(direction)
   {
      case VIRTUAL_DIR_BUY:  return "BUY";
      case VIRTUAL_DIR_SELL: return "SELL";
      default:               return "NONE";
   }
}

bool CanPrintVirtualEntryLog(string reason)
{
   datetime now = TimeCurrent();

   if(reason != g_lastVirtualEntryLoggedReason)
   {
      g_lastVirtualEntryLoggedReason = reason;
      g_lastVirtualEntryLogTime = now;
      return true;
   }

   if((now - g_lastVirtualEntryLogTime) >= MinSecondsBetweenVirtualEntryLogs)
   {
      g_lastVirtualEntryLogTime = now;
      return true;
   }

   return false;
}

void AuditVirtualEntry(string message)
{
   if(!PrintDetailedLogs || !PrintVirtualEntryDiagnostics)
      return;

   if(!CanPrintVirtualEntryLog(message))
      return;

   Print("[HORSE EA][VIRTUAL_ENTRY] ", message);
}

bool CanStartPreExecutionRiskGate()
{
   // Placeholder for ETAPA 8 - Pre-Execution Risk Gate Engine.
   return false;
}

bool WasLastVirtualEntryWin()
{
   return g_virtualEntryWin;
}

bool WasLastVirtualEntryLoss()
{
   return g_virtualEntryLoss;
}

bool HasActiveVirtualEntry()
{
   return g_virtualEntryActive;
}

bool HasCompletedVirtualEntry()
{
   return g_virtualEntryCompleted;
}

ENUM_VIRTUAL_ENTRY_STATE GetVirtualEntryState()
{
   return g_virtualEntry.state;
}

bool CanStartVirtualEntrySimulation()
{
   string reason = "";
   return CanStartVirtualEntrySimulationNow(reason);
}

ENUM_ENTRY_DECISION GetCurrentEntryDecision()
{
   return g_entryDecision;
}

double GetBuyDecisionScore()
{
   return g_buyDecisionScore;
}

double GetSellDecisionScore()
{
   return g_sellDecisionScore;
}

bool HasValidDecision()
{
   return (g_entryDecision == ENTRY_DECISION_BUY || g_entryDecision == ENTRY_DECISION_SELL);
}

bool CanStartMicroCycle()
{
   // Placeholder for future Dual Direction Micro Cycle.
   return false;
}

void PrepareForExecutionEngine()
{
   // Placeholder for ETAPA 7 - Execution Engine.
}


//+------------------------------------------------------------------+
//| ETAPA 8 - Pre-Execution Risk Gate Engine                         |
//+------------------------------------------------------------------+
void InitializePreExecutionData()
{
   ZeroMemory(g_preExecution);
   g_preExecution.state = PRE_EXECUTION_WAIT;
   g_preExecution.statusText = "WAITING";
   g_preExecution.reason = "INITIALIZED";

   g_preExecutionApproved = false;
   g_preExecutionBlocked = false;
   g_preExecutionWaiting = true;
   g_preExecutionRiskDanger = false;

   g_preExecutionScore = 0.0;
   g_preExecutionRiskScore = 0.0;
   g_preExecutionVirtualScore = 0.0;
   g_preExecutionAccountScore = 0.0;
   g_preExecutionCostScore = 0.0;
   g_preExecutionRRScore = 0.0;
   g_preExecutionDailyRiskScore = 0.0;

   g_estimatedExecutionLot = 0.0;
   g_estimatedRiskMoney = 0.0;
   g_estimatedRewardMoney = 0.0;
   g_estimatedRiskPercent = 0.0;
   g_estimatedSpreadCostMoney = 0.0;
   g_estimatedCommissionBufferMoney = 0.0;

   g_preExecutionStatus = "WAITING";
   g_preExecutionReason = "INITIALIZED";
   g_preExecutionBlockReason = "NONE";
   g_preExecutionDirection = "NONE";
}

double ClampPreExecutionScore(double value)
{
   if(value < 0.0) return 0.0;
   if(value > 100.0) return 100.0;
   return value;
}

double NormalizePreExecutionScore(double value, double minValue, double maxValue)
{
   if(maxValue <= minValue)
      return 0.0;

   return ClampPreExecutionScore(((value - minValue) / (maxValue - minValue)) * 100.0);
}

double NormalizeEstimatedLot(double lot)
{
   double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(minVol <= 0.0)
      return 0.0;

   if(maxVol < minVol)
      maxVol = minVol;

   if(step <= 0.0)
      step = minVol;
   if(step <= 0.0)
      step = 0.01;

   lot = MathMax(minVol, MathMin(maxVol, lot));
   lot = MathFloor(lot / step) * step;

   if(lot < minVol)
      lot = minVol;

   return NormalizeDouble(lot, 2);
}

double CalculateEstimatedExecutionLot()
{
   double lot = FixedEstimatedLot;

   if(UseRiskPercentEstimatedLot)
   {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double riskPoints = g_virtualEntry.virtualRiskPoints;
      if(riskPoints <= 0.0)
         riskPoints = CalculateVirtualSLPoints();

      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

      if(equity > 0.0 && riskPoints > 0.0 && tickValue > 0.0 && tickSize > 0.0 && _Point > 0.0)
      {
         double riskMoney = equity * EstimatedRiskPercentPerTrade / 100.0;
         double moneyPerLot = (riskPoints * _Point / tickSize) * tickValue;
         if(moneyPerLot > 0.0)
            lot = riskMoney / moneyPerLot;
      }
   }
   else if(!UseFixedEstimatedLot)
      lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   return NormalizeEstimatedLot(lot);
}

double CalculateEstimatedRiskMoney(double lot)
{
   double riskPoints = g_virtualEntry.virtualRiskPoints;
   if(riskPoints <= 0.0)
      riskPoints = CalculateVirtualSLPoints();
   if(riskPoints <= 0.0 || lot <= 0.0)
      return 0.0;

   return MathAbs(CalculateVirtualMoneyFromPoints(riskPoints, lot));
}

double CalculateEstimatedRewardMoney(double lot)
{
   double rewardPoints = g_virtualEntry.virtualRewardPoints;
   if(rewardPoints <= 0.0)
      rewardPoints = CalculateVirtualTPPoints();
   if(rewardPoints <= 0.0 || lot <= 0.0)
      return 0.0;

   return MathAbs(CalculateVirtualMoneyFromPoints(rewardPoints, lot));
}

double CalculateEstimatedRiskPercent(double riskMoney)
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0)
      return 100.0;

   return (riskMoney / equity) * 100.0;
}

double CalculateEstimatedSpreadCostMoney(double lot)
{
   if(g_currentSpreadPoints < 0 || lot <= 0.0)
      return MaxEstimatedSpreadCostMoney * 10.0;

   return MathAbs(CalculateVirtualMoneyFromPoints((double)g_currentSpreadPoints, lot));
}

double CalculateEstimatedCommissionBufferMoney(double lot)
{
   if(lot <= 0.0)
      return 0.0;
   return CommissionBufferPerLot * lot;
}

double CalculatePreExecutionRiskScore()
{
   if(g_estimatedRiskMoney <= 0.0)
      return 0.0;

   double moneyScore = 100.0;
   if(MaxPreExecutionRiskMoney > 0.0)
      moneyScore = 100.0 - NormalizePreExecutionScore(g_estimatedRiskMoney, MaxPreExecutionRiskMoney, MaxPreExecutionRiskMoney * 2.0);

   double percentScore = 100.0;
   if(MaxPreExecutionRiskPercent > 0.0)
      percentScore = 100.0 - NormalizePreExecutionScore(g_estimatedRiskPercent, MaxPreExecutionRiskPercent, MaxPreExecutionRiskPercent * 2.0);

   return ClampPreExecutionScore(MathMin(moneyScore, percentScore));
}

double CalculatePreExecutionVirtualConfirmationScore()
{
   if(!RequireVirtualEntryConfirmation)
      return 80.0;

   if(g_virtualEntryWin)
      return 100.0;

   if(g_virtualEntryActive && AllowActiveVirtualEntryForApproval)
      return ClampPreExecutionScore(g_virtualEntryResultScore);

   if(g_virtualEntryTimeout)
   {
      if(AllowTimeoutVirtualEntryIfProfitable && g_virtualEntry.currentProfitPoints > 0.0)
         return 65.0;
      return 35.0;
   }

   if(g_virtualEntryLoss)
      return 0.0;

   if(g_virtualEntryInvalidated)
      return 20.0;

   if(g_virtualEntryCancelled)
      return (BlockIfVirtualCancelled ? 20.0 : 50.0);

   return 40.0;
}

double CalculatePreExecutionAccountSafetyScore()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);

   if(equity <= 0.0)
      return 0.0;

   double score = 100.0;

   if(balance > 0.0)
   {
      double minEquity = balance * MinEquityProtectionPercent / 100.0;
      if(equity < minEquity)
         score = MathMin(score, 35.0);
   }

   if(UseMarginPreExecutionCheck)
   {
      if(freeMargin <= 0.0)
         score = MathMin(score, 10.0);

      if(marginLevel > 0.0 && marginLevel < MinMarginLevelForPreExecution)
         score = MathMin(score, 35.0);

      double minFreeAfter = equity * MinFreeMarginAfterEstimatedTradePercent / 100.0;
      if((freeMargin - g_estimatedRiskMoney) < minFreeAfter)
         score = MathMin(score, 45.0);
   }

   return ClampPreExecutionScore(score);
}

double CalculatePreExecutionTradeCostScore()
{
   if(!UseSpreadCostPreCheck)
      return 80.0;

   double score = 100.0;

   if(g_estimatedSpreadCostMoney > MaxEstimatedSpreadCostMoney)
      score = MathMin(score, 35.0);

   if(g_currentSpreadPoints > MaxSpreadPoints)
      score = MathMin(score, 30.0);

   return ClampPreExecutionScore(score);
}

double CalculatePreExecutionRRScore()
{
   double rr = g_virtualEntry.virtualRR;

   if(rr <= 0.0)
   {
      double sl = CalculateVirtualSLPoints();
      double tp = CalculateVirtualTPPoints();
      rr = CalculateVirtualRiskRewardRatio(sl, tp);
   }

   if(rr <= 0.0)
      return 0.0;
   if(rr < MinVirtualRRForApproval)
      return 35.0;
   if(rr >= 2.0)
      return 100.0;
   if(rr >= 1.5)
      return 85.0;

   return 65.0;
}

double CalculatePreExecutionDailyRiskScore()
{
   if(!UseDailyRiskPreCheck)
      return 80.0;

   if(g_estimatedRiskMoney > MaxDailyEstimatedLossMoney)
      return 20.0;

   if(g_estimatedRiskPercent > MaxDailyRiskPercentPreCheck)
      return 25.0;

   return 90.0;
}

double CalculatePreExecutionFinalScore()
{
   g_preExecutionRiskScore = CalculatePreExecutionRiskScore();
   g_preExecutionVirtualScore = CalculatePreExecutionVirtualConfirmationScore();
   g_preExecutionAccountScore = CalculatePreExecutionAccountSafetyScore();
   g_preExecutionCostScore = CalculatePreExecutionTradeCostScore();
   g_preExecutionRRScore = CalculatePreExecutionRRScore();
   g_preExecutionDailyRiskScore = CalculatePreExecutionDailyRiskScore();

   double finalScore =
      (g_preExecutionRiskScore * 0.25) +
      (g_preExecutionVirtualScore * 0.20) +
      (g_preExecutionAccountScore * 0.20) +
      (g_preExecutionCostScore * 0.15) +
      (g_preExecutionRRScore * 0.10) +
      (g_preExecutionDailyRiskScore * 0.10);

   g_preExecutionScore = ClampPreExecutionScore(finalScore);
   return g_preExecutionScore;
}

bool IsPreExecutionVirtualApproved(string &reason)
{
   if(!RequireVirtualEntryConfirmation)
   {
      reason = "VIRTUAL NOT REQUIRED";
      return true;
   }

   if(RequireVirtualEntryWinForApproval && !g_virtualEntryWin)
   {
      reason = "VIRTUAL WIN REQUIRED";
      return false;
   }

   if(BlockIfVirtualLoss && g_virtualEntryLoss)
   {
      reason = "VIRTUAL LOSS";
      return false;
   }

   if(BlockIfVirtualInvalidated && g_virtualEntryInvalidated)
   {
      reason = "VIRTUAL INVALIDATED";
      return false;
   }

   if(BlockIfVirtualCancelled && g_virtualEntryCancelled)
   {
      reason = "VIRTUAL CANCELLED";
      return false;
   }

   if(BlockIfVirtualTimeoutNegative && g_virtualEntryTimeout && g_virtualEntry.currentProfitPoints <= 0.0)
   {
      reason = "VIRTUAL TIMEOUT NEGATIVE";
      return false;
   }

   if(g_virtualEntryResultScore < MinVirtualResultScoreForApproval)
   {
      reason = "VIRTUAL SCORE LOW";
      return false;
   }

   reason = "VIRTUAL APPROVED";
   return true;
}

bool IsPreExecutionDecisionApproved(string &reason)
{
   if(!RequireValidEntryDecisionForPreExecution)
   {
      reason = "DECISION NOT REQUIRED";
      return true;
   }

   if(g_entryDecision != ENTRY_DECISION_BUY && g_entryDecision != ENTRY_DECISION_SELL)
   {
      reason = "NO VALID ENTRY DECISION";
      return false;
   }

   if(!g_entryDecisionOK && !(EntryDecisionDiagnosticOnly && PreExecutionDiagnosticOnly))
   {
      reason = "ENTRY DECISION NOT OK";
      return false;
   }

   if(RequireEntryBaseForPreExecution && !g_entryBaseOK && !(EntryBaseDiagnosticOnly && PreExecutionDiagnosticOnly))
   {
      reason = "ENTRY BASE NOT OK";
      return false;
   }

   if(RequireEntryDecisionDirectionMatch && (g_virtualEntryActive || g_virtualEntryCompleted))
   {
      if(g_entryDecision == ENTRY_DECISION_BUY && g_virtualEntry.direction == VIRTUAL_DIR_SELL)
      {
         reason = "DECISION VIRTUAL DIRECTION MISMATCH";
         return false;
      }

      if(g_entryDecision == ENTRY_DECISION_SELL && g_virtualEntry.direction == VIRTUAL_DIR_BUY)
      {
         reason = "DECISION VIRTUAL DIRECTION MISMATCH";
         return false;
      }
   }

   reason = "DECISION APPROVED";
   return true;
}

bool IsPreExecutionRiskApproved(string &reason)
{
   if(g_estimatedRiskMoney > MaxPreExecutionRiskMoney)
   {
      reason = "RISK MONEY TOO HIGH";
      return false;
   }

   if(g_estimatedRiskPercent > MaxPreExecutionRiskPercent)
   {
      reason = "RISK PERCENT TOO HIGH";
      return false;
   }

   if(BlockIfRiskScoreLow && g_preExecutionRiskScore < 60.0)
   {
      reason = "RISK SCORE LOW";
      return false;
   }

   reason = "RISK APPROVED";
   return true;
}

bool IsPreExecutionAccountApproved(string &reason)
{
   if(!UseMarginPreExecutionCheck)
   {
      reason = "ACCOUNT CHECK DISABLED";
      return true;
   }

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);

   if(equity <= 0.0)
   {
      reason = "INVALID EQUITY";
      return false;
   }

   if(freeMargin <= 0.0)
   {
      reason = "INVALID FREE MARGIN";
      return false;
   }

   if(marginLevel > 0.0 && marginLevel < MinMarginLevelForPreExecution)
   {
      reason = "MARGIN LEVEL LOW";
      return false;
   }

   double minFreeAfter = equity * MinFreeMarginAfterEstimatedTradePercent / 100.0;
   if((freeMargin - g_estimatedRiskMoney) < minFreeAfter)
   {
      reason = "FREE MARGIN AFTER TRADE LOW";
      return false;
   }

   reason = "ACCOUNT APPROVED";
   return true;
}

bool IsPreExecutionCostApproved(string &reason)
{
   if(!UseSpreadCostPreCheck)
   {
      reason = "COST CHECK DISABLED";
      return true;
   }

   if(g_estimatedSpreadCostMoney > MaxEstimatedSpreadCostMoney)
   {
      reason = "SPREAD COST TOO HIGH";
      return false;
   }

   if(g_currentSpreadPoints > MaxSpreadPoints)
   {
      reason = "SPREAD TOO HIGH";
      return false;
   }

   reason = "COST APPROVED";
   return true;
}

bool IsPreExecutionRRApproved(string &reason)
{
   if(!BlockIfRRTooLow)
   {
      reason = "RR CHECK DISABLED";
      return true;
   }

   double rr = g_virtualEntry.virtualRR;
   if(rr <= 0.0)
      rr = CalculateVirtualRiskRewardRatio(CalculateVirtualSLPoints(), CalculateVirtualTPPoints());

   if(rr < MinVirtualRRForApproval)
   {
      reason = "RR TOO LOW";
      return false;
   }

   reason = "RR APPROVED";
   return true;
}

bool IsPreExecutionDailyRiskApproved(string &reason)
{
   if(!UseDailyRiskPreCheck)
   {
      reason = "DAILY RISK CHECK DISABLED";
      return true;
   }

   if(g_estimatedRiskMoney > MaxDailyEstimatedLossMoney)
   {
      reason = "DAILY MONEY RISK TOO HIGH";
      return false;
   }

   if(g_estimatedRiskPercent > MaxDailyRiskPercentPreCheck)
   {
      reason = "DAILY RISK PERCENT TOO HIGH";
      return false;
   }

   reason = "DAILY RISK APPROVED";
   return true;
}

ENUM_PRE_EXECUTION_STATE DetectPreExecutionState()
{
   if(!UsePreExecutionRiskGate)
      return PRE_EXECUTION_DISABLED;

   if(!g_symbolOK || !g_timeframeOK || !g_environmentOK || !g_securityFiltersOK || !g_market.isTradable || !g_flowOK)
   {
      g_preExecutionBlockReason = "PREVIOUS FILTER BLOCKED";
      return PRE_EXECUTION_WAIT;
   }

   string reason = "";

   if(!IsPreExecutionDecisionApproved(reason))
   {
      g_preExecutionBlockReason = reason;
      return PRE_EXECUTION_BLOCKED;
   }

   if(!IsPreExecutionRiskApproved(reason))
   {
      g_preExecutionBlockReason = reason;
      return PRE_EXECUTION_RISK_DANGER;
   }

   if(!IsPreExecutionAccountApproved(reason))
   {
      g_preExecutionBlockReason = reason;
      return PRE_EXECUTION_RISK_DANGER;
   }

   if(!IsPreExecutionCostApproved(reason))
   {
      g_preExecutionBlockReason = reason;
      return PRE_EXECUTION_BLOCKED;
   }

   if(!IsPreExecutionRRApproved(reason))
   {
      g_preExecutionBlockReason = reason;
      return PRE_EXECUTION_BLOCKED;
   }

   if(!IsPreExecutionDailyRiskApproved(reason))
   {
      g_preExecutionBlockReason = reason;
      return PRE_EXECUTION_RISK_DANGER;
   }

   if(!IsPreExecutionVirtualApproved(reason))
   {
      g_preExecutionBlockReason = reason;
      return PRE_EXECUTION_BLOCKED;
   }

   if(g_preExecutionScore < MinPreExecutionScore)
   {
      g_preExecutionBlockReason = "PRE EXECUTION SCORE LOW";
      return PRE_EXECUTION_WAIT;
   }

   g_preExecutionBlockReason = "NONE";
   return PRE_EXECUTION_APPROVED;
}

bool IsPreExecutionTradable(string &reason)
{
   if(!UsePreExecutionRiskGate)
   {
      reason = "PRE EXECUTION ENGINE DISABLED";
      return true;
   }

   switch(g_preExecution.state)
   {
      case PRE_EXECUTION_APPROVED:
         reason = "PRE EXECUTION APPROVED";
         return true;
      case PRE_EXECUTION_WAIT:
         reason = "PRE EXECUTION WAITING";
         return false;
      case PRE_EXECUTION_BLOCKED:
         reason = "PRE EXECUTION BLOCKED";
         return false;
      case PRE_EXECUTION_RISK_DANGER:
         reason = "PRE EXECUTION RISK DANGER";
         return false;
      default:
         reason = "PRE EXECUTION ENGINE DISABLED";
         return true;
   }
}

string PreExecutionStateToText(ENUM_PRE_EXECUTION_STATE state)
{
   switch(state)
   {
      case PRE_EXECUTION_DISABLED:    return "PRE_EXECUTION_DISABLED";
      case PRE_EXECUTION_WAIT:        return "PRE_EXECUTION_WAIT";
      case PRE_EXECUTION_APPROVED:    return "PRE_EXECUTION_APPROVED";
      case PRE_EXECUTION_BLOCKED:     return "PRE_EXECUTION_BLOCKED";
      case PRE_EXECUTION_RISK_DANGER: return "PRE_EXECUTION_RISK_DANGER";
      default:                        return "PRE_EXECUTION_UNKNOWN";
   }
}

string PreExecutionStatusToText()
{
   if(!UsePreExecutionRiskGate)
      return "PRE EXECUTION ENGINE DISABLED";

   if(PreExecutionDiagnosticOnly)
      return "DIAGNOSTIC ONLY";

   switch(g_preExecution.state)
   {
      case PRE_EXECUTION_APPROVED:    return "PRE EXECUTION APPROVED";
      case PRE_EXECUTION_WAIT:        return "PRE EXECUTION WAITING";
      case PRE_EXECUTION_BLOCKED:     return "PRE EXECUTION BLOCKED";
      case PRE_EXECUTION_RISK_DANGER: return "PRE EXECUTION RISK DANGER";
      default:                        return "PRE EXECUTION ENGINE DISABLED";
   }
}

bool CanPrintPreExecutionLog(string reason)
{
   datetime now = TimeCurrent();

   if(reason != g_lastPreExecutionLoggedReason)
   {
      g_lastPreExecutionLoggedReason = reason;
      g_lastPreExecutionLogTime = now;
      return true;
   }

   if((now - g_lastPreExecutionLogTime) >= MinSecondsBetweenPreExecutionLogs)
   {
      g_lastPreExecutionLogTime = now;
      return true;
   }

   return false;
}

void AuditPreExecution(string message)
{
   if(!PrintDetailedLogs || !PrintPreExecutionDiagnostics)
      return;

   if(!CanPrintPreExecutionLog(message))
      return;

   Print("[HORSE EA][PRE_EXECUTION] ", message);
}

void UpdatePreExecutionRiskGate()
{
   if(!UsePreExecutionRiskGate)
   {
      g_preExecution.state = PRE_EXECUTION_DISABLED;

      g_preExecutionApproved = true;
      g_preExecutionBlocked = false;
      g_preExecutionWaiting = false;
      g_preExecutionRiskDanger = false;

      g_preExecutionScore = 0.0;
      g_preExecutionRiskScore = 0.0;
      g_preExecutionVirtualScore = 0.0;
      g_preExecutionAccountScore = 0.0;
      g_preExecutionCostScore = 0.0;
      g_preExecutionRRScore = 0.0;
      g_preExecutionDailyRiskScore = 0.0;

      g_estimatedExecutionLot = 0.0;
      g_estimatedRiskMoney = 0.0;
      g_estimatedRewardMoney = 0.0;
      g_estimatedRiskPercent = 0.0;
      g_estimatedSpreadCostMoney = 0.0;
      g_estimatedCommissionBufferMoney = 0.0;

      g_preExecutionStatus = "PRE EXECUTION ENGINE DISABLED";
      g_preExecutionReason = "DISABLED - PASS";
      g_preExecutionBlockReason = "NONE";
      g_preExecutionDirection = "NONE";

      g_preExecution.approved = true;
      g_preExecution.blocked = false;
      g_preExecution.waiting = false;
      g_preExecution.riskDanger = false;
      g_preExecution.preExecutionScore = 0.0;
      g_preExecution.riskScore = 0.0;
      g_preExecution.virtualConfirmationScore = 0.0;
      g_preExecution.accountSafetyScore = 0.0;
      g_preExecution.tradeCostScore = 0.0;
      g_preExecution.rrScore = 0.0;
      g_preExecution.dailyRiskScore = 0.0;
      g_preExecution.estimatedLot = 0.0;
      g_preExecution.estimatedRiskMoney = 0.0;
      g_preExecution.estimatedRewardMoney = 0.0;
      g_preExecution.estimatedRiskPercent = 0.0;
      g_preExecution.estimatedSpreadCostMoney = 0.0;
      g_preExecution.estimatedCommissionBufferMoney = 0.0;
      g_preExecution.direction = "NONE";
      g_preExecution.statusText = "PRE EXECUTION ENGINE DISABLED";
      g_preExecution.reason = "DISABLED - PASS";
      g_preExecution.blockReason = "NONE";
      return;
   }

   g_preExecution.accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_preExecution.accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_preExecution.accountFreeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   g_preExecution.accountMarginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   g_preExecution.lastUpdateTime = TimeCurrent();
   g_preExecution.minRequiredScore = MinPreExecutionScore;
   g_preExecution.maxAllowedRiskMoney = MaxPreExecutionRiskMoney;
   g_preExecution.maxAllowedRiskPercent = MaxPreExecutionRiskPercent;

   g_estimatedExecutionLot = CalculateEstimatedExecutionLot();
   g_estimatedRiskMoney = CalculateEstimatedRiskMoney(g_estimatedExecutionLot);
   g_estimatedRewardMoney = CalculateEstimatedRewardMoney(g_estimatedExecutionLot);
   g_estimatedRiskPercent = CalculateEstimatedRiskPercent(g_estimatedRiskMoney);
   g_estimatedSpreadCostMoney = CalculateEstimatedSpreadCostMoney(g_estimatedExecutionLot);
   g_estimatedCommissionBufferMoney = CalculateEstimatedCommissionBufferMoney(g_estimatedExecutionLot);

   CalculatePreExecutionFinalScore();

   g_preExecution.state = DetectPreExecutionState();
   g_preExecutionApproved = (g_preExecution.state == PRE_EXECUTION_APPROVED);
   g_preExecutionBlocked = (g_preExecution.state == PRE_EXECUTION_BLOCKED);
   g_preExecutionWaiting = (g_preExecution.state == PRE_EXECUTION_WAIT);
   g_preExecutionRiskDanger = (g_preExecution.state == PRE_EXECUTION_RISK_DANGER);

   g_preExecutionDirection = g_entryDecisionDirection;
   if(g_preExecutionDirection == "NONE" && g_virtualEntry.direction != VIRTUAL_DIR_NONE)
      g_preExecutionDirection = VirtualEntryDirectionToText(g_virtualEntry.direction);

   g_preExecutionStatus = PreExecutionStatusToText();
   g_preExecutionReason = PreExecutionStateToText(g_preExecution.state);

   if(g_preExecutionBlockReason != "NONE")
      g_preExecutionReason = g_preExecutionBlockReason;

   if(PreExecutionDiagnosticOnly && !IsFunctionalExecutionOverrideActive())
   {
      g_preExecutionApproved = true;
      g_preExecutionStatus = "DIAGNOSTIC ONLY";
      if(StringFind(g_preExecutionReason, "DIAGNOSTIC ONLY") < 0)
         g_preExecutionReason = g_preExecutionReason + " - DIAGNOSTIC ONLY";
   }
   else if(IsFunctionalExecutionOverrideActive() && (PreExecutionDiagnosticOnly || ForceFunctionalIgnorePreExecutionDiagnostic))
   {
      g_preExecutionApproved = true;
      g_preExecutionBlocked = false;
      g_preExecutionWaiting = false;
      g_preExecutionStatus = "FUNCTIONAL OVERRIDE";
      g_preExecutionReason = "FUNCTIONAL OVERRIDE: PRE EXECUTION APPROVED FOR TEST";
      g_preExecutionBlockReason = "NONE";
      AuditPreExecution("[FUNCTIONAL_OVERRIDE] PRE EXECUTION DIAGNOSTIC BYPASSED");
   }

   g_preExecution.approved = g_preExecutionApproved;
   g_preExecution.blocked = g_preExecutionBlocked;
   g_preExecution.waiting = g_preExecutionWaiting;
   g_preExecution.riskDanger = g_preExecutionRiskDanger;
   g_preExecution.preExecutionScore = g_preExecutionScore;
   g_preExecution.riskScore = g_preExecutionRiskScore;
   g_preExecution.virtualConfirmationScore = g_preExecutionVirtualScore;
   g_preExecution.accountSafetyScore = g_preExecutionAccountScore;
   g_preExecution.tradeCostScore = g_preExecutionCostScore;
   g_preExecution.rrScore = g_preExecutionRRScore;
   g_preExecution.dailyRiskScore = g_preExecutionDailyRiskScore;
   g_preExecution.estimatedLot = g_estimatedExecutionLot;
   g_preExecution.estimatedRiskMoney = g_estimatedRiskMoney;
   g_preExecution.estimatedRewardMoney = g_estimatedRewardMoney;
   g_preExecution.estimatedRiskPercent = g_estimatedRiskPercent;
   g_preExecution.estimatedSpreadCostMoney = g_estimatedSpreadCostMoney;
   g_preExecution.estimatedCommissionBufferMoney = g_estimatedCommissionBufferMoney;
   g_preExecution.direction = g_preExecutionDirection;
   g_preExecution.statusText = g_preExecutionStatus;
   g_preExecution.reason = g_preExecutionReason;
   g_preExecution.blockReason = g_preExecutionBlockReason;

   AuditPreExecution("PRE EXECUTION UPDATED");

   if(g_preExecution.state == PRE_EXECUTION_APPROVED)
      AuditPreExecution("PRE EXECUTION APPROVED");
   else if(g_preExecution.state == PRE_EXECUTION_WAIT)
      AuditPreExecution("PRE EXECUTION WAITING");
   else if(g_preExecution.state == PRE_EXECUTION_BLOCKED)
      AuditPreExecution("PRE EXECUTION BLOCKED");
   else if(g_preExecution.state == PRE_EXECUTION_RISK_DANGER)
      AuditPreExecution("PRE EXECUTION RISK DANGER");

   if(PreExecutionDiagnosticOnly && !IsFunctionalExecutionOverrideActive())
      AuditPreExecution("DIAGNOSTIC ONLY - NO TRADING");
   else if(IsFunctionalExecutionOverrideActive() && ForceFunctionalIgnorePreExecutionDiagnostic)
      AuditPreExecution("[FUNCTIONAL_OVERRIDE] PRE EXECUTION DIAGNOSTIC BYPASSED");
}

bool CanStartExecutionDryRun()
{
   // Placeholder for ETAPA 9 - Execution Dry-Run / Real Execution Permission Engine.
   return false;
}

bool IsPreExecutionApproved()
{
   return g_preExecutionApproved;
}

double GetPreExecutionScore()
{
   return g_preExecutionScore;
}

string GetPreExecutionReason()
{
   return g_preExecutionReason;
}

//+------------------------------------------------------------------+
//| ETAPA 9 - Execution Dry-Run / Real Execution Permission Engine    |
//+------------------------------------------------------------------+
void InitializeExecutionDryRunData()
{
   ZeroMemory(g_executionDryRun);
   g_executionDryRun.state = DRY_RUN_WAIT;
   g_executionDryRun.direction = DRY_RUN_DIR_NONE;
   g_executionDryRun.statusText = "WAITING";
   g_executionDryRun.reason = "INITIALIZED";
   g_executionDryRun.blockReason = "NONE";
   g_executionDryRun.permissionReason = "INITIALIZED";
   g_dryRunApproved = false;
   g_dryRunBlocked = false;
   g_dryRunWaiting = true;
   g_dryRunBuyReady = false;
   g_dryRunSellReady = false;
   g_dryRunRiskBlock = false;
   g_dryRunDuplicateBlock = false;
   g_dryRunScore = 0.0;
   g_dryRunPermissionScore = 0.0;
   g_dryRunDirectionScore = 0.0;
   g_dryRunRiskPermissionScore = 0.0;
   g_dryRunDuplicateSafetyScore = 0.0;
   g_dryRunExecutionCostScore = 0.0;
   g_plannedExecutionLot = 0.0;
   g_plannedExecutionEntryPrice = 0.0;
   g_plannedExecutionSL = 0.0;
   g_plannedExecutionTP = 0.0;
   g_plannedExecutionRiskMoney = 0.0;
   g_plannedExecutionRewardMoney = 0.0;
   g_plannedExecutionRiskPercent = 0.0;
   g_dryRunStatus = "WAITING";
   g_dryRunReason = "INITIALIZED";
   g_dryRunBlockReason = "NONE";
   g_dryRunDirectionText = "NONE";
}

void ResetExecutionDryRunDisabled()
{
   g_executionDryRun.state = DRY_RUN_DISABLED;
   g_executionDryRun.direction = DRY_RUN_DIR_NONE;
   g_executionDryRun.approved = true;
   g_executionDryRun.blocked = false;
   g_executionDryRun.waiting = false;
   g_executionDryRun.buyReady = false;
   g_executionDryRun.sellReady = false;
   g_executionDryRun.riskBlock = false;
   g_executionDryRun.duplicateBlock = false;
   g_executionDryRun.lastUpdateTime = TimeCurrent();
   g_executionDryRun.dryRunScore = 0.0;
   g_executionDryRun.permissionScore = 0.0;
   g_executionDryRun.directionScore = 0.0;
   g_executionDryRun.riskPermissionScore = 0.0;
   g_executionDryRun.duplicateSafetyScore = 0.0;
   g_executionDryRun.executionCostScore = 0.0;
   g_executionDryRun.plannedLot = 0.0;
   g_executionDryRun.plannedEntryPrice = 0.0;
   g_executionDryRun.plannedSL = 0.0;
   g_executionDryRun.plannedTP = 0.0;
   g_executionDryRun.plannedRiskPoints = 0.0;
   g_executionDryRun.plannedRewardPoints = 0.0;
   g_executionDryRun.plannedRR = 0.0;
   g_executionDryRun.plannedRiskMoney = 0.0;
   g_executionDryRun.plannedRewardMoney = 0.0;
   g_executionDryRun.plannedRiskPercent = 0.0;
   g_executionDryRun.plannedSpreadCostMoney = 0.0;
   g_executionDryRun.plannedCommissionMoney = 0.0;
   g_executionDryRun.plannedOrderType = "NONE";
   g_executionDryRun.statusText = "EXECUTION DRY RUN ENGINE DISABLED";
   g_executionDryRun.reason = "DISABLED - PASS";
   g_executionDryRun.blockReason = "NONE";
   g_executionDryRun.permissionReason = "DISABLED";
   g_dryRunApproved = true;
   g_dryRunBlocked = false;
   g_dryRunWaiting = false;
   g_dryRunBuyReady = false;
   g_dryRunSellReady = false;
   g_dryRunRiskBlock = false;
   g_dryRunDuplicateBlock = false;
   g_dryRunScore = 0.0;
   g_dryRunPermissionScore = 0.0;
   g_dryRunDirectionScore = 0.0;
   g_dryRunRiskPermissionScore = 0.0;
   g_dryRunDuplicateSafetyScore = 0.0;
   g_dryRunExecutionCostScore = 0.0;
   g_plannedExecutionLot = 0.0;
   g_plannedExecutionEntryPrice = 0.0;
   g_plannedExecutionSL = 0.0;
   g_plannedExecutionTP = 0.0;
   g_plannedExecutionRiskMoney = 0.0;
   g_plannedExecutionRewardMoney = 0.0;
   g_plannedExecutionRiskPercent = 0.0;
   g_dryRunStatus = "EXECUTION DRY RUN ENGINE DISABLED";
   g_dryRunReason = "DISABLED - PASS";
   g_dryRunBlockReason = "NONE";
   g_dryRunDirectionText = "NONE";
}

double ClampDryRunScore(double value)
{
   if(value < 0.0) return 0.0;
   if(value > 100.0) return 100.0;
   return value;
}

double NormalizeDryRunScore(double value, double minValue, double maxValue)
{
   if(maxValue <= minValue) return 0.0;
   return ClampDryRunScore(((value - minValue) / (maxValue - minValue)) * 100.0);
}

ENUM_DRY_RUN_DIRECTION DetectDryRunDirection()
{
   if(g_entryDecision == ENTRY_DECISION_BUY) return DRY_RUN_DIR_BUY;
   if(g_entryDecision == ENTRY_DECISION_SELL) return DRY_RUN_DIR_SELL;
   if(g_virtualEntry.direction == VIRTUAL_DIR_BUY) return DRY_RUN_DIR_BUY;
   if(g_virtualEntry.direction == VIRTUAL_DIR_SELL) return DRY_RUN_DIR_SELL;
   return DRY_RUN_DIR_NONE;
}

string DryRunDirectionToText(ENUM_DRY_RUN_DIRECTION direction)
{
   switch(direction)
   {
      case DRY_RUN_DIR_BUY: return "BUY";
      case DRY_RUN_DIR_SELL: return "SELL";
      default: return "NONE";
   }
}

void ResetDryRunPlannedData()
{
   g_plannedExecutionLot = 0.0;
   g_plannedExecutionEntryPrice = 0.0;
   g_plannedExecutionSL = 0.0;
   g_plannedExecutionTP = 0.0;
   g_plannedExecutionRiskMoney = 0.0;
   g_plannedExecutionRewardMoney = 0.0;
   g_plannedExecutionRiskPercent = 0.0;
   g_executionDryRun.plannedOrderType = "NONE";
   g_executionDryRun.plannedLot = 0.0;
   g_executionDryRun.plannedEntryPrice = 0.0;
   g_executionDryRun.plannedSL = 0.0;
   g_executionDryRun.plannedTP = 0.0;
   g_executionDryRun.plannedRiskPoints = 0.0;
   g_executionDryRun.plannedRewardPoints = 0.0;
   g_executionDryRun.plannedRR = 0.0;
   g_executionDryRun.plannedRiskMoney = 0.0;
   g_executionDryRun.plannedRewardMoney = 0.0;
   g_executionDryRun.plannedRiskPercent = 0.0;
   g_executionDryRun.plannedSpreadCostMoney = 0.0;
   g_executionDryRun.plannedCommissionMoney = 0.0;
}

void BuildPlannedExecutionData()
{
   ENUM_DRY_RUN_DIRECTION direction = DetectDryRunDirection();
   g_executionDryRun.direction = direction;
   g_dryRunDirectionText = DryRunDirectionToText(direction);
   if(direction == DRY_RUN_DIR_NONE)
   {
      ResetDryRunPlannedData();
      return;
   }
   double lot = g_estimatedExecutionLot;
   if(lot <= 0.0) lot = FixedEstimatedLot;
   lot = NormalizeEstimatedLot(lot);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double price = (direction == DRY_RUN_DIR_BUY ? ask : bid);
   double slPoints = g_virtualEntry.virtualRiskPoints;
   if(slPoints <= 0.0) slPoints = CalculateVirtualSLPoints();
   double tpPoints = g_virtualEntry.virtualRewardPoints;
   if(tpPoints <= 0.0) tpPoints = CalculateVirtualTPPoints();
   double plannedSL = g_virtualEntry.stopLossPrice;
   double plannedTP = g_virtualEntry.takeProfitPrice;
   if(plannedSL <= 0.0 && price > 0.0 && _Point > 0.0) plannedSL = (direction == DRY_RUN_DIR_BUY ? price - slPoints * _Point : price + slPoints * _Point);
   if(plannedTP <= 0.0 && price > 0.0 && _Point > 0.0) plannedTP = (direction == DRY_RUN_DIR_BUY ? price + tpPoints * _Point : price - tpPoints * _Point);
   double riskMoney = g_estimatedRiskMoney;
   if(riskMoney <= 0.0) riskMoney = CalculateEstimatedRiskMoney(lot);
   double rewardMoney = g_estimatedRewardMoney;
   if(rewardMoney <= 0.0) rewardMoney = CalculateEstimatedRewardMoney(lot);
   double riskPercent = g_estimatedRiskPercent;
   if(riskPercent <= 0.0) riskPercent = CalculateEstimatedRiskPercent(riskMoney);
   double spreadCost = g_estimatedSpreadCostMoney;
   if(spreadCost <= 0.0) spreadCost = CalculateEstimatedSpreadCostMoney(lot);
   double commission = g_estimatedCommissionBufferMoney;
   if(commission <= 0.0) commission = CalculateEstimatedCommissionBufferMoney(lot);
   g_plannedExecutionLot = lot;
   g_plannedExecutionEntryPrice = price;
   g_plannedExecutionSL = plannedSL;
   g_plannedExecutionTP = plannedTP;
   g_plannedExecutionRiskMoney = riskMoney;
   g_plannedExecutionRewardMoney = rewardMoney;
   g_plannedExecutionRiskPercent = riskPercent;
   g_executionDryRun.plannedOrderType = DryRunDirectionToText(direction);
   g_executionDryRun.plannedLot = lot;
   g_executionDryRun.plannedEntryPrice = price;
   g_executionDryRun.plannedSL = plannedSL;
   g_executionDryRun.plannedTP = plannedTP;
   g_executionDryRun.plannedRiskPoints = slPoints;
   g_executionDryRun.plannedRewardPoints = tpPoints;
   g_executionDryRun.plannedRR = (slPoints > 0.0 ? tpPoints / slPoints : 0.0);
   g_executionDryRun.plannedRiskMoney = riskMoney;
   g_executionDryRun.plannedRewardMoney = rewardMoney;
   g_executionDryRun.plannedRiskPercent = riskPercent;
   g_executionDryRun.plannedSpreadCostMoney = spreadCost;
   g_executionDryRun.plannedCommissionMoney = commission;
   g_executionDryRun.plannedBarTime = iTime(_Symbol, _Period, 0);
}

double CalculateDryRunPermissionScore()
{
   if(g_preExecutionRiskDanger) return 5.0;
   if(g_preExecutionBlocked) return 20.0;
   if(g_preExecutionWaiting) return 45.0;
   if(g_preExecutionApproved)
   {
      if(g_preExecutionScore >= ExcellentPreExecutionScore) return 100.0;
      if(g_preExecutionScore >= StrongPreExecutionScore) return 90.0;
      if(g_preExecutionScore >= MinPreExecutionScore) return 80.0;
      return 70.0;
   }
   return 30.0;
}

double CalculateDryRunDirectionScore()
{
   ENUM_DRY_RUN_DIRECTION direction = DetectDryRunDirection();
   if(direction == DRY_RUN_DIR_NONE) return 0.0;
   if(direction == DRY_RUN_DIR_BUY && !AllowDryRunBuy) return 10.0;
   if(direction == DRY_RUN_DIR_SELL && !AllowDryRunSell) return 10.0;
   if(RequireDirectionMatchAcrossEngines)
   {
      if(g_entryDecision == ENTRY_DECISION_BUY && direction != DRY_RUN_DIR_BUY) return 25.0;
      if(g_entryDecision == ENTRY_DECISION_SELL && direction != DRY_RUN_DIR_SELL) return 25.0;
      if((g_virtualEntryActive || g_virtualEntryCompleted) && g_virtualEntry.direction == VIRTUAL_DIR_BUY && direction != DRY_RUN_DIR_BUY) return 25.0;
      if((g_virtualEntryActive || g_virtualEntryCompleted) && g_virtualEntry.direction == VIRTUAL_DIR_SELL && direction != DRY_RUN_DIR_SELL) return 25.0;
   }
   return 90.0;
}

double CalculateDryRunRiskPermissionScore()
{
   if(!UseDryRunRiskPermission) return 80.0;
   if(g_plannedExecutionRiskMoney <= 0.0 || g_plannedExecutionRiskPercent <= 0.0) return 10.0;
   if(g_plannedExecutionRiskMoney > MaxDryRunRiskMoney || g_plannedExecutionRiskPercent > MaxDryRunRiskPercent) return 20.0;
   return 90.0;
}

double CalculateDryRunDuplicateSafetyScore()
{
   if(!UseDryRunDuplicateProtection) return 80.0;
   datetime barTime = iTime(_Symbol, _Period, 0);
   if(PreventDryRunSameCandle && g_lastDryRunApprovalBarTime > 0 && barTime == g_lastDryRunApprovalBarTime) return 15.0;
   if(MinSecondsBetweenDryRunApprovals > 0 && g_lastDryRunApprovalTime > 0)
   {
      int elapsed = (int)(TimeCurrent() - g_lastDryRunApprovalTime);
      if(elapsed < MinSecondsBetweenDryRunApprovals) return 25.0;
   }
   return 90.0;
}

double CalculateDryRunExecutionCostScore()
{
   if(g_executionDryRun.plannedSpreadCostMoney > MaxDryRunSpreadCostMoney) return 20.0;
   if(g_currentSpreadPoints > MaxSpreadPoints) return 25.0;
   return 90.0;
}

double CalculateDryRunFinalScore()
{
   g_dryRunPermissionScore = CalculateDryRunPermissionScore();
   g_dryRunDirectionScore = CalculateDryRunDirectionScore();
   g_dryRunRiskPermissionScore = CalculateDryRunRiskPermissionScore();
   g_dryRunDuplicateSafetyScore = CalculateDryRunDuplicateSafetyScore();
   g_dryRunExecutionCostScore = CalculateDryRunExecutionCostScore();
   g_dryRunScore = ClampDryRunScore((g_dryRunPermissionScore * 0.30) + (g_dryRunDirectionScore * 0.20) + (g_dryRunRiskPermissionScore * 0.20) + (g_dryRunDuplicateSafetyScore * 0.15) + (g_dryRunExecutionCostScore * 0.15));
   g_executionDryRun.dryRunScore = g_dryRunScore;
   g_executionDryRun.permissionScore = g_dryRunPermissionScore;
   g_executionDryRun.directionScore = g_dryRunDirectionScore;
   g_executionDryRun.riskPermissionScore = g_dryRunRiskPermissionScore;
   g_executionDryRun.duplicateSafetyScore = g_dryRunDuplicateSafetyScore;
   g_executionDryRun.executionCostScore = g_dryRunExecutionCostScore;
   return g_dryRunScore;
}

bool IsDryRunDirectionAllowed(string &reason)
{
   ENUM_DRY_RUN_DIRECTION direction = DetectDryRunDirection();
   if(direction == DRY_RUN_DIR_BUY && !AllowDryRunBuy){ reason = "DRY RUN BUY DISABLED"; return false; }
   if(direction == DRY_RUN_DIR_SELL && !AllowDryRunSell){ reason = "DRY RUN SELL DISABLED"; return false; }
   if(direction == DRY_RUN_DIR_NONE){ reason = "NO DRY RUN DIRECTION"; return false; }
   reason = "DRY RUN DIRECTION APPROVED";
   return true;
}

bool IsDryRunPreviousGatesApproved(string &reason)
{
   if(RequirePreExecutionApprovedForDryRun && !g_preExecutionApproved){ reason = "PRE EXECUTION NOT APPROVED"; return false; }
   if(BlockDryRunIfPreExecutionBlocked && g_preExecutionBlocked){ reason = "PRE EXECUTION BLOCKED"; return false; }
   if(BlockDryRunIfRiskDanger && g_preExecutionRiskDanger){ reason = "PRE EXECUTION RISK DANGER"; return false; }
   if(RequireValidDecisionForDryRun && !(g_entryDecision == ENTRY_DECISION_BUY || g_entryDecision == ENTRY_DECISION_SELL)){ reason = "NO VALID ENTRY DECISION"; return false; }
   if(RequireVirtualEntryForDryRun && !(g_virtualEntryActive || g_virtualEntryCompleted)){ reason = "NO VIRTUAL ENTRY"; return false; }
   if(RequireSecurityForDryRun && !g_securityFiltersOK){ reason = "SECURITY NOT APPROVED"; return false; }
   if(RequireMarketForDryRun){ string marketReason = ""; if(!IsMarketTradableByVolatility(marketReason)){ reason = "MARKET NOT APPROVED - " + marketReason; return false; } }
   if(RequireFlowForDryRun){ string flowReason = ""; if(!IsFlowTradable(flowReason)){ reason = "FLOW NOT APPROVED - " + flowReason; return false; } }
   reason = "PREVIOUS GATES APPROVED";
   return true;
}

bool IsDryRunRiskApproved(string &reason)
{
   if(!UseDryRunRiskPermission){ reason = "DRY RUN RISK PERMISSION DISABLED"; return true; }
   if(g_plannedExecutionRiskMoney > MaxDryRunRiskMoney){ reason = "DRY RUN RISK MONEY TOO HIGH"; return false; }
   if(g_plannedExecutionRiskPercent > MaxDryRunRiskPercent){ reason = "DRY RUN RISK PERCENT TOO HIGH"; return false; }
   if(g_plannedExecutionRiskMoney <= 0.0){ reason = "INVALID DRY RUN RISK"; return false; }
   if(g_executionDryRun.plannedRR < MinDryRunRR){ reason = "DRY RUN RR TOO LOW"; return false; }
   reason = "DRY RUN RISK APPROVED";
   return true;
}

bool IsDryRunDuplicateSafe(string &reason)
{
   if(!UseDryRunDuplicateProtection){ reason = "DRY RUN DUPLICATE PROTECTION DISABLED"; return true; }
   datetime barTime = iTime(_Symbol, _Period, 0);
   if(PreventDryRunSameCandle && g_lastDryRunApprovalBarTime > 0 && barTime == g_lastDryRunApprovalBarTime){ reason = "DRY RUN SAME CANDLE BLOCK"; return false; }
   if(MinSecondsBetweenDryRunApprovals > 0 && g_lastDryRunApprovalTime > 0)
   {
      int elapsed = (int)(TimeCurrent() - g_lastDryRunApprovalTime);
      if(elapsed < MinSecondsBetweenDryRunApprovals){ reason = "DRY RUN COOLDOWN"; return false; }
   }
   reason = "DRY RUN DUPLICATE SAFE";
   return true;
}

bool IsDryRunCostApproved(string &reason)
{
   if(g_executionDryRun.plannedSpreadCostMoney > MaxDryRunSpreadCostMoney){ reason = "DRY RUN SPREAD COST TOO HIGH"; return false; }
   if(g_currentSpreadPoints > MaxSpreadPoints){ reason = "DRY RUN SPREAD TOO HIGH"; return false; }
   reason = "DRY RUN COST APPROVED";
   return true;
}

bool IsDryRunSafetyApproved(string &reason)
{
   if(BlockDryRunIfVirtualLoss && g_virtualEntryLoss){ reason = "VIRTUAL LOSS BLOCK"; return false; }
   if(BlockDryRunIfVirtualInvalidated && g_virtualEntryInvalidated){ reason = "VIRTUAL INVALIDATED BLOCK"; return false; }
   if(BlockDryRunIfDecisionConflict && g_entryDecisionConflict){ reason = "DECISION CONFLICT BLOCK"; return false; }
   if(BlockDryRunIfFlowDangerous && g_flowDangerous){ reason = "FLOW DANGEROUS BLOCK"; return false; }
   if(BlockDryRunIfMarketDangerous && IsVolatilityDangerous()){ reason = "MARKET DANGEROUS BLOCK"; return false; }
   reason = "DRY RUN SAFETY APPROVED";
   return true;
}

ENUM_EXECUTION_DRY_RUN_STATE DetectExecutionDryRunState()
{
   if(!UseExecutionDryRun) return DRY_RUN_DISABLED;
   BuildPlannedExecutionData();
   CalculateDryRunFinalScore();
   string reason = "";
   if(!IsDryRunDuplicateSafe(reason)){ g_dryRunBlockReason = reason; return DRY_RUN_DUPLICATE_BLOCK; }
   if(!IsDryRunRiskApproved(reason)){ g_dryRunBlockReason = reason; return DRY_RUN_RISK_BLOCK; }
   if(!IsDryRunDirectionAllowed(reason)){ g_dryRunBlockReason = reason; return DRY_RUN_BLOCKED; }
   if(!IsDryRunPreviousGatesApproved(reason)){ g_dryRunBlockReason = reason; return DRY_RUN_BLOCKED; }
   if(!IsDryRunCostApproved(reason)){ g_dryRunBlockReason = reason; return DRY_RUN_BLOCKED; }
   if(!IsDryRunSafetyApproved(reason)){ g_dryRunBlockReason = reason; return DRY_RUN_BLOCKED; }
   g_dryRunBlockReason = "NONE";
   if(g_dryRunScore < MinDryRunScore) return DRY_RUN_WAIT;
   if(g_executionDryRun.direction == DRY_RUN_DIR_BUY) return DRY_RUN_BUY_READY;
   if(g_executionDryRun.direction == DRY_RUN_DIR_SELL) return DRY_RUN_SELL_READY;
   return DRY_RUN_APPROVED;
}

string ExecutionDryRunStateToText(ENUM_EXECUTION_DRY_RUN_STATE state)
{
   switch(state)
   {
      case DRY_RUN_DISABLED: return "DRY_RUN_DISABLED";
      case DRY_RUN_WAIT: return "DRY_RUN_WAIT";
      case DRY_RUN_APPROVED: return "DRY_RUN_APPROVED";
      case DRY_RUN_BLOCKED: return "DRY_RUN_BLOCKED";
      case DRY_RUN_BUY_READY: return "DRY_RUN_BUY_READY";
      case DRY_RUN_SELL_READY: return "DRY_RUN_SELL_READY";
      case DRY_RUN_RISK_BLOCK: return "DRY_RUN_RISK_BLOCK";
      case DRY_RUN_DUPLICATE_BLOCK: return "DRY_RUN_DUPLICATE_BLOCK";
      default: return "DRY_RUN_UNKNOWN";
   }
}

string ExecutionDryRunStatusToText()
{
   if(!UseExecutionDryRun) return "EXECUTION DRY RUN ENGINE DISABLED";
   if(ExecutionDryRunDiagnosticOnly) return "DIAGNOSTIC ONLY";
   switch(g_executionDryRun.state)
   {
      case DRY_RUN_APPROVED: return "DRY RUN APPROVED";
      case DRY_RUN_BUY_READY: return "DRY RUN BUY READY";
      case DRY_RUN_SELL_READY: return "DRY RUN SELL READY";
      case DRY_RUN_WAIT: return "DRY RUN WAITING";
      case DRY_RUN_BLOCKED: return "DRY RUN BLOCKED";
      case DRY_RUN_RISK_BLOCK: return "DRY RUN RISK BLOCK";
      case DRY_RUN_DUPLICATE_BLOCK: return "DRY RUN DUPLICATE BLOCK";
      default: return "DRY RUN WAITING";
   }
}

bool IsExecutionDryRunTradable(string &reason)
{
   if(!UseExecutionDryRun){ reason = "EXECUTION DRY RUN ENGINE DISABLED"; return true; }
   switch(g_executionDryRun.state)
   {
      case DRY_RUN_APPROVED: reason = "DRY RUN APPROVED"; return true;
      case DRY_RUN_BUY_READY: reason = "DRY RUN BUY READY"; return true;
      case DRY_RUN_SELL_READY: reason = "DRY RUN SELL READY"; return true;
      case DRY_RUN_WAIT: reason = "DRY RUN WAITING"; break;
      case DRY_RUN_BLOCKED: reason = "DRY RUN BLOCKED - " + g_dryRunBlockReason; break;
      case DRY_RUN_RISK_BLOCK: reason = "DRY RUN RISK BLOCK - " + g_dryRunBlockReason; break;
      case DRY_RUN_DUPLICATE_BLOCK: reason = "DRY RUN DUPLICATE BLOCK - " + g_dryRunBlockReason; break;
      default: reason = "DRY RUN UNKNOWN"; break;
   }
   if(ExecutionDryRunDiagnosticOnly && !IsFunctionalExecutionOverrideActive())
   {
      g_dryRunReason = reason + " - DIAGNOSTIC ONLY";
      return true;
   }
   if(ExecutionDryRunDiagnosticOnly && IsFunctionalExecutionOverrideActive() && ForceFunctionalIgnoreDryRunDiagnostic)
   {
      g_dryRunReason = "FUNCTIONAL OVERRIDE: DRY RUN NOT REQUIRED FOR TEST";
      return true;
   }
   return false;
}

bool CanPrintDryRunLog(string reason)
{
   if(!PrintExecutionDryRunDiagnostics) return false;
   datetime now = TimeCurrent();
   if(reason != g_lastDryRunLoggedReason || (now - g_lastDryRunLogTime) >= MinSecondsBetweenDryRunLogs)
   {
      g_lastDryRunLoggedReason = reason;
      g_lastDryRunLogTime = now;
      return true;
   }
   return false;
}

void AuditExecutionDryRun(string message)
{
   if(!CanPrintDryRunLog(message)) return;
   Print("[HORSE EA][EXECUTION_DRY_RUN] ", message);
}

void UpdateExecutionDryRun()
{
   if(!UseExecutionDryRun)
   {
      ResetExecutionDryRunDisabled();
      return;
   }
   g_executionDryRun.lastUpdateTime = TimeCurrent();
   BuildPlannedExecutionData();
   CalculateDryRunFinalScore();
   g_executionDryRun.state = DetectExecutionDryRunState();
   g_executionDryRun.direction = DetectDryRunDirection();
   g_dryRunApproved = (g_executionDryRun.state == DRY_RUN_APPROVED || g_executionDryRun.state == DRY_RUN_BUY_READY || g_executionDryRun.state == DRY_RUN_SELL_READY);
   g_dryRunBlocked = (g_executionDryRun.state == DRY_RUN_BLOCKED);
   g_dryRunWaiting = (g_executionDryRun.state == DRY_RUN_WAIT);
   g_dryRunBuyReady = (g_executionDryRun.state == DRY_RUN_BUY_READY);
   g_dryRunSellReady = (g_executionDryRun.state == DRY_RUN_SELL_READY);
   g_dryRunRiskBlock = (g_executionDryRun.state == DRY_RUN_RISK_BLOCK);
   g_dryRunDuplicateBlock = (g_executionDryRun.state == DRY_RUN_DUPLICATE_BLOCK);
   g_executionDryRun.approved = g_dryRunApproved;
   g_executionDryRun.blocked = g_dryRunBlocked;
   g_executionDryRun.waiting = g_dryRunWaiting;
   g_executionDryRun.buyReady = g_dryRunBuyReady;
   g_executionDryRun.sellReady = g_dryRunSellReady;
   g_executionDryRun.riskBlock = g_dryRunRiskBlock;
   g_executionDryRun.duplicateBlock = g_dryRunDuplicateBlock;
   g_dryRunDirectionText = DryRunDirectionToText(g_executionDryRun.direction);
   g_dryRunStatus = ExecutionDryRunStatusToText();
   g_dryRunReason = ExecutionDryRunStateToText(g_executionDryRun.state);
   if(g_dryRunBlockReason == "") g_dryRunBlockReason = "NONE";
   string tradableReason = "";
   IsExecutionDryRunTradable(tradableReason);
   if(ExecutionDryRunDiagnosticOnly && !IsFunctionalExecutionOverrideActive())
   {
      g_dryRunReason = tradableReason + " - DIAGNOSTIC ONLY";
      g_dryRunStatus = "DIAGNOSTIC ONLY";
   }
   else if(IsFunctionalExecutionOverrideActive() && (ExecutionDryRunDiagnosticOnly || ForceFunctionalIgnoreDryRunDiagnostic))
   {
      g_dryRunApproved = true;
      g_dryRunBlocked = false;
      g_dryRunWaiting = false;
      g_executionDryRun.approved = true;
      g_executionDryRun.blocked = false;
      g_executionDryRun.waiting = false;
      g_dryRunStatus = "FUNCTIONAL OVERRIDE";
      g_dryRunReason = "FUNCTIONAL OVERRIDE: DRY RUN NOT REQUIRED FOR TEST";
      g_executionDryRun.state = DRY_RUN_APPROVED;
      AuditExecutionDryRun("[FUNCTIONAL_OVERRIDE] DRY RUN DIAGNOSTIC BYPASSED");
   }
   else
      g_dryRunReason = tradableReason;
   g_executionDryRun.statusText = g_dryRunStatus;
   g_executionDryRun.reason = g_dryRunReason;
   g_executionDryRun.blockReason = g_dryRunBlockReason;
   g_executionDryRun.permissionReason = tradableReason;
   if(g_dryRunApproved)
   {
      datetime barTime = iTime(_Symbol, _Period, 0);
      if(barTime != g_lastDryRunApprovalBarTime)
      {
         g_lastDryRunApprovalTime = TimeCurrent();
         g_lastDryRunApprovalBarTime = barTime;
         g_executionDryRun.lastApprovedTime = g_lastDryRunApprovalTime;
      }
   }
   AuditExecutionDryRun("EXECUTION DRY RUN UPDATED");
   if(g_executionDryRun.state == DRY_RUN_BUY_READY) AuditExecutionDryRun("DRY RUN BUY READY");
   else if(g_executionDryRun.state == DRY_RUN_SELL_READY) AuditExecutionDryRun("DRY RUN SELL READY");
   else if(g_executionDryRun.state == DRY_RUN_APPROVED) AuditExecutionDryRun("DRY RUN APPROVED");
   else if(g_executionDryRun.state == DRY_RUN_WAIT) AuditExecutionDryRun("DRY RUN WAITING");
   else if(g_executionDryRun.state == DRY_RUN_BLOCKED) AuditExecutionDryRun("DRY RUN BLOCKED");
   else if(g_executionDryRun.state == DRY_RUN_RISK_BLOCK) AuditExecutionDryRun("DRY RUN RISK BLOCK");
   else if(g_executionDryRun.state == DRY_RUN_DUPLICATE_BLOCK) AuditExecutionDryRun("DRY RUN DUPLICATE BLOCK");
   if(ExecutionDryRunDiagnosticOnly && !IsFunctionalExecutionOverrideActive()) AuditExecutionDryRun("DIAGNOSTIC ONLY - NO TRADING");
   else if(IsFunctionalExecutionOverrideActive() && ForceFunctionalIgnoreDryRunDiagnostic) AuditExecutionDryRun("[FUNCTIONAL_OVERRIDE] DRY RUN DIAGNOSTIC BYPASSED");
}


//+------------------------------------------------------------------+
//| ETAPA 10 - Real Execution Engine                                 |
//+------------------------------------------------------------------+
void InitializeRealExecutionData()
{
   g_realExecution.state = REAL_EXEC_WAIT;
   g_realExecution.direction = REAL_EXEC_DIR_NONE;
   g_realExecution.ready = false;
   g_realExecution.blocked = false;
   g_realExecution.simulationOnly = false;
   g_realExecution.riskBlock = false;
   g_realExecution.duplicateBlock = false;
   g_realExecution.brokerBlock = false;
   g_realExecution.orderSent = false;
   g_realExecution.buySent = false;
   g_realExecution.sellSent = false;
   g_realExecution.error = false;
   g_realExecution.lastUpdateTime = 0;
   g_realExecution.lastExecutionTime = 0;
   g_realExecution.lastExecutionBarTime = 0;
   g_realExecution.lastAttemptTime = 0;
   g_realExecution.attemptCount = 0;
   g_realExecution.lastOrderTicket = 0;
   g_realExecution.lastDealTicket = 0;
   g_realExecution.lastPositionTicket = 0;
   g_realExecution.executionLot = 0.0;
   g_realExecution.executionEntryPrice = 0.0;
   g_realExecution.executionSL = 0.0;
   g_realExecution.executionTP = 0.0;
   g_realExecution.executionRiskMoney = 0.0;
   g_realExecution.executionRewardMoney = 0.0;
   g_realExecution.executionRiskPercent = 0.0;
   g_realExecution.executionRR = 0.0;
   g_realExecution.executionSpreadPoints = 0.0;
   g_realExecution.executionMarginRequired = 0.0;
   g_realExecution.executionOrderType = "NONE";
   g_realExecution.statusText = "WAITING";
   g_realExecution.reason = "INITIALIZED";
   g_realExecution.blockReason = "NONE";
   g_realExecution.brokerReason = "NONE";
   g_realExecution.lastErrorText = "";

   g_realExecutionReady = false;
   g_realExecutionBlocked = false;
   g_realExecutionSimulationOnly = false;
   g_realExecutionRiskBlock = false;
   g_realExecutionDuplicateBlock = false;
   g_realExecutionBrokerBlock = false;
   g_realOrderSent = false;
   g_realBuySent = false;
   g_realSellSent = false;
   g_realExecutionError = false;
   g_realExecutionLot = 0.0;
   g_realExecutionEntryPrice = 0.0;
   g_realExecutionSL = 0.0;
   g_realExecutionTP = 0.0;
   g_realExecutionRiskMoney = 0.0;
   g_realExecutionRewardMoney = 0.0;
   g_realExecutionRiskPercent = 0.0;
   g_realExecutionRR = 0.0;
   g_realExecutionMarginRequired = 0.0;
   g_lastRealExecutionTime = 0;
   g_lastRealExecutionBarTime = 0;
   g_lastRealExecutionAttemptTime = 0;
   g_lastRealExecutionLogTime = 0;
   g_realExecutionAttemptCount = 0;
   g_lastRealOrderTicket = 0;
   g_lastRealDealTicket = 0;
   g_lastRealPositionTicket = 0;
   g_realExecutionStatus = "WAITING";
   g_realExecutionReason = "INITIALIZED";
   g_realExecutionBlockReason = "NONE";
   g_realExecutionDirectionText = "NONE";
   g_lastRealExecutionLoggedReason = "";
   g_lastRealExecutionErrorText = "";
   g_realExecutionBrokerReason = "NONE";
}

void ResetRealExecutionDisabled()
{
   g_realExecution.state = REAL_EXEC_DISABLED;
   g_realExecution.direction = REAL_EXEC_DIR_NONE;
   g_realExecution.ready = false;
   g_realExecution.blocked = false;
   g_realExecution.simulationOnly = false;
   g_realExecution.riskBlock = false;
   g_realExecution.duplicateBlock = false;
   g_realExecution.brokerBlock = false;
   g_realExecution.orderSent = false;
   g_realExecution.buySent = false;
   g_realExecution.sellSent = false;
   g_realExecution.error = false;
   g_realExecution.executionLot = 0.0;
   g_realExecution.executionEntryPrice = 0.0;
   g_realExecution.executionSL = 0.0;
   g_realExecution.executionTP = 0.0;
   g_realExecution.executionRiskMoney = 0.0;
   g_realExecution.executionRewardMoney = 0.0;
   g_realExecution.executionRiskPercent = 0.0;
   g_realExecution.executionRR = 0.0;
   g_realExecution.executionMarginRequired = 0.0;
   g_realExecution.executionOrderType = "NONE";
   g_realExecution.statusText = "REAL EXECUTION ENGINE DISABLED";
   g_realExecution.reason = "DISABLED";
   g_realExecution.blockReason = "NONE";
   g_realExecution.brokerReason = "NONE";

   g_realExecutionReady = false;
   g_realExecutionBlocked = false;
   g_realExecutionSimulationOnly = false;
   g_realExecutionRiskBlock = false;
   g_realExecutionDuplicateBlock = false;
   g_realExecutionBrokerBlock = false;
   g_realOrderSent = false;
   g_realBuySent = false;
   g_realSellSent = false;
   g_realExecutionError = false;
   g_realExecutionLot = 0.0;
   g_realExecutionEntryPrice = 0.0;
   g_realExecutionSL = 0.0;
   g_realExecutionTP = 0.0;
   g_realExecutionRiskMoney = 0.0;
   g_realExecutionRewardMoney = 0.0;
   g_realExecutionRiskPercent = 0.0;
   g_realExecutionRR = 0.0;
   g_realExecutionMarginRequired = 0.0;
   g_realExecutionStatus = "REAL EXECUTION ENGINE DISABLED";
   g_realExecutionReason = "DISABLED";
   g_realExecutionBlockReason = "NONE";
   g_realExecutionDirectionText = "NONE";
   g_realExecutionBrokerReason = "NONE";
}


//+------------------------------------------------------------------+
//| STAGE 12 FIX2 - Functional Execution Override Helpers             |
//+------------------------------------------------------------------+
bool IsFunctionalExecutionOverrideActive()
{
   if(!ForceFunctionalExecutionTest)
      return false;
   if(!ForceFunctionalAllowRealExecution)
      return false;
   if(!AllowLiveTrading)
      return false;
   if(!EnableRealExecution)
      return false;
   // FIX3 V3: RealExecutionSimulationOnly is handled as an effective flag in execution functions.
   // The input itself is not modified at runtime.
   return true;
}

bool IsFunctionalLayerOverrideActive()
{
   if(!ForceFunctionalExecutionTest)
      return false;
   if(!ForceFunctionalAllowLayerExecution)
      return false;
   if(!UseReentryLayerEngine)
      return false;
   if(!EnableLayerExecution)
      return false;
   if(LayerSimulationOnly)
      return false;
   if(!AllowLayerOrders)
      return false;
   return true;
}

double FunctionalGetSpreadPoints()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || _Point <= 0.0)
      return 999999.0;
   return (ask - bid) / _Point;
}

double FunctionalNormalizeLot(double lot)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(minLot <= 0.0)
      minLot = 0.01;
   if(maxLot < minLot)
      maxLot = minLot;
   if(stepLot <= 0.0)
      stepLot = minLot;
   if(stepLot <= 0.0)
      stepLot = 0.01;

   lot = MathMax(lot, minLot);
   lot = MathMin(lot, maxLot);
   lot = MathFloor(lot / stepLot) * stepLot;
   if(lot < minLot)
      lot = minLot;

   return NormalizeDouble(lot, 2);
}

int CountAllMagicPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      long posMagic = (long)PositionGetInteger(POSITION_MAGIC);
      if(posMagic != MagicNumber)
         continue;
      count++;
   }
   return count;
}

double FunctionalTotalSymbolLots()
{
   double lots = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      long posMagic = (long)PositionGetInteger(POSITION_MAGIC);
      if(posMagic != MagicNumber)
         continue;
      lots += PositionGetDouble(POSITION_VOLUME);
   }
   return NormalizeDouble(lots, 2);
}

long GetMainPositionTypeByTicket(ulong ticket)
{
   if(ticket == 0)
      return -1;
   if(!PositionSelectByTicket(ticket))
      return -1;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol)
      return -1;
   long posMagic = (long)PositionGetInteger(POSITION_MAGIC);
   if(posMagic != MagicNumber)
      return -1;
   return (long)PositionGetInteger(POSITION_TYPE);
}

bool FunctionalValidateMargin(ENUM_ORDER_TYPE orderType, double lot, string &reason)
{
   reason = "FUNCTIONAL MARGIN APPROVED";
   if(!ForceFunctionalKeepMarginProtection)
      return true;

   double price = (orderType == ORDER_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID));
   if(price <= 0.0)
   {
      reason = "FUNCTIONAL SAFETY BLOCK: INVALID MARGIN PRICE";
      return false;
   }

   double margin = 0.0;
   if(!OrderCalcMargin(orderType, _Symbol, lot, price, margin))
   {
      reason = "FUNCTIONAL SAFETY BLOCK: MARGIN CALC FAILED";
      return false;
   }

   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(margin <= 0.0 || freeMargin <= margin)
   {
      reason = "FUNCTIONAL SAFETY BLOCK: MARGIN NOT SAFE";
      return false;
   }
   return true;
}

bool IsFunctionalSafetyApproved(double projectedLot, string &reason)
{
   reason = "";

   if(projectedLot <= 0.0)
   {
      reason = "FUNCTIONAL SAFETY BLOCK: INVALID PROJECTED LOT";
      g_functionalSafetyApproved = false;
      g_functionalSafetyReason = reason;
      return false;
   }

   double normalizedLot = FunctionalNormalizeLot(projectedLot);
   if(normalizedLot <= 0.0)
   {
      reason = "FUNCTIONAL SAFETY BLOCK: INVALID NORMALIZED LOT";
      g_functionalSafetyApproved = false;
      g_functionalSafetyReason = reason;
      return false;
   }

   if(normalizedLot - ForceFunctionalFixedLot > 0.000001)
   {
      reason = "FUNCTIONAL SAFETY BLOCK: LOT ABOVE FUNCTIONAL FIXED LOT";
      g_functionalSafetyApproved = false;
      g_functionalSafetyReason = reason;
      return false;
   }

   if(ForceFunctionalKeepSpreadProtection)
   {
      double spread = FunctionalGetSpreadPoints();
      if(spread > MaxRealExecutionSpreadPoints && MaxRealExecutionSpreadPoints > 0)
      {
         reason = "FUNCTIONAL SAFETY BLOCK: SPREAD TOO HIGH";
         g_functionalSafetyApproved = false;
         g_functionalSafetyReason = reason;
         return false;
      }
   }

   if(ForceFunctionalKeepExposureProtection)
   {
      int totalPositions = CountAllMagicPositions();
      if(totalPositions >= ForceFunctionalMaxTotalPositions)
      {
         reason = "FUNCTIONAL SAFETY BLOCK: MAX TOTAL POSITIONS";
         g_functionalSafetyApproved = false;
         g_functionalSafetyReason = reason;
         return false;
      }

      double currentLots = FunctionalTotalSymbolLots();
      if(currentLots + normalizedLot - ForceFunctionalMaxSymbolExposureLots > 0.000001)
      {
         reason = "FUNCTIONAL SAFETY BLOCK: PROJECTED SYMBOL EXPOSURE TOO HIGH";
         g_functionalSafetyApproved = false;
         g_functionalSafetyReason = reason;
         return false;
      }
   }

   if(ForceFunctionalKeepDailyRiskProtection)
   {
      // V8 FIX: DD calculado desde o inÃ­cio do dia (dailyStartEquity),
      // nÃ£o desde o balance atual â€” que ignora lucros anteriores do mesmo dia.
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double startEq = g_risk.dailyStartEquity > 0.0
                     ? g_risk.dailyStartEquity
                     : AccountInfoDouble(ACCOUNT_BALANCE);
      if(startEq > 0.0 && equity < startEq)
      {
         double dd = ((startEq - equity) / startEq) * 100.0;
         if(dd >= DailyLossLimitPercent)
         {
            reason = StringFormat("FUNCTIONAL SAFETY BLOCK: DAILY DD %.2f%% >= LIMIT %.2f%%",
                                  dd, DailyLossLimitPercent);
            g_functionalSafetyApproved = false;
            g_functionalSafetyReason = reason;
            return false;
         }
      }
   }

   reason = "FUNCTIONAL SAFETY APPROVED";
   g_functionalSafetyApproved = true;
   g_functionalSafetyReason = reason;
   return true;
}

bool HasValidRealExecutionDirection()
{
   ENUM_REAL_EXECUTION_DIRECTION dir = DetectRealExecutionDirection();
   return (dir == REAL_EXEC_DIR_BUY || dir == REAL_EXEC_DIR_SELL);
}

bool BuildOrValidateFunctionalSLTP(ENUM_REAL_EXECUTION_DIRECTION direction, double entryPrice, double &sl, double &tp)
{
   if(_Point <= 0.0 || entryPrice <= 0.0)
      return false;

   double slPoints = FixedVirtualSLPoints;
   double tpPoints = FixedVirtualTPPoints;
   if(slPoints < MinVirtualSLPoints)
      slPoints = MinVirtualSLPoints;
   if(tpPoints < MinVirtualTPPoints)
      tpPoints = MinVirtualTPPoints;
   if(slPoints <= 0.0 || tpPoints <= 0.0)
      return false;

   if(direction == REAL_EXEC_DIR_BUY)
   {
      if(sl <= 0.0 || !(sl < entryPrice))
         sl = entryPrice - slPoints * _Point;
      if(tp <= 0.0 || !(tp > entryPrice))
         tp = entryPrice + tpPoints * _Point;
      return (sl > 0.0 && tp > 0.0 && sl < entryPrice && entryPrice < tp);
   }

   if(direction == REAL_EXEC_DIR_SELL)
   {
      if(sl <= 0.0 || !(sl > entryPrice))
         sl = entryPrice + slPoints * _Point;
      if(tp <= 0.0 || !(tp < entryPrice))
         tp = entryPrice - tpPoints * _Point;
      return (sl > 0.0 && tp > 0.0 && tp < entryPrice && entryPrice < sl);
   }

   return false;
}

double FunctionalEstimateMoneyByPoints(double lot, double points)
{
   if(lot <= 0.0 || points <= 0.0 || _Point <= 0.0)
      return 0.0;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0.0 || tickSize <= 0.0)
      return MathAbs(points) * lot;
   return MathAbs(points * _Point / tickSize * tickValue * lot);
}


int Fix3CurrentDayKey()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.year * 1000 + dt.day_of_year;
}

void Fix3ResetTradesTodayIfNeeded()
{
   int key = Fix3CurrentDayKey();
   if(g_fix3TradeDayKey != key)
   {
      g_fix3TradeDayKey = key;
      g_fix3TradesToday = 0;
   }
}

bool HasAnyMagicPosition()
{
   return (CountAllMagicPositions() > 0);
}

bool CanStartNewAggressiveCycle(string &reason)
{
   Fix3ResetTradesTodayIfNeeded();
   reason = "";
   g_fix3AggressiveCycleActive = false;

   if(!ForceFunctionalAggressiveEntryCycle)
   {
      reason = "Aggressive cycle disabled";
      g_fix3AggressiveCycleReason = reason;
      return false;
   }
   if(!ForceFunctionalAllowManySequentialTrades)
   {
      reason = "Many sequential trades disabled";
      g_fix3AggressiveCycleReason = reason;
      return false;
   }
   if(CountAllMagicPositions() > 0)
   {
      reason = "MAIN POSITION ALREADY ACTIVE - LAYER ENGINE WILL HANDLE";
      g_fix3AggressiveCycleReason = reason;
      return false;
   }
   if(g_fix3TradesToday >= ForceFunctionalMaxTradesPerDay)
   {
      reason = "Max trades per day reached";
      g_fix3AggressiveCycleReason = reason;
      return false;
   }
   if(ForceFunctionalMinSecondsBetweenCycles > 0 && g_fix3LastCycleTime > 0 && (TimeCurrent() - g_fix3LastCycleTime) < ForceFunctionalMinSecondsBetweenCycles)
   {
      reason = "Min seconds between cycles not reached";
      g_fix3AggressiveCycleReason = reason;
      return false;
   }
   if(ForceFunctionalRearmAfterPositionClose && g_fix3LastPositionCloseTime > 0 && (TimeCurrent() - g_fix3LastPositionCloseTime) < ForceFunctionalRearmSecondsAfterClose)
   {
      reason = "Rearm delay after close not reached";
      g_fix3AggressiveCycleReason = reason;
      return false;
   }

   reason = "Aggressive cycle allowed";
   g_fix3AggressiveCycleReason = reason;
   g_fix3AggressiveCycleActive = true;
   return true;
}

void UpdateAggressiveCycleRearm()
{
   static int lastPositionCount = 0;
   int currentCount = CountAllMagicPositions();
   if(lastPositionCount > 0 && currentCount == 0)
   {
      g_fix3LastPositionCloseTime = TimeCurrent();
      AuditLog("AGGRESSIVE_CYCLE", "POSITIONS CLOSED - REARMING NEW CYCLE");
   }
   lastPositionCount = currentCount;
}

double GetLastBuyDecisionScore()
{
   if(g_entryDecision == ENTRY_DECISION_BUY)
      return g_entryBaseScore + g_flowQualityScore;
   if(g_entryBaseDirection == "BUY" || g_entryDecisionDirection == "BUY")
      return g_entryBaseScore + g_flowQualityScore;
   return 0.0;
}

double GetLastSellDecisionScore()
{
   if(g_entryDecision == ENTRY_DECISION_SELL)
      return g_entryBaseScore + g_flowQualityScore;
   if(g_entryBaseDirection == "SELL" || g_entryDecisionDirection == "SELL")
      return g_entryBaseScore + g_flowQualityScore;
   return 0.0;
}



// ==================================================
// HORSE EA V5.1 - ADAPTIVE MARKET DIRECTION ONLY
// Scope: BUY / SELL / NEUTRAL final direction resolver.
// This module does NOT change lots, layers, hedge, runner, exits,
// RiskGovernor, FTMO protections or structural OrderSend.
// ==================================================

enum ENUM_HORSE_FINAL_DIRECTION
{
   HORSE_DIR_NEUTRAL = 0,
   HORSE_DIR_BUY     = 1,
   HORSE_DIR_SELL    = 2
};

enum ENUM_HORSE_MARKET_REGIME
{
   HORSE_TREND_STRONG_BULL = 0,
   HORSE_TREND_MODERATE_BULL = 1,
   HORSE_TREND_WEAK_BULL = 2,
   HORSE_TREND_STRONG_BEAR = 3,
   HORSE_TREND_MODERATE_BEAR = 4,
   HORSE_TREND_WEAK_BEAR = 5,
   HORSE_RANGE = 6,
   HORSE_CHOPPY = 7,
   HORSE_COMPRESSION = 8,
   HORSE_EXPANSION = 9,
   HORSE_REVERSAL_RISK = 10,
   HORSE_NEUTRAL = 11
};

string HorseMarketRegimeToText(ENUM_HORSE_MARKET_REGIME regime)
{
   switch(regime)
   {
      case HORSE_TREND_STRONG_BULL:    return "HORSE_TREND_STRONG_BULL";
      case HORSE_TREND_MODERATE_BULL:  return "HORSE_TREND_MODERATE_BULL";
      case HORSE_TREND_WEAK_BULL:      return "HORSE_TREND_WEAK_BULL";
      case HORSE_TREND_STRONG_BEAR:    return "HORSE_TREND_STRONG_BEAR";
      case HORSE_TREND_MODERATE_BEAR:  return "HORSE_TREND_MODERATE_BEAR";
      case HORSE_TREND_WEAK_BEAR:      return "HORSE_TREND_WEAK_BEAR";
      case HORSE_RANGE:                return "HORSE_RANGE";
      case HORSE_CHOPPY:               return "HORSE_CHOPPY";
      case HORSE_COMPRESSION:          return "HORSE_COMPRESSION";
      case HORSE_EXPANSION:            return "HORSE_EXPANSION";
      case HORSE_REVERSAL_RISK:        return "HORSE_REVERSAL_RISK";
      default:                         return "HORSE_NEUTRAL";
   }
}

string HorseFinalDirectionToText(ENUM_HORSE_FINAL_DIRECTION dir)
{
   if(dir == HORSE_DIR_BUY)
      return "BUY";
   if(dir == HORSE_DIR_SELL)
      return "SELL";
   return "NEUTRAL";
}

double HorseCalculateBuyScore()
{
   return CalculateAggressiveEntryScoreV4(ORDER_TYPE_BUY);
}

double HorseCalculateSellScore()
{
   return CalculateAggressiveEntryScoreV4(ORDER_TYPE_SELL);
}

ENUM_HORSE_MARKET_REGIME HorseDetectMarketRegime(string &reason)
{
   reason = "";

   double close1 = iClose(_Symbol, _Period, 1);
   double close2 = iClose(_Symbol, _Period, 2);
   double ma20   = V32GetMA((ENUM_TIMEFRAMES)_Period, 20, 1);
   double ma50   = V32GetMA((ENUM_TIMEFRAMES)_Period, 50, 1);
   double ma200  = V32GetMA((ENUM_TIMEFRAMES)_Period, 200, 1);
   double adx    = V32GetADX((ENUM_TIMEFRAMES)_Period, 14, 1);
   double atr1   = V32GetATRPoints((ENUM_TIMEFRAMES)_Period, 14, 1);
   double atr5   = V32GetATRPoints((ENUM_TIMEFRAMES)_Period, 14, 5);

   bool dataOk = (close1 > 0.0 && ma20 > 0.0 && ma50 > 0.0 && ma200 > 0.0 && adx > 0.0 && atr1 > 0.0);
   if(!dataOk)
   {
      reason = "DATA_NOT_READY";
      AuditV4("[HORSE_MARKET_REGIME] regime=HORSE_NEUTRAL adx=" + DoubleToString(adx,1) + " atr=" + DoubleToString(atr1,1) + " emaBias=DATA_NOT_READY structure=UNKNOWN volatility=UNKNOWN reason=" + reason);
      return HORSE_NEUTRAL;
   }

   bool emaBull = (ma20 > ma50 && ma50 > ma200 && close1 > ma20);
   bool emaBear = (ma20 < ma50 && ma50 < ma200 && close1 < ma20);
   bool weakBull = (ma20 > ma50 && close1 > ma50);
   bool weakBear = (ma20 < ma50 && close1 < ma50);
   bool atrExpanding = (atr5 > 0.0 && atr1 > atr5 * 1.10);
   bool atrCompressing = (atr5 > 0.0 && atr1 < atr5 * 0.85);

   string emaBias = "MIXED";
   if(emaBull) emaBias = "BULL";
   else if(emaBear) emaBias = "BEAR";
   else if(weakBull) emaBias = "WEAK_BULL";
   else if(weakBear) emaBias = "WEAK_BEAR";

   string volatility = "NORMAL";
   if(atrExpanding) volatility = "EXPANDING";
   else if(atrCompressing) volatility = "COMPRESSING";

   ENUM_HORSE_MARKET_REGIME regime = HORSE_NEUTRAL;
   if(emaBull && adx >= 24.0)
      regime = HORSE_TREND_STRONG_BULL;
   else if(emaBear && adx >= 24.0)
      regime = HORSE_TREND_STRONG_BEAR;
   else if(emaBull && adx >= 18.0)
      regime = HORSE_TREND_MODERATE_BULL;
   else if(emaBear && adx >= 18.0)
      regime = HORSE_TREND_MODERATE_BEAR;
   else if(weakBull && adx >= 14.0)
      regime = HORSE_TREND_WEAK_BULL;
   else if(weakBear && adx >= 14.0)
      regime = HORSE_TREND_WEAK_BEAR;
   else if(atrCompressing)
      regime = HORSE_COMPRESSION;
   else if(atrExpanding)
      regime = HORSE_EXPANSION;
   else if(adx < 12.0)
      regime = HORSE_CHOPPY;
   else if(adx < 16.0)
      regime = HORSE_RANGE;
   else if((close1 > ma20 && close2 < ma20) || (close1 < ma20 && close2 > ma20))
      regime = HORSE_REVERSAL_RISK;
   else
      regime = HORSE_NEUTRAL;

   reason = "EMA=" + emaBias + ";ADX=" + DoubleToString(adx,1) + ";ATR=" + DoubleToString(atr1,1) + ";VOL=" + volatility;
   AuditV4("[HORSE_MARKET_REGIME] regime=" + HorseMarketRegimeToText(regime) + " adx=" + DoubleToString(adx,1) + " atr=" + DoubleToString(atr1,1) + " emaBias=" + emaBias + " structure=" + emaBias + " volatility=" + volatility + " reason=" + reason);

   return regime;
}

ENUM_HORSE_FINAL_DIRECTION HorseResolveFinalDirection(ENUM_ORDER_TYPE &orderType,
                                                       string &reason,
                                                       double &buyScore,
                                                       double &sellScore,
                                                       ENUM_HORSE_MARKET_REGIME &regime)
{
   string regimeReason = "";
   regime = HorseDetectMarketRegime(regimeReason);

   buyScore = HorseCalculateBuyScore();
   sellScore = HorseCalculateSellScore();

   double gap = MathAbs(buyScore - sellScore);
   double minGap = AdaptiveDirectionNeutralThresholdV4;
   double minScore = AdaptiveDirectionMinValidScoreV4;

   bool buyDominates = (buyScore > sellScore + minGap && buyScore >= minScore);
   bool sellDominates = (sellScore > buyScore + minGap && sellScore >= minScore);

   bool bullHardBlockForSell = (regime == HORSE_TREND_STRONG_BULL || regime == HORSE_TREND_MODERATE_BULL);
   bool bearHardBlockForBuy = (regime == HORSE_TREND_STRONG_BEAR || regime == HORSE_TREND_MODERATE_BEAR);
   bool neutralRegime = (regime == HORSE_RANGE || regime == HORSE_CHOPPY || regime == HORSE_COMPRESSION || regime == HORSE_NEUTRAL);

   ENUM_HORSE_FINAL_DIRECTION finalDir = HORSE_DIR_NEUTRAL;

   if(neutralRegime)
   {
      reason = "NEUTRAL_REGIME_NO_CLEAR_DIRECTION";
      finalDir = HORSE_DIR_NEUTRAL;
   }
   else if(buyDominates && !bearHardBlockForBuy)
   {
      orderType = ORDER_TYPE_BUY;
      reason = "BUY_SCORE_DOMINANT_ADAPTIVE";
      finalDir = HORSE_DIR_BUY;
   }
   else if(sellDominates && !bullHardBlockForSell)
   {
      orderType = ORDER_TYPE_SELL;
      reason = "SELL_SCORE_DOMINANT_ADAPTIVE";
      finalDir = HORSE_DIR_SELL;
   }
   else
   {
      reason = "NO_CLEAR_DIRECTION_OR_CONFLICT";
      if(buyDominates && bearHardBlockForBuy)
         reason = "BUY_SCORE_DOMINANT_BUT_BEARISH_REGIME";
      if(sellDominates && bullHardBlockForSell)
         reason = "SELL_SCORE_DOMINANT_BUT_BULLISH_REGIME";
      finalDir = HORSE_DIR_NEUTRAL;
   }

   string finalText = HorseFinalDirectionToText(finalDir);
   AuditV4("[HORSE_DIRECTION_SCORE] buyScore=" + DoubleToString(buyScore,1) + " sellScore=" + DoubleToString(sellScore,1) + " gap=" + DoubleToString(gap,1) + " momentumBias=" + finalText + " structureBias=" + HorseMarketRegimeToText(regime) + " finalDirection=" + finalText);
   AuditV4("[HORSE_DIRECTION_DECISION] finalDirection=" + finalText + " allowed=" + BoolToText(finalDir != HORSE_DIR_NEUTRAL) + " reason=" + reason + " orderType=" + (finalDir == HORSE_DIR_BUY ? "BUY" : (finalDir == HORSE_DIR_SELL ? "SELL" : "NONE")));

   return finalDir;
}

bool ResolveFunctionalDirectionFromDryRun(ENUM_ORDER_TYPE &orderType, string &reason)
{
   // HORSE V5.1: final execution direction must come from the adaptive market direction engine.
   // No BUY fallback, no SELL fallback, no candle fallback.
   double buyScore = 0.0;
   double sellScore = 0.0;
   ENUM_HORSE_MARKET_REGIME regime = HORSE_NEUTRAL;
   string adaptiveReason = "";

   ENUM_HORSE_FINAL_DIRECTION finalDir = HorseResolveFinalDirection(orderType, adaptiveReason, buyScore, sellScore, regime);

   string dryRunDirectionText = "NONE";
   if(g_executionDryRun.direction == DRY_RUN_DIR_BUY)
      dryRunDirectionText = "BUY";
   else if(g_executionDryRun.direction == DRY_RUN_DIR_SELL)
      dryRunDirectionText = "SELL";

   string finalOrderType = "NONE";
   if(finalDir == HORSE_DIR_BUY)
      finalOrderType = "BUY";
   else if(finalDir == HORSE_DIR_SELL)
      finalOrderType = "SELL";

   bool wasOverwritten = false;
   if(finalOrderType != "NONE" && dryRunDirectionText != "NONE" && finalOrderType != dryRunDirectionText)
      wasOverwritten = true;
   if(finalOrderType != "NONE" && g_entryDecisionDirection != "" && finalOrderType != g_entryDecisionDirection)
      wasOverwritten = true;

   AuditV4("[HORSE_DIRECTION_PIPELINE] buyScore=" + DoubleToString(buyScore,1) +
           " sellScore=" + DoubleToString(sellScore,1) +
           " selectedAdaptiveDirection=" + HorseFinalDirectionToText(finalDir) +
           " dryRunDirection=" + dryRunDirectionText +
           " entryDecisionDirection=" + g_entryDecisionDirection +
           " entryBaseDirection=" + g_entryBaseDirection +
           " finalOrderType=" + finalOrderType +
           " reason=" + adaptiveReason);

   AuditV4("[HORSE_DIRECTION_OVERRIDE_CHECK] adaptiveDirection=" + HorseFinalDirectionToText(finalDir) +
           " oldDirection=" + dryRunDirectionText +
           " finalDirection=" + finalOrderType +
           " wasOverwritten=" + BoolToText(wasOverwritten) +
           " reason=ADAPTIVE_DIRECTION_IS_FINAL_SOURCE");

   if(finalDir == HORSE_DIR_BUY || finalDir == HORSE_DIR_SELL)
   {
      reason = "HORSE_ADAPTIVE_DIRECTION: " + adaptiveReason;
      AuditV4("[HORSE_ORDER_DIRECTION_FINAL] orderType=" + finalOrderType + " directionSource=HORSE_ADAPTIVE_MARKET_DIRECTION allowed=true reason=" + reason);
      return true;
   }

   reason = "HORSE_ADAPTIVE_NEUTRAL_NO_TRADE: " + adaptiveReason;
   AuditV4("[HORSE_ORDER_DIRECTION_FINAL] orderType=NONE directionSource=HORSE_ADAPTIVE_MARKET_DIRECTION allowed=false reason=" + reason);
   return false;
}

bool BuildFunctionalOrderPlanFromDryRun(ENUM_ORDER_TYPE &orderType,
                                        double &lot,
                                        double &entryPrice,
                                        double &sl,
                                        double &tp,
                                        string &reason)
{
   reason = "";
   lot = FunctionalNormalizeLot(ForceFunctionalFixedLot);
   if(lot <= 0.0 || lot - ForceFunctionalFixedLot > 0.000001)
   {
      reason = "Invalid functional lot";
      return false;
   }

   string dirReason = "";
   if(!ResolveFunctionalDirectionFromDryRun(orderType, dirReason))
   {
      reason = "Direction resolve failed: " + dirReason;
      return false;
   }

   entryPrice = (orderType == ORDER_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID));
   if(entryPrice <= 0.0)
   {
      reason = "Invalid entry price";
      return false;
   }

   ENUM_REAL_EXECUTION_DIRECTION realDir = (orderType == ORDER_TYPE_BUY ? REAL_EXEC_DIR_BUY : REAL_EXEC_DIR_SELL);
   sl = 0.0;
   tp = 0.0;
   if(!BuildOrValidateFunctionalSLTP(realDir, entryPrice, sl, tp))
   {
      reason = "Invalid SLTP / StopLevel / FreezeLevel";
      return false;
   }

   reason = "Functional order plan built: " + dirReason;
   return true;
}

ENUM_REAL_EXECUTION_DIRECTION DetectRealExecutionDirection()
{
   // HORSE V5.1B: every real execution direction must pass through the adaptive direction gate.
   // This intentionally prevents legacy DryRun / plannedOrderType / ready flags / decision/base fallbacks
   // from becoming the final real direction. Legacy values are logged only for forensic comparison.
   ENUM_ORDER_TYPE adaptiveOrderType = ORDER_TYPE_BUY;
   string adaptiveReason = "";
   double buyScore = 0.0;
   double sellScore = 0.0;
   ENUM_HORSE_MARKET_REGIME regime = HORSE_NEUTRAL;

   ENUM_HORSE_FINAL_DIRECTION adaptiveDirection = HorseResolveFinalDirection(adaptiveOrderType,
                                                                              adaptiveReason,
                                                                              buyScore,
                                                                              sellScore,
                                                                              regime);

   string oldDryRunDirection = "NONE";
   if(g_executionDryRun.direction == DRY_RUN_DIR_BUY)
      oldDryRunDirection = "BUY";
   else if(g_executionDryRun.direction == DRY_RUN_DIR_SELL)
      oldDryRunDirection = "SELL";

   string oldPlannedOrderType = g_executionDryRun.plannedOrderType;
   if(oldPlannedOrderType == "")
      oldPlannedOrderType = "NONE";

   ENUM_REAL_EXECUTION_DIRECTION finalRealDirection = REAL_EXEC_DIR_NONE;
   string finalRealText = "NONE";

   if(adaptiveDirection == HORSE_DIR_BUY)
   {
      finalRealDirection = REAL_EXEC_DIR_BUY;
      finalRealText = "BUY";
   }
   else if(adaptiveDirection == HORSE_DIR_SELL)
   {
      finalRealDirection = REAL_EXEC_DIR_SELL;
      finalRealText = "SELL";
   }
   else
   {
      finalRealDirection = REAL_EXEC_DIR_NONE;
      finalRealText = "NONE";
      g_fix3LastBlockReason = "HORSE_ADAPTIVE_NEUTRAL_NO_TRADE: " + adaptiveReason;
   }

   bool bypassPrevented = false;
   if(adaptiveDirection == HORSE_DIR_NEUTRAL)
   {
      if(oldDryRunDirection != "NONE" || oldPlannedOrderType != "NONE" || g_executionDryRun.buyReady || g_executionDryRun.sellReady || g_entryDecisionDirection != "" || g_entryBaseDirection != "")
         bypassPrevented = true;
   }
   else
   {
      if(oldDryRunDirection != "NONE" && oldDryRunDirection != finalRealText)
         bypassPrevented = true;
      if(oldPlannedOrderType != "NONE" && oldPlannedOrderType != finalRealText)
         bypassPrevented = true;
      if(g_entryDecisionDirection != "" && g_entryDecisionDirection != finalRealText)
         bypassPrevented = true;
      if(g_entryBaseDirection != "" && g_entryBaseDirection != finalRealText)
         bypassPrevented = true;
   }

   AuditV4("[HORSE_REAL_DIRECTION_GATE] adaptiveDirection=" + HorseFinalDirectionToText(adaptiveDirection) +
           " oldDryRunDirection=" + oldDryRunDirection +
           " oldPlannedOrderType=" + oldPlannedOrderType +
           " buyReady=" + BoolToText(g_executionDryRun.buyReady) +
           " sellReady=" + BoolToText(g_executionDryRun.sellReady) +
           " finalRealDirection=" + finalRealText +
           " source=HORSE_ADAPTIVE_ONLY" +
           " reason=" + adaptiveReason);

   AuditV4("[HORSE_DIRECTION_BYPASS_AUDIT] function=DetectRealExecutionDirection" +
           " oldDirection=" + oldDryRunDirection +
           " adaptiveDirection=" + HorseFinalDirectionToText(adaptiveDirection) +
           " bypassPrevented=" + BoolToText(bypassPrevented));

   AuditV4("[HORSE_ORDER_DIRECTION_FINAL] orderType=" + finalRealText +
           " finalRealDirection=" + finalRealText +
           " source=HORSE_ADAPTIVE_ONLY" +
           " allowed=" + BoolToText(finalRealDirection != REAL_EXEC_DIR_NONE) +
           " reason=" + (finalRealDirection == REAL_EXEC_DIR_NONE ? g_fix3LastBlockReason : adaptiveReason));

   return finalRealDirection;
}

double NormalizeRealExecutionLot(double lot)
{
   double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(minVol <= 0.0)
      minVol = 0.01;
   if(maxVol < minVol)
      maxVol = minVol;
   if(step <= 0.0)
      step = minVol;
   if(step <= 0.0)
      step = 0.01;

   lot = MathMax(MinRealExecutionLot, lot);
   lot = MathMin(MaxRealExecutionLot, lot);
   lot = MathMax(minVol, MathMin(maxVol, lot));
   lot = MathFloor(lot / step) * step;
   if(lot < minVol)
      lot = minVol;

   return NormalizeDouble(lot, 2);
}

void ClearDirectionState()
{
   g_realExecution.direction = REAL_EXEC_DIR_NONE;
   g_realExecutionDirectionText = "NONE";
   g_realExecution.executionOrderType = "NONE";

   g_realExecutionLot = 0.0;
   g_realExecutionEntryPrice = 0.0;
   g_realExecutionSL = 0.0;
   g_realExecutionTP = 0.0;
   g_realExecutionRiskMoney = 0.0;
   g_realExecutionRewardMoney = 0.0;
   g_realExecutionRiskPercent = 0.0;
   g_realExecutionRR = 0.0;

   g_realExecution.executionLot = 0.0;
   g_realExecution.executionEntryPrice = 0.0;
   g_realExecution.executionSL = 0.0;
   g_realExecution.executionTP = 0.0;
   g_realExecution.executionRiskMoney = 0.0;
   g_realExecution.executionRewardMoney = 0.0;
   g_realExecution.executionRiskPercent = 0.0;
   g_realExecution.executionRR = 0.0;
   g_realExecution.executionSpreadPoints = 0.0;

   g_fix3OrderPlanReady = false;
   g_fix3LastOrderPlanReason = "NO_ADAPTIVE_DIRECTION";
   g_plannedExecutionLot = 0.0;
   g_plannedExecutionEntryPrice = 0.0;
   g_plannedExecutionSL = 0.0;
   g_plannedExecutionTP = 0.0;
   g_plannedExecutionRiskMoney = 0.0;
   g_plannedExecutionRewardMoney = 0.0;
   g_plannedExecutionRiskPercent = 0.0;
}

bool BuildRealExecutionOrderData(string &reason)
{
   reason = "REAL EXECUTION ORDER DATA OK";

   if(_Point <= 0.0)
   {
      reason = "INVALID POINT";
      return false;
   }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
   {
      reason = "INVALID BID ASK";
      return false;
   }

   if(UseV4AsPrimaryDecisionEngine && UseV4DirectPlanBuilder)
   {
      string v4Reason = "";
      if(BuildV4RealExecutionOrderData(v4Reason, bid, ask))
      {
         reason = v4Reason;
         return true;
      }

      string oldDirection = g_realExecutionDirectionText;
      ClearDirectionState();
      reason = "V4_DIRECT_PLAN_NO_VALID_ADAPTIVE_DIRECTION: " + v4Reason;

      AuditV4("[HORSE_BYPASS_AUDIT] function=BuildRealExecutionOrderData" +
              " fallbackDetected=true" +
              " oldDirection=" + oldDirection +
              " newDirection=NONE" +
              " blocked=true" +
              " reason=" + reason);

      AuditV4("[HORSE_EXECUTION_AUTHORITY] finalDirection=NONE" +
              " orderType=NONE" +
              " source=V4_DIRECT_PLAN" +
              " valid=false" +
              " reason=" + reason);

      return false;
   }

   if(ForceFunctionalExecutionTest && ForceFunctionalBuildPlanFromDryRun)
   {
      ENUM_ORDER_TYPE functionalOrderType = ORDER_TYPE_BUY;
      double functionalLot = 0.0;
      double functionalEntry = 0.0;
      double functionalSL = 0.0;
      double functionalTP = 0.0;
      string planReason = "";
      if(!BuildFunctionalOrderPlanFromDryRun(functionalOrderType, functionalLot, functionalEntry, functionalSL, functionalTP, planReason))
      {
         g_fix3OrderPlanReady = false;
         g_fix3LastOrderPlanReason = planReason;

         AuditV4("[WARNING] ORDER_PLAN_FALLBACK_CONTINUE reason=" + planReason);
         reason = "ORDER_PLAN_FALLBACK";
         return true;
      }

      ENUM_REAL_EXECUTION_DIRECTION direction = (functionalOrderType == ORDER_TYPE_BUY ? REAL_EXEC_DIR_BUY : REAL_EXEC_DIR_SELL);
      double riskPoints = MathAbs(functionalEntry - functionalSL) / _Point;
      double rewardPoints = MathAbs(functionalTP - functionalEntry) / _Point;
      double riskMoney = FunctionalEstimateMoneyByPoints(functionalLot, riskPoints);
      double rewardMoney = FunctionalEstimateMoneyByPoints(functionalLot, rewardPoints);
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double riskPercent = (equity > 0.0 ? (riskMoney / equity) * 100.0 : 0.0);
      double rr = (riskPoints > 0.0 ? rewardPoints / riskPoints : 0.0);

      g_realExecution.direction = direction;
      g_realExecutionDirectionText = RealExecutionDirectionToText(direction);
      g_realExecutionLot = functionalLot;
      g_realExecutionEntryPrice = functionalEntry;
      g_realExecutionSL = functionalSL;
      g_realExecutionTP = functionalTP;
      g_realExecutionRiskMoney = riskMoney;
      g_realExecutionRewardMoney = rewardMoney;
      g_realExecutionRiskPercent = riskPercent;
      g_realExecutionRR = rr;
      g_realExecution.executionLot = functionalLot;
      g_realExecution.executionEntryPrice = functionalEntry;
      g_realExecution.executionSL = functionalSL;
      g_realExecution.executionTP = functionalTP;
      g_realExecution.executionRiskMoney = riskMoney;
      g_realExecution.executionRewardMoney = rewardMoney;
      g_realExecution.executionRiskPercent = riskPercent;
      g_realExecution.executionRR = rr;
      g_realExecution.executionSpreadPoints = (double)GetCurrentSpreadPoints();
      g_realExecution.executionOrderType = RealExecutionDirectionToText(direction);
      g_fix3OrderPlanReady = true;
      g_fix3LastOrderPlanReason = planReason;
      reason = "REAL EXECUTION ORDER DATA OK - " + planReason;
      AuditRealExecution("[REAL_EXECUTION] ORDER PLAN BUILT");
      return true;
   }

   ENUM_REAL_EXECUTION_DIRECTION direction = DetectRealExecutionDirection();
   g_realExecution.direction = direction;
   g_realExecutionDirectionText = RealExecutionDirectionToText(direction);
   if(direction == REAL_EXEC_DIR_NONE)
   {
      reason = "NO REAL EXECUTION DIRECTION";
      return false;
   }

   double lot = (UsePlannedLotForRealExecution ? g_plannedExecutionLot : FixedEstimatedLot);
   if(lot <= 0.0)
      lot = FixedEstimatedLot;
   if(IsFunctionalExecutionOverrideActive())
      lot = ForceFunctionalFixedLot;
   lot = NormalizeRealExecutionLot(lot);
   if(IsFunctionalExecutionOverrideActive())
      lot = FunctionalNormalizeLot(ForceFunctionalFixedLot);

   double entry = g_plannedExecutionEntryPrice;
   if(UseCurrentBidAskForRealEntry || entry <= 0.0 || IsFunctionalExecutionOverrideActive())
      entry = (direction == REAL_EXEC_DIR_BUY ? ask : bid);

   double sl = (UsePlannedSLTPForRealExecution ? g_plannedExecutionSL : 0.0);
   double tp = (UsePlannedSLTPForRealExecution ? g_plannedExecutionTP : 0.0);
   if(IsFunctionalExecutionOverrideActive())
   {
      if(!BuildOrValidateFunctionalSLTP(direction, entry, sl, tp))
      {
         reason = "FUNCTIONAL SAFETY BLOCK: INVALID SLTP";
         return false;
      }
   }
   else if(sl <= 0.0 || tp <= 0.0)
   {
      reason = "INVALID PLANNED SL TP";
      return false;
   }

   if(RevalidateSLTPAgainstCurrentPrice || IsFunctionalExecutionOverrideActive())
   {
      if(direction == REAL_EXEC_DIR_BUY && !(sl < ask && ask < tp))
      {
         reason = "BUY SL TP NOT VALID AGAINST ASK";
         return false;
      }
      if(direction == REAL_EXEC_DIR_SELL && !(tp < bid && bid < sl))
      {
         reason = "SELL SL TP NOT VALID AGAINST BID";
         return false;
      }
   }

   double riskMoney = g_plannedExecutionRiskMoney;
   double rewardMoney = g_plannedExecutionRewardMoney;
   double riskPercent = g_plannedExecutionRiskPercent;
   double rr = g_executionDryRun.plannedRR;

   if(IsFunctionalExecutionOverrideActive())
   {
      double riskPoints = MathAbs(entry - sl) / _Point;
      double rewardPoints = MathAbs(tp - entry) / _Point;
      if(riskMoney <= 0.0)
         riskMoney = FunctionalEstimateMoneyByPoints(lot, riskPoints);
      if(rewardMoney <= 0.0)
         rewardMoney = FunctionalEstimateMoneyByPoints(lot, rewardPoints);
      if(riskPercent <= 0.0)
      {
         double equity = AccountInfoDouble(ACCOUNT_EQUITY);
         riskPercent = (equity > 0.0 ? (riskMoney / equity) * 100.0 : 0.0);
      }
      rr = (riskPoints > 0.0 ? rewardPoints / riskPoints : 0.0);
   }

   if(lot <= 0.0 || entry <= 0.0 || sl <= 0.0 || tp <= 0.0 || riskMoney <= 0.0 || rewardMoney <= 0.0 || rr < MinRealExecutionRR)
   {
      reason = "INVALID REAL EXECUTION PLANNED VALUES";
      return false;
   }

   g_realExecutionLot = lot;
   g_realExecutionEntryPrice = entry;
   g_realExecutionSL = sl;
   g_realExecutionTP = tp;
   g_realExecutionRiskMoney = riskMoney;
   g_realExecutionRewardMoney = rewardMoney;
   g_realExecutionRiskPercent = riskPercent;
   g_realExecutionRR = rr;
   g_realExecution.executionLot = lot;
   g_realExecution.executionEntryPrice = entry;
   g_realExecution.executionSL = sl;
   g_realExecution.executionTP = tp;
   g_realExecution.executionRiskMoney = riskMoney;
   g_realExecution.executionRewardMoney = rewardMoney;
   g_realExecution.executionRiskPercent = riskPercent;
   g_realExecution.executionRR = rr;
   g_realExecution.executionSpreadPoints = (double)GetCurrentSpreadPoints();
   g_realExecution.executionOrderType = RealExecutionDirectionToText(direction);

   return true;
}

bool IsRealExecutionMasterAllowed(string &reason)
{
   if(!UseRealExecutionEngine)
   {
      reason = "REAL EXECUTION ENGINE DISABLED";
      return false;
   }
   bool realSimulationOnlyEffective = RealExecutionSimulationOnly;
   if(ForceFunctionalExecutionTest)
      realSimulationOnlyEffective = false;
   if(realSimulationOnlyEffective)
   {
      reason = "REAL EXECUTION SIMULATION ONLY - NO ORDER SENT";
      return false;
   }
   if(!EnableRealExecution)
   {
      reason = "ENABLE REAL EXECUTION FALSE";
      return false;
   }
   if(!AllowLiveTrading || !g_liveTradingAllowed)
   {
      reason = "ALLOW LIVE TRADING FALSE";
      return false;
   }
   if(UseDiagnosticMode && !AllowRealExecutionInDiagnosticMode && !IsFunctionalExecutionOverrideActive())
   {
      reason = "DIAGNOSTIC MODE BLOCK";
      return false;
   }
   if(UseDiagnosticMode && IsFunctionalExecutionOverrideActive())
      AuditRealExecution("[FUNCTIONAL_OVERRIDE] ACTIVE");
   if(!g_terminalConnected)
   {
      reason = "TERMINAL NOT CONNECTED";
      return false;
   }
   if(!g_mqlTradeAllowed)
   {
      reason = "MQL TRADE DISABLED";
      return false;
   }
   if(!g_accountTradeAllowed)
   {
      reason = "ACCOUNT TRADE DISABLED";
      return false;
   }
   reason = "REAL EXECUTION MASTER ALLOWED";
   return true;
}

bool IsRealExecutionPreviousGatesApproved(string &reason)
{
   if(IsFunctionalExecutionOverrideActive())
   {
      if(ForceFunctionalIgnorePreExecutionDiagnostic || !RequirePreExecutionApprovedForRealExecution)
      {
         g_preExecutionApproved = true;
         g_preExecutionBlocked = false;
         g_preExecutionReason = "FUNCTIONAL OVERRIDE: PRE EXECUTION APPROVED FOR TEST";
         AuditRealExecution("[FUNCTIONAL_OVERRIDE] PRE EXECUTION DIAGNOSTIC BYPASSED");
      }
      if(ForceFunctionalIgnoreDryRunDiagnostic || !RequireDryRunApprovedForRealExecution)
      {
         g_dryRunApproved = true;
         g_dryRunBlocked = false;
         g_dryRunReason = "FUNCTIONAL OVERRIDE: DRY RUN NOT REQUIRED FOR TEST";
         AuditRealExecution("[FUNCTIONAL_OVERRIDE] DRY RUN DIAGNOSTIC BYPASSED");
      }
      reason = "PREVIOUS GATES APPROVED: FUNCTIONAL OVERRIDE ACTIVE";
      return true;
   }

   if(RequireDryRunApprovedForRealExecution && !g_dryRunApproved)
   {
      reason = "DRY RUN NOT APPROVED";
      return false;
   }
   if(RequirePreExecutionApprovedForRealExecution && !g_preExecutionApproved)
   {
      reason = "PRE EXECUTION NOT APPROVED";
      return false;
   }
   if(RequirePlannedOrderForRealExecution)
   {
      if(g_realExecutionLot <= 0.0 || g_realExecutionEntryPrice <= 0.0 || g_realExecutionSL <= 0.0)
      {
         reason = "PLANNED ORDER NOT VALID";
         return false;
      }
      // TP=0 is a valid, intentional state when the fixed server TP is disabled
      // and Stage15 manages the exit dynamically (same tolerance as elsewhere).
      if(g_realExecutionTP <= 0.0 && !(UseStage15SmartDynamicExitEngine && Stage15_DisableFixedServerTP))
      {
         reason = "PLANNED ORDER NOT VALID";
         return false;
      }
   }
   reason = "PREVIOUS GATES APPROVED";
   return true;
}

bool IsRealExecutionDirectionAllowed(string &reason)
{
   ENUM_REAL_EXECUTION_DIRECTION direction = g_realExecution.direction;
   if(RequireDryRunDirectionForRealExecution && direction == REAL_EXEC_DIR_NONE)
   {
      reason = "NO REAL EXECUTION DIRECTION";
      return false;
   }
   if(direction == REAL_EXEC_DIR_BUY && !AllowRealBuyExecution)
   {
      reason = "REAL BUY DISABLED";
      return false;
   }
   if(direction == REAL_EXEC_DIR_SELL && !AllowRealSellExecution)
   {
      reason = "REAL SELL DISABLED";
      return false;
   }
   if(direction == REAL_EXEC_DIR_NONE)
   {
      reason = "NO REAL EXECUTION DIRECTION";
      return false;
   }
   if(UseV4AsPrimaryDecisionEngine && UseV4DirectPlanBuilder)
   {
      ENUM_ORDER_TYPE v4OrderType = V4RealDirectionToOrderType(direction);
      string realText = V4OrderTypeToPlanTextSafe(v4OrderType);
      string dryText = V4DryRunDirectionTextSafe();
      bool dryRunMismatch = (dryText != "NONE" && dryText != realText);
      bool entryDecisionMismatch = (g_entryDecisionDirection != "" && g_entryDecisionDirection != realText);
      if(dryRunMismatch || entryDecisionMismatch)
      {
         AuditV4("[V4_DRYRUN_STALE_IGNORED] realDirection=" + realText +
                 " dryRunDirection=" + dryText +
                 " entryDecisionDirection=" + g_entryDecisionDirection +
                 " plannedOrderType=" + g_executionDryRun.plannedOrderType +
                 " source=V4_DIRECT_PLAN_AUTHORITY action=DO_NOT_BLOCK_REAL_EXECUTION");
      }
   }
   reason = "REAL EXECUTION DIRECTION APPROVED";
   return true;
}

bool IsRealExecutionRiskApproved(string &reason)
{
   if(IsFunctionalExecutionOverrideActive())
   {
      string cycleReason = "";
      if(!CanStartNewAggressiveCycle(cycleReason))
      {
         reason = "[AGGRESSIVE_CYCLE][BLOCK_REASON] " + cycleReason;
         g_fix3LastBlockReason = reason;
         return false;
      }
      string safetyReason = "";
      if(!IsFunctionalSafetyApproved(ForceFunctionalFixedLot, safetyReason))
      {
         reason = safetyReason;
         return false;
      }
      reason = "REAL EXECUTION RISK APPROVED: FUNCTIONAL OVERRIDE ACTIVE";
      return true;
   }

   if(!UseRealExecutionRiskCheck)
   {
      reason = "REAL EXECUTION RISK CHECK DISABLED";
      return true;
   }
   if(g_realExecutionRiskMoney <= 0.0)
   {
      reason = "INVALID REAL EXECUTION RISK MONEY";
      return false;
   }
   if(g_realExecutionRiskMoney > MaxRealExecutionRiskMoney)
   {
      reason = "REAL EXECUTION RISK MONEY TOO HIGH";
      return false;
   }
   if(g_realExecutionRiskPercent > MaxRealExecutionRiskPercent)
   {
      reason = "REAL EXECUTION RISK PERCENT TOO HIGH";
      return false;
   }
   if(g_realExecutionRR < MinRealExecutionRR)
   {
      reason = "REAL EXECUTION RR TOO LOW";
      return false;
   }
   if(g_realExecutionLot > MaxRealExecutionLot || g_realExecutionLot < MinRealExecutionLot)
   {
      reason = "REAL EXECUTION LOT OUT OF LIMIT";
      return false;
   }
   reason = "REAL EXECUTION RISK APPROVED";
   return true;
}

bool HasOpenPositionSameSymbolMagic()
{
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         string sym = PositionGetString(POSITION_SYMBOL);
         long magic = PositionGetInteger(POSITION_MAGIC);
         if(sym == _Symbol && magic == MagicNumber)
            return true;
      }
   }
   return false;
}

bool HasPendingOrderSameSymbolMagic()
{
   int total = OrdersTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderSelect(ticket))
      {
         string sym = OrderGetString(ORDER_SYMBOL);
         long magic = OrderGetInteger(ORDER_MAGIC);
         if(sym == _Symbol && magic == MagicNumber)
            return true;
      }
   }
   return false;
}

bool IsRealExecutionDuplicateSafe(string &reason)
{
   if(IsFunctionalExecutionOverrideActive())
   {
      if(CountAllMagicPositions() >= ForceFunctionalMaxTotalPositions)
      {
         reason = "FUNCTIONAL SAFETY BLOCK: MAX TOTAL POSITIONS";
         return false;
      }
      if(BlockIfAnyPositionOpenSameSymbolMagic && HasOpenPositionSameSymbolMagic())
      {
         reason = "OPEN POSITION SAME SYMBOL MAGIC";
         return false;
      }
      if(BlockIfAnyPendingOrderSameSymbolMagic && HasPendingOrderSameSymbolMagic())
      {
         reason = "PENDING ORDER SAME SYMBOL MAGIC";
         return false;
      }
      reason = "REAL EXECUTION DUPLICATE SAFE: FUNCTIONAL OVERRIDE ACTIVE";
      return true;
   }

   if(UseV4AsPrimaryDecisionEngine)
   {
      ENUM_ORDER_TYPE v4Dir = V4RealDirectionToOrderType(g_realExecution.direction);
      string dirText = V4OrderTypeToPlanTextSafe(v4Dir);
      bool hasOpenPosition = HasOpenPositionSameSymbolMagic();
      bool hasOppositePosition = ((v4Dir == ORDER_TYPE_BUY || v4Dir == ORDER_TYPE_SELL) && HasOppositePositionV4(v4Dir));
      datetime barTimeV4 = iTime(_Symbol, _Period, 0);
      bool sameCandleBlocked = (PreventRealExecutionSameCandle && g_lastRealExecutionBarTime > 0 && barTimeV4 == g_lastRealExecutionBarTime);
      bool cooldownActive = (MinSecondsBetweenRealExecutions > 0 && g_lastRealExecutionTime > 0 && (TimeCurrent() - g_lastRealExecutionTime) < MinSecondsBetweenRealExecutions);

      if(hasOppositePosition)
      {
         string forceCloseReason = "";
         if(V4CloseOppositePositionsForAggressiveReverse(v4Dir, forceCloseReason))
         {
            hasOpenPosition = HasOpenPositionSameSymbolMagic();
            hasOppositePosition = HasOppositePositionV4(v4Dir);
            AuditV4("[V4_DUPLICATE_GATE_AUDIT] direction=" + dirText +
                    " hasOpenPosition=" + BoolToText(hasOpenPosition) +
                    " hasOppositePosition=" + BoolToText(hasOppositePosition) +
                    " lastExecutionDirection=" + V4RealDirectionTextSafe(g_realExecution.direction) +
                    " lastPlanDirection=" + V4OrderTypeToPlanTextSafe(g_fix3LastOrderPlanDirection) +
                    " cooldownActive=" + BoolToText(cooldownActive) +
                    " sameCandleBlocked=" + BoolToText(sameCandleBlocked) +
                    " allowed=true blockReason=OPPOSITE_FORCE_CLOSED_CONTINUE reason=" + forceCloseReason);
         }
         else
         {
            V4ArmPendingReverseAfterClose(v4Dir, dirText + "_SIGNAL_WHILE_OPPOSITE_POSITION_OPEN_REVERSE_AFTER_CLOSE");
            reason = "OPPOSITE_POSITION_PROTECTION_REVERSE_ARMED_FORCE_CLOSE_FAILED: " + forceCloseReason;
            AuditV4("[V4_DUPLICATE_GATE_AUDIT] direction=" + dirText +
                    " hasOpenPosition=" + BoolToText(hasOpenPosition) +
                    " hasOppositePosition=" + BoolToText(hasOppositePosition) +
                    " lastExecutionDirection=" + V4RealDirectionTextSafe(g_realExecution.direction) +
                    " lastPlanDirection=" + V4OrderTypeToPlanTextSafe(g_fix3LastOrderPlanDirection) +
                    " cooldownActive=" + BoolToText(cooldownActive) +
                    " sameCandleBlocked=" + BoolToText(sameCandleBlocked) +
                    " allowed=false blockReason=" + reason);
            return false;
         }
      }

      if(V4CountMagicPositions() >= MaxPositionsV4)
      {
         reason = "MAX_POSITIONS_REACHED";
         AuditV4("[V4_DUPLICATE_GATE_AUDIT] direction=" + dirText +
                 " hasOpenPosition=" + BoolToText(hasOpenPosition) +
                 " hasOppositePosition=" + BoolToText(hasOppositePosition) +
                 " lastExecutionDirection=" + V4RealDirectionTextSafe(g_realExecution.direction) +
                 " lastPlanDirection=" + V4OrderTypeToPlanTextSafe(g_fix3LastOrderPlanDirection) +
                 " cooldownActive=" + BoolToText(cooldownActive) +
                 " sameCandleBlocked=" + BoolToText(sameCandleBlocked) +
                 " allowed=false blockReason=" + reason);
         return false;
      }

      if(BlockIfAnyPendingOrderSameSymbolMagic && HasPendingOrderSameSymbolMagic())
      {
         reason = "ANTI_OVERTRADE_OBJECTIVE";
         AuditV4("[V4_DUPLICATE_GATE_AUDIT] direction=" + dirText +
                 " hasOpenPosition=" + BoolToText(hasOpenPosition) +
                 " hasOppositePosition=" + BoolToText(hasOppositePosition) +
                 " lastExecutionDirection=" + V4RealDirectionTextSafe(g_realExecution.direction) +
                 " lastPlanDirection=" + V4OrderTypeToPlanTextSafe(g_fix3LastOrderPlanDirection) +
                 " cooldownActive=" + BoolToText(cooldownActive) +
                 " sameCandleBlocked=" + BoolToText(sameCandleBlocked) +
                 " allowed=false blockReason=PENDING_ORDER_SAME_SYMBOL_MAGIC");
         return false;
      }

      if(sameCandleBlocked)
      {
         reason = "REAL_EXECUTION_SAME_CANDLE";
         AuditV4("[V4_DUPLICATE_GATE_AUDIT] direction=" + dirText +
                 " hasOpenPosition=" + BoolToText(hasOpenPosition) +
                 " hasOppositePosition=" + BoolToText(hasOppositePosition) +
                 " lastExecutionDirection=" + V4RealDirectionTextSafe(g_realExecution.direction) +
                 " lastPlanDirection=" + V4OrderTypeToPlanTextSafe(g_fix3LastOrderPlanDirection) +
                 " cooldownActive=" + BoolToText(cooldownActive) +
                 " sameCandleBlocked=" + BoolToText(sameCandleBlocked) +
                 " allowed=false blockReason=" + reason);
         return false;
      }

      if(cooldownActive)
      {
         reason = "REAL_EXECUTION_COOLDOWN";
         AuditV4("[V4_DUPLICATE_GATE_AUDIT] direction=" + dirText +
                 " hasOpenPosition=" + BoolToText(hasOpenPosition) +
                 " hasOppositePosition=" + BoolToText(hasOppositePosition) +
                 " lastExecutionDirection=" + V4RealDirectionTextSafe(g_realExecution.direction) +
                 " lastPlanDirection=" + V4OrderTypeToPlanTextSafe(g_fix3LastOrderPlanDirection) +
                 " cooldownActive=" + BoolToText(cooldownActive) +
                 " sameCandleBlocked=" + BoolToText(sameCandleBlocked) +
                 " allowed=false blockReason=" + reason);
         return false;
      }

      reason = "REAL EXECUTION DUPLICATE SAFE V4";
      AuditV4("[V4_DUPLICATE_GATE_AUDIT] direction=" + dirText +
              " hasOpenPosition=" + BoolToText(hasOpenPosition) +
              " hasOppositePosition=" + BoolToText(hasOppositePosition) +
              " lastExecutionDirection=" + V4RealDirectionTextSafe(g_realExecution.direction) +
              " lastPlanDirection=" + V4OrderTypeToPlanTextSafe(g_fix3LastOrderPlanDirection) +
              " cooldownActive=" + BoolToText(cooldownActive) +
              " sameCandleBlocked=" + BoolToText(sameCandleBlocked) +
              " allowed=true blockReason=NONE");
      return true;
   }

   if(!UseRealExecutionDuplicateProtection)
   {
      reason = "REAL EXECUTION DUPLICATE CHECK DISABLED";
      return true;
   }
   if(BlockIfAnyPositionOpenSameSymbolMagic && HasOpenPositionSameSymbolMagic())
   {
      reason = "OPEN POSITION SAME SYMBOL MAGIC";
      return false;
   }
   if(BlockIfAnyPendingOrderSameSymbolMagic && HasPendingOrderSameSymbolMagic())
   {
      reason = "PENDING ORDER SAME SYMBOL MAGIC";
      return false;
   }
   datetime barTime = iTime(_Symbol, _Period, 0);
   if(PreventRealExecutionSameCandle && g_lastRealExecutionBarTime > 0 && barTime == g_lastRealExecutionBarTime)
   {
      reason = "REAL EXECUTION SAME CANDLE BLOCK";
      return false;
   }
   if(MinSecondsBetweenRealExecutions > 0 && g_lastRealExecutionTime > 0 && (TimeCurrent() - g_lastRealExecutionTime) < MinSecondsBetweenRealExecutions)
   {
      reason = "REAL EXECUTION COOLDOWN";
      return false;
   }
   if(DisableRealExecutionAfterOneTrade && g_realOrderSent)
   {
      reason = "REAL ORDER ALREADY SENT";
      return false;
   }
   if(!ForceFunctionalAggressiveEntryCycle && MaxRealExecutionAttemptsPerSignal > 0 && g_realExecutionAttemptCount >= MaxRealExecutionAttemptsPerSignal)
   {
      reason = "MAX REAL EXECUTION ATTEMPTS REACHED";
      return false;
   }
   reason = "REAL EXECUTION DUPLICATE SAFE";
   return true;
}

bool ValidateRealExecutionLot(string &reason)
{
   double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(minVol <= 0.0 || maxVol < minVol || step <= 0.0)
   {
      reason = "INVALID BROKER VOLUME SETTINGS";
      return false;
   }
   if(g_realExecutionLot < minVol || g_realExecutionLot > maxVol)
   {
      reason = "LOT OUT OF BROKER RANGE";
      return false;
   }
   double units = g_realExecutionLot / step;
   if(MathAbs(units - MathRound(units)) > 0.000001)
   {
      reason = "LOT NOT ALIGNED TO STEP";
      return false;
   }
   reason = "REAL EXECUTION LOT VALID";
   return true;
}

bool ValidateRealExecutionStops(string &reason)
{
   if(_Point <= 0.0)
   {
      reason = "INVALID POINT";
      return false;
   }
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
   {
      reason = "INVALID BID ASK";
      return false;
   }
   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long freezeLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double minDistance = 0.0;
   if(UseBrokerStopLevelValidation)
      minDistance = MathMax(minDistance, (double)stopsLevel * _Point);
   if(UseBrokerFreezeLevelValidation)
      minDistance = MathMax(minDistance, (double)freezeLevel * _Point);

   // Stage15 dynamic exit intentionally sends TP=0 (no fixed server TP).
   // In that mode TP=0 is VALID and the TP side must not be validated,
   // mirroring the tolerance already used at the plan-reuse checks above.
   bool serverTPDisabled = (UseStage15SmartDynamicExitEngine && Stage15_DisableFixedServerTP);
   bool hasTP = (g_realExecutionTP > 0.0);

   if(g_realExecution.direction == REAL_EXEC_DIR_BUY)
   {
      // SL must always be present and below the market for a BUY.
      if(!(g_realExecutionSL > 0.0 && g_realExecutionSL < ask))
      {
         reason = "BUY STOPS INVALID";
         return false;
      }
      // TP is only validated when actually used (not when dynamically managed).
      if(hasTP)
      {
         if(!(ask < g_realExecutionTP))
         {
            reason = "BUY STOPS INVALID";
            return false;
         }
      }
      else if(!serverTPDisabled)
      {
         reason = "BUY STOPS INVALID";
         return false;
      }
      if(MathAbs(ask - g_realExecutionSL) < minDistance)
      {
         reason = "BUY STOPS TOO CLOSE";
         return false;
      }
      if(hasTP && MathAbs(g_realExecutionTP - ask) < minDistance)
      {
         reason = "BUY STOPS TOO CLOSE";
         return false;
      }
   }
   else if(g_realExecution.direction == REAL_EXEC_DIR_SELL)
   {
      // SL must always be present and above the market for a SELL.
      if(!(g_realExecutionSL > 0.0 && bid < g_realExecutionSL))
      {
         reason = "SELL STOPS INVALID";
         return false;
      }
      if(hasTP)
      {
         if(!(g_realExecutionTP < bid))
         {
            reason = "SELL STOPS INVALID";
            return false;
         }
      }
      else if(!serverTPDisabled)
      {
         reason = "SELL STOPS INVALID";
         return false;
      }
      if(MathAbs(g_realExecutionSL - bid) < minDistance)
      {
         reason = "SELL STOPS TOO CLOSE";
         return false;
      }
      if(hasTP && MathAbs(bid - g_realExecutionTP) < minDistance)
      {
         reason = "SELL STOPS TOO CLOSE";
         return false;
      }
   }
   else
   {
      reason = "NO STOPS DIRECTION";
      return false;
   }
   reason = "REAL EXECUTION STOPS VALID";
   return true;
}

bool ValidateRealExecutionMargin(string &reason)
{
   if(!UseRealMarginCheck)
   {
      reason = "REAL MARGIN CHECK DISABLED";
      return true;
   }
   double price = g_realExecutionEntryPrice;
   ENUM_ORDER_TYPE orderType = (g_realExecution.direction == REAL_EXEC_DIR_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   double margin = 0.0;
   if(!OrderCalcMargin(orderType, _Symbol, g_realExecutionLot, price, margin) || margin <= 0.0)
   {
      reason = "REAL EXECUTION MARGIN CALC FAILED";
      return false;
   }
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(freeMargin <= margin)
   {
      reason = "INSUFFICIENT FREE MARGIN";
      return false;
   }
   g_realExecutionMarginRequired = margin;
   g_realExecution.executionMarginRequired = margin;
   reason = "REAL EXECUTION MARGIN VALID";
   return true;
}

bool ValidateRealExecutionSpread(string &reason)
{
   if(!UseRealSpreadCheck)
   {
      reason = "REAL SPREAD CHECK DISABLED";
      return true;
   }
   int spread = GetCurrentSpreadPoints();
   if(spread < 0)
   {
      reason = "INVALID REAL EXECUTION SPREAD";
      return false;
   }
   if(spread > MaxRealExecutionSpreadPoints)
   {
      reason = "REAL EXECUTION SPREAD TOO HIGH";
      return false;
   }
   g_realExecution.executionSpreadPoints = (double)spread;
   reason = "REAL EXECUTION SPREAD VALID";
   return true;
}

bool IsRealExecutionBrokerSafe(string &reason)
{
   if(!ValidateRealExecutionLot(reason)) return false;
   if(!ValidateRealExecutionStops(reason)) return false;
   if(!ValidateRealExecutionMargin(reason)) return false;
   if(!ValidateRealExecutionSpread(reason)) return false;
   reason = "REAL EXECUTION BROKER SAFE";
   return true;
}

bool IsRealExecutionEnvironmentSafe(string &reason)
{
   if(!g_environmentOK)
   {
      reason = "TERMINAL_TRADE_DISABLED";
      return false;
   }
   if(UseV4AsPrimaryDecisionEngine)
   {
      if(!g_symbolOK || !g_timeframeOK)
      {
         reason = "SYMBOL_TRADE_DISABLED";
         return false;
      }
      if(!g_securityFiltersOK)
      {
         string normalizedSecurity = NormalizeLegacyReasonV4(g_securityFilterReason);
         if(IsAbsoluteRiskBlockV4(normalizedSecurity))
         {
            reason = normalizedSecurity;
            return false;
         }
         AuditV4("[V4_LEGACY_OVERRIDE] LEGACY_FILTER_PENALTY_ONLY_CONTINUE reason=" + normalizedSecurity);
      }
      reason = "REAL EXECUTION ENVIRONMENT SAFE V4";
      return true;
   }
   if(!g_securityFiltersOK)
   {
      reason = "SECURITY FILTERS NOT OK";
      return false;
   }
   reason = "REAL EXECUTION ENVIRONMENT SAFE";
   return true;
}


string V4DryRunDirectionTextSafe()
{
   if(g_executionDryRun.direction == DRY_RUN_DIR_BUY) return "BUY";
   if(g_executionDryRun.direction == DRY_RUN_DIR_SELL) return "SELL";
   return "NONE";
}

string V4RealDirectionTextSafe(ENUM_REAL_EXECUTION_DIRECTION d)
{
   if(d == REAL_EXEC_DIR_BUY) return "BUY";
   if(d == REAL_EXEC_DIR_SELL) return "SELL";
   return "NONE";
}


string V4OrderTypeToPlanTextSafe(ENUM_ORDER_TYPE direction)
{
   if(direction == ORDER_TYPE_BUY) return "BUY";
   if(direction == ORDER_TYPE_SELL) return "SELL";
   return "NONE";
}

ENUM_DRY_RUN_DIRECTION V4OrderTypeToDryRunDirection(ENUM_ORDER_TYPE direction)
{
   if(direction == ORDER_TYPE_BUY) return DRY_RUN_DIR_BUY;
   if(direction == ORDER_TYPE_SELL) return DRY_RUN_DIR_SELL;
   return DRY_RUN_DIR_NONE;
}

bool V4HasOpenPositionInDirection(ENUM_ORDER_TYPE direction)
{
   ENUM_POSITION_TYPE ptNeed = (direction == ORDER_TYPE_BUY ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pt == ptNeed) return true;
   }
   return false;
}

void V4ClearPendingReverse(string reason)
{
   if(g_pendingReverseAfterClose)
   {
      AuditV4("[V4_REVERSE_CLEARED] pendingDirection=" + V4OrderTypeToPlanTextSafe(g_pendingReverseDirection) +
              " reason=" + reason);
   }
   g_pendingReverseAfterClose = false;
   g_pendingReverseDirection = (ENUM_ORDER_TYPE)-1;
   g_pendingReverseCreatedAt = 0;
   g_pendingReverseReason = "NONE";
}

void V4ArmPendingReverseAfterClose(ENUM_ORDER_TYPE pendingDirection, string reason)
{
   if(pendingDirection != ORDER_TYPE_BUY && pendingDirection != ORDER_TYPE_SELL) return;
   g_pendingReverseAfterClose = true;
   g_pendingReverseDirection = pendingDirection;
   g_pendingReverseCreatedAt = TimeCurrent();
   g_pendingReverseReason = reason;

   string fromPosition = (pendingDirection == ORDER_TYPE_BUY ? "SELL" : "BUY");
   AuditV4("[V4_REVERSE_ARMED] fromPosition=" + fromPosition +
           " pendingDirection=" + V4OrderTypeToPlanTextSafe(pendingDirection) +
           " reason=OPPOSITE_POSITION_PROTECTION_REVERSE_AFTER_CLOSE");
}

void V4ArmAggressiveBuyExecutionLatch(double score, string source)
{
   g_v4AggressiveBuyLatchActive = true;
   g_v4AggressiveBuyLatchTime = TimeCurrent();
   g_v4AggressiveBuyLatchBarTime = iTime(_Symbol, _Period, 0);
   g_v4AggressiveBuyLatchScore = score;
   g_v4AggressiveBuyLatchSource = source;
   AuditV4("[V4_BUY_LATCH_ARMED] direction=BUY score=" + DoubleToString(score,1) +
           " source=" + source +
           " ttlSeconds=" + IntegerToString(g_v4AggressiveBuyLatchTTLSeconds));
}

bool V4HasFreshAggressiveBuyLatch()
{
   if(!g_v4AggressiveBuyLatchActive) return false;
   if(g_v4AggressiveBuyLatchTime <= 0) return false;
   int age = (int)(TimeCurrent() - g_v4AggressiveBuyLatchTime);
   if(g_v4AggressiveBuyLatchTTLSeconds > 0 && age > g_v4AggressiveBuyLatchTTLSeconds)
   {
      AuditV4("[V4_BUY_LATCH_EXPIRED] ageSeconds=" + IntegerToString(age) +
              " reason=TTL_EXPIRED");
      g_v4AggressiveBuyLatchActive = false;
      return false;
   }
   return true;
}

void V4ClearAggressiveBuyLatch(string reason)
{
   if(g_v4AggressiveBuyLatchActive)
      AuditV4("[V4_BUY_LATCH_CLEARED] reason=" + reason);
   g_v4AggressiveBuyLatchActive = false;
   g_v4AggressiveBuyLatchTime = 0;
   g_v4AggressiveBuyLatchBarTime = 0;
   g_v4AggressiveBuyLatchScore = 0.0;
   g_v4AggressiveBuyLatchSource = "NONE";
}

bool V4CloseOppositePositionsForAggressiveReverse(ENUM_ORDER_TYPE desiredDirection, string &reason)
{
   reason = "NO_OPPOSITE_POSITION";
   if(desiredDirection != ORDER_TYPE_BUY && desiredDirection != ORDER_TYPE_SELL)
   {
      reason = "INVALID_REVERSE_DIRECTION";
      return false;
   }

   ENUM_POSITION_TYPE oppositeType = (desiredDirection == ORDER_TYPE_BUY ? POSITION_TYPE_SELL : POSITION_TYPE_BUY);
   string desiredText = V4OrderTypeToPlanTextSafe(desiredDirection);
   string oppositeText = (desiredDirection == ORDER_TYPE_BUY ? "SELL" : "BUY");
   bool found = false;
   bool allClosed = true;

   trade.SetExpertMagicNumber((ulong)MagicNumber);
   trade.SetDeviationInPoints(RealExecutionDeviationPoints);

   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype != oppositeType) continue;

      found = true;
      double volume = PositionGetDouble(POSITION_VOLUME);
      AuditV4("[V4_FORCE_REVERSE_CLOSE] desiredDirection=" + desiredText +
              " closingOpposite=" + oppositeText +
              " ticket=" + UlongToText(ticket) +
              " volume=" + DoubleToString(volume,2) +
              " action=POSITION_CLOSE_BEFORE_NEW_ENTRY");

      string v10ReverseReason = "AGGRESSIVE_REVERSE_CLOSE_OPPOSITE_POSITION";
      bool closed = ClosePositionV4(ticket, v10ReverseReason);
      if(!closed)
      {
         allClosed = false;
         AuditV4("[V4_FORCE_REVERSE_CLOSE_FAILED] desiredDirection=" + desiredText +
                 " ticket=" + UlongToText(ticket) +
                 " retcode=" + IntegerToString((int)trade.ResultRetcode()) +
                 " desc=" + trade.ResultRetcodeDescription());
      }
      else
      {
         AuditV4("[V4_FORCE_REVERSE_CLOSE_OK] desiredDirection=" + desiredText +
                 " ticket=" + UlongToText(ticket) +
                 " deal=" + UlongToText(trade.ResultDeal()) +
                 " nextAction=BUILD_NEW_" + desiredText + "_PLAN");
      }
   }

   if(!found)
   {
      reason = "NO_OPPOSITE_POSITION";
      return true;
   }
   if(!allClosed)
   {
      reason = "OPPOSITE_POSITION_CLOSE_FAILED";
      return false;
   }
   if(HasOppositePositionV4(desiredDirection))
   {
      reason = "OPPOSITE_POSITION_STILL_OPEN_AFTER_FORCE_CLOSE";
      return false;
   }

   reason = "OPPOSITE_POSITION_FORCE_CLOSED_FOR_" + desiredText;
   AuditV4("[V4_FORCE_REVERSE_READY] desiredDirection=" + desiredText +
           " noOppositePosition=true reason=" + reason);
   return true;
}

bool V4PendingReverseExpired()
{
   if(!g_pendingReverseAfterClose) return false;
   int age = (int)(TimeCurrent() - g_pendingReverseCreatedAt);
   return (g_pendingReverseTimeoutSeconds > 0 && age > g_pendingReverseTimeoutSeconds);
}

void V4SyncDryRunWithV4DirectPlan(ENUM_ORDER_TYPE direction)
{
   if(direction == ORDER_TYPE_BUY)
   {
      g_executionDryRun.direction = DRY_RUN_DIR_BUY;
      g_executionDryRun.plannedOrderType = "BUY";
      g_executionDryRun.buyReady = true;
      g_executionDryRun.sellReady = false;
   }
   else if(direction == ORDER_TYPE_SELL)
   {
      g_executionDryRun.direction = DRY_RUN_DIR_SELL;
      g_executionDryRun.plannedOrderType = "SELL";
      g_executionDryRun.buyReady = false;
      g_executionDryRun.sellReady = true;
   }
}

void V4MarkV4PlanSync(ENUM_ORDER_TYPE direction)
{
   g_fix3OrderPlanReady = true;
   g_fix3LastOrderPlanDirection = direction;
   g_fix3LastOrderPlanBuildTime = TimeCurrent();
   g_fix3LastOrderPlanBarTime = iTime(_Symbol, _Period, 0);
   g_fix3LastOrderPlanSymbol = _Symbol;
   g_fix3LastOrderPlanMagic = MagicNumber;
   V4SyncDryRunWithV4DirectPlan(direction);

   AuditV4("[V4_PLAN_SYNC] selectedDirection=" + V4OrderTypeToPlanTextSafe(direction) +
           " g_realExecution.direction=" + V4RealDirectionTextSafe(g_realExecution.direction) +
           " plannedOrderType=" + g_executionDryRun.plannedOrderType +
           " g_fix3OrderPlanReady=" + BoolToText(g_fix3OrderPlanReady) +
           " source=V4_DIRECT_PLAN_BUILDER");
}

void V4InvalidateCurrentPlan(string reason, ENUM_ORDER_TYPE newSelectedDirection=(ENUM_ORDER_TYPE)-1)
{
   if(g_fix3OrderPlanReady)
   {
      AuditV4("[V4_STALE_PLAN_REJECTED] oldPlanDirection=" + V4OrderTypeToPlanTextSafe(g_fix3LastOrderPlanDirection) +
              " newSelectedDirection=" + V4OrderTypeToPlanTextSafe(newSelectedDirection) +
              " reason=" + reason);
   }
   g_fix3OrderPlanReady = false;
   g_fix3LastOrderPlanDirection = (ENUM_ORDER_TYPE)-1;
   g_fix3LastOrderPlanBuildTime = 0;
   g_fix3LastOrderPlanBarTime = 0;
   g_fix3LastOrderPlanSymbol = "";
   g_fix3LastOrderPlanMagic = 0;
}

bool HasReusableV4RealExecutionPlan()
{
   if(!g_fix3OrderPlanReady)
      return false;
   if(g_realExecution.direction != REAL_EXEC_DIR_BUY && g_realExecution.direction != REAL_EXEC_DIR_SELL)
   {
      V4InvalidateCurrentPlan("PLAN_HAS_NO_REAL_DIRECTION", (ENUM_ORDER_TYPE)-1);
      return false;
   }

   ENUM_ORDER_TYPE currentDirection = V4RealDirectionToOrderType(g_realExecution.direction);

   if(UseV4AsPrimaryDecisionEngine && UseV4DirectPlanBuilder)
   {
      if(g_fix3LastOrderPlanDirection != currentDirection)
      {
         V4InvalidateCurrentPlan("PLAN_DIRECTION_MISMATCH_REBUILD_REQUIRED", currentDirection);
         return false;
      }
      if(g_fix3LastOrderPlanSymbol != _Symbol || g_fix3LastOrderPlanMagic != MagicNumber)
      {
         V4InvalidateCurrentPlan("PLAN_SYMBOL_OR_MAGIC_MISMATCH_REBUILD_REQUIRED", currentDirection);
         return false;
      }
      if(g_realExecutionLot <= 0.0 || g_realExecutionEntryPrice <= 0.0 || g_realExecutionSL <= 0.0)
      {
         V4InvalidateCurrentPlan("PLAN_VALUES_INVALID_REBUILD_REQUIRED", currentDirection);
         return false;
      }
      if(g_realExecutionTP <= 0.0 && !(UseStage15SmartDynamicExitEngine && Stage15_DisableFixedServerTP))
      {
         V4InvalidateCurrentPlan("PLAN_TP_INVALID_REBUILD_REQUIRED", currentDirection);
         return false;
      }

      AuditV4("[V4_STALE_PLAN_FIX] action=REUSE_FRESH_CURRENT_TICK_PLAN direction=" + V4OrderTypeToPlanTextSafe(currentDirection) +
              " planReady=true source=V4_DIRECT_PLAN");
      return true;
   }

   if(g_realExecutionLot <= 0.0 || g_realExecutionEntryPrice <= 0.0 || g_realExecutionSL <= 0.0)
      return false;
   if(g_realExecutionTP <= 0.0 && !(UseStage15SmartDynamicExitEngine && Stage15_DisableFixedServerTP))
      return false;
   return true;
}

void AuditV4RealExecutionGate(string stage, string finalAllowed, string blockReason)
{
   ENUM_ORDER_TYPE direction = V4RealDirectionToOrderType(g_realExecution.direction);
   string directionText = (direction == ORDER_TYPE_BUY ? "BUY" : (direction == ORDER_TYPE_SELL ? "SELL" : "NONE"));
   string plannedOrderType = g_executionDryRun.plannedOrderType;
   if(plannedOrderType == "") plannedOrderType = "NONE";

   AuditV4("[V4_REAL_EXECUTION_GATE_AUDIT]" +
           " stage=" + stage +
           " direction=" + directionText +
           " dryRunDirection=" + V4DryRunDirectionTextSafe() +
           " plannedOrderType=" + plannedOrderType +
           " entryDecisionDirection=" + g_entryDecisionDirection +
           " baseDirection=" + g_entryBaseDirection +
           " realDirection=" + V4RealDirectionTextSafe(g_realExecution.direction) +
           " allowed=" + finalAllowed +
           " blockReason=" + blockReason);
}

void AuditV4BuyPathTrace(string stage, string finalAllowed, string blockReason)
{
   ENUM_ORDER_TYPE direction = V4RealDirectionToOrderType(g_realExecution.direction);
   if(direction != ORDER_TYPE_BUY)
      return;

   string plannedOrderType = g_executionDryRun.plannedOrderType;
   if(plannedOrderType == "") plannedOrderType = "NONE";

   bool hasOpenPosition = HasOpenPositionSameSymbolMagic();
   bool hasOppositePosition = HasOppositePositionV4(ORDER_TYPE_BUY);
   datetime barTime = iTime(_Symbol, _Period, 0);
   bool cooldownActive = (MinSecondsBetweenRealExecutions > 0 && g_lastRealExecutionTime > 0 && (TimeCurrent() - g_lastRealExecutionTime) < MinSecondsBetweenRealExecutions);
   bool sameCandleBlocked = (PreventRealExecutionSameCandle && g_lastRealExecutionBarTime > 0 && barTime == g_lastRealExecutionBarTime);
   bool antiOvertradeBlocked = (cooldownActive || sameCandleBlocked || (BlockIfAnyPendingOrderSameSymbolMagic && HasPendingOrderSameSymbolMagic()));
   bool marketWeakBlocked = (NormalizeLegacyReasonV4(blockReason) == "ANTI_OVERTRADE_MARKET_WEAK" || blockReason == "MARKET_DEAD" || blockReason == "MARKET_STRENGTH_WEAK");

   AuditV4("[V4_BUY_PATH_TRACE]" +
           " stage=" + stage +
           " selectedDirection=BUY" +
           " g_realExecution.direction=" + V4RealDirectionTextSafe(g_realExecution.direction) +
           " plannedOrderType=" + plannedOrderType +
           " g_executionDryRun.direction=" + V4DryRunDirectionTextSafe() +
           " entryDecisionDirection=" + g_entryDecisionDirection +
           " baseDirection=" + g_entryBaseDirection +
           " hasOpenPosition=" + BoolToText(hasOpenPosition) +
           " hasOppositePosition=" + BoolToText(hasOppositePosition) +
           " cooldownActive=" + BoolToText(cooldownActive) +
           " sameCandleBlocked=" + BoolToText(sameCandleBlocked) +
           " antiOvertradeBlocked=" + BoolToText(antiOvertradeBlocked) +
           " marketWeakBlocked=" + BoolToText(marketWeakBlocked) +
           " finalAllowed=" + finalAllowed +
           " blockReason=" + blockReason);
}

ENUM_REAL_EXECUTION_STATE DetectRealExecutionState()
{
   if(!UseRealExecutionEngine)
      return REAL_EXEC_DISABLED;

   string reason = "";
   bool reuseV4Plan = HasReusableV4RealExecutionPlan();
   if(reuseV4Plan)
   {
      AuditV4RealExecutionGate("DETECT_STATE_REUSE_V4_PLAN", "pending", "REUSING_ALREADY_BUILT_V4_PLAN");
      AuditV4BuyPathTrace("DETECT_STATE_REUSE_V4_PLAN", "pending", "REUSING_ALREADY_BUILT_V4_PLAN");
   }
   else if(!BuildRealExecutionOrderData(reason))
   {
      g_realExecutionBlockReason = reason;
      return REAL_EXEC_BLOCKED;
   }
   bool detectSimulationOnlyEffective = RealExecutionSimulationOnly;
   if(ForceFunctionalExecutionTest)
      detectSimulationOnlyEffective = false;
   if(detectSimulationOnlyEffective)
   {
      g_realExecutionReason = "REAL EXECUTION SIMULATION ONLY - NO ORDER SENT";
      return REAL_EXEC_SIMULATION_ONLY;
   }
   if(!IsRealExecutionMasterAllowed(reason))
   {
      g_realExecutionBlockReason = reason;
      return REAL_EXEC_BLOCKED;
   }
   if(UseV4AsPrimaryDecisionEngine)
   {
      if(!CanV4ExecuteRealOrder(reason))
      {
         g_realExecutionBlockReason = reason;
         return (IsAbsoluteRiskBlockV4(reason) ? REAL_EXEC_RISK_BLOCK : REAL_EXEC_BLOCKED);
      }
      return REAL_EXEC_READY;
   }
   if(!IsRealExecutionPreviousGatesApproved(reason))
   {
      g_realExecutionBlockReason = reason;
      return REAL_EXEC_BLOCKED;
   }
   if(!IsRealExecutionDirectionAllowed(reason))
   {
      g_realExecutionBlockReason = reason;
      return REAL_EXEC_BLOCKED;
   }
   if(!IsRealExecutionRiskApproved(reason))
   {
      g_realExecutionBlockReason = reason;
      return REAL_EXEC_RISK_BLOCK;
   }
   if(!IsRealExecutionDuplicateSafe(reason))
   {
      g_realExecutionBlockReason = reason;
      return REAL_EXEC_DUPLICATE_BLOCK;
   }
   if(!IsRealExecutionEnvironmentSafe(reason))
   {
      g_realExecutionBlockReason = reason;
      return REAL_EXEC_BLOCKED;
   }
   if(!IsRealExecutionBrokerSafe(reason))
   {
      g_realExecutionBrokerReason = reason;
      return REAL_EXEC_BROKER_BLOCK;
   }
   return REAL_EXEC_READY;
}

bool CanExecuteRealOrder(string &reason)
{
   reason = "";

   if(!AllowLiveTrading)
   {
      reason = "REAL EXECUTION BLOCKED: AllowLiveTrading=false";
      return false;
   }
   if(!EnableRealExecution)
   {
      reason = "REAL EXECUTION BLOCKED: EnableRealExecution=false";
      return false;
   }
   bool canSimulationOnlyEffective = RealExecutionSimulationOnly;
   if(ForceFunctionalExecutionTest)
      canSimulationOnlyEffective = false;
   if(canSimulationOnlyEffective)
   {
      reason = "REAL EXECUTION BLOCKED: RealExecutionSimulationOnly=true";
      return false;
   }
   if(UseDiagnosticMode && !IsFunctionalExecutionOverrideActive() && !AllowRealExecutionInDiagnosticMode)
   {
      reason = "REAL EXECUTION BLOCKED: UseDiagnosticMode=true";
      return false;
   }

   bool reuseV4Plan = HasReusableV4RealExecutionPlan();
   if(reuseV4Plan)
   {
      AuditV4RealExecutionGate("CAN_EXECUTE_REUSE_V4_PLAN", "pending", "REUSING_ALREADY_BUILT_V4_PLAN");
      AuditV4BuyPathTrace("CAN_EXECUTE_REUSE_V4_PLAN", "pending", "REUSING_ALREADY_BUILT_V4_PLAN");
   }
   else if(!BuildRealExecutionOrderData(reason))
      return false;
   if(!IsRealExecutionMasterAllowed(reason))
      return false;

   if(UseV4AsPrimaryDecisionEngine)
   {
      if(!CanV4ExecuteRealOrder(reason))
         return false;
      reason = "REAL EXECUTION APPROVED BY V4 FINAL DECISION";
      return true;
   }

   if(IsFunctionalExecutionOverrideActive())
   {
      string cycleReason = "";
      if(!CanStartNewAggressiveCycle(cycleReason))
      {
         reason = "[AGGRESSIVE_CYCLE][BLOCK_REASON] " + cycleReason;
         g_fix3LastBlockReason = reason;
         return false;
      }
      string safetyReason = "";
      if(!IsFunctionalSafetyApproved(ForceFunctionalFixedLot, safetyReason))
      {
         reason = safetyReason;
         return false;
      }
      if(!HasValidRealExecutionDirection())
      {
         reason = "[FUNCTIONAL_SAFETY] BLOCKED: NO VALID EA DIRECTION";
         return false;
      }
      if(!IsRealExecutionDirectionAllowed(reason))
         return false;
      if(!IsRealExecutionDuplicateSafe(reason))
         return false;
      if(!IsRealExecutionEnvironmentSafe(reason))
         return false;
      if(!IsRealExecutionBrokerSafe(reason))
         return false;
      reason = "REAL EXECUTION APPROVED: FUNCTIONAL OVERRIDE ACTIVE";
      AuditRealExecution("[FUNCTIONAL_OVERRIDE] REAL EXECUTION APPROVED");
      return true;
   }

   if(!IsRealExecutionPreviousGatesApproved(reason)) return false;
   if(!IsRealExecutionDirectionAllowed(reason)) return false;
   if(!IsRealExecutionRiskApproved(reason)) return false;
   if(!IsRealExecutionDuplicateSafe(reason)) return false;
   if(!IsRealExecutionEnvironmentSafe(reason)) return false;
   if(!IsRealExecutionBrokerSafe(reason)) return false;
   reason = "REAL EXECUTION APPROVED";
   return true;
}

bool ExecuteRealOrder(string &reason)
{
   reason = "";
   bool execSimulationOnlyEffective = RealExecutionSimulationOnly;
   if(ForceFunctionalExecutionTest)
      execSimulationOnlyEffective = false;
   if(execSimulationOnlyEffective)
   {
      reason = "REAL EXECUTION SIMULATION ONLY - NO ORDER SENT";
      return false;
   }
   datetime now = TimeCurrent();
   if(g_lastRealExecutionAttemptTime == now)
   {
      reason = "REAL EXECUTION ATTEMPT ALREADY DONE THIS TICK";
      return false;
   }
   if(!ForceFunctionalAggressiveEntryCycle && MaxRealExecutionAttemptsPerSignal > 0 && g_realExecutionAttemptCount >= MaxRealExecutionAttemptsPerSignal)
   {
      reason = "MAX REAL EXECUTION ATTEMPTS REACHED";
      return false;
   }
   if(!CanExecuteRealOrder(reason))
      return false;

   if(IsFunctionalExecutionOverrideActive())
   {
      double lot = FunctionalNormalizeLot(ForceFunctionalFixedLot);
      if(lot <= 0.0 || lot - ForceFunctionalFixedLot > 0.000001)
      {
         reason = "[FUNCTIONAL_SAFETY] BLOCKED: INVALID LOT";
         return false;
      }
      if(CountAllMagicPositions() >= ForceFunctionalMaxTotalPositions)
      {
         reason = "[FUNCTIONAL_SAFETY] BLOCKED: MAX TOTAL POSITIONS";
         return false;
      }
      if(!HasValidRealExecutionDirection())
      {
         reason = "[FUNCTIONAL_SAFETY] BLOCKED: NO VALID EA DIRECTION";
         return false;
      }
      double sl = g_realExecutionSL;
      double tp = g_realExecutionTP;
      if(!BuildOrValidateFunctionalSLTP(g_realExecution.direction, g_realExecutionEntryPrice, sl, tp))
      {
         reason = "[FUNCTIONAL_SAFETY] BLOCKED: INVALID SLTP";
         return false;
      }
      g_realExecutionLot = lot;
      g_realExecutionSL = sl;
      g_realExecutionTP = tp;
   }

   g_lastRealExecutionAttemptTime = now;
   g_realExecutionAttemptCount++;
   g_realExecution.lastAttemptTime = now;
   g_realExecution.attemptCount = g_realExecutionAttemptCount;

   trade.SetExpertMagicNumber((ulong)MagicNumber);
   trade.SetDeviationInPoints(RealExecutionDeviationPoints);

   // V10 VPS FIX: detectar filling mode suportado pelo broker automaticamente
   // FTMO VPS pode exigir IOC ou RETURN em vez de FOK
   ENUM_ORDER_TYPE_FILLING filling = ORDER_FILLING_FOK;
   uint fillingModes = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((fillingModes & SYMBOL_FILLING_IOC) != 0)  filling = ORDER_FILLING_IOC;
   if((fillingModes & SYMBOL_FILLING_FOK) != 0)  filling = ORDER_FILLING_FOK;
   trade.SetTypeFilling(filling);

   bool sent = false;
   double realSLToSend = g_realExecutionSL;
   double realTPToSend = g_realExecutionTP;
   if(UseStage15SmartDynamicExitEngine && Stage15_DisableFixedServerTP)
      realTPToSend = 0.0;
   if(g_realExecution.direction == REAL_EXEC_DIR_BUY)
   {
      AuditV4("[V4_BUY_ORDER_READY] direction=BUY orderType=ORDER_TYPE_BUY lot=" + DoubleToString(g_realExecutionLot,2) +
              " sl=" + DoubleToString(realSLToSend,_Digits) +
              " tp=" + DoubleToString(realTPToSend,_Digits) +
              " readyForTradeBuy=true");
      sent = trade.Buy(g_realExecutionLot, _Symbol, 0.0, realSLToSend, realTPToSend, RealExecutionComment);
   }
   else if(g_realExecution.direction == REAL_EXEC_DIR_SELL)
   {
      if(g_v4AggressiveBuyLatchActive)
         AuditV4("[V4_SELL_SEND_WITH_BUY_LATCH_ACTIVE] lot=" + DoubleToString(g_realExecutionLot,2) +
                 " action=SELL_SEND_SHOULD_NOT_HAPPEN_IF_BUY_LATCH_FRESH");
      sent = trade.Sell(g_realExecutionLot, _Symbol, 0.0, realSLToSend, realTPToSend, RealExecutionComment);
   }
   else
   {
      reason = "NO REAL EXECUTION DIRECTION";
      return false;
   }

   ulong resultOrder = trade.ResultOrder();
   ulong resultDeal = trade.ResultDeal();
   string resultText = trade.ResultRetcodeDescription();

   if(sent)
   {
      // STAGE 13 FINAL FULL: register approved role after successful real order.
      if(UseStage13FinalAuthorityManager)
      {
         Stage12_MarkEntryExecuted(g_stage12LastRole);
         Stage13_AuditDecision("ORDER_EXECUTED", "RealExecution", reason);
      }
      g_realOrderSent = true;
      g_realBuySent = (g_realExecution.direction == REAL_EXEC_DIR_BUY);
      g_realSellSent = (g_realExecution.direction == REAL_EXEC_DIR_SELL);
      g_realExecutionError = false;
      g_lastRealExecutionTime = now;
      g_lastRealExecutionBarTime = iTime(_Symbol, _Period, 0);
      g_lastRealOrderTicket = resultOrder;
      g_lastRealDealTicket = resultDeal;
      g_realExecution.orderSent = true;
      g_realExecution.buySent = g_realBuySent;
      g_realExecution.sellSent = g_realSellSent;
      g_realExecution.lastExecutionTime = g_lastRealExecutionTime;
      g_realExecution.lastExecutionBarTime = g_lastRealExecutionBarTime;
      g_realExecution.lastOrderTicket = resultOrder;
      g_realExecution.lastDealTicket = resultDeal;
      g_realExecution.state = (g_realBuySent ? REAL_EXEC_BUY_SENT : REAL_EXEC_SELL_SENT);
      reason = (g_realBuySent ? "REAL BUY SENT" : "REAL SELL SENT");
      if(g_realBuySent)
         V4ClearAggressiveBuyLatch("BUY_ORDER_SENT_SUCCESS");
      else if(g_v4AggressiveBuyLatchActive)
         AuditV4("[V4_BUY_LATCH_WARNING] sellSentWhileBuyLatchActive=true reason=CHECK_GATE_ORDER_FLOW");
      // V5.1J FORENSIC FIX:
      // Consume the V4 direct plan immediately after an order is sent so the next
      // signal cannot reuse stale SELL/BUY order data. The next entry must rebuild
      // direction from SelectAggressiveDirectionV4() again.
      if(UseV4AsPrimaryDecisionEngine && UseV4DirectPlanBuilder)
      {
         ENUM_ORDER_TYPE executedOrderType = V4RealDirectionToOrderType(g_realExecution.direction);
         g_fix3OrderPlanReady = false;
         g_fix3LastOrderPlanDirection = (ENUM_ORDER_TYPE)-1;
         g_fix3LastOrderPlanBuildTime = 0;
         g_fix3LastOrderPlanBarTime = 0;
         g_fix3LastOrderPlanReason = "ORDER_SENT_PLAN_CONSUMED_REBUILD_NEXT_SIGNAL";
         AuditV4("[V4_PLAN_CONSUMED] executedDirection=" + V4RealDirectionTextSafe(g_realExecution.direction) +
                 " orderType=" + V4OrderTypeToPlanTextSafe(executedOrderType) +
                 " ticket=" + UlongToText(resultOrder) +
                 " planReady=false");
         AuditV4("[V4_STALE_PLAN_FIX] action=CONSUME_PLAN_AFTER_ORDER_SENT nextSignalMustRebuild=true sentDirection=" + V4RealDirectionTextSafe(g_realExecution.direction));
      }

      V10_PostOrderCapture(resultDeal, resultOrder, "ExecuteRealOrder");

      if(IsFunctionalExecutionOverrideActive())
      {
         g_fix3TradesToday++;
         g_fix3LastTradeTime = now;
         g_fix3LastCycleTime = now;
         AuditRealExecution("[REAL_EXECUTION] FUNCTIONAL ORDER SENT");
         AuditReentryLayer("[LAYER_SYNC] AFTER REAL ORDER SENT - SYNCING MAIN POSITION");
         string syncMainReason = "";
         bool mainSynced = SyncMainPositionForLayer(syncMainReason);
         if(!mainSynced)
            AuditReentryLayer("[LAYER_SYNC][BLOCK_REASON] " + syncMainReason);
         AuditReentryLayer("[LAYER_SYNC] MAIN POSITION FOUND=" + BoolToText(g_reentryLayer.hasMainPosition) + " ticket=" + UlongToText(g_reentryLayer.mainPositionTicket) + " reason=" + syncMainReason);
         reason = "[REAL_EXECUTION] FUNCTIONAL ORDER SENT";
      }
      return true;
   }

   g_realExecutionError = true;
   g_lastRealExecutionErrorText = resultText;
   g_realExecution.lastErrorText = resultText;
   g_realExecution.error = true;
   g_realExecution.state = REAL_EXEC_ERROR;
   reason = "REAL EXECUTION ERROR: " + resultText;
   return false;
}

string RealExecutionStateToText(ENUM_REAL_EXECUTION_STATE state)
{
   switch(state)
   {
      case REAL_EXEC_DISABLED: return "REAL_EXEC_DISABLED";
      case REAL_EXEC_SIMULATION_ONLY: return "REAL_EXEC_SIMULATION_ONLY";
      case REAL_EXEC_WAIT: return "REAL_EXEC_WAIT";
      case REAL_EXEC_READY: return "REAL_EXEC_READY";
      case REAL_EXEC_BUY_SENT: return "REAL_EXEC_BUY_SENT";
      case REAL_EXEC_SELL_SENT: return "REAL_EXEC_SELL_SENT";
      case REAL_EXEC_BLOCKED: return "REAL_EXEC_BLOCKED";
      case REAL_EXEC_RISK_BLOCK: return "REAL_EXEC_RISK_BLOCK";
      case REAL_EXEC_DUPLICATE_BLOCK: return "REAL_EXEC_DUPLICATE_BLOCK";
      case REAL_EXEC_BROKER_BLOCK: return "REAL_EXEC_BROKER_BLOCK";
      case REAL_EXEC_ERROR: return "REAL_EXEC_ERROR";
      default: return "REAL_EXEC_UNKNOWN";
   }
}

string RealExecutionDirectionToText(ENUM_REAL_EXECUTION_DIRECTION direction)
{
   switch(direction)
   {
      case REAL_EXEC_DIR_BUY: return "BUY";
      case REAL_EXEC_DIR_SELL: return "SELL";
      default: return "NONE";
   }
}

string RealExecutionStatusToText()
{
   if(!UseRealExecutionEngine) return "REAL EXECUTION ENGINE DISABLED";
   if(RealExecutionSimulationOnly) return "SIMULATION ONLY";
   switch(g_realExecution.state)
   {
      case REAL_EXEC_READY: return "REAL EXECUTION READY";
      case REAL_EXEC_BUY_SENT: return "REAL BUY SENT";
      case REAL_EXEC_SELL_SENT: return "REAL SELL SENT";
      case REAL_EXEC_BLOCKED: return "REAL EXECUTION BLOCKED";
      case REAL_EXEC_RISK_BLOCK: return "REAL EXECUTION RISK BLOCK";
      case REAL_EXEC_DUPLICATE_BLOCK: return "REAL EXECUTION DUPLICATE BLOCK";
      case REAL_EXEC_BROKER_BLOCK: return "REAL EXECUTION BROKER BLOCK";
      case REAL_EXEC_ERROR: return "REAL EXECUTION ERROR";
      default: return "REAL EXECUTION WAITING";
   }
}

bool CanPrintRealExecutionLog(string reason)
{
   if(!PrintRealExecutionDiagnostics) return false;
   datetime now = TimeCurrent();
   if(reason != g_lastRealExecutionLoggedReason || (now - g_lastRealExecutionLogTime) >= MinSecondsBetweenRealExecutionLogs)
   {
      g_lastRealExecutionLoggedReason = reason;
      g_lastRealExecutionLogTime = now;
      return true;
   }
   return false;
}

void AuditRealExecution(string message)
{
   if(CanPrintRealExecutionLog(message))
      AuditLog("REAL_EXECUTION", message);
}

void UpdateRealExecutionEngine()
{
   if(!UseRealExecutionEngine)
   {
      ResetRealExecutionDisabled();
      return;
   }

   g_realExecution.lastUpdateTime = TimeCurrent();

   // V5.1K: a new tick must start with a fresh V4 direct plan.
   // After this fresh plan is built, later state/gate/order-send checks in the same tick may reuse it.
   if(UseV4AsPrimaryDecisionEngine && UseV4DirectPlanBuilder)
      V4InvalidateCurrentPlan("NEW_TICK_REBUILD_REQUIRED", (ENUM_ORDER_TYPE)-1);

   string buildReason = "";
   bool buildOK = BuildRealExecutionOrderData(buildReason);

   if(!buildOK)
   {
      g_realExecution.state = REAL_EXEC_BLOCKED;
      g_realExecutionBlockReason = buildReason;
   }
   else
      g_realExecution.state = DetectRealExecutionState();

   bool updateSimulationOnlyEffective = RealExecutionSimulationOnly;
   if(ForceFunctionalExecutionTest)
      updateSimulationOnlyEffective = false;
   g_realExecutionSimulationOnly = (g_realExecution.state == REAL_EXEC_SIMULATION_ONLY || updateSimulationOnlyEffective);
   g_realExecutionReady = (g_realExecution.state == REAL_EXEC_READY || g_realExecution.state == REAL_EXEC_SIMULATION_ONLY);
   g_realExecutionBlocked = (g_realExecution.state == REAL_EXEC_BLOCKED);
   g_realExecutionRiskBlock = (g_realExecution.state == REAL_EXEC_RISK_BLOCK);
   g_realExecutionDuplicateBlock = (g_realExecution.state == REAL_EXEC_DUPLICATE_BLOCK);
   g_realExecutionBrokerBlock = (g_realExecution.state == REAL_EXEC_BROKER_BLOCK);
   g_realExecutionError = (g_realExecution.state == REAL_EXEC_ERROR || g_realExecutionError);

   g_realExecution.ready = g_realExecutionReady;
   g_realExecution.blocked = g_realExecutionBlocked;
   g_realExecution.simulationOnly = g_realExecutionSimulationOnly;
   g_realExecution.riskBlock = g_realExecutionRiskBlock;
   g_realExecution.duplicateBlock = g_realExecutionDuplicateBlock;
   g_realExecution.brokerBlock = g_realExecutionBrokerBlock;
   g_realExecution.error = g_realExecutionError;

   g_realExecutionStatus = RealExecutionStatusToText();
   g_realExecutionReason = RealExecutionStateToText(g_realExecution.state);
   g_realExecutionDirectionText = RealExecutionDirectionToText(g_realExecution.direction);
   g_realExecution.statusText = g_realExecutionStatus;
   g_realExecution.reason = g_realExecutionReason;
   g_realExecution.blockReason = g_realExecutionBlockReason;
   g_realExecution.brokerReason = g_realExecutionBrokerReason;

   AuditRealExecution("REAL EXECUTION UPDATED");
   AuditRealExecution(g_realExecutionStatus);
   if(g_realExecutionBlocked || g_realExecutionRiskBlock || g_realExecutionDuplicateBlock || g_realExecutionBrokerBlock)
   {
      string detailedBlock = (g_realExecutionBlockReason != "" && g_realExecutionBlockReason != "NONE" ? g_realExecutionBlockReason : g_realExecutionBrokerReason);
      if(detailedBlock == "" || detailedBlock == "NONE")
         detailedBlock = g_realExecutionReason;
      g_fix3LastBlockReason = detailedBlock;
      AuditRealExecution("[REAL_EXECUTION][BLOCK_REASON] " + detailedBlock);
   }

   if(updateSimulationOnlyEffective)
   {
      AuditRealExecution("REAL EXECUTION SIMULATION ONLY - NO ORDER SENT");
      return;
   }
   if(!EnableRealExecution)
   {
      AuditRealExecution("ENABLE REAL EXECUTION FALSE");
      return;
   }
   if(!AllowLiveTrading || !g_liveTradingAllowed)
   {
      AuditRealExecution("ALLOW LIVE TRADING FALSE");
      return;
   }
   if(UseDiagnosticMode && !AllowRealExecutionInDiagnosticMode && !IsFunctionalExecutionOverrideActive())
   {
      AuditRealExecution("DIAGNOSTIC MODE BLOCK");
      return;
   }
   if(IsFunctionalExecutionOverrideActive())
      AuditRealExecution("[FUNCTIONAL_OVERRIDE] ACTIVE");

   if(g_realExecution.state == REAL_EXEC_READY)
   {
      if(UseV4AsPrimaryDecisionEngine)
      {
         string v4ExecReason = "";
         if(!CanV4ExecuteRealOrder(v4ExecReason))
         {
            if(IsForbiddenLegacyFinalReasonV4(v4ExecReason))
            {
               AuditV4("[WARNING] ENTRY_WARNING_FINAL -> PENALTY_ONLY_CONTINUE reason=" + NormalizeLegacyReasonV4(v4ExecReason));
               v4ExecReason = "V4_ENTRY_ALLOWED_PENALTY_ONLY";
            }
            else
            {
               g_fix3LastBlockReason = v4ExecReason;
               g_realExecutionBlockReason = v4ExecReason;
               AuditRealExecution("[REAL_EXECUTION][V4] ENTRY_WARNING_FINAL reason=" + v4ExecReason);
               return;
            }
         }
         AuditRealExecution("[REAL_EXECUTION][V4] ENTRY_ALLOWED_FORWARDING_TO_ORDER_SEND");
      }
      else
      {
         string v32EntryReason = "";
         if(!IsV32RealEntryAllowed(g_realExecution.direction, v32EntryReason))
         {
            g_fix3LastBlockReason = "V3.2 ENTRY BLOCK: " + v32EntryReason;
            g_realExecutionBlockReason = g_fix3LastBlockReason;
            AuditRealExecution("[REAL_EXECUTION][BLOCK_REASON] " + g_fix3LastBlockReason);
            AuditV32("[V3_2_MASTER][BLOCK_REASON] " + v32EntryReason);
            return;
         }
      }

      string execReason = "";
      if(ExecuteRealOrder(execReason))
      {
         g_v32LastNewCycleTime = TimeCurrent();
         AuditRealExecution(execReason);
         if(UseV4AsPrimaryDecisionEngine)
            AuditRealExecution("[REAL_EXECUTION][V4] ORDER_SEND_OK " + execReason);
      }
      else
      {
         g_fix3LastBlockReason = execReason;
         if(UseV4AsPrimaryDecisionEngine)
            AuditRealExecution("[REAL_EXECUTION][V4] ORDER_SEND_FAILED " + execReason);
         AuditRealExecution("[REAL_EXECUTION][BLOCK_REASON] " + execReason);
      }
   }
}

bool CanStartRealExecution()
{
   string reason = "";
   return CanExecuteRealOrder(reason);
}

bool HasRealOrderBeenSent()
{
   return g_realOrderSent;
}

bool WasRealBuySent()
{
   return g_realBuySent;
}

bool WasRealSellSent()
{
   return g_realSellSent;
}

double GetRealExecutionLot()
{
   return g_realExecutionLot;
}

string GetRealExecutionReason()
{
   return g_realExecutionReason;
}

//+------------------------------------------------------------------+
//| ETAPA 11 FIX3 - Position Manager Visual State Hold                |
//+------------------------------------------------------------------+
void ClearPositionManagerStateHold()
{
   g_positionManagerStateHoldUntil = 0;
   g_positionManagerHoldState = POS_MANAGER_MONITORING;
   g_positionManagerHoldReason = "NONE";
}

void StartPositionManagerStateHold(ENUM_POSITION_MANAGER_STATE holdState, string reason)
{
   if(!UsePositionManagerStateHold)
      return;

   if(!g_positionManager.hasPosition || !g_managedPositionFound || g_managedPositionTicket == 0)
      return;

   int holdSeconds = PositionManagerStateHoldSeconds;
   if(holdSeconds < 1)
      holdSeconds = 1;

   g_positionManagerHoldState = holdState;
   g_positionManagerHoldReason = reason;
   g_positionManagerStateHoldUntil = TimeCurrent() + holdSeconds;

   g_positionManager.state = holdState;
   g_positionManager.reason = reason;
   g_positionManager.actionReason = reason;

   if(holdState == POS_MANAGER_BE_APPLIED)
   {
      g_positionManager.breakEvenApplied = true;
      g_breakEvenApplied = true;
      g_positionManagerStatus = "BE_APPLIED";
   }

   if(holdState == POS_MANAGER_TRAILING_APPLIED)
   {
      g_positionManager.trailingApplied = true;
      g_trailingApplied = true;
      g_positionManagerStatus = "TRAILING_APPLIED";
   }
}

bool ApplyPositionManagerStateHold()
{
   if(!UsePositionManagerStateHold)
      return false;

   if(g_positionManagerStateHoldUntil <= 0)
      return false;

   if(TimeCurrent() > g_positionManagerStateHoldUntil)
      return false;

   if(!g_positionManager.hasPosition || !g_managedPositionFound || g_managedPositionTicket == 0)
      return false;

   g_positionManager.state = g_positionManagerHoldState;
   g_positionManager.reason = g_positionManagerHoldReason;
   g_positionManager.actionReason = g_positionManagerHoldReason;

   if(g_positionManagerHoldState == POS_MANAGER_BE_APPLIED)
   {
      g_positionManager.breakEvenApplied = true;
      g_breakEvenApplied = true;
      g_positionManagerStatus = "BE_APPLIED";
   }

   if(g_positionManagerHoldState == POS_MANAGER_TRAILING_APPLIED)
   {
      g_positionManager.trailingApplied = true;
      g_trailingApplied = true;
      g_positionManagerStatus = "TRAILING_APPLIED";
   }

   return true;
}


//+------------------------------------------------------------------+
//| FIX3 V3.1 - Smart Exit Real Engine State                         |
//+------------------------------------------------------------------+
struct SSmartExitTicketState
{
   ulong    ticket;
   double   peakProfitMoney;
   double   peakProfitPoints;
   bool     breakEvenApplied;
   int      modifyRetries;
   datetime lastModifyTime;
   datetime lastCloseAttemptTime;
   string   lastExitAction;
   string   lastBlockReason;
};

SSmartExitTicketState g_smartExitStates[];
double   g_basketPeakProfit          = 0.0;
datetime g_lastBasketCloseTime       = 0;
string   g_lastBasketCloseReason     = "NONE";
double   g_basketProfit              = 0.0;
string   g_lastSmartExitAction       = "NONE";
string   g_lastSmartExitBlockReason  = "NONE";
ulong    g_lastModifiedTicket        = 0;
ulong    g_lastClosedTicket          = 0;
string   g_lastEnvironmentStatus     = "WAITING";
string   g_lastEnvironmentBlock      = "NONE";

//+------------------------------------------------------------------+
//| ETAPA 11 - Position Manager / Smart Position Control             |
//+------------------------------------------------------------------+
void ResetManagedPositionFields()
{
   ClearPositionManagerStateHold();

   g_positionManager.state = POS_MANAGER_NO_POSITION;
   g_positionManager.direction = MANAGED_POS_NONE;

   g_positionManager.hasPosition = false;
   g_positionManager.monitoring = false;
   g_positionManager.simulationOnly = PositionManagerSimulationOnly;

   g_positionManager.breakEvenReady = false;
   g_positionManager.breakEvenApplied = false;
   g_positionManager.trailingReady = false;
   g_positionManager.trailingApplied = false;
   g_positionManager.profitProtected = false;
   g_positionManager.emergencyBlock = false;
   g_positionManager.emergencyClosed = false;
   g_positionManager.error = false;

   g_positionManager.positionTicket = 0;
   g_positionManager.positionType = -1;
   g_positionManager.positionMagic = 0;

   g_positionManager.openTime = 0;
   g_positionManager.lastUpdateTime = TimeCurrent();
   g_positionManager.lastModifyTime = 0;
   g_positionManager.lastCloseTime = 0;

   g_positionManager.volume = 0.0;
   g_positionManager.openPrice = 0.0;
   g_positionManager.currentPrice = 0.0;
   g_positionManager.currentSL = 0.0;
   g_positionManager.currentTP = 0.0;
   g_positionManager.proposedSL = 0.0;
   g_positionManager.proposedTP = 0.0;

   g_positionManager.profitMoney = 0.0;
   g_positionManager.swapMoney = 0.0;
   g_positionManager.commissionMoney = 0.0;
   g_positionManager.netProfitMoney = 0.0;

   g_positionManager.profitPoints = 0.0;
   g_positionManager.adversePoints = 0.0;
   g_positionManager.favorablePoints = 0.0;
   g_positionManager.maxProfitMoney = 0.0;
   g_positionManager.maxAdverseMoney = 0.0;
   g_positionManager.maxFavorablePoints = 0.0;
   g_positionManager.maxAdversePoints = 0.0;

   g_positionManager.distanceToSLPoints = 0.0;
   g_positionManager.distanceToTPPoints = 0.0;
   g_positionManager.riskMoneyAtSL = 0.0;
   g_positionManager.rewardMoneyAtTP = 0.0;

   g_positionManager.statusText = "NO_POSITION";
   g_positionManager.reason = "NO MANAGED POSITION FOUND";
   g_positionManager.blockReason = "NONE";
   g_positionManager.actionReason = "NONE";
   g_positionManager.lastErrorText = "NONE";

   g_positionManagerActive = UsePositionManager;
   g_positionManagerSimulationOnly = PositionManagerSimulationOnly;
   g_managedPositionFound = false;

   g_breakEvenReady = false;
   g_breakEvenApplied = false;
   g_trailingReady = false;
   g_trailingApplied = false;
   g_profitProtectionActive = false;
   g_positionEmergencyBlock = false;
   g_positionEmergencyClosed = false;
   g_positionManagerError = false;

   g_managedPositionTicket = 0;

   g_managedPositionVolume = 0.0;
   g_managedPositionOpenPrice = 0.0;
   g_managedPositionCurrentPrice = 0.0;
   g_managedPositionSL = 0.0;
   g_managedPositionTP = 0.0;
   g_managedPositionProfitMoney = 0.0;
   g_managedPositionProfitPoints = 0.0;

   g_positionProposedSL = 0.0;
   g_positionProposedTP = 0.0;
   g_positionMaxProfitMoney = 0.0;
   g_positionMaxAdverseMoney = 0.0;

   g_positionManagerStatus = "NO_POSITION";
   g_positionManagerReason = "NO MANAGED POSITION FOUND";
   g_positionManagerBlockReason = "NONE";
   g_positionManagerActionReason = "NONE";
   g_positionManagerLastErrorText = "NONE";
}

void InitializePositionManagerData()
{
   ResetManagedPositionFields();

   g_positionManager.state = POS_MANAGER_NO_POSITION;
   g_positionManager.direction = MANAGED_POS_NONE;
   g_positionManager.positionType = -1;
   g_positionManager.statusText = "WAITING";
   g_positionManager.reason = "INITIALIZED";
   g_positionManager.blockReason = "NONE";
   g_positionManager.actionReason = "NONE";
   g_positionManager.lastErrorText = "NONE";

   g_positionManagerActive = false;
   g_positionManagerSimulationOnly = false;

   g_lastPositionManagerUpdateTime = 0;
   g_lastPositionModifyTime = 0;
   g_lastPositionCloseTime = 0;
   g_lastPositionLogTime = 0;

   g_positionManagerStatus = "WAITING";
   g_positionManagerReason = "INITIALIZED";
   g_positionManagerBlockReason = "NONE";
   g_positionManagerActionReason = "NONE";
   g_lastPositionManagerLoggedReason = "";
   g_positionManagerLastErrorText = "NONE";
}

void ResetPositionManagerDisabled()
{
   ResetManagedPositionFields();
   g_positionManager.state = POS_MANAGER_DISABLED;
   g_positionManager.direction = MANAGED_POS_NONE;
   g_positionManager.positionType = -1;
   g_positionManager.hasPosition = false;
   g_positionManager.monitoring = false;
   g_positionManager.simulationOnly = false;
   g_positionManager.statusText = "POSITION MANAGER DISABLED";
   g_positionManager.reason = "DISABLED";
   g_positionManager.blockReason = "NONE";
   g_positionManager.actionReason = "NONE";
   g_positionManager.lastErrorText = "NONE";

   g_positionManagerActive = false;
   g_positionManagerSimulationOnly = false;
   g_positionManagerStatus = "POSITION MANAGER DISABLED";
   g_positionManagerReason = "DISABLED";
   g_positionManagerBlockReason = "NONE";
   g_positionManagerActionReason = "NONE";
   g_positionManagerLastErrorText = "NONE";
}

bool SelectManagedPositionByTicket(ulong ticket)
{
   if(ticket == 0)
      return false;
   return PositionSelectByTicket(ticket);
}

bool FindManagedPosition()
{
   g_managedPositionTicket = 0;
   g_managedPositionFound = false;

   int found = 0;
   ulong firstTicket = 0;
   long firstMagic = 0;
   long firstType = -1;

   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      string sym = PositionGetString(POSITION_SYMBOL);
      long magic = PositionGetInteger(POSITION_MAGIC);

      if(ManageOnlyCurrentSymbol && sym != _Symbol)
         continue;

      if(ManageOnlyMagicNumber && magic != MagicNumber)
         continue;

      found++;
      if(firstTicket == 0)
      {
         firstTicket = ticket;
         firstMagic = magic;
         firstType = PositionGetInteger(POSITION_TYPE);
      }
   }

   if(found > 1 && ManageOnlyOnePosition)
      AuditPositionManager("MULTIPLE POSITIONS FOUND - STAGE 11 MANAGES FIRST ONLY");

   if(firstTicket > 0)
   {
      g_managedPositionTicket = firstTicket;
      g_managedPositionFound = true;

      g_positionManager.hasPosition = true;
      g_positionManager.positionTicket = firstTicket;
      g_positionManager.positionMagic = firstMagic;
      g_positionManager.positionType = firstType;
      g_positionManager.state = POS_MANAGER_MONITORING;
      g_positionManager.statusText = "POSITION_FOUND";
      g_positionManager.reason = "MANAGED POSITION FOUND";
      g_positionManager.blockReason = "NONE";
      g_positionManager.lastErrorText = "NONE";
      return true;
   }

   ResetManagedPositionFields();
   return false;
}

ENUM_MANAGED_POSITION_DIRECTION DetectManagedPositionDirection()
{
   if(!g_positionManager.hasPosition || !g_managedPositionFound || g_managedPositionTicket == 0 || g_positionManager.positionType < 0)
      return MANAGED_POS_NONE;

   if(g_positionManager.positionType == POSITION_TYPE_BUY)
      return MANAGED_POS_BUY;

   if(g_positionManager.positionType == POSITION_TYPE_SELL)
      return MANAGED_POS_SELL;

   return MANAGED_POS_NONE;
}

double GetManagedPositionCurrentPrice()
{
   if(!g_positionManager.hasPosition || !g_managedPositionFound || g_managedPositionTicket == 0 || _Point <= 0.0)
      return 0.0;

   if(g_positionManager.direction == MANAGED_POS_BUY)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid > 0.0)
         return bid;
   }

   if(g_positionManager.direction == MANAGED_POS_SELL)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask > 0.0)
         return ask;
   }

   return PositionGetDouble(POSITION_PRICE_CURRENT);
}

double CalculatePositionProfitPoints()
{
   if(!g_positionManager.hasPosition || !g_managedPositionFound || g_managedPositionTicket == 0 || _Point <= 0.0)
      return 0.0;

   if(g_positionManager.direction == MANAGED_POS_BUY)
      return (g_positionManager.currentPrice - g_positionManager.openPrice) / _Point;

   if(g_positionManager.direction == MANAGED_POS_SELL)
      return (g_positionManager.openPrice - g_positionManager.currentPrice) / _Point;

   return 0.0;
}

double CalculatePositionAdversePoints()
{
   if(!g_positionManager.hasPosition || !g_managedPositionFound || g_managedPositionTicket == 0)
      return 0.0;

   double points = CalculatePositionProfitPoints();
   if(points < 0.0)
      return MathAbs(points);
   return 0.0;
}

double CalculateDistanceToSLPoints()
{
   if(!g_positionManager.hasPosition || !g_managedPositionFound || g_managedPositionTicket == 0 || _Point <= 0.0 || g_positionManager.currentSL <= 0.0)
      return 0.0;

   if(g_positionManager.direction == MANAGED_POS_BUY)
      return MathMax(0.0, (g_positionManager.currentPrice - g_positionManager.currentSL) / _Point);

   if(g_positionManager.direction == MANAGED_POS_SELL)
      return MathMax(0.0, (g_positionManager.currentSL - g_positionManager.currentPrice) / _Point);

   return 0.0;
}

double CalculateDistanceToTPPoints()
{
   if(!g_positionManager.hasPosition || !g_managedPositionFound || g_managedPositionTicket == 0 || _Point <= 0.0 || g_positionManager.currentTP <= 0.0)
      return 0.0;

   if(g_positionManager.direction == MANAGED_POS_BUY)
      return MathMax(0.0, (g_positionManager.currentTP - g_positionManager.currentPrice) / _Point);

   if(g_positionManager.direction == MANAGED_POS_SELL)
      return MathMax(0.0, (g_positionManager.currentPrice - g_positionManager.currentTP) / _Point);

   return 0.0;
}

double CalculateRiskMoneyAtSL()
{
   if(!g_positionManager.hasPosition || !g_managedPositionFound || g_managedPositionTicket == 0 || g_positionManager.currentSL <= 0.0 || _Point <= 0.0)
      return 0.0;

   double riskPoints = 0.0;
   if(g_positionManager.direction == MANAGED_POS_BUY)
      riskPoints = MathAbs((g_positionManager.openPrice - g_positionManager.currentSL) / _Point);
   else if(g_positionManager.direction == MANAGED_POS_SELL)
      riskPoints = MathAbs((g_positionManager.currentSL - g_positionManager.openPrice) / _Point);

   return MathAbs(CalculateVirtualMoneyFromPoints(riskPoints, g_positionManager.volume));
}

double CalculateRewardMoneyAtTP()
{
   if(!g_positionManager.hasPosition || !g_managedPositionFound || g_managedPositionTicket == 0 || g_positionManager.currentTP <= 0.0 || _Point <= 0.0)
      return 0.0;

   double rewardPoints = 0.0;
   if(g_positionManager.direction == MANAGED_POS_BUY)
      rewardPoints = MathAbs((g_positionManager.currentTP - g_positionManager.openPrice) / _Point);
   else if(g_positionManager.direction == MANAGED_POS_SELL)
      rewardPoints = MathAbs((g_positionManager.openPrice - g_positionManager.currentTP) / _Point);

   return MathAbs(CalculateVirtualMoneyFromPoints(rewardPoints, g_positionManager.volume));
}

void UpdateManagedPositionData()
{
   if(g_managedPositionTicket == 0 || !PositionSelectByTicket(g_managedPositionTicket))
   {
      ResetManagedPositionFields();
      return;
   }

   ulong previousTicket = g_positionManager.positionTicket;

   g_positionManager.positionTicket = g_managedPositionTicket;
   g_positionManager.positionType = PositionGetInteger(POSITION_TYPE);
   g_positionManager.positionMagic = PositionGetInteger(POSITION_MAGIC);
   g_positionManager.volume = PositionGetDouble(POSITION_VOLUME);
   g_positionManager.openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   g_positionManager.currentSL = PositionGetDouble(POSITION_SL);
   g_positionManager.currentTP = PositionGetDouble(POSITION_TP);
   g_positionManager.profitMoney = PositionGetDouble(POSITION_PROFIT);
   g_positionManager.swapMoney = PositionGetDouble(POSITION_SWAP);
   g_positionManager.commissionMoney = 0.0;
   g_positionManager.netProfitMoney = g_positionManager.profitMoney + g_positionManager.swapMoney + g_positionManager.commissionMoney;
   g_positionManager.openTime = (datetime)PositionGetInteger(POSITION_TIME);
   g_positionManager.hasPosition = true;
   g_positionManager.direction = DetectManagedPositionDirection();
   g_positionManager.currentPrice = GetManagedPositionCurrentPrice();

   g_positionManager.profitPoints = CalculatePositionProfitPoints();
   g_positionManager.adversePoints = CalculatePositionAdversePoints();
   g_positionManager.favorablePoints = MathMax(0.0, g_positionManager.profitPoints);
   g_positionManager.distanceToSLPoints = CalculateDistanceToSLPoints();
   g_positionManager.distanceToTPPoints = CalculateDistanceToTPPoints();
   g_positionManager.riskMoneyAtSL = CalculateRiskMoneyAtSL();
   g_positionManager.rewardMoneyAtTP = CalculateRewardMoneyAtTP();

   if(previousTicket != g_positionManager.positionTicket)
   {
      g_positionManager.maxProfitMoney = g_positionManager.netProfitMoney;
      g_positionManager.maxAdverseMoney = MathMin(0.0, g_positionManager.netProfitMoney);
      g_positionManager.maxFavorablePoints = g_positionManager.favorablePoints;
      g_positionManager.maxAdversePoints = g_positionManager.adversePoints;
      g_breakEvenApplied = false;
      g_trailingApplied = false;
   }
   else
   {
      g_positionManager.maxProfitMoney = MathMax(g_positionManager.maxProfitMoney, g_positionManager.netProfitMoney);
      g_positionManager.maxAdverseMoney = MathMin(g_positionManager.maxAdverseMoney, g_positionManager.netProfitMoney);
      g_positionManager.maxFavorablePoints = MathMax(g_positionManager.maxFavorablePoints, g_positionManager.favorablePoints);
      g_positionManager.maxAdversePoints = MathMax(g_positionManager.maxAdversePoints, g_positionManager.adversePoints);
   }

   g_managedPositionVolume = g_positionManager.volume;
   g_managedPositionOpenPrice = g_positionManager.openPrice;
   g_managedPositionCurrentPrice = g_positionManager.currentPrice;
   g_managedPositionSL = g_positionManager.currentSL;
   g_managedPositionTP = g_positionManager.currentTP;
   g_managedPositionProfitMoney = g_positionManager.netProfitMoney;
   g_managedPositionProfitPoints = g_positionManager.profitPoints;
   g_positionMaxProfitMoney = g_positionManager.maxProfitMoney;
   g_positionMaxAdverseMoney = g_positionManager.maxAdverseMoney;
}

bool IsPositionManagerMasterAllowed(string &reason)
{
   if(!UsePositionManager)
   {
      reason = "POSITION MANAGER DISABLED";
      return false;
   }
   if(!EnablePositionManagerActions)
   {
      reason = "POSITION ACTIONS DISABLED";
      return false;
   }
   if(PositionManagerSimulationOnly)
   {
      reason = "POSITION MANAGER SIMULATION ONLY";
      return false;
   }
   if(!AllowLiveTrading || !g_liveTradingAllowed)
   {
      reason = "ALLOW LIVE TRADING FALSE";
      return false;
   }
   if(UseDiagnosticMode && !AllowPositionManagerInDiagnosticMode)
   {
      reason = "DIAGNOSTIC MODE BLOCK";
      return false;
   }
   if(!g_mqlTradeAllowed || !g_accountTradeAllowed)
   {
      reason = "TRADE ENVIRONMENT BLOCK";
      return false;
   }

   reason = "POSITION MANAGER ACTIONS ALLOWED";
   return true;
}

bool IsPositionModifyAllowed(string &reason)
{
   if(!IsPositionManagerMasterAllowed(reason))
      return false;
   if(!AllowPositionModify)
   {
      reason = "ALLOW POSITION MODIFY FALSE";
      return false;
   }
   return true;
}

bool IsPositionCloseAllowed(string &reason)
{
   if(!IsPositionManagerMasterAllowed(reason))
      return false;
   if(!AllowEmergencyPositionClose)
   {
      reason = "ALLOW EMERGENCY POSITION CLOSE FALSE";
      return false;
   }
   return true;
}

bool IsBreakEvenReady(string &reason)
{
   if(!UseBreakEvenEngine)
   {
      reason = "BREAK EVEN ENGINE DISABLED";
      return false;
   }
   if(!g_positionManager.hasPosition || !g_managedPositionFound || g_managedPositionTicket == 0)
   {
      reason = "NO MANAGED POSITION";
      return false;
   }
   if(g_positionManager.profitPoints < BreakEvenTriggerPoints)
   {
      reason = "BREAK EVEN TRIGGER NOT REACHED";
      return false;
   }

   double beSL = 0.0;
   string calcReason = "";
   if(!CalculateBreakEvenSL(beSL, calcReason))
   {
      reason = calcReason;
      return false;
   }

   if(g_positionManager.direction == MANAGED_POS_BUY)
   {
      if(g_positionManager.currentSL >= beSL && BreakEvenOnlyOnce)
      {
         reason = "BREAK EVEN ALREADY APPLIED";
         g_breakEvenApplied = true;
         return false;
      }
   }
   else if(g_positionManager.direction == MANAGED_POS_SELL)
   {
      if(g_positionManager.currentSL > 0.0 && g_positionManager.currentSL <= beSL && BreakEvenOnlyOnce)
      {
         reason = "BREAK EVEN ALREADY APPLIED";
         g_breakEvenApplied = true;
         return false;
      }
   }

   reason = "BREAK EVEN READY";
   return true;
}

bool CalculateBreakEvenSL(double &newSL, string &reason)
{
   newSL = 0.0;
   if(!g_positionManager.hasPosition || !g_managedPositionFound || g_managedPositionTicket == 0 || _Point <= 0.0)
   {
      reason = "INVALID POSITION OR POINT";
      return false;
   }

   if(g_positionManager.direction == MANAGED_POS_BUY)
      newSL = NormalizeDouble(g_positionManager.openPrice + BreakEvenOffsetPoints * _Point, _Digits);
   else if(g_positionManager.direction == MANAGED_POS_SELL)
      newSL = NormalizeDouble(g_positionManager.openPrice - BreakEvenOffsetPoints * _Point, _Digits);
   else
   {
      reason = "INVALID POSITION DIRECTION";
      return false;
   }

   reason = "BREAK EVEN SL CALCULATED";
   return (newSL > 0.0);
}

bool ValidatePositionFreezeLevel(string &reason)
{
   if(!ValidateFreezeBeforeModify)
   {
      reason = "FREEZE VALIDATION DISABLED";
      return true;
   }

   if(_Point <= 0.0)
   {
      reason = "INVALID POINT";
      return false;
   }

   double freezePoints = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   if(freezePoints <= 0.0)
   {
      reason = "NO FREEZE LEVEL";
      return true;
   }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
   {
      reason = "INVALID BID ASK";
      return false;
   }

   double price = (g_positionManager.direction == MANAGED_POS_BUY ? bid : ask);
   if(g_positionManager.proposedSL > 0.0 && MathAbs(price - g_positionManager.proposedSL) / _Point < freezePoints)
   {
      reason = "SL INSIDE FREEZE LEVEL";
      return false;
   }
   if(g_positionManager.proposedTP > 0.0 && MathAbs(price - g_positionManager.proposedTP) / _Point < freezePoints)
   {
      reason = "TP INSIDE FREEZE LEVEL";
      return false;
   }

   reason = "FREEZE LEVEL OK";
   return true;
}

bool ValidatePositionModifyStops(double newSL, double newTP, string &reason)
{
   if(!ValidateStopsBeforeModify)
   {
      reason = "STOP VALIDATION DISABLED";
      return true;
   }

   if(!g_positionManager.hasPosition || !g_managedPositionFound || g_managedPositionTicket == 0 || _Point <= 0.0)
   {
      reason = "INVALID POSITION OR POINT";
      return false;
   }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
   {
      reason = "INVALID BID ASK";
      return false;
   }

   double stopsPoints = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = stopsPoints * _Point;

   if(RequirePositionSL && newSL <= 0.0)
   {
      reason = "POSITION SL REQUIRED";
      return false;
   }
   if(RequirePositionTP && newTP <= 0.0)
   {
      reason = "POSITION TP REQUIRED";
      return false;
   }

   if(g_positionManager.direction == MANAGED_POS_BUY)
   {
      if(newSL > 0.0 && !(newSL < bid))
      {
         reason = "BUY MODIFY SL MUST BE BELOW BID";
         return false;
      }
      if(newTP > 0.0 && !(newTP > bid))
      {
         reason = "BUY MODIFY TP MUST BE ABOVE BID";
         return false;
      }
      if(newSL > 0.0 && (bid - newSL) < minDistance)
      {
         reason = "BUY SL TOO CLOSE TO PRICE";
         return false;
      }
      if(newTP > 0.0 && (newTP - bid) < minDistance)
      {
         reason = "BUY TP TOO CLOSE TO PRICE";
         return false;
      }
   }
   else if(g_positionManager.direction == MANAGED_POS_SELL)
   {
      if(newSL > 0.0 && !(newSL > ask))
      {
         reason = "SELL MODIFY SL MUST BE ABOVE ASK";
         return false;
      }
      if(newTP > 0.0 && !(newTP < ask))
      {
         reason = "SELL MODIFY TP MUST BE BELOW ASK";
         return false;
      }
      if(newSL > 0.0 && (newSL - ask) < minDistance)
      {
         reason = "SELL SL TOO CLOSE TO PRICE";
         return false;
      }
      if(newTP > 0.0 && (ask - newTP) < minDistance)
      {
         reason = "SELL TP TOO CLOSE TO PRICE";
         return false;
      }
   }
   else
   {
      reason = "INVALID POSITION DIRECTION";
      return false;
   }

   g_positionManager.proposedSL = newSL;
   g_positionManager.proposedTP = newTP;
   g_positionProposedSL = newSL;
   g_positionProposedTP = newTP;

   string freezeReason = "";
   if(!ValidatePositionFreezeLevel(freezeReason))
   {
      reason = freezeReason;
      return false;
   }

   reason = "MODIFY STOPS VALID";
   return true;
}

bool ApplyBreakEven(string &reason)
{
   double newSL = 0.0;
   if(!CalculateBreakEvenSL(newSL, reason))
      return false;

   double newTP = g_positionManager.currentTP;
   if(!ValidatePositionModifyStops(newSL, newTP, reason))
      return false;

   if(PositionManagerSimulationOnly || !EnablePositionManagerActions || !AllowBreakEvenModify)
   {
      reason = "BREAK EVEN READY - SIMULATION ONLY";
      g_positionManager.actionReason = reason;
      g_positionManager.proposedSL = newSL;
      g_positionManager.proposedTP = newTP;
      return false;
   }

   string allowReason = "";
   if(!IsPositionModifyAllowed(allowReason))
   {
      reason = "POSITION MODIFY BLOCKED: " + allowReason;
      return false;
   }

   trade.SetExpertMagicNumber((ulong)MagicNumber);
   trade.SetDeviationInPoints(PositionModifyDeviationPoints);

   if(trade.PositionModify(g_positionManager.positionTicket, newSL, newTP))
   {
      g_breakEvenApplied = true;
      g_positionManager.breakEvenApplied = true;
      g_lastPositionModifyTime = TimeCurrent();
      g_positionManager.lastModifyTime = g_lastPositionModifyTime;
      g_positionManager.state = POS_MANAGER_BE_APPLIED;
      g_positionManager.actionReason = "BREAK EVEN APPLIED";
      reason = "BREAK EVEN APPLIED";
      StartPositionManagerStateHold(POS_MANAGER_BE_APPLIED, "BREAK EVEN APPLIED");
      AuditPositionManager("BREAK EVEN APPLIED - STATE HOLD STARTED");
      return true;
   }

   g_positionManagerError = true;
   g_positionManagerLastErrorText = trade.ResultRetcodeDescription();
   reason = "BREAK EVEN MODIFY ERROR: " + g_positionManagerLastErrorText;
   return false;
}

bool IsTrailingReady(string &reason)
{
   if(!UseSmartTrailingStop)
   {
      reason = "TRAILING ENGINE DISABLED";
      return false;
   }
   if(!g_positionManager.hasPosition || !g_managedPositionFound || g_managedPositionTicket == 0)
   {
      reason = "NO MANAGED POSITION";
      return false;
   }
   if(g_positionManager.profitPoints < TrailingStartPoints)
   {
      reason = "TRAILING START NOT REACHED";
      return false;
   }
   if(TrailOnlyAfterBreakEven && !g_breakEvenApplied)
   {
      reason = "TRAILING WAITING BREAK EVEN";
      return false;
   }

   double newSL = 0.0;
   if(!CalculateTrailingSL(newSL, reason))
      return false;

   reason = "TRAILING READY";
   return true;
}

bool CalculateTrailingSL(double &newSL, string &reason)
{
   newSL = 0.0;
   if(!g_positionManager.hasPosition || !g_managedPositionFound || g_managedPositionTicket == 0 || _Point <= 0.0)
   {
      reason = "INVALID POSITION OR POINT";
      return false;
   }

   if(g_positionManager.direction == MANAGED_POS_BUY)
   {
      newSL = NormalizeDouble(g_positionManager.currentPrice - TrailingDistancePoints * _Point, _Digits);
      if(g_positionManager.currentSL > 0.0 && newSL <= g_positionManager.currentSL + TrailingStepPoints * _Point)
      {
         reason = "BUY TRAILING STEP NOT REACHED";
         return false;
      }
      if(newSL <= g_positionManager.openPrice && TrailOnlyAfterBreakEven)
      {
         reason = "BUY TRAILING BELOW BREAK EVEN";
         return false;
      }
   }
   else if(g_positionManager.direction == MANAGED_POS_SELL)
   {
      newSL = NormalizeDouble(g_positionManager.currentPrice + TrailingDistancePoints * _Point, _Digits);
      if(g_positionManager.currentSL > 0.0 && newSL >= g_positionManager.currentSL - TrailingStepPoints * _Point)
      {
         reason = "SELL TRAILING STEP NOT REACHED";
         return false;
      }
      if(newSL >= g_positionManager.openPrice && TrailOnlyAfterBreakEven)
      {
         reason = "SELL TRAILING ABOVE BREAK EVEN";
         return false;
      }
   }
   else
   {
      reason = "INVALID POSITION DIRECTION";
      return false;
   }

   reason = "TRAILING SL CALCULATED";
   return (newSL > 0.0);
}

bool ApplyTrailingStop(string &reason)
{
   double newSL = 0.0;
   if(!CalculateTrailingSL(newSL, reason))
      return false;

   double newTP = g_positionManager.currentTP;
   if(!ValidatePositionModifyStops(newSL, newTP, reason))
      return false;

   if(PositionManagerSimulationOnly || !EnablePositionManagerActions || !AllowTrailingModify)
   {
      reason = "TRAILING READY - SIMULATION ONLY";
      g_positionManager.actionReason = reason;
      g_positionManager.proposedSL = newSL;
      g_positionManager.proposedTP = newTP;
      return false;
   }

   string allowReason = "";
   if(!IsPositionModifyAllowed(allowReason))
   {
      reason = "POSITION MODIFY BLOCKED: " + allowReason;
      return false;
   }

   trade.SetExpertMagicNumber((ulong)MagicNumber);
   trade.SetDeviationInPoints(PositionModifyDeviationPoints);

   if(trade.PositionModify(g_positionManager.positionTicket, newSL, newTP))
   {
      g_trailingApplied = true;
      g_positionManager.trailingApplied = true;
      g_lastPositionModifyTime = TimeCurrent();
      g_positionManager.lastModifyTime = g_lastPositionModifyTime;
      g_positionManager.state = POS_MANAGER_TRAILING_APPLIED;
      g_positionManager.actionReason = "TRAILING APPLIED";
      reason = "TRAILING APPLIED";
      StartPositionManagerStateHold(POS_MANAGER_TRAILING_APPLIED, "TRAILING APPLIED");
      AuditPositionManager("TRAILING APPLIED - STATE HOLD STARTED");
      return true;
   }

   g_positionManagerError = true;
   g_positionManagerLastErrorText = trade.ResultRetcodeDescription();
   reason = "TRAILING MODIFY ERROR: " + g_positionManagerLastErrorText;
   return false;
}

bool IsProfitProtectionReady(string &reason)
{
   if(!UseProfitProtection)
   {
      reason = "PROFIT PROTECTION DISABLED";
      return false;
   }
   if(!g_positionManager.hasPosition || !g_managedPositionFound || g_managedPositionTicket == 0)
   {
      reason = "NO MANAGED POSITION";
      return false;
   }
   if(g_positionManager.maxProfitMoney < ProfitProtectionTriggerMoney)
   {
      reason = "PROFIT PROTECTION TRIGGER NOT REACHED";
      return false;
   }

   double allowedRetrace = g_positionManager.maxProfitMoney * (1.0 - ProfitRetraceClosePercent / 100.0);
   allowedRetrace = MathMax(allowedRetrace, ProfitProtectionMinLockMoney);

   if(g_positionManager.netProfitMoney <= allowedRetrace)
   {
      reason = "PROFIT PROTECTION READY";
      return true;
   }

   reason = "PROFIT PROTECTION NOT REQUIRED";
   return false;
}

bool IsEmergencyCloseRequired(string &reason)
{
   if(!UseEmergencyPositionProtection)
   {
      reason = "EMERGENCY PROTECTION DISABLED";
      return false;
   }
   if(!g_positionManager.hasPosition || !g_managedPositionFound || g_managedPositionTicket == 0)
   {
      reason = "NO MANAGED POSITION";
      return false;
   }

   // V8 FIX: Fechar posiÃ§Ãµes abertas quando DD diÃ¡rio estoura
   // Antes: o EA sÃ³ bloqueava novas entradas mas deixava posiÃ§Ãµes sangrando
   // Agora: se tradingLocked (DD diÃ¡rio estourou), fecha tudo imediatamente
   if(g_risk.tradingLocked && StringFind(g_risk.lockReason, "DAILY_DD") >= 0)
   {
      reason = "V8_DAILY_DD_LIMIT_EMERGENCY_CLOSE: " + g_risk.lockReason;
      return true;
   }

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double lossPercent = 0.0;
   if(balance > 0.0 && g_positionManager.netProfitMoney < 0.0)
      lossPercent = MathAbs(g_positionManager.netProfitMoney) / balance * 100.0;

   if(g_positionManager.netProfitMoney <= -MathAbs(MaxPositionLossMoney))
   {
      reason = "MAX POSITION LOSS MONEY REACHED";
      return true;
   }
   if(g_positionManager.adversePoints >= MaxPositionAdversePoints)
   {
      reason = "MAX POSITION ADVERSE POINTS REACHED";
      return true;
   }
   if(lossPercent >= MaxPositionLossPercent)
   {
      reason = "MAX POSITION LOSS PERCENT REACHED";
      return true;
   }

   reason = "NO EMERGENCY CLOSE REQUIRED";
   return false;
}

bool CloseManagedPositionEmergency(string &reason)
{
   if(!g_positionManager.hasPosition || !g_managedPositionFound || g_managedPositionTicket == 0)
   {
      reason = "NO MANAGED POSITION";
      return false;
   }

   if(PositionManagerSimulationOnly || !EnablePositionManagerActions || !AllowEmergencyPositionClose)
   {
      reason = "EMERGENCY CLOSE BLOCKED - SIMULATION ONLY OR NOT ALLOWED";
      return false;
   }

   string allowReason = "";
   if(!IsPositionCloseAllowed(allowReason))
   {
      reason = "POSITION CLOSE BLOCKED: " + allowReason;
      return false;
   }

   double pmProfit = 0.0;
   if(PositionSelectByTicket(g_positionManager.positionTicket))
      pmProfit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

   // FIX3.2: even emergency Position Manager closes are routed through the unified V4 Orchestrator gate.
   // It is marked critical, so Profit Hold cannot block it.
   if(RequestV4ExitOrchestrator(g_positionManager.positionTicket, "POSITION_MANAGER", "EMERGENCY_POSITION_CLOSE", pmProfit, true, false))
   {
      g_positionEmergencyClosed = true;
      g_lastPositionCloseTime = TimeCurrent();
      g_positionManager.lastCloseTime = g_lastPositionCloseTime;
      reason = "EMERGENCY POSITION CLOSED BY V4_ORCHESTRATOR";
      return true;
   }

   g_positionManagerError = true;
   g_positionManagerLastErrorText = "POSITION_MANAGER_EMERGENCY_CLOSE_ROUTED_TO_ORCHESTRATOR_FAILED";
   reason = "EMERGENCY CLOSE ERROR: " + g_positionManagerLastErrorText;
   return false;
}

ENUM_POSITION_MANAGER_STATE DetectPositionManagerState()
{
   if(UsePositionManagerStateHold &&
      g_positionManagerStateHoldUntil > 0 &&
      TimeCurrent() <= g_positionManagerStateHoldUntil &&
      g_positionManager.hasPosition &&
      g_managedPositionFound &&
      g_managedPositionTicket > 0)
   {
      return g_positionManagerHoldState;
   }

   if(!UsePositionManager)
      return POS_MANAGER_DISABLED;
   if(!g_positionManager.hasPosition)
      return POS_MANAGER_NO_POSITION;
   if(g_positionManagerError)
      return POS_MANAGER_ERROR;
   if(g_positionEmergencyClosed)
      return POS_MANAGER_EMERGENCY_CLOSED;
   if(g_positionEmergencyBlock)
      return POS_MANAGER_EMERGENCY_BLOCK;
   if(g_profitProtectionActive)
      return POS_MANAGER_PROFIT_PROTECTED;
   if(g_trailingReady)
      return POS_MANAGER_TRAILING_READY;
   if(g_breakEvenReady)
      return POS_MANAGER_BE_READY;
   if(PositionManagerSimulationOnly)
      return POS_MANAGER_SIMULATION_ONLY;
   return POS_MANAGER_MONITORING;
}

string PositionManagerStateToText(ENUM_POSITION_MANAGER_STATE state)
{
   switch(state)
   {
      case POS_MANAGER_DISABLED: return "POS_MANAGER_DISABLED";
      case POS_MANAGER_NO_POSITION: return "POS_MANAGER_NO_POSITION";
      case POS_MANAGER_MONITORING: return "POS_MANAGER_MONITORING";
      case POS_MANAGER_SIMULATION_ONLY: return "POS_MANAGER_SIMULATION_ONLY";
      case POS_MANAGER_BE_READY: return "POS_MANAGER_BE_READY";
      case POS_MANAGER_BE_APPLIED: return "POS_MANAGER_BE_APPLIED";
      case POS_MANAGER_TRAILING_READY: return "POS_MANAGER_TRAILING_READY";
      case POS_MANAGER_TRAILING_APPLIED: return "POS_MANAGER_TRAILING_APPLIED";
      case POS_MANAGER_PROFIT_PROTECTED: return "POS_MANAGER_PROFIT_PROTECTED";
      case POS_MANAGER_EMERGENCY_BLOCK: return "POS_MANAGER_EMERGENCY_BLOCK";
      case POS_MANAGER_EMERGENCY_CLOSED: return "POS_MANAGER_EMERGENCY_CLOSED";
      case POS_MANAGER_ERROR: return "POS_MANAGER_ERROR";
   }
   return "UNKNOWN";
}

string ManagedPositionDirectionToText(ENUM_MANAGED_POSITION_DIRECTION direction)
{
   switch(direction)
   {
      case MANAGED_POS_BUY: return "BUY";
      case MANAGED_POS_SELL: return "SELL";
      case MANAGED_POS_NONE: return "NONE";
   }
   return "NONE";
}

string ManagedPositionTypeToText(long positionType)
{
   if(!g_positionManager.hasPosition || !g_managedPositionFound || g_managedPositionTicket == 0 || positionType < 0)
      return "NONE";

   if(positionType == POSITION_TYPE_BUY)
      return "BUY";

   if(positionType == POSITION_TYPE_SELL)
      return "SELL";

   return "UNKNOWN";
}

string PositionManagerStatusToText()
{
   if(!UsePositionManager) return "DISABLED";
   if(!g_positionManager.hasPosition) return "NO POSITION";
   if(g_positionManager.state == POS_MANAGER_BE_APPLIED) return "BE_APPLIED";
   if(g_positionManager.state == POS_MANAGER_TRAILING_APPLIED) return "TRAILING_APPLIED";
   if(PositionManagerSimulationOnly) return "SIMULATION ONLY";
   if(g_breakEvenReady) return "BREAK EVEN READY";
   if(g_trailingReady) return "TRAILING READY";
   if(g_profitProtectionActive) return "PROFIT PROTECTION READY";
   if(g_positionEmergencyBlock) return "EMERGENCY BLOCK";
   if(g_positionManagerError) return "ERROR";
   return "MONITORING";
}

bool CanPrintPositionManagerLog(string reason)
{
   datetime now = TimeCurrent();
   if(reason != g_lastPositionManagerLoggedReason)
   {
      g_lastPositionManagerLoggedReason = reason;
      g_lastPositionLogTime = now;
      return true;
   }

   if(now - g_lastPositionLogTime >= MinSecondsBetweenPositionLogs)
   {
      g_lastPositionLogTime = now;
      return true;
   }

   return false;
}

void AuditPositionManager(string message)
{
   if(!PrintPositionManagerDiagnostics)
      return;
   if(!CanPrintPositionManagerLog(message))
      return;

   AuditLog("POSITION_MANAGER", message);
}

void UpdatePositionManager()
{
   if(!UsePositionManager)
   {
      ResetPositionManagerDisabled();
      return;
   }

   g_positionManager.lastUpdateTime = TimeCurrent();
   g_lastPositionManagerUpdateTime = g_positionManager.lastUpdateTime;
   g_positionManagerActive = true;
   g_positionManagerSimulationOnly = PositionManagerSimulationOnly;
   g_positionManager.simulationOnly = PositionManagerSimulationOnly;

   g_breakEvenReady = false;
   g_trailingReady = false;
   g_profitProtectionActive = false;
   g_positionEmergencyBlock = false;
   g_positionManagerError = false;
   g_positionManager.proposedSL = 0.0;
   g_positionManager.proposedTP = 0.0;
   g_positionProposedSL = 0.0;
   g_positionProposedTP = 0.0;

   if(!FindManagedPosition())
   {
      ResetManagedPositionFields();

      g_positionManager.state = POS_MANAGER_NO_POSITION;
      g_positionManager.direction = MANAGED_POS_NONE;
      g_positionManager.positionType = -1;
      g_positionManager.statusText = "NO_POSITION";
      g_positionManager.reason = "NO MANAGED POSITION FOUND";

      g_positionManagerActive = UsePositionManager;
      g_positionManagerSimulationOnly = PositionManagerSimulationOnly;

      AuditPositionManager("NO MANAGED POSITION FOUND");
      return;
   }

   if(!SelectManagedPositionByTicket(g_managedPositionTicket))
   {
      ResetManagedPositionFields();
      g_positionManager.state = POS_MANAGER_ERROR;
      g_positionManager.error = true;
      g_positionManager.reason = "FAILED TO SELECT MANAGED POSITION";
      g_positionManagerStatus = "ERROR";
      g_positionManagerReason = g_positionManager.reason;
      AuditPositionManager(g_positionManager.reason);
      return;
   }

   g_managedPositionFound = true;
   UpdateManagedPositionData();

   bool holdActive = ApplyPositionManagerStateHold();

   if(!g_positionManager.hasPosition || !g_managedPositionFound || g_managedPositionTicket == 0)
   {
      ResetManagedPositionFields();
      AuditPositionManager("NO MANAGED POSITION FOUND");
      return;
   }

   g_positionManager.monitoring = true;
   g_positionManager.statusText = PositionManagerStatusToText();
   g_positionManager.reason = "POSITION MONITORING";
   g_positionManager.blockReason = "NONE";
   g_positionManager.actionReason = "NONE";

   string beReason = "";
   if(IsBreakEvenReady(beReason))
   {
      g_breakEvenReady = true;
      g_positionManager.breakEvenReady = true;
      string applyReason = "";
      ApplyBreakEven(applyReason);
      g_positionManager.actionReason = applyReason;
      AuditPositionManager(applyReason);
   }
   else
   {
      g_positionManager.breakEvenReady = false;
   }

   string trailReason = "";
   if(IsTrailingReady(trailReason))
   {
      g_trailingReady = true;
      g_positionManager.trailingReady = true;
      string applyTrailReason = "";
      ApplyTrailingStop(applyTrailReason);
      g_positionManager.actionReason = applyTrailReason;
      AuditPositionManager(applyTrailReason);
   }
   else
   {
      g_positionManager.trailingReady = false;
   }

   string profitReason = "";
   if(IsProfitProtectionReady(profitReason))
   {
      g_profitProtectionActive = true;
      g_positionManager.profitProtected = true;
      g_positionManager.actionReason = profitReason;
      AuditPositionManager(PositionManagerSimulationOnly ? "PROFIT PROTECTION READY - SIMULATION ONLY" : profitReason);
   }
   else
   {
      g_positionManager.profitProtected = false;
   }

   string emergencyReason = "";
   if(IsEmergencyCloseRequired(emergencyReason))
   {
      g_positionEmergencyBlock = true;
      g_positionManager.emergencyBlock = true;
      string closeReason = "";
      CloseManagedPositionEmergency(closeReason);
      g_positionManager.actionReason = closeReason;
      AuditPositionManager(closeReason);
   }
   else
   {
      g_positionManager.emergencyBlock = false;
   }

   g_positionManager.breakEvenApplied = g_breakEvenApplied;
   g_positionManager.trailingApplied = g_trailingApplied;
   g_positionManager.emergencyClosed = g_positionEmergencyClosed;
   g_positionManager.error = g_positionManagerError;
   g_positionManager.lastErrorText = g_positionManagerLastErrorText;

   holdActive = ApplyPositionManagerStateHold();
   g_positionManager.state = DetectPositionManagerState();
   if(holdActive)
   {
      g_positionManager.state = g_positionManagerHoldState;
      g_positionManager.reason = g_positionManagerHoldReason;
      g_positionManager.actionReason = g_positionManagerHoldReason;
   }
   g_positionManager.statusText = PositionManagerStatusToText();

   g_positionManagerStatus = g_positionManager.statusText;
   g_positionManagerReason = g_positionManager.reason;
   g_positionManagerBlockReason = g_positionManager.blockReason;
   g_positionManagerActionReason = g_positionManager.actionReason;

   AuditPositionManager("POSITION MANAGER UPDATED | " + g_positionManagerStatus + " | " + ManagedPositionDirectionToText(g_positionManager.direction));
}

bool HasManagedPosition()
{
   return g_managedPositionFound;
}

bool HasBreakEvenApplied()
{
   return g_breakEvenApplied;
}

bool HasTrailingApplied()
{
   return g_trailingApplied;
}

double GetManagedPositionProfitMoney()
{
   return g_managedPositionProfitMoney;
}

double GetManagedPositionProfitPoints()
{
   return g_managedPositionProfitPoints;
}

string GetPositionManagerReason()
{
   return g_positionManagerReason;
}


//+------------------------------------------------------------------+
//| ETAPA 12 - Reentry / Layer Engine                               |
//+------------------------------------------------------------------+
string LayerStateToText(ENUM_LAYER_STATE state)
{
   switch(state)
   {
      case LAYER_DISABLED:          return "LAYER_DISABLED";
      case LAYER_WAIT:              return "LAYER_WAIT";
      case LAYER_NO_MAIN_POSITION:  return "LAYER_NO_MAIN_POSITION";
      case LAYER_MONITORING:        return "LAYER_MONITORING";
      case LAYER_READY:             return "LAYER_READY";
      case LAYER_SIMULATION_ONLY:   return "LAYER_SIMULATION_ONLY";
      case LAYER_BLOCKED:           return "LAYER_BLOCKED";
      case LAYER_RISK_BLOCK:        return "LAYER_RISK_BLOCK";
      case LAYER_DISTANCE_BLOCK:    return "LAYER_DISTANCE_BLOCK";
      case LAYER_SIGNAL_BLOCK:      return "LAYER_SIGNAL_BLOCK";
      case LAYER_EXPOSURE_BLOCK:    return "LAYER_EXPOSURE_BLOCK";
      case LAYER_BROKER_BLOCK:      return "LAYER_BROKER_BLOCK";
      case LAYER_BUY_READY:         return "LAYER_BUY_READY";
      case LAYER_SELL_READY:        return "LAYER_SELL_READY";
      case LAYER_BUY_SENT:          return "LAYER_BUY_SENT";
      case LAYER_SELL_SENT:         return "LAYER_SELL_SENT";
      case LAYER_ERROR:             return "LAYER_ERROR";
   }
   return "LAYER_UNKNOWN";
}

string LayerDirectionToText(ENUM_LAYER_DIRECTION direction)
{
   switch(direction)
   {
      case LAYER_DIR_BUY:  return "BUY";
      case LAYER_DIR_SELL: return "SELL";
      default:             return "NONE";
   }
}

string LayerStatusToText()
{
   return g_layerStatus;
}

void InitializeReentryLayerData()
{
   g_reentryLayer.state = LAYER_WAIT;
   g_reentryLayer.direction = LAYER_DIR_NONE;
   g_reentryLayer.active = UseReentryLayerEngine;
   g_reentryLayer.hasMainPosition = false;
   g_reentryLayer.layerReady = false;
   g_reentryLayer.layerBlocked = false;
   g_reentryLayer.simulationOnly = LayerSimulationOnly;
   g_reentryLayer.layerSent = false;
   g_reentryLayer.buyLayerReady = false;
   g_reentryLayer.sellLayerReady = false;
   g_reentryLayer.riskApproved = false;
   g_reentryLayer.distanceApproved = false;
   g_reentryLayer.signalApproved = false;
   g_reentryLayer.exposureApproved = false;
   g_reentryLayer.brokerApproved = false;
   g_reentryLayer.error = false;
   g_reentryLayer.mainPositionTicket = 0;
   g_reentryLayer.lastLayerTicket = 0;
   g_reentryLayer.lastUpdateTime = 0;
   g_reentryLayer.lastLayerTime = 0;
   g_reentryLayer.lastLayerCandleTime = 0;
   g_reentryLayer.currentLayerCount = 0;
   g_reentryLayer.buyLayerCount = 0;
   g_reentryLayer.sellLayerCount = 0;
   g_reentryLayer.maxLayersAllowed = MaxTotalLayers;
   g_reentryLayer.mainPositionOpenPrice = 0.0;
   g_reentryLayer.mainPositionCurrentPrice = 0.0;
   g_reentryLayer.mainPositionProfitMoney = 0.0;
   g_reentryLayer.mainPositionProfitPoints = 0.0;
   g_reentryLayer.mainPositionSL = 0.0;
   g_reentryLayer.mainPositionTP = 0.0;
   g_reentryLayer.plannedLayerLot = 0.0;
   g_reentryLayer.plannedLayerEntry = 0.0;
   g_reentryLayer.plannedLayerSL = 0.0;
   g_reentryLayer.plannedLayerTP = 0.0;
   g_reentryLayer.plannedLayerRiskMoney = 0.0;
   g_reentryLayer.plannedLayerRewardMoney = 0.0;
   g_reentryLayer.plannedLayerRR = 0.0;
   g_reentryLayer.distanceFromLastLayerPoints = 0.0;
   g_reentryLayer.totalLayerLots = 0.0;
   g_reentryLayer.totalSymbolLots = 0.0;
   g_reentryLayer.currentSpreadPoints = 0.0;
   g_reentryLayer.statusText = "WAITING";
   g_reentryLayer.reason = "INITIALIZED";
   g_reentryLayer.blockReason = "NONE";
   g_reentryLayer.actionReason = "NONE";
   g_reentryLayer.lastErrorText = "";

   g_layerEngineActive = UseReentryLayerEngine;
   g_layerSimulationOnly = LayerSimulationOnly;
   g_layerReady = false;
   g_layerBlocked = false;
   g_layerSent = false;
   g_layerRiskApproved = false;
   g_layerDistanceApproved = false;
   g_layerSignalApproved = false;
   g_layerExposureApproved = false;
   g_layerBrokerApproved = false;
   g_layerError = false;
   g_lastLayerTicket = 0;
   g_currentLayerCount = 0;
   g_buyLayerCount = 0;
   g_sellLayerCount = 0;
   g_plannedLayerLot = 0.0;
   g_plannedLayerEntry = 0.0;
   g_plannedLayerSL = 0.0;
   g_plannedLayerTP = 0.0;
   g_plannedLayerRiskMoney = 0.0;
   g_plannedLayerRewardMoney = 0.0;
   g_plannedLayerRR = 0.0;
   g_totalLayerLots = 0.0;
   g_totalSymbolExposureLots = 0.0;
   g_layerDistanceFromLastEntryPoints = 0.0;
   g_lastLayerUpdateTime = 0;
   g_lastLayerExecutionTime = 0;
   g_lastLayerCandleTime = 0;
   g_layerStatus = "WAITING";
   g_layerReason = "INITIALIZED";
   g_layerBlockReason = "NONE";
   g_layerActionReason = "NONE";
   g_layerLastErrorText = "";
}

void ResetReentryLayerPlanning()
{
   g_layerReady = false;
   g_layerBlocked = false;
   g_layerRiskApproved = false;
   g_layerDistanceApproved = false;
   g_layerSignalApproved = false;
   g_layerExposureApproved = false;
   g_layerBrokerApproved = false;
   g_layerError = false;
   g_plannedLayerLot = 0.0;
   g_plannedLayerEntry = 0.0;
   g_plannedLayerSL = 0.0;
   g_plannedLayerTP = 0.0;
   g_plannedLayerRiskMoney = 0.0;
   g_plannedLayerRewardMoney = 0.0;
   g_plannedLayerRR = 0.0;
   g_layerDistanceFromLastEntryPoints = 0.0;
   g_layerActionReason = "NONE";
   g_layerLastErrorText = "";

   g_reentryLayer.layerReady = false;
   g_reentryLayer.buyLayerReady = false;
   g_reentryLayer.sellLayerReady = false;
   g_reentryLayer.riskApproved = false;
   g_reentryLayer.distanceApproved = false;
   g_reentryLayer.signalApproved = false;
   g_reentryLayer.exposureApproved = false;
   g_reentryLayer.brokerApproved = false;
   g_reentryLayer.error = false;
   g_reentryLayer.plannedLayerLot = 0.0;
   g_reentryLayer.plannedLayerEntry = 0.0;
   g_reentryLayer.plannedLayerSL = 0.0;
   g_reentryLayer.plannedLayerTP = 0.0;
   g_reentryLayer.plannedLayerRiskMoney = 0.0;
   g_reentryLayer.plannedLayerRewardMoney = 0.0;
   g_reentryLayer.plannedLayerRR = 0.0;
   g_reentryLayer.distanceFromLastLayerPoints = 0.0;
   g_reentryLayer.actionReason = "NONE";
   g_reentryLayer.lastErrorText = "";
}

void ResetReentryLayerMainPosition()
{
   g_reentryLayer.hasMainPosition = false;
   g_reentryLayer.mainPositionTicket = 0;
   g_reentryLayer.mainPositionOpenPrice = 0.0;
   g_reentryLayer.mainPositionCurrentPrice = 0.0;
   g_reentryLayer.mainPositionProfitMoney = 0.0;
   g_reentryLayer.mainPositionProfitPoints = 0.0;
   g_reentryLayer.mainPositionSL = 0.0;
   g_reentryLayer.mainPositionTP = 0.0;
   g_reentryLayer.direction = LAYER_DIR_NONE;
}

void SyncLayerGlobals()
{
   g_layerEngineActive = g_reentryLayer.active;
   g_layerSimulationOnly = g_reentryLayer.simulationOnly;
   g_layerReady = g_reentryLayer.layerReady;
   g_layerBlocked = g_reentryLayer.layerBlocked;
   g_layerSent = g_reentryLayer.layerSent;
   g_layerRiskApproved = g_reentryLayer.riskApproved;
   g_layerDistanceApproved = g_reentryLayer.distanceApproved;
   g_layerSignalApproved = g_reentryLayer.signalApproved;
   g_layerExposureApproved = g_reentryLayer.exposureApproved;
   g_layerBrokerApproved = g_reentryLayer.brokerApproved;
   g_layerError = g_reentryLayer.error;

   g_lastLayerTicket = g_reentryLayer.lastLayerTicket;
   g_currentLayerCount = g_reentryLayer.currentLayerCount;
   g_buyLayerCount = g_reentryLayer.buyLayerCount;
   g_sellLayerCount = g_reentryLayer.sellLayerCount;

   g_plannedLayerLot = g_reentryLayer.plannedLayerLot;
   g_plannedLayerEntry = g_reentryLayer.plannedLayerEntry;
   g_plannedLayerSL = g_reentryLayer.plannedLayerSL;
   g_plannedLayerTP = g_reentryLayer.plannedLayerTP;
   g_plannedLayerRiskMoney = g_reentryLayer.plannedLayerRiskMoney;
   g_plannedLayerRewardMoney = g_reentryLayer.plannedLayerRewardMoney;
   g_plannedLayerRR = g_reentryLayer.plannedLayerRR;
   g_totalLayerLots = g_reentryLayer.totalLayerLots;
   g_totalSymbolExposureLots = g_reentryLayer.totalSymbolLots;
   g_layerDistanceFromLastEntryPoints = g_reentryLayer.distanceFromLastLayerPoints;

   g_layerStatus = g_reentryLayer.statusText;
   g_layerReason = g_reentryLayer.reason;
   g_layerBlockReason = g_reentryLayer.blockReason;
   g_layerActionReason = g_reentryLayer.actionReason;
   g_layerLastErrorText = g_reentryLayer.lastErrorText;
}

void ResetReentryLayerDisabled()
{
   ResetReentryLayerPlanning();
   ResetReentryLayerMainPosition();
   g_layerEngineActive = false;
   g_layerSimulationOnly = LayerSimulationOnly;
   g_reentryLayer.active = false;
   g_reentryLayer.state = LAYER_DISABLED;
   g_reentryLayer.statusText = "LAYER ENGINE DISABLED";
   g_reentryLayer.reason = "LAYER ENGINE DISABLED";
   g_reentryLayer.blockReason = "NONE";
   g_reentryLayer.actionReason = "NONE";
   g_reentryLayer.layerBlocked = false;
   SyncLayerGlobals();
}

bool SyncLayerMainPositionFromTicket(ulong ticket, string &reason)
{
   if(ticket <= 0)
   {
      reason = "INVALID MAIN POSITION TICKET";
      return false;
   }

   if(!PositionSelectByTicket(ticket))
   {
      reason = "MAIN POSITION TICKET NOT SELECTED";
      return false;
   }

   string sym = PositionGetString(POSITION_SYMBOL);
   long magic = (long)PositionGetInteger(POSITION_MAGIC);
   double volume = PositionGetDouble(POSITION_VOLUME);
   long type = (long)PositionGetInteger(POSITION_TYPE);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl = PositionGetDouble(POSITION_SL);
   double tp = PositionGetDouble(POSITION_TP);
   double profit = PositionGetDouble(POSITION_PROFIT);

   if(sym != _Symbol)
   {
      reason = "MAIN POSITION SYMBOL MISMATCH";
      return false;
   }

   if(!V10_IsMagicAccepted(magic))
   {
      reason = "MAIN POSITION MAGIC MISMATCH";
      return false;
   }

   if(volume <= 0.0)
   {
      reason = "MAIN POSITION VOLUME INVALID";
      return false;
   }

   if(type != POSITION_TYPE_BUY && type != POSITION_TYPE_SELL)
   {
      reason = "MAIN POSITION TYPE INVALID";
      return false;
   }

   if(openPrice <= 0.0)
   {
      reason = "MAIN POSITION OPEN PRICE INVALID";
      return false;
   }

   double currentPrice = 0.0;
   if(type == POSITION_TYPE_BUY)
      currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   else
      currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(currentPrice <= 0.0)
   {
      reason = "MAIN POSITION CURRENT PRICE INVALID";
      return false;
   }

   double profitPoints = 0.0;
   if(_Point > 0.0)
   {
      if(type == POSITION_TYPE_BUY)
         profitPoints = (currentPrice - openPrice) / _Point;
      else
         profitPoints = (openPrice - currentPrice) / _Point;
   }

   g_reentryLayer.hasMainPosition = true;
   g_reentryLayer.mainPositionTicket = ticket;
   g_reentryLayer.mainPositionOpenPrice = openPrice;
   g_reentryLayer.mainPositionCurrentPrice = currentPrice;
   g_reentryLayer.mainPositionProfitMoney = profit;
   g_reentryLayer.mainPositionProfitPoints = profitPoints;
   g_reentryLayer.mainPositionSL = sl;
   g_reentryLayer.mainPositionTP = tp;
   g_reentryLayer.direction = (type == POSITION_TYPE_BUY ? LAYER_DIR_BUY : LAYER_DIR_SELL);

   reason = "MAIN POSITION FOUND";
   return true;
}

bool SyncMainPositionForLayer(string &reason)
{
   reason = "NO MAIN POSITION FOR LAYER";
   ResetReentryLayerMainPosition();

   ulong ticket = 0;

   if(g_managedPositionFound && g_managedPositionTicket > 0)
      ticket = g_managedPositionTicket;
   else if(g_positionManager.hasPosition && g_positionManager.positionTicket > 0)
      ticket = g_positionManager.positionTicket;

   if(ticket > 0 && SyncLayerMainPositionFromTicket(ticket, reason))
      return true;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong scanTicket = PositionGetTicket(i);
      if(scanTicket <= 0)
         continue;

      if(!PositionSelectByTicket(scanTicket))
         continue;

      string sym = PositionGetString(POSITION_SYMBOL);
      long magic = (long)PositionGetInteger(POSITION_MAGIC);

      if(sym != _Symbol)
         continue;

      if(!V10_IsMagicAccepted(magic))
         continue;

      if(SyncLayerMainPositionFromTicket(scanTicket, reason))
         return true;
   }

   reason = "NO MAIN POSITION FOR LAYER";
   ResetReentryLayerMainPosition();
   return false;
}

bool HasMainPositionForLayer(string &reason)
{
   bool found = SyncMainPositionForLayer(reason);

   if(found)
   {
      g_reentryLayer.hasMainPosition = true;
      g_reentryLayer.state = LAYER_MONITORING;
      g_reentryLayer.statusText = "MAIN_POSITION_FOUND";
      g_reentryLayer.reason = "MAIN POSITION FOUND";
      g_reentryLayer.blockReason = "NONE";
      g_reentryLayer.layerBlocked = false;
      g_reentryLayer.layerReady = false;
      SyncLayerGlobals();
      return true;
   }

   g_reentryLayer.hasMainPosition = false;
   g_reentryLayer.state = LAYER_NO_MAIN_POSITION;
   g_reentryLayer.statusText = "NO_MAIN_POSITION";
   g_reentryLayer.reason = "NO MAIN POSITION FOR LAYER";
   g_reentryLayer.blockReason = "NO MAIN POSITION FOR LAYER";
   g_reentryLayer.actionReason = "WAITING MAIN POSITION";
   g_reentryLayer.layerBlocked = true;
   g_reentryLayer.layerReady = false;
   g_reentryLayer.layerSent = false;
   g_reentryLayer.direction = LAYER_DIR_NONE;
   SyncLayerGlobals();
   return false;
}

bool HasMainPositionForLayer()
{
   string reason = "";
   return HasMainPositionForLayer(reason);
}

ENUM_LAYER_DIRECTION DetectLayerDirection()
{
   if(!g_reentryLayer.hasMainPosition || g_reentryLayer.mainPositionTicket == 0)
      return LAYER_DIR_NONE;

   if(PositionSelectByTicket(g_reentryLayer.mainPositionTicket))
   {
      long type = (long)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY)
         return LAYER_DIR_BUY;
      if(type == POSITION_TYPE_SELL)
         return LAYER_DIR_SELL;
   }

   return g_reentryLayer.direction;
}


// PATCH_LAYER_010_025_040 - Helpers de layer por Ã­ndice (Main + Layer1 + Layer2)
bool IsLayerMainTicket(ulong ticket)
{
   if(ticket == 0)
      return false;
   if(g_reentryLayer.mainPositionTicket > 0 && ticket == g_reentryLayer.mainPositionTicket)
      return true;
   if(g_managedPositionTicket > 0 && ticket == g_managedPositionTicket)
      return true;
   return false;
}

int CountLayerPositionsOnly()
{
   int count = 0;
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      if(IsLayerMainTicket(ticket))
         continue;
      count++;
   }
   return count;
}

int CountLayerPositionsByDirectionOnly(ENUM_LAYER_DIRECTION direction)
{
   int count = 0;
   long targetType = -1;
   if(direction == LAYER_DIR_BUY) targetType = POSITION_TYPE_BUY;
   if(direction == LAYER_DIR_SELL) targetType = POSITION_TYPE_SELL;
   if(targetType < 0)
      return 0;

   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      if((long)PositionGetInteger(POSITION_TYPE) != targetType)
         continue;
      if(IsLayerMainTicket(ticket))
         continue;
      count++;
   }
   return count;
}

double CalculateDirectionalLayerExposureLots(ENUM_LAYER_DIRECTION direction)
{
   double lots = 0.0;
   long targetType = -1;
   if(direction == LAYER_DIR_BUY) targetType = POSITION_TYPE_BUY;
   if(direction == LAYER_DIR_SELL) targetType = POSITION_TYPE_SELL;
   if(targetType < 0)
      return 0.0;

   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      if((long)PositionGetInteger(POSITION_TYPE) != targetType)
         continue;
      lots += PositionGetDouble(POSITION_VOLUME);
   }
   return lots;
}

int GetNextLayerIndex()
{
   ENUM_LAYER_DIRECTION dir = g_reentryLayer.direction;
   if(dir == LAYER_DIR_NONE)
      dir = DetectLayerDirection();
   if(dir == LAYER_DIR_NONE)
      return 0;
   int existingLayers = CountLayerPositionsByDirectionOnly(dir);
   if(existingLayers <= 0)
      return 1;
   if(existingLayers == 1)
      return 2;
   return 0;
}

double CalculateLayerLotByIndex(int layerIndex)
{
   if(layerIndex == 1)
      return NormalizeLayerLot(Layer1LotByIndex);
   if(layerIndex == 2)
      return NormalizeLayerLot(Layer2LotByIndex);
   return 0.0;
}

double GetLayerDirectionalScore(ENUM_LAYER_DIRECTION direction)
{
   double score = MathMax(g_entryBaseScore, g_entryDecisionScore);
   if(direction == LAYER_DIR_BUY)
      score = MathMax(score, MathMax(g_buyDecisionScore, g_buyStrengthScore));
   else if(direction == LAYER_DIR_SELL)
      score = MathMax(score, MathMax(g_sellDecisionScore, g_sellStrengthScore));
   return score;
}

int CountCurrentLayers()
{
   // PATCH_LAYER_010_025_040: contar somente camadas reais, sem contar a posiÃ§Ã£o principal.
   return CountLayerPositionsOnly();
}

int CountLayersByDirection(ENUM_LAYER_DIRECTION direction)
{
   // PATCH_LAYER_010_025_040: contar somente Layer 1/Layer 2 da direÃ§Ã£o, excluindo main.
   return CountLayerPositionsByDirectionOnly(direction);
}

double CalculateTotalLayerLots()
{
   double lots = 0.0;
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      if(IsLayerMainTicket(ticket))
         continue;
      lots += PositionGetDouble(POSITION_VOLUME);
   }
   return lots;
}

double CalculateTotalSymbolExposureLots()
{
   double lots = 0.0;
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      lots += PositionGetDouble(POSITION_VOLUME);
   }
   return lots;
}

double GetLastLayerEntryPrice(ENUM_LAYER_DIRECTION direction)
{
   double lastPrice = 0.0;
   datetime lastTime = 0;
   long targetType = -1;
   if(direction == LAYER_DIR_BUY) targetType = POSITION_TYPE_BUY;
   if(direction == LAYER_DIR_SELL) targetType = POSITION_TYPE_SELL;
   if(targetType < 0) return 0.0;

   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      if((long)PositionGetInteger(POSITION_TYPE) != targetType)
         continue;

      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      if(openTime >= lastTime)
      {
         lastTime = openTime;
         lastPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      }
   }

   if(lastPrice <= 0.0 && HasMainPositionForLayer())
      lastPrice = g_positionManager.openPrice;

   return lastPrice;
}

double CalculateLayerDistancePoints(ENUM_LAYER_DIRECTION direction)
{
   if(_Point <= 0.0)
      return 0.0;

   double lastPrice = GetLastLayerEntryPrice(direction);
   if(lastPrice <= 0.0)
      return 0.0;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double current = (direction == LAYER_DIR_BUY ? ask : bid);
   if(current <= 0.0)
      current = g_positionManager.currentPrice;

   if(direction == LAYER_DIR_BUY)
      return (current - lastPrice) / _Point;
   if(direction == LAYER_DIR_SELL)
      return (lastPrice - current) / _Point;

   return 0.0;
}

double NormalizeLayerLot(double lot)
{
   double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(minVol <= 0.0) minVol = 0.01;
   if(maxVol < minVol) maxVol = minVol;
   if(step <= 0.0) step = minVol;
   if(step <= 0.0) step = 0.01;

   lot = MathMax(MinLayerLot, lot);
   lot = MathMin(MaxLayerLot, lot);
   lot = MathMax(minVol, MathMin(maxVol, lot));
   lot = MathFloor(lot / step) * step;
   if(lot < minVol) lot = minVol;
   return NormalizeDouble(lot, 2);
}

double CalculateLayerLot()
{
   // PATCH_LAYER_010_025_040: lote por Ã­ndice, nÃ£o FixedLayerLot Ãºnico para todas as camadas.
   int layerIndex = GetNextLayerIndex();
   double lot = CalculateLayerLotByIndex(layerIndex);

   if(lot <= 0.0)
      return 0.0;

   // SeguranÃ§a anti-martingale: sÃ³ permite os lotes explÃ­citos Layer1/Layer2.
   if(layerIndex == 1 && MathAbs(lot - NormalizeLayerLot(Layer1LotByIndex)) > 0.000001)
      return 0.0;
   if(layerIndex == 2 && MathAbs(lot - NormalizeLayerLot(Layer2LotByIndex)) > 0.000001)
      return 0.0;

   return NormalizeLayerLot(lot);
}

bool IsLayerMasterAllowed(string &reason)
{
   if(!UseReentryLayerEngine)
   {
      reason = "LAYER ENGINE DISABLED";
      return false;
   }
   if(!AllowLiveTrading)
   {
      reason = "ALLOW LIVE TRADING FALSE";
      return false;
   }
   if(UseDiagnosticMode && !AllowLayerInDiagnosticMode)
   {
      reason = "DIAGNOSTIC MODE BLOCKS REAL LAYER";
      return false;
   }
   reason = "LAYER MASTER ALLOWED";
   return true;
}

bool IsLayerDirectionAllowed(string &reason)
{
   ENUM_LAYER_DIRECTION dir = DetectLayerDirection();
   g_reentryLayer.direction = dir;
   if(dir == LAYER_DIR_NONE)
   {
      reason = "NO LAYER DIRECTION";
      return false;
   }
   if(dir == LAYER_DIR_BUY && !AllowBuyLayers)
   {
      reason = "BUY LAYERS DISABLED";
      return false;
   }
   if(dir == LAYER_DIR_SELL && !AllowSellLayers)
   {
      reason = "SELL LAYERS DISABLED";
      return false;
   }
   if(LayerOnlySameDirectionAsMainPosition || BlockOppositeLayerDirection)
   {
      if((dir == LAYER_DIR_BUY && g_positionManager.direction != MANAGED_POS_BUY) ||
         (dir == LAYER_DIR_SELL && g_positionManager.direction != MANAGED_POS_SELL))
      {
         reason = "OPPOSITE LAYER DIRECTION BLOCKED";
         return false;
      }
   }
   reason = "LAYER DIRECTION ALLOWED";
   return true;
}

bool IsLayerCountAllowed(string &reason)
{
   // PATCH_LAYER_010_025_040: permitir exatamente Main + Layer1 + Layer2.
   ENUM_LAYER_DIRECTION dir = g_reentryLayer.direction;
   g_currentLayerCount = CountLayerPositionsOnly();
   g_buyLayerCount = CountLayerPositionsByDirectionOnly(LAYER_DIR_BUY);
   g_sellLayerCount = CountLayerPositionsByDirectionOnly(LAYER_DIR_SELL);

   g_reentryLayer.currentLayerCount = g_currentLayerCount;
   g_reentryLayer.buyLayerCount = g_buyLayerCount;
   g_reentryLayer.sellLayerCount = g_sellLayerCount;

   int dirLayerCount = 0;
   if(dir == LAYER_DIR_BUY) dirLayerCount = g_buyLayerCount;
   if(dir == LAYER_DIR_SELL) dirLayerCount = g_sellLayerCount;

   if(MaxTotalLayers > 0 && g_currentLayerCount >= MaxTotalLayers)
   {
      reason = "[LAYER_MAX_COUNT_BLOCK] MAX TOTAL REAL LAYERS REACHED current=" + IntegerToString(g_currentLayerCount) + " max=" + IntegerToString(MaxTotalLayers);
      return false;
   }

   if(MaxLayersPerDirection > 0 && dirLayerCount >= MaxLayersPerDirection)
   {
      reason = "[LAYER_MAX_COUNT_BLOCK] MAX LAYERS PER DIRECTION REACHED current=" + IntegerToString(dirLayerCount) + " max=" + IntegerToString(MaxLayersPerDirection);
      return false;
   }

   int nextLayerIndex = dirLayerCount + 1;
   if(nextLayerIndex < 1 || nextLayerIndex > 2)
   {
      reason = "[LAYER_MAX_COUNT_BLOCK] LAYER 3+ BLOCKED nextIndex=" + IntegerToString(nextLayerIndex);
      return false;
   }

   // Compatibilidade: a trava legada nÃ£o deve matar a Layer 2.
   if(DisableLayerAfterOneSuccess && g_layerSent && MaxLayersPerDirection <= 1)
   {
      reason = "LAYER ALREADY SENT";
      return false;
   }

   reason = "LAYER COUNT ALLOWED nextIndex=" + IntegerToString(nextLayerIndex);
   return true;
}

bool IsLayerDistanceAllowed(string &reason)
{
   if(!UseMinLayerDistance)
   {
      reason = "LAYER DISTANCE FILTER DISABLED";
      g_layerDistanceFromLastEntryPoints = 999999.0;
      return true;
   }

   double minDistance = MinLayerDistancePoints;
   if(UseATRLayerDistance)
      minDistance = MathMax(MinLayerDistancePoints, g_atrM1Points * MinLayerDistanceATRMultiplier);

   g_layerDistanceFromLastEntryPoints = CalculateLayerDistancePoints(g_reentryLayer.direction);
   g_reentryLayer.distanceFromLastLayerPoints = g_layerDistanceFromLastEntryPoints;

   if(g_layerDistanceFromLastEntryPoints < minDistance)
   {
      reason = "MIN LAYER DISTANCE NOT REACHED";
      return false;
   }

   reason = "LAYER DISTANCE APPROVED";
   return true;
}

bool IsMainPositionProtectedForLayer(string &reason)
{
   if(!HasMainPositionForLayer())
   {
      reason = "NO MAIN POSITION FOR LAYER";
      return false;
   }

   double profitMoney = g_reentryLayer.mainPositionProfitMoney;
   double profitPoints = g_reentryLayer.mainPositionProfitPoints;
   double openPrice = g_reentryLayer.mainPositionOpenPrice;
   double currentSL = g_reentryLayer.mainPositionSL;
   ENUM_LAYER_DIRECTION dir = g_reentryLayer.direction;
   int layerIndex = GetNextLayerIndex();
   double score = GetLayerDirectionalScore(dir);

   if(profitMoney < 0.0)
   {
      reason = "[V10_LAYER_BLOCK] MAIN_NEGATIVE_FOR_LAYER mainProfit=" + DoubleToString(profitMoney,2)
             + " basketProfit=" + DoubleToString(g_basket.netProfit,2);
      AuditReentryLayer(reason);
      AuditV4(reason);
      return false;
   }

   if(g_basket.netProfit <= 0.0)
   {
      reason = "[V10_LAYER_BLOCK] BASKET_NOT_POSITIVE_FOR_LAYER mainProfit=" + DoubleToString(profitMoney,2)
             + " basketProfit=" + DoubleToString(g_basket.netProfit,2);
      AuditReentryLayer(reason);
      AuditV4(reason);
      return false;
   }

   if(layerIndex <= 0 || layerIndex > 2)
   {
      reason = "[LAYER_MAX_COUNT_BLOCK] INVALID NEXT LAYER INDEX";
      return false;
   }

   bool beRegion = false;
   if(dir == LAYER_DIR_BUY)
      beRegion = (currentSL >= openPrice && currentSL > 0.0);
   else if(dir == LAYER_DIR_SELL)
      beRegion = (currentSL <= openPrice && currentSL > 0.0);
   bool beApplied = (g_positionManager.breakEvenApplied || g_breakEvenApplied || beRegion);

   // Layer 2 sÃ³ existe apÃ³s Layer 1 e nÃ£o pode ser recuperaÃ§Ã£o suicida.
   if(layerIndex == 2)
   {
      if(CountLayerPositionsByDirectionOnly(dir) < 1)
      {
         reason = "[LAYER_MAX_COUNT_BLOCK] LAYER 2 BLOCKED - LAYER 1 NOT FOUND";
         return false;
      }
      if(g_basket.netProfit < -MaxBasketFloatingLossMoneyForLayer2)
      {
         reason = "[LAYER_DRAWDOWN_BLOCK] BASKET FLOATING LOSS TOO HIGH FOR LAYER 2";
         return false;
      }
      if(score < MinScoreLayer2)
      {
         reason = "[LAYER_SIGNAL_BLOCK] LAYER 2 SCORE LOW=" + DoubleToString(score,1);
         return false;
      }
      reason = "MAIN/LAYER1 CONTEXT APPROVED FOR LAYER 2";
      return true;
   }

   // Layer 1 em pullback controlado: permitido apenas com score alto e perda limitada.
   if(profitMoney < 0.0)
   {
      if(!AllowControlledPullbackLayer)
      {
         reason = "MAIN POSITION IN DRAWDOWN";
         return false;
      }
      if(profitMoney < -MaxFloatingLossMoneyForPullbackLayer1 || profitMoney <= -MaxMainPositionLossMoneyForLayer)
      {
         reason = "[LAYER_DRAWDOWN_BLOCK] MAIN FLOATING LOSS TOO HIGH FOR PULLBACK LAYER";
         return false;
      }
      if(score < MinScorePullbackLayer1)
      {
         reason = "[LAYER_SIGNAL_BLOCK] PULLBACK LAYER SCORE LOW=" + DoubleToString(score,1);
         return false;
      }
      if(MaxMainPositionAdversePointsForLayer > 0.0 && g_positionManager.adversePoints >= MaxMainPositionAdversePointsForLayer)
      {
         reason = "MAIN POSITION ADVERSE POINTS TOO HIGH";
         return false;
      }
      reason = "CONTROLLED PULLBACK APPROVED FOR LAYER 1";
      return true;
   }

   // Layer 1 em lucro: precisa lucro mÃ­nimo + BE quando configurado.
   if(RequireMainPositionProfitForLayer)
   {
      if(profitMoney < MinMainPositionProfitMoneyForLayer || profitPoints < MinMainPositionProfitPointsForLayer)
      {
         reason = "MAIN POSITION NOT PROFITABLE";
         return false;
      }
   }

   if(MaxMainPositionLossMoneyForLayer > 0.0 && profitMoney <= -MaxMainPositionLossMoneyForLayer)
   {
      reason = "MAIN POSITION LOSS TOO HIGH";
      return false;
   }

   if(MaxMainPositionAdversePointsForLayer > 0.0 && g_positionManager.adversePoints >= MaxMainPositionAdversePointsForLayer)
   {
      reason = "MAIN POSITION ADVERSE POINTS TOO HIGH";
      return false;
   }

   if(RequireBreakEvenBeforeLayer && !beApplied)
   {
      reason = "[LAYER_BE_BLOCK] BREAK EVEN REQUIRED BEFORE PROFIT LAYER";
      return false;
   }

   if(RequireTrailingBeforeLayer)
   {
      bool trailRegion = false;
      if(dir == LAYER_DIR_BUY)
         trailRegion = (currentSL > openPrice && currentSL > 0.0);
      else if(dir == LAYER_DIR_SELL)
         trailRegion = (currentSL < openPrice && currentSL > 0.0);

      if(!g_positionManager.trailingApplied && !g_trailingApplied && !trailRegion)
      {
         reason = "TRAILING REQUIRED BEFORE LAYER";
         return false;
      }
   }

   reason = "MAIN POSITION PROTECTED FOR LAYER 1";
   return true;
}

bool IsLayerSignalApproved(string &reason)
{
   ENUM_LAYER_DIRECTION dir = g_reentryLayer.direction;
   int layerIndex = GetNextLayerIndex();
   double score = GetLayerDirectionalScore(dir);
   double requiredScore = MinEntryScoreForLayer;
   if(layerIndex == 1)
      requiredScore = MinScoreLayer1;
   else if(layerIndex == 2)
      requiredScore = MinScoreLayer2;

   if(RequireFlowConfirmationForLayer)
   {
      if(dir == LAYER_DIR_BUY)
      {
         if(!(g_flow.direction == FLOW_BUY_WEAK || g_flow.direction == FLOW_BUY_STRONG) || g_buyStrengthScore < MinFlowStrengthForLayer)
         {
            reason = "[LAYER_DIRECTION_BLOCK] LAYER SIGNAL NOT APPROVED - BUY FLOW";
            return false;
         }
      }
      else if(dir == LAYER_DIR_SELL)
      {
         if(!(g_flow.direction == FLOW_SELL_WEAK || g_flow.direction == FLOW_SELL_STRONG) || g_sellStrengthScore < MinFlowStrengthForLayer)
         {
            reason = "[LAYER_DIRECTION_BLOCK] LAYER SIGNAL NOT APPROVED - SELL FLOW";
            return false;
         }
      }
      else
      {
         reason = "[LAYER_DIRECTION_BLOCK] LAYER SIGNAL NOT APPROVED - NO DIRECTION";
         return false;
      }
   }

   if(score < requiredScore)
   {
      reason = "[LAYER_SIGNAL_BLOCK] LAYER SCORE LOW layerIndex=" + IntegerToString(layerIndex) + " score=" + DoubleToString(score,1) + " required=" + DoubleToString(requiredScore,1);
      return false;
   }

   if(RequireSameDryRunDirectionForLayer)
   {
      if(dir == LAYER_DIR_BUY && !(g_executionDryRun.direction == DRY_RUN_DIR_BUY || g_dryRunBuyReady))
      {
         reason = "LAYER SIGNAL NOT APPROVED - DRY RUN NOT BUY";
         return false;
      }
      if(dir == LAYER_DIR_SELL && !(g_executionDryRun.direction == DRY_RUN_DIR_SELL || g_dryRunSellReady))
      {
         reason = "LAYER SIGNAL NOT APPROVED - DRY RUN NOT SELL";
         return false;
      }
   }

   if(RequirePreExecutionApprovedForLayer && !g_preExecutionApproved)
   {
      reason = "LAYER SIGNAL NOT APPROVED - PRE EXECUTION BLOCK";
      return false;
   }

   reason = "LAYER SIGNAL APPROVED layerIndex=" + IntegerToString(layerIndex) + " score=" + DoubleToString(score,1);
   return true;
}

bool BuildPlannedLayerOrder(string &reason)
{
   reason = "";
   if(_Point <= 0.0)
   {
      reason = "INVALID POINT";
      return false;
   }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
   {
      reason = "INVALID BID ASK";
      return false;
   }

   ENUM_LAYER_DIRECTION dir = g_reentryLayer.direction;
   if(dir == LAYER_DIR_NONE)
   {
      reason = "NO LAYER DIRECTION";
      return false;
   }

   double lot = CalculateLayerLot();
   if(lot <= 0.0)
   {
      reason = "INVALID LAYER LOT";
      return false;
   }

   double entry = (dir == LAYER_DIR_BUY ? ask : bid);
   double sl = 0.0;
   double tp = 0.0;
   double atr = g_atrM1Points;
   if(atr <= 0.0)
      atr = MinATRPointsForActiveMarket;

   if(UseMainPositionSLTPForLayer && g_positionManager.currentSL > 0.0 && g_positionManager.currentTP > 0.0)
   {
      sl = g_positionManager.currentSL;
      tp = g_positionManager.currentTP;
   }
   else
   {
      double slDistance = atr * LayerSL_ATR_Multiplier * _Point;
      double tpDistance = atr * LayerTP_ATR_Multiplier * _Point;
      if(dir == LAYER_DIR_BUY)
      {
         sl = entry - slDistance;
         tp = entry + tpDistance;
      }
      else
      {
         sl = entry + slDistance;
         tp = entry - tpDistance;
      }
   }

   if(sl <= 0.0 || tp <= 0.0)
   {
      reason = "INVALID LAYER SL TP";
      return false;
   }

   if(dir == LAYER_DIR_BUY && !(sl < entry && entry < tp))
   {
      reason = "INVALID BUY LAYER SL TP";
      return false;
   }
   if(dir == LAYER_DIR_SELL && !(tp < entry && entry < sl))
   {
      reason = "INVALID SELL LAYER SL TP";
      return false;
   }

   double riskPoints = MathAbs(entry - sl) / _Point;
   double rewardPoints = MathAbs(tp - entry) / _Point;
   double riskMoney = MathAbs(CalculateVirtualMoneyFromPoints(riskPoints, lot));
   double rewardMoney = MathAbs(CalculateVirtualMoneyFromPoints(rewardPoints, lot));
   double rr = (riskMoney > 0.0 ? rewardMoney / riskMoney : 0.0);

   if(rr < MinLayerRR)
   {
      reason = "LAYER RR TOO LOW";
      return false;
   }

   g_plannedLayerLot = lot;
   g_plannedLayerEntry = NormalizeDouble(entry, _Digits);
   g_plannedLayerSL = NormalizeDouble(sl, _Digits);
   g_plannedLayerTP = NormalizeDouble(tp, _Digits);
   g_plannedLayerRiskMoney = riskMoney;
   g_plannedLayerRewardMoney = rewardMoney;
   g_plannedLayerRR = rr;

   g_reentryLayer.plannedLayerLot = g_plannedLayerLot;
   g_reentryLayer.plannedLayerEntry = g_plannedLayerEntry;
   g_reentryLayer.plannedLayerSL = g_plannedLayerSL;
   g_reentryLayer.plannedLayerTP = g_plannedLayerTP;
   g_reentryLayer.plannedLayerRiskMoney = g_plannedLayerRiskMoney;
   g_reentryLayer.plannedLayerRewardMoney = g_plannedLayerRewardMoney;
   g_reentryLayer.plannedLayerRR = g_plannedLayerRR;

   reason = "PLANNED LAYER ORDER OK";
   return true;
}

bool ValidateLayerSLTP(string &reason)
{
   if(!RevalidateLayerSLTP)
   {
      reason = "LAYER SLTP REVALIDATION DISABLED";
      return true;
   }
   if(g_plannedLayerEntry <= 0.0 || g_plannedLayerSL <= 0.0 || g_plannedLayerTP <= 0.0)
   {
      reason = "INVALID PLANNED LAYER SLTP";
      return false;
   }
   if(g_reentryLayer.direction == LAYER_DIR_BUY && !(g_plannedLayerSL < g_plannedLayerEntry && g_plannedLayerEntry < g_plannedLayerTP))
   {
      reason = "BUY LAYER SLTP INVALID";
      return false;
   }
   if(g_reentryLayer.direction == LAYER_DIR_SELL && !(g_plannedLayerTP < g_plannedLayerEntry && g_plannedLayerEntry < g_plannedLayerSL))
   {
      reason = "SELL LAYER SLTP INVALID";
      return false;
   }
   reason = "LAYER SLTP VALID";
   return true;
}

bool ValidateLayerSpread(string &reason)
{
   g_reentryLayer.currentSpreadPoints = (double)g_currentSpreadPoints;
   if(!UseLayerSpreadFilter)
   {
      reason = "LAYER SPREAD FILTER DISABLED";
      return true;
   }
   if(g_currentSpreadPoints > (int)MaxLayerSpreadPoints)
   {
      reason = "LAYER SPREAD TOO HIGH";
      return false;
   }
   reason = "LAYER SPREAD OK";
   return true;
}

bool ValidateLayerMargin(string &reason)
{
   if(!UseLayerMarginCheck)
   {
      reason = "LAYER MARGIN CHECK DISABLED";
      return true;
   }

   ENUM_ORDER_TYPE orderType = (g_reentryLayer.direction == LAYER_DIR_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   double margin = 0.0;
   if(!OrderCalcMargin(orderType, _Symbol, g_plannedLayerLot, g_plannedLayerEntry, margin))
   {
      reason = "LAYER MARGIN CALC FAILED";
      return false;
   }
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(freeMargin <= margin)
   {
      reason = "INSUFFICIENT FREE MARGIN FOR LAYER";
      return false;
   }
   reason = "LAYER MARGIN OK";
   return true;
}

bool ValidateLayerStopsAndFreeze(string &reason)
{
   if(!UseLayerStopLevelValidation && !UseLayerFreezeLevelValidation)
   {
      reason = "LAYER STOP/FREEZE VALIDATION DISABLED";
      return true;
   }

   double minStopPoints = 0.0;
   if(UseLayerStopLevelValidation)
      minStopPoints = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double freezePoints = 0.0;
   if(UseLayerFreezeLevelValidation)
      freezePoints = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double required = MathMax(minStopPoints, freezePoints);

   if(required <= 0.0)
   {
      reason = "LAYER STOP/FREEZE OK";
      return true;
   }

   double slDistance = MathAbs(g_plannedLayerEntry - g_plannedLayerSL) / _Point;
   double tpDistance = MathAbs(g_plannedLayerTP - g_plannedLayerEntry) / _Point;
   if(slDistance < required || tpDistance < required)
   {
      reason = "LAYER STOP/FREEZE DISTANCE TOO CLOSE";
      return false;
   }

   reason = "LAYER STOP/FREEZE OK";
   return true;
}

bool IsLayerRiskApproved(string &reason)
{
   if(!UseLayerRiskControl)
   {
      reason = "LAYER RISK CONTROL DISABLED";
      return true;
   }

   if(g_plannedLayerRiskMoney <= 0.0)
   {
      reason = "LAYER RISK NOT CALCULATED";
      return false;
   }
   if(MaxLayerRiskMoney > 0.0 && g_plannedLayerRiskMoney > MaxLayerRiskMoney)
   {
      reason = "LAYER RISK BLOCK";
      return false;
   }

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskPercent = (equity > 0.0 ? (g_plannedLayerRiskMoney / equity) * 100.0 : 100.0);
   if(MaxLayerRiskPercent > 0.0 && riskPercent > MaxLayerRiskPercent)
   {
      reason = "LAYER RISK PERCENT BLOCK";
      return false;
   }

   g_totalLayerLots = CalculateTotalLayerLots();
   g_totalSymbolExposureLots = CalculateTotalSymbolExposureLots();
   double directionalExposure = CalculateDirectionalLayerExposureLots(g_reentryLayer.direction);
   if(MaxTotalLayerLotsPerDirection > 0.0 && (directionalExposure + g_plannedLayerLot) > MaxTotalLayerLotsPerDirection + 0.000001)
   {
      reason = "LAYER DIRECTIONAL LOT LIMIT BLOCK current=" + DoubleToString(directionalExposure,2) + " next=" + DoubleToString(g_plannedLayerLot,2);
      return false;
   }
   if(MaxTotalLayerExposureLots > 0.0 && (g_totalLayerLots + g_plannedLayerLot) > MaxTotalLayerExposureLots + 0.000001)
   {
      reason = "LAYER EXPOSURE BLOCK";
      return false;
   }
   if(MaxTotalSymbolExposureLots > 0.0 && (g_totalSymbolExposureLots + g_plannedLayerLot) > MaxTotalSymbolExposureLots + 0.000001)
   {
      reason = "SYMBOL EXPOSURE BLOCK";
      return false;
   }

   if(BlockLayerIfEquityDrawdown)
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(balance > 0.0)
      {
         double dd = ((balance - currentEquity) / balance) * 100.0;
         if(dd > MaxEquityDrawdownPercentForLayer)
         {
            reason = "EQUITY DRAWDOWN TOO HIGH FOR LAYER";
            return false;
         }
      }
   }

   reason = "LAYER RISK APPROVED";
   return true;
}

bool IsLayerExposureApproved(string &reason)
{
   g_totalLayerLots = CalculateTotalLayerLots();
   g_totalSymbolExposureLots = CalculateTotalSymbolExposureLots();
   g_reentryLayer.totalLayerLots = g_totalLayerLots;
   g_reentryLayer.totalSymbolLots = g_totalSymbolExposureLots;
   double directionalExposure = CalculateDirectionalLayerExposureLots(g_reentryLayer.direction);
   if(MaxTotalLayerLotsPerDirection > 0.0 && (directionalExposure + g_plannedLayerLot) > MaxTotalLayerLotsPerDirection + 0.000001)
   {
      reason = "LAYER DIRECTIONAL LOT LIMIT BLOCK current=" + DoubleToString(directionalExposure,2) + " next=" + DoubleToString(g_plannedLayerLot,2);
      return false;
   }
   if(MaxTotalLayerExposureLots > 0.0 && (g_totalLayerLots + g_plannedLayerLot) > MaxTotalLayerExposureLots + 0.000001)
   {
      reason = "LAYER EXPOSURE BLOCK";
      return false;
   }
   if(MaxTotalSymbolExposureLots > 0.0 && (g_totalSymbolExposureLots + g_plannedLayerLot) > MaxTotalSymbolExposureLots + 0.000001)
   {
      reason = "SYMBOL EXPOSURE BLOCK";
      return false;
   }
   reason = "LAYER EXPOSURE APPROVED";
   return true;
}

bool IsLayerBrokerApproved(string &reason)
{
   string r = "";
   if(!ValidateLayerSpread(r)) { reason = r; return false; }
   if(!ValidateLayerSLTP(r)) { reason = r; return false; }
   if(!ValidateLayerStopsAndFreeze(r)) { reason = r; return false; }
   if(!ValidateLayerMargin(r)) { reason = r; return false; }

   long tradeMode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(tradeMode == SYMBOL_TRADE_MODE_DISABLED)
   {
      reason = "SYMBOL TRADE MODE DISABLED";
      return false;
   }
   reason = "LAYER BROKER APPROVED";
   return true;
}

bool IsLayerAccountModeAllowed(string &reason)
{
   bool realLayerRequested = (EnableLayerExecution && !LayerSimulationOnly && AllowLayerOrders);
   if(!realLayerRequested)
   {
      reason = "LAYER ACCOUNT MODE OK - SIMULATION";
      return true;
   }

   if(IsFunctionalLayerOverrideActive())
   {
      reason = "LAYER ACCOUNT MODE APPROVED: FUNCTIONAL OVERRIDE ACTIVE";
      return true;
   }

   if(RequireHedgingAccountForRealLayers || BlockRealLayerOnNettingAccount)
   {
      long marginMode = AccountInfoInteger(ACCOUNT_MARGIN_MODE);
      if(marginMode != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      {
         reason = "NETTING ACCOUNT - REAL LAYER BLOCKED";
         return false;
      }
   }
   reason = "LAYER ACCOUNT MODE APPROVED";
   return true;
}

bool CanPlanLayer(string &reason)
{
   string r = "";
   if(!HasMainPositionForLayer()) { reason = "NO MAIN POSITION FOR LAYER"; return false; }
   if(!IsLayerDirectionAllowed(r)) { reason = r; return false; }
   if(!IsLayerCountAllowed(r)) { reason = r; return false; }

   if(!IsFunctionalLayerOverrideActive())
   {
      if(!IsMainPositionProtectedForLayer(r)) { reason = r; return false; }
      if(!IsLayerDistanceAllowed(r)) { reason = r; return false; }
      if(!IsLayerSignalApproved(r)) { reason = r; return false; }
   }
   else
   {
      g_layerDistanceApproved = true;
      g_layerSignalApproved = true;
      g_layerActionReason = "FUNCTIONAL OVERRIDE: LAYER PROTECTION/DISTANCE/SIGNAL BYPASSED FOR TEST";
   }

   if(!BuildPlannedLayerOrder(r)) { reason = r; return false; }

   if(IsFunctionalLayerOverrideActive())
   {
      g_plannedLayerLot = FunctionalNormalizeLot(ForceFunctionalFixedLot);
      g_reentryLayer.plannedLayerLot = g_plannedLayerLot;
   }

   if(!IsLayerRiskApproved(r) && !IsFunctionalLayerOverrideActive()) { reason = r; return false; }
   if(IsFunctionalLayerOverrideActive())
   {
      string safetyReason = "";
      if(!IsFunctionalSafetyApproved(ForceFunctionalFixedLot, safetyReason)) { reason = safetyReason; return false; }
      g_layerRiskApproved = true;
   }
   if(!IsLayerExposureApproved(r)) { reason = r; return false; }
   if(!IsLayerBrokerApproved(r)) { reason = r; return false; }
   if(!IsLayerAccountModeAllowed(r)) { reason = r; return false; }
   reason = (IsFunctionalLayerOverrideActive() ? "LAYER PLAN APPROVED: FUNCTIONAL OVERRIDE ACTIVE" : "LAYER PLAN APPROVED");
   return true;
}

bool CanExecuteLayerOrder(string &reason)
{
   string r = "";
   if(UseStage17DualSideConfirmation &&
      g_stage17Pair.pairId > 0 &&
      (g_stage17Pair.pairState == STAGE17_PAIR_ACTIVE ||
       g_stage17Pair.pairState == STAGE17_PAIR_DECIDED_WEAK_CLOSED))
   {
      reason = "STAGE17_ACTIVE_BLOCKS_REENTRY_LAYER";
      if(Stage17_DebugLogs)
         Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_CONFLICT_BLOCKED_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
               " conflict=REENTRY_LAYER source=CanExecuteLayerOrder reason=", reason);
      return false;
   }
   if(!IsLayerMasterAllowed(r)) { reason = r; return false; }
   if(!EnableLayerExecution) { reason = "LAYER EXECUTION BLOCKED: EnableLayerExecution=false"; return false; }
   if(LayerSimulationOnly) { reason = "LAYER EXECUTION BLOCKED: LayerSimulationOnly=true"; return false; }
   if(!AllowLayerOrders) { reason = "LAYER EXECUTION BLOCKED: AllowLayerOrders=false"; return false; }
   if(UseDiagnosticMode && !IsFunctionalLayerOverrideActive()) { reason = "LAYER EXECUTION BLOCKED: UseDiagnosticMode=true"; return false; }

   // STAGE 13 FINAL FULL: legacy Smart Scaler/Reentry Layer cannot scale without Stage13/Stage12 authority.
   if(UseStage13FinalAuthorityManager && Stage13_RequireStage12ForAllScales)
   {
      string st13ScaleReason = "";
      if(!Stage13_ScaleAuthorityGuard(st13ScaleReason))
      {
         reason = "STAGE13 SCALE BLOCK: " + st13ScaleReason;
         Stage13_AuditDecision("SCALE_BLOCKED", "Stage13", reason);
         return false;
      }
   }

   if(IsFunctionalLayerOverrideActive())
   {
      string safetyReason = "";
      if(!IsFunctionalSafetyApproved(ForceFunctionalFixedLot, safetyReason)) { reason = safetyReason; return false; }
      if(!g_reentryLayer.hasMainPosition) { reason = "LAYER EXECUTION BLOCKED: NO MAIN POSITION"; return false; }
      if(g_reentryLayer.mainPositionTicket <= 0) { reason = "LAYER EXECUTION BLOCKED: INVALID MAIN TICKET"; return false; }
      if(g_reentryLayer.direction == LAYER_DIR_NONE) { reason = "LAYER EXECUTION BLOCKED: NO LAYER DIRECTION"; return false; }
      if(CountAllMagicPositions() >= ForceFunctionalMaxTotalPositions) { reason = "LAYER EXECUTION BLOCKED: MAX TOTAL POSITIONS"; return false; }
      if(ForceFunctionalKeepNoHedgeProtection)
      {
         long mainType = GetMainPositionTypeByTicket(g_reentryLayer.mainPositionTicket);
         if(mainType == POSITION_TYPE_BUY && g_reentryLayer.direction != LAYER_DIR_BUY)
         {
            reason = "FUNCTIONAL SAFETY BLOCK: OPPOSITE LAYER SELL AGAINST BUY";
            return false;
         }
         if(mainType == POSITION_TYPE_SELL && g_reentryLayer.direction != LAYER_DIR_SELL)
         {
            reason = "FUNCTIONAL SAFETY BLOCK: OPPOSITE LAYER BUY AGAINST SELL";
            return false;
         }
      }
      string v32LayerReason = "";
      if(!IsV32LayerEntryAllowed(v32LayerReason))
      {
         reason = "V3.2 LAYER QUALITY BLOCK: " + v32LayerReason;
         AuditReentryLayer("[LAYER_EXECUTION][BLOCK_REASON] " + reason);
         AuditV32("[V3_2_LAYER_GATE][BLOCK_REASON] " + v32LayerReason);
         return false;
      }
      if(!CanPlanLayer(r)) { reason = r; return false; }
      reason = "LAYER EXECUTION APPROVED: FUNCTIONAL OVERRIDE ACTIVE";
      AuditReentryLayer("[FUNCTIONAL_OVERRIDE] LAYER EXECUTION APPROVED");
      return true;
   }

   string v32LayerReason2 = "";
   if(!IsV32LayerEntryAllowed(v32LayerReason2))
   {
      reason = "V3.2 LAYER QUALITY BLOCK: " + v32LayerReason2;
      AuditReentryLayer("[LAYER_EXECUTION][BLOCK_REASON] " + reason);
      AuditV32("[V3_2_LAYER_GATE][BLOCK_REASON] " + v32LayerReason2);
      return false;
   }
   if(!CanPlanLayer(r)) { reason = r; return false; }
   if(MinSecondsBetweenLayers > 0 && g_lastLayerExecutionTime > 0 && (TimeCurrent() - g_lastLayerExecutionTime) < MinSecondsBetweenLayers)
   {
      reason = "MIN SECONDS BETWEEN LAYERS NOT REACHED";
      return false;
   }
   if(PreventLayerSameCandle)
   {
      datetime barTime = iTime(_Symbol, _Period, 0);
      if(g_lastLayerCandleTime == barTime)
      {
         reason = "LAYER SAME CANDLE BLOCKED";
         return false;
      }
   }
   reason = "LAYER EXECUTION APPROVED";
   return true;
}

bool ExecuteLayerOrder(string &reason)
{
   reason = "";
   if(LayerSimulationOnly)
   {
      reason = "LAYER SIMULATION ONLY - NO ORDER SENT";
      return false;
   }
   if(!CanExecuteLayerOrder(reason))
      return false;

   if(IsFunctionalLayerOverrideActive())
   {
      if(CountAllMagicPositions() >= ForceFunctionalMaxTotalPositions)
      {
         reason = "[FUNCTIONAL_SAFETY] BLOCKED: MAX TOTAL POSITIONS";
         return false;
      }
      g_plannedLayerLot = FunctionalNormalizeLot(ForceFunctionalFixedLot);
      if(g_plannedLayerLot <= 0.0 || g_plannedLayerLot - ForceFunctionalFixedLot > 0.000001)
      {
         reason = "[FUNCTIONAL_SAFETY] BLOCKED: INVALID LOT";
         return false;
      }
   }

   int layerIndexToSend = GetNextLayerIndex();

   trade.SetExpertMagicNumber((ulong)MagicNumber);
   trade.SetDeviationInPoints(LayerDeviationPoints);

   bool sent = false;
   string comment = LayerOrderComment;
   double layerSLToSend = (UseServerSideLayerSLTP ? g_plannedLayerSL : 0.0);
   double layerTPToSend = (UseServerSideLayerSLTP ? g_plannedLayerTP : 0.0);
   string layerRole = g_stage12LastRole;
   if(layerRole == "" || layerRole == "NONE") layerRole = RoleForPositionIndexV4(Stage13_PositionCount());
   double layerEntry = (g_reentryLayer.direction == LAYER_DIR_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID));
   Stage15_PrepareLayerDynamicSLTP(g_reentryLayer.direction, layerRole, layerEntry, layerSLToSend, layerTPToSend);
   if(g_reentryLayer.direction == LAYER_DIR_BUY)
      sent = trade.Buy(g_plannedLayerLot, _Symbol, 0.0, layerSLToSend, layerTPToSend, comment + " BUY");
   else if(g_reentryLayer.direction == LAYER_DIR_SELL)
      sent = trade.Sell(g_plannedLayerLot, _Symbol, 0.0, layerSLToSend, layerTPToSend, comment + " SELL");
   else
   {
      reason = "NO LAYER DIRECTION";
      return false;
   }

   ulong resultOrder = trade.ResultOrder();
   string resultText = trade.ResultRetcodeDescription();
   if(sent)
   {
      if(UseStage13FinalAuthorityManager)
      {
         Stage12_MarkEntryExecuted(g_stage12LastRole);
         Stage13_AuditDecision("LAYER_EXECUTED", "ReentryLayer", reason);
      }
      g_layerSent = true;
      g_lastLayerTicket = resultOrder;
      g_lastLayerExecutionTime = TimeCurrent();
      g_lastLayerCandleTime = iTime(_Symbol, _Period, 0);
      g_reentryLayer.layerSent = true;
      g_reentryLayer.lastLayerTicket = resultOrder;
      g_reentryLayer.lastLayerTime = g_lastLayerExecutionTime;
      g_reentryLayer.lastLayerCandleTime = g_lastLayerCandleTime;
      g_reentryLayer.state = (g_reentryLayer.direction == LAYER_DIR_BUY ? LAYER_BUY_SENT : LAYER_SELL_SENT);
      g_reentryLayer.statusText = (g_reentryLayer.direction == LAYER_DIR_BUY ? "LAYER BUY SENT" : "LAYER SELL SENT");
      g_layerStatus = g_reentryLayer.statusText;
      reason = "[LAYER_SENT] layerIndex=" + IntegerToString(layerIndexToSend) +
               " lot=" + DoubleToString(g_plannedLayerLot, 2) +
               " direction=" + LayerDirectionToText(g_reentryLayer.direction) +
               " ticket=" + UlongToText(resultOrder);
      AuditReentryLayer(reason);
      if(IsFunctionalLayerOverrideActive())
      {
         AuditReentryLayer("[LAYER_EXECUTION] FUNCTIONAL LAYER SENT");
         reason = "[LAYER_EXECUTION] FUNCTIONAL LAYER SENT";
      }
      return true;
   }

   g_layerError = true;
   g_layerLastErrorText = resultText;
   g_reentryLayer.error = true;
   g_reentryLayer.lastErrorText = resultText;
   g_reentryLayer.state = LAYER_ERROR;
   reason = "LAYER EXECUTION ERROR: " + resultText;
   return false;
}

ENUM_LAYER_STATE DetectLayerState()
{
   if(!UseReentryLayerEngine)
      return LAYER_DISABLED;
   if(!HasMainPositionForLayer())
      return LAYER_NO_MAIN_POSITION;
   if(g_layerError)
      return LAYER_ERROR;
   if(g_layerSent)
      return (g_reentryLayer.direction == LAYER_DIR_BUY ? LAYER_BUY_SENT : LAYER_SELL_SENT);
   if(g_layerBlocked)
   {
      if(!g_layerRiskApproved) return LAYER_RISK_BLOCK;
      if(!g_layerDistanceApproved) return LAYER_DISTANCE_BLOCK;
      if(!g_layerSignalApproved) return LAYER_SIGNAL_BLOCK;
      if(!g_layerExposureApproved) return LAYER_EXPOSURE_BLOCK;
      if(!g_layerBrokerApproved) return LAYER_BROKER_BLOCK;
      return LAYER_BLOCKED;
   }
   if(g_layerReady)
   {
      if(LayerSimulationOnly || !EnableLayerExecution || !AllowLayerOrders)
         return LAYER_SIMULATION_ONLY;
      return (g_reentryLayer.direction == LAYER_DIR_BUY ? LAYER_BUY_READY : LAYER_SELL_READY);
   }
   return LAYER_MONITORING;
}

bool CanPrintLayerLog(string reason)
{
   if(!PrintLayerDiagnostics)
      return false;
   datetime now = TimeCurrent();
   if(g_lastLayerLoggedReason == reason && (now - g_lastLayerLogTime) < MinSecondsBetweenLayerLogs)
      return false;
   g_lastLayerLoggedReason = reason;
   g_lastLayerLogTime = now;
   return true;
}

void AuditReentryLayer(string message)
{
   if(!PrintLayerDiagnostics)
      return;
   AuditLog("REENTRY_LAYER", message);
}

void UpdateReentryLayerEngine()
{
   if(!UseReentryLayerEngine)
   {
      ResetReentryLayerDisabled();
      return;
   }

   if(UseStage17DualSideConfirmation &&
      g_stage17Pair.pairId > 0 &&
      (g_stage17Pair.pairState == STAGE17_PAIR_ACTIVE ||
       g_stage17Pair.pairState == STAGE17_PAIR_DECIDED_WEAK_CLOSED))
   {
      g_reentryLayer.active = true;
      g_reentryLayer.simulationOnly = LayerSimulationOnly;
      g_reentryLayer.lastUpdateTime = TimeCurrent();
      g_reentryLayer.state = LAYER_BLOCKED;
      g_reentryLayer.statusText = "BLOCKED_BY_STAGE17";
      g_reentryLayer.reason = "STAGE17_ACTIVE_BLOCKS_REENTRY_LAYER";
      g_reentryLayer.blockReason = "STAGE17_ACTIVE_BLOCKS_REENTRY_LAYER";
      g_reentryLayer.actionReason = "WAITING_STAGE17_PAIR_RESOLUTION";
      g_reentryLayer.layerBlocked = true;
      g_reentryLayer.layerReady = false;
      g_reentryLayer.layerSent = false;
      SyncLayerGlobals();
      if(Stage17_DebugLogs)
      {
         Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_CONFLICT_BLOCKED_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
               " conflict=REENTRY_LAYER source=UpdateReentryLayerEngine reason=STAGE17_ACTIVE_BLOCKS_REENTRY_LAYER");
         Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_LEGACY_ENGINE_BLOCKED_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
               " engine=ReentryLayerEngine reason=STAGE17_ACTIVE_BLOCKS_REENTRY_LAYER");
      }
      return;
   }

   g_reentryLayer.active = true;
   g_reentryLayer.simulationOnly = LayerSimulationOnly;
   g_reentryLayer.lastUpdateTime = TimeCurrent();
   g_lastLayerUpdateTime = g_reentryLayer.lastUpdateTime;

   string reason = "";
   bool hasMain = HasMainPositionForLayer(reason);

   if(!hasMain)
   {
      ResetReentryLayerPlanning();
      ResetReentryLayerMainPosition();

      g_reentryLayer.active = true;
      g_reentryLayer.simulationOnly = LayerSimulationOnly;
      g_reentryLayer.state = LAYER_NO_MAIN_POSITION;
      g_reentryLayer.statusText = "NO_MAIN_POSITION";
      g_reentryLayer.reason = "NO MAIN POSITION FOR LAYER";
      g_reentryLayer.blockReason = "NO MAIN POSITION FOR LAYER";
      g_reentryLayer.actionReason = "WAITING MAIN POSITION";
      g_reentryLayer.layerBlocked = true;
      g_reentryLayer.layerReady = false;
      g_reentryLayer.layerSent = false;
      g_reentryLayer.direction = LAYER_DIR_NONE;
      g_reentryLayer.currentLayerCount = CountCurrentLayers();
      g_reentryLayer.buyLayerCount = CountLayersByDirection(LAYER_DIR_BUY);
      g_reentryLayer.sellLayerCount = CountLayersByDirection(LAYER_DIR_SELL);
      g_reentryLayer.totalLayerLots = CalculateTotalLayerLots();
      g_reentryLayer.totalSymbolLots = CalculateTotalSymbolExposureLots();
      g_reentryLayer.maxLayersAllowed = MaxTotalLayers;
      g_reentryLayer.currentSpreadPoints = (double)g_currentSpreadPoints;
      SyncLayerGlobals();

      if(CanPrintLayerLog("NO MAIN POSITION FOR LAYER"))
         AuditReentryLayer("NO MAIN POSITION FOR LAYER");
      return;
   }

   g_reentryLayer.direction = DetectLayerDirection();

   if(g_reentryLayer.direction == LAYER_DIR_NONE)
   {
      ResetReentryLayerPlanning();
      g_reentryLayer.state = LAYER_BLOCKED;
      g_reentryLayer.statusText = "DIRECTION_BLOCK";
      g_reentryLayer.reason = "LAYER DIRECTION NOT DETECTED";
      g_reentryLayer.blockReason = "LAYER DIRECTION NOT DETECTED";
      g_reentryLayer.layerBlocked = true;
      g_reentryLayer.layerReady = false;
      SyncLayerGlobals();
      return;
   }

   g_reentryLayer.currentLayerCount = CountCurrentLayers();
   g_reentryLayer.buyLayerCount = CountLayersByDirection(LAYER_DIR_BUY);
   g_reentryLayer.sellLayerCount = CountLayersByDirection(LAYER_DIR_SELL);
   g_reentryLayer.totalLayerLots = CalculateTotalLayerLots();
   g_reentryLayer.totalSymbolLots = CalculateTotalSymbolExposureLots();
   g_reentryLayer.maxLayersAllowed = MaxTotalLayers;
   g_reentryLayer.currentSpreadPoints = (double)g_currentSpreadPoints;

   ResetReentryLayerPlanning();

   string planReason = "";
   bool planned = CanPlanLayer(planReason);
   if(!planned)
   {
      g_reentryLayer.layerBlocked = true;
      g_reentryLayer.layerReady = false;
      g_reentryLayer.reason = planReason;
      g_reentryLayer.blockReason = planReason;
      g_reentryLayer.actionReason = "LAYER PLAN BLOCKED";
      g_reentryLayer.statusText = "BLOCKED";

      if(StringFind(planReason, "DISTANCE") >= 0)
         g_reentryLayer.state = LAYER_DISTANCE_BLOCK;
      else if(StringFind(planReason, "SIGNAL") >= 0 || StringFind(planReason, "FLOW") >= 0 || StringFind(planReason, "SCORE") >= 0)
         g_reentryLayer.state = LAYER_SIGNAL_BLOCK;
      else if(StringFind(planReason, "RISK") >= 0)
         g_reentryLayer.state = LAYER_RISK_BLOCK;
      else if(StringFind(planReason, "EXPOSURE") >= 0)
         g_reentryLayer.state = LAYER_EXPOSURE_BLOCK;
      else if(StringFind(planReason, "SPREAD") >= 0 || StringFind(planReason, "MARGIN") >= 0 || StringFind(planReason, "STOP") >= 0 || StringFind(planReason, "BROKER") >= 0)
         g_reentryLayer.state = LAYER_BROKER_BLOCK;
      else
         g_reentryLayer.state = LAYER_BLOCKED;

      SyncLayerGlobals();
      if(CanPrintLayerLog(g_reentryLayer.statusText + " | " + planReason))
         AuditReentryLayer(g_reentryLayer.statusText + " | " + planReason);
      return;
   }

   g_reentryLayer.layerReady = true;
   g_reentryLayer.layerBlocked = false;
   g_reentryLayer.buyLayerReady = (g_reentryLayer.direction == LAYER_DIR_BUY);
   g_reentryLayer.sellLayerReady = (g_reentryLayer.direction == LAYER_DIR_SELL);
   g_reentryLayer.riskApproved = true;
   g_reentryLayer.distanceApproved = true;
   g_reentryLayer.signalApproved = true;
   g_reentryLayer.exposureApproved = true;
   g_reentryLayer.brokerApproved = true;
   g_reentryLayer.reason = "LAYER PLAN APPROVED";
   g_reentryLayer.blockReason = "NONE";

   if(g_reentryLayer.direction == LAYER_DIR_BUY)
   {
      g_reentryLayer.state = LAYER_BUY_READY;
      g_reentryLayer.statusText = "BUY_LAYER_READY";
   }
   else
   {
      g_reentryLayer.state = LAYER_SELL_READY;
      g_reentryLayer.statusText = "SELL_LAYER_READY";
   }

   int readyLayerIndex = GetNextLayerIndex();
   string readyMsg = "[LAYER_READY] layerIndex=" + IntegerToString(readyLayerIndex) +
                     " lot=" + DoubleToString(g_plannedLayerLot, 2) +
                     " direction=" + LayerDirectionToText(g_reentryLayer.direction);
   if(CanPrintLayerLog(readyMsg))
      AuditReentryLayer(readyMsg);

   if(LayerSimulationOnly || !EnableLayerExecution || !AllowLayerOrders)
   {
      g_reentryLayer.state = LAYER_SIMULATION_ONLY;
      g_reentryLayer.statusText = "LAYER_SIMULATION_ONLY";
      g_reentryLayer.actionReason = "LAYER SIMULATION ONLY - NO ORDER SENT";
      g_reentryLayer.layerSent = false;
      SyncLayerGlobals();
      string simMsg = "[LAYER_SIMULATION_ONLY] layerIndex=" + IntegerToString(GetNextLayerIndex()) +
                      " lot=" + DoubleToString(g_plannedLayerLot, 2) +
                      " direction=" + LayerDirectionToText(g_reentryLayer.direction);
      if(CanPrintLayerLog(simMsg))
         AuditReentryLayer(simMsg);
      return;
   }

   string execReason = "";
   if(CanExecuteLayerOrder(execReason))
   {
      ExecuteLayerOrder(execReason);
      g_reentryLayer.reason = execReason;
      g_reentryLayer.actionReason = execReason;
      SyncLayerGlobals();
      if(CanPrintLayerLog(execReason))
         AuditReentryLayer(execReason + " | Ticket=" + UlongToText(g_lastLayerTicket));
      return;
   }

   g_reentryLayer.layerBlocked = true;
   g_reentryLayer.layerReady = false;
   g_reentryLayer.state = LAYER_BLOCKED;
   g_reentryLayer.statusText = "EXECUTION_BLOCKED";
   g_reentryLayer.reason = execReason;
   g_reentryLayer.blockReason = execReason;
   g_reentryLayer.actionReason = execReason;
   SyncLayerGlobals();
   if(CanPrintLayerLog(execReason))
      AuditReentryLayer(execReason);
}

bool HasLayerReady()
{
   return g_layerReady;
}

bool HasLayerSent()
{
   return g_layerSent;
}

double GetPlannedLayerLot()
{
   return g_plannedLayerLot;
}

string GetLayerReason()
{
   return g_layerReason;
}


//+------------------------------------------------------------------+
//| FIX3 V3.1 - Smart Exit Real Engine                               |
//+------------------------------------------------------------------+
void AuditSmartExit(string message)
{
   AuditLog("SMART_EXIT", message);
}

bool IsSmartExitPosition(ulong ticket, string &reason)
{
   reason = "";
   if(ticket == 0)
   {
      reason = "ZERO_TICKET";
      return false;
   }
   if(!PositionSelectByTicket(ticket))
   {
      reason = "POSITION_NOT_FOUND_BEFORE_ACTION";
      return false;
   }
   string sym = PositionGetString(POSITION_SYMBOL);
   if(sym != _Symbol)
   {
      reason = "POSITION_SYMBOL_MISMATCH";
      return false;
   }
   long magic = (long)PositionGetInteger(POSITION_MAGIC);
   if(magic != MagicNumber)
   {
      reason = "POSITION_MAGIC_MISMATCH";
      return false;
   }
   return true;
}

int CountSmartExitPositions()
{
   int count = 0;
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      count++;
   }
   return count;
}

bool ValidateSmartExitEnvironment(string &reason)
{
   reason = "OK";
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      reason = "TERMINAL_TRADE_NOT_ALLOWED";
      g_lastEnvironmentStatus = "BLOCKED";
      g_lastEnvironmentBlock = reason;
      AuditSmartExit("[SMART_EXIT][ENV_BLOCK] " + reason);
      return false;
   }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      reason = "MQL_TRADE_NOT_ALLOWED";
      g_lastEnvironmentStatus = "BLOCKED";
      g_lastEnvironmentBlock = reason;
      AuditSmartExit("[SMART_EXIT][ENV_BLOCK] " + reason);
      return false;
   }
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
   {
      reason = "ACCOUNT_TRADE_NOT_ALLOWED";
      g_lastEnvironmentStatus = "BLOCKED";
      g_lastEnvironmentBlock = reason;
      AuditSmartExit("[SMART_EXIT][ENV_BLOCK] " + reason);
      return false;
   }
   long tradeMode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(tradeMode == SYMBOL_TRADE_MODE_DISABLED)
   {
      reason = "SYMBOL_TRADE_NOT_ALLOWED";
      g_lastEnvironmentStatus = "BLOCKED";
      g_lastEnvironmentBlock = reason;
      AuditSmartExit("[SMART_EXIT][ENV_BLOCK] " + reason);
      return false;
   }
   g_lastEnvironmentStatus = "OK";
   g_lastEnvironmentBlock = "NONE";
   return true;
}

int FindSmartExitStateIndex(ulong ticket)
{
   int size = ArraySize(g_smartExitStates);
   for(int i = 0; i < size; i++)
   {
      if(g_smartExitStates[i].ticket == ticket)
         return i;
   }
   return -1;
}

int EnsureSmartExitState(ulong ticket)
{
   int idx = FindSmartExitStateIndex(ticket);
   if(idx >= 0)
      return idx;
   int size = ArraySize(g_smartExitStates);
   ArrayResize(g_smartExitStates, size + 1);
   g_smartExitStates[size].ticket = ticket;
   g_smartExitStates[size].peakProfitMoney = 0.0;
   g_smartExitStates[size].peakProfitPoints = 0.0;
   g_smartExitStates[size].breakEvenApplied = false;
   g_smartExitStates[size].modifyRetries = 0;
   g_smartExitStates[size].lastModifyTime = 0;
   g_smartExitStates[size].lastCloseAttemptTime = 0;
   g_smartExitStates[size].lastExitAction = "NEW";
   g_smartExitStates[size].lastBlockReason = "NONE";
   return size;
}

void SetSmartExitTicketBlockReason(ulong ticket, string reason)
{
   int idx = EnsureSmartExitState(ticket);
   g_smartExitStates[idx].lastBlockReason = reason;
   g_lastSmartExitBlockReason = reason;
}

double SmartExitProfitPoints(ulong ticket)
{
   string reason = "";
   if(!IsSmartExitPosition(ticket, reason))
      return 0.0;
   if(_Point <= 0.0)
      return 0.0;
   long type = (long)PositionGetInteger(POSITION_TYPE);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(type == POSITION_TYPE_BUY)
      return (bid - openPrice) / _Point;
   if(type == POSITION_TYPE_SELL)
      return (openPrice - ask) / _Point;
   return 0.0;
}

void UpdateSmartExitTicketState(ulong ticket)
{
   string reason = "";
   if(!IsSmartExitPosition(ticket, reason))
      return;
   int idx = EnsureSmartExitState(ticket);
   double profitMoney = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   double profitPoints = SmartExitProfitPoints(ticket);
   if(profitMoney > g_smartExitStates[idx].peakProfitMoney)
      g_smartExitStates[idx].peakProfitMoney = profitMoney;
   if(profitPoints > g_smartExitStates[idx].peakProfitPoints)
      g_smartExitStates[idx].peakProfitPoints = profitPoints;
}

void RemoveClosedTicketStates()
{
   for(int i = ArraySize(g_smartExitStates) - 1; i >= 0; i--)
   {
      ulong ticket = g_smartExitStates[i].ticket;
      if(ticket == 0 || !PositionSelectByTicket(ticket))
      {
         for(int j = i; j < ArraySize(g_smartExitStates) - 1; j++)
            g_smartExitStates[j] = g_smartExitStates[j + 1];
         ArrayResize(g_smartExitStates, ArraySize(g_smartExitStates) - 1);
      }
   }
}

bool ValidateModifyLevels(ENUM_POSITION_TYPE posType, double currentPrice, double newSL, double newTP, string &reason)
{
   reason = "OK";
   if(_Point <= 0.0)
   {
      reason = "INVALID_POINT";
      return false;
   }
   if(newSL <= 0.0 || newTP <= 0.0)
   {
      reason = "SL_OR_TP_ZERO_NOT_ALLOWED";
      return false;
   }
   long stopLevel = (long)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long freezeLevel = (long)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double minDistance = (double)MathMax(stopLevel, freezeLevel) * _Point;
   if(posType == POSITION_TYPE_BUY)
   {
      if(newSL >= currentPrice)
      {
         reason = "BUY_SL_NOT_BELOW_PRICE";
         return false;
      }
      if(newTP <= currentPrice)
      {
         reason = "BUY_TP_NOT_ABOVE_PRICE";
         return false;
      }
      if((currentPrice - newSL) < minDistance || (newTP - currentPrice) < minDistance)
      {
         reason = "BUY_STOPLEVEL_FREEZELEVEL_BLOCK";
         return false;
      }
   }
   else if(posType == POSITION_TYPE_SELL)
   {
      if(newSL <= currentPrice)
      {
         reason = "SELL_SL_NOT_ABOVE_PRICE";
         return false;
      }
      if(newTP >= currentPrice)
      {
         reason = "SELL_TP_NOT_BELOW_PRICE";
         return false;
      }
      if((newSL - currentPrice) < minDistance || (currentPrice - newTP) < minDistance)
      {
         reason = "SELL_STOPLEVEL_FREEZELEVEL_BLOCK";
         return false;
      }
   }
   else
   {
      reason = "UNKNOWN_POSITION_TYPE";
      return false;
   }
   return true;
}

bool ModifyPositionSmart(ulong ticket, double newSL, double newTP, string modifyReason)
{
   string envReason = "";
   if(!ValidateSmartExitEnvironment(envReason))
   {
      g_lastSmartExitBlockReason = envReason;
      return false;
   }
   if(SmartExitSimulationOnly || !AllowSmartExitRealModify)
   {
      g_lastSmartExitBlockReason = "SMART_MODIFY_NOT_ALLOWED_OR_SIMULATION_ONLY";
      AuditSmartExit("[SMART_MODIFY][BLOCK_REASON] " + g_lastSmartExitBlockReason + " ticket=" + UlongToText(ticket));
      return false;
   }
   string posReason = "";
   if(!IsSmartExitPosition(ticket, posReason))
   {
      g_lastSmartExitBlockReason = posReason;
      AuditSmartExit("[SMART_MODIFY][BLOCK_REASON] " + posReason + " ticket=" + UlongToText(ticket));
      return false;
   }
   int idx = EnsureSmartExitState(ticket);
   datetime now = TimeCurrent();
   if(g_smartExitStates[idx].lastModifyTime > 0 && now - g_smartExitStates[idx].lastModifyTime < MinSecondsBetweenPositionModifies)
   {
      g_lastSmartExitBlockReason = "MODIFY_COOLDOWN_ACTIVE";
      AuditSmartExit("[SMART_MODIFY][BLOCK_REASON] MODIFY_COOLDOWN_ACTIVE ticket=" + UlongToText(ticket));
      return false;
   }
   if(g_smartExitStates[idx].modifyRetries >= MaxPositionModifyRetries)
   {
      g_lastSmartExitBlockReason = "MAX_MODIFY_RETRIES_REACHED";
      AuditSmartExit("[SMART_MODIFY][BLOCK_REASON] MAX_MODIFY_RETRIES_REACHED ticket=" + UlongToText(ticket));
      return false;
   }
   long type = (long)PositionGetInteger(POSITION_TYPE);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double currentPrice = (type == POSITION_TYPE_BUY ? bid : ask);
   string levelReason = "";
   if(!ValidateModifyLevels((ENUM_POSITION_TYPE)type, currentPrice, newSL, newTP, levelReason))
   {
      g_lastSmartExitBlockReason = levelReason;
      AuditSmartExit("[SMART_MODIFY][BLOCK_REASON] " + levelReason + " ticket=" + UlongToText(ticket));
      return false;
   }
   trade.SetExpertMagicNumber((ulong)MagicNumber);
   trade.SetDeviationInPoints(PositionModifyDeviationPoints);
   AuditSmartExit("[SMART_MODIFY] MODIFY_SENT ticket=" + UlongToText(ticket) + " reason=" + modifyReason);
   if(trade.PositionModify(ticket, NormalizeDouble(newSL, _Digits), NormalizeDouble(newTP, _Digits)))
   {
      g_smartExitStates[idx].lastModifyTime = now;
      g_smartExitStates[idx].modifyRetries = 0;
      g_smartExitStates[idx].lastExitAction = modifyReason;
      g_lastModifiedTicket = ticket;
      g_lastSmartExitAction = modifyReason;
      AuditSmartExit("[SMART_MODIFY] MODIFY_OK ticket=" + UlongToText(ticket));
      return true;
   }
   g_smartExitStates[idx].modifyRetries++;
   g_lastSmartExitBlockReason = trade.ResultRetcodeDescription();
   AuditSmartExit("[SMART_MODIFY] MODIFY_FAIL ticket=" + UlongToText(ticket) + " retcode=" + trade.ResultRetcodeDescription());
   return false;
}

bool ClosePositionSmart(ulong ticket, string closeReason)
{
   double traceNetProfit = 0.0;
   if(PositionSelectByTicket(ticket))
      traceNetProfit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

   AuditSmartExit("[V4_CLOSE_TRACE] REQUEST_RECEIVED ticket=" + UlongToText(ticket) + " module=LEGACY_SMART_EXIT reason=" + closeReason + " netProfit=" + DoubleToString(traceNetProfit,2));

   string envReason = "";
   if(!ValidateSmartExitEnvironment(envReason))
   {
      g_lastSmartExitBlockReason = envReason;
      AuditSmartExit("[SMART_CLOSE][BLOCK_REASON] " + envReason + " ticket=" + UlongToText(ticket));
      return false;
   }

   if(SmartExitSimulationOnly || !AllowSmartExitRealClose)
   {
      g_lastSmartExitBlockReason = "SMART_CLOSE_NOT_ALLOWED_OR_SIMULATION_ONLY";
      AuditSmartExit("[SMART_CLOSE][BLOCK_REASON] " + g_lastSmartExitBlockReason + " ticket=" + UlongToText(ticket));
      return false;
   }

   string posReason = "";
   if(!IsSmartExitPosition(ticket, posReason))
   {
      g_lastSmartExitBlockReason = posReason;
      AuditSmartExit("[SMART_CLOSE][BLOCK_REASON] " + posReason + " ticket=" + UlongToText(ticket));
      return false;
   }

   int idx = EnsureSmartExitState(ticket);
   datetime now = TimeCurrent();
   if(g_smartExitStates[idx].lastCloseAttemptTime > 0 && now - g_smartExitStates[idx].lastCloseAttemptTime < MinSecondsBetweenSmartCloses)
   {
      g_lastSmartExitBlockReason = "SMART_CLOSE_COOLDOWN_ACTIVE";
      AuditSmartExit("[SMART_CLOSE][BLOCK_REASON] SMART_CLOSE_COOLDOWN_ACTIVE ticket=" + UlongToText(ticket));
      return false;
   }
   g_smartExitStates[idx].lastCloseAttemptTime = now;

   traceNetProfit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

   string upperReason = closeReason;
   StringToUpper(upperReason);
   bool isCriticalExit = false;
   if(StringFind(upperReason, "EMERGENCY") >= 0) isCriticalExit = true;
   if(StringFind(upperReason, "DAILY") >= 0) isCriticalExit = true;
   if(StringFind(upperReason, "MARGIN") >= 0) isCriticalExit = true;
   if(StringFind(upperReason, "RISK") >= 0) isCriticalExit = true;
   if(StringFind(upperReason, "SL_HIT") >= 0) isCriticalExit = true;
   if(StringFind(upperReason, "BREAK_EVEN") >= 0 || StringFind(upperReason, "VIRTUAL_LOCK_CLOSE") >= 0) isCriticalExit = true;

   // FIX3.2: legacy Smart Exit no longer executes trade.PositionClose directly.
   // It must request a V4 Orchestrator decision so Profit Hold / Micro Guard / Runner Protection can intercept weak micro profit exits.
   bool ok = RequestV4ExitOrchestrator(ticket, "LEGACY_SMART_EXIT", closeReason, traceNetProfit, isCriticalExit, false);
   if(ok)
   {
      g_lastClosedTicket = ticket;
      g_lastSmartExitAction = closeReason;
      AuditSmartExit("[SMART_CLOSE] ROUTED_TO_ORCHESTRATOR_OK ticket=" + UlongToText(ticket) + " reason=" + closeReason);
      return true;
   }

   g_lastSmartExitBlockReason = "ROUTED_TO_ORCHESTRATOR_BLOCKED_OR_FAILED";
   AuditSmartExit("[SMART_CLOSE][BLOCK_REASON] ROUTED_TO_ORCHESTRATOR_BLOCKED_OR_FAILED ticket=" + UlongToText(ticket) + " reason=" + closeReason);
   return false;
}

double GetExitATRPoints()
{
   int period = ExitATRPeriod;
   if(period <= 0)
      period = 14;
   int handle = iATR(_Symbol, PERIOD_M1, period);
   if(handle == INVALID_HANDLE || _Point <= 0.0)
      return 250.0;
   double buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyBuffer(handle, 0, 0, 1, buffer) <= 0)
   {
      IndicatorRelease(handle);
      return 250.0;
   }
   IndicatorRelease(handle);
   if(buffer[0] <= 0.0)
      return 250.0;
   return buffer[0] / _Point;
}

bool ApplyBreakEvenReal(ulong ticket, string &reason)
{
   reason = "";
   if(!UseBreakEvenReal)
   {
      reason = "BE_DISABLED";
      return false;
   }
   string posReason = "";
   if(!IsSmartExitPosition(ticket, posReason))
   {
      reason = posReason;
      return false;
   }
   int idx = EnsureSmartExitState(ticket);
   if(BreakEvenOnlyOnce && g_smartExitStates[idx].breakEvenApplied)
   {
      reason = "BE_ALREADY_APPLIED";
      return false;
   }
   double profitPoints = SmartExitProfitPoints(ticket);
   double profitMoney = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   if(profitPoints < BreakEvenTriggerPoints)
   {
      reason = "BE_TRIGGER_NOT_REACHED";
      return false;
   }
   if(BreakEvenRequirePositiveProfit && profitMoney <= 0.0)
   {
      reason = "BE_PROFIT_NOT_POSITIVE";
      return false;
   }
   long type = (long)PositionGetInteger(POSITION_TYPE);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double oldSL = PositionGetDouble(POSITION_SL);
   double oldTP = PositionGetDouble(POSITION_TP);
   if(oldTP <= 0.0)
   {
      reason = "BE_TP_MISSING";
      return false;
   }
   double newSL = oldSL;
   if(type == POSITION_TYPE_BUY)
   {
      newSL = NormalizeDouble(openPrice + BreakEvenOffsetPoints * _Point, _Digits);
      if(oldSL > 0.0 && newSL <= oldSL)
      {
         reason = "BE_WOULD_NOT_IMPROVE_SL";
         return false;
      }
   }
   else if(type == POSITION_TYPE_SELL)
   {
      newSL = NormalizeDouble(openPrice - BreakEvenOffsetPoints * _Point, _Digits);
      if(oldSL > 0.0 && newSL >= oldSL)
      {
         reason = "BE_WOULD_NOT_IMPROVE_SL";
         return false;
      }
   }
   else
   {
      reason = "BE_UNKNOWN_TYPE";
      return false;
   }
   if(SmartExitSimulationOnly || !AllowBreakEvenModify)
   {
      reason = "[BE_REAL] SIMULATION_ONLY plannedSL=" + DoubleToString(newSL, _Digits);
      AuditSmartExit(reason);
      return false;
   }
   if(ModifyPositionSmart(ticket, newSL, oldTP, "BE_REAL"))
   {
      g_smartExitStates[idx].breakEvenApplied = true;
      reason = "BE_REAL_MODIFY_OK";
      AuditSmartExit("[BE_REAL] MODIFY_OK ticket=" + UlongToText(ticket));
      return true;
   }
   reason = g_lastSmartExitBlockReason;
   AuditSmartExit("[BE_REAL][BLOCK_REASON] " + reason);
   return false;
}

bool ApplySmartTrailingReal(ulong ticket, string &reason)
{
   reason = "";
   if(!UseSmartTrailingReal)
   {
      reason = "TRAIL_DISABLED";
      return false;
   }
   string posReason = "";
   if(!IsSmartExitPosition(ticket, posReason))
   {
      reason = posReason;
      return false;
   }
   double profitPoints = SmartExitProfitPoints(ticket);
   if(profitPoints < TrailingStartPoints)
   {
      reason = "TRAIL_START_NOT_REACHED";
      return false;
   }
   long type = (long)PositionGetInteger(POSITION_TYPE);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double oldSL = PositionGetDouble(POSITION_SL);
   double oldTP = PositionGetDouble(POSITION_TP);
   if(oldSL <= 0.0 || oldTP <= 0.0)
   {
      reason = "TRAIL_SL_OR_TP_MISSING";
      return false;
   }
   if(TrailOnlyAfterBreakEven)
   {
      if(type == POSITION_TYPE_BUY && oldSL < openPrice)
      {
         reason = "TRAIL_WAITING_BE";
         return false;
      }
      if(type == POSITION_TYPE_SELL && oldSL > openPrice)
      {
         reason = "TRAIL_WAITING_BE";
         return false;
      }
   }
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double newSL = oldSL;
   if(type == POSITION_TYPE_BUY)
   {
      newSL = NormalizeDouble(bid - TrailingDistancePoints * _Point, _Digits);
      if(newSL <= oldSL + TrailingStepPoints * _Point)
      {
         reason = "TRAIL_STEP_NOT_REACHED";
         return false;
      }
   }
   else if(type == POSITION_TYPE_SELL)
   {
      newSL = NormalizeDouble(ask + TrailingDistancePoints * _Point, _Digits);
      if(newSL >= oldSL - TrailingStepPoints * _Point)
      {
         reason = "TRAIL_STEP_NOT_REACHED";
         return false;
      }
   }
   else
   {
      reason = "TRAIL_UNKNOWN_TYPE";
      return false;
   }
   if(SmartExitSimulationOnly || !AllowTrailingModify)
   {
      reason = "[TRAIL_REAL] SIMULATION_ONLY plannedSL=" + DoubleToString(newSL, _Digits);
      AuditSmartExit(reason);
      return false;
   }
   if(ModifyPositionSmart(ticket, newSL, oldTP, "TRAIL_REAL"))
   {
      reason = "TRAIL_REAL_MODIFY_OK";
      AuditSmartExit("[TRAIL_REAL] MODIFY_OK ticket=" + UlongToText(ticket));
      return true;
   }
   reason = g_lastSmartExitBlockReason;
   AuditSmartExit("[TRAIL_REAL][BLOCK_REASON] " + reason);
   return false;
}

bool ApplyDynamicTPReal(ulong ticket, string &reason)
{
   reason = "";
   if(!UseATRDynamicExit)
   {
      reason = "DYNAMIC_TP_DISABLED";
      return false;
   }
   string posReason = "";
   if(!IsSmartExitPosition(ticket, posReason))
   {
      reason = posReason;
      return false;
   }
   long type = (long)PositionGetInteger(POSITION_TYPE);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double oldSL = PositionGetDouble(POSITION_SL);
   double oldTP = PositionGetDouble(POSITION_TP);
   if(oldSL <= 0.0 || oldTP <= 0.0)
   {
      reason = "DYNAMIC_TP_SL_OR_TP_MISSING";
      return false;
   }
   double atrPoints = GetExitATRPoints();
   double dynamicPoints = atrPoints * ATRDynamicTPMultiplier;
   dynamicPoints = MathMax((double)MinDynamicTPPoints, MathMin((double)MaxDynamicTPPoints, dynamicPoints));
   double newTP = oldTP;
   if(type == POSITION_TYPE_BUY)
      newTP = NormalizeDouble(openPrice + dynamicPoints * _Point, _Digits);
   else if(type == POSITION_TYPE_SELL)
      newTP = NormalizeDouble(openPrice - dynamicPoints * _Point, _Digits);
   else
   {
      reason = "DYNAMIC_TP_UNKNOWN_TYPE";
      return false;
   }
   if(MathAbs(newTP - oldTP) < MinTPModifyDifferencePoints * _Point)
   {
      reason = "DYNAMIC_TP_DIFF_TOO_SMALL";
      return false;
   }
   if(SmartExitSimulationOnly || !AllowSmartExitRealModify)
   {
      reason = "[DYNAMIC_TP] SIMULATION_ONLY plannedTP=" + DoubleToString(newTP, _Digits);
      AuditSmartExit(reason);
      return false;
   }
   if(ModifyPositionSmart(ticket, oldSL, newTP, "DYNAMIC_TP"))
   {
      reason = "DYNAMIC_TP_MODIFY_OK";
      AuditSmartExit("[DYNAMIC_TP] MODIFY_OK ticket=" + UlongToText(ticket));
      return true;
   }
   reason = g_lastSmartExitBlockReason;
   AuditSmartExit("[DYNAMIC_TP][BLOCK_REASON] " + reason);
   return false;
}

bool ApplyProfitProtectionReal(ulong ticket, string &reason)
{
   reason = "";
   if(!UseProfitProtectionReal)
   {
      reason = "PROFIT_PROTECTION_DISABLED";
      return false;
   }
   string posReason = "";
   if(!IsSmartExitPosition(ticket, posReason))
   {
      reason = posReason;
      return false;
   }
   int idx = EnsureSmartExitState(ticket);
   double currentProfit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   double peakProfit = g_smartExitStates[idx].peakProfitMoney;
   if(currentProfit > peakProfit)
   {
      g_smartExitStates[idx].peakProfitMoney = currentProfit;
      peakProfit = currentProfit;
      AuditSmartExit("[PROFIT_PROTECTION] PEAK_UPDATED ticket=" + UlongToText(ticket) + " peak=" + DoubleToString(peakProfit, 2));
   }
   if(peakProfit < ProfitProtectionTriggerMoney)
   {
      reason = "PROFIT_PROTECTION_TRIGGER_NOT_REACHED";
      return false;
   }
   if(currentProfit < ProfitProtectionMinLockMoney || currentProfit <= 0.0)
   {
      reason = "PROFIT_PROTECTION_CURRENT_PROFIT_TOO_LOW";
      return false;
   }
   double retracePercent = 0.0;
   if(peakProfit > 0.0)
      retracePercent = ((peakProfit - currentProfit) / peakProfit) * 100.0;
   if(retracePercent < ProfitRetraceClosePercent)
   {
      reason = "PROFIT_PROTECTION_RETRACE_NOT_REACHED";
      return false;
   }
   if(SmartExitSimulationOnly || !AllowProfitProtectionClose)
   {
      reason = "[PROFIT_PROTECTION] SIMULATION_ONLY ticket=" + UlongToText(ticket);
      AuditSmartExit(reason);
      return false;
   }
   if(ClosePositionSmart(ticket, "PROFIT_PROTECTION"))
   {
      reason = "PROFIT_PROTECTION_CLOSE_OK";
      return true;
   }
   reason = g_lastSmartExitBlockReason;
   AuditSmartExit("[PROFIT_PROTECTION][BLOCK_REASON] " + reason);
   return false;
}

bool ApplyBasketSmartClose(string &reason)
{
   reason = "";
   if(!UseBasketSmartClose)
   {
      reason = "BASKET_SMART_CLOSE_DISABLED";
      return false;
   }

   double basketProfit = 0.0;
   ulong tickets[];
   ArrayResize(tickets, 0);

   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      string v10BasketReject = "";
      if(!V10_ShouldAcceptPosition(ticket, i, v10BasketReject))
         continue;

      basketProfit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      int size = ArraySize(tickets);
      ArrayResize(tickets, size + 1);
      tickets[size] = ticket;
   }

   g_basketProfit = basketProfit;

   if(ArraySize(tickets) <= 0)
   {
      g_basketPeakProfit = 0.0;
      g_basketProfit = 0.0;
      reason = "NO_BASKET_POSITIONS";
      AuditSmartExit("[BASKET_SMART_CLOSE] PEAK_RESET_NO_POSITIONS");
      return false;
   }

   if(basketProfit > g_basketPeakProfit)
   {
      g_basketPeakProfit = basketProfit;
      AuditSmartExit("[BASKET_SMART_CLOSE] PEAK_UPDATED basketPeak=" + DoubleToString(g_basketPeakProfit, 2));
   }

   AuditSmartExit("[BASKET_SMART_CLOSE] CHECK basketProfit=" + DoubleToString(basketProfit, 2) + " peak=" + DoubleToString(g_basketPeakProfit, 2));

   bool shouldClose = false;
   bool isCriticalExit = false;
   string closeReason = "";

   if(basketProfit >= BasketProfitTargetMoney)
   {
      shouldClose = true;
      closeReason = "BASKET_TARGET_REACHED";
   }
   else if(g_basketPeakProfit >= BasketMinProfitToProtectMoney && g_basketPeakProfit > 0.0)
   {
      double retracePercent = ((g_basketPeakProfit - basketProfit) / g_basketPeakProfit) * 100.0;
      if(basketProfit > 0.0 && retracePercent >= BasketMaxProfitRetracePercent)
      {
         shouldClose = true;
         closeReason = "BASKET_PROFIT_RETRACE";
      }
   }

   if(basketProfit <= BasketEmergencyLossMoney)
   {
      AuditSmartExit("[BASKET_SMART_CLOSE] EMERGENCY_LOSS_ALERT_ONLY basketProfit=" + DoubleToString(basketProfit, 2));
      if(AllowBasketEmergencyClose)
      {
         shouldClose = true;
         isCriticalExit = true;
         closeReason = "BASKET_EMERGENCY_CLOSE";
      }
   }

   if(!shouldClose)
   {
      reason = "BASKET_CLOSE_NOT_TRIGGERED";
      return false;
   }

   AuditSmartExit("[V4_BASKET_PROFIT] LEGACY_BASKET_CLOSE_REQUEST profit=" + DoubleToString(basketProfit,2) + " reason=" + closeReason + " oldTarget=" + DoubleToString(BasketProfitTargetMoney,2) + " minV4=" + DoubleToString(MinBasketProfitToCloseV4,2));

   // FIX3.2: BasketProfitTargetMoney=8.00 may still trigger, but cannot close directly or below V4 minimum unless critical.
   if(!isCriticalExit && basketProfit < MinBasketProfitToCloseV4)
   {
      reason = "LEGACY_MICRO_BASKET_BLOCKED";
      g_v4EarlyBasketCloseBlockedCount++;
      g_v4MicroProfitCloseBlockedCount++;
      AuditSmartExit("[V4_BASKET_PROFIT] LEGACY_MICRO_BASKET_BLOCKED profit=" + DoubleToString(basketProfit,2) + " min=" + DoubleToString(MinBasketProfitToCloseV4,2) + " reason=" + closeReason);
      AuditV4("[V4_BASKET_PROFIT] LEGACY_MICRO_BASKET_BLOCKED profit=" + DoubleToString(basketProfit,2) + " min=" + DoubleToString(MinBasketProfitToCloseV4,2) + " reason=" + closeReason);
      return false;
   }

   if(SmartExitSimulationOnly || !AllowBasketSmartClose)
   {
      reason = "[BASKET_SMART_CLOSE] SIMULATION_ONLY reason=" + closeReason;
      AuditSmartExit(reason);
      return true;
   }

   AuditSmartExit("[V4_BASKET_PROFIT] ROUTED_TO_ORCHESTRATOR profit=" + DoubleToString(basketProfit,2) + " reason=" + closeReason);
   AuditV4("[V4_BASKET_PROFIT] ROUTED_TO_ORCHESTRATOR profit=" + DoubleToString(basketProfit,2) + " reason=" + closeReason);

   bool anySent = false;
   for(int j = 0; j < ArraySize(tickets); j++)
   {
      ulong ticket = tickets[j];
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;

      ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool runnerProtected = (GetRoleForTicketV4(ticket) == "RUNNER" || IsRunnerCandidateV4(ticket, pt));
      double ticketProfit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

      if(runnerProtected && !isCriticalExit && ticketProfit > 0.0 && ticketProfit < MinProfitToAllowPositiveCloseV4)
      {
         g_v4RunnerMicroCloseBlockedCount++;
         AuditSmartExit("[V4_RUNNER_PROTECTION] LEGACY_CLOSE_BLOCKED ticket=" + UlongToText(ticket) + " module=LEGACY_BASKET_SMART_CLOSE reason=" + closeReason + " profit=" + DoubleToString(ticketProfit,2));
         AuditV4("[V4_RUNNER_PROTECTION] LEGACY_CLOSE_BLOCKED ticket=" + UlongToText(ticket) + " module=LEGACY_BASKET_SMART_CLOSE reason=" + closeReason + " profit=" + DoubleToString(ticketProfit,2));
         continue;
      }

      if(RequestV4ExitOrchestrator(ticket, "LEGACY_BASKET_SMART_CLOSE", closeReason, ticketProfit, isCriticalExit, false))
         anySent = true;
   }

   if(anySent)
   {
      g_lastBasketCloseTime = TimeCurrent();
      g_lastBasketCloseReason = closeReason;
      g_lastSmartExitAction = "BASKET_SMART_CLOSE_ROUTED_TO_ORCHESTRATOR";
      reason = closeReason;
      AuditSmartExit("[BASKET_SMART_CLOSE] ROUTED_CLOSE_ALL_SENT reason=" + closeReason);
      return true;
   }

   reason = "BASKET_CLOSE_BLOCKED_BY_V4_ORCHESTRATOR";
   AuditSmartExit("[BASKET_SMART_CLOSE][BLOCK_REASON] " + reason + " reason=" + closeReason);
   return false;
}

bool DetectPositionWeakness(ulong ticket, string &reason)
{
   reason = "";
   string posReason = "";
   if(!IsSmartExitPosition(ticket, posReason))
   {
      reason = posReason;
      return false;
   }
   if(WeaknessLookbackCandles <= 0)
   {
      reason = "WEAKNESS_LOOKBACK_INVALID";
      return false;
   }
   if(SmartExitProfitPoints(ticket) < WeaknessMinProfitPoints && MathAbs(SmartExitProfitPoints(ticket)) < WeaknessCloseIfAgainstPoints)
   {
      reason = "WEAKNESS_MIN_PROFIT_OR_AGAINST_NOT_MET";
      return false;
   }
   long type = (long)PositionGetInteger(POSITION_TYPE);
   double close1 = iClose(_Symbol, PERIOD_M1, 1);
   double open1 = iOpen(_Symbol, PERIOD_M1, 1);
   double lowRecent = iLow(_Symbol, PERIOD_M1, 1);
   double highRecent = iHigh(_Symbol, PERIOD_M1, 1);
   for(int i = 2; i <= WeaknessLookbackCandles; i++)
   {
      lowRecent = MathMin(lowRecent, iLow(_Symbol, PERIOD_M1, i));
      highRecent = MathMax(highRecent, iHigh(_Symbol, PERIOD_M1, i));
   }
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(type == POSITION_TYPE_BUY)
   {
      if(close1 < open1 && bid < lowRecent)
      {
         reason = "BUY_WEAKNESS_DETECTED";
         return true;
      }
   }
   if(type == POSITION_TYPE_SELL)
   {
      if(close1 > open1 && ask > highRecent)
      {
         reason = "SELL_WEAKNESS_DETECTED";
         return true;
      }
   }
   reason = "WEAKNESS_NOT_DETECTED";
   return false;
}

bool ApplyWeaknessExit(ulong ticket, string &reason)
{
   reason = "";
   if(!UseWeaknessExit)
   {
      reason = "WEAKNESS_EXIT_DISABLED";
      return false;
   }
   double basketProfit = 0.0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0)
         continue;
      if(!PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      basketProfit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   if(WeaknessExitOnlyIfBasketPositive && basketProfit <= 0.0)
   {
      reason = "WEAKNESS_BASKET_NOT_POSITIVE";
      return false;
   }
   string weakReason = "";
   if(!DetectPositionWeakness(ticket, weakReason))
   {
      reason = weakReason;
      return false;
   }
   long posTypeForWeakness = PositionGetInteger(POSITION_TYPE);
   ENUM_POSITION_TYPE ptForWeakness = (ENUM_POSITION_TYPE)posTypeForWeakness;
   if((GetRoleForTicketV4(ticket) == "RUNNER" || IsRunnerCandidateV4(ticket, ptForWeakness)) && !IsSevereReversalV4(ticket, ptForWeakness))
   {
      reason = "GOOD_RUNNER_PULLBACK_NOT_REVERSAL_WEAKNESS_EXIT_BLOCKED";
      AuditSmartExit("[WEAKNESS_EXIT] GOOD_RUNNER_PULLBACK_BLOCKED ticket=" + UlongToText(ticket));
      return false;
   }
   if(SmartExitSimulationOnly || !AllowWeaknessExitClose)
   {
      reason = "[WEAKNESS_EXIT] SIMULATION_ONLY ticket=" + UlongToText(ticket) + " reason=" + weakReason;
      AuditSmartExit(reason);
      return false;
   }
   if(ClosePositionSmart(ticket, weakReason))
   {
      reason = "WEAKNESS_EXIT_CLOSE_OK";
      return true;
   }
   reason = g_lastSmartExitBlockReason;
   AuditSmartExit("[WEAKNESS_EXIT][BLOCK_REASON] " + reason);
   return false;
}

void UpdateSmartExitRealEngine()
{
   if(!UseSmartExitRealEngine)
      return;
   string envReason = "";
   if(!ValidateSmartExitEnvironment(envReason))
   {
      g_lastSmartExitBlockReason = envReason;
      return;
   }
   RemoveClosedTicketStates();
   int posCount = CountSmartExitPositions();
   if(posCount <= 0)
   {
      g_basketPeakProfit = 0.0;
      g_basketProfit = 0.0;
      AuditSmartExit("[SMART_EXIT] NO_POSITIONS_TO_MANAGE");
      AuditSmartExit("[BASKET_SMART_CLOSE] PEAK_RESET_NO_POSITIONS");
      return;
   }
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      string posReason = "";
      if(!IsSmartExitPosition(ticket, posReason))
         continue;
      UpdateSmartExitTicketState(ticket);
   }
   string basketReason = "";
   if(ApplyBasketSmartClose(basketReason))
   {
      AuditSmartExit("[SMART_EXIT] BASKET_CLOSED_SKIP_INDIVIDUAL_ACTIONS");
      g_lastSmartExitAction = "BASKET_SMART_CLOSE";
      return;
   }
   ulong tickets[];
   ArrayResize(tickets, 0);
   for(int j = 0; j < PositionsTotal(); j++)
   {
      ulong ticket = PositionGetTicket(j);
      if(ticket == 0)
         continue;
      string posReason = "";
      if(!IsSmartExitPosition(ticket, posReason))
         continue;
      int size = ArraySize(tickets);
      ArrayResize(tickets, size + 1);
      tickets[size] = ticket;
   }
   for(int k = 0; k < ArraySize(tickets); k++)
   {
      ulong ticket = tickets[k];
      string reason = "";
      ApplyBreakEvenReal(ticket, reason);
      ApplySmartTrailingReal(ticket, reason);
      ApplyDynamicTPReal(ticket, reason);
      ApplyProfitProtectionReal(ticket, reason);
      ApplyWeaknessExit(ticket, reason);
   }
}



//+------------------------------------------------------------------+
//| FIX3 V3.2 - FUNCTIONS: ENTRY QUALITY + RUNNER                    |
//+------------------------------------------------------------------+
enum EV32PositionRole
{
   ROLE_NONE,
   ROLE_MAIN,
   ROLE_LAYER_1,
   ROLE_RUNNER
};

struct SV32PositionRoleState
{
   ulong ticket;
   EV32PositionRole role;
   datetime assignedTime;
   double entryPrice;
   string assignReason;
};

SV32PositionRoleState g_v32RoleStates[];

double   g_v32LastBuyQualityScore = 0.0;
double   g_v32LastSellQualityScore = 0.0;
double   g_v32LastEntryQualityScore = 0.0;
string   g_v32LastEntryQualityResult = "NONE";
string   g_v32LastEntryQualityReason = "NONE";
string   g_v32LastTrendResult = "NONE";
string   g_v32LastTrendReason = "NONE";
string   g_v32LastAntiOvertradeResult = "NONE";
string   g_v32LastAntiOvertradeReason = "NONE";
string   g_v32LastBiasResult = "NONE";
string   g_v32LastBiasReason = "NONE";
string   g_v32LastRegimeResult = "NONE";
string   g_v32LastRegimeReason = "NONE";
string   g_v32LastLayerGateResult = "NONE";
string   g_v32LastLayerGateReason = "NONE";
string   g_v32LastProfitDistributionMode = "NONE";
string   g_v32LastRunnerStatus = "NONE";
string   g_v32LastAdaptiveBasketMode = "NONE";
string   g_v32LastBlockReason = "NONE";
string   g_v32LastAction = "NONE";
ulong    g_v32RunnerTicket = 0;
double   g_v32AdaptiveBasketTarget = 0.0;
double   g_v32BuySellRatio = 0.0;
int      g_v32TradesLast100Candles = 0;
int      g_v32CyclesLast100Candles = 0;
int      g_v32CurrentLossStreak = 0;
datetime g_v32LastNewCycleTime = 0;
datetime g_v32PauseUntil = 0;

// V3.2 Balanced Relaxed FIX1 runtime state
datetime g_lastChoppyBypassTimeV32 = 0;
datetime g_v32ChoppyBypassTimes[];
string   g_v32LastBalancedRelaxedAction = "NONE";
string   g_v32LastChoppyBypassResult = "NONE";
string   g_v32LastChoppyBypassReason = "NONE";
double   g_v32LastChoppyRangeCompression = 0.0;
double   g_v32LastChoppyATRPoints = 0.0;
double   g_v32LastChoppySpreadPoints = 0.0;
double   g_v32LastChoppyTrendM5 = 0.0;
double   g_v32LastChoppyTrendM15 = 0.0;
double   g_v32LastChoppyADX = 0.0;
int      g_v32LastChoppyBypassCount100 = 0;

// V3.2 Balanced Relaxed FIX1 final decision state
bool     g_v32Fix1FinalEntryAllowed = false;
string   g_v32Fix1FinalBlockReason  = "NONE";
string   g_v32Fix1LastDecision      = "NONE";
string   g_v32Fix1BiasStatus        = "NONE";
bool     g_v32Fix1TrendAlignedBonus = false;

double V32Clamp(double value, double minValue, double maxValue)
{
   if(value < minValue) return minValue;
   if(value > maxValue) return maxValue;
   return value;
}

string V32OrderTypeToText(ENUM_ORDER_TYPE direction)
{
   if(direction == ORDER_TYPE_BUY) return "BUY";
   if(direction == ORDER_TYPE_SELL) return "SELL";
   return "NONE";
}

ENUM_ORDER_TYPE V32RealDirectionToOrderType(ENUM_REAL_EXECUTION_DIRECTION direction)
{
   if(direction == REAL_EXEC_DIR_BUY) return ORDER_TYPE_BUY;
   if(direction == REAL_EXEC_DIR_SELL) return ORDER_TYPE_SELL;
   return (ENUM_ORDER_TYPE)-1;
}

ENUM_ORDER_TYPE V32LayerDirectionToOrderType()
{
   if(g_reentryLayer.direction == LAYER_DIR_BUY) return ORDER_TYPE_BUY;
   if(g_reentryLayer.direction == LAYER_DIR_SELL) return ORDER_TYPE_SELL;
   return (ENUM_ORDER_TYPE)-1;
}

void AuditV32(string message)
{
   AuditLog("V3_2", message);
}

double V32GetBufferValue(int handle, int bufferIndex, int shift)
{
   if(handle == INVALID_HANDLE)
      return 0.0;
   double values[];
   ArraySetAsSeries(values, true);
   if(CopyBuffer(handle, bufferIndex, shift, 1, values) <= 0)
   {
      IndicatorRelease(handle);
      return 0.0;
   }
   double result = values[0];
   IndicatorRelease(handle);
   return result;
}

double V32GetMA(ENUM_TIMEFRAMES tf, int period, int shift)
{
   int handle = iMA(_Symbol, tf, period, 0, MODE_EMA, PRICE_CLOSE);
   return V32GetBufferValue(handle, 0, shift);
}

double V32GetADX(ENUM_TIMEFRAMES tf, int period, int shift)
{
   int handle = iADX(_Symbol, tf, period);
   return V32GetBufferValue(handle, 0, shift);
}

double V32GetATRPoints(ENUM_TIMEFRAMES tf, int period, int shift)
{
   int handle = iATR(_Symbol, tf, period);
   double atr = V32GetBufferValue(handle, 0, shift);
   if(atr <= 0.0 || _Point <= 0.0)
      return 0.0;
   return atr / _Point;
}

int V32CountMagicPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      count++;
   }
   return count;
}

int V32FindRoleIndex(ulong ticket)
{
   for(int i = 0; i < ArraySize(g_v32RoleStates); i++)
      if(g_v32RoleStates[i].ticket == ticket)
         return i;
   return -1;
}

string RoleToTextV32(EV32PositionRole role)
{
   if(role == ROLE_MAIN) return "MAIN";
   if(role == ROLE_LAYER_1) return "LAYER_1";
   if(role == ROLE_RUNNER) return "RUNNER";
   return "NONE";
}

EV32PositionRole GetPositionRoleV32(ulong ticket)
{
   int idx = V32FindRoleIndex(ticket);
   if(idx < 0)
      return ROLE_NONE;
   return g_v32RoleStates[idx].role;
}

void AssignPositionRoleV32(ulong ticket, EV32PositionRole role, string reason)
{
   if(ticket == 0)
      return;
   int idx = V32FindRoleIndex(ticket);
   if(idx < 0)
   {
      int n = ArraySize(g_v32RoleStates);
      ArrayResize(g_v32RoleStates, n + 1);
      idx = n;
      g_v32RoleStates[idx].ticket = ticket;
   }
   g_v32RoleStates[idx].role = role;
   g_v32RoleStates[idx].assignedTime = TimeCurrent();
   g_v32RoleStates[idx].assignReason = reason;
   g_v32RoleStates[idx].entryPrice = 0.0;
   if(PositionSelectByTicket(ticket))
      g_v32RoleStates[idx].entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   AuditV32("[V3_2_ROLE] ticket=" + UlongToText(ticket) + " role=" + RoleToTextV32(role) + " reason=" + reason);
}

void RemoveClosedRoleStatesV32()
{
   for(int i = ArraySize(g_v32RoleStates) - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(g_v32RoleStates[i].ticket))
      {
         for(int j = i; j < ArraySize(g_v32RoleStates) - 1; j++)
            g_v32RoleStates[j] = g_v32RoleStates[j + 1];
         ArrayResize(g_v32RoleStates, ArraySize(g_v32RoleStates) - 1);
      }
   }
}

void SyncPositionRolesV32()
{
   RemoveClosedRoleStatesV32();
   ulong tickets[];
   datetime times[];
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      ArrayResize(tickets, count + 1);
      ArrayResize(times, count + 1);
      tickets[count] = ticket;
      times[count] = (datetime)PositionGetInteger(POSITION_TIME);
      count++;
   }
   for(int a = 0; a < count - 1; a++)
   {
      for(int b = a + 1; b < count; b++)
      {
         if(times[b] < times[a])
         {
            datetime tt = times[a]; times[a] = times[b]; times[b] = tt;
            ulong uu = tickets[a]; tickets[a] = tickets[b]; tickets[b] = uu;
         }
      }
   }
   for(int k = 0; k < count; k++)
   {
      EV32PositionRole role = ROLE_NONE;
      string why = "POSITION_ORDER_IN_CYCLE";
      if(k == 0) { role = ROLE_MAIN; why = "FIRST_POSITION_IN_CYCLE"; }
      else if(k == 1) { role = ROLE_LAYER_1; why = "SECOND_POSITION_IN_CYCLE"; }
      else { role = ROLE_RUNNER; why = "THIRD_POSITION_IN_CYCLE"; }
      EV32PositionRole existingRole = GetPositionRoleV32(tickets[k]);
      if(existingRole == ROLE_RUNNER)
      {
         g_v32RunnerTicket = tickets[k];
         continue;
      }
      if(existingRole != role)
         AssignPositionRoleV32(tickets[k], role, why);
      if(role == ROLE_RUNNER)
         g_v32RunnerTicket = tickets[k];
   }
   if(count < 3)
      g_v32RunnerTicket = 0;
}

double GetTrendStrengthV32(ENUM_TIMEFRAMES tf)
{
   double fast = V32GetMA(tf, TrendEMA_Fast, 1);
   double medium = V32GetMA(tf, TrendEMA_Medium, 1);
   double slow = V32GetMA(tf, TrendEMA_Slow, 1);
   double adx = V32GetADX(tf, TrendADXPeriod, 1);
   if(fast <= 0.0 || medium <= 0.0 || slow <= 0.0)
      return 0.0;
   double trend = 0.0;
   if(fast > medium && medium >= slow) trend += 50.0;
   if(fast < medium && medium <= slow) trend -= 50.0;
   if(adx >= StrongTrendADXV32) trend += (trend >= 0.0 ? 25.0 : -25.0);
   else if(adx >= MinTrendADXV32) trend += (trend >= 0.0 ? 10.0 : -10.0);
   return trend;
}

bool CheckMTFTrendFilterV32(ENUM_ORDER_TYPE direction, string &reason)
{
   reason = "MTF TREND FILTER OFF";
   if(!UseMTFTrendFilterV32)
      return true;
   double s1 = GetTrendStrengthV32(TrendTF1);
   double s2 = GetTrendStrengthV32(TrendTF2);
   double adx1 = V32GetADX(TrendTF1, TrendADXPeriod, 1);
   double adx2 = V32GetADX(TrendTF2, TrendADXPeriod, 1);
   double adxMax = MathMax(adx1, adx2);
   bool allow = true;

   if(UseBalancedRelaxedV32 && !V32_GlobalDiagnosticOnly)
   {
      // FIX1: In Balanced Relaxed FIX1, do not block a trade because only one higher TF is against.
      // Block only when BOTH M5 and M15 are strongly against and ADX confirms strength.
      if(direction == ORDER_TYPE_BUY && s1 < -20.0 && s2 < -20.0 && adxMax >= StrongTrendADXV32)
      {
         allow = false;
         reason = "STRONG_AGAINST_MTF_TREND";
      }
      else if(direction == ORDER_TYPE_SELL && s1 > 20.0 && s2 > 20.0 && adxMax >= StrongTrendADXV32)
      {
         allow = false;
         reason = "STRONG_AGAINST_MTF_TREND";
      }
      else
      {
         allow = true;
         reason = "MTF_TREND_OK_RELAXED_FIX1";
      }
   }
   else
   {
      if(direction == ORDER_TYPE_BUY && (s1 < -20.0 || s2 < -20.0)) { allow = false; reason = "AGAINST_MTF_TREND"; }
      else if(direction == ORDER_TYPE_SELL && (s1 > 20.0 || s2 > 20.0)) { allow = false; reason = "AGAINST_MTF_TREND"; }
      else if(adx1 < MinTrendADXV32 && adx2 < MinTrendADXV32) { allow = false; reason = "WEAK_MTF_ADX"; }
      else reason = "MTF_TREND_OK";
   }

   g_v32LastTrendResult = (allow ? "WOULD_ALLOW" : "WOULD_BLOCK");
   g_v32LastTrendReason = reason;
   AuditV32("[V3_2_TREND_FILTER] direction=" + V32OrderTypeToText(direction) + " M5=" + DoubleToString(s1,1) + " M15=" + DoubleToString(s2,1) + " ADX=" + DoubleToString(adxMax,1) + " result=" + g_v32LastTrendResult + " reason=" + reason);
   if(MTFTrendFilterV32_DiagnosticOnly || V32_GlobalDiagnosticOnly)
      return true;
   return allow;
}


int CountChoppyBypassTradesLastCandlesV32(int candles)
{
   int safeCandles = (candles < 1 ? 1 : candles);
   datetime start = iTime(_Symbol, PERIOD_M1, safeCandles);
   if(start <= 0)
      start = TimeCurrent() - safeCandles * 60;

   int count = 0;
   int total = ArraySize(g_v32ChoppyBypassTimes);
   for(int i = total - 1; i >= 0; i--)
   {
      if(g_v32ChoppyBypassTimes[i] >= start)
         count++;
   }
   return count;
}

void RegisterChoppyBypassV32()
{
   g_lastChoppyBypassTimeV32 = TimeCurrent();
   int total = ArraySize(g_v32ChoppyBypassTimes);
   ArrayResize(g_v32ChoppyBypassTimes, total + 1);
   g_v32ChoppyBypassTimes[total] = g_lastChoppyBypassTimeV32;
}

int EffectiveChoppyBypassSpreadLimitV32()
{
   int limit = MaxSpreadPoints;
   if(limit <= 0)
      limit = ExtremeSpreadPoints;
   if(MaxRealExecutionSpreadPoints > 0 && (limit <= 0 || MaxRealExecutionSpreadPoints < limit))
      limit = MaxRealExecutionSpreadPoints;
   if(MaxLayerSpreadPoints > 0.0 && (limit <= 0 || (int)MaxLayerSpreadPoints < limit))
      limit = (int)MaxLayerSpreadPoints;
   return limit;
}

bool HasAbsoluteRiskBlockForChoppyBypassV32(string &reason)
{
   if(g_risk.tradingLocked)
   {
      reason = "BYPASS_DENIED_ABSOLUTE_RISK_BLOCK";
      return true;
   }
   if(g_realExecutionRiskBlock || g_realExecutionBrokerBlock || g_positionEmergencyBlock)
   {
      reason = "BYPASS_DENIED_ABSOLUTE_RISK_BLOCK";
      return true;
   }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
   {
      reason = "BYPASS_DENIED_ABSOLUTE_RISK_BLOCK";
      return true;
   }
   long tradeMode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(tradeMode == SYMBOL_TRADE_MODE_DISABLED)
   {
      reason = "BYPASS_DENIED_ABSOLUTE_RISK_BLOCK";
      return true;
   }
   return false;
}

bool IsStrongAgainstTrendForBypassV32(ENUM_ORDER_TYPE direction, double trendM5, double trendM15, double adxValue)
{
   if(!BlockStrongAgainstTrendBypassV32)
      return false;
   if(direction == ORDER_TYPE_BUY && trendM5 < -20.0 && trendM15 < -20.0 && adxValue >= StrongTrendADXV32)
      return true;
   if(direction == ORDER_TYPE_SELL && trendM5 > 20.0 && trendM15 > 20.0 && adxValue >= StrongTrendADXV32)
      return true;
   return false;
}


bool IsDirectionAlignedWithStrongTrendV32(ENUM_ORDER_TYPE direction,
                                          double trendM5,
                                          double trendM15,
                                          double adxValue)
{
   if(direction == ORDER_TYPE_SELL && trendM5 < -20.0 && trendM15 < -20.0 && adxValue >= StrongTrendADXV32)
      return true;
   if(direction == ORDER_TYPE_BUY && trendM5 > 20.0 && trendM15 > 20.0 && adxValue >= StrongTrendADXV32)
      return true;
   return false;
}

bool CanBypassChoppyMarketV32(ENUM_ORDER_TYPE direction,
                              double entryQualityScore,
                              double atrPoints,
                              double spreadPoints,
                              double rangeCompressionRatio,
                              double trendM5,
                              double trendM15,
                              double adxValue,
                              bool antiOvertradeOk,
                              string &reason)
{
   g_v32LastChoppyRangeCompression = rangeCompressionRatio;
   g_v32LastChoppyATRPoints = atrPoints;
   g_v32LastChoppySpreadPoints = spreadPoints;
   g_v32LastChoppyTrendM5 = trendM5;
   g_v32LastChoppyTrendM15 = trendM15;
   g_v32LastChoppyADX = adxValue;
   g_v32LastChoppyBypassCount100 = CountChoppyBypassTradesLastCandlesV32(100);
   g_v32Fix1TrendAlignedBonus = IsDirectionAlignedWithStrongTrendV32(direction, trendM5, trendM15, adxValue);

   if(DebugBypassChoppyAlwaysLogV32)
   {
      AuditV32("[V3_2_REGIME_RELAXED_FIX1] CHECK direction=" + V32OrderTypeToText(direction) +
               " score=" + DoubleToString(entryQualityScore,1) +
               " min68=" + DoubleToString(MinQualityForModerateRangeV32,1) +
               " min70=" + DoubleToString(MinQualityForCompressedRangeV32,1) +
               " strong72=" + DoubleToString(StrongQualityToBypassChoppyV32,1) +
               " atr=" + DoubleToString(atrPoints,1) +
               " spread=" + DoubleToString(spreadPoints,1) +
               " trendM5=" + DoubleToString(trendM5,1) +
               " trendM15=" + DoubleToString(trendM15,1) +
               " adx=" + DoubleToString(adxValue,1) +
               " antiOvertrade=" + BoolToText(antiOvertradeOk) +
               " bias=" + g_v32LastBiasReason +
               " trendAligned=" + BoolToText(g_v32Fix1TrendAlignedBonus) +
               " rangeRatio=" + DoubleToString(rangeCompressionRatio,2) +
               " bypassCount100=" + IntegerToString(g_v32LastChoppyBypassCount100));
   }

   string absoluteReason = "";
   if(HasAbsoluteRiskBlockForChoppyBypassV32(absoluteReason))
   {
      reason = "FINAL_BLOCK_ABSOLUTE_RISK";
      AuditV32("[V3_2_REGIME_RELAXED_FIX1] FINAL_BLOCK_ABSOLUTE_RISK");
      return false;
   }
   if(!AllowHighQualityEntryInChoppyMarketV32)
   {
      reason = "FINAL_BLOCK_SCORE_BELOW_68";
      AuditV32("[V3_2_REGIME_RELAXED_FIX1] FINAL_BLOCK_SCORE_BELOW_68");
      return false;
   }
   if(RequireHealthyATRForChoppyBypassV32 && atrPoints < MinHealthyATRPointsV32)
   {
      reason = "FINAL_BLOCK_LOW_ATR";
      AuditV32("[V3_2_REGIME_RELAXED_FIX1] FINAL_BLOCK_LOW_ATR");
      return false;
   }
   if(RequireSpreadOkForChoppyBypassV32)
   {
      int spreadLimit = EffectiveChoppyBypassSpreadLimitV32();
      if(spreadLimit > 0 && spreadPoints > spreadLimit)
      {
         reason = "FINAL_BLOCK_SPREAD";
         AuditV32("[V3_2_REGIME_RELAXED_FIX1] FINAL_BLOCK_SPREAD");
         return false;
      }
   }
   if(RequireAntiOvertradeOkForChoppyBypassV32 && !antiOvertradeOk)
   {
      reason = "FINAL_BLOCK_ANTI_OVERTRADE";
      AuditV32("[V3_2_REGIME_RELAXED_FIX1] FINAL_BLOCK_ANTI_OVERTRADE");
      return false;
   }
   if(IsStrongAgainstTrendForBypassV32(direction, trendM5, trendM15, adxValue))
   {
      reason = "FINAL_BLOCK_STRONG_AGAINST_TREND";
      AuditV32("[V3_2_REGIME_RELAXED_FIX1] FINAL_BLOCK_STRONG_AGAINST_TREND");
      return false;
   }
   else
   {
      AuditV32("[V3_2_REGIME_RELAXED_FIX1] TREND_NOT_STRONGLY_AGAINST");
   }

   if(rangeCompressionRatio <= ExtremeCompressionBlockV32)
   {
      reason = "FINAL_BLOCK_EXTREME_COMPRESSION";
      AuditV32("[V3_2_REGIME_RELAXED_FIX1] FINAL_BLOCK_EXTREME_COMPRESSION");
      return false;
   }

   if(g_v32LastChoppyBypassCount100 >= MaxChoppyBypassTradesPer100CandlesV32)
   {
      reason = "CHOPPY_BYPASS_DENIED_MAX_BYPASS_TRADES";
      AuditV32("[V3_2_REGIME_RELAXED_FIX1] FINAL_BLOCK_MAX_BYPASS_TRADES");
      return false;
   }
   if(g_lastChoppyBypassTimeV32 > 0 && (TimeCurrent() - g_lastChoppyBypassTimeV32) < MinSecondsBetweenChoppyBypassV32)
   {
      reason = "CHOPPY_BYPASS_DENIED_COOLDOWN";
      AuditV32("[V3_2_REGIME_RELAXED_FIX1] FINAL_BLOCK_COOLDOWN");
      return false;
   }

   bool allow = false;
   string allowReason = "";

   if(entryQualityScore >= StrongQualityToBypassChoppyV32)
   {
      allow = true;
      allowReason = "FINAL_ALLOW_SCORE_72_STRONG_QUALITY";
   }
   else if(rangeCompressionRatio > ExtremeCompressionBlockV32 && rangeCompressionRatio <= ModerateCompressionBypassV32)
   {
      AuditV32("[V3_2_REGIME_RELAXED_FIX1] COMPRESSED_RANGE_CAN_BYPASS_WITH_SCORE_70");
      if(entryQualityScore >= MinQualityForCompressedRangeV32)
      {
         allow = true;
         allowReason = "FINAL_ALLOW_SCORE_70_COMPRESSED_RANGE";
      }
   }
   else if(rangeCompressionRatio > ModerateCompressionBypassV32)
   {
      AuditV32("[V3_2_REGIME_RELAXED_FIX1] MODERATE_RANGE_CAN_BYPASS_WITH_SCORE_68");
      if(entryQualityScore >= MinQualityForModerateRangeV32)
      {
         allow = true;
         allowReason = "FINAL_ALLOW_SCORE_68_MODERATE_RANGE";
      }
   }

   if(!allow)
   {
      reason = "FINAL_BLOCK_SCORE_BELOW_68";
      AuditV32("[V3_2_REGIME_RELAXED_FIX1] FINAL_BLOCK_SCORE_BELOW_68");
      return false;
   }

   if(g_v32Fix1TrendAlignedBonus)
   {
      AuditV32("[V3_2_REGIME_RELAXED_FIX1] TREND_ALIGNED_BONUS_APPLIED");
      if(direction == ORDER_TYPE_SELL)
         AuditV32("[V3_2_REGIME_RELAXED_FIX1] SELL_ALLOWED_BY_STRONG_DOWN_TREND");
      if(direction == ORDER_TYPE_BUY)
         AuditV32("[V3_2_REGIME_RELAXED_FIX1] BUY_ALLOWED_BY_STRONG_UP_TREND");
   }

   reason = "BALANCED_RELAXED_FIX1_ALLOW";
   AuditV32("[V3_2_REGIME_RELAXED_FIX1] " + allowReason);
   return true;
}

bool CheckMarketRegimeV32Ex(ENUM_ORDER_TYPE direction,
                            double entryQualityScore,
                            bool antiOvertradeOk,
                            bool allowRelaxedBypass,
                            string &reason)
{
   reason = "MARKET REGIME OFF";
   if(!UseMarketRegimeFilterV32)
      return true;

   double atr = V32GetATRPoints(PERIOD_M1, RegimeATRPeriodV32, 1);
   double highest = -1.0e100;
   double lowest = 1.0e100;
   for(int i = 1; i <= RangeLookbackCandlesV32; i++)
   {
      highest = MathMax(highest, iHigh(_Symbol, PERIOD_M1, i));
      lowest = MathMin(lowest, iLow(_Symbol, PERIOD_M1, i));
   }
   double rangePoints = (highest > lowest && _Point > 0.0 ? (highest - lowest) / _Point : 0.0);
   int safeLookback = (RangeLookbackCandlesV32 < 1 ? 1 : RangeLookbackCandlesV32);
   double compression = (atr > 0.0 ? rangePoints / (atr * safeLookback) : 1.0);
   double trendM5 = GetTrendStrengthV32(TrendTF1);
   double trendM15 = GetTrendStrengthV32(TrendTF2);
   double adxValue = MathMax(V32GetADX(TrendTF1, TrendADXPeriod, 1), V32GetADX(TrendTF2, TrendADXPeriod, 1));
   double spreadPoints = (double)GetCurrentSpreadPoints();

   bool allow = true;
   if(atr < MinHealthyATRPointsV32) { allow = false; reason = "LOW_ATR_MARKET"; }
   else if(BlockExtremeVolatilityV32 && atr > MaxDangerATRPointsV32) { allow = false; reason = "EXTREME_VOLATILITY"; }
   else if(BlockChoppyMarketV32 && compression < MaxRangeCompressionRatioV32)
   {
      string relaxedReason = "CHOPPY_MARKET";
      bool bypass = false;
      if(UseBalancedRelaxedV32 && allowRelaxedBypass)
         bypass = CanBypassChoppyMarketV32(direction, entryQualityScore, atr, spreadPoints, compression, trendM5, trendM15, adxValue, antiOvertradeOk, relaxedReason);

      if(bypass)
      {
         allow = true;
         reason = "BALANCED_RELAXED_FIX1_ALLOW";
         g_v32LastBalancedRelaxedAction = "ENTRY_ALLOWED_BY_BALANCED_RELAXED_FIX1";
         g_v32LastChoppyBypassResult = "ALLOWED";
         g_v32LastChoppyBypassReason = reason;
         g_v32Fix1FinalEntryAllowed = true;
         g_v32Fix1FinalBlockReason = reason;
         g_v32Fix1LastDecision = "ALLOWED";
         RegisterChoppyBypassV32();
         AuditV32("[V3_2_MASTER] FINAL_ENTRY_DECISION_ALLOWED_FIX1");
         AuditV32("[REAL_EXECUTION][V3_2_FIX1] ENTRY_ALLOWED_FORWARDING_TO_ORDER_SEND");
      }
      else
      {
         allow = false;
         reason = relaxedReason;
         g_v32LastBalancedRelaxedAction = "ENTRY_WARNING_BY_BALANCED_RELAXED_FIX1";
         g_v32LastChoppyBypassResult = "BLOCKED";
         g_v32LastChoppyBypassReason = reason;
         g_v32Fix1FinalEntryAllowed = false;
         g_v32Fix1FinalBlockReason = reason;
         g_v32Fix1LastDecision = "BLOCKED";
         AuditV32("[V3_2_MASTER] FINAL_ENTRY_DECISION_BLOCKED_FIX1 reason=" + reason);
         AuditV32("[V3_2_LEGACY_AUDIT] WOULD_BLOCK_CONVERTED_TO_SCORE reason=" + reason);
      }
   }
   else reason = "REGIME_OK";

   g_v32LastRegimeResult = (allow ? "WOULD_ALLOW" : "WOULD_BLOCK");
   g_v32LastRegimeReason = reason;
   AuditV32("[V3_2_REGIME] ATR=" + DoubleToString(atr,1) + " rangeRatio=" + DoubleToString(compression,2) + " result=" + g_v32LastRegimeResult + " reason=" + reason);
   if(MarketRegimeFilterV32_DiagnosticOnly || V32_GlobalDiagnosticOnly)
      return true;
   return allow;
}

bool CheckMarketRegimeV32(string &reason)
{
   // Backward-compatible wrapper used by diagnostic scoring.
   return CheckMarketRegimeV32Ex((ENUM_ORDER_TYPE)-1, g_v32LastEntryQualityScore, true, false, reason);
}

int CountTradesLastCandlesV32(int candles)
{
   int safeCandles = (candles < 1 ? 1 : candles);
   datetime start = iTime(_Symbol, PERIOD_M1, safeCandles);
   if(start <= 0) start = TimeCurrent() - candles * 60;
   HistorySelect(start, TimeCurrent());
   int count = 0;
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0) continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol) continue;
      if((long)HistoryDealGetInteger(deal, DEAL_MAGIC) != MagicNumber) continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN)
         count++;
   }
   return count;
}

int CountCurrentLossStreakV32()
{
   HistorySelect(0, TimeCurrent());
   int streak = 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0) continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol) continue;
      if((long)HistoryDealGetInteger(deal, DEAL_MAGIC) != MagicNumber) continue;
      ENUM_DEAL_ENTRY e = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(e != DEAL_ENTRY_OUT && e != DEAL_ENTRY_INOUT) continue;
      double profit = HistoryDealGetDouble(deal, DEAL_PROFIT) + HistoryDealGetDouble(deal, DEAL_SWAP) + HistoryDealGetDouble(deal, DEAL_COMMISSION);
      if(profit < 0.0) streak++;
      else break;
   }
   return streak;
}

bool CheckAntiOvertradeV32(string &reason)
{
   reason = "ANTI OVERTRADE OFF";
   if(!UseAntiOvertradeV32)
      return true;
   g_v32TradesLast100Candles = CountTradesLastCandlesV32(100);
   g_v32CyclesLast100Candles = (int)MathCeil((double)g_v32TradesLast100Candles / 3.0);
   g_v32CurrentLossStreak = CountCurrentLossStreakV32();
   bool allow = true;
   if(g_v32PauseUntil > TimeCurrent()) { allow = false; reason = "LOSS_STREAK_PAUSE_ACTIVE"; }
   else if(g_v32TradesLast100Candles > MaxTradesPer100Candles) { allow = false; reason = "TOO_MANY_TRADES"; }
   else if(g_v32CyclesLast100Candles > MaxCyclesPer100Candles) { allow = false; reason = "TOO_MANY_CYCLES"; }
   else if(g_v32LastNewCycleTime > 0 && (TimeCurrent() - g_v32LastNewCycleTime) < MinSecondsBetweenNewCyclesV32) { allow = false; reason = "NEW_CYCLE_COOLDOWN"; }
   else if(g_v32CurrentLossStreak >= MaxConsecutiveLossesBeforePauseV32)
   {
      allow = false;
      reason = "LOSS_STREAK_LIMIT";
      if(PauseMinutesAfterLossStreakV32 > 0)
         g_v32PauseUntil = TimeCurrent() + PauseMinutesAfterLossStreakV32 * 60;
   }
   else reason = "ANTI_OVERTRADE_OK";
   g_v32LastAntiOvertradeResult = (allow ? "WOULD_ALLOW" : "WOULD_BLOCK");
   g_v32LastAntiOvertradeReason = reason;
   AuditV32("[V3_2_ANTI_OVERTRADE] tradesLast100=" + IntegerToString(g_v32TradesLast100Candles) + " cyclesLast100=" + IntegerToString(g_v32CyclesLast100Candles) + " lossStreak=" + IntegerToString(g_v32CurrentLossStreak) + " result=" + g_v32LastAntiOvertradeResult + " reason=" + reason);
   if(AntiOvertradeV32_DiagnosticOnly || V32_GlobalDiagnosticOnly)
      return true;
   return allow;
}

void CountDirectionTradesV32(int lookbackTrades, int &buyTrades, int &sellTrades)
{
   buyTrades = 0;
   sellTrades = 0;
   HistorySelect(0, TimeCurrent());
   int counted = 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0 && counted < lookbackTrades; i--)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0) continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol) continue;
      if((long)HistoryDealGetInteger(deal, DEAL_MAGIC) != MagicNumber) continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
      ENUM_DEAL_TYPE type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal, DEAL_TYPE);
      if(type == DEAL_TYPE_BUY) buyTrades++;
      if(type == DEAL_TYPE_SELL) sellTrades++;
      counted++;
   }
}

bool CheckDirectionalBiasV32(ENUM_ORDER_TYPE direction, string &reason)
{
   reason = "BIAS CONTROL OFF";
   if(!UseDirectionalBiasControlV32)
      return true;
   int buyTrades = 0, sellTrades = 0;
   CountDirectionTradesV32(BiasLookbackTradesV32, buyTrades, sellTrades);
   int totalTrades = buyTrades + sellTrades;
   g_v32BuySellRatio = (sellTrades > 0 ? (double)buyTrades / (double)sellTrades : (buyTrades > 0 ? 999.0 : 1.0));

   double trendM5 = GetTrendStrengthV32(TrendTF1);
   double trendM15 = GetTrendStrengthV32(TrendTF2);
   double adxValue = MathMax(V32GetADX(TrendTF1, TrendADXPeriod, 1), V32GetADX(TrendTF2, TrendADXPeriod, 1));
   bool trendAligned = IsDirectionAlignedWithStrongTrendV32(direction, trendM5, trendM15, adxValue);

   bool allow = true;
   g_v32Fix1BiasStatus = "BIAS_OK_RELAXED";

   if(UseBalancedRelaxedV32)
   {
      if(totalTrades < MinTradesBeforeBiasBlockV32)
      {
         reason = "SAMPLE_TOO_SMALL_FOR_BIAS_BLOCK";
         g_v32Fix1BiasStatus = reason;
         AuditV32("[V3_2_BIAS_FIX1] SAMPLE_TOO_SMALL_FOR_BIAS_BLOCK buyTrades=" + IntegerToString(buyTrades) + " sellTrades=" + IntegerToString(sellTrades) + " total=" + IntegerToString(totalTrades));
      }
      else if(direction == ORDER_TYPE_BUY && buyTrades < MinSameDirectionTradesForBiasV32)
      {
         reason = "SAMPLE_TOO_SMALL_FOR_BIAS_BLOCK";
         g_v32Fix1BiasStatus = reason;
         AuditV32("[V3_2_BIAS_FIX1] SAMPLE_TOO_SMALL_FOR_BIAS_BLOCK buyTrades=" + IntegerToString(buyTrades));
      }
      else if(direction == ORDER_TYPE_SELL && sellTrades < MinSameDirectionTradesForBiasV32)
      {
         reason = "SAMPLE_TOO_SMALL_FOR_BIAS_BLOCK";
         g_v32Fix1BiasStatus = reason;
         AuditV32("[V3_2_BIAS_FIX1] SAMPLE_TOO_SMALL_FOR_BIAS_BLOCK sellTrades=" + IntegerToString(sellTrades));
      }
      else if(AllowBiasBypassWhenTrendAlignedV32 && trendAligned)
      {
         reason = "BIAS_BYPASSED_BY_TREND_ALIGNMENT";
         g_v32Fix1BiasStatus = reason;
         AuditV32("[V3_2_BIAS_FIX1] BIAS_BYPASSED_BY_TREND_ALIGNMENT direction=" + V32OrderTypeToText(direction));
      }
      else if(direction == ORDER_TYPE_BUY && BlockNewBuyIfBuyBiasExtremeV32 && g_v32BuySellRatio > MaxBuySellRatioRelaxedV32)
      {
         allow = false;
         reason = "BIAS_EXTREME_CONFIRMED";
         g_v32Fix1BiasStatus = reason;
         AuditV32("[V3_2_BIAS_FIX1] BIAS_EXTREME_CONFIRMED side=BUY ratio=" + DoubleToString(g_v32BuySellRatio,2));
      }
      else if(direction == ORDER_TYPE_SELL && BlockNewSellIfSellBiasExtremeV32 && g_v32BuySellRatio < (1.0 / MathMax(0.1, MaxBuySellRatioRelaxedV32)))
      {
         allow = false;
         reason = "BIAS_EXTREME_CONFIRMED";
         g_v32Fix1BiasStatus = reason;
         AuditV32("[V3_2_BIAS_FIX1] BIAS_EXTREME_CONFIRMED side=SELL ratio=" + DoubleToString(g_v32BuySellRatio,2));
      }
      else
      {
         reason = "BIAS_OK_RELAXED";
         g_v32Fix1BiasStatus = reason;
         AuditV32("[V3_2_BIAS_FIX1] BIAS_OK_RELAXED buyTrades=" + IntegerToString(buyTrades) + " sellTrades=" + IntegerToString(sellTrades) + " ratio=" + DoubleToString(g_v32BuySellRatio,2));
      }
   }
   else
   {
      if(direction == ORDER_TYPE_BUY && BlockNewBuyIfBuyBiasExtremeV32 && g_v32BuySellRatio > MaxBuySellRatioV32) { allow = false; reason = "BUY_BIAS_EXTREME"; }
      else if(direction == ORDER_TYPE_SELL && BlockNewSellIfSellBiasExtremeV32 && g_v32BuySellRatio < (1.0 / MathMax(0.1, MaxBuySellRatioV32))) { allow = false; reason = "SELL_BIAS_EXTREME"; }
      else reason = "BIAS_OK";
   }

   g_v32LastBiasResult = (allow ? "WOULD_ALLOW" : "WOULD_BLOCK");
   g_v32LastBiasReason = reason;
   AuditV32("[V3_2_BIAS] buyTrades=" + IntegerToString(buyTrades) + " sellTrades=" + IntegerToString(sellTrades) + " ratio=" + DoubleToString(g_v32BuySellRatio,2) + " result=" + g_v32LastBiasResult + " reason=" + reason);
   if(DirectionalBiasControlV32_DiagnosticOnly || V32_GlobalDiagnosticOnly)
      return true;
   return allow;
}

double CalculateEntryQualityScoreV32(ENUM_ORDER_TYPE direction, string &reason)
{
   double score = 0.0;
   double maxScore = WeightTrendAlignmentV32 + WeightMomentumV32 + WeightVolatilityV32 + WeightCandleConfirmationV32 + WeightAntiRangeV32 + WeightSpreadCostV32;
   string trendReason = "";
   bool trendOK = CheckMTFTrendFilterV32(direction, trendReason);
   if(trendOK) score += WeightTrendAlignmentV32;
   double open1 = iOpen(_Symbol, PERIOD_M1, 1);
   double close1 = iClose(_Symbol, PERIOD_M1, 1);
   double close4 = iClose(_Symbol, PERIOD_M1, 4);
   double momentumPoints = (_Point > 0.0 ? MathAbs(close1 - close4) / _Point : 0.0);
   if(momentumPoints >= 80.0) score += WeightMomentumV32;
   else score += WeightMomentumV32 * V32Clamp(momentumPoints / 80.0, 0.0, 1.0);
   double atr = V32GetATRPoints(PERIOD_M1, RegimeATRPeriodV32, 1);
   if(atr >= MinHealthyATRPointsV32 && atr <= MaxDangerATRPointsV32) score += WeightVolatilityV32;
   if((direction == ORDER_TYPE_BUY && close1 > open1) || (direction == ORDER_TYPE_SELL && close1 < open1)) score += WeightCandleConfirmationV32;
   string regimeReason = "";
   bool regimeOK = CheckMarketRegimeV32(regimeReason);
   if(regimeOK) score += WeightAntiRangeV32;
   int spread = GetCurrentSpreadPoints();
   if(spread <= MaxSpreadPoints) score += WeightSpreadCostV32;
   else if(spread <= ExtremeSpreadPoints) score += WeightSpreadCostV32 * 0.5;
   double normalized = (maxScore > 0.0 ? (score / maxScore) * 100.0 : 0.0);
   reason = "trend=" + trendReason + "; regime=" + regimeReason + "; momentum=" + DoubleToString(momentumPoints,1) + "; spread=" + IntegerToString(spread);
   if(direction == ORDER_TYPE_BUY) g_v32LastBuyQualityScore = normalized;
   if(direction == ORDER_TYPE_SELL) g_v32LastSellQualityScore = normalized;
   g_v32LastEntryQualityScore = normalized;
   return V32Clamp(normalized, 0.0, 100.0);
}

bool CheckEntryQualityV32(ENUM_ORDER_TYPE direction, string &reason)
{
   if(!UseEntryQualityV32)
   {
      reason = "ENTRY QUALITY OFF";
      return true;
   }
   double score = CalculateEntryQualityScoreV32(direction, reason);
   bool allow = (score >= MinEntryQualityV32);
   g_v32LastEntryQualityResult = (allow ? "WOULD_ALLOW" : "WOULD_BLOCK");
   g_v32LastEntryQualityReason = reason;
   AuditV32("[V3_2_ENTRY_QUALITY] direction=" + V32OrderTypeToText(direction) + " score=" + DoubleToString(score,1) + " min=" + DoubleToString(MinEntryQualityV32,1) + " result=" + g_v32LastEntryQualityResult + " reason=" + reason);
   if(EntryQualityV32_DiagnosticOnly || V32_GlobalDiagnosticOnly)
      return true;
   return allow;
}

bool CheckLayerQualityGateV32(ENUM_ORDER_TYPE direction, int layerIndex, string &reason)
{
   reason = "LAYER GATE OFF";
   if(!UseLayerQualityGateV32)
      return true;
   string qReason = "";
   double score = CalculateEntryQualityScoreV32(direction, qReason);
   bool allow = (score >= MinLayerQualityScoreV32);
   if(!allow) reason = "LAYER_SCORE_LOW";
   if(allow && RequireNoExtremeSpreadForLayerV32 && GetCurrentSpreadPoints() > MaxLayerSpreadPoints) { allow = false; reason = "LAYER_SPREAD_HIGH"; }
   if(allow && RequireMainPositionNotDeepNegativeV32 && g_reentryLayer.hasMainPosition && g_reentryLayer.mainPositionTicket > 0 && PositionSelectByTicket(g_reentryLayer.mainPositionTicket))
   {
      double profit = PositionGetDouble(POSITION_PROFIT);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      long type = PositionGetInteger(POSITION_TYPE);
      double adversePoints = 0.0;
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(type == POSITION_TYPE_BUY) adversePoints = MathMax(0.0, (open - bid) / _Point);
      if(type == POSITION_TYPE_SELL) adversePoints = MathMax(0.0, (ask - open) / _Point);
      if(profit < -MaxMainAdverseMoneyForLayerV32 || adversePoints > MaxMainAdversePointsForLayerV32) { allow = false; reason = "MAIN_TOO_NEGATIVE"; }
   }
   if(allow) reason = "LAYER_GATE_OK";
   g_v32LastLayerGateResult = (allow ? "WOULD_ALLOW" : "WOULD_BLOCK");
   g_v32LastLayerGateReason = reason;
   AuditV32("[V3_2_LAYER_GATE] layer=" + IntegerToString(layerIndex) + " score=" + DoubleToString(score,1) + " result=" + g_v32LastLayerGateResult + " reason=" + reason);
   if(LayerQualityGateV32_DiagnosticOnly || V32_GlobalDiagnosticOnly)
      return true;
   return allow;
}

bool IsV32RealEntryAllowed(ENUM_REAL_EXECUTION_DIRECTION realDirection, string &reason)
{
   reason = "V3.2 NOT ACTIVE";
   if(!UseV32EntryQualityProfitDistribution)
      return true;
   ENUM_ORDER_TYPE direction = V32RealDirectionToOrderType(realDirection);
   if(direction != ORDER_TYPE_BUY && direction != ORDER_TYPE_SELL)
   {
      reason = "NO_V32_DIRECTION";
      return true;
   }
   if(V32_GlobalDiagnosticOnly || !V32_AllowRealEntryBlocking)
   {
      string diagReason = "";
      CheckEntryQualityV32(direction, diagReason);
      CheckMTFTrendFilterV32(direction, diagReason);
      CheckAntiOvertradeV32(diagReason);
      CheckDirectionalBiasV32(direction, diagReason);
      CheckMarketRegimeV32(diagReason);
      reason = "V3.2 DIAGNOSTIC ONLY - ENTRY NOT BLOCKED";
      return true;
   }
   bool antiOvertradeOk = CheckAntiOvertradeV32(reason);
   if(!antiOvertradeOk) { g_v32LastBlockReason = reason; return false; }
   if(!CheckDirectionalBiasV32(direction, reason)) { g_v32LastBlockReason = reason; return false; }
   if(!CheckMTFTrendFilterV32(direction, reason)) { g_v32LastBlockReason = reason; return false; }
   if(!CheckEntryQualityV32(direction, reason)) { g_v32LastBlockReason = reason; return false; }
   double relaxedEntryQualityScore = g_v32LastEntryQualityScore;
   if(!CheckMarketRegimeV32Ex(direction, relaxedEntryQualityScore, antiOvertradeOk, true, reason)) { g_v32LastBlockReason = reason; return false; }
   reason = "V3.2 ENTRY ALLOWED";
   g_v32LastAction = reason;
   return true;
}

bool IsV32LayerEntryAllowed(string &reason)
{
   reason = "V3.2 LAYER NOT ACTIVE";
   if(!UseV32EntryQualityProfitDistribution)
      return true;
   ENUM_ORDER_TYPE direction = V32LayerDirectionToOrderType();
   if(direction != ORDER_TYPE_BUY && direction != ORDER_TYPE_SELL)
      return true;
   int layerIndex = V32CountMagicPositions();
   bool allow = CheckLayerQualityGateV32(direction, layerIndex, reason);
   if(!allow) g_v32LastBlockReason = reason;
   return allow;
}

void LogV32ABTest(ENUM_ORDER_TYPE direction, double score, string reason)
{
   AuditV32("[V3_2_AB_TEST] V3_1_ENTRY_ALLOWED=true V3_2_ENTRY_QUALITY_SCORE=" + DoubleToString(score,1) + " V3_2_WOULD_BLOCK=" + BoolToText(score < MinEntryQualityV32) + " V3_2_WOULD_BLOCK_REASON=" + reason + " V3_2_EXPECTED_IMPROVEMENT=FILTER_BAD_ENTRY direction=" + V32OrderTypeToText(direction));
}

void UpdateV32Diagnostics()
{
   if(!UseV32EntryQualityProfitDistribution)
      return;
   AuditV32("[V3_2_MASTER] ACTIVE=" + BoolToText(UseV32EntryQualityProfitDistribution) + " GLOBAL_DIAGNOSTIC_ONLY=" + BoolToText(V32_GlobalDiagnosticOnly) + " REAL_BLOCKING_ALLOWED=" + BoolToText(V32_AllowRealEntryBlocking) + " PROFIT_DISTRIBUTION_CLOSE_ALLOWED=" + BoolToText(V32_AllowRealProfitDistributionClose));
   string r = "";
   double buyScore = CalculateEntryQualityScoreV32(ORDER_TYPE_BUY, r);
   LogV32ABTest(ORDER_TYPE_BUY, buyScore, r);
   double sellScore = CalculateEntryQualityScoreV32(ORDER_TYPE_SELL, r);
   LogV32ABTest(ORDER_TYPE_SELL, sellScore, r);
   CheckAntiOvertradeV32(r);
   CheckDirectionalBiasV32(ORDER_TYPE_BUY, r);
}


bool IsV32ConfirmedReversal(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return false;
   long type = (long)PositionGetInteger(POSITION_TYPE);
   double ema50 = V32GetMA(PERIOD_M1, 50, 1);
   double close1 = iClose(_Symbol, PERIOD_M1, 1);
   double low1 = iLow(_Symbol, PERIOD_M1, 1);
   double low2 = iLow(_Symbol, PERIOD_M1, 2);
   double high1 = iHigh(_Symbol, PERIOD_M1, 1);
   double high2 = iHigh(_Symbol, PERIOD_M1, 2);
   double adx = MathMax(V32GetADX(PERIOD_M5, TrendADXPeriod, 1), V32GetADX(PERIOD_M15, TrendADXPeriod, 1));
   if(type == POSITION_TYPE_BUY)
      return (close1 < ema50 && low1 < low2 && adx >= MinTrendADXV32);
   if(type == POSITION_TYPE_SELL)
      return (close1 > ema50 && high1 > high2 && adx >= MinTrendADXV32);
   return false;
}

bool IsV32HealthyPullback(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return false;
   long type = (long)PositionGetInteger(POSITION_TYPE);
   double ema50 = V32GetMA(PERIOD_M1, 50, 1);
   double close1 = iClose(_Symbol, PERIOD_M1, 1);
   double adx = MathMax(V32GetADX(PERIOD_M5, TrendADXPeriod, 1), V32GetADX(PERIOD_M15, TrendADXPeriod, 1));
   if(type == POSITION_TYPE_BUY)
      return (close1 >= ema50 && adx >= MinTrendADXV32 && !IsV32ConfirmedReversal(ticket));
   if(type == POSITION_TYPE_SELL)
      return (close1 <= ema50 && adx >= MinTrendADXV32 && !IsV32ConfirmedReversal(ticket));
   return false;
}

bool IsV32RunnerPromotionCandidate(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return false;
   long type = (long)PositionGetInteger(POSITION_TYPE);
   double open = PositionGetDouble(POSITION_PRICE_OPEN);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double points = 0.0;
   if(type == POSITION_TYPE_BUY) points = (bid - open) / _Point;
   if(type == POSITION_TYPE_SELL) points = (open - ask) / _Point;
   double adx = MathMax(V32GetADX(PERIOD_M5, TrendADXPeriod, 1), V32GetADX(PERIOD_M15, TrendADXPeriod, 1));
   bool profitOK = (points >= RunnerPromotionMinProfitPointsV32 || PositionGetDouble(POSITION_PROFIT) >= RunnerMinProfitMoneyToProtectV32);
   bool trendOK = (adx >= RunnerPromotionMinADXV32 && IsV32HealthyPullback(ticket));
   return (profitOK && trendOK && !IsV32ConfirmedReversal(ticket));
}

void PromoteStrongPositionsToRunnerV32()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(GetPositionRoleV32(ticket) == ROLE_RUNNER) continue;
      if(IsV32RunnerPromotionCandidate(ticket))
      {
         AssignPositionRoleV32(ticket, ROLE_RUNNER, "EARLY_RUNNER_PROMOTION_TREND_PULLBACK_HEALTHY");
         g_v32RunnerTicket = ticket;
         AuditV32("[V3_2_RUNNER_PROMOTION] ticket=" + UlongToText(ticket) + " result=PROMOTED_TO_RUNNER");
      }
   }
}

bool CheckProfitDistributionCloseV32(ulong ticket, string &reason)
{
   reason = "";
   if(!PositionSelectByTicket(ticket)) { reason = "POSITION_NOT_FOUND"; return false; }
   if(PositionGetString(POSITION_SYMBOL) != _Symbol) { reason = "SYMBOL_MISMATCH"; return false; }
   if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber) { reason = "MAGIC_MISMATCH"; return false; }
   double profit = PositionGetDouble(POSITION_PROFIT);
   if(profit <= 0.0) { reason = "NEGATIVE_OR_ZERO_PROFIT"; return false; }
   EV32PositionRole role = GetPositionRoleV32(ticket);
   if((role == ROLE_RUNNER || IsV32RunnerPromotionCandidate(ticket)) && !IsV32ConfirmedReversal(ticket))
   {
      if(role != ROLE_RUNNER)
         AssignPositionRoleV32(ticket, ROLE_RUNNER, "PROFIT_DISTRIBUTION_EARLY_RUNNER_PROTECTION");
      reason = "GOOD_RUNNER_PULLBACK_HOLD_NO_CLOSE";
      AuditV32("[V3_2_PROFIT_DISTRIBUTION] ticket=" + UlongToText(ticket) + " result=GOOD_RUNNER_PULLBACK_HOLD_NO_CLOSE");
      return false;
   }
   double target = 0.0;
   string action = "";
   if(role == ROLE_MAIN && CloseMainAtSmallProfitV32) { target = MainTargetMoneyV32; action = "WOULD_CLOSE_MAIN"; }
   else if(role == ROLE_LAYER_1 && CloseLayer1AtMediumProfitV32) { target = Layer1TargetMoneyV32; action = "WOULD_CLOSE_LAYER1"; }
   else if(role == ROLE_RUNNER && LetRunnerRunV32) { reason = "LET_RUNNER_RUN"; g_v32LastProfitDistributionMode = reason; AuditV32("[V3_2_PROFIT_DISTRIBUTION] ticket=" + UlongToText(ticket) + " role=RUNNER profit=" + DoubleToString(profit,2) + " result=LET_RUNNER_RUN"); return false; }
   else { reason = "NO_ROLE_TARGET"; return false; }
   bool shouldClose = (profit >= target && target > 0.0);
   reason = action;
   AuditV32("[V3_2_PROFIT_DISTRIBUTION] ticket=" + UlongToText(ticket) + " role=" + RoleToTextV32(role) + " profit=" + DoubleToString(profit,2) + " target=" + DoubleToString(target,2) + " result=" + (shouldClose ? action : "WAIT_TARGET"));
   return shouldClose;
}

bool UpdateRunnerEngineV32(ulong ticket, string &reason)
{
   reason = "";
   if(!UseRunnerEngineV32) { reason = "RUNNER_OFF"; return false; }
   if(!PositionSelectByTicket(ticket)) { reason = "RUNNER_POSITION_NOT_FOUND"; return false; }
   if(GetPositionRoleV32(ticket) != ROLE_RUNNER)
   {
      if(IsV32RunnerPromotionCandidate(ticket))
         AssignPositionRoleV32(ticket, ROLE_RUNNER, "RUNNER_ENGINE_EARLY_PROMOTION");
      else { reason = "NOT_RUNNER_ROLE"; AuditV32("[V3_2_RUNNER][BLOCK_REASON] NOT_RUNNER_ROLE ticket=" + UlongToText(ticket)); return false; }
   }
   double open = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl = PositionGetDouble(POSITION_SL);
   double tp = PositionGetDouble(POSITION_TP);
   long type = PositionGetInteger(POSITION_TYPE);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double profitPoints = 0.0;
   if(type == POSITION_TYPE_BUY) profitPoints = (bid - open) / _Point;
   if(type == POSITION_TYPE_SELL) profitPoints = (open - ask) / _Point;
   g_v32LastRunnerStatus = "ACTIVE ticket=" + UlongToText(ticket) + " points=" + DoubleToString(profitPoints,1);
   AuditV32("[V3_2_RUNNER] ticket=" + UlongToText(ticket) + " status=ACTIVE profitPoints=" + DoubleToString(profitPoints,1));
   if(RunnerEngineV32_DiagnosticOnly || V32_GlobalDiagnosticOnly || !V32_AllowRunnerRealManagement || !AllowRunnerRealModifyV32)
   {
      if(profitPoints >= RunnerBreakEvenTriggerPointsV32) AuditV32("[V3_2_RUNNER] ticket=" + UlongToText(ticket) + " result=WOULD_MOVE_BE");
      if(profitPoints >= RunnerTrailingStartPointsV32) AuditV32("[V3_2_RUNNER] ticket=" + UlongToText(ticket) + " result=WOULD_TRAIL");
      return false;
   }
   if(profitPoints < RunnerTrailingStartPointsV32)
   {
      reason = "RUNNER_WAIT_TRAIL_START";
      return false;
   }
   double atrPoints = MathMax(GetExitATRPoints(), (double)RunnerTrailingDistancePointsV32);
   double runnerTrailDistance = MathMax((double)RunnerTrailingDistancePointsV32, atrPoints * RunnerATRMultV32);
   if(profitPoints >= atrPoints * 3.0) runnerTrailDistance = MathMax(runnerTrailDistance, atrPoints * StrongRunnerATRMultV32);
   if(profitPoints >= atrPoints * 5.0) runnerTrailDistance = MathMax(runnerTrailDistance, atrPoints * ExceptionalRunnerATRMultV32);

   double newSL = sl;
   if(type == POSITION_TYPE_BUY)
   {
      newSL = bid - runnerTrailDistance * _Point;
      if(sl > 0.0 && newSL <= sl + RunnerTrailingStepPointsV32 * _Point) { reason = "RUNNER_TRAIL_STEP_NOT_REACHED"; return false; }
      if(newSL <= open) newSL = open + RunnerBreakEvenOffsetPointsV32 * _Point;
   }
   if(type == POSITION_TYPE_SELL)
   {
      newSL = ask + runnerTrailDistance * _Point;
      if(sl > 0.0 && newSL >= sl - RunnerTrailingStepPointsV32 * _Point) { reason = "RUNNER_TRAIL_STEP_NOT_REACHED"; return false; }
      if(newSL >= open) newSL = open - RunnerBreakEvenOffsetPointsV32 * _Point;
   }
   bool ok = ModifyPositionSmart(ticket, NormalizeDouble(newSL, _Digits), tp, "V3_2_RUNNER_TRAIL");
   reason = (ok ? "RUNNER_TRAIL_OK" : "RUNNER_TRAIL_FAIL");
   AuditV32("[V3_2_RUNNER] ticket=" + UlongToText(ticket) + " result=" + reason);
   return ok;
}

void UpdateProfitDistributionV32()
{
   if(!UseProfitDistributionV32)
      return;
   SyncPositionRolesV32();
   PromoteStrongPositionsToRunnerV32();
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      EV32PositionRole role = GetPositionRoleV32(ticket);
      if(role == ROLE_RUNNER)
      {
         string runnerReason = "";
         UpdateRunnerEngineV32(ticket, runnerReason);
      }
      string closeReason = "";
      if(CheckProfitDistributionCloseV32(ticket, closeReason))
      {
         if(ProfitDistributionV32_DiagnosticOnly || V32_GlobalDiagnosticOnly || !V32_AllowRealProfitDistributionClose || !AllowProfitDistributionRealCloseV32)
         {
            AuditV32("[V3_2_PROFIT_DISTRIBUTION] ticket=" + UlongToText(ticket) + " result=" + closeReason + " mode=DIAGNOSTIC_ONLY");
            continue;
         }
         ClosePositionSmart(ticket, "V3_2_PROFIT_DISTRIBUTION_" + closeReason);
      }
   }
}

double V32BasketProfit()
{
   double profit = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      profit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return profit;
}

bool CheckAdaptiveBasketCloseV32(string &reason)
{
   reason = "";
   if(!UseAdaptiveBasketCloseV32)
   {
      reason = "ADAPTIVE_BASKET_OFF";
      return false;
   }
   double profit = V32BasketProfit();
   double target = BasketTargetSmallV32;
   string mode = "SMALL";
   if(g_v32RunnerTicket > 0 && HoldBasketLongerIfRunnerStrongV32 && profit >= MinBasketProfitToHoldRunnerV32)
   {
      target = BasketRunnerModeTargetV32;
      mode = "RUNNER";
   }
   else if(profit >= BasketTargetStrongV32) { target = BasketTargetStrongV32; mode = "STRONG"; }
   else if(profit >= BasketTargetMediumV32) { target = BasketTargetMediumV32; mode = "MEDIUM"; }
   g_v32AdaptiveBasketTarget = target;
   g_v32LastAdaptiveBasketMode = mode;
   bool shouldClose = (profit >= target && target > 0.0);
   reason = (shouldClose ? "ADAPTIVE_BASKET_TARGET_REACHED" : "ADAPTIVE_BASKET_WAIT");
   AuditV32("[V3_2_ADAPTIVE_BASKET] profit=" + DoubleToString(profit,2) + " target=" + DoubleToString(target,2) + " mode=" + mode + " result=" + (shouldClose ? "WOULD_CLOSE" : "HOLD_RUNNER"));
   if(AdaptiveBasketCloseV32_DiagnosticOnly || V32_GlobalDiagnosticOnly || !AllowAdaptiveBasketCloseRealV32)
      return false;
   if(!shouldClose)
      return false;
   return ApplyBasketSmartClose(reason);
}

void UpdateV32PositionManagement()
{
   if(!UseV32EntryQualityProfitDistribution)
      return;
   SyncPositionRolesV32();
   PromoteStrongPositionsToRunnerV32();
   UpdateProfitDistributionV32();
   string basketReason = "";
   CheckAdaptiveBasketCloseV32(basketReason);
}

//+------------------------------------------------------------------+
//| Dashboard                                                        |
//+------------------------------------------------------------------+
void DeleteDashboard()
{
   int total = ObjectsTotal(0, -1, -1);

   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, -1, -1);

      if(StringFind(name, DASH_PREFIX) == 0)
         ObjectDelete(0, name);
   }

   g_dashboardCreated = false;
}

void CreateDashboard()
{
   if(!ShowDashboard)
      return;

   DeleteDashboard();

   for(int i = 0; i < DASH_TOTAL_LINES; i++)
   {
      string name = DASH_PREFIX + IntegerToString(i);

      if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
         continue;

      ObjectSetInteger(0, name, OBJPROP_CORNER, DashboardCorner);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, DashboardX);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, DashboardY + (i * DashboardLineHeight));
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, DashboardFontSize);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      ObjectSetString(0, name, OBJPROP_TEXT, "");
   }

   g_dashboardCreated = true;
   UpdateDashboard();
}

void SetDashboardLine(int index, string text)
{
   if(!ShowDashboard)
      return;

   if(index < 0 || index >= DASH_TOTAL_LINES)
      return;

   string name = DASH_PREFIX + IntegerToString(index);

   if(ObjectFind(0, name) < 0)
      return;

   ObjectSetString(0, name, OBJPROP_TEXT, text);
}


void ClearDashboardLines()
{
   if(!ShowDashboard)
      return;

   for(int i = 0; i < DASH_TOTAL_LINES; i++)
      SetDashboardLine(i, "");
}

void AddDashboardLine(int &row, string text)
{
   SetDashboardLine(row, text);
   row++;
}

int NormalizeDashboardPage()
{
   if(DashboardPage < 1)
      return 1;
   if(DashboardPage > 15)
      return 15;
   return DashboardPage;
}

void UpdateDashboardPage1()
{
   int row = 0;
   AddDashboardLine(row, "HORSE EA - PROP CHALLENGE EDITION");
   AddDashboardLine(row, "Stage: 11 - POSITION MANAGER | DASH PAGE 1/7");
   AddDashboardLine(row, "Page 1 = Core + Security + Market/ATR");
   AddDashboardLine(row, "Symbol: " + _Symbol);
   AddDashboardLine(row, "Timeframe: " + TimeframeToText((ENUM_TIMEFRAMES)_Period));
   AddDashboardLine(row, "Magic: " + IntegerToString((int)MagicNumber));
   AddDashboardLine(row, "EA Status: " + g_eaStatus);
   AddDashboardLine(row, "Diagnostic Mode: " + BoolToText(UseDiagnosticMode));
   AddDashboardLine(row, "Live Trading Allowed: " + BoolToText(g_liveTradingAllowed));
   AddDashboardLine(row, "Symbol OK: " + BoolToText(g_symbolOK));
   AddDashboardLine(row, "Timeframe OK: " + BoolToText(g_timeframeOK));
   AddDashboardLine(row, "Environment OK: " + BoolToText(g_environmentOK));
   AddDashboardLine(row, "Terminal Connected: " + BoolToText(g_terminalConnected));
   AddDashboardLine(row, "MQL Trade Allowed: " + BoolToText(g_mqlTradeAllowed));
   AddDashboardLine(row, "Account Trade Allowed: " + BoolToText(g_accountTradeAllowed));
   AddDashboardLine(row, "Price Feed OK: " + BoolToText(g_priceFeedOK));
   AddDashboardLine(row, "--- SECURITY ---");
   AddDashboardLine(row, "Security Filters OK: " + BoolToText(g_securityFiltersOK));
   AddDashboardLine(row, "Security Reason: " + g_securityFilterReason);
   AddDashboardLine(row, "Spread: " + IntegerToString(g_currentSpreadPoints));
   AddDashboardLine(row, "Max Spread: " + IntegerToString(MaxSpreadPoints));
   AddDashboardLine(row, "Spread Status: " + g_spreadStatus);
   AddDashboardLine(row, "Session OK: " + BoolToText(g_sessionOK));
   AddDashboardLine(row, "Session Status: " + g_sessionStatus);
   AddDashboardLine(row, "Cooldown OK: " + BoolToText(g_cooldownOK));
   AddDashboardLine(row, "Cooldown Status: " + g_cooldownStatus);
   AddDashboardLine(row, "Price Data OK: " + BoolToText(g_priceOK));
   AddDashboardLine(row, "Price Status: " + g_priceStatus);
   AddDashboardLine(row, "Margin Diagnostic OK: " + BoolToText(g_marginOK));
   AddDashboardLine(row, "Margin Status: " + g_marginStatus);
   AddDashboardLine(row, "Account Safety OK: " + BoolToText(g_accountSafetyOK));
   AddDashboardLine(row, "Account Safety Status: " + g_accountSafetyStatus);
   AddDashboardLine(row, "--- MARKET / ATR ---");
   AddDashboardLine(row, "ATR M1: " + DoubleToString(g_atrM1Points, 1));
   AddDashboardLine(row, "ATR M5: " + DoubleToString(g_atrM5Points, 1));
   AddDashboardLine(row, "Current Candle Range: " + DoubleToString(g_currentCandleRangePoints, 1));
   AddDashboardLine(row, "Average Range: " + DoubleToString(g_averageRangePoints, 1));
   AddDashboardLine(row, "Body Ratio: " + DoubleToString(g_bodyRatio, 2));
   AddDashboardLine(row, "Upper Wick Ratio: " + DoubleToString(g_upperWickRatio, 2));
   AddDashboardLine(row, "Lower Wick Ratio: " + DoubleToString(g_lowerWickRatio, 2));
   AddDashboardLine(row, "Volatility Status: " + g_volatilityStatus);
   AddDashboardLine(row, "Market Mode: " + g_marketModeStatus);
   AddDashboardLine(row, "Market Strength: " + g_marketStrengthStatus);
   AddDashboardLine(row, "Market Tradable: " + BoolToText(g_market.isTradable));
   AddDashboardLine(row, "Market Reason: " + g_marketDiagnosticReason);
}

void UpdateDashboardPage2()
{
   int row = 0;
   AddDashboardLine(row, "HORSE EA - PROP CHALLENGE EDITION");
   AddDashboardLine(row, "Stage: 11 - POSITION MANAGER | DASH PAGE 2/7");
   AddDashboardLine(row, "Page 2 = Flow + Entry Base + Entry Decision");
   AddDashboardLine(row, "EA Status: " + g_eaStatus);
   AddDashboardLine(row, "--- FLOW ENGINE ---");
   AddDashboardLine(row, "Flow Engine OK: " + BoolToText(g_flowOK));
   AddDashboardLine(row, "Flow Status: " + g_flowStatus);
   AddDashboardLine(row, "Flow Reason: " + g_flowReason);
   AddDashboardLine(row, "Flow Direction: " + g_flowDirectionText);
   AddDashboardLine(row, "BUY Strength: " + DoubleToString(g_buyStrengthScore, 1));
   AddDashboardLine(row, "SELL Strength: " + DoubleToString(g_sellStrengthScore, 1));
   AddDashboardLine(row, "Momentum Score: " + DoubleToString(g_momentumScore, 1));
   AddDashboardLine(row, "Acceleration Score: " + DoubleToString(g_accelerationScore, 1));
   AddDashboardLine(row, "Rejection Score: " + DoubleToString(g_rejectionScore, 1));
   AddDashboardLine(row, "BUY Rejection: " + DoubleToString(g_buyRejectionScore, 1));
   AddDashboardLine(row, "SELL Rejection: " + DoubleToString(g_sellRejectionScore, 1));
   AddDashboardLine(row, "Imbalance Score: " + DoubleToString(g_imbalanceScore, 1));
   AddDashboardLine(row, "BUY Imbalance: " + DoubleToString(g_buyImbalanceScore, 1));
   AddDashboardLine(row, "SELL Imbalance: " + DoubleToString(g_sellImbalanceScore, 1));
   AddDashboardLine(row, "Flow Danger Score: " + DoubleToString(g_flowDangerScore, 1));
   AddDashboardLine(row, "Flow Quality Score: " + DoubleToString(g_flowQualityScore, 1));
   AddDashboardLine(row, "BUY Dominant: " + BoolToText(g_buyFlowDominant));
   AddDashboardLine(row, "SELL Dominant: " + BoolToText(g_sellFlowDominant));
   AddDashboardLine(row, "Flow Balanced: " + BoolToText(g_flowBalanced));
   AddDashboardLine(row, "Flow Dangerous: " + BoolToText(g_flowDangerous));
   AddDashboardLine(row, "--- ENTRY BASE SCORE ---");
   AddDashboardLine(row, "Entry Base OK: " + BoolToText(g_entryBaseOK));
   AddDashboardLine(row, "Entry Base Status: " + g_entryBaseStatus);
   AddDashboardLine(row, "Entry Base Reason: " + g_entryBaseReason);
   AddDashboardLine(row, "Entry Base Direction: " + EntryDirectionToText());
   AddDashboardLine(row, "Entry Base Score: " + DoubleToString(g_entryBaseScore, 2));
   AddDashboardLine(row, "BUY Entry Base Score: " + DoubleToString(g_buyEntryBaseScore, 2));
   AddDashboardLine(row, "SELL Entry Base Score: " + DoubleToString(g_sellEntryBaseScore, 2));
   AddDashboardLine(row, "BUY Candidate: " + BoolToText(g_buyEntryCandidate));
   AddDashboardLine(row, "SELL Candidate: " + BoolToText(g_sellEntryCandidate));
   AddDashboardLine(row, "Total Penalty: " + DoubleToString(g_totalEntryPenalty, 1));
   AddDashboardLine(row, "Entry Diagnostic Only: " + BoolToText(EntryBaseDiagnosticOnly));
   AddDashboardLine(row, "--- ENTRY DECISION ---");
   AddDashboardLine(row, "Entry Decision OK: " + BoolToText(g_entryDecisionOK));
   AddDashboardLine(row, "Entry Decision Status: " + g_entryDecisionStatus);
   AddDashboardLine(row, "Entry Decision Reason: " + g_entryDecisionReason);
   AddDashboardLine(row, "Entry Decision Direction: " + g_entryDecisionDirection);
   AddDashboardLine(row, "Entry Decision Text: " + g_entryDecisionText);
   AddDashboardLine(row, "Entry Decision Score: " + DoubleToString(g_entryDecisionScore, 2));
   AddDashboardLine(row, "BUY Decision Score: " + DoubleToString(g_buyDecisionScore, 2));
   AddDashboardLine(row, "SELL Decision Score: " + DoubleToString(g_sellDecisionScore, 2));
   AddDashboardLine(row, "Decision Difference: " + DoubleToString(g_decisionScoreDifference, 2));
   AddDashboardLine(row, "BUY Decision Candidate: " + BoolToText(g_buyDecisionCandidate));
   AddDashboardLine(row, "SELL Decision Candidate: " + BoolToText(g_sellDecisionCandidate));
   AddDashboardLine(row, "Decision Conflict: " + BoolToText(g_entryDecisionConflict));
   AddDashboardLine(row, "Decision Blocked: " + BoolToText(g_entryDecisionBlocked));
   AddDashboardLine(row, "Decision Diagnostic Only: " + BoolToText(EntryDecisionDiagnosticOnly));
}

void UpdateDashboardPage3()
{
   int row = 0;
   AddDashboardLine(row, "HORSE EA - PROP CHALLENGE EDITION");
   AddDashboardLine(row, "Stage: 11 - POSITION MANAGER | DASH PAGE 3/7");
   AddDashboardLine(row, "Page 3 = Virtual Entry + Pre-Execution Risk Gate");
   AddDashboardLine(row, "EA Status: " + g_eaStatus);
   AddDashboardLine(row, "--- VIRTUAL ENTRY ---");
   AddDashboardLine(row, "Virtual Entry Active: " + BoolToText(g_virtualEntryActive));
   AddDashboardLine(row, "Virtual Entry Completed: " + BoolToText(g_virtualEntryCompleted));
   AddDashboardLine(row, "Virtual Entry State: " + VirtualEntryStateToText(g_virtualEntry.state));
   AddDashboardLine(row, "Virtual Entry Direction: " + g_virtualEntryDirectionText);
   AddDashboardLine(row, "Virtual Entry Status: " + g_virtualEntryStatus);
   AddDashboardLine(row, "Virtual Entry Reason: " + g_virtualEntryReason);
   AddDashboardLine(row, "Virtual Entry Price: " + DoubleToString(g_virtualEntry.entryPrice, _Digits));
   AddDashboardLine(row, "Virtual Current Price: " + DoubleToString(g_virtualEntry.currentPrice, _Digits));
   AddDashboardLine(row, "Virtual SL: " + DoubleToString(g_virtualEntry.stopLossPrice, _Digits));
   AddDashboardLine(row, "Virtual TP: " + DoubleToString(g_virtualEntry.takeProfitPrice, _Digits));
   AddDashboardLine(row, "Virtual Risk Points: " + DoubleToString(g_virtualEntry.virtualRiskPoints, 1));
   AddDashboardLine(row, "Virtual Reward Points: " + DoubleToString(g_virtualEntry.virtualRewardPoints, 1));
   AddDashboardLine(row, "Virtual RR: " + DoubleToString(g_virtualEntry.virtualRR, 2));
   AddDashboardLine(row, "Virtual Profit Points: " + DoubleToString(g_virtualEntry.currentProfitPoints, 1));
   AddDashboardLine(row, "Virtual Profit Money: " + DoubleToString(g_virtualEntry.currentProfitMoney, 2));
   AddDashboardLine(row, "Virtual Result Score: " + DoubleToString(g_virtualEntryResultScore, 1));
   AddDashboardLine(row, "Virtual Total Simulations: " + IntegerToString(g_virtualTotalSimulations));
   AddDashboardLine(row, "Virtual Diagnostic Only: " + BoolToText(VirtualEntryDiagnosticOnly));
   AddDashboardLine(row, "--- PRE-EXECUTION RISK GATE ---");
   AddDashboardLine(row, "Pre Execution Approved: " + BoolToText(g_preExecutionApproved));
   AddDashboardLine(row, "Pre Execution Blocked: " + BoolToText(g_preExecutionBlocked));
   AddDashboardLine(row, "Pre Execution Waiting: " + BoolToText(g_preExecutionWaiting));
   AddDashboardLine(row, "Pre Execution Risk Danger: " + BoolToText(g_preExecutionRiskDanger));
   AddDashboardLine(row, "Pre Execution State: " + PreExecutionStateToText(g_preExecution.state));
   AddDashboardLine(row, "Pre Execution Status: " + g_preExecutionStatus);
   AddDashboardLine(row, "Pre Execution Reason: " + g_preExecutionReason);
   AddDashboardLine(row, "Pre Execution Block Reason: " + g_preExecutionBlockReason);
   AddDashboardLine(row, "Pre Execution Direction: " + g_preExecutionDirection);
   AddDashboardLine(row, "Pre Execution Score: " + DoubleToString(g_preExecutionScore, 2));
   AddDashboardLine(row, "Risk Score: " + DoubleToString(g_preExecutionRiskScore, 2));
   AddDashboardLine(row, "Virtual Confirmation Score: " + DoubleToString(g_preExecutionVirtualScore, 2));
   AddDashboardLine(row, "Account Safety Score: " + DoubleToString(g_preExecutionAccountScore, 2));
   AddDashboardLine(row, "Trade Cost Score: " + DoubleToString(g_preExecutionCostScore, 2));
   AddDashboardLine(row, "RR Score: " + DoubleToString(g_preExecutionRRScore, 2));
   AddDashboardLine(row, "Daily Risk Score: " + DoubleToString(g_preExecutionDailyRiskScore, 2));
   AddDashboardLine(row, "Estimated Lot: " + DoubleToString(g_estimatedExecutionLot, 2));
   AddDashboardLine(row, "Estimated Risk Money: " + DoubleToString(g_estimatedRiskMoney, 2));
   AddDashboardLine(row, "Estimated Reward Money: " + DoubleToString(g_estimatedRewardMoney, 2));
   AddDashboardLine(row, "Estimated Risk Percent: " + DoubleToString(g_estimatedRiskPercent, 3));
   AddDashboardLine(row, "Estimated Spread Cost: " + DoubleToString(g_estimatedSpreadCostMoney, 2));
   AddDashboardLine(row, "Estimated Commission: " + DoubleToString(g_estimatedCommissionBufferMoney, 2));
   AddDashboardLine(row, "Pre Execution Diagnostic Only: " + BoolToText(PreExecutionDiagnosticOnly));
}

void UpdateDashboardPage4()
{
   int row = 0;
   AddDashboardLine(row, "HORSE EA - PROP CHALLENGE EDITION");
   AddDashboardLine(row, "Stage: 11 - POSITION MANAGER | DASH PAGE 4/7");
   AddDashboardLine(row, "Page 4 = Execution Dry-Run + Planned Order");
   AddDashboardLine(row, "EA Status: " + g_eaStatus);
   AddDashboardLine(row, "Diagnostic Mode: " + BoolToText(UseDiagnosticMode));
   AddDashboardLine(row, "Live Trading Allowed: " + BoolToText(g_liveTradingAllowed));
   AddDashboardLine(row, "--- EXECUTION DRY-RUN ---");
   AddDashboardLine(row, "Dry Run Approved: " + BoolToText(g_dryRunApproved));
   AddDashboardLine(row, "Dry Run Blocked: " + BoolToText(g_dryRunBlocked));
   AddDashboardLine(row, "Dry Run Waiting: " + BoolToText(g_dryRunWaiting));
   AddDashboardLine(row, "Dry Run Buy Ready: " + BoolToText(g_dryRunBuyReady));
   AddDashboardLine(row, "Dry Run Sell Ready: " + BoolToText(g_dryRunSellReady));
   AddDashboardLine(row, "Dry Run Risk Block: " + BoolToText(g_dryRunRiskBlock));
   AddDashboardLine(row, "Dry Run Duplicate Block: " + BoolToText(g_dryRunDuplicateBlock));
   AddDashboardLine(row, "Dry Run State: " + ExecutionDryRunStateToText(g_executionDryRun.state));
   AddDashboardLine(row, "Dry Run Status: " + g_dryRunStatus);
   AddDashboardLine(row, "Dry Run Reason: " + g_dryRunReason);
   AddDashboardLine(row, "Dry Run Block Reason: " + g_dryRunBlockReason);
   AddDashboardLine(row, "Dry Run Direction: " + g_dryRunDirectionText);
   AddDashboardLine(row, "Dry Run Score: " + DoubleToString(g_dryRunScore, 2));
   AddDashboardLine(row, "Permission Score: " + DoubleToString(g_dryRunPermissionScore, 2));
   AddDashboardLine(row, "Direction Score: " + DoubleToString(g_dryRunDirectionScore, 2));
   AddDashboardLine(row, "Risk Permission Score: " + DoubleToString(g_dryRunRiskPermissionScore, 2));
   AddDashboardLine(row, "Duplicate Safety Score: " + DoubleToString(g_dryRunDuplicateSafetyScore, 2));
   AddDashboardLine(row, "Execution Cost Score: " + DoubleToString(g_dryRunExecutionCostScore, 2));
   AddDashboardLine(row, "--- PLANNED ORDER ---");
   AddDashboardLine(row, "Planned Order Type: " + g_executionDryRun.plannedOrderType);
   AddDashboardLine(row, "Planned Lot: " + DoubleToString(g_plannedExecutionLot, 2));
   AddDashboardLine(row, "Planned Entry Price: " + DoubleToString(g_plannedExecutionEntryPrice, _Digits));
   AddDashboardLine(row, "Planned SL: " + DoubleToString(g_plannedExecutionSL, _Digits));
   AddDashboardLine(row, "Planned TP: " + DoubleToString(g_plannedExecutionTP, _Digits));
   AddDashboardLine(row, "Planned Risk Money: " + DoubleToString(g_plannedExecutionRiskMoney, 2));
   AddDashboardLine(row, "Planned Reward Money: " + DoubleToString(g_plannedExecutionRewardMoney, 2));
   AddDashboardLine(row, "Planned Risk Percent: " + DoubleToString(g_plannedExecutionRiskPercent, 3));
   AddDashboardLine(row, "Planned RR: " + DoubleToString(g_executionDryRun.plannedRR, 2));
   AddDashboardLine(row, "Planned Spread Cost: " + DoubleToString(g_executionDryRun.plannedSpreadCostMoney, 2));
   AddDashboardLine(row, "Planned Commission: " + DoubleToString(g_executionDryRun.plannedCommissionMoney, 2));
   AddDashboardLine(row, "Last Dry Run Approval Time: " + (g_lastDryRunApprovalTime > 0 ? TimeToString(g_lastDryRunApprovalTime, TIME_DATE | TIME_SECONDS) : "NONE"));
   AddDashboardLine(row, "Last Dry Run Approval Candle: " + (g_lastDryRunApprovalBarTime > 0 ? TimeToString(g_lastDryRunApprovalBarTime, TIME_DATE | TIME_MINUTES) : "NONE"));
   AddDashboardLine(row, "Execution Dry Run Diagnostic Only: " + BoolToText(ExecutionDryRunDiagnosticOnly));
   AddDashboardLine(row, "UseExecutionDryRun: " + BoolToText(UseExecutionDryRun));
   AddDashboardLine(row, "No Real Orders Stage09: TRUE");
   AddDashboardLine(row, "Total trades expected: 0");
   AddDashboardLine(row, "Next: STAGE 12 REENTRY / LAYER ENGINE");
}


void UpdateDashboardPage5()
{
   int row = 0;
   AddDashboardLine(row, "HORSE EA - PROP CHALLENGE EDITION");
   AddDashboardLine(row, "Stage: 11 - POSITION MANAGER | DASH PAGE 5/7");
   AddDashboardLine(row, "Page 5 = Real Execution Engine");
   AddDashboardLine(row, "EA Status: " + g_eaStatus);
   AddDashboardLine(row, "--- REAL EXECUTION ENGINE ---");
   AddDashboardLine(row, "Use Real Execution Engine: " + BoolToText(UseRealExecutionEngine));
   AddDashboardLine(row, "Enable Real Execution: " + BoolToText(EnableRealExecution));
   AddDashboardLine(row, "Real Execution Simulation Only: " + BoolToText(RealExecutionSimulationOnly));
   AddDashboardLine(row, "Allow Live Trading: " + BoolToText(g_liveTradingAllowed));
   AddDashboardLine(row, "Allow Real In Diagnostic: " + BoolToText(AllowRealExecutionInDiagnosticMode));
   AddDashboardLine(row, "Real Execution State: " + RealExecutionStateToText(g_realExecution.state));
   AddDashboardLine(row, "Real Execution Status: " + g_realExecutionStatus);
   AddDashboardLine(row, "Real Execution Direction: " + g_realExecutionDirectionText);
   AddDashboardLine(row, "Real Execution Ready: " + BoolToText(g_realExecutionReady));
   AddDashboardLine(row, "Real Execution Blocked: " + BoolToText(g_realExecutionBlocked));
   AddDashboardLine(row, "Real Execution Risk Block: " + BoolToText(g_realExecutionRiskBlock));
   AddDashboardLine(row, "Real Execution Duplicate Block: " + BoolToText(g_realExecutionDuplicateBlock));
   AddDashboardLine(row, "Real Execution Broker Block: " + BoolToText(g_realExecutionBrokerBlock));
   AddDashboardLine(row, "Real Order Sent: " + BoolToText(g_realOrderSent));
   AddDashboardLine(row, "Real Buy Sent: " + BoolToText(g_realBuySent));
   AddDashboardLine(row, "Real Sell Sent: " + BoolToText(g_realSellSent));
   AddDashboardLine(row, "Real Execution Error: " + BoolToText(g_realExecutionError));
   AddDashboardLine(row, "--- EXECUTION DATA ---");
   AddDashboardLine(row, "Execution Lot: " + DoubleToString(g_realExecutionLot, 2));
   AddDashboardLine(row, "Execution Entry: " + DoubleToString(g_realExecutionEntryPrice, _Digits));
   AddDashboardLine(row, "Execution SL: " + DoubleToString(g_realExecutionSL, _Digits));
   AddDashboardLine(row, "Execution TP: " + DoubleToString(g_realExecutionTP, _Digits));
   AddDashboardLine(row, "Execution Risk Money: " + DoubleToString(g_realExecutionRiskMoney, 2));
   AddDashboardLine(row, "Execution Reward Money: " + DoubleToString(g_realExecutionRewardMoney, 2));
   AddDashboardLine(row, "Execution Risk Percent: " + DoubleToString(g_realExecutionRiskPercent, 3));
   AddDashboardLine(row, "Execution RR: " + DoubleToString(g_realExecutionRR, 2));
   AddDashboardLine(row, "Execution Margin Required: " + DoubleToString(g_realExecutionMarginRequired, 2));
   AddDashboardLine(row, "Execution Spread Points: " + DoubleToString(g_realExecution.executionSpreadPoints, 1));
   AddDashboardLine(row, "Real Execution Attempts: " + IntegerToString(g_realExecutionAttemptCount));
   AddDashboardLine(row, "Last Real Execution Time: " + (g_lastRealExecutionTime > 0 ? TimeToString(g_lastRealExecutionTime, TIME_DATE | TIME_SECONDS) : "NONE"));
   AddDashboardLine(row, "Last Real Execution Bar: " + (g_lastRealExecutionBarTime > 0 ? TimeToString(g_lastRealExecutionBarTime, TIME_DATE | TIME_MINUTES) : "NONE"));
   AddDashboardLine(row, "Last Attempt Time: " + (g_lastRealExecutionAttemptTime > 0 ? TimeToString(g_lastRealExecutionAttemptTime, TIME_DATE | TIME_SECONDS) : "NONE"));
   AddDashboardLine(row, "Last Order Ticket: " + UlongToText(g_lastRealOrderTicket));
   AddDashboardLine(row, "Last Deal Ticket: " + UlongToText(g_lastRealDealTicket));
   AddDashboardLine(row, "Last Position Ticket: " + UlongToText(g_lastRealPositionTicket));
   AddDashboardLine(row, "Real Execution Reason: " + g_realExecutionReason);
   AddDashboardLine(row, "Real Execution Block Reason: " + g_realExecutionBlockReason);
   AddDashboardLine(row, "Real Execution Broker Reason: " + g_realExecutionBrokerReason);
   AddDashboardLine(row, "Last Execution Error: " + g_lastRealExecutionErrorText);
}


void UpdateDashboardPage6()
{
   int row = 0;
   AddDashboardLine(row, "HORSE EA - PROP CHALLENGE EDITION");
   AddDashboardLine(row, "Stage: 11 - POSITION MANAGER | DASH PAGE 6/7");
   AddDashboardLine(row, "Page 6 = Position Manager");
   AddDashboardLine(row, "EA Status: " + g_eaStatus);
   AddDashboardLine(row, "--- POSITION MANAGER ---");
   AddDashboardLine(row, "Use Position Manager: " + BoolToText(UsePositionManager));
   AddDashboardLine(row, "Enable Position Actions: " + BoolToText(EnablePositionManagerActions));
   AddDashboardLine(row, "Position Manager Simulation Only: " + BoolToText(PositionManagerSimulationOnly));
   AddDashboardLine(row, "Allow Position Modify: " + BoolToText(AllowPositionModify));
   AddDashboardLine(row, "Allow BE Modify: " + BoolToText(AllowBreakEvenModify));
   AddDashboardLine(row, "Allow Trailing Modify: " + BoolToText(AllowTrailingModify));
   AddDashboardLine(row, "Allow Emergency Close: " + BoolToText(AllowEmergencyPositionClose));
   AddDashboardLine(row, "Allow Position In Diagnostic: " + BoolToText(AllowPositionManagerInDiagnosticMode));
   AddDashboardLine(row, "State Hold Enabled: " + BoolToText(UsePositionManagerStateHold));
   AddDashboardLine(row, "State Hold Active: " + BoolToText(UsePositionManagerStateHold && g_positionManagerStateHoldUntil > 0 && TimeCurrent() <= g_positionManagerStateHoldUntil && g_managedPositionFound));
   AddDashboardLine(row, "State Hold Until: " + (g_positionManagerStateHoldUntil > 0 ? TimeToString(g_positionManagerStateHoldUntil, TIME_DATE | TIME_SECONDS) : "NONE"));
   AddDashboardLine(row, "State Hold Reason: " + g_positionManagerHoldReason);
   AddDashboardLine(row, "Position Manager State: " + PositionManagerStateToText(g_positionManager.state));
   AddDashboardLine(row, "Position Manager Status: " + g_positionManagerStatus);
   AddDashboardLine(row, "Managed Position Found: " + BoolToText(g_managedPositionFound));
   AddDashboardLine(row, "Managed Position Direction: " + ManagedPositionDirectionToText(g_positionManager.direction));
   AddDashboardLine(row, "Position Ticket: " + UlongToText(g_positionManager.positionTicket));
   AddDashboardLine(row, "Position Type: " + ManagedPositionTypeToText(g_positionManager.positionType));
   AddDashboardLine(row, "Position Magic: " + IntegerToString((int)g_positionManager.positionMagic));
   AddDashboardLine(row, "Position Volume: " + DoubleToString(g_positionManager.volume, 2));
   AddDashboardLine(row, "Open Price: " + DoubleToString(g_positionManager.openPrice, _Digits));
   AddDashboardLine(row, "Current Price: " + DoubleToString(g_positionManager.currentPrice, _Digits));
   AddDashboardLine(row, "Current SL: " + DoubleToString(g_positionManager.currentSL, _Digits));
   AddDashboardLine(row, "Current TP: " + DoubleToString(g_positionManager.currentTP, _Digits));
   AddDashboardLine(row, "Proposed SL: " + DoubleToString(g_positionManager.proposedSL, _Digits));
   AddDashboardLine(row, "Proposed TP: " + DoubleToString(g_positionManager.proposedTP, _Digits));
   AddDashboardLine(row, "Profit Money: " + DoubleToString(g_positionManager.profitMoney, 2));
   AddDashboardLine(row, "Swap Money: " + DoubleToString(g_positionManager.swapMoney, 2));
   AddDashboardLine(row, "Commission Money: " + DoubleToString(g_positionManager.commissionMoney, 2));
   AddDashboardLine(row, "Net Profit Money: " + DoubleToString(g_positionManager.netProfitMoney, 2));
   AddDashboardLine(row, "Profit Points: " + DoubleToString(g_positionManager.profitPoints, 1));
   AddDashboardLine(row, "Adverse Points: " + DoubleToString(g_positionManager.adversePoints, 1));
   AddDashboardLine(row, "Max Profit Money: " + DoubleToString(g_positionManager.maxProfitMoney, 2));
   AddDashboardLine(row, "Max Adverse Money: " + DoubleToString(g_positionManager.maxAdverseMoney, 2));
   AddDashboardLine(row, "Max Favorable Points: " + DoubleToString(g_positionManager.maxFavorablePoints, 1));
   AddDashboardLine(row, "Max Adverse Points: " + DoubleToString(g_positionManager.maxAdversePoints, 1));
   AddDashboardLine(row, "Distance To SL Points: " + DoubleToString(g_positionManager.distanceToSLPoints, 1));
   AddDashboardLine(row, "Distance To TP Points: " + DoubleToString(g_positionManager.distanceToTPPoints, 1));
   AddDashboardLine(row, "Risk Money At SL: " + DoubleToString(g_positionManager.riskMoneyAtSL, 2));
   AddDashboardLine(row, "Reward Money At TP: " + DoubleToString(g_positionManager.rewardMoneyAtTP, 2));
   AddDashboardLine(row, "BreakEven Ready: " + BoolToText(g_breakEvenReady));
   AddDashboardLine(row, "BreakEven Applied: " + BoolToText(g_breakEvenApplied));
   AddDashboardLine(row, "Trailing Ready: " + BoolToText(g_trailingReady));
   AddDashboardLine(row, "Trailing Applied: " + BoolToText(g_trailingApplied));
   AddDashboardLine(row, "Profit Protection Active: " + BoolToText(g_profitProtectionActive));
   AddDashboardLine(row, "Emergency Block: " + BoolToText(g_positionEmergencyBlock));
   AddDashboardLine(row, "Emergency Closed: " + BoolToText(g_positionEmergencyClosed));
   AddDashboardLine(row, "Position Manager Error: " + BoolToText(g_positionManagerError));
   AddDashboardLine(row, "Last Modify Time: " + (g_lastPositionModifyTime > 0 ? TimeToString(g_lastPositionModifyTime, TIME_DATE | TIME_SECONDS) : "NONE"));
   AddDashboardLine(row, "Last Close Time: " + (g_lastPositionCloseTime > 0 ? TimeToString(g_lastPositionCloseTime, TIME_DATE | TIME_SECONDS) : "NONE"));
   AddDashboardLine(row, "Position Manager Reason: " + g_positionManagerReason);
   AddDashboardLine(row, "Position Manager Block Reason: " + g_positionManagerBlockReason);
   AddDashboardLine(row, "Position Manager Action Reason: " + g_positionManagerActionReason);
   AddDashboardLine(row, "Last Position Error: " + g_positionManagerLastErrorText);
}


void UpdateDashboardPage7()
{
   int row = 0;
   AddDashboardLine(row, "HORSE EA - PROP CHALLENGE EDITION");
   AddDashboardLine(row, "Stage: 12 FIX3 V3 - AGGRESSIVE 3 POSITIONS | DASH PAGE 7/7");
   AddDashboardLine(row, "Page 7 = Reentry / Layer Engine + Smart Exit");
   AddDashboardLine(row, "EA Status: " + g_eaStatus);
   AddDashboardLine(row, "--- FIX3 V3.1 SMART EXIT REAL ---");
   AddDashboardLine(row, "Smart Exit Active: " + BoolToText(UseSmartExitRealEngine));
   AddDashboardLine(row, "Smart Exit Simulation Only: " + BoolToText(SmartExitSimulationOnly));
   AddDashboardLine(row, "Allow Real Modify: " + BoolToText(AllowSmartExitRealModify));
   AddDashboardLine(row, "Allow Real Close: " + BoolToText(AllowSmartExitRealClose));
   AddDashboardLine(row, "BE Real: " + BoolToText(UseBreakEvenReal));
   AddDashboardLine(row, "Trailing Real: " + BoolToText(UseSmartTrailingReal));
   AddDashboardLine(row, "Dynamic TP: " + BoolToText(UseATRDynamicExit));
   AddDashboardLine(row, "Basket Profit: " + DoubleToString(g_basketProfit, 2));
   AddDashboardLine(row, "Basket Peak Profit: " + DoubleToString(g_basketPeakProfit, 2));
   AddDashboardLine(row, "Basket Close Reason: " + g_lastBasketCloseReason);
   AddDashboardLine(row, "Last Smart Exit Action: " + g_lastSmartExitAction);
   AddDashboardLine(row, "Last Smart Exit Block: " + g_lastSmartExitBlockReason);
   AddDashboardLine(row, "Last Modified Ticket: " + UlongToText(g_lastModifiedTicket));
   AddDashboardLine(row, "Last Closed Ticket: " + UlongToText(g_lastClosedTicket));
   AddDashboardLine(row, "Environment Status: " + g_lastEnvironmentStatus);
   AddDashboardLine(row, "Last Environment Block: " + g_lastEnvironmentBlock);
   AddDashboardLine(row, "--- FUNCTIONAL OVERRIDE FIX3 V3 ---");
   AddDashboardLine(row, "Functional Override: " + BoolToText(IsFunctionalExecutionOverrideActive()));
   AddDashboardLine(row, "Functional Safety: " + (g_functionalSafetyApproved ? "APPROVED" : "BLOCKED/WAIT"));
   AddDashboardLine(row, "Functional Reason: " + g_functionalSafetyReason);
   AddDashboardLine(row, "Functional Max Positions: " + IntegerToString(ForceFunctionalMaxTotalPositions));
   AddDashboardLine(row, "Functional Current Positions: " + IntegerToString(CountAllMagicPositions()));
   AddDashboardLine(row, "Functional Fixed Lot: " + DoubleToString(ForceFunctionalFixedLot, 2));
   AddDashboardLine(row, "Functional Real Execution: " + (IsFunctionalExecutionOverrideActive() ? "ALLOWED" : "BLOCKED/OFF"));
   AddDashboardLine(row, "Functional Layer Execution: " + (IsFunctionalLayerOverrideActive() ? "ALLOWED" : "BLOCKED/OFF"));
   AddDashboardLine(row, "Aggressive Cycle Active: " + BoolToText(g_fix3AggressiveCycleActive));
   AddDashboardLine(row, "Aggressive Cycle Reason: " + g_fix3AggressiveCycleReason);
   AddDashboardLine(row, "Trades Today: " + IntegerToString(g_fix3TradesToday));
   AddDashboardLine(row, "Last Order Plan: " + g_fix3LastOrderPlanReason);
   AddDashboardLine(row, "Last Block Reason: " + g_fix3LastBlockReason);
   AddDashboardLine(row, "--- REENTRY / LAYER MASTER ---");
   AddDashboardLine(row, "Use Reentry Layer Engine: " + BoolToText(UseReentryLayerEngine));
   AddDashboardLine(row, "Enable Layer Execution: " + BoolToText(EnableLayerExecution));
   AddDashboardLine(row, "Layer Simulation Only: " + BoolToText(LayerSimulationOnly));
   AddDashboardLine(row, "Allow Layer Orders: " + BoolToText(AllowLayerOrders));
   AddDashboardLine(row, "Allow Layer In Diagnostic: " + BoolToText(AllowLayerInDiagnosticMode));
   AddDashboardLine(row, "Layer State: " + LayerStateToText(g_reentryLayer.state));
   AddDashboardLine(row, "Layer Status: " + g_layerStatus);
   AddDashboardLine(row, "Layer Direction: " + LayerDirectionToText(g_reentryLayer.direction));
   AddDashboardLine(row, "Layer Ready: " + BoolToText(g_layerReady));
   AddDashboardLine(row, "Layer Sent: " + BoolToText(g_layerSent));
   AddDashboardLine(row, "Layer Blocked: " + BoolToText(g_layerBlocked));
   AddDashboardLine(row, "--- MAIN POSITION ---");
   AddDashboardLine(row, "Main Position Found: " + BoolToText(g_reentryLayer.hasMainPosition));
   AddDashboardLine(row, "Main Position Ticket: " + UlongToText(g_reentryLayer.mainPositionTicket));
   AddDashboardLine(row, "Main Profit Money: " + DoubleToString(g_reentryLayer.mainPositionProfitMoney, 2));
   AddDashboardLine(row, "Main Profit Points: " + DoubleToString(g_reentryLayer.mainPositionProfitPoints, 1));
   AddDashboardLine(row, "Main Position SL: " + DoubleToString(g_reentryLayer.mainPositionSL, _Digits));
   AddDashboardLine(row, "Main Position TP: " + DoubleToString(g_reentryLayer.mainPositionTP, _Digits));
   AddDashboardLine(row, "--- LAYER COUNTS / LIMITS ---");
   AddDashboardLine(row, "Current Layer Count: " + IntegerToString(g_currentLayerCount));
   AddDashboardLine(row, "Buy Layer Count: " + IntegerToString(g_buyLayerCount));
   AddDashboardLine(row, "Sell Layer Count: " + IntegerToString(g_sellLayerCount));
   AddDashboardLine(row, "Max Total Layers: " + IntegerToString(MaxTotalLayers));
   AddDashboardLine(row, "Max Layers Per Direction: " + IntegerToString(MaxLayersPerDirection));
   AddDashboardLine(row, "--- PLANNED LAYER ORDER ---");
   AddDashboardLine(row, "Planned Layer Lot: " + DoubleToString(g_plannedLayerLot, 2));
   AddDashboardLine(row, "Planned Layer Entry: " + DoubleToString(g_plannedLayerEntry, _Digits));
   AddDashboardLine(row, "Planned Layer SL: " + DoubleToString(g_plannedLayerSL, _Digits));
   AddDashboardLine(row, "Planned Layer TP: " + DoubleToString(g_plannedLayerTP, _Digits));
   AddDashboardLine(row, "Planned Risk Money: " + DoubleToString(g_plannedLayerRiskMoney, 2));
   AddDashboardLine(row, "Planned Reward Money: " + DoubleToString(g_plannedLayerRewardMoney, 2));
   AddDashboardLine(row, "Planned Layer RR: " + DoubleToString(g_plannedLayerRR, 2));
   AddDashboardLine(row, "--- DISTANCE / EXPOSURE ---");
   AddDashboardLine(row, "Distance From Last Layer Points: " + DoubleToString(g_layerDistanceFromLastEntryPoints, 1));
   AddDashboardLine(row, "Min Layer Distance Points: " + DoubleToString(MinLayerDistancePoints, 1));
   AddDashboardLine(row, "Total Layer Lots: " + DoubleToString(g_totalLayerLots, 2));
   AddDashboardLine(row, "Total Symbol Exposure Lots: " + DoubleToString(g_totalSymbolExposureLots, 2));
   AddDashboardLine(row, "--- APPROVAL FLAGS ---");
   AddDashboardLine(row, "Layer Risk Approved: " + BoolToText(g_layerRiskApproved));
   AddDashboardLine(row, "Layer Distance Approved: " + BoolToText(g_layerDistanceApproved));
   AddDashboardLine(row, "Layer Signal Approved: " + BoolToText(g_layerSignalApproved));
   AddDashboardLine(row, "Layer Exposure Approved: " + BoolToText(g_layerExposureApproved));
   AddDashboardLine(row, "Layer Broker Approved: " + BoolToText(g_layerBrokerApproved));
   AddDashboardLine(row, "--- LAST ACTION ---");
   AddDashboardLine(row, "Layer Last Ticket: " + UlongToText(g_lastLayerTicket));
   AddDashboardLine(row, "Layer Last Execution Time: " + (g_lastLayerExecutionTime > 0 ? TimeToString(g_lastLayerExecutionTime, TIME_DATE | TIME_SECONDS) : "NONE"));
   AddDashboardLine(row, "Layer Reason: " + g_layerReason);
   AddDashboardLine(row, "Layer Block Reason: " + g_layerBlockReason);
   AddDashboardLine(row, "Layer Action Reason: " + g_layerActionReason);
   AddDashboardLine(row, "Layer Last Error: " + g_layerLastErrorText);
}



void UpdateDashboardPage8()
{
   int row = 0;
   AddDashboardLine(row, "HORSE EA - PROP CHALLENGE EDITION");
   AddDashboardLine(row, "Stage: FIX3 V3.2 | DASH PAGE 8/8");
   AddDashboardLine(row, "Page 8 = Entry Quality + Profit Distribution Runner");
   AddDashboardLine(row, "EA Status: " + g_eaStatus);
   AddDashboardLine(row, "--- V3.2 MASTER ---");
   AddDashboardLine(row, "V3.2 Master Active: " + BoolToText(UseV32EntryQualityProfitDistribution));
   AddDashboardLine(row, "V3.2 Diagnostic Only: " + BoolToText(V32_GlobalDiagnosticOnly));
   AddDashboardLine(row, "Real Entry Blocking: " + BoolToText(V32_AllowRealEntryBlocking));
   AddDashboardLine(row, "Profit Dist Real Close: " + BoolToText(V32_AllowRealProfitDistributionClose));
   AddDashboardLine(row, "Runner Real Mgmt: " + BoolToText(V32_AllowRunnerRealManagement));
   AddDashboardLine(row, "--- ENTRY QUALITY ---");
   AddDashboardLine(row, "Last Entry Score: " + DoubleToString(g_v32LastEntryQualityScore, 1));
   AddDashboardLine(row, "BUY Quality: " + DoubleToString(g_v32LastBuyQualityScore, 1));
   AddDashboardLine(row, "SELL Quality: " + DoubleToString(g_v32LastSellQualityScore, 1));
   AddDashboardLine(row, "Entry Result: " + g_v32LastEntryQualityResult);
   AddDashboardLine(row, "Entry Reason: " + g_v32LastEntryQualityReason);
   AddDashboardLine(row, "--- FILTERS ---");
   AddDashboardLine(row, "Trend Result: " + g_v32LastTrendResult);
   AddDashboardLine(row, "Trend Reason: " + g_v32LastTrendReason);
   AddDashboardLine(row, "Market Regime: " + g_v32LastRegimeResult);
   AddDashboardLine(row, "Regime Reason: " + g_v32LastRegimeReason);
   AddDashboardLine(row, "--- BALANCED RELAXED ---");
   AddDashboardLine(row, "Balanced Relaxed FIX1 Active: " + BoolToText(UseBalancedRelaxedV32));
   AddDashboardLine(row, "Choppy Bypass Enabled: " + BoolToText(AllowHighQualityEntryInChoppyMarketV32));
   AddDashboardLine(row, "Choppy Bypass Result: " + g_v32LastChoppyBypassResult);
   AddDashboardLine(row, "Choppy Bypass Reason: " + g_v32LastChoppyBypassReason);
   AddDashboardLine(row, "Choppy Bypass Count100: " + IntegerToString(g_v32LastChoppyBypassCount100));
   AddDashboardLine(row, "Range Compression: " + DoubleToString(g_v32LastChoppyRangeCompression, 2));
   AddDashboardLine(row, "Min Quality Bypass: " + DoubleToString(MinQualityToBypassChoppyV32, 1));
   AddDashboardLine(row, "Balanced Relaxed FIX1 Active: " + BoolToText(UseBalancedRelaxedV32));
   AddDashboardLine(row, "Final Entry Decision FIX1: " + g_v32Fix1LastDecision);
   AddDashboardLine(row, "Final Block Reason FIX1: " + g_v32Fix1FinalBlockReason);
   AddDashboardLine(row, "Score 68 Moderate Range: " + DoubleToString(MinQualityForModerateRangeV32, 1));
   AddDashboardLine(row, "Score 70 Compressed Range: " + DoubleToString(MinQualityForCompressedRangeV32, 1));
   AddDashboardLine(row, "Strong Quality 72: " + DoubleToString(StrongQualityToBypassChoppyV32, 1));
   AddDashboardLine(row, "Extreme Compression Block: " + DoubleToString(ExtremeCompressionBlockV32, 2));
   AddDashboardLine(row, "Trend Aligned Bonus: " + BoolToText(g_v32Fix1TrendAlignedBonus));
   AddDashboardLine(row, "Bias Sample Status: " + g_v32Fix1BiasStatus);
   AddDashboardLine(row, "Choppy ATR Points: " + DoubleToString(g_v32LastChoppyATRPoints, 1));
   AddDashboardLine(row, "Choppy Spread Points: " + DoubleToString(g_v32LastChoppySpreadPoints, 1));
   AddDashboardLine(row, "Choppy Trend M5/M15: " + DoubleToString(g_v32LastChoppyTrendM5, 1) + "/" + DoubleToString(g_v32LastChoppyTrendM15, 1));
   AddDashboardLine(row, "Choppy ADX: " + DoubleToString(g_v32LastChoppyADX, 1));
   AddDashboardLine(row, "Last Relaxed Action: " + g_v32LastBalancedRelaxedAction);
   AddDashboardLine(row, "Anti-Overtrade: " + g_v32LastAntiOvertradeResult);
   AddDashboardLine(row, "Anti-Overtrade Reason: " + g_v32LastAntiOvertradeReason);
   AddDashboardLine(row, "Trades Last 100: " + IntegerToString(g_v32TradesLast100Candles));
   AddDashboardLine(row, "Cycles Last 100: " + IntegerToString(g_v32CyclesLast100Candles));
   AddDashboardLine(row, "Loss Streak: " + IntegerToString(g_v32CurrentLossStreak));
   AddDashboardLine(row, "Buy/Sell Ratio: " + DoubleToString(g_v32BuySellRatio, 2));
   AddDashboardLine(row, "Bias Result: " + g_v32LastBiasResult);
   AddDashboardLine(row, "Bias Reason: " + g_v32LastBiasReason);
   AddDashboardLine(row, "--- LAYER / ROLES / RUNNER ---");
   AddDashboardLine(row, "Layer Gate: " + g_v32LastLayerGateResult);
   AddDashboardLine(row, "Layer Gate Reason: " + g_v32LastLayerGateReason);
   AddDashboardLine(row, "Role States: " + IntegerToString(ArraySize(g_v32RoleStates)));
   AddDashboardLine(row, "Runner Ticket: " + UlongToText(g_v32RunnerTicket));
   AddDashboardLine(row, "Runner Status: " + g_v32LastRunnerStatus);
   AddDashboardLine(row, "--- PROFIT DISTRIBUTION / BASKET ---");
   AddDashboardLine(row, "Profit Dist Mode: " + g_v32LastProfitDistributionMode);
   AddDashboardLine(row, "Adaptive Basket Mode: " + g_v32LastAdaptiveBasketMode);
   AddDashboardLine(row, "Adaptive Basket Target: " + DoubleToString(g_v32AdaptiveBasketTarget, 2));
   AddDashboardLine(row, "V3.2 Last Action: " + g_v32LastAction);
   AddDashboardLine(row, "V3.2 Last Block: " + g_v32LastBlockReason);
}

void UpdateDashboardCompact()
{
   ClearDashboardLines();

   int page = NormalizeDashboardPage();

   if(page == 1)
      UpdateDashboardPage1();
   else if(page == 2)
      UpdateDashboardPage2();
   else if(page == 3)
      UpdateDashboardPage3();
   else if(page == 4)
      UpdateDashboardPage4();
   else if(page == 5)
      UpdateDashboardPage5();
   else if(page == 6)
      UpdateDashboardPage6();
   else if(page == 7)
      UpdateDashboardPage7();
   else if(page == 8)
      UpdateDashboardPage8();
   else if(page == 13)
      Stage13_UpdateWallboard();
   else if(page == 14)
      Stage14_UpdateWallboard();
   else if(page == 15)
      Stage15_UpdateWallboard();
   else
      UpdateDashboardPage9();
}

void UpdateDashboard()
{
   if(!ShowDashboard)
      return;

   if(UseCompactDashboard)
   {
      UpdateDashboardCompact();
      return;
   }

   UpdateDashboardFull();
}

void UpdateDashboardFull()
{
   if(!ShowDashboard)
      return;

   SetDashboardLine(0, "HORSE EA - PROP CHALLENGE EDITION");
   SetDashboardLine(1, "Stage: 12 - REENTRY / LAYER ENGINE");
   SetDashboardLine(2, "Symbol: " + _Symbol);
   SetDashboardLine(3, "Timeframe: " + TimeframeToText((ENUM_TIMEFRAMES)_Period));
   SetDashboardLine(4, "Magic: " + IntegerToString((int)MagicNumber));
   SetDashboardLine(5, "EA Status: " + g_eaStatus);
   SetDashboardLine(6, "Diagnostic Mode: " + BoolToText(UseDiagnosticMode));
   SetDashboardLine(7, "Live Trading Allowed: " + BoolToText(g_liveTradingAllowed));
   SetDashboardLine(8, "Symbol OK: " + BoolToText(g_symbolOK));
   SetDashboardLine(9, "Timeframe OK: " + BoolToText(g_timeframeOK));
   SetDashboardLine(10, "Environment OK: " + BoolToText(g_environmentOK));
   SetDashboardLine(11, "Terminal Connected: " + BoolToText(g_terminalConnected));
   SetDashboardLine(12, "MQL Trade Allowed: " + BoolToText(g_mqlTradeAllowed));
   SetDashboardLine(13, "Account Trade Allowed: " + BoolToText(g_accountTradeAllowed));
   SetDashboardLine(14, "Price Feed OK: " + BoolToText(g_priceFeedOK));
   SetDashboardLine(15, "Security Filters OK: " + BoolToText(g_securityFiltersOK));
   SetDashboardLine(16, "Security Reason: " + g_securityFilterReason);
   SetDashboardLine(17, "Spread: " + IntegerToString(g_currentSpreadPoints));
   SetDashboardLine(18, "Max Spread: " + IntegerToString(MaxSpreadPoints));
   SetDashboardLine(19, "Spread Status: " + g_spreadStatus);
   SetDashboardLine(20, "Session OK: " + BoolToText(g_sessionOK));
   SetDashboardLine(21, "Session Status: " + g_sessionStatus);
   SetDashboardLine(22, "Cooldown OK: " + BoolToText(g_cooldownOK));
   SetDashboardLine(23, "Cooldown Status: " + g_cooldownStatus);
   SetDashboardLine(24, "Price Data OK: " + BoolToText(g_priceOK));
   SetDashboardLine(25, "Price Status: " + g_priceStatus);
   SetDashboardLine(26, "Margin Diagnostic OK: " + BoolToText(g_marginOK));
   SetDashboardLine(27, "Margin Status: " + g_marginStatus);
   SetDashboardLine(28, "Account Safety OK: " + BoolToText(g_accountSafetyOK));
   SetDashboardLine(29, "Account Safety Status: " + g_accountSafetyStatus);
   SetDashboardLine(30, "ATR M1: " + DoubleToString(g_atrM1Points, 1));
   SetDashboardLine(31, "ATR M5: " + DoubleToString(g_atrM5Points, 1));
   SetDashboardLine(32, "Current Candle Range: " + DoubleToString(g_currentCandleRangePoints, 1));
   SetDashboardLine(33, "Average Range: " + DoubleToString(g_averageRangePoints, 1));
   SetDashboardLine(34, "Candle Body: " + DoubleToString(g_currentCandleBodyPoints, 1));
   SetDashboardLine(35, "Upper Wick: " + DoubleToString(g_upperWickPoints, 1));
   SetDashboardLine(36, "Lower Wick: " + DoubleToString(g_lowerWickPoints, 1));
   SetDashboardLine(37, "Body Ratio: " + DoubleToString(g_bodyRatio, 2));
   SetDashboardLine(38, "Upper Wick Ratio: " + DoubleToString(g_upperWickRatio, 2));
   SetDashboardLine(39, "Lower Wick Ratio: " + DoubleToString(g_lowerWickRatio, 2));
   SetDashboardLine(40, "Volatility Status: " + g_volatilityStatus);
   SetDashboardLine(41, "Market Mode: " + g_marketModeStatus);
   SetDashboardLine(42, "Market Strength: " + g_marketStrengthStatus);
   SetDashboardLine(43, "Market Tradable: " + BoolToText(g_market.isTradable));
   SetDashboardLine(44, "Market Reason: " + g_marketDiagnosticReason);
   SetDashboardLine(45, "Flow Engine OK: " + BoolToText(g_flowOK));
   SetDashboardLine(46, "Flow Status: " + g_flowStatus);
   SetDashboardLine(47, "Flow Reason: " + g_flowReason);
   SetDashboardLine(48, "Flow Direction: " + g_flowDirectionText);
   SetDashboardLine(49, "BUY Strength: " + DoubleToString(g_buyStrengthScore, 1));
   SetDashboardLine(50, "SELL Strength: " + DoubleToString(g_sellStrengthScore, 1));
   SetDashboardLine(51, "Momentum Score: " + DoubleToString(g_momentumScore, 1));
   SetDashboardLine(52, "Acceleration Score: " + DoubleToString(g_accelerationScore, 1));
   SetDashboardLine(53, "Rejection Score: " + DoubleToString(g_rejectionScore, 1));
   SetDashboardLine(54, "BUY Rejection: " + DoubleToString(g_buyRejectionScore, 1));
   SetDashboardLine(55, "SELL Rejection: " + DoubleToString(g_sellRejectionScore, 1));
   SetDashboardLine(56, "Imbalance Score: " + DoubleToString(g_imbalanceScore, 1));
   SetDashboardLine(57, "BUY Imbalance: " + DoubleToString(g_buyImbalanceScore, 1));
   SetDashboardLine(58, "SELL Imbalance: " + DoubleToString(g_sellImbalanceScore, 1));
   SetDashboardLine(59, "Flow Danger Score: " + DoubleToString(g_flowDangerScore, 1));
   SetDashboardLine(60, "Flow Quality Score: " + DoubleToString(g_flowQualityScore, 1));
   SetDashboardLine(61, "BUY Dominant: " + BoolToText(g_buyFlowDominant));
   SetDashboardLine(62, "SELL Dominant: " + BoolToText(g_sellFlowDominant));
   SetDashboardLine(63, "Flow Balanced: " + BoolToText(g_flowBalanced));
   SetDashboardLine(64, "Flow Dangerous: " + BoolToText(g_flowDangerous));
   SetDashboardLine(65, "Entry Base OK: " + BoolToText(g_entryBaseOK));
   SetDashboardLine(66, "Entry Base Status: " + g_entryBaseStatus);
   SetDashboardLine(67, "Entry Base Reason: " + g_entryBaseReason);
   SetDashboardLine(68, "Entry Base Direction: " + EntryDirectionToText());
   SetDashboardLine(69, "Entry Base Score: " + DoubleToString(g_entryBaseScore, 2));
   SetDashboardLine(70, "BUY Entry Score: " + DoubleToString(g_buyEntryBaseScore, 2));
   SetDashboardLine(71, "SELL Entry Score: " + DoubleToString(g_sellEntryBaseScore, 2));
   SetDashboardLine(72, "Security Component: " + DoubleToString(g_securityComponentScore, 1));
   SetDashboardLine(73, "Volatility Component: " + DoubleToString(g_volatilityComponentScore, 1));
   SetDashboardLine(74, "Market Mode Component: " + DoubleToString(g_marketModeComponentScore, 1));
   SetDashboardLine(75, "Market Strength Component: " + DoubleToString(g_marketStrengthComponentScore, 1));
   SetDashboardLine(76, "Flow Quality Component: " + DoubleToString(g_flowQualityComponentScore, 1));
   SetDashboardLine(77, "BUY Directional Component: " + DoubleToString(g_buyDirectionalComponentScore, 1));
   SetDashboardLine(78, "SELL Directional Component: " + DoubleToString(g_sellDirectionalComponentScore, 1));
   SetDashboardLine(79, "Momentum Component: " + DoubleToString(g_momentumComponentScore, 1));
   SetDashboardLine(80, "BUY Rejection Component: " + DoubleToString(g_buyRejectionComponentScore, 1));
   SetDashboardLine(81, "SELL Rejection Component: " + DoubleToString(g_sellRejectionComponentScore, 1));
   SetDashboardLine(82, "BUY Imbalance Component: " + DoubleToString(g_buyImbalanceComponentScore, 1));
   SetDashboardLine(83, "SELL Imbalance Component: " + DoubleToString(g_sellImbalanceComponentScore, 1));
   SetDashboardLine(84, "Total Penalty: " + DoubleToString(g_totalEntryPenalty, 1));
   SetDashboardLine(85, "BUY Candidate: " + BoolToText(g_buyEntryCandidate));
   SetDashboardLine(86, "SELL Candidate: " + BoolToText(g_sellEntryCandidate));
   SetDashboardLine(87, "Entry Strong: " + BoolToText(g_entryScoreStrong));
   SetDashboardLine(88, "Entry Excellent: " + BoolToText(g_entryScoreExcellent));
   SetDashboardLine(89, "Diagnostic Only: " + BoolToText(EntryBaseDiagnosticOnly));
   SetDashboardLine(90, "Entry Decision OK: " + BoolToText(g_entryDecisionOK));
   SetDashboardLine(91, "Entry Decision Status: " + g_entryDecisionStatus);
   SetDashboardLine(92, "Entry Decision Reason: " + g_entryDecisionReason);
   SetDashboardLine(93, "Entry Decision Direction: " + g_entryDecisionDirection);
   SetDashboardLine(94, "Entry Decision Text: " + g_entryDecisionText);
   SetDashboardLine(95, "Entry Decision Score: " + DoubleToString(g_entryDecisionScore, 2));
   SetDashboardLine(96, "BUY Decision Score: " + DoubleToString(g_buyDecisionScore, 2));
   SetDashboardLine(97, "SELL Decision Score: " + DoubleToString(g_sellDecisionScore, 2));
   SetDashboardLine(98, "Decision Difference: " + DoubleToString(g_decisionScoreDifference, 2));
   SetDashboardLine(99, "BUY Decision Candidate: " + BoolToText(g_buyDecisionCandidate));
   SetDashboardLine(100, "SELL Decision Candidate: " + BoolToText(g_sellDecisionCandidate));
   SetDashboardLine(101, "Decision Strong: " + BoolToText(g_entryDecisionStrong));
   SetDashboardLine(102, "Decision Excellent: " + BoolToText(g_entryDecisionExcellent));
   SetDashboardLine(103, "Decision Conflict: " + BoolToText(g_entryDecisionConflict));
   SetDashboardLine(104, "Decision Blocked: " + BoolToText(g_entryDecisionBlocked));
   SetDashboardLine(105, "Decision Diagnostic Only: " + BoolToText(EntryDecisionDiagnosticOnly));
   SetDashboardLine(106, "Virtual Entry Active: " + BoolToText(g_virtualEntryActive));
   SetDashboardLine(107, "Virtual Entry Completed: " + BoolToText(g_virtualEntryCompleted));
   SetDashboardLine(108, "Virtual Entry State: " + VirtualEntryStateToText(g_virtualEntry.state));
   SetDashboardLine(109, "Virtual Entry Direction: " + g_virtualEntryDirectionText);
   SetDashboardLine(110, "Virtual Entry Status: " + g_virtualEntryStatus);
   SetDashboardLine(111, "Virtual Entry Reason: " + g_virtualEntryReason);
   SetDashboardLine(112, "Virtual Entry Price: " + DoubleToString(g_virtualEntry.entryPrice, _Digits));
   SetDashboardLine(113, "Virtual Current Price: " + DoubleToString(g_virtualEntry.currentPrice, _Digits));
   SetDashboardLine(114, "Virtual SL: " + DoubleToString(g_virtualEntry.stopLossPrice, _Digits));
   SetDashboardLine(115, "Virtual TP: " + DoubleToString(g_virtualEntry.takeProfitPrice, _Digits));
   SetDashboardLine(116, "Virtual Risk Points: " + DoubleToString(g_virtualEntry.virtualRiskPoints, 1));
   SetDashboardLine(117, "Virtual Reward Points: " + DoubleToString(g_virtualEntry.virtualRewardPoints, 1));
   SetDashboardLine(118, "Virtual RR: " + DoubleToString(g_virtualEntry.virtualRR, 2));
   SetDashboardLine(119, "Virtual Profit Points: " + DoubleToString(g_virtualEntry.currentProfitPoints, 1));
   SetDashboardLine(120, "Virtual Profit Money: " + DoubleToString(g_virtualEntry.currentProfitMoney, 2));
   SetDashboardLine(121, "Virtual Max Favorable: " + DoubleToString(g_virtualEntry.maxFavorablePoints, 1));
   SetDashboardLine(122, "Virtual Max Adverse: " + DoubleToString(g_virtualEntry.maxAdversePoints, 1));
   SetDashboardLine(123, "Virtual Result Score: " + DoubleToString(g_virtualEntryResultScore, 1));
   SetDashboardLine(124, "Virtual Age Seconds: " + IntegerToString(g_virtualEntry.ageSeconds));
   SetDashboardLine(125, "Virtual Age Bars: " + IntegerToString(g_virtualEntry.ageBars));
   SetDashboardLine(126, "Virtual Wins: " + IntegerToString(g_virtualWins));
   SetDashboardLine(127, "Virtual Losses: " + IntegerToString(g_virtualLosses));
   SetDashboardLine(128, "Virtual Timeouts: " + IntegerToString(g_virtualTimeouts));
   SetDashboardLine(129, "Virtual Invalidations: " + IntegerToString(g_virtualInvalidations));
   SetDashboardLine(130, "Virtual Cancellations: " + IntegerToString(g_virtualCancellations));
   SetDashboardLine(131, "Virtual Total Simulations: " + IntegerToString(g_virtualTotalSimulations));
   SetDashboardLine(132, "Last Virtual Start Candle: " + (g_lastVirtualEntryStartBarTime > 0 ? TimeToString(g_lastVirtualEntryStartBarTime, TIME_DATE | TIME_MINUTES) : "NONE"));
   SetDashboardLine(133, "Virtual Diagnostic Only: " + BoolToText(VirtualEntryDiagnosticOnly));
   SetDashboardLine(134, "Daily Start Equity: " + DoubleToString(g_risk.dailyStartEquity, 2));
   SetDashboardLine(135, "Daily High Equity: " + DoubleToString(g_risk.dailyHighEquity, 2));
   SetDashboardLine(136, "Daily DD %: " + DoubleToString(g_risk.dailyDrawdownPercent, 2));
   SetDashboardLine(137, "Protection Mode: " + ProtectionModeToText(g_risk.protectionMode));
   SetDashboardLine(138, "Last Action: " + g_lastAction);
   SetDashboardLine(139, "Last Block: " + g_lastBlockReason);
   SetDashboardLine(140, "Last Block Time: " + (g_lastBlockTime > 0 ? TimeToString(g_lastBlockTime, TIME_DATE | TIME_SECONDS) : "NONE"));
   SetDashboardLine(141, "Last Action Time: " + (g_lastActionTime > 0 ? TimeToString(g_lastActionTime, TIME_DATE | TIME_SECONDS) : "NONE"));
   SetDashboardLine(142, "Server Time: " + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS));
   SetDashboardLine(143, "UseATRVolatilityEngine: " + BoolToText(UseATRVolatilityEngine));
   SetDashboardLine(144, "UseMarketClassification: " + BoolToText(UseMarketClassification));
   SetDashboardLine(145, "UseFlowEngine: " + BoolToText(UseFlowEngine));
   SetDashboardLine(146, "UseEntryBaseScoreEngine: " + BoolToText(UseEntryBaseScoreEngine));
   SetDashboardLine(147, "UseEntryDecisionEngine: " + BoolToText(UseEntryDecisionEngine));
   SetDashboardLine(148, "UseVirtualEntrySimulation: " + BoolToText(UseVirtualEntrySimulation));
   SetDashboardLine(149, "StrictFlowFilter: " + BoolToText(StrictFlowFilter));
   SetDashboardLine(150, "BlockBalancedFlow: " + BoolToText(BlockBalancedFlow));
   SetDashboardLine(151, "Closed Candle Market: " + BoolToText(UseClosedCandleForMarketAnalysis));
   SetDashboardLine(152, "Closed Candle Flow: " + BoolToText(UseClosedCandleForFlowAnalysis));
   SetDashboardLine(153, "Prevent Same Candle Virtual: " + BoolToText(PreventMultipleVirtualEntriesSameCandle));
   SetDashboardLine(154, "Max Positions/Basket: " + IntegerToString(MaxPositionsPerBasket));
   SetDashboardLine(155, "Max Loss/Trade: " + DoubleToString(MaxLossPerTradeMoney, 2));
   SetDashboardLine(156, "Daily Loss Limit %: " + DoubleToString(DailyLossLimitPercent, 2));
   SetDashboardLine(157, "Score Despite Blocks: ENABLED");
   SetDashboardLine(158, "Decision Despite Blocks: ENABLED");
   SetDashboardLine(159, "Virtual Despite Blocks: ENABLED");
   SetDashboardLine(160, "No Trade Dependency: TRUE");
   SetDashboardLine(161, "No Position Dependency: TRUE");
   SetDashboardLine(162, "No History Dependency: TRUE");
   SetDashboardLine(163, "No Real Orders: TRUE");
   SetDashboardLine(164, "NO TRADING IN STAGE 09");
   SetDashboardLine(165, "Total trades expected: 0");
   SetDashboardLine(166, "Next: STAGE 12 REENTRY / LAYER ENGINE");
   SetDashboardLine(167, "Virtual Price Validation: TRUE");
   SetDashboardLine(168, "Virtual Same Candle Guard: TRUE");
   SetDashboardLine(169, "Virtual Engine Disabled Reset: TRUE");
   SetDashboardLine(170, "CanStartPreExecutionRiskGate Single: TRUE");
   SetDashboardLine(171, "Stage 09 Ready: TRUE");
   SetDashboardLine(172, "Pre Execution Approved: " + BoolToText(g_preExecutionApproved));
   SetDashboardLine(173, "Pre Execution Blocked: " + BoolToText(g_preExecutionBlocked));
   SetDashboardLine(174, "Pre Execution Waiting: " + BoolToText(g_preExecutionWaiting));
   SetDashboardLine(175, "Pre Execution Risk Danger: " + BoolToText(g_preExecutionRiskDanger));
   SetDashboardLine(176, "Pre Execution State: " + PreExecutionStateToText(g_preExecution.state));
   SetDashboardLine(177, "Pre Execution Status: " + g_preExecutionStatus);
   SetDashboardLine(178, "Pre Execution Reason: " + g_preExecutionReason);
   SetDashboardLine(179, "Pre Execution Block Reason: " + g_preExecutionBlockReason);
   SetDashboardLine(180, "Pre Execution Direction: " + g_preExecutionDirection);
   SetDashboardLine(181, "Pre Execution Score: " + DoubleToString(g_preExecutionScore, 2));
   SetDashboardLine(182, "Risk Score: " + DoubleToString(g_preExecutionRiskScore, 2));
   SetDashboardLine(183, "Virtual Confirmation Score: " + DoubleToString(g_preExecutionVirtualScore, 2));
   SetDashboardLine(184, "Account Safety Score: " + DoubleToString(g_preExecutionAccountScore, 2));
   SetDashboardLine(185, "Trade Cost Score: " + DoubleToString(g_preExecutionCostScore, 2));
   SetDashboardLine(186, "RR Score: " + DoubleToString(g_preExecutionRRScore, 2));
   SetDashboardLine(187, "Daily Risk Score: " + DoubleToString(g_preExecutionDailyRiskScore, 2));
   SetDashboardLine(188, "Estimated Lot: " + DoubleToString(g_estimatedExecutionLot, 2));
   SetDashboardLine(189, "Estimated Risk Money: " + DoubleToString(g_estimatedRiskMoney, 2));
   SetDashboardLine(190, "Estimated Reward Money: " + DoubleToString(g_estimatedRewardMoney, 2));
   SetDashboardLine(191, "Estimated Risk Percent: " + DoubleToString(g_estimatedRiskPercent, 3));
   SetDashboardLine(192, "Estimated Spread Cost: " + DoubleToString(g_estimatedSpreadCostMoney, 2));
   SetDashboardLine(193, "Estimated Commission: " + DoubleToString(g_estimatedCommissionBufferMoney, 2));
   SetDashboardLine(194, "Account Balance: " + DoubleToString(g_preExecution.accountBalance, 2));
   SetDashboardLine(195, "Account Equity: " + DoubleToString(g_preExecution.accountEquity, 2));
   SetDashboardLine(196, "Account Free Margin: " + DoubleToString(g_preExecution.accountFreeMargin, 2));
   SetDashboardLine(197, "Account Margin Level: " + DoubleToString(g_preExecution.accountMarginLevel, 2));
   SetDashboardLine(198, "Pre Execution Diagnostic Only: " + BoolToText(PreExecutionDiagnosticOnly));
   SetDashboardLine(199, "CanStartExecutionDryRun Single: TRUE");
   SetDashboardLine(200, "Dry Run Approved: " + BoolToText(g_dryRunApproved));
   SetDashboardLine(201, "Dry Run Blocked: " + BoolToText(g_dryRunBlocked));
   SetDashboardLine(202, "Dry Run Waiting: " + BoolToText(g_dryRunWaiting));
   SetDashboardLine(203, "Dry Run Buy Ready: " + BoolToText(g_dryRunBuyReady));
   SetDashboardLine(204, "Dry Run Sell Ready: " + BoolToText(g_dryRunSellReady));
   SetDashboardLine(205, "Dry Run Risk Block: " + BoolToText(g_dryRunRiskBlock));
   SetDashboardLine(206, "Dry Run Duplicate Block: " + BoolToText(g_dryRunDuplicateBlock));
   SetDashboardLine(207, "Dry Run State: " + ExecutionDryRunStateToText(g_executionDryRun.state));
   SetDashboardLine(208, "Dry Run Status: " + g_dryRunStatus);
   SetDashboardLine(209, "Dry Run Reason: " + g_dryRunReason);
   SetDashboardLine(210, "Dry Run Block Reason: " + g_dryRunBlockReason);
   SetDashboardLine(211, "Dry Run Direction: " + g_dryRunDirectionText);
   SetDashboardLine(212, "Dry Run Score: " + DoubleToString(g_dryRunScore, 2));
   SetDashboardLine(213, "Permission Score: " + DoubleToString(g_dryRunPermissionScore, 2));
   SetDashboardLine(214, "Direction Score: " + DoubleToString(g_dryRunDirectionScore, 2));
   SetDashboardLine(215, "Risk Permission Score: " + DoubleToString(g_dryRunRiskPermissionScore, 2));
   SetDashboardLine(216, "Duplicate Safety Score: " + DoubleToString(g_dryRunDuplicateSafetyScore, 2));
   SetDashboardLine(217, "Execution Cost Score: " + DoubleToString(g_dryRunExecutionCostScore, 2));
   SetDashboardLine(218, "Planned Order Type: " + g_executionDryRun.plannedOrderType);
   SetDashboardLine(219, "Planned Lot: " + DoubleToString(g_plannedExecutionLot, 2));
   SetDashboardLine(220, "Planned Entry Price: " + DoubleToString(g_plannedExecutionEntryPrice, _Digits));
   SetDashboardLine(221, "Planned SL: " + DoubleToString(g_plannedExecutionSL, _Digits));
   SetDashboardLine(222, "Planned TP: " + DoubleToString(g_plannedExecutionTP, _Digits));
   SetDashboardLine(223, "Planned Risk Money: " + DoubleToString(g_plannedExecutionRiskMoney, 2));
   SetDashboardLine(224, "Planned Reward Money: " + DoubleToString(g_plannedExecutionRewardMoney, 2));
   SetDashboardLine(225, "Planned Risk Percent: " + DoubleToString(g_plannedExecutionRiskPercent, 3));
   SetDashboardLine(226, "Planned RR: " + DoubleToString(g_executionDryRun.plannedRR, 2));
   SetDashboardLine(227, "Planned Spread Cost: " + DoubleToString(g_executionDryRun.plannedSpreadCostMoney, 2));
   SetDashboardLine(228, "Planned Commission: " + DoubleToString(g_executionDryRun.plannedCommissionMoney, 2));
   SetDashboardLine(229, "Last Dry Run Approval Time: " + (g_lastDryRunApprovalTime > 0 ? TimeToString(g_lastDryRunApprovalTime, TIME_DATE | TIME_SECONDS) : "NONE"));
   SetDashboardLine(230, "Last Dry Run Approval Candle: " + (g_lastDryRunApprovalBarTime > 0 ? TimeToString(g_lastDryRunApprovalBarTime, TIME_DATE | TIME_MINUTES) : "NONE"));
   SetDashboardLine(231, "Execution Dry Run Diagnostic Only: " + BoolToText(ExecutionDryRunDiagnosticOnly));
   SetDashboardLine(232, "UseExecutionDryRun: " + BoolToText(UseExecutionDryRun));
   SetDashboardLine(233, "CanStartRealExecution Single: TRUE");
   SetDashboardLine(234, "No Real Orders Stage09: TRUE");
   SetDashboardLine(235, "Total trades expected: 0");
   SetDashboardLine(236, "Next: STAGE 12 REENTRY / LAYER ENGINE");
}



//+------------------------------------------------------------------+
//| HORSE EA V4 - Aggressive Result Engine Final                |
//+------------------------------------------------------------------+
void AuditV4(string message)
{
   if(UseV4AuditMode)
      AuditLog("V4", message);
}

bool V4Contains(string source, string token)
{
   string s = source;
   string t = token;
   StringToUpper(s);
   StringToUpper(t);
   return (StringFind(s, t) >= 0);
}

string V4OrderTypeToText(ENUM_ORDER_TYPE direction)
{
   if(direction == ORDER_TYPE_BUY) return "BUY";
   if(direction == ORDER_TYPE_SELL) return "SELL";
   return "NONE";
}

string V4PositionTypeToText(ENUM_POSITION_TYPE direction)
{
   if(direction == POSITION_TYPE_BUY) return "BUY";
   if(direction == POSITION_TYPE_SELL) return "SELL";
   return "NONE";
}

ENUM_ORDER_TYPE V4RealDirectionToOrderType(ENUM_REAL_EXECUTION_DIRECTION direction)
{
   if(direction == REAL_EXEC_DIR_BUY) return ORDER_TYPE_BUY;
   if(direction == REAL_EXEC_DIR_SELL) return ORDER_TYPE_SELL;
   return (ENUM_ORDER_TYPE)-1;
}

ENUM_POSITION_TYPE V4OrderToPositionType(ENUM_ORDER_TYPE direction)
{
   if(direction == ORDER_TYPE_BUY) return POSITION_TYPE_BUY;
   if(direction == ORDER_TYPE_SELL) return POSITION_TYPE_SELL;
   return (ENUM_POSITION_TYPE)-1;
}

int V4CountMagicPositions()
{
   return CountAllMagicPositions();
}

double V4Clamp(double value, double minValue, double maxValue)
{
   if(value < minValue) return minValue;
   if(value > maxValue) return maxValue;
   return value;
}

double GetTickValueSafeV4()
{
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickValue <= 0.0)
      tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_PROFIT);
   if(tickValue <= 0.0)
      tickValue = 1.0;
   return tickValue;
}

double GetPointValueSafeV4()
{
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0.0 || _Point <= 0.0)
      return GetTickValueSafeV4();
   return GetTickValueSafeV4() * (_Point / tickSize);
}

double PointsToMoneyV4(double points, double lot)
{
   if(points < 0.0) points = -points;
   if(lot < 0.0) lot = -lot;
   double money = points * GetPointValueSafeV4() * lot;
   AuditV4("[V4_RISK] MONEY_POINTS_CONVERSION points=" + DoubleToString(points,1) + " lot=" + DoubleToString(lot,2) + " money=" + DoubleToString(money,2));
   return money;
}

double MoneyToPointsV4(double money, double lot)
{
   double pv = GetPointValueSafeV4();
   if(pv <= 0.0 || lot <= 0.0) return 0.0;
   if(money < 0.0) money = -money;
   double points = money / (pv * lot);
   AuditV4("[V4_RISK] MONEY_POINTS_CONVERSION money=" + DoubleToString(money,2) + " lot=" + DoubleToString(lot,2) + " points=" + DoubleToString(points,1));
   return points;
}

double NormalizeLotV4(double lot)
{
   double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(minVol <= 0.0) minVol = 0.01;
   if(maxVol <= 0.0) maxVol = 100.0;
   if(step <= 0.0) step = 0.01;
   if(lot < minVol) lot = minVol;
   if(lot > maxVol) lot = maxVol;
   lot = MathFloor(lot / step) * step;
   if(lot < minVol) lot = minVol;
   lot = NormalizeDouble(lot, 2);
   AuditV4("[V4_RISK] LOT_NORMALIZED lot=" + DoubleToString(lot,2));
   return lot;
}

string NormalizeLegacyReasonV4(string reason)
{
   string r = reason;
   StringToUpper(r);
   StringReplace(r, " ", "_");
   StringReplace(r, "-", "_");
   StringReplace(r, ":", "_");
   StringReplace(r, "[", "");
   StringReplace(r, "]", "");
   StringReplace(r, "__", "_");

   if(r == "" || r == "NONE" || r == "NO_LEGACY_BLOCK")
      return "NONE";

   if(V4Contains(r, "CHOPPY") || V4Contains(r, "OLD_CHOPPY_BLOCK") || V4Contains(r, "REGIME_CHOPPY") || V4Contains(r, "MARKET_CHOPPY"))
      return "CHOPPY_MARKET";
   if(V4Contains(r, "BIAS_EXTREME") || V4Contains(r, "BIASEXTREME") || V4Contains(r, "OLD_BIAS_BLOCK") || V4Contains(r, "V3_2_BIAS"))
      return "BIAS_EXTREME";
   if(V4Contains(r, "BIAS_MODERATE") || V4Contains(r, "BIAS MODERATE"))
      return "BIAS_MODERATE";
   if(V4Contains(r, "LOSS_STREAK") || V4Contains(r, "LOSSSTREAK") || V4Contains(r, "V3_2_ANTI_OVERTRADE_LOSS"))
      return "LOSS_STREAK_PAUSE_ACTIVE";
   if(V4Contains(r, "AGAINST_MTF_TREND") || V4Contains(r, "MTF_TREND_AGAINST") || V4Contains(r, "TREND_FILTER_AGAINST") || V4Contains(r, "TREND_AGAINST"))
      return "MTF_TREND_AGAINST";
   if(V4Contains(r, "OLD_MARKET_REGIME_BLOCK") || V4Contains(r, "V3_2_REGIME_BLOCK") || V4Contains(r, "REGIME_BLOCK"))
      return "REGIME_BLOCK";
   if(V4Contains(r, "RANGE_COMPRESSED"))
      return "RANGE_COMPRESSED_MODERATE";
   if(V4Contains(r, "RANGE_LOW"))
      return "RANGE_LOW";
   if(V4Contains(r, "LOW_VOLATILITY"))
      return "LOW_VOLATILITY_MODERATE";
   if(V4Contains(r, "CANDLE_WEAK"))
      return "CANDLE_WEAK";
   if(V4Contains(r, "SIGNAL_WEAK"))
      return "SIGNAL_WEAK";
   if(V4Contains(r, "TREND_PARTIAL"))
      return "TREND_PARTIAL_AGAINST";
   if(V4Contains(r, "ANTI_OVERTRADE") && (V4Contains(r, "MAX") || V4Contains(r, "DUPLICATE") || V4Contains(r, "SAME_CANDLE") || V4Contains(r, "ATTEMPTS") || V4Contains(r, "REQUEST")))
      return "ANTI_OVERTRADE_OBJECTIVE";
   if(V4Contains(r, "ANTI_OVERTRADE") || V4Contains(r, "TOO_MANY_TRADES") || V4Contains(r, "COOLDOWN"))
      return "ANTI_OVERTRADE_MARKET_WEAK";

   if(V4Contains(r, "DAILY_LOSS")) return "DAILY_LOSS_LIMIT";
   if(V4Contains(r, "DAILY_DRAWDOWN") || V4Contains(r, "DRAWDOWN")) return "DAILY_DRAWDOWN_LIMIT";
   if(V4Contains(r, "MAX_DAILY_RISK")) return "MAX_DAILY_RISK";
   if(V4Contains(r, "EQUITY_PROTECTION")) return "EQUITY_PROTECTION";
   if(V4Contains(r, "BASKET_EMERGENCY") || V4Contains(r, "EMERGENCY_SL")) return "BASKET_EMERGENCY_SL";
   if(V4Contains(r, "MARGIN_INSUFFICIENT") || V4Contains(r, "INSUFFICIENT_FREE_MARGIN") || V4Contains(r, "INSUFFICIENT FREE MARGIN")) return "MARGIN_INSUFFICIENT";
   if(V4Contains(r, "FREE_MARGIN_LOW")) return "FREE_MARGIN_LOW";
   if(V4Contains(r, "SPREAD_EXTREME") || V4Contains(r, "EXTREME_SPREAD") || V4Contains(r, "REAL_EXECUTION_SPREAD_TOO_HIGH")) return "SPREAD_EXTREME";
   if(V4Contains(r, "STOP_LEVEL") || V4Contains(r, "STOPLEVEL") || V4Contains(r, "STOPS_TOO_CLOSE") || V4Contains(r, "STOPS_INVALID")) return "STOP_LEVEL_INVALID";
   if(V4Contains(r, "FREEZE")) return "FREEZE_LEVEL_INVALID";
   if(V4Contains(r, "TERMINAL_TRADE_DISABLED") || V4Contains(r, "MQL_TRADE_DISABLED")) return "TERMINAL_TRADE_DISABLED";
   if(V4Contains(r, "SYMBOL_TRADE_DISABLED") || V4Contains(r, "TRADE_DISABLED")) return "SYMBOL_TRADE_DISABLED";
   if(V4Contains(r, "MARKET_CLOSED")) return "MARKET_CLOSED";
   if(V4Contains(r, "MAX_TOTAL_POSITIONS") || V4Contains(r, "MAX_POSITIONS") || V4Contains(r, "MAX TOTAL POSITIONS")) return "MAX_POSITIONS_REACHED";
   if(V4Contains(r, "OPPOSITE_POSITION")) return "OPPOSITE_POSITION_DETECTED";
   if(V4Contains(r, "HEDGE")) return "HEDGE_DETECTED";
   if(V4Contains(r, "INVALID_VOLUME") || V4Contains(r, "INVALID_LOT")) return "INVALID_VOLUME";
   if(V4Contains(r, "LOT_OUT") || V4Contains(r, "LOT OUT") || V4Contains(r, "LOT_NOT_ALIGNED") || V4Contains(r, "LOT OUT OF")) return "LOT_OUT_OF_LIMITS";
   if(V4Contains(r, "ORDER_SEND_FATAL") || V4Contains(r, "REAL_EXECUTION_ERROR")) return "ORDER_SEND_FATAL_ERROR";
   if(V4Contains(r, "NEWS")) return "NEWS_HIGH_IMPACT_BLOCK";

   return r;
}

ENUM_V4_FILTER_ACTION ClassifyFilterV4(string reason)
{
   string r = NormalizeLegacyReasonV4(reason);
   ENUM_V4_FILTER_ACTION action = FILTER_REMOVE_FROM_FLOW;

   if(r == "DAILY_LOSS_LIMIT" || r == "DAILY_DRAWDOWN_LIMIT" || r == "MAX_DAILY_RISK" ||
      r == "EQUITY_PROTECTION" || r == "BASKET_EMERGENCY_SL" || r == "MARGIN_INSUFFICIENT" ||
      r == "FREE_MARGIN_LOW" || r == "SPREAD_EXTREME" || r == "STOP_LEVEL_INVALID" ||
      r == "FREEZE_LEVEL_INVALID" || r == "TERMINAL_TRADE_DISABLED" || r == "SYMBOL_TRADE_DISABLED" ||
      r == "MARKET_CLOSED" || r == "MAX_POSITIONS_REACHED" || r == "OPPOSITE_POSITION_DETECTED" ||
      r == "HEDGE_DETECTED" || r == "INVALID_VOLUME" || r == "LOT_OUT_OF_LIMITS" ||
      r == "ORDER_SEND_FATAL_ERROR" || r == "ANTI_OVERTRADE_OBJECTIVE" ||
      (r == "NEWS_HIGH_IMPACT_BLOCK" && UseNewsFilter))
      action = FILTER_KEEP_ABSOLUTE_BLOCK;
   else if(r == "CHOPPY_MARKET" || r == "BIAS_EXTREME" || r == "BIAS_MODERATE" ||
           r == "LOSS_STREAK_PAUSE_ACTIVE" || r == "MTF_TREND_AGAINST" || r == "AGAINST_MTF_TREND" ||
           r == "ANTI_OVERTRADE_MARKET_WEAK" || r == "REGIME_BLOCK" ||
           r == "RANGE_COMPRESSED_MODERATE" || r == "RANGE_LOW" || r == "TREND_PARTIAL_AGAINST" ||
           r == "LOW_VOLATILITY_MODERATE" || r == "CANDLE_WEAK" || r == "SIGNAL_WEAK")
      action = FILTER_CONVERT_TO_SCORE;
   else if(V4Contains(r, "SMART_EXIT") || V4Contains(r, "RUNNER") || V4Contains(r, "GIVEBACK"))
      action = FILTER_EXIT_ONLY;
   else if(V4Contains(r, "V3_2") || V4Contains(r, "OLD_"))
      action = FILTER_REMOVE_FROM_FLOW;

   AuditV4("[V4_FILTER_MATRIX] reason=" + r + " action=" + (action == FILTER_KEEP_ABSOLUTE_BLOCK ? "FILTER_KEEP_ABSOLUTE_BLOCK" : action == FILTER_CONVERT_TO_SCORE ? "FILTER_CONVERT_TO_SCORE" : action == FILTER_EXIT_ONLY ? "FILTER_EXIT_ONLY" : "FILTER_REMOVE_FROM_FLOW"));
   return action;
}

bool IsAbsoluteRiskBlockV4(string legacyReason)
{
   string r = NormalizeLegacyReasonV4(legacyReason);
   if(r == "NEWS_HIGH_IMPACT_BLOCK" && !UseNewsFilter)
   {
      AuditV4("[V4_NEWS] NEWS_FILTER_DISABLED_NO_BLOCK");
      return false;
   }
   if(r == "DAILY_LOSS_LIMIT" || r == "DAILY_DRAWDOWN_LIMIT" || r == "MAX_DAILY_RISK" ||
      r == "EQUITY_PROTECTION" || r == "BASKET_EMERGENCY_SL" || r == "MARGIN_INSUFFICIENT" ||
      r == "FREE_MARGIN_LOW" || r == "SPREAD_EXTREME" || r == "STOP_LEVEL_INVALID" ||
      r == "FREEZE_LEVEL_INVALID" || r == "TERMINAL_TRADE_DISABLED" || r == "SYMBOL_TRADE_DISABLED" ||
      r == "MARKET_CLOSED" || r == "MAX_POSITIONS_REACHED" || r == "OPPOSITE_POSITION_DETECTED" ||
      r == "HEDGE_DETECTED" || r == "INVALID_VOLUME" || r == "LOT_OUT_OF_LIMITS" ||
      r == "ORDER_SEND_FATAL_ERROR" || r == "ANTI_OVERTRADE_OBJECTIVE" ||
      (r == "NEWS_HIGH_IMPACT_BLOCK" && UseNewsFilter))
      return true;

   if(g_risk.tradingLocked) return true;
   if(!g_symbolOK || !g_timeframeOK || !g_environmentOK) return true;
   if(V4CountMagicPositions() >= MaxPositionsV4) return true;
   return false;
}

bool ShouldConvertLegacyBlockToScoreV4(string legacyReason)
{
   string r = NormalizeLegacyReasonV4(legacyReason);
   if(r == "" || r == "NONE") return false;
   if(IsAbsoluteRiskBlockV4(r)) return false;
   return (ClassifyFilterV4(r) == FILTER_CONVERT_TO_SCORE);
}

double ConvertLegacyReasonToScorePenaltyV4(string legacyReason)
{
   string r = NormalizeLegacyReasonV4(legacyReason);
   if(r == "CHOPPY_MARKET") return (V4Contains(legacyReason, "FORTE") || V4Contains(legacyReason, "STRONG") ? 18.0 : 10.0);
   if(r == "BIAS_EXTREME") return 15.0;
   if(r == "BIAS_MODERATE") return 8.0;
   if(r == "LOSS_STREAK_PAUSE_ACTIVE") return 8.0;
   if(r == "MTF_TREND_AGAINST" || r == "AGAINST_MTF_TREND") return 10.0;
   if(r == "ANTI_OVERTRADE_MARKET_WEAK") return 8.0;
   if(r == "REGIME_BLOCK") return 10.0;
   if(r == "RANGE_COMPRESSED_MODERATE") return 8.0;
   if(r == "RANGE_LOW") return 10.0;
   if(r == "LOW_VOLATILITY_MODERATE") return 8.0;
   if(r == "CANDLE_WEAK") return 8.0;
   if(r == "SIGNAL_WEAK") return 10.0;
   if(r == "TREND_PARTIAL_AGAINST") return 8.0;
   return 5.0;
}

bool ApplyLegacyOverrideV4(string legacyReason, double &entryScore, bool &absoluteBlock, string &legacyAction, string &finalReason)
{
   string r = NormalizeLegacyReasonV4(legacyReason);
   g_v4LastLegacyReason = r;
   absoluteBlock = false;
   legacyAction = "NO_LEGACY_BLOCK";

   if(r == "" || r == "NONE")
   {
      g_v4LastLegacyAction = legacyAction;
      finalReason = "V4_SCORE_BASED_DECISION";
      return true;
   }

   AuditV4("[V4_LEGACY_OVERRIDE] OLD_BLOCK_INTERCEPTED reason=" + r);
   ENUM_V4_FILTER_ACTION action = ClassifyFilterV4(r);

   if(IsAbsoluteRiskBlockV4(r))
   {
      absoluteBlock = true;
      legacyAction = "ABSOLUTE_BLOCK";
      g_v4LastLegacyAction = legacyAction;
      finalReason = r;
      AuditV4("[V4_LEGACY_OVERRIDE] FINAL_BLOCK_ONLY_IF_ABSOLUTE_RISK reason=" + r);
      return false;
   }

   if(action == FILTER_CONVERT_TO_SCORE && UseLegacyFilterOverrideV4)
   {
      double penalty = ConvertLegacyReasonToScorePenaltyV4(r);
      double originalPenalty = penalty;
      double oldEntryScore = entryScore;

      // HORSE V5.1H: CHOPPY_MARKET must remain a protection, but it cannot
      // destroy a valid adaptive BUY/SELL decision after the direction engine
      // already found a clear directional edge.
      if(r == "CHOPPY_MARKET")
      {
         double buyScoreAudit  = CalculateAggressiveEntryScoreV4(ORDER_TYPE_BUY);
         double sellScoreAudit = CalculateAggressiveEntryScoreV4(ORDER_TYPE_SELL);
         double gapAudit = MathAbs(buyScoreAudit - sellScoreAudit);
         string directionAudit = "NEUTRAL";
         if(buyScoreAudit > sellScoreAudit)
            directionAudit = "BUY";
         else if(sellScoreAudit > buyScoreAudit)
            directionAudit = "SELL";

         string regimeReasonAudit = "";
         ENUM_HORSE_MARKET_REGIME regimeAudit = HorseDetectMarketRegime(regimeReasonAudit);
         bool weakRegimeAudit = (regimeAudit == HORSE_RANGE || regimeAudit == HORSE_CHOPPY || regimeAudit == HORSE_COMPRESSION || regimeAudit == HORSE_NEUTRAL);
         bool directionalEdgeValid = (gapAudit >= AdaptiveDirectionNeutralThresholdV4 && MathMax(buyScoreAudit, sellScoreAudit) >= AdaptiveDirectionMinValidScoreV4);

         // Cap the legacy choppy penalty. If direction is clear, make it light.
         // If the market is genuinely weak and edge is not clear, keep protection
         // but still cap the penalty to avoid repeated score destruction.
         if(directionalEdgeValid)
            penalty = MathMin(penalty, 3.0);
         else if(weakRegimeAudit)
            penalty = MathMin(penalty, 6.0);
         else
            penalty = MathMin(penalty, 5.0);

         AuditV4("[V4_CHOPPY_PENALTY_AUDIT] direction=" + directionAudit +
                 " buyScore=" + DoubleToString(buyScoreAudit,1) +
                 " sellScore=" + DoubleToString(sellScoreAudit,1) +
                 " gap=" + DoubleToString(gapAudit,1) +
                 " originalPenalty=" + DoubleToString(originalPenalty,1) +
                 " finalPenalty=" + DoubleToString(penalty,1) +
                 " reason=" + r +
                 " regime=" + HorseMarketRegimeToText(regimeAudit));
      }

      entryScore = V4Clamp(entryScore - penalty, 0.0, 100.0);
      legacyAction = "CONVERTED_TO_SCORE";
      g_v4LastLegacyAction = legacyAction;
      finalReason = "V4_SCORE_BASED_DECISION";
      AuditV4("[V4_LEGACY_OVERRIDE] CONVERTED_TO_SCORE reason=" + r + " penalty=" + DoubleToString(penalty,1));
      AuditV4("[V4_LEGACY_OVERRIDE] LEGACY_FILTER_PENALTY_ONLY_CONTINUE reason=" + r);

      if(r == "CHOPPY_MARKET")
      {
         AuditV4("[V4_CHOPPY_SOFTENED] oldEntryScore=" + DoubleToString(oldEntryScore,1) +
                 " newEntryScore=" + DoubleToString(entryScore,1) +
                 " choppyPenaltyCapped=" + (penalty < originalPenalty ? "true" : "false") +
                 " directionalEdgeValid=" + (penalty <= 3.0 ? "true" : "false"));
      }

      return true;
   }

   if(action == FILTER_EXIT_ONLY)
   {
      legacyAction = "EXIT_ONLY";
      g_v4LastLegacyAction = legacyAction;
      finalReason = "V4_SCORE_BASED_DECISION";
      return true;
   }

   legacyAction = "REMOVE_FROM_FLOW";
   g_v4LastLegacyAction = legacyAction;
   finalReason = "V4_SCORE_BASED_DECISION";
   AuditV4("[V4_LEGACY_OVERRIDE] legacyReason=" + r + " action=REMOVE_FROM_FLOW");
   return true;
}

bool IsForbiddenLegacyFinalReasonV4(string reason)
{
   string r = NormalizeLegacyReasonV4(reason);
   return (r == "CHOPPY_MARKET" || r == "BIAS_EXTREME" || r == "BIAS_MODERATE" ||
           r == "LOSS_STREAK_PAUSE_ACTIVE" || r == "MTF_TREND_AGAINST" || r == "AGAINST_MTF_TREND" ||
           r == "ANTI_OVERTRADE_MARKET_WEAK" || r == "REGIME_BLOCK" ||
           r == "RANGE_COMPRESSED_MODERATE" || r == "RANGE_LOW" || r == "TREND_PARTIAL_AGAINST" ||
           r == "LOW_VOLATILITY_MODERATE" || r == "CANDLE_WEAK" || r == "SIGNAL_WEAK" ||
           r == "LOW_ENTRY_SCORE_V4" || r == "LOW_SCORE_AFTER_LEGACY_PENALTY" ||
           r == "ENTRY_SCORE_PENALTY_ONLY" || r == "ENTRY_SCORE_LEGACY_PENALTY_ONLY" ||
           r == "OLD_MARKET_REGIME_BLOCK" || r == "OLD_BIAS_BLOCK" || r == "OLD_TREND_BLOCK" ||
           r == "OLD_CHOPPY_BLOCK" || r == "V3_2_REAL_EXECUTION_BLOCK" || r == "V3_2_ENTRY_WARNING_FINAL");
}

bool IsEntryQualityFinalBlockV4(string reason)
{
   string r = NormalizeLegacyReasonV4(reason);
   return (r == "LOW_ENTRY_SCORE_V4" || r == "LOW_SCORE_AFTER_LEGACY_PENALTY" ||
           r == "ENTRY_SCORE_PENALTY_ONLY" || r == "ENTRY_SCORE_LEGACY_PENALTY_ONLY");
}

bool ValidateFinalReasonBeforeExecutionV4(string &finalReason, bool &allowEntry, bool &absoluteBlock)
{
   if(!UseV4FinalReasonValidation)
      return true;

   string normalized = NormalizeLegacyReasonV4(finalReason);
   if(IsEntryQualityFinalBlockV4(normalized))
   {
      AuditV4("[V4_VALIDATION] ENTRY_QUALITY_HARD_BLOCK reason=" + normalized);
      allowEntry = false;
      absoluteBlock = false;
      finalReason = normalized;
      return true;
   }

   if(allowEntry)
   {
      if(absoluteBlock)
      {
         AuditV4("[V4_VALIDATION] FAILED item=ALLOW_ENTRY_WITH_ABSOLUTE_BLOCK reason=" + finalReason);
         return false;
      }
      if(IsForbiddenLegacyFinalReasonV4(finalReason))
      {
         AuditV4("[WARNING] LEGACY_FILTER_REACHED_REAL_EXECUTION -> PENALTY_ONLY reason=" + normalized);
         allowEntry = true;
         absoluteBlock = false;
         finalReason = "V4_ENTRY_ALLOWED_LEGACY_PENALTY_ONLY";
      }
      if(RealExecutionSimulationOnly || UseDiagnosticMode || !EnableRealExecution || !AllowLiveTrading)
      {
         AuditV4("[WARNING] REAL_EXECUTION_FLAGS_NOT_REAL -> FALLBACK_CONTINUE");
         allowEntry = true;
         absoluteBlock = false;
         finalReason = "V4_ENTRY_ALLOWED_FLAGS_WARNING";
      }
      return true;
   }

   if(IsForbiddenLegacyFinalReasonV4(finalReason))
   {
      AuditV4("[WARNING] LEGACY_FILTER_REACHED_REAL_EXECUTION -> PENALTY_ONLY reason=" + normalized);
      allowEntry = true;
      absoluteBlock = false;
      finalReason = "V4_ENTRY_ALLOWED_LEGACY_PENALTY_ONLY";
      return true;
   }

   if(absoluteBlock && !IsAbsoluteRiskBlockV4(finalReason))
   {
      AuditV4("[V4_VALIDATION] FAILED item=ABSOLUTE_BLOCK_WITH_NON_ABSOLUTE_REASON reason=" + finalReason);
      return false;
   }
   if(!absoluteBlock && IsAbsoluteRiskBlockV4(finalReason))
   {
      AuditV4("[V4_VALIDATION] FAILED item=NON_ABSOLUTE_WITH_ABSOLUTE_REASON reason=" + finalReason);
      return false;
   }
   return true;
}

class CLegacyFilterOverrideEngineV4
{
public:
   bool IsAbsoluteRiskBlockV4(string legacyReason) { return ::IsAbsoluteRiskBlockV4(legacyReason); }
   bool ShouldConvertLegacyBlockToScoreV4(string legacyReason) { return ::ShouldConvertLegacyBlockToScoreV4(legacyReason); }
   double ConvertLegacyReasonToScorePenaltyV4(string legacyReason) { return ::ConvertLegacyReasonToScorePenaltyV4(legacyReason); }
   bool ApplyLegacyOverrideV4(string legacyReason, double &entryScore, bool &absoluteBlock, string &legacyAction, string &finalReason) { return ::ApplyLegacyOverrideV4(legacyReason, entryScore, absoluteBlock, legacyAction, finalReason); }
};

CLegacyFilterOverrideEngineV4 g_v4LegacyOverrideEngine;

string GetActiveLegacyReasonV4()
{
   if(g_v32Fix1FinalBlockReason != "" && g_v32Fix1FinalBlockReason != "NONE") return g_v32Fix1FinalBlockReason;
   if(g_v32LastRegimeResult == "WOULD_BLOCK") return g_v32LastRegimeReason;
   if(g_v32LastAntiOvertradeResult == "WOULD_BLOCK") return g_v32LastAntiOvertradeReason;
   if(g_v32LastBiasResult == "WOULD_BLOCK") return g_v32LastBiasReason;
   if(g_v32LastTrendResult == "WOULD_BLOCK") return g_v32LastTrendReason;
   if(g_fix3LastBlockReason != "" && g_fix3LastBlockReason != "NONE") return g_fix3LastBlockReason;
   return "NONE";
}

bool HasOppositePositionV4(ENUM_ORDER_TYPE direction)
{
   ENUM_POSITION_TYPE opposite = (direction == ORDER_TYPE_BUY ? POSITION_TYPE_SELL : POSITION_TYPE_BUY);
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pt == opposite) return true;
   }
   return false;
}

bool IsAbsoluteRiskSafeV4(ENUM_ORDER_TYPE direction, string &reason)
{
   reason = "ABSOLUTE_RISK_OK";
   if(!g_symbolOK || !g_timeframeOK || !g_environmentOK) { reason = "CORE_ENVIRONMENT_ABSOLUTE_BLOCK"; return false; }
   if(g_risk.tradingLocked) { reason = "DAILY_RISK_LOCKED_ABSOLUTE_BLOCK: " + g_risk.lockReason; return false; }
   if(V4CountMagicPositions() >= MaxPositionsV4) { reason = "MAX_TOTAL_POSITIONS_ABSOLUTE_BLOCK"; return false; }
   // V5.1M STOP-AND-REVERSE: posicao oposta NAO bloqueia mais aqui na etapa de decisao.
   // O fechamento do lado oposto e tratado na etapa de execucao por
   // V4CloseOppositePositionsForAggressiveReverse (linha ~9332), que fecha o lado
   // fraco ANTES de abrir o novo lado. Bloquear aqui impedia o reverse de acontecer
   // (era a causa do "0 compras": o sinal de BUY morria antes de chegar no reverse).
   // if(HasOppositePositionV4(direction)) { reason = "OPPOSITE_POSITION_ABSOLUTE_BLOCK"; return false; }
   int spread = GetCurrentSpreadPoints();
   int extremeSpread = ExtremeSpreadPoints;
   if(extremeSpread <= 0) extremeSpread = 999999;
   if(spread > extremeSpread) { reason = "SPREAD_EXTREME_ABSOLUTE_BLOCK"; return false; }
   if(!g_mqlTradeAllowed || !g_accountTradeAllowed || !g_liveTradingAllowed) { reason = "TRADE_PERMISSION_ABSOLUTE_BLOCK"; return false; }
   return true;
}

double TrendScoreSimpleV4(ENUM_ORDER_TYPE direction, ENUM_TIMEFRAMES tf)
{
   double c1 = iClose(_Symbol, tf, 1);
   double c4 = iClose(_Symbol, tf, 4);
   if(c1 <= 0.0 || c4 <= 0.0) return 0.0;
   if(direction == ORDER_TYPE_BUY && c1 > c4) return 1.0;
   if(direction == ORDER_TYPE_SELL && c1 < c4) return 1.0;
   return -1.0;
}

string AdaptiveMarketStateV4()
{
   double maFast = V32GetMA((ENUM_TIMEFRAMES)_Period, 9, 1);
   double maSlow = V32GetMA((ENUM_TIMEFRAMES)_Period, 21, 1);
   double adx = MathMax(V32GetADX(PERIOD_M5, 14, 1), V32GetADX(PERIOD_M15, 14, 1));
   double close1 = iClose(_Symbol, _Period, 1);
   if(adx >= 22.0 && maFast > maSlow && close1 > maFast) return "TREND_BULLISH";
   if(adx >= 22.0 && maFast < maSlow && close1 < maFast) return "TREND_BEARISH";
   if(adx >= 18.0 && maFast > maSlow) return "BULLISH_TRANSITION";
   if(adx >= 18.0 && maFast < maSlow) return "BEARISH_TRANSITION";
   if(adx < 14.0) return "RANGE_LOW_ADX";
   return "NEUTRAL_MIXED";
}

double AdaptiveStructureScoreV4(ENUM_ORDER_TYPE direction, string &components)
{
   double h1 = iHigh(_Symbol, _Period, 1);
   double h2 = iHigh(_Symbol, _Period, 2);
   double h3 = iHigh(_Symbol, _Period, 3);
   double l1 = iLow(_Symbol, _Period, 1);
   double l2 = iLow(_Symbol, _Period, 2);
   double l3 = iLow(_Symbol, _Period, 3);
   double c1 = iClose(_Symbol, _Period, 1);
   double c3 = iClose(_Symbol, _Period, 3);
   if(h1 <= 0.0 || h2 <= 0.0 || h3 <= 0.0 || l1 <= 0.0 || l2 <= 0.0 || l3 <= 0.0) return 0.0;

   double score = 0.0;
   if(direction == ORDER_TYPE_BUY)
   {
      if(h1 > h2 && h2 >= h3) { score += 12.0; components += "HH+12;"; }
      if(l1 > l2 && l2 >= l3) { score += 12.0; components += "HL+12;"; }
      if(c1 > c3) { score += 6.0; components += "CLOSE_UP_STRUCTURE+6;"; }
      if(h1 < h2 && l1 < l2) { score -= 10.0; components += "LH_LL_AGAINST-10;"; }
   }
   else if(direction == ORDER_TYPE_SELL)
   {
      if(h1 < h2 && h2 <= h3) { score += 12.0; components += "LH+12;"; }
      if(l1 < l2 && l2 <= l3) { score += 12.0; components += "LL+12;"; }
      if(c1 < c3) { score += 6.0; components += "CLOSE_DOWN_STRUCTURE+6;"; }
      if(h1 > h2 && l1 > l2) { score -= 10.0; components += "HH_HL_AGAINST-10;"; }
   }
   return score;
}

double AdaptivePullbackScoreV4(ENUM_ORDER_TYPE direction, string &components)
{
   double maFast = V32GetMA((ENUM_TIMEFRAMES)_Period, 9, 1);
   double maSlow = V32GetMA((ENUM_TIMEFRAMES)_Period, 21, 1);
   double c1 = iClose(_Symbol, _Period, 1);
   double o1 = iOpen(_Symbol, _Period, 1);
   double l1 = iLow(_Symbol, _Period, 1);
   double h1 = iHigh(_Symbol, _Period, 1);
   double score = 0.0;
   if(maFast <= 0.0 || maSlow <= 0.0 || c1 <= 0.0) return 0.0;

   if(direction == ORDER_TYPE_BUY)
   {
      if(maFast > maSlow && l1 <= maFast && c1 >= maFast) { score += 10.0; components += "BULL_PULLBACK_RECOVERY+10;"; }
      if(maFast < maSlow && h1 >= maFast && c1 <= maFast) { score -= 8.0; components += "BEAR_PULLBACK_AGAINST-8;"; }
      if(c1 > o1) { score += 4.0; components += "BULL_REACTION+4;"; }
   }
   else if(direction == ORDER_TYPE_SELL)
   {
      if(maFast < maSlow && h1 >= maFast && c1 <= maFast) { score += 10.0; components += "BEAR_PULLBACK_RECOVERY+10;"; }
      if(maFast > maSlow && l1 <= maFast && c1 >= maFast) { score -= 8.0; components += "BULL_PULLBACK_AGAINST-8;"; }
      if(c1 < o1) { score += 4.0; components += "BEAR_REACTION+4;"; }
   }
   return score;
}

double V4GetRSIValue(ENUM_TIMEFRAMES tf, int period, int shift)
{
   int handle = iRSI(_Symbol, tf, period, PRICE_CLOSE);
   return V32GetBufferValue(handle, 0, shift);
}

double CalculateAggressiveEntryScoreV4(ENUM_ORDER_TYPE direction)
{
   // V5.1D SCORE BALANCE FIX:
   // BUY and SELL are now scored with the same components, same weights and opposite signs.
   // No side receives a hidden bonus, no side receives a hidden penalty, and score cannot choose SELL by bias.
   double score = 50.0;
   string components = "";
   string buyContrib = "";
   string sellContrib = "";
   string buyPenalty = "";
   string sellPenalty = "";

   int spread = GetCurrentSpreadPoints();
   double open0  = iOpen(_Symbol, _Period, 0);
   double close0 = iClose(_Symbol, _Period, 0);
   double open1  = iOpen(_Symbol, _Period, 1);
   double close1 = iClose(_Symbol, _Period, 1);
   double close2 = iClose(_Symbol, _Period, 2);
   double close3 = iClose(_Symbol, _Period, 3);
   double high1  = iHigh(_Symbol, _Period, 1);
   double high2  = iHigh(_Symbol, _Period, 2);
   double high3  = iHigh(_Symbol, _Period, 3);
   double low1   = iLow(_Symbol, _Period, 1);
   double low2   = iLow(_Symbol, _Period, 2);
   double low3   = iLow(_Symbol, _Period, 3);
   double ma20   = V32GetMA((ENUM_TIMEFRAMES)_Period, 20, 1);
   double ma50   = V32GetMA((ENUM_TIMEFRAMES)_Period, 50, 1);
   double ma200  = V32GetMA((ENUM_TIMEFRAMES)_Period, 200, 1);
   double ma9    = V32GetMA((ENUM_TIMEFRAMES)_Period, 9, 1);
   double ma21   = V32GetMA((ENUM_TIMEFRAMES)_Period, 21, 1);
   double adx    = MathMax(V32GetADX(PERIOD_M5, 14, 1), V32GetADX(PERIOD_M15, 14, 1));
   double atr1   = V32GetATRPoints((ENUM_TIMEFRAMES)_Period, 14, 1);
   double atr5   = V32GetATRPoints((ENUM_TIMEFRAMES)_Period, 14, 5);
   double rsi    = V4GetRSIValue((ENUM_TIMEFRAMES)_Period, 14, 1);
   long vol1     = iVolume(_Symbol, _Period, 1);
   long vol2     = iVolume(_Symbol, _Period, 2);
   long vol3     = iVolume(_Symbol, _Period, 3);
   double avgVol = (double)(vol1 + vol2 + vol3) / 3.0;

   string regimeReason = "";
   ENUM_HORSE_MARKET_REGIME regime = HorseDetectMarketRegime(regimeReason);
   string regimeText = HorseMarketRegimeToText(regime);

   bool isBuy = (direction == ORDER_TYPE_BUY);
   double directionalDelta = 0.0;

   // EMA / trend stack: symmetric + / -.
   if(ma20 > 0.0 && ma50 > 0.0 && ma200 > 0.0 && close1 > 0.0)
   {
      if(ma20 > ma50 && ma50 > ma200 && close1 > ma20)
      {
         directionalDelta += 18.0;
         buyContrib += "EMA_STACK_BULL+18;";
         sellPenalty += "EMA_STACK_BULL_AGAINST-18;";
      }
      else if(ma20 < ma50 && ma50 < ma200 && close1 < ma20)
      {
         directionalDelta -= 18.0;
         sellContrib += "EMA_STACK_BEAR+18;";
         buyPenalty += "EMA_STACK_BEAR_AGAINST-18;";
      }
      else if(ma9 > ma21 && close1 >= ma9)
      {
         directionalDelta += 8.0;
         buyContrib += "EMA_FAST_BULL+8;";
         sellPenalty += "EMA_FAST_BULL_AGAINST-8;";
      }
      else if(ma9 < ma21 && close1 <= ma9)
      {
         directionalDelta -= 8.0;
         sellContrib += "EMA_FAST_BEAR+8;";
         buyPenalty += "EMA_FAST_BEAR_AGAINST-8;";
      }
   }

   // Momentum and candle body: symmetric.
   if(close1 > 0.0 && close3 > 0.0)
   {
      if(close1 > close3) { directionalDelta += 10.0; buyContrib += "MOMENTUM_UP+10;"; sellPenalty += "MOMENTUM_UP_AGAINST-10;"; }
      else if(close1 < close3) { directionalDelta -= 10.0; sellContrib += "MOMENTUM_DOWN+10;"; buyPenalty += "MOMENTUM_DOWN_AGAINST-10;"; }
   }
   if(close0 > open0) { directionalDelta += 5.0; buyContrib += "LIVE_CANDLE_BULL+5;"; sellPenalty += "LIVE_CANDLE_BULL_AGAINST-5;"; }
   else if(close0 < open0) { directionalDelta -= 5.0; sellContrib += "LIVE_CANDLE_BEAR+5;"; buyPenalty += "LIVE_CANDLE_BEAR_AGAINST-5;"; }

   // Structure HH/HL vs LH/LL: symmetric.
   if(high1 > 0.0 && high2 > 0.0 && high3 > 0.0 && low1 > 0.0 && low2 > 0.0 && low3 > 0.0)
   {
      bool bullStruct = (high1 > high2 && high2 >= high3 && low1 >= low2);
      bool bearStruct = (low1 < low2 && low2 <= low3 && high1 <= high2);
      if(bullStruct) { directionalDelta += 16.0; buyContrib += "HH_HL_STRUCTURE+16;"; sellPenalty += "HH_HL_AGAINST-16;"; }
      else if(bearStruct) { directionalDelta -= 16.0; sellContrib += "LH_LL_STRUCTURE+16;"; buyPenalty += "LH_LL_AGAINST-16;"; }
   }

   // RSI: bullish above 55, bearish below 45. Neutral zone does not favor either side.
   if(rsi > 0.0)
   {
      if(rsi >= 55.0 && rsi <= 72.0) { directionalDelta += 7.0; buyContrib += "RSI_BULL+7;"; sellPenalty += "RSI_BULL_AGAINST-7;"; }
      else if(rsi <= 45.0 && rsi >= 28.0) { directionalDelta -= 7.0; sellContrib += "RSI_BEAR+7;"; buyPenalty += "RSI_BEAR_AGAINST-7;"; }
      else if(rsi > 78.0) { directionalDelta -= 3.0; sellContrib += "RSI_OVERBOUGHT_RISK+3;"; buyPenalty += "RSI_OVERBOUGHT_RISK-3;"; }
      else if(rsi < 22.0) { directionalDelta += 3.0; buyContrib += "RSI_OVERSOLD_RISK+3;"; sellPenalty += "RSI_OVERSOLD_RISK-3;"; }
   }

   // ADX/ATR confirms the current directional delta; it does not create SELL bias.
   if(adx >= 22.0)
   {
      if(directionalDelta > 0.0) { directionalDelta += 6.0; buyContrib += "ADX_CONFIRMS_BULL+6;"; sellPenalty += "ADX_BULL_AGAINST-6;"; }
      else if(directionalDelta < 0.0) { directionalDelta -= 6.0; sellContrib += "ADX_CONFIRMS_BEAR+6;"; buyPenalty += "ADX_BEAR_AGAINST-6;"; }
   }
   else if(adx > 0.0 && adx < 14.0)
   {
      // range penalty is symmetric, applied after side score below
      components += "LOW_ADX_RANGE_SYMMETRIC;";
   }

   if(atr1 > 0.0 && atr5 > 0.0)
   {
      if(atr1 > atr5 * 1.10)
      {
         if(directionalDelta > 0.0) { directionalDelta += 4.0; buyContrib += "ATR_EXPANSION_BULL+4;"; sellPenalty += "ATR_EXPANSION_BULL_AGAINST-4;"; }
         else if(directionalDelta < 0.0) { directionalDelta -= 4.0; sellContrib += "ATR_EXPANSION_BEAR+4;"; buyPenalty += "ATR_EXPANSION_BEAR_AGAINST-4;"; }
      }
   }

   // Volume confirms recent candle direction only; symmetric.
   if(avgVol > 0.0 && (double)vol1 > avgVol * 1.10)
   {
      if(close1 > open1) { directionalDelta += 4.0; buyContrib += "VOLUME_BULL_CONFIRM+4;"; sellPenalty += "VOLUME_BULL_AGAINST-4;"; }
      else if(close1 < open1) { directionalDelta -= 4.0; sellContrib += "VOLUME_BEAR_CONFIRM+4;"; buyPenalty += "VOLUME_BEAR_AGAINST-4;"; }
   }

   // Regime alignment. Strong opposite regime is a symmetric penalty, not a forced fallback.
   if(regime == HORSE_TREND_STRONG_BULL || regime == HORSE_TREND_MODERATE_BULL)
   {
      directionalDelta += 10.0;
      buyContrib += "REGIME_BULL+10;";
      sellPenalty += "REGIME_BULL_AGAINST-10;";
   }
   else if(regime == HORSE_TREND_STRONG_BEAR || regime == HORSE_TREND_MODERATE_BEAR)
   {
      directionalDelta -= 10.0;
      sellContrib += "REGIME_BEAR+10;";
      buyPenalty += "REGIME_BEAR_AGAINST-10;";
   }

   if(isBuy) score += directionalDelta;
   else score -= directionalDelta;

   // Symmetric quality penalties: they reduce both sides and therefore cannot create SELL bias.
   if(adx > 0.0 && adx < 14.0) score -= 8.0;
   if(atr1 > 0.0 && atr5 > 0.0 && atr1 < atr5 * 0.85) score -= 6.0;
   if(g_flow.atrPoints > 0.0)
   {
      if(g_flow.atrPoints < HealthyATRMinPoints) score -= 5.0;
      else if(g_flow.atrPoints <= HealthyATRMaxPoints) score += 4.0;
   }
   if(spread <= MaxSpreadPoints) score += 3.0;
   else if(spread < ExtremeSpreadPoints) score -= 8.0;
   if(g_flow.rejectionScore >= StrongRejectionScore) score -= 6.0;

   score = V4Clamp(score, 0.0, 100.0);
   if(direction == ORDER_TYPE_BUY) g_v4LastBuyScore = score;
   if(direction == ORDER_TYPE_SELL) g_v4LastSellScore = score;

   if(isBuy)
      components = buyContrib + buyPenalty;
   else
      components = sellContrib + sellPenalty;

   bool sellBiasDetected = false;
   bool buyBiasDetected = false;
   AuditV4("[V4_ADAPTIVE_DIRECTION_SCORE] direction=" + V4OrderTypeToText(direction) +
           " score=" + DoubleToString(score,1) +
           " EMA_M20=" + DoubleToString(ma20,_Digits) +
           " EMA_M50=" + DoubleToString(ma50,_Digits) +
           " EMA_M200=" + DoubleToString(ma200,_Digits) +
           " RSI=" + DoubleToString(rsi,1) +
           " ADX=" + DoubleToString(adx,1) +
           " ATR=" + DoubleToString(atr1,1) +
           " Momentum=" + DoubleToString(close1-close3,_Digits) +
           " Structure=" + components +
           " Volume=" + IntegerToString((int)vol1) +
           " Regime=" + regimeText +
           " directionalDelta=" + DoubleToString(directionalDelta,1));

   AuditV4("[V4_SCORE_BIAS_AUDIT] direction=" + V4OrderTypeToText(direction) +
           " buyContributions=" + buyContrib +
           " sellContributions=" + sellContrib +
           " buyPenalty=" + buyPenalty +
           " sellPenalty=" + sellPenalty +
           " biasDetected=" + (sellBiasDetected || buyBiasDetected ? "true" : "false"));
   return score;
}

ENUM_ORDER_TYPE SelectAggressiveDirectionV4(double &selectedScore, string &reason)
{
   // HORSE V5.1E - ADAPTIVE / DIRECTIONAL / SYMMETRIC DIRECTION SELECTOR.
   // Esta e a unica autoridade VIVA de direcao antes do OrderSend.
   // BUY e SELL sao tratados como espelho perfeito; o regime atua de forma simetrica.
   // Nenhuma outra funcao foi alterada. O score (CalculateAggressiveEntryScoreV4)
   // permanece intacto e ja e simetrico.
   double buyScore  = CalculateAggressiveEntryScoreV4(ORDER_TYPE_BUY);
   double sellScore = CalculateAggressiveEntryScoreV4(ORDER_TYPE_SELL);
   double diff      = MathAbs(buyScore - sellScore);
   string marketState = AdaptiveMarketStateV4();

   // Regime apenas por LEITURA (HorseDetectMarketRegime nao e alterada).
   string regimeReason = "";
   ENUM_HORSE_MARKET_REGIME regime = HorseDetectMarketRegime(regimeReason);
   string regimeText = HorseMarketRegimeToText(regime);
   // V5.1F: o regime e usado APENAS como informacao de log. O veto de regime foi
   // removido porque, no M1, o regime (MA50/MA200 = 50/200 minutos) le "baixista"
   // a maior parte do tempo mesmo em tendencia de alta, vetando BUY de forma
   // assimetrica. A direcao agora e 100% simetrica, decidida apenas pelo score.

   // (a)/(b) NO_TRADE adaptativo, respeitando os inputs ja existentes.
   if(UseAdaptiveDirectionNoTradeV4)
   {
      if(buyScore < AdaptiveDirectionMinValidScoreV4 && sellScore < AdaptiveDirectionMinValidScoreV4)
      {
         selectedScore = MathMax(buyScore, sellScore);
         reason = "NO_TRADE_BOTH_SCORES_WEAK";
         AuditV4("[V4_ADAPTIVE_DIRECTION] BUY_SCORE=" + DoubleToString(buyScore,1) + " SELL_SCORE=" + DoubleToString(sellScore,1) + " DIRECTION_SELECTED=NO_TRADE MARKET_STATE=" + marketState + " REGIME=" + regimeText + " REASON=" + reason);
         AuditV4("[V4_ADAPTIVE_DIRECTION_AUDIT] buyScore=" + DoubleToString(buyScore,1) + " sellScore=" + DoubleToString(sellScore,1) + " gap=" + DoubleToString(diff,1) + " regime=" + regimeText + " selectedDirection=NEUTRAL reason=" + reason);
         AuditV4("[HORSE_NO_DIRECTION] buyScore=" + DoubleToString(buyScore,1) + " sellScore=" + DoubleToString(sellScore,1) + " gap=" + DoubleToString(diff,1) + " reason=" + reason + " action=NO_TRADE");
         return (ENUM_ORDER_TYPE)-1;
      }
      if(diff < AdaptiveDirectionNeutralThresholdV4)
      {
         selectedScore = MathMax(buyScore, sellScore);
         reason = "NO_TRADE_DIRECTIONAL_EDGE_TOO_SMALL";
         AuditV4("[V4_ADAPTIVE_DIRECTION] BUY_SCORE=" + DoubleToString(buyScore,1) + " SELL_SCORE=" + DoubleToString(sellScore,1) + " DIRECTION_SELECTED=NO_TRADE MARKET_STATE=" + marketState + " REGIME=" + regimeText + " REASON=" + reason);
         AuditV4("[V4_ADAPTIVE_DIRECTION_AUDIT] buyScore=" + DoubleToString(buyScore,1) + " sellScore=" + DoubleToString(sellScore,1) + " gap=" + DoubleToString(diff,1) + " regime=" + regimeText + " selectedDirection=NEUTRAL reason=" + reason);
         AuditV4("[HORSE_NO_DIRECTION] buyScore=" + DoubleToString(buyScore,1) + " sellScore=" + DoubleToString(sellScore,1) + " gap=" + DoubleToString(diff,1) + " reason=" + reason + " action=NO_TRADE");
         return (ENUM_ORDER_TYPE)-1;
      }
   }

   // (d) BUY domina -> BUY (sem veto de regime; decisao 100% simetrica pelo score).
   if(buyScore > sellScore)
   {
      selectedScore = buyScore;
      reason = "BUY_SCORE_DOMINANT_ADAPTIVE";
      AuditV4("[V4_ADAPTIVE_DIRECTION] BUY_SCORE=" + DoubleToString(buyScore,1) + " SELL_SCORE=" + DoubleToString(sellScore,1) + " DIRECTION_SELECTED=BUY MARKET_STATE=" + marketState + " REGIME=" + regimeText + " REASON=" + reason);
      AuditV4("[V4_ADAPTIVE_DIRECTION_AUDIT] buyScore=" + DoubleToString(buyScore,1) + " sellScore=" + DoubleToString(sellScore,1) + " gap=" + DoubleToString(diff,1) + " regime=" + regimeText + " selectedDirection=BUY reason=" + reason);
      AuditV4("[HORSE_DIRECTION_FINAL_GATE] buyScore=" + DoubleToString(buyScore,1) + " sellScore=" + DoubleToString(sellScore,1) + " gap=" + DoubleToString(diff,1) + " direction=BUY source=V4_ADAPTIVE_DIRECTION regime=" + regimeText + " allowed=true reason=" + reason);
      return ORDER_TYPE_BUY;
   }

   // (e) SELL domina -> SELL (sem veto de regime; decisao 100% simetrica pelo score).
   if(sellScore > buyScore)
   {
      selectedScore = sellScore;
      reason = "SELL_SCORE_DOMINANT_ADAPTIVE";
      AuditV4("[V4_ADAPTIVE_DIRECTION] BUY_SCORE=" + DoubleToString(buyScore,1) + " SELL_SCORE=" + DoubleToString(sellScore,1) + " DIRECTION_SELECTED=SELL MARKET_STATE=" + marketState + " REGIME=" + regimeText + " REASON=" + reason);
      AuditV4("[V4_ADAPTIVE_DIRECTION_AUDIT] buyScore=" + DoubleToString(buyScore,1) + " sellScore=" + DoubleToString(sellScore,1) + " gap=" + DoubleToString(diff,1) + " regime=" + regimeText + " selectedDirection=SELL reason=" + reason);
      AuditV4("[HORSE_DIRECTION_FINAL_GATE] buyScore=" + DoubleToString(buyScore,1) + " sellScore=" + DoubleToString(sellScore,1) + " gap=" + DoubleToString(diff,1) + " direction=SELL source=V4_ADAPTIVE_DIRECTION regime=" + regimeText + " allowed=true reason=" + reason);
      return ORDER_TYPE_SELL;
   }

   // (f) Empate exato.
   selectedScore = buyScore;
   reason = "NO_TRADE_EXACT_SCORE_TIE";
   AuditV4("[V4_ADAPTIVE_DIRECTION] BUY_SCORE=" + DoubleToString(buyScore,1) + " SELL_SCORE=" + DoubleToString(sellScore,1) + " DIRECTION_SELECTED=NO_TRADE MARKET_STATE=" + marketState + " REGIME=" + regimeText + " REASON=" + reason);
   AuditV4("[V4_ADAPTIVE_DIRECTION_AUDIT] buyScore=" + DoubleToString(buyScore,1) + " sellScore=" + DoubleToString(sellScore,1) + " gap=" + DoubleToString(diff,1) + " regime=" + regimeText + " selectedDirection=NEUTRAL reason=" + reason);
   AuditV4("[HORSE_NO_DIRECTION] buyScore=" + DoubleToString(buyScore,1) + " sellScore=" + DoubleToString(sellScore,1) + " gap=" + DoubleToString(diff,1) + " reason=" + reason + " action=NO_TRADE");
   return (ENUM_ORDER_TYPE)-1;
}

bool CanOpenAggressiveEntryV4(ENUM_ORDER_TYPE direction, string &reason)
{
   string absReason = "";
   if(!IsAbsoluteRiskSafeV4(direction, absReason))
   {
      reason = NormalizeLegacyReasonV4(absReason);
      AuditV4("[V4_AGGRESSIVE_ENTRY] BLOCK_ABSOLUTE_RISK reason=" + reason);
      return false;
   }

   double score = CalculateAggressiveEntryScoreV4(direction);
   double rawScore = score;
   string legacyReason = NormalizeLegacyReasonV4(GetActiveLegacyReasonV4());
   string legacyAction = "";
   bool absoluteBlock = false;
   string overrideReason = "";

   if(!ApplyLegacyOverrideV4(legacyReason, score, absoluteBlock, legacyAction, overrideReason))
   {
      reason = overrideReason;
      return false;
   }

   g_v4LastEntryScore = score;
   if(score >= PriorityAggressiveEntryScoreV4)
   {
      reason = "ALLOW_SCORE_82_PRIORITY";
      AuditV4("[V4_AGGRESSIVE_ENTRY] ALLOW_SCORE_82_PRIORITY");
      return true;
   }
   if(score >= StrongAggressiveEntryScoreV4)
   {
      reason = "ALLOW_SCORE_75_STRONG";
      AuditV4("[V4_AGGRESSIVE_ENTRY] ALLOW_SCORE_75_STRONG");
      return true;
   }
   if(score >= MinAggressiveEntryScoreV4)
   {
      reason = "ALLOW_SCORE_68";
      AuditV4("[V4_AGGRESSIVE_ENTRY] ALLOW_SCORE_68");
      return true;
   }

   double penalty = MinAggressiveEntryScoreV4 - score;
   if(penalty < 0.0)
      penalty = 0.0;

   if(legacyAction == "CONVERTED_TO_SCORE" && rawScore >= MinAggressiveEntryScoreV4 && score < MinAggressiveEntryScoreV4)
      reason = "ENTRY_SCORE_LEGACY_PENALTY_ONLY";
   else
      reason = "ENTRY_SCORE_PENALTY_ONLY";

   AuditV4("[WARNING] ENTRY_SCORE_LOW -> PENALTY_ONLY_CONTINUE penalty=" + DoubleToString(penalty,1) + " rawScore=" + DoubleToString(rawScore,1) + " finalScore=" + DoubleToString(score,1));
   return true;
}

V4FinalDecision BuildFinalDecisionV4(ENUM_ORDER_TYPE direction)
{
   V4FinalDecision d;
   d.allowEntry = false;
   d.allowExit = true;
   d.absoluteBlock = false;
   d.direction = V4OrderTypeToText(direction);
   d.finalReason = "INIT";
   d.entryScore = CalculateAggressiveEntryScoreV4(direction);
   double rawScore = d.entryScore;
   d.profitPotentialScore = 0.0;
   d.legacyReason = NormalizeLegacyReasonV4(GetActiveLegacyReasonV4());
   d.legacyAction = "NONE";

   string absReason = "";
   if(!IsAbsoluteRiskSafeV4(direction, absReason))
   {
      d.absoluteBlock = true;
      d.allowEntry = false;
      d.finalReason = NormalizeLegacyReasonV4(absReason);
      d.legacyAction = "ABSOLUTE_BLOCK";
   }
   else
   {
      string overReason = "";
      bool legacyAbsolute = false;
      string legacyAction = "";
      bool legacyOK = ApplyLegacyOverrideV4(d.legacyReason, d.entryScore, legacyAbsolute, legacyAction, overReason);
      d.legacyAction = legacyAction;
      if(!legacyOK || legacyAbsolute)
      {
         d.absoluteBlock = true;
         d.allowEntry = false;
         d.finalReason = overReason;
      }
      else if(d.entryScore >= MinAggressiveEntryScoreV4)
      {
         d.allowEntry = true;
         d.absoluteBlock = false;
         d.finalReason = "V4_ENTRY_ALLOWED";
      }
      else
      {
         d.allowEntry = false;
         d.absoluteBlock = false;

         double penalty = MinAggressiveEntryScoreV4 - d.entryScore;
         if(penalty < 0.0)
            penalty = 0.0;

         AuditV4("[V4_ENTRY_QUALITY_BLOCK] ENTRY_SCORE_LOW -> HARD_BLOCK penalty=" + DoubleToString(penalty,1));

         if(d.legacyAction == "CONVERTED_TO_SCORE" && rawScore >= MinAggressiveEntryScoreV4 && d.entryScore < MinAggressiveEntryScoreV4)
            d.finalReason = "ENTRY_SCORE_LEGACY_PENALTY_ONLY";
         else
            d.finalReason = "ENTRY_SCORE_PENALTY_ONLY";
      }
   }

   string validatedReason = d.finalReason;
   if(!ValidateFinalReasonBeforeExecutionV4(validatedReason, d.allowEntry, d.absoluteBlock))
   {
      d.allowEntry = false;
      d.absoluteBlock = false;
   }
   d.finalReason = validatedReason;
   g_v4LastFinalReason = d.finalReason;
   g_v4LastEntryScore = d.entryScore;

   AuditV4("[V4_FINAL_DECISION] allowEntry=" + BoolToText(d.allowEntry) + " absoluteBlock=" + BoolToText(d.absoluteBlock) + " entryScore=" + DoubleToString(d.entryScore,1) + " legacyReason=" + d.legacyReason + " legacyAction=" + d.legacyAction + " finalReason=" + d.finalReason);
   return d;
}

int FindRoleIndexV4(ulong ticket)
{
   for(int i=0; i<ArraySize(g_v4TicketRoles); i++)
      if(g_v4TicketRoles[i].ticket == ticket)
         return i;
   return -1;
}

string RoleForPositionIndexV4(int index)
{
   if(index <= 0) return "MAIN";
   if(index == 1) return "LAYER_1";
   if(index == 2) return "RUNNER";
   return "UNKNOWN";
}

string GetRoleForTicketV4(ulong ticket)
{
   int idx = FindRoleIndexV4(ticket);
   if(idx >= 0) return g_v4TicketRoles[idx].role;
   return "UNKNOWN";
}

void AssignRoleV4(ulong ticket, string role, datetime openTime, double entryPrice, double lot, string reason)
{
   int idx = FindRoleIndexV4(ticket);
   if(idx < 0)
   {
      int size = ArraySize(g_v4TicketRoles);
      ArrayResize(g_v4TicketRoles, size + 1);
      idx = size;
   }
   g_v4TicketRoles[idx].ticket = ticket;
   g_v4TicketRoles[idx].role = role;
   g_v4TicketRoles[idx].openTime = openTime;
   g_v4TicketRoles[idx].entryPrice = entryPrice;
   g_v4TicketRoles[idx].initialLot = lot;
   AuditV4("[V4_ROLE] " + role + "_ASSIGNED ticket=" + UlongToText(ticket) + " reason=" + reason);
}

void RemoveClosedRolesV4()
{
   for(int i=ArraySize(g_v4TicketRoles)-1; i>=0; i--)
   {
      if(!PositionSelectByTicket(g_v4TicketRoles[i].ticket))
      {
         for(int j=i; j<ArraySize(g_v4TicketRoles)-1; j++)
            g_v4TicketRoles[j] = g_v4TicketRoles[j+1];
         ArrayResize(g_v4TicketRoles, ArraySize(g_v4TicketRoles)-1);
      }
   }
}

void SyncTicketRolesV4()
{
   RemoveClosedRolesV4();
   int posIndex = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(FindRoleIndexV4(ticket) < 0)
      {
         string role = RoleForPositionIndexV4(posIndex);
         AssignRoleV4(ticket, role, (datetime)PositionGetInteger(POSITION_TIME), PositionGetDouble(POSITION_PRICE_OPEN), PositionGetDouble(POSITION_VOLUME), "ROLE_REBUILT_FROM_POSITIONS");
         AuditV4("[V4_ROLE] ROLE_REBUILT_FROM_POSITIONS ticket=" + UlongToText(ticket) + " role=" + role);
      }
      posIndex++;
   }
}

int FindPeakIndexV4(ulong ticket)
{
   for(int i=0; i<ArraySize(g_v4TicketPeaks); i++)
      if(g_v4TicketPeaks[i].ticket == ticket)
         return i;
   return -1;
}

void UpdateTicketPeakProfitV4(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return;
   double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   int idx = FindPeakIndexV4(ticket);
   if(idx < 0)
   {
      int size = ArraySize(g_v4TicketPeaks);
      ArrayResize(g_v4TicketPeaks, size + 1);
      idx = size;
      g_v4TicketPeaks[idx].ticket = ticket;
      g_v4TicketPeaks[idx].peakProfit = profit;
   }
   if(profit > g_v4TicketPeaks[idx].peakProfit)
      g_v4TicketPeaks[idx].peakProfit = profit;
   g_v4TicketPeaks[idx].lastUpdate = TimeCurrent();
}

double GetTicketPeakProfitV4(ulong ticket)
{
   int idx = FindPeakIndexV4(ticket);
   if(idx < 0) return 0.0;
   return g_v4TicketPeaks[idx].peakProfit;
}

void RemoveClosedTicketPeakV4()
{
   for(int i=ArraySize(g_v4TicketPeaks)-1; i>=0; i--)
   {
      if(!PositionSelectByTicket(g_v4TicketPeaks[i].ticket))
      {
         for(int j=i; j<ArraySize(g_v4TicketPeaks)-1; j++)
            g_v4TicketPeaks[j] = g_v4TicketPeaks[j+1];
         ArrayResize(g_v4TicketPeaks, ArraySize(g_v4TicketPeaks)-1);
      }
   }
}

// ==================================================
// FIX3 - Smart Exit & Runner Calibration Engine
// This block is exit-only and preserves the FIX2 entry flow.
// ==================================================

bool IsExitLockActiveV4(ulong ticket, string reason)
{
   for(int i=0; i<ArraySize(g_v4ExitLocks); i++)
   {
      if(g_v4ExitLocks[i].ticket == ticket && (TimeCurrent() - g_v4ExitLocks[i].lastCloseAttempt) < MinSecondsBetweenCloseAttemptsV4)
      {
         AuditV4("[V4_EXIT_ORCHESTRATOR] CLOSE_ATTEMPT_LOCK_ACTIVE ticket=" + UlongToText(ticket) + " lastReason=" + g_v4ExitLocks[i].lastReason);
         return true;
      }
   }
   return false;
}

void SetExitLockV4(ulong ticket, string reason)
{
   int idx = -1;
   for(int i=0; i<ArraySize(g_v4ExitLocks); i++)
      if(g_v4ExitLocks[i].ticket == ticket) idx = i;
   if(idx < 0)
   {
      int size = ArraySize(g_v4ExitLocks);
      ArrayResize(g_v4ExitLocks, size + 1);
      idx = size;
   }
   g_v4ExitLocks[idx].ticket = ticket;
   g_v4ExitLocks[idx].lastCloseAttempt = TimeCurrent();
   g_v4ExitLocks[idx].lastReason = reason;
}

string ExitReasonToTextV4(ENUM_V4_EXIT_REASON reason)
{
   switch(reason)
   {
      case EXIT_BASKET_EMERGENCY_SL: return "EXIT_BASKET_EMERGENCY_SL";
      case EXIT_DAILY_RISK: return "EXIT_DAILY_RISK";
      case EXIT_MARGIN_PROTECTION: return "EXIT_MARGIN_PROTECTION";
      case EXIT_RUNNER_BREAK_EVEN: return "EXIT_RUNNER_BREAK_EVEN";
      case EXIT_RUNNER_GIVEBACK: return "EXIT_RUNNER_GIVEBACK";
      case EXIT_SMART_EXIT_CONFIRMED: return "EXIT_SMART_EXIT_CONFIRMED";
      case EXIT_BASKET_PROFIT: return "EXIT_BASKET_PROFIT";
      case EXIT_SMALL_WIN: return "EXIT_SMALL_WIN";
      case EXIT_TIME_NO_PROGRESS: return "EXIT_TIME_NO_PROGRESS";
      default: return "EXIT_NONE";
   }
}

int ExitPriorityValueV4(ENUM_V4_EXIT_REASON reason)
{
   return (int)reason;
}

int FindTicketExitStateIndexV4(ulong ticket)
{
   for(int i=0; i<ArraySize(g_v4TicketExitStates); i++)
      if(g_v4TicketExitStates[i].ticket == ticket)
         return i;
   return -1;
}

int EnsureTicketExitStateV4(ulong ticket)
{
   // V10 VPS FIX: purge tickets fechados antes de crescer o array
   // Evita crescimento ilimitado em sessÃµes longas (6 meses backtest / VPS 24h)
   for(int p = ArraySize(g_v4TicketExitStates) - 1; p >= 0; p--)
   {
      ulong t = g_v4TicketExitStates[p].ticket;
      if(t > 0 && t != ticket && !PositionSelectByTicket(t))
      {
         int sz = ArraySize(g_v4TicketExitStates);
         for(int q = p; q < sz - 1; q++)
            g_v4TicketExitStates[q] = g_v4TicketExitStates[q + 1];
         ArrayResize(g_v4TicketExitStates, sz - 1);
      }
   }

   int idx = FindTicketExitStateIndexV4(ticket);
   if(idx >= 0)
      return idx;

   int size = ArraySize(g_v4TicketExitStates);
   ArrayResize(g_v4TicketExitStates, size + 1);
   idx = size;

   g_v4TicketExitStates[idx].ticket = ticket;
   g_v4TicketExitStates[idx].symbol = _Symbol;
   g_v4TicketExitStates[idx].magic = MagicNumber;
   g_v4TicketExitStates[idx].isRunner = (GetRoleForTicketV4(ticket) == "RUNNER");
   g_v4TicketExitStates[idx].breakEvenActivated = false;
   g_v4TicketExitStates[idx].closeAlreadyRequestedThisTick = false;
   g_v4TicketExitStates[idx].profitPeakMoney = 0.0;
   g_v4TicketExitStates[idx].maxAdverseMoney = 0.0;
   g_v4TicketExitStates[idx].lastProfitMoney = 0.0;
   g_v4TicketExitStates[idx].lastPeakTime = TimeCurrent();
   g_v4TicketExitStates[idx].lastExitDecisionTime = 0;
   g_v4TicketExitStates[idx].lastExitReason = "NONE";
   g_v4TicketExitStates[idx].liveExitClass = "NEW";
   g_v4TicketExitStates[idx].previousExitClass = "NONE";
   g_v4TicketExitStates[idx].lockActivated = false;
   g_v4TicketExitStates[idx].trailingActivated = false;
   g_v4TicketExitStates[idx].classChangedTime = TimeCurrent();

   AuditV4("[V4_TICKET_STATE] CREATED ticket=" + UlongToText(ticket));
   return idx;
}

void RemoveClosedTicketExitStatesV4()
{
   for(int i=ArraySize(g_v4TicketExitStates)-1; i>=0; i--)
   {
      if(!PositionSelectByTicket(g_v4TicketExitStates[i].ticket))
      {
         AuditV4("[V4_TICKET_STATE] REMOVED ticket=" + UlongToText(g_v4TicketExitStates[i].ticket));
         for(int j=i; j<ArraySize(g_v4TicketExitStates)-1; j++)
            g_v4TicketExitStates[j] = g_v4TicketExitStates[j+1];
         ArrayResize(g_v4TicketExitStates, ArraySize(g_v4TicketExitStates)-1);
      }
   }
}

void ResetTicketCloseFlagsV4()
{
   for(int i=0; i<ArraySize(g_v4TicketExitStates); i++)
      g_v4TicketExitStates[i].closeAlreadyRequestedThisTick = false;
}

double CurrentPositionProfitMoneyV4(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return 0.0;
   double grossProfit = PositionGetDouble(POSITION_PROFIT);
   double swap = PositionGetDouble(POSITION_SWAP);
   // MQL5 open positions may not expose commission consistently by broker/build.
   // Use 0.0 here and validate final net result from closed history when needed.
   double commission = 0.0;
   double netProfit = grossProfit + swap + commission;
   AuditV4("[V4_PROFIT_CALC] ticket=" + UlongToText(ticket) +
           " grossProfit=" + DoubleToString(grossProfit,2) +
           " swap=" + DoubleToString(swap,2) +
           " commission=" + DoubleToString(commission,2) +
           " netProfit=" + DoubleToString(netProfit,2));
   return netProfit;
}

void UpdateTicketExitStateV4(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return;
   int idx = EnsureTicketExitStateV4(ticket);
   double profit = CurrentPositionProfitMoneyV4(ticket);
   string role = GetRoleForTicketV4(ticket);

   g_v4TicketExitStates[idx].symbol = PositionGetString(POSITION_SYMBOL);
   g_v4TicketExitStates[idx].magic = (long)PositionGetInteger(POSITION_MAGIC);
   g_v4TicketExitStates[idx].isRunner = (role == "RUNNER");
   g_v4TicketExitStates[idx].lastProfitMoney = profit;
   if(profit < g_v4TicketExitStates[idx].maxAdverseMoney)
      g_v4TicketExitStates[idx].maxAdverseMoney = profit;

   if(profit > g_v4TicketExitStates[idx].profitPeakMoney)
   {
      g_v4TicketExitStates[idx].profitPeakMoney = profit;
      g_v4TicketExitStates[idx].lastPeakTime = TimeCurrent();
      AuditV4("[V4_RUNNER_TRAIL] PEAK_UPDATED ticket=" + UlongToText(ticket) + " peak=" + DoubleToString(profit,2));
   }

   AuditV4("[V4_TICKET_STATE] UPDATED ticket=" + UlongToText(ticket) + " profit=" + DoubleToString(profit,2) + " peak=" + DoubleToString(g_v4TicketExitStates[idx].profitPeakMoney,2));
}

double GetTicketExitPeakMoneyV4(ulong ticket)
{
   int idx = FindTicketExitStateIndexV4(ticket);
   if(idx < 0) return GetTicketPeakProfitV4(ticket);
   return g_v4TicketExitStates[idx].profitPeakMoney;
}

bool IsMomentumStillValidV4(ENUM_POSITION_TYPE direction)
{
   if(direction == POSITION_TYPE_BUY) return (g_flow.buyStrength >= g_flow.sellStrength && g_flow.momentumScore >= MinMomentumScore);
   if(direction == POSITION_TYPE_SELL) return (g_flow.sellStrength >= g_flow.buyStrength && g_flow.momentumScore >= MinMomentumScore);
   return false;
}

bool IsPriceRejectingEntryV4(ENUM_POSITION_TYPE direction)
{
   double o = iOpen(_Symbol, _Period, 0);
   double c = iClose(_Symbol, _Period, 0);
   if(direction == POSITION_TYPE_BUY && c < o && g_flow.rejectionScore >= MinRejectionScore) return true;
   if(direction == POSITION_TYPE_SELL && c > o && g_flow.rejectionScore >= MinRejectionScore) return true;
   return false;
}


int SevereReversalConfirmationsV4(ulong ticket, ENUM_POSITION_TYPE direction)
{
   if(!PositionSelectByTicket(ticket)) return 0;
   int confirms = 0;
   if(IsPriceRejectingEntryV4(direction)) confirms++;
   if(!IsMomentumStillValidV4(direction)) confirms++;
   if(IsM5M15FullyAgainstV4(direction)) confirms++;
   double score = CalculateProfitPotentialScoreV4(ticket, direction);
   if(score < EmergencyNoPotentialScoreV4) confirms++;
   double profit = CurrentPositionProfitMoneyV4(ticket);
   double peak = GetTicketExitPeakMoneyV4(ticket);
   if((peak > 0.0 && profit < peak * 0.40) || profit <= 0.0) confirms++;
   if(confirms > 5) confirms = 5;
   return confirms;
}

bool IsSevereReversalV4(ulong ticket, ENUM_POSITION_TYPE direction)
{
   int confirms = SevereReversalConfirmationsV4(ticket, direction);
   bool allowed = (confirms >= SmartExitPositiveCloseConfirmationsV4);
   AuditV4("[V4_SEVERE_REVERSAL] confirmations=" + IntegerToString(confirms) + "/5 allowed=" + (allowed ? "TRUE" : "FALSE") + " ticket=" + UlongToText(ticket));
   return allowed;
}

bool IsRunnerCandidateV4(ulong ticket, ENUM_POSITION_TYPE direction)
{
   if(!PositionSelectByTicket(ticket)) return false;
   if(GetRoleForTicketV4(ticket) == "RUNNER") return true;
   datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
   int age = (int)(TimeCurrent() - openTime);
   double profit = CurrentPositionProfitMoneyV4(ticket);
   double peak = GetTicketExitPeakMoneyV4(ticket);
   bool profitOK = (profit >= RunnerAssignMinProfitV4 || peak >= RunnerAssignMinProfitV4 * 1.5);
   if(profitOK && age >= RunnerAssignMinSecondsV4 && IsTrendSupportiveV4(direction) && GetCurrentSpreadPoints() <= MaxSpreadForSmartExitV4 && !IsSevereReversalV4(ticket, direction))
   {
      AuditV4("[V4_RUNNER] RUNNER_CANDIDATE ticket=" + UlongToText(ticket) + " profit=" + DoubleToString(profit,2));
      if(GetRoleForTicketV4(ticket) != "RUNNER")
         AssignRoleV4(ticket, "RUNNER", openTime, PositionGetDouble(POSITION_PRICE_OPEN), PositionGetDouble(POSITION_VOLUME), "EARLY_RUNNER_PROMOTION_V4");
      AuditV4("[V4_RUNNER] RUNNER_ASSIGNED_EARLY ticket=" + UlongToText(ticket));
      return true;
   }
   return false;
}

bool IsCriticalExitReasonTextV4(string closeReason)
{
   string r = closeReason;
   StringToUpper(r);
   if(StringFind(r, "BASKET_EMERGENCY") >= 0) return true;
   if(StringFind(r, "EMERGENCY") >= 0) return true;
   if(StringFind(r, "SL_HIT") >= 0) return true;
   if(StringFind(r, "DAILY") >= 0) return true;
   if(StringFind(r, "MARGIN") >= 0) return true;
   if(StringFind(r, "RISK") >= 0) return true;
   if(StringFind(r, "BREAK_EVEN") >= 0) return true;
   if(StringFind(r, "VIRTUAL_LOCK_CLOSE") >= 0) return true;
   return false;
}

bool IsWeakMicroProfitExitReasonV4(string closeReason)
{
   string r = closeReason;
   StringToUpper(r);
   if(StringFind(r, "SMALL_WIN") >= 0) return true;
   if(StringFind(r, "BASKET_PROFIT") >= 0) return true;
   if(StringFind(r, "BASKET_TARGET") >= 0) return true;
   if(StringFind(r, "BASKET_SMART") >= 0) return true;
   if(StringFind(r, "BASKET_CLOSE") >= 0 && StringFind(r, "EMERGENCY") < 0) return true;
   if(StringFind(r, "RETRACE") >= 0) return true;
   if(StringFind(r, "PROFIT_PROTECTION") >= 0) return true;
   if(StringFind(r, "WEAKNESS") >= 0) return true;
   if(StringFind(r, "TIME") >= 0 || StringFind(r, "NO_PROGRESS") >= 0 || StringFind(r, "STALL") >= 0) return true;
   if(StringFind(r, "SMART") >= 0 || StringFind(r, "CLOSE_CONFIRMED") >= 0) return true;
   if(StringFind(r, "GIVEBACK") >= 0 && StringFind(r, "RUNNER_GIVEBACK") < 0) return true;
   return false;
}

void AuditEarlyCloseV4(ulong ticket, string closeReason)
{
   if(!PositionSelectByTicket(ticket)) return;
   ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
   int age = (int)(TimeCurrent() - openTime);
   double profit = CurrentPositionProfitMoneyV4(ticket);
   double peak = GetTicketExitPeakMoneyV4(ticket);
   int confirms = SevereReversalConfirmationsV4(ticket, pt);
   double adx = MathMax(V32GetADX(PERIOD_M5, 14, 1), V32GetADX(PERIOD_M15, 14, 1));
   string role = GetRoleForTicketV4(ticket);
   AuditV4("[V4_EARLY_CLOSE_AUDIT] ticket=" + UlongToText(ticket) +
           " profit=" + DoubleToString(profit,2) +
           " profitPeak=" + DoubleToString(peak,2) +
           " ageSeconds=" + IntegerToString(age) +
           " isRunner=" + BoolToText(role == "RUNNER") +
           " exitReason=" + closeReason +
           " selectedBy=EXIT_ORCHESTRATOR" +
           " confirmations=" + IntegerToString(confirms) +
           " momentum=" + DoubleToString(g_flow.momentumScore,1) +
           " adx=" + DoubleToString(adx,1) +
           " emaState=" + (IsTrendSupportiveV4(pt) ? "FAVORABLE" : "NOT_FAVORABLE") +
           " m5State=" + (IsM5M15FullyAgainstV4(pt) ? "AGAINST" : "NOT_FULLY_AGAINST") +
           " spread=" + IntegerToString(GetCurrentSpreadPoints()));
}

bool ShouldBlockMicroProfitCloseV4(ulong ticket, string closeReason)
{
   if(!UseMinProfitHoldV4 || !BlockMicroProfitCloseV4) return false;
   if(!PositionSelectByTicket(ticket)) return false;
   ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double profit = CurrentPositionProfitMoneyV4(ticket);
   if(profit <= 0.0 || profit >= MinProfitToAllowPositiveCloseV4) return false;

   if(profit > 0.0 && profit < 10.0)
      AuditEarlyCloseV4(ticket, closeReason);

    if(IsCriticalExitReasonTextV4(closeReason))
    {
       g_v4MicroProfitCloseAllowedCount++;
       AuditV4("[V4_EXIT_ORCHESTRATOR] CRITICAL_EXIT_BYPASS_PROFIT_HOLD ticket=" + UlongToText(ticket) + " reason=" + closeReason);
       AuditV4("[V4_PROFIT_HOLD] MICRO_PROFIT_RISK_EXIT_ALLOWED ticket=" + UlongToText(ticket) + " profit=" + DoubleToString(profit,2));
       return false;
    }

    string protectedReasonV10 = closeReason;
    StringToUpper(protectedReasonV10);
    if(StringFind(protectedReasonV10, "MODERATE_LOCK_PROTECTED") >= 0 ||
       StringFind(protectedReasonV10, "GOOD_PROTECTED_REVERSAL") >= 0 ||
       StringFind(protectedReasonV10, "RUNNER_CONFIRMED_REVERSAL") >= 0 ||
       StringFind(protectedReasonV10, "BIG_RUNNER_EXIT_CONFIRMED") >= 0)
    {
       g_v4MicroProfitCloseAllowedCount++;
       AuditV4("[V4_PROFIT_HOLD] PROTECTED_CLASS_EXIT_ALLOWED_V10 ticket=" + UlongToText(ticket) + " profit=" + DoubleToString(profit,2) + " reason=" + closeReason);
       return false;
    }

   bool severe = IsSevereReversalV4(ticket, pt);
   if(severe)
   {
      g_v4MicroProfitCloseAllowedCount++;
      AuditV4("[V4_PROFIT_HOLD] MICRO_PROFIT_SEVERE_REVERSAL_ALLOWED ticket=" + UlongToText(ticket) + " profit=" + DoubleToString(profit,2) + " reason=" + closeReason);
      return false;
   }

   bool runnerProtected = (GetRoleForTicketV4(ticket) == "RUNNER" || IsRunnerCandidateV4(ticket, pt));
   if(runnerProtected)
   {
      g_v4RunnerMicroCloseBlockedCount++;
      AuditV4("[V4_RUNNER_PROTECTION] MICRO_PROFIT_CLOSE_BLOCKED ticket=" + UlongToText(ticket) + " profit=" + DoubleToString(profit,2) + " reason=" + closeReason);
      AuditV4("[V4_RUNNER_PROTECTION] RUNNER_HOLDING_FOR_LARGER_MOVE ticket=" + UlongToText(ticket));
   }

   if(IsWeakMicroProfitExitReasonV4(closeReason) || runnerProtected)
   {
      g_v4MicroProfitCloseBlockedCount++;
      if(StringFind(closeReason, "SMALL_WIN") >= 0) g_v4EarlySmallWinBlockedCount++;
      if(StringFind(closeReason, "BASKET") >= 0 || StringFind(closeReason, "MEDIUM_WIN") >= 0) g_v4EarlyBasketCloseBlockedCount++;
      if(StringFind(closeReason, "TIME") >= 0 || StringFind(closeReason, "NO_PROGRESS") >= 0) g_v4EarlyTimeExitBlockedCount++;
      AuditV4("[V4_PROFIT_HOLD] MICRO_PROFIT_WEAK_EXIT_BLOCKED ticket=" + UlongToText(ticket) + " profit=" + DoubleToString(profit,2) + " reason=" + closeReason);
      AuditV4("[V4_PROFIT_HOLD] MICRO_PROFIT_CLOSE_BLOCKED ticket=" + UlongToText(ticket) + " profit=" + DoubleToString(profit,2) + " reason=" + closeReason);
      AuditV4("[V4_EXIT_ORCHESTRATOR] WEAK_EXIT_BLOCKED_MICRO_PROFIT ticket=" + UlongToText(ticket) + " reason=" + closeReason + " profit=" + DoubleToString(profit,2));
      AuditV4("[V4_EXIT_ORCHESTRATOR] HOLDING_FOR_BETTER_EXIT ticket=" + UlongToText(ticket));
      if(UseEarlyCloseDiagnosticOnlyV4)
      {
         AuditV4("[V4_EARLY_CLOSE_DIAGNOSTIC] WOULD_BLOCK ticket=" + UlongToText(ticket) + " profit=" + DoubleToString(profit,2) + " reason=" + closeReason);
         return false;
      }
      return true;
   }

   return false;
}




//+------------------------------------------------------------------+
//| HORSE EA - STAGE 15                                         |
//| SMART DYNAMIC SL/TP & EXIT ENGINE                                |
//| Objetivo: remover dependencia de TP/SL fixo e deixar winners run. |
//+------------------------------------------------------------------+

input bool   UseStage15SmartDynamicExitEngine = true;
input bool   Stage15_DisableFixedServerTP     = true;
input bool   Stage15_UseDynamicServerSL       = true;
input bool   Stage15_ManageOpenPositions      = true;
input bool   Stage15_CloseWeakTrades          = true;
input bool   Stage15_TimeExitEnabled          = true;
input bool   Stage15_ShowWallboard            = true;
input bool   Stage15_EnableCatastrophicSingleTradeGuard = true;
input double Stage15_CatastrophicLossMoney = -35.0;
input double Stage15_CatastrophicMaxMFEToClose = 8.0;
input int    Stage15_CatastrophicMinSecondsInTrade = 90;
input double Stage15_CatastrophicRunnerSafeMFE = 25.0;

input int    Stage15_ATRPeriod                = 14;
input double Stage15_MainSL_ATR               = 2.00;  // V10: MAIN â€” 2Ã—ATR
input double Stage15_LayerSL_ATR              = 2.20;  // V10: LAYER
input double Stage15_RunnerSL_ATR             = 3.50;  // V10: RUNNER â€” 3.5Ã—ATR
input double Stage15_MinSLPoints              = 100.0; // V10: piso menor â€” be mais eficiente
input double Stage15_MaxSLPoints              = 1200.0;// V10: teto maior â€” runner grande respira

// Break-even por classe (ATR multipliers)
input double Stage15_BreakEvenTriggerATR      = 0.60;  // V10: era 0.80 â†’ BE mais rÃ¡pido (60% do ATR)
input double Stage15_BreakEvenBufferATR       = 0.12;  // V10: era 0.20 â†’ buffer menor = mais justo

// Profit lock por classe
input double Stage15_ProfitLockTriggerATR     = 1.00;  // V10: era 1.40 â†’ lock ativa em 1Ã—ATR
input double Stage15_ProfitLockPercent        = 30.0;  // V10: era 35 â†’ lock 30% (menos sufocante)

// Trailing por classe â€” conduz o trade, protege e captura tendÃªncia
input double Stage15_TrailATRWeak             = 1.20;  // V10: WEAK â€” trailing a 1.2Ã—ATR do preÃ§o
input double Stage15_TrailATRStrong           = 2.00;  // V10: MODERATE â€” 2Ã—ATR de distÃ¢ncia
input double Stage15_RunnerTrailATR           = 4.00;  // V10: RUNNER â€” 4Ã—ATR (era 3.20)

// V10: BIG RUNNER ($500-$1500) â€” trailing ainda mais largo para capturar moves longos
input double Stage15_BigRunnerMinMoney        = 150.0; // Trade com >$150 = Big Runner
input double Stage15_BigRunnerTrailATR        = 5.50;  // 5.5Ã—ATR de distÃ¢ncia â€” fÃ´lego mÃ¡ximo

input double Stage15_ExitScoreHold            = 62.0;
input double Stage15_ExitScoreTighten         = 45.0;
input double Stage15_ExitScoreClose           = 35.0;
input int    Stage15_MinHoldMainSeconds       = 60;
input int    Stage15_MinHoldLayerSeconds      = 90;
input int    Stage15_MinHoldRunnerSeconds     = 90;
input int    Stage15_MaxNoProgressSeconds     = 5400;
input double Stage15_MinProfitForWeakClose    = 2.0;
input int    Stage15_MinSecondsBetweenModify  = 5;

// V10 LIVE EXIT CLASSIFICATION - ajuste cirurgico de saida por classe
input bool   V10_EnableLiveExitClassification = true;
input double V10_WeakMaxLossMoney             = 10.0;
input double V10_WeakMinMFEToSurvive          = 5.0;
input int    V10_WeakMaxSecondsNoConfirm      = 120;

input double V10_ModerateBETriggerMoney       = 6.0;
input double V10_ModerateLockTriggerMoney     = 12.0;
input double V10_ModerateLockProfitMoney      = 3.0;

input double V10_GoodBETriggerMoney           = 8.0;
input double V10_GoodLockTriggerMoney         = 18.0;
input double V10_GoodMinProtectedProfit       = 5.0;

input double V10_RunnerStartMoney             = 30.0;
input double V10_RunnerATRMult                = 4.0;
input double V10_BigRunnerStartMoney          = 80.0;
input double V10_BigRunnerATRMult             = 6.0;
input double V10_MaxGivebackPercentRunner     = 45.0;
input double V10_MaxGivebackPercentBigRunner  = 35.0;

// V10 REAL FLOW INTEGRATION - garante que a saida V10 rode no fluxo real antes dos fechamentos antigos
input bool   V10_ForceRealFlowIntegration     = true;
input bool   V10_BlockLegacySmallProfitExit   = true;
input bool   V10_LogEveryManagedTicket        = true;
input bool   V10_EnablePositionScanAudit      = true;
input bool   V10_BlockLegacySmallExit         = true;

int      g_stage15ModifyCount = 0;
int      g_stage15BECount = 0;
int      g_stage15TrailCount = 0;
int      g_stage15WeakExitRequests = 0;
int      g_stage15TimeExitRequests = 0;
string   g_stage15LastAction = "INIT";
string   g_stage15LastReason = "INIT";
datetime g_stage15LastModifyTime = 0;
ulong    g_stage15LastTicket = 0;
double   g_stage15LastExitScore = 0.0;

void Stage15_Log(string msg)
{
   if(PrintDetailedLogs)
      Print("[HORSE EA][STAGE15_DYNAMIC_EXIT] ", msg);
}

double Stage15_ATRPoints()
{
   int handle = iATR(_Symbol, PERIOD_M1, Stage15_ATRPeriod);
   if(handle == INVALID_HANDLE) return MathMax(g_atrM1Points, Stage15_MinSLPoints);
   double buf[];
   ArraySetAsSeries(buf, true);
   int copied = CopyBuffer(handle, 0, 0, 1, buf);
   IndicatorRelease(handle);
   if(copied <= 0 || buf[0] <= 0.0 || _Point <= 0.0)
      return MathMax(g_atrM1Points, Stage15_MinSLPoints);
   return buf[0] / _Point;
}

double Stage15_Clamp(double v, double lo, double hi)
{
   return MathMax(lo, MathMin(hi, v));
}


// ==================================================
// STAGE 15 - SAFE DATA ACCESSORS
// ==================================================
// These helpers avoid compile errors caused by non-existent snapshot globals.
// They use variables/functions that exist in the HORSE EA base and fall
// back to indicator calculations when needed.

bool Stage15_HasDirectionalData()
{
   // In this EA build the V4/V32 score variables are always declared.
   if(g_v4LastEntryScore > 0.0 || g_v4LastBuyScore > 0.0 || g_v4LastSellScore > 0.0)
      return true;
   if(g_entryDecisionScore > 0.0 || g_buyDecisionScore > 0.0 || g_sellDecisionScore > 0.0)
      return true;
   if(g_entryBaseScore > 0.0 || g_buyEntryBaseScore > 0.0 || g_sellEntryBaseScore > 0.0)
      return true;
   return false;
}

double Stage15_GetADX()
{
   double adx = 0.0;

   // Prefer existing V32 helper because it is already used by the EA.
   adx = MathMax(V32GetADX(PERIOD_M5, 14, 1), V32GetADX(PERIOD_M15, 14, 1));

   // Fallback to M1 ADX if higher timeframe helper did not return a useful value.
   if(adx <= 0.0)
   {
      int handle = iADX(_Symbol, PERIOD_M1, 14);
      if(handle != INVALID_HANDLE)
      {
         double buf[];
         ArraySetAsSeries(buf, true);
         if(CopyBuffer(handle, 0, 0, 1, buf) > 0)
            adx = buf[0];
         IndicatorRelease(handle);
      }
   }

   if(adx <= 0.0)
      adx = 20.0; // neutral-safe fallback

   return adx;
}

int Stage15_GetSpreadPoints()
{
   if(g_currentSpreadPoints > 0)
      return g_currentSpreadPoints;

   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > 0)
      return (int)spread;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && _Point > 0.0)
      return (int)MathRound((ask - bid) / _Point);

   return 0;
}

double Stage15_GetEntryScoreBuy()
{
   double s = 0.0;
   s = MathMax(s, g_v4LastBuyScore);
   s = MathMax(s, g_buyDecisionScore);
   s = MathMax(s, g_buyEntryBaseScore);
   s = MathMax(s, g_buyDirectionalComponentScore);
   if(s <= 0.0)
      s = 50.0;
   return Stage15_Clamp(s, 0.0, 100.0);
}

double Stage15_GetEntryScoreSell()
{
   double s = 0.0;
   s = MathMax(s, g_v4LastSellScore);
   s = MathMax(s, g_sellDecisionScore);
   s = MathMax(s, g_sellEntryBaseScore);
   s = MathMax(s, g_sellDirectionalComponentScore);
   if(s <= 0.0)
      s = 50.0;
   return Stage15_Clamp(s, 0.0, 100.0);
}

double Stage15_GetDirectionalScore()
{
   double s = 0.0;

   // Prefer V4 aggregate score if available.
   s = MathMax(s, g_v4LastEntryScore);
   s = MathMax(s, MathMax(g_v4LastBuyScore, g_v4LastSellScore));
   s = MathMax(s, g_entryDecisionScore);
   s = MathMax(s, MathMax(g_buyDecisionScore, g_sellDecisionScore));
   s = MathMax(s, g_entryBaseScore);
   s = MathMax(s, MathMax(g_buyEntryBaseScore, g_sellEntryBaseScore));

   // If no internal score exists yet, build a safe neutral market score.
   if(s <= 0.0)
   {
      double adx = Stage15_GetADX();
      double atr = MathMax(Stage15_ATRPoints(), 1.0);
      int spread = Stage15_GetSpreadPoints();

      s = 50.0;
      if(adx >= 25.0) s += 10.0;
      else if(adx < 15.0) s -= 8.0;

      if(atr >= Stage15_MinSLPoints) s += 5.0;
      if(spread > 0 && spread <= Stage12_MaxSpreadPoints) s += 5.0;
      if(g_market.isTradable) s += 5.0;
   }

   return Stage15_Clamp(s, 0.0, 100.0);
}

double Stage15_RoleSLMultiplier(string role)
{
   if(role == "LAYER_1") return Stage15_LayerSL_ATR;
   if(role == "RUNNER") return Stage15_RunnerSL_ATR;
   return Stage15_MainSL_ATR;
}

double Stage15_DynamicSLPoints(string role)
{
   double atr = Stage15_ATRPoints();
   return Stage15_Clamp(atr * Stage15_RoleSLMultiplier(role), Stage15_MinSLPoints, Stage15_MaxSLPoints);
}

void Stage15_PrepareDynamicSLTP(ENUM_ORDER_TYPE direction, string role, double entryPrice, double &sl, double &tp, double &riskPoints, double &rewardPoints)
{
   if(!UseStage15SmartDynamicExitEngine)
      return;

   riskPoints = Stage15_DynamicSLPoints(role);
   rewardPoints = 0.0;

   if(Stage15_UseDynamicServerSL)
   {
      if(direction == ORDER_TYPE_BUY)
         sl = NormalizeDouble(entryPrice - riskPoints * _Point, _Digits);
      else if(direction == ORDER_TYPE_SELL)
         sl = NormalizeDouble(entryPrice + riskPoints * _Point, _Digits);
   }
   else
      sl = 0.0;

   if(Stage15_DisableFixedServerTP)
      tp = 0.0;

   g_stage15LastAction = "PREPARE_DYNAMIC_SLTP";
   g_stage15LastReason = "role=" + role + " riskPoints=" + DoubleToString(riskPoints,1) + " TP_DISABLED=" + BoolToText(Stage15_DisableFixedServerTP);
}

void Stage15_PrepareLayerDynamicSLTP(int layerDirection, string role, double entryPrice, double &sl, double &tp)
{
   if(!UseStage15SmartDynamicExitEngine)
      return;
   double rp = 0.0, rw = 0.0;
   ENUM_ORDER_TYPE dir = (layerDirection == LAYER_DIR_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   Stage15_PrepareDynamicSLTP(dir, role, entryPrice, sl, tp, rp, rw);
}

double Stage15_NormalizedDirectionScore()
{
   return Stage15_GetDirectionalScore();
}

double Stage15_ExitScore(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return 0.0;
   string role = GetRoleForTicketV4(ticket);
   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double open = PositionGetDouble(POSITION_PRICE_OPEN);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double price = (type == POSITION_TYPE_BUY ? bid : ask);
   double atr = MathMax(Stage15_ATRPoints(), 1.0);
   double profitPoints = (type == POSITION_TYPE_BUY ? (price - open) : (open - price)) / _Point;
   double profitAtr = profitPoints / atr;
   double score = 50.0;

   double ds = Stage15_NormalizedDirectionScore();
   double adx = Stage15_GetADX();
   score += (ds - 50.0) * 0.35;
   score += (adx - 20.0) * 0.80;
   score += Stage15_Clamp(profitAtr * 8.0, -20.0, 25.0);
   if(role == "RUNNER") score += 8.0;
   if(g_market.isTradable) score += 5.0;
   if(Stage15_GetSpreadPoints() > Stage12_MaxSpreadPoints) score -= 10.0;

   return Stage15_Clamp(score, 0.0, 100.0);
}

bool Stage15_CanModifyNow()
{
   if(g_stage15LastModifyTime > 0 && TimeCurrent() - g_stage15LastModifyTime < Stage15_MinSecondsBetweenModify)
      return false;
   return true;
}

bool Stage15_IsBetterSL(ENUM_POSITION_TYPE type, double currentSL, double proposedSL)
{
   if(proposedSL <= 0.0) return false;
   if(currentSL <= 0.0) return true;
   if(type == POSITION_TYPE_BUY) return proposedSL > currentSL + (_Point * 2.0);
   return proposedSL < currentSL - (_Point * 2.0);
}

double Stage15_SLTickSizeV10()
{
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0.0) tickSize = _Point;
   if(tickSize <= 0.0) tickSize = 0.01;
   return tickSize;
}

double Stage15_SLMinDistancePriceV10()
{
   int stopLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   int freezeLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   int levelPoints = (stopLevel > freezeLevel ? stopLevel : freezeLevel);
   return MathMax(_Point, ((double)levelPoints * _Point) + Stage15_SLTickSizeV10());
}

double Stage15_NormalizeSLForSideV10(ENUM_POSITION_TYPE type, double sl)
{
   double tickSize = Stage15_SLTickSizeV10();
   if(tickSize <= 0.0) return NormalizeDouble(sl, _Digits);
   if(type == POSITION_TYPE_BUY)
      return NormalizeDouble(MathFloor(sl / tickSize) * tickSize, _Digits);
   return NormalizeDouble(MathCeil(sl / tickSize) * tickSize, _Digits);
}

bool Stage15_IsSLOnCorrectSideV10(ENUM_POSITION_TYPE type, double sl, double bid, double ask, double minDistance)
{
   if(sl <= 0.0 || bid <= 0.0 || ask <= 0.0) return false;
   double tol = MathMax(_Point * 0.25, Stage15_SLTickSizeV10() * 0.25);
   if(type == POSITION_TYPE_BUY) return (bid - sl) >= (minDistance - tol);
   return (sl - ask) >= (minDistance - tol);
}

bool Stage15_IsServerSLAtOrBeyondTargetV10(ENUM_POSITION_TYPE type, double serverSL, double targetSL, double bid, double ask, double minDistance)
{
   if(!Stage15_IsSLOnCorrectSideV10(type, serverSL, bid, ask, minDistance)) return false;
   double tol = MathMax(_Point * 0.5, Stage15_SLTickSizeV10() * 0.5);
   if(type == POSITION_TYPE_BUY) return serverSL >= targetSL - tol;
   return serverSL <= targetSL + tol;
}

bool Stage15_IsSLImprovementV10(ENUM_POSITION_TYPE type, double currentSL, double candidateSL)
{
   if(candidateSL <= 0.0) return false;
   if(currentSL <= 0.0) return true;
   double tol = MathMax(_Point * 2.0, Stage15_SLTickSizeV10());
   if(type == POSITION_TYPE_BUY) return candidateSL > currentSL + tol;
   return candidateSL < currentSL - tol;
}

string Stage15_PositionTypeTextV10(ENUM_POSITION_TYPE type)
{
   return (type == POSITION_TYPE_BUY ? "BUY" : "SELL");
}

void Stage15_LogProtectionNotAppliedV10(ulong ticket, ENUM_POSITION_TYPE type, double currentSL, double requestedSL, double clampedSL, double bid, double ask, string failReason)
{
   Stage15_Log("[STAGE15_SL_PROTECTION_NOT_APPLIED] ticket=" + UlongToText(ticket)
             + " type=" + Stage15_PositionTypeTextV10(type)
             + " currentSL=" + DoubleToString(currentSL,_Digits)
             + " requestedSL=" + DoubleToString(requestedSL,_Digits)
             + " clampedSL=" + DoubleToString(clampedSL,_Digits)
             + " bid=" + DoubleToString(bid,_Digits)
             + " ask=" + DoubleToString(ask,_Digits)
             + " reason=" + failReason);
}

bool Stage15_ModifySL(ulong ticket, double newSL, string reason, double mfeMoneyForLog = 0.0, double profitMoneyForLog = 0.0)
{
   if(!Stage15_CanModifyNow()) return false;
   if(!PositionSelectByTicket(ticket)) return false;

   ENUM_POSITION_TYPE modifyType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double volumeForLog = PositionGetDouble(POSITION_VOLUME);
   double oldSLForLog = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);
   if(Stage15_DisableFixedServerTP) currentTP = 0.0;

   double bidForLog = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double askForLog = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double targetSL = Stage15_NormalizeSLForSideV10(modifyType, newSL);
   double effectiveSL = targetSL;
   double clampedSL = 0.0;
   double tickSizeForLog = Stage15_SLTickSizeV10();
   int stopLevelForLog = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   int freezeLevelForLog = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double minDistance = Stage15_SLMinDistancePriceV10();
   double priceForLog = (modifyType == POSITION_TYPE_BUY ? bidForLog : askForLog);
   double slDistancePointsForLog = (priceForLog > 0.0 ? MathAbs(priceForLog - targetSL) / _Point : 0.0);
   bool requestedSideValid = Stage15_IsSLOnCorrectSideV10(modifyType, targetSL, bidForLog, askForLog, minDistance);
   bool stopLevelOkForLog = (stopLevelForLog <= 0 || slDistancePointsForLog >= (double)stopLevelForLog);
   bool freezeLevelOkForLog = (freezeLevelForLog <= 0 || slDistancePointsForLog >= (double)freezeLevelForLog);

   Stage15_Log("[STAGE15_SL_MODIFY_ATTEMPT] ticket=" + UlongToText(ticket)
             + " symbol=" + _Symbol
             + " type=" + Stage15_PositionTypeTextV10(modifyType)
             + " volume=" + DoubleToString(volumeForLog,2)
             + " tradeClassReason=" + reason
             + " requestedSL=" + DoubleToString(targetSL,_Digits)
             + " currentSL=" + DoubleToString(oldSLForLog,_Digits)
             + " tp=" + DoubleToString(currentTP,_Digits)
             + " bid=" + DoubleToString(bidForLog,_Digits)
             + " ask=" + DoubleToString(askForLog,_Digits)
             + " stopLevel=" + IntegerToString(stopLevelForLog)
             + " freezeLevel=" + IntegerToString(freezeLevelForLog)
             + " digits=" + IntegerToString(_Digits)
             + " point=" + DoubleToString(_Point,_Digits)
             + " tickSize=" + DoubleToString(tickSizeForLog,_Digits)
             + " reason=" + reason);

   Stage15_Log("[STAGE15_SL_DIRECTION_VALIDATION] ticket=" + UlongToText(ticket)
             + " type=" + Stage15_PositionTypeTextV10(modifyType)
             + " bid=" + DoubleToString(bidForLog,_Digits)
             + " ask=" + DoubleToString(askForLog,_Digits)
             + " currentSL=" + DoubleToString(oldSLForLog,_Digits)
             + " requestedSL=" + DoubleToString(targetSL,_Digits)
             + " decision=" + (requestedSideValid ? "VALID" : "INVALID"));

   if(Stage15_IsServerSLAtOrBeyondTargetV10(modifyType, oldSLForLog, targetSL, bidForLog, askForLog, minDistance))
   {
      Stage15_Log("[STAGE15_SL_PROTECTION_CONFIRMED] ticket=" + UlongToText(ticket)
                + " type=" + Stage15_PositionTypeTextV10(modifyType)
                + " oldSL=" + DoubleToString(oldSLForLog,_Digits)
                + " requestedSL=" + DoubleToString(targetSL,_Digits)
                + " effectiveSL=" + DoubleToString(oldSLForLog,_Digits)
                + " serverSL=" + DoubleToString(oldSLForLog,_Digits)
                + " reason=SERVER_SL_ALREADY_AT_TARGET");
      return true;
   }

   if(!requestedSideValid)
   {
      Stage15_Log("[STAGE15_SL_REQUEST_INVALID] ticket=" + UlongToText(ticket)
                + " type=" + Stage15_PositionTypeTextV10(modifyType)
                + " bid=" + DoubleToString(bidForLog,_Digits)
                + " ask=" + DoubleToString(askForLog,_Digits)
                + " currentSL=" + DoubleToString(oldSLForLog,_Digits)
                + " requestedSL=" + DoubleToString(targetSL,_Digits)
                + " reason=REQUESTED_SL_WRONG_SIDE_OR_TOO_CLOSE");

      double rawClamp = (modifyType == POSITION_TYPE_BUY ? bidForLog - minDistance : askForLog + minDistance);
      clampedSL = Stage15_NormalizeSLForSideV10(modifyType, rawClamp);
      bool clampLegal = Stage15_IsSLOnCorrectSideV10(modifyType, clampedSL, bidForLog, askForLog, minDistance);
      bool clampImproves = Stage15_IsSLImprovementV10(modifyType, oldSLForLog, clampedSL);

      if(clampLegal)
      {
         Stage15_Log("[STAGE15_SL_CLAMPED] ticket=" + UlongToText(ticket)
                   + " type=" + Stage15_PositionTypeTextV10(modifyType)
                   + " requestedSL=" + DoubleToString(targetSL,_Digits)
                   + " clampedSL=" + DoubleToString(clampedSL,_Digits)
                   + " bid=" + DoubleToString(bidForLog,_Digits)
                   + " ask=" + DoubleToString(askForLog,_Digits)
                   + " minDistance=" + DoubleToString(minDistance,_Digits)
                   + " reason=REQUESTED_SL_INVALID_CLAMPED_TO_LEGAL_SIDE");
      }

      if(!clampLegal || !clampImproves)
      {
         if(Stage15_IsSLOnCorrectSideV10(modifyType, oldSLForLog, bidForLog, askForLog, minDistance))
         {
            Stage15_Log("[STAGE15_OLD_SL_VALID_BUT_TARGET_NOT_APPLIED] ticket=" + UlongToText(ticket)
                      + " type=" + Stage15_PositionTypeTextV10(modifyType)
                      + " currentSL=" + DoubleToString(oldSLForLog,_Digits)
                      + " targetSL=" + DoubleToString(targetSL,_Digits)
                      + " bid=" + DoubleToString(bidForLog,_Digits)
                      + " ask=" + DoubleToString(askForLog,_Digits)
                      + " reason=OLD_SL_VALID_BUT_NOT_ENOUGH_FOR_TARGET");
         }
         Stage15_LogProtectionNotAppliedV10(ticket, modifyType, oldSLForLog, targetSL, clampedSL, bidForLog, askForLog, "CLAMP_NOT_LEGAL_OR_NOT_IMPROVING_TARGET_NOT_CONFIRMED");
         return false;
      }

      effectiveSL = clampedSL;
   }

   trade.SetExpertMagicNumber((ulong)MagicNumber);
   trade.SetDeviationInPoints(PositionModifyDeviationPoints);
   ResetLastError();
   bool ok = trade.PositionModify(ticket, effectiveSL, currentTP);
   int lastErrorForLog = (int)GetLastError();
   ulong retcodeForLog = trade.ResultRetcode();
   string retcodeDescriptionForLog = trade.ResultRetcodeDescription();

   if(ok)
   {
      g_stage15ModifyCount++;
      g_stage15LastModifyTime = TimeCurrent();
      g_stage15LastTicket = ticket;
      g_stage15LastAction = "MODIFY_SL";
      g_stage15LastReason = reason;
      Stage15_Log("MODIFY_SL_OK ticket=" + UlongToText(ticket) + " sl=" + DoubleToString(effectiveSL,_Digits) + " reason=" + reason);
      Stage15_Log("[STAGE15_SL_MODIFY_SUCCESS] ticket=" + UlongToText(ticket)
                + " newSL=" + DoubleToString(effectiveSL,_Digits)
                + " retcode=" + IntegerToString((int)retcodeForLog)
                + " retcodeDescription=" + retcodeDescriptionForLog
                + " reason=" + reason);
   }
   else
   {
      Stage15_Log("MODIFY_SL_FAIL ticket=" + UlongToText(ticket) + " reason=" + reason + " ret=" + retcodeDescriptionForLog);
      Stage15_Log("[STAGE15_SL_MODIFY_FAILED_V10] ticket=" + UlongToText(ticket)
                + " symbol=" + _Symbol
                + " type=" + Stage15_PositionTypeTextV10(modifyType)
                + " volume=" + DoubleToString(volumeForLog,2)
                + " tradeClassReason=" + reason
                + " requestedSL=" + DoubleToString(effectiveSL,_Digits)
                + " currentSL=" + DoubleToString(oldSLForLog,_Digits)
                + " tp=" + DoubleToString(currentTP,_Digits)
                + " bid=" + DoubleToString(bidForLog,_Digits)
                + " ask=" + DoubleToString(askForLog,_Digits)
                + " stopLevel=" + IntegerToString(stopLevelForLog)
                + " freezeLevel=" + IntegerToString(freezeLevelForLog)
                + " digits=" + IntegerToString(_Digits)
                + " point=" + DoubleToString(_Point,_Digits)
                + " tickSize=" + DoubleToString(tickSizeForLog,_Digits)
                + " lastError=" + IntegerToString(lastErrorForLog)
                + " retcode=" + IntegerToString((int)retcodeForLog)
                + " retcodeDescription=" + retcodeDescriptionForLog
                + " reason=" + reason);
      Stage15_Log("[STAGE15_PROTECTION_NOT_APPLIED] ticket=" + UlongToText(ticket)
                + " tradeClass=" + reason
                + " profit=" + DoubleToString(profitMoneyForLog,2)
                + " mfe=" + DoubleToString(mfeMoneyForLog,2)
                + " mae=NA"
                + " serverSL=" + DoubleToString(oldSLForLog,_Digits)
                + " requestedSL=" + DoubleToString(effectiveSL,_Digits)
                + " reason=SL_MODIFY_FAILED");
      Stage15_Log("[STAGE15_SL_MODIFY_FAIL] ticket=" + UlongToText(ticket)
                + " oldSL=" + DoubleToString(oldSLForLog,_Digits)
                + " attemptedSL=" + DoubleToString(effectiveSL,_Digits)
                + " reason=" + reason
                + " positionType=" + Stage15_PositionTypeTextV10(modifyType)
                + " bid=" + DoubleToString(bidForLog,_Digits)
                + " ask=" + DoubleToString(askForLog,_Digits)
                + " priceRef=" + DoubleToString(priceForLog,_Digits)
                + " slDistancePoints=" + DoubleToString(slDistancePointsForLog,1)
                + " retcode=" + IntegerToString((int)retcodeForLog)
                + " retcodeText=" + retcodeDescriptionForLog
                + " lastError=" + IntegerToString(lastErrorForLog)
                + " brokerStopLevel=" + IntegerToString(stopLevelForLog)
                + " freezeLevel=" + IntegerToString(freezeLevelForLog)
                + " slSideValid=" + BoolToText(requestedSideValid)
                + " stopLevelOK=" + BoolToText(stopLevelOkForLog)
                + " freezeLevelOK=" + BoolToText(freezeLevelOkForLog)
                + " mfeMoney=" + DoubleToString(mfeMoneyForLog,2)
                + " profitMoney=" + DoubleToString(profitMoneyForLog,2));
      Stage15_LogProtectionNotAppliedV10(ticket, modifyType, oldSLForLog, targetSL, clampedSL, bidForLog, askForLog, "POSITION_MODIFY_FAILED_TARGET_NOT_CONFIRMED");
      return false;
   }

   double serverSL = 0.0;
   double confirmBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double confirmAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(PositionSelectByTicket(ticket))
      serverSL = PositionGetDouble(POSITION_SL);

   bool targetConfirmed = Stage15_IsServerSLAtOrBeyondTargetV10(modifyType, serverSL, targetSL, confirmBid, confirmAsk, minDistance);
   bool effectiveConfirmed = Stage15_IsServerSLAtOrBeyondTargetV10(modifyType, serverSL, effectiveSL, confirmBid, confirmAsk, minDistance);

   if(targetConfirmed)
   {
      Stage15_Log("[STAGE15_SL_PROTECTION_CONFIRMED] ticket=" + UlongToText(ticket)
                + " type=" + Stage15_PositionTypeTextV10(modifyType)
                + " oldSL=" + DoubleToString(oldSLForLog,_Digits)
                + " requestedSL=" + DoubleToString(targetSL,_Digits)
                + " effectiveSL=" + DoubleToString(effectiveSL,_Digits)
                + " serverSL=" + DoubleToString(serverSL,_Digits)
                + " reason=POSITION_MODIFY_CONFIRMED");
      Stage15_Log("[STAGE15_SL_MODIFY_OK] ticket=" + UlongToText(ticket)
                + " oldSL=" + DoubleToString(oldSLForLog,_Digits)
                + " newSL=" + DoubleToString(serverSL,_Digits)
                + " reason=" + reason
                + " positionType=" + Stage15_PositionTypeTextV10(modifyType)
                + " bid=" + DoubleToString(confirmBid,_Digits)
                + " ask=" + DoubleToString(confirmAsk,_Digits)
                + " priceRef=" + DoubleToString((modifyType == POSITION_TYPE_BUY ? confirmBid : confirmAsk),_Digits)
                + " slDistancePoints=" + DoubleToString(slDistancePointsForLog,1)
                + " stopLevel=" + IntegerToString(stopLevelForLog)
                + " freezeLevel=" + IntegerToString(freezeLevelForLog)
                + " slSideValid=" + BoolToText(requestedSideValid)
                + " stopLevelOK=" + BoolToText(stopLevelOkForLog)
                + " freezeLevelOK=" + BoolToText(freezeLevelOkForLog)
                + " mfeMoney=" + DoubleToString(mfeMoneyForLog,2)
                + " profitMoney=" + DoubleToString(profitMoneyForLog,2));
      return true;
   }

   if(effectiveConfirmed && MathAbs(effectiveSL - targetSL) > MathMax(_Point, tickSizeForLog) * 0.5)
   {
      Stage15_Log("[STAGE15_SL_PARTIAL_PROTECTION_APPLIED] ticket=" + UlongToText(ticket)
                + " type=" + Stage15_PositionTypeTextV10(modifyType)
                + " oldSL=" + DoubleToString(oldSLForLog,_Digits)
                + " requestedSL=" + DoubleToString(targetSL,_Digits)
                + " clampedSL=" + DoubleToString(effectiveSL,_Digits)
                + " serverSL=" + DoubleToString(serverSL,_Digits)
                + " targetSL=" + DoubleToString(targetSL,_Digits)
                + " reason=CLAMP_APPLIED_BUT_TARGET_NOT_REACHED");
      return false;
   }

   if(Stage15_IsSLOnCorrectSideV10(modifyType, serverSL, confirmBid, confirmAsk, minDistance))
   {
      Stage15_Log("[STAGE15_OLD_SL_VALID_BUT_TARGET_NOT_APPLIED] ticket=" + UlongToText(ticket)
                + " type=" + Stage15_PositionTypeTextV10(modifyType)
                + " currentSL=" + DoubleToString(serverSL,_Digits)
                + " targetSL=" + DoubleToString(targetSL,_Digits)
                + " bid=" + DoubleToString(confirmBid,_Digits)
                + " ask=" + DoubleToString(confirmAsk,_Digits)
                + " reason=OLD_SL_VALID_BUT_NOT_ENOUGH_FOR_TARGET");
   }

   Stage15_LogProtectionNotAppliedV10(ticket, modifyType, serverSL, targetSL, clampedSL, confirmBid, confirmAsk, "SERVER_SL_DID_NOT_CONFIRM_TARGET");
   return false;
}

bool Stage15_IsConfirmedReversal(ulong ticket, ENUM_POSITION_TYPE type)
{
   if(!PositionSelectByTicket(ticket)) return false;
   double ema50 = V32GetMA(PERIOD_M1, 50, 1);
   double close1 = iClose(_Symbol, PERIOD_M1, 1);
   double low1 = iLow(_Symbol, PERIOD_M1, 1);
   double low2 = iLow(_Symbol, PERIOD_M1, 2);
   double high1 = iHigh(_Symbol, PERIOD_M1, 1);
   double high2 = iHigh(_Symbol, PERIOD_M1, 2);
   double adx = Stage15_GetADX();
   if(type == POSITION_TYPE_BUY)
      return (close1 < ema50 && low1 < low2 && adx >= 18.0);
   if(type == POSITION_TYPE_SELL)
      return (close1 > ema50 && high1 > high2 && adx >= 18.0);
   return false;
}

bool Stage15_IsHealthyPullback(ulong ticket, ENUM_POSITION_TYPE type)
{
   if(!PositionSelectByTicket(ticket)) return false;
   double ema50 = V32GetMA(PERIOD_M1, 50, 1);
   double close1 = iClose(_Symbol, PERIOD_M1, 1);
   if(type == POSITION_TYPE_BUY)
      return (close1 >= ema50 && !Stage15_IsConfirmedReversal(ticket, type));
   if(type == POSITION_TYPE_SELL)
      return (close1 <= ema50 && !Stage15_IsConfirmedReversal(ticket, type));
   return false;
}

string Stage15_ClassTextV10(int classID)
{
   if(classID == 1) return "MODERATE";
   if(classID == 2) return "GOOD";
   if(classID == 3) return "RUNNER";
   if(classID == 4) return "BIG_RUNNER";
   return "WEAK";
}

double Stage15_GetTicketMAEMoneyV10(ulong ticket)
{
   int idx = FindTicketExitStateIndexV4(ticket);
   if(idx < 0) return 0.0;
   return g_v4TicketExitStates[idx].maxAdverseMoney;
}

bool Stage15_IsTrendAliveV10(ulong ticket, ENUM_POSITION_TYPE type, bool healthyPullback, bool confirmedReversal)
{
   if(confirmedReversal) return false;
   if(IsTrendSupportiveV4(type)) return true;
   if(IsMomentumStillValidV4(type) && !IsM5M15FullyAgainstV4(type)) return true;
   if(healthyPullback && Stage15_GetADX() >= 18.0) return true;
   return false;
}

double Stage15_ATRPointsForClassV10(int classID)
{
   double atr = MathMax(Stage15_ATRPoints(), 1.0);
   if(classID >= 3)
   {
      double atrM5 = V32GetATRPoints(PERIOD_M5, Stage15_ATRPeriod, 1);
      if(atrM5 > 0.0) atr = MathMax(atr, atrM5);
   }
   return MathMax(atr, 1.0);
}

void Stage15_UpdateLiveClassV10(ulong ticket, string newClass, double profit, double mfe, double mae, double score, bool trendAlive, bool healthyPullback, bool confirmedReversal, string reason)
{
   int idx = EnsureTicketExitStateV4(ticket);
   string oldClass = g_v4TicketExitStates[idx].liveExitClass;
   if(oldClass == "") oldClass = "NEW";
   if(oldClass != newClass)
   {
      g_v4TicketExitStates[idx].previousExitClass = oldClass;
      g_v4TicketExitStates[idx].liveExitClass = newClass;
      g_v4TicketExitStates[idx].classChangedTime = TimeCurrent();
      Stage15_Log("[CLASS_TRANSITION_V10] ticket=" + UlongToText(ticket)
                + " oldClass=" + oldClass
                + " newClass=" + newClass
                + " profit=" + DoubleToString(profit,2)
                + " mfe=" + DoubleToString(mfe,2)
                + " mae=" + DoubleToString(mae,2)
                + " score=" + DoubleToString(score,1)
                + " trendAlive=" + BoolToText(trendAlive)
                + " pullback=" + BoolToText(healthyPullback)
                + " reversal=" + BoolToText(confirmedReversal)
                + " reason=" + reason);
      Stage15_Log("[STAGE15_CLASS_TRANSITION_V10] ticket=" + UlongToText(ticket)
                + " oldClass=" + oldClass
                + " newClass=" + newClass
                + " reason=" + reason
                + " profitMoney=" + DoubleToString(profit,2)
                + " mfeMoney=" + DoubleToString(mfe,2)
                + " maeMoney=" + DoubleToString(mae,2));
   }
}

bool Stage15_SetProtectedSLByMoneyV10(ENUM_POSITION_TYPE type, double openPrice, double volume, double lockMoney, double &proposedSL, string &slReason, string tag)
{
   double dist = MoneyToPriceDistanceV4(lockMoney, volume);
   if(dist <= 0.0) return false;
   double lockSL = 0.0;
   if(type == POSITION_TYPE_BUY) lockSL = openPrice + dist;
   else lockSL = openPrice - dist;
   if(Stage15_IsBetterSL(type, proposedSL, lockSL))
   {
      proposedSL = lockSL;
      slReason = tag;
      return true;
   }
   return false;
}

void Stage15_LogExitAuthorityV10(ulong ticket, string tradeClass, double profit, double mfe, double mae, bool beActive, bool lockActive, bool trailActive, string exitCandidate, bool exitAllowed, string exitReason, string authorizedBy)
{
   Stage15_Log("[EXIT_AUTHORITY_V10] ticket=" + UlongToText(ticket)
             + " class=" + tradeClass
             + " profit=" + DoubleToString(profit,2)
             + " mfe=" + DoubleToString(mfe,2)
             + " mae=" + DoubleToString(mae,2)
             + " beActive=" + BoolToText(beActive)
             + " lockActive=" + BoolToText(lockActive)
             + " trailActive=" + BoolToText(trailActive)
             + " exitCandidate=" + exitCandidate
             + " exitAllowed=" + BoolToText(exitAllowed)
             + " exitReason=" + exitReason
             + " authorizedBy=" + authorizedBy);
}

void Stage15_LogClassDecisionV10(ulong ticket,
                                 string rawClass,
                                 string finalClass,
                                 double profitMoney,
                                 double mfeMoney,
                                 double maeMoney,
                                 int ageSec,
                                 int barsAlive,
                                 bool trendAlive,
                                 bool healthyPullback,
                                 bool confirmedReversal,
                                 bool severeReversal,
                                 string role,
                                 bool runnerCandidate,
                                 string runnerCandidateReason,
                                 bool bigRunnerCandidate,
                                 bool protectionConfirmed,
                                 bool beConfirmed,
                                 bool lockConfirmed,
                                 bool trailConfirmed,
                                 string weakReason,
                                 string moderateReason,
                                 string goodReason,
                                 string runnerReason,
                                 string bigRunnerReason)
{
   Stage15_Log("[STAGE15_CLASS_DECISION_V10] ticket=" + UlongToText(ticket)
             + " rawClass=" + rawClass
             + " finalClass=" + finalClass
             + " profitMoney=" + DoubleToString(profitMoney,2)
             + " mfeMoney=" + DoubleToString(mfeMoney,2)
             + " maeMoney=" + DoubleToString(maeMoney,2)
             + " ageSec=" + IntegerToString(ageSec)
             + " barsAlive=" + IntegerToString(barsAlive)
             + " trendAlive=" + BoolToText(trendAlive)
             + " pullback=" + BoolToText(healthyPullback)
             + " reversal=" + BoolToText(confirmedReversal)
             + " severeReversal=" + BoolToText(severeReversal)
             + " role=" + role
             + " runnerCandidate=" + BoolToText(runnerCandidate)
             + " runnerCandidateReason=" + runnerCandidateReason
             + " bigRunnerCandidate=" + BoolToText(bigRunnerCandidate)
             + " protectionConfirmed=" + BoolToText(protectionConfirmed)
             + " beConfirmed=" + BoolToText(beConfirmed)
             + " lockConfirmed=" + BoolToText(lockConfirmed)
             + " trailConfirmed=" + BoolToText(trailConfirmed)
             + " weakReason=" + weakReason
             + " moderateReason=" + moderateReason
             + " goodReason=" + goodReason
             + " runnerReason=" + runnerReason
             + " bigRunnerReason=" + bigRunnerReason);
}



bool V10_IsMagicAccepted(long magic)
{
   if(magic == MagicNumber) return true;
   // Strategy Tester / some broker bridges can report magic=0 on existing positions.
   // Accept magic=0 only as a safe fallback on the current symbol so V10 can audit and protect real tickets.
   if(MQLInfoInteger(MQL_TESTER) && magic == 0) return true;
   return false;
}

string V10_PositionTypeText(long posType)
{
   if(posType == POSITION_TYPE_BUY) return "BUY";
   if(posType == POSITION_TYPE_SELL) return "SELL";
   return "UNKNOWN";
}

bool V10_ShouldAcceptPosition(ulong ticket, int index, string &rejectReason)
{
   rejectReason = "ACCEPTED";
   bool selected = PositionSelectByTicket(ticket);
   string symbol = "";
   long magic = -1;
   long posType = -1;
   double profit = 0.0;

   if(selected)
   {
      symbol = PositionGetString(POSITION_SYMBOL);
      magic = (long)PositionGetInteger(POSITION_MAGIC);
      posType = (long)PositionGetInteger(POSITION_TYPE);
      profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }

   bool symbolMatch = (selected && symbol == _Symbol);
   bool magicMatch = (selected && V10_IsMagicAccepted(magic));
   bool accepted = (selected && symbolMatch && magicMatch);

   if(!selected) rejectReason = "SELECT_FAILED";
   else if(!symbolMatch) rejectReason = "SYMBOL_MISMATCH";
   else if(!magicMatch) rejectReason = "MAGIC_MISMATCH";
   else rejectReason = "ACCEPTED";

   if(V10_EnablePositionScanAudit)
   {
      AuditV4("[V10_POSITION_SCAN] index=" + IntegerToString(index)
            + " ticket=" + UlongToText(ticket)
            + " symbol=" + symbol
            + " expectedSymbol=" + _Symbol
            + " magic=" + IntegerToString((int)magic)
            + " expectedMagic=" + IntegerToString((int)MagicNumber)
            + " type=" + V10_PositionTypeText(posType)
            + " profit=" + DoubleToString(profit,2)
            + " selected=" + BoolToText(selected)
            + " symbolMatch=" + BoolToText(symbolMatch)
            + " magicMatch=" + BoolToText(magicMatch)
            + " accepted=" + BoolToText(accepted)
            + " rejectReason=" + rejectReason);
   }

   return accepted;
}


void Stage15_ManageTicket(ulong ticket)
{
   if(!UseStage15SmartDynamicExitEngine || !Stage15_ManageOpenPositions) return;
   string v10RejectReason = "";
   if(!V10_ShouldAcceptPosition(ticket, -1, v10RejectReason))
   {
      AuditV4("[V10_FLOW_CONNECTED] ticket=" + UlongToText(ticket) + " accepted=false reason=" + v10RejectReason);
      return;
   }

   UpdateTicketExitStateV4(ticket);
   int stateIdx = EnsureTicketExitStateV4(ticket);

   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   string role = GetRoleForTicketV4(ticket);
   double open = PositionGetDouble(POSITION_PRICE_OPEN);
   double volume = PositionGetDouble(POSITION_VOLUME);
   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double price = (type == POSITION_TYPE_BUY ? bid : ask);
   double atrBase = MathMax(Stage15_ATRPoints(), 1.0);
   double profitPoints = (type == POSITION_TYPE_BUY ? (price - open) : (open - price)) / _Point;
   double profitMoney = CurrentPositionProfitMoneyV4(ticket);
   double mfeMoney = GetTicketExitPeakMoneyV4(ticket);
   double maeMoney = Stage15_GetTicketMAEMoneyV10(ticket);
   datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
   int age = (int)(TimeCurrent() - openTime);
   int barsAlive = 0;
   int openBarShift = iBarShift(_Symbol, _Period, openTime, false);
   if(openBarShift >= 0) barsAlive = openBarShift;
   double exitScore = Stage15_ExitScore(ticket);
   g_stage15LastExitScore = exitScore;

   int minHold = Stage15_MinHoldMainSeconds;
   if(role == "LAYER_1") minHold = Stage15_MinHoldLayerSeconds;
   if(role == "RUNNER") minHold = Stage15_MinHoldRunnerSeconds;

   double profitAtr = 0.0;
   if(atrBase > 0.0)
      profitAtr = profitPoints / atrBase;

   bool confirmedReversal = Stage15_IsConfirmedReversal(ticket, type);
   bool healthyPullback = Stage15_IsHealthyPullback(ticket, type);
   bool severeReversal = IsSevereReversalV4(ticket, type);
   bool trendAlive = Stage15_IsTrendAliveV10(ticket, type, healthyPullback, confirmedReversal);
   bool m5m15Against = IsM5M15FullyAgainstV4(type);

   int tradeClassID = 0; // 0=WEAK, 1=MODERATE, 2=GOOD, 3=RUNNER, 4=BIG_RUNNER

   bool bigRunnerCandidate = false;
   string bigRunnerCandidateReason = "NONE";
   if(profitMoney >= V10_BigRunnerStartMoney)
   {
      bigRunnerCandidate = true;
      bigRunnerCandidateReason = "PROFIT_GE_V10_BIG_RUNNER_START";
   }
   else if(mfeMoney >= V10_BigRunnerStartMoney)
   {
      bigRunnerCandidate = true;
      bigRunnerCandidateReason = "MFE_GE_V10_BIG_RUNNER_START";
   }
   else if(profitMoney >= Stage15_BigRunnerMinMoney)
   {
      bigRunnerCandidate = true;
      bigRunnerCandidateReason = "PROFIT_GE_STAGE15_BIG_RUNNER_MIN";
   }
   else if(mfeMoney >= Stage15_BigRunnerMinMoney)
   {
      bigRunnerCandidate = true;
      bigRunnerCandidateReason = "MFE_GE_STAGE15_BIG_RUNNER_MIN";
   }

   bool runnerCandidate = false;
   string runnerCandidateReason = "NONE";
   if(role == "RUNNER")
   {
      runnerCandidate = true;
      runnerCandidateReason = "ROLE_RUNNER";
   }
   else if(profitMoney >= V10_RunnerStartMoney)
   {
      runnerCandidate = true;
      runnerCandidateReason = "PROFIT_GE_V10_RUNNER_START";
   }
   else if(mfeMoney >= V10_RunnerStartMoney)
   {
      runnerCandidate = true;
      runnerCandidateReason = "MFE_GE_V10_RUNNER_START";
   }
   else if(profitAtr >= 1.50)
   {
      runnerCandidate = true;
      runnerCandidateReason = "PROFIT_ATR_GE_1_50";
   }
   else if(IsRunnerCandidateV4(ticket, type))
   {
      runnerCandidate = true;
      runnerCandidateReason = "V4_RUNNER_CANDIDATE";
   }

   bool goodCandidate = false;
   string goodReason = "NONE";
   if(profitMoney >= V10_GoodBETriggerMoney)
   {
      goodCandidate = true;
      goodReason = "PROFIT_GE_GOOD_BE_TRIGGER";
   }
   else if(mfeMoney >= V10_GoodLockTriggerMoney)
   {
      goodCandidate = true;
      goodReason = "MFE_GE_GOOD_LOCK_TRIGGER";
   }
   else if(profitAtr >= 1.00)
   {
      goodCandidate = true;
      goodReason = "PROFIT_ATR_GE_1_00";
   }

   bool moderateCandidate = false;
   string moderateReason = "NONE";
   if(profitMoney >= (V10_ModerateBETriggerMoney * 0.50))
   {
      moderateCandidate = true;
      moderateReason = "PROFIT_GE_HALF_MODERATE_BE_TRIGGER";
   }
   else if(mfeMoney >= V10_ModerateBETriggerMoney)
   {
      moderateCandidate = true;
      moderateReason = "MFE_GE_MODERATE_BE_TRIGGER";
   }
   else if(profitPoints >= atrBase * Stage15_BreakEvenTriggerATR)
   {
      moderateCandidate = true;
      moderateReason = "PROFIT_POINTS_GE_BE_ATR_TRIGGER";
   }

   string weakReason = "NONE";
   string runnerReason = "NONE";
   string bigRunnerReason = "NONE";

   if(bigRunnerCandidate)
      bigRunnerReason = bigRunnerCandidateReason + (trendAlive && !severeReversal ? "|TREND_ALIVE_NO_SEVERE_REVERSAL" : (!trendAlive ? "|REJECTED_TREND_NOT_ALIVE" : "|REJECTED_SEVERE_REVERSAL"));
   if(runnerCandidate)
      runnerReason = runnerCandidateReason + (trendAlive && !severeReversal ? "|TREND_ALIVE_NO_SEVERE_REVERSAL" : (!trendAlive ? "|REJECTED_TREND_NOT_ALIVE" : "|REJECTED_SEVERE_REVERSAL"));

   if(bigRunnerCandidate && trendAlive && !severeReversal)
      tradeClassID = 4;
   else if(runnerCandidate && trendAlive && !severeReversal)
      tradeClassID = 3;
   else if(goodCandidate && !severeReversal)
      tradeClassID = 2;
   else if(moderateCandidate)
      tradeClassID = 1;
   else
      tradeClassID = 0;

   if(profitMoney <= 0.0 && mfeMoney < V10_WeakMinMFEToSurvive && (confirmedReversal || m5m15Against || exitScore < Stage15_ExitScoreClose))
   {
      tradeClassID = 0;
      weakReason = "NEGATIVE_OR_FLAT_LOW_MFE_STRUCTURE_OR_SCORE";
   }
   else if(tradeClassID == 0)
   {
      weakReason = "NO_OBJECTIVE_CLASS_CANDIDATE";
   }

   int rawClassID = tradeClassID;
   string rawClass = Stage15_ClassTextV10(rawClassID);

   string tradeClass = Stage15_ClassTextV10(tradeClassID);
   Stage15_UpdateLiveClassV10(ticket, tradeClass, profitMoney, mfeMoney, maeMoney, exitScore, trendAlive, healthyPullback, confirmedReversal, "LIVE_MARKET_RECLASSIFICATION");

   bool breakEvenApplied = false;
   bool lockApplied = false;
   bool trailingApplied = false;
   string classifierAction = "HOLD";
   string reasonFinal = "MANAGE_OPEN_POSITION";

   if(Stage15_DisableFixedServerTP && currentTP > 0.0 && Stage15_CanModifyNow())
   {
      trade.SetExpertMagicNumber((ulong)MagicNumber);
      if(trade.PositionModify(ticket, currentSL, 0.0))
      {
         g_stage15ModifyCount++;
         g_stage15LastModifyTime = TimeCurrent();
         Stage15_Log("SERVER_TP_REMOVED ticket=" + UlongToText(ticket));
      }
   }

   double proposedSL = currentSL;
   string slReason = "";
   double atr = Stage15_ATRPointsForClassV10(tradeClassID);

   // V10 STAGE15 AUDIT-ONLY LOG: prova tick a tick que a checagem de protecao usa mfeMoney
   // (nao profitMoney) e mostra hasBE/hasLOCK antes da tentativa de modificacao abaixo.
   {
      double checkBeTrigger = 0.0;
      double checkLockTrigger = 0.0;
      bool checkShouldProtect = false;
      if(tradeClassID == 1) { checkBeTrigger = V10_ModerateBETriggerMoney; checkLockTrigger = V10_ModerateLockTriggerMoney; checkShouldProtect = (mfeMoney >= checkBeTrigger || mfeMoney >= checkLockTrigger); }
      else if(tradeClassID == 2) { checkBeTrigger = V10_GoodBETriggerMoney; checkLockTrigger = V10_GoodLockTriggerMoney; checkShouldProtect = (mfeMoney >= checkBeTrigger || mfeMoney >= checkLockTrigger); }
      else if(tradeClassID >= 3) { checkBeTrigger = MathMin(V10_RunnerStartMoney, RunnerBreakEvenStartMoneyV4); checkLockTrigger = checkBeTrigger; checkShouldProtect = (mfeMoney >= checkBeTrigger); }

      Stage15_Log("[STAGE15_MFE_PROTECTION_CHECK] ticket=" + UlongToText(ticket)
                + " class=" + tradeClass
                + " profitMoney=" + DoubleToString(profitMoney,2)
                + " mfeMoney=" + DoubleToString(mfeMoney,2)
                + " beTrigger=" + DoubleToString(checkBeTrigger,2)
                + " lockTrigger=" + DoubleToString(checkLockTrigger,2)
                + " hasBE=" + BoolToText(g_v4TicketExitStates[stateIdx].breakEvenActivated)
                + " hasLOCK=" + BoolToText(g_v4TicketExitStates[stateIdx].lockActivated)
                + " shouldProtectByMFE=" + BoolToText(checkShouldProtect));
   }

   // V10 STAGE15 AUDIT FIX: gates trocados de profitMoney (instantaneo) para mfeMoney (pico,
   // nunca cai). Causa raiz do "ganha pequeno perde grande": profitMoney podia cruzar o
   // gatilho e reverter antes do proximo tick reavaliar, deixando o trade promovido
   // (MODERATE/GOOD/RUNNER/BIG_RUNNER via MFE) sem nunca receber o BE/LOCK correspondente,
   // sobrando apenas o SL largo original ate o fim. mfeMoney >= profitMoney sempre, entao
   // todo caso que antes disparava continua disparando â€” isso so adiciona a protecao que faltava.
   if(tradeClassID == 1)
   {
      if(mfeMoney >= V10_ModerateBETriggerMoney)
      {
         if(Stage15_SetProtectedSLByMoneyV10(type, open, volume, 0.50, proposedSL, slReason, "MODERATE_BE_V10"))
         {
            breakEvenApplied = true;
            classifierAction = "APPLY_BE";
         }
      }
      if(mfeMoney >= V10_ModerateLockTriggerMoney)
      {
         if(Stage15_SetProtectedSLByMoneyV10(type, open, volume, V10_ModerateLockProfitMoney, proposedSL, slReason, "MODERATE_LOCK_V10"))
         {
            lockApplied = true;
            classifierAction = "APPLY_LOCK";
         }
      }
   }
   else if(tradeClassID == 2)
   {
      if(mfeMoney >= V10_GoodBETriggerMoney)
      {
         if(Stage15_SetProtectedSLByMoneyV10(type, open, volume, 0.50, proposedSL, slReason, "GOOD_BE_V10"))
         {
            breakEvenApplied = true;
            classifierAction = "APPLY_BE";
         }
      }
      if(mfeMoney >= V10_GoodLockTriggerMoney)
      {
         if(Stage15_SetProtectedSLByMoneyV10(type, open, volume, V10_GoodMinProtectedProfit, proposedSL, slReason, "GOOD_PROTECTED_V10"))
         {
            lockApplied = true;
            classifierAction = "APPLY_LOCK";
         }
      }
   }
   else if(tradeClassID >= 3)
   {
      double runnerLock = MathMax(RunnerBreakEvenLockMoneyV4, V10_GoodMinProtectedProfit);
      if(mfeMoney >= MathMin(V10_RunnerStartMoney, RunnerBreakEvenStartMoneyV4))
      {
         if(Stage15_SetProtectedSLByMoneyV10(type, open, volume, runnerLock, proposedSL, slReason, (tradeClassID == 4 ? "BIG_RUNNER_BE_V10" : "RUNNER_BE_V10")))
         {
            breakEvenApplied = true;
            lockApplied = true;
            classifierAction = "APPLY_RUNNER_BE_LOCK";
         }
      }
   }
   else
   {
      if(profitPoints >= atr * MathMin(Stage15_BreakEvenTriggerATR, 0.45))
      {
         double beSL = (type == POSITION_TYPE_BUY ? open + atr * 0.05 * _Point : open - atr * 0.05 * _Point);
         if(Stage15_IsBetterSL(type, proposedSL, beSL))
         {
            proposedSL = beSL;
            slReason = "WEAK_FAST_BE_V10";
            breakEvenApplied = true;
            classifierAction = "APPLY_WEAK_BE";
         }
      }
   }

   double lockTriggerAtr = Stage15_ProfitLockTriggerATR;
   double lockPercent = Stage15_ProfitLockPercent;
   if(tradeClassID == 1) { lockTriggerAtr = MathMin(Stage15_ProfitLockTriggerATR, 1.00); lockPercent = MathMax(20.0, MathMin(Stage15_ProfitLockPercent, 35.0)); }
   if(tradeClassID == 2) { lockTriggerAtr = MathMin(Stage15_ProfitLockTriggerATR, 1.10); lockPercent = MathMax(25.0, MathMin(Stage15_ProfitLockPercent, 40.0)); }
   if(tradeClassID >= 3) { lockTriggerAtr = MathMin(Stage15_ProfitLockTriggerATR, 1.20); lockPercent = MathMax(25.0, MathMin(Stage15_ProfitLockPercent, 40.0)); }

   if(profitPoints >= atr * lockTriggerAtr && tradeClassID >= 1)
   {
      double lockPoints = profitPoints * (lockPercent / 100.0);
      double lockSL = (type == POSITION_TYPE_BUY ? open + lockPoints * _Point : open - lockPoints * _Point);
      if(Stage15_IsBetterSL(type, proposedSL, lockSL))
      {
         proposedSL = lockSL;
         slReason = "CLASSIFIER_LOCK_" + tradeClass;
         lockApplied = true;
         classifierAction = "APPLY_LOCK";
      }
   }

   if(profitPoints > atr && tradeClassID >= 1)
   {
      double trailMult = Stage15_TrailATRStrong;
      if(tradeClassID == 1) trailMult = Stage15_TrailATRStrong;
      else if(tradeClassID == 2) trailMult = MathMax(Stage15_TrailATRStrong, 2.50);
      else if(tradeClassID == 3)
      {
         trailMult = MathMax(Stage15_RunnerTrailATR, V10_RunnerATRMult);
         if(profitAtr >= 3.0) trailMult = MathMax(trailMult, 4.20);
         if(profitAtr >= 5.0) trailMult = MathMax(trailMult, 4.80);
      }
      else if(tradeClassID == 4)
      {
         trailMult = MathMax(Stage15_BigRunnerTrailATR, V10_BigRunnerATRMult);
         if(profitAtr >= 5.0) trailMult = MathMax(trailMult, 6.00);
         if(profitAtr >= 8.0) trailMult = MathMax(trailMult, 7.00);
      }

      double trailSL = (type == POSITION_TYPE_BUY ? price - atr * trailMult * _Point : price + atr * trailMult * _Point);
      if(Stage15_IsBetterSL(type, proposedSL, trailSL))
      {
         proposedSL = trailSL;
         slReason = "CLASSIFIER_TRAIL_" + tradeClass;
         trailingApplied = true;
         classifierAction = "APPLY_TRAILING";
      }
   }

   bool modifyOk = false;
   if(Stage15_IsBetterSL(type, currentSL, proposedSL))
   {
      modifyOk = Stage15_ModifySL(ticket, proposedSL, slReason, mfeMoney, profitMoney);
      if(modifyOk)
      {
         reasonFinal = slReason;
         if(breakEvenApplied) { g_stage15BECount++; g_v4TicketExitStates[stateIdx].breakEvenActivated = true; }
         if(lockApplied) g_v4TicketExitStates[stateIdx].lockActivated = true;
         if(trailingApplied) { g_stage15TrailCount++; g_v4TicketExitStates[stateIdx].trailingActivated = true; }

         Stage15_Log("[PROTECTION_V10] ticket=" + UlongToText(ticket)
                   + " class=" + tradeClass
                   + " profit=" + DoubleToString(profitMoney,2)
                   + " mfe=" + DoubleToString(mfeMoney,2)
                   + " mae=" + DoubleToString(maeMoney,2)
                   + " oldSL=" + DoubleToString(currentSL,_Digits)
                   + " newSL=" + DoubleToString(proposedSL,_Digits)
                   + " fullProtectionConfirmed=TRUE"
                   + " partialProtectionOnly=FALSE"
                   + " beConfirmed=" + BoolToText(breakEvenApplied)
                   + " lockConfirmed=" + BoolToText(lockApplied)
                   + " trailConfirmed=" + BoolToText(trailingApplied)
                   + " beActive=" + BoolToText(g_v4TicketExitStates[stateIdx].breakEvenActivated)
                   + " lockActive=" + BoolToText(g_v4TicketExitStates[stateIdx].lockActivated)
                   + " trailActive=" + BoolToText(g_v4TicketExitStates[stateIdx].trailingActivated)
                   + " reason=" + slReason);

         if(slReason == "MODERATE_BE_V10") Stage15_Log("[MODERATE_BE_V10] ticket=" + UlongToText(ticket) + " profit=" + DoubleToString(profitMoney,2) + " mfe=" + DoubleToString(mfeMoney,2) + " mae=" + DoubleToString(maeMoney,2) + " oldSL=" + DoubleToString(currentSL,_Digits) + " newSL=" + DoubleToString(proposedSL,_Digits) + " beTrigger=" + DoubleToString(V10_ModerateBETriggerMoney,2) + " reason=" + slReason);
         if(slReason == "MODERATE_LOCK_V10" || slReason == "CLASSIFIER_LOCK_MODERATE") Stage15_Log("[MODERATE_LOCK_V10] ticket=" + UlongToText(ticket) + " profit=" + DoubleToString(profitMoney,2) + " mfe=" + DoubleToString(mfeMoney,2) + " mae=" + DoubleToString(maeMoney,2) + " oldSL=" + DoubleToString(currentSL,_Digits) + " newSL=" + DoubleToString(proposedSL,_Digits) + " lockProfit=" + DoubleToString(V10_ModerateLockProfitMoney,2) + " reason=" + slReason);
         if(tradeClassID == 2) Stage15_Log("[GOOD_PROTECTED_V10] ticket=" + UlongToText(ticket) + " profit=" + DoubleToString(profitMoney,2) + " mfe=" + DoubleToString(mfeMoney,2) + " mae=" + DoubleToString(maeMoney,2) + " beActive=" + BoolToText(g_v4TicketExitStates[stateIdx].breakEvenActivated) + " lockActive=" + BoolToText(g_v4TicketExitStates[stateIdx].lockActivated) + " pullback=" + BoolToText(healthyPullback) + " reversal=" + BoolToText(confirmedReversal) + " reason=" + slReason);
         if(tradeClassID == 3 && trailingApplied) Stage15_Log("[RUNNER_TRAIL_V10] ticket=" + UlongToText(ticket) + " profit=" + DoubleToString(profitMoney,2) + " mfe=" + DoubleToString(mfeMoney,2) + " mae=" + DoubleToString(maeMoney,2) + " atr=" + DoubleToString(atr,1) + " trailDistance=" + DoubleToString(MathAbs(price-proposedSL)/_Point,1) + " oldSL=" + DoubleToString(currentSL,_Digits) + " newSL=" + DoubleToString(proposedSL,_Digits) + " trendAlive=" + BoolToText(trendAlive) + " pullback=" + BoolToText(healthyPullback) + " reversal=" + BoolToText(confirmedReversal) + " reason=" + slReason);
         if(tradeClassID == 4) Stage15_Log("[BIG_RUNNER_HOLD_V10] ticket=" + UlongToText(ticket) + " profit=" + DoubleToString(profitMoney,2) + " mfe=" + DoubleToString(mfeMoney,2) + " mae=" + DoubleToString(maeMoney,2) + " atr=" + DoubleToString(atr,1) + " trailDistance=" + DoubleToString(MathAbs(price-proposedSL)/_Point,1) + " structureAlive=" + BoolToText(!confirmedReversal) + " trendAlive=" + BoolToText(trendAlive) + " pullback=" + BoolToText(healthyPullback) + " reversal=" + BoolToText(confirmedReversal) + " reason=" + slReason);
      }
   }

   bool beActive = g_v4TicketExitStates[stateIdx].breakEvenActivated;
   bool lockActive = g_v4TicketExitStates[stateIdx].lockActivated;
   bool trailActive = g_v4TicketExitStates[stateIdx].trailingActivated;

   bool runnerHoldBlockedNoMFE = ((tradeClassID == 3 || tradeClassID == 4)
                                  && profitMoney < 0.0
                                  && mfeMoney <= 0.0
                                  && trendAlive
                                  && !severeReversal);
   if(runnerHoldBlockedNoMFE)
   {
      string oldRunnerClass = tradeClass;
      tradeClassID = 0;
      tradeClass = Stage15_ClassTextV10(tradeClassID);
      Stage15_Log("[RUNNER_HOLD_BLOCKED_NO_MFE_V10] ticket=" + UlongToText(ticket)
                + " class=" + oldRunnerClass
                + " profit=" + DoubleToString(profitMoney,2)
                + " mfe=" + DoubleToString(mfeMoney,2)
                + " mae=" + DoubleToString(maeMoney,2)
                + " trendAlive=" + BoolToText(trendAlive)
                + " pullback=" + BoolToText(healthyPullback)
                + " reversal=" + BoolToText(confirmedReversal)
                + " reason=NEGATIVE_TRADE_WITH_ZERO_MFE_CANNOT_BE_HELD_AS_RUNNER");
      Stage15_Log("[RUNNER_FALSE_DOWNGRADE_V10] ticket=" + UlongToText(ticket)
                + " oldClass=" + oldRunnerClass
                + " newClass=" + tradeClass
                + " profit=" + DoubleToString(profitMoney,2)
                + " mfe=" + DoubleToString(mfeMoney,2)
                + " mae=" + DoubleToString(maeMoney,2)
                + " reason=RUNNER_WITHOUT_OWN_MFE_PROOF");
      if(oldRunnerClass == "BIG_RUNNER")
      {
         Stage15_Log("[STAGE15_BIG_RUNNER_PROMOTION_REJECTED_V10] ticket=" + UlongToText(ticket)
                   + " attemptedClass=" + oldRunnerClass
                   + " reason=NEGATIVE_TRADE_WITH_ZERO_MFE_CANNOT_BE_BIG_RUNNER"
                   + " profitMoney=" + DoubleToString(profitMoney,2)
                   + " mfeMoney=" + DoubleToString(mfeMoney,2)
                   + " protectionConfirmed=" + BoolToText(beActive || lockActive || trailActive)
                   + " trendAlive=" + BoolToText(trendAlive));
      }
      else
      {
         Stage15_Log("[STAGE15_RUNNER_PROMOTION_REJECTED_V10] ticket=" + UlongToText(ticket)
                   + " attemptedClass=" + oldRunnerClass
                   + " reason=NEGATIVE_TRADE_WITH_ZERO_MFE_CANNOT_BE_RUNNER"
                   + " profitMoney=" + DoubleToString(profitMoney,2)
                   + " mfeMoney=" + DoubleToString(mfeMoney,2)
                   + " protectionConfirmed=" + BoolToText(beActive || lockActive || trailActive)
                   + " trendAlive=" + BoolToText(trendAlive));
      }
      Stage15_UpdateLiveClassV10(ticket, tradeClass, profitMoney, mfeMoney, maeMoney, exitScore, trendAlive, healthyPullback, confirmedReversal, "RUNNER_WITHOUT_OWN_MFE_PROOF");
      weakReason = "RUNNER_WITHOUT_OWN_MFE_PROOF";
      runnerReason = runnerReason + "|FINAL_REJECTED_NO_OWN_MFE";
   }

   Stage15_LogClassDecisionV10(ticket,
                               rawClass,
                               tradeClass,
                               profitMoney,
                               mfeMoney,
                               maeMoney,
                               age,
                               barsAlive,
                               trendAlive,
                               healthyPullback,
                               confirmedReversal,
                               severeReversal,
                               role,
                               runnerCandidate,
                               runnerCandidateReason,
                               bigRunnerCandidate,
                               (beActive || lockActive || trailActive),
                               beActive,
                               lockActive,
                               trailActive,
                               weakReason,
                               moderateReason,
                               goodReason,
                               runnerReason,
                               bigRunnerReason);

   if(Stage15_EnableCatastrophicSingleTradeGuard && profitMoney <= Stage15_CatastrophicLossMoney)
   {
      bool wasEverGood = (mfeMoney >= V10_GoodLockTriggerMoney || tradeClassID >= 2);
      bool wasEverRunner = (role == "RUNNER" || g_v4TicketExitStates[stateIdx].isRunner || mfeMoney >= V10_RunnerStartMoney || tradeClassID == 3 || tradeClassID == 4);
      bool wasEverBigRunner = (mfeMoney >= V10_BigRunnerStartMoney || tradeClassID == 4);
      bool runnerProtected = (tradeClassID == 3 || tradeClassID == 4 || wasEverRunner || wasEverBigRunner || mfeMoney >= Stage15_CatastrophicRunnerSafeMFE || trailActive);
      bool serverSLValid = (currentSL > 0.0 && (type == POSITION_TYPE_BUY ? currentSL < bid : currentSL > ask));
      bool runnerUnprotectedAudit = (runnerProtected && !beActive && !lockActive && !trailActive && !serverSLValid);
      bool failedStructure = (confirmedReversal || m5m15Against || !trendAlive || exitScore < Stage15_ExitScoreClose);
      string catastrophicRegimeReason = "";
      string catastrophicMarketRegime = HorseMarketRegimeToText(HorseDetectMarketRegime(catastrophicRegimeReason));
      bool hasEnoughDataToClose = (stateIdx >= 0 && age >= Stage15_CatastrophicMinSecondsInTrade && failedStructure);
      bool isBadFailedTrade = (profitMoney <= Stage15_CatastrophicLossMoney
                               && mfeMoney < Stage15_CatastrophicMaxMFEToClose
                               && age >= Stage15_CatastrophicMinSecondsInTrade
                               && tradeClassID != 3
                               && tradeClassID != 4
                               && !wasEverGood
                               && !wasEverRunner
                               && !wasEverBigRunner
                               && !trailActive
                               && !beActive
                               && !lockActive
                               && mfeMoney < Stage15_CatastrophicRunnerSafeMFE
                               && failedStructure);

      Stage15_Log("[CATASTROPHIC_LOSS_AUDIT] ticket=" + UlongToText(ticket)
                + " symbol=" + _Symbol
                + " direction=" + (type == POSITION_TYPE_BUY ? "BUY" : "SELL")
                + " openTime=" + TimeToString(openTime, TIME_DATE | TIME_SECONDS)
                + " currentTime=" + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS)
                + " timeInTradeSec=" + IntegerToString(age)
                + " profitMoney=" + DoubleToString(profitMoney,2)
                + " mfeMoney=" + DoubleToString(mfeMoney,2)
                + " maeMoney=" + DoubleToString(maeMoney,2)
                + " entryPrice=" + DoubleToString(open,_Digits)
                + " currentPrice=" + DoubleToString(price,_Digits)
                + " sl=" + DoubleToString(currentSL,_Digits)
                + " tp=" + DoubleToString(currentTP,_Digits)
                + " tradeClass=" + tradeClass
                + " wasEverGood=" + BoolToText(wasEverGood)
                + " wasEverRunner=" + BoolToText(wasEverRunner)
                + " wasEverBigRunner=" + BoolToText(wasEverBigRunner)
                + " beApplied=" + BoolToText(beActive)
                + " lockApplied=" + BoolToText(lockActive)
                + " trailingApplied=" + BoolToText(trailActive)
                + " serverSLValid=" + BoolToText(serverSLValid)
                + " runnerUnprotectedAudit=" + BoolToText(runnerUnprotectedAudit)
                + " m5Trend=" + (m5m15Against ? "AGAINST" : "NOT_FULLY_AGAINST")
                + " marketRegime=" + catastrophicMarketRegime
                + " spreadPoints=" + IntegerToString(GetCurrentSpreadPoints())
                + " atrM1=" + DoubleToString(g_atrM1Points,1)
                + " atrM5=" + DoubleToString(g_atrM5Points,1)
                + " basketProfit=" + DoubleToString(g_basket.netProfit,2)
                + " closeAllowed=" + BoolToText(isBadFailedTrade)
                + " closeBlockedReason=" + (runnerProtected ? "RUNNER_OR_HIGH_MFE_PROTECTED" : (!hasEnoughDataToClose ? "INSUFFICIENT_DATA_TO_CLOSE_SAFELY" : (isBadFailedTrade ? "NONE" : "FAILED_TRADE_NOT_PROVEN"))));

      Stage15_Log("[CATASTROPHIC_GUARD_AUDIT] ticket=" + UlongToText(ticket)
                + " profit=" + DoubleToString(profitMoney,2)
                + " mfe=" + DoubleToString(mfeMoney,2)
                + " mae=" + DoubleToString(maeMoney,2)
                + " tradeClass=" + tradeClass
                + " wasEverGood=" + BoolToText(wasEverGood)
                + " wasEverRunner=" + BoolToText(wasEverRunner)
                + " wasEverBigRunner=" + BoolToText(wasEverBigRunner)
                + " timeInTradeSec=" + IntegerToString(age)
                + " trailingApplied=" + BoolToText(trailActive)
                + " beApplied=" + BoolToText(beActive)
                + " lockApplied=" + BoolToText(lockActive)
                + " serverSLValid=" + BoolToText(serverSLValid)
                + " runnerUnprotectedAudit=" + BoolToText(runnerUnprotectedAudit)
                + " m5Trend=" + (m5m15Against ? "AGAINST" : "NOT_FULLY_AGAINST")
                + " marketRegime=" + catastrophicMarketRegime
                + " isRunnerProtected=" + BoolToText(runnerProtected)
                + " isBadFailedTrade=" + BoolToText(isBadFailedTrade)
                + " decision=" + (isBadFailedTrade ? "CLOSE" : "SKIP")
                + " reason=" + (runnerProtected ? "RUNNER_OR_HIGH_MFE_PROTECTED" : (!hasEnoughDataToClose ? "INSUFFICIENT_DATA_TO_CLOSE_SAFELY" : (isBadFailedTrade ? "FAILED_TRADE_CATASTROPHIC_LOSS" : "FAILED_TRADE_NOT_PROVEN"))));

      if(runnerProtected)
      {
         if(runnerUnprotectedAudit)
         {
            Stage15_Log("[STAGE15_RUNNER_UNPROTECTED] ticket=" + UlongToText(ticket)
                      + " tradeClass=" + tradeClass
                      + " profit=" + DoubleToString(profitMoney,2)
                      + " mfe=" + DoubleToString(mfeMoney,2)
                      + " mae=" + DoubleToString(maeMoney,2)
                      + " serverSL=" + DoubleToString(currentSL,_Digits)
                      + " trailingApplied=" + BoolToText(trailActive)
                      + " beApplied=" + BoolToText(beActive)
                      + " lockApplied=" + BoolToText(lockActive)
                      + " reason=RUNNER_CLASS_BUT_NO_REAL_SL_PROTECTION");
            Stage15_Log("[CATASTROPHIC_GUARD_RUNNER_UNPROTECTED] ticket=" + UlongToText(ticket)
                      + " tradeClass=" + tradeClass
                      + " profit=" + DoubleToString(profitMoney,2)
                      + " mfe=" + DoubleToString(mfeMoney,2)
                      + " mae=" + DoubleToString(maeMoney,2)
                      + " serverSL=" + DoubleToString(currentSL,_Digits)
                      + " isRunnerProtected=" + BoolToText(runnerProtected)
                      + " reason=RUNNER_OR_BIG_RUNNER_WITHOUT_REAL_SL_PROTECTION");
            Stage15_Log("[RUNNER_UNPROTECTED_AUDIT] ticket=" + UlongToText(ticket)
                      + " profit=" + DoubleToString(profitMoney,2)
                      + " mfe=" + DoubleToString(mfeMoney,2)
                      + " tradeClass=" + tradeClass
                      + " currentSL=" + DoubleToString(currentSL,_Digits)
                      + " beActive=" + BoolToText(beActive)
                      + " lockActive=" + BoolToText(lockActive)
                      + " trailActive=" + BoolToText(trailActive)
                      + " serverSLValid=" + BoolToText(serverSLValid)
                      + " catastrophicDecisionStill=SKIP_AUDIT_ONLY");
         }
         Stage15_Log("[CATASTROPHIC_GUARD_SKIP_RUNNER] ticket=" + UlongToText(ticket)
                   + " profit=" + DoubleToString(profitMoney,2)
                   + " mfe=" + DoubleToString(mfeMoney,2)
                   + " tradeClass=" + tradeClass
                   + " reason=RUNNER_OR_HIGH_MFE_PROTECTED");
      }
      else if(!hasEnoughDataToClose)
      {
         Stage15_Log("[CATASTROPHIC_GUARD_UNCERTAIN_SKIP] ticket=" + UlongToText(ticket)
                   + " profit=" + DoubleToString(profitMoney,2)
                   + " mfe=" + DoubleToString(mfeMoney,2)
                   + " tradeClass=" + tradeClass
                   + " reason=INSUFFICIENT_DATA_TO_CLOSE_SAFELY");
      }
      else if(isBadFailedTrade)
      {
         string catastrophicReason = "HARD_RISK_CATASTROPHIC_GUARD_CLOSE_V10";
         Stage15_Log("[CATASTROPHIC_GUARD_CLOSE] ticket=" + UlongToText(ticket)
                   + " profit=" + DoubleToString(profitMoney,2)
                   + " mfe=" + DoubleToString(mfeMoney,2)
                   + " mae=" + DoubleToString(maeMoney,2)
                   + " tradeClass=" + tradeClass
                   + " timeInTradeSec=" + IntegerToString(age)
                   + " reason=FAILED_TRADE_CATASTROPHIC_LOSS");
         Stage15_LogExitAuthorityV10(ticket, tradeClass, profitMoney, mfeMoney, maeMoney, beActive, lockActive, trailActive, "CATASTROPHIC_GUARD", true, catastrophicReason, "Stage15_ManageTicket");
         ClosePositionV4(ticket, catastrophicReason);
         return;
      }
      else
      {
         Stage15_Log("[CATASTROPHIC_GUARD_SKIP] ticket=" + UlongToText(ticket)
                   + " profit=" + DoubleToString(profitMoney,2)
                   + " mfe=" + DoubleToString(mfeMoney,2)
                   + " tradeClass=" + tradeClass
                   + " reason=FAILED_TRADE_NOT_PROVEN");
      }
   }

   bool weakLossLimit = (profitMoney <= -V10_WeakMaxLossMoney && mfeMoney < V10_WeakMinMFEToSurvive);
   bool weakNoConfirm = (age >= V10_WeakMaxSecondsNoConfirm && mfeMoney < V10_WeakMinMFEToSurvive && profitMoney <= 0.0 && !trendAlive);
   bool weakScoreDead = (exitScore < Stage15_ExitScoreClose && profitMoney <= 0.0 && mfeMoney < V10_WeakMinMFEToSurvive && (confirmedReversal || m5m15Against));
   if(V10_EnableLiveExitClassification && Stage15_CloseWeakTrades && tradeClassID == 0 && (weakLossLimit || weakNoConfirm || weakScoreDead))
   {
      string weakReason = "WEAK_CUT_V10";
      if(weakLossLimit) weakReason = "WEAK_CUT_V10_MAX_LOSS";
      else if(weakNoConfirm) weakReason = "WEAK_CUT_V10_NO_CONFIRM";
      else if(weakScoreDead) weakReason = "WEAK_CUT_V10_SCORE_DEAD";
      g_stage15WeakExitRequests++;
      Stage15_Log("[WEAK_CUT_V10] ticket=" + UlongToText(ticket)
                + " profit=" + DoubleToString(profitMoney,2)
                + " mfe=" + DoubleToString(mfeMoney,2)
                + " mae=" + DoubleToString(maeMoney,2)
                + " score=" + DoubleToString(exitScore,1)
                + " ageSeconds=" + IntegerToString(age)
                + " reason=" + weakReason
                + " authorizedBy=Stage15_ManageTicket");
      Stage15_LogExitAuthorityV10(ticket, tradeClass, profitMoney, mfeMoney, maeMoney, beActive, lockActive, trailActive, "WEAK_CUT", true, weakReason, "Stage15_ManageTicket");
      ClosePositionV4(ticket, weakReason);
      return;
   }

   // V10 STAGE15 AUDIT FIX: rede de seguranca para o "zumbi promovido". Um trade so chega aqui
   // (tradeClassID>=1, ou seja, foi promovido por ter tocado um MFE de MODERATE/GOOD/RUNNER/
   // BIG_RUNNER) e ainda assim NUNCA recebeu BE nem LOCK (ex.: gap/slippage que invalidou o
   // PositionModify no exato tick do pico). Sem essa rede, esse trade fica "preso" fora do
   // corte de WEAK e cavalga o SL largo original ate uma perda grande. Um runner saudavel
   // protegido normalmente (beActive/lockActive=true) nunca cai aqui.
   bool stage15GhostPromotion = (tradeClassID >= 1 && !beActive && !lockActive
                                 && profitMoney <= -V10_WeakMaxLossMoney
                                 && (confirmedReversal || m5m15Against));
   if(V10_EnableLiveExitClassification && Stage15_CloseWeakTrades && stage15GhostPromotion)
   {
      string ghostReason = "WEAK_CUT_V10_GHOST_PROMOTION";
      g_stage15WeakExitRequests++;
      Stage15_Log("[WEAK_CUT_V10] ticket=" + UlongToText(ticket)
                + " profit=" + DoubleToString(profitMoney,2)
                + " mfe=" + DoubleToString(mfeMoney,2)
                + " mae=" + DoubleToString(maeMoney,2)
                + " score=" + DoubleToString(exitScore,1)
                + " ageSeconds=" + IntegerToString(age)
                + " reason=" + ghostReason
                + " authorizedBy=Stage15_ManageTicket");
      Stage15_LogExitAuthorityV10(ticket, tradeClass, profitMoney, mfeMoney, maeMoney, beActive, lockActive, trailActive, "WEAK_CUT_GHOST", true, ghostReason, "Stage15_ManageTicket");
      // V10 STAGE15 AUDIT-ONLY LOG: tag dedicada para isolar eventos de ghost-promotion no Journal
      // sem precisar fazer parsing do campo reason= dentro do [WEAK_CUT_V10].
      Stage15_Log("[GHOST_PROMOTION_CUT] ticket=" + UlongToText(ticket)
                + " class=" + tradeClass
                + " mfeMoney=" + DoubleToString(mfeMoney,2)
                + " profitMoney=" + DoubleToString(profitMoney,2)
                + " hasBE=" + BoolToText(beActive)
                + " hasLOCK=" + BoolToText(lockActive)
                + " weakMaxLoss=" + DoubleToString(V10_WeakMaxLossMoney,2)
                + " reversalConfirmed=" + BoolToText(confirmedReversal || m5m15Against));
      ClosePositionV4(ticket, ghostReason);
      return;
   }

   if(V10_EnableLiveExitClassification && tradeClassID == 1 && age >= minHold && mfeMoney >= V10_ModerateLockTriggerMoney && profitMoney > 0.0 && confirmedReversal && !healthyPullback)
   {
      string modReason = "MODERATE_LOCK_PROTECTED_REVERSAL_V10";
      Stage15_LogExitAuthorityV10(ticket, tradeClass, profitMoney, mfeMoney, maeMoney, beActive, lockActive, trailActive, "MODERATE_PROTECTED_EXIT", true, modReason, "Stage15_ManageTicket");
      ClosePositionV4(ticket, modReason);
      return;
   }

   if(V10_EnableLiveExitClassification && tradeClassID == 2)
   {
      if(healthyPullback && !confirmedReversal)
      {
         Stage15_Log("[GOOD_PROTECTED_V10] ticket=" + UlongToText(ticket) + " profit=" + DoubleToString(profitMoney,2) + " mfe=" + DoubleToString(mfeMoney,2) + " mae=" + DoubleToString(maeMoney,2) + " beActive=" + BoolToText(beActive) + " lockActive=" + BoolToText(lockActive) + " pullback=TRUE reversal=FALSE reason=GOOD_PULLBACK_HOLD");
      }
      else if(mfeMoney >= V10_GoodLockTriggerMoney && profitMoney > 0.0 && confirmedReversal && severeReversal)
      {
         string goodReason = "GOOD_PROTECTED_REVERSAL_V10";
         Stage15_LogExitAuthorityV10(ticket, tradeClass, profitMoney, mfeMoney, maeMoney, beActive, lockActive, trailActive, "GOOD_PROTECTED_EXIT", true, goodReason, "Stage15_ManageTicket");
         ClosePositionV4(ticket, goodReason);
         return;
      }
   }

   if(tradeClassID == 3)
   {
      Stage15_Log("[RUNNER_HOLD_V10] ticket=" + UlongToText(ticket)
                + " profit=" + DoubleToString(profitMoney,2)
                + " mfe=" + DoubleToString(mfeMoney,2)
                + " mae=" + DoubleToString(maeMoney,2)
                + " pullback=" + BoolToText(healthyPullback)
                + " reversal=" + BoolToText(confirmedReversal)
                + " trendAlive=" + BoolToText(trendAlive)
                + " blockedCloseReason=" + (trendAlive && !severeReversal ? "RUNNER_HOLD_TREND_ALIVE" : "RUNNER_WAIT_CONFIRMED_EXIT"));

      double givebackPct = 0.0;
      if(mfeMoney > 0.0) givebackPct = ((mfeMoney - profitMoney) / MathMax(0.01, mfeMoney)) * 100.0;
      if(mfeMoney >= V10_RunnerStartMoney && givebackPct >= V10_MaxGivebackPercentRunner && confirmedReversal && severeReversal && !trendAlive)
      {
         string runReason = "RUNNER_CONFIRMED_REVERSAL_GIVEBACK_V10";
         Stage15_LogExitAuthorityV10(ticket, tradeClass, profitMoney, mfeMoney, maeMoney, beActive, lockActive, trailActive, "RUNNER_EXIT", true, runReason, "Stage15_ManageTicket");
         ClosePositionV4(ticket, runReason);
         return;
      }
      return;
   }

   if(tradeClassID == 4)
   {
      Stage15_Log("[BIG_RUNNER_HOLD_V10] ticket=" + UlongToText(ticket)
                + " profit=" + DoubleToString(profitMoney,2)
                + " mfe=" + DoubleToString(mfeMoney,2)
                + " mae=" + DoubleToString(maeMoney,2)
                + " atr=" + DoubleToString(atr,1)
                + " trailDistance=" + DoubleToString((proposedSL > 0.0 ? MathAbs(price-proposedSL)/_Point : 0.0),1)
                + " structureAlive=" + BoolToText(!confirmedReversal)
                + " trendAlive=" + BoolToText(trendAlive)
                + " pullback=" + BoolToText(healthyPullback)
                + " reversal=" + BoolToText(confirmedReversal)
                + " reason=BIG_RUNNER_EXCEPTION_HOLD");

      double bigGivebackPct = 0.0;
      if(mfeMoney > 0.0) bigGivebackPct = ((mfeMoney - profitMoney) / MathMax(0.01, mfeMoney)) * 100.0;
      if(mfeMoney >= V10_BigRunnerStartMoney && bigGivebackPct >= V10_MaxGivebackPercentBigRunner && confirmedReversal && severeReversal && m5m15Against && !trendAlive)
      {
         string bigReason = "BIG_RUNNER_EXIT_CONFIRMED_TREND_END_V10";
         double captureEfficiency = (mfeMoney > 0.0 ? (profitMoney / mfeMoney) * 100.0 : 0.0);
         Stage15_Log("[BIG_RUNNER_EXIT_V10] ticket=" + UlongToText(ticket) + " profit=" + DoubleToString(profitMoney,2) + " mfe=" + DoubleToString(mfeMoney,2) + " mae=" + DoubleToString(maeMoney,2) + " captureEfficiency=" + DoubleToString(captureEfficiency,1) + " exitReason=" + bigReason + " authorizedBy=Stage15_ManageTicket");
         Stage15_LogExitAuthorityV10(ticket, tradeClass, profitMoney, mfeMoney, maeMoney, beActive, lockActive, trailActive, "BIG_RUNNER_EXIT", true, bigReason, "Stage15_ManageTicket");
         ClosePositionV4(ticket, bigReason);
         return;
      }
      return;
   }

   if(Stage15_TimeExitEnabled && age >= Stage15_MaxNoProgressSeconds && profitMoney < Stage15_MinProfitForWeakClose && tradeClassID == 0)
   {
      g_stage15TimeExitRequests++;
      Stage15_Log("[TRADE_EXIT_CLASSIFIER_V10] ticket=" + UlongToText(ticket) + " profit=" + DoubleToString(profitMoney,2) + " tradeClass=" + tradeClass + " action=TIME_EXIT reasonFinal=NO_PROGRESS_TIME_EXIT");
      Stage15_LogExitAuthorityV10(ticket, tradeClass, profitMoney, mfeMoney, maeMoney, beActive, lockActive, trailActive, "TIME_EXIT", true, "STAGE15_TIME_NO_PROGRESS_EXIT", "Stage15_ManageTicket");
      ClosePositionV4(ticket, "STAGE15_TIME_NO_PROGRESS_EXIT");
      return;
   }

   Stage15_Log("[TRADE_EXIT_CLASSIFIER_V10] ticket=" + UlongToText(ticket)
             + " profit=" + DoubleToString(profitMoney,2)
             + " mfe=" + DoubleToString(mfeMoney,2)
             + " mae=" + DoubleToString(maeMoney,2)
             + " tradeClass=" + tradeClass
             + " action=" + classifierAction
             + " breakEvenApplied=" + BoolToText(breakEvenApplied)
             + " lockApplied=" + BoolToText(lockApplied)
             + " trailingApplied=" + BoolToText(trailingApplied)
             + " trendAlive=" + BoolToText(trendAlive)
             + " pullback=" + BoolToText(healthyPullback)
             + " reversal=" + BoolToText(confirmedReversal)
             + " reasonFinal=" + reasonFinal);
}

void V10_LogFlowConnected(ulong ticket, bool stage15Called, bool exitAuthorityCalled, bool protectionChecked, bool oldSmartExitBlocked)
{
   if(!V10_LogEveryManagedTicket) return;
   if(!PositionSelectByTicket(ticket)) return;
   int idx = EnsureTicketExitStateV4(ticket);
   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   string typeText = (type == POSITION_TYPE_BUY ? "BUY" : "SELL");
   double profit = CurrentPositionProfitMoneyV4(ticket);
   double mfe = GetTicketExitPeakMoneyV4(ticket);
   double mae = Stage15_GetTicketMAEMoneyV10(ticket);
   AuditV4("[V10_FLOW_CONNECTED] ticket=" + UlongToText(ticket)
         + " symbol=" + PositionGetString(POSITION_SYMBOL)
         + " type=" + typeText
         + " profit=" + DoubleToString(profit,2)
         + " mfe=" + DoubleToString(mfe,2)
         + " mae=" + DoubleToString(mae,2)
         + " class=" + g_v4TicketExitStates[idx].liveExitClass
         + " stage15Called=" + BoolToText(stage15Called)
         + " exitAuthorityCalled=" + BoolToText(exitAuthorityCalled)
         + " protectionChecked=" + BoolToText(protectionChecked)
         + " oldSmartExitBlocked=" + BoolToText(oldSmartExitBlocked));
}

void V10_ManageAllOpenPositions()
{
   if(!V10_ForceRealFlowIntegration) return;
   if(!UseStage15SmartDynamicExitEngine || !Stage15_ManageOpenPositions)
   {
      AuditV4("[V10_FLOW_CONNECTED] active=false reason=STAGE15_DISABLED_OR_MANAGE_POSITIONS_DISABLED");
      return;
   }

   RemoveClosedTicketExitStatesV4();

   int managed = 0;
   int scanned = 0;
   int rejected = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      scanned++;

      string rejectReason = "";
      if(!V10_ShouldAcceptPosition(ticket, i, rejectReason))
      {
         rejected++;
         continue;
      }

      UpdateTicketExitStateV4(ticket);
      V10_LogFlowConnected(ticket, true, true, true, false);
      Stage15_ManageTicket(ticket);
      managed++;
   }

   AuditV4("[V10_FLOW_CONNECTED] managedPositions=" + IntegerToString(managed)
         + " scannedPositions=" + IntegerToString(scanned)
         + " rejectedPositions=" + IntegerToString(rejected)
         + " reason=" + (managed > 0 ? "V10_MANAGING_REAL_TICKETS" : "NO_ACCEPTED_POSITION_FOR_SYMBOL_MAGIC"));
}

void Stage15_OnTick()
{
   V10_ManageAllOpenPositions();
}


// ================================================================
// V10 TRADE TRANSACTION INTEGRATION PATCH
// Objetivo: capturar tickets reais no evento de trade, nÃ£o apenas via PositionsTotal() no OnTick.
// EvidÃªncia: log anterior mostrava [V10_FLOW_CONNECTED] managedPositions=0 scannedPositions=0
// mesmo com centenas de negociaÃ§Ãµes no Strategy Tester.
// ================================================================
string V10_DealEntryText(long entry)
{
   if(entry == DEAL_ENTRY_IN) return "DEAL_ENTRY_IN";
   if(entry == DEAL_ENTRY_OUT) return "DEAL_ENTRY_OUT";
   if(entry == DEAL_ENTRY_INOUT) return "DEAL_ENTRY_INOUT";
   if(entry == DEAL_ENTRY_OUT_BY) return "DEAL_ENTRY_OUT_BY";
   return "DEAL_ENTRY_UNKNOWN";
}

string V10_DealTypeText(long dealType)
{
   if(dealType == DEAL_TYPE_BUY) return "BUY";
   if(dealType == DEAL_TYPE_SELL) return "SELL";
   if(dealType == DEAL_TYPE_BALANCE) return "BALANCE";
   if(dealType == DEAL_TYPE_CREDIT) return "CREDIT";
   return "OTHER";
}

ulong V10_FindOpenPositionTicketByPositionId(ulong positionId, string symbol, long magic)
{
   if(positionId > 0 && PositionSelectByTicket(positionId))
   {
      string ps = PositionGetString(POSITION_SYMBOL);
      long pm = (long)PositionGetInteger(POSITION_MAGIC);
      if(ps == symbol && V10_IsMagicAccepted(pm))
         return positionId;
   }

   ulong bestTicket = 0;
   datetime bestTime = 0;
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      string ps = PositionGetString(POSITION_SYMBOL);
      long pm = (long)PositionGetInteger(POSITION_MAGIC);
      if(ps != symbol) continue;
      if(!V10_IsMagicAccepted(pm) && pm != magic) continue;
      datetime ot = (datetime)PositionGetInteger(POSITION_TIME);
      if(bestTicket == 0 || ot >= bestTime)
      {
         bestTicket = ticket;
         bestTime = ot;
      }
   }
   return bestTicket;
}

int V10_FindTicketStateByPositionOrTicket(ulong ticket, ulong positionId)
{
   int idx = FindTicketExitStateIndexV4(ticket);
   if(idx >= 0) return idx;
   if(positionId > 0)
   {
      idx = FindTicketExitStateIndexV4(positionId);
      if(idx >= 0) return idx;
   }
   return -1;
}

void V10_RegisterPositionOpened(ulong ticket, ulong deal, ulong positionId, string source)
{
   if(ticket == 0)
   {
      AuditV4("[V10_POSITION_OPENED_CAPTURED] ticket=0 deal=" + UlongToText(deal)
            + " position=" + UlongToText(positionId)
            + " symbol=" + _Symbol
            + " magic=0 type=UNKNOWN price=0.00000 volume=0.00 source=" + source
            + " result=FAILED_NO_TICKET");
      return;
   }

   if(!PositionSelectByTicket(ticket))
   {
      AuditV4("[V10_POSITION_OPENED_CAPTURED] ticket=" + UlongToText(ticket)
            + " deal=" + UlongToText(deal)
            + " position=" + UlongToText(positionId)
            + " symbol=" + _Symbol
            + " magic=0 type=UNKNOWN price=0.00000 volume=0.00 source=" + source
            + " result=FAILED_SELECT_POSITION");
      return;
   }

   int idx = EnsureTicketExitStateV4(ticket);
   UpdateTicketExitStateV4(ticket);

   string symbol = PositionGetString(POSITION_SYMBOL);
   long magic = (long)PositionGetInteger(POSITION_MAGIC);
   long posType = (long)PositionGetInteger(POSITION_TYPE);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double volume = PositionGetDouble(POSITION_VOLUME);
   double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

   g_v4TicketExitStates[idx].symbol = symbol;
   g_v4TicketExitStates[idx].magic = magic;
   g_v4TicketExitStates[idx].lastProfitMoney = profit;
   if(g_v4TicketExitStates[idx].liveExitClass == "" || g_v4TicketExitStates[idx].liveExitClass == "NEW")
      g_v4TicketExitStates[idx].liveExitClass = "WEAK";

   AuditV4("[V10_POSITION_OPENED_CAPTURED] ticket=" + UlongToText(ticket)
         + " deal=" + UlongToText(deal)
         + " position=" + UlongToText(positionId)
         + " symbol=" + symbol
         + " magic=" + IntegerToString((int)magic)
         + " type=" + V10_PositionTypeText(posType)
         + " price=" + DoubleToString(openPrice, _Digits)
         + " volume=" + DoubleToString(volume, 2)
         + " profit=" + DoubleToString(profit, 2)
         + " source=" + source
         + " result=REGISTERED");
}

void V10_ManageTicketNow(ulong ticket, string source)
{
   if(ticket == 0)
   {
      AuditV4("[V10_MANAGE_TICKET_NOW] ticket=0 profit=0.00 mfe=0.00 mae=0.00 class=NONE source=" + source + " result=FAILED_NO_TICKET");
      return;
   }

   if(!PositionSelectByTicket(ticket))
   {
      AuditV4("[V10_MANAGE_TICKET_NOW] ticket=" + UlongToText(ticket)
            + " profit=0.00 mfe=0.00 mae=0.00 class=NONE source=" + source
            + " result=FAILED_POSITION_NOT_SELECTABLE");
      return;
   }

   UpdateTicketExitStateV4(ticket);
   int idx = EnsureTicketExitStateV4(ticket);
   double profit = CurrentPositionProfitMoneyV4(ticket);
   double mfe = GetTicketExitPeakMoneyV4(ticket);
   double mae = Stage15_GetTicketMAEMoneyV10(ticket);
   string cls = g_v4TicketExitStates[idx].liveExitClass;
   if(cls == "" || cls == "NEW" || cls == "NONE")
      cls = V10_FallbackClassByMFE(ticket, profit, mfe);

   AuditV4("[V10_MANAGE_TICKET_NOW] ticket=" + UlongToText(ticket)
         + " profit=" + DoubleToString(profit, 2)
         + " mfe=" + DoubleToString(mfe, 2)
         + " mae=" + DoubleToString(mae, 2)
         + " class=" + cls
         + " source=" + source
         + " result=CALL_STAGE15_MANAGE_TICKET");

   Stage15_ManageTicket(ticket);
}

void V10_PostOrderCapture(ulong resultDeal, ulong resultOrder, string source)
{
   string symbol = _Symbol;
   long magic = MagicNumber;
   ulong positionId = 0;
   long entry = -1;
   double profit = 0.0;

   if(resultDeal > 0 && HistoryDealSelect(resultDeal))
   {
      symbol = HistoryDealGetString(resultDeal, DEAL_SYMBOL);
      magic = (long)HistoryDealGetInteger(resultDeal, DEAL_MAGIC);
      positionId = (ulong)HistoryDealGetInteger(resultDeal, DEAL_POSITION_ID);
      entry = (long)HistoryDealGetInteger(resultDeal, DEAL_ENTRY);
      profit = HistoryDealGetDouble(resultDeal, DEAL_PROFIT);
   }

   ulong ticket = V10_FindOpenPositionTicketByPositionId(positionId, symbol, magic);
   AuditV4("[V10_POST_ORDER_CAPTURE] source=" + source
         + " deal=" + UlongToText(resultDeal)
         + " order=" + UlongToText(resultOrder)
         + " position=" + UlongToText(positionId)
         + " resolvedTicket=" + UlongToText(ticket)
         + " symbol=" + symbol
         + " entry=" + V10_DealEntryText(entry)
         + " profit=" + DoubleToString(profit, 2));

   if(ticket > 0)
   {
      V10_RegisterPositionOpened(ticket, resultDeal, positionId, source + "_POST_ORDER");
      V10_ManageTicketNow(ticket, source + "_POST_ORDER");
   }
}

// ================================================================
// STAGE17 - Adaptive Dual-Side Confirmation Engine
// Cut Weak / Run Strong. This module does not use the legacy hedge
// airbag and does not route pair entry through ExecuteRealOrder().
// ================================================================

void Stage17_UpdatePairState()
{
   if(g_stage17Pair.pairId <= 0)
      return;

   if(g_stage17Pair.pairState == STAGE17_PAIR_FAILED ||
      g_stage17Pair.pairState == STAGE17_PAIR_CLOSED_NO_WINNER ||
      g_stage17Pair.pairState == STAGE17_PAIR_COMPLETED)
      return;

   bool buyOpen = (g_stage17Pair.buyTicket > 0 && PositionSelectByTicket(g_stage17Pair.buyTicket));
   bool sellOpen = (g_stage17Pair.sellTicket > 0 && PositionSelectByTicket(g_stage17Pair.sellTicket));

   if(!buyOpen && !sellOpen)
   {
      g_stage17Pair.pairState = (g_stage17Pair.weakClosed ? STAGE17_PAIR_COMPLETED : STAGE17_PAIR_CLOSED_NO_WINNER);
      return;
   }

   if(g_stage17Pair.weakClosed)
   {
      if(g_stage17Pair.winnerSide == STAGE17_SIDE_BUY && !buyOpen)
         g_stage17Pair.pairState = STAGE17_PAIR_COMPLETED;
      if(g_stage17Pair.winnerSide == STAGE17_SIDE_SELL && !sellOpen)
         g_stage17Pair.pairState = STAGE17_PAIR_COMPLETED;
      return;
   }

   if(buyOpen && sellOpen)
   {
      g_stage17Pair.pairState = STAGE17_PAIR_ACTIVE;
      return;
   }

   g_stage17Pair.decisionMade = true;
   g_stage17Pair.weakClosed = true;
   g_stage17Pair.weakClosedByStage17 = false;
   g_stage17Pair.survivorUnconfirmed = true;
   g_stage17Pair.winnerConfirmed = false;
   if(buyOpen)
   {
      g_stage17Pair.winnerSide = STAGE17_SIDE_BUY;
      g_stage17Pair.loserSide = STAGE17_SIDE_SELL;
   }
   else
   {
      g_stage17Pair.winnerSide = STAGE17_SIDE_SELL;
      g_stage17Pair.loserSide = STAGE17_SIDE_BUY;
   }
   g_stage17Pair.pairState = STAGE17_PAIR_DECIDED_WEAK_CLOSED;

   if(Stage17_DebugLogs)
   {
      ulong survivorTicket = (g_stage17Pair.winnerSide == STAGE17_SIDE_BUY ? g_stage17Pair.buyTicket : g_stage17Pair.sellTicket);
      Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_SURVIVOR_UNCONFIRMED_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
            " ticket=", UlongToText(survivorTicket),
            " winnerSide=", (g_stage17Pair.winnerSide == STAGE17_SIDE_BUY ? "BUY" : "SELL"),
            " survivorUnconfirmed=", BoolToText(g_stage17Pair.survivorUnconfirmed),
            " winnerConfirmed=", BoolToText(g_stage17Pair.winnerConfirmed),
            " rawClass=NONE finalClass=NONE profitMoney=0.00 mfeMoney=0.00 maeMoney=0.00 givebackPct=0.00 basketProfit=0.00",
            " beActive=false lockActive=false realSLConfirmed=false trendAlive=false severeReversal=false",
            " winnerLayer1Opened=", BoolToText(g_stage17Pair.winnerLayer1Opened),
            " winnerLayer1Alive=", BoolToText(g_stage17Pair.winnerLayer1Alive),
            " winnerLayer1Failed=", BoolToText(g_stage17Pair.winnerLayer1Failed),
            " decision=SURVIVOR_ONLY reason=OTHER_SIDE_CLOSED_OUTSIDE_STAGE17_WEAK_CUT");
   }
}

bool Stage17_CanOpenPair()
{
   bool hasActivePair = (g_stage17Pair.pairId > 0 &&
                         (g_stage17Pair.pairState == STAGE17_PAIR_ACTIVE ||
                          g_stage17Pair.pairState == STAGE17_PAIR_DECIDED_WEAK_CLOSED));
   bool allowPair = true;
   string reason = "ALLOW";
   int openPositions = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      openPositions++;
   }

   if(!UseStage17DualSideConfirmation)
   {
      allowPair = false;
      reason = "STAGE17_DISABLED";
   }
   else if(Stage17_MaxActivePairs < 1)
   {
      allowPair = false;
      reason = "MAX_ACTIVE_PAIRS_ZERO";
   }
   else if(hasActivePair)
   {
      allowPair = false;
      reason = "ACTIVE_PAIR_EXISTS";
   }
   else if(g_stage17LastPairOpenTime > 0 && TimeCurrent() - g_stage17LastPairOpenTime < Stage17_MinSecondsBetweenPairs)
   {
      allowPair = false;
      reason = "PAIR_COOLDOWN";
   }
   else if(openPositions > 0)
   {
      allowPair = false;
      reason = "COMMON_POSITION_CONFLICT";
   }
   else if(!g_symbolOK || !g_timeframeOK || !g_environmentOK || !g_securityFiltersOK)
   {
      allowPair = false;
      reason = "CORE_OR_SECURITY_BLOCK";
   }
   else if(!g_mqlTradeAllowed || !g_accountTradeAllowed || !g_liveTradingAllowed)
   {
      allowPair = false;
      reason = "TRADE_PERMISSION_BLOCK";
   }
   else if(g_risk.tradingLocked)
   {
      allowPair = false;
      reason = "RISK_LOCKED";
   }
   else if(Stage17_BlockIfDailyDDAbovePercent > 0.0 && g_risk.dailyDrawdownPercent > Stage17_BlockIfDailyDDAbovePercent)
   {
      allowPair = false;
      reason = "DAILY_DD_BLOCK";
   }
   else if(GetCurrentSpreadPoints() > Stage17_MaxSpreadPoints)
   {
      allowPair = false;
      reason = "SPREAD_HIGH";
   }
   else if(Stage17_BlockInRange && g_market.mode == MARKET_SIDEWAYS)
   {
      allowPair = false;
      reason = "RANGE_BLOCK";
   }
   else if(Stage17_BlockInChoppy && (g_market.mode == MARKET_ERRATIC || g_market.mode == MARKET_SPREAD_DANGER))
   {
      allowPair = false;
      reason = "CHOPPY_OR_DANGER_BLOCK";
   }
   else if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
      allowPair = false;
      reason = "ACCOUNT_NOT_HEDGING";
   }
   else
   {
      double nextExposure = CalculateTotalSymbolExposureLots() + (Stage17_DualSideProbeLot * 2.0);
      if(MaxTotalSymbolExposureLots > 0.0 && nextExposure > MaxTotalSymbolExposureLots + 0.000001)
      {
         allowPair = false;
         reason = "SYMBOL_EXPOSURE_BLOCK";
      }
   }

   if(Stage17_DebugLogs)
      Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_ENTRY_CHECK_V10] symbol=", _Symbol,
            " spread=", IntegerToString(GetCurrentSpreadPoints()),
            " dailyDD=", DoubleToString(g_risk.dailyDrawdownPercent,2),
            " openPositions=", IntegerToString(openPositions),
            " hasActivePair=", BoolToText(hasActivePair),
            " allowPair=", BoolToText(allowPair),
            " reason=", reason);

   return allowPair;
}

bool Stage17_OpenPair()
{
   g_stage17LegacyBlockThisTick = true;
   g_stage17NextPairId++;
   g_stage17Pair.pairId = g_stage17NextPairId;
   g_stage17Pair.buyTicket = 0;
   g_stage17Pair.sellTicket = 0;
   g_stage17Pair.openTime = TimeCurrent();
   g_stage17Pair.pairState = STAGE17_PAIR_ACTIVE;
   g_stage17Pair.winnerSide = STAGE17_SIDE_NONE;
   g_stage17Pair.loserSide = STAGE17_SIDE_NONE;
   g_stage17Pair.decisionMade = false;
   g_stage17Pair.weakClosed = false;
   g_stage17Pair.winnerLayer1Opened = false;
   g_stage17Pair.winnerLayer2Opened = false;
   g_stage17Pair.weakClosedByStage17 = false;
   g_stage17Pair.survivorUnconfirmed = false;
   g_stage17Pair.winnerConfirmed = false;
   g_stage17Pair.winnerLayer1Ticket = 0;
   g_stage17Pair.winnerLayer1Alive = false;
   g_stage17Pair.winnerLayer1Closed = false;
   g_stage17Pair.winnerLayer1Failed = false;
   g_stage17Pair.winnerLayer1Profit = 0.0;
   g_stage17Pair.winnerLayer1MFE = 0.0;
   g_stage17LastPairOpenTime = TimeCurrent();

   double lot = Stage17_DualSideProbeLot;
   double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(minVol <= 0.0) minVol = 0.01;
   if(maxVol < minVol) maxVol = minVol;
   if(step <= 0.0) step = minVol;
   lot = MathMax(minVol, MathMin(maxVol, lot));
   lot = MathFloor(lot / step) * step;
   lot = NormalizeDouble(lot, 2);

   string buyComment = "HORSE DUAL BUY";
   string sellComment = "HORSE DUAL SELL";
   datetime openStarted = TimeCurrent();
   double buyPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sellPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   trade.SetExpertMagicNumber((ulong)MagicNumber);
   trade.SetDeviationInPoints(RealExecutionDeviationPoints);
   ENUM_ORDER_TYPE_FILLING filling = ORDER_FILLING_FOK;
   uint fillingModes = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((fillingModes & SYMBOL_FILLING_IOC) != 0) filling = ORDER_FILLING_IOC;
   if((fillingModes & SYMBOL_FILLING_FOK) != 0) filling = ORDER_FILLING_FOK;
   trade.SetTypeFilling(filling);

   bool buyOk = trade.Buy(lot, _Symbol, 0.0, 0.0, 0.0, buyComment);
   ulong buyOrder = trade.ResultOrder();
   ulong buyDeal = trade.ResultDeal();
   uint buyRetcode = trade.ResultRetcode();

   if(Stage17_DebugLogs)
      Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_ORDER_RESULT_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
            " orderType=PAIR_PROBE side=BUY lot=", DoubleToString(lot,2),
            " success=", BoolToText(buyOk),
            " retcode=", IntegerToString((int)buyRetcode),
            " ticket=", UlongToText(buyOrder),
            " price=", DoubleToString(buyPrice,_Digits),
            " reason=STAGE17_OPEN_PAIR_BUY");

   ulong buyTicket = 0;
   if(buyDeal > 0 && HistoryDealSelect(buyDeal))
   {
      ulong positionId = (ulong)HistoryDealGetInteger(buyDeal, DEAL_POSITION_ID);
      buyTicket = V10_FindOpenPositionTicketByPositionId(positionId, _Symbol, MagicNumber);
   }
   if(buyTicket == 0)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
         if((long)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY) continue;
         if(PositionGetString(POSITION_COMMENT) != buyComment) continue;
         if(MathAbs(PositionGetDouble(POSITION_VOLUME) - lot) > 0.000001) continue;
         if((datetime)PositionGetInteger(POSITION_TIME) < openStarted - 10) continue;
         buyTicket = ticket;
         break;
      }
   }

   if(!buyOk || buyTicket == 0)
   {
      g_stage17Pair.pairState = STAGE17_PAIR_FAILED;
      if(Stage17_DebugLogs)
         Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_ORDER_RESULT_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
               " orderType=PAIR_FAILED side=BUY lot=", DoubleToString(lot,2),
               " success=false retcode=", IntegerToString((int)buyRetcode),
               " ticket=", UlongToText(buyTicket),
               " price=", DoubleToString(buyPrice,_Digits),
               " reason=BUY_NOT_OPENED_OR_NOT_CAPTURED");
      return false;
   }

   bool sellOk = trade.Sell(lot, _Symbol, 0.0, 0.0, 0.0, sellComment);
   ulong sellOrder = trade.ResultOrder();
   ulong sellDeal = trade.ResultDeal();
   uint sellRetcode = trade.ResultRetcode();

   if(Stage17_DebugLogs)
      Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_ORDER_RESULT_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
            " orderType=PAIR_PROBE side=SELL lot=", DoubleToString(lot,2),
            " success=", BoolToText(sellOk),
            " retcode=", IntegerToString((int)sellRetcode),
            " ticket=", UlongToText(sellOrder),
            " price=", DoubleToString(sellPrice,_Digits),
            " reason=STAGE17_OPEN_PAIR_SELL");

   ulong sellTicket = 0;
   if(sellDeal > 0 && HistoryDealSelect(sellDeal))
   {
      ulong positionId = (ulong)HistoryDealGetInteger(sellDeal, DEAL_POSITION_ID);
      sellTicket = V10_FindOpenPositionTicketByPositionId(positionId, _Symbol, MagicNumber);
   }
   if(sellTicket == 0)
   {
      for(int j = PositionsTotal() - 1; j >= 0; j--)
      {
         ulong ticket = PositionGetTicket(j);
         if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
         if((long)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL) continue;
         if(PositionGetString(POSITION_COMMENT) != sellComment) continue;
         if(MathAbs(PositionGetDouble(POSITION_VOLUME) - lot) > 0.000001) continue;
         if((datetime)PositionGetInteger(POSITION_TIME) < openStarted - 10) continue;
         sellTicket = ticket;
         break;
      }
   }

   if(!sellOk || sellTicket == 0)
   {
      bool closeBuy = false;
      if(buyTicket > 0 && PositionSelectByTicket(buyTicket))
         closeBuy = ClosePositionV4(buyTicket, "DUAL_SIDE_PAIR_OPEN_FAILED_V10");
      g_stage17Pair.pairState = STAGE17_PAIR_FAILED;
      if(Stage17_DebugLogs)
         Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_ORDER_RESULT_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
               " orderType=PAIR_FAILED side=SELL lot=", DoubleToString(lot,2),
               " success=false retcode=", IntegerToString((int)sellRetcode),
               " ticket=", UlongToText(sellTicket),
               " price=", DoubleToString(sellPrice,_Digits),
               " reason=SELL_FAILED_BUY_CLOSE_ATTEMPT closeBuySuccess=", BoolToText(closeBuy));
      return false;
   }

   g_stage17Pair.buyTicket = buyTicket;
   g_stage17Pair.sellTicket = sellTicket;

   if(PositionSelectByTicket(buyTicket))
      AssignRoleV4(buyTicket, "MAIN", (datetime)PositionGetInteger(POSITION_TIME), PositionGetDouble(POSITION_PRICE_OPEN), PositionGetDouble(POSITION_VOLUME), "STAGE17_DUAL_PAIR_BUY");
   if(PositionSelectByTicket(sellTicket))
      AssignRoleV4(sellTicket, "MAIN", (datetime)PositionGetInteger(POSITION_TIME), PositionGetDouble(POSITION_PRICE_OPEN), PositionGetDouble(POSITION_VOLUME), "STAGE17_DUAL_PAIR_SELL");

   V10_PostOrderCapture(buyDeal, buyOrder, "Stage17_OpenPair_BUY");
   V10_PostOrderCapture(sellDeal, sellOrder, "Stage17_OpenPair_SELL");

   if(Stage17_DebugLogs)
      Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_PAIR_OPENED_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
            " buyTicket=", UlongToText(buyTicket),
            " sellTicket=", UlongToText(sellTicket),
            " lot=", DoubleToString(lot,2),
            " buyPrice=", DoubleToString(buyPrice,_Digits),
            " sellPrice=", DoubleToString(sellPrice,_Digits),
            " spread=", IntegerToString(GetCurrentSpreadPoints()),
            " reason=BUY_SELL_PROBE_PAIR_OPENED");

   return true;
}

void Stage17_CompareSides()
{
   if(g_stage17Pair.pairId <= 0)
      return;
   if(g_stage17Pair.pairState != STAGE17_PAIR_ACTIVE &&
      g_stage17Pair.pairState != STAGE17_PAIR_DECIDED_WEAK_CLOSED)
      return;

   bool buyOpen = (g_stage17Pair.buyTicket > 0 && PositionSelectByTicket(g_stage17Pair.buyTicket));
   bool sellOpen = (g_stage17Pair.sellTicket > 0 && PositionSelectByTicket(g_stage17Pair.sellTicket));
   if(!buyOpen && !sellOpen)
      return;

   double buyProfit = 0.0, sellProfit = 0.0, buyMFE = 0.0, sellMFE = 0.0, buyMAE = 0.0, sellMAE = 0.0;
   string buyFinal = "NONE", sellFinal = "NONE", buyRaw = "WEAK", sellRaw = "WEAK";
   bool buyTrendAlive = false, sellTrendAlive = false, buySevere = false, sellSevere = false;

   if(buyOpen)
   {
      ulong ticket = g_stage17Pair.buyTicket;
      UpdateTicketExitStateV4(ticket);
      int idx = EnsureTicketExitStateV4(ticket);
      buyProfit = CurrentPositionProfitMoneyV4(ticket);
      buyMFE = GetTicketExitPeakMoneyV4(ticket);
      buyMAE = Stage15_GetTicketMAEMoneyV10(ticket);
      buyFinal = g_v4TicketExitStates[idx].liveExitClass;
      if(buyMFE >= V10_BigRunnerStartMoney || buyProfit >= V10_BigRunnerStartMoney) buyRaw = "BIG_RUNNER";
      else if(buyMFE >= V10_RunnerStartMoney || buyProfit >= V10_RunnerStartMoney) buyRaw = "RUNNER";
      else if(buyMFE >= V10_GoodLockTriggerMoney || buyProfit >= V10_GoodBETriggerMoney) buyRaw = "GOOD";
      else if(buyMFE >= V10_ModerateBETriggerMoney || buyProfit >= (V10_ModerateBETriggerMoney * 0.50)) buyRaw = "MODERATE";
      if(buyFinal == "" || buyFinal == "NEW" || buyFinal == "NONE") buyFinal = buyRaw;
      bool confirmedReversal = Stage15_IsConfirmedReversal(ticket, POSITION_TYPE_BUY);
      bool healthyPullback = Stage15_IsHealthyPullback(ticket, POSITION_TYPE_BUY);
      buySevere = IsSevereReversalV4(ticket, POSITION_TYPE_BUY);
      buyTrendAlive = Stage15_IsTrendAliveV10(ticket, POSITION_TYPE_BUY, healthyPullback, confirmedReversal);
   }

   if(sellOpen)
   {
      ulong ticket = g_stage17Pair.sellTicket;
      UpdateTicketExitStateV4(ticket);
      int idx = EnsureTicketExitStateV4(ticket);
      sellProfit = CurrentPositionProfitMoneyV4(ticket);
      sellMFE = GetTicketExitPeakMoneyV4(ticket);
      sellMAE = Stage15_GetTicketMAEMoneyV10(ticket);
      sellFinal = g_v4TicketExitStates[idx].liveExitClass;
      if(sellMFE >= V10_BigRunnerStartMoney || sellProfit >= V10_BigRunnerStartMoney) sellRaw = "BIG_RUNNER";
      else if(sellMFE >= V10_RunnerStartMoney || sellProfit >= V10_RunnerStartMoney) sellRaw = "RUNNER";
      else if(sellMFE >= V10_GoodLockTriggerMoney || sellProfit >= V10_GoodBETriggerMoney) sellRaw = "GOOD";
      else if(sellMFE >= V10_ModerateBETriggerMoney || sellProfit >= (V10_ModerateBETriggerMoney * 0.50)) sellRaw = "MODERATE";
      if(sellFinal == "" || sellFinal == "NEW" || sellFinal == "NONE") sellFinal = sellRaw;
      bool confirmedReversal = Stage15_IsConfirmedReversal(ticket, POSITION_TYPE_SELL);
      bool healthyPullback = Stage15_IsHealthyPullback(ticket, POSITION_TYPE_SELL);
      sellSevere = IsSevereReversalV4(ticket, POSITION_TYPE_SELL);
      sellTrendAlive = Stage15_IsTrendAliveV10(ticket, POSITION_TYPE_SELL, healthyPullback, confirmedReversal);
   }

   int age = (int)(TimeCurrent() - g_stage17Pair.openTime);
   double basketProfit = buyProfit + sellProfit;
   string decision = "HOLD";
   string reason = "NO_DECISION";

   bool buyWeakClass = (buyFinal == "WEAK");
   bool sellWeakClass = (sellFinal == "WEAK");
   bool buyStrongClass = (buyFinal == "GOOD" || buyFinal == "RUNNER" || buyFinal == "BIG_RUNNER");
   bool sellStrongClass = (sellFinal == "GOOD" || sellFinal == "RUNNER" || sellFinal == "BIG_RUNNER");
   bool buyWeakByLoss = (buyProfit <= Stage17_WeakSideMaxLossMoney);
   bool sellWeakByLoss = (sellProfit <= Stage17_WeakSideMaxLossMoney);
   bool buyNoMFETooLong = (age >= Stage17_WeakSideMaxNoMFESeconds && buyMFE < Stage17_WeakSideMinMFEToSurvive && buyProfit <= 0.0);
   bool sellNoMFETooLong = (age >= Stage17_WeakSideMaxNoMFESeconds && sellMFE < Stage17_WeakSideMinMFEToSurvive && sellProfit <= 0.0);
   bool buyStrong = (buyOpen && buyProfit >= Stage17_StrongSideMinProfitMoney && buyMFE >= Stage17_StrongSideMinMFEMoney && buyStrongClass);
   bool sellStrong = (sellOpen && sellProfit >= Stage17_StrongSideMinProfitMoney && sellMFE >= Stage17_StrongSideMinMFEMoney && sellStrongClass);
   if(Stage17_RequireTrendAliveForWinner)
   {
      buyStrong = (buyStrong && buyTrendAlive);
      sellStrong = (sellStrong && sellTrendAlive);
   }
   if(Stage17_BlockOnSevereReversal)
   {
      buyStrong = (buyStrong && !buySevere);
      sellStrong = (sellStrong && !sellSevere);
   }

   if(Stage17_EnableCloseWeakSide && !g_stage17Pair.weakClosed && buyOpen && sellOpen)
   {
      if(buyWeakClass && (buyWeakByLoss || buyNoMFETooLong || buyMFE <= 0.0) && sellStrong)
      {
         g_stage17Pair.winnerSide = STAGE17_SIDE_SELL;
         g_stage17Pair.loserSide = STAGE17_SIDE_BUY;
         decision = "CUT_BUY_HOLD_SELL";
         reason = "BUY_WEAK_SELL_STRONG";
         Stage17_CloseWeakSide();
      }
      else if(sellWeakClass && (sellWeakByLoss || sellNoMFETooLong || sellMFE <= 0.0) && buyStrong)
      {
         g_stage17Pair.winnerSide = STAGE17_SIDE_BUY;
         g_stage17Pair.loserSide = STAGE17_SIDE_SELL;
         decision = "CUT_SELL_HOLD_BUY";
         reason = "SELL_WEAK_BUY_STRONG";
         Stage17_CloseWeakSide();
      }
   }

   bool bothWeakOrModerate = ((buyFinal == "WEAK" || buyFinal == "MODERATE") &&
                              (sellFinal == "WEAK" || sellFinal == "MODERATE"));
   bool marketBlocked = ((Stage17_BlockInRange && g_market.mode == MARKET_SIDEWAYS) ||
                         (Stage17_BlockInChoppy && (g_market.mode == MARKET_ERRATIC || g_market.mode == MARKET_SPREAD_DANGER)));
   bool riskBlocked = (Stage17_BlockIfDailyDDAbovePercent > 0.0 && g_risk.dailyDrawdownPercent > Stage17_BlockIfDailyDDAbovePercent);
   bool spreadBlocked = (GetCurrentSpreadPoints() > Stage17_MaxSpreadPoints);

   if(Stage17_CloseBothIfNoWinner && !g_stage17Pair.weakClosed && buyOpen && sellOpen)
   {
      bool noWinnerTimeout = (age >= Stage17_CloseBothAfterSeconds && basketProfit <= Stage17_CloseBothIfBasketBelowMoney);
      bool noProgressDecision = (age >= Stage17_MaxDecisionSeconds &&
                                 buyMFE < Stage17_WeakSideMinMFEToSurvive &&
                                 sellMFE < Stage17_WeakSideMinMFEToSurvive &&
                                 bothWeakOrModerate);
      if(noWinnerTimeout || noProgressDecision || marketBlocked || riskBlocked || spreadBlocked)
      {
         decision = "CLOSE_BOTH_NO_WINNER";
         reason = (noWinnerTimeout ? "NO_WINNER_TIMEOUT" : (noProgressDecision ? "NO_PROGRESS_DECISION" : (marketBlocked ? "MARKET_BLOCK" : (riskBlocked ? "RISK_BLOCK" : "SPREAD_BLOCK"))));
         Stage17_CloseBothNoWinner();
      }
   }

   if(Stage17_DebugLogs)
      Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_CLASS_COMPARE_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
            " buyTicket=", UlongToText(g_stage17Pair.buyTicket),
            " sellTicket=", UlongToText(g_stage17Pair.sellTicket),
            " buyProfit=", DoubleToString(buyProfit,2),
            " sellProfit=", DoubleToString(sellProfit,2),
            " buyMFE=", DoubleToString(buyMFE,2),
            " sellMFE=", DoubleToString(sellMFE,2),
            " buyRawClass=", buyRaw,
            " sellRawClass=", sellRaw,
            " buyFinalClass=", buyFinal,
            " sellFinalClass=", sellFinal,
            " buyTrendAlive=", BoolToText(buyTrendAlive),
            " sellTrendAlive=", BoolToText(sellTrendAlive),
            " buySevereReversal=", BoolToText(buySevere),
            " sellSevereReversal=", BoolToText(sellSevere),
            " decision=", decision,
            " reason=", reason);

   if(g_stage17Pair.weakClosed)
   {
      int idx = -1;
      ulong winnerTicket = (g_stage17Pair.winnerSide == STAGE17_SIDE_BUY ? g_stage17Pair.buyTicket : g_stage17Pair.sellTicket);
      double winnerProfit = 0.0, winnerMFE = 0.0;
      string winnerClass = "NONE";
      bool beConfirmed = false, lockConfirmed = false, realSLConfirmed = false, trendAlive = false;
      if(winnerTicket > 0 && PositionSelectByTicket(winnerTicket))
      {
         UpdateTicketExitStateV4(winnerTicket);
         idx = EnsureTicketExitStateV4(winnerTicket);
         winnerProfit = CurrentPositionProfitMoneyV4(winnerTicket);
         winnerMFE = GetTicketExitPeakMoneyV4(winnerTicket);
         winnerClass = g_v4TicketExitStates[idx].liveExitClass;
         beConfirmed = g_v4TicketExitStates[idx].breakEvenActivated;
         lockConfirmed = g_v4TicketExitStates[idx].lockActivated;
         realSLConfirmed = (PositionGetDouble(POSITION_SL) > 0.0);
         ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         bool confirmedReversal = Stage15_IsConfirmedReversal(winnerTicket, pt);
         bool healthyPullback = Stage15_IsHealthyPullback(winnerTicket, pt);
         trendAlive = Stage15_IsTrendAliveV10(winnerTicket, pt, healthyPullback, confirmedReversal);
      }
      if(Stage17_DebugLogs)
         Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_STRONG_SIDE_HOLD_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
               " winnerSide=", (g_stage17Pair.winnerSide == STAGE17_SIDE_BUY ? "BUY" : "SELL"),
               " winnerTicket=", UlongToText(winnerTicket),
               " profit=", DoubleToString(winnerProfit,2),
               " mfe=", DoubleToString(winnerMFE,2),
               " finalClass=", winnerClass,
               " beConfirmed=", BoolToText(beConfirmed),
               " lockConfirmed=", BoolToText(lockConfirmed),
               " realSLConfirmed=", BoolToText(realSLConfirmed),
               " trendAlive=", BoolToText(trendAlive),
               " reason=WINNER_HELD_BY_STAGE17");
   }
}

bool Stage17_CloseWeakSide()
{
   if(g_stage17Pair.pairId <= 0)
      return false;
   if(g_stage17Pair.loserSide != STAGE17_SIDE_BUY && g_stage17Pair.loserSide != STAGE17_SIDE_SELL)
      return false;

   ulong weakTicket = (g_stage17Pair.loserSide == STAGE17_SIDE_BUY ? g_stage17Pair.buyTicket : g_stage17Pair.sellTicket);
   ulong strongTicket = (g_stage17Pair.winnerSide == STAGE17_SIDE_BUY ? g_stage17Pair.buyTicket : g_stage17Pair.sellTicket);
   double weakProfit = 0.0, weakMFE = 0.0, strongProfit = 0.0, strongMFE = 0.0;
   string weakClass = "NONE", strongClass = "NONE";

   if(weakTicket > 0 && PositionSelectByTicket(weakTicket))
   {
      UpdateTicketExitStateV4(weakTicket);
      int idx = EnsureTicketExitStateV4(weakTicket);
      weakProfit = CurrentPositionProfitMoneyV4(weakTicket);
      weakMFE = GetTicketExitPeakMoneyV4(weakTicket);
      weakClass = g_v4TicketExitStates[idx].liveExitClass;
   }
   if(strongTicket > 0 && PositionSelectByTicket(strongTicket))
   {
      UpdateTicketExitStateV4(strongTicket);
      int idx = EnsureTicketExitStateV4(strongTicket);
      strongProfit = CurrentPositionProfitMoneyV4(strongTicket);
      strongMFE = GetTicketExitPeakMoneyV4(strongTicket);
      strongClass = g_v4TicketExitStates[idx].liveExitClass;
   }

   bool closeSuccess = true;
   if(weakTicket > 0 && PositionSelectByTicket(weakTicket))
      closeSuccess = ClosePositionV4(weakTicket, "DUAL_SIDE_WEAK_CUT_V10");

   if(closeSuccess)
   {
      g_stage17Pair.decisionMade = true;
      g_stage17Pair.weakClosed = true;
      g_stage17Pair.weakClosedByStage17 = true;
      g_stage17Pair.survivorUnconfirmed = false;
      g_stage17Pair.winnerConfirmed = false;
      g_stage17Pair.pairState = STAGE17_PAIR_DECIDED_WEAK_CLOSED;
   }

   if(Stage17_DebugLogs)
      Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_WEAK_SIDE_CUT_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
            " weakSide=", (g_stage17Pair.loserSide == STAGE17_SIDE_BUY ? "BUY" : "SELL"),
            " weakTicket=", UlongToText(weakTicket),
            " strongSide=", (g_stage17Pair.winnerSide == STAGE17_SIDE_BUY ? "BUY" : "SELL"),
            " strongTicket=", UlongToText(strongTicket),
            " weakProfit=", DoubleToString(weakProfit,2),
            " weakMFE=", DoubleToString(weakMFE,2),
            " weakFinalClass=", weakClass,
            " strongProfit=", DoubleToString(strongProfit,2),
            " strongMFE=", DoubleToString(strongMFE,2),
            " strongFinalClass=", strongClass,
            " closeSuccess=", BoolToText(closeSuccess),
            " reason=STAGE17_CUT_WEAK_SIDE");

   return closeSuccess;
}

bool Stage17_CloseBothNoWinner()
{
   if(g_stage17Pair.pairId <= 0)
      return false;

   double buyProfit = 0.0, sellProfit = 0.0, buyMFE = 0.0, sellMFE = 0.0;
   if(g_stage17Pair.buyTicket > 0 && PositionSelectByTicket(g_stage17Pair.buyTicket))
   {
      buyProfit = CurrentPositionProfitMoneyV4(g_stage17Pair.buyTicket);
      buyMFE = GetTicketExitPeakMoneyV4(g_stage17Pair.buyTicket);
   }
   if(g_stage17Pair.sellTicket > 0 && PositionSelectByTicket(g_stage17Pair.sellTicket))
   {
      sellProfit = CurrentPositionProfitMoneyV4(g_stage17Pair.sellTicket);
      sellMFE = GetTicketExitPeakMoneyV4(g_stage17Pair.sellTicket);
   }

   bool buyClosed = true;
   bool sellClosed = true;
   if(g_stage17Pair.buyTicket > 0 && PositionSelectByTicket(g_stage17Pair.buyTicket))
      buyClosed = ClosePositionV4(g_stage17Pair.buyTicket, "DUAL_SIDE_CLOSE_BOTH_NO_WINNER_V10");
   if(g_stage17Pair.sellTicket > 0 && PositionSelectByTicket(g_stage17Pair.sellTicket))
      sellClosed = ClosePositionV4(g_stage17Pair.sellTicket, "DUAL_SIDE_CLOSE_BOTH_NO_WINNER_V10");

   if(buyClosed && sellClosed)
      g_stage17Pair.pairState = STAGE17_PAIR_CLOSED_NO_WINNER;
   else
      g_stage17Pair.pairState = STAGE17_PAIR_ACTIVE;

   if(Stage17_DebugLogs)
      Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_CLOSE_BOTH_NO_WINNER_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
            " buyTicket=", UlongToText(g_stage17Pair.buyTicket),
            " sellTicket=", UlongToText(g_stage17Pair.sellTicket),
            " buyProfit=", DoubleToString(buyProfit,2),
            " sellProfit=", DoubleToString(sellProfit,2),
            " buyMFE=", DoubleToString(buyMFE,2),
            " sellMFE=", DoubleToString(sellMFE,2),
            " ageSeconds=", IntegerToString((int)(TimeCurrent() - g_stage17Pair.openTime)),
            " basketProfit=", DoubleToString(buyProfit + sellProfit,2),
            " reason=NO_WINNER buyClosed=", BoolToText(buyClosed),
            " sellClosed=", BoolToText(sellClosed));

   return (buyClosed && sellClosed);
}

bool Stage17_ConfirmWinnerQuality(ulong winnerTicket, string &reason, string &rawClass, string &finalClass, double &profitMoney, double &mfeMoney, double &maeMoney, double &givebackPct, double &basketProfit, bool &beActive, bool &lockActive, bool &realSLConfirmed, bool &trendAlive, bool &severeReversal)
{
   reason = "ALLOW";
   rawClass = "WEAK";
   finalClass = "NONE";
   profitMoney = 0.0;
   mfeMoney = 0.0;
   maeMoney = 0.0;
   givebackPct = 0.0;
   basketProfit = 0.0;
   beActive = false;
   lockActive = false;
   realSLConfirmed = false;
   trendAlive = false;
   severeReversal = false;

   ulong loserTicket = (g_stage17Pair.loserSide == STAGE17_SIDE_BUY ? g_stage17Pair.buyTicket : g_stage17Pair.sellTicket);
   bool loserOpen = (loserTicket > 0 && PositionSelectByTicket(loserTicket));

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      basketProfit += CurrentPositionProfitMoneyV4(t);
   }

   bool allowConfirm = true;
   if(!UseStage17DualSideConfirmation)
   {
      allowConfirm = false;
      reason = "STAGE17_DISABLED";
   }
   else if(g_stage17Pair.pairId <= 0 || !g_stage17Pair.weakClosed)
   {
      allowConfirm = false;
      reason = "WEAK_SIDE_NOT_CLOSED";
   }
   else if(g_stage17Pair.winnerSide != STAGE17_SIDE_BUY && g_stage17Pair.winnerSide != STAGE17_SIDE_SELL)
   {
      allowConfirm = false;
      reason = "WINNER_SIDE_NOT_DEFINED";
   }
   else if(winnerTicket == 0 || !PositionSelectByTicket(winnerTicket))
   {
      allowConfirm = false;
      reason = "WINNER_NOT_OPEN";
   }
   else if(loserOpen)
   {
      allowConfirm = false;
      reason = "LOSER_STILL_OPEN";
   }
   else
   {
      UpdateTicketExitStateV4(winnerTicket);
      int idx = EnsureTicketExitStateV4(winnerTicket);
      profitMoney = CurrentPositionProfitMoneyV4(winnerTicket);
      mfeMoney = GetTicketExitPeakMoneyV4(winnerTicket);
      maeMoney = Stage15_GetTicketMAEMoneyV10(winnerTicket);
      finalClass = g_v4TicketExitStates[idx].liveExitClass;
      if(mfeMoney >= V10_BigRunnerStartMoney || profitMoney >= V10_BigRunnerStartMoney) rawClass = "BIG_RUNNER";
      else if(mfeMoney >= V10_RunnerStartMoney || profitMoney >= V10_RunnerStartMoney) rawClass = "RUNNER";
      else if(mfeMoney >= V10_GoodLockTriggerMoney || profitMoney >= V10_GoodBETriggerMoney) rawClass = "GOOD";
      else if(mfeMoney >= V10_ModerateBETriggerMoney || profitMoney >= (V10_ModerateBETriggerMoney * 0.50)) rawClass = "MODERATE";
      if(finalClass == "" || finalClass == "NEW" || finalClass == "NONE") finalClass = rawClass;
      beActive = g_v4TicketExitStates[idx].breakEvenActivated;
      lockActive = g_v4TicketExitStates[idx].lockActivated;
      realSLConfirmed = (PositionGetDouble(POSITION_SL) > 0.0);
      ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool confirmedReversal = Stage15_IsConfirmedReversal(winnerTicket, pt);
      bool healthyPullback = Stage15_IsHealthyPullback(winnerTicket, pt);
      severeReversal = IsSevereReversalV4(winnerTicket, pt);
      trendAlive = Stage15_IsTrendAliveV10(winnerTicket, pt, healthyPullback, confirmedReversal);
      if(mfeMoney > 0.0)
         givebackPct = MathMax(0.0, ((mfeMoney - profitMoney) / mfeMoney) * 100.0);

      bool classOK = (finalClass == "GOOD" || finalClass == "RUNNER" || finalClass == "BIG_RUNNER");
      bool slOK = (!Stage17_RequireRealSLConfirmedBeforeLayer || realSLConfirmed);
      bool beLockOK = (!(Stage17_RequireBEBeforeLayer || Stage17_RequireLockOrBEBeforeLayer) || (beActive || lockActive));
      if(!classOK)
      {
         allowConfirm = false;
         reason = "FINAL_CLASS_BELOW_GOOD";
      }
      else if(profitMoney < Stage17_StrongSideMinProfitMoney)
      {
         allowConfirm = false;
         reason = "WINNER_PROFIT_TOO_LOW";
      }
      else if(mfeMoney < Stage17_StrongSideMinMFEMoney)
      {
         allowConfirm = false;
         reason = "WINNER_MFE_TOO_LOW";
      }
      else if(Stage17_BlockLayerIfBasketNegative && basketProfit < 0.0)
      {
         allowConfirm = false;
         reason = "BASKET_NEGATIVE";
      }
      else if(Stage17_RequireTrendAliveForWinner && !trendAlive)
      {
         allowConfirm = false;
         reason = "TREND_NOT_ALIVE";
      }
      else if(Stage17_BlockOnSevereReversal && severeReversal)
      {
         allowConfirm = false;
         reason = "SEVERE_REVERSAL";
      }
      else if(!slOK)
      {
         allowConfirm = false;
         reason = "REAL_SL_NOT_CONFIRMED";
      }
      else if(!beLockOK)
      {
         allowConfirm = false;
         reason = "BE_OR_LOCK_NOT_CONFIRMED";
      }
   }

   if(allowConfirm)
   {
      if(Stage17_DebugLogs && (!g_stage17Pair.winnerConfirmed || g_stage17Pair.survivorUnconfirmed))
         Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_WINNER_CONFIRMED_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
               " ticket=", UlongToText(winnerTicket),
               " winnerSide=", (g_stage17Pair.winnerSide == STAGE17_SIDE_BUY ? "BUY" : "SELL"),
               " survivorUnconfirmed=", BoolToText(g_stage17Pair.survivorUnconfirmed),
               " winnerConfirmed=true rawClass=", rawClass,
               " finalClass=", finalClass,
               " profitMoney=", DoubleToString(profitMoney,2),
               " mfeMoney=", DoubleToString(mfeMoney,2),
               " maeMoney=", DoubleToString(maeMoney,2),
               " givebackPct=", DoubleToString(givebackPct,1),
               " basketProfit=", DoubleToString(basketProfit,2),
               " beActive=", BoolToText(beActive),
               " lockActive=", BoolToText(lockActive),
               " realSLConfirmed=", BoolToText(realSLConfirmed),
               " trendAlive=", BoolToText(trendAlive),
               " severeReversal=", BoolToText(severeReversal),
               " winnerLayer1Opened=", BoolToText(g_stage17Pair.winnerLayer1Opened),
               " winnerLayer1Alive=", BoolToText(g_stage17Pair.winnerLayer1Alive),
               " winnerLayer1Failed=", BoolToText(g_stage17Pair.winnerLayer1Failed),
               " decision=CONFIRM_WINNER reason=QUALITY_CONFIRMED");
      g_stage17Pair.winnerConfirmed = true;
      g_stage17Pair.survivorUnconfirmed = false;
      return true;
   }

   g_stage17Pair.winnerConfirmed = false;
   if(Stage17_DebugLogs)
   {
      Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_WINNER_CONFIRMATION_BLOCKED_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
            " ticket=", UlongToText(winnerTicket),
            " winnerSide=", (g_stage17Pair.winnerSide == STAGE17_SIDE_BUY ? "BUY" : "SELL"),
            " survivorUnconfirmed=", BoolToText(g_stage17Pair.survivorUnconfirmed),
            " winnerConfirmed=false rawClass=", rawClass,
            " finalClass=", finalClass,
            " profitMoney=", DoubleToString(profitMoney,2),
            " mfeMoney=", DoubleToString(mfeMoney,2),
            " maeMoney=", DoubleToString(maeMoney,2),
            " givebackPct=", DoubleToString(givebackPct,1),
            " basketProfit=", DoubleToString(basketProfit,2),
            " beActive=", BoolToText(beActive),
            " lockActive=", BoolToText(lockActive),
            " realSLConfirmed=", BoolToText(realSLConfirmed),
            " trendAlive=", BoolToText(trendAlive),
            " severeReversal=", BoolToText(severeReversal),
            " winnerLayer1Opened=", BoolToText(g_stage17Pair.winnerLayer1Opened),
            " winnerLayer1Alive=", BoolToText(g_stage17Pair.winnerLayer1Alive),
            " winnerLayer1Failed=", BoolToText(g_stage17Pair.winnerLayer1Failed),
            " decision=BLOCK_WINNER_CONFIRMATION reason=", reason);
      if(g_stage17Pair.survivorUnconfirmed)
         Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_SURVIVOR_UNCONFIRMED_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
               " ticket=", UlongToText(winnerTicket),
               " winnerSide=", (g_stage17Pair.winnerSide == STAGE17_SIDE_BUY ? "BUY" : "SELL"),
               " survivorUnconfirmed=true winnerConfirmed=false rawClass=", rawClass,
               " finalClass=", finalClass,
               " profitMoney=", DoubleToString(profitMoney,2),
               " mfeMoney=", DoubleToString(mfeMoney,2),
               " maeMoney=", DoubleToString(maeMoney,2),
               " givebackPct=", DoubleToString(givebackPct,1),
               " basketProfit=", DoubleToString(basketProfit,2),
               " beActive=", BoolToText(beActive),
               " lockActive=", BoolToText(lockActive),
               " realSLConfirmed=", BoolToText(realSLConfirmed),
               " trendAlive=", BoolToText(trendAlive),
               " severeReversal=", BoolToText(severeReversal),
               " winnerLayer1Opened=", BoolToText(g_stage17Pair.winnerLayer1Opened),
               " winnerLayer1Alive=", BoolToText(g_stage17Pair.winnerLayer1Alive),
               " winnerLayer1Failed=", BoolToText(g_stage17Pair.winnerLayer1Failed),
               " decision=MONITOR_ONLY reason=", reason);
   }
   return false;
}

void Stage17_UpdateLayer1State()
{
   if(!UseStage17DualSideConfirmation || g_stage17Pair.pairId <= 0)
      return;
   if(!g_stage17Pair.winnerLayer1Opened || g_stage17Pair.winnerLayer1Ticket == 0)
      return;

   ulong ticket = g_stage17Pair.winnerLayer1Ticket;
   bool alive = PositionSelectByTicket(ticket);
   string rawClass = "WEAK";
   string finalClass = "NONE";
   double profitMoney = g_stage17Pair.winnerLayer1Profit;
   double mfeMoney = g_stage17Pair.winnerLayer1MFE;
   double maeMoney = 0.0;
   double givebackPct = 0.0;
   double basketProfit = 0.0;
   bool beActive = false, lockActive = false, realSLConfirmed = false, trendAlive = false, severeReversal = false;
   string decision = "HOLD";
   string reason = "LAYER1_ALIVE";

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      basketProfit += CurrentPositionProfitMoneyV4(t);
   }

   if(alive && PositionSelectByTicket(ticket))
   {
      UpdateTicketExitStateV4(ticket);
      int idx = EnsureTicketExitStateV4(ticket);
      profitMoney = CurrentPositionProfitMoneyV4(ticket);
      mfeMoney = MathMax(g_stage17Pair.winnerLayer1MFE, GetTicketExitPeakMoneyV4(ticket));
      maeMoney = Stage15_GetTicketMAEMoneyV10(ticket);
      finalClass = g_v4TicketExitStates[idx].liveExitClass;
      if(mfeMoney >= V10_BigRunnerStartMoney || profitMoney >= V10_BigRunnerStartMoney) rawClass = "BIG_RUNNER";
      else if(mfeMoney >= V10_RunnerStartMoney || profitMoney >= V10_RunnerStartMoney) rawClass = "RUNNER";
      else if(mfeMoney >= V10_GoodLockTriggerMoney || profitMoney >= V10_GoodBETriggerMoney) rawClass = "GOOD";
      else if(mfeMoney >= V10_ModerateBETriggerMoney || profitMoney >= (V10_ModerateBETriggerMoney * 0.50)) rawClass = "MODERATE";
      if(finalClass == "" || finalClass == "NEW" || finalClass == "NONE") finalClass = rawClass;
      beActive = g_v4TicketExitStates[idx].breakEvenActivated;
      lockActive = g_v4TicketExitStates[idx].lockActivated;
      realSLConfirmed = (PositionGetDouble(POSITION_SL) > 0.0);
      ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool confirmedReversal = Stage15_IsConfirmedReversal(ticket, pt);
      bool healthyPullback = Stage15_IsHealthyPullback(ticket, pt);
      severeReversal = IsSevereReversalV4(ticket, pt);
      trendAlive = Stage15_IsTrendAliveV10(ticket, pt, healthyPullback, confirmedReversal);
      if(mfeMoney > 0.0)
         givebackPct = MathMax(0.0, ((mfeMoney - profitMoney) / mfeMoney) * 100.0);

      g_stage17Pair.winnerLayer1Alive = true;
      g_stage17Pair.winnerLayer1Closed = false;
      g_stage17Pair.winnerLayer1Profit = profitMoney;
      g_stage17Pair.winnerLayer1MFE = mfeMoney;
   }
   else
   {
      double closedProfit = 0.0;
      string closeComment = "UNKNOWN";
      bool foundClose = false;
      datetime fromTime = (g_stage17Pair.openTime > 3600 ? g_stage17Pair.openTime - 3600 : 0);
      if(HistorySelect(fromTime, TimeCurrent()))
      {
         int total = HistoryDealsTotal();
         for(int d = total - 1; d >= 0; d--)
         {
            ulong deal = HistoryDealGetTicket(d);
            if(deal == 0 || !HistoryDealSelect(deal)) continue;
            if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol) continue;
            if((long)HistoryDealGetInteger(deal, DEAL_MAGIC) != MagicNumber) continue;
            ulong positionId = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
            if(positionId != ticket) continue;
            long entryType = (long)HistoryDealGetInteger(deal, DEAL_ENTRY);
            if(entryType != DEAL_ENTRY_OUT && entryType != DEAL_ENTRY_OUT_BY) continue;
            closedProfit += HistoryDealGetDouble(deal, DEAL_PROFIT) + HistoryDealGetDouble(deal, DEAL_SWAP) + HistoryDealGetDouble(deal, DEAL_COMMISSION);
            closeComment = HistoryDealGetString(deal, DEAL_COMMENT);
            foundClose = true;
         }
      }
      profitMoney = (foundClose ? closedProfit : g_stage17Pair.winnerLayer1Profit);
      mfeMoney = g_stage17Pair.winnerLayer1MFE;
      bool failed = (!foundClose || profitMoney < 0.0 || mfeMoney < Stage17_Layer1_MinMFEMoney || StringFind(closeComment, "sl") >= 0 || StringFind(closeComment, "SL") >= 0);
      g_stage17Pair.winnerLayer1Alive = false;
      g_stage17Pair.winnerLayer1Closed = true;
      g_stage17Pair.winnerLayer1Profit = profitMoney;
      if(failed)
         g_stage17Pair.winnerLayer1Failed = true;
      decision = (failed ? "LAYER1_FAILED" : "LAYER1_CLOSED_OK");
      reason = (failed ? "LAYER1_CLOSED_WITH_NEGATIVE_OR_WEAK_QUALITY" : "LAYER1_CLOSED_WITH_ACCEPTABLE_RESULT");
   }

   if(Stage17_DebugLogs)
   {
      Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_LAYER1_STATE_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
            " ticket=", UlongToText(ticket),
            " winnerSide=", (g_stage17Pair.winnerSide == STAGE17_SIDE_BUY ? "BUY" : "SELL"),
            " survivorUnconfirmed=", BoolToText(g_stage17Pair.survivorUnconfirmed),
            " winnerConfirmed=", BoolToText(g_stage17Pair.winnerConfirmed),
            " rawClass=", rawClass,
            " finalClass=", finalClass,
            " profitMoney=", DoubleToString(profitMoney,2),
            " mfeMoney=", DoubleToString(mfeMoney,2),
            " maeMoney=", DoubleToString(maeMoney,2),
            " givebackPct=", DoubleToString(givebackPct,1),
            " basketProfit=", DoubleToString(basketProfit,2),
            " beActive=", BoolToText(beActive),
            " lockActive=", BoolToText(lockActive),
            " realSLConfirmed=", BoolToText(realSLConfirmed),
            " trendAlive=", BoolToText(trendAlive),
            " severeReversal=", BoolToText(severeReversal),
            " winnerLayer1Opened=", BoolToText(g_stage17Pair.winnerLayer1Opened),
            " winnerLayer1Alive=", BoolToText(g_stage17Pair.winnerLayer1Alive),
            " winnerLayer1Failed=", BoolToText(g_stage17Pair.winnerLayer1Failed),
            " decision=", decision,
            " reason=", reason);
      if(g_stage17Pair.winnerLayer1Failed)
         Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_LAYER2_BLOCKED_AFTER_LAYER1_FAIL_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
               " ticket=", UlongToText(ticket),
               " winnerSide=", (g_stage17Pair.winnerSide == STAGE17_SIDE_BUY ? "BUY" : "SELL"),
               " survivorUnconfirmed=", BoolToText(g_stage17Pair.survivorUnconfirmed),
               " winnerConfirmed=", BoolToText(g_stage17Pair.winnerConfirmed),
               " rawClass=", rawClass,
               " finalClass=", finalClass,
               " profitMoney=", DoubleToString(profitMoney,2),
               " mfeMoney=", DoubleToString(mfeMoney,2),
               " maeMoney=", DoubleToString(maeMoney,2),
               " givebackPct=", DoubleToString(givebackPct,1),
               " basketProfit=", DoubleToString(basketProfit,2),
               " beActive=", BoolToText(beActive),
               " lockActive=", BoolToText(lockActive),
               " realSLConfirmed=", BoolToText(realSLConfirmed),
               " trendAlive=", BoolToText(trendAlive),
               " severeReversal=", BoolToText(severeReversal),
               " winnerLayer1Opened=", BoolToText(g_stage17Pair.winnerLayer1Opened),
               " winnerLayer1Alive=", BoolToText(g_stage17Pair.winnerLayer1Alive),
               " winnerLayer1Failed=true decision=BLOCK_LAYER2 reason=LAYER1_FAILED");
   }
}

void Stage17_ProfitExtractionManager()
{
   if(!UseStage17DualSideConfirmation)
      return;
   if(g_stage17Pair.pairId <= 0)
      return;
   if(g_stage17Pair.pairState != STAGE17_PAIR_ACTIVE && g_stage17Pair.pairState != STAGE17_PAIR_DECIDED_WEAK_CLOSED)
      return;
   if(!g_stage17Pair.weakClosed)
      return;
   if(g_stage17Pair.winnerSide != STAGE17_SIDE_BUY && g_stage17Pair.winnerSide != STAGE17_SIDE_SELL)
      return;

   ulong winnerTicket = (g_stage17Pair.winnerSide == STAGE17_SIDE_BUY ? g_stage17Pair.buyTicket : g_stage17Pair.sellTicket);
   ulong loserTicket = (g_stage17Pair.loserSide == STAGE17_SIDE_BUY ? g_stage17Pair.buyTicket : g_stage17Pair.sellTicket);
   if(winnerTicket == 0 || !PositionSelectByTicket(winnerTicket))
      return;
   if(loserTicket > 0 && PositionSelectByTicket(loserTicket))
      return;

   Stage17_UpdateLayer1State();

   string reason = "ALLOW";
   string rawClass = "WEAK";
   string finalClass = "NONE";
   double profitMoney = 0.0, mfeMoney = 0.0, maeMoney = 0.0, givebackPct = 0.0, basketProfit = 0.0;
   bool beActive = false, lockActive = false, realSLConfirmed = false, trendAlive = false, severeReversal = false;
   bool confirmed = Stage17_ConfirmWinnerQuality(winnerTicket, reason, rawClass, finalClass, profitMoney, mfeMoney, maeMoney, givebackPct, basketProfit, beActive, lockActive, realSLConfirmed, trendAlive, severeReversal);

   string decision = (confirmed ? "HOLD_CONFIRMED_WINNER" : (g_stage17Pair.survivorUnconfirmed ? "HOLD_SURVIVOR_UNCONFIRMED" : "WAIT_CONFIRMATION"));
   string extractionReason = reason;
   bool closeWinner = false;

   if(confirmed)
   {
      if(finalClass == "GOOD" && profitMoney > 0.0 && mfeMoney >= Stage17_Layer1_MinMFEMoney && givebackPct > 55.0)
      {
         closeWinner = true;
         decision = "CLOSE_GOOD_GIVEBACK";
         extractionReason = "GOOD_GIVEBACK_EXCESSIVE";
      }
      else if(finalClass == "RUNNER")
      {
         if(trendAlive && !severeReversal)
         {
            decision = "HOLD_RUNNER_TREND_ALIVE";
            extractionReason = "RUNNER_TREND_ALIVE";
         }
         else if(profitMoney > 0.0 && givebackPct > 45.0)
         {
            closeWinner = true;
            decision = "CLOSE_RUNNER_GIVEBACK";
            extractionReason = "RUNNER_GIVEBACK_WITH_TREND_LOSS";
         }
      }
      else if(finalClass == "BIG_RUNNER")
      {
         if(trendAlive && !severeReversal)
         {
            decision = "HOLD_BIG_RUNNER_TREND_ALIVE";
            extractionReason = "BIG_RUNNER_TREND_ALIVE";
         }
         else if(profitMoney > 0.0 && (severeReversal || givebackPct > 35.0))
         {
            closeWinner = true;
            decision = "CLOSE_BIG_RUNNER_GIVEBACK";
            extractionReason = (severeReversal ? "BIG_RUNNER_SEVERE_REVERSAL" : "BIG_RUNNER_GIVEBACK_CRITICAL");
         }
      }
   }

   if(Stage17_DebugLogs)
   {
      Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_PROFIT_EXTRACTION_CHECK_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
            " ticket=", UlongToText(winnerTicket),
            " winnerSide=", (g_stage17Pair.winnerSide == STAGE17_SIDE_BUY ? "BUY" : "SELL"),
            " survivorUnconfirmed=", BoolToText(g_stage17Pair.survivorUnconfirmed),
            " winnerConfirmed=", BoolToText(g_stage17Pair.winnerConfirmed),
            " rawClass=", rawClass,
            " finalClass=", finalClass,
            " profitMoney=", DoubleToString(profitMoney,2),
            " mfeMoney=", DoubleToString(mfeMoney,2),
            " maeMoney=", DoubleToString(maeMoney,2),
            " givebackPct=", DoubleToString(givebackPct,1),
            " basketProfit=", DoubleToString(basketProfit,2),
            " beActive=", BoolToText(beActive),
            " lockActive=", BoolToText(lockActive),
            " realSLConfirmed=", BoolToText(realSLConfirmed),
            " trendAlive=", BoolToText(trendAlive),
            " severeReversal=", BoolToText(severeReversal),
            " winnerLayer1Opened=", BoolToText(g_stage17Pair.winnerLayer1Opened),
            " winnerLayer1Alive=", BoolToText(g_stage17Pair.winnerLayer1Alive),
            " winnerLayer1Failed=", BoolToText(g_stage17Pair.winnerLayer1Failed),
            " decision=", decision,
            " reason=", extractionReason);
      if(confirmed && (finalClass == "RUNNER" || finalClass == "BIG_RUNNER") && trendAlive && !severeReversal && !closeWinner)
         Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_WINNER_RUNNER_HOLD_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
               " ticket=", UlongToText(winnerTicket),
               " winnerSide=", (g_stage17Pair.winnerSide == STAGE17_SIDE_BUY ? "BUY" : "SELL"),
               " survivorUnconfirmed=", BoolToText(g_stage17Pair.survivorUnconfirmed),
               " winnerConfirmed=", BoolToText(g_stage17Pair.winnerConfirmed),
               " rawClass=", rawClass,
               " finalClass=", finalClass,
               " profitMoney=", DoubleToString(profitMoney,2),
               " mfeMoney=", DoubleToString(mfeMoney,2),
               " maeMoney=", DoubleToString(maeMoney,2),
               " givebackPct=", DoubleToString(givebackPct,1),
               " basketProfit=", DoubleToString(basketProfit,2),
               " beActive=", BoolToText(beActive),
               " lockActive=", BoolToText(lockActive),
               " realSLConfirmed=", BoolToText(realSLConfirmed),
               " trendAlive=", BoolToText(trendAlive),
               " severeReversal=", BoolToText(severeReversal),
               " winnerLayer1Opened=", BoolToText(g_stage17Pair.winnerLayer1Opened),
               " winnerLayer1Alive=", BoolToText(g_stage17Pair.winnerLayer1Alive),
               " winnerLayer1Failed=", BoolToText(g_stage17Pair.winnerLayer1Failed),
               " decision=HOLD_RUNNER reason=TREND_ALIVE");
   }

   if(closeWinner && winnerTicket > 0 && PositionSelectByTicket(winnerTicket))
   {
      bool closeOk = ClosePositionV4(winnerTicket, "DUAL_SIDE_WINNER_GIVEBACK_EXIT_V10");
      if(Stage17_DebugLogs)
         Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_WINNER_GIVEBACK_EXIT_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
               " ticket=", UlongToText(winnerTicket),
               " winnerSide=", (g_stage17Pair.winnerSide == STAGE17_SIDE_BUY ? "BUY" : "SELL"),
               " survivorUnconfirmed=", BoolToText(g_stage17Pair.survivorUnconfirmed),
               " winnerConfirmed=", BoolToText(g_stage17Pair.winnerConfirmed),
               " rawClass=", rawClass,
               " finalClass=", finalClass,
               " profitMoney=", DoubleToString(profitMoney,2),
               " mfeMoney=", DoubleToString(mfeMoney,2),
               " maeMoney=", DoubleToString(maeMoney,2),
               " givebackPct=", DoubleToString(givebackPct,1),
               " basketProfit=", DoubleToString(basketProfit,2),
               " beActive=", BoolToText(beActive),
               " lockActive=", BoolToText(lockActive),
               " realSLConfirmed=", BoolToText(realSLConfirmed),
               " trendAlive=", BoolToText(trendAlive),
               " severeReversal=", BoolToText(severeReversal),
               " winnerLayer1Opened=", BoolToText(g_stage17Pair.winnerLayer1Opened),
               " winnerLayer1Alive=", BoolToText(g_stage17Pair.winnerLayer1Alive),
               " winnerLayer1Failed=", BoolToText(g_stage17Pair.winnerLayer1Failed),
               " decision=", decision,
               " reason=", extractionReason,
               " closeSuccess=", BoolToText(closeOk));
   }
}

bool Stage17_CanOpenWinnerLayer()
{
   g_stage17ApprovedLayerNumber = 0;
   g_stage17ApprovedLayerLot = 0.0;

   if(g_stage17Pair.pairId <= 0)
      return false;
   if(g_stage17Pair.pairState != STAGE17_PAIR_ACTIVE &&
      g_stage17Pair.pairState != STAGE17_PAIR_DECIDED_WEAK_CLOSED)
      return false;

   Stage17_UpdateLayer1State();

   int layerNumber = (!g_stage17Pair.winnerLayer1Opened ? 1 : (!g_stage17Pair.winnerLayer2Opened ? 2 : 0));
   if(layerNumber <= 0)
      return false;

   string reason = "ALLOW";
   bool allowLayer = true;
   ulong winnerTicket = (g_stage17Pair.winnerSide == STAGE17_SIDE_BUY ? g_stage17Pair.buyTicket : g_stage17Pair.sellTicket);
   ulong loserTicket = (g_stage17Pair.loserSide == STAGE17_SIDE_BUY ? g_stage17Pair.buyTicket : g_stage17Pair.sellTicket);
   double profit = 0.0, mfe = 0.0, mae = 0.0, givebackPct = 0.0, basketProfit = 0.0;
   string finalClass = "NONE", rawClass = "WEAK";
   bool beConfirmed = false, lockConfirmed = false, realSLConfirmed = false, trendAlive = false, severeReversal = false;
   int qualityScore = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      basketProfit += CurrentPositionProfitMoneyV4(t);
   }

   bool confirmed = Stage17_ConfirmWinnerQuality(winnerTicket, reason, rawClass, finalClass, profit, mfe, mae, givebackPct, basketProfit, beConfirmed, lockConfirmed, realSLConfirmed, trendAlive, severeReversal);
   if(confirmed) qualityScore += 20;
   if(finalClass == "GOOD" || finalClass == "RUNNER" || finalClass == "BIG_RUNNER") qualityScore += 15;
   if(finalClass == "RUNNER" || finalClass == "BIG_RUNNER") qualityScore += 10;
   if(trendAlive) qualityScore += 15;
   if(!severeReversal) qualityScore += 10;
   if(basketProfit >= 0.0) qualityScore += 10;
   if(beConfirmed || lockConfirmed) qualityScore += 10;
   if(realSLConfirmed) qualityScore += 10;

   if(!g_stage17Pair.decisionMade || !g_stage17Pair.weakClosed)
   {
      allowLayer = false;
      reason = "WEAK_SIDE_STILL_OPEN";
   }
   else if(Stage17_LayerOnlyAfterWeakSideClosed && loserTicket > 0 && PositionSelectByTicket(loserTicket))
   {
      allowLayer = false;
      reason = "LOSER_STILL_OPEN";
   }
   else if(winnerTicket == 0 || !PositionSelectByTicket(winnerTicket))
   {
      allowLayer = false;
      reason = "WINNER_NOT_OPEN";
   }
   else if(g_stage17Pair.survivorUnconfirmed && !g_stage17Pair.winnerConfirmed)
   {
      allowLayer = false;
      reason = "SURVIVOR_UNCONFIRMED";
   }
   else if(!confirmed || !g_stage17Pair.winnerConfirmed)
   {
      allowLayer = false;
      if(reason == "ALLOW") reason = "WINNER_NOT_CONFIRMED";
   }
   else
   {
      UpdateTicketExitStateV4(winnerTicket);
      int idx = EnsureTicketExitStateV4(winnerTicket);
      profit = CurrentPositionProfitMoneyV4(winnerTicket);
      mfe = GetTicketExitPeakMoneyV4(winnerTicket);
      mae = Stage15_GetTicketMAEMoneyV10(winnerTicket);
      if(mfe > 0.0)
         givebackPct = MathMax(0.0, ((mfe - profit) / mfe) * 100.0);
      finalClass = g_v4TicketExitStates[idx].liveExitClass;
      if(mfe >= V10_BigRunnerStartMoney || profit >= V10_BigRunnerStartMoney) rawClass = "BIG_RUNNER";
      else if(mfe >= V10_RunnerStartMoney || profit >= V10_RunnerStartMoney) rawClass = "RUNNER";
      else if(mfe >= V10_GoodLockTriggerMoney || profit >= V10_GoodBETriggerMoney) rawClass = "GOOD";
      else if(mfe >= V10_ModerateBETriggerMoney || profit >= (V10_ModerateBETriggerMoney * 0.50)) rawClass = "MODERATE";
      if(finalClass == "" || finalClass == "NEW" || finalClass == "NONE") finalClass = rawClass;
      beConfirmed = g_v4TicketExitStates[idx].breakEvenActivated;
      lockConfirmed = g_v4TicketExitStates[idx].lockActivated;
      realSLConfirmed = (PositionGetDouble(POSITION_SL) > 0.0);
      ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool confirmedReversal = Stage15_IsConfirmedReversal(winnerTicket, pt);
      bool healthyPullback = Stage15_IsHealthyPullback(winnerTicket, pt);
      severeReversal = IsSevereReversalV4(winnerTicket, pt);
      trendAlive = Stage15_IsTrendAliveV10(winnerTicket, pt, healthyPullback, confirmedReversal);

      double minProfit = (layerNumber == 1 ? Stage17_Layer1_MinProfitMoney : Stage17_Layer2_MinProfitMoney);
      double minMFE = (layerNumber == 1 ? Stage17_Layer1_MinMFEMoney : Stage17_Layer2_MinMFEMoney);
      bool classOK = (layerNumber == 1 ? (finalClass == "GOOD" || finalClass == "RUNNER" || finalClass == "BIG_RUNNER") : (finalClass == "RUNNER" || finalClass == "BIG_RUNNER"));

      if(Stage17_OnlyWinnerCanLayer && (g_stage17Pair.winnerSide != STAGE17_SIDE_BUY && g_stage17Pair.winnerSide != STAGE17_SIDE_SELL))
      {
         allowLayer = false;
         reason = "WINNER_SIDE_NOT_DEFINED";
      }
      else if(finalClass == "WEAK")
      {
         allowLayer = false;
         reason = (rawClass == "RUNNER" ? "RAW_RUNNER_FINAL_WEAK_BLOCK" : "FINAL_CLASS_WEAK_BLOCK");
      }
      else if(!classOK)
      {
         allowLayer = false;
         reason = "FINAL_CLASS_NOT_ALLOWED";
      }
      else if(profit <= 0.0 || profit < minProfit)
      {
         allowLayer = false;
         reason = "PROFIT_TOO_LOW";
      }
      else if(mfe <= 0.0 || mfe < minMFE)
      {
         allowLayer = false;
         reason = "MFE_TOO_LOW";
      }
      else if(Stage17_BlockLayerIfBasketNegative && basketProfit < 0.0)
      {
         allowLayer = false;
         reason = "BASKET_NEGATIVE";
      }
      else if(Stage17_RequireRealSLConfirmedBeforeLayer && !realSLConfirmed)
      {
         allowLayer = false;
         reason = "REAL_SL_NOT_CONFIRMED";
      }
      else if((Stage17_RequireBEBeforeLayer || Stage17_RequireLockOrBEBeforeLayer) && !(beConfirmed || lockConfirmed))
      {
         allowLayer = false;
         reason = "BE_OR_LOCK_NOT_CONFIRMED";
      }
      else if(Stage17_RequireTrendAliveForWinner && !trendAlive)
      {
         allowLayer = false;
         reason = "TREND_NOT_ALIVE";
      }
      else if(Stage17_BlockOnSevereReversal && severeReversal)
      {
         allowLayer = false;
         reason = "SEVERE_REVERSAL";
      }
      else if(layerNumber == 2 && g_stage17Pair.winnerLayer1Failed)
      {
         allowLayer = false;
         reason = "LAYER1_FAILED_BLOCK_LAYER2";
      }
      else if(layerNumber == 2 && (!g_stage17Pair.winnerLayer1Opened || !g_stage17Pair.winnerLayer1Alive || g_stage17Pair.winnerLayer1Ticket == 0))
      {
         allowLayer = false;
         reason = "LAYER1_NOT_ALIVE_BLOCK_LAYER2";
      }
      else if(layerNumber == 2 && g_stage17Pair.winnerLayer1Profit <= 0.0)
      {
         allowLayer = false;
         reason = "LAYER1_NOT_PROFITABLE_BLOCK_LAYER2";
      }
      else if(layerNumber == 2 && g_stage17Pair.winnerLayer1MFE < Stage17_Layer1_MinMFEMoney)
      {
         allowLayer = false;
         reason = "LAYER1_MFE_WEAK_BLOCK_LAYER2";
      }
      else if(layerNumber == 2 && givebackPct > 45.0)
      {
         allowLayer = false;
         reason = "GIVEBACK_TOO_HIGH_BLOCK_LAYER2";
      }
      else if(GetCurrentSpreadPoints() > Stage17_MaxSpreadPoints)
      {
         allowLayer = false;
         reason = "SPREAD_HIGH";
      }
      else if(Stage17_BlockIfDailyDDAbovePercent > 0.0 && g_risk.dailyDrawdownPercent > Stage17_BlockIfDailyDDAbovePercent)
      {
         allowLayer = false;
         reason = "DAILY_DD_BLOCK";
      }
      else
      {
         double nextLot = (layerNumber == 1 ? Stage17_WinnerLayer1Lot : Stage17_WinnerLayer2Lot);
         double directionLots = 0.0;
         for(int p = PositionsTotal() - 1; p >= 0; p--)
         {
            ulong t = PositionGetTicket(p);
            if(t == 0 || !PositionSelectByTicket(t)) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
            if((long)PositionGetInteger(POSITION_TYPE) == (long)pt)
               directionLots += PositionGetDouble(POSITION_VOLUME);
         }
         if(MaxTotalLayerLotsPerDirection > 0.0 && directionLots + nextLot > MaxTotalLayerLotsPerDirection + 0.000001)
         {
            allowLayer = false;
            reason = "DIRECTIONAL_LOT_LIMIT";
         }
      }
   }

   if(Stage17_DebugLogs)
   {
      Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_LAYER_QUALITY_SCORE_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
            " winnerSide=", (g_stage17Pair.winnerSide == STAGE17_SIDE_BUY ? "BUY" : "SELL"),
            " winnerTicket=", UlongToText(winnerTicket),
            " layerNumber=", IntegerToString(layerNumber),
            " qualityScore=", IntegerToString(qualityScore),
            " survivorUnconfirmed=", BoolToText(g_stage17Pair.survivorUnconfirmed),
            " winnerConfirmed=", BoolToText(g_stage17Pair.winnerConfirmed),
            " rawClass=", rawClass,
            " finalClass=", finalClass,
            " profitMoney=", DoubleToString(profit,2),
            " mfeMoney=", DoubleToString(mfe,2),
            " maeMoney=", DoubleToString(mae,2),
            " givebackPct=", DoubleToString(givebackPct,1),
            " basketProfit=", DoubleToString(basketProfit,2),
            " trendAlive=", BoolToText(trendAlive),
            " severeReversal=", BoolToText(severeReversal),
            " winnerLayer1Alive=", BoolToText(g_stage17Pair.winnerLayer1Alive),
            " winnerLayer1Failed=", BoolToText(g_stage17Pair.winnerLayer1Failed),
            " allowLayer=", BoolToText(allowLayer),
            " reason=", reason);
      Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_WINNER_LAYER_CHECK_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
            " winnerSide=", (g_stage17Pair.winnerSide == STAGE17_SIDE_BUY ? "BUY" : "SELL"),
            " winnerTicket=", UlongToText(winnerTicket),
            " layerNumber=", IntegerToString(layerNumber),
            " profit=", DoubleToString(profit,2),
            " mfe=", DoubleToString(mfe,2),
            " finalClass=", finalClass,
            " beConfirmed=", BoolToText(beConfirmed),
            " lockConfirmed=", BoolToText(lockConfirmed),
            " realSLConfirmed=", BoolToText(realSLConfirmed),
            " basketProfit=", DoubleToString(basketProfit,2),
            " spread=", IntegerToString(GetCurrentSpreadPoints()),
            " dailyDD=", DoubleToString(g_risk.dailyDrawdownPercent,2),
            " allowLayer=", BoolToText(allowLayer),
            " reason=", reason);
   }

   if(allowLayer)
   {
      g_stage17ApprovedLayerNumber = layerNumber;
      g_stage17ApprovedLayerLot = (layerNumber == 1 ? Stage17_WinnerLayer1Lot : Stage17_WinnerLayer2Lot);
      if(Stage17_DebugLogs)
      {
         Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_LAYER_APPROVED_BY_EXTRACTION_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
               " winnerSide=", (g_stage17Pair.winnerSide == STAGE17_SIDE_BUY ? "BUY" : "SELL"),
               " winnerTicket=", UlongToText(winnerTicket),
               " layerNumber=", IntegerToString(layerNumber),
               " qualityScore=", IntegerToString(qualityScore),
               " lot=", DoubleToString(g_stage17ApprovedLayerLot,2),
               " survivorUnconfirmed=", BoolToText(g_stage17Pair.survivorUnconfirmed),
               " winnerConfirmed=", BoolToText(g_stage17Pair.winnerConfirmed),
               " rawClass=", rawClass,
               " finalClass=", finalClass,
               " profitMoney=", DoubleToString(profit,2),
               " mfeMoney=", DoubleToString(mfe,2),
               " givebackPct=", DoubleToString(givebackPct,1),
               " basketProfit=", DoubleToString(basketProfit,2),
               " winnerLayer1Failed=", BoolToText(g_stage17Pair.winnerLayer1Failed),
               " reason=EXTRACTION_APPROVED");
         Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_WINNER_LAYER_APPROVED_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
               " winnerSide=", (g_stage17Pair.winnerSide == STAGE17_SIDE_BUY ? "BUY" : "SELL"),
               " winnerTicket=", UlongToText(winnerTicket),
               " layerNumber=", IntegerToString(layerNumber),
               " lot=", DoubleToString(g_stage17ApprovedLayerLot,2),
               " profit=", DoubleToString(profit,2),
               " mfe=", DoubleToString(mfe,2),
               " finalClass=", finalClass,
               " reason=STAGE17_LAYER_APPROVED");
      }
      return true;
   }

   if(Stage17_DebugLogs)
   {
      Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_LAYER_BLOCKED_BY_EXTRACTION_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
            " winnerSide=", (g_stage17Pair.winnerSide == STAGE17_SIDE_BUY ? "BUY" : "SELL"),
            " winnerTicket=", UlongToText(winnerTicket),
            " layerNumber=", IntegerToString(layerNumber),
            " qualityScore=", IntegerToString(qualityScore),
            " survivorUnconfirmed=", BoolToText(g_stage17Pair.survivorUnconfirmed),
            " winnerConfirmed=", BoolToText(g_stage17Pair.winnerConfirmed),
            " rawClass=", rawClass,
            " finalClass=", finalClass,
            " profitMoney=", DoubleToString(profit,2),
            " mfeMoney=", DoubleToString(mfe,2),
            " givebackPct=", DoubleToString(givebackPct,1),
            " basketProfit=", DoubleToString(basketProfit,2),
            " winnerLayer1Alive=", BoolToText(g_stage17Pair.winnerLayer1Alive),
            " winnerLayer1Failed=", BoolToText(g_stage17Pair.winnerLayer1Failed),
            " reason=", reason);
      if(g_stage17Pair.survivorUnconfirmed && !g_stage17Pair.winnerConfirmed)
         Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_SURVIVOR_LAYER_BLOCKED_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
               " winnerSide=", (g_stage17Pair.winnerSide == STAGE17_SIDE_BUY ? "BUY" : "SELL"),
               " winnerTicket=", UlongToText(winnerTicket),
               " layerNumber=", IntegerToString(layerNumber),
               " reason=SURVIVOR_UNCONFIRMED");
      if(layerNumber == 2 && g_stage17Pair.winnerLayer1Failed)
         Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_LAYER2_BLOCKED_AFTER_LAYER1_FAIL_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
               " winnerSide=", (g_stage17Pair.winnerSide == STAGE17_SIDE_BUY ? "BUY" : "SELL"),
               " winnerTicket=", UlongToText(winnerTicket),
               " layer1Ticket=", UlongToText(g_stage17Pair.winnerLayer1Ticket),
               " layer1Profit=", DoubleToString(g_stage17Pair.winnerLayer1Profit,2),
               " layer1MFE=", DoubleToString(g_stage17Pair.winnerLayer1MFE,2),
               " reason=", reason);
      Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_WINNER_LAYER_BLOCKED_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
            " winnerSide=", (g_stage17Pair.winnerSide == STAGE17_SIDE_BUY ? "BUY" : "SELL"),
            " winnerTicket=", UlongToText(winnerTicket),
            " layerNumber=", IntegerToString(layerNumber),
            " reason=", reason,
            " profit=", DoubleToString(profit,2),
            " mfe=", DoubleToString(mfe,2),
            " finalClass=", finalClass,
            " beConfirmed=", BoolToText(beConfirmed),
            " lockConfirmed=", BoolToText(lockConfirmed),
            " realSLConfirmed=", BoolToText(realSLConfirmed),
            " basketProfit=", DoubleToString(basketProfit,2));
   }

   return false;
}

bool Stage17_OpenWinnerLayer()
{
   if(g_stage17ApprovedLayerNumber <= 0 || g_stage17ApprovedLayerLot <= 0.0)
      return false;

   ulong winnerTicket = (g_stage17Pair.winnerSide == STAGE17_SIDE_BUY ? g_stage17Pair.buyTicket : g_stage17Pair.sellTicket);
   if(winnerTicket == 0 || !PositionSelectByTicket(winnerTicket))
      return false;

   ENUM_POSITION_TYPE winnerType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double sl = PositionGetDouble(POSITION_SL);
   double tp = 0.0;
   double lot = g_stage17ApprovedLayerLot;
   string sideText = (winnerType == POSITION_TYPE_BUY ? "BUY" : "SELL");
   string comment = "HORSE DUAL LAYER" + IntegerToString(g_stage17ApprovedLayerNumber) + " " + sideText;

   trade.SetExpertMagicNumber((ulong)MagicNumber);
   trade.SetDeviationInPoints(LayerDeviationPoints);
   ENUM_ORDER_TYPE_FILLING filling = ORDER_FILLING_FOK;
   uint fillingModes = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((fillingModes & SYMBOL_FILLING_IOC) != 0) filling = ORDER_FILLING_IOC;
   if((fillingModes & SYMBOL_FILLING_FOK) != 0) filling = ORDER_FILLING_FOK;
   trade.SetTypeFilling(filling);

   bool sent = false;
   double price = 0.0;
   if(winnerType == POSITION_TYPE_BUY)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sent = trade.Buy(lot, _Symbol, 0.0, sl, tp, comment);
   }
   else
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sent = trade.Sell(lot, _Symbol, 0.0, sl, tp, comment);
   }

   ulong resultOrder = trade.ResultOrder();
   ulong resultDeal = trade.ResultDeal();
   uint retcode = trade.ResultRetcode();
   ulong layerTicket = 0;

   if(resultDeal > 0 && HistoryDealSelect(resultDeal))
   {
      ulong positionId = (ulong)HistoryDealGetInteger(resultDeal, DEAL_POSITION_ID);
      layerTicket = V10_FindOpenPositionTicketByPositionId(positionId, _Symbol, MagicNumber);
   }
   if(layerTicket == 0)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
         if((long)PositionGetInteger(POSITION_TYPE) != (long)winnerType) continue;
         if(PositionGetString(POSITION_COMMENT) != comment) continue;
         if(MathAbs(PositionGetDouble(POSITION_VOLUME) - lot) > 0.000001) continue;
         layerTicket = ticket;
         break;
      }
   }

   if(sent && layerTicket > 0)
   {
      string role = (g_stage17ApprovedLayerNumber == 1 ? "LAYER_1" : "RUNNER");
      if(PositionSelectByTicket(layerTicket))
         AssignRoleV4(layerTicket, role, (datetime)PositionGetInteger(POSITION_TIME), PositionGetDouble(POSITION_PRICE_OPEN), PositionGetDouble(POSITION_VOLUME), "STAGE17_WINNER_LAYER");
      V10_PostOrderCapture(resultDeal, resultOrder, "Stage17_OpenWinnerLayer");
      if(g_stage17ApprovedLayerNumber == 1)
      {
         g_stage17Pair.winnerLayer1Opened = true;
         g_stage17Pair.winnerLayer1Ticket = layerTicket;
         g_stage17Pair.winnerLayer1Alive = true;
         g_stage17Pair.winnerLayer1Closed = false;
         g_stage17Pair.winnerLayer1Failed = false;
         g_stage17Pair.winnerLayer1Profit = 0.0;
         g_stage17Pair.winnerLayer1MFE = 0.0;
      }
      if(g_stage17ApprovedLayerNumber == 2) g_stage17Pair.winnerLayer2Opened = true;
   }

   if(Stage17_DebugLogs)
      Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_ORDER_RESULT_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
            " orderType=WINNER_LAYER side=", sideText,
            " lot=", DoubleToString(lot,2),
            " success=", BoolToText(sent && layerTicket > 0),
            " retcode=", IntegerToString((int)retcode),
            " ticket=", UlongToText(layerTicket),
            " price=", DoubleToString(price,_Digits),
            " reason=STAGE17_OPEN_WINNER_LAYER_", IntegerToString(g_stage17ApprovedLayerNumber));

   return (sent && layerTicket > 0);
}

bool Stage17_PairEntryQualityGate()
{
   if(!UseStage17DualSideConfirmation)
      return false;
   if(!Stage17_EnablePairEntryQualityGate)
      return true;

   long nextPairId = g_stage17NextPairId + 1;
   string regimeReason = "";
   ENUM_HORSE_MARKET_REGIME regime = HorseDetectMarketRegime(regimeReason);
   double adx = V32GetADX((ENUM_TIMEFRAMES)_Period, 14, 1);
   double atrPoints = g_atrM1Points;
   int spread = GetCurrentSpreadPoints();
   double buyScore = HorseCalculateBuyScore();
   double sellScore = HorseCalculateSellScore();
   double directionGap = MathAbs(buyScore - sellScore);
   double dominantScore = MathMax(buyScore, sellScore);
   double momentum = g_momentumScore;
   double directionalStrength = MathMax(g_buyStrengthScore, g_sellStrengthScore);
   string flowState = g_flowDirectionText;

   bool trendRegimeOK = (regime == HORSE_TREND_STRONG_BULL || regime == HORSE_TREND_STRONG_BEAR ||
                         regime == HORSE_TREND_MODERATE_BULL || regime == HORSE_TREND_MODERATE_BEAR);
   bool expansionRegimeOK = (regime == HORSE_EXPANSION);
   bool weakTrendRegime = (regime == HORSE_TREND_WEAK_BULL || regime == HORSE_TREND_WEAK_BEAR);
   bool runnerPotential = ((trendRegimeOK || expansionRegimeOK) &&
                           dominantScore >= AdaptiveDirectionMinValidScoreV4 &&
                           directionGap >= Stage17_MinDirectionGapForPair &&
                           adx >= Stage17_MinADXForPair &&
                           momentum >= Stage17_MinMomentumForPair);

   bool pairAllowed = true;
   string reason = "ALLOW";

   if(spread > Stage17_MaxSpreadForPair)
   {
      pairAllowed = false;
      reason = "SPREAD_TOO_HIGH_FOR_PAIR";
   }
   else if(atrPoints <= 0.0)
   {
      pairAllowed = false;
      reason = "ATR_DATA_NOT_READY";
   }
   else if(Stage17_MinATRForPair > 0.0 && atrPoints < Stage17_MinATRForPair)
   {
      pairAllowed = false;
      reason = "ATR_TOO_LOW";
   }
   else if(Stage17_MaxATRForPair > 0.0 && atrPoints > Stage17_MaxATRForPair)
   {
      pairAllowed = false;
      reason = "ATR_TOO_HIGH";
   }
   else if(Stage17_BlockPairInChoppy && (regime == HORSE_CHOPPY || g_market.mode == MARKET_ERRATIC))
   {
      pairAllowed = false;
      reason = "CHOPPY_MARKET_BLOCK";
   }
   else if(Stage17_BlockPairInRange && (regime == HORSE_RANGE || g_market.mode == MARKET_SIDEWAYS))
   {
      pairAllowed = false;
      reason = "RANGE_MARKET_BLOCK";
   }
   else if(g_market.mode == MARKET_DEAD || g_market.mode == MARKET_UNKNOWN || g_market.mode == MARKET_SPREAD_DANGER)
   {
      pairAllowed = false;
      reason = "MARKET_MODE_DEAD_OR_DANGER";
   }
   else if(weakTrendRegime)
   {
      pairAllowed = false;
      reason = "WEAK_TREND_BLOCK";
   }
   else if(regime == HORSE_COMPRESSION || regime == HORSE_REVERSAL_RISK || regime == HORSE_NEUTRAL)
   {
      pairAllowed = false;
      reason = "NO_EXPANSION_REGIME";
   }
   else if(adx < Stage17_MinADXForPair)
   {
      pairAllowed = false;
      reason = "ADX_TOO_WEAK";
   }
   else if(momentum < Stage17_MinMomentumForPair)
   {
      pairAllowed = false;
      reason = "MOMENTUM_TOO_WEAK";
   }
   else if(directionalStrength < Stage17_MinDirectionalStrengthForPair)
   {
      pairAllowed = false;
      reason = "DIRECTIONAL_STRENGTH_TOO_LOW";
   }
   else if(g_flow.direction == FLOW_BALANCED)
   {
      pairAllowed = false;
      reason = "FLOW_BALANCED_NO_DOMINANCE";
   }
   else if(g_flow.direction == FLOW_DANGEROUS)
   {
      pairAllowed = false;
      reason = "FLOW_DANGEROUS";
   }
   else if(directionGap < Stage17_MinDirectionGapForPair)
   {
      pairAllowed = false;
      reason = "DIRECTION_GAP_TOO_SMALL";
   }
   else if(dominantScore < AdaptiveDirectionMinValidScoreV4)
   {
      pairAllowed = false;
      reason = "DOMINANT_SCORE_TOO_LOW";
   }
   else if(Stage17_RequireRunnerPotentialForPair && !runnerPotential)
   {
      pairAllowed = false;
      reason = "NO_RUNNER_POTENTIAL";
   }

   if(Stage17_DebugLogs)
   {
      string common = StringFormat("pairId=%d time=%s regime=%s adx=%.1f atr=%.1f spread=%d buyScore=%.1f sellScore=%.1f directionGap=%.1f flowState=%s momentum=%.1f directionalStrength=%.1f runnerPotential=%s basketProfit=0.00 elapsedSeconds=0 buyMFE=0.00 sellMFE=0.00 winnerConfirmed=%s survivorUnconfirmed=%s pairAllowed=%s reason=%s",
                                   (int)nextPairId,
                                   TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
                                   HorseMarketRegimeToText(regime),
                                   adx, atrPoints, spread,
                                   buyScore, sellScore, directionGap,
                                   flowState, momentum, directionalStrength,
                                   BoolToText(runnerPotential),
                                   BoolToText(g_stage17Pair.winnerConfirmed),
                                   BoolToText(g_stage17Pair.survivorUnconfirmed),
                                   BoolToText(pairAllowed),
                                   reason);
      Print("[HORSE EA][STAGE17_DUAL_SIDE] [STAGE17_PAIR_ENTRY_QUALITY_CHECK] ", common);
      if(pairAllowed)
         Print("[HORSE EA][STAGE17_DUAL_SIDE] [STAGE17_PAIR_ENTRY_ALLOWED] ", common);
      else if(reason == "NO_RUNNER_POTENTIAL")
         Print("[HORSE EA][STAGE17_DUAL_SIDE] [STAGE17_PAIR_ENTRY_BLOCKED_NO_RUNNER_POTENTIAL] ", common);
      else
         Print("[HORSE EA][STAGE17_DUAL_SIDE] [STAGE17_PAIR_ENTRY_BLOCKED_BAD_MARKET] ", common);
   }

   return pairAllowed;
}

bool Stage17_NoWinnerFastAbort()
{
   if(!UseStage17DualSideConfirmation || !Stage17_EnableNoWinnerFastAbort)
      return false;
   if(g_stage17Pair.pairId <= 0)
      return false;
   if(g_stage17Pair.pairState != STAGE17_PAIR_ACTIVE)
      return false;
   if(g_stage17Pair.weakClosed || g_stage17Pair.winnerConfirmed || g_stage17Pair.decisionMade)
      return false;

   bool buyOpen = (g_stage17Pair.buyTicket > 0 && PositionSelectByTicket(g_stage17Pair.buyTicket));
   bool sellOpen = (g_stage17Pair.sellTicket > 0 && PositionSelectByTicket(g_stage17Pair.sellTicket));
   if(!buyOpen || !sellOpen)
      return false;

   int elapsedSeconds = (int)(TimeCurrent() - g_stage17Pair.openTime);
   double buyProfit = CurrentPositionProfitMoneyV4(g_stage17Pair.buyTicket);
   double sellProfit = CurrentPositionProfitMoneyV4(g_stage17Pair.sellTicket);
   double buyMFE = GetTicketExitPeakMoneyV4(g_stage17Pair.buyTicket);
   double sellMFE = GetTicketExitPeakMoneyV4(g_stage17Pair.sellTicket);
   double basketProfit = buyProfit + sellProfit;
   int spread = GetCurrentSpreadPoints();

   // never abort against a side that already shows real winner/runner progress
   bool anySideHasMFE = (buyMFE >= Stage17_NoWinnerFastAbortMinMFE || sellMFE >= Stage17_NoWinnerFastAbortMinMFE);
   bool anySideProfitable = (buyProfit >= Stage17_StrongSideMinProfitMoney || sellProfit >= Stage17_StrongSideMinProfitMoney);

   bool costBleed = (basketProfit <= Stage17_NoWinnerFastAbortMaxBasketLoss);
   bool timeoutNoWinner = (elapsedSeconds >= Stage17_NoWinnerFastAbortSeconds && basketProfit < 0.0);
   bool abortPair = (!anySideHasMFE && !anySideProfitable && (costBleed || timeoutNoWinner));
   string reason = "HOLD_PAIR";
   if(anySideHasMFE || anySideProfitable)
      reason = "SIDE_SHOWS_WINNER_PROGRESS";
   else if(costBleed)
      reason = "BASKET_COST_BLEED";
   else if(timeoutNoWinner)
      reason = "NO_WINNER_TIMEOUT_FAST";

   if(Stage17_DebugLogs)
   {
      double adx = V32GetADX((ENUM_TIMEFRAMES)_Period, 14, 1);
      string common = StringFormat("pairId=%d time=%s regime=%s adx=%.1f atr=%.1f spread=%d buyScore=%.1f sellScore=%.1f directionGap=%.1f flowState=%s momentum=%.1f directionalStrength=%.1f runnerPotential=%s basketProfit=%.2f elapsedSeconds=%d buyMFE=%.2f sellMFE=%.2f winnerConfirmed=%s survivorUnconfirmed=%s pairAllowed=%s reason=%s",
                                   (int)g_stage17Pair.pairId,
                                   TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
                                   MarketModeToText(g_market.mode),
                                   adx, g_atrM1Points, spread,
                                   g_buyStrengthScore, g_sellStrengthScore,
                                   MathAbs(g_buyStrengthScore - g_sellStrengthScore),
                                   g_flowDirectionText, g_momentumScore,
                                   MathMax(g_buyStrengthScore, g_sellStrengthScore),
                                   BoolToText(anySideHasMFE || anySideProfitable),
                                   basketProfit, elapsedSeconds, buyMFE, sellMFE,
                                   BoolToText(g_stage17Pair.winnerConfirmed),
                                   BoolToText(g_stage17Pair.survivorUnconfirmed),
                                   BoolToText(!abortPair),
                                   reason);
      Print("[HORSE EA][STAGE17_DUAL_SIDE] [STAGE17_NO_WINNER_FAST_ABORT_CHECK] ", common);
      if(abortPair && costBleed)
         Print("[HORSE EA][STAGE17_DUAL_SIDE] [STAGE17_PAIR_COST_BLEED_DETECTED] ", common);
      if(abortPair)
         Print("[HORSE EA][STAGE17_DUAL_SIDE] [STAGE17_NO_WINNER_FAST_ABORT_CLOSE] ", common);
   }

   if(!abortPair)
      return false;

   return Stage17_CloseBothNoWinner();
}

void Stage17_DualSideOnTick()
{
   if(!UseStage17DualSideConfirmation)
      return;

   Stage17_UpdatePairState();
   bool activePair = (g_stage17Pair.pairId > 0 &&
                      (g_stage17Pair.pairState == STAGE17_PAIR_ACTIVE ||
                       g_stage17Pair.pairState == STAGE17_PAIR_DECIDED_WEAK_CLOSED));

   if(activePair)
   {
      g_stage17LegacyBlockThisTick = true;
      Stage17_CompareSides();
      Stage17_UpdatePairState();
      if(g_stage17Pair.pairState == STAGE17_PAIR_ACTIVE &&
         !g_stage17Pair.weakClosed && !g_stage17Pair.winnerConfirmed)
      {
         if(Stage17_NoWinnerFastAbort())
            Stage17_UpdatePairState();
      }
      if(g_stage17Pair.pairState == STAGE17_PAIR_DECIDED_WEAK_CLOSED)
      {
         Stage17_ProfitExtractionManager();
         if(Stage17_CanOpenWinnerLayer())
            Stage17_OpenWinnerLayer();
      }
      return;
   }

   if(Stage17_CanOpenPair() && Stage17_PairEntryQualityGate())
      Stage17_OpenPair();
}


void Stage15_UpdateWallboard()
{
   if(!Stage15_ShowWallboard) return;
   int row = 0;
   AddDashboardLine(row, "HORSE EA - STAGE 15 SMART DYNAMIC EXIT ENGINE");
   AddDashboardLine(row, "Dynamic Exit Active: " + BoolToText(UseStage15SmartDynamicExitEngine));
   AddDashboardLine(row, "Disable Fixed TP: " + BoolToText(Stage15_DisableFixedServerTP));
   AddDashboardLine(row, "Dynamic Server SL: " + BoolToText(Stage15_UseDynamicServerSL));
   AddDashboardLine(row, "ATR Points: " + DoubleToString(Stage15_ATRPoints(),1));
   AddDashboardLine(row, "Last Action: " + g_stage15LastAction);
   AddDashboardLine(row, "Last Reason: " + g_stage15LastReason);
   AddDashboardLine(row, "Last Ticket: " + UlongToText(g_stage15LastTicket));
   AddDashboardLine(row, "Last ExitScore: " + DoubleToString(g_stage15LastExitScore,1));
   AddDashboardLine(row, "Modify Count: " + IntegerToString(g_stage15ModifyCount));
   AddDashboardLine(row, "BE Count: " + IntegerToString(g_stage15BECount));
   AddDashboardLine(row, "Trail Count: " + IntegerToString(g_stage15TrailCount));
   AddDashboardLine(row, "Weak Exit Requests: " + IntegerToString(g_stage15WeakExitRequests));
   AddDashboardLine(row, "Time Exit Requests: " + IntegerToString(g_stage15TimeExitRequests));
}

//+------------------------------------------------------------------+
//| STAGE 14 - SMART EXIT AUTHORITY INTEGRATION                     |
//| Central authority for all exits / closes                         |
//+------------------------------------------------------------------+

input bool UseStage14SmartExitAuthority      = true;
input bool Stage14_ShowWallboard             = true;
input bool Stage14_BlockDuplicateExitSameTick= true;
input bool Stage14_LogEveryExitRequest       = true;
input int  Stage14_MaxPendingExitRequests    = 64;
input int  Stage14_DuplicateExitSeconds      = 2;

enum STAGE14_EXIT_STATE
{
   EXIT_STATE_IDLE = 0,
   EXIT_STATE_MONITORING = 1,
   EXIT_STATE_PROFIT_PROTECTION = 2,
   EXIT_STATE_HEDGE_RESOLUTION = 3,
   EXIT_STATE_WEAKNESS = 4,
   EXIT_STATE_TIME_EXIT = 5,
   EXIT_STATE_RUNNER = 6,
   EXIT_STATE_RISK_EXIT = 7,
   EXIT_STATE_EMERGENCY = 8,
   EXIT_STATE_LOCKED = 9
};

struct Stage14ExitRequest
{
   ulong    ticket;
   string   reason;
   int      priority;
   double   profit;
   double   volume;
   datetime timestamp;
   string   module;
   bool     active;
};

STAGE14_EXIT_STATE g_stage14ExitState = EXIT_STATE_IDLE;
Stage14ExitRequest g_stage14ExitQueue[];
int      g_stage14ExitRequestID = 0;
int      g_stage14ExitExecutionID = 0;
ulong    g_stage14LastExitTicket = 0;
datetime g_stage14LastExitTime = 0;
string   g_stage14LastExitReason = "INIT";
string   g_stage14LastExitModule = "INIT";
int      g_stage14LastExitPriority = 999;
int      g_stage14DuplicateExitBlocked = 0;
int      g_stage14PendingExitRequests = 0;

bool g_stage14CanExitMain = true;
bool g_stage14CanExitLayer1 = true;
bool g_stage14CanExitRunner = true;
bool g_stage14CanExitBasket = true;
bool g_stage14CanResolveHedge = true;
bool g_stage14CanEmergencyExit = true;
bool g_stage14CanProfitLock = true;
bool g_stage14CanWeaknessExit = true;
bool g_stage14CanTimeExit = true;

void Stage14_Log(string msg)
{
   if(PrintDetailedLogs)
      Print("[HORSE EA][STAGE14_EXIT_AUTHORITY] ", msg);
}

string Stage14_ExitStateText()
{
   switch(g_stage14ExitState)
   {
      case EXIT_STATE_IDLE: return "IDLE";
      case EXIT_STATE_MONITORING: return "MONITORING";
      case EXIT_STATE_PROFIT_PROTECTION: return "PROFIT_PROTECTION";
      case EXIT_STATE_HEDGE_RESOLUTION: return "HEDGE_RESOLUTION";
      case EXIT_STATE_WEAKNESS: return "WEAKNESS";
      case EXIT_STATE_TIME_EXIT: return "TIME_EXIT";
      case EXIT_STATE_RUNNER: return "RUNNER";
      case EXIT_STATE_RISK_EXIT: return "RISK_EXIT";
      case EXIT_STATE_EMERGENCY: return "EMERGENCY";
      case EXIT_STATE_LOCKED: return "LOCKED";
   }
   return "UNKNOWN";
}

string Stage14_Upper(string s)
{
   string x = s;
   StringToUpper(x);
   return x;
}

bool Stage14_IsEmergencyReason(string reason)
{
   string r = Stage14_Upper(reason);
   if(StringFind(r, "EMERGENCY") >= 0) return true;
   if(StringFind(r, "HARD_RISK") >= 0) return true;
   if(StringFind(r, "DD") >= 0 && StringFind(r, "STOP") >= 0) return true;
   if(StringFind(r, "SL_HIT") >= 0) return true;
   if(StringFind(r, "BASKET_EMERGENCY") >= 0) return true;
   return false;
}

int Stage14_PriorityFromReason(string reason)
{
   string r = Stage14_Upper(reason);
   if(Stage14_IsEmergencyReason(r)) return 0;
   if(StringFind(r, "RISK") >= 0 || StringFind(r, "DAILY") >= 0 || StringFind(r, "WEEKLY") >= 0 || StringFind(r, "EQUITY") >= 0) return 1;
   if(StringFind(r, "HEDGE") >= 0 || StringFind(r, "RESOLVER") >= 0 || StringFind(r, "ROTATION") >= 0) return 2;
   if(StringFind(r, "PROFIT") >= 0 || StringFind(r, "LOCK") >= 0 || StringFind(r, "TRAIL") >= 0 || StringFind(r, "BREAK_EVEN") >= 0 || StringFind(r, "GIVEBACK") >= 0) return 3;
   if(StringFind(r, "WEAK") >= 0 || StringFind(r, "REVERSAL") >= 0 || StringFind(r, "MOMENTUM") >= 0 || StringFind(r, "SMART_EXIT") >= 0) return 4;
   if(StringFind(r, "TIME") >= 0 || StringFind(r, "NO_PROGRESS") >= 0 || StringFind(r, "STALL") >= 0) return 5;
   if(StringFind(r, "RUNNER") >= 0) return 6;
   return 4;
}

STAGE14_EXIT_STATE Stage14_StateFromPriority(int priority, string reason)
{
   if(priority == 0) return EXIT_STATE_EMERGENCY;
   if(priority == 1) return EXIT_STATE_RISK_EXIT;
   if(priority == 2) return EXIT_STATE_HEDGE_RESOLUTION;
   if(priority == 3) return EXIT_STATE_PROFIT_PROTECTION;
   if(priority == 5) return EXIT_STATE_TIME_EXIT;
   if(priority == 6) return EXIT_STATE_RUNNER;
   return EXIT_STATE_WEAKNESS;
}

bool Stage14_IsDuplicateExit(ulong ticket, string reason, int priority)
{
   if(ticket == 0) return false;
   if(priority == 0) return false; // emergency is always allowed to attempt close

   if(g_stage14LastExitTicket == ticket && (TimeCurrent() - g_stage14LastExitTime) <= Stage14_DuplicateExitSeconds)
      return true;

   for(int i=0; i<ArraySize(g_stage14ExitQueue); i++)
   {
      if(!g_stage14ExitQueue[i].active) continue;
      if(g_stage14ExitQueue[i].ticket != ticket) continue;
      if((TimeCurrent() - g_stage14ExitQueue[i].timestamp) <= Stage14_DuplicateExitSeconds)
         return true;
   }
   return false;
}

void Stage14_AddExitRequest(ulong ticket, string module, string reason, int priority, double profit, double volume)
{
   if(ArraySize(g_stage14ExitQueue) <= 0)
      ArrayResize(g_stage14ExitQueue, Stage14_MaxPendingExitRequests);

   int slot = -1;
   for(int i=0; i<ArraySize(g_stage14ExitQueue); i++)
   {
      if(!g_stage14ExitQueue[i].active)
      {
         slot = i;
         break;
      }
   }

   if(slot < 0)
   {
      // overwrite oldest non-emergency request if queue is full
      slot = 0;
      datetime oldest = g_stage14ExitQueue[0].timestamp;
      for(int j=1; j<ArraySize(g_stage14ExitQueue); j++)
      {
         if(g_stage14ExitQueue[j].timestamp < oldest)
         {
            oldest = g_stage14ExitQueue[j].timestamp;
            slot = j;
         }
      }
   }

   g_stage14ExitQueue[slot].ticket = ticket;
   g_stage14ExitQueue[slot].module = module;
   g_stage14ExitQueue[slot].reason = reason;
   g_stage14ExitQueue[slot].priority = priority;
   g_stage14ExitQueue[slot].profit = profit;
   g_stage14ExitQueue[slot].volume = volume;
   g_stage14ExitQueue[slot].timestamp = TimeCurrent();
   g_stage14ExitQueue[slot].active = true;
   g_stage14ExitRequestID++;

   g_stage14PendingExitRequests = 0;
   for(int k=0; k<ArraySize(g_stage14ExitQueue); k++)
      if(g_stage14ExitQueue[k].active) g_stage14PendingExitRequests++;
}

void Stage14_MarkExitExecuted(ulong ticket, string module, string reason, int priority)
{
   g_stage14ExitExecutionID++;
   g_stage14LastExitTicket = ticket;
   g_stage14LastExitTime = TimeCurrent();
   g_stage14LastExitReason = reason;
   g_stage14LastExitModule = module;
   g_stage14LastExitPriority = priority;
   g_stage14ExitState = Stage14_StateFromPriority(priority, reason);

   for(int i=0; i<ArraySize(g_stage14ExitQueue); i++)
      if(g_stage14ExitQueue[i].active && g_stage14ExitQueue[i].ticket == ticket)
         g_stage14ExitQueue[i].active = false;
}

bool Stage14_AuthorizeExit(ulong ticket, string module, string reason, double profit, double volume, string &denyReason)
{
   denyReason = "STAGE14_EXIT_ALLOWED";

   if(!UseStage14SmartExitAuthority)
      return true;

   if(!PositionSelectByTicket(ticket))
   {
      denyReason = "STAGE14_POSITION_NOT_FOUND";
      return false;
   }

   int priority = Stage14_PriorityFromReason(module + "_" + reason);
   g_stage14ExitState = Stage14_StateFromPriority(priority, reason);

   if(Stage14_BlockDuplicateExitSameTick && Stage14_IsDuplicateExit(ticket, reason, priority))
   {
      g_stage14DuplicateExitBlocked++;
      denyReason = "STAGE14_DUPLICATE_EXIT_BLOCKED ticket=" + UlongToText(ticket) + " reason=" + reason;
      Stage14_Log(denyReason);
      return false;
   }

   string role = GetRoleForTicketV4(ticket);
   if(role == "MAIN" && !g_stage14CanExitMain && priority > 0)
   {
      denyReason = "STAGE14_MAIN_EXIT_NOT_ALLOWED";
      return false;
   }
   if(role == "LAYER_1" && !g_stage14CanExitLayer1 && priority > 0)
   {
      denyReason = "STAGE14_LAYER_EXIT_NOT_ALLOWED";
      return false;
   }
   if(role == "RUNNER" && !g_stage14CanExitRunner && priority > 0)
   {
      denyReason = "STAGE14_RUNNER_EXIT_NOT_ALLOWED";
      return false;
   }

   Stage14_AddExitRequest(ticket, module, reason, priority, profit, volume);

   if(Stage14_LogEveryExitRequest)
   {
      Stage14_Log("REQUEST ticket=" + UlongToText(ticket) +
                  " module=" + module +
                  " reason=" + reason +
                  " priority=" + IntegerToString(priority) +
                  " profit=" + DoubleToString(profit,2) +
                  " role=" + role +
                  " state=" + Stage14_ExitStateText());
   }

   denyReason = "STAGE14_EXIT_APPROVED priority=" + IntegerToString(priority);
   return true;
}

void Stage14_AuditExitExecution(ulong ticket, string module, string reason, bool ok)
{
   if(!UseStage14SmartExitAuthority) return;

   string mode = (MQLInfoInteger(MQL_TESTER) ? "BACKTEST" : "LIVE");
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double profit = 0.0;
   if(PositionSelectByTicket(ticket)) profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

   Stage14_Log(mode +
               " EXECUTION ticket=" + UlongToText(ticket) +
               " module=" + module +
               " reason=" + reason +
               " ok=" + BoolToText(ok) +
               " state=" + Stage14_ExitStateText() +
               " equity=" + DoubleToString(eq,2) +
               " balance=" + DoubleToString(bal,2) +
               " spread=" + IntegerToString(spread) +
               " profit=" + DoubleToString(profit,2));
}

void Stage14_UpdateWallboard()
{
   if(!Stage14_ShowWallboard) return;

   int row = 0;
   AddDashboardLine(row, "HORSE EA - STAGE 14 SMART EXIT AUTHORITY");
   AddDashboardLine(row, "Exit State: " + Stage14_ExitStateText());
   AddDashboardLine(row, "Last Exit Module: " + g_stage14LastExitModule);
   AddDashboardLine(row, "Last Exit Reason: " + g_stage14LastExitReason);
   AddDashboardLine(row, "Last Exit Ticket: " + UlongToText(g_stage14LastExitTicket));
   AddDashboardLine(row, "Last Exit Time: " + (g_stage14LastExitTime > 0 ? TimeToString(g_stage14LastExitTime, TIME_DATE | TIME_SECONDS) : "NONE"));
   AddDashboardLine(row, "Last Exit Priority: " + IntegerToString(g_stage14LastExitPriority));
   AddDashboardLine(row, "Pending Exit Requests: " + IntegerToString(g_stage14PendingExitRequests));
   AddDashboardLine(row, "Exit Request ID: " + IntegerToString(g_stage14ExitRequestID));
   AddDashboardLine(row, "Exit Execution ID: " + IntegerToString(g_stage14ExitExecutionID));
   AddDashboardLine(row, "Duplicate Exit Blocked: " + IntegerToString(g_stage14DuplicateExitBlocked));
   AddDashboardLine(row, "CanExitMain: " + BoolToText(g_stage14CanExitMain));
   AddDashboardLine(row, "CanExitLayer1: " + BoolToText(g_stage14CanExitLayer1));
   AddDashboardLine(row, "CanExitRunner: " + BoolToText(g_stage14CanExitRunner));
   AddDashboardLine(row, "CanResolveHedge: " + BoolToText(g_stage14CanResolveHedge));
   AddDashboardLine(row, "CanEmergencyExit: " + BoolToText(g_stage14CanEmergencyExit));
   AddDashboardLine(row, "Mode: " + string(MQLInfoInteger(MQL_TESTER) ? "BACKTEST" : "LIVE"));
}


bool RequestV4ExitOrchestrator(ulong ticket, string module, string reason, double netProfit, bool isCriticalExit, bool isSevereReversal)
{
   if(!PositionSelectByTicket(ticket))
   {
      AuditV4("[V4_CLOSE_TRACE] REQUEST_REJECTED ticket=" + UlongToText(ticket) + " module=" + module + " reason=" + reason + " error=POSITION_NOT_FOUND");
      AuditSmartExit("[V4_CLOSE_TRACE] REQUEST_REJECTED ticket=" + UlongToText(ticket) + " module=" + module + " reason=" + reason + " error=POSITION_NOT_FOUND");
      return false;
   }

   double currentNetProfit = CurrentPositionProfitMoneyV4(ticket);
   if(MathAbs(currentNetProfit - netProfit) > 0.01)
      netProfit = currentNetProfit;

   string finalReason = module + "_" + reason;

   AuditV4("[V4_CLOSE_TRACE] REQUEST_RECEIVED ticket=" + UlongToText(ticket) + " module=" + module + " reason=" + reason + " netProfit=" + DoubleToString(netProfit,2));
   AuditSmartExit("[V4_CLOSE_TRACE] REQUEST_RECEIVED ticket=" + UlongToText(ticket) + " module=" + module + " reason=" + reason + " netProfit=" + DoubleToString(netProfit,2));

   ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   if(!isSevereReversal && netProfit > 0.0 && netProfit < MinProfitToAllowPositiveCloseV4)
      isSevereReversal = IsSevereReversalV4(ticket, pt);

   if(IsCriticalExitReasonTextV4(reason) || IsCriticalExitReasonTextV4(finalReason))
      isCriticalExit = true;

   AuditV4("[V4_CLOSE_TRACE] BEFORE_PROFIT_HOLD ticket=" + UlongToText(ticket) + " reason=" + finalReason + " netProfit=" + DoubleToString(netProfit,2));
   AuditSmartExit("[V4_CLOSE_TRACE] BEFORE_PROFIT_HOLD ticket=" + UlongToText(ticket) + " reason=" + finalReason + " netProfit=" + DoubleToString(netProfit,2));

   if(isCriticalExit)
   {
      AuditV4("[V4_EXIT_ORCHESTRATOR] CRITICAL_EXIT_BYPASS_PROFIT_HOLD ticket=" + UlongToText(ticket) + " reason=" + finalReason);
      AuditSmartExit("[V4_EXIT_ORCHESTRATOR] CRITICAL_EXIT_BYPASS_PROFIT_HOLD ticket=" + UlongToText(ticket) + " reason=" + finalReason);
      AuditV4("[V4_CLOSE_TRACE] PROFIT_HOLD_RESULT ticket=" + UlongToText(ticket) + " allowed=TRUE reason=CRITICAL_EXIT");
      return ClosePositionV4(ticket, finalReason);
   }

   if(isSevereReversal)
   {
      AuditV4("[V4_CLOSE_TRACE] PROFIT_HOLD_RESULT ticket=" + UlongToText(ticket) + " allowed=TRUE reason=SEVERE_REVERSAL");
      AuditSmartExit("[V4_CLOSE_TRACE] PROFIT_HOLD_RESULT ticket=" + UlongToText(ticket) + " allowed=TRUE reason=SEVERE_REVERSAL");
      return ClosePositionV4(ticket, finalReason + "_SEVERE_REVERSAL");
   }

   bool profitHoldBlocked = ShouldBlockMicroProfitCloseV4(ticket, finalReason);
   AuditV4("[V4_CLOSE_TRACE] PROFIT_HOLD_RESULT ticket=" + UlongToText(ticket) + " allowed=" + BoolToText(!profitHoldBlocked) + " reason=" + (profitHoldBlocked ? "MICRO_PROFIT_HOLD_BLOCKED" : "ALLOWED"));
   AuditSmartExit("[V4_CLOSE_TRACE] PROFIT_HOLD_RESULT ticket=" + UlongToText(ticket) + " allowed=" + BoolToText(!profitHoldBlocked) + " reason=" + (profitHoldBlocked ? "MICRO_PROFIT_HOLD_BLOCKED" : "ALLOWED"));

   if(profitHoldBlocked)
   {
      AuditV4("[V4_EXIT_ORCHESTRATOR] WEAK_EXIT_BLOCKED_MICRO_PROFIT ticket=" + UlongToText(ticket) + " module=" + module + " reason=" + reason + " netProfit=" + DoubleToString(netProfit,2));
      AuditSmartExit("[V4_EXIT_ORCHESTRATOR] WEAK_EXIT_BLOCKED_MICRO_PROFIT ticket=" + UlongToText(ticket) + " module=" + module + " reason=" + reason + " netProfit=" + DoubleToString(netProfit,2));
      return false;
   }

   // FIX3.2: only this path may execute a legacy-requested close, and it delegates to the V4 Orchestrator.
   return ClosePositionV4(ticket, finalReason);
}

bool IsTradeStallingV4(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return false;
   string role = GetRoleForTicketV4(ticket);
   datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double current = (pt == POSITION_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK));
   double points = MathAbs(current - openPrice) / _Point;
   int age = (int)(TimeCurrent() - openTime);
   double profit = CurrentPositionProfitMoneyV4(ticket);
   if(profit > TimeNoProgressIgnoreIfProfitV4)
   {
      AuditV4("[V4_TIME_EXIT] POSITIVE_TRADE_NO_PROGRESS_IGNORED ticket=" + UlongToText(ticket) + " profit=" + DoubleToString(profit,2));
      return false;
   }
   if(age < TimeNoProgressMinSecondsV4)
   {
      AuditV4("[V4_TIME_EXIT] TOO_EARLY_BLOCKED ticket=" + UlongToText(ticket) + " age=" + IntegerToString(age));
      return false;
   }
   if(profit > 0.0)
   {
      AuditV4("[V4_TIME_EXIT] POSITIVE_TRADE_NO_PROGRESS_IGNORED ticket=" + UlongToText(ticket) + " profit=" + DoubleToString(profit,2));
      return false;
   }
   if(role == "MAIN" && age >= MaxSecondsMainNoProgressV4 && points < MainMinProgressPointsV4 && profit <= TimeNoProgressMinAdverseMoneyV4) { AuditV4("[V4_TIME_EXIT] CLOSE_ALLOWED_NEGATIVE_STALLED ticket=" + UlongToText(ticket)); return true; }
   if(role == "LAYER_1" && age >= MaxSecondsLayerNoProgressV4 && points < LayerMinProgressPointsV4 && profit <= TimeNoProgressMinAdverseMoneyV4) { AuditV4("[V4_TIME_EXIT] CLOSE_ALLOWED_NEGATIVE_STALLED ticket=" + UlongToText(ticket)); return true; }
   if(role == "RUNNER" && age >= SmartExitNoProgressSecondsV4 && points < RunnerMinProgressPointsV4 && profit <= TimeNoProgressMinAdverseMoneyV4) { AuditV4("[V4_TIME_EXIT] CLOSE_ALLOWED_NEGATIVE_STALLED ticket=" + UlongToText(ticket)); return true; }
   return false;
}

bool IsM5M15FullyAgainstV4(ENUM_POSITION_TYPE direction)
{
   ENUM_ORDER_TYPE od = (direction == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   double t5 = TrendScoreSimpleV4(od, PERIOD_M5);
   double t15 = TrendScoreSimpleV4(od, PERIOD_M15);
   return (t5 < 0.0 && t15 < 0.0);
}

bool IsTrendSupportiveV4(ENUM_POSITION_TYPE direction)
{
   double maFast = V32GetMA((ENUM_TIMEFRAMES)_Period, 9, 1);
   double maSlow = V32GetMA((ENUM_TIMEFRAMES)_Period, 21, 1);
   bool emaOK = false;
   if(direction == POSITION_TYPE_BUY) emaOK = (maFast > maSlow);
   if(direction == POSITION_TYPE_SELL) emaOK = (maFast < maSlow);
   double adx = MathMax(V32GetADX(PERIOD_M5, 14, 1), V32GetADX(PERIOD_M15, 14, 1));
   return (emaOK && adx >= 18.0 && !IsM5M15FullyAgainstV4(direction) && GetCurrentSpreadPoints() <= MaxSpreadForSmartExitV4);
}

bool IsRunnerStrongV4(ulong ticket, ENUM_POSITION_TYPE direction)
{
   if(!PositionSelectByTicket(ticket)) return false;
   double profit = CurrentPositionProfitMoneyV4(ticket);
   double peak = GetTicketExitPeakMoneyV4(ticket);
   bool profitOK = (profit > 0.0);
   bool peakOK = (peak >= profit && peak > 0.0);
   bool momentumOK = IsMomentumStillValidV4(direction) || IsTrendSupportiveV4(direction);
   bool m5OK = !IsM5M15FullyAgainstV4(direction);
   bool spreadOK = (GetCurrentSpreadPoints() <= MaxSpreadForSmartExitV4);

   // V7: Runner grande (profit >= $80) recebe proteÃ§Ã£o extra.
   // NÃ£o fecha por falta de momentum pontual â€” sÃ³ fecha por reversÃ£o severa.
   // Isso permite capturar os $500â€“800 quando o mercado realmente anda.
   if(profitOK && profit >= 80.0 && peakOK && spreadOK)
      return true;  // runner grande: protege independente de momentum momentÃ¢neo

   return (profitOK && peakOK && momentumOK && m5OK && spreadOK);
}

bool IsProfitGivebackDangerV4(ulong ticket)
{
   if(!UseGivebackProtectionV4) return false;
   if(!PositionSelectByTicket(ticket)) return false;
   double profit = CurrentPositionProfitMoneyV4(ticket);
   double peak = GetTicketExitPeakMoneyV4(ticket);
   if(peak < RunnerMinPeakToTrailMoneyV4 && peak < MinProfitToActivateGivebackV4) return false;
   string role = GetRoleForTicketV4(ticket);
   double pct = GivebackClosePercentV4;
   if(role == "MAIN") pct = MainMaxGivebackPercentV4;
   if(role == "LAYER_1") pct = LayerMaxGivebackPercentV4;
   if(role == "RUNNER") pct = RunnerGivebackPercentV4;
   double giveback = ((peak - profit) / MathMax(0.01, peak)) * 100.0;
   if(giveback >= GivebackWarningPercentV4)
      AuditV4("[V4_GIVEBACK] WARNING_ONLY ticket=" + UlongToText(ticket) + " peak=" + DoubleToString(peak,2) + " current=" + DoubleToString(profit,2));
   if(giveback >= pct)
   {
      AuditV4("[V4_GIVEBACK] PROTECTION_ACTIVE ticket=" + UlongToText(ticket) + " peak=" + DoubleToString(peak,2) + " current=" + DoubleToString(profit,2));
      return true;
   }
   return false;
}

double CalculateProfitPotentialScoreV4(ulong ticket, ENUM_POSITION_TYPE direction)
{
   if(!PositionSelectByTicket(ticket)) return 0.0;
   double score = 0.0;
   string comp = "";
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double current = (direction == POSITION_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK));
   double o = iOpen(_Symbol, _Period, 0);
   double c = iClose(_Symbol, _Period, 0);
   ENUM_ORDER_TYPE od = (direction == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   if(IsMomentumStillValidV4(direction)) { score += 20.0; comp += "MOM+20;"; }
   if(direction == POSITION_TYPE_BUY && c >= o) { score += 15.0; comp += "CANDLE+15;"; }
   if(direction == POSITION_TYPE_SELL && c <= o) { score += 15.0; comp += "CANDLE+15;"; }
   if(direction == POSITION_TYPE_BUY && current > openPrice) { score += 15.0; comp += "ADVANCE+15;"; }
   if(direction == POSITION_TYPE_SELL && current < openPrice) { score += 15.0; comp += "ADVANCE+15;"; }
   double maFast = V32GetMA((ENUM_TIMEFRAMES)_Period, 9, 1);
   double maSlow = V32GetMA((ENUM_TIMEFRAMES)_Period, 21, 1);
   if(direction == POSITION_TYPE_BUY && maFast > maSlow) { score += 15.0; comp += "EMA+15;"; }
   if(direction == POSITION_TYPE_SELL && maFast < maSlow) { score += 15.0; comp += "EMA+15;"; }
   double t5 = TrendScoreSimpleV4(od, PERIOD_M5);
   double t15 = TrendScoreSimpleV4(od, PERIOD_M15);
   if(!(t5 < 0.0 && t15 < 0.0)) { score += 15.0; comp += "M5M15_NOT_AGAINST+15;"; }
   else { score -= 20.0; comp += "M5M15_AGAINST-20;"; }
   double adx = MathMax(V32GetADX(PERIOD_M5, 14, 1), V32GetADX(PERIOD_M15, 14, 1));
   if(adx >= 18.0) { score += 10.0; comp += "ADX+10;"; }
   if(GetCurrentSpreadPoints() <= MaxSpreadForSmartExitV4) { score += 10.0; comp += "SPREAD+10;"; }
   score = V4Clamp(score, 0.0, 100.0);
   g_v4LastPotentialScore = score;
   AuditV4("[V4_SMART_EXIT] POTENTIAL_SCORE=" + DoubleToString(score,1) + " ticket=" + UlongToText(ticket) + " comp=" + comp);
   return score;
}

bool HasProfitPotentialV4(ulong ticket, ENUM_POSITION_TYPE direction, string &reason)
{
   double score = CalculateProfitPotentialScoreV4(ticket, direction);
   if(score >= MinProfitPotentialScoreV4)
   {
      reason = "POTENTIAL_OK score=" + DoubleToString(score,1);
      return true;
   }
   reason = "LOW_POTENTIAL score=" + DoubleToString(score,1);
   return false;
}

int SmartExitConfirmationsV4(ulong ticket, ENUM_POSITION_TYPE direction, double score)
{
   int confirms = 0;
   if(!IsMomentumStillValidV4(direction)) confirms++;
   if(IsPriceRejectingEntryV4(direction)) confirms++;
   if(IsTradeStallingV4(ticket)) confirms++;
   if(IsM5M15FullyAgainstV4(direction)) confirms++;
   if(IsProfitGivebackDangerV4(ticket)) confirms++;
   if(score < MinProfitPotentialScoreV4) confirms++;
   if(confirms > 5) confirms = 5;
   return confirms;
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// V9 â€” CHANDELIER EXIT ADAPTATIVO
// SL virtual = Peak - NÃ—ATR. Nunca desce. Fecha quando profit cai abaixo desse SL.
// N cresce conforme o lucro aumenta â€” dÃ¡ mais fÃ´lego para runners maiores.
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
double V9_GetChandelierN(double profit)
{
   // V10: 5 zonas â€” BIG_RUNNER tem Chandelier de 7Ã—ATR para capturar $1500
   if(profit >= Stage15_BigRunnerMinMoney) return V9_ChandelierN_BigRunner; // $150+ = 7Ã—ATR
   if(profit >= V8_Zone3MaxMoney)          return V9_ChandelierN_Zone4;     // $100+ = 5Ã—ATR
   if(profit >= V8_Zone2MaxMoney)          return V9_ChandelierN_Zone3;     // $30+  = 3Ã—ATR
   if(profit >= V8_Zone1MaxMoney)          return V9_ChandelierN_Zone2;     // $10+  = 2Ã—ATR
   return V9_ChandelierN_Zone1;                                              // $3.50+= 1.5Ã—ATR
}

bool V9_IsChandelierHit(ulong ticket, string &reason)
{
   if(!V9_UseChandelierExit) return false;
   if(!PositionSelectByTicket(ticket)) return false;
   double profit = CurrentPositionProfitMoneyV4(ticket);
   double peak   = GetTicketExitPeakMoneyV4(ticket);
   if(peak < V9_ChandelierMinPeakToActivate) return false;
   double posLot   = PositionGetDouble(POSITION_VOLUME);
   double atrMoney = g_atrM1Points * _Point * posLot * 100.0;
   if(atrMoney <= 0.0) atrMoney = 8.0;
   double N            = V9_GetChandelierN(peak);
   double chandelierSL = peak - (N * atrMoney);
   if(profit <= chandelierSL)
   {
      reason = StringFormat("V9_CHANDELIER_HIT peak=%.2f profit=%.2f N=%.1f chandelierSL=%.2f",
                            peak, profit, N, chandelierSL);
      AuditV4("[V9_CHANDELIER] HIT ticket=" + UlongToText(ticket) + " " + reason);
      return true;
   }
   AuditV4("[V9_CHANDELIER] HOLD ticket=" + UlongToText(ticket)
         + " peak=" + DoubleToString(peak,2)
         + " profit=" + DoubleToString(profit,2)
         + " chandelierSL=" + DoubleToString(chandelierSL,2)
         + " buffer=" + DoubleToString(profit-chandelierSL,2)
         + " N=" + DoubleToString(N,1));
   return false;
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// V9 â€” FECHAMENTO PARCIAL (PARTIAL CLOSE)
// Fecha V9_PartialClosePercent% quando profit >= V9_PartialCloseTriggerMoney.
// SÃ³ executa 1 vez por trade. Os 50% restantes continuam como runner.
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
bool V9_HasPartialCloseBeenDone(ulong ticket)
{
   int idx = EnsureTicketExitStateV4(ticket);
   if(idx < 0) return false;
   return (StringFind(g_v4TicketExitStates[idx].lastExitReason, "V9_PARTIAL_DONE") >= 0);
}

void V9_MarkPartialCloseDone(ulong ticket)
{
   int idx = EnsureTicketExitStateV4(ticket);
   if(idx < 0) return;
   g_v4TicketExitStates[idx].lastExitReason = "V9_PARTIAL_DONE";
}

bool V9_TryPartialClose(ulong ticket, string &reason)
{
   if(!V9_UsePartialClose)             return false;
   if(!PositionSelectByTicket(ticket)) return false;
   if(V9_PartialCloseOncePerTrade && V9_HasPartialCloseBeenDone(ticket)) return false;
   double profit = CurrentPositionProfitMoneyV4(ticket);
   if(profit < V9_PartialCloseTriggerMoney) return false;
   string v10DenyReason = "";
   if(!V10_ExitAuthority(ticket, "V9_PARTIAL_CLOSE", "V9_TryPartialClose", v10DenyReason))
   {
      reason = "V9_PARTIAL_CLOSE_BLOCKED_BY_V10 reason=" + v10DenyReason;
      AuditV4("[V9_PARTIAL_CLOSE] BLOCKED_BY_V10 ticket=" + UlongToText(ticket)
            + " profit=" + DoubleToString(profit,2)
            + " blockedReason=" + v10DenyReason);
      return false;
   }
   // V10: BIG_RUNNER nÃ£o faz partial â€” precisa do volume completo para capturar $1500
   if(profit >= V9_PartialCloseMaxProfit)
   {
      reason = "V10_SKIP_PARTIAL_BIG_RUNNER profit=" + DoubleToString(profit,2);
      return false;
   }
   if(g_risk.tradingLocked) return false;
   double volume   = PositionGetDouble(POSITION_VOLUME);
   double stepLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double closeVol = NormalizeDouble(volume * V9_PartialClosePercent / 100.0, (int)MathRound(-MathLog(stepLot)/MathLog(10)));
   double minLot   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(closeVol < minLot || (volume - closeVol) < minLot)
   {
      reason = "V9_PARTIAL_SKIP_LOT_TOO_SMALL";
      return false;
   }
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double closePrice = (posType == POSITION_TYPE_BUY)
                     ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                     : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   ENUM_ORDER_TYPE closeType = (posType == POSITION_TYPE_BUY)
                              ? ORDER_TYPE_SELL
                              : ORDER_TYPE_BUY;

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action       = TRADE_ACTION_DEAL;
   req.position     = ticket;
   req.symbol       = _Symbol;
   req.volume       = closeVol;
   req.type         = closeType;
   req.price        = closePrice;
   req.deviation    = RealExecutionDeviationPoints;
   req.magic        = (ulong)MagicNumber;
   req.type_filling = ORDER_FILLING_FOK;
   req.comment      = "V9_PARTIAL_CLOSE";

   bool ok = OrderSend(req, res);
   bool success = ok && (res.retcode == TRADE_RETCODE_DONE || res.retcode == 0);
   if(success)
   {
      V9_MarkPartialCloseDone(ticket);
      reason = StringFormat("V9_PARTIAL_CLOSE_OK vol=%.2f profit=%.2f remaining=%.2f retcode=%d",
                            closeVol, profit, volume - closeVol, res.retcode);
      AuditV4("[V9_PARTIAL_CLOSE] EXECUTED ticket=" + UlongToText(ticket) + " " + reason);
   }
   else
   {
      reason = "V9_PARTIAL_CLOSE_FAILED retcode=" + IntegerToString(res.retcode)
             + " comment=" + res.comment;
      AuditV4("[V9_PARTIAL_CLOSE] FAILED ticket=" + UlongToText(ticket) + " " + reason);
   }
   return success;
}

bool ShouldCloseBadTradeEarlyV4(ulong ticket, ENUM_POSITION_TYPE direction, string &reason)
{
   if(!UseSmartExitV4) { reason = "SMART_EXIT_DISABLED"; return false; }
   if(!PositionSelectByTicket(ticket)) { reason = "POSITION_NOT_FOUND"; return false; }

   UpdateTicketExitStateV4(ticket);
   string role   = GetRoleForTicketV4(ticket);
   double profit = CurrentPositionProfitMoneyV4(ticket);
   double peak   = GetTicketExitPeakMoneyV4(ticket);
   double score  = CalculateProfitPotentialScoreV4(ticket, direction);
   int    confirms = SmartExitConfirmationsV4(ticket, direction, score);
   // Valor monetÃ¡rio de 1x ATR M1 na posiÃ§Ã£o atual (posLot = volume real da posiÃ§Ã£o)
   double posLot   = PositionGetDouble(POSITION_VOLUME);
   double atrMoney = g_atrM1Points * _Point * posLot * 100.0;
   if(atrMoney <= 0.0) atrMoney = 8.0; // fallback seguro

   AuditV4("[V8_ZONE_EXIT] ticket=" + UlongToText(ticket)
         + " role=" + role
         + " profit=" + DoubleToString(profit,2)
         + " peak="   + DoubleToString(peak,2)
         + " score="  + DoubleToString(score,1)
         + " confirms=" + IntegerToString(confirms)
         + " atrMoney=" + DoubleToString(atrMoney,2));

   // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
   // ZONA 0 â€” ZONA MORTA DO SPREAD ($0 a $3.50)
   // Nunca fechar aqui. O spread ainda nÃ£o foi superado.
   // O trade nÃ£o teve chance real ainda.
   // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
   if(profit > -1.0 && profit <= V8_Zone0MaxMoney)
   {
      reason = "V8_ZONE0_SPREAD_DEAD_ZONE_HOLD profit=" + DoubleToString(profit,2);
      AuditV4("[V8_ZONE_EXIT] ZONE0_HOLD â€” spread zone, never close here");
      return false;
   }

   // â”€â”€ ZONA 1 â€” MICRO SCALP ($3.50 a $10) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
   // V9: Chandelier SL = peak - 1.5Ã—ATR. SÃ³ fecha em reversÃ£o severa sem Chandelier.
   if(profit > V8_Zone0MaxMoney && profit <= V8_Zone1MaxMoney)
   {
      string chanReason = "";
      if(V9_IsChandelierHit(ticket, chanReason))
      {
         reason = chanReason;
         AuditV4("[V9_ZONE_EXIT] ZONE1_CHANDELIER_CLOSE â€” " + chanReason);
         return true;
      }
      bool severeReversal  = IsSevereReversalV4(ticket, direction);
      bool momentumFlipped = !IsMomentumStillValidV4(direction) && IsM5M15FullyAgainstV4(direction);
      bool enoughConfirms  = (confirms >= SmartExitMinConfirmationsV4);
      if(severeReversal && momentumFlipped && enoughConfirms)
      {
         reason = "V9_ZONE1_SEVERE_REVERSAL profit=" + DoubleToString(profit,2);
         return true;
      }
      reason = "V9_ZONE1_HOLD Chandelier_1.5x_active profit=" + DoubleToString(profit,2);
      return false;
   }

   // â”€â”€ ZONA 2 â€” SCALP BOM ($10 a $30) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
   // V9: Chandelier SL = peak - 2.0Ã—ATR. Partial Close aqui se configurado.
   if(profit > V8_Zone1MaxMoney && profit <= V8_Zone2MaxMoney)
   {
      string chanReason = "";
      if(V9_IsChandelierHit(ticket, chanReason))
      {
         reason = chanReason;
         AuditV4("[V9_ZONE_EXIT] ZONE2_CHANDELIER_CLOSE â€” " + chanReason);
         return true;
      }
      double givebackAllowed = 1.5 * atrMoney;
      bool trailingHit = (peak > V8_Zone1MaxMoney && (peak - profit) > givebackAllowed);
      bool scoreCrash  = (score < V8_Zone2MinScore);
      bool m5Against   = IsM5M15FullyAgainstV4(direction);
      if(trailingHit && m5Against)
      {
         reason = "V9_ZONE2_ATR_TRAIL profit=" + DoubleToString(profit,2) + " peak=" + DoubleToString(peak,2);
         return true;
      }
      if(scoreCrash && confirms >= SmartExitMinConfirmationsV4 && IsSevereReversalV4(ticket,direction))
      {
         reason = "V9_ZONE2_SCORE_CRASH score=" + DoubleToString(score,1);
         return true;
      }
      reason = "V9_ZONE2_HOLD Chandelier_2.0x profit=" + DoubleToString(profit,2);
      return false;
   }

   // â”€â”€ ZONA 3 â€” SWING ($30 a $100) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
   // V9: Chandelier SL = peak - 3.0Ã—ATR. Runner sÃ³ fecha com reversÃ£o severa.
   if(profit > V8_Zone2MaxMoney && profit <= V8_Zone3MaxMoney)
   {
      string chanReason = "";
      if(V9_IsChandelierHit(ticket, chanReason) && IsSevereReversalV4(ticket, direction))
      {
         reason = chanReason + "_ZONE3_SEVERE_CONFIRMED";
         AuditV4("[V9_ZONE_EXIT] ZONE3_CHANDELIER_CLOSE â€” " + reason);
         return true;
      }
      if(IsRunnerStrongV4(ticket, direction))
      {
         reason = "V9_ZONE3_RUNNER_PROTECTED profit=" + DoubleToString(profit,2);
         return false;
      }
      reason = "V9_ZONE3_HOLD Chandelier_3.0x profit=" + DoubleToString(profit,2);
      return false;
   }

   // â”€â”€ ZONA 4 â€” RUNNER ($100+) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
   // V9: Chandelier SL = peak - 4.0Ã—ATR. Fecha APENAS com reversÃ£o M5 completa.
   if(profit > V8_Zone3MaxMoney)
   {
      string chanReason = "";
      bool trendReverse = IsM5M15FullyAgainstV4(direction)
                       && IsSevereReversalV4(ticket, direction)
                       && !IsMomentumStillValidV4(direction);
      if(V9_IsChandelierHit(ticket, chanReason) && trendReverse)
      {
         reason = chanReason + "_ZONE4_TREND_REVERSAL_CONFIRMED";
         AuditV4("[V9_ZONE_EXIT] ZONE4_BIG_RUNNER_CLOSE â€” " + reason);
         return true;
      }
      reason = "V9_ZONE4_BIG_RUNNER_HOLD Chandelier_4.0x profit=" + DoubleToString(profit,2)
             + " peak=" + DoubleToString(peak,2);
      AuditV4("[V9_ZONE_EXIT] ZONE4_PROTECTING_500_800_RUNNER");
      g_v4RunnerProtectedCount++;
      return false;
   }

   // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
   // PERDA â€” SL ainda nÃ£o atingido, mas trade estÃ¡ negativo
   // SÃ³ fecha se perda real (alÃ©m do spread) + confirmaÃ§Ãµes suficientes
   // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
   if(profit <= -1.0)
   {
      bool realLoss   = (profit <= CloseNoPotentialProfitMoneyV4);
      bool scoreDead  = (score < EmergencyNoPotentialScoreV4);
      bool enoughConf = (confirms >= SmartExitMinConfirmationsV4);

      if(enoughConf && (realLoss || scoreDead))
      {
         reason = "V8_LOSS_CONFIRMED profit=" + DoubleToString(profit,2)
                + " score=" + DoubleToString(score,1)
                + " confirms=" + IntegerToString(confirms);
         AuditV4("[V8_ZONE_EXIT] LOSS_CLOSE â€” confirmed real loss, not spread noise");
         return true;
      }
      reason = "V8_LOSS_HOLD_FOR_RECOVERY profit=" + DoubleToString(profit,2);
      AuditV4("[V8_ZONE_EXIT] LOSS_HOLD â€” waiting for SL or recovery");
      return false;
   }

   reason = "V8_ZONE_UNKNOWN_HOLD";
   return false;
}

bool ShouldProtectGoodTradeProfitV4(ulong ticket, ENUM_POSITION_TYPE direction, string &reason)
{
   if(!PositionSelectByTicket(ticket)) { reason = "POSITION_NOT_FOUND"; return false; }
   UpdateTicketExitStateV4(ticket);

   double profit = CurrentPositionProfitMoneyV4(ticket);
   double peak = GetTicketExitPeakMoneyV4(ticket);
   if(!UseGivebackProtectionV4 || peak < MinProfitToActivateGivebackV4)
   {
      reason = "NO_GIVEBACK_DANGER";
      return false;
   }

   double pct = ((peak - profit) / MathMax(0.01, peak)) * 100.0;
   if(pct < GivebackClosePercentV4)
   {
      reason = "GIVEBACK_WARNING_ONLY pct=" + DoubleToString(pct,1);
      return false;
   }

   if(IsRunnerStrongV4(ticket, direction))
   {
      reason = "RUNNER_STRONG_GIVEBACK_IGNORED";
      AuditV4("[V4_GIVEBACK] WARNING_ONLY ticket=" + UlongToText(ticket) + " strongRunner=true");
      return false;
   }

   bool runnerCandidate = (GetRoleForTicketV4(ticket) == "RUNNER" || IsRunnerCandidateV4(ticket, direction));
   if(runnerCandidate && !IsSevereReversalV4(ticket, direction))
   {
      reason = "GOOD_RUNNER_PULLBACK_GIVEBACK_HOLD_NO_REVERSAL";
      AuditV4("[V4_GIVEBACK] GOOD_RUNNER_PULLBACK_HOLD ticket=" + UlongToText(ticket));
      return false;
   }

   if((!IsMomentumStillValidV4(direction) || IsM5M15FullyAgainstV4(direction)) && IsSevereReversalV4(ticket, direction))
   {
      reason = "GIVEBACK_PROTECTION_CLOSE_CONFIRMED_REVERSAL";
      AuditV4("[V4_GIVEBACK] CLOSE_CONFIRMED ticket=" + UlongToText(ticket) + " peak=" + DoubleToString(peak,2) + " current=" + DoubleToString(profit,2));
      return true;
   }

   reason = "GIVEBACK_PROTECTION_ACTIVE_BUT_MOMENTUM_OK";
   AuditV4("[V4_GIVEBACK] PROTECTION_ACTIVE ticket=" + UlongToText(ticket) + " momentumStillOK=true");
   return false;
}

class CSmartProfitPotentialExitEngineV4
{
public:
   void UpdateSmartProfitPotentialExitV4() { ::UpdateSmartProfitPotentialExitV4(); }
   double CalculateProfitPotentialScoreV4(ulong ticket, ENUM_POSITION_TYPE direction) { return ::CalculateProfitPotentialScoreV4(ticket, direction); }
   bool HasProfitPotentialV4(ulong ticket, ENUM_POSITION_TYPE direction, string &reason) { return ::HasProfitPotentialV4(ticket, direction, reason); }
   bool ShouldCloseBadTradeEarlyV4(ulong ticket, ENUM_POSITION_TYPE direction, string &reason) { return ::ShouldCloseBadTradeEarlyV4(ticket, direction, reason); }
   bool ShouldProtectGoodTradeProfitV4(ulong ticket, ENUM_POSITION_TYPE direction, string &reason) { return ::ShouldProtectGoodTradeProfitV4(ticket, direction, reason); }
   bool IsMomentumStillValidV4(ENUM_POSITION_TYPE direction) { return ::IsMomentumStillValidV4(direction); }
   bool IsPriceRejectingEntryV4(ENUM_POSITION_TYPE direction) { return ::IsPriceRejectingEntryV4(direction); }
   bool IsTradeStallingV4(ulong ticket) { return ::IsTradeStallingV4(ticket); }
   bool IsProfitGivebackDangerV4(ulong ticket) { return ::IsProfitGivebackDangerV4(ticket); }
};

CSmartProfitPotentialExitEngineV4 g_v4SmartExitEngine;

double MoneyToPriceDistanceV4(double money, double volume)
{
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0.0 || tickSize <= 0.0 || volume <= 0.0) return 0.0;
   double ticks = money / (tickValue * volume);
   return ticks * tickSize;
}

bool IsStopPriceValidV4(ENUM_POSITION_TYPE type, double sl)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   int stopLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   int freezeLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(point <= 0.0 || digits <= 0) return false;
   double minDistance = MathMax(stopLevel, freezeLevel) * point;
   if(type == POSITION_TYPE_BUY && (bid - sl) < minDistance) return false;
   if(type == POSITION_TYPE_SELL && (sl - ask) < minDistance) return false;
   return true;
}

bool BuildRunnerBreakEvenTargetSLV4(ulong ticket, ENUM_POSITION_TYPE type, double lockMoney, double &targetSL)
{
   targetSL = 0.0;
   if(!PositionSelectByTicket(ticket)) return false;
   double volume = PositionGetDouble(POSITION_VOLUME);
   double open = PositionGetDouble(POSITION_PRICE_OPEN);
   double priceDistance = MoneyToPriceDistanceV4(lockMoney, volume);
   if(priceDistance <= 0.0) return false;
   if(type == POSITION_TYPE_BUY) targetSL = NormalizeDouble(open + priceDistance, _Digits);
   else targetSL = NormalizeDouble(open - priceDistance, _Digits);
   return (targetSL > 0.0);
}

bool IsRunnerServerSLConfirmedV4(ENUM_POSITION_TYPE type, double serverSL, double targetSL)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double minDistance = Stage15_SLMinDistancePriceV10();
   return Stage15_IsServerSLAtOrBeyondTargetV10(type, serverSL, targetSL, bid, ask, minDistance);
}

bool HasRunnerRealBreakEvenProtectionV4(ulong ticket, ENUM_POSITION_TYPE type, double lockMoney, string &reason)
{
   reason = "SERVER_SL_NOT_CONFIRMED";
   if(!PositionSelectByTicket(ticket))
   {
      reason = "POSITION_NOT_FOUND";
      return false;
   }

   double targetSL = 0.0;
   if(!BuildRunnerBreakEvenTargetSLV4(ticket, type, lockMoney, targetSL))
   {
      reason = "TARGET_SL_BUILD_FAILED";
      return false;
   }

   double serverSL = PositionGetDouble(POSITION_SL);
   if(IsRunnerServerSLConfirmedV4(type, serverSL, targetSL))
   {
      reason = "SERVER_SL_CONFIRMED";
      return true;
   }

   reason = "SERVER_SL_BELOW_TARGET";
   return false;
}

bool TryMoveRunnerBreakEvenSLV4(ulong ticket, ENUM_POSITION_TYPE type, double lockMoney)
{
   if(!PositionSelectByTicket(ticket)) return false;
   double currentSL = PositionGetDouble(POSITION_SL);
   double tp = PositionGetDouble(POSITION_TP);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = 0.0;
   if(!BuildRunnerBreakEvenTargetSLV4(ticket, type, lockMoney, sl))
   {
      AuditV4("[V4_RUNNER_BE_NOT_CONFIRMED] ticket=" + UlongToText(ticket) + " type=" + Stage15_PositionTypeTextV10(type) + " targetSL=0.00000 serverSL=" + DoubleToString(currentSL,_Digits) + " reason=TARGET_SL_BUILD_FAILED");
      return false;
   }

   AuditV4("[V4_RUNNER_BE_ATTEMPT] ticket=" + UlongToText(ticket)
         + " type=" + Stage15_PositionTypeTextV10(type)
         + " currentSL=" + DoubleToString(currentSL,_Digits)
         + " targetSL=" + DoubleToString(sl,_Digits)
         + " bid=" + DoubleToString(bid,_Digits)
         + " ask=" + DoubleToString(ask,_Digits));

   if(!IsStopPriceValidV4(type, sl))
   {
      AuditV4("[V4_RUNNER_BE_NOT_CONFIRMED] ticket=" + UlongToText(ticket)
            + " type=" + Stage15_PositionTypeTextV10(type)
            + " targetSL=" + DoubleToString(sl,_Digits)
            + " serverSL=" + DoubleToString(currentSL,_Digits)
            + " reason=TARGET_SL_INVALID_FOR_BROKER_DISTANCE");
      return false;
   }

   trade.SetExpertMagicNumber((ulong)MagicNumber);
   bool ok = trade.PositionModify(ticket, sl, tp);
   if(!ok)
   {
      AuditV4("[V4_RUNNER_BE] REAL_SL_MOVE_FAILED ticket=" + UlongToText(ticket) + " retcode=" + trade.ResultRetcodeDescription());
      AuditV4("[V4_RUNNER_BE_NOT_CONFIRMED] ticket=" + UlongToText(ticket)
            + " type=" + Stage15_PositionTypeTextV10(type)
            + " targetSL=" + DoubleToString(sl,_Digits)
            + " serverSL=" + DoubleToString(currentSL,_Digits)
            + " reason=POSITION_MODIFY_FAILED");
      return false;
   }

   double serverSL = 0.0;
   if(PositionSelectByTicket(ticket))
      serverSL = PositionGetDouble(POSITION_SL);
   else
   {
      AuditV4("[V4_RUNNER_BE_NOT_CONFIRMED] ticket=" + UlongToText(ticket)
            + " type=" + Stage15_PositionTypeTextV10(type)
            + " targetSL=" + DoubleToString(sl,_Digits)
            + " serverSL=0.00000"
            + " reason=POSITION_RESELECT_FAILED");
      return false;
   }

   if(IsRunnerServerSLConfirmedV4(type, serverSL, sl))
   {
      AuditV4("[V4_RUNNER_BE_CONFIRMED] ticket=" + UlongToText(ticket)
            + " type=" + Stage15_PositionTypeTextV10(type)
            + " targetSL=" + DoubleToString(sl,_Digits)
            + " serverSL=" + DoubleToString(serverSL,_Digits)
            + " reason=SERVER_SL_CONFIRMED");
      return true;
   }

   AuditV4("[V4_RUNNER_BE_NOT_CONFIRMED] ticket=" + UlongToText(ticket)
         + " type=" + Stage15_PositionTypeTextV10(type)
         + " targetSL=" + DoubleToString(sl,_Digits)
         + " serverSL=" + DoubleToString(serverSL,_Digits)
         + " reason=SERVER_SL_DID_NOT_CONFIRM_TARGET");
   return false;
}

bool EvaluateRunnerBreakEvenV4(ulong ticket, ENUM_POSITION_TYPE type, ENUM_V4_EXIT_REASON &exitReason, string &reason)
{
   exitReason = EXIT_NONE;
   reason = "NO_RUNNER_BE";
   if(!UseRunnerBreakEvenV4) return false;
   if(GetRoleForTicketV4(ticket) != "RUNNER") return false;
   if(!PositionSelectByTicket(ticket)) return false;

   int idx = EnsureTicketExitStateV4(ticket);
   double profit = CurrentPositionProfitMoneyV4(ticket);

   if(!g_v4TicketExitStates[idx].breakEvenActivated && profit >= RunnerBreakEvenStartMoneyV4)
   {
      AuditV4("[V4_RUNNER_BE] ACTIVATED ticket=" + UlongToText(ticket) + " profit=" + DoubleToString(profit,2) + " lock=" + DoubleToString(RunnerBreakEvenLockMoneyV4,2));
      if(TryMoveRunnerBreakEvenSLV4(ticket, type, RunnerBreakEvenLockMoneyV4))
         g_v4TicketExitStates[idx].breakEvenActivated = true;
      else
      {
         g_v4TicketExitStates[idx].breakEvenActivated = false;
         AuditV4("[V4_RUNNER_VIRTUAL_LOCK_DISABLED] ticket=" + UlongToText(ticket) + " reason=VIRTUAL_LOCK_NOT_ALLOWED_WITHOUT_SERVER_SL");
      }
   }

   if(g_v4TicketExitStates[idx].breakEvenActivated && profit <= RunnerBreakEvenLockMoneyV4)
   {
      string realProtectionReason = "";
      if(HasRunnerRealBreakEvenProtectionV4(ticket, type, RunnerBreakEvenLockMoneyV4, realProtectionReason))
      {
         exitReason = EXIT_RUNNER_BREAK_EVEN;
         reason = "RUNNER_BREAK_EVEN_REAL_SL_CONFIRMED_CLOSE";
         AuditV4("[V4_RUNNER_BE] REAL_SL_CONFIRMED_CLOSE ticket=" + UlongToText(ticket) + " profit=" + DoubleToString(profit,2));
         return true;
      }

      g_v4TicketExitStates[idx].breakEvenActivated = false;
      AuditV4("[V4_RUNNER_VIRTUAL_LOCK_DISABLED] ticket=" + UlongToText(ticket) + " reason=VIRTUAL_LOCK_NOT_ALLOWED_WITHOUT_SERVER_SL detail=" + realProtectionReason);
   }
   return false;
}

bool EvaluateRunnerProfitPeakTrailV4(ulong ticket, ENUM_POSITION_TYPE type, ENUM_V4_EXIT_REASON &exitReason, string &reason)
{
   exitReason = EXIT_NONE;
   reason = "NO_RUNNER_TRAIL";
   if(!UseRunnerProfitPeakTrailV4) return false;
   if(GetRoleForTicketV4(ticket) != "RUNNER") return false;
   if(!PositionSelectByTicket(ticket)) return false;

   double profit = CurrentPositionProfitMoneyV4(ticket);
   double peak = GetTicketExitPeakMoneyV4(ticket);
   if(peak < RunnerMinPeakToTrailMoneyV4) return false;
   double giveback = ((peak - profit) / MathMax(0.01, peak)) * 100.0;
   if(giveback >= RunnerGivebackPercentV4)
   {
      AuditV4("[V4_RUNNER_TRAIL] GIVEBACK_WARNING ticket=" + UlongToText(ticket) + " peak=" + DoubleToString(peak,2) + " current=" + DoubleToString(profit,2));
      string realProtectionReason = "";
      bool hasRealProtection = HasRunnerRealBreakEvenProtectionV4(ticket, type, RunnerBreakEvenLockMoneyV4, realProtectionReason);
      bool severeReversal = IsSevereReversalV4(ticket, type);
      if(!hasRealProtection && !severeReversal)
      {
         AuditV4("[V4_RUNNER_GIVEBACK_BLOCKED_NO_REAL_PROTECTION] ticket=" + UlongToText(ticket)
               + " reason=GIVEBACK_CLOSE_REQUIRES_REAL_SL_OR_REAL_REVERSAL"
               + " protectionReason=" + realProtectionReason);
         return false;
      }

      if(!IsRunnerStrongV4(ticket, type) && (!IsMomentumStillValidV4(type) || IsM5M15FullyAgainstV4(type)))
      {
         exitReason = EXIT_RUNNER_GIVEBACK;
         reason = "RUNNER_GIVEBACK_CLOSE_CONFIRMED";
         AuditV4("[V4_RUNNER_TRAIL] GIVEBACK_CLOSE_CONFIRMED ticket=" + UlongToText(ticket) + " peak=" + DoubleToString(peak,2) + " current=" + DoubleToString(profit,2) + " realProtection=" + BoolToText(hasRealProtection) + " severeReversal=" + BoolToText(severeReversal));
         return true;
      }
   }
   return false;
}

bool RequestExitDecisionV4(ulong ticket, ENUM_V4_EXIT_REASON candidate, string candidateReason, ENUM_V4_EXIT_REASON &selected, string &selectedReason)
{
   if(candidate == EXIT_NONE) return false;
   if(selected == EXIT_NONE)
   {
      selected = candidate;
      selectedReason = candidateReason;
      return true;
   }
   if(ExitPriorityValueV4(candidate) < ExitPriorityValueV4(selected))
   {
      AuditV4("[V4_EXIT_ORCHESTRATOR] SKIPPED_LOWER_PRIORITY_EXIT ticket=" + UlongToText(ticket) + " skipped=" + selectedReason);
      selected = candidate;
      selectedReason = candidateReason;
      return true;
   }
   AuditV4("[V4_EXIT_ORCHESTRATOR] SKIPPED_LOWER_PRIORITY_EXIT ticket=" + UlongToText(ticket) + " skipped=" + candidateReason);
   return false;
}

string V10_UpperReason(string reason)
{
   string r = reason;
   StringToUpper(r);
   return r;
}

bool V10_IsCriticalExitReason(string reason)
{
   string r = V10_UpperReason(reason);
   if(StringFind(r, "EMERGENCY") >= 0) return true;
   if(StringFind(r, "CRITICAL") >= 0) return true;
   if(StringFind(r, "HARD_RISK") >= 0) return true;
   if(StringFind(r, "RISK") >= 0 && StringFind(r, "LOCK") < 0) return true;
   if(StringFind(r, "DAILY") >= 0) return true;
   if(StringFind(r, "DD") >= 0 && StringFind(r, "STOP") >= 0) return true;
   if(StringFind(r, "MARGIN") >= 0) return true;
   if(StringFind(r, "SL_HIT") >= 0) return true;
   if(StringFind(r, "STOP_LOSS") >= 0) return true;
   return false;
}

bool V10_IsV10AuthorizedReason(string reason)
{
   string r = V10_UpperReason(reason);
   if(StringFind(r, "_V10") >= 0) return true;
   if(StringFind(r, "WEAK_CUT_V10") >= 0) return true;
   if(StringFind(r, "MODERATE") >= 0 && StringFind(r, "V10") >= 0) return true;
   if(StringFind(r, "GOOD") >= 0 && StringFind(r, "V10") >= 0) return true;
   if(StringFind(r, "RUNNER") >= 0 && StringFind(r, "V10") >= 0) return true;
   return false;
}

bool V10_IsLegacySmallOrBasketExit(string reason)
{
   string r = V10_UpperReason(reason);
   if(StringFind(r, "SMALL_WIN") >= 0) return true;
   if(StringFind(r, "MICRO") >= 0) return true;
   if(StringFind(r, "BASKET_PROFIT") >= 0) return true;
   if(StringFind(r, "BASKET_SMART_CLOSE") >= 0) return true;
   if(StringFind(r, "LEGACY_SMART_EXIT") >= 0) return true;
   if(StringFind(r, "SMART_EXIT") >= 0) return true;
   if(StringFind(r, "V9_PARTIAL_CLOSE") >= 0) return true;
   if(StringFind(r, "PARTIAL_CLOSE") >= 0) return true;
   if(StringFind(r, "ADAPTIVE_BASKET") >= 0) return true;
   if(StringFind(r, "PROFIT_TARGET") >= 0) return true;
   if(StringFind(r, "TAKE_PROFIT") >= 0) return true;
   if(StringFind(r, "CLOSED_SMALL") >= 0) return true;
   return false;
}

string V10_FallbackClassByMFE(ulong ticket, double profit, double mfe)
{
   if(mfe >= V10_BigRunnerStartMoney || profit >= V10_BigRunnerStartMoney) return "BIG_RUNNER";
   if(mfe >= V10_RunnerStartMoney || profit >= V10_RunnerStartMoney) return "RUNNER";
   if(mfe >= V10_GoodLockTriggerMoney || profit >= V10_GoodBETriggerMoney) return "GOOD";
   if(mfe >= V10_ModerateBETriggerMoney || profit >= (V10_ModerateBETriggerMoney * 0.50)) return "MODERATE";
   return "WEAK";
}

bool V10_ExitAuthority(ulong ticket, string proposedReason, string proposedFunction, string &denyReason)
{
   denyReason = "ALLOWED";
   if(!V10_ForceRealFlowIntegration || !V10_EnableLiveExitClassification) return true;
   if(!PositionSelectByTicket(ticket))
   {
      denyReason = "POSITION_NOT_FOUND";
      return false;
   }

   UpdateTicketExitStateV4(ticket);
   int idx = EnsureTicketExitStateV4(ticket);
   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double profit = CurrentPositionProfitMoneyV4(ticket);
   double mfe = GetTicketExitPeakMoneyV4(ticket);
   double mae = Stage15_GetTicketMAEMoneyV10(ticket);
   bool critical = V10_IsCriticalExitReason(proposedReason);
   bool v10Reason = V10_IsV10AuthorizedReason(proposedReason);
   bool legacySmall = V10_IsLegacySmallOrBasketExit(proposedReason) || V10_IsLegacySmallOrBasketExit(proposedFunction);
   bool confirmedReversal = Stage15_IsConfirmedReversal(ticket, type);
   bool healthyPullback = Stage15_IsHealthyPullback(ticket, type);
   bool severeReversal = IsSevereReversalV4(ticket, type);
   bool trendAlive = Stage15_IsTrendAliveV10(ticket, type, healthyPullback, confirmedReversal);

   string cls = g_v4TicketExitStates[idx].liveExitClass;
   if(cls == "" || cls == "NEW" || cls == "NONE")
   {
      cls = V10_FallbackClassByMFE(ticket, profit, mfe);
      g_v4TicketExitStates[idx].previousExitClass = g_v4TicketExitStates[idx].liveExitClass;
      g_v4TicketExitStates[idx].liveExitClass = cls;
      g_v4TicketExitStates[idx].classChangedTime = TimeCurrent();
      AuditV4("[CLASS_TRANSITION_V10] ticket=" + UlongToText(ticket)
            + " oldClass=" + g_v4TicketExitStates[idx].previousExitClass
            + " newClass=" + cls
            + " profit=" + DoubleToString(profit,2)
            + " mfe=" + DoubleToString(mfe,2)
            + " mae=" + DoubleToString(mae,2)
            + " score=0.0 trendAlive=" + BoolToText(trendAlive)
            + " pullback=" + BoolToText(healthyPullback)
            + " reversal=" + BoolToText(confirmedReversal)
            + " reason=V10_AUTHORITY_FALLBACK_CLASSIFICATION");
   }

   bool allow = true;
   denyReason = "ALLOWED_BY_V10";
   bool hasRelevantMFE = (mfe >= V10_ModerateLockTriggerMoney);
   bool strongClass = (cls == "GOOD" || cls == "RUNNER" || cls == "BIG_RUNNER");


   if(critical || v10Reason)
   {
      allow = true;
      denyReason = (critical ? "CRITICAL_OR_RISK_EXIT_ALLOWED" : "V10_REASON_ALLOWED");
   }
   else if((V10_BlockLegacySmallProfitExit || V10_BlockLegacySmallExit) && legacySmall)
   {
      if(cls == "RUNNER" || cls == "BIG_RUNNER")
      {
         if(trendAlive && !severeReversal)
         {
            allow = false;
            denyReason = cls + "_LEGACY_SMALL_CLOSE_BLOCKED_TREND_ALIVE";
         }
      }
      else if(cls == "GOOD")
      {
         if((trendAlive || healthyPullback) && !confirmedReversal && !severeReversal)
         {
            allow = false;
            denyReason = "GOOD_LEGACY_SMALL_CLOSE_BLOCKED_PULLBACK_OR_TREND_ALIVE";
         }
      }
      else if(cls == "MODERATE")
      {
         if(mfe >= V10_ModerateLockTriggerMoney && profit <= 0.0)
         {
            allow = false;
            denyReason = "MODERATE_MFE_RELEVANT_CANNOT_CLOSE_AS_LEGACY_LOSS";
         }
      }
   }

   if(allow && !critical && !v10Reason && strongClass && hasRelevantMFE && (trendAlive || healthyPullback) && !severeReversal)
   {
      allow = false;
      denyReason = cls + "_PROTECTED_MFE_BLOCKED_NON_V10_CLOSE";
   }

   AuditV4("[EXIT_AUTHORITY_V10] ticket=" + UlongToText(ticket)
         + " class=" + cls
         + " profit=" + DoubleToString(profit,2)
         + " mfe=" + DoubleToString(mfe,2)
         + " mae=" + DoubleToString(mae,2)
         + " beActive=" + BoolToText(g_v4TicketExitStates[idx].breakEvenActivated)
         + " lockActive=" + BoolToText(g_v4TicketExitStates[idx].lockActivated)
         + " trailActive=" + BoolToText(g_v4TicketExitStates[idx].trailingActivated)
         + " exitCandidate=" + proposedReason
         + " exitAllowed=" + BoolToText(allow)
         + " exitReason=" + denyReason
         + " authorizedBy=" + proposedFunction);

   V10_LogFlowConnected(ticket, true, true, true, !allow);

   if(!allow)
   {
      AuditV4("[EXIT_BLOCKED_BY_V10] ticket=" + UlongToText(ticket)
            + " class=" + cls
            + " profit=" + DoubleToString(profit,2)
            + " mfe=" + DoubleToString(mfe,2)
            + " mae=" + DoubleToString(mae,2)
            + " oldFunction=" + proposedFunction
            + " oldReason=" + proposedReason
            + " blockedReason=" + denyReason);
   }

   return allow;
}

bool SelectBestExitReasonV4(ulong ticket, ENUM_V4_EXIT_REASON &exitReason, string &reason)
{
   exitReason = EXIT_NONE;
   reason = "NO_EXIT";
   if(!PositionSelectByTicket(ticket)) return false;

   UpdateTicketExitStateV4(ticket);
   string role = GetRoleForTicketV4(ticket);
   ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double profit = CurrentPositionProfitMoneyV4(ticket);
    bool runnerCandidate = IsRunnerCandidateV4(ticket, pt);
    double livePeakV10 = GetTicketExitPeakMoneyV4(ticket);
    bool liveGoodOrBetterV10 = (livePeakV10 >= V10_GoodLockTriggerMoney || profit >= V10_GoodBETriggerMoney)
                               && !IsSevereReversalV4(ticket, pt)
                               && (IsTrendSupportiveV4(pt) || IsMomentumStillValidV4(pt));
    if(liveGoodOrBetterV10)
    {
       runnerCandidate = true;
       AuditV4("[GOOD_PROTECTED_V10] SMALL_MEDIUM_TARGET_BLOCKED_LIVE_TREND ticket=" + UlongToText(ticket) + " profit=" + DoubleToString(profit,2) + " mfe=" + DoubleToString(livePeakV10,2));
    }
    string candidate = "";
   ENUM_V4_EXIT_REASON candidateReason = EXIT_NONE;

   if(profit <= BasketEmergencySLMoneyV4)
      RequestExitDecisionV4(ticket, EXIT_BASKET_EMERGENCY_SL, "BASKET_EMERGENCY_SL_HIT", exitReason, reason);
   if(role == "MAIN" && profit <= MainSLMoneyV4)
      RequestExitDecisionV4(ticket, EXIT_BASKET_EMERGENCY_SL, "MAIN_SL_HIT", exitReason, reason);
   if(role == "LAYER_1" && profit <= LayerSLMoneyV4)
      RequestExitDecisionV4(ticket, EXIT_BASKET_EMERGENCY_SL, "LAYER_SL_HIT", exitReason, reason);
   if(role == "RUNNER" && profit <= RunnerSLMoneyV4)
      RequestExitDecisionV4(ticket, EXIT_BASKET_EMERGENCY_SL, "RUNNER_SL_HIT", exitReason, reason);

   if(EvaluateRunnerBreakEvenV4(ticket, pt, candidateReason, candidate))
      RequestExitDecisionV4(ticket, candidateReason, candidate, exitReason, reason);
   if(EvaluateRunnerProfitPeakTrailV4(ticket, pt, candidateReason, candidate))
      RequestExitDecisionV4(ticket, candidateReason, candidate, exitReason, reason);
   if(ShouldCloseBadTradeEarlyV4(ticket, pt, candidate))
      RequestExitDecisionV4(ticket, EXIT_SMART_EXIT_CONFIRMED, candidate, exitReason, reason);
   if(ShouldProtectGoodTradeProfitV4(ticket, pt, candidate))
      RequestExitDecisionV4(ticket, EXIT_RUNNER_GIVEBACK, candidate, exitReason, reason);

   if(role == "MAIN" && profit >= MediumWinMoneyV4 && profit >= MinBasketProfitToCloseV4 && !runnerCandidate)
      RequestExitDecisionV4(ticket, EXIT_BASKET_PROFIT, "MAIN_CLOSED_MEDIUM_WIN", exitReason, reason);
   if(role == "MAIN" && profit >= SmallWinMoneyV4 && !IsMomentumStillValidV4(pt) && !runnerCandidate)
      RequestExitDecisionV4(ticket, EXIT_SMALL_WIN, "MAIN_CLOSED_SMALL_WIN", exitReason, reason);
   else if(role == "MAIN" && runnerCandidate && profit >= SmallWinMoneyV4)
      AuditV4("[V4_RUNNER] SMALL_WIN_BLOCKED_RUNNER_CANDIDATE ticket=" + UlongToText(ticket));
   if(role == "LAYER_1" && profit >= MediumWinMoneyV4 && profit >= MinBasketProfitToCloseV4 && !runnerCandidate)
      RequestExitDecisionV4(ticket, EXIT_BASKET_PROFIT, "LAYER_CLOSED_MEDIUM_WIN", exitReason, reason);
   if(role == "LAYER_1" && profit >= SmallWinMoneyV4 && !IsMomentumStillValidV4(pt) && !runnerCandidate)
      RequestExitDecisionV4(ticket, EXIT_SMALL_WIN, "LAYER_CLOSED_SMALL_WIN", exitReason, reason);
   else if(role == "LAYER_1" && runnerCandidate && profit >= SmallWinMoneyV4)
      AuditV4("[V4_RUNNER] SMALL_WIN_BLOCKED_RUNNER_CANDIDATE ticket=" + UlongToText(ticket));

   if(role == "RUNNER")
   {
      if(profit >= SmallWinMoneyV4) AuditV4("[V4_RUNNER] SMALL_TARGET_IGNORED_RUNNER_CONTINUES ticket=" + UlongToText(ticket));
      if(profit >= MediumWinMoneyV4 && IsTrendSupportiveV4(pt)) AuditV4("[V4_RUNNER] MEDIUM_TARGET_IGNORED_STRONG_TREND ticket=" + UlongToText(ticket));
      if(profit >= BigWinMoneyV4) AuditV4("[V4_RUNNER] BIG_TARGET_PROTECTION_ACTIVE ticket=" + UlongToText(ticket));
      if(profit >= RunnerWinMoneyV4 && !IsRunnerStrongV4(ticket, pt) && IsSevereReversalV4(ticket, pt))
         RequestExitDecisionV4(ticket, EXIT_RUNNER_GIVEBACK, "RUNNER_CLOSE_CONFIRMED_REVERSAL", exitReason, reason);
      else if(profit >= RunnerWinMoneyV4 && !IsRunnerStrongV4(ticket, pt))
         AuditV4("[V4_RUNNER] WEAKNESS_PULLBACK_HOLD_NO_CONFIRMED_REVERSAL ticket=" + UlongToText(ticket));
      else if(profit >= RunnerWinMoneyV4 && IsRunnerStrongV4(ticket, pt))
         AuditV4("[V4_RUNNER] RUNNER_CONTINUE_STRONG_TREND ticket=" + UlongToText(ticket));
   }

   return (exitReason != EXIT_NONE);
}

bool ClosePositionV4(ulong ticket, string closeReason)
{
   if(!UseExitOrchestratorV4) return false;
   if(!PositionSelectByTicket(ticket)) return false;
   double traceNetProfit = CurrentPositionProfitMoneyV4(ticket);

   string stage14DenyReason = "";
   double stage14Volume = PositionGetDouble(POSITION_VOLUME);
   if(!Stage14_AuthorizeExit(ticket, "V4_EXIT_ORCHESTRATOR", closeReason, traceNetProfit, stage14Volume, stage14DenyReason))
   {
      AuditV4("[STAGE14_EXIT_AUTHORITY] CLOSE_BLOCKED ticket=" + UlongToText(ticket) + " reason=" + stage14DenyReason);
      return false;
   }

   string v10DenyReason = "";
   if(!V10_ExitAuthority(ticket, closeReason, "ClosePositionV4", v10DenyReason))
   {
      AuditV4("[V4_EXIT_ORCHESTRATOR] CLOSE_BLOCKED_BY_V10 ticket=" + UlongToText(ticket) + " reason=" + closeReason + " blockedReason=" + v10DenyReason);
      return false;
   }

   AuditV4("[V4_CLOSE_TRACE] REQUEST_RECEIVED ticket=" + UlongToText(ticket) + " module=V4_EXIT_ORCHESTRATOR reason=" + closeReason + " profit=" + DoubleToString(traceNetProfit,2));
   AuditV4("[V4_CLOSE_TRACE] BEFORE_PROFIT_HOLD ticket=" + UlongToText(ticket) + " reason=" + closeReason + " netProfit=" + DoubleToString(traceNetProfit,2));
   bool profitHoldBlocked = ShouldBlockMicroProfitCloseV4(ticket, closeReason);
   AuditV4("[V4_CLOSE_TRACE] PROFIT_HOLD_RESULT ticket=" + UlongToText(ticket) + " allowed=" + BoolToText(!profitHoldBlocked) + " reason=" + (profitHoldBlocked ? "MICRO_PROFIT_HOLD_BLOCKED" : "ALLOWED"));
   if(profitHoldBlocked)
      return false;
   int idx = EnsureTicketExitStateV4(ticket);
   bool stage14EmergencyBypass = Stage14_IsEmergencyReason(closeReason);
   if(g_v4TicketExitStates[idx].closeAlreadyRequestedThisTick && !stage14EmergencyBypass)
   {
      g_v4DuplicateClosePreventedCount++;
      AuditV4("[V4_EXIT_ORCHESTRATOR] DUPLICATE_CLOSE_PREVENTED ticket=" + UlongToText(ticket));
      return false;
   }
   if(IsExitLockActiveV4(ticket, closeReason) && !stage14EmergencyBypass)
   {
      g_v4DuplicateClosePreventedCount++;
      AuditV4("[V4_EXIT_ORCHESTRATOR] DUPLICATE_CLOSE_PREVENTED ticket=" + UlongToText(ticket));
      return false;
   }

   g_v4TicketExitStates[idx].closeAlreadyRequestedThisTick = true;
   g_v4TicketExitStates[idx].lastExitDecisionTime = TimeCurrent();
   g_v4TicketExitStates[idx].lastExitReason = closeReason;
   SetExitLockV4(ticket, closeReason);

    g_v4LastExitReason = closeReason;
    int liveStateIdxV10 = EnsureTicketExitStateV4(ticket);
    AuditV4("[EXIT_AUTHORITY_V10] ticket=" + UlongToText(ticket)
          + " class=" + g_v4TicketExitStates[liveStateIdxV10].liveExitClass
          + " profit=" + DoubleToString(traceNetProfit,2)
          + " mfe=" + DoubleToString(g_v4TicketExitStates[liveStateIdxV10].profitPeakMoney,2)
          + " mae=" + DoubleToString(g_v4TicketExitStates[liveStateIdxV10].maxAdverseMoney,2)
          + " beActive=" + BoolToText(g_v4TicketExitStates[liveStateIdxV10].breakEvenActivated)
          + " lockActive=" + BoolToText(g_v4TicketExitStates[liveStateIdxV10].lockActivated)
          + " trailActive=" + BoolToText(g_v4TicketExitStates[liveStateIdxV10].trailingActivated)
          + " exitCandidate=POSITION_CLOSE"
          + " exitAllowed=TRUE"
          + " exitReason=" + closeReason
          + " authorizedBy=ClosePositionV4");
    AuditV4("[V4_EXIT_ORCHESTRATOR] SELECTED_EXIT_REASON ticket=" + UlongToText(ticket) + " reason=" + closeReason);

   if(StringFind(closeReason, "SMART") >= 0 || StringFind(closeReason, "CONFIRMED_3_OF_5") >= 0) g_v4SmartExitCloseCount++;
   if(StringFind(closeReason, "RUNNER") >= 0) g_v4RunnerCloseCount++;
   if(StringFind(closeReason, "GIVEBACK") >= 0) g_v4GivebackCloseCount++;
   if(StringFind(closeReason, "BREAK_EVEN") >= 0) g_v4BreakEvenCloseCount++;
   if(StringFind(closeReason, "MEDIUM_WIN") >= 0 || StringFind(closeReason, "SMALL_WIN") >= 0) g_v4BasketProfitCloseCount++;
   if(StringFind(closeReason, "SL_HIT") >= 0 || StringFind(closeReason, "EMERGENCY") >= 0) g_v4EmergencyCloseCount++;

   if(UseExitCalibrationDiagnosticV4)
   {
      AuditV4("[V4_EXIT_DIAGNOSTIC] WOULD_CLOSE ticket=" + UlongToText(ticket) + " reason=" + closeReason);
      return false;
   }

   AuditV4("[V4_CLOSE_TRACE] BEFORE_POSITION_CLOSE ticket=" + UlongToText(ticket) + " finalReason=" + closeReason + " module=V4_EXIT_ORCHESTRATOR");
   trade.SetExpertMagicNumber((ulong)MagicNumber);
   trade.SetDeviationInPoints(RealExecutionDeviationPoints);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   AuditV4("[V4_CLOSE_TRACE] POSITION_CLOSE_SENT ticket=" + UlongToText(ticket) + " reason=" + closeReason + " module=V4_EXIT_ORCHESTRATOR");
   bool ok = trade.PositionClose(ticket);
   if(ok)
   {
      g_v4LastSmartExitCloseTime = TimeCurrent();
      g_v4LastSmartExitDirection = V4PositionTypeToText(posType);
      Stage14_MarkExitExecuted(ticket, "V4_EXIT_ORCHESTRATOR", closeReason, Stage14_PriorityFromReason(closeReason));
      Stage14_AuditExitExecution(ticket, "V4_EXIT_ORCHESTRATOR", closeReason, true);
      AuditV4("[V4_EXIT_ORCHESTRATOR] POSITION_CLOSED ticket=" + UlongToText(ticket) + " reason=" + closeReason);
      AuditV4("[V4_CLOSE_TRACE] POSITION_CLOSE_RESULT ticket=" + UlongToText(ticket) + " retcode=" + trade.ResultRetcodeDescription() + " ok=TRUE");
   }
   else
   {
      Stage14_AuditExitExecution(ticket, "V4_EXIT_ORCHESTRATOR", closeReason, false);
      AuditV4("[V4_EXIT_ORCHESTRATOR] CLOSE_FAILED ticket=" + UlongToText(ticket) + " error=" + trade.ResultRetcodeDescription());
      AuditV4("[V4_CLOSE_TRACE] POSITION_CLOSE_RESULT ticket=" + UlongToText(ticket) + " retcode=" + trade.ResultRetcodeDescription() + " ok=FALSE");
   }
   return ok;
}

void ManageMainPositionV4()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      string v10LoopReject = "";
      if(!V10_ShouldAcceptPosition(ticket, i, v10LoopReject)) continue;
      if(GetRoleForTicketV4(ticket) != "MAIN") continue;

      // V9: tentar Partial Close antes da saÃ­da total
      // Fecha 50% em $12+ garantindo lucro real, deixa 50% correr como runner
      string partialReason = "";
      if(V9_TryPartialClose(ticket, partialReason))
      {
         AuditV4("[V9_MAIN_MANAGER] PARTIAL_CLOSE_EXECUTED ticket=" + UlongToText(ticket) + " " + partialReason);
         // ApÃ³s partial close: nÃ£o fechar o restante neste tick
         continue;
      }

      ENUM_V4_EXIT_REASON p; string r;
      if(SelectBestExitReasonV4(ticket, p, r)) ClosePositionV4(ticket, r);
   }
}

void ManageLayerPositionV4()
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      string v10LoopReject = "";
      if(!V10_ShouldAcceptPosition(ticket, i, v10LoopReject)) continue;
      if(GetRoleForTicketV4(ticket) != "LAYER_1") continue;
      ENUM_V4_EXIT_REASON p; string r;
      if(SelectBestExitReasonV4(ticket, p, r)) ClosePositionV4(ticket, r);
   }
}

void ManageRunnerPositionV4()
{
   if(!UseRunnerV4) return;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      string v10LoopReject = "";
      if(!V10_ShouldAcceptPosition(ticket, i, v10LoopReject)) continue;
      if(GetRoleForTicketV4(ticket) != "RUNNER") continue;
      AuditV4("[V4_RUNNER] RUNNER_ASSIGNED ticket=" + UlongToText(ticket));
      ENUM_V4_EXIT_REASON p; string r;
      if(SelectBestExitReasonV4(ticket, p, r)) ClosePositionV4(ticket, r);
      else AuditV4("[V4_RUNNER] RUNNER_CONTINUE_STRONG_TREND ticket=" + UlongToText(ticket));
   }
}

void UpdateSmartProfitPotentialExitV4()
{
   if(!UseSmartExitV4 || !UseSmartProfitPotentialExitV4) return;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      string v10LoopReject = "";
      if(!V10_ShouldAcceptPosition(ticket, i, v10LoopReject)) continue;
      ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      string reason = "";
      if(ShouldCloseBadTradeEarlyV4(ticket, pt, reason))
         ClosePositionV4(ticket, reason);
      else if(UseExitCalibrationDiagnosticV4)
         AuditV4("[V4_EXIT_DIAGNOSTIC] WOULD_KEEP ticket=" + UlongToText(ticket) + " reason=" + reason);
   }
}

void PrintV4ExitReport()
{
   AuditV4("[V4_EXIT_REPORT] SmartExitClose=" + IntegerToString(g_v4SmartExitCloseCount));
   AuditV4("[V4_EXIT_REPORT] RunnerClose=" + IntegerToString(g_v4RunnerCloseCount));
   AuditV4("[V4_EXIT_REPORT] GivebackClose=" + IntegerToString(g_v4GivebackCloseCount));
   AuditV4("[V4_EXIT_REPORT] BreakEvenClose=" + IntegerToString(g_v4BreakEvenCloseCount));
   AuditV4("[V4_EXIT_REPORT] BasketProfitClose=" + IntegerToString(g_v4BasketProfitCloseCount));
   AuditV4("[V4_EXIT_REPORT] EmergencyClose=" + IntegerToString(g_v4EmergencyCloseCount));
   AuditV4("[V4_EXIT_REPORT] RunnerProtected=" + IntegerToString(g_v4RunnerProtectedCount));
   AuditV4("[V4_EXIT_REPORT] EarlyClosePrevented=" + IntegerToString(g_v4EarlyClosePreventedCount));
   AuditV4("[V4_EXIT_REPORT] DuplicateClosePrevented=" + IntegerToString(g_v4DuplicateClosePreventedCount));
   AuditV4("[V4_EARLY_CLOSE_REPORT] MicroProfitBlocked=" + IntegerToString(g_v4MicroProfitCloseBlockedCount));
   AuditV4("[V4_EARLY_CLOSE_REPORT] MicroProfitAllowed=" + IntegerToString(g_v4MicroProfitCloseAllowedCount));
   AuditV4("[V4_EARLY_CLOSE_REPORT] EarlySmallWinBlocked=" + IntegerToString(g_v4EarlySmallWinBlockedCount));
   AuditV4("[V4_EARLY_CLOSE_REPORT] EarlyBasketCloseBlocked=" + IntegerToString(g_v4EarlyBasketCloseBlockedCount));
   AuditV4("[V4_EARLY_CLOSE_REPORT] EarlyTimeExitBlocked=" + IntegerToString(g_v4EarlyTimeExitBlockedCount));
   AuditV4("[V4_EARLY_CLOSE_REPORT] RunnerMicroCloseBlocked=" + IntegerToString(g_v4RunnerMicroCloseBlockedCount));
}

string ResultClassToTextV4(ENUM_RESULT_CLASS_V4 cls)
{
   switch(cls)
   {
      case RESULT_SMALL_WIN_V4: return "SMALL_WIN";
      case RESULT_MEDIUM_WIN_V4: return "MEDIUM_WIN";
      case RESULT_BIG_WIN_V4: return "BIG_WIN";
      case RESULT_RUNNER_WIN_V4: return "RUNNER_WIN";
      case RESULT_SMALL_LOSS_V4: return "SMALL_LOSS";
      case RESULT_CONTROLLED_LOSS_V4: return "CONTROLLED_LOSS";
      case RESULT_EMERGENCY_LOSS_V4: return "EMERGENCY_LOSS";
      default: return "NONE";
   }
}

ENUM_RESULT_CLASS_V4 ClassifyResultV4(double profit, string role)
{
   if(profit > 0.0)
   {
      if(role == "RUNNER" && profit >= RunnerWinMoneyV4) return RESULT_RUNNER_WIN_V4;
      if(profit >= BigWinMoneyV4) return RESULT_BIG_WIN_V4;
      if(profit >= MediumWinMoneyV4) return RESULT_MEDIUM_WIN_V4;
      return RESULT_SMALL_WIN_V4;
   }
   if(profit <= BasketEmergencySLMoneyV4) return RESULT_EMERGENCY_LOSS_V4;
   if(profit <= LayerSLMoneyV4) return RESULT_CONTROLLED_LOSS_V4;
   return RESULT_SMALL_LOSS_V4;
}

void RegisterResultClassV4(double profit, string role, ulong ticket)
{
   ENUM_RESULT_CLASS_V4 cls = ClassifyResultV4(profit, role);
   string t = ResultClassToTextV4(cls);
   g_v4LastResultClass = t;
   if(cls == RESULT_SMALL_WIN_V4) g_v4SmallWinCount++;
   else if(cls == RESULT_MEDIUM_WIN_V4) g_v4MediumWinCount++;
   else if(cls == RESULT_BIG_WIN_V4) g_v4BigWinCount++;
   else if(cls == RESULT_RUNNER_WIN_V4) g_v4RunnerWinCount++;
   else if(cls == RESULT_SMALL_LOSS_V4) g_v4SmallLossCount++;
   else if(cls == RESULT_CONTROLLED_LOSS_V4) g_v4ControlledLossCount++;
   else if(cls == RESULT_EMERGENCY_LOSS_V4) g_v4EmergencyLossCount++;
   if(profit > 0.0) { g_v4ClosedWinCount++; g_v4TotalWinMoney += profit; if(profit > g_v4LargestWin) g_v4LargestWin = profit; }
   if(profit < 0.0) { g_v4ClosedLossCount++; g_v4TotalLossMoney += profit; if(profit < g_v4LargestLoss) g_v4LargestLoss = profit; }
   AuditV4("[V4_RESULT_CLASSIFICATION] ticket=" + UlongToText(ticket) + " role=" + role + " profit=" + DoubleToString(profit,2) + " class=" + t);
}

void UpdateAggressiveResultEngineV4()
{
   if(!UseResultClassificationV4 || !UseAggressiveResultEngineV4) return;
   datetime now = TimeCurrent();
   datetime from = g_v4LastHistoryScanTime;
   if(from <= 0) from = now - 86400;
   if(!HistorySelect(from, now)) return;
   int deals = HistoryDealsTotal();
   for(int i=0; i<deals; i++)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0) continue;
      datetime dt = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      if(dt <= g_v4LastHistoryScanTime) continue;
      string sym = HistoryDealGetString(deal, DEAL_SYMBOL);
      if(sym != _Symbol) continue;
      long magic = (long)HistoryDealGetInteger(deal, DEAL_MAGIC);
      if(magic != MagicNumber) continue;
      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) continue;
      double profit = HistoryDealGetDouble(deal, DEAL_PROFIT) + HistoryDealGetDouble(deal, DEAL_SWAP) + HistoryDealGetDouble(deal, DEAL_COMMISSION);
      ulong posId = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
      string role = GetRoleForTicketV4(posId);
      RegisterResultClassV4(profit, role, posId);
   }
   g_v4LastHistoryScanTime = now;
   double avgWin = (g_v4ClosedWinCount > 0 ? g_v4TotalWinMoney / g_v4ClosedWinCount : 0.0);
   double avgLoss = (g_v4ClosedLossCount > 0 ? g_v4TotalLossMoney / g_v4ClosedLossCount : 0.0);
   AuditV4("[V4_RESULT_STATS] smallWins=" + IntegerToString(g_v4SmallWinCount) + " mediumWins=" + IntegerToString(g_v4MediumWinCount) + " bigWins=" + IntegerToString(g_v4BigWinCount) + " runnerWins=" + IntegerToString(g_v4RunnerWinCount) + " avgWin=" + DoubleToString(avgWin,2) + " avgLoss=" + DoubleToString(avgLoss,2));
}

class CAggressiveResultDistributionEngineV4
{
public:
   void UpdateAggressiveResultEngineV4() { ::UpdateAggressiveResultEngineV4(); }
};

CAggressiveResultDistributionEngineV4 g_v4ResultEngine;

void UpdateV4LossStreakControl()
{
   if(!UseLossStreakControlV4) return;
   int lossStreak = CountCurrentLossStreakV32();
   if(lossStreak >= MaxLossStreakV4 && g_v4LossStreakPauseUntil < TimeCurrent())
   {
      g_v4LossStreakPauseUntil = TimeCurrent() + LossStreakPauseMinutesV4 * 60;
      AuditV4("[V4_LOSS_STREAK] PAUSE_STARTED lossStreak=" + IntegerToString(lossStreak));
   }
   if(g_v4LossStreakPauseUntil > TimeCurrent())
      AuditV4("[V4_LOSS_STREAK] PAUSE_ACTIVE until=" + TimeToString(g_v4LossStreakPauseUntil, TIME_SECONDS));
   else if(g_v4LossStreakPauseUntil > 0)
   {
      AuditV4("[V4_LOSS_STREAK] PAUSE_EXPIRED");
      g_v4LossStreakPauseUntil = 0;
   }
   if(ResetLossStreakAfterNoTradesWindowV4 && g_v32LastNewCycleTime > 0 && (TimeCurrent() - g_v32LastNewCycleTime) > ResetLossStreakNoTradesMinutesV4 * 60)
      AuditV4("[V4_LOSS_STREAK] RESET_AFTER_NO_TRADES");
}



//+------------------------------------------------------------------+
//| STAGE 12/13 FULL INTEGRATION COMPATIBILITY LAYER                 |
//| This compact adapter lets Stage 13 control the existing full EA.  |
//+------------------------------------------------------------------+

input bool   UseStage12_InstitutionalEngine       = true;
input bool   Stage12_SimulationOnly               = true;
input bool   Stage12_CommercialSafeMode           = true;
input double Stage12_MainLot                      = 0.10;
input double Stage12_Layer1Lot                    = 0.25;   // PATCH_LAYER_010_025_040
input double Stage12_RunnerLot                    = 0.40;   // PATCH_LAYER_010_025_040
input double Stage12_MaxDirectionalLots           = 0.75;   // PATCH_LAYER_010_025_040
input int    Stage12_MaxDirectionalPositions      = 3;
input double Stage12_Main_MinScore                = 75.0;
input double Stage12_Layer1_MinScore              = 75.0;   // PATCH_LAYER_010_025_040
input double Stage12_Runner_MinScore              = 85.0;   // PATCH_LAYER_010_025_040
input double Stage12_Layer1_MinBasketProfit       = -15.0;   // PATCH_LAYER_010_025_040: permite pullback controlado atÃ© -15 USD
input double Stage12_Runner_MinBasketProfit       = 15.0;   // PATCH_LAYER_010_025_040
input double Stage12_Runner_MinPeakProfit         = 20.0;   // PATCH_LAYER_010_025_040
input int    Stage12_MaxSpreadPoints              = 35;
input int    Stage12_MinSecondsBetweenEntry       = 45;
input int    Stage12_MinSecondsBetweenScale       = 90;
input bool   Stage12_BlockEntriesOnHedge          = true;
input bool   Stage12_BlockScalingOnHedge          = true;
input bool   Stage12_BlockScalingOnNegativeBasket = false;   // PATCH_LAYER_010_025_040: pullback controlado Ã© validado pelo mÃ³dulo de layer
input double RiskGovEmergencyDDPercent            = 1.20;

string   g_stage12LastRole = "NONE";
double   g_stage12LastApprovedLot = 0.0;
string   g_stage12LastReason = "INIT";
datetime g_stage12LastEntryTime = 0;
datetime g_stage12LastScaleTime = 0;
double   g_stage12BasketPeakProfit = 0.0;

void Stage12_Log(string msg)
{
   if(PrintDetailedLogs)
      Print("[HORSE EA][STAGE12_AUTHORITY] ", msg);
}

double RiskGov_CurrentDDPercent()
{
   return g_risk.dailyDrawdownPercent;
}

bool RiskGov_IsEmergencyStopActive()
{
   if(g_positionEmergencyBlock || g_positionEmergencyClosed) return true;
   if(g_risk.tradingLocked && StringFind(g_risk.lockReason, "EMERGENCY") >= 0) return true;
   if(g_basket.netProfit <= BasketEmergencyLossMoney) return true;
   return false;
}

double Stage12_NormalizeLot(double lot)
{
   double minVol=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxVol=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(minVol<=0.0) minVol=0.01;
   if(maxVol<minVol) maxVol=minVol;
   if(step<=0.0) step=minVol;
   lot=MathMax(minVol,MathMin(maxVol,lot));
   lot=MathFloor(lot/step)*step;
   return NormalizeDouble(lot,2);
}

bool Stage12_HasHedge()
{
   bool hasBuy=false, hasSell=false;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type==POSITION_TYPE_BUY) hasBuy=true;
      if(type==POSITION_TYPE_SELL) hasSell=true;
   }
   return hasBuy && hasSell;
}

double Stage12_TotalMagicLots()
{
   double lots=0.0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      lots += PositionGetDouble(POSITION_VOLUME);
   }
   return lots;
}

string Stage12_NextRole()
{
   int count=V4CountMagicPositions();
   if(count<=0) return "MAIN";
   if(count==1) return "LAYER_1";
   if(count==2) return "RUNNER";
   return "MAXED";
}

double Stage12_LotByRole(string role)
{
   if(role=="MAIN") return Stage12_NormalizeLot(Stage12_MainLot);
   if(role=="LAYER_1") return Stage12_NormalizeLot(Stage12_Layer1Lot);
   if(role=="RUNNER") return Stage12_NormalizeLot(Stage12_RunnerLot);
   return 0.0;
}

double Stage12_CurrentEntryScore()
{
   return MathMax(MathMax(g_buyDecisionScore,g_sellDecisionScore),MathMax(g_entryDecisionScore,g_entryBaseScore));
}

bool Stage12_MarketAndRiskOK(string role,string &reason)
{
   if(!UseStage12_InstitutionalEngine){ reason="STAGE12_OFF"; return true; }
   if(g_risk.tradingLocked){ reason="RISK_LOCKED: "+g_risk.lockReason; return false; }
   if(Stage12_BlockEntriesOnHedge && Stage12_HasHedge()){ reason="HEDGE_ACTIVE_BLOCK_ENTRY"; return false; }
   if(GetCurrentSpreadPoints()>Stage12_MaxSpreadPoints){ reason="STAGE12_SPREAD_HIGH"; return false; }
   if(V4CountMagicPositions()>=Stage12_MaxDirectionalPositions){ reason="STAGE12_MAX_POSITIONS"; return false; }
   double score=Stage12_CurrentEntryScore();
   if(role=="MAIN" && score<Stage12_Main_MinScore){ reason="STAGE12_MAIN_SCORE_LOW=" + DoubleToString(score,1); return false; }
   if(role=="LAYER_1" && score<Stage12_Layer1_MinScore){ reason="STAGE12_LAYER1_SCORE_LOW=" + DoubleToString(score,1); return false; }
   if(role=="RUNNER" && score<Stage12_Runner_MinScore){ reason="STAGE12_RUNNER_SCORE_LOW=" + DoubleToString(score,1); return false; }
   double basket=g_basket.netProfit;
   if(basket>g_stage12BasketPeakProfit) g_stage12BasketPeakProfit=basket;
   if(role=="LAYER_1")
   {
      if(TimeCurrent()-g_stage12LastScaleTime<Stage12_MinSecondsBetweenScale){ reason="STAGE12_LAYER1_COOLDOWN"; return false; }
      if(basket<Stage12_Layer1_MinBasketProfit){ reason="STAGE12_LAYER1_NEEDS_PROFIT=" + DoubleToString(basket,2); return false; }
   }
   if(role=="RUNNER")
   {
      if(TimeCurrent()-g_stage12LastScaleTime<Stage12_MinSecondsBetweenScale){ reason="STAGE12_RUNNER_COOLDOWN"; return false; }
      if(basket<Stage12_Runner_MinBasketProfit){ reason="STAGE12_RUNNER_NEEDS_PROFIT=" + DoubleToString(basket,2); return false; }
      if(g_stage12BasketPeakProfit<Stage12_Runner_MinPeakProfit){ reason="STAGE12_RUNNER_NEEDS_PEAK=" + DoubleToString(g_stage12BasketPeakProfit,2); return false; }
   }
   if(TimeCurrent()-g_stage12LastEntryTime<Stage12_MinSecondsBetweenEntry){ reason="STAGE12_ENTRY_COOLDOWN"; return false; }
   reason="STAGE12_MARKET_AND_RISK_OK role="+role;
   return true;
}

bool Stage12_NewEntryGuard(double &approvedLot,string &approvedRole,string &reason)
{
   approvedRole=Stage12_NextRole();
   if(approvedRole=="MAXED"){ reason="STAGE12_ROLE_MAXED"; return false; }
   approvedLot=Stage12_LotByRole(approvedRole);
   if(approvedLot<=0.0){ reason="STAGE12_INVALID_LOT"; return false; }
   if(Stage12_TotalMagicLots()+approvedLot>Stage12_MaxDirectionalLots+0.000001)
   {
      reason="STAGE12_MAX_DIRECTIONAL_LOTS total="+DoubleToString(Stage12_TotalMagicLots(),2)+" next="+DoubleToString(approvedLot,2);
      return false;
   }
   if(!Stage12_MarketAndRiskOK(approvedRole,reason)) return false;
   g_stage12LastRole=approvedRole;
   g_stage12LastApprovedLot=approvedLot;
   g_stage12LastReason=reason;
   return true;
}

bool Stage12_ScaleGuard(string &reason)
{
   if(!UseStage12_InstitutionalEngine){ reason="STAGE12_OFF_SCALE_ALLOWED"; return true; }
   if(Stage12_BlockScalingOnHedge && Stage12_HasHedge()){ reason="STAGE12_SCALE_BLOCK_HEDGE_ACTIVE"; return false; }
   if(Stage12_BlockScalingOnNegativeBasket && g_basket.netProfit<0.0){ reason="STAGE12_SCALE_BLOCK_NEGATIVE_BASKET"; return false; }
   string role=Stage12_NextRole();
   if(role!="LAYER_1" && role!="RUNNER"){ reason="STAGE12_SCALE_ROLE_NOT_ALLOWED="+role; return false; }
   double tmpLot=0.0; string tmpRole="";
   return Stage12_NewEntryGuard(tmpLot,tmpRole,reason);
}

void Stage12_MarkEntryExecuted(string role)
{
   g_stage12LastEntryTime=TimeCurrent();
   if(role=="LAYER_1" || role=="RUNNER") g_stage12LastScaleTime=TimeCurrent();
   g_stage12LastRole=role;
   Stage12_Log("ENTRY_EXECUTED role="+role);
}


//+------------------------------------------------------------------+
//| STAGE 12 - REAL HEDGE AIRBAG EXECUTOR                            |
//| Defensive hedge engine: partial/full hedge by basket DD.          |
//+------------------------------------------------------------------+
input bool   Stage12_UseHedgeAirbag               = false;
input double Stage12_PartialHedgeMoney            = -40.0;
input double Stage12_FullHedgeMoney               = -100.0;
input double Stage12_EmergencyMoney               = -150.0;
input double Stage12_PartialHedgeRatio            = 0.50;
input double Stage12_FullHedgeRatio               = 1.00;
input double Stage12_MaxHedgeLot                  = 0.55;
input int    Stage12_MinSecondsBeforeHedge        = 15;
input int    Stage12_MinSecondsBetweenHedges      = 90;
input int    Stage12_MaxSpreadToHedgePoints       = 60;
input bool   Stage12_HedgeOnlyWhenNetExposure     = true;
input bool   Stage12_AllowFullHedgeUpgrade        = true;
input bool   Stage12_ShowHedgeDiagnostics         = true;

int      g_stage12HedgeRequests = 0;
int      g_stage12HedgesOpened = 0;
int      g_stage12HedgesDenied = 0;
int      g_stage12PartialHedgesOpened = 0;
int      g_stage12FullHedgesOpened = 0;
int      g_stage12EmergencyActivations = 0;
datetime g_stage12LastHedgeTime = 0;
datetime g_stage12HedgeCycleStartTime = 0;
string   g_stage12LastHedgeAction = "NONE";
string   g_stage12LastHedgeReason = "INIT";
double   g_stage12LastHedgeLot = 0.0;
string   g_stage12LastHedgeMode = "NONE";

void Stage12_Exposure(double &buyLots,double &sellLots,double &netLots,ENUM_POSITION_TYPE &netSide)
{
   buyLots=0.0; sellLots=0.0; netLots=0.0; netSide=POSITION_TYPE_BUY;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double vol=PositionGetDouble(POSITION_VOLUME);
      if(type==POSITION_TYPE_BUY) buyLots+=vol;
      if(type==POSITION_TYPE_SELL) sellLots+=vol;
   }
   if(buyLots>=sellLots){ netLots=buyLots-sellLots; netSide=POSITION_TYPE_BUY; }
   else { netLots=sellLots-buyLots; netSide=POSITION_TYPE_SELL; }
}

string Stage12_HedgeComment(ENUM_POSITION_TYPE hedgeSide,string mode)
{
   string side=(hedgeSide==POSITION_TYPE_BUY ? "BUY" : "SELL");
   return "STAGE12_HEDGE_" + side + "_" + mode;
}

bool Stage12_IsStage12HedgePosition()
{
   string c=PositionGetString(POSITION_COMMENT);
   StringToUpper(c);
   if(StringFind(c,"STAGE12_HEDGE_BUY")>=0) return true;
   if(StringFind(c,"STAGE12_HEDGE_SELL")>=0) return true;
   if(StringFind(c,"SMART_HEDGE_BUY")>=0) return true;
   if(StringFind(c,"SMART_HEDGE_SELL")>=0) return true;
   return false;
}

double Stage12_CurrentHedgeLots(ENUM_POSITION_TYPE side)
{
   double lots=0.0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)!=side) continue;
      if(!Stage12_IsStage12HedgePosition()) continue;
      lots += PositionGetDouble(POSITION_VOLUME);
   }
   return lots;
}

bool Stage12_CanAttemptHedge(string &reason)
{
   if(!UseStage12_InstitutionalEngine){ reason="STAGE12_OFF"; return false; }
   if(!Stage12_UseHedgeAirbag){ reason="HEDGE_AIRBAG_OFF"; return false; }
   if(V4CountMagicPositions()<=0){ reason="NO_MANAGED_POSITION"; return false; }
   if(GetCurrentSpreadPoints()>Stage12_MaxSpreadToHedgePoints){ reason="SPREAD_TOO_HIGH_FOR_HEDGE="+IntegerToString(GetCurrentSpreadPoints()); return false; }
   if(g_stage12LastHedgeTime>0 && TimeCurrent()-g_stage12LastHedgeTime<Stage12_MinSecondsBetweenHedges){ reason="HEDGE_COOLDOWN"; return false; }
   if(g_stage12LastEntryTime>0 && TimeCurrent()-g_stage12LastEntryTime<Stage12_MinSecondsBeforeHedge){ reason="TOO_SOON_AFTER_ENTRY"; return false; }
   if(g_risk.tradingLocked && StringFind(g_risk.lockReason,"EMERGENCY")>=0){ reason="RISK_EMERGENCY_LOCK"; return false; }
   reason="HEDGE_ATTEMPT_ALLOWED";
   return true;
}

bool Stage12_OpenHedge(double ratio,string mode,string triggerReason)
{
   g_stage12HedgeRequests++;

   string guardReason="";
   if(!Stage12_CanAttemptHedge(guardReason))
   {
      g_stage12HedgesDenied++;
      g_stage12LastHedgeAction="DENIED";
      g_stage12LastHedgeReason=guardReason + " | " + triggerReason;
      if(Stage12_ShowHedgeDiagnostics) Stage12_Log("HEDGE_DENIED mode="+mode+" reason="+g_stage12LastHedgeReason);
      return false;
   }

   double buyLots=0.0,sellLots=0.0,netLots=0.0;
   ENUM_POSITION_TYPE netSide=POSITION_TYPE_BUY;
   Stage12_Exposure(buyLots,sellLots,netLots,netSide);

   if(Stage12_HedgeOnlyWhenNetExposure && netLots<=0.0)
   {
      g_stage12HedgesDenied++;
      g_stage12LastHedgeAction="DENIED";
      g_stage12LastHedgeReason="NET_EXPOSURE_ZERO | "+triggerReason;
      Stage12_Log("HEDGE_DENIED mode="+mode+" reason="+g_stage12LastHedgeReason);
      return false;
   }

   ENUM_POSITION_TYPE hedgeSide=(netSide==POSITION_TYPE_BUY ? POSITION_TYPE_SELL : POSITION_TYPE_BUY);
   double desiredTotalHedgeLot=Stage12_NormalizeLot(netLots*ratio);
   desiredTotalHedgeLot=MathMin(desiredTotalHedgeLot,Stage12_MaxHedgeLot);

   double existingHedgeLots=Stage12_CurrentHedgeLots(hedgeSide);
   double hedgeLot=desiredTotalHedgeLot-existingHedgeLots;
   if(hedgeLot<=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN)/2.0)
   {
      g_stage12HedgesDenied++;
      g_stage12LastHedgeAction="DENIED";
      g_stage12LastHedgeReason="HEDGE_ALREADY_SUFFICIENT existing="+DoubleToString(existingHedgeLots,2)+" desired="+DoubleToString(desiredTotalHedgeLot,2);
      Stage12_Log("HEDGE_DENIED mode="+mode+" reason="+g_stage12LastHedgeReason);
      return false;
   }

   hedgeLot=Stage12_NormalizeLot(hedgeLot);
   if(hedgeLot<=0.0)
   {
      g_stage12HedgesDenied++;
      g_stage12LastHedgeAction="DENIED";
      g_stage12LastHedgeReason="INVALID_HEDGE_LOT";
      Stage12_Log("HEDGE_DENIED mode="+mode+" reason="+g_stage12LastHedgeReason);
      return false;
   }

   string comment=Stage12_HedgeComment(hedgeSide,mode);

   if(Stage12_SimulationOnly)
   {
      g_stage12HedgesOpened++;
      if(mode=="PARTIAL") g_stage12PartialHedgesOpened++;
      if(mode=="FULL") g_stage12FullHedgesOpened++;
      g_stage12LastHedgeTime=TimeCurrent();
      if(g_stage12HedgeCycleStartTime<=0) g_stage12HedgeCycleStartTime=TimeCurrent();
      g_stage12LastHedgeAction="SIMULATED_OPEN";
      g_stage12LastHedgeReason=triggerReason;
      g_stage12LastHedgeLot=hedgeLot;
      g_stage12LastHedgeMode=mode;
      Stage12_Log("[SIMULATION] HEDGE_OPEN mode="+mode+" lot="+DoubleToString(hedgeLot,2)+" comment="+comment+" reason="+triggerReason);
      return true;
   }

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(MaxRealExecutionSlippagePoints);

   bool ok=false;
   if(hedgeSide==POSITION_TYPE_BUY)
      ok=trade.Buy(hedgeLot,_Symbol,0.0,0.0,0.0,comment);
   else
      ok=trade.Sell(hedgeLot,_Symbol,0.0,0.0,0.0,comment);

   if(ok)
   {
      g_stage12HedgesOpened++;
      if(mode=="PARTIAL") g_stage12PartialHedgesOpened++;
      if(mode=="FULL") g_stage12FullHedgesOpened++;
      g_stage12LastHedgeTime=TimeCurrent();
      if(g_stage12HedgeCycleStartTime<=0) g_stage12HedgeCycleStartTime=TimeCurrent();
      g_stage12LastHedgeAction="OPENED";
      g_stage12LastHedgeReason=triggerReason;
      g_stage12LastHedgeLot=hedgeLot;
      g_stage12LastHedgeMode=mode;
      Stage12_Log("HEDGE_OPENED mode="+mode+" side="+(hedgeSide==POSITION_TYPE_BUY?"BUY":"SELL")+" lot="+DoubleToString(hedgeLot,2)+" basket="+DoubleToString(g_basket.netProfit,2)+" comment="+comment);
      return true;
   }

   g_stage12HedgesDenied++;
   g_stage12LastHedgeAction="FAILED";
   g_stage12LastHedgeReason=trade.ResultRetcodeDescription();
   Stage12_Log("HEDGE_OPEN_FAILED mode="+mode+" lot="+DoubleToString(hedgeLot,2)+" ret="+g_stage12LastHedgeReason);
   return false;
}

void Stage12_HedgeAirbagOnTick()
{
   if(Stage17_ForceLegacyHedgeAirbagOff && UseStage17DualSideConfirmation)
   {
      if(Stage17_DebugLogs && (g_stage17LastLegacyAirbagLogTime <= 0 || TimeCurrent() - g_stage17LastLegacyAirbagLogTime >= 60))
      {
         g_stage17LastLegacyAirbagLogTime = TimeCurrent();
         Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_LEGACY_AIRBAG_OFF_V10] reason=Stage17 enabled / Stage12_UseHedgeAirbag=",
               BoolToText(Stage12_UseHedgeAirbag));
      }
      return;
   }
   if(!UseStage12_InstitutionalEngine || !Stage12_UseHedgeAirbag) return;
   if(V4CountMagicPositions()<=0) return;

   double basket=g_basket.netProfit;

   if(basket<=Stage12_EmergencyMoney)
   {
      g_stage12EmergencyActivations++;
      g_stage12LastHedgeAction="EMERGENCY_TRIGGER";
      g_stage12LastHedgeReason="basket="+DoubleToString(basket,2)+" <= "+DoubleToString(Stage12_EmergencyMoney,2);
      Stage12_Log("HEDGE_EMERGENCY_TRIGGER " + g_stage12LastHedgeReason);
      return;
   }

   if(basket<=Stage12_FullHedgeMoney)
   {
      Stage12_OpenHedge(Stage12_FullHedgeRatio,"FULL","basket="+DoubleToString(basket,2)+" <= full="+DoubleToString(Stage12_FullHedgeMoney,2));
      return;
   }

   if(basket<=Stage12_PartialHedgeMoney && !Stage12_HasHedge())
   {
      Stage12_OpenHedge(Stage12_PartialHedgeRatio,"PARTIAL","basket="+DoubleToString(basket,2)+" <= partial="+DoubleToString(Stage12_PartialHedgeMoney,2));
      return;
   }
}

//+------------------------------------------------------------------+
//| HORSE EA - STAGE 13                                         |
//| FINAL AUTHORITY MANAGER FOR BACKTEST + LIVE EXECUTION            |
//| Objetivo: autoridade unica por decisao, sem duplicidade.          |
//+------------------------------------------------------------------+
//
// INTEGRAR AO EA BASE:
// HORSE_GOLD_AI_V4_FIX3_2_RISKGOV_SMARTHEDGE_STAGE7_PROFIT.mq5
//
// Este patch organiza permissoes e impede:
// - dupla entrada
// - dupla escala
// - duplo hedge
// - hedge orfao
// - SimulationOnly executando ordem real
//+------------------------------------------------------------------+

input bool UseStage13FinalAuthorityManager = true;
input bool Stage13_BlockLegacyStage8RealExecution = true;
input bool Stage13_BlockLegacyStage10RealExecution = true;
input bool Stage13_BlockLegacyStage11RealExecution = true;
input bool Stage13_RequireStage12ForAllEntries = true;
input bool Stage13_RequireStage12ForAllScales  = true;
input bool Stage13_RequireStage12ForAllHedges  = true;
input bool Stage13_AllowEmergencyCloseAlways   = true;
input bool Stage13_ShowWallboard               = true;

enum EA_GLOBAL_STATE
{
   EA_STATE_IDLE = 0,
   EA_STATE_ENTRY_ALLOWED = 1,
   EA_STATE_MAIN_ACTIVE = 2,
   EA_STATE_SCALE_ALLOWED = 3,
   EA_STATE_RUNNER_ALLOWED = 4,
   EA_STATE_PROFIT_PROTECTION = 5,
   EA_STATE_HEDGE_ACTIVE = 6,
   EA_STATE_RESOLVING_HEDGE = 7,
   EA_STATE_EMERGENCY = 8,
   EA_STATE_LOCKED = 9
};

EA_GLOBAL_STATE g_stage13State = EA_STATE_IDLE;
string g_stage13LastDecisionModule = "INIT";
string g_stage13LastDecisionReason = "INIT";
datetime g_stage13LastDecisionTime = 0;

bool g_stage13CanOpenMain = false;
bool g_stage13CanOpenLayer1 = false;
bool g_stage13CanOpenRunner = false;
bool g_stage13CanOpenHedge = false;
bool g_stage13CanScale = false;
bool g_stage13CanResolveHedge = false;
bool g_stage13CanCloseProfit = false;
bool g_stage13CanEmergencyClose = true;

void Stage13_Log(string msg)
{
   if(PrintDetailedLogs)
      Print("[HORSE EA][STAGE13_AUTHORITY] ", msg);
}

string Stage13_StateText()
{
   switch(g_stage13State)
   {
      case EA_STATE_IDLE: return "IDLE";
      case EA_STATE_ENTRY_ALLOWED: return "ENTRY_ALLOWED";
      case EA_STATE_MAIN_ACTIVE: return "MAIN_ACTIVE";
      case EA_STATE_SCALE_ALLOWED: return "SCALE_ALLOWED";
      case EA_STATE_RUNNER_ALLOWED: return "RUNNER_ALLOWED";
      case EA_STATE_PROFIT_PROTECTION: return "PROFIT_PROTECTION";
      case EA_STATE_HEDGE_ACTIVE: return "HEDGE_ACTIVE";
      case EA_STATE_RESOLVING_HEDGE: return "RESOLVING_HEDGE";
      case EA_STATE_EMERGENCY: return "EMERGENCY";
      case EA_STATE_LOCKED: return "LOCKED";
   }
   return "UNKNOWN";
}

void Stage13_SetDecision(string module, string reason)
{
   g_stage13LastDecisionModule = module;
   g_stage13LastDecisionReason = reason;
   g_stage13LastDecisionTime = TimeCurrent();
   Stage13_Log(module + " => " + reason);
}

int Stage13_PositionCount()
{
   int c = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      c++;
   }
   return c;
}

bool Stage13_HasAnyHedge()
{
   bool hasBuy = false;
   bool hasSell = false;
   int magicPositions = 0;
   ulong buyTicket = 0;
   ulong sellTicket = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      magicPositions++;
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY)
      {
         hasBuy = true;
         buyTicket = ticket;
      }
      if(type == POSITION_TYPE_SELL)
      {
         hasSell = true;
         sellTicket = ticket;
      }
   }

   if(hasBuy && hasSell)
   {
      bool stage17Active = (UseStage17DualSideConfirmation &&
                            g_stage17Pair.pairId > 0 &&
                            g_stage17Pair.pairState == STAGE17_PAIR_ACTIVE &&
                            !g_stage17Pair.weakClosed &&
                            magicPositions == 2 &&
                            buyTicket == g_stage17Pair.buyTicket &&
                            sellTicket == g_stage17Pair.sellTicket);
      if(stage17Active)
      {
         bool pairExact = false;
         if(PositionSelectByTicket(buyTicket))
         {
            string buyComment = PositionGetString(POSITION_COMMENT);
            double buyLot = PositionGetDouble(POSITION_VOLUME);
            if(PositionSelectByTicket(sellTicket))
            {
               string sellComment = PositionGetString(POSITION_COMMENT);
               double sellLot = PositionGetDouble(POSITION_VOLUME);
               pairExact = (buyComment == "HORSE DUAL BUY" &&
                            sellComment == "HORSE DUAL SELL" &&
                            MathAbs(buyLot - Stage17_DualSideProbeLot) <= 0.000001 &&
                            MathAbs(sellLot - Stage17_DualSideProbeLot) <= 0.000001);
            }
         }

         if(pairExact)
            return false;
      }
   }

   return hasBuy && hasSell;
}

bool Stage13_PositionCommentMatches(string comment)
{
   string c = comment;
   StringToUpper(c);

   if(StringFind(c, "SMART_HEDGE_BUY") >= 0) return true;
   if(StringFind(c, "SMART_HEDGE_SELL") >= 0) return true;
   if(StringFind(c, "STAGE12_HEDGE_BUY") >= 0) return true;
   if(StringFind(c, "STAGE12_HEDGE_SELL") >= 0) return true;

   return false;
}

bool Stage13_HasRecognizedResolvableHedge()
{
   bool buyHedge = false;
   bool sellHedge = false;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      string comment = PositionGetString(POSITION_COMMENT);
      if(!Stage13_PositionCommentMatches(comment)) continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY) buyHedge = true;
      if(type == POSITION_TYPE_SELL) sellHedge = true;
   }

   return buyHedge && sellHedge;
}

bool Stage13_IsEmergency()
{
   double dd = RiskGov_CurrentDDPercent();

   if(dd >= RiskGovEmergencyDDPercent)
      return true;

   if(RiskGov_IsEmergencyStopActive())
      return true;

   return false;
}

void Stage13_UpdateState()
{
   if(!UseStage13FinalAuthorityManager)
      return;

   g_stage13CanOpenMain = false;
   g_stage13CanOpenLayer1 = false;
   g_stage13CanOpenRunner = false;
   g_stage13CanOpenHedge = false;
   g_stage13CanScale = false;
   g_stage13CanResolveHedge = false;
   g_stage13CanCloseProfit = true;
   g_stage13CanEmergencyClose = true;

   if(Stage13_IsEmergency())
   {
      g_stage13State = EA_STATE_EMERGENCY;
      g_stage13CanCloseProfit = true;
      g_stage13CanResolveHedge = true;
      g_stage13CanEmergencyClose = true;
      Stage13_SetDecision("RiskGovernor", "EMERGENCY_STATE_ACTIVE");
      return;
   }

   if(Stage13_HasAnyHedge())
   {
      g_stage13State = EA_STATE_HEDGE_ACTIVE;
      g_stage13CanResolveHedge = true;
      g_stage13CanCloseProfit = true;
      g_stage13CanEmergencyClose = true;
      Stage13_SetDecision("Stage13", "HEDGE_ACTIVE_BLOCK_ENTRY_AND_SCALE");
      return;
   }

   int positions = Stage13_PositionCount();

   if(positions <= 0)
   {
      g_stage13State = EA_STATE_ENTRY_ALLOWED;
      g_stage13CanOpenMain = true;
      g_stage13CanEmergencyClose = true;
      Stage13_SetDecision("Stage13", "ENTRY_ALLOWED_MAIN");
      return;
   }

   if(positions == 1)
   {
      g_stage13State = EA_STATE_SCALE_ALLOWED;
      g_stage13CanOpenLayer1 = true;
      g_stage13CanScale = true;
      g_stage13CanCloseProfit = true;
      g_stage13CanEmergencyClose = true;
      Stage13_SetDecision("Stage13", "SCALE_ALLOWED_LAYER1");
      return;
   }

   if(positions == 2)
   {
      g_stage13State = EA_STATE_RUNNER_ALLOWED;
      g_stage13CanOpenRunner = true;
      g_stage13CanScale = true;
      g_stage13CanCloseProfit = true;
      g_stage13CanEmergencyClose = true;
      Stage13_SetDecision("Stage13", "RUNNER_ALLOWED");
      return;
   }

   g_stage13State = EA_STATE_LOCKED;
   g_stage13CanCloseProfit = true;
   g_stage13CanEmergencyClose = true;
   Stage13_SetDecision("Stage13", "LOCKED_MAX_POSITIONS");
}

bool Stage13_EntryAuthorityGuard(double &approvedLot, string &approvedRole, string &reason)
{
   Stage13_UpdateState();

   if(!UseStage13FinalAuthorityManager)
   {
      reason = "STAGE13_OFF";
      return true;
   }

   if(g_stage13State == EA_STATE_EMERGENCY || g_stage13State == EA_STATE_LOCKED || g_stage13State == EA_STATE_HEDGE_ACTIVE)
   {
      reason = "STAGE13_BLOCK_ENTRY state=" + Stage13_StateText() + " reason=" + g_stage13LastDecisionReason;
      return false;
   }

   if(Stage13_RequireStage12ForAllEntries)
   {
      bool ok = Stage12_NewEntryGuard(approvedLot, approvedRole, reason);
      if(!ok)
      {
         reason = "STAGE12_ENTRY_DENIED: " + reason;
         return false;
      }

      Stage13_SetDecision("Stage12", "ENTRY_APPROVED role=" + approvedRole + " lot=" + DoubleToString(approvedLot, 2));
      return true;
   }

   reason = "STAGE13_ENTRY_ALLOWED_NO_STAGE12_REQUIRED";
   return true;
}

bool Stage13_ScaleAuthorityGuard(string &reason)
{
   Stage13_UpdateState();

   if(!UseStage13FinalAuthorityManager)
   {
      reason = "STAGE13_OFF";
      return true;
   }

   if(g_stage13State == EA_STATE_EMERGENCY || g_stage13State == EA_STATE_LOCKED || g_stage13State == EA_STATE_HEDGE_ACTIVE)
   {
      reason = "STAGE13_BLOCK_SCALE state=" + Stage13_StateText() + " reason=" + g_stage13LastDecisionReason;
      return false;
   }

   if(Stage13_RequireStage12ForAllScales)
   {
      bool ok = Stage12_ScaleGuard(reason);
      if(!ok)
      {
         reason = "STAGE12_SCALE_DENIED: " + reason;
         return false;
      }

      Stage13_SetDecision("Stage12", "SCALE_APPROVED");
      return true;
   }

   reason = "STAGE13_SCALE_ALLOWED_NO_STAGE12_REQUIRED";
   return true;
}

bool Stage13_HedgeAuthorityGuard(string &reason)
{
   Stage13_UpdateState();

   if(!UseStage13FinalAuthorityManager)
   {
      reason = "STAGE13_OFF";
      return true;
   }

   if(g_stage13State == EA_STATE_EMERGENCY)
   {
      reason = "STAGE13_BLOCK_HEDGE_EMERGENCY_ONLY_CLOSE";
      return false;
   }

   if(Stage13_HasAnyHedge())
   {
      reason = "STAGE13_BLOCK_HEDGE_ALREADY_ACTIVE";
      return false;
   }

   if(Stage13_RequireStage12ForAllHedges)
   {
      reason = "STAGE12_ONLY_CAN_OPEN_HEDGE";
      return false;
   }

   reason = "STAGE13_HEDGE_ALLOWED";
   return true;
}

bool Stage13_CanResolveHedge(string &reason)
{
   Stage13_UpdateState();

   if(!Stage13_HasAnyHedge())
   {
      reason = "NO_HEDGE_ACTIVE";
      return false;
   }

   if(!Stage13_HasRecognizedResolvableHedge())
   {
      reason = "HEDGE_ACTIVE_BUT_NOT_RECOGNIZED_BY_RESOLVER_TAGS";
      return false;
   }

   reason = "RESOLVER_ALLOWED";
   return true;
}

bool Stage13_CanEmergencyClose(string &reason)
{
   reason = "EMERGENCY_CLOSE_ALWAYS_ALLOWED";
   return true;
}

void Stage13_AuditDecision(string eventName, string moduleName, string reason)
{
   string mode = (MQLInfoInteger(MQL_TESTER) ? "BACKTEST" : "LIVE");
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

   string msg = mode +
                " event=" + eventName +
                " module=" + moduleName +
                " state=" + Stage13_StateText() +
                " reason=" + reason +
                " equity=" + DoubleToString(eq, 2) +
                " balance=" + DoubleToString(bal, 2) +
                " spread=" + IntegerToString(spread) +
                " positions=" + IntegerToString(Stage13_PositionCount()) +
                " hedge=" + (Stage13_HasAnyHedge() ? "YES" : "NO");

   Stage13_Log(msg);
}

void Stage13_UpdateWallboard()
{
   if(!Stage13_ShowWallboard)
      return;

   int row = 0;
   AddDashboardLine(row, "HORSE EA - STAGE 13 FINAL AUTHORITY MANAGER");
   AddDashboardLine(row, "State: " + Stage13_StateText());
   AddDashboardLine(row, "Last Module: " + g_stage13LastDecisionModule);
   AddDashboardLine(row, "Last Reason: " + g_stage13LastDecisionReason);
   AddDashboardLine(row, "CanOpenMain: " + BoolToText(g_stage13CanOpenMain));
   AddDashboardLine(row, "CanOpenLayer1: " + BoolToText(g_stage13CanOpenLayer1));
   AddDashboardLine(row, "CanOpenRunner: " + BoolToText(g_stage13CanOpenRunner));
   AddDashboardLine(row, "CanScale: " + BoolToText(g_stage13CanScale));
   AddDashboardLine(row, "CanOpenHedge: " + BoolToText(g_stage13CanOpenHedge));
   AddDashboardLine(row, "CanResolveHedge: " + BoolToText(g_stage13CanResolveHedge));
   AddDashboardLine(row, "CanCloseProfit: " + BoolToText(g_stage13CanCloseProfit));
   AddDashboardLine(row, "CanEmergencyClose: " + BoolToText(g_stage13CanEmergencyClose));
   AddDashboardLine(row, "Positions: " + IntegerToString(Stage13_PositionCount()));
   AddDashboardLine(row, "Hedge Active: " + BoolToText(Stage13_HasAnyHedge()));
   AddDashboardLine(row, "Resolvable Hedge: " + BoolToText(Stage13_HasRecognizedResolvableHedge()));
   AddDashboardLine(row, "Hedge Requests: " + IntegerToString(g_stage12HedgeRequests));
   AddDashboardLine(row, "Hedges Opened: " + IntegerToString(g_stage12HedgesOpened));
   AddDashboardLine(row, "Hedges Denied: " + IntegerToString(g_stage12HedgesDenied));
   AddDashboardLine(row, "Partial / Full: " + IntegerToString(g_stage12PartialHedgesOpened) + " / " + IntegerToString(g_stage12FullHedgesOpened));
   AddDashboardLine(row, "Last Hedge: " + g_stage12LastHedgeAction + " " + g_stage12LastHedgeMode + " lot=" + DoubleToString(g_stage12LastHedgeLot,2));
   AddDashboardLine(row, "Last Hedge Reason: " + g_stage12LastHedgeReason);
   AddDashboardLine(row, "Mode: " + string(MQLInfoInteger(MQL_TESTER) ? "BACKTEST" : "LIVE"));
}

// ==================================================
// INTEGRATION GUIDE
// ==================================================
//
// 1) OnTick(), logo no comeÃ§o:
//      Stage13_UpdateState();
//      if(Stage13_IsEmergency())
//      {
//         string er = "";
//         if(Stage13_CanEmergencyClose(er))
//            EmergencyCloseAll("STAGE13_EMERGENCY");
//         return;
//      }
//
// 2) Dentro de BuildV4RealExecutionOrderData(), antes de definir role/lote:
//      double st13Lot = 0.0;
//      string st13Role = "";
//      string st13Reason = "";
//      if(!Stage13_EntryAuthorityGuard(st13Lot, st13Role, st13Reason))
//      {
//         reason = st13Reason;
//         return false;
//      }
//      role = st13Role;
//      lot = st13Lot;
//
// 3) Depois de execuÃ§Ã£o real bem-sucedida:
//      Stage12_MarkEntryExecuted(st13Role);
//      Stage13_AuditDecision("ORDER_EXECUTED", "Stage12", st13Reason);
//
// 4) Antes do SmartPositionScaler abrir qualquer escala:
//      string scaleReason = "";
//      if(!Stage13_ScaleAuthorityGuard(scaleReason))
//      {
//         Stage13_AuditDecision("SCALE_BLOCKED", "Stage13", scaleReason);
//         return;
//      }
//
// 5) Antes de qualquer hedge legado:
//      string hedgeReason = "";
//      if(!Stage13_HedgeAuthorityGuard(hedgeReason))
//      {
//         Stage13_AuditDecision("LEGACY_HEDGE_BLOCKED", "Stage13", hedgeReason);
//         return false;
//      }
//
// 6) Dentro de SmartHedgeResolver_HasInitialHedge():
//      if(Stage13_HasRecognizedResolvableHedge())
//         return true;
//
// 7) Dashboard:
//      if(DashboardPage == 13)
//         Stage13_UpdateWallboard();
//+------------------------------------------------------------------+

bool BuildV4RealExecutionOrderData(string &reason, double bid, double ask)
{
   double selectedScore = 0.0;
   string dirReason = "";
   ENUM_ORDER_TYPE direction = SelectAggressiveDirectionV4(selectedScore, dirReason);

   // V5.1L aggressive fix: if the V4 engine selected BUY earlier in this same
   // execution window, the real order builder must not silently fall back to SELL
   // or NONE. This directly targets the report symptom: DIRECTION_SELECTED=BUY
   // appears in Journal, but BUY IN remains zero.
   if(direction == ORDER_TYPE_BUY)
      V4ArmAggressiveBuyExecutionLatch(selectedScore, "BUILD_V4_DIRECT_SELECTED_BUY");
   else if(V4HasFreshAggressiveBuyLatch())
   {
      AuditV4("[V4_FORCE_BUY_PLAN] originalDirection=" + V4OrderTypeToPlanTextSafe(direction) +
              " forcedDirection=BUY" +
              " latchScore=" + DoubleToString(g_v4AggressiveBuyLatchScore,1) +
              " latchSource=" + g_v4AggressiveBuyLatchSource +
              " reason=BUY_SELECTED_MUST_REACH_REAL_ORDER");
      direction = ORDER_TYPE_BUY;
      selectedScore = MathMax(selectedScore, g_v4AggressiveBuyLatchScore);
      dirReason = "BUY_EXECUTION_LATCH_FORCED_REAL_PLAN";
   }

   if(direction != ORDER_TYPE_BUY && direction != ORDER_TYPE_SELL)
   {
      reason = dirReason;
      ClearDirectionState();
      AuditV4("[V4_REAL_EXECUTION] NO_TRADE_ADAPTIVE_DIRECTION selectedScore=" + DoubleToString(selectedScore,1) + " reason=" + reason);
      AuditV4("[V4_DIRECT_PLAN_DIRECTION_FINAL] direction=NEUTRAL orderType=NONE source=V4_ADAPTIVE_DIRECTION allowed=false reason=" + reason);
      AuditV4("[HORSE_EXECUTION_AUTHORITY] finalDirection=NONE orderType=NONE source=V4_ADAPTIVE_DIRECTION valid=false reason=" + reason);
      return false;
   }
   g_v4FinalDecision = BuildFinalDecisionV4(direction);
   if(!g_v4FinalDecision.allowEntry)
   {
      reason = g_v4FinalDecision.finalReason;
      return false;
   }

   if(g_pendingReverseAfterClose)
   {
      int reverseAge = (int)(TimeCurrent() - g_pendingReverseCreatedAt);
      if(V4PendingReverseExpired())
      {
         AuditV4("[V4_REVERSE_EXPIRED] pendingDirection=" + V4OrderTypeToPlanTextSafe(g_pendingReverseDirection) +
                 " ageSeconds=" + IntegerToString(reverseAge) +
                 " reason=SIGNAL_STALE_OR_TIMEOUT");
         V4ClearPendingReverse("SIGNAL_STALE_OR_TIMEOUT");
      }
      else if(!HasOpenPositionSameSymbolMagic())
      {
         if(direction == g_pendingReverseDirection)
         {
            AuditV4("[V4_REVERSE_EXECUTING] pendingDirection=" + V4OrderTypeToPlanTextSafe(g_pendingReverseDirection) +
                    " noOpenPosition=true source=REVERSE_AFTER_CLOSE");
            V4ClearPendingReverse("PENDING_DIRECTION_EXECUTING_NOW");
         }
         else
         {
            AuditV4("[V4_REVERSE_EXPIRED] pendingDirection=" + V4OrderTypeToPlanTextSafe(g_pendingReverseDirection) +
                    " ageSeconds=" + IntegerToString(reverseAge) +
                    " reason=SIGNAL_FLIPPED_TO_" + V4OrderTypeToPlanTextSafe(direction));
            V4ClearPendingReverse("SIGNAL_FLIPPED_BEFORE_REVERSE_EXECUTION");
         }
      }
   }

   if(HasOppositePositionV4(direction))
   {
      // V5.1L aggressive correction for MT5/netting behavior:
      // A BUY order sent while a SELL position is open can appear in the report only
      // as BUY OUT (closing the SELL), not BUY IN. Therefore the EA must first close
      // the opposite position and then continue building the fresh BUY/SELL plan.
      string forceCloseReason = "";
      if(V4CloseOppositePositionsForAggressiveReverse(direction, forceCloseReason))
      {
         AuditV4("[V4_FORCE_REVERSE_CONTINUE] direction=" + V4OrderTypeToPlanTextSafe(direction) +
                 " reason=" + forceCloseReason +
                 " action=CONTINUE_TO_NEW_ENTRY_PLAN");
      }
      else
      {
         V4ArmPendingReverseAfterClose(direction, V4OrderTypeToPlanTextSafe(direction) + "_SIGNAL_WHILE_OPPOSITE_POSITION_OPEN_REVERSE_AFTER_CLOSE");
         reason = "OPPOSITE_POSITION_PROTECTION_REVERSE_ARMED_FORCE_CLOSE_FAILED: " + forceCloseReason;
         AuditV4("[V4_BUY_BLOCK_FOUND] function=BuildV4RealExecutionOrderData reason=" + reason +
                 " condition=OppositePositionForceCloseFailed criticalBlock=true");
         return false;
      }
   }

   int posCount = V4CountMagicPositions();
   string role = RoleForPositionIndexV4(posCount);
   double lot = PropBaseLotV4;

   // STAGE 13 FINAL FULL: every V4 real order must pass through Stage13/Stage12 authority.
   if(UseStage13FinalAuthorityManager && Stage13_RequireStage12ForAllEntries)
   {
      double st13Lot = 0.0;
      string st13Role = "";
      string st13Reason = "";
      if(!Stage13_EntryAuthorityGuard(st13Lot, st13Role, st13Reason))
      {
         reason = NormalizeLegacyReasonV4(st13Reason);
         if(IsAbsoluteRiskBlockV4(reason))
         {
            AuditV4("[STAGE13_AUTHORITY][ABSOLUTE_BLOCK] " + reason);
            return false;
         }
         // V7: Stage13 fallback convertido em HARD BLOCK.
         // Antes o EA entrava mesmo com score abaixo de Stage12_Main_MinScore=70.
         // Isso gerava ~100% das entradas ruins (WR 29.7%). Agora bloqueia de verdade.
         AuditV4("[STAGE13_AUTHORITY][V7_HARD_BLOCK] " + reason + " â€” entry rejected, score too low");
         reason = NormalizeLegacyReasonV4(st13Reason);
         return false;
      }
      lot = st13Lot;
      role = st13Role;
      g_fix3LastOrderPlanReason = st13Reason;
      Stage13_AuditDecision("ORDER_PLAN_APPROVED", "Stage13/Stage12", st13Reason);
   }
   else
   {
      if(AggressiveProfileV4 == PROFILE_DEMO_BENCHMARK_ULTRA)
      {
         if(role == "MAIN") lot = DemoBaseLotV4;
         else if(role == "LAYER_1") lot = DemoLayerLotV4;
         else lot = DemoRunnerLotV4;
      }
      else
      {
         if(role == "MAIN") lot = PropBaseLotV4;
         else if(role == "LAYER_1") lot = PropLayerLotV4;
         else lot = PropRunnerLotV4;
      }
      lot = NormalizeLotV4(lot);
   }
   double maxExposure = (AggressiveProfileV4 == PROFILE_DEMO_BENCHMARK_ULTRA ? DemoMaxExposureLotV4 : PropMaxExposureLotV4);
   if(g_basket.totalLots + lot > maxExposure + 0.000001)
   {
      reason = "V4_MAX_EXPOSURE_ABSOLUTE_BLOCK";
      return false;
   }
   int slPoints = MainSLPointsV4;
   int tpPoints = MainTPPointsV4;
   if(role == "LAYER_1") { slPoints = LayerSLPointsV4; tpPoints = LayerTPPointsV4; }
   if(role == "RUNNER") { slPoints = RunnerSLPointsV4; tpPoints = RunnerTPPointsV4; }
   double entry = (direction == ORDER_TYPE_BUY ? ask : bid);
   double sl = 0.0, tp = 0.0;
   if(direction == ORDER_TYPE_BUY)
   {
      sl = NormalizeDouble(entry - slPoints * _Point, _Digits);
      tp = NormalizeDouble(entry + tpPoints * _Point, _Digits);
      g_realExecution.direction = REAL_EXEC_DIR_BUY;
   }
   else
   {
      sl = NormalizeDouble(entry + slPoints * _Point, _Digits);
      tp = NormalizeDouble(entry - tpPoints * _Point, _Digits);
      g_realExecution.direction = REAL_EXEC_DIR_SELL;
   }

   double dynRiskPoints = (double)slPoints;
   double dynRewardPoints = (double)tpPoints;
   Stage15_PrepareDynamicSLTP(direction, role, entry, sl, tp, dynRiskPoints, dynRewardPoints);
   slPoints = (int)MathRound(dynRiskPoints);
   tpPoints = (int)MathRound(dynRewardPoints);

   double riskMoney = PointsToMoneyV4((double)slPoints, lot);
   double rewardMoney = (Stage15_DisableFixedServerTP && UseStage15SmartDynamicExitEngine ? 0.0 : PointsToMoneyV4((double)tpPoints, lot));
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskPercent = (equity > 0.0 ? riskMoney / equity * 100.0 : 0.0);
   double rr = (slPoints > 0 && tpPoints > 0 ? (double)tpPoints / (double)slPoints : 0.0);
   g_realExecutionLot = lot;
   g_realExecutionEntryPrice = entry;
   g_realExecutionSL = sl;
   g_realExecutionTP = tp;
   g_realExecutionRiskMoney = riskMoney;
   g_realExecutionRewardMoney = rewardMoney;
   g_realExecutionRiskPercent = riskPercent;
   g_realExecutionRR = rr;
   g_realExecution.executionLot = lot;
   g_realExecution.executionEntryPrice = entry;
   g_realExecution.executionSL = sl;
   g_realExecution.executionTP = tp;
   g_realExecution.executionRiskMoney = riskMoney;
   g_realExecution.executionRewardMoney = rewardMoney;
   g_realExecution.executionRiskPercent = riskPercent;
   g_realExecution.executionRR = rr;
   g_realExecution.executionSpreadPoints = (double)GetCurrentSpreadPoints();
   g_realExecution.executionOrderType = V4OrderTypeToText(direction);
   g_realExecutionDirectionText = V4OrderTypeToText(direction);
   g_fix3LastOrderPlanReason = "V4_DIRECT_PLAN role=" + role + " score=" + DoubleToString(selectedScore,1);
   V4MarkV4PlanSync(direction);
   reason = "REAL EXECUTION ORDER DATA OK - V4_DIRECT_PLAN role=" + role + " direction=" + V4OrderTypeToText(direction) + " score=" + DoubleToString(selectedScore,1);
   AuditV4("[V4_MASTER] PRIMARY_DECISION_ENGINE_ACTIVE");
   AuditV4("[V4_DIRECT_PLAN_DIRECTION_FINAL] direction=" + V4OrderTypeToText(direction) + " orderType=" + V4OrderTypeToText(direction) + " source=V4_ADAPTIVE_DIRECTION allowed=true reason=" + reason);
   AuditV4("[HORSE_EXECUTION_AUTHORITY] finalDirection=" + V4OrderTypeToText(direction) + " orderType=" + V4OrderTypeToText(direction) + " source=V4_ADAPTIVE_DIRECTION valid=true reason=" + reason);
   if(direction == ORDER_TYPE_BUY)
      AuditV4BuyPathTrace("BUILD_V4_ORDER_DATA", "pending", "ORDER_DATA_BUILT_PENDING_REAL_EXECUTION_GATE");
   AuditV4("[V4_STALE_PLAN_FIX] action=FRESH_PLAN_BUILT direction=" + V4OrderTypeToText(direction) + " planReady=true source=V4_DIRECT_PLAN");
   AuditV4("[REAL_EXECUTION][V4] ENTRY_ALLOWED_FORWARDING_TO_ORDER_SEND " + reason);
   return true;
}

bool CanV4ExecuteRealOrder(string &reason)
{
   ENUM_ORDER_TYPE direction = V4RealDirectionToOrderType(g_realExecution.direction);
   string directionText = (direction == ORDER_TYPE_BUY ? "BUY" : (direction == ORDER_TYPE_SELL ? "SELL" : "NONE"));
   if(direction != ORDER_TYPE_BUY && direction != ORDER_TYPE_SELL)
   {
      reason = "NO_REAL_EXECUTION_DIRECTION";
      AuditV4RealExecutionGate("CAN_V4_EXECUTE", "false", reason);
      return false;
   }

   g_v4FinalDecision = BuildFinalDecisionV4(direction);
   string finalReason = g_v4FinalDecision.finalReason;
   if(!ValidateFinalReasonBeforeExecutionV4(finalReason, g_v4FinalDecision.allowEntry, g_v4FinalDecision.absoluteBlock))
   {
      g_v4FinalDecision.allowEntry = false;
      g_v4FinalDecision.absoluteBlock = false;
   }
   g_v4FinalDecision.finalReason = finalReason;

   if(!g_v4FinalDecision.allowEntry && IsForbiddenLegacyFinalReasonV4(g_v4FinalDecision.finalReason) && !IsEntryQualityFinalBlockV4(g_v4FinalDecision.finalReason))
   {
      AuditV4("[WARNING] LEGACY_FILTER_REACHED_REAL_EXECUTION -> PENALTY_ONLY reason=" + NormalizeLegacyReasonV4(g_v4FinalDecision.finalReason));
      g_v4FinalDecision.allowEntry = true;
      g_v4FinalDecision.absoluteBlock = false;
      g_v4FinalDecision.finalReason = "V4_ENTRY_ALLOWED_LEGACY_PENALTY_ONLY";
   }

   if(!g_v4FinalDecision.allowEntry)
   {
      reason = g_v4FinalDecision.finalReason;
      AuditV4("[REAL_EXECUTION][V4] ENTRY_WARNING_FINAL reason=" + reason);
      AuditV4RealExecutionGate("CAN_V4_EXECUTE", "false", reason);
      if(direction == ORDER_TYPE_BUY)
      {
         AuditV4BuyPathTrace("CAN_V4_EXECUTE", "false", reason);
         AuditV4("[V4_BUY_BLOCK_FOUND] function=CanV4ExecuteRealOrder reason=" + reason + " condition=BuildFinalDecisionV4 staleState=false correctionApplied=false");
      }
      return false;
   }

   string r = "";
   if(!IsRealExecutionDirectionAllowed(r))
   {
      reason = NormalizeLegacyReasonV4(r);
      AuditV4RealExecutionGate("DIRECTION_ALLOWED", "false", reason);
      if(direction == ORDER_TYPE_BUY)
      {
         AuditV4BuyPathTrace("DIRECTION_ALLOWED", "false", reason);
         AuditV4("[V4_BUY_BLOCK_FOUND] function=IsRealExecutionDirectionAllowed reason=" + reason + " condition=DirectionNotAllowed staleState=false correctionApplied=false");
      }
      return false;
   }

   if(!IsRealExecutionDuplicateSafe(r))
   {
      reason = NormalizeLegacyReasonV4(r);
      AuditV4RealExecutionGate("DUPLICATE_SAFE", "false", reason);
      if(direction == ORDER_TYPE_BUY)
      {
         string staleState = "false";
         if(V4DryRunDirectionTextSafe() == "SELL" || g_entryDecisionDirection == "SELL" || g_entryBaseDirection == "SELL")
            staleState = "true";
         AuditV4BuyPathTrace("DUPLICATE_SAFE", "false", reason);
         AuditV4("[V4_BUY_BLOCK_FOUND] function=IsRealExecutionDuplicateSafe reason=" + reason + " condition=Duplicate/Opposite/Cooldown/SameCandle staleState=" + staleState + " correctionApplied=false");
      }
      return false;
   }

   if(!IsRealExecutionEnvironmentSafe(r))
   {
      reason = NormalizeLegacyReasonV4(r);
      AuditV4RealExecutionGate("ENVIRONMENT_SAFE", "false", reason);
      if(direction == ORDER_TYPE_BUY)
      {
         AuditV4BuyPathTrace("ENVIRONMENT_SAFE", "false", reason);
         AuditV4("[V4_BUY_BLOCK_FOUND] function=IsRealExecutionEnvironmentSafe reason=" + reason + " condition=EnvironmentUnsafe staleState=false correctionApplied=false");
      }
      return false;
   }

   if(!IsRealExecutionBrokerSafe(r))
   {
      reason = NormalizeLegacyReasonV4(r);
      AuditV4RealExecutionGate("BROKER_SAFE", "false", reason);
      if(direction == ORDER_TYPE_BUY)
      {
         AuditV4BuyPathTrace("BROKER_SAFE", "false", reason);
         AuditV4("[V4_BUY_BLOCK_FOUND] function=IsRealExecutionBrokerSafe reason=" + reason + " condition=BrokerUnsafe staleState=false correctionApplied=false");
      }
      return false;
   }

   reason = "V4_ENTRY_ALLOWED";
   AuditV4RealExecutionGate("CAN_V4_EXECUTE", "true", reason);
   if(direction == ORDER_TYPE_BUY)
   {
      AuditV4BuyPathTrace("CAN_V4_EXECUTE", "true", reason);
      AuditV4("[V4_BUY_ORDER_READY] direction=BUY orderType=ORDER_TYPE_BUY lot=" + DoubleToString(g_realExecutionLot,2) +
              " sl=" + DoubleToString(g_realExecutionSL,_Digits) +
              " tp=" + DoubleToString(g_realExecutionTP,_Digits) +
              " readyForTradeBuy=true");
   }
   AuditV4("[REAL_EXECUTION][V4] ENTRY_ALLOWED_FORWARDING_TO_ORDER_SEND");
   return true;
}

void UpdateV4Engine()
{
   if(!UseV4AsPrimaryDecisionEngine) return;
   AuditV4("[V4_MASTER] PRIMARY_DECISION_ENGINE_ACTIVE");
   SyncTicketRolesV4();
   RemoveClosedTicketPeakV4();
   RemoveClosedTicketExitStatesV4();
   ResetTicketCloseFlagsV4();
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      string v10LoopReject = "";
      if(!V10_ShouldAcceptPosition(ticket, i, v10LoopReject)) continue;
      UpdateTicketPeakProfitV4(ticket);
      UpdateTicketExitStateV4(ticket);
   }
   UpdateV4LossStreakControl();
   UpdateAggressiveResultEngineV4();
   UpdateSmartProfitPotentialExitV4();
   ManageMainPositionV4();
   ManageLayerPositionV4();
   ManageRunnerPositionV4();
   double score=0.0; string rs=""; ENUM_ORDER_TYPE dir = SelectAggressiveDirectionV4(score, rs);
   if(dir == ORDER_TYPE_BUY)
      V4ArmAggressiveBuyExecutionLatch(score, "UPDATE_V4_ENGINE_DIRECTION_SELECTED_BUY");
   g_v4FinalDecision = BuildFinalDecisionV4(dir);
}

void UpdateDashboardPage9()
{
   int row = 0;
   AddDashboardLine(row, "HORSE EA V4 AGGRESSIVE RESULT ENGINE FINAL");
   AddDashboardLine(row, "Stage: V4 FINAL | DASH PAGE 9/9");
   AddDashboardLine(row, "V4 Primary Decision Active: " + BoolToText(UseV4AsPrimaryDecisionEngine));
   AddDashboardLine(row, "Legacy Filter Override Active: TRUE");
   AddDashboardLine(row, "V4 Final Allow Entry: " + BoolToText(g_v4FinalDecision.allowEntry));
   AddDashboardLine(row, "V4 Final Reason: " + g_v4FinalDecision.finalReason);
   AddDashboardLine(row, "Profile: " + (AggressiveProfileV4 == PROFILE_DEMO_BENCHMARK_ULTRA ? "DEMO_BENCHMARK_ULTRA" : "PROP_AGGRESSIVE_SAFE"));
   AddDashboardLine(row, "Entry Score: " + DoubleToString(g_v4LastEntryScore,1));
   AddDashboardLine(row, "Buy Score: " + DoubleToString(g_v4LastBuyScore,1));
   AddDashboardLine(row, "Sell Score: " + DoubleToString(g_v4LastSellScore,1));
   AddDashboardLine(row, "Profit Potential Score: " + DoubleToString(g_v4LastPotentialScore,1));
   AddDashboardLine(row, "Legacy Reason: " + g_v4LastLegacyReason);
   AddDashboardLine(row, "Legacy Action: " + g_v4LastLegacyAction);
   AddDashboardLine(row, "Last Exit Reason: " + g_v4LastExitReason);
   AddDashboardLine(row, "Last Result Class: " + g_v4LastResultClass);
   AddDashboardLine(row, "Open Positions: " + IntegerToString(V4CountMagicPositions()) + " / " + IntegerToString(MaxPositionsV4));
   AddDashboardLine(row, "Small Wins: " + IntegerToString(g_v4SmallWinCount));
   AddDashboardLine(row, "Medium Wins: " + IntegerToString(g_v4MediumWinCount));
   AddDashboardLine(row, "Big Wins: " + IntegerToString(g_v4BigWinCount));
   AddDashboardLine(row, "Runner Wins: " + IntegerToString(g_v4RunnerWinCount));
   AddDashboardLine(row, "Small Losses: " + IntegerToString(g_v4SmallLossCount));
   AddDashboardLine(row, "Controlled Losses: " + IntegerToString(g_v4ControlledLossCount));
   AddDashboardLine(row, "Emergency Losses: " + IntegerToString(g_v4EmergencyLossCount));
   AddDashboardLine(row, "Loss Streak: " + IntegerToString(CountCurrentLossStreakV32()));
   AddDashboardLine(row, "Real Execution V4: " + g_realExecutionStatus);
}


// ==================================================
// FIX2 #53 - Expected History / Strategy Tester Result Profile
// Behavioral target only: frequent small/medium wins, controlled losses,
// occasional runners, progressive equity curve, no martingale, no continuous
// hedge, no artificial exposure increase, no forced entries and no report
// manipulation. Protection of the account has priority over profit appearance.
// ==================================================

//+------------------------------------------------------------------+
//| Expert lifecycle                                                 |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber((ulong)MagicNumber);

   InitializeCoreData();
   InitializeATRHandles();
   InitializeVirtualEntryData();
   InitializePreExecutionData();
   InitializeExecutionDryRunData();
   InitializeRealExecutionData();
   InitializePositionManagerData();
   InitializeReentryLayerData();

   g_symbolOK = IsAllowedSymbol();
   g_timeframeOK = IsAllowedTimeframe();
   g_environmentOK = IsTradingEnvironmentOK();

   ResetDailyStatsIfNeeded();
   UpdateSecurityFilters();
   UpdateMarketData();
   UpdateFlowData();

   if(ShowDashboard && !MQLInfoInteger(MQL_OPTIMIZATION)
      && (MQLInfoInteger(MQL_VISUAL_MODE) || !MQLInfoInteger(MQL_TESTER)))
      CreateDashboard();

   AuditLog("CORE", "EA INITIALIZED");
   AuditLog("SECURITY", "SECURITY FILTERS INITIALIZED");
   AuditLog("MARKET", "MARKET ENGINE INITIALIZED");
   AuditLog("FLOW", "FLOW ENGINE INITIALIZED");
   AuditLog("ENTRY_SCORE", "ENTRY SCORE ENGINE INITIALIZED");
   AuditLog("ENTRY_DECISION", "ENTRY DECISION ENGINE INITIALIZED");
   AuditLog("VIRTUAL_ENTRY", "VIRTUAL ENTRY ENGINE INITIALIZED");
   AuditLog("PRE_EXECUTION", "PRE EXECUTION ENGINE INITIALIZED");
   AuditLog("EXECUTION_DRY_RUN", "EXECUTION DRY RUN ENGINE INITIALIZED");
   AuditRealExecution("REAL EXECUTION ENGINE INITIALIZED");
   AuditPositionManager("POSITION MANAGER INITIALIZED");
   AuditReentryLayer("REENTRY LAYER ENGINE INITIALIZED");
   AuditLog("CORE", "Symbol=" + _Symbol);
   AuditLog("CORE", "Timeframe=" + TimeframeToText((ENUM_TIMEFRAMES)_Period));
   AuditLog("CORE", "Account=" + IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN)));
   AuditLog("CORE", "Initial Equity=" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2));
   AuditLog("CORE", "Diagnostic Mode=" + BoolToText(UseDiagnosticMode));
   AuditLog("CORE", "[V4_MASTER] PRIMARY_DECISION_ENGINE_ACTIVE=" + BoolToText(UseV4AsPrimaryDecisionEngine));
   AuditLog("CORE", "[STAGE13_FINAL_FULL] UseStage13FinalAuthorityManager=" + BoolToText(UseStage13FinalAuthorityManager));
   AuditLog("CORE", "[STAGE13_FINAL_FULL] UseStage12_InstitutionalEngine=" + BoolToText(UseStage12_InstitutionalEngine));
   AuditLog("CORE", "[V4_MASTER] UseV4DirectPlanBuilder=" + BoolToText(UseV4DirectPlanBuilder));
   AuditLog("CORE", "[V4_MASTER] MaxPositionsV4=" + IntegerToString(MaxPositionsV4));
   AuditLog("CORE", "[FIX3_V3_INPUT_SNAPSHOT] ForceFunctionalExecutionTest=" + BoolToText(ForceFunctionalExecutionTest));
   AuditLog("CORE", "[FIX3_V3_INPUT_SNAPSHOT] ForceFunctionalAggressiveEntryCycle=" + BoolToText(ForceFunctionalAggressiveEntryCycle));
   AuditLog("CORE", "[FIX3_V3_INPUT_SNAPSHOT] ForceFunctionalMaxTotalPositions=" + IntegerToString(ForceFunctionalMaxTotalPositions));
   AuditLog("CORE", "[FIX3_V3_INPUT_SNAPSHOT] ForceFunctionalFixedLot=" + DoubleToString(ForceFunctionalFixedLot, 2));
   AuditLog("CORE", "[FIX3_V3_INPUT_SNAPSHOT] ForceFunctionalMaxSymbolExposureLots=" + DoubleToString(ForceFunctionalMaxSymbolExposureLots, 2));
   AuditLog("CORE", "[FIX3_V3_INPUT_SNAPSHOT] EnableRealExecution=" + BoolToText(EnableRealExecution));
   AuditLog("CORE", "[FIX3_V3_INPUT_SNAPSHOT] RealExecutionSimulationOnly=" + BoolToText(RealExecutionSimulationOnly));
   AuditLog("CORE", "[FIX3_V3_1_AUDIT] SmartExitRealEngine injected=true");
   AuditLog("CORE", "[FIX3_V3_1_AUDIT] UseSmartExitRealEngine=" + BoolToText(UseSmartExitRealEngine));
   AuditLog("CORE", "[FIX3_V3_1_AUDIT] SmartExitSimulationOnly=" + BoolToText(SmartExitSimulationOnly));
   AuditLog("CORE", "[V4_CLOSE_TRACE] INPUT_SNAPSHOT UseSmartExitRealEngine=" + BoolToText(UseSmartExitRealEngine) + " AllowBasketSmartClose=" + BoolToText(AllowBasketSmartClose) + " BasketProfitTargetMoney=" + DoubleToString(BasketProfitTargetMoney,2) + " BasketMinProfitToProtectMoney=" + DoubleToString(BasketMinProfitToProtectMoney,2));
   AuditLog("CORE", "[V4_CLOSE_TRACE] INPUT_SNAPSHOT UseMinProfitHoldV4=" + BoolToText(UseMinProfitHoldV4) + " BlockMicroProfitCloseV4=" + BoolToText(BlockMicroProfitCloseV4) + " MinProfitToAllowPositiveCloseV4=" + DoubleToString(MinProfitToAllowPositiveCloseV4,2) + " UseEarlyCloseDiagnosticOnlyV4=" + BoolToText(UseEarlyCloseDiagnosticOnlyV4));
   AuditLog("CORE", "[FIX3_V3_1_AUDIT] PositionModify found=true");
   AuditLog("CORE", "[FIX3_V3_1_AUDIT] PositionClose found=true");
   AuditLog("CORE", "[FIX3_V3_INPUT_SNAPSHOT] MaxTotalLayers=" + IntegerToString(MaxTotalLayers));
   AuditLog("CORE", "[LAYER_CONFIG] CountMainPositionAsLayer=" + BoolToText(CountMainPositionAsLayer));
   AuditLog("CORE", "[LAYER_CONFIG] Main + Layer1 + Layer2 = Max " + IntegerToString(ForceFunctionalMaxTotalPositions) + " positions");
   AuditLog("CORE", "[DUAL_SIDE_AUDIT_V10] source=OnInit"
            + " stage12HedgeAirbag=" + BoolToText(Stage12_UseHedgeAirbag)
            + " stage13BlocksHedge=" + BoolToText(UseStage13FinalAuthorityManager)
            + " reentryLayerActive=" + BoolToText(UseReentryLayerEngine)
            + " stage12LayerActive=" + BoolToText(Stage13_RequireStage12ForAllScales)
            + " orderPath=Stage17_OpenPair_isolated"
            + " reason=Stage17 minimal patch initialized");
   AuditLog("CORE", "[DUAL_SIDE_LEGACY_AIRBAG_OFF_V10] reason=Stage17 init / Stage12_UseHedgeAirbag=" + BoolToText(Stage12_UseHedgeAirbag));

   UpdateEntryBaseData();
   UpdateEntryDecisionData();
   UpdateVirtualEntrySimulation();
   UpdatePreExecutionRiskGate();
   UpdateExecutionDryRun();
   if(UseStage17DualSideConfirmation)
   {
      AuditRealExecution("[DUAL_SIDE_LEGACY_ENTRY_BLOCKED_V10] reason=Stage17Enabled source=OnInit engine=UpdateRealExecutionEngine");
   }
   else if(!ForceFunctionalExecutionTest)
      UpdateRealExecutionEngine();
   else
      AuditRealExecution("[FIX3_V3] SKIP REAL EXECUTION ONINIT - WAITING FIRST TICK");
   UpdatePositionManager();
   UpdateReentryLayerEngine();

   if(g_symbolOK && g_timeframeOK && g_environmentOK && g_securityFiltersOK && g_market.isTradable && g_flowOK && g_entryBaseOK && g_entryDecisionOK)
      AuditLog("CORE", "EA READY - STAGE 12 REENTRY LAYER OK");

   return INIT_SUCCEEDED;
}


void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   string symbol = trans.symbol;
   ulong deal = trans.deal;
   ulong order = trans.order;
   ulong positionId = trans.position;
   long entry = -1;
   long dealType = -1;
   long magic = MagicNumber;
   double profit = 0.0;
   double price = trans.price;
   double volume = trans.volume;
   string reason = "TRANS_TYPE_" + IntegerToString((int)trans.type);

   if(trans.type == TRADE_TRANSACTION_DEAL_ADD && deal > 0 && HistoryDealSelect(deal))
   {
      symbol = HistoryDealGetString(deal, DEAL_SYMBOL);
      entry = (long)HistoryDealGetInteger(deal, DEAL_ENTRY);
      dealType = (long)HistoryDealGetInteger(deal, DEAL_TYPE);
      magic = (long)HistoryDealGetInteger(deal, DEAL_MAGIC);
      positionId = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
      profit = HistoryDealGetDouble(deal, DEAL_PROFIT);
      price = HistoryDealGetDouble(deal, DEAL_PRICE);
      volume = HistoryDealGetDouble(deal, DEAL_VOLUME);
      reason = "DEAL_ADD_" + V10_DealEntryText(entry);
   }

   AuditV4("[V10_TRADE_TRANSACTION] type=" + IntegerToString((int)trans.type)
         + " deal=" + UlongToText(deal)
         + " order=" + UlongToText(order)
         + " position=" + UlongToText(positionId)
         + " symbol=" + symbol
         + " entry=" + V10_DealEntryText(entry)
         + " dealType=" + V10_DealTypeText(dealType)
         + " magic=" + IntegerToString((int)magic)
         + " price=" + DoubleToString(price, _Digits)
         + " volume=" + DoubleToString(volume, 2)
         + " profit=" + DoubleToString(profit, 2)
         + " reason=" + reason);

   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   if(symbol != _Symbol)
      return;

   if(entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT)
   {
      ulong ticket = V10_FindOpenPositionTicketByPositionId(positionId, symbol, magic);
      if(ticket == 0)
      {
         AuditV4("[V10_POSITION_OPENED_CAPTURED] ticket=0 deal=" + UlongToText(deal)
               + " position=" + UlongToText(positionId)
               + " symbol=" + symbol
               + " magic=" + IntegerToString((int)magic)
               + " type=" + V10_DealTypeText(dealType)
               + " price=" + DoubleToString(price, _Digits)
               + " volume=" + DoubleToString(volume, 2)
               + " source=ON_TRADE_TRANSACTION result=FAILED_RESOLVE_OPEN_POSITION");
      }
      else
      {
         V10_RegisterPositionOpened(ticket, deal, positionId, "ON_TRADE_TRANSACTION");
         V10_ManageTicketNow(ticket, "ON_TRADE_TRANSACTION_ENTRY_IN");
      }
   }

   if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY || entry == DEAL_ENTRY_INOUT)
   {
      int idx = V10_FindTicketStateByPositionOrTicket(positionId, positionId);
      string cls = "UNKNOWN";
      double mfe = 0.0;
      double mae = 0.0;
      if(idx >= 0)
      {
         cls = g_v4TicketExitStates[idx].liveExitClass;
         mfe = g_v4TicketExitStates[idx].profitPeakMoney;
         mae = g_v4TicketExitStates[idx].maxAdverseMoney;
      }

      AuditV4("[V10_POSITION_CLOSED] ticket=" + UlongToText(positionId)
            + " deal=" + UlongToText(deal)
            + " profit=" + DoubleToString(profit, 2)
            + " class=" + cls
            + " mfe=" + DoubleToString(mfe, 2)
            + " mae=" + DoubleToString(mae, 2)
            + " reason=" + reason);
   }
}

void OnDeinit(const int reason)
{
   PrintV4ExitReport();
   ReleaseATRHandles();
   DeleteDashboard();
   AuditLog("CORE", "EA DEINITIALIZED | Reason=" + IntegerToString(reason));
}

void OnTick()
{
   g_lastTickTime = TimeCurrent();
   g_stage17LegacyBlockThisTick = false;

   ResetDailyStatsIfNeeded();

   g_symbolOK = IsAllowedSymbol();
   g_timeframeOK = IsAllowedTimeframe();
   g_environmentOK = IsTradingEnvironmentOK();

   UpdateSecurityFilters();
   UpdateMarketData();
   UpdateFlowData();
   UpdateBasketData();
   UpdateRiskData();
   Stage12_HedgeAirbagOnTick();
   Stage13_UpdateState();
   Stage17_DualSideOnTick();
   UpdateAggressiveCycleRearm();

   // Entry score, entry decision and virtual entry diagnostics must update before blocking returns.
   UpdateEntryBaseData();
   UpdateEntryDecisionData();
   UpdateVirtualEntrySimulation();
   UpdatePreExecutionRiskGate();
   UpdateExecutionDryRun();
   UpdateV32Diagnostics();
   UpdateV4Engine();
   if(UseStage17DualSideConfirmation)
   {
      if(Stage17_DebugLogs)
         Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_LEGACY_ENTRY_BLOCKED_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
               " reason=Stage17Enabled source=OnTick engine=UpdateRealExecutionEngine");
   }
   else if(g_stage17LegacyBlockThisTick)
   {
      if(Stage17_DebugLogs)
         Print("[HORSE EA][STAGE17_DUAL_SIDE] [DUAL_SIDE_LEGACY_ENGINE_BLOCKED_V10] pairId=", IntegerToString((int)g_stage17Pair.pairId),
               " engine=UpdateRealExecutionEngine reason=STAGE17_PAIR_ACTIVE_OR_OPENING");
   }
   else
      UpdateRealExecutionEngine();

   // V10 FLOW INTEGRATION: gerencia/protege/classifica tickets ANTES dos motores antigos de fechamento.
   Stage15_OnTick();
   Stage17_DualSideOnTick();

   UpdatePositionManager();
   UpdateReentryLayerEngine();
   UpdateSmartExitRealEngine();

   // Segunda passagem leve: prova no log que a V10 continua conectada apos os motores legados.
   Stage15_OnTick();
   UpdateV32PositionManagement();
   // Terceira passagem: captura tickets criados/alterados pelo motor V3.2 antes do fim do tick.
   Stage15_OnTick();

   if(!g_symbolOK || !g_timeframeOK || !g_environmentOK)
   {
      g_eaStatus = "BLOCKED - CORE FILTER";
      UpdateDashboard();
      return;
   }

   if(!g_securityFiltersOK)
   {
      g_eaStatus = "BLOCKED - SECURITY FILTER";
      UpdateDashboard();
      return;
   }

   string marketReason = "";
   bool marketOK = IsMarketTradableByVolatility(marketReason);

   if(!marketOK)
   {
      g_eaStatus = "BLOCKED - MARKET FILTER";
      g_marketDiagnosticReason = marketReason;
      g_market.reason = marketReason;
      g_market.isTradable = false;
      UpdateDashboard();
      return;
   }

   string flowReason = "";
   bool flowOK = IsFlowTradable(flowReason);

   if(!flowOK)
   {
      g_eaStatus = "BLOCKED - FLOW FILTER";
      g_flowDiagnosticReason = flowReason;
      g_flowReason = flowReason;
      g_flowOK = false;
      UpdateDashboard();
      return;
   }

   string entryReason = "";
   bool entryOK = IsEntryBaseTradable(entryReason);

   if(!entryOK && !EntryBaseDiagnosticOnly)
   {
      g_eaStatus = "BLOCKED - ENTRY SCORE";
      g_entryDiagnosticReason = entryReason;
      g_entryBaseReason = entryReason;
      UpdateDashboard();
      return;
   }

   string decisionReason = "";
   bool decisionOK = IsEntryDecisionTradable(decisionReason);

   if(!decisionOK && !EntryDecisionDiagnosticOnly)
   {
      g_eaStatus = "BLOCKED - ENTRY DECISION";
      g_entryDecisionDiagnosticReason = decisionReason;
      UpdateDashboard();
      return;
   }

   string preReason = "";
   bool preOK = IsPreExecutionTradable(preReason);

   if(!preOK && !PreExecutionDiagnosticOnly)
   {
      g_eaStatus = "BLOCKED - PRE EXECUTION";
      g_preExecutionReason = preReason;
      UpdateDashboard();
      return;
   }

   string dryReason = "";
   bool dryOK = IsExecutionDryRunTradable(dryReason);

   if(!dryOK && !ExecutionDryRunDiagnosticOnly)
   {
      g_eaStatus = "BLOCKED - EXECUTION DRY RUN";
      g_dryRunReason = dryReason;
      UpdateDashboard();
      return;
   }

   if(!g_mqlTradeAllowed || !g_accountTradeAllowed || !g_liveTradingAllowed)
      g_eaStatus = "READY - STAGE 12 DIAGNOSTIC WARNING";
   else
      g_eaStatus = "READY - STAGE 12 REENTRY LAYER OK";

   g_lastAction = "WAITING STAGE 12 REENTRY LAYER ENGINE";
   AuditLog("CORE", "EA READY - STAGE 12 REENTRY LAYER OK");

   UpdateDashboard();
}

//+------------------------------------------------------------------+


