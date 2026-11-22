import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../mtp/models.dart';
import '../format.dart';

/// Barra de cima: voltar, caminho clicável, busca e as ações da pasta (enviar, nova pasta).
class BrowserToolbar extends StatefulWidget {
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
  final VoidCallback onSearchChanged,
      onGoUp,
      onRefresh,
      onNewFolder,
      onUploadFiles,
      onUploadFolder;
  final ValueChanged<int> onGoTo;

  @override
  State<BrowserToolbar> createState() => _BrowserToolbarState();
}

class _BrowserToolbarState extends State<BrowserToolbar> {
  /// Janela estreita: a busca fica recolhida numa lupa e abre no lugar do caminho.
  bool _searchOpen = false;
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  void _closeSearch() {
    widget.search.clear();
    widget.onSearchChanged();
    setState(() => _searchOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final storageName = w.storageName, path = w.path, canGoUp = w.canGoUp;
    final enabled = w.enabled, loading = w.loading, search = w.search;
    final onSearchChanged = w.onSearchChanged,
        onGoUp = w.onGoUp,
        onGoTo = w.onGoTo;
    final onRefresh = w.onRefresh, onNewFolder = w.onNewFolder;
    final onUploadFiles = w.onUploadFiles, onUploadFolder = w.onUploadFolder;
    final root = storageName.replaceFirst(RegExp(r'^\d+:\s*'), '');
    return LayoutBuilder(
      builder: (context, c) {
        // janela estreita: busca numa lupa e "Enviar" só com o ícone, para o caminho caber
        final narrow = c.maxWidth < 720;
        final searching = narrow && (_searchOpen || search.text.isNotEmpty);
        final field = TextField(
          controller: search,
          focusNode: _searchFocus,
          onChanged: (_) => onSearchChanged(),
          decoration: InputDecoration(
            hintText: 'Buscar nesta pasta',
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            prefixIconConstraints: const BoxConstraints(minWidth: 34),
            suffixIcon: search.text.isEmpty && !searching
                ? null
                : IconButton(
                    tooltip: 'Limpar',
                    icon: const Icon(Icons.close_rounded, size: 16),
                    onPressed: narrow
                        ? _closeSearch
                        : () {
                            search.clear();
                            onSearchChanged();
                          },
                  ),
          ),
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Voltar à pasta de cima (⌘↑)',
                onPressed: canGoUp ? onGoUp : null,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 4),
              // caminho (ou, na janela estreita com a busca aberta, o campo de busca)
              Expanded(
                child: searching
                    ? field
                    : _PathBar(
                        root: root,
                        path: path,
                        compact: narrow || path.length > 2,
                        onGoTo: onGoTo,
                      ),
              ),
              const SizedBox(width: 12),
              if (!narrow)
                SizedBox(width: 240, child: field)
              else if (!searching)
                IconButton(
                  tooltip: 'Buscar nesta pasta',
                  onPressed: () {
                    setState(() => _searchOpen = true);
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _searchFocus.requestFocus(),
                    );
                  },
                  icon: const Icon(Icons.search_rounded),
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
                    leadingIcon: const Icon(
                      Icons.upload_file_rounded,
                      size: 18,
                    ),
                    shortcut: const SingleActivator(
                      LogicalKeyboardKey.keyO,
                      meta: true,
                    ),
                    onPressed: onUploadFiles,
                    child: const Text('Arquivos…'),
                  ),
                  MenuItemButton(
                    leadingIcon: const Icon(
                      Icons.drive_folder_upload_rounded,
                      size: 18,
                    ),
                    onPressed: onUploadFolder,
                    child: const Text('Pasta inteira…'),
                  ),
                ],
                builder: (context, menu, _) => Tooltip(
                  message: 'Enviar arquivos ou pasta (ou arraste do Finder)',
                  child: FilledButton(
                    onPressed: enabled
                        ? () => menu.isOpen ? menu.close() : menu.open()
                        : null,
                    style: narrow
                        ? FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                          )
                        : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.upload_rounded, size: 18),
                        if (!narrow) ...[
                          const SizedBox(width: 6),
                          const Text('Enviar'),
                        ],
                        const SizedBox(width: 2),
                        const Icon(Icons.expand_more_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Crumb extends StatelessWidget {
  const _Crumb({
    required this.label,
    required this.current,
    required this.onTap,
    this.icon,
    this.iconOnly = false,
  });
  final String label;
  final bool current, iconOnly;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final button = TextButton(
      onPressed: current ? null : onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        minimumSize: Size.zero,
        foregroundColor: cs.onSurfaceVariant,
        disabledForegroundColor: cs.onSurface,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, size: 16),
          if (icon != null && !iconOnly) const SizedBox(width: 6),
          if (!iconOnly)
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: current ? 16 : 14,
                  fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
    return iconOnly ? Tooltip(message: label, child: button) : button;
  }
}

/// Caminho da pasta. Largo: todo o caminho, rolando (a pasta atual sempre à vista). Estreito
/// ou fundo: "SD Card › … › pasta atual", com as pastas do meio num menu.
class _PathBar extends StatelessWidget {
  const _PathBar({
    required this.root,
    required this.path,
    required this.compact,
    required this.onGoTo,
  });
  final String root;
  final List<String> path;
  final bool compact;
  final ValueChanged<int> onGoTo;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget sep() =>
        Icon(Icons.chevron_right_rounded, size: 18, color: cs.onSurfaceVariant);
    if (path.isEmpty) {
      return Row(
        children: [
          Flexible(
            child: _Crumb(
              label: root,
              icon: Icons.sd_card_rounded,
              current: true,
              onTap: () {},
            ),
          ),
        ],
      );
    }
    if (compact) {
      return Row(
        children: [
          _Crumb(
            label: root,
            icon: Icons.sd_card_rounded,
            iconOnly: true,
            current: false,
            onTap: () => onGoTo(0),
          ),
          if (path.length > 1) ...[
            sep(),
            PopupMenuButton<int>(
              tooltip: 'Pastas do caminho',
              onSelected: onGoTo,
              itemBuilder: (_) => [
                for (var i = 0; i < path.length - 1; i++)
                  PopupMenuItem(
                    value: i + 1,
                    child: Row(
                      children: [
                        SizedBox(width: 12.0 * i),
                        const Icon(
                          Icons.folder_rounded,
                          size: 18,
                          color: Color(0xFF4A9EFF),
                        ),
                        const SizedBox(width: 8),
                        Text(path[i]),
                      ],
                    ),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Icon(
                  Icons.more_horiz_rounded,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
          sep(),
          Flexible(
            child: _Crumb(label: path.last, current: true, onTap: () {}),
          ),
        ],
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        children: [
          _Crumb(
            label: root,
            icon: Icons.sd_card_rounded,
            current: false,
            onTap: () => onGoTo(0),
          ),
          for (var i = 0; i < path.length; i++) ...[
            sep(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: _Crumb(
                label: path[i],
                current: i == path.length - 1,
                onTap: () => onGoTo(i + 1),
              ),
            ),
          ],
        ],
      ),
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
    final size = selected
        .where((e) => !e.isFolder)
        .fold<int>(0, (s, e) => s + e.size);
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
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        n == 1 ? '1 selecionado' : '$n selecionados',
                        if (size > 0) formatBytes(size),
                        if (folders > 0)
                          folders == 1 ? '1 pasta' : '$folders pastas',
                      ].join('  ·  '),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  _DownloadButton(enabled: enabled, onDownload: onDownload),
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
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: enabled ? cs.error : null,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Limpar seleção (Esc)',
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
    );
  }
}

/// "Baixar para o Mac": com texto quando a janela é larga, só o ícone quando estreita.
class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.enabled, required this.onDownload});
  final bool enabled;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    if (wide) {
      return FilledButton.tonalIcon(
        onPressed: enabled ? onDownload : null,
        icon: const Icon(Icons.download_rounded, size: 18),
        label: const Text('Baixar para o Mac'),
      );
    }
    return Tooltip(
      message: 'Baixar para o Mac',
      child: FilledButton.tonal(
        onPressed: enabled ? onDownload : null,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        child: const Icon(Icons.download_rounded, size: 18),
      ),
    );
  }
}
