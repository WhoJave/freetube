import Foundation
import Combine

/// Global, observable auth state. Root view watches this and routes Login when `loggedOut` fires.
/// CLAUDE.md §12: on `cookieExpired` / 401 the session manager flips this and clears cookies.
final class AuthState: ObservableObject {
    enum Status: Equatable {
        case unknown
        case loggedIn(displayName: String?)
        case loggedOut
    }

    @Published var status: Status = .unknown

    static let shared = AuthState()

    private init() {}
}
