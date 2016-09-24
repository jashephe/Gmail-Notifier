import Cocoa
import ReactiveCocoa
import Result
import SwiftyJSON
import Reachability

/// Allows for storage and access to multiple `Account` objects, and manages
/// their persistent storage.
class AccountManager {

    fileprivate var messageCheckInterval: TimeInterval = 20 {
        didSet {
            self.currentMessageUpdater?.dispose()
            self.currentMessageUpdater = startMessageUpdater()
        }
    }
    fileprivate var messageCheckLeeway: TimeInterval = 5

    fileprivate var _accounts: MutableProperty<[Account]> = MutableProperty([])
    var accounts: AnyProperty<[Account]> {
        return AnyProperty(self._accounts)
    }

    fileprivate var _lastUpdate: MutableProperty<Date> = MutableProperty(Date.distantPast)
    var lastUpdate: AnyProperty<Date> {
        return AnyProperty(self._lastUpdate)
    }

    fileprivate var currentMessageUpdater: Disposable?
    fileprivate func startMessageUpdater() -> Disposable? {
        let scheduler = QueueScheduler(qos: DispatchQoS.QoSClass.background, name: "\(NSRunningApplication.current().localizedName!).sharedMessageFetch")
        return scheduler.scheduleAfter(Date(), repeatingEvery: self.messageCheckInterval, withLeeway: self.messageCheckLeeway, action: { () -> () in
            if self.accounts.value.count > 0 && self.isNetworkReachable.value {
                for account in self.accounts.value {
                    account.messageUpdater.start()
                }
                self._lastUpdate.value = Date()
            }
        })
    }

    fileprivate var reachabilityChecker: Reachability?
    fileprivate var _isNetworkReachable: MutableProperty<Bool>
    var isNetworkReachable: AnyProperty<Bool> {
        return AnyProperty(self._isNetworkReachable)
    }


    init() {
        do {
            self.reachabilityChecker = try Reachability.reachabilityForInternetConnection()
            self._isNetworkReachable = MutableProperty(self.reachabilityChecker!.isReachable())
        } catch {
            NSLog("Unable to monitor internet status; assuming internet is reachable.")
            self._isNetworkReachable = MutableProperty(true)
        }

        self.reachabilityChecker?.whenReachable = { reachability in
            self._isNetworkReachable.value = true
        }
        self.reachabilityChecker?.whenUnreachable = { reachability in
            self._isNetworkReachable.value = false
        }

        do {
            try self.reachabilityChecker?.startNotifier()
        } catch {
            NSLog("Unable to start internet status monitor; assuming internet is reachable.")
            self.reachabilityChecker = nil
            self._isNetworkReachable.value = true
        }

        self.loadStoredAccounts()

        self.currentMessageUpdater = startMessageUpdater()
    }

    deinit {
        self.reachabilityChecker?.stopNotifier()
    }

    fileprivate func loadStoredAccounts() {
        var queryAttributes = KeychainAttributes()
        queryAttributes.kind = "OAuth2 Token"
        queryAttributes.where_ = NSRunningApplication.current().localizedName!

        let defaults = UserDefaults(suiteName: XPCParameters.APPLICATION_GROUP_IDENTIFIER)!
        if let accountStore = defaults.object(forKey: Defaults.kACCOUNTS_STORE) as? NSDictionary {
            let newAccountStore = accountStore.mutableCopy() as! NSMutableDictionary

            for (account, _) in newAccountStore {
                queryAttributes.account = account as? String

                switch Keychain.get(attributes: queryAttributes) {
                case let .success(data):
                    if let token = String(data: data, encoding: String.Encoding.utf8) {
                        OAuth2Authorizer.createFromRefreshToken(token).flatMap(.latest, transform: { (authorizer) -> SignalProducer<(OAuth2Authorizer, (String, String, NSImage?)), GmailNotifierError> in
                            combineLatest(SignalProducer(value: authorizer), Account.fetchAccountPropertiesWithAuthorizer(authorizer))
                        }).map({ (authorizer, accountProperties) -> Account in
                            let (emailAddress, userName, profilePicture) = accountProperties
                            return Account(authorizer: authorizer, emailAddress: emailAddress, userName: userName, profilePicture: profilePicture)
                        }).attemptMap({ (account) -> Result<Account, GmailNotifierError> in
                            if self.accounts.value.contains(account) {
                                self.revokeToken(account.authorizer.refreshToken).start()
                                return .failure(.invalidOperation("The account '\(account.emailAddress)' already exists."))
                            } else {
                                return .success(account)
                            }
                        }).startWithNext({ (account) in
                            account.messageUpdater.start()
                            self._accounts.value.append(account)
                        })
                    }
                case let .failure(error):
                    let alert = error.constructAlert("Could not load authorization token for \"\(account)\"", informativeTextFormat: "%@. The stored account data will be removed.")
                    NSApp.activate(ignoringOtherApps: true)
                    alert.runModal()
                }
            }
        }
    }

    /// - returns: A `SignalProducer` for adding an account created from the
    /// given authorization code to the `AccountManager`.
    func addAccountWithCode(_ authorizationCode: String) -> SignalProducer<Account, GmailNotifierError> {
        return OAuth2Authorizer.createFromAuthorizationCode(authorizationCode).flatMap(.latest, transform: { (authorizer) -> SignalProducer<(OAuth2Authorizer, (String, String, NSImage?)), GmailNotifierError> in
            combineLatest(SignalProducer(value: authorizer), Account.fetchAccountPropertiesWithAuthorizer(authorizer))
        }).map({ (authorizer, accountProperties) -> Account in
            let (emailAddress, userName, profilePicture) = accountProperties
            return Account(authorizer: authorizer, emailAddress: emailAddress, userName: userName, profilePicture: profilePicture)
        }).attemptMap({ (account) -> Result<Account, GmailNotifierError> in
            if self.accounts.value.contains(account) {
                self.revokeToken(account.authorizer.refreshToken).start()
                return .failure(.invalidOperation("The account '\(account.emailAddress)' already exists."))
            } else {
                return .success(account)
            }
        }).on(
            next: { (account) -> () in
                account.messageUpdater.start()
                self._accounts.value.append(account)
                var queryAttributes = KeychainAttributes()
                queryAttributes.name = "\(NSRunningApplication.current().localizedName!) (\(account.emailAddress))"
                queryAttributes.where_ = NSRunningApplication.current().localizedName!
                queryAttributes.account = account.emailAddress
                queryAttributes.kind = "OAuth2 Token"
                Keychain.save(attributes: queryAttributes, data: account.authorizer.refreshToken.data(using: String.Encoding.utf8, allowLossyConversion: false)!)

                //FIXME: Consider whether it is appropriate for defaults to be set here (rather than in deinit or somewhere else)
                let defaults = UserDefaults(suiteName: XPCParameters.APPLICATION_GROUP_IDENTIFIER)!
                if let accountStore = defaults.object(forKey: Defaults.kACCOUNTS_STORE) as? NSDictionary {
                    let newAccountStore = accountStore.mutableCopy() as! NSMutableDictionary

                    var accountAttributes = [String:AnyObject]()
                    accountAttributes[Defaults.Account.kFILTER_QUERY] = account.filterQuery
                    accountAttributes[Defaults.Account.kSHOW_SNIPPETS] = account.shouldParseSnippets
                    accountAttributes[Defaults.Account.kALLOW_QUICKLOOK] = account.shouldParseRawDataForQuicklook

                    newAccountStore.setObject(accountAttributes, forKey: account.emailAddress)
                    defaults.set(newAccountStore, forKey: Defaults.kACCOUNTS_STORE)
                }
        })
    }

    /// Remove the account with the corresponding email address, delete the
    /// corresponding keychain entry, and start a request to revoke the OAuth2
    /// tokens.
    ///
    /// - returns: The `Account` that was removed.
    func removeAccountAtIndex(_ index: Int) -> SignalProducer<(), GmailNotifierError> {
        let account = self._accounts.value.remove(at: index)
        var queryAttributes = KeychainAttributes()
        queryAttributes.where_ = NSRunningApplication.current().localizedName!
        queryAttributes.kind = "OAuth2 Token"
        queryAttributes.account = account.emailAddress
        Keychain.delete(attributes: queryAttributes)
        return revokeToken(account.authorizer.refreshToken)
    }

    /// Create a network request to revoke the given OAuth2 token.
    /// - parameter token:  An OAuth2 refresh token **or** access token.
    fileprivate func revokeToken(_ token: String) -> SignalProducer<(), GmailNotifierError> {
        let request = URLRequest(url: GoogleParameters.Authentication.constructRevocationURLForToken(token))
        return URLSession.shared.rac_dataWithRequest(request)
            .startOn(QueueScheduler(qos: DispatchQoS.QoSClass.default, name: "\(NSRunningApplication.current().localizedName!).tokenRevocation"))
            .mapError({ (error) -> GmailNotifierError in
                .connectionError(error)
            }).attemptMap({ (data, response) -> Result<(), GmailNotifierError> in
                if let response = response as? HTTPURLResponse {
                    if response.statusCode >= 200 && response.statusCode < 300 {
                        return .success(())
                    } else {
                        let object = JSON(data: data)
                        if let error_string = object["error"].string, let error_description = object["error_description"].string {
                            return .failure(.apiError(error_string, error_description))
                        }
                    }
                }
                return .failure(.malformedResponse(nil))
            })
    }
}
