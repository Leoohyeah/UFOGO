import SwiftUI
import UIKit

enum NumericKeyboardKind {
    case unsignedInteger
    case signedDecimal

    fileprivate var keyboardType: UIKeyboardType {
        switch self {
        case .unsignedInteger:
            return .numberPad
        case .signedDecimal:
            return .numbersAndPunctuation
        }
    }
}

struct NumericInputStyle: ViewModifier {
    let keyboard: NumericKeyboardKind
    let clearsOnFocus: Bool

    func body(content: Content) -> some View {
        content
            .keyboardType(keyboard.keyboardType)
            .foregroundStyle(.primary)
            .tint(.accentColor)
            .padding(.horizontal, 8)
            .frame(minHeight: 36)
            .background(
                Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UITextField.textDidBeginEditingNotification
                )
            ) { notification in
                guard let textField = notification.object as? UITextField,
                      textField.keyboardType == keyboard.keyboardType else { return }
                NumericKeyboardAccessory.install(on: textField)
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    DispatchQueue.main.async {
                        guard clearsOnFocus else { return }
                        guard let field = activeTextField() else { return }
                        NumericKeyboardAccessory.install(on: field)
                        field.text = ""
                        field.sendActions(for: .editingChanged)
                    }
                }
            )
    }

    private func activeTextField() -> UITextField? {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                if let field = findActiveTextField(in: window) {
                    return field
                }
            }
        }
        return nil
    }

    private func findActiveTextField(in view: UIView) -> UITextField? {
        if let field = view as? UITextField, field.isFirstResponder {
            return field
        }
        for subview in view.subviews {
            if let field = findActiveTextField(in: subview) {
                return field
            }
        }
        return nil
    }
}

private final class NumericKeyboardAccessory: NSObject {
    static let shared = NumericKeyboardAccessory()
    private static let accessoryTag = 7_426_013

    static func install(on textField: UITextField) {
        if textField.inputAccessoryView?.tag == accessoryTag { return }

        let toolbar = UIToolbar()
        toolbar.tag = accessoryTag
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem(
                barButtonSystemItem: .flexibleSpace,
                target: nil,
                action: nil
            ),
            UIBarButtonItem(
                title: "完成",
                style: .done,
                target: shared,
                action: #selector(dismissKeyboard)
            )
        ]
        textField.inputAccessoryView = toolbar
        if textField.isFirstResponder {
            textField.reloadInputViews()
        }
    }

    @objc private func dismissKeyboard() {
        KeyboardDismissal.dismiss()
    }
}

extension View {
    func numericInputStyle(
        keyboard: NumericKeyboardKind = .unsignedInteger,
        clearsOnFocus: Bool = true
    ) -> some View {
        modifier(
            NumericInputStyle(
                keyboard: keyboard,
                clearsOnFocus: clearsOnFocus
            )
        )
    }
}
