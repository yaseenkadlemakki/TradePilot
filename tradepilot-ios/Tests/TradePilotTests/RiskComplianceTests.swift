import XCTest
@testable import TradePilot

final class RiskComplianceTests: XCTestCase {
    private var compliance: RiskCompliance!

    override func setUp() {
        super.setUp()
        compliance = RiskCompliance()
    }

    // MARK: - Passing cases

    func testGoodCandidatePasses() {
        let features = makeFeatures(oi: 2000, volume: 500, spread: 0.05, ivRank: 0.5, dte: 30, sentiment: 0.4, mentionVol: 0.5)
        XCTAssertEqual(compliance.validate(features), .passed)
    }

    // MARK: - Open interest

    func testLowOpenInterestRejects() {
        let features = makeFeatures(oi: 499, volume: 500, spread: 0.05)
        if case .rejected(let reason) = compliance.validate(features) {
            XCTAssertTrue(reason.contains("Open interest"))
        } else {
            XCTFail("Expected rejection")
        }
    }

    func testExactMinOpenInterestPasses() {
        let features = makeFeatures(oi: 500, volume: 500, spread: 0.05)
        XCTAssertEqual(compliance.validate(features), .passed)
    }

    // MARK: - Volume

    func testLowVolumeRejects() {
        let features = makeFeatures(oi: 2000, volume: 99, spread: 0.05)
        if case .rejected(let reason) = compliance.validate(features) {
            XCTAssertTrue(reason.contains("Volume"))
        } else {
            XCTFail("Expected rejection")
        }
    }

    func testExactMinVolumePasses() {
        let features = makeFeatures(oi: 2000, volume: 100, spread: 0.05)
        XCTAssertEqual(compliance.validate(features), .passed)
    }

    // MARK: - Spread

    func testWideSpreadRejects() {
        let features = makeFeatures(oi: 2000, volume: 500, spread: 0.16)
        if case .rejected(let reason) = compliance.validate(features) {
            XCTAssertTrue(reason.contains("spread") || reason.contains("Bid-ask"))
        } else {
            XCTFail("Expected rejection")
        }
    }

    func testExactMaxSpreadPasses() {
        let features = makeFeatures(oi: 2000, volume: 500, spread: 0.15)
        XCTAssertEqual(compliance.validate(features), .passed)
    }

    // MARK: - IV rank

    func testExtremeIVRejects() {
        let features = makeFeatures(oi: 2000, volume: 500, spread: 0.05, ivRank: 0.91)
        if case .rejected(let reason) = compliance.validate(features) {
            XCTAssertTrue(reason.contains("IV"))
        } else {
            XCTFail("Expected rejection")
        }
    }

    // MARK: - DTE

    func testDTETooLowRejects() {
        let features = makeFeatures(oi: 2000, volume: 500, spread: 0.05, dte: 6)
        if case .rejected(let reason) = compliance.validate(features) {
            XCTAssertTrue(reason.contains("DTE"))
        } else {
            XCTFail("Expected rejection")
        }
    }

    func testDTETooHighRejects() {
        let features = makeFeatures(oi: 2000, volume: 500, spread: 0.05, dte: 61)
        if case .rejected(let reason) = compliance.validate(features) {
            XCTAssertTrue(reason.contains("DTE"))
        } else {
            XCTFail("Expected rejection")
        }
    }

    func testDTEAtBoundariesPasses() {
        let low = makeFeatures(oi: 2000, volume: 500, spread: 0.05, dte: 7)
        let high = makeFeatures(oi: 2000, volume: 500, spread: 0.05, dte: 60)
        XCTAssertEqual(compliance.validate(low), .passed)
        XCTAssertEqual(compliance.validate(high), .passed)
    }

    // MARK: - Pump detection

    func testPumpPatternRejects() {
        let features = makeFeatures(oi: 2000, volume: 500, spread: 0.05, sentiment: 0.95, mentionVol: 0.96)
        if case .rejected(let reason) = compliance.validate(features) {
            XCTAssertTrue(reason.lowercased().contains("pump"))
        } else {
            XCTFail("Expected pump rejection")
        }
    }

    func testHighSentimentAloneDoesNotTriggerPump() {
        // Sentiment high but mention volume low — not a pump
        let features = makeFeatures(oi: 2000, volume: 500, spread: 0.05, sentiment: 0.92, mentionVol: 0.5)
        XCTAssertEqual(compliance.validate(features), .passed)
    }

    func testHighMentionVolumeAloneDoesNotTriggerPump() {
        let features = makeFeatures(oi: 2000, volume: 500, spread: 0.05, sentiment: 0.5, mentionVol: 0.97)
        XCTAssertEqual(compliance.validate(features), .passed)
    }

    // MARK: - Filter list

    func testFilterRemovesInvalidCandidates() {
        let good = makeFeatures(oi: 2000, volume: 500, spread: 0.05)
        let bad = makeFeatures(oi: 100, volume: 500, spread: 0.05)
        let result = compliance.filter([good, bad])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.openInterest, 2000)
    }

    // MARK: - Helpers

    private func makeFeatures(
        oi: Double, volume: Double, spread: Double,
        ivRank: Double = 0.5, dte: Double = 30,
        sentiment: Double = 0.3, mentionVol: Double = 0.4
    ) -> CandidateFeatures {
        CandidateFeatures(
            ticker: "TEST",
            sentimentScore: sentiment,
            sentimentMomentum: 0,
            mentionVolume: mentionVol,
            unusualFlowScore: 0.5,
            callPutRatio: 0.6,
            openInterestRank: 0.5,
            priceVsMA20: 0.01,
            priceVsMA50: 0.005,
            rsiValue: 55,
            bollingerPosition: 0.5,
            impliedVolatilityRank: ivRank,
            daysToExpiration: dte,
            bidAskSpreadPct: spread,
            openInterest: oi,
            optionVolume: volume
        )
    }
}
