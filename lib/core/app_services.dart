import 'package:flutter/foundation.dart';

import '../obd/protocol/elm327.dart';
import '../obd/transport/spp_transport.dart';
import 'telemetry_bus.dart';
import 'telemetry_simulator.dart';
import 'telemetry_store.dart';

/// Instâncias únicas usadas pelo app inteiro.
/// A camada OBD publica no telemetryBus; a tela lê do telemetryStore.
final telemetryBus = TelemetryBus();
final telemetryStore = TelemetryStore(bus: telemetryBus);
final telemetrySimulator = TelemetrySimulator(telemetryBus);

/// Conexão Bluetooth com o adaptador e protocolo ELM327 sobre ela.
final obdTransport = SppTransport();
final elm327 = Elm327(obdTransport)..start();

/// Endereço do adaptador conectado, ou null. Telas leem daqui para
/// mostrar o mesmo estado em qualquer lugar.
final obdConnection = ValueNotifier<String?>(null);
