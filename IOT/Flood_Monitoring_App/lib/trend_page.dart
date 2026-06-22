import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';

class TrendPage extends StatelessWidget {
  const TrendPage({super.key});

  int getTimestampValue(Map<dynamic, dynamic> record) {
    final timestamp = record["timestamp"];

    if (timestamp == null) return 0;

    if (timestamp is int) return timestamp;
    if (timestamp is double) return timestamp.toInt();

    if (timestamp is String) {
      final normalized = timestamp.replaceFirst(" ", "T");

      final parsedDate = DateTime.tryParse(normalized);
      if (parsedDate != null) {
        return parsedDate.millisecondsSinceEpoch;
      }

      final parsedInt = int.tryParse(timestamp);
      if (parsedInt != null) return parsedInt;
    }

    return 0;
  }

  String formatTime(dynamic timestamp) {
    if (timestamp == null) return "--";

    if (timestamp is String) {
      return timestamp;
    }

    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp)
          .toString()
          .substring(0, 19);
    }

    return timestamp.toString();
  }

  double getStatusScore(String status) {
    if (status == "SAFE") {
      return 0;
    } else if (status == "WARNING") {
      return 1;
    } else if (status == "DANGEROUS") {
      return 2;
    } else {
      return 0;
    }
  }

  String getStatusScoreLabel(double value) {
    if (value == 0) {
      return "Safe";
    } else if (value == 1) {
      return "Warning";
    } else if (value == 2) {
      return "Danger";
    } else {
      return "";
    }
  }

  String getStatusLabel(String status) {
    if (status == "DANGEROUS") {
      return "Dangerous";
    } else if (status == "WARNING") {
      return "Warning";
    } else if (status == "SAFE") {
      return "Safe";
    } else {
      return "Unknown";
    }
  }

  Color getStatusColor(String status) {
    if (status == "SAFE") {
      return Colors.green;
    } else if (status == "WARNING") {
      return Colors.orange;
    } else if (status == "DANGEROUS") {
      return Colors.red;
    } else {
      return Colors.grey;
    }
  }

  String getTrendInsight(List<double> values) {
    if (values.length < 2) {
      return "Not enough data to identify the trend yet.";
    }

    final first = values.first;
    final latest = values.last;

    if (latest == 2) {
      return "Latest condition is dangerous. Immediate action is required.";
    } else if (latest > first) {
      return "Flood risk is increasing. Please monitor the vehicle area carefully.";
    } else if (latest < first) {
      return "Flood risk is decreasing. The condition is improving.";
    } else {
      return "Flood risk is stable. No major change detected.";
    }
  }

  Color getCardColor(bool isDarkMode) {
    return isDarkMode ? const Color(0xFF1F2937) : Colors.white;
  }

  Color getBackgroundColor(bool isDarkMode) {
    return isDarkMode ? const Color(0xFF0F172A) : Colors.lightBlue.shade50;
  }

  Color getMainTextColor(bool isDarkMode) {
    return isDarkMode ? Colors.white : Colors.black87;
  }

  Color getSubTextColor(bool isDarkMode) {
    return isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700;
  }

  Color getGridColor(bool isDarkMode) {
    return isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300;
  }

  Widget buildLegendRow({
    required Color color,
    required String title,
    required String description,
    required bool isDarkMode,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 8,
            backgroundColor: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "$title: $description",
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: getMainTextColor(isDarkMode),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        Theme.of(context).brightness == Brightness.dark;

    final database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL:
          "https://smart-flood-system-c5823-default-rtdb.asia-southeast1.firebasedatabase.app",
    );

    final historyRef = database.ref("History");

    return Scaffold(
      backgroundColor: getBackgroundColor(isDarkMode),
      appBar: AppBar(
        elevation: 0,
        title: const Text("Flood Trend Analysis"),
        centerTitle: true,
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: historyRef.limitToLast(20).onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final data = snapshot.data!.snapshot.value;

          if (data == null) {
            return Center(
              child: Text(
                "No history data available yet.",
                style: TextStyle(
                  color: getSubTextColor(isDarkMode),
                  fontSize: 16,
                ),
              ),
            );
          }

          final historyMap =
              Map<dynamic, dynamic>.from(data as Map);

          var historyList = historyMap.entries.map((entry) {
            return Map<dynamic, dynamic>.from(entry.value);
          }).toList();

          historyList.sort((a, b) {
            return getTimestampValue(a)
                .compareTo(getTimestampValue(b));
          });

          // Show latest 20 records only
          if (historyList.length > 20) {
            historyList = historyList.sublist(historyList.length - 20);
          }

          final List<FlSpot> spots = [];
          final List<double> riskValues = [];
          final List<String> statusList = [];

          for (int i = 0; i < historyList.length; i++) {
            final record = historyList[i];

            final status =
                record["flood_status"]?.toString() ?? "--";

            final riskScore = getStatusScore(status);

            riskValues.add(riskScore);
            statusList.add(status);

            spots.add(
              FlSpot(
                i.toDouble(),
                riskScore,
              ),
            );
          }

          if (spots.isEmpty) {
            return Center(
              child: Text(
                "No trend data available.",
                style: TextStyle(
                  color: getSubTextColor(isDarkMode),
                  fontSize: 16,
                ),
              ),
            );
          }

          final latestRecord = historyList.last;

          final latestStatus =
              latestRecord["flood_status"]?.toString() ?? "--";

          final latestWaterLevel = double.tryParse(
                latestRecord["water_level"]?.toString() ?? "0",
              ) ??
              0;

          final latestTime =
              formatTime(latestRecord["timestamp"]);

          final riskColor = getStatusColor(latestStatus);
          final riskLabel = getStatusLabel(latestStatus);

          const double maxY = 2.2;

          final double maxX =
              spots.length == 1 ? 1 : (spots.length - 1).toDouble();

          final int labelInterval =
              spots.length <= 5 ? 1 : (spots.length / 4).ceil();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF1E293B)
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isDarkMode
                          ? Colors.lightBlueAccent.withValues(alpha: 0.25)
                          : Colors.blue.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.lightBlueAccent
                                  .withValues(alpha: 0.18)
                              : Colors.blue.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.show_chart,
                          color: isDarkMode
                              ? Colors.lightBlueAccent
                              : Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          "This chart shows flood risk level over time. "
                          "Safe is shown as 0, Warning as 1, and Dangerous as 2. "
                          "If the line goes up, the flood risk is increasing.",
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            color: getMainTextColor(isDarkMode),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Container(
                  decoration: BoxDecoration(
                    color: getCardColor(isDarkMode),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDarkMode ? 0.25 : 0.08,
                        ),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: riskColor,
                          child: const Icon(
                            Icons.water_drop,
                            color: Colors.white,
                            size: 35,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Latest Condition",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: getSubTextColor(isDarkMode),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "$riskLabel Risk",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: riskColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Sensor: ${latestWaterLevel.toStringAsFixed(0)} | Status: $latestStatus",
                                style: TextStyle(
                                  color: getMainTextColor(isDarkMode),
                                ),
                              ),
                              Text(
                                "Time: $latestTime",
                                style: TextStyle(
                                  color: getSubTextColor(isDarkMode),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: getCardColor(isDarkMode),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDarkMode ? 0.25 : 0.08,
                        ),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Trend Summary",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: getMainTextColor(isDarkMode),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          getTrendInsight(riskValues),
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            color: getMainTextColor(isDarkMode),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Container(
                  decoration: BoxDecoration(
                    color: getCardColor(isDarkMode),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDarkMode ? 0.25 : 0.08,
                        ),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Flood Risk Trend",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: getMainTextColor(isDarkMode),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Safe = 0, Warning = 1, Dangerous = 2",
                          style: TextStyle(
                            color: getSubTextColor(isDarkMode),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 320,
                          child: LineChart(
                            LineChartData(
                              minX: 0,
                              maxX: maxX,
                              minY: 0,
                              maxY: maxY,
                              clipData: const FlClipData.all(),
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: 1,
                                getDrawingHorizontalLine: (value) {
                                  return FlLine(
                                    color: getGridColor(isDarkMode),
                                    strokeWidth: 1,
                                  );
                                },
                              ),
                              borderData: FlBorderData(
                                show: true,
                                border: Border.all(
                                  color: getGridColor(isDarkMode),
                                ),
                              ),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(
                                  sideTitles:
                                      SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles:
                                      SideTitles(showTitles: false),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 70,
                                    interval: 1,
                                    getTitlesWidget: (value, meta) {
                                      if (value != 0 &&
                                          value != 1 &&
                                          value != 2) {
                                        return const SizedBox.shrink();
                                      }

                                      return Text(
                                        getStatusScoreLabel(value),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color:
                                              getSubTextColor(isDarkMode),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 35,
                                    interval: 1,
                                    getTitlesWidget: (value, meta) {
                                      final index = value.toInt();

                                      if (index < 0 ||
                                          index >= spots.length) {
                                        return const SizedBox.shrink();
                                      }

                                      if (index != 0 &&
                                          index != spots.length - 1 &&
                                          index % labelInterval != 0) {
                                        return const SizedBox.shrink();
                                      }

                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          top: 8,
                                        ),
                                        child: Text(
                                          "R${index + 1}",
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: getSubTextColor(
                                              isDarkMode,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: spots,
                                  isCurved: true,
                                  curveSmoothness: 0.25,
                                  barWidth: 3,
                                  color: Colors.lightBlueAccent,
                                  dotData: FlDotData(
                                    show: true,
                                    getDotPainter: (
                                      spot,
                                      percent,
                                      barData,
                                      index,
                                    ) {
                                      final status =
                                          statusList[index];

                                      return FlDotCirclePainter(
                                        radius: 4,
                                        color: getStatusColor(status),
                                        strokeWidth: 1.5,
                                        strokeColor: Colors.white,
                                      );
                                    },
                                  ),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: Colors.lightBlueAccent
                                        .withValues(alpha: 0.15),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            "R1, R2, R3 = history record number",
                            style: TextStyle(
                              color: getSubTextColor(isDarkMode),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: getCardColor(isDarkMode),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDarkMode ? 0.25 : 0.08,
                        ),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Risk Level Guide",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: getMainTextColor(isDarkMode),
                          ),
                        ),
                        const SizedBox(height: 12),
                        buildLegendRow(
                          color: Colors.green,
                          title: "Safe",
                          description: "Normal condition",
                          isDarkMode: isDarkMode,
                        ),
                        buildLegendRow(
                          color: Colors.orange,
                          title: "Warning",
                          description: "Flood risk detected",
                          isDarkMode: isDarkMode,
                        ),
                        buildLegendRow(
                          color: Colors.red,
                          title: "Dangerous",
                          description: "Immediate action required",
                          isDarkMode: isDarkMode,
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
}