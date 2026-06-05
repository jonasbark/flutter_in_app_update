#import "InAppUpdatePlugin.h"
#import <UIKit/UIKit.h>

static NSInteger const UpdateAvailabilityNotAvailable = 1;
static NSInteger const UpdateAvailabilityAvailable = 2;
static NSInteger const InstallStatusUnknown = 0;

@interface InAppUpdatePlugin ()
@property(nonatomic, copy) NSString *lastStoreUrl;
@end

@implementation InAppUpdatePlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"de.ffuf.in_app_update_plus/methods"
            binaryMessenger:[registrar messenger]];
  FlutterEventChannel* eventChannel = [FlutterEventChannel
      eventChannelWithName:@"de.ffuf.in_app_update_plus/stateEvents"
            binaryMessenger:[registrar messenger]];

  InAppUpdatePlugin* instance = [[InAppUpdatePlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
  [eventChannel setStreamHandler:instance];
}

- (FlutterError*)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)events {
  return nil;
}

- (FlutterError*)onCancelWithArguments:(id)arguments {
  return nil;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"checkForUpdate" isEqualToString:call.method]) {
    [self checkForUpdate:call result:result];
  } else if ([@"performImmediateUpdate" isEqualToString:call.method] ||
             [@"startFlexibleUpdate" isEqualToString:call.method]) {
    [self openAppStoreWithResult:result];
  } else if ([@"completeFlexibleUpdate" isEqualToString:call.method]) {
    result(nil);
  } else {
    result(FlutterMethodNotImplemented);
  }
}

- (void)checkForUpdate:(FlutterMethodCall*)call result:(FlutterResult)result {
  NSDictionary *arguments = [call.arguments isKindOfClass:[NSDictionary class]]
      ? call.arguments
      : @{};
  NSString *bundleIdentifier = [self stringFromObject:arguments[@"bundleId"]];
  if (bundleIdentifier.length == 0) {
    bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
  }
  NSString *installedVersion = [self installedVersion];

  NSURL *lookupUrl = [self lookupUrlWithBundleIdentifier:bundleIdentifier
                                              appStoreId:[self stringFromObject:arguments[@"appStoreId"]]
                                             countryCode:[self stringFromObject:arguments[@"countryCode"]]];
  if (lookupUrl == nil) {
    result([FlutterError errorWithCode:@"APP_STORE_LOOKUP_FAILED"
                               message:@"Unable to build an App Store lookup URL."
                               details:nil]);
    return;
  }

  NSURLSessionDataTask *task = [[NSURLSession sharedSession]
      dataTaskWithURL:lookupUrl
    completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
      if (error != nil) {
        [self finishWithErrorCode:@"APP_STORE_LOOKUP_FAILED"
                          message:error.localizedDescription
                           result:result];
        return;
      }

      NSHTTPURLResponse *httpResponse = [response isKindOfClass:[NSHTTPURLResponse class]]
          ? (NSHTTPURLResponse *)response
          : nil;
      if (httpResponse != nil && (httpResponse.statusCode < 200 || httpResponse.statusCode >= 300)) {
        [self finishWithErrorCode:@"APP_STORE_LOOKUP_FAILED"
                          message:[NSString stringWithFormat:@"App Store lookup failed with HTTP status %ld.",
                                                             (long)httpResponse.statusCode]
                           result:result];
        return;
      }

      NSError *jsonError = nil;
      NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:data ?: [NSData data]
                                                               options:0
                                                                 error:&jsonError];
      if (![payload isKindOfClass:[NSDictionary class]] || jsonError != nil) {
        [self finishWithErrorCode:@"APP_STORE_LOOKUP_FAILED"
                          message:jsonError.localizedDescription ?: @"Unable to parse App Store lookup response."
                           result:result];
        return;
      }

      NSDictionary *storeInfo = [self storeInfoFromLookupPayload:payload
                                                bundleIdentifier:bundleIdentifier];
      NSDictionary *updateInfo = [self updateInfoFromStoreInfo:storeInfo
                                              bundleIdentifier:bundleIdentifier
                                              installedVersion:installedVersion];
      [self finishWithSuccess:updateInfo result:result];
    }];
  [task resume];
}

- (NSURL*)lookupUrlWithBundleIdentifier:(NSString*)bundleIdentifier
                             appStoreId:(NSString*)appStoreId
                            countryCode:(NSString*)countryCode {
  NSURLComponents *components = [NSURLComponents componentsWithString:@"https://itunes.apple.com/lookup"];
  NSMutableArray<NSURLQueryItem*> *queryItems = [NSMutableArray array];

  if (appStoreId.length > 0) {
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"id" value:appStoreId]];
  } else if (bundleIdentifier.length > 0) {
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"bundleId" value:bundleIdentifier]];
  } else {
    return nil;
  }

  [queryItems addObject:[NSURLQueryItem queryItemWithName:@"media" value:@"software"]];
  if (countryCode.length > 0) {
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"country" value:countryCode]];
  }
  components.queryItems = queryItems;
  return components.URL;
}

- (NSDictionary*)storeInfoFromLookupPayload:(NSDictionary*)payload
                           bundleIdentifier:(NSString*)bundleIdentifier {
  NSArray *results = [payload[@"results"] isKindOfClass:[NSArray class]]
      ? payload[@"results"]
      : @[];
  if (results.count == 0) {
    return nil;
  }

  for (id item in results) {
    if (![item isKindOfClass:[NSDictionary class]]) {
      continue;
    }
    NSDictionary *candidate = (NSDictionary*)item;
    NSString *candidateBundleId = [self stringFromObject:candidate[@"bundleId"]];
    if (bundleIdentifier.length == 0 || [candidateBundleId isEqualToString:bundleIdentifier]) {
      return candidate;
    }
  }

  return [results.firstObject isKindOfClass:[NSDictionary class]]
      ? results.firstObject
      : nil;
}

- (NSDictionary*)updateInfoFromStoreInfo:(NSDictionary*)storeInfo
                        bundleIdentifier:(NSString*)bundleIdentifier
                        installedVersion:(NSString*)installedVersion {
  NSString *availableVersion = [self stringFromObject:storeInfo[@"version"]];
  NSString *storeUrl = [self stringFromObject:storeInfo[@"trackViewUrl"]];
  NSNumber *appStoreId = [storeInfo[@"trackId"] isKindOfClass:[NSNumber class]]
      ? storeInfo[@"trackId"]
      : nil;

  BOOL updateAvailable = availableVersion.length > 0 &&
      [self compareVersion:availableVersion toVersion:installedVersion] == NSOrderedDescending;
  BOOL canOpenStore = updateAvailable && storeUrl.length > 0;
  self.lastStoreUrl = storeUrl;

  NSMutableDictionary *info = [@{
    @"updateAvailability": @(updateAvailable ? UpdateAvailabilityAvailable : UpdateAvailabilityNotAvailable),
    @"immediateAllowed": @(canOpenStore),
    @"immediateAllowedPreconditions": @[],
    @"flexibleAllowed": @NO,
    @"flexibleAllowedPreconditions": @[],
    @"installStatus": @(InstallStatusUnknown),
    @"packageName": bundleIdentifier ?: @"",
    @"clientVersionStalenessDays": [NSNull null],
    @"updatePriority": @0,
    @"installedVersionName": installedVersion ?: @""
  } mutableCopy];

  if (availableVersion.length > 0) {
    info[@"availableVersionName"] = availableVersion;
  }
  if (storeUrl.length > 0) {
    info[@"storeUrl"] = storeUrl;
  }
  if (appStoreId != nil) {
    info[@"appStoreId"] = appStoreId;
  }
  NSString *releaseNotes = [self stringFromObject:storeInfo[@"releaseNotes"]];
  if (releaseNotes.length > 0) {
    info[@"releaseNotes"] = releaseNotes;
  }

  return info;
}

- (void)openAppStoreWithResult:(FlutterResult)result {
  NSString *storeUrl = self.lastStoreUrl;
  if (storeUrl.length == 0) {
    result([FlutterError errorWithCode:@"REQUIRE_CHECK_FOR_UPDATE"
                               message:@"Call checkForUpdate first so the App Store URL can be resolved."
                               details:nil]);
    return;
  }

  NSURL *url = [NSURL URLWithString:storeUrl];
  if (url == nil) {
    result([FlutterError errorWithCode:@"IN_APP_UPDATE_FAILED"
                               message:@"The resolved App Store URL is invalid."
                               details:nil]);
    return;
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    UIApplication *application = [UIApplication sharedApplication];
    if (@available(iOS 10.0, *)) {
      [application openURL:url
                   options:@{}
         completionHandler:^(BOOL success) {
        if (success) {
          result(nil);
        } else {
          result([FlutterError errorWithCode:@"IN_APP_UPDATE_FAILED"
                                     message:@"iOS could not open the App Store URL."
                                     details:nil]);
        }
      }];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
      BOOL success = [application openURL:url];
#pragma clang diagnostic pop
      if (success) {
        result(nil);
      } else {
        result([FlutterError errorWithCode:@"IN_APP_UPDATE_FAILED"
                                   message:@"iOS could not open the App Store URL."
                                   details:nil]);
      }
    }
  });
}

- (NSComparisonResult)compareVersion:(NSString*)left toVersion:(NSString*)right {
  NSArray<NSString*> *leftParts = [left componentsSeparatedByString:@"."];
  NSArray<NSString*> *rightParts = [right componentsSeparatedByString:@"."];
  NSUInteger count = MAX(leftParts.count, rightParts.count);

  for (NSUInteger index = 0; index < count; index++) {
    NSInteger leftValue = index < leftParts.count ? leftParts[index].integerValue : 0;
    NSInteger rightValue = index < rightParts.count ? rightParts[index].integerValue : 0;

    if (leftValue > rightValue) {
      return NSOrderedDescending;
    }
    if (leftValue < rightValue) {
      return NSOrderedAscending;
    }
  }

  return NSOrderedSame;
}

- (NSString*)installedVersion {
  NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
  return version.length > 0 ? version : @"0";
}

- (NSString*)stringFromObject:(id)value {
  if ([value isKindOfClass:[NSString class]]) {
    return value;
  }
  if ([value respondsToSelector:@selector(stringValue)]) {
    return [value stringValue];
  }
  return nil;
}

- (void)finishWithSuccess:(id)value result:(FlutterResult)result {
  dispatch_async(dispatch_get_main_queue(), ^{
    result(value);
  });
}

- (void)finishWithErrorCode:(NSString*)code message:(NSString*)message result:(FlutterResult)result {
  dispatch_async(dispatch_get_main_queue(), ^{
    result([FlutterError errorWithCode:code
                               message:message ?: @"App Store lookup failed."
                               details:nil]);
  });
}

@end
