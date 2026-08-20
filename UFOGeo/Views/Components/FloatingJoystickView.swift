import SwiftUI

/// 浮動搖桿視圖 - 封裝搖桿、手勢和視覺反饋
struct FloatingJoystickView: View {
    let manager: JoystickManager
    let size: CGFloat
    let layout: AdaptiveLayoutMetrics
    let isSimulating: Bool
    let joystickDirectionLocked: Bool
    
    let onDragChanged: () -> Void
    let onDragEnded: () -> Bool
    let onDoubleTap: () -> Void
    
    var body: some View {
        JoystickComponentView(
            manager: manager,
            size: size,
            knobScale: 0.38,
            onDragChanged: onDragChanged,
            onDragEnded: onDragEnded
        )
        .frame(width: size, height: size)
        .opacity(isSimulating ? 1 : 0.65)
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    if joystickDirectionLocked {
                        onDoubleTap()
                    }
                }
        )
        .overlay {
            if joystickDirectionLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .position(manager.position)
                    .allowsHitTesting(false)
                    .accessibilityLabel("方向已鎖定，點擊兩下解除")
            }
        }
        .padding(8)
        .background(.regularMaterial, in: Circle())
        .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
        .padding(.trailing, layout.horizontalPadding)
        .padding(.bottom, layout.joystickBottomInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .accessibilityLabel("浮動搖桿")
        .zIndex(45)
    }
}
