#property strict
#property version   "1.00"
#property description "IA FUNDED GOLD V1 - Expert Advisor autoral para MT5 hedge."
// TACTICAL_PRECISION_FINAL_FIX 2026-07-17: patch restrito ao motor tatico; sem lote, risco ou gestao.

#include <Trade/Trade.mqh>

CTrade trade;

enum ENUM_STRUCTURAL_FLOW_STATE
{
   STRUCTURAL_STRONG_SELL   = -2,
   STRUCTURAL_MODERATE_SELL = -1,
   STRUCTURAL_NEUTRAL       = 0,
   STRUCTURAL_MODERATE_BUY  = 1,
   STRUCTURAL_STRONG_BUY    = 2
};

enum ENUM_TACTICAL_FLOW_STATE
{
   TACTICAL_NONE = 0,
   TACTICAL_BUY  = 1,
   TACTICAL_SELL = -1
};

enum ENUM_TACTICAL_EPISODE_STATE
{
   TACTICAL_STATE_NONE = 0,
   TACTICAL_STATE_CANDIDATE = 1,
   TACTICAL_STATE_ACTIVE = 2,
   TACTICAL_STATE_ORDER_PENDING = 3,
   TACTICAL_STATE_CONSUMED = 4
};

enum ENUM_MFE_POSITION_STATE
{
   MFE_UNTRACKED = 0,
   MFE_TRACKING = 1,
   MFE_ARMED = 2,
   MFE_MODIFY_PENDING = 3,
   MFE_PROTECTED = 4,
   MFE_CLOSED = 5
};

enum ENUM_MFE_SL_SOURCE
{
   MFE_SL_SOURCE_NONE = 0,
   MFE_SL_SOURCE_BREAK_EVEN = 1,
   MFE_SL_SOURCE_LEGACY_TRAILING = 2,
   MFE_SL_SOURCE_ADAPTIVE_MFE = 3
};

struct MFEPositionState
{
   bool used;
   long identifier;
   ulong ticket;
   ENUM_POSITION_TYPE type;
   double volume;
   double open_price;
   datetime open_time;
   double entry_commission;
   double exit_commission_per_lot;
   double estimated_exit_commission;
   int cost_source;
   bool cost_refresh_attempted;
   double current_net_profit;
   double net_mfe;
   double desired_net_lock;
   double effective_net_lock;
   double confirmed_net_lock;
   double last_confirmed_sl;
   ENUM_MFE_POSITION_STATE state;
   int stage;
   int last_step;
   int last_logged_high_quantum;
   double requested_sl;
   double requested_effective_lock;
   datetime request_time;
   ENUM_MFE_SL_SOURCE request_source;
   ENUM_MFE_SL_SOURCE last_confirmed_source;
   bool pending;
   datetime backoff_until;
   ulong last_request_cycle;
   int modification_count;
   int failure_count;
   double last_conversion_failure_lock;
   double realized_exit_components;
   ulong last_exit_deal;
   int last_exit_reason;
   double last_exit_price;
};

input group "=== GERAL ==="
input double FixedLot = 0.01; // Lote fixo
input long MagicNumber = 20260710; // Numero magico
input int SlippagePoints = 30; // Slippage em pontos
input bool AllowTrading = true; // Permitir operacoes
input bool EnableLogs = true; // Ativar logs detalhados
input bool UsePanel = true; // Mostrar painel no grafico

input group "=== MODO ALWAYS IN MARKET ==="
input bool AlwaysInMarket = true; // Operar sempre no mercado
input bool OpenPairImmediatelyAfterBasketClose = true; // Abrir novo par apos fechar cesta
input int ReopenDelaySecondsAfterClose = 5; // Segundos para reabrir apos fechar cesta

input group "=== ENTRADAS ADICIONAIS ==="
input bool OpenAdditionalPairsWhileBasketActive = true; // Abrir novos pares com cesta ativa
input bool OpenAdditionalPairsUntilMaxPositions = true; // Abrir pares ate atingir maximo de operacoes
input int MinSecondsBetweenAdditionalPairs = 120; // Tempo minimo entre pares adicionais
input bool RequireDistanceForAdditionalPairs = true; // Exigir distancia para pares adicionais
input bool StopAddingPairsWhenBasketPositive = false; // Parar novos pares se cesta estiver positiva

input group "=== OPERACIONAL BUY SELL ==="
input bool Allow_BUY = true; // Permitir compras
input bool Allow_SELL = true; // Permitir vendas
input bool EA_makes_first_order = true; // EA abre primeira ordem
input bool Open_order_on_trend = true; // Considerar tendencia para gerenciamento

input group "=== LIMITES DE OPERACOES ==="
input int MaxPairs = 4; // Maximo de pares BUY SELL
input int MaxOpenPositions = 8; // Maximo de operacoes abertas
input int MaxBuyPositions = 4; // Maximo de compras abertas
input int MaxSellPositions = 4; // Maximo de vendas abertas

input group "=== DISTANCIAMENTO DE ORDENS ==="
input int First_step = 600; // Primeiro passo em pontos
input int Minimum_price_distance = 800; // Distancia minima de preco
input int Move_step = 300; // Passo de movimentacao
input int Distance_between_orders = 1200; // Distancia entre ordens

input group "=== FECHAMENTO DA CESTA ==="
input double Profit_for_closing_2_directions = 25.0; // Lucro para fechar cesta BUY SELL em USD
input double Profit_for_closing_1_direction = 50.0; // Lucro para fechar uma direcao em USD
input bool Auto_calculated_profit = false; // Calculo automatico de lucro
input bool UseBasketProfitClose = true; // Usar fechamento por lucro da cesta

input group "=== PROTECAO DE LUCRO DA CESTA ==="
input bool UsarProtecaoLucroCesta = true; // Usar protecao por pico de lucro da cesta
input double PicoMinimoLucroCestaUSD = 15.0; // Pico minimo da cesta para ativar protecao
input double LucroProtegidoAposPicoUSD = 7.0; // Lucro minimo protegido apos pico
input double FechamentoFortePicoCestaUSD = 30.0; // Fechamento forte por pico da cesta

input group "=== FECHAMENTO POR PRECO MEDIO ==="
input bool UsePriceBasedBasketClose = true; // Usar fechamento por preco medio da cesta
input double BasketProfitUSD_MinConfirm = 5.0; // Lucro minimo para fechar por linha dinamica
input int BasketCloseDistancePoints = 300; // Distancia da linha de fechamento
input bool DrawBasketPriceLines = true; // Desenhar linhas da cesta no grafico

input group "=== BREAKEVEN RAPIDO ==="
input bool UseBreakEven = true; // Usar breakeven
input double BreakEvenStartUSD = 6.0; // Iniciar breakeven com lucro em USD
input double BreakEvenLockUSD = 1.0; // Lucro protegido no breakeven

input group "=== TRAILING INTELIGENTE ==="
input bool UseSmartTrailing = true; // Usar trailing inteligente
input int Trailing_type = 1; // Tipo de trailing
input double Minimum_trailing_profit = 8.0; // Lucro minimo para iniciar trailing
input double Trailing_stop = 5.0; // Distancia do trailing em USD
input double Trailing_step = 1.0; // Passo minimo do trailing em USD
input int Padding_by_fractals_or_candles = 150; // Folga por candles ou fractais
input ENUM_TIMEFRAMES Timeframe_fractals_or_candles = PERIOD_M15; // Timeframe do trailing

input group "=== TRAILING MFE MONETARIO ADAPTATIVO ==="
input bool EnableAdaptiveMoneyMFE = true; // Ativar protecao MFE individual tick a tick
input double MFEActivationNetMoney = 2.00; // MFE liquido para armar a protecao
input double MFEInitialProtectedNetMoney = 1.00; // Lock liquido no primeiro gatilho
input double MFETriggerStepNetMoney = 2.00; // Avanco de MFE por degrau
input double MFEProtectStepNetMoney = 1.00; // Avanco de lock por degrau
input double MFEStage2StartNetMoney = 6.00; // Inicio da retencao de 60 por cento
input double MFEStage2RetentionRatio = 0.60; // Retencao do estagio 2
input double MFEStage3StartNetMoney = 12.00; // Inicio da retencao de 70 por cento
input double MFEStage3RetentionRatio = 0.70; // Retencao do estagio 3
input double MFEStage4StartNetMoney = 25.00; // Inicio da retencao de 80 por cento
input double MFEStage4RetentionRatio = 0.80; // Retencao do estagio 4
input double MFEProtectionQuantumNetMoney = 0.25; // Quantum monetario da protecao
input double MFEMinimumGivebackNetMoney = 0.50; // Recuo minimo preservado abaixo do MFE
input double MFEMoneyConversionTolerance = 0.05; // Tolerancia da conversao dinheiro-preco
input double MFEEstimatedClosingCommissionPerLot = 3.50; // Fallback conservador por lote e lado
input bool MFEPersistState = true; // Persistir estado individual por identifier
input bool MFELogStateChanges = true; // Registrar somente transicoes relevantes

input group "=== ORDENS PENDENTES DINAMICAS ==="
input bool UseDynamicPendingOrders = true; // Usar ordens pendentes dinamicas
input int MaxPendingOrders = 2; // Maximo de pendentes totais
input int MaxPendingBuyOrders = 1; // Maximo de pendentes BUY
input int MaxPendingSellOrders = 1; // Maximo de pendentes SELL
input int PendingOrderDistancePoints = 600; // Distancia da ordem pendente
input int PendingOrderExpirationMinutes = 30; // Expiracao da pendente em minutos
input int PendingRepositionStepPoints = 300; // Reposicionar pendente apos distancia
input bool PendingOrdersCountAsRisk = true; // Pendentes contam no limite de risco

input group "=== ANTI HIPERATIVIDADE ==="
input bool UseAntiOvertradeFilter = true; // Usar filtro anti hiperatividade
input bool OnePairPerCandle = true; // Apenas um par por candle
input int MinSecondsBetweenPairs = 120; // Tempo minimo entre pares em segundos
input bool BlockNewPairNearBasketTarget = false; // Bloquear novo par perto do alvo da cesta
input double BasketTargetProximityUSD = 5.0; // Proximidade do alvo para bloquear novo par

input group "=== PROTECAO FTMO ==="
input double MaxDailyLossUSD = 700.0; // Limite de perda diaria em USD
input bool StopTradingAfterDailyLoss = true; // Parar novas entradas apos loss diario
input bool ClosePositionsAtDailyLoss = false; // Fechar posicoes ao atingir loss diario
input double Maximum_allowed_loss = 600.0; // Perda maxima da cesta em USD
input bool Close_loss_by_drawdown = false; // Fechar cesta ao atingir DD maximo
input double Loss_for_closing = 600.0; // Loss para fechamento da cesta

input group "=== META DIARIA ==="
input double DailyProfitTargetUSD = 200.0; // Meta diaria em USD
input bool StopTradingAfterDailyProfit = false; // Parar novas entradas apos meta diaria

input group "=== FILTROS DE SEGURANCA ==="
input bool UseSpreadFilter = true; // Usar filtro de spread
input int MaxSpreadPoints = 60; // Spread maximo em pontos
input bool UseTimeFilter = false; // Usar filtro de horario
input int StartHour = 0; // Hora inicial
input int EndHour = 23; // Hora final

input group "=== PRICE ACTION E FLUXO DE VOLUME ==="
input bool UsePriceActionFilter = true; // Usar leitura de Price Action
input int PriceActionLookbackBars = 10; // Candles para analisar Price Action
input double StrongCandleBodyRatio = 0.55; // Forca minima do corpo do candle
input bool UseNativeVolumeFlow = true; // Usar fluxo de volume nativo
input int VolumeLookbackBars = 20; // Candles para media de volume
input double VolumeFlowMinStrength = 1.20; // Forca minima do volume

input group "=== MOTOR BILATERAL ASSIMETRICO ==="
input bool UseAsymmetricBilateralFlowEngine = true;
input ENUM_TIMEFRAMES StructuralFlowTimeframe = PERIOD_M5;
input ENUM_TIMEFRAMES TacticalFlowTimeframe = PERIOD_M5;
input bool UseTacticalCorrectionEntries = true;
input int StructuralStrongConfirmationBars = 2;
input double TacticalMinimumBodyRatio = 0.45;
input double TacticalMinimumVolumeStrength = 1.00;

input group "=== FILTRO DE NOTICIAS V2 ==="
input bool UseNewsFilter = false; // Reservado para filtro de noticias na V2
input bool BlockMediumImpactNews = true; // Bloquear noticias de medio impacto na V2
input bool BlockHighImpactNews = true; // Bloquear noticias de alto impacto na V2
input int MinutesBeforeNewsToStop = 20; // Minutos antes da noticia para parar novas entradas
input int MinutesAfterNewsToResume = 20; // Minutos depois da noticia para voltar

#define EA_NAME "IA FUNDED GOLD"
#define LINE_AVG_BUY "IA_FG_AVG_BUY"
#define LINE_AVG_SELL "IA_FG_AVG_SELL"
#define LINE_AVG_BASKET "IA_FG_AVG_BASKET"
#define LINE_CLOSE_TARGET "IA_FG_CLOSE_TARGET"
#define LINE_PROFIT_ZONE "IA_FG_PROFIT_ZONE"

const int MAINTENANCE_TIMER_SECONDS = 1;
const int STALE_TICK_SECONDS = 60;
const int TACTICAL_MAX_PROGRESSIVE_ENTRIES = 1;
const int TACTICAL_ATR_LOOKBACK_BARS = 14;
const int TACTICAL_ANCHOR_LOOKBACK_BARS = 6;
const double TACTICAL_MIN_ENTRY_ATR_RATIO = 0.18;
const double TACTICAL_MAX_ENTRY_ATR_RATIO = 0.90;
const double TACTICAL_MAX_CONFIRMATION_CANDLE_ATR = 0.85;
const int TACTICAL_NEUTRAL_END_BARS = 2;
const int TACTICAL_MAX_EPISODE_BARS = 6;
const int TACTICAL_ORDER_PENDING_TIMEOUT_SECONDS = 30;
#define MFE_MAX_TRACKED_POSITIONS 16
const int MFE_STATE_SCHEMA_VERSION = 1;
const int MFE_PRICE_SEARCH_ITERATIONS = 48;
const int MFE_MODIFY_TIMEOUT_SECONDS = 15;
const int MFE_MODIFY_BACKOFF_SECONDS = 5;
const int MFE_COMMISSION_LOOKBACK_DAYS = 90;
const double MFE_STAGE1_RETENTION_RATIO = 0.50;

MqlTick g_tick;
datetime g_currentDayStart = 0;
datetime g_lastServerTime = 0;
datetime g_lastRealTickTime = 0;
datetime g_lastPairOpenTime = 0;
datetime g_lastBasketCloseTime = 0;
datetime g_lastPairCandleTime = 0;
double g_lastPairMidPrice = 0.0;
double g_dailyResult = 0.0;
bool g_dailyLossBlocked = false;
bool g_dailyProfitBlocked = false;
bool g_basketDDBlocked = false;
bool g_nettingWarningShown = false;
string g_status = "OPERANDO";
string g_lastLogMessage = "";
datetime g_lastLogTime = 0;
int g_lastTickAgeSeconds = -1;
string g_symbolSessionState = "AGUARDANDO PRIMEIRO TICK";
bool g_terminalConnected = false;
bool g_symbolTradingEnabled = true;
bool g_operationalBusy = false;
bool g_timerBusy = false;
bool g_dailyStateBusy = false;
bool g_waitingFirstTickAfterReopen = true;
double g_PicoLucroCestaUSD = 0.0;
bool g_FechamentoMFECestaEmAndamento = false;
ENUM_STRUCTURAL_FLOW_STATE g_structuralStableFlow = STRUCTURAL_NEUTRAL;
int g_structuralCandidateDirection = 0;
int g_structuralConsecutiveConfirmations = 0;
datetime g_lastStructuralClosedBar = 0;
ENUM_TACTICAL_FLOW_STATE g_tacticalEpisode = TACTICAL_NONE;
ENUM_TACTICAL_EPISODE_STATE g_tacticalState = TACTICAL_STATE_NONE;
bool g_tacticalEntryExecuted = false;
int g_tacticalEntryCount = 0;
int g_tacticalConsecutiveConfirmations = 0;
bool g_tacticalAwaitingPostRebuildClosedBar = false;
datetime g_tacticalEpisodeStartBar = 0;
datetime g_lastTacticalClosedBar = 0;
int g_tacticalEpisodeStructuralDirection = 0;
double g_tacticalAnchorPrice = 0.0;
datetime g_tacticalAnchorBar = 0;
int g_tacticalAnchorStructuralDirection = 0;
int g_tacticalAnchorSourceShift = 0;
datetime g_tacticalActivatedClosedBar = 0;
datetime g_tacticalEntryAuthorizedClosedBar = 0;
datetime g_blockOppositeStructuralPromotionBar = 0;
datetime g_tacticalLastEndBar = 0;
int g_tacticalNeutralClosedBars = 0;
int g_tacticalEpisodeClosedBars = 0;
ulong g_tacticalPendingOrder = 0;
ulong g_tacticalPendingDeal = 0;
datetime g_tacticalOrderRequestTime = 0;
datetime g_tacticalOrderRequestBar = 0;
ENUM_ORDER_TYPE g_tacticalPendingOrderType = ORDER_TYPE_BUY;
string g_tacticalPendingComment = "";
double g_tacticalPendingVolume = 0.0;
ulong g_tacticalConfirmedPosition = 0;
ulong g_tacticalConfirmedDeal = 0;
datetime g_tacticalConsumedBlockLoggedBar = 0;
bool g_adaptiveBasketWasActive = false;
bool g_adaptiveEntryAttemptedThisTick = false;
bool g_adaptivePendingSuspensionLogged = false;
string g_adaptiveLastAction = "AGUARDANDO";
string g_adaptiveBlockReason = "SEM CONFIRMACAO";
string g_lastAdaptiveBlockLogKey = "";
string g_lastTacticalEntryBlockLogKey = "";
string g_lastTacticalFlowTraceAfterUpdateKey = "";
string g_lastTacticalFlowTraceBeforeManageKey = "";
string g_lastTacticalFlowTraceBeforeOpenKey = "";
string g_lastTacticalFlowTraceAfterOpenKey = "";
string g_lastTacticalFlowTraceOtherKey = "";
MFEPositionState g_mfePositions[MFE_MAX_TRACKED_POSITIONS];
ulong g_mfeManagementCycle = 0;
bool g_mfeSkipSubmissionAfterRebuild = false;
double g_mfeObservedClosingCommissionPerLot = 0.0;
bool g_mfeObservedCommissionInitialized = false;

int OnInit();
void OnDeinit(const int reason);
void OnTick();
void OnTimer();
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result);

bool IsHedgingAccount();
bool IsSpreadOK();
bool IsTradingHourOK();
bool IsNewsBlocked();

int DetectPriceActionBias();
int DetectNativeVolumeFlow();

int DetectClosedPriceActionSignal(ENUM_TIMEFRAMES timeframe, int shift);
int DetectClosedVolumeSignal(ENUM_TIMEFRAMES timeframe, int shift, double &volume_strength);
double GetClosedCandleBodyRatio(ENUM_TIMEFRAMES timeframe, int shift);
int DetectClosedTacticalSignal(ENUM_TIMEFRAMES timeframe, int shift);
double GetClosedAtrPoints(ENUM_TIMEFRAMES timeframe, int shift, int lookback);
void ResetTacticalAnchor();
void LogTacticalAnchor(string action, int structural_direction);
bool EnsureTacticalAnchor(int structural_direction, ENUM_TIMEFRAMES timeframe, int shift);
void RefreshTacticalAnchor(int structural_direction, ENUM_TIMEFRAMES timeframe, int shift);
int DetectClosedTacticalCorrectionSignal(ENUM_TIMEFRAMES timeframe, int shift, int structural_direction, double &body_ratio, double &displacement_points, double &atr_points, int &price_action, int &volume_signal, string &reason);
bool GetClosedStructuralSignal(ENUM_TIMEFRAMES timeframe, int shift, int &raw_signal, double &body_ratio, double &volume_strength);
void ApplyStructuralFlowSignal(int raw_signal, double body_ratio, double volume_strength, bool emit_log=true);
string TacticalStateGlobalName(string field);
void ClearPersistedTacticalEpisodeState();
void PersistTacticalEpisodeState();
bool LoadPersistedTacticalEpisodeState(ENUM_TACTICAL_FLOW_STATE episode, datetime start_bar, int structural_direction, int &entry_count);
void LoadPersistedTacticalRuntimeState();
void RebuildAdaptiveFlowStateFromClosedBars();
void UpdateStructuralFlowOnClosedBar();
void UpdateTacticalFlowOnClosedBar();
void PrepareAdaptiveFlowForBasket(int open_positions);
void ResetAdaptiveFlowCycle();
void EndTacticalEpisode(bool clear_persisted_state=true);
void EndTacticalEpisodeReason(string reason, bool clear_persisted_state=true);
int StructuralFlowDirection();
string StructuralFlowToText();
string TacticalFlowToText();
string TacticalStateToText(ENUM_TACTICAL_EPISODE_STATE state);
string TacticalEpisodeStateToText();
void SetTacticalEpisodeState(ENUM_TACTICAL_EPISODE_STATE new_state, string reason, datetime closed_bar=0);
bool IsTradeRetcodeSuccess(uint retcode);
bool IsTacticalComment(string comment);
string TacticalOrderComment(ENUM_TACTICAL_FLOW_STATE episode);
ENUM_ORDER_TYPE TacticalOrderTypeForEpisode(ENUM_TACTICAL_FLOW_STATE episode);
string TacticalDirectionToText();
string TacticalEntryBlockReasonFromAdaptive(string reason);
void LogTacticalEntryBlock(string reason);
void LogTacticalFlowTrace(string stage, string extra="");
void ResetTacticalOrderPendingState();
bool FindOpenTacticalPosition(ENUM_ORDER_TYPE order_type, string comment, double volume, datetime request_time, ulong &position_ticket);
bool ConfirmTacticalEntryFromOpenPositions(ENUM_ORDER_TYPE order_type, string comment, double volume, datetime request_time);
bool ConfirmTacticalEntryFromDeal(ulong deal_ticket);
void MarkTacticalEntryConfirmed(ulong position_ticket, ulong deal_ticket);
void CheckTacticalOrderPendingTimeout();

int GetDynamicBuyLimit();
int GetDynamicSellLimit();
int CountPotentialBuyExposure();
int CountPotentialSellExposure();
int CountPotentialTotalExposure();
int CountOpenPositionsByComment(string comment);
bool IsAdaptivePendingOrderType(ENUM_ORDER_TYPE type);
bool CancelLegacyPendingOrdersForAdaptiveMode();
bool BaseDirectionalEntryFiltersOK(ENUM_ORDER_TYPE order_type);
double RequiredAdaptiveEntryDistancePoints();
bool CanOpenAdaptiveUnitEntry(ENUM_ORDER_TYPE order_type);
bool OpenAdaptiveUnitPosition(ENUM_ORDER_TYPE order_type, string comment);
bool ManageAsymmetricAdaptiveEntries();
void SetAdaptiveBlockReason(string reason, string context="");

bool CanOpenNewPair();
bool CanOpenAdditionalPair();
bool CanOpenNewPairAntiOvertrade();
bool OpenBuySellPair(bool additional_pair=false);

void ManageDynamicPendingOrders();
bool PlaceDynamicBuyPending();
bool PlaceDynamicSellPending();
void RepositionDynamicPendingOrders();
void CancelInvalidPendingOrders();
void CancelAllPendingOrders();

int CountOpenPositions();
int CountBuyPositions();
int CountSellPositions();
int CountPairs();
int CountPendingOrders();
int CountPendingBuyOrders();
int CountPendingSellOrders();

double GetBasketProfit();
double GetBuyBasketProfit();
double GetSellBasketProfit();

double GetAverageBuyPrice();
double GetAverageSellPrice();
double GetBasketAveragePrice();
double GetDynamicBasketClosePrice();

bool CloseAllBasket();
bool CloseBuyBasket();
bool CloseSellBasket();

void ManageBasketClosing();
void ManagePriceBasedBasketClosing();
bool BuildBreakEvenSLCandidate(ENUM_POSITION_TYPE type, double legacy_profit, double open_price, double volume, double current_sl, double &candidate_sl);
bool BuildSmartTrailingSLCandidate(ENUM_POSITION_TYPE type, double legacy_profit, double open_price, double volume, double current_sl, double &candidate_sl);
void ManageUnifiedProfitStopProtection();
void ManageBasketDrawdown();
void ManageDailyRisk();
void ManageDailyProfitTarget();
void ResetarPicoLucroCesta();
void AtualizarPicoLucroCesta();
bool GerenciarProtecaoLucroCestaMFE();

double USDToPriceDistance(double usd, double volume);

void DrawBasketLines();
void DeleteBasketLines();
void UpdatePanel();
void LogMessage(string msg);

bool UpdateSymbolData(bool real_tick);
void UpdateMarketDiagnostics();
datetime GetOperationalServerTime();
datetime GetServerDayStart(datetime server_time);
int SecondsFromMidnight(datetime value);
string FormatServerTime(datetime value);
string BoolToSimNao(bool value);
string GetSymbolSessionState(datetime server_time, bool &session_known, bool &session_open);
void RecalculateDailyResult();
void ActivateDailyLossBlock(string log_reason="");
void ActivateDailyProfitBlock(string log_reason="");
string DailyLossBlockGlobalName();
bool IsPersistedDailyLossBlockCurrent();
void PersistDailyLossBlock();
void ClearDailyLossBlock();
void RefreshDailyState();
double GetTodayClosedProfit();
double GetSelectedPositionProfitWithCosts();
double GetPositionCommissionByIdentifier(long position_id);
double GetCurrentSpreadPoints();
double NormalizePrice(double price);
double NormalizeVolume(double volume);
double MinTradeDistancePrice();
bool IsOurPositionByIndex(int index);
bool IsOurOrderByIndex(int index);
bool IsPendingOrderType(ENUM_ORDER_TYPE type);
bool IsBuyPendingType(ENUM_ORDER_TYPE type);
bool IsSellPendingType(ENUM_ORDER_TYPE type);
int LimitOpenPositions();
int LimitBuyPositions();
int LimitSellPositions();
int LimitPairs();
int LimitPendingOrders();
int LimitPendingBuyOrders();
int LimitPendingSellOrders();
bool HasExposureRoomIncludingPendings(int additionalOrders);
bool HasExposureRoomFor(int positions_to_add);
bool BaseEntryFiltersOK();
double MidPrice();
double DistanceFromLastPairPoints();
double RequiredAdditionalDistancePoints();
double BasketCloseTargetTwoDirections();
double BasketCloseTargetOneDirection();
bool GetDesiredPendingOrder(bool buy_side, ENUM_ORDER_TYPE &order_type, double &price);
bool IsPendingFiltersOK();
bool IsSLValid(ENUM_POSITION_TYPE position_type, double sl_price);
bool CloseNewestPositionOfType(ENUM_POSITION_TYPE position_type);
void DrawOrUpdateLine(string name, double price, color line_color, ENUM_LINE_STYLE line_style);
string BiasToText(int value, string positive, string negative);
string ComputePanelStatus();
void SetStatus(string status, string log_reason="");

string MFEStateToText(ENUM_MFE_POSITION_STATE state);
string MFESLSourceToText(ENUM_MFE_SL_SOURCE source);
string MFEGlobalPrefix();
string MFEGlobalName(long identifier, string field);
void ClearMFEPersistedState(long identifier);
void PersistMFEPositionState(int index, bool full_state);
bool LoadMFEPositionState(int index);
void PersistAllMFEPositionStates();
void CleanupOrphanedMFEPersistedStates();
int FindMFEPositionState(long identifier);
int FindMFEPositionStateByTicket(ulong ticket);
int AllocateMFEPositionState();
void ResetMFEPositionState(int index);
bool SelectMFEPositionByIdentifier(long identifier, ulong &ticket);
bool ReconcileMFEPositionIdentity(int index);
void InitializeMFEObservedCommissionRate();
bool ResolveMFEPositionCosts(int index);
bool CalculateMFEPositionNetProfit(int index, bool use_close_price, double close_price, double &net_profit);
int GetMFERetentionStage(double net_mfe, double &retention_ratio);
double QuantizeMFENetLock(double value);
double UpdateDesiredMFENetLock(int index);
double NormalizeMFEPriceToTick(double price, bool round_up);
bool ConvertMFENetLockToPrice(int index, double desired_net_lock, double &sl_price, double &effective_net_lock, bool &distance_clamped);
bool IsMFEStopMoreProtective(ENUM_POSITION_TYPE type, double candidate_sl, double reference_sl);
bool IsMFEStopMatchingRequest(ENUM_POSITION_TYPE type, double actual_sl, double requested_sl);
bool IsMFETradeModificationAllowed();
string MFERetcodeReason(uint retcode);
void LogMFEStateEvent(string event_name, int index, string extra="");
bool ConfirmMFEServerStop(int index, bool timeout_reconciliation);
void ReconcileMFEModifyPending(int index, bool force_timeout_check);
bool SubmitUnifiedPositionStop(int index, double requested_sl, ENUM_MFE_SL_SOURCE source, double effective_net_lock);
int InitializeMFEPositionFromSelection(ulong ticket, bool rebuild);
void RebuildMFEStateFromOpenPositions();
void FinalizeMFEPositionState(int index, double realized_net_profit, string close_reason);
void HandleMFETradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result);

int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);
   trade.SetTypeFillingBySymbol(_Symbol);

   RefreshDailyState();
   UpdateSymbolData(false);
   UpdateMarketDiagnostics();
   InitializeMFEObservedCommissionRate();
   RebuildMFEStateFromOpenPositions();

   if(CountOpenPositions() > 0)
   {
      datetime now = GetOperationalServerTime();
      if(now <= 0)
         now = TimeCurrent();
      g_lastPairOpenTime = now;
      g_lastPairCandleTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      g_lastPairMidPrice = MidPrice();
   }

   if(EventSetTimer(MAINTENANCE_TIMER_SECONDS))
      LogMessage("timer de manutencao iniciado.");
   else
      LogMessage("falha ao iniciar timer de manutencao. Erro: " + IntegerToString(GetLastError()));

   LogMessage("EA iniciado.");

   if(IsHedgingAccount())
      LogMessage("Conta HEDGE detectada.");
   else
   {
      string warning = "IA FUNDED GOLD precisa de conta HEDGE para BUY/SELL simultaneo funcionar corretamente.";
      LogMessage(warning);
      if(!MQLInfoInteger(MQL_TESTER))
         Alert(warning);
      g_nettingWarningShown = true;
   }

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   PersistAllMFEPositionStates();
   if(MFEPersistState)
      GlobalVariablesFlush();
   EventKillTimer();
   DeleteBasketLines();
   Comment("");
   LogMessage("EA finalizado.");
}

void OnTick()
{
   if(g_operationalBusy)
      return;

   g_operationalBusy = true;

   RefreshDailyState();

   if(!UpdateSymbolData(true))
   {
      UpdateMarketDiagnostics();
      UpdatePanel();
      g_operationalBusy = false;
      return;
   }

   ManageDailyRisk();
   ManageDailyProfitTarget();
   AtualizarPicoLucroCesta();
   ManageBasketClosing();
   ManagePriceBasedBasketClosing();
   if(GerenciarProtecaoLucroCestaMFE())
   {
      DrawBasketLines();
      UpdatePanel();
      g_operationalBusy = false;
      return;
   }
   ManageUnifiedProfitStopProtection();
   ManageBasketDrawdown();
   if(!UseAsymmetricBilateralFlowEngine)
   {
      g_adaptivePendingSuspensionLogged = false;
      CancelInvalidPendingOrders();
      ManageDynamicPendingOrders();

      int open_positions = CountOpenPositions();

      if(open_positions == 0)
      {
         if(CanOpenNewPair())
            OpenBuySellPair(false);
      }
      else
      {
         if(CanOpenAdditionalPair())
            OpenBuySellPair(true);
      }
   }
   else
   {
      bool adaptive_pendings_cleared = CancelLegacyPendingOrdersForAdaptiveMode();
      int adaptive_open_positions = CountOpenPositions();
      PrepareAdaptiveFlowForBasket(adaptive_open_positions);

      if(adaptive_open_positions > 0)
      {
         UpdateTacticalFlowOnClosedBar();
         UpdateStructuralFlowOnClosedBar();
         CheckTacticalOrderPendingTimeout();
         LogTacticalFlowTrace("AFTER_UPDATE");
      }

      g_adaptiveEntryAttemptedThisTick = false;
      LogTacticalFlowTrace("BEFORE_MANAGE");
      if(adaptive_pendings_cleared)
         ManageAsymmetricAdaptiveEntries();
      else
         SetAdaptiveBlockReason("TETO TOTAL", "pendentes legadas ainda ativas");
   }

   DrawBasketLines();
   UpdatePanel();
   g_operationalBusy = false;
}

void OnTimer()
{
   if(g_timerBusy || g_operationalBusy)
      return;

   g_timerBusy = true;
   RefreshDailyState();
   UpdateMarketDiagnostics();
   CheckTacticalOrderPendingTimeout();
   if(UsePanel)
      UpdatePanel();
   g_timerBusy = false;
}

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   HandleMFETradeTransaction(trans, request, result);

   if(g_tacticalState != TACTICAL_STATE_ORDER_PENDING)
      return;

   if(trans.type == TRADE_TRANSACTION_DEAL_ADD && trans.deal > 0)
      ConfirmTacticalEntryFromDeal(trans.deal);
}

bool IsHedgingAccount()
{
   return ((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
}

bool IsSpreadOK()
{
   if(!UseSpreadFilter)
      return true;

   return (GetCurrentSpreadPoints() <= (double)MaxSpreadPoints);
}

bool IsTradingHourOK()
{
   if(!UseTimeFilter)
      return true;

   datetime server_time = GetOperationalServerTime();
   if(server_time <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(server_time, dt);

   int start_hour = MathMax(0, MathMin(23, StartHour));
   int end_hour = MathMax(0, MathMin(23, EndHour));

   if(start_hour <= end_hour)
      return (dt.hour >= start_hour && dt.hour <= end_hour);

   return (dt.hour >= start_hour || dt.hour <= end_hour);
}

bool IsNewsBlocked()
{
   return false;
}

int DetectPriceActionBias()
{
   if(!UsePriceActionFilter)
      return 0;

   int lookback = MathMax(3, PriceActionLookbackBars);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, lookback + 3, rates);
   if(copied < lookback + 2)
      return 0;

   double recent_high = rates[2].high;
   double recent_low = rates[2].low;
   int bullish_sequence = 0;
   int bearish_sequence = 0;

   for(int i = 2; i < copied && i <= lookback + 1; i++)
   {
      recent_high = MathMax(recent_high, rates[i].high);
      recent_low = MathMin(recent_low, rates[i].low);

      if(rates[i].close > rates[i].open)
         bullish_sequence++;
      else if(rates[i].close < rates[i].open)
         bearish_sequence++;
   }

   MqlRates current = rates[0];
   MqlRates closed = rates[1];

   double candle_range = closed.high - closed.low;
   double body = MathAbs(closed.close - closed.open);
   double body_ratio = (candle_range > 0.0 ? body / candle_range : 0.0);
   bool strong_body = (body_ratio >= StrongCandleBodyRatio);
   bool current_holding_high = (current.close > closed.close && current.high >= closed.high);
   bool current_holding_low = (current.close < closed.close && current.low <= closed.low);
   bool bullish_break = (closed.close > recent_high || current.close > recent_high);
   bool bearish_break = (closed.close < recent_low || current.close < recent_low);
   bool bullish_displacement = (closed.close > closed.open && strong_body && closed.close > rates[2].close);
   bool bearish_displacement = (closed.close < closed.open && strong_body && closed.close < rates[2].close);

   int bullish_score = 0;
   int bearish_score = 0;

   if(bullish_break)
      bullish_score += 2;
   if(bearish_break)
      bearish_score += 2;
   if(bullish_displacement)
      bullish_score++;
   if(bearish_displacement)
      bearish_score++;
   if(current_holding_high)
      bullish_score++;
   if(current_holding_low)
      bearish_score++;
   if(bullish_sequence > bearish_sequence)
      bullish_score++;
   if(bearish_sequence > bullish_sequence)
      bearish_score++;

   if(bullish_score >= bearish_score + 2)
      return 1;
   if(bearish_score >= bullish_score + 2)
      return -1;

   return 0;
}

int DetectNativeVolumeFlow()
{
   if(!UseNativeVolumeFlow)
      return 0;

   int lookback = MathMax(3, VolumeLookbackBars);
   double open_prices[];
   double close_prices[];
   long tick_volumes[];
   ArraySetAsSeries(open_prices, true);
   ArraySetAsSeries(close_prices, true);
   ArraySetAsSeries(tick_volumes, true);

   int copied_open = CopyOpen(_Symbol, PERIOD_CURRENT, 0, lookback + 2, open_prices);
   int copied_close = CopyClose(_Symbol, PERIOD_CURRENT, 0, lookback + 2, close_prices);
   int copied_volume = CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, lookback + 2, tick_volumes);
   if(copied_open < lookback + 2 || copied_close < lookback + 2 || copied_volume < lookback + 2)
      return 0;

   double volume_sum = 0.0;
   for(int i = 2; i <= lookback + 1; i++)
      volume_sum += (double)tick_volumes[i];

   double average_volume = volume_sum / (double)lookback;
   if(average_volume <= 0.0)
      return 0;

   double strength = (double)tick_volumes[1] / average_volume;

   if(strength >= VolumeFlowMinStrength && close_prices[1] > open_prices[1])
      return 1;
   if(strength >= VolumeFlowMinStrength && close_prices[1] < open_prices[1])
      return -1;

   return 0;
}

int DetectClosedPriceActionSignal(ENUM_TIMEFRAMES timeframe, int shift)
{
   if(!UsePriceActionFilter || shift < 1)
      return 0;

   int lookback = MathMax(3, PriceActionLookbackBars);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   int copied = CopyRates(_Symbol, timeframe, shift, lookback + 1, rates);
   if(copied < lookback + 1)
      return 0;

   MqlRates latest = rates[0];
   MqlRates previous = rates[1];
   double recent_high = previous.high;
   double recent_low = previous.low;
   int bullish_sequence = 0;
   int bearish_sequence = 0;

   for(int i = 1; i < copied && i <= lookback; i++)
   {
      recent_high = MathMax(recent_high, rates[i].high);
      recent_low = MathMin(recent_low, rates[i].low);

      if(rates[i].close > rates[i].open)
         bullish_sequence++;
      else if(rates[i].close < rates[i].open)
         bearish_sequence++;
   }

   double candle_range = latest.high - latest.low;
   double body = MathAbs(latest.close - latest.open);
   double body_ratio = (candle_range > 0.0 ? body / candle_range : 0.0);
   bool strong_body = (body_ratio >= StrongCandleBodyRatio);
   bool bullish_break = (latest.close > recent_high);
   bool bearish_break = (latest.close < recent_low);
   bool bullish_displacement = (latest.close > latest.open && strong_body && latest.close > previous.close);
   bool bearish_displacement = (latest.close < latest.open && strong_body && latest.close < previous.close);

   int bullish_score = 0;
   int bearish_score = 0;

   if(latest.close > latest.open)
      bullish_score++;
   else if(latest.close < latest.open)
      bearish_score++;
   if(latest.close > previous.close)
      bullish_score++;
   if(latest.close < previous.close)
      bearish_score++;
   if(bullish_break)
      bullish_score += 2;
   if(bearish_break)
      bearish_score += 2;
   if(bullish_displacement)
      bullish_score++;
   if(bearish_displacement)
      bearish_score++;
   if(bullish_sequence > bearish_sequence)
      bullish_score++;
   if(bearish_sequence > bullish_sequence)
      bearish_score++;

   if(bullish_score >= bearish_score + 2)
      return 1;
   if(bearish_score >= bullish_score + 2)
      return -1;

   return 0;
}

int DetectClosedVolumeSignal(ENUM_TIMEFRAMES timeframe, int shift, double &volume_strength)
{
   volume_strength = 0.0;
   if(!UseNativeVolumeFlow || shift < 1)
      return 0;

   int lookback = MathMax(3, VolumeLookbackBars);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   int copied = CopyRates(_Symbol, timeframe, shift, lookback + 1, rates);
   if(copied < lookback + 1)
      return 0;

   double volume_sum = 0.0;
   for(int i = 1; i <= lookback; i++)
      volume_sum += (double)rates[i].tick_volume;

   double average_volume = volume_sum / (double)lookback;
   if(average_volume <= 0.0)
      return 0;

   volume_strength = (double)rates[0].tick_volume / average_volume;

   if(rates[0].close > rates[0].open)
      return 1;
   if(rates[0].close < rates[0].open)
      return -1;

   return 0;
}

double GetClosedCandleBodyRatio(ENUM_TIMEFRAMES timeframe, int shift)
{
   if(shift < 1)
      return 0.0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, timeframe, shift, 1, rates) < 1)
      return 0.0;

   double candle_range = rates[0].high - rates[0].low;
   if(candle_range <= 0.0)
      return 0.0;

   return MathAbs(rates[0].close - rates[0].open) / candle_range;
}

int DetectClosedTacticalSignal(ENUM_TIMEFRAMES timeframe, int shift)
{
   if(shift < 1)
      return 0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, timeframe, shift, 2, rates) < 2)
      return 0;

   double volume_strength = 0.0;
   int price_action = DetectClosedPriceActionSignal(timeframe, shift);
   int volume_signal = DetectClosedVolumeSignal(timeframe, shift, volume_strength);
   double body_ratio = GetClosedCandleBodyRatio(timeframe, shift);

   if(price_action == 1 &&
      volume_signal == 1 &&
      rates[0].close > rates[0].open &&
      rates[0].close > rates[1].close &&
      body_ratio >= TacticalMinimumBodyRatio &&
      volume_strength >= TacticalMinimumVolumeStrength)
      return 1;

   if(price_action == -1 &&
      volume_signal == -1 &&
      rates[0].close < rates[0].open &&
      rates[0].close < rates[1].close &&
      body_ratio >= TacticalMinimumBodyRatio &&
      volume_strength >= TacticalMinimumVolumeStrength)
      return -1;

   return 0;
}

double GetClosedAtrPoints(ENUM_TIMEFRAMES timeframe, int shift, int lookback)
{
   int bars = MathMax(3, lookback);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, timeframe, shift, bars + 1, rates) < bars + 1)
      return 0.0;

   double sum = 0.0;
   for(int i = 0; i < bars; i++)
   {
      double high_low = rates[i].high - rates[i].low;
      double high_close = MathAbs(rates[i].high - rates[i + 1].close);
      double low_close = MathAbs(rates[i].low - rates[i + 1].close);
      sum += MathMax(high_low, MathMax(high_close, low_close));
   }

   if(_Point <= 0.0)
      return 0.0;
   return (sum / (double)bars) / _Point;
}

void LogTacticalAnchor(string action, int structural_direction)
{
   if(g_tacticalAnchorPrice <= 0.0 || structural_direction == 0)
      return;

   string structural_side = (structural_direction > 0 ? "BUY" : "SELL");
   LogMessage("[TACTICAL_ANCHOR] action=" + action +
              " structural=" + structural_side +
              " anchor_bar=" + TimeToString(g_tacticalAnchorBar, TIME_DATE | TIME_SECONDS) +
              " anchor_price=" + DoubleToString(g_tacticalAnchorPrice, _Digits) +
              " source_shift=" + IntegerToString(g_tacticalAnchorSourceShift));
}

void ResetTacticalAnchor()
{
   bool had_anchor = (g_tacticalAnchorPrice > 0.0 || g_tacticalAnchorBar > 0 || g_tacticalAnchorStructuralDirection != 0);
   int previous_direction = g_tacticalAnchorStructuralDirection;

   g_tacticalAnchorPrice = 0.0;
   g_tacticalAnchorBar = 0;
   g_tacticalAnchorStructuralDirection = 0;
   g_tacticalAnchorSourceShift = 0;

   if(had_anchor)
      LogMessage("[TACTICAL_ANCHOR] action=RESET structural=" + (previous_direction > 0 ? "BUY" : previous_direction < 0 ? "SELL" : "NONE"));
}

bool EnsureTacticalAnchor(int structural_direction, ENUM_TIMEFRAMES timeframe, int shift)
{
   if(structural_direction == 0 || shift < 1)
      return false;

   if(g_tacticalAnchorPrice > 0.0 && g_tacticalAnchorStructuralDirection == structural_direction)
      return true;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int lookback = MathMax(2, TACTICAL_ANCHOR_LOOKBACK_BARS);
   int copied = CopyRates(_Symbol, timeframe, shift, lookback, rates);
   if(copied <= 0)
      return false;

   int anchor_index = 0;
   double anchor = (structural_direction < 0 ? rates[0].low : rates[0].high);
   for(int i = 1; i < copied; i++)
   {
      if(structural_direction < 0 && rates[i].low < anchor)
      {
         anchor = rates[i].low;
         anchor_index = i;
      }
      else if(structural_direction > 0 && rates[i].high > anchor)
      {
         anchor = rates[i].high;
         anchor_index = i;
      }
   }

   g_tacticalAnchorPrice = anchor;
   g_tacticalAnchorBar = rates[anchor_index].time;
   g_tacticalAnchorStructuralDirection = structural_direction;
   g_tacticalAnchorSourceShift = shift + anchor_index;
   LogTacticalAnchor("CREATED", structural_direction);
   return (g_tacticalAnchorPrice > 0.0);
}

void RefreshTacticalAnchor(int structural_direction, ENUM_TIMEFRAMES timeframe, int shift)
{
   if(structural_direction == 0 || shift < 1)
   {
      ResetTacticalAnchor();
      return;
   }

   if(g_tacticalState != TACTICAL_STATE_NONE || g_tacticalEpisode != TACTICAL_NONE)
      return;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, timeframe, shift, 1, rates) < 1)
      return;

   if(!EnsureTacticalAnchor(structural_direction, timeframe, shift))
      return;

   if(structural_direction < 0 && rates[0].low < g_tacticalAnchorPrice)
   {
      g_tacticalAnchorPrice = rates[0].low;
      g_tacticalAnchorBar = rates[0].time;
      g_tacticalAnchorStructuralDirection = structural_direction;
      g_tacticalAnchorSourceShift = shift;
      LogTacticalAnchor("UPDATED", structural_direction);
   }
   else if(structural_direction > 0 && rates[0].high > g_tacticalAnchorPrice)
   {
      g_tacticalAnchorPrice = rates[0].high;
      g_tacticalAnchorBar = rates[0].time;
      g_tacticalAnchorStructuralDirection = structural_direction;
      g_tacticalAnchorSourceShift = shift;
      LogTacticalAnchor("UPDATED", structural_direction);
   }
}

int DetectClosedTacticalCorrectionSignal(ENUM_TIMEFRAMES timeframe, int shift, int structural_direction, double &body_ratio, double &displacement_points, double &atr_points, int &price_action, int &volume_signal, string &reason)
{
   body_ratio = 0.0;
   displacement_points = 0.0;
   atr_points = 0.0;
   price_action = 0;
   volume_signal = 0;
   reason = "SEM_CONFIRMACAO";

   if(structural_direction == 0)
   {
      reason = "TACTICAL_NO_PROTECTED_STRUCTURE";
      return 0;
   }

   if(shift < 1)
   {
      reason = "TACTICAL_DATA_BARS_INSUFFICIENT";
      return 0;
   }

   int tactical_signal = -structural_direction;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, timeframe, shift, 2, rates) < 2)
   {
      reason = "TACTICAL_DATA_BARS_INSUFFICIENT";
      return 0;
   }

   double candle_range = rates[0].high - rates[0].low;
   if(candle_range <= 0.0 || _Point <= 0.0)
   {
      reason = "TACTICAL_DATA_BARS_INSUFFICIENT";
      return 0;
   }

   double body = MathAbs(rates[0].close - rates[0].open);
   body_ratio = body / candle_range;
   double close_position = (rates[0].close - rates[0].low) / candle_range;
   double upper_wick = rates[0].high - MathMax(rates[0].open, rates[0].close);
   double lower_wick = MathMin(rates[0].open, rates[0].close) - rates[0].low;

   bool direction_ok = (tactical_signal > 0 ? rates[0].close > rates[0].open : rates[0].close < rates[0].open);
   if(!direction_ok)
   {
      reason = "TACTICAL_DIRECTION_MISMATCH";
      return 0;
   }

   double tactical_body_min = MathMax(0.30, TacticalMinimumBodyRatio - 0.12);
   if(body_ratio < tactical_body_min)
   {
      reason = "TACTICAL_CANDLE_BODY_SMALL";
      return 0;
   }

   bool close_ok = (tactical_signal > 0 ? close_position >= 0.55 : close_position <= 0.45);
   if(!close_ok)
   {
      reason = "TACTICAL_CLOSE_POSITION";
      return 0;
   }

   bool wick_ok = (tactical_signal > 0 ? upper_wick <= candle_range * 0.55 : lower_wick <= candle_range * 0.55);
   if(!wick_ok)
   {
      reason = "TACTICAL_WICK_REJECTION";
      return 0;
   }

   atr_points = GetClosedAtrPoints(timeframe, shift, TACTICAL_ATR_LOOKBACK_BARS);
   if(atr_points <= 0.0)
   {
      reason = "TACTICAL_DATA_ATR_UNAVAILABLE";
      return 0;
   }

   if(!EnsureTacticalAnchor(structural_direction, timeframe, shift))
   {
      reason = "TACTICAL_DATA_ANCHOR_UNAVAILABLE";
      return 0;
   }

   displacement_points = (tactical_signal > 0 ?
                          (rates[0].close - g_tacticalAnchorPrice) / _Point :
                          (g_tacticalAnchorPrice - rates[0].close) / _Point);
   double min_points = MathMax((double)First_step * 0.20, (double)Minimum_price_distance * 0.15);
   double min_atr = atr_points * TACTICAL_MIN_ENTRY_ATR_RATIO;
   double max_atr = atr_points * TACTICAL_MAX_ENTRY_ATR_RATIO;

   if(displacement_points < MathMax(min_points, min_atr))
   {
      reason = "DISPLACEMENT_TOO_SMALL";
      return 0;
   }

   if(displacement_points > max_atr)
   {
      reason = "TACTICAL_LATE_EXTENSION";
      return 0;
   }

   double candle_range_points = candle_range / _Point;
   if(candle_range_points > atr_points * TACTICAL_MAX_CONFIRMATION_CANDLE_ATR)
   {
      reason = "TACTICAL_EXHAUSTION_CANDLE";
      return 0;
   }

   if(UseNativeVolumeFlow && Bars(_Symbol, timeframe) < shift + MathMax(3, VolumeLookbackBars) + 1)
   {
      reason = "TACTICAL_DATA_VOLUME_UNAVAILABLE";
      return 0;
   }

   double volume_strength = 0.0;
   price_action = DetectClosedPriceActionSignal(timeframe, shift);
   volume_signal = DetectClosedVolumeSignal(timeframe, shift, volume_strength);
   if(UseNativeVolumeFlow && volume_strength <= 0.0)
   {
      reason = "TACTICAL_DATA_VOLUME_UNAVAILABLE";
      return 0;
   }

   bool volume_against = (volume_signal == structural_direction && volume_strength >= TacticalMinimumVolumeStrength);
   if(volume_against)
   {
      reason = "TACTICAL_VOLUME_STILL_STRUCTURAL";
      return 0;
   }

   bool price_transition = (tactical_signal > 0 ? rates[0].close > rates[1].close : rates[0].close < rates[1].close);
   bool pa_ok = (price_action == tactical_signal || price_transition);
   bool volume_contrary = (volume_signal == tactical_signal && volume_strength >= TacticalMinimumVolumeStrength);
   bool volume_neutral = (volume_signal == 0 || volume_strength < TacticalMinimumVolumeStrength);

   if(!(pa_ok && (volume_contrary || volume_neutral)) && !(volume_contrary && price_transition))
   {
      reason = "PA_VOLUME_INSUFICIENTE";
      return 0;
   }

   reason = "TACTICAL_VALID";
   return tactical_signal;
}
bool GetClosedStructuralSignal(ENUM_TIMEFRAMES timeframe, int shift, int &raw_signal, double &body_ratio, double &volume_strength)
{
   raw_signal = 0;
   body_ratio = 0.0;
   volume_strength = 0.0;

   if(shift < 1 || iTime(_Symbol, timeframe, shift) <= 0)
      return false;

   int price_action = DetectClosedPriceActionSignal(timeframe, shift);
   int volume_signal = DetectClosedVolumeSignal(timeframe, shift, volume_strength);
   body_ratio = GetClosedCandleBodyRatio(timeframe, shift);

   if(price_action != 0 &&
      price_action == volume_signal &&
      volume_strength >= VolumeFlowMinStrength)
      raw_signal = price_action;

   return true;
}

void ApplyStructuralFlowSignal(int raw_signal, double body_ratio, double volume_strength, bool emit_log=true)
{
   if(raw_signal == 0)
   {
      g_structuralCandidateDirection = 0;
      g_structuralConsecutiveConfirmations = 0;
   }
   else if(g_structuralCandidateDirection == raw_signal)
      g_structuralConsecutiveConfirmations++;
   else
   {
      g_structuralCandidateDirection = raw_signal;
      g_structuralConsecutiveConfirmations = 1;
   }

   int strong_bars = MathMax(2, StructuralStrongConfirmationBars);
   double strong_body = MathMin(0.90, StrongCandleBodyRatio + 0.10);
   double strong_volume = VolumeFlowMinStrength + 0.20;
   bool strong_confirmation = (raw_signal != 0 &&
                               g_structuralConsecutiveConfirmations >= strong_bars &&
                               body_ratio >= strong_body &&
                               volume_strength >= strong_volume);

   int protected_direction = (g_tacticalEpisodeStructuralDirection != 0 ? g_tacticalEpisodeStructuralDirection : StructuralFlowDirection());
   datetime structural_closed_bar = iTime(_Symbol, StructuralFlowTimeframe, 1);
   if(g_tacticalState != TACTICAL_STATE_NONE && protected_direction != 0)
   {
      bool same_bar_block = (structural_closed_bar > 0 && structural_closed_bar == g_blockOppositeStructuralPromotionBar);
      bool correction_or_neutral = (raw_signal == 0 || raw_signal == -protected_direction);
      if(same_bar_block && correction_or_neutral)
      {
         if(emit_log)
            LogMessage("[TACTICAL_BLOCK] reason=SAME_BAR_STRUCTURAL_PROMOTION_BLOCKED");
         return;
      }

      if(correction_or_neutral && !strong_confirmation)
      {
         if(emit_log)
            LogMessage("[IA_FG_ASYMMETRIC] fluxo estrutural preservado durante microcorrecao");
         return;
      }

      if(raw_signal == -protected_direction && strong_confirmation)
         EndTacticalEpisodeReason("STRUCTURAL_REVERSAL", true);
   }

   int current = (int)g_structuralStableFlow;
   int next = current;

   if(raw_signal == 0)
   {
      if(current > 0)
         next = current - 1;
      else if(current < 0)
         next = current + 1;
   }
   else if(current == 0)
      next = raw_signal;
   else if((current > 0 && raw_signal < 0) || (current < 0 && raw_signal > 0))
      next = (current > 0 ? current - 1 : current + 1);
   else
   {
      int target = raw_signal * (strong_confirmation ? 2 : 1);
      if(current < target)
         next = current + 1;
      else if(current > target)
         next = current - 1;
   }

   next = MathMax(-2, MathMin(2, next));
   if(next == current)
      return;

   string previous = "";
   if(emit_log)
      previous = StructuralFlowToText();

   g_structuralStableFlow = (ENUM_STRUCTURAL_FLOW_STATE)next;

   if(emit_log)
      LogMessage("[IA_FG_ASYMMETRIC] fluxo estrutural: " + previous + " -> " + StructuralFlowToText());
}

string TacticalStateGlobalName(string field)
{
   return "IAFGAB_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + "_" +
          _Symbol + "_" + IntegerToString(MagicNumber) + "_" + field;
}

void ClearPersistedTacticalEpisodeState()
{
   GlobalVariableDel(TacticalStateGlobalName("V"));
   GlobalVariableDel(TacticalStateGlobalName("D"));
   GlobalVariableDel(TacticalStateGlobalName("B"));
   GlobalVariableDel(TacticalStateGlobalName("S"));
   GlobalVariableDel(TacticalStateGlobalName("C"));
   GlobalVariableDel(TacticalStateGlobalName("E"));
   GlobalVariableDel(TacticalStateGlobalName("A"));
   GlobalVariableDel(TacticalStateGlobalName("AB"));
   GlobalVariableDel(TacticalStateGlobalName("AS"));
   GlobalVariableDel(TacticalStateGlobalName("N"));
   GlobalVariableDel(TacticalStateGlobalName("L"));
   GlobalVariableDel(TacticalStateGlobalName("AC"));
   GlobalVariableDel(TacticalStateGlobalName("BP"));
   GlobalVariableDel(TacticalStateGlobalName("RQ"));
   GlobalVariableDel(TacticalStateGlobalName("RB"));
}

void PersistTacticalEpisodeState()
{
   if(g_tacticalEpisode == TACTICAL_NONE ||
      g_tacticalEpisodeStartBar <= 0 ||
      g_tacticalEpisodeStructuralDirection == 0 ||
      g_tacticalState == TACTICAL_STATE_NONE)
      return;

   if(g_tacticalEntryCount < 0)
      g_tacticalEntryCount = 0;
   if(g_tacticalEntryCount > TACTICAL_MAX_PROGRESSIVE_ENTRIES)
      g_tacticalEntryCount = TACTICAL_MAX_PROGRESSIVE_ENTRIES;

   GlobalVariableSet(TacticalStateGlobalName("V"), 2.0);
   GlobalVariableSet(TacticalStateGlobalName("D"), (double)((int)g_tacticalEpisode));
   GlobalVariableSet(TacticalStateGlobalName("B"), (double)g_tacticalEpisodeStartBar);
   GlobalVariableSet(TacticalStateGlobalName("S"), (double)g_tacticalEpisodeStructuralDirection);
   GlobalVariableSet(TacticalStateGlobalName("C"), (double)g_tacticalEntryCount);
   GlobalVariableSet(TacticalStateGlobalName("E"), (double)((int)g_tacticalState));
   GlobalVariableSet(TacticalStateGlobalName("A"), g_tacticalAnchorPrice);
   GlobalVariableSet(TacticalStateGlobalName("AB"), (double)g_tacticalAnchorBar);
   GlobalVariableSet(TacticalStateGlobalName("AS"), (double)g_tacticalAnchorSourceShift);
   GlobalVariableSet(TacticalStateGlobalName("N"), (double)g_tacticalNeutralClosedBars);
   GlobalVariableSet(TacticalStateGlobalName("L"), (double)g_tacticalEpisodeClosedBars);
   GlobalVariableSet(TacticalStateGlobalName("AC"), (double)g_tacticalActivatedClosedBar);
   GlobalVariableSet(TacticalStateGlobalName("BP"), (double)g_blockOppositeStructuralPromotionBar);
   GlobalVariableSet(TacticalStateGlobalName("RQ"), (double)g_tacticalOrderRequestTime);
   GlobalVariableSet(TacticalStateGlobalName("RB"), (double)g_tacticalOrderRequestBar);
}

bool LoadPersistedTacticalEpisodeState(ENUM_TACTICAL_FLOW_STATE episode, datetime start_bar, int structural_direction, int &entry_count)
{
   entry_count = TACTICAL_MAX_PROGRESSIVE_ENTRIES;

   string version_name = TacticalStateGlobalName("V");
   string direction_name = TacticalStateGlobalName("D");
   string start_name = TacticalStateGlobalName("B");
   string structure_name = TacticalStateGlobalName("S");
   string count_name = TacticalStateGlobalName("C");

   if(!GlobalVariableCheck(version_name) ||
      !GlobalVariableCheck(direction_name) ||
      !GlobalVariableCheck(start_name) ||
      !GlobalVariableCheck(structure_name) ||
      !GlobalVariableCheck(count_name))
      return false;

   int version = (int)GlobalVariableGet(version_name);
   int persisted_direction = (int)GlobalVariableGet(direction_name);
   datetime persisted_start = (datetime)GlobalVariableGet(start_name);
   int persisted_structure = (int)GlobalVariableGet(structure_name);
   int persisted_count = (int)GlobalVariableGet(count_name);

   if(version != 2 ||
      persisted_direction != (int)episode ||
      persisted_start != start_bar ||
      persisted_structure != structural_direction ||
      persisted_count < 0 ||
      persisted_count > TACTICAL_MAX_PROGRESSIVE_ENTRIES)
      return false;

   entry_count = persisted_count;
   return true;
}

void LoadPersistedTacticalRuntimeState()
{
   if(GlobalVariableCheck(TacticalStateGlobalName("E")))
   {
      int state = (int)GlobalVariableGet(TacticalStateGlobalName("E"));
      if(state >= (int)TACTICAL_STATE_CANDIDATE && state <= (int)TACTICAL_STATE_CONSUMED)
         g_tacticalState = (ENUM_TACTICAL_EPISODE_STATE)state;
   }

   if(GlobalVariableCheck(TacticalStateGlobalName("A")))
      g_tacticalAnchorPrice = GlobalVariableGet(TacticalStateGlobalName("A"));
   if(GlobalVariableCheck(TacticalStateGlobalName("AB")))
      g_tacticalAnchorBar = (datetime)GlobalVariableGet(TacticalStateGlobalName("AB"));
   if(GlobalVariableCheck(TacticalStateGlobalName("AS")))
      g_tacticalAnchorSourceShift = (int)GlobalVariableGet(TacticalStateGlobalName("AS"));
   if(GlobalVariableCheck(TacticalStateGlobalName("N")))
      g_tacticalNeutralClosedBars = (int)GlobalVariableGet(TacticalStateGlobalName("N"));
   if(GlobalVariableCheck(TacticalStateGlobalName("L")))
      g_tacticalEpisodeClosedBars = (int)GlobalVariableGet(TacticalStateGlobalName("L"));
   if(GlobalVariableCheck(TacticalStateGlobalName("AC")))
      g_tacticalActivatedClosedBar = (datetime)GlobalVariableGet(TacticalStateGlobalName("AC"));
   if(GlobalVariableCheck(TacticalStateGlobalName("BP")))
      g_blockOppositeStructuralPromotionBar = (datetime)GlobalVariableGet(TacticalStateGlobalName("BP"));
   if(GlobalVariableCheck(TacticalStateGlobalName("RQ")))
      g_tacticalOrderRequestTime = (datetime)GlobalVariableGet(TacticalStateGlobalName("RQ"));
   if(GlobalVariableCheck(TacticalStateGlobalName("RB")))
      g_tacticalOrderRequestBar = (datetime)GlobalVariableGet(TacticalStateGlobalName("RB"));

   if(g_tacticalState == TACTICAL_STATE_NONE)
      g_tacticalState = (g_tacticalEntryCount > 0 ? TACTICAL_STATE_CONSUMED : TACTICAL_STATE_ACTIVE);
   if(g_tacticalEntryCount > 0)
      g_tacticalState = TACTICAL_STATE_CONSUMED;
   if(g_tacticalAnchorPrice > 0.0)
      g_tacticalAnchorStructuralDirection = g_tacticalEpisodeStructuralDirection;
}
void RebuildAdaptiveFlowStateFromClosedBars()
{
   g_structuralStableFlow = STRUCTURAL_NEUTRAL;
   g_structuralCandidateDirection = 0;
   g_structuralConsecutiveConfirmations = 0;
   EndTacticalEpisode(false);
   g_tacticalAwaitingPostRebuildClosedBar = true;

   int available = Bars(_Symbol, StructuralFlowTimeframe);
   int bars_to_scan = MathMax(3, StructuralStrongConfirmationBars + 4);
   int max_shift = MathMin(bars_to_scan, available - 1);

   for(int shift = max_shift; shift >= 1; shift--)
   {
      int raw_signal = 0;
      double body_ratio = 0.0;
      double volume_strength = 0.0;
      if(GetClosedStructuralSignal(StructuralFlowTimeframe, shift, raw_signal, body_ratio, volume_strength))
         ApplyStructuralFlowSignal(raw_signal, body_ratio, volume_strength, false);
   }

   g_lastStructuralClosedBar = iTime(_Symbol, StructuralFlowTimeframe, 1);
   g_lastTacticalClosedBar = iTime(_Symbol, TacticalFlowTimeframe, 1);

   int structural_direction = StructuralFlowDirection();
   if(structural_direction == 0)
      return;

   ulong tactical_position = 0;
   bool has_tactical_buy = FindOpenTacticalPosition(ORDER_TYPE_BUY, "IA_FG_TACTICAL_BUY", 0.0, 0, tactical_position);
   bool has_tactical_sell = false;
   if(!has_tactical_buy)
      has_tactical_sell = FindOpenTacticalPosition(ORDER_TYPE_SELL, "IA_FG_TACTICAL_SELL", 0.0, 0, tactical_position);

   double body_ratio = 0.0;
   double displacement_points = 0.0;
   double atr_points = 0.0;
   int price_action = 0;
   int volume_signal = 0;
   string reason = "";
   int tactical_signal = 0;

   if(has_tactical_buy || has_tactical_sell)
      tactical_signal = (has_tactical_buy ? 1 : -1);
   else
      tactical_signal = DetectClosedTacticalCorrectionSignal(TacticalFlowTimeframe,
                                                             1,
                                                             structural_direction,
                                                             body_ratio,
                                                             displacement_points,
                                                             atr_points,
                                                             price_action,
                                                             volume_signal,
                                                             reason);

   if(tactical_signal == 0 || tactical_signal != -structural_direction)
      return;

   g_tacticalEpisode = (tactical_signal > 0 ? TACTICAL_BUY : TACTICAL_SELL);
   g_tacticalEpisodeStartBar = g_lastTacticalClosedBar;
   g_tacticalEpisodeStructuralDirection = structural_direction;
   g_tacticalConsecutiveConfirmations = 1;
   g_tacticalEpisodeClosedBars = 1;

   int persisted_entry_count = TACTICAL_MAX_PROGRESSIVE_ENTRIES;
   bool persisted_ok = LoadPersistedTacticalEpisodeState(g_tacticalEpisode,
                                                         g_tacticalEpisodeStartBar,
                                                         g_tacticalEpisodeStructuralDirection,
                                                         persisted_entry_count);
   if(persisted_ok)
   {
      g_tacticalEntryCount = persisted_entry_count;
      LoadPersistedTacticalRuntimeState();
   }
   else
   {
      g_tacticalEntryCount = TACTICAL_MAX_PROGRESSIVE_ENTRIES;
      g_tacticalState = TACTICAL_STATE_CONSUMED;
   }

   if(has_tactical_buy || has_tactical_sell)
   {
      g_tacticalEntryCount = TACTICAL_MAX_PROGRESSIVE_ENTRIES;
      g_tacticalState = TACTICAL_STATE_CONSUMED;
      g_tacticalConfirmedPosition = tactical_position;
   }

   if(g_tacticalState == TACTICAL_STATE_ORDER_PENDING && !(has_tactical_buy || has_tactical_sell))
      g_tacticalState = TACTICAL_STATE_ACTIVE;
   if(g_tacticalEntryCount > 0)
      g_tacticalState = TACTICAL_STATE_CONSUMED;

   EnsureTacticalAnchor(structural_direction, TacticalFlowTimeframe, 1);
   g_tacticalEntryExecuted = (g_tacticalEntryCount > 0);
   g_tacticalConsecutiveConfirmations = MathMax(g_tacticalConsecutiveConfirmations, g_tacticalEntryCount);
}
int StructuralFlowDirection()
{
   if((int)g_structuralStableFlow > 0)
      return 1;
   if((int)g_structuralStableFlow < 0)
      return -1;
   return 0;
}

string StructuralFlowToText()
{
   switch(g_structuralStableFlow)
   {
      case STRUCTURAL_STRONG_SELL:
         return "SELL FORTE";
      case STRUCTURAL_MODERATE_SELL:
         return "SELL MODERADO";
      case STRUCTURAL_MODERATE_BUY:
         return "BUY MODERADO";
      case STRUCTURAL_STRONG_BUY:
         return "BUY FORTE";
      default:
         return "NEUTRO";
   }
}

string TacticalFlowToText()
{
   if(g_tacticalEpisode == TACTICAL_BUY)
      return "BUY TATICO";
   if(g_tacticalEpisode == TACTICAL_SELL)
      return "SELL TATICO";
   return "NENHUM";
}

string TacticalStateToText(ENUM_TACTICAL_EPISODE_STATE state)
{
   switch(state)
   {
      case TACTICAL_STATE_CANDIDATE:
         return "CANDIDATE";
      case TACTICAL_STATE_ACTIVE:
         return "ACTIVE";
      case TACTICAL_STATE_ORDER_PENDING:
         return "ORDER_PENDING";
      case TACTICAL_STATE_CONSUMED:
         return "CONSUMED";
      default:
         return "NONE";
   }
}

string TacticalEpisodeStateToText()
{
   switch(g_tacticalState)
   {
      case TACTICAL_STATE_CANDIDATE:
         return "CANDIDATO";
      case TACTICAL_STATE_ACTIVE:
         return "ATIVO";
      case TACTICAL_STATE_ORDER_PENDING:
         return "ORDEM PENDENTE";
      case TACTICAL_STATE_CONSUMED:
         return "CONSUMIDO";
      default:
         return "INATIVO";
   }
}

void SetTacticalEpisodeState(ENUM_TACTICAL_EPISODE_STATE new_state, string reason, datetime closed_bar)
{
   if(g_tacticalState == new_state)
      return;

   string from_state = TacticalStateToText(g_tacticalState);
   string to_state = TacticalStateToText(new_state);
   g_tacticalState = new_state;
   LogMessage("[TACTICAL_STATE] from=" + from_state +
              " to=" + to_state +
              " bar=" + TimeToString(closed_bar, TIME_DATE | TIME_SECONDS) +
              " reason=" + reason);
}

bool IsTradeRetcodeSuccess(uint retcode)
{
   return (retcode == TRADE_RETCODE_DONE ||
           retcode == TRADE_RETCODE_DONE_PARTIAL ||
           retcode == TRADE_RETCODE_PLACED);
}

bool IsTacticalComment(string comment)
{
   return (comment == "IA_FG_TACTICAL_BUY" || comment == "IA_FG_TACTICAL_SELL");
}

string TacticalOrderComment(ENUM_TACTICAL_FLOW_STATE episode)
{
   if(episode == TACTICAL_BUY)
      return "IA_FG_TACTICAL_BUY";
   if(episode == TACTICAL_SELL)
      return "IA_FG_TACTICAL_SELL";
   return "";
}

ENUM_ORDER_TYPE TacticalOrderTypeForEpisode(ENUM_TACTICAL_FLOW_STATE episode)
{
   return (episode == TACTICAL_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
}

string TacticalDirectionToText()
{
   if(g_tacticalEpisode == TACTICAL_BUY)
      return "BUY";
   if(g_tacticalEpisode == TACTICAL_SELL)
      return "SELL";
   return "NONE";
}

string TacticalEntryBlockReasonFromAdaptive(string reason)
{
   if(reason == "TETO TOTAL")
      return "TOTAL_EXPOSURE_LIMIT";
   if(reason == "LIMITE DO LADO")
      return "SIDE_EXPOSURE_LIMIT";
   if(reason == "DISTANCIA")
      return "DISTANCE_BLOCK";
   if(reason == "TEMPO" || reason == "CANDLE")
      return "COOLDOWN_BLOCK";
   if(reason == "DD" || reason == "LOSS DIARIO" || reason == "META DIARIA")
      return "RISK_BLOCK";
   if(reason == "MERCADO FECHADO" || reason == "HORARIO" || reason == "SPREAD")
      return "MARKET_NOT_AVAILABLE";
   if(reason == "SEM CONFIRMACAO")
      return "ADAPTIVE_DISTRIBUTION_LIMIT";
   if(reason == "")
      return "INTERNAL_STATE_MISMATCH";
   return "ADAPTIVE_DISTRIBUTION_LIMIT";
}

void LogTacticalEntryBlock(string reason)
{
   datetime bar = g_lastTacticalClosedBar;
   string state = TacticalEpisodeStateToText();
   string direction = TacticalDirectionToText();
   string adaptive_reason = (g_adaptiveBlockReason == "" ? "NONE" : g_adaptiveBlockReason);
   bool pending = (g_tacticalState == TACTICAL_STATE_ORDER_PENDING || g_tacticalPendingOrder > 0 || g_tacticalPendingDeal > 0);
   string key = TimeToString(bar, TIME_DATE | TIME_SECONDS) + "|" + state + "|" + direction + "|" + reason + "|" + adaptive_reason;
   if(key == g_lastTacticalEntryBlockLogKey)
      return;

   LogMessage("[TACTICAL_ENTRY_BLOCK] state=" + state +
              " direction=" + direction +
              " reason=" + reason +
              " adaptive_reason=" + adaptive_reason +
              " buy_count=" + IntegerToString(CountPotentialBuyExposure()) +
              " sell_count=" + IntegerToString(CountPotentialSellExposure()) +
              " total=" + IntegerToString(CountPotentialTotalExposure()) +
              " buy_limit=" + IntegerToString(GetDynamicBuyLimit()) +
              " sell_limit=" + IntegerToString(GetDynamicSellLimit()) +
              " total_limit=" + IntegerToString(MathMin(8, LimitOpenPositions())) +
              " entry_count=" + IntegerToString(g_tacticalEntryCount) +
              " pending=" + (pending ? "1" : "0") +
              " attempted_tick=" + (g_adaptiveEntryAttemptedThisTick ? "1" : "0") +
              " bar=" + TimeToString(bar, TIME_DATE | TIME_SECONDS));
   g_lastTacticalEntryBlockLogKey = key;
}

void LogTacticalFlowTrace(string stage, string extra)
{
   if(g_tacticalState != TACTICAL_STATE_ACTIVE && g_tacticalState != TACTICAL_STATE_ORDER_PENDING)
      return;

   datetime bar = g_lastTacticalClosedBar;
   string key = stage + "|" + TimeToString(bar, TIME_DATE | TIME_SECONDS) + "|" + TacticalEpisodeStateToText() + "|" + TacticalDirectionToText() + "|" + extra;

   if(stage == "AFTER_UPDATE")
   {
      if(key == g_lastTacticalFlowTraceAfterUpdateKey)
         return;
      g_lastTacticalFlowTraceAfterUpdateKey = key;
   }
   else if(stage == "BEFORE_MANAGE")
   {
      if(key == g_lastTacticalFlowTraceBeforeManageKey)
         return;
      g_lastTacticalFlowTraceBeforeManageKey = key;
   }
   else if(stage == "BEFORE_OPEN")
   {
      if(key == g_lastTacticalFlowTraceBeforeOpenKey)
         return;
      g_lastTacticalFlowTraceBeforeOpenKey = key;
   }
   else if(stage == "AFTER_OPEN")
   {
      if(key == g_lastTacticalFlowTraceAfterOpenKey)
         return;
      g_lastTacticalFlowTraceAfterOpenKey = key;
   }
   else
   {
      if(key == g_lastTacticalFlowTraceOtherKey)
         return;
      g_lastTacticalFlowTraceOtherKey = key;
   }

   string suffix = (extra == "" ? "" : " " + extra);
   LogMessage("[TACTICAL_FLOW_TRACE] stage=" + stage +
              " state=" + TacticalEpisodeStateToText() +
              " direction=" + TacticalDirectionToText() +
              " bar=" + TimeToString(bar, TIME_DATE | TIME_SECONDS) +
              " entry_count=" + IntegerToString(g_tacticalEntryCount) +
              " attempted=" + (g_adaptiveEntryAttemptedThisTick ? "1" : "0") +
              suffix);
}

void ResetTacticalOrderPendingState()
{
   g_tacticalPendingOrder = 0;
   g_tacticalPendingDeal = 0;
   g_tacticalOrderRequestTime = 0;
   g_tacticalOrderRequestBar = 0;
   g_tacticalPendingOrderType = ORDER_TYPE_BUY;
   g_tacticalPendingComment = "";
   g_tacticalPendingVolume = 0.0;
}

bool FindOpenTacticalPosition(ENUM_ORDER_TYPE order_type, string comment, double volume, datetime request_time, ulong &position_ticket)
{
   position_ticket = 0;
   ENUM_POSITION_TYPE expected_type = (order_type == ORDER_TYPE_BUY ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0)
      step = 0.00000001;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!IsOurPositionByIndex(i))
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != expected_type)
         continue;
      if(PositionGetString(POSITION_COMMENT) != comment)
         continue;
      if(volume > 0.0 && MathAbs(PositionGetDouble(POSITION_VOLUME) - volume) > step + 0.00000001)
         continue;

      datetime position_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(request_time > 0 && position_time + 60 < request_time)
         continue;

      position_ticket = (ulong)PositionGetInteger(POSITION_TICKET);
      return (position_ticket > 0);
   }

   return false;
}

bool ConfirmTacticalEntryFromOpenPositions(ENUM_ORDER_TYPE order_type, string comment, double volume, datetime request_time)
{
   ulong position_ticket = 0;
   if(!FindOpenTacticalPosition(order_type, comment, volume, request_time, position_ticket))
      return false;

   MarkTacticalEntryConfirmed(position_ticket, g_tacticalPendingDeal);
   return true;
}

bool ConfirmTacticalEntryFromDeal(ulong deal_ticket)
{
   if(deal_ticket == 0 || !HistoryDealSelect(deal_ticket))
      return false;

   if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol)
      return false;
   if((long)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != MagicNumber)
      return false;
   if(HistoryDealGetString(deal_ticket, DEAL_COMMENT) != g_tacticalPendingComment)
      return false;
   if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY) != DEAL_ENTRY_IN)
      return false;

   ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
   if(g_tacticalPendingOrderType == ORDER_TYPE_BUY && deal_type != DEAL_TYPE_BUY)
      return false;
   if(g_tacticalPendingOrderType == ORDER_TYPE_SELL && deal_type != DEAL_TYPE_SELL)
      return false;

   double deal_volume = HistoryDealGetDouble(deal_ticket, DEAL_VOLUME);
   if(deal_volume <= 0.0)
      return false;

   ulong position_id = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
   MarkTacticalEntryConfirmed(position_id, deal_ticket);
   return true;
}

void MarkTacticalEntryConfirmed(ulong position_ticket, ulong deal_ticket)
{
   if(g_tacticalState == TACTICAL_STATE_CONSUMED && g_tacticalEntryCount >= TACTICAL_MAX_PROGRESSIVE_ENTRIES)
      return;

   string side = (g_tacticalEpisode == TACTICAL_BUY ? "BUY" : "SELL");
   g_tacticalEntryCount = TACTICAL_MAX_PROGRESSIVE_ENTRIES;
   g_tacticalEntryExecuted = true;
   g_tacticalConfirmedPosition = position_ticket;
   g_tacticalConfirmedDeal = deal_ticket;
   ResetTacticalOrderPendingState();
   SetTacticalEpisodeState(TACTICAL_STATE_CONSUMED, "ORDER_CONFIRMED", g_lastTacticalClosedBar);
   PersistTacticalEpisodeState();

   LogMessage("[TACTICAL_ORDER_CONFIRMED] side=" + side +
              " position=" + IntegerToString((long)position_ticket) +
              " deal=" + IntegerToString((long)deal_ticket));
   LogMessage("[TACTICAL_CONSUMED] entry_count=" + IntegerToString(g_tacticalEntryCount));
}

void CheckTacticalOrderPendingTimeout()
{
   if(g_tacticalState != TACTICAL_STATE_ORDER_PENDING)
      return;

   if(ConfirmTacticalEntryFromOpenPositions(g_tacticalPendingOrderType,
                                            g_tacticalPendingComment,
                                            g_tacticalPendingVolume,
                                            g_tacticalOrderRequestTime))
      return;

   datetime now = TimeCurrent();
   if(g_tacticalOrderRequestTime <= 0 || now - g_tacticalOrderRequestTime < TACTICAL_ORDER_PENDING_TIMEOUT_SECONDS)
      return;

   if(g_tacticalPendingDeal > 0 && ConfirmTacticalEntryFromDeal(g_tacticalPendingDeal))
      return;

   string side = (g_tacticalEpisode == TACTICAL_BUY ? "BUY" : "SELL");
   LogMessage("[TACTICAL_ORDER_TIMEOUT_RECONCILED] side=" + side +
              " request_bar=" + TimeToString(g_tacticalOrderRequestBar, TIME_DATE | TIME_SECONDS));
   ResetTacticalOrderPendingState();
   SetTacticalEpisodeState(TACTICAL_STATE_ACTIVE, "ORDER_TIMEOUT", g_lastTacticalClosedBar);
   PersistTacticalEpisodeState();
}
void EndTacticalEpisode(bool clear_persisted_state)
{
   EndTacticalEpisodeReason("MANUAL", clear_persisted_state);
}

void EndTacticalEpisodeReason(string reason, bool clear_persisted_state)
{
   ENUM_TACTICAL_EPISODE_STATE previous_state = g_tacticalState;
   bool had_episode = (g_tacticalEpisode != TACTICAL_NONE || g_tacticalState != TACTICAL_STATE_NONE);
   string side = (g_tacticalEpisode == TACTICAL_BUY ? "BUY" : g_tacticalEpisode == TACTICAL_SELL ? "SELL" : "NONE");

   if(had_episode)
   {
      LogMessage("[TACTICAL_END] reason=" + reason +
                 " side=" + side +
                 " bar=" + TimeToString(g_lastTacticalClosedBar, TIME_DATE | TIME_SECONDS));
      SetTacticalEpisodeState(TACTICAL_STATE_NONE, reason, g_lastTacticalClosedBar);
   }
   else
      g_tacticalState = TACTICAL_STATE_NONE;

   g_tacticalEpisode = TACTICAL_NONE;
   if(clear_persisted_state)
      ClearPersistedTacticalEpisodeState();

   g_tacticalEntryExecuted = false;
   g_tacticalEntryCount = 0;
   g_tacticalConsecutiveConfirmations = 0;
   g_tacticalAwaitingPostRebuildClosedBar = false;
   g_tacticalEpisodeStartBar = 0;
   g_tacticalEpisodeStructuralDirection = 0;
   g_tacticalActivatedClosedBar = 0;
   g_tacticalEntryAuthorizedClosedBar = 0;
   g_tacticalLastEndBar = g_lastTacticalClosedBar;
   g_tacticalNeutralClosedBars = 0;
   g_tacticalEpisodeClosedBars = 0;
   g_tacticalConsumedBlockLoggedBar = 0;
   g_lastTacticalEntryBlockLogKey = "";
   g_lastTacticalFlowTraceAfterUpdateKey = "";
   g_lastTacticalFlowTraceBeforeManageKey = "";
   g_lastTacticalFlowTraceBeforeOpenKey = "";
   g_lastTacticalFlowTraceAfterOpenKey = "";
   g_lastTacticalFlowTraceOtherKey = "";

   if(previous_state == TACTICAL_STATE_ORDER_PENDING || clear_persisted_state)
      ResetTacticalOrderPendingState();

   ResetTacticalAnchor();
}
void ResetAdaptiveFlowCycle()
{
   if(g_structuralStableFlow != STRUCTURAL_NEUTRAL)
   {
      string previous = StructuralFlowToText();
      g_structuralStableFlow = STRUCTURAL_NEUTRAL;
      LogMessage("[IA_FG_ASYMMETRIC] fluxo estrutural: " + previous + " -> NEUTRO");
   }
   else
      g_structuralStableFlow = STRUCTURAL_NEUTRAL;

   EndTacticalEpisode();
   g_structuralCandidateDirection = 0;
   g_structuralConsecutiveConfirmations = 0;
   g_lastStructuralClosedBar = 0;
   g_lastTacticalClosedBar = 0;
   g_blockOppositeStructuralPromotionBar = 0;
   g_tacticalLastEndBar = 0;
   g_adaptiveBasketWasActive = false;
   g_adaptiveEntryAttemptedThisTick = false;
   g_adaptiveLastAction = "AGUARDANDO";
   g_adaptiveBlockReason = "SEM CONFIRMACAO";
   g_lastAdaptiveBlockLogKey = "";
}

void PrepareAdaptiveFlowForBasket(int open_positions)
{
   if(open_positions <= 0)
   {
      if(g_adaptiveBasketWasActive)
         ResetAdaptiveFlowCycle();
      return;
   }

   if(g_adaptiveBasketWasActive)
      return;

   g_adaptiveBasketWasActive = true;
   RebuildAdaptiveFlowStateFromClosedBars();
}

void UpdateStructuralFlowOnClosedBar()
{
   datetime closed_bar = iTime(_Symbol, StructuralFlowTimeframe, 1);
   if(closed_bar <= 0)
      return;

   if(g_lastStructuralClosedBar == 0)
   {
      g_lastStructuralClosedBar = closed_bar;
      return;
   }

   if(closed_bar == g_lastStructuralClosedBar)
      return;

   g_lastStructuralClosedBar = closed_bar;

   int raw_signal = 0;
   double body_ratio = 0.0;
   double volume_strength = 0.0;
   if(!GetClosedStructuralSignal(StructuralFlowTimeframe, 1, raw_signal, body_ratio, volume_strength))
      return;

   ApplyStructuralFlowSignal(raw_signal, body_ratio, volume_strength, true);
}

void UpdateTacticalFlowOnClosedBar()
{
   datetime closed_bar = iTime(_Symbol, TacticalFlowTimeframe, 1);
   if(closed_bar <= 0)
      return;

   if(g_lastTacticalClosedBar == 0)
   {
      g_lastTacticalClosedBar = closed_bar;
      return;
   }

   if(closed_bar == g_lastTacticalClosedBar)
      return;

   g_lastTacticalClosedBar = closed_bar;
   if(g_tacticalAwaitingPostRebuildClosedBar)
      g_tacticalAwaitingPostRebuildClosedBar = false;

   if(g_tacticalState == TACTICAL_STATE_ORDER_PENDING)
   {
      g_tacticalEpisodeClosedBars++;
      CheckTacticalOrderPendingTimeout();
      PersistTacticalEpisodeState();
      return;
   }

   int current_structural_direction = StructuralFlowDirection();
   int structural_direction = (g_tacticalState != TACTICAL_STATE_NONE && g_tacticalEpisodeStructuralDirection != 0 ?
                               g_tacticalEpisodeStructuralDirection :
                               current_structural_direction);

   if(structural_direction == 0)
   {
      if(g_tacticalState != TACTICAL_STATE_NONE || g_tacticalEpisode != TACTICAL_NONE)
         EndTacticalEpisodeReason("STRUCTURAL_NEUTRAL", true);
      else
         ResetTacticalAnchor();
      return;
   }

   if(g_tacticalState != TACTICAL_STATE_NONE &&
      g_tacticalEpisodeStructuralDirection != 0 &&
      current_structural_direction != 0 &&
      current_structural_direction != g_tacticalEpisodeStructuralDirection)
   {
      EndTacticalEpisodeReason("STRUCTURAL_REVERSAL", true);
      return;
   }

   if(g_tacticalState == TACTICAL_STATE_NONE && g_tacticalEpisode == TACTICAL_NONE)
      RefreshTacticalAnchor(structural_direction, TacticalFlowTimeframe, 1);

   double body_ratio = 0.0;
   double displacement_points = 0.0;
   double atr_points = 0.0;
   int price_action = 0;
   int volume_signal = 0;
   string reason = "";
   int tactical_signal = DetectClosedTacticalCorrectionSignal(TacticalFlowTimeframe,
                                                              1,
                                                              structural_direction,
                                                              body_ratio,
                                                              displacement_points,
                                                              atr_points,
                                                              price_action,
                                                              volume_signal,
                                                              reason);

   bool valid_tactical = (tactical_signal == -structural_direction);

   if(valid_tactical)
   {
      if(g_tacticalState == TACTICAL_STATE_NONE || g_tacticalEpisode == TACTICAL_NONE)
      {
         g_tacticalEpisode = (tactical_signal > 0 ? TACTICAL_BUY : TACTICAL_SELL);
         g_tacticalEntryExecuted = false;
         g_tacticalEntryCount = 0;
         g_tacticalConsecutiveConfirmations = 1;
         g_tacticalEpisodeStartBar = closed_bar;
         g_tacticalEpisodeStructuralDirection = structural_direction;
         g_tacticalActivatedClosedBar = closed_bar;
         g_tacticalEntryAuthorizedClosedBar = 0;
         g_blockOppositeStructuralPromotionBar = closed_bar;
         g_tacticalNeutralClosedBars = 0;
         g_tacticalEpisodeClosedBars = 1;
         SetTacticalEpisodeState(TACTICAL_STATE_ACTIVE, "TACTICAL_VALID", closed_bar);
         PersistTacticalEpisodeState();

         string structural_side = (structural_direction > 0 ? "BUY" : "SELL");
         string side = (g_tacticalEpisode == TACTICAL_BUY ? "BUY" : "SELL");
         LogMessage("[TACTICAL_ANCHOR] action=FROZEN structural=" + structural_side +
                    " anchor_bar=" + TimeToString(g_tacticalAnchorBar, TIME_DATE | TIME_SECONDS) +
                    " anchor_price=" + DoubleToString(g_tacticalAnchorPrice, _Digits) +
                    " source_shift=" + IntegerToString(g_tacticalAnchorSourceShift));
         LogMessage("[TACTICAL_SIGNAL] structural=" + structural_side +
                    " tactical=" + side +
                    " bar=" + TimeToString(closed_bar, TIME_DATE | TIME_SECONDS) +
                    " body=" + DoubleToString(body_ratio, 2) +
                    " displacement=" + DoubleToString(displacement_points, 1) +
                    " atr=" + DoubleToString(atr_points, 1) +
                    " ratio=" + DoubleToString((atr_points > 0.0 ? displacement_points / atr_points : 0.0), 2) +
                    " pa=" + IntegerToString(price_action) +
                    " volume=" + IntegerToString(volume_signal) +
                    " reason=" + reason);
         return;
      }

      bool same_structure = (structural_direction == g_tacticalEpisodeStructuralDirection);
      bool same_signal = (tactical_signal == (int)g_tacticalEpisode);
      if(!same_structure || !same_signal)
      {
         EndTacticalEpisodeReason("TACTICAL_DIRECTION_CHANGED", true);
         return;
      }

      g_tacticalConsecutiveConfirmations++;
      g_tacticalNeutralClosedBars = 0;
      g_tacticalEpisodeClosedBars++;
      if(g_tacticalEpisodeClosedBars >= TACTICAL_MAX_EPISODE_BARS)
         EndTacticalEpisodeReason("MAX_EPISODE_BARS", true);
      else
         PersistTacticalEpisodeState();
      return;
   }

   if(g_tacticalState == TACTICAL_STATE_NONE || g_tacticalEpisode == TACTICAL_NONE)
   {
      if(reason != "SEM_CONFIRMACAO")
         LogMessage("[TACTICAL_BLOCK] reason=" + reason);
      return;
   }

   g_tacticalEpisodeClosedBars++;

   int resume_signal = 0;
   double resume_body_ratio = 0.0;
   double resume_volume_strength = 0.0;
   if(GetClosedStructuralSignal(TacticalFlowTimeframe, 1, resume_signal, resume_body_ratio, resume_volume_strength) &&
      resume_signal == structural_direction)
   {
      EndTacticalEpisodeReason("STRUCTURAL_RESUMED", true);
      return;
   }

   g_tacticalNeutralClosedBars++;
   if(g_tacticalNeutralClosedBars >= TACTICAL_NEUTRAL_END_BARS)
   {
      EndTacticalEpisodeReason("NEUTRAL_TIMEOUT", true);
      return;
   }

   if(g_tacticalEpisodeClosedBars >= TACTICAL_MAX_EPISODE_BARS)
   {
      EndTacticalEpisodeReason("MAX_EPISODE_BARS", true);
      return;
   }

   if(reason != "SEM_CONFIRMACAO")
      LogMessage("[TACTICAL_BLOCK] reason=" + reason);
   PersistTacticalEpisodeState();
}
int GetDynamicBuyLimit()
{
   switch(g_structuralStableFlow)
   {
      case STRUCTURAL_STRONG_SELL:
         return 2;
      case STRUCTURAL_MODERATE_SELL:
         return 3;
      case STRUCTURAL_MODERATE_BUY:
         return 5;
      case STRUCTURAL_STRONG_BUY:
         return 6;
      default:
         return 4;
   }
}

int GetDynamicSellLimit()
{
   switch(g_structuralStableFlow)
   {
      case STRUCTURAL_STRONG_SELL:
         return 6;
      case STRUCTURAL_MODERATE_SELL:
         return 5;
      case STRUCTURAL_MODERATE_BUY:
         return 3;
      case STRUCTURAL_STRONG_BUY:
         return 2;
      default:
         return 4;
   }
}

bool IsAdaptivePendingOrderType(ENUM_ORDER_TYPE type)
{
   return (type == ORDER_TYPE_BUY_LIMIT ||
           type == ORDER_TYPE_SELL_LIMIT ||
           type == ORDER_TYPE_BUY_STOP ||
           type == ORDER_TYPE_SELL_STOP ||
           type == ORDER_TYPE_BUY_STOP_LIMIT ||
           type == ORDER_TYPE_SELL_STOP_LIMIT);
}

int CountPotentialBuyExposure()
{
   int count = CountBuyPositions();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != MagicNumber)
         continue;

      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_LIMIT ||
         type == ORDER_TYPE_BUY_STOP ||
         type == ORDER_TYPE_BUY_STOP_LIMIT)
         count++;
   }

   return count;
}

int CountPotentialSellExposure()
{
   int count = CountSellPositions();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != MagicNumber)
         continue;

      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_SELL_LIMIT ||
         type == ORDER_TYPE_SELL_STOP ||
         type == ORDER_TYPE_SELL_STOP_LIMIT)
         count++;
   }

   return count;
}

int CountPotentialTotalExposure()
{
   return CountPotentialBuyExposure() + CountPotentialSellExposure();
}

int CountOpenPositionsByComment(string comment)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!IsOurPositionByIndex(i))
         continue;

      if(PositionGetString(POSITION_COMMENT) == comment)
         count++;
   }
   return count;
}

bool CancelLegacyPendingOrdersForAdaptiveMode()
{
   if(!g_adaptivePendingSuspensionLogged)
   {
      LogMessage("[IA_FG_ASYMMETRIC] pendentes legadas suspensas no modo adaptativo");
      g_adaptivePendingSuspensionLogged = true;
   }

   bool all_cleared = true;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != MagicNumber)
         continue;

      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(!IsAdaptivePendingOrderType(type))
         continue;

      if(!trade.OrderDelete(ticket))
      {
         all_cleared = false;
         LogMessage("[IA_FG_ASYMMETRIC] falha ao cancelar pendente legada: " +
                    IntegerToString((int)trade.ResultRetcode()) + " - " +
                    trade.ResultRetcodeDescription());
      }
   }

   return (all_cleared && CountPotentialTotalExposure() == CountOpenPositions());
}

void SetAdaptiveBlockReason(string reason, string context="")
{
   g_adaptiveBlockReason = reason;

   if(reason == "")
   {
      g_lastAdaptiveBlockLogKey = "";
      return;
   }

   string key = context + "|" + reason;
   if(key == g_lastAdaptiveBlockLogKey)
      return;

   string prefix = "[IA_FG_ASYMMETRIC] bloqueio";
   if(context != "")
      prefix += " " + context;

   LogMessage(prefix + ": " + reason);
   g_lastAdaptiveBlockLogKey = key;
}

bool BaseDirectionalEntryFiltersOK(ENUM_ORDER_TYPE order_type)
{
   if(order_type != ORDER_TYPE_BUY && order_type != ORDER_TYPE_SELL)
   {
      SetAdaptiveBlockReason("SEM CONFIRMACAO");
      return false;
   }

   if(!AllowTrading)
   {
      SetAdaptiveBlockReason("SEM CONFIRMACAO", "trading desativado");
      return false;
   }

   if(order_type == ORDER_TYPE_BUY && !Allow_BUY)
   {
      SetAdaptiveBlockReason("LIMITE DO LADO", "BUY desativada");
      return false;
   }

   if(order_type == ORDER_TYPE_SELL && !Allow_SELL)
   {
      SetAdaptiveBlockReason("LIMITE DO LADO", "SELL desativada");
      return false;
   }

   if(TerminalInfoInteger(TERMINAL_CONNECTED) == 0)
   {
      SetAdaptiveBlockReason("MERCADO FECHADO", "terminal desconectado");
      return false;
   }

   if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) == 0 ||
      MQLInfoInteger(MQL_TRADE_ALLOWED) == 0)
   {
      SetAdaptiveBlockReason("MERCADO FECHADO", "negociacao indisponivel");
      return false;
   }

   if(g_tick.bid <= 0.0 || g_tick.ask <= 0.0 || g_lastRealTickTime <= 0 ||
      g_waitingFirstTickAfterReopen)
   {
      SetAdaptiveBlockReason("MERCADO FECHADO", "aguardando tick real");
      return false;
   }

   if(g_symbolSessionState == "MERCADO FECHADO" ||
      g_symbolSessionState == "SEM TICKS" ||
      g_symbolSessionState == "AGUARDANDO PRIMEIRO TICK")
   {
      SetAdaptiveBlockReason("MERCADO FECHADO");
      return false;
   }

   long trade_mode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(trade_mode == SYMBOL_TRADE_MODE_DISABLED || trade_mode == SYMBOL_TRADE_MODE_CLOSEONLY)
   {
      SetAdaptiveBlockReason("MERCADO FECHADO", "simbolo sem abertura");
      return false;
   }

   if(order_type == ORDER_TYPE_BUY && trade_mode == SYMBOL_TRADE_MODE_SHORTONLY)
   {
      SetAdaptiveBlockReason("LIMITE DO LADO", "simbolo somente SELL");
      return false;
   }

   if(order_type == ORDER_TYPE_SELL && trade_mode == SYMBOL_TRADE_MODE_LONGONLY)
   {
      SetAdaptiveBlockReason("LIMITE DO LADO", "simbolo somente BUY");
      return false;
   }

   if(!IsHedgingAccount())
   {
      SetAdaptiveBlockReason("SEM CONFIRMACAO", "conta nao HEDGE");
      return false;
   }

   if(!IsSpreadOK())
   {
      SetAdaptiveBlockReason("SPREAD");
      return false;
   }

   if(!IsTradingHourOK())
   {
      SetAdaptiveBlockReason("HORARIO");
      return false;
   }

   if(IsNewsBlocked())
   {
      SetAdaptiveBlockReason("SEM CONFIRMACAO", "noticia");
      return false;
   }

   if(g_dailyLossBlocked)
   {
      SetAdaptiveBlockReason("LOSS DIARIO");
      return false;
   }

   if(g_dailyProfitBlocked)
   {
      SetAdaptiveBlockReason("META DIARIA");
      return false;
   }

   if(g_basketDDBlocked)
   {
      SetAdaptiveBlockReason("DD");
      return false;
   }

   return true;
}

double RequiredAdaptiveEntryDistancePoints()
{
   double required = (double)MathMax(Distance_between_orders, Minimum_price_distance);
   if(CountOpenPositions() <= 2)
      required = MathMax(required, (double)First_step);
   return MathMax(required, 0.0);
}

bool CanOpenAdaptiveUnitEntry(ENUM_ORDER_TYPE order_type)
{
   if(!OpenAdditionalPairsWhileBasketActive || !OpenAdditionalPairsUntilMaxPositions)
   {
      SetAdaptiveBlockReason("SEM CONFIRMACAO", "entradas adicionais desativadas");
      return false;
   }

   if(CountOpenPositions() <= 0)
   {
      SetAdaptiveBlockReason("SEM CONFIRMACAO");
      return false;
   }

   if(StopAddingPairsWhenBasketPositive && GetBasketProfit() > 0.0)
   {
      SetAdaptiveBlockReason("SEM CONFIRMACAO", "cesta positiva");
      return false;
   }

   if(!BaseDirectionalEntryFiltersOK(order_type))
      return false;

   int potential_total = CountPotentialTotalExposure();
   int total_limit = MathMin(8, LimitOpenPositions());
   if(potential_total + 1 > 8 || potential_total + 1 > total_limit)
   {
      SetAdaptiveBlockReason("TETO TOTAL");
      return false;
   }

   if(order_type == ORDER_TYPE_BUY &&
      CountPotentialBuyExposure() + 1 > GetDynamicBuyLimit())
   {
      SetAdaptiveBlockReason("LIMITE DO LADO", "BUY");
      return false;
   }

   if(order_type == ORDER_TYPE_SELL &&
      CountPotentialSellExposure() + 1 > GetDynamicSellLimit())
   {
      SetAdaptiveBlockReason("LIMITE DO LADO", "SELL");
      return false;
   }

   datetime now = TimeCurrent();

   if(g_lastPairOpenTime > 0 && MinSecondsBetweenAdditionalPairs > 0 &&
      (int)(now - g_lastPairOpenTime) < MinSecondsBetweenAdditionalPairs)
   {
      SetAdaptiveBlockReason("TEMPO");
      return false;
   }

   if(RequireDistanceForAdditionalPairs)
   {
      double distance = DistanceFromLastPairPoints();
      if(distance < RequiredAdaptiveEntryDistancePoints())
      {
         SetAdaptiveBlockReason("DISTANCIA");
         return false;
      }
   }

   if(UseAntiOvertradeFilter)
   {
      if(MinSecondsBetweenPairs > 0 && g_lastPairOpenTime > 0 &&
         (int)(now - g_lastPairOpenTime) < MinSecondsBetweenPairs)
      {
         SetAdaptiveBlockReason("TEMPO");
         return false;
      }

      if(OnePairPerCandle)
      {
         datetime candle_time = iTime(_Symbol, PERIOD_CURRENT, 0);
         if(candle_time > 0 && g_lastPairCandleTime == candle_time)
         {
            SetAdaptiveBlockReason("CANDLE");
            return false;
         }
      }

      if(BlockNewPairNearBasketTarget && CountOpenPositions() > 0)
      {
         double target = BasketCloseTargetTwoDirections();
         double remaining = target - GetBasketProfit();
         if(remaining >= 0.0 && remaining <= BasketTargetProximityUSD)
         {
            SetAdaptiveBlockReason("SEM CONFIRMACAO", "proximo ao alvo da cesta");
            return false;
         }
      }
   }

   SetAdaptiveBlockReason("");
   return true;
}

bool OpenAdaptiveUnitPosition(ENUM_ORDER_TYPE order_type, string comment)
{
   if(g_adaptiveEntryAttemptedThisTick)
      return false;

   g_adaptiveEntryAttemptedThisTick = true;

   if(order_type != ORDER_TYPE_BUY && order_type != ORDER_TYPE_SELL)
      return false;

   double lot = NormalizeVolume(FixedLot);
   if(lot <= 0.0)
   {
      LogMessage("[IA_FG_ASYMMETRIC] falha de entrada unitaria: lote invalido");
      return false;
   }

   bool opened = false;
   if(order_type == ORDER_TYPE_BUY)
      opened = trade.Buy(lot, _Symbol, 0.0, 0.0, 0.0, comment);
   else
      opened = trade.Sell(lot, _Symbol, 0.0, 0.0, 0.0, comment);

   if(!opened)
   {
      LogMessage("[IA_FG_ASYMMETRIC] falha de entrada unitaria: " +
                 IntegerToString((int)trade.ResultRetcode()) + " - " +
                 trade.ResultRetcodeDescription());
      return false;
   }

   uint retcode = (uint)trade.ResultRetcode();
   if(!IsTradeRetcodeSuccess(retcode))
   {
      LogMessage("[IA_FG_ASYMMETRIC] entrada unitaria sem retcode de execucao: " +
                 IntegerToString((int)retcode) + " - " +
                 trade.ResultRetcodeDescription());
      return false;
   }

   g_lastPairOpenTime = TimeCurrent();
   g_lastPairCandleTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   g_lastPairMidPrice = MidPrice();
   return true;
}

bool ManageAsymmetricAdaptiveEntries()
{
   if(g_adaptiveEntryAttemptedThisTick)
   {
      if(g_tacticalState == TACTICAL_STATE_ACTIVE)
         LogTacticalEntryBlock("ENTRY_ATTEMPTED_THIS_TICK");
      return false;
   }

   int open_positions = CountOpenPositions();

   if(open_positions == 0)
   {
      g_adaptiveLastAction = "AGUARDANDO";
      if(CanOpenNewPair())
      {
         g_adaptiveEntryAttemptedThisTick = true;
         if(OpenBuySellPair(false))
         {
            g_adaptiveLastAction = "PAR INICIAL";
            SetAdaptiveBlockReason("");
         }
      }
      return true;
   }

   if(g_tacticalEpisode != TACTICAL_NONE || g_tacticalState != TACTICAL_STATE_NONE)
   {
      if(g_tacticalEpisode != TACTICAL_BUY && g_tacticalEpisode != TACTICAL_SELL)
      {
         SetAdaptiveBlockReason("CORRECAO ATIVA", "direcao tatica invalida");
         LogTacticalEntryBlock("INVALID_TACTICAL_DIRECTION");
         return false;
      }

      string side = TacticalDirectionToText();

      if(g_tacticalAwaitingPostRebuildClosedBar)
      {
         SetAdaptiveBlockReason("CORRECAO ATIVA", side + " aguardando candle pos-rebuild");
         LogTacticalEntryBlock("POST_REBUILD_GUARD");
         return false;
      }

      if(g_tacticalState == TACTICAL_STATE_ORDER_PENDING)
      {
         CheckTacticalOrderPendingTimeout();
         SetAdaptiveBlockReason("CORRECAO ATIVA", side + " ordem tatica pendente");
         LogTacticalEntryBlock("ORDER_ALREADY_PENDING");
         return false;
      }

      if(g_tacticalState == TACTICAL_STATE_CONSUMED || g_tacticalEntryCount >= TACTICAL_MAX_PROGRESSIVE_ENTRIES)
      {
         SetAdaptiveBlockReason("CORRECAO ATIVA", side + " tatica consumida");
         LogTacticalEntryBlock("ALREADY_CONSUMED");
         if(g_tacticalConsumedBlockLoggedBar != g_lastTacticalClosedBar)
         {
            LogMessage("[TACTICAL_BLOCK] reason=ALREADY_CONSUMED");
            g_tacticalConsumedBlockLoggedBar = g_lastTacticalClosedBar;
         }
         return false;
      }

      if(g_tacticalState != TACTICAL_STATE_ACTIVE)
      {
         SetAdaptiveBlockReason("CORRECAO ATIVA", side + " aguardando estado ativo");
         LogTacticalEntryBlock("INTERNAL_STATE_MISMATCH");
         return false;
      }

      if(!UseTacticalCorrectionEntries)
      {
         SetAdaptiveBlockReason("CORRECAO ATIVA", side + " tatica desativada");
         LogTacticalEntryBlock("TRADE_NOT_ALLOWED");
         return false;
      }

      if(g_tacticalEntryAuthorizedClosedBar == g_lastTacticalClosedBar)
      {
         SetAdaptiveBlockReason("CORRECAO ATIVA", side + " aguardando novo candle");
         LogTacticalEntryBlock("SAME_BAR_DUPLICATE_REQUEST");
         return false;
      }

      ENUM_ORDER_TYPE tactical_order = TacticalOrderTypeForEpisode(g_tacticalEpisode);
      string tactical_comment = TacticalOrderComment(g_tacticalEpisode);
      double tactical_volume = NormalizeVolume(FixedLot);

      if(CanOpenAdaptiveUnitEntry(tactical_order))
      {
         LogTacticalFlowTrace("BEFORE_OPEN", "side=" + side);
         g_tacticalEntryAuthorizedClosedBar = g_lastTacticalClosedBar;
         g_blockOppositeStructuralPromotionBar = g_lastTacticalClosedBar;
         g_tacticalPendingOrderType = tactical_order;
         g_tacticalPendingComment = tactical_comment;
         g_tacticalPendingVolume = tactical_volume;
         g_tacticalOrderRequestTime = TimeCurrent();
         g_tacticalOrderRequestBar = g_lastTacticalClosedBar;
         SetTacticalEpisodeState(TACTICAL_STATE_ORDER_PENDING, "ORDER_REQUESTED", g_lastTacticalClosedBar);
         PersistTacticalEpisodeState();

         LogMessage("[TACTICAL_ORDER_REQUESTED] side=" + side +
                    " bar=" + TimeToString(g_lastTacticalClosedBar, TIME_DATE | TIME_SECONDS) +
                    " request=" + tactical_comment);

         bool requested = OpenAdaptiveUnitPosition(tactical_order, tactical_comment);
         uint retcode = (uint)trade.ResultRetcode();
         g_tacticalPendingOrder = trade.ResultOrder();
         g_tacticalPendingDeal = trade.ResultDeal();
         LogTacticalFlowTrace("AFTER_OPEN", "result=" + (requested ? "1" : "0") + " retcode=" + IntegerToString((int)retcode));

         if(!requested || !IsTradeRetcodeSuccess(retcode))
         {
            LogMessage("[TACTICAL_ORDER_REJECTED] retcode=" + IntegerToString((int)retcode) +
                       " description=" + trade.ResultRetcodeDescription());
            ResetTacticalOrderPendingState();
            SetTacticalEpisodeState(TACTICAL_STATE_ACTIVE, "ORDER_REJECTED", g_lastTacticalClosedBar);
            PersistTacticalEpisodeState();
            return true;
         }

         PersistTacticalEpisodeState();
         ConfirmTacticalEntryFromOpenPositions(tactical_order,
                                               tactical_comment,
                                               tactical_volume,
                                               g_tacticalOrderRequestTime);
         if(g_tacticalState == TACTICAL_STATE_ORDER_PENDING && g_tacticalPendingDeal > 0)
            ConfirmTacticalEntryFromDeal(g_tacticalPendingDeal);
         g_adaptiveLastAction = side + " TATICA";
         SetAdaptiveBlockReason("");
         return true;
      }

      LogTacticalEntryBlock(TacticalEntryBlockReasonFromAdaptive(g_adaptiveBlockReason));
      return true;
   }

   int structural_direction = StructuralFlowDirection();
   if(structural_direction == 0)
   {
      if(CanOpenAdditionalPair())
      {
         g_adaptiveEntryAttemptedThisTick = true;
         if(OpenBuySellPair(true))
         {
            g_adaptiveLastAction = "PAR BILATERAL LATERAL";
            SetAdaptiveBlockReason("");
            return true;
         }
      }

      g_adaptiveLastAction = "AGUARDANDO";
      SetAdaptiveBlockReason("SEM CONFIRMACAO");
      return false;
   }

   ENUM_ORDER_TYPE structural_order = (structural_direction > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   string structural_side = (structural_direction > 0 ? "BUY" : "SELL");
   string structural_comment = (structural_direction > 0 ? "IA_FG_STRUCTURAL_BUY" : "IA_FG_STRUCTURAL_SELL");

   if(CanOpenAdaptiveUnitEntry(structural_order) &&
      OpenAdaptiveUnitPosition(structural_order, structural_comment))
   {
      g_adaptiveLastAction = "REFORCO " + structural_side;
      SetAdaptiveBlockReason("");
      LogMessage("[IA_FG_ASYMMETRIC] reforco estrutural " + structural_side + " aberto");
      return true;
   }

   return false;
}
bool CanOpenNewPair()
{
   if(!AlwaysInMarket)
      return false;

   if(!EA_makes_first_order)
      return false;

   if(CountOpenPositions() > 0)
      return false;

   if(!BaseEntryFiltersOK())
      return false;

   if(!HasExposureRoomFor(2))
   {
      SetStatus("MAXIMO DE 8 OPERACOES", "bloqueio por MaxOpenPositions");
      return false;
   }

   if(CountBuyPositions() + 1 > LimitBuyPositions())
   {
      SetStatus("MAXIMO DE 8 OPERACOES", "bloqueio por MaxBuyPositions");
      return false;
   }

   if(CountSellPositions() + 1 > LimitSellPositions())
   {
      SetStatus("MAXIMO DE 8 OPERACOES", "bloqueio por MaxSellPositions");
      return false;
   }

   if(g_lastBasketCloseTime > 0)
   {
      if(!OpenPairImmediatelyAfterBasketClose)
         return false;

      int elapsed = (int)(TimeCurrent() - g_lastBasketCloseTime);
      if(elapsed < ReopenDelaySecondsAfterClose)
      {
         SetStatus("OPERANDO", "aguardando delay para reabrir cesta");
         return false;
      }
   }

   SetStatus("OPERANDO");
   return true;
}

bool CanOpenAdditionalPair()
{
   if(!OpenAdditionalPairsWhileBasketActive || !OpenAdditionalPairsUntilMaxPositions)
      return false;

   if(CountOpenPositions() <= 0)
      return false;

   if(StopAddingPairsWhenBasketPositive && GetBasketProfit() > 0.0)
      return false;

   if(!BaseEntryFiltersOK())
      return false;

   if(CountOpenPositions() >= LimitOpenPositions())
   {
      SetStatus("MAXIMO DE 8 OPERACOES", "bloqueio por MaxOpenPositions");
      return false;
   }

   if(CountPairs() >= LimitPairs())
   {
      SetStatus("MAXIMO DE 8 OPERACOES", "bloqueio por MaxPairs");
      return false;
   }

   if(CountBuyPositions() + 1 > LimitBuyPositions())
   {
      SetStatus("MAXIMO DE 8 OPERACOES", "bloqueio por MaxBuyPositions");
      return false;
   }

   if(CountSellPositions() + 1 > LimitSellPositions())
   {
      SetStatus("MAXIMO DE 8 OPERACOES", "bloqueio por MaxSellPositions");
      return false;
   }

   if(!HasExposureRoomFor(2))
   {
      SetStatus("MAXIMO DE 8 OPERACOES", "bloqueio por MaxOpenPositions");
      return false;
   }

   if(g_lastPairOpenTime > 0 && MinSecondsBetweenAdditionalPairs > 0)
   {
      int elapsed = (int)(TimeCurrent() - g_lastPairOpenTime);
      if(elapsed < MinSecondsBetweenAdditionalPairs)
      {
         SetStatus("AGUARDANDO DISTANCIA", "bloqueio por tempo minimo entre pares adicionais");
         return false;
      }
   }

   if(RequireDistanceForAdditionalPairs)
   {
      double distance = DistanceFromLastPairPoints();
      double required = RequiredAdditionalDistancePoints();
      if(distance < required)
      {
         SetStatus("AGUARDANDO DISTANCIA", "bloqueio por distancia");
         return false;
      }
   }

   if(!CanOpenNewPairAntiOvertrade())
      return false;

   SetStatus("ABRINDO PAR ADICIONAL");
   return true;
}

bool CanOpenNewPairAntiOvertrade()
{
   if(!UseAntiOvertradeFilter)
      return true;

   datetime now = TimeCurrent();

   if(MinSecondsBetweenPairs > 0 && g_lastPairOpenTime > 0)
   {
      int elapsed = (int)(now - g_lastPairOpenTime);
      if(elapsed < MinSecondsBetweenPairs)
      {
         SetStatus("AGUARDANDO DISTANCIA", "bloqueio por tempo minimo entre pares");
         return false;
      }
   }

   if(OnePairPerCandle)
   {
      datetime candle_time = iTime(_Symbol, PERIOD_CURRENT, 0);
      if(candle_time > 0 && g_lastPairCandleTime == candle_time)
      {
         SetStatus("AGUARDANDO DISTANCIA", "bloqueio por um par por candle");
         return false;
      }
   }

   if(BlockNewPairNearBasketTarget && CountOpenPositions() > 0)
   {
      double target = BasketCloseTargetTwoDirections();
      double remaining = target - GetBasketProfit();
      if(remaining >= 0.0 && remaining <= BasketTargetProximityUSD)
      {
         SetStatus("AGUARDANDO DISTANCIA", "bloqueio por proximidade do alvo da cesta");
         return false;
      }
   }

   return true;
}

bool OpenBuySellPair(bool additional_pair=false)
{
   if(!Allow_BUY || !Allow_SELL)
      return false;

   double lot = NormalizeVolume(FixedLot);
   if(lot <= 0.0)
   {
      LogMessage("erro ao abrir ordem: lote fixo invalido para o simbolo.");
      return false;
   }

   string tag = (additional_pair ? "IA_FG_ADDITIONAL" : "IA_FG_INITIAL");

   bool buy_ok = trade.Buy(lot, _Symbol, 0.0, 0.0, 0.0, tag + "_BUY");
   if(!buy_ok)
   {
      LogMessage("erro ao abrir ordem BUY: " + trade.ResultRetcodeDescription());
      return false;
   }

   bool sell_ok = trade.Sell(lot, _Symbol, 0.0, 0.0, 0.0, tag + "_SELL");
   if(!sell_ok)
   {
      LogMessage("erro ao abrir ordem SELL: " + trade.ResultRetcodeDescription());
      LogMessage("[PAIR_ROLLBACK] SELL falhou, BUY recem-aberto foi fechado para evitar exposicao unilateral.");
      CloseNewestPositionOfType(POSITION_TYPE_BUY);
      return false;
   }

   if(!buy_ok && sell_ok)
   {
      LogMessage("[PAIR_ROLLBACK] BUY falhou, SELL recem-aberto foi fechado para evitar exposicao unilateral.");
      CloseNewestPositionOfType(POSITION_TYPE_SELL);
      return false;
   }

   g_lastPairOpenTime = TimeCurrent();
   g_lastPairCandleTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   g_lastPairMidPrice = MidPrice();

   if(additional_pair)
      LogMessage("abertura de par adicional BUY/SELL.");
   else
      LogMessage("abertura do primeiro par BUY/SELL.");

   return true;
}

void ManageDynamicPendingOrders()
{
   if(!UseDynamicPendingOrders)
   {
      CancelAllPendingOrders();
      return;
   }

   int open_positions = CountOpenPositions();
   if(open_positions <= 0)
   {
      CancelAllPendingOrders();
      return;
   }

   if(open_positions >= LimitOpenPositions())
   {
      CancelAllPendingOrders();
      return;
   }

   if(!IsPendingFiltersOK())
      return;

   RepositionDynamicPendingOrders();

   int pending_total = CountPendingOrders();
   int pending_buy = CountPendingBuyOrders();
   int pending_sell = CountPendingSellOrders();

   bool need_buy = (pending_buy < LimitPendingBuyOrders());
   bool need_sell = (pending_sell < LimitPendingSellOrders());
   int orders_to_add = (need_buy ? 1 : 0) + (need_sell ? 1 : 0);

   if(orders_to_add <= 0)
      return;

   if(pending_total + orders_to_add > LimitPendingOrders())
      return;

   if(!HasExposureRoomIncludingPendings(orders_to_add))
      return;

   if(PendingOrdersCountAsRisk && open_positions + pending_total + orders_to_add > LimitOpenPositions())
      return;

   bool buy_created = false;
   bool sell_created = false;

   if(need_buy)
      buy_created = PlaceDynamicBuyPending();
   if(need_sell)
      sell_created = PlaceDynamicSellPending();

   if(need_buy && need_sell && buy_created != sell_created)
   {
      LogMessage("cancelamento de pendentes por criacao incompleta do par dinamico.");
      CancelAllPendingOrders();
   }
}

bool PlaceDynamicBuyPending()
{
   if(CountPendingBuyOrders() >= LimitPendingBuyOrders())
      return false;

   if(!IsPendingFiltersOK())
      return false;

   ENUM_ORDER_TYPE order_type;
   double price = 0.0;
   if(!GetDesiredPendingOrder(true, order_type, price))
      return false;

   double lot = NormalizeVolume(FixedLot);
   if(lot <= 0.0)
      return false;

   datetime expiration = 0;
   ENUM_ORDER_TYPE_TIME time_type = ORDER_TIME_GTC;
   if(PendingOrderExpirationMinutes > 0)
   {
      expiration = TimeCurrent() + PendingOrderExpirationMinutes * 60;
      time_type = ORDER_TIME_SPECIFIED;
   }

   bool ok = false;
   if(order_type == ORDER_TYPE_BUY_STOP)
      ok = trade.BuyStop(lot, price, _Symbol, 0.0, 0.0, time_type, expiration, "IA_FG_BUY_PENDING");
   else if(order_type == ORDER_TYPE_BUY_LIMIT)
      ok = trade.BuyLimit(lot, price, _Symbol, 0.0, 0.0, time_type, expiration, "IA_FG_BUY_PENDING");

   if(ok)
      LogMessage("criacao de pendente BUY.");
   else
      LogMessage("erro ao criar pendente BUY: " + trade.ResultRetcodeDescription());

   return ok;
}

bool PlaceDynamicSellPending()
{
   if(CountPendingSellOrders() >= LimitPendingSellOrders())
      return false;

   if(!IsPendingFiltersOK())
      return false;

   ENUM_ORDER_TYPE order_type;
   double price = 0.0;
   if(!GetDesiredPendingOrder(false, order_type, price))
      return false;

   double lot = NormalizeVolume(FixedLot);
   if(lot <= 0.0)
      return false;

   datetime expiration = 0;
   ENUM_ORDER_TYPE_TIME time_type = ORDER_TIME_GTC;
   if(PendingOrderExpirationMinutes > 0)
   {
      expiration = TimeCurrent() + PendingOrderExpirationMinutes * 60;
      time_type = ORDER_TIME_SPECIFIED;
   }

   bool ok = false;
   if(order_type == ORDER_TYPE_SELL_STOP)
      ok = trade.SellStop(lot, price, _Symbol, 0.0, 0.0, time_type, expiration, "IA_FG_SELL_PENDING");
   else if(order_type == ORDER_TYPE_SELL_LIMIT)
      ok = trade.SellLimit(lot, price, _Symbol, 0.0, 0.0, time_type, expiration, "IA_FG_SELL_PENDING");

   if(ok)
      LogMessage("criacao de pendente SELL.");
   else
      LogMessage("erro ao criar pendente SELL: " + trade.ResultRetcodeDescription());

   return ok;
}

void RepositionDynamicPendingOrders()
{
   double threshold = (double)MathMax(PendingRepositionStepPoints, Move_step) * _Point;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;

      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != MagicNumber)
         continue;

      ENUM_ORDER_TYPE current_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(!IsPendingOrderType(current_type))
         continue;

      bool buy_side = IsBuyPendingType(current_type);
      ENUM_ORDER_TYPE desired_type;
      double desired_price = 0.0;
      if(!GetDesiredPendingOrder(buy_side, desired_type, desired_price))
         continue;

      double current_price = OrderGetDouble(ORDER_PRICE_OPEN);
      bool wrong_type = (current_type != desired_type);
      bool far_from_target = (MathAbs(current_price - desired_price) >= threshold);

      if(wrong_type || far_from_target)
      {
         if(trade.OrderDelete(ticket))
            LogMessage("cancelamento de pendentes para reposicionamento.");
         else
            LogMessage("erro ao cancelar pendente para reposicionar: " + trade.ResultRetcodeDescription());
      }
   }
}

void CancelInvalidPendingOrders()
{
   int open_positions = CountOpenPositions();

   if(open_positions <= 0 || open_positions >= LimitOpenPositions())
   {
      if(CountPendingOrders() > 0)
         CancelAllPendingOrders();
      return;
   }

   if(!AllowTrading || !IsSpreadOK() || !IsTradingHourOK() || IsNewsBlocked() || g_dailyLossBlocked || g_dailyProfitBlocked || g_basketDDBlocked)
   {
      if(CountPendingOrders() > 0)
         CancelAllPendingOrders();
      return;
   }

   if(open_positions + CountPendingOrders() > LimitOpenPositions())
   {
      CancelAllPendingOrders();
      return;
   }

   bool keep_buy = false;
   bool keep_sell = false;
   int kept_total = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;

      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != MagicNumber)
         continue;

      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(!IsPendingOrderType(type))
         continue;

      datetime expiration = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
      bool expired = (expiration > 0 && expiration <= TimeCurrent());
      bool delete_order = expired;

      if(IsBuyPendingType(type))
      {
         if(keep_buy || kept_total >= LimitPendingOrders())
            delete_order = true;
         else
         {
            keep_buy = true;
            kept_total++;
         }
      }
      else if(IsSellPendingType(type))
      {
         if(keep_sell || kept_total >= LimitPendingOrders())
            delete_order = true;
         else
         {
            keep_sell = true;
            kept_total++;
         }
      }

      if(delete_order)
      {
         if(trade.OrderDelete(ticket))
            LogMessage("cancelamento de pendentes.");
         else
            LogMessage("erro ao cancelar pendente invalida: " + trade.ResultRetcodeDescription());
      }
   }
}

void CancelAllPendingOrders()
{
   bool deleted_any = false;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;

      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != MagicNumber)
         continue;

      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(!IsPendingOrderType(type))
         continue;

      if(trade.OrderDelete(ticket))
         deleted_any = true;
      else
         LogMessage("erro ao cancelar pendente: " + trade.ResultRetcodeDescription());
   }

   if(deleted_any)
      LogMessage("cancelamento de pendentes.");
}

int CountOpenPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(IsOurPositionByIndex(i))
         count++;
   }
   return count;
}

int CountBuyPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!IsOurPositionByIndex(i))
         continue;

      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         count++;
   }
   return count;
}

int CountSellPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!IsOurPositionByIndex(i))
         continue;

      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         count++;
   }
   return count;
}

int CountPairs()
{
   return MathMin(CountBuyPositions(), CountSellPositions());
}

int CountPendingOrders()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(IsOurOrderByIndex(i))
         count++;
   }
   return count;
}

int CountPendingBuyOrders()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!IsOurOrderByIndex(i))
         continue;

      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(IsBuyPendingType(type))
         count++;
   }
   return count;
}

int CountPendingSellOrders()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!IsOurOrderByIndex(i))
         continue;

      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(IsSellPendingType(type))
         count++;
   }
   return count;
}

double GetBasketProfit()
{
   double profit = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!IsOurPositionByIndex(i))
         continue;

      profit += GetSelectedPositionProfitWithCosts();
   }
   return profit;
}

double GetBuyBasketProfit()
{
   double profit = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!IsOurPositionByIndex(i))
         continue;

      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         profit += GetSelectedPositionProfitWithCosts();
   }
   return profit;
}

double GetSellBasketProfit()
{
   double profit = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!IsOurPositionByIndex(i))
         continue;

      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         profit += GetSelectedPositionProfitWithCosts();
   }
   return profit;
}

double GetAverageBuyPrice()
{
   double price_volume = 0.0;
   double volume_sum = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!IsOurPositionByIndex(i))
         continue;

      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      double volume = PositionGetDouble(POSITION_VOLUME);
      price_volume += PositionGetDouble(POSITION_PRICE_OPEN) * volume;
      volume_sum += volume;
   }

   if(volume_sum <= 0.0)
      return 0.0;

   return NormalizePrice(price_volume / volume_sum);
}

double GetAverageSellPrice()
{
   double price_volume = 0.0;
   double volume_sum = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!IsOurPositionByIndex(i))
         continue;

      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
         continue;

      double volume = PositionGetDouble(POSITION_VOLUME);
      price_volume += PositionGetDouble(POSITION_PRICE_OPEN) * volume;
      volume_sum += volume;
   }

   if(volume_sum <= 0.0)
      return 0.0;

   return NormalizePrice(price_volume / volume_sum);
}

double GetBasketAveragePrice()
{
   double price_volume = 0.0;
   double volume_sum = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!IsOurPositionByIndex(i))
         continue;

      double volume = PositionGetDouble(POSITION_VOLUME);
      price_volume += PositionGetDouble(POSITION_PRICE_OPEN) * volume;
      volume_sum += volume;
   }

   if(volume_sum <= 0.0)
      return 0.0;

   return NormalizePrice(price_volume / volume_sum);
}

double GetDynamicBasketClosePrice()
{
   double avg_buy = GetAverageBuyPrice();
   double avg_sell = GetAverageSellPrice();
   double avg_basket = GetBasketAveragePrice();
   double distance = (double)BasketCloseDistancePoints * _Point;

   if(avg_basket <= 0.0)
      return 0.0;

   int bias = 0;
   if(Open_order_on_trend)
   {
      int pa = DetectPriceActionBias();
      int flow = DetectNativeVolumeFlow();
      if(pa != 0 && pa == flow)
         bias = pa;
      else if(pa != 0)
         bias = pa;
      else
         bias = flow;
   }

   if(bias > 0 && avg_buy > 0.0)
      return NormalizePrice(avg_buy + distance);
   if(bias < 0 && avg_sell > 0.0)
      return NormalizePrice(avg_sell - distance);

   if(MidPrice() >= avg_basket)
      return NormalizePrice(avg_basket + distance);

   return NormalizePrice(avg_basket - distance);
}

bool CloseAllBasket()
{
   bool all_ok = true;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;

      if(!trade.PositionClose(ticket, SlippagePoints))
      {
         all_ok = false;
         LogMessage("erro ao fechar ordem: " + trade.ResultRetcodeDescription());
      }
   }

   if(CountOpenPositions() == 0)
   {
      CancelAllPendingOrders();
      g_lastBasketCloseTime = TimeCurrent();
      g_basketDDBlocked = false;
   }

   return all_ok;
}

bool CloseBuyBasket()
{
   bool all_ok = true;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      if(!trade.PositionClose(ticket, SlippagePoints))
      {
         all_ok = false;
         LogMessage("erro ao fechar ordem BUY: " + trade.ResultRetcodeDescription());
      }
   }

   if(CountOpenPositions() == 0)
   {
      CancelAllPendingOrders();
      g_lastBasketCloseTime = TimeCurrent();
      g_basketDDBlocked = false;
   }

   return all_ok;
}

bool CloseSellBasket()
{
   bool all_ok = true;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
         continue;

      if(!trade.PositionClose(ticket, SlippagePoints))
      {
         all_ok = false;
         LogMessage("erro ao fechar ordem SELL: " + trade.ResultRetcodeDescription());
      }
   }

   if(CountOpenPositions() == 0)
   {
      CancelAllPendingOrders();
      g_lastBasketCloseTime = TimeCurrent();
      g_basketDDBlocked = false;
   }

   return all_ok;
}

void ManageBasketClosing()
{
   if(!UseBasketProfitClose)
      return;

   int buys = CountBuyPositions();
   int sells = CountSellPositions();
   int total = buys + sells;
   if(total <= 0)
      return;

   double basket_profit = GetBasketProfit();

   if(buys > 0 && sells > 0)
   {
      if(basket_profit >= BasketCloseTargetTwoDirections())
      {
         LogMessage("fechamento por lucro USD.");
         CloseAllBasket();
      }
      return;
   }

   if(buys > 0 && GetBuyBasketProfit() >= BasketCloseTargetOneDirection())
   {
      LogMessage("fechamento por lucro USD em BUY.");
      CloseBuyBasket();
      return;
   }

   if(sells > 0 && GetSellBasketProfit() >= BasketCloseTargetOneDirection())
   {
      LogMessage("fechamento por lucro USD em SELL.");
      CloseSellBasket();
   }
}

void ManagePriceBasedBasketClosing()
{
   if(!UsePriceBasedBasketClose)
      return;

   if(CountOpenPositions() <= 0)
      return;

   double profit = GetBasketProfit();
   if(profit <= 0.0 || profit < BasketProfitUSD_MinConfirm)
      return;

   double distance = (double)BasketCloseDistancePoints * _Point;
   double avg_buy = GetAverageBuyPrice();
   double avg_sell = GetAverageSellPrice();
   double target = GetDynamicBasketClosePrice();
   double avg_basket = GetBasketAveragePrice();
   bool touched = false;

   if(avg_buy > 0.0 && g_tick.bid >= NormalizePrice(avg_buy + distance))
      touched = true;

   if(avg_sell > 0.0 && g_tick.ask <= NormalizePrice(avg_sell - distance))
      touched = true;

   if(target > 0.0 && avg_basket > 0.0)
   {
      if(target >= avg_basket && g_tick.bid >= target)
         touched = true;
      if(target < avg_basket && g_tick.ask <= target)
         touched = true;
   }

   if(touched)
   {
      LogMessage("fechamento por linha dinamica.");
      CloseAllBasket();
   }
}

bool BuildBreakEvenSLCandidate(ENUM_POSITION_TYPE type,
                              double legacy_profit,
                              double open_price,
                              double volume,
                              double current_sl,
                              double &candidate_sl)
{
   candidate_sl = 0.0;
   if(!UseBreakEven || legacy_profit < BreakEvenStartUSD || legacy_profit <= 0.0)
      return false;

   double lock_distance = USDToPriceDistance(BreakEvenLockUSD, volume);
   if(lock_distance <= 0.0)
      return false;

   if(type == POSITION_TYPE_BUY)
   {
      candidate_sl = NormalizePrice(open_price + lock_distance);
      if(candidate_sl <= open_price || (current_sl > 0.0 && candidate_sl <= current_sl))
         return false;
   }
   else
   {
      candidate_sl = NormalizePrice(open_price - lock_distance);
      if(candidate_sl >= open_price || (current_sl > 0.0 && candidate_sl >= current_sl))
         return false;
   }

   return (candidate_sl > 0.0);
}

bool BuildSmartTrailingSLCandidate(ENUM_POSITION_TYPE type,
                                  double legacy_profit,
                                  double open_price,
                                  double volume,
                                  double current_sl,
                                  double &candidate_sl)
{
   candidate_sl = 0.0;
   if(!UseSmartTrailing || Trailing_type == 0)
      return false;
   if(legacy_profit < Minimum_trailing_profit || legacy_profit <= 0.0)
      return false;

   double stop_distance = USDToPriceDistance(Trailing_stop, volume);
   double step_distance = USDToPriceDistance(Trailing_step, volume);
   if(stop_distance <= 0.0 || step_distance <= 0.0)
      return false;

   if(Trailing_type == 1)
   {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int copied = CopyRates(_Symbol, Timeframe_fractals_or_candles, 0, 6, rates);
      if(copied >= 4)
      {
         if(type == POSITION_TYPE_BUY)
         {
            double low = rates[1].low;
            for(int b = 2; b < copied && b <= 4; b++)
               low = MathMin(low, rates[b].low);
            candidate_sl = NormalizePrice(low - (double)Padding_by_fractals_or_candles * _Point);
         }
         else
         {
            double high = rates[1].high;
            for(int b = 2; b < copied && b <= 4; b++)
               high = MathMax(high, rates[b].high);
            candidate_sl = NormalizePrice(high + (double)Padding_by_fractals_or_candles * _Point);
         }
      }
   }
   else if(Trailing_type == 2)
   {
      double basket_avg = GetBasketAveragePrice();
      if(basket_avg > 0.0)
      {
         if(type == POSITION_TYPE_BUY)
            candidate_sl = NormalizePrice(MathMax(open_price, basket_avg) + step_distance);
         else
            candidate_sl = NormalizePrice(MathMin(open_price, basket_avg) - step_distance);
      }
   }
   else if(Trailing_type == 3)
   {
      if(type == POSITION_TYPE_BUY)
         candidate_sl = NormalizePrice(g_tick.bid - stop_distance);
      else
         candidate_sl = NormalizePrice(g_tick.ask + stop_distance);
   }

   if(candidate_sl <= 0.0)
   {
      if(type == POSITION_TYPE_BUY)
         candidate_sl = NormalizePrice(g_tick.bid - stop_distance);
      else
         candidate_sl = NormalizePrice(g_tick.ask + stop_distance);
   }

   if(type == POSITION_TYPE_BUY)
   {
      if(candidate_sl <= open_price)
         return false;
      if(current_sl > 0.0 && candidate_sl <= current_sl + step_distance)
         return false;
   }
   else
   {
      if(candidate_sl >= open_price)
         return false;
      if(current_sl > 0.0 && candidate_sl >= current_sl - step_distance)
         return false;
   }

   return (candidate_sl > 0.0);
}

void ManageBasketDrawdown()
{
   if(CountOpenPositions() <= 0)
   {
      g_basketDDBlocked = false;
      return;
   }

   double profit = GetBasketProfit();
   double block_loss = MathAbs(Maximum_allowed_loss);
   double close_loss = MathAbs(Loss_for_closing);
   if(close_loss <= 0.0)
      close_loss = block_loss;

   if(block_loss > 0.0 && profit <= -block_loss)
   {
      g_basketDDBlocked = true;
      SetStatus("DD BLOQUEADO", "bloqueio por DD");
   }

   if(Close_loss_by_drawdown && close_loss > 0.0 && profit <= -close_loss)
   {
      LogMessage("fechamento por DD maximo da cesta.");
      CloseAllBasket();
   }
}

void ManageDailyRisk()
{
   RecalculateDailyResult();

   if(MaxDailyLossUSD <= 0.0)
      return;

   if(g_dailyResult <= -MathAbs(MaxDailyLossUSD))
   {
      if(StopTradingAfterDailyLoss)
         ActivateDailyLossBlock("bloqueio por loss diario");

      if(ClosePositionsAtDailyLoss && CountOpenPositions() > 0)
      {
         LogMessage("fechamento por loss diario.");
         CloseAllBasket();
      }
   }
}

void ManageDailyProfitTarget()
{
   RecalculateDailyResult();

   if(DailyProfitTargetUSD <= 0.0)
      return;

   if(g_dailyResult >= DailyProfitTargetUSD)
   {
      if(StopTradingAfterDailyProfit)
         ActivateDailyProfitBlock("meta diaria atingida");
      else
         SetStatus("META BATIDA");
   }
}

void ResetarPicoLucroCesta()
{
   g_PicoLucroCestaUSD = 0.0;
   g_FechamentoMFECestaEmAndamento = false;

   if(EnableLogs)
      Print("[BASKET_MFE_RESET] pico_lucro_cesta=0.00");
}

void AtualizarPicoLucroCesta()
{
   int posicoesAbertas = CountOpenPositions();

   if(posicoesAbertas <= 0)
   {
      if(g_PicoLucroCestaUSD != 0.0 || g_FechamentoMFECestaEmAndamento)
         ResetarPicoLucroCesta();

      return;
   }

   double lucroAtualCesta = GetBasketProfit();

   if(lucroAtualCesta > g_PicoLucroCestaUSD)
   {
      g_PicoLucroCestaUSD = lucroAtualCesta;

      if(EnableLogs)
         Print("[BASKET_MFE_UPDATE] pico=", DoubleToString(g_PicoLucroCestaUSD, 2),
               " atual=", DoubleToString(lucroAtualCesta, 2),
               " posicoes=", posicoesAbertas);
   }
}

bool GerenciarProtecaoLucroCestaMFE()
{
   if(!UsarProtecaoLucroCesta)
      return false;

   int posicoesAbertas = CountOpenPositions();

   if(posicoesAbertas <= 0)
   {
      if(g_PicoLucroCestaUSD != 0.0 || g_FechamentoMFECestaEmAndamento)
         ResetarPicoLucroCesta();

      return false;
   }

   if(g_FechamentoMFECestaEmAndamento)
      return true;

   double lucroAtualCesta = GetBasketProfit();

   if(g_PicoLucroCestaUSD >= FechamentoFortePicoCestaUSD)
   {
      g_FechamentoMFECestaEmAndamento = true;

      if(EnableLogs)
         Print("[BASKET_MFE_HARD_CLOSE] pico=", DoubleToString(g_PicoLucroCestaUSD, 2),
               " atual=", DoubleToString(lucroAtualCesta, 2),
               " gatilho=", DoubleToString(FechamentoFortePicoCestaUSD, 2),
               " posicoes=", posicoesAbertas);

      bool fechou = CloseAllBasket();

      if(!fechou)
      {
         g_FechamentoMFECestaEmAndamento = false;

         if(EnableLogs)
            Print("[BASKET_MFE_CLOSE_FAIL] motivo=HARD_CLOSE",
                  " pico=", DoubleToString(g_PicoLucroCestaUSD, 2),
                  " atual=", DoubleToString(lucroAtualCesta, 2),
                  " posicoes=", CountOpenPositions());
      }

      return fechou;
   }

   if(g_PicoLucroCestaUSD >= PicoMinimoLucroCestaUSD &&
      lucroAtualCesta <= LucroProtegidoAposPicoUSD &&
      lucroAtualCesta > 0.0)
   {
      g_FechamentoMFECestaEmAndamento = true;

      if(EnableLogs)
         Print("[BASKET_MFE_LOCK_CLOSE] pico=", DoubleToString(g_PicoLucroCestaUSD, 2),
               " atual=", DoubleToString(lucroAtualCesta, 2),
               " lock=", DoubleToString(LucroProtegidoAposPicoUSD, 2),
               " inicio=", DoubleToString(PicoMinimoLucroCestaUSD, 2),
               " posicoes=", posicoesAbertas);

      bool fechou = CloseAllBasket();

      if(!fechou)
      {
         g_FechamentoMFECestaEmAndamento = false;

         if(EnableLogs)
            Print("[BASKET_MFE_CLOSE_FAIL] motivo=LOCK_CLOSE",
                  " pico=", DoubleToString(g_PicoLucroCestaUSD, 2),
                  " atual=", DoubleToString(lucroAtualCesta, 2),
                  " posicoes=", CountOpenPositions());
      }

      return fechou;
   }

   return false;
}

double USDToPriceDistance(double usd, double volume)
{
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(usd <= 0.0 || volume <= 0.0 || tick_value <= 0.0 || tick_size <= 0.0)
      return 0.0;

   return MathAbs(usd) / (tick_value * volume) * tick_size;
}

void DrawBasketLines()
{
   if(!DrawBasketPriceLines || CountOpenPositions() <= 0)
   {
      DeleteBasketLines();
      return;
   }

   double avg_buy = GetAverageBuyPrice();
   double avg_sell = GetAverageSellPrice();
   double avg_basket = GetBasketAveragePrice();
   double close_target = GetDynamicBasketClosePrice();
   double profit_zone = 0.0;

   if(close_target > 0.0 && avg_basket > 0.0)
   {
      double half_distance = (double)BasketCloseDistancePoints * _Point * 0.5;
      profit_zone = (close_target >= avg_basket ? close_target - half_distance : close_target + half_distance);
      profit_zone = NormalizePrice(profit_zone);
   }

   DrawOrUpdateLine(LINE_AVG_BUY, avg_buy, clrDodgerBlue, STYLE_SOLID);
   DrawOrUpdateLine(LINE_AVG_SELL, avg_sell, clrTomato, STYLE_SOLID);
   DrawOrUpdateLine(LINE_AVG_BASKET, avg_basket, clrGold, STYLE_DASH);
   DrawOrUpdateLine(LINE_CLOSE_TARGET, close_target, clrLimeGreen, STYLE_SOLID);
   DrawOrUpdateLine(LINE_PROFIT_ZONE, profit_zone, clrPaleGreen, STYLE_DOT);
}

void DeleteBasketLines()
{
   ObjectDelete(0, LINE_AVG_BUY);
   ObjectDelete(0, LINE_AVG_SELL);
   ObjectDelete(0, LINE_AVG_BASKET);
   ObjectDelete(0, LINE_CLOSE_TARGET);
   ObjectDelete(0, LINE_PROFIT_ZONE);
}

void UpdatePanel()
{
   if(!UsePanel)
   {
      Comment("");
      return;
   }

   int pa = DetectPriceActionBias();
   int flow = DetectNativeVolumeFlow();
   double basket_profit = GetBasketProfit();
   double closed_profit = GetTodayClosedProfit();
   double daily_total = closed_profit + basket_profit;
   g_dailyResult = daily_total;
   double basket_dd = (basket_profit < 0.0 ? MathAbs(basket_profit) : 0.0);
   double distance = DistanceFromLastPairPoints();
   double required = (UseAsymmetricBilateralFlowEngine ?
                      RequiredAdaptiveEntryDistancePoints() :
                      RequiredAdditionalDistancePoints());
   double remaining_distance = MathMax(0.0, required - distance);
   datetime server_time = (g_lastServerTime > 0 ? g_lastServerTime : GetOperationalServerTime());
   datetime next_reset = (g_currentDayStart > 0 ? g_currentDayStart + 86400 : 0);
   int seconds_since_pair = (g_lastPairOpenTime > 0 && server_time > 0 ? (int)(server_time - g_lastPairOpenTime) : 0);
   string tick_age = (g_lastTickAgeSeconds >= 0 ? IntegerToString(g_lastTickAgeSeconds) + "s" : "n/d");
   string status = ComputePanelStatus();
   string engine_mode = (UseAsymmetricBilateralFlowEngine ? "ADAPTATIVO ASSIMETRICO" : "LEGADO");
   string tactical_episode = TacticalEpisodeStateToText();
   string tactical_execution = IntegerToString(g_tacticalEntryCount);
   int current_buy_limit = (UseAsymmetricBilateralFlowEngine ? GetDynamicBuyLimit() : LimitBuyPositions());
   int current_sell_limit = (UseAsymmetricBilateralFlowEngine ? GetDynamicSellLimit() : LimitSellPositions());
   string adaptive_reason = (g_adaptiveBlockReason == "" ? "SEM BLOQUEIO" : g_adaptiveBlockReason);

   string panel =
      EA_NAME + "\n" +
      "Simbolo: " + _Symbol + "\n" +
      "Timeframe: " + EnumToString((ENUM_TIMEFRAMES)_Period) + "\n" +
      "Conta: " + (IsHedgingAccount() ? "HEDGE" : "NETTING") + "\n" +
      "Modo: " + engine_mode + "\n" +
      "Hora servidor: " + FormatServerTime(server_time) + "\n" +
      "Inicio dia operacional: " + FormatServerTime(g_currentDayStart) + "\n" +
      "Proximo reset diario: " + FormatServerTime(next_reset) + "\n" +
      "Spread ultimo tick: " + DoubleToString(GetCurrentSpreadPoints(), 1) + " pontos\n" +
      "Estado da sessao do simbolo: " + g_symbolSessionState + "\n" +
      "Ultimo tick real: " + FormatServerTime(g_lastRealTickTime) + "\n" +
      "Idade ultimo tick: " + tick_age + "\n" +
      "Price Action Bias: " + BiasToText(pa, "ALTA", "QUEDA") + "\n" +
      "Volume Flow: " + BiasToText(flow, "COMPRADOR", "VENDEDOR") + "\n" +
      "Fluxo estrutural: " + StructuralFlowToText() + "\n" +
      "Microfluxo: " + TacticalFlowToText() + "\n" +
      "Episodio tatico: " + tactical_episode + "\n" +
      "Entradas taticas confirmadas: " + tactical_execution + "\n" +
      "Limites BUY/SELL: " + IntegerToString(current_buy_limit) + " / " + IntegerToString(current_sell_limit) + "\n" +
      "Pares abertos: " + IntegerToString(CountPairs()) + "\n" +
      "BUYs abertas: " + IntegerToString(CountBuyPositions()) + "\n" +
      "SELLs abertas: " + IntegerToString(CountSellPositions()) + "\n" +
      "Posicoes totais: " + IntegerToString(CountOpenPositions()) + "\n" +
      "Pendentes BUY: " + IntegerToString(CountPendingBuyOrders()) + "\n" +
      "Pendentes SELL: " + IntegerToString(CountPendingSellOrders()) + "\n" +
      "Pendentes totais: " + IntegerToString(CountPendingOrders()) + "\n" +
      "Exposicao potencial BUY: " + IntegerToString(CountPotentialBuyExposure()) + "\n" +
      "Exposicao potencial SELL: " + IntegerToString(CountPotentialSellExposure()) + "\n" +
      "Exposicao potencial total: " + IntegerToString(CountPotentialTotalExposure()) + "\n" +
      "Lucro da cesta: " + DoubleToString(basket_profit, 2) + " USD\n" +
      "Pico Lucro Cesta: " + DoubleToString(g_PicoLucroCestaUSD, 2) + " USD\n" +
      "DD da cesta: " + DoubleToString(basket_dd, 2) + " USD\n" +
      "Lucro diario: " + DoubleToString(daily_total, 2) + " USD\n" +
      "Resultado fechado do dia: " + DoubleToString(closed_profit, 2) + " USD\n" +
      "Resultado flutuante atual: " + DoubleToString(basket_profit, 2) + " USD\n" +
      "Resultado diario total: " + DoubleToString(daily_total, 2) + " USD\n" +
      "Loss diario bloqueado: " + BoolToSimNao(g_dailyLossBlocked) + "\n" +
      "Meta diaria bloqueada: " + BoolToSimNao(g_dailyProfitBlocked) + "\n" +
      "DD da cesta bloqueado: " + BoolToSimNao(g_basketDDBlocked) + "\n" +
      "Preco medio BUY: " + DoubleToString(GetAverageBuyPrice(), _Digits) + "\n" +
      "Preco medio SELL: " + DoubleToString(GetAverageSellPrice(), _Digits) + "\n" +
      "Preco medio geral: " + DoubleToString(GetBasketAveragePrice(), _Digits) + "\n" +
      "Preco alvo de fechamento: " + DoubleToString(GetDynamicBasketClosePrice(), _Digits) + "\n" +
      "Distancia ate proximo par: " + DoubleToString(remaining_distance, 1) + " pontos\n" +
      "Tempo desde ultimo par: " + IntegerToString(seconds_since_pair) + "s\n" +
      "Ultima acao: " + g_adaptiveLastAction + "\n" +
      "Motivo do bloqueio adaptativo: " + adaptive_reason + "\n" +
      "Motivo operacional atual: " + status + "\n" +
      "Status operacional: " + status;

   Comment(panel);
}

void LogMessage(string msg)
{
   if(!EnableLogs)
      return;

   datetime now = GetOperationalServerTime();
   if(now <= 0)
      now = TimeCurrent();
   if(msg == g_lastLogMessage && now - g_lastLogTime < 10)
      return;

   Print("[", EA_NAME, "] ", msg);
   g_lastLogMessage = msg;
   g_lastLogTime = now;
}

bool UpdateSymbolData(bool real_tick)
{
   MqlTick latest_tick;
   if(!SymbolInfoTick(_Symbol, latest_tick))
      return false;

   datetime previous_tick = g_lastRealTickTime;
   g_tick = latest_tick;

   if(real_tick && latest_tick.time > 0)
   {
      g_lastRealTickTime = (datetime)latest_tick.time;
      if(g_waitingFirstTickAfterReopen && previous_tick > 0 && g_lastRealTickTime >= previous_tick)
         LogMessage("primeiro tick recebido apos reabertura.");
      g_waitingFirstTickAfterReopen = false;
   }

   UpdateMarketDiagnostics();
   return true;
}

void UpdateMarketDiagnostics()
{
   datetime server_time = GetOperationalServerTime();
   if(server_time > 0)
      g_lastServerTime = server_time;

   g_terminalConnected = (TerminalInfoInteger(TERMINAL_CONNECTED) != 0);

   long trade_mode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   g_symbolTradingEnabled = (trade_mode == SYMBOL_TRADE_MODE_FULL ||
                             trade_mode == SYMBOL_TRADE_MODE_LONGONLY ||
                             trade_mode == SYMBOL_TRADE_MODE_SHORTONLY);

   if(g_lastRealTickTime > 0 && server_time > 0)
      g_lastTickAgeSeconds = MathMax(0, (int)(server_time - g_lastRealTickTime));
   else
      g_lastTickAgeSeconds = -1;

   bool session_known = false;
   bool session_open = false;
   string previous_state = g_symbolSessionState;
   string session_state = GetSymbolSessionState(server_time, session_known, session_open);

   if(!g_terminalConnected)
      session_state = "TERMINAL DESCONECTADO";
   else if(session_known && session_open)
   {
      if(g_lastRealTickTime <= 0)
         session_state = "AGUARDANDO PRIMEIRO TICK";
      else if(g_lastTickAgeSeconds > STALE_TICK_SECONDS)
         session_state = "SEM TICKS";
      else
         session_state = "MERCADO ABERTO";
   }

   if(session_state != previous_state)
   {
      if(session_state == "MERCADO FECHADO")
         LogMessage("sessao do simbolo fechada.");
      else if(session_state == "SEM TICKS")
         LogMessage("sem ticks recentes do simbolo.");
      else if(session_state == "MERCADO ABERTO" && previous_state != "")
         LogMessage("sessao do simbolo aberta.");
   }

   if(session_state == "MERCADO FECHADO" || session_state == "SEM TICKS" || session_state == "AGUARDANDO PRIMEIRO TICK")
      g_waitingFirstTickAfterReopen = true;

   g_symbolSessionState = session_state;
}

datetime GetOperationalServerTime()
{
   bool connected = (TerminalInfoInteger(TERMINAL_CONNECTED) != 0);
   datetime trade_server_time = TimeTradeServer();
   if(connected && trade_server_time > 0)
      return trade_server_time;

   datetime current_time = TimeCurrent();
   if(current_time > 0)
      return current_time;

   return 0;
}

datetime GetServerDayStart(datetime server_time)
{
   if(server_time <= 0)
      return 0;

   MqlDateTime dt;
   TimeToStruct(server_time, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
}

int SecondsFromMidnight(datetime value)
{
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.hour * 3600 + dt.min * 60 + dt.sec;
}

string FormatServerTime(datetime value)
{
   if(value <= 0)
      return "n/d";
   return TimeToString(value, TIME_DATE | TIME_SECONDS);
}

string BoolToSimNao(bool value)
{
   return (value ? "SIM" : "NAO");
}

string GetSymbolSessionState(datetime server_time, bool &session_known, bool &session_open)
{
   session_known = false;
   session_open = false;

   if(server_time <= 0)
      return "SESSAO INDETERMINADA";

   MqlDateTime dt;
   TimeToStruct(server_time, dt);
   int now_seconds = dt.hour * 3600 + dt.min * 60 + dt.sec;

   datetime session_from;
   datetime session_to;
   for(uint i = 0; i < 24; i++)
   {
      if(!SymbolInfoSessionTrade(_Symbol, (ENUM_DAY_OF_WEEK)dt.day_of_week, i, session_from, session_to))
         break;

      session_known = true;
      int from_seconds = SecondsFromMidnight(session_from);
      int to_seconds = SecondsFromMidnight(session_to);

      bool open_now = false;
      if(from_seconds == to_seconds)
         open_now = true;
      else if(from_seconds < to_seconds)
         open_now = (now_seconds >= from_seconds && now_seconds < to_seconds);
      else
         open_now = (now_seconds >= from_seconds || now_seconds < to_seconds);

      if(open_now)
      {
         session_open = true;
         return "MERCADO ABERTO";
      }
   }

   if(session_known)
      return "MERCADO FECHADO";

   return "SESSAO INDETERMINADA";
}

void RecalculateDailyResult()
{
   g_dailyResult = GetTodayClosedProfit() + GetBasketProfit();
}

void ActivateDailyLossBlock(string log_reason="")
{
   if(!StopTradingAfterDailyLoss)
      return;

   bool was_blocked = g_dailyLossBlocked;
   g_dailyLossBlocked = true;
   PersistDailyLossBlock();

   if(!was_blocked && log_reason != "")
      SetStatus("LOSS DIARIO", log_reason);
   else
      g_status = "LOSS DIARIO";
}

void ActivateDailyProfitBlock(string log_reason="")
{
   if(!StopTradingAfterDailyProfit)
      return;

   bool was_blocked = g_dailyProfitBlocked;
   g_dailyProfitBlocked = true;

   if(!was_blocked && log_reason != "")
      SetStatus("META BATIDA", log_reason);
   else
      g_status = "META BATIDA";
}

string DailyLossBlockGlobalName()
{
   return "IA_FG_DAILY_LOSS_BLOCK_" + _Symbol + "_" + IntegerToString(MagicNumber);
}

bool IsPersistedDailyLossBlockCurrent()
{
   if(g_currentDayStart <= 0)
      return false;

   string name = DailyLossBlockGlobalName();
   if(!GlobalVariableCheck(name))
      return false;

   datetime stored_day = (datetime)GlobalVariableGet(name);
   if(stored_day == g_currentDayStart)
      return true;

   GlobalVariableDel(name);
   return false;
}

void PersistDailyLossBlock()
{
   if(g_currentDayStart <= 0)
      return;

   GlobalVariableSet(DailyLossBlockGlobalName(), (double)g_currentDayStart);
}

void ClearDailyLossBlock()
{
   string name = DailyLossBlockGlobalName();
   if(GlobalVariableCheck(name))
      GlobalVariableDel(name);
}

void RefreshDailyState()
{
   if(g_dailyStateBusy)
      return;

   g_dailyStateBusy = true;

   datetime server_time = GetOperationalServerTime();
   if(server_time > 0)
      g_lastServerTime = server_time;

   if(server_time <= 0)
   {
      g_dailyStateBusy = false;
      return;
   }

   datetime day_start = GetServerDayStart(server_time);
   if(day_start <= 0)
   {
      g_dailyStateBusy = false;
      return;
   }

   bool first_day = (g_currentDayStart <= 0);
   bool day_changed = (!first_day && g_currentDayStart != day_start);

   if(first_day || day_changed)
   {
      if(day_changed)
      {
         bool was_loss_blocked = g_dailyLossBlocked;
         g_dailyLossBlocked = false;
         g_dailyProfitBlocked = false;
         g_dailyResult = 0.0;
         ClearDailyLossBlock();
         if(was_loss_blocked)
            LogMessage("bloqueio diario removido por mudanca de dia do servidor.");
         LogMessage("novo dia operacional iniciado.");
      }

      g_currentDayStart = day_start;
   }

   RecalculateDailyResult();

   if(StopTradingAfterDailyLoss && MaxDailyLossUSD > 0.0)
   {
      if(g_dailyResult <= -MathAbs(MaxDailyLossUSD) || IsPersistedDailyLossBlockCurrent())
         ActivateDailyLossBlock("bloqueio por loss diario");
   }

   if(StopTradingAfterDailyProfit && DailyProfitTargetUSD > 0.0 && g_dailyResult >= DailyProfitTargetUSD)
      ActivateDailyProfitBlock("meta diaria atingida");

   g_dailyStateBusy = false;
}

double GetTodayClosedProfit()
{
   double result = 0.0;
   if(g_currentDayStart <= 0)
      return result;

   datetime to = GetOperationalServerTime();
   if(to <= 0)
      return result;

   if(!HistorySelect(g_currentDayStart, to))
      return result;

   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;

      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      if((long)HistoryDealGetInteger(deal, DEAL_MAGIC) != MagicNumber)
         continue;

      result += HistoryDealGetDouble(deal, DEAL_PROFIT);
      result += HistoryDealGetDouble(deal, DEAL_SWAP);
      result += HistoryDealGetDouble(deal, DEAL_COMMISSION);
   }

   return result;
}

double GetSelectedPositionProfitWithCosts()
{
   long position_id = (long)PositionGetInteger(POSITION_IDENTIFIER);
   double profit = PositionGetDouble(POSITION_PROFIT);
   double swap = PositionGetDouble(POSITION_SWAP);
   double commission = GetPositionCommissionByIdentifier(position_id);
   return profit + swap + commission;
}

double GetPositionCommissionByIdentifier(long position_id)
{
   if(position_id <= 0)
      return 0.0;

   double commission = 0.0;
   datetime from = 0;
   datetime to = TimeCurrent();

   if(!HistorySelect(from, to))
      return 0.0;

   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;

      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      if((long)HistoryDealGetInteger(deal, DEAL_MAGIC) != MagicNumber)
         continue;
      if((long)HistoryDealGetInteger(deal, DEAL_POSITION_ID) != position_id)
         continue;

      commission += HistoryDealGetDouble(deal, DEAL_COMMISSION);
   }

   return commission;
}

double GetCurrentSpreadPoints()
{
   if(g_tick.ask <= 0.0 || g_tick.bid <= 0.0 || _Point <= 0.0)
      return 0.0;

   return (g_tick.ask - g_tick.bid) / _Point;
}

double NormalizePrice(double price)
{
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, _Digits);
}

double NormalizeVolume(double volume)
{
   double min_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(volume <= 0.0 || min_volume <= 0.0 || max_volume <= 0.0 || step <= 0.0)
      return 0.0;

   if(volume < min_volume || volume > max_volume)
      return 0.0;

   double normalized = MathFloor((volume / step) + 0.0000001) * step;
   int digits = 0;
   double tmp = step;
   while(tmp < 1.0 && digits < 8)
   {
      tmp *= 10.0;
      digits++;
   }

   normalized = NormalizeDouble(normalized, digits);
   if(normalized < min_volume)
      return 0.0;

   return normalized;
}

double MinTradeDistancePrice()
{
   int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   int freeze_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   int points = MathMax(stops_level, freeze_level) + 2;
   return (double)MathMax(points, 2) * _Point;
}

bool IsOurPositionByIndex(int index)
{
   ulong ticket = PositionGetTicket(index);
   if(ticket == 0)
      return false;

   if(PositionGetString(POSITION_SYMBOL) != _Symbol)
      return false;

   if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
      return false;

   return true;
}

bool IsOurOrderByIndex(int index)
{
   ulong ticket = OrderGetTicket(index);
   if(ticket == 0)
      return false;

   if(OrderGetString(ORDER_SYMBOL) != _Symbol)
      return false;

   if((long)OrderGetInteger(ORDER_MAGIC) != MagicNumber)
      return false;

   return IsPendingOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE));
}

bool IsPendingOrderType(ENUM_ORDER_TYPE type)
{
   return (type == ORDER_TYPE_BUY_LIMIT ||
           type == ORDER_TYPE_SELL_LIMIT ||
           type == ORDER_TYPE_BUY_STOP ||
           type == ORDER_TYPE_SELL_STOP);
}

bool IsBuyPendingType(ENUM_ORDER_TYPE type)
{
   return (type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_BUY_STOP);
}

bool IsSellPendingType(ENUM_ORDER_TYPE type)
{
   return (type == ORDER_TYPE_SELL_LIMIT || type == ORDER_TYPE_SELL_STOP);
}

int LimitOpenPositions()
{
   return MathMax(0, (int)MathMin((double)MaxOpenPositions, 8.0));
}

int LimitBuyPositions()
{
   return MathMax(0, (int)MathMin((double)MaxBuyPositions, 4.0));
}

int LimitSellPositions()
{
   return MathMax(0, (int)MathMin((double)MaxSellPositions, 4.0));
}

int LimitPairs()
{
   return MathMax(0, (int)MathMin((double)MaxPairs, 4.0));
}

int LimitPendingOrders()
{
   return MathMax(0, (int)MathMin((double)MaxPendingOrders, 2.0));
}

int LimitPendingBuyOrders()
{
   return MathMax(0, (int)MathMin((double)MaxPendingBuyOrders, 1.0));
}

int LimitPendingSellOrders()
{
   return MathMax(0, (int)MathMin((double)MaxPendingSellOrders, 1.0));
}

bool HasExposureRoomIncludingPendings(int additionalOrders)
{
   return (CountOpenPositions() + CountPendingOrders() + additionalOrders <= LimitOpenPositions());
}

bool HasExposureRoomFor(int positions_to_add)
{
   int exposure = CountOpenPositions();
   if(PendingOrdersCountAsRisk)
      exposure += CountPendingOrders();

   return (exposure + positions_to_add <= LimitOpenPositions() && HasExposureRoomIncludingPendings(positions_to_add));
}

bool BaseEntryFiltersOK()
{
   if(!AllowTrading)
      return false;

   if(!Allow_BUY || !Allow_SELL)
   {
      SetStatus("OPERANDO", "operacao bloqueada porque BUY ou SELL esta desativado");
      return false;
   }

   if(!IsSpreadOK())
   {
      SetStatus("SPREAD ALTO", "bloqueio por spread");
      return false;
   }

   if(!IsTradingHourOK())
   {
      SetStatus("HORARIO BLOQUEADO", "bloqueio por horario");
      return false;
   }

   if(IsNewsBlocked())
   {
      SetStatus("NEWS BLOCK V2", "bloqueio por noticia");
      return false;
   }

   if(g_dailyLossBlocked)
   {
      SetStatus("LOSS DIARIO", "bloqueio por loss diario");
      return false;
   }

   if(g_dailyProfitBlocked)
   {
      SetStatus("META BATIDA", "meta diaria atingida");
      return false;
   }

   if(g_basketDDBlocked)
   {
      SetStatus("DD BLOQUEADO", "bloqueio por DD");
      return false;
   }

   return true;
}

double MidPrice()
{
   if(g_tick.bid <= 0.0 || g_tick.ask <= 0.0)
      return SymbolInfoDouble(_Symbol, SYMBOL_BID);

   return (g_tick.bid + g_tick.ask) * 0.5;
}

double DistanceFromLastPairPoints()
{
   if(g_lastPairMidPrice <= 0.0 || _Point <= 0.0)
      return 0.0;

   return MathAbs(MidPrice() - g_lastPairMidPrice) / _Point;
}

double RequiredAdditionalDistancePoints()
{
   double required = (double)MathMax(Distance_between_orders, Minimum_price_distance);
   if(CountPairs() <= 1)
      required = MathMax(required, (double)First_step);
   return MathMax(required, 0.0);
}

double BasketCloseTargetTwoDirections()
{
   if(!Auto_calculated_profit)
      return Profit_for_closing_2_directions;

   return MathMax(Profit_for_closing_2_directions, Profit_for_closing_2_directions * (double)MathMax(1, CountPairs()));
}

double BasketCloseTargetOneDirection()
{
   if(!Auto_calculated_profit)
      return Profit_for_closing_1_direction;

   int directional_count = MathMax(CountBuyPositions(), CountSellPositions());
   return MathMax(Profit_for_closing_1_direction, Profit_for_closing_1_direction * (double)MathMax(1, directional_count));
}

bool GetDesiredPendingOrder(bool buy_side, ENUM_ORDER_TYPE &order_type, double &price)
{
   if(!UpdateSymbolData(false))
      return false;

   int pressure = 0;
   if(Open_order_on_trend)
   {
      int pa = DetectPriceActionBias();
      int flow = DetectNativeVolumeFlow();
      if(pa != 0 && pa == flow)
         pressure = pa;
      else if(pa != 0)
         pressure = pa;
      else
         pressure = flow;
   }

   double raw_distance = (double)MathMax(PendingOrderDistancePoints, 1) * _Point;
   double min_distance = MinTradeDistancePrice();
   double distance = MathMax(raw_distance, min_distance);

   if(buy_side)
   {
      if(pressure < 0)
      {
         order_type = ORDER_TYPE_BUY_LIMIT;
         price = g_tick.bid - distance;
         if(price >= g_tick.ask - min_distance)
            price = g_tick.ask - min_distance;
      }
      else
      {
         order_type = ORDER_TYPE_BUY_STOP;
         price = g_tick.ask + distance;
         if(price <= g_tick.ask + min_distance)
            price = g_tick.ask + min_distance;
      }
   }
   else
   {
      if(pressure > 0)
      {
         order_type = ORDER_TYPE_SELL_LIMIT;
         price = g_tick.ask + distance;
         if(price <= g_tick.bid + min_distance)
            price = g_tick.bid + min_distance;
      }
      else
      {
         order_type = ORDER_TYPE_SELL_STOP;
         price = g_tick.bid - distance;
         if(price >= g_tick.bid - min_distance)
            price = g_tick.bid - min_distance;
      }
   }

   price = NormalizePrice(price);
   return (price > 0.0);
}

bool IsPendingFiltersOK()
{
   if(!AllowTrading)
      return false;

   if(!IsSpreadOK())
   {
      SetStatus("SPREAD ALTO", "bloqueio por spread");
      return false;
   }

   if(!IsTradingHourOK())
   {
      SetStatus("HORARIO BLOQUEADO", "bloqueio por horario");
      return false;
   }

   if(IsNewsBlocked())
   {
      SetStatus("NEWS BLOCK V2", "bloqueio por noticia");
      return false;
   }

   if(g_dailyLossBlocked)
   {
      SetStatus("LOSS DIARIO", "bloqueio por loss diario");
      return false;
   }

   if(g_dailyProfitBlocked)
   {
      SetStatus("META BATIDA", "meta diaria atingida");
      return false;
   }

   if(g_basketDDBlocked)
   {
      SetStatus("DD BLOQUEADO", "bloqueio por DD");
      return false;
   }

   if(CountOpenPositions() >= LimitOpenPositions())
      return false;

   if(CountPendingOrders() >= LimitPendingOrders())
      return false;

   return true;
}

bool IsSLValid(ENUM_POSITION_TYPE position_type, double sl_price)
{
   if(sl_price <= 0.0)
      return false;

   double min_distance = MinTradeDistancePrice();

   if(position_type == POSITION_TYPE_BUY)
      return (sl_price < g_tick.bid - min_distance);

   return (sl_price > g_tick.ask + min_distance);
}

string MFEStateToText(ENUM_MFE_POSITION_STATE state)
{
   switch(state)
   {
      case MFE_TRACKING:
         return "TRACKING";
      case MFE_ARMED:
         return "ARMED";
      case MFE_MODIFY_PENDING:
         return "MODIFY_PENDING";
      case MFE_PROTECTED:
         return "PROTECTED";
      case MFE_CLOSED:
         return "CLOSED";
      default:
         return "UNTRACKED";
   }
}

string MFESLSourceToText(ENUM_MFE_SL_SOURCE source)
{
   switch(source)
   {
      case MFE_SL_SOURCE_BREAK_EVEN:
         return "BREAK_EVEN";
      case MFE_SL_SOURCE_LEGACY_TRAILING:
         return "LEGACY_TRAILING";
      case MFE_SL_SOURCE_ADAPTIVE_MFE:
         return "ADAPTIVE_MFE";
      default:
         return "NONE";
   }
}

string MFEGlobalPrefix()
{
   string symbol_key = _Symbol;
   StringReplace(symbol_key, ".", "_");
   return "PFMFE_" +
          IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + "_" +
          symbol_key + "_" +
          IntegerToString(MagicNumber) + "_";
}

string MFEGlobalName(long identifier, string field)
{
   return MFEGlobalPrefix() + IntegerToString(identifier) + "_" + field;
}

void ResetMFEPositionState(int index)
{
   if(index < 0 || index >= MFE_MAX_TRACKED_POSITIONS)
      return;

   ZeroMemory(g_mfePositions[index]);
   g_mfePositions[index].state = MFE_UNTRACKED;
   g_mfePositions[index].request_source = MFE_SL_SOURCE_NONE;
   g_mfePositions[index].last_confirmed_source = MFE_SL_SOURCE_NONE;
}

int FindMFEPositionState(long identifier)
{
   if(identifier <= 0)
      return -1;

   for(int i = 0; i < MFE_MAX_TRACKED_POSITIONS; i++)
   {
      if(g_mfePositions[i].used && g_mfePositions[i].identifier == identifier)
         return i;
   }

   return -1;
}

int FindMFEPositionStateByTicket(ulong ticket)
{
   if(ticket == 0)
      return -1;

   for(int i = 0; i < MFE_MAX_TRACKED_POSITIONS; i++)
   {
      if(g_mfePositions[i].used && g_mfePositions[i].ticket == ticket)
         return i;
   }

   return -1;
}

int AllocateMFEPositionState()
{
   for(int i = 0; i < MFE_MAX_TRACKED_POSITIONS; i++)
   {
      if(!g_mfePositions[i].used)
      {
         ResetMFEPositionState(i);
         return i;
      }
   }

   return -1;
}

void LogMFEStateEvent(string event_name, int index, string extra)
{
   if(!MFELogStateChanges || index < 0 || index >= MFE_MAX_TRACKED_POSITIONS)
      return;
   if(!g_mfePositions[index].used)
      return;

   string side = (g_mfePositions[index].type == POSITION_TYPE_BUY ? "BUY" : "SELL");
   string message = "[" + event_name + "]" +
                    " identifier=" + IntegerToString(g_mfePositions[index].identifier) +
                    " ticket=" + IntegerToString((long)g_mfePositions[index].ticket) +
                    " side=" + side +
                    " volume=" + DoubleToString(g_mfePositions[index].volume, 2) +
                    " current_net=" + DoubleToString(g_mfePositions[index].current_net_profit, 2) +
                    " net_mfe=" + DoubleToString(g_mfePositions[index].net_mfe, 2) +
                    " stage=" + IntegerToString(g_mfePositions[index].stage) +
                    " desired_lock=" + DoubleToString(g_mfePositions[index].desired_net_lock, 2) +
                    " effective_lock=" + DoubleToString(g_mfePositions[index].effective_net_lock, 2) +
                    " confirmed_lock=" + DoubleToString(g_mfePositions[index].confirmed_net_lock, 2) +
                    " confirmed_sl=" + DoubleToString(g_mfePositions[index].last_confirmed_sl, _Digits) +
                    " state=" + MFEStateToText(g_mfePositions[index].state);
   if(extra != "")
      message += " " + extra;

   LogMessage(message);
}

void ClearMFEPersistedState(long identifier)
{
   if(identifier <= 0)
      return;

   string state_prefix = MFEGlobalName(identifier, "");
   for(int i = GlobalVariablesTotal() - 1; i >= 0; i--)
   {
      string name = GlobalVariableName(i);
      if(StringFind(name, state_prefix) == 0)
         GlobalVariableDel(name);
   }
}

void PersistMFEPositionState(int index, bool full_state)
{
   if(!MFEPersistState || index < 0 || index >= MFE_MAX_TRACKED_POSITIONS)
      return;
   if(!g_mfePositions[index].used || g_mfePositions[index].identifier <= 0)
      return;

   long identifier = g_mfePositions[index].identifier;

   if(full_state)
   {
      GlobalVariableSet(MFEGlobalName(identifier, "V"), (double)MFE_STATE_SCHEMA_VERSION);
      GlobalVariableSet(MFEGlobalName(identifier, "ID"), (double)identifier);
      GlobalVariableSet(MFEGlobalName(identifier, "TK"), (double)g_mfePositions[index].ticket);
      GlobalVariableSet(MFEGlobalName(identifier, "TY"), (double)((int)g_mfePositions[index].type));
      GlobalVariableSet(MFEGlobalName(identifier, "VO"), g_mfePositions[index].volume);
      GlobalVariableSet(MFEGlobalName(identifier, "OP"), g_mfePositions[index].open_price);
      GlobalVariableSet(MFEGlobalName(identifier, "OT"), (double)g_mfePositions[index].open_time);
      GlobalVariableSet(MFEGlobalName(identifier, "EC"), g_mfePositions[index].entry_commission);
      GlobalVariableSet(MFEGlobalName(identifier, "XR"), g_mfePositions[index].exit_commission_per_lot);
      GlobalVariableSet(MFEGlobalName(identifier, "CS"), (double)g_mfePositions[index].cost_source);
   }

   GlobalVariableSet(MFEGlobalName(identifier, "NM"), g_mfePositions[index].net_mfe);
   GlobalVariableSet(MFEGlobalName(identifier, "DL"), g_mfePositions[index].desired_net_lock);
   GlobalVariableSet(MFEGlobalName(identifier, "EL"), g_mfePositions[index].effective_net_lock);
   GlobalVariableSet(MFEGlobalName(identifier, "CL"), g_mfePositions[index].confirmed_net_lock);
   GlobalVariableSet(MFEGlobalName(identifier, "SL"), g_mfePositions[index].last_confirmed_sl);
   GlobalVariableSet(MFEGlobalName(identifier, "ST"), (double)((int)g_mfePositions[index].state));
   GlobalVariableSet(MFEGlobalName(identifier, "SG"), (double)g_mfePositions[index].stage);
   GlobalVariableSet(MFEGlobalName(identifier, "LS"), (double)g_mfePositions[index].last_step);
   GlobalVariableSet(MFEGlobalName(identifier, "HQ"), (double)g_mfePositions[index].last_logged_high_quantum);
   if(!full_state)
      return;

   GlobalVariableSet(MFEGlobalName(identifier, "RS"), g_mfePositions[index].requested_sl);
   GlobalVariableSet(MFEGlobalName(identifier, "RL"), g_mfePositions[index].requested_effective_lock);
   GlobalVariableSet(MFEGlobalName(identifier, "RT"), (double)g_mfePositions[index].request_time);
   GlobalVariableSet(MFEGlobalName(identifier, "PN"), (g_mfePositions[index].pending ? 1.0 : 0.0));
   GlobalVariableSet(MFEGlobalName(identifier, "SO"), (double)((int)g_mfePositions[index].request_source));
   GlobalVariableSet(MFEGlobalName(identifier, "LC"), (double)((int)g_mfePositions[index].last_confirmed_source));
   GlobalVariableSet(MFEGlobalName(identifier, "MC"), (double)g_mfePositions[index].modification_count);
   GlobalVariableSet(MFEGlobalName(identifier, "FC"), (double)g_mfePositions[index].failure_count);
}

bool LoadMFEPositionState(int index)
{
   if(!MFEPersistState || index < 0 || index >= MFE_MAX_TRACKED_POSITIONS)
      return false;
   if(!g_mfePositions[index].used || g_mfePositions[index].identifier <= 0)
      return false;

   long identifier = g_mfePositions[index].identifier;
   string version_name = MFEGlobalName(identifier, "V");
   string identifier_name = MFEGlobalName(identifier, "ID");
   string type_name = MFEGlobalName(identifier, "TY");
   string volume_name = MFEGlobalName(identifier, "VO");
   string open_name = MFEGlobalName(identifier, "OP");
   string mfe_name = MFEGlobalName(identifier, "NM");

   if(!GlobalVariableCheck(version_name) ||
      !GlobalVariableCheck(identifier_name) ||
      !GlobalVariableCheck(type_name) ||
      !GlobalVariableCheck(volume_name) ||
      !GlobalVariableCheck(open_name) ||
      !GlobalVariableCheck(mfe_name))
      return false;

   int version = (int)GlobalVariableGet(version_name);
   long persisted_identifier = (long)GlobalVariableGet(identifier_name);
   ENUM_POSITION_TYPE persisted_type = (ENUM_POSITION_TYPE)((int)GlobalVariableGet(type_name));
   double persisted_volume = GlobalVariableGet(volume_name);
   double persisted_open = GlobalVariableGet(open_name);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(tick_size <= 0.0)
      tick_size = _Point;
   if(volume_step <= 0.0)
      volume_step = 0.01;

   if(version != MFE_STATE_SCHEMA_VERSION ||
      persisted_identifier != identifier ||
      persisted_type != g_mfePositions[index].type ||
      MathAbs(persisted_volume - g_mfePositions[index].volume) > volume_step * 0.5 ||
      MathAbs(persisted_open - g_mfePositions[index].open_price) > tick_size)
   {
      LogMFEStateEvent("MFE_REBUILD_INCONSISTENT_STATE", index, "reason=PERSISTED_IDENTITY_MISMATCH");
      return false;
   }

   if(GlobalVariableCheck(MFEGlobalName(identifier, "TK")))
   {
      ulong persisted_ticket = (ulong)GlobalVariableGet(MFEGlobalName(identifier, "TK"));
      if(persisted_ticket > 0 && persisted_ticket != g_mfePositions[index].ticket)
         LogMFEStateEvent("MFE_TICKET_RECONCILED", index,
                          "persisted_ticket=" + IntegerToString((long)persisted_ticket) +
                          " current_ticket=" + IntegerToString((long)g_mfePositions[index].ticket));
   }

   g_mfePositions[index].net_mfe = MathMax(g_mfePositions[index].net_mfe, GlobalVariableGet(mfe_name));
   if(GlobalVariableCheck(MFEGlobalName(identifier, "DL")))
      g_mfePositions[index].desired_net_lock = MathMax(0.0, GlobalVariableGet(MFEGlobalName(identifier, "DL")));
   if(GlobalVariableCheck(MFEGlobalName(identifier, "EL")))
      g_mfePositions[index].effective_net_lock = MathMax(0.0, GlobalVariableGet(MFEGlobalName(identifier, "EL")));
   if(GlobalVariableCheck(MFEGlobalName(identifier, "CL")))
      g_mfePositions[index].confirmed_net_lock = MathMax(0.0, GlobalVariableGet(MFEGlobalName(identifier, "CL")));
   if(GlobalVariableCheck(MFEGlobalName(identifier, "SL")))
      g_mfePositions[index].last_confirmed_sl = GlobalVariableGet(MFEGlobalName(identifier, "SL"));
   if(GlobalVariableCheck(MFEGlobalName(identifier, "SG")))
      g_mfePositions[index].stage = MathMax(0, MathMin(4, (int)GlobalVariableGet(MFEGlobalName(identifier, "SG"))));
   if(GlobalVariableCheck(MFEGlobalName(identifier, "LS")))
      g_mfePositions[index].last_step = MathMax(0, (int)GlobalVariableGet(MFEGlobalName(identifier, "LS")));
   if(GlobalVariableCheck(MFEGlobalName(identifier, "HQ")))
      g_mfePositions[index].last_logged_high_quantum = (int)GlobalVariableGet(MFEGlobalName(identifier, "HQ"));
   if(GlobalVariableCheck(MFEGlobalName(identifier, "RS")))
      g_mfePositions[index].requested_sl = GlobalVariableGet(MFEGlobalName(identifier, "RS"));
   if(GlobalVariableCheck(MFEGlobalName(identifier, "RL")))
      g_mfePositions[index].requested_effective_lock = MathMax(0.0, GlobalVariableGet(MFEGlobalName(identifier, "RL")));
   if(GlobalVariableCheck(MFEGlobalName(identifier, "RT")))
      g_mfePositions[index].request_time = (datetime)GlobalVariableGet(MFEGlobalName(identifier, "RT"));
   if(GlobalVariableCheck(MFEGlobalName(identifier, "SO")))
      g_mfePositions[index].request_source = (ENUM_MFE_SL_SOURCE)((int)GlobalVariableGet(MFEGlobalName(identifier, "SO")));
   if(GlobalVariableCheck(MFEGlobalName(identifier, "LC")))
      g_mfePositions[index].last_confirmed_source = (ENUM_MFE_SL_SOURCE)((int)GlobalVariableGet(MFEGlobalName(identifier, "LC")));
   if(GlobalVariableCheck(MFEGlobalName(identifier, "MC")))
      g_mfePositions[index].modification_count = MathMax(0, (int)GlobalVariableGet(MFEGlobalName(identifier, "MC")));
   if(GlobalVariableCheck(MFEGlobalName(identifier, "FC")))
      g_mfePositions[index].failure_count = MathMax(0, (int)GlobalVariableGet(MFEGlobalName(identifier, "FC")));

   bool persisted_pending = (GlobalVariableCheck(MFEGlobalName(identifier, "PN")) &&
                             GlobalVariableGet(MFEGlobalName(identifier, "PN")) > 0.5);
   if(persisted_pending && g_mfePositions[index].requested_sl > 0.0 && g_mfePositions[index].request_time > 0)
   {
      g_mfePositions[index].pending = true;
      g_mfePositions[index].state = MFE_MODIFY_PENDING;
   }

   return true;
}

void PersistAllMFEPositionStates()
{
   for(int i = 0; i < MFE_MAX_TRACKED_POSITIONS; i++)
   {
      if(g_mfePositions[i].used)
         PersistMFEPositionState(i, true);
   }
}

void CleanupOrphanedMFEPersistedStates()
{
   if(!MFEPersistState)
      return;

   string prefix = MFEGlobalPrefix();
   bool removed_orphan = true;
   while(removed_orphan)
   {
      removed_orphan = false;
      for(int i = GlobalVariablesTotal() - 1; i >= 0; i--)
      {
         string name = GlobalVariableName(i);
         if(StringFind(name, prefix) != 0)
            continue;

         string tail = StringSubstr(name, StringLen(prefix));
         int separator = StringFind(tail, "_");
         if(separator <= 0)
            continue;

         long identifier = (long)StringToInteger(StringSubstr(tail, 0, separator));
         if(identifier <= 0 || FindMFEPositionState(identifier) >= 0)
            continue;

         ulong ticket = 0;
         if(!SelectMFEPositionByIdentifier(identifier, ticket))
         {
            ClearMFEPersistedState(identifier);
            removed_orphan = true;
            break;
         }
      }
   }
}

bool SelectMFEPositionByIdentifier(long identifier, ulong &ticket)
{
   ticket = 0;
   if(identifier <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong current_ticket = PositionGetTicket(i);
      if(current_ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      if((long)PositionGetInteger(POSITION_IDENTIFIER) != identifier)
         continue;

      ticket = current_ticket;
      return true;
   }

   return false;
}

bool ReconcileMFEPositionIdentity(int index)
{
   if(index < 0 || index >= MFE_MAX_TRACKED_POSITIONS || !g_mfePositions[index].used)
      return false;

   bool identity_changed = false;
   ulong current_ticket = 0;
   if(!SelectMFEPositionByIdentifier(g_mfePositions[index].identifier, current_ticket))
      return false;
   if(!PositionSelectByTicket(current_ticket))
      return false;

   if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
      (long)PositionGetInteger(POSITION_MAGIC) != MagicNumber ||
      (long)PositionGetInteger(POSITION_IDENTIFIER) != g_mfePositions[index].identifier)
      return false;

   ENUM_POSITION_TYPE current_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double current_volume = PositionGetDouble(POSITION_VOLUME);
   double current_open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(tick_size <= 0.0)
      tick_size = _Point;
   if(volume_step <= 0.0)
      volume_step = 0.01;

   if(current_type != g_mfePositions[index].type || MathAbs(current_open_price - g_mfePositions[index].open_price) > tick_size)
   {
      LogMFEStateEvent("MFE_REBUILD_INCONSISTENT_STATE", index, "reason=LIVE_IDENTITY_MISMATCH");
      return false;
   }

   if(current_ticket != g_mfePositions[index].ticket)
   {
      ulong previous_ticket = g_mfePositions[index].ticket;
      g_mfePositions[index].ticket = current_ticket;
      identity_changed = true;
      LogMFEStateEvent("MFE_TICKET_RECONCILED", index,
                       "previous_ticket=" + IntegerToString((long)previous_ticket) +
                       " current_ticket=" + IntegerToString((long)current_ticket));
   }

   if(MathAbs(current_volume - g_mfePositions[index].volume) > volume_step * 0.5)
   {
      double previous_volume = g_mfePositions[index].volume;
      g_mfePositions[index].volume = current_volume;
      g_mfePositions[index].estimated_exit_commission = -MathAbs(g_mfePositions[index].exit_commission_per_lot) * g_mfePositions[index].volume;
      identity_changed = true;
      LogMFEStateEvent("MFE_REBUILD", index,
                       "reason=EXTERNAL_VOLUME_RECONCILED previous_volume=" +
                       DoubleToString(previous_volume, 2));
   }

   if(identity_changed)
      PersistMFEPositionState(index, true);
   return true;
}

void InitializeMFEObservedCommissionRate()
{
   if(g_mfeObservedCommissionInitialized)
      return;

   g_mfeObservedCommissionInitialized = true;
   g_mfeObservedClosingCommissionPerLot = 0.0;

   datetime to = TimeCurrent();
   if(to <= 0)
      return;

   datetime from = to - (datetime)(MFE_COMMISSION_LOOKBACK_DAYS * 86400);
   if(!HistorySelect(from, to))
      return;

   double commission_cost = 0.0;
   double commission_volume = 0.0;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;

      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
         continue;

      double volume = HistoryDealGetDouble(deal, DEAL_VOLUME);
      double commission = HistoryDealGetDouble(deal, DEAL_COMMISSION);
      if(volume <= 0.0 || MathAbs(commission) <= 0.0000001)
         continue;

      commission_cost += MathAbs(commission);
      commission_volume += volume;
   }

   if(commission_volume > 0.0)
      g_mfeObservedClosingCommissionPerLot = commission_cost / commission_volume;
}

bool ResolveMFEPositionCosts(int index)
{
   if(index < 0 || index >= MFE_MAX_TRACKED_POSITIONS || !g_mfePositions[index].used)
      return false;

   g_mfePositions[index].entry_commission = 0.0;
   g_mfePositions[index].exit_commission_per_lot = 0.0;
   g_mfePositions[index].estimated_exit_commission = 0.0;
   g_mfePositions[index].cost_source = 0;

   datetime to = TimeCurrent();
   if(to <= 0)
      to = GetOperationalServerTime();
   datetime from = g_mfePositions[index].open_time - 86400;
   if(from < 0)
      from = 0;

   double own_commission_volume = 0.0;
   if(to > 0 && HistorySelect(from, to))
   {
      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
      {
         ulong deal = HistoryDealGetTicket(i);
         if(deal == 0)
            continue;
         if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
            continue;
         if((long)HistoryDealGetInteger(deal, DEAL_MAGIC) != MagicNumber)
            continue;
         if((long)HistoryDealGetInteger(deal, DEAL_POSITION_ID) != g_mfePositions[index].identifier)
            continue;

         ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
         if(entry != DEAL_ENTRY_IN && entry != DEAL_ENTRY_INOUT)
            continue;

         g_mfePositions[index].entry_commission += HistoryDealGetDouble(deal, DEAL_COMMISSION);
         own_commission_volume += HistoryDealGetDouble(deal, DEAL_VOLUME);
      }
   }

   if(MathAbs(g_mfePositions[index].entry_commission) > 0.0000001 && own_commission_volume > 0.0)
   {
      g_mfePositions[index].exit_commission_per_lot = MathAbs(g_mfePositions[index].entry_commission) / own_commission_volume;
      g_mfePositions[index].cost_source = 1;
   }
   else if(g_mfeObservedClosingCommissionPerLot > 0.0)
   {
      g_mfePositions[index].exit_commission_per_lot = g_mfeObservedClosingCommissionPerLot;
      g_mfePositions[index].cost_source = 2;
   }
   else
   {
      g_mfePositions[index].exit_commission_per_lot = MathMax(MathAbs(MFEEstimatedClosingCommissionPerLot), 0.01);
      g_mfePositions[index].cost_source = 3;
   }

   g_mfePositions[index].estimated_exit_commission = -g_mfePositions[index].exit_commission_per_lot * g_mfePositions[index].volume;
   if(g_mfePositions[index].cost_source == 3)
      LogMFEStateEvent("MFE_COST_FALLBACK", index,
                       "per_lot=" + DoubleToString(g_mfePositions[index].exit_commission_per_lot, 2));

   return true;
}

bool CalculateMFEPositionNetProfit(int index,
                                   bool use_close_price,
                                   double close_price,
                                   double &net_profit)
{
   net_profit = 0.0;
   if(index < 0 || index >= MFE_MAX_TRACKED_POSITIONS || !g_mfePositions[index].used)
      return false;

   if(!PositionSelectByTicket(g_mfePositions[index].ticket))
      return false;
   if((long)PositionGetInteger(POSITION_IDENTIFIER) != g_mfePositions[index].identifier ||
      PositionGetString(POSITION_SYMBOL) != _Symbol ||
      (long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
      return false;

   double gross_profit = 0.0;
   if(use_close_price)
   {
      if(close_price <= 0.0)
         return false;

      ENUM_ORDER_TYPE order_type = (g_mfePositions[index].type == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      if(!OrderCalcProfit(order_type,
                          _Symbol,
                          g_mfePositions[index].volume,
                          g_mfePositions[index].open_price,
                          close_price,
                          gross_profit))
         return false;
   }
   else
      gross_profit = PositionGetDouble(POSITION_PROFIT);

   double swap = PositionGetDouble(POSITION_SWAP);
   net_profit = gross_profit +
                swap +
                g_mfePositions[index].entry_commission +
                g_mfePositions[index].estimated_exit_commission;
   return true;
}

int GetMFERetentionStage(double net_mfe, double &retention_ratio)
{
   if(net_mfe >= MFEStage4StartNetMoney)
   {
      retention_ratio = MathMax(0.0, MathMin(1.0, MFEStage4RetentionRatio));
      return 4;
   }
   if(net_mfe >= MFEStage3StartNetMoney)
   {
      retention_ratio = MathMax(0.0, MathMin(1.0, MFEStage3RetentionRatio));
      return 3;
   }
   if(net_mfe >= MFEStage2StartNetMoney)
   {
      retention_ratio = MathMax(0.0, MathMin(1.0, MFEStage2RetentionRatio));
      return 2;
   }

   retention_ratio = MFE_STAGE1_RETENTION_RATIO;
   return 1;
}

double QuantizeMFENetLock(double value)
{
   double quantum = MathMax(MFEProtectionQuantumNetMoney, 0.01);
   if(value <= 0.0)
      return 0.0;

   return NormalizeDouble(MathFloor((value / quantum) + 0.0000001) * quantum, 2);
}

double UpdateDesiredMFENetLock(int index)
{
   if(index < 0 || index >= MFE_MAX_TRACKED_POSITIONS || !g_mfePositions[index].used)
      return 0.0;

   double activation = MathMax(MFEActivationNetMoney, 0.01);
   if(g_mfePositions[index].net_mfe < activation)
      return g_mfePositions[index].desired_net_lock;

   double trigger_step = MathMax(MFETriggerStepNetMoney, 0.01);
   int completed_steps = (int)MathFloor(((g_mfePositions[index].net_mfe - activation) / trigger_step) + 0.0000001);
   completed_steps = MathMax(0, completed_steps);

   double base_lock = MathMax(0.0, MFEInitialProtectedNetMoney) +
                      (double)completed_steps * MathMax(0.0, MFEProtectStepNetMoney);
   double retention_ratio = 0.0;
   int stage = GetMFERetentionStage(g_mfePositions[index].net_mfe, retention_ratio);
   double ratio_lock = g_mfePositions[index].net_mfe * retention_ratio;
   double candidate_lock = MathMax(base_lock, ratio_lock);
   double maximum_lock = g_mfePositions[index].net_mfe - MathMax(0.0, MFEMinimumGivebackNetMoney);
   candidate_lock = MathMin(candidate_lock, maximum_lock);
   candidate_lock = QuantizeMFENetLock(MathMax(0.0, candidate_lock));

   bool stage_changed = false;
   int previous_stage = g_mfePositions[index].stage;
   if(stage != g_mfePositions[index].stage)
   {
      g_mfePositions[index].stage = stage;
      stage_changed = true;
   }

   g_mfePositions[index].last_step = MathMax(g_mfePositions[index].last_step, completed_steps);
   if(candidate_lock > g_mfePositions[index].desired_net_lock)
      g_mfePositions[index].desired_net_lock = candidate_lock;

   if(stage_changed)
      LogMFEStateEvent("MFE_STAGE_CHANGED", index,
                       "previous_stage=" + IntegerToString(previous_stage) +
                       " retention=" + DoubleToString(retention_ratio, 2));

   return g_mfePositions[index].desired_net_lock;
}

double NormalizeMFEPriceToTick(double price, bool round_up)
{
   if(price <= 0.0)
      return 0.0;

   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0.0)
      tick_size = _Point;
   if(tick_size <= 0.0)
      return 0.0;

   double units = price / tick_size;
   double normalized_units = (round_up ? MathCeil(units - 0.000000001) :
                                         MathFloor(units + 0.000000001));
   return NormalizeDouble(normalized_units * tick_size, _Digits);
}

bool ConvertMFENetLockToPrice(int index,
                              double desired_net_lock,
                              double &sl_price,
                              double &effective_net_lock,
                              bool &distance_clamped)
{
   sl_price = 0.0;
   effective_net_lock = 0.0;
   distance_clamped = false;
   if(index < 0 || index >= MFE_MAX_TRACKED_POSITIONS || !g_mfePositions[index].used)
      return false;
   if(desired_net_lock <= 0.0 || !ReconcileMFEPositionIdentity(index))
      return false;

   double market_price = (g_mfePositions[index].type == POSITION_TYPE_BUY ? g_tick.bid : g_tick.ask);
   if(market_price <= 0.0 || g_mfePositions[index].open_price <= 0.0)
      return false;

   double open_net = 0.0;
   double market_net = 0.0;
   if(!CalculateMFEPositionNetProfit(index, true, g_mfePositions[index].open_price, open_net) ||
      !CalculateMFEPositionNetProfit(index, true, market_price, market_net))
      return false;
   if(market_net + MFEMoneyConversionTolerance < desired_net_lock)
      return false;

   double low = MathMin(g_mfePositions[index].open_price, market_price);
   double high = MathMax(g_mfePositions[index].open_price, market_price);
   double low_net = 0.0;
   double high_net = 0.0;
   if(!CalculateMFEPositionNetProfit(index, true, low, low_net) ||
      !CalculateMFEPositionNetProfit(index, true, high, high_net))
      return false;

   double minimum_net = MathMin(low_net, high_net);
   double maximum_net = MathMax(low_net, high_net);
   if(desired_net_lock < minimum_net - MFEMoneyConversionTolerance ||
      desired_net_lock > maximum_net + MFEMoneyConversionTolerance)
      return false;

   for(int iteration = 0; iteration < MFE_PRICE_SEARCH_ITERATIONS; iteration++)
   {
      double middle = (low + high) * 0.5;
      double middle_net = 0.0;
      if(!CalculateMFEPositionNetProfit(index, true, middle, middle_net))
         return false;

      if(g_mfePositions[index].type == POSITION_TYPE_BUY)
      {
         if(middle_net < desired_net_lock)
            low = middle;
         else
            high = middle;
      }
      else
      {
         if(middle_net > desired_net_lock)
            low = middle;
         else
            high = middle;
      }
   }

   double raw_price = (low + high) * 0.5;
   double down_price = NormalizeMFEPriceToTick(raw_price, false);
   double up_price = NormalizeMFEPriceToTick(raw_price, true);
   double down_net = 0.0;
   double up_net = 0.0;
   bool down_ok = (down_price > 0.0 && CalculateMFEPositionNetProfit(index, true, down_price, down_net));
   bool up_ok = (up_price > 0.0 && CalculateMFEPositionNetProfit(index, true, up_price, up_net));
   if(!down_ok && !up_ok)
      return false;

   if(down_ok && (!up_ok ||
      MathAbs(down_net - desired_net_lock) <= MathAbs(up_net - desired_net_lock)))
   {
      sl_price = down_price;
      effective_net_lock = down_net;
   }
   else
   {
      sl_price = up_price;
      effective_net_lock = up_net;
   }

   if(MathAbs(effective_net_lock - desired_net_lock) > MathMax(MFEMoneyConversionTolerance, 0.01))
      return false;

   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0.0)
      tick_size = _Point;
   double minimum_distance = MinTradeDistancePrice();
   if(g_mfePositions[index].type == POSITION_TYPE_BUY)
   {
      double maximum_valid_sl = NormalizeMFEPriceToTick(g_tick.bid - minimum_distance - tick_size, false);
      if(sl_price > maximum_valid_sl)
      {
         sl_price = maximum_valid_sl;
         distance_clamped = true;
      }
      if(sl_price <= g_mfePositions[index].open_price)
         return false;
   }
   else
   {
      double minimum_valid_sl = NormalizeMFEPriceToTick(g_tick.ask + minimum_distance + tick_size, true);
      if(sl_price < minimum_valid_sl)
      {
         sl_price = minimum_valid_sl;
         distance_clamped = true;
      }
      if(sl_price >= g_mfePositions[index].open_price)
         return false;
   }

   if(!IsSLValid(g_mfePositions[index].type, sl_price) ||
      !CalculateMFEPositionNetProfit(index, true, sl_price, effective_net_lock))
      return false;

   double minimum_positive_lock = MathMin(MathMax(MFEProtectionQuantumNetMoney, 0.01),
                                          desired_net_lock);
   if(effective_net_lock + MathMax(MFEMoneyConversionTolerance, 0.01) < minimum_positive_lock)
      return false;

   return true;
}

bool IsMFEStopMoreProtective(ENUM_POSITION_TYPE type,
                             double candidate_sl,
                             double reference_sl)
{
   if(candidate_sl <= 0.0)
      return false;
   if(reference_sl <= 0.0)
      return true;

   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0.0)
      tick_size = _Point;
   double epsilon = MathMax(_Point, tick_size) * 0.01;

   if(type == POSITION_TYPE_BUY)
      return (candidate_sl >= reference_sl + tick_size - epsilon);

   return (candidate_sl <= reference_sl - tick_size + epsilon);
}

bool IsMFEStopMatchingRequest(ENUM_POSITION_TYPE type,
                              double actual_sl,
                              double requested_sl)
{
   if(actual_sl <= 0.0 || requested_sl <= 0.0)
      return false;

   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0.0)
      tick_size = _Point;
   double tolerance = MathMax(tick_size * 0.51, _Point * 0.51);
   if(MathAbs(actual_sl - requested_sl) > tolerance)
      return false;

   if(type == POSITION_TYPE_BUY)
      return (actual_sl + tolerance >= requested_sl);

   return (actual_sl - tolerance <= requested_sl);
}

bool IsMFETradeModificationAllowed()
{
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
      return false;
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      return false;
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
      return false;
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
      return false;

   ENUM_SYMBOL_TRADE_MODE trade_mode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   return (trade_mode != SYMBOL_TRADE_MODE_DISABLED);
}

string MFERetcodeReason(uint retcode)
{
   switch(retcode)
   {
      case TRADE_RETCODE_DONE:
         return "DONE";
      case TRADE_RETCODE_NO_CHANGES:
         return "NO_CHANGES";
      case TRADE_RETCODE_INVALID_STOPS:
         return "INVALID_STOPS";
      case TRADE_RETCODE_PRICE_CHANGED:
         return "PRICE_CHANGED";
      case TRADE_RETCODE_REQUOTE:
         return "REQUOTE";
      case TRADE_RETCODE_TOO_MANY_REQUESTS:
         return "TOO_MANY_REQUESTS";
      case TRADE_RETCODE_TRADE_DISABLED:
         return "TRADE_DISABLED";
      case TRADE_RETCODE_MARKET_CLOSED:
         return "MARKET_CLOSED";
      case TRADE_RETCODE_CONNECTION:
         return "CONNECTION";
      case TRADE_RETCODE_POSITION_CLOSED:
         return "POSITION_CLOSED";
      case TRADE_RETCODE_TIMEOUT:
         return "TIMEOUT";
      case TRADE_RETCODE_FROZEN:
         return "FROZEN";
      case TRADE_RETCODE_LOCKED:
         return "LOCKED";
      case TRADE_RETCODE_PRICE_OFF:
         return "PRICE_OFF";
      case TRADE_RETCODE_CLIENT_DISABLES_AT:
         return "CLIENT_DISABLES_AT";
      case TRADE_RETCODE_SERVER_DISABLES_AT:
         return "SERVER_DISABLES_AT";
      default:
         return "RETCODE_" + IntegerToString((int)retcode);
   }
}

bool ConfirmMFEServerStop(int index, bool timeout_reconciliation)
{
   if(index < 0 || index >= MFE_MAX_TRACKED_POSITIONS || !g_mfePositions[index].used)
      return false;

   if(!g_mfePositions[index].pending || g_mfePositions[index].requested_sl <= 0.0)
      return false;
   if(!ReconcileMFEPositionIdentity(index) || !PositionSelectByTicket(g_mfePositions[index].ticket))
      return false;

   double actual_sl = PositionGetDouble(POSITION_SL);
   if(!IsMFEStopMatchingRequest(g_mfePositions[index].type, actual_sl, g_mfePositions[index].requested_sl))
      return false;
   if(g_mfePositions[index].last_confirmed_sl > 0.0 &&
      actual_sl != g_mfePositions[index].last_confirmed_sl &&
      !IsMFEStopMoreProtective(g_mfePositions[index].type, actual_sl, g_mfePositions[index].last_confirmed_sl))
      return false;

   double confirmed_lock = 0.0;
   if(!CalculateMFEPositionNetProfit(index, true, actual_sl, confirmed_lock))
      return false;

   g_mfePositions[index].pending = false;
   g_mfePositions[index].state = MFE_PROTECTED;
   g_mfePositions[index].last_confirmed_sl = actual_sl;
   g_mfePositions[index].effective_net_lock = confirmed_lock;
   g_mfePositions[index].confirmed_net_lock = MathMax(g_mfePositions[index].confirmed_net_lock, confirmed_lock);
   g_mfePositions[index].last_confirmed_source = g_mfePositions[index].request_source;
   g_mfePositions[index].modification_count++;
   g_mfePositions[index].backoff_until = 0;
   PersistMFEPositionState(index, true);

   if(timeout_reconciliation)
      LogMFEStateEvent("MFE_MODIFY_TIMEOUT_RECONCILED", index, "result=CONFIRMED");
   LogMFEStateEvent("MFE_SL_CONFIRMED", index,
                    "source=" + MFESLSourceToText(g_mfePositions[index].last_confirmed_source) +
                    " requested_sl=" + DoubleToString(g_mfePositions[index].requested_sl, _Digits) +
                    " actual_sl=" + DoubleToString(actual_sl, _Digits));
   return true;
}

void ReconcileMFEModifyPending(int index, bool force_timeout_check)
{
   if(index < 0 || index >= MFE_MAX_TRACKED_POSITIONS || !g_mfePositions[index].used)
      return;

   if(!g_mfePositions[index].pending)
      return;
   if(ConfirmMFEServerStop(index, false))
      return;

   datetime now = TimeCurrent();
   if(now <= 0)
      now = GetOperationalServerTime();
   int elapsed = (g_mfePositions[index].request_time > 0 && now >= g_mfePositions[index].request_time ?
                  (int)(now - g_mfePositions[index].request_time) :
                  MFE_MODIFY_TIMEOUT_SECONDS);
   if(!force_timeout_check && elapsed < MFE_MODIFY_TIMEOUT_SECONDS)
      return;

   if(ConfirmMFEServerStop(index, true))
      return;

   g_mfePositions[index].pending = false;
   g_mfePositions[index].failure_count++;
   g_mfePositions[index].backoff_until = now + MFE_MODIFY_BACKOFF_SECONDS;
   g_mfePositions[index].state = (g_mfePositions[index].last_confirmed_sl > 0.0 ? MFE_PROTECTED : MFE_ARMED);
   PersistMFEPositionState(index, true);
   LogMFEStateEvent("MFE_MODIFY_TIMEOUT_RECONCILED", index,
                    "result=NOT_APPLIED requested_sl=" +
                    DoubleToString(g_mfePositions[index].requested_sl, _Digits));
}

bool SubmitUnifiedPositionStop(int index,
                               double requested_sl,
                               ENUM_MFE_SL_SOURCE source,
                               double effective_net_lock)
{
   if(index < 0 || index >= MFE_MAX_TRACKED_POSITIONS || !g_mfePositions[index].used)
      return false;

   if(g_mfePositions[index].pending || g_mfePositions[index].last_request_cycle == g_mfeManagementCycle)
      return false;

   datetime now = TimeCurrent();
   if(now <= 0)
      now = GetOperationalServerTime();
   if(g_mfePositions[index].backoff_until > 0 && now < g_mfePositions[index].backoff_until)
      return false;
   if(!IsMFETradeModificationAllowed())
   {
      g_mfePositions[index].backoff_until = now + MFE_MODIFY_BACKOFF_SECONDS;
      LogMFEStateEvent("MFE_MODIFY_REJECTED", index, "reason=TRADING_NOT_ALLOWED");
      return false;
   }

   if(!ReconcileMFEPositionIdentity(index) || !PositionSelectByTicket(g_mfePositions[index].ticket))
      return false;

   if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
      (long)PositionGetInteger(POSITION_MAGIC) != MagicNumber ||
      (long)PositionGetInteger(POSITION_IDENTIFIER) != g_mfePositions[index].identifier ||
      (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != g_mfePositions[index].type)
      return false;

   double current_volume = PositionGetDouble(POSITION_VOLUME);
   double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(volume_step <= 0.0)
      volume_step = 0.01;
   if(MathAbs(current_volume - g_mfePositions[index].volume) > volume_step * 0.5)
      return false;

   bool round_up = (g_mfePositions[index].type == POSITION_TYPE_SELL);
   requested_sl = NormalizeMFEPriceToTick(requested_sl, round_up);
   double current_sl = PositionGetDouble(POSITION_SL);
   double current_tp = PositionGetDouble(POSITION_TP);
   if(!IsMFEStopMoreProtective(g_mfePositions[index].type, requested_sl, current_sl))
      return false;
   if(!IsSLValid(g_mfePositions[index].type, requested_sl))
      return false;

   if(current_sl > 0.0 &&
      (g_mfePositions[index].last_confirmed_sl <= 0.0 ||
       IsMFEStopMoreProtective(g_mfePositions[index].type, current_sl, g_mfePositions[index].last_confirmed_sl)))
      g_mfePositions[index].last_confirmed_sl = current_sl;

   g_mfePositions[index].last_request_cycle = g_mfeManagementCycle;
   g_mfePositions[index].pending = true;
   g_mfePositions[index].state = MFE_MODIFY_PENDING;
   g_mfePositions[index].requested_sl = requested_sl;
   g_mfePositions[index].requested_effective_lock = effective_net_lock;
   g_mfePositions[index].request_time = now;
   g_mfePositions[index].request_source = source;
   PersistMFEPositionState(index, true);

   MqlTradeRequest trade_request;
   MqlTradeResult trade_result;
   ZeroMemory(trade_request);
   ZeroMemory(trade_result);
   trade_request.action = TRADE_ACTION_SLTP;
   trade_request.symbol = _Symbol;
   trade_request.position = g_mfePositions[index].ticket;
   trade_request.magic = (ulong)MagicNumber;
   trade_request.sl = requested_sl;
   trade_request.tp = current_tp;

   ResetLastError();
   bool sent = OrderSend(trade_request, trade_result);
   int terminal_error = GetLastError();
   LogMFEStateEvent("MFE_SL_REQUEST", index,
                    "source=" + MFESLSourceToText(source) +
                    " previous_sl=" + DoubleToString(current_sl, _Digits) +
                    " requested_sl=" + DoubleToString(requested_sl, _Digits) +
                    " preserved_tp=" + DoubleToString(current_tp, _Digits));

   bool accepted_retcode = (trade_result.retcode == TRADE_RETCODE_DONE ||
                            trade_result.retcode == TRADE_RETCODE_NO_CHANGES);
   if(!sent || !accepted_retcode)
   {
      g_mfePositions[index].pending = false;
      g_mfePositions[index].failure_count++;
      g_mfePositions[index].backoff_until = now + MFE_MODIFY_BACKOFF_SECONDS;
      g_mfePositions[index].state = (g_mfePositions[index].last_confirmed_sl > 0.0 ? MFE_PROTECTED : MFE_ARMED);
      PersistMFEPositionState(index, true);
      LogMFEStateEvent("MFE_MODIFY_REJECTED", index,
                       "retcode=" + IntegerToString((int)trade_result.retcode) +
                       " reason=" + MFERetcodeReason(trade_result.retcode) +
                       " terminal_error=" + IntegerToString(terminal_error));
      return false;
   }

   if(ConfirmMFEServerStop(index, false))
      return true;

   if(trade_result.retcode == TRADE_RETCODE_NO_CHANGES)
   {
      g_mfePositions[index].pending = false;
      g_mfePositions[index].failure_count++;
      g_mfePositions[index].backoff_until = now + MFE_MODIFY_BACKOFF_SECONDS;
      g_mfePositions[index].state = (g_mfePositions[index].last_confirmed_sl > 0.0 ? MFE_PROTECTED : MFE_ARMED);
      PersistMFEPositionState(index, true);
      LogMFEStateEvent("MFE_MODIFY_REJECTED", index,
                       "retcode=" + IntegerToString((int)trade_result.retcode) +
                       " reason=NO_CHANGES_WITHOUT_MATCH");
      return false;
   }

   return true;
}

int InitializeMFEPositionFromSelection(ulong ticket, bool rebuild)
{
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return -1;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
      (long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
      return -1;

   long identifier = (long)PositionGetInteger(POSITION_IDENTIFIER);
   if(identifier <= 0)
      return -1;

   int existing_index = FindMFEPositionState(identifier);
   if(existing_index >= 0)
   {
      g_mfePositions[existing_index].ticket = ticket;
      return existing_index;
   }

   int index = AllocateMFEPositionState();
   if(index < 0)
      return -1;

   g_mfePositions[index].used = true;
   g_mfePositions[index].identifier = identifier;
   g_mfePositions[index].ticket = ticket;
   g_mfePositions[index].type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   g_mfePositions[index].volume = PositionGetDouble(POSITION_VOLUME);
   g_mfePositions[index].open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   g_mfePositions[index].open_time = (datetime)PositionGetInteger(POSITION_TIME);
   g_mfePositions[index].state = MFE_TRACKING;

   ResolveMFEPositionCosts(index);
   double current_net = 0.0;
   if(CalculateMFEPositionNetProfit(index, false, 0.0, current_net))
   {
      g_mfePositions[index].current_net_profit = current_net;
      g_mfePositions[index].net_mfe = current_net;
   }

   bool loaded = LoadMFEPositionState(index);
   g_mfePositions[index].net_mfe = MathMax(g_mfePositions[index].net_mfe, g_mfePositions[index].current_net_profit);
   double quantum = MathMax(MFEProtectionQuantumNetMoney, 0.01);
   if(!loaded)
      g_mfePositions[index].last_logged_high_quantum = (int)MathFloor(MathMax(0.0, g_mfePositions[index].net_mfe) / quantum);

   double current_sl = PositionGetDouble(POSITION_SL);
   if(current_sl > 0.0)
   {
      double actual_lock = 0.0;
      g_mfePositions[index].last_confirmed_sl = current_sl;
      if(CalculateMFEPositionNetProfit(index, true, current_sl, actual_lock))
         g_mfePositions[index].confirmed_net_lock = MathMax(0.0, actual_lock);
   }

   if(!g_mfePositions[index].pending)
   {
      if(current_sl > 0.0)
         g_mfePositions[index].state = MFE_PROTECTED;
      else if(EnableAdaptiveMoneyMFE && g_mfePositions[index].net_mfe >= MathMax(MFEActivationNetMoney, 0.01))
         g_mfePositions[index].state = MFE_ARMED;
      else
         g_mfePositions[index].state = MFE_TRACKING;
   }

   if(EnableAdaptiveMoneyMFE)
      UpdateDesiredMFENetLock(index);
   PersistMFEPositionState(index, true);

   LogMFEStateEvent(rebuild ? "MFE_REBUILD" : "MFE_INIT",
                    index,
                    "persisted=" + (loaded ? "YES" : "NO") +
                    " current_sl=" + DoubleToString(current_sl, _Digits));
   return index;
}

void RebuildMFEStateFromOpenPositions()
{
   for(int i = 0; i < MFE_MAX_TRACKED_POSITIONS; i++)
      ResetMFEPositionState(i);

   int rebuilt_positions = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;

      if(InitializeMFEPositionFromSelection(ticket, true) >= 0)
         rebuilt_positions++;
   }

   g_mfeSkipSubmissionAfterRebuild = (rebuilt_positions > 0);
   CleanupOrphanedMFEPersistedStates();
}

void FinalizeMFEPositionState(int index,
                              double realized_net_profit,
                              string close_reason)
{
   if(index < 0 || index >= MFE_MAX_TRACKED_POSITIONS || !g_mfePositions[index].used)
      return;

   g_mfePositions[index].state = MFE_CLOSED;
   long identifier = g_mfePositions[index].identifier;
   bool realized_known = (realized_net_profit != EMPTY_VALUE);
   ulong exit_deal = g_mfePositions[index].last_exit_deal;
   int exit_reason = (exit_deal > 0 ? g_mfePositions[index].last_exit_reason : -1);
   double exit_price = g_mfePositions[index].last_exit_price;
   datetime history_to = TimeCurrent();
   if(history_to <= 0)
      history_to = GetOperationalServerTime();
   datetime history_from = g_mfePositions[index].open_time - 86400;
   if(history_from < 0)
      history_from = 0;

   if(exit_deal > 0 && !realized_known)
   {
      realized_net_profit = g_mfePositions[index].entry_commission +
                            g_mfePositions[index].realized_exit_components;
      realized_known = true;
   }

   if(exit_deal == 0 && history_to > 0 && HistorySelect(history_from, history_to))
   {
      double history_realized_net = g_mfePositions[index].entry_commission;
      bool exit_found = false;
      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
      {
         ulong deal = HistoryDealGetTicket(i);
         if(deal == 0 ||
            (long)HistoryDealGetInteger(deal, DEAL_POSITION_ID) != identifier)
            continue;

         ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
         if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
            continue;

         history_realized_net += HistoryDealGetDouble(deal, DEAL_PROFIT) +
                                 HistoryDealGetDouble(deal, DEAL_SWAP) +
                                 HistoryDealGetDouble(deal, DEAL_COMMISSION);
         exit_deal = deal;
         exit_reason = (int)HistoryDealGetInteger(deal, DEAL_REASON);
         exit_price = HistoryDealGetDouble(deal, DEAL_PRICE);
         exit_found = true;
      }

      if(!realized_known && exit_found)
      {
         realized_net_profit = history_realized_net;
         realized_known = true;
      }
   }

   if(!realized_known)
      return;

   string exit_class = "UNKNOWN";
   if(exit_reason == DEAL_REASON_SL)
   {
      if(g_mfePositions[index].last_confirmed_source == MFE_SL_SOURCE_ADAPTIVE_MFE &&
         g_mfePositions[index].last_confirmed_sl > 0.0)
         exit_class = "EXIT_BY_MFE_SL";
      else if(g_mfePositions[index].last_confirmed_source == MFE_SL_SOURCE_BREAK_EVEN)
         exit_class = "EXIT_BY_BREAK_EVEN_SL";
      else if(g_mfePositions[index].last_confirmed_source == MFE_SL_SOURCE_LEGACY_TRAILING)
         exit_class = "EXIT_BY_LEGACY_TRAILING_SL";
      else
         exit_class = "EXIT_BY_OTHER_SL";
   }
   else if(exit_reason == DEAL_REASON_TP)
      exit_class = "EXIT_BY_TP";
   else if(exit_reason == DEAL_REASON_SO)
      exit_class = "EXIT_BY_STOP_OUT";
   else if(exit_reason == DEAL_REASON_EXPERT)
      exit_class = "EXIT_BY_EXPERT";
   else if(exit_reason >= 0)
      exit_class = "EXIT_BY_OTHER_REASON";

   double giveback = (realized_known ? g_mfePositions[index].net_mfe - realized_net_profit : 0.0);
   double capture_efficiency = 0.0;
   bool efficiency_known = (realized_known && g_mfePositions[index].net_mfe > 0.0);
   if(efficiency_known)
      capture_efficiency = (realized_net_profit / g_mfePositions[index].net_mfe) * 100.0;

   string extra = "reason=" + close_reason +
                  " exit_class=" + exit_class +
                  " exit_deal=" + IntegerToString((long)exit_deal) +
                  " deal_reason=" + IntegerToString(exit_reason) +
                  " exit_price=" + (exit_deal > 0 ? DoubleToString(exit_price, _Digits) : "UNKNOWN") +
                  " realized_net=" + (realized_known ? DoubleToString(realized_net_profit, 2) : "UNKNOWN") +
                  " giveback=" + (realized_known ? DoubleToString(giveback, 2) : "UNKNOWN") +
                  " capture_efficiency=" + (efficiency_known ? DoubleToString(capture_efficiency, 2) : "UNKNOWN") +
                  " modifications=" + IntegerToString(g_mfePositions[index].modification_count) +
                  " failures=" + IntegerToString(g_mfePositions[index].failure_count) +
                  " last_source=" + MFESLSourceToText(g_mfePositions[index].last_confirmed_source);
   LogMFEStateEvent("MFE_CLOSED", index, extra);

   ClearMFEPersistedState(identifier);
   ResetMFEPositionState(index);
}

void HandleMFETradeTransaction(const MqlTradeTransaction &trans,
                               const MqlTradeRequest &request,
                               const MqlTradeResult &result)
{
   if(trans.type == TRADE_TRANSACTION_POSITION && trans.position > 0)
   {
      int position_index = FindMFEPositionStateByTicket(trans.position);
      if(position_index >= 0 && g_mfePositions[position_index].pending)
         ConfirmMFEServerStop(position_index, false);
   }

   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal == 0)
      return;
   if(!HistoryDealSelect(trans.deal))
      return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol)
      return;

   long identifier = (long)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   int index = FindMFEPositionState(identifier);
   if(index < 0)
      return;

   ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
      return;

   if(g_mfePositions[index].last_exit_deal != trans.deal)
   {
      g_mfePositions[index].realized_exit_components +=
         HistoryDealGetDouble(trans.deal, DEAL_PROFIT) +
         HistoryDealGetDouble(trans.deal, DEAL_SWAP) +
         HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
      g_mfePositions[index].last_exit_deal = trans.deal;
      g_mfePositions[index].last_exit_reason =
         (int)HistoryDealGetInteger(trans.deal, DEAL_REASON);
      g_mfePositions[index].last_exit_price =
         HistoryDealGetDouble(trans.deal, DEAL_PRICE);
   }

   ulong remaining_ticket = 0;
   if(SelectMFEPositionByIdentifier(identifier, remaining_ticket))
   {
      ReconcileMFEPositionIdentity(index);
      return;
   }

   double realized_net_profit = g_mfePositions[index].entry_commission +
                                g_mfePositions[index].realized_exit_components;
   FinalizeMFEPositionState(index, realized_net_profit, "DEAL_POSITION_CLOSED");
}

void ManageUnifiedProfitStopProtection()
{
   g_mfeManagementCycle++;
   if(g_mfeManagementCycle == 0)
      g_mfeManagementCycle = 1;

   bool seen[MFE_MAX_TRACKED_POSITIONS];
   ArrayInitialize(seen, false);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;

      long identifier = (long)PositionGetInteger(POSITION_IDENTIFIER);
      int index = FindMFEPositionState(identifier);
      if(index < 0)
         index = InitializeMFEPositionFromSelection(ticket, false);
      if(index < 0)
         continue;

      seen[index] = true;
      if(!ReconcileMFEPositionIdentity(index))
         continue;

      if(g_mfePositions[index].cost_source == 3 &&
         !g_mfePositions[index].cost_refresh_attempted)
      {
         datetime cost_refresh_time = TimeCurrent();
         if(cost_refresh_time <= 0)
            cost_refresh_time = GetOperationalServerTime();
         if(cost_refresh_time > g_mfePositions[index].open_time)
         {
            g_mfePositions[index].cost_refresh_attempted = true;
            if(ResolveMFEPositionCosts(index) &&
               g_mfePositions[index].cost_source != 3)
            {
               LogMFEStateEvent("MFE_COST_REFRESHED", index,
                                "entry_commission=" +
                                DoubleToString(g_mfePositions[index].entry_commission, 2) +
                                " exit_per_lot=" +
                                DoubleToString(g_mfePositions[index].exit_commission_per_lot, 2) +
                                " source=" +
                                IntegerToString(g_mfePositions[index].cost_source));
            }
         }
      }

      if(g_mfePositions[index].pending)
      {
         ReconcileMFEModifyPending(index, false);
         if(g_mfePositions[index].pending)
            continue;
      }

      double current_net = 0.0;
      if(!CalculateMFEPositionNetProfit(index, false, 0.0, current_net))
         continue;
      g_mfePositions[index].current_net_profit = current_net;

      if(current_net > g_mfePositions[index].net_mfe + 0.0000001)
      {
         g_mfePositions[index].net_mfe = current_net;
         if(EnableAdaptiveMoneyMFE)
            UpdateDesiredMFENetLock(index);

         double quantum = MathMax(MFEProtectionQuantumNetMoney, 0.01);
         int high_quantum = (int)MathFloor(MathMax(0.0, g_mfePositions[index].net_mfe) / quantum);
         if(EnableAdaptiveMoneyMFE &&
            g_mfePositions[index].net_mfe >= MathMax(MFEActivationNetMoney, 0.01) &&
            high_quantum > g_mfePositions[index].last_logged_high_quantum)
         {
            g_mfePositions[index].last_logged_high_quantum = high_quantum;
            LogMFEStateEvent("MFE_NEW_HIGH", index, "");
         }
         PersistMFEPositionState(index, false);
      }

      if(EnableAdaptiveMoneyMFE &&
         g_mfePositions[index].net_mfe >= MathMax(MFEActivationNetMoney, 0.01) &&
         g_mfePositions[index].state == MFE_TRACKING)
      {
         g_mfePositions[index].state = MFE_ARMED;
         LogMFEStateEvent("MFE_ARMED", index, "");
         PersistMFEPositionState(index, false);
      }

      if(!PositionSelectByTicket(g_mfePositions[index].ticket))
         continue;
      double current_sl = PositionGetDouble(POSITION_SL);
      double final_sl = 0.0;
      double final_effective_lock = 0.0;
      ENUM_MFE_SL_SOURCE final_source = MFE_SL_SOURCE_NONE;
      double legacy_profit = g_mfePositions[index].current_net_profit - g_mfePositions[index].estimated_exit_commission;
      double candidate_sl = 0.0;

      if(BuildBreakEvenSLCandidate(g_mfePositions[index].type,
                                  legacy_profit,
                                  g_mfePositions[index].open_price,
                                  g_mfePositions[index].volume,
                                  current_sl,
                                  candidate_sl) &&
         IsSLValid(g_mfePositions[index].type, candidate_sl) &&
         IsMFEStopMoreProtective(g_mfePositions[index].type, candidate_sl, current_sl))
      {
         final_sl = candidate_sl;
         final_source = MFE_SL_SOURCE_BREAK_EVEN;
         CalculateMFEPositionNetProfit(index, true, final_sl, final_effective_lock);
      }

      candidate_sl = 0.0;
      if(BuildSmartTrailingSLCandidate(g_mfePositions[index].type,
                                      legacy_profit,
                                      g_mfePositions[index].open_price,
                                      g_mfePositions[index].volume,
                                      current_sl,
                                      candidate_sl) &&
         IsSLValid(g_mfePositions[index].type, candidate_sl) &&
         IsMFEStopMoreProtective(g_mfePositions[index].type, candidate_sl, current_sl) &&
         IsMFEStopMoreProtective(g_mfePositions[index].type, candidate_sl, final_sl))
      {
         final_sl = candidate_sl;
         final_source = MFE_SL_SOURCE_LEGACY_TRAILING;
         CalculateMFEPositionNetProfit(index, true, final_sl, final_effective_lock);
      }

      if(EnableAdaptiveMoneyMFE)
      {
         double desired_lock = UpdateDesiredMFENetLock(index);
         if(desired_lock > 0.0)
         {
            bool conversion_required = true;
            if(current_sl > 0.0)
            {
               double current_sl_lock = 0.0;
               if(CalculateMFEPositionNetProfit(index, true, current_sl, current_sl_lock) &&
                  current_sl_lock + MathMax(MFEMoneyConversionTolerance, 0.01) >= desired_lock)
               {
                  g_mfePositions[index].confirmed_net_lock =
                     MathMax(g_mfePositions[index].confirmed_net_lock, current_sl_lock);
                  g_mfePositions[index].effective_net_lock = current_sl_lock;
                  conversion_required = false;
               }
            }

            if(conversion_required)
            {
            double mfe_sl = 0.0;
            double mfe_effective_lock = 0.0;
            bool distance_clamped = false;
            if(ConvertMFENetLockToPrice(index,
                                        desired_lock,
                                        mfe_sl,
                                        mfe_effective_lock,
                                        distance_clamped))
            {
               if(distance_clamped &&
                  MathAbs(g_mfePositions[index].last_conversion_failure_lock + desired_lock) > 0.0000001)
               {
                  g_mfePositions[index].last_conversion_failure_lock = -desired_lock;
                  LogMFEStateEvent("MFE_SERVER_DISTANCE_CLAMP", index,
                                   "requested_lock=" + DoubleToString(desired_lock, 2) +
                                   " effective_lock=" + DoubleToString(mfe_effective_lock, 2) +
                                   " clamped_sl=" + DoubleToString(mfe_sl, _Digits));
               }
               else if(!distance_clamped)
                  g_mfePositions[index].last_conversion_failure_lock = 0.0;

               g_mfePositions[index].effective_net_lock = mfe_effective_lock;
               if(IsMFEStopMoreProtective(g_mfePositions[index].type, mfe_sl, current_sl) &&
                  IsMFEStopMoreProtective(g_mfePositions[index].type, mfe_sl, final_sl))
               {
                  final_sl = mfe_sl;
                  final_effective_lock = mfe_effective_lock;
                  final_source = MFE_SL_SOURCE_ADAPTIVE_MFE;
               }
            }
            else
            {
               if(MathAbs(g_mfePositions[index].last_conversion_failure_lock - desired_lock) > 0.0000001)
               {
                  g_mfePositions[index].last_conversion_failure_lock = desired_lock;
                  LogMFEStateEvent("MFE_PRICE_CONVERSION_FAILED", index,
                                   "requested_lock=" + DoubleToString(desired_lock, 2));
               }
               if(g_mfePositions[index].last_confirmed_sl <= 0.0)
                  g_mfePositions[index].state = MFE_ARMED;
            }
            }
         }
      }

      if(current_sl > 0.0 &&
         (g_mfePositions[index].last_confirmed_sl <= 0.0 ||
          IsMFEStopMoreProtective(g_mfePositions[index].type, current_sl, g_mfePositions[index].last_confirmed_sl)))
      {
         double actual_lock = 0.0;
         g_mfePositions[index].last_confirmed_sl = current_sl;
         if(CalculateMFEPositionNetProfit(index, true, current_sl, actual_lock))
         {
            g_mfePositions[index].confirmed_net_lock = MathMax(g_mfePositions[index].confirmed_net_lock, actual_lock);
            g_mfePositions[index].effective_net_lock = actual_lock;
         }
         if(!g_mfePositions[index].pending)
            g_mfePositions[index].state = MFE_PROTECTED;
         PersistMFEPositionState(index, false);
      }

      if(g_mfeSkipSubmissionAfterRebuild)
         continue;
      if(final_sl > 0.0 && final_source != MFE_SL_SOURCE_NONE)
         SubmitUnifiedPositionStop(index, final_sl, final_source, final_effective_lock);
   }

   for(int i = 0; i < MFE_MAX_TRACKED_POSITIONS; i++)
   {
      if(!g_mfePositions[i].used || seen[i])
         continue;

      ulong current_ticket = 0;
      if(!SelectMFEPositionByIdentifier(g_mfePositions[i].identifier, current_ticket))
         FinalizeMFEPositionState(i, EMPTY_VALUE, "POSITION_NOT_FOUND");
   }

   g_mfeSkipSubmissionAfterRebuild = false;
}

bool CloseNewestPositionOfType(ENUM_POSITION_TYPE position_type)
{
   ulong newest_ticket = 0;
   datetime newest_time = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != position_type)
         continue;

      datetime position_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(position_time >= newest_time)
      {
         newest_time = position_time;
         newest_ticket = ticket;
      }
   }

   if(newest_ticket == 0)
      return false;

   bool ok = trade.PositionClose(newest_ticket, SlippagePoints);
   if(!ok)
      LogMessage("erro ao fechar ordem unilateral de seguranca: " + trade.ResultRetcodeDescription());

   return ok;
}

void DrawOrUpdateLine(string name, double price, color line_color, ENUM_LINE_STYLE line_style)
{
   if(price <= 0.0)
   {
      ObjectDelete(0, name);
      return;
   }

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);

   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
   ObjectSetInteger(0, name, OBJPROP_STYLE, line_style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
}

string BiasToText(int value, string positive, string negative)
{
   if(value > 0)
      return positive;
   if(value < 0)
      return negative;
   return "NEUTRO";
}

string ComputePanelStatus()
{
   if(!g_terminalConnected)
      return "TERMINAL DESCONECTADO";
   if(g_dailyLossBlocked)
      return "LOSS DIARIO";
   if(g_dailyProfitBlocked)
      return "META BATIDA";
   if(g_basketDDBlocked)
      return "DD BLOQUEADO";
   if(g_symbolSessionState == "MERCADO FECHADO")
      return "MERCADO FECHADO";
   if(g_symbolSessionState == "AGUARDANDO PRIMEIRO TICK")
      return "AGUARDANDO PRIMEIRO TICK";
   if(g_symbolSessionState == "SEM TICKS")
      return "SEM TICKS";
   if(!AllowTrading || !Allow_BUY || !Allow_SELL || !g_symbolTradingEnabled)
      return "NEGOCIACAO DESABILITADA";
   if(!IsTradingHourOK())
      return "HORARIO BLOQUEADO";
   if(!IsSpreadOK())
      return "SPREAD ALTO";
   if(IsNewsBlocked())
      return "NEWS BLOCK V2";
   if(!IsHedgingAccount())
      return "CONTA NETTING";
   if(CountOpenPositions() >= LimitOpenPositions())
      return "MAXIMO DE 8 OPERACOES";

   return g_status;
}

void SetStatus(string status, string log_reason="")
{
   g_status = status;
   if(log_reason != "")
      LogMessage(log_reason + ".");
}
