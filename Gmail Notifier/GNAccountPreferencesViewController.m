//
//  GNAccountPreferencesViewController.m
//  Gmail Notifier
//
//  Created by James Shepherdson on 1/2/13.
//  Copyright (c) 2013 James Shepherdson. All rights reserved.
//

#import "GNAccountPreferencesViewController.h"
#import "GNMailAccountManager.h"

@interface GNAccountPreferencesViewController ()

@end

@implementation GNAccountPreferencesViewController

- (void)awakeFromNib {
	// Bind the status text to whether or not the account manager is ready.
	RAC(self.statusText, stringValue) = [RACSignal combineLatest:@[[[GNMailAccountManager sharedAccountManager] readySignal], [[GNMailAccountManager sharedAccountManager] reachableSignal]] reduce:^id(NSNumber *isReady, NSNumber *isReachable) {
		if (!isReachable.boolValue) {
			return NSLocalizedString(@"No network connection", @"Displayed in the account preference panel");
		}
		else if (isReady.boolValue) {
			return NSLocalizedString(@"Logged in", @"Displayed in the account preference panel");
		}
		else {
			return NSLocalizedString(@"Not logged in", @"Displayed in the account preference panel");
		}
	}];
	
	// Bind the button text to whether or not the account manager is ready.
	RAC(self.accountButton, title) = [[[GNMailAccountManager sharedAccountManager] readySignal] map:^id(NSNumber *isReady) {
		if (isReady.boolValue) {
			return NSLocalizedString(@"Log Out", @"Displayed on the action button in the account preference panel");
		}
		else {
			return NSLocalizedString(@"Log In", @"Displayed on the action button in the account preference panel");
		}
	}];
	
	[self.accountButton rac_liftSelector:@selector(setEnabled:) withSignalsFromArray:@[[[GNMailAccountManager sharedAccountManager] reachableSignal]]];
}

#pragma mark IBActions

- (IBAction)performAccountAction:(id)sender {
	if ([GNMailAccountManager sharedAccountManager].authentication != nil && [[GNMailAccountManager sharedAccountManager].authentication canAuthorize])
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
