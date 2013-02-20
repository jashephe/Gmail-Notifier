//
//  GNUtils.h
//  Gmail Notifier
//
//  Created by James Shepherdson on 1/12/13.
//  Copyright (c) 2013 James Shepherdson. All rights reserved.
//

#pragma mark OAuth2 and API
extern NSString *const GNOAuth2ServiceAddress;
extern NSString *const GNOAuth2Scope;
extern NSString *const GNOAuth2KeychainItemName;

#pragma mark Notifications
extern NSString *const GNAuthDidChangeNotification;

#pragma mark Keys
extern NSString *const GNMessageURLKey;
extern NSString *const GNMessageIDKey;
extern NSString *const GNPrefsRefreshIntervalKey;
extern NSString *const GNPrefsShowSnippetsKey;
extern NSString *const GNPrefsShowUnreadCountInStatusItemKey;
extern NSString *const GNPrefsOnlyShowNewMessagesKey;

#pragma mark Resources
NSImage * defaultStatusIcon();
NSImage * alternateStatusIcon();
NSImage * attentionStatusIcon();
NSImage * errorStatusIcon();
