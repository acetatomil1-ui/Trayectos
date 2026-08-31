import CoreLocation
import Foundation

struct TimelineParser {
    private var calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    func parse(data: Data) throws -> TimelineDataset {
        let decoder = JSONDecoder()
        let records: [RawTimelineRecord]

        if let directRecords = try? decoder.decode([RawTimelineRecord].self, from: data) {
            records = directRecords
        } else if let wrapped = try? decoder.decode(RawTimelineDocument.self, from: data),
                  let wrappedRecords = wrapped.records {
            records = wrappedRecords
        } else {
            throw TimelineImportError.unsupportedDocument
        }

        var blocks: [RouteBlock] = []
        var activities: [TimelineActivity] = []
        var visits: [TimelineVisit] = []
        var skippedPoints = 0
        var timelineBlockCount = 0

        for (recordIndex, record) in records.enumerated() {
            let startDate = record.startTime.flatMap(FlexibleDateParser.date(from:))
            let endDate = record.endTime.flatMap(FlexibleDateParser.date(from:))

            if let activity = record.activity {
                activities.append(
                    TimelineActivity(
                        startTime: startDate,
                        endTime: endDate,
                        startCoordinate: activity.start.flatMap(CoordinateParser.coordinate(from:)),
                        endCoordinate: activity.end.flatMap(CoordinateParser.coordinate(from:)),
                        distanceMeters: activity.distanceMeters,
                        type: activity.topCandidate?.type,
                        probability: activity.topCandidate?.probability
                    )
                )
            }

            if let visit = record.visit {
                visits.append(
                    TimelineVisit(
                        startTime: startDate,
                        endTime: endDate,
                        coordinate: visit.topCandidate?.placeLocation.flatMap(CoordinateParser.coordinate(from:)),
                        semanticType: visit.topCandidate?.semanticType,
                        placeID: visit.topCandidate?.placeID
                    )
                )
            }

            guard let rawPath = record.timelinePath, !rawPath.isEmpty else { continue }
            timelineBlockCount += 1

            let fallbackDate = startDate ?? endDate
            let parsedPoints: [(sourceIndex: Int, point: TimedRoutePoint)] = rawPath.enumerated().compactMap { index, rawPoint in
                guard let coordinate = CoordinateParser.coordinate(from: rawPoint.point) else {
                    skippedPoints += 1
                    return nil
                }

                guard let baseDate = fallbackDate else {
                    skippedPoints += 1
                    return nil
                }

                let timestamp: Date
                if let startDate, let minuteOffset = rawPoint.minuteOffset {
                    timestamp = startDate.addingTimeInterval(minuteOffset * 60)
                } else {
                    timestamp = baseDate
                }

                return (
                    index,
                    TimedRoutePoint(coordinate: coordinate, timestamp: timestamp)
                )
            }
            .sorted {
                if $0.point.timestamp == $1.point.timestamp {
                    return $0.sourceIndex < $1.sourceIndex
                }
                return $0.point.timestamp < $1.point.timestamp
            }

            guard !parsedPoints.isEmpty else { continue }

            var dayPartIndex = 0
            var currentDay = calendar.startOfDay(for: parsedPoints[0].point.timestamp)
            var currentPoints: [TimedRoutePoint] = []

            func makeBlock(day: Date, points: [TimedRoutePoint], partIndex: Int) -> RouteBlock {
                RouteBlock(
                    id: "record-\(recordIndex)-part-\(partIndex)",
                    sourceIndex: recordIndex,
                    day: day,
                    points: points
                )
            }

            for parsedPoint in parsedPoints {
                let pointDay = calendar.startOfDay(for: parsedPoint.point.timestamp)
                if pointDay != currentDay {
                    if !currentPoints.isEmpty {
                        blocks.append(makeBlock(day: currentDay, points: currentPoints, partIndex: dayPartIndex))
                        dayPartIndex += 1
                    }
                    currentDay = pointDay
                    currentPoints = []
                }
                currentPoints.append(parsedPoint.point)
            }

            if !currentPoints.isEmpty {
                blocks.append(makeBlock(day: currentDay, points: currentPoints, partIndex: dayPartIndex))
            }
        }

        guard blocks.contains(where: { !$0.points.isEmpty }) else {
            throw TimelineImportError.noRoutePoints
        }

        return TimelineDataset(
            blocks: blocks,
            activities: activities,
            visits: visits,
            diagnostics: ImportDiagnostics(
                recordCount: records.count,
                timelineBlockCount: timelineBlockCount,
                skippedPointCount: skippedPoints
            )
        )
    }
}

enum TimelineImportError: LocalizedError, Equatable {
    case unsupportedDocument
    case noRoutePoints

    var errorDescription: String? {
        switch self {
        case .unsupportedDocument:
            return "El archivo no tiene un formato de Cronología compatible. Elegí el location-history.json exportado desde Google Maps."
        case .noRoutePoints:
            return "El archivo se pudo abrir, pero no contiene puntos timelinePath válidos para dibujar."
        }
    }
}

private struct RawTimelineDocument: Decodable {
    let semanticSegments: [RawTimelineRecord]?
    let timelineObjects: [RawTimelineRecord]?
    let items: [RawTimelineRecord]?

    var records: [RawTimelineRecord]? {
        semanticSegments ?? timelineObjects ?? items
    }
}

private struct RawTimelineRecord: Decodable {
    let startTime: String?
    let endTime: String?
    let timelinePath: [RawTimelinePoint]?
    let activity: RawActivity?
    let visit: RawVisit?

    private enum CodingKeys: String, CodingKey {
        case startTime
        case endTime
        case timelinePath
        case activity
        case visit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startTime = try? container.decodeIfPresent(String.self, forKey: .startTime)
        endTime = try? container.decodeIfPresent(String.self, forKey: .endTime)
        activity = try? container.decodeIfPresent(RawActivity.self, forKey: .activity)
        visit = try? container.decodeIfPresent(RawVisit.self, forKey: .visit)

        let lossyPath = try? container.decodeIfPresent(
            [LossyDecodable<RawTimelinePoint>].self,
            forKey: .timelinePath
        )
        timelinePath = lossyPath?.compactMap(\.value)
    }
}

private struct RawTimelinePoint: Decodable {
    let point: String
    let minuteOffset: Double?

    private enum CodingKeys: String, CodingKey {
        case point
        case minuteOffset = "durationMinutesOffsetFromStartTime"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        point = try container.decode(String.self, forKey: .point)
        minuteOffset = container.decodeFlexibleDoubleIfPresent(forKey: .minuteOffset)
    }
}

private struct RawActivity: Decodable {
    let start: String?
    let end: String?
    let distanceMeters: Double?
    let topCandidate: RawActivityCandidate?

    private enum CodingKeys: String, CodingKey {
        case start
        case end
        case distanceMeters
        case topCandidate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        start = try container.decodeIfPresent(String.self, forKey: .start)
        end = try container.decodeIfPresent(String.self, forKey: .end)
        distanceMeters = container.decodeFlexibleDoubleIfPresent(forKey: .distanceMeters)
        topCandidate = try container.decodeIfPresent(RawActivityCandidate.self, forKey: .topCandidate)
    }
}

private struct RawActivityCandidate: Decodable {
    let type: String?
    let probability: Double?

    private enum CodingKeys: String, CodingKey {
        case type
        case probability
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        probability = container.decodeFlexibleDoubleIfPresent(forKey: .probability)
    }
}

private struct RawVisit: Decodable {
    let topCandidate: RawVisitCandidate?
}

private struct RawVisitCandidate: Decodable {
    let semanticType: String?
    let placeID: String?
    let placeLocation: String?
}

private struct LossyDecodable<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleDoubleIfPresent(forKey key: Key) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}

private enum FlexibleDateParser {
    static func date(from value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: trimmed) {
            return date
        }

        let standardFormatter = ISO8601DateFormatter()
        standardFormatter.formatOptions = [.withInternetDateTime]
        return standardFormatter.date(from: trimmed)
    }
}

private enum CoordinateParser {
    static func coordinate(from value: String) -> RouteCoordinate? {
        var normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.lowercased().hasPrefix("geo:") {
            normalized.removeFirst(4)
        }

        normalized = normalized.components(separatedBy: "?").first ?? normalized
        normalized = normalized.components(separatedBy: ";").first ?? normalized

        let parts = normalized.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count >= 2,
              let latitude = Double(parts[0].trimmingCharacters(in: .whitespacesAndNewlines)),
              let longitude = Double(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }

        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }

        return RouteCoordinate(latitude: latitude, longitude: longitude)
    }
}
