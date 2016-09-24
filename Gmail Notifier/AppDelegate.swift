import Cocoa
import ReactiveCocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var accountManager: AccountManager!
    var menuUIManager: MenuUIManager!
    var userNotificationManager: UserNotificationManager!
    var preferencesWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setUpDefaults()

        self.accountManager = AccountManager()
        self.menuUIManager = MenuUIManager(accountManager: self.accountManager)

        self.userNotificationManager = UserNotificationManager(accountManager: self.accountManager)
        if let launchNotification = (aNotification as NSNotification).userInfo?[NSApplicationLaunchUserNotificationKey] as? NSUserNotification {
            // If the application was launched as a result of the user clicking on a notification, let the notification manager know.
            self.userNotificationManager.userNotificationCenter(NSUserNotificationCenter.default, didActivate: launchNotification)
        }
    }

    func showPreferencesWindow() {
        if preferencesWindowController == nil {
            self.preferencesWindowController = PreferencesWindowController(viewControllers: [GeneralPreferencesViewController(nibName: "GeneralPreferencesPane", bundle: Bundle.main)!, AccountsPreferencesViewController(accountManager: self.accountManager)])
        }
        NSApp.activate(ignoringOtherApps: true)
        self.preferencesWindowController!.window?.center()
        self.preferencesWindowController!.showWindow(self)
    }

    func showAboutPanel() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(self)
    }

    func setUpDefaults() {
        let defaults = UserDefaults(suiteName: XPCParameters.APPLICATION_GROUP_IDENTIFIER)!
        let initialValues = [
            Defaults.Application.kPOLL_INTERVAL : 1,
            Defaults.Application.kLAUNCH_AT_LOGIN : false,
            Defaults.kACCOUNTS_STORE : [:]
        ] as [String : Any]
        defaults.register(defaults: initialValues)
    }
}

