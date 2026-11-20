import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LandeckDownloads") {
      registerIosDownloadBridge(registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LandeckGlass") {
      registrar.register(
        GlassHeaderFactory(messenger: registrar.messenger()),
        withId: "landeck/glass_header"
      )
      registrar.register(
        GlassTabFactory(messenger: registrar.messenger()),
        withId: "landeck/glass_tabs"
      )
    }
  }
}


// MARK: - Native Liquid Glass surfaces

private func landeckGlassEffect() -> UIVisualEffect {
  if #available(iOS 26.0, *) {
    let effect = UIGlassEffect(style: .regular)
    effect.isInteractive = true
    return effect
  }
  return UIBlurEffect(style: .systemThinMaterial)
}

private final class GlassEffectView: UIVisualEffectView {
  init(cornerRadius: CGFloat) {
    super.init(effect: landeckGlassEffect())
    translatesAutoresizingMaskIntoConstraints = false
    layer.cornerRadius = cornerRadius
    layer.cornerCurve = .continuous
    clipsToBounds = true
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class GlassHeaderPlatformView: NSObject, FlutterPlatformView {
  private let container = UIView()
  private let channel: FlutterMethodChannel

  init(
    frame: CGRect,
    viewId: Int64,
    arguments: Any?,
    messenger: FlutterBinaryMessenger
  ) {
    channel = FlutterMethodChannel(
      name: "landeck/glass_header_\(viewId)",
      binaryMessenger: messenger
    )
    super.init()
    container.frame = frame
    container.backgroundColor = .clear

    let glass = GlassEffectView(cornerRadius: 22)
    container.addSubview(glass)

    let title = UILabel()
    title.translatesAutoresizingMaskIntoConstraints = false
    title.text = (arguments as? [String: Any])?["title"] as? String ?? "LANDeck"
    title.font = .systemFont(ofSize: 17, weight: .semibold)
    title.textColor = .label
    glass.contentView.addSubview(title)

    let add = UIButton(type: .system)
    add.translatesAutoresizingMaskIntoConstraints = false
    add.setImage(
      UIImage(
        systemName: "plus",
        withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
      ),
      for: .normal
    )
    add.tintColor = .systemBlue
    add.accessibilityLabel = "添加"
    add.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
    glass.contentView.addSubview(add)

    NSLayoutConstraint.activate([
      glass.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      glass.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      glass.topAnchor.constraint(equalTo: container.topAnchor),
      glass.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      title.leadingAnchor.constraint(equalTo: glass.contentView.leadingAnchor, constant: 20),
      title.centerYAnchor.constraint(equalTo: glass.contentView.centerYAnchor),
      add.trailingAnchor.constraint(equalTo: glass.contentView.trailingAnchor, constant: -8),
      add.centerYAnchor.constraint(equalTo: glass.contentView.centerYAnchor),
      add.widthAnchor.constraint(equalToConstant: 44),
      add.heightAnchor.constraint(equalToConstant: 44),
    ])

    channel.setMethodCallHandler { _, _ in }
  }

  func view() -> UIView { container }

  @objc private func addTapped() {
    channel.invokeMethod("add", arguments: nil)
  }
}

final class GlassHeaderFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    GlassHeaderPlatformView(
      frame: frame,
      viewId: viewId,
      arguments: args,
      messenger: messenger
    )
  }

  func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol) {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

final class GlassTabPlatformView: NSObject, FlutterPlatformView {
  private let container = UIView()
  private let channel: FlutterMethodChannel
  private let buttons: [UIButton]
  private var selected: Int
  private let symbols = ["house.fill", "antenna.radiowaves.left.and.right", "gearshape.fill"]
  private let titles = ["首页", "发现", "设置"]

  init(
    frame: CGRect,
    viewId: Int64,
    arguments: Any?,
    messenger: FlutterBinaryMessenger
  ) {
    selected = (arguments as? [String: Any])?["selected"] as? Int ?? 0
    channel = FlutterMethodChannel(
      name: "landeck/glass_tabs_\(viewId)",
      binaryMessenger: messenger
    )
    var created: [UIButton] = []
    for index in 0..<3 {
      let button = UIButton(type: .custom)
      var configuration = UIButton.Configuration.plain()
      configuration.image = UIImage(
        systemName: symbols[index],
        withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .regular)
      )
      configuration.title = titles[index]
      configuration.imagePlacement = .top
      configuration.imagePadding = 3
      configuration.contentInsets = NSDirectionalEdgeInsets(
        top: 6, leading: 0, bottom: 6, trailing: 0
      )
      button.configuration = configuration
      button.tag = index
      created.append(button)
    }
    buttons = created
    super.init()

    for button in buttons {
      button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
    }

    container.frame = frame
    container.backgroundColor = .clear

    let glass = GlassEffectView(cornerRadius: 28)
    container.addSubview(glass)

    let stack = UIStackView(arrangedSubviews: buttons)
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.axis = .horizontal
    stack.distribution = .fillEqually
    glass.contentView.addSubview(stack)

    NSLayoutConstraint.activate([
      glass.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      glass.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      glass.topAnchor.constraint(equalTo: container.topAnchor),
      glass.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      stack.leadingAnchor.constraint(equalTo: glass.contentView.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: glass.contentView.trailingAnchor),
      stack.topAnchor.constraint(equalTo: glass.contentView.topAnchor),
      stack.bottomAnchor.constraint(equalTo: glass.contentView.bottomAnchor),
    ])

    updateSelection()
    channel.setMethodCallHandler { [weak self] call, _ in
      guard call.method == "setSelected", let index = call.arguments as? Int else { return }
      self?.selected = index
      self?.updateSelection()
    }
  }

  func view() -> UIView { container }

  @objc private func tabTapped(_ sender: UIButton) {
    selected = sender.tag
    updateSelection()
    channel.invokeMethod("selected", arguments: sender.tag)
  }

  private func updateSelection() {
    for (index, button) in buttons.enumerated() {
      let active = index == selected
      button.configuration?.baseForegroundColor = active ? .systemBlue : .secondaryLabel
      button.configuration?.attributedTitle = AttributedString(
        titles[index],
        attributes: AttributeContainer([
          .font: UIFont.systemFont(ofSize: 10, weight: active ? .semibold : .medium)
        ])
      )
    }
  }
}

final class GlassTabFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    GlassTabPlatformView(
      frame: frame,
      viewId: viewId,
      arguments: args,
      messenger: messenger
    )
  }

  func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol) {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

// MARK: - iOS download bridge

final class LandeckDownloadManager: NSObject, URLSessionDownloadDelegate {
  static let shared = LandeckDownloadManager()

  private var session: URLSession!
  private var tasks: [String: URLSessionDownloadTask] = [:]
  private var records: [String: [String: Any]] = [:]
  private var destinations: [String: String] = [:]
  private var fileNames: [String: String] = [:]
  private var identifiers: [Int: String] = [:]
  private let lock = NSLock()
  private var filesChannel: FlutterMethodChannel?
  private var downloadsChannel: FlutterMethodChannel?
  private var previewController: UIDocumentInteractionController?

  private override init() {
    super.init()
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 30
    configuration.timeoutIntervalForResource = 60 * 60
    configuration.waitsForConnectivity = true
    session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
  }

  func register(with messenger: FlutterBinaryMessenger) {
    let downloads = FlutterMethodChannel(
      name: "com.example.landeck/downloads",
      binaryMessenger: messenger
    )
    downloads.setMethodCallHandler { [weak self] call, result in
      self?.handleDownloadCall(call, result: result)
    }
    downloadsChannel = downloads

    let files = FlutterMethodChannel(
      name: "com.example.landeck/files",
      binaryMessenger: messenger
    )
    files.setMethodCallHandler { [weak self] call, result in
      self?.handleFileCall(call, result: result)
    }
    filesChannel = files
  }

  private func handleFileCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "pickSaveFile":
      guard let args = call.arguments as? [String: Any] else {
        result(nil)
        return
      }
      let name = (args["fileName"] as? String) ?? "下载文件"
      do {
        result(try makeDestination(fileName: name))
      } catch {
        result(FlutterError(code: "save_path", message: "无法创建下载目录", details: nil))
      }
    case "pickFiles", "pickFolderFiles":
      // File uploads are handled by WKWebView's native file input support.
      result([String]())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleDownloadCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      guard let args = call.arguments as? [String: Any],
            let taskId = args["taskId"] as? String,
            let urlString = args["url"] as? String,
            let destination = args["destinationUri"] as? String,
            let url = URL(string: urlString) else {
        result(false)
        return
      }
      let headers = (args["headers"] as? String).flatMap { encoded -> [String: String]? in
        guard let data = encoded.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let map = object as? [String: String] else {
          return nil
        }
        return map
      } ?? [:]
      let fileName = (args["fileName"] as? String) ?? "下载文件"
      result(start(taskId: taskId, url: url, destination: destination, fileName: fileName, headers: headers))
    case "query":
      guard let taskId = call.arguments as? String else {
        result(nil)
        return
      }
      lock.lock()
      let record = records[taskId]
      lock.unlock()
      result(record)
    case "cancel":
      guard let taskId = call.arguments as? String else {
        result(nil)
        return
      }
      cancel(taskId: taskId)
      result(nil)
    case "open":
      guard let args = call.arguments as? [String: Any],
            let path = args["uri"] as? String else {
        result(false)
        return
      }
      result(open(path: path))
    case "share":
      guard let args = call.arguments as? [String: Any],
            let path = args["uri"] as? String else {
        result(false)
        return
      }
      result(share(path: path))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func downloadsDirectory() throws -> URL {
    let base = try FileManager.default.url(
      for: .documentDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    let directory = base.appendingPathComponent("Downloads", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  private func makeDestination(fileName: String) throws -> String {
    let directory = try downloadsDirectory()
    let base = safeFileName(fileName)
    var candidate = directory.appendingPathComponent(base)
    var index = 2
    while FileManager.default.fileExists(atPath: candidate.path) {
      let ext = candidate.pathExtension
      let stem = candidate.deletingPathExtension().lastPathComponent
      let name = ext.isEmpty ? "\(stem)-\(index)" : "\(stem)-\(index).\(ext)"
      candidate = directory.appendingPathComponent(name)
      index += 1
    }
    return candidate.path
  }

  private func safeFileName(_ raw: String) -> String {
    let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|").union(.controlCharacters)
    var name = raw.components(separatedBy: invalid).joined(separator: "_")
    name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    while name.hasPrefix(".") { name.removeFirst() }
    if name.isEmpty { name = "下载文件" }
    if name.count > 120 { name = String(name.prefix(120)) }
    return name
  }

  private func start(
    taskId: String,
    url: URL,
    destination: String,
    fileName: String,
    headers: [String: String]
  ) -> Bool {
    lock.lock()
    if tasks[taskId] != nil {
      lock.unlock()
      return false
    }
    lock.unlock()

    let request = NSMutableURLRequest(url: url)
    request.httpMethod = "GET"
    for (key, value) in headers {
      request.setValue(value, forHTTPHeaderField: key)
    }
    request.setValue("LANDeck/0.7.4 (iOS)", forHTTPHeaderField: "User-Agent")

    let task = session.downloadTask(with: request as URLRequest)
    lock.lock()
    tasks[taskId] = task
    destinations[taskId] = destination
    fileNames[taskId] = fileName
    identifiers[task.taskIdentifier] = taskId
    records[taskId] = [
      "status": "downloading",
      "downloaded": 0,
      "total": 0,
      "fileName": fileName,
      "destination": destination,
    ]
    lock.unlock()
    task.resume()
    return true
  }

  private func cancel(taskId: String) {
    lock.lock()
    let task = tasks[taskId]
    lock.unlock()
    task?.cancel()
    update(taskId: taskId) { record in
      record["status"] = "cancelled"
      record["error"] = "已取消下载"
    }
  }

  private func update(taskId: String, _ block: (inout [String: Any]) -> Void) {
    lock.lock()
    var record = records[taskId] ?? [:]
    block(&record)
    records[taskId] = record
    lock.unlock()
  }

  private func updateProgress(task: URLSessionDownloadTask, written: Int64, expected: Int64) {
    guard let taskId = identifier(for: task) else { return }
    update(taskId: taskId) { record in
      record["downloaded"] = written
      if expected > 0 { record["total"] = expected }
      record["status"] = "downloading"
    }
  }

  private func identifier(for task: URLSessionTask) -> String? {
    lock.lock()
    let value = identifiers[task.taskIdentifier]
    lock.unlock()
    return value
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    updateProgress(task: downloadTask, written: totalBytesWritten, expected: totalBytesExpectedToWrite)
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    guard let taskId = identifier(for: downloadTask),
          let destination = destinations[taskId] else { return }
    let suggested = downloadTask.response?.suggestedFilename
    let target = resolvedDestination(destination: destination, suggested: suggested)
    do {
      if FileManager.default.fileExists(atPath: target.path) {
        try FileManager.default.removeItem(at: target)
      }
      try FileManager.default.moveItem(at: location, to: target)
      let attributes = try? FileManager.default.attributesOfItem(atPath: target.path)
      let size = (attributes?[.size] as? NSNumber)?.int64Value
      update(taskId: taskId) { record in
        record["status"] = "completed"
        if let size = size {
          record["downloaded"] = size
          record["total"] = size
        }
        record["fileName"] = target.lastPathComponent
        record["destination"] = target.path
        record.removeValue(forKey: "error")
      }
    } catch {
      update(taskId: taskId) { record in
        record["status"] = "failed"
        record["error"] = "无法保存文件：\(error.localizedDescription)"
      }
    }
  }

  private func resolvedDestination(destination: String, suggested: String?) -> URL {
    let original = URL(fileURLWithPath: destination)
    guard let suggested = suggested, !suggested.isEmpty else { return original }
    let name = safeFileName(suggested)
    let directory = original.deletingLastPathComponent()
    var candidate = directory.appendingPathComponent(name)
    if candidate.path == original.path { return original }
    var index = 2
    while FileManager.default.fileExists(atPath: candidate.path) {
      let ext = candidate.pathExtension
      let stem = candidate.deletingPathExtension().lastPathComponent
      let next = ext.isEmpty ? "\(stem)-\(index)" : "\(stem)-\(index).\(ext)"
      candidate = directory.appendingPathComponent(next)
      index += 1
    }
    return candidate
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: Error?
  ) {
    guard let taskId = identifier(for: task) else { return }
    if let error = error {
      let cancelled = (error as NSError).code == NSURLErrorCancelled
      update(taskId: taskId) { record in
        if (record["status"] as? String) != "completed" {
          record["status"] = cancelled ? "cancelled" : "failed"
          record["error"] = cancelled ? "已取消下载" : error.localizedDescription
        }
      }
    } else {
      update(taskId: taskId) { record in
        if (record["status"] as? String) == "downloading" {
          record["status"] = "completed"
        }
      }
    }
    lock.lock()
    tasks[taskId] = nil
    identifiers[task.taskIdentifier] = nil
    lock.unlock()
  }

  private func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes.flatMap { $0.windows }.first { $0.isKeyWindow }
    var controller = window?.rootViewController
    while let presented = controller?.presentedViewController {
      controller = presented
    }
    return controller
  }

  private func open(path: String) -> Bool {
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: path) else { return false }
    let controller = UIDocumentInteractionController(url: url)
    previewController = controller
    guard let top = topViewController() else { return false }
    controller.presentPreview(animated: true)
    return true
  }

  private func share(path: String) -> Bool {
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: path) else { return false }
    guard let top = topViewController() else { return false }
    let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    if let popover = controller.popoverPresentationController {
      popover.sourceView = top.view
      popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 1, height: 1)
      popover.permittedArrowDirections = []
    }
    top.present(controller, animated: true)
    return true
  }
}

extension AppDelegate {
  func registerIosDownloadBridge(_ registrar: FlutterPluginRegistrar) {
    LandeckDownloadManager.shared.register(with: registrar.messenger())
  }
}
