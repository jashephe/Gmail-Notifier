//
//  GNUtils.m
//  Gmail Notifier
//
//  Created by James Shepherdson on 1/12/13.
//  Copyright (c) 2013 James Shepherdson. All rights reserved.
//

#import "GNUtils.h"

#pragma mark OAuth2 and API
NSString *const GNOAuth2ServiceAddress = @"https://mail.google.com/mail/feed/atom/";
NSString *const GNOAuth2Scope = @"https://mail.google.com/mail/feed/atom/";
NSString *const GNOAuth2KeychainItemName = @"Gmail Notifier OAuth2";

#pragma mark Notifications
NSString *const GNAuthDidChangeNotification = @"notification.authDidChange";

#pragma mark Keys
NSString *const GNMessageURLKey = @"key.messageURL";
NSString *const GNMessageIDKey = @"key.messageID";
NSString *const GNLastCheckedKey = @"key.lastChecked";
NSString *const GNPrefsRefreshIntervalKey = @"prefs.refreshInterval";
NSString *const GNPrefsShowSnippetsKey = @"prefs.showSnippets";
NSString *const GNPrefsShowUnreadCountInStatusItemKey = @"prefs.showUnreadCount";
NSString *const GNPrefsOnlyShowNewMessagesKey = @"prefs.onlyNewMessages";

#pragma mark Resources

#define STATUS_ICON_IMAGE_SIZE NSMakeSize(20, 14)

NSImage * defaultStatusIcon() {
	NSImage *icon = [NSImage imageNamed:@"mail"];
	[icon setSize:STATUS_ICON_IMAGE_SIZE];
	return icon;
}

NSImage * alternateStatusIcon() {
	NSImage *icon = [NSImage imageNamed:@"mail_alt"];
	[icon setSize:STATUS_ICON_IMAGE_SIZE];
	return icon;
}

NSImage * attentionStatusIcon() {
	NSImage *icon = [NSImage imageNamed:@"mail_new"];
	[icon setSize:STATUS_ICON_IMAGE_SIZE];
	return icon;
}

NSImage * errorStatusIcon() {
	NSImage *icon = [NSImage imageNamed:@"mail_error"];
	[icon setSize:STATUS_ICON_IMAGE_SIZE];
	return icon;
}
