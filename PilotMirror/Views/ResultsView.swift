import SwiftUI

struct ResultsView: View {
    @ObservedObject var aiService = AIAnalysisService.shared
    @EnvironmentObject var auth: AuthService
    @State private var selectedTab = 0

    var result: AnalysisResult? { aiService.result }

    var body: some View {
        ZStack {
            Color(hex: "0A1628").ignoresSafeArea()

            if let result {
                VStack(spacing: 0) {
                    // Tab picker (fixed, not scrolling)
                    Picker("", selection: $selectedTab) {
                        Text("Profil").tag(0)
                        Text("Vergleich").tag(1)
                        Text("Rohdaten").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 12)

                    // Single ScrollView — no nesting
                    ScrollView {
                        VStack(spacing: 18) {
                            if selectedTab == 0 { profilContent(result) }
                            else if selectedTab == 1 { vergleichContent(result) }
                            else { rohdatenContent(result) }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                        .animation(.easeInOut(duration: 0.2), value: selectedTab)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    ProgressView().tint(Color(hex: "4A9EF8"))
                    Text("Analyse wird erstellt…")
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .navigationTitle("Dein Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            if aiService.result == nil {
                aiService.loadMockResult(
                    assessmentType: auth.currentUser?.assessmentType?.rawValue ?? "General"
                )
            }
        }
    }

    // MARK: - Tab 1: Profil

    @ViewBuilder
    private func profilContent(_ r: AnalysisResult) -> some View {
                // "Das macht dich aus" — top traits with %
                sectionCard(icon: "person.fill", color: "4A9EF8", title: "Das macht dich aus") {
                    VStack(alignment: .leading, spacing: 14) {
                        let topTraits = r.traitStats
                            .filter { $0.othersPercent >= 0.50 }
                            .sorted { $0.othersPercent > $1.othersPercent }

                        FlowLayout(spacing: 8) {
                            ForEach(topTraits) { t in
                                HStack(spacing: 4) {
                                    Text(t.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(Int(t.othersPercent * 100))%")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Color(hex: "4A9EF8").opacity(0.2))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                            }
                        }

                        Divider().background(.white.opacity(0.1))

                        Text(r.personalitySummary)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineSpacing(5)
                    }
                }

                // Stärken
                sectionCard(icon: "star.fill", color: "34C759", title: "Stärken") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(r.perceivedStrengths.enumerated()), id: \.offset) { _, s in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color(hex: "34C759"))
                                    .font(.system(size: 18))
                                Text(s)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.9))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                // Schwächen
                sectionCard(icon: "exclamationmark.triangle.fill", color: "FF9F0A", title: "Schwächen") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(r.possibleWeaknesses.enumerated()), id: \.offset) { _, w in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundStyle(Color(hex: "FF9F0A"))
                                    .font(.system(size: 18))
                                Text(w)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.9))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                // Advice
                sectionCard(icon: "sparkles", color: "6B5EE4", title: "Empfehlung für dein Assessment") {
                    Text(r.assessmentAdvice)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineSpacing(5)
                }
    }

    // MARK: - Tab 2: Vergleich

    @ViewBuilder
    private func vergleichContent(_ r: AnalysisResult) -> some View {
        // Rating areas — Du vs. Andere
        sectionCard(icon: "chart.bar.fill", color: "4A9EF8", title: "Bereiche — Du vs. Andere (1–5)") {
            VStack(spacing: 22) {
                ForEach(r.comparisonAreas) { area in
                    areaComparisonRow(area)
                }
            }
        }

        // Self vs Others summary
        sectionCard(icon: "arrow.left.arrow.right", color: "FF9F0A", title: "Wo täuschst du dich?") {
            Text(r.selfVsOthers)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .lineSpacing(5)
        }

        // Surprise traits
        let surpriseTraits = r.traitStats.filter(\.surprise)
        if !surpriseTraits.isEmpty {
            sectionCard(icon: "exclamationmark.bubble.fill", color: "FF6B6B", title: "Überraschende Unterschiede") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(surpriseTraits) { t in
                        traitSurpriseRow(t)
                    }
                }
            }
        }
    }

    private func areaComparisonRow(_ area: ComparisonArea) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(area.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(area.gapLabel)
                    .font(.caption)
                    .foregroundStyle(Color(hex: area.gapColor))
            }

            // Du
            HStack(spacing: 8) {
                Text("Du")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 40, alignment: .trailing)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.08)).frame(height: 10)
                        Capsule().fill(Color(hex: "4A9EF8"))
                            .frame(width: geo.size.width * (area.selfRating / 5.0), height: 10)
                    }
                }
                .frame(height: 10)
                Text(String(format: "%.1f", area.selfRating))
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(Color(hex: "4A9EF8"))
                    .frame(width: 28)
            }

            // Andere
            HStack(spacing: 8) {
                Text("Andere")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 40, alignment: .trailing)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.08)).frame(height: 10)
                        Capsule().fill(Color(hex: "34C759"))
                            .frame(width: geo.size.width * (area.othersAverage / 5.0), height: 10)
                    }
                }
                .frame(height: 10)
                Text(String(format: "%.1f", area.othersAverage))
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(Color(hex: "34C759"))
                    .frame(width: 28)
            }

            // Delta badge
            let d = area.delta
            if abs(d) >= 0.2 {
                HStack(spacing: 4) {
                    Image(systemName: d > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.caption2)
                    Text(String(format: "Δ %+.1f", d))
                        .font(.caption2.monospacedDigit())
                }
                .foregroundStyle(Color(hex: area.gapColor))
            }
        }
    }

    private func traitSurpriseRow(_ t: TraitStat) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    Label(t.selfSelected ? "Du: Ja" : "Du: Nein",
                          systemImage: t.selfSelected ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(t.selfSelected ? Color(hex: "34C759") : .white.opacity(0.4))
                    Text("·").foregroundStyle(.white.opacity(0.3))
                    Text("Andere: \(Int(t.othersPercent * 100))%")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "FF6B6B"))
                }
            }
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color(hex: "FF6B6B"))
        }
        .padding(12)
        .background(Color(hex: "FF6B6B").opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Tab 3: Rohdaten

    @ViewBuilder
    private func rohdatenContent(_ r: AnalysisResult) -> some View {
        // Trait stats
        sectionCard(icon: "tag.fill", color: "4A9EF8", title: "Eigenschaften — wie oft genannt?") {
            VStack(spacing: 10) {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill").font(.caption2)
                        .foregroundStyle(Color(hex: "4A9EF8"))
                    Text("Du hast dich so gesehen")
                        .font(.caption2).foregroundStyle(.white.opacity(0.4))
                    Spacer()
                }
                ForEach(r.traitStats.sorted { $0.othersPercent > $1.othersPercent }) { t in
                    traitStatRow(t)
                }
            }
        }

        // Forced choice
        sectionCard(icon: "arrow.triangle.branch", color: "FF9F0A", title: "Entscheidungsstil — Antworten der anderen") {
            VStack(spacing: 20) {
                ForEach(r.forcedChoiceStats) { stat in
                    forcedChoiceRow(stat)
                }
            }
        }

        // Open text
        if !r.openTextResponses.isEmpty {
            sectionCard(icon: "text.bubble.fill", color: "6B5EE4", title: "Freitextantworten (\(r.openTextResponses.count))") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(r.openTextResponses.enumerated()), id: \.offset) { _, text in
                        HStack(alignment: .top, spacing: 10) {
                            Text("„")
                                .font(.title2.bold())
                                .foregroundStyle(Color(hex: "6B5EE4"))
                            Text(text)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .background(.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    private func traitStatRow(_ t: TraitStat) -> some View {
        HStack(spacing: 10) {
            Image(systemName: t.selfSelected ? "person.fill" : "person")
                .font(.caption)
                .foregroundStyle(t.selfSelected ? Color(hex: "4A9EF8") : .white.opacity(0.15))
                .frame(width: 16)

            Text(t.name)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 120, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08)).frame(height: 8)
                    Capsule().fill(barColor(for: t))
                        .frame(width: geo.size.width * t.othersPercent, height: 8)
                }
            }
            .frame(height: 8)

            Text("\(Int(t.othersPercent * 100))%")
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(barColor(for: t))
                .frame(width: 36, alignment: .trailing)
        }
    }

    private func barColor(for t: TraitStat) -> Color {
        if t.othersPercent >= 0.7 { return Color(hex: "34C759") }
        if t.othersPercent >= 0.4 { return Color(hex: "4A9EF8") }
        return Color(hex: "8E8E93")
    }

    private func forcedChoiceRow(_ stat: ForcedChoiceStat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(stat.question)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(0.5)

            ForEach(Array(stat.results.sorted { $0.value > $1.value }), id: \.key) { option, fraction in
                let isSelf = option == stat.selfChoice
                HStack(spacing: 8) {
                    Image(systemName: isSelf ? "person.fill" : "person")
                        .font(.caption2)
                        .foregroundStyle(isSelf ? Color(hex: "4A9EF8") : .clear)
                        .frame(width: 14)

                    Text(option)
                        .font(.subheadline)
                        .foregroundStyle(isSelf ? .white : .white.opacity(0.65))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.08)).frame(height: 8)
                            Capsule()
                                .fill(isSelf ? Color(hex: "4A9EF8") : Color(hex: "34C759").opacity(0.7))
                                .frame(width: max(0, geo.size.width * fraction), height: 8)
                        }
                    }
                    .frame(width: 80, height: 8)

                    Text("\(Int(fraction * 100))%")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(isSelf ? Color(hex: "4A9EF8") : .white.opacity(0.5))
                        .frame(width: 32, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Shared card builder

    private func sectionCard<Content: View>(
        icon: String, color: String, title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(Color(hex: color))
                    .frame(width: 32, height: 32)
                    .background(Color(hex: color).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal)
    }
}

#Preview {
    NavigationStack {
        ResultsView()
            .environmentObject(AuthService.shared)
    }
}
