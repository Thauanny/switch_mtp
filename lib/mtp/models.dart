class MtpStorage {
  const MtpStorage({
    required this.id,
    required this.description,
    required this.maxCapacity,
    required this.freeBytes,
  });

  final int id;
  final String description;
  final int maxCapacity;
  final int freeBytes;

  factory MtpStorage.fromMap(Map m) => MtpStorage(
        id: m['id'] as int,
        description: m['description'] as String,
        maxCapacity: m['maxCapacity'] as int,
        freeBytes: m['freeBytes'] as int,
      );

  Map<String, Object> toMap() => {
        'id': id,
        'description': description,
        'maxCapacity': maxCapacity,
        'freeBytes': freeBytes,
      };
}

class MtpDeviceInfo {
  const MtpDeviceInfo({
    required this.name,
    required this.vendor,
    required this.product,
    required this.storages,
  });

  final String name;
  final String vendor;
  final String product;
  final List<MtpStorage> storages;

  factory MtpDeviceInfo.fromMap(Map m) => MtpDeviceInfo(
        name: m['name'] as String,
        vendor: m['vendor'] as String,
        product: m['product'] as String,
        storages: (m['storages'] as List)
            .map((e) => MtpStorage.fromMap(e as Map))
            .toList(),
      );
}

class MtpEntry {
  const MtpEntry({
    required this.id,
    required this.parentId,
    required this.storageId,
    required this.name,
    required this.size,
    required this.modified,
    required this.isFolder,
  });

  final int id;
  final int parentId;
  final int storageId;
  final String name;
  final int size;
  final DateTime? modified;
  final bool isFolder;

  factory MtpEntry.fromMap(Map m) => MtpEntry(
        id: m['id'] as int,
        parentId: m['parentId'] as int,
        storageId: m['storageId'] as int,
        name: m['name'] as String,
        size: m['size'] as int,
        modified: m['modified'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['modified'] as int),
        isFolder: m['isFolder'] as bool,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'parentId': parentId,
        'storageId': storageId,
        'name': name,
        'size': size,
        'modified': modified?.millisecondsSinceEpoch,
        'isFolder': isFolder,
      };
}

class TransferProgress {
  const TransferProgress({
    required this.currentFile,
    required this.fileIndex,
    required this.fileCount,
    required this.fileSent,
    required this.fileTotal,
    required this.totalSent,
    required this.totalBytes,
  });

  final String currentFile;
  final int fileIndex;
  final int fileCount;
  final int fileSent;
  final int fileTotal;
  final int totalSent;
  final int totalBytes;

  double get fraction => totalBytes <= 0 ? 0 : totalSent / totalBytes;

  factory TransferProgress.fromMap(Map m) => TransferProgress(
        currentFile: m['currentFile'] as String,
        fileIndex: m['fileIndex'] as int,
        fileCount: m['fileCount'] as int,
        fileSent: m['fileSent'] as int,
        fileTotal: m['fileTotal'] as int,
        totalSent: m['totalSent'] as int,
        totalBytes: m['totalBytes'] as int,
      );
}

class TransferResult {
  const TransferResult(
      {required this.done, required this.failed, required this.cancelled});
  final int done;
  final List<String> failed;
  final bool cancelled;

  factory TransferResult.fromMap(Map m) => TransferResult(
        done: m['done'] as int,
        failed: (m['failed'] as List).cast<String>(),
        cancelled: m['cancelled'] as bool,
      );
}
