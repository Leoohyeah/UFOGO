import SwiftUI

struct JoystickComponentView: View {
    @ObservedObject var manager: JoystickManager
    let size: CGFloat
    var knobScale: CGFloat = 0.25
    var onDragChanged: (() -> Void)? = nil
    var onDragEnded: (() -> Bool)? = nil

    private var displayedPosition: CGPoint {
        guard manager.isActive else {
            return CGPoint(x: size / 2, y: size / 2)
        }
        return manager.position
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray6))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
            
            Canvas { context, _ in
                drawGridLines(context: context, size: size)
            }
            .opacity(0.3)
            
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [Color.accentColor, Color.accentColor.opacity(0.7)]),
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.2
                    )
                )
                .frame(width: size * knobScale, height: size * knobScale)
                .position(displayedPosition)
                .shadow(color: Color.accentColor.opacity(0.5), radius: 8, x: 0, y: 2)
            
            if manager.magnitude > 0 {
                Circle()
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 2)
                    .frame(width: size * 0.5 * CGFloat(manager.magnitude), height: size * 0.5 * CGFloat(manager.magnitude))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .onAppear {
            if !manager.isActive {
                manager.reset(within: CGRect(x: 0, y: 0, width: size, height: size))
            }
        }
        .onChange(of: size) { _, newSize in
            if !manager.isActive {
                manager.reset(
                    within: CGRect(x: 0, y: 0, width: newSize, height: newSize)
                )
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    manager.updatePosition(value.location, within: CGRect(x: 0, y: 0, width: size, height: size))
                    onDragChanged?()
                }
                .onEnded { _ in
                    let shouldKeepMoving = onDragEnded?() ?? false
                    if !shouldKeepMoving {
                        manager.reset(within: CGRect(x: 0, y: 0, width: size, height: size))
                    }
                }
        )
    }
    
    private func drawGridLines(context: GraphicsContext, size: CGFloat) {
        let center = CGPoint(x: size / 2, y: size / 2)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: center.y))
        path.addLine(to: CGPoint(x: size, y: center.y))
        path.move(to: CGPoint(x: center.x, y: 0))
        path.addLine(to: CGPoint(x: center.x, y: size))
        
        context.stroke(
            path,
            with: .color(Color(.systemGray3).opacity(0.4)),
            lineWidth: 1
        )
    }
}


