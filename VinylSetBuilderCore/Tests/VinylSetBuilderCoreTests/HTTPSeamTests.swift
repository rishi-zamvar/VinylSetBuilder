import Foundation
import Testing
@testable import VinylSetBuilderCore

/// The fake transport every network test in this package runs against. It counts, so RES-06
/// can be PROVEN rather than asserted: "the cache works" is a claim, "the second pass issued
/// zero requests" is a measurement.
actor RecordingTransport: HTTPFetching {
    private(set) var sent: [HTTPRequest] = []
    private var responses: [(HTTPRequest) -> HTTPResponse?]

    init(_ responses: [(HTTPRequest) -> HTTPResponse?] = []) {
        self.responses = responses
    }

    var count: Int { sent.count }
    var urls: [String] { sent.map(\.url.absoluteString) }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        sent.append(request)
        for responder in responses {
            if let response = responder(request) { return response }
        }
        return HTTPResponse(status: 404, body: Data())
    }
}

func json(_ object: Any, status: Int = 200, headers: [String: String] = [:]) -> HTTPResponse {
    HTTPResponse(status: status,
                 body: try! JSONSerialization.data(withJSONObject: object),
                 headers: headers)
}

@Test("the transport seam carries a method, headers and a body without naming a networking type")
func test_givenRequest_whenBuilt_thenCarriesMethodHeadersAndBody() {
    let request = HTTPRequest(url: URL(string: "https://example.test/x")!,
                              method: .post,
                              headers: ["A": "B"],
                              body: Data("hi".utf8))
    #expect(request.method == .post)
    #expect(request.headers["A"] == "B")
    #expect(request.body == Data("hi".utf8))
}

@Test("a fake transport records every request it is given")
func test_givenFakeTransport_whenSent_thenRecorded() async throws {
    let transport = RecordingTransport([{ _ in json(["ok": true]) }])
    _ = try await transport.send(HTTPRequest(url: URL(string: "https://example.test/1")!))
    _ = try await transport.send(HTTPRequest(url: URL(string: "https://example.test/2")!))
    #expect(await transport.count == 2)
}
