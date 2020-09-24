//
//  ImageProcessorBridge.h
//  ImageExposureFusion
//
//  Created by Jan Hoelscher on 22.09.20.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@interface ImageProcessorBridge : NSObject

- (UIImage *) processImages:(NSArray<UIImage*> * ) sourceImages;

@end
