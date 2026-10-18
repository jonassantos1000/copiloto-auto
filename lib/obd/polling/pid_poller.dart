import 'dart:async';

import '../../core/telemetry.dart';
import '../../core/telemetry_bus.dart';
import '../decoders/pid_decoders.dart';
import '../protocol/elm327.dart';

/// Lê os sensores em ciclos e publica cada leitura no TelemetryBus.
/// A UI nunca chama o adaptador: ela só escuta o bus.
class PidPoller {
  final Elm327 elm;
  final TelemetryBus bus;
  final Duration interval;

  Timer? _timer;
  bool _running = false;

  PidPoller({
    required this.elm,
    required this.bus,
    this.interval = const Duration(seconds: 2),
  });

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _tick());
    _tick();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    if (_running) return; // evita sobrepor ciclos se o adaptador estiver lento
    _running = true;
    try {
      final coolant = decodeCoolantTemp(await elm.query('0105'));
      final rpm = decodeRpm(await elm.query('010C'));
      final speed = decodeSpeed(await elm.query('010D'));
      final maf = decodeMaf(await elm.query('0110'));
      final fuel = decodeFuelLevel(await elm.query('012F'));

      bus.publish(Telemetry(
        timestamp: DateTime.now(),
        coolantTempC: coolant,
        rpm: rpm,
        speedKmh: speed,
        mafGs: maf,
        fuelLevelPct: fuel,
      ));
    } catch (_) {
      // Falha neste ciclo (sem resposta ou dado inválido): tenta de novo no próximo.
    } finally {
      _running = false;
    }
  }
}
