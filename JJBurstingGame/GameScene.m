//
//  GameScene.m
//  JJBurstingGame
//
//  Created by Julien Comparato on 06/04/2017.
//  Copyright © 2017 Julien Comparato. All rights reserved.
//

#import "GameScene.h"

static const uint32_t kMovingNodeCategory = 0x1 << 0;
static const uint32_t kWallCategory = 0x1 << 1;
static NSString * const kMovingNodeName = @"movingNode";
static NSString * const kWallNodeName = @"wallNode";
static NSString * const kStimulusNodeName = @"stimulusNode";
static NSString * const kResetButtonNodeName = @"resetButtonNode";

@implementation GameScene
{
    NSTimeInterval _lastUpdateTime;
    GameSceneStimulusStatus _currentStatus;
    NSInteger _movingNodesAdded;
    NSInteger _internalScore;
    
    BOOL _isEndGameInProcess;
    
    // Moving items
    //NOTE: We just need one node that we can copy for reuse and randomly display it.
    SKSpriteNode *_movingNode;
    SKTexture *_movingNodeTexture;
    // Central item
    //NOTE: This central item changes according to the score (we might need several nodes to reflect it...). We just create it once
    SKSpriteNode *_centerNodeDefault;
    //SKSpriteNode *_centerNode1;
    //SKSpriteNode *_centerNode2;
    //SKSpriteNode *_centerNode3;
    SKTexture *_centerNodeDefaultTexture;
    SKTexture *_centerNode1Texture;
    SKTexture *_centerNode2Texture;
    SKTexture *_centerNode3Texture;
    
    // Out of screen item
    //NOTE: We create a kind of wall out off the screen and then detect a collision to reset the position of the moving item
    SKShapeNode *_wall;
    // FX item
    //NOTE: We need a particles emitter to give a feeback when we tap on a moving item (e.g. explosion)
    SKEmitterNode *_burstFx;
    
    SKLabelNode *_scoreLebelNode;
    SKLabelNode *_resetButton;
    
    // Default texture in case no texture set
    SKTexture *_defaultTexture;
}

- (void)didMoveToView:(SKView *)view {
    [self generateGame];
}

#pragma mark -
#pragma mark Game life Cycle
#pragma mark -

-(void)update:(CFTimeInterval)currentTime {
    // Called before each frame is rendered
    
    // Initialize _lastUpdateTime if it has not already been
    if (_lastUpdateTime == 0) {
        _lastUpdateTime = currentTime;
    }
    
    // Calculate time since last update
    CGFloat dt = currentTime - _lastUpdateTime;
    
    // Update entities
    for (GKEntity *entity in self.entities) {
        [entity updateWithDeltaTime:dt];
    }
    
    if ([self isGameFinished])
    {
        if (!_isEndGameInProcess)
        {
            [self processTheEndOfGame];
        }
    }
    else
    {
        // add a sprite at random position
        if ([self isAddingNewNodeAllowed]) {
            [self addMovingNodeIntoGame];
        }
    }
    
    _lastUpdateTime = currentTime;
}

#pragma mark - Contact/Collision Events

- (void)didBeginContact:(SKPhysicsContact *)contact
{
    if(([contact.bodyA.node.name isEqualToString:kMovingNodeName] && [contact.bodyB.node.name isEqualToString:kWallNodeName] ) ||
       ([contact.bodyA.node.name isEqualToString:kWallNodeName] && [contact.bodyB.node.name isEqualToString:kMovingNodeName]) )
    {
        if([contact.bodyA.node.name isEqualToString:kMovingNodeName])
        {
            [self removeMovingNodeFromGame:(SKSpriteNode *)contact.bodyA.node];
        }
        else
        {
            [self removeMovingNodeFromGame:(SKSpriteNode *)contact.bodyB.node];
        }
    }
}

#pragma mark - Touch Events

- (void)touchDownAtPoint:(CGPoint)pos {
    SKNode *node = [self nodeAtPoint:pos];
    if ([node.name isEqualToString:kMovingNodeName] && [node containsPoint:pos]) {
        NSLog(@"YaY");
        // you touch the object and not it will burst!
        [self increaseScore];
        [self processBurstingForNode:(SKSpriteNode *)node];
    }
}

- (void)touchMovedToPoint:(CGPoint)pos {
    // nothing
}

- (void)touchUpAtPoint:(CGPoint)pos {
    SKNode *node = [self nodeAtPoint:pos];
    if ([node.name isEqualToString:kResetButtonNodeName] && [node containsPoint:pos]) {
        NSLog(@"You tap reset/restart");
        [self processResetGame];
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch *t in touches) {[self touchDownAtPoint:[t locationInNode:self]];}
}
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{
    for (UITouch *t in touches) {[self touchMovedToPoint:[t locationInNode:self]];}
}
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch *t in touches) {[self touchUpAtPoint:[t locationInNode:self]];}
}
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch *t in touches) {[self touchUpAtPoint:[t locationInNode:self]];}
}

#pragma mark - Gaming methods

- (void)generateGame
{
    // Setup your scene here
    self.physicsWorld.contactDelegate = self;
    
    // Initialize Game Status
    _isEndGameInProcess = NO;
    
    // Initialize update time
    _lastUpdateTime = 0;
    
    // Number of nodes displayed
    _movingNodesAdded = 0;
    if(!_maxMovingNodesAllowed) { _maxMovingNodesAllowed = 15; }
    
    // Initialize score
    _internalScore = 0;
    if(!_maxScore) { _maxScore = 15; };
    
    // InitializeStatus
    _currentStatus = GameSceneStimulusStatusDefault;
    
    // Default Texture
    _defaultTexture = [SKTexture textureWithImageNamed:@"defaultTexture"];
    
    // Create nodes
    _movingNode = [self createBurstingSpriteWithTexture:_movingNodeTexture];
    
    // Create Wall/ground/roof for collision
    _wall = [self createWall];
    
    // Create burst FX
    _burstFx = [self creatBurstFx];
    
    // Create centered node
    _centerNodeDefault = [self createSimulusSpriteWithTexture:_centerNodeDefaultTexture];
    
    // Create score lable
    _scoreLebelNode = [self createScoreLabel];
    
    // Create Reset/Restart button
    _resetButton = [self createResetButton];
    
    // Add childs
    [self addChild:_wall];
    [self addChild:_centerNodeDefault];
    [self addChild:_scoreLebelNode];
}

- (void)updateGravity:(CGFloat)gravity
{
    self.physicsWorld.gravity =  CGVectorMake(0.0, gravity);
}

- (void)updateStimulusWithStatus:(GameSceneStimulusStatus)status
{
    switch (status) {
        case GameSceneStimulusStatusDefault:
            _centerNodeDefault.texture = _centerNodeDefaultTexture ? _centerNodeDefaultTexture : _defaultTexture;
            break;
        case GameSceneStimulusStatus1:
            _centerNodeDefault.texture = _centerNode1Texture ? _centerNode1Texture : _defaultTexture;
            break;
        case GameSceneStimulusStatus2:
            _centerNodeDefault.texture = _centerNode2Texture ? _centerNode2Texture : _defaultTexture;
            break;
        case GameSceneStimulusStatus3:
            _centerNodeDefault.texture = _centerNode3Texture ? _centerNode3Texture : _defaultTexture;
            break;
        default:
            _centerNodeDefault.texture = _centerNodeDefaultTexture ? _centerNodeDefaultTexture : _defaultTexture;
            break;
    }
}

- (void)updateScoreLabelWithScore:(NSInteger)score
{
    _scoreLebelNode.text = [NSString stringWithFormat:@"score : %@", @(score)];
}

- (BOOL)isAddingNewNodeAllowed
{
    BOOL allowed = NO;
    if (_movingNodesAdded < _maxMovingNodesAllowed) {
        return YES;
    }
    return allowed;
}

- (BOOL)isGameFinished
{
    BOOL isGameShoudFinished = NO;
    if (_internalScore >= _maxScore) {
        isGameShoudFinished = YES;
    }
    return isGameShoudFinished;
}

- (GameSceneStimulusStatus)statusForScore:(NSInteger)score
{
    GameSceneStimulusStatus status = GameSceneStimulusStatusDefault;
    if (score >= 0 && score <= 3) {
        status = GameSceneStimulusStatusDefault;
    } else if (score > 3 && score <= 7 )
    {
        status = GameSceneStimulusStatus1;
    } else if (score > 7 && score <= 10 )
    {
        status = GameSceneStimulusStatus2;
    } else if (score > 10)
    {
        status = GameSceneStimulusStatus3;
    }
    return status;
}

- (void)addMovingNodeIntoGame
{
    SKSpriteNode *node = [_movingNode copy];
    node.position = [self randomStartingPoint];
    [self addChild:node];
    _movingNodesAdded++;
}

- (void)removeMovingNodeFromGame:(SKSpriteNode *)node
{
    [node removeFromParent];
    node = nil;
    _movingNodesAdded--;
}

- (void)processBurstingForNode:(SKSpriteNode *)node
{
    // Actions
    SKAction *removing = [SKAction runBlock:^{
        [self removeMovingNodeFromGame:node];
    }];
    SKAction *burstingSequence = [SKAction sequence:
                                  @[
                                   [SKAction scaleBy:2. duration:0.10],
                                   removing
                                  ]];
    [node runAction:[SKAction fadeOutWithDuration:0.25]];
    [node runAction:burstingSequence];
    // Add FX
    SKEmitterNode *burstNode = [_burstFx copy];
    burstNode.position = node.position;
    [self addChild:burstNode];
}

- (void)processTheEndOfGame
{
    //TODO: Write an ending for the game
    NSLog(@"This is the end of the game buddy");
    _isEndGameInProcess = YES;
    [self addChild:_resetButton];
}

- (void)processResetGame
{
    NSLog(@"process reset/restart");
    
    [self removeAllChildren];
    [self generateGame];
}

#pragma mark - Scoring

- (void)updateScore:(NSInteger)newscore
{
    if (newscore >= 0 && newscore <= _maxScore) {
        _internalScore = newscore;
        [self updateStimulusWithStatus:[self statusForScore:_internalScore]];
        [self updateScoreLabelWithScore:_internalScore];
    }
}

- (NSInteger)myScore
{
    return _internalScore;
}

- (void)increaseScore
{
    [self updateScore:_internalScore + 1];
}

- (void)decreaseScore
{
    if (_internalScore == 0) {
        return;
    }
    [self updateScore:_internalScore - 1];
}

#pragma mark - Sprite creation

- (SKSpriteNode *)createBurstingSpriteWithTexture:(SKTexture *)texture
{
    if (!texture) {
        texture = _defaultTexture;
    }
    SKSpriteNode *burstingNode = [SKSpriteNode spriteNodeWithTexture:texture];
    burstingNode.name = kMovingNodeName;
    burstingNode.zPosition = 2;
    CGFloat collisionExtension = 0.f;
    CGSize collisionRect = CGSizeMake(texture.size.height + collisionExtension, texture.size.width + collisionExtension);
    burstingNode.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:collisionRect];
    burstingNode.physicsBody.usesPreciseCollisionDetection = YES;
    burstingNode.physicsBody.mass = 2;
    burstingNode.physicsBody.dynamic = YES;
    burstingNode.physicsBody.categoryBitMask = kMovingNodeCategory;
    burstingNode.physicsBody.contactTestBitMask = kWallCategory;
    return burstingNode;
}

- (SKSpriteNode *)createSimulusSpriteWithTexture:(SKTexture *)texture
{
    if (!texture) {
        texture = _defaultTexture;
    }
    SKSpriteNode *stimulusNode = [SKSpriteNode spriteNodeWithTexture:texture];
    stimulusNode.name = kStimulusNodeName;
    stimulusNode.zPosition = 1;
    return stimulusNode;
}

- (SKShapeNode *)createWall
{
    SKShapeNode *wall = [SKShapeNode shapeNodeWithRectOfSize:CGSizeMake(self.frame.size.width, 1)];
    wall.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:CGSizeMake(self.frame.size.width, 1)];
    wall.name = kWallNodeName;
    wall.lineWidth = 1;
    wall.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMinY(self.frame) - 2);
    wall.physicsBody.mass = NSUIntegerMax;
    wall.physicsBody.affectedByGravity = NO;
    wall.physicsBody.categoryBitMask = kWallCategory;
    wall.physicsBody.contactTestBitMask = kMovingNodeCategory;
    return wall;
}

- (SKEmitterNode *)creatBurstFx
{
    NSString *burstPath = [[NSBundle mainBundle] pathForResource:@"MyFireParticle" ofType:@"sks"];
    SKEmitterNode *burstFx = [NSKeyedUnarchiver unarchiveObjectWithFile:burstPath];
    burstFx.zPosition = 1;
    [burstFx runAction:[SKAction sequence:@[
                                             [SKAction fadeOutWithDuration:2.],
                                             [SKAction removeFromParent]
                                             ]]];
    return burstFx;
}

- (SKLabelNode *)createScoreLabel
{
    NSString *scoreString = @"score : 0";
    SKLabelNode *scoreLabelNode = [SKLabelNode labelNodeWithText:scoreString];
    scoreLabelNode.zPosition = 1;
    scoreLabelNode.color = [UIColor whiteColor];
    scoreLabelNode.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMinY(self.frame)+150);
    return scoreLabelNode;
}

- (SKLabelNode *)createResetButton
{
    NSString *resetLabelString = @"restart";
    SKLabelNode *resetLabelButton = [SKLabelNode labelNodeWithText:resetLabelString];
    resetLabelButton.name = kResetButtonNodeName;
    resetLabelButton.zPosition = 3;
    resetLabelButton.color = [UIColor whiteColor];
    resetLabelButton.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMaxY(self.frame)-300);
    
    SKAction *scaleUp = [SKAction scaleTo:1.2 duration:0.10];
    SKAction *scaleDown = [SKAction scaleTo:1. duration:0.10];
    SKAction *wait = [SKAction waitForDuration:3];
    SKAction *sequence = [SKAction sequence:@[scaleUp,scaleDown,wait]];
    SKAction *sequenceLoop = [SKAction repeatActionForever:sequence];
    [resetLabelButton runAction:sequenceLoop];
    
    return resetLabelButton;
}

#pragma mark - Textures

- (void)setTextureForBurstingObject:(SKTexture *)texture
{
    _movingNodeTexture = texture;
}

- (void)setTextureForStimulusObject:(SKTexture *)texture status:(GameSceneStimulusStatus)status
{
    switch (status) {
        case GameSceneStimulusStatusDefault:
            _centerNodeDefaultTexture = texture;
            break;
        case GameSceneStimulusStatus1:
            _centerNode1Texture = texture;
            break;
        case GameSceneStimulusStatus2:
            _centerNode2Texture = texture;
            break;
        case GameSceneStimulusStatus3:
            _centerNode3Texture = texture;
            break;
        default:
            _centerNodeDefaultTexture = texture;
            break;
    }
}

#pragma mark - Convenience

- (CGPoint)randomStartingPoint
{
    CGFloat width = self.frame.size.width;
    CGFloat height = self.frame.size.height;
    CGFloat x = arc4random_uniform(width+1) - (width/2);
    CGFloat y = height/2;
    CGPoint pos = CGPointMake(x, y);
    return pos;
}

@end
