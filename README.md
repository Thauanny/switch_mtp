# Switch MTP

App desktop (Flutter, macOS) para transferir arquivos entre o Mac e um Nintendo
Switch desbloqueado rodando o **MTP responder do DBI**.

O macOS não tem suporte nativo a MTP; o app usa a [libmtp](https://github.com/libmtp/libmtp)
(via `dart:ffi`) num isolate separado, então a interface não trava durante as transferências.

## Uso

1. No Switch: abra o **DBI** → **Run MTP responder**.
2. Conecte o cabo USB-C (de dados) ao Mac.
3. Abra o app → **Conectar**.
4. Escolha o armazenamento na barra lateral (ex.: `SD Card`, ou `SD Card install` para instalar NSP/NSZ/XCI direto).
5. Envie arquivos ou pastas pelo botão **Enviar** ou **arrastando do Finder**.
6. Selecione itens (⌘/⇧ para seleção múltipla, clique direito para o menu) e use
   **Baixar para o Mac**, **Renomear** ou **Apagar** na faixa que aparece em cima da lista.

Atalhos: ⌘A seleciona tudo · Esc limpa a seleção · Enter ou ⌘↓ abre a pasta · ⌘↑ volta ·
⌘⌫ apaga · ⌘R atualiza · ⇧⌘N nova pasta · ⌘O envia arquivos.

Feche OpenMTP / Android File Transfer antes: só um app por vez pode usar o dispositivo.
Se a abertura falhar, o app encerra automaticamente o `ptpcamerad` do macOS
(que às vezes "captura" dispositivos MTP) e tenta de novo.

## Desenvolvimento

```bash
brew install libmtp
flutter run -d macos
dart run tool/diagnose.dart     # testa a libmtp e lista dispositivos no terminal
```

## Build distribuível

```bash
./scripts/build_release.sh
# -> build/macos/Build/Products/Release/Switch MTP.app (libmtp/libusb embutidas)
```

O app roda **sem App Sandbox** (necessário para acesso USB direto via libusb).

## Estrutura

- `lib/mtp/libmtp_bindings.dart` — bindings FFI da libmtp
- `lib/mtp/mtp_worker.dart` — isolate dono do dispositivo (listar, enviar, baixar, criar, renomear, apagar)
- `lib/mtp/mtp_client.dart` — API assíncrona + progresso + cancelamento
- `lib/ui/browser_page.dart` — tela principal (estado e ações)
- `lib/ui/widgets/` — barra lateral, barra de ferramentas, lista de arquivos, cartão de transferência e tela inicial
- `lib/ui/theme.dart` — tema claro/escuro e ícones por tipo de arquivo
