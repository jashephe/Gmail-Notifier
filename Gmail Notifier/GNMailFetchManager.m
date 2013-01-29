//
//  GNMessageFetchController.m
//  Gmail Notifier
//
//  Created by James Shepherdson on 1/1/13.
//  Copyright (c) 2013 James Shepherdson. All rights reserved.
//

#import "GNMailFetchManager.h"
#import "GNMailAccountManager.h"
#import "GNUtils.h"
#import "GNAPIKeys.h"
#import "NSObject+BlockObservation.h"

@interface GNMailFetchManager ()

@property (strong) NSStatusItem *statusItem;
@property GTMOAuth2Authentication *possibleAuth;
@property NSTimer *mailCheckTimer;
@property NSDate *creationTime;
@end

@implementation GNMailFetchManager

- (id)init {
	self = [super init];
	if (self) {
		[NSUserNotificationCenter defaultUserNotificationCenter].delegate = self;
		
		self.creationTime = [NSDate date];
		
		self.statusItem = prepareStatusItem();
		self.statusItem.menu = fabricateStatusMenu();
		
		// Check once, and then register for authorization changes
		[self respondToAccountStateChange];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(respondToAccountStateChange) name:GNAuthDidChangeNotification object:nil];
		
		// If the refresh interval changes is preferences, we want to update the timer, if necessary.
		__block GNMailFetchManager *weakSelf = self;
		[[NSUserDefaultsController sharedUserDefaultsController] addObserverForKeyPath:[@"values." stringByAppendingString:GNPrefsRefreshIntervalKey] options:NSKeyValueObservingOptionNew task:^(id obj, NSDictionary *change) {
			if (weakSelf.mailCheckTimer != nil && [weakSelf.mailCheckTimer isValid]) {
				[weakSelf.mailCheckTimer invalidate];
				NSInteger refreshRate = [[NSUserDefaults standardUserDefaults] integerForKey:GNPrefsRefreshIntervalKey];
				weakSelf.mailCheckTimer = [NSTimer scheduledTimerWithTimeInterval:60*refreshRate target:self selector:@selector(checkForNewEmails) userInfo:nil repeats:YES];
			}
		}];
		
		// If the user changes whether or not they want the message counter in the menu bar, check
		// for messages (which will automatically show or hide the counter if needed).
		[[NSUserDefaultsController sharedUserDefaultsController] addObserverForKeyPath:[@"values." stringByAppendingString:GNPrefsShowUnreadCountInStatusItemKey] options:NSKeyValueObservingOptionNew task:^(id obj, NSDictionary *change) {
			[self checkForNewEmails];
		}];
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark Account Handling
- (void)respondToAccountStateChange {
	if ([[GNMailAccountManager sharedAccountManager] isReady]) {
		[self.statusItem.menu.itemArray[0] setTitle:NSLocalizedString(@"Logged In", @"Status menu application state indicator")];
		[self.statusItem.menu.itemArray[0] setImage:trafficLight([NSColor greenColor])];
		
		NSMenuItem *checkNowItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Check now", @"Status menu option") action:@selector(checkForNewEmails) keyEquivalent:@""];
		[checkNowItem setTarget:self];
		[checkNowItem setTag:3];
		[self.statusItem.menu insertItem:checkNowItem atIndex:2];
		
		if (self.mailCheckTimer == nil || ![self.mailCheckTimer isValid]) {
			[self checkForNewEmails];
			NSInteger refreshRate = [[NSUserDefaults standardUserDefaults] integerForKey:GNPrefsRefreshIntervalKey];
			self.mailCheckTimer = [NSTimer scheduledTimerWithTimeInterval:60*refreshRate target:self selector:@selector(checkForNewEmails) userInfo:nil repeats:YES];
		}
	}
	else {
		[self.statusItem setImage:errorStatusIcon()];
		self.statusItem.title = @"";
		[self.statusItem.menu.itemArray[0] setTitle:NSLocalizedString(@"Not Logged In", @"Status menu application state indicator")];
		[self.statusItem.menu.itemArray[0] setImage:trafficLight([NSColor redColor])];
		
		if(((NSMenuItem *)self.statusItem.menu.itemArray[2]).tag == 3)
			[self.statusItem.menu removeItemAtIndex:2];
		
		if (self.mailCheckTimer != nil) {
			[self.mailCheckTimer invalidate];
			self.mailCheckTimer = nil;
		}
	}
}

NSString * currentTimeString() {
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
	[dateFormatter setDateStyle:NSDateFormatterNoStyle];
	
	NSDate *date = [NSDate date];
	
	[dateFormatter setLocale:[NSLocale currentLocale]];
	
	return [dateFormatter stringFromDate:date];
}

- (void)checkForNewEmails {
	if ([[GNMailAccountManager sharedAccountManager] isReady]) {
		[self.statusItem.menu.itemArray[1] setTitle:[NSString stringWithFormat:@"Last checked at: %@", currentTimeString()]];
		
		NSURL *url = [NSURL URLWithString:GNOAuth2ServiceAddress];
		NSURLRequest *request = [NSURLRequest requestWithURL:url];
		GTMHTTPFetcher* fetcher = [GTMHTTPFetcher fetcherWithRequest:request];
		[fetcher setAuthorizer:[GNMailAccountManager sharedAccountManager].authentication];
		[fetcher beginFetchWithCompletionHandler:^(NSData *data, NSError *error) {
			if (!error) {
				NSXMLDocument *response = [[NSXMLDocument alloc] initWithData:data options:NSXMLDocumentTidyXML error:nil];
				
				int numMessages = [[[response.rootElement elementsForName:@"fullcount"][0] stringValue] intValue];
				if (numMessages == 0) {
					self.statusItem.title = @"";
					[self.statusItem setImage:defaultStatusIcon()];
				}
				else {
					if ([[NSUserDefaults standardUserDefaults] boolForKey:GNPrefsShowUnreadCountInStatusItemKey])
						self.statusItem.title = [NSString stringWithFormat:@"%i", numMessages];
					else
						self.statusItem.title = @"";
					[self.statusItem setImage:attentionStatusIcon()];
					
					for (NSXMLElement *element in [response.rootElement elementsForName:@"entry"]) {
						NSUserNotification *notification = [[NSUserNotification alloc] init];
						notification.soundName = @"mail_new";
						
						// If the user only wants to see new messages, get the message modification date, and compare it to the one
						// created at launch.
						if ([[NSUserDefaults standardUserDefaults] boolForKey:GNPrefsOnlyShowNewMessagesKey] && [element elementsForName:@"modified"].count > 0) {
							NSString *dateString = [[element elementsForName:@"modified"][0] stringValue];
							NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
							
							[formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
							[formatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
							[formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
							
							NSDate *messageDate = [formatter dateFromString:dateString];
							if ([self.creationTime compare:messageDate] != NSOrderedAscending)
								break;
						}
						
						if ([element elementsForName:@"title"].count > 0)
							notification.title = [[element elementsForName:@"title"][0] stringValue];
						
						// If the user doesn't want snippets, don't set any informative text.
						if ([[NSUserDefaults standardUserDefaults] boolForKey:GNPrefsShowSnippetsKey] && [element elementsForName:@"summary"].count > 0)
							notification.informativeText = [[element elementsForName:@"summary"][0] stringValue];
						
						NSString *messageURL = @"";
						if ([element elementsForName:@"link"].count > 0)
							messageURL = [[[element elementsForName:@"link"][0] attributeForName:@"href"] stringValue];
						
						NSString *messageID = @"";
						if ([element elementsForName:@"id"].count > 0)
							messageID = [[element elementsForName:@"id"][0] stringValue];
						
						notification.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:messageID, GNMessageIDKey, messageURL, GNMessageURLKey, nil];
						
						if (mailNotificationNotYetDelivered(notification))
							[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
					}
				}
			}
		}];
	}
}
	
#pragma mark Status Item

// Create a status item and set images
NSStatusItem * prepareStatusItem() {
	// Create system menu item
	NSStatusItem *item = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
	
	// Set default and highlighted images, allow highlighting
	[item setImage:defaultStatusIcon()];
	[item setAlternateImage:alternateStatusIcon()];
    [item setHighlightMode:YES];
	
	return item;
}

// Create an NSImage in the shape of a small circle of a given color (used as the account state indicator
// for the status menu)
NSImage * trafficLight(NSColor *aColor) {
	NSRect imgRect = NSMakeRect(0.0, 0.0, 9.0, 9.0);
	NSImage *image = [[NSImage alloc] initWithSize:imgRect.size];
	
	NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:imgRect];
	
	[image lockFocus];
	[aColor set];
	[circle fill];
	[image unlockFocus];
	
	return image;
}

// Create an NSMenu and various menu items to be added to the status item
NSMenu * fabricateStatusMenu() {
	NSMenu *menu = [[NSMenu alloc] init];
	
	NSMenuItem *appStateItem = [[NSMenuItem alloc] initWithTitle:@"Account Login Status" action:NULL keyEquivalent:@""];
	[appStateItem setImage:trafficLight([NSColor redColor])];
	[menu addItem:appStateItem];
	
	NSMenuItem *checkHistoryItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Never checked", @"Status menu check history") action:NULL keyEquivalent:@""];
	[menu addItem:checkHistoryItem];
	
	[menu addItem:[NSMenuItem separatorItem]];
	
	NSMenuItem *inboxItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Go to inbox", @"Status menu option") action:@selector(goToInbox) keyEquivalent:@""];
	[inboxItem setTarget:[NSApplication sharedApplication].delegate];
	[menu addItem:inboxItem];
	
	[menu addItem:[NSMenuItem separatorItem]];
	
	NSMenuItem *aboutItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:NSLocalizedString(@"About %@", @"Status menu option"), [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]] action:@selector(showAboutPanel) keyEquivalent:@""];
	[aboutItem setTarget:[NSApplication sharedApplication].delegate];
	[menu addItem:aboutItem];
	
	NSMenuItem *prefsItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Preferences", @"Status menu option and Window Title") action:@selector(showPreferences) keyEquivalent:@""];
	[prefsItem setTarget:[NSApplication sharedApplication].delegate];
	[menu addItem:prefsItem];
	
	[menu addItem:[NSMenuItem separatorItem]];
	
	NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Quit %@", @"Status menu option"), [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]] action:@selector(quit) keyEquivalent:@""];
	[quitItem setTarget:[NSApplication sharedApplication].delegate];
	[menu addItem:quitItem];
	
	return menu;
}

#pragma mark User Notification Center Management

// This is called when a user notification is clicked on in Notification Center.  We want to
// open the URL encoded in the user notification's userInfo attribute, and then remove it from
// Notification Center.
- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {
	//TODO:  Remove counter from status item
	//FIXME:  Not called when application launched from a notification...
	if (notification.userInfo != nil && notification.userInfo[GNMessageURLKey] != nil)
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:notification.userInfo[GNMessageURLKey]]];
	[center removeDeliveredNotification:notification];
}

// This makes Notification Center display notifications even if we're in the foreground.
- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification{
	return YES;
}

// Since user notifications persist in the Notification Center after applications have quit, we
// want to check to make sure that we haven't already delivered a message notification during
// a previous app session (e.g. user launches app, new message notification sent, user quits
// app, user relaunches app, message still unread, don't want to send a new notification since
// the old one will still be there)
BOOL mailNotificationNotYetDelivered(NSUserNotification *theNotification) {
	if ([NSUserNotificationCenter defaultUserNotificationCenter].deliveredNotifications.count == 0)
		return YES;
	if (theNotification.userInfo == nil)
		return YES;
	if (theNotification.userInfo[GNMessageIDKey] == nil)
		return YES;
	for (NSUserNotification *aNotification in [NSUserNotificationCenter defaultUserNotificationCenter].deliveredNotifications)
		if (aNotification.userInfo != nil && aNotification.userInfo[GNMessageIDKey] != nil)
			if ([theNotification.userInfo[GNMessageIDKey] isEqual:aNotification.userInfo[GNMessageIDKey]])
				return NO;
	return YES;
}

@end
