import Combine
import Foundation

@MainActor
final class JourneyViewModel: ObservableObject {
    @Published private(set) var dataset: TimelineDataset?
    @Published private(set) var fileName: String?
    @Published private(set) var selectedDays: [JourneyDay] = []
    @Published private(set) var selectedBlocks: [RouteBlock] = []
    @Published private(set) var isImporting = false
    @Published var enabledDays: Set<Date> = []
    @Published var fromDate = Date()
    @Published var toDate = Date()
    @Published var errorMessage: String?

    private var calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    var availableDateRange: ClosedRange<Date>? {
        guard let dataset,
              let first = dataset.earliestPointDate,
              let last = dataset.latestPointDate else {
            return nil
        }
        return calendar.startOfDay(for: first)...calendar.startOfDay(for: last)
    }

    var visibleBlocks: [RouteBlock] {
        selectedBlocks.filter { enabledDays.contains($0.day) }
    }

    var visibleStats: JourneyStats {
        let blocks = visibleBlocks
        return JourneyStats(
            dayCount: enabledDays.intersection(Set(selectedDays.map(\.date))).count,
            pointCount: blocks.reduce(0) { $0 + $1.pointCount },
            distanceMeters: blocks.reduce(0) { $0 + $1.distanceMeters }
        )
    }

    var allDaysAreEnabled: Bool {
        !selectedDays.isEmpty && selectedDays.allSatisfy { enabledDays.contains($0.date) }
    }

    func importDocument(from url: URL) {
        errorMessage = nil
        isImporting = true

        defer { isImporting = false }

        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            let parsedDataset = try TimelineParser(calendar: calendar).parse(data: data)

            dataset = parsedDataset
            fileName = url.lastPathComponent

            if let range = availableDateRange {
                fromDate = range.lowerBound
                toDate = range.upperBound
            }

            applyRange()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func presentImportError(_ error: Error) {
        errorMessage = error.localizedDescription
    }

    func applyRange() {
        guard let dataset else { return }

        let lowerDay = calendar.startOfDay(for: min(fromDate, toDate))
        let upperDay = calendar.startOfDay(for: max(fromDate, toDate))

        let blocks = dataset.blocks.filter { block in
            block.day >= lowerDay && block.day <= upperDay
        }
        .sorted { lhs, rhs in
            let leftDate = lhs.points.first?.timestamp ?? lhs.day
            let rightDate = rhs.points.first?.timestamp ?? rhs.day
            return leftDate < rightDate
        }

        selectedBlocks = blocks

        let grouped = Dictionary(grouping: blocks, by: \.day)
        selectedDays = grouped.keys.sorted().map { date in
            JourneyDay(date: date, blocks: grouped[date, default: []])
        }
        enabledDays = Set(selectedDays.map(\.date))
    }

    func setDay(_ day: Date, enabled: Bool) {
        if enabled {
            enabledDays.insert(day)
        } else {
            enabledDays.remove(day)
        }
    }

    func setAllDays(enabled: Bool) {
        enabledDays = enabled ? Set(selectedDays.map(\.date)) : []
    }
}
