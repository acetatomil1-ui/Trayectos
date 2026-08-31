import CoreLocation
import Foundation

struct RouteCoordinate: Hashable {
    let latitude: Double
    let longitude: Double

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}

struct TimedRoutePoint: Hashable {
    let coordinate: RouteCoordinate
    let timestamp: Date
}

struct RouteBlock: Identifiable, Hashable {
    let id: String
    let sourceIndex: Int
    let day: Date
    let points: [TimedRoutePoint]

    var pointCount: Int {
        points.count
    }

    var distanceMeters: CLLocationDistance {
        guard points.count > 1 else { return 0 }

        return zip(points, points.dropFirst()).reduce(0) { partial, pair in
            partial + pair.0.coordinate.location.distance(from: pair.1.coordinate.location)
        }
    }
}

struct TimelineActivity: Hashable {
    let startTime: Date?
    let endTime: Date?
    let startCoordinate: RouteCoordinate?
    let endCoordinate: RouteCoordinate?
    let distanceMeters: Double?
    let type: String?
    let probability: Double?
}

struct TimelineVisit: Hashable {
    let startTime: Date?
    let endTime: Date?
    let coordinate: RouteCoordinate?
    let semanticType: String?
    let placeID: String?
}

struct ImportDiagnostics: Hashable {
    let recordCount: Int
    let timelineBlockCount: Int
    let skippedPointCount: Int
}

struct TimelineDataset: Hashable {
    let blocks: [RouteBlock]
    let activities: [TimelineActivity]
    let visits: [TimelineVisit]
    let diagnostics: ImportDiagnostics

    var pointCount: Int {
        blocks.reduce(0) { $0 + $1.pointCount }
    }

    var distanceMeters: CLLocationDistance {
        blocks.reduce(0) { $0 + $1.distanceMeters }
    }

    var earliestPointDate: Date? {
        blocks.compactMap { $0.points.first?.timestamp }.min()
    }

    var latestPointDate: Date? {
        blocks.compactMap { $0.points.last?.timestamp }.max()
    }
}

struct JourneyDay: Identifiable, Hashable {
    let date: Date
    let blocks: [RouteBlock]

    var id: Date { date }

    var pointCount: Int {
        blocks.reduce(0) { $0 + $1.pointCount }
    }

    var distanceMeters: CLLocationDistance {
        blocks.reduce(0) { $0 + $1.distanceMeters }
    }
}

struct JourneyStats: Hashable {
    let dayCount: Int
    let pointCount: Int
    let distanceMeters: CLLocationDistance

    static let empty = JourneyStats(dayCount: 0, pointCount: 0, distanceMeters: 0)
}
