<img src="https://raw.github.com/jashephe/Gmail-Notifier/support/images/appIcon.png" alt="Gmail Notifier Icon" width="128px">
## Gmail Notifier
### [Download] (https://github.com/jashephe/Gmail-Notifier/releases)
Minimalist Gmail inbox notifications for Mac OS X.

##Development Update
There hasn't been much activity here recently, but about 9 months ago, I started work on v3, a ground-up rewrite of Gmail Notifier in the Swift programming language.

Check out the [devel branch](https://github.com/jashephe/Gmail-Notifier/tree/devel) to see current progress. Note that as of September 2016, the devel branch is not yet even in an alpha state, and should largely be considered unusable (actually, it mostly works, but data persistence across application restarts is still in-progress, which is a fairly critical feature). **Still, if you have any suggestions or feature requests, consider [opening an issue](https://github.com/jashephe/Gmail-Notifier/issues/new).**

### Core targets of v3 include:

- [ ] Usage of the Gmail API — Previous versions of Gmail Notifier used the Gmail Inbox feed, which is easy to parse but limited in flexibility. The usage of the Gmail API will lay the foundation for future features that involve more fine-grained mailbox access, such as label and folder information.
- [ ] Multi-account support — This was highly requested, but involved writing a custom OAuth2 implementation and restructuring how account information is stored.

### Additional targets include:

- [ ] Update checking — Ideally, this will provide notifications when a new version has been released. Auto-downloading of updates still remains unlikely, because doing so with existing tools (i.e. Sparkle) requires non-GitHub infrastructure. Furthermore, auto-downloading carries with it certain security concerns that must be addressed with care and are largely beyond the scope of my ambitions for this project.
- [ ] Notification Center "Today" Widget — This was initially targeted for the v3 release, but will probably be pushed back to a feature release in v3.1. The idea is to create a widget for the Notification Center's "Today" view rather than keeping a persistent list of notifications, which is sort of a misuse of the Notification Center. 


## What Gmail Notifier is
Gmail Notifier is designed to replace [Google's Mac Notifier](http://toolbar.google.com/gmail-helper/notifier_mac.html).  It offers such improvements as Notification Center integration and OAuth2 authentication (which is nice as a general rule, but particularly so if you use 2-Factor Authentication, which you probably should).  It should currently be able to give you notifications of new messages pretty consistently, but has not been thoroughly tested, so please [file an issue](https://github.com/jashephe/Gmail-Notifier/issues) if you run across a bug.

## What Gmail Notifier is not
Gmail Notifier is not a fully-featured email client.  It cannot handle mailto: links (yet, but that's coming eventually), and cannot compose, display, or archive messages.  It simply reads your [Gmail Inbox Feed](https://mail.google.com/mail/feed/atom/), which only shows a list of unread messages in your inbox, with limited information on each message.  Gmail Notifier is for people who don't mind using Gmail's web interface, but like to get notifications about new emails, and would like to use notification center rather than whatever custom notification system rolls with [Google's Mac Notifier](http://toolbar.google.com/gmail-helper/notifier_mac.html).  Also, unlike Google's Mac Notifier, Gmail Notifier has nothing to do with your calendar.

## Building Gmail Notifier
Gmail Notifier is not a very complex project and shouldn't be too hard to build (if you have problems, please [file an issue](https://github.com/jashephe/Gmail-Notifier/issues)).  The one caveat is that you will need a Google API key.  All you have to do is head over to the [Google API Console](https://console.developers.google.com/project) and create a new API project.  There's no need for any special service access; just go to "APIs & auth" > "Credentials" in the sidebar and create a new client ID.  Make sure to set it to an "Installed application" of type "Other".  Then just copy GNAPIKeys_EXAMPLE.m in the source directory to GNAPIKeys.m, and change the keys to match what you got from the developer console.

## Screenshots
Status Menu Icon

<img src="https://raw.github.com/jashephe/Gmail-Notifier/support/images/statusIcon.png" alt="Status Menu Icon" width="241px">

Status Menu

<img src="https://raw.github.com/jashephe/Gmail-Notifier/support/images/menu.png" alt="Status Menu" width="269px">

Preferences

<img src="https://raw.github.com/jashephe/Gmail-Notifier/support/images/prefs.png" alt="Preferences" width="498px">

## A Note on the Name
Gmail Notifier is not a Google product, nor is it in any way, shape, or form endorsed or recognized as an "official" Gmail client.  The name is simply intended to make it clear what services this application is intended to work with (i.e. Google's [Gmail](http://mail.google.com/)).
