import Cocoa

class AccountStatusMenuViewController: NSViewController {

    @IBOutlet fileprivate var accountsStack: NSStackView!
    @IBOutlet fileprivate var entryPlaceholder: NSView!
    @IBOutlet fileprivate var statusField: NSTextField!

    var statusString: String {
        get {
            return statusField.stringValue
        }
        set(value) {
            self.statusField.stringValue = value
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        //FIXME: Why doesn't this work?
        let controller = AccountStatusMenuEntryViewController(nibName: "AccountStatusMenuEntryViewController", bundle: Bundle.main)!
        self.accountsStack.addView(controller.view, in: .bottom)

        self.accountsStack.addView(self.entryPlaceholder, in: .top)
    }

    override var nibName: String? {
        return "\(type(of: self))"
    }
}
