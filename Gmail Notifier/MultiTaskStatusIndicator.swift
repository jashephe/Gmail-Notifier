import Cocoa

@IBDesignable open class MultiTaskStatusIndicator: NSView {

    fileprivate var borderCircle = CAShapeLayer()
    fileprivate var wedge = CAShapeLayer()
    fileprivate var wedgeGradient = RadialGradientLayer()
    fileprivate var animation: CAKeyframeAnimation = {
        let animation = CAKeyframeAnimation(keyPath: "transform.rotation")
        animation.repeatCount = Float.infinity
        animation.calculationMode = kCAAnimationLinear
        animation.duration = 0.75
        return animation
    }()

    @IBInspectable var borderWeight: CGFloat = 1.5 {
        didSet {
            setupLayers()
        }
    }
    @IBInspectable var wedgeInset: CGFloat = 2 {
        didSet {
            setupLayers()
        }
    }
    @IBInspectable var wedgeAngle: CGFloat = 60 {
        didSet {
            setupLayers()
        }
    }

    fileprivate var animating: Bool = false {
        didSet {
            if animating {
                self.wedge.add(animation, forKey: "rotation")
                self.borderCircle.isHidden = false
                self.wedgeGradient.isHidden = false
            } else {
                self.wedgeGradient.isHidden = true
                self.borderCircle.isHidden = true
                self.wedge.removeAnimation(forKey: "rotation")
            }
        }
    }

    fileprivate var popover: NSPopover = {
        let popover = NSPopover()
        let contentViewController = NSViewController(nibName: nil, bundle: nil)!
        let contentView = NSStackView(frame: NSZeroRect)
        contentView.orientation = .vertical
        contentView.spacing = 3
        contentView.alignment = .leading
        contentViewController.view = contentView
        popover.contentViewController = contentViewController
        popover.behavior = .semitransient
        popover.appearance = NSAppearance(named: NSAppearanceNameVibrantDark)
        return popover
    }()

    override open var intrinsicContentSize: NSSize {
        get {
            return NSMakeSize(21, 21)
        }
    }

    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.commonSetup()
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        self.commonSetup()
    }

    fileprivate func commonSetup() {
        self.wantsLayer = true
        setupLayers()
        self.borderCircle.fillColor = NSColor.clear.cgColor
        self.borderCircle.strokeColor = NSColor.darkGray.cgColor
        self.borderCircle.isHidden = true
        self.layer?.addSublayer(self.borderCircle)

        self.wedgeGradient.setNeedsDisplay()
        self.wedgeGradient.isHidden = true
        self.layer?.addSublayer(self.wedgeGradient)
    }

    fileprivate func setupLayers() {
        self.borderCircle.lineWidth = self.borderWeight
        self.borderCircle.frame = self.bounds
        self.borderCircle.path = NSBezierPath(ovalIn: NSInsetRect(self.borderCircle.bounds, self.borderCircle.lineWidth/2, self.borderCircle.lineWidth/2)).CGPath

        do {
            self.wedgeGradient.frame = NSInsetRect(self.bounds, self.borderWeight + self.wedgeInset, self.borderWeight + self.wedgeInset)
            self.wedge.frame = self.wedgeGradient.bounds
            let path = NSBezierPath()
            path.move(to: NSMakePoint(self.wedge.bounds.size.width/2, self.wedge.bounds.size.height/2))
            path.appendArc(withCenter: NSMakePoint(self.wedge.bounds.size.width/2, self.wedge.bounds.size.height/2), radius: self.wedge.bounds.size.width/2, startAngle: 90 - self.wedgeAngle/2, endAngle: 90 + self.wedgeAngle/2)
            self.wedge.path = path.CGPath

            self.wedgeGradient.mask = self.wedge
        }

        animation.values = [2*M_PI, 0]
    }

    open override func mouseUp(with theEvent: NSEvent) {
        if self.animating && theEvent.modifierFlags.contains(.AlternateKeyMask) && self.convert(theEvent.locationInWindow, from: nil).isInRect(rect: self.bounds) {
            self.popover.show(relativeTo: NSZeroRect, of: self, preferredEdge: .minY)
        }
    }

    fileprivate var statusActions: [String:NSTextField] = [:]
    open func addStatusAction(key theKey: String, label: String) {
        let textLabel = NSTextField(frame: NSZeroRect)
        textLabel.stringValue = label
        textLabel.isBezeled = false
        textLabel.drawsBackground = false
        textLabel.isEditable = false
        textLabel.isSelectable = false
        textLabel.sizeToFit()
        self.statusActions[theKey] = textLabel
        if let stackView = self.popover.contentViewController?.view as? NSStackView {
            stackView.addView(textLabel, in: .top)
            self.animating = true
        }
    }

    open func removeStatusAction(key theKey: String) {
        if let correspondingLabel = self.statusActions[theKey] {
            if let stackView = self.popover.contentViewController?.view as? NSStackView {
                stackView.removeView(correspondingLabel)
            }
            self.statusActions.removeValue(forKey: theKey)
            if self.statusActions.isEmpty {
                self.animating = false
            }
        }
    }
}

private extension NSPoint {
    func isInRect(rect theRect: NSRect) -> Bool {
        return (self.x >= theRect.origin.x && self.x < theRect.origin.x + theRect.size.width) && (self.y >= theRect.origin.y && self.y < theRect.origin.y + theRect.size.height)
    }
}

private class RadialGradientLayer: CALayer {
    var gradientColor = NSColor.darkGray

    override func draw(in ctx: CGContext) {
        let locations: [CGFloat] = [0.0, 0.7, 1.0]

        let colors = [gradientColor.withAlphaComponent(0.0).cgColor, gradientColor.withAlphaComponent(0.8).cgColor, gradientColor.cgColor]

        let colorspace = CGColorSpaceCreateDeviceRGB()

        let gradient = CGGradient(colorsSpace: colorspace, colors: colors as CFArray, locations: locations)

        let startPoint = CGPoint(x: self.bounds.size.width/2, y: self.bounds.size.height/2)
        let endPoint = CGPoint(x: self.bounds.size.width/2, y: self.bounds.size.height/2)
        let startRadius: CGFloat = 0
        let endRadius: CGFloat = min(self.bounds.size.width/2, self.bounds.size.height/2)

        ctx.drawRadialGradient(gradient!, startCenter: startPoint, startRadius: startRadius, endCenter: endPoint, endRadius: endRadius, options: .drawsAfterEndLocation)
    }
}

private extension NSBezierPath {
    var CGPath: CGPath {
        let path = CGMutablePath()

        var points = [NSPoint](repeating: NSZeroPoint, count: 3)
        for index in 0..<self.elementCount {
            switch self.element(at: index, associatedPoints: &points) {
            case .moveToBezierPathElement:
                CGPathMoveToPoint(path, nil, points[0].x, points[0].y)
            case .lineToBezierPathElement:
                CGPathAddLineToPoint(path, nil, points[0].x, points[0].y)
            case .curveToBezierPathElement:
                CGPathAddCurveToPoint(path, nil, points[0].x, points[0].y, points[1].x, points[1].y, points[2].x, points[2].y)
            case .closePathBezierPathElement:
                path.closeSubpath()
            }
        }

        return path
    }
}
