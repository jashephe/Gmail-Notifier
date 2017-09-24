//
//  GNGeneralPreferencesViewController.m
//  Gmail Notifier
//
//  Created by James Shepherdson on 1/2/13.
//  Copyright (c) 2013 James Shepherdson. All rights reserved.
//

#import "GNGeneralPreferencesViewController.h"

@interface GNGeneralPreferencesViewController ()
@property (strong) NSPopover *tagHelpTextPopover;
@end

@implementation GNGeneralPreferencesViewController

/** Show the popup help text for the notification source combox box. */
- (IBAction)showTagHelpText:(NSButton *)sender {
	if (!self.tagHelpTextPopover) {
		self.tagHelpTextPopover = [[NSPopover alloc] init];
		NSViewController *popoverViewController = [[NSViewController alloc] initWithNibName:nil bundle:nil];
		popoverViewController.view = self.tagHelpTextView;
		self.tagHelpTextPopover.contentViewController = popoverViewController;
		self.tagHelpTextPopover.behavior = NSPopoverBehaviorTransient;
	}
	[self.tagHelpTextPopover showRelativeToRect:sender.frame ofView:self.view preferredEdge:NSMaxXEdge];
}

#pragma mark MASPreferencesViewController Delegate Methods

- (NSString *)identifier {
	return @"General";
}

- (NSImage *)toolbarItemImage {
	return [NSImage imageNamed:NSImageNamePreferencesGeneral];
}

- (NSString *)toolbarItemLabel {
	return NSLocalizedString(@"General", @"Toolbar item name for the General preference pane");
}

@end
