// Converte bytes de resposta OBD2 em valores físicos.
// Cada função recebe os bytes de dados (sem o cabeçalho) e devolve null se faltarem bytes.

bool _short(List<int>? b, int needed) => b == null || b.length < needed;

/// PID 01 05: temperatura do líquido de arrefecimento. Fórmula: A - 40.
double? decodeCoolantTemp(List<int>? b) {
  if (_short(b, 1)) return null;
  return b![0].toDouble() - 40;
}

/// PID 01 0C: rotação do motor. Fórmula: (256A + B) / 4.
double? decodeRpm(List<int>? b) {
  if (_short(b, 2)) return null;
  return (256 * b![0] + b[1]) / 4;
}

/// PID 01 0D: velocidade. Fórmula: A.
double? decodeSpeed(List<int>? b) {
  if (_short(b, 1)) return null;
  return b![0].toDouble();
}

/// PID 01 10: fluxo de ar (MAF) em g/s. Fórmula: (256A + B) / 100.
double? decodeMaf(List<int>? b) {
  if (_short(b, 2)) return null;
  return (256 * b![0] + b[1]) / 100;
}

/// PID 01 2F: nível de combustível em %. Fórmula: A * 100 / 255.
double? decodeFuelLevel(List<int>? b) {
  if (_short(b, 1)) return null;
  return b![0] * 100 / 255;
}

/// Modo 03: lista de códigos de erro (DTC). Cada código ocupa 2 bytes.
/// Exemplo: 01 33 vira P0133. Pares 00 00 são preenchimento e são ignorados.
List<String> decodeDtcs(List<int>? b) {
  if (b == null) return const [];
  const letters = ['P', 'C', 'B', 'U'];
  final codes = <String>[];
  for (var i = 0; i + 1 < b.length; i += 2) {
    final first = b[i];
    final second = b[i + 1];
    if (first == 0 && second == 0) continue;
    final letter = letters[(first >> 6) & 0x3];
    final digit1 = (first >> 4) & 0x3;
    final digit2 = (first & 0xF).toRadixString(16).toUpperCase();
    final digits34 = second.toRadixString(16).toUpperCase().padLeft(2, '0');
    codes.add('$letter$digit1$digit2$digits34');
  }
  return codes;
}
