import SwiftUI

@main
struct DesktopPetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            Text("DesktopPet 설정")
                .frame(width: 200, height: 100)
        }
    }
}
