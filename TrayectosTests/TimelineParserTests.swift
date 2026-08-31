import XCTest
@testable import Trayectos

final class TimelineParserTests: XCTestCase {
    func testParsesObservedGoogleTimelineFormat() throws {
        let json = #"""
        [
          {
            "startTime": "2026-08-25T12:00:00.000Z",
            "endTime": "2026-08-25T13:00:00.000Z",
            "timelinePath": [
              { "point": "geo:-34.6037,-58.3816", "durationMinutesOffsetFromStartTime": "0" },
              { "point": "geo:-34.6047,-58.3826", "durationMinutesOffsetFromStartTime": 10 }
            ]
          },
          {
            "startTime": "2026-08-25T13:00:00.000Z",
            "endTime": "2026-08-25T13:30:00.000Z",
            "activity": {
              "start": "geo:-34.6047,-58.3826",
              "end": "geo:-34.6100,-58.3900",
              "distanceMeters": "1250.5",
              "topCandidate": {
                "type": "in passenger vehicle",
                "probability": "0.91"
              }
            }
          },
          {
            "startTime": "2026-08-25T13:30:00.000Z",
            "endTime": "2026-08-25T14:00:00.000Z",
            "visit": {
              "topCandidate": {
                "semanticType": "Work",
                "placeID": "example",
                "placeLocation": "geo:-34.6100,-58.3900"
              }
            }
          }
        ]
        """#.data(using: .utf8)!

        let dataset = try TimelineParser(calendar: utcCalendar()).parse(data: json)

        XCTAssertEqual(dataset.blocks.count, 1)
        XCTAssertEqual(dataset.pointCount, 2)
        XCTAssertEqual(dataset.activities.count, 1)
        XCTAssertEqual(dataset.activities.first?.distanceMeters, 1_250.5)
        XCTAssertEqual(dataset.activities.first?.type, "in passenger vehicle")
        XCTAssertEqual(dataset.visits.count, 1)
        XCTAssertEqual(dataset.visits.first?.semanticType, "Work")
        XCTAssertEqual(dataset.diagnostics.recordCount, 3)
    }

    func testKeepsIndependentTimelinePathsAsSeparateBlocks() throws {
        let json = #"""
        [
          {
            "startTime": "2026-08-25T12:00:00Z",
            "endTime": "2026-08-25T12:15:00Z",
            "timelinePath": [
              { "point": "geo:-34.6000,-58.3800", "durationMinutesOffsetFromStartTime": "0" },
              { "point": "geo:-34.6010,-58.3810", "durationMinutesOffsetFromStartTime": "10" }
            ]
          },
          {
            "startTime": "2026-08-25T20:00:00Z",
            "endTime": "2026-08-25T20:15:00Z",
            "timelinePath": [
              { "point": "geo:-26.8300,-65.2000", "durationMinutesOffsetFromStartTime": "0" },
              { "point": "geo:-26.8310,-65.2010", "durationMinutesOffsetFromStartTime": "10" }
            ]
          }
        ]
        """#.data(using: .utf8)!

        let dataset = try TimelineParser(calendar: utcCalendar()).parse(data: json)

        XCTAssertEqual(dataset.blocks.count, 2)
        XCTAssertEqual(dataset.blocks.map(\.sourceIndex), [0, 1])
        XCTAssertLessThan(dataset.distanceMeters, 1_000)
    }

    func testAcceptsWrappedDocumentAndSkipsInvalidCoordinates() throws {
        let json = #"""
        {
          "semanticSegments": [
            {
              "startTime": "2026-08-26T12:00:00Z",
              "endTime": "2026-08-26T13:00:00Z",
              "timelinePath": [
                { "point": "not-a-coordinate", "durationMinutesOffsetFromStartTime": "0" },
                { "point": "geo:-31.4167,-64.1833", "durationMinutesOffsetFromStartTime": 5 },
                { "point": "geo:-31.4177,-64.1843?z=17", "durationMinutesOffsetFromStartTime": "15.5" }
              ]
            }
          ]
        }
        """#.data(using: .utf8)!

        let dataset = try TimelineParser(calendar: utcCalendar()).parse(data: json)

        XCTAssertEqual(dataset.pointCount, 2)
        XCTAssertEqual(dataset.diagnostics.skippedPointCount, 1)
    }

    func testThrowsWhenDocumentHasNoTimelinePoints() {
        let json = #"""
        [
          {
            "startTime": "2026-08-26T12:00:00Z",
            "endTime": "2026-08-26T13:00:00Z",
            "visit": {
              "topCandidate": {
                "placeLocation": "geo:-31.4167,-64.1833"
              }
            }
          }
        ]
        """#.data(using: .utf8)!

        XCTAssertThrowsError(try TimelineParser(calendar: utcCalendar()).parse(data: json)) { error in
            XCTAssertEqual(error as? TimelineImportError, .noRoutePoints)
        }
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}

