import SwiftUI

// MARK: - EmotionOrbView
// Pure SwiftUI Canvas — Y-axis rotation + perspective projection.
// Pre-computes a Fibonacci-lattice sphere and the adjacency connections
// (3D distance < threshold) so they can be drawn cheaply every frame.

struct EmotionOrbView: View {
    let emotion: Emotion
    let size: CGFloat

    // ── Sphere geometry (pre-computed once) ─────────────────────────────
    private static func makeSpherePoints() -> [(Float, Float, Float)] {
        let n = 140
        let golden = Float.pi * (3 - sqrt(5.0))
        return (0..<n).map { i in
            let y     = 1 - Float(i) / Float(n - 1) * 2
            let r     = sqrt(max(0, 1 - y * y))
            let theta = golden * Float(i)
            return (cos(theta) * r, y, sin(theta) * r)
        }
    }

    // Pairs of indices whose 3D distance < threshold → draw edge
    private static func makeConnections(pts: [(Float, Float, Float)]) -> [(Int, Int)] {
        let threshold: Float = 0.34   // ~nearest-neighbour distance on Fibonacci lattice
        var pairs: [(Int, Int)] = []
        for i in 0..<pts.count {
            for j in (i + 1)..<pts.count {
                let dx = pts[i].0 - pts[j].0
                let dy = pts[i].1 - pts[j].1
                let dz = pts[i].2 - pts[j].2
                if dx*dx + dy*dy + dz*dz < threshold * threshold {
                    pairs.append((i, j))
                }
            }
        }
        return pairs
    }

    private let points: [(Float, Float, Float)] = makeSpherePoints()
    private let connections: [(Int, Int)]

    init(emotion: Emotion, size: CGFloat) {
        self.emotion = emotion
        self.size = size
        let pts = EmotionOrbView.makeSpherePoints()
        self.connections = EmotionOrbView.makeConnections(pts: pts)
    }

    var body: some View {
        ZStack {
            // Glow halo
            RadialGradient(
                colors: [emotion.color.opacity(0.55), emotion.color.opacity(0.0)],
                center: .center, startRadius: 0, endRadius: size * 0.55
            )
            .frame(width: size * 1.1, height: size * 1.1)
            .blur(radius: size * 0.12)

            // Inner core glow
            Circle()
                .fill(emotion.color.opacity(0.18))
                .frame(width: size * 0.55, height: size * 0.55)
                .blur(radius: size * 0.08)

            // 3D rotating particle sphere + edge connections
            TimelineView(.animation) { tl in
                Canvas { ctx, cSize in
                    let t    = tl.date.timeIntervalSince1970
                    let rot  = t * 0.35
                    let cx   = cSize.width  / 2
                    let cy   = cSize.height / 2
                    let R    = Double(min(cSize.width, cSize.height)) * 0.40
                    let fov  = 3.2
                    let cosR = cos(rot); let sinR = sin(rot)

                    // Project all points
                    struct Proj {
                        let sx, sy, depth, pz: Double
                    }
                    let projected: [Proj] = points.map { (px, py, pz) in
                        let nx = Double(px) * cosR + Double(pz) * sinR
                        let nz = -Double(px) * sinR + Double(pz) * cosR
                        let sc = fov / (fov + nz + 1)
                        return Proj(sx: cx + nx * R * sc,
                                    sy: cy - Double(py) * R * sc,
                                    depth: (nz + 1) / 2,
                                    pz: nz)
                    }

                    // ── Edge connections (silhouette-weighted opacity) ─────
                    // Opacity peaks at silhouette (pz≈0) and fades toward
                    // front/back so only the sphere boundary looks defined.
                    var edgePath = Path()
                    for (i, j) in connections {
                        let pi = projected[i]; let pj = projected[j]
                        // Skip if both are clearly behind the sphere
                        guard pi.pz > -0.95 || pj.pz > -0.95 else { continue }
                        edgePath.move(to: CGPoint(x: pi.sx, y: pi.sy))
                        edgePath.addLine(to: CGPoint(x: pj.sx, y: pj.sy))
                    }
                    // Single stroke for all edges — batched for performance
                    // Silhouette-weighted: we draw in two passes with different opacities
                    // Pass 1: all connections, very faint
                    ctx.stroke(edgePath,
                               with: .color(emotion.color.opacity(0.09)),
                               style: StrokeStyle(lineWidth: 0.7))

                    // Pass 2: only near-silhouette connections, slightly brighter
                    var silPath = Path()
                    for (i, j) in connections {
                        let pi = projected[i]; let pj = projected[j]
                        let avgAbsZ = (abs(pi.pz) + abs(pj.pz)) / 2
                        // Near silhouette: |pz| < 0.35
                        if avgAbsZ < 0.35 {
                            silPath.move(to: CGPoint(x: pi.sx, y: pi.sy))
                            silPath.addLine(to: CGPoint(x: pj.sx, y: pj.sy))
                        }
                    }
                    ctx.stroke(silPath,
                               with: .color(emotion.color.opacity(0.18)),
                               style: StrokeStyle(lineWidth: 0.8))

                    // ── Particles (depth-sorted) ─────────────────────────
                    let sorted = projected.sorted { $0.pz < $1.pz }
                    for p in sorted {
                        let alpha  = 0.22 + p.depth * 0.55
                        let pScale = fov / (fov + p.pz + 1)
                        // Fixed small size — same as original, slightly larger minimum
                        let pSize  = CGFloat(max(2.5, pScale * 5.8))
                        let rect   = CGRect(x: p.sx - pSize/2, y: p.sy - pSize/2,
                                            width: pSize, height: pSize)
                        ctx.fill(Path(ellipseIn: rect),
                                 with: .color(emotion.color.opacity(alpha)))
                    }
                }
                .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
    }
}
