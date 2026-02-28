import Foundation

// MARK: - EmotionSession

/// Recorded data from one completed emotion exploration + stabilization cycle.
struct EmotionSession: Identifiable {
    let id   = UUID()
    let emotion:            Emotion
    let date:               Date
    let stabilizationTime:  TimeInterval
    let breathingQuality:   String
    let isLogged:           Bool       // true only when user tapped "Yes" to log prompt

    var formattedStabilizationTime: String {
        let s = Int(max(0, stabilizationTime))
        guard s >= 60 else { return "\(s)s" }
        let m = s / 60; let rem = s % 60
        return rem == 0 ? "\(m)m" : "\(m)m \(rem)s"
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }

    var formattedFullDate: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f.string(from: date)
    }
}
