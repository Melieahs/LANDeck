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

  func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
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

  func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
    FlutterStandardMessageCodec.sharedInstance()
  }
}
