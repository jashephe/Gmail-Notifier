import Cocoa
import Result
import SwiftyJSON

class Message: CustomStringConvertible, Hashable, Comparable {

    // MARK: Properties

    var associatedEmail: String
    var messageID: String
    var threadID: String
    var subject: String
    var sender: String
    var dateReceived: Date
    var snippet: String
    var webURL: URL {
        return GmailParameters.constructWebURL(emailAddress: self.associatedEmail, withFragment: "inbox/\(self.messageID)") as URL
    }

    // MARK: - Lifecycle

    init(associatedEmail theAssociatedEmail: String, messageID theMessageID: String, threadID theThreadID: String, subject theSubject: String, sender theSender: String, dateReceived theDateReceived: Date, snippet theSnippet: String) {
        self.associatedEmail = theAssociatedEmail
        self.messageID = theMessageID
        self.threadID = theThreadID
        self.subject = theSubject
        self.sender = theSender
        self.dateReceived = theDateReceived
        self.snippet = theSnippet
    }

    // FIXME:  Switch this to an init method.
    class func createFromJSONData(_ jsonData: Data, associatedEmail: String) -> Result<Message, GmailNotifierError> {
        let object = JSON(data: jsonData)
        if let error_string = object["error"].string, let error_description = object["error_description"].string {
            return .failure(.apiError(error_string, error_description))
        } else if let messageID = object["id"].string, let threadID = object["threadId"].string, let headers = object["payload"]["headers"].array, let dateReceivedMs = object["internalDate"].string, let snippet = object["snippet"].string {
            var subject: String? = nil
            var sender: String? = nil
            for header in headers {
                if header["name"].stringValue == "Subject" {
                    subject = header["value"].stringValue
                }
                if header["name"].stringValue == "From" {
                    sender = header["value"].stringValue
                }
            }
            if let subject = subject, let sender = sender, let dateReceivedMs = Double(dateReceivedMs) {
                return .success(Message(associatedEmail: associatedEmail, messageID: messageID, threadID: threadID, subject: subject, sender: sender, dateReceived: Date(timeIntervalSince1970: (dateReceivedMs/1000.0)), snippet: CFXMLCreateStringByUnescapingEntities(nil, snippet, nil) as String))
            }
        }
        return .failure(.malformedResponse("Failure occurred during message parsing."))
    }

    // MARK: - Protocol Implementations

    var description: String {
        return "Message (\(messageID)), in thread=[\(threadID)], in account=\(associatedEmail): {\n\tsubject: \"\(subject)\"\n\tsender: \"\(sender)\"\n\tdateReceived: \(dateReceived)\n\tsnippet: \"\(snippet)\"\n} <\(webURL)>"
    }

    var hashValue: Int {
        return self.messageID.hashValue
    }
}

func <(left: Message, right: Message) -> Bool {
    return left.messageID < right.messageID
}

func ==(left: Message, right: Message) -> Bool {
    return left.messageID == right.messageID
}
