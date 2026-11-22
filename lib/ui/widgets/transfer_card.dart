import 'package:flutter/material.dart';

import '../../mtp/models.dart';
import '../format.dart';

/// Cartão flutuante da transferência: arquivo atual, progresso total, velocidade e
/// tempo restante, com cancelar (como o painel de cópia do OpenMTP e do Finder).
class TransferCard extends StatelessWidget {
  const TransferCard({
    super.key,
    required this.title,
    required this.uploading,
    required this.progress,
    required this.speed,
    required this.onCancel,
  });

  final String title;
  final bool uploading;
  final TransferProgress? progress;
  final double speed;
  final VoidCallback onCancel;

  String _eta(TransferProgress p) {
    if (speed <= 0) return '';
    final secs = ((p.totalBytes - p.totalSent) / speed).round();
    if (secs < 60) return '${secs}s restantes';
    if (secs < 3600) return '${secs ~/ 60} min restantes';
    return '${secs ~/ 3600}h ${(secs % 3600) ~/ 60} min restantes';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final p = progress;
    final pct = p?.fraction.clamp(0.0, 1.0);
    final muted = t.bodySmall?.copyWith(color: cs.onSurfaceVariant);
    return Material(
      elevation: 12,
      shadowColor: Colors.black38,
      color: cs.surface,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: cs.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)),
              child: Icon(uploading ? Icons.upload_rounded : Icons.download_rounded, color: cs.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  p == null ? 'Preparando…' : 'Arquivo ${p.fileIndex} de ${p.fileCount}',
                  style: muted,
                ),
              ]),
            ),
            Text(pct == null ? '' : '${(pct * 100).toStringAsFixed(0)}%',
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: cs.primary)),
            IconButton(
              tooltip: 'Cancelar',
              onPressed: onCancel,
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: pct, minHeight: 6, backgroundColor: cs.surfaceContainerHigh),
          ),
          const SizedBox(height: 8),
          if (p != null) ...[
            Text(p.currentFile, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
            const SizedBox(height: 2),
            Row(children: [
              Expanded(
                child: Text('${formatBytes(p.totalSent)} de ${formatBytes(p.totalBytes)}', style: muted),
              ),
              if (speed > 0) Text('${formatBytes(speed.round())}/s  ·  ${_eta(p)}', style: muted),
            ]),
          ],
        ]),
      ),
    );
  }
}
