import CoreImage
import SpriteKit

/// Full-screen "console look": soft bloom on everything bright (neon, beam, windows, coins)
/// plus a cinematic grade (richer colour, deeper contrast, cool shadows).
final class CinemaFilter: CIFilter {
    @objc dynamic var inputImage: CIImage?

    override var outputImage: CIImage? {
        guard let img = inputImage else { return nil }
        let extent = img.extent
        // only the brightest parts bloom; blurred at quarter size so it stays cheap at 120 Hz
        let small = img.transformed(by: CGAffineTransform(scaleX: 0.25, y: 0.25))
        let bright = small
            .applyingFilter("CIColorControls", parameters: [kCIInputBrightnessKey: -0.42, kCIInputContrastKey: 2.2, kCIInputSaturationKey: 1.0])
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 4])
            .transformed(by: CGAffineTransform(scaleX: 4, y: 4))
            .cropped(to: extent)
        let glow = bright.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0.55, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0.55, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0.55, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ])
        let bloomed = glow.applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: img]).cropped(to: extent)
        // gentle grade: a touch more contrast and richness, no colour shift
        let graded = bloomed
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.05, kCIInputContrastKey: 1.04, kCIInputBrightnessKey: 0.0])
            .applyingFilter("CIVibrance", parameters: ["inputAmount": 0.12])
        return graded.cropped(to: extent)
    }
}

enum FX {
    static var cinematic: Bool {
        get { UserDefaults.standard.object(forKey: "fxCinematic") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "fxCinematic") }
    }
}
