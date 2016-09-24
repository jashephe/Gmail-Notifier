import Cocoa
import ReactiveCocoa

class AccountsPreferencesViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, PreferenceViewController {
    //MARK: Toolbar
    let toolbarItemImage: NSImage = NSImage(named: NSImageNameUserAccounts)!
    let toolbarItemLabel: String = "Accounts"
    var preferredSize: NSSize = NSMakeSize(500, 356)
    let allowResizing: Bool = true

    //MARK: Managed Accounts
    var accountManager: AccountManager
    @IBOutlet weak var accountsList: NSTableView!
    @IBOutlet weak var statusIndicator: MultiTaskStatusIndicator!
    @IBOutlet weak var accountTransactionControl: NSSegmentedControl!

    //MARK: New Account Creation
    @IBOutlet var newAccountPanel: NSView!
    @IBOutlet weak var logInButton: NSButton!
    @IBOutlet weak var codeField: NSTextField!
    @IBOutlet weak var addAccountButton: NSButton!

    //MARK: Account Detail Properties
    @IBOutlet weak var accountDetailContainer: NSBox!
    @IBOutlet weak var accountDetailView: NSView!
    @IBOutlet weak var noAccountsView: NSView!
    @IBOutlet weak var userNameField: NSTextField!
    @IBOutlet weak var emailAddressField: NSTextField!
    @IBOutlet weak var profilePictureView: NSImageView!
    @IBOutlet weak var filterQueryField: NSTextField!
    @IBOutlet weak var testQueryButton: NSButton!
    @IBOutlet weak var searchQueryHelpView: NSView!
    @IBOutlet weak var queryTestHelpView: NSView!

    //MARK: - Lifecycle

    init(accountManager: AccountManager) {
        self.accountManager = accountManager
        super.init(nibName: "AccountsPreferencesPane", bundle: Bundle.main)!
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: View Controls

    override func viewDidLoad() {
        super.viewDidLoad()
        self.preferredSize = self.view.bounds.size

        self.accountDetailContainer.contentView = self.noAccountsView

        self.accountManager.accounts.producer.observeOn(UIScheduler()).startWithNext { (accounts) -> () in
            if accounts.count == 0 {
                self.accountTransactionControl.setEnabled(false, forSegment: 1)
                if self.accountDetailContainer.contentView != self.noAccountsView {
                    self.accountDetailContainer.contentView = self.noAccountsView
                }
            } else {
                self.accountTransactionControl.setEnabled(true, forSegment: 1)
            }
            self.accountsList.reloadData()
        }

        self.codeField.rac_textSignal().toSignalProducer().map({ (token) -> Bool in
            if let token = token as? NSString {
                return (token.length > 0 && !token.contains("@") && !token.contains(" "))
            }
            return false
        }).startWithNext({ (isValidToken) -> () in
            self.addAccountButton.isEnabled = isValidToken
        })

        //FIXME: This gets the value *before* the change, not after the change.
        NotificationCenter.default.rac_addObserver(forName: NSNotification.Name.NSComboBoxSelectionDidChange, object: self.filterQueryField).toSignalProducer().startWithNext { (value) in
            if let notification = value as? Notification {
                if let queryField = notification.object as? NSComboBox {
                    print("Changed: \(queryField.stringValue)")
                }
            }
        }

        self.filterQueryField.rac_textSignal().toSignalProducer().map({ (value) -> String in
            if let value = value as? String {
                return value
            }
            return ""
        }).startWithNext({ (filterQuery) -> () in
            print("New filter query: \(filterQuery)")
            print("Current account: \(self.selectedAccount?.emailAddress)")
            self.selectedAccount?.filterQuery = filterQuery
        })

        NSEvent.addLocalMonitorForEvents(matching: NSEventMask.flagsChanged) { (event) -> NSEvent? in
            if event.modifierFlags.contains(.AlternateKeyMask) {
                self.testQueryButton.image = NSImage(named: "CopyToClipboardTemplate")
                self.logInButton.image = NSImage(named: "CopyToClipboardTemplate")
            } else {
                self.testQueryButton.image = NSImage(named: "FollowLinkTemplate")
                self.logInButton.image = NSImage(named: "FollowLinkTemplate")
            }
            
            return event
        }
    }

    //MARK: Table View Controls

    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.accountManager.accounts.value.count
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return AccountCellView.preferredHeight
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return self.accountManager.accounts.value[row]
    }

    var selectedAccount: Account? {
        return self.accountsList.selectedRow > -1 ? self.accountManager.accounts.value[self.accountsList.selectedRow] : nil
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        if self.accountsList.selectedRow > -1 {
            self.tableView(self.accountsList, viewFor: nil, row: self.accountsList.selectedRow)?.needsDisplay = true
            if self.accountDetailContainer.contentView != self.accountDetailView {
                self.accountDetailContainer.contentView = self.accountDetailView
            }
            self.userNameField.stringValue = self.selectedAccount!.userName
            self.emailAddressField.stringValue = self.selectedAccount!.emailAddress
            self.profilePictureView.image = self.selectedAccount!.profilePicture
            self.filterQueryField.stringValue = self.selectedAccount!.filterQuery
        }
    }

    let kAccountCellViewReuseIdentifier = "AccountCellView"
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var cellView: AccountCellView
        if let potentialCellView = tableView.make(withIdentifier: kAccountCellViewReuseIdentifier, owner: nil) as? AccountCellView {
            potentialCellView.objectValue = nil
            cellView = potentialCellView
        } else {
            cellView = AccountCellView()
            cellView.identifier = kAccountCellViewReuseIdentifier
        }
        return cellView
    }

    //MARK: Actions

    @IBAction func testQuery(_ sender: AnyObject) {
        if let account = self.selectedAccount {
            let url = GmailParameters.constructWebURL(emailAddress: account.emailAddress, withFragment: "search/\(account.filterQuery)")
            if NSEvent.modifierFlags().contains(.AlternateKeyMask) {
                NSPasteboard.general().clearContents()
                NSPasteboard.general().writeObjects([url.absoluteString as! NSPasteboardWriting])
            } else {
                NSWorkspace.shared().open(url as URL)
            }
        }
    }

    fileprivate var sheetModalWindow: NSWindow?
    @IBAction func performAccountTransaction(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
            if sheetModalWindow == nil {
                self.sheetModalWindow = NSWindow(contentRect: self.newAccountPanel.bounds, styleMask: NSTitledWindowMask, backing: NSBackingStoreType.buffered, defer: false)
                self.sheetModalWindow!.contentView = self.newAccountPanel
            }
            self.codeField.stringValue = ""
            self.addAccountButton.isEnabled = false
            self.view.window?.beginSheet(self.sheetModalWindow!, completionHandler: { (modalResponse: NSModalResponse) -> Void in

            })
        case 1:
            if let selectedAccount = self.selectedAccount {
                let key = "removeAccount_\(selectedAccount.emailAddress)"
                self.statusIndicator.addStatusAction(key: key, label: "Removing account.")
                self.accountManager.removeAccountAtIndex(self.accountsList.selectedRow).observeOn(UIScheduler()).start(Observer(
                    failed: { (error) -> () in
                        let alert = error.constructAlert("The account was removed, but its tokens could not be revoked.")
                        alert.beginSheetModal(for: self.view.window!, completionHandler: nil)
                        self.statusIndicator.removeStatusAction(key: key)
                    },
                    completed: { () -> () in
                        self.statusIndicator.removeStatusAction(key: key)
                }))
                //FIXME: Why does the spinner not stop?
            }
        default:
            NSLog("Internal Inconsistency.  Unexpected number of segemented control segments.")
        }
    }

    @IBAction func attemptAddAccount(_ sender: AnyObject) {
        self.closeSheet(sender)
        self.statusIndicator.addStatusAction(key: self.codeField.stringValue, label: "Creating new account.")
        self.accountManager.addAccountWithCode(self.codeField.stringValue).observeOn(UIScheduler()).start(Observer(
            failed: { (error) -> () in
                let alert = error.constructAlert("The account could not be added.")
                alert.beginSheetModal(for: self.view.window!, completionHandler: nil)
                self.statusIndicator.removeStatusAction(key: self.codeField.stringValue)
            },
            completed: { () -> () in
                self.statusIndicator.removeStatusAction(key: self.codeField.stringValue)
            }))
    }

    @IBAction func closeSheet(_ sender: AnyObject) {
        if let sheet = self.view.window?.attachedSheet {
            self.view.window!.endSheet(sheet)
            sheet.orderOut(self)
        }
    }

    @IBAction func launchLoginRequest(_ sender: AnyObject) {
        let url = GoogleParameters.Authentication.constructAuthenticationURL()
        if NSEvent.modifierFlags().contains(.AlternateKeyMask) {
            NSPasteboard.general().clearContents()
            NSPasteboard.general().writeObjects([url.absoluteString as! NSPasteboardWriting])
        } else {
            NSWorkspace.shared().open(url as URL)
        }
    }

    fileprivate var searchQueryHelpPanel: NSPopover?
    fileprivate var queryTestHelpPanel: NSPopover?
    @IBAction func showQueryHelpPanel(_ sender: NSButton) {
        if searchQueryHelpPanel == nil {
            searchQueryHelpPanel = NSPopover()
            searchQueryHelpPanel?.contentViewController = NSViewController(nibName: nil, bundle: nil)
            searchQueryHelpPanel?.contentViewController?.view = self.searchQueryHelpView
            searchQueryHelpPanel?.behavior = .transient
        }
        if queryTestHelpPanel == nil {
            queryTestHelpPanel = NSPopover()
            queryTestHelpPanel?.contentViewController = NSViewController(nibName: nil, bundle: nil)
            queryTestHelpPanel?.contentViewController?.view = self.queryTestHelpView
            queryTestHelpPanel?.behavior = .transient
        }
        searchQueryHelpPanel?.show(relativeTo: NSZeroRect, of: self.filterQueryField, preferredEdge: .maxY)
        queryTestHelpPanel?.show(relativeTo: NSZeroRect, of: self.testQueryButton, preferredEdge: .maxX)
    }
}
