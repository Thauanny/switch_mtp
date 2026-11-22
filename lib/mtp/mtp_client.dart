import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'models.dart';
import 'mtp_worker.dart';

/// Fachada assíncrona para o worker MTP.
class MtpClient {
  MtpClient._(this._send, this._cancelFlag);

  final SendPort _send;
  final Pointer<Int32> _cancelFlag;
  final _pending = <int, Completer<Object?>>{};
  final _progress = StreamController<TransferProgress>.broadcast();
  int _nextId = 1;

  Stream<TransferProgress> get progress => _progress.stream;

  static Future<MtpClient> start() async {
    final cancelFlag = calloc<Int32>();
    final receive = ReceivePort();
    final ready = Completer<SendPort>();
    late MtpClient client;
    receive.listen((msg) {
      if (msg is SendPort) {
        ready.complete(msg);
        return;
      }
      client._onMessage(msg as Map);
    });
    await Isolate.spawn(
        mtpWorkerMain, WorkerBoot(receive.sendPort, cancelFlag.address),
        debugName: 'mtp-worker');
    client = MtpClient._(await ready.future, cancelFlag);
    return client;
  }

  void _onMessage(Map m) {
    if (m.containsKey('progress')) {
      _progress.add(TransferProgress.fromMap(m));
      return;
    }
    final c = _pending.remove(m['id'] as int);
    if (c == null) return;
    if (m['ok'] == true) {
      c.complete(m['result']);
    } else {
      c.completeError(MtpClientException(m['error'] as String));
    }
  }

  Future<Object?> _call(String cmd, [Map<String, Object?> args = const {}]) {
    final id = _nextId++;
    final c = Completer<Object?>();
    _pending[id] = c;
    _send.send({'id': id, 'cmd': cmd, 'args': args});
    return c.future;
  }

  /// Conecta ao primeiro dispositivo MTP (prioriza o Switch).
  /// Se falhar, tenta liberar o USB do daemon de câmera do macOS e repete.
  Future<MtpDeviceInfo> connect() async {
    try {
      return MtpDeviceInfo.fromMap(await _call('connect') as Map);
    } on MtpClientException catch (e) {
      if (e.message.contains('Nenhum dispositivo MTP')) {
        throw MtpClientException(await _usbHint());
      }
      if (!e.message.contains('não foi possível abri-lo')) rethrow;
      await releaseMacUsbDaemons();
      await Future<void>.delayed(const Duration(milliseconds: 800));
      return MtpDeviceInfo.fromMap(await _call('connect') as Map);
    }
  }

  /// Explica por que nada foi encontrado, consultando o que o macOS vê no USB.
  static Future<String> _usbHint() async {
    var devices = <String>[];
    var nintendo = false;
    try {
      final r = await Process.run(
          'ioreg', ['-r', '-c', 'IOUSBHostDevice', '-l', '-w0']);
      final out = r.stdout as String;
      nintendo = RegExp(r'"idVendor" = 1406\b').hasMatch(out); // 0x057e
      devices = RegExp(r'"USB Product Name" = "([^"]*)"')
          .allMatches(out)
          .map((m) => m.group(1)!)
          .toList();
    } catch (_) {}

    if (nintendo) {
      return 'O Switch está conectado no USB, mas não respondeu como MTP.\n'
          'No DBI, abra "Run MTP responder" e mantenha essa tela aberta; '
          'depois clique em Conectar de novo.';
    }
    final seen = devices.isEmpty
        ? 'O Mac não está vendo nenhum dispositivo USB.'
        : 'O Mac vê no USB: ${devices.join(', ')} — mas não o Switch.';
    return '$seen\n'
        '• Aceite o alerta "Permitir que o acessório se conecte?" '
        '(Ajustes → Privacidade e Segurança → Permitir que acessórios se conectem).\n'
        '• Use um cabo USB-C de DADOS (muitos só carregam), direto no Mac, sem a dock.\n'
        '• No Switch, deixe o DBI na tela "Run MTP responder".';
  }

  /// O macOS (ptpcamerad / Captura de Imagem) às vezes "pega" dispositivos
  /// PTP/MTP assim que são conectados, impedindo o acesso via libusb.
  static Future<void> releaseMacUsbDaemons() async {
    try {
      await Process.run('killall', ['-9', 'ptpcamerad']);
    } catch (_) {}
  }

  Future<void> disconnect() => _call('disconnect');

  Future<List<MtpStorage>> storages() async =>
      (await _call('storages') as List)
          .map((e) => MtpStorage.fromMap(e as Map))
          .toList();

  Future<List<MtpEntry>> list(int storageId, int parentId) async =>
      (await _call('list', {'storageId': storageId, 'parentId': parentId})
              as List)
          .map((e) => MtpEntry.fromMap(e as Map))
          .toList();

  Future<int> createFolder(int storageId, int parentId, String name) async =>
      await _call('mkdir',
          {'storageId': storageId, 'parentId': parentId, 'name': name}) as int;

  Future<void> delete(List<MtpEntry> entries) =>
      _call('delete', {'entries': entries.map((e) => e.toMap()).toList()});

  Future<void> rename(int id, String name) =>
      _call('rename', {'id': id, 'name': name});

  Future<TransferResult> download(List<MtpEntry> entries, String destDir) async {
    _cancelFlag.value = 0;
    final r = await _call('download', {
      'entries': entries.map((e) => e.toMap()).toList(),
      'dest': destDir,
    });
    return TransferResult.fromMap(r as Map);
  }

  Future<TransferResult> upload(
      List<String> localPaths, int storageId, int parentId) async {
    _cancelFlag.value = 0;
    final r = await _call('upload', {
      'paths': localPaths,
      'storageId': storageId,
      'parentId': parentId,
    });
    return TransferResult.fromMap(r as Map);
  }

  /// Sinaliza cancelamento; lido pelo callback de progresso da libmtp.
  void cancelTransfer() => _cancelFlag.value = 1;
}

class MtpClientException implements Exception {
  MtpClientException(this.message);
  final String message;
  @override
  String toString() => message;
}
