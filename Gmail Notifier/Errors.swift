import Cocoa

enum GmailNotifierError: Error, CustomStringConvertible {
    case malformedRequest(String?)
    case malformedResponse(String?)
    case connectionError(NSError)
    case apiError(String, String)
    case invalidOperation(String)

    var description: String {
        switch self {
        case let .malformedRequest(message):
            var description = "Unexpected data was sent to the server"
            if let message = message {
                description += "(\"\(message)\")"
            }
            return description
        case let .malformedResponse(message):
            var description = "Unexpected data was received from the server"
            if let message = message {
                description += "(\"\(message)\")"
            }
            return description
        case let .connectionError(systemError):
            return "An error occurred while connecting to the desired resource (\"\(systemError.localizedDescription)\")"
        case let .apiError(error_code, description):
            return "Gmail reported an error for the attempted action (\"\(description)\", Code: \(error_code))"
        case let .invalidOperation(description):
            return "\(description)"
        }
    }
}

extension Error where Self: CustomStringConvertible {
    func constructAlert(_ title: String, informativeTextFormat: String = "%@", type: NSAlertStyle = .warning) -> NSAlert {
        let errorAlert: NSAlert = NSAlert()
        errorAlert.alertStyle = type
        errorAlert.messageText = title
        errorAlert.informativeText = String(format: informativeTextFormat, self.description)
        errorAlert.addButton(withTitle: "OK")
        return errorAlert
    }
}

