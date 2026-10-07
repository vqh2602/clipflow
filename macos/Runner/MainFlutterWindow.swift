import Cocoa
import FlutterMacOS
import ServiceManagement
import Accessibility
import Carbon
import Vision

class MainFlutterWindow: NSWindow {
  private var standardStyleMask: NSWindow.StyleMask = []
  private var standardCollectionBehavior: NSWindow.CollectionBehavior = []
  private var standardBackgroundColor: NSColor = .windowBackgroundColor
  private var standardIsOpaque = true
  private var standardHasShadow = true
  private var standardIsMovable = true
  private var standardSharingType: NSWindow.SharingType = .readOnly
  private var previousApplication: NSRunningApplication?
  private var lastActiveApplication: NSRunningApplication?
  private var isTouchNotchMode = false

  override var canBecomeKey: Bool {
    return true
  }

  override var canBecomeMain: Bool {
    return true
  }

  override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
    if self.isTouchNotchMode {
      return frameRect
    }
    return super.constrainFrameRect(frameRect, to: screen)
  }

  private func getNotchScreen() -> NSScreen {
    if #available(macOS 12.0, *) {
      for s in NSScreen.screens {
        if s.safeAreaInsets.top > 0 {
          return s
        }
      }
    }
    return NSScreen.screens.first ?? NSScreen.main ?? NSScreen()
  }

  func positionAtNotch(width: CGFloat, height: CGFloat, topOffset: CGFloat) {
    let screen = self.getNotchScreen()
    let screenFrame = screen.frame
    let x = screenFrame.origin.x + (screenFrame.width - width) / 2.0
    let y = screenFrame.origin.y + screenFrame.height - topOffset - height
    let targetFrame = NSRect(x: x, y: y, width: width, height: height)
    self.setFrame(targetFrame, display: true, animate: false)
  }

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    flutterViewController.backgroundColor = .windowBackgroundColor
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    standardStyleMask = self.styleMask
    standardCollectionBehavior = self.collectionBehavior
    standardBackgroundColor = self.backgroundColor
    standardIsOpaque = self.isOpaque
    standardHasShadow = self.hasShadow
    standardIsMovable = self.isMovable
    standardSharingType = self.sharingType
    Self.migrateLegacySandboxPreferences()

    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(handleAppActivation(_:)),
      name: NSWorkspace.didActivateApplicationNotification,
      object: nil
    )

    RegisterGeneratedPlugins(registry: flutterViewController)

    let clipboardChannel = FlutterMethodChannel(
      name: "clipflow/clipboard",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    clipboardChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "readClipboard":
        let pasteboard = NSPasteboard.general
        var response: [String: Any] = [:]
        // changeCount is the most reliable signal for any clipboard change
        // (covers Cmd+C, right-click Copy, app copy buttons, etc.)
        response["changeCount"] = pasteboard.changeCount
        let fileURLs = pasteboard.readObjects(
          forClasses: [NSURL.self],
          options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []
        let filePaths = fileURLs.filter(\.isFileURL).map(\.path)
        if !filePaths.isEmpty {
          response["filePaths"] = filePaths
          response["text"] = filePaths.joined(separator: "\n")
        } else {
          if let text = pasteboard.string(forType: .string) {
            response["text"] = text
          }
          if let pngData = pasteboard.data(forType: .png) ?? Self.pngDataFromTiff(pasteboard) {
            response["imageBase64"] = pngData.base64EncodedString()
          }
        }
        // Use lastActiveApplication (cached before we take focus) for accurate source tracking
        if let app = self.lastActiveApplication ?? NSWorkspace.shared.frontmostApplication {
          response["sourceAppName"] = app.localizedName
          response["sourceAppIdentifier"] = app.bundleIdentifier
          response["sensitiveContext"] = Self.isSensitiveContext(app)
        }
        result(response)
      case "writeText":
        guard
          let arguments = call.arguments as? [String: Any],
          let text = arguments["text"] as? String
        else {
          result(FlutterError(code: "invalid_arguments", message: "Missing text", details: nil))
          return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        result(nil)
      case "writeImage":
        guard
          let arguments = call.arguments as? [String: Any],
          let imageBase64 = arguments["imageBase64"] as? String,
          let imageData = Data(base64Encoded: imageBase64)
        else {
          result(FlutterError(code: "invalid_arguments", message: "Missing image", details: nil))
          return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(imageData, forType: .png)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let ocrChannel = FlutterMethodChannel(
      name: "clipflow/ocr",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    ocrChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "performOcr":
        guard
          let arguments = call.arguments as? [String: Any],
          let imagePath = arguments["imagePath"] as? String
        else {
          result(FlutterError(code: "invalid_arguments", message: "Missing imagePath", details: nil))
          return
        }

        guard let nsImage = NSImage(contentsOfFile: imagePath),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
          result(FlutterError(code: "invalid_image", message: "Could not load image file", details: nil))
          return
        }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { request, error in
          if let error = error {
            DispatchQueue.main.async {
              result(FlutterError(code: "ocr_failed", message: error.localizedDescription, details: nil))
            }
            return
          }
          guard let observations = request.results as? [VNRecognizedTextObservation] else {
            DispatchQueue.main.async {
              result("")
            }
            return
          }
          let recognizedStrings = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
          }
          let fullText = recognizedStrings.joined(separator: "\n")
          DispatchQueue.main.async {
            result(fullText)
          }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        DispatchQueue.global(qos: .userInitiated).async {
          do {
            try requestHandler.perform([request])
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(code: "ocr_error", message: error.localizedDescription, details: nil))
            }
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let startupChannel = FlutterMethodChannel(
      name: "launch_at_startup",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    startupChannel.setMethodCallHandler { call, result in
      guard #available(macOS 13.0, *) else {
        result(
          FlutterError(
            code: "unsupported_macos_version",
            message: "Launch at login requires macOS 13 or later.",
            details: nil
          )
        )
        return
      }

      switch call.method {
      case "launchAtStartupIsEnabled":
        result(SMAppService.mainApp.status == .enabled)
      case "launchAtStartupStatus":
        result(Self.launchAtStartupStatus())
      case "launchAtStartupSetEnabled":
        guard
          let arguments = call.arguments as? [String: Any],
          let shouldEnable = arguments["setEnabledValue"] as? Bool
        else {
          result(
            FlutterError(
              code: "invalid_arguments",
              message: "Missing setEnabledValue.",
              details: nil
            )
          )
          return
        }

        do {
          let service = SMAppService.mainApp
          if shouldEnable {
            if service.status != .enabled && service.status != .requiresApproval {
              try service.register()
            }
          } else if service.status != .notRegistered {
            try service.unregister()
          }
          result(nil)
        } catch {
          result(
            FlutterError(
              code: "launch_at_login_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let windowChannel = FlutterMethodChannel(
      name: "clipflow/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    windowChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterMethodNotImplemented)
        return
      }

      switch call.method {
      case "setQuickPanelMode":
        guard let enabled = call.arguments as? Bool else {
          result(
            FlutterError(
              code: "invalid_arguments",
              message: "Expected a boolean quick-panel state.",
              details: nil
            )
          )
          return
        }

        if enabled {
          if
            let frontmostApplication = NSWorkspace.shared.frontmostApplication,
            frontmostApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier
          {
            self.previousApplication = frontmostApplication
            self.lastActiveApplication = frontmostApplication
          }
          flutterViewController.backgroundColor = .clear
          self.isOpaque = false
          self.backgroundColor = .clear
          self.hasShadow = false
          self.isMovable = false
          self.level = .popUpMenu
          self.hidesOnDeactivate = true
          self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient,
            .stationary,
            .ignoresCycle,
          ]
        } else {
          flutterViewController.backgroundColor = .windowBackgroundColor
          self.isOpaque = self.standardIsOpaque
          self.backgroundColor = self.standardBackgroundColor
          self.hasShadow = self.standardHasShadow
          self.isMovable = self.standardIsMovable
          self.level = .normal
          self.hidesOnDeactivate = false
          self.collectionBehavior = self.standardCollectionBehavior
        }
        result(nil)
      case "setTouchNotchMode":
        var enabled = false
        var width: CGFloat = 260
        var height: CGFloat = 36
        var isDynamicIsland = false

        if let boolVal = call.arguments as? Bool {
          enabled = boolVal
        } else if let dict = call.arguments as? [String: Any] {
          enabled = dict["enabled"] as? Bool ?? false
          width = CGFloat((dict["width"] as? NSNumber)?.doubleValue ?? 260)
          height = CGFloat((dict["height"] as? NSNumber)?.doubleValue ?? 36)
          isDynamicIsland = dict["isDynamicIsland"] as? Bool ?? false
        }

        self.isTouchNotchMode = enabled
        if enabled {
          if
            let frontmostApplication = NSWorkspace.shared.frontmostApplication,
            frontmostApplication.processIdentifier != ProcessInfo.processInfo.processIdentifier
          {
            self.previousApplication = frontmostApplication
            self.lastActiveApplication = frontmostApplication
          }
          flutterViewController.backgroundColor = .clear
          self.styleMask = [.borderless]
          self.isOpaque = false
          self.backgroundColor = .clear
          self.hasShadow = false
          self.isMovable = false
          self.level = .statusBar
          self.hidesOnDeactivate = false
          self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
          ]

          let topOffset: CGFloat = isDynamicIsland ? 8.0 : 0.0
          self.positionAtNotch(width: width, height: height, topOffset: topOffset)
        } else {
          flutterViewController.backgroundColor = .windowBackgroundColor
          self.styleMask = self.standardStyleMask
          self.isOpaque = self.standardIsOpaque
          self.backgroundColor = self.standardBackgroundColor
          self.hasShadow = self.standardHasShadow
          self.isMovable = self.standardIsMovable
          self.level = .normal
          self.hidesOnDeactivate = false
          self.collectionBehavior = self.standardCollectionBehavior
        }
        result(nil)
      case "updateNotchBounds":
        guard let args = call.arguments as? [String: Any],
              let width = (args["width"] as? NSNumber)?.doubleValue,
              let height = (args["height"] as? NSNumber)?.doubleValue
        else {
          result(nil)
          return
        }
        let isDynamicIsland = args["isDynamicIsland"] as? Bool ?? false
        let topOffset: CGFloat = isDynamicIsland ? 8.0 : 0.0
        self.positionAtNotch(width: CGFloat(width), height: CGFloat(height), topOffset: topOffset)
        result(nil)
      case "getNotchInfo":
        let mouseLoc = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens.first
        var topInset: CGFloat = 0
        var width: CGFloat = 1728
        var height: CGFloat = 1117
        var x: CGFloat = 0
        if let s = targetScreen {
          width = s.frame.width
          height = s.frame.height
          x = s.frame.origin.x
          if #available(macOS 12.0, *) {
            topInset = s.safeAreaInsets.top
          }
        }
        result([
          "x": Double(x),
          "width": Double(width),
          "height": Double(height),
          "topInset": Double(topInset),
          "hasNotch": topInset > 0,
        ])
      case "setShowInDock":
        guard let show = call.arguments as? Bool else {
          result(
            FlutterError(
              code: "invalid_arguments",
              message: "Expected a boolean showInDock state.",
              details: nil
            )
          )
          return
        }
        NSApp.setActivationPolicy(show ? .regular : .accessory)
        if show {
          NSApp.activate(ignoringOtherApps: true)
        }
        result(nil)
      case "setCaptureProtection":
        guard let enabled = call.arguments as? Bool else {
          result(
            FlutterError(
              code: "invalid_arguments",
              message: "Expected a boolean capture-protection state.",
              details: nil
            )
          )
          return
        }
        self.sharingType = enabled ? .none : self.standardSharingType
        result(nil)
      case "isSensitiveContext":
        guard let application = NSWorkspace.shared.frontmostApplication else {
          result(false)
          return
        }
        result(Self.isSensitiveContext(application))
      case "checkAccessibilityPermission":
        result(AXIsProcessTrusted())
      case "requestAccessibilityPermission":
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
          if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
          }
        }
        result(trusted)
      case "resetAccessibilityPermission":
        let bundleID = Bundle.main.bundleIdentifier ?? "com.clipflow.clipflow"
        let task = Process()
        task.launchPath = "/usr/bin/tccutil"
        task.arguments = ["reset", "Accessibility", bundleID]
        try? task.run()
        task.waitUntilExit()
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
          NSWorkspace.shared.open(url)
        }
        result(true)
      case "getRunningApplications":
        self.getRunningApplications(result: result)
      case "pickApplicationFile":
        self.pickApplicationFile(result: result)
      case "saveConfigFile":
        let defaultName = (call.arguments as? [String: Any])?["defaultName"] as? String ?? "clipflow_config.clipflow"
        self.saveConfigFile(defaultName: defaultName, result: result)
      case "pickConfigFile":
        self.pickConfigFile(result: result)
      case "pasteToPreviousApplication":
        self.pasteToPreviousApplication(result: result)
      case "openUrl":
        guard
          let arguments = call.arguments as? [String: Any],
          let urlString = arguments["url"] as? String,
          let url = URL(string: urlString)
        else {
          result(FlutterError(code: "invalid_arguments", message: "Missing url", details: nil))
          return
        }
        NSWorkspace.shared.open(url)
        result(nil)
      case "getAppBundlePath":
        result(Bundle.main.bundlePath)
      case "restartApp":
        let bundleUrl = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: bundleUrl, configuration: configuration) { _, _ in
          DispatchQueue.main.async {
            NSApp.terminate(nil)
          }
        }
        result(nil)
      case "mediaControl":
        guard let action = call.arguments as? String else {
          result(nil)
          return
        }
        self.handleMediaControl(action: action)
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }

  @objc private func handleAppActivation(_ notification: Notification) {
    guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
      return
    }
    if app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
      self.lastActiveApplication = app
      self.previousApplication = app
    }
  }

  private static func isSensitiveContext(_ application: NSRunningApplication) -> Bool {
    // Browsers enable Secure Event Input while a password control is focused.
    // Check it before Accessibility so protection still works when AX access
    // has not been granted yet.
    if IsSecureEventInputEnabled() {
      return true
    }
    guard AXIsProcessTrusted() else { return false }
    let applicationElement = AXUIElementCreateApplication(application.processIdentifier)

    var focusedValue: CFTypeRef?
    if AXUIElementCopyAttributeValue(
      applicationElement,
      kAXFocusedUIElementAttribute as CFString,
      &focusedValue
    ) == .success, let focusedElement = focusedValue as! AXUIElement? {
      var roleValue: CFTypeRef?
      if AXUIElementCopyAttributeValue(
        focusedElement,
        kAXRoleAttribute as CFString,
        &roleValue
      ) == .success,
        let role = roleValue as? String,
        role == "AXSecureTextField"
      {
        return true
      }
    }

    var windowValue: CFTypeRef?
    guard AXUIElementCopyAttributeValue(
      applicationElement,
      kAXFocusedWindowAttribute as CFString,
      &windowValue
    ) == .success,
      let focusedWindow = windowValue as! AXUIElement?
    else {
      return false
    }
    var titleValue: CFTypeRef?
    guard AXUIElementCopyAttributeValue(
      focusedWindow,
      kAXTitleAttribute as CFString,
      &titleValue
    ) == .success,
      let title = (titleValue as? String)?.lowercased()
    else {
      return false
    }
    let sensitiveTitles = [
      "password", "passcode", "sign in", "log in", "login", "authentication",
      "verify identity", "payment", "banking", "mật khẩu", "đăng nhập", "xác thực",
      "thanh toán", "ngân hàng"
    ]
    return sensitiveTitles.contains { title.contains($0) }
  }

  private static func pngDataFromTiff(_ pasteboard: NSPasteboard) -> Data? {
    guard
      let tiffData = pasteboard.data(forType: .tiff),
      let representation = NSBitmapImageRep(data: tiffData)
    else {
      return nil
    }
    return representation.representation(using: .png, properties: [:])
  }

  private static func migrateLegacySandboxPreferences() {
    let settingsKey = "flutter.clipflow.settings.v1"
    let defaults = UserDefaults.standard
    guard defaults.object(forKey: settingsKey) == nil else { return }

    let legacyPreferencesURL = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library")
      .appendingPathComponent("Containers")
      .appendingPathComponent("com.clipflow.clipflow")
      .appendingPathComponent("Data")
      .appendingPathComponent("Library")
      .appendingPathComponent("Preferences")
      .appendingPathComponent("com.clipflow.clipflow.plist")
    guard
      let preferences = NSDictionary(contentsOf: legacyPreferencesURL),
      let settings = preferences[settingsKey]
    else {
      return
    }
    defaults.set(settings, forKey: settingsKey)
  }

  private func pasteToPreviousApplication(result: @escaping FlutterResult) {
    guard AXIsProcessTrusted() else {
      let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
      AXIsProcessTrustedWithOptions(options)
      result(false)
      return
    }

    let myPid = ProcessInfo.processInfo.processIdentifier
    var targetApplication: NSRunningApplication? = lastActiveApplication ?? previousApplication

    if targetApplication == nil || targetApplication?.isTerminated == true || targetApplication?.processIdentifier == myPid {
      targetApplication = NSWorkspace.shared.runningApplications.first { app in
        app.activationPolicy == .regular &&
        app.processIdentifier != myPid &&
        !app.isTerminated
      }
    }

    guard let appToActivate = targetApplication, !appToActivate.isTerminated else {
      result(false)
      return
    }

    appToActivate.activate(options: [.activateIgnoringOtherApps])
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
      let source = CGEventSource(stateID: .hidSystemState)
      guard
        let keyDown = CGEvent(
          keyboardEventSource: source,
          virtualKey: 9,
          keyDown: true
        ),
        let keyUp = CGEvent(
          keyboardEventSource: source,
          virtualKey: 9,
          keyDown: false
        )
      else {
        result(false)
        return
      }
      keyDown.flags = .maskCommand
      keyUp.flags = .maskCommand
      keyDown.post(tap: .cghidEventTap)
      keyUp.post(tap: .cghidEventTap)
      result(true)
    }
  }

  private func getRunningApplications(result: @escaping FlutterResult) {
    let runningApps = NSWorkspace.shared.runningApplications.filter { app in
      app.activationPolicy == .regular &&
      app.processIdentifier != ProcessInfo.processInfo.processIdentifier
    }
    var seenNames = Set<String>()
    let appsData: [[String: String]] = runningApps.compactMap { app in
      guard let name = app.localizedName, !name.isEmpty else { return nil }
      if seenNames.contains(name) { return nil }
      seenNames.insert(name)
      return [
        "name": name,
        "bundleId": app.bundleIdentifier ?? ""
      ]
    }
    result(appsData)
  }

  private func pickApplicationFile(result: @escaping FlutterResult) {
    let openPanel = NSOpenPanel()
    openPanel.canChooseFiles = true
    openPanel.canChooseDirectories = true
    openPanel.allowsMultipleSelection = false
    openPanel.allowedFileTypes = ["app"]
    openPanel.directoryURL = URL(fileURLWithPath: "/Applications")
    openPanel.begin { response in
      if response == .OK, let url = openPanel.url {
        let bundle = Bundle(url: url)
        let appName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
          ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
          ?? url.deletingPathExtension().lastPathComponent
        let bundleId = bundle?.bundleIdentifier ?? ""
        result([
          "name": appName,
          "bundleId": bundleId,
          "path": url.path
        ])
      } else {
        result(nil)
      }
    }
  }

  private func saveConfigFile(defaultName: String, result: @escaping FlutterResult) {
    let savePanel = NSSavePanel()
    savePanel.canCreateDirectories = true
    savePanel.nameFieldStringValue = defaultName
    savePanel.allowedFileTypes = ["clipflow"]
    savePanel.begin { response in
      if response == .OK, let url = savePanel.url {
        result(url.path)
      } else {
        result(nil)
      }
    }
  }

  private func pickConfigFile(result: @escaping FlutterResult) {
    let openPanel = NSOpenPanel()
    openPanel.canChooseFiles = true
    openPanel.canChooseDirectories = false
    openPanel.allowsMultipleSelection = false
    openPanel.allowedFileTypes = ["clipflow"]
    openPanel.begin { response in
      if response == .OK, let url = openPanel.url {
        result(url.path)
      } else {
        result(nil)
      }
    }
  }

  @available(macOS 13.0, *)
  private static func launchAtStartupStatus() -> String {
    switch SMAppService.mainApp.status {
    case .notRegistered:
      return "notRegistered"
    case .enabled:
      return "enabled"
    case .requiresApproval:
      return "requiresApproval"
    case .notFound:
      return "notFound"
    @unknown default:
      return "unknown"
    }
  }

  private func handleMediaControl(action: String) {
    let script: String
    switch action {
    case "play":
      script = "tell application \"Spotify\" to play"
    case "pause":
      script = "tell application \"Spotify\" to pause"
    case "next":
      script = "tell application \"Spotify\" to next track"
    case "previous":
      script = "tell application \"Spotify\" to previous track"
    default:
      return
    }
    if let scriptObject = NSAppleScript(source: script) {
      var errorDict: NSDictionary?
      scriptObject.executeAndReturnError(&errorDict)
    }
  }
}
