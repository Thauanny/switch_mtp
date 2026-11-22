// ignore_for_file: avoid_print
// Diagnóstico via terminal: dart run tool/diagnose.dart
// Verifica se a libmtp carrega, os layouts das structs e lista dispositivos.
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:switch_mtp/mtp/libmtp_bindings.dart';

void main() {
  print('sizeof RawDevice=${sizeOf<RawDevice>()} MtpFile=${sizeOf<MtpFile>()} '
      'DeviceStorage=${sizeOf<DeviceStorage>()}');
  final lib = LibMtp.open();
  lib.init();
  final raw = calloc<Pointer<RawDevice>>();
  final n = calloc<Int32>();
  final rc = lib.detectRawDevices(raw, n);
  print('LIBMTP_Detect_Raw_Devices -> código $rc, ${n.value} dispositivo(s)');
  for (var i = 0; i < n.value; i++) {
    final d = (raw.value + i).ref.deviceEntry;
    print('  [$i] VID=0x${d.vendorId.toRadixString(16)} '
        'PID=0x${d.productId.toRadixString(16)}');
  }
}
