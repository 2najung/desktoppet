import SwiftUI

struct WeatherEffectView: View {
    let condition: WeatherCondition

    var body: some View {
        ZStack {
            switch condition {
            case .rain:
                RainEffect(heavy: true)
            case .drizzle:
                RainEffect(heavy: false)
            case .snow:
                SnowEffect()
            case .clear:
                SunEffect()
            case .thunder:
                RainEffect(heavy: true)
                ThunderFlash()
            case .cloudy:
                CloudEffect()
            case .fog:
                FogEffect()
            case .wind:
                WindEffect()
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 비 (cloud.rain.fill + 빗줄기)

struct RainEffect: View {
    let heavy: Bool
    @State private var t0 = Date.now

    var body: some View {
        TimelineView(.animation) { ctx in
            Canvas { c, size in
                let dt = ctx.date.timeIntervalSince(t0)

                // 구름
                let cloud = c.resolve(Image(systemName: heavy ? "cloud.rain.fill" : "cloud.drizzle.fill"))
                c.drawLayer { layer in
                    layer.opacity = 0.2
                    layer.addFilter(.blur(radius: 2))
                    layer.draw(cloud, in: CGRect(x: size.width * 0.1, y: -5, width: 60, height: 40))
                    layer.draw(cloud, in: CGRect(x: size.width * 0.55, y: 5, width: 50, height: 35))
                }

                // 빗줄기
                let count = heavy ? 35 : 15
                let speed: Double = heavy ? 200 : 120
                let len: Double = heavy ? 14 : 9
                for i in 0..<count {
                    let s = Double(i)
                    let x = (s * 8.7 + 3).truncatingRemainder(dividingBy: Double(size.width))
                    let v = speed + (s * 3).truncatingRemainder(dividingBy: 40)
                    let y = ((dt * v) + s * 37).truncatingRemainder(dividingBy: Double(size.height) + 30) - 15
                    let path = Path { p in
                        p.move(to: CGPoint(x: x, y: y))
                        p.addLine(to: CGPoint(x: x - 2, y: y + len))
                    }
                    c.stroke(path, with: .color(Color(red: 0.4, green: 0.7, blue: 1, opacity: heavy ? 0.35 : 0.25)), lineWidth: 1.5)
                }
            }
        }
    }
}

// MARK: - 눈 (snowflake + 떨어지는 눈)

struct SnowEffect: View {
    @State private var t0 = Date.now

    var body: some View {
        TimelineView(.animation) { ctx in
            Canvas { c, size in
                let dt = ctx.date.timeIntervalSince(t0)

                // 구름
                let cloud = c.resolve(Image(systemName: "cloud.snow.fill"))
                c.drawLayer { layer in
                    layer.opacity = 0.18
                    layer.addFilter(.blur(radius: 2))
                    layer.draw(cloud, in: CGRect(x: size.width * 0.15, y: -5, width: 55, height: 38))
                    layer.draw(cloud, in: CGRect(x: size.width * 0.6, y: 3, width: 45, height: 32))
                }

                // 눈송이
                let snowflake = c.resolve(Image(systemName: "snowflake"))
                for i in 0..<20 {
                    let s = Double(i)
                    let baseX = (s * 15.3 + 5).truncatingRemainder(dividingBy: Double(size.width))
                    let drift = sin(dt * 0.5 + s * 0.6) * 20
                    let x = baseX + drift
                    let v = 18 + (s * 2).truncatingRemainder(dividingBy: 12)
                    let y = ((dt * v) + s * 43).truncatingRemainder(dividingBy: Double(size.height) + 20) - 10
                    let snowSize = 6 + (s.truncatingRemainder(dividingBy: 4)) * 2

                    c.drawLayer { layer in
                        layer.opacity = 0.4 + (s.truncatingRemainder(dividingBy: 3)) * 0.15
                        layer.draw(snowflake, in: CGRect(x: x - snowSize/2, y: y - snowSize/2, width: snowSize, height: snowSize))
                    }
                }
            }
        }
    }
}

// MARK: - 맑음 (sun.max.fill + 반짝이)

struct SunEffect: View {
    @State private var t0 = Date.now

    var body: some View {
        TimelineView(.animation) { ctx in
            Canvas { c, size in
                let dt = ctx.date.timeIntervalSince(t0)

                // 태양
                let sun = c.resolve(Image(systemName: "sun.max.fill"))
                c.drawLayer { layer in
                    layer.opacity = 0.15 + sin(dt * 0.5) * 0.05
                    layer.addFilter(.blur(radius: 3))
                    layer.draw(sun, in: CGRect(x: size.width * 0.65, y: -10, width: 50, height: 50))
                }

                // 반짝이 (sparkle)
                let sparkle = c.resolve(Image(systemName: "sparkle"))
                for i in 0..<10 {
                    let s = Double(i)
                    let x = (s * 28.7 + 10).truncatingRemainder(dividingBy: Double(size.width))
                    let y = (s * 42.3 + 15).truncatingRemainder(dividingBy: Double(size.height) * 0.6)
                    let phase = (dt * 0.4 + s * 0.55).truncatingRemainder(dividingBy: 3.0)
                    let opacity = phase < 1.5 ? sin(phase / 1.5 * .pi) * 0.4 : 0.0
                    let sparkSize = phase < 1.5 ? sin(phase / 1.5 * .pi) * 10 + 4 : 0.0

                    if opacity > 0.01 {
                        c.drawLayer { layer in
                            layer.opacity = opacity
                            layer.draw(sparkle, in: CGRect(x: x - sparkSize/2, y: y - sparkSize/2, width: sparkSize, height: sparkSize))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 천둥 (bolt.fill + 번쩍)

struct ThunderFlash: View {
    @State private var t0 = Date.now

    var body: some View {
        TimelineView(.animation) { ctx in
            Canvas { c, size in
                let dt = ctx.date.timeIntervalSince(t0)
                let cycle = dt.truncatingRemainder(dividingBy: 4.5)
                let flash = cycle < 0.08 || (cycle > 0.15 && cycle < 0.2)

                if flash {
                    c.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(0.4)))
                    // 번개
                    let bolt = c.resolve(Image(systemName: "bolt.fill"))
                    c.drawLayer { layer in
                        layer.opacity = 0.7
                        let bx = Double(size.width) * 0.3 + sin(dt * 2) * 30
                        layer.draw(bolt, in: CGRect(x: bx, y: 10, width: 25, height: 40))
                    }
                }
            }
        }
    }
}

// MARK: - 흐림 (cloud.fill)

struct CloudEffect: View {
    @State private var t0 = Date.now

    var body: some View {
        TimelineView(.animation) { ctx in
            Canvas { c, size in
                let dt = ctx.date.timeIntervalSince(t0)
                let symbol = c.resolve(Image(systemName: "cloud.fill"))

                let clouds: [(Double, Double, Double, Double)] = [
                    (20, 8, 55, 4),
                    (100, 35, 45, 6),
                    (60, 65, 50, 3),
                    (160, 15, 40, 5),
                    (10, 50, 35, 7),
                ]

                for (i, cloud) in clouds.enumerated() {
                    let (baseX, y, cloudSize, speed) = cloud
                    let x = (baseX + dt * speed).truncatingRemainder(dividingBy: Double(size.width) + 80) - 40
                    let opacity = 0.15 + Double(i % 3) * 0.05

                    c.drawLayer { layer in
                        layer.opacity = opacity
                        layer.addFilter(.blur(radius: 2))
                        layer.draw(symbol, in: CGRect(x: x, y: y, width: cloudSize, height: cloudSize * 0.6))
                    }
                }
            }
        }
    }
}

// MARK: - 안개 (cloud.fog.fill)

struct FogEffect: View {
    @State private var t0 = Date.now

    var body: some View {
        TimelineView(.animation) { ctx in
            Canvas { c, size in
                let dt = ctx.date.timeIntervalSince(t0)
                let fog = c.resolve(Image(systemName: "cloud.fog.fill"))

                // 안개 레이어 여러 겹
                for i in 0..<4 {
                    let s = Double(i)
                    let x = sin(dt * 0.15 + s * 1.5) * 20 - 10
                    let y = s * Double(size.height) * 0.25
                    c.drawLayer { layer in
                        layer.opacity = 0.1 + sin(dt * 0.2 + s) * 0.03
                        layer.addFilter(.blur(radius: 8))
                        layer.draw(fog, in: CGRect(x: x, y: y, width: Double(size.width) + 20, height: Double(size.height) * 0.35))
                    }
                }
            }
        }
    }
}

// MARK: - 바람 (wind + 나뭇잎)

struct WindEffect: View {
    @State private var t0 = Date.now

    var body: some View {
        TimelineView(.animation) { ctx in
            Canvas { c, size in
                let dt = ctx.date.timeIntervalSince(t0)

                // 바람 줄
                let wind = c.resolve(Image(systemName: "wind"))
                for i in 0..<3 {
                    let s = Double(i)
                    let speed = 40 + s * 15
                    let x = ((dt * speed) + s * 60).truncatingRemainder(dividingBy: Double(size.width) + 60) - 30
                    let y = 15 + s * 35
                    c.drawLayer { layer in
                        layer.opacity = 0.12
                        layer.draw(wind, in: CGRect(x: x, y: y, width: 35, height: 20))
                    }
                }

                // 나뭇잎
                let leaf = c.resolve(Text("🍃").font(.system(size: 14)))
                let leaf2 = c.resolve(Text("🍂").font(.system(size: 12)))
                for i in 0..<8 {
                    let s = Double(i)
                    let v = 55 + s * 12
                    let x = ((dt * v) + s * 45).truncatingRemainder(dividingBy: Double(size.width) + 40) - 20
                    let baseY = (s * 52 + 20).truncatingRemainder(dividingBy: Double(size.height) * 0.7)
                    let y = baseY + sin(dt * 1.8 + s) * 18
                    c.draw(i % 2 == 0 ? leaf : leaf2, at: CGPoint(x: x, y: y))
                }
            }
        }
    }
}

// MARK: - 레벨업 빵빠레

struct ConfettiOverlay: View {
    @State private var t0 = Date.now
    private let colors: [Color] = [.red, .yellow, .green, .blue, .purple, .orange, .pink, .mint, .cyan]

    var body: some View {
        TimelineView(.animation) { ctx in
            Canvas { c, size in
                let dt = ctx.date.timeIntervalSince(t0)
                if dt > 3.5 { return }

                if dt < 2 {
                    let text = c.resolve(Text("🎉 LEVEL UP! 🎉").font(.system(size: 14, weight: .black, design: .rounded)))
                    let yy = size.height * 0.15 + sin(dt * 4) * 5
                    c.draw(text, at: CGPoint(x: size.width / 2, y: yy))
                }

                for i in 0..<40 {
                    let s = Double(i)
                    let angle = s * 0.157 + s * 0.37
                    let speed = 60 + (s * 7).truncatingRemainder(dividingBy: 50)
                    let vx = cos(angle) * speed
                    let vy = -120 - s * 3
                    let gravity = 180.0
                    let x = size.width / 2 + vx * dt
                    let y = size.height * 0.4 + vy * dt + 0.5 * gravity * dt * dt
                    let opacity = max(0, 1 - dt / 3.0)
                    guard opacity > 0 else { continue }
                    let w: CGFloat = 5 + CGFloat(s.truncatingRemainder(dividingBy: 3))
                    let h: CGFloat = 3 + CGFloat(s.truncatingRemainder(dividingBy: 2))
                    let color = colors[i % colors.count]
                    let rect = CGRect(x: x - w/2, y: y - h/2, width: w, height: h)
                    c.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(color.opacity(opacity)))
                }
            }
        }
        .transition(.opacity)
    }
}
