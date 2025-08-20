//
//  CoreDataManager.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/20.
//

import CoreData


// MARK: - CoreDataManager
final class CoreDataManager {
    // MARK: - Singleton
    static let shared = CoreDataManager()
    
    // MARK: - Core Data Stack
    let container: NSPersistentContainer
    var context: NSManagedObjectContext { container.viewContext }
    
    private init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "GallerySelect")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    // MARK: - Preview / Sample Data
    @MainActor
    static var preview: CoreDataManager = {
        let manager = CoreDataManager(inMemory: true)
        let context = manager.context
        
        // サンプルの Item データを10件作成
        for _ in 0..<10 {
            let newItem = Item(context: context)
            newItem.timestamp = Date()
        }
        
        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        
        return manager
    }()
}
