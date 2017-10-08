//
//  ViewController.m
//  DrHopper
//
//  Created by 増田 真也 on 2016/02/11.
//  Copyright © 2016年 Luck. All rights reserved.
//

#import "ViewController.h"

#define GAME_VIEW_SIZE_X 320
#define GAME_VIEW_SIZE_Y 320
#define STATUS_BAR_HEIGHT 20

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
  
  [super viewDidLoad];
  
  CGRect rect = self.view.bounds;
  CGFloat offsetX = rect.size.width / 2 - GAME_VIEW_SIZE_X / 2;
  
  CGFloat x = 0 + offsetX;
  CGFloat y = 0 + STATUS_BAR_HEIGHT + rect.origin.y;
  CGFloat width  = rect.size.width - offsetX * 2;
  CGFloat height = rect.size.height - STATUS_BAR_HEIGHT;
  
  CGRect gvrect = CGRectMake(x, y, width, height);
  
  self.gameView = [[GameView alloc] initWithFrame:gvrect];
  self.gameView.backgroundColor = [UIColor whiteColor];
  [self.view addSubview:self.gameView];
  
  // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  
  // Dispose of any resources that can be recreated.
}

@end
