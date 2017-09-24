//
//  GNMessageFetchController.h
//  Gmail Notifier
//
//  Created by James Shepherdson on 1/1/13.
//  Copyright (c) 2013 James Shepherdson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

@interface GNMailFetchManager : NSObject

/** The last path component of the URL to query for new messages. */
@property NSString *messagesSource;

- (instancetype)initWithMessagesSource:(NSString *)theMessagesSource;

#pragma mark Message Fetching
- (RACSignal *)checkForNewEmails;

@end

#pragma mark -
#pragma mark Mail Message

@interface GNMailMessage : NSObject

/** The date and time that the message was recieved in Gmail */
@property NSDate *dateRecieved;
/** The subject of the message */
@property NSString *subject;
/** The message author and/or author's email */
@property NSString *author;
/** A snippet of the message */
@property NSString *snippet;
/** A URL that can be used to open the message in Gmail in a browser */
@property NSURL *directURL;
/** A unique ID assigned to the message by Gmail */
@property NSString *uniqueID;

@end
