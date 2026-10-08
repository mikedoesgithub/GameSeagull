#import "Utils.h"
#import <dlfcn.h>
#import "substrate.h"

uint64_t bh_memmem(const uint8_t* haystack, size_t hlen, const uint8_t* needle, size_t nlen) {
    if (nlen == 0 || !haystack || !needle || hlen < nlen) return 0;
    
    size_t bad_char_skip[UCHAR_MAX + 1];
    for (size_t scan = 0; scan <= UCHAR_MAX; scan++) bad_char_skip[scan] = nlen;
    for (size_t scan = 0; scan < nlen - 1; scan++)
        bad_char_skip[needle[scan]] = (nlen - 1) - scan;

    while (hlen >= nlen) {
        size_t scan = nlen - 1;
        while (haystack[scan] == needle[scan]) {
            if (scan == 0) return (uint64_t)haystack;
            scan--;
        }
        
        // Safety check for ARM64 RET (0xd65f03c0) / RETAB (0xd65f0fff)
        if (*(const uint32_t *)haystack == 0xd65f03c0 || *(const uint32_t *)haystack == 0xd65f0fff) {
            return 0;
        }

        size_t skip = bad_char_skip[haystack[nlen - 1]];
        if (hlen < skip) break;
        hlen -= skip;
        haystack += skip;
    }
    return 0;
}

int (*__LHPatchMemory)(const struct LHMemoryPatch *patches, int count);
int PatchMemory(const struct LHMemoryPatch *patches, int count) {
    static dispatch_once_t onceToken;
    dispatch_once (&onceToken, ^{
        void* lhImage = dlopen((ROOT_PATH("/usr/lib/libhooker.dylib")), RTLD_NOW);
        if(lhImage) {
            __LHPatchMemory = (void*)dlsym(lhImage, "LHPatchMemory");
        }
    });

    if(__LHPatchMemory) {
        return __LHPatchMemory(patches, count);
    } else {
        for(int i = 0; i < count; i++)
        {
            struct LHMemoryPatch patch = patches[i];
            MSHookMemory(patch.destination, patch.data, patch.size);
        }
        return 0;
    }
}

void HookMemory(Class class, SEL selector, uint64_t offset, uint32_t data) {
	void *final_offset = (void *)[class instanceMethodForSelector:selector] + offset;
	struct LHMemoryPatch patch;
	patch.destination = final_offset;
	patch.data = &data;
	patch.size = sizeof(data);
	patch.options = NULL;

	PatchMemory(&patch, 1);
}

void alert(UIView* object, NSString *title, NSString *message) {
    UIViewController *vc = object.window.rootViewController ?: [UIApplication sharedApplication].keyWindow.rootViewController;
    if (!vc) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:ok];
    [vc presentViewController:alert animated:YES completion:nil];
}

void showWordList(UIView *parentView, NSString *title, NSArray<NSString *> *words) {
    UIViewController *rootVC = parentView.window.rootViewController ?: [UIApplication sharedApplication].keyWindow.rootViewController;
    if (!rootVC) {
        alert(parentView, title, [words componentsJoinedByString:@"\n"]);
        return;
    }

    UIViewController *wordVC = [[UIViewController alloc] init];
    wordVC.modalPresentationStyle = UIModalPresentationPageSheet;

    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = wordVC.sheetPresentationController;
        if (sheet) {
            sheet.detents = @[UISheetPresentationControllerDetent.mediumDetent, UISheetPresentationControllerDetent.largeDetent];
            sheet.prefersGrabberVisible = YES;
        }
    }

    UIView *container = [[UIView alloc] initWithFrame:wordVC.view.bounds];
    container.backgroundColor = [UIColor systemBackgroundColor];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = [NSString stringWithFormat:@"%@ (%lu)", title, (unsigned long)words.count];
    titleLabel.font = [UIFont boldSystemFontOfSize:17];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:titleLabel];

    UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [copyButton setTitle:@"Copy All" forState:UIControlStateNormal];
    copyButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    copyButton.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:copyButton];

    UITextView *textView = [[UITextView alloc] init];
    textView.editable = NO;
    textView.font = [UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightRegular];
    textView.text = [words componentsJoinedByString:@"\n"];
    textView.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:textView];

    [copyButton addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
        [UIPasteboard generalPasteboard].string = textView.text;
        [copyButton setTitle:@"Copied!" forState:UIControlStateNormal];
    }] forControlEvents:UIControlEventTouchUpInside];

    wordVC.view = container;

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.safeAreaLayoutGuide.topAnchor constant:16],
        [titleLabel.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [copyButton.centerYAnchor constraintEqualToAnchor:titleLabel.centerYAnchor],
        [copyButton.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-16],
        [textView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:12],
        [textView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:16],
        [textView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-16],
        [textView.bottomAnchor constraintEqualToAnchor:container.safeAreaLayoutGuide.bottomAnchor constant:-16]
    ]];

    [rootVC presentViewController:wordVC animated:YES completion:nil];
}

static NSDictionary *gPreferences = nil;

void reloadPreferences(void) {
    CFPreferencesAppSynchronize(CFSTR("com.fiore.gameseagull.prefs"));
    CFArrayRef keyList = CFPreferencesCopyKeyList(CFSTR("com.fiore.gameseagull.prefs"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);

    if (keyList) {
        gPreferences = (__bridge_transfer NSDictionary *)CFPreferencesCopyMultiple(keyList, CFSTR("com.fiore.gameseagull.prefs"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        CFRelease(keyList);
    }

    if (!gPreferences) {
        gPreferences = [[NSDictionary alloc] initWithContentsOfFile:ROOT_PATH_NS(@"/var/mobile/Library/Preferences/com.fiore.gameseagull.prefs.plist")];
    }
}

NSDictionary *getPreferences(void) {
    if (!gPreferences) {
        reloadPreferences();
    }
    return gPreferences;
}

bool boolForKey(NSString *key) {
    NSDictionary *prefs = getPreferences();
    if (!prefs) return false;

    id val = prefs[key];
    return val ? [val boolValue] : false;
}

int intForKey(NSString *key, int defaultVal) {
    NSDictionary *prefs = getPreferences();
    if (!prefs) return defaultVal;

    id val = prefs[key];
    return val ? [val intValue] : defaultVal;
}

UIButton *makeButton(NSString *title, CGRect frame, id target, SEL selector) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setFrame:frame];
    [button setBackgroundColor:[[UIColor blackColor] colorWithAlphaComponent:0.75]];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    if (target && selector) {
        [button addTarget:target action:selector forControlEvents:UIControlEventTouchUpInside];
    }
    button.layer.cornerRadius = 14;
    button.layer.masksToBounds = YES;
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3].CGColor;
    return button;
}

SCNVector3 getAimbotPos(int multiplier, int number) {
	if (multiplier == 1 && number == 25) {
		return SCNVector3Make(0.0f, 0.325f, 0.0f);
	} else if (multiplier == 1 && number == 50) {
		return SCNVector3Make(0.0f, 0.35f, 0.0f);
	}
	
	if (multiplier < 1 || multiplier > 3 || number < 1 || number > 20) {
		return SCNVector3Make(0.0f, 0.35f, 0.0f);
	}

	static const float points[3][20][3] = {
		{
			{0.05f, 0.5f, 0.0f}, {0.2f, 0.0f, 0.0f}, {0.0f, 0.0f, 0.0f}, {0.2f, 0.5f, 0.0f},
			{-0.05f, 0.5f, 0.0f}, {0.2f, 0.35f, 0.0f}, {-0.2f, 0.0f, 0.0f}, {-0.2f, 0.3f, 0.0f},
			{-0.2f, 0.5f, 0.0f}, {0.2f, 0.3f, 0.0f}, {-0.2f, 0.35f, 0.0f}, {-0.1f, 0.5f, 0.0f},
			{0.2f, 0.4f, 0.0f}, {-0.2f, 0.4f, 0.0f}, {0.2f, 0.2f, 0.0f}, {-0.2f, 0.2f, 0.0f},
			{0.1f, 0.0f, 0.0f}, {0.1f, 0.5f, 0.0f}, {-0.1f, 0.0f, 0.0f}, {0.0f, 0.5f, 0.0f}
		},
		{
			{0.15f, 0.815f, 0.0f}, {0.26f, -0.05f, 0.0f}, {0.0f, -0.145f, 0.0f}, {0.4f, 0.625f, 0.0f},
			{-0.15f, 0.815f, 0.0f}, {0.49f, 0.35f, 0.0f}, {-0.26f, -0.05f, 0.0f}, {-0.47f, 0.175f, 0.0f},
			{-0.4f, 0.625f, 0.0f}, {0.47f, 0.175f, 0.0f}, {-0.49f, 0.35f, 0.0f}, {-0.26f, 0.75f, 0.0f},
			{0.47f, 0.46f, 0.0f}, {-0.47f, 0.46f, 0.0f}, {0.4f, 0.05f, 0.0f}, {-0.4f, 0.05f, 0.0f},
			{0.15f, -0.125f, 0.0f}, {0.26f, 0.75f, 0.0f}, {-0.15f, -0.125f, 0.0f}, {0.0f, 0.835f, 0.0f}
		},
		{
			{0.1f, 0.63f, 0.0f}, {0.175f, 0.1f, 0.0f}, {0.0f, 0.035f, 0.0f}, {0.25f, 0.53f, 0.0f},
			{-0.1f, 0.63f, 0.0f}, {0.3f, 0.35f, 0.0f}, {-0.175f, 0.1f, 0.0f}, {-0.28f, 0.25f, 0.0f},
			{-0.25f, 0.53f, 0.0f}, {0.28f, 0.25f, 0.0f}, {-0.3f, 0.35f, 0.0f}, {-0.175f, 0.59f, 0.0f},
			{0.28f, 0.45f, 0.0f}, {-0.28f, 0.45f, 0.0f}, {0.25f, 0.16f, 0.0f}, {-0.25f, 0.16f, 0.0f},
			{0.1f, 0.05f, 0.0f}, {0.175f, 0.59f, 0.0f}, {-0.1f, 0.05f, 0.0f}, {0.0f, 0.65f, 0.0f}
		}
	};

	const float *coords = points[multiplier - 1][number - 1];
	return SCNVector3Make(coords[0], coords[1], coords[2]);
}