//
//  GNAppDelegate.m
//  Gmail Notifier
//
//  Created by James Shepherdson on 1/1/13.
//  Copyright (c) 2013 James Shepherdson. All rights reserved.
//

#import "GNAppDelegate.h"
#import "GNMailFetchManager.h"
#import "MASPreferencesWindowController.h"
#import "GNGeneralPreferencesViewController.h"
#import "GNAccountPreferencesViewController.h"
#import "GNUtils.h"

@interface GNAppDelegate ()
@property (strong) GNMailFetchManager *fetchManager;
@property (strong) MASPreferencesWindowController *prefsWindowController;
@end


@implementation GNAppDelegate

+ (void)initialize {
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
															 [NSNumber numberWithBool:YES], GNPrefsShowSnippetsKey,
															 [NSNumber numberWithInt:1], GNPrefsRefreshIntervalKey,
															 [NSNumber numberWithBool:YES], GNPrefsShowUnreadCountInStatusItemKey,
															 [NSNumber numberWithBool:NO], GNPrefsOnlyShowNewMessagesKey,
															 nil]];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	[[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(handleURLEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
	self.fetchManager = [[GNMailFetchManager alloc] init];
	
}

// Handle mailto: URLs by opening a Gmail compose window.
- (void)handleURLEvent:(NSAppleEventDescriptor*)event withReplyEvent:(NSAppleEventDescriptor*)replyEvent {
	// FIXME:  Make this handle other mailto: components, such as a subject or body.
	NSURL* theURL = [NSURL URLWithString:[[event paramDescriptorForKeyword:keyDirectObject] stringValue]];
	if ([theURL.scheme isEqualToString:@"mailto"])
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://mail.google.com/mail/?view=cm&fs=1&tf=1&to=%@", theURL.resourceSpecifier]]];
}

#pragma mark Actions

// Convenient shortcut to opening Gmail in the user's default browser.
- (void)goToInbox {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://mail.google.com/"]];
}

// Creates (if necessary) and shows the preferences window.
- (void)showPreferences {
	if (!self.prefsWindowController)
		self.prefsWindowController = [[MASPreferencesWindowController alloc] initWithViewControllers:@[[[GNGeneralPreferencesViewController alloc] initWithNibName:@"GNGeneralPreferencesViewController" bundle:[NSBundle mainBundle]], [[GNAccountPreferencesViewController alloc] initWithNibName:@"GNAccountPreferencesViewController" bundle:[NSBundle mainBundle]]] title:NSLocalizedString(@"Preferences", @"Status menu option and Window Title")];
	[self.prefsWindowController selectControllerAtIndex:0];
	[self.prefsWindowController.window center];
	[NSApp activateIgnoringOtherApps:YES];
	[self.prefsWindowController showWindow:nil];
}

// Brings application to front and shows about panel.  Clicking on the status item doesn't
// automatically activate the application, meaning that the about panel might appear behind
// the window of some other application.
- (void)showAboutPanel {
	[NSApp activateIgnoringOtherApps:YES];
	[NSApp orderFrontStandardAboutPanel:nil];
}

// We want to call terminate at the start of the next event loop, just to be safe.
- (void)quit {
	[NSApp performSelector:@selector(terminate:) withObject:nil afterDelay:0.0];
}

@end
