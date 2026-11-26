import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var fileClipboardChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "dev.0xfaced.lira/file_clipboard",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "copyFile" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let path = call.arguments as? String,
            path.hasPrefix("/"),
            !path.contains("\0") else {
        result(FlutterError(
          code: "invalid_arguments",
          message: "Expected an absolute local file path.",
          details: nil
        ))
        return
      }
      guard FileManager.default.fileExists(atPath: path) else {
        result(FlutterError(
          code: "file_not_found",
          message: "The file no longer exists.",
          details: nil
        ))
        return
      }

      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      // Keep the selected path, including aliases/symlinks, rather than resolving it.
      guard pasteboard.writeObjects([NSURL(fileURLWithPath: path)]) else {
        result(FlutterError(
          code: "clipboard_error",
          message: "Could not copy the file to the clipboard.",
          details: nil
        ))
        return
      }
      result(nil)
    }
    fileClipboardChannel = channel

    super.awakeFromNib()
  }
}
