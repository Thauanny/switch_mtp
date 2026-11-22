import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../mtp/libmtp_bindings.dart' show kFilesAndFoldersRoot;
import '../mtp/models.dart';
import '../mtp/mtp_client.dart';
import 'format.dart';
import 'theme.dart';
import 'widgets/file_list.dart';
import 'widgets/sidebar.dart';
import 'widgets/toolbar.dart';
import 'widgets/transfer_card.dart';
import 'widgets/welcome.dart';

class Crumb {
  const Crumb(this.id, this.name);
  final int id;
  final String name;
}

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  MtpClient? _client;
  MtpDeviceInfo? _device;
  MtpStorage? _storage;
  List<Crumb> _path = const [];
  List<MtpEntry> _entries = const [];
  final Set<int> _selected = {};
  int? _anchorIndex;

  bool _connecting = false;
  bool _loading = false;
  bool _dragging = false;
  String? _error;

  // busca e ordenação da pasta aberta
  final _search = TextEditingController();
  SortBy _sortBy = SortBy.name;
  bool _ascending = true;

  // transferência em andamento
  String? _transferTitle;
  bool _uploading = false;
  TransferProgress? _progress;
  StreamSubscription<TransferProgress>? _progressSub;
  double _speed = 0; // bytes por segundo (média móvel)
  DateTime? _lastSampleAt;
  int _lastSampleBytes = 0;

  final _listFocus = FocusNode();

  bool get _busy => _transferTitle != null;
  int get _currentParent =>
      _path.isEmpty ? kFilesAndFoldersRoot : _path.last.id;
  String get _here =>
      _path.isEmpty ? (_storage?.description ?? '') : _path.last.name;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = await MtpClient.start();
    _progressSub = c.progress.listen(_onProgress);
    setState(() => _client = c);
  }

  void _onProgress(TransferProgress p) {
    final now = DateTime.now();
    final last = _lastSampleAt;
    if (last != null) {
      final dt = now.difference(last).inMicroseconds / 1e6;
      final db = p.totalSent - _lastSampleBytes;
      if (dt > 0.05 && db >= 0) {
        final instant = db / dt;
        _speed = _speed == 0 ? instant : _speed * .8 + instant * .2;
        _lastSampleAt = now;
        _lastSampleBytes = p.totalSent;
      }
    } else {
      _lastSampleAt = now;
      _lastSampleBytes = p.totalSent;
    }
    setState(() => _progress = p);
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _client?.disconnect();
    _search.dispose();
    _listFocus.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ ações

  Future<void> _connect() async {
    final c = _client;
    if (c == null) return;
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final info = await c.connect();
      setState(() {
        _device = info;
        _storage = info.storages.isEmpty ? null : info.storages.first;
        _path = const [];
      });
      await _reload();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _connecting = false);
    }
  }

  Future<void> _disconnect() async {
    await _client?.disconnect();
    setState(() {
      _device = null;
      _storage = null;
      _entries = const [];
      _path = const [];
      _selected.clear();
      _search.clear();
    });
  }

  Future<void> _reload({bool refreshStorages = false}) async {
    final c = _client, s = _storage;
    if (c == null || s == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (refreshStorages) {
        final list = await c.storages();
        final dev = _device!;
        _device = MtpDeviceInfo(
          name: dev.name,
          vendor: dev.vendor,
          product: dev.product,
          storages: list,
        );
        _storage = list.firstWhere(
          (x) => x.id == s.id,
          orElse: () => list.isNotEmpty ? list.first : s,
        );
      }
      final items = await c.list(_storage!.id, _currentParent);
      setState(() {
        _entries = items;
        _selected.clear();
        _anchorIndex = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _openFolder(MtpEntry e) {
    if (_busy || !e.isFolder) return;
    setState(() {
      _path = [..._path, Crumb(e.id, e.name)];
      _search.clear();
    });
    _reload();
  }

  void _goTo(int depth) {
    if (_busy || depth == _path.length) return;
    setState(() {
      _path = _path.sublist(0, depth);
      _search.clear();
    });
    _reload();
  }

  void _goUp() {
    if (_path.isNotEmpty) _goTo(_path.length - 1);
  }

  void _selectStorage(MtpStorage s) {
    if (_busy || s.id == _storage?.id) return;
    setState(() {
      _storage = s;
      _path = const [];
      _search.clear();
    });
    _reload();
  }

  /// A pasta como aparece: filtrada pela busca e ordenada (pastas sempre antes).
  List<MtpEntry> get _view {
    final q = _search.text.trim().toLowerCase();
    final list = [
      for (final e in _entries)
        if (q.isEmpty || e.name.toLowerCase().contains(q)) e,
    ];
    int by(MtpEntry a, MtpEntry b) => switch (_sortBy) {
      SortBy.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      SortBy.size => a.size.compareTo(b.size),
      SortBy.kind => fileKind(
        a.name,
        isFolder: a.isFolder,
      ).compareTo(fileKind(b.name, isFolder: b.isFolder)),
      SortBy.modified => (a.modified ?? DateTime(0)).compareTo(
        b.modified ?? DateTime(0),
      ),
    };
    list.sort((a, b) {
      if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
      final r = by(a, b);
      return _ascending ? r : -r;
    });
    return list;
  }

  void _sort(SortBy s) => setState(() {
    if (_sortBy == s) {
      _ascending = !_ascending;
    } else {
      _sortBy = s;
      _ascending = true;
    }
  });

  List<MtpEntry> get _selectedEntries =>
      _entries.where((e) => _selected.contains(e.id)).toList();

  Future<void> _runTransfer(
    String title,
    bool uploading,
    Future<TransferResult> Function() job,
  ) async {
    setState(() {
      _transferTitle = title;
      _uploading = uploading;
      _progress = null;
      _speed = 0;
      _lastSampleAt = null;
      _lastSampleBytes = 0;
    });
    try {
      final r = await job();
      if (!mounted) return;
      final msg = r.cancelled
          ? 'Transferência cancelada (${r.done} concluído(s)).'
          : r.failed.isEmpty
          ? '${r.done} arquivo(s) transferido(s) com sucesso.'
          : '${r.done} ok, ${r.failed.length} falha(s).';
      _snack(msg, error: r.failed.isNotEmpty);
      if (r.failed.isNotEmpty) _showErrors(r.failed);
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _transferTitle = null;
          _progress = null;
        });
      }
    }
  }

  Future<void> _uploadPaths(List<String> paths) async {
    final c = _client, s = _storage;
    if (c == null || s == null || paths.isEmpty || _busy) return;
    await _runTransfer(
      'Enviando para "$_here"',
      true,
      () => c.upload(paths, s.id, _currentParent),
    );
    await _reload(refreshStorages: true);
  }

  Future<void> _pickAndUploadFiles() async {
    final files = await openFiles();
    await _uploadPaths(files.map((f) => f.path).toList());
  }

  Future<void> _pickAndUploadFolder() async {
    final dir = await getDirectoryPath(confirmButtonText: 'Enviar pasta');
    if (dir != null) await _uploadPaths([dir]);
  }

  Future<void> _download() async {
    final c = _client;
    final items = _selectedEntries;
    if (c == null || items.isEmpty || _busy) return;
    final dir = await getDirectoryPath(confirmButtonText: 'Salvar aqui');
    if (dir == null) return;
    await _runTransfer(
      'Baixando para o Mac',
      false,
      () => c.download(items, dir),
    );
  }

  Future<void> _newFolder() async {
    final c = _client, s = _storage;
    if (c == null || s == null || _busy) return;
    final name = await _prompt('Nova pasta', 'Nome da pasta', action: 'Criar');
    if (name == null || name.isEmpty) return;
    try {
      await c.createFolder(s.id, _currentParent, name);
      await _reload();
    } catch (e) {
      _snack(e.toString(), error: true);
    }
  }

  Future<void> _rename() async {
    final c = _client;
    final items = _selectedEntries;
    if (c == null || items.length != 1 || _busy) return;
    final name = await _prompt(
      'Renomear',
      'Novo nome',
      initial: items.first.name,
      action: 'Renomear',
    );
    if (name == null || name.isEmpty || name == items.first.name) return;
    try {
      await c.rename(items.first.id, name);
      await _reload();
    } catch (e) {
      _snack(e.toString(), error: true);
    }
  }

  Future<void> _delete() async {
    final c = _client;
    final items = _selectedEntries;
    if (c == null || items.isEmpty || _busy) return;
    final cs = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_outline_rounded, color: cs.error),
        title: Text(
          items.length == 1
              ? 'Apagar "${items.first.name}"?'
              : 'Apagar ${items.length} itens?',
        ),
        content: Text(
          items.any((e) => e.isFolder)
              ? 'As pastas são apagadas com todo o conteúdo. Isso não pode ser desfeito.'
              : 'Os arquivos são apagados do Switch. Isso não pode ser desfeito.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _loading = true);
    try {
      await c.delete(items);
    } catch (e) {
      _snack(e.toString(), error: true);
    }
    await _reload(refreshStorages: true);
  }

  // ------------------------------------------------------------- seleção

  void _select(int index, {bool toggle = false, bool range = false}) {
    final view = _view;
    if (index < 0 || index >= view.length) return;
    final id = view[index].id;
    setState(() {
      if (range && _anchorIndex != null) {
        final a = _anchorIndex!.clamp(0, view.length - 1), b = index;
        if (!toggle) _selected.clear();
        for (var i = a < b ? a : b; i <= (a < b ? b : a); i++) {
          _selected.add(view[i].id);
        }
        return;
      }
      if (toggle) {
        _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
      } else {
        _selected
          ..clear()
          ..add(id);
      }
      _anchorIndex = index;
    });
  }

  void _onRowTap(int index) {
    final keys = HardwareKeyboard.instance;
    _listFocus.requestFocus();
    _select(index, toggle: keys.isMetaPressed, range: keys.isShiftPressed);
  }

  void _selectAll() => setState(() => _selected.addAll(_view.map((e) => e.id)));
  void _clearSelection() => setState(_selected.clear);

  void _moveSelection(int delta) {
    final view = _view;
    if (view.isEmpty) return;
    final current = _anchorIndex ?? (delta > 0 ? -1 : view.length);
    _select(
      (current + delta).clamp(0, view.length - 1),
      range: HardwareKeyboard.instance.isShiftPressed,
    );
  }

  void _openSelected() {
    final sel = _selectedEntries;
    if (sel.length == 1 && sel.first.isFolder) _openFolder(sel.first);
  }

  Future<void> _showContextMenu(MtpEntry e, Offset position) async {
    if (_busy) return;
    if (!_selected.contains(e.id)) {
      final i = _view.indexWhere((x) => x.id == e.id);
      _select(i);
    }
    final count = _selected.length;
    final cs = Theme.of(context).colorScheme;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        if (count == 1 && e.isFolder)
          const PopupMenuItem(
            value: 'open',
            child: _MenuRow(Icons.folder_open_rounded, 'Abrir'),
          ),
        PopupMenuItem(
          value: 'download',
          child: _MenuRow(
            Icons.download_rounded,
            count == 1 ? 'Baixar para o Mac' : 'Baixar $count itens',
          ),
        ),
        if (count == 1)
          const PopupMenuItem(
            value: 'rename',
            child: _MenuRow(Icons.edit_rounded, 'Renomear'),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: _MenuRow(
            Icons.delete_outline_rounded,
            count == 1 ? 'Apagar' : 'Apagar $count itens',
            color: cs.error,
          ),
        ),
      ],
    );
    switch (choice) {
      case 'open':
        _openFolder(e);
      case 'download':
        _download();
      case 'rename':
        _rename();
      case 'delete':
        _delete();
    }
  }

  // --------------------------------------------------------------- helpers

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: error ? cs.onError : Colors.greenAccent.shade100,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: error ? cs.error : null,
      ),
    );
  }

  void _showErrors(List<String> errors) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Falhas na transferência'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: SelectableText(errors.join('\n\n')),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<String?> _prompt(
    String title,
    String label, {
    String initial = '',
    String action = 'OK',
  }) {
    final ctrl = TextEditingController(text: initial)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: initial.contains('.')
            ? initial.lastIndexOf('.')
            : initial.length,
      );
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 380,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(hintText: label),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final device = _device;
    if (device == null) {
      return Scaffold(
        body: WelcomeView(
          ready: _client != null,
          connecting: _connecting,
          error: _error,
          onConnect: _connect,
        ),
      );
    }
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 250,
            child: Sidebar(
              device: device,
              current: _storage,
              busy: _busy,
              onSelectStorage: _selectStorage,
              onDisconnect: _disconnect,
            ),
          ),
          VerticalDivider(width: 1, color: cs.outlineVariant),
          Expanded(child: _buildMain(context)),
        ],
      ),
    );
  }

  Widget _buildMain(BuildContext context) {
    final view = _view;
    final sel = _selectedEntries;
    final enabled = !_busy && _storage != null;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyA, meta: true): _selectAll,
        const SingleActivator(LogicalKeyboardKey.escape): _clearSelection,
        const SingleActivator(LogicalKeyboardKey.arrowUp, meta: true): _goUp,
        const SingleActivator(LogicalKeyboardKey.arrowDown, meta: true):
            _openSelected,
        const SingleActivator(LogicalKeyboardKey.enter): _openSelected,
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _moveSelection(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _moveSelection(-1),
        const SingleActivator(LogicalKeyboardKey.arrowDown, shift: true): () =>
            _moveSelection(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp, shift: true): () =>
            _moveSelection(-1),
        const SingleActivator(LogicalKeyboardKey.backspace, meta: true):
            _delete,
        const SingleActivator(LogicalKeyboardKey.delete): _delete,
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () =>
            _reload(refreshStorages: true),
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true, shift: true):
            _newFolder,
        const SingleActivator(LogicalKeyboardKey.keyO, meta: true):
            _pickAndUploadFiles,
      },
      child: Focus(
        focusNode: _listFocus,
        autofocus: true,
        child: Stack(
          children: [
            Column(
              children: [
                BrowserToolbar(
                  storageName: _storage?.description ?? '',
                  path: [for (final c in _path) c.name],
                  canGoUp: _path.isNotEmpty && !_busy,
                  enabled: enabled,
                  loading: _loading,
                  search: _search,
                  onSearchChanged: () => setState(() {}),
                  onGoUp: _goUp,
                  onGoTo: _goTo,
                  onRefresh: () => _reload(refreshStorages: true),
                  onNewFolder: _newFolder,
                  onUploadFiles: _pickAndUploadFiles,
                  onUploadFolder: _pickAndUploadFolder,
                ),
                if (_error != null)
                  _ErrorStrip(
                    message: _error!,
                    onClose: () => setState(() => _error = null),
                  ),
                SelectionBar(
                  selected: sel,
                  enabled: enabled,
                  onDownload: _download,
                  onRename: _rename,
                  onDelete: _delete,
                  onClear: _clearSelection,
                ),
                Expanded(
                  child: DropTarget(
                    enable: enabled,
                    onDragEntered: (_) => setState(() => _dragging = true),
                    onDragExited: (_) => setState(() => _dragging = false),
                    onDragDone: (d) {
                      setState(() => _dragging = false);
                      _uploadPaths(d.files.map((f) => f.path).toList());
                    },
                    child: Stack(
                      children: [
                        FileList(
                          entries: view,
                          selected: _selected,
                          sortBy: _sortBy,
                          ascending: _ascending,
                          loading: _loading,
                          filtering: _search.text.trim().isNotEmpty,
                          onSort: _sort,
                          onTap: _onRowTap,
                          onOpen: _openFolder,
                          onContextMenu: _showContextMenu,
                          onBackgroundTap: _clearSelection,
                        ),
                        if (_loading)
                          const Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                        if (_dragging)
                          Positioned.fill(child: DropOverlay(target: _here)),
                      ],
                    ),
                  ),
                ),
                _StatusBar(
                  entries: _entries,
                  shown: view.length,
                  storage: _storage,
                ),
              ],
            ),
            if (_busy)
              Positioned(
                right: 16,
                bottom: 40,
                width: 380,
                child: TransferCard(
                  title: _transferTitle!,
                  uploading: _uploading,
                  progress: _progress,
                  speed: _speed,
                  onCancel: () => _client?.cancelTransfer(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label, {this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(color: color)),
    ],
  );
}

class _ErrorStrip extends StatelessWidget {
  const _ErrorStrip({required this.message, required this.onClose});
  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: cs.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              message,
              style: TextStyle(color: cs.onErrorContainer),
            ),
          ),
          IconButton(
            tooltip: 'Fechar',
            onPressed: onClose,
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: cs.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.entries,
    required this.shown,
    required this.storage,
  });
  final List<MtpEntry> entries;
  final int shown;
  final MtpStorage? storage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final folders = entries.where((e) => e.isFolder).length;
    final files = entries.length - folders;
    final size = entries
        .where((e) => !e.isFolder)
        .fold<int>(0, (s, e) => s + e.size);
    final style = TextStyle(fontSize: 12, color: cs.onSurfaceVariant);
    final s = storage;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final roomy = c.maxWidth > 640;
          return Row(
            children: [
              Flexible(
                child: Text(
                  [
                    if (shown != entries.length)
                      '$shown de ${entries.length} itens',
                    if (shown == entries.length) '${entries.length} itens',
                    if (folders > 0) '$folders pasta${folders == 1 ? '' : 's'}',
                    if (files > 0)
                      '$files arquivo${files == 1 ? '' : 's'} · ${formatBytes(size)}',
                  ].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
              const Spacer(),
              if (roomy) ...[
                Icon(
                  Icons.upload_rounded,
                  size: 14,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Arraste do Finder para enviar',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
              ],
              if (s != null && s.maxCapacity > 0) ...[
                const SizedBox(width: 16),
                Text('${formatBytes(s.freeBytes)} livres', style: style),
              ],
            ],
          );
        },
      ),
    );
  }
}
