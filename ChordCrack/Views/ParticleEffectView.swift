import SwiftUI

struct ParticleEffectView: View {
    @State private var particles: [Particle] = []
    let isActive: Bool
    
    var body: some View {
        ZStack {
            ForEach(particles, id: \.id) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .opacity(particle.opacity)
                    .scaleEffect(particle.scale)
            }
        }
        .onAppear {
            if isActive {
                createParticles()
            }
        }
        .onChange(of: isActive) { oldValue, newValue in
            if newValue {
                createParticles()
            } else {
                particles.removeAll()
            }
        }
    }
    
    private func createParticles() {
        particles.removeAll()
        
        for i in 0..<20 {
            let particle = Particle(
                id: i,
                position: CGPoint(x: 150, y: 150),
                color: [ColorTheme.primaryGreen, ColorTheme.lightGreen, ColorTheme.accentGreen].randomElement() ?? ColorTheme.primaryGreen,
                size: Double.random(in: 4...12),
                opacity: 1.0,
                scale: 1.0
            )
            particles.append(particle)
        }
        
        animateParticles()
    }
    
    private func animateParticles() {
        for i in particles.indices {
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = Double.random(in: 50...150)
            let endX = particles[i].position.x + cos(angle) * distance
            let endY = particles[i].position.y + sin(angle) * distance
            
            withAnimation(.easeOut(duration: Double.random(in: 1.0...2.0))) {
                particles[i].position = CGPoint(x: endX, y: endY)
                particles[i].opacity = 0
                particles[i].scale = 0.1
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            particles.removeAll()
        }
    }
}

struct Particle {
    let id: Int
    var position: CGPoint
    let color: Color
    let size: Double
    var opacity: Double
    var scale: Double
}
