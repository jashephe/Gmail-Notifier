//
//  GNAppDelegate.m
//  Gmail Notifier
//
//  Created by James Shepherdson on 1/1/13.
//  Copyright (c) 2013 James Shepherdson. All rights reserved.
//

#import "GNAppDelegate.h"
#import "GNUIManager.h"
#import <MASPreferencesWindowController.h>
#import "GNGeneralPreferencesViewController.h"
#import "GNAccountPreferencesViewController.h"

@interface GNAppDelegate ()
@property (strong) GNUIManager *uiManager;
@property (strong) MASPreferencesWindowController *prefsWindowController;
@end


@implementation GNAppDelegate

+ (void)initialize {
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
															 [NSNumber numberWithBool:YES], GNPrefsShowSnippetsKey,
															 [NSNumber numberWithInt:1], GNPrefsUpdateIntervalKey,
															 [NSNumber numberWithBool:YES], GNPrefsShowUnreadCount,
															 @"inbox", GNPrefsMessagesSourceKey,
															 nil]];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	[[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(handleURLEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
	self.uiManager = [[GNUIManager alloc] init];
}

/* Handle mailto: URLs by opening a Gmail compose window. */
- (void)handleURLEvent:(NSAppleEventDescriptor*)event withReplyEvent:(NSAppleEventDescriptor*)replyEvent {
	NSURL* theURL = [NSURL URLWithString:[[event paramDescriptorForKeyword:keyDirectObject] stringValue]];
	if ([theURL.scheme isEqualToString:@"mailto"]) {
		NSString *processedComposeURL = [[theURL.resourceSpecifier stringByReplacingOccurrencesOfString:@"?" withString:@"&"] stringByReplacingOccurrencesOfString:@"subject" withString:@"su"];
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://mail.google.com/mail/?view=cm&fs=1&tf=1&to=%@", processedComposeURL]]];
	}
}

#pragma mark Actions

/** Convenient shortcut to opening Gmail in the user's default browser. */
- (void)goToInbox {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://mail.google.com/"]];
}

/** Convenient shortcut to opening GitHub issues in the user's default browser. */
- (void)reportIssue {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/jashephe/Gmail-Notifier/issues"]];
}

/** Convenient shortcut to opening GitHub releases in the user's default browser. */
- (void)checkForUpdate {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/jashephe/Gmail-Notifier/releases/latest"]];
}


/** Creates (if necessary) and shows the preferences window. */
- (void)showPreferences {
	if (!self.prefsWindowController)
		self.prefsWindowController = [[MASPreferencesWindowController alloc] initWithViewControllers:@[[[GNGeneralPreferencesViewController alloc] initWithNibName:@"GNGeneralPreferencesViewController" bundle:[NSBundle mainBundle]], [[GNAccountPreferencesViewController alloc] initWithNibName:@"GNAccountPreferencesViewController" bundle:[NSBundle mainBundle]]] title:NSLocalizedString(@"Preferences", @"Status menu option and Window Title")];
	[self.prefsWindowController selectControllerAtIndex:0];
	[self.prefsWindowController.window center];
	[NSApp activateIgnoringOtherApps:YES];
	[self.prefsWindowController showWindow:nil];
}

/** Brings application to front and shows about panel.  Clicking on the status item doesn't
	automatically activate the application, meaning that the about panel might appear behind
	the window of some other application, so we force it to move to the foreground. */
- (void)showAboutPanel {
	[NSApp activateIgnoringOtherApps:YES];
	[NSApp orderFrontStandardAboutPanel:nil];
}

/** Calls terminate: at the start of the next event loop. */
- (void)quit {
	[NSApp performSelector:@selector(terminate:) withObject:nil afterDelay:0.0];
}

@end
