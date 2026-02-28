import SwiftUI

// MARK: - Emotion

enum Emotion: String, CaseIterable, Identifiable, Codable {
    case calm    = "Calm"
    case anxiety = "Anxiety"
    case sadness = "Sadness"
    case love    = "Love"
    case happy   = "Happy"
    case angry   = "Angry"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .calm:    return "🧘"
        case .anxiety: return "⚡️"
        case .sadness: return "🌧"
        case .love:    return "💗"
        case .happy:   return "✨"
        case .angry:   return "🔥"
        }
    }

    var tagline: String {
        switch self {
        case .calm:    return "Peaceful & Centered"
        case .anxiety: return "Turbulent & Alert"
        case .sadness: return "Heavy & Withdrawn"
        case .love:    return "Warm & Connected"
        case .happy:   return "Bright & Energised"
        case .angry:   return "Intense & Reactive"
        }
    }

    var neuralCaption: String {
        switch self {
        case .calm:
            return "Neurons fire in slow, synchronized waves — your brain is settling into effortful peace."
        case .anxiety:
            return "Rapid, desynchronized firing floods your circuits — your brain is in high-alert overdrive."
        case .sadness:
            return "Reduced synaptic activity dims your neural network — withdrawal conserves energy."
        case .love:
            return "Dopamine and oxytocin flood reward circuits — your neurons are lighting up in warm cascades."
        case .happy:
            return "Dopamine and serotonin synchronize reward circuits — your brain is firing in bright, uplifting bursts."
        case .angry:
            return "The amygdala hijacks prefrontal control — rapid, forceful firing primes your body for action."
        }
    }

    var color: Color {
        switch self {
        case .calm:    return Color(red: 0.20, green: 0.55, blue: 0.95)
        case .anxiety: return Color(red: 0.95, green: 0.28, blue: 0.08)
        case .sadness: return Color(red: 0.38, green: 0.40, blue: 0.58)
        case .love:    return Color(red: 0.95, green: 0.38, blue: 0.65)
        case .happy:   return Color(red: 0.98, green: 0.78, blue: 0.10) // warm amber-gold
        case .angry:   return Color(red: 0.88, green: 0.10, blue: 0.18) // deep crimson
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
    var glowIntensity: Float    // base emission brightness 0–1

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
                particleBirthRate: 15, rotationDuration: 20,
                glowIntensity: 0.72
            )
        case .anxiety:
            return EmotionParameters(
                priR: 0.95, priG: 0.28, priB: 0.08,
                secR: 0.90, secG: 0.58, secB: 0.02,
                turbulence: 0.35, pulseSpeed: 0.5, connectivity: 0.45,
                particleVelocity: 2.5, connectionOpacity: 0.80,
                particleBirthRate: 80, rotationDuration: 5,
                glowIntensity: 1.0
            )
        case .sadness:
            return EmotionParameters(
                priR: 0.32, priG: 0.35, priB: 0.55,
                secR: 0.18, secG: 0.20, secB: 0.38,
                turbulence: 0.06, pulseSpeed: 4.0, connectivity: 0.28,
                particleVelocity: 0.12, connectionOpacity: 0.28,
                particleBirthRate: 5, rotationDuration: 35,
                glowIntensity: 0.30
            )
        case .love:
            return EmotionParameters(
                priR: 0.95, priG: 0.38, priB: 0.65,
                secR: 0.90, secG: 0.75, secB: 0.20,
                turbulence: 0.12, pulseSpeed: 1.2, connectivity: 0.90,
                particleVelocity: 0.55, connectionOpacity: 0.68,
                particleBirthRate: 35, rotationDuration: 15,
                glowIntensity: 0.90
            )
        case .happy:
            // Dopamine/serotonin synchronize reward circuits.
            // Medium-fast synchronized pulses, high connectivity (social brain online),
            // warm amber primary with golden secondary.
            // Gamma-like upward-cascading bursts, bright sustained glow.
            return EmotionParameters(
                priR: 0.98, priG: 0.78, priB: 0.10,
                secR: 0.98, secG: 0.55, secB: 0.05,
                turbulence: 0.14, pulseSpeed: 1.0, connectivity: 0.88,
                particleVelocity: 0.70, connectionOpacity: 0.72,
                particleBirthRate: 45, rotationDuration: 13,
                glowIntensity: 0.88
            )
        case .angry:
            // Amygdala hijack: fast, forceful, rhythmically aggressive bursts.
            // Higher amplitude than calm, lower chaos than anxiety — directed intensity.
            // Deep crimson primary, red-orange secondary (adrenaline heat).
            // Strong connectivity in limbic loop, fast rotation.
            return EmotionParameters(
                priR: 0.90, priG: 0.10, priB: 0.15,
                secR: 0.98, secG: 0.40, secB: 0.05,
                turbulence: 0.28, pulseSpeed: 0.65, connectivity: 0.60,
                particleVelocity: 1.80, connectionOpacity: 0.75,
                particleBirthRate: 60, rotationDuration: 7,
                glowIntensity: 0.95
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
            rotationDuration: md(a.rotationDuration, b.rotationDuration),
            glowIntensity: m(a.glowIntensity, b.glowIntensity)
        )
    }
}
