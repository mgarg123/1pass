import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var visualEffectView: UIVisualEffectView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  override func applicationWillResignActive(_ application: UIApplication) {
      guard let window = self.window else { return }
      
      let blurEffect = UIBlurEffect(style: .dark)
      let blurEffectView = UIVisualEffectView(effect: blurEffect)
      blurEffectView.frame = window.bounds
      blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      
      self.visualEffectView = blurEffectView
      window.addSubview(blurEffectView)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
      if let visualEffectView = self.visualEffectView {
          visualEffectView.removeFromSuperview()
          self.visualEffectView = nil
      }
  }
}
