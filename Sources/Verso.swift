//
//  _____ _           _____
// |   __| |_ ___ ___|   __|_ _ ___
// |__   |   | . | . |  |  | | |   |
// |_____|_|_|___|  _|_____|___|_|_|
//               |_|
//
//  Copyright (c) 2016 ShopGun. All rights reserved.

import UIKit


// MARK: - Delegate

public protocol VersoViewDelegate : class {
    
    /// This is triggered whenever the centered pages change, but only once any scrolling or re-layout animation finishes.
    func currentPageIndexesChangedForVerso(verso:VersoView, pageIndexes:NSIndexSet, added:NSIndexSet, removed:NSIndexSet)
    /// This is triggered whenever the visible pages change, whilst the user is scrolling, or after a relayout. This will be called before `currentPageIndexesChanged` callback is triggered.
    func visiblePageIndexesChangedForVerso(verso:VersoView, pageIndexes:NSIndexSet, added:NSIndexSet, removed:NSIndexSet)
    
    /// The user started zooming in/out of the spread containing the specified pages. ZoomScale is the how zoomed in we are when zooming started.
    func didStartZoomingPagesForVerso(verso:VersoView, zoomingPageIndexes:NSIndexSet, zoomScale:CGFloat)
    /// ZoomScale changed - the user is in the process of zooming in/out of the spread containing the specified pages.
    func didZoomPagesForVerso(verso:VersoView, zoomingPageIndexes:NSIndexSet, zoomScale:CGFloat)
    /// The user finished zooming in/out of the spread containing the specified pages. ZoomScale is the how zoomed in we are when zooming finishes.
    func didEndZoomingPagesForVerso(verso:VersoView, zoomingPageIndexes:NSIndexSet, zoomScale:CGFloat)
}

/// Default implementation of delegate does nothing. This makes the delegate methods optional.
public extension VersoViewDelegate {
    func currentPageIndexesChangedForVerso(verso:VersoView, pageIndexes:NSIndexSet, added:NSIndexSet, removed:NSIndexSet) {}
    func visiblePageIndexesChangedForVerso(verso:VersoView, pageIndexes:NSIndexSet, added:NSIndexSet, removed:NSIndexSet) {}
    func didStartZoomingPagesForVerso(verso:VersoView, zoomingPageIndexes:NSIndexSet, zoomScale:CGFloat) {}
    func didZoomPagesForVerso(verso:VersoView, zoomingPageIndexes:NSIndexSet, zoomScale:CGFloat) {}
    func didEndZoomingPagesForVerso(verso:VersoView, zoomingPageIndexes:NSIndexSet, zoomScale:CGFloat) {}
}




// MARK: - DataSource

public protocol VersoViewDataSource : VersoViewDataSourceOptional {
    
    /// The SpreadConfiguration that defines the page count, and layout of the pages, within this verso.
    func spreadConfigurationForVerso(verso:VersoView, size:CGSize) -> VersoSpreadConfiguration
    
    /// Gives the dataSource a chance to configure the pageView. 
    /// This must not take a long time, as it is called during scrolling.
    /// The pageView's `pageIndex` property will have been set, but its size will not be correct
    func configurePageForVerso(verso:VersoView, pageView:VersoPageView)
    
    
    /// What subclass of VersoPageView should be used.
    func pageViewClassForVerso(verso:VersoView, pageIndex:Int) -> VersoPageViewClass
    
}

public protocol VersoViewDataSourceOptional : class {
    /// How many pages before the currently visible pageIndexes to preload. 
    /// Ignored if `preloadPageIndexesForVerso` does not return nil.
    func previousPageCountToPreloadForVerso(verso:VersoView, visiblePageIndexes:NSIndexSet) -> Int
    
    /// How many pages after the currently visible pageIndexes to preload.
    /// Ignored if `preloadPageIndexesForVerso` does not return nil.
    func nextPageCountToPreloadForVerso(verso:VersoView, visiblePageIndexes:NSIndexSet) -> Int
    
    /// Provide a set of indexes to preload around the visible page indexes.
    /// This is for more advanced customization of the preloading indexes.
    /// If nil (default), the next/prev page counts will be used instead.
    func preloadPageIndexesForVerso(verso:VersoView, visiblePageIndexes:NSIndexSet) -> NSIndexSet?
    
    /// What color should the background fade to when zooming.
    func zoomBackgroundColorForVerso(verso:VersoView, zoomingPageIndexes:NSIndexSet) -> UIColor
    
    /// Return a view to overlay over the currently visible pages. 
    /// This is called every time the layout changes, or the user finishes scrolling.
    func spreadOverlayViewForVerso(verso:VersoView, overlaySize:CGSize, pageFrames:[Int:CGRect]) -> UIView?
}

/// Default Values for Optional DataSource
public extension VersoViewDataSourceOptional {
    
    func previousPageCountToPreloadForVerso(verso:VersoView, visiblePageIndexes:NSIndexSet) -> Int {
        return 2
    }
    func nextPageCountToPreloadForVerso(verso:VersoView, visiblePageIndexes:NSIndexSet) -> Int {
        return 6
    }
    func preloadPageIndexesForVerso(verso:VersoView, visiblePageIndexes:NSIndexSet) -> NSIndexSet? {
        return nil
    }
    func zoomBackgroundColorForVerso(verso:VersoView, zoomingPageIndexes:NSIndexSet) -> UIColor {
        return UIColor(white: 0, alpha: 0.7)
    }
    func spreadOverlayViewForVerso(verso:VersoView, overlaySize:CGSize, pageFrames:[Int:CGRect]) -> UIView? {
        return nil
    }
}
/// Have VersoView as the source of the default optional values, for when dataSource is nil.
extension VersoView : VersoViewDataSourceOptional {}



// MARK: -

/// The class that should be sub-classed to build your own pages
public class VersoPageView : UIView {
    public private(set) var pageIndex:Int = NSNotFound
    
    /// make init(frame:) required
    required override public init(frame: CGRect) { super.init(frame: frame) }
    required public init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
    
    public override func sizeThatFits(size: CGSize) -> CGSize {
        return size
    }
}
public typealias VersoPageViewClass = VersoPageView.Type




// MARK: -

public class VersoView : UIView {
    
    // MARK: UIView subclassing
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(pageScrollView)
        
        pageScrollView.addSubview(zoomView)
        
        setNeedsLayout()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    private var performingLayout:Bool = false
    
    override public func layoutSubviews() {
        assert(dataSource != nil, "You must provide a VersoDataSource")
        
        super.layoutSubviews()
        
        
        let newVersoSize = bounds.size
        var newSpreadConfig = spreadConfiguration
        
        
        // get a new spread configuration
        if spreadConfiguration == nil || versoSize != newVersoSize {
            newSpreadConfig = dataSource?.spreadConfigurationForVerso(self, size: newVersoSize)
        }
        
        let willRelayout = versoSize != newVersoSize || spreadConfiguration != newSpreadConfig
        
        
        if willRelayout {
            // move pageViews out of zoomView (without side-effects)
            UIView.performWithoutAnimation { [weak self] in
                self?._resetZoomView()
            }
        }
        
        
        pageScrollView.frame = bounds
        versoSize = newVersoSize
        spreadConfiguration = newSpreadConfig
        
        // there was a change in size or configuration ... relayout
        if willRelayout {
            // recalc all layout states, and update spreads
            _updateSpreadPositions()
            
        }
    }
    
    override public func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        // When Verso is moved to a new superview, reload all the pages.
        // This is basically a 'first-run' event
        if superview != nil {
            reloadPages()
        }
    }
    
    

    
    
    
    /// The datasource for this VersoView. You must set this.
    public weak var dataSource:VersoViewDataSource?
    
    /// The delegate for this Veros. This is optional.
    public weak var delegate:VersoViewDelegate?
    
    
    
    /// The page indexes of the spread that was centered when scrolling animations last ended
    public private(set) var currentPageIndexes:NSIndexSet = NSIndexSet()
    
    /// The page indexes of all the pageViews that are currently visible
    public private(set) var visiblePageIndexes:NSIndexSet = NSIndexSet()
    
    /// The spreadConfiguration provided by the dataSource
    public private(set) var spreadConfiguration:VersoSpreadConfiguration?
    
    
    public var zoomDoubleTapGestureRecognizer:UITapGestureRecognizer? {
        return zoomView.sgn_doubleTapGesture
    }
    
    
    /// This triggers a refetch of info from the dataSource, and all the pageViews are re-configured.
    public func reloadPages() {
        dispatch_async(dispatch_get_main_queue()) { [weak self] in
            guard self != nil else { return }
            
            for (_, pageView) in self!.pageViewsByPageIndex {
                pageView.removeFromSuperview()
            }
            self?.pageViewsByPageIndex = [:]
            
            self?.currentSpreadIndex = nil
            self?.currentPageIndexes = NSIndexSet()
            self?.centeredSpreadIndex = nil
            self?.visiblePageIndexes = NSIndexSet()
            
            self?.spreadConfiguration = nil
            
            self?.setNeedsLayout()
        }
    }
    
    /// Scrolls the VersoView to point to a specific page. This is a no-op if the page doesnt exist.
    public func jumpToPage(pageIndex:Int, animated:Bool) {
        dispatch_async(dispatch_get_main_queue()) { [weak self] in
            
            guard self?.spreadConfiguration != nil else {
                return
            }
            
            if let spreadIndex = self?.spreadConfiguration?.spreadIndexForPageIndex(pageIndex) {
                self?.pageScrollView.setContentOffset(VersoView.calc_scrollOffsetForSpread(spreadIndex, spreadFrames:self!.spreadFrames, versoSize: self!.versoSize), animated: animated)
            }
        }
    }
    
    
    /// This causes all the preloaded pages to be reconfigured by the dataSource
    public func reconfigureVisiblePages() {
        dispatch_async(dispatch_get_main_queue()) { [weak self] in
            guard self != nil else { return }
            for (_, pageView) in self!.pageViewsByPageIndex {
                self!._configurePageView(pageView)
            }
        }
    }
    
    
    /// Return the VersoPageView for a pageIndex, or nil if the pageView is not in memory
    public func getPageViewIfLoaded(pageIndex:Int) -> VersoPageView? {
        return pageViewsByPageIndex[pageIndex]
    }
    
    public func reconfigureSpreadOverlay() {
        dispatch_async(dispatch_get_main_queue()) { [weak self] in
            guard self != nil else { return }
            
            self?._updateSpreadOverlay()
        }
    }
    
    
    
    
    
    
    
    // MARK: - Private Proprties
    
    /// The current size of this VersoView
    private var versoSize:CGSize = CGSizeZero
    
    /// Precalculated frames for all spreads
    private var spreadFrames:[CGRect] = []
    
    /// Precalculated initial (non-resized) frames for all pages
    private var pageFrames:[CGRect] = []
    
    /// the pageIndexes that are embedded in the zoomView
    private var zoomingPageIndexes:NSIndexSet = NSIndexSet()
    
    
    /// the pageViews that are currently being used
    private var pageViewsByPageIndex = [Int:VersoPageView]()

    /// the spreadIndex under the center of the verso (with some magic for first/last spreads)
    private var centeredSpreadIndex:Int?
    private var centeredSpreadPageIndexes:NSIndexSet = NSIndexSet()

    /// the `centeredSpreadIndex` when animation ended
    private var currentSpreadIndex:Int?

    /// the centeredSpreadIndex when we started dragging
    private var dragStartSpreadIndex:Int = 0
    /// the visibleRect when the drag starts
    private var dragStartVisibleRect:CGRect = CGRectZero
    
    /// The background color provided by the datasource when we started zooming.
    private var zoomTargetBackgroundColor:UIColor?
    
    /// A neat trick to allow pure-swift optional protocol methods: http://blog.stablekernel.com/optional-protocol-methods-in-pure-swift
    private var dataSourceOptional: VersoViewDataSourceOptional {
        return dataSource ?? self
    }

    
    
    // MARK: - Spread & PageView Layout
    
    /**
        Re-calc all the spread frames.
        Then recalculates the contentSize & offset of the pageScrollView.
        Finally re-position all the pageViews
     */
    private func _updateSpreadPositions() {
        guard let config = spreadConfiguration else {
            assert(spreadConfiguration != nil, "You must provide a VersoSpreadConfiguration")
            return
        }
        
        
        // figure out which page we should scroll to
        var targetPageIndex = centeredSpreadPageIndexes.firstIndex
        if targetPageIndex == NSNotFound {
            targetPageIndex = 0
        }
        
        
        
        CATransaction.begin() // start a transaction, so we get a completion handler
        
        performingLayout = true
        
        
        // when the layout is complete, move the active page views into the zoomview
        CATransaction.setCompletionBlock { [weak self] in
            
            self?.pageScrollView.scrollEnabled = true
            
            self?._enableZoomingForCurrentPageViews(force: true)
            
            self?.performingLayout = false
            
        }
        
        // remove the overlay
        spreadOverlayView?.removeFromSuperview()
        spreadOverlayView = nil

        
        // disable scrolling
        pageScrollView.scrollEnabled = false
        
        
        // (p)recalculate new frames for all spreads & pages
        spreadFrames = VersoView.calc_spreadFrames(versoSize, spreadConfig: config)
        pageFrames = VersoView.calc_pageFrames(spreadFrames, spreadConfig: config)
        
        
        // update the contentSize to match the new spreadFrames
        pageScrollView.contentSize = VersoView.calc_contentSize(spreadFrames)
        

        // insta-scroll to that spread
        let targetSpreadIndex = config.spreadIndexForPageIndex(targetPageIndex)
        pageScrollView.setContentOffset(VersoView.calc_scrollOffsetForSpread(targetSpreadIndex ?? 0, spreadFrames:spreadFrames, versoSize: versoSize), animated: false)
        
        
        _updateVisiblePageIndexes()
        
        // generate/config any extra pageviews that we might need
        // these will be added/positioned in the pagingScrollView
        _preparePageViews()
        
        
        // update to the current & visible spread index now we have updated the content offset & spreadFrames
        _updateCurrentSpreadIndex()
        
        
        CATransaction.commit()

    }
    
    private func _frameForPageViews(pageIndexes:NSIndexSet) -> CGRect {
        
        var combinedFrame:CGRect?
        for pageIndex in pageIndexes {
            if let pageView = pageViewsByPageIndex[pageIndex] {
                let pageFrame = pageView.frame
                
                combinedFrame = combinedFrame?.union(pageFrame) ?? pageFrame
            }
        }
        
        return combinedFrame ?? CGRectZero
    }
    
    
    /// This handles the creation/re-use and configuration of pageViews. This is triggered whilst the user scrolls.
    private func _preparePageViews() {

        let visibleFrame = pageScrollView.bounds
        
        // generate/config any extra pageviews that we might need
        // these will be added/positioned in the pagingScrollView
        let pageIndexesToPrepare = _pageIndexesToPreloadAround(visiblePageIndexes)
        
        var preparedPageViews = [Int:VersoPageView]()
        
        // page indexes that dont have a view
        let missingPageViewIndexes = NSMutableIndexSet(indexSet: pageIndexesToPrepare)
        // page views that aren't needed anymore
        var recyclablePageViews = [VersoPageView]()
        
        
        // go through all the page views we have, and find out what we need
        for (pageIndex, pageView) in pageViewsByPageIndex {
            
            if pageIndexesToPrepare.containsIndex(pageIndex) == false && zoomingPageIndexes.containsIndex(pageIndex) == false {
                // we have a page view that can be recycled
                    recyclablePageViews.append(pageView)
            } else {
                missingPageViewIndexes.removeIndex(pageIndex)
                preparedPageViews[pageIndex] = pageView
            }
        }
    
        
        
        // get pageviews for all the missing indexes
        for pageIndex in missingPageViewIndexes {
            
            var pageView:VersoPageView? = nil
            
            // get the class of the page at that index
            let pageViewClass:VersoPageViewClass = dataSource?.pageViewClassForVerso(self, pageIndex: pageIndex) ?? VersoPageView.self
            
            // try to find a pageView of the correct type from the recycle bin
            if let recycleIndex = recyclablePageViews.indexOf({ (recyclablePageView:VersoPageView) -> Bool in
                return recyclablePageView.dynamicType === pageViewClass
            }) {
                pageView = recyclablePageViews.removeAtIndex(recycleIndex)
            }
            
            // nothing in the bin - make a new one
            if pageView == nil {
                // need to give new PageViews an initial frame otherwise they fly in from 0,0
                let initialFrame = pageFrames[verso_safe:pageIndex] ?? CGRectZero
                
                pageView = pageViewClass.init(frame:initialFrame)
                pageScrollView.insertSubview(pageView!, belowSubview: zoomView)
            }
            
            pageView!.pageIndex = pageIndex
            _configurePageView(pageView!)
            
            preparedPageViews[pageIndex] = pageView!
        }
        
        
        
        // clean up any unused recyclables
        for pageView in recyclablePageViews {
            pageView.removeFromSuperview()
        }
        
        
        // do final re-positioning of the pageViews
        for (pageIndex, pageView) in preparedPageViews {
            
            if zoomingPageIndexes.containsIndex(pageIndex) == true {
                continue
            }

            pageView.transform = CGAffineTransformIdentity
            pageView.frame = _resizedFrameForPageView(pageView)
            pageView.alpha = 1
            
            
            // find out how far the pageView is from the visible pages
            var indexDist = 0
            if pageView.pageIndex > visiblePageIndexes.lastIndex {
                indexDist = pageView.pageIndex - visiblePageIndexes.lastIndex
            } else if pageView.pageIndex < visiblePageIndexes.firstIndex {
                indexDist = pageView.pageIndex - visiblePageIndexes.firstIndex
            }
            
            // style the non-visible pages
            if indexDist != 0 {
                pageView.alpha = 0
                pageView.transform = CGAffineTransformMakeTranslation(visibleFrame.width/2 * CGFloat(indexDist), 0)
            }
        }

        pageViewsByPageIndex = preparedPageViews
    }
    
    /// Asks the datasource for which pageIndexes around the specified set we should pre-load.
    private func _pageIndexesToPreloadAround(pageIndexes:NSIndexSet)->NSIndexSet {
        guard let config = spreadConfiguration else {
            return NSIndexSet()
        }
        
        guard pageIndexes.count > 0 && config.pageCount > 0 else {
            return NSIndexSet()
        }
        
        // get all the page indexes we are going to config and position, based on delegate callbacks
        let requiredPageIndexes = NSMutableIndexSet(indexSet: pageIndexes)
        
        
        if let preloadIndexes = dataSourceOptional.preloadPageIndexesForVerso(self, visiblePageIndexes: pageIndexes) {
            requiredPageIndexes.addIndexes(preloadIndexes)
        } else {
            if pageIndexes.firstIndex > 0 {
                let beforeCount = dataSourceOptional.previousPageCountToPreloadForVerso(self, visiblePageIndexes: pageIndexes)
                let newFirstIndex = max(pageIndexes.firstIndex-beforeCount, 0)
                requiredPageIndexes.addIndexesInRange(NSMakeRange(newFirstIndex, pageIndexes.firstIndex - newFirstIndex ))
            }
            if pageIndexes.lastIndex < (config.pageCount-1) {
                let afterCount = dataSourceOptional.nextPageCountToPreloadForVerso(self, visiblePageIndexes: pageIndexes)
                let newLastIndex = min(pageIndexes.lastIndex+afterCount, config.pageCount-1)
                requiredPageIndexes.addIndexesInRange(NSMakeRange(pageIndexes.lastIndex+1, newLastIndex - pageIndexes.lastIndex))
            }
        }
        
        return requiredPageIndexes
    }
    
    /// Asks the datasource to configure its pageview (done from preparePageView
    private func _configurePageView(pageView:VersoPageView) {
        if pageView.pageIndex != NSNotFound {
            dataSource?.configurePageForVerso(self, pageView: pageView)
        }
    }
    
    /// ask the pageView for the size that it wants to be (within a max page frame size)
    private func _resizedFrameForPageView(pageView:VersoPageView) -> CGRect {
        
        let maxFrame = pageFrames[pageView.pageIndex]
        let pageSize = pageView.sizeThatFits(maxFrame.size)
        
        
        var pageFrame = maxFrame
        pageFrame.size = pageSize
        pageFrame.origin.y = round(CGRectGetMidY(maxFrame) - pageSize.height/2)
        
        
        let alignment = spreadConfiguration?.pageAlignmentForPage(pageView.pageIndex) ?? .Center
        
        switch alignment {
        case .Left:
            pageFrame.origin.x = CGRectGetMinX(maxFrame)
        case .Right:
            pageFrame.origin.x = CGRectGetMaxX(maxFrame) - pageSize.width
        case .Center:
            pageFrame.origin.x = round(CGRectGetMidX(maxFrame) - pageSize.width/2)
        }
        
        return pageFrame
    }
    
    
    
    
    
    
    
    // MARK: Spread index state
    
    /**
        Do the calculations to figure out which spread we are currently looking at.
        This will also update the centeredSpreadPageIndexes
        This is called while the user scrolls
     */
    private func _updateCenteredSpreadIndex() {
        guard let config = spreadConfiguration else {
            return
        }
        

        var newCenteredSpreadIndex:Int?
        
        // to avoid skipping frames with rounding errors, expand by a few pxs
        let visibleRect = pageScrollView.bounds.insetBy(dx: -2, dy: -2)
        
        if spreadFrames.count == 0 {
            newCenteredSpreadIndex = nil
        }
        else if visibleRect.contains(spreadFrames.first!) {
            // first page is visible - assume first
            newCenteredSpreadIndex = 0
        }
        else if visibleRect.contains(spreadFrames.last!) {
            // last page is visible - assume last
            newCenteredSpreadIndex = spreadFrames.count-1
        }
        else {
            let visibleMid = CGPoint(x:visibleRect.midX, y:visibleRect.midY)
            
            var minIndex = 0
            var maxIndex = spreadFrames.count-1
            
            // binary search which spread is under the center of the visible rect
            var spreadIndex:Int = 0
            while (true) {
                spreadIndex = (minIndex + maxIndex)/2
                
                let spreadFrame = spreadFrames[spreadIndex]
                if spreadFrame.contains(visibleMid) {
                    newCenteredSpreadIndex = spreadIndex
                    break
                } else if (minIndex > maxIndex) {
                    break
                } else {
                    if visibleMid.x < spreadFrame.midX {
                        maxIndex = spreadIndex - 1
                    } else {
                        minIndex = spreadIndex + 1
                    }
                }
            }
            
            if newCenteredSpreadIndex == nil {
                newCenteredSpreadIndex = spreadIndex
            }
        }
        
        centeredSpreadIndex = newCenteredSpreadIndex
        
        centeredSpreadPageIndexes = centeredSpreadIndex != nil ? config.pageIndexesForSpreadIndex(centeredSpreadIndex!) : NSIndexSet()
    }
    
    
    /**
        Updates a separate cache of the centeredSpreadIndex.
        This is called whenever scrolling animations finish.
        Will notify the delegate if there is a change
     */
    private func _updateCurrentSpreadIndex() {
        guard let config = spreadConfiguration else {
            return
        }
        
        _updateCenteredSpreadIndex()
        
        currentSpreadIndex = centeredSpreadIndex
        
        
        // update currentPageIndexes
        let newCurrentPageIndexes = currentSpreadIndex != nil ? config.pageIndexesForSpreadIndex(currentSpreadIndex!) : NSIndexSet()
        
        guard newCurrentPageIndexes.isEqualToIndexSet(currentPageIndexes) == false else {
            return
        }
        
        // calc diff
        let addedIndexes = NSMutableIndexSet(indexSet:newCurrentPageIndexes)
        addedIndexes.removeIndexes(currentPageIndexes)
        
        let removedIndexes = NSMutableIndexSet(indexSet:currentPageIndexes)
        removedIndexes.removeIndexes(newCurrentPageIndexes)
        
        currentPageIndexes = newCurrentPageIndexes
        
        // notify delegate of changes to current page
        delegate?.currentPageIndexesChangedForVerso(self, pageIndexes: currentPageIndexes, added: addedIndexes, removed: removedIndexes)
    }
    
    
    
    private func _updateVisiblePageIndexes() {
        
        let visibleFrame = pageScrollView.bounds
        
        let newVisiblePageIndexes = VersoView.calc_visiblePageIndexesInRect(visibleFrame, pageFrames: pageFrames, fullyVisible: false)

        guard newVisiblePageIndexes.isEqualToIndexSet(visiblePageIndexes) == false else {
            return
        }
        
        // calc diff
        let addedIndexes = NSMutableIndexSet(indexSet:newVisiblePageIndexes)
        addedIndexes.removeIndexes(visiblePageIndexes)
        
        let removedIndexes = NSMutableIndexSet(indexSet:visiblePageIndexes)
        removedIndexes.removeIndexes(newVisiblePageIndexes)
        
        visiblePageIndexes = newVisiblePageIndexes
        
        // notify delegate of changes to current page
        delegate?.visiblePageIndexesChangedForVerso(self, pageIndexes: visiblePageIndexes, added: addedIndexes, removed: removedIndexes)

    }
    
    
    
    
    
    
    
    
    // MARK: - Scrolling Pages
    
    private func _didStartScrolling() {
        // disable scrolling
        zoomView.maximumZoomScale = 1.0
    }
    @objc private func _didFinishScrolling() {
        // dont do any post-scrolling layout if the user rotated the device while scroll-animations were being performed.
        if performingLayout == false {
            _updateCurrentSpreadIndex()
            
            _enableZoomingForCurrentPageViews(force: false)
            
            _updateMaxZoomScale()
        }
    }
    
    
    private func _updateSpreadOverlay() {
        
        
        var spreadPageFrames:[Int:CGRect] = [:]
        for pageIndex in zoomingPageIndexes {
            if let pageView = pageViewsByPageIndex[pageIndex] {
                
                let pageViewFrame = pageView.convertRect(pageView.bounds, toView: zoomViewContents)
                
                spreadPageFrames[pageIndex] = pageViewFrame
            }
        }

        let newSpreadOverlayView = spreadPageFrames.count > 0 ? dataSourceOptional.spreadOverlayViewForVerso(self, overlaySize:zoomViewContents.bounds.size, pageFrames:spreadPageFrames) : nil
        
        if newSpreadOverlayView != spreadOverlayView {
            spreadOverlayView?.removeFromSuperview()
            spreadOverlayView = newSpreadOverlayView
            spreadOverlayView?.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        }
        
        
        if spreadOverlayView != nil {
            zoomViewContents.addSubview(spreadOverlayView!)
            spreadOverlayView?.frame = zoomViewContents.bounds
        }
    }
    
    
    
    
    // MARK: - Zooming
    
    private func _updateMaxZoomScale() {
        // update zoom scale based on the current spread
        if let spreadIndex = currentSpreadIndex,
            let zoomScale = spreadConfiguration?.spreadPropertyForSpreadIndex(spreadIndex)?.maxZoomScale {
            
            zoomView.maximumZoomScale = zoomScale
        } else {
            zoomView.maximumZoomScale = 1.0
        }

    }
    /// Remove all pageViews that are in the zoomView, placing them correctly back in the pageScrollView
    private func _resetZoomView() {
        
        // reset previous zooming pageViews
        for pageIndex in zoomingPageIndexes {            
            if let pageView = pageViewsByPageIndex[pageIndex] {
                pageScrollView.insertSubview(pageView, belowSubview: zoomView)
                
                pageView.transform = CGAffineTransformIdentity
                pageView.frame = _resizedFrameForPageView(pageView)
                pageView.alpha = 1
            }
        }
        
        if zoomView.zoomScale != 1 && zoomingPageIndexes.count > 0 {
            _didStartZooming()
            zoomView.zoomScale = 1.0
            _didEndZooming()
        }
        
        zoomView.maximumZoomScale = 1.0
        zoomView.backgroundColor = UIColor.clearColor()
        zoomingPageIndexes = NSIndexSet()
    }
    
    private var spreadOverlayView:UIView?
    
    /**
     Resets the zoomView to correct location and adds pageviews that will be zoomed
     If `force` is false we will only enable zooming when the page indexes to zoom have changed.
     */
    private func _enableZoomingForCurrentPageViews(force force:Bool) {
        
        guard zoomingPageIndexes != currentPageIndexes || force else {
            return
        }
        
        _resetZoomView()
        
        _updateMaxZoomScale()
        
        // update which pages are zooming
        zoomingPageIndexes = currentPageIndexes
        
        
        // reset the zoomview
        zoomView.zoomScale = 1.0
        zoomView.contentInset = UIEdgeInsetsZero
        zoomView.contentOffset = CGPointZero
        
        // move zoomview visible frame
        zoomView.frame = pageScrollView.bounds
        
        
        // reset the zoomContents to fill the zoomView
        zoomViewContents.frame = zoomView.bounds
        
        
        // get the PageViews that will be in zoomview, and the combined frame for all those views
        var combinedPageFrame = CGRectZero
        
        var activePageViews = [VersoPageView]()
        for pageIndex in zoomingPageIndexes {
            if let pageView = pageViewsByPageIndex[pageIndex] {
                
                activePageViews.append(pageView)
                
                let pageViewFrame = pageView.convertRect(pageView.bounds, toView: zoomView)
                combinedPageFrame = combinedPageFrame==CGRectZero ? pageViewFrame : combinedPageFrame.union(pageViewFrame)
            }
        }
        
        zoomView.contentSize = combinedPageFrame.size
        zoomViewContents.frame = combinedPageFrame
        
        for pageView in activePageViews {
            
            let newPageFrame = zoomViewContents.convertRect(pageView.bounds, fromView: pageView)
            pageView.frame = newPageFrame
            zoomViewContents.addSubview(pageView)
        }
        
        zoomViewContents.frame = CGRect(origin: CGPointZero, size: combinedPageFrame.size)
        
        zoomView.targetContentFrame = combinedPageFrame
        
        _updateSpreadOverlay()
    }
    
    private func _didStartZooming() {
        if zoomingPageIndexes.count > 0 {
            delegate?.didStartZoomingPagesForVerso(self, zoomingPageIndexes: zoomingPageIndexes, zoomScale: zoomView.zoomScale)
            
            zoomTargetBackgroundColor = dataSourceOptional.zoomBackgroundColorForVerso(self, zoomingPageIndexes:zoomingPageIndexes)
        }
    }
    
    private func _didZoom() {
        
        // fade in the zoomView's background as we zoom
        
        if zoomTargetBackgroundColor == nil {
            zoomTargetBackgroundColor = dataSourceOptional.zoomBackgroundColorForVerso(self, zoomingPageIndexes:zoomingPageIndexes)
        }
        
        var maxAlpha:CGFloat = 1.0
        zoomTargetBackgroundColor!.getWhite(nil, alpha: &maxAlpha)
        
        // alpha 0->0.7 zoom 1->1.5
        // x0 + ((x1-x0) / (y1-y0)) * (y-y0)
        let targetAlpha = min(0 + ((maxAlpha-0) / (1.5-1)) * (zoomView.zoomScale-1), maxAlpha)
        zoomView.backgroundColor = zoomTargetBackgroundColor!.colorWithAlphaComponent(targetAlpha)
        
        if zoomingPageIndexes.count > 0 {
            delegate?.didZoomPagesForVerso(self, zoomingPageIndexes: zoomingPageIndexes, zoomScale: zoomView.zoomScale)
        }
    }
    
    private func _didEndZooming() {
        if zoomView.zoomScale <= zoomView.minimumZoomScale + 0.01 {
            pageScrollView.scrollEnabled = true
        }
        else {
            pageScrollView.scrollEnabled = false
        }
        
        
        if zoomingPageIndexes.count > 0 {
            delegate?.didEndZoomingPagesForVerso(self, zoomingPageIndexes: zoomingPageIndexes, zoomScale: zoomView.zoomScale)
        }
    }
    
    
    
    
    
    // MARK: - Subviews
    
    private lazy var pageScrollView:UIScrollView = {
        let view = UIScrollView(frame:self.frame)
        view.delegate = self
        view.decelerationRate = UIScrollViewDecelerationRateFast
        
        return view
    }()
    
    
    private lazy var zoomView:InsetZoomView = {
        let view = InsetZoomView(frame:self.frame)
        
        view.addSubview(self.zoomViewContents)

        
        view.delegate = self
        view.maximumZoomScale = 1.0
        
        view.sgn_enableDoubleTapGestures()
        
        return view
    }()
    
    private lazy var zoomViewContents:UIView = {
        let view = UIView()
        return view
    }()
    
    
}





// MARK: - UIScrollViewDelegate

extension VersoView : UIScrollViewDelegate {
    
    public func scrollViewDidScroll(scrollView: UIScrollView) {
        if scrollView == pageScrollView {
            
            // only update spreadIndex and pageViews during scroll when it was manually triggered
            if scrollView.dragging == true || scrollView.decelerating == true || scrollView.tracking == true {
                _updateCenteredSpreadIndex()
                _updateVisiblePageIndexes()
                _preparePageViews()
            }
            
        }
    }
    
    
    // MARK: Animation
    public func scrollViewDidEndScrollingAnimation(scrollView: UIScrollView) {
        if scrollView == pageScrollView {
            _didFinishScrolling()
        }
    }
    public func scrollViewWillBeginDecelerating(scrollView: UIScrollView) {
        if scrollView == pageScrollView {
            // cancel any delayed didFinishScrolling requests - see `scrollViewDidEndDecelerating`
            NSObject.cancelPreviousPerformRequestsWithTarget(self, selector: #selector(VersoView._didFinishScrolling), object: nil)
        }
    }
    public func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        if scrollView == pageScrollView {
            
            var delay:NSTimeInterval = 0
            // There are some edge cases where, when dragging rapidly, we get a decel finished event, and then a bounce-back decel again
            // In that case (where scrolled out of bounds and decel finished) wait before triggering didEndScrolling
            // We delay rather than just not calling to make sure we dont end up in the situation where didEndScrolling is never called
            if scrollView.bounces && (CGRectGetMaxX(scrollView.bounds) > scrollView.contentSize.width || CGRectGetMinX(scrollView.bounds) < 0 || CGRectGetMaxY(scrollView.bounds) > scrollView.contentSize.height || CGRectGetMinY(scrollView.bounds) < 0) {
                delay = 0.2
            }
            NSObject.cancelPreviousPerformRequestsWithTarget(self, selector: #selector(VersoView._didFinishScrolling), object: nil)
            self.performSelector(#selector(VersoView._didFinishScrolling), withObject: nil, afterDelay: delay)
        }
    }
    
    
    // MARK: Dragging
    
    public func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        if scrollView == pageScrollView {
            
            guard spreadConfiguration?.spreadCount > 0 else {
                return
            }
            
            // calculate the spreadIndex that was centered when  we started this drag
            dragStartSpreadIndex = centeredSpreadIndex ?? 0
            dragStartVisibleRect = scrollView.bounds
            _didStartScrolling()
        }
    }
    public func scrollViewWillEndDragging(scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        if scrollView == pageScrollView {
            guard let config = spreadConfiguration where config.spreadCount > 0 else {
                return
            }
            
            var targetSpreadIndex = centeredSpreadIndex ?? 0
            
            // spread hasnt changed, use velocity to inc/dec spread
            if targetSpreadIndex == dragStartSpreadIndex {
                if velocity.x > 0.5 {
                    targetSpreadIndex += 1
                }
                else if velocity.x < -0.5 {
                    targetSpreadIndex -= 1
                }
                else {
                    // no velocity, so se if the next or prev spreads are a certain % visible
                    let visibleRect = scrollView.bounds
                    
                    let changeOnPercentageVisible:CGFloat = 0.1                    
                    
                    if visibleRect.origin.x > dragStartVisibleRect.origin.x && VersoView.calc_spreadVisibilityPercentage(targetSpreadIndex+1, visibleRect: visibleRect, spreadFrames: spreadFrames) > changeOnPercentageVisible {
                        targetSpreadIndex += 1
                    }
                    else if visibleRect.origin.x < dragStartVisibleRect.origin.x &&  VersoView.calc_spreadVisibilityPercentage(targetSpreadIndex-1, visibleRect: visibleRect, spreadFrames: spreadFrames) > changeOnPercentageVisible {
                        targetSpreadIndex -= 1
                    }
                }
            }
            
            
            
            // clamp targetSpread
            targetSpreadIndex = min(max(targetSpreadIndex, 0), config.spreadCount-1)
            
            // generate offset for the new target spread
            targetContentOffset.memory = VersoView.calc_scrollOffsetForSpread(targetSpreadIndex, spreadFrames: spreadFrames, versoSize: versoSize)
        }
    }
    
    public func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if scrollView == pageScrollView {
            if !decelerate && !scrollView.zoomBouncing {
                _didFinishScrolling()
            }
        }
    }
    
    
    
    
    // MARK: Zooming
    public func scrollViewWillBeginZooming(scrollView: UIScrollView, withView view: UIView?) {
        if scrollView == zoomView {
            _didStartZooming()
        }
    }
    public func scrollViewDidZoom(scrollView: UIScrollView) {
        if scrollView == zoomView {
            
            _didZoom()
        }
    }
    public func scrollViewDidEndZooming(scrollView: UIScrollView, withView view: UIView?, atScale scale: CGFloat) {
        if scrollView == zoomView {
            _didEndZooming()
        }
    }
    public func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        if scrollView == zoomView {
            return zoomViewContents
        }
        return nil
    }
    
}







// MARK: - Layout Utilities

extension VersoView {
    
    /// Calculate all the frames of all the spreads
    private static func calc_spreadFrames(versoSize:CGSize, spreadConfig:VersoSpreadConfiguration) -> [CGRect] {
        
        let spreadSpacing:CGFloat = spreadConfig.spreadSpacing
        
        // recalculate frames for all spreads
        var newSpreadFrames:[CGRect] = []
        
        var prevSpreadFrame = CGRectZero
        for properties in spreadConfig.spreadProperties {
            
            var spreadFrame = CGRectZero
            spreadFrame.size.width = floor(versoSize.width * properties.widthPercentage)
            spreadFrame.size.height = versoSize.height
            spreadFrame.origin.x = CGRectGetMaxX(prevSpreadFrame) + spreadSpacing
            
            newSpreadFrames.append(spreadFrame)
            
            prevSpreadFrame = spreadFrame
        }
        return newSpreadFrames
    }
    
    /// Calculate all the frames of all the pages
    private static func calc_pageFrames(spreadFrames:[CGRect], spreadConfig:VersoSpreadConfiguration) -> [CGRect] {
        
        var pageFrames:[CGRect] = []
        
        for (spreadIndex, spreadFrame) in spreadFrames.enumerate() {
            
            let spreadType = spreadConfig.spreadTypeForSpreadIndex(spreadIndex)
            
            switch spreadType {
            case .Double(_,_):
                var versoPageFrame = spreadFrame
                versoPageFrame.size.width /= 2
                
                var rectoPageFrame = versoPageFrame
                rectoPageFrame.origin.x = versoPageFrame.maxX
                
                pageFrames.append(versoPageFrame)
                pageFrames.append(rectoPageFrame)
                
            case .Single(_):
                pageFrames.append(spreadFrame)
            default:
                break
            }
        }
        
        return pageFrames
    }
    
    
    /// Calculate the size of all the spreads
    private static func calc_contentSize(spreadFrames:[CGRect]) -> CGSize {
        var size = CGSizeZero
        if let lastFrame = spreadFrames.last {
            size.width = CGRectGetMaxX(lastFrame)
            size.height = lastFrame.size.height
        }
        return size
    }
    
    /// Calculate the scroll position of a specific spread
    private static func calc_scrollOffsetForSpread(spreadIndex:Int, spreadFrames:[CGRect], versoSize:CGSize) -> CGPoint {
        
        var offset = CGPointZero
        
        if let spreadFrame = spreadFrames[verso_safe:spreadIndex] {
            
            if spreadIndex == 0 {
                offset.x = spreadFrame.origin.x
            }
            else if spreadIndex == spreadFrames.count-1 {
                offset.x = spreadFrame.maxX - versoSize.width
            }
            else {
                offset.x = spreadFrame.midX - (versoSize.width/2)
            }
        }
        
        return offset
    }
    
    /// Calculate the visibility % of a specific spread within a certain rect
    private static func calc_spreadVisibilityPercentage(spreadIndex:Int, visibleRect:CGRect, spreadFrames:[CGRect]) -> CGFloat {
        
        if let spreadFrame = spreadFrames[verso_safe:spreadIndex] where spreadFrame.width > 0 {
            let spreadIntersection = spreadFrame.intersect(visibleRect)
            
            if spreadIntersection.isEmpty == false {
                return spreadIntersection.width / spreadFrame.width
            }
        }
        
        return 0
    }
    
    /// Calculate which pages are visible within a certain rect. Called frequently.
    private static func calc_visiblePageIndexesInRect(visibleRect:CGRect, pageFrames:[CGRect], fullyVisible:Bool) -> NSIndexSet {
    
        // TODO: optimize?
        
        let visiblePageIndexes = NSMutableIndexSet()
        for (pageIndex, pageFrame) in pageFrames.enumerate() {
            
            if (fullyVisible && visibleRect.contains(pageFrame)) ||
                (!fullyVisible && visibleRect.intersects(pageFrame)){
                visiblePageIndexes.addIndex(pageIndex)
            }
        }
        
        return visiblePageIndexes
    }
    
}





// MARK: - Utility Zooming View subclass
extension VersoView {
    
    // A Utility zooming view that will modify the contentInsets to keep the content matching a target frame
    class InsetZoomView : UIScrollView {
        
        /// This is the frame we wish the contentsView to occupy. contentInset is adjusted to maintain that frame.
        /// If this is nil the contents will be centered
        var targetContentFrame:CGRect? { didSet {
            _updateZoomContentInsets()
            }
        }
        
        override func layoutSublayersOfLayer(layer: CALayer) {
            super.layoutSublayersOfLayer(layer)
            
            _updateZoomContentInsets()
        }
        
        private func _updateZoomContentInsets() {
            
            if let contentView = delegate?.viewForZoomingInScrollView?(self) {
                self.contentInset = _targetedInsets(contentView)
            }
        }
        
        private func _targetedInsets(contentView:UIView) -> UIEdgeInsets {
            
            var edgeInset = UIEdgeInsetsZero
            
            // the goal frame of the contentsView when not zoomed in
            let unscaledTargetFrame = self.targetContentFrame ?? CGRect(origin:CGPointMake(CGRectGetMidX(bounds)-(contentView.bounds.size.width/2), CGRectGetMidY(bounds)-(contentView.bounds.size.height/2)), size:contentView.bounds.size)
            
            // calc what percentage of non-contents space the origin distance is
            var percentageOfRemainingSpace = CGPointZero
            percentageOfRemainingSpace.x = bounds.size.width != unscaledTargetFrame.size.width ? unscaledTargetFrame.origin.x/(bounds.size.width-unscaledTargetFrame.size.width) : 1
            percentageOfRemainingSpace.y = bounds.size.height != unscaledTargetFrame.size.height ? unscaledTargetFrame.origin.y/(bounds.size.height-unscaledTargetFrame.size.height) : 1
            
            
            // scale the contentFrame's origin based on desired percentage of remaining space
            var scaledTargetFrame = contentView.frame
            scaledTargetFrame.origin.x = (bounds.size.width - scaledTargetFrame.size.width) * percentageOfRemainingSpace.x
            scaledTargetFrame.origin.y = (bounds.size.height - scaledTargetFrame.size.height) * percentageOfRemainingSpace.y
            
            
            if bounds.size.height > scaledTargetFrame.size.height {
                edgeInset.top = scaledTargetFrame.origin.y + (bounds.origin.y - contentOffset.y)
            }
            if bounds.size.width > scaledTargetFrame.size.width {
                edgeInset.left = scaledTargetFrame.origin.x + (bounds.origin.x - contentOffset.x)
            }
            
            return edgeInset
        }
    }
}








// MARK: - SpreadConfiguration & Properties

/// This contains all the properties necessary to configure a single spread.
@objc public class VersoSpreadProperty : NSObject {
    let pageIndexes:[Int]
    let maxZoomScale:CGFloat
    let widthPercentage:CGFloat
    
    public init(pageIndexes:[Int], maxZoomScale:CGFloat = 4.0, widthPercentage:CGFloat = 1.0) {
        
        assert(pageIndexes.count <= 2, "VersoSpreadProperties does not currently support more than 2 pages in a spread (\(pageIndexes))")
        assert(pageIndexes.count >= 1, "VersoSpreadProperties does not currently support empty spreads")
        
        self.pageIndexes = pageIndexes
        self.maxZoomScale = max(maxZoomScale, 1.0)
        self.widthPercentage = max(min(widthPercentage, 1.0), 0.0)
    }
    
    
    
    // MARK: Equatable
    override public func isEqual(object: AnyObject?) -> Bool {
        if let object = object as? VersoSpreadProperty {
            if maxZoomScale != object.maxZoomScale || widthPercentage != object.widthPercentage {
                return false
            }
            return pageIndexes == object.pageIndexes
        } else {
            return false
        }
    }
    
    override public var hash: Int {
        return (pageIndexes as NSArray).hashValue ^ maxZoomScale.hashValue ^ widthPercentage.hashValue
    }
}



/// This contains the properties of all the spreads in a VersoView
@objc public class VersoSpreadConfiguration : NSObject {
    public let spreadProperties:[VersoSpreadProperty]
    
    public private(set) var pageCount:Int = 0
    public private(set) var spreadCount:Int = 0
    public private(set) var spreadSpacing:CGFloat = 0
    
    public init(_ spreadProperties:[VersoSpreadProperty], spreadSpacing:CGFloat = 0) {
        self.spreadProperties = spreadProperties
        
        self.spreadCount = spreadProperties.count
        
        // calculate pageCount
        var newPageCount = 0
        for (_, properties) in spreadProperties.enumerate() {
            newPageCount += properties.pageIndexes.count
        }
        self.pageCount = newPageCount
        
        self.spreadSpacing = spreadSpacing
    }
    
    
    func spreadIndexForPageIndex(pageIndex:Int) -> Int? {
        for (spreadIndex, properties) in self.spreadProperties.enumerate() {
            if properties.pageIndexes.contains(pageIndex) {
                return spreadIndex
            }
        }
        return nil
    }
    
    func pageIndexesForSpreadIndex(spreadIndex:Int) -> NSIndexSet {
        let pageIndexes = NSMutableIndexSet()
        
        if let properties = spreadProperties[verso_safe:spreadIndex] {
            for pageIndex in properties.pageIndexes {
                pageIndexes.addIndex(pageIndex)
            }
        }
        return pageIndexes
    }

    func spreadPropertyForSpreadIndex(spreadIndex:Int) -> VersoSpreadProperty? {
        return spreadProperties[verso_safe:spreadIndex]
    }
    func spreadPropertyForPageIndex(pageIndex:Int) -> VersoSpreadProperty? {
        if let spreadIndex = spreadIndexForPageIndex(pageIndex) {
            return spreadPropertyForSpreadIndex(spreadIndex)
        }
        return nil
    }
    
    
    
    // MARK: Equatable
    override public func isEqual(object: AnyObject?) -> Bool {
        if let object = object as? VersoSpreadConfiguration {
            if pageCount != object.pageCount || spreadCount != object.spreadCount {
                return false
            }
            return (spreadProperties as NSArray).isEqualToArray(object.spreadProperties)
        } else {
            return false
        }
    }
    
    override public var hash: Int {
        return (spreadProperties as NSArray).hashValue
    }
}






// MARK: VersoSpreadProperty: Spread Type

extension VersoSpreadProperty {
    
    enum SpreadType {
        case None
        case Single(pageIndex:Int)
        case Double(versoIndex:Int, rectoIndex:Int)
        
        
        // get a set of all the page indexes
        func allPageIndexes() -> NSIndexSet {
            
            let pageIndexes = NSMutableIndexSet()
            switch self {
            case let .Single(pageIndex):
                pageIndexes.addIndex(pageIndex)
            case let .Double(verso, recto):
                pageIndexes.addIndex(verso)
                pageIndexes.addIndex(recto)
            default:break
            }
            return pageIndexes
        }
    }
    
    
    func getSpreadType() -> SpreadType {
        
        if pageIndexes.count == 1 {
            return .Single(pageIndex: pageIndexes[0])
        }
        else if pageIndexes.count == 2 {
            return .Double(versoIndex: pageIndexes[0], rectoIndex: pageIndexes[1])
        }
        else {
            return .None
        }
    }
}

extension VersoSpreadProperty.SpreadType: Equatable { }
func ==(lhs: VersoSpreadProperty.SpreadType, rhs: VersoSpreadProperty.SpreadType) -> Bool {
    switch (lhs, rhs) {
    case (let .Single(pageIndex1), let .Single(pageIndex2)):
        return pageIndex1 == pageIndex2
        
    case (let .Double(verso1, recto1), let .Double(verso2, recto2)):
        return verso1 == verso2 && recto1 == recto2
        
    case (.None, .None):
        return true
        
    default:
        return false
    }
}

extension VersoSpreadConfiguration {
    func spreadTypeForSpreadIndex(spreadIndex:Int) -> VersoSpreadProperty.SpreadType {
        return spreadPropertyForSpreadIndex(spreadIndex)?.getSpreadType() ?? .None
    }
}





// MARK: VersoSpreadProperty: Page Alignment

extension VersoSpreadProperty {
    enum SpreadPageAlignment {
        case Center
        case Left
        case Right
    }
    
    func pageAlignmentForPage(pageIndex:Int) -> SpreadPageAlignment {
        
        guard pageIndexes.contains(pageIndex) else {
            return .Center
        }
        
        let type = getSpreadType()
            
        switch type {
        case let .Double(versoIndex, _) where versoIndex == pageIndex:
            return .Right
        case let .Double(_, rectoIndex) where rectoIndex == pageIndex:
            return .Left
        default:
            return .Center
        }
    }
    
}

extension VersoSpreadConfiguration {
    
    func pageAlignmentForPage(pageIndex:Int) -> VersoSpreadProperty.SpreadPageAlignment {
        if let properties = spreadPropertyForPageIndex(pageIndex) {
            return properties.pageAlignmentForPage(pageIndex)
        }
        return .Center
    }
}








// MARK: Configuration utility constructors

extension VersoSpreadConfiguration {
    
    /// This is a utility configuration builder that helps you construct a SpreadConfiguration.
    public static func buildPageSpreadConfiguration(pageCount:Int, spreadSpacing:CGFloat, spreadPropertyConstructor:((spreadIndex:Int, nextPageIndex:Int)->(spreadPageCount:Int, maxZoomScale:CGFloat, widthPercentage:CGFloat))? = nil) -> VersoSpreadConfiguration {
        
        var spreadProperties:[VersoSpreadProperty] = []
        
        var nextPageIndex = 0
        
        var spreadIndex = 0
        while nextPageIndex < pageCount {
            
            let constructorResults = spreadPropertyConstructor?(spreadIndex:spreadIndex, nextPageIndex:nextPageIndex) ?? (spreadPageCount:1, maxZoomScale:4.0, widthPercentage:1.0)

            
            let lastSpreadPageIndex = min(nextPageIndex + max(constructorResults.spreadPageCount,1) - 1, pageCount - 1)
            
            var pageIndexes:[Int] = []
            for pageIndex in nextPageIndex ... lastSpreadPageIndex {
                pageIndexes.append(pageIndex)
            }
            
            
            let properties = VersoSpreadProperty(pageIndexes: pageIndexes, maxZoomScale:constructorResults.maxZoomScale, widthPercentage:constructorResults.widthPercentage)
            
            spreadProperties.append(properties)
            
            nextPageIndex += pageIndexes.count
            spreadIndex += 1
        }
        

        return VersoSpreadConfiguration(spreadProperties, spreadSpacing: spreadSpacing)
    }
}



// MARK: - Double-Tappable ScrollView

import ObjectiveC

private var doubleTapGestureAssociationKey: UInt8 = 0
private var doubleTapAnimatedAssociationKey: UInt8 = 0

extension UIScrollView {
    /// The double-tap gesture that performs the zoom
    /// This is nil until `sgn_enableDoubleTapGestures` is called
    public private(set) var sgn_doubleTapGesture:UITapGestureRecognizer? {
        get {
            return objc_getAssociatedObject(self, &doubleTapGestureAssociationKey) as? UITapGestureRecognizer
        }
        set(newValue) {
            objc_setAssociatedObject(self, &doubleTapGestureAssociationKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        }
    }
    /// Should the double-tap zoom be animated? Defaults to true
    public var sgn_doubleTapZoomAnimated:Bool {
        get {
            return objc_getAssociatedObject(self, &doubleTapAnimatedAssociationKey) as? Bool ?? true
        }
        set(newValue) {
            objc_setAssociatedObject(self, &doubleTapAnimatedAssociationKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_ASSIGN)
        }
    }
    
    /// This will create, add, and enable, the double-tap gesture to this scrollview.
    public func sgn_enableDoubleTapGestures() {
        var doubleTap = sgn_doubleTapGesture
        if doubleTap == nil {
            doubleTap = UITapGestureRecognizer(target: self, action: #selector(UIScrollView._sgn_didDoubleTap(_:)))
            doubleTap!.numberOfTapsRequired = 2
            
            sgn_doubleTapGesture = doubleTap
        }

        addGestureRecognizer(doubleTap!)
        doubleTap!.enabled = true
    }
    
    /// This will remove and nil-out the double-tap gesture.
    public func sgn_disableDoubleTapGestures() {
        guard let doubleTap = sgn_doubleTapGesture else {
            return
        }
        
        removeGestureRecognizer(doubleTap)
        sgn_doubleTapGesture = nil
    }
    
    
    
    
    
    @objc
    private func _sgn_didDoubleTap(tap:UITapGestureRecognizer) {
        guard tap.state == .Ended else {
            return
        }
        
        // no-op if zoom is disabled
        guard pinchGestureRecognizer != nil && pinchGestureRecognizer!.enabled == true else {
            return
        }
        
        // no zoom, so eject
        guard minimumZoomScale < maximumZoomScale else {
            return
        }
        
        guard let zoomedView = delegate?.viewForZoomingInScrollView?(self) else {
            return
        }
        
        // fake 'willBegin'
        delegate?.scrollViewWillBeginZooming?(self, withView:zoomedView)

        let zoomedIn = zoomScale > minimumZoomScale
        
        
        let zoomAnimations = {
            if zoomedIn {
                // zoomed in - so zoom out again
                self.setZoomScale(self.minimumZoomScale, animated: false)
            }
            else {
                // zoomed out - find the rect we want to zoom to
                let targetScale = self.maximumZoomScale
                let targetCenter = tap.locationInView(zoomedView)
                    //zoomedView.convertPoint(tap.locationInView(self), fromView: self)
                
                var targetZoomRect = CGRectZero
                targetZoomRect.size = CGSize(width: zoomedView.frame.size.width / targetScale,
                                             height: zoomedView.frame.size.height / targetScale)
                
                targetZoomRect.origin = CGPoint(x: targetCenter.x - ((targetZoomRect.size.width / 2.0)),
                                                y: targetCenter.y - ((targetZoomRect.size.height / 2.0)))
                
                self.zoomToRect(targetZoomRect, animated: false)
            }

        }
    
        
        let animated = sgn_doubleTapZoomAnimated
        
        // here we use a custom animation to make zooming faster/nicer
        let duration:NSTimeInterval = zoomedIn ? 0.50 : 0.60;
        let damping:CGFloat = zoomedIn ? 0.9 : 0.8;
        let initialVelocity:CGFloat = zoomedIn ? 0.9 : 0.8;

    
        UIView.animateWithDuration(animated ? duration : 0, delay: 0, usingSpringWithDamping: damping, initialSpringVelocity: initialVelocity, options: [.BeginFromCurrentState], animations: zoomAnimations) { [weak self] finished in
            
            if self != nil && finished {
                // fake 'didZoom'
                self!.delegate?.scrollViewDidEndZooming?(self!, withView:zoomedView, atScale:self!.zoomScale)
            }
        }
    }
}



private extension CollectionType {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (verso_safe index: Index) -> Generator.Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

