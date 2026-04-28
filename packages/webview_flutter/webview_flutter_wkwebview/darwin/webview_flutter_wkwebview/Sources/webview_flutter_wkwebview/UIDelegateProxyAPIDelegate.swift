// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import WebKit

/// Implementation of `WKUIDelegate` that calls to Dart in callback methods.
class UIDelegateImpl: NSObject, WKUIDelegate {
  let api: PigeonApiProtocolWKUIDelegate
  unowned let registrar: ProxyAPIRegistrar

  init(api: PigeonApiProtocolWKUIDelegate, registrar: ProxyAPIRegistrar) {
    self.api = api
    self.registrar = registrar
  }

  func webView(
    _ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
    for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures
  ) -> WKWebView? {
    registrar.dispatchOnMainThread { onFailure in
      self.api.onCreateWebView(
        pigeonInstance: self, webView: webView, configuration: configuration,
        navigationAction: navigationAction
      ) { result in
        if case .failure(let error) = result {
          onFailure("WKUIDelegate.onCreateWebView", error)
        }
      }
    }
    return nil
  }

  #if compiler(>=6.0)
    @available(iOS 15.0, macOS 12.0, *)
    func webView(
      _ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
      initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
      decisionHandler: @escaping @MainActor (WKPermissionDecision) -> Void
    ) {
      let wrapperCaptureType: MediaCaptureType
      switch type {
      case .camera:
        wrapperCaptureType = .camera
      case .microphone:
        wrapperCaptureType = .microphone
      case .cameraAndMicrophone:
        wrapperCaptureType = .cameraAndMicrophone
      @unknown default:
        wrapperCaptureType = .unknown
      }

      registrar.dispatchOnMainThread { onFailure in
        self.api.requestMediaCapturePermission(
          pigeonInstance: self, webView: webView, origin: origin, frame: frame,
          type: wrapperCaptureType
        ) { result in
          DispatchQueue.main.async {
            switch result {
            case .success(let decision):
              switch decision {
              case .deny:
                decisionHandler(.deny)
              case .grant:
                decisionHandler(.grant)
              case .prompt:
                decisionHandler(.prompt)
              }
            case .failure(let error):
              decisionHandler(.deny)
              onFailure("WKUIDelegate.requestMediaCapturePermission", error)
            }
          }
        }
      }
    }
  #else
    @available(iOS 15.0, macOS 12.0, *)
    func webView(
      _ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
      initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
      decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
      let wrapperCaptureType: MediaCaptureType
      switch type {
      case .camera:
        wrapperCaptureType = .camera
      case .microphone:
        wrapperCaptureType = .microphone
      case .cameraAndMicrophone:
        wrapperCaptureType = .cameraAndMicrophone
      @unknown default:
        wrapperCaptureType = .unknown
      }

      registrar.dispatchOnMainThread { onFailure in
        self.api.requestMediaCapturePermission(
          pigeonInstance: self, webView: webView, origin: origin, frame: frame,
          type: wrapperCaptureType
        ) { result in
          DispatchQueue.main.async {
            switch result {
            case .success(let decision):
              switch decision {
              case .deny:
                decisionHandler(.deny)
              case .grant:
                decisionHandler(.grant)
              case .prompt:
                decisionHandler(.prompt)
              }
            case .failure(let error):
              decisionHandler(.deny)
              onFailure("WKUIDelegate.requestMediaCapturePermission", error)
            }
          }
        }
      }
    }
  #endif

  // -- Start support for native js alert, confirm, prompt --
  #if os(iOS)
    private func topViewController() -> UIViewController? {
      guard let window = getCurrentWindow() else { return nil }
      return topViewController(from: window.rootViewController)
    }

    private func topViewController(from viewController: UIViewController?) -> UIViewController? {
      guard let vc = viewController else { return nil }
      if let presented = vc.presentedViewController {
        return topViewController(from: presented)
      } else if let tab = vc as? UITabBarController {
        return topViewController(from: tab.selectedViewController)
      } else if let nav = vc as? UINavigationController {
        return topViewController(from: nav.visibleViewController)
      }
      return vc
    }

    private func getCurrentWindow() -> UIWindow? {
      guard let window = UIApplication.shared.keyWindow else { return nil }
      if window.windowLevel != .normal {
        for w in UIApplication.shared.windows where w.windowLevel == .normal {
          return w
        }
      }
      return window
    }
  #endif

  #if compiler(>=6.0)
    func webView(
      _ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
      initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor () -> Void
    ) {
      #if os(iOS)
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(
          UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .cancel) { _ in
            completionHandler()
          })
        topViewController()?.present(alert, animated: true, completion: nil)
      #else
        completionHandler()
      #endif
    }
  #else
    func webView(
      _ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
      initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void
    ) {
      #if os(iOS)
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(
          UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .cancel) { _ in
            completionHandler()
          })
        topViewController()?.present(alert, animated: true, completion: nil)
      #else
        completionHandler()
      #endif
    }
  #endif

  #if compiler(>=6.0)
    func webView(
      _ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
      initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor (Bool) -> Void
    ) {
      #if os(iOS)
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(
          UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
            completionHandler(false)
          })
        alert.addAction(
          UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in
            completionHandler(true)
          })
        topViewController()?.present(alert, animated: true, completion: nil)
      #else
        completionHandler(false)
      #endif
    }
  #else
    func webView(
      _ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
      initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void
    ) {
      #if os(iOS)
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(
          UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
            completionHandler(false)
          })
        alert.addAction(
          UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in
            completionHandler(true)
          })
        topViewController()?.present(alert, animated: true, completion: nil)
      #else
        completionHandler(false)
      #endif
    }
  #endif

  #if compiler(>=6.0)
    func webView(
      _ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
      defaultText: String?, initiatedByFrame frame: WKFrameInfo,
      completionHandler: @escaping @MainActor (String?) -> Void
    ) {
      #if os(iOS)
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { textField in
          textField.placeholder = prompt
          textField.isSecureTextEntry = false
          textField.text = defaultText
        }
        alert.addAction(
          UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
            completionHandler(nil)
          })
        alert.addAction(
          UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in
            completionHandler(alert.textFields?.first?.text)
          })
        topViewController()?.present(alert, animated: true, completion: nil)
      #else
        completionHandler(nil)
      #endif
    }
  #else
    func webView(
      _ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
      defaultText: String?, initiatedByFrame frame: WKFrameInfo,
      completionHandler: @escaping (String?) -> Void
    ) {
      #if os(iOS)
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { textField in
          textField.placeholder = prompt
          textField.isSecureTextEntry = false
          textField.text = defaultText
        }
        alert.addAction(
          UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
            completionHandler(nil)
          })
        alert.addAction(
          UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in
            completionHandler(alert.textFields?.first?.text)
          })
        topViewController()?.present(alert, animated: true, completion: nil)
      #else
        completionHandler(nil)
      #endif
    }
  #endif
  // -- End support for native js alert, confirm, prompt --
}

/// ProxyApi implementation for `WKUIDelegate`.
///
/// This class may handle instantiating native object instances that are attached to a Dart instance
/// or handle method calls on the associated native class or an instance of that class.
class UIDelegateProxyAPIDelegate: PigeonApiDelegateWKUIDelegate {
  func pigeonDefaultConstructor(pigeonApi: PigeonApiWKUIDelegate) throws -> WKUIDelegate {
    return UIDelegateImpl(
      api: pigeonApi, registrar: pigeonApi.pigeonRegistrar as! ProxyAPIRegistrar)
  }
}
