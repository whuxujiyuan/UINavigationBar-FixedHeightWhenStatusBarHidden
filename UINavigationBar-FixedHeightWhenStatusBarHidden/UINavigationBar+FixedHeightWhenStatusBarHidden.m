//
//  UINavigationBar+FixedHeightWhenStatusBarHidden.m
//
//  Created by Vitaliy Ivanov on 7/30/14.
//  Copyright (c) 2014 Factorial Complexity. All rights reserved.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "UINavigationBar+FixedHeightWhenStatusBarHidden.h"
#import <objc/runtime.h>

#define FYIsIOSVersionGreaterThanOrEqualTo(v) \
([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

#define IS_PORTRAIT YES// UIDeviceOrientationIsPortrait([UIDevice currentDevice].orientation)

#define IS_IPHONE    (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)

static char const* const FixedNavigationBarSize = "FixedNavigationBarSize";

@implementation UINavigationBar (FixedHeightWhenStatusBarHidden)

/// 是否为全面屏设备（刘海屏 / 灵动岛 / 折叠屏 iPhone Duo 等）：
/// 全面屏设备（存在底部 Home Indicator 或侧边安全区，或顶部安全区 > 20pt）由系统 safeArea 管理导航栏位置，
/// 不应再按传统非全面屏（20pt 状态栏 + 44pt 导航栏 = 64pt）强行改写 frame。
- (BOOL)fy_isFullScreenDevice {
    if (!IS_IPHONE) {
        return YES;
    }
    if (@available(iOS 11.0, *)) {
        UIWindow *window = self.window;
        if (!window) {
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *windowScene = (UIWindowScene *)scene;
                    for (UIWindow *w in windowScene.windows) {
                        if (w.isKeyWindow) {
                            window = w;
                            break;
                        }
                    }
                    if (!window && windowScene.windows.count > 0) {
                        window = windowScene.windows.firstObject;
                    }
                    if (window) {
                        break;
                    }
                }
            }
        }
        if (window) {
            UIEdgeInsets insets = window.safeAreaInsets;
            if (insets.bottom > 0 || insets.top > 20.0 || insets.left > 0 || insets.right > 0) {
                return YES;
            }
        }
    }
    CGFloat maxDimension = MAX([[UIScreen mainScreen] bounds].size.width, [[UIScreen mainScreen] bounds].size.height);
    return maxDimension >= 812.0;
}

- (BOOL)fy_isStatusBarHidden {
    if (@available(iOS 13.0, *)) {
        UIWindowScene *windowScene = self.window.windowScene;
        if (windowScene && windowScene.statusBarManager) {
            return windowScene.statusBarManager.isStatusBarHidden;
        }
    }
    return [UIApplication sharedApplication].isStatusBarHidden;
}

/// 注意：必须加 fy_ 前缀，避免覆盖 UIKit UINavigationBar 内部同名私有方法 -statusBarHeight
- (CGFloat)fy_statusBarHeight {
    if (@available(iOS 13.0, *)) {
        UIWindowScene *windowScene = self.window.windowScene;
        if (windowScene && windowScene.statusBarManager) {
            CGFloat height = CGRectGetHeight(windowScene.statusBarManager.statusBarFrame);
            if (height > 0) {
                return height;
            }
        }
    }
    if ([self fy_isFullScreenDevice]) {
        return 0;
    }
    return 20.0;
}

/// 注意：必须加 fy_ 前缀，避免覆盖 UIKit UINavigationBar 内部同名私有方法 -navigationBarHeight
- (CGFloat)fy_navigationBarHeight {
    if (IS_PORTRAIT || !IS_IPHONE) {
        return 44.0;
    } else {
        return 32.0;
    }
}

- (UIEdgeInsets)additionalSafeAreaInsets {
    if ([self fy_isStatusBarHidden] &&
        FYIsIOSVersionGreaterThanOrEqualTo(@"11.0") &&
        self.fixedHeightWhenStatusBarHidden) {
        return ([self fy_isFullScreenDevice]) ? UIEdgeInsetsZero : UIEdgeInsetsMake([self fy_statusBarHeight], 0, 0, 0);
    } else {
        return UIEdgeInsetsZero;
    }
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

- (void)setAdditionalSafeAreaInsetsForViewController:(UIViewController*)viewController {
    if ([viewController respondsToSelector:NSSelectorFromString(@"setAdditionalSafeAreaInsets:")]) {
        [viewController performSelector:NSSelectorFromString(@"setAdditionalSafeAreaInsets:") withObject:[NSValue valueWithUIEdgeInsets:[self additionalSafeAreaInsets]]];
    }
}

#pragma clang diagnostic pop

- (CGSize)sizeThatFits_FixedHeightWhenStatusBarHidden:(CGSize)size
{
    if (![self fy_isFullScreenDevice] &&
        [self fy_isStatusBarHidden] &&
        FYIsIOSVersionGreaterThanOrEqualTo(@"7.0") &&
        self.fixedHeightWhenStatusBarHidden)
    {
        CGSize newSize = CGSizeMake(self.frame.size.width, [self fy_navigationBarHeight] + [self fy_statusBarHeight]);
        return newSize;
    }
    else
    {
        return [self sizeThatFits_FixedHeightWhenStatusBarHidden:size];
    }
}

- (void)setFrame_FixedHeightWhenStatusBarHidden:(CGRect)frame
{
    if (![self fy_isFullScreenDevice] &&
        [self fy_isStatusBarHidden] &&
        FYIsIOSVersionGreaterThanOrEqualTo(@"11.0") &&
        self.fixedHeightWhenStatusBarHidden) {
        frame.size.height = [self fy_navigationBarHeight] + [self fy_statusBarHeight];
    }
    [self setFrame_FixedHeightWhenStatusBarHidden:frame];
}

- (void)layoutSubviews_FixedHeightWhenStatusBarHidden
{
    [self layoutSubviews_FixedHeightWhenStatusBarHidden];
    
    if (![self fy_isFullScreenDevice] &&
        [self fy_isStatusBarHidden] &&
        FYIsIOSVersionGreaterThanOrEqualTo(@"11.0") &&
        self.fixedHeightWhenStatusBarHidden) {
        
        CGRect frame = self.frame;
        frame.size.height = [self fy_navigationBarHeight] + [self fy_statusBarHeight];
        self.frame = frame;
        
        for (UIView *subview in self.subviews) {
            if ([NSStringFromClass([subview class]) containsString:@"BarBackground"]) {
                CGRect subViewFrame = subview.frame;
                subViewFrame.origin.y = 0;
                subViewFrame.size.height = [self fy_navigationBarHeight] + [self fy_statusBarHeight];
                [subview setFrame: subViewFrame];
            }
            if ([NSStringFromClass([subview class]) containsString:@"BarContentView"]) {
                CGRect subViewFrame = subview.frame;
                subViewFrame.origin.y = [self fy_statusBarHeight];
                subViewFrame.size.height = [self fy_navigationBarHeight];
                [subview setFrame: subViewFrame];
            }
        }
    }
}

- (BOOL)fixedHeightWhenStatusBarHidden
{
    return [objc_getAssociatedObject(self, FixedNavigationBarSize) boolValue];
}

- (void)setFixedHeightWhenStatusBarHidden:(BOOL)fixedHeightWhenStatusBarHidden
{
    objc_setAssociatedObject(self, FixedNavigationBarSize,
                             [NSNumber numberWithBool:fixedHeightWhenStatusBarHidden], OBJC_ASSOCIATION_RETAIN);
}

+ (void)load
{
    method_exchangeImplementations(class_getInstanceMethod(self, @selector(sizeThatFits:)),
                                   class_getInstanceMethod(self, @selector(sizeThatFits_FixedHeightWhenStatusBarHidden:)));
    
    method_exchangeImplementations(class_getInstanceMethod(self, @selector(setFrame:)),
                                   class_getInstanceMethod(self, @selector(setFrame_FixedHeightWhenStatusBarHidden:)));
    
    method_exchangeImplementations(class_getInstanceMethod(self, @selector(layoutSubviews)),
                                   class_getInstanceMethod(self, @selector(layoutSubviews_FixedHeightWhenStatusBarHidden)));
}

@end
