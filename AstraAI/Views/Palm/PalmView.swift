import SwiftData
import SwiftUI
import UIKit
import Vision

/// The four major palmistry lines, each drawn as a single stroke so it can be
/// animated with `.trim` — the "tracing" effect while the scan runs.
enum PalmLine: CaseIterable, Identifiable {
    case heart, head, life, fate

    var id: Self { self }

    var label: String {
        switch self {
        case .heart: "heart line"
        case .head: "head line"
        case .life: "life line"
        case .fate: "fate line"
        }
    }

    /// The line's shape in a normalized unit square: x runs thumb-side (0) to
    /// little-finger-side (1), y runs fingers (0) to wrist (1).
    private var unitPath: Path {
        var p = Path()
        switch self {
        case .heart:
            p.move(to: CGPoint(x: 0.92, y: 0.20))
            p.addQuadCurve(to: CGPoint(x: 0.08, y: 0.26), control: CGPoint(x: 0.5, y: 0.04))
        case .head:
            p.move(to: CGPoint(x: 0.12, y: 0.44))
            p.addQuadCurve(to: CGPoint(x: 0.90, y: 0.42), control: CGPoint(x: 0.5, y: 0.52))
        case .life:
            p.move(to: CGPoint(x: 0.28, y: 0.16))
            p.addQuadCurve(to: CGPoint(x: 0.32, y: 0.95), control: CGPoint(x: 0.00, y: 0.56))
        case .fate:
            p.move(to: CGPoint(x: 0.56, y: 0.96))
            p.addQuadCurve(to: CGPoint(x: 0.50, y: 0.08), control: CGPoint(x: 0.42, y: 0.55))
        }
        return p
    }

    /// Path within `rect` — used for the stylized placeholder illustration, whose
    /// palm is always an upright, axis-aligned block.
    func path(in rect: CGRect) -> Path {
        let t = CGAffineTransform(a: rect.width, b: 0, c: 0, d: rect.height, tx: rect.minX, ty: rect.minY)
        return unitPath.applying(t)
    }

    /// Path mapped through a hand-fitted affine transform — used over a real photo,
    /// so the line follows that specific hand's actual position, size and rotation
    /// instead of an axis-aligned box that ignores how the hand is tilted.
    func path(transform: CGAffineTransform) -> Path {
        unitPath.applying(transform)
    }
}

/// The four lines, trimmed in as `progress` animates 0→1, mapped through `transform`
/// (an axis-aligned box for the placeholder illustration, or a hand-fitted transform
/// over a real photo).
private struct PalmLinesOverlay: View {
    var transform: CGAffineTransform
    var progress: [PalmLine: CGFloat]

    var body: some View {
        ForEach(PalmLine.allCases) { line in
            let amount: CGFloat = progress[line] ?? 0
            let style = StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
            line.path(transform: transform)
                .trim(from: 0, to: amount)
                .stroke(Theme.gold, style: style)
                .shadow(color: Theme.gold.opacity(0.8), radius: 5)
        }
    }
}

/// A stylized, geometric hand shown before any photo is taken — a preview of what
/// the scan will trace.
struct PalmHandView: View {
    var progress: [PalmLine: CGFloat]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let palmRect = CGRect(x: w * 0.14, y: h * 0.48, width: w * 0.72, height: h * 0.45)

            ZStack {
                thumb(w: w, h: h)
                finger(w: w, h: h, x: 0.27, width: 0.15, top: 0.20)
                finger(w: w, h: h, x: 0.435, width: 0.15, top: 0.05)
                finger(w: w, h: h, x: 0.60, width: 0.15, top: 0.13)
                finger(w: w, h: h, x: 0.765, width: 0.13, top: 0.27)
                palm(rect: palmRect)
                let t = CGAffineTransform(a: palmRect.width, b: 0, c: 0, d: palmRect.height,
                                          tx: palmRect.minX, ty: palmRect.minY)
                PalmLinesOverlay(transform: t, progress: progress)
            }
        }
        .accessibilityHidden(true)
    }

    private func palm(rect: CGRect) -> some View {
        let shape = RoundedRectangle(cornerRadius: rect.width * 0.22, style: .continuous)
        let border: Color = Theme.gold.opacity(0.5)
        return shape
            .fill(Theme.surface)
            .overlay(shape.stroke(border, lineWidth: 1))
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }

    private func finger(w: CGFloat, h: CGFloat, x: CGFloat, width: CGFloat, top: CGFloat) -> some View {
        let bottom: CGFloat = 0.58
        let shape = RoundedRectangle(cornerRadius: w * width * 0.5, style: .continuous)
        let border: Color = Theme.gold.opacity(0.35)
        return shape
            .fill(Theme.surface)
            .overlay(shape.stroke(border, lineWidth: 1))
            .frame(width: w * width, height: h * (bottom - top))
            .position(x: w * x, y: h * (top + (bottom - top) / 2))
    }

    private func thumb(w: CGFloat, h: CGFloat) -> some View {
        let border: Color = Theme.gold.opacity(0.35)
        return Capsule()
            .fill(Theme.surface)
            .overlay(Capsule().stroke(border, lineWidth: 1))
            .frame(width: w * 0.19, height: h * 0.34)
            .rotationEffect(.degrees(-38))
            .position(x: w * 0.135, y: h * 0.62)
    }
}

/// A sci-fi-scanner sweep: a glowing bar travels down the frame between bracket
/// corners, as if actively hunting for lines in the photo beneath it.
private struct ScannerSweepOverlay: View {
    var sweep: CGFloat // 0...1

    var body: some View {
        GeometryReader { geo in
            ZStack {
                corners(size: geo.size)
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, Theme.gold.opacity(0.9), .clear],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(height: 40)
                    .offset(y: sweep * max(geo.size.height - 40, 0))
                    .blendMode(.plusLighter)
            }
        }
        .allowsHitTesting(false)
    }

    private func corners(size: CGSize) -> some View {
        let len: CGFloat = min(size.width, size.height) * 0.12
        return ForEach(0..<4, id: \.self) { i in
            let corner = CGPoint(x: i % 2 == 0 ? 0 : size.width, y: i < 2 ? 0 : size.height)
            CornerBracket(corner: corner, length: len, flipX: i % 2 != 0, flipY: i >= 2)
                .stroke(Theme.gold.opacity(0.8), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }
}

private struct CornerBracket: Shape {
    var corner: CGPoint
    var length: CGFloat
    var flipX: Bool
    var flipY: Bool

    func path(in rect: CGRect) -> Path {
        let dx: CGFloat = flipX ? -length : length
        let dy: CGFloat = flipY ? -length : length
        var p = Path()
        p.move(to: CGPoint(x: corner.x + dx, y: corner.y))
        p.addLine(to: corner)
        p.addLine(to: CGPoint(x: corner.x, y: corner.y + dy))
        return p
    }
}

/// The palm's outline in a photo — the wrist plus each finger's base (MCP) knuckle,
/// which together trace the palm without the fingers. Points are normalized in
/// Vision's coordinate space (0...1, origin bottom-left).
private struct HandLandmarks {
    var wrist: CGPoint
    var thumbCMC: CGPoint
    var indexMCP: CGPoint
    var middleMCP: CGPoint
    var ringMCP: CGPoint
    var littleMCP: CGPoint

    /// Thumb-side to little-finger-side, closing back through the wrist — a simple
    /// polygon that hugs the palm and excludes the fingers above it.
    var polygon: [CGPoint] { [wrist, thumbCMC, indexMCP, middleMCP, ringMCP, littleMCP] }
}

/// Finds the palm's outline in a photo using Vision's on-device hand pose model —
/// no network call, so a scan works offline and never leaves the device.
private enum HandDetector {
    static func detectPalm(in image: UIImage) -> HandLandmarks? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation(for: image.imageOrientation))
        guard (try? handler.perform([request])) != nil, let observation = request.results?.first else { return nil }

        func point(_ joint: VNHumanHandPoseObservation.JointName) -> CGPoint? {
            guard let p = try? observation.recognizedPoint(joint), p.confidence > 0.4 else { return nil }
            return p.location
        }
        guard let wrist = point(.wrist), let thumbCMC = point(.thumbCMC), let indexMCP = point(.indexMCP),
              let middleMCP = point(.middleMCP), let ringMCP = point(.ringMCP), let littleMCP = point(.littleMCP)
        else { return nil }

        // Reject a degenerate read: if the wrist and the two hand-width points are
        // nearly collinear, the line-placement transform built from them would be
        // wildly stretched or skewed rather than actually following the hand.
        let ax = littleMCP.x - thumbCMC.x, ay = littleMCP.y - thumbCMC.y
        let bx = wrist.x - thumbCMC.x, by = wrist.y - thumbCMC.y
        guard abs(ax * by - ay * bx) > 0.02 else { return nil }

        return HandLandmarks(wrist: wrist, thumbCMC: thumbCMC, indexMCP: indexMCP,
                              middleMCP: middleMCP, ringMCP: ringMCP, littleMCP: littleMCP)
    }

    private static func orientation(for uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch uiOrientation {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        case .upMirrored: .upMirrored
        case .downMirrored: .downMirrored
        case .leftMirrored: .leftMirrored
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}

/// A fixed set of points as a `Shape`, so it can be used with `.clipShape` — used to
/// confine the traced lines to the palm's actual outline in the photo.
private struct PolygonShape: Shape {
    var points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: first)
        for point in points.dropFirst() { p.addLine(to: point) }
        p.closeSubpath()
        return p
    }
}

/// Wraps `UIImagePickerController` to capture a palm photo from the camera, or the
/// photo library when the camera isn't available (e.g. the Simulator).
/// Which source to open the picker with — a single `Identifiable` value driving
/// `.sheet(item:)`, so the sheet's content is always built fresh from one atomic
/// state change rather than two separately-set `@State` properties.
private enum PalmPickerSource: Identifiable {
    case camera, library

    var id: Self { self }

    var uiSourceType: UIImagePickerController.SourceType {
        self == .camera ? .camera : .photoLibrary
    }
}

private struct PalmImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType
    var onPick: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.allowsEditing = true
        if sourceType == .camera { picker.cameraCaptureMode = .photo }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PalmImagePicker
        init(_ parent: PalmImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                    didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage) {
                parent.onPick(image)
            } else {
                parent.onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}

/// Palm reading: opens the camera to capture a photo, sweeps it with a scanner
/// animation, traces the four major lines, then streams an AI interpretation.
struct PalmView: View {
    let me: BirthProfile

    @Environment(\.modelContext) private var context
    @State private var loader = ReadingLoader()
    @State private var capturedImage: UIImage?
    @State private var handLandmarks: HandLandmarks?
    @State private var detectionFailed = false
    @State private var hasRead = false
    @State private var isScanning = false
    @State private var scanSweep: CGFloat = 0
    @State private var currentLine: PalmLine?
    @State private var traceProgress: [PalmLine: CGFloat] =
        Dictionary(uniqueKeysWithValues: PalmLine.allCases.map { ($0, 0) })
    @State private var scanTask: Task<Void, Never>?
    @State private var activePicker: PalmPickerSource?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Palm Reading").font(Theme.serif(30)).foregroundStyle(Theme.text).padding(.top, 12)
                    Text(subtitle).font(Theme.serif(15)).foregroundStyle(Theme.secondary)

                    photoStage

                    if isScanning {
                        Text("Scanning your palm…")
                            .font(Theme.mono(11)).tracking(1).foregroundStyle(Theme.gold)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .transition(.opacity)
                    } else if let currentLine {
                        Text("Tracing your \(currentLine.label)…")
                            .font(Theme.mono(11)).tracking(1).foregroundStyle(Theme.gold)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .transition(.opacity)
                    } else if detectionFailed {
                        Text("I couldn't find a palm in that photo. Try again with your open hand filling the frame, in good light.")
                            .font(Theme.serif(14)).foregroundStyle(Theme.tense)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .multilineTextAlignment(.center)
                    }

                    if capturedImage == nil || detectionFailed {
                        Button(detectionFailed ? "Try again" : "Scan my palm", action: startCapture)
                            .buttonStyle(PillButtonStyle())
                        Button("Choose from Photos") { activePicker = .library }
                            .font(Theme.mono(12)).foregroundStyle(Theme.secondary)
                            .frame(maxWidth: .infinity)
                    } else if hasRead {
                        Card {
                            HStack {
                                SectionLabel("Your lines")
                                if !loader.isLoading && !loader.text.isEmpty {
                                    ShareReadingButton(profile: me, reading: loader.text)
                                }
                            }
                            ReadingBlock(loader: loader) { interpret(force: true) }
                        }
                        Button("Scan again", action: reset).buttonStyle(PillButtonStyle(filled: false))
                    }
                }
                .padding(20)
            }
            .astraScreen()
            .navigationBarHidden(true)
        }
        .sheet(item: $activePicker) { picker in
            PalmImagePicker(sourceType: picker.uiSourceType) { image in
                activePicker = nil
                capturedImage = image
                beginScan()
            } onCancel: {
                activePicker = nil
            }
            .ignoresSafeArea()
        }
        .onDisappear { scanTask?.cancel() }
    }

    private var subtitle: String {
        if detectionFailed { return "No palm found — let's try that again." }
        return capturedImage == nil
            ? "Snap a clear photo of your open palm and I'll scan it for your heart, head, life and fate lines."
            : "Hold still — tracing the lines I find."
    }

    private var photoStage: some View {
        GeometryReader { geo in
            ZStack {
                if let capturedImage {
                    Image(uiImage: capturedImage).resizable().scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                    if let handLandmarks {
                        let points = handLandmarks.polygon.map {
                            viewPoint($0, imageSize: capturedImage.size, frameSize: geo.size)
                        }
                        PalmLinesOverlay(transform: palmTransform(handLandmarks, imageSize: capturedImage.size, frameSize: geo.size),
                                         progress: traceProgress)
                            .clipShape(PolygonShape(points: points))
                    }
                    if isScanning { ScannerSweepOverlay(sweep: scanSweep) }
                } else {
                    PalmHandView(progress: traceProgress)
                }
            }
        }
        .frame(height: 320)
        .frame(maxWidth: .infinity)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.gold.opacity(0.5), lineWidth: 1))
    }

    /// Maps a Vision-normalized point (0...1, origin bottom-left, in the photo's own
    /// orientation-corrected space) to this view's coordinates under `.scaledToFill()`.
    private func viewPoint(_ p: CGPoint, imageSize: CGSize, frameSize: CGSize) -> CGPoint {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = max(frameSize.width / imageSize.width, frameSize.height / imageSize.height)
        let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let originX = (frameSize.width - scaledSize.width) / 2
        let originY = (frameSize.height - scaledSize.height) / 2
        return CGPoint(x: originX + p.x * scaledSize.width, y: originY + (1 - p.y) * scaledSize.height)
    }

    /// Builds an affine transform that maps the palm lines' normalized unit square
    /// — (0,0) thumb base, (1,0) little-finger base, (0.5,1) wrist — onto this
    /// specific hand's real position, size and rotation in the photo, so the lines
    /// follow the hand exactly as it's tilted rather than sitting in an upright box.
    private func palmTransform(_ landmarks: HandLandmarks, imageSize: CGSize, frameSize: CGSize) -> CGAffineTransform {
        let thumb = viewPoint(landmarks.thumbCMC, imageSize: imageSize, frameSize: frameSize)
        let little = viewPoint(landmarks.littleMCP, imageSize: imageSize, frameSize: frameSize)
        let wrist = viewPoint(landmarks.wrist, imageSize: imageSize, frameSize: frameSize)

        let a = little.x - thumb.x
        let b = little.y - thumb.y
        let c = wrist.x - thumb.x - 0.5 * a
        let d = wrist.y - thumb.y - 0.5 * b
        return CGAffineTransform(a: a, b: b, c: c, d: d, tx: thumb.x, ty: thumb.y)
    }

    private func startCapture() {
        activePicker = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .library
    }

    private func reset() {
        scanTask?.cancel()
        capturedImage = nil
        handLandmarks = nil
        detectionFailed = false
        hasRead = false
        isScanning = false
        currentLine = nil
        scanSweep = 0
        for line in PalmLine.allCases { traceProgress[line] = 0 }
        loader = ReadingLoader()
    }

    private func beginScan() {
        guard let capturedImage else { return }
        handLandmarks = nil
        detectionFailed = false
        isScanning = true
        scanSweep = 0
        for line in PalmLine.allCases { traceProgress[line] = 0 }
        scanTask?.cancel()
        scanTask = Task {
            // Detection (first call loads Vision's on-device model, which can take a
            // few seconds) runs in the background while the sweep keeps animating,
            // so the UI never sits frozen waiting for it — bounded by a timeout so a
            // slow or stuck detection can't leave the scan hanging indefinitely.
            async let landmarksResult = Self.detectPalmWithTimeout(capturedImage)
            for _ in 0..<2 {
                withAnimation(.easeInOut(duration: 0.9)) { scanSweep = 1 }
                try? await Task.sleep(for: .seconds(0.9))
                if Task.isCancelled { return }
                scanSweep = 0
            }
            let landmarks = await landmarksResult
            withAnimation { isScanning = false }

            guard let landmarks else {
                withAnimation { detectionFailed = true }
                return
            }
            handLandmarks = landmarks
            interpret(force: hasRead)
            hasRead = true
            for line in PalmLine.allCases {
                withAnimation { currentLine = line }
                withAnimation(.easeInOut(duration: 1.0)) { traceProgress[line] = 1 }
                try? await Task.sleep(for: .seconds(1.05))
                if Task.isCancelled { return }
            }
            withAnimation { currentLine = nil }
        }
    }

    /// Races hand detection against a timeout so a slow first model load — or a
    /// genuinely stuck request — resolves to "no palm found" instead of hanging.
    private static func detectPalmWithTimeout(_ image: UIImage) async -> HandLandmarks? {
        await withTaskGroup(of: HandLandmarks?.self) { group in
            group.addTask { HandDetector.detectPalm(in: image) }
            group.addTask {
                try? await Task.sleep(for: .seconds(10))
                return nil
            }
            let result = (await group.next()) ?? nil
            group.cancelAll()
            return result
        }
    }

    private func interpret(force: Bool = false) {
        let profile = me
        let prompt = """
        Give me a palm reading. Read each of the four major lines symbolically — heart line (love, emotion), \
        head line (mind, decisions), life line (vitality, energy) and fate line (career, purpose) — one short \
        paragraph each, then tie the overall reading to one or two of my chart placements. 180–260 words. \
        Be clear this is symbolic, not medical or predictive of lifespan.
        """
        loader.load(key: "palm-\(me.id)-\(ReadingPeriod.today.bucket())",
                    system: { AstrologerExpert.palm.systemPrompt(for: profile) },
                    prompt: prompt, context: context, force: force, maxTokens: 900)
    }
}
