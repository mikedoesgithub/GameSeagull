@import Foundation;
@import UIKit;
@import SceneKit;
@import SpriteKit;
@import libhooker;

#import <rootless.h>
#import "Headers.h"

// Memory & Hooking
uint64_t bh_memmem(const uint8_t* haystack, size_t hlen, const uint8_t* needle, size_t nlen);
void HookMemory(Class class, SEL selector, uint64_t offset, uint32_t data);
int PatchMemory(const struct LHMemoryPatch *patches, int count);

// UI Helpers & Alerts
UIWindow *GSG_keyWindow(void);
void alert(UIView *object, NSString *title, NSString *message);
void showWordList(UIView *parentView, NSString *title, NSArray<NSString *> *words);
UIButton *makeButton(NSString *title, CGRect frame, id target, SEL selector);

// Preferences (Live Sync)
NSDictionary* getPreferences(void);
void reloadPreferences(void);
bool boolForKey(NSString *key);
int intForKey(NSString *key, int defaultVal);
void setBoolForKey(NSString *key, bool value);
void setIntForKey(NSString *key, int value);

// Aim & Physics Solvers
SCNVector3 getAimbotPos(int multiplier, int number);
CGFloat calculateBestPoolShotAngle(CGPoint cuePos, NSArray *balls, NSArray *pockets, CGFloat ballRadius);

// Board Game Solvers
typedef struct {
    int columnScores[7]; // -10000 = blunder, 0 = neutral, +10000 = win
    int bestColumn;
} Connect4Evaluation;
Connect4Evaluation evaluateConnect4Grid(const int grid[6][7], int player);

typedef struct {
    BOOL isFreeTurn;
    BOOL isCapture;
    int seedsCaptured;
    int advantage;
} MancalaPitEvaluation;
MancalaPitEvaluation evaluateMancalaPit(const int board[14], int pitIndex, int player);
int getBestMancalaPit(const int board[14], int player);

typedef enum {
    DOTS_MOVE_DANGER = -1, // Creates a 3-sided box (sacrifice/giveaway)
    DOTS_MOVE_SAFE = 0,    // Leaves <= 2 sides in adjacent boxes
    DOTS_MOVE_CAPTURE = 1, // Closes 1 box
    DOTS_MOVE_DOUBLE = 2   // Closes 2 boxes
} DotsLineQuality;
DotsLineQuality evaluateDotsLineQuality(int countBoxA, int countBoxB);

typedef struct {
    int bestRow;
    int bestCol;
    int threatLevel; // 1000 = win now, 800 = urgent block, 500 = open 4, 300 = open 3
} GomokuMove;
GomokuMove evaluateGomokuGrid(const int grid[15][15], int player);

typedef struct {
    int scores[8][8];
    int bestRow;
    int bestCol;
    int maxFlips;
} ReversiEvaluation;
ReversiEvaluation evaluateReversiBoard(const int board[8][8], int player);

typedef struct {
    int fromRow, fromCol;
    int toRow, toCol;
    int score;
    BOOL isJump;
} CheckersEvaluation;
CheckersEvaluation evaluateCheckersMoves(const int board[8][8], int player);

int getBestFillerColor(const int grid[12][8], int player1Color, int player2Color, int player);
CGPoint calculateShuffleImpulse(CGSize sceneSize);
CGPoint applyPoolPocketMagnet(CGPoint ballPos, CGPoint ballVel, NSArray *pockets, CGFloat magnetRadius);


// In-Game Floating HUD Menu
@interface SeagullHUD : UIView
@property (nonatomic, copy) NSString *currentGameType;
@property (nonatomic, weak) id currentTarget;
+ (instancetype)sharedHUD;
+ (void)attachToView:(UIView *)parentView gameType:(NSString *)gameType target:(id)target;
- (void)toggleMenu;
- (void)updateContentForGame:(NSString *)gameType;
- (void)openSettingsMenu;
@end

// In-Game Settings & Win Spoofer Presenter
void presentGameSeagullSettings(UIView *parentView);