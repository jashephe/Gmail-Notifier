import Cocoa
import ReactiveCocoa
import Result
import SwiftyJSON

/// Represents an email account with attributes and corresponding OAuth2
/// authorizer.
internal class Account: Equatable, Comparable, CustomStringConvertible {

    // MARK: Attributes
    fileprivate(set) var emailAddress: String
    fileprivate(set) var userName: String
    fileprivate(set) var profilePicture: NSImage

    // MARK: Authentication
    fileprivate(set) var authorizer: OAuth2Authorizer

    // MARK: Behavior
    var filterQuery: String = "in:INBOX is:unread"
    var shouldParseSnippets: Bool = true
    var shouldParseRawDataForQuicklook: Bool = true
    var maxMessagesToDownload: Int = 5

    // MARK: Messages

    fileprivate var _messages: MutableProperty<Set<Message>> = MutableProperty([])
    var messages: Set<Message> {
        return self._messages.value
    }

    // MARK: - Lifecycle
    init(authorizer: OAuth2Authorizer, emailAddress: String, userName: String, profilePicture: NSImage? = nil) {
        self.authorizer = authorizer
        self.emailAddress = emailAddress
        self.userName = userName
        self.profilePicture = profilePicture ?? NSImage(named: NSImageNameUser)!
    }

    deinit {
        self._messageDeltasObserver.sendCompleted()
    }

    /// - returns: A `SignalProducer` that, upon `start`ing, yields a single
    /// triple containing the email address, username, and profile picture, in
    /// that order, for the account authorized by `authorizer`.
    class func fetchAccountPropertiesWithAuthorizer(_ authorizer: OAuth2Authorizer) -> SignalProducer<(String, String, NSImage?), GmailNotifierError> {
        let profileRequest = URLRequest(url: GmailParameters.constructAPIURL([GmailParameters.Endpoints.profile])!)
        let profileSignal = authorizer.authorizedSession.rac_dataWithRequest(profileRequest)
            .startOn(QueueScheduler(qos: DispatchQoS.QoSClass.default, name: "\(NSRunningApplication.current().localizedName!).profileRequest"))
            .mapError({ (error) -> GmailNotifierError in
                .connectionError(error)
            })
            .attemptMap({ (data, response) -> Result<String, GmailNotifierError> in
                let object = JSON(data: data)
                if let error_string = object["error"].string, let error_description = object["error_description"].string {
                    return .failure(.apiError(error_string, error_description))
                } else if let emailAddress = object["emailAddress"].string {
                    return .success(emailAddress)
                }
                return .failure(.malformedResponse(nil))
            })

        let accountRequest = URLRequest(url: ProfileParameters.constructURL() as URL)
        let accountSignal = authorizer.authorizedSession.rac_dataWithRequest(accountRequest)
            .startOn(QueueScheduler(qos: DispatchQoS.QoSClass.default, name: "\(NSRunningApplication.current().localizedName!).accountRequest"))
            .mapError({ (error) -> GmailNotifierError in
                .connectionError(error)
            })
            .attemptMap({ (data, response) -> Result<(String, NSImage?), GmailNotifierError> in
                let object = JSON(data: data)
                if let error_string = object["error"].string, let error_description = object["error_description"].string {
                    return .failure(.apiError(error_string, error_description))
                } else if let name = object["displayName"].string, let image_url_string = object["image"]["url"].string {
                    if let image_url = URL(string: image_url_string) {
                        return .success((name, NSImage(contentsOf: image_url)))
                    }
                }
                return .failure(.malformedResponse(nil))
            })

        return combineLatest(profileSignal, accountSignal).map({ (emailAddress, profileTuple) -> (String, String, NSImage?) in
            let (userName, profilePicture) = profileTuple
            return (emailAddress, userName, profilePicture)
        })
    }

    fileprivate var (_messageDeltas, _messageDeltasObserver) = Signal<(Set<Message>, Set<Message>), NoError>.pipe()
    var messageDeltas: Signal<(Set<Message>, Set<Message>), NoError> {
        return self._messageDeltas
    }

    // MARK: - Message Fetching

    // FIXME:  If we're going to calculate some sort of diff, we can't operate on a stream; we'll have to collect the messages.
    // FIXME:  Look into batching message requests:  https://developers.google.com/gmail/api/guides/batch
    lazy var messageUpdater: SignalProducer<[Message], NoError> = { [weak self] in
        guard let realSelf = self else {
            NSLog("INVALID INTERNAL STATE:  `messageUpdater` called with no corresponding `Account`.")
            return SignalProducer.empty
        }
        return realSelf.fetchMessageIDs().flatMap(.merge, transform: { (messageID) -> SignalProducer<Message, GmailNotifierError> in
            return realSelf.fetchMessage(forMessageID: messageID)
        }).flatMapError({ (_) -> SignalProducer<Message, NoError> in
            return SignalProducer.empty
        }).collect().on(next: { (messages) -> () in
            let newMessages = Set(messages)
            var oldMessages = realSelf._messages.value

            let removed = oldMessages.subtracting(newMessages)
            let added = newMessages.subtracting(oldMessages)
            realSelf._messages.swap(newMessages)
            if removed.count > 0 || added.count > 0 {
                realSelf._messageDeltasObserver.sendNext((removed, added))
            }
        })
    }()

    /// - important: Returned messages will be filtered dependent on the
    /// `Account`'s `filterQuery` and `maxMessagesToDownload` properties.
    /// - warning: If `filterQuery` and `maxMessagesToDownload` are changed
    /// subsequently to the time that this method is called, those changes will
    /// not be reflected in the output, even if the signal producer has not yet
    /// been `start`ed.
    /// - returns: A `SignalProducer` that, upon `start`ing, yields zero or more
    /// Gmail API `Message` ID strings, subject to the parameters discussed
    /// above, suitable for use in subsequent API calls.
    func fetchMessageIDs() -> SignalProducer<String, GmailNotifierError> {
        guard let requestURL = GmailParameters.constructAPIURL([GmailParameters.Endpoints.messages], queryItems: [
            URLQueryItem(name: "q", value: self.filterQuery),
            URLQueryItem(name: "maxResults", value: "\(self.maxMessagesToDownload)")
            ]) else {
                return SignalProducer(error: .malformedRequest("Could not construct the message query URL.  This may be the result of an invalid search query."))
        }
        let messageRequest = URLRequest(url: requestURL)
        return self.authorizer.authorizedSession.rac_dataWithRequest(messageRequest)
            .startOn(QueueScheduler(qos: DispatchQoS.QoSClass.default, name: "\(NSRunningApplication.current().localizedName!).messageIDRequest"))
            .mapError({ (error) -> GmailNotifierError in
                .connectionError(error)
            }).flatMap(.latest, transform: { (data, response) -> SignalProducer<String, GmailNotifierError> in
                let object = JSON(data: data)
                if let error_string = object["error"].string, let error_description = object["error_description"].string {
                    return SignalProducer(error: .apiError(error_string, error_description))
                } else if let messagesList = object["messages"].array {
                    return SignalProducer({ (observer, disposable) -> () in
                        for message in messagesList {
                            if let messageID = message["id"].string {
                                observer.sendNext(messageID)
                            }
                        }
                        observer.sendCompleted()
                    })
                }
                return SignalProducer(error: .malformedResponse(nil))
            })
    }

    /// - parameter messageID: A Gmail API `Message` ID
    /// - returns: A `SignalProducer` that, upon `start`ing, yields
    /// RFC 2822-formatted strings, sutable for saving to a `.eml` file.
    func fetchRawMessage(forMessageID messageID: String) -> SignalProducer<(String, String), GmailNotifierError> {
        guard let requestURL = GmailParameters.constructAPIURL([GmailParameters.Endpoints.messages, "get"], queryItems: [
            URLQueryItem(name: "id", value: messageID),
            URLQueryItem(name: "format", value: "raw")
            ]) else {
                return SignalProducer(error: .malformedRequest("Could not construct the message query URL.  This may be the result of an invalid search query."))
        }
        let messageRequest = URLRequest(url: requestURL)
        return self.authorizer.authorizedSession.rac_dataWithRequest(messageRequest).mapError({ (error) -> GmailNotifierError in
            .connectionError(error)
        }).attemptMap({ (data, response) -> Result<(String, String), GmailNotifierError> in
            let object = JSON(data: data)
            if let error_string = object["error"].string, let error_description = object["error_description"].string {
                return .failure(.apiError(error_string, error_description))
            } else if let rawEncoded = object["raw"].string, let messageID = object["id"].string {
                if let rawData = Data(base64URLEncodedString: rawEncoded, options: []) {
                    if let rawString = String(data: rawData, encoding: String.Encoding.utf8) {
                        return .success(messageID, rawString)
                    }
                }
            }
            return .failure(.malformedResponse("Failure occurred during message parsing."))
        })
    }

    /// - parameter messageID: A Gmail API `Message` ID
    /// - returns: A `SignalProducer` that, upon `start`ing, yields a `Message`
    /// object for the given ID and then completes.
    func fetchMessage(forMessageID messageID: String) -> SignalProducer<Message, GmailNotifierError> {
        guard let requestURL = GmailParameters.constructAPIURL([GmailParameters.Endpoints.messages, "get"], queryItems: [
            URLQueryItem(name: "id", value: messageID),
            URLQueryItem(name: "format", value: "full")
            ]) else {
                return SignalProducer(error: .malformedRequest("Could not construct the message query URL.  This may be the result of an invalid search query."))
        }
        let messageRequest = URLRequest(url: requestURL)
        return self.authorizer.authorizedSession.rac_dataWithRequest(messageRequest).mapError({ (error) -> GmailNotifierError in
            .connectionError(error)
        }).attemptMap({ (data, response) -> Result<Message, GmailNotifierError> in
            return Message.createFromJSONData(data, associatedEmail: self.emailAddress)
        })
    }

    // MARK: - Protocol Implementations

    var description: String {
        get {
            return "Account(\(userName), \(emailAddress))"
        }
    }
}

func ==(left: Account, right: Account) -> Bool {
    return left.emailAddress == right.emailAddress
}

func <(left: Account, right: Account) -> Bool {
    return left.emailAddress < right.emailAddress
}
