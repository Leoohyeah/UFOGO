import Foundation

enum RouteNameGenerator {
    static func nextAvailableName(in routes: [SimulationRoute]) -> String {
        var number = 1
        while routes.contains(where: {
            SavedItemNameMatcher.matches($0.name, "路線 #\(number)")
        }) {
            number += 1
        }
        return "路線 #\(number)"
    }
}
