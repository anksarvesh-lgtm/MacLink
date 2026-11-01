// SPDX-License-Identifier: GPL-3.0-or-later
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#include "mac_notifications.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface MacNotificationDelegate : NSObject <NSUserNotificationCenterDelegate>
@property (nonatomic, assign) MacNotificationCallback callback;
@end

@implementation MacNotificationDelegate

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification {
    // Ensure notifications always present as banners even when MacLink is frontmost/active.
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

static MacNotificationDelegate *s_delegate = nil;

extern "C" {

void mac_notification_start(const char *app_icon_path, MacNotificationCallback callback) {
    (void)app_icon_path;
    @autoreleasepool {
        s_delegate = [[MacNotificationDelegate alloc] init];
        s_delegate.callback = callback;
        [NSUserNotificationCenter defaultUserNotificationCenter].delegate = s_delegate;
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
        NSUserNotification *notif = [[NSUserNotification alloc] init];
        notif.identifier = [NSString stringWithFormat:@"%s:%s", device, key];
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

        // Attach source app icon (e.g. Telegram, WhatsApp) or notification image
        NSString *imageFile = nil;
        if (icon_path && strlen(icon_path) > 0) {
            imageFile = [NSString stringWithUTF8String:icon_path];
        } else if (image_path && strlen(image_path) > 0) {
            imageFile = [NSString stringWithUTF8String:image_path];
        }
        if (imageFile && [[NSFileManager defaultManager] fileExistsAtPath:imageFile]) {
            NSImage *img = [[NSImage alloc] initWithContentsOfFile:imageFile];
            if (img) {
                notif.contentImage = img;
            }
        }

        NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
        userInfo[@"device"] = [NSString stringWithUTF8String:device];
        userInfo[@"key"] = [NSString stringWithUTF8String:key];

        // Actions & Replies
        if (has_reply) {
            notif.hasReplyButton = YES;
            if (reply_title && strlen(reply_title) > 0) {
                notif.responsePlaceholder = [NSString stringWithUTF8String:reply_title];
            }
            if (reply_id && strlen(reply_id) > 0) {
                userInfo[@"reply_action"] = [NSString stringWithUTF8String:reply_id];
            }
        } else if (action_count > 0 && action_ids && action_titles) {
            notif.hasActionButton = YES;
            notif.actionButtonTitle = [NSString stringWithUTF8String:action_titles[0]];
            userInfo[@"primary_action"] = [NSString stringWithUTF8String:action_ids[0]];

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
        }

        notif.userInfo = userInfo;
        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notif];
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
        [[NSUserNotificationCenter defaultUserNotificationCenter] removeAllDeliveredNotifications];
        [NSUserNotificationCenter defaultUserNotificationCenter].delegate = nil;
        s_delegate = nil;
    }
}

}

#pragma clang diagnostic pop
