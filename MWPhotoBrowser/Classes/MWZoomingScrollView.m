//
//  ZoomingScrollView.m
//  MWPhotoBrowser
//
//  Created by Michael Waterfall on 14/10/2010.
//  Copyright 2010 d3i. All rights reserved.
//

#import "RBSScreen.h"
#import "RBSFrame.h"
#import "MWZoomingScrollView.h"
#import "MWPhotoBrowser.h"
#import "MWPhoto.h"

// Declare private methods of browser
@interface MWPhotoBrowser ()
- (UIImage *)imageForPhoto:(id<MWPhoto>)photo;
- (void)cancelControlHiding;
- (void)hideControlsAfterDelay;
@end

// Private methods and properties
@interface MWZoomingScrollView ()
@property (nonatomic, assign) MWPhotoBrowser *photoBrowser;
- (void)handleSingleTap:(CGPoint)touchPoint;
- (void)handleDoubleTap:(CGPoint)touchPoint;

// Comic reader extensions
@property (readonly) RBSScreen *screen;
- (CGPoint)relativeImagePoint:(CGPoint)absolutePoint;
- (CGRect)absoluteImageRect:(CGRect)relativeRect;
@end

@implementation MWZoomingScrollView

@synthesize photoBrowser = _photoBrowser, photo = _photo, captionView = _captionView, currentFrameIndex = _currentFrameIndex;

- (id)initWithPhotoBrowser:(MWPhotoBrowser *)browser {
    if ((self = [super init])) {
        
        // Delegate
        self.photoBrowser = browser;
        
		// Tap view for background
		_tapView = [[MWTapDetectingView alloc] initWithFrame:self.bounds];
		_tapView.tapDelegate = self;
		_tapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		_tapView.backgroundColor = [UIColor clearColor];
		[self addSubview:_tapView];
		
		// Image view
		_photoImageView = [[MWTapDetectingImageView alloc] initWithFrame:CGRectZero];
		_photoImageView.tapDelegate = self;
		_photoImageView.contentMode = UIViewContentModeCenter;
		_photoImageView.backgroundColor = [UIColor clearColor];
		[self addSubview:_photoImageView];
		
		// Spinner
		_spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
		_spinner.hidesWhenStopped = YES;
		_spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
		[self addSubview:_spinner];
		
		// Setup
		self.backgroundColor = [UIColor clearColor];
		self.delegate = self;
		self.showsHorizontalScrollIndicator = NO;
		self.showsVerticalScrollIndicator = NO;
		self.decelerationRate = UIScrollViewDecelerationRateFast;
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
    }
    return self;
}

- (void)dealloc {
	[_tapView release];
	[_photoImageView release];
	[_spinner release];
    [_photo release];
    [_captionView release];
	[super dealloc];
}

- (void)setPhoto:(id<MWPhoto>)photo {
    _photoImageView.image = nil; // Release image
    if (_photo != photo) {
        [_photo release];
        _photo = [photo retain];
    }
    [self displayImage];
}

- (void)prepareForReuse {
    self.photo = nil;
    [_captionView removeFromSuperview];
    self.captionView = nil;
}

#pragma mark - Image

// Get and display image
- (void)displayImage {
	if (_photo && _photoImageView.image == nil) {
		
		// Reset
		self.maximumZoomScale = 1;
		self.minimumZoomScale = 1;
		self.zoomScale = 1;
		self.contentSize = CGSizeMake(0, 0);
		
		// Get image from browser as it handles ordering of fetching
		UIImage *img = [self.photoBrowser imageForPhoto:_photo];
		if (img) {
			
			// Hide spinner
			[_spinner stopAnimating];
			
			// Set image
			_photoImageView.image = img;
			_photoImageView.hidden = NO;
			
			// Setup photo frame
			CGRect photoImageViewFrame;
			photoImageViewFrame.origin = CGPointZero;
			photoImageViewFrame.size = img.size;
			_photoImageView.frame = photoImageViewFrame;
			self.contentSize = photoImageViewFrame.size;
            
			// Set zoom to minimum zoom
            [self setMaxMinZoomScalesForCurrentBounds];
            
            // Set background color if set on the screen
            UIColor *backgroundColor = [self.screen backgroundColor];
            _photoImageView.backgroundColor = backgroundColor;
            self.backgroundColor = backgroundColor;
			
		} else {
			
			// Hide image view
			_photoImageView.hidden = YES;
			[_spinner startAnimating];
			
		}
		[self setNeedsLayout];
	}
}

// Image failed so just show black!
- (void)displayImageFailure {
	[_spinner stopAnimating];
}

#pragma mark - Setup

- (void)setMaxMinZoomScalesForCurrentBounds {
	
	// Reset
	self.maximumZoomScale = 1;
	self.minimumZoomScale = 1;
	self.zoomScale = 1;
	
	// Bail
	if (_photoImageView.image == nil) return;
	
	// Sizes
    CGSize boundsSize = self.bounds.size;
    CGSize imageSize = _photoImageView.image.size;
    
    // Calculate Min
    CGFloat xScale = boundsSize.width / imageSize.width;    // the scale needed to perfectly fit the image width-wise
    CGFloat yScale = boundsSize.height / imageSize.height;  // the scale needed to perfectly fit the image height-wise
    CGFloat minScale = MIN(xScale, yScale);                 // use minimum of these to allow the image to become fully visible
	
	// If image is smaller than the screen then ensure we show it at
	// min scale of 1
	if (xScale > 1 && yScale > 1) {
		minScale = 1.0;
	}
    
	// Calculate Max
	CGFloat maxScale = 2.0; // Allow double scale
    // on high resolution screens we have double the pixel density, so we will be seeing every pixel if we limit the
    // maximum zoom scale to 0.5.
	if ([UIScreen instancesRespondToSelector:@selector(scale)]) {
		maxScale = maxScale / [[UIScreen mainScreen] scale];
	}
	
	// Set
    if (self.photoBrowser.zoomMode == RBSZoomModeWidth) {
        self.maximumZoomScale = xScale;
        self.minimumZoomScale = xScale;
        self.zoomScale = xScale;
    }
    else {
        self.maximumZoomScale = maxScale;
        self.minimumZoomScale = minScale;
        self.zoomScale = minScale;
    }
	
	// Reset position
	_photoImageView.frame = CGRectMake(0, 0, _photoImageView.frame.size.width, _photoImageView.frame.size.height);
	[self setNeedsLayout];

}

#pragma mark - Layout

- (void)layoutSubviews {
    
	// Update tap view frame
	_tapView.frame = self.bounds;
	
	// Spinner
	if (!_spinner.hidden) _spinner.center = CGPointMake(floorf(self.bounds.size.width/2.0),
													  floorf(self.bounds.size.height/2.0));
	// Super
	[super layoutSubviews];
	
    // Center the image as it becomes smaller than the size of the screen
    CGSize boundsSize = self.bounds.size;
    CGRect frameToCenter = _photoImageView.frame;
    
    if (self.photoBrowser.zoomMode == RBSZoomModePage) {
        self.contentInset = UIEdgeInsetsZero;
        
        // Horizontally
        if (frameToCenter.size.width < boundsSize.width) {
            frameToCenter.origin.x = floorf((boundsSize.width - frameToCenter.size.width) / 2.0);
        } else {
            frameToCenter.origin.x = 0;
        }
        
        // Vertically
        if (frameToCenter.size.height < boundsSize.height) {
            frameToCenter.origin.y = floorf((boundsSize.height - frameToCenter.size.height) / 2.0);
        } else {
            frameToCenter.origin.y = 0;
        }
        
        // Center
        if (!CGRectEqualToRect(_photoImageView.frame, frameToCenter))
            _photoImageView.frame = frameToCenter;
        
    }
    else if (self.photoBrowser.zoomMode == RBSZoomModeWidth) {
        _photoImageView.frame = CGRectMake(0, 0, _photoImageView.frame.size.width, _photoImageView.frame.size.height);
    }
    else {
        [self zoomToCurrentFrame];
    }
}

#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
	return _photoImageView;
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
	[_photoBrowser cancelControlHiding];
}

- (void)scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(UIView *)view {
	[_photoBrowser cancelControlHiding];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
	[_photoBrowser hideControlsAfterDelay];
}

#pragma mark - Tap Detection

- (void)handleSingleTap:(CGPoint)touchPoint {
	[_photoBrowser performSelector:@selector(toggleControls) withObject:nil afterDelay:0.2];
}

- (void)handleDoubleTap:(CGPoint)touchPoint {
	
	// Cancel any single tap handling
	[NSObject cancelPreviousPerformRequestsWithTarget:_photoBrowser];
	
    [self.photoBrowser toggleZoomMode];
    [self setMaxMinZoomScalesForCurrentBounds];
    
    // Adjust current view depending on new zoom mode
    if (self.photoBrowser.zoomMode == RBSZoomModeWidth) {
        self.contentOffset = CGPointZero;
    }
	if (self.photoBrowser.zoomMode == RBSZoomModeFrame) {
        
		// Find a frame under touch location
        NSInteger index = [self.screen indexOfFrameAtPoint:[self relativeImagePoint:touchPoint]];
        if (index != -1) {
            self.currentFrameIndex = index;
            [self zoomToCurrentFrame];
        }
        
	}
	
	// Delay controls
	[_photoBrowser hideControlsAfterDelay];
}

// Image View
- (void)imageView:(UIImageView *)imageView singleTapDetected:(UITouch *)touch { 
    [self handleSingleTap:[touch locationInView:imageView]];
}
- (void)imageView:(UIImageView *)imageView doubleTapDetected:(UITouch *)touch {
    [self handleDoubleTap:[touch locationInView:imageView]];
}

// Background View
- (void)view:(UIView *)view singleTapDetected:(UITouch *)touch {
    [self handleSingleTap:[touch locationInView:view]];
}
- (void)view:(UIView *)view doubleTapDetected:(UITouch *)touch {
    [self handleDoubleTap:[touch locationInView:view]];
}

#pragma mark - Comic reader extensions

- (RBSScreen *)screen
{
    return (RBSScreen *) self.photo;
}

// Convert absolute screen coordinate to a image-level position where
// both coordinates are between 0 and 1
- (CGPoint)relativeImagePoint:(CGPoint)absolutePoint
{
    CGSize size = _photoImageView.image.size;
    CGAffineTransform t = CGAffineTransformMakeScale(1/size.width, 1/size.height);
    return CGPointApplyAffineTransform(absolutePoint, t);
}

- (CGRect)absoluteImageRect:(CGRect)relativeRect
{
    CGSize size = _photoImageView.image.size;
    CGAffineTransform t = CGAffineTransformMakeScale(size.width, size.height);
    return CGRectApplyAffineTransform(relativeRect, t);
}

- (void)zoomToCurrentFrame
{
    // Allows centering of image edges
    self.contentInset = UIEdgeInsetsMake(240, 240, 240, 240);

    // Reset image position (fixes weird offset problems when zooming)
    _photoImageView.frame = CGRectMake(0, 0, _photoImageView.frame.size.width, _photoImageView.frame.size.height);
    
    RBSFrame *frame = self.screen.frames[self.currentFrameIndex];
    CGRect rect = [self absoluteImageRect:frame.rect];
    
    if (frame.transitionDuration > 0) {
        [UIView animateWithDuration:frame.transitionDuration animations:^{
            [self zoomToRect:rect animated:NO];
        }];
    }
    else {
        [self zoomToRect:rect animated:NO];
    }
}

- (void)jumpToNextFrame
{
    if (self.currentFrameIndex < self.lastFrameIndex) {
        self.currentFrameIndex += 1;
        [self zoomToCurrentFrame];
    }
}

- (void)jumpToPreviousFrame
{
    if (self.currentFrameIndex > 0) {
        self.currentFrameIndex -= 1;
        [self zoomToCurrentFrame];
    }
}

- (NSInteger)lastFrameIndex
{
    return self.screen.numFrames - 1;
}

- (BOOL)isShowingFirstFrame
{
    return self.currentFrameIndex == 0;
}

- (BOOL)isShowingLastFrame
{
    return self.currentFrameIndex == self.lastFrameIndex;
}

- (CGFloat)imageWidthZoomScale
{
    CGSize boundsSize = self.bounds.size;
    CGSize imageSize = _photoImageView.image.size;
    
    return boundsSize.width / imageSize.width;
}

@end
