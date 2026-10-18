import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:copilotoauto/obd/decoders/pid_decoders.dart';
import 'package:copilotoauto/obd/protocol/elm327.dart';
import 'package:copilotoauto/obd/transport/obd_transport.dart';

/// Transporte falso: responde sempre com o texto de [reply], sem precisar de carro.
class FakeTransport implements ObdTransport {
  final _controller = StreamController<String>.broadcast();
  final List<String> sent = [];
  String reply = '';

  @override
  bool get isConnected => true;

  @override
  Stream<String> get incoming => _controller.stream;

  @override
  void write(String data) {
    sent.add(data);
    _controller.add('$reply\r>');
  }
}

void main() {
  group('decodificadores', () {
    test('temperatura do motor: A - 40', () {
      expect(decodeCoolantTemp([0x7D]), 85.0);
    });

    test('rpm: (256A + B) / 4', () {
      expect(decodeRpm([0x1A, 0xF8]), 1726.0);
    });

    test('velocidade: A', () {
      expect(decodeSpeed([0x3E]), 62.0);
    });

    test('combustível: A * 100 / 255', () {
      expect(decodeFuelLevel([0xFF]), 100.0);
    });

    test('bytes insuficientes ou ausentes devolvem null', () {
      expect(decodeRpm([0x1A]), isNull);
      expect(decodeCoolantTemp(null), isNull);
    });

    test('DTC: 01 33 vira P0133', () {
      expect(decodeDtcs([0x01, 0x33, 0x00, 0x00]), ['P0133']);
    });
  });

  group('protocolo ELM327', () {
    test('query devolve os bytes depois do cabeçalho 41 0C', () async {
      final transport = FakeTransport()..reply = '41 0C 1A F8';
      final elm = Elm327(transport)..start();

      final data = await elm.query('010C');

      expect(data, [0x1A, 0xF8]);
      expect(transport.sent.last, '010C\r');
    });

    test('NO DATA devolve null', () async {
      final transport = FakeTransport()..reply = 'NO DATA';
      final elm = Elm327(transport)..start();

      expect(await elm.query('010C'), isNull);
    });
  });
}


