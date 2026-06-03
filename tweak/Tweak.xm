#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Vision/Vision.h>
#import <QuartzCore/QuartzCore.h>
#import <ImageIO/ImageIO.h>

@interface BTTranslatorOverlay : NSObject
+ (instancetype)sharedOverlay;
- (void)start;
@end

@interface BTTranslatorOverlay ()
@property (nonatomic, strong) UIWindow *bubbleWindow;
@property (nonatomic, strong) UIButton *bubbleButton;
@property (nonatomic, strong) UIWindow *panelWindow;
@property (nonatomic, strong) UIView *panelView;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, assign) BOOL busy;
@end

static NSArray<NSString *> *BTTargetBundleIdentifiers(void) {
	return @[@"com.taobao.fleamarket", @"com.taobao.idlefish"];
}
static CGFloat BTBubbleSize = 58.0;

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
		if (window.isKeyWindow) {
			return window;
		}
	}
	return scene.windows.firstObject;
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
	self.bubbleButton.titleLabel.font = [UIFont boldSystemFontOfSize:18.0];
	[self.bubbleButton setTitle:@"译" forState:UIControlStateNormal];
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
	[self showPanelWithStatus:@"Reading screen" text:@"Looking for Chinese text..."];

	dispatch_async(dispatch_get_main_queue(), ^{
		UIImage *image = [self captureHostScreen];
		if (!image) {
			[self finishWithStatus:@"Failed" text:@"Could not capture Xianyu screen." copyable:NO translatedText:nil];
			return;
		}

		[self recognizeImage:image completion:^(NSString *recognizedText, NSError *error) {
			if (error || recognizedText.length == 0) {
				[self finishWithStatus:@"No text" text:(error.localizedDescription ?: @"No readable text found.") copyable:NO translatedText:nil];
				return;
			}

			[self updateStatus:@"Translating"];
			[self translateText:recognizedText completion:^(NSString *translatedText, NSError *translateError) {
				if (translateError || translatedText.length == 0) {
					NSString *message = translateError.localizedDescription ?: @"The translation service returned no text.";
					[self finishWithStatus:@"Failed" text:message copyable:NO translatedText:nil];
					return;
				}

				NSString *output = [NSString stringWithFormat:@"Original\n%@\n\nTranslation\n%@", recognizedText, translatedText];
				[self finishWithStatus:@"Done" text:output copyable:YES translatedText:translatedText];
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
	BOOL panelWasHidden = self.panelWindow.hidden;
	self.bubbleWindow.hidden = YES;
	self.panelWindow.hidden = YES;

	UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
	format.scale = UIScreen.mainScreen.scale;
	format.opaque = YES;

	UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithBounds:window.bounds format:format];
	UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
		[window drawViewHierarchyInRect:window.bounds afterScreenUpdates:NO];
	}];

	self.bubbleWindow.hidden = bubbleWasHidden;
	self.panelWindow.hidden = panelWasHidden;
	return image;
}

- (void)recognizeImage:(UIImage *)image completion:(void (^)(NSString *recognizedText, NSError *error))completion {
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		CGImageRef cgImage = image.CGImage;
		if (!cgImage) {
			NSError *error = [NSError errorWithDomain:@"BubbleTrans" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Screen image could not be read."}];
			dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, error); });
			return;
		}

		VNRecognizeTextRequest *request = [[VNRecognizeTextRequest alloc] initWithCompletionHandler:^(VNRequest *request, NSError *error) {
			if (error) {
				dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, error); });
				return;
			}

			NSMutableArray<NSString *> *lines = [NSMutableArray array];
			for (VNRecognizedTextObservation *observation in request.results) {
				VNRecognizedText *candidate = [[observation topCandidates:1] firstObject];
				if (candidate.string.length > 0) {
					[lines addObject:candidate.string];
				}
			}

			NSString *recognized = [lines componentsJoinedByString:@"\n"];
			dispatch_async(dispatch_get_main_queue(), ^{ completion(recognized, nil); });
		}];

		request.recognitionLevel = VNRequestTextRecognitionLevelAccurate;
		request.usesLanguageCorrection = NO;
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
			dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, performError); });
		}
	});
}

- (void)translateText:(NSString *)text completion:(void (^)(NSString *translatedText, NSError *error))completion {
	NSArray<NSString *> *chunks = [self chunksForText:text maxLength:450];
	NSMutableArray<NSString *> *translatedChunks = [NSMutableArray array];
	[self translateChunks:chunks index:0 output:translatedChunks completion:completion];
}

- (void)translateChunks:(NSArray<NSString *> *)chunks index:(NSUInteger)index output:(NSMutableArray<NSString *> *)output completion:(void (^)(NSString *translatedText, NSError *error))completion {
	if (index >= chunks.count) {
		completion([output componentsJoinedByString:@"\n"], nil);
		return;
	}

	NSString *chunk = chunks[index];
	NSURLComponents *components = [NSURLComponents componentsWithString:@"https://api.mymemory.translated.net/get"];
	components.queryItems = @[
		[NSURLQueryItem queryItemWithName:@"q" value:chunk],
		[NSURLQueryItem queryItemWithName:@"langpair" value:@"zh-CN|en"]
	];

	NSURL *url = components.URL;
	if (!url) {
		NSError *error = [NSError errorWithDomain:@"BubbleTrans" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Translation URL could not be built."}];
		completion(nil, error);
		return;
	}

	NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		if (error) {
			dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, error); });
			return;
		}

		NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
		if (![http isKindOfClass:NSHTTPURLResponse.class] || http.statusCode < 200 || http.statusCode >= 300) {
			NSError *httpError = [NSError errorWithDomain:@"BubbleTrans" code:3 userInfo:@{NSLocalizedDescriptionKey: @"Translation service failed."}];
			dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, httpError); });
			return;
		}

		NSError *jsonError = nil;
		NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
		NSString *translated = json[@"responseData"][@"translatedText"];
		if (![translated isKindOfClass:NSString.class]) {
			dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, jsonError ?: [NSError errorWithDomain:@"BubbleTrans" code:4 userInfo:@{NSLocalizedDescriptionKey: @"Translation response could not be read."}]); });
			return;
		}

		NSString *cleaned = [self stringByDecodingHTMLEntities:translated];
		dispatch_async(dispatch_get_main_queue(), ^{
			[output addObject:cleaned];
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.18 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				[self translateChunks:chunks index:index + 1 output:output completion:completion];
			});
		});
	}];
	[task resume];
}

- (NSArray<NSString *> *)chunksForText:(NSString *)text maxLength:(NSUInteger)maxLength {
	NSMutableArray<NSString *> *chunks = [NSMutableArray array];
	NSMutableString *current = [NSMutableString string];
	for (NSString *line in [text componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
		NSString *candidate = current.length == 0 ? line : [NSString stringWithFormat:@"%@\n%@", current, line];
		if (candidate.length <= maxLength) {
			[current setString:candidate];
		} else {
			if (current.length > 0) {
				[chunks addObject:[current copy]];
			}
			[current setString:line];
		}
	}
	if (current.length > 0) {
		[chunks addObject:[current copy]];
	}
	return chunks.count > 0 ? chunks : @[text];
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

- (void)showPanelWithStatus:(NSString *)status text:(NSString *)text {
	if (!self.panelWindow) {
		[self buildPanel];
	}
	self.panelWindow.hidden = NO;
	[self updateStatus:status];
	self.textView.text = text;
	self.spinner.hidden = NO;
	[self.spinner startAnimating];
}

- (void)buildPanel {
	CGRect screenBounds = UIScreen.mainScreen.bounds;
	CGFloat width = MIN(CGRectGetWidth(screenBounds) - 28.0, 430.0);
	CGFloat height = MIN(CGRectGetHeight(screenBounds) * 0.58, 420.0);
	CGRect frame = CGRectMake((CGRectGetWidth(screenBounds) - width) / 2.0, 72.0, width, height);

	UIWindowScene *scene = [self activeWindowScene];
	if (scene) {
		self.panelWindow = [[UIWindow alloc] initWithWindowScene:scene];
		self.panelWindow.frame = screenBounds;
	} else {
		self.panelWindow = [[UIWindow alloc] initWithFrame:screenBounds];
	}
	self.panelWindow.backgroundColor = UIColor.clearColor;
	self.panelWindow.windowLevel = UIWindowLevelAlert + 90.0;
	self.panelWindow.hidden = YES;

	UIViewController *controller = [[UIViewController alloc] init];
	controller.view.backgroundColor = UIColor.clearColor;
	self.panelWindow.rootViewController = controller;

	self.panelView = [[UIView alloc] initWithFrame:frame];
	self.panelView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.97];
	self.panelView.layer.cornerRadius = 12.0;
	self.panelView.layer.shadowColor = UIColor.blackColor.CGColor;
	self.panelView.layer.shadowOpacity = 0.22;
	self.panelView.layer.shadowRadius = 18.0;
	self.panelView.layer.shadowOffset = CGSizeMake(0.0, 6.0);
	[controller.view addSubview:self.panelView];

	UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragPanel:)];
	[self.panelView addGestureRecognizer:pan];

	UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
	closeButton.frame = CGRectMake(CGRectGetWidth(frame) - 48.0, 8.0, 40.0, 40.0);
	closeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
	closeButton.tintColor = UIColor.darkGrayColor;
	[closeButton setTitle:@"×" forState:UIControlStateNormal];
	closeButton.titleLabel.font = [UIFont boldSystemFontOfSize:28.0];
	[closeButton addTarget:self action:@selector(hidePanel) forControlEvents:UIControlEventTouchUpInside];
	[self.panelView addSubview:closeButton];

	UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
	copyButton.frame = CGRectMake(CGRectGetWidth(frame) - 106.0, 12.0, 54.0, 32.0);
	copyButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
	copyButton.tintColor = [UIColor colorWithRed:0.04 green:0.34 blue:0.52 alpha:1.0];
	[copyButton setTitle:@"Copy" forState:UIControlStateNormal];
	copyButton.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
	[copyButton addTarget:self action:@selector(copyPanelText) forControlEvents:UIControlEventTouchUpInside];
	[self.panelView addSubview:copyButton];

	self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(14.0, 14.0, CGRectGetWidth(frame) - 130.0, 28.0)];
	self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
	self.statusLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
	self.statusLabel.textColor = UIColor.blackColor;
	[self.panelView addSubview:self.statusLabel];

	self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
	self.spinner.center = CGPointMake(CGRectGetMaxX(self.statusLabel.frame) - 4.0, 28.0);
	self.spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
	[self.panelView addSubview:self.spinner];

	self.textView = [[UITextView alloc] initWithFrame:CGRectMake(12.0, 54.0, CGRectGetWidth(frame) - 24.0, CGRectGetHeight(frame) - 66.0)];
	self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.textView.editable = NO;
	self.textView.backgroundColor = [UIColor colorWithWhite:0.96 alpha:1.0];
	self.textView.textColor = UIColor.blackColor;
	self.textView.font = [UIFont systemFontOfSize:15.0];
	self.textView.layer.cornerRadius = 8.0;
	self.textView.textContainerInset = UIEdgeInsetsMake(10.0, 8.0, 10.0, 8.0);
	[self.panelView addSubview:self.textView];
}

- (void)dragPanel:(UIPanGestureRecognizer *)recognizer {
	CGPoint translation = [recognizer translationInView:self.panelWindow];
	CGPoint center = self.panelView.center;
	center.x += translation.x;
	center.y += translation.y;
	[self clampPanelCenter:&center];
	self.panelView.center = center;
	[recognizer setTranslation:CGPointZero inView:self.panelWindow];
}

- (void)clampPanelCenter:(CGPoint *)center {
	CGRect bounds = UIScreen.mainScreen.bounds;
	CGFloat halfWidth = CGRectGetWidth(self.panelView.bounds) / 2.0;
	CGFloat halfHeight = CGRectGetHeight(self.panelView.bounds) / 2.0;
	center->x = MAX(halfWidth + 8.0, MIN(CGRectGetWidth(bounds) - halfWidth - 8.0, center->x));
	center->y = MAX(halfHeight + 24.0, MIN(CGRectGetHeight(bounds) - halfHeight - 8.0, center->y));
}

- (void)updateStatus:(NSString *)status {
	dispatch_async(dispatch_get_main_queue(), ^{
		self.statusLabel.text = status;
	});
}

- (void)finishWithStatus:(NSString *)status text:(NSString *)text copyable:(BOOL)copyable translatedText:(NSString *)translatedText {
	dispatch_async(dispatch_get_main_queue(), ^{
		self.busy = NO;
		self.statusLabel.text = status;
		self.textView.text = text;
		self.textView.accessibilityValue = translatedText ?: text;
		[self.spinner stopAnimating];
		self.spinner.hidden = YES;
	});
}

- (void)copyPanelText {
	UIPasteboard.generalPasteboard.string = self.textView.accessibilityValue ?: self.textView.text;
	self.statusLabel.text = @"Copied";
}

- (void)hidePanel {
	self.panelWindow.hidden = YES;
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
