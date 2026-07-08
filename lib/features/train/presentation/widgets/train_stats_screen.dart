import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:bc_transporter/core/services/runtime_localizations.dart';
import 'package:bc_transporter/features/train/data/models/train_stats_model.dart';

class TrainStatsScreen extends StatefulWidget {
  final String category;
  final String tripNumber;

  const TrainStatsScreen({
    Key? key,
    required this.category,
    required this.tripNumber,
  }) : super(key: key);

  @override
  State<TrainStatsScreen> createState() => _TrainStatsScreenState();
}

class _TrainStatsScreenState extends State<TrainStatsScreen> {
  late Future<TrainBehavioralReport> _reportFuture;

  @override
  void initState() {
    super.initState();
    _reportFuture = fetchTrainStats();
  }

  Future<TrainBehavioralReport> fetchTrainStats() async {
    final url = Uri.parse(
        'https://betacloud-transporter.is-cool.dev/api/stats/train/${widget.category}/${widget.tripNumber}');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['ok'] == true) {
        return TrainBehavioralReport.fromJson(json);
      } else {
        throw Exception(json['message'] ?? 'Errore nei dati');
      }
    } else if (response.statusCode == 404) {
      throw Exception('Nessun dato statistico trovato per questo treno.');
    } else {
      throw Exception('Errore di connessione al server.');
    }
  }

  // Funzione per aggiornare i dati
  void _refreshData() {
    setState(() {
      _reportFuture = fetchTrainStats();
    });
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.greenAccent;
    if (score >= 50) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('${widget.category.toUpperCase()} ${widget.tripNumber}', 
          style: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 1.2)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Aggiorna dati',
          ),
        ],
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient Orbs
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isDark ? Colors.blue.shade900 : Colors.blue.shade100).withValues(alpha: 0.5),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isDark ? Colors.purple.shade900 : Colors.purple.shade100).withValues(alpha: 0.5),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(),
              ),
            ),
          ),
          SafeArea(
            child: FutureBuilder<TrainBehavioralReport>(
              future: _reportFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  );
                } else if (snapshot.hasData) {
                  return _buildDashboard(snapshot.data!);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(TrainBehavioralReport report) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildHeroScore(report.metrics),
        const SizedBox(height: 16),
        
        // SEZIONE: Metriche Globali (Tasso cancellazioni e Variazione ritardo)
        _buildGlobalMetrics(report.metrics),
        const SizedBox(height: 16),
        
        // SEZIONE: Record Storico Negativo
        if (report.metrics.maxAbsoluteDelayMinutes > 0) ...[
          _buildHistoricalRecord(report.metrics),
          const SizedBox(height: 32),
        ],

        _sectionTitle(RuntimeLocalizations.t(context, 'train_stats_insights')),
        const SizedBox(height: 16),
        _buildInsightsGrid(report.insights),
        const SizedBox(height: 32),
        
        _sectionTitle(RuntimeLocalizations.t(context, 'train_stats_stops_analysis')),
        const SizedBox(height: 16),
        _buildStopsAnalyticsList(report.stopsAnalytics),
        const SizedBox(height: 32),
        
        _sectionTitle(RuntimeLocalizations.t(context, 'train_stats_timeline')),
        const SizedBox(height: 16),
        _buildDailyBreakdownList(report.dailyBreakdown),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.blueAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
      ],
    );
  }

  Widget _glassmorphicCard({required Widget child, EdgeInsetsGeometry? padding}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildHeroScore(RevolutionaryMetrics metrics) {
    final color = _getScoreColor(metrics.reliabilityScore);
    
    return _glassmorphicCard(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  RuntimeLocalizations.t(context, 'train_stats_reliability'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  metrics.behaviorTrend,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8), 
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    RuntimeLocalizations.t(context, 'train_stats_total_trips', params: {'count': metrics.totalTripsAnalyzed.toString()}),
                    style: const TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            height: 110,
            width: 110,
            child: Stack(
              fit: StackFit.expand,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: metrics.reliabilityScore / 100),
                  duration: const Duration(seconds: 2),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return CircularProgressIndicator(
                      value: value,
                      strokeWidth: 12,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      strokeCap: StrokeCap.round,
                    );
                  },
                ),
                Center(
                  child: Text(
                    '${metrics.reliabilityScore}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: color,
                      shadows: [
                        Shadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 10,
                        )
                      ]
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalMetrics(RevolutionaryMetrics metrics) {
    final bool tendsToRecover = metrics.averageNetDelayChangeMinutes < 0;
    final bool isStable = metrics.averageNetDelayChangeMinutes == 0;
    final Color netDelayColor = tendsToRecover ? Colors.greenAccent : (isStable ? Colors.blueAccent : Colors.redAccent);
    final String netDelayText = tendsToRecover 
        ? RuntimeLocalizations.t(context, 'train_stats_net_delay_recovers', params: {'min': metrics.averageNetDelayChangeMinutes.abs().toString()})
        : (isStable 
            ? RuntimeLocalizations.t(context, 'train_stats_net_delay_stable') 
            : RuntimeLocalizations.t(context, 'train_stats_net_delay_adds', params: {'min': metrics.averageNetDelayChangeMinutes.toString()}));

    final Color cancelColor = metrics.cancellationRatePercentage > 10 ? Colors.redAccent : (metrics.cancellationRatePercentage > 0 ? Colors.orangeAccent : Colors.greenAccent);

    return Row(
      children: [
        Expanded(
          child: _glassmorphicCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cancel_outlined, size: 16, color: cancelColor),
                    const SizedBox(width: 6),
                    Text(
                      RuntimeLocalizations.t(context, 'train_stats_cancellation_rate'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${metrics.cancellationRatePercentage}%',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cancelColor),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _glassmorphicCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(tendsToRecover ? Icons.trending_down : (isStable ? Icons.trending_flat : Icons.trending_up), size: 16, color: netDelayColor),
                    const SizedBox(width: 6),
                    Text(
                      RuntimeLocalizations.t(context, 'train_stats_net_delay'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  netDelayText,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: netDelayColor),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoricalRecord(RevolutionaryMetrics metrics) {
    return _glassmorphicCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.history_toggle_off, color: Colors.redAccent, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  RuntimeLocalizations.t(context, 'train_stats_historical_worst'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.redAccent),
                ),
                const SizedBox(height: 4),
                Text(
                  RuntimeLocalizations.t(context, 'train_stats_historical_delay', params: {
                    'min': metrics.maxAbsoluteDelayMinutes.toString(),
                    'station': metrics.criticalStation
                  }),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  RuntimeLocalizations.t(context, 'train_stats_historical_date', params: {'date': metrics.criticalDate}),
                  style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsGrid(OperationalInsights insights) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.1,
      children: [
        _insightCard(
            Icons.warning_amber_rounded, RuntimeLocalizations.t(context, 'train_stats_bottleneck'), insights.criticalBottleneckStation, Colors.orangeAccent),
        _insightCard(
            Icons.calendar_today_rounded, RuntimeLocalizations.t(context, 'train_stats_worst_day'), insights.worstDayOfWeek, Colors.blueAccent),
        _insightCard(
            Icons.trending_up_rounded, RuntimeLocalizations.t(context, 'train_stats_trend'), insights.recentPerformanceTrend, Colors.greenAccent),
        _insightCard(
            Icons.local_fire_department, RuntimeLocalizations.t(context, 'train_stats_streak'), insights.currentDelayStreakDays.toString(), Colors.redAccent),
      ],
    );
  }

  Widget _insightCard(IconData icon, String title, String value, Color accentColor) {
    return _glassmorphicCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStopsAnalyticsList(List<StopAnalytics> analytics) {
    if (analytics.isEmpty) {
      return Text(RuntimeLocalizations.t(context, 'train_stats_no_data'));
    }

    return _glassmorphicCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: analytics.length,
        itemBuilder: (context, index) {
          final stop = analytics[index];
          final isCritical = stop.cancellationRate > 20 || stop.averageDelay > 10;
          final color = stop.averageDelay > 5 ? Colors.orangeAccent : Colors.greenAccent;
          final cancelColor = stop.cancellationRate > 0 ? Colors.redAccent : Colors.greenAccent;
          
          final isFirst = index == 0;
          final isLast = index == analytics.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Timeline Graphics
                SizedBox(
                  width: 30,
                  child: Column(
                    children: [
                      Container(
                        width: 2,
                        height: 20,
                        color: isFirst ? Colors.transparent : Theme.of(context).dividerColor,
                      ),
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: isCritical ? Colors.redAccent : (stop.averageDelay > 5 ? Colors.orangeAccent : Colors.blueAccent),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isCritical ? Colors.redAccent : (stop.averageDelay > 5 ? Colors.orangeAccent : Colors.blueAccent)).withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            )
                          ]
                        ),
                      ),
                      Expanded(
                        child: Container(
                          width: 2,
                          color: isLast ? Colors.transparent : Theme.of(context).dividerColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Stop Details
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16), // Align with dot
                        Text(
                          stop.stationName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 16,
                            color: isCritical ? Colors.redAccent : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.timer, size: 14, color: color),
                            const SizedBox(width: 4),
                            Text(
                              RuntimeLocalizations.t(context, 'train_stats_avg_delay', params: {'delay': stop.averageDelay.toString()}),
                              style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.cancel, size: 14, color: cancelColor),
                            const SizedBox(width: 4),
                            Text(
                              RuntimeLocalizations.t(context, 'train_stats_cancellations', params: {'rate': stop.cancellationRate.toString(), 'logs': stop.totalLogs.toString()}),
                              style: TextStyle(fontSize: 13, color: cancelColor, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDailyBreakdownList(List<DailyBreakdown> breakdown) {
    if (breakdown.isEmpty) {
      return Text(RuntimeLocalizations.t(context, 'train_stats_no_data'));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: breakdown.length,
      itemBuilder: (context, index) {
        final day = breakdown[index];
        final isDelayed = day.status == 'DELAYED';
        final isCancelled = day.status == 'CANCELLED';

        Color statusColor = Colors.greenAccent;
        if (isDelayed) statusColor = Colors.orangeAccent;
        if (isCancelled) statusColor = Colors.redAccent;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _glassmorphicCard(
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCancelled ? Icons.cancel : Icons.train,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                title: Text(
                  day.date,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    '${RuntimeLocalizations.t(context, 'train_stats_max_delay')}: +${day.maxDelayReached} min',
                    style: TextStyle(color: isDelayed ? Colors.orangeAccent : Colors.grey, fontWeight: FontWeight.w500),
                  ),
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.black26 : Colors.white24,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: Colors.blueAccent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${RuntimeLocalizations.t(context, 'train_stats_behavior')}: ${day.behaviorDescription}',
                                style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Divider(height: 1),
                        ),
                        ...day.itinerary.map((station) => _buildStationRow(station)).toList(),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStationRow(StationItinerary station) {
    final arrDelay = station.arrival?.delay ?? 0;
    final depDelay = station.departure?.delay ?? 0;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  station.stationName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 4),
                if (station.arrival != null)
                  Text(
                    '${RuntimeLocalizations.t(context, 'train_stats_arr')}: +$arrDelay min (${RuntimeLocalizations.t(context, 'train_stats_platform')} ${station.arrival!.platform})',
                    style: TextStyle(
                      color: arrDelay > 5 ? Colors.redAccent : Theme.of(context).textTheme.bodySmall?.color,
                      fontSize: 13,
                    ),
                  ),
                if (station.departure != null)
                  Text(
                    '${RuntimeLocalizations.t(context, 'train_stats_dep')}: +$depDelay min (${RuntimeLocalizations.t(context, 'train_stats_platform')} ${station.departure!.platform})',
                    style: TextStyle(
                      color: depDelay > 5 ? Colors.redAccent : Theme.of(context).textTheme.bodySmall?.color,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }
}