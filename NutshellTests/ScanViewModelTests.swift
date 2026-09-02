import Testing
import Foundation
@testable import Nutshell

/// A service whose barcode lookups are scripted and counted.
final class ScanStubService: FoodFactsService, @unchecked Sendable {
    private let lock = NSLock()
    private let response: Result<Product?, Error>
    private(set) var lookedUp: [String] = []

    init(_ response: Result<Product?, Error>) { self.response = response }

    var lookupCount: Int {
        lock.lock(); defer { lock.unlock() }
        return lookedUp.count
    }

    func search(_ query: ProductQuery, page: Int) async throws -> SearchPage { .empty }

    func product(barcode: String) async throws -> Product? {
        lock.lock(); lookedUp.append(barcode); lock.unlock()
        return try response.get()
    }
}

@MainActor
@Suite("Scan view model")
struct ScanViewModelTests {

    private func makeProduct() throws -> Product {
        try JSONDecoder().decode(
            Product.self, from: Data(#"{"code":"3017620422003","product_name":"Nutella"}"#.utf8)
        )
    }

    @Test("A found product ends the scan")
    func foundProduct() async throws {
        let product = try makeProduct()
        let viewModel = ScanViewModel(service: ScanStubService(.success(product)))

        await viewModel.lookUp("3017620422003")

        #expect(viewModel.phase == .found(product))
        #expect(viewModel.isBusy == false)
    }

    @Test("A barcode absent from the database is an answer, not an error")
    func notFound() async {
        let viewModel = ScanViewModel(service: ScanStubService(.success(nil)))

        await viewModel.lookUp("0000000000000")

        #expect(viewModel.phase == .notFound(barcode: "0000000000000"))
    }

    @Test("A lookup failure reports the API's own explanation")
    func failure() async {
        let viewModel = ScanViewModel(service: ScanStubService(.failure(APIError.serviceUnavailable)))

        await viewModel.lookUp("3017620422003")

        guard case .failed(let message, _) = viewModel.phase else {
            Issue.record("expected a failure, got \(viewModel.phase)")
            return
        }
        #expect(message == APIError.serviceUnavailable.errorDescription)
    }

    /// Regression: the photo path used to set the busy state and then call the public
    /// `lookUp`, whose own busy guard refused to run — leaving the UI on "Looking it
    /// up…" forever.
    @Test("Manual entry still runs while the view model reports itself busy-capable")
    func manualEntryIsNotBlockedByItsOwnBusyState() async throws {
        let service = ScanStubService(.success(try makeProduct()))
        let viewModel = ScanViewModel(service: service)
        viewModel.manualEntry = "3017620422003"

        await viewModel.submitManualEntry()

        #expect(service.lookupCount == 1)
        #expect(viewModel.isBusy == false)
        guard case .found = viewModel.phase else {
            Issue.record("manual entry did not complete: \(viewModel.phase)")
            return
        }
    }

    @Test("Non-digits are stripped before the barcode is sent")
    func stripsNonDigits() async throws {
        let service = ScanStubService(.success(try makeProduct()))
        let viewModel = ScanViewModel(service: service)

        await viewModel.lookUp(" 3017-6204 22003 ")

        #expect(service.lookedUp == ["3017620422003"])
    }

    @Test("A barcode with no digits at all is ignored rather than queried")
    func ignoresEmptyBarcode() async {
        let service = ScanStubService(.success(nil))
        let viewModel = ScanViewModel(service: service)

        await viewModel.lookUp("----")

        #expect(service.lookupCount == 0)
        #expect(viewModel.phase == .ready)
    }

    @Test("Manual entry is validated as a plausible barcode length")
    func manualEntryValidation() {
        let viewModel = ScanViewModel(service: ScanStubService(.success(nil)))

        viewModel.manualEntry = "123"
        #expect(viewModel.manualEntryIsValid == false)

        viewModel.manualEntry = "3017620422003"
        #expect(viewModel.manualEntryIsValid)

        viewModel.manualEntry = "123456789012345678"
        #expect(viewModel.manualEntryIsValid == false)
    }

    @Test("Resetting clears both the result and the typed entry")
    func reset() async throws {
        let viewModel = ScanViewModel(service: ScanStubService(.success(try makeProduct())))
        viewModel.manualEntry = "3017620422003"
        await viewModel.submitManualEntry()

        viewModel.reset()

        #expect(viewModel.phase == .ready)
        #expect(viewModel.manualEntry.isEmpty)
    }
}
