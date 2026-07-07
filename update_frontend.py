import re
import os

model_file = 'lib/features/train/data/models/train_stats_model.dart'
screen_file = 'lib/features/train/presentation/widgets/train_stats_screen.dart'

with open(model_file, 'r', encoding='utf-8') as f:
    model_content = f.read()

# Add models
new_models = """
class CommonRoute {
  final Map<String, dynamic>? polyline;
  final List<dynamic>? stops;

  CommonRoute({this.polyline, this.stops});

  factory CommonRoute.fromJson(Map<String, dynamic>? json) {
    if (json == null) return CommonRoute();
    return CommonRoute(
      polyline: json['polyline'],
      stops: json['stops'],
    );
  }
}

class StopAnalytics {
  final String stationName;
  final String stationId;
  final int totalLogs;
  final int cancellationRate;
  final int averageDelay;

  StopAnalytics({
    required this.stationName,
    required this.stationId,
    required this.totalLogs,
    required this.cancellationRate,
    required this.averageDelay,
  });

  factory StopAnalytics.fromJson(Map<String, dynamic> json) {
    return StopAnalytics(
      stationName: json['stationName'] ?? '',
      stationId: json['stationId'] ?? '',
      totalLogs: json['totalLogs'] ?? 0,
      cancellationRate: json['cancellationRate'] ?? 0,
      averageDelay: json['averageDelay'] ?? 0,
    );
  }
}
"""

if 'class CommonRoute' not in model_content:
    model_content += new_models

# Update TrainBehavioralReport
model_content = model_content.replace(
"""  final OperationalInsights insights;
  final List<DailyBreakdown> dailyBreakdown;""",
"""  final OperationalInsights insights;
  final List<DailyBreakdown> dailyBreakdown;
  final CommonRoute? commonRoute;
  final List<StopAnalytics> stopsAnalytics;"""
)

model_content = model_content.replace(
"""    required this.insights,
    required this.dailyBreakdown,""",
"""    required this.insights,
    required this.dailyBreakdown,
    this.commonRoute,
    this.stopsAnalytics = const [],"""
)

model_content = model_content.replace(
"""      dailyBreakdown: (json['dailyBreakdown'] as List?)
              ?.map((e) => DailyBreakdown.fromJson(e))
              .toList() ??
          [],
    );""",
"""      dailyBreakdown: (json['dailyBreakdown'] as List?)
              ?.map((e) => DailyBreakdown.fromJson(e))
              .toList() ??
          [],
      commonRoute: json['commonRoute'] != null ? CommonRoute.fromJson(json['commonRoute']) : null,
      stopsAnalytics: (json['stopsAnalytics'] as List?)?.map((e) => StopAnalytics.fromJson(e)).toList() ?? [],
    );"""
)

with open(model_file, 'w', encoding='utf-8') as f:
    f.write(model_content)

# Screen file
with open(screen_file, 'r', encoding='utf-8') as f:
    screen_content = f.read()

# Add a section for Stops Analytics
stops_ui = """
  Widget _buildStopsAnalyticsList(List<StopAnalytics> analytics) {
    if (analytics.isEmpty) {
      return Text(RuntimeLocalizations.t(context, 'train_stats_no_data'));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: analytics.length,
      itemBuilder: (context, index) {
        final stop = analytics[index];
        final isCritical = stop.cancellationRate > 20 || stop.averageDelay > 10;
        final color = stop.averageDelay > 5 ? Colors.orange : Colors.green;
        final cancelColor = stop.cancellationRate > 0 ? Colors.red : Colors.green;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: Theme.of(context).cardColor,
          child: ListTile(
            leading: Icon(
              isCritical ? Icons.warning_rounded : Icons.location_on_rounded,
              color: isCritical ? Colors.redAccent : Colors.blueAccent,
            ),
            title: Text(
              stop.stationName,
              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.timer, size: 14, color: color),
                    const SizedBox(width: 4),
                    Text(
                      "${stop.averageDelay} min ritardo medio",
                      style: TextStyle(fontSize: 12, color: color),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.cancel, size: 14, color: cancelColor),
                    const SizedBox(width: 4),
                    Text(
                      "${stop.cancellationRate}% cancellazioni (${stop.totalLogs} rilevamenti)",
                      style: TextStyle(fontSize: 12, color: cancelColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
"""

if '_buildStopsAnalyticsList' not in screen_content:
    screen_content = screen_content.replace('Widget _buildHeroScore(RevolutionaryMetrics metrics)', stops_ui + '\n  Widget _buildHeroScore(RevolutionaryMetrics metrics)')

# Insert into dashboard
dashboard = """
        _buildDailyBreakdownList(report.dailyBreakdown),
      ],
    );
"""
new_dashboard = """
        _buildDailyBreakdownList(report.dailyBreakdown),
        const SizedBox(height: 24),
        Text(
          "Analisi Fermate (Storico)",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
        const SizedBox(height: 12),
        _buildStopsAnalyticsList(report.stopsAnalytics),
      ],
    );
"""
screen_content = screen_content.replace(dashboard, new_dashboard)

with open(screen_file, 'w', encoding='utf-8') as f:
    f.write(screen_content)

print("Updated frontend")
