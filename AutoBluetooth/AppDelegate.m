//
//  AppDelegate.m
//  AutoBluetooth
//
//  Created by Kyle Sluder on 5/18/14.
//  Copyright (c) 2014 Kyle Sluder. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate () <NSUserNotificationCenterDelegate>
@end

@implementation AppDelegate

#pragma mark - Display configuration

static void _displaysReconfigured(CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags, void *userInfo)
{
    [[NSRunLoop currentRunLoop] cancelPerformSelector:@selector(_handleDisplaysReconfigured:) target:[NSApp delegate] argument:nil];
    [[NSApp delegate] performSelector:@selector(_handleDisplaysReconfigured:) withObject:nil afterDelay:0];
}

- (void)_handleDisplaysReconfigured:(id)unused;
{
    uint32_t externalDisplayCount = 0;
    
    static const uint32_t MaxDisplayCount = 256;
    CGDirectDisplayID onlineDisplayIDs[MaxDisplayCount];
    uint32_t onlineDisplayIDCount;
    CGGetOnlineDisplayList(MaxDisplayCount, onlineDisplayIDs, &onlineDisplayIDCount);
    for (uint32_t i = 0; i < onlineDisplayIDCount; i++) {
        if (!CGDisplayIsBuiltin(onlineDisplayIDs[i]))
            externalDisplayCount++;
    }
    
    [self _displayBluetoothBalloon:externalDisplayCount > 0];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    
    // Register the callback _first_, so that events get enqueued for any display configuration changes that happen while we're processing the initial display configuration.
    CGError registrationError = CGDisplayRegisterReconfigurationCallback(_displaysReconfigured, NULL);
    if (registrationError != kCGErrorSuccess) {
        NSAlert *failureAlert = [NSAlert alertWithMessageText:NSLocalizedString(@"Could not register display configuration callback.", @"error message") defaultButton:NSLocalizedString(@"Quit", @"error button") alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedString(@"Received error %ld. %@ will now quit.", @"error informative text"), registrationError, NSApp];
        [failureAlert runModal];
        [NSApp terminate:nil];
    }
    
    // Turn Bluetooth on or off based on the initial display configuration. Delay-performed so it gets coalesced with any incoming notifications that happen while we finish launching. (Let's not turn radios on and off unnecessarily.)
    [self performSelector:@selector(_handleDisplaysReconfigured:) withObject:nil afterDelay:0];
}

- (void)applicationWillTerminate:(NSNotification *)notification;
{
    CGDisplayRemoveReconfigurationCallback(_displaysReconfigured, NULL);
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:nil];
}

#pragma mark - Notification balloons

static NSString *const NotificationCookie = @"hello, world!";
static NSString *const NotificationCookieKey = @"com.ksluder.AutoBluetooth.BluetoothBalloonCookie";

- (void)_displayBluetoothBalloon:(BOOL)bluetoothEnabled;
{
    NSUserNotification *notification = [NSUserNotification new];
    notification.userInfo = @{NotificationCookieKey : NotificationCookie};
    
    if (bluetoothEnabled) {
        notification.title = NSLocalizedString(@"Bluetooth enabled", @"notification title");
        notification.informativeText = NSLocalizedString(@"Bluetooth has been enabled because this computer was connected to an external display.", @"notification informative text");
    } else {
        notification.title = NSLocalizedString(@"Bluetooth disabled", @"notification title");
        notification.informativeText = NSLocalizedString(@"Bluetooth has been disabled because this computer was disconnected from all external displays.", @"notification informative text");
    }
    
    NSUserNotificationCenter *center = [NSUserNotificationCenter defaultUserNotificationCenter];
    for (NSUserNotification *existingNotification in center.deliveredNotifications) {
        if ([existingNotification.userInfo objectForKey:NotificationCookieKey] != nil)
            [center removeDeliveredNotification:existingNotification];
    }
    
    [center deliverNotification:notification];
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification;
{
    NSAssert([[notification.userInfo objectForKey:NotificationCookieKey] isEqual:NotificationCookie], @"Asked about a notification we didn't enqueue!");
    
    return YES;
}

@end
