//
//  GNAppDelegate.h
//  Gmail Notifier
//
//  Created by James Shepherdson on 1/1/13.
//  Copyright (c) 2013 James Shepherdson. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

@interface GNAppDelegate : NSObject <NSApplicationDelegate>

#pragma mark Actions
- (void)goToInbox;
- (void)reportIssue;
- (void)checkForUpdate;
- (void)showPreferences;
- (void)showAboutPanel;
- (void)quit;

@end
