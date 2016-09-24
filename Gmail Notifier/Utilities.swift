import Cocoa
import ReactiveCocoa
import Result

struct AppParameters {
    struct Images {
        struct Message {
            struct Solid {
                static let DARK: NSImage = {
                    let image = NSImage(named: "email_dark")!
                    image.isTemplate = true
                    return image
                }()
                static let LIGHT: NSImage = {
                    let image = NSImage(named: "email_light")!
                    image.isTemplate = true
                    return image
                }()
                static let RED: NSImage = {
                    let image = NSImage(named: "email_red")!
                    image.isTemplate = false
                    return image
                }()
            }
            struct Outline {
                static let DARK: NSImage = {
                    let image = NSImage(named: "email_outline_dark")!
                    image.isTemplate = true
                    return image
                }()
                static let LIGHT: NSImage = {
                    let image = NSImage(named: "email_outline_light")!
                    image.isTemplate = true
                    return image
                }()
                static let RED: NSImage = {
                    let image = NSImage(named: "email_outline_red")!
                    image.isTemplate = false
                    return image
                }()
            }
        }
    }
}

func encodeParametersForPOST<K, V>(_ parameters: [K:V]) -> Data where K:Hashable {
    var string = ""
    var first = true
    for (key, value) in parameters {
        if first {
            first = false
        } else {
            string += "&"
        }
        string += "\(key)=\(value)"
    }
    return (string as NSString).data(using: String.Encoding.utf8.rawValue, allowLossyConversion:true)!
}

extension Data {
    init?(base64URLEncodedString base64URLString: String, options: NSData.Base64DecodingOptions) {
        var base64String = base64URLString.replacingOccurrences(of: "-", with: "+", options: NSString.CompareOptions.literal, range: nil)
        base64String = base64String.replacingOccurrences(of: "_", with: "/", options: NSString.CompareOptions.literal, range: nil)
        let equalsToBeAdded = (base64URLString as NSString).length % 4
        for _ in 0..<equalsToBeAdded {
            base64String += "="
        }
        (self as NSData).init(base64Encoded: base64String, options: options)
    }
}

extension Sequence {
    /// - returns: A `SignalProducer` which, upon `start`ing, yields the
    /// sequence's elements in the order in which they would be iterated.
    func rac_values() -> SignalProducer<Iterator.Element, NoError> {
        return SignalProducer({ (observer, disposable) -> () in
            for element in self {
                observer.sendNext(element)
            }
            observer.sendCompleted()
        })
    }
}
