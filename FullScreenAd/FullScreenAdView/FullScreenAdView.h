//
//  FullScreenAdView.h
//  FullScreenAd
//
//  Created by zhifu360 on 2018/11/19.
//  Copyright © 2018 ZZJ. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - 启动页广告

typedef NS_ENUM(NSUInteger, SkipButtonType) {
    SkipButtonTypeNormal = 0, //普通的倒计时+跳过
    SkipButtonTypeCircleAnimation, //圆形动画+跳过
    SkipButtonTypeOnlyTitle, //只有跳过
    SkipButtonTypeOnlyTime, //只有倒计时
    SkipButtonTypeNone //无
};

@interface FullScreenAdView : UIView

///广告图的显示时间（默认5秒）
@property (nonatomic, assign) NSInteger duration;
///获取数据前，启动图的等待时间（若不设置则不启动等待机制）
@property (nonatomic, assign) NSInteger waitTime;
///右上角按钮的样式（默认倒计时+跳过）
@property (nonatomic, assign) SkipButtonType skipButtonType;
///广告图点击事件回调
@property (nonatomic, copy) dispatch_block_t adTapBlock;

///加载广告图
- (void)reloadWithUrl:(NSString *)urlStr;

@end

NS_ASSUME_NONNULL_END
