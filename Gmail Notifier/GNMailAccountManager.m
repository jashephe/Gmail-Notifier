//
//  GNMailAccountManager.m
//  Gmail Notifier
//
//  Created by James Shepherdson on 1/12/13.
//  Copyright (c) 2013 James Shepherdson. All rights reserved.
//

#import "GNMailAccountManager.h"
#import <libextobjc/EXTScope.h>
#import <Reachability.h>
#import "GNAPIKeys.h"

@implementation GNMailAccountManager

static GNMailAccountManager *sharedAccountManager = nil;

+ (GNMailAccountManager *)sharedAccountManager {
	if (sharedAccountManager == nil) {
		sharedAccountManager = [[super alloc] init];	
		
		[[Reachability reachabilityWithHostname:@"mail.google.com"] startNotifier];
		
		// Try to see if a token is stored in the user's keychain
		GTMOAuth2Authentication *potentialAuthentication = [GTMOAuth2WindowController authForGoogleFromKeychainForName:GNOAuth2KeychainItemName clientID:GNOAuth2ClientID clientSecret:GNOAuth2ClientSecret];
		if (potentialAuthentication != nil && [potentialAuthentication canAuthorize]) {
			sharedAccountManager.authentication = potentialAuthentication;
		}
	}
	
	return sharedAccountManager;
}

#pragma mark Authentication Operations

/** Creates a new GTMOAuth2WindowController and handles the response authentication. */
- (void)attemptMailAccountLoginWithWindow:(NSWindow *)windowOrNil {
	GTMOAuth2WindowController *windowController = [[GTMOAuth2WindowController alloc] initWithScope:GNOAuth2Scope clientID:GNOAuth2ClientID clientSecret:GNOAuth2ClientSecret keychainItemName:GNOAuth2KeychainItemName resourceBundle:[NSBundle bundleForClass:[GTMOAuth2WindowController class]]];
	@weakify(self);
	[windowController signInSheetModalForWindow:windowOrNil completionHandler:^(GTMOAuth2Authentication *anAuthentication, NSError *anError) {
		@strongify(self);
		if (anError != nil) {
			if (anError.code == kGTMOAuth2ErrorAuthorizationFailed) {
				NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Access Authorization Failed", @"Showed in error message")
										defaultButton:NSLocalizedString(@"Okay", @"Showed in error message")
									  alternateButton:nil
										  otherButton:nil
							informativeTextWithFormat:NSLocalizedString(@"%@ could not become authorized to access your inbox.  You must allow %@ to view and manage your mail in order to recieve notifications.", @"Showed in error message"), [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"], [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]];
				[alert runModal];
			}
		} else {
			self.authentication = anAuthentication;
		}
	}];
}

/** Deletes the token from the keychain, revokes it, and deletes the current authentication object. */
- (void)attemptMailAccountLogoutAndTokenRevocation {
	[GTMOAuth2WindowController removeAuthFromKeychainForName:GNOAuth2KeychainItemName];
	[GTMOAuth2WindowController revokeTokenForGoogleAuthentication:self.authentication];
	self.authentication = nil;
}

#pragma mark Status Signals

RACMulticastConnection *isReadyConnection;
/** Returns a signal (NSNumber-wrapped BOOL) of whether or not the authentication is valid and ready for requests. */
- (RACSignal *)readySignal {
	if (isReadyConnection == nil) {
		isReadyConnection = [[RACObserve(self, authentication) map:^id(GTMOAuth2Authentication *anAuthentication) {
			return @(anAuthentication != nil && [anAuthentication canAuthorize]);
		}] multicast:[RACReplaySubject replaySubjectWithCapacity:1]];
		[isReadyConnection connect];
	}
	return isReadyConnection.signal;
}

RACMulticastConnection *isReachableConnection;
/** Returns a signal (NSNumber-wrapped BOOL) of whether or not Gmail is reachable. */
- (RACSignal *)reachableSignal {
	if (isReachableConnection == nil) {
		isReachableConnection = [[[[[NSNotificationCenter defaultCenter] rac_addObserverForName:kReachabilityChangedNotification object:nil] takeUntil:[self rac_willDeallocSignal]] map:^id(NSNotification *aNotification) {
			if ([[aNotification object] isReachable])
				return @(YES);
			return @(NO);
		}] multicast:[RACReplaySubject replaySubjectWithCapacity:1]];
		[isReachableConnection connect];
	}
	return isReachableConnection.signal;
}

@end
