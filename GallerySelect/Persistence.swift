//
//  Persistence.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/15.
//

import CoreData

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "GallerySelect")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Application Support ディレクトリ
            let appSupportURL = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first!
            
            // ディレクトリがなければ作成
            do {
                try FileManager.default.createDirectory(at: appSupportURL,
                                                        withIntermediateDirectories: true,
                                                        attributes: nil)
            } catch {
                fatalError("Unable to create Application Support directory: \(error)")
            }

            // SQLite ファイルパス
            let storeURL = appSupportURL.appendingPathComponent("GallerySelect.sqlite")
            container.persistentStoreDescriptions.first?.url = storeURL
        }

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            } else {
                print("Core Data store loaded at: \(storeDescription.url?.path ?? "unknown path")")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}

