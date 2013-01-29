//
//  GNAccountPreferencesViewController.m
//  Gmail Notifier
//
//  Created by James Shepherdson on 1/2/13.
//  Copyright (c) 2013 James Shepherdson. All rights reserved.
//

#import "GNAccountPreferencesViewController.h"
#import "GNMailAccountManager.h"
#import "GNUtils.h"
#import "GNAPIKeys.h"

@interface GNAccountPreferencesViewController ()

@end

@implementation GNAccountPreferencesViewController

//TODO:  Allow logout and token revoke
- (void)awakeFromNib {
	[self respondToAccountStateChange];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(respondToAccountStateChange) name:GNAuthDidChangeNotification object:nil];
}

- (void)respondToAccountStateChange {
	if ([[GNMailAccountManager sharedAccountManager] isReady]) {
		self.statusText.stringValue = NSLocalizedString(@"Logged in.", @"Displayed in the account preference panel");
		self.accountButton.title = NSLocalizedString(@"Log Out", @"Displayed on the action button in the account preference panel");
	}
	else {
		self.statusText.stringValue = NSLocalizedString(@"Not logged in.", @"Displayed in the account preference panel");
		self.accountButton.title = NSLocalizedString(@"Log In", @"Displayed on the action button in the account preference panel");
	}
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark IBActions
- (IBAction)performAccountAction:(id)sender {
	if ([[GNMailAccountManager sharedAccountManager] isReady])
		[[GNMailAccountManager sharedAccountManager] attemptMailAccountLogoutAndTokenRevocation];
	else
		[[GNMailAccountManager sharedAccountManager] attemptMailAccountLoginWithWindow:self.view.window];
}

#pragma mark MASPreferencesViewController Delegate Methods
- (NSString *)identifier {
	return @"Account";
}

- (NSImage *)toolbarItemImage {
	return [NSImage imageNamed:NSImageNameUserAccounts];
}

- (NSString *)toolbarItemLabel {
	return NSLocalizedString(@"Account", @"Toolbar item name for the Account preference pane");
}

@end
