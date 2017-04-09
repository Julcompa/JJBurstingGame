//
//  GameScene.h
//  JJBurstingGame
//
//  Created by Julien Comparato on 06/04/2017.
//  Copyright © 2017 Julien Comparato. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>
#import <GameplayKit/GameplayKit.h>

typedef enum : NSUInteger {
    GameSceneStimulusStatusDefault,
    GameSceneStimulusStatus1,
    GameSceneStimulusStatus2,
    GameSceneStimulusStatus3,
} GameSceneStimulusStatus;

@interface GameScene : SKScene <SKPhysicsContactDelegate>

@property (nonatomic) NSMutableArray<GKEntity *> *entities;
@property (nonatomic) NSMutableDictionary<NSString*, GKGraph *> *graphs;

@property (nonatomic, readonly, getter=myScore) NSInteger score;
@property (nonatomic) NSUInteger maxScore; // default is 15.

@property (nonatomic) NSUInteger maxMovingNodesAllowed; // default is 15.

@property (nonatomic) NSTimeInterval duration; // default is 120 seconds before Game Over
@property (nonatomic) NSTimeInterval inactivityDuration; // default is 60 seconds before Game Over

- (void)updateGravity:(CGFloat)gravity;

- (void)setTextureForBurstingObject:(SKTexture *)texture;
- (void)addTextureForBurstingObject:(NSArray<SKTexture *> *)textures;
- (void)setTextureForStimulusObject:(SKTexture *)texture status:(GameSceneStimulusStatus)status;

@end
