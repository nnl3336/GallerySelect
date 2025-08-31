//
//  ContentView.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/15.
//

import SwiftUI
import PhotosUI
import CoreData
import Combine

// MARK: - SwiftUI ContentView
struct ContentView: View {

    var body: some View {
        CollectionViewWrapper()
        .edgesIgnoringSafeArea(.all)
    }
}



// MARK: - FRCラッパークラス
/*class PhotoController: NSObject, ObservableObject, NSFetchedResultsControllerDelegate {
    @Published var photos: [Photo] = []
    
    private let context: NSManagedObjectContext
    private let frc: NSFetchedResultsController<Photo>
    
    init(context: NSManagedObjectContext) {
        self.context = context
        
        let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Photo.creationDate, ascending: true)]
        fetchRequest.fetchBatchSize = 20   // ← ここ
        
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
}*/



import UIKit
import SwiftUI
import PhotosUI
import CoreData
import Combine

import UIKit
import PhotosUI
import CoreData

import UIKit
import PhotosUI
import CoreData

class PhotoGalleryViewController: UIViewController,
                                  UICollectionViewDataSource,
                                  UICollectionViewDelegate,
                                  NSFetchedResultsControllerDelegate,
                                  UICollectionViewDataSourcePrefetching, // Prefetch対応
                                  PHPickerViewControllerDelegate {
 
    var context: NSManagedObjectContext!
    var collectionView: UICollectionView!
    var fetchedResultsController: NSFetchedResultsController<Photo>!
    
    // サムネイルキャッシュ
    var thumbnailCache: [NSManagedObjectID: UIImage] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        context = PersistenceController.shared.container.viewContext
        setupNavigationBar()
        setupCollectionView()
        setupFetchedResultsController()
        try? fetchedResultsController.performFetch()
    }

    // MARK: - Navigation Bar
    func setupNavigationBar() {
        title = "Photos"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add,
                                                            target: self,
                                                            action: #selector(addPhotoTapped))
    }

    @objc func addPhotoTapped() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0 // 複数選択可
        config.filter = .images

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    // MARK: - PHPicker Delegate
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        for result in results {
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] reading, error in
                guard let self = self else { return }
                if let image = reading as? UIImage {
                    DispatchQueue.main.async {
                        let newPhoto = Photo(context: self.context)
                        newPhoto.id = UUID()
                        newPhoto.creationDate = Date()
                        // サムネイルと元画像は圧縮して保存
                        newPhoto.imageData = image.jpegData(compressionQuality: 0.5)
                        do {
                            try self.context.save()
                        } catch {
                            print("CoreData save error: \(error)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - CollectionView
    func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        let spacing: CGFloat = 5
        let itemsPerRow: CGFloat = 3
        let width = (view.frame.width - (itemsPerRow + 1) * spacing) / itemsPerRow
        layout.itemSize = CGSize(width: width, height: width)
        layout.minimumLineSpacing = spacing
        layout.minimumInteritemSpacing = spacing

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemBackground
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.prefetchDataSource = self as any UICollectionViewDataSourcePrefetching // Swift 5.7+対応

        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: "PhotoCell")
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    func setupFetchedResultsController() {
        let request: NSFetchRequest<Photo> = Photo.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        fetchedResultsController.delegate = self
    }

    // MARK: - CollectionView DataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fetchedResultsController.fetchedObjects?.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCell
        let photo = fetchedResultsController.object(at: indexPath)

        if let cached = thumbnailCache[photo.objectID] {
            cell.imageView.image = cached
        } else if let data = photo.imageData, let image = UIImage(data: data) {
            // サムネイル作成
            let thumb = image.resize(to: CGSize(width: 200, height: 200))
            thumbnailCache[photo.objectID] = thumb
            cell.imageView.image = thumb
        } else {
            cell.imageView.image = nil
        }

        return cell
    }

    // MARK: - Prefetching
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            let photo = fetchedResultsController.object(at: indexPath)
            if thumbnailCache[photo.objectID] == nil,
               let data = photo.imageData,
               let image = UIImage(data: data) {
                thumbnailCache[photo.objectID] = image.resize(to: CGSize(width: 200, height: 200))
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        // 必要ならキャッシュを解放する処理
    }

    // MARK: - FRC Delegate
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>,
                    didChange anObject: Any,
                    at indexPath: IndexPath?,
                    for type: NSFetchedResultsChangeType,
                    newIndexPath: IndexPath?) {

        switch type {
        case .insert:
            if let newIndexPath = newIndexPath {
                collectionView.insertItems(at: [newIndexPath])
            }
        case .delete:
            if let indexPath = indexPath {
                collectionView.deleteItems(at: [indexPath])
            }
        case .update:
            if let indexPath = indexPath {
                collectionView.reloadItems(at: [indexPath])
            }
        case .move:
            if let indexPath = indexPath, let newIndexPath = newIndexPath {
                collectionView.moveItem(at: indexPath, to: newIndexPath)
            }
        @unknown default:
            break
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // 個別更新で十分なのでreloadDataは不要
    }
}

// MARK: - UIImage Resize Helper
extension UIImage {
    func resize(to targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}



//

class PhotoCell: UICollectionViewCell {
    let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        imageView.frame = contentView.bounds
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
    }

    required init?(coder: NSCoder) { fatalError() }
}

//

struct CollectionViewWrapper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UINavigationController {
        let photoVC = PhotoGalleryViewController()
        let nav = UINavigationController(rootViewController: photoVC)
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) { }
}
