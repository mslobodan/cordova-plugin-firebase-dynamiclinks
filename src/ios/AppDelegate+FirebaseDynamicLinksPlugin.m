#import "AppDelegate+FirebaseDynamicLinksPlugin.h"
#import "FirebaseDynamicLinksPlugin.h"
#import <objc/runtime.h>


// This file is taken from https://github.com/QDOOZ/cordova-plugin-firebase-offline/blob/master/src/ios/AppDelegate%2BFirebaseDynamicLinksPlugin.m
@implementation AppDelegate (FirebaseDynamicLinksPlugin)

static NSString *const CUSTOM_URL_PREFIX_TO_IGNORE = @"/__/auth/callback";

// Borrowed from http://nshipster.com/method-swizzling/
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];

        SEL originalSelector = @selector(application:continueUserActivity:restorationHandler:);
        SEL swizzledSelector = @selector(identity_application:continueUserActivity:restorationHandler:);

        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);

        BOOL didAddMethod =
        class_addMethod(class,
                        originalSelector,
                        method_getImplementation(swizzledMethod),
                        method_getTypeEncoding(swizzledMethod));

        if (didAddMethod) {
            class_replaceMethod(class,
                                swizzledSelector,
                                method_getImplementation(originalMethod),
                                method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

// [START continueuseractivity]
- (BOOL)identity_application:(UIApplication *)application
        continueUserActivity:(NSUserActivity *)userActivity
          restorationHandler:
#if defined(__IPHONE_12_0) && (__IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_12_0)
(nonnull void (^)(NSArray<id<UIUserActivityRestoring>> *_Nullable))restorationHandler {
#else
    (nonnull void (^)(NSArray *_Nullable))restorationHandler {
#endif  // __IPHONE_12_0
    FirebaseDynamicLinksPlugin* dl = [self.viewController getCommandInstance:@"FirebaseDynamicLinks"];

    BOOL handled = [[FIRDynamicLinks dynamicLinks]
        handleUniversalLink:userActivity.webpageURL
        completion:^(FIRDynamicLink * _Nullable dynamicLink, NSError * _Nullable error) {
            // Try this method as some dynamic links are not recognize by handleUniversalLink
            // ISSUE: https://github.com/firebase/firebase-ios-sdk/issues/743
            dynamicLink = dynamicLink ? dynamicLink
                : [[FIRDynamicLinks dynamicLinks]
                   dynamicLinkFromUniversalLinkURL:userActivity.webpageURL];

            if (dynamicLink) {
                [dl postDynamicLink:dynamicLink];
            }
        }];

    if (handled) {
        return YES;
    }

    return [self identity_application:application
                 continueUserActivity:userActivity
                   restorationHandler:restorationHandler];
}

// This method is from chemerisuk/cordova-plugin-firebase-dynamiclinks
- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString *, id> *)options {
    return FALSE;
}

// This method is from chemerisuk/cordova-plugin-firebase-dynamiclinks
- (BOOL)identity_application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString *, id> *)options {
    // always call original method implementation first
    BOOL handled = [self identity_application:app openURL:url options:options];
    FirebaseDynamicLinksPlugin* dl = [self.viewController getCommandInstance:@"FirebaseDynamicLinks"];
    // parse firebase dynamic link
    FIRDynamicLink *dynamicLink = [[FIRDynamicLinks dynamicLinks] dynamicLinkFromCustomSchemeURL:url];
    if (dynamicLink) {
        [dl postDynamicLink:dynamicLink];
        handled = TRUE;
    }
    return handled;
}

//- (BOOL)application:(UIApplication *)app
//            openURL:(NSURL *)url
//            options:(NSDictionary<NSString *, id> *)options {
//    return [self application:app
//                     openURL:url
//           sourceApplication:options[UIApplicationOpenURLOptionsSourceApplicationKey]
//                  annotation:options[UIApplicationOpenURLOptionsAnnotationKey]];
//}

static id orNull(id obj) {
    return obj ?: [NSNull null];
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
  FIRDynamicLink *dynamicLink = [[FIRDynamicLinks dynamicLinks] dynamicLinkFromCustomSchemeURL:url];

    FirebaseDynamicLinksPlugin* dl = [self.viewController getCommandInstance:@"FirebaseDynamicLinks"];
    if (dynamicLink) {
        BOOL validDynamicLink = dynamicLink.url && ![dynamicLink.url.path hasPrefix:CUSTOM_URL_PREFIX_TO_IGNORE];
        if (validDynamicLink) {
            [dl postDynamicLink:dynamicLink];
            return YES;
        } else {
            // Dynamic link has empty deep link. This situation will happens if
            // Firebase Dynamic Links iOS SDK tried to retrieve pending dynamic link,
            // but pending link is not available for this device/App combination.
            // At this point you may display default onboarding view.
        }
    }

    NSDictionary *options = @{
        @"UIApplicationOpenURLOptionsSourceApplicationKey": orNull(sourceApplication),
        @"UIApplicationOpenURLOptionsAnnotationKey": orNull(annotation)
    };

    return [super application: application
                      openURL:url
                      options:options];
}

// [END continueuseractivity]

@end
