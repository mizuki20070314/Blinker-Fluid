// SPDX-License-Identifier: GPL-3.0-or-later
#import "BKSheet.h"
#import "BKTheme.h"
#import <objc/runtime.h>

static const void *kTransitionKey = &kTransitionKey;

@interface BKSheetPresentation : UIPresentationController <UIGestureRecognizerDelegate>
@end

@implementation BKSheetPresentation {
  UIView *_dim;
  UIPanGestureRecognizer *_pan;
}

- (CGRect)frameOfPresentedViewInContainerView {
  CGRect bounds = self.containerView.bounds;
  UIEdgeInsets safe = self.containerView.safeAreaInsets;
  CGFloat maxHeight = bounds.size.height - safe.top - 16;
  CGFloat wanted = self.presentedViewController.preferredContentSize.height;
  CGFloat share = bounds.size.width > bounds.size.height ? 0.9 : 0.78;   // never taller than this share of the screen
  CGFloat height = wanted > 0 ? MIN(MIN(wanted, bounds.size.height * share), maxHeight) : MIN(bounds.size.height * 0.62, maxHeight);
  CGFloat width = MIN(bounds.size.width, 520);
  return CGRectMake((bounds.size.width - width) / 2, bounds.size.height - height, width, height);
}

- (void)presentationTransitionWillBegin {
  _dim = [[UIView alloc] initWithFrame:self.containerView.bounds];
  _dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  _dim.backgroundColor = [BKTheme scrim];
  _dim.alpha = 0;
  [_dim addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dimTapped)]];
  [self.containerView insertSubview:_dim atIndex:0];

  UIView *sheet = self.presentedViewController.view;
  sheet.layer.cornerRadius = 16;
  if (@available(iOS 11.0, *)) {
    sheet.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
  }
  sheet.layer.masksToBounds = YES;
  _pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)];
  _pan.delegate = self;
  [sheet addGestureRecognizer:_pan];

  id<UIViewControllerTransitionCoordinator> coordinator = self.presentedViewController.transitionCoordinator;
  if (coordinator) {
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> ctx) { self->_dim.alpha = 1; } completion:nil];
  } else {
    _dim.alpha = 1;
  }
}

- (void)dismissalTransitionWillBegin {
  id<UIViewControllerTransitionCoordinator> coordinator = self.presentedViewController.transitionCoordinator;
  if (coordinator) {
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> ctx) { self->_dim.alpha = 0; } completion:nil];
  } else {
    _dim.alpha = 0;
  }
}

- (void)dismissalTransitionDidEnd:(BOOL)completed {
  if (completed) {
    [_dim removeFromSuperview];
  }
}

- (void)containerViewWillLayoutSubviews {
  _dim.frame = self.containerView.bounds;
  if (!CGAffineTransformIsIdentity(self.presentedView.transform)) {
    return;  // mid-drag
  }
  self.presentedView.frame = [self frameOfPresentedViewInContainerView];
}

- (void)dimTapped {
  [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture {
  if (gesture != _pan) {
    return YES;
  }
  CGPoint p = [gesture locationInView:self.presentedView];
  CGPoint v = [_pan velocityInView:self.presentedView];
  return p.y < 64 && v.y > 0 && fabs(v.y) > fabs(v.x);
}

- (void)panned:(UIPanGestureRecognizer *)pan {
  UIView *sheet = self.presentedView;
  CGFloat dy = MAX([pan translationInView:sheet].y, 0);
  switch (pan.state) {
    case UIGestureRecognizerStateChanged:
      sheet.transform = CGAffineTransformMakeTranslation(0, dy);
      _dim.alpha = MAX(0, 1 - dy / MAX(sheet.bounds.size.height, 1));
      break;
    case UIGestureRecognizerStateEnded:
    case UIGestureRecognizerStateCancelled: {
      CGFloat vy = [pan velocityInView:sheet].y;
      if (dy > 90 || vy > 900) {
        [UIView animateWithDuration:0.2
            animations:^{
              sheet.transform = CGAffineTransformMakeTranslation(0, sheet.bounds.size.height);
              self->_dim.alpha = 0;
            }
            completion:^(BOOL finished) {
              sheet.transform = CGAffineTransformIdentity;
              [self.presentedViewController dismissViewControllerAnimated:NO completion:nil];
            }];
      } else {
        [UIView animateWithDuration:0.25
                              delay:0
             usingSpringWithDamping:0.85
              initialSpringVelocity:0
                            options:0
                         animations:^{
                           sheet.transform = CGAffineTransformIdentity;
                           self->_dim.alpha = 1;
                         }
                         completion:nil];
      }
      break;
    }
    default:
      break;
  }
}

@end

@interface BKSheetAnimator : NSObject <UIViewControllerAnimatedTransitioning>
@property(nonatomic) BOOL presenting;
@end

@implementation BKSheetAnimator

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)ctx {
  return self.presenting ? 0.34 : 0.22;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)ctx {
  UIViewController *to = [ctx viewControllerForKey:UITransitionContextToViewControllerKey];
  UIViewController *from = [ctx viewControllerForKey:UITransitionContextFromViewControllerKey];
  UIView *container = ctx.containerView;
  if (self.presenting) {
    UIView *view = [ctx viewForKey:UITransitionContextToViewKey] ?: to.view;
    CGRect final = [ctx finalFrameForViewController:to];
    view.frame = final;
    view.transform = CGAffineTransformMakeTranslation(0, final.size.height + 8);
    [container addSubview:view];
    [UIView animateWithDuration:[self transitionDuration:ctx]
        delay:0
        usingSpringWithDamping:0.92
        initialSpringVelocity:0
        options:UIViewAnimationOptionCurveEaseOut
        animations:^{ view.transform = CGAffineTransformIdentity; }
        completion:^(BOOL finished) { [ctx completeTransition:!ctx.transitionWasCancelled]; }];
  } else {
    UIView *view = [ctx viewForKey:UITransitionContextFromViewKey] ?: from.view;
    [UIView animateWithDuration:[self transitionDuration:ctx]
        delay:0
        options:UIViewAnimationOptionCurveEaseIn
        animations:^{ view.transform = CGAffineTransformMakeTranslation(0, view.bounds.size.height + 8); }
        completion:^(BOOL finished) {
          view.transform = CGAffineTransformIdentity;
          [ctx completeTransition:!ctx.transitionWasCancelled];
        }];
  }
}

@end

@implementation BKSheetTransition

+ (void)applyToController:(UIViewController *)controller {
  BKSheetTransition *transition = [[BKSheetTransition alloc] init];
  objc_setAssociatedObject(controller, kTransitionKey, transition, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  controller.modalPresentationStyle = UIModalPresentationCustom;
  controller.transitioningDelegate = transition;
}

- (UIPresentationController *)presentationControllerForPresentedViewController:(UIViewController *)presented
                                                      presentingViewController:(UIViewController *)presenting
                                                          sourceViewController:(UIViewController *)source {
  return [[BKSheetPresentation alloc] initWithPresentedViewController:presented presentingViewController:presenting];
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented
                                                                  presentingController:(UIViewController *)presenting
                                                                      sourceController:(UIViewController *)source {
  BKSheetAnimator *animator = [[BKSheetAnimator alloc] init];
  animator.presenting = YES;
  return animator;
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed {
  BKSheetAnimator *animator = [[BKSheetAnimator alloc] init];
  animator.presenting = NO;
  return animator;
}

@end
