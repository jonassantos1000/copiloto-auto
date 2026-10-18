import 'dart:async';
import 'telemetry.dart';

/// Barramento desacoplado: o OBD publica, a UI e o banco consomem.
class TelemetryBus {
  final _controller = StreamController<Telemetry>.broadcast();

  Stream<Telemetry> get stream => _controller.stream;

  void publish(Telemetry t) {
    if (!_controller.isClosed) _controller.add(t);
  }

  Future<void> dispose() => _controller.close();
}
