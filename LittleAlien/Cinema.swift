import CoreImage
import SpriteKit

/// Full-screen "console look": soft bloom on everything bright (neon, beam, windows, coins)
/// plus a cinematic grade (richer colour, deeper contrast, cool shadows).
final class CinemaFilter: CIFilter {
    @objc dynamic var inputImage: CIImage?

    override var outputImage: CIImage? {
        guard let img = inputImage else { return nil }
        let extent = img.extent
        // only the brightest parts bloom, so the dark field keeps its contrast
        let bright = img
            .applyingFilter("CIColorControls", parameters: [kCIInputBrightnessKey: -0.25, kCIInputContrastKey: 1.6, kCIInputSaturationKey: 1.3])
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 14])
            .cropped(to: extent)
        let bloomed = bright.applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: img]).cropped(to: extent)
        let mixed = bloomed.applyingFilter("CIDissolveTransition", parameters: [kCIInputTargetImageKey: img, kCIInputTimeKey: 0.55])
        // colour grade
        let graded = mixed
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.14, kCIInputContrastKey: 1.07, kCIInputBrightnessKey: 0.0])
            .applyingFilter("CIVibrance", parameters: ["inputAmount": 0.25])
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1.0, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 1.0, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 1.04, w: 0),
                "inputBiasVector": CIVector(x: -0.005, y: 0, z: 0.012, w: 0)
            ])
        return graded.cropped(to: extent)
    }
}

enum FX {
    static var cinematic: Bool {
        get { UserDefaults.standard.object(forKey: "fxCinematic") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "fxCinematic") }
    }
}
