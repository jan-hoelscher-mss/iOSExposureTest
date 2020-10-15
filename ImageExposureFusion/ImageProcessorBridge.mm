//
//  ImageProcessorBridge.m
//  ImageExposureFusion
//
//  Created by Jan Hoelscher on 22.09.20.
//

#import <Foundation/Foundation.h>
#import "ImageProcessorBridge.hpp"

#undef NO
#undef YES
#import <opencv2/opencv.hpp>
#import <opencv2/imgcodecs/ios.h>

@implementation ImageProcessorBridge

- (UIImage *) processImages:(NSArray<UIImage*> * ) sourceImages
{
    std::cout << "OpenCV version : " << CV_VERSION << std::endl;

    std::vector<cv::Mat> images;
    std::vector<cv::Mat> aligned;

    for(UIImage * uiimage in sourceImages){
        
        cv::Mat opencvImage;
        UIImageToMat(uiimage, opencvImage, false);
        
        cv::Mat opencvImageOut;
        cv::cvtColor(opencvImage, opencvImageOut, cv::COLOR_RGBA2RGB);
        images.push_back(opencvImageOut);
    }

    //cv::Ptr<cv::AlignMTB> alignMTB = cv::createAlignMTB();
    //alignMTB->process(images, aligned);
    
    cv::Mat exposureFusion;
    cv::Ptr<cv::MergeMertens> mergeMertens = cv::createMergeMertens();
    mergeMertens->process(images, exposureFusion);
    exposureFusion = exposureFusion * 255;

    cv::Mat fusion8bit;
    exposureFusion.convertTo(fusion8bit, CV_8U);
    UIImage * result = MatToUIImage( fusion8bit );
    return result;
}

@end
