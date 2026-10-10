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
bool pokerCardESP;
bool questionsESP;
bool unlockAllContent;
bool infiniteReveals;
bool noAds;
bool paintGodMode;
bool paintDisarm;

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

// ---- Pool ball/pocket discovery (2.0.13 has no balls/pockets arrays) ----
static CGPoint PoolScenePoint(SKScene *scene, SKNode *node) {
	CGPoint p = node.position;
	@try {
		if (node.parent && node.scene == scene) p = [scene convertPoint:CGPointZero fromNode:node];
	} @catch (id ex) {}
	return p;
}

static void PoolCollectBalls(SKScene *scene, SKNode *root, NSMutableArray *out, Class poolBall) {
	@try {
		NSArray *kids = [root valueForKey:@"children"];
		if (![kids isKindOfClass:[NSArray class]]) return;
		for (SKNode *n in kids) {
			if (poolBall && [n isKindOfClass:poolBall] && ![out containsObject:n]) [out addObject:n];
			PoolCollectBalls(scene, n, out, poolBall);
		}
	} @catch (id ex) {}
}

static NSArray *PoolAllBalls(SKScene *scene) {
	NSMutableArray *out = [NSMutableArray array];
	@try {
		for (NSString *k in @[@"cue_ball", @"white", @"ball1", @"ball2", @"black_ball"]) {
			id b = [scene valueForKey:k];
			if (b && [b isKindOfClass:[SKNode class]] && ![out containsObject:b]) [out addObject:b];
		}
	} @catch (id ex) {}
	PoolCollectBalls(scene, scene, out, NSClassFromString(@"PoolBall"));
	return out;
}

static NSArray *PoolAllPockets(SKScene *scene) {
	@try {
		NSArray *holes = [scene valueForKey:@"holes"];
		if ([holes isKindOfClass:[NSArray class]] && holes.count > 0) return holes;
		NSArray *gh = [scene valueForKey:@"glow_holes"];
		if ([gh isKindOfClass:[NSArray class]] && gh.count > 0) return gh;
	} @catch (id ex) {}
	return @[];
}

static void updateFullPoolTrajectory(SKScene *scene) {
	if (!poolFullTrajectory) return;

	NSArray *balls = PoolAllBalls(scene);
	if (!balls || balls.count == 0) return;

	NSArray *pockets = PoolAllPockets(scene);

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

	__block CGPoint firstPt = PoolScenePoint(scene, cueBall);
	__block CGPoint lastPt = PoolScenePoint(scene, cueBall);
	CGPathApplyWithBlock(canvas.path, ^(const CGPathElement *element) {
		if (element->type == kCGPathElementMoveToPoint) {
			firstPt = element->points[0];
		} else if (element->type == kCGPathElementAddLineToPoint) {
			lastPt = element->points[0];
		}
	});
	// Canvas path lives in the canvas node's space: convert to scene space
	firstPt = [scene convertPoint:firstPt fromNode:canvas];
	lastPt = [scene convertPoint:lastPt fromNode:canvas];

	CGPoint shotDir = CGPointMake(lastPt.x - firstPt.x, lastPt.y - firstPt.y);
	if (hypot(shotDir.x, shotDir.y) < 2.0f) {
		id angleVal = nil;
		@try { angleVal = [scene valueForKey:@"angle"]; } @catch (id ex) {}
		if (angleVal) {
			float theta = [angleVal floatValue];
			shotDir = CGPointMake(cosf(theta), sinf(theta));
		} else {
			// 2.0.13 has no angle ivar: fall back to aim direction vector
			@try {
				for (NSString *dk in @[@"direction", @"start_direction", @"vec2"]) {
					id dir = [scene valueForKey:dk];
					if ([dir isKindOfClass:[NSValue class]]) {
						CGPoint dp = CGPointZero;
						[dir getValue:&dp];
						if (hypot(dp.x, dp.y) > 0.001f) { shotDir = dp; break; }
					}
				}
			} @catch (id ex2) {}
			if (hypot(shotDir.x, shotDir.y) < 2.0f) return;
		}
	}
	CGPoint cueDir = normalizeVec(shotDir);

	CGFloat minX = 40.0f, maxX = scene.size.width - 40.0f;
	CGFloat minY = 40.0f, maxY = scene.size.height - 40.0f;
	if (pockets && pockets.count >= 4) {
		minX = 1e9; maxX = -1e9; minY = 1e9; maxY = -1e9;
		for (SKNode *pocket in pockets) {
			CGPoint pp = PoolScenePoint(scene, pocket);
			if (pp.x < minX) minX = pp.x;
			if (pp.x > maxX) maxX = pp.x;
			if (pp.y < minY) minY = pp.y;
			if (pp.y > maxY) maxY = pp.y;
		}
	}
	CGFloat R_ball = 15.0f;
	@try {
		float rv = [[scene valueForKey:@"rad"] floatValue];
		if (rv >= 5.0f && rv <= 30.0f) R_ball = rv;
	} @catch (id exRad) {}
	CGPoint currentCuePos = PoolScenePoint(scene, cueBall);
	CGFloat cushionLeft = minX + R_ball;
	CGFloat cushionRight = maxX - R_ball;
	CGFloat cushionBottom = minY + R_ball;
	CGFloat cushionTop = maxY - R_ball;

	CGMutablePathRef fullPath = CGPathCreateMutable();
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
			CGPoint bPos = PoolScenePoint(scene, b);
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
		CGPoint targetBallPos = PoolScenePoint(scene, targetBall);
		ballHitNormal = normalizeVec(CGPointMake(targetBallPos.x - ballHitPos.x, targetBallPos.y - ballHitPos.y));
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
		CGPoint targetPos = PoolScenePoint(scene, targetBall);
		CGPoint targetDir = ballHitNormal;

		CGPoint cueDeflect = normalizeVec(CGPointMake(cueDir.x - dotProduct(cueDir, ballHitNormal) * ballHitNormal.x,
		                                              cueDir.y - dotProduct(cueDir, ballHitNormal) * ballHitNormal.y));
		CGPathMoveToPoint(fullPath, NULL, ballHitPos.x, ballHitPos.y);
		CGPathAddLineToPoint(fullPath, NULL, ballHitPos.x + cueDeflect.x * 120.0f, ballHitPos.y + cueDeflect.y * 120.0f);

		CGPathMoveToPoint(fullPath, NULL, targetPos.x, targetPos.y);

		BOOL targetEntersPocket = NO;
		if (pockets) {
			for (SKNode *pocket in pockets) {
				CGPoint pp = PoolScenePoint(scene, pocket);
				CGPoint toPocket = CGPointMake(pp.x - targetPos.x, pp.y - targetPos.y);
				CGFloat pProj = dotProduct(toPocket, targetDir);
				if (pProj > 0) {
					CGFloat perpSq = (toPocket.x * toPocket.x + toPocket.y * toPocket.y) - (pProj * pProj);
					if (perpSq <= (32.0f * 32.0f)) {
						CGPathAddLineToPoint(fullPath, NULL, pp.x, pp.y);
						CGPathAddArc(fullPath, NULL, pp.x, pp.y, 20.0f, 0, M_PI * 2, YES);
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
				CGPoint b2Pos = PoolScenePoint(scene, b2);
				CGPoint toB2 = CGPointMake(b2Pos.x - targetPos.x, b2Pos.y - targetPos.y);
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
				CGPoint secPos = PoolScenePoint(scene, secBall);
				CGPoint secNormal = normalizeVec(CGPointMake(secPos.x - secHitPos.x, secPos.y - secHitPos.y));
				CGPathMoveToPoint(fullPath, NULL, secPos.x, secPos.y);
				CGPathAddLineToPoint(fullPath, NULL, secPos.x + secNormal.x * 200.0f, secPos.y + secNormal.y * 200.0f);
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
	NSArray *balls = PoolAllBalls(scene);
	if (!balls || balls.count < 6) return;

	NSArray *pockets = PoolAllPockets(scene);
	if (!pockets || pockets.count < 6) return;

	int pocketIdx = 0;
	for (int i = 0; i < (int)balls.count; i++) {
		SKNode *b = balls[i];
		int num = -1;
		@try { num = [[b valueForKey:@"num"] intValue]; } @catch (id ex) {}
		if (num == 0) {
			// Cue ball: keep safely on table, avoid scratch
			b.physicsBody.velocity = CGVectorMake(0.0f, 0.0f);
			continue;
		}

		SKNode *targetPocket = pockets[pocketIdx % pockets.count];
		pocketIdx++;

		CGPoint bp = PoolScenePoint(scene, b);
		CGPoint tp = PoolScenePoint(scene, targetPocket);
		CGFloat dx = tp.x - bp.x;
		CGFloat dy = tp.y - bp.y;
		CGFloat dist = hypot(dx, dy);
		if (dist > 1.0f) {
			CGFloat speed = 1050.0f + (arc4random_uniform(150));
			b.physicsBody.velocity = CGVectorMake((dx / dist) * speed, (dy / dist) * speed);
		}
	}
}

// ---- Pool scene shared logic (plain C helpers: Logos directives cannot live inside #define) ----
static void PoolDidMoveToView(SKScene *scene) {
	if (disableHardmode) {
		[scene setValue:@"n" forKey:@"mode"];
	}
	if (floatingHUD) {
		[SeagullHUD attachToView:scene.view gameType:@"8-Ball / 9-Ball Pool" target:scene];
	}
}

// Extend the game's own guideline: draw a same-space continuation segment as
// a child of the canvas (no binary patching, works on every game version).
static void ExtendGameGuideline(SKScene *scene) {
	SKShapeNode *canvas = nil;
	@try { canvas = [scene valueForKey:@"canvas"]; } @catch (id ex) {}
	if (!canvas || !canvas.path) return;
	__block CGPoint segA = CGPointZero, segB = CGPointZero, cur = CGPointZero;
	__block BOOL haveSeg = NO;
	CGPathApplyWithBlock(canvas.path, ^(const CGPathElement *element) {
		if (element->type == kCGPathElementMoveToPoint) cur = element->points[0];
		else if (element->type == kCGPathElementAddLineToPoint) {
			segA = cur; segB = element->points[0]; cur = segB; haveSeg = YES;
		}
		else if (element->type == kCGPathElementAddQuadCurveToPoint) cur = element->points[1];
		else if (element->type == kCGPathElementAddCurveToPoint) cur = element->points[2];
	});
	if (!haveSeg) return;
	CGPoint d = CGPointMake(segB.x - segA.x, segB.y - segA.y);
	CGFloat len = hypot(d.x, d.y);
	if (len < 1.0f) return;
	// Only extend short guidelines: keeps this idempotent per frame.
	if (len >= 400.0f) {
		SKNode *old = [canvas childNodeWithName:@"gp_extend_line"];
		if (old) old.hidden = YES;
		return;
	}
	d.x /= len; d.y /= len;
	CGPoint newEnd = CGPointMake(segA.x + d.x * 400.0f, segA.y + d.y * 400.0f);
	SKShapeNode *ext = (SKShapeNode *)[canvas childNodeWithName:@"gp_extend_line"];
	if (!ext) {
		CGMutablePathRef empty = CGPathCreateMutable();
		ext = [SKShapeNode shapeNodeWithPath:empty];
		CGPathRelease(empty);
		ext.name = @"gp_extend_line";
		ext.lineWidth = 2.0f;
		ext.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.55];
		ext.zPosition = 998;
		[canvas addChild:ext];
	}
	CGMutablePathRef p = CGPathCreateMutable();
	CGPathMoveToPoint(p, NULL, segB.x, segB.y);
	CGPathAddLineToPoint(p, NULL, newEnd.x, newEnd.y);
	ext.path = p;
	ext.hidden = NO;
	CGPathRelease(p);
}

static void PoolUpdate(SKScene *scene) {
	if (rgbLine) {
		SKShapeNode *canvas = nil;
		@try { canvas = [scene valueForKey:@"canvas"]; } @catch (id ex) {}
		int hue = 0;
		@try { hue = [[scene valueForKey:@"currentColorHue"] intValue]; } @catch (id ex) {}
		hue = (hue + 1) % 360;
		@try { [scene setValue:@(hue) forKey:@"currentColorHue"]; } @catch (id ex) {}
		if (canvas) {
			[canvas setStrokeColor:[UIColor colorWithHue:hue/360.0 saturation:1.0 brightness:1.0 alpha:1.0]];
		}
	}
	if (alwaysMoveCueBall) {
		[scene setValue:@(true) forKey:@"move_white"];
	}
	if (poolPocketAssist) {
		@try {
			NSArray *balls = PoolAllBalls(scene);
			NSArray *pockets = PoolAllPockets(scene);
			if (balls.count > 0 && pockets.count > 0) {
				for (SKNode *b in balls) {
					if (!b.physicsBody) { continue; }
					CGVector vel = b.physicsBody.velocity;
					CGFloat speed = hypot(vel.dx, vel.dy);
					if (speed > 5.0f && speed < 800.0f) {
						CGPoint bp2 = PoolScenePoint(scene, b);
						CGPoint p = applyPoolPocketMagnet(bp2, CGPointMake(vel.dx, vel.dy), pockets, 40.0f);
						b.physicsBody.velocity = CGVectorMake(p.x, p.y);
					}
				}
			}
		} @catch (id ex) {}
	}
	if (extendLines) ExtendGameGuideline(scene);
}

static void PoolHideTraj(SKScene *scene) {
	SKNode *traj = [scene childNodeWithName:@"gp_full_pool_traj"];
	if (traj) traj.hidden = YES;
}

static void PoolAutoAimBestBall(SKScene *scene) {
	NSArray *balls = PoolAllBalls(scene);
	NSArray *pockets = PoolAllPockets(scene);
	SKNode *cueBall = nil;
	for (SKNode *b in balls) {
		int num = -1;
		@try { num = [[b valueForKey:@"num"] intValue]; } @catch (id ex) {}
		if (num == 0) {
			cueBall = b;
			break;
		}
	}
	if (!cueBall && balls.count > 0) cueBall = balls[0];
	if (!cueBall || !balls || !pockets) return;
	CGFloat bestAngle = calculateBestPoolShotAngle(PoolScenePoint(scene, cueBall), balls, pockets, 15.0f);
	@try {
		[scene setValue:@(bestAngle) forKey:@"angle"];
	} @catch (id ex) {}
	if (poolFullTrajectory) {
		updateFullPoolTrajectory(scene);
	}
}

static void PoolInstantWin(SKScene *scene) {
	@try {
		if ([scene respondsToSelector:@selector(showWin)]) {
			[(id)scene showWin];
		}
	} @catch (id ex) {}
}

%hook PoolScene
%property (nonatomic) int currentColorHue;
%property (nonatomic, retain) SKShapeNode *fullTrajNode;
- (void)didMoveToView:(id)arg1 {
	%orig;
	PoolDidMoveToView(self);
}
- (void)update:(double)arg1 {
	%orig;
	PoolUpdate(self);
}
- (void)mMove {
	%orig;
	if (poolFullTrajectory) {
		updateFullPoolTrajectory(self);
	}
}
- (void)shoot:(float)angle power:(float)power spin_x:(float)spin_x spin_y:(float)spin_y save:(BOOL)save {
	if (poolBreakToOneTurnWin) {
		executeBreakToOneTurnWin(self);
	}
	%orig;
	PoolHideTraj(self);
}
- (void)touchUpAtPoint:(CGPoint)arg1 {
	if (poolBreakToOneTurnWin) {
		executeBreakToOneTurnWin(self);
	}
	%orig;
	PoolHideTraj(self);
}
%new
- (void)triggerBreakToWinNow {
	executeBreakToOneTurnWin(self);
}
%new
- (void)instantWinPoolGame {
	PoolInstantWin(self);
}
%new
- (void)autoAimBestBall {
	PoolAutoAimBestBall(self);
}
%end

%hook PoolScene2
%property (nonatomic) int currentColorHue;
%property (nonatomic, retain) SKShapeNode *fullTrajNode;
- (void)didMoveToView:(id)arg1 {
	%orig;
	PoolDidMoveToView(self);
}
- (void)update:(double)arg1 {
	%orig;
	PoolUpdate(self);
}
- (void)mMove {
	%orig;
	if (poolFullTrajectory) {
		updateFullPoolTrajectory(self);
	}
}
- (void)shoot:(float)angle power:(float)power spin_x:(float)spin_x spin_y:(float)spin_y save:(BOOL)save {
	if (poolBreakToOneTurnWin) {
		executeBreakToOneTurnWin(self);
	}
	%orig;
	PoolHideTraj(self);
}
- (void)touchUpAtPoint:(CGPoint)arg1 {
	if (poolBreakToOneTurnWin) {
		executeBreakToOneTurnWin(self);
	}
	%orig;
	PoolHideTraj(self);
}
%new
- (void)triggerBreakToWinNow {
	executeBreakToOneTurnWin(self);
}
%new
- (void)instantWinPoolGame {
	PoolInstantWin(self);
}
%new
- (void)autoAimBestBall {
	PoolAutoAimBestBall(self);
}
%end

%hook PoolScene3
%property (nonatomic) int currentColorHue;
%property (nonatomic, retain) SKShapeNode *fullTrajNode;
- (void)didMoveToView:(id)arg1 {
	%orig;
	PoolDidMoveToView(self);
}
- (void)update:(double)arg1 {
	%orig;
	PoolUpdate(self);
}
- (void)mMove {
	%orig;
	if (poolFullTrajectory) {
		updateFullPoolTrajectory(self);
	}
}
- (void)shoot:(float)angle power:(float)power spin_x:(float)spin_x spin_y:(float)spin_y save:(BOOL)save {
	if (poolBreakToOneTurnWin) {
		executeBreakToOneTurnWin(self);
	}
	%orig;
	PoolHideTraj(self);
}
- (void)touchUpAtPoint:(CGPoint)arg1 {
	if (poolBreakToOneTurnWin) {
		executeBreakToOneTurnWin(self);
	}
	%orig;
	PoolHideTraj(self);
}
%new
- (void)triggerBreakToWinNow {
	executeBreakToOneTurnWin(self);
}
%new
- (void)instantWinPoolGame {
	PoolInstantWin(self);
}
%new
- (void)autoAimBestBall {
	PoolAutoAimBestBall(self);
}
%end

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
				strokesVal = [self.scene valueForKey:@"strokes"];
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
				strokesVal = [self.scene valueForKey:@"strokes"];
			} @catch (id ex) {}
			int strokes = strokesVal ? [strokesVal intValue] : 0;
			return (strokes >= 2) ? true : %orig;
		}
		return true;
	}
	return %orig;
}
%end

static SKNode *getGolfBallNode(SKScene *scene) {
	SKNode *ball = nil;
	@try { ball = [scene valueForKey:@"golf_ball"]; } @catch (id ex) {}
	if (!ball) { @try { ball = [scene valueForKey:@"golf_ball1"]; } @catch (id ex) {} }
	if (!ball) { @try { ball = [scene valueForKey:@"golf_ball2"]; } @catch (id ex) {} }
	if (!ball) { @try { ball = [scene valueForKey:@"ball"]; } @catch (id ex) {} }
	return ball;
}

static SKNode *getGolfHoleNode(SKScene *scene) {
	SKNode *hole = nil;
	@try { hole = [scene valueForKey:@"hole"]; } @catch (id ex) {}
	return hole;
}

static CGPoint GolfScenePoint(SKScene *scene, SKNode *node) {
	CGPoint p = node.position;
	@try {
		if (node.parent && node.scene == scene) p = [scene convertPoint:CGPointZero fromNode:node];
	} @catch (id ex) {}
	return p;
}

static void GolfPlayBounds(SKScene *scene, CGFloat *minX, CGFloat *maxX, CGFloat *minY, CGFloat *maxY) {
	*minX = 25.0f; *maxX = scene.size.width - 25.0f;
	*minY = 25.0f; *maxY = scene.size.height - 25.0f;
	@try {
		SKNode *ground = [scene valueForKey:@"ground"];
		if (ground && ground.parent == scene) {
			CGRect gf = ground.frame;
			if (gf.size.width > 100.0f && gf.size.height > 100.0f) {
				*minX = gf.origin.x + 12.0f; *maxX = gf.origin.x + gf.size.width - 12.0f;
				*minY = gf.origin.y + 12.0f; *maxY = gf.origin.y + gf.size.height - 12.0f;
			}
		}
	} @catch (id ex) {}
}

static void updateGolfTrajectoryMap(SKScene *scene, CGPoint dragVector) {
	if (!golfTrajectoryMap) return;

	SKNode *ball = getGolfBallNode(scene);
	if (!ball) return;

	SKNode *hole = getGolfHoleNode(scene);
	CGPoint holePos = hole ? GolfScenePoint(scene, hole) : CGPointMake(scene.size.width * 0.5f, scene.size.height * 0.8f);

	CGPoint p = GolfScenePoint(scene, ball);
	CGPoint v = CGPointMake(-dragVector.x * 4.2f, -dragVector.y * 4.2f);

	CGFloat minX, maxX, minY, maxY;
	GolfPlayBounds(scene, &minX, &maxX, &minY, &maxY);

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
	SKNode *ball = getGolfBallNode(scene);
	if (!ball) return;

	SKNode *hole = getGolfHoleNode(scene);
	CGPoint holePos = hole ? GolfScenePoint(scene, hole) : CGPointMake(scene.size.width * 0.5f, scene.size.height * 0.8f);

	CGPoint ballPos = GolfScenePoint(scene, ball);
	CGFloat bestAngle = 0.0f;
	CGFloat bestPower = 0.5f;
	CGFloat minFinalDist = 1e9;
	BOOL foundHoleInOne = NO;

	CGFloat minX, maxX, minY, maxY;
	GolfPlayBounds(scene, &minX, &maxX, &minY, &maxY);

	for (int a = 0; a < 72; a++) {
		CGFloat theta = (a * 5.0f) * (M_PI / 180.0f);
		for (CGFloat pwr = 0.35f; pwr <= 1.0f; pwr += 0.15f) {
			CGPoint p = ballPos;
			// Must match execution: dragDist 90 * preview factor 4.2
			CGPoint v = CGPointMake(cosf(theta) * pwr * 378.0f, sinf(theta) * pwr * 378.0f);

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
		((void (*)(id, SEL, CGPoint))objc_msgSend)(scene, @selector(touchDownAtPoint:), ballPos);
	}
	if ([scene respondsToSelector:@selector(touchMovedToPoint:)]) {
		((void (*)(id, SEL, CGPoint))objc_msgSend)(scene, @selector(touchMovedToPoint:), dragTouch);
	}
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		if ([scene respondsToSelector:@selector(touchUpAtPoint:)]) {
			((void (*)(id, SEL, CGPoint))objc_msgSend)(scene, @selector(touchUpAtPoint:), dragTouch);
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

	if (golfAutoPuttStealth && ![self.view viewWithTag:99101]) {
		CGFloat topInset = self.view.safeAreaInsets.top + 10.0;
		self.golfAutoButton = makeButton(@"Auto Putt", CGRectMake([UIScreen mainScreen].bounds.size.width / 2 - 50, topInset, 100, 36), self, @selector(autoShootHoleInOne));
		self.golfAutoButton.tag = 99101;
		[self.view addSubview:self.golfAutoButton];
		[self.view bringSubviewToFront:self.golfAutoButton];
	}
}

- (void)touchMovedToPoint:(CGPoint)pt {
	%orig;
	if (golfTrajectoryMap) {
		SKNode *ball = getGolfBallNode(self);
		if (ball) {
			CGPoint bp = GolfScenePoint(self, ball);
			CGPoint drag = CGPointMake(pt.x - bp.x, pt.y - bp.y);
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

%new
- (void)instantSinkInCup {
	SKNode *ball = getGolfBallNode(self);
	SKNode *hole = getGolfHoleNode(self);
	if (!ball || !hole) return;
	ball.position = hole.position;
	if (ball.physicsBody) {
		ball.physicsBody.velocity = CGVectorMake(0.0f, 0.0f);
	}
	@try {
		[ball setValue:@(true) forKey:@"inside"];
		[ball setValue:@(true) forKey:@"hole"];
	} @catch (id ex) {}
	if ([self respondsToSelector:@selector(testWin)]) {
		[self testWin];
	}
}
%end

%hook BeerScene

- (void)didMoveToView:(id)arg1 {
	%orig;

	if (floatingHUD) {
		[SeagullHUD attachToView:self.view gameType:@"Cup Pong" target:self.scene3d];
	}

	if (!autoCupPong || [self.view viewWithTag:99103]) return;

	CGFloat topInset = self.view.safeAreaInsets.top + 10.0;
	UIButton *button = makeButton(@"Shoot", CGRectMake([UIScreen mainScreen].bounds.size.width / 2 - 50, topInset, 100, 36), self.scene3d, @selector(shootRandomCup));
	button.tag = 99103;
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
	
	cup = liveCups[0];
	CGFloat bestD = 1e9;
	for (BeerCup *c in liveCups) {
		CGFloat dx = c.pos.x - ball.position.x;
		CGFloat dz = c.pos.z - ball.position.z;
		CGFloat d = dx*dx + dz*dz;
		if (d < bestD) { bestD = d; cup = c; }
	}
	
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
	for (id ship in ships) {
		@try {
			[ship setValue:@(NO) forKey:@"hidden"];
			if ([ship respondsToSelector:@selector(Die)]) {
				[ship Die];
			}
			SKNode *sprite = [ship valueForKey:@"sprite"];
			if (sprite) {
				sprite.hidden = NO;
				CGPoint pt = sprite.position;
				if ([self respondsToSelector:@selector(BombTo:)]) {
					((void (*)(id, SEL, CGPoint))objc_msgSend)(self, @selector(BombTo:), pt);
				}
			}
		} @catch (id ex) {}
	}
	@try {
		if ([self respondsToSelector:@selector(checkWin)]) {
			[self checkWin];
		}
	} @catch (id ex) {}
}

%new
- (void)strikeNextEnemyShip {
	NSArray *ships = nil;
	@try { ships = [self valueForKey:@"ships"]; } @catch (id ex) {}
	if (!ships) return;
	for (id ship in ships) {
		@try {
			SKNode *sprite = [ship valueForKey:@"sprite"];
			if (sprite && sprite.hidden) {
				sprite.hidden = NO;
				CGPoint pt = sprite.position;
				if ([self respondsToSelector:@selector(BombTo:)]) {
					((void (*)(id, SEL, CGPoint))objc_msgSend)(self, @selector(BombTo:), pt);
				}
				break;
			}
		} @catch (id ex) {}
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
%new
- (void)instantWinAnagrams {
	@try {
		if ([self respondsToSelector:@selector(winGame)]) {
			[self winGame];
		}
	} @catch (id ex) {}
}
%end

%hook HuntScene
%property (nonatomic, retain) NSArray *words;
%property (nonatomic, retain) UIButton *hunt_revealWordsButton;
%property (nonatomic, retain) UIButton *hunt_autoButton;

- (void)didMoveToView:(id)arg1 {
	%orig;
	NSString *gameName = @"Word Hunt";
	@try {
		if ([self respondsToSelector:@selector(getBiteGrid:y:)] || [self valueForKey:@"bytes"] != nil) {
			gameName = @"Word Bites";
		}
	} @catch (id ex) {}

	if (floatingHUD) {
		[SeagullHUD attachToView:self.view gameType:gameName target:self];
	}

	if (revealWords) {
		CGFloat topInset = self.view.safeAreaInsets.top + 10.0;
		self.hunt_revealWordsButton = makeButton(@"Words", CGRectMake([UIScreen mainScreen].bounds.size.width - 90, topInset, 75, 36), self, @selector(revealAllWordsInSheet));
		[self.view addSubview:self.hunt_revealWordsButton];
		[self.view bringSubviewToFront:self.hunt_revealWordsButton];

		self.hunt_autoButton = makeButton(@"Auto", CGRectMake([UIScreen mainScreen].bounds.size.width - 170, topInset, 75, 36), self, @selector(solveAndSubmitAllWords));
		[self.view addSubview:self.hunt_autoButton];
		[self.view bringSubviewToFront:self.hunt_autoButton];
	}
}

- (void)startGame {
	%orig;
	@try {
		self.words = [[[[self valueForKey:@"wordList"] valueForKey:@"words_string"] stringByReplacingOccurrencesOfString:@"?" withString:@""] componentsSeparatedByString:@"|"];
	} @catch (id ex) {}
}

- (void)toResult {
	%orig;
	[self.hunt_revealWordsButton removeFromSuperview];
	[self.hunt_autoButton removeFromSuperview];
}

%new
- (void)revealAllWordsInSheet {
	[self revealWords:YES];
	if (!self.words || self.words.count == 0) {
		@try {
			self.words = [[[[self valueForKey:@"wordList"] valueForKey:@"words_string"] stringByReplacingOccurrencesOfString:@"?" withString:@""] componentsSeparatedByString:@"|"];
		} @catch (id ex) {}
	}
	showWordList(self.view, @"Words", self.words ?: @[]);
}

%new
- (void)solveAndSubmitAllWords {
	[self revealWords:YES];
	if (!self.words || self.words.count == 0) {
		@try {
			self.words = [[[[self valueForKey:@"wordList"] valueForKey:@"words_string"] stringByReplacingOccurrencesOfString:@"?" withString:@""] componentsSeparatedByString:@"|"];
		} @catch (id ex) {}
	}
	if (self.words) {
		for (NSString *word in self.words) {
			@try {
				if ([self respondsToSelector:@selector(checkWord:flag:)]) {
					[self checkWord:word flag:0];
				} else if ([self respondsToSelector:@selector(checkWord:)]) {
					[self checkWord:word];
				}
			} @catch (id ex) {}
		}
	}
	@try {
		if ([self respondsToSelector:@selector(winGame)]) {
			[self winGame];
		}
	} @catch (id ex) {}
}
%new
- (void)instantWinAnagrams {
	@try {
		if ([self respondsToSelector:@selector(winGame)]) {
			[self winGame];
		}
	} @catch (id ex) {}
}
%end

%hook NoodleScene
%property (nonatomic, retain) NSArray *words;
- (void)didMoveToView:(id)arg1 {
	%orig;
	if (floatingHUD) {
		[SeagullHUD attachToView:self.view gameType:@"Word Bites" target:self];
	}
	if ((revealWords || bitesAutoSolve) && ![self.view viewWithTag:99105]) {
		CGFloat topInset = self.view.safeAreaInsets.top + 10.0;
		UIButton *wordsBtn = makeButton(@"Words", CGRectMake([UIScreen mainScreen].bounds.size.width - 90, topInset, 75, 36), self, @selector(revealAllWordsInSheet));
		wordsBtn.tag = 99105;
		[self.view addSubview:wordsBtn];
		[self.view bringSubviewToFront:wordsBtn];
		UIButton *autoBtn = makeButton(@"Auto", CGRectMake([UIScreen mainScreen].bounds.size.width - 170, topInset, 75, 36), self, @selector(solveAndSubmitAllWords));
		autoBtn.tag = 99106;
		[self.view addSubview:autoBtn];
		[self.view bringSubviewToFront:autoBtn];
	}
}
- (void)startGame {
	%orig;
	@try {
		self.words = [[[[self valueForKey:@"wordList"] valueForKey:@"words_string"] stringByReplacingOccurrencesOfString:@"?" withString:@""] componentsSeparatedByString:@"|"];
	} @catch (id ex) {}
	@try {
		if (!self.words || self.words.count == 0) {
			id w = [self valueForKey:@"words_ar"];
			if ([w isKindOfClass:[NSArray class]]) self.words = w;
		}
	} @catch (id ex) {}
}
- (void)toResult {
	%orig;
	[[self.view viewWithTag:99105] removeFromSuperview];
	[[self.view viewWithTag:99106] removeFromSuperview];
}
%new
- (void)revealAllWordsInSheet {
	if (!self.words || self.words.count == 0) {
		@try {
			self.words = [[[[self valueForKey:@"wordList"] valueForKey:@"words_string"] stringByReplacingOccurrencesOfString:@"?" withString:@""] componentsSeparatedByString:@"|"];
		} @catch (id ex) {}
	}
	showWordList(self.view, @"Bites", self.words ?: @[]);
}
%new
- (void)solveAndSubmitAllWords {
	if (!self.words || self.words.count == 0) {
		@try {
			self.words = [[[[self valueForKey:@"wordList"] valueForKey:@"words_string"] stringByReplacingOccurrencesOfString:@"?" withString:@""] componentsSeparatedByString:@"|"];
		} @catch (id ex) {}
	}
	if (self.words) {
		for (NSString *word in self.words) {
			@try {
				if ([self respondsToSelector:@selector(checkWord:flag:)]) {
					[self checkWord:word flag:0];
				} else if ([self respondsToSelector:@selector(checkWord:)]) {
					[self checkWord:word];
				}
			} @catch (id ex) {}
		}
	}
	@try {
		if ([self respondsToSelector:@selector(winGame)]) {
			[self winGame];
		}
	} @catch (id ex) {}
}
%new
- (void)instantWinAnagrams {
	@try {
		if ([self respondsToSelector:@selector(winGame)]) {
			[self winGame];
		}
	} @catch (id ex) {}
}
%end

// ---- Connect 4 shared logic (plain C helpers: Logos directives cannot live inside #define) ----
static void ConnectDidMoveToView(SKScene *scene, id target) {
	if (floatingHUD) {
		[SeagullHUD attachToView:scene.view gameType:@"Connect 4" target:target];
	}
}

static void ConnectUpdateMinimaxOverlay(SKScene *scene) {
	NSArray *gridArr = nil;
	@try { gridArr = [scene valueForKey:@"board"]; } @catch (id ex) {}
	int grid[6][7] = {0};
	if (gridArr && gridArr.count >= 6) {
		for (int r = 0; r < 6; r++) {
			NSArray *row = gridArr[r];
			for (int c = 0; c < 7 && c < (int)row.count; c++) {
				grid[r][c] = [row[c] intValue];
			}
		}
	}
	Connect4Evaluation eval = evaluateConnect4Grid(grid, 1);
	for (int c = 0; c < 7; c++) {
		NSString *nodeName = [NSString stringWithFormat:@"c4_ind_%d", c];
		SKLabelNode *lbl = (SKLabelNode *)[scene childNodeWithName:nodeName];
		if (!lbl) {
			lbl = [SKLabelNode labelNodeWithFontNamed:@"Helvetica-Bold"];
			lbl.name = nodeName;
			lbl.fontSize = 18.0;
			lbl.zPosition = 999;
			[scene addChild:lbl];
		}
		CGFloat colW = scene.size.width / 7.0;
		lbl.position = CGPointMake(colW * c + colW * 0.5, scene.size.height - 40.0);
		if (c == eval.bestColumn) {
			lbl.text = @"👑";
			lbl.fontColor = [UIColor greenColor];
		} else if (eval.columnScores[c] == -10000) {
			lbl.text = @"💀";
			lbl.fontColor = [UIColor redColor];
		} else {
			lbl.text = @"•";
			lbl.fontColor = [UIColor yellowColor];
		}
	}
}

%hook ConnectScene
- (void)didMoveToView:(id)arg1 {
	%orig;
	ConnectDidMoveToView(self, self);
}
- (void)update:(double)arg1 {
	%orig;
	if (!connect4Overlay) return;
	ConnectUpdateMinimaxOverlay(self);
}
%new
- (void)updateMinimaxOverlay {
	ConnectUpdateMinimaxOverlay(self);
}
%new
- (void)autoPlayBestConnectMove {
	NSArray *gridArr = nil;
	@try { gridArr = [self valueForKey:@"board"]; } @catch (id ex) {}
	int grid[6][7] = {0};
	if (gridArr && gridArr.count >= 6) {
		for (int r = 0; r < 6; r++) {
			NSArray *row = gridArr[r];
			for (int c = 0; c < 7 && c < (int)row.count; c++) {
				grid[r][c] = [row[c] intValue];
			}
		}
	}
	Connect4Evaluation eval = evaluateConnect4Grid(grid, 1);
	if (eval.bestColumn >= 0 && eval.bestColumn < 7) {
		CGFloat colW = self.size.width / 7.0;
		CGPoint pt = CGPointMake(colW * eval.bestColumn + colW * 0.5, self.size.height - 40.0);
		if ([self respondsToSelector:@selector(touchDownAtPoint:)]) {
			[self touchDownAtPoint:pt];
			[self touchUpAtPoint:pt];
		}
	}
}
%new
- (void)instantWinConnect {
	@try {
		if ([self respondsToSelector:@selector(testWin)]) {
			[self testWin];
		}
	} @catch (id ex) {}
}
%end

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
	NSMutableArray *pitsArr = [NSMutableArray array];
	@try {
		NSArray *s1 = [self valueForKey:@"spots1"];
		NSArray *s2 = [self valueForKey:@"spots2"];
		if ([s1 isKindOfClass:[NSArray class]]) [pitsArr addObjectsFromArray:s1];
		if ([s2 isKindOfClass:[NSArray class]]) [pitsArr addObjectsFromArray:s2];
	} @catch (id ex) {}
	if (pitsArr.count < 14) return;

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
%new
- (void)autoPlayBestMancalaMove {
	NSMutableArray *pitsArr = [NSMutableArray array];
	@try {
		NSArray *s1 = [self valueForKey:@"spots1"];
		NSArray *s2 = [self valueForKey:@"spots2"];
		if ([s1 isKindOfClass:[NSArray class]]) [pitsArr addObjectsFromArray:s1];
		if ([s2 isKindOfClass:[NSArray class]]) [pitsArr addObjectsFromArray:s2];
	} @catch (id ex) {}
	if (pitsArr.count < 14) return;
	int board[14] = {0};
	for (int i = 0; i < 14; i++) {
		id p = pitsArr[i];
		@try { board[i] = [p respondsToSelector:@selector(count)] ? (int)[p count] : [p intValue]; } @catch (id ex) {}
	}
	int best = getBestMancalaPit(board, 1);
	if (best >= 0 && best < 6) {
		SKNode *pitNode = pitsArr[best];
		if ([self respondsToSelector:@selector(touchDownAtPoint:)]) {
			[self touchDownAtPoint:pitNode.position];
			[self touchUpAtPoint:pitNode.position];
		}
	}
}
%new
- (void)instantWinMancala {
	@try {
		if ([self respondsToSelector:@selector(testWin)]) {
			[self testWin];
		}
	} @catch (id ex) {}
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
	// 2.0.13 exposes no per-line box counts: skip coloring rather than mislabel
	{
		BOOL haveCounts = NO;
		for (SKNode *ln in lines) {
			if (ln.hidden == NO) continue;
			@try { [ln valueForKey:@"boxA_count"]; haveCounts = YES; } @catch (id ex) {}
			break;
		}
		if (!haveCounts) return;
	}

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
%new
- (void)autoPlayBestDotsLine {
	NSArray *lines = nil;
	@try { lines = [self valueForKey:@"lines"]; } @catch (id ex) {}
	if (!lines) return;
	SKNode *fallback = nil;
	for (SKNode *lineNode in lines) {
		if (lineNode.hidden == NO) continue;
		int boxA = -1, boxB = -1;
		@try {
			boxA = [[lineNode valueForKey:@"boxA_count"] intValue];
			boxB = [[lineNode valueForKey:@"boxB_count"] intValue];
		} @catch (id ex) {}
		if (boxA < 0) {
			// 2.0.13 exposes no per-line counts: tap the first legal line
			if ([self respondsToSelector:@selector(touchDownAtPoint:)]) {
				[self touchDownAtPoint:lineNode.position];
				[self touchUpAtPoint:lineNode.position];
			}
			return;
		}
		DotsLineQuality q = evaluateDotsLineQuality(boxA, boxB);
		if (q == DOTS_MOVE_CAPTURE || q == DOTS_MOVE_DOUBLE) {
			if ([self respondsToSelector:@selector(touchDownAtPoint:)]) {
				[self touchDownAtPoint:lineNode.position];
				[self touchUpAtPoint:lineNode.position];
			}
			return;
		}
		if (q == DOTS_MOVE_SAFE && !fallback) fallback = lineNode;
	}
	if (fallback && [self respondsToSelector:@selector(touchDownAtPoint:)]) {
		[self touchDownAtPoint:fallback.position];
		[self touchUpAtPoint:fallback.position];
	}
}
%end

%hook RenjuScene
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
%new
- (void)autoPlayBestRenjuMove {
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
	if (move.bestRow >= 0 && move.bestCol >= 0) {
		CGFloat cellW = self.size.width / 15.0;
		CGPoint pt = CGPointMake(cellW * move.bestCol + cellW * 0.5, cellW * move.bestRow + cellW * 0.5);
		if ([self respondsToSelector:@selector(touchDownAtPoint:)]) {
			[self touchDownAtPoint:pt];
			[self touchUpAtPoint:pt];
		}
	}
}
%end

// ---- Basketball shared logic (plain C helpers: Logos directives cannot live inside #define) ----
static void BasketballDidMoveToView(SKScene *scene, id target) {
	if (floatingHUD) {
		[SeagullHUD attachToView:scene.view gameType:@"Basketball" target:target];
	}
	if (basketAutoSwish && ![scene.view viewWithTag:99104]) {
		CGFloat topInset = scene.view.safeAreaInsets.top + 10.0;
		UIButton *btn = makeButton(@"Auto Swish", CGRectMake([UIScreen mainScreen].bounds.size.width / 2 - 55, topInset, 110, 36), target, @selector(gp_autoSwishShoot));
		btn.tag = 99104;
		@try { [target setValue:btn forKey:@"autoBasketButton"]; } @catch (id ex) {}
		[scene.view addSubview:btn];
		[scene.view bringSubviewToFront:btn];
	}
}

static void BasketballUpdate(SKScene *scene) {
	if (basketInfiniteTimer) {
		@try {
			[scene setValue:@(60) forKey:@"time"];
			[scene setValue:@(60) forKey:@"shot_time"];
		} @catch (id ex) {}
	}
}

static void BasketballAutoSwish(SKScene *scene) {
	CGPoint startPos = CGPointMake(scene.size.width * 0.5, 140.0);
	CGPoint hoopPos = CGPointMake(scene.size.width * 0.5, scene.size.height - 180.0);
	if ([scene respondsToSelector:@selector(touchDownAtPoint:)]) {
		[(id)scene touchDownAtPoint:startPos];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.06 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[(id)scene touchMovedToPoint:CGPointMake(startPos.x, startPos.y + 60.0)];
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.06 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				[(id)scene touchUpAtPoint:hoopPos];
			});
		});
	}
}

%hook BasketballScene
%property (nonatomic, retain) UIButton *autoBasketButton;
- (void)didMoveToView:(id)arg1 {
	%orig;
	BasketballDidMoveToView(self, self);
}
- (void)update:(double)arg1 {
	%orig;
	BasketballUpdate(self);
}
%new
- (void)gp_autoSwishShoot {
	BasketballAutoSwish(self);
}
%new
- (void)autoThrowBasket {
	BasketballAutoSwish(self);
}
%end

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
%new
- (void)instantWinTanks {
	@try {
		if ([self respondsToSelector:@selector(showWin)]) {
			[self showWin];
		}
	} @catch (id ex) {}
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
	if (golfAutoPuttStealth && ![self.view viewWithTag:99102]) {
		CGFloat topInset = self.view.safeAreaInsets.top + 10.0;
		self.golfAutoButton = makeButton(@"Auto Hole-In-1", CGRectMake([UIScreen mainScreen].bounds.size.width / 2 - 65, topInset, 130, 36), self, @selector(autoShootHoleInOne));
		self.golfAutoButton.tag = 99102;
		[self.view addSubview:self.golfAutoButton];
		[self.view bringSubviewToFront:self.golfAutoButton];
	}
}

- (void)touchMovedToPoint:(CGPoint)pt {
	%orig;
	if (golfTrajectoryMap) {
		SKNode *ball = getGolfBallNode((SKScene *)self);
		if (ball) {
			CGPoint bp = GolfScenePoint((SKScene *)self, ball);
			CGPoint drag = CGPointMake(pt.x - bp.x, pt.y - bp.y);
			updateGolfTrajectoryMap((SKScene *)self, drag);
		}
	}
}

- (void)touchUpAtPoint:(CGPoint)pt {
	%orig;
	SKNode *traj = [(SKScene *)self childNodeWithName:@"gp_golf_traj"];
	if (traj) traj.hidden = YES;
}

%new
- (void)autoShootHoleInOne {
	executeGolfAutoPuttStealth((SKScene *)self);
}

%new
- (void)instantSinkInCup {
	SKNode *ball = getGolfBallNode((SKScene *)self);
	SKNode *hole = getGolfHoleNode((SKScene *)self);
	if (!ball || !hole) return;
	ball.position = hole.position;
	if (ball.physicsBody) {
		ball.physicsBody.velocity = CGVectorMake(0.0f, 0.0f);
	}
	@try {
		[ball setValue:@(true) forKey:@"inside"];
		[ball setValue:@(true) forKey:@"hole"];
	} @catch (id ex) {}
	if ([self respondsToSelector:@selector(testWin)]) {
		[self testWin];
	}
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
		NSArray *rows = nil;
		@try { rows = [self valueForKey:@"board"]; } @catch (id ex) {}
		if ([rows isKindOfClass:[NSArray class]]) {
			for (int r = 0; r < 8 && r < (int)rows.count; r++) {
				id rowObj = rows[r];
				NSArray *row = [rowObj isKindOfClass:[NSArray class]] ? rowObj : nil;
				for (int c = 0; c < 8; c++) {
					id p = nil;
					if (row && c < (int)row.count) p = row[c];
					else if (!row && (r * 8 + c) < (int)rows.count) p = rows[r * 8 + c];
					if (!p || [p isEqual:[NSNull null]]) continue;
					@try {
						if ([p isKindOfClass:[NSNumber class]]) board[r][c] = [p intValue];
						else {
							int pl = [[p valueForKey:@"player"] intValue];
							BOOL isKing = NO;
							@try { isKing = [[p valueForKey:@"isKing"] boolValue]; } @catch (id ex2) {}
							board[r][c] = pl + (isKing ? 2 : 0);
						}
					} @catch (id ex3) {}
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
%new
- (void)instantWinCheckers {
	@try {
		if ([self respondsToSelector:@selector(testWin)]) {
			[self testWin];
		}
	} @catch (id ex) {}
}
%end

%hook ChessScene
- (void)didMoveToView:(id)arg1 {
	%orig;
	if (floatingHUD) {
		[SeagullHUD attachToView:self.view gameType:@"Chess" target:self];
	}
}
%new
- (void)instantWinChess {
	@try {
		if ([self respondsToSelector:@selector(testWin)]) {
			[self testWin];
		}
	} @catch (id ex) {}
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
		NSArray *rows = nil;
		@try { rows = [self valueForKey:@"board"]; } @catch (id ex) {}
		if ([rows isKindOfClass:[NSArray class]]) {
			for (int r = 0; r < 8 && r < (int)rows.count; r++) {
				id rowObj = rows[r];
				NSArray *row = [rowObj isKindOfClass:[NSArray class]] ? rowObj : nil;
				for (int c = 0; c < 8; c++) {
					id p = nil;
					if (row && c < (int)row.count) p = row[c];
					else if (!row && (r * 8 + c) < (int)rows.count) p = rows[r * 8 + c];
					if (!p || [p isEqual:[NSNull null]]) continue;
					@try {
						if ([p isKindOfClass:[NSNumber class]]) board[r][c] = [p intValue];
						else board[r][c] = [[p valueForKey:@"player"] intValue];
					} @catch (id ex2) {}
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
%new
- (void)instantWinReversi {
	@try {
		if ([self respondsToSelector:@selector(testWin)]) {
			[self testWin];
		}
	} @catch (id ex) {}
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
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				@try { [self meShoot]; } @catch (id ex) {}
			});
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				@try { [self meShoot]; } @catch (id ex) {}
			});
		}
	} @catch (id ex) {}
}
- (void)hit_me {
	if (paintGodMode) return;
	%orig;
}
- (void)heShoot {
	if (paintDisarm) return;
	%orig;
}
%new
- (void)instantWinPaint {
	@try {
		if ([self respondsToSelector:@selector(showWin)]) {
			[self showWin];
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
%new
- (void)instantWinShuffle {
	@try {
		if ([self respondsToSelector:@selector(testWin)]) {
			[self testWin];
		}
	} @catch (id ex) {}
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
%new
- (void)instantWinShuffle {
	@try {
		if ([self respondsToSelector:@selector(testWin)]) {
			[self testWin];
		}
	} @catch (id ex) {}
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

%hook PokerScene
- (void)didMoveToView:(id)arg1 {
	%orig;
	if (floatingHUD) {
		[SeagullHUD attachToView:self.view gameType:@"Poker" target:self];
	}
}

- (void)update:(double)arg1 {
	%orig;
	if (pokerCardESP) {
		[self espRevealOpponentCards];
	}
}

%new
- (void)espRevealOpponentCards {
	@try {
		id c1 = [self valueForKey:@"enemy_card1"];
		if (c1) {
			[c1 setValue:@(NO) forKey:@"secret"];
			if ([c1 respondsToSelector:@selector(updateTexture)]) [c1 updateTexture];
		}
		id c2 = [self valueForKey:@"enemy_card2"];
		if (c2) {
			[c2 setValue:@(NO) forKey:@"secret"];
			if ([c2 respondsToSelector:@selector(updateTexture)]) [c2 updateTexture];
		}
	} @catch (id ex) {}
}

%new
- (void)instantWinPot {
	@try {
		if ([self respondsToSelector:@selector(ActionWin)]) {
			[self ActionWin];
		} else if ([self respondsToSelector:@selector(WinAll1)]) {
			[self WinAll1];
		}
	} @catch (id ex) {}
}

%new
- (void)showWinningCombos {
	@try {
		if ([self respondsToSelector:@selector(ShowCombos)]) {
			[self ShowCombos];
		}
	} @catch (id ex) {}
}
%end

%hook QuestionsScene
- (void)didMoveToView:(id)arg1 {
	%orig;
	if (floatingHUD) {
		[SeagullHUD attachToView:self.view gameType:@"20 Questions" target:self];
	}
}

%new
- (void)revealSecretWord {
	@try {
		SKLabelNode *wordLabel = [self valueForKey:@"word"];
		NSString *secret = wordLabel ? [wordLabel text] : nil;
		if (!secret || secret.length == 0) {
			SKLabelNode *yourLabel = [self valueForKey:@"your"];
			secret = yourLabel ? [yourLabel text] : @"Unknown";
		}
		
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🔍 Secret Word" message:[NSString stringWithFormat:@"The Secret Word is: %@", secret] preferredStyle:UIAlertControllerStyleAlert];
		[alert addAction:[UIAlertAction actionWithTitle:@"Got it" style:UIAlertActionStyleDefault handler:nil]];
		UIViewController *root = GSG_keyWindow().rootViewController;
		[root presentViewController:alert animated:YES completion:nil];
	} @catch (id ex) {}
}

%new
- (void)autoGuessWord {
	@try {
		if ([self respondsToSelector:@selector(SendGuessed)]) {
			[self SendGuessed];
		}
	} @catch (id ex) {}
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

// ================= Unlock Pack: skins, packs, reveals, ads =================
// PIOPayVault is the single entitlement vault: hasItem:/countOfItem: gate
// all unlock + consumable checks game-wide. Signatures verified from 2.0.13
// type encodings (hasItem: B+@, countOfItem: Q+@) — no block guessing.
%hook PIOPayVault
- (BOOL)hasItem:(id)arg1 {
	if (unlockAllContent || infiniteReveals) return YES;
	return %orig;
}
- (NSUInteger)countOfItem:(id)arg1 {
	if (unlockAllContent || infiniteReveals) return 999;
	return %orig;
}
%end

// Root-controller consumables (reveals): int getter + spend path.
%hook MessagesViewController
- (int)consumableGet:(id)arg1 {
	if (infiniteReveals) return 999;
	return %orig;
}
- (BOOL)consumableConsume:(id)arg1 ammount:(int)arg2 {
	if (infiniteReveals) return YES;
	return %orig;
}
- (void)showAd {
	if (!noAds) %orig;
}
- (void)showAd:(id)arg1 {
	if (!noAds) %orig;
}
%end

// Per-pack theme flags (pool animals/evil/variety/patterns + avatar packs).
%hook PoolCustomizePack
- (BOOL)unlocked {
	if (unlockAllContent) return YES;
	return %orig;
}
%end

// Ad removal: entitlement flag + every show path no-op'd.
%hook GameScene
- (id)remove_ads {
	if (noAds) return @YES;
	return %orig;
}
- (BOOL)canShowAd {
	if (noAds) return NO;
	return %orig;
}
- (void)showAd {
	if (!noAds) %orig;
}
- (void)showBannerAd {
	if (!noAds) %orig;
}
- (void)requestBannerAd {
	if (!noAds) %orig;
}
%end

%hook GameViewController
- (void)showAd {
	if (!noAds) %orig;
}
- (void)showAd:(id)arg1 {
	if (!noAds) %orig;
}
- (void)showAd:(id)arg1 force:(BOOL)arg2 {
	if (!noAds) %orig;
}
- (void)showInt:(id)arg1 {
	if (!noAds) %orig;
}
- (void)showInterstitial {
	if (!noAds) %orig;
}
- (void)displayAdFullscreen:(id)arg1 {
	if (!noAds) %orig;
}
%end

// Paywall overlay: never shown when everything is unlocked.
%hook PoolCustomizeScene
- (void)showUnlock {
	if (!unlockAllContent) %orig;
}
%end
%hook WordgamesStoreScene
- (void)showUnlock {
	if (!unlockAllContent) %orig;
}
%end
%hook SeaCustomizeScene
- (void)showUnlock {
	if (!unlockAllContent) %orig;
}
%end
%hook SettingsScene
- (void)showUnlock {
	if (!unlockAllContent) %orig;
}
%end
%hook PaintCustomizeScene
- (void)showUnlock {
	if (!unlockAllContent) %orig;
}
%end
%hook BeerCustomizeScene
- (void)showUnlock {
	if (!unlockAllContent) %orig;
}
%end
%hook GPlusScene
- (void)showUnlock {
	if (!unlockAllContent) %orig;
}
%end
%hook DartsCustomizeScene
- (void)showUnlock {
	if (!unlockAllContent) %orig;
}
%end
%hook MancalaCustomizeScene
- (void)showUnlock {
	if (!unlockAllContent) %orig;
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
	pokerCardESP = boolForKey(@"kPokerCardESP");
	questionsESP = boolForKey(@"kQuestionsESP");
	unlockAllContent = boolForKey(@"kUnlockAllContent");
	infiniteReveals = boolForKey(@"kInfiniteReveals");
	noAds = boolForKey(@"kNoAds");
	paintGodMode = boolForKey(@"kPaintGodMode");
	paintDisarm = boolForKey(@"kPaintDisarm");
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

	%init;
}
