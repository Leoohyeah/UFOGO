import SwiftUI

/// 可展開的速度控制面板元件
struct ExpandableSpeedPanel: View {
    private static let autoCollapseDelay: TimeInterval = 0.9

    @Binding var speed: Double
    @Binding var isExpanded: Bool
    @FocusState private var focusedField: Field?
    @State private var autoCollapseTask: Task<Void, Never>?
    @State private var sliderIsBeingEdited = false
    @State private var didInteractWithSliderInCurrentExpansion = false
    
    var onSpeedChanged: (Double) -> Void = { _ in }
    var unit: String = "km/hr"
    var range: ClosedRange<Double> = 0...1000
    var maxWidth: CGFloat? = nil
    
    private enum Field {
        case speed
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // 展開/收起按鈕
            Button {
                withAnimation(AnimationPreferences.standard) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.tint)
                    Spacer()
                    Text("\(Int(speed)) \(unit)")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.tint)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .frame(height: 40)
                .panelStyle(cornerRadius: 12)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.speed)
            .accessibilityValue("\(Int(speed)) \(L10n.speedUnit)")
            .accessibilityHint(isExpanded ? "已展開速度面板" : "點擊展開速度面板")
            
            // 展開的控制面板
            if isExpanded {
                VStack(spacing: 10) {
                    // 數字輸入欄
                    HStack {
                        TextField("0", text: speedTextForEditing)
                            .focused($focusedField, equals: .speed)
                            .multilineTextAlignment(.trailing)
                            .font(.body.monospacedDigit())
                            .numericInputStyle()
                            .submitLabel(.done)
                            .onSubmit {
                                finishAdjustment()
                            }
                        Text(L10n.speedUnit).foregroundStyle(.secondary)
                    }
                    .accessibilityLabel(L10n.speed + " 輸入")
                    
                    // 滑塊
                    Slider(
                        value: $speed,
                        in: range,
                        step: 1,
                        onEditingChanged: { isEditing in
                            if isEditing {
                                sliderIsBeingEdited = true
                                didInteractWithSliderInCurrentExpansion = true
                                autoCollapseTask?.cancel()
                                autoCollapseTask = nil
                            }
                            onSpeedChanged(speed)
                            if !isEditing
                                && sliderIsBeingEdited
                                && didInteractWithSliderInCurrentExpansion {
                                sliderIsBeingEdited = false
                                finishAdjustment()
                            }
                        }
                    )
                    .accessibilityLabel(L10n.speed + " 滑塊")
                    .accessibilityValue("\(Int(speed)) \(L10n.speedUnit)")
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment:
                            speed = min(speed + 1, range.upperBound)
                        case .decrement:
                            speed = max(speed - 1, range.lowerBound)
                        @unknown default:
                            break
                        }
                        onSpeedChanged(speed)
                    }
                }
                .padding(12)
                .panelStyle()
                .transition(AnimationPreferences.expandTransition)
            }
        }
        .if(maxWidth != nil) { view in
            view.frame(maxWidth: maxWidth)
        }
        .onDisappear {
            autoCollapseTask?.cancel()
            autoCollapseTask = nil
            sliderIsBeingEdited = false
            didInteractWithSliderInCurrentExpansion = false
        }
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                sliderIsBeingEdited = false
                didInteractWithSliderInCurrentExpansion = false
            }
        }
        .onChange(of: focusedField) { _, field in
            guard field == .speed else { return }
            autoCollapseTask?.cancel()
            autoCollapseTask = nil
        }
    }
    
    /// 用於 TextField 的速度文本綁定
    private var speedTextForEditing: Binding<String> {
        Binding(
            get: { String(Int(speed)) },
            set: { newValue in
                if newValue.isEmpty {
                    // 允許暫時為空
                } else if let newSpeed = Double(newValue) {
                    let clampedValue = min(max(newSpeed, range.lowerBound), range.upperBound)
                    speed = clampedValue
                    onSpeedChanged(clampedValue)
                    scheduleAutoCollapseIfNeeded()
                }
            }
        )
    }

    private func scheduleAutoCollapseIfNeeded() {
        guard isExpanded else { return }
        autoCollapseTask?.cancel()
        autoCollapseTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.autoCollapseDelay))
            guard !Task.isCancelled, isExpanded else { return }
            finishAdjustment()
        }
    }

    private func finishAdjustment() {
        autoCollapseTask?.cancel()
        autoCollapseTask = nil
        onSpeedChanged(speed)
        focusedField = nil
        withAnimation(AnimationPreferences.standard) {
            isExpanded = false
        }
    }
}

#Preview {
    @Previewable @State var speed: Double = 10
    @Previewable @State var isExpanded = false
    
    return ExpandableSpeedPanel(
        speed: $speed,
        isExpanded: $isExpanded,
        onSpeedChanged: { _ in }
    )
    .padding()
}
