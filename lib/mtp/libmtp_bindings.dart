// Bindings FFI mínimos para a libmtp (https://github.com/libmtp/libmtp).
// Os layouts das structs seguem /opt/homebrew/include/libmtp.h (v1.1.x).
import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as p;

const int kFilesAndFoldersRoot = 0xFFFFFFFF;
const int kFiletypeFolder = 0;
const int kFiletypeUnknown = 44;

final class DeviceEntry extends Struct {
  external Pointer<Utf8Char> vendor;
  @Uint16()
  external int vendorId;
  external Pointer<Utf8Char> product;
  @Uint16()
  external int productId;
  @Uint32()
  external int deviceFlags;
}

final class RawDevice extends Struct {
  external DeviceEntry deviceEntry;
  @Uint32()
  external int busLocation;
  @Uint8()
  external int devnum;
}

final class DeviceStorage extends Struct {
  @Uint32()
  external int id;
  @Uint16()
  external int storageType;
  @Uint16()
  external int filesystemType;
  @Uint16()
  external int accessCapability;
  @Uint64()
  external int maxCapacity;
  @Uint64()
  external int freeSpaceInBytes;
  @Uint64()
  external int freeSpaceInObjects;
  external Pointer<Utf8Char> storageDescription;
  external Pointer<Utf8Char> volumeIdentifier;
  external Pointer<DeviceStorage> next;
  external Pointer<DeviceStorage> prev;
}

/// Apenas o prefixo da struct que precisamos (até `storage`).
final class MtpDevice extends Struct {
  @Uint8()
  external int objectBitsize;
  external Pointer<Void> params;
  external Pointer<Void> usbinfo;
  external Pointer<DeviceStorage> storage;
}

final class MtpFile extends Struct {
  @Uint32()
  external int itemId;
  @Uint32()
  external int parentId;
  @Uint32()
  external int storageId;
  external Pointer<Utf8Char> filename;
  @Uint64()
  external int filesize;
  @Int64()
  external int modificationdate; // time_t
  @Int32()
  external int filetype;
  external Pointer<MtpFile> next;
}

final class MtpError extends Struct {
  @Int32()
  external int errornumber;
  external Pointer<Utf8Char> errorText;
  external Pointer<MtpError> next;
}

/// char* como UTF-8 (evita depender de Char, que varia por plataforma).
typedef Utf8Char = Uint8;

typedef ProgressNative = Int32 Function(
    Uint64 sent, Uint64 total, Pointer<Void> data);
typedef ProgressFunc = Pointer<NativeFunction<ProgressNative>>;

class LibMtp {
  LibMtp._(this._lib);
  final DynamicLibrary _lib;

  static LibMtp open() {
    final candidates = <String>[
      // Bundled dentro do .app (ver scripts/bundle_libmtp.sh)
      p.join(p.dirname(Platform.resolvedExecutable), '..', 'Frameworks',
          'libmtp.9.dylib'),
      '/opt/homebrew/lib/libmtp.9.dylib',
      '/opt/homebrew/opt/libmtp/lib/libmtp.9.dylib',
      '/usr/local/lib/libmtp.9.dylib',
      '/usr/local/opt/libmtp/lib/libmtp.9.dylib',
      'libmtp.9.dylib',
    ];
    final errors = <String>[];
    for (final path in candidates) {
      if (path.contains('/') && !File(path).existsSync()) continue;
      try {
        return LibMtp._(DynamicLibrary.open(path));
      } catch (e) {
        errors.add('$path: $e');
      }
    }
    throw StateError(
        'libmtp não encontrada. Instale com "brew install libmtp".\n${errors.join('\n')}');
  }

  late final init = _lib.lookupFunction<Void Function(), void Function()>(
      'LIBMTP_Init');

  late final detectRawDevices = _lib.lookupFunction<
      Int32 Function(Pointer<Pointer<RawDevice>>, Pointer<Int32>),
      int Function(
          Pointer<Pointer<RawDevice>>, Pointer<Int32>)>('LIBMTP_Detect_Raw_Devices');

  late final openRawDeviceUncached = _lib.lookupFunction<
      Pointer<MtpDevice> Function(Pointer<RawDevice>),
      Pointer<MtpDevice> Function(
          Pointer<RawDevice>)>('LIBMTP_Open_Raw_Device_Uncached');

  late final releaseDevice = _lib.lookupFunction<
      Void Function(Pointer<MtpDevice>),
      void Function(Pointer<MtpDevice>)>('LIBMTP_Release_Device');

  late final getFriendlyname = _lib.lookupFunction<
      Pointer<Utf8Char> Function(Pointer<MtpDevice>),
      Pointer<Utf8Char> Function(Pointer<MtpDevice>)>('LIBMTP_Get_Friendlyname');

  late final getModelname = _lib.lookupFunction<
      Pointer<Utf8Char> Function(Pointer<MtpDevice>),
      Pointer<Utf8Char> Function(Pointer<MtpDevice>)>('LIBMTP_Get_Modelname');

  late final getStorage = _lib.lookupFunction<
      Int32 Function(Pointer<MtpDevice>, Int32),
      int Function(Pointer<MtpDevice>, int)>('LIBMTP_Get_Storage');

  late final getFilesAndFolders = _lib.lookupFunction<
      Pointer<MtpFile> Function(Pointer<MtpDevice>, Uint32, Uint32),
      Pointer<MtpFile> Function(
          Pointer<MtpDevice>, int, int)>('LIBMTP_Get_Files_And_Folders');

  late final getFilemetadata = _lib.lookupFunction<
      Pointer<MtpFile> Function(Pointer<MtpDevice>, Uint32),
      Pointer<MtpFile> Function(
          Pointer<MtpDevice>, int)>('LIBMTP_Get_Filemetadata');

  late final newFile = _lib.lookupFunction<Pointer<MtpFile> Function(),
      Pointer<MtpFile> Function()>('LIBMTP_new_file_t');

  late final destroyFile = _lib.lookupFunction<Void Function(Pointer<MtpFile>),
      void Function(Pointer<MtpFile>)>('LIBMTP_destroy_file_t');

  late final getFileToFile = _lib.lookupFunction<
      Int32 Function(
          Pointer<MtpDevice>, Uint32, Pointer<Utf8Char>, ProgressFunc, Pointer<Void>),
      int Function(Pointer<MtpDevice>, int, Pointer<Utf8Char>, ProgressFunc,
          Pointer<Void>)>('LIBMTP_Get_File_To_File');

  late final sendFileFromFile = _lib.lookupFunction<
      Int32 Function(Pointer<MtpDevice>, Pointer<Utf8Char>, Pointer<MtpFile>,
          ProgressFunc, Pointer<Void>),
      int Function(Pointer<MtpDevice>, Pointer<Utf8Char>, Pointer<MtpFile>,
          ProgressFunc, Pointer<Void>)>('LIBMTP_Send_File_From_File');

  late final createFolder = _lib.lookupFunction<
      Uint32 Function(Pointer<MtpDevice>, Pointer<Utf8Char>, Uint32, Uint32),
      int Function(
          Pointer<MtpDevice>, Pointer<Utf8Char>, int, int)>('LIBMTP_Create_Folder');

  late final deleteObject = _lib.lookupFunction<
      Int32 Function(Pointer<MtpDevice>, Uint32),
      int Function(Pointer<MtpDevice>, int)>('LIBMTP_Delete_Object');

  late final setFileName = _lib.lookupFunction<
      Int32 Function(Pointer<MtpDevice>, Pointer<MtpFile>, Pointer<Utf8Char>),
      int Function(Pointer<MtpDevice>, Pointer<MtpFile>,
          Pointer<Utf8Char>)>('LIBMTP_Set_File_Name');

  late final getErrorstack = _lib.lookupFunction<
      Pointer<MtpError> Function(Pointer<MtpDevice>),
      Pointer<MtpError> Function(Pointer<MtpDevice>)>('LIBMTP_Get_Errorstack');

  late final clearErrorstack = _lib.lookupFunction<
      Void Function(Pointer<MtpDevice>),
      void Function(Pointer<MtpDevice>)>('LIBMTP_Clear_Errorstack');
}
