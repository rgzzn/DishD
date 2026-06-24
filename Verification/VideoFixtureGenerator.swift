import AVFoundation
import CoreGraphics
import CoreText
import CoreVideo
import Foundation

@main
struct VideoFixtureGenerator {
    static func main() async throws {
        let outputURL = URL(fileURLWithPath: "/tmp/dishd-recipe-video.mp4")
        try? FileManager.default.removeItem(at: outputURL)

        let width = 720
        let height = 1_280
        let framesPerSecond: Int32 = 10
        let durationSeconds = 8

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height
            ]
        )
        input.expectsMediaDataInRealTime = false
        let adapter = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )
        guard writer.canAdd(input) else {
            throw FixtureError.writerSetup
        }
        writer.add(input)
        guard writer.startWriting() else {
            throw writer.error ?? FixtureError.writerSetup
        }
        writer.startSession(atSourceTime: .zero)

        let pages = [
            """
            PASTA AL LIMONE
            PER 2 PERSONE

            180 g spaghetti
            1 limone
            30 g parmigiano
            20 g burro
            sale e pepe q.b.
            """,
            """
            PROCEDIMENTO

            Cuoci la pasta.
            Sciogli il burro con
            la scorza di limone.
            Manteca con parmigiano
            e acqua di cottura.
            """
        ]

        for frame in 0..<(durationSeconds * Int(framesPerSecond)) {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(10))
            }
            guard let pool = adapter.pixelBufferPool,
                  let buffer = makePixelBuffer(pool: pool, width: width, height: height)
            else {
                throw FixtureError.pixelBuffer
            }
            draw(
                pages[frame < (durationSeconds * Int(framesPerSecond) / 2) ? 0 : 1],
                in: buffer,
                width: width,
                height: height
            )
            let time = CMTime(value: CMTimeValue(frame), timescale: framesPerSecond)
            guard adapter.append(buffer, withPresentationTime: time) else {
                throw writer.error ?? FixtureError.append
            }
        }

        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw writer.error ?? FixtureError.append
        }
        print(outputURL.path)
    }

    private static func makePixelBuffer(
        pool: CVPixelBufferPool,
        width: Int,
        height: Int
    ) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess else {
            return nil
        }
        return buffer
    }

    private static func draw(
        _ text: String,
        in buffer: CVPixelBuffer,
        width: Int,
        height: Int
    ) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer),
              let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue
              )
        else {
            return
        }

        context.setFillColor(CGColor(red: 0.97, green: 0.94, blue: 0.87, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                kCTFontAttributeName as NSAttributedString.Key:
                    CTFontCreateWithName("Helvetica-Bold" as CFString, 48, nil),
                kCTForegroundColorAttributeName as NSAttributedString.Key:
                    CGColor(red: 0.10, green: 0.18, blue: 0.10, alpha: 1)
            ]
        )
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let path = CGMutablePath()
        path.addRect(CGRect(x: 70, y: 120, width: width - 140, height: height - 240))
        let textFrame = CTFramesetterCreateFrame(
            framesetter,
            CFRange(location: 0, length: attributed.length),
            path,
            nil
        )
        CTFrameDraw(textFrame, context)
    }
}

private enum FixtureError: Error {
    case writerSetup
    case pixelBuffer
    case append
}
