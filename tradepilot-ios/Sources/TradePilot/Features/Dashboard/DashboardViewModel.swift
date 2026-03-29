import SwiftUI
import SwiftData
import Observation

@Observable
final class DashboardViewModel {
    enum ViewState {
        case loading
        case loaded([Recommendation])
        case empty
        case error(String)
    }

    var state: ViewState = .loading

    private let cache = LocalCache()

    @MainActor
    func load(context: ModelContext) async {
        state = .loading
        let items = cache.fetchToday(in: context)
        if items.isEmpty {
            state = .empty
        } else {
            state = .loaded(items)
        }
    }

    @MainActor
    func refresh(context: ModelContext) async {
        let items = cache.fetchToday(in: context)
        if items.isEmpty {
            state = .empty
        } else {
            state = .loaded(items)
        }
    }
}
