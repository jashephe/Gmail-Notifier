import Foundation

struct GoogleParameters {
    struct Authentication {
        static let requestEndpoint = "https://accounts.google.com/o/oauth2/auth"
        static let responseType = "code"
        static let redirectURI = "urn:ietf:wg:oauth:2.0:oob"
        static let scope = "https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/gmail.readonly"
        static func constructAuthenticationURL() -> URL {
            var urlBuilder = URLComponents(string: Authentication.requestEndpoint)!
            urlBuilder.queryItems = [
                URLQueryItem(name: "response_type", value: Authentication.responseType),
                URLQueryItem(name: "client_id", value: Credentials.clientID),
                URLQueryItem(name: "redirect_uri", value: Authentication.redirectURI),
                URLQueryItem(name: "scope", value: Authentication.scope)
            ]
            return urlBuilder.url!
        }

        static let revocationEndpoint = "https://accounts.google.com/o/oauth2/revoke"
        static func constructRevocationURLForToken(_ token: String) -> URL {
            var urlBuilder = URLComponents(string: Authentication.revocationEndpoint)!
            urlBuilder.queryItems = [
                URLQueryItem(name: "token", value: token),
            ]
            return urlBuilder.url!
        }

        static let userID = "me"
    }
    
    struct Token {
        static let tokenExchangeEndpoint = "https://www.googleapis.com/oauth2/v4/token"
        static let tokenValidateEndpoint = "https://www.googleapis.com/oauth2/v3/tokeninfo"
    }
}

struct ProfileParameters {
    static let userinfoEndpoint = "https://www.googleapis.com/plus/v1/people"

    static func constructURL(_ userID: String = GoogleParameters.Authentication.userID) -> URL {
        return URL(string: "\(userinfoEndpoint)/\(userID)")!
    }
}
