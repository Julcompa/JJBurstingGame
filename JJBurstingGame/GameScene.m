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
    NSTimeInterval _elapsedTime;
    NSTimeInterval _inactivityTime;
    GameSceneStimulusStatus _currentStatus;
    NSInteger _movingNodesAdded;
    NSInteger _internalScore;
    
    BOOL _isEndGameInProcess;
    
    // Moving items
    //NOTE: We just need one node that we can copy for reuse and randomly display it.
    SKSpriteNode *_movingNode;
    NSArray *_movingNodeTextures;
    //SKTexture *_movingNodeTexture;
    
    // Central item
    //NOTE: This central item changes according to the score (we might need several nodes to reflect it...). We just create it once
    SKSpriteNode *_centerNodeDefault;
    //SKSpriteNode *_centerNode1;
    //SKSpriteNode *_centerNode2;
    //SKSpriteNode *_centerNode3;
    
    //TODO: change it and create an array of texture
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
    
    // Background
    SKSpriteNode *_backgroundNode;
    SKTexture *_backgroundTexture;
    
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
    _elapsedTime += dt;
    _inactivityTime += dt;
    
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

- (void)touchDownAtPoint:(CGPoint)pos
{
    _inactivityTime = 0; // reset inactivity
    
    SKNode *node = [self nodeAtPoint:pos];
    if ([node.name isEqualToString:kMovingNodeName] && [node containsPoint:pos])
    {
        NSLog(@"YaY");
        // you touch the object and not it will burst!
        [self increaseScore];
        [self processBurstingForNode:(SKSpriteNode *)node];
    }
}

- (void)touchMovedToPoint:(CGPoint)pos
{
    _inactivityTime = 0; // reset inactivity
}

- (void)touchUpAtPoint:(CGPoint)pos
{
    _inactivityTime = 0; // reset inactivity
    
    SKNode *node = [self nodeAtPoint:pos];
    if ([node.name isEqualToString:kResetButtonNodeName] && [node containsPoint:pos])
    {
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
    
    // Initialize game duration time
    if(!_duration) { _duration = 120; }
    if(!_inactivityDuration) { _inactivityDuration = 60; }
    _lastUpdateTime = 0;
    _elapsedTime = 0;
    _inactivityTime = 0;
    
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
    _movingNode = [self createBurstingSpriteWithTexture:(_movingNodeTextures.count > 0) ? _movingNodeTextures[0] : nil];
    
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
    
    // Create Background
    _backgroundNode = [self createBackgroundWithTexture:_backgroundTexture];
    
    // Add childs
    [self addChild:_backgroundNode];
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
            [_centerNodeDefault runAction:[SKAction scaleTo:1. duration:0.1]];
            break;
        case GameSceneStimulusStatus1:
            _centerNodeDefault.texture = _centerNode1Texture ? _centerNode1Texture : _defaultTexture;
            [_centerNodeDefault runAction:[SKAction scaleTo:1.5 duration:0.1]];
            break;
        case GameSceneStimulusStatus2:
            _centerNodeDefault.texture = _centerNode2Texture ? _centerNode2Texture : _defaultTexture;
            [_centerNodeDefault runAction:[SKAction scaleTo:2. duration:0.1]];
            break;
        case GameSceneStimulusStatus3:
            _centerNodeDefault.texture = _centerNode3Texture ? _centerNode3Texture : _defaultTexture;
            [_centerNodeDefault runAction:[SKAction scaleTo:2.5 duration:0.1]];
            break;
        default:
            _centerNodeDefault.texture = _centerNodeDefaultTexture ? _centerNodeDefaultTexture : _defaultTexture;
            [_centerNodeDefault runAction:[SKAction scaleTo:1. duration:0.1]];
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
    if (_internalScore  >= _maxScore ||
        _elapsedTime    >  _duration ||
        _inactivityTime >  _inactivityDuration ||
        _isEndGameInProcess)
    {
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
    
    if(_movingNodeTextures.count > 0)
    {
        NSUInteger randomIndex = (NSUInteger)arc4random_uniform((uint32_t)_movingNodeTextures.count);
        node.texture = _movingNodeTextures[randomIndex];
    }
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
    burstNode.particleColor = [self generateRandomColor];
    burstNode.position = node.position;
    [self addChild:burstNode];
}

- (void)processFireworks
{
    SKAction *fireWorks = [SKAction runBlock:^{
        // trigger fireworks!!
        for (NSInteger i = 0; i < 3; i++) {
            SKEmitterNode *burstFxNode = [_burstFx copy];
            burstFxNode.position = [self randomPointIntoGameBoard];
            burstFxNode.particleColor = [self generateRandomColor];
            [self addChild:burstFxNode];
        }
    }];
    SKAction *wait = [SKAction waitForDuration:0.5];
    SKAction *FireworksWithDelay = [SKAction sequence:@[fireWorks,wait]];
    SKAction *multipleFireworks = [SKAction repeatAction:FireworksWithDelay count:5];
    [self runAction:multipleFireworks];
}

- (void)processTheEndOfGame
{
    NSLog(@"This is the end of the game buddy");
    _isEndGameInProcess = YES;
    [self runAction:[SKAction sequence:@[[SKAction waitForDuration:2],
                                         [SKAction runBlock:^{
        [self addChild:_resetButton];
    }]]]];
    [self processPlayerWinning];
}

- (void)processPlayerWinning
{
    NSLog(@"You win :)");
    [self processFireworks];
    [self enumerateChildNodesWithName:kMovingNodeName usingBlock:^(SKNode * _Nonnull node, BOOL * _Nonnull stop) {
        [self processBurstingForNode:(SKSpriteNode *)node];
    }];
    
    //TODO: Change it for a better way
    if (_centerNodeDefault && _centerNode1Texture &&
        _centerNode2Texture && _centerNode3Texture)
    {
        SKAction *rainbowOFApples = [SKAction animateWithTextures:@[_centerNodeDefaultTexture,
                                                                    _centerNode1Texture,
                                                                    _centerNode2Texture,
                                                                    _centerNode3Texture]
                                                     timePerFrame:0.1];
        SKAction *rainbowOFApplesLoop = [SKAction repeatActionForever:rainbowOFApples];
        [_centerNodeDefault runAction:rainbowOFApplesLoop];
    }
}

- (void)processPlayerLoosing
{
    NSLog(@"You Loose :(");
    // Nothing yet
}

- (void)processResetGame
{
    NSLog(@"process reset/restart");
    [self removeAllActions];
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
    scoreLabelNode.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMinY(self.frame)+(self.frame.size.width / 20));
    scoreLabelNode.fontName = @"GillSans-Bold";
    scoreLabelNode.fontSize = self.frame.size.width / 20;
    return scoreLabelNode;
}

- (SKLabelNode *)createResetButton
{
    NSString *resetLabelString = @"restart";
    SKLabelNode *resetLabelButton = [SKLabelNode labelNodeWithText:resetLabelString];
    resetLabelButton.name = kResetButtonNodeName;
    resetLabelButton.zPosition = 3;
    resetLabelButton.fontName = @"GillSans-Bold";
    resetLabelButton.fontSize = self.frame.size.width / 20;
    resetLabelButton.fontColor = [UIColor whiteColor];
    resetLabelButton.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMaxY(self.frame)-(self.frame.size.width / 10));
    
    SKAction *scaleUp = [SKAction scaleTo:3. duration:0.10];
    SKAction *scaleDown = [SKAction scaleTo:1. duration:0.10];
    SKAction *wait = [SKAction waitForDuration:3];
    SKAction *sequence = [SKAction sequence:@[scaleUp,scaleDown,wait]];
    SKAction *sequenceLoop = [SKAction repeatActionForever:sequence];
    [resetLabelButton runAction:sequenceLoop];
    
    return resetLabelButton;
}

- (SKSpriteNode *)createBackgroundWithTexture:(SKTexture *)texture
{
    SKSpriteNode *bgNode = [SKSpriteNode spriteNodeWithTexture:texture];
    bgNode.zPosition = 0;
    bgNode.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame));
    return bgNode;
}

#pragma mark - Textures

- (void)addTextureForBurstingObject:(NSArray<SKTexture *> *)textures
{
    if(!_movingNodeTextures)
    {
        _movingNodeTextures = [NSArray arrayWithArray:textures];
    }
    else
    {
        NSMutableArray *temp = [NSMutableArray arrayWithArray:_movingNodeTextures];
        [temp addObjectsFromArray:textures];
        _movingNodeTextures = [NSArray arrayWithArray:temp];
    }
}

- (void)setTextureForBurstingObject:(SKTexture *)texture
{
    _movingNodeTextures = @[texture];
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

- (void)setTextureForBackground:(SKTexture *)texture
{
    _backgroundTexture = texture;
}

#pragma mark - Convenience

- (SKColor *)generateRandomColor
{
    // Random RGB
    CGFloat red  = (CGFloat)(arc4random_uniform(256) / 256.f);
    CGFloat green  = (CGFloat)(arc4random_uniform(256) / 256.f);
    CGFloat blue  = (CGFloat)(arc4random_uniform(256) / 256.f);
    return [SKColor colorWithRed:red green:green blue:blue alpha:1];
}

- (SKColor *)generateRandomPastelColor
{
    // Random RGB
    CGFloat red  = (CGFloat)(arc4random_uniform(256) / 256.f);
    CGFloat green  = (CGFloat)(arc4random_uniform(256) / 256.f);
    CGFloat blue  = (CGFloat)(arc4random_uniform(256) / 256.f);
    
    // Mix with light-blue because it's pastel
    CGFloat mixRed = 1+0xad/256;
    CGFloat mixGreen = 1+0xd8/256;
    CGFloat mixBlue = 1+0xe6/256;
    red = (red + mixRed) / 3;
    green = (green + mixGreen) / 3;
    blue = (blue + mixBlue) / 3;
    return [SKColor colorWithRed:red green:green blue:blue alpha:1];
}

- (CGPoint)randomStartingPoint
{
    CGFloat width = self.frame.size.width;
    CGFloat height = self.frame.size.height;
    CGFloat x = arc4random_uniform(width+1) - (width/2);
    CGFloat y = height/2;
    CGPoint pos = CGPointMake(x, y);
    return pos;
}

- (CGPoint)randomPointIntoGameBoard
{
    CGFloat width = self.frame.size.width;
    CGFloat height = self.frame.size.height;
    CGFloat x = arc4random_uniform(width+1) - (width/2);
    CGFloat y = arc4random_uniform(height+1) - (height/2);
    CGPoint pos = CGPointMake(x, y);
    return pos;
}

@end
