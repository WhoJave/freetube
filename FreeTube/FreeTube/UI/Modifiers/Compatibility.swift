import SwiftUI

// Keep the iOS 17 onChange behavior while providing an iOS 16 implementation.
// On iOS 16 an initial callback happens on appearance; later callbacks happen
// whenever the Equatable value changes, just as in the newer overload.
extension View {
    @ViewBuilder
    func onCompatibleChange<Value: Equatable>(
        of value: Value,
        initial: Bool = false,
        perform action: @escaping (Value) -> Void
    ) -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: value, initial: initial) { _, newValue in
                action(newValue)
            }
        } else {
            self.onAppear {
                if initial { action(value) }
            }
            .onChange(of: value, perform: action)
        }
    }

    @ViewBuilder
    func compatiblePulse<Value: Equatable>(value: Value) -> some View {
        if #available(iOS 17.0, *) {
            self.symbolEffect(.pulse, options: .repeating, value: value)
        } else {
            self
        }
    }
}
