import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:bc_transporter/core/services/runtime_localizations.dart';

// Enum per gestire i periodi di tempo
enum TimeRange { today, week, month, year }

class TrainStatsScreen extends StatefulWidget {
  final Map<String, dynamic> rawStats;
  final String stationId;

  const TrainStatsScreen({super.key, required this.rawStats, required this.stationId});

  @override
  State<TrainStatsScreen> createState() => _TrainStatsScreenState();
}

class _TrainStatsScreenState extends State<TrainStatsScreen> {
  late Map<String, dynamic> _currentStats;
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();
  TimeRange _selectedRange = TimeRange.today; // Periodo di default

  @override
  void initState() {
    super.initState();
    _currentStats = widget.rawStats;
  }

  Future<void> _refreshStats() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final dateString = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
      
      final bool isToday = _selectedDate.year == DateTime.now().year && 
                           _selectedDate.month == DateTime.now().month && 
                           _selectedDate.day == DateTime.now().day;
                           
      String queryString = '';

      if (_selectedRange == TimeRange.today) {
        queryString = isToday ? '' : '?date=$dateString';
      } else {
        queryString = '?period=${_selectedRange.name}'; 
      }
      
      final url = Uri.parse('https://betacloud-transporter.is-cool.dev/api/stats/station/${widget.stationId}$queryString');
      
      final response = await http.get(url).timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _currentStats = json.decode(response.body);
        });
      } else {
        throw Exception("Errore del server: ${response.statusCode}");
      }
    } on TimeoutException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tempo scaduto: il server sta impiegando troppo tempo a rispondere.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore aggiornamento: ${e.toString().split(':').last.trim()}")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    if (_selectedRange != TimeRange.today) {
       setState(() => _selectedRange = TimeRange.today);
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Colors.blueAccent),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _refreshStats();
    }
  }

  // --- WIDGET PER IL RATING ---
  Widget _buildRatingStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star_rounded : Icons.star_border_rounded,
          color: Colors.amber,
          size: 24,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final general = _currentStats['general'] ?? _currentStats['stats'] ?? _currentStats;
    final board = general['boardAnalysis'] ?? {};
    final arrivals = board['arrivals'] ?? {};
    final departures = board['departures'] ?? {};
    final topWorstTrains = List.from(general['topWorstTrains'] ?? []);
    final topWorstRoutes = List.from(general['topWorstRoutes'] ?? []);
    final categoryDistribution = List.from(general['categoryDistribution'] ?? []);
    final distributionData = List.from(general['distribution'] ?? general['hourlyDistribution'] ?? []);
    final hourlyPredictions = List.from(general['hourlyPredictions'] ?? []);
    
    // Estrazione rating dal livello radice (Default a 0 se non presente)
    final double stationRating = (_currentStats['stationRating'] ?? 0).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0,
        title: Text(
          general['stationName'] ?? _currentStats['stationName'] ?? RuntimeLocalizations.t(context, 'stats_station_title'),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded, color: Colors.blueAccent),
            onPressed: _pickDate,
          ),
          _isLoading
              ? const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
              : IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _refreshStats),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // RATING E FILTRI
            Center(
              child: Column(
                children: [
                  _buildRatingStars(stationRating),
                  const SizedBox(height: 8),
                  Text("${stationRating.toStringAsFixed(1)} / 5.0", style: TextStyle(color: Colors.white.withOpacity(0.7))),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: SegmentedButton<TimeRange>(
                segments: [
                  ButtonSegment(value: TimeRange.today, label: Text(RuntimeLocalizations.t(context, 'stats_day'))),
                  ButtonSegment(value: TimeRange.week, label: Text(RuntimeLocalizations.t(context, 'stats_week'))),
                  ButtonSegment(value: TimeRange.month, label: Text(RuntimeLocalizations.t(context, 'stats_month'))),
                  ButtonSegment(value: TimeRange.year, label: Text(RuntimeLocalizations.t(context, 'stats_year'))),
                ],
                selected: <TimeRange>{_selectedRange},
                onSelectionChanged: (Set<TimeRange> newSelection) {
                  setState(() {
                    _selectedRange = newSelection.first;
                    if (_selectedRange == TimeRange.today) {
                      _selectedDate = DateTime.now();
                    }
                  });
                  _refreshStats();
                },
                style: SegmentedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.05),
                  foregroundColor: Colors.white,
                  selectedForegroundColor: Colors.blueAccent,
                  selectedBackgroundColor: Colors.blueAccent.withOpacity(0.2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_selectedRange == TimeRange.today)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  RuntimeLocalizations.t(context, 'stats_date_of', params: {'date': "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}"}),
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                ),
              ),

            Row(
              children: [
                Expanded(child: _buildKPI(RuntimeLocalizations.t(context, 'stats_punctuality'), "${general['onTimePercentage'] ?? 0}%", Colors.green)),
                const SizedBox(width: 12),
                Expanded(child: _buildKPI(RuntimeLocalizations.t(context, 'stats_avg_delay'), "${general['averageDelay'] ?? 0} min", Colors.orange)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildKPI(RuntimeLocalizations.t(context, 'stats_total_trains'), "${general['totalTrains'] ?? 0}", Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: _buildKPI(RuntimeLocalizations.t(context, 'stats_cancelled_trains'), "${general['cancelledTrains'] ?? 0}", Colors.red)),
              ],
            ),
            
            const SizedBox(height: 32),
            _buildSectionTitle(RuntimeLocalizations.t(context, 'stats_movements_analysis')),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildSubCard(title: "${RuntimeLocalizations.t(context, 'stats_arrivals')} (${arrivals['count'] ?? 0})", color: Colors.teal, children: [_buildMiniRow(RuntimeLocalizations.t(context, 'stats_avg_delay_short'), "${arrivals['avgDelay'] ?? 0}m"), _buildMiniRow(RuntimeLocalizations.t(context, 'stats_punctuality_short'), "${arrivals['onTimePercentage'] ?? 0}%")])),
                const SizedBox(width: 12),
                Expanded(child: _buildSubCard(title: "${RuntimeLocalizations.t(context, 'stats_departures')} (${departures['count'] ?? 0})", color: Colors.indigo, children: [_buildMiniRow(RuntimeLocalizations.t(context, 'stats_avg_delay_short'), "${departures['avgDelay'] ?? 0}m"), _buildMiniRow(RuntimeLocalizations.t(context, 'stats_punctuality_short'), "${departures['onTimePercentage'] ?? 0}%")])),
              ],
            ),

            if (hourlyPredictions.isNotEmpty && _selectedRange == TimeRange.today) ...[
              const SizedBox(height: 32),
              _buildSectionTitle("Previsioni Orarie (Storico)"),
              const SizedBox(height: 12),
              _buildPredictionsList(hourlyPredictions),
            ],

            const SizedBox(height: 32),
            _buildSectionTitle(_selectedRange == TimeRange.today ? RuntimeLocalizations.t(context, 'stats_hourly_trend') : RuntimeLocalizations.t(context, 'stats_historical_trend')),
            const SizedBox(height: 12),
            _buildChart(distributionData),

            const SizedBox(height: 32),
            _buildSectionTitle(RuntimeLocalizations.t(context, 'stats_category_perf')),
            const SizedBox(height: 12),
            if (categoryDistribution.isEmpty) _buildEmptyNotice() else ...categoryDistribution.map((cat) => _buildCategoryTile(cat)),

            const SizedBox(height: 32),
            _buildSectionTitle(RuntimeLocalizations.t(context, 'stats_worst_trains')),
            const SizedBox(height: 12),
            if (topWorstTrains.isEmpty) _buildEmptyNotice() else ...topWorstTrains.map((train) => _buildWorstTrainTile(train)),

            const SizedBox(height: 32),
            _buildSectionTitle(RuntimeLocalizations.t(context, 'stats_worst_routes')),
            const SizedBox(height: 12),
            if (topWorstRoutes.isEmpty) _buildEmptyNotice() else ...topWorstRoutes.map((route) => _buildWorstRouteTile(route)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold));

  Widget _buildEmptyNotice() => Text(RuntimeLocalizations.t(context, 'stats_no_data'), style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14));

  Widget _buildKPI(String title, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.25), width: 1)),
      child: Column(children: [Text(val, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(title, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13), textAlign: TextAlign.center)]),
    );
  }

  Widget _buildSubCard({required String title, required Color color, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 8), Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))]), const Divider(color: Colors.white10, height: 16), ...children]),
    );
  }

  Widget _buildMiniRow(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)), Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12))]));
  }

  Widget _buildPredictionsList(List<dynamic> predictions) {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: predictions.length,
        itemBuilder: (context, index) {
          final pred = predictions[index];
          final int hour = pred['hour'] ?? 0;
          final int risk = pred['delayProbability'] ?? 0;
          final String crowd = pred['crowdLevel'] ?? RuntimeLocalizations.t(context, 'low');

          Color riskColor = risk < 20 ? Colors.green : (risk < 50 ? Colors.orange : Colors.redAccent);
          IconData crowdIcon = crowd == RuntimeLocalizations.t(context, 'high') ? Icons.groups : (crowd == RuntimeLocalizations.t(context, 'medium') ? Icons.group : Icons.person);
          Color crowdColor = crowd == RuntimeLocalizations.t(context, 'high') ? Colors.redAccent : (crowd == RuntimeLocalizations.t(context, 'medium') ? Colors.orangeAccent : Colors.green);

          return Container(
            width: 120,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("$hour:00", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(crowdIcon, color: crowdColor, size: 16),
                    const SizedBox(width: 4),
                    Text(crowd, style: TextStyle(color: crowdColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                Text("Rischio Ritardo", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                const SizedBox(height: 4),
                Text("$risk%", style: TextStyle(color: riskColor, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        },
      ),
    );
  }
Widget _buildChart(List<dynamic> data) {
    if (data.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(16)),
        child: Text(RuntimeLocalizations.t(context, 'stats_no_chart_data'), style: TextStyle(color: Colors.white.withOpacity(0.4))),
      );
    }

    int daysInCurrentMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
    DateTime now = DateTime.now();

    bool isCurrentPeriod = _selectedDate.year == now.year && 
                           _selectedDate.month == now.month && 
                           _selectedDate.day == now.day;

    double maxXValue = 23; 

    if (_selectedRange == TimeRange.today) {
      maxXValue = isCurrentPeriod ? now.hour.toDouble() : 23;
    } else if (_selectedRange == TimeRange.week) {
      maxXValue = isCurrentPeriod ? (now.weekday - 1).toDouble() : 6;
    } else if (_selectedRange == TimeRange.month) {
      maxXValue = isCurrentPeriod ? (now.day - 1).toDouble() : (daysInCurrentMonth - 1).toDouble(); 
    } else if (_selectedRange == TimeRange.year) {
      maxXValue = isCurrentPeriod ? (now.month - 1).toDouble() : 11;
    }

    if (maxXValue <= 0) maxXValue = 1;

    final List<FlSpot> spots = [];
    double maxY = 0;

    DateTime? parseCustomDate(dynamic val) {
      if (val == null) return null;
      String s = val.toString();
      try { return DateTime.parse(s); } catch (_) {}
      try {
        final p = s.split(RegExp(r'[/|-]'));
        if (p.length >= 3) {
          return p[0].length == 4 
              ? DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]))
              : DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
        }
      } catch (_) {}
      return null;
    }

    for (int i = 0; i < data.length; i++) {
      final e = data[i];
      double xValue = i.toDouble(); 
      
      DateTime? parsedDate = parseCustomDate(e['date'] ?? e['timestamp'] ?? e['time']);

      if (_selectedRange == TimeRange.today) {
        if (e['hour'] != null) xValue = (e['hour'] as num).toDouble();
        else if (parsedDate != null) xValue = parsedDate.hour.toDouble();
        else if (data.length == 1) xValue = _selectedDate.hour.toDouble();
      } 
      else if (_selectedRange == TimeRange.week) {
        if (e['weekday'] != null) xValue = (e['weekday'] as num).toDouble() - 1; 
        else if (parsedDate != null) xValue = (parsedDate.weekday - 1).toDouble();
        else if (data.length == 1) xValue = (_selectedDate.weekday - 1).toDouble();
      } 
      else if (_selectedRange == TimeRange.month) {
        if (e['day'] != null) xValue = (e['day'] as num).toDouble() - 1; 
        else if (parsedDate != null) xValue = (parsedDate.day - 1).toDouble();
        else if (data.length == 1) xValue = (_selectedDate.day - 1).toDouble();
      } 
      else if (_selectedRange == TimeRange.year) {
        if (e['month'] != null) xValue = (e['month'] as num).toDouble() - 1; 
        else if (parsedDate != null) xValue = (parsedDate.month - 1).toDouble();
        else if (data.length == 1) xValue = (_selectedDate.month - 1).toDouble();
      }

      if (isCurrentPeriod && xValue > maxXValue) continue;
      if (xValue > maxXValue || xValue < 0) continue; 

      final double delay = (e['averageDelay'] as num).toDouble();
      spots.add(FlSpot(xValue, delay));
      
      if (delay > maxY) maxY = delay;
    }

    if (spots.isEmpty) {
       spots.add(const FlSpot(0, 0));
       maxXValue = 1;
    }

    spots.sort((a, b) => a.x.compareTo(b.x));

    if (maxY < 10) maxY = 10;
    maxY = ((maxY / 5).ceil() * 5).toDouble();

    double bottomInterval = _getBottomInterval(maxXValue);
    double leftInterval = maxY > 20 ? (maxY / 4).roundToDouble() : 5;
    if (leftInterval <= 0) leftInterval = 5;

    return Container(
      height: 220,
      padding: const EdgeInsets.only(top: 20, right: 24, left: 4, bottom: 8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(16)),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxXValue,
          minY: 0,
          maxY: maxY,
          // ---- CONFIGURAZIONE TOUCH / INTERAZIONE ----
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => Colors.blueGrey.withOpacity(0.9),
              tooltipBorder: const BorderSide(color: Colors.white24, width: 1),
              tooltipRoundedRadius: 8,
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((barSpot) {
                  final index = barSpot.x.toInt();
                  String titleLabel = "";

                  // Costruiamo il titolo del tooltip in base al range temporale
                  switch (_selectedRange) {
                    case TimeRange.today:
                      titleLabel = "$index:00";
                      break;
                    case TimeRange.week:
                      const giorni = ["Lunedì", "Martedì", "Mercoledì", "Giovedì", "Venerdì", "Sabato", "Domenica"];
                      titleLabel = (index >= 0 && index < giorni.length) ? giorni[index] : "";
                      break;
                    case TimeRange.month:
                      titleLabel = "Giorno ${index + 1}";
                      break;
                    case TimeRange.year:
                      const mesi = ["Gennaio", "Febbraio", "Marzo", "Aprile", "Maggio", "Giugno", "Luglio", "Agosto", "Settembre", "Ottobre", "Novembre", "Dicembre"];
                      titleLabel = (index >= 0 && index < mesi.length) ? mesi[index] : "";
                      break;
                  }

                  return LineTooltipItem(
                    "$titleLabel\n",
                    const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.normal),
                    children: [
                      TextSpan(
                        text: "+${barSpot.y.toStringAsFixed(1)} min",
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
            handleBuiltInTouches: true, // Abilita il comportamento predefinito di fl_chart
          ),
          // --------------------------------------------
          lineBarsData: [
            LineChartBarData(
              spots: spots, 
              isCurved: true, 
              color: Colors.blueAccent, 
              barWidth: 3, 
              dotData: FlDotData(show: _selectedRange != TimeRange.today),
              belowBarData: BarAreaData(show: true, color: Colors.blueAccent.withOpacity(0.15))
            )
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true, 
                reservedSize: 40, 
                interval: leftInterval, 
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(right: 6.0), 
                  child: Text("${value.toInt()}m", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right)
                )
              )
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true, 
                interval: bottomInterval, 
                reservedSize: 28, 
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  String label = "";

                  switch (_selectedRange) {
                    case TimeRange.today:
                      label = "$index:00";
                      break;
                    case TimeRange.week:
                      const giorni = ["Lun", "Mar", "Mer", "Gio", "Ven", "Sab", "Dom"];
                      label = (index >= 0 && index < giorni.length) ? giorni[index] : "";
                      break;
                    case TimeRange.month:
                      label = "G${index + 1}";
                      break;
                    case TimeRange.year:
                      const mesi = ["Gen", "Feb", "Mar", "Apr", "Mag", "Giu", "Lug", "Ago", "Set", "Ott", "Nov", "Dic"];
                      label = (index >= 0 && index < mesi.length) ? mesi[index] : "";
                      break;
                  }

                  if (value % meta.appliedInterval != 0 || label.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 6,
                    child: Text(
                      label, 
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5), 
                        fontSize: _selectedRange == TimeRange.year ? 9 : 10, 
                        fontWeight: FontWeight.bold
                      )
                    ),
                  );
                }
              )
            ),
          ),
          gridData: FlGridData(
            show: true, 
            drawVerticalLine: true, 
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.white.withOpacity(0.06), strokeWidth: 1), 
            getDrawingVerticalLine: (value) => FlLine(color: Colors.white.withOpacity(0.06), strokeWidth: 1)
          ),
          borderData: FlBorderData(
            show: true, 
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.2), width: 1.5), left: BorderSide(color: Colors.white.withOpacity(0.2), width: 1.5), right: BorderSide.none, top: BorderSide.none)
          ),
        ),
      ),
    );
  }
  
  double _getBottomInterval(double maxVal) {
    switch (_selectedRange) {
      case TimeRange.today:
        return maxVal > 12 ? 4 : 2;
      case TimeRange.week:
        return 1; 
      case TimeRange.month:
        return 5;
      case TimeRange.year:
        return 1; 
    }
  }

  Widget _buildCategoryTile(dynamic cat) {
    final onTime = cat['onTimePercentage'] ?? 0;
    Color progressColor = onTime < 50 ? Colors.red : (onTime < 75 ? Colors.orange : Colors.green);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("${cat['category']} (${cat['totalTrains']} treni)", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text(RuntimeLocalizations.t(context, 'stats_avg_delay_val', params: {'val': cat['averageDelay'].toString()}), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13))]), const SizedBox(height: 8), Row(children: [Expanded(child: LinearProgressIndicator(value: onTime / 100, backgroundColor: Colors.white10, color: progressColor)), const SizedBox(width: 12), Text(RuntimeLocalizations.t(context, 'stats_punctuality_val', params: {'val': onTime.toString()}), style: TextStyle(color: progressColor, fontSize: 12, fontWeight: FontWeight.bold))])]),
    );
  }

  Widget _buildWorstTrainTile(dynamic train) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withOpacity(0.1))),
      child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), title: Text(train['line'] ?? RuntimeLocalizations.t(context, 'stats_unknown_train'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), subtitle: Text(RuntimeLocalizations.t(context, 'stats_detected_times', params: {'count': train['samples'].toString()}), style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)), trailing: Text("+${train['averageDelay']} min", style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold))),
    );
  }

  Widget _buildWorstRouteTile(dynamic route) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withOpacity(0.1))),
      child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), title: Text(route['destination'] ?? RuntimeLocalizations.t(context, 'stats_destination'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)), subtitle: Text(RuntimeLocalizations.t(context, 'stats_analyzed_trips', params: {'count': route['totalTrips'].toString()}), style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)), trailing: Text("+${route['averageDelay']} min", style: const TextStyle(color: Colors.orange, fontSize: 15, fontWeight: FontWeight.bold))),
    );
  }
}