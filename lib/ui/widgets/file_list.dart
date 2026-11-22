import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../mtp/models.dart';
import '../format.dart';
import '../theme.dart';

enum SortBy { name, kind, size, modified }

/// Lista de arquivos no estilo do Finder: cabeçalho com colunas ordenáveis, linhas
/// compactas, seleção com ⌘/⇧, clique duplo abre a pasta e clique direito abre o menu.
class FileList extends StatefulWidget {
  const FileList({
    super.key,
    required this.entries,
    required this.selected,
    required this.sortBy,
    required this.ascending,
    required this.loading,
    required this.filtering,
    required this.onSort,
    required this.onTap,
    required this.onOpen,
    required this.onContextMenu,
    required this.onBackgroundTap,
  });

  final List<MtpEntry> entries;
  final Set<int> selected;
  final SortBy sortBy;
  final bool ascending, loading, filtering;
  final ValueChanged<SortBy> onSort;
  final ValueChanged<int> onTap;
  final ValueChanged<MtpEntry> onOpen;
  final void Function(MtpEntry, Offset) onContextMenu;
  final VoidCallback onBackgroundTap;

  @override
  State<FileList> createState() => _FileListState();
}

class _FileListState extends State<FileList> {
  // clique duplo feito à mão: o do InkWell atrasa o clique simples (a seleção)
  int? _lastId;
  DateTime _lastAt = DateTime(0);

  void _down(int index, MtpEntry e) {
    final now = DateTime.now();
    final dbl = _lastId == e.id && now.difference(_lastAt) < kDoubleTapTimeout;
    _lastId = e.id;
    _lastAt = now;
    if (dbl && e.isFolder) {
      _lastId = null;
      widget.onOpen(e);
    } else {
      widget.onTap(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entries = widget.entries;
    return Column(children: [
      _Header(sortBy: widget.sortBy, ascending: widget.ascending, onSort: widget.onSort),
      Expanded(
        child: entries.isEmpty && !widget.loading
            ? _Empty(filtering: widget.filtering)
            : GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: widget.onBackgroundTap,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 120),
                  itemCount: entries.length,
                  itemExtent: 40,
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    return _Row(
                      entry: e,
                      striped: i.isOdd,
                      selected: widget.selected.contains(e.id),
                      onDown: () => _down(i, e),
                      onOpen: () => widget.onOpen(e),
                      onContextMenu: (pos) => widget.onContextMenu(e, pos),
                      selectionColor: cs.primary,
                    );
                  },
                ),
              ),
      ),
    ]);
  }
}

const _kindWidth = 110.0, _sizeWidth = 90.0, _dateWidth = 140.0, _openWidth = 36.0;

class _Header extends StatelessWidget {
  const _Header({required this.sortBy, required this.ascending, required this.onSort});
  final SortBy sortBy;
  final bool ascending;
  final ValueChanged<SortBy> onSort;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget col(String label, SortBy by, {double? width, bool end = false}) {
      final on = sortBy == by;
      final child = InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => onSort(by),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: end ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                      color: on ? cs.onSurface : cs.onSurfaceVariant)),
              if (on)
                Icon(ascending ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
                    size: 18, color: cs.onSurface),
            ],
          ),
        ),
      );
      return width == null ? Expanded(child: child) : SizedBox(width: width, child: child);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outlineVariant))),
      child: Row(children: [
        const SizedBox(width: 40),
        col('Nome', SortBy.name),
        col('Tipo', SortBy.kind, width: _kindWidth),
        col('Tamanho', SortBy.size, width: _sizeWidth, end: true),
        col('Modificado', SortBy.modified, width: _dateWidth),
        const SizedBox(width: _openWidth),
      ]),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({
    required this.entry,
    required this.striped,
    required this.selected,
    required this.onDown,
    required this.onOpen,
    required this.onContextMenu,
    required this.selectionColor,
  });

  final MtpEntry entry;
  final bool striped, selected;
  final VoidCallback onDown, onOpen;
  final ValueChanged<Offset> onContextMenu;
  final Color selectionColor;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final e = widget.entry;
    final (icon, color) = fileVisual(e.name, isFolder: e.isFolder);
    final sel = widget.selected;
    final muted = TextStyle(fontSize: 12.5, color: sel ? Colors.white.withValues(alpha: .85) : cs.onSurfaceVariant);
    final bg = sel
        ? widget.selectionColor
        : _hover
            ? cs.surfaceContainerHigh
            : widget.striped
                ? cs.surfaceContainerLow
                : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Listener(
        onPointerDown: (ev) {
          if (ev.kind == PointerDeviceKind.mouse && ev.buttons == kSecondaryMouseButton) {
            widget.onContextMenu(ev.position);
          } else if (ev.buttons == kPrimaryButton) {
            widget.onDown();
          }
        },
        // a linha fica com o toque (o fundo da lista limpa a seleção só fora das linhas)
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            SizedBox(
              width: 32,
              child: Icon(icon, size: 22, color: sel ? Colors.white : color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(e.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w500, color: sel ? Colors.white : cs.onSurface)),
            ),
            SizedBox(
              width: _kindWidth,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(fileKind(e.name, isFolder: e.isFolder), overflow: TextOverflow.ellipsis, style: muted),
              ),
            ),
            SizedBox(
              width: _sizeWidth,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(e.isFolder ? '—' : formatBytes(e.size), textAlign: TextAlign.end, style: muted),
              ),
            ),
            SizedBox(
              width: _dateWidth,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(formatDate(e.modified), overflow: TextOverflow.ellipsis, style: muted),
              ),
            ),
            SizedBox(
              width: _openWidth,
              child: e.isFolder && (_hover || sel)
                  ? IconButton(
                      tooltip: 'Abrir',
                      visualDensity: VisualDensity.compact,
                      onPressed: widget.onOpen,
                      icon: Icon(Icons.chevron_right_rounded, size: 20, color: sel ? Colors.white : null),
                    )
                  : null,
            ),
          ]),
        ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.filtering});
  final bool filtering;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(color: cs.surfaceContainer, shape: BoxShape.circle),
          child: Icon(filtering ? Icons.search_off_rounded : Icons.folder_open_rounded,
              size: 34, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        Text(filtering ? 'Nada com esse nome nesta pasta' : 'Pasta vazia',
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(filtering ? 'Tente outra busca.' : 'Arraste arquivos do Finder para cá ou use "Enviar".',
            style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
      ]),
    );
  }
}

/// Camada que aparece ao arrastar arquivos do Finder sobre a lista.
class DropOverlay extends StatelessWidget {
  const DropOverlay({super.key, required this.target});
  final String target;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: .07),
          border: Border.all(color: cs.primary, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
            child: const Icon(Icons.upload_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 12),
          Text('Solte para enviar',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('para "$target"', style: TextStyle(color: cs.onSurfaceVariant)),
        ]),
      ),
    );
  }
}
