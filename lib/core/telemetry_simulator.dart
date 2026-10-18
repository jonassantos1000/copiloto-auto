import 'dart:async';
import 'dart:math' as math;

import 'telemetry.dart';
import 'telemetry_bus.dart';

/// Gera leituras falsas (carro entre 20 e 70 km/h) para ver o dashboard sem o carro.
/// Será substituído pelo PidPoller quando a conexão real estiver ligada à UI.
class TelemetrySimulator {
  final TelemetryBus bus;
  Timer? _timer;
  int _tick = 0;

  TelemetrySimulator(this.bus);

  bool get running => _timer != null;

  void start() {
    if (running) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _emit());
    _emit();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _emit() {
    _tick++;
    final speed = 45 + 25 * math.sin(_tick / 6);
    final coolant = 100 + 2 * math.sin(_tick / 10);
    bus.publish(Telemetry(
      timestamp: DateTime.now(),
      coolantTempC: coolant,
      speedKmh: speed,
      rpm: 800 + speed * 40,
      mafGs: 2 + speed / 15,
      fuelLevelPct: 62,
    ));
  }
}
