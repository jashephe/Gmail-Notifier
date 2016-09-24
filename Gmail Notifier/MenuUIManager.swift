import Cocoa
import ReactiveCocoa
import Result

class MenuUIManager {

    var accountManager: AccountManager

    var accountStatusController: AccountStatusMenuViewController

    var statusItem: NSStatusItem = {
        let item = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
        item.image = AppParameters.Images.Message.Outline.LIGHT
        return item
    }()

    fileprivate let tACCOUNTS_STATUS_ITEM = 1
    fileprivate let tCHECK_HISTORY_ITEM = 2


    func createStatusItemMenu() -> NSMenu {
        let menu = NSMenu(title: NSRunningApplication.current().localizedName!)

        let accountsStatusItem = NSMenuItem(title: NSLocalizedString("Accounts", comment: "Status menu accounts status"), action: nil, keyEquivalent: "")
        accountsStatusItem.tag = tACCOUNTS_STATUS_ITEM
        accountsStatusItem.view = self.accountStatusController.view
        menu.addItem(accountsStatusItem)

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(title: NSLocalizedString("About \(NSRunningApplication.current().localizedName!)", comment: "Status menu about descriptor"), action: #selector(AppDelegate.showAboutPanel), keyEquivalent: "")
        aboutItem.target = NSApp.delegate
        menu.addItem(aboutItem)

        let supportItem = NSMenuItem(title: NSLocalizedString("Support", comment: "Status menu support descriptor"), action: nil, keyEquivalent: "")
        let supportMenu = NSMenu(title: supportItem.title)
        supportItem.submenu = supportMenu
        menu.addItem(supportItem)

        let support_updateItem = NSMenuItem(title: NSLocalizedString("Check for Updates", comment: "Support menu update check descriptor"), action: nil, keyEquivalent: "")
        supportMenu.addItem(support_updateItem)

        let support_fileIssueItem = NSMenuItem(title: NSLocalizedString("Report an Issue", comment: "Support menu issue reporting descriptor"), action: nil, keyEquivalent: "")
        supportMenu.addItem(support_fileIssueItem)

        let preferencesItem = NSMenuItem(title: NSLocalizedString("Preferences", comment: "Status menu preferences descriptor"), action: #selector(AppDelegate.showPreferencesWindow), keyEquivalent: "")
        preferencesItem.target = NSApp.delegate
        menu.addItem(preferencesItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: NSLocalizedString("Quit \(NSRunningApplication.current().localizedName!)", comment: "Status menu quit descriptor"), action: #selector(NSApp.terminate), keyEquivalent: "")
        quitItem.target = NSApp
        menu.addItem(quitItem)

        return menu
    }

    init(accountManager: AccountManager) {
        self.accountManager = accountManager
        self.accountStatusController = AccountStatusMenuViewController(nibName: "AccountStatusMenuViewController", bundle: Bundle.main)!
        self.statusItem.menu = self.createStatusItemMenu()

        self.accountManager.lastUpdate.signal.observeNext({ (latestUpdate) -> () in
            let formatter = DateFormatter()
            formatter.timeStyle = .medium
            formatter.dateStyle = .none
            formatter.locale = Locale.current
            self.accountStatusController.statusString = NSLocalizedString("Last Updated at \(formatter.string(from: latestUpdate))", comment: "Status menu check history")
        })

        self.accountManager.isNetworkReachable.producer.combineLatestWith(self.accountManager.accounts.producer).startWithNext { (isNetworkReachable, accounts) -> () in
            if !isNetworkReachable {
                self.statusItem.image = AppParameters.Images.Message.Outline.RED
                self.statusItem.menu?.item(withTag: self.tACCOUNTS_STATUS_ITEM)?.title = NSLocalizedString("No Network Connection", comment: "Status menu accounts status")
            } else {
                if accounts.count > 0 {
                    self.statusItem.image = AppParameters.Images.Message.Outline.DARK
                    self.statusItem.menu?.item(withTag: self.tACCOUNTS_STATUS_ITEM)?.title = NSLocalizedString("\(accounts.count) Account\(accounts.count > 1 ? "s" : "")", comment: "Status menu accounts status; Note that `accounts.count` is used to confer plurality")
                } else {
                    self.statusItem.image = AppParameters.Images.Message.Outline.LIGHT
                    self.statusItem.menu?.item(withTag: self.tACCOUNTS_STATUS_ITEM)?.title = NSLocalizedString("No Accounts", comment: "Status menu accounts status")
                }
            }
        }
    }
}
