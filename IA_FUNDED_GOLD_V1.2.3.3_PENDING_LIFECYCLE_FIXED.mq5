#property strict
#property version   "1.233"
#property description "IA FUNDED GOLD V1.2.3.3 - lifecycle transacional de pendentes: autoexclusao de slot, replacement de tipo e troca validada antes do cancelamento."

#include <Trade/Trade.mqh>

CTrade trade;

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

input group "=== ORCAMENTO DE EXPOSICAO ==="
input int MaxSlotsExposicaoTotal = 8; // Maximo absoluto de posicoes e pendentes
input int MaxSlotsPorDirecao = 6; // Maximo de slots por direcao
input int MaxDesequilibrioDirecional = 4; // Diferenca maxima entre BUY e SELL
input double MaxExposicaoLiquidaLotes = 0.04; // Exposicao liquida maxima em lotes
input bool UsarEntradasDirecionaisIndependentes = true; // Permitir adicionais BUY ou SELL independentes

input group "=== DISTANCIAMENTO DE ORDENS ==="
input int First_step = 600; // Primeiro passo em pontos
input int Minimum_price_distance = 800; // Distancia minima de preco
input int Move_step = 300; // Passo de movimentacao
input int Distance_between_orders = 1200; // Distancia entre ordens

input group "=== COMPRESSOR DE ZONAS ==="
input bool UsarCompressorZonas = true; // Evitar entradas na mesma zona
input int DistanciaMinimaZonaPontos = 800; // Zona minima entre entradas
input bool UsarDistanciaATR = true; // Usar ATR para distancia adaptativa
input int PeriodoATRRegime = 14; // Periodo do ATR M15
input double MultiplicadorATRZona = 0.80; // Multiplicador ATR da zona
input double MultiplicadorContraTendencia = 1.50; // Aumento de distancia contra tendencia
input double ProgressaoDistanciaPorEntrada = 0.25; // Aumento progressivo por entrada
input int PersistenciaRegimeCandles = 2; // Candles fechados para confirmar regime
input bool BloquearContraTendenciaExtrema = true; // Bloquear contra tendencia em regime extremo

input group "=== MOTOR AGRESSIVO CONTROLADO V121 ==="
input bool UsarMotorAgressivoV121 = true; // Usar motor agressivo controlado V121
input bool PermitirRecoveryV121 = true; // Permitir entradas de recuperacao V121
input bool PermitirMomentumV121 = true; // Permitir entradas de momentum V121
input int MaxEntradasAdicionaisPorCandleV121 = 4; // Maximo de adicionais por candle
input int MaxEntradasPorDirecaoPorCandleV121 = 2; // Maximo por direcao por candle
input int CooldownEntradaDirecionalSegundosV121 = 20; // Cooldown por direcao em segundos
input double MultiplicadorATRRecoveryV121 = 0.35; // Multiplicador ATR para recovery
input double MultiplicadorATRMomentumV121 = 0.20; // Multiplicador ATR para momentum
input double MultiplicadorContraTendenciaV121 = 1.20; // Distancia extra contra tendencia
input double ProgressaoDistanciaPorEntradaV121 = 0.10; // Progressao por entrada do mesmo lado
input int PersistenciaRegimeCandlesV121 = 1; // Candles fechados para regime V121
input int MaxEntradasRecoveryContraExtremaV121 = 1; // Recovery contra extrema por direcao
input double MultiplicadorRecoveryContraExtremaV121 = 2.0; // Distancia extra contra extrema
input bool PermitirMomentumEmRegimeExtremoV121 = true; // Permitir momentum em regime extremo
input double ScoreMinimoRecoveryV121 = 48.0; // Score minimo recovery
input double ScoreMinimoMomentumV121 = 52.0; // Score minimo momentum
input bool UsarSpreadRelativoATRV121 = false; // Usar spread relativo ao ATR
input double MaxSpreadComoPercentualATRV121 = 0.0; // Maximo spread como percentual do ATR

input group "=== V1.2.3 EXTRACAO CONTINUA ==="
input bool UsarExtracaoContinuaV123 = true; // Ativar fluxo agressivo continuo V123
input int DistanciaMinimaMomentumPontosV123 = 350; // Piso de distancia para momentum
input int DistanciaMinimaRecoveryPontosV123 = 600; // Piso de distancia para recovery
input bool PermitirMomentumNeutroV123 = true; // Permitir momentum por fluxo em regime neutro
input bool IdentificarLadoForteFracoV123 = true; // Classificar BUY e SELL separadamente
input bool PreservarLadoForteNaExtracaoV123 = true; // Fechar lado oposto e manter lado forte
input double LucroMinimoLadoForteV123 = 8.0; // Lucro minimo do lado forte para preservar
input double LucroMinimoCestaExtracaoV123 = 5.0; // Lucro liquido minimo antes da extracao
input int CooldownExtracaoLadoSegundosV123 = 30; // Intervalo entre extracoes direcionais
input bool CorrigirPerseguicaoPendentesV123 = true; // Nao afastar pendente quando preco se aproxima
input bool PriorizarEntradaMercadoSobrePendenteV123 = true; // Liberar pendente para entrada validada

input group "=== V1.2.2 PRESENCA BILATERAL ==="
input bool ManterPresencaBilateralV122 = true; // Manter BUY e SELL reais quando possivel
input bool RebalancePrioritarioV122 = true; // Priorizar reposicao do lado ausente
input int RebalanceDelaySeconds = 2; // Espera antes do Rebalance
input int RebalanceCooldownSeconds = 10; // Cooldown por lado no Rebalance
input int MaxSecondsWithoutOneSide = 15; // Diagnostico de ausencia por lado
input bool RebalanceViaMarketOrder = true; // Rebalance por ordem a mercado
input bool CancelPendingToFreeRebalanceSlot = true; // Cancelar pendente comum para liberar slot

input group "=== V1.2.2 BIAS E ALOCACAO ==="
input bool UsarBiasDirecionalV122 = true; // Direcionar novas entradas pelo bias
input int BiasConfirmationBars = 1; // Candles M15 para confirmar bias
input double BiasMinConfidence = 55.0; // Confianca minima do bias
input double BiasSwitchConfidence = 60.0; // Confianca minima para inversao direta
input int TargetBuySlotsStrongBuy = 6; // Alvo BUY em forte alta
input int TargetSellSlotsStrongBuy = 2; // Alvo SELL em forte alta
input int TargetBuySlotsBuy = 5; // Alvo BUY em alta
input int TargetSellSlotsBuy = 3; // Alvo SELL em alta
input int TargetBuySlotsNeutral = 4; // Alvo BUY neutro
input int TargetSellSlotsNeutral = 4; // Alvo SELL neutro
input int TargetBuySlotsSell = 3; // Alvo BUY em queda
input int TargetSellSlotsSell = 5; // Alvo SELL em queda
input int TargetBuySlotsStrongSell = 2; // Alvo BUY em forte queda
input int TargetSellSlotsStrongSell = 6; // Alvo SELL em forte queda

input group "=== V1.2.2 SEGURANCA TRANSACIONAL ==="
input int MaxQuoteAgeSeconds = 3; // Idade maxima do tick em segundos
input int TradeReconciliationTimeoutSeconds = 10; // Timeout de confirmacao do servidor
input bool BlockEntriesWhileClosing = true; // Bloquear entradas durante fechamento
input bool RequireServerConfirmationV122 = true; // Exigir reconciliacao no servidor

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
input bool ConfirmarSLNoServidor = true; // Confirmar SL aplicado no servidor
input double ToleranciaConfirmacaoSLTicks = 1.0; // Tolerancia para confirmar SL em ticks

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
input double DDBloqueioAntesFechamentoUSD = 350.0; // DD para bloquear novas entradas
input double DDFechamentoObrigatorioUSD = 600.0; // DD final para fechar cesta

input group "=== META DIARIA ==="
input double DailyProfitTargetUSD = 200.0; // Meta diaria em USD
input bool StopTradingAfterDailyProfit = false; // Parar novas entradas apos meta diaria

input group "=== RISCO DIARIO DA CONTA ==="
input bool UsarRiscoDiarioEquityConta = true; // Usar limite diario pela equity da conta
input double MaxDailyLossContaUSD = 700.0; // Loss diario maximo da conta em USD
input bool FecharEsteEASeLossConta = true; // Fechar somente posicoes deste EA no loss da conta

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

enum ENUM_ENTRY_GEOMETRY_V121
{
   ENTRY_GEOMETRY_RECOVERY = 0,
   ENTRY_GEOMETRY_MOMENTUM = 1,
   ENTRY_GEOMETRY_REBALANCE = 2
};

// Bias confirmado usado apenas para direcionar novas entradas, sem inverter posicoes existentes.
enum ENUM_DIRECTIONAL_BIAS_V122
{
   BIAS_STRONG_BUY = 0,
   BIAS_BUY = 1,
   BIAS_NEUTRAL = 2,
   BIAS_SELL = 3,
   BIAS_STRONG_SELL = 4
};

enum ENUM_EXIT_STATE_V122
{
   EXIT_IDLE = 0,
   EXIT_REQUESTED = 1,
   EXIT_CANCELLING_PENDING = 2,
   EXIT_CLOSING_POSITIONS = 3,
   EXIT_RECONCILING = 4
};

enum ENUM_PENDING_LIFECYCLE_V1231
{
   PENDING_LIFECYCLE_NONE = 0,
   PENDING_LIFECYCLE_CREATE_REQUESTED = 1,
   PENDING_LIFECYCLE_ACTIVE = 2,
   PENDING_LIFECYCLE_MODIFY_REQUESTED = 3,
   PENDING_LIFECYCLE_CANCEL_REQUESTED = 4,
   PENDING_LIFECYCLE_CONFIRMING = 5
};

enum ENUM_PENDING_ACTION_V1231
{
   PENDING_ACTION_NONE = 0,
   PENDING_ACTION_CREATE = 1,
   PENDING_ACTION_MODIFY = 2,
   PENDING_ACTION_CANCEL = 3
};

enum ENUM_MARKET_HANDOFF_STATE_V1232
{
   MARKET_HANDOFF_NONE = 0,
   MARKET_HANDOFF_CANCEL_REQUESTED = 1,
   MARKET_HANDOFF_SLOT_READY = 2,
   MARKET_HANDOFF_EXECUTING = 3
};

// V1.2.3.3 PENDING LIFECYCLE FIX
// Cada cancelamento de pendente precisa declarar um motivo estrutural. Motivos
// vagos (NORMAL/UPDATE/REFRESH/MANAGE) nao existem de proposito.
enum ENUM_PENDING_CANCEL_REASON_V1233
{
   PENDING_CANCEL_REASON_NONE = 0,
   PENDING_CANCEL_REASON_RISK_EMERGENCY = 1,
   PENDING_CANCEL_REASON_GLOBAL_CLOSE = 2,
   PENDING_CANCEL_REASON_EXPIRED = 3,
   PENDING_CANCEL_REASON_INVALID_PRICE = 4,
   PENDING_CANCEL_REASON_STRUCTURAL_INVALIDATION = 5,
   PENDING_CANCEL_REASON_REPLACE_ORDER_TYPE = 6,
   PENDING_CANCEL_REASON_MARKET_HANDOFF = 7,
   PENDING_CANCEL_REASON_REBALANCE = 8,
   PENDING_CANCEL_REASON_SYMBOL_DISABLED = 9,
   PENDING_CANCEL_REASON_SHUTDOWN = 10,
   PENDING_CANCEL_REASON_RECONCILIATION = 11
};
#define PENDING_CANCEL_REASON_COUNT_V1233 12

struct RebalanceCandidateV122
{
   bool valid;
   ENUM_POSITION_TYPE direction;
   double lot;
   string reason;
};

struct EntryCandidateV121
{
   bool valid;
   ENUM_POSITION_TYPE direction;
   ENUM_ENTRY_GEOMETRY_V121 geometry;
   double score;
   double threshold;
   double entryPrice;
   double referencePrice;
   double movedPoints;
   double requiredPoints;
   int regime;
   double atrPoints;
   double spreadPoints;
   int sideSlots;
   int totalSlots;
   double netLotsBefore;
   double netLotsAfter;
   string reasonAllowBlock;
   datetime candleTime;
   string zoneId;
};

MqlTick g_tick;
datetime g_currentDayStart = 0;
datetime g_lastPairOpenTime = 0;
datetime g_lastBasketCloseTime = 0;
datetime g_lastPairCandleTime = 0;
double g_lastPairMidPrice = 0.0;
double g_dailyResult = 0.0;
bool g_dailyLossBlocked = false;
bool g_dailyProfitBlocked = false;
bool g_basketDDBlocked = false;
bool g_accountDailyLossBlocked = false;
bool g_nettingWarningShown = false;
string g_status = "OPERANDO";
string g_lastLogMessage = "";
datetime g_lastLogTime = 0;
double g_PicoLucroCestaUSD = 0.0;
bool g_FechamentoMFECestaEmAndamento = false;
double g_MAELucroCestaUSD = 0.0;
double g_dailyStartEquity = 0.0;
double g_dailyAccountResult = 0.0;
int g_atrHandle = INVALID_HANDLE;
double g_lastATRPoints = 0.0;
double g_lastATRRatio = 1.0;
double g_lastBuyLevelPrice = 0.0;
double g_lastSellLevelPrice = 0.0;
datetime g_lastBuyLevelTime = 0;
datetime g_lastSellLevelTime = 0;
bool g_tradeStateDirty = false;
datetime g_lastTradeTransactionTime = 0;
datetime g_lastBuyAdditionalTimeV121 = 0;
datetime g_lastSellAdditionalTimeV121 = 0;
datetime g_lastBuyAdditionalCandleV121 = 0;
datetime g_lastSellAdditionalCandleV121 = 0;
datetime g_budgetCandleV121 = 0;
int g_buyEntriesThisCandleV121 = 0;
int g_sellEntriesThisCandleV121 = 0;
int g_totalEntriesThisCandleV121 = 0;
int g_recoveryEntriesTodayV121 = 0;
int g_momentumEntriesTodayV121 = 0;
int g_lastRegimeV121 = 0;
int g_lastRegimeCandidateV121 = 0;
int g_regimeStableCandlesV121 = 0;
datetime g_lastRegimeCandleV121 = 0;
int g_lastSelectedDirectionV121 = -1;
string g_lastBuyBlockReasonV121 = "sem_sinal";
string g_lastSellBlockReasonV121 = "sem_sinal";
string g_bestBuyCandidateTextV121 = "sem_candidato";
string g_bestSellCandidateTextV121 = "sem_candidato";
datetime g_lastSideExtractionTimeV123 = 0;
string g_buySideStateV123 = "ABSENT";
string g_sellSideStateV123 = "ABSENT";

datetime g_buyMissingSince = 0;
datetime g_sellMissingSince = 0;
datetime g_lastBuyRebalanceTime = 0;
datetime g_lastSellRebalanceTime = 0;
bool g_buyRebalancePendingConfirmation = false;
bool g_sellRebalancePendingConfirmation = false;
int g_expectedBuyPositionCountV122 = 0;
int g_expectedSellPositionCountV122 = 0;
double g_buyReservedMarginV122 = 0.0;
double g_sellReservedMarginV122 = 0.0;
bool g_pendingOrderConfirmationV122 = false;
bool g_pendingCancelConfirmationV122 = false;
int g_expectedPendingOrdersV122 = 0;
double g_pendingReservedMarginV122 = 0.0;
datetime g_tradeRequestSinceV122 = 0;
int g_reservedSlotsV122 = 0;
double g_reservedMarginV122 = 0.0;
datetime g_flatSince = 0;
int g_previousManagedPositionCount = 0;
bool g_waitingPairReopen = false;
ENUM_EXIT_STATE_V122 g_exitState = EXIT_IDLE;
datetime g_exitStateSince = 0;
bool g_exitAwaitingServerV122 = false;
int g_exitExpectedOpenPositionsV122 = -1;
int g_exitExpectedBuyPositionsV122 = -1;
int g_exitExpectedSellPositionsV122 = -1;
int g_exitExpectedPendingOrdersV122 = -1;
ENUM_DIRECTIONAL_BIAS_V122 g_directionalBiasV122 = BIAS_NEUTRAL;
ENUM_DIRECTIONAL_BIAS_V122 g_pendingBiasV122 = BIAS_NEUTRAL;
int g_biasStableBarsV122 = 0;
datetime g_lastBiasCandleV122 = 0;
double g_biasConfidenceV122 = 0.0;
string g_lastEntryBlockReasonV122 = "OK";
datetime g_lastFlatDelayLogV122 = 0;
int g_lastFlatRemainingLoggedV122 = -1;

// Estado transacional independente por lado. Nenhuma destas variaveis altera
// sinal, distancia, lote ou risco; elas apenas serializam pedidos ao servidor.
ENUM_PENDING_LIFECYCLE_V1231 g_buyPendingStateV1231 = PENDING_LIFECYCLE_NONE;
ENUM_PENDING_LIFECYCLE_V1231 g_sellPendingStateV1231 = PENDING_LIFECYCLE_NONE;
ENUM_PENDING_ACTION_V1231 g_buyPendingActionV1231 = PENDING_ACTION_NONE;
ENUM_PENDING_ACTION_V1231 g_sellPendingActionV1231 = PENDING_ACTION_NONE;
ulong g_buyPendingTicketV1231 = 0;
ulong g_sellPendingTicketV1231 = 0;
ENUM_ORDER_TYPE g_buyPendingExpectedTypeV1231 = ORDER_TYPE_BUY_STOP;
ENUM_ORDER_TYPE g_sellPendingExpectedTypeV1231 = ORDER_TYPE_SELL_STOP;
double g_buyPendingRequestedPriceV1231 = 0.0;
double g_sellPendingRequestedPriceV1231 = 0.0;
datetime g_buyPendingRequestTimeV1231 = 0;
datetime g_sellPendingRequestTimeV1231 = 0;
int g_buyPendingExpectedCountV1231 = 0;
int g_sellPendingExpectedCountV1231 = 0;
bool g_buyPendingSlotReservedV1231 = false;
bool g_sellPendingSlotReservedV1231 = false;
double g_buyPendingReservedMarginV1231 = 0.0;
double g_sellPendingReservedMarginV1231 = 0.0;
string g_buyPendingLastReasonV1231 = "init";
string g_sellPendingLastReasonV1231 = "init";
datetime g_buyPendingLastBusyLogV1231 = 0;
datetime g_sellPendingLastBusyLogV1231 = 0;
datetime g_buyPendingLastCancelTimeV1231 = 0;
datetime g_sellPendingLastCancelTimeV1231 = 0;
datetime g_buyPendingLastCreateTimeV1232 = 0;
datetime g_sellPendingLastCreateTimeV1232 = 0;
bool g_pendingMutationSentThisTickV1231 = false;
int g_pendingCreatesBuyV1231 = 0;
int g_pendingCreatesSellV1231 = 0;
int g_pendingModifiesBuyV1231 = 0;
int g_pendingModifiesSellV1231 = 0;
int g_pendingCancelsBuyV1231 = 0;
int g_pendingCancelsSellV1231 = 0;
int g_pendingBusyBlocksV1231 = 0;
int g_pendingTimeoutsV1231 = 0;
int g_pendingRegimeInvalidationsV1231 = 0;
int g_pendingExecutionsV1231 = 0;

ENUM_MARKET_HANDOFF_STATE_V1232 g_marketHandoffStateV1232 = MARKET_HANDOFF_NONE;
EntryCandidateV121 g_marketHandoffCandidateV1232;
ulong g_marketHandoffPendingTicketV1232 = 0;
bool g_marketHandoffPendingBuySideV1232 = false;
datetime g_marketHandoffSinceV1232 = 0;
string g_marketHandoffReasonV1232 = "init";
bool g_marketHandoffResolvedThisTickV1232 = false;
int g_marketHandoffRequestsV1232 = 0;
int g_marketHandoffExecutedV1232 = 0;
int g_marketHandoffReleasedV1232 = 0;
int g_marketHandoffTimeoutsV1232 = 0;

string g_throttledLogKeysV1232[128];
datetime g_throttledLogTimesV1232[128];
string g_lastStatusLogReasonV1232 = "";
datetime g_lastStatusLogTimeV1232 = 0;

// V1.2.3.3 PENDING LIFECYCLE FIX - estado do replacement transacional de tipo
// (buy stop <-> buy limit, sell stop <-> sell limit) e contadores por motivo.
// Nenhuma destas variaveis altera sinal, distancia, lote ou risco.
bool g_buyPendingReplaceActiveV1233 = false;
bool g_sellPendingReplaceActiveV1233 = false;
ENUM_ORDER_TYPE g_buyPendingReplaceTypeV1233 = ORDER_TYPE_BUY_STOP;
ENUM_ORDER_TYPE g_sellPendingReplaceTypeV1233 = ORDER_TYPE_SELL_STOP;
ulong g_buyPendingReplaceOldTicketV1233 = 0;
ulong g_sellPendingReplaceOldTicketV1233 = 0;
datetime g_buyPendingReplaceSinceV1233 = 0;
datetime g_sellPendingReplaceSinceV1233 = 0;
long g_pendingMutationSeqV1233 = 0;
int g_pendingCancelsByReasonV1233[PENDING_CANCEL_REASON_COUNT_V1233];
int g_pendingReplaceRequestsV1233 = 0;
int g_pendingReplaceCompletedV1233 = 0;
int g_pendingReplaceReleasedV1233 = 0;
int g_pendingReplaceTimeoutsV1233 = 0;
int g_pendingRecreateBlockedV1233 = 0;
int g_pendingSwapSimBlockedV1233 = 0;

int OnInit();
void OnDeinit(const int reason);
void OnTick();
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result);

bool IsHedgingAccount();
bool IsSpreadOK();
bool IsTradingHourOK();
bool IsNewsBlocked();

int DetectPriceActionBias();
int DetectNativeVolumeFlow();

bool CanOpenNewPair();
bool CanOpenAdditionalPair();
bool CanOpenNewPairAntiOvertrade();
bool OpenBuySellPair(bool additional_pair=false);
bool ManageDirectionalAdditionalEntries();
bool CanOpenDirectionalEntry(ENUM_POSITION_TYPE direction, string &reason);
bool OpenDirectionalOrder(ENUM_POSITION_TYPE direction, string reason);
bool SelectAndExecuteCandidatesV121();
void DetectBasketStateTransitionV122();
bool ManageFlatPairReopenV122();
bool ManageBilateralPresenceV122();
bool BuildRebalanceCandidateV122(ENUM_POSITION_TYPE direction, RebalanceCandidateV122 &candidate);
bool CanExecuteRebalanceV122(RebalanceCandidateV122 &candidate);
bool ExecuteRebalanceV122(RebalanceCandidateV122 &candidate);
int GetSecondsWithoutBuyV122();
int GetSecondsWithoutSellV122();
bool HasRealBuyPositionV122();
bool HasRealSellPositionV122();
bool FreeSlotForPriorityRebalanceV122(ENUM_POSITION_TYPE direction);
bool FreePendingSlotForMarketEntryV123(EntryCandidateV121 &candidate, string &reason);
void UpdateMissingSideTimersV122();
void UpdateDirectionalBiasV122();
double GetBiasConfidenceV122();
int GetTargetBuySlotsV122();
int GetTargetSellSlotsV122();
bool CanAddTowardBiasV122(ENUM_POSITION_TYPE direction, int side_slots_adjust=0); // V1.2.3.3 PENDING LIFECYCLE FIX
bool CanAddCounterBiasRecoveryV122(ENUM_POSITION_TYPE direction, int side_slots_adjust=0); // V1.2.3.3 PENDING LIFECYCLE FIX
string BiasToTextV122(ENUM_DIRECTIONAL_BIAS_V122 bias);
string ExitStateToTextV122(ENUM_EXIT_STATE_V122 state);
int RemainingFlatDelayV122();
bool CanOpenPairV122(string &reason);
bool EntryPreflightV122(string source, bool ignore_pending_confirmation, string &reason);
bool HasValidQuoteV122(string &reason);
bool IsMarketOpenForDirectionV122(ENUM_POSITION_TYPE direction, string &reason);
bool HasMarginForOrderV122(ENUM_ORDER_TYPE order_type, double lot, double price, string &reason, double &required_margin);
bool IsTradeRetcodeSuccessV122(uint retcode);
int UsedExposureSlotsV122();
bool CanReserveSlotsV122(int slots, string &reason);
bool ReserveSlotsV122(int slots, string reason);
void ReleaseSlotsV122(int slots, string reason);
void ReserveMarginV122(double margin);
void ReleaseMarginV122(double margin);
bool HasPendingTradeConfirmationV122();
void MarkMarketRequestPendingV122(ENUM_POSITION_TYPE direction, int expected_count, double reserved_margin);
void MarkPendingOrderRequestV122(int expected_count, double reserved_margin);
void MarkPendingCancelRequestV122(int expected_count);
void ReconcileTradeRequestsV122();
void InitializePendingLifecycleV1231();
void ReconcilePendingLifecycleV1231();
bool PendingLifecycleBusyV1231(bool buy_side);
bool AnyPendingLifecycleBusyV1231();
string PendingLifecycleStateTextV1231(ENUM_PENDING_LIFECYCLE_V1231 state);
bool RequestPendingCreateV1231(bool buy_side, ENUM_ORDER_TYPE desired_type, double desired_price, double required_margin, string reason);
bool RequestPendingModifyV1231(bool buy_side, ulong ticket, double desired_price, string reason);
bool RequestPendingCancelV1231(bool buy_side, ulong ticket, ENUM_PENDING_CANCEL_REASON_V1233 reason_code, string reason, bool global_scope=false); // V1.2.3.3 PENDING LIFECYCLE FIX
// V1.2.3.3 PENDING LIFECYCLE FIX - novas autoridades auxiliares
string PendingCancelReasonTextV1233(ENUM_PENDING_CANCEL_REASON_V1233 reason_code);
int PendingSideSlotAdjustV1233(bool buy_side, ulong exclude_order_ticket);
bool SimulatePendingSwapV1233(ENUM_POSITION_TYPE entry_direction, bool pending_buy_side, ulong pending_ticket, string &reason);
bool PendingReplaceActiveV1233(bool buy_side);
void ReleasePendingReplacementV1233(bool buy_side, string reason, bool timed_out=false);
void ProcessPendingReplacementV1233();
bool IsMarketHandoffActiveV1232();
string MarketHandoffStateTextV1232();
bool ProcessMarketEntryHandoffV1232();
void ClearMarketEntryHandoffV1232(string reason);
void LogThrottledV1232(string key, string message, int interval_seconds=10);
bool SendMarketOrderV122(ENUM_POSITION_TYPE direction, string comment, bool reserve_slot, bool ignore_pending_confirmation, bool &confirmed, string &reason);
bool ConfirmMarketPositionV122(ENUM_POSITION_TYPE direction, int expected_count);
bool IsClosingScopeActiveV122();
void StartClosingScopeV122(string reason);
void SetExitStateV122(ENUM_EXIT_STATE_V122 state, string reason);
void ConfigureClosingExpectationV122(int expected_open, int expected_buy, int expected_sell, int expected_pending, string reason);
bool ClosingExpectationMetV122();
void ReconcileClosingScopeV122();
void FinishClosingScopeV122(string reason);
void LogEntryBlockedV122(string source, string reason);
bool DeletePendingOrderV122(ulong ticket, string reason, int expected_after=-1);
int ClosedM15PriceActionBiasV122();
int ClosedM15VolumeFlowV122();
bool BuildDirectionalCandidateV121(ENUM_POSITION_TYPE direction, ENUM_ENTRY_GEOMETRY_V121 geometry, EntryCandidateV121 &candidate);
double ScoreEntryCandidateV121(EntryCandidateV121 &candidate);
bool ExecuteEntryCandidateV121(EntryCandidateV121 &candidate);
bool CanUseDirectionalCooldownV121(ENUM_POSITION_TYPE direction, string &reason);
bool IsDistinctEntryZoneV121(EntryCandidateV121 &candidate);
void ResetCandleBudgetV121();
void ResetCandidateV121(EntryCandidateV121 &candidate);
double GetAdaptiveDistancePointsV121(ENUM_POSITION_TYPE direction, ENUM_ENTRY_GEOMETRY_V121 geometry, int regime);
int DetectRegimeConfirmadoV121();
bool IsGeometryApplicableV121(ENUM_POSITION_TYPE direction, ENUM_ENTRY_GEOMETRY_V121 geometry, int regime, string &reason, int side_slots_adjust=0); // V1.2.3.3 PENDING LIFECYCLE FIX
int CountRecoveryContraExtremaV121(ENUM_POSITION_TYPE direction);
double EntryThresholdV121(ENUM_ENTRY_GEOMETRY_V121 geometry);
string DirectionToTextV121(ENUM_POSITION_TYPE direction);
string GeometryToTextV121(ENUM_ENTRY_GEOMETRY_V121 geometry);
string RegimeToTextV121(int regime);
string CandidateTextV121(EntryCandidateV121 &candidate);
string BuildZoneIdV121(ENUM_POSITION_TYPE direction, double price, double zone_points);
void LogCandidateV121(string tag, EntryCandidateV121 &candidate, string reason);
bool GetDesiredPendingOrderV121(bool buy_side, ENUM_ORDER_TYPE &order_type, double &price, ENUM_ENTRY_GEOMETRY_V121 &geometry, string &reason, ulong exclude_order_ticket=0);
bool GetDesiredPendingOrderCurrentMode(bool buy_side, ENUM_ORDER_TYPE &order_type, double &price, ENUM_ENTRY_GEOMETRY_V121 &geometry, string &reason, ulong exclude_order_ticket=0);

void ManageDynamicPendingOrders();
bool PlaceDynamicBuyPending();
bool PlaceDynamicSellPending();
void RepositionDynamicPendingOrders();
void CancelInvalidPendingOrders();
void CancelAllPendingOrders(ENUM_PENDING_CANCEL_REASON_V1233 reason_code); // V1.2.3.3 PENDING LIFECYCLE FIX

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
int DirectionalBiasSignV123();
string ClassifySideV123(ENUM_POSITION_TYPE direction);
void UpdateSideIdentificationV123();
bool TryExtractWeakSideV123(string trigger);
void ManageBreakEven();
void ManageSmartTrailing();
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

bool UpdateSymbolData();
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
int CountBuyExposureSlots();
int CountSellExposureSlots();
double GetBuyExposureLots();
double GetSellExposureLots();
double GetNetExposureLots();
bool HasExposureRoomIncludingPendings(int additionalOrders);
bool HasExposureRoomFor(int positions_to_add);
bool HasDirectionalSlotRoom(ENUM_POSITION_TYPE direction, int additional_slots, double additional_lots, string &reason);
bool BaseEntryFiltersOK();
double MidPrice();
double DistanceFromLastPairPoints();
double RequiredAdditionalDistancePoints();
bool UpdateATRData();
int DetectRegimeConfirmado();
double GetAdaptiveDistancePoints(ENUM_POSITION_TYPE direction);
double GetDirectionalReferencePrice(ENUM_POSITION_TYPE direction);
bool IsZoneAlreadyRepresented(ENUM_POSITION_TYPE direction, double price, double zone_points, ulong exclude_order_ticket=0);
bool IsBasketHealthyForNewEntry(string &reason);
double BasketCloseTargetTwoDirections();
double BasketCloseTargetOneDirection();
bool GetDesiredPendingOrder(bool buy_side, ENUM_ORDER_TYPE &order_type, double &price);
bool IsPendingFiltersOK();
bool IsSLValid(ENUM_POSITION_TYPE position_type, double sl_price);
bool ModifyPositionSL(ulong ticket, double new_sl, double current_tp, string reason);
void RebuildExposureStateFromServer();
void PersistBasketState();
void RestoreBasketState();
string StateKey(string suffix);
void DrawOrUpdateLine(string name, double price, color line_color, ENUM_LINE_STYLE line_style);
string BiasToText(int value, string positive, string negative);
string ComputePanelStatus();
void SetStatus(string status, string log_reason="");

int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);
   trade.SetTypeFillingBySymbol(_Symbol);

   LogMessage("[V122_INIT] simbolo=" + _Symbol + " magic=" + IntegerToString(MagicNumber));

   if(!IsHedgingAccount())
   {
      string warning = "[V122_HEDGING_REQUIRED] conta NETTING/EXCHANGE nao permite BUY e SELL simultaneos no mesmo simbolo; use ACCOUNT_MARGIN_MODE_RETAIL_HEDGING.";
      LogMessage(warning);
      if(!MQLInfoInteger(MQL_TESTER))
         Alert(warning);
      g_nettingWarningShown = true;
      return INIT_FAILED;
   }

   if(MathAbs(FixedLot - 0.01) > 0.0000001)
   {
      LogMessage("[V122_ENTRY_BLOCKED] motivo=fixedlot_deve_ser_0_01 valor=" + DoubleToString(FixedLot, 2));
      return INIT_FAILED;
   }

   int atr_period = MathMax(1, PeriodoATRRegime);
   g_atrHandle = iATR(_Symbol, PERIOD_M15, atr_period);
   if(g_atrHandle == INVALID_HANDLE)
      LogMessage("erro ao criar handle ATR M15.");

   UpdateSymbolData();
   RefreshDailyState();
   RestoreBasketState();
   RebuildExposureStateFromServer();
   InitializePendingLifecycleV1231();
   ResetCandidateV121(g_marketHandoffCandidateV1232);
   g_marketHandoffStateV1232 = MARKET_HANDOFF_NONE;
   UpdateATRData();
   ResetCandleBudgetV121();
   UpdateDirectionalBiasV122();

   int current_positions = CountOpenPositions();
   g_previousManagedPositionCount = current_positions;
   if(current_positions > 0)
   {
      if(g_lastPairOpenTime <= 0)
         g_lastPairOpenTime = TimeCurrent();
      g_lastPairCandleTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      g_waitingPairReopen = false;
      g_flatSince = 0;
   }
   else
   {
      int flat_elapsed = (g_flatSince > 0 ? (int)(TimeCurrent() - g_flatSince) : -1);
      if(g_flatSince <= 0 || flat_elapsed < 0 || flat_elapsed >= MathMax(0, ReopenDelaySecondsAfterClose))
         g_flatSince = TimeCurrent();
      g_waitingPairReopen = true;
      if(CountPendingOrders() > 0)
         CancelAllPendingOrders(PENDING_CANCEL_REASON_RECONCILIATION); // V1.2.3.3 PENDING LIFECYCLE FIX
      LogMessage("[V122_BASKET_BECAME_FLAT] origem=init aguardando_reabertura=1 delay=" + IntegerToString(MathMax(0, ReopenDelaySecondsAfterClose)));
   }

   UpdateMissingSideTimersV122();
   LogMessage("EA iniciado.");
   LogMessage("Conta HEDGE detectada.");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   LogMessage("[V1232_HANDOFF_SUMMARY] requests=" + IntegerToString(g_marketHandoffRequestsV1232) +
              " executed=" + IntegerToString(g_marketHandoffExecutedV1232) +
              " released=" + IntegerToString(g_marketHandoffReleasedV1232) +
              " timeouts=" + IntegerToString(g_marketHandoffTimeoutsV1232) +
              " state=" + MarketHandoffStateTextV1232());
   LogMessage("[V1231_PENDING_LIFECYCLE_SUMMARY] origem=deinit creates=" +
              IntegerToString(g_pendingCreatesBuyV1231) + "/" + IntegerToString(g_pendingCreatesSellV1231) +
              " modifies=" + IntegerToString(g_pendingModifiesBuyV1231) + "/" + IntegerToString(g_pendingModifiesSellV1231) +
              " cancels=" + IntegerToString(g_pendingCancelsBuyV1231) + "/" + IntegerToString(g_pendingCancelsSellV1231) +
              " timeouts=" + IntegerToString(g_pendingTimeoutsV1231) +
              " busy=" + IntegerToString(g_pendingBusyBlocksV1231) +
              " executions=" + IntegerToString(g_pendingExecutionsV1231));
   // V1.2.3.3 PENDING LIFECYCLE FIX: fechamento dos contadores por motivo
   string reason_summary = "";
   int reason_total = 0;
   for(int r = 0; r < PENDING_CANCEL_REASON_COUNT_V1233; r++)
   {
      reason_total += g_pendingCancelsByReasonV1233[r];
      if(g_pendingCancelsByReasonV1233[r] > 0)
         reason_summary += " " + PendingCancelReasonTextV1233((ENUM_PENDING_CANCEL_REASON_V1233)r) + "=" +
                           IntegerToString(g_pendingCancelsByReasonV1233[r]);
   }
   LogMessage("[V1233_PENDING_LIFECYCLE_SUMMARY] origem=deinit" +
              " creates_total=" + IntegerToString(g_pendingCreatesBuyV1231 + g_pendingCreatesSellV1231) +
              " cancels_total=" + IntegerToString(g_pendingCancelsBuyV1231 + g_pendingCancelsSellV1231) +
              " cancels_por_motivo_total=" + IntegerToString(reason_total) +
              " motivos:" + (reason_summary == "" ? " nenhum" : reason_summary) +
              " replace_requests=" + IntegerToString(g_pendingReplaceRequestsV1233) +
              " replace_completed=" + IntegerToString(g_pendingReplaceCompletedV1233) +
              " replace_released=" + IntegerToString(g_pendingReplaceReleasedV1233) +
              " replace_timeouts=" + IntegerToString(g_pendingReplaceTimeoutsV1233) +
              " recreates_bloqueadas=" + IntegerToString(g_pendingRecreateBlockedV1233) +
              " trocas_reprovadas_simulacao=" + IntegerToString(g_pendingSwapSimBlockedV1233) +
              " pendentes_ativas=" + IntegerToString(CountPendingOrders()));
   PersistBasketState();
   if(g_atrHandle != INVALID_HANDLE)
   {
      IndicatorRelease(g_atrHandle);
      g_atrHandle = INVALID_HANDLE;
   }
   DeleteBasketLines();
   Comment("");
   LogMessage("EA finalizado.");
}

void OnTick()
{
   // Limite absoluto: no maximo uma criacao, modificacao ou exclusao de
   // pendente por passagem do OnTick.
   g_pendingMutationSentThisTickV1231 = false;
   g_marketHandoffResolvedThisTickV1232 = false;

   if(!UpdateSymbolData())
   {
      g_lastEntryBlockReasonV122 = "tick_indisponivel";
      DrawBasketLines();
      UpdatePanel();
      return;
   }

   RefreshDailyState();
   UpdateATRData();
   UpdateDirectionalBiasV122();
   UpdateSideIdentificationV123();
   if(g_tradeStateDirty)
   {
      RebuildExposureStateFromServer();
      g_tradeStateDirty = false;
      LogMessage("[V122_STATE_REBUILT] motivo=trade_transaction posicoes=" + IntegerToString(CountOpenPositions()) +
                 " pendentes=" + IntegerToString(CountPendingOrders()) +
                 " slots=" + IntegerToString(UsedExposureSlotsV122()) + "/" + IntegerToString(LimitOpenPositions()));
   }

   ReconcileTradeRequestsV122();
   ReconcilePendingLifecycleV1231();
   DetectBasketStateTransitionV122();
   ReconcileClosingScopeV122();

   ManageDailyRisk();
   ManageDailyProfitTarget();
   AtualizarPicoLucroCesta();

   // Primeiro protege o lucro individual. Depois decide se extrai apenas o
   // lado fraco ou se encerra toda a cesta.
   ManageBreakEven();
   ManageSmartTrailing();

   ManageBasketClosing();
   if(IsClosingScopeActiveV122())
   {
      DrawBasketLines();
      UpdatePanel();
      return;
   }

   ManagePriceBasedBasketClosing();
   if(IsClosingScopeActiveV122())
   {
      DrawBasketLines();
      UpdatePanel();
      return;
   }

   if(GerenciarProtecaoLucroCestaMFE())
   {
      DrawBasketLines();
      UpdatePanel();
      return;
   }
   ManageBasketDrawdown();

   if(g_tradeStateDirty)
   {
      RebuildExposureStateFromServer();
      g_tradeStateDirty = false;
      LogMessage("[V122_STATE_REBUILT] motivo=saida_ou_risco posicoes=" + IntegerToString(CountOpenPositions()) +
                 " pendentes=" + IntegerToString(CountPendingOrders()) +
                 " slots=" + IntegerToString(UsedExposureSlotsV122()) + "/" + IntegerToString(LimitOpenPositions()));
   }

   DetectBasketStateTransitionV122();
   ReconcileTradeRequestsV122();
   ReconcilePendingLifecycleV1231();
   ReconcileClosingScopeV122();

   if(IsClosingScopeActiveV122())
   {
      DrawBasketLines();
      UpdatePanel();
      return;
   }

   if(ManageFlatPairReopenV122())
   {
      DrawBasketLines();
      UpdatePanel();
      PersistBasketState();
      return;
   }

   if(ManageBilateralPresenceV122())
   {
      DrawBasketLines();
      UpdatePanel();
      PersistBasketState();
      return;
   }

   int open_positions = CountOpenPositions();

   if(open_positions > 0)
   {
      if(UsarMotorAgressivoV121 && UsarEntradasDirecionaisIndependentes)
         SelectAndExecuteCandidatesV121();
      else if(UsarEntradasDirecionaisIndependentes)
         ManageDirectionalAdditionalEntries();
      else if(CanOpenAdditionalPair())
         OpenBuySellPair(true);
   }

   CancelInvalidPendingOrders();
   if(!g_pendingMutationSentThisTickV1231)
      ManageDynamicPendingOrders();

   DrawBasketLines();
   UpdatePanel();
   PersistBasketState();
}

void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
{
   if(trans.symbol != "" && trans.symbol != _Symbol)
      return;
   if(request.magic != 0 && request.magic != MagicNumber)
      return;

   g_tradeStateDirty = true;
   g_lastTradeTransactionTime = TimeCurrent();
   // Transacoes de entrada e reposicionamento nao sao fechamento. Somente
   // reconciliar o escopo se um fechamento ja estiver ativo.
   if(BlockEntriesWhileClosing && g_exitState != EXIT_IDLE)
      SetExitStateV122(EXIT_RECONCILING, "trade_transaction");
   PersistBasketState();
}

void DetectBasketStateTransitionV122()
{
   int current_count = CountOpenPositions();
   if(g_previousManagedPositionCount > 0 && current_count == 0)
   {
      g_flatSince = TimeCurrent();
      g_waitingPairReopen = true;
      g_lastBasketCloseTime = g_flatSince;
      ResetarPicoLucroCesta();
      if(CountPendingOrders() > 0)
         CancelAllPendingOrders(PENDING_CANCEL_REASON_GLOBAL_CLOSE); // V1.2.3.3 PENDING LIFECYCLE FIX
      LogMessage("[V122_BASKET_BECAME_FLAT] time=" + TimeToString(g_flatSince, TIME_DATE|TIME_SECONDS) +
                 " previous=" + IntegerToString(g_previousManagedPositionCount) + " current=0");
   }
   else if(current_count == 0 && g_flatSince <= 0)
   {
      g_flatSince = TimeCurrent();
      g_waitingPairReopen = true;
      LogMessage("[V122_BASKET_BECAME_FLAT] origem=primeira_reconciliacao current=0");
   }
   else if(current_count > 0)
   {
      g_waitingPairReopen = false;
      g_flatSince = 0;
   }

   g_previousManagedPositionCount = current_count;
   UpdateMissingSideTimersV122();
}

bool ManageFlatPairReopenV122()
{
   if(CountOpenPositions() > 0)
      return false;

   if(IsMarketHandoffActiveV1232())
   {
      g_marketHandoffReleasedV1232++;
      ClearMarketEntryHandoffV1232("cesta_ficou_flat");
   }

   if(!AlwaysInMarket || !OpenPairImmediatelyAfterBasketClose)
      return true;

   if(!g_waitingPairReopen)
   {
      g_flatSince = TimeCurrent();
      g_waitingPairReopen = true;
   }

   if(CountPendingOrders() > 0)
   {
      CancelAllPendingOrders(PENDING_CANCEL_REASON_GLOBAL_CLOSE); // V1.2.3.3 PENDING LIFECYCLE FIX
      g_lastEntryBlockReasonV122 = "flat_com_pendentes_cancelando";
      return true;
   }

   if(IsClosingScopeActiveV122() || HasPendingTradeConfirmationV122())
   {
      LogEntryBlockedV122("flat_reopen", IsClosingScopeActiveV122() ? "fechamento_em_andamento" : "confirmacao_pendente");
      return true;
   }

   int remaining = RemainingFlatDelayV122();
   if(remaining > 0)
   {
      datetime now = TimeCurrent();
      if(remaining != g_lastFlatRemainingLoggedV122 || now - g_lastFlatDelayLogV122 >= 1)
      {
         LogMessage("[V122_FLAT_DELAY] remaining_seconds=" + IntegerToString(remaining));
         g_lastFlatDelayLogV122 = now;
         g_lastFlatRemainingLoggedV122 = remaining;
      }
      return true;
   }

   string reason = "";
   if(!CanOpenPairV122(reason))
   {
      LogEntryBlockedV122("flat_reopen", reason);
      return true;
   }

   LogMessage("[V122_PAIR_REOPEN] flat_since=" + TimeToString(g_flatSince, TIME_DATE|TIME_SECONDS));
   OpenBuySellPair(false);
   return true;
}

int RemainingFlatDelayV122()
{
   int delay = MathMax(0, ReopenDelaySecondsAfterClose);
   if(g_flatSince <= 0)
      return delay;
   int elapsed = (int)(TimeCurrent() - g_flatSince);
   return MathMax(0, delay - elapsed);
}

void UpdateMissingSideTimersV122()
{
   datetime now = TimeCurrent();
   if(HasRealBuyPositionV122())
      g_buyMissingSince = 0;
   else if(g_buyMissingSince <= 0)
      g_buyMissingSince = now;

   if(HasRealSellPositionV122())
      g_sellMissingSince = 0;
   else if(g_sellMissingSince <= 0)
      g_sellMissingSince = now;
}

bool HasRealBuyPositionV122()
{
   return (CountBuyPositions() > 0);
}

bool HasRealSellPositionV122()
{
   return (CountSellPositions() > 0);
}

int GetSecondsWithoutBuyV122()
{
   if(g_buyMissingSince <= 0)
      return 0;
   return (int)(TimeCurrent() - g_buyMissingSince);
}

int GetSecondsWithoutSellV122()
{
   if(g_sellMissingSince <= 0)
      return 0;
   return (int)(TimeCurrent() - g_sellMissingSince);
}

bool ManageBilateralPresenceV122()
{
   if(!ManterPresencaBilateralV122 || !RebalancePrioritarioV122)
      return false;

   UpdateMissingSideTimersV122();

   bool has_buy = HasRealBuyPositionV122();
   bool has_sell = HasRealSellPositionV122();
   if(!has_buy && !has_sell)
      return false;

   RebalanceCandidateV122 candidate;
   if(!has_buy && has_sell)
   {
      if(BuildRebalanceCandidateV122(POSITION_TYPE_BUY, candidate) && CanExecuteRebalanceV122(candidate))
         return ExecuteRebalanceV122(candidate);
      if(candidate.reason != "")
         LogMessage("[V122_REBALANCE_BLOCKED] direcao=BUY motivo=" + candidate.reason +
                    " sem_buy=" + IntegerToString(GetSecondsWithoutBuyV122()));
   }

   if(!has_sell && has_buy)
   {
      if(BuildRebalanceCandidateV122(POSITION_TYPE_SELL, candidate) && CanExecuteRebalanceV122(candidate))
         return ExecuteRebalanceV122(candidate);
      if(candidate.reason != "")
         LogMessage("[V122_REBALANCE_BLOCKED] direcao=SELL motivo=" + candidate.reason +
                    " sem_sell=" + IntegerToString(GetSecondsWithoutSellV122()));
   }

   return false;
}

bool BuildRebalanceCandidateV122(ENUM_POSITION_TYPE direction, RebalanceCandidateV122 &candidate)
{
   candidate.valid = false;
   candidate.direction = direction;
   candidate.lot = NormalizeVolume(FixedLot);
   candidate.reason = "";

   if(candidate.lot <= 0.0)
   {
      candidate.reason = "lote_invalido";
      return false;
   }

   if(direction == POSITION_TYPE_BUY)
   {
      if(HasRealBuyPositionV122() || !HasRealSellPositionV122())
      {
         candidate.reason = "presenca_buy_ja_ok";
         return false;
      }
      if(g_buyRebalancePendingConfirmation)
      {
         candidate.reason = "buy_aguardando_confirmacao";
         return false;
      }
      if(GetSecondsWithoutBuyV122() < MathMax(0, RebalanceDelaySeconds))
      {
         candidate.reason = "delay_rebalance_buy";
         return false;
      }
      if(g_lastBuyRebalanceTime > 0 && (int)(TimeCurrent() - g_lastBuyRebalanceTime) < MathMax(0, RebalanceCooldownSeconds))
      {
         candidate.reason = "cooldown_rebalance_buy";
         return false;
      }
   }
   else
   {
      if(HasRealSellPositionV122() || !HasRealBuyPositionV122())
      {
         candidate.reason = "presenca_sell_ja_ok";
         return false;
      }
      if(g_sellRebalancePendingConfirmation)
      {
         candidate.reason = "sell_aguardando_confirmacao";
         return false;
      }
      if(GetSecondsWithoutSellV122() < MathMax(0, RebalanceDelaySeconds))
      {
         candidate.reason = "delay_rebalance_sell";
         return false;
      }
      if(g_lastSellRebalanceTime > 0 && (int)(TimeCurrent() - g_lastSellRebalanceTime) < MathMax(0, RebalanceCooldownSeconds))
      {
         candidate.reason = "cooldown_rebalance_sell";
         return false;
      }
   }

   candidate.valid = true;
   candidate.reason = "OK";
   return true;
}

bool CanExecuteRebalanceV122(RebalanceCandidateV122 &candidate)
{
   if(!candidate.valid)
      return false;

   if(!RebalanceViaMarketOrder)
   {
      candidate.reason = "rebalance_market_desativado";
      return false;
   }

   string reason = "";
   if(!EntryPreflightV122("rebalance", false, reason))
   {
      candidate.reason = reason;
      return false;
   }

   if(!IsBasketHealthyForNewEntry(reason))
   {
      candidate.reason = reason;
      return false;
   }

   if(!HasExposureRoomIncludingPendings(1))
   {
      if(CancelPendingToFreeRebalanceSlot && FreeSlotForPriorityRebalanceV122(candidate.direction))
      {
         candidate.reason = "aguardando_cancelamento_pendente";
         return false;
      }
      candidate.reason = "sem_slot_total";
      return false;
   }

   if(!HasDirectionalSlotRoom(candidate.direction, 1, candidate.lot, reason))
   {
      candidate.reason = reason;
      return false;
   }

   return true;
}

bool ExecuteRebalanceV122(RebalanceCandidateV122 &candidate)
{
   bool confirmed = false;
   string reason = "";
   string side = (candidate.direction == POSITION_TYPE_BUY ? "BUY" : "SELL");
   string comment = "IA_FG_V122_REBALANCE_" + side;
   bool sent = SendMarketOrderV122(candidate.direction, comment, true, false, confirmed, reason);
   if(!sent)
   {
      candidate.reason = reason;
      LogMessage("[V122_REBALANCE_BLOCKED] direcao=" + side + " motivo=" + reason);
      return false;
   }

   if(candidate.direction == POSITION_TYPE_BUY)
      g_lastBuyRebalanceTime = TimeCurrent();
   else
      g_lastSellRebalanceTime = TimeCurrent();

   LogMessage((candidate.direction == POSITION_TYPE_BUY ? "[V122_REBALANCE_BUY]" : "[V122_REBALANCE_SELL]") +
              " lote=" + DoubleToString(candidate.lot, 2) +
              " confirmed=" + (confirmed ? "true" : "false") +
              " slots=" + IntegerToString(UsedExposureSlotsV122()) + "/" + IntegerToString(LimitOpenPositions()));
   return true;
}

bool FreeSlotForPriorityRebalanceV122(ENUM_POSITION_TYPE direction)
{
   if(IsMarketHandoffActiveV1232())
      return false;
   if(UsedExposureSlotsV122() < LimitOpenPositions())
      return true;

   ENUM_POSITION_TYPE preferred_side = (direction == POSITION_TYPE_BUY ? POSITION_TYPE_SELL : POSITION_TYPE_BUY);
   for(int pass = 0; pass < 2; pass++)
   {
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

         bool buy_pending = IsBuyPendingType(type);
         if(pass == 0)
         {
            if(preferred_side == POSITION_TYPE_BUY && !buy_pending)
               continue;
            if(preferred_side == POSITION_TYPE_SELL && buy_pending)
               continue;
         }

         // V1.2.3.3 PENDING LIFECYCLE FIX: lado sob replacement pertence ao driver
         if(PendingReplaceActiveV1233(buy_pending))
            continue;

         // V1.2.3.3 PENDING LIFECYCLE FIX: valida a troca pendente->posicao de
         // Rebalance ANTES do cancelamento, com o mesmo simulador do Handoff.
         string swap_reason = "";
         if(!SimulatePendingSwapV1233(direction, buy_pending, ticket, swap_reason))
         {
            g_pendingSwapSimBlockedV1233++;
            LogThrottledV1232("rebalance_swap_blocked_" + (direction == POSITION_TYPE_BUY ? "BUY" : "SELL") + "_" + swap_reason,
                              "[V1233_PENDING_MUTATION_BLOCKED] origem=rebalance ticket=" + IntegerToString((int)ticket) +
                              " direction=" + (direction == POSITION_TYPE_BUY ? "BUY" : "SELL") +
                              " motivo=" + swap_reason, 10);
            continue;
         }

         if(RequestPendingCancelV1231(buy_pending, ticket, PENDING_CANCEL_REASON_REBALANCE, "liberar_slot_rebalance"))
         {
            LogMessage("[V122_PENDING_CANCEL_FOR_REBALANCE] ticket=" + IntegerToString((int)ticket) +
                       " direcao_rebalance=" + (direction == POSITION_TYPE_BUY ? "BUY" : "SELL"));
            return true;
         }
         LogMessage("[V122_REBALANCE_BLOCKED] motivo=falha_cancelar_pendente retcode=" + IntegerToString((int)trade.ResultRetcode()) +
                    " desc=" + trade.ResultRetcodeDescription());
         return false;
      }
   }

   return false;
}

bool FreePendingSlotForMarketEntryV123(EntryCandidateV121 &candidate, string &reason)
{
   ENUM_POSITION_TYPE direction = candidate.direction;
   if(HasExposureRoomIncludingPendings(1))
      return true;
   if(!UsarExtracaoContinuaV123 || !PriorizarEntradaMercadoSobrePendenteV123)
   {
      reason = "sem_slot_total";
      return false;
   }
   if(IsMarketHandoffActiveV1232())
   {
      reason = "handoff_mercado_ja_ativo";
      return false;
   }

   // Uma entrada a mercado ja validada por distancia/score tem prioridade
   // sobre uma pendente ainda nao executada. Prefere liberar o mesmo lado.
   for(int pass = 0; pass < 2; pass++)
   {
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(ticket == 0)
            continue;
         if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
            (long)OrderGetInteger(ORDER_MAGIC) != MagicNumber)
            continue;

         ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if(!IsPendingOrderType(type))
            continue;

         bool same_side = ((direction == POSITION_TYPE_BUY && IsBuyPendingType(type)) ||
                           (direction == POSITION_TYPE_SELL && IsSellPendingType(type)));
         if(pass == 0 && !same_side)
            continue;

         bool buy_pending = IsBuyPendingType(type);

         // V1.2.3.3 PENDING LIFECYCLE FIX: lado sob replacement pertence ao driver
         if(PendingReplaceActiveV1233(buy_pending))
            continue;

         // V1.2.3.3 PENDING LIFECYCLE FIX: a troca inteira (pendente removida +
         // posicao adicionada) e simulada ANTES do OrderDelete. Na V1.2.3.2 a
         // viabilidade direcional/margem so era conferida depois do cancelamento,
         // deixando o caminho residual CANCELAR->FALHAR->RECRIAR.
         string swap_reason = "";
         if(!SimulatePendingSwapV1233(direction, buy_pending, ticket, swap_reason))
         {
            g_pendingSwapSimBlockedV1233++;
            LogThrottledV1232("handoff_swap_blocked_" + DirectionToTextV121(direction) + "_" + swap_reason,
                              "[V1233_PENDING_MUTATION_BLOCKED] origem=handoff ticket=" + IntegerToString((int)ticket) +
                              " direction=" + DirectionToTextV121(direction) +
                              " motivo=" + swap_reason, 10);
            continue;
         }

         if(RequestPendingCancelV1231(buy_pending, ticket, PENDING_CANCEL_REASON_MARKET_HANDOFF, "liberar_slot_entrada_mercado"))
         {
            g_marketHandoffCandidateV1232 = candidate;
            g_marketHandoffCandidateV1232.valid = true;
            g_marketHandoffCandidateV1232.reasonAllowBlock = "HANDOFF_RESERVED";
            g_marketHandoffPendingTicketV1232 = ticket;
            g_marketHandoffPendingBuySideV1232 = buy_pending;
            g_marketHandoffSinceV1232 = TimeCurrent();
            g_marketHandoffReasonV1232 = "aguardando_cancelamento_pendente";
            g_marketHandoffStateV1232 = MARKET_HANDOFF_CANCEL_REQUESTED;
            g_marketHandoffRequestsV1232++;
            reason = "aguardando_liberacao_pendente";
            LogMessage("[V123_PENDING_RELEASE_FOR_MARKET] ticket=" + IntegerToString((int)ticket) +
                       " direction=" + DirectionToTextV121(direction));
            LogMessage("[V1232_HANDOFF_RESERVED] ticket=" + IntegerToString((int)ticket) +
                       " direction=" + DirectionToTextV121(direction) +
                       " geometry=" + GeometryToTextV121(candidate.geometry) +
                       " score=" + DoubleToString(candidate.score, 1) +
                       " threshold=" + DoubleToString(candidate.threshold, 1) +
                       " slots=" + IntegerToString(UsedExposureSlotsV122()) + "/" + IntegerToString(LimitOpenPositions()));
            return false;
         }

         reason = "falha_liberar_pendente";
         LogMessage("[V123_PENDING_RELEASE_FAIL] ticket=" + IntegerToString((int)ticket) +
                    " retcode=" + IntegerToString((int)trade.ResultRetcode()));
         return false;
      }
   }

   reason = "sem_slot_total";
   return false;
}

int ClosedM15PriceActionBiasV122()
{
   int lookback = MathMax(3, PriceActionLookbackBars);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_M15, 1, lookback + 2, rates);
   if(copied < lookback + 1)
      return 0;

   double recent_high = rates[1].high;
   double recent_low = rates[1].low;
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

   MqlRates closed = rates[0];
   double candle_range = closed.high - closed.low;
   double body = MathAbs(closed.close - closed.open);
   double body_ratio = (candle_range > 0.0 ? body / candle_range : 0.0);
   bool strong_body = (body_ratio >= StrongCandleBodyRatio);
   bool bullish_break = (closed.close > recent_high);
   bool bearish_break = (closed.close < recent_low);
   bool bullish_displacement = (closed.close > closed.open && strong_body && closed.close > rates[1].close);
   bool bearish_displacement = (closed.close < closed.open && strong_body && closed.close < rates[1].close);

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

int ClosedM15VolumeFlowV122()
{
   if(!UseNativeVolumeFlow)
      return 0;

   int lookback = MathMax(3, VolumeLookbackBars);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_M15, 1, lookback + 1, rates);
   if(copied < lookback + 1)
      return 0;

   double volume_sum = 0.0;
   for(int i = 1; i <= lookback; i++)
      volume_sum += (double)rates[i].tick_volume;

   double average_volume = volume_sum / (double)lookback;
   if(average_volume <= 0.0)
      return 0;

   double strength = (double)rates[0].tick_volume / average_volume;
   if(strength >= VolumeFlowMinStrength && rates[0].close > rates[0].open)
      return 1;
   if(strength >= VolumeFlowMinStrength && rates[0].close < rates[0].open)
      return -1;
   return 0;
}

void UpdateDirectionalBiasV122()
{
   if(!UsarBiasDirecionalV122)
   {
      g_directionalBiasV122 = BIAS_NEUTRAL;
      g_biasConfidenceV122 = 0.0;
      return;
   }

   datetime closed_candle = iTime(_Symbol, PERIOD_M15, 1);
   if(closed_candle > 0 && g_lastBiasCandleV122 == closed_candle)
      return;

   int regime = DetectRegimeConfirmadoV121();
   int pa = ClosedM15PriceActionBiasV122();
   int flow = ClosedM15VolumeFlowV122();
   double score = (double)regime * 22.0 + (double)pa * 16.0 + (double)flow * 12.0;
   double confidence = 50.0 + MathMin(50.0, MathAbs(score));
   ENUM_DIRECTIONAL_BIAS_V122 raw_bias = BIAS_NEUTRAL;

   if(confidence >= BiasMinConfidence)
   {
      if(score >= 55.0)
         raw_bias = BIAS_STRONG_BUY;
      else if(score >= 15.0)
         raw_bias = BIAS_BUY;
      else if(score <= -55.0)
         raw_bias = BIAS_STRONG_SELL;
      else if(score <= -15.0)
         raw_bias = BIAS_SELL;
   }

   int current_sign = (g_directionalBiasV122 == BIAS_BUY || g_directionalBiasV122 == BIAS_STRONG_BUY ? 1 :
                       (g_directionalBiasV122 == BIAS_SELL || g_directionalBiasV122 == BIAS_STRONG_SELL ? -1 : 0));
   int raw_sign = (raw_bias == BIAS_BUY || raw_bias == BIAS_STRONG_BUY ? 1 :
                   (raw_bias == BIAS_SELL || raw_bias == BIAS_STRONG_SELL ? -1 : 0));
   if(current_sign != 0 && raw_sign != 0 && current_sign != raw_sign && confidence < BiasSwitchConfidence)
      raw_bias = BIAS_NEUTRAL;

   if(raw_bias == g_pendingBiasV122)
      g_biasStableBarsV122++;
   else
   {
      g_pendingBiasV122 = raw_bias;
      g_biasStableBarsV122 = 1;
   }

   if(g_biasStableBarsV122 >= MathMax(1, BiasConfirmationBars) && raw_bias != g_directionalBiasV122)
   {
      ENUM_DIRECTIONAL_BIAS_V122 old_bias = g_directionalBiasV122;
      g_directionalBiasV122 = raw_bias;
      LogMessage("[V122_BIAS_CHANGE] from=" + BiasToTextV122(old_bias) +
                 " to=" + BiasToTextV122(g_directionalBiasV122) +
                 " confidence=" + DoubleToString(confidence, 1));
   }

   g_biasConfidenceV122 = confidence;
   g_lastBiasCandleV122 = closed_candle;
   LogMessage("[V122_TARGET_ALLOCATION] bias=" + BiasToTextV122(g_directionalBiasV122) +
              " confidence=" + DoubleToString(g_biasConfidenceV122, 1) +
              " target_buy=" + IntegerToString(GetTargetBuySlotsV122()) +
              " target_sell=" + IntegerToString(GetTargetSellSlotsV122()));
}

double GetBiasConfidenceV122()
{
   return g_biasConfidenceV122;
}

int GetTargetBuySlotsV122()
{
   switch(g_directionalBiasV122)
   {
      case BIAS_STRONG_BUY: return (int)MathMin((double)TargetBuySlotsStrongBuy, (double)LimitBuyPositions());
      case BIAS_BUY: return (int)MathMin((double)TargetBuySlotsBuy, (double)LimitBuyPositions());
      case BIAS_SELL: return (int)MathMin((double)TargetBuySlotsSell, (double)LimitBuyPositions());
      case BIAS_STRONG_SELL: return (int)MathMin((double)TargetBuySlotsStrongSell, (double)LimitBuyPositions());
      default: return (int)MathMin((double)TargetBuySlotsNeutral, (double)LimitBuyPositions());
   }
}

int GetTargetSellSlotsV122()
{
   switch(g_directionalBiasV122)
   {
      case BIAS_STRONG_BUY: return (int)MathMin((double)TargetSellSlotsStrongBuy, (double)LimitSellPositions());
      case BIAS_BUY: return (int)MathMin((double)TargetSellSlotsBuy, (double)LimitSellPositions());
      case BIAS_SELL: return (int)MathMin((double)TargetSellSlotsSell, (double)LimitSellPositions());
      case BIAS_STRONG_SELL: return (int)MathMin((double)TargetSellSlotsStrongSell, (double)LimitSellPositions());
      default: return (int)MathMin((double)TargetSellSlotsNeutral, (double)LimitSellPositions());
   }
}

bool CanAddTowardBiasV122(ENUM_POSITION_TYPE direction, int side_slots_adjust) // V1.2.3.3 PENDING LIFECYCLE FIX
{
   if(!UsarBiasDirecionalV122)
      return true;

   // V1.2.3.3 PENDING LIFECYCLE FIX: ao reavaliar uma pendente existente o
   // ajuste (-1) remove o proprio slot dela; alocacao alvo permanece identica.
   int side_slots = (direction == POSITION_TYPE_BUY ? CountBuyExposureSlots() : CountSellExposureSlots());
   side_slots = MathMax(0, side_slots + side_slots_adjust);
   int target = (direction == POSITION_TYPE_BUY ? GetTargetBuySlotsV122() : GetTargetSellSlotsV122());
   if(side_slots >= target)
      return false;

   if(g_directionalBiasV122 == BIAS_NEUTRAL)
      return false;
   if(direction == POSITION_TYPE_BUY)
      return (g_directionalBiasV122 == BIAS_BUY || g_directionalBiasV122 == BIAS_STRONG_BUY);
   return (g_directionalBiasV122 == BIAS_SELL || g_directionalBiasV122 == BIAS_STRONG_SELL);
}

bool CanAddCounterBiasRecoveryV122(ENUM_POSITION_TYPE direction, int side_slots_adjust) // V1.2.3.3 PENDING LIFECYCLE FIX
{
   if(!UsarBiasDirecionalV122)
      return true;
   int side_slots = (direction == POSITION_TYPE_BUY ? CountBuyExposureSlots() : CountSellExposureSlots());
   side_slots = MathMax(0, side_slots + side_slots_adjust); // V1.2.3.3 PENDING LIFECYCLE FIX
   int target = (direction == POSITION_TYPE_BUY ? GetTargetBuySlotsV122() : GetTargetSellSlotsV122());
   return (side_slots < MathMax(1, target));
}

bool CanOpenPairV122(string &reason)
{
   reason = "OK";
   if(!AlwaysInMarket || !EA_makes_first_order)
   {
      reason = "always_in_market_desativado";
      return false;
   }
   if(CountOpenPositions() > 0)
   {
      reason = "posicao_existente";
      return false;
   }
   if(CountPendingOrders() > 0)
   {
      reason = "pendente_remanescente";
      return false;
   }
   if(!EntryPreflightV122("pair", false, reason))
      return false;

   double lot = NormalizeVolume(FixedLot);
   if(lot <= 0.0)
   {
      reason = "lote_invalido";
      return false;
   }
   if(!HasExposureRoomIncludingPendings(2))
   {
      reason = "sem_dois_slots";
      return false;
   }
   if(!HasDirectionalSlotRoom(POSITION_TYPE_BUY, 1, lot, reason))
      return false;
   if(!HasDirectionalSlotRoom(POSITION_TYPE_SELL, 1, lot, reason))
      return false;
   return true;
}

bool EntryPreflightV122(string source, bool ignore_pending_confirmation, string &reason)
{
   reason = "OK";
   if(!AllowTrading)
   {
      reason = "trading_desativado";
      return false;
   }
   if(!IsHedgingAccount())
   {
      reason = "conta_nao_hedging";
      return false;
   }
   if(BlockEntriesWhileClosing && IsClosingScopeActiveV122())
   {
      reason = "fechamento_em_andamento";
      return false;
   }
   if(!ignore_pending_confirmation && HasPendingTradeConfirmationV122())
   {
      reason = "confirmacao_servidor_pendente";
      return false;
   }
   if(!HasValidQuoteV122(reason))
      return false;
   if(!IsSpreadOK())
   {
      reason = "spread_alto";
      return false;
   }
   if(!IsTradingHourOK())
   {
      reason = "horario_bloqueado";
      return false;
   }
   if(IsNewsBlocked())
   {
      reason = "news_block";
      return false;
   }
   if(g_dailyLossBlocked || g_accountDailyLossBlocked)
   {
      reason = "loss_diario";
      return false;
   }
   if(g_dailyProfitBlocked)
   {
      reason = "meta_diaria";
      return false;
   }
   if(g_basketDDBlocked)
   {
      reason = "dd_bloqueado";
      return false;
   }
   return true;
}

bool HasValidQuoteV122(string &reason)
{
   if(g_tick.bid <= 0.0 || g_tick.ask <= 0.0 || g_tick.ask < g_tick.bid)
   {
      reason = "bid_ask_invalidos";
      return false;
   }
   if(MaxQuoteAgeSeconds > 0 && g_tick.time > 0)
   {
      int age = (int)(TimeCurrent() - (datetime)g_tick.time);
      if(age > MaxQuoteAgeSeconds)
      {
         reason = "tick_antigo_" + IntegerToString(age) + "s";
         return false;
      }
   }
   reason = "OK";
   return true;
}

bool IsMarketOpenForDirectionV122(ENUM_POSITION_TYPE direction, string &reason)
{
   reason = "OK";
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      reason = "terminal_ou_ea_sem_permissao";
      return false;
   }
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
   {
      reason = "conta_sem_permissao";
      return false;
   }
   ENUM_SYMBOL_TRADE_MODE mode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(mode == SYMBOL_TRADE_MODE_DISABLED || mode == SYMBOL_TRADE_MODE_CLOSEONLY)
   {
      reason = "trade_mode_fechado";
      return false;
   }
   if(direction == POSITION_TYPE_BUY && mode == SYMBOL_TRADE_MODE_SHORTONLY)
   {
      reason = "simbolo_short_only";
      return false;
   }
   if(direction == POSITION_TYPE_SELL && mode == SYMBOL_TRADE_MODE_LONGONLY)
   {
      reason = "simbolo_long_only";
      return false;
   }
   return true;
}

bool HasMarginForOrderV122(ENUM_ORDER_TYPE order_type, double lot, double price, string &reason, double &required_margin)
{
   required_margin = 0.0;
   ENUM_ORDER_TYPE calc_type = order_type;
   if(IsBuyPendingType(order_type))
      calc_type = ORDER_TYPE_BUY;
   else if(IsSellPendingType(order_type))
      calc_type = ORDER_TYPE_SELL;
   if(!OrderCalcMargin(calc_type, _Symbol, lot, price, required_margin))
   {
      reason = "order_calc_margin_fail";
      LogMessage("[V122_MARGIN_BLOCK] motivo=" + reason + " err=" + IntegerToString(GetLastError()));
      return false;
   }
   double available = AccountInfoDouble(ACCOUNT_MARGIN_FREE) - g_reservedMarginV122;
   if(required_margin > available + 0.0000001)
   {
      reason = "margem_insuficiente";
      LogMessage("[V122_MARGIN_BLOCK] required=" + DoubleToString(required_margin, 2) +
                 " available=" + DoubleToString(available, 2) +
                 " reserved=" + DoubleToString(g_reservedMarginV122, 2));
      return false;
   }
   reason = "OK";
   return true;
}

bool IsTradeRetcodeSuccessV122(uint retcode)
{
   return (retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_PLACED || retcode == TRADE_RETCODE_DONE_PARTIAL);
}

int UsedExposureSlotsV122()
{
   return CountOpenPositions() + CountPendingOrders() + g_reservedSlotsV122;
}

bool CanReserveSlotsV122(int slots, string &reason)
{
   if(slots <= 0)
   {
      reason = "OK";
      return true;
   }
   if(UsedExposureSlotsV122() + slots > LimitOpenPositions())
   {
      reason = "sem_slot_total";
      LogMessage("[V122_ENTRY_BLOCKED] motivo=" + reason +
                 " used=" + IntegerToString(UsedExposureSlotsV122()) +
                 " add=" + IntegerToString(slots) +
                 " limit=" + IntegerToString(LimitOpenPositions()));
      return false;
   }
   reason = "OK";
   return true;
}

bool ReserveSlotsV122(int slots, string reason)
{
   string block = "";
   if(!CanReserveSlotsV122(slots, block))
      return false;
   g_reservedSlotsV122 += MathMax(0, slots);
   LogMessage("[V122_SLOT_RESERVED] slots=" + IntegerToString(slots) +
              " reserved=" + IntegerToString(g_reservedSlotsV122) +
              " used=" + IntegerToString(UsedExposureSlotsV122()) + "/" + IntegerToString(LimitOpenPositions()) +
              " reason=" + reason);
   return true;
}

void ReleaseSlotsV122(int slots, string reason)
{
   int release = MathMax(0, MathMin(slots, g_reservedSlotsV122));
   if(release <= 0)
      return;
   g_reservedSlotsV122 -= release;
   LogMessage("[V122_SLOT_RELEASED] slots=" + IntegerToString(release) +
              " reserved=" + IntegerToString(g_reservedSlotsV122) +
              " used=" + IntegerToString(UsedExposureSlotsV122()) + "/" + IntegerToString(LimitOpenPositions()) +
              " reason=" + reason);
}

void ReserveMarginV122(double margin)
{
   if(margin > 0.0)
      g_reservedMarginV122 += margin;
}

void ReleaseMarginV122(double margin)
{
   if(margin <= 0.0)
      return;
   g_reservedMarginV122 = MathMax(0.0, g_reservedMarginV122 - margin);
}

bool SendMarketOrderV122(ENUM_POSITION_TYPE direction, string comment, bool reserve_slot, bool ignore_pending_confirmation, bool &confirmed, string &reason)
{
   confirmed = false;
   reason = "OK";

   if(direction == POSITION_TYPE_BUY && !Allow_BUY)
   {
      reason = "buy_desativado";
      return false;
   }
   if(direction == POSITION_TYPE_SELL && !Allow_SELL)
   {
      reason = "sell_desativado";
      return false;
   }

   double lot = NormalizeVolume(FixedLot);
   if(lot <= 0.0)
   {
      reason = "lote_invalido";
      return false;
   }

   if(reserve_slot && !ReserveSlotsV122(1, comment))
   {
      reason = "sem_slot_total";
      return false;
   }

   if(!EntryPreflightV122(comment, ignore_pending_confirmation, reason))
   {
      if(reserve_slot)
         ReleaseSlotsV122(1, "preflight_fail");
      LogEntryBlockedV122(comment, reason);
      return false;
   }

   if(!IsMarketOpenForDirectionV122(direction, reason))
   {
      if(reserve_slot)
         ReleaseSlotsV122(1, "market_closed");
      LogEntryBlockedV122(comment, reason);
      return false;
   }

   ENUM_ORDER_TYPE order_type = (direction == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   double price = (direction == POSITION_TYPE_BUY ? g_tick.ask : g_tick.bid);
   double required_margin = 0.0;
   if(!HasMarginForOrderV122(order_type, lot, price, reason, required_margin))
   {
      if(reserve_slot)
         ReleaseSlotsV122(1, "margin_fail");
      return false;
   }

   int expected_count = (direction == POSITION_TYPE_BUY ? CountBuyPositions() + 1 : CountSellPositions() + 1);
   bool sent = false;
   if(direction == POSITION_TYPE_BUY)
      sent = trade.Buy(lot, _Symbol, 0.0, 0.0, 0.0, comment);
   else
      sent = trade.Sell(lot, _Symbol, 0.0, 0.0, 0.0, comment);

   uint retcode = trade.ResultRetcode();
   if(!sent || !IsTradeRetcodeSuccessV122(retcode))
   {
      reason = "retcode_" + IntegerToString((int)retcode);
      LogMessage("[V122_ENTRY_BLOCKED] source=" + comment + " motivo=" + reason +
                 " desc=" + trade.ResultRetcodeDescription());
      if(reserve_slot)
         ReleaseSlotsV122(1, "send_fail");
      return false;
   }

   RebuildExposureStateFromServer();
   confirmed = ConfirmMarketPositionV122(direction, expected_count);
   if(confirmed)
   {
      if(reserve_slot)
         ReleaseSlotsV122(1, "market_confirmed_immediate");
   }
   else
      MarkMarketRequestPendingV122(direction, expected_count, required_margin);

   datetime now = TimeCurrent();
   g_lastPairOpenTime = now;
   g_lastPairCandleTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   g_lastPairMidPrice = MidPrice();
   if(direction == POSITION_TYPE_BUY)
   {
      g_lastBuyLevelPrice = g_tick.ask;
      g_lastBuyLevelTime = now;
   }
   else
   {
      g_lastSellLevelPrice = g_tick.bid;
      g_lastSellLevelTime = now;
   }
   PersistBasketState();
   return true;
}

bool ConfirmMarketPositionV122(ENUM_POSITION_TYPE direction, int expected_count)
{
   if(direction == POSITION_TYPE_BUY)
      return (CountBuyPositions() >= expected_count);
   return (CountSellPositions() >= expected_count);
}

bool HasPendingTradeConfirmationV122()
{
   return (g_buyRebalancePendingConfirmation || g_sellRebalancePendingConfirmation ||
           g_pendingOrderConfirmationV122 || g_pendingCancelConfirmationV122 ||
           AnyPendingLifecycleBusyV1231());
}

void MarkMarketRequestPendingV122(ENUM_POSITION_TYPE direction, int expected_count, double reserved_margin)
{
   g_tradeRequestSinceV122 = TimeCurrent();
   if(direction == POSITION_TYPE_BUY)
   {
      g_buyRebalancePendingConfirmation = true;
      g_expectedBuyPositionCountV122 = expected_count;
      g_buyReservedMarginV122 += MathMax(0.0, reserved_margin);
   }
   else
   {
      g_sellRebalancePendingConfirmation = true;
      g_expectedSellPositionCountV122 = expected_count;
      g_sellReservedMarginV122 += MathMax(0.0, reserved_margin);
   }
   ReserveMarginV122(reserved_margin);
}

void MarkPendingOrderRequestV122(int expected_count, double reserved_margin)
{
   g_pendingOrderConfirmationV122 = true;
   g_expectedPendingOrdersV122 = expected_count;
   g_pendingReservedMarginV122 += MathMax(0.0, reserved_margin);
   g_tradeRequestSinceV122 = TimeCurrent();
   ReserveMarginV122(reserved_margin);
}

void MarkPendingCancelRequestV122(int expected_count)
{
   g_pendingCancelConfirmationV122 = true;
   g_expectedPendingOrdersV122 = expected_count;
   g_tradeRequestSinceV122 = TimeCurrent();
   g_tradeStateDirty = true;
}

void ReconcileTradeRequestsV122()
{
   bool legacy_confirmation = (g_buyRebalancePendingConfirmation || g_sellRebalancePendingConfirmation ||
                               g_pendingOrderConfirmationV122 || g_pendingCancelConfirmationV122);
   if(!legacy_confirmation)
      return;

   if(g_buyRebalancePendingConfirmation && CountBuyPositions() >= g_expectedBuyPositionCountV122)
   {
      g_buyRebalancePendingConfirmation = false;
      ReleaseSlotsV122(1, "buy_confirmed_server");
      ReleaseMarginV122(g_buyReservedMarginV122);
      g_buyReservedMarginV122 = 0.0;
   }
   if(g_sellRebalancePendingConfirmation && CountSellPositions() >= g_expectedSellPositionCountV122)
   {
      g_sellRebalancePendingConfirmation = false;
      ReleaseSlotsV122(1, "sell_confirmed_server");
      ReleaseMarginV122(g_sellReservedMarginV122);
      g_sellReservedMarginV122 = 0.0;
   }
   if(g_pendingOrderConfirmationV122 && CountPendingOrders() >= g_expectedPendingOrdersV122)
   {
      g_pendingOrderConfirmationV122 = false;
      ReleaseSlotsV122(1, "pending_confirmed_server");
      ReleaseMarginV122(g_pendingReservedMarginV122);
      g_pendingReservedMarginV122 = 0.0;
   }
   if(g_pendingCancelConfirmationV122 && CountPendingOrders() <= g_expectedPendingOrdersV122)
      g_pendingCancelConfirmationV122 = false;

   legacy_confirmation = (g_buyRebalancePendingConfirmation || g_sellRebalancePendingConfirmation ||
                          g_pendingOrderConfirmationV122 || g_pendingCancelConfirmationV122);
   if(!legacy_confirmation)
      return;

   int timeout = MathMax(1, TradeReconciliationTimeoutSeconds);
   if(g_tradeRequestSinceV122 > 0 && (int)(TimeCurrent() - g_tradeRequestSinceV122) >= timeout)
   {
      LogMessage("[V122_SERVER_CONFIRM_FAIL] timeout=" + IntegerToString(timeout) +
                 " buy_pending=" + (g_buyRebalancePendingConfirmation ? "true" : "false") +
                 " sell_pending=" + (g_sellRebalancePendingConfirmation ? "true" : "false") +
                 " pending_order=" + (g_pendingOrderConfirmationV122 ? "true" : "false"));
      if(g_buyRebalancePendingConfirmation)
      {
         g_buyRebalancePendingConfirmation = false;
         ReleaseSlotsV122(1, "buy_confirm_timeout");
         ReleaseMarginV122(g_buyReservedMarginV122);
         g_buyReservedMarginV122 = 0.0;
      }
      if(g_sellRebalancePendingConfirmation)
      {
         g_sellRebalancePendingConfirmation = false;
         ReleaseSlotsV122(1, "sell_confirm_timeout");
         ReleaseMarginV122(g_sellReservedMarginV122);
         g_sellReservedMarginV122 = 0.0;
      }
      if(g_pendingOrderConfirmationV122)
      {
         g_pendingOrderConfirmationV122 = false;
         ReleaseSlotsV122(1, "pending_confirm_timeout");
         ReleaseMarginV122(g_pendingReservedMarginV122);
         g_pendingReservedMarginV122 = 0.0;
      }
      g_pendingCancelConfirmationV122 = false;
   }
}

string PendingLifecycleStateTextV1231(ENUM_PENDING_LIFECYCLE_V1231 state)
{
   if(state == PENDING_LIFECYCLE_CREATE_REQUESTED) return "CREATE_REQUESTED";
   if(state == PENDING_LIFECYCLE_ACTIVE) return "ACTIVE";
   if(state == PENDING_LIFECYCLE_MODIFY_REQUESTED) return "MODIFY_REQUESTED";
   if(state == PENDING_LIFECYCLE_CANCEL_REQUESTED) return "CANCEL_REQUESTED";
   if(state == PENDING_LIFECYCLE_CONFIRMING) return "CONFIRMING";
   return "NONE";
}

string PendingActionTextV1231(ENUM_PENDING_ACTION_V1231 action)
{
   if(action == PENDING_ACTION_CREATE) return "CREATE";
   if(action == PENDING_ACTION_MODIFY) return "MODIFY";
   if(action == PENDING_ACTION_CANCEL) return "CANCEL";
   return "NONE";
}

bool PendingLifecycleBusyV1231(bool buy_side)
{
   ENUM_PENDING_LIFECYCLE_V1231 state = (buy_side ? g_buyPendingStateV1231 : g_sellPendingStateV1231);
   return (state == PENDING_LIFECYCLE_CREATE_REQUESTED ||
           state == PENDING_LIFECYCLE_MODIFY_REQUESTED ||
           state == PENDING_LIFECYCLE_CANCEL_REQUESTED ||
           state == PENDING_LIFECYCLE_CONFIRMING);
}

bool AnyPendingLifecycleBusyV1231()
{
   return (PendingLifecycleBusyV1231(true) || PendingLifecycleBusyV1231(false));
}

bool FindPendingSideV1231(bool buy_side, ulong &ticket, ENUM_ORDER_TYPE &type, double &price)
{
   ticket = 0;
   price = 0.0;
   type = (buy_side ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP);
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong current_ticket = OrderGetTicket(i);
      if(current_ticket == 0)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (long)OrderGetInteger(ORDER_MAGIC) != MagicNumber)
         continue;
      ENUM_ORDER_TYPE current_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(!IsPendingOrderType(current_type))
         continue;
      if(buy_side != IsBuyPendingType(current_type))
         continue;
      ticket = current_ticket;
      type = current_type;
      price = OrderGetDouble(ORDER_PRICE_OPEN);
      return true;
   }
   return false;
}

bool PendingTicketExistsV1231(ulong ticket, ENUM_ORDER_TYPE &type, double &price)
{
   if(ticket == 0)
      return false;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong current_ticket = OrderGetTicket(i);
      if(current_ticket != ticket)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (long)OrderGetInteger(ORDER_MAGIC) != MagicNumber)
         return false;
      type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(!IsPendingOrderType(type))
         return false;
      price = OrderGetDouble(ORDER_PRICE_OPEN);
      return true;
   }
   return false;
}

void LogPendingLifecycleV1231(string tag, bool buy_side,
                              ENUM_PENDING_LIFECYCLE_V1231 old_state,
                              ENUM_PENDING_LIFECYCLE_V1231 new_state,
                              ulong ticket, ENUM_ORDER_TYPE type,
                              double current_price, double desired_price,
                              ENUM_PENDING_ACTION_V1231 action, string reason)
{
   LogMessage(tag + " lado=" + (buy_side ? "BUY" : "SELL") +
              " estado_anterior=" + PendingLifecycleStateTextV1231(old_state) +
              " estado_novo=" + PendingLifecycleStateTextV1231(new_state) +
              " ticket=" + IntegerToString((int)ticket) +
              " tipo=" + EnumToString(type) +
              " preco_atual=" + DoubleToString(current_price, _Digits) +
              " preco_desejado=" + DoubleToString(desired_price, _Digits) +
              " pendentes=" + IntegerToString(CountPendingOrders()) +
              " slots=" + IntegerToString(UsedExposureSlotsV122()) + "/" + IntegerToString(LimitOpenPositions()) +
              " acao=" + PendingActionTextV1231(action) +
              " motivo=" + reason);
}

void SetPendingLifecycleV1231(bool buy_side, ENUM_PENDING_LIFECYCLE_V1231 new_state,
                              ENUM_PENDING_ACTION_V1231 action, ulong ticket,
                              ENUM_ORDER_TYPE type, double requested_price, string reason)
{
   ENUM_PENDING_LIFECYCLE_V1231 old_state = (buy_side ? g_buyPendingStateV1231 : g_sellPendingStateV1231);
   double current_price = 0.0;
   ENUM_ORDER_TYPE current_type = type;
   PendingTicketExistsV1231(ticket, current_type, current_price);

   if(buy_side)
   {
      g_buyPendingStateV1231 = new_state;
      g_buyPendingActionV1231 = action;
      g_buyPendingTicketV1231 = ticket;
      g_buyPendingExpectedTypeV1231 = type;
      g_buyPendingRequestedPriceV1231 = requested_price;
      g_buyPendingLastReasonV1231 = reason;
      if(new_state == PENDING_LIFECYCLE_CREATE_REQUESTED ||
         new_state == PENDING_LIFECYCLE_MODIFY_REQUESTED ||
         new_state == PENDING_LIFECYCLE_CANCEL_REQUESTED)
         g_buyPendingRequestTimeV1231 = TimeCurrent();
      else if(new_state == PENDING_LIFECYCLE_NONE || new_state == PENDING_LIFECYCLE_ACTIVE)
         g_buyPendingRequestTimeV1231 = 0;
   }
   else
   {
      g_sellPendingStateV1231 = new_state;
      g_sellPendingActionV1231 = action;
      g_sellPendingTicketV1231 = ticket;
      g_sellPendingExpectedTypeV1231 = type;
      g_sellPendingRequestedPriceV1231 = requested_price;
      g_sellPendingLastReasonV1231 = reason;
      if(new_state == PENDING_LIFECYCLE_CREATE_REQUESTED ||
         new_state == PENDING_LIFECYCLE_MODIFY_REQUESTED ||
         new_state == PENDING_LIFECYCLE_CANCEL_REQUESTED)
         g_sellPendingRequestTimeV1231 = TimeCurrent();
      else if(new_state == PENDING_LIFECYCLE_NONE || new_state == PENDING_LIFECYCLE_ACTIVE)
         g_sellPendingRequestTimeV1231 = 0;
   }

   LogPendingLifecycleV1231("[V1231_PENDING_STATE_CHANGE]", buy_side, old_state, new_state,
                            ticket, type, current_price, requested_price, action, reason);
}

void ReleasePendingReservationV1231(bool buy_side, string reason)
{
   bool reserved = (buy_side ? g_buyPendingSlotReservedV1231 : g_sellPendingSlotReservedV1231);
   double margin = (buy_side ? g_buyPendingReservedMarginV1231 : g_sellPendingReservedMarginV1231);
   if(reserved)
      ReleaseSlotsV122(1, reason);
   if(margin > 0.0)
      ReleaseMarginV122(margin);
   if(buy_side)
   {
      g_buyPendingSlotReservedV1231 = false;
      g_buyPendingReservedMarginV1231 = 0.0;
   }
   else
   {
      g_sellPendingSlotReservedV1231 = false;
      g_sellPendingReservedMarginV1231 = 0.0;
   }
}

void InitializePendingSideV1231(bool buy_side)
{
   ulong ticket = 0;
   ENUM_ORDER_TYPE type;
   double price = 0.0;
   bool exists = FindPendingSideV1231(buy_side, ticket, type, price);
   if(buy_side)
   {
      g_buyPendingSlotReservedV1231 = false;
      g_buyPendingReservedMarginV1231 = 0.0;
      g_buyPendingExpectedCountV1231 = (exists ? 1 : 0);
   }
   else
   {
      g_sellPendingSlotReservedV1231 = false;
      g_sellPendingReservedMarginV1231 = 0.0;
      g_sellPendingExpectedCountV1231 = (exists ? 1 : 0);
   }
   SetPendingLifecycleV1231(buy_side,
                            (exists ? PENDING_LIFECYCLE_ACTIVE : PENDING_LIFECYCLE_NONE),
                            PENDING_ACTION_NONE, ticket, type, price, "reconstrucao_init_servidor");
}

void InitializePendingLifecycleV1231()
{
   InitializePendingSideV1231(true);
   InitializePendingSideV1231(false);
   LogMessage("[V1231_PENDING_LIFECYCLE_SUMMARY] origem=init buy=" +
              PendingLifecycleStateTextV1231(g_buyPendingStateV1231) +
              " sell=" + PendingLifecycleStateTextV1231(g_sellPendingStateV1231) +
              " pendentes=" + IntegerToString(CountPendingOrders()));
}

void ReconcilePendingSideV1231(bool buy_side)
{
   ENUM_PENDING_LIFECYCLE_V1231 state = (buy_side ? g_buyPendingStateV1231 : g_sellPendingStateV1231);
   ENUM_PENDING_ACTION_V1231 action = (buy_side ? g_buyPendingActionV1231 : g_sellPendingActionV1231);
   ulong expected_ticket = (buy_side ? g_buyPendingTicketV1231 : g_sellPendingTicketV1231);
   ENUM_ORDER_TYPE expected_type = (buy_side ? g_buyPendingExpectedTypeV1231 : g_sellPendingExpectedTypeV1231);
   double requested_price = (buy_side ? g_buyPendingRequestedPriceV1231 : g_sellPendingRequestedPriceV1231);
   datetime request_time = (buy_side ? g_buyPendingRequestTimeV1231 : g_sellPendingRequestTimeV1231);

   ulong actual_ticket = 0;
   ENUM_ORDER_TYPE actual_type;
   double actual_price = 0.0;
   bool side_exists = FindPendingSideV1231(buy_side, actual_ticket, actual_type, actual_price);
   ENUM_ORDER_TYPE ticket_type = expected_type;
   double ticket_price = 0.0;
   bool expected_ticket_exists = PendingTicketExistsV1231(expected_ticket, ticket_type, ticket_price);

   if(state == PENDING_LIFECYCLE_ACTIVE)
   {
      if(!side_exists)
      {
         g_pendingExecutionsV1231++;
         SetPendingLifecycleV1231(buy_side, PENDING_LIFECYCLE_NONE, PENDING_ACTION_NONE,
                                  0, expected_type, 0.0, "ordem_ativa_ausente_no_servidor");
      }
      else if(actual_ticket != expected_ticket)
      {
         SetPendingLifecycleV1231(buy_side, PENDING_LIFECYCLE_ACTIVE, PENDING_ACTION_NONE,
                                  actual_ticket, actual_type, actual_price, "ticket_ativo_reconciliado");
      }
      return;
   }

   if(state == PENDING_LIFECYCLE_NONE)
   {
      if(side_exists)
         SetPendingLifecycleV1231(buy_side, PENDING_LIFECYCLE_ACTIVE, PENDING_ACTION_NONE,
                                  actual_ticket, actual_type, actual_price, "ordem_encontrada_no_servidor");
      return;
   }

   bool confirmed = false;
   string confirm_tag = "";
   if(action == PENDING_ACTION_CREATE && side_exists)
   {
      confirmed = true;
      confirm_tag = "[V1231_PENDING_CREATE_CONFIRMED]";
      ReleasePendingReservationV1231(buy_side, "pending_create_confirmed_v1231");
   }
   else if(action == PENDING_ACTION_CANCEL && !expected_ticket_exists)
   {
      confirmed = true;
      confirm_tag = "[V1231_PENDING_CANCEL_CONFIRMED]";
   }
   else if(action == PENDING_ACTION_MODIFY && expected_ticket_exists)
   {
      double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double tolerance = MathMax(_Point, tick_size);
      if(ticket_type == expected_type && MathAbs(ticket_price - requested_price) <= tolerance)
      {
         confirmed = true;
         confirm_tag = "[V1231_PENDING_MODIFY_CONFIRMED]";
      }
   }

   if(confirmed)
   {
      ulong final_ticket = (side_exists ? actual_ticket : 0);
      ENUM_ORDER_TYPE final_type = (side_exists ? actual_type : expected_type);
      double final_price = (side_exists ? actual_price : 0.0);
      LogPendingLifecycleV1231(confirm_tag, buy_side, state,
                               (side_exists ? PENDING_LIFECYCLE_ACTIVE : PENDING_LIFECYCLE_NONE),
                               expected_ticket, final_type, final_price, requested_price, action, "servidor_confirmado");
      SetPendingLifecycleV1231(buy_side,
                               (side_exists ? PENDING_LIFECYCLE_ACTIVE : PENDING_LIFECYCLE_NONE),
                               PENDING_ACTION_NONE, final_ticket, final_type, final_price, "servidor_confirmado");
      return;
   }

   int timeout = MathMax(1, TradeReconciliationTimeoutSeconds);
   if(request_time > 0 && (int)(TimeCurrent() - request_time) >= timeout)
   {
      g_pendingTimeoutsV1231++;
      RebuildExposureStateFromServer();
      LogPendingLifecycleV1231("[V1231_PENDING_TIMEOUT_REBUILD]", buy_side, state, state,
                               expected_ticket, expected_type, ticket_price, requested_price, action,
                               "timeout_rebuild_servidor");
      if(action == PENDING_ACTION_CREATE)
      {
         ReleasePendingReservationV1231(buy_side, "pending_create_timeout_v1231");
         if(side_exists)
            SetPendingLifecycleV1231(buy_side, PENDING_LIFECYCLE_ACTIVE, PENDING_ACTION_NONE,
                                     actual_ticket, actual_type, actual_price, "timeout_ordem_encontrada");
         else
            SetPendingLifecycleV1231(buy_side, PENDING_LIFECYCLE_NONE, PENDING_ACTION_NONE,
                                     0, expected_type, 0.0, "timeout_sem_ordem");
      }
      else if(action == PENDING_ACTION_CANCEL)
      {
         SetPendingLifecycleV1231(buy_side,
                                  (expected_ticket_exists ? PENDING_LIFECYCLE_ACTIVE : PENDING_LIFECYCLE_NONE),
                                  PENDING_ACTION_NONE,
                                  (expected_ticket_exists ? expected_ticket : 0), ticket_type, ticket_price,
                                  (expected_ticket_exists ? "timeout_ticket_ainda_ativo" : "timeout_cancel_confirmado"));
      }
      else
      {
         SetPendingLifecycleV1231(buy_side,
                                  (side_exists ? PENDING_LIFECYCLE_ACTIVE : PENDING_LIFECYCLE_NONE),
                                  PENDING_ACTION_NONE, actual_ticket, actual_type, actual_price,
                                  "timeout_modify_reconciliado");
      }
      return;
   }

   if(state != PENDING_LIFECYCLE_CONFIRMING)
      SetPendingLifecycleV1231(buy_side, PENDING_LIFECYCLE_CONFIRMING, action,
                               expected_ticket, expected_type, requested_price, "aguardando_servidor");
}

void ReconcilePendingLifecycleV1231()
{
   ReconcilePendingSideV1231(true);
   ReconcilePendingSideV1231(false);
}

bool PendingActionGuardV1231(bool buy_side, ENUM_PENDING_ACTION_V1231 action,
                             ulong ticket, ENUM_ORDER_TYPE type, double desired_price, string reason)
{
   if(g_pendingMutationSentThisTickV1231)
   {
      g_pendingBusyBlocksV1231++;
      LogPendingLifecycleV1231("[V1231_PENDING_ACTION_BUSY]", buy_side,
                               (buy_side ? g_buyPendingStateV1231 : g_sellPendingStateV1231),
                               (buy_side ? g_buyPendingStateV1231 : g_sellPendingStateV1231),
                               ticket, type, 0.0, desired_price, action, "mutacao_ja_enviada_neste_tick");
      return false;
   }
   if(AnyPendingLifecycleBusyV1231())
   {
      datetime now = TimeCurrent();
      datetime last_log = (buy_side ? g_buyPendingLastBusyLogV1231 : g_sellPendingLastBusyLogV1231);
      g_pendingBusyBlocksV1231++;
      if(last_log <= 0 || now - last_log >= MathMax(1, TradeReconciliationTimeoutSeconds))
      {
         LogPendingLifecycleV1231("[V1231_PENDING_ACTION_BUSY]", buy_side,
                                  (buy_side ? g_buyPendingStateV1231 : g_sellPendingStateV1231),
                                  (buy_side ? g_buyPendingStateV1231 : g_sellPendingStateV1231),
                                  ticket, type, 0.0, desired_price, action,
                                  reason + "_confirmacao_global_em_andamento");
         if(buy_side) g_buyPendingLastBusyLogV1231 = now;
         else g_sellPendingLastBusyLogV1231 = now;
      }
      return false;
   }
   return true;
}

bool RequestPendingCreateV1231(bool buy_side, ENUM_ORDER_TYPE desired_type, double desired_price,
                               double required_margin, string reason)
{
   datetime last_cancel = (buy_side ? g_buyPendingLastCancelTimeV1231 : g_sellPendingLastCancelTimeV1231);
   if(last_cancel > 0 && TimeCurrent() <= last_cancel)
   {
      datetime last_log = (buy_side ? g_buyPendingLastBusyLogV1231 : g_sellPendingLastBusyLogV1231);
      if(last_log != TimeCurrent())
      {
         LogPendingLifecycleV1231("[V1231_PENDING_CREATE_BLOCKED]", buy_side,
                                  (buy_side ? g_buyPendingStateV1231 : g_sellPendingStateV1231),
                                  (buy_side ? g_buyPendingStateV1231 : g_sellPendingStateV1231),
                                  0, desired_type, 0.0, desired_price, PENDING_ACTION_CREATE,
                                  "cancelamento_confirmado_no_mesmo_segundo");
         if(buy_side) g_buyPendingLastBusyLogV1231 = TimeCurrent();
         else g_sellPendingLastBusyLogV1231 = TimeCurrent();
      }
      return false;
   }
   if(!PendingActionGuardV1231(buy_side, PENDING_ACTION_CREATE, 0, desired_type, desired_price, reason))
      return false;

   ulong existing_ticket = 0;
   ENUM_ORDER_TYPE existing_type;
   double existing_price = 0.0;
   if(FindPendingSideV1231(buy_side, existing_ticket, existing_type, existing_price))
   {
      LogPendingLifecycleV1231("[V1231_PENDING_CREATE_BLOCKED]", buy_side,
                               (buy_side ? g_buyPendingStateV1231 : g_sellPendingStateV1231),
                               PENDING_LIFECYCLE_ACTIVE, existing_ticket, existing_type,
                               existing_price, desired_price, PENDING_ACTION_CREATE, "ticket_real_ja_existe");
      SetPendingLifecycleV1231(buy_side, PENDING_LIFECYCLE_ACTIVE, PENDING_ACTION_NONE,
                               existing_ticket, existing_type, existing_price, "ticket_real_ja_existe");
      return false;
   }

   if(!ReserveSlotsV122(1, (buy_side ? "pending_buy_v1231" : "pending_sell_v1231")))
      return false;

   datetime expiration = 0;
   ENUM_ORDER_TYPE_TIME time_type = ORDER_TIME_GTC;
   if(PendingOrderExpirationMinutes > 0)
   {
      expiration = TimeCurrent() + PendingOrderExpirationMinutes * 60;
      time_type = ORDER_TIME_SPECIFIED;
   }

   double lot = NormalizeVolume(FixedLot);
   bool ok = false;
   if(desired_type == ORDER_TYPE_BUY_STOP)
      ok = trade.BuyStop(lot, desired_price, _Symbol, 0.0, 0.0, time_type, expiration, "IA_FG_BUY_PENDING");
   else if(desired_type == ORDER_TYPE_BUY_LIMIT)
      ok = trade.BuyLimit(lot, desired_price, _Symbol, 0.0, 0.0, time_type, expiration, "IA_FG_BUY_PENDING");
   else if(desired_type == ORDER_TYPE_SELL_STOP)
      ok = trade.SellStop(lot, desired_price, _Symbol, 0.0, 0.0, time_type, expiration, "IA_FG_SELL_PENDING");
   else if(desired_type == ORDER_TYPE_SELL_LIMIT)
      ok = trade.SellLimit(lot, desired_price, _Symbol, 0.0, 0.0, time_type, expiration, "IA_FG_SELL_PENDING");

   g_pendingMutationSentThisTickV1231 = true;
   uint retcode = trade.ResultRetcode();
   if(!ok || !IsTradeRetcodeSuccessV122(retcode))
   {
      ReleaseSlotsV122(1, "pending_create_send_fail_v1231");
      LogPendingLifecycleV1231("[V1231_PENDING_CREATE_BLOCKED]", buy_side,
                               (buy_side ? g_buyPendingStateV1231 : g_sellPendingStateV1231),
                               (buy_side ? g_buyPendingStateV1231 : g_sellPendingStateV1231),
                               0, desired_type, 0.0, desired_price, PENDING_ACTION_CREATE,
                               "retcode_" + IntegerToString((int)retcode));
      return false;
   }

   ulong requested_ticket = trade.ResultOrder();
   ReserveMarginV122(required_margin);
   if(buy_side)
   {
      g_buyPendingSlotReservedV1231 = true;
      g_buyPendingReservedMarginV1231 = MathMax(0.0, required_margin);
      g_buyPendingExpectedCountV1231 = 1;
      g_buyPendingLastCreateTimeV1232 = TimeCurrent();
      g_pendingCreatesBuyV1231++;
   }
   else
   {
      g_sellPendingSlotReservedV1231 = true;
      g_sellPendingReservedMarginV1231 = MathMax(0.0, required_margin);
      g_sellPendingExpectedCountV1231 = 1;
      g_sellPendingLastCreateTimeV1232 = TimeCurrent();
      g_pendingCreatesSellV1231++;
   }
   SetPendingLifecycleV1231(buy_side, PENDING_LIFECYCLE_CREATE_REQUESTED, PENDING_ACTION_CREATE,
                            requested_ticket, desired_type, desired_price, reason);
   LogPendingLifecycleV1231("[V1231_PENDING_CREATE_REQUEST]", buy_side,
                            PENDING_LIFECYCLE_NONE, PENDING_LIFECYCLE_CREATE_REQUESTED,
                            requested_ticket, desired_type, 0.0, desired_price, PENDING_ACTION_CREATE, reason);
   return true;
}

bool RequestPendingModifyV1231(bool buy_side, ulong ticket, double desired_price, string reason)
{
   ENUM_ORDER_TYPE current_type;
   double current_price = 0.0;
   if(!PendingTicketExistsV1231(ticket, current_type, current_price))
   {
      LogPendingLifecycleV1231("[V1231_PENDING_MODIFY_SKIPPED]", buy_side,
                               (buy_side ? g_buyPendingStateV1231 : g_sellPendingStateV1231),
                               PENDING_LIFECYCLE_NONE, ticket,
                               (buy_side ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP),
                               0.0, desired_price, PENDING_ACTION_MODIFY, "ticket_ausente");
      return false;
   }
   if(!PendingActionGuardV1231(buy_side, PENDING_ACTION_MODIFY, ticket, current_type, desired_price, reason))
      return false;

   double current_sl = OrderGetDouble(ORDER_SL);
   double current_tp = OrderGetDouble(ORDER_TP);
   double stop_limit = OrderGetDouble(ORDER_PRICE_STOPLIMIT);
   ENUM_ORDER_TYPE_TIME time_type = (ENUM_ORDER_TYPE_TIME)OrderGetInteger(ORDER_TYPE_TIME);
   datetime expiration = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
   bool ok = trade.OrderModify(ticket, NormalizePrice(desired_price), current_sl, current_tp,
                               time_type, expiration, stop_limit);
   g_pendingMutationSentThisTickV1231 = true;
   uint retcode = trade.ResultRetcode();
   if(!ok || !IsTradeRetcodeSuccessV122(retcode))
   {
      LogPendingLifecycleV1231("[V1231_PENDING_MODIFY_SKIPPED]", buy_side,
                               (buy_side ? g_buyPendingStateV1231 : g_sellPendingStateV1231),
                               (buy_side ? g_buyPendingStateV1231 : g_sellPendingStateV1231),
                               ticket, current_type, current_price, desired_price, PENDING_ACTION_MODIFY,
                               "retcode_" + IntegerToString((int)retcode));
      return false;
   }
   if(buy_side) g_pendingModifiesBuyV1231++;
   else g_pendingModifiesSellV1231++;
   SetPendingLifecycleV1231(buy_side, PENDING_LIFECYCLE_MODIFY_REQUESTED, PENDING_ACTION_MODIFY,
                            ticket, current_type, desired_price, reason);
   LogPendingLifecycleV1231("[V1231_PENDING_MODIFY_REQUEST]", buy_side,
                            PENDING_LIFECYCLE_ACTIVE, PENDING_LIFECYCLE_MODIFY_REQUESTED,
                            ticket, current_type, current_price, desired_price, PENDING_ACTION_MODIFY, reason);
   return true;
}

bool RequestPendingCancelV1231(bool buy_side, ulong ticket, ENUM_PENDING_CANCEL_REASON_V1233 reason_code, string reason, bool global_scope) // V1.2.3.3 PENDING LIFECYCLE FIX
{
   datetime last_create = (buy_side ? g_buyPendingLastCreateTimeV1232 : g_sellPendingLastCreateTimeV1232);
   bool emergency_cancel = global_scope;
   if(!emergency_cancel && last_create > 0 && TimeCurrent() <= last_create)
   {
      LogThrottledV1232("cancel_same_second_" + (buy_side ? "BUY" : "SELL") + "_" + reason,
                        "[V1232_PENDING_CANCEL_BLOCKED_SAME_SECOND] lado=" + (buy_side ? "BUY" : "SELL") +
                        " ticket=" + IntegerToString((int)ticket) + " motivo=" + reason, 1);
      return false;
   }
   ENUM_ORDER_TYPE current_type = (buy_side ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP);
   double current_price = 0.0;
   if(!PendingTicketExistsV1231(ticket, current_type, current_price))
   {
      LogPendingLifecycleV1231("[V1231_PENDING_CANCEL_BLOCKED]", buy_side,
                               (buy_side ? g_buyPendingStateV1231 : g_sellPendingStateV1231),
                               PENDING_LIFECYCLE_NONE, ticket, current_type, 0.0, 0.0,
                               PENDING_ACTION_CANCEL, "ticket_ja_ausente");
      return false;
   }
   if(!PendingActionGuardV1231(buy_side, PENDING_ACTION_CANCEL, ticket, current_type, 0.0, reason))
      return false;

   // V1.2.3.3 PENDING LIFECYCLE FIX: idade e contexto capturados antes da mutacao
   datetime setup_time = 0;
   if(OrderSelect(ticket))
      setup_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
   int order_age = (setup_time > 0 ? (int)(TimeCurrent() - setup_time) : -1);

   int expected_side_count = MathMax(0, (buy_side ? CountPendingBuyOrders() : CountPendingSellOrders()) - 1);
   bool ok = trade.OrderDelete(ticket);
   g_pendingMutationSentThisTickV1231 = true;
   uint retcode = trade.ResultRetcode();
   if(!ok || !IsTradeRetcodeSuccessV122(retcode))
   {
      LogPendingLifecycleV1231("[V1231_PENDING_CANCEL_BLOCKED]", buy_side,
                               (buy_side ? g_buyPendingStateV1231 : g_sellPendingStateV1231),
                               (buy_side ? g_buyPendingStateV1231 : g_sellPendingStateV1231),
                               ticket, current_type, current_price, 0.0, PENDING_ACTION_CANCEL,
                               "retcode_" + IntegerToString((int)retcode));
      return false;
   }
   if(buy_side)
   {
      g_buyPendingExpectedCountV1231 = expected_side_count;
      g_buyPendingLastCancelTimeV1231 = TimeCurrent();
      g_pendingCancelsBuyV1231++;
   }
   else
   {
      g_sellPendingExpectedCountV1231 = expected_side_count;
      g_sellPendingLastCancelTimeV1231 = TimeCurrent();
      g_pendingCancelsSellV1231++;
   }
   // V1.2.3.3 PENDING LIFECYCLE FIX: contabiliza e registra o motivo estrutural
   int reason_index = (int)reason_code;
   if(reason_index >= 0 && reason_index < PENDING_CANCEL_REASON_COUNT_V1233)
      g_pendingCancelsByReasonV1233[reason_index]++;
   g_pendingMutationSeqV1233++;
   LogMessage("[V1233_PENDING_CANCEL_REASON] mutation_id=" + IntegerToString((int)g_pendingMutationSeqV1233) +
              " ticket=" + IntegerToString((int)ticket) +
              " lado=" + (buy_side ? "BUY" : "SELL") +
              " tipo=" + EnumToString(current_type) +
              " preco=" + DoubleToString(current_price, _Digits) +
              " idade_s=" + IntegerToString(order_age) +
              " motivo=" + PendingCancelReasonTextV1233(reason_code) +
              " detalhe=" + reason +
              " pos_buy=" + IntegerToString(CountBuyPositions()) +
              " pos_sell=" + IntegerToString(CountSellPositions()) +
              " pend_buy=" + IntegerToString(CountPendingBuyOrders()) +
              " pend_sell=" + IntegerToString(CountPendingSellOrders()) +
              " expo=" + IntegerToString(UsedExposureSlotsV122()) + "/" + IntegerToString(LimitOpenPositions()) +
              " handoff=" + (IsMarketHandoffActiveV1232() ? "1" : "0") +
              " rebalance=" + ((g_buyRebalancePendingConfirmation || g_sellRebalancePendingConfirmation) ? "1" : "0") +
              " replace=" + ((PendingReplaceActiveV1233(true) || PendingReplaceActiveV1233(false)) ? "1" : "0"));
   SetPendingLifecycleV1231(buy_side, PENDING_LIFECYCLE_CANCEL_REQUESTED, PENDING_ACTION_CANCEL,
                            ticket, current_type, current_price, reason);
   LogPendingLifecycleV1231("[V1231_PENDING_CANCEL_REQUEST]", buy_side,
                            PENDING_LIFECYCLE_ACTIVE, PENDING_LIFECYCLE_CANCEL_REQUESTED,
                            ticket, current_type, current_price, 0.0, PENDING_ACTION_CANCEL, reason);
   g_tradeStateDirty = true;
   return true;
}

// ============================ V1.2.3.3 PENDING LIFECYCLE FIX ============================
// Autoridades auxiliares do ciclo de vida: motivo de cancelamento, autoexclusao
// do proprio slot, simulacao completa da troca pendente->mercado e replacement
// transacional de tipo. Nenhuma funcao abaixo altera sinal, lote ou risco.

string PendingCancelReasonTextV1233(ENUM_PENDING_CANCEL_REASON_V1233 reason_code)
{
   switch(reason_code)
   {
      case PENDING_CANCEL_REASON_RISK_EMERGENCY: return "RISK_EMERGENCY";
      case PENDING_CANCEL_REASON_GLOBAL_CLOSE: return "GLOBAL_CLOSE";
      case PENDING_CANCEL_REASON_EXPIRED: return "EXPIRED";
      case PENDING_CANCEL_REASON_INVALID_PRICE: return "INVALID_PRICE";
      case PENDING_CANCEL_REASON_STRUCTURAL_INVALIDATION: return "STRUCTURAL_INVALIDATION";
      case PENDING_CANCEL_REASON_REPLACE_ORDER_TYPE: return "REPLACE_ORDER_TYPE";
      case PENDING_CANCEL_REASON_MARKET_HANDOFF: return "MARKET_HANDOFF";
      case PENDING_CANCEL_REASON_REBALANCE: return "REBALANCE";
      case PENDING_CANCEL_REASON_SYMBOL_DISABLED: return "SYMBOL_DISABLED";
      case PENDING_CANCEL_REASON_SHUTDOWN: return "SHUTDOWN";
      case PENDING_CANCEL_REASON_RECONCILIATION: return "RECONCILIATION";
      default: return "NONE";
   }
}

// A propria pendente nao pode contar como slot ocupado quando o EA avalia se
// ela continua desejada. Sem esta exclusao, posicoes_do_lado == target-1 fazia
// a ordem invalidar a si mesma e renascer a cada dois segundos (causa raiz do
// loop CREATE->CANCEL->CREATE da V1.2.3.2).
int PendingSideSlotAdjustV1233(bool buy_side, ulong exclude_order_ticket)
{
   if(exclude_order_ticket == 0)
      return 0;
   ENUM_ORDER_TYPE type = (buy_side ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP);
   double price = 0.0;
   if(!PendingTicketExistsV1231(exclude_order_ticket, type, price))
      return 0;
   if(buy_side != IsBuyPendingType(type))
      return 0;
   return -1;
}

// Simula o estado que existira DEPOIS da troca (pendente removida + posicao a
// mercado adicionada) antes de autorizar qualquer cancelamento por Handoff ou
// Rebalance. Reprova a troca que fatalmente falharia depois do OrderDelete.
bool SimulatePendingSwapV1233(ENUM_POSITION_TYPE entry_direction, bool pending_buy_side, ulong pending_ticket, string &reason)
{
   reason = "OK";
   ENUM_ORDER_TYPE pending_type = (pending_buy_side ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP);
   double pending_price = 0.0;
   if(!PendingTicketExistsV1231(pending_ticket, pending_type, pending_price))
   {
      reason = "troca_ticket_ausente";
      return false;
   }
   double pending_lot = OrderGetDouble(ORDER_VOLUME_CURRENT);
   double lot = NormalizeVolume(FixedLot);
   if(lot <= 0.0)
   {
      reason = "troca_lote_invalido";
      return false;
   }

   int buy_slots = CountBuyExposureSlots() - (pending_buy_side ? 1 : 0) +
                   (entry_direction == POSITION_TYPE_BUY ? 1 : 0);
   int sell_slots = CountSellExposureSlots() - (pending_buy_side ? 0 : 1) +
                    (entry_direction == POSITION_TYPE_SELL ? 1 : 0);
   double buy_lots = GetBuyExposureLots() - (pending_buy_side ? pending_lot : 0.0) +
                     (entry_direction == POSITION_TYPE_BUY ? lot : 0.0);
   double sell_lots = GetSellExposureLots() - (pending_buy_side ? 0.0 : pending_lot) +
                      (entry_direction == POSITION_TYPE_SELL ? lot : 0.0);

   if(buy_slots > LimitBuyPositions())
   {
      reason = "troca_limite_buy";
      return false;
   }
   if(sell_slots > LimitSellPositions())
   {
      reason = "troca_limite_sell";
      return false;
   }
   int max_imbalance = MathMax(0, MaxDesequilibrioDirecional);
   if(MathAbs(buy_slots - sell_slots) > max_imbalance)
   {
      reason = "troca_desequilibrio_direcional";
      return false;
   }
   double net_lots = MathAbs(buy_lots - sell_lots);
   if(MaxExposicaoLiquidaLotes > 0.0 && net_lots > MaxExposicaoLiquidaLotes + 0.0000001)
   {
      reason = "troca_exposicao_liquida";
      return false;
   }

   ENUM_ORDER_TYPE market_type = (entry_direction == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   double market_price = (entry_direction == POSITION_TYPE_BUY ? g_tick.ask : g_tick.bid);
   double required_margin = 0.0;
   if(!HasMarginForOrderV122(market_type, lot, market_price, reason, required_margin))
   {
      reason = "troca_sem_margem";
      return false;
   }
   return true;
}

bool PendingReplaceActiveV1233(bool buy_side)
{
   return (buy_side ? g_buyPendingReplaceActiveV1233 : g_sellPendingReplaceActiveV1233);
}

void ReleasePendingReplacementV1233(bool buy_side, string reason, bool timed_out)
{
   if(!PendingReplaceActiveV1233(buy_side))
      return;
   if(timed_out)
      g_pendingReplaceTimeoutsV1233++;
   else
      g_pendingReplaceReleasedV1233++;
   LogMessage("[V1233_PENDING_REPLACE_RELEASED] lado=" + (buy_side ? "BUY" : "SELL") +
              " ticket_antigo=" + IntegerToString((int)(buy_side ? g_buyPendingReplaceOldTicketV1233 : g_sellPendingReplaceOldTicketV1233)) +
              " tipo_reservado=" + EnumToString(buy_side ? g_buyPendingReplaceTypeV1233 : g_sellPendingReplaceTypeV1233) +
              " timeout=" + (timed_out ? "1" : "0") +
              " motivo=" + reason);
   if(buy_side)
   {
      g_buyPendingReplaceActiveV1233 = false;
      g_buyPendingReplaceOldTicketV1233 = 0;
      g_buyPendingReplaceSinceV1233 = 0;
   }
   else
   {
      g_sellPendingReplaceActiveV1233 = false;
      g_sellPendingReplaceOldTicketV1233 = 0;
      g_sellPendingReplaceSinceV1233 = 0;
   }
}

// Conclui um replacement de tipo reservado: espera a confirmacao do
// cancelamento pela autoridade V1231 e cria exatamente a substituta reservada.
// Concluido como REPLACED (create aceito), RELEASED (estado mudou) ou TIMEOUT.
void ProcessPendingReplacementV1233()
{
   for(int side = 0; side < 2; side++)
   {
      bool buy_side = (side == 0);
      if(!PendingReplaceActiveV1233(buy_side))
         continue;

      datetime since = (buy_side ? g_buyPendingReplaceSinceV1233 : g_sellPendingReplaceSinceV1233);
      int timeout = MathMax(1, TradeReconciliationTimeoutSeconds);
      if(since > 0 && (int)(TimeCurrent() - since) >= timeout)
      {
         ReleasePendingReplacementV1233(buy_side, "timeout_replacement", true);
         continue;
      }

      // Cancelamento ainda em confirmacao no servidor: aguardar.
      if(PendingLifecycleBusyV1231(buy_side))
         continue;

      ulong old_ticket = (buy_side ? g_buyPendingReplaceOldTicketV1233 : g_sellPendingReplaceOldTicketV1233);
      ENUM_ORDER_TYPE old_check_type = (buy_side ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP);
      double old_check_price = 0.0;
      if(PendingTicketExistsV1231(old_ticket, old_check_type, old_check_price))
      {
         // Cancel nao confirmado (timeout da autoridade devolveu ACTIVE).
         ReleasePendingReplacementV1233(buy_side, "cancelamento_nao_confirmado");
         continue;
      }

      // Guardas de serializacao: nunca criar no mesmo segundo do cancelamento
      // nem com outra mutacao em andamento. Aguarda o proximo tick.
      datetime last_cancel = (buy_side ? g_buyPendingLastCancelTimeV1231 : g_sellPendingLastCancelTimeV1231);
      if(last_cancel > 0 && TimeCurrent() <= last_cancel)
         continue;
      if(g_pendingMutationSentThisTickV1231 || AnyPendingLifecycleBusyV1231())
         continue;

      if(!IsPendingFiltersOK())
      {
         ReleasePendingReplacementV1233(buy_side, "filtros_bloqueando");
         continue;
      }

      ENUM_ORDER_TYPE desired_type;
      double desired_price = 0.0;
      ENUM_ENTRY_GEOMETRY_V121 geometry = ENTRY_GEOMETRY_RECOVERY;
      string pending_reason = "";
      if(!GetDesiredPendingOrderCurrentMode(buy_side, desired_type, desired_price, geometry, pending_reason))
      {
         ReleasePendingReplacementV1233(buy_side, "desejado_indisponivel_" + pending_reason);
         continue;
      }
      ENUM_ORDER_TYPE reserved_type = (buy_side ? g_buyPendingReplaceTypeV1233 : g_sellPendingReplaceTypeV1233);
      if(desired_type != reserved_type)
      {
         ReleasePendingReplacementV1233(buy_side, "tipo_desejado_mudou");
         continue;
      }

      double lot = NormalizeVolume(FixedLot);
      string reason = "";
      if(!HasDirectionalSlotRoom(buy_side ? POSITION_TYPE_BUY : POSITION_TYPE_SELL, 1, lot, reason))
      {
         ReleasePendingReplacementV1233(buy_side, "sem_slot_" + reason);
         continue;
      }
      double required_margin = 0.0;
      if(!HasMarginForOrderV122(desired_type, lot, desired_price, reason, required_margin))
      {
         ReleasePendingReplacementV1233(buy_side, "sem_margem");
         continue;
      }

      if(RequestPendingCreateV1231(buy_side, desired_type, desired_price, required_margin, "replacement_tipo_v1233"))
      {
         g_pendingReplaceCompletedV1233++;
         LogMessage("[V1233_PENDING_REPLACE_CONFIRMED] lado=" + (buy_side ? "BUY" : "SELL") +
                    " ticket_antigo=" + IntegerToString((int)old_ticket) +
                    " tipo=" + EnumToString(desired_type) +
                    " preco=" + DoubleToString(desired_price, _Digits) +
                    " resultado=REPLACED");
         if(buy_side)
         {
            g_buyPendingReplaceActiveV1233 = false;
            g_buyPendingReplaceOldTicketV1233 = 0;
            g_buyPendingReplaceSinceV1233 = 0;
         }
         else
         {
            g_sellPendingReplaceActiveV1233 = false;
            g_sellPendingReplaceOldTicketV1233 = 0;
            g_sellPendingReplaceSinceV1233 = 0;
         }
      }
      else
      {
         ReleasePendingReplacementV1233(buy_side, "create_rejeitado");
      }

      if(g_pendingMutationSentThisTickV1231)
         return;
   }
}
// ========================== FIM V1.2.3.3 PENDING LIFECYCLE FIX ==========================

bool IsMarketHandoffActiveV1232()
{
   return (g_marketHandoffStateV1232 != MARKET_HANDOFF_NONE);
}

string MarketHandoffStateTextV1232()
{
   if(g_marketHandoffStateV1232 == MARKET_HANDOFF_CANCEL_REQUESTED) return "CANCEL_REQUESTED";
   if(g_marketHandoffStateV1232 == MARKET_HANDOFF_SLOT_READY) return "SLOT_READY";
   if(g_marketHandoffStateV1232 == MARKET_HANDOFF_EXECUTING) return "EXECUTING";
   return "NONE";
}

void ClearMarketEntryHandoffV1232(string reason)
{
   if(!IsMarketHandoffActiveV1232())
      return;
   LogMessage("[V1232_HANDOFF_CLEARED] state=" + MarketHandoffStateTextV1232() +
              " ticket=" + IntegerToString((int)g_marketHandoffPendingTicketV1232) +
              " direction=" + DirectionToTextV121(g_marketHandoffCandidateV1232.direction) +
              " reason=" + reason);
   g_marketHandoffStateV1232 = MARKET_HANDOFF_NONE;
   g_marketHandoffPendingTicketV1232 = 0;
   g_marketHandoffPendingBuySideV1232 = false;
   g_marketHandoffSinceV1232 = 0;
   g_marketHandoffReasonV1232 = reason;
   g_marketHandoffResolvedThisTickV1232 = true;
   ResetCandidateV121(g_marketHandoffCandidateV1232);
}

bool ProcessMarketEntryHandoffV1232()
{
   if(!IsMarketHandoffActiveV1232())
      return false;

   ENUM_ORDER_TYPE pending_type = (g_marketHandoffPendingBuySideV1232 ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP);
   double pending_price = 0.0;
   bool ticket_exists = PendingTicketExistsV1231(g_marketHandoffPendingTicketV1232, pending_type, pending_price);
   int timeout = MathMax(1, TradeReconciliationTimeoutSeconds);

   if(g_marketHandoffStateV1232 == MARKET_HANDOFF_CANCEL_REQUESTED)
   {
      if(ticket_exists || AnyPendingLifecycleBusyV1231())
      {
         if(g_marketHandoffSinceV1232 > 0 && (int)(TimeCurrent() - g_marketHandoffSinceV1232) >= timeout * 2)
         {
            g_marketHandoffTimeoutsV1232++;
            g_marketHandoffReleasedV1232++;
            ClearMarketEntryHandoffV1232("timeout_cancelamento_ou_confirmacao");
         }
         return false;
      }
      g_marketHandoffStateV1232 = MARKET_HANDOFF_SLOT_READY;
      g_marketHandoffReasonV1232 = "slot_confirmado_livre";
      LogMessage("[V1232_HANDOFF_SLOT_READY] ticket=" + IntegerToString((int)g_marketHandoffPendingTicketV1232) +
                 " direction=" + DirectionToTextV121(g_marketHandoffCandidateV1232.direction) +
                 " slots=" + IntegerToString(UsedExposureSlotsV122()) + "/" + IntegerToString(LimitOpenPositions()));
   }

   if(g_marketHandoffStateV1232 != MARKET_HANDOFF_SLOT_READY)
      return false;

   if(CountOpenPositions() <= 0 || IsClosingScopeActiveV122() ||
      g_dailyLossBlocked || g_accountDailyLossBlocked || g_dailyProfitBlocked || g_basketDDBlocked)
   {
      g_marketHandoffReleasedV1232++;
      ClearMarketEntryHandoffV1232("bloqueio_de_risco_ou_cesta_inativa");
      return false;
   }

   if(!HasExposureRoomIncludingPendings(1))
   {
      g_marketHandoffReleasedV1232++;
      ClearMarketEntryHandoffV1232("slot_consumido_por_outro_evento");
      return false;
   }

   // O sinal, distancia e score ja foram validados antes do cancelamento.
   // Atualiza apenas o preco real de execucao e a zona de seguranca.
   g_marketHandoffCandidateV1232.entryPrice =
      (g_marketHandoffCandidateV1232.direction == POSITION_TYPE_BUY ? g_tick.ask : g_tick.bid);
   g_marketHandoffCandidateV1232.zoneId =
      BuildZoneIdV121(g_marketHandoffCandidateV1232.direction,
                      g_marketHandoffCandidateV1232.entryPrice,
                      g_marketHandoffCandidateV1232.requiredPoints);
   g_marketHandoffCandidateV1232.valid = true;
   g_marketHandoffCandidateV1232.reasonAllowBlock = "HANDOFF_EXECUTING";
   g_marketHandoffStateV1232 = MARKET_HANDOFF_EXECUTING;

   LogMessage("[V1232_HANDOFF_EXECUTE] direction=" +
              DirectionToTextV121(g_marketHandoffCandidateV1232.direction) +
              " geometry=" + GeometryToTextV121(g_marketHandoffCandidateV1232.geometry) +
              " score=" + DoubleToString(g_marketHandoffCandidateV1232.score, 1) +
              " price=" + DoubleToString(g_marketHandoffCandidateV1232.entryPrice, _Digits));

   bool executed = ExecuteEntryCandidateV121(g_marketHandoffCandidateV1232);
   if(executed)
   {
      g_marketHandoffExecutedV1232++;
      ClearMarketEntryHandoffV1232("executado");
      return true;
   }

   g_marketHandoffReleasedV1232++;
   string failure_reason = g_marketHandoffCandidateV1232.reasonAllowBlock;
   ClearMarketEntryHandoffV1232("execucao_bloqueada_" + failure_reason);
   return false;
}

void LogThrottledV1232(string key, string message, int interval_seconds)
{
   datetime now = TimeCurrent();
   int selected = -1;
   int oldest = 0;
   for(int i = 0; i < 128; i++)
   {
      if(g_throttledLogKeysV1232[i] == key)
      {
         if(now - g_throttledLogTimesV1232[i] < MathMax(1, interval_seconds))
            return;
         selected = i;
         break;
      }
      if(g_throttledLogKeysV1232[i] == "" && selected < 0)
         selected = i;
      if(g_throttledLogTimesV1232[i] < g_throttledLogTimesV1232[oldest])
         oldest = i;
   }
   if(selected < 0)
      selected = oldest;
   g_throttledLogKeysV1232[selected] = key;
   g_throttledLogTimesV1232[selected] = now;
   LogMessage(message);
}

bool IsClosingScopeActiveV122()
{
   return (BlockEntriesWhileClosing && g_exitState != EXIT_IDLE);
}

void StartClosingScopeV122(string reason)
{
   if(!BlockEntriesWhileClosing)
      return;
   SetExitStateV122(EXIT_REQUESTED, reason);
}

void SetExitStateV122(ENUM_EXIT_STATE_V122 state, string reason)
{
   if(g_exitState == state && TimeCurrent() - g_exitStateSince < 1)
      return;
   g_exitState = state;
   g_exitStateSince = TimeCurrent();
   LogMessage("[V122_EXIT_STATE] state=" + ExitStateToTextV122(state) + " reason=" + reason);
}

void ReconcileClosingScopeV122()
{
   if(g_exitState == EXIT_IDLE)
      return;
   if(g_tradeStateDirty)
      return;
   if(g_exitState != EXIT_RECONCILING)
      return;
   if(TimeCurrent() - g_exitStateSince < 1)
      return;
   FinishClosingScopeV122("server_reconciled");
}

void FinishClosingScopeV122(string reason)
{
   if(g_exitState == EXIT_IDLE)
      return;
   g_exitState = EXIT_IDLE;
   g_exitStateSince = TimeCurrent();
   LogMessage("[V122_EXIT_STATE] state=EXIT_IDLE reason=" + reason);
}

void LogEntryBlockedV122(string source, string reason)
{
   g_lastEntryBlockReasonV122 = reason;
   LogThrottledV1232("entry_blocked_" + source + "_" + reason,
                     "[V122_ENTRY_BLOCKED] source=" + source + " motivo=" + reason +
                     " buy=" + IntegerToString(CountBuyPositions()) +
                     " sell=" + IntegerToString(CountSellPositions()) +
                     " pend_buy=" + IntegerToString(CountPendingBuyOrders()) +
                     " pend_sell=" + IntegerToString(CountPendingSellOrders()) +
                     " slots=" + IntegerToString(UsedExposureSlotsV122()) + "/" + IntegerToString(LimitOpenPositions()) +
                     " spread=" + DoubleToString(GetCurrentSpreadPoints(), 1), 10);
}

string BiasToTextV122(ENUM_DIRECTIONAL_BIAS_V122 bias)
{
   switch(bias)
   {
      case BIAS_STRONG_BUY: return "STRONG_BUY";
      case BIAS_BUY: return "BUY";
      case BIAS_SELL: return "SELL";
      case BIAS_STRONG_SELL: return "STRONG_SELL";
      default: return "NEUTRAL";
   }
}

string ExitStateToTextV122(ENUM_EXIT_STATE_V122 state)
{
   switch(state)
   {
      case EXIT_REQUESTED: return "EXIT_REQUESTED";
      case EXIT_CANCELLING_PENDING: return "EXIT_CANCELLING_PENDING";
      case EXIT_CLOSING_POSITIONS: return "EXIT_CLOSING_POSITIONS";
      case EXIT_RECONCILING: return "EXIT_RECONCILING";
      default: return "EXIT_IDLE";
   }
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

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

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
   string reason = "";
   if(!additional_pair)
   {
      if(!CanOpenPairV122(reason))
      {
         LogEntryBlockedV122("initial_pair", reason);
         return false;
      }
   }
   else
   {
      if(!EntryPreflightV122("additional_pair", false, reason))
      {
         LogEntryBlockedV122("additional_pair", reason);
         return false;
      }
      double additional_lot = NormalizeVolume(FixedLot);
      if(additional_lot <= 0.0)
      {
         LogEntryBlockedV122("additional_pair", "lote_invalido");
         return false;
      }
      if(!HasExposureRoomIncludingPendings(2))
      {
         LogEntryBlockedV122("additional_pair", "sem_dois_slots");
         return false;
      }
      if(!HasDirectionalSlotRoom(POSITION_TYPE_BUY, 1, additional_lot, reason) ||
         !HasDirectionalSlotRoom(POSITION_TYPE_SELL, 1, additional_lot, reason))
      {
         LogEntryBlockedV122("additional_pair", reason);
         return false;
      }
   }

   double lot = NormalizeVolume(FixedLot);
   if(lot <= 0.0)
   {
      LogMessage("erro ao abrir ordem: lote fixo invalido para o simbolo.");
      return false;
   }

   if(!ReserveSlotsV122(2, additional_pair ? "additional_pair" : "initial_pair"))
      return false;

   string tag = (additional_pair ? "IA_FG_ADDITIONAL_V122" : "IA_FG_INITIAL_V122");
   bool buy_confirmed = false;
   bool sell_confirmed = false;
   string buy_reason = "";
   string sell_reason = "";
   bool buy_sent = SendMarketOrderV122(POSITION_TYPE_BUY, tag + "_BUY", false, true, buy_confirmed, buy_reason);
   if(!buy_sent)
      ReleaseSlotsV122(1, "pair_buy_failed");
   else if(buy_confirmed)
      ReleaseSlotsV122(1, "pair_buy_confirmed");

   bool sell_sent = SendMarketOrderV122(POSITION_TYPE_SELL, tag + "_SELL", false, true, sell_confirmed, sell_reason);
   if(!sell_sent)
      ReleaseSlotsV122(1, "pair_sell_failed");
   else if(sell_confirmed)
      ReleaseSlotsV122(1, "pair_sell_confirmed");

   g_lastPairOpenTime = TimeCurrent();
   g_lastPairCandleTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   g_lastPairMidPrice = MidPrice();
   if(buy_sent)
      g_lastBuyLevelPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(sell_sent)
      g_lastSellLevelPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   g_lastBuyLevelTime = g_lastPairOpenTime;
   g_lastSellLevelTime = g_lastPairOpenTime;
   PersistBasketState();

   if(buy_confirmed && sell_confirmed)
      LogMessage("[V122_PAIR_CONFIRMED] lote=" + DoubleToString(lot, 2) +
                 " slots=" + IntegerToString(UsedExposureSlotsV122()) + "/" + IntegerToString(LimitOpenPositions()));
   else if(buy_sent || sell_sent)
      LogMessage("[V122_PAIR_PARTIAL] buy_sent=" + (buy_sent ? "true" : "false") +
                 " buy_confirmed=" + (buy_confirmed ? "true" : "false") +
                 " sell_sent=" + (sell_sent ? "true" : "false") +
                 " sell_confirmed=" + (sell_confirmed ? "true" : "false") +
                 " buy_reason=" + buy_reason + " sell_reason=" + sell_reason);
   else
      LogMessage("[V122_SERVER_CONFIRM_FAIL] par_nao_enviado buy_reason=" + buy_reason + " sell_reason=" + sell_reason);

   return (buy_sent || sell_sent);
}

bool ManageDirectionalAdditionalEntries()
{
   bool opened_any = false;
   string buy_reason = "";
   string sell_reason = "";

   if(CanOpenDirectionalEntry(POSITION_TYPE_BUY, buy_reason))
      opened_any = OpenDirectionalOrder(POSITION_TYPE_BUY, buy_reason);
   else
      LogMessage("[DIRECTIONAL_ENTRY_BLOCKED] direcao=BUY motivo=" + buy_reason);

   if(CanOpenDirectionalEntry(POSITION_TYPE_SELL, sell_reason))
      opened_any = (OpenDirectionalOrder(POSITION_TYPE_SELL, sell_reason) || opened_any);
   else
      LogMessage("[DIRECTIONAL_ENTRY_BLOCKED] direcao=SELL motivo=" + sell_reason);

   return opened_any;
}

bool CanOpenDirectionalEntry(ENUM_POSITION_TYPE direction, string &reason)
{
   reason = "OK";

   if(!OpenAdditionalPairsWhileBasketActive || !OpenAdditionalPairsUntilMaxPositions)
   {
      reason = "adicionais_desativados";
      return false;
   }

   if(CountOpenPositions() <= 0)
   {
      reason = "sem_cesta_ativa";
      return false;
   }

   if(StopAddingPairsWhenBasketPositive && GetBasketProfit() > 0.0)
   {
      reason = "cesta_positiva";
      return false;
   }

   if(!BaseEntryFiltersOK())
   {
      reason = "filtros_base";
      return false;
   }

   if(!CanOpenNewPairAntiOvertrade())
   {
      reason = "anti_hiperatividade";
      return false;
   }

   if(!HasExposureRoomIncludingPendings(1))
   {
      reason = "sem_slot_total";
      LogMessage("[EXPOSURE_BUDGET_BLOCKED] motivo=sem_slot_total");
      return false;
   }

   double lot = NormalizeVolume(FixedLot);
   if(lot <= 0.0)
   {
      reason = "lote_invalido";
      return false;
   }

   if(!HasDirectionalSlotRoom(direction, 1, lot, reason))
      return false;

   if(!UpdateATRData())
   {
      reason = "atr_indisponivel";
      LogMessage("[REGIME_NOT_CONFIRMED] motivo=atr_indisponivel");
      return false;
   }

   if(!IsBasketHealthyForNewEntry(reason))
      return false;

   int regime = DetectRegimeConfirmado();
   bool counter_extreme = ((direction == POSITION_TYPE_BUY && regime == -2) ||
                           (direction == POSITION_TYPE_SELL && regime == 2));
   if(counter_extreme && BloquearContraTendenciaExtrema)
   {
      reason = "contra_tendencia_extrema";
      LogMessage("[COUNTERTREND_ADD_BLOCKED] direcao=" + (direction == POSITION_TYPE_BUY ? "BUY" : "SELL") +
                 " regime=" + IntegerToString(regime));
      return false;
   }

   double entry_price = (direction == POSITION_TYPE_BUY ? g_tick.ask : g_tick.bid);
   double required_points = GetAdaptiveDistancePoints(direction);
   double reference_price = GetDirectionalReferencePrice(direction);

   if(reference_price > 0.0)
   {
      double moved_points = 0.0;
      if(direction == POSITION_TYPE_BUY)
         moved_points = (reference_price - entry_price) / _Point;
      else
         moved_points = (entry_price - reference_price) / _Point;

      if(moved_points < required_points)
      {
         reason = "distancia_adaptativa";
         LogMessage("[ADDITIONAL_ENTRY_CHECK] direcao=" + (direction == POSITION_TYPE_BUY ? "BUY" : "SELL") +
                    " allow=BLOCK motivo=distancia_adaptativa atual=" + DoubleToString(moved_points, 1) +
                    " requerida=" + DoubleToString(required_points, 1));
         return false;
      }
   }

   if(UsarCompressorZonas && IsZoneAlreadyRepresented(direction, entry_price, required_points))
   {
      reason = "zona_ja_representada";
      LogMessage("[ADDITIONAL_ENTRY_CHECK] direcao=" + (direction == POSITION_TYPE_BUY ? "BUY" : "SELL") +
                 " allow=BLOCK motivo=zona_ja_representada");
      return false;
   }

   LogMessage("[ADDITIONAL_ENTRY_CHECK] direcao=" + (direction == POSITION_TYPE_BUY ? "BUY" : "SELL") +
              " allow=ALLOW regime=" + IntegerToString(regime) +
              " atr=" + DoubleToString(g_lastATRPoints, 1) +
              " distancia=" + DoubleToString(required_points, 1) +
              " buy_slots=" + IntegerToString(CountBuyExposureSlots()) +
              " sell_slots=" + IntegerToString(CountSellExposureSlots()) +
              " lucro=" + DoubleToString(GetBasketProfit(), 2) +
              " mfe=" + DoubleToString(g_PicoLucroCestaUSD, 2) +
              " mae=" + DoubleToString(g_MAELucroCestaUSD, 2));

   return true;
}

bool OpenDirectionalOrder(ENUM_POSITION_TYPE direction, string reason)
{
   bool confirmed = false;
   string send_reason = "";
   string comment = (direction == POSITION_TYPE_BUY ? "IA_FG_DIRECTIONAL_BUY_V122" : "IA_FG_DIRECTIONAL_SELL_V122");
   bool ok = SendMarketOrderV122(direction, comment, true, false, confirmed, send_reason);
   if(!ok)
   {
      LogEntryBlockedV122(comment, send_reason);
      return false;
   }

   LogMessage("[DIRECTIONAL_ENTRY_OK] direcao=" + (direction == POSITION_TYPE_BUY ? "BUY" : "SELL") +
               " motivo=" + reason +
               " confirmed=" + (confirmed ? "true" : "false") +
               " slot_total=" + IntegerToString(UsedExposureSlotsV122()) +
               " net_lots=" + DoubleToString(GetNetExposureLots(), 2));

   return (!RequireServerConfirmationV122 || confirmed);
}

void ResetCandidateV121(EntryCandidateV121 &candidate)
{
   candidate.valid = false;
   candidate.direction = POSITION_TYPE_BUY;
   candidate.geometry = ENTRY_GEOMETRY_RECOVERY;
   candidate.score = 0.0;
   candidate.threshold = 0.0;
   candidate.entryPrice = 0.0;
   candidate.referencePrice = 0.0;
   candidate.movedPoints = 0.0;
   candidate.requiredPoints = 0.0;
   candidate.regime = 0;
   candidate.atrPoints = 0.0;
   candidate.spreadPoints = 0.0;
   candidate.sideSlots = 0;
   candidate.totalSlots = 0;
   candidate.netLotsBefore = 0.0;
   candidate.netLotsAfter = 0.0;
   candidate.reasonAllowBlock = "nao_avaliado";
   candidate.candleTime = 0;
   candidate.zoneId = "";
}

void ResetCandleBudgetV121()
{
   datetime candle_time = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(candle_time <= 0)
      candle_time = TimeCurrent();

   if(g_budgetCandleV121 != candle_time)
   {
      g_budgetCandleV121 = candle_time;
      g_buyEntriesThisCandleV121 = 0;
      g_sellEntriesThisCandleV121 = 0;
      g_totalEntriesThisCandleV121 = 0;
   }
}

string DirectionToTextV121(ENUM_POSITION_TYPE direction)
{
   return (direction == POSITION_TYPE_BUY ? "BUY" : "SELL");
}

string GeometryToTextV121(ENUM_ENTRY_GEOMETRY_V121 geometry)
{
   if(geometry == ENTRY_GEOMETRY_MOMENTUM)
      return "MOMENTUM";
   if(geometry == ENTRY_GEOMETRY_REBALANCE)
      return "REBALANCE";
   return "RECOVERY";
}

string RegimeToTextV121(int regime)
{
   if(regime >= 2)
      return "ALTA_EXTREMA";
   if(regime == 1)
      return "ALTA";
   if(regime == 0)
      return "NEUTRO";
   if(regime == -1)
      return "QUEDA";
   return "QUEDA_EXTREMA";
}

double EntryThresholdV121(ENUM_ENTRY_GEOMETRY_V121 geometry)
{
   if(geometry == ENTRY_GEOMETRY_REBALANCE)
      return 0.0;
   if(geometry == ENTRY_GEOMETRY_MOMENTUM)
      return MathMax(1.0, ScoreMinimoMomentumV121);

   return MathMax(1.0, ScoreMinimoRecoveryV121);
}

string BuildZoneIdV121(ENUM_POSITION_TYPE direction, double price, double zone_points)
{
   double zone = MathMax(1.0, zone_points);
   long bucket = (long)MathFloor(price / (_Point * zone));
   return DirectionToTextV121(direction) + "_" + IntegerToString((int)bucket);
}

string CandidateTextV121(EntryCandidateV121 &candidate)
{
   if(candidate.reasonAllowBlock == "")
      candidate.reasonAllowBlock = (candidate.valid ? "ALLOW" : "BLOCK");

   return DirectionToTextV121(candidate.direction) + " " + GeometryToTextV121(candidate.geometry) +
          " score=" + DoubleToString(candidate.score, 1) +
          "/" + DoubleToString(candidate.threshold, 1) +
          " moved=" + DoubleToString(candidate.movedPoints, 1) +
          "/" + DoubleToString(candidate.requiredPoints, 1) +
          " regime=" + RegimeToTextV121(candidate.regime) +
          " motivo=" + candidate.reasonAllowBlock;
}

void LogCandidateV121(string tag, EntryCandidateV121 &candidate, string reason)
{
   string decision = (candidate.valid ? "ALLOW" : "BLOCK");
   string message = tag +
                    " decision=" + decision +
                    " reason=" + reason +
                    " direction=" + DirectionToTextV121(candidate.direction) +
                    " geometry=" + GeometryToTextV121(candidate.geometry) +
                    " score=" + DoubleToString(candidate.score, 1) +
                    " threshold=" + DoubleToString(candidate.threshold, 1) +
                    " regime=" + RegimeToTextV121(candidate.regime) +
                    " atr=" + DoubleToString(candidate.atrPoints, 1) +
                    " spread=" + DoubleToString(candidate.spreadPoints, 1) +
                    " entry=" + DoubleToString(candidate.entryPrice, _Digits) +
                    " reference=" + DoubleToString(candidate.referencePrice, _Digits) +
                    " moved=" + DoubleToString(candidate.movedPoints, 1) +
                    " required=" + DoubleToString(candidate.requiredPoints, 1) +
                    " zone=" + candidate.zoneId +
                    " buy_slots=" + IntegerToString(CountBuyExposureSlots()) +
                    " sell_slots=" + IntegerToString(CountSellExposureSlots()) +
                    " total_slots=" + IntegerToString(UsedExposureSlotsV122()) +
                    " pending=" + IntegerToString(CountPendingOrders()) +
                    " net_before=" + DoubleToString(candidate.netLotsBefore, 2) +
                    " net_after=" + DoubleToString(candidate.netLotsAfter, 2) +
                    " basket_profit=" + DoubleToString(GetBasketProfit(), 2) +
                    " mfe=" + DoubleToString(g_PicoLucroCestaUSD, 2) +
                    " mae=" + DoubleToString(g_MAELucroCestaUSD, 2);

   bool critical = (StringFind(tag, "EXECUTED") >= 0 ||
                    StringFind(tag, "SELECTED") >= 0 ||
                    StringFind(tag, "MOMENTUM_ENTRY") >= 0 ||
                    StringFind(tag, "RECOVERY_ENTRY") >= 0);
   if(critical)
      LogMessage(message);
   else
      LogThrottledV1232("candidate_" + tag + "_" + DirectionToTextV121(candidate.direction) +
                        "_" + GeometryToTextV121(candidate.geometry) + "_" + reason,
                        message, 10);
}

int DetectRegimeConfirmadoV121()
{
   int persistence = MathMax(1, PersistenciaRegimeCandlesV121);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   int copied = CopyRates(_Symbol, PERIOD_M15, 1, persistence + 3, rates);
   if(copied < persistence + 2)
      return g_lastRegimeV121;

   int up_count = 0;
   int down_count = 0;

   for(int i = 0; i < persistence; i++)
   {
      if(rates[i].close > rates[i + 1].high)
         up_count++;
      else if(rates[i].close < rates[i + 1].low)
         down_count++;
      else if(rates[i].close > rates[i].open)
         up_count++;
      else if(rates[i].close < rates[i].open)
         down_count++;
   }

   bool extreme = (g_lastATRRatio >= 1.80);
   int raw_regime = 0;
   if(up_count >= persistence)
      raw_regime = (extreme ? 2 : 1);
   else if(down_count >= persistence)
      raw_regime = (extreme ? -2 : -1);

   datetime closed_candle = iTime(_Symbol, PERIOD_M15, 1);
   if(closed_candle <= 0)
      return raw_regime;

   if(g_lastRegimeCandleV121 != closed_candle)
   {
      if(raw_regime == g_lastRegimeCandidateV121)
         g_regimeStableCandlesV121++;
      else
      {
         g_lastRegimeCandidateV121 = raw_regime;
         g_regimeStableCandlesV121 = 1;
      }

      g_lastRegimeCandleV121 = closed_candle;
      if(g_regimeStableCandlesV121 >= MathMax(1, persistence))
         g_lastRegimeV121 = raw_regime;
   }

   return g_lastRegimeV121;
}

bool IsGeometryApplicableV121(ENUM_POSITION_TYPE direction, ENUM_ENTRY_GEOMETRY_V121 geometry, int regime, string &reason, int side_slots_adjust) // V1.2.3.3 PENDING LIFECYCLE FIX
{
   reason = "OK";

   if(geometry == ENTRY_GEOMETRY_REBALANCE)
   {
      reason = "rebalance_fluxo_dedicado";
      return false;
   }

   if(geometry == ENTRY_GEOMETRY_RECOVERY && !PermitirRecoveryV121)
   {
      reason = "recovery_desativado";
      return false;
   }

   if(geometry == ENTRY_GEOMETRY_MOMENTUM && !PermitirMomentumV121)
   {
      reason = "momentum_desativado";
      return false;
   }

   bool neutral_momentum_v123 = (UsarExtracaoContinuaV123 && PermitirMomentumNeutroV123 && regime == 0);
   if(geometry == ENTRY_GEOMETRY_MOMENTUM && !neutral_momentum_v123 && !CanAddTowardBiasV122(direction, side_slots_adjust))
   {
      reason = "bias_bloqueia_momentum";
      return false;
   }

   if(geometry == ENTRY_GEOMETRY_RECOVERY && !CanAddCounterBiasRecoveryV122(direction, side_slots_adjust))
   {
      reason = "bias_limite_recovery";
      return false;
   }

   if(MathAbs(regime) == 2 && geometry == ENTRY_GEOMETRY_MOMENTUM && !PermitirMomentumEmRegimeExtremoV121)
   {
      reason = "momentum_extremo_desativado";
      return false;
   }

   if(regime > 0)
   {
      if(direction == POSITION_TYPE_BUY && geometry == ENTRY_GEOMETRY_MOMENTUM)
         return true;
      if(direction == POSITION_TYPE_SELL && geometry == ENTRY_GEOMETRY_RECOVERY)
         return true;
      reason = "geometria_fora_do_regime";
      return false;
   }

   if(regime < 0)
   {
      if(direction == POSITION_TYPE_SELL && geometry == ENTRY_GEOMETRY_MOMENTUM)
         return true;
      if(direction == POSITION_TYPE_BUY && geometry == ENTRY_GEOMETRY_RECOVERY)
         return true;
      reason = "geometria_fora_do_regime";
      return false;
   }

   if(geometry == ENTRY_GEOMETRY_RECOVERY)
      return true;

   if(geometry == ENTRY_GEOMETRY_MOMENTUM && neutral_momentum_v123)
      return true;

   reason = "momentum_sem_regime";
   return false;
}

int CountRecoveryContraExtremaV121(ENUM_POSITION_TYPE direction)
{
   int side_slots = (direction == POSITION_TYPE_BUY ? CountBuyExposureSlots() : CountSellExposureSlots());
   return MathMax(0, side_slots - 1);
}

double GetAdaptiveDistancePointsV121(ENUM_POSITION_TYPE direction, ENUM_ENTRY_GEOMETRY_V121 geometry, int regime)
{
   double min_trade_points = 1.0;
   if(_Point > 0.0)
      min_trade_points = MathMax(1.0, MinTradeDistancePrice() / _Point);

   double geometry_floor = (double)MathMax(DistanciaMinimaZonaPontos, 1);
   if(UsarExtracaoContinuaV123)
   {
      if(geometry == ENTRY_GEOMETRY_MOMENTUM)
         geometry_floor = (double)MathMax(DistanciaMinimaMomentumPontosV123, 1);
      else if(geometry == ENTRY_GEOMETRY_RECOVERY)
         geometry_floor = (double)MathMax(DistanciaMinimaRecoveryPontosV123, 1);
   }

   double required = MathMax(geometry_floor, min_trade_points);
   double atr_multiplier = (geometry == ENTRY_GEOMETRY_MOMENTUM ? MultiplicadorATRMomentumV121 : MultiplicadorATRRecoveryV121);
   if(UsarDistanciaATR && g_lastATRPoints > 0.0)
      required = MathMax(required, g_lastATRPoints * MathMax(0.05, atr_multiplier));

   double spread_points = GetCurrentSpreadPoints();
   required = MathMax(required, min_trade_points + spread_points * 2.0);

   int same_side_slots = (direction == POSITION_TYPE_BUY ? CountBuyExposureSlots() : CountSellExposureSlots());
   required *= (1.0 + MathMax(0.0, ProgressaoDistanciaPorEntradaV121) * (double)MathMax(0, same_side_slots - 1));

   bool countertrend = ((direction == POSITION_TYPE_BUY && regime < 0) ||
                        (direction == POSITION_TYPE_SELL && regime > 0));
   if(countertrend && geometry == ENTRY_GEOMETRY_RECOVERY)
   {
      required *= MathMax(1.0, MultiplicadorContraTendenciaV121);
      if(MathAbs(regime) == 2)
         required *= MathMax(1.0, MultiplicadorRecoveryContraExtremaV121);
   }

   return MathMax(required, 1.0);
}

bool CanUseDirectionalCooldownV121(ENUM_POSITION_TYPE direction, string &reason)
{
   ResetCandleBudgetV121();
   reason = "OK";

   datetime now = TimeCurrent();
   datetime candle_time = iTime(_Symbol, PERIOD_CURRENT, 0);
   datetime last_time = (direction == POSITION_TYPE_BUY ? g_lastBuyAdditionalTimeV121 : g_lastSellAdditionalTimeV121);
   datetime last_candle = (direction == POSITION_TYPE_BUY ? g_lastBuyAdditionalCandleV121 : g_lastSellAdditionalCandleV121);
   int entries_direction = (direction == POSITION_TYPE_BUY ? g_buyEntriesThisCandleV121 : g_sellEntriesThisCandleV121);

   if(MaxEntradasAdicionaisPorCandleV121 > 0 && g_totalEntriesThisCandleV121 >= MaxEntradasAdicionaisPorCandleV121)
   {
      reason = "orcamento_candle_total";
      LogMessage("[CANDLE_BUDGET_V121] direction=" + DirectionToTextV121(direction) +
                 " total=" + IntegerToString(g_totalEntriesThisCandleV121) +
                 "/" + IntegerToString(MaxEntradasAdicionaisPorCandleV121));
      return false;
   }

   if(MaxEntradasPorDirecaoPorCandleV121 > 0 && entries_direction >= MaxEntradasPorDirecaoPorCandleV121)
   {
      reason = "orcamento_candle_direcao";
      LogMessage("[CANDLE_BUDGET_V121] direction=" + DirectionToTextV121(direction) +
                 " dir=" + IntegerToString(entries_direction) +
                 "/" + IntegerToString(MaxEntradasPorDirecaoPorCandleV121));
      return false;
   }

   if(MaxEntradasPorDirecaoPorCandleV121 <= 1 && candle_time > 0 && last_candle == candle_time)
   {
      reason = "direcao_ja_executada_no_candle";
      LogMessage("[CANDLE_BUDGET_V121] direction=" + DirectionToTextV121(direction) +
                 " candle=" + TimeToString(candle_time, TIME_DATE|TIME_MINUTES));
      return false;
   }

   if(CooldownEntradaDirecionalSegundosV121 > 0 && last_time > 0)
   {
      int elapsed = (int)(now - last_time);
      if(elapsed < CooldownEntradaDirecionalSegundosV121)
      {
         reason = "cooldown_direcional";
         LogMessage("[DIRECTIONAL_COOLDOWN_V121] direction=" + DirectionToTextV121(direction) +
                    " elapsed=" + IntegerToString(elapsed) +
                    "/" + IntegerToString(CooldownEntradaDirecionalSegundosV121));
         return false;
      }
   }

   return true;
}

bool IsDistinctEntryZoneV121(EntryCandidateV121 &candidate)
{
   double zone_floor = (double)MathMax(DistanciaMinimaZonaPontos, 1);
   if(UsarExtracaoContinuaV123)
   {
      zone_floor = (candidate.geometry == ENTRY_GEOMETRY_MOMENTUM ?
                    (double)MathMax(DistanciaMinimaMomentumPontosV123, 1) :
                    (double)MathMax(DistanciaMinimaRecoveryPontosV123, 1));
   }
   double zone_points = MathMax(candidate.requiredPoints, zone_floor);
   candidate.zoneId = BuildZoneIdV121(candidate.direction, candidate.entryPrice, zone_points);

   if(!UsarCompressorZonas)
      return true;

   if(IsZoneAlreadyRepresented(candidate.direction, candidate.entryPrice, zone_points))
   {
      LogThrottledV1232("zone_candidate_" + DirectionToTextV121(candidate.direction) + "_" + GeometryToTextV121(candidate.geometry),
                        "[ZONE_DUPLICATE_V121] direction=" + DirectionToTextV121(candidate.direction) +
                        " geometry=" + GeometryToTextV121(candidate.geometry) +
                        " zone=" + candidate.zoneId +
                        " required=" + DoubleToString(zone_points, 1), 10);
      return false;
   }

   return true;
}

double ScoreEntryCandidateV121(EntryCandidateV121 &candidate)
{
   double score = 50.0;
   int pa = DetectPriceActionBias();
   int flow = DetectNativeVolumeFlow();
   int dir_sign = (candidate.direction == POSITION_TYPE_BUY ? 1 : -1);

   bool aligned_momentum = ((candidate.direction == POSITION_TYPE_BUY && candidate.regime > 0) ||
                            (candidate.direction == POSITION_TYPE_SELL && candidate.regime < 0));
   bool countertrend = ((candidate.direction == POSITION_TYPE_BUY && candidate.regime < 0) ||
                        (candidate.direction == POSITION_TYPE_SELL && candidate.regime > 0));

   if(candidate.geometry == ENTRY_GEOMETRY_MOMENTUM)
   {
      if(aligned_momentum)
         score += (MathAbs(candidate.regime) == 2 ? 24.0 : 18.0);
      else if(candidate.regime == 0 && UsarExtracaoContinuaV123 && PermitirMomentumNeutroV123)
      {
         // Em mercado neutro o fluxo/Price Action decide. Nao aplicar a
         // penalidade de tendencia usada quando existe regime contrario.
         if(pa == dir_sign || flow == dir_sign)
            score += 10.0;
         else
            score -= 4.0;
      }
      else
         score -= 18.0;
   }
   else
   {
      if(candidate.regime == 0)
         score += 10.0;
      if(countertrend)
         score -= (MathAbs(candidate.regime) == 2 ? 10.0 : 5.0);
   }

   if(candidate.requiredPoints > 0.0)
   {
      double excess_ratio = (candidate.movedPoints - candidate.requiredPoints) / candidate.requiredPoints;
      if(excess_ratio > 0.0)
         score += MathMin(18.0, excess_ratio * 18.0);
   }

   if(pa == dir_sign)
      score += 6.0;
   else if(pa == -dir_sign)
      score -= 4.0;

   if(flow == dir_sign)
      score += 4.0;
   else if(flow == -dir_sign)
      score -= 2.0;

   if(UsarBiasDirecionalV122)
   {
      int target = (candidate.direction == POSITION_TYPE_BUY ? GetTargetBuySlotsV122() : GetTargetSellSlotsV122());
      if(candidate.sideSlots < target)
         score += MathMin(8.0, (double)(target - candidate.sideSlots) * 2.0);
      else
         score -= 8.0;

      if(candidate.geometry == ENTRY_GEOMETRY_MOMENTUM && CanAddTowardBiasV122(candidate.direction))
         score += 8.0;
   }

   if(candidate.atrPoints > 0.0 && g_lastATRRatio >= 0.75 && g_lastATRRatio <= 2.50)
      score += 4.0;
   else if(g_lastATRRatio > 3.0)
      score -= 5.0;

   score += MathMax(0.0, 4.0 - (double)candidate.sideSlots);
   score -= (double)MathMax(0, candidate.sideSlots - 1) * 1.5;

   if(MaxExposicaoLiquidaLotes > 0.0 && candidate.netLotsAfter > MaxExposicaoLiquidaLotes * 0.75)
      score -= 5.0;

   if(candidate.atrPoints > 0.0)
   {
      double spread_ratio = candidate.spreadPoints / candidate.atrPoints;
      if(spread_ratio > 0.03)
         score -= MathMin(8.0, spread_ratio * 100.0);
   }

   if(score < 0.0)
      score = 0.0;
   if(score > 100.0)
      score = 100.0;

   candidate.score = score;
   LogCandidateV121("[ENTRY_SCORE_V121]", candidate, "score_calculado");
   return score;
}

bool BuildDirectionalCandidateV121(ENUM_POSITION_TYPE direction, ENUM_ENTRY_GEOMETRY_V121 geometry, EntryCandidateV121 &candidate)
{
   ResetCandidateV121(candidate);
   candidate.direction = direction;
   candidate.geometry = geometry;
   candidate.threshold = EntryThresholdV121(geometry);
   candidate.candleTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   candidate.spreadPoints = GetCurrentSpreadPoints();
   candidate.atrPoints = g_lastATRPoints;
   candidate.regime = DetectRegimeConfirmadoV121();
   candidate.entryPrice = (direction == POSITION_TYPE_BUY ? g_tick.ask : g_tick.bid);
   candidate.referencePrice = GetDirectionalReferencePrice(direction);
   candidate.sideSlots = (direction == POSITION_TYPE_BUY ? CountBuyExposureSlots() : CountSellExposureSlots());
   candidate.totalSlots = UsedExposureSlotsV122();
   candidate.netLotsBefore = GetNetExposureLots();
   candidate.netLotsAfter = candidate.netLotsBefore;

   double lot = NormalizeVolume(FixedLot);
   if(direction == POSITION_TYPE_BUY)
      candidate.netLotsAfter = MathAbs((GetBuyExposureLots() + lot) - GetSellExposureLots());
   else
      candidate.netLotsAfter = MathAbs(GetBuyExposureLots() - (GetSellExposureLots() + lot));

   string reason = "";
   if(!IsGeometryApplicableV121(direction, geometry, candidate.regime, reason))
   {
      candidate.reasonAllowBlock = reason;
      LogCandidateV121("[ENTRY_BLOCKED_V121]", candidate, reason);
      return false;
   }

   candidate.requiredPoints = GetAdaptiveDistancePointsV121(direction, geometry, candidate.regime);
   candidate.zoneId = BuildZoneIdV121(direction, candidate.entryPrice, candidate.requiredPoints);
   LogCandidateV121("[ENTRY_CANDIDATE_V121]", candidate, "avaliando");

   if(!OpenAdditionalPairsWhileBasketActive || !OpenAdditionalPairsUntilMaxPositions)
   {
      candidate.reasonAllowBlock = "adicionais_desativados";
      LogCandidateV121("[ENTRY_BLOCKED_V121]", candidate, candidate.reasonAllowBlock);
      return true;
   }

   if(CountOpenPositions() <= 0)
   {
      candidate.reasonAllowBlock = "sem_cesta_ativa";
      LogCandidateV121("[ENTRY_BLOCKED_V121]", candidate, candidate.reasonAllowBlock);
      return true;
   }

   if(StopAddingPairsWhenBasketPositive && GetBasketProfit() > 0.0)
   {
      candidate.reasonAllowBlock = "cesta_positiva";
      LogCandidateV121("[ENTRY_BLOCKED_V121]", candidate, candidate.reasonAllowBlock);
      return true;
   }

   if(!BaseEntryFiltersOK())
   {
      candidate.reasonAllowBlock = "filtros_base";
      LogCandidateV121("[ENTRY_BLOCKED_V121]", candidate, candidate.reasonAllowBlock);
      return true;
   }

   if(BlockNewPairNearBasketTarget && CountOpenPositions() > 0)
   {
      double target = BasketCloseTargetTwoDirections();
      double remaining = target - GetBasketProfit();
      if(remaining >= 0.0 && remaining <= BasketTargetProximityUSD)
      {
         candidate.reasonAllowBlock = "proximo_alvo_cesta";
         LogCandidateV121("[ENTRY_BLOCKED_V121]", candidate, candidate.reasonAllowBlock);
         return true;
      }
   }

   if(lot <= 0.0)
   {
      candidate.reasonAllowBlock = "lote_invalido";
      LogCandidateV121("[ENTRY_BLOCKED_V121]", candidate, candidate.reasonAllowBlock);
      return true;
   }

   if(!UpdateATRData())
   {
      candidate.reasonAllowBlock = "atr_indisponivel";
      LogCandidateV121("[ENTRY_BLOCKED_V121]", candidate, candidate.reasonAllowBlock);
      return true;
   }

   candidate.atrPoints = g_lastATRPoints;
   candidate.regime = DetectRegimeConfirmadoV121();
   if(!IsGeometryApplicableV121(direction, geometry, candidate.regime, reason))
   {
      candidate.reasonAllowBlock = reason;
      LogCandidateV121("[ENTRY_BLOCKED_V121]", candidate, candidate.reasonAllowBlock);
      return true;
   }

   if(!IsBasketHealthyForNewEntry(reason))
   {
      candidate.reasonAllowBlock = reason;
      LogCandidateV121("[ENTRY_BLOCKED_V121]", candidate, candidate.reasonAllowBlock);
      return true;
   }

   if(!CanUseDirectionalCooldownV121(direction, reason))
   {
      candidate.reasonAllowBlock = reason;
      LogCandidateV121("[ENTRY_BLOCKED_V121]", candidate, candidate.reasonAllowBlock);
      return true;
   }

   if(UsarSpreadRelativoATRV121 && MaxSpreadComoPercentualATRV121 > 0.0 && candidate.atrPoints > 0.0)
   {
      double relative_limit = candidate.atrPoints * MaxSpreadComoPercentualATRV121 / 100.0;
      LogThrottledV1232("spread_relative_" + DirectionToTextV121(direction) + "_" + GeometryToTextV121(geometry),
                        "[SPREAD_DIAGNOSTIC_V121] spread=" + DoubleToString(candidate.spreadPoints, 1) +
                        " atr=" + DoubleToString(candidate.atrPoints, 1) +
                        " relative_limit=" + DoubleToString(relative_limit, 1) +
                        " absolute_limit=" + IntegerToString(MaxSpreadPoints), 10);
      if(candidate.spreadPoints > relative_limit)
      {
         candidate.reasonAllowBlock = "spread_relativo_atr";
         LogCandidateV121("[ENTRY_BLOCKED_V121]", candidate, candidate.reasonAllowBlock);
         return true;
      }
   }
   else
   {
      LogThrottledV1232("spread_off_" + DirectionToTextV121(direction) + "_" + GeometryToTextV121(geometry),
                        "[SPREAD_DIAGNOSTIC_V121] spread=" + DoubleToString(candidate.spreadPoints, 1) +
                        " atr=" + DoubleToString(candidate.atrPoints, 1) +
                        " relative_filter=OFF absolute_limit=" + IntegerToString(MaxSpreadPoints), 10);
   }

   if(candidate.referencePrice <= 0.0)
   {
      candidate.reasonAllowBlock = "sem_referencia_real";
      LogCandidateV121("[ENTRY_BLOCKED_V121]", candidate, candidate.reasonAllowBlock);
      return true;
   }

   candidate.requiredPoints = GetAdaptiveDistancePointsV121(direction, geometry, candidate.regime);

   if(direction == POSITION_TYPE_BUY && geometry == ENTRY_GEOMETRY_RECOVERY)
      candidate.movedPoints = (candidate.referencePrice - candidate.entryPrice) / _Point;
   else if(direction == POSITION_TYPE_BUY && geometry == ENTRY_GEOMETRY_MOMENTUM)
      candidate.movedPoints = (candidate.entryPrice - candidate.referencePrice) / _Point;
   else if(direction == POSITION_TYPE_SELL && geometry == ENTRY_GEOMETRY_RECOVERY)
      candidate.movedPoints = (candidate.entryPrice - candidate.referencePrice) / _Point;
   else
      candidate.movedPoints = (candidate.referencePrice - candidate.entryPrice) / _Point;

   if(candidate.movedPoints < candidate.requiredPoints)
   {
      candidate.reasonAllowBlock = "distancia_adaptativa";
      LogCandidateV121("[ENTRY_BLOCKED_V121]", candidate, candidate.reasonAllowBlock);
      return true;
   }

   if(MathAbs(candidate.regime) == 2 && geometry == ENTRY_GEOMETRY_RECOVERY)
   {
      bool counter_extreme = ((direction == POSITION_TYPE_BUY && candidate.regime < 0) ||
                              (direction == POSITION_TYPE_SELL && candidate.regime > 0));
      if(counter_extreme)
      {
         int contra_count = CountRecoveryContraExtremaV121(direction);
         LogMessage("[EXTREME_REGIME_POLICY_V121] direction=" + DirectionToTextV121(direction) +
                    " geometry=RECOVERY contra_count=" + IntegerToString(contra_count) +
                    "/" + IntegerToString(MaxEntradasRecoveryContraExtremaV121) +
                    " distance_multiplier=" + DoubleToString(MultiplicadorRecoveryContraExtremaV121, 2));
         if(contra_count >= MaxEntradasRecoveryContraExtremaV121)
         {
            candidate.reasonAllowBlock = "limite_recovery_contra_extrema";
            LogCandidateV121("[ENTRY_BLOCKED_V121]", candidate, candidate.reasonAllowBlock);
            return true;
         }
      }
   }

   if(!IsDistinctEntryZoneV121(candidate))
   {
      candidate.reasonAllowBlock = "zona_ja_representada";
      LogCandidateV121("[ENTRY_BLOCKED_V121]", candidate, candidate.reasonAllowBlock);
      return true;
   }

   candidate.score = ScoreEntryCandidateV121(candidate);
   if(candidate.score < candidate.threshold)
   {
      candidate.reasonAllowBlock = "score_insuficiente";
      LogCandidateV121("[ENTRY_BLOCKED_V121]", candidate, candidate.reasonAllowBlock);
      return true;
   }

   // Somente libera uma pendente depois que distancia, zona e score foram
   // aprovados. Assim uma candidata incompleta nunca consome uma ordem util.
   if(!FreePendingSlotForMarketEntryV123(candidate, reason))
   {
      candidate.reasonAllowBlock = reason;
      LogCandidateV121("[ENTRY_BLOCKED_V121]", candidate, candidate.reasonAllowBlock);
      return true;
   }

   if(!HasDirectionalSlotRoom(direction, 1, lot, reason))
   {
      candidate.reasonAllowBlock = reason;
      LogCandidateV121("[ENTRY_BLOCKED_V121]", candidate, candidate.reasonAllowBlock);
      return true;
   }

   candidate.valid = true;
   candidate.reasonAllowBlock = "ALLOW";
   LogCandidateV121("[ENTRY_CANDIDATE_V121]", candidate, "aprovado");
   return true;
}

bool IsCandidateBetterV121(EntryCandidateV121 &candidate, EntryCandidateV121 &best)
{
   if(candidate.score > best.score + 0.0001)
      return true;
   if(best.score > candidate.score + 0.0001)
      return false;

   int candidate_dir = (candidate.direction == POSITION_TYPE_BUY ? 0 : 1);
   int best_dir = (best.direction == POSITION_TYPE_BUY ? 0 : 1);

   if(g_lastSelectedDirectionV121 >= 0 && candidate_dir != best_dir)
   {
      if(candidate_dir != g_lastSelectedDirectionV121 && best_dir == g_lastSelectedDirectionV121)
         return true;
      if(best_dir != g_lastSelectedDirectionV121 && candidate_dir == g_lastSelectedDirectionV121)
         return false;
   }

   if(candidate.sideSlots < best.sideSlots)
      return true;
   if(candidate.sideSlots > best.sideSlots)
      return false;

   datetime candidate_level = (candidate.direction == POSITION_TYPE_BUY ? g_lastBuyLevelTime : g_lastSellLevelTime);
   datetime best_level = (best.direction == POSITION_TYPE_BUY ? g_lastBuyLevelTime : g_lastSellLevelTime);
   if(candidate_level < best_level)
      return true;
   if(candidate_level > best_level)
      return false;

   datetime candidate_last = (candidate.direction == POSITION_TYPE_BUY ? g_lastBuyAdditionalTimeV121 : g_lastSellAdditionalTimeV121);
   datetime best_last = (best.direction == POSITION_TYPE_BUY ? g_lastBuyAdditionalTimeV121 : g_lastSellAdditionalTimeV121);
   return (candidate_last < best_last);
}

void MarkExecutionV121(EntryCandidateV121 &candidate)
{
   datetime now = TimeCurrent();
   datetime candle_time = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(candle_time <= 0)
      candle_time = now;

   ResetCandleBudgetV121();
   g_totalEntriesThisCandleV121++;
   g_lastSelectedDirectionV121 = (candidate.direction == POSITION_TYPE_BUY ? 0 : 1);

   if(candidate.direction == POSITION_TYPE_BUY)
   {
      g_lastBuyAdditionalTimeV121 = now;
      g_lastBuyAdditionalCandleV121 = candle_time;
      g_buyEntriesThisCandleV121++;
   }
   else
   {
      g_lastSellAdditionalTimeV121 = now;
      g_lastSellAdditionalCandleV121 = candle_time;
      g_sellEntriesThisCandleV121++;
   }

   if(candidate.geometry == ENTRY_GEOMETRY_MOMENTUM)
      g_momentumEntriesTodayV121++;
   else
      g_recoveryEntriesTodayV121++;

   PersistBasketState();
}

bool ExecuteEntryCandidateV121(EntryCandidateV121 &candidate)
{
   if(!candidate.valid)
      return false;

   string reason = "";
   double lot = NormalizeVolume(FixedLot);
   if(lot <= 0.0)
   {
      candidate.reasonAllowBlock = "lote_invalido_execucao";
      LogCandidateV121("[ENTRY_BLOCKED_V121]", candidate, candidate.reasonAllowBlock);
      return false;
   }

   if(!CanUseDirectionalCooldownV121(candidate.direction, reason))
   {
      candidate.reasonAllowBlock = reason;
      LogCandidateV121("[ENTRY_BLOCKED_V121]", candidate, candidate.reasonAllowBlock);
      return false;
   }

   if(!HasExposureRoomIncludingPendings(1))
   {
      candidate.reasonAllowBlock = "sem_slot_total_execucao";
      LogCandidateV121("[ENTRY_BLOCKED_V121]", candidate, candidate.reasonAllowBlock);
      return false;
   }

   if(!HasDirectionalSlotRoom(candidate.direction, 1, lot, reason))
   {
      candidate.reasonAllowBlock = reason;
      LogCandidateV121("[ENTRY_BLOCKED_V121]", candidate, candidate.reasonAllowBlock);
      return false;
   }

   if(!IsDistinctEntryZoneV121(candidate))
   {
      candidate.reasonAllowBlock = "zona_ja_representada_execucao";
      LogCandidateV121("[ENTRY_BLOCKED_V121]", candidate, candidate.reasonAllowBlock);
      return false;
   }

   LogCandidateV121("[ENTRY_SELECTED_V121]", candidate, "selecionado_por_score");
   bool opened = OpenDirectionalOrder(candidate.direction, "V121_" + GeometryToTextV121(candidate.geometry));
   if(!opened)
   {
      candidate.reasonAllowBlock = "falha_envio_ordem";
      LogCandidateV121("[ENTRY_BLOCKED_V121]", candidate, candidate.reasonAllowBlock);
      return false;
   }

   MarkExecutionV121(candidate);
   RebuildExposureStateFromServer();
   LogCandidateV121("[ENTRY_EXECUTED_V121]", candidate, "executado");
   if(candidate.geometry == ENTRY_GEOMETRY_MOMENTUM)
      LogCandidateV121("[MOMENTUM_ENTRY_V121]", candidate, "executado");
   else
      LogCandidateV121("[RECOVERY_ENTRY_V121]", candidate, "executado");

   return true;
}

bool SelectAndExecuteCandidatesV121()
{
   ResetCandleBudgetV121();
   g_bestBuyCandidateTextV121 = "sem_candidato";
   g_bestSellCandidateTextV121 = "sem_candidato";

   // Um sinal que ja liberou uma pendente possui prioridade transacional.
   // Nao recalcula score/distancia antes de tentar consumir o slot reservado.
   if(IsMarketHandoffActiveV1232())
      return ProcessMarketEntryHandoffV1232();

   EntryCandidateV121 candidates[4];
   EntryCandidateV121 candidate;
   int count = 0;

   if(BuildDirectionalCandidateV121(POSITION_TYPE_BUY, ENTRY_GEOMETRY_RECOVERY, candidate))
   {
      candidates[count] = candidate;
      count++;
   }
   if(BuildDirectionalCandidateV121(POSITION_TYPE_SELL, ENTRY_GEOMETRY_RECOVERY, candidate))
   {
      candidates[count] = candidate;
      count++;
   }
   if(BuildDirectionalCandidateV121(POSITION_TYPE_BUY, ENTRY_GEOMETRY_MOMENTUM, candidate))
   {
      candidates[count] = candidate;
      count++;
   }
   if(BuildDirectionalCandidateV121(POSITION_TYPE_SELL, ENTRY_GEOMETRY_MOMENTUM, candidate))
   {
      candidates[count] = candidate;
      count++;
   }

   bool used[4];
   for(int i = 0; i < 4; i++)
      used[i] = false;

   bool opened_any = false;
   int executed = 0;
   int max_to_execute = MathMax(0, MaxEntradasAdicionaisPorCandleV121);
   if(max_to_execute <= 0)
      max_to_execute = 1;

   while(executed < max_to_execute)
   {
      int best_index = -1;
      for(int i = 0; i < count; i++)
      {
         if(used[i] || !candidates[i].valid)
            continue;
         if(best_index < 0 || IsCandidateBetterV121(candidates[i], candidates[best_index]))
            best_index = i;
      }

      if(best_index < 0)
         break;

      used[best_index] = true;
      if(ExecuteEntryCandidateV121(candidates[best_index]))
      {
         opened_any = true;
         executed++;
      }
   }

   double best_buy_score = -1.0;
   double best_sell_score = -1.0;
   for(int i = 0; i < count; i++)
   {
      if(candidates[i].direction == POSITION_TYPE_BUY && candidates[i].score >= best_buy_score)
      {
         g_bestBuyCandidateTextV121 = CandidateTextV121(candidates[i]);
         best_buy_score = candidates[i].score;
      }
      if(candidates[i].direction == POSITION_TYPE_SELL && candidates[i].score >= best_sell_score)
      {
         g_bestSellCandidateTextV121 = CandidateTextV121(candidates[i]);
         best_sell_score = candidates[i].score;
      }
      if(!candidates[i].valid)
      {
         if(candidates[i].direction == POSITION_TYPE_BUY)
            g_lastBuyBlockReasonV121 = candidates[i].reasonAllowBlock;
         else
            g_lastSellBlockReasonV121 = candidates[i].reasonAllowBlock;
      }
   }

   return opened_any;
}

bool GetDesiredPendingOrderV121(bool buy_side, ENUM_ORDER_TYPE &order_type, double &price, ENUM_ENTRY_GEOMETRY_V121 &geometry, string &reason, ulong exclude_order_ticket)
{
   reason = "OK";
   price = 0.0;

   if(!UpdateSymbolData())
   {
      reason = "tick_indisponivel";
      return false;
   }

   if(!UpdateATRData())
   {
      reason = "atr_indisponivel";
      return false;
   }

   ENUM_POSITION_TYPE direction = (buy_side ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);
   int regime = DetectRegimeConfirmadoV121();

   // V1.2.3.3 PENDING LIFECYCLE FIX: ao reavaliar a pendente existente
   // (exclude_order_ticket > 0) o proprio ticket nao conta como slot ocupado.
   // Na V1.2.3.2 a exclusao valia apenas para a zona; nos limites de bias a
   // ordem contava contra si mesma, era cancelada como "invalida_bias_*" e
   // recriada no tick seguinte, gerando o loop CREATE->CANCEL->CREATE.
   int side_slots_adjust = PendingSideSlotAdjustV1233(buy_side, exclude_order_ticket);

   if(regime > 0)
      geometry = (buy_side ? ENTRY_GEOMETRY_MOMENTUM : ENTRY_GEOMETRY_RECOVERY);
   else if(regime < 0)
      geometry = (buy_side ? ENTRY_GEOMETRY_RECOVERY : ENTRY_GEOMETRY_MOMENTUM);
   else
      geometry = ENTRY_GEOMETRY_RECOVERY;

   if(!IsGeometryApplicableV121(direction, geometry, regime, reason, side_slots_adjust))
      return false;

   if(MathAbs(regime) == 2 && geometry == ENTRY_GEOMETRY_RECOVERY)
   {
      bool counter_extreme = ((direction == POSITION_TYPE_BUY && regime < 0) ||
                              (direction == POSITION_TYPE_SELL && regime > 0));
      if(counter_extreme && CountRecoveryContraExtremaV121(direction) + side_slots_adjust >= MaxEntradasRecoveryContraExtremaV121)
      {
         reason = "limite_recovery_contra_extrema";
         LogMessage("[EXTREME_REGIME_POLICY_V121] pending direction=" + DirectionToTextV121(direction) +
                    " geometry=RECOVERY motivo=" + reason);
         return false;
      }
   }

   double raw_distance = (double)MathMax(PendingOrderDistancePoints, 1);
   double adaptive_distance = GetAdaptiveDistancePointsV121(direction, geometry, regime);
   double min_distance = MinTradeDistancePrice();
   // A pendente precisa respeitar a mesma zona exigida pelo compressor. O
   // fator antigo de 0.75 criava pendentes dentro da propria zona bloqueada.
   double distance_factor = (UsarExtracaoContinuaV123 ? 1.0 : 0.75);
   double distance_price = MathMax(MathMax(raw_distance, adaptive_distance * distance_factor) * _Point, min_distance);

   if(buy_side)
   {
      if(geometry == ENTRY_GEOMETRY_MOMENTUM)
      {
         order_type = ORDER_TYPE_BUY_STOP;
         price = g_tick.ask + distance_price;
         if(price <= g_tick.ask + min_distance)
            price = g_tick.ask + min_distance;
      }
      else
      {
         order_type = ORDER_TYPE_BUY_LIMIT;
         price = g_tick.bid - distance_price;
         if(price >= g_tick.ask - min_distance)
            price = g_tick.ask - min_distance;
      }
   }
   else
   {
      if(geometry == ENTRY_GEOMETRY_MOMENTUM)
      {
         order_type = ORDER_TYPE_SELL_STOP;
         price = g_tick.bid - distance_price;
         if(price >= g_tick.bid - min_distance)
            price = g_tick.bid - min_distance;
      }
      else
      {
         order_type = ORDER_TYPE_SELL_LIMIT;
         price = g_tick.ask + distance_price;
         if(price <= g_tick.bid + min_distance)
            price = g_tick.bid + min_distance;
      }
   }

   price = NormalizePrice(price);
   if(price <= 0.0)
   {
      reason = "preco_pendente_invalido";
      return false;
   }

   if(UsarCompressorZonas && IsZoneAlreadyRepresented(direction, price, adaptive_distance, exclude_order_ticket))
   {
      reason = "zona_ja_representada";
      LogThrottledV1232("zone_pending_" + DirectionToTextV121(direction) + "_" + GeometryToTextV121(geometry),
                        "[ZONE_DUPLICATE_V121] pending direction=" + DirectionToTextV121(direction) +
                        " geometry=" + GeometryToTextV121(geometry) +
                        " price=" + DoubleToString(price, _Digits), 10);
      return false;
   }

   LogThrottledV1232("pending_candidate_" + DirectionToTextV121(direction) + "_" + GeometryToTextV121(geometry),
                     "[ENTRY_CANDIDATE_V121] pending direction=" + DirectionToTextV121(direction) +
                     " geometry=" + GeometryToTextV121(geometry) +
                     " regime=" + RegimeToTextV121(regime) +
                     " price=" + DoubleToString(price, _Digits) +
                     " required=" + DoubleToString(adaptive_distance, 1) +
                     " slots=" + IntegerToString(UsedExposureSlotsV122()) +
                     "/" + IntegerToString(LimitOpenPositions()), 10);
   return true;
}

bool GetDesiredPendingOrderCurrentMode(bool buy_side, ENUM_ORDER_TYPE &order_type, double &price, ENUM_ENTRY_GEOMETRY_V121 &geometry, string &reason, ulong exclude_order_ticket)
{
   if(UsarMotorAgressivoV121 && UsarEntradasDirecionaisIndependentes)
      return GetDesiredPendingOrderV121(buy_side, order_type, price, geometry, reason, exclude_order_ticket);

   geometry = ENTRY_GEOMETRY_RECOVERY;
   reason = "LEGACY";
   return GetDesiredPendingOrder(buy_side, order_type, price);
}

void ManageDynamicPendingOrders()
{
   if(IsMarketHandoffActiveV1232() || g_marketHandoffResolvedThisTickV1232)
      return;
   if(g_pendingMutationSentThisTickV1231)
      return;

   if(!UseDynamicPendingOrders)
   {
      CancelAllPendingOrders(PENDING_CANCEL_REASON_STRUCTURAL_INVALIDATION); // V1.2.3.3 PENDING LIFECYCLE FIX
      return;
   }

   int open_positions = CountOpenPositions();
   if(open_positions <= 0)
   {
      CancelAllPendingOrders(PENDING_CANCEL_REASON_GLOBAL_CLOSE); // V1.2.3.3 PENDING LIFECYCLE FIX
      return;
   }

   if(open_positions >= LimitOpenPositions())
   {
      CancelAllPendingOrders(PENDING_CANCEL_REASON_STRUCTURAL_INVALIDATION); // V1.2.3.3 PENDING LIFECYCLE FIX
      return;
   }

   if(!IsPendingFiltersOK())
      return;

   // V1.2.3.3 PENDING LIFECYCLE FIX: um replacement de tipo reservado tem
   // prioridade sobre reposicionamento e novas criacoes do mesmo lado.
   ProcessPendingReplacementV1233();
   if(g_pendingMutationSentThisTickV1231)
      return;

   RepositionDynamicPendingOrders();
   if(g_pendingMutationSentThisTickV1231)
      return;

   int pending_total = CountPendingOrders();
   int pending_buy = CountPendingBuyOrders();
   int pending_sell = CountPendingSellOrders();

   bool need_buy = (pending_buy < LimitPendingBuyOrders());
   bool need_sell = (pending_sell < LimitPendingSellOrders());

   if(UsarEntradasDirecionaisIndependentes)
   {
      if(need_buy && HasExposureRoomIncludingPendings(1))
         PlaceDynamicBuyPending();
      if(!g_pendingMutationSentThisTickV1231 && need_sell && HasExposureRoomIncludingPendings(1))
         PlaceDynamicSellPending();
      return;
   }

   int orders_to_add = (need_buy ? 1 : 0) + (need_sell ? 1 : 0);

   if(orders_to_add <= 0)
      return;

   if(pending_total + orders_to_add > LimitPendingOrders())
      return;

   if(!HasExposureRoomIncludingPendings(orders_to_add))
      return;

   if(PendingOrdersCountAsRisk && open_positions + pending_total + orders_to_add > LimitOpenPositions())
      return;

   if(need_buy)
      PlaceDynamicBuyPending();
   if(!g_pendingMutationSentThisTickV1231 && need_sell)
      PlaceDynamicSellPending();
}

bool PlaceDynamicBuyPending()
{
   if(IsMarketHandoffActiveV1232() || g_marketHandoffResolvedThisTickV1232)
      return false;
   if(g_pendingMutationSentThisTickV1231 || PendingLifecycleBusyV1231(true))
      return false;
   // V1.2.3.3 PENDING LIFECYCLE FIX: durante replacement reservado somente o
   // driver transacional pode criar a substituta deste lado.
   if(PendingReplaceActiveV1233(true))
   {
      g_pendingRecreateBlockedV1233++;
      LogThrottledV1232("recreate_blocked_buy_replacement",
                        "[V1233_PENDING_RECREATE_BLOCKED] lado=BUY motivo=replacement_ativo", 10);
      return false;
   }
   if(CountPendingBuyOrders() >= LimitPendingBuyOrders())
      return false;

   if(!IsPendingFiltersOK())
      return false;

   ENUM_ORDER_TYPE order_type;
   double price = 0.0;
   ENUM_ENTRY_GEOMETRY_V121 geometry = ENTRY_GEOMETRY_RECOVERY;
   string pending_reason = "";
   if(!GetDesiredPendingOrderCurrentMode(true, order_type, price, geometry, pending_reason))
   {
      if(UsarMotorAgressivoV121 && UsarEntradasDirecionaisIndependentes)
         LogThrottledV1232("pending_blocked_buy_" + pending_reason,
                           "[ENTRY_BLOCKED_V121] pending direction=BUY reason=" + pending_reason, 10);
      return false;
   }

   double lot = NormalizeVolume(FixedLot);
   if(lot <= 0.0)
      return false;

   string reason = "";
   if(!HasDirectionalSlotRoom(POSITION_TYPE_BUY, 1, lot, reason))
   {
      LogThrottledV1232("pending_invalid_buy_" + reason,
                        "[PENDING_INVALIDATED_BY_REGIME] direcao=BUY motivo=" + reason, 10);
      return false;
   }

   int regime = DetectRegimeConfirmado();
   if(!(UsarMotorAgressivoV121 && UsarEntradasDirecionaisIndependentes) && BloquearContraTendenciaExtrema && regime == -2)
   {
      LogThrottledV1232("pending_invalid_buy_contra_tendencia_extrema",
                        "[PENDING_INVALIDATED_BY_REGIME] direcao=BUY motivo=contra_tendencia_extrema", 10);
      return false;
   }

   double zone_points = (UsarMotorAgressivoV121 && UsarEntradasDirecionaisIndependentes ?
                         GetAdaptiveDistancePointsV121(POSITION_TYPE_BUY, geometry, DetectRegimeConfirmadoV121()) :
                         GetAdaptiveDistancePoints(POSITION_TYPE_BUY));
   if(UsarCompressorZonas && IsZoneAlreadyRepresented(POSITION_TYPE_BUY, price, zone_points))
   {
      LogThrottledV1232("pending_invalid_buy_zona_ja_representada",
                        "[PENDING_INVALIDATED_BY_REGIME] direcao=BUY motivo=zona_ja_representada", 10);
      return false;
   }

   double required_margin = 0.0;
   if(!HasMarginForOrderV122(order_type, lot, price, reason, required_margin))
      return false;

   bool order_accepted = RequestPendingCreateV1231(true, order_type, price, required_margin, pending_reason);
   if(order_accepted)
   {
      LogMessage("criacao de pendente BUY.");
      if(UsarMotorAgressivoV121 && UsarEntradasDirecionaisIndependentes)
         LogMessage("[ENTRY_EXECUTED_V121] pending direction=BUY geometry=" + GeometryToTextV121(geometry) +
                    " price=" + DoubleToString(price, _Digits));
      LogMessage("[PENDING_SLOT_RESERVED] direcao=BUY slot_total=" + IntegerToString(UsedExposureSlotsV122()));
   }

   return order_accepted;
}

bool PlaceDynamicSellPending()
{
   if(IsMarketHandoffActiveV1232() || g_marketHandoffResolvedThisTickV1232)
      return false;
   if(g_pendingMutationSentThisTickV1231 || PendingLifecycleBusyV1231(false))
      return false;
   // V1.2.3.3 PENDING LIFECYCLE FIX: durante replacement reservado somente o
   // driver transacional pode criar a substituta deste lado.
   if(PendingReplaceActiveV1233(false))
   {
      g_pendingRecreateBlockedV1233++;
      LogThrottledV1232("recreate_blocked_sell_replacement",
                        "[V1233_PENDING_RECREATE_BLOCKED] lado=SELL motivo=replacement_ativo", 10);
      return false;
   }
   if(CountPendingSellOrders() >= LimitPendingSellOrders())
      return false;

   if(!IsPendingFiltersOK())
      return false;

   ENUM_ORDER_TYPE order_type;
   double price = 0.0;
   ENUM_ENTRY_GEOMETRY_V121 geometry = ENTRY_GEOMETRY_RECOVERY;
   string pending_reason = "";
   if(!GetDesiredPendingOrderCurrentMode(false, order_type, price, geometry, pending_reason))
   {
      if(UsarMotorAgressivoV121 && UsarEntradasDirecionaisIndependentes)
         LogThrottledV1232("pending_blocked_sell_" + pending_reason,
                           "[ENTRY_BLOCKED_V121] pending direction=SELL reason=" + pending_reason, 10);
      return false;
   }

   double lot = NormalizeVolume(FixedLot);
   if(lot <= 0.0)
      return false;

   string reason = "";
   if(!HasDirectionalSlotRoom(POSITION_TYPE_SELL, 1, lot, reason))
   {
      LogThrottledV1232("pending_invalid_sell_" + reason,
                        "[PENDING_INVALIDATED_BY_REGIME] direcao=SELL motivo=" + reason, 10);
      return false;
   }

   int regime = DetectRegimeConfirmado();
   if(!(UsarMotorAgressivoV121 && UsarEntradasDirecionaisIndependentes) && BloquearContraTendenciaExtrema && regime == 2)
   {
      LogThrottledV1232("pending_invalid_sell_contra_tendencia_extrema",
                        "[PENDING_INVALIDATED_BY_REGIME] direcao=SELL motivo=contra_tendencia_extrema", 10);
      return false;
   }

   double zone_points = (UsarMotorAgressivoV121 && UsarEntradasDirecionaisIndependentes ?
                         GetAdaptiveDistancePointsV121(POSITION_TYPE_SELL, geometry, DetectRegimeConfirmadoV121()) :
                         GetAdaptiveDistancePoints(POSITION_TYPE_SELL));
   if(UsarCompressorZonas && IsZoneAlreadyRepresented(POSITION_TYPE_SELL, price, zone_points))
   {
      LogThrottledV1232("pending_invalid_sell_zona_ja_representada",
                        "[PENDING_INVALIDATED_BY_REGIME] direcao=SELL motivo=zona_ja_representada", 10);
      return false;
   }

   double required_margin = 0.0;
   if(!HasMarginForOrderV122(order_type, lot, price, reason, required_margin))
      return false;

   bool order_accepted = RequestPendingCreateV1231(false, order_type, price, required_margin, pending_reason);
   if(order_accepted)
   {
      LogMessage("criacao de pendente SELL.");
      if(UsarMotorAgressivoV121 && UsarEntradasDirecionaisIndependentes)
         LogMessage("[ENTRY_EXECUTED_V121] pending direction=SELL geometry=" + GeometryToTextV121(geometry) +
                    " price=" + DoubleToString(price, _Digits));
      LogMessage("[PENDING_SLOT_RESERVED] direcao=SELL slot_total=" + IntegerToString(UsedExposureSlotsV122()));
   }

   return order_accepted;
}

void RepositionDynamicPendingOrders()
{
   if(IsMarketHandoffActiveV1232() || g_marketHandoffResolvedThisTickV1232)
      return;
   if(g_pendingMutationSentThisTickV1231)
      return;
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
      double current_price = OrderGetDouble(ORDER_PRICE_OPEN);

      bool buy_side = IsBuyPendingType(current_type);
      if(PendingLifecycleBusyV1231(buy_side))
         continue;
      // V1.2.3.3 PENDING LIFECYCLE FIX: lado sob replacement pertence ao driver
      if(PendingReplaceActiveV1233(buy_side))
         continue;
      ENUM_ORDER_TYPE desired_type;
      double desired_price = 0.0;
      ENUM_ENTRY_GEOMETRY_V121 geometry = ENTRY_GEOMETRY_RECOVERY;
      string pending_reason = "";
      if(!GetDesiredPendingOrderCurrentMode(buy_side, desired_type, desired_price, geometry, pending_reason, ticket))
      {
         // Zona temporariamente representada nao torna a pendente existente
         // invalida. Mantem a ordem para evitar ciclo delete/create.
         if(pending_reason == "zona_ja_representada")
         {
            static datetime last_buy_self_zone_log = 0;
            static datetime last_sell_self_zone_log = 0;
            datetime last_log = (buy_side ? last_buy_self_zone_log : last_sell_self_zone_log);
            if(last_log <= 0 || TimeCurrent() - last_log >= MathMax(1, TradeReconciliationTimeoutSeconds))
            {
               LogPendingLifecycleV1231("[V1231_PENDING_SELF_ZONE_EXCLUDED]", buy_side,
                                        (buy_side ? g_buyPendingStateV1231 : g_sellPendingStateV1231),
                                        (buy_side ? g_buyPendingStateV1231 : g_sellPendingStateV1231),
                                        ticket, current_type, current_price, 0.0,
                                        PENDING_ACTION_NONE, "proprio_ticket_excluido_da_zona");
               if(buy_side) last_buy_self_zone_log = TimeCurrent();
               else last_sell_self_zone_log = TimeCurrent();
            }
            continue;
         }

         if(UsarMotorAgressivoV121 && UsarEntradasDirecionaisIndependentes)
         {
            g_pendingRegimeInvalidationsV1231++;
            // V1.2.3.3 PENDING LIFECYCLE FIX: invalidacao genuina (avaliada sem o
            // proprio slot da ordem) recebe motivo estrutural explicito.
            ENUM_PENDING_CANCEL_REASON_V1233 invalid_code =
               (pending_reason == "preco_pendente_invalido" ? PENDING_CANCEL_REASON_INVALID_PRICE
                                                            : PENDING_CANCEL_REASON_STRUCTURAL_INVALIDATION);
            if(RequestPendingCancelV1231(buy_side, ticket, invalid_code, "invalida_" + pending_reason))
               LogMessage("[ENTRY_BLOCKED_V121] pending invalidated reason=" + pending_reason);
         }
         if(g_pendingMutationSentThisTickV1231)
            return;
         continue;
      }

      // GetDesiredPendingOrderCurrentMode() percorre posicoes/ordens ao testar
      // zonas. Re-seleciona explicitamente o ticket original antes de ler ou
      // mutar seus atributos.
      ENUM_ORDER_TYPE refreshed_type = current_type;
      if(!PendingTicketExistsV1231(ticket, refreshed_type, current_price))
         continue;
      current_type = refreshed_type;
      bool wrong_type = (current_type != desired_type);
      bool far_from_target = (MathAbs(current_price - desired_price) >= threshold);

      if(wrong_type)
      {
         // V1.2.3.3 PENDING LIFECYCLE FIX: mudanca estrutural real de tipo
         // (stop <-> limit) vira replacement transacional. A substituta e
         // validada ANTES do cancelamento, o tipo fica reservado, o gerenciador
         // do lado fica bloqueado e o driver cria exatamente a ordem reservada
         // apos a confirmacao do servidor (REPLACED / RELEASED / TIMEOUT).
         double replace_lot = NormalizeVolume(FixedLot);
         string replace_reason = "";
         double replace_margin = 0.0;
         if(!HasMarginForOrderV122(desired_type, replace_lot, desired_price, replace_reason, replace_margin))
         {
            LogThrottledV1232("replace_margin_blocked_" + (buy_side ? "BUY" : "SELL"),
                              "[V1233_PENDING_MUTATION_BLOCKED] origem=replacement ticket=" + IntegerToString((int)ticket) +
                              " motivo=sem_margem_substituta", 10);
            continue;
         }
         if(RequestPendingCancelV1231(buy_side, ticket, PENDING_CANCEL_REASON_REPLACE_ORDER_TYPE, "mudanca_tipo_pendente"))
         {
            g_pendingReplaceRequestsV1233++;
            if(buy_side)
            {
               g_buyPendingReplaceActiveV1233 = true;
               g_buyPendingReplaceTypeV1233 = desired_type;
               g_buyPendingReplaceOldTicketV1233 = ticket;
               g_buyPendingReplaceSinceV1233 = TimeCurrent();
            }
            else
            {
               g_sellPendingReplaceActiveV1233 = true;
               g_sellPendingReplaceTypeV1233 = desired_type;
               g_sellPendingReplaceOldTicketV1233 = ticket;
               g_sellPendingReplaceSinceV1233 = TimeCurrent();
            }
            LogMessage("[V1233_PENDING_REPLACE_RESERVED] lado=" + (buy_side ? "BUY" : "SELL") +
                       " ticket_antigo=" + IntegerToString((int)ticket) +
                       " tipo_atual=" + EnumToString(current_type) +
                       " tipo_reservado=" + EnumToString(desired_type) +
                       " preco_alvo=" + DoubleToString(desired_price, _Digits));
            LogMessage("[V123_PENDING_TYPE_CHANGED] ticket=" + IntegerToString((int)ticket));
         }
         if(g_pendingMutationSentThisTickV1231)
            return;
         continue;
      }

      if(!far_from_target)
         continue;

      bool reposition_toward_market = false;
      if(current_type == ORDER_TYPE_BUY_STOP)
         reposition_toward_market = (desired_price < current_price);
      else if(current_type == ORDER_TYPE_BUY_LIMIT)
         reposition_toward_market = (desired_price > current_price);
      else if(current_type == ORDER_TYPE_SELL_STOP)
         reposition_toward_market = (desired_price > current_price);
      else if(current_type == ORDER_TYPE_SELL_LIMIT)
         reposition_toward_market = (desired_price < current_price);

      // Se o mercado esta se aproximando da pendente, nao afastar a ordem.
      if(CorrigirPerseguicaoPendentesV123 && !reposition_toward_market)
      {
         LogThrottledV1232("pending_hold_" + IntegerToString((int)ticket),
                           "[V123_PENDING_HOLD_FOR_TRIGGER] ticket=" + IntegerToString((int)ticket) +
                           " atual=" + DoubleToString(current_price, _Digits) +
                           " desejado=" + DoubleToString(desired_price, _Digits), 10);
         continue;
      }

      if(RequestPendingModifyV1231(buy_side, ticket, desired_price, "reposicionar_em_direcao_ao_mercado"))
      {
         LogMessage("[V123_PENDING_REPOSITION_TOWARD_MARKET] ticket=" + IntegerToString((int)ticket) +
                    " preco=" + DoubleToString(desired_price, _Digits));
      }
      if(g_pendingMutationSentThisTickV1231)
         return;
   }
}

void CancelInvalidPendingOrders()
{
   if(IsMarketHandoffActiveV1232() || g_marketHandoffResolvedThisTickV1232)
      return;
   if(g_pendingMutationSentThisTickV1231)
      return;
   int open_positions = CountOpenPositions();

   if(open_positions <= 0 || open_positions >= LimitOpenPositions())
   {
      if(CountPendingOrders() > 0)
         CancelAllPendingOrders(open_positions <= 0 ? PENDING_CANCEL_REASON_GLOBAL_CLOSE
                                                    : PENDING_CANCEL_REASON_STRUCTURAL_INVALIDATION); // V1.2.3.3 PENDING LIFECYCLE FIX
      return;
   }

   if(!AllowTrading || !IsSpreadOK() || !IsTradingHourOK() || IsNewsBlocked() || g_dailyLossBlocked || g_dailyProfitBlocked || g_basketDDBlocked)
   {
      if(CountPendingOrders() > 0)
      {
         // V1.2.3.3 PENDING LIFECYCLE FIX: classifica o bloqueio ativo
         ENUM_PENDING_CANCEL_REASON_V1233 block_code = PENDING_CANCEL_REASON_STRUCTURAL_INVALIDATION;
         if(!AllowTrading)
            block_code = PENDING_CANCEL_REASON_SYMBOL_DISABLED;
         else if(g_dailyLossBlocked || g_dailyProfitBlocked || g_basketDDBlocked)
            block_code = PENDING_CANCEL_REASON_RISK_EMERGENCY;
         CancelAllPendingOrders(block_code);
      }
      return;
   }

   if(open_positions + CountPendingOrders() > LimitOpenPositions())
   {
      CancelAllPendingOrders(PENDING_CANCEL_REASON_STRUCTURAL_INVALIDATION); // V1.2.3.3 PENDING LIFECYCLE FIX
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

      // V1.2.3.3 PENDING LIFECYCLE FIX: lado sob replacement pertence ao driver
      if(PendingReplaceActiveV1233(IsBuyPendingType(type)))
         continue;

      datetime expiration = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
      bool expired = (expiration > 0 && expiration <= TimeCurrent());
      bool delete_order = expired;
      string reason = "";
      // V1.2.3.3 PENDING LIFECYCLE FIX: motivo explicito por cancelamento
      ENUM_PENDING_CANCEL_REASON_V1233 cancel_code =
         (expired ? PENDING_CANCEL_REASON_EXPIRED : PENDING_CANCEL_REASON_NONE);

      if(IsBuyPendingType(type) && !HasDirectionalSlotRoom(POSITION_TYPE_BUY, 0, 0.0, reason))
      {
         delete_order = true;
         if(cancel_code == PENDING_CANCEL_REASON_NONE)
            cancel_code = PENDING_CANCEL_REASON_STRUCTURAL_INVALIDATION;
         LogMessage("[PENDING_INVALIDATED] direcao=BUY motivo=" + reason);
      }

      int regime = DetectRegimeConfirmado();
      if(IsBuyPendingType(type) && !(UsarMotorAgressivoV121 && UsarEntradasDirecionaisIndependentes) &&
         BloquearContraTendenciaExtrema && regime == -2)
      {
         delete_order = true;
         if(cancel_code == PENDING_CANCEL_REASON_NONE)
            cancel_code = PENDING_CANCEL_REASON_STRUCTURAL_INVALIDATION;
         LogMessage("[PENDING_INVALIDATED] direcao=BUY motivo=contra_tendencia_extrema");
      }

      if(IsSellPendingType(type) && !HasDirectionalSlotRoom(POSITION_TYPE_SELL, 0, 0.0, reason))
      {
         delete_order = true;
         if(cancel_code == PENDING_CANCEL_REASON_NONE)
            cancel_code = PENDING_CANCEL_REASON_STRUCTURAL_INVALIDATION;
         LogMessage("[PENDING_INVALIDATED] direcao=SELL motivo=" + reason);
      }

      if(IsSellPendingType(type) && !(UsarMotorAgressivoV121 && UsarEntradasDirecionaisIndependentes) &&
         BloquearContraTendenciaExtrema && regime == 2)
      {
         delete_order = true;
         if(cancel_code == PENDING_CANCEL_REASON_NONE)
            cancel_code = PENDING_CANCEL_REASON_STRUCTURAL_INVALIDATION;
         LogMessage("[PENDING_INVALIDATED] direcao=SELL motivo=contra_tendencia_extrema");
      }

      if(IsBuyPendingType(type))
      {
         if(keep_buy || kept_total >= LimitPendingOrders())
         {
            delete_order = true;
            if(cancel_code == PENDING_CANCEL_REASON_NONE)
               cancel_code = PENDING_CANCEL_REASON_RECONCILIATION; // V1.2.3.3: duplicada alem do limite
         }
         else
         {
            keep_buy = true;
            kept_total++;
         }
      }
      else if(IsSellPendingType(type))
      {
         if(keep_sell || kept_total >= LimitPendingOrders())
         {
            delete_order = true;
            if(cancel_code == PENDING_CANCEL_REASON_NONE)
               cancel_code = PENDING_CANCEL_REASON_RECONCILIATION; // V1.2.3.3: duplicada alem do limite
         }
         else
         {
            keep_sell = true;
            kept_total++;
         }
      }

      if(delete_order)
      {
         bool buy_side = IsBuyPendingType(type);
         if(cancel_code == PENDING_CANCEL_REASON_NONE)
            cancel_code = PENDING_CANCEL_REASON_STRUCTURAL_INVALIDATION;
         if(RequestPendingCancelV1231(buy_side, ticket, cancel_code,
                                      (expired ? "expirada_ou_invalida" : "invalida_ou_duplicada")))
            LogMessage("cancelamento de pendentes.");
         if(g_pendingMutationSentThisTickV1231)
            return;
      }
   }
}

void CancelAllPendingOrders(ENUM_PENDING_CANCEL_REASON_V1233 reason_code) // V1.2.3.3 PENDING LIFECYCLE FIX
{
   if(IsMarketHandoffActiveV1232())
   {
      g_marketHandoffReleasedV1232++;
      ClearMarketEntryHandoffV1232("cancelamento_global_ou_risco");
   }
   // V1.2.3.3 PENDING LIFECYCLE FIX: um cancelamento global encerra qualquer
   // replacement reservado; a substituta nao pode nascer durante risco/flat.
   if(PendingReplaceActiveV1233(true))
      ReleasePendingReplacementV1233(true, "cancelamento_global_" + PendingCancelReasonTextV1233(reason_code));
   if(PendingReplaceActiveV1233(false))
      ReleasePendingReplacementV1233(false, "cancelamento_global_" + PendingCancelReasonTextV1233(reason_code));
   if(g_pendingMutationSentThisTickV1231)
      return;

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

      bool buy_side = IsBuyPendingType(type);
      if(RequestPendingCancelV1231(buy_side, ticket, reason_code, "cancelar_todas_pendentes", true))
         LogMessage("cancelamento de pendentes.");
      // Uma unica autoridade e uma unica mutacao por tick, mesmo durante
      // encerramentos. As demais pendentes sao reconciliadas nos ticks seguintes.
      if(g_pendingMutationSentThisTickV1231)
         return;
   }
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

int CountBuyExposureSlots()
{
   return CountBuyPositions() + CountPendingBuyOrders();
}

int CountSellExposureSlots()
{
   return CountSellPositions() + CountPendingSellOrders();
}

double GetBuyExposureLots()
{
   double lots = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!IsOurPositionByIndex(i))
         continue;

      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         lots += PositionGetDouble(POSITION_VOLUME);
   }

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!IsOurOrderByIndex(i))
         continue;

      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(IsBuyPendingType(type))
         lots += OrderGetDouble(ORDER_VOLUME_CURRENT);
   }

   return lots;
}

double GetSellExposureLots()
{
   double lots = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!IsOurPositionByIndex(i))
         continue;

      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         lots += PositionGetDouble(POSITION_VOLUME);
   }

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!IsOurOrderByIndex(i))
         continue;

      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(IsSellPendingType(type))
         lots += OrderGetDouble(ORDER_VOLUME_CURRENT);
   }

   return lots;
}

double GetNetExposureLots()
{
   return MathAbs(GetBuyExposureLots() - GetSellExposureLots());
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
   if(CountOpenPositions() > 0 || CountPendingOrders() > 0)
      StartClosingScopeV122("close_all_basket");
   if(CountPendingOrders() > 0)
      CancelAllPendingOrders(PENDING_CANCEL_REASON_GLOBAL_CLOSE); // V1.2.3.3 PENDING LIFECYCLE FIX
   SetExitStateV122(EXIT_CLOSING_POSITIONS, "close_all_basket");

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

   SetExitStateV122(EXIT_RECONCILING, "close_all_basket_sent");

   return all_ok;
}

bool CloseBuyBasket()
{
   bool all_ok = true;
   if(CountBuyPositions() > 0)
      StartClosingScopeV122("close_buy_basket");
   SetExitStateV122(EXIT_CLOSING_POSITIONS, "close_buy_basket");

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

   SetExitStateV122(EXIT_RECONCILING, "close_buy_basket_sent");

   return all_ok;
}

bool CloseSellBasket()
{
   bool all_ok = true;
   if(CountSellPositions() > 0)
      StartClosingScopeV122("close_sell_basket");
   SetExitStateV122(EXIT_CLOSING_POSITIONS, "close_sell_basket");

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

   SetExitStateV122(EXIT_RECONCILING, "close_sell_basket_sent");

   return all_ok;
}

int DirectionalBiasSignV123()
{
   if(g_directionalBiasV122 == BIAS_BUY || g_directionalBiasV122 == BIAS_STRONG_BUY)
      return 1;
   if(g_directionalBiasV122 == BIAS_SELL || g_directionalBiasV122 == BIAS_STRONG_SELL)
      return -1;
   return 0;
}

string ClassifySideV123(ENUM_POSITION_TYPE direction)
{
   int count = (direction == POSITION_TYPE_BUY ? CountBuyPositions() : CountSellPositions());
   if(count <= 0)
      return "ABSENT";

   double side_profit = (direction == POSITION_TYPE_BUY ? GetBuyBasketProfit() : GetSellBasketProfit());
   int side_sign = (direction == POSITION_TYPE_BUY ? 1 : -1);
   int bias_sign = DirectionalBiasSignV123();

   if(bias_sign == 0)
   {
      if(side_profit >= Minimum_trailing_profit)
         return "PROTECTED";
      if(side_profit < 0.0)
         return "RECOVERY";
      return "BALANCED";
   }

   if(side_sign == bias_sign)
   {
      if(side_profit >= Minimum_trailing_profit)
         return "RUNNER";
      return "STRONG";
   }

   if(side_profit < 0.0)
      return "WEAK";
   return "RECOVERY";
}

void UpdateSideIdentificationV123()
{
   if(!IdentificarLadoForteFracoV123)
      return;

   string buy_state = ClassifySideV123(POSITION_TYPE_BUY);
   string sell_state = ClassifySideV123(POSITION_TYPE_SELL);
   if(buy_state == g_buySideStateV123 && sell_state == g_sellSideStateV123)
      return;

   g_buySideStateV123 = buy_state;
   g_sellSideStateV123 = sell_state;
   LogMessage("[V123_SIDE_CLASSIFICATION] BUY=" + buy_state +
              " profit_buy=" + DoubleToString(GetBuyBasketProfit(), 2) +
              " SELL=" + sell_state +
              " profit_sell=" + DoubleToString(GetSellBasketProfit(), 2) +
              " bias=" + BiasToTextV122(g_directionalBiasV122));
}

bool TryExtractWeakSideV123(string trigger)
{
   if(!UsarExtracaoContinuaV123 || !PreservarLadoForteNaExtracaoV123)
      return false;
   if(CountBuyPositions() <= 0 || CountSellPositions() <= 0)
      return false;

   int bias_sign = DirectionalBiasSignV123();
   if(bias_sign == 0)
      return false;

   if(CooldownExtracaoLadoSegundosV123 > 0 && g_lastSideExtractionTimeV123 > 0 &&
      (int)(TimeCurrent() - g_lastSideExtractionTimeV123) < CooldownExtracaoLadoSegundosV123)
      return false;

   double basket_profit = GetBasketProfit();
   double strong_profit = (bias_sign > 0 ? GetBuyBasketProfit() : GetSellBasketProfit());
   double weak_profit = (bias_sign > 0 ? GetSellBasketProfit() : GetBuyBasketProfit());
   if(basket_profit < MathMax(0.0, LucroMinimoCestaExtracaoV123))
      return false;
   if(strong_profit < MathMax(0.0, LucroMinimoLadoForteV123))
      return false;

   string strong_side = (bias_sign > 0 ? "BUY" : "SELL");
   string weak_side = (bias_sign > 0 ? "SELL" : "BUY");
   LogMessage("[V123_STRONG_SIDE_HOLD] trigger=" + trigger +
              " strong=" + strong_side +
              " strong_profit=" + DoubleToString(strong_profit, 2) +
              " weak=" + weak_side +
              " weak_profit=" + DoubleToString(weak_profit, 2) +
              " basket=" + DoubleToString(basket_profit, 2));

   bool closed = (bias_sign > 0 ? CloseSellBasket() : CloseBuyBasket());
   if(closed)
   {
      g_lastSideExtractionTimeV123 = TimeCurrent();
      LogMessage("[V123_WEAK_SIDE_CUT] trigger=" + trigger +
                 " side=" + weak_side +
                 " strong_side_preserved=" + strong_side);
   }
   return closed;
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
         if(TryExtractWeakSideV123("BASKET_TARGET"))
            return;
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
      if(TryExtractWeakSideV123("PRICE_LINE"))
         return;
      LogMessage("fechamento por linha dinamica.");
      CloseAllBasket();
   }
}

void ManageBreakEven()
{
   if(!UseBreakEven)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;

      double profit = GetSelectedPositionProfitWithCosts();
      if(profit < BreakEvenStartUSD || profit <= 0.0)
         continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double volume = PositionGetDouble(POSITION_VOLUME);
      double current_sl = PositionGetDouble(POSITION_SL);
      double current_tp = PositionGetDouble(POSITION_TP);
      double lock_distance = USDToPriceDistance(BreakEvenLockUSD, volume);
      if(lock_distance <= 0.0)
         continue;

      double new_sl = 0.0;

      if(type == POSITION_TYPE_BUY)
      {
         new_sl = NormalizePrice(open_price + lock_distance);
         if(current_sl > 0.0 && new_sl <= current_sl)
            continue;
         if(new_sl <= open_price)
            continue;
      }
      else
      {
         new_sl = NormalizePrice(open_price - lock_distance);
         if(current_sl > 0.0 && new_sl >= current_sl)
            continue;
         if(new_sl >= open_price)
            continue;
      }

      ModifyPositionSL(ticket, new_sl, current_tp, "breakeven aplicado");
   }
}

void ManageSmartTrailing()
{
   if(!UseSmartTrailing || Trailing_type == 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;

      double profit = GetSelectedPositionProfitWithCosts();
      if(profit < Minimum_trailing_profit || profit <= 0.0)
         continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double volume = PositionGetDouble(POSITION_VOLUME);
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double current_sl = PositionGetDouble(POSITION_SL);
      double current_tp = PositionGetDouble(POSITION_TP);
      double stop_distance = USDToPriceDistance(Trailing_stop, volume);
      double step_distance = USDToPriceDistance(Trailing_step, volume);
      if(stop_distance <= 0.0 || step_distance <= 0.0)
         continue;

      double new_sl = 0.0;

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
               new_sl = NormalizePrice(low - (double)Padding_by_fractals_or_candles * _Point);
            }
            else
            {
               double high = rates[1].high;
               for(int b = 2; b < copied && b <= 4; b++)
                  high = MathMax(high, rates[b].high);
               new_sl = NormalizePrice(high + (double)Padding_by_fractals_or_candles * _Point);
            }
         }
      }
      else if(Trailing_type == 2)
      {
         double basket_avg = GetBasketAveragePrice();
         if(basket_avg > 0.0)
         {
            if(type == POSITION_TYPE_BUY)
               new_sl = NormalizePrice(MathMax(open_price, basket_avg) + step_distance);
            else
               new_sl = NormalizePrice(MathMin(open_price, basket_avg) - step_distance);
         }
      }
      else if(Trailing_type == 3)
      {
         if(type == POSITION_TYPE_BUY)
            new_sl = NormalizePrice(g_tick.bid - stop_distance);
         else
            new_sl = NormalizePrice(g_tick.ask + stop_distance);
      }

      if(new_sl <= 0.0)
      {
         if(type == POSITION_TYPE_BUY)
            new_sl = NormalizePrice(g_tick.bid - stop_distance);
         else
            new_sl = NormalizePrice(g_tick.ask + stop_distance);
      }

      if(type == POSITION_TYPE_BUY)
      {
         if(new_sl <= open_price)
            continue;
         if(current_sl > 0.0 && new_sl <= current_sl + step_distance)
            continue;
      }
      else
      {
         if(new_sl >= open_price)
            continue;
         if(current_sl > 0.0 && new_sl >= current_sl - step_distance)
            continue;
      }

      ModifyPositionSL(ticket, new_sl, current_tp, "trailing aplicado");
   }
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
   if(DDBloqueioAntesFechamentoUSD > 0.0)
      block_loss = MathAbs(DDBloqueioAntesFechamentoUSD);
   double close_loss = MathAbs(Loss_for_closing);
   if(DDFechamentoObrigatorioUSD > 0.0)
      close_loss = MathAbs(DDFechamentoObrigatorioUSD);
   if(close_loss <= 0.0)
      close_loss = block_loss;

   if(block_loss > 0.0 && profit <= -block_loss)
   {
      g_basketDDBlocked = true;
      SetStatus("DD BLOQUEADO", "bloqueio por DD");
      CancelAllPendingOrders(PENDING_CANCEL_REASON_RISK_EMERGENCY); // V1.2.3.3 PENDING LIFECYCLE FIX
   }

   if(close_loss > 0.0 && profit <= -close_loss)
   {
      LogMessage("fechamento obrigatorio por DD maximo da cesta.");
      CloseAllBasket();
      return;
   }

   if(Close_loss_by_drawdown && MathAbs(Loss_for_closing) > 0.0 && profit <= -MathAbs(Loss_for_closing))
   {
      LogMessage("fechamento por DD maximo legado da cesta.");
      CloseAllBasket();
   }
}

void ManageDailyRisk()
{
   g_dailyResult = GetTodayClosedProfit() + GetBasketProfit();
   if(g_dailyStartEquity > 0.0)
      g_dailyAccountResult = AccountInfoDouble(ACCOUNT_EQUITY) - g_dailyStartEquity;

   if(MaxDailyLossUSD <= 0.0)
   {
      if(!UsarRiscoDiarioEquityConta || MaxDailyLossContaUSD <= 0.0)
         return;
   }

   if(g_dailyResult <= -MathAbs(MaxDailyLossUSD))
   {
      if(StopTradingAfterDailyLoss)
      {
         g_dailyLossBlocked = true;
         SetStatus("LOSS DIARIO", "bloqueio por loss diario");
      }

      if(ClosePositionsAtDailyLoss && CountOpenPositions() > 0)
      {
         LogMessage("fechamento por loss diario.");
         CloseAllBasket();
      }
   }

   if(UsarRiscoDiarioEquityConta && MaxDailyLossContaUSD > 0.0 &&
      g_dailyAccountResult <= -MathAbs(MaxDailyLossContaUSD))
   {
      g_accountDailyLossBlocked = true;
      SetStatus("LOSS DIARIO", "bloqueio por loss diario da conta");
      CancelAllPendingOrders(PENDING_CANCEL_REASON_RISK_EMERGENCY); // V1.2.3.3 PENDING LIFECYCLE FIX

      if(FecharEsteEASeLossConta && CountOpenPositions() > 0)
      {
         LogMessage("fechamento deste EA por loss diario da conta.");
         CloseAllBasket();
      }
   }
}

void ManageDailyProfitTarget()
{
   g_dailyResult = GetTodayClosedProfit() + GetBasketProfit();

   if(DailyProfitTargetUSD <= 0.0)
      return;

   if(g_dailyResult >= DailyProfitTargetUSD)
   {
      if(StopTradingAfterDailyProfit)
      {
         g_dailyProfitBlocked = true;
         SetStatus("META BATIDA", "meta diaria atingida");
      }
      else
         SetStatus("META BATIDA");
   }
}

void ResetarPicoLucroCesta()
{
   g_PicoLucroCestaUSD = 0.0;
   g_FechamentoMFECestaEmAndamento = false;
   g_MAELucroCestaUSD = 0.0;
   PersistBasketState();

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

   if(lucroAtualCesta < g_MAELucroCestaUSD)
   {
      g_MAELucroCestaUSD = lucroAtualCesta;
      PersistBasketState();
   }

   if(lucroAtualCesta > g_PicoLucroCestaUSD)
   {
      g_PicoLucroCestaUSD = lucroAtualCesta;
      PersistBasketState();

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
   double basket_dd = (basket_profit < 0.0 ? MathAbs(basket_profit) : 0.0);
   double distance = DistanceFromLastPairPoints();
   double required = RequiredAdditionalDistancePoints();
   double remaining_distance = MathMax(0.0, required - distance);
   int seconds_since_pair = (g_lastPairOpenTime > 0 ? (int)(TimeCurrent() - g_lastPairOpenTime) : 0);
   int regime_v121 = DetectRegimeConfirmadoV121();
   double recovery_distance_v121 = GetAdaptiveDistancePointsV121(POSITION_TYPE_BUY, ENTRY_GEOMETRY_RECOVERY, regime_v121);
   double momentum_distance_v121 = GetAdaptiveDistancePointsV121(POSITION_TYPE_BUY, ENTRY_GEOMETRY_MOMENTUM, regime_v121);
   int buy_cooldown_v121 = 0;
   int sell_cooldown_v121 = 0;
   if(CooldownEntradaDirecionalSegundosV121 > 0)
   {
      if(g_lastBuyAdditionalTimeV121 > 0)
         buy_cooldown_v121 = MathMax(0, CooldownEntradaDirecionalSegundosV121 - (int)(TimeCurrent() - g_lastBuyAdditionalTimeV121));
      if(g_lastSellAdditionalTimeV121 > 0)
         sell_cooldown_v121 = MathMax(0, CooldownEntradaDirecionalSegundosV121 - (int)(TimeCurrent() - g_lastSellAdditionalTimeV121));
   }

   string panel =
      EA_NAME + "\n" +
      "Versao: V1.2.3.2 PENDING HANDOFF FIXED\n" +
      "Simbolo: " + _Symbol + "\n" +
      "Timeframe: " + EnumToString((ENUM_TIMEFRAMES)_Period) + "\n" +
      "Conta: " + (IsHedgingAccount() ? "HEDGE" : "NETTING") + "\n" +
      "Spread atual: " + DoubleToString(GetCurrentSpreadPoints(), 1) + " pontos\n" +
      "Price Action Bias: " + BiasToText(pa, "ALTA", "QUEDA") + "\n" +
      "Volume Flow: " + BiasToText(flow, "COMPRADOR", "VENDEDOR") + "\n" +
      "Pares abertos: " + IntegerToString(CountPairs()) + "\n" +
      "BUYs abertas: " + IntegerToString(CountBuyPositions()) + "\n" +
      "SELLs abertas: " + IntegerToString(CountSellPositions()) + "\n" +
      "Posicoes totais: " + IntegerToString(CountOpenPositions()) + "\n" +
      "Pendentes BUY: " + IntegerToString(CountPendingBuyOrders()) + "\n" +
      "Pendentes SELL: " + IntegerToString(CountPendingSellOrders()) + "\n" +
      "Pendentes totais: " + IntegerToString(CountPendingOrders()) + "\n" +
      "Pending State BUY/SELL: " + PendingLifecycleStateTextV1231(g_buyPendingStateV1231) + "/" + PendingLifecycleStateTextV1231(g_sellPendingStateV1231) + "\n" +
      "Pending Creates BUY/SELL: " + IntegerToString(g_pendingCreatesBuyV1231) + "/" + IntegerToString(g_pendingCreatesSellV1231) + "\n" +
      "Pending Modifies BUY/SELL: " + IntegerToString(g_pendingModifiesBuyV1231) + "/" + IntegerToString(g_pendingModifiesSellV1231) + "\n" +
      "Pending Cancels BUY/SELL: " + IntegerToString(g_pendingCancelsBuyV1231) + "/" + IntegerToString(g_pendingCancelsSellV1231) + "\n" +
      "Pending Timeouts/Busy: " + IntegerToString(g_pendingTimeoutsV1231) + "/" + IntegerToString(g_pendingBusyBlocksV1231) + "\n" +
      "Market Handoff: " + MarketHandoffStateTextV1232() + "\n" +
      "Handoff motivo: " + g_marketHandoffReasonV1232 + "\n" +
      "Handoff Req/Exec/Release: " + IntegerToString(g_marketHandoffRequestsV1232) + "/" + IntegerToString(g_marketHandoffExecutedV1232) + "/" + IntegerToString(g_marketHandoffReleasedV1232) + "\n" +
      "Slots exposicao: " + IntegerToString(UsedExposureSlotsV122()) + "/" + IntegerToString(LimitOpenPositions()) + "\n" +
      "Slots reservados V122: " + IntegerToString(g_reservedSlotsV122) + "\n" +
      "Exposicao liquida: " + DoubleToString(GetNetExposureLots(), 2) + " lotes\n" +
      "Lucro da cesta: " + DoubleToString(basket_profit, 2) + " USD\n" +
      "Pico Lucro Cesta: " + DoubleToString(g_PicoLucroCestaUSD, 2) + " USD\n" +
      "DD da cesta: " + DoubleToString(basket_dd, 2) + " USD\n" +
      "Lucro diario: " + DoubleToString(g_dailyResult, 2) + " USD\n" +
      "Lucro diario conta: " + DoubleToString(g_dailyAccountResult, 2) + " USD\n" +
      "ATR M15: " + DoubleToString(g_lastATRPoints, 1) + " pontos\n" +
      "MotorV121: " + (UsarMotorAgressivoV121 ? "AGGRESSIVE" : "LEGACY") + "\n" +
      "Motor agressivo: " + (UsarMotorAgressivoV121 ? "ON" : "OFF") + "\n" +
      "Presenca bilateral: " + (ManterPresencaBilateralV122 ? "ON" : "OFF") + "\n" +
      "Bias V122: " + BiasToTextV122(g_directionalBiasV122) + " conf " + DoubleToString(GetBiasConfidenceV122(), 1) + "\n" +
      "Estado BUY/SELL V123: " + g_buySideStateV123 + "/" + g_sellSideStateV123 + "\n" +
      "Extracao continua V123: " + (UsarExtracaoContinuaV123 ? "ON" : "OFF") + "\n" +
      "Alocacao alvo: BUY " + IntegerToString(GetTargetBuySlotsV122()) + " / SELL " + IntegerToString(GetTargetSellSlotsV122()) + "\n" +
      "Tempo sem BUY/SELL: " + IntegerToString(GetSecondsWithoutBuyV122()) + "/" + IntegerToString(GetSecondsWithoutSellV122()) + "s\n" +
      "Estado fechamento: " + ExitStateToTextV122(g_exitState) + "\n" +
      "Reabertura cesta: " + (g_waitingPairReopen ? "AGUARDANDO" : "INATIVA") + " restam " + IntegerToString(RemainingFlatDelayV122()) + "s\n" +
      "Ultimo bloqueio: " + g_lastEntryBlockReasonV122 + "\n" +
      "Regime V121: " + RegimeToTextV121(regime_v121) + "\n" +
      "Melhor BUY V121: " + g_bestBuyCandidateTextV121 + "\n" +
      "Melhor SELL V121: " + g_bestSellCandidateTextV121 + "\n" +
      "Dist V121 REC/MOM: " + DoubleToString(recovery_distance_v121, 1) + "/" + DoubleToString(momentum_distance_v121, 1) + " pontos\n" +
      "Cooldown BUY/SELL V121: " + IntegerToString(buy_cooldown_v121) + "/" + IntegerToString(sell_cooldown_v121) + "s\n" +
      "Orcamento candle V121: " + IntegerToString(g_totalEntriesThisCandleV121) + "/" + IntegerToString(MaxEntradasAdicionaisPorCandleV121) +
      " BUY " + IntegerToString(g_buyEntriesThisCandleV121) + " SELL " + IntegerToString(g_sellEntriesThisCandleV121) + "\n" +
      "Bloqueio BUY/SELL V121: " + g_lastBuyBlockReasonV121 + "/" + g_lastSellBlockReasonV121 + "\n" +
      "Entradas REC/MOM dia V121: " + IntegerToString(g_recoveryEntriesTodayV121) + "/" + IntegerToString(g_momentumEntriesTodayV121) + "\n" +
      "Preco medio BUY: " + DoubleToString(GetAverageBuyPrice(), _Digits) + "\n" +
      "Preco medio SELL: " + DoubleToString(GetAverageSellPrice(), _Digits) + "\n" +
      "Preco medio geral: " + DoubleToString(GetBasketAveragePrice(), _Digits) + "\n" +
      "Preco alvo de fechamento: " + DoubleToString(GetDynamicBasketClosePrice(), _Digits) + "\n" +
      "Distancia ate proximo par: " + DoubleToString(remaining_distance, 1) + " pontos\n" +
      "Tempo desde ultimo par: " + IntegerToString(seconds_since_pair) + "s\n" +
      "Status operacional: " + ComputePanelStatus();

   Comment(panel);
}

void LogMessage(string msg)
{
   if(!EnableLogs)
      return;

   datetime now = TimeCurrent();
   if(msg == g_lastLogMessage && now - g_lastLogTime < 10)
      return;

   Print("[", EA_NAME, "] ", msg);
   g_lastLogMessage = msg;
   g_lastLogTime = now;
}

bool UpdateSymbolData()
{
   return SymbolInfoTick(_Symbol, g_tick);
}

void RefreshDailyState()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   datetime day_start = StructToTime(dt);

   if(g_currentDayStart != day_start)
   {
      g_currentDayStart = day_start;
      g_dailyLossBlocked = false;
      g_accountDailyLossBlocked = false;
      g_dailyProfitBlocked = false;
      g_basketDDBlocked = false;
      g_dailyResult = 0.0;
      g_recoveryEntriesTodayV121 = 0;
      g_momentumEntriesTodayV121 = 0;
      g_buyEntriesThisCandleV121 = 0;
      g_sellEntriesThisCandleV121 = 0;
      g_totalEntriesThisCandleV121 = 0;
      string equity_key = StateKey("DAILY_EQUITY_" + IntegerToString((int)day_start));
      if(GlobalVariableCheck(equity_key))
         g_dailyStartEquity = GlobalVariableGet(equity_key);
      else
      {
         g_dailyStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
         GlobalVariableSet(equity_key, g_dailyStartEquity);
      }
      LogMessage("novo dia operacional iniciado.");
   }
}

double GetTodayClosedProfit()
{
   double result = 0.0;
   if(g_currentDayStart <= 0)
      return result;

   if(!HistorySelect(g_currentDayStart, TimeCurrent()))
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
   int legacy_limit = MathMax(0, MaxOpenPositions);
   int slot_limit = MathMax(0, MaxSlotsExposicaoTotal);
   return MathMax(0, (int)MathMin((double)MathMin(legacy_limit, slot_limit), 8.0));
}

int LimitBuyPositions()
{
   if(UsarEntradasDirecionaisIndependentes)
      return MathMax(0, (int)MathMin((double)MaxSlotsPorDirecao, 6.0));

   return MathMax(0, (int)MathMin((double)MaxBuyPositions, 4.0));
}

int LimitSellPositions()
{
   if(UsarEntradasDirecionaisIndependentes)
      return MathMax(0, (int)MathMin((double)MaxSlotsPorDirecao, 6.0));

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
   return (UsedExposureSlotsV122() + additionalOrders <= LimitOpenPositions());
}

bool HasExposureRoomFor(int positions_to_add)
{
   int exposure = CountOpenPositions();
   if(PendingOrdersCountAsRisk)
      exposure += CountPendingOrders();

   return (exposure + positions_to_add <= LimitOpenPositions() && HasExposureRoomIncludingPendings(positions_to_add));
}

bool HasDirectionalSlotRoom(ENUM_POSITION_TYPE direction, int additional_slots, double additional_lots, string &reason)
{
   reason = "OK";

   if(!HasExposureRoomIncludingPendings(additional_slots))
   {
      reason = "sem_slot_total";
      LogMessage("[EXPOSURE_BUDGET_BLOCKED] motivo=sem_slot_total");
      return false;
   }

   int buy_slots = CountBuyExposureSlots();
   int sell_slots = CountSellExposureSlots();
   double buy_lots = GetBuyExposureLots();
   double sell_lots = GetSellExposureLots();

   if(direction == POSITION_TYPE_BUY)
   {
      buy_slots += additional_slots;
      buy_lots += additional_lots;
   }
   else
   {
      sell_slots += additional_slots;
      sell_lots += additional_lots;
   }

   if(buy_slots > LimitBuyPositions())
   {
      reason = "limite_buy";
      LogMessage("[EXPOSURE_BUDGET_BLOCKED] motivo=limite_buy");
      return false;
   }

   if(sell_slots > LimitSellPositions())
   {
      reason = "limite_sell";
      LogMessage("[EXPOSURE_BUDGET_BLOCKED] motivo=limite_sell");
      return false;
   }

   int max_imbalance = MathMax(0, MaxDesequilibrioDirecional);
   if(MathAbs(buy_slots - sell_slots) > max_imbalance)
   {
      reason = "desequilibrio_direcional";
      LogMessage("[NET_EXPOSURE_LIMIT] motivo=desequilibrio_direcional buy_slots=" +
                 IntegerToString(buy_slots) + " sell_slots=" + IntegerToString(sell_slots));
      return false;
   }

   double net_lots = MathAbs(buy_lots - sell_lots);
   if(MaxExposicaoLiquidaLotes > 0.0 && net_lots > MaxExposicaoLiquidaLotes + 0.0000001)
   {
      reason = "exposicao_liquida_lotes";
      LogMessage("[NET_EXPOSURE_LIMIT] motivo=exposicao_liquida_lotes net_lots=" + DoubleToString(net_lots, 2));
      return false;
   }

   return true;
}

bool BaseEntryFiltersOK()
{
   string reason = "";
   if(!EntryPreflightV122("base_entry", false, reason))
   {
      SetStatus("ENTRADA BLOQUEADA", reason);
      LogEntryBlockedV122("base_entry", reason);
      return false;
   }

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

   if(g_accountDailyLossBlocked)
   {
      SetStatus("LOSS DIARIO", "bloqueio por loss diario da conta");
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

bool UpdateATRData()
{
   if(!UsarDistanciaATR)
   {
      g_lastATRPoints = 0.0;
      g_lastATRRatio = 1.0;
      return true;
   }

   if(g_atrHandle == INVALID_HANDLE)
      return false;

   double atr_values[];
   ArraySetAsSeries(atr_values, true);
   int copied = CopyBuffer(g_atrHandle, 0, 1, 20, atr_values);
   if(copied < MathMax(3, MathMin(20, PeriodoATRRegime)))
      return false;

   if(atr_values[0] <= 0.0 || _Point <= 0.0)
      return false;

   g_lastATRPoints = atr_values[0] / _Point;

   double sum = 0.0;
   for(int i = 0; i < copied; i++)
      sum += atr_values[i];

   double avg = sum / (double)copied;
   g_lastATRRatio = (avg > 0.0 ? atr_values[0] / avg : 1.0);
   return true;
}

int DetectRegimeConfirmado()
{
   int persistence = MathMax(1, PersistenciaRegimeCandles);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   int copied = CopyRates(_Symbol, PERIOD_M15, 1, persistence + 3, rates);
   if(copied < persistence + 2)
      return 0;

   int up_count = 0;
   int down_count = 0;

   for(int i = 0; i < persistence; i++)
   {
      if(rates[i].close > rates[i + 1].high)
         up_count++;
      else if(rates[i].close < rates[i + 1].low)
         down_count++;
      else if(rates[i].close > rates[i].open)
         up_count++;
      else if(rates[i].close < rates[i].open)
         down_count++;
   }

   bool extreme = (g_lastATRRatio >= 1.80);

   if(up_count >= persistence)
      return (extreme ? 2 : 1);
   if(down_count >= persistence)
      return (extreme ? -2 : -1);

   return 0;
}

double GetAdaptiveDistancePoints(ENUM_POSITION_TYPE direction)
{
   double required = MathMax((double)DistanciaMinimaZonaPontos, RequiredAdditionalDistancePoints());

   if(UsarDistanciaATR && g_lastATRPoints > 0.0)
      required = MathMax(required, g_lastATRPoints * MathMax(0.10, MultiplicadorATRZona));

   int same_side_slots = (direction == POSITION_TYPE_BUY ? CountBuyExposureSlots() : CountSellExposureSlots());
   required *= (1.0 + MathMax(0.0, ProgressaoDistanciaPorEntrada) * (double)MathMax(0, same_side_slots - 1));

   int regime = DetectRegimeConfirmado();
   bool countertrend = ((direction == POSITION_TYPE_BUY && regime < 0) ||
                        (direction == POSITION_TYPE_SELL && regime > 0));
   if(countertrend)
      required *= MathMax(1.0, MultiplicadorContraTendencia);

   return MathMax(required, 1.0);
}

double GetDirectionalReferencePrice(ENUM_POSITION_TYPE direction)
{
   if(direction == POSITION_TYPE_BUY)
      return g_lastBuyLevelPrice;

   return g_lastSellLevelPrice;
}

bool IsZoneAlreadyRepresented(ENUM_POSITION_TYPE direction, double price, double zone_points, ulong exclude_order_ticket)
{
   if(!UsarCompressorZonas || price <= 0.0 || zone_points <= 0.0 || _Point <= 0.0)
      return false;

   double zone = zone_points * _Point;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!IsOurPositionByIndex(i))
         continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type != direction)
         continue;

      if(MathAbs(PositionGetDouble(POSITION_PRICE_OPEN) - price) < zone)
         return true;
   }

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!IsOurOrderByIndex(i))
         continue;

      ulong selected_ticket = (ulong)OrderGetInteger(ORDER_TICKET);
      if(exclude_order_ticket > 0 && selected_ticket == exclude_order_ticket)
         continue;

      ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(direction == POSITION_TYPE_BUY && !IsBuyPendingType(order_type))
         continue;
      if(direction == POSITION_TYPE_SELL && !IsSellPendingType(order_type))
         continue;

      if(MathAbs(OrderGetDouble(ORDER_PRICE_OPEN) - price) < zone)
         return true;
   }

   return false;
}

bool IsBasketHealthyForNewEntry(string &reason)
{
   double profit = GetBasketProfit();

   if(DDBloqueioAntesFechamentoUSD > 0.0 && profit <= -MathAbs(DDBloqueioAntesFechamentoUSD))
   {
      reason = "dd_bloqueio_ativo";
      LogMessage("[BASKET_HEALTH_BLOCKED] motivo=dd_bloqueio_ativo lucro=" + DoubleToString(profit, 2));
      return false;
   }

   if(g_basketDDBlocked)
   {
      reason = "dd_bloqueado";
      LogMessage("[RISK_LOCK_ACTIVE] motivo=dd_bloqueado");
      return false;
   }

   if(g_accountDailyLossBlocked || g_dailyLossBlocked)
   {
      reason = "loss_diario";
      LogMessage("[RISK_LOCK_ACTIVE] motivo=loss_diario");
      return false;
   }

   return true;
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
   if(!UpdateSymbolData())
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
   string reason = "";
   if(!EntryPreflightV122("pending", false, reason))
   {
      SetStatus("PENDENTE BLOQUEADA", reason);
      LogEntryBlockedV122("pending", reason);
      return false;
   }

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

   if(g_accountDailyLossBlocked)
   {
      SetStatus("LOSS DIARIO", "bloqueio por loss diario da conta");
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

bool ModifyPositionSL(ulong ticket, double new_sl, double current_tp, string reason)
{
   if(ticket == 0)
      return false;

   if(!PositionSelectByTicket(ticket))
      return false;

   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   if(!IsSLValid(type, new_sl))
      return false;

   if(!trade.PositionModify(ticket, NormalizePrice(new_sl), current_tp))
   {
      LogMessage("erro ao modificar SL: " + trade.ResultRetcodeDescription());
      return false;
   }

   if(ConfirmarSLNoServidor)
   {
      if(!PositionSelectByTicket(ticket))
      {
         LogMessage("[SL_SERVER_CONFIRM_FAIL] motivo=ticket_nao_selecionado");
         return false;
      }

      double server_sl = PositionGetDouble(POSITION_SL);
      double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double tolerance = MathMax(tick_size, _Point) * MathMax(0.0, ToleranciaConfirmacaoSLTicks);

      if(MathAbs(server_sl - NormalizePrice(new_sl)) > tolerance)
      {
         LogMessage("[SL_SERVER_CONFIRM_FAIL] esperado=" + DoubleToString(NormalizePrice(new_sl), _Digits) +
                    " servidor=" + DoubleToString(server_sl, _Digits));
         return false;
      }
   }

   LogMessage(reason + ".");
   return true;
}

void RebuildExposureStateFromServer()
{
   datetime last_buy_time = 0;
   datetime last_sell_time = 0;
   double last_buy_price = 0.0;
   double last_sell_price = 0.0;
   datetime last_any_time = 0;
   double last_any_price = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!IsOurPositionByIndex(i))
         continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      datetime position_time = (datetime)PositionGetInteger(POSITION_TIME);
      double position_price = PositionGetDouble(POSITION_PRICE_OPEN);

      if(position_time >= last_any_time)
      {
         last_any_time = position_time;
         last_any_price = position_price;
      }

      if(type == POSITION_TYPE_BUY && position_time >= last_buy_time)
      {
         last_buy_time = position_time;
         last_buy_price = position_price;
      }

      if(type == POSITION_TYPE_SELL && position_time >= last_sell_time)
      {
         last_sell_time = position_time;
         last_sell_price = position_price;
      }
   }

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!IsOurOrderByIndex(i))
         continue;

      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      datetime order_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      double order_price = OrderGetDouble(ORDER_PRICE_OPEN);

      if(order_time >= last_any_time)
      {
         last_any_time = order_time;
         last_any_price = order_price;
      }

      if(IsBuyPendingType(type) && order_time >= last_buy_time)
      {
         last_buy_time = order_time;
         last_buy_price = order_price;
      }

      if(IsSellPendingType(type) && order_time >= last_sell_time)
      {
         last_sell_time = order_time;
         last_sell_price = order_price;
      }
   }

   if(last_buy_price > 0.0)
   {
      g_lastBuyLevelPrice = last_buy_price;
      g_lastBuyLevelTime = last_buy_time;
   }

   if(last_sell_price > 0.0)
   {
      g_lastSellLevelPrice = last_sell_price;
      g_lastSellLevelTime = last_sell_time;
   }

   if(last_any_price > 0.0)
   {
      g_lastPairMidPrice = last_any_price;
      g_lastPairOpenTime = last_any_time;
   }

   if(CountOpenPositions() <= 0)
      ResetarPicoLucroCesta();
   else
   {
      double current_profit = GetBasketProfit();
      if(g_PicoLucroCestaUSD < current_profit)
         g_PicoLucroCestaUSD = current_profit;
      if(g_MAELucroCestaUSD > current_profit)
         g_MAELucroCestaUSD = current_profit;
      PersistBasketState();
   }
}

void PersistBasketState()
{
   GlobalVariableSet(StateKey("MFE"), g_PicoLucroCestaUSD);
   GlobalVariableSet(StateKey("MAE"), g_MAELucroCestaUSD);
   GlobalVariableSet(StateKey("LAST_BUY_PRICE"), g_lastBuyLevelPrice);
   GlobalVariableSet(StateKey("LAST_SELL_PRICE"), g_lastSellLevelPrice);
   GlobalVariableSet(StateKey("V121_LAST_BUY_TIME"), (double)g_lastBuyAdditionalTimeV121);
   GlobalVariableSet(StateKey("V121_LAST_SELL_TIME"), (double)g_lastSellAdditionalTimeV121);
   GlobalVariableSet(StateKey("V121_LAST_BUY_CANDLE"), (double)g_lastBuyAdditionalCandleV121);
   GlobalVariableSet(StateKey("V121_LAST_SELL_CANDLE"), (double)g_lastSellAdditionalCandleV121);
   GlobalVariableSet(StateKey("V121_BUDGET_CANDLE"), (double)g_budgetCandleV121);
   GlobalVariableSet(StateKey("V121_BUY_CANDLE_COUNT"), (double)g_buyEntriesThisCandleV121);
   GlobalVariableSet(StateKey("V121_SELL_CANDLE_COUNT"), (double)g_sellEntriesThisCandleV121);
   GlobalVariableSet(StateKey("V121_TOTAL_CANDLE_COUNT"), (double)g_totalEntriesThisCandleV121);
   GlobalVariableSet(StateKey("V122_BIAS"), (double)g_directionalBiasV122);
   GlobalVariableSet(StateKey("V122_BIAS_CONFIDENCE"), g_biasConfidenceV122);
   GlobalVariableSet(StateKey("V122_LAST_BUY_REBALANCE"), (double)g_lastBuyRebalanceTime);
   GlobalVariableSet(StateKey("V122_LAST_SELL_REBALANCE"), (double)g_lastSellRebalanceTime);
   if(g_flatSince > 0 && CountOpenPositions() == 0)
      GlobalVariableSet(StateKey("V122_FLAT_SINCE"), (double)g_flatSince);
}

void RestoreBasketState()
{
   if(GlobalVariableCheck(StateKey("MFE")))
      g_PicoLucroCestaUSD = GlobalVariableGet(StateKey("MFE"));
   if(GlobalVariableCheck(StateKey("MAE")))
      g_MAELucroCestaUSD = GlobalVariableGet(StateKey("MAE"));
   if(GlobalVariableCheck(StateKey("LAST_BUY_PRICE")))
      g_lastBuyLevelPrice = GlobalVariableGet(StateKey("LAST_BUY_PRICE"));
   if(GlobalVariableCheck(StateKey("LAST_SELL_PRICE")))
      g_lastSellLevelPrice = GlobalVariableGet(StateKey("LAST_SELL_PRICE"));
   if(GlobalVariableCheck(StateKey("V121_LAST_BUY_TIME")))
      g_lastBuyAdditionalTimeV121 = (datetime)GlobalVariableGet(StateKey("V121_LAST_BUY_TIME"));
   if(GlobalVariableCheck(StateKey("V121_LAST_SELL_TIME")))
      g_lastSellAdditionalTimeV121 = (datetime)GlobalVariableGet(StateKey("V121_LAST_SELL_TIME"));
   if(GlobalVariableCheck(StateKey("V121_LAST_BUY_CANDLE")))
      g_lastBuyAdditionalCandleV121 = (datetime)GlobalVariableGet(StateKey("V121_LAST_BUY_CANDLE"));
   if(GlobalVariableCheck(StateKey("V121_LAST_SELL_CANDLE")))
      g_lastSellAdditionalCandleV121 = (datetime)GlobalVariableGet(StateKey("V121_LAST_SELL_CANDLE"));
   if(GlobalVariableCheck(StateKey("V121_BUDGET_CANDLE")))
      g_budgetCandleV121 = (datetime)GlobalVariableGet(StateKey("V121_BUDGET_CANDLE"));
   if(GlobalVariableCheck(StateKey("V121_BUY_CANDLE_COUNT")))
      g_buyEntriesThisCandleV121 = (int)GlobalVariableGet(StateKey("V121_BUY_CANDLE_COUNT"));
   if(GlobalVariableCheck(StateKey("V121_SELL_CANDLE_COUNT")))
      g_sellEntriesThisCandleV121 = (int)GlobalVariableGet(StateKey("V121_SELL_CANDLE_COUNT"));
   if(GlobalVariableCheck(StateKey("V121_TOTAL_CANDLE_COUNT")))
      g_totalEntriesThisCandleV121 = (int)GlobalVariableGet(StateKey("V121_TOTAL_CANDLE_COUNT"));
   if(GlobalVariableCheck(StateKey("V122_BIAS")))
      g_directionalBiasV122 = (ENUM_DIRECTIONAL_BIAS_V122)(int)GlobalVariableGet(StateKey("V122_BIAS"));
   if(GlobalVariableCheck(StateKey("V122_BIAS_CONFIDENCE")))
      g_biasConfidenceV122 = GlobalVariableGet(StateKey("V122_BIAS_CONFIDENCE"));
   if(GlobalVariableCheck(StateKey("V122_LAST_BUY_REBALANCE")))
      g_lastBuyRebalanceTime = (datetime)GlobalVariableGet(StateKey("V122_LAST_BUY_REBALANCE"));
   if(GlobalVariableCheck(StateKey("V122_LAST_SELL_REBALANCE")))
      g_lastSellRebalanceTime = (datetime)GlobalVariableGet(StateKey("V122_LAST_SELL_REBALANCE"));
   if(GlobalVariableCheck(StateKey("V122_FLAT_SINCE")))
      g_flatSince = (datetime)GlobalVariableGet(StateKey("V122_FLAT_SINCE"));
}

string StateKey(string suffix)
{
   return "IAFG_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_" +
          _Symbol + "_" + IntegerToString(MagicNumber) + "_" + suffix;
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
   if(IsClosingScopeActiveV122())
      return ExitStateToTextV122(g_exitState);
   if(IsMarketHandoffActiveV1232())
      return "HANDOFF " + MarketHandoffStateTextV1232();
   if(HasPendingTradeConfirmationV122())
      return "RECONCILIANDO TRADE";
   if(g_waitingPairReopen && CountOpenPositions() == 0)
      return "AGUARDANDO REABERTURA";
   if(g_dailyLossBlocked)
      return "LOSS DIARIO";
   if(g_accountDailyLossBlocked)
      return "LOSS DIARIO";
   if(g_dailyProfitBlocked)
      return "META BATIDA";
   if(g_basketDDBlocked)
      return "DD BLOQUEADO";
   if(!IsSpreadOK())
      return "SPREAD ALTO";
   if(!IsTradingHourOK())
      return "HORARIO BLOQUEADO";
   if(IsNewsBlocked())
      return "NEWS BLOCK V2";
   if(!IsHedgingAccount())
      return "CONTA NETTING";
   if(UsedExposureSlotsV122() >= LimitOpenPositions())
      return "MAXIMO DE 8 OPERACOES";

   return g_status;
}

void SetStatus(string status, string log_reason="")
{
   g_status = status;
   if(log_reason != "")
   {
      datetime now = TimeCurrent();
      if(log_reason != g_lastStatusLogReasonV1232 ||
         g_lastStatusLogTimeV1232 <= 0 ||
         now - g_lastStatusLogTimeV1232 >= 10)
      {
         LogMessage(log_reason + ".");
         g_lastStatusLogReasonV1232 = log_reason;
         g_lastStatusLogTimeV1232 = now;
      }
   }
}
