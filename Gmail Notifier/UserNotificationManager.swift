import Cocoa
import ReactiveCocoa
import Result

private let kNOTIFICATION_MESSAGE_ID = "notification.messageID"
private let kNOTIFICATION_MESSAGE_URL_STRING = "notification.messageURLString"

class UserNotificationManager: NSObject, NSUserNotificationCenterDelegate {

    fileprivate var accountManager: AccountManager
    fileprivate var userNotificationCenter = NSUserNotificationCenter.default

    init(accountManager theAccountManager: AccountManager) {
        self.accountManager = theAccountManager
        super.init()
        self.userNotificationCenter.delegate = self
        self.userNotificationCenter.removeAllDeliveredNotifications()

        self.accountManager.accounts.producer.flatMap(.latest, transform: { (accounts) -> SignalProducer<Account, NoError> in
            return SignalProducer({ (observer, disposable) -> () in
                for account in accounts {
                    observer.sendNext(account)
                }
            })
        }).start(Observer(
            next: { (account) -> () in
                for message in account.messages {
                    self.sendNotificationForMessage(message)
                }
                account.messageDeltas.observe(Observer(
                    next: { (removed, added) -> () in
                        for message in removed {
                            self.removeNotificationForMessage(message)
                        }
                        for message in added {
                            self.sendNotificationForMessage(message)
                        }
                }))
        }))
    }

    func sendNotificationForMessage(_ message: Message) {
        NSUserNotificationCenter.default.deliver(message.userNotification)
    }

    func removeNotificationForMessage(_ message: Message) {
        NSUserNotificationCenter.default.removeDeliveredNotification(message.userNotification)
    }

    func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
        return true
    }

    func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
        if let userInfo = notification.userInfo {
            if let webURLString = userInfo[kNOTIFICATION_MESSAGE_URL_STRING] as? String {
                if let webURL = URL(string: webURLString) {
                    NSWorkspace.shared().open(webURL)
                }
            }
        }
        center.removeDeliveredNotification(notification)
    }

}

private extension Message {
    var userNotification: NSUserNotification {
        let notification = NSUserNotification()
        notification.title = self.subject
        notification.subtitle = self.sender
        notification.informativeText = self.snippet
        notification.deliveryDate = self.dateReceived as Date
        notification.soundName = "new_mail"
        notification.userInfo = [kNOTIFICATION_MESSAGE_ID: self.messageID, kNOTIFICATION_MESSAGE_URL_STRING: self.webURL.absoluteString]
        return notification
    }
}
