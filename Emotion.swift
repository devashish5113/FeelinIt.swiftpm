import SwiftUI

// MARK: - Emotion

enum Emotion: String, CaseIterable, Identifiable {
    case calm    = "Calm"
    case anxiety = "Anxiety"
    case sadness = "Sadness"
    case love    = "Love"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .calm:    return "🧘"
        case .anxiety: return "⚡️"
        case .sadness: return "🌧"
        case .love:    return "💗"
        }
    }

    var tagline: String {
        switch self {
        case .calm:    return "Peaceful & Centered"
        case .anxiety: return "Turbulent & Alert"
        case .sadness: return "Heavy & Withdrawn"
        case .love:    return "Warm & Connected"
        }
    }

    var color: Color {
        switch self {
        case .calm:    return Color(red: 0.20, green: 0.55, blue: 0.95)
        case .anxiety: return Color(red: 0.95, green: 0.28, blue: 0.08)
        case .sadness: return Color(red: 0.38, green: 0.40, blue: 0.58)
        case .love:    return Color(red: 0.95, green: 0.38, blue: 0.65)
        }
    }
}

// MARK: - EmotionParameters

struct EmotionParameters: Sendable {
    // Color components (0–1 each)
    var priR: Float; var priG: Float; var priB: Float
    var secR: Float; var secG: Float; var secB: Float
    // Behavior
    var turbulence: Float       // node displacement magnitude 0–1
    var pulseSpeed: Double      // pulse cycle duration in seconds
    var connectivity: Float     // 0–1 connection density factor
    var particleVelocity: Float
    var connectionOpacity: Float
    var particleBirthRate: Float
    var rotationDuration: Double // seconds for full Y rotation

    var primaryUIColor: UIColor {
        UIColor(red: CGFloat(priR), green: CGFloat(priG), blue: CGFloat(priB), alpha: 1)
    }
    var secondaryUIColor: UIColor {
        UIColor(red: CGFloat(secR), green: CGFloat(secG), blue: CGFloat(secB), alpha: 1)
    }

    static func make(for emotion: Emotion) -> EmotionParameters {
        switch emotion {
        case .calm:
            return EmotionParameters(
                priR: 0.20, priG: 0.60, priB: 0.95,
                secR: 0.10, secG: 0.30, secB: 0.70,
                turbulence: 0.04, pulseSpeed: 2.5, connectivity: 0.75,
                particleVelocity: 0.3, connectionOpacity: 0.55,
                particleBirthRate: 15, rotationDuration: 20
            )
        case .anxiety:
            return EmotionParameters(
                priR: 0.95, priG: 0.28, priB: 0.08,
                secR: 0.90, secG: 0.58, secB: 0.02,
                turbulence: 0.35, pulseSpeed: 0.5, connectivity: 0.45,
                particleVelocity: 2.5, connectionOpacity: 0.80,
                particleBirthRate: 80, rotationDuration: 5
            )
        case .sadness:
            return EmotionParameters(
                priR: 0.32, priG: 0.35, priB: 0.55,
                secR: 0.18, secG: 0.20, secB: 0.38,
                turbulence: 0.06, pulseSpeed: 4.0, connectivity: 0.28,
                particleVelocity: 0.12, connectionOpacity: 0.28,
                particleBirthRate: 5, rotationDuration: 35
            )
        case .love:
            return EmotionParameters(
                priR: 0.95, priG: 0.38, priB: 0.65,
                secR: 0.90, secG: 0.75, secB: 0.20,
                turbulence: 0.12, pulseSpeed: 1.2, connectivity: 0.90,
                particleVelocity: 0.55, connectionOpacity: 0.68,
                particleBirthRate: 35, rotationDuration: 15
            )
        }
    }

    static func lerp(_ a: EmotionParameters, _ b: EmotionParameters, t: Float) -> EmotionParameters {
        let t = max(0, min(1, t))
        func m(_ x: Float, _ y: Float) -> Float { x + (y - x) * t }
        func md(_ x: Double, _ y: Double) -> Double { x + (y - x) * Double(t) }
        return EmotionParameters(
            priR: m(a.priR, b.priR), priG: m(a.priG, b.priG), priB: m(a.priB, b.priB),
            secR: m(a.secR, b.secR), secG: m(a.secG, b.secG), secB: m(a.secB, b.secB),
            turbulence: m(a.turbulence, b.turbulence),
            pulseSpeed: md(a.pulseSpeed, b.pulseSpeed),
            connectivity: m(a.connectivity, b.connectivity),
            particleVelocity: m(a.particleVelocity, b.particleVelocity),
            connectionOpacity: m(a.connectionOpacity, b.connectionOpacity),
            particleBirthRate: m(a.particleBirthRate, b.particleBirthRate),
            rotationDuration: md(a.rotationDuration, b.rotationDuration)
        )
    }
}
