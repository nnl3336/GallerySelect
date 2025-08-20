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
    @StateObject private var foldercontroller: FolderController

    init() {
        let context = persistenceController.container.viewContext
        _photoController = StateObject(wrappedValue: PhotoController(context: context))
        _foldercontroller = StateObject(wrappedValue: FolderController(context: context))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(photocontroller: photoController, foldercontroller: foldercontroller)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
