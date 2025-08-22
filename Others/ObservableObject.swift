//
//  ObservableObject.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/17.
//

import SwiftUI
import CoreData
import Photos

// MARK: - FolderController
class FolderController: NSObject, ObservableObject {
    @Published var folders: [Folder] = []

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
        super.init()
        fetchFolders()
    }

    func fetchFolders() {
        let request: NSFetchRequest<Folder> = Folder.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        do {
            folders = try context.fetch(request)
        } catch {
            print("Folder fetch error: \(error)")
        }
    }

    func createFolder(with selectedPhotos: [Photo], name: String) {
        let newFolder = Folder(context: context)
        newFolder.name = name
        newFolder.addToPhotos(NSSet(array: selectedPhotos))
        
        do {
            try context.save()
            fetchFolders() // 更新
        } catch {
            print("Folder save error: \(error)")
        }
    }

    func deleteFolder(_ folder: Folder) {
        context.delete(folder)
        do {
            try context.save()
            fetchFolders()
        } catch {
            print("Failed to delete folder: \(error)")
        }
    }
}
// MARK: - FRCラッパークラス
class PhotoController: NSObject, ObservableObject, NSFetchedResultsControllerDelegate {
    @Published var photos: [Photo] = []

    private let context: NSManagedObjectContext
    private let frc: NSFetchedResultsController<Photo>
    
    //***

    init(context: NSManagedObjectContext) {
        self.context = context
        
        let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Photo.creationDate, ascending: true)]
        fetchRequest.fetchBatchSize = 20
        
        frc = NSFetchedResultsController(fetchRequest: fetchRequest,
                                         managedObjectContext: context,
                                         sectionNameKeyPath: nil,
                                         cacheName: nil)
        super.init()
        frc.delegate = self
        
        do {
            try frc.performFetch()
            photos = frc.fetchedObjects ?? []
        } catch {
            print("Fetch error: \(error)")
        }
    }
    
    //***
    
    // フィルタ適用
        func applyFilter(keyword: String, likedOnly: Bool) {
            var predicates: [NSPredicate] = []

            if !keyword.isEmpty {
                predicates.append(NSPredicate(format: "note CONTAINS[cd] %@", keyword))
            }
            if likedOnly {
                predicates.append(NSPredicate(format: "isLiked == true"))
            }

            let compound = predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            fetchPhotos(predicate: compound)
        }

        // fetchPhotosもちゃんと public/internal である必要あり
        func fetchPhotos(predicate: NSPredicate? = nil) {
            let request: NSFetchRequest<Photo> = Photo.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            request.predicate = predicate

            do {
                photos = try context.fetch(request)
            } catch {
                print("Fetch error: \(error)")
            }
        }

    func addPhoto(_ image: UIImage, creationDate: Date = Date()) {
        let newPhoto = Photo(context: context)
        newPhoto.id = UUID()
        newPhoto.creationDate = creationDate
        newPhoto.imageData = image.jpegData(compressionQuality: 0.8)
        
        do {
            try context.save()
            photos.append(newPhoto)
        } catch {
            print(error)
        }
    }

    func deletePhoto(at index: Int) {
        let photo = photos[index]
        context.delete(photo)
        do {
            try context.save()
            photos.remove(at: index)
        } catch {
            print(error)
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        guard let updatedPhotos = controller.fetchedObjects as? [Photo] else { return }
        DispatchQueue.main.async {
            self.photos = updatedPhotos
        }
    }
}
