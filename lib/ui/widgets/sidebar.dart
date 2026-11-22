import 'package:flutter/material.dart';

import '../../mtp/models.dart';
import '../format.dart';
import '../theme.dart';

/// Barra lateral: o aparelho conectado e os armazenamentos dele, com o espaço usado.
class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.device,
    required this.current,
    required this.busy,
    required this.onSelectStorage,
    required this.onDisconnect,
  });

  final MtpDeviceInfo device;
  final MtpStorage? current;
  final bool busy;
  final ValueChanged<MtpStorage> onSelectStorage;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      color: cs.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // aparelho
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: switchRed.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.videogame_asset_rounded,
                    color: switchRed,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF34C759),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              device.product.isEmpty
                                  ? 'Conectado'
                                  : 'Conectado · ${device.product}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 6),
            child: Text(
              'ARMAZENAMENTO',
              style: t.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: .8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // o DBI mostra vários armazenamentos (SD, NAND, instalar...): a lista rola
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final s in device.storages)
                  _StorageTile(
                    storage: s,
                    selected: s.id == current?.id,
                    onTap: busy ? null : () => onSelectStorage(s),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : onDisconnect,
            icon: const Icon(Icons.eject_rounded, size: 18),
            label: const Text('Desconectar'),
          ),
        ],
      ),
    );
  }
}

class _StorageTile extends StatelessWidget {
  const _StorageTile({
    required this.storage,
    required this.selected,
    required this.onTap,
  });
  final MtpStorage storage;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final s = storage;
    final hasCap = s.maxCapacity > 0;
    final used = hasCap
        ? (1 - s.freeBytes / s.maxCapacity).clamp(0.0, 1.0)
        : 0.0;
    // "1: SD Card" -> "SD Card"
    final name = s.description.replaceFirst(RegExp(r'^\d+:\s*'), '');
    final icon = name.toLowerCase().contains('sd')
        ? Icons.sd_card_rounded
        : Icons.storage_rounded;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? cs.primary.withValues(alpha: .10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: selected ? cs.primary : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyMedium?.copyWith(
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected ? cs.primary : cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                if (hasCap) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: used,
                      minHeight: 5,
                      backgroundColor: cs.outlineVariant,
                      color: used > .9 ? cs.error : cs.primary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${formatBytes(s.freeBytes)} livres de ${formatBytes(s.maxCapacity)}',
                    style: t.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
