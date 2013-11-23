//
//  GNAccountPreferencesViewController.h
//  Gmail Notifier
//
//  Created by James Shepherdson on 1/2/13.
//  Copyright (c) 2013 James Shepherdson. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <gtm-oauth2/GTMOAuth2WindowController.h>
#import <MASPreferencesViewController.h>

@interface GNAccountPreferencesViewController : NSViewController <MASPreferencesViewController>

@property IBOutlet NSButton *accountButton;
@property IBOutlet NSTextField *statusText;


@end
