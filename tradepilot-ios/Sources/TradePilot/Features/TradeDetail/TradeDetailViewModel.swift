import SwiftUI
import SwiftData
import Observation

@Observable
final class TradeDetailViewModel {
    var recommendation: Recommendation

    init(recommendation: Recommendation) {
        self.recommendation = recommendation
    }

    // Sections expanded state
    var rationaleExpanded = true
    var signalsExpanded   = true
    var riskExpanded      = false
    var greeksExpanded    = false
    var citationsExpanded = false
}
