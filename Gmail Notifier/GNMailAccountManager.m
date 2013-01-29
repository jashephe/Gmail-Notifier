//
//  GNMailAccountManager.m
//  Gmail Notifier
//
//  Created by James Shepherdson on 1/12/13.
//  Copyright (c) 2013 James Shepherdson. All rights reserved.
//

#import "GNMailAccountManager.h"
#import "GNUtils.h"
#import "GNAPIKeys.h"

@implementation GNMailAccountManager

static GNMailAccountManager *sharedAccountManager = nil;

+ (GNMailAccountManager *)sharedAccountManager {
	if (sharedAccountManager == nil) {
		sharedAccountManager = [[super allocWithZone:NULL] init];
		
		// Try to see if a token is stored in the user's keychain
		GTMOAuth2Authentication *potentialAuthentication = [GTMOAuth2WindowController authForGoogleFromKeychainForName:GNOAuth2KeychainItemName clientID:GNOAuth2ClientID clientSecret:GNOAuth2ClientSecret];
		if (potentialAuthentication != nil && [potentialAuthentication canAuthorize]) {
			sharedAccountManager.authentication = potentialAuthentication;
			[[NSNotificationCenter defaultCenter] postNotificationName:GNAuthDidChangeNotification object:self];
		}
	}
	
	return sharedAccountManager;
}

// Creates a new GTMOAuth2WindowController and handles the response.
- (void)attemptMailAccountLoginWithWindow:(NSWindow *)windowOrNil {
	GTMOAuth2WindowController *windowController = [[GTMOAuth2WindowController alloc] initWithScope:GNOAuth2Scope clientID:GNOAuth2ClientID clientSecret:GNOAuth2ClientSecret keychainItemName:GNOAuth2KeychainItemName resourceBundle:[NSBundle bundleForClass:[GTMOAuth2WindowController class]]];
	[windowController signInSheetModalForWindow:windowOrNil completionHandler:^(GTMOAuth2Authentication *anAuthentication, NSError *anError) {
		if (anError != nil) {
			NSAlert *alert = nil;
			if (anError.code == kGTMOAuth2ErrorAuthorizationFailed) {
				alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Access Authorization Failed", @"Showed in error message")
										defaultButton:NSLocalizedString(@"Okay", @"Showed in error message")
									  alternateButton:nil
										  otherButton:nil
							informativeTextWithFormat:@"%@ could not become authorized to access your inbox.  You must allow %@ to view and manage your mail in order to recieve notifications.", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"], [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]];
			}
			if (alert != nil)
				[alert runModal];
		} else {
			self.authentication = anAuthentication;
			[[NSNotificationCenter defaultCenter] postNotificationName:GNAuthDidChangeNotification object:self];
		}
	}];
}

// Deletes the token from the keychain, revokes it, and deletes the current authentication object.
- (void)attemptMailAccountLogoutAndTokenRevocation {
	[GTMOAuth2WindowController removeAuthFromKeychainForName:GNOAuth2KeychainItemName];
	[GTMOAuth2WindowController revokeTokenForGoogleAuthentication:self.authentication];
	self.authentication = nil;
	[[NSNotificationCenter defaultCenter] postNotificationName:GNAuthDidChangeNotification object:self];
}

// Returns whether or not we're fully authorized and ready to start making requests to the inbox feed.
- (BOOL)isReady {
	return self.authentication != nil && [self.authentication canAuthorize];
}

@end
