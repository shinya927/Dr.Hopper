//
//  GameView.m
//  DrHopper
//
//  Created by 増田 真也 on 2016/02/11.
//  Copyright © 2016年 Luck. All rights reserved.
//

#import "GameView.h"
#include <AudioToolbox/AudioToolbox.h>

// ゲームモード //
#define GAME_MODE_NORMAL 0
#define GAME_MODE_ERASE  1

// ゲームシーン //
#define GAME_SCENE_TITLE  0
#define GAME_SCENE_MAIN   1
#define GAME_SCENE_RESULT 2

// ゲーム画面のサイズ //
#define GAME_VIEW_WIDTH  320
#define GAME_VIEW_HEIGHT 320

// 広告サイズ //
#define AD_WIDTH  320
#define AD_HEIGHT 50

// 描画オフセット量（文字列） //
#define TITLE_DRAW_OFFSET_X 160
#define TITLE_DRAW_OFFSET_Y 120
#define HI_SCORE_DRAW_OFFSET_X 160
#define HI_SCORE_DRAW_OFFSET_Y 170
#define SCORE_DRAW_OFFSET_X 10
#define SCORE_DRAW_OFFSET_Y 25
#define GET_READY_DRAW_OFFSET_X 160
#define GET_READY_DRAW_OFFSET_Y 100
#define GAME_OVER_DRAW_OFFSET_X 160
#define GAME_OVER_DRAW_OFFSET_Y 130
#define GAME_OVER_SCORE_DRAW_OFFSET_X 160
#define GAME_OVER_SCORE_DRAW_OFFSET_Y 180

// タイマー //
#define TIME_INTERVAL (1.0f/60.0f)

// トゲ画像サイズ //
#define TOGE_IMG_SIZE_WIDTH  16
#define TOGE_IMG_SIZE_HEIGHT 16

// トゲ画像の描画数 //
#define NUM_OF_TOGE 20

// プレイヤーサイズ //
#define PLAYER_SIZE_WIDTH  16
#define PLAYER_SIZE_HEIGHT 16

// ブロックサイズ //
#define BLOCK_START_SIZE_WIDTH  16
#define BLOCK_START_SIZE_HEIGHT 16

// 重力 //
#define GRAVITY 0.175

// ジャンプ力 //
#define JUMP_POWER (-4.8)

// X方向の加速度関係 //
#define INCREMENT_DELTA_X 0.175
#define MAX_DELTA_X 4.8

// レベル関係 //
#define LEVEL_UP_COUNT 25
#define LEVEL_MAX 10

// ERASEモード解禁スコア //
#define ERASE_MODE_RELEASE_SCORE 250

// ゲーム情報 //
struct Game
{
  int mode;
  int scene;
  int score;
  int hiscore_normal;
  int hiscore_erase;
  int level;
};

// プレイヤー情報 //
struct Player
{
  int x;
  int y;
  int width;
  int height;
  CGFloat deltaX;
  CGFloat deltaY;
};

// ブロック情報 //
struct Block
{
  int x;
  int y;
  int width;
  int height;
};

struct Player player;
struct Block  crntBlock; // 現在表示されているブロック
struct Block  nextBlock; // 次に表示予定のブロック
struct Game   game;

// 広告 //
NADView* nadView;

// 画像関係 //
UIImage* playerImage = nil;
UIImage* togeImage   = nil;

// 音源関係 //
SystemSoundID	soundOK;

// ボタン関係 //
UIButton* playButton  = nil;
UIButton* retryButton = nil;
UIButton* titleButton = nil;

// タイマー //
NSTimer* timer = nil;

// 長押し認識 //
UILongPressGestureRecognizer* longPressGesture = nil;

// 描画オフセット //
int drawOffsetX = 0;

// GetReady表示用フラグ //
bool isGetReady = false;

// 操作系変数 //
int touchCountL = 0;       // 左側をタッチしている数
int touchCountR = 0;       // 右側をタッチしている数
char crntTouchArea = '\0'; // 'L'：左側をタッチ 'R'：右側をタッチ

// ERASEモード解除フラグ //
BOOL isEraseModeRelease = NO;

@implementation GameView

//-----------------------------------------------------------
// 初期化処理
-(id)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  
  if (self) {
    
    // 広告生成 //
    nadView = [[NADView alloc] initWithFrame:CGRectMake(0, 0, AD_WIDTH, AD_HEIGHT)];
    [nadView setIsOutputLog:NO];
    [nadView setNendID:@"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" spotID:@"xxxxxx"];
    //[nadView setNendID:@"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" spotID:@"xxxxxx"];
    [nadView setDelegate:self];
    [nadView load];
    nadView.backgroundColor = [UIColor blackColor];

    // マルチタッチ有効 //
    [self setMultipleTouchEnabled:YES];
    
    // 長押し認識 //
    longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
    [self addGestureRecognizer:longPressGesture];
    
    // 画像読み込み //
    playerImage = [UIImage imageNamed:@"player.png"];
    togeImage   = [UIImage imageNamed:@"toge.png"];
    
    // 音源読み込み //
    CFBundleRef mainBundle;
    mainBundle = CFBundleGetMainBundle();
    CFURLRef soundURL = CFBundleCopyResourceURL(mainBundle, CFSTR("ok"), CFSTR("wav"), NULL);
    AudioServicesCreateSystemSoundID (soundURL, &soundOK);
    CFRelease (soundURL);

    // Playボタン初期化 //
    playButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    UIFont* font = [UIFont systemFontOfSize:30];
    NSString* str = [NSString stringWithFormat:@"Play"];
    CGSize size = [str sizeWithAttributes:@{NSFontAttributeName:font}];
    CGFloat playbtnx = GAME_VIEW_WIDTH / 2 - size.width/2;
    CGFloat playbtny = GAME_VIEW_HEIGHT + 50;
    playButton.frame = CGRectMake(playbtnx, playbtny, size.width, size.height);
    playButton.layer.cornerRadius = 6.0;
    playButton.layer.borderColor = [[UIColor blackColor] CGColor];
    playButton.layer.borderWidth = 2.0;
    [playButton setTitle:@"Play" forState:UIControlStateNormal];
    [playButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [playButton addTarget:self action:@selector(onPlayButton:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:playButton];
    
    // Retryボタン初期化 //
    retryButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    str = [NSString stringWithFormat:@"Retry"];
    size = [str sizeWithAttributes:@{NSFontAttributeName:font}];
    CGFloat replaybtnx = GAME_VIEW_WIDTH / 3 - size.width/2;
    CGFloat replaybtny = GAME_VIEW_HEIGHT + 50;
    retryButton.frame = CGRectMake(replaybtnx, replaybtny, size.width, size.height);
    retryButton.layer.cornerRadius = 6.0;
    retryButton.layer.borderColor = [[UIColor blackColor] CGColor];
    retryButton.layer.borderWidth = 2.0;
    [retryButton setTitle:@"Retry" forState:UIControlStateNormal];
    [retryButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [retryButton addTarget:self action:@selector(onRetryButton:) forControlEvents:UIControlEventTouchUpInside];
    
    // Titleボタン初期化（Retryボタンと大きさを合わせる） //
    titleButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    str = [NSString stringWithFormat:@"Title"];
    CGFloat titlebtnx = GAME_VIEW_WIDTH - GAME_VIEW_WIDTH / 3 - size.width/2;
    CGFloat titlebtny = GAME_VIEW_HEIGHT + 50;
    titleButton.frame = CGRectMake(titlebtnx, titlebtny, retryButton.frame.size.width, retryButton.frame.size.height);
    titleButton.layer.cornerRadius = 6.0;
    titleButton.layer.borderColor = [[UIColor blackColor] CGColor];
    titleButton.layer.borderWidth = 2.0;
    [titleButton setTitle:@"Title" forState:UIControlStateNormal];
    [titleButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [titleButton addTarget:self action:@selector(onTitleButton:) forControlEvents:UIControlEventTouchUpInside];

    // 保存データ読み込み //
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    if ([userDefaults objectForKey:@"hiscore_normal"] == nil) {
      
      // 初回起動時の場合 //
      [userDefaults setInteger:0 forKey:@"hiscore_normal"];
      [userDefaults setInteger:0 forKey:@"hiscore_erase"];
      [userDefaults setBool:NO  forKey:@"isEraseModeRelease"];
      [userDefaults synchronize];
    }
    game.hiscore_normal = (int)[userDefaults integerForKey:@"hiscore_normal"];
    game.hiscore_erase  = (int)[userDefaults integerForKey:@"hiscore_erase"];
    isEraseModeRelease  = [userDefaults boolForKey:@"isEraseModeRelease"];

    // タイトルへ //
    game.mode = GAME_MODE_NORMAL;
    game.scene = GAME_SCENE_TITLE;
  }
  return self;
}

//-----------------------------------------------------------
// ゲーム初期化
-(void)initGame
{
  
  // ゲーム情報初期化 //
  game.score = 0;
  game.level = 0;
  
  // プレイヤー情報初期化 //
  player.x = GAME_VIEW_WIDTH / 2 - PLAYER_SIZE_WIDTH / 2;
  player.y = GAME_VIEW_HEIGHT / 2 - PLAYER_SIZE_HEIGHT * 2;
  player.width = PLAYER_SIZE_WIDTH;
  player.height = PLAYER_SIZE_HEIGHT;
  player.deltaX = 0.0;
  player.deltaY = 0.0;
  
  // ブロック情報初期化 //
  crntBlock.x = 0;
  crntBlock.y = 0;
  crntBlock.width = 0;
  crntBlock.height = 0;
  
  nextBlock.x = GAME_VIEW_WIDTH / 2 - PLAYER_SIZE_WIDTH / 2;
  nextBlock.y = GAME_VIEW_HEIGHT / 2;
  nextBlock.width = BLOCK_START_SIZE_WIDTH;
  nextBlock.height = BLOCK_START_SIZE_HEIGHT;
  
  // 各変数の初期化 //
  drawOffsetX = 0;
  isGetReady = true;
  touchCountL = 0;
  touchCountR = 0;
  crntTouchArea = '\0';
}

//-----------------------------------------------------------
// 描画処理
- (void)drawRect:(CGRect)rect
{
  // コンテキストの指定 //
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextRetain(context);
  
  switch (game.scene) {
      
    case GAME_SCENE_TITLE:
      [self drawTitle:context];
      break;
      
    case GAME_SCENE_MAIN:
      [self drawMain:context];
      break;
      
    case GAME_SCENE_RESULT:
      [self drawResult:context];
      break;
      
    default:
      break;
  }
}

//-----------------------------------------------------------
// 描画処理（タイトル）
- (void)drawTitle:(CGContextRef)context
{
  // "Dr.Hopper"の描画 //
  UIColor* color = nil;
  if (game.mode == GAME_MODE_NORMAL) {
    
    color = [UIColor blackColor];
  }
  else if (game.mode == GAME_MODE_ERASE) {
    
    color = [UIColor blueColor];
  }
  
  UIFont* font = [UIFont systemFontOfSize:20];
  NSString* text = [NSString stringWithFormat:@"Dr.Hopper"];
  CGSize size = [text sizeWithAttributes:@{NSFontAttributeName:font}];
  NSAttributedString *str = [[NSAttributedString alloc] initWithString:text
                             attributes:@{NSForegroundColorAttributeName:color,NSFontAttributeName:font}];
  [str drawInRect:CGRectMake(TITLE_DRAW_OFFSET_X - size.width / 2,
                             TITLE_DRAW_OFFSET_Y - size.height / 2,
                             size.width, size.height)];

  // ハイスコアの描画 //
  font = [UIFont systemFontOfSize:14];
  if (game.mode == GAME_MODE_NORMAL) {
    
    text = [NSString stringWithFormat:@"HI SCORE  %06d", game.hiscore_normal];
  }
  else if (game.mode == GAME_MODE_ERASE) {
    
    text = [NSString stringWithFormat:@"HI SCORE  %06d", game.hiscore_erase];
  }
  size = [text sizeWithAttributes:@{NSFontAttributeName:font}];
  str = [[NSAttributedString alloc] initWithString:text
                                    attributes:@{NSForegroundColorAttributeName:color,NSFontAttributeName:font}];
  [str drawInRect:CGRectMake(HI_SCORE_DRAW_OFFSET_X - size.width / 2,
                             HI_SCORE_DRAW_OFFSET_Y - size.height / 2,
                             size.width, size.height)];
  
  // トゲの描画 //
  for (int ii = 0; ii < NUM_OF_TOGE; ii++) {
    
    [togeImage drawAtPoint:CGPointMake(TOGE_IMG_SIZE_WIDTH * ii, GAME_VIEW_HEIGHT - TOGE_IMG_SIZE_HEIGHT)];
  }
}

//-----------------------------------------------------------
// 描画処理（メイン）
- (void)drawMain:(CGContextRef)context
{
  // スコアの描画 //
  UIFont* font = [UIFont systemFontOfSize:14];
  NSString* str = [NSString stringWithFormat:@"SCORE  %06d", game.score];
  CGSize size = [str sizeWithAttributes:@{NSFontAttributeName:font}];
  CGPoint point = CGPointMake(SCORE_DRAW_OFFSET_X, SCORE_DRAW_OFFSET_Y - size.height);
  [str drawAtPoint:point withAttributes:@{NSFontAttributeName:font}];
  
  if (isGetReady == true) {
    
    // GetReadyの描画 //
    font = [UIFont systemFontOfSize:16];
    str = [NSString stringWithFormat:@"Get Ready"];
    size = [str sizeWithAttributes:@{NSFontAttributeName:font}];
    point = CGPointMake(GET_READY_DRAW_OFFSET_X - size.width/2, GET_READY_DRAW_OFFSET_Y - size.height);
    [str drawAtPoint:point withAttributes:@{NSFontAttributeName:font}];
  }
  
  // トゲの描画 //
  for (int ii = 0; ii < NUM_OF_TOGE; ii++) {
    
    [togeImage drawAtPoint:CGPointMake(TOGE_IMG_SIZE_WIDTH * ii, GAME_VIEW_HEIGHT - TOGE_IMG_SIZE_HEIGHT)];
  }

  // ブロックの描画 //
  if (game.mode == GAME_MODE_NORMAL) {
    
    CGContextSetRGBFillColor(context, 0, 0, 0, 1);
    CGContextFillRect(context, CGRectMake(crntBlock.x, crntBlock.y, crntBlock.width, crntBlock.height));
    CGContextFillRect(context, CGRectMake(nextBlock.x, nextBlock.y, nextBlock.width, nextBlock.height));
  }
  else if (game.mode == GAME_MODE_ERASE) {
    
    CGContextSetRGBFillColor(context, 0, 0, 0, 0.5);
    CGContextFillRect(context, CGRectMake(crntBlock.x, crntBlock.y, crntBlock.width, crntBlock.height));
    CGContextFillRect(context, CGRectMake(nextBlock.x, nextBlock.y, nextBlock.width, nextBlock.height));
  }
  
  // プレイヤーの描画 //
  [playerImage drawAtPoint:CGPointMake(player.x, player.y)];
}

//-----------------------------------------------------------
// 描画処理（リザルト）
- (void)drawResult:(CGContextRef)context
{
  // Game Overの描画 //
  UIFont* font = [UIFont systemFontOfSize:16];
  NSString* str = [NSString stringWithFormat:@"Game Over"];
  CGSize size = [str sizeWithAttributes:@{NSFontAttributeName:font}];
  CGPoint point = CGPointMake(GAME_OVER_DRAW_OFFSET_X - size.width/2, GAME_OVER_DRAW_OFFSET_Y - size.height);
  [str drawAtPoint:point withAttributes:@{NSFontAttributeName:font}];
  
  // スコアの描画 //
  font = [UIFont systemFontOfSize:14];
  str = [NSString stringWithFormat:@"SCORE  %06d", game.score];
  size = [str sizeWithAttributes:@{NSFontAttributeName:font}];
  point = CGPointMake(GAME_OVER_SCORE_DRAW_OFFSET_X - size.width/2, GAME_OVER_SCORE_DRAW_OFFSET_Y - size.height);
  [str drawAtPoint:point withAttributes:@{NSFontAttributeName:font}];
  
  // トゲの描画 //
  for (int ii = 0; ii < NUM_OF_TOGE; ii++) {
    
    [togeImage drawAtPoint:CGPointMake(TOGE_IMG_SIZE_WIDTH * ii, GAME_VIEW_HEIGHT - TOGE_IMG_SIZE_HEIGHT)];
  }
}

//-----------------------------------------------------------
// Playボタン押下
-(void)onPlayButton:(UIButton*)button
{
  game.scene = GAME_SCENE_MAIN;
  
  [self initGame];
  
  [self removeGestureRecognizer:longPressGesture];

  [playButton removeFromSuperview];
  
  [self setNeedsDisplay];
}

//-----------------------------------------------------------
// Replayボタン押下
-(void)onRetryButton:(UIButton*)button
{
  game.scene = GAME_SCENE_MAIN;
  
  [self initGame];
  
  [nadView removeFromSuperview];
  
  [retryButton removeFromSuperview];
  [titleButton removeFromSuperview];
  
  [self setNeedsDisplay];
}

//-----------------------------------------------------------
// Titleボタン押下
-(void)onTitleButton:(UIButton*)button
{
  game.scene = GAME_SCENE_TITLE;
  
  [self addGestureRecognizer:longPressGesture];
  
  [nadView removeFromSuperview];
  
  [retryButton removeFromSuperview];
  [titleButton removeFromSuperview];
  
  [self addSubview:playButton];
  
  [self setNeedsDisplay];
}

//-----------------------------------------------------------
// タイマーイベント
-(void)onTick:(NSTimer*)timer
{
  switch (game.scene) {
      
    case GAME_SCENE_TITLE:
      break;
      
    case GAME_SCENE_MAIN:
      [self onTickMain];
      break;
      
    case GAME_SCENE_RESULT:
      
      break;
      
    default:
      break;
  }
  
  [self setNeedsDisplay];
}

//-----------------------------------------------------------
// タイマー処理（メイン）
-(void)onTickMain
{
  // Y方向の加速度更新 //
  player.deltaY += GRAVITY;
  
  // Y方向衝突判定 //
  bool colY = false;
  colY = [self collisionY:crntBlock blockType:'C'];
  colY = [self collisionY:nextBlock blockType:'N'];

  if (colY == false) {
    
    player.y += player.deltaY;
  }
  
  // X方向の加速度更新 //
  if (crntTouchArea == 'L') {
    
    player.deltaX -= INCREMENT_DELTA_X;
  
    if (player.deltaX < -MAX_DELTA_X) {
      
      player.deltaX = -MAX_DELTA_X;
    }
  }
  else if(crntTouchArea == 'R') {
    
    player.deltaX += INCREMENT_DELTA_X;

    if (player.deltaX > MAX_DELTA_X) {
      
      player.deltaX = MAX_DELTA_X;
    }
  }
  
  // X方向衝突判定 //
  bool colX = false;
  colX = [self collisionX:crntBlock];
  colX = [self collisionX:nextBlock];
  
  if (colX == false) {
    
    player.x += player.deltaX;
  }
  
  // トゲとの衝突判定 //
  if (player.y + player.height > GAME_VIEW_HEIGHT - TOGE_IMG_SIZE_HEIGHT) {
    
    [self gameOver];
  }
}

//-----------------------------------------------------------
// Y方向衝突判定
-(bool)collisionY:(struct Block)block blockType:(char)type
{
  int playerL = player.x + 4;
  int playerR = player.x + 12;
  int blockL = block.x;
  int blockR = block.x + block.width;

  for (int x = playerL; x < playerR; x++) {
    
    if(blockL <= x && x <= blockR) {
      
      int oldPlayerBtm = player.y + player.height;
      int newPlayerBtm = player.y + player.height + player.deltaY;
      int blockTop = block.y;
      if (oldPlayerBtm <= blockTop && blockTop <= newPlayerBtm) {
        
        // 衝突あり //
        player.y = block.y - player.height;
        player.deltaY = JUMP_POWER;
        
        if (type == 'N') {
          
          // OKサウンド再生 //
          AudioServicesPlaySystemSound(soundOK);
          
          // 次のブロックの生成 //
          [self createBlock];
        }
        return true;
      }
    }
  }
  
  return false;
}

//-----------------------------------------------------------
// X方向衝突判定
-(bool)collisionX:(struct Block)block
{
  int playerT = player.y + 0;
  int playerB = player.y + 16;
  int blockT = block.y;
  int blockB = block.y + block.height;
  
  for (int y = playerT; y < playerB; y++) {
    
    if(blockT <= y && y <= blockB) {
      
      if (player.deltaX < 0) {
        
        // 左方向の加速度の場合 //
        int newPlayerLft = player.x + player.deltaX;
        int oldPlayerLft = player.x;
        
        int blockRgt = block.x + block.width;
        if (newPlayerLft <= blockRgt && blockRgt <= oldPlayerLft) {
          
          // 衝突あり //
          player.x = block.x + block.width;
          player.deltaX = 0.0;
          return true;
        }
      }
      else if (player.deltaX > 0) {
        
        // 右方向の加速度の場合 //
        int oldPlayerRgt = player.x + player.width;
        int newPlayerRgt = player.x + player.width + player.deltaX;
        
        int blockLft = block.x;
        if (oldPlayerRgt <= blockLft && blockLft <= newPlayerRgt) {
          
          // 衝突あり //
          player.x = block.x - player.width;
          player.deltaX = 0.0;
          return true;
        }
      }
    }
  }
  
  return false;
}

//-----------------------------------------------------------
// ブロックの生成
-(void)createBlock
{
  // 現在のブロック情報を保持 //
  struct Block oldBlock = {0,0,0,0};
  oldBlock = crntBlock;
  
  // 現在のブロックの更新 //
  crntBlock = nextBlock;
  
  // スコアの更新 //
  game.score++;
  
  // レベルの更新 //
  if (game.score % LEVEL_UP_COUNT == 0) {
    
    if (game.level < LEVEL_MAX) {

      game.level++;
    }
  }
  
  nextBlock.width  = BLOCK_START_SIZE_WIDTH  - game.level;
  nextBlock.height = BLOCK_START_SIZE_HEIGHT - game.level;
  
  while (true) {
    
    // 次のブロックの場所を乱数で決定する //
    int minX = 0;
    int maxX = 0;
    if (game.mode == GAME_MODE_NORMAL) {
      
      minX = (crntBlock.x + crntBlock.width / 2) - (20 * game.level) - 70;
      maxX = (crntBlock.x + crntBlock.width / 2) + (20 * game.level) + 70;
    }
    else if (game.mode == GAME_MODE_ERASE) {

      minX = (crntBlock.x + crntBlock.width / 2) - 100;
      maxX = (crntBlock.x + crntBlock.width / 2) + 100;
    }
    int x = (random() % (maxX + 1 - minX)) + minX;
    
    int minY = 100; // Y方向最小値
    int maxY = GAME_VIEW_HEIGHT - TOGE_IMG_SIZE_WIDTH - nextBlock.width; // Y方向最大値
    int y = (random() % (maxY + 1 - minY)) + minY;
    
    // 飛べる位置かチェック //
    
    // 左端はNG //
    if (x < 35) {
      
      continue;
    }
    
    // 右端はNG //
    if ((x + nextBlock.width) > (320 - 35)) {
      
      continue;
    }
    
    // 現在のブロックの上下方向のチェック //
    int marginX = 8;
    int crntBlockL = crntBlock.x - marginX;
    int crntBlockR = crntBlock.x + crntBlock.width + marginX;
    int nextBlockL = x;
    int nextBlockR = x + nextBlock.width;
    if ((crntBlockL <= nextBlockL && nextBlockL <= crntBlockR) ||
        (crntBlockL <= nextBlockR && nextBlockR <= crntBlockR))
    {
      
      int crntBlockB = crntBlock.y + crntBlock.height;
      if (y <= crntBlockB) {
 
        // 現在のブロックの上方向はNG //
        continue;
      }
      else if (crntBlockB <= y && y <= crntBlockB + 100) {
        
        // 現在のブロックの下方向100pxはNG //
        continue;
      }
      
    }
    
    // 飛べる距離かチェック //
    int distanceX = abs(x - crntBlock.x);
    if (0 <= distanceX && distanceX <= 110) {
      
      // 現在のブロックと次のブロックのX方向の距離が0〜110の場合 //
      int diffY = y - crntBlock.y;
      if (game.mode == GAME_MODE_NORMAL) {

        if (diffY < -80) {
          
          // 上方向に80より大きい場合はNG //
          continue;
        }
      }
      else if (game.mode == GAME_MODE_ERASE) {

        if (diffY < -50) {
          
          // 上方向に50より大きい場合はNG //
          continue;
        }
      }
    }
    else {
      
      // それ以外の場合（X方向の距離が111〜250）//
      int diffY = y - crntBlock.y;
      int diffX = distanceX - 110;
      if (game.mode == GAME_MODE_NORMAL) {
        
        if (diffY < -80 + diffX) {
          
          continue;
        }
      }
      else if (game.mode == GAME_MODE_ERASE) {

        if (diffY < -50 + diffX) {
          
          continue;
        }
      }
    }
    
    
    // 前のブロックにかぶる場所はNG //
    int lftTopX = x;
    int lftTopY = y;
    int lftBtmX = x;
    int lftBtmY = y + nextBlock.height;
    int rgtTopX = x + nextBlock.width;
    int rgtTopY = y;
    int rgtBtmX = x + nextBlock.width;
    int rgtBtmY = y + nextBlock.height;
    
    if ((oldBlock.x <= lftTopX && lftTopX <= oldBlock.x + oldBlock.width) &&
        (oldBlock.y <= lftTopY && lftTopY <= oldBlock.y + oldBlock.height))
    {
      continue;
    }
    if ((oldBlock.x <= lftBtmX && lftBtmX <= oldBlock.x + oldBlock.width) &&
        (oldBlock.y <= lftBtmY && lftBtmY <= oldBlock.y + oldBlock.height))
    {
      continue;
    }
    if ((oldBlock.x <= rgtTopX && rgtTopX <= oldBlock.x + oldBlock.width) &&
        (oldBlock.y <= rgtTopY && rgtTopY <= oldBlock.y + oldBlock.height))
    {
      continue;
    }
    if ((oldBlock.x <= rgtBtmX && rgtBtmX <= oldBlock.x + oldBlock.width) &&
        (oldBlock.y <= rgtBtmY && rgtBtmY <= oldBlock.y + oldBlock.height))
    {
      continue;
    }
    
    nextBlock.x = x;
    nextBlock.y = y;

    break;
  }
  
  // ERASEモードの場合は現在のブロックを消す //
  if (game.mode == GAME_MODE_ERASE) {
    
    crntBlock.x = 0;
    crntBlock.y = 0;
    crntBlock.width = 0;
    crntBlock.height = 0;
  }
  
}

//-----------------------------------------------------------
// ゲームオーバー処理
-(void)gameOver
{
  // タイマーの停止 //
  [timer invalidate];
  timer = nil;
  
  // ハイスコアの更新 //
  if (game.mode == GAME_MODE_NORMAL) {
    
    if (game.score > game.hiscore_normal) {
      
      game.hiscore_normal = game.score;
    }
    
    // ERASEモードの解除チェック //
    if (isEraseModeRelease == NO) {
      
      if (game.hiscore_normal >= ERASE_MODE_RELEASE_SCORE) {
        
        // アラートを表示 //
        UIAlertView *alert =
        [[UIAlertView alloc]
         initWithTitle:@"裏モード解除!!"
         message:@"タイトル画面でタップ長押しで裏モードを選択できます。"
         delegate:nil
         cancelButtonTitle:nil
         otherButtonTitles:@"OK", nil
         ];
        
        [alert show];
        
        // EASEモード解除フラグを更新 //
        isEraseModeRelease = YES;
        
        // EASEモード解除フラグを保存 //
        NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
        [userDefaults setBool:isEraseModeRelease  forKey:@"isEraseModeRelease"];
        [userDefaults synchronize];
      }
    }
  }
  else if (game.mode == GAME_MODE_ERASE) {
    
    if (game.score > game.hiscore_erase) {
      
      game.hiscore_erase = game.score;
    }
  }
  
  // ハイスコアの保存 //
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  [userDefaults setInteger:game.hiscore_normal forKey:@"hiscore_normal"];
  [userDefaults setInteger:game.hiscore_erase forKey:@"hiscore_erase"];
  [userDefaults synchronize];
  
  // 広告ビューの追加 //
  [self addSubview:nadView];
  
  // リトライボタンとタイトルボタンの追加 //
  [self addSubview:retryButton];
  [self addSubview:titleButton];
  
  // リザルト画面へ //
  game.scene = GAME_SCENE_RESULT;
}

//-----------------------------------------------------------
// タッチ開始イベント
-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  switch (game.scene) {
      
    case GAME_SCENE_TITLE:
      break;
      
    case GAME_SCENE_MAIN: {
      
      if (isGetReady == true) {
        
        break;
      }
      
      NSArray* objects = [touches allObjects];
      CGPoint pos = [[objects objectAtIndex:0] locationInView:self];
      
      if (0 <= pos.x && pos.x < GAME_VIEW_WIDTH / 2) {
        
        // 左側のビューがタッチされた場合 //
        if (touchCountL == 0) {
          
          touchCountL++;
          crntTouchArea = 'L';
        }
      }
      else {
        
        // 右側のビューがタッチされた場合 //
        if (touchCountR == 0) {
          
          touchCountR++;
          crntTouchArea = 'R';
        }
      }
      
      break;
    }
      
    case GAME_SCENE_RESULT:
      break;
      
    default:
      break;
  }
  
}

//-----------------------------------------------------------
// タッチ終了イベント
-(void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    switch (game.scene) {
        
      case GAME_SCENE_TITLE:
        break;
      
      case GAME_SCENE_MAIN: {
        
        if (isGetReady == true) {
          
          isGetReady = false;

          timer = [NSTimer
                   scheduledTimerWithTimeInterval:TIME_INTERVAL
                   target:self
                   selector:@selector(onTick:)
                   userInfo:nil repeats:YES];
          break;
        }
        
        NSArray *objects = [touches allObjects];
        CGPoint pos = [[objects objectAtIndex:0] locationInView:self];
        
        if (0 <= pos.x && pos.x < GAME_VIEW_WIDTH / 2) {
          
          // 左側のビューがタッチアップされた場合
          touchCountL--;
        }
        else {
          
          // 右側のビューがタッチアップされた場合
          touchCountR--;
        }
        
        // プレイヤーの加速度をクリア //
        player.deltaX = 0.0;
        
        if (touchCountL == touchCountR) {
          
          // タッチ数が同じ場合 //
          crntTouchArea = '\0';
        }
        else if (touchCountL < touchCountR) {
          
          // 右側のタッチ数が多い場合 //
          crntTouchArea = 'R';
        }
        else {
          
          // 左側のタッチ数が多い場合 //
          crntTouchArea = 'L';
        }
        
        break;
      }
        
      case GAME_SCENE_RESULT:
        break;
      
      default:
        break;
    }
}

//-----------------------------------------------------------
// 長押しイベント
- (void)longPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
  switch (gestureRecognizer.state) {
      
    case UIGestureRecognizerStateBegan:
      
      if (game.mode == GAME_MODE_NORMAL) {
        
        if (isEraseModeRelease == YES) {
  
          game.mode = GAME_MODE_ERASE;
        }
      }
      else {
        
        game.mode = GAME_MODE_NORMAL;
      }
      
      [self setNeedsDisplay];
      break;
      
    case UIGestureRecognizerStateChanged:
      break;
      
    case UIGestureRecognizerStateEnded:
      break;
      
    default:
      break;
  }
}

@end
