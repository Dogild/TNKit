/*
 * TNSwipeView.j
 *
 * Copyright (C) 2010  Antoine Mercadal <antoine.mercadal@inframonde.eu>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3.0 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

@import <Foundation/Foundation.j>

@import <AppKit/CPView.j>

var CSSProperties = {
    "webkit" : {
        "transform": "WebkitTransform",
        "backfaceVisibility": "WebkitBackfaceVisibility",
        "perspective": "WebkitPerspective",
        "transformStyle": "WebkitTransformStyle",
        "transition": "WebkitTransition",
        "transitionTimingFunction": "WebkitTransitionTimingFunction",
        "transitionEnd": "webkitTransitionEnd"
    },
    "gecko" : {
        "transform": "MozTransform",
        "backfaceVisibility": "MozBackfaceVisibility",
        "perspective": "MozPerspective",
        "transformStyle": "MozTransformStyle",
        "transition": "MozTransition",
        "transitionTimingFunction": "MozTransitionTimingFunction",
        "transitionEnd": "transitionend"
    }
};

TNSwipeViewDirectionRight = 1;
TNSwipeViewDirectionLeft = 2;

TNSwipeViewCSSTranslateFunctionX = @"translateX";
TNSwipeViewCSSTranslateFunctionY = @"translateY";

TNSwipeViewBrowserEngine = (typeof(document.body.style.WebkitTransform) != "undefined") ? "webkit" : "gecko";

/*! @ingroup TNKit
    This widget allows to add custom views in it and swipe them as pages
    Note that is use CSS transformation
*/
@implementation TNSwipeView : CPControl
{
    CPArray     _views                  @accessors(getter=views);
    CPString    _translationFunction    @accessors(getter=translationFunction);
    float       _animationDuration      @accessors(property=animationDuration);

    BOOL        _isAnimating;
    CPPoint     _currentDraggingPoint;
    CPPoint     _generalInitialTrackingPoint;
    CPPoint     _initialTrackingPoint;
    CPView      _mainView;
    Function    _validateFunction;
    int         _currentViewIndex;
}


#pragma mark -
#pragma mark Initialization

/*! initialize the TNFlipView
    @param aRect the frame
*/
- (TNSwipeView)initWithFrame:(CGRect)aRect
{
    if (self = [super initWithFrame:aRect])
    {
        _animationDuration      = 0.3;
        _currentViewIndex       = 0;
        _isAnimating            = NO;
        _mainView               = [[CPView alloc] initWithFrame:[self bounds]];
        _translationFunction    = TNSwipeViewCSSTranslateFunctionX;
        _views                  = [CPArray array];

        _validateFunction       = function(e){
            this.removeEventListener(CSSProperties[TNSwipeViewBrowserEngine].transitionEnd, _validateFunction, YES);
            _mainView._DOMElement.style[CSSProperties[TNSwipeViewBrowserEngine].transition] = "0s";
            [self _commitAnimation];
            _isAnimating = NO;
        };

        [_mainView setAutoresizingMask:CPViewHeightSizable];
        [self addSubview:_mainView];
        [self setNeedsLayout];
    }

    return self;
}

/*! initialize the TNSwipeView
    @param aRect the frame
    @param aFunction the CSS transformation to use
*/
- (TNSwipeView)initWithFrame:(CGRect)aRect translationFunction:(CPString)aFunction
{
    if (self = [self initWithFrame:aRect])
    {
        _translationFunction = aFunction;
    }

    return self
}

#pragma mark -
#pragma mark Getters / Setters

/*! set the content of the TNSwipeView
    @param someViews CPArray containing views
*/
- (void)setViews:(CPArray)someViews
{
    _views = someViews;
    [self setNeedsLayout];
}


#pragma mark -
#pragma mark Overrides

- (void)mouseDown:(CPEvent)anEvent
{
    if (!_isAnimating)
    {
        _initialTrackingPoint = [_mainView convertPointFromBase:[anEvent globalLocation]];
        _generalInitialTrackingPoint = [self convertPointFromBase:[anEvent globalLocation]];
    }
    [super mouseDown:anEvent];
}

- (void)trackMouse:(CPEvent)anEvent
{
    if (!_isAnimating)
    {
        var _currentDraggingPoint = [_mainView convertPointFromBase:[anEvent globalLocation]];

        _mainView._DOMElement.style[CSSProperties[TNSwipeViewBrowserEngine].transition] =  @"0.1s";

        if (_translationFunction == TNSwipeViewCSSTranslateFunctionX)
        {
            _currentDraggingPoint.x -= _initialTrackingPoint.x;
            _mainView._DOMElement.style[CSSProperties[TNSwipeViewBrowserEngine].transform] = _translationFunction + @"("+ _currentDraggingPoint.x + @"px)";
        }
        else
        {
            _currentDraggingPoint.y -= _initialTrackingPoint.y;
            _mainView._DOMElement.style[CSSProperties[TNSwipeViewBrowserEngine].transform] = _translationFunction + @"("+ _currentDraggingPoint.y + @"px)";
        }
    }
    [super trackMouse:anEvent];

}

- (void)stopTracking:(CGPoint)lastPoint at:(CGPoint)aPoint mouseIsUp:(BOOL)mouseIsUp
{
    [super stopTracking:lastPoint at:aPoint mouseIsUp:mouseIsUp];

    if (!mouseIsUp)
        return;

    var movement,
        minimalMovement;

    if (_translationFunction == TNSwipeViewCSSTranslateFunctionX)
    {
        movement = _generalInitialTrackingPoint.x - aPoint.x;
        minimalMovement = [self frameSize].width / 3;
    }
    else
    {
        movement = _generalInitialTrackingPoint.y - aPoint.y;
        minimalMovement = [self frameSize].height / 3;
    }

    if (movement != 0 && Math.abs(movement) >= minimalMovement)
    {
        if (movement < 0)
        {
            if (_currentViewIndex > 0)
            {
                [self _performDirectionalSlide:TNSwipeViewDirectionRight];
                return;
            }
        }
        else
        {
            if (_currentViewIndex < [_views count] - 1)
            {
                [self _performDirectionalSlide:TNSwipeViewDirectionLeft];
                return;
            }
        }
    }
    _isAnimating = NO;
    [self _resetTranslation];
}

- (void)layoutSubviews
{
    if (_translationFunction == TNSwipeViewCSSTranslateFunctionX)
    {
        [_mainView setFrameSize:CPSizeMake([self frameSize].width * [_views count], [self frameSize].height)];
        for (var i = 0; i < [_views count]; i++)
        {
            var currentView = [_views objectAtIndex:i];

            [currentView setFrame:[self bounds]];
            [currentView setFrameOrigin:CPPointMake(i * [self frameSize].width, 0)];
            [_mainView addSubview:currentView];
        }
    }
    else
    {
        [_mainView setFrameSize:CPSizeMake([self frameSize].width, [self frameSize].height * [_views count])];
        for (var i = 0; i < [_views count]; i++)
        {
            var currentView = [_views objectAtIndex:i];

            [currentView setFrame:[self bounds]];
            [currentView setFrameOrigin:CPPointMake(0, i * [self frameSize].height)];
            [_mainView addSubview:currentView];
        }
    }
}


#pragma mark -
#pragma mark Utilities

/*! @ignore
*/
- (void)_setSlideValue:(float)a_performDirectionalSlideValue
{
    if (a_performDirectionalSlideValue == 0)
        return;

    _isAnimating = YES;
    _mainView._DOMElement.style[CSSProperties[TNSwipeViewBrowserEngine].transition] = _animationDuration + @"s";
    _mainView._DOMElement.addEventListener(CSSProperties[TNSwipeViewBrowserEngine].transitionEnd,  _validateFunction, YES);
    _mainView._DOMElement.style[CSSProperties[TNSwipeViewBrowserEngine].transform] = _translationFunction + @"(" + a_performDirectionalSlideValue  + @"px)";
}

/*! _performDirectionalSlide directly to the current view index. If anIndex is
    greater than the actual number of views, last view will be selected
    if anIndex is lesser than 0, then the first view will be selected
    @param anIndex the index of the view to display
*/
- (void)slideToViewIndex:(int)anIndex
{
    if (anIndex == _currentViewIndex)
        return;

    if (anIndex > [_views count] - 1)
        anIndex == [_views count] - 1;

    if (anIndex < 0)
        anIndex = 0;


    if (anIndex > _currentViewIndex)
    {
        if (_translationFunction == TNSwipeViewCSSTranslateFunctionX)
            [self _setSlideValue:- (anIndex - _currentViewIndex) * [self frameSize].width];
        else
            [self _setSlideValue:- (anIndex - _currentViewIndex) * [self frameSize].height];

    }
    else if (anIndex < _currentViewIndex)
    {
        if (_translationFunction == TNSwipeViewCSSTranslateFunctionX)
            [self _setSlideValue:(_currentViewIndex - anIndex) * [self frameSize].width];
        else
            [self _setSlideValue:(_currentViewIndex - anIndex) * [self frameSize].height];

    }

    _currentViewIndex = anIndex;
}

/*! @ignore
    reset the eventual not commited translation
*/
- (void)_resetTranslation
{
    if (_mainView._DOMElement.style[CSSProperties[TNSwipeViewBrowserEngine].transform] == _translationFunction + "(0px)"
        || _mainView._DOMElement.style[CSSProperties[TNSwipeViewBrowserEngine].transform] == "")
    {
        _isAnimating = NO;
        return;
    }
    _isAnimating = YES;
    _mainView._DOMElement.style[CSSProperties[TNSwipeViewBrowserEngine].transition] = _animationDuration + @"s";
    _mainView._DOMElement.addEventListener(CSSProperties[TNSwipeViewBrowserEngine].transitionEnd,  _validateFunction, YES);
    _mainView._DOMElement.style[CSSProperties[TNSwipeViewBrowserEngine].transform] = _translationFunction + @"(0px)";
}

/*! @ignore
    perform a _performDirectionalSlide by 1 in given direction.
    @param the direction TNSwipeViewDirectionRight, or TNSwipeViewDirectionLeft
*/
- (void)_performDirectionalSlide:(int)aDirection
{
    if (_isAnimating)
        return;

    var offset;
    switch (aDirection)
    {
        case TNSwipeViewDirectionLeft:
            if (_currentViewIndex + 1 < [_views count])
            {
                _currentViewIndex++;
                if (_translationFunction == TNSwipeViewCSSTranslateFunctionX)
                    offset = - [self frameSize].width;
                else
                    offset = - [self frameSize].height;
            }
            else
            {
                _currentViewIndex = 0;
                if (_translationFunction == TNSwipeViewCSSTranslateFunctionX)
                    offset = [self frameSize].width * ([_views count] - 1);
                else
                    offset = [self frameSize].height * ([_views count] - 1);
            }
            break;

        case TNSwipeViewDirectionRight:
            if (_currentViewIndex > 0)
            {
                _currentViewIndex--;
                if (_translationFunction == TNSwipeViewCSSTranslateFunctionX)
                    offset = [self frameSize].width;
                else
                    offset = [self frameSize].height;
            }
            else
            {
                _currentViewIndex = [_views count] - 1;
                if (_translationFunction == TNSwipeViewCSSTranslateFunctionX)
                    offset = - (_currentViewIndex * [self frameSize].width);
                else
                    offset = - (_currentViewIndex * [self frameSize].height);
            }
            break;
    }
    [self _setSlideValue:offset];
}

/*! @ignore
    returns the current translation offset
    @return integer representing the pixel offset
*/
- (int)_currentTranslation
{
    var t = _mainView._DOMElement.style[CSSProperties[TNSwipeViewBrowserEngine].transform];
    t = t.replace(_translationFunction + @"(", @"");
    t = t.replace(@"px)", @"");
    if (t == "")
        t = 0;
    return parseInt(t);
}

/*! @ignore
    commit the current CSS translation by moving the actual
    position of the main view and be reseting the translation offset
*/
- (void)_commitAnimation
{
    [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];

    if (_translationFunction == TNSwipeViewCSSTranslateFunctionX)
    {
        tx = [self _currentTranslation];
        var newX = [_mainView frameOrigin].x + tx;
        [_mainView setFrameOrigin:CPPointMake(newX, 0)];
    }
    else
    {
        ty = [self _currentTranslation];
        var newY = [_mainView frameOrigin].y + ty;
        [_mainView setFrameOrigin:CPPointMake(0, newY)];
    }
    [_mainView removeFromSuperview];
    [self addSubview:_mainView];
    _mainView._DOMElement.style[CSSProperties[TNSwipeViewBrowserEngine].transform] = _translationFunction + @"(0px)";
    _isAnimating = NO;
}


#pragma mark -
#pragma mark Actions

/*! select the next view.
    if current view is the last one, first view will be selected
    @param aSender the sender of the action
*/
- (IBAction)nextView:(id)aSender
{
    [self _performDirectionalSlide:TNSwipeViewDirectionLeft];
}

/*! select the previous view.
    if current view is the first one, last view will be selected
    @param aSender the sender of the action
*/
- (IBAction)previousView:(id)aSender
{
    [self _performDirectionalSlide:TNSwipeViewDirectionRight];
}

@end