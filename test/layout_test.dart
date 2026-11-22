import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:switch_mtp/mtp/models.dart';
import 'package:switch_mtp/ui/theme.dart';
import 'package:switch_mtp/ui/widgets/file_list.dart';
import 'package:switch_mtp/ui/widgets/sidebar.dart';
import 'package:switch_mtp/ui/widgets/toolbar.dart';

const _gb = 1024 * 1024 * 1024;

/// A tela não pode estourar na janela mínima (820×520) com os 7 armazenamentos que o DBI
/// mostra e uma pasta cheia (o caso do cartão SD com 23 pastas e 13 arquivos).
void main() {
  for (final size in [const Size(820, 520), const Size(1280, 800)]) {
    testWidgets('sem estouro em ${size.width.toInt()}×${size.height.toInt()}', (
      t,
    ) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      MtpStorage st(int id, String name, int max, int free) => MtpStorage(
        id: id,
        description: '$id: $name',
        maxCapacity: max * _gb,
        freeBytes: free * _gb,
      );
      final storages = [
        st(1, 'SD Card', 477, 206),
        st(2, 'Nand USER', 55, 49),
        st(3, 'Nand SYSTEM', 2, 1),
        st(4, 'Installed games', 477, 206),
        st(5, 'SD Card install', 477, 206),
        st(6, 'NAND install', 55, 49),
        st(7, 'Saves', 0, 0),
      ];
      final device = MtpDeviceInfo(
        name: 'DBI MTP Responder',
        vendor: 'Nintendo',
        product: 'Switch / Switch Lite',
        storages: storages,
      );
      final entries = [
        for (var i = 0; i < 23; i++)
          MtpEntry(
            id: i,
            parentId: 0,
            storageId: 1,
            name: 'pasta com nome comprido número $i',
            size: 0,
            modified: null,
            isFolder: true,
          ),
        for (var i = 0; i < 13; i++)
          MtpEntry(
            id: 100 + i,
            parentId: 0,
            storageId: 1,
            name: 'arquivo_$i.nsp',
            size: 4 * _gb,
            modified: DateTime(2026),
            isFolder: false,
          ),
      ];
      final search = TextEditingController();
      await t.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: 250,
                  child: Sidebar(
                    device: device,
                    current: storages.first,
                    busy: false,
                    onSelectStorage: (_) {},
                    onDisconnect: () {},
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      BrowserToolbar(
                        storageName: '1: SD Card',
                        path: const [
                          'atmosphere',
                          'contents',
                          'uma pasta de nome bem comprido',
                        ],
                        canGoUp: true,
                        enabled: true,
                        loading: false,
                        search: search,
                        onSearchChanged: () {},
                        onGoUp: () {},
                        onGoTo: (_) {},
                        onRefresh: () {},
                        onNewFolder: () {},
                        onUploadFiles: () {},
                        onUploadFolder: () {},
                      ),
                      SelectionBar(
                        selected: entries.sublist(30, 33),
                        enabled: true,
                        onDownload: () {},
                        onRename: () {},
                        onDelete: () {},
                        onClear: () {},
                      ),
                      Expanded(
                        child: FileList(
                          entries: entries,
                          selected: const {},
                          sortBy: SortBy.name,
                          ascending: true,
                          loading: false,
                          filtering: false,
                          onSort: (_) {},
                          onTap: (_) {},
                          onOpen: (_) {},
                          onContextMenu: (_, _) {},
                          onBackgroundTap: () {},
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final err = t.takeException();
      if (err != null) debugPrint((err as FlutterError).toStringDeep());
      expect(err, isNull);
      // a pasta atual aparece inteira no caminho
      expect(find.text('uma pasta de nome bem comprido'), findsOneWidget);
    });
  }
}
