//
//  GNAppDelegate.h
//  Gmail Notifier
//
//  Created by James Shepherdson on 1/1/13.
//  Copyright (c) 2013 James Shepherdson. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface GNAppDelegate : NSObject <NSApplicationDelegate>

- (void)goToInbox;
- (void)showPreferences;
- (void)showAboutPanel;
- (void)quit;

@end
