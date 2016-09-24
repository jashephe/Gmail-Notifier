import Cocoa

class AccountStatusMenuEntryViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }

    override var nibName: String? {
        return "\(type(of: self))"
    }
}
