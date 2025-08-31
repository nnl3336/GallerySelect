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
    @StateObject private var folderController: FolderController

    init() {
        let context = persistenceController.container.viewContext
        _photoController = StateObject(wrappedValue: PhotoController(context: context))
        _folderController = StateObject(wrappedValue: FolderController(context: context))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                photoController: photoController,
                folderController: folderController
            )
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

