// SPDX-License-Identifier: GPL-3.0-or-later
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <UserNotifications/UserNotifications.h>
#import <objc/runtime.h>
#include "mac_notifications.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// Swizzle NSBundle.bundleIdentifier if running outside .app bundle so Cocoa notifications never fail
@implementation NSBundle (MacLinkBundleIdentifier)
- (NSString *)__maclink_bundleIdentifier {
    NSString *bundleId = [self __maclink_bundleIdentifier];
    if (bundleId != nil && bundleId.length > 0) {
        return bundleId;
    }
    return @"in.maclink.srv";
}
@end

static void ensure_bundle_identifier(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if ([NSBundle mainBundle].bundleIdentifier == nil) {
            Method origMethod = class_getInstanceMethod([NSBundle class], @selector(bundleIdentifier));
            Method swizzledMethod = class_getInstanceMethod([NSBundle class], @selector(__maclink_bundleIdentifier));
            if (origMethod && swizzledMethod) {
                method_exchangeImplementations(origMethod, swizzledMethod);
            }
        }
    });
}

// ---------------------------------------------------------------------------
// Modern macOS 10.14+ UserNotifications (UNUserNotificationCenter)
// ---------------------------------------------------------------------------
API_AVAILABLE(macos(10.14))
@interface MacUNNotificationDelegate : NSObject <UNUserNotificationCenterDelegate>
@property (nonatomic, assign) MacNotificationCallback callback;
@end

@implementation MacUNNotificationDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    // Ensure notifications always present as banners even when MacLink is frontmost/active.
    UNNotificationPresentationOptions opts = UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionSound | UNNotificationPresentationOptionList;
    completionHandler(opts);
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler {
    if (!self.callback) {
        completionHandler();
        return;
    }
    
    NSDictionary *userInfo = response.notification.request.content.userInfo;
    NSString *device = userInfo[@"device"] ?: @"";
    NSString *key = userInfo[@"key"] ?: @"";
    
    if ([response isKindOfClass:[UNTextInputNotificationResponse class]]) {
        UNTextInputNotificationResponse *textResp = (UNTextInputNotificationResponse *)response;
        NSString *replyAction = userInfo[@"reply_action"] ?: response.actionIdentifier ?: @"";
        NSString *text = textResp.userText ?: @"";
        self.callback("reply", device.UTF8String, key.UTF8String, replyAction.UTF8String, text.UTF8String);
    } else if ([response.actionIdentifier isEqualToString:UNNotificationDefaultActionIdentifier]) {
        self.callback("opened", device.UTF8String, key.UTF8String, "", "");
    } else if ([response.actionIdentifier isEqualToString:UNNotificationDismissActionIdentifier]) {
        self.callback("dismissed", device.UTF8String, key.UTF8String, "", "");
    } else {
        self.callback("action", device.UTF8String, key.UTF8String, response.actionIdentifier.UTF8String, "");
    }
    completionHandler();
}

@end

// ---------------------------------------------------------------------------
// Legacy macOS NSUserNotificationCenter fallback
// ---------------------------------------------------------------------------
@interface MacNotificationDelegate : NSObject <NSUserNotificationCenterDelegate>
@property (nonatomic, assign) MacNotificationCallback callback;
@end

@implementation MacNotificationDelegate

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification {
    return YES;
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {
    if (!self.callback) return;
    
    NSString *device = notification.userInfo[@"device"] ?: @"";
    NSString *key = notification.userInfo[@"key"] ?: @"";
    
    switch (notification.activationType) {
        case NSUserNotificationActivationTypeContentsClicked: {
            self.callback("opened", device.UTF8String, key.UTF8String, "", "");
            break;
        }
        case NSUserNotificationActivationTypeActionButtonClicked: {
            NSString *action = notification.userInfo[@"primary_action"] ?: @"";
            self.callback("action", device.UTF8String, key.UTF8String, action.UTF8String, "");
            break;
        }
        case NSUserNotificationActivationTypeReplied: {
            NSString *replyAction = notification.userInfo[@"reply_action"] ?: @"";
            NSString *text = notification.response.string ?: @"";
            self.callback("reply", device.UTF8String, key.UTF8String, replyAction.UTF8String, text.UTF8String);
            break;
        }
        case NSUserNotificationActivationTypeAdditionalActionClicked: {
            if (notification.additionalActivationAction) {
                NSString *action = notification.additionalActivationAction.identifier ?: @"";
                self.callback("action", device.UTF8String, key.UTF8String, action.UTF8String, "");
            }
            break;
        }
        default:
            break;
    }
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didDismissNotification:(NSUserNotification *)notification {
    if (!self.callback) return;
    NSString *device = notification.userInfo[@"device"] ?: @"";
    NSString *key = notification.userInfo[@"key"] ?: @"";
    self.callback("dismissed", device.UTF8String, key.UTF8String, "", "");
}

@end

static MacUNNotificationDelegate *s_un_delegate = nil;
static MacNotificationDelegate *s_ns_delegate = nil;

static void deliver_via_ns_user_notification(
    NSString *targetId,
    const char *title,
    const char *subtitle,
    const char *body,
    const char *icon_path,
    const char *image_path,
    bool silent,
    bool has_reply,
    const char *reply_id,
    const char *reply_title,
    int action_count,
    const char *const *action_ids,
    const char *const *action_titles,
    NSDictionary *userInfo
) {
    NSUserNotification *notif = [[NSUserNotification alloc] init];
    notif.identifier = targetId;
    if (title && strlen(title) > 0) {
        notif.title = [NSString stringWithUTF8String:title];
    }
    if (subtitle && strlen(subtitle) > 0) {
        notif.subtitle = [NSString stringWithUTF8String:subtitle];
    }
    if (body && strlen(body) > 0) {
        notif.informativeText = [NSString stringWithUTF8String:body];
    }
    if (silent) {
        notif.soundName = nil;
    } else {
        notif.soundName = NSUserNotificationDefaultSoundName;
    }

    // Set _identityImage: This is the key Cocoa property that replaces the application
    // bundle icon on the left of the notification banner with the phone app's icon or contact avatar!
    if (icon_path && strlen(icon_path) > 0) {
        NSString *iconFile = [NSString stringWithUTF8String:icon_path];
        if ([[NSFileManager defaultManager] fileExistsAtPath:iconFile]) {
            NSImage *iconImg = [[NSImage alloc] initWithContentsOfFile:iconFile];
            if (iconImg) {
                @try {
                    [notif setValue:iconImg forKey:@"_identityImage"];
                    [notif setValue:@YES forKey:@"_identityImageHasBorder"];
                    [notif setValue:@(0) forKey:@"_identityImageStyle"]; // 0 = standard / rounded square
                } @catch (NSException *e) {
                    NSLog(@"[MacLink] Could not set _identityImage: %@", e);
                }
            }
        }
    }

    // Set contentImage: this is the attached picture (e.g. photo in message or big picture)
    // which appears on the right side of the notification banner.
    if (image_path && strlen(image_path) > 0) {
        NSString *imageFile = [NSString stringWithUTF8String:image_path];
        if ([[NSFileManager defaultManager] fileExistsAtPath:imageFile]) {
            NSImage *img = [[NSImage alloc] initWithContentsOfFile:imageFile];
            if (img) {
                notif.contentImage = img;
            }
        }
    }

    NSMutableDictionary *infoCopy = [userInfo mutableCopy];
    if (has_reply) {
        notif.hasReplyButton = YES;
        if (reply_title && strlen(reply_title) > 0) {
            notif.responsePlaceholder = [NSString stringWithUTF8String:reply_title];
        } else {
            notif.responsePlaceholder = @"Type a message...";
        }
        if (reply_id && strlen(reply_id) > 0) {
            infoCopy[@"reply_action"] = [NSString stringWithUTF8String:reply_id];
        }
    } else if (action_count > 0 && action_ids && action_titles) {
        notif.hasActionButton = YES;
        notif.actionButtonTitle = [NSString stringWithUTF8String:action_titles[0]];
        infoCopy[@"primary_action"] = [NSString stringWithUTF8String:action_ids[0]];

        if (action_count > 1) {
            NSMutableArray *moreActions = [NSMutableArray array];
            for (int i = 1; i < action_count; i++) {
                NSString *actId = [NSString stringWithUTF8String:action_ids[i]];
                NSString *actTitle = [NSString stringWithUTF8String:action_titles[i]];
                NSUserNotificationAction *action = [NSUserNotificationAction actionWithIdentifier:actId title:actTitle];
                [moreActions addObject:action];
            }
            notif.additionalActions = moreActions;
        }
    } else {
        // Default action button: "Show" (matching native macOS companion look)
        notif.hasActionButton = YES;
        notif.actionButtonTitle = @"Show";
        infoCopy[@"primary_action"] = @"open";
    }

    @try {
        [notif setValue:@YES forKey:@"_showsButtons"];
    } @catch (NSException *e) {}

    notif.userInfo = infoCopy;
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notif];
}

extern "C" {

void mac_notification_start(const char *app_icon_path, MacNotificationCallback callback) {
    (void)app_icon_path;
    @autoreleasepool {
        ensure_bundle_identifier();
        
        if (@available(macOS 10.14, *)) {
            @try {
                s_un_delegate = [[MacUNNotificationDelegate alloc] init];
                s_un_delegate.callback = callback;
                UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
                center.delegate = s_un_delegate;
                [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge)
                                      completionHandler:^(BOOL granted, NSError * _Nullable error) {
                    (void)granted;
                    (void)error;
                }];
            } @catch (NSException *e) {
                // When running outside an application bundle, UNUserNotificationCenter is not available
            }
        }
        
        s_ns_delegate = [[MacNotificationDelegate alloc] init];
        s_ns_delegate.callback = callback;
        [NSUserNotificationCenter defaultUserNotificationCenter].delegate = s_ns_delegate;
    }
}

void mac_notification_show(
    const char *device,
    const char *key,
    const char *title,
    const char *subtitle,
    const char *body,
    const char *icon_path,
    const char *image_path,
    bool silent,
    bool has_reply,
    const char *reply_id,
    const char *reply_title,
    int action_count,
    const char *const *action_ids,
    const char *const *action_titles
) {
    @autoreleasepool {
        ensure_bundle_identifier();
        
        NSString *targetId = [NSString stringWithFormat:@"%s:%s", device, key];
        
        // Resolve image or app icon
        NSString *imageFile = nil;
        if (icon_path && strlen(icon_path) > 0) {
            imageFile = [NSString stringWithUTF8String:icon_path];
        } else if (image_path && strlen(image_path) > 0) {
            imageFile = [NSString stringWithUTF8String:image_path];
        }

        NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
        userInfo[@"device"] = [NSString stringWithUTF8String:device];
        userInfo[@"key"] = [NSString stringWithUTF8String:key];

        // If an app icon or sender avatar is provided, deliver via NSUserNotificationCenter
        // with _identityImage so macOS displays the mirrored app's icon on the left
        // rather than the host MacLink bundle icon.
        if (icon_path && strlen(icon_path) > 0) {
            deliver_via_ns_user_notification(targetId, title, subtitle, body, icon_path, image_path, silent, has_reply, reply_id, reply_title, action_count, action_ids, action_titles, userInfo);
            return;
        }

        // Deliver via UNUserNotificationCenter on modern macOS (for internal MacLink notices)
        if (@available(macOS 10.14, *)) {
            @try {
                UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
                if (title && strlen(title) > 0) {
                    content.title = [NSString stringWithUTF8String:title];
                }
                if (subtitle && strlen(subtitle) > 0) {
                    content.subtitle = [NSString stringWithUTF8String:subtitle];
                }
                if (body && strlen(body) > 0) {
                    content.body = [NSString stringWithUTF8String:body];
                }
                if (silent) {
                    content.sound = nil;
                } else {
                    content.sound = [UNNotificationSound defaultSound];
                }

                if (imageFile && [[NSFileManager defaultManager] fileExistsAtPath:imageFile]) {
                    NSURL *fileUrl = [NSURL fileURLWithPath:imageFile];
                    NSError *attErr = nil;
                    UNNotificationAttachment *attachment = [UNNotificationAttachment attachmentWithIdentifier:@"icon" URL:fileUrl options:nil error:&attErr];
                    if (attachment) {
                        content.attachments = @[attachment];
                    }
                }

                NSString *categoryId = [NSString stringWithFormat:@"cat_%s_%s", device, key];
                NSMutableArray<UNNotificationAction *> *unActions = [NSMutableArray array];

                if (has_reply) {
                    NSString *replyIdStr = (reply_id && strlen(reply_id) > 0) ? [NSString stringWithUTF8String:reply_id] : @"reply";
                    NSString *replyTitleStr = (reply_title && strlen(reply_title) > 0) ? [NSString stringWithUTF8String:reply_title] : @"Reply";
                    userInfo[@"reply_action"] = replyIdStr;
                    UNTextInputNotificationAction *replyAction = [UNTextInputNotificationAction actionWithIdentifier:replyIdStr
                                                                                                               title:replyTitleStr
                                                                                                             options:UNNotificationActionOptionNone
                                                                                                textInputButtonTitle:@"Send"
                                                                                                textInputPlaceholder:@"Type a message..."];
                    [unActions addObject:replyAction];
                } else if (action_count > 0 && action_ids && action_titles) {
                    userInfo[@"primary_action"] = [NSString stringWithUTF8String:action_ids[0]];
                    for (int i = 0; i < action_count; i++) {
                        NSString *actId = [NSString stringWithUTF8String:action_ids[i]];
                        NSString *actTitle = [NSString stringWithUTF8String:action_titles[i]];
                        UNNotificationAction *action = [UNNotificationAction actionWithIdentifier:actId
                                                                                            title:actTitle
                                                                                          options:UNNotificationActionOptionForeground];
                        [unActions addObject:action];
                    }
                }

                if (unActions.count > 0) {
                    UNNotificationCategory *category = [UNNotificationCategory categoryWithIdentifier:categoryId
                                                                                               actions:unActions
                                                                                     intentIdentifiers:@[]
                                                                                               options:UNNotificationCategoryOptionCustomDismissAction];
                    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
                    [center setNotificationCategories:[NSSet setWithObject:category]];
                    content.categoryIdentifier = categoryId;
                }

                content.userInfo = userInfo;

                UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:targetId content:content trigger:nil];
                [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
                    if (error) {
                        // Fallback to NSUserNotificationCenter if UNUserNotificationCenter encounters an issue
                        deliver_via_ns_user_notification(targetId, title, subtitle, body, icon_path, image_path, silent, has_reply, reply_id, reply_title, action_count, action_ids, action_titles, userInfo);
                    }
                }];
                return;
            } @catch (NSException *e) {
                // Fall through to NSUserNotificationCenter
            }
        }

        // Fallback for older macOS
        deliver_via_ns_user_notification(targetId, title, subtitle, body, icon_path, image_path, silent, has_reply, reply_id, reply_title, action_count, action_ids, action_titles, userInfo);
    }
}

void mac_notification_update_progress(const char *device, const char *key, double value, const char *status) {
    (void)value;
    @autoreleasepool {
        NSString *targetId = [NSString stringWithFormat:@"%s:%s", device, key];
        for (NSUserNotification *n in [NSUserNotificationCenter defaultUserNotificationCenter].deliveredNotifications) {
            if ([n.identifier isEqualToString:targetId]) {
                if (status && strlen(status) > 0) {
                    n.informativeText = [NSString stringWithUTF8String:status];
                }
                [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:n];
                break;
            }
        }
    }
}

void mac_notification_remove(const char *device, const char *key) {
    @autoreleasepool {
        NSString *targetId = [NSString stringWithFormat:@"%s:%s", device, key];
        if (@available(macOS 10.14, *)) {
            @try {
                [[UNUserNotificationCenter currentNotificationCenter] removeDeliveredNotificationsWithIdentifiers:@[targetId]];
                [[UNUserNotificationCenter currentNotificationCenter] removePendingNotificationRequestsWithIdentifiers:@[targetId]];
            } @catch (NSException *e) {}
        }
        
        NSString *devStr = [NSString stringWithUTF8String:device];
        NSString *keyStr = [NSString stringWithUTF8String:key];
        NSUserNotificationCenter *center = [NSUserNotificationCenter defaultUserNotificationCenter];
        for (NSUserNotification *n in center.deliveredNotifications) {
            if ([n.userInfo[@"device"] isEqualToString:devStr] && [n.userInfo[@"key"] isEqualToString:keyStr]) {
                [center removeDeliveredNotification:n];
            }
        }
    }
}

void mac_notification_remove_device(const char *device) {
    @autoreleasepool {
        NSString *devStr = [NSString stringWithUTF8String:device];
        
        if (@available(macOS 10.14, *)) {
            @try {
                UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
                [center getDeliveredNotificationsWithCompletionHandler:^(NSArray<UNNotification *> * _Nonnull notifications) {
                    NSMutableArray<NSString *> *toRemove = [NSMutableArray array];
                    for (UNNotification *n in notifications) {
                        if ([n.request.content.userInfo[@"device"] isEqualToString:devStr]) {
                            [toRemove addObject:n.request.identifier];
                        }
                    }
                    if (toRemove.count > 0) {
                        [center removeDeliveredNotificationsWithIdentifiers:toRemove];
                    }
                }];
            } @catch (NSException *e) {}
        }
        
        NSUserNotificationCenter *center = [NSUserNotificationCenter defaultUserNotificationCenter];
        for (NSUserNotification *n in center.deliveredNotifications) {
            if ([n.userInfo[@"device"] isEqualToString:devStr]) {
                [center removeDeliveredNotification:n];
            }
        }
    }
}

void mac_notification_unregister(void) {
    @autoreleasepool {
        if (@available(macOS 10.14, *)) {
            @try {
                [[UNUserNotificationCenter currentNotificationCenter] removeAllDeliveredNotifications];
                [[UNUserNotificationCenter currentNotificationCenter] removeAllPendingNotificationRequests];
                [UNUserNotificationCenter currentNotificationCenter].delegate = nil;
                s_un_delegate = nil;
            } @catch (NSException *e) {}
        }
        [[NSUserNotificationCenter defaultUserNotificationCenter] removeAllDeliveredNotifications];
        [NSUserNotificationCenter defaultUserNotificationCenter].delegate = nil;
        s_ns_delegate = nil;
    }
}

}

#pragma clang diagnostic pop
