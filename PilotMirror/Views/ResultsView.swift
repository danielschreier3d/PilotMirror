import SwiftUI

struct ResultsView: View {
    @ObservedObject var aiService = AIAnalysisService.shared
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var lang: LanguageService
    @State private var selectedTab = 0
    @State private var relationshipFilter: Respondent.RelationshipType? = nil

    var result: AnalysisResult? { aiService.result }

    var body: some View {
        ZStack {
            Color.appBG.ignoresSafeArea()

            if let result {
                VStack(spacing: 0) {
                    // Tab picker (fixed, not scrolling)
                    Picker("", selection: $selectedTab) {
                        Text(lang.t("Profil", "Profile")).tag(0)
                        Text(lang.t("Vergleich", "Comparison")).tag(1)
                        Text(lang.t("Rohdaten", "Raw Data")).tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 12)

                    // Relationship filter bar (shown for Vergleich + Rohdaten)
                    if selectedTab == 1 || selectedTab == 2 {
                        relationshipFilterBar
                    }

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
                    Text(lang.t("Analyse wird erstellt…", "Generating analysis…"))
                        .foregroundStyle(Color.appSecondary)
                }
            }
        }
        .alert("KI-Fehler", isPresented: Binding(
            get: { aiService.error != nil },
            set: { if !$0 { aiService.error = nil } }
        )) {
            Button("OK") { aiService.error = nil }
        } message: {
            Text(aiService.error ?? "")
        }
        .navigationTitle(lang.t("Dein Report", "Your Report"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let r = result {
                    ShareLink(
                        item: exportText(r),
                        subject: Text("PilotMirror Report")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(Color(hex: "4A9EF8"))
                    }
                }
            }
        }
        .onAppear {
            if aiService.result == nil {
                Task { await aiService.loadExistingResult() }
            }
        }
    }

    // MARK: - Relationship filter bar

    private var relationshipFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: lang.t("Alle", "All"), isActive: relationshipFilter == nil) {
                    withAnimation(.easeInOut(duration: 0.2)) { relationshipFilter = nil }
                }
                ForEach(Respondent.RelationshipType.allCases, id: \.self) { rel in
                    let count = aiService.respondentsWithRelationship.filter { $0.relationship == rel }.count
                    if count > 0 {
                        filterChip(
                            label: lang.isGerman ? rel.labelDE : rel.labelEN,
                            isActive: relationshipFilter == rel
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                relationshipFilter = relationshipFilter == rel ? nil : rel
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
    }

    private func filterChip(label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(isActive ? Color(hex: "4A9EF8") : Color.appInputBG)
                .foregroundStyle(isActive ? .white : .white.opacity(0.6))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(isActive ? Color.clear : Color.appBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func exportText(_ r: AnalysisResult) -> String {
        var lines: [String] = ["# PilotMirror 360° Report", ""]
        lines.append("## \(lang.t("Profil", "Profile"))")
        lines.append(r.personalitySummary)
        lines.append("")
        lines.append("### \(lang.t("Stärken", "Strengths"))")
        r.perceivedStrengths.forEach { lines.append("• \($0)") }
        lines.append("")
        lines.append("### \(lang.t("Entwicklungsfelder", "Development Areas"))")
        r.possibleWeaknesses.forEach { lines.append("• \($0)") }
        lines.append("")
        lines.append("### \(lang.t("Selbst- vs. Fremdwahrnehmung", "Self vs. Others"))")
        lines.append(r.selfVsOthers)
        lines.append("")
        lines.append("### \(lang.t("Empfehlung", "Recommendation"))")
        lines.append(r.assessmentAdvice)
        return lines.joined(separator: "\n")
    }

    // MARK: - Tab 1: Profil

    @ViewBuilder
    private func profilContent(_ r: AnalysisResult) -> some View {
        // Trait chips — always shown
        sectionCard(icon: "person.fill", color: "4A9EF8", title: lang.t("Das macht dich aus", "Your Defining Traits")) {
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
                                .foregroundStyle(Color.appSecondary)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color(hex: "4A9EF8").opacity(0.2))
                        .foregroundStyle(Color.appPrimary)
                        .clipShape(Capsule())
                    }
                }

                if !r.personalitySummary.isEmpty {
                    Divider().overlay(Color.appBorder)
                    Text(r.personalitySummary)
                        .font(.subheadline)
                        .foregroundStyle(Color.appPrimary)
                        .lineSpacing(5)
                }
            }
        }

        if r.personalitySummary.isEmpty {
            // KI computing or unavailable
            HStack(spacing: 12) {
                if aiService.isComputingAI {
                    ProgressView().tint(Color(hex: "6B5EE4")).scaleEffect(0.9)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(hex: "6B5EE4"))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(aiService.isComputingAI
                         ? lang.t("KI-Analyse läuft…", "AI Analysis Running…")
                         : lang.t("KI-Analyse noch nicht verfügbar", "AI Analysis Not Yet Available"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appPrimary)
                    Text(lang.t("Stärken, Schwächen und Empfehlungen werden per KI generiert. Statistiken und Rohdaten stehen bereits zur Verfügung.",
                                "Strengths, weaknesses and tips are AI-generated. Statistics and raw data are already available."))
                        .font(.caption)
                        .foregroundStyle(Color.appSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .background(Color(hex: "6B5EE4").opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(hex: "6B5EE4").opacity(0.3), lineWidth: 1))
            .padding(.horizontal)
        } else {
            // Stärken
            sectionCard(icon: "star.fill", color: "34C759", title: lang.t("Deine Stärken", "Your Strengths")) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(r.perceivedStrengths.enumerated()), id: \.offset) { _, s in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color(hex: "34C759"))
                                .font(.system(size: 18))
                            Text(s)
                                .font(.subheadline)
                                .foregroundStyle(Color.appPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            // Schwächen
            sectionCard(icon: "exclamationmark.triangle.fill", color: "FF9F0A", title: lang.t("Deine Schwächen", "Your Weaknesses")) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(r.possibleWeaknesses.enumerated()), id: \.offset) { _, w in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundStyle(Color(hex: "FF9F0A"))
                                .font(.system(size: 18))
                            Text(w)
                                .font(.subheadline)
                                .foregroundStyle(Color.appPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            // Advice
            sectionCard(icon: "sparkles", color: "6B5EE4", title: lang.t("Empfehlung für dein Assessment", "Assessment Recommendations")) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(r.assessmentAdvice)
                        .font(.subheadline)
                        .foregroundStyle(Color.appPrimary)
                        .lineSpacing(5)

                    // Fixed hint — always shown
                    Divider().overlay(Color.appBorder)
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundStyle(Color(hex: "FFD60A"))
                        Text(lang.t(
                            "Bereite für jede deiner Stärken und Schwächen ein konkretes Beispiel vor — Assessoren fragen gezielt danach, um deine Selbsteinschätzung zu überprüfen.",
                            "Prepare a concrete example for each of your strengths and weaknesses — assessors will ask for them specifically to verify your self-assessment."))
                            .font(.caption)
                            .foregroundStyle(Color.appPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    let licenseHints = licenseSpecificHints(for: auth.currentUser?.flightLicenses ?? [])
                    if !licenseHints.isEmpty {
                        Divider().overlay(Color.appBorder)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(lang.t("Mögliche Fragen zu deiner Lizenz", "Possible License-Related Questions"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(hex: "6B5EE4"))
                                .textCase(.uppercase)
                                .tracking(0.4)
                            ForEach(licenseHints, id: \.self) { hint in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "questionmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color(hex: "6B5EE4").opacity(0.7))
                                    Text(hint)
                                        .font(.caption)
                                        .foregroundStyle(Color.appSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }

            // Motivation card — shown when at least one person left a confidence rating or wish
            if r.motivationConfidenceCount > 0 || !r.motivationWishes.isEmpty {
                motivationCard(r)
            }
        }
    }

    @ViewBuilder
    private func motivationCard(_ r: AnalysisResult) -> some View {
        sectionCard(icon: "heart.circle.fill", color: "FF6B6B",
                    title: lang.t("Deine Unterstützer", "Your Supporters")) {
            VStack(alignment: .leading, spacing: 16) {

                // Confidence bar
                if r.motivationConfidenceCount > 0, let avg = r.motivationConfidenceAvg {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(lang.t(
                                "\(r.motivationConfidenceCount) Person\(r.motivationConfidenceCount == 1 ? "" : "en") glauben an dich",
                                "\(r.motivationConfidenceCount) person\(r.motivationConfidenceCount == 1 ? "" : "s") believe in you"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.appPrimary)
                            Spacer()
                            Text(String(format: "%.1f / 5", avg))
                                .font(.subheadline.bold().monospacedDigit())
                                .foregroundStyle(Color(hex: "FF6B6B"))
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.appInputBG).frame(height: 10)
                                Capsule().fill(Color(hex: "FF6B6B"))
                                    .frame(width: geo.size.width * (avg / 5.0), height: 10)
                            }
                        }
                        .frame(height: 10)

                        Text(lang.t(
                            "Durchschnittliche Zuversicht deiner Unterstützer",
                            "Average confidence of your supporters"))
                            .font(.caption)
                            .foregroundStyle(Color.appTertiary)
                    }
                }

                // Wishes
                if !r.motivationWishes.isEmpty {
                    if r.motivationConfidenceCount > 0 {
                        Divider().overlay(Color.appBorder)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(lang.t("Persönliche Wünsche", "Personal Messages"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.appTertiary)
                            .textCase(.uppercase)
                            .tracking(0.5)

                        ForEach(Array(r.motivationWishes.enumerated()), id: \.offset) { _, wish in
                            HStack(alignment: .top, spacing: 10) {
                                Text(wish)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .italic()
                            }
                            .padding(12)
                            .background(Color(hex: "FF6B6B").opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tab 2: Vergleich

    @ViewBuilder
    private func vergleichContent(_ r: AnalysisResult) -> some View {
        let areas = aiService.respondentsWithRelationship.isEmpty
            ? r.comparisonAreas
            : aiService.filteredComparisonAreas(for: relationshipFilter)

        let surpriseTraits: [TraitStat] = {
            if aiService.respondentsWithRelationship.isEmpty { return r.traitStats.filter(\.surprise) }
            return aiService.filteredTraitStats(for: relationshipFilter).filter(\.surprise)
        }()

        // Rating areas — Du vs. Andere
        sectionCard(icon: "chart.bar.fill", color: "4A9EF8", title: lang.t("Bereiche — Du vs. Andere (1–5)", "Areas — You vs. Others (1–5)")) {
            if areas.isEmpty {
                Text(lang.t("Keine Daten für diese Gruppe.", "No data for this group."))
                    .font(.subheadline)
                    .foregroundStyle(Color.appTertiary)
            } else {
                VStack(spacing: 22) {
                    ForEach(areas) { area in
                        areaComparisonRow(area)
                    }
                }
            }
        }

        // Self vs Others summary — only with AI
        if !r.selfVsOthers.isEmpty {
            sectionCard(icon: "arrow.left.arrow.right", color: "FF9F0A", title: lang.t("So realistisch schätzt du dich ein", "How Realistic Is Your Self-Image")) {
                Text(r.selfVsOthers)
                    .font(.subheadline)
                    .foregroundStyle(Color.appPrimary)
                    .lineSpacing(5)
            }
        }

        // Surprise traits
        if !surpriseTraits.isEmpty {
            sectionCard(icon: "exclamationmark.bubble.fill", color: "FF6B6B", title: lang.t("Überraschende Unterschiede", "Surprising Differences")) {
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
                    .foregroundStyle(Color.appPrimary)
                Spacer()
                Text(area.gapLabel)
                    .font(.caption)
                    .foregroundStyle(Color(hex: area.gapColor))
            }

            // Du
            HStack(spacing: 8) {
                Text(lang.t("Du", "You"))
                    .font(.caption2)
                    .foregroundStyle(Color.appSecondary)
                    .frame(width: 40, alignment: .trailing)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.appInputBG).frame(height: 10)
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
                Text(lang.t("Andere", "Others"))
                    .font(.caption2)
                    .foregroundStyle(Color.appSecondary)
                    .frame(width: 40, alignment: .trailing)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.appInputBG).frame(height: 10)
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
                    .foregroundStyle(Color.appPrimary)
                HStack(spacing: 6) {
                    Label(t.selfSelected ? lang.t("Du: Ja", "You: Yes") : lang.t("Du: Nein", "You: No"),
                          systemImage: t.selfSelected ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(t.selfSelected ? Color(hex: "34C759") : .white.opacity(0.4))
                    Text("·").foregroundStyle(Color.appTertiary)
                    Text(lang.t("Andere: \(Int(t.othersPercent * 100))%", "Others: \(Int(t.othersPercent * 100))%"))
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
        let traits: [TraitStat] = aiService.respondentsWithRelationship.isEmpty
            ? r.traitStats
            : aiService.filteredTraitStats(for: relationshipFilter)

        let fcStats: [ForcedChoiceStat] = aiService.respondentsWithRelationship.isEmpty
            ? r.forcedChoiceStats
            : aiService.filteredForcedChoiceStats(for: relationshipFilter)

        let openByQ: [String: [String]] = aiService.respondentsWithRelationship.isEmpty
            ? aiService.openTextByQuestion
            : aiService.filteredOpenText(for: relationshipFilter)

        // Trait stats
        sectionCard(icon: "tag.fill", color: "4A9EF8",
                    title: lang.t("Deine Eigenschaften — wie oft genannt?", "Your Traits — How Often Mentioned?")) {
            VStack(spacing: 10) {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill").font(.caption2)
                        .foregroundStyle(Color(hex: "4A9EF8"))
                    Text(lang.t("Du hast dich so beschrieben", "How you described yourself"))
                        .font(.caption2).foregroundStyle(Color.appTertiary)
                    Spacer()
                }
                ForEach(traits.sorted { $0.othersPercent > $1.othersPercent }) { t in
                    traitStatRow(t)
                }
            }
        }

        // Forced choice
        sectionCard(icon: "arrow.triangle.branch", color: "FF9F0A",
                    title: lang.t("Dein Entscheidungsstil — Antworten der anderen", "Your Decision Style — Others' Answers")) {
            if fcStats.isEmpty {
                Text(lang.t("Keine Daten für diese Gruppe.", "No data for this group."))
                    .font(.subheadline)
                    .foregroundStyle(Color.appTertiary)
            } else {
                VStack(spacing: 20) {
                    ForEach(fcStats) { stat in
                        forcedChoiceRow(stat)
                    }
                }
            }
        }

        // Open text — grouped by question
        let openIds = ["q10","q11","q12","q13","q14","q15","q16","q17","q18"]
        let groups: [(String, [String])] = openIds.compactMap { id in
            guard let answers = openByQ[id], !answers.isEmpty else { return nil }
            let title = Question.surveyQuestions.first(where: { $0.id == id })?.text ?? id
            return (title, answers)
        }

        if !groups.isEmpty {
            sectionCard(icon: "text.bubble.fill", color: "6B5EE4",
                        title: lang.t("So sehen andere dich", "How Others See You")) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(groups.enumerated()), id: \.offset) { idx, group in
                        VStack(alignment: .leading, spacing: 10) {
                            // Question header — prominent
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(hex: "6B5EE4"))
                                    .frame(width: 3, height: 16)
                                Text(group.0)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.appPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            // Answers
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(group.1.enumerated()), id: \.offset) { _, text in
                                    ExpandableAnswerView(text: text)
                                }
                            }
                        }
                        .padding(.vertical, 16)

                        // Divider between groups (not after last)
                        if idx < groups.count - 1 {
                            Divider()
                                .background(Color.appBorder)
                        }
                    }
                }
            }
        } else if !r.openTextResponses.isEmpty {
            // Fallback for results loaded from Supabase (no grouped data)
            sectionCard(icon: "text.bubble.fill", color: "6B5EE4",
                        title: lang.t("So sehen andere dich", "How Others See You")) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(r.openTextResponses.enumerated()), id: \.offset) { _, text in
                        ExpandableAnswerView(text: text)
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
                .foregroundStyle(Color.appPrimary)
                .frame(width: 120, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.appInputBG).frame(height: 8)
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
                .foregroundStyle(Color.appSecondary)
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
                            Capsule().fill(Color.appInputBG).frame(height: 8)
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

    // MARK: - License-specific hints

    private func licenseSpecificHints(for licenses: [User.FlightLicense]) -> [String] {
        let relevant = licenses.filter { $0 != .none }
        guard !relevant.isEmpty else { return [] }

        let isMotorized = relevant.contains(.ppl) || relevant.contains(.lapl)
            || relevant.contains(.tmg) || relevant.contains(.ultralight)
        let isParamotor = relevant.contains(.paramotor)
        let isOther     = relevant.contains(.other)

        var hints: [String] = []

        if isMotorized {
            hints += lang.isGerman ? [
                "Welche Luftraumklassen kennst du und was darf man wo fliegen?",
                "Wie gehst du eine Flugplanung an? (Wetter, NOTAM, Route, Ausweichplätze)",
                "Was tust du bei einem unerwarteten Wetterumschwung in der Luft?",
                "Wie bereitest du dich auf einen Flug in kontrollierten Luftraum vor?",
                "Was versteht man unter CRM und warum ist es im Cockpit wichtig?"
            ] : [
                "Which airspace classes do you know and what is permitted where?",
                "How do you approach flight planning? (weather, NOTAM, route, alternates)",
                "What do you do in case of an unexpected weather change in flight?",
                "How do you prepare for a flight into controlled airspace?",
                "What is CRM and why does it matter in the cockpit?"
            ]
        }

        if isParamotor {
            hints += lang.isGerman ? [
                "Woran erkennst du gefährliche oder fluguntaugliche Thermik?",
                "Wie schätzt du deinen Gleitwinkel und deine Reichweite ein?",
                "Welche Wetterphänomene sind für Paramotor-/Gleitschirmpiloten besonders relevant?",
                "Wie gehst du mit einem plötzlichen Winddreher oder einer Böe um?",
                "Was prüfst du beim Preflight-Check an deinem Gerät?"
            ] : [
                "How do you recognize dangerous or unflyable thermals?",
                "How do you estimate your glide ratio and range?",
                "Which weather phenomena are especially relevant for paramotor/paraglider pilots?",
                "How do you handle a sudden wind shift or gust?",
                "What do you check during your preflight inspection?"
            ]
        }

        if isOther {
            hints += lang.isGerman ? [
                "Welche Lufträume und Regularien sind für deine Art des Fliegens relevant?",
                "Wie planst du einen Flug und welche Sicherheitsaspekte berücksichtigst du?",
                "Beschreibe eine Situation, in der du eine schnelle Entscheidung in der Luft treffen musstest."
            ] : [
                "Which airspace and regulations are relevant for your type of flying?",
                "How do you plan a flight and what safety aspects do you consider?",
                "Describe a situation where you had to make a quick decision in the air."
            ]
        }

        return hints
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
                    .foregroundStyle(Color.appPrimary)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal)
    }
}

// MARK: - Expandable answer bubble

private struct ExpandableAnswerView: View {
    let text: String
    @State private var isExpanded = false
    @State private var isTruncated = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                Text("„")
                    .font(.title2.bold())
                    .foregroundStyle(Color(hex: "6B5EE4"))
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(Color.appPrimary)
                    .lineLimit(isExpanded ? nil : 2)
                    .background(
                        // Detect if text would be truncated at 2 lines
                        GeometryReader { displayed in
                            Text(text)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                                .hidden()
                                .background(GeometryReader { full in
                                    Color.clear.onAppear {
                                        isTruncated = full.size.height > displayed.size.height + 1
                                    }
                                })
                        }
                    )
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }

            if isTruncated || isExpanded {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "Weniger anzeigen" : "Mehr anzeigen")
                            .font(.caption.weight(.semibold))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(Color(hex: "6B5EE4"))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.appInputBG, lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        ResultsView()
            .environmentObject(AuthService.shared)
            .environmentObject(LanguageService.shared)
    }
}
