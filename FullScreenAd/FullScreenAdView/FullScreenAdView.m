//
//  FullScreenAdView.m
//  FullScreenAd
//
//  Created by zhifu360 on 2018/11/19.
//  Copyright © 2018 ZZJ. All rights reserved.
//

#import "FullScreenAdView.h"
#import "SDWebImageManager.h"

//屏幕Size
#define ADSCREEN_SIZE [UIScreen mainScreen].bounds.size

//状态栏Size
#define ADSTATUSBAR_SIZE [UIApplication sharedApplication].statusBarFrame.size

//tag值
static const NSInteger ImageViewTag = 100;
static const NSInteger CircleViewTag = 200;

@interface FullScreenAdView ()

///图片
@property (nonatomic, strong) UIImageView *imageView;
///跳过按钮
@property (nonatomic, strong) UIButton *skipButton;
///圆形动画BaseView
@property (nonatomic, strong) UIView *circleView;
///圆形CAShaperLayer
@property (nonatomic, strong) CAShapeLayer *circleLayer;
///UIBezierPath
@property (nonatomic, strong) UIBezierPath *circlePath;
///计时器
@property (nonatomic, strong) dispatch_source_t timer;
///计时器计数
@property (nonatomic, assign) NSInteger count;
///等待机制计时器
@property (nonatomic, strong) dispatch_source_t waitTimer;
//是否将要消失
@property (nonatomic, assign) BOOL flag;

@end

@implementation FullScreenAdView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self baseInit];
    }
    return self;
}

///初始化
- (void)baseInit {
    
    self.frame = [UIScreen mainScreen].bounds;
    
    [self addSubview:self.imageView];
    
    self.skipButtonType = SkipButtonTypeNormal;
    
    _count = 0;
    
    _duration = 5;
    
    _flag = NO;
}

///获取启动图片
- (UIImage *)getLaunchImage {
    
    CGSize viewSize = ADSCREEN_SIZE;
    NSString *viewOrientation = @"Portrait"; // 横屏请设置成 @"Landscape"
    UIImage *lauchImage = nil;
    NSArray *imagesDictionary = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"UILaunchImages"];
    
    for (NSDictionary *dic in imagesDictionary) {
        CGSize imageSize = CGSizeFromString(dic[@"UILaunchImageSize"]);
        if (CGSizeEqualToSize(imageSize, viewSize) && [viewOrientation isEqualToString:dic[@"UILaunchImageOrientation"]]) {
            lauchImage = [UIImage imageNamed:dic[@"UILaunchImageName"]];
        }
    }
    return lauchImage;
}

///加载广告
- (void)reloadWithUrl:(NSString *)urlStr {
    
    if (!urlStr || !urlStr.length)  {
        [self removeFromSuperview];
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    
    NSURL *imageUrl = [NSURL URLWithString:urlStr];
    
    UIImage *cacheImage = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:urlStr];
    if (cacheImage) {
        //显示图片
        [self addAdWithImage:cacheImage];
    } else {
        
        SDWebImageManager *manager = [SDWebImageManager sharedManager];
        [[manager imageDownloader] downloadImageWithURL:imageUrl options:SDWebImageDownloaderLowPriority progress:^(NSInteger receivedSize, NSInteger expectedSize, NSURL * _Nullable targetURL) {
            
        } completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished) {
            
            if (image && finished && error == nil) {
                //显示图片
                [weakSelf addAdWithImage:image];
                //保存图片
                [[SDImageCache sharedImageCache] storeImage:image forKey:urlStr completion:nil];
            }
            
        }];
        
    }
}

- (void)addAdWithImage:(UIImage *)image {
    
    if (_flag) return;
    
    if (_waitTimer) dispatch_source_cancel(_waitTimer);
    
    //UI
    self.imageView.image = image;
    
    if (_skipButtonType == SkipButtonTypeCircleAnimation) {
        [self addSubview:self.circleView];
        [self setCircleTimer];
    } else {
        [self addSubview:self.skipButton];
        [self setSkidBtnTimer];
    }
    
    //添加显示动画
    CATransition *animation = [CATransition animation];
    animation.duration = 0.2;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.type = kCATransitionFade;
    [self.layer addAnimation:animation forKey:@"animation"];
}

#pragma mark - Hide
- (void)hide {
    
    [UIView animateWithDuration:0.5 delay:0.3 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.transform = CGAffineTransformMakeScale(1.2, 1.2);
        self.alpha = 0.0f;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

#pragma mark - 点击事件
///点击事件
- (void)tapAction:(UITapGestureRecognizer *)tapGesture {
    
    if (_timer) dispatch_source_cancel(_timer);
    
    switch (tapGesture.view.tag) {
        case ImageViewTag:
            //点击广告图片
            if (_adTapBlock) _adTapBlock();
            break;
        case CircleViewTag:
            //点击跳过
            break;
        default:
            break;
    }
    
    [self hide];
}

///按钮点击
- (void)skipBtnAction {
    
    if (_timer) dispatch_source_cancel(_timer);
    
    [self hide];
}

#pragma mark - 设置定时器
///设置圆形动画定时器
- (void)setCircleTimer {
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    _timer= dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(_timer, dispatch_walltime(NULL, 0), 0.05 * NSEC_PER_SEC, 0);//每秒执行
    dispatch_source_set_event_handler(_timer, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (self.count >= self.duration*20) {
                dispatch_source_cancel(self.timer);
                self.circleLayer.strokeStart = 1;
                //hide视图
                [self hide];
            } else {
                self.circleLayer.strokeStart += 0.01;
                self.count ++;
            }
            
        });
    });
    dispatch_resume(_timer);
}

///设置跳过按钮定时器
- (void)setSkidBtnTimer {
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(_timer, dispatch_walltime(NULL, 0), 1.0 * NSEC_PER_SEC, 0);
    dispatch_source_set_event_handler(_timer, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"duration===%ld",self.duration);
            if (self.duration <= 0) {
                dispatch_source_cancel(self.timer);
                //hide视图
                [self hide];
            } else {
                //设置跳过按钮文字
                [self skipButtonShowTimeWithDuration:self.duration];
                self.duration --;
            }
            
        });
    });
    dispatch_resume(_timer);
}

- (void)skipButtonShowTimeWithDuration:(NSInteger)duration {
    
    switch (_skipButtonType) {
        case SkipButtonTypeNormal:
            [self.skipButton setTitle:[NSString stringWithFormat:@"%ld 跳过",(long)duration] forState:UIControlStateNormal];
            break;
        case SkipButtonTypeOnlyTitle:
            [self.skipButton setTitle:@"跳过" forState:UIControlStateNormal];
            break;
        case SkipButtonTypeOnlyTime:
            [self.skipButton setTitle:[NSString stringWithFormat:@"%ld S",(long)duration] forState:UIControlStateNormal];
            break;
        case SkipButtonTypeNone:
            self.skipButton.hidden = YES;
            break;
        default:
            break;
    }
}

///设置等待机制计时器
- (void)setWaitMechanismTimer {
    
    if (_waitTimer) dispatch_source_cancel(_waitTimer);
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    _waitTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(_waitTimer, dispatch_walltime(NULL, 0), 1.0 * NSEC_PER_SEC, 0);
    dispatch_source_set_event_handler(_waitTimer, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
           
            if (self.waitTime <= 0) {
                self.flag = YES;
                dispatch_source_cancel(self.waitTimer);
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self hide];
                });
            } else {
                self.waitTime --;
            }
            
        });
    });
    dispatch_resume(_waitTimer);
}

#pragma mark - setter
- (void)setWaitTime:(NSInteger)waitTime {
    
    _waitTime = waitTime;
    if (waitTime < 1) {
        _waitTime = 1;
    }
    
    [self setWaitMechanismTimer];
}

#pragma mark - lazy
- (UIButton *)skipButton {
    if (!_skipButton) {
        _skipButton = [UIButton new];
        [_skipButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _skipButton.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.4];
        _skipButton.titleLabel.font = [UIFont systemFontOfSize:13.0f];
        _skipButton.layer.masksToBounds = YES;
        _skipButton.frame = CGRectMake(ADSCREEN_SIZE.width - 70, ADSTATUSBAR_SIZE.height + 10, 60, 30);
        [_skipButton addTarget:self action:@selector(skipBtnAction) forControlEvents:UIControlEventTouchUpInside];
    }
    return _skipButton;
}

- (UIImageView *)imageView {
    if (!_imageView) {
        _imageView = [[UIImageView alloc] initWithFrame:self.bounds];
        _imageView.userInteractionEnabled = YES;
        _imageView.image = [self getLaunchImage];
        [_imageView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapAction:)]];
        _imageView.tag = ImageViewTag;
    }
    return _imageView;
}

- (UIView *)circleView {
    if (!_circleView) {
        _circleView = [[UIView alloc] initWithFrame:CGRectMake(ADSCREEN_SIZE.width - 70, ADSTATUSBAR_SIZE.height + 10, 40, 40)];
        [_circleView.layer addSublayer:self.circleLayer];
        
        UILabel *skip = [[UILabel alloc] initWithFrame:_circleView.bounds];
        skip.text = @"跳过";
        skip.textAlignment = NSTextAlignmentCenter;
        skip.textColor = [UIColor whiteColor];
        skip.font = [UIFont systemFontOfSize:15.0f];
        [_circleView addSubview:skip];
        
        [_circleView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapAction:)]];
        _circleView.tag = CircleViewTag;
    }
    return _circleView;
}

- (CAShapeLayer *)circleLayer {
    if (!_circleLayer) {
        _circleLayer = [CAShapeLayer layer];
        _circleLayer.fillColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.4].CGColor;// 填充颜色
        _circleLayer.strokeColor = [UIColor redColor].CGColor;// 绘制颜色
        _circleLayer.lineCap = kCALineCapRound;
        _circleLayer.lineJoin = kCALineJoinRound;
        _circleLayer.frame = self.bounds;
        _circleLayer.path = self.circlePath.CGPath;
        _circleLayer.strokeStart = 0;
    }
    return _circleLayer;
}

- (UIBezierPath *)circlePath {
    if (!_circlePath) {
        _circlePath = [UIBezierPath bezierPathWithArcCenter:CGPointMake(20, 20) radius:19 startAngle:-0.5*M_PI endAngle:1.5*M_PI clockwise:YES];
    }
    return _circlePath;
}

@end
