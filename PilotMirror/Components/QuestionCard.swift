import SwiftUI

struct QuestionCard: View {
    let question: Question
    let answer: AnswerValue?
    var mode: SurveyMode = .selfAssessment
    var candidateName: String? = nil
    let onAnswer: (AnswerValue) -> Void
    @EnvironmentObject var lang: LanguageService

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(question.displayText(mode: mode, candidateName: candidateName, isGerman: lang.isGerman))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.appPrimary)
                .fixedSize(horizontal: false, vertical: true)

            switch question.type {
            case .traitSelection:
                traitGrid
            case .forcedChoice:
                forcedChoiceButtons
            case .ratingScale:
                ratingView
            case .openText:
                openTextView
            }
        }
        .padding(20)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Trait grid

    private var traitGrid: some View {
        let canonical = question.options ?? []
        let display = question.displayOptions(isGerman: lang.isGerman) ?? canonical
        let selected: [String] = {
            if case .multipleChoice(let m) = answer { return m }
            return []
        }()

        return FlowLayout(spacing: 10) {
            ForEach(Array(zip(display, canonical)), id: \.1) { displayLabel, key in
                let isOn = selected.contains(key)
                Button {
                    var current = selected
                    if isOn { current.removeAll { $0 == key } }
                    else { current.append(key) }
                    onAnswer(.multipleChoice(current))
                } label: {
                    Text(displayLabel)
                        .font(.subheadline)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(isOn ? Color(hex: "4A9EF8") : Color.appInputBG)
                        .foregroundStyle(isOn ? .white : Color.appPrimary)
                        .clipShape(Capsule())
                        .animation(.easeInOut(duration: 0.15), value: isOn)
                }
            }
        }
    }

    // MARK: - Forced choice

    private var forcedChoiceButtons: some View {
        let canonical = question.options ?? []
        let display = question.displayOptions(isGerman: lang.isGerman) ?? canonical
        return VStack(spacing: 10) {
            ForEach(Array(zip(display, canonical)), id: \.1) { displayLabel, key in
                let isSelected: Bool = {
                    if case .singleChoice(let s) = answer { return s == key }
                    return false
                }()

                Button {
                    onAnswer(.singleChoice(key))
                } label: {
                    HStack {
                        Text(displayLabel)
                            .font(.subheadline)
                            .foregroundStyle(isSelected ? .white : Color.appPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? Color(hex: "4A9EF8") : Color.appTertiary)
                    }
                    .padding(14)
                    .background(isSelected ? Color(hex: "4A9EF8").opacity(0.18) : Color.appCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(isSelected ? Color(hex: "4A9EF8").opacity(0.7) : Color.appBorder, lineWidth: 1)
                    )
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Rating scale

    private var ratingView: some View {
        let current: Int = {
            if case .rating(let r) = answer { return r }
            return 0
        }()

        return VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { i in
                    Button {
                        onAnswer(.rating(i))
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(i <= current ? Color(hex: "4A9EF8") : Color.appInputBG)
                                    .frame(width: 48, height: 48)
                                Text("\(i)")
                                    .font(.headline)
                                    .foregroundStyle(i <= current ? .white : Color.appSecondary)
                            }
                            .scaleEffect(i == current ? 1.1 : 1.0)
                            .animation(.spring(response: 0.25), value: current)
                        }
                    }
                    .buttonStyle(.plain)
                    if i < 5 { Spacer() }
                }
            }
            HStack {
                Text(lang.t("Niedrig", "Low"))
                Spacer()
                Text(lang.t("Hoch", "High"))
            }
            .font(.caption2)
            .foregroundStyle(Color.appTertiary)
        }
    }

    // MARK: - Open text

    @State private var localText: String = ""

    private var openTextView: some View {
        TextField(question.displayPlaceholder(isGerman: lang.isGerman) ?? lang.t("Antwort eingeben…", "Enter your answer…"), text: $localText, axis: .vertical)
        .lineLimit(3...6)
        .foregroundStyle(Color.appPrimary)
        .padding(14)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.appBorder, lineWidth: 1)
        )
        .onAppear {
            if case .text(let t) = answer { localText = t } else { localText = "" }
        }
        .onChange(of: localText) { _, newValue in
            onAnswer(.text(newValue))
        }
    }
}

// MARK: - FlowLayout (wrapping HStack)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map { $0.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0 }.reduce(0, +)
            + CGFloat(max(rows.count - 1, 0)) * spacing
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for view in row {
                let size = view.sizeThatFits(.unspecified)
                view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var x: CGFloat = 0
        let maxW = proposal.width ?? .infinity
        for view in subviews {
            let w = view.sizeThatFits(.unspecified).width
            if x + w > maxW, !rows.last!.isEmpty {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append(view)
            x += w + spacing
        }
        return rows
    }
}

#Preview {
    ZStack {
        Color.appBG.ignoresSafeArea()
        QuestionCard(
            question: Question.surveyQuestions[0],
            answer: .multipleChoice(["calm", "analytical"]),
            onAnswer: { _ in }
        )
        .environmentObject(LanguageService.shared)
        .padding()
    }
}
