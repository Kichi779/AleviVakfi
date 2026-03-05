import UIKit
import Flutter
import OneSignalFramework // <-- KRİTİK: Bu satırı ekliyoruz

@main
class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // --- ONESIGNAL BAŞLATMA ---
    // Uygulama açılırken iOS bildirim sistemini OneSignal'a bağlar.
    OneSignal.initialize("0e1426f3-843b-4e98-8fa2-87ee35839a88", withLaunchOptions: launchOptions)

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
