import SwiftUI

struct QuestionCard: View {
    let question: Question
    let answer: AnswerValue?
    let onAnswer: (AnswerValue) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(question.text)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
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
        .background(.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Trait grid

    private var traitGrid: some View {
        let options = question.options ?? []
        let selected: [String] = {
            if case .multipleChoice(let m) = answer { return m }
            return []
        }()

        return FlowLayout(spacing: 10) {
            ForEach(options, id: \.self) { trait in
                let isOn = selected.contains(trait)
                Button {
                    var current = selected
                    if isOn { current.removeAll { $0 == trait } }
                    else { current.append(trait) }
                    onAnswer(.multipleChoice(current))
                } label: {
                    Text(trait)
                        .font(.subheadline)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(isOn ? Color(hex: "4A9EF8") : .white.opacity(0.08))
                        .foregroundStyle(isOn ? .white : .white.opacity(0.7))
                        .clipShape(Capsule())
                        .animation(.easeInOut(duration: 0.15), value: isOn)
                }
            }
        }
    }

    // MARK: - Forced choice

    private var forcedChoiceButtons: some View {
        VStack(spacing: 10) {
            ForEach(question.options ?? [], id: \.self) { option in
                let isSelected: Bool = {
                    if case .singleChoice(let s) = answer { return s == option }
                    return false
                }()

                Button {
                    onAnswer(.singleChoice(option))
                } label: {
                    HStack {
                        Text(option)
                            .font(.subheadline)
                            .foregroundStyle(isSelected ? .white : .white.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? Color(hex: "4A9EF8") : .white.opacity(0.3))
                    }
                    .padding(14)
                    .background(isSelected ? Color(hex: "4A9EF8").opacity(0.18) : .white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(isSelected ? Color(hex: "4A9EF8").opacity(0.7) : .clear, lineWidth: 1.5)
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
                                    .fill(i <= current ? Color(hex: "4A9EF8") : .white.opacity(0.1))
                                    .frame(width: 48, height: 48)
                                Text("\(i)")
                                    .font(.headline)
                                    .foregroundStyle(i <= current ? .white : .white.opacity(0.5))
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
                Text("Low")
                Spacer()
                Text("High")
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: - Open text

    @State private var textInput = ""

    private var openTextView: some View {
        TextField("Type your answer here…", text: Binding(
            get: {
                if case .text(let t) = answer { return t }
                return ""
            },
            set: { onAnswer(.text($0)) }
        ), axis: .vertical)
        .lineLimit(3...6)
        .foregroundStyle(.white)
        .padding(14)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
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
        Color(hex: "0A1628").ignoresSafeArea()
        QuestionCard(
            question: Question.surveyQuestions[0],
            answer: .multipleChoice(["calm", "analytical"]),
            onAnswer: { _ in }
        )
        .padding()
    }
}
