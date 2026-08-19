import Foundation
import Combine
import UIKit

class JoystickManager: ObservableObject {
    private(set) var position: CGPoint = .zero
    private(set) var isActive: Bool = false
    private(set) var magnitude: Double = 0.0
    private(set) var angle: Double = 0.0
    @Published var maxSpeed: Double = 100.0
    private(set) var currentSpeed: Double = 0.0
    
    
    func updatePosition(_ point: CGPoint, within bounds: CGRect) {
        objectWillChange.send()
        isActive = true
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = bounds.width / 2.5
        
        let delta = CGPoint(
            x: point.x - center.x,
            y: point.y - center.y
        )
        
        let distance = sqrt(delta.x * delta.x + delta.y * delta.y)
        
        if distance > 0 {
            let normalizedX = delta.x / distance
            let normalizedY = delta.y / distance
            let constrainedDistance = min(distance, radius)
            
            position = CGPoint(
                x: center.x + normalizedX * constrainedDistance,
                y: center.y + normalizedY * constrainedDistance
            )
            
            magnitude = constrainedDistance / radius
            
            angle = atan2(Double(normalizedY), Double(normalizedX)) * 180 / .pi + 180
            
            currentSpeed = maxSpeed
        }
        
    }
    
    func reset(within bounds: CGRect) {
        objectWillChange.send()
        currentSpeed = 0.0
        position = CGPoint(x: bounds.midX, y: bounds.midY)
        magnitude = 0.0
        angle = 0.0
        isActive = false
    }
    
}

