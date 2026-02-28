import SceneKit
import SwiftUI

// MARK: - NeuralSceneManager
//
// 3000 pts split into 8 independent point-cloud groups.
// Each emotion gives each group a distinct SCNAction pattern:
//   Calm    → slow synchronized wave, small gentle displacement
//   Anxiety → chaotic rapid multi-freq jitter, large amplitude, opacity flashes
//   Sadness → most groups dim/frozen, minimal motion
//   Love    → rhythmic cascade wave, warm secondary color flashes

@MainActor
final class NeuralSceneManager: ObservableObject {

    let scene = SCNScene()
    private let sphereRoot     = SCNNode()
    private var cloudGroups:   [SCNNode] = []   // 8 independently animated point groups
    private var connectionNode = SCNNode()
    private var skeletonPts:   [SCNVector3] = []
    private var currentParams  = EmotionParameters.make(for: .calm)

    // Impulse trails
    private var impulseRoot      = SCNNode()
    private var synapseNode      = SCNNode()           // persistent bouton display
    private var synapsePositions: [SCNVector3] = []    // cached for color rebuilds
    private var synapsePaths: [[SCNVector3]] = []
    private var impulseTask: Task<Void, Never>?

    // Restore balance animation
    private(set) var isRestoring = false

    private let groupCount = 8

    init() {
        setupScene()
        Task.detached { [weak self] in await self?.asyncBuild() }
    }

    private func setupScene() {
        scene.background.contents = UIColor.black
        let amb = SCNNode(); amb.light = SCNLight()
        amb.light?.type = .ambient; amb.light?.intensity = 40
        scene.rootNode.addChildNode(amb)
        scene.rootNode.addChildNode(sphereRoot)
        sphereRoot.addChildNode(impulseRoot)   // rotates with neuron
    }

    // MARK: - Background Build

    nonisolated private func asyncBuild() async {
        let skeleton       = Self.neuronSkeleton()
        let synPositions   = Self.buildSynapsePositions()            // bouton locations
        let paths          = Self.buildShortImpulsePaths(from: synPositions)  // short hops
        let allCloud       = Self.neuronCloud(count: 5000)
        let (lineV, lineI) = Self.connectionGeo(positions: skeleton, threshold: 0.38)

        // Split cloud into 8 animated groups
        let groupSize  = allCloud.count / 8
        var groups     = [[SCNVector3]]()
        for g in 0..<8 {
            let start = g * groupSize
            let end   = g == 7 ? allCloud.count : start + groupSize
            groups.append(Array(allCloud[start..<end]))
        }

        await MainActor.run { [weak self] in
            guard let self else { return }
            self.skeletonPts  = skeleton
            self.synapsePaths = paths
            self.buildGroups(groups)
            let calmColor = NeuralSceneManager.hardcodedImpulseColor(for: .calm)
            self.placeLines(vertices: lineV, indices: lineI, color: calmColor)
            self.synapsePositions = synPositions          // cache for later rebuilds
            self.buildSynapseDisplay(positions: synPositions, color: calmColor)
            self.applyParameters(EmotionParameters.make(for: .calm), animated: false)
        }
    }

    // MARK: - Group Setup

    private func buildGroups(_ groups: [[SCNVector3]]) {
        cloudGroups.forEach { $0.removeFromParentNode() }
        cloudGroups = groups.map { pts in
            let node = makeCloudNode(positions: pts, color: .white)
            sphereRoot.addChildNode(node)
            return node
        }
    }

    private func makeCloudNode(positions: [SCNVector3], color: UIColor) -> SCNNode {
        let src  = SCNGeometrySource(vertices: positions)
        let idxs = Array(Int32(0)..<Int32(positions.count))
        let elem = SCNGeometryElement(indices: idxs, primitiveType: .point)
        elem.pointSize = 3.5
        elem.minimumPointScreenSpaceRadius = 0.5
        elem.maximumPointScreenSpaceRadius = 5.0
        let geo = SCNGeometry(sources: [src], elements: [elem])
        let mat = SCNMaterial()
        mat.lightingModel     = .constant
        mat.emission.contents = color
        mat.blendMode         = .add
        mat.writesToDepthBuffer = false
        geo.materials = [mat]
        return SCNNode(geometry: geo)
    }

    // MARK: - Update

    func update(parameters: EmotionParameters) {
        guard !isRestoring else {
            currentParams = parameters
            sphereRoot.removeAction(forKey: "rot")
            sphereRoot.runAction(.repeatForever(
                .rotateBy(x: 0.06, y: CGFloat(2 * Double.pi), z: 0.03,
                          duration: parameters.rotationDuration)
            ), forKey: "rot")
            return
        }
        applyParameters(parameters, animated: true)
    }

    /// Instantly snaps impulse / bouton / connection colors to the target emotion
    /// without waiting for the lerp animation. Call this as soon as the user
    /// selects a new emotion so there is zero color flicker during the transition.
    func snapColors(for emotion: Emotion) {
        guard !isRestoring else { return }
        let color = NeuralSceneManager.hardcodedImpulseColor(for: emotion)

        // Boutons
        if !synapsePositions.isEmpty {
            buildSynapseDisplay(positions: synapsePositions, color: color)
        }
        // Connection lines
        let skel = skeletonPts
        if !skel.isEmpty {
            let thresh = Float(0.22 + EmotionParameters.make(for: emotion).connectivity * 0.22)
            let (v, i) = Self.connectionGeo(positions: skel, threshold: thresh)
            placeLines(vertices: v, indices: i, color: color)
        }
        // Impulse loop
        let cfg = impulseConfig(for: emotion)
        startImpulseLoop(color: color, cfg: cfg)
    }

    // MARK: - Restore Balance Animation

    /// Call when restore-balance begins. Goes white, stops impulses, plays
    /// a visible convergence spiral that settles the cloud groups inward.
    func beginRestoreAnimation() {
        isRestoring = true

        // 1. Stop impulses
        impulseTask?.cancel()
        impulseRoot.enumerateChildNodes { [weak self] node, _ in
            guard node !== self?.synapseNode else { return }
            node.removeFromParentNode()
        }

        // 2. Set boutons + connections to white
        if !synapsePositions.isEmpty {
            buildSynapseDisplay(positions: synapsePositions,
                                color: UIColor(white: 0.85, alpha: 1))
        }
        let skel = skeletonPts
        if !skel.isEmpty {
            let (v, i) = Self.connectionGeo(positions: skel, threshold: 0.30)
            placeLines(vertices: v, indices: i, color: UIColor(white: 0.50, alpha: 1))
        }

        // 3. Fade cloud groups to dim white
        let white = UIColor(white: 0.45, alpha: 1)
        for group in cloudGroups {
            group.removeAllActions()
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 1.2
            group.geometry?.firstMaterial?.emission.contents = white
            group.geometry?.firstMaterial?.diffuse.contents = white
            SCNTransaction.commit()
        }

        // 4. Convergence spiral: groups pull inward toward center + gentle spin
        for (i, group) in cloudGroups.enumerated() {
            let phase  = Float(i) * 2 * .pi / Float(groupCount)
            let delay  = Double(i) * 0.15   // stagger
            let settle = SCNAction.customAction(duration: 2.5) { nd, t in
                let prog = Float(t / 2.5)
                // Shrink orbit radius toward 0 (convergence)
                let radius = 0.045 * (1.0 - prog * prog)   // quadratic ease-in
                let angle  = prog * 6 * .pi + phase         // spiraling
                let x = radius * cos(angle)
                let y = radius * sin(angle)
                let z = radius * sin(angle * 0.7) * 0.4
                nd.position = SCNVector3(x, y, z)
                // Scale slightly down then back to 1
                let s = 1.0 - 0.08 * sin(Double(prog) * .pi)
                nd.scale = SCNVector3(s, s, s)
            }
            settle.timingMode = .easeInEaseOut

            // Gentle brightening pulse near the end
            let brighten = SCNAction.customAction(duration: 2.5) { nd, t in
                let prog = Float(t / 2.5)
                let brightness = 0.45 + 0.35 * prog   // 0.45 → 0.80
                let c = UIColor(white: CGFloat(brightness), alpha: 1)
                nd.geometry?.firstMaterial?.emission.contents = c
            }

            let waitThenSettle = SCNAction.sequence([
                .wait(duration: delay),
                .group([settle, brighten])
            ])
            group.runAction(waitThenSettle, forKey: "restoreSettle")
        }
    }

    /// Call when restore-balance is complete. Snaps everything to calm colors.
    func finishRestoreAnimation() {
        isRestoring = false

        // Reset group positions
        for group in cloudGroups {
            group.removeAction(forKey: "restoreSettle")
            group.position = .init(0, 0, 0)
            group.scale    = .init(1, 1, 1)
        }

        // Apply calm parameters normally
        applyParameters(EmotionParameters.make(for: .calm), animated: true)
    }

    // MARK: - Glow helpers

    /// Returns the emission UIColor pre-multiplied by an intensity factor (0–1+).
    /// Values >1 clamp at white, giving the "white-hot" overblown effect for Anxiety.
    private func glowColor(from base: UIColor, intensity: Float) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        base.getRed(&r, green: &g, blue: &b, alpha: &a)
        if intensity <= 1.0 {
            let f = CGFloat(intensity)
            return UIColor(red: r * f, green: g * f, blue: b * f, alpha: a)
        } else {
            let t = CGFloat(min((intensity - 1.0) / 1.0, 1.0))
            return UIColor(red: r + (1 - r) * t, green: g + (1 - g) * t,
                           blue: b + (1 - b) * t, alpha: a)
        }
    }


    /// Cloud-specific wrapper — scales glowColor intensity down to 28% so the
    /// 5000 additive-blended cloud particles stay dim enough that the vivid
    /// coloured impulse sparkles are clearly visible against them.
    private func cloudGlowColor(from base: UIColor, intensity: Float) -> UIColor {
        glowColor(from: base, intensity: intensity * 0.28)
    }

    private func applyParameters(_ p: EmotionParameters, animated: Bool) {
        currentParams = p
        let dur: CGFloat = animated ? 1.2 : 0

        // Rotation — speed + slight tilt for 3D read
        sphereRoot.removeAllActions()
        sphereRoot.runAction(.repeatForever(
            .rotateBy(x: 0.06, y: CGFloat(2 * Double.pi), z: 0.03, duration: p.rotationDuration)
        ), forKey: "rot")

        // Per-group emotion behavior
        for (i, group) in cloudGroups.enumerated() {
            group.removeAllActions()

            // Base color keyed to glow intensity — dimmed so impulse colours dominate
            let baseGlowColor = cloudGlowColor(from: p.primaryUIColor, intensity: p.glowIntensity)
            SCNTransaction.begin(); SCNTransaction.animationDuration = dur
            group.geometry?.firstMaterial?.emission.contents = baseGlowColor
            SCNTransaction.commit()

            applyEmotionActions(to: group, index: i, params: p, animated: animated)
        }

        // Connections density — restored to 0.22–0.44 so soma ring keeps axon connections
        let threshold = Float(0.22 + p.connectivity * 0.22)
        let skel = skeletonPts
        if animated && !skel.isEmpty {
            SCNTransaction.begin(); SCNTransaction.animationDuration = 0.8
            connectionNode.opacity = 0; SCNTransaction.commit()
            Task.detached { [threshold, skel] in
                let (v, i) = NeuralSceneManager.connectionGeo(positions: skel, threshold: threshold)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.placeLines(vertices: v, indices: i,
                                    color: NeuralSceneManager.hardcodedImpulseColor(
                                        for: self.dominantEmotion(p)))
                    SCNTransaction.begin(); SCNTransaction.animationDuration = 0.8
                    self.connectionNode.opacity = 1; SCNTransaction.commit()
                }
            }
        } else if !skel.isEmpty {
            let (v, i) = Self.connectionGeo(positions: skel, threshold: threshold)
            placeLines(vertices: v, indices: i,
                       color: NeuralSceneManager.hardcodedImpulseColor(for: dominantEmotion(p)))
        }

        // Rebuild synapse bouton display with correct emotion color.
        // We rebuild the full SCNGeometry rather than patching the existing material
        // because .alpha blendMode requires BOTH diffuse and emission to be updated
        // simultaneously — partial updates leave the wrong color.
        let emotion  = dominantEmotion(p)
        let impColor = NeuralSceneManager.hardcodedImpulseColor(for: emotion)
        if !synapsePositions.isEmpty {
            buildSynapseDisplay(positions: synapsePositions, color: impColor)
        }

        // Synapse impulse trails
        let cfg = impulseConfig(for: emotion)
        startImpulseLoop(color: impColor, cfg: cfg)
    }

    // MARK: - Emotion-specific SCNAction per group

    private func applyEmotionActions(to node: SCNNode, index i: Int,
                                     params p: EmotionParameters, animated: Bool) {
        let phase = Float(i) * 2 * .pi / Float(groupCount)   // wave phase offset
        let fi    = Float(i)

        switch dominantEmotion(p) {

        case .calm:
            // ── Slow synchronized wave: all groups gently ripple in unison ──
            let amp   = CGFloat(0.03)
            let speed = p.pulseSpeed   // ~2.5s → slow
            let action = SCNAction.repeatForever(SCNAction.customAction(duration: speed * 2) { nd, t in
                let tf = Float(t / speed)
                let x  = sin(tf * 2 * .pi + phase) * Float(amp) * 0.6
                let y  = cos(tf * 2 * .pi + phase) * Float(amp) * 0.4
                nd.position = SCNVector3(x, y, 0)
            })
            node.runAction(action, forKey: "motion")
            node.opacity = 1.0
            // Gentle size pulse
            let ps = SCNAction.scale(to: 1 + amp * 0.3, duration: speed * 0.5)
            let pb = SCNAction.scale(to: 1.0, duration: speed * 0.5)
            ps.timingMode = .easeInEaseOut; pb.timingMode = .easeInEaseOut
            node.runAction(.repeatForever(.sequence([ps, pb])), forKey: "pulse")

            // ── Glow: soft breathing brightness — phase-offset per group ──
            // Oscillates between 55% and 85% of base intensity
            let priC = p.primaryUIColor
            let glowLo = Float(0.55); let glowHi = Float(0.85)
            let glowBreath = SCNAction.repeatForever(SCNAction.customAction(duration: speed * 2) { [weak self] nd, t in
                guard let self else { return }
                let tf   = Float(t / speed)
                let bright = glowLo + (glowHi - glowLo) * (0.5 + 0.5 * sin(tf * 2 * .pi + phase))
                nd.geometry?.firstMaterial?.emission.contents = self.cloudGlowColor(from: priC, intensity: bright)
            })
            node.runAction(glowBreath, forKey: "glow")

        case .anxiety:
            // ── Chaotic rapid multi-frequency jitter — each group is DIFFERENT ──
            let freqMult  = 1.5 + fi * 0.6
            let ampMult   = 0.06 + fi * 0.015
            let chaosAmp  = CGFloat(ampMult)
            let freqA = 2.31 * freqMult;  let freqB = 3.07 * (8 - fi) / 4
            let freqC = 1.89 * freqMult + 0.5

            let action = SCNAction.repeatForever(SCNAction.customAction(duration: 100) { nd, t in
                let tf = Float(t)
                let x = sin(tf * freqA + phase) * cos(tf * freqB) * Float(chaosAmp)
                let y = cos(tf * freqC + phase) * sin(tf * freqA * 0.7) * Float(chaosAmp * 0.8)
                let z = sin(tf * freqB * 1.3 + phase) * Float(chaosAmp * 0.5)
                nd.position = SCNVector3(x, y, z)
            })
            node.runAction(action, forKey: "motion")

            // Opacity flash — irregular "neural firing" bursts
            let flashOn  = SCNAction.fadeOpacity(to: 1.0, duration: 0.05 + Double(fi) * 0.02)
            let flashOff = SCNAction.fadeOpacity(to: 0.55, duration: 0.08 + Double(fi) * 0.03)
            let pause    = SCNAction.wait(duration: 0.12 + Double(fi) * 0.04)
            node.runAction(.repeatForever(.sequence([flashOn, flashOff, pause])), forKey: "flash")

            // Rapid large scale bursts
            let sUp = SCNAction.scale(to: 1.0 + CGFloat(ampMult * 3), duration: p.pulseSpeed * 0.25)
            let sDn = SCNAction.scale(to: 1.0, duration: p.pulseSpeed * 0.25)
            sUp.timingMode = .easeIn; sDn.timingMode = .easeOut
            node.runAction(.repeatForever(.sequence([sUp, sDn])), forKey: "pulse")

            // ── Glow: electric white-hot spikes — each group fires at different freq ──
            // Base stays at 1.0 intensity; spikes shoot to 1.4 (overblown white)
            // then dim to 0.6, rhythm driven by per-group freqA so they never sync
            let priC2 = p.primaryUIColor
            let spikeFreq = freqA * 0.18   // slow down to visible glow-flicker range
            let glowSpike = SCNAction.repeatForever(SCNAction.customAction(duration: 100) { [weak self] nd, t in
                guard let self else { return }
                let tf = Float(t)
                // Two overlapping sin waves create irregular spiking pattern
                let raw = 0.70 + 0.30 * sin(tf * spikeFreq + phase)
                            + 0.15 * sin(tf * spikeFreq * 2.7 + phase * 1.3)
                let bright = max(0.4, min(1.4, raw))   // clamp; >1.0 → white-hot
                nd.geometry?.firstMaterial?.emission.contents = self.cloudGlowColor(from: priC2, intensity: Float(bright))
            })
            node.runAction(glowSpike, forKey: "glow")

        case .sadness:
            // ── Most groups dim/frozen; a few barely stir ──
            let opacity: CGFloat = i < 5 ? 0.22 + CGFloat(i) * 0.05 : 0.55
            SCNTransaction.begin(); SCNTransaction.animationDuration = animated ? 2.0 : 0
            node.opacity = opacity; SCNTransaction.commit()

            if i >= 5 {
                let slowAmp = CGFloat(0.015)
                let action  = SCNAction.repeatForever(SCNAction.customAction(duration: 8) { nd, t in
                    let tf = Float(t) * 0.3
                    nd.position = SCNVector3(sin(tf + phase) * Float(slowAmp),
                                             cos(tf * 0.7 + phase) * Float(slowAmp * 0.6), 0)
                })
                node.runAction(action, forKey: "motion")
            }
            // Very slow scale droop
            let sd = SCNAction.scale(to: 0.88, duration: p.pulseSpeed * 0.5)
            let su = SCNAction.scale(to: 1.0,  duration: p.pulseSpeed * 0.5)
            sd.timingMode = .easeInEaseOut; su.timingMode = .easeInEaseOut
            node.runAction(.repeatForever(.sequence([sd, su])), forKey: "pulse")

            // ── Glow: barely-there flicker — each group slightly different dim level ──
            // Groups fade between 0.15 and 0.40 very slowly; higher index = slightly brighter
            let priC3 = p.primaryUIColor
            let dimLo = Float(0.12) + fi * 0.015
            let dimHi = Float(0.32) + fi * 0.020
            let slowCycle = p.pulseSpeed * 1.8
            let glowDim = SCNAction.repeatForever(SCNAction.customAction(duration: slowCycle) { [weak self] nd, t in
                guard let self else { return }
                let tf = Float(t / slowCycle)
                let bright = dimLo + (dimHi - dimLo) * (0.5 + 0.5 * sin(tf * 2 * .pi + phase))
                nd.geometry?.firstMaterial?.emission.contents = self.cloudGlowColor(from: priC3, intensity: bright)
            })
            node.runAction(glowDim, forKey: "glow")

        case .love:
            // ── Cascading wave: groups fire sequentially → rhythmic cascade ──
            let delay  = Double(i) * p.pulseSpeed / Double(groupCount)
            let medAmp = CGFloat(0.055)
            let wave   = SCNAction.repeatForever(SCNAction.customAction(duration: p.pulseSpeed * 1.5) { nd, t in
                let tf = Float(t / p.pulseSpeed)
                let x  = sin(tf * 2 * .pi + phase) * Float(medAmp * 0.7)
                let y  = cos(tf * 2 * .pi + phase) * Float(medAmp * 0.5)
                nd.position = SCNVector3(x, y, sin(tf * .pi + phase) * Float(medAmp * 0.3))
            })
            let waitAct = SCNAction.wait(duration: delay)
            node.runAction(.sequence([waitAct, wave]), forKey: "motion")
            node.opacity = 1.0

            // Colour + glow cascade unified — hue blends pri→sec while brightness rides 0.65→1.10
            // Both driven by the same sin wave so peak brightness aligns with warm-gold hue shift
            let priC4  = p.primaryUIColor
            let secC4  = p.secondaryUIColor
            let glowLo4 = Float(0.65); let glowHi4 = Float(1.10)
            let unified = SCNAction.repeatForever(SCNAction.customAction(duration: p.pulseSpeed) { [weak self] nd, t in
                guard let self else { return }
                let tf     = Float(t / p.pulseSpeed)
                let bright = glowLo4 + (glowHi4 - glowLo4) * (0.5 + 0.5 * sin(tf * 2 * .pi + phase))
                let hueBlend = CGFloat(0.5 + 0.5 * sin(tf * 2 * .pi + phase))
                var pr: CGFloat = 0, pg: CGFloat = 0, pb: CGFloat = 0, pa: CGFloat = 0
                var sr: CGFloat = 0, sg: CGFloat = 0, sb: CGFloat = 0, sa: CGFloat = 0
                priC4.getRed(&pr, green: &pg, blue: &pb, alpha: &pa)
                secC4.getRed(&sr, green: &sg, blue: &sb, alpha: &sa)
                let blended = UIColor(red: pr + (sr - pr) * hueBlend,
                                     green: pg + (sg - pg) * hueBlend,
                                     blue: pb + (sb - pb) * hueBlend, alpha: 1)
                nd.geometry?.firstMaterial?.emission.contents = self.cloudGlowColor(from: blended, intensity: bright)
            })
            let glowSeq = SCNAction.sequence([.wait(duration: delay), .repeatForever(unified)])
            node.runAction(glowSeq, forKey: "glow")

            // Heartbeat-like scale pulse
            let h1 = SCNAction.scale(to: 1.12, duration: p.pulseSpeed * 0.18)
            let h2 = SCNAction.scale(to: 1.00, duration: p.pulseSpeed * 0.18)
            let h3 = SCNAction.scale(to: 1.07, duration: p.pulseSpeed * 0.12)
            let h4 = SCNAction.scale(to: 1.00, duration: p.pulseSpeed * 0.52)
            [h1,h2,h3,h4].forEach { $0.timingMode = .easeInEaseOut }
            let heartbeat = SCNAction.repeatForever(.sequence([
                .wait(duration: delay), h1, h2, h3, h4
            ]))
            node.runAction(heartbeat, forKey: "pulse")

        case .happy:
            // ── Dopamine/serotonin synchronized reward bursts ──
            // Gamma-like (40 Hz analogue) upward-cascading waves: groups fire in
            // ascending phase order → "reward signal propagating through cortex".
            // Brighter, faster, more energetic than calm but well-coordinated.
            let happyDelay = Double(i) * p.pulseSpeed / Double(groupCount) * 0.6
            let happyAmp   = CGFloat(0.045)
            let happyWave  = SCNAction.repeatForever(SCNAction.customAction(duration: p.pulseSpeed * 1.2) { nd, t in
                let tf = Float(t / p.pulseSpeed)
                // Upward-biased motion — joy literally lifts neural activity
                let x = sin(tf * 2 * .pi + phase) * Float(happyAmp * 0.6)
                let y = abs(sin(tf * 2 * .pi + phase)) * Float(happyAmp) - Float(happyAmp * 0.2)
                let z = cos(tf * 2 * .pi + phase) * Float(happyAmp * 0.3)
                nd.position = SCNVector3(x, y, z)
            })
            let happyWait = SCNAction.wait(duration: happyDelay)
            node.runAction(.sequence([happyWait, happyWave]), forKey: "motion")
            node.opacity = 1.0

            // Bouncy upbeat scale — energetic without being erratic
            let bu1 = SCNAction.scale(to: 1.10, duration: p.pulseSpeed * 0.22)
            let bu2 = SCNAction.scale(to: 0.97, duration: p.pulseSpeed * 0.14)
            let bu3 = SCNAction.scale(to: 1.04, duration: p.pulseSpeed * 0.10)
            let bu4 = SCNAction.scale(to: 1.00, duration: p.pulseSpeed * 0.54)
            [bu1,bu2,bu3,bu4].forEach { $0.timingMode = .easeInEaseOut }
            node.runAction(.repeatForever(.sequence([
                .wait(duration: happyDelay), bu1, bu2, bu3, bu4
            ])), forKey: "pulse")

            // ── Glow: bright cascading amber warmth ──
            // Rides 0.70→1.05 with upward phase, so brightness peaks match the upward motion.
            // Groups cascade so the whole neuron "lights up" progressively.
            let priCH  = p.primaryUIColor
            let secCH  = p.secondaryUIColor
            let hLo = Float(0.70); let hHi = Float(1.05)
            let happyGlow = SCNAction.repeatForever(SCNAction.customAction(duration: p.pulseSpeed) { [weak self] nd, t in
                guard let self else { return }
                let tf = Float(t / p.pulseSpeed)
                let bright     = hLo + (hHi - hLo) * (0.5 + 0.5 * sin(tf * 2 * .pi + phase))
                let hueBlend   = CGFloat(max(0, sin(tf * 2 * .pi + phase)))   // 0→1 drives warm→amber
                var pr: CGFloat = 0, pg: CGFloat = 0, pb: CGFloat = 0, pa: CGFloat = 0
                var sr: CGFloat = 0, sg: CGFloat = 0, sb: CGFloat = 0
                priCH.getRed(&pr, green: &pg, blue: &pb, alpha: &pa)
                secCH.getRed(&sr, green: &sg, blue: &sb, alpha: &pa)
                let blended = UIColor(red: pr + (sr - pr) * hueBlend,
                                     green: pg + (sg - pg) * hueBlend,
                                     blue: pb + (sb - pb) * hueBlend, alpha: 1)
                nd.geometry?.firstMaterial?.emission.contents = self.cloudGlowColor(from: blended, intensity: bright)
            })
            node.runAction(.sequence([.wait(duration: happyDelay), .repeatForever(happyGlow)]), forKey: "glow")

        case .angry:
            // ── Amygdala-driven aggressive rhythmic bursts ──
            // Unlike anxiety (pure chaos), anger is DIRECTED: regular high-amplitude
            // strikes with forceful rebounds — the amygdala fires in synchronized
            // bursts that override prefrontal modulation.
            let angryFreq = 1.8 + fi * 0.25     // each group slightly different → overlapping attack waves
            let angryAmp  = CGFloat(0.07 + Double(fi) * 0.008)

            let angryMotion = SCNAction.repeatForever(SCNAction.customAction(duration: 100) { nd, t in
                let tf = Float(t)
                // Forceful strike pattern: fast attack, slow decay (like anger flare)
                let rawX = sin(tf * angryFreq + phase)
                let rawY = cos(tf * angryFreq * 0.85 + phase)
                // Sharpen the waveform → more abrupt strikes than sinusoidal
                let x = (rawX > 0 ? pow(rawX, 0.6) : -pow(-rawX, 0.6)) * Float(angryAmp)
                let y = (rawY > 0 ? pow(rawY, 0.6) : -pow(-rawY, 0.6)) * Float(angryAmp * 0.7)
                let z = sin(tf * angryFreq * 1.2 + phase) * Float(angryAmp * 0.4)
                nd.position = SCNVector3(x, y, z)
            })
            node.runAction(angryMotion, forKey: "motion")

            // Aggressive strike pulse — hard in, hard out
            let aUp = SCNAction.scale(to: 1.0 + CGFloat(0.08 + Double(fi) * 0.01),
                                      duration: p.pulseSpeed * 0.20)
            let aDn = SCNAction.scale(to: 1.0, duration: p.pulseSpeed * 0.80)
            aUp.timingMode = .easeIn; aDn.timingMode = .easeOut
            node.runAction(.repeatForever(.sequence([aUp, aDn])), forKey: "pulse")
            node.opacity = 1.0

            // Opacity throbs between full and 0.70 on each strike
            let aFlashOn  = SCNAction.fadeOpacity(to: 1.00, duration: p.pulseSpeed * 0.18)
            let aFlashOff = SCNAction.fadeOpacity(to: 0.70, duration: p.pulseSpeed * 0.82)
            node.runAction(.repeatForever(.sequence([aFlashOn, aFlashOff])), forKey: "flash")

            // ── Glow: crimson flare with red-orange discharge on each strike ──
            // Peaks at 1.3 (white-hot red tip) then bleeds to orange at 0.65
            let priCA  = p.primaryUIColor  // deep crimson
            let secCA  = p.secondaryUIColor  // red-orange
            let aLo = Float(0.65); let aHi = Float(1.35)  // >1 → overblown red-white
            let angryGlow = SCNAction.repeatForever(SCNAction.customAction(duration: p.pulseSpeed) { [weak self] nd, t in
                guard let self else { return }
                let tf = Float(t / p.pulseSpeed)
                // Fast-attack waveform mirrors the strike motion
                let rawSin = 0.5 + 0.5 * sin(tf * 2 * .pi + phase)
                let sharp  = pow(rawSin, 0.5)   // sharpen peak
                let bright = aLo + (aHi - aLo) * Float(sharp)
                // At peak brightness, discharge bleeds toward orange secondary
                let hueBlend = CGFloat(sharp)
                var pr: CGFloat = 0, pg: CGFloat = 0, pb: CGFloat = 0, pa: CGFloat = 0
                var sr: CGFloat = 0, sg: CGFloat = 0, sb: CGFloat = 0
                priCA.getRed(&pr, green: &pg, blue: &pb, alpha: &pa)
                secCA.getRed(&sr, green: &sg, blue: &sb, alpha: &pa)
                let blended = UIColor(red: pr + (sr - pr) * hueBlend * 0.4,
                                     green: pg + (sg - pg) * hueBlend * 0.4,
                                     blue: pb + (sb - pb) * hueBlend * 0.2, alpha: 1)
                nd.geometry?.firstMaterial?.emission.contents = self.cloudGlowColor(from: blended, intensity: bright)
            })
            node.runAction(angryGlow, forKey: "glow")
        }
    }

    /// Match EmotionParameters back to the nearest Emotion for switch logic
    private func dominantEmotion(_ p: EmotionParameters) -> Emotion {
        let emotions = Emotion.allCases
        return emotions.min(by: {
            let aP = EmotionParameters.make(for: $0)
            let bP = EmotionParameters.make(for: $1)
            return abs(aP.turbulence - p.turbulence) < abs(bP.turbulence - p.turbulence)
        }) ?? .calm
    }

    /// Hardcoded vivid UIColor for impulse particles — six distinct colours that
    /// are guaranteed to render correctly regardless of brightness or blend math.
    static func hardcodedImpulseColor(for emotion: Emotion) -> UIColor {
        switch emotion {
        case .calm:    return UIColor(red: 0.20, green: 0.55, blue: 0.95, alpha: 1) // app blue
        case .anxiety: return UIColor(red: 0.95, green: 0.28, blue: 0.08, alpha: 1) // app orange
        case .sadness: return UIColor(red: 0.38, green: 0.40, blue: 0.58, alpha: 1) // app muted blue
        case .love:    return UIColor(red: 0.95, green: 0.38, blue: 0.65, alpha: 1) // app pink
        case .happy:   return UIColor(red: 0.98, green: 0.78, blue: 0.10, alpha: 1) // app amber-gold
        case .angry:   return UIColor(red: 0.88, green: 0.10, blue: 0.18, alpha: 1) // app crimson
        }
    }

    // MARK: - Impulse Config

    private struct ImpulseConfig {
        let segmentDuration: Double   // seconds to traverse one path segment
        let launchInterval:  Double   // seconds between successive impulse launches
        let trailCount:      Int      // trailing clusters per launch (creates comet effect)
        let trailDelay:      Double   // seconds between each trail cluster
        let particleCount:   Int      // points per cluster node
        let brightness:      Float    // emission intensity (>1 = white-hot overblown)
    }

    private func impulseConfig(for emotion: Emotion) -> ImpulseConfig {
        switch emotion {
        case .calm:
            // Slow deliberate signals, 2-glow trail, medium density
            return ImpulseConfig(segmentDuration: 0.28, launchInterval: 0.09,
                                 trailCount: 2, trailDelay: 0.14,
                                 particleCount: 20, brightness: 0.85)
        case .anxiety:
            // Frantic rapid-fire bursts everywhere at once
            return ImpulseConfig(segmentDuration: 0.06, launchInterval: 0.03,
                                 trailCount: 5, trailDelay: 0.04,
                                 particleCount: 28, brightness: 1.55)
        case .sadness:
            // Sparse, slow, barely-there signals
            return ImpulseConfig(segmentDuration: 0.60, launchInterval: 0.55,
                                 trailCount: 1, trailDelay: 0.35,
                                 particleCount: 12, brightness: 0.30)
        case .love:
            // Warm cascading rhythm
            return ImpulseConfig(segmentDuration: 0.22, launchInterval: 0.06,
                                 trailCount: 3, trailDelay: 0.10,
                                 particleCount: 24, brightness: 1.20)
        case .happy:
            // Bright energetic bursts all over
            return ImpulseConfig(segmentDuration: 0.14, launchInterval: 0.05,
                                 trailCount: 3, trailDelay: 0.08,
                                 particleCount: 24, brightness: 1.25)
        case .angry:
            // Explosive strike-and-rebound — heavy, overblown
            return ImpulseConfig(segmentDuration: 0.09, launchInterval: 0.03,
                                 trailCount: 5, trailDelay: 0.05,
                                 particleCount: 30, brightness: 1.50)
        }
    }

    // MARK: - Synapse Position Builder (nonisolated)

    /// Returns all synaptic bouton positions spread across the neuron structure.
    nonisolated static func buildSynapsePositions() -> [SCNVector3] {
        var pts = [SCNVector3]()
        pts.append(SCNVector3(0, 0, 0))   // soma

        for d in 0..<6 {
            let ba  = Float(d) * 2 * Float.pi / 6
            let zv  = sin(Float(d) * 1.4) * 0.3
            let dir = norm(SCNVector3(cos(ba), sin(ba), zv))
            var tip = SCNVector3(dir.x*0.18, dir.y*0.18, dir.z*0.18)
            for _ in 0..<4 {
                tip = SCNVector3(tip.x+dir.x*0.21, tip.y+dir.y*0.21, tip.z+dir.z*0.21)
                pts.append(tip)
            }
            for s: Float in [-1, 1] {
                let pa = ba + s * .pi / 3.5
                let sd = norm(SCNVector3(cos(pa), sin(pa), zv*0.5))
                var st = tip
                for _ in 0..<3 {
                    st = SCNVector3(st.x+sd.x*0.17, st.y+sd.y*0.17, st.z+sd.z*0.17)
                    pts.append(st)
                }
            }
        }
        var at = SCNVector3(0, -0.20, 0)
        let ad = norm(SCNVector3(0.04, -1, 0.03))
        for _ in 0..<8 {
            at = SCNVector3(at.x+ad.x*0.27, at.y+ad.y*0.27, at.z+ad.z*0.27)
            pts.append(at)
        }
        for t in 0..<5 {
            let ta = Float(t) * 2 * Float.pi / 5
            let td = norm(SCNVector3(cos(ta)*0.6, -0.6, sin(ta)*0.6))
            var tt = at
            for _ in 0..<2 {
                tt = SCNVector3(tt.x+td.x*0.14, tt.y+td.y*0.14, tt.z+td.z*0.14)
                pts.append(tt)
            }
        }
        return pts   // ~79 bouton positions spread across full neuron
    }

    /// Generates short 2-hop paths between adjacent boutons (dist < threshold).
    /// This creates ~200 short synapse-to-synapse paths for dense local signalling.
    nonisolated static func buildShortImpulsePaths(from positions: [SCNVector3]) -> [[SCNVector3]] {
        var paths = [[SCNVector3]]()
        let threshold: Float = 0.45   // connect any two boutons within this range

        for i in 0..<positions.count {
            for j in (i+1)..<positions.count {
                let dx = positions[i].x - positions[j].x
                let dy = positions[i].y - positions[j].y
                let dz = positions[i].z - positions[j].z
                if sqrt(dx*dx + dy*dy + dz*dz) < threshold {
                    // Add slight random midpoint arc to each path
                    let mid = SCNVector3(
                        (positions[i].x + positions[j].x) * 0.5 + Float.random(in: -0.015...0.015),
                        (positions[i].y + positions[j].y) * 0.5 + Float.random(in: -0.015...0.015),
                        (positions[i].z + positions[j].z) * 0.5 + Float.random(in: -0.015...0.015)
                    )
                    // Both directions — bidirectional traffic like real synapses
                    paths.append([positions[i], mid, positions[j]])
                    paths.append([positions[j], mid, positions[i]])
                }
            }
        }
        return paths
    }

    // MARK: - Synapse Bouton Display

    /// Creates a persistent point-cloud node showing all bouton positions as
    /// larger, brighter points — giving visible synapse "buttons" on the structure.
    private func buildSynapseDisplay(positions: [SCNVector3], color: UIColor) {
        synapseNode.removeFromParentNode()
        guard !positions.isEmpty else { return }
        let src  = SCNGeometrySource(vertices: positions)
        let idxs = Array(Int32(0)..<Int32(positions.count))
        let elem = SCNGeometryElement(indices: idxs, primitiveType: .point)
        elem.pointSize                     = 10.0
        elem.minimumPointScreenSpaceRadius = 3.0
        elem.maximumPointScreenSpaceRadius = 18.0
        let geo = SCNGeometry(sources: [src], elements: [elem])
        let mat = SCNMaterial()
        mat.lightingModel       = .constant
        mat.diffuse.contents    = color          // primary render color
        mat.emission.contents   = color          // self-illuminated
        mat.blendMode           = .alpha         // NOT .add — prevents white washout
        mat.writesToDepthBuffer = false
        geo.materials = [mat]
        synapseNode = SCNNode(geometry: geo)
        impulseRoot.addChildNode(synapseNode)
    }

    // MARK: - Impulse Node Factory

    /// Tight point-cloud cluster that travels as one luminous blob along a path.
    /// Uses .alpha blend (not .add) so the hardcoded emotion color renders at
    /// its exact RGB value without being washed to white by nearby cloud particles.
    private func makeImpulseCloudNode(positions: [SCNVector3], color: UIColor) -> SCNNode {
        let src  = SCNGeometrySource(vertices: positions)
        let idxs = Array(Int32(0)..<Int32(positions.count))
        let elem = SCNGeometryElement(indices: idxs, primitiveType: .point)
        elem.pointSize                   = 2.5
        elem.minimumPointScreenSpaceRadius = 0.8
        elem.maximumPointScreenSpaceRadius = 5.5
        let geo = SCNGeometry(sources: [src], elements: [elem])
        let mat = SCNMaterial()
        mat.lightingModel       = .constant
        mat.diffuse.contents    = color          // primary color channel
        mat.emission.contents   = color          // self-illuminated glow
        mat.blendMode           = .alpha         // NOT .add — prevents white washout
        mat.writesToDepthBuffer = false
        geo.materials = [mat]
        return SCNNode(geometry: geo)
    }

    /// Creates a star/diamond shaped impulse node using the given color DIRECTLY.
    /// No brightness scaling, no color math — the color you pass is exactly
    /// what gets rendered.
    private func makeImpulseNode(color: UIColor, count: Int) -> SCNNode {
        var pts = [SCNVector3]()
        let stepsPerArm = max(3, count / 14)
        let armLen: Float = 0.024

        for step in 0..<stepsPerArm {
            let t = Float(step + 1) / Float(stepsPerArm)
            let r = t * armLen
            pts += [
                SCNVector3( r,  0,  0), SCNVector3(-r,  0,  0),
                SCNVector3( 0,  r,  0), SCNVector3( 0, -r,  0),
                SCNVector3( 0,  0,  r), SCNVector3( 0,  0, -r),
            ]
            let d = r * 0.65
            pts += [
                SCNVector3( d,  d,  0), SCNVector3(-d,  d,  0),
                SCNVector3( d, -d,  0), SCNVector3(-d, -d,  0),
                SCNVector3( d,  0,  d), SCNVector3(-d,  0,  d),
                SCNVector3( d,  0, -d), SCNVector3(-d,  0, -d),
            ]
        }
        pts.append(SCNVector3(0, 0, 0))
        let node = makeImpulseCloudNode(positions: pts, color: color)

        // Attach a tiny omni light in the emotion color for a soft glow radius
        let light = SCNLight()
        light.type = .omni
        light.color = color
        light.intensity = 120          // subtle, not blinding
        light.attenuationStartDistance = 0.0
        light.attenuationEndDistance   = 0.25   // gentle falloff radius
        let lightNode = SCNNode()
        lightNode.light = light
        node.addChildNode(lightNode)

        return node
    }

    // MARK: - Launch a single impulse along one path

    /// Launches one impulse sparkle along a path. Color is used as-is.
    private func launchImpulse(path: [SCNVector3], color: UIColor, cfg: ImpulseConfig) {
        guard path.count >= 2 else { return }
        let node = makeImpulseNode(color: color, count: cfg.particleCount)
        node.position = path[0]
        impulseRoot.addChildNode(node)

        var actions = [SCNAction]()
        for i in 1..<path.count {
            let step = SCNAction.move(to: path[i], duration: cfg.segmentDuration)
            step.timingMode = .easeInEaseOut
            actions.append(step)
        }
        actions.append(.removeFromParentNode())
        node.runAction(.sequence(actions))
    }

    // MARK: - Continuous impulse loop

    private func startImpulseLoop(color: UIColor, cfg: ImpulseConfig) {
        impulseTask?.cancel()
        impulseRoot.enumerateChildNodes { [weak self] node, _ in
            guard node !== self?.synapseNode else { return }
            node.removeFromParentNode()
        }

        let paths = synapsePaths
        guard !paths.isEmpty else { return }

        // Immediate burst so the neuron is alive from the first frame
        let burst = min(30, paths.count)
        let shuffled = paths.shuffled()
        for i in 0..<burst {
            launchImpulse(path: shuffled[i], color: color, cfg: cfg)
        }

        impulseTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                guard let path = paths.randomElement() else { continue }

                // All impulses use the same vivid emotion color
                self.launchImpulse(path: path, color: color, cfg: cfg)

                // Trailing impulses — same color, staggered timing
                for t in 1..<cfg.trailCount {
                    let delay = Double(t) * cfg.trailDelay
                    Task { @MainActor [weak self] in
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        guard !Task.isCancelled else { return }
                        self?.launchImpulse(path: path, color: color, cfg: cfg)
                    }
                }

                try? await Task.sleep(
                    nanoseconds: UInt64(cfg.launchInterval * 1_000_000_000))
            }
        }
    }

    // MARK: - Camera Reset

    /// Stored during makeUIView so resetCamera() can act on the live view.
    private(set) weak var attachedView: SCNView?

    func attach(view: SCNView) { attachedView = view }

    func resetCamera() {
        guard let v   = attachedView,
              let cam = v.scene?.rootNode.childNode(withName: "mainCam",
                                                    recursively: false)
        else { return }

        // Force SCNView back to the named camera so our changes take effect.
        v.pointOfView = cam

        // Stop rotation so we can snap sphereRoot to a fixed orientation.
        sphereRoot.removeAllActions()

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.7
        SCNTransaction.animationTimingFunction =
            CAMediaTimingFunction(name: .easeInEaseOut)
        // Fixed camera pose — always the same view
        cam.position    = SCNVector3(0, -0.4, 4.0)
        cam.eulerAngles = SCNVector3(0, 0, 0)
        cam.camera?.fieldOfView = 65
        // Reset sphere to canonical orientation — same starting angle every time
        sphereRoot.eulerAngles = SCNVector3(0, 0, 0)
        SCNTransaction.commit()

        // Restart rotation from the canonical orientation after animation settles
        let dur = currentParams.rotationDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            guard let self else { return }
            self.sphereRoot.runAction(.repeatForever(
                .rotateBy(x: 0.06, y: CGFloat(2 * Double.pi), z: 0.03,
                          duration: dur)
            ), forKey: "rot")
        }
    }

    // MARK: - Scene Graph

    private func placeLines(vertices: [SCNVector3], indices: [Int32],
                            color: UIColor = .white) {
        connectionNode.removeFromParentNode()
        guard !vertices.isEmpty else { return }
        let src  = SCNGeometrySource(vertices: vertices)
        let elem = SCNGeometryElement(indices: indices, primitiveType: .line)
        let geo  = SCNGeometry(sources: [src], elements: [elem])
        let mat  = SCNMaterial()
        mat.lightingModel     = .constant
        mat.emission.contents = color.withAlphaComponent(0.35)
        mat.blendMode         = .add
        mat.writesToDepthBuffer = false
        geo.materials = [mat]
        connectionNode = SCNNode(geometry: geo)
        sphereRoot.addChildNode(connectionNode)
    }

    // MARK: - Static Helpers (nonisolated, background-safe)

    nonisolated private static func neuronSkeleton() -> [SCNVector3] {
        var pts = [SCNVector3]()
        for i in 0..<8 { let a=Float(i)*2 * Float.pi/8; pts.append(SCNVector3(cos(a)*0.12,sin(a)*0.12,0)) }
        pts.append(.init(0,0,0))
        for d in 0..<6 {
            let ba=Float(d)*2 * Float.pi/6; let zv=sin(Float(d)*1.4)*0.3
            let dir=norm(SCNVector3(cos(ba),sin(ba),zv))
            var tip=SCNVector3(dir.x*0.18,dir.y*0.18,dir.z*0.18)
            for _ in 0..<4 { tip=SCNVector3(tip.x+dir.x*0.21,tip.y+dir.y*0.21,tip.z+dir.z*0.21); pts.append(tip) }
            for s in [-1,1] as [Float] {
                let pa=ba+s * .pi/3.5; let sd=norm(SCNVector3(cos(pa),sin(pa),zv*0.5))
                var st=tip
                for _ in 0..<3 { st=SCNVector3(st.x+sd.x*0.17,st.y+sd.y*0.17,st.z+sd.z*0.17); pts.append(st) }
            }
        }
        var at=SCNVector3(0,-0.20,0); let ad=norm(SCNVector3(0.04,-1,0.03))
        for _ in 0..<8 { at=SCNVector3(at.x+ad.x*0.27,at.y+ad.y*0.27,at.z+ad.z*0.27); pts.append(at) }
        for t in 0..<5 {
            let ta=Float(t)*2 * Float.pi/5; let td=norm(SCNVector3(cos(ta)*0.6,-0.6,sin(ta)*0.6))
            var tt=at
            for _ in 0..<2 { tt=SCNVector3(tt.x+td.x*0.14,tt.y+td.y*0.14,tt.z+td.z*0.14); pts.append(tt) }
        }
        return pts
    }

    nonisolated private static func neuronCloud(count: Int) -> [SCNVector3] {
        var pts=[SCNVector3]()
        let somaN=count/5; let dendN=count*11/20; let axonN=count-somaN-dendN
        pts += sphere(c:.init(0,0,0), r:0.22, n:somaN)
        let perD=dendN/6
        for d in 0..<6 {
            let ba=Float(d)*2 * Float.pi/6; let zv=sin(Float(d)*1.4)*0.3
            let dir=norm(SCNVector3(cos(ba),sin(ba),zv))
            let ts=SCNVector3(dir.x*0.22,dir.y*0.22,dir.z*0.22)
            let te=SCNVector3(dir.x*1.05,dir.y*1.05,dir.z*1.05)
            pts+=cylinder(a:ts,b:te,r:0.07,n:perD/2)
            for s in [-1,1] as [Float] {
                let pa=ba+s * .pi/3.5; let sd=norm(SCNVector3(cos(pa),sin(pa),zv*0.5))
                let ss=lerp(ts,te,t:0.55)
                let se=SCNVector3(ss.x+sd.x*0.38,ss.y+sd.y*0.38,ss.z+sd.z*0.38)
                pts+=cylinder(a:ss,b:se,r:0.05,n:perD/4)
            }
        }
        let axS=SCNVector3(0,-0.22,0); let axE=SCNVector3(0.09,-2.25,0.07)
        pts+=cylinder(a:axS,b:axE,r:0.05,n:axonN*3/4)
        let perT=max(1,axonN/4/5)
        for t in 0..<5 {
            let ta=Float(t)*2 * Float.pi/5; let td=norm(SCNVector3(cos(ta)*0.6,-0.6,sin(ta)*0.6))
            let te=SCNVector3(axE.x+td.x*0.32,axE.y+td.y*0.32,axE.z+td.z*0.32)
            pts+=cylinder(a:axE,b:te,r:0.03,n:perT)
        }
        return pts
    }

    nonisolated private static func sphere(c: SCNVector3, r: Float, n: Int) -> [SCNVector3] {
        (0..<n).map { _ in
            let rad=r*pow(Float.random(in:0...1),1.0/3.0)
            let th=Float.random(in:0...2 * .pi)
            let ph=acos(max(-1,min(1,2*Float.random(in:0...1)-1)))
            return SCNVector3(c.x+rad*sin(ph)*cos(th),c.y+rad*sin(ph)*sin(th),c.z+rad*cos(ph))
        }
    }

    nonisolated private static func cylinder(a: SCNVector3, b: SCNVector3, r: Float, n: Int) -> [SCNVector3] {
        guard n > 0 else { return [] }
        let dx=b.x-a.x,dy=b.y-a.y,dz=b.z-a.z
        let len=sqrt(dx*dx+dy*dy+dz*dz); guard len>0.0001 else { return [] }
        let d=SCNVector3(dx/len,dy/len,dz/len)
        let up:SCNVector3=abs(d.y)<0.9 ? .init(0,1,0) : .init(1,0,0)
        let rg=norm(cross(d,up)); let fw=norm(cross(d,rg))
        return (0..<n).map { _ in
            let t=Float.random(in:0...1); let rv=r*sqrt(Float.random(in:0...1))
            let th=Float.random(in:0...2 * .pi); let cx=rv*cos(th),cy=rv*sin(th)
            return SCNVector3(a.x+d.x*t*len+rg.x*cx+fw.x*cy,
                              a.y+d.y*t*len+rg.y*cx+fw.y*cy,
                              a.z+d.z*t*len+rg.z*cx+fw.z*cy)
        }
    }

    nonisolated private static func lerp(_ a: SCNVector3,_ b: SCNVector3, t: Float)->SCNVector3 {
        SCNVector3(a.x+(b.x-a.x)*t,a.y+(b.y-a.y)*t,a.z+(b.z-a.z)*t)
    }
    nonisolated private static func norm(_ v: SCNVector3)->SCNVector3 {
        let l=sqrt(v.x*v.x+v.y*v.y+v.z*v.z); guard l>0.0001 else { return .init(0,1,0) }
        return SCNVector3(v.x/l,v.y/l,v.z/l)
    }
    nonisolated private static func cross(_ a: SCNVector3,_ b: SCNVector3)->SCNVector3 {
        SCNVector3(a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x)
    }
    nonisolated private static func connectionGeo(positions:[SCNVector3],threshold:Float)->([SCNVector3],[Int32]) {
        var verts=[SCNVector3](); var idxs=[Int32](); var n:Int32=0
        for i in 0..<positions.count {
            for j in (i+1)..<positions.count {
                let dx=positions[i].x-positions[j].x,dy=positions[i].y-positions[j].y,dz=positions[i].z-positions[j].z
                if sqrt(dx*dx+dy*dy+dz*dz)<threshold {
                    verts.append(positions[i]); verts.append(positions[j])
                    idxs.append(n); n+=1; idxs.append(n); n+=1
                }
            }
        }
        return (verts,idxs)
    }
}

// MARK: - NeuralSceneView

struct NeuralSceneView: UIViewRepresentable {
    let manager: NeuralSceneManager

    @MainActor func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        v.scene = manager.scene; v.allowsCameraControl = true
        v.autoenablesDefaultLighting = false; v.backgroundColor = .black
        v.antialiasingMode = .multisampling4X
        if manager.scene.rootNode.childNode(withName: "mainCam", recursively: false) == nil {
            let cam = SCNCamera(); cam.fieldOfView = 65
            let cn  = SCNNode(); cn.name = "mainCam"; cn.camera = cam
            cn.position = SCNVector3(0, -0.4, 4.0)
            manager.scene.rootNode.addChildNode(cn)
        }
        manager.attach(view: v)   // enables one-tap camera reset
        return v
    }
    @MainActor func updateUIView(_ uiView: SCNView, context: Context) {}
}
