import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum QRCodeGenerator {
    static func make(from string: String, scale: CGFloat = 10) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else {
            return UIImage(systemName: "xmark.octagon") ?? UIImage()
        }

        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return UIImage(systemName: "xmark.octagon") ?? UIImage()
        }

        return UIImage(cgImage: cgImage)
    }
}
