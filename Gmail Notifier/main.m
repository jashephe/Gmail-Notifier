//
//  main.m
//  Gmail Notifier
//
//  Created by James Shepherdson on 1/1/13.
//  Copyright (c) 2013 James Shepherdson. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GNAppDelegate.h"

int main(int argc, char *argv[]) {
	NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
	Class principalClass = NSClassFromString([infoDictionary objectForKey:@"NSPrincipalClass"]);
	if (![principalClass respondsToSelector:@selector(sharedApplication)]) {
		NSLog(@"Principal class must implement sharedApplication.");
		return EXIT_FAILURE;
	}
	NSApplication *application = [principalClass sharedApplication];
	
	GNAppDelegate *appDelegate = [[GNAppDelegate alloc] init];
	
	[application setDelegate:appDelegate];
	if ([application respondsToSelector:@selector(run)]) {
		[application performSelectorOnMainThread:@selector(run) withObject:nil waitUntilDone:YES];
	}
	
	return EXIT_SUCCESS;
}
