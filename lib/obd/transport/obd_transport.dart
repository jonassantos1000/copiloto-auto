/// Contrato de transporte. Qualquer meio (Bluetooth clássico, BLE ou um mock de teste)
/// precisa oferecer isso para o protocolo ELM327 funcionar.
abstract class ObdTransport {
  bool get isConnected;

  /// Texto recebido do adaptador, em pedaços (podem chegar quebrados).
  Stream<String> get incoming;

  /// Envia texto cru ao adaptador.
  void write(String data);
}
