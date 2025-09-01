//
//  ObservableObject.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/17.
//

import SwiftUI
import CoreData
import Photos

// MARK: - ViewModel (CoreData + FRC)
class PhotoFRCController: NSObject, ObservableObject, NSFetchedResultsControllerDelegate {
    private let context: NSManagedObjectContext
    var frc: NSFetchedResultsController<Photo>!
    private weak var collectionView: UICollectionView?

    init(context: NSManagedObjectContext) {
        self.context = context
        super.init()
        setupFRC()
    }

    private func setupFRC() {
        let request: NSFetchRequest<Photo> = Photo.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Photo.creationDate, ascending: true)]
        request.fetchBatchSize = 50

        frc = NSFetchedResultsController(fetchRequest: request,
                                         managedObjectContext: context,
                                         sectionNameKeyPath: nil,
                                         cacheName: nil)
        frc.delegate = self

        do {
            try frc.performFetch()
        } catch {
            print("FRC fetch error: \(error)")
        }
    }
    
    // 公開用配列
    var photos: [Photo] {
        frc.fetchedObjects ?? []
    }

    // MARK: - Public API
    func attach(collectionView: UICollectionView) {
        self.collectionView = collectionView
        collectionView.reloadData()
    }

    var numberOfItems: Int {
        frc.fetchedObjects?.count ?? 0
    }

    func photo(at index: Int) -> Photo? {
        frc.fetchedObjects?[index]
    }

    func delete(_ photo: Photo) {
        context.delete(photo)
        do {
            try context.save()
        } catch {
            print("Delete failed: \(error)")
        }
    }

    // MARK: - NSFetchedResultsControllerDelegate
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        collectionView?.reloadData()
    }
}

//

class PhotoSliderViewModel: ObservableObject {
    @Published var localNotes: [Int: String] = [:]
    @Published var localLikes: [Int: Bool] = [:]
    
    private(set) var thumbnailCache: [Int: UIImage] = [:]
    private(set) var fullImageCache: [Int: UIImage] = [:]
    
    // サムネイルを返す（スクロール用）
    func cachedThumbnail(for index: Int, photos: [Photo]) -> UIImage {
        if let img = thumbnailCache[index] {
            return img
        }
        if let data = photos[index].thumbnailData,  // ← CoreData に保存した縮小版
           let img = UIImage(data: data) {
            thumbnailCache[index] = img
            return img
        }
        return UIImage()
    }
    
    // フル画像を返す（拡大表示用）
    func cachedFullImage(for index: Int, photos: [Photo]) -> UIImage {
        if let img = fullImageCache[index] {
            return img
        }
        if let data = photos[index].fullImageData,  // ← CoreData に保存した高画質版
           let img = UIImage(data: data) {
            fullImageCache[index] = img
            return img
        }
        return UIImage()
    }
}


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

    /*private*/ let context: NSManagedObjectContext
    private let frc: NSFetchedResultsController<Photo>
        
    //***

    init(context: NSManagedObjectContext) {
            self.context = context
            
            let request: NSFetchRequest<Photo> = Photo.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Photo.creationDate, ascending: true)]
            request.fetchBatchSize = 20
            
            frc = NSFetchedResultsController(
                fetchRequest: request,
                managedObjectContext: context,
                sectionNameKeyPath: nil,
                cacheName: nil
            )
            
            super.init()
            frc.delegate = self
            try? frc.performFetch()
            photos = frc.fetchedObjects ?? []
        }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        photos = frc.fetchedObjects ?? []
        
        guard let updatedPhotos = controller.fetchedObjects as? [Photo] else { return }
        DispatchQueue.main.async {
            self.photos = updatedPhotos
        }
    }
    
    //***
    
    func photo(at indexPath: IndexPath) -> Photo {
        return frc.object(at: indexPath)
    }
    
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
        
        // 高画質（フルサイズ）
        newPhoto.fullImageData = image.jpegData(compressionQuality: 0.9)
        
        // サムネイル（スクロール用に縮小）
        let thumb = image.resize(to: CGSize(width: 200, height: 200))
        newPhoto.thumbnailData = thumb.jpegData(compressionQuality: 0.7)
        
        do {
            try context.save()
            photos.append(newPhoto)
        } catch {
            print("CoreData save error: \(error.localizedDescription)")
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
}
