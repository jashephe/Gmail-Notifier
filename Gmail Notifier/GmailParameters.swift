import Foundation

struct GmailParameters {
    static let apiEndpoint = "https://www.googleapis.com/gmail/v1/users"
    static let webEndpoint = "https://mail.google.com/mail/"

    struct Endpoints {
        static let profile = "profile"
        static let messages = "messages"
        static let threads = "threads"
    }

    static func constructAPIURL(_ endpoint: [String], queryItems: [URLQueryItem]? = nil, userID: String = GoogleParameters.Authentication.userID) -> URL? {
        var pathString = ""
        for endpointComponent in endpoint {
            pathString += "/" + endpointComponent
        }
        var urlBuilder = URLComponents(string: "\(GmailParameters.apiEndpoint)/\(userID)\(pathString)")
        urlBuilder?.queryItems = queryItems
        return urlBuilder?.url
    }

    static func constructWebURL(emailAddress theEmailAddress: String, withFragment fragment: String?) -> URL {
        var urlBuilder = URLComponents(string: GmailParameters.webEndpoint)!
        urlBuilder.queryItems = [
            URLQueryItem(name: "authuser", value: theEmailAddress)
        ]
        urlBuilder.fragment = fragment
        return urlBuilder.url!
    }
}
