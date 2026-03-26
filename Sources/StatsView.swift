import SwiftUI

struct StatsView: View {
    @ObservedObject var petManager: PetManager

    var body: some View {
        VStack(spacing: 5) {
            StatBar(icon: "fork.knife", label: "배고픔", value: petManager.hunger, color: .orange)
            StatBar(icon: "heart.fill", label: "기분", value: petManager.happiness, color: .pink)
            StatBar(icon: "bolt.fill", label: "에너지", value: petManager.energy, color: .yellow)
            StatBar(icon: "bubbles.and.sparkles.fill", label: "청결", value: petManager.cleanliness, color: .cyan)
            StatBar(icon: "heart.circle.fill", label: "친밀도", value: petManager.bond, color: .red)
        }
    }
}

struct StatBar: View {
    let icon: String
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(barColor)
                .frame(width: 14)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .frame(width: 36, alignment: .leading)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 10)

                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: [barColor.opacity(0.7), barColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(value / 100.0))
                        .animation(.easeInOut(duration: 0.4), value: value)
                }
                .frame(height: 10)
            }

            Text("\(Int(value))")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(barColor)
                .frame(width: 24, alignment: .trailing)
        }
    }

    var barColor: Color {
        if value < 25 { return .red }
        if value < 50 { return .orange }
        return color
    }
}
