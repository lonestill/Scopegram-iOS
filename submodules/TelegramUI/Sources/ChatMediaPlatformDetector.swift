import Foundation
import UIKit
import Postbox
import TelegramCore

public enum ClientPlatform: String {
    case ios = "iOS"
    case android = "Android"
    case desktop = "Desktop"
    case web = "Web"
    
    public var badgeText: String {
        return self.rawValue
    }
}

public struct MediaDetectionResult {
    public let platform: ClientPlatform
    public let detail: String
    
    public init(platform: ClientPlatform, detail: String) {
        self.platform = platform
        self.detail = detail
    }
}

public final class ChatMediaPlatformDetector {
    public static var isEnabled: Bool {
        return UserDefaults.standard.object(forKey: "scopegram.detectMediaClient") as? Bool ?? true
    }
    
    public static func detect(for message: Message) -> MediaDetectionResult? {
        guard isEnabled else { return nil }
        
        // 1. Check Voice Messages
        for media in message.media {
            if let file = media as? TelegramMediaFile, file.isVoice {
                return detectVoice(file: file)
            }
        }
        
        // 2. Check Round Video Messages (Video Notes)
        for media in message.media {
            if let file = media as? TelegramMediaFile, file.isVideo && file.isInstantVideo {
                return detectVideoNote(file: file)
            }
        }
        
        // 3. Check Photos
        for media in message.media {
            if let image = media as? TelegramMediaImage {
                return detectImage(image: image)
            }
        }
        
        return nil
    }
    
    public static func detectPlatformBadge(for message: Message) -> String? {
        guard let result = detect(for: message) else { return nil }
        return result.platform.badgeText
    }
    
    // MARK: - Voice Message Detection
    
    private static func detectVoice(file: TelegramMediaFile) -> MediaDetectionResult? {
        let mime = file.mimeType.lowercased()
        if mime.contains("webm") || mime.contains("codecs=opus") {
            return MediaDetectionResult(platform: .web, detail: "Web (MediaRecorder container)")
        }
        
        var waveformData: Data?
        var durationSec: Int = 0
        for attribute in file.attributes {
            if case let .Audio(isVoice, duration, _, _, waveform) = attribute, isVoice {
                waveformData = waveform
                durationSec = duration
                break
            }
        }
        
        guard let bitstream = waveformData, !bitstream.isEmpty else {
            if durationSec > 0 {
                return MediaDetectionResult(platform: .web, detail: "Web / Bot (no waveform)")
            }
            return nil
        }
        
        let numSamples = Int(Float(bitstream.count * 8) / 5.0)
        guard numSamples >= 10 else { return nil }
        
        var samples: [Int] = []
        samples.reserveCapacity(numSamples)
        
        let totalBits = bitstream.count * 8
        bitstream.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            for i in 0 ..< numSamples {
                let bitOffset = i * 5
                if bitOffset + 5 <= totalBits {
                    let byteOffset = bitOffset / 8
                    let bitInByte = bitOffset % 8
                    let ptr = baseAddress.advanced(by: byteOffset)
                    var value: UInt32 = 0
                    let bytesToRead = min(4, bitstream.count - byteOffset)
                    memcpy(&value, ptr, bytesToRead)
                    let sample = Int((value >> bitInByte) & 0x1F)
                    samples.append(sample)
                }
            }
        }
        
        guard samples.count >= 10 else { return nil }
        
        var leadingZeros = 0
        for s in samples {
            if s == 0 { leadingZeros += 1 } else { break }
        }
        var trailingZeros = 0
        for s in samples.reversed() {
            if s == 0 { trailingZeros += 1 } else { break }
        }
        
        var maxSample = 0
        var totalZeros = 0
        var totalStep = 0
        var maxStep = 0
        for i in 0 ..< samples.count {
            let s = samples[i]
            if s > maxSample { maxSample = s }
            if s == 0 { totalZeros += 1 }
            if i > 0 {
                let diff = abs(s - samples[i - 1])
                totalStep += diff
                if diff > maxStep { maxStep = diff }
            }
        }
        
        let avgSample = Double(samples.reduce(0, +)) / Double(samples.count)
        let meanDiff = Double(totalStep) / Double(samples.count - 1)
        
        if (leadingZeros >= 2 || trailingZeros >= 2) && meanDiff < 2.5 && maxSample >= 24 {
            return MediaDetectionResult(platform: .ios, detail: "iOS (CoreAudio AGC waveform)")
        }
        if meanDiff >= 2.8 && maxStep >= 12 && totalZeros <= 1 {
            return MediaDetectionResult(platform: .android, detail: "Android (AudioRecord linear RMS)")
        }
        if maxSample <= 18 && avgSample < 6.0 {
            return MediaDetectionResult(platform: .desktop, detail: "Desktop (libopus unamplified input)")
        }
        if totalZeros == 0 && meanDiff < 3.2 {
            return MediaDetectionResult(platform: .android, detail: "Android (NoiseSuppressed AudioRecord)")
        }
        return MediaDetectionResult(platform: .ios, detail: "iOS (AVAudioEngine waveform)")
    }
    
    // MARK: - Video Note Detection
    
    private static func detectVideoNote(file: TelegramMediaFile) -> MediaDetectionResult? {
        var dimensions: CGSize?
        for attribute in file.attributes {
            if case let .Video(_, size, _, _, _, _) = attribute {
                dimensions = CGSize(width: CGFloat(size.width), height: CGFloat(size.height))
                break
            }
        }
        guard let dim = dimensions else { return nil }
        let w = Int(dim.width)
        let h = Int(dim.height)
        
        if (w == 240 && h == 240) || (w == 360 && h == 360) || (w == 480 && h == 480) {
            return MediaDetectionResult(platform: .android, detail: "Android (MediaCodec round note: \(w)x\(h))")
        }
        if w == 400 || h == 400 || w == 384 || h == 384 {
            return MediaDetectionResult(platform: .ios, detail: "iOS (AVFoundation round note: \(w)x\(h))")
        }
        return nil
    }
    
    // MARK: - Photo Detection
    
    private static func detectImage(image: TelegramMediaImage) -> MediaDetectionResult? {
        if image.video != nil || !image.videoRepresentations.isEmpty {
            return MediaDetectionResult(platform: .ios, detail: "iOS (Live Photo)")
        }
        
        guard let maxRep = image.representations.max(by: { $0.dimensions.width * $0.dimensions.height < $1.dimensions.width * $1.dimensions.height }) else {
            return nil
        }
        
        let w = Int(maxRep.dimensions.width)
        let h = Int(maxRep.dimensions.height)
        guard w > 0, h > 0 else { return nil }
        
        let longSide = max(w, h)
        let shortSide = min(w, h)
        let ratio = Double(longSide) / Double(shortSide)
        let isLandscape = w > h
        
        if longSide == 1280 && (shortSide >= 574 && shortSide <= 578) {
            return MediaDetectionResult(platform: .android, detail: "Android (20:9 screen: \(w)x\(h))")
        }
        if ratio >= 2.215 && ratio <= 2.235 {
            return MediaDetectionResult(platform: .android, detail: "Android (20:9 display: \(w)x\(h))")
        }
        if longSide == 1280 && (shortSide >= 558 && shortSide <= 565) {
            return MediaDetectionResult(platform: .android, detail: "Android (20.5:9 Samsung screen: \(w)x\(h))")
        }
        if longSide == 1280 && (shortSide >= 545 && shortSide <= 552) {
            return MediaDetectionResult(platform: .android, detail: "Android (21:9 Sony screen: \(w)x\(h))")
        }
        if longSide == 1280 && (shortSide >= 600 && shortSide <= 610) {
            return MediaDetectionResult(platform: .android, detail: "Android (19:9 screen: \(w)x\(h))")
        }
        
        if longSide == 1280 && (shortSide == 591 || shortSide == 592) {
            return MediaDetectionResult(platform: .ios, detail: "iOS (iPhone 19.5:9 screen: \(w)x\(h))")
        }
        if ratio >= 2.160 && ratio <= 2.174 && (shortSide >= 588 && shortSide <= 595) {
            return MediaDetectionResult(platform: .ios, detail: "iOS (iPhone screen: \(w)x\(h))")
        }
        if longSide == 1280 && (shortSide >= 892 && shortSide <= 896) {
            return MediaDetectionResult(platform: .ios, detail: "iOS (iPad Pro 11\" screen: \(w)x\(h))")
        }
        
        if isLandscape && longSide == 1280 && shortSide == 800 {
            return MediaDetectionResult(platform: .desktop, detail: "Desktop (Mac 16:10 display: 1280x800)")
        }
        if isLandscape && longSide == 1280 && (shortSide >= 533 && shortSide <= 540) {
            return MediaDetectionResult(platform: .desktop, detail: "Desktop (21:9 Ultrawide display: \(w)x\(h))")
        }
        if isLandscape && longSide == 1280 && (shortSide >= 355 && shortSide <= 365) {
            return MediaDetectionResult(platform: .desktop, detail: "Desktop (32:9 Monitor: \(w)x\(h))")
        }
        if isLandscape && longSide == 1280 && shortSide == 720 {
            return MediaDetectionResult(platform: .desktop, detail: "Desktop (16:9 Display: 1280x720)")
        }
        
        if longSide == 1280 && shortSide == 960 {
            if let thumb = image.immediateThumbnailData, !thumb.isEmpty {
                if thumb.count <= 110 {
                    return MediaDetectionResult(platform: .ios, detail: "iOS (Camera 4:3)")
                } else {
                    return MediaDetectionResult(platform: .android, detail: "Android (Camera 4:3)")
                }
            }
        }
        
        return nil
    }
}
