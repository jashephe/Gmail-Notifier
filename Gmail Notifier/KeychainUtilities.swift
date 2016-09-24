//  Inspired by https://gist.github.com/jackreichert/414623731241c95f0e20

import Foundation
import Security
import Result

// KEYCHAIN ACCESS NAMES
//       kSecAttrLabel == "Name"
// kSecAttrDescription == "Kind"
//     kSecAttrAccount == "Account"
//     kSecAttrService == "Where"
//     kSecAttrComment == "Comments

enum KeychainTransactionError: Error, CustomStringConvertible {
    case operationUnimplemented
    case invalidParameters
    case memoryAllocationFailed
    case resultsNotAvailable
    case authorizationFailed
    case itemAlreadyExists
    case itemNotFound
    case interactionNotAllowed
    case decodeFailed
    case otherFailure(code: OSStatus)
    case unexpectedData

    init(fromCode code: OSStatus) {
        switch code {
        case errSecUnimplemented:
            self = .operationUnimplemented
        case errSecParam:
            self = .invalidParameters
        case errSecAllocate:
            self = .memoryAllocationFailed
        case errSecNotAvailable:
            self = .resultsNotAvailable
        case errSecAuthFailed:
            self = .authorizationFailed
        case errSecDuplicateItem:
            self = .itemAlreadyExists
        case errSecItemNotFound:
            self = .itemNotFound
        case errSecInteractionNotAllowed:
            self = .interactionNotAllowed
        case errSecDecode:
            self = .decodeFailed
        default:
            self = .otherFailure(code: code)
        }
    }

    var description: String {
        switch self {
        case .operationUnimplemented:
            return "The requsted Keychain operation is not implemented"
        case .invalidParameters:
            return "Invalid parameters were passed to the Security Server"
        case .memoryAllocationFailed:
            return "The Keychain failed to allocate memory for the operation"
        case .resultsNotAvailable:
            return "The results of the Keychain operation are not available"
        case .authorizationFailed:
            return "The authorization required to access the Keychain failed"
        case .itemAlreadyExists:
            return "The requested Keychain item already exists"
        case .itemNotFound:
            return "The requested Keychain item could not be found"
        case .interactionNotAllowed:
            return "The interaction with the Security Server was not allowed"
        case .decodeFailed, .unexpectedData:
            return "The Keychain data could not be decoded"
        case let .otherFailure(code):
            if let description = type(of: self).explainCode(code) {
                return "An unexpected keychain error occured (\"\(description)\")"
            } else {
                return "An unexpected keychain error occured"
            }
        }
    }

    static func explainCode(_ code: OSStatus) -> String? {
        if let message = SecCopyErrorMessageString(code, UnsafeMutablePointer<Int>(nil)) {
            return message as String
        }
        return nil
    }
}

struct KeychainAttributes {
    var name: String?
    var kind: String?
    var account: String?
    var where_: String?
    var comment: String?

    init() {

    }

    init(fromAttributes attributes: [String: AnyObject]) {
        if let name = attributes[kSecAttrLabel as String] {
            self.name = name as? String
        }
        if let kind = attributes[kSecAttrDescription as String] {
            self.kind = kind as? String
        }
        if let account = attributes[kSecAttrAccount as String] {
            self.account = account as? String
        }
        if let where_ = attributes[kSecAttrService as String] {
            self.where_ = where_ as? String
        }
        if let comment = attributes[kSecAttrComment as String] {
            self.comment = comment as? String
        }
    }

    func toAttributeArray() -> [String: AnyObject] {
        var attributes: [String: NSObject] = [:]
        if let label = self.name {
            attributes[kSecAttrLabel as String] = label as NSObject?
        }
        if let description = self.kind {
            attributes[kSecAttrDescription as String] = description as NSObject?
        }
        if let account = self.account {
            attributes[kSecAttrAccount as String] = account as NSObject?
        }
        if let service = self.where_ {
            attributes[kSecAttrService as String] = service as NSObject?
        }
        if let comment = self.comment {
            attributes[kSecAttrComment as String] = comment as NSObject?
        }
        return attributes
    }
}

// Consider whether it is appropriate to pass an array of `KeychainAttributes`.
// i.e. Using an array allows for duplicate entries.

class Keychain {

    /// Store `data` in the Keychain with the given `attributes`.
    ///
    /// - important: This will overwrite any Keychain entry maching the
    ///              provided `attributes`.
    /// - returns: A `Result` encapsulting the stored Keychain item upon 
    ///            success, or an error describing why the transaction failed.
    class func save(attributes theAttributes: KeychainAttributes, data theData: Data) -> Result<Dictionary<String, AnyObject>, KeychainTransactionError> {
        var query: [String: AnyObject] = [
            kSecClass as String       : kSecClassGenericPassword,
            kSecReturnAttributes as String : kCFBooleanTrue,
            kSecValueData as String   : theData ]

        query += theAttributes.toAttributeArray()

        SecItemDelete(query as CFDictionary)

        var responseRef: AnyObject?
        let status = withUnsafeMutablePointer(to: &responseRef) { SecItemAdd(query as CFDictionary, UnsafeMutablePointer($0)) }

        if status == errSecSuccess {
            if let attributes = responseRef as! Dictionary<String, AnyObject>? {
                return .success(attributes)
            } else {
                return .failure(.unexpectedData)
            }
        } else {
            return .failure(KeychainTransactionError(fromCode: status))
        }
    }

    /// Search the Keychain and return all entries matching the given
    /// `attributes`.
    ///
    /// - returns: A `Result` encapsulating, upon success, an `Array` of zero or
    ///            more `Dictionary<String,NSObject>` objects, one for each
    ///            matching entry, or an error describing why the transaction
    ///            failed. The contents of the attributes dictionaries are
    ///            determinted by the Keychain.
    class func query(attributes theAttributes: KeychainAttributes) -> Result<[Dictionary<String, AnyObject>], KeychainTransactionError> {
        var query: [String: AnyObject] = [
            kSecClass as String       : kSecClassGenericPassword,
            kSecReturnAttributes as String : kCFBooleanTrue,
            kSecMatchLimit as String  : kSecMatchLimitAll ]

        query += theAttributes.toAttributeArray()

        var responseRef: AnyObject?
        let status = withUnsafeMutablePointer(to: &responseRef) { SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0)) }

        if status == errSecSuccess {
            if let attributes = responseRef as! [Dictionary<String, AnyObject>]? {
                return .success(attributes)
            } else {
                return .failure(.unexpectedData)
            }
        } else {
            return .failure(KeychainTransactionError(fromCode: status))
        }
    }

    /// Retrieve the data for the Keychain item matching `attributes`. If
    /// multiple Keychain items match the provided attributes, the Keychain will
    /// determine which one will be returned.
    ///
    /// - returns: A result encapsulting, upon success, the requested Keychain
    ///            item's stored data, or an error describing why the
    ///            transaction failed.
    class func get(attributes theAttributes: KeychainAttributes) -> Result<Data, KeychainTransactionError> {
        var query: [String: AnyObject] = [
            kSecClass as String       : kSecClassGenericPassword,
            kSecReturnData as String  : kCFBooleanTrue,
            kSecMatchLimit as String  : kSecMatchLimitOne ]

        query += theAttributes.toAttributeArray()

        var responseRef: AnyObject?
        let status = withUnsafeMutablePointer(to: &responseRef) { SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0)) }

        if status == errSecSuccess {
            if let data = responseRef as! Data? {
                return .success(data)
            } else {
                return .failure(.unexpectedData)
            }
        } else {
            return .failure(KeychainTransactionError(fromCode: status))
        }
    }

    class func delete(attributes theAttributes: KeychainAttributes) -> Result<(), KeychainTransactionError> {
        var query: [String: AnyObject] = [
            kSecClass as String       : kSecClassGenericPassword
        ]

        query += theAttributes.toAttributeArray()

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess {
            return .success(())
        } else {
            return .failure(KeychainTransactionError(fromCode: status))
        }
    }
}

//MARK: - Conveniences

private func += <K, V> (left: inout [K:V], right: [K:V]) {
    for (k, v) in right {
        left.updateValue(v, forKey: k)
    }
}
