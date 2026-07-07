import 'dart:convert';
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
    // Sostituisci con l'URL reale del tuo backend
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

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('${widget.category.toUpperCase()} ${widget.tripNumber}'),
        centerTitle: true,
        elevation: 0,
      ),
      body: FutureBuilder<TrainBehavioralReport>(
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
    );
  }

  Widget _buildDashboard(TrainBehavioralReport report) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildHeroScore(report.metrics),
        const SizedBox(height: 24),
        Text(
          RuntimeLocalizations.t(context, 'train_stats_insights'),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildInsightsGrid(report.insights),
        const SizedBox(height: 24),
        Text(
          RuntimeLocalizations.t(context, 'train_stats_timeline'),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildDailyBreakdownList(report.dailyBreakdown),
      ],
    );
  }

  Widget _buildHeroScore(RevolutionaryMetrics metrics) {
    final color = _getScoreColor(metrics.reliabilityScore);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              SizedBox(
                height: 100,
                width: 100,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: metrics.reliabilityScore / 100,
                      strokeWidth: 10,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest ?? Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                    Center(
                      child: Text(
                        '${metrics.reliabilityScore}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        RuntimeLocalizations.t(context, 'train_stats_reliability'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        metrics.behaviorTrend,
                        style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsGrid(OperationalInsights insights) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.3,
      children: [
        _insightCard(
            Icons.warning_amber_rounded, RuntimeLocalizations.t(context, 'train_stats_bottleneck'), insights.criticalBottleneckStation),
        _insightCard(
            Icons.calendar_today_rounded, RuntimeLocalizations.t(context, 'train_stats_worst_day'), insights.worstDayOfWeek),
        _insightCard(
            Icons.trending_up_rounded, RuntimeLocalizations.t(context, 'train_stats_trend'), insights.recentPerformanceTrend),
        _insightCard(
            Icons.local_fire_department, RuntimeLocalizations.t(context, 'train_stats_streak'), insights.currentDelayStreakDays.toString()),
      ],
    );
  }

  Widget _insightCard(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.blueAccent, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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

        Color statusColor = Colors.green;
        if (isDelayed) statusColor = Colors.orange;
        if (isCancelled) statusColor = Colors.red;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.2),
              child: Icon(
                isCancelled ? Icons.cancel : Icons.train,
                color: statusColor,
              ),
            ),
            title: Text(
              day.date,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${RuntimeLocalizations.t(context, 'train_stats_max_delay')}: +${day.maxDelayReached} min',
              style: TextStyle(color: isDelayed ? Colors.orange[800] : Colors.grey),
            ),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.surfaceContainerHighest ?? Colors.grey[50],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${RuntimeLocalizations.t(context, 'train_stats_behavior')}: ${day.behaviorDescription}',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                    const Divider(height: 24),
                    ...day.itinerary.map((station) => _buildStationRow(station)).toList(),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildStationRow(StationItinerary station) {
    final arrDelay = station.arrival?.delay ?? 0;
    final depDelay = station.departure?.delay ?? 0;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Indicatore pallino
          Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Dettagli stazione
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  station.stationName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (station.arrival != null)
                  Text(
                    '${RuntimeLocalizations.t(context, 'train_stats_arr')}: +$arrDelay min (${RuntimeLocalizations.t(context, 'train_stats_platform')} ${station.arrival!.platform})',
                    style: TextStyle(
                      color: arrDelay > 5 ? Colors.red : Colors.grey[700],
                      fontSize: 12,
                    ),
                  ),
                if (station.departure != null)
                  Text(
                    '${RuntimeLocalizations.t(context, 'train_stats_dep')}: +$depDelay min (${RuntimeLocalizations.t(context, 'train_stats_platform')} ${station.departure!.platform})',
                    style: TextStyle(
                      color: depDelay > 5 ? Colors.red : Colors.grey[700],
                      fontSize: 12,
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