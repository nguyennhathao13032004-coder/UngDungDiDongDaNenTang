import 'dart:convert';

class DailyHealthReport {
  final String date;
  final int heartRate;
  final String bloodPressure;
  final double weight;
  final int waterIntakeMl;
  final int targetWaterMl;
  final List<String> takenMedicines;
  final List<String> missedMedicines;

  DailyHealthReport({
    required this.date,
    required this.heartRate,
    required this.bloodPressure,
    required this.weight,
    required this.waterIntakeMl,
    required this.targetWaterMl,
    required this.takenMedicines,
    required this.missedMedicines,
  });

  factory DailyHealthReport.fromJson(Map<String, dynamic> json) {
    return DailyHealthReport(
      date: json['date'] ?? '',
      heartRate: json['heartRate'] ?? 0,
      bloodPressure: json['bloodPressure'] ?? 'Chưa đo',
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
      waterIntakeMl: json['waterIntakeMl'] ?? 0,
      targetWaterMl: json['targetWaterMl'] ?? 2000,
      takenMedicines: List<String>.from(json['takenMedicines'] ?? []),
      missedMedicines: List<String>.from(json['missedMedicines'] ?? []),
    );
  }
}