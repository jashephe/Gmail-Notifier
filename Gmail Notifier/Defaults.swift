import Foundation

struct XPCParameters {
    static let APPLICATION_GROUP_IDENTIFIER = "group.org.jashephe.Gmail-Notifier"
}

struct Defaults {
    struct Application {
        static let kPOLL_INTERVAL = "application.pollInterval"
        static let kLAUNCH_AT_LOGIN = "application.launchAtLogin"
    }

    static let kACCOUNTS_STORE = "accounts"
    struct Account {
        static let kFILTER_QUERY = "account.filterQuery"
        static let kSHOW_SNIPPETS = "account.showSnippets"
        static let kSHOW_IN_WIDGET = "account.showInTodayWidget"
        static let kALLOW_QUICKLOOK = "account.allowQuickLookPreviews"
    }
}