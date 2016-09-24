import Cocoa

class AccountCellView: NSTableCellView {

    class var preferredHeight: CGFloat {
        get {
            return 40;
        }
    }

    fileprivate var userImageFrame: NSRect {
        get {
            return NSMakeRect(0, 0, self.frame.size.height, self.frame.size.height)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        Swift.print("Drawing! State is: \(self.backgroundStyle == .dark)")
        if let account: Account = self.objectValue as? Account {
            let inset: CGFloat = 5
            let clipPath = NSBezierPath(roundedRect: NSInsetRect(self.userImageFrame, inset, inset), xRadius: inset, yRadius: inset)
            NSGraphicsContext.saveGraphicsState()
            clipPath.addClip()
            account.profilePicture.draw(in: NSInsetRect(self.userImageFrame, inset, inset), from: NSZeroRect, operation: NSCompositingOperation.sourceOver, fraction: 1.0, respectFlipped: true, hints: nil)
            NSGraphicsContext.restoreGraphicsState()

            let textPadding: CGFloat = 5
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = NSLineBreakMode.byTruncatingTail
            let textColor = (self.backgroundStyle == NSBackgroundStyle.light) ? NSColor.textColor : NSColor.selectedTextColor;
            let labelFont = NSFont.labelFont(ofSize: 13);
            account.userName.draw(in: NSMakeRect(NSWidth(self.userImageFrame) + textPadding, (NSHeight(self.bounds) - NSHeight(labelFont.boundingRectForFont))/2, NSWidth(self.bounds) - NSWidth(self.userImageFrame) - 2*textPadding, NSHeight(labelFont.boundingRectForFont)), withAttributes: [NSForegroundColorAttributeName: textColor, NSFontAttributeName: labelFont, NSParagraphStyleAttributeName: paragraphStyle])
        }
    }
}
