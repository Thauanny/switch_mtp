// Isolate dedicado que é dono do dispositivo MTP.
// Todas as chamadas da libmtp são síncronas/bloqueantes, então rodam aqui
// para não travar a UI. Os comandos são processados em ordem.
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import 'libmtp_bindings.dart';
import 'models.dart';

class WorkerBoot {
  WorkerBoot(this.mainPort, this.cancelFlagAddress);
  final SendPort mainPort;
  final int cancelFlagAddress;
}

void mtpWorkerMain(WorkerBoot boot) {
  final port = ReceivePort();
  boot.mainPort.send(port.sendPort);
  _Worker? worker;
  String? bootError;
  try {
    worker = _Worker(
        boot.mainPort, Pointer<Int32>.fromAddress(boot.cancelFlagAddress));
  } catch (e) {
    bootError = e.toString();
  }
  port.listen((msg) {
    final m = msg as Map;
    final id = m['id'] as int;
    try {
      if (worker == null) throw MtpException(bootError ?? 'libmtp indisponível');
      final result = worker.handle(id, m['cmd'] as String, m['args'] as Map);
      boot.mainPort.send({'id': id, 'ok': true, 'result': result});
    } catch (e) {
      boot.mainPort.send({'id': id, 'ok': false, 'error': e.toString()});
    }
  });
}

class MtpException implements Exception {
  MtpException(this.message);
  final String message;
  @override
  String toString() => message;
}

const int _nintendoVendorId = 0x057e;

class _PlannedDownload {
  _PlannedDownload(this.id, this.name, this.localPath, this.size);
  final int id;
  final String name;
  final String localPath;
  final int size;
}

class _PlannedUpload {
  _PlannedUpload(this.localPath, this.name, this.size, this.parentKey);
  final String localPath;
  final String name;
  final int size;
  final String parentKey; // chave da pasta local -> id remoto
}

class _Worker {
  _Worker(this.mainPort, this.cancelFlag) {
    lib = LibMtp.open();
    lib.init();
  }

  final SendPort mainPort;
  final Pointer<Int32> cancelFlag;
  late final LibMtp lib;
  Pointer<MtpDevice> device = nullptr;

  // Contexto do progresso da transferência corrente.
  int _jobId = 0;
  String _curName = '';
  int _fileIndex = 0;
  int _fileCount = 0;
  int _bytesBefore = 0;
  int _totalBytes = 0;
  int _lastEmit = 0;

  Object? handle(int id, String cmd, Map args) {
    switch (cmd) {
      case 'connect':
        return _connect();
      case 'disconnect':
        _disconnect();
        return null;
      case 'storages':
        _requireDevice();
        return _storages();
      case 'list':
        _requireDevice();
        return _list(args['storageId'] as int, args['parentId'] as int)
            .map((e) => e.toMap())
            .toList();
      case 'mkdir':
        _requireDevice();
        return _mkdir(args['storageId'] as int, args['parentId'] as int,
            args['name'] as String);
      case 'delete':
        _requireDevice();
        for (final e in (args['entries'] as List)) {
          _deleteRecursive(MtpEntry.fromMap(e as Map));
        }
        return null;
      case 'rename':
        _requireDevice();
        _rename(args['id'] as int, args['name'] as String);
        return null;
      case 'download':
        _requireDevice();
        _jobId = id;
        return _download(
          (args['entries'] as List).map((e) => MtpEntry.fromMap(e as Map)).toList(),
          args['dest'] as String,
        );
      case 'upload':
        _requireDevice();
        _jobId = id;
        return _upload((args['paths'] as List).cast<String>(),
            args['storageId'] as int, args['parentId'] as int);
      default:
        throw MtpException('Comando desconhecido: $cmd');
    }
  }

  // ---------------------------------------------------------------- conexão

  Map<String, Object> _connect() {
    _disconnect();
    final rawPtr = calloc<Pointer<RawDevice>>();
    final countPtr = calloc<Int32>();
    try {
      final err = lib.detectRawDevices(rawPtr, countPtr);
      final count = countPtr.value;
      if (err != 0 || count == 0) {
        throw MtpException(
            'Nenhum dispositivo MTP encontrado (código $err).\n'
            'No Switch, abra o DBI e escolha "Run MTP responder", '
            'depois conecte o cabo USB.');
      }
      // Prefere o Switch (vendor Nintendo) se houver mais de um dispositivo.
      var index = 0;
      for (var i = 0; i < count; i++) {
        if ((rawPtr.value + i).ref.deviceEntry.vendorId == _nintendoVendorId) {
          index = i;
          break;
        }
      }
      final raw = rawPtr.value + index;
      final vendor = _str(raw.ref.deviceEntry.vendor,
          fallback: 'VID ${raw.ref.deviceEntry.vendorId.toRadixString(16)}');
      final product = _str(raw.ref.deviceEntry.product,
          fallback: 'PID ${raw.ref.deviceEntry.productId.toRadixString(16)}');

      final dev = lib.openRawDeviceUncached(raw);
      malloc.free(rawPtr.value);
      if (dev == nullptr) {
        throw MtpException(
            'Dispositivo encontrado, mas não foi possível abri-lo. '
            'Outro app (Android File Transfer, OpenMTP, Captura de Imagem) '
            'pode estar usando o USB.');
      }
      device = dev;

      final namePtr = lib.getFriendlyname(dev);
      var name = _str(namePtr);
      if (namePtr != nullptr) malloc.free(namePtr);
      if (name.isEmpty) {
        final modelPtr = lib.getModelname(dev);
        name = _str(modelPtr, fallback: product);
        if (modelPtr != nullptr) malloc.free(modelPtr);
      }
      return {
        'name': name,
        'vendor': vendor,
        'product': product,
        'storages': _storages(),
      };
    } finally {
      calloc.free(rawPtr);
      calloc.free(countPtr);
    }
  }

  void _disconnect() {
    if (device != nullptr) {
      lib.releaseDevice(device);
      device = nullptr;
    }
  }

  void _requireDevice() {
    if (device == nullptr) throw MtpException('Nenhum dispositivo conectado.');
  }

  List<Map<String, Object>> _storages() {
    if (lib.getStorage(device, 0) != 0) {
      throw MtpException('Falha ao ler armazenamentos: ${_errors()}');
    }
    final list = <Map<String, Object>>[];
    var s = device.ref.storage;
    while (s != nullptr) {
      list.add(MtpStorage(
        id: s.ref.id,
        description: _str(s.ref.storageDescription,
            fallback: _str(s.ref.volumeIdentifier,
                fallback: 'Storage 0x${s.ref.id.toRadixString(16)}')),
        maxCapacity: s.ref.maxCapacity,
        freeBytes: s.ref.freeSpaceInBytes,
      ).toMap());
      s = s.ref.next;
    }
    return list;
  }

  // ---------------------------------------------------------------- arquivos

  List<MtpEntry> _list(int storageId, int parentId) {
    lib.clearErrorstack(device);
    final head = lib.getFilesAndFolders(device, storageId, parentId);
    final out = <MtpEntry>[];
    var f = head;
    while (f != nullptr) {
      final next = f.ref.next;
      final mod = f.ref.modificationdate;
      out.add(MtpEntry(
        id: f.ref.itemId,
        parentId: f.ref.parentId,
        storageId: f.ref.storageId,
        name: _str(f.ref.filename, fallback: '(sem nome)'),
        size: f.ref.filesize,
        modified: mod > 0 ? DateTime.fromMillisecondsSinceEpoch(mod * 1000) : null,
        isFolder: f.ref.filetype == kFiletypeFolder,
      ));
      lib.destroyFile(f);
      f = next;
    }
    if (head == nullptr) {
      final err = _errors();
      if (err.isNotEmpty) throw MtpException('Falha ao listar: $err');
    }
    out.sort((a, b) {
      if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return out;
  }

  int _mkdir(int storageId, int parentId, String name) {
    lib.clearErrorstack(device);
    final cName = name.toNativeUtf8().cast<Uint8>();
    try {
      final id = lib.createFolder(device, cName, parentId, storageId);
      if (id == 0) {
        throw MtpException('Falha ao criar pasta "$name": ${_errors()}');
      }
      return id;
    } finally {
      malloc.free(cName);
    }
  }

  void _deleteRecursive(MtpEntry e) {
    if (e.isFolder) {
      for (final child in _list(e.storageId, e.id)) {
        _deleteRecursive(child);
      }
    }
    lib.clearErrorstack(device);
    if (lib.deleteObject(device, e.id) != 0) {
      throw MtpException('Falha ao apagar "${e.name}": ${_errors()}');
    }
  }

  void _rename(int id, String newName) {
    lib.clearErrorstack(device);
    final meta = lib.getFilemetadata(device, id);
    if (meta == nullptr) throw MtpException('Objeto não encontrado.');
    final cName = newName.toNativeUtf8().cast<Uint8>();
    try {
      if (lib.setFileName(device, meta, cName) != 0) {
        throw MtpException('Falha ao renomear: ${_errors()}');
      }
    } finally {
      malloc.free(cName);
      lib.destroyFile(meta);
    }
  }

  // ------------------------------------------------------------ transferências

  int _onProgress(int sent, int total, Pointer<Void> _) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastEmit >= 100 || sent >= total) {
      _lastEmit = now;
      mainPort.send({
        'progress': _jobId,
        'currentFile': _curName,
        'fileIndex': _fileIndex,
        'fileCount': _fileCount,
        'fileSent': sent,
        'fileTotal': total,
        'totalSent': _bytesBefore + sent,
        'totalBytes': _totalBytes,
      });
    }
    return cancelFlag.value != 0 ? 1 : 0;
  }

  bool get _cancelled => cancelFlag.value != 0;

  Map<String, Object> _download(List<MtpEntry> entries, String dest) {
    // 1) Planeja: expande pastas e calcula o total.
    final plan = <_PlannedDownload>[];
    void walk(MtpEntry e, String localDir) {
      if (_cancelled) return;
      final target = p.join(localDir, _safeLocalName(e.name));
      if (e.isFolder) {
        Directory(target).createSync(recursive: true);
        for (final c in _list(e.storageId, e.id)) {
          walk(c, target);
        }
      } else {
        plan.add(_PlannedDownload(e.id, e.name, target, e.size));
      }
    }

    for (final e in entries) {
      walk(e, dest);
    }

    // 2) Executa.
    _fileCount = plan.length;
    _totalBytes = plan.fold(0, (a, b) => a + b.size);
    _bytesBefore = 0;
    final failed = <String>[];
    var done = 0;
    final callback = NativeCallable<ProgressNative>.isolateLocal(_onProgress,
        exceptionalReturn: 1);
    try {
      for (var i = 0; i < plan.length && !_cancelled; i++) {
        final item = plan[i];
        _curName = item.name;
        _fileIndex = i + 1;
        _lastEmit = 0;
        lib.clearErrorstack(device);
        final cPath = item.localPath.toNativeUtf8().cast<Uint8>();
        final rc = lib.getFileToFile(
            device, item.id, cPath, callback.nativeFunction, nullptr);
        malloc.free(cPath);
        if (rc != 0) {
          try {
            File(item.localPath).deleteSync();
          } catch (_) {}
          if (!_cancelled) failed.add('${item.name}: ${_errors()}');
        } else {
          done++;
        }
        _bytesBefore += item.size;
      }
    } finally {
      callback.close();
    }
    return {'done': done, 'failed': failed, 'cancelled': _cancelled};
  }

  Map<String, Object> _upload(List<String> paths, int storageId, int parentId) {
    // 1) Planeja: percorre pastas locais.
    final plan = <_PlannedUpload>[];
    final folders = <String, ({String name, String parentKey})>{};
    const rootKey = '';

    void walk(FileSystemEntity ent, String parentKey) {
      final name = p.basename(ent.path);
      if (name == '.DS_Store' || name.startsWith('._')) return;
      if (ent is Directory) {
        final key = ent.absolute.path;
        folders[key] = (name: name, parentKey: parentKey);
        final children = ent.listSync(followLinks: false)
          ..sort((a, b) => a.path.compareTo(b.path));
        for (final c in children) {
          walk(c, key);
        }
      } else if (ent is File) {
        plan.add(_PlannedUpload(ent.path, name, ent.lengthSync(), parentKey));
      }
    }

    for (final path in paths) {
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.directory) {
        walk(Directory(path), rootKey);
      } else if (type == FileSystemEntityType.file) {
        walk(File(path), rootKey);
      }
    }

    // 2) Cria pastas remotas sob demanda (reaproveitando as existentes).
    final remoteIds = <String, int>{rootKey: parentId};
    int ensureFolder(String key) {
      final cached = remoteIds[key];
      if (cached != null) return cached;
      final info = folders[key]!;
      final parent = ensureFolder(info.parentKey);
      final existing = _list(storageId, parent)
          .where((e) => e.isFolder && e.name == info.name)
          .firstOrNull;
      final id = existing?.id ?? _mkdir(storageId, parent, info.name);
      remoteIds[key] = id;
      return id;
    }

    // Pastas vazias também devem existir no destino.
    for (final key in folders.keys) {
      if (_cancelled) break;
      ensureFolder(key);
    }

    // 3) Envia arquivos.
    _fileCount = plan.length;
    _totalBytes = plan.fold(0, (a, b) => a + b.size);
    _bytesBefore = 0;
    final failed = <String>[];
    var done = 0;
    final callback = NativeCallable<ProgressNative>.isolateLocal(_onProgress,
        exceptionalReturn: 1);
    try {
      for (var i = 0; i < plan.length && !_cancelled; i++) {
        final item = plan[i];
        _curName = item.name;
        _fileIndex = i + 1;
        _lastEmit = 0;
        lib.clearErrorstack(device);
        final remoteParent = ensureFolder(item.parentKey);
        final meta = lib.newFile();
        // filename é liberado pelo LIBMTP_destroy_file_t (free), por isso malloc.
        meta.ref.filename = item.name.toNativeUtf8(allocator: malloc).cast();
        meta.ref.filesize = item.size;
        meta.ref.parentId = remoteParent;
        meta.ref.storageId = storageId;
        meta.ref.filetype = kFiletypeUnknown;
        final cPath = item.localPath.toNativeUtf8().cast<Uint8>();
        final rc = lib.sendFileFromFile(
            device, cPath, meta, callback.nativeFunction, nullptr);
        malloc.free(cPath);
        lib.destroyFile(meta);
        if (rc != 0) {
          if (!_cancelled) failed.add('${item.name}: ${_errors()}');
        } else {
          done++;
        }
        _bytesBefore += item.size;
      }
    } finally {
      callback.close();
    }
    return {'done': done, 'failed': failed, 'cancelled': _cancelled};
  }

  // ------------------------------------------------------------------ helpers

  String _errors() {
    if (device == nullptr) return '';
    final parts = <String>[];
    var e = lib.getErrorstack(device);
    while (e != nullptr) {
      final t = _str(e.ref.errorText);
      if (t.isNotEmpty) parts.add(t);
      e = e.ref.next;
    }
    lib.clearErrorstack(device);
    return parts.isEmpty ? 'erro desconhecido' : parts.join('; ');
  }

  static String _str(Pointer<Uint8> ptr, {String fallback = ''}) {
    if (ptr == nullptr) return fallback;
    try {
      return ptr.cast<Utf8>().toDartString();
    } catch (_) {
      return fallback;
    }
  }

  static String _safeLocalName(String name) =>
      name.replaceAll('/', '_').replaceAll(':', '_');
}
