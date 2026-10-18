import 'package:flutter/material.dart';

/// Nota geral de saúde e nota de cada sistema.
class HealthReport {
  final int overall; // 0 a 100
  final List<SystemHealth> systems;

  const HealthReport({required this.overall, required this.systems});
}

/// Um sistema do carro com sua nota.
class SystemHealth {
  final String name;
  final int? score; // 0 a 100, ou null se ainda não há leitura
  final IconData icon;

  const SystemHealth({
    required this.name,
    required this.score,
    required this.icon,
  });

  HealthLevel? get level {
    final s = score;
    if (s == null) return null;
    if (s >= 80) return HealthLevel.good;
    if (s >= 50) return HealthLevel.warning;
    return HealthLevel.bad;
  }
}

enum HealthLevel { good, warning, bad }

/// Calcula a saúde do carro a partir dos dados disponíveis.
/// Regras simples, fáceis de ajustar:
/// - Temperatura do motor: ideal entre 80 e 100 °C. Fora disso, perde 4 pontos por grau.
/// - Erros da ECU: cada código ativo tira 20 pontos.
/// - Nota geral: média das duas notas.
HealthReport computeHealth({
  required double coolantTempC,
  required int errorCount,
}) {
  final motorScore = _tempScore(coolantTempC);
  final ecuScore = (100 - errorCount * 20).clamp(0, 100).toInt();
  final overall = ((motorScore + ecuScore) / 2).round();

  return HealthReport(
    overall: overall,
    systems: [
      SystemHealth(name: 'Motor', score: motorScore, icon: Icons.thermostat),
      SystemHealth(name: 'Eletrônica', score: ecuScore, icon: Icons.memory),
    ],
  );
}

int _tempScore(double tempC) {
  if (tempC <= 98) return 100;
  final distance = tempC - 98;
  return (100 - distance * 4).clamp(0, 100).round();
}

/// Cor da nota de saúde, com transição progressiva:
/// 0% vermelho, 40% laranja, 70% amarelo, 100% verde água.
Color healthColor(int score) {
  final s = score.clamp(0, 100);
  const points = [0, 40, 70, 100];
  const colors = [
    Color(0xFFEF4444),
    Color(0xFFF97316),
    Color(0xFFEAB308),
    Color(0xFF14A39A),
  ];

  for (var i = 0; i < points.length - 1; i++) {
    if (s <= points[i + 1]) {
      final t = (s - points[i]) / (points[i + 1] - points[i]);
      return Color.lerp(colors[i], colors[i + 1], t)!;
    }
  }
  return colors.last;
}

/// Monta o relatório de saúde a partir da telemetria e da contagem de erros.
/// Regras de negócio ficam aqui, não na tela:
/// - sem temperatura, não há nota geral;
/// - sem leitura de DTC (errorCount nulo), a eletrônica fica sem nota (null),
///   e a nota geral usa só o motor.
HealthReport? buildHealthReport({
  required double? coolantTempC,
  required int? errorCount,
}) {
  if (coolantTempC == null) return null;

  final motorScore = _tempScore(coolantTempC);
  final ecuScore = errorCount == null
      ? null
      : (100 - errorCount * 20).clamp(0, 100).toInt();
  final overall = ecuScore == null
      ? motorScore
      : ((motorScore + ecuScore) / 2).round();

  return HealthReport(
    overall: overall,
    systems: [
      SystemHealth(name: 'Motor', score: motorScore, icon: Icons.thermostat),
      SystemHealth(name: 'Eletrônica', score: ecuScore, icon: Icons.memory),
    ],
  );
}
