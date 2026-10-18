import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';

import 'obd_transport.dart';

/// Transporte Bluetooth clássico (SPP) usando o pacote flutter_classic_bluetooth.
/// Conecta ao adaptador pelo endereço MAC e expõe texto para o protocolo ELM327.
class SppTransport implements ObdTransport {
  final FlutterClassicBluetooth _bluetooth = FlutterClassicBluetooth();
  final StreamController<String> _incomingController =
      StreamController<String>.broadcast();

  BtcConnection? _connection;
  StreamSubscription<Uint8List>? _inputSubscription;

  @override
  bool get isConnected => _connection?.isConnected ?? false;

  @override
  Stream<String> get incoming => _incomingController.stream;

  /// Dispositivos já pareados no Android. O ELM327 precisa estar entre eles.
  Future<List<BtcDevice>> pairedDevices() => _bluetooth.getPairedDevices();

  /// Abre a conexão SPP com o endereço MAC do adaptador.
  Future<void> connect(String address) async {
    await disconnect();
    final connection = await _bluetooth.connect(
      address: address,
      timeout: const Duration(seconds: 15),
    );
    _connection = connection;
    _inputSubscription = connection.input.listen(
      (Uint8List data) =>
          _incomingController.add(utf8.decode(data, allowMalformed: true)),
      onDone: () => _connection = null,
    );
  }

  @override
  void write(String data) {
    _connection?.output.writeString(data);
  }

  Future<void> disconnect() async {
    await _inputSubscription?.cancel();
    _inputSubscription = null;
    await _connection?.close();
    _connection = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _incomingController.close();
  }
}
