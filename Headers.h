@import SpriteKit;
@import SceneKit;

@interface ArcheryView : NSObject
@end

@interface PoolScene : SKScene
@property (nonatomic) int currentColorHue;
@property (nonatomic, retain) SKShapeNode *fullTrajNode;
- (void)drawFullMultiBallTrajectory;
- (void)autoAimBestBall;
- (void)triggerBreakToWinNow;
- (void)instantWinPoolGame;
- (void)showWin;
@end

@interface PoolScene2 : SKScene
@property (nonatomic) int currentColorHue;
@property (nonatomic, retain) SKShapeNode *fullTrajNode;
- (void)drawFullMultiBallTrajectory;
- (void)autoAimBestBall;
- (void)triggerBreakToWinNow;
- (void)instantWinPoolGame;
- (void)showWin;
@end

@interface PoolScene3 : SKScene
@property (nonatomic) int currentColorHue;
@property (nonatomic, retain) SKShapeNode *fullTrajNode;
- (void)drawFullMultiBallTrajectory;
- (void)autoAimBestBall;
- (void)triggerBreakToWinNow;
- (void)instantWinPoolGame;
- (void)showWin;
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

@interface SeaShip : NSObject
@property (nonatomic) SKSpriteNode *sprite; 
@property (nonatomic, retain) NSArray *cells;
@property (nonatomic) CGPoint pos;
- (void)Die;
@end

@interface SeaScene : SKScene
- (void)BombTo:(CGPoint)pt;
- (void)checkWin;
- (void)autoSinkEnemyFleet;
- (void)strikeNextEnemyShip;
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
- (void)solveAndSubmitAllWords;
@end

@interface PoolBall : NSObject
@property (nonatomic) int num;
- (bool)isStripes;
- (bool)isSolid;
- (bool)isNine;
- (bool)isBlack;
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

@interface BasketballScene : SKScene
@property (nonatomic, retain) UIButton *autoBasketButton;
- (void)touchDownAtPoint:(CGPoint)pt;
- (void)touchMovedToPoint:(CGPoint)pt;
- (void)touchUpAtPoint:(CGPoint)pt;
- (void)gp_autoSwishShoot;
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
- (void)instantSinkInCup;
- (void)testWin;
@end

@interface GolfScene2 : SKScene
@property (nonatomic, retain) UIButton *golfAutoButton;
@property (nonatomic, retain) SKShapeNode *golfTrajectoryNode;
- (void)touchDownAtPoint:(CGPoint)pt;
- (void)touchMovedToPoint:(CGPoint)pt;
- (void)touchUpAtPoint:(CGPoint)pt;
- (void)autoShootHoleInOne;
- (void)instantSinkInCup;
- (void)testWin;
@end

@interface CheckersScene : SKScene
- (void)showMove:(id)move add:(BOOL)add;
- (void)checkAttack;
- (void)updateCheckersOverlay;
- (void)autoPlayBestCheckersMove;
@end

@interface ChessScene : SKScene
- (void)showMove:(id)move add:(BOOL)add pl:(int)pl;
- (void)updateChessOverlay;
@end

@interface ReversiScene : SKScene
- (void)showMoves:(int)player add:(BOOL)add;
- (void)updateReversiOverlay;
- (void)autoPlayBestReversiMove;
@end

@interface FillScene : SKScene
- (void)finalWin;
- (void)fill:(id)arg1 num:(int)color;
- (void)autoPickBestColor;
- (void)instantWin;
@end

@interface PaintScene : SKScene
- (void)showEnemy;
- (void)meShoot;
- (void)autoAimEnemy;
@end

@interface ShuffleScene : SKScene
- (void)touchDownAtPoint:(CGPoint)pt;
- (void)touchMovedToPoint:(CGPoint)pt;
- (void)touchUpAtPoint:(CGPoint)pt;
- (void)launchPerfectPuck;
@end

@interface ShuffleScene2 : SKScene
- (void)touchDownAtPoint:(CGPoint)pt;
- (void)touchMovedToPoint:(CGPoint)pt;
- (void)touchUpAtPoint:(CGPoint)pt;
- (void)launchPerfectPuck;
@end

@interface CrazyScene : SKScene
- (void)winner;
- (void)instantWin;
@end

@interface KnockScene : SKScene
- (void)touchDownAtPoint:(CGPoint)pt;
- (void)touchMovedToPoint:(CGPoint)pt;
- (void)touchUpAtPoint:(CGPoint)pt;
- (void)superPuckShoot;
@end

@interface GameIcon : NSObject
@property (nonatomic, retain) NSString *_id;
@end

@interface PokerCard : SKNode
@property (nonatomic) int suit;
@property (nonatomic) int rank;
@property (nonatomic) BOOL secret;
- (void)updateTexture;
@end

@interface PokerScene : SKScene
@property (nonatomic, retain) PokerCard *enemy_card1;
@property (nonatomic, retain) PokerCard *enemy_card2;
- (void)ActionWin;
- (void)WinAll1;
- (void)ShowCombos;
- (void)espRevealOpponentCards;
- (void)instantWinPot;
- (void)showWinningCombos;
@end

@interface QuestionsScene : SKScene
- (void)SendGuessed;
- (void)revealSecretWord;
- (void)autoGuessWord;
@end

