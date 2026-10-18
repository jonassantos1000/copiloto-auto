import 'package:flutter/material.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';

import '../../core/app_services.dart';
import '../../core/app_theme.dart';

/// Tela de conexão com o adaptador OBD2.
/// Mostra dois grupos: dispositivos já pareados (para conectar) e
/// dispositivos encontrados na busca (para parear). Ao conectar,
/// inicializa o protocolo ELM327.
class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key});

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  final _bluetooth = FlutterClassicBluetooth();

  List<BtcDevice> _paired = [];
  List<BtcDevice> _nearby = [];
  bool _loadingPaired = true;
  bool _scanning = false;
  String? _busyAddress; // dispositivo sendo pareado ou conectado agora
  String? _connectedAddress;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPaired();
  }

  /// Pede a permissão de Bluetooth quando necessário.
  Future<bool> _ensurePermissions() async {
    var status = await _bluetooth.checkPermissions();
    if (status == BtcPermissionStatus.denied) {
      status = await _bluetooth.requestPermissions();
    }
    if (status == BtcPermissionStatus.permanentlyDenied) {
      _setError(
        'Permissão de Bluetooth negada. Libere em Configurações do app.',
      );
      return false;
    }
    return status == BtcPermissionStatus.granted ||
        status == BtcPermissionStatus.notRequired;
  }

  Future<void> _loadPaired() async {
    setState(() {
      _loadingPaired = true;
      _error = null;
    });
    try {
      if (!await _ensurePermissions()) return;
      final devices = await obdTransport.pairedDevices();
      devices.sort((a, b) =>
          (_looksLikeObd(b) ? 1 : 0).compareTo(_looksLikeObd(a) ? 1 : 0));
      if (!mounted) return;
      setState(() => _paired = devices);
    } catch (e) {
      _setError('Não foi possível listar os pareados: $e');
    } finally {
      if (mounted) setState(() => _loadingPaired = false);
    }
  }

  /// Busca dispositivos próximos por alguns segundos.
  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
      _nearby = [];
    });
    try {
      if (!await _ensurePermissions()) return;

      // No Android 11 e anteriores, a busca não encontra nada com a
      // localização desligada, mesmo com a permissão concedida.
      if (await _bluetooth.isLocationServiceRequired() &&
          !await _bluetooth.isLocationServiceEnabled()) {
        _setError(
          'Ative a localização do celular para buscar dispositivos.',
        );
        await _bluetooth.openLocationSettings();
        return;
      }

      final found = await _bluetooth.scan(timeout: const Duration(seconds: 10));
      final pairedAddresses = _paired.map((d) => d.address).toSet();
      final notPaired =
          found.where((d) => !pairedAddresses.contains(d.address)).toList();
      notPaired.sort((a, b) =>
          (_looksLikeObd(b) ? 1 : 0).compareTo(_looksLikeObd(a) ? 1 : 0));

      if (!mounted) return;
      setState(() => _nearby = notPaired);
    } catch (e) {
      _setError('Falha na busca: $e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  /// Pareia com o dispositivo. O Android mostra a tela de PIN do sistema.
  Future<void> _pair(BtcDevice device) async {
    setState(() {
      _busyAddress = device.address;
      _error = null;
    });
    try {
      final ok = await _bluetooth.bondDevice(device.address);
      if (!ok) {
        _setError(
          'Pareamento não concluído. Se pedir PIN, tente 1234 ou 0000.',
        );
        return;
      }
      if (!mounted) return;
      setState(() => _nearby.removeWhere((d) => d.address == device.address));
      await _loadPaired();
    } catch (e) {
      _setError('Falha ao parear: $e');
    } finally {
      if (mounted) setState(() => _busyAddress = null);
    }
  }

  Future<void> _connect(BtcDevice device) async {
    setState(() {
      _busyAddress = device.address;
      _error = null;
    });
    try {
      await obdTransport.connect(device.address);
      await elm327.init();
      if (!mounted) return;
      setState(() => _connectedAddress = device.address);
    } catch (e) {
      await obdTransport.disconnect();
      _setError('Falha ao conectar: $e');
    } finally {
      if (mounted) setState(() => _busyAddress = null);
    }
  }

  Future<void> _disconnect() async {
    await obdTransport.disconnect();
    if (!mounted) return;
    setState(() => _connectedAddress = null);
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  bool _looksLikeObd(BtcDevice device) {
    final name = device.displayName.toLowerCase();
    return name.contains('obd') || name.contains('elm');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final connected = _connectedAddress != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Conexão OBD2')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration(context),
              child: Row(
                children: [
                  Icon(
                    connected
                        ? Icons.bluetooth_connected_rounded
                        : Icons.bluetooth_disabled_rounded,
                    color: connected ? const Color(0xFF22C55E) : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      connected
                          ? 'Conectado a $_connectedAddress'
                          : 'Nenhum adaptador conectado',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  if (connected)
                    TextButton(
                      onPressed: _disconnect,
                      child: const Text('Desconectar'),
                    ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFB91C1C)),
                ),
              ),
            ],

            const SizedBox(height: 24),
            Text(
              'Pareados',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (_loadingPaired)
              const Center(child: CircularProgressIndicator())
            else if (_paired.isEmpty)
              Text(
                'Nenhum dispositivo pareado ainda. Busque abaixo e pareie o adaptador.',
                style: TextStyle(color: colors.onSurfaceVariant),
              )
            else
              for (final device in _paired)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DeviceTile(
                    device: device,
                    likelyObd: _looksLikeObd(device),
                    trailing: device.address == _connectedAddress
                        ? const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF22C55E))
                        : FilledButton(
                            onPressed: _busyAddress != null
                                ? null
                                : () => _connect(device),
                            child: _busyAddress == device.address
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text('Conectar'),
                          ),
                  ),
                ),

            const SizedBox(height: 24),
            Text(
              'Buscar dispositivos',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Deixe o carro com a ignição ligada e o adaptador na porta OBD2.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _scanning || _busyAddress != null ? null : _scan,
              icon: _scanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search_rounded),
              label: Text(_scanning ? 'Buscando...' : 'Buscar agora'),
            ),
            const SizedBox(height: 12),
            if (!_scanning && _nearby.isEmpty)
              Text(
                'Nenhum dispositivo novo encontrado. Toque em "Buscar agora".',
                style: TextStyle(color: colors.onSurfaceVariant),
              )
            else
              for (final device in _nearby)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DeviceTile(
                    device: device,
                    likelyObd: _looksLikeObd(device),
                    trailing: OutlinedButton(
                      onPressed:
                          _busyAddress != null ? null : () => _pair(device),
                      child: _busyAddress == device.address
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Parear'),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Cartão de um dispositivo. O trailing é o botão de ação (conectar ou parear).
class _DeviceTile extends StatelessWidget {
  final BtcDevice device;
  final bool likelyObd;
  final Widget trailing;

  const _DeviceTile({
    required this.device,
    required this.likelyObd,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Row(
        children: [
          Icon(
            Icons.directions_car_rounded,
            color: likelyObd ? const Color(0xFF0D9488) : colors.onSurfaceVariant,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  likelyObd
                      ? '${device.address} · parece OBD2'
                      : device.address,
                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}
