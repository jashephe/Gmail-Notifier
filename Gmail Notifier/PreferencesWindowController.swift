import Cocoa

func identifierForInstance(_ instance: AnyObject) -> String {
    return NSRunningApplication.current().localizedName! + "." + String(describing: type(of: instance))
}

protocol PreferenceViewController: class {
    var toolbarItemImage: NSImage { get }
    var toolbarItemLabel: String { get }
    var preferredSize: NSSize { get }
    var allowResizing: Bool { get }
}

class PreferencesWindowController: NSWindowController, NSToolbarDelegate {
    static let PREFERENCES_TOOLBAR_IDENTIFIER = NSRunningApplication.current().localizedName! + ".preferencesToolbar"

    override func windowDidLoad() {
        super.windowDidLoad()
    }

    init(viewControllers: [NSViewController]) {
        let tabViewController = PreferenceTabViewController(nibName: nil, bundle: nil)!
        tabViewController.tabStyle = .toolbar
        tabViewController.transitionOptions = NSViewControllerTransitionOptions()
        viewControllers.forEach { (viewController) -> () in
            let item = NSTabViewItem(identifier: identifierForInstance(viewController))
            item.viewController = viewController
            item.label = (viewController as! PreferenceViewController).toolbarItemLabel
            item.image = (viewController as! PreferenceViewController).toolbarItemImage
            tabViewController.addTabViewItem(item)
        }
        let window = NSWindow(contentRect: tabViewController.tabView.bounds, styleMask: (NSTitledWindowMask | NSClosableWindowMask), backing: .buffered, defer: true)
        window.title = "Preferences"
        window.collectionBehavior = NSWindowCollectionBehavior([NSWindowCollectionBehavior.moveToActiveSpace, NSWindowCollectionBehavior.managed, NSWindowCollectionBehavior.fullScreenAuxiliary, NSWindowCollectionBehavior.fullScreenDisallowsTiling])
        window.contentViewController = tabViewController
        if (tabViewController.tabViewItems[tabViewController.selectedTabViewItemIndex].viewController as! PreferenceViewController).allowResizing == true {
            window.styleMask = window.styleMask | NSResizableWindowMask
        }
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class PreferenceTabViewController: NSTabViewController {
    override func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        if let nextTabViewController = tabViewItem?.viewController as? PreferenceViewController, let window = self.view.window {
            let newFrameSize = window.frameRect(forContentRect: NSMakeRect(0, 0, nextTabViewController.preferredSize.width, nextTabViewController.preferredSize.height)).size
            window.setFrame(NSMakeRect(window.frame.origin.x, window.frame.origin.y + NSHeight(window.frame) - newFrameSize.height, newFrameSize.width, newFrameSize.height), display: false, animate: false)
            if nextTabViewController.allowResizing {
                window.styleMask = window.styleMask | NSResizableWindowMask
            } else {
                window.styleMask = window.styleMask & ~NSResizableWindowMask
            }
        }

        super.tabView(tabView, willSelect: tabViewItem)
    }

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
    }
}
