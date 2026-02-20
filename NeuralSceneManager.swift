import SceneKit
import SwiftUI

// MARK: - NeuralSceneManager

@MainActor
final class NeuralSceneManager: ObservableObject {

    let scene = SCNScene()
    private let sphereRoot     = SCNNode()
    private let nodesContainer = SCNNode()
    private var connectionNode = SCNNode()
    private var particleNode   = SCNNode()

    private var nodePoints:    [SCNNode]    = []
    private var basePositions: [SCNVector3] = []
    private var currentParams: EmotionParameters = EmotionParameters.make(for: .calm)

    // MARK: Init

    init() {
        setupLighting()
        // Kick off the heavy O(n²) sphere build entirely on a background thread
        Task.detached { [weak self] in
            await self?.asyncBuildSphere(count: 160)
        }
    }

    // MARK: - Scene Lighting (main thread, fast)

    private func setupLighting() {
        scene.background.contents = UIColor.black
        scene.rootNode.addChildNode({ let n = SCNNode(); n.light = { let l = SCNLight(); l.type = .ambient; l.intensity = 80; return l }(); return n }())
        scene.rootNode.addChildNode({ let n = SCNNode(); n.light = { let l = SCNLight(); l.type = .omni; l.intensity = 400; return l }(); n.position = SCNVector3(3,3,3); return n }())
        sphereRoot.addChildNode(nodesContainer)
        scene.rootNode.addChildNode(sphereRoot)
    }

    // MARK: - Async Sphere Construction

    // Called from Task.detached → runs on cooperative thread pool (NOT main thread)
    nonisolated private func asyncBuildSphere(count: Int) async {
        // All heavy math happens HERE — pure structs, no SceneKit scene graph
        let positions = Self.fibonacciPositions(count: count, radius: 1.0)
        let (vertices, indices) = Self.connectionGeometry(positions: positions, threshold: 0.62)

        // Only after math is done, hop to main to touch SceneKit
        await MainActor.run { [weak self] in
            guard let self else { return }
            self.basePositions = positions
            self.placeNodes(positions: positions)
            self.placeConnections(vertices: vertices, indices: indices)
            self.buildParticles()
            self.applyParameters(EmotionParameters.make(for: .calm), animated: false)
        }
    }

    // MARK: - Static (background-safe) computation

    nonisolated private static func fibonacciPositions(count: Int, radius: Float) -> [SCNVector3] {
        var out = [SCNVector3]()
        out.reserveCapacity(count)
        let golden = Float((1.0 + sqrt(5.0)) / 2.0)
        for i in 0..<count {
            let theta = 2.0 * Float.pi * Float(i) / golden
            let phi   = acos(1.0 - 2.0 * Float(i + 1) / Float(count + 1))
            out.append(SCNVector3(sin(phi)*cos(theta)*radius,
                                  sin(phi)*sin(theta)*radius,
                                  cos(phi)*radius))
        }
        return out
    }

    nonisolated private static func connectionGeometry(positions: [SCNVector3],
                                           threshold: Float) -> ([SCNVector3], [Int32]) {
        var verts = [SCNVector3](); var idxs = [Int32](); var n: Int32 = 0
        let count = positions.count
        for i in 0..<count {
            for j in (i+1)..<count {
                if dist(positions[i], positions[j]) < threshold {
                    verts.append(positions[i]); verts.append(positions[j])
                    idxs.append(n); n += 1; idxs.append(n); n += 1
                }
            }
        }
        return (verts, idxs)
    }

    nonisolated private static func dist(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        let dx=a.x-b.x; let dy=a.y-b.y; let dz=a.z-b.z
        return sqrt(dx*dx + dy*dy + dz*dz)
    }

    // MARK: - Scene Graph (main-thread only)

    private func placeNodes(positions: [SCNVector3]) {
        nodePoints.forEach { $0.removeFromParentNode() }
        nodePoints.removeAll()
        for pos in positions {
            let geo = SCNSphere(radius: 0.012)
            let mat = SCNMaterial()
            mat.lightingModel = .constant
            mat.emission.contents = UIColor.white
            geo.materials = [mat]
            let node = SCNNode(geometry: geo)
            node.position = pos
            nodesContainer.addChildNode(node)
            nodePoints.append(node)
        }
    }

    private func placeConnections(vertices: [SCNVector3], indices: [Int32]) {
        connectionNode.removeFromParentNode()
        guard !vertices.isEmpty else { return }
        let src  = SCNGeometrySource(vertices: vertices)
        let elem = SCNGeometryElement(indices: indices, primitiveType: .line)
        let geo  = SCNGeometry(sources: [src], elements: [elem])
        let mat  = SCNMaterial()
        mat.lightingModel = .constant
        mat.emission.contents = UIColor.white.withAlphaComponent(0.5)
        geo.materials = [mat]
        connectionNode = SCNNode(geometry: geo)
        sphereRoot.addChildNode(connectionNode)
    }

    private func buildParticles() {
        particleNode.removeFromParentNode()
        let ps = SCNParticleSystem()
        ps.loops = true; ps.emitterShape = SCNSphere(radius: 1.0)
        ps.birthRate = 15; ps.particleLifeSpan = 2.0
        ps.particleSize = 0.02; ps.particleVelocity = 0.3; ps.particleVelocityVariation = 0.2
        ps.spreadingAngle = 360
        ps.particleColor = UIColor(red: 0.2, green: 0.6, blue: 0.95, alpha: 0.8)
        ps.isLightingEnabled = false; ps.blendMode = .additive
        particleNode = SCNNode(); particleNode.addParticleSystem(ps)
        sphereRoot.addChildNode(particleNode)
    }

    // MARK: - Update

    func update(parameters: EmotionParameters) {
        applyParameters(parameters, animated: true)
    }

    private func applyParameters(_ p: EmotionParameters, animated: Bool) {
        currentParams = p
        let dur: CGFloat = animated ? 1.0 : 0

        SCNTransaction.begin(); SCNTransaction.animationDuration = dur
        nodePoints.forEach { $0.geometry?.firstMaterial?.emission.contents = p.primaryUIColor }
        connectionNode.geometry?.firstMaterial?.emission.contents =
            p.primaryUIColor.withAlphaComponent(CGFloat(p.connectionOpacity))
        SCNTransaction.commit()

        sphereRoot.removeAllActions()
        sphereRoot.runAction(.repeatForever(.rotateBy(x: 0, y: CGFloat(2 * Double.pi), z: 0,
                                                       duration: p.rotationDuration)))
        nodesContainer.removeAllActions()
        let out = SCNAction.scale(to: 1 + CGFloat(p.turbulence)*0.15, duration: p.pulseSpeed*0.5)
        let bk  = SCNAction.scale(to: 1.0, duration: p.pulseSpeed*0.5)
        out.timingMode = .easeInEaseOut; bk.timingMode = .easeInEaseOut
        nodesContainer.runAction(.repeatForever(.sequence([out, bk])))

        if let ps = particleNode.particleSystems?.first {
            ps.birthRate = CGFloat(p.particleBirthRate)
            ps.particleVelocity = CGFloat(p.particleVelocity)
            ps.particleColor = p.primaryUIColor.withAlphaComponent(0.8)
        }

        restartTurbulence(magnitude: p.turbulence)

        // Rebuild connections off main thread
        let threshold = Float(0.42 + p.connectivity * 0.30)
        let captured  = basePositions
        if animated {
            SCNTransaction.begin(); SCNTransaction.animationDuration = 1.5
            connectionNode.opacity = 0; SCNTransaction.commit()
            Task.detached { [threshold, captured] in
                let (v, i) = NeuralSceneManager.connectionGeometry(positions: captured, threshold: threshold)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.placeConnections(vertices: v, indices: i)
                    SCNTransaction.begin(); SCNTransaction.animationDuration = 1.0
                    self.connectionNode.opacity = 1; SCNTransaction.commit()
                }
            }
        } else {
            let (v, i) = Self.connectionGeometry(positions: captured, threshold: threshold)
            placeConnections(vertices: v, indices: i)
        }
    }

    private func restartTurbulence(magnitude: Float) {
        nodePoints.forEach { $0.removeAllActions() }
        guard magnitude > 0.01 else { return }
        for (idx, node) in nodePoints.enumerated() {
            guard idx < basePositions.count else { break }
            let base = basePositions[idx]
            let amp  = CGFloat(magnitude) * 0.12
            let dur  = Double.random(in: 0.4...1.2) / Double(magnitude + 0.1)
            let dx = CGFloat.random(in: -amp...amp)
            let dy = CGFloat.random(in: -amp...amp)
            let dz = CGFloat.random(in: -amp...amp)
            let mv = SCNAction.move(to: SCNVector3(base.x+Float(dx), base.y+Float(dy), base.z+Float(dz)), duration: dur)
            let bk = SCNAction.move(to: base, duration: dur)
            mv.timingMode = .easeInEaseOut; bk.timingMode = .easeInEaseOut
            node.runAction(.repeatForever(.sequence([mv, bk])))
        }
    }
}

// MARK: - NeuralSceneView

struct NeuralSceneView: UIViewRepresentable {
    let manager: NeuralSceneManager

    @MainActor
    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        v.scene = manager.scene
        v.allowsCameraControl = true
        v.autoenablesDefaultLighting = false
        v.backgroundColor = .black
        v.antialiasingMode = .multisampling4X
        if manager.scene.rootNode.childNode(withName: "mainCam", recursively: false) == nil {
            let cam = SCNCamera(); cam.fieldOfView = 60
            let cn  = SCNNode(); cn.name = "mainCam"; cn.camera = cam
            cn.position = SCNVector3(0, 0, 3)
            manager.scene.rootNode.addChildNode(cn)
        }
        return v
    }

    @MainActor
    func updateUIView(_ uiView: SCNView, context: Context) {}
}
