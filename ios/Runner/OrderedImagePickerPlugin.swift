import Flutter
import AVFoundation
import Photos
import PhotosUI
import QuickLook
import UIKit
import UniformTypeIdentifiers

@available(iOS 14, *)
final class OrderedImagePickerPlugin: NSObject, FlutterPlugin, PHPickerViewControllerDelegate {
  private static let maxSelectionLimit = 9
  private static let compressedMaxDimension: CGFloat = 1600
  private static let compressedQuality: CGFloat = 0.78
  private static let pickerActionMinWidth: CGFloat = 176
  private static let pickerActionMinHeight: CGFloat = 56
  private static let pickerActionInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)

  private var pendingResult: FlutterResult?
  private var pendingOriginal = false
  private var sendTitleTimer: Timer?

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
    let arguments = call.arguments as? [String: Any]
    let original = arguments?["original"] as? Bool ?? false
    let limit = arguments?["limit"] as? Int ?? Self.maxSelectionLimit
    presentPicker(result: result, original: original, limit: limit)
  }

  private func presentPicker(result: @escaping FlutterResult, original: Bool, limit: Int) {
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
    configuration.selectionLimit = min(max(limit, 1), Self.maxSelectionLimit)
    if #available(iOS 15, *) {
      configuration.selection = .ordered
    }

    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = self
    pendingResult = result
    pendingOriginal = original
    presenter.present(picker, animated: true) { [weak self, weak picker] in
      guard let picker else { return }
      self?.startSendTitleOverride(for: picker)
    }
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    stopSendTitleOverride()
    picker.dismiss(animated: true)
    guard let result = pendingResult else { return }
    let original = pendingOriginal
    pendingResult = nil
    pendingOriginal = false

    loadImages(results, original: original) { images, error in
      if let error {
        result(error)
        return
      }
      result(images ?? [])
    }
  }

  private func startSendTitleOverride(for picker: PHPickerViewController) {
    stopSendTitleOverride()
    applySendTitleOverride(in: picker)
    sendTitleTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self, weak picker] _ in
      guard let self, let picker, picker.presentingViewController != nil else {
        self?.stopSendTitleOverride()
        return
      }
      self.applySendTitleOverride(in: picker)
    }
  }

  private func stopSendTitleOverride() {
    sendTitleTimer?.invalidate()
    sendTitleTimer = nil
  }

  private func applySendTitleOverride(in picker: PHPickerViewController) {
    overrideSendTitle(in: picker)
    overrideSendTitle(in: picker.view)
  }

  private func overrideSendTitle(in viewController: UIViewController) {
    updateBarButtonTitle(viewController.navigationItem.rightBarButtonItem)
    updateBarButtonTitle(viewController.navigationItem.leftBarButtonItem)
    for child in viewController.children {
      overrideSendTitle(in: child)
    }
  }

  private func updateBarButtonTitle(_ item: UIBarButtonItem?) {
    guard let item, shouldOverridePickerActionTitle(item.title) else { return }
    item.title = "发送"
    item.width = max(item.width, Self.pickerActionMinWidth)
  }

  private func overrideSendTitle(in view: UIView) {
    if let button = view as? UIButton {
      var matched = updateButtonTitle(button, for: .normal)
      matched = updateButtonTitle(button, for: .highlighted) || matched
      matched = updateButtonTitle(button, for: .selected) || matched
      matched = updateButtonTitle(button, for: .disabled) || matched
      matched = updateButtonConfigurationTitle(button) || matched
      if matched {
        applyPickerActionButtonStyle(button)
      }
    }
    if let label = view as? UILabel, shouldOverridePickerActionTitle(label.text) {
      label.text = "发送"
      label.textAlignment = .center
      label.lineBreakMode = .byClipping
      label.minimumScaleFactor = 0.7
      label.adjustsFontSizeToFitWidth = true
      label.setContentCompressionResistancePriority(.required, for: .horizontal)
      label.setContentHuggingPriority(.required, for: .horizontal)
      label.sizeToFit()
      if let actionView = pickerActionContainer(for: label) {
        applyPickerActionContainerStyle(actionView)
        if let outerActionView = actionView.superview {
          applyPickerActionContainerStyle(outerActionView)
        }
      }
    }
    for subview in view.subviews {
      overrideSendTitle(in: subview)
    }
  }

  private func updateButtonTitle(_ button: UIButton, for state: UIControl.State) -> Bool {
    guard shouldOverridePickerActionTitle(button.title(for: state)) else { return false }
    button.setTitle("发送", for: state)
    return true
  }

  private func updateButtonConfigurationTitle(_ button: UIButton) -> Bool {
    guard #available(iOS 15, *), var configuration = button.configuration else {
      return false
    }
    let title: String?
    if let configurationTitle = configuration.title {
      title = configurationTitle
    } else if let attributedTitle = configuration.attributedTitle {
      title = String(attributedTitle.characters)
    } else {
      title = nil
    }
    guard shouldOverridePickerActionTitle(title) else { return false }
    configuration.title = "发送"
    configuration.attributedTitle = nil
    configuration.contentInsets = NSDirectionalEdgeInsets(
      top: Self.pickerActionInsets.top,
      leading: Self.pickerActionInsets.left,
      bottom: Self.pickerActionInsets.bottom,
      trailing: Self.pickerActionInsets.right
    )
    button.configuration = configuration
    return true
  }

  private func applyPickerActionButtonStyle(_ button: UIButton) {
    button.contentEdgeInsets = Self.pickerActionInsets
    button.titleLabel?.lineBreakMode = .byClipping
    button.titleLabel?.minimumScaleFactor = 0.7
    button.titleLabel?.adjustsFontSizeToFitWidth = true
    button.titleLabel?.textAlignment = .center
    button.titleLabel?.setContentCompressionResistancePriority(.required, for: .horizontal)
    button.titleLabel?.setContentHuggingPriority(.required, for: .horizontal)
    button.setContentCompressionResistancePriority(.required, for: .horizontal)
    button.setContentHuggingPriority(.required, for: .horizontal)
    applyPickerActionContainerStyle(button)
    if let container = button.superview {
      applyPickerActionContainerStyle(container)
    }
    button.sizeToFit()
  }

  private func pickerActionContainer(for view: UIView) -> UIView? {
    var current: UIView? = view
    while let candidate = current {
      if candidate is UIControl || candidate is UIButton {
        return candidate
      }
      current = candidate.superview
    }
    return view.superview
  }

  private func applyPickerActionContainerStyle(_ view: UIView) {
    view.translatesAutoresizingMaskIntoConstraints = false
    view.setContentCompressionResistancePriority(.required, for: .horizontal)
    view.setContentHuggingPriority(.required, for: .horizontal)
    let minWidth = view.widthAnchor.constraint(greaterThanOrEqualToConstant: Self.pickerActionMinWidth)
    minWidth.priority = .defaultHigh
    minWidth.identifier = "p2p_im_picker_action_min_width"
    let minHeight = view.heightAnchor.constraint(greaterThanOrEqualToConstant: Self.pickerActionMinHeight)
    minHeight.priority = .defaultHigh
    minHeight.identifier = "p2p_im_picker_action_min_height"
    for constraint in view.constraints {
      if constraint.identifier == minWidth.identifier ||
        constraint.identifier == minHeight.identifier {
        constraint.isActive = false
      }
    }
    NSLayoutConstraint.activate([minWidth, minHeight])
  }

  private func shouldOverridePickerActionTitle(_ title: String?) -> Bool {
    guard let title else { return false }
    let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if normalized.isEmpty { return false }
    return normalized == "add" ||
      normalized == "done" ||
      normalized == "send" ||
      normalized == "完成" ||
      normalized == "添加" ||
      normalized == "选择" ||
      normalized.hasPrefix("add ") ||
      normalized.hasPrefix("done ") ||
      normalized.hasPrefix("send ") ||
      normalized.hasPrefix("添加") ||
      normalized.hasPrefix("选择") ||
      normalized.contains(" item") ||
      normalized.contains(" items") ||
      normalized.contains("项目") ||
      normalized.contains("项")
  }

  private func loadImages(
    _ results: [PHPickerResult],
    original: Bool,
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
            let image = original
              ? try Self.copyOriginalImageFile(
                from: fileURL,
                suggestedName: provider.suggestedName,
                typeIdentifier: typeIdentifier,
                outputDirectory: outputDirectory
              )
              : try Self.writeCompressedImageFile(
                from: fileURL,
                suggestedName: provider.suggestedName,
                outputDirectory: outputDirectory
              )
            stateQueue.sync {
              loadedImages[index] = image
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
            let image = original
              ? try Self.writeOriginalImageData(
                data,
                suggestedName: provider.suggestedName,
                typeIdentifier: typeIdentifier,
                outputDirectory: outputDirectory
              )
              : try Self.writeCompressedImageData(
                data,
                suggestedName: provider.suggestedName,
                outputDirectory: outputDirectory
              )
            stateQueue.sync {
              loadedImages[index] = image
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

  private static func copyOriginalImageFile(
    from sourceURL: URL,
    suggestedName: String?,
    typeIdentifier: String,
    outputDirectory: URL
  ) throws -> [String: String] {
    let fileName = Self.fileName(suggestedName: suggestedName, typeIdentifier: typeIdentifier)
    let destinationURL = outputDirectory.appendingPathComponent("\(UUID().uuidString)-\(fileName)")
    if FileManager.default.fileExists(atPath: destinationURL.path) {
      try FileManager.default.removeItem(at: destinationURL)
    }
    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    return [
      "path": destinationURL.path,
      "name": fileName,
      "mimeType": Self.mimeType(for: typeIdentifier),
    ]
  }

  private static func writeOriginalImageData(
    _ data: Data,
    suggestedName: String?,
    typeIdentifier: String,
    outputDirectory: URL
  ) throws -> [String: String] {
    let fileName = Self.fileName(suggestedName: suggestedName, typeIdentifier: typeIdentifier)
    let fileURL = outputDirectory.appendingPathComponent("\(UUID().uuidString)-\(fileName)")
    try data.write(to: fileURL, options: .atomic)
    return [
      "path": fileURL.path,
      "name": fileName,
      "mimeType": Self.mimeType(for: typeIdentifier),
    ]
  }

  private static func writeCompressedImageFile(
    from sourceURL: URL,
    suggestedName: String?,
    outputDirectory: URL
  ) throws -> [String: String] {
    guard let image = UIImage(contentsOfFile: sourceURL.path) else {
      let data = try Data(contentsOf: sourceURL)
      return try writeCompressedImageData(
        data,
        suggestedName: suggestedName,
        outputDirectory: outputDirectory
      )
    }
    return try writeCompressedImage(image, suggestedName: suggestedName, outputDirectory: outputDirectory)
  }

  private static func writeCompressedImageData(
    _ data: Data,
    suggestedName: String?,
    outputDirectory: URL
  ) throws -> [String: String] {
    guard let image = UIImage(data: data) else {
      throw NSError(
        domain: "p2p_im.ordered_image_picker",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Failed to decode selected image."]
      )
    }
    return try writeCompressedImage(image, suggestedName: suggestedName, outputDirectory: outputDirectory)
  }

  private static func writeCompressedImage(
    _ image: UIImage,
    suggestedName: String?,
    outputDirectory: URL
  ) throws -> [String: String] {
    let resized = resizedImageIfNeeded(image)
    guard let data = resized.jpegData(compressionQuality: Self.compressedQuality) else {
      throw NSError(
        domain: "p2p_im.ordered_image_picker",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "Failed to encode selected image."]
      )
    }
    let base = sanitizedFileName(
      suggestedName
        .flatMap { $0.isEmpty ? nil : ($0 as NSString).deletingPathExtension }
        ?? "image"
    )
    let fileName = "\(base).jpg"
    let fileURL = outputDirectory.appendingPathComponent("\(UUID().uuidString)-\(fileName)")
    try data.write(to: fileURL, options: .atomic)
    return [
      "path": fileURL.path,
      "name": fileName,
      "mimeType": "image/jpeg",
    ]
  }

  private static func resizedImageIfNeeded(_ image: UIImage) -> UIImage {
    let width = image.size.width
    let height = image.size.height
    let longest = max(width, height)
    guard longest > Self.compressedMaxDimension, width > 0, height > 0 else {
      return image
    }
    let scale = Self.compressedMaxDimension / longest
    let targetSize = CGSize(width: width * scale, height: height * scale)
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: targetSize))
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

final class SaveImagePlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "p2p_im/save_image",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(SaveImagePlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "savePng":
      savePng(call, result: result)
    case "saveMediaFile":
      saveMediaFile(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func savePng(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: Any],
      let typedData = arguments["bytes"] as? FlutterStandardTypedData,
      !typedData.data.isEmpty
    else {
      result(
        FlutterError(
          code: "invalid_args",
          message: "Image bytes are required.",
          details: nil
        )
      )
      return
    }

    guard let image = UIImage(data: typedData.data) else {
      result(
        FlutterError(
          code: "decode_failed",
          message: "Failed to decode PNG image.",
          details: nil
        )
      )
      return
    }

    Self.requestPhotoAddAuthorization { granted in
      guard granted else {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "permission_denied",
              message: "Photo library add permission was denied.",
              details: nil
            )
          )
        }
        return
      }

      PHPhotoLibrary.shared().performChanges({
        PHAssetChangeRequest.creationRequestForAsset(from: image)
      }) { success, error in
        DispatchQueue.main.async {
          if success {
            result(nil)
          } else {
            result(
              FlutterError(
                code: "save_failed",
                message: error?.localizedDescription ?? "Failed to save image.",
                details: nil
              )
            )
          }
        }
      }
    }
  }

  private func saveMediaFile(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: Any],
      let path = arguments["path"] as? String,
      let fileName = arguments["fileName"] as? String,
      let mimeType = arguments["mimeType"] as? String,
      !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !mimeType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      result(
        FlutterError(
          code: "invalid_args",
          message: "path, fileName and mimeType are required.",
          details: nil
        )
      )
      return
    }

    let fileURL = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      result(
        FlutterError(
          code: "media_not_found",
          message: "The media file does not exist.",
          details: path
        )
      )
      return
    }

    let isVideo = mimeType.lowercased().hasPrefix("video/")
    Self.requestPhotoAddAuthorization { granted in
      guard granted else {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "permission_denied",
              message: "Photo library add permission was denied.",
              details: nil
            )
          )
        }
        return
      }

      PHPhotoLibrary.shared().performChanges({
        let request = PHAssetCreationRequest.forAsset()
        let options = PHAssetResourceCreationOptions()
        options.originalFilename = fileName
        request.addResource(
          with: isVideo ? .video : .photo,
          fileURL: fileURL,
          options: options
        )
      }) { success, error in
        DispatchQueue.main.async {
          if success {
            result(nil)
          } else {
            result(
              FlutterError(
                code: "save_failed",
                message: error?.localizedDescription ?? "Failed to save media.",
                details: nil
              )
            )
          }
        }
      }
    }
  }

  private static func requestPhotoAddAuthorization(_ completion: @escaping (Bool) -> Void) {
    if #available(iOS 14, *) {
      PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
        completion(status == .authorized || status == .limited)
      }
    } else {
      PHPhotoLibrary.requestAuthorization { status in
        completion(status == .authorized)
      }
    }
  }
}
