//
//  GNUIManager.m
//  Gmail Notifier
//
//  Created by James Shepherdson on 12/7/13.
//  Copyright (c) 2013 James Shepherdson. All rights reserved.
//

#import "GNUIManager.h"
#import <libextobjc/EXTScope.h>
#import "GNMailAccountManager.h"
#import "GNMailFetchManager.h"

#pragma mark Constants

static const NSUInteger GNUILoginStatusItemTag = 11;
static const NSUInteger GNUICheckHistoryItemTag = 13;
static const NSUInteger GNUICheckNowItemTag = 15;

#pragma mark -
#pragma mark Private Header

@interface GNUIManager ()
@property (strong) NSStatusItem *statusItem;
@property (strong) GNMailFetchManager *fetchManager;
@property (strong) RACSubject *manualFetchSignal;
@end

#pragma mark -
#pragma mark Class Definition

@implementation GNUIManager

- (id)init {
	self = [super init];
	if (self) {
		[NSUserNotificationCenter defaultUserNotificationCenter].delegate = self;
		self.fetchManager = [[GNMailFetchManager alloc] init];
		self.manualFetchSignal = [RACSubject subject];
		
		self.statusItem = prepareStatusItem();
		self.statusItem.menu = [self prepareStatusMenu];
		
		[self setupSignalProcessing];
	}
	return self;
}

/** Return the current time, formatted as a string in a user-friendly locale. */
NSString * currentTimeString() {
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
	[dateFormatter setDateStyle:NSDateFormatterNoStyle];
	
	NSDate *date = [NSDate date];
	
	[dateFormatter setLocale:[NSLocale currentLocale]];
	
	return [dateFormatter stringFromDate:date];
}

- (void)setupSignalProcessing {
	NSAssert(self.fetchManager != nil, @"Fetch Manager must be initialized before setting up signal processing.");
	
	// Bind the fetch manager's message source to the one set by the defaults key
	RAC(self.fetchManager, messagesSource) = [[NSUserDefaults standardUserDefaults] rac_channelTerminalForKey:GNPrefsMessagesSourceKey];
	
	// A combined signal for whether or not the account manager is both ready and reachable
	RACSignal *readyAndReachable = [[RACSignal combineLatest:@[[[GNMailAccountManager sharedAccountManager] readySignal], [[GNMailAccountManager sharedAccountManager] reachableSignal]]] and];
	
	// A signal (NSNumber-wrapped integer) from the user defaults controller that yields the update interval
	RACSignal *fetchIntervalMonitor = [[NSUserDefaults standardUserDefaults] rac_channelTerminalForKey:GNPrefsUpdateIntervalKey];
	
	// A signal (NSDate) that yields at a periodic interval, and updates to reflect the value from fetchIntervalMonitor
	RACSignal *timedFetchInterval = [[[fetchIntervalMonitor map:^id(NSNumber *interval) {
		return [[RACSignal interval:(interval.integerValue * 60) onScheduler:[RACScheduler mainThreadScheduler] withLeeway:5] startWith:[NSDate date]];
	}] takeUntil:self.rac_willDeallocSignal] switchToLatest];
	
	// A signal (NSDate) that yields both at a period interval described by timeFetchInterval as well as whenever manualFetchSignal is called.
	RACSignal *shouldFetch = [RACSignal merge:@[timedFetchInterval, self.manualFetchSignal]];
	
	@weakify(self);
	
	// A signal of signals (GNMailMessage) that yields the currently unread messages whenever requested by fetchInterval
	// (as long as the authentication is ready and the network is reachable.
	RACSignal *filteredShouldFetch = [RACSignal if:readyAndReachable then:shouldFetch else:[RACSignal empty]];
	RACMulticastConnection *messageConnections = [[filteredShouldFetch map:^id(id _) {
		@strongify(self);
		return [self.fetchManager checkForNewEmails];
	}] publish];
	RACSignal *messageSignals = messageConnections.signal;
	
	[messageSignals subscribeNext:^(RACSignal *messageSignal) {
		NSMutableArray *messages = [[NSMutableArray alloc] init];
		[messageSignal subscribeNext:^(GNMailMessage *aMessage) {
			@strongify(self);
			[messages addObject:aMessage];
			[self sendUserNotificationForMessage:aMessage];
		} completed:^{
			@strongify(self);
			[[self.statusItem.menu itemWithTag:GNUICheckHistoryItemTag] setTitle:[NSString stringWithFormat:NSLocalizedString(@"Last checked at %@", @"Status menu check history"), currentTimeString()]];
			[self reconcileStaleNotifications:messages];
		}];
	}];
	
	// A signal (NSNumber-wrapped Integer) that yields the number of messages that are currently unread
	RACSignal *messageCount = [messageSignals flattenMap:^RACStream *(RACSignal *messageSignal) {
		return [[[messageSignal catchTo:[RACSignal empty]] collect] map:^id(NSArray *messages) {
			return @(messages.count);
		}];
	}];
	
	// Bind the status item's title to the number of unread messages, as long as we're logged in, the network connection is good, and the user wants the count.
	RACSignal *showCount = [[NSUserDefaults standardUserDefaults] rac_channelTerminalForKey:GNPrefsShowUnreadCount];
	RAC(self.statusItem, title) = [RACSignal combineLatest:@[messageCount, readyAndReachable, showCount] reduce:^id(NSString *count, NSNumber *isReadyAndReachable, NSNumber *shouldShowCount) {
		if (isReadyAndReachable.boolValue && shouldShowCount.boolValue && count.integerValue > 0)
			return [NSString stringWithFormat:@"%lu", count.integerValue];
		else
			return @"";
	}];
	
	// Bind the status item's image to whether or not we have unread messages, as long as we're logged in and the network connection is good
	RAC(self.statusItem, image) = [RACSignal combineLatest:@[messageCount, readyAndReachable] reduce:^id(NSString *count, NSNumber *isReadyAndReachable) {
		if (!isReadyAndReachable.boolValue)
			return errorStatusIcon();
		else if (count.integerValue > 0)
			return attentionStatusIcon();
		else
			return defaultStatusIcon();
	}];
	

	// Bind the status menu's login item title to whether or not the account manager is ready.
	RAC([self.statusItem.menu itemWithTag:GNUILoginStatusItemTag], title) = [RACSignal combineLatest:@[[[GNMailAccountManager sharedAccountManager] readySignal], [[GNMailAccountManager sharedAccountManager] reachableSignal]] reduce:^id(NSNumber *isReady, NSNumber *isReachable) {
		if (!isReachable.boolValue) {
			return NSLocalizedString(@"No Network Connection", @"Status menu application state indicator");
		}
		else if (isReady.boolValue) {
			return NSLocalizedString(@"Logged In", @"Status menu application state indicator");
		}
		else {
			return NSLocalizedString(@"Not Logged In", @"Status menu application state indicator");
		}
	}];
	
	// Bind the status menu's login item icon to whether or not the account manager is ready.
	RAC([self.statusItem.menu itemWithTag:GNUILoginStatusItemTag], image) = [RACSignal combineLatest:@[[[GNMailAccountManager sharedAccountManager] readySignal], [[GNMailAccountManager sharedAccountManager] reachableSignal]] reduce:^id(NSNumber *isReady, NSNumber *isReachable) {
		if (!isReachable.boolValue) {
			return fabricateTrafficLightImageOfColor([NSColor redColor]);
		}
		else if (isReady.boolValue) {
			return fabricateTrafficLightImageOfColor([NSColor greenColor]);
		}
		else {
			return fabricateTrafficLightImageOfColor([NSColor blueColor]);
		}
	}];
	
	[messageConnections connect];
}

#pragma mark Status Item

/** Manually fire a signal to request a message check */
- (void)checkForMessagesNow:(id)sender {
	[self.manualFetchSignal sendNext:[NSDate date]];
}

/** Create a status item and set images */
NSStatusItem * prepareStatusItem() {
	NSStatusItem *item = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
	
	[item setImage:defaultStatusIcon()];
    [item setHighlightMode:YES];
	
	return item;
}

/** Fabricate an NSImage in the shape of a small circle of a given color (used as the account state
	indicator for the status menu) */
NSImage * fabricateTrafficLightImageOfColor(NSColor *aColor) {
	NSRect imgRect = NSMakeRect(0.0, 0.0, 9.0, 9.0);
	NSImage *image = [[NSImage alloc] initWithSize:imgRect.size];
	
	NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:imgRect];
	
	[image lockFocus];
	[aColor set];
	[circle fill];
	[image unlockFocus];
	
	return image;
}

/** Create an NSMenu and various menu items to be added to the status item */
- (NSMenu *)prepareStatusMenu {
	NSMenu *menu = [[NSMenu alloc] init];
	
	NSMenuItem *appStateItem = [[NSMenuItem alloc] initWithTitle:@"Account Login Status" action:NULL keyEquivalent:@""];
	[appStateItem setImage:fabricateTrafficLightImageOfColor([NSColor blackColor])];
	[appStateItem setTag:GNUILoginStatusItemTag];
	[menu addItem:appStateItem];
	
	NSMenuItem *checkHistoryItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Never checked", @"Status menu check history") action:NULL keyEquivalent:@""];
	[checkHistoryItem setTag:GNUICheckHistoryItemTag];
	[checkHistoryItem setEnabled:YES];
	[menu addItem:checkHistoryItem];

	NSMenuItem *checkNowItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Check Now", @"Status menu option") action:@selector(checkForMessagesNow:) keyEquivalent:@""];
	[checkNowItem setTarget:self];
	[checkNowItem setTag:GNUICheckNowItemTag];
	[menu addItem:checkNowItem];
	
	[menu addItem:[NSMenuItem separatorItem]];
	
	NSMenuItem *inboxItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Go to Inbox", @"Status menu option") action:@selector(goToInbox) keyEquivalent:@""];
	[inboxItem setTarget:[NSApplication sharedApplication].delegate];
	[menu addItem:inboxItem];
	
	[menu addItem:[NSMenuItem separatorItem]];
	
	NSMenuItem *aboutItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:NSLocalizedString(@"About %@", @"Status menu option"), [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]] action:@selector(showAboutPanel) keyEquivalent:@""];
	[aboutItem setTarget:[NSApplication sharedApplication].delegate];
	[menu addItem:aboutItem];
	
	NSMenuItem *supportItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Support", @"Status menu option") action:NULL keyEquivalent:@""];
	NSMenu *supportMenu = [[NSMenu alloc] init];
	
	NSMenuItem *updateSupportItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Check for Updates", @"Support menu option") action:@selector(checkForUpdate) keyEquivalent:@""];
	[updateSupportItem setTarget:[NSApplication sharedApplication].delegate];
	[supportMenu addItem:updateSupportItem];
	
	NSMenuItem *issueSupportItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"File an Issue", @"Support menu option") action:@selector(reportIssue) keyEquivalent:@""];
	[issueSupportItem setTarget:[NSApplication sharedApplication].delegate];
	[supportMenu addItem:issueSupportItem];
	
	[supportItem setSubmenu:supportMenu];
	[menu addItem:supportItem];
	
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

/** Create a new NSUserNotification, populate it with the properties of the message, and deliver it to the user notification center. */
- (void)sendUserNotificationForMessage:(GNMailMessage *)aMessage {
	if (messageNotificationNotYetDelivered(aMessage)) {
		NSUserNotification *aNotification = [[NSUserNotification alloc] init];
		aNotification.soundName = @"mail_new";
		aNotification.deliveryDate = aMessage.dateRecieved;
		aNotification.title = aMessage.subject;
		aNotification.subtitle = aMessage.author;
		if ([[NSUserDefaults standardUserDefaults] boolForKey:GNPrefsShowSnippetsKey])
			aNotification.informativeText = aMessage.snippet;
		aNotification.userInfo = @{GNMessageURLKey: [aMessage.directURL absoluteString], GNMessageIDKey: aMessage.uniqueID};
		[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:aNotification];
	}
}

/* This is called when a user notification is clicked on in Notification Center.  We want to
	open the URL encoded in the user notification's userInfo attribute, and then remove it from
	Notification Center. */
- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {
	if (notification.userInfo != nil && notification.userInfo[GNMessageURLKey] != nil)
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:notification.userInfo[GNMessageURLKey]]];
}

/* This makes Notification Center display notifications even the app is in the foreground. */
- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification {
	return YES;
}

/** Returns whether or not a message notification has already been sent to the Notification Center.
	Since user notifications persist in the Notification Center after applications have quit, we
	want to check to make sure that we haven't already delivered a message notification during
	a previous app session (e.g. user launches app, new message notification sent, user quits
	app, user relaunches app, message still unread, don't want to send a new notification since
	the old one will still be there) */
BOOL messageNotificationNotYetDelivered(GNMailMessage *theMessage) {
	if ([NSUserNotificationCenter defaultUserNotificationCenter].deliveredNotifications.count == 0)
		return YES;
	if (theMessage.uniqueID == nil)
		return YES;
	for (NSUserNotification *aNotification in [NSUserNotificationCenter defaultUserNotificationCenter].deliveredNotifications)
		if (aNotification.userInfo != nil && aNotification.userInfo[GNMessageIDKey] != nil)
			if ([theMessage.uniqueID isEqual:aNotification.userInfo[GNMessageIDKey]])
				return NO;
	return YES;
}

/** Remove notifications that refer to messages that are no longer unread */
- (void)reconcileStaleNotifications:(NSArray *)freshMessages {
	for (NSUserNotification *aDeliveredNotification in [NSUserNotificationCenter defaultUserNotificationCenter].deliveredNotifications) {
		if (aDeliveredNotification.userInfo != nil && aDeliveredNotification.userInfo[GNMessageIDKey] != nil) {
			BOOL notificationIsFresh = NO;
			for (GNMailMessage *aFreshMessage in freshMessages) {
				if ([aDeliveredNotification.userInfo[GNMessageIDKey] isEqual:aFreshMessage.uniqueID]) {
					notificationIsFresh = YES;
					break;
				}
			}
			if (!notificationIsFresh)
				[[NSUserNotificationCenter defaultUserNotificationCenter] removeDeliveredNotification:aDeliveredNotification];
		}
	}
}


@end
