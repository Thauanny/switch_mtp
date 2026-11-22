import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../mtp/models.dart';
import '../format.dart';

/// Barra de cima: voltar, caminho clicável, busca e as ações da pasta (enviar, nova pasta).
class BrowserToolbar extends StatelessWidget {
  const BrowserToolbar({
    super.key,
    required this.storageName,
    required this.path,
    required this.canGoUp,
    required this.enabled,
    required this.loading,
    required this.search,
    required this.onSearchChanged,
    required this.onGoUp,
    required this.onGoTo,
    required this.onRefresh,
    required this.onNewFolder,
    required this.onUploadFiles,
    required this.onUploadFolder,
  });

  final String storageName;
  final List<String> path;
  final bool canGoUp, enabled, loading;
  final TextEditingController search;
  final VoidCallback onSearchChanged, onGoUp, onRefresh, onNewFolder, onUploadFiles, onUploadFolder;
  final ValueChanged<int> onGoTo;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final root = storageName.replaceFirst(RegExp(r'^\d+:\s*'), '');
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
      child: Row(children: [
        IconButton(
          tooltip: 'Voltar à pasta de cima (⌘↑)',
          onPressed: canGoUp ? onGoUp : null,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 4),
        // caminho
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Row(children: [
              _Crumb(label: root, icon: Icons.sd_card_rounded, current: path.isEmpty, onTap: () => onGoTo(0)),
              for (var i = 0; i < path.length; i++) ...[
                Icon(Icons.chevron_right_rounded, size: 18, color: cs.onSurfaceVariant),
                _Crumb(label: path[i], current: i == path.length - 1, onTap: () => onGoTo(i + 1)),
              ],
            ]),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 220,
          child: TextField(
            controller: search,
            onChanged: (_) => onSearchChanged(),
            decoration: InputDecoration(
              hintText: 'Buscar nesta pasta',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              prefixIconConstraints: const BoxConstraints(minWidth: 34),
              suffixIcon: search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar',
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () {
                        search.clear();
                        onSearchChanged();
                      },
                    ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Atualizar (⌘R)',
          onPressed: enabled && !loading ? onRefresh : null,
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: 'Nova pasta (⇧⌘N)',
          onPressed: enabled ? onNewFolder : null,
          icon: const Icon(Icons.create_new_folder_outlined),
        ),
        const SizedBox(width: 6),
        MenuAnchor(
          alignmentOffset: const Offset(0, 6),
          menuChildren: [
            MenuItemButton(
              leadingIcon: const Icon(Icons.upload_file_rounded, size: 18),
              shortcut: const SingleActivator(LogicalKeyboardKey.keyO, meta: true),
              onPressed: onUploadFiles,
              child: const Text('Arquivos…'),
            ),
            MenuItemButton(
              leadingIcon: const Icon(Icons.drive_folder_upload_rounded, size: 18),
              onPressed: onUploadFolder,
              child: const Text('Pasta inteira…'),
            ),
          ],
          builder: (context, menu, _) => FilledButton.icon(
            onPressed: enabled ? () => menu.isOpen ? menu.close() : menu.open() : null,
            icon: const Icon(Icons.upload_rounded, size: 18),
            label: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Enviar'),
              SizedBox(width: 2),
              Icon(Icons.expand_more_rounded, size: 18),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Crumb extends StatelessWidget {
  const _Crumb({required this.label, required this.current, required this.onTap, this.icon});
  final String label;
  final bool current;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: current ? null : onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        minimumSize: Size.zero,
        foregroundColor: cs.onSurfaceVariant,
        disabledForegroundColor: cs.onSurface,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 6)],
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: current ? 16 : 14, fontWeight: current ? FontWeight.w700 : FontWeight.w500)),
        ),
      ]),
    );
  }
}

/// Aparece só com algo selecionado: quantos, tamanho e o que dá para fazer com eles.
class SelectionBar extends StatelessWidget {
  const SelectionBar({
    super.key,
    required this.selected,
    required this.enabled,
    required this.onDownload,
    required this.onRename,
    required this.onDelete,
    required this.onClear,
  });

  final List<MtpEntry> selected;
  final bool enabled;
  final VoidCallback onDownload, onRename, onDelete, onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final n = selected.length;
    final size = selected.where((e) => !e.isFolder).fold<int>(0, (s, e) => s + e.size);
    final folders = selected.where((e) => e.isFolder).length;
    return AnimatedSize(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: n == 0
          ? const SizedBox(width: double.infinity)
          : Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.primary.withValues(alpha: .25)),
              ),
              child: Row(children: [
                Icon(Icons.check_circle_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    [
                      n == 1 ? '1 selecionado' : '$n selecionados',
                      if (size > 0) formatBytes(size),
                      if (folders > 0) folders == 1 ? '1 pasta' : '$folders pastas',
                    ].join('  ·  '),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: enabled ? onDownload : null,
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Baixar para o Mac'),
                ),
                const SizedBox(width: 6),
                if (n == 1)
                  IconButton(
                    tooltip: 'Renomear',
                    onPressed: enabled ? onRename : null,
                    icon: const Icon(Icons.edit_rounded, size: 19),
                  ),
                IconButton(
                  tooltip: 'Apagar (⌘⌫)',
                  onPressed: enabled ? onDelete : null,
                  icon: Icon(Icons.delete_outline_rounded, size: 20, color: enabled ? cs.error : null),
                ),
                IconButton(
                  tooltip: 'Limpar seleção (Esc)',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ]),
            ),
    );
  }
}
