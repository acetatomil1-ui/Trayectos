import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = JourneyViewModel()
    @State private var showsFileImporter = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        if viewModel.dataset == nil {
                            WelcomeCard {
                                showsFileImporter = true
                            }
                        } else {
                            FileSummaryCard(viewModel: viewModel)
                            DateRangeCard(viewModel: viewModel)

                            if viewModel.selectedDays.isEmpty {
                                NoResultsCard()
                            } else {
                                StatsCard(stats: viewModel.visibleStats)
                                MapCard(routes: mapRoutes, hasVisibleDays: !viewModel.enabledDays.isEmpty)
                                DayFiltersCard(viewModel: viewModel)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 36)
                }

                if viewModel.isImporting {
                    LoadingOverlay()
                }
            }
            .navigationTitle("Trayectos")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if viewModel.dataset != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showsFileImporter = true
                        } label: {
                            Label("Importar", systemImage: "square.and.arrow.down")
                        }
                    }
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .fileImporter(
                isPresented: $showsFileImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let url):
                    viewModel.importDocument(from: url)
                case .failure(let error):
                    viewModel.presentImportError(error)
                }
            }
            .alert(
                "No se pudo abrir el archivo",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { isPresented in
                        if !isPresented { viewModel.errorMessage = nil }
                    }
                )
            ) {
                Button("Entendido", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "Ocurrió un error inesperado.")
            }
        }
        .tint(Color.accentColor)
    }

    private var mapRoutes: [MapRoute] {
        let colorByDay = Dictionary(uniqueKeysWithValues: viewModel.selectedDays.enumerated().map { item in
            (item.element.date, RoutePalette.uiColor(for: item.offset))
        })

        return viewModel.visibleBlocks.map { block in
            MapRoute(block: block, color: colorByDay[block.day] ?? RoutePalette.uiColor(for: 0))
        }
    }
}

private struct AppBackground: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.14),
                    Color.teal.opacity(0.08),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
    }
}

private struct WelcomeCard: View {
    let importAction: () -> Void

    var body: some View {
        CardSurface {
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor, Color.teal],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 104, height: 104)
                        .shadow(color: Color.accentColor.opacity(0.28), radius: 18, y: 10)

                    Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 10) {
                    Text("Tus días, en un solo mapa")
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)

                    Text("Importá tu historial, elegí un rango de fechas y mirá el viaje completo sin saltar de día en día.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: importAction) {
                    Label("Elegir location-history.json", systemImage: "folder.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Label("Tu archivo se procesa en este dispositivo", systemImage: "lock.shield.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 26)
        }
        .padding(.top, 22)
    }
}

private struct FileSummaryCard: View {
    @ObservedObject var viewModel: JourneyViewModel

    var body: some View {
        CardSurface {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color.green.opacity(0.14))
                        .frame(width: 50, height: 50)

                    Image(systemName: "checkmark.document.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.fileName ?? "location-history.json")
                        .font(.headline)
                        .lineLimit(1)

                    if let dataset = viewModel.dataset {
                        Text(importDetails(dataset))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)

                Text("LISTO")
                    .font(.caption2.weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.12), in: Capsule())
            }
        }
    }

    private func importDetails(_ dataset: TimelineDataset) -> String {
        var details = [
            "\(dataset.pointCount.formatted()) puntos",
            "\(dataset.activities.count.formatted()) actividades",
            "\(dataset.visits.count.formatted()) visitas"
        ]
        if dataset.diagnostics.skippedPointCount > 0 {
            details.append("\(dataset.diagnostics.skippedPointCount.formatted()) omitidos")
        }
        return details.joined(separator: " · ")
    }
}

private struct DateRangeCard: View {
    @ObservedObject var viewModel: JourneyViewModel

    var body: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 17) {
                SectionTitle(
                    title: "Elegí el período",
                    subtitle: "Incluye completos el primer y el último día",
                    symbol: "calendar.badge.clock"
                )

                if let availableRange = viewModel.availableDateRange {
                    VStack(spacing: 0) {
                        DateRow(
                            title: "Desde",
                            symbol: "arrow.right",
                            selection: $viewModel.fromDate,
                            range: availableRange.lowerBound...min(viewModel.toDate, availableRange.upperBound)
                        )

                        Divider()
                            .padding(.leading, 46)

                        DateRow(
                            title: "Hasta",
                            symbol: "flag.fill",
                            selection: $viewModel.toDate,
                            range: max(viewModel.fromDate, availableRange.lowerBound)...availableRange.upperBound
                        )
                    }
                    .padding(.horizontal, 12)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.applyRange()
                    }
                } label: {
                    Label("Ver recorrido", systemImage: "map.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }
}

private struct DateRow: View {
    let title: String
    let symbol: String
    @Binding var selection: Date
    let range: ClosedRange<Date>

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 30, height: 30)
                .background(Color.accentColor.opacity(0.11), in: Circle())

            Text(title)
                .font(.subheadline.weight(.semibold))

            Spacer()

            DatePicker(
                title,
                selection: $selection,
                in: range,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
        }
        .padding(.vertical, 10)
    }
}

private struct StatsCard: View {
    let stats: JourneyStats

    var body: some View {
        CardSurface {
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    StatMetric(
                        value: stats.dayCount.formatted(),
                        label: stats.dayCount == 1 ? "día" : "días",
                        symbol: "calendar",
                        color: Color.accentColor
                    )

                    MetricDivider()

                    StatMetric(
                        value: stats.pointCount.formatted(),
                        label: "puntos",
                        symbol: "mappin.and.ellipse",
                        color: .teal
                    )

                    MetricDivider()

                    StatMetric(
                        value: "~\(DistanceFormatter.kilometers(stats.distanceMeters))",
                        label: "km GPS",
                        symbol: "ruler",
                        color: .orange
                    )
                }

                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.orange)
                        .padding(.top, 1)

                    Text("La distancia es aproximada y puede quedar corta cuando hay huecos entre puntos GPS.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(Color.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
}

private struct StatMetric: View {
    let value: String
    let label: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)

            Text(value)
                .font(.title3.weight(.bold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct MetricDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.16))
            .frame(width: 1, height: 54)
    }
}

private struct MapCard: View {
    let routes: [MapRoute]
    let hasVisibleDays: Bool

    var body: some View {
        CardSurface(contentPadding: 10) {
            ZStack {
                RouteMapView(routes: routes)
                    .frame(height: 430)

                if !hasVisibleDays {
                    Color(uiColor: .secondarySystemGroupedBackground)
                        .opacity(0.94)

                    VStack(spacing: 12) {
                        Image(systemName: "eye.slash.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Activá al menos un día")
                            .font(.headline)
                        Text("Usá los controles de abajo para volver a mostrarlo en el mapa.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(alignment: .topLeading) {
                Label("Recorrido", systemImage: "map.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(12)
            }
        }
    }
}

private struct DayFiltersCard: View {
    @ObservedObject var viewModel: JourneyViewModel

    var body: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    SectionTitle(
                        title: "Días del recorrido",
                        subtitle: "Mostrá u ocultá cada jornada",
                        symbol: "line.3.horizontal.decrease.circle.fill"
                    )

                    Spacer(minLength: 10)

                    Button(viewModel.allDaysAreEnabled ? "Ninguno" : "Todos") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.setAllDays(enabled: !viewModel.allDaysAreEnabled)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                }

                VStack(spacing: 0) {
                    ForEach(viewModel.selectedDays.indices, id: \.self) { index in
                        let day = viewModel.selectedDays[index]
                        DayToggleRow(
                            day: day,
                            color: RoutePalette.color(for: index),
                            isEnabled: Binding(
                                get: { viewModel.enabledDays.contains(day.date) },
                                set: { viewModel.setDay(day.date, enabled: $0) }
                            )
                        )

                        if day.id != viewModel.selectedDays.last?.id {
                            Divider()
                                .padding(.leading, 50)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
}

private struct DayToggleRow: View {
    let day: JourneyDay
    let color: Color
    @Binding var isEnabled: Bool

    var body: some View {
        Toggle(isOn: $isEnabled) {
            HStack(spacing: 12) {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 2))
                    .shadow(color: color.opacity(0.35), radius: 4)

                VStack(alignment: .leading, spacing: 3) {
                    Text(DateFormatterHelper.dayTitle(day.date))
                        .font(.subheadline.weight(.semibold))

                    Text("\(day.pointCount.formatted()) puntos · ~\(DistanceFormatter.kilometers(day.distanceMeters)) km")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .tint(color)
        .padding(.vertical, 11)
        .accessibilityLabel("\(DateFormatterHelper.dayTitle(day.date)), \(day.pointCount) puntos")
    }
}

private struct SectionTitle: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct NoResultsCard: View {
    var body: some View {
        CardSurface {
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)

                Text("No hay puntos en esas fechas")
                    .font(.headline)

                Text("Probá ampliando el rango y tocá Ver recorrido otra vez.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        }
    }
}

private struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.16)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                Text("Leyendo tu recorrido…")
                    .font(.headline)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 20, y: 10)
        }
    }
}

private struct CardSurface<Content: View>: View {
    let contentPadding: CGFloat
    let content: Content

    init(contentPadding: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.contentPadding = contentPadding
        self.content = content()
    }

    var body: some View {
        content
            .padding(contentPadding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.055), radius: 16, y: 8)
    }
}

private enum DateFormatterHelper {
    static func dayTitle(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .locale(.autoupdatingCurrent)
                .weekday(.wide)
                .day()
                .month(.wide)
        )
        .capitalized
    }
}

private enum DistanceFormatter {
    static func kilometers(_ meters: Double) -> String {
        let kilometers = meters / 1_000
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .autoupdatingCurrent
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = kilometers < 100 ? 1 : 0
        return formatter.string(from: NSNumber(value: kilometers)) ?? "0"
    }
}
