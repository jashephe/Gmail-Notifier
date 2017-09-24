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

#pragma mark Keys
extern NSString *const GNMessageURLKey;
extern NSString *const GNMessageIDKey;
extern NSString *const GNMessageFreshnessKey;
extern NSString *const GNPrefsUpdateIntervalKey;
extern NSString *const GNPrefsShowSnippetsKey;
extern NSString *const GNPrefsShowUnreadCount;
extern NSString *const GNPrefsMessagesSourceKey;

#pragma mark Resources
NSImage * defaultStatusIcon();
NSImage * alternateStatusIcon();
NSImage * attentionStatusIcon();
NSImage * errorStatusIcon();
