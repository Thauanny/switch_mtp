// Gera a imagem de fundo da janela do instalador .dmg (1x e 2x).
//
//   swift scripts/make_dmg_background.swift <pasta-de-saída>
//
// A janela tem 640x400 pontos. O app fica em (160, 190) e o atalho Aplicativos em (480, 190),
// medidos do canto superior esquerdo — as mesmas posições usadas em scripts/build_dmg.sh.
import AppKit

let W: CGFloat = 640, H: CGFloat = 400
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

func render(scale: CGFloat) -> Data {
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W * scale), pixelsHigh: Int(H * scale),
                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                             colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  rep.size = NSSize(width: W, height: H)
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

  // Fundo: cinza bem claro com um leve gradiente.
  let bg = NSGradient(colors: [NSColor(white: 0.985, alpha: 1), NSColor(white: 0.93, alpha: 1)])!
  bg.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)

  // Faixa vermelha fina no topo (identidade do app).
  NSColor(srgbRed: 0.90, green: 0.0, blue: 0.07, alpha: 1).setFill()
  NSRect(x: 0, y: H - 6, width: W, height: 6).fill()

  // Título.
  let para = NSMutableParagraphStyle(); para.alignment = .center
  let title: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 22, weight: .semibold),
    .foregroundColor: NSColor(white: 0.13, alpha: 1), .paragraphStyle: para]
  ("Switch MTP" as NSString).draw(in: NSRect(x: 0, y: H - 62, width: W, height: 30), withAttributes: title)

  // Seta entre o app e Aplicativos (centro dos ícones a 190 pt do topo).
  let y = H - 190
  let red = NSColor(srgbRed: 0.90, green: 0.0, blue: 0.07, alpha: 1)
  let shaft = NSBezierPath()
  shaft.move(to: NSPoint(x: 258, y: y)); shaft.line(to: NSPoint(x: 362, y: y))
  shaft.lineWidth = 7; shaft.lineCapStyle = .round
  red.setStroke(); shaft.stroke()
  let head = NSBezierPath()
  head.move(to: NSPoint(x: 384, y: y))
  head.line(to: NSPoint(x: 360, y: y + 20))
  head.line(to: NSPoint(x: 360, y: y - 20))
  head.close()
  red.setFill(); head.fill()

  // Instrução.
  let hint: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 14, weight: .regular),
    .foregroundColor: NSColor(white: 0.38, alpha: 1), .paragraphStyle: para]
  ("Arraste o Switch MTP para a pasta Aplicativos para instalar" as NSString)
    .draw(in: NSRect(x: 0, y: 70, width: W, height: 22), withAttributes: hint)

  // Primeira abertura: o app não é notarizado pela Apple, então o macOS bloqueia uma vez.
  let note: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 11.5, weight: .regular),
    .foregroundColor: NSColor(white: 0.48, alpha: 1), .paragraphStyle: para]
  ("Se o macOS bloquear na primeira vez: Ajustes do Sistema › Privacidade e Segurança › Abrir Mesmo Assim"
    as NSString).draw(in: NSRect(x: 0, y: 36, width: W, height: 18), withAttributes: note)

  NSGraphicsContext.restoreGraphicsState()
  return rep.representation(using: .png, properties: [:])!
}

try! render(scale: 1).write(to: URL(fileURLWithPath: "\(outDir)/background.png"))
try! render(scale: 2).write(to: URL(fileURLWithPath: "\(outDir)/background@2x.png"))
