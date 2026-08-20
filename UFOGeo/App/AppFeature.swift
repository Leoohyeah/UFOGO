enum AppFeature: String {
    case home
    case pathSimulation = "pathsimulation"

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .home:
            return "定位"
        case .pathSimulation:
            return "路線"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            return "location.fill"
        case .pathSimulation:
            return "map.fill"
        }
    }

}

extension AppFeature {
    static let mainTabs: [AppFeature] = [.home, .pathSimulation]
}
