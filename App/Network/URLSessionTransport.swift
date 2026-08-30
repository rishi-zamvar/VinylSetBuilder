import Foundation
import VinylSetBuilderCore

/// The only networking code in this project.
///
/// Everything that DECIDES anything — the ladder, the ranking, the retry policy, the rate
/// limit, every JSON parse — is in `VinylSetBuilderCore` behind `HTTPFetching`, where there is
/// a test target. This file opens the socket and nothing else, and it is deliberately short
/// enough to read in one go.
struct URLSessionTransport: HTTPFetching {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw HTTPError.malformedResponse }
        var headers: [String: String] = [:]
        for (name, value) in http.allHeaderFields {
            if let name = name as? String, let value = value as? String { headers[name] = value }
        }
        return HTTPResponse(status: http.statusCode, body: data, headers: headers)
    }
}
