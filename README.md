# Switch MTP

**Transfira arquivos entre o Mac e o Nintendo Switch pelo cabo USB, sem complicação.**

Switch MTP é um app para macOS que conversa com o **MTP responder do DBI** no Switch.
O macOS não tem suporte a MTP; o app traz a [libmtp](https://github.com/libmtp/libmtp) embutida
e oferece uma interface no estilo do Finder para enviar jogos, homebrew, saves e capturas, ou
instalar NSP/NSZ/XCI direto pelo DBI.

![Plataforma](https://img.shields.io/badge/macOS-15%2B-lightgrey?logo=apple)
![Mac](https://img.shields.io/badge/Mac-chip%20Apple%20%7C%20Intel-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.38-02569B?logo=flutter)

---

## Sumário

- [Recursos](#recursos)
- [Download e instalação](#download-e-instalação)
- [Como usar](#como-usar)
- [Atalhos de teclado](#atalhos-de-teclado)
- [Solução de problemas](#solução-de-problemas)
- [Desenvolvimento](#desenvolvimento)
- [Publicar uma versão](#publicar-uma-versão)
- [Arquitetura](#arquitetura)
- [Aviso legal](#aviso-legal)

## Recursos

- **Todos os armazenamentos do DBI** na barra lateral, com o espaço livre de cada um: SD Card,
  NAND, "SD Card install" e "NAND install" (instalam NSP/NSZ/XCI ao enviar), saves e outros.
- **Enviar arquivos e pastas inteiras**, pelo botão **Enviar** ou **arrastando do Finder**.
- **Baixar para o Mac** vários itens de uma vez, inclusive pastas com todo o conteúdo.
- **Organizar o cartão:** criar pastas, renomear e apagar (com confirmação).
- **Lista no estilo do Finder:** colunas ordenáveis (nome, tipo, tamanho, data), busca na pasta,
  ícones por tipo de arquivo e menu de clique direito.
- **Transferências acompanhadas:** arquivo atual, progresso total, velocidade e tempo restante,
  com cancelar a qualquer momento.
- **Interface que não trava:** o trabalho com o USB roda numa thread separada.
- **Tema claro e escuro**, acompanhando o macOS.

## Download e instalação

**Requisitos:** macOS 15 (Sequoia) ou mais novo, Mac com chip Apple ou Intel, e um Switch com o
[DBI](https://github.com/rashevskyv/dbi).

1. Na página de [**Releases**](../../releases/latest), baixe o `.dmg` do seu Mac:

   | Seu Mac | Arquivo |
   |---|---|
   | Chip Apple (M1, M2, M3, M4…) | `Switch-MTP-<versão>-apple-silicon.dmg` |
   | Intel | `Switch-MTP-<versão>-intel.dmg` |

   Para saber qual é o seu: menu  › **Sobre este Mac** mostra "Chip" (Apple) ou "Processador" (Intel).

2. Abra o `.dmg` e arraste **Switch MTP** para a pasta **Aplicativos**.

3. **Primeira abertura.** O app não é assinado com um certificado de desenvolvedor da Apple, então
   o macOS o bloqueia na primeira vez:
   1. abra o app uma vez; o aviso aparece e você fecha;
   2. vá em **Ajustes do Sistema › Privacidade e Segurança**, role até o aviso sobre o
      Switch MTP e clique em **Abrir Mesmo Assim**.

   Ou, pelo Terminal:

   ```bash
   xattr -dr com.apple.quarantine "/Applications/Switch MTP.app"
   ```

Não é preciso instalar Homebrew nem libmtp: as bibliotecas vão dentro do app.

## Como usar

1. No Switch, abra o **DBI** (pelo menu Homebrew) e escolha **Run MTP responder**.
2. Ligue o Switch ao Mac com um **cabo USB-C de dados**, direto no Mac (sem a dock).
3. Abra o Switch MTP e clique em **Conectar**.
4. Escolha o armazenamento na barra lateral e navegue pelas pastas (clique duplo abre).
5. Para enviar, use **Enviar** ou arraste arquivos e pastas do Finder para a lista.
6. Para baixar, renomear ou apagar, selecione os itens (⌘ e ⇧ para vários). As ações aparecem
   numa faixa acima da lista e no clique direito.

> Para **instalar jogos**, envie os NSP/NSZ/XCI para **SD Card install** ou **NAND install**.

## Atalhos de teclado

| Atalho | Ação |
|---|---|
| ⌘A | Selecionar tudo |
| Esc | Limpar a seleção |
| ↑ / ↓ (com ⇧ para estender) | Mover a seleção |
| Enter ou ⌘↓ | Abrir a pasta |
| ⌘↑ | Voltar à pasta de cima |
| ⌘O | Enviar arquivos |
| ⇧⌘N | Nova pasta |
| ⌘R | Atualizar |
| ⌘⌫ | Apagar |

## Solução de problemas

**O Switch não aparece ("nenhum dispositivo MTP")**
- Deixe o DBI na tela **Run MTP responder** enquanto usa o app.
- Use um cabo **de dados** (muitos cabos USB-C só carregam), ligado direto no Mac.
- Aceite o alerta **"Permitir que o acessório se conecte?"** do macOS
  (também em Ajustes do Sistema › Privacidade e Segurança).

**"O dispositivo foi encontrado, mas não foi possível abri-lo"**
- Feche o OpenMTP, o Android File Transfer e outros apps MTP: só um app por vez pode usar o Switch.
- O app já tenta liberar o `ptpcamerad` do macOS, que às vezes "captura" aparelhos MTP. Se
  continuar, desconecte o cabo, ligue de novo e clique em **Conectar**.

**"O app não pode ser aberto porque a Apple não pode verificá-lo"**
- Veja o passo 3 de [Download e instalação](#download-e-instalação).

**Diagnóstico pelo Terminal** (com o projeto clonado):

```bash
dart run tool/diagnose.dart   # testa a libmtp e lista os aparelhos USB/MTP
```

## Desenvolvimento

Requisitos: macOS, [Flutter](https://docs.flutter.dev/get-started/install/macos) 3.38+, Xcode e a libmtp.

```bash
brew install libmtp
flutter pub get
flutter run -d macos          # rodar em desenvolvimento
flutter test                  # testes
```

Gerar o app e o instalador localmente:

```bash
./scripts/build_release.sh    # build/macos/Build/Products/Release/Switch MTP.app (libs embutidas)
./scripts/build_dmg.sh        # dist/Switch-MTP-<versão>-<apple-silicon|intel>.dmg
./scripts/build_dmg.sh 1.2.0  # com outra versão
```

As bibliotecas embutidas vêm do Homebrew do Mac que compila. Por isso o `.dmg` gerado vale para
Macs com o **mesmo processador** e a **mesma versão do macOS (ou mais nova)** de quem o gerou. Os
`.dmg` das Releases são compilados em macOS 15.

O app roda **sem App Sandbox**, porque o acesso direto ao USB (libusb) exige isso.

## Publicar uma versão

O workflow [`.github/workflows/release.yml`](.github/workflows/release.yml) roda os testes, compila
o app em Mac com chip Apple e em Mac Intel, gera os dois `.dmg` e cria a Release no GitHub com eles.

```bash
git tag v1.2.0
git push origin v1.2.0
```

Também dá para disparar à mão em **Actions › Release › Run workflow**, informando a versão.

## Arquitetura

```
lib/
├── main.dart                   app e tema
├── mtp/
│   ├── libmtp_bindings.dart    bindings FFI da libmtp
│   ├── mtp_worker.dart         isolate dono do aparelho (listar, enviar, baixar, criar, renomear, apagar)
│   ├── mtp_client.dart         API assíncrona, progresso e cancelamento
│   └── models.dart             aparelho, armazenamentos, arquivos e progresso
└── ui/
    ├── browser_page.dart       tela principal: estado e ações
    ├── theme.dart              tema claro/escuro e ícones por tipo de arquivo
    └── widgets/                barra lateral, barra de ferramentas, lista, transferência, tela inicial
scripts/                        build do app com as libs embutidas e do .dmg
tool/diagnose.dart              diagnóstico da libmtp pelo Terminal
.github/workflows/release.yml   publicação das versões com os .dmg
```

A libmtp é carregada via `dart:ffi` num isolate próprio: a interface nunca espera o USB, e o
cancelamento é sinalizado por memória compartilhada lida no callback de progresso da libmtp.

## Aviso legal

Projeto independente, sem vínculo com a Nintendo. Nintendo Switch é marca da Nintendo. O DBI é um
projeto de terceiros. Use apenas com aparelhos e arquivos que você tem direito de usar.
