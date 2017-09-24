//
//  GNMessageFetchController.m
//  Gmail Notifier
//
//  Created by James Shepherdson on 1/1/13.
//  Copyright (c) 2013 James Shepherdson. All rights reserved.
//

#import "GNMailFetchManager.h"
#import <libextobjc/EXTScope.h>
#import <GTMOAuth2WindowController.h>
#import "GNMailAccountManager.h"

#pragma mark Fetch Manager Private Header

@interface GNMailFetchManager ()

@end

#pragma mark -
#pragma mark Fetch Manager Class Definition

@implementation GNMailFetchManager

- (instancetype)init {
	return [self initWithMessagesSource:@""];
}

- (instancetype)initWithMessagesSource:(NSString *)theMessagesSource {
	self = [super init];
	if (self) {
		self.messagesSource = theMessagesSource;
	}
	return self;
}

#pragma mark Message Fetching

/** Check for new messages and return a signal of GNMailMessage objects. */
- (RACSignal *)checkForNewEmails
{
	if ([GNMailAccountManager sharedAccountManager].authentication != nil &&
        [[GNMailAccountManager sharedAccountManager].authentication canAuthorize])
    {
		RACSignal *reponseSignal = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber)
        {
            GTMSessionFetcher* fetcher = [GTMSessionFetcher fetcherWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[self.messagesSource stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] relativeToURL:[NSURL URLWithString:GNOAuth2ServiceAddress]]]];
			[fetcher setAuthorizer:[GNMailAccountManager sharedAccountManager].authentication];
			[fetcher beginFetchWithCompletionHandler:^(NSData *data, NSError *error) {
				if (!error) {
					NSXMLDocument *response = [[NSXMLDocument alloc] initWithData:data options:NSXMLDocumentTidyXML error:nil];
					for (NSXMLElement *element in [response.rootElement elementsForName:@"entry"]) {
						GNMailMessage *message = [[GNMailMessage alloc] init];
						
						// Try to set the notification date to the message date
						NSDate *messageDate = [NSDate date];
						if ([element elementsForName:@"modified"].count > 0) {
							NSString *dateString = [[element elementsForName:@"modified"][0] stringValue];
							NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
							
							[formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
							[formatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
							[formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
							
							messageDate = [formatter dateFromString:dateString];
						}
						message.dateRecieved = messageDate;
						
						// Try to set the message title to the message's subject line.
						if ([element elementsForName:@"title"].count > 0)
							message.subject = [[element elementsForName:@"title"][0] stringValue];
						
						// Try to set the message author to the message's author and email.
						if ([element elementsForName:@"author"].count > 0) {
							NSString *subtitle = @"";
							BOOL emailParens = NO;
							if ([[element elementsForName:@"author"][0] elementsForName:@"name"].count > 0) {
								subtitle = [[[element elementsForName:@"author"][0] elementsForName:@"name"][0] stringValue];
								emailParens = YES;
							}
							if ([[element elementsForName:@"author"][0] elementsForName:@"email"].count > 0) {
								if (emailParens)
									subtitle = [NSString stringWithFormat:@"%@ (%@)", subtitle, [[[element elementsForName:@"author"][0] elementsForName:@"email"][0] stringValue]];
								else
									subtitle = [[[element elementsForName:@"author"][0] elementsForName:@"email"][0] stringValue];
							}
							message.author = subtitle;
						}
						
						// Try to set the message snippet to the message's summary.
						if ([element elementsForName:@"summary"].count > 0)
							message.snippet = [[element elementsForName:@"summary"][0] stringValue];
						
						// Try to set the message URL to the message's hypertext reference.
						if ([element elementsForName:@"link"].count > 0 && [[element elementsForName:@"link"][0] attributeForName:@"href"])
							message.directURL = [NSURL URLWithString:[[[element elementsForName:@"link"][0] attributeForName:@"href"] stringValue]];
						
						// Try to set the message ID to the message's unique ID.
						if ([element elementsForName:@"id"].count > 0)
							message.uniqueID = [[element elementsForName:@"id"][0] stringValue];
						
						// Add the current notification to the list of potential notifications.
						[subscriber sendNext:message];
					}
					[subscriber sendCompleted];
				} else {
					[subscriber sendError:error];
				}
				
			}];
			return [RACDisposable disposableWithBlock:^{
				[fetcher stopFetching];
			}];
		}];
		return reponseSignal;
	}
	else {
		return [RACSignal empty];
	}
}

@end

#pragma mark -
#pragma mark Mail Message Class Definition

@implementation GNMailMessage

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p> {subject: '%@', author: '%@'}", self.className, self, self.subject, self.author];
}

@end
