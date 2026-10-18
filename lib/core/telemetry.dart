/// Um instante de leitura do carro, já convertido em valores físicos.
class Telemetry {
  final DateTime timestamp;
  final double? coolantTempC;   // temperatura do motor (°C)
  final double? speedKmh;       // velocidade (km/h)
  final double? rpm;            // rotação (rpm)
  final double? mafGs;          // fluxo de ar (g/s)
  final double? fuelLevelPct;   // nível de combustível (%)

  const Telemetry({
    required this.timestamp,
    this.coolantTempC,
    this.speedKmh,
    this.rpm,
    this.mafGs,
    this.fuelLevelPct,
  });
}
