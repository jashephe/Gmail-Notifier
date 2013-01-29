//
//  GNMailAccountManager.h
//  Gmail Notifier
//
//  Created by James Shepherdson on 1/12/13.
//  Copyright (c) 2013 James Shepherdson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GTMOAuth2/GTMOAuth2WindowController.h>

@interface GNMailAccountManager : NSObject

+ (GNMailAccountManager *)sharedAccountManager;
- (void)attemptMailAccountLoginWithWindow:(NSWindow *)windowOrNil;
- (void)attemptMailAccountLogoutAndTokenRevocation;
- (BOOL)isReady;

@property GTMOAuth2Authentication *authentication;

@end
