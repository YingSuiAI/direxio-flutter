import Flutter
import AVFoundation
import PhotosUI
import QuickLook
import UIKit
import UniformTypeIdentifiers

@available(iOS 14, *)
final class OrderedImagePickerPlugin: NSObject, FlutterPlugin, PHPickerViewControllerDelegate {
  private var pendingResult: FlutterResult?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "p2p_im/ordered_image_picker",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(OrderedImagePickerPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "pickOrderedImages" else {
      result(FlutterMethodNotImplemented)
      return
    }
    presentPicker(result: result)
  }

  private func presentPicker(result: @escaping FlutterResult) {
    guard #available(iOS 14, *) else {
      result(
        FlutterError(
          code: "ordered_picker_unavailable",
          message: "PHPickerViewController requires iOS 14 or later.",
          details: nil
        )
      )
      return
    }
    guard pendingResult == nil else {
      result(
        FlutterError(
          code: "ordered_picker_active",
          message: "An ordered image picker is already active.",
          details: nil
        )
      )
      return
    }
    guard let presenter = Self.topViewController() else {
      result(
        FlutterError(
          code: "ordered_picker_no_presenter",
          message: "No active view controller is available to present the image picker.",
          details: nil
        )
      )
      return
    }

    var configuration = PHPickerConfiguration(photoLibrary: .shared())
    configuration.filter = .images
    configuration.preferredAssetRepresentationMode = .current
    configuration.selectionLimit = 0
    if #available(iOS 15, *) {
      configuration.selection = .ordered
    }

    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = self
    pendingResult = result
    presenter.present(picker, animated: true)
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    guard let result = pendingResult else { return }
    pendingResult = nil

    loadImages(results) { images, error in
      if let error {
        result(error)
        return
      }
      result(images ?? [])
    }
  }

  private func loadImages(
    _ results: [PHPickerResult],
    completion: @escaping ([[String: String]]?, FlutterError?) -> Void
  ) {
    guard !results.isEmpty else {
      completion([], nil)
      return
    }

    let outputDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("p2p-im-ordered-picker", isDirectory: true)
    do {
      try FileManager.default.createDirectory(
        at: outputDirectory,
        withIntermediateDirectories: true
      )
    } catch {
      completion(
        nil,
        FlutterError(
          code: "ordered_picker_cache_error",
          message: error.localizedDescription,
          details: nil
        )
      )
      return
    }

    let group = DispatchGroup()
    let stateQueue = DispatchQueue(label: "p2p-im.ordered-image-picker.state")
    var loadedImages = Array<Dictionary<String, String>?>(repeating: nil, count: results.count)
    var firstError: FlutterError?

    for (index, pickerResult) in results.enumerated() {
      let provider = pickerResult.itemProvider
      guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else {
        stateQueue.sync {
          firstError = firstError ?? FlutterError(
            code: "ordered_picker_invalid_source",
            message: "The selected item is not an image.",
            details: nil
          )
        }
        continue
      }
      let typeIdentifier = Self.preferredImageTypeIdentifier(from: provider)

      group.enter()
      provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { fileURL, error in
        if let fileURL {
          do {
            let fileName = Self.fileName(
              suggestedName: provider.suggestedName,
              typeIdentifier: typeIdentifier
            )
            let destinationURL = outputDirectory
              .appendingPathComponent("\(UUID().uuidString)-\(fileName)")
            if FileManager.default.fileExists(atPath: destinationURL.path) {
              try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: fileURL, to: destinationURL)
            stateQueue.sync {
              loadedImages[index] = [
                "path": destinationURL.path,
                "name": fileName,
                "mimeType": Self.mimeType(for: typeIdentifier),
              ]
            }
          } catch {
            stateQueue.sync {
              firstError = firstError ?? FlutterError(
                code: "ordered_picker_cache_error",
                message: error.localizedDescription,
                details: nil
              )
            }
          }
          group.leave()
          return
        }

        if error != nil {
          // Some providers fail file loading but still support data loading.
          // Fall through to data representation instead of failing immediately.
        }

        provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, dataError in
          defer { group.leave() }
          if let dataError {
            stateQueue.sync {
              firstError = firstError ?? FlutterError(
                code: "ordered_picker_read_error",
                message: dataError.localizedDescription,
                details: nil
              )
            }
            return
          }
          guard let data else {
            stateQueue.sync {
              firstError = firstError ?? FlutterError(
                code: "ordered_picker_read_error",
                message: "The selected image returned empty data.",
                details: nil
              )
            }
            return
          }

          do {
            let fileName = Self.fileName(
              suggestedName: provider.suggestedName,
              typeIdentifier: typeIdentifier
            )
            let fileURL = outputDirectory.appendingPathComponent("\(UUID().uuidString)-\(fileName)")
            try data.write(to: fileURL, options: .atomic)
            stateQueue.sync {
              loadedImages[index] = [
                "path": fileURL.path,
                "name": fileName,
                "mimeType": Self.mimeType(for: typeIdentifier),
              ]
            }
          } catch {
            stateQueue.sync {
              firstError = firstError ?? FlutterError(
                code: "ordered_picker_cache_error",
                message: error.localizedDescription,
                details: nil
              )
            }
          }
        }
      }
    }

    group.notify(queue: .main) {
      if let firstError {
        completion(nil, firstError)
        return
      }
      completion(loadedImages.compactMap { $0 }, nil)
    }
  }

  private static func preferredImageTypeIdentifier(from provider: NSItemProvider) -> String {
    provider.registeredTypeIdentifiers.first { typeIdentifier in
      guard let type = UTType(typeIdentifier) else { return false }
      return type.conforms(to: .image)
    } ?? UTType.jpeg.identifier
  }

  private static func fileName(suggestedName: String?, typeIdentifier: String) -> String {
    let fileExtension = UTType(typeIdentifier)?.preferredFilenameExtension ?? "jpg"
    let baseName = suggestedName
      .flatMap { $0.isEmpty ? nil : $0 }
      .map(sanitizedFileName)
      ?? "image"
    let existingExtension = (baseName as NSString).pathExtension
    return existingExtension.isEmpty ? "\(baseName).\(fileExtension)" : baseName
  }

  private static func sanitizedFileName(_ value: String) -> String {
    let disallowedCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
    let parts = value.components(separatedBy: disallowedCharacters)
    let name = parts.joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
    return name.isEmpty ? "image" : name
  }

  private static func mimeType(for typeIdentifier: String) -> String {
    UTType(typeIdentifier)?.preferredMIMEType ?? "image/jpeg"
  }

  private static func topViewController() -> UIViewController? {
    let root = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first { $0.isKeyWindow }?
      .rootViewController
    return topViewController(from: root)
  }

  private static func topViewController(from root: UIViewController?) -> UIViewController? {
    if let navigation = root as? UINavigationController {
      return topViewController(from: navigation.visibleViewController)
    }
    if let tabBar = root as? UITabBarController {
      return topViewController(from: tabBar.selectedViewController)
    }
    if let presented = root?.presentedViewController {
      return topViewController(from: presented)
    }
    return root
  }
}

final class VideoToolsPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "p2p_im/video_tools",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(VideoToolsPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "createThumbnail":
      createThumbnail(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func createThumbnail(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: Any],
      let path = arguments["path"] as? String,
      !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      result(
        FlutterError(
          code: "video_thumbnail_invalid_path",
          message: "A non-empty video path is required.",
          details: nil
        )
      )
      return
    }

    guard FileManager.default.fileExists(atPath: path) else {
      result(
        FlutterError(
          code: "video_thumbnail_not_found",
          message: "The video file does not exist.",
          details: path
        )
      )
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      let finish: (Any?) -> Void = { value in
        DispatchQueue.main.async {
          result(value)
        }
      }
      let fail: (String, String) -> Void = { code, message in
        DispatchQueue.main.async {
          result(FlutterError(code: code, message: message, details: nil))
        }
      }

      let url = URL(fileURLWithPath: path)
      let asset = AVURLAsset(url: url)
      let generator = AVAssetImageGenerator(asset: asset)
      generator.appliesPreferredTrackTransform = true
      generator.maximumSize = CGSize(width: 720, height: 720)

      do {
        let cgImage = try generator.copyCGImage(
          at: CMTime(seconds: 0, preferredTimescale: 600),
          actualTime: nil
        )
        let image = UIImage(cgImage: cgImage)
        guard let data = image.jpegData(compressionQuality: 0.78) else {
          fail("video_thumbnail_encode_failed", "Failed to encode video thumbnail.")
          return
        }
        let seconds = asset.duration.seconds
        let durationMs = seconds.isFinite && seconds > 0 ? Int(seconds * 1000) : 0
        finish([
          "bytes": FlutterStandardTypedData(bytes: data),
          "mimeType": "image/jpeg",
          "width": cgImage.width,
          "height": cgImage.height,
          "durationMs": durationMs,
        ])
      } catch {
        fail("video_thumbnail_failed", error.localizedDescription)
      }
    }
  }
}

final class FileActionsPlugin: NSObject, FlutterPlugin, QLPreviewControllerDataSource {
  private var previewURL: URL?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "p2p_im/file_actions",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(FileActionsPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "previewFile":
      previewFile(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func previewFile(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: Any],
      let path = arguments["path"] as? String,
      !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      result(
        FlutterError(
          code: "file_preview_invalid_path",
          message: "A non-empty file path is required.",
          details: nil
        )
      )
      return
    }

    guard FileManager.default.fileExists(atPath: path) else {
      result(
        FlutterError(
          code: "file_preview_not_found",
          message: "The file does not exist.",
          details: path
        )
      )
      return
    }

    guard let presenter = Self.topViewController() else {
      result(
        FlutterError(
          code: "file_preview_no_presenter",
          message: "No active view controller is available to present the file.",
          details: nil
        )
      )
      return
    }

    previewURL = URL(fileURLWithPath: path)
    let controller = QLPreviewController()
    controller.dataSource = self
    presenter.present(controller, animated: true) {
      result(nil)
    }
  }

  func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
    previewURL == nil ? 0 : 1
  }

  func previewController(
    _ controller: QLPreviewController,
    previewItemAt index: Int
  ) -> QLPreviewItem {
    previewURL! as NSURL
  }

  private static func topViewController() -> UIViewController? {
    let root = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first { $0.isKeyWindow }?
      .rootViewController
    return topViewController(from: root)
  }

  private static func topViewController(from root: UIViewController?) -> UIViewController? {
    if let navigation = root as? UINavigationController {
      return topViewController(from: navigation.visibleViewController)
    }
    if let tabBar = root as? UITabBarController {
      return topViewController(from: tabBar.selectedViewController)
    }
    if let presented = root?.presentedViewController {
      return topViewController(from: presented)
    }
    return root
  }
}
