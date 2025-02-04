//
//  TGClipView.swift
//  TGUIKit
//
//  Created by keepcoder on 12/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import CoreVideo
import SwiftSignalKit
public class TGClipView: NSClipView,CALayerDelegate {
    
    var border:BorderType? {
        didSet {
            self.layerContentsRedrawPolicy = .onSetNeedsDisplay
            super.needsDisplay = true
             self.layerContentsRedrawPolicy = .never
        }
    }
    
    var displayLink:CVDisplayLink?
    var shouldAnimateOriginChange:Bool = false
    var destinationOrigin:NSPoint?
    
    var backgroundMode: TableBackgroundMode = .plain {
        didSet {
            needsDisplay = true
        }
    }
    
    public override var needsDisplay: Bool {
        set {
            //self.layerContentsRedrawPolicy = .onSetNeedsDisplay
            super.needsDisplay = needsDisplay
           // self.layerContentsRedrawPolicy = .never
        }
        get {
            return super.needsDisplay
        }
    }
    public var _mouseDownCanMoveWindow: Bool = false
    public override var mouseDownCanMoveWindow: Bool {
        return _mouseDownCanMoveWindow
    }
    
    weak var containingScrollView:NSScrollView? {
        
        if let scroll = self.enclosingScrollView {
            return scroll 
        } else {
            if let scroll = self.superview as? NSScrollView {
                return scroll
            }
            
            return nil
        }
        
    }
    var scrollCompletion:((_ success:Bool) ->Void)?
    public var decelerationRate:CGFloat = 0.8
    
    
    public var isScrolling: Bool {
        if let displayLink = displayLink {
            return CVDisplayLinkIsRunning(displayLink)
        }
        return false
    }
    public var destination: NSPoint? {
        return self.destinationOrigin
    }

    override init(frame frameRect: NSRect) {
        
        super.init(frame: frameRect)
        //self.wantsLayer = true
        backgroundColor = .clear
        self.layerContentsRedrawPolicy = .never
      //  self.layer?.drawsAsynchronously = System.drawAsync
        //self.layer?.delegate = self
//        createDisplayLink()

    }
    
    override public static var isCompatibleWithResponsiveScrolling: Bool {
        return true
    }
    
    public override var backgroundColor: NSColor {
        set {
            super.backgroundColor = .clear
        }
        get {
            return .clear
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        
    }
    
//    override public func setNeedsDisplay(_ invalidRect: NSRect) {
//        
//    }
    
    public func draw(_ layer: CALayer, in ctx: CGContext) {
       // ctx.clear(bounds)

        
           // ctx.setFillColor(NSColor.clear.cgColor)
           // ctx.fill(bounds)
        

        if let border = border {
            
            ctx.setFillColor(presentation.colors.border.cgColor)
            
            if border.contains(.Top) {
                ctx.fill(NSMakeRect(0, NSHeight(self.frame) - .borderSize, NSWidth(self.frame), .borderSize))
            }
            if border.contains(.Bottom) {
                ctx.fill(NSMakeRect(0, 0, NSWidth(self.frame), .borderSize))
            }
            if border.contains(.Left) {
                ctx.fill(NSMakeRect(0, 0, .borderSize, NSHeight(self.frame)))
            }
            if border.contains(.Right) {
                ctx.fill(NSMakeRect(NSWidth(self.frame) - .borderSize, 0, .borderSize, NSHeight(self.frame)))
            }
            
        }
    }
    
    private func createDisplayLink() {
        if displayLink != nil {
            return
        }
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let displayLink = displayLink else {
            return
        }
        
        let callback: CVDisplayLinkOutputCallback = { (_, _, _, _, _, userInfo) -> CVReturn in
            let clipView = Unmanaged<TGClipView>.fromOpaque(userInfo!).takeUnretainedValue()
            
            Queue.mainQueue().async {
                clipView.updateOrigin()
            }
            
            return kCVReturnSuccess
        }
        
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(displayLink, callback, userInfo)
    }
    
    deinit {
        endScroll()
        NotificationCenter.default.removeObserver(self)
    }
    
    
    func beginScroll() -> Void {
        createDisplayLink()
        if let displayLink = displayLink {
            if (CVDisplayLinkIsRunning(displayLink)) {
                return
            }
            CVDisplayLinkStart(displayLink)
        }
        
    }
    
    public var isAnimateScrolling:Bool {
        if let displayLink = displayLink {
            if (CVDisplayLinkIsRunning(displayLink)) {
                return true
            }
        }
        if layer?.animation(forKey: "bounds") != nil {
            return true
        }
        return self.point != nil
    }
    
    func endScroll() -> Void {
        if let displayLink = displayLink {
            if (!CVDisplayLinkIsRunning(displayLink)) {
                return;
            }
            CVDisplayLinkStop(displayLink);
        }
        self.displayLink = nil
    }
//    
//    func easeInOutQuad (percentComplete: CGFloat, elapsedTimeMs: CGFloat, startValue: CGFloat, endValue: CGFloat, totalDuration: CGFloat) -> CGFloat {
//        var newElapsedTimeMs = elapsedTimeMs
//        newElapsedTimeMs /= totalDuration/2
//        
//        if newElapsedTimeMs < 1 {
//            return endValue/2*newElapsedTimeMs*newElapsedTimeMs + startValue
//        }
//        newElapsedTimeMs = newElapsedTimeMs - 1
//        return -endValue/2 * ((newElapsedTimeMs)*(newElapsedTimeMs-2) - 1) + startValue
//    }

    public func reset() {
        endScroll()
        if let destinationOrigin = destinationOrigin {
            super.scroll(to: destinationOrigin)
            handleCompletionIfNeeded(withSuccess: false)
        }
    }
    
    public func updateOrigin() -> Void {
        if (self.window == nil) {
            self.reset()
            return;
        }
        
        if let destination = self.destinationOrigin {
            var o:CGPoint = self.bounds.origin;
            let lastOrigin:CGPoint = o;
            
            
            
            o.x = ceil(o.x + (destination.x - o.x) * (1 - self.decelerationRate));
            o.y = ceil(o.y + (destination.y - o.y) * (1 - self.decelerationRate));
            
            
            super.scroll(to: o)
            
            
            // Make this call so that we can force an update of the scroller positions.
      //      self.containingScrollView?.reflectScrolledClipView(self);
            
            if ((abs(o.x - lastOrigin.x) < 1 && abs(o.y - lastOrigin.y) < 1)) {
                self.endScroll()
                super.scroll(to: destination)
                self.handleCompletionIfNeeded(withSuccess: true)
            } else if o == destination {
                self.endScroll()
                self.handleCompletionIfNeeded(withSuccess: true)
            }
        } else {
            endScroll()
        }
        

    }
    
    override public func viewWillMove(toWindow newWindow: NSWindow?) {
//        if let w = newWindow {
//
//            NotificationCenter.default.addObserver(self, selector: #selector(updateCVDisplay), name: NSWindow.didChangeScreenNotification, object: w)
//
//        } else {
//            NotificationCenter.default.removeObserver(self, name: NSWindow.didChangeScreenNotification, object: self.window)
//        }
        
        super.viewWillMove(toWindow: newWindow)
    }
    
//    @objc func updateCVDisplay(_ notification:NSNotification? = nil) -> Void {
//        if let displayLink = displayLink, let _ = NSScreen.main {
//            CVDisplayLinkSetCurrentCGDisplay(displayLink, CGMainDisplayID());
//        }
//    }
    
    
    func scrollRectToVisible(_ rect: NSRect, animated: Bool) -> Bool {
        self.shouldAnimateOriginChange = animated
        return super.scrollToVisible(rect)
    }
    
    func scrollRectToVisible(_ rect: CGRect, animated: Bool, completion: @escaping (Bool) -> Void) -> Bool {
        self.scrollCompletion = completion
        let success = self.scrollRectToVisible(rect, animated: animated)
        if !animated || !success {
            self.handleCompletionIfNeeded(withSuccess: success)
        }
        return success
    }
    
    var documentOffset: NSPoint {
        return self.point ?? self.bounds.origin
    }
        
    private(set) var point: NSPoint?
    
    public func scroll(to point: NSPoint, animated:Bool, completion: @escaping (Bool) -> Void = {_ in})  {
        
        self.scrollCompletion = completion
        self.destinationOrigin = point
        if animated {
            
            self.point = point
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.35
                let timingFunction = CAMediaTimingFunction(controlPoints: 0.5, 1.0 + 0.4 / 3.0, 1.0, 1.0)
                ctx.timingFunction = timingFunction
                self.animator().setBoundsOrigin(point)
            }, completionHandler: {
//                if point != self.bounds.origin, self.point == point {
//                    self.setBoundsOrigin(point)
//                }
                self.destinationOrigin = nil
                self.point = nil
                self.scrollCompletion?(point == self.bounds.origin)
            })
        } else {
            self.setBoundsOrigin(point)
            self.point = nil
            self.destinationOrigin = nil
            self.scrollCompletion?(false)
        }
        
//        self.scrollCompletion?(false)
//        self.shouldAnimateOriginChange = animated
//        self.scrollCompletion = completion
        
//        if animated {
//            self.layer?.removeAllAnimations()
//            beginScroll()
//        }
//        if animated && abs(bounds.minY - point.y) > frame.height {
//            let y:CGFloat
//            if bounds.minY < point.y {
//                y = point.y - floor(frame.height / 2)
//            } else {
//                y = point.y + floor(frame.height / 2)
//            }
//            super.scroll(to: NSMakePoint(point.x,y))
//            DispatchQueue.main.async(execute: { [weak self] in
//                self?.scroll(to: point)
//            })
//        } else {
//            self.scroll(to: point)
//        }
        
    }
    
    public func justScroll(to newOrigin:NSPoint) {
        super.scroll(to: newOrigin)
    }
    
    
    override public func scroll(to newOrigin:NSPoint) -> Void {
        let newOrigin = NSMakePoint(round(newOrigin.x), round(newOrigin.y))
        if (self.shouldAnimateOriginChange) {
            self.shouldAnimateOriginChange = false;
            self.destinationOrigin = newOrigin;
            self.beginScroll()
        } else {
            if !isAnimateScrolling {
                self.destinationOrigin = nil;
                self.endScroll()
                super.scroll(to: newOrigin)
                Queue.mainQueue().justDispatch {
                    self.handleCompletionIfNeeded(withSuccess: true)
                }
            }
        }
        
    }
    
    public override var bounds: NSRect {
        set {
            super.bounds = newValue
        }
        get {
            return super.bounds
        }
    }
    
    
    func handleCompletionIfNeeded(withSuccess success: Bool) {
        self.destinationOrigin = nil
        if self.scrollCompletion != nil {
          //  super.scroll(to: bounds.origin)
            self.scrollCompletion!(success)
            self.scrollCompletion = nil
        }
    }
    
    
    public override func isAccessibilityElement() -> Bool {
        return false
    }
    public override func accessibilityParent() -> Any? {
        return nil
    }
}
