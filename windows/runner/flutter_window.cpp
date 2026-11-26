#include "flutter_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <shlobj.h>

#include <optional>
#include <cstring>
#include <limits>
#include <string>

#include "flutter/generated_plugin_registrant.h"

namespace {

struct GlobalMemoryDeleter {
  void operator()(void* memory) const { GlobalFree(memory); }
};

using ClipboardMemory = std::unique_ptr<void, GlobalMemoryDeleter>;

struct ClipboardCloser {
  ~ClipboardCloser() { CloseClipboard(); }
};

void CopyFileToClipboard(HWND owner, const std::string& path,
                         flutter::MethodResult<flutter::EncodableValue>* result) {
  if (path.empty() || path.find('\0') != std::string::npos ||
      path.size() > static_cast<size_t>((std::numeric_limits<int>::max)())) {
    result->Error("invalid_arguments", "Expected an absolute local file path.");
    return;
  }
  const int length = MultiByteToWideChar(
      CP_UTF8, MB_ERR_INVALID_CHARS, path.data(), static_cast<int>(path.size()),
      nullptr, 0);
  if (length == 0) {
    result->Error("invalid_arguments", "The file path is not valid UTF-8.");
    return;
  }
  std::wstring wide_path(length, L'\0');
  if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path.data(),
                          static_cast<int>(path.size()), wide_path.data(),
                          length) == 0) {
    result->Error("invalid_arguments", "The file path is not valid UTF-8.");
    return;
  }
  const auto is_separator = [](wchar_t character) {
    return character == L'\\' || character == L'/';
  };
  const bool drive_absolute =
      wide_path.size() >= 3 &&
      ((wide_path[0] >= L'A' && wide_path[0] <= L'Z') ||
       (wide_path[0] >= L'a' && wide_path[0] <= L'z')) &&
      wide_path[1] == L':' && is_separator(wide_path[2]);
  const bool unc_absolute = wide_path.size() > 2 &&
                            is_separator(wide_path[0]) &&
                            is_separator(wide_path[1]);
  if (!drive_absolute && !unc_absolute) {
    result->Error("invalid_arguments", "Expected an absolute local file path.");
    return;
  }
  if (GetFileAttributesW(wide_path.c_str()) == INVALID_FILE_ATTRIBUTES) {
    result->Error("file_not_found", "The file no longer exists or is inaccessible.");
    return;
  }

  const UINT drop_effect_format = RegisterClipboardFormatW(CFSTR_PREFERREDDROPEFFECT);
  ClipboardMemory files(GlobalAlloc(
      GMEM_MOVEABLE | GMEM_ZEROINIT,
      sizeof(DROPFILES) + (wide_path.size() + 2) * sizeof(wchar_t)));
  ClipboardMemory effect(GlobalAlloc(GMEM_MOVEABLE, sizeof(DWORD)));
  if (drop_effect_format == 0 || !files || !effect) {
    result->Error("clipboard_error", "Could not allocate file clipboard data.");
    return;
  }
  auto* drop = static_cast<DROPFILES*>(GlobalLock(files.get()));
  if (!drop) {
    result->Error("clipboard_error", "Could not access file clipboard data.");
    return;
  }
  drop->pFiles = sizeof(DROPFILES);
  drop->fWide = TRUE;
  // Preserve the selected path rather than resolving symlinks or copying files.
  std::memcpy(reinterpret_cast<char*>(drop) + sizeof(DROPFILES),
              wide_path.data(), wide_path.size() * sizeof(wchar_t));
  GlobalUnlock(files.get());
  auto* preferred_effect = static_cast<DWORD*>(GlobalLock(effect.get()));
  if (!preferred_effect) {
    result->Error("clipboard_error", "Could not access file clipboard data.");
    return;
  }
  *preferred_effect = DROPEFFECT_COPY;
  GlobalUnlock(effect.get());

  {
    if (!OpenClipboard(owner)) {
      result->Error("clipboard_error", "Could not open the clipboard.");
      return;
    }
    ClipboardCloser clipboard_closer;
    if (!EmptyClipboard() || !SetClipboardData(CF_HDROP, files.get())) {
      result->Error("clipboard_error", "Could not copy the file to the clipboard.");
      return;
    }
    // Successful SetClipboardData transfers ownership to Windows.
    files.release();
    if (!SetClipboardData(drop_effect_format, effect.get())) {
      EmptyClipboard();
      result->Error("clipboard_error", "Could not set the clipboard copy operation.");
      return;
    }
    effect.release();
  }
  result->Success();
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter::MethodChannel<> file_clipboard_channel(
      flutter_controller_->engine()->messenger(),
      "dev.0xfaced.lira/file_clipboard",
      &flutter::StandardMethodCodec::GetInstance());
  file_clipboard_channel.SetMethodCallHandler(
      [owner = GetHandle()](const flutter::MethodCall<>& call,
                            std::unique_ptr<flutter::MethodResult<>> result) {
        if (call.method_name() != "copyFile") {
          result->NotImplemented();
          return;
        }
        const auto* path = call.arguments()
                               ? std::get_if<std::string>(call.arguments())
                               : nullptr;
        if (!path) {
          result->Error("invalid_arguments",
                        "Expected an absolute local file path.");
          return;
        }
        CopyFileToClipboard(owner, *path, result.get());
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
