import 'dart:async';

import '../transport/obd_transport.dart';

/// Erro de comunicação com o adaptador ou a ECU.
class ObdException implements Exception {
  final String message;
  const ObdException(this.message);

  @override
  String toString() => 'ObdException: $message';
}

/// Fala o protocolo ELM327: envia comandos AT e PIDs e devolve as linhas da resposta.
class Elm327 {
  final ObdTransport transport;
  final Duration defaultTimeout;

  final StringBuffer _buffer = StringBuffer();
  StreamSubscription<String>? _subscription;
  Completer<String>? _pending;

  Elm327(this.transport, {this.defaultTimeout = const Duration(seconds: 3)});

  /// Começa a ouvir o adaptador. Chame antes de qualquer comando.
  void start() {
    _subscription = transport.incoming.listen((chunk) {
      _buffer.write(chunk);
      // O ELM327 termina cada resposta com o caractere '>' (prompt).
      if (_buffer.toString().contains('>')) {
        final response = _buffer.toString();
        _buffer.clear();
        final pending = _pending;
        if (pending != null && !pending.isCompleted) {
          pending.complete(response);
        }
      }
    });
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Sequência de inicialização recomendada para ELM327.
  Future<void> init() async {
    await send('ATZ', timeout: const Duration(seconds: 5)); // reset
    await send('ATE0'); // desliga o eco dos comandos
    await send('ATL0'); // sem quebras de linha extras
    await send('ATSP0'); // detecção automática do protocolo
  }

  /// Envia um comando e devolve as linhas da resposta, sem eco nem prompt.
  Future<List<String>> send(String command, {Duration? timeout}) async {
    if (_pending != null) {
      throw const ObdException('Já existe um comando em andamento');
    }
    _buffer.clear();
    final completer = Completer<String>();
    _pending = completer;
    transport.write('$command\r');

    try {
      final raw = await completer.future.timeout(timeout ?? defaultTimeout);
      return _cleanLines(raw);
    } on TimeoutException {
      throw ObdException('Sem resposta para $command');
    } finally {
      _pending = null;
    }
  }

  /// Consulta um modo e PID, ex.: '010C' (RPM).
  /// Devolve os bytes de dados (sem o cabeçalho 41 0C) ou null se a ECU não respondeu.
  Future<List<int>?> query(String modePid) async {
    final mode = modePid.substring(0, 2).toUpperCase();
    final pid = modePid.substring(2).toUpperCase();
    final responseMode = (int.parse(mode, radix: 16) + 0x40)
        .toRadixString(16)
        .toUpperCase()
        .padLeft(2, '0');
    final header = '$responseMode$pid';

    final lines = await send(modePid);
    for (final line in lines) {
      // Remove prefixos de CAN tipo "0: " e espaços entre os bytes.
      final hex = line
          .replaceFirst(RegExp(r'^[0-9A-Fa-f]{1,2}:\s*'), '')
          .replaceAll(' ', '')
          .toUpperCase();
      if (hex.startsWith(header)) {
        return _hexToBytes(hex.substring(header.length));
      }
    }
    return null;
  }

  List<String> _cleanLines(String raw) {
    return raw
        .replaceAll('>', '')
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && line != 'SEARCHING...')
        .toList();
  }

  List<int> _hexToBytes(String hex) {
    final bytes = <int>[];
    for (var i = 0; i + 1 < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }
}
