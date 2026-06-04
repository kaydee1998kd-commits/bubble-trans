#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Vision/Vision.h>
#import <QuartzCore/QuartzCore.h>
#import <ImageIO/ImageIO.h>

static CGFloat BTBubbleSize = 58.0;
static NSUInteger BTMaxOverlayItems = 18;
static NSUInteger BTTranslationBatchSize = 6;

static NSArray<NSString *> *BTTargetBundleIdentifiers(void) {
	return @[@"com.taobao.fleamarket", @"com.taobao.idlefish"];
}

@interface BTTextItem : NSObject
@property (nonatomic, copy) NSString *source;
@property (nonatomic, copy) NSString *translated;
@property (nonatomic, assign) CGRect frame;
@end

@implementation BTTextItem
@end

@interface BTPassthroughView : UIView
@end

@implementation BTPassthroughView

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
	UIView *hitView = [super hitTest:point withEvent:event];
	return hitView == self ? nil : hitView;
}

@end

@interface BTTranslatorOverlay : NSObject
+ (instancetype)sharedOverlay;
- (void)start;
@end

@interface BTTranslatorOverlay ()
@property (nonatomic, strong) UIWindow *bubbleWindow;
@property (nonatomic, strong) UIButton *bubbleButton;
@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) BTPassthroughView *overlayView;
@property (nonatomic, strong) UIView *statusPill;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, assign) BOOL busy;
@end

@implementation BTTranslatorOverlay

+ (instancetype)sharedOverlay {
	static BTTranslatorOverlay *overlay = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		overlay = [[BTTranslatorOverlay alloc] init];
	});
	return overlay;
}

- (void)start {
	dispatch_async(dispatch_get_main_queue(), ^{
		if (![self isInsideXianyu] || self.bubbleWindow) {
			return;
		}
		[self buildBubble];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appBecameActive) name:UIApplicationDidBecomeActiveNotification object:nil];
	});
}

- (BOOL)isInsideXianyu {
	return [BTTargetBundleIdentifiers() containsObject:[[NSBundle mainBundle] bundleIdentifier]];
}

- (UIWindowScene *)activeWindowScene {
	for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
		if (![scene isKindOfClass:UIWindowScene.class]) {
			continue;
		}
		if (scene.activationState == UISceneActivationStateForegroundActive || scene.activationState == UISceneActivationStateForegroundInactive) {
			return (UIWindowScene *)scene;
		}
	}

	for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
		if ([scene isKindOfClass:UIWindowScene.class]) {
			return (UIWindowScene *)scene;
		}
	}

	return nil;
}

- (UIWindow *)hostWindow {
	UIWindowScene *scene = [self activeWindowScene];
	for (UIWindow *window in scene.windows) {
		if (window.isKeyWindow && window != self.bubbleWindow && window != self.overlayWindow) {
			return window;
		}
	}

	for (UIWindow *window in scene.windows) {
		if (window != self.bubbleWindow && window != self.overlayWindow) {
			return window;
		}
	}

	return nil;
}

- (void)appBecameActive {
	if (!self.bubbleWindow) {
		[self buildBubble];
	}
	self.bubbleWindow.hidden = NO;
}

- (void)buildBubble {
	CGRect screenBounds = UIScreen.mainScreen.bounds;
	CGRect frame = CGRectMake(CGRectGetWidth(screenBounds) - BTBubbleSize - 16.0, CGRectGetHeight(screenBounds) * 0.42, BTBubbleSize, BTBubbleSize);

	UIWindowScene *scene = [self activeWindowScene];
	if (scene) {
		self.bubbleWindow = [[UIWindow alloc] initWithWindowScene:scene];
		self.bubbleWindow.frame = frame;
	} else {
		self.bubbleWindow = [[UIWindow alloc] initWithFrame:frame];
	}
	self.bubbleWindow.backgroundColor = UIColor.clearColor;
	self.bubbleWindow.windowLevel = UIWindowLevelAlert + 100.0;
	self.bubbleWindow.hidden = NO;

	UIViewController *controller = [[UIViewController alloc] init];
	controller.view.backgroundColor = UIColor.clearColor;
	self.bubbleWindow.rootViewController = controller;

	self.bubbleButton = [UIButton buttonWithType:UIButtonTypeSystem];
	self.bubbleButton.frame = controller.view.bounds;
	self.bubbleButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.bubbleButton.backgroundColor = [UIColor colorWithRed:0.04 green:0.34 blue:0.52 alpha:0.94];
	self.bubbleButton.tintColor = UIColor.whiteColor;
	self.bubbleButton.layer.cornerRadius = BTBubbleSize / 2.0;
	self.bubbleButton.layer.shadowColor = UIColor.blackColor.CGColor;
	self.bubbleButton.layer.shadowOpacity = 0.22;
	self.bubbleButton.layer.shadowRadius = 9.0;
	self.bubbleButton.layer.shadowOffset = CGSizeMake(0.0, 4.0);
	self.bubbleButton.titleLabel.font = [UIFont boldSystemFontOfSize:17.0];
	[self.bubbleButton setTitle:@"EN" forState:UIControlStateNormal];
	[self.bubbleButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
	[self.bubbleButton addTarget:self action:@selector(translateVisibleScreen) forControlEvents:UIControlEventTouchUpInside];

	UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragBubble:)];
	[self.bubbleButton addGestureRecognizer:pan];
	[controller.view addSubview:self.bubbleButton];
}

- (void)dragBubble:(UIPanGestureRecognizer *)recognizer {
	CGPoint translation = [recognizer translationInView:nil];
	CGPoint center = self.bubbleWindow.center;
	center.x += translation.x;
	center.y += translation.y;
	[self clampBubbleCenter:&center];
	self.bubbleWindow.center = center;
	[recognizer setTranslation:CGPointZero inView:nil];
}

- (void)clampBubbleCenter:(CGPoint *)center {
	UIEdgeInsets insets = UIEdgeInsetsMake(20.0, 8.0, 20.0, 8.0);
	CGRect bounds = UIScreen.mainScreen.bounds;
	CGFloat radius = BTBubbleSize / 2.0;
	center->x = MAX(insets.left + radius, MIN(CGRectGetWidth(bounds) - insets.right - radius, center->x));
	center->y = MAX(insets.top + radius, MIN(CGRectGetHeight(bounds) - insets.bottom - radius, center->y));
}

- (void)translateVisibleScreen {
	if (self.busy) {
		return;
	}

	self.busy = YES;
	[self showOverlayStatus:@"Scanning"];
	[self clearTranslationLabels];

	dispatch_async(dispatch_get_main_queue(), ^{
		UIImage *image = [self captureHostScreen];
		CGSize screenSize = [self hostWindow].bounds.size;
		if (!image || CGSizeEqualToSize(screenSize, CGSizeZero)) {
			[self finishWithStatus:@"Screen capture failed"];
			return;
		}

		[self recognizeImage:image screenSize:screenSize completion:^(NSArray<BTTextItem *> *items, NSError *error) {
			if (error) {
				[self finishWithStatus:error.localizedDescription ?: @"OCR failed"];
				return;
			}
			if (items.count == 0) {
				[self finishWithStatus:@"No Chinese text found"];
				return;
			}

			[self showOverlayStatus:[NSString stringWithFormat:@"Translating 0/%lu", (unsigned long)items.count]];
			[self translateItems:items index:0 completion:^(NSArray<BTTextItem *> *translatedItems) {
				[self renderTranslatedItems:translatedItems];
				[self finishWithStatus:[NSString stringWithFormat:@"Translated %lu", (unsigned long)translatedItems.count]];
			}];
		}];
	});
}

- (UIImage *)captureHostScreen {
	UIWindow *window = [self hostWindow];
	if (!window) {
		return nil;
	}

	BOOL bubbleWasHidden = self.bubbleWindow.hidden;
	BOOL overlayWasHidden = self.overlayWindow.hidden;
	self.bubbleWindow.hidden = YES;
	self.overlayWindow.hidden = YES;

	UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
	format.scale = UIScreen.mainScreen.scale;
	format.opaque = YES;

	UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithBounds:window.bounds format:format];
	UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
		[window drawViewHierarchyInRect:window.bounds afterScreenUpdates:NO];
	}];

	self.bubbleWindow.hidden = bubbleWasHidden;
	self.overlayWindow.hidden = overlayWasHidden;
	return image;
}

- (void)recognizeImage:(UIImage *)image screenSize:(CGSize)screenSize completion:(void (^)(NSArray<BTTextItem *> *items, NSError *error))completion {
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		CGImageRef cgImage = image.CGImage;
		if (!cgImage) {
			NSError *error = [NSError errorWithDomain:@"BubbleTrans" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Screen image could not be read."}];
			dispatch_async(dispatch_get_main_queue(), ^{ completion(@[], error); });
			return;
		}

		VNRecognizeTextRequest *request = [[VNRecognizeTextRequest alloc] initWithCompletionHandler:^(VNRequest *request, NSError *error) {
			if (error) {
				dispatch_async(dispatch_get_main_queue(), ^{ completion(@[], error); });
				return;
			}

			NSMutableArray<BTTextItem *> *items = [NSMutableArray array];
			for (VNRecognizedTextObservation *observation in request.results) {
				VNRecognizedText *candidate = [[observation topCandidates:1] firstObject];
				NSString *source = [candidate.string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
				if (source.length == 0 || ![self containsChinese:source]) {
					continue;
				}

				BTTextItem *item = [[BTTextItem alloc] init];
				item.source = source;
				item.frame = [self screenFrameForVisionBox:observation.boundingBox screenSize:screenSize];
				if (CGRectGetWidth(item.frame) < 12.0 || CGRectGetHeight(item.frame) < 8.0) {
					continue;
				}
				[items addObject:item];
				if (items.count >= BTMaxOverlayItems) {
					break;
				}
			}

			[items sortUsingComparator:^NSComparisonResult(BTTextItem *first, BTTextItem *second) {
				if (CGRectGetMinY(first.frame) < CGRectGetMinY(second.frame)) {
					return NSOrderedAscending;
				}
				if (CGRectGetMinY(first.frame) > CGRectGetMinY(second.frame)) {
					return NSOrderedDescending;
				}
				return CGRectGetMinX(first.frame) < CGRectGetMinX(second.frame) ? NSOrderedAscending : NSOrderedDescending;
			}];

			dispatch_async(dispatch_get_main_queue(), ^{ completion(items, nil); });
		}];

		request.recognitionLevel = VNRequestTextRecognitionLevelFast;
		request.usesLanguageCorrection = NO;
		request.minimumTextHeight = 0.018;
		NSArray<NSString *> *preferred = @[@"zh-Hans", @"zh-Hant", @"en-US"];
		NSArray<NSString *> *supported = [request supportedRecognitionLanguagesAndReturnError:nil] ?: preferred;
		NSMutableArray<NSString *> *available = [NSMutableArray array];
		for (NSString *language in preferred) {
			if ([supported containsObject:language]) {
				[available addObject:language];
			}
		}
		request.recognitionLanguages = available.count > 0 ? available : supported;

		VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:cgImage orientation:kCGImagePropertyOrientationUp options:@{}];
		NSError *performError = nil;
		[handler performRequests:@[request] error:&performError];
		if (performError) {
			dispatch_async(dispatch_get_main_queue(), ^{ completion(@[], performError); });
		}
	});
}

- (BOOL)containsChinese:(NSString *)text {
	for (NSUInteger index = 0; index < text.length; index++) {
		unichar character = [text characterAtIndex:index];
		if ((character >= 0x3400 && character <= 0x9FFF) || (character >= 0xF900 && character <= 0xFAFF)) {
			return YES;
		}
	}
	return NO;
}

- (CGRect)screenFrameForVisionBox:(CGRect)box screenSize:(CGSize)screenSize {
	CGFloat x = box.origin.x * screenSize.width;
	CGFloat y = (1.0 - box.origin.y - box.size.height) * screenSize.height;
	CGFloat width = box.size.width * screenSize.width;
	CGFloat height = box.size.height * screenSize.height;
	return CGRectInset(CGRectMake(x, y, width, height), -3.0, -2.0);
}

- (void)translateItems:(NSArray<BTTextItem *> *)items index:(NSUInteger)index completion:(void (^)(NSArray<BTTextItem *> *translatedItems))completion {
	if (index >= items.count) {
		completion([self translatedItemsFromItems:items]);
		return;
	}

	NSUInteger batchEnd = MIN(index + BTTranslationBatchSize, items.count);
	NSArray<BTTextItem *> *batch = [items subarrayWithRange:NSMakeRange(index, batchEnd - index)];
	[self showOverlayStatus:[NSString stringWithFormat:@"Translating %lu/%lu", (unsigned long)batchEnd, (unsigned long)items.count]];
	[self translateBatch:batch completion:^{
		[self renderTranslatedItems:[self translatedItemsFromItems:items]];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.03 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[self translateItems:items index:batchEnd completion:completion];
		});
	}];
}

- (NSArray<BTTextItem *> *)translatedItemsFromItems:(NSArray<BTTextItem *> *)items {
	NSMutableArray<BTTextItem *> *translated = [NSMutableArray array];
	for (BTTextItem *item in items) {
		if (item.translated.length > 0) {
			[translated addObject:item];
		}
	}
	return translated;
}

- (void)translateBatch:(NSArray<BTTextItem *> *)batch completion:(void (^)(void))completion {
	if (batch.count == 0) {
		completion();
		return;
	}

	NSMutableArray<NSString *> *sources = [NSMutableArray arrayWithCapacity:batch.count];
	for (BTTextItem *item in batch) {
		[sources addObject:item.source ?: @""];
	}

	NSString *joined = [sources componentsJoinedByString:@"\n"];
	[self translateText:joined completion:^(NSString *translatedText, NSError *error) {
		(void)error;
		NSArray<NSString *> *lines = [self translatedLinesFromText:translatedText expectedCount:batch.count];
		if (lines.count == batch.count) {
			for (NSUInteger index = 0; index < batch.count; index++) {
				BTTextItem *item = batch[index];
				item.translated = lines[index];
			}
			completion();
			return;
		}

		[self translateBatchSequentially:batch index:0 completion:completion];
	}];
}

- (NSArray<NSString *> *)translatedLinesFromText:(NSString *)text expectedCount:(NSUInteger)expectedCount {
	if (text.length == 0) {
		return @[];
	}

	NSArray<NSString *> *rawLines = [text componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet];
	NSMutableArray<NSString *> *lines = [NSMutableArray array];
	for (NSString *line in rawLines) {
		NSString *cleaned = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
		if (cleaned.length > 0) {
			[lines addObject:cleaned];
		}
	}

	if (lines.count == expectedCount) {
		return lines;
	}
	if (expectedCount == 1) {
		return @[[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
	}
	return @[];
}

- (void)translateBatchSequentially:(NSArray<BTTextItem *> *)batch index:(NSUInteger)index completion:(void (^)(void))completion {
	if (index >= batch.count) {
		completion();
		return;
	}

	BTTextItem *item = batch[index];
	[self translateText:item.source completion:^(NSString *translatedText, NSError *error) {
		(void)error;
		if (translatedText.length > 0) {
			item.translated = translatedText;
		}
		[self translateBatchSequentially:batch index:index + 1 completion:completion];
	}];
}

- (void)translateText:(NSString *)text completion:(void (^)(NSString *translatedText, NSError *error))completion {
	[self translateWithGoogle:text completion:^(NSString *translatedText, NSError *error) {
		if (translatedText.length > 0) {
			completion(translatedText, nil);
			return;
		}
		[self translateWithMyMemory:text completion:completion];
	}];
}

- (void)translateWithGoogle:(NSString *)text completion:(void (^)(NSString *translatedText, NSError *error))completion {
	NSURLComponents *components = [NSURLComponents componentsWithString:@"https://translate.googleapis.com/translate_a/single"];
	components.queryItems = @[
		[NSURLQueryItem queryItemWithName:@"client" value:@"gtx"],
		[NSURLQueryItem queryItemWithName:@"sl" value:@"zh-CN"],
		[NSURLQueryItem queryItemWithName:@"tl" value:@"en"],
		[NSURLQueryItem queryItemWithName:@"dt" value:@"t"],
		[NSURLQueryItem queryItemWithName:@"q" value:text]
	];

	NSURL *url = components.URL;
	if (!url) {
		completion(nil, [NSError errorWithDomain:@"BubbleTrans" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Translation URL failed."}]);
		return;
	}

	NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		if (error) {
			dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, error); });
			return;
		}

		NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
		if (![http isKindOfClass:NSHTTPURLResponse.class] || http.statusCode < 200 || http.statusCode >= 300 || data.length == 0) {
			dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, [NSError errorWithDomain:@"BubbleTrans" code:3 userInfo:@{NSLocalizedDescriptionKey: @"Google translation failed."}]); });
			return;
		}

		NSError *jsonError = nil;
		NSArray *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
		NSString *translated = [self googleTranslatedTextFromJSON:json];
		dispatch_async(dispatch_get_main_queue(), ^{
			if (translated.length > 0) {
				completion(translated, nil);
			} else {
				completion(nil, jsonError ?: [NSError errorWithDomain:@"BubbleTrans" code:4 userInfo:@{NSLocalizedDescriptionKey: @"Google response could not be read."}]);
			}
		});
	}];
	[task resume];
}

- (NSString *)googleTranslatedTextFromJSON:(NSArray *)json {
	if (![json isKindOfClass:NSArray.class] || json.count == 0) {
		return nil;
	}
	NSArray *sentences = json[0];
	if (![sentences isKindOfClass:NSArray.class]) {
		return nil;
	}

	NSMutableString *result = [NSMutableString string];
	for (NSArray *sentence in sentences) {
		if (![sentence isKindOfClass:NSArray.class] || sentence.count == 0) {
			continue;
		}
		NSString *part = sentence[0];
		if ([part isKindOfClass:NSString.class]) {
			[result appendString:part];
		}
	}
	return [result stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

- (void)translateWithMyMemory:(NSString *)text completion:(void (^)(NSString *translatedText, NSError *error))completion {
	NSURLComponents *components = [NSURLComponents componentsWithString:@"https://api.mymemory.translated.net/get"];
	components.queryItems = @[
		[NSURLQueryItem queryItemWithName:@"q" value:text],
		[NSURLQueryItem queryItemWithName:@"langpair" value:@"zh-CN|en"]
	];

	NSURL *url = components.URL;
	if (!url) {
		completion(nil, [NSError errorWithDomain:@"BubbleTrans" code:5 userInfo:@{NSLocalizedDescriptionKey: @"Fallback URL failed."}]);
		return;
	}

	NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		if (error) {
			dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, error); });
			return;
		}

		NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
		if (![http isKindOfClass:NSHTTPURLResponse.class] || http.statusCode < 200 || http.statusCode >= 300) {
			dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, [NSError errorWithDomain:@"BubbleTrans" code:6 userInfo:@{NSLocalizedDescriptionKey: @"Fallback translation failed."}]); });
			return;
		}

		NSError *jsonError = nil;
		NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
		NSString *translated = json[@"responseData"][@"translatedText"];
		if (![translated isKindOfClass:NSString.class]) {
			dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, jsonError ?: [NSError errorWithDomain:@"BubbleTrans" code:7 userInfo:@{NSLocalizedDescriptionKey: @"Fallback response could not be read."}]); });
			return;
		}

		NSString *cleaned = [self stringByDecodingHTMLEntities:translated];
		dispatch_async(dispatch_get_main_queue(), ^{ completion(cleaned, nil); });
	}];
	[task resume];
}

- (NSString *)stringByDecodingHTMLEntities:(NSString *)string {
	NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
	if (!data) {
		return string;
	}
	NSDictionary *options = @{
		NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
		NSCharacterEncodingDocumentAttribute: @(NSUTF8StringEncoding)
	};
	NSAttributedString *attributed = [[NSAttributedString alloc] initWithData:data options:options documentAttributes:nil error:nil];
	return attributed.string ?: string;
}

- (void)buildOverlayIfNeeded {
	if (self.overlayWindow) {
		return;
	}

	CGRect screenBounds = UIScreen.mainScreen.bounds;
	UIWindowScene *scene = [self activeWindowScene];
	if (scene) {
		self.overlayWindow = [[UIWindow alloc] initWithWindowScene:scene];
		self.overlayWindow.frame = screenBounds;
	} else {
		self.overlayWindow = [[UIWindow alloc] initWithFrame:screenBounds];
	}
	self.overlayWindow.backgroundColor = UIColor.clearColor;
	self.overlayWindow.windowLevel = UIWindowLevelAlert + 90.0;
	self.overlayWindow.hidden = YES;

	UIViewController *controller = [[UIViewController alloc] init];
	self.overlayView = [[BTPassthroughView alloc] initWithFrame:screenBounds];
	self.overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.overlayView.backgroundColor = UIColor.clearColor;
	controller.view = self.overlayView;
	self.overlayWindow.rootViewController = controller;

	self.statusPill = [[UIView alloc] initWithFrame:CGRectMake(14.0, 48.0, 210.0, 38.0)];
	self.statusPill.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.82];
	self.statusPill.layer.cornerRadius = 19.0;
	self.statusPill.layer.shadowColor = UIColor.blackColor.CGColor;
	self.statusPill.layer.shadowOpacity = 0.2;
	self.statusPill.layer.shadowRadius = 8.0;
	self.statusPill.layer.shadowOffset = CGSizeMake(0.0, 3.0);
	[self.overlayView addSubview:self.statusPill];

	self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
	self.spinner.frame = CGRectMake(8.0, 7.0, 24.0, 24.0);
	self.spinner.color = UIColor.whiteColor;
	[self.statusPill addSubview:self.spinner];

	self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(36.0, 4.0, 112.0, 30.0)];
	self.statusLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
	self.statusLabel.textColor = UIColor.whiteColor;
	self.statusLabel.adjustsFontSizeToFitWidth = YES;
	self.statusLabel.minimumScaleFactor = 0.75;
	[self.statusPill addSubview:self.statusLabel];

	UIButton *clearButton = [UIButton buttonWithType:UIButtonTypeSystem];
	clearButton.frame = CGRectMake(151.0, 3.0, 54.0, 32.0);
	clearButton.tintColor = UIColor.whiteColor;
	clearButton.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightBold];
	[clearButton setTitle:@"Clear" forState:UIControlStateNormal];
	[clearButton addTarget:self action:@selector(hideOverlay) forControlEvents:UIControlEventTouchUpInside];
	[self.statusPill addSubview:clearButton];
}

- (void)showOverlayStatus:(NSString *)status {
	[self buildOverlayIfNeeded];
	self.overlayWindow.hidden = NO;
	self.statusPill.hidden = NO;
	self.statusLabel.text = status;
	[self.spinner startAnimating];
}

- (void)finishWithStatus:(NSString *)status {
	dispatch_async(dispatch_get_main_queue(), ^{
		self.busy = NO;
		self.statusLabel.text = status;
		[self.spinner stopAnimating];
	});
}

- (void)clearTranslationLabels {
	[self buildOverlayIfNeeded];
	for (UIView *view in [self.overlayView.subviews copy]) {
		if (view != self.statusPill) {
			[view removeFromSuperview];
		}
	}
}

- (void)renderTranslatedItems:(NSArray<BTTextItem *> *)items {
	[self clearTranslationLabels];
	for (BTTextItem *item in items) {
		UILabel *label = [self labelForItem:item];
		[self.overlayView addSubview:label];
	}
}

- (UILabel *)labelForItem:(BTTextItem *)item {
	CGRect screenBounds = UIScreen.mainScreen.bounds;
	CGFloat fontSize = MAX(7.5, MIN(10.5, CGRectGetHeight(item.frame) * 0.48));
	UIFont *font = [UIFont systemFontOfSize:fontSize weight:UIFontWeightMedium];
	NSString *displayText = [self compactTranslation:item.translated];

	CGFloat maxWidth = MIN(CGRectGetWidth(screenBounds) - 16.0, MAX(CGRectGetWidth(item.frame) + 18.0, 58.0));
	CGRect textRect = [displayText boundingRectWithSize:CGSizeMake(maxWidth - 6.0, 30.0)
	                                                options:NSStringDrawingUsesLineFragmentOrigin
	                                             attributes:@{NSFontAttributeName: font}
	                                                context:nil];
	CGFloat width = MIN(maxWidth, MAX(CGRectGetWidth(item.frame) + 2.0, ceil(textRect.size.width) + 8.0));
	CGFloat height = MIN(34.0, MAX(CGRectGetHeight(item.frame) + 1.0, ceil(textRect.size.height) + 5.0));

	CGFloat x = MIN(MAX(8.0, CGRectGetMinX(item.frame)), CGRectGetWidth(screenBounds) - width - 8.0);
	CGFloat y = MIN(MAX(24.0, CGRectGetMinY(item.frame)), CGRectGetHeight(screenBounds) - height - 8.0);

	UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(x, y, width, height)];
	label.userInteractionEnabled = NO;
	label.numberOfLines = 2;
	label.textAlignment = NSTextAlignmentCenter;
	label.text = displayText;
	label.font = font;
	label.textColor = UIColor.blackColor;
	label.backgroundColor = [UIColor colorWithRed:1.0 green:0.98 blue:0.70 alpha:0.78];
	label.layer.cornerRadius = 4.0;
	label.layer.masksToBounds = YES;
	label.layer.borderColor = [UIColor colorWithWhite:0.0 alpha:0.18].CGColor;
	label.layer.borderWidth = 0.5;
	label.adjustsFontSizeToFitWidth = YES;
	label.minimumScaleFactor = 0.65;
	label.lineBreakMode = NSLineBreakByTruncatingTail;
	label.alpha = 0.88;
	return label;
}

- (NSString *)compactTranslation:(NSString *)translation {
	NSString *cleaned = [translation stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
	cleaned = [cleaned stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
	while ([cleaned containsString:@"  "]) {
		cleaned = [cleaned stringByReplacingOccurrencesOfString:@"  " withString:@" "];
	}

	NSUInteger maxLength = 42;
	if (cleaned.length <= maxLength) {
		return cleaned;
	}
	return [[cleaned substringToIndex:maxLength - 1] stringByAppendingString:@"..."];
}

- (void)hideOverlay {
	self.overlayWindow.hidden = YES;
}

@end

%ctor {
	@autoreleasepool {
		if ([BTTargetBundleIdentifiers() containsObject:[[NSBundle mainBundle] bundleIdentifier]]) {
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				[[BTTranslatorOverlay sharedOverlay] start];
			});
		}
	}
}
