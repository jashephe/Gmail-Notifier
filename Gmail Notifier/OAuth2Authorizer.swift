import Foundation
import ReactiveCocoa
import Result
import SwiftyJSON

internal class OAuth2Authorizer {

    // MARK: Attributes

    /// The OAuth2 refresh token; can be used to recreate the access token from
    /// scratch (along with the entire `Account`).
    fileprivate(set) var refreshToken: String

    /// The OAuth2 access token, used to authorize API requests; short lived and
    /// must be periodically reset with the refresh token.
    fileprivate(set) var accessToken: String {
        didSet {
            self._authorizedSession = nil
        }
    }

    /// The expiration date for the current access token after which the access
    /// token is invalid.
    fileprivate(set) var accessTokenExpirationDate: Date {
        didSet {
            scheduleAccessTokenRefresh()
        }
    }

    // MARK: - Lifecycle

    init(refreshToken: String, accessToken: String, accessTokenExpirationDate: Date) {
        self.refreshToken = refreshToken
        self.accessToken = accessToken
        self.accessTokenExpirationDate = accessTokenExpirationDate

        scheduleAccessTokenRefresh()
    }


    /// Creates an `OAuth2Authorizer` from the given authorization code.
    /// - important: The authorizer will be created dependent on the OAuth2
    /// parameters defined in `GoogleParameters`.
    /// - returns: A `SignalProducer` which, upon `start`ing, yields a single
    /// fully-formed `OAuth2Authorizer`, with tokens generated from the given
    /// authorization code.
    class func createFromAuthorizationCode(_ authorizationCode: String) -> SignalProducer<OAuth2Authorizer, GmailNotifierError> {
        let request = NSMutableURLRequest(url: URL(string: GoogleParameters.Token.tokenExchangeEndpoint)!)
        request.httpMethod = "POST"
        request.httpBody = encodeParametersForPOST([
            "code": authorizationCode,
            "client_id": GoogleParameters.Credentials.clientID,
            "client_secret": GoogleParameters.Credentials.secret,
            "redirect_uri": GoogleParameters.Authentication.redirectURI,
            "grant_type": "authorization_code"
            ])
        return URLSession.shared.rac_dataWithRequest(request)
            .startOn(QueueScheduler(qos: DispatchQoS.QoSClass.default, name: (NSRunningApplication.current().localizedName! + ".newAccount")))
            .mapError({ (error) -> GmailNotifierError in
                .connectionError(error)
            }).attemptMap({ (data, response) -> Result<OAuth2Authorizer, GmailNotifierError> in
                let object = JSON(data: data)
                if let error_string = object["error"].string, let error_description = object["error_description"].string {
                    return .failure(.apiError(error_string, error_description))
                } else if let refresh_token = object["refresh_token"].string, let access_token = object["access_token"].string, let expires_in = object["expires_in"].double {
                    return .success(OAuth2Authorizer(refreshToken: refresh_token, accessToken: access_token, accessTokenExpirationDate: Date(timeIntervalSinceNow: expires_in)))
                }
                return .failure(.malformedResponse(nil))
            })
    }

    /// Creates an `OAuth2Authorizer` from the given refresh token.
    /// - important: The authorizer will be created dependent on the OAuth2
    /// parameters defined in `GoogleParameters`.
    /// - returns: A `SignalProducer` which, upon `start`ing, yields a single
    /// fully-formed `OAuth2Authorizer`, with access token generated from the
    /// given refresh token, and then completes.
    class func createFromRefreshToken(_ refreshToken: String) -> SignalProducer<OAuth2Authorizer, GmailNotifierError> {
        return generateAccessTokenFromRefreshToken(refreshToken).map { (accessToken, expirationDate) -> OAuth2Authorizer in
            OAuth2Authorizer(refreshToken: refreshToken, accessToken: accessToken, accessTokenExpirationDate: expirationDate)
        }
    }

    /// Fetches a new access token from the Google OAuth2 API, using the
    /// provided refresh token.
    /// - important: The authorizer will be created dependent on the OAuth2
    /// parameters defined in `GoogleParameters`.
    /// - returns: A `SignalProducer` that yields a single tuple of the form
    /// (`accessToken`, `expirationDate`) and then completes.
    class func generateAccessTokenFromRefreshToken(_ refreshToken: String) -> SignalProducer<(String, Date), GmailNotifierError> {
        let request = NSMutableURLRequest(url: URL(string: GoogleParameters.Token.tokenExchangeEndpoint)!)
        request.httpMethod = "POST"
        request.httpBody = encodeParametersForPOST([
            "refresh_token": refreshToken,
            "client_id": GoogleParameters.Credentials.clientID,
            "client_secret": GoogleParameters.Credentials.secret,
            "grant_type": "refresh_token"
            ])
        return URLSession.shared.rac_dataWithRequest(request)
            .startOn(QueueScheduler(qos: DispatchQoS.QoSClass.default, name: (NSRunningApplication.current().localizedName! + ".newAccount")))
            .mapError({ (error) -> GmailNotifierError in
                .connectionError(error)
            }).attemptMap({ (data, response) -> Result<(String, Date), GmailNotifierError> in
                let object = JSON(data: data)
                if let error_string = object["error"].string, let error_description = object["error_description"].string {
                    return .failure(.apiError(error_string, error_description))
                } else if let access_token = object["access_token"].string, let expires_in = object["expires_in"].double {
                    return .success((access_token, Date(timeIntervalSinceNow: expires_in)))
                }
                return .failure(.malformedResponse(nil))
            })
    }

    // MARK: - Token Updating

    fileprivate var updateScheduler: QueueScheduler = QueueScheduler(qos: DispatchQoS.QoSClass.background, name: "\(NSRunningApplication.current().localizedName!).refreshCycle")
    fileprivate var currentScheduledUpdate: Disposable?

    /// Schedule a future network request to update the access token, at the
    /// time of the current value of `accessTokenExpirationDate` +
    /// `intervalOffset`.  If an existing update has been scheduled, it will be
    /// canceled.
    fileprivate func scheduleAccessTokenRefresh(intervalOffset: TimeInterval = -30) {
        self.currentScheduledUpdate?.dispose()
        self.currentScheduledUpdate = updateScheduler.scheduleAfter(self.accessTokenExpirationDate.addingTimeInterval(intervalOffset), action: { () -> () in
            OAuth2Authorizer.generateAccessTokenFromRefreshToken(self.refreshToken).start(Observer(
                failed: { (error) -> () in
                    NSLog("Couldn't refresh access token with refresh token [\(self.refreshToken)]: \(error)")
                }, next: { (newAccessToken, newAccessTokenExpirationDate) -> () in
                    self.accessToken = newAccessToken
                    self.accessTokenExpirationDate = newAccessTokenExpirationDate
            }))
        })
    }

    /// - returns: A `SignalProducer` that yields a `Bool` signalling whether or
    /// not `accessToken` is valid and able to authorize requests.
    class func validatorForAccessToken(_ accessToken: String) -> SignalProducer<Bool, GmailNotifierError> {
        let requestURL = URLComponents(string: GoogleParameters.Token.tokenValidateEndpoint)!
        requestURL.queryItems = [
            URLQueryItem(name: "access_token", value: accessToken),
        ];
        let request = URLRequest(url: requestURL.url!)
        return URLSession.shared.rac_dataWithRequest(request)
            .startOn(QueueScheduler(qos: DispatchQoS.QoSClass.default, name: "\(NSRunningApplication.current().localizedName!).tokenValidator"))
            .mapError({ (error) -> GmailNotifierError in
                .connectionError(error)
            }).map({ (data, _) -> Bool in
                let object = JSON(data: data)
                if let audience = object["aud"].string , audience == GoogleParameters.Credentials.clientID {
                    return true
                }
                return false
            })
    }

    // MARK: - HTTP

    // FIXME:  Does the session need to be recreated upon access token update?
    //         Couldn't we just change `HTTPAdditionalHeaders`?
    fileprivate var _authorizedSession: URLSession?
    /// An `NSURLSession` pre-authorized with `accessToken`, ready for API
    /// requests.
    var authorizedSession: URLSession {
        get {
            if self._authorizedSession != nil {
                return self._authorizedSession!
            } else {
                let configuration = URLSessionConfiguration.default
                configuration.httpAdditionalHeaders = [
                    "Authorization": "Bearer \(self.accessToken)"
                ]
                self._authorizedSession = URLSession(configuration: configuration)
                return self._authorizedSession!
            }
        }
    }
}
