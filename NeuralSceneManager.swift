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
    }

    // MARK: - Background Build

    nonisolated private func asyncBuild() async {
        let skeleton       = Self.neuronSkeleton()
        let allCloud       = Self.neuronCloud(count: 3000)
        let (lineV, lineI) = Self.connectionGeo(positions: skeleton, threshold: 0.38)

        // Split cloud into groups
        let groupSize  = allCloud.count / 8
        var groups     = [[SCNVector3]]()
        for g in 0..<8 {
            let start = g * groupSize
            let end   = g == 7 ? allCloud.count : start + groupSize
            groups.append(Array(allCloud[start..<end]))
        }

        await MainActor.run { [weak self] in
            guard let self else { return }
            self.skeletonPts = skeleton
            self.buildGroups(groups)
            self.placeLines(vertices: lineV, indices: lineI)
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

    func update(parameters: EmotionParameters) { applyParameters(parameters, animated: true) }

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

            // Color
            SCNTransaction.begin(); SCNTransaction.animationDuration = dur
            group.geometry?.firstMaterial?.emission.contents = p.primaryUIColor
            SCNTransaction.commit()

            applyEmotionActions(to: group, index: i, params: p, animated: animated)
        }

        // Connections density
        let threshold = Float(0.22 + p.connectivity * 0.22)
        let skel = skeletonPts
        if animated && !skel.isEmpty {
            SCNTransaction.begin(); SCNTransaction.animationDuration = 0.8
            connectionNode.opacity = 0; SCNTransaction.commit()
            Task.detached { [threshold, skel] in
                let (v, i) = NeuralSceneManager.connectionGeo(positions: skel, threshold: threshold)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.placeLines(vertices: v, indices: i)
                    SCNTransaction.begin(); SCNTransaction.animationDuration = 0.8
                    self.connectionNode.opacity = 1; SCNTransaction.commit()
                }
            }
        } else if !skel.isEmpty {
            let (v, i) = Self.connectionGeo(positions: skel, threshold: threshold)
            placeLines(vertices: v, indices: i)
        }
    }

    // MARK: - Emotion-specific SCNAction per group

    private func applyEmotionActions(to node: SCNNode, index i: Int,
                                     params p: EmotionParameters, animated: Bool) {
        let phase = Float(i) * 2 * .pi / Float(groupCount)   // wave phase offset
        let fi    = Float(i)

        switch dominantEmotion(p) {

        case .calm:
            // ── Slow synchronized wave: all groups gently ripple in unison ──
            // Each group has a tiny phase offset → creates traveling wave feel
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

        case .anxiety:
            // ── Chaotic rapid multi-frequency jitter — each group is DIFFERENT ──
            // Frequency varies 2-6x per group; groups clash → hyperactive firing
            let freqMult  = 1.5 + fi * 0.6          // group 0: 1.5x, group 7: 5.7x
            let ampMult   = 0.06 + fi * 0.015        // larger amplitude for higher-index groups
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

        case .sadness:
            // ── Most groups dim/frozen; a few barely stir ──
            // Groups 0-4 go very dim, 5-7 retain faint motion
            let opacity: CGFloat = i < 5 ? 0.22 + CGFloat(i) * 0.05 : 0.55
            SCNTransaction.begin(); SCNTransaction.animationDuration = animated ? 2.0 : 0
            node.opacity = opacity; SCNTransaction.commit()

            if i >= 5 {
                // A whisper of motion for the mid groups
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

        case .love:
            // ── Cascading wave: groups fire sequentially → rhythmic cascade ──
            // Each group is delayed by its index → "neural signal propagating"
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

            // Colour cascade: alt between primary and secondary per wave
            let secColor = p.secondaryUIColor.withAlphaComponent(0.9)
            let priColor = p.primaryUIColor
            let colorFwd = SCNAction.customAction(duration: p.pulseSpeed * 0.5) { nd, t in
                let frac = CGFloat(t / p.pulseSpeed * 0.5)
                nd.geometry?.firstMaterial?.emission.contents =
                    frac < 0.5 ? priColor : secColor
            }
            let colorBk = SCNAction.customAction(duration: p.pulseSpeed * 0.5) { nd, t in
                nd.geometry?.firstMaterial?.emission.contents = priColor
            }
            let colorSeq = SCNAction.repeatForever(.sequence([
                .wait(duration: delay), colorFwd, colorBk
            ]))
            node.runAction(colorSeq, forKey: "colorwave")

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

    // MARK: - Scene Graph

    private func placeLines(vertices: [SCNVector3], indices: [Int32]) {
        connectionNode.removeFromParentNode()
        guard !vertices.isEmpty else { return }
        let src  = SCNGeometrySource(vertices: vertices)
        let elem = SCNGeometryElement(indices: indices, primitiveType: .line)
        let geo  = SCNGeometry(sources: [src], elements: [elem])
        let mat  = SCNMaterial()
        mat.lightingModel     = .constant
        mat.emission.contents = currentParams.primaryUIColor.withAlphaComponent(0.2)
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
        return v
    }
    @MainActor func updateUIView(_ uiView: SCNView, context: Context) {}
}
