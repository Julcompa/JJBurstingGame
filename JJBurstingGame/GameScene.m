//
//  GameScene.m
//  JJBurstingGame
//
//  Created by Julien Comparato on 06/04/2017.
//  Copyright © 2017 Julien Comparato. All rights reserved.
//

#import "GameScene.h"

static const uint32_t kSpinnyCategory = 0x1 << 0;
static const uint32_t kWallsCategory = 0x1 << 1;

@implementation GameScene {
    NSTimeInterval _lastUpdateTime;
    SKShapeNode *_spinnyNode;
    SKShapeNode *_spinnyNodeFalling;
    SKShapeNode *_wall;
    SKEmitterNode *_burstFx;
    
    BOOL isWallAdded;
}

- (void)sceneDidLoad {
    // env
    isWallAdded = NO;
    
    // Setup your scene here
    //self.physicsWorld.gravity =  CGVectorMake(0.0, 0.0);
    self.physicsWorld.contactDelegate = self;
    
    // Initialize update time
    _lastUpdateTime = 0;
    
    CGFloat w = (self.size.width + self.size.height) * 0.05;
    
    // Create shape node to use during mouse interaction
    _spinnyNode = [SKShapeNode shapeNodeWithRectOfSize:CGSizeMake(w, w) cornerRadius:w * 0.3];
    _spinnyNode.lineWidth = 2.5;
    _spinnyNode.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:CGSizeMake(w, w)];
    _spinnyNode.physicsBody.mass = 2;
    _spinnyNode.physicsBody.dynamic = YES;
    _spinnyNode.physicsBody.categoryBitMask = kSpinnyCategory;
    _spinnyNode.physicsBody.contactTestBitMask = kWallsCategory;
    
    [_spinnyNode runAction:[SKAction repeatActionForever:[SKAction rotateByAngle:M_PI duration:0.5]]];
    
    // Create Wall/ground/roof for collision
    _wall = [SKShapeNode shapeNodeWithRectOfSize:CGSizeMake(self.frame.size.width, 10)];
    _wall.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:CGSizeMake(self.frame.size.width, 1)];
    _wall.lineWidth = 2.5;
    _wall.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMinY(self.frame) - (2 * w));
    _wall.physicsBody.mass = 1000;
    _wall.physicsBody.affectedByGravity = NO;
    _wall.physicsBody.categoryBitMask = kWallsCategory;
    _wall.physicsBody.contactTestBitMask = kSpinnyCategory;
    [self addChild:_wall];
    
    // Create burst FX
    NSString *burstPath =
    [[NSBundle mainBundle] pathForResource:@"MyFireParticle" ofType:@"sks"];
    _burstFx = [NSKeyedUnarchiver unarchiveObjectWithFile:burstPath];
    [_burstFx runAction:[SKAction sequence:@[
                                             [SKAction fadeOutWithDuration:0.4],
                                             [SKAction removeFromParent]
                                             ]]];
}

- (void)didBeginContact:(SKPhysicsContact *)contact
{
    [self removeFallingNode];
}

- (void)touchDownAtPoint:(CGPoint)pos {
    if ([_spinnyNodeFalling containsPoint:pos]) {
        NSLog(@"YaY");
        // you touch the object and not it will burst!
        SKEmitterNode *burstNode = [_burstFx copy];
        burstNode.position = _spinnyNodeFalling.position;
        [self removeFallingNode];
        [self addChild:burstNode];
        
        //TODO: increase score
    }
}

- (void)touchMovedToPoint:(CGPoint)pos {
    // nothing
}

- (void)touchUpAtPoint:(CGPoint)pos {
    // nothing
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

- (CGPoint)randomStartingPoint
{
    CGFloat width = self.frame.size.width;
    CGFloat height = self.frame.size.height;
    CGFloat x = arc4random_uniform(width+1) - (width/2);
    CGFloat y = height/2;
    CGPoint pos = CGPointMake(x, y);
    return pos;
}

- (SKColor *)randomColor
{
    return (arc4random_uniform(2) > 0 ) ? [SKColor redColor] : [SKColor blueColor];
}


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
    
    // add a random sprite
    if (!_spinnyNodeFalling) {
        _spinnyNodeFalling = [_spinnyNode copy];
        _spinnyNodeFalling.name = @"toto";
        _spinnyNodeFalling.position = [self randomStartingPoint];
        _spinnyNodeFalling.strokeColor = [self randomColor];
        [self addChild:_spinnyNodeFalling];
    }
    
    _lastUpdateTime = currentTime;
}

// Gaming methods
- (void)removeFallingNode
{
    [_spinnyNodeFalling removeFromParent];
    _spinnyNodeFalling = nil;
}

@end
