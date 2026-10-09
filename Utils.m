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
    if (prefs && prefs[key]) {
        return [prefs[key] boolValue];
    }
    // Sideloaded / TrollStore fallback
    id userDefaultVal = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if (userDefaultVal) {
        return [userDefaultVal boolValue];
    }
    return false;
}

int intForKey(NSString *key, int defaultVal) {
    NSDictionary *prefs = getPreferences();
    if (prefs && prefs[key]) {
        return [prefs[key] intValue];
    }
    // Sideloaded / TrollStore fallback
    id userDefaultVal = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if (userDefaultVal) {
        return [userDefaultVal intValue];
    }
    return defaultVal;
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

void setBoolForKey(NSString *key, bool value) {
    CFPreferencesSetAppValue((__bridge CFStringRef)key, value ? kCFBooleanTrue : kCFBooleanFalse, CFSTR("com.fiore.gameseagull.prefs"));
    CFPreferencesAppSynchronize(CFSTR("com.fiore.gameseagull.prefs"));

    // Also write to standardUserDefaults for TrollStore/sideloading!
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];

    reloadPreferences();
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.fiore.gameseagull.prefs/ReloadPrefs"),
        NULL, NULL, YES
    );
}

void setIntForKey(NSString *key, int value) {
    CFNumberRef num = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &value);
    CFPreferencesSetAppValue((__bridge CFStringRef)key, num, CFSTR("com.fiore.gameseagull.prefs"));
    if (num) CFRelease(num);
    CFPreferencesAppSynchronize(CFSTR("com.fiore.gameseagull.prefs"));

    // Also write to standardUserDefaults for TrollStore/sideloading!
    [[NSUserDefaults standardUserDefaults] setInteger:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];

    reloadPreferences();
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.fiore.gameseagull.prefs/ReloadPrefs"),
        NULL, NULL, YES
    );
}

static CGFloat dotProduct2D(CGPoint a, CGPoint b) {
    return a.x * b.x + a.y * b.y;
}

CGFloat calculateBestPoolShotAngle(CGPoint cuePos, NSArray *balls, NSArray *pockets, CGFloat ballRadius) {
    if (!balls || balls.count == 0 || !pockets || pockets.count == 0) return 0.0f;
    if (ballRadius <= 0.0f) ballRadius = 15.0f;

    CGFloat bestScore = -1e9f;
    CGFloat bestAngle = 0.0f;
    BOOL foundShot = NO;

    for (SKNode *b in balls) {
        if ([b respondsToSelector:@selector(isStripes)] && [b respondsToSelector:@selector(isSolid)]) {
            if (![b performSelector:@selector(isStripes)] && ![b performSelector:@selector(isSolid)]) {
                continue; // Skip cue ball
            }
        }
        CGPoint bPos = b.position;

        for (SKNode *pkt in pockets) {
            CGPoint pPos = pkt.position;
            CGPoint toPkt = CGPointMake(pPos.x - bPos.x, pPos.y - bPos.y);
            CGFloat distPkt = hypot(toPkt.x, toPkt.y);
            if (distPkt < 1.0f) continue;
            CGPoint uPkt = CGPointMake(toPkt.x / distPkt, toPkt.y / distPkt);

            // Ghost ball contact center
            CGPoint ghostPos = CGPointMake(bPos.x - uPkt.x * (2.0f * ballRadius), bPos.y - uPkt.y * (2.0f * ballRadius));
            CGPoint toGhost = CGPointMake(ghostPos.x - cuePos.x, ghostPos.y - cuePos.y);
            CGFloat distCue = hypot(toGhost.x, toGhost.y);
            if (distCue < 1.0f) continue;
            CGPoint uCue = CGPointMake(toGhost.x / distCue, toGhost.y / distCue);

            CGFloat cutCosine = dotProduct2D(uCue, uPkt);
            if (cutCosine < 0.15f) continue; // Cut angle too sharp (>80 deg)

            // Raycast check: other balls blocking path
            BOOL blocked = NO;
            for (SKNode *other in balls) {
                if (other == b) continue;
                if ([other respondsToSelector:@selector(isStripes)] && [other respondsToSelector:@selector(isSolid)]) {
                    if (![other performSelector:@selector(isStripes)] && ![other performSelector:@selector(isSolid)]) continue;
                }
                CGPoint oPos = other.position;
                CGPoint toOther = CGPointMake(oPos.x - cuePos.x, oPos.y - cuePos.y);
                CGFloat proj = dotProduct2D(toOther, uCue);
                if (proj > ballRadius && proj < distCue - ballRadius) {
                    CGFloat perpSq = (toOther.x * toOther.x + toOther.y * toOther.y) - (proj * proj);
                    if (perpSq < (4.0f * ballRadius * ballRadius * 0.9f)) {
                        blocked = YES;
                        break;
                    }
                }
            }
            if (blocked) continue;

            CGFloat shotScore = cutCosine * 150.0f - (distCue * 0.08f + distPkt * 0.04f);
            if (shotScore > bestScore) {
                bestScore = shotScore;
                bestAngle = atan2f(uCue.y, uCue.x);
                foundShot = YES;
            }
        }
    }

    return foundShot ? bestAngle : 0.0f;
}

// ==================== CONNECT 4 SOLVER ====================

static BOOL checkConnect4Win(const int g[6][7], int p) {
    for (int r = 0; r < 6; r++) {
        for (int c = 0; c < 4; c++) {
            if (g[r][c] == p && g[r][c+1] == p && g[r][c+2] == p && g[r][c+3] == p) return YES;
        }
    }
    for (int c = 0; c < 7; c++) {
        for (int r = 0; r < 3; r++) {
            if (g[r][c] == p && g[r+1][c] == p && g[r+2][c] == p && g[r+3][c] == p) return YES;
        }
    }
    for (int r = 0; r < 3; r++) {
        for (int c = 0; c < 4; c++) {
            if (g[r][c] == p && g[r+1][c+1] == p && g[r+2][c+2] == p && g[r+3][c+3] == p) return YES;
        }
    }
    for (int r = 3; r < 6; r++) {
        for (int c = 0; c < 4; c++) {
            if (g[r][c] == p && g[r-1][c+1] == p && g[r-2][c+2] == p && g[r-3][c+3] == p) return YES;
        }
    }
    return NO;
}

static int getTopRow(const int g[6][7], int c) {
    for (int r = 0; r < 6; r++) {
        if (g[r][c] == 0) return r;
    }
    return -1;
}

Connect4Evaluation evaluateConnect4Grid(const int grid[6][7], int player) {
    Connect4Evaluation eval;
    int opponent = (player == 1) ? 2 : 1;
    int bestCol = 3;
    int bestScore = -99999;

    for (int c = 0; c < 7; c++) {
        int r = getTopRow(grid, c);
        if (r == -1) {
            eval.columnScores[c] = -99999;
            continue;
        }

        int temp[6][7];
        memcpy(temp, grid, sizeof(temp));
        temp[r][c] = player;

        if (checkConnect4Win(temp, player)) {
            eval.columnScores[c] = 10000;
            if (eval.columnScores[c] > bestScore) {
                bestScore = eval.columnScores[c];
                bestCol = c;
            }
            continue;
        }

        if (r + 1 < 6) {
            temp[r+1][c] = opponent;
            if (checkConnect4Win(temp, opponent)) {
                eval.columnScores[c] = -10000;
                if (eval.columnScores[c] > bestScore) {
                    bestScore = eval.columnScores[c];
                    bestCol = c;
                }
                continue;
            }
            temp[r+1][c] = 0;
        }

        BOOL blocksWin = NO;
        int oppTemp[6][7];
        memcpy(oppTemp, grid, sizeof(oppTemp));
        oppTemp[r][c] = opponent;
        if (checkConnect4Win(oppTemp, opponent)) {
            blocksWin = YES;
        }

        int score = 0;
        if (blocksWin) {
            score = 8000;
        } else {
            int centerBias = 3 - abs(c - 3);
            score = centerBias * 25;

            for (int oc = 0; oc < 7; oc++) {
                int orow = getTopRow(temp, oc);
                if (orow != -1) {
                    temp[orow][oc] = opponent;
                    if (checkConnect4Win(temp, opponent)) {
                        score -= 500;
                    }
                    temp[orow][oc] = 0;
                }
            }
        }

        eval.columnScores[c] = score;
        if (score > bestScore) {
            bestScore = score;
            bestCol = c;
        }
    }

    eval.bestColumn = bestCol;
    return eval;
}

// ==================== MANCALA SOLVER ====================

MancalaPitEvaluation evaluateMancalaPit(const int board[14], int pitIndex, int player) {
    MancalaPitEvaluation eval;
    eval.isFreeTurn = NO;
    eval.isCapture = NO;
    eval.seedsCaptured = 0;
    eval.advantage = 0;

    int minPit = (player == 1) ? 0 : 7;
    int maxPit = (player == 1) ? 5 : 12;
    int myStore = (player == 1) ? 6 : 13;
    int oppStore = (player == 1) ? 13 : 6;

    if (pitIndex < minPit || pitIndex > maxPit) return eval;
    int seeds = board[pitIndex];
    if (seeds <= 0) return eval;

    int simBoard[14];
    memcpy(simBoard, board, sizeof(simBoard));
    simBoard[pitIndex] = 0;

    int curr = pitIndex;
    while (seeds > 0) {
        curr = (curr + 1) % 14;
        if (curr == oppStore) continue;
        simBoard[curr]++;
        seeds--;
    }

    if (curr == myStore) {
        eval.isFreeTurn = YES;
        eval.advantage += 100;
    } else if (curr >= minPit && curr <= maxPit && simBoard[curr] == 1) {
        int oppositePit = 12 - curr;
        if (simBoard[oppositePit] > 0) {
            eval.isCapture = YES;
            eval.seedsCaptured = simBoard[oppositePit] + 1;
            eval.advantage += eval.seedsCaptured * 15;
        }
    }

    eval.advantage += (simBoard[myStore] - board[myStore]) * 5;
    return eval;
}

int getBestMancalaPit(const int board[14], int player) {
    int minPit = (player == 1) ? 0 : 7;
    int maxPit = (player == 1) ? 5 : 12;
    int bestPit = minPit;
    int maxAdv = -1;

    for (int p = minPit; p <= maxPit; p++) {
        if (board[p] <= 0) continue;
        MancalaPitEvaluation eval = evaluateMancalaPit(board, p, player);
        if (eval.isFreeTurn) {
            return p;
        }
        if (eval.advantage > maxAdv) {
            maxAdv = eval.advantage;
            bestPit = p;
        }
    }
    return bestPit;
}

// ==================== DOTS & BOXES SOLVER ====================

DotsLineQuality evaluateDotsLineQuality(int countBoxA, int countBoxB) {
    if (countBoxA == 3 && countBoxB == 3) return DOTS_MOVE_DOUBLE;
    if (countBoxA == 3 || countBoxB == 3) return DOTS_MOVE_CAPTURE;
    if (countBoxA == 2 || countBoxB == 2) return DOTS_MOVE_DANGER;
    return DOTS_MOVE_SAFE;
}

// ==================== GOMOKU THREAT SCANNER ====================

GomokuMove evaluateGomokuGrid(const int grid[15][15], int player) {
    GomokuMove move;
    move.bestRow = 7;
    move.bestCol = 7;
    move.threatLevel = 0;

    int opponent = (player == 1) ? 2 : 1;
    int bestScore = -1;

    const int dr[4] = {0, 1, 1, 1};
    const int dc[4] = {1, 0, 1, -1};

    for (int r = 0; r < 15; r++) {
        for (int c = 0; c < 15; c++) {
            if (grid[r][c] != 0) continue;

            int score = 0;
            for (int dir = 0; dir < 4; dir++) {
                int pCount = 0, oCount = 0;
                for (int step = 1; step <= 4; step++) {
                    int nr = r + dr[dir] * step, nc = c + dc[dir] * step;
                    if (nr < 0 || nr >= 15 || nc < 0 || nc >= 15) break;
                    if (grid[nr][nc] == player) pCount++;
                    else if (grid[nr][nc] == opponent) oCount++;
                    else break;
                }
                for (int step = 1; step <= 4; step++) {
                    int nr = r - dr[dir] * step, nc = c - dc[dir] * step;
                    if (nr < 0 || nr >= 15 || nc < 0 || nc >= 15) break;
                    if (grid[nr][nc] == player) pCount++;
                    else if (grid[nr][nc] == opponent) oCount++;
                    else break;
                }

                if (pCount >= 4) score += 10000;      // 5 in a row win!
                else if (oCount >= 4) score += 8000;  // Urgent block!
                else if (pCount == 3) score += 2000;  // Open 4
                else if (oCount == 3) score += 1500;  // Block open 3
                else if (pCount == 2) score += 300;
            }

            int distCenter = abs(r - 7) + abs(c - 7);
            score += (14 - distCenter) * 2;

            if (score > bestScore) {
                bestScore = score;
                move.bestRow = r;
                move.bestCol = c;
                move.threatLevel = score;
            }
        }
    }

    return move;
}

// ==================== REVERSI / OTHELLO STRATEGIC SOLVER ====================

ReversiEvaluation evaluateReversiBoard(const int board[8][8], int player) {
    ReversiEvaluation eval;
    memset(&eval, 0, sizeof(eval));
    eval.bestRow = -1;
    eval.bestCol = -1;

    static const int posWeights[8][8] = {
        { 100, -35,  15,  10,  10,  15, -35, 100 },
        { -35, -50,  -5,  -5,  -5,  -5, -50, -35 },
        {  15,  -5,   5,   2,   2,   5,  -5,  15 },
        {  10,  -5,   2,   1,   1,   2,  -5,  10 },
        {  10,  -5,   2,   1,   1,   2,  -5,  10 },
        {  15,  -5,   5,   2,   2,   5,  -5,  15 },
        { -35, -50,  -5,  -5,  -5,  -5, -50, -35 },
        { 100, -35,  15,  10,  10,  15, -35, 100 }
    };

    int opponent = (player == 1) ? 2 : 1;
    int bestScore = -999999;
    static const int dirs[8][2] = {
        {-1,-1},{-1,0},{-1,1},
        { 0,-1},       { 0,1},
        { 1,-1},{ 1,0},{ 1,1}
    };

    for (int r = 0; r < 8; r++) {
        for (int c = 0; c < 8; c++) {
            eval.scores[r][c] = -1000;
            if (board[r][c] != 0) continue;

            int totalFlips = 0;
            for (int d = 0; d < 8; d++) {
                int dr = dirs[d][0];
                int dc = dirs[d][1];
                int nr = r + dr;
                int nc = c + dc;
                int count = 0;
                while (nr >= 0 && nr < 8 && nc >= 0 && nc < 8 && board[nr][nc] == opponent) {
                    count++;
                    nr += dr;
                    nc += dc;
                }
                if (count > 0 && nr >= 0 && nr < 8 && nc >= 0 && nc < 8 && board[nr][nc] == player) {
                    totalFlips += count;
                }
            }

            if (totalFlips > 0) {
                int score = posWeights[r][c] + totalFlips * 10;
                eval.scores[r][c] = score;
                if (score > bestScore) {
                    bestScore = score;
                    eval.bestRow = r;
                    eval.bestCol = c;
                    eval.maxFlips = totalFlips;
                }
            }
        }
    }
    return eval;
}

// ==================== CHECKERS AI EVALUATOR ====================

CheckersEvaluation evaluateCheckersMoves(const int board[8][8], int player) {
    CheckersEvaluation eval;
    memset(&eval, 0, sizeof(eval));
    eval.fromRow = -1; eval.fromCol = -1;
    eval.toRow = -1; eval.toCol = -1;
    eval.score = -10000;

    int opponentNormal = (player == 1) ? 2 : 1;
    int opponentKing = (player == 1) ? 4 : 3;
    int forward = (player == 1) ? 1 : -1;

    // Check jumps first (mandatory in Checkers)
    for (int r = 0; r < 8; r++) {
        for (int c = 0; c < 8; c++) {
            int piece = board[r][c];
            if (piece != player && piece != (player + 2)) continue;
            BOOL isKing = (piece == (player + 2));

            static const int dRow[4] = { 1, 1, -1, -1 };
            static const int dCol[4] = { -1, 1, -1, 1 };
            for (int i = 0; i < 4; i++) {
                int dr = dRow[i];
                int dc = dCol[i];
                if (!isKing && dr != forward) continue;

                int midR = r + dr;
                int midC = c + dc;
                int endR = r + 2 * dr;
                int endC = c + 2 * dc;

                if (endR >= 0 && endR < 8 && endC >= 0 && endC < 8 && midR >= 0 && midR < 8 && midC >= 0 && midC < 8) {
                    int midP = board[midR][midC];
                    if ((midP == opponentNormal || midP == opponentKing) && board[endR][endC] == 0) {
                        int jumpScore = 1000 + (midP == opponentKing ? 500 : 0);
                        if (jumpScore > eval.score) {
                            eval.score = jumpScore;
                            eval.fromRow = r; eval.fromCol = c;
                            eval.toRow = endR; eval.toCol = endC;
                            eval.isJump = YES;
                        }
                    }
                }
            }
        }
    }

    // If no jumps available, evaluate regular advancement moves
    if (eval.score < 0) {
        for (int r = 0; r < 8; r++) {
            for (int c = 0; c < 8; c++) {
                int piece = board[r][c];
                if (piece != player && piece != (player + 2)) continue;
                BOOL isKing = (piece == (player + 2));

                static const int dRow[4] = { 1, 1, -1, -1 };
                static const int dCol[4] = { -1, 1, -1, 1 };
                for (int i = 0; i < 4; i++) {
                    int dr = dRow[i];
                    int dc = dCol[i];
                    if (!isKing && dr != forward) continue;

                    int endR = r + dr;
                    int endC = c + dc;
                    if (endR >= 0 && endR < 8 && endC >= 0 && endC < 8 && board[endR][endC] == 0) {
                        int moveScore = (isKing ? 60 : 25) + (3 - abs(endC - 3)) * 8;
                        if ((player == 1 && endR == 7) || (player == 2 && endR == 0)) {
                            moveScore += 350; // Crown promotion
                        }
                        if (moveScore > eval.score) {
                            eval.score = moveScore;
                            eval.fromRow = r; eval.fromCol = c;
                            eval.toRow = endR; eval.toCol = endC;
                            eval.isJump = NO;
                        }
                    }
                }
            }
        }
    }
    return eval;
}

// ==================== FILLER SOLVER ====================

int getBestFillerColor(const int grid[12][8], int player1Color, int player2Color, int player) {
    int currentColor = (player == 1) ? player1Color : player2Color;
    int opponentColor = (player == 1) ? player2Color : player1Color;

    int visited[12][8] = {0};
    int queue[96][2];
    int qHead = 0, qTail = 0;

    int startR = (player == 1) ? 11 : 0;
    int startC = (player == 1) ? 0 : 7;
    queue[qTail][0] = startR;
    queue[qTail][1] = startC;
    qTail++;
    visited[startR][startC] = 1;

    static const int dirs[4][2] = {{-1,0},{1,0},{0,-1},{0,1}};
    while (qHead < qTail) {
        int cr = queue[qHead][0];
        int cc = queue[qHead][1];
        qHead++;

        for (int i = 0; i < 4; i++) {
            int nr = cr + dirs[i][0];
            int nc = cc + dirs[i][1];
            if (nr >= 0 && nr < 12 && nc >= 0 && nc < 8 && !visited[nr][nc]) {
                if (grid[nr][nc] == currentColor) {
                    visited[nr][nc] = 1;
                    queue[qTail][0] = nr;
                    queue[qTail][1] = nc;
                    qTail++;
                }
            }
        }
    }

    int bestColor = -1;
    int maxAbsorbed = -1;

    for (int col = 0; col < 6; col++) {
        if (col == currentColor || col == opponentColor) continue;

        int absorbed = 0;
        int checked[12][8] = {0};
        for (int r = 0; r < 12; r++) {
            for (int c = 0; c < 8; c++) {
                if (visited[r][c]) {
                    for (int i = 0; i < 4; i++) {
                        int nr = r + dirs[i][0];
                        int nc = c + dirs[i][1];
                        if (nr >= 0 && nr < 12 && nc >= 0 && nc < 8 && !visited[nr][nc] && !checked[nr][nc]) {
                            if (grid[nr][nc] == col) {
                                checked[nr][nc] = 1;
                                absorbed++;
                            }
                        }
                    }
                }
            }
        }

        if (absorbed > maxAbsorbed) {
            maxAbsorbed = absorbed;
            bestColor = col;
        }
    }
    return (bestColor >= 0) ? bestColor : 0;
}

// ==================== SHUFFLEBOARD & POOL PHYSICS HELPERS ====================

CGPoint calculateShuffleImpulse(CGSize sceneSize) {
    CGFloat targetY = sceneSize.height * 0.78f;
    return CGPointMake(0.0f, targetY * 1.65f);
}

CGPoint applyPoolPocketMagnet(CGPoint ballPos, CGPoint ballVel, NSArray *pockets, CGFloat magnetRadius) {
    if (!pockets || pockets.count == 0) return ballVel;
    for (NSValue *val in pockets) {
        CGPoint pkt = [val CGPointValue];
        CGFloat dx = pkt.x - ballPos.x;
        CGFloat dy = pkt.y - ballPos.y;
        CGFloat dist = hypot(dx, dy);
        if (dist > 0.001f && dist < magnetRadius) {
            CGFloat pull = (1.0f - dist / magnetRadius) * 0.35f;
            return CGPointMake(ballVel.x + (dx / dist) * pull, ballVel.y + (dy / dist) * pull);
        }
    }
    return ballVel;
}

// ==================== SEAGULL IN-GAME FLOATING HUD ====================

@interface SeagullHUD ()
@property (nonatomic, strong) UIButton *floatingPill;
@property (nonatomic, strong) UIVisualEffectView *menuContainer;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *gameSubtitle;
@property (nonatomic, strong) UIStackView *stackView;
@property (nonatomic, assign) BOOL isExpanded;
@end

@implementation SeagullHUD

static SeagullHUD *gSharedHUD = nil;

+ (instancetype)sharedHUD {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gSharedHUD = [[SeagullHUD alloc] initWithFrame:CGRectZero];
    });
    return gSharedHUD;
}

+ (void)attachToView:(UIView *)parentView gameType:(NSString *)gameType target:(id)target {
    if (!parentView) return;
    SeagullHUD *hud = [SeagullHUD sharedHUD];
    hud.currentGameType = gameType;
    hud.currentTarget = target;

    if (hud.superview != parentView) {
        [hud removeFromSuperview];
        CGFloat xPos = parentView.bounds.size.width > 60 ? parentView.bounds.size.width - 58.0 : 20.0;
        hud.frame = CGRectMake(xPos, 110.0, 48.0, 48.0);
        [parentView addSubview:hud];
        [parentView bringSubviewToFront:hud];
    }
    [hud updateContentForGame:gameType];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.isExpanded = NO;
        self.clipsToBounds = NO;

        _floatingPill = [UIButton buttonWithType:UIButtonTypeCustom];
        _floatingPill.frame = CGRectMake(0, 0, 48, 48);
        _floatingPill.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.12 alpha:0.85];
        [_floatingPill setTitle:@"🕊️" forState:UIControlStateNormal];
        _floatingPill.titleLabel.font = [UIFont systemFontOfSize:22];
        _floatingPill.layer.cornerRadius = 24;
        _floatingPill.layer.borderWidth = 1.5;
        _floatingPill.layer.borderColor = [UIColor colorWithRed:0.2 green:0.8 blue:1.0 alpha:0.7].CGColor;
        _floatingPill.layer.shadowColor = [UIColor blackColor].CGColor;
        _floatingPill.layer.shadowOpacity = 0.5;
        _floatingPill.layer.shadowRadius = 8;
        _floatingPill.layer.shadowOffset = CGSizeMake(0, 4);
        [_floatingPill addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_floatingPill];

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [_floatingPill addGestureRecognizer:pan];

        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        _menuContainer = [[UIVisualEffectView alloc] initWithEffect:blur];
        _menuContainer.frame = CGRectZero;
        _menuContainer.layer.cornerRadius = 20;
        _menuContainer.layer.masksToBounds = YES;
        _menuContainer.layer.borderWidth = 1.0;
        _menuContainer.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.25].CGColor;
        _menuContainer.alpha = 0.0;
        _menuContainer.hidden = YES;
        [self addSubview:_menuContainer];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.text = @"🕊️ GameSeagull v3.0";
        _titleLabel.font = [UIFont boldSystemFontOfSize:16];
        _titleLabel.textColor = [UIColor whiteColor];

        _gameSubtitle = [[UILabel alloc] init];
        _gameSubtitle.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        _gameSubtitle.textColor = [UIColor colorWithRed:0.4 green:0.85 blue:1.0 alpha:1.0];

        UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
        [closeBtn setTitleColor:[UIColor lightTextColor] forState:UIControlStateNormal];
        closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        [closeBtn addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];

        _stackView = [[UIStackView alloc] init];
        _stackView.axis = UILayoutConstraintAxisVertical;
        _stackView.spacing = 10.0;
        _stackView.alignment = UIStackViewAlignmentFill;
        _stackView.distribution = UIStackViewDistributionFill;

        _scrollView = [[UIScrollView alloc] init];
        _scrollView.showsVerticalScrollIndicator = YES;
        [_scrollView addSubview:_stackView];

        UIView *content = _menuContainer.contentView;
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _gameSubtitle.translatesAutoresizingMaskIntoConstraints = NO;
        closeBtn.translatesAutoresizingMaskIntoConstraints = NO;
        _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
        _stackView.translatesAutoresizingMaskIntoConstraints = NO;

        [content addSubview:_titleLabel];
        [content addSubview:_gameSubtitle];
        [content addSubview:closeBtn];
        [content addSubview:_scrollView];

        [NSLayoutConstraint activateConstraints:@[
            [_titleLabel.topAnchor constraintEqualToAnchor:content.topAnchor constant:14],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
            [_gameSubtitle.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:2],
            [_gameSubtitle.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
            [closeBtn.centerYAnchor constraintEqualToAnchor:_titleLabel.centerYAnchor],
            [closeBtn.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-14],
            [closeBtn.widthAnchor constraintEqualToConstant:30],
            [closeBtn.heightAnchor constraintEqualToConstant:30],
            [_scrollView.topAnchor constraintEqualToAnchor:_gameSubtitle.bottomAnchor constant:12],
            [_scrollView.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:14],
            [_scrollView.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-14],
            [_scrollView.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-14],
            [_stackView.topAnchor constraintEqualToAnchor:_scrollView.topAnchor],
            [_stackView.leadingAnchor constraintEqualToAnchor:_scrollView.leadingAnchor],
            [_stackView.trailingAnchor constraintEqualToAnchor:_scrollView.trailingAnchor],
            [_stackView.bottomAnchor constraintEqualToAnchor:_scrollView.bottomAnchor],
            [_stackView.widthAnchor constraintEqualToAnchor:_scrollView.widthAnchor]
        ]];
    }
    return self;
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    if (self.isExpanded) return;
    UIView *parent = self.superview;
    if (!parent) return;

    CGPoint translation = [pan translationInView:parent];
    CGPoint center = self.center;
    center.x += translation.x;
    center.y += translation.y;

    // Bounds clamp
    CGFloat halfW = 24.0, halfH = 24.0;
    center.x = fmaxf(halfW, fminf(parent.bounds.size.width - halfW, center.x));
    center.y = fmaxf(halfH + 60.0, fminf(parent.bounds.size.height - halfH - 20.0, center.y));
    self.center = center;
    [pan setTranslation:CGPointZero inView:parent];
}

- (void)toggleMenu {
    self.isExpanded = !self.isExpanded;
    UIView *parent = self.superview;
    if (!parent) return;

    if (self.isExpanded) {
        CGFloat hudW = fminf(330.0, parent.bounds.size.width - 32.0);
        CGFloat hudH = 340.0;
        CGFloat originX = (parent.bounds.size.width - hudW) / 2.0;
        CGFloat originY = 110.0;

        self.frame = CGRectMake(0, 0, parent.bounds.size.width, parent.bounds.size.height);
        self.menuContainer.frame = CGRectMake(originX, originY, hudW, hudH);
        self.menuContainer.hidden = NO;
        self.floatingPill.hidden = YES;

        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:0 animations:^{
            self.menuContainer.alpha = 1.0;
        } completion:nil];
    } else {
        [UIView animateWithDuration:0.25 animations:^{
            self.menuContainer.alpha = 0.0;
        } completion:^(BOOL finished) {
            self.menuContainer.hidden = YES;
            self.floatingPill.hidden = NO;
            CGFloat xPos = parent.bounds.size.width - 58.0;
            self.frame = CGRectMake(xPos, 110.0, 48.0, 48.0);
        }];
    }
}

- (void)addToggleWithTitle:(NSString *)title key:(NSString *)key {
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 280, 40)];
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 8, 210, 24)];
    lbl.text = title;
    lbl.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    lbl.textColor = [UIColor whiteColor];
    [row addSubview:lbl];

    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(220, 4, 51, 31)];
    sw.on = boolForKey(key);
    sw.onTintColor = [UIColor colorWithRed:0.1 green:0.8 blue:0.95 alpha:1.0];
    [sw addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
        setBoolForKey(key, sw.isOn);
    }] forControlEvents:UIControlEventValueChanged];
    [row addSubview:sw];
    [row.heightAnchor constraintEqualToConstant:40].active = YES;
    [self.stackView addArrangedSubview:row];
}

- (void)addActionButtonWithTitle:(NSString *)title icon:(NSString *)icon selector:(SEL)sel {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:[NSString stringWithFormat:@"%@  %@", icon, title] forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    btn.backgroundColor = [UIColor colorWithWhite:0.22 alpha:0.8];
    btn.layer.cornerRadius = 12;
    btn.layer.borderWidth = 1.0;
    btn.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.2].CGColor;
    [btn.heightAnchor constraintEqualToConstant:38].active = YES;

    if (self.currentTarget && [self.currentTarget respondsToSelector:sel]) {
        [btn addTarget:self.currentTarget action:sel forControlEvents:UIControlEventTouchUpInside];
    }
    [self.stackView addArrangedSubview:btn];
}

- (void)updateContentForGame:(NSString *)gameType {
    for (UIView *sub in self.stackView.arrangedSubviews) {
        [self.stackView removeArrangedSubview:sub];
        [sub removeFromSuperview];
    }
    self.gameSubtitle.text = [NSString stringWithFormat:@"Active: %@", gameType ?: @"GamePigeon"];

    if ([gameType containsString:@"Pool"]) {
        [self addActionButtonWithTitle:@"Auto-Aim Best Ball" icon:@"🎯" selector:@selector(autoAimBestBall)];
        [self addToggleWithTitle:@"Break To Win 1-Turn" key:@"kPoolBreakToOneTurnWin"];
        [self addToggleWithTitle:@"Full Trajectory Raycast" key:@"kPoolFullTrajectory"];
        [self addToggleWithTitle:@"RGB Cue Guide" key:@"kRGBLine"];
        [self addToggleWithTitle:@"Always Move Cue Ball" key:@"kAlwaysMoveCueBall"];
    } else if ([gameType containsString:@"Golf"]) {
        [self addActionButtonWithTitle:@"Stealth Hole-In-One" icon:@"⛳" selector:@selector(autoShootHoleInOne)];
        [self addToggleWithTitle:@"Physics Bounce Map" key:@"kGolfTrajectoryMap"];
        [self addToggleWithTitle:@"Stealth Putt Solver" key:@"kGolfAutoPuttStealth"];
        [self addToggleWithTitle:@"Infinite Golf Shots" key:@"kHoleInOne"];
        [self addToggleWithTitle:@"Legit Mode (2+ Strokes)" key:@"kGolfLegitMode"];
    } else if ([gameType containsString:@"Word"] || [gameType containsString:@"Anagrams"]) {
        [self addActionButtonWithTitle:@"Auto-Solve Words" icon:@"⚡" selector:@selector(winGame)];
        [self addActionButtonWithTitle:@"View Full Word List" icon:@"📋" selector:@selector(revealAllWordsInSheet)];
        [self addToggleWithTitle:@"Auto Enter Words" key:@"kAutoEnterWords"];
        [self addToggleWithTitle:@"Reveal Words Button" key:@"kRevealWords"];
    } else if ([gameType containsString:@"Beer"] || [gameType containsString:@"Pong"]) {
        [self addActionButtonWithTitle:@"100% Swish Shot" icon:@"🎯" selector:@selector(shootRandomCup)];
        [self addToggleWithTitle:@"One Cup Win" key:@"kOneCup"];
        [self addToggleWithTitle:@"Auto Cup Pong" key:@"kAutoCupPong"];
    } else if ([gameType containsString:@"Sea"] || [gameType containsString:@"Battle"]) {
        [self addActionButtonWithTitle:@"Auto-Sink Enemy Fleet" icon:@"💥" selector:@selector(autoSinkEnemyFleet)];
        [self addToggleWithTitle:@"ESP Reveal Enemy Ships" key:@"kSeeEnemies"];
    } else if ([gameType containsString:@"Connect"] || [gameType containsString:@"Four"]) {
        [self addToggleWithTitle:@"AI Minimax Move Guide" key:@"kConnect4Overlay"];
    } else if ([gameType containsString:@"Mancala"]) {
        [self addToggleWithTitle:@"Kalah Extra Turn Badges" key:@"kMancalaOverlay"];
    } else if ([gameType containsString:@"Dots"]) {
        [self addToggleWithTitle:@"Safe Line Color Guide" key:@"kDotsOverlay"];
    } else if ([gameType containsString:@"Basket"]) {
        [self addActionButtonWithTitle:@"Auto-Swish Basket" icon:@"🏀" selector:@selector(gp_autoSwishShoot)];
        [self addToggleWithTitle:@"Freeze Timer" key:@"kBasketInfiniteTimer"];
    } else if ([gameType containsString:@"Tanks"]) {
        [self addToggleWithTitle:@"Zero Wind" key:@"kTanksDisableWind"];
        [self addToggleWithTitle:@"Persistent Trajectory" key:@"kTanksTrajectory"];
    } else if ([gameType containsString:@"Darts"]) {
        [self addToggleWithTitle:@"Darts Aimbot" key:@"kDartsAimbot"];
        [self addToggleWithTitle:@"One Dart Win" key:@"kOneDart"];
    } else if ([gameType containsString:@"Archery"]) {
        [self addToggleWithTitle:@"Disable Wind" key:@"kArcheryDisableWind"];
        [self addToggleWithTitle:@"Infinite Timer" key:@"kDisableTimer"];
    } else if ([gameType containsString:@"Checkers"]) {
        [self addActionButtonWithTitle:@"Auto-Play Best Jump" icon:@"👑" selector:@selector(autoPlayBestCheckersMove)];
        [self addToggleWithTitle:@"Move Guide Overlay" key:@"kCheckersOverlay"];
    } else if ([gameType containsString:@"Chess"]) {
        [self addToggleWithTitle:@"AI Best Move Hint" key:@"kChessOverlay"];
    } else if ([gameType containsString:@"Reversi"]) {
        [self addActionButtonWithTitle:@"Auto-Play Best Move" icon:@"⭐" selector:@selector(autoPlayBestReversiMove)];
        [self addToggleWithTitle:@"Corner & Mobility Heatmap" key:@"kReversiOverlay"];
    } else if ([gameType containsString:@"Fill"]) {
        [self addActionButtonWithTitle:@"Auto-Pick Best Color" icon:@"🎨" selector:@selector(autoPickBestColor)];
        [self addActionButtonWithTitle:@"Instant Win" icon:@"🏆" selector:@selector(instantWin)];
    } else if ([gameType containsString:@"Paint"]) {
        [self addActionButtonWithTitle:@"Auto-Aim Enemy" icon:@"🎯" selector:@selector(autoAimEnemy)];
        [self addToggleWithTitle:@"ESP Reveal Enemy" key:@"kPaintESP"];
    } else if ([gameType containsString:@"Shuffle"]) {
        [self addActionButtonWithTitle:@"Perfect 3-Point Shot" icon:@"🎯" selector:@selector(launchPerfectPuck)];
    } else if ([gameType containsString:@"Crazy"]) {
        [self addActionButtonWithTitle:@"Instant Win" icon:@"🏆" selector:@selector(instantWin)];
    } else if ([gameType containsString:@"Knock"]) {
        [self addActionButtonWithTitle:@"Super Impulse Shot" icon:@"🚀" selector:@selector(superPuckShoot)];
    } else {
        [self addToggleWithTitle:@"Floating In-Game HUD" key:@"kFloatingHUD"];
        [self addToggleWithTitle:@"Word Solvers" key:@"kAutoEnterWords"];
        [self addToggleWithTitle:@"Pool Trajectory" key:@"kPoolFullTrajectory"];
    }

    // Always provide shortcut to Full Settings & Spoof Wins in HUD
    [self addActionButtonWithTitle:@"Settings & Spoof Wins" icon:@"⚙️" selector:@selector(openSettingsMenu)];
}

- (void)openSettingsMenu {
    [self toggleMenu];
    presentGameSeagullSettings(self.superview ?: self);
}

@end

// ==================== IN-GAME SETTINGS & WIN SPOOFER ====================

typedef struct {
    const char *name;
    const char *key;
} GameSpoofEntry;

static const GameSpoofEntry kGameSpoofEntries[] = {
    {"8 Ball", "pool"},
    {"9 Ball", "pool2"},
    {"Sea Battle", "sea"},
    {"Basketball", "basketball"},
    {"Archery", "archery"},
    {"Anagrams", "anagrams"},
    {"Word Hunt", "hunt"},
    {"Word Bites", "wordbites"},
    {"Darts", "darts"},
    {"Cup Pong", "beer"},
    {"Mini Golf", "golf"},
    {"Knock Out", "knock"},
    {"Crazy 8", "crazy"},
    {"Four in a Row", "connect"},
    {"Paintball", "paint"},
    {"Shuffleboard", "suffle"},
    {"Tanks", "tanks"},
    {"Filler", "fill"},
    {"Checkers", "checkers"},
    {"Chess", "chess"},
    {"Mancala", "mancala"},
    {"Gomoku", "renju"},
    {"Reversi", "reversi"},
    {"20 Questions", "questions"}
};
static const int kGameSpoofCount = sizeof(kGameSpoofEntries) / sizeof(kGameSpoofEntries[0]);

@interface GSPInGameWinSpooferController : UITableViewController <UITextFieldDelegate>
@end

@implementation GSPInGameWinSpooferController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Spoof Wins";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(doneTapped)];
}

- (void)doneTapped {
    [self.view endEditing:YES];
    reloadPreferences();
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.fiore.gameseagull.prefs/ReloadPrefs"),
        NULL, NULL, YES
    );
    [self.navigationController popViewControllerAnimated:YES];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"Enter your desired wins. Leave empty or 0 to display real wins.";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return kGameSpoofCount;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"SpoofCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 100, 32)];
        tf.textAlignment = NSTextAlignmentRight;
        tf.keyboardType = UIKeyboardTypeNumberPad;
        tf.placeholder = @"0";
        tf.tag = 1001;
        cell.accessoryView = tf;
    }

    GameSpoofEntry entry = kGameSpoofEntries[indexPath.row];
    cell.textLabel.text = [NSString stringWithUTF8String:entry.name];

    UITextField *tf = (UITextField *)cell.accessoryView;
    NSString *key = [NSString stringWithUTF8String:entry.key];

    NSString *val = [[NSUserDefaults standardUserDefaults] stringForKey:key];
    if (!val || val.length == 0) {
        val = getPreferences()[key];
    }
    tf.text = (val && [val intValue] > 0) ? val : @"";

    [tf removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    [tf addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
        NSString *newVal = tf.text;
        [[NSUserDefaults standardUserDefaults] setObject:newVal forKey:key];
        [[NSUserDefaults standardUserDefaults] synchronize];
        CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)newVal, CFSTR("com.fiore.gameseagull.prefs"));
        CFPreferencesAppSynchronize(CFSTR("com.fiore.gameseagull.prefs"));
    }] forControlEvents:UIControlEventEditingChanged];

    return cell;
}

@end

typedef struct {
    const char *label;
    const char *key;
} CheatSwitchEntry;

@interface GSPInGameSettingsController : UITableViewController
@end

@implementation GSPInGameSettingsController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"GameSeagull";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(doneTapped)];
}

- (void)doneTapped {
    reloadPreferences();
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.fiore.gameseagull.prefs/ReloadPrefs"),
        NULL, NULL, YES
    );
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 7;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"Profile & Wins";
        case 1: return @"Universal";
        case 2: return @"8 Ball & 9 Ball Pool";
        case 3: return @"Mini Golf";
        case 4: return @"Word Games";
        case 5: return @"Board Game AI Solvers";
        case 6: return @"Action Games";
        default: return nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 1; // Spoof Wins
        case 1: return 1; // Floating HUD
        case 2: return 7; // Pool
        case 3: return 4; // Golf
        case 4: return 3; // Word games
        case 5: return 7; // Board games
        case 6: return 18; // Action games
        default: return 0;
    }
}

static CheatSwitchEntry getSwitchEntry(NSInteger section, NSInteger row) {
    if (section == 1) {
        CheatSwitchEntry e = {"In-Game Floating Seagull HUD", "kFloatingHUD"};
        return e;
    } else if (section == 2) {
        static const CheatSwitchEntry poolEntries[] = {
            {"Full Multi-Ball Trajectory", "kPoolFullTrajectory"},
            {"Break to Win in One Turn", "kPoolBreakToOneTurnWin"},
            {"Pocket Magnet Assist", "kPoolPocketAssist"},
            {"Always Move Cue Ball", "kAlwaysMoveCueBall"},
            {"Extended Trajectory Lines", "kExtendLines"},
            {"RGB Cue Guide Line", "kRGBLine"},
            {"Disable Hard Mode", "kDisableHardMode"}
        };
        return poolEntries[row];
    } else if (section == 3) {
        static const CheatSwitchEntry golfEntries[] = {
            {"Physics Bounce Map", "kGolfTrajectoryMap"},
            {"Stealth Hole-In-One", "kGolfAutoPuttStealth"},
            {"Infinite Golf Shots", "kHoleInOne"},
            {"Legit Mode (2+ Strokes)", "kGolfLegitMode"}
        };
        return golfEntries[row];
    } else if (section == 4) {
        static const CheatSwitchEntry wordEntries[] = {
            {"Word Bites Auto-Solve", "kBitesAutoSolve"},
            {"Reveal Words Button", "kRevealWords"},
            {"Auto Enter Words (Anagrams)", "kAutoEnterWords"}
        };
        return wordEntries[row];
    } else if (section == 5) {
        static const CheatSwitchEntry boardEntries[] = {
            {"Connect 4 Minimax Guide (👑/💀)", "kConnect4Overlay"},
            {"Mancala Kalah Free Turn Guide (⭐)", "kMancalaOverlay"},
            {"Dots & Boxes Safe Line Guide", "kDotsOverlay"},
            {"Gomoku 5-in-a-Row Threat Scanner", "kGomokuOverlay"},
            {"Checkers AI Jump & King Guide", "kCheckersOverlay"},
            {"Reversi Corner & Mobility Heatmap", "kReversiOverlay"},
            {"Chess Move Quality Indicator", "kChessOverlay"}
        };
        return boardEntries[row];
    } else if (section == 6) {
        static const CheatSwitchEntry actionEntries[] = {
            {"Sea Battle: See Enemy Ships", "kSeeEnemies"},
            {"Sea Battle: Auto-Sink Fleet", "kSeaAutoSink"},
            {"Cup Pong: Auto Shoot Button", "kAutoCupPong"},
            {"Cup Pong: One Cup Win", "kOneCup"},
            {"Basketball: Auto Swish", "kBasketAutoSwish"},
            {"Basketball: Freeze Timer", "kBasketInfiniteTimer"},
            {"Tanks: Zero Wind", "kTanksDisableWind"},
            {"Tanks: Persistent Trajectory", "kTanksTrajectory"},
            {"Darts: Aimbot", "kDartsAimbot"},
            {"Darts: One Dart Win", "kOneDart"},
            {"Archery: Disable Wind", "kArcheryDisableWind"},
            {"Archery: Disable Timer", "kDisableTimer"},
            {"Archery: Always 50ft Target", "kArchery50ft"},
            {"Filler: Best Color Guide", "kFillOverlay"},
            {"Paintball: ESP Enemy Reveal", "kPaintESP"},
            {"Shuffleboard: 3-Point Guide", "kShuffleGuide"},
            {"Knockout: Super Impulse Puck", "kKnockSuperImpulse"},
            {"Pool: Pocket Magnet Assist", "kPoolPocketAssist"}
        };
        return actionEntries[row];
    }
    CheatSwitchEntry fallback = {"", ""};
    return fallback;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        cell.textLabel.text = @"🏆 Spoof Wins";
        cell.detailTextLabel.text = @"Edit Scores";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }

    CheatSwitchEntry entry = getSwitchEntry(indexPath.section, indexPath.row);
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = [NSString stringWithUTF8String:entry.label];

    UISwitch *sw = [[UISwitch alloc] init];
    NSString *key = [NSString stringWithUTF8String:entry.key];
    sw.on = boolForKey(key);
    sw.onTintColor = [UIColor colorWithRed:0.1 green:0.8 blue:0.95 alpha:1.0];
    [sw addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
        setBoolForKey(key, sw.isOn);
    }] forControlEvents:UIControlEventValueChanged];

    cell.accessoryView = sw;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0 && indexPath.row == 0) {
        GSPInGameWinSpooferController *spooferVC = [[GSPInGameWinSpooferController alloc] initWithStyle:UITableViewStyleInsetGrouped];
        [self.navigationController pushViewController:spooferVC animated:YES];
    }
}

@end

void presentGameSeagullSettings(UIView *parentView) {
    if (!parentView) return;
    UIViewController *rootVC = parentView.window.rootViewController ?: [UIApplication sharedApplication].keyWindow.rootViewController;
    if (!rootVC) return;

    GSPInGameSettingsController *settingsVC = [[GSPInGameSettingsController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [rootVC presentViewController:nav animated:YES completion:nil];
}