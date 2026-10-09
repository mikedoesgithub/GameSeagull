@import SpriteKit;
@import SceneKit;

@interface ArcheryView : NSObject
@end

@interface PoolScene : SKScene
@property (nonatomic) int currentColorHue;
@property (nonatomic, retain) SKShapeNode *fullTrajNode;
- (void)drawFullMultiBallTrajectory;
- (void)autoAimBestBall;
@end

@interface PoolScene2 : SKScene
@property (nonatomic) int currentColorHue;
@property (nonatomic, retain) SKShapeNode *fullTrajNode;
- (void)drawFullMultiBallTrajectory;
- (void)autoAimBestBall;
@end

@interface PoolScene3 : SKScene
@property (nonatomic) int currentColorHue;
@property (nonatomic, retain) SKShapeNode *fullTrajNode;
- (void)drawFullMultiBallTrajectory;
- (void)autoAimBestBall;
@end

@interface BeerView : SCNView
@property (assign) float F_x;
@property (assign) float F_z;
-(void)touchDownAtPoint:(CGPoint)arg1;
-(void)touchMovedToPoint:(CGPoint)arg1;
-(void)touchUpAtPoint:(CGPoint)arg1;
- (void)shootRandomCup;
@end

@interface BeerScene : SKScene
@property (retain) BeerView *scene3d; 
@end

@interface BeerCup : NSObject
@property (assign) SCNVector3 pos;
@property (assign) BOOL live;
@end

@interface BeerBall : NSObject
@property (nonatomic, retain) SCNNode *ball;
@end

@interface DartsScene : SKScene
@property (nonatomic, assign) bool aimbotEnabled;
@property (nonatomic, retain) UIButton *menuButton;
@property (nonatomic, assign) int multiplier;
@property (nonatomic, assign) int number;
@property (nonatomic, retain) UIView *aimbotStatusView;
@property (assign) int score1;
- (void)updateAimbotStatusView;
- (void)createMainMenu;
@end

@interface SettingsScene : SKScene
- (void)openSettings;
@end

@interface SeaScene : NSObject
- (void)autoSinkEnemyFleet;
@end

@interface SeaShip : SKScene
@property (nonatomic) SKSpriteNode *sprite; 
@property (nonatomic, retain) NSArray *cells;
@property (nonatomic) CGPoint pos;
@end

@interface BitesScene : SKScene
@property (nonatomic, retain) NSArray *words;
@property (nonatomic, retain) UIButton *bites_revealButton;
@property (nonatomic, retain) UIButton *bites_autoButton;
- (void)revealAllWordsInSheet;
- (void)winGame;
@end

@interface ConnectScene : SKScene
- (void)updateMinimaxOverlay;
@end

@interface FourScene : SKScene
- (void)updateMinimaxOverlay;
@end

@interface MancalaScene : SKScene
- (void)updateMancalaOverlay;
@end

@interface DotsScene : SKScene
- (void)updateDotsOverlay;
@end

@interface GomokuScene : SKScene
- (void)updateGomokuOverlay;
@end

@interface AnagramsScene : SKScene
@property (nonatomic, retain) NSArray *words;
@property (nonatomic, retain) UIButton *anagrams_revealButton;
@property (nonatomic, retain) UIButton *anagrams_autoButton;
- (void)enterWord;
- (void)thingAt:(NSArray *)words wordsArr:(NSMutableArray *)wordsArr blocks:(NSMutableArray *)blocks fromIndex:(int)index;
- (void)revealWords:(bool)arg1;
- (void)revealAllWordsInSheet;
- (void)winGame;
@end

@interface HuntScene : SKScene {
    SKSpriteNode* score_bg;
}
@property (nonatomic, retain) NSArray *words;
@property (nonatomic, retain) UIButton *hunt_revealWordsButton;
- (void)revealWords:(BOOL)reveal;
- (void)revealAllWordsInSheet;
- (void)winGame;
- (bool)checkWord:(NSString *)word flag:(bool)flag;
@end

@interface PoolBall : NSObject
- (bool)isStripes;
- (bool)isSolid;
@end

@interface GolfBall : NSObject
@property (assign) int strokeCount;
- (bool)inside;
- (bool)hole;
@end

@interface BasketBall : SKNode
@property (nonatomic, assign) CGPoint velocity;
@end

@interface BasketScene : SKScene
@property (nonatomic, retain) UIButton *autoBasketButton;
- (void)throwBallWithVelocity:(CGPoint)vel;
- (void)autoThrowBasket;
@end

@interface TanksScene : SKScene
@property (nonatomic, retain) SKShapeNode *trajectoryLine;
@end

@interface GolfScene : SKScene
@property (nonatomic, retain) UIButton *golfAutoButton;
@property (nonatomic, retain) SKShapeNode *golfTrajectoryNode;
- (void)touchDownAtPoint:(CGPoint)pt;
- (void)touchMovedToPoint:(CGPoint)pt;
- (void)touchUpAtPoint:(CGPoint)pt;
- (void)autoShootHoleInOne;
@end

@interface GameIcon : NSObject
@property (nonatomic, retain) NSString *_id;
@end
