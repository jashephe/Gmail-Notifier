import Cocoa
import ReactiveCocoa

class GeneralPreferencesViewController: NSViewController, PreferenceViewController {
    let toolbarItemImage: NSImage = NSImage(named: NSImageNamePreferencesGeneral)!
    let toolbarItemLabel: String = "General"
    var preferredSize: NSSize = NSZeroSize
    let allowResizing: Bool = false

    fileprivate var userDefaultsMonitorDisposable: Disposable!

    @IBOutlet weak var updateIntervalField: NSTextField!
    @IBOutlet weak var launchAtLoginCheckbox: NSButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.preferredSize = self.view.bounds.size

        let defaults = UserDefaults(suiteName: XPCParameters.APPLICATION_GROUP_IDENTIFIER)!
        self.userDefaultsMonitorDisposable = NotificationCenter.default.rac_notifications(UserDefaults.didChangeNotification, object: nil).start(Observer(
            next: { (notification) -> () in
                self.updateIntervalField.integerValue = defaults.integer(forKey: Defaults.Application.kPOLL_INTERVAL)
                self.launchAtLoginCheckbox.state = defaults.bool(forKey: Defaults.Application.kLAUNCH_AT_LOGIN) ? NSOnState : NSOffState
        }))

        self.launchAtLoginCheckbox.rac_values(forKeyPath: "cell.state", observer: self).toSignalProducer().startWithNext({ (state) -> () in
            if let state  = state as? Int , state == NSOnState {
                // TODO:  Set launch at login
                print("TODO:  Set launch at login")
            } else {
                // TODO:  Unset launch at login
                print("TODO:  Unset launch at login")
            }
        })
    }

    deinit {
        self.userDefaultsMonitorDisposable.dispose()
    }

}
