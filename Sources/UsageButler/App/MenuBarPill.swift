import AppKit
import SwiftUI

enum MenuBarPill {
    static func image(title: String, color: Color) -> NSImage {
        let font = NSFont.systemFont(ofSize: 12, weight: .medium)
        let text = NSAttributedString(string: title, attributes: [.font: font, .foregroundColor: NSColor.white])
        let textSize = text.size()
        let size = NSSize(width: ceil(textSize.width) + 16, height: 20)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor(color).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10).fill()
            text.draw(at: NSPoint(x: 8, y: (rect.height - textSize.height) / 2))
            return true
        }
        image.isTemplate = false
        assert(image.size.width >= textSize.width + 16 && image.size.height == 20 && !image.isTemplate)
        return image
    }
}
