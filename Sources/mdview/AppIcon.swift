import AppKit

enum AppIcon {
    /// Creates a document-style icon with "MD" text
    static func create(size: CGFloat = 512) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))

        image.lockFocus()

        let scale = size / 512.0

        // Document shape with folded corner
        let docPath = NSBezierPath()
        let margin: CGFloat = 40 * scale
        let foldSize: CGFloat = 100 * scale
        let cornerRadius: CGFloat = 24 * scale

        let docRect = NSRect(
            x: margin,
            y: margin,
            width: size - margin * 2,
            height: size - margin * 2
        )

        // Key points for document shape
        let bottomLeft = NSPoint(x: docRect.minX, y: docRect.minY + cornerRadius)
        let topRight = NSPoint(x: docRect.maxX - foldSize, y: docRect.maxY)
        let foldPoint = NSPoint(x: docRect.maxX, y: docRect.maxY - foldSize)

        docPath.move(to: bottomLeft)

        // Left edge with rounded bottom-left corner
        docPath.appendArc(
            withCenter: NSPoint(x: docRect.minX + cornerRadius, y: docRect.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: 180,
            endAngle: 270,
            clockwise: false
        )

        // Bottom edge with rounded bottom-right corner
        docPath.line(to: NSPoint(x: docRect.maxX - cornerRadius, y: docRect.minY))
        docPath.appendArc(
            withCenter: NSPoint(x: docRect.maxX - cornerRadius, y: docRect.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: 270,
            endAngle: 0,
            clockwise: false
        )

        // Right edge up to fold
        docPath.line(to: foldPoint)

        // Fold diagonal
        docPath.line(to: topRight)

        // Top edge with rounded top-left corner
        docPath.line(to: NSPoint(x: docRect.minX + cornerRadius, y: docRect.maxY))
        docPath.appendArc(
            withCenter: NSPoint(x: docRect.minX + cornerRadius, y: docRect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: 90,
            endAngle: 180,
            clockwise: false
        )

        docPath.close()

        // Draw shadow
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowOffset = NSSize(width: 0, height: -8 * scale)
        shadow.shadowBlurRadius = 16 * scale
        shadow.set()

        // Fill document background
        NSColor.white.setFill()
        docPath.fill()

        // Remove shadow for subsequent drawing
        NSShadow().set()

        // Draw fold triangle (darker shade)
        let foldPath = NSBezierPath()
        foldPath.move(to: topRight)
        foldPath.line(to: foldPoint)
        foldPath.line(to: NSPoint(x: docRect.maxX - foldSize, y: docRect.maxY - foldSize))
        foldPath.close()

        NSColor(white: 0.85, alpha: 1.0).setFill()
        foldPath.fill()

        // Draw "MD" text
        let fontSize: CGFloat = 160 * scale
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)

        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)
        ]

        let text = "MD" as NSString
        let textSize = text.size(withAttributes: textAttributes)

        let textX = (size - textSize.width) / 2
        let textY = (size - textSize.height) / 2 - 20 * scale

        text.draw(at: NSPoint(x: textX, y: textY), withAttributes: textAttributes)

        // Draw subtle document border
        NSColor(white: 0.8, alpha: 1.0).setStroke()
        docPath.lineWidth = 1 * scale
        docPath.stroke()

        image.unlockFocus()

        return image
    }

    /// Sets the application icon
    static func setAsAppIcon() {
        NSApp.applicationIconImage = create()
    }
}
