import CoreGraphics

public enum ArtworkTint {
    public static func averageColor(of image: CGImage) -> (r: Double, g: Double, b: Double)? {
        var px = [UInt8](repeating: 0, count: 4)
        guard let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return (Double(px[0]) / 255, Double(px[1]) / 255, Double(px[2]) / 255)
    }
}
