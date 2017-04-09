//
//  GameViewController.m
//  JJBurstingGame
//
//  Created by Julien Comparato on 06/04/2017.
//  Copyright © 2017 Julien Comparato. All rights reserved.
//

#import "GameViewController.h"
#import "GameScene.h"
#import "SKScene+unarchiver.h"

@implementation GameViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    GameScene *sceneNode = nil;
    if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_9_x_Max)
    {
        // Load 'GameScene.sks' as a GKScene. This provides gameplay related content
        // including entities and graphs.
        GKScene *scene = [GKScene sceneWithFileNamed:@"GameScene"];
        sceneNode = (GameScene *)scene.rootNode;
        // Copy gameplay related content over to the scene
        sceneNode.entities = [scene.entities mutableCopy];
        sceneNode.graphs = [scene.graphs mutableCopy];
    }
    else
    {
        // Load 'GameScene.sks' as a SKScene. This provides gameplay related content
        // including entities and graphs.
        sceneNode = [GameScene unarchiveFromFile:@"GameScene"];
    }
    
    // Set the scale mode to scale to fit the window
    sceneNode.scaleMode = SKSceneScaleModeAspectFill;
    [sceneNode addTextureForBurstingObject:@[[SKTexture textureWithImageNamed:@"apple"],
                                             [SKTexture textureWithImageNamed:@"carote"]]];
    [sceneNode setTextureForStimulusObject:[SKTexture textureWithImageNamed:@"appleDefault"] status:GameSceneStimulusStatusDefault];
    [sceneNode setTextureForStimulusObject:[SKTexture textureWithImageNamed:@"apple1"] status:GameSceneStimulusStatus1];
    [sceneNode setTextureForStimulusObject:[SKTexture textureWithImageNamed:@"apple2"] status:GameSceneStimulusStatus2];
    [sceneNode setTextureForStimulusObject:[SKTexture textureWithImageNamed:@"apple3"] status:GameSceneStimulusStatus3];
    [sceneNode setMaxMovingNodesAllowed:15];
    [sceneNode updateGravity:-1.5];
    [sceneNode setMaxScore:15];
    
    SKView *skView = (SKView *)self.view;
    
    // Present the scene
    [skView presentScene:sceneNode];
    
    skView.showsFPS = YES;
    skView.showsNodeCount = YES;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskAllButUpsideDown;
    } else {
        return UIInterfaceOrientationMaskAll;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

@end
