import SwiftUI

struct WeatherEffectView: View {
    let condition: WeatherCondition
    var body: some View {
        ZStack {
            switch condition {
            case .rain: RainEffect(heavy: true)
            case .drizzle: RainEffect(heavy: false)
            case .snow: SnowEffect()
            case .clear: SunEffect()
            case .thunder: RainEffect(heavy: true); ThunderFlash()
            case .cloudy: CloudEffect()
            case .fog: FogEffect()
            case .wind: WindEffect()
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 비

struct RainEffect: View {
    let heavy: Bool
    @State private var t0 = Date.now
    var body: some View {
        RainCloud(heavy: heavy)
        RainDrops(heavy: heavy, t0: $t0)
    }
}

struct RainCloud: View {
    let heavy: Bool
    var body: some View {
        Image(systemName: heavy ? "cloud.rain.fill" : "cloud.drizzle.fill")
            .font(.system(size: 45))
            .foregroundStyle(Color(red: 0.5, green: 0.6, blue: 0.75))
            .blur(radius: 3)
            .opacity(0.3)
            .offset(x: -30, y: -60)
        Image(systemName: heavy ? "cloud.rain.fill" : "cloud.drizzle.fill")
            .font(.system(size: 35))
            .foregroundStyle(Color(red: 0.5, green: 0.6, blue: 0.75))
            .blur(radius: 2)
            .opacity(0.25)
            .offset(x: 50, y: -50)
    }
}

struct RainDrops: View {
    let heavy: Bool
    @Binding var t0: Date
    var body: some View {
        TimelineView(.animation) { ctx in
            Canvas { c, size in
                let dt = ctx.date.timeIntervalSince(t0)
                let count = heavy ? 35 : 15
                let spd: Double = heavy ? 200 : 120
                let len: Double = heavy ? 14 : 9
                for i in 0..<count {
                    let s = Double(i)
                    let x = (s * 8.7 + 3).truncatingRemainder(dividingBy: Double(size.width))
                    let v = spd + (s * 3).truncatingRemainder(dividingBy: 40)
                    let y = ((dt * v) + s * 37).truncatingRemainder(dividingBy: Double(size.height) + 30) - 15
                    var path = Path(); path.move(to: CGPoint(x: x, y: y)); path.addLine(to: CGPoint(x: x - 2, y: y + len))
                    c.stroke(path, with: .color(Color(red: 0.35, green: 0.6, blue: 0.95).opacity(heavy ? 0.4 : 0.25)), lineWidth: 1.5)
                }
            }
        }
    }
}

// MARK: - 눈

struct SnowEffect: View {
    @State private var t0 = Date.now
    var body: some View {
        Image(systemName: "cloud.snow.fill")
            .font(.system(size: 40))
            .foregroundStyle(Color(red: 0.65, green: 0.72, blue: 0.85))
            .blur(radius: 3)
            .opacity(0.25)
            .offset(x: -25, y: -55)
        Image(systemName: "cloud.snow.fill")
            .font(.system(size: 32))
            .foregroundStyle(Color(red: 0.65, green: 0.72, blue: 0.85))
            .blur(radius: 2)
            .opacity(0.2)
            .offset(x: 45, y: -48)
        TimelineView(.animation) { ctx in
            Canvas { c, size in
                let dt = ctx.date.timeIntervalSince(t0)
                for i in 0..<20 {
                    let s = Double(i)
                    let baseX = (s * 15.3 + 5).truncatingRemainder(dividingBy: Double(size.width))
                    let drift = sin(dt * 0.5 + s * 0.6) * 20
                    let v = 18 + (s * 2).truncatingRemainder(dividingBy: 12)
                    let y = ((dt * v) + s * 43).truncatingRemainder(dividingBy: Double(size.height) + 20) - 10
                    let sz = 3 + (s.truncatingRemainder(dividingBy: 3))
                    let circle = Path(ellipseIn: CGRect(x: baseX + drift - sz, y: y - sz, width: sz * 2, height: sz * 2))
                    c.fill(circle, with: .color(Color(red: 0.8, green: 0.9, blue: 1).opacity(0.6)))
                }
            }
        }
    }
}

// MARK: - 맑음

struct SunEffect: View {
    @State private var t0 = Date.now
    var body: some View {
        Image(systemName: "sun.max.fill")
            .font(.system(size: 42))
            .foregroundStyle(.yellow)
            .blur(radius: 5)
            .opacity(0.2)
            .offset(x: 50, y: -55)
        TimelineView(.animation) { ctx in
            Canvas { c, size in
                let dt = ctx.date.timeIntervalSince(t0)
                for i in 0..<10 {
                    let s = Double(i)
                    let x = (s * 28.7 + 10).truncatingRemainder(dividingBy: Double(size.width))
                    let y = (s * 42.3 + 15).truncatingRemainder(dividingBy: Double(size.height) * 0.6)
                    let phase = (dt * 0.4 + s * 0.55).truncatingRemainder(dividingBy: 3.0)
                    let op = phase < 1.5 ? sin(phase / 1.5 * .pi) * 0.4 : 0.0
                    let sz = phase < 1.5 ? sin(phase / 1.5 * .pi) * 5 + 2 : 0.0
                    if op > 0.01 {
                        let star = Path(ellipseIn: CGRect(x: x - sz, y: y - sz, width: sz * 2, height: sz * 2))
                        c.fill(star, with: .color(Color(red: 1, green: 0.85, blue: 0.3).opacity(op)))
                    }
                }
            }
        }
    }
}

// MARK: - 천둥

struct ThunderFlash: View {
    @State private var t0 = Date.now
    var body: some View {
        TimelineView(.animation) { ctx in
            Canvas { c, size in
                let dt = ctx.date.timeIntervalSince(t0)
                let cycle = dt.truncatingRemainder(dividingBy: 4.5)
                if cycle < 0.08 || (cycle > 0.15 && cycle < 0.2) {
                    c.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(0.35)))
                }
            }
        }
        Image(systemName: "bolt.fill")
            .font(.system(size: 20))
            .foregroundStyle(.yellow)
            .opacity(0.6)
            .offset(x: -15, y: -30)
    }
}

// MARK: - 흐림

struct CloudEffect: View {
    @State private var t0 = Date.now
    var body: some View {
        TimelineView(.animation) { ctx in
            Canvas { c, size in
                let dt = ctx.date.timeIntervalSince(t0)
                let sym = c.resolve(Image(systemName: "cloud.fill"))
                let data: [(Double, Double, Double, Double)] = [
                    (20, 8, 55, 4), (100, 35, 45, 6), (60, 65, 50, 3), (160, 15, 40, 5), (10, 50, 35, 7),
                ]
                for (i, d) in data.enumerated() {
                    let x = (d.0 + dt * d.3).truncatingRemainder(dividingBy: Double(size.width) + 80) - 40
                    c.drawLayer { l in
                        l.opacity = 0.18 + Double(i % 3) * 0.05
                        l.addFilter(.blur(radius: 2))
                        l.draw(sym, in: CGRect(x: x, y: d.1, width: d.2, height: d.2 * 0.6))
                    }
                }
            }
        }
    }
}

// MARK: - 안개

struct FogEffect: View {
    @State private var t0 = Date.now
    var body: some View {
        Image(systemName: "cloud.fog.fill")
            .font(.system(size: 60))
            .foregroundStyle(Color(red: 0.75, green: 0.78, blue: 0.85))
            .blur(radius: 12)
            .opacity(0.15)
            .offset(y: -20)
        Image(systemName: "cloud.fog.fill")
            .font(.system(size: 50))
            .foregroundStyle(Color(red: 0.75, green: 0.78, blue: 0.85))
            .blur(radius: 10)
            .opacity(0.12)
            .offset(y: 30)
    }
}

// MARK: - 바람

struct WindEffect: View {
    @State private var t0 = Date.now
    var body: some View {
        Image(systemName: "wind")
            .font(.system(size: 25))
            .foregroundStyle(Color(red: 0.55, green: 0.7, blue: 0.85))
            .opacity(0.2)
            .offset(x: -30, y: -40)
        Image(systemName: "wind")
            .font(.system(size: 20))
            .foregroundStyle(Color(red: 0.55, green: 0.7, blue: 0.85))
            .opacity(0.15)
            .offset(x: 40, y: 10)
        TimelineView(.animation) { ctx in
            Canvas { c, size in
                let dt = ctx.date.timeIntervalSince(t0)
                let leaf = c.resolve(Text("🍃").font(.system(size: 14)))
                let leaf2 = c.resolve(Text("🍂").font(.system(size: 12)))
                for i in 0..<8 {
                    let s = Double(i)
                    let x = ((dt * (55 + s * 12)) + s * 45).truncatingRemainder(dividingBy: Double(size.width) + 40) - 20
                    let y = (s * 52 + 20).truncatingRemainder(dividingBy: Double(size.height) * 0.7) + sin(dt * 1.8 + s) * 18
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
                    c.draw(text, at: CGPoint(x: size.width / 2, y: size.height * 0.15 + sin(dt * 4) * 5))
                }
                for i in 0..<40 {
                    let s = Double(i)
                    let vx = cos(s * 0.157 + s * 0.37) * (60 + (s * 7).truncatingRemainder(dividingBy: 50))
                    let x = size.width / 2 + vx * dt
                    let y = size.height * 0.4 + (-120 - s * 3) * dt + 90 * dt * dt
                    let op = max(0, 1 - dt / 3.0)
                    guard op > 0 else { continue }
                    let w: CGFloat = 5 + CGFloat(s.truncatingRemainder(dividingBy: 3))
                    let h: CGFloat = 3 + CGFloat(s.truncatingRemainder(dividingBy: 2))
                    c.fill(Path(roundedRect: CGRect(x: x - w/2, y: y - h/2, width: w, height: h), cornerRadius: 1),
                           with: .color(colors[i % colors.count].opacity(op)))
                }
            }
        }
        .transition(.opacity)
    }
}
