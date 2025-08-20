//
//  ObservableObject.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/17.
//

import SwiftUI
import CoreData
import Photos

//廃止
/*class MainViewModel: ObservableObject {
    // MARK: - UI State
    @Published var selectedIndex: Int? = nil
    @Published var selectedPhotos: Set<Int> = []
    @Published var showPicker: Bool = false
    @Published var showSearch: Bool = false
    @Published var showFolderSheet: Bool = false
    @Published var showAlbum: Bool = false
    @Published var segmentSelection: Int = 2
    @Published var showFastScroll: Bool = false
    @Published var dragPosition: CGFloat = 0

    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    let segments = ["後ろの月", "前の月", "すべての写真"]

    // MARK: - Photos
    @Published var allPhotos: [Photo] = [] {
        didSet { applyFilter() }
    }
    @Published var filteredPhotos: [Photo] = []
    @Published var groupedByMonth: [String: [Photo]] = [:]
    @Published var monthStartIndex: [String: Int] = [:]

    // MARK: - Filtering
    func applyFilter() {
        switch segmentSelection {
        case 0:
            filteredPhotos = allPhotos.filter { photo in
                guard let date = photo.creationDate else { return false }
                return Calendar.current.isDate(date, equalTo: Date().addingTimeInterval(30*24*60*60), toGranularity: .month)
            }
        case 1:
            filteredPhotos = allPhotos.filter { photo in
                guard let date = photo.creationDate else { return false }
                return Calendar.current.isDate(date, equalTo: Date().addingTimeInterval(-30*24*60*60), toGranularity: .month)
            }
        default:
            filteredPhotos = allPhotos
        }
        updateGrouping()
    }

    private func updateGrouping() {
        // 月ごとにグループ化
        groupedByMonth = Dictionary(grouping: filteredPhotos) { photo in
            let date = photo.creationDate ?? Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM"
            return formatter.string(from: date)
        }

        // 月ごとの先頭写真インデックス
        var dict: [String: Int] = [:]
        let sortedMonths = groupedByMonth.keys.sorted(by: >)
        for month in sortedMonths {
            if let firstPhoto = groupedByMonth[month]?.first,
               let index = filteredPhotos.firstIndex(of: firstPhoto) {
                dict[month] = index
            }
        }
        monthStartIndex = dict
    }

    // セグメント切り替え時
    func selectSegment(_ index: Int) {
        segmentSelection = index
        applyFilter()
    }

    // ドラッグによるスクロール位置計算
    func scrollIndex(fromDrag value: CGFloat, totalHeight: CGFloat) -> Int {
        let y = min(max(value, 0), totalHeight)
        let ratio = y / totalHeight
        return Int(ratio * CGFloat(max(filteredPhotos.count-1, 0)))
    }
}*/


// MARK: - FRCラッパークラス
class FolderController: NSObject, ObservableObject, NSFetchedResultsControllerDelegate {
    @Published var folders: [Folder] = []
    
    private let context: NSManagedObjectContext
    private let frc: NSFetchedResultsController<Folder>
    
    init(context: NSManagedObjectContext) {
        self.context = context
        
        let fetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        fetchRequest.fetchBatchSize = 20
        
        frc = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        super.init()
        frc.delegate = self
        
        do {
            try frc.performFetch()
            folders = frc.fetchedObjects ?? []
        } catch {
            print("Folder fetch error: \(error)")
        }
    }
    
    // MARK: - Folder CRUD
    
    func fetchFolders() {
        do {
            folders = try context.fetch(Folder.fetchRequest())
                .sorted { ($0.name ?? "") < ($1.name ?? "") }
        } catch {
            print("Folder fetch error: \(error)")
        }
    }
    
    func createFolder(name: String, photos: [Photo] = []) {
        let newFolder = Folder(context: context)
        newFolder.name = name
        newFolder.addToPhotos(NSSet(array: photos))
        
        do {
            try context.save()
            fetchFolders()
        } catch {
            print("Folder save error: \(error)")
        }
    }
    
    func deleteFolder(at index: Int) {
        let folder = folders[index]
        context.delete(folder)
        
        do {
            try context.save()
            fetchFolders()
        } catch {
            print("Folder delete error: \(error)")
        }
    }
    
    func addPhotos(_ photos: [Photo], to folderIndex: Int) {
        guard folders.indices.contains(folderIndex) else { return }
        let folder = folders[folderIndex]
        folder.addToPhotos(NSSet(array: photos))
        
        do {
            try context.save()
            fetchFolders()
        } catch {
            print("Add photos to folder error: \(error)")
        }
    }
    
    func removePhotos(_ photos: [Photo], from folderIndex: Int) {
        guard folders.indices.contains(folderIndex) else { return }
        let folder = folders[folderIndex]
        folder.removeFromPhotos(NSSet(array: photos))
        
        do {
            try context.save()
            fetchFolders()
        } catch {
            print("Remove photos from folder error: \(error)")
        }
    }
    
    // NSFetchedResultsControllerDelegate
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        guard let updatedFolders = controller.fetchedObjects as? [Folder] else { return }
        DispatchQueue.main.async {
            self.folders = updatedFolders
        }
    }
}

// MARK: - FRCラッパークラス
class PhotoController: NSObject, ObservableObject, NSFetchedResultsControllerDelegate {
    @Published var photos: [Photo] = []
    
    private let context: NSManagedObjectContext
    private let frc: NSFetchedResultsController<Photo>
    
    init(context: NSManagedObjectContext) {
        self.context = context
        
        let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Photo.creationDate, ascending: true)]
        fetchRequest.fetchBatchSize = 20
        
        frc = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        super.init()
        frc.delegate = self
        
        do {
            try frc.performFetch()
            photos = frc.fetchedObjects ?? []
        } catch {
            print("Fetch error: \(error)")
        }
    }
    
    // MARK: - Photo CRUD
    
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
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        guard let updatedPhotos = controller.fetchedObjects as? [Photo] else { return }
        DispatchQueue.main.async {
            self.photos = updatedPhotos
        }
    }
    
    func deletePhoto(at index: Int) {
        let photo = photos[index]
        context.delete(photo)
        do {
            try context.save()
        } catch {
            print(error)
        }
    }
    
    func addPhoto(_ image: UIImage, creationDate: Date = Date()) {
        let newPhoto = Photo(context: context)
        newPhoto.id = UUID()
        newPhoto.creationDate = creationDate
        newPhoto.imageData = image.jpegData(compressionQuality: 0.8)
        
        do {
            try context.save()
        } catch {
            print(error)
        }
    }
    
    func saveImageToCameraRoll(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            })
        }
    }
}
