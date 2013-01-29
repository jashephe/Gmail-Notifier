//
//  GNGeneralPreferencesViewController.m
//  Gmail Notifier
//
//  Created by James Shepherdson on 1/2/13.
//  Copyright (c) 2013 James Shepherdson. All rights reserved.
//

#import "GNGeneralPreferencesViewController.h"

@interface GNGeneralPreferencesViewController ()

@end

@implementation GNGeneralPreferencesViewController

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
