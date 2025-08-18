//
//  GallerySelectApp.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/15.
//

import SwiftUI

@main
struct GallerySelectApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var photoController: PhotoController

    init() {
        let context = persistenceController.container.viewContext
        _photoController = StateObject(wrappedValue: PhotoController(context: context))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(controller: photoController)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
