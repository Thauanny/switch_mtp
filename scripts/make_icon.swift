// Gera o ícone do app (todas as resoluções do AppIcon.appiconset do macOS).
//
//   swift scripts/make_icon.swift
//
// Desenho: placa arredondada no grid de ícones do macOS (824/1024), gradiente vermelho da
// identidade do app, um aparelho portátil estilizado e duas setas de transferência.
import AppKit

let outDir = "macos/Runner/Assets.xcassets/AppIcon.appiconset"

func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
  CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
          blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func drawIcon(_ ctx: CGContext) {
  let S: CGFloat = 1024
  ctx.clear(CGRect(x: 0, y: 0, width: S, height: S))

  // Placa com sombra (grid do macOS: 824x824 centralizado, raio ~185).
  let plate = CGRect(x: 100, y: 100, width: 824, height: 824)
  let platePath = CGPath(roundedRect: plate, cornerWidth: 185, cornerHeight: 185, transform: nil)
  ctx.saveGState()
  ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
  ctx.addPath(platePath); ctx.setFillColor(color(0xE60012)); ctx.fillPath()
  ctx.restoreGState()

  ctx.saveGState()
  ctx.addPath(platePath); ctx.clip()
  let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                        colors: [color(0xFF4D5A), color(0xE60012), color(0xA8000D)] as CFArray,
                        locations: [0, 0.55, 1])!
  ctx.drawLinearGradient(grad, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
  // Brilho suave no topo.
  let gloss = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                         colors: [color(0xFFFFFF, 0.18), color(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
  ctx.drawLinearGradient(gloss, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 600), options: [])
  ctx.restoreGState()

  let white = color(0xFFFFFF)

  // Aparelho portátil: corpo arredondado com tela recortada e botões nas laterais.
  let body = CGRect(x: 232, y: 420, width: 560, height: 300)
  let bodyPath = CGMutablePath()
  bodyPath.addRoundedRect(in: body, cornerWidth: 70, cornerHeight: 70)
  let screen = CGRect(x: 352, y: 462, width: 320, height: 216)
  bodyPath.addRoundedRect(in: screen, cornerWidth: 22, cornerHeight: 22)
  // Botões (círculos vazados) e direcional.
  bodyPath.addEllipse(in: CGRect(x: 718, y: 590, width: 40, height: 40))
  bodyPath.addEllipse(in: CGRect(x: 718, y: 510, width: 40, height: 40))
  // Direcional em cruz (contorno único, para o recorte par-ímpar não vazar o centro).
  let cx: CGFloat = 296, cy: CGFloat = 562, a: CGFloat = 30, t: CGFloat = 10
  bodyPath.addLines(between: [
    CGPoint(x: cx - t, y: cy + a), CGPoint(x: cx + t, y: cy + a), CGPoint(x: cx + t, y: cy + t),
    CGPoint(x: cx + a, y: cy + t), CGPoint(x: cx + a, y: cy - t), CGPoint(x: cx + t, y: cy - t),
    CGPoint(x: cx + t, y: cy - a), CGPoint(x: cx - t, y: cy - a), CGPoint(x: cx - t, y: cy - t),
    CGPoint(x: cx - a, y: cy - t), CGPoint(x: cx - a, y: cy + t), CGPoint(x: cx - t, y: cy + t),
  ])
  bodyPath.closeSubpath()
  ctx.saveGState()
  ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: color(0x5A0007, 0.35))
  ctx.addPath(bodyPath); ctx.setFillColor(white); ctx.fillPath(using: .evenOdd)
  ctx.restoreGState()

  // Setas de transferência (uma para cada lado) abaixo do aparelho.
  func arrow(y: CGFloat, right: Bool) {
    let x0: CGFloat = 330, x1: CGFloat = 694, h: CGFloat = 44, head: CGFloat = 62
    let shaft = CGRect(x: right ? x0 : x0 + head - 6, y: y - h / 2, width: x1 - x0 - head + 6, height: h)
    let tip = right ? x1 : x0
    let base = right ? x1 - head - 10 : x0 + head + 10
    // Haste e ponta preenchidas separadamente, para que a sobreposição não se anule.
    ctx.setFillColor(white)
    ctx.addPath(CGPath(roundedRect: shaft, cornerWidth: h / 2, cornerHeight: h / 2, transform: nil))
    ctx.fillPath()
    ctx.move(to: CGPoint(x: tip, y: y))
    ctx.addLine(to: CGPoint(x: base, y: y + head))
    ctx.addLine(to: CGPoint(x: base, y: y - head))
    ctx.closePath()
    ctx.fillPath()
  }
  arrow(y: 340, right: true)
  arrow(y: 225, right: false)
}

// Desenha em 1024 e reduz para cada tamanho.
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let g = NSGraphicsContext(bitmapImageRep: rep)!
drawIcon(g.cgContext)
g.flushGraphics()
let master = NSImage(size: NSSize(width: 1024, height: 1024))
master.addRepresentation(rep)

for size in [16, 32, 64, 128, 256, 512, 1024] {
  let r = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  let c = NSGraphicsContext(bitmapImageRep: r)!
  c.imageInterpolation = .high
  NSGraphicsContext.current = c
  master.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
  NSGraphicsContext.restoreGraphicsState()
  let data = r.representation(using: .png, properties: [:])!
  try! data.write(to: URL(fileURLWithPath: "\(outDir)/app_icon_\(size).png"))
  print("app_icon_\(size).png")
}
