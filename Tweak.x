@import Foundation;
@import UIKit;

#import "Utils.h"
#import "Headers.h"

bool archeryDisableWind;
bool archeryDisableTimer;
bool archery50ft;
bool extendLines;
bool disableHardmode;
bool alwaysShowLines;
bool rgbLine;
bool alwaysMoveCueBall;
bool poolBankShots;
bool poolFullTrajectory;
bool poolBreakToOneTurnWin;
bool oneDartWin;
bool dartAimbot;
bool tanksDisableWind;
bool tanksTrajectory;
bool alwaysHoleInOne;
bool golfLegitMode;
bool golfTrajectoryMap;
bool golfAutoPuttStealth;
bool oneCupWin;
bool autoCupPong;
bool revealWords;
bool autoEnterWords;
bool seeEnemyShips;
bool basketAutoSwish;
bool basketInfiniteTimer;
bool floatingHUD;
bool connect4Overlay;
bool mancalaOverlay;
bool dotsOverlay;
bool gomokuOverlay;
bool bitesAutoSolve;
bool seaAutoSink;
bool poolPocketAssist;
bool checkersOverlay;
bool reversiOverlay;
bool chessOverlay;
bool fillOverlay;
bool paintESP;
bool shuffleGuide;
bool knockSuperImpulse;

DartsScene *sharedInstance;

%hook ArcheryScene
- (void)didMoveToView:(id)arg1 {
	%orig;
	if (floatingHUD) {
		[SeagullHUD attachToView:self.view gameType:@"Archery" target:self];
	}
}

- (void)setWind:(float)arg1 angle:(float)arg2 {
	if (archeryDisableWind) {
		%orig(0.0, 0.0);
	} else {
		%orig;
	}
}
%end

%hook ArcheryView

- (void)update {
    %orig;
    if (archeryDisableTimer) {
        [self setValue:@(38) forKey:@"shot_time"];
    }
}

- (void)setTargetDistance:(int)arg1 {
	if (archery50ft) arg1 = 50;
	%orig;
}

%end

%hook PoolBall
- (bool)isStripes {
	return alwaysShowLines ? true : %orig;
}

- (bool)isSolid {
	return alwaysShowLines ? true : %orig;
}
%end

static CGPoint normalizeVec(CGPoint v) {
	CGFloat len = hypot(v.x, v.y);
	if (len < 0.0001f) return CGPointMake(1.0f, 0.0f);
	return CGPointMake(v.x / len, v.y / len);
}

static CGFloat dotProduct(CGPoint a, CGPoint b) {
	return a.x * b.x + a.y * b.y;
}

static void updateFullPoolTrajectory(SKScene *scene) {
	if (!poolFullTrajectory) return;

	NSArray *balls = nil;
	@try { balls = [scene valueForKey:@"balls"]; } @catch (id ex) {}
	if (!balls || balls.count == 0) return;

	NSArray *pockets = nil;
	@try { pockets = [scene valueForKey:@"pockets"]; } @catch (id ex) {}

	SKNode *cueBall = nil;
	for (SKNode *b in balls) {
		if ([b respondsToSelector:@selector(isStripes)] && [b respondsToSelector:@selector(isSolid)]) {
			if (![b performSelector:@selector(isStripes)] && ![b performSelector:@selector(isSolid)]) {
				cueBall = b;
				break;
			}
		}
	}
	if (!cueBall && balls.count > 0) cueBall = balls[0];
	if (!cueBall) return;

	SKShapeNode *canvas = nil;
	@try { canvas = [scene valueForKey:@"canvas"]; } @catch (id ex) {}
	if (!canvas || !canvas.path) return;

	__block CGPoint firstPt = cueBall.position;
	__block CGPoint lastPt = cueBall.position;
	__block int ptCount = 0;
	CGPathApplyWithBlock(canvas.path, ^(const CGPathElement *element) {
		if (element->type == kCGPathElementMoveToPoint) {
			firstPt = element->points[0];
		} else if (element->type == kCGPathElementAddLineToPoint) {
			lastPt = element->points[0];
			ptCount++;
		}
	});

	CGPoint shotDir = CGPointMake(lastPt.x - firstPt.x, lastPt.y - firstPt.y);
	if (hypot(shotDir.x, shotDir.y) < 2.0f) {
		id angleVal = nil;
		@try { angleVal = [scene valueForKey:@"angle"]; } @catch (id ex) {}
		if (angleVal) {
			float theta = [angleVal floatValue];
			shotDir = CGPointMake(cosf(theta), sinf(theta));
		} else {
			return;
		}
	}
	CGPoint cueDir = normalizeVec(shotDir);

	CGFloat minX = 40.0f, maxX = scene.size.width - 40.0f;
	CGFloat minY = 40.0f, maxY = scene.size.height - 40.0f;
	if (pockets && pockets.count >= 4) {
		minX = 1e9; maxX = -1e9; minY = 1e9; maxY = -1e9;
		for (SKNode *pocket in pockets) {
			if (pocket.position.x < minX) minX = pocket.position.x;
			if (pocket.position.x > maxX) maxX = pocket.position.x;
			if (pocket.position.y < minY) minY = pocket.position.y;
			if (pocket.position.y > maxY) maxY = pocket.position.y;
		}
	}
	CGFloat R_ball = 15.0f;
	CGFloat cushionLeft = minX + R_ball;
	CGFloat cushionRight = maxX - R_ball;
	CGFloat cushionBottom = minY + R_ball;
	CGFloat cushionTop = maxY - R_ball;

	CGMutablePathRef fullPath = CGPathCreateMutable();
	CGPoint currentCuePos = cueBall.position;
	CGPathMoveToPoint(fullPath, NULL, currentCuePos.x, currentCuePos.y);

	int hitBallIndex = -1;
	CGPoint ballHitPos = CGPointZero;
	CGPoint ballHitNormal = CGPointZero;

	for (int bounce = 0; bounce < 3; bounce++) {
		CGFloat tCushion = 1e9;
		int cushionSide = 0;
		if (cueDir.x > 0.0001f) {
			CGFloat t = (cushionRight - currentCuePos.x) / cueDir.x;
			if (t > 0 && t < tCushion) { tCushion = t; cushionSide = 2; }
		} else if (cueDir.x < -0.0001f) {
			CGFloat t = (cushionLeft - currentCuePos.x) / cueDir.x;
			if (t > 0 && t < tCushion) { tCushion = t; cushionSide = 1; }
		}
		if (cueDir.y > 0.0001f) {
			CGFloat t = (cushionTop - currentCuePos.y) / cueDir.y;
			if (t > 0 && t < tCushion) { tCushion = t; cushionSide = 4; }
		} else if (cueDir.y < -0.0001f) {
			CGFloat t = (cushionBottom - currentCuePos.y) / cueDir.y;
			if (t > 0 && t < tCushion) { tCushion = t; cushionSide = 3; }
		}

		CGFloat tBall = 1e9;
		int closestBallIdx = -1;
		for (int i = 0; i < (int)balls.count; i++) {
			SKNode *b = balls[i];
			if (b == cueBall) continue;
			CGPoint bPos = b.position;
			CGPoint toBall = CGPointMake(bPos.x - currentCuePos.x, bPos.y - currentCuePos.y);
			CGFloat proj = dotProduct(toBall, cueDir);
			if (proj <= 0) continue;
			CGFloat perpSq = (toBall.x * toBall.x + toBall.y * toBall.y) - (proj * proj);
			CGFloat diam = 2.0f * R_ball;
			if (perpSq <= (diam * diam)) {
				CGFloat t = proj - sqrtf(fmaxf(0.0f, (diam * diam) - perpSq));
				if (t > 0.1f && t < tBall) {
					tBall = t;
					closestBallIdx = i;
				}
			}
		}

		if (closestBallIdx >= 0 && tBall < tCushion) {
			hitBallIndex = closestBallIdx;
			ballHitPos = CGPointMake(currentCuePos.x + cueDir.x * tBall, currentCuePos.y + cueDir.y * tBall);
			CGPathAddLineToPoint(fullPath, NULL, ballHitPos.x, ballHitPos.y);
			CGPathAddArc(fullPath, NULL, ballHitPos.x, ballHitPos.y, R_ball, 0, M_PI * 2, YES);

			SKNode *targetBall = balls[closestBallIdx];
			ballHitNormal = normalizeVec(CGPointMake(targetBall.position.x - ballHitPos.x, targetBall.position.y - ballHitPos.y));
			break;
		} else if (tCushion < 1e8) {
			currentCuePos = CGPointMake(currentCuePos.x + cueDir.x * tCushion, currentCuePos.y + cueDir.y * tCushion);
			CGPathAddLineToPoint(fullPath, NULL, currentCuePos.x, currentCuePos.y);
			if (cushionSide == 1 || cushionSide == 2) cueDir.x = -cueDir.x;
			if (cushionSide == 3 || cushionSide == 4) cueDir.y = -cueDir.y;
		} else {
			break;
		}
	}

	if (hitBallIndex >= 0) {
		SKNode *targetBall = balls[hitBallIndex];
		CGPoint targetPos = targetBall.position;
		CGPoint targetDir = ballHitNormal;

		CGPoint cueDeflect = normalizeVec(CGPointMake(cueDir.x - dotProduct(cueDir, ballHitNormal) * ballHitNormal.x,
		                                              cueDir.y - dotProduct(cueDir, ballHitNormal) * ballHitNormal.y));
		CGPathMoveToPoint(fullPath, NULL, ballHitPos.x, ballHitPos.y);
		CGPathAddLineToPoint(fullPath, NULL, ballHitPos.x + cueDeflect.x * 120.0f, ballHitPos.y + cueDeflect.y * 120.0f);

		CGPathMoveToPoint(fullPath, NULL, targetPos.x, targetPos.y);

		BOOL targetEntersPocket = NO;
		if (pockets) {
			for (SKNode *pocket in pockets) {
				CGPoint toPocket = CGPointMake(pocket.position.x - targetPos.x, pocket.position.y - targetPos.y);
				CGFloat pProj = dotProduct(toPocket, targetDir);
				if (pProj > 0) {
					CGFloat perpSq = (toPocket.x * toPocket.x + toPocket.y * toPocket.y) - (pProj * pProj);
					if (perpSq <= (32.0f * 32.0f)) {
						CGPathAddLineToPoint(fullPath, NULL, pocket.position.x, pocket.position.y);
						CGPathAddArc(fullPath, NULL, pocket.position.x, pocket.position.y, 20.0f, 0, M_PI * 2, YES);
						targetEntersPocket = YES;
						break;
					}
				}
			}
		}

		if (!targetEntersPocket) {
			CGFloat tSecondary = 1e9;
			int secBallIdx = -1;
			for (int j = 0; j < (int)balls.count; j++) {
				if (j == hitBallIndex) continue;
				SKNode *b2 = balls[j];
				if (b2 == cueBall) continue;
				CGPoint toB2 = CGPointMake(b2.position.x - targetPos.x, b2.position.y - targetPos.y);
				CGFloat proj = dotProduct(toB2, targetDir);
				if (proj <= 0) continue;
				CGFloat perpSq = (toB2.x * toB2.x + toB2.y * toB2.y) - (proj * proj);
				CGFloat diam = 2.0f * R_ball;
				if (perpSq <= (diam * diam)) {
					CGFloat t = proj - sqrtf(fmaxf(0.0f, (diam * diam) - perpSq));
					if (t > 0.1f && t < tSecondary) {
						tSecondary = t;
						secBallIdx = j;
					}
				}
			}

			if (secBallIdx >= 0 && tSecondary < 400.0f) {
				CGPoint secHitPos = CGPointMake(targetPos.x + targetDir.x * tSecondary, targetPos.y + targetDir.y * tSecondary);
				CGPathAddLineToPoint(fullPath, NULL, secHitPos.x, secHitPos.y);
				CGPathAddArc(fullPath, NULL, secHitPos.x, secHitPos.y, R_ball, 0, M_PI * 2, YES);

				SKNode *secBall = balls[secBallIdx];
				CGPoint secNormal = normalizeVec(CGPointMake(secBall.position.x - secHitPos.x, secBall.position.y - secHitPos.y));
				CGPathMoveToPoint(fullPath, NULL, secBall.position.x, secBall.position.y);
				CGPathAddLineToPoint(fullPath, NULL, secBall.position.x + secNormal.x * 200.0f, secBall.position.y + secNormal.y * 200.0f);
			} else {
				CGFloat tCush = 350.0f;
				CGPathAddLineToPoint(fullPath, NULL, targetPos.x + targetDir.x * tCush, targetPos.y + targetDir.y * tCush);
			}
		}
	}

	SKShapeNode *trajNode = (SKShapeNode *)[scene childNodeWithName:@"gp_full_pool_traj"];
	if (!trajNode) {
		trajNode = [SKShapeNode shapeNodeWithPath:fullPath];
		trajNode.name = @"gp_full_pool_traj";
		trajNode.zPosition = 999;
		trajNode.lineWidth = 2.0f;
		trajNode.strokeColor = [UIColor colorWithRed:0.0f green:0.95f blue:1.0f alpha:0.9f];
		[scene addChild:trajNode];
	} else {
		trajNode.path = fullPath;
		trajNode.hidden = NO;
	}
	CGPathRelease(fullPath);
}

static void executeBreakToOneTurnWin(SKScene *scene) {
	if (!poolBreakToOneTurnWin) return;

	NSArray *balls = nil;
	@try { balls = [scene valueForKey:@"balls"]; } @catch (id ex) {}
	if (!balls || balls.count < 6) return;

	NSArray *pockets = nil;
	@try { pockets = [scene valueForKey:@"pockets"]; } @catch (id ex) {}
	if (!pockets || pockets.count < 6) return;

	int pocketIdx = 0;
	for (int i = 0; i < (int)balls.count; i++) {
		SKNode *b = balls[i];
		if ([b respondsToSelector:@selector(isStripes)] && [b respondsToSelector:@selector(isSolid)]) {
			if (![b performSelector:@selector(isStripes)] && ![b performSelector:@selector(isSolid)]) {
				// Cue ball: keep safely on table
				b.physicsBody.velocity = CGVectorMake(0.0f, 0.0f);
				continue;
			}
		}

		SKNode *targetPocket = pockets[pocketIdx % pockets.count];
		pocketIdx++;

		CGFloat dx = targetPocket.position.x - b.position.x;
		CGFloat dy = targetPocket.position.y - b.position.y;
		CGFloat dist = hypot(dx, dy);
		if (dist > 1.0f) {
			CGFloat speed = 950.0f + (arc4random_uniform(150));
			b.physicsBody.velocity = CGVectorMake((dx / dist) * speed, (dy / dist) * speed);
		}
	}
}

#define IMPLEMENT_POOL_SCENE(SceneClass) \
%hook SceneClass \
%property (nonatomic) int currentColorHue; \
%property (nonatomic, retain) SKShapeNode *fullTrajNode; \
- (void)didMoveToView:(id)arg1 { \
	%orig; \
	if (disableHardmode) { \
		[self setValue:@"n" forKey:@"mode"]; \
	} \
	if (floatingHUD) { \
		[SeagullHUD attachToView:self.view gameType:@"8-Ball / 9-Ball Pool" target:self]; \
	} \
} \
- (void)update:(double)arg1 { \
	%orig; \
	if (rgbLine) { \
		SKShapeNode *canvas = [self valueForKey:@"canvas"]; \
		self.currentColorHue = (self.currentColorHue + 1) % 360; \
		if (canvas) { \
			[canvas setStrokeColor:[UIColor colorWithHue:self.currentColorHue/360.0 saturation:1.0 brightness:1.0 alpha:1.0]]; \
		} \
	} \
	if (alwaysMoveCueBall) { \
		[self setValue:@(true) forKey:@"move_white"]; \
	} \
	if (poolPocketAssist) { \
		@try { \
			NSArray *balls = [self valueForKey:@"balls"]; \
			NSArray *pockets = [self valueForKey:@"pockets"]; \
			if (balls && pockets) { \
				for (SKNode *b in balls) { \
					if (!b.physicsBody) continue; \
					CGVector vel = b.physicsBody.velocity; \
					CGFloat speed = hypot(vel.dx, vel.dy); \
					if (speed > 5.0f && speed < 800.0f) { \
						CGPoint p = applyPoolPocketMagnet(b.position, CGPointMake(vel.dx, vel.dy), pockets, 40.0f); \
						b.physicsBody.velocity = CGVectorMake(p.x, p.y); \
					} \
				} \
			} \
		} @catch (id ex) {} \
	} \
} \
- (void)mMove { \
	%orig; \
	if (poolFullTrajectory) { \
		updateFullPoolTrajectory(self); \
	} \
} \
- (void)mUp { \
	if (poolBreakToOneTurnWin) { \
		executeBreakToOneTurnWin(self); \
	} \
	%orig; \
	SKNode *traj = [self childNodeWithName:@"gp_full_pool_traj"]; \
	if (traj) traj.hidden = YES; \
} \
%new \
- (void)autoAimBestBall { \
	NSArray *balls = nil; \
	@try { balls = [self valueForKey:@"balls"]; } @catch (id ex) {} \
	NSArray *pockets = nil; \
	@try { pockets = [self valueForKey:@"pockets"]; } @catch (id ex) {} \
	SKNode *cueBall = nil; \
	for (SKNode *b in balls) { \
		if ([b respondsToSelector:@selector(isStripes)] && [b respondsToSelector:@selector(isSolid)]) { \
			if (![b performSelector:@selector(isStripes)] && ![b performSelector:@selector(isSolid)]) { \
				cueBall = b; \
				break; \
			} \
		} \
	} \
	if (!cueBall && balls.count > 0) cueBall = balls[0]; \
	if (!cueBall || !balls || !pockets) return; \
	CGFloat bestAngle = calculateBestPoolShotAngle(cueBall.position, balls, pockets, 15.0f); \
	@try { \
		[self setValue:@(bestAngle) forKey:@"angle"]; \
	} @catch (id ex) {} \
	if (poolFullTrajectory) { \
		updateFullPoolTrajectory(self); \
	} \
} \
%end

IMPLEMENT_POOL_SCENE(PoolScene)
IMPLEMENT_POOL_SCENE(PoolScene2)
IMPLEMENT_POOL_SCENE(PoolScene3)

%hook TanksWind
- (void)setWind:(float)arg1 {
	if (tanksDisableWind) {
		%orig(0.0);
	} else {
		%orig;
	}
}
%end

%hook DartsScene
%property (nonatomic, assign) bool aimbotEnabled;
%property (nonatomic, retain) UIButton *menuButton;
%property (nonatomic, assign) int multiplier;
%property (nonatomic, assign) int number;

%property (nonatomic, retain) UIView *aimbotStatusView;

- (void)update:(double)arg1 {
	%orig;

	if (!self.menuButton.hidden) return;

	if ([[self valueForKey:@"state"] intValue] == 1) {
		self.menuButton.hidden = false;
		self.aimbotStatusView.hidden = false;
	} else {
		self.menuButton.hidden = true;
		self.aimbotStatusView.hidden = true;
	}
}

- (void)didMoveToView:(id)arg1 {
	%orig;

	if (floatingHUD) {
		[SeagullHUD attachToView:self.view gameType:@"Darts" target:self];
	}

	if (!dartAimbot) return;

	sharedInstance = self;
	self.aimbotEnabled = false;
	self.menuButton = makeButton(@"Aimbot", CGRectMake([UIScreen mainScreen].bounds.size.width / 2 - 50, 10, 100, 40), nil, nil);
	[self createMainMenu];
	self.menuButton.showsMenuAsPrimaryAction = true;
	[self.view addSubview:self.menuButton];
	[self.view bringSubviewToFront:self.menuButton];

	self.aimbotStatusView = [[UIView alloc] init];
	[self.view addSubview:self.aimbotStatusView];
	[self updateAimbotStatusView];
	self.aimbotStatusView.translatesAutoresizingMaskIntoConstraints = NO;
	[self.view bringSubviewToFront:self.aimbotStatusView];

	[NSLayoutConstraint activateConstraints:@[
		[self.aimbotStatusView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:10],
		[self.aimbotStatusView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-110],
		[self.aimbotStatusView.widthAnchor constraintEqualToConstant:100],
		[self.aimbotStatusView.heightAnchor constraintEqualToConstant:100]
	]];

	self.menuButton.hidden = true;
}

%new
- (void)createMainMenu {
	NSMutableArray *actions = [[NSMutableArray alloc] init];
	NSMutableArray *multipliers = [[NSMutableArray alloc] init];
	NSMutableArray *numbers = [[NSMutableArray alloc] init];

	UIAction *action = [UIAction actionWithTitle:@"Enabled" image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
		self.aimbotEnabled = !self.aimbotEnabled;
		if (self.aimbotEnabled) {
			if (self.multiplier == 0) self.multiplier = 1;
			if (self.number == 0) self.number = 1;
		} else {
			self.multiplier = 0;
			self.number = 0;
		}

		[self createMainMenu];
	}];
	action.state = self.aimbotEnabled ? UIMenuElementStateOn : UIMenuElementStateOff;

	[actions addObject:action];

	for (int i = 1; i <= 3; i++) {
		UIAction *action = [UIAction actionWithTitle:[NSString stringWithFormat:@"%dx", i] image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
			if (self.number == 0) self.number = 1;
			self.multiplier = i;

			if (self.multiplier > 1 && self.number > 20) {
				self.number = 20;
			}

			[self createMainMenu];
		}];
		action.state = self.multiplier == i ? UIMenuElementStateOn : UIMenuElementStateOff;
		[multipliers addObject:action];
	}

	for (UIAction *action in multipliers) {
		if (!self.aimbotEnabled) {
			action.attributes = UIMenuElementAttributesDisabled;
		}
	}

	[actions addObject:[UIMenu menuWithTitle:@"Multiplier" children:multipliers]];

	for (int i = 1; i <= 20; i++) {
		UIAction *action = [UIAction actionWithTitle:[NSString stringWithFormat:@"%d", i] image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
			if (self.multiplier == 0) self.multiplier = 1;
			self.number = i;

			[self createMainMenu];
		}];
		action.state = self.number == i ? UIMenuElementStateOn : UIMenuElementStateOff;
		[numbers addObject:action];
	}

	UIAction *action25 = [UIAction actionWithTitle:@"25" image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
		self.multiplier = 1;
		self.number = 25;

		[self createMainMenu];
	}];
	action25.state = self.number == 25 ? UIMenuElementStateOn : UIMenuElementStateOff;
	[numbers addObject:action25];

	UIAction *action50 = [UIAction actionWithTitle:@"50" image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
		self.multiplier = 1;
		self.number = 50;

		[self createMainMenu];
	}];
	action50.state = self.number == 50 ? UIMenuElementStateOn : UIMenuElementStateOff;
	[numbers addObject:action50];

	for (UIAction *action in numbers) {
		if (!self.aimbotEnabled) {
			action.attributes = UIMenuElementAttributesDisabled;
		}

		if ([action.title isEqualToString:@"25"] || [action.title isEqualToString:@"50"]) {
			if (self.multiplier != 1) {
				action.attributes = UIMenuElementAttributesDisabled;
			}
		}
	}

	[actions addObject:[UIMenu menuWithTitle:@"Number" children:numbers]];


	UIMenu* menu = [UIMenu menuWithTitle:@"Aimbot" children:actions];
	self.menuButton.menu = menu;

	[self updateAimbotStatusView];
}

%new
- (void)updateAimbotStatusView {
	if (!self.aimbotStatusView) return;
	[[self.aimbotStatusView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];

	UILabel *activeLabel = [[UILabel alloc] init];
	activeLabel.text = self.aimbotEnabled ? @"Enabled" : @"Disabled";
	activeLabel.textAlignment = NSTextAlignmentCenter;
	activeLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
	activeLabel.frame = CGRectMake(0, 0, 0, 0);
	[activeLabel sizeToFit];
	activeLabel.translatesAutoresizingMaskIntoConstraints = NO;

	activeLabel.layer.shadowColor = [[UIColor blackColor] CGColor];
	activeLabel.layer.shadowOffset = CGSizeMake(1.5, 1.5);
	activeLabel.layer.shadowRadius = 4;
	activeLabel.layer.shadowOpacity = 1;

	[self.aimbotStatusView addSubview:activeLabel];

	[NSLayoutConstraint activateConstraints:@[
		[activeLabel.centerXAnchor constraintEqualToAnchor:self.aimbotStatusView.centerXAnchor],
		[activeLabel.topAnchor constraintEqualToAnchor:self.aimbotStatusView.topAnchor constant:5]
	]];

	if (!self.aimbotEnabled) return;

	UILabel *multiplierLabel = [[UILabel alloc] init];
	multiplierLabel.text = [NSString stringWithFormat:@"Multiplier: %dx", self.multiplier];
	multiplierLabel.textAlignment = NSTextAlignmentCenter;
	multiplierLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
	[multiplierLabel sizeToFit];
	multiplierLabel.translatesAutoresizingMaskIntoConstraints = NO;

	multiplierLabel.layer.shadowColor = [[UIColor blackColor] CGColor];
	multiplierLabel.layer.shadowOffset = CGSizeMake(1.5, 1.5);
	multiplierLabel.layer.shadowRadius = 4;
	multiplierLabel.layer.shadowOpacity = 1;

	[self.aimbotStatusView addSubview:multiplierLabel];

	[NSLayoutConstraint activateConstraints:@[
		[multiplierLabel.centerXAnchor constraintEqualToAnchor:self.aimbotStatusView.centerXAnchor],
		[multiplierLabel.topAnchor constraintEqualToAnchor:activeLabel.bottomAnchor constant:5]
	]];

	UILabel *numberLabel = [[UILabel alloc] init];
	numberLabel.text = [NSString stringWithFormat:@"Number: %d", self.number];
	numberLabel.textAlignment = NSTextAlignmentCenter;
	numberLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
	numberLabel.translatesAutoresizingMaskIntoConstraints = NO;

	numberLabel.layer.shadowColor = [[UIColor blackColor] CGColor];
	numberLabel.layer.shadowOffset = CGSizeMake(1.5, 1.5);
	numberLabel.layer.shadowRadius = 4;
	numberLabel.layer.shadowOpacity = 1;

	[numberLabel sizeToFit];
	[self.aimbotStatusView addSubview:numberLabel];

	[NSLayoutConstraint activateConstraints:@[
		[numberLabel.centerXAnchor constraintEqualToAnchor:self.aimbotStatusView.centerXAnchor],
		[numberLabel.topAnchor constraintEqualToAnchor:multiplierLabel.bottomAnchor constant:5]
	]];
}

- (void)showScore:(int)arg1 full_score:(int)arg2 multi:(int)arg3 pos:(int)arg4 send_pos:(CGPoint)arg5 {
	if (oneDartWin) {
		%orig(100, self.score1, arg3, arg4, arg5);
	} else {
		%orig;
	}
}

- (void)showScore2:(int)arg1 full_score:(int)arg2 multi:(int)arg3 pos:(int)arg4 send_pos:(CGPoint)arg5 {
	if (oneDartWin) {
		%orig(100, self.score1, arg3, arg4, arg5);
	} else {
		%orig;
	}
}
%end

%hook DartsDart

- (void)setTarget:(SCNVector3)arg1 {
	if (sharedInstance.aimbotEnabled) {
		%orig(getAimbotPos(sharedInstance.multiplier, sharedInstance.number));
	} else {
		%orig;
	}
}

%end


%hook GolfBall
- (bool)inside {
	if (alwaysHoleInOne) {
		if (golfLegitMode) {
			id strokesVal = nil;
			@try {
				strokesVal = [self valueForKey:@"strokes"];
			} @catch (id ex) {}
			int strokes = strokesVal ? [strokesVal intValue] : 0;
			return (strokes >= 2) ? true : %orig;
		}
		return true;
	}
	return %orig;
}

- (bool)hole {
	if (alwaysHoleInOne) {
		if (golfLegitMode) {
			id strokesVal = nil;
			@try {
				strokesVal = [self valueForKey:@"strokes"];
			} @catch (id ex) {}
			int strokes = strokesVal ? [strokesVal intValue] : 0;
			return (strokes >= 2) ? true : %orig;
		}
		return true;
	}
	return %orig;
}
%end

static void updateGolfTrajectoryMap(SKScene *scene, CGPoint dragVector) {
	if (!golfTrajectoryMap) return;

	SKNode *ball = nil;
	@try { ball = [scene valueForKey:@"ball"]; } @catch (id ex) {}
	if (!ball) return;

	SKNode *hole = nil;
	@try { hole = [scene valueForKey:@"hole"]; } @catch (id ex) {}
	CGPoint holePos = hole ? hole.position : CGPointMake(scene.size.width * 0.5f, scene.size.height * 0.8f);

	CGPoint p = ball.position;
	CGPoint v = CGPointMake(-dragVector.x * 4.2f, -dragVector.y * 4.2f);

	CGFloat minX = 25.0f, maxX = scene.size.width - 25.0f;
	CGFloat minY = 25.0f, maxY = scene.size.height - 25.0f;

	CGMutablePathRef golfPath = CGPathCreateMutable();
	CGPathMoveToPoint(golfPath, NULL, p.x, p.y);

	for (int step = 0; step < 160; step++) {
		p.x += v.x * 0.016f;
		p.y += v.y * 0.016f;
		v.x *= 0.982f;
		v.y *= 0.982f;

		if (p.x < minX) { p.x = minX; v.x = -v.x * 0.82f; CGPathAddArc(golfPath, NULL, p.x, p.y, 4.0f, 0, M_PI * 2, YES); }
		if (p.x > maxX) { p.x = maxX; v.x = -v.x * 0.82f; CGPathAddArc(golfPath, NULL, p.x, p.y, 4.0f, 0, M_PI * 2, YES); }
		if (p.y < minY) { p.y = minY; v.y = -v.y * 0.82f; CGPathAddArc(golfPath, NULL, p.x, p.y, 4.0f, 0, M_PI * 2, YES); }
		if (p.y > maxY) { p.y = maxY; v.y = -v.y * 0.82f; CGPathAddArc(golfPath, NULL, p.x, p.y, 4.0f, 0, M_PI * 2, YES); }

		CGPathAddLineToPoint(golfPath, NULL, p.x, p.y);

		CGFloat distToHole = hypot(p.x - holePos.x, p.y - holePos.y);
		if (distToHole < 16.0f) {
			CGPathAddArc(golfPath, NULL, holePos.x, holePos.y, 14.0f, 0, M_PI * 2, YES);
			break;
		}

		if (hypot(v.x, v.y) < 8.0f) break;
	}

	SKShapeNode *trajNode = (SKShapeNode *)[scene childNodeWithName:@"gp_golf_traj"];
	if (!trajNode) {
		trajNode = [SKShapeNode shapeNodeWithPath:golfPath];
		trajNode.name = @"gp_golf_traj";
		trajNode.zPosition = 999;
		trajNode.lineWidth = 2.5f;
		trajNode.strokeColor = [UIColor colorWithRed:0.2f green:1.0f blue:0.4f alpha:0.9f];
		[scene addChild:trajNode];
	} else {
		trajNode.path = golfPath;
		trajNode.hidden = NO;
	}
	CGPathRelease(golfPath);
}

static void executeGolfAutoPuttStealth(SKScene *scene) {
	SKNode *ball = nil;
	@try { ball = [scene valueForKey:@"ball"]; } @catch (id ex) {}
	if (!ball) return;

	SKNode *hole = nil;
	@try { hole = [scene valueForKey:@"hole"]; } @catch (id ex) {}
	CGPoint holePos = hole ? hole.position : CGPointMake(scene.size.width * 0.5f, scene.size.height * 0.8f);

	CGPoint ballPos = ball.position;
	CGFloat bestAngle = 0.0f;
	CGFloat bestPower = 0.5f;
	CGFloat minFinalDist = 1e9;
	BOOL foundHoleInOne = NO;

	CGFloat minX = 25.0f, maxX = scene.size.width - 25.0f;
	CGFloat minY = 25.0f, maxY = scene.size.height - 25.0f;

	for (int a = 0; a < 72; a++) {
		CGFloat theta = (a * 5.0f) * (M_PI / 180.0f);
		for (CGFloat pwr = 0.35f; pwr <= 1.0f; pwr += 0.15f) {
			CGPoint p = ballPos;
			CGPoint v = CGPointMake(cosf(theta) * pwr * 800.0f, sinf(theta) * pwr * 800.0f);

			for (int step = 0; step < 160; step++) {
				p.x += v.x * 0.016f;
				p.y += v.y * 0.016f;
				v.x *= 0.982f;
				v.y *= 0.982f;

				if (p.x < minX) { p.x = minX; v.x = -v.x * 0.82f; }
				if (p.x > maxX) { p.x = maxX; v.x = -v.x * 0.82f; }
				if (p.y < minY) { p.y = minY; v.y = -v.y * 0.82f; }
				if (p.y > maxY) { p.y = maxY; v.y = -v.y * 0.82f; }

				CGFloat d = hypot(p.x - holePos.x, p.y - holePos.y);
				if (d < 15.0f && hypot(v.x, v.y) < 300.0f) {
					foundHoleInOne = YES;
					bestAngle = theta;
					bestPower = pwr;
					break;
				}
				if (step == 159 && d < minFinalDist) {
					minFinalDist = d;
					bestAngle = theta;
					bestPower = pwr;
				}
			}
			if (foundHoleInOne) break;
		}
		if (foundHoleInOne) break;
	}

	CGFloat dragDist = bestPower * 90.0f;
	CGPoint dragTouch = CGPointMake(ballPos.x - cosf(bestAngle) * dragDist, ballPos.y - sinf(bestAngle) * dragDist);

	if ([scene respondsToSelector:@selector(touchDownAtPoint:)]) {
		[scene performSelector:@selector(touchDownAtPoint:) withObject:[NSValue valueWithCGPoint:ballPos]];
	}
	if ([scene respondsToSelector:@selector(touchMovedToPoint:)]) {
		[scene performSelector:@selector(touchMovedToPoint:) withObject:[NSValue valueWithCGPoint:dragTouch]];
	}
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		if ([scene respondsToSelector:@selector(touchUpAtPoint:)]) {
			[scene performSelector:@selector(touchUpAtPoint:) withObject:[NSValue valueWithCGPoint:dragTouch]];
		}
	});
}

%hook GolfScene
%property (nonatomic, retain) UIButton *golfAutoButton;

- (void)didMoveToView:(id)arg1 {
	%orig;

	if (floatingHUD) {
		[SeagullHUD attachToView:self.view gameType:@"Mini Golf" target:self];
	}

	if (golfAutoPuttStealth) {
		CGFloat topInset = 20.0;
		if (@available(iOS 11.0, *)) {
			topInset = self.view.safeAreaInsets.top + 10.0;
		}
		self.golfAutoButton = makeButton(@"Auto Putt", CGRectMake([UIScreen mainScreen].bounds.size.width / 2 - 50, topInset, 100, 36), self, @selector(autoShootHoleInOne));
		[self.view addSubview:self.golfAutoButton];
		[self.view bringSubviewToFront:self.golfAutoButton];
	}
}

- (void)touchMovedToPoint:(CGPoint)pt {
	%orig;
	if (golfTrajectoryMap) {
		SKNode *ball = nil;
		@try { ball = [self valueForKey:@"ball"]; } @catch (id ex) {}
		if (ball) {
			CGPoint drag = CGPointMake(pt.x - ball.position.x, pt.y - ball.position.y);
			updateGolfTrajectoryMap(self, drag);
		}
	}
}

- (void)touchUpAtPoint:(CGPoint)pt {
	%orig;
	SKNode *traj = [self childNodeWithName:@"gp_golf_traj"];
	if (traj) traj.hidden = YES;
}

%new
- (void)autoShootHoleInOne {
	executeGolfAutoPuttStealth(self);
}
%end

%hook BeerScene

- (void)didMoveToView:(id)arg1 {
	%orig;

	if (floatingHUD) {
		[SeagullHUD attachToView:self.view gameType:@"Cup Pong" target:self.scene3d];
	}

	if (!autoCupPong) return;

	CGFloat topInset = 20.0;
	if (@available(iOS 11.0, *)) {
		topInset = self.view.safeAreaInsets.top + 10.0;
	}
	UIButton *button = makeButton(@"Shoot", CGRectMake([UIScreen mainScreen].bounds.size.width / 2 - 50, topInset, 100, 36), self.scene3d, @selector(shootRandomCup));
	[self.view addSubview:button];
	[self.view bringSubviewToFront:button];
}

%end

static BeerView *gCurrentBeerView = nil;

%hook SCNPhysicsBody
- (void)applyForce:(SCNVector3)direction impulse:(BOOL)impulse {
	if (gCurrentBeerView) {
		if (gCurrentBeerView.F_x != 0.0f) direction.x = gCurrentBeerView.F_x;
		if (gCurrentBeerView.F_z != 0.0f) direction.z = gCurrentBeerView.F_z;
	}
	%orig(direction, impulse);
}
%end

%hook BeerView
%property (assign) float F_x;
%property (assign) float F_z;

- (void)killCup:(id)arg1 {
	if (oneCupWin) {
		for (BeerCup *cup in [self valueForKey:@"cups"]) {
			%orig(cup);
		}
	} else {
		%orig;
	}
}

%new
- (void)shootRandomCup {
	NSArray *cups = [self valueForKey:@"cups"];
	BeerCup *cup = nil;

	SCNNode *ball = [[self valueForKey:@"game_ball"] ball];

	if ([cups count] < 1 || !ball) return;

	NSMutableArray *liveCups = [NSMutableArray array];
	for (BeerCup *c in cups) {
		if (c.live) [liveCups addObject:c];
	}
	if (liveCups.count == 0) return;

	SCNVector3 realBallPos = [self projectPoint:ball.position];
	CGPoint start = CGPointMake(realBallPos.x, self.frame.size.height - realBallPos.y);
	[self touchDownAtPoint:start];
	
	cup = liveCups[arc4random_uniform((uint32_t)liveCups.count)];
	
	self.F_x = (cup.pos.x - ball.position.x) * 1.3;
	self.F_z = -1.2 / (cup.pos.z - ball.position.z + 0.25) - 2.91;

	gCurrentBeerView = self;

	CGPoint dest = CGPointMake(realBallPos.x, self.frame.size.height);

	[self touchMovedToPoint:dest];
	[self touchUpAtPoint:dest];

	self.F_x = 0;
	self.F_z = 0;
	gCurrentBeerView = nil;
}

%end

%hook SeaScene
- (void)didMoveToView:(id)arg1 {
	%orig;
	UIView *pv = nil;
	@try { pv = [self valueForKey:@"view"]; } @catch (id ex) {}
	if (pv && floatingHUD) {
		[SeagullHUD attachToView:pv gameType:@"Sea Battle" target:self];
	}
}

- (void)update:(double)arg1 {
	%orig;
	if (seeEnemyShips) {
		for (SeaShip *ship in [self valueForKey:@"ships"]) {
			ship.sprite.hidden = false;
		}
	}
}

%new
- (void)autoSinkEnemyFleet {
	NSArray *ships = nil;
	@try { ships = [self valueForKey:@"ships"]; } @catch (id ex) {}
	if (!ships) return;
	for (SeaShip *ship in ships) {
		ship.sprite.hidden = false;
		CGPoint pt = ship.sprite.position;
		if ([self respondsToSelector:@selector(touchDownAtPoint:)]) {
			[self performSelector:@selector(touchDownAtPoint:) withObject:[NSValue valueWithCGPoint:pt]];
		}
	}
}
%end

%hook AnagramsScene
%property (nonatomic, retain) NSArray *words;
%property (nonatomic, retain) UIButton *anagrams_revealButton;
%property (nonatomic, retain) UIButton *anagrams_autoButton;

- (void)startGame {
	%orig;

	if (floatingHUD) {
		[SeagullHUD attachToView:self.view gameType:@"Anagrams" target:self];
	}

	[self revealWords:YES];
	self.words = [[[[self valueForKey:@"wordList"] valueForKey:@"words_string"] stringByReplacingOccurrencesOfString:@"?" withString:@""] componentsSeparatedByString:@"|"];

	if (revealWords) {
		CGFloat offset = autoEnterWords ? 110 : 50;
		self.anagrams_revealButton = makeButton(@"Reveal Words", CGRectMake([UIScreen mainScreen].bounds.size.width / 2 - offset, 10, 100, 40), self, @selector(revealAllWordsInSheet));
		[self.view addSubview:self.anagrams_revealButton];
		[self.view bringSubviewToFront:self.anagrams_revealButton];
	}
	
	if (autoEnterWords) {
		CGFloat offset = revealWords ? -10 : 50;
		self.anagrams_autoButton = makeButton(@"Auto", CGRectMake([UIScreen mainScreen].bounds.size.width / 2 - offset, 10, 100, 40), self, @selector(fillArr));
		[self.view addSubview:self.anagrams_autoButton];
		[self.view bringSubviewToFront:self.anagrams_autoButton];
	}
}

- (void)toResult {
	%orig;

	[self.anagrams_revealButton removeFromSuperview];
	[self.anagrams_autoButton removeFromSuperview];
}

%new
- (void)thingAt:(NSArray *)words wordsArr:(NSMutableArray *)wordsArr blocks:(NSMutableArray *)blocks fromIndex:(int)index {
	NSString *word = words[index];
	NSMutableArray *availableBlocks = [blocks mutableCopy];
	for(int i = 0; i < [word length]; i++) {
		NSString *targetChar = [NSString stringWithFormat:@"%c", [word characterAtIndex:i]];
		for(int j = 0; j < [availableBlocks count]; j++) {
			if([[availableBlocks[j] valueForKey:@"letter"] isEqual:targetChar]) {
				[wordsArr addObject:availableBlocks[j]];
				[availableBlocks removeObjectAtIndex:j];
				break;
			}
		}
	}
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, .17 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
		[self enterWord];
		[wordsArr removeAllObjects];

		if (([words count] - 1) == index) {
			[self winGame];
			return;
		}
		
		[self thingAt:words wordsArr:wordsArr blocks:blocks fromIndex:index + 1];
	});
}

%new
- (void)fillArr {
	[self revealWords:YES];
	if ([self.words count] == 0) return;
	NSMutableArray *wordsArr = [self valueForKey:@"answer"];
	NSMutableArray *blocks = [self valueForKey:@"blocks"];

	[self thingAt:self.words wordsArr:wordsArr blocks:blocks fromIndex:0];
}

%new
- (void)revealAllWordsInSheet {
	showWordList(self.view, @"Anagrams", self.words ?: @[]);
}

%new
- (void)anagramsShow {
	[self revealAllWordsInSheet];
}
%end

%hook HuntScene
%property (nonatomic, retain) UIButton *hunt_revealWordsButton;
- (void)startGame {
	%orig;

	if (floatingHUD) {
		[SeagullHUD attachToView:self.view gameType:@"Word Hunt" target:self];
	}

	if (revealWords) {
		CGFloat pos = ((SKSpriteNode*)[self valueForKey:@"score_bg"]).size.height + self.view.safeAreaInsets.top;
		self.hunt_revealWordsButton = makeButton(@"Reveal Words", CGRectMake([UIScreen mainScreen].bounds.size.width / 2 - 50, pos, 100, 40), self, @selector(hunt_revealWords));
		[self.view addSubview:self.hunt_revealWordsButton];
		[self.view bringSubviewToFront:self.hunt_revealWordsButton];
	}
}

- (void)toResult {
	%orig;
	[self.hunt_revealWordsButton removeFromSuperview];
}

%new
- (void)hunt_revealWords {
	[self revealWords:YES];
	NSArray *words = [[[[self valueForKey:@"wordList"] valueForKey:@"words_string"] stringByReplacingOccurrencesOfString:@"?" withString:@""] componentsSeparatedByString:@"|"];
	NSMutableArray *validWords = [[NSMutableArray alloc] init];
	for (NSString *word in words) {
		if ([self checkWord:word flag:0]) {
			[validWords addObject:word];
		}
	}

	showWordList(self.view, @"Word Hunt", validWords);
}

%new
- (void)revealAllWordsInSheet {
	[self hunt_revealWords];
}

%new
- (void)winGame {
	NSArray *words = [[[[self valueForKey:@"wordList"] valueForKey:@"words_string"] stringByReplacingOccurrencesOfString:@"?" withString:@""] componentsSeparatedByString:@"|"];
	for (NSString *word in words) {
		if ([self checkWord:word flag:0]) {
			// Solved
		}
	}
}
%end

%hook BitesScene
%property (nonatomic, retain) NSArray *words;
%property (nonatomic, retain) UIButton *bites_revealButton;
%property (nonatomic, retain) UIButton *bites_autoButton;

- (void)didMoveToView:(id)arg1 {
	%orig;
	if (floatingHUD) {
		[SeagullHUD attachToView:self.view gameType:@"Word Bites" target:self];
	}

	if (revealWords) {
		CGFloat topInset = 20.0;
		if (@available(iOS 11.0, *)) {
			topInset = self.view.safeAreaInsets.top + 10.0;
		}
		self.bites_revealButton = makeButton(@"Words", CGRectMake([UIScreen mainScreen].bounds.size.width - 90, topInset, 75, 36), self, @selector(revealAllWordsInSheet));
		[self.view addSubview:self.bites_revealButton];
		[self.view bringSubviewToFront:self.bites_revealButton];

		self.bites_autoButton = makeButton(@"Auto", CGRectMake([UIScreen mainScreen].bounds.size.width - 170, topInset, 75, 36), self, @selector(winGame));
		[self.view addSubview:self.bites_autoButton];
		[self.view bringSubviewToFront:self.bites_autoButton];
	}
}

- (void)startGame {
	%orig;
	@try {
		self.words = [[[[self valueForKey:@"wordList"] valueForKey:@"words_string"] stringByReplacingOccurrencesOfString:@"?" withString:@""] componentsSeparatedByString:@"|"];
	} @catch (id ex) {}
}

%new
- (void)revealAllWordsInSheet {
	if (!self.words) {
		@try {
			self.words = [[[[self valueForKey:@"wordList"] valueForKey:@"words_string"] stringByReplacingOccurrencesOfString:@"?" withString:@""] componentsSeparatedByString:@"|"];
		} @catch (id ex) {}
	}
	showWordList(self.view, @"Word Bites", self.words ?: @[]);
}

%new
- (void)winGame {
	if (!self.words || self.words.count == 0) {
		@try {
			self.words = [[[[self valueForKey:@"wordList"] valueForKey:@"words_string"] stringByReplacingOccurrencesOfString:@"?" withString:@""] componentsSeparatedByString:@"|"];
		} @catch (id ex) {}
	}
	if (!self.words) return;
	for (NSString *w in self.words) {
		if ([self respondsToSelector:@selector(checkWord:flag:)]) {
			[self performSelector:@selector(checkWord:flag:) withObject:w withObject:@(YES)];
		}
	}
}
%end

#define IMPLEMENT_CONNECT_SCENE(SceneClass) \
%hook SceneClass \
- (void)didMoveToView:(id)arg1 { \
	%orig; \
	if (floatingHUD) { \
		[SeagullHUD attachToView:self.view gameType:@"Connect 4" target:self]; \
	} \
} \
- (void)update:(double)arg1 { \
	%orig; \
	if (!connect4Overlay) return; \
	[self updateMinimaxOverlay]; \
} \
%new \
- (void)updateMinimaxOverlay { \
	NSArray *gridArr = nil; \
	@try { gridArr = [self valueForKey:@"grid"]; } @catch (id ex) {} \
	int grid[6][7] = {0}; \
	if (gridArr && gridArr.count >= 6) { \
		for (int r = 0; r < 6; r++) { \
			NSArray *row = gridArr[r]; \
			for (int c = 0; c < 7 && c < (int)row.count; c++) { \
				grid[r][c] = [row[c] intValue]; \
			} \
		} \
	} \
	Connect4Evaluation eval = evaluateConnect4Grid(grid, 1); \
	for (int c = 0; c < 7; c++) { \
		NSString *nodeName = [NSString stringWithFormat:@"c4_ind_%d", c]; \
		SKLabelNode *lbl = (SKLabelNode *)[self childNodeWithName:nodeName]; \
		if (!lbl) { \
			lbl = [SKLabelNode labelNodeWithFontNamed:@"Helvetica-Bold"]; \
			lbl.name = nodeName; \
			lbl.fontSize = 18.0; \
			lbl.zPosition = 999; \
			[self addChild:lbl]; \
		} \
		CGFloat colW = self.size.width / 7.0; \
		lbl.position = CGPointMake(colW * c + colW * 0.5, self.size.height - 40.0); \
		if (c == eval.bestColumn) { \
			lbl.text = @"👑"; \
			lbl.fontColor = [UIColor greenColor]; \
		} else if (eval.columnScores[c] == -10000) { \
			lbl.text = @"💀"; \
			lbl.fontColor = [UIColor redColor]; \
		} else { \
			lbl.text = @"•"; \
			lbl.fontColor = [UIColor yellowColor]; \
		} \
	} \
} \
%end

IMPLEMENT_CONNECT_SCENE(ConnectScene)
IMPLEMENT_CONNECT_SCENE(FourScene)

%hook MancalaScene
- (void)didMoveToView:(id)arg1 {
	%orig;
	if (floatingHUD) {
		[SeagullHUD attachToView:self.view gameType:@"Mancala" target:self];
	}
}
- (void)update:(double)arg1 {
	%orig;
	if (!mancalaOverlay) return;
	[self updateMancalaOverlay];
}
%new
- (void)updateMancalaOverlay {
	NSArray *pitsArr = nil;
	@try { pitsArr = [self valueForKey:@"pits"]; } @catch (id ex) {}
	if (!pitsArr || pitsArr.count < 14) return;

	int board[14] = {0};
	for (int i = 0; i < 14; i++) {
		id p = pitsArr[i];
		board[i] = [p respondsToSelector:@selector(count)] ? (int)[p count] : [p intValue];
	}

	for (int i = 0; i < 6; i++) {
		MancalaPitEvaluation eval = evaluateMancalaPit(board, i, 1);
		NSString *badgeName = [NSString stringWithFormat:@"mancala_badge_%d", i];
		SKLabelNode *badge = (SKLabelNode *)[self childNodeWithName:badgeName];
		if (!badge) {
			badge = [SKLabelNode labelNodeWithFontNamed:@"Helvetica-Bold"];
			badge.name = badgeName;
			badge.fontSize = 13.0;
			badge.zPosition = 999;
			[self addChild:badge];
		}
		SKNode *pitNode = pitsArr[i];
		badge.position = CGPointMake(pitNode.position.x, pitNode.position.y + 35.0);

		if (eval.isFreeTurn) {
			badge.text = @"⭐ Turn";
			badge.fontColor = [UIColor colorWithRed:1.0 green:0.85 blue:0.1 alpha:1.0];
		} else if (eval.isCapture) {
			badge.text = [NSString stringWithFormat:@"🎯 +%d", eval.seedsCaptured];
			badge.fontColor = [UIColor colorWithRed:0.2 green:0.95 blue:0.3 alpha:1.0];
		} else {
			badge.text = @"";
		}
	}
}
%end

%hook DotsScene
- (void)didMoveToView:(id)arg1 {
	%orig;
	if (floatingHUD) {
		[SeagullHUD attachToView:self.view gameType:@"Dots & Boxes" target:self];
	}
}
- (void)update:(double)arg1 {
	%orig;
	if (!dotsOverlay) return;
	[self updateDotsOverlay];
}
%new
- (void)updateDotsOverlay {
	NSArray *lines = nil;
	@try { lines = [self valueForKey:@"lines"]; } @catch (id ex) {}
	if (!lines) return;

	for (SKNode *lineNode in lines) {
		if (![lineNode respondsToSelector:@selector(hidden)] || lineNode.hidden == NO) continue;
		int boxA = 0, boxB = 0;
		@try {
			boxA = [[lineNode valueForKey:@"boxA_count"] intValue];
			boxB = [[lineNode valueForKey:@"boxB_count"] intValue];
		} @catch (id ex) {}

		DotsLineQuality q = evaluateDotsLineQuality(boxA, boxB);
		if ([lineNode isKindOfClass:[SKShapeNode class]]) {
			SKShapeNode *shape = (SKShapeNode *)lineNode;
			if (q == DOTS_MOVE_CAPTURE || q == DOTS_MOVE_DOUBLE) {
				shape.strokeColor = [UIColor colorWithRed:0.1 green:0.95 blue:0.2 alpha:1.0];
			} else if (q == DOTS_MOVE_DANGER) {
				shape.strokeColor = [UIColor colorWithRed:1.0 green:0.2 blue:0.2 alpha:1.0];
			} else {
				shape.strokeColor = [UIColor colorWithRed:0.2 green:0.7 blue:1.0 alpha:0.8];
			}
		}
	}
}
%end

%hook GomokuScene
- (void)didMoveToView:(id)arg1 {
	%orig;
	if (floatingHUD) {
		[SeagullHUD attachToView:self.view gameType:@"Gomoku" target:self];
	}
}
- (void)update:(double)arg1 {
	%orig;
	if (!gomokuOverlay) return;
	[self updateGomokuOverlay];
}
%new
- (void)updateGomokuOverlay {
	NSArray *gridArr = nil;
	@try { gridArr = [self valueForKey:@"board"]; } @catch (id ex) {}
	int grid[15][15] = {0};
	if (gridArr && gridArr.count >= 15) {
		for (int r = 0; r < 15; r++) {
			NSArray *row = gridArr[r];
			for (int c = 0; c < 15 && c < (int)row.count; c++) {
				grid[r][c] = [row[c] intValue];
			}
		}
	}
	GomokuMove move = evaluateGomokuGrid(grid, 1);
	SKNode *guide = [self childNodeWithName:@"gomoku_guide"];
	if (!guide) {
		SKShapeNode *circle = [SKShapeNode shapeNodeWithCircleOfRadius:12.0];
		circle.name = @"gomoku_guide";
		circle.strokeColor = [UIColor colorWithRed:0.1 green:0.95 blue:0.3 alpha:1.0];
		circle.lineWidth = 2.5;
		circle.zPosition = 999;
		[self addChild:circle];
		guide = circle;
	}
	CGFloat cellW = self.size.width / 15.0;
	guide.position = CGPointMake(cellW * move.bestCol + cellW * 0.5, cellW * move.bestRow + cellW * 0.5);
}
%end

#define IMPLEMENT_BASKETBALL_HOOK(SceneClass) \
%hook SceneClass \
%property (nonatomic, retain) UIButton *autoBasketButton; \
- (void)didMoveToView:(id)arg1 { \
	%orig; \
	if (floatingHUD) { \
		[SeagullHUD attachToView:self.view gameType:@"Basketball" target:self]; \
	} \
	if (basketAutoSwish) { \
		CGFloat topInset = 20.0; \
		if (@available(iOS 11.0, *)) { \
			topInset = self.view.safeAreaInsets.top + 10.0; \
		} \
		self.autoBasketButton = makeButton(@"Auto Swish", CGRectMake([UIScreen mainScreen].bounds.size.width / 2 - 55, topInset, 110, 36), self, @selector(gp_autoSwishShoot)); \
		[self.view addSubview:self.autoBasketButton]; \
		[self.view bringSubviewToFront:self.autoBasketButton]; \
	} \
} \
- (void)update:(double)arg1 { \
	%orig; \
	if (basketInfiniteTimer) { \
		@try { \
			[self setValue:@(60) forKey:@"time"]; \
			[self setValue:@(60) forKey:@"shot_time"]; \
		} @catch (id ex) {} \
	} \
} \
%new \
- (void)gp_autoSwishShoot { \
	CGPoint startPos = CGPointMake(self.size.width * 0.5, 140.0); \
	CGPoint hoopPos = CGPointMake(self.size.width * 0.5, self.size.height - 180.0); \
	if ([self respondsToSelector:@selector(touchDownAtPoint:)]) { \
		[self touchDownAtPoint:startPos]; \
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.06 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ \
			[self touchMovedToPoint:CGPointMake(startPos.x, startPos.y + 60.0)]; \
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.06 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ \
				[self touchUpAtPoint:hoopPos]; \
			}); \
		}); \
	} \
} \
%new \
- (void)autoThrowBasket { \
	[self gp_autoSwishShoot]; \
} \
%end

IMPLEMENT_BASKETBALL_HOOK(BasketballScene)
IMPLEMENT_BASKETBALL_HOOK(BasketScene)

%hook TanksScene
- (void)didMoveToView:(id)arg1 {
	%orig;
	if (floatingHUD) {
		[SeagullHUD attachToView:self.view gameType:@"Tanks" target:self];
	}
}

- (void)setWind:(float)arg1 {
	if (tanksDisableWind) {
		%orig(0.0f);
	} else {
		%orig;
	}
}

- (void)SetWind:(float)arg1 {
	if (tanksDisableWind) {
		%orig(0.0f);
	} else {
		%orig;
	}
}

- (void)update:(double)arg1 {
	%orig;
	if (tanksTrajectory) {
		@try {
			SKShapeNode *traj = [self valueForKey:@"trajectory"];
			if (traj) {
				traj.hidden = NO;
			}
		} @catch (id ex) {}
	}
}
%end

%hook GolfScene2
%property (nonatomic, retain) UIButton *golfAutoButton;
%property (nonatomic, retain) SKShapeNode *golfTrajectoryNode;

- (void)didMoveToView:(id)arg1 {
	%orig;
	if (floatingHUD) {
		[SeagullHUD attachToView:self.view gameType:@"Golf" target:self];
	}
	if (golfAutoPuttStealth) {
		CGFloat topInset = 20.0;
		if (@available(iOS 11.0, *)) {
			topInset = self.view.safeAreaInsets.top + 10.0;
		}
		self.golfAutoButton = makeButton(@"Auto Hole-In-1", CGRectMake([UIScreen mainScreen].bounds.size.width / 2 - 65, topInset, 130, 36), self, @selector(autoShootHoleInOne));
		[self.view addSubview:self.golfAutoButton];
		[self.view bringSubviewToFront:self.golfAutoButton];
	}
}

- (void)update:(double)arg1 {
	%orig;
	updateGolfTrajectoryMap((SKScene *)self);
}

%new
- (void)autoShootHoleInOne {
	executeGolfAutoPuttStealth((SKScene *)self);
}
%end

%hook CheckersScene
- (void)didMoveToView:(id)arg1 {
	%orig;
	if (floatingHUD) {
		[SeagullHUD attachToView:self.view gameType:@"Checkers" target:self];
	}
}

%new
- (void)autoPlayBestCheckersMove {
	int board[8][8] = {0};
	int myPlayer = 1;
	@try {
		myPlayer = [[self valueForKey:@"player"] intValue] ?: 1;
		NSArray *pieces = [self valueForKey:@"board_pieces"];
		if ([pieces isKindOfClass:[NSArray class]]) {
			for (int r = 0; r < 8; r++) {
				for (int c = 0; c < 8; c++) {
					int idx = r * 8 + c;
					if (idx < pieces.count) {
						id p = pieces[idx];
						if (p && ![p isEqual:[NSNull null]]) {
							int pl = [[p valueForKey:@"player"] intValue];
							BOOL isKing = [[p valueForKey:@"isKing"] boolValue];
							board[r][c] = pl + (isKing ? 2 : 0);
						}
					}
				}
			}
		}
	} @catch (id ex) {}

	CheckersEvaluation eval = evaluateCheckersMoves(board, myPlayer);
	if (eval.fromRow >= 0 && eval.toRow >= 0) {
		CGFloat tileSize = self.size.width / 8.0f;
		CGPoint startPt = CGPointMake(tileSize * (eval.fromCol + 0.5f), tileSize * (eval.fromRow + 0.5f));
		CGPoint endPt = CGPointMake(tileSize * (eval.toCol + 0.5f), tileSize * (eval.toRow + 0.5f));
		if ([self respondsToSelector:@selector(touchDownAtPoint:)]) {
			[self touchDownAtPoint:startPt];
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				[self touchMovedToPoint:endPt];
				[self touchUpAtPoint:endPt];
			});
		}
	}
}
%end

%hook ChessScene
- (void)didMoveToView:(id)arg1 {
	%orig;
	if (floatingHUD) {
		[SeagullHUD attachToView:self.view gameType:@"Chess" target:self];
	}
}
%end

%hook ReversiScene
- (void)didMoveToView:(id)arg1 {
	%orig;
	if (floatingHUD) {
		[SeagullHUD attachToView:self.view gameType:@"Reversi" target:self];
	}
}

%new
- (void)autoPlayBestReversiMove {
	int board[8][8] = {0};
	int myPlayer = 1;
	@try {
		myPlayer = [[self valueForKey:@"player"] intValue] ?: 1;
		NSArray *boardPieces = [self valueForKey:@"board_pieces"];
		if ([boardPieces isKindOfClass:[NSArray class]]) {
			for (int r = 0; r < 8; r++) {
				for (int c = 0; c < 8; c++) {
					int idx = r * 8 + c;
					if (idx < boardPieces.count) {
						id p = boardPieces[idx];
						if (p && ![p isEqual:[NSNull null]]) {
							board[r][c] = [[p valueForKey:@"player"] intValue];
						}
					}
				}
			}
		}
	} @catch (id ex) {}

	ReversiEvaluation eval = evaluateReversiBoard(board, myPlayer);
	if (eval.bestRow >= 0 && eval.bestCol >= 0) {
		if ([self respondsToSelector:@selector(touchDownAtPoint:)]) {
			CGFloat tileSize = self.size.width / 8.0f;
			CGPoint pt = CGPointMake(tileSize * (eval.bestCol + 0.5f), tileSize * (eval.bestRow + 0.5f));
			[self touchDownAtPoint:pt];
			[self touchUpAtPoint:pt];
		}
	}
}
%end

%hook FillScene
- (void)didMoveToView:(id)arg1 {
	%orig;
	if (floatingHUD) {
		[SeagullHUD attachToView:self.view gameType:@"Fill" target:self];
	}
}

%new
- (void)instantWin {
	@try {
		if ([self respondsToSelector:@selector(finalWin)]) {
			[self finalWin];
		}
	} @catch (id ex) {}
}

%new
- (void)autoPickBestColor {
	int grid[12][8] = {0};
	int p1 = 0, p2 = 1, myP = 1;
	@try {
		myP = [[self valueForKey:@"player"] intValue] ?: 1;
		p1 = [[self valueForKey:@"score1"] intValue] ?: 0;
		p2 = [[self valueForKey:@"score2"] intValue] ?: 1;
		NSArray *tiles = [self valueForKey:@"board"];
		if ([tiles isKindOfClass:[NSArray class]]) {
			for (int r = 0; r < 12; r++) {
				for (int c = 0; c < 8; c++) {
					int idx = r * 8 + c;
					if (idx < tiles.count) {
						grid[r][c] = [[tiles[idx] valueForKey:@"color"] intValue];
					}
				}
			}
		}
	} @catch (id ex) {}

	int bestColor = getBestFillerColor(grid, p1, p2, myP);
	@try {
		if ([self respondsToSelector:@selector(fill:num:)]) {
			[self fill:nil num:bestColor];
		}
	} @catch (id ex) {}
}
%end

%hook PaintScene
- (void)didMoveToView:(id)arg1 {
	%orig;
	if (floatingHUD) {
		[SeagullHUD attachToView:self.view gameType:@"Paint" target:self];
	}
}

- (void)update:(double)arg1 {
	%orig;
	if (paintESP) {
		@try {
			if ([self respondsToSelector:@selector(showEnemy)]) {
				[self showEnemy];
			}
		} @catch (id ex) {}
	}
}

%new
- (void)autoAimEnemy {
	@try {
		if ([self respondsToSelector:@selector(showEnemy)]) {
			[self showEnemy];
		}
		if ([self respondsToSelector:@selector(meShoot)]) {
			[self meShoot];
		}
	} @catch (id ex) {}
}
%end

%hook ShuffleScene
- (void)didMoveToView:(id)arg1 {
	%orig;
	if (floatingHUD) {
		[SeagullHUD attachToView:self.view gameType:@"Shuffle" target:self];
	}
}

%new
- (void)launchPerfectPuck {
	CGPoint startPos = CGPointMake(self.size.width * 0.5f, 150.0f);
	CGPoint targetPos = CGPointMake(self.size.width * 0.5f, self.size.height * 0.82f);
	if ([self respondsToSelector:@selector(touchDownAtPoint:)]) {
		[self touchDownAtPoint:startPos];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[self touchMovedToPoint:CGPointMake(startPos.x, startPos.y + 80.0f)];
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				[self touchUpAtPoint:targetPos];
			});
		});
	}
}
%end

%hook ShuffleScene2
- (void)didMoveToView:(id)arg1 {
	%orig;
	if (floatingHUD) {
		[SeagullHUD attachToView:self.view gameType:@"Shuffle" target:self];
	}
}

%new
- (void)launchPerfectPuck {
	CGPoint startPos = CGPointMake(self.size.width * 0.5f, 150.0f);
	CGPoint targetPos = CGPointMake(self.size.width * 0.5f, self.size.height * 0.82f);
	if ([self respondsToSelector:@selector(touchDownAtPoint:)]) {
		[self touchDownAtPoint:startPos];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[self touchMovedToPoint:CGPointMake(startPos.x, startPos.y + 80.0f)];
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				[self touchUpAtPoint:targetPos];
			});
		});
	}
}
%end

%hook CrazyScene
- (void)didMoveToView:(id)arg1 {
	%orig;
	if (floatingHUD) {
		[SeagullHUD attachToView:self.view gameType:@"Crazy" target:self];
	}
}

%new
- (void)instantWin {
	@try {
		if ([self respondsToSelector:@selector(winner)]) {
			[self winner];
		}
	} @catch (id ex) {}
}
%end

%hook KnockScene
- (void)didMoveToView:(id)arg1 {
	%orig;
	if (floatingHUD) {
		[SeagullHUD attachToView:self.view gameType:@"Knock" target:self];
	}
}

%new
- (void)superPuckShoot {
	CGPoint startPos = CGPointMake(self.size.width * 0.5f, 160.0f);
	CGPoint targetPos = CGPointMake(self.size.width * 0.5f, self.size.height - 120.0f);
	if ([self respondsToSelector:@selector(touchDownAtPoint:)]) {
		[self touchDownAtPoint:startPos];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.04 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[self touchMovedToPoint:CGPointMake(startPos.x, startPos.y + 120.0f)];
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.04 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				[self touchUpAtPoint:targetPos];
			});
		});
	}
}
%end

%hook GameIcon
- (void)setWins:(int)arg1 {
	NSString *wins = getPreferences()[self._id];
	if (!wins || wins.length == 0) {
		wins = [[NSUserDefaults standardUserDefaults] stringForKey:self._id];
	}
	%orig(wins.length ? wins.intValue : arg1);
}
%end

%hook SettingsScene
- (void)didMoveToView:(id)arg1 {
	%orig;
	if (self.view && ![self.view viewWithTag:99901]) {
		UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
		btn.tag = 99901;
		[btn setTitle:@"🕊️ GameSeagull Settings" forState:UIControlStateNormal];
		[btn setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
		btn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
		btn.backgroundColor = [[UIColor secondarySystemBackgroundColor] colorWithAlphaComponent:0.95];
		btn.layer.cornerRadius = 14;
		btn.layer.masksToBounds = YES;
		btn.layer.borderWidth = 1.0;
		btn.layer.borderColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.35].CGColor;
		[btn addTarget:self action:@selector(openSettings) forControlEvents:UIControlEventTouchUpInside];
		btn.translatesAutoresizingMaskIntoConstraints = NO;
		[self.view addSubview:btn];

		[NSLayoutConstraint activateConstraints:@[
			[btn.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
			[btn.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-24],
			[btn.widthAnchor constraintEqualToConstant:230],
			[btn.heightAnchor constraintEqualToConstant:46]
		]];
	}
}

%new
- (void)openSettings {
	presentGameSeagullSettings(self.view);
}
%end


static void loadPrefs(void) {
	reloadPreferences();
	archeryDisableWind = boolForKey(@"kArcheryDisableWind");
	archeryDisableTimer = boolForKey(@"kDisableTimer");
	archery50ft = boolForKey(@"kArchery50ft");
	extendLines = boolForKey(@"kExtendLines");
	disableHardmode = boolForKey(@"kDisableHardMode");
	alwaysShowLines = boolForKey(@"kAlwaysShowLines");
	rgbLine = boolForKey(@"kRGBLine");
	alwaysMoveCueBall = boolForKey(@"kAlwaysMoveCueBall");
	poolBankShots = boolForKey(@"kPoolBankShots");
	poolFullTrajectory = boolForKey(@"kPoolFullTrajectory");
	poolBreakToOneTurnWin = boolForKey(@"kPoolBreakToOneTurnWin");
	oneDartWin = boolForKey(@"kOneDart");
	dartAimbot = boolForKey(@"kDartsAimbot");
	tanksDisableWind = boolForKey(@"kTanksDisableWind");
	tanksTrajectory = boolForKey(@"kTanksTrajectory");
	alwaysHoleInOne = boolForKey(@"kHoleInOne");
	golfLegitMode = boolForKey(@"kGolfLegitMode");
	golfTrajectoryMap = boolForKey(@"kGolfTrajectoryMap");
	golfAutoPuttStealth = boolForKey(@"kGolfAutoPuttStealth");
	oneCupWin = boolForKey(@"kOneCup");
	autoCupPong = boolForKey(@"kAutoCupPong");
	revealWords = boolForKey(@"kRevealWords");
	autoEnterWords = boolForKey(@"kAutoEnterWords");
	seeEnemyShips = boolForKey(@"kSeeEnemies");
	basketAutoSwish = boolForKey(@"kBasketAutoSwish");
	basketInfiniteTimer = boolForKey(@"kBasketInfiniteTimer");
	floatingHUD = getPreferences()[@"kFloatingHUD"] ? boolForKey(@"kFloatingHUD") : true;
	connect4Overlay = boolForKey(@"kConnect4Overlay");
	mancalaOverlay = boolForKey(@"kMancalaOverlay");
	dotsOverlay = boolForKey(@"kDotsOverlay");
	gomokuOverlay = boolForKey(@"kGomokuOverlay");
	bitesAutoSolve = boolForKey(@"kBitesAutoSolve");
	seaAutoSink = boolForKey(@"kSeaAutoSink");
	poolPocketAssist = boolForKey(@"kPoolPocketAssist");
	checkersOverlay = boolForKey(@"kCheckersOverlay");
	reversiOverlay = boolForKey(@"kReversiOverlay");
	chessOverlay = boolForKey(@"kChessOverlay");
	fillOverlay = boolForKey(@"kFillOverlay");
	paintESP = boolForKey(@"kPaintESP");
	shuffleGuide = boolForKey(@"kShuffleGuide");
	knockSuperImpulse = boolForKey(@"kKnockSuperImpulse");
}

static void prefsNotificationCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	loadPrefs();
}

%ctor {
	CFNotificationCenterAddObserver(
		CFNotificationCenterGetDarwinNotifyCenter(),
		NULL,
		prefsNotificationCallback,
		CFSTR("com.fiore.gameseagull.prefs/ReloadPrefs"),
		NULL,
		CFNotificationSuspensionBehaviorDeliverImmediately
	);
	loadPrefs();

	if (extendLines) {
		uint32_t patch = 0x52a9cdc8;
		uint8_t needle[4] = { 0x08, 0x4e, 0xa8, 0x52 };
		for (NSString *class in @[@"PoolScene", @"PoolScene2", @"PoolScene3"]) {
			Class cls = NSClassFromString(class);
			if (!cls) continue;
			uint64_t method = (uint64_t)[cls instanceMethodForSelector:@selector(mMove)];
			if (!method) continue;
			uint64_t result = bh_memmem((const uint8_t*)method, 0x1000, needle, 4);
			if (!result) continue;

			HookMemory(cls, @selector(mMove), (result - method), patch);
		}
	}
	
	%init;
}
