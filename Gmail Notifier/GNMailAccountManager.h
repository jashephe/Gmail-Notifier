//
//  GNMailAccountManager.h
//  Gmail Notifier
//
//  Created by James Shepherdson on 1/12/13.
//  Copyright (c) 2013 James Shepherdson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ReactiveCocoa/ReactiveCocoa.h>
#import <GTMOAuth2WindowController.h>

@interface GNMailAccountManager : NSObject

/** The GTMOAuth2 authentication token to use for authorizing HTTP requests. */
@property (strong) GTMOAuth2Authentication *authentication;

+ (GNMailAccountManager *)sharedAccountManager;

#pragma mark Authentication Operations
- (void)attemptMailAccountLoginWithWindow:(NSWindow *)windowOrNil;
- (void)attemptMailAccountLogoutAndTokenRevocation;

#pragma mark Status Signals
- (RACSignal *)readySignal;
- (RACSignal *)reachableSignal;

@end
