import UIKit

#if !os(macOS)
// Compatibility shims for iOS SDKs < 26.0 (Xcode 16 and earlier)
@objc(UIGlassEffect)
public class UIGlassEffect: UIVisualEffect {
    @objc public enum Style: Int {
        case regular = 0
        case clear = 1
    }
    @objc public var isInteractive: Bool = false
    @objc public var tintColor: UIColor?
    @objc public init(style: Style) {
        super.init()
    }
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

@objc(UIGlassContainerEffect)
public class UIGlassContainerEffect: UIVisualEffect {
    @objc public var spacing: CGFloat = 0.0
    public override init() {
        super.init()
    }
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
#endif
