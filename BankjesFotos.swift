import Foundation
import UIKit

/// Foto's van eigen bankjes, bewaard op de iPhone (map "fotos" in Documenten, één JPEG per bankje).
/// De naam van het bestand is het ID van het bankje, dus het `Bench`-model hoeft niet te veranderen.
enum BankjesFotos {
    private static var folder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("fotos", isDirectory: true)
    }

    private static func file(for benchID: String) -> URL {
        folder.appendingPathComponent("\(benchID).jpg")
    }

    static func heeftFoto(voor benchID: String) -> Bool {
        FileManager.default.fileExists(atPath: file(for: benchID).path)
    }

    static func afbeelding(voor benchID: String) -> UIImage? {
        guard let data = try? Data(contentsOf: file(for: benchID)) else { return nil }
        return UIImage(data: data)
    }

    /// Verkleint de foto (langste kant maximaal `KaartStijl.fotoMaxPixels`) en bewaart hem als JPEG.
    @discardableResult
    static func bewaar(_ image: UIImage, voor benchID: String) -> Bool {
        let klein = verkleind(image, maxPixels: KaartStijl.fotoMaxPixels)
        guard let data = klein.jpegData(compressionQuality: KaartStijl.fotoJpegKwaliteit) else { return false }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        do {
            try data.write(to: file(for: benchID), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// Verkleint een foto (langste kant maximaal `KaartStijl.fotoMaxPixels`) tot JPEG-data, klaar om te uploaden.
    static func jpegData(_ image: UIImage) -> Data? {
        verkleind(image, maxPixels: KaartStijl.fotoMaxPixels).jpegData(compressionQuality: KaartStijl.fotoJpegKwaliteit)
    }

    static func verwijder(voor benchID: String) {
        try? FileManager.default.removeItem(at: file(for: benchID))
    }

    private static func verkleind(_ image: UIImage, maxPixels: CGFloat) -> UIImage {
        let grootte = image.size
        let langste = max(grootte.width, grootte.height)
        guard langste > maxPixels else { return image }
        let schaal = maxPixels / langste
        let nieuw = CGSize(width: (grootte.width * schaal).rounded(), height: (grootte.height * schaal).rounded())
        let formaat = UIGraphicsImageRendererFormat()
        formaat.scale = 1   // 1 punt = 1 pixel, zodat het echt maximaal 1200 px is
        return UIGraphicsImageRenderer(size: nieuw, format: formaat).image { _ in
            image.draw(in: CGRect(origin: .zero, size: nieuw))
        }
    }
}
