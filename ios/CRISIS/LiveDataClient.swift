import Foundation

/// An opt-in fetch from the operator's HTTPS adapter. No provider keys live in the app.
final class LiveDataClient: NSObject, URLSessionDataDelegate {
 private let limit = 3 * 1024 * 1024
 private var bytes = Data()
 private var continuation: CheckedContinuation<Data, Error>?
 private var session: URLSession?
 private var completed = false

 static func fetch(_ address: String) async throws -> Data {
  guard address.count <= 2048, let components = URLComponents(string: address),
        components.scheme?.lowercased() == "https", components.host != nil,
        components.user == nil, components.password == nil, let url = components.url else {
   throw CrisisError(message: "Eine vollständige HTTPS-Adresse ohne eingebettete Zugangsdaten eingeben.")
  }
  let client = LiveDataClient()
  return try await withCheckedThrowingContinuation { continuation in
   client.continuation = continuation
   let config = URLSessionConfiguration.ephemeral
   config.timeoutIntervalForRequest = 20
   config.timeoutIntervalForResource = 30
   config.httpShouldSetCookies = false
   let session = URLSession(configuration: config, delegate: client, delegateQueue: nil)
   client.session = session
   var request = URLRequest(url: url)
   request.setValue("application/json", forHTTPHeaderField: "Accept")
   session.dataTask(with: request).resume()
  }
 }

 private func finish(_ result: Result<Data, Error>) {
  guard !completed else { return }
  completed = true
  continuation?.resume(with: result)
  continuation = nil
  session?.invalidateAndCancel()
  session = nil
 }

 func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
  guard let response = response as? HTTPURLResponse, response.statusCode == 200,
        response.url?.scheme?.lowercased() == "https" else {
   completionHandler(.cancel)
   finish(.failure(CrisisError(message: "Der Datenserver hat keine erfolgreiche HTTPS-Antwort geliefert.")))
   return
  }
  guard response.expectedContentLength <= Int64(limit) else {
   completionHandler(.cancel)
   finish(.failure(CrisisError(message: "Die Serverantwort ist größer als 3 MB.")))
   return
  }
  completionHandler(.allow)
 }

 func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
  guard bytes.count + data.count <= limit else {
   finish(.failure(CrisisError(message: "Die Serverantwort ist größer als 3 MB.")))
   return
  }
  bytes.append(data)
 }

 func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
  if let error = error { finish(.failure(error)) } else { finish(.success(bytes)) }
 }

 func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
  // The user-selected adapter is the destination; redirects must be reviewed explicitly.
  completionHandler(nil)
 }
}
