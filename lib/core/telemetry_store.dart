import 'dart:async';

import 'package:flutter/foundation.dart';

import 'telemetry.dart';
import 'telemetry_bus.dart';

/// Sem nova leitura por este tempo, a conexão é considerada perdida.
const liveTimeout = Duration(seconds: 6);

const _gasolineDensityGPerL = 745.0;
const _airFuelRatio = 14.7;

/// Litros de gasolina consumidos por hora, a partir do MAF em g/s.
double fuelLitersPerHour(double mafGs) {
  final fuelGPerH = mafGs * 3600 / _airFuelRatio;
  return fuelGPerH / _gasolineDensityGPerL;
}

/// Consumo instantâneo em km/l. Devolve null se o carro estiver parado ou sem MAF.
double? instantKmPerLiter(double? speedKmh, double? mafGs) {
  if (speedKmh == null || mafGs == null) return null;
  if (speedKmh <= 0 || mafGs <= 0) return null;
  return speedKmh / fuelLitersPerHour(mafGs);
}

/// Ponte entre o TelemetryBus e a tela.
/// Guarda a última leitura, calcula o consumo (instantâneo e médio)
/// e marca se a conexão continua ativa.
class TelemetryStore {
  final TelemetryBus bus;

  final ValueNotifier<Telemetry?> latest = ValueNotifier(null);
  final ValueNotifier<bool> live = ValueNotifier(false);
  final ValueNotifier<double?> instantKmL = ValueNotifier(null);
  final ValueNotifier<double?> avgKmL = ValueNotifier(null);

  /// Quantidade de DTCs lidos da ECU. Null = ainda não lido.
  final ValueNotifier<int?> dtcCount = ValueNotifier(null);

  late final StreamSubscription<Telemetry> _subscription;
  late final Timer _watchdog;
  Telemetry? _previous;
  DateTime? _lastAt;
  double _totalKm = 0;
  double _totalLiters = 0;

  TelemetryStore({required this.bus}) {
    _subscription = bus.stream.listen(_onTelemetry);
    _watchdog = Timer.periodic(const Duration(seconds: 1), (_) => _checkLive());
  }

  void setDtcCount(int count) => dtcCount.value = count;

  void _onTelemetry(Telemetry t) {
    final previous = _previous;
    final maf = t.mafGs;

    // Integra o consumo só entre leituras próximas (até ~10 s).
    if (previous != null && maf != null) {
      final hours =
          t.timestamp.difference(previous.timestamp).inMilliseconds / 3600000;
      if (hours > 0 && hours <= 10 / 3600) {
        _totalKm += (t.speedKmh ?? 0) * hours;
        _totalLiters += fuelLitersPerHour(maf) * hours;
      }
    }

    _previous = t;
    _lastAt = DateTime.now();
    live.value = true;
    latest.value = t;
    instantKmL.value = instantKmPerLiter(t.speedKmh, t.mafGs);
    avgKmL.value = _totalLiters > 0 ? _totalKm / _totalLiters : null;
  }

  void _checkLive() {
    final last = _lastAt;
    if (last != null && DateTime.now().difference(last) > liveTimeout) {
      live.value = false;
    }
  }

  void dispose() {
    _subscription.cancel();
    _watchdog.cancel();
  }
}
