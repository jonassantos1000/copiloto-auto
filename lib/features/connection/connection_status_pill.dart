import 'package:flutter/material.dart';

import '../../core/app_services.dart';
import 'connection_page.dart';

/// Pílula de status da conexão, mostrada no cabeçalho do dashboard.
/// O texto diz o estado e a ação ("toque para conectar"), sem depender de ícone.
/// Ao tocar, abre a tela de conexão.
class ConnectionStatusPill extends StatelessWidget {
  const ConnectionStatusPill({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: obdConnection,
      builder: (context, _) {
        final connected = obdConnection.value != null;
        final color =
            connected ? const Color(0xFF22C55E) : const Color(0xFFF59E0B);
        final label = connected
            ? 'Adaptador conectado'
            : 'Sem adaptador · Toque para conectar';

        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ConnectionPage()),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
