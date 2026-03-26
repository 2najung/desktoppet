import Foundation

enum PetMood: String, CaseIterable {
    case happy
    case normal
    case hungry
    case tired
    case sad
    case sleeping
    case dirty
    case bathing
    case cook      // 요리 중
    case eat       // 먹는 중
    case full      // 배부른 상태
    case angry     // 화남
    case work      // 집중/작업 중

    var emoji: String {
        switch self {
        case .happy: return "😆"
        case .normal: return "😊"
        case .hungry: return "😿"
        case .tired: return "😪"
        case .sad: return "🥺"
        case .sleeping: return "💤"
        case .dirty: return "🫥"
        case .bathing: return "🛁"
        case .cook: return "🍳"
        case .eat: return "🍴"
        case .full: return "😋"
        case .angry: return "😤"
        case .work: return "💻"
        }
    }

    var label: String {
        switch self {
        case .happy: return "행복해!"
        case .normal: return "기분 좋아~"
        case .hungry: return "배고파..."
        case .tired: return "졸려..."
        case .sad: return "외로워..."
        case .sleeping: return "쿨쿨..."
        case .dirty: return "씻고싶어..."
        case .bathing: return "뽀득뽀득~!"
        case .cook: return "요리 중~!"
        case .eat: return "냠냠냠~!"
        case .full: return "배불러~!"
        case .angry: return "화났어!!"
        case .work: return "집중 중...!"
        }
    }
}

struct PetSaveData: Codable {
    var name: String
    var hunger: Double
    var happiness: Double
    var energy: Double
    var cleanliness: Double
    var bond: Double
    var experience: Double
    var level: Int
    var isSleeping: Bool
    var lastUpdateTime: Date
}
