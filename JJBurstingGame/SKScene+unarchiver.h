//
//  SKScene+unarchiver.h
//  JJBurstingGame
//
//  Created by Julien on 4/7/17.
//  Copyright © 2017 Julien Comparato. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>

@interface SKScene (unarchiver)

+ (instancetype)unarchiveFromFile:(NSString *)file;

@end
