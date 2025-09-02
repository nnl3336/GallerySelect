//
//  PhotoCollectionViewController.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/24.
//
import UIKit
import SwiftUI
import PhotosUI
import CoreData
import Combine

import UIKit
import CoreData
import PhotosUI

class PhotoGalleryViewController: UIViewController,
                                  UICollectionViewDelegate,
                                  NSFetchedResultsControllerDelegate,
                                  UICollectionViewDataSourcePrefetching,
                                  PHPickerViewControllerDelegate {

    // MARK: - Properties
    var context: NSManagedObjectContext!
    var collectionView: UICollectionView!
    var fetchedResultsController: NSFetchedResultsController<Photo>!

    enum Section { case main }
    var dataSource: UICollectionViewDiffableDataSource<Section, NSManagedObjectID>!

    let cacheWindow = 100
    var thumbnailCache = NSCache<NSManagedObjectID, UIImage>()
    var cachedKeys = Set<NSManagedObjectID>()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        context = PersistenceController.shared.container.viewContext

        setupNavigationBar()
        setupCollectionView()
        setupDataSource()
        setupFetchedResultsController()

        do {
            try fetchedResultsController.performFetch()
            applySnapshot(animated: false)
        } catch {
            print("Fetch error: \(error)")
        }
    }

    // MARK: - Setup
    func setupNavigationBar() {
        title = "Photos"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add,
                                                            target: self,
                                                            action: #selector(addPhotoTapped))
    }

    func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 120, height: 120)
        layout.minimumLineSpacing = 4
        layout.minimumInteritemSpacing = 4

        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.prefetchDataSource = self
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: "PhotoCell")
        view.addSubview(collectionView)
    }

    func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, NSManagedObjectID>(collectionView: collectionView) { [weak self] collectionView, indexPath, objectID in
            guard let self = self else { return UICollectionViewCell() }
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCell

            // キャッシュから取得、なければ読み込む
            if let image = self.thumbnailCache.object(forKey: objectID) {
                cell.imageView.image = image
            } else if let photo = try? self.context.existingObject(with: objectID) as? Photo,
                      let data = photo.thumbnailData,
                      let image = UIImage(data: data) {
                cell.imageView.image = image
                self.thumbnailCache.setObject(image, forKey: objectID)
                self.cachedKeys.insert(objectID)
            } else {
                cell.imageView.image = nil
            }

            self.updateCacheAround(index: indexPath.item)
            return cell
        }
    }

    func setupFetchedResultsController() {
        let request: NSFetchRequest<Photo> = Photo.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        fetchedResultsController = NSFetchedResultsController(fetchRequest: request,
                                                              managedObjectContext: context,
                                                              sectionNameKeyPath: nil,
                                                              cacheName: nil)
        fetchedResultsController.delegate = self
    }

    // MARK: - Snapshot
    func applySnapshot(animated: Bool = true) {
        guard let objects = fetchedResultsController.fetchedObjects else { return }
        var snapshot = NSDiffableDataSourceSnapshot<Section, NSManagedObjectID>()
        snapshot.appendSections([.main])
        snapshot.appendItems(fetchedResultsController.fetchedObjects!.map { $0.objectID })
        print(snapshot.numberOfItems) // <- ここで0なら何も表示されない
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    // MARK: - PHPicker
    @objc func addPhotoTapped() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    //写真保存
    let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        let group = DispatchGroup()
        var imagesToAdd: [UIImage] = []

        for result in results {
            group.enter()
            result.itemProvider.loadObject(ofClass: UIImage.self) { reading, _ in
                defer { group.leave() }
                if let image = reading as? UIImage {
                    imagesToAdd.append(image)
                }
            }
        }

        group.notify(queue: .main) {
            for image in imagesToAdd {
                let uuid = UUID().uuidString
                if let fileWrapper = self.savePhotoToFile(photo: image, fileName: uuid) {
                    let url = self.documentsDirectory.appendingPathComponent(uuid) // ディレクトリ名
                    try? fileWrapper.write(to: url, options: .atomic, originalContentsURL: nil)
                    
                    // Core Data には URL を保存
                    let photo = Photo(context: self.context)
                    photo.id = UUID()
                    photo.creationDate = Date()
                    photo.imageURL = url.path
                }
            }
            try? self.context.save()
        }

    }
    
    func savePhotoToFile(photo: UIImage, fileName: String) -> FileWrapper? {
        let directoryWrapper = FileWrapper(directoryWithFileWrappers: [:])
        
        // Thumbnail
        if let thumbData = photo.resize(to: CGSize(width: 200, height: 200))
                                .jpegData(compressionQuality: 0.7) {
            let thumbWrapper = FileWrapper(regularFileWithContents: thumbData)
            thumbWrapper.preferredFilename = "thumb.jpg"
            directoryWrapper.addFileWrapper(thumbWrapper)
        }

        // Full image
        if let fullData = photo.jpegData(compressionQuality: 0.9) {
            let fullWrapper = FileWrapper(regularFileWithContents: fullData)
            fullWrapper.preferredFilename = "full.jpg"
            directoryWrapper.addFileWrapper(fullWrapper)
        }

        return directoryWrapper
    }


    // MARK: - NSFetchedResultsControllerDelegate
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        applySnapshot()
    }

    // MARK: - Prefetching
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        guard let fetchedObjects = fetchedResultsController.fetchedObjects else { return }
        let minIndex = max((indexPaths.map { $0.item }.min() ?? 0) - cacheWindow, 0)
        let maxIndex = min((indexPaths.map { $0.item }.max() ?? 0) + cacheWindow, fetchedObjects.count - 1)

        for i in minIndex...maxIndex {
            let photo = fetchedObjects[i]

            if thumbnailCache.object(forKey: photo.objectID) == nil {
                var dataToUse: Data?
                
                if let thumb = photo.thumbnailData {
                    dataToUse = thumb
                } else if let full = photo.fullImageData {
                    // 過去の写真には thumbnail がない → 作って保存
                    let image = UIImage(data: full)!
                    let thumb = image.resize(to: CGSize(width: 200, height: 200))
                    dataToUse = thumb.jpegData(compressionQuality: 0.7)
                    
                    photo.thumbnailData = dataToUse
                    try? context.save()
                }

                if let data = dataToUse, let image = UIImage(data: data) {
                    thumbnailCache.setObject(image, forKey: photo.objectID)
                    cachedKeys.insert(photo.objectID)
                }
            }
        }
    }


    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) { }

    // MARK: - Cache Helper
    private func updateCacheAround(index: Int) {
        guard let fetchedObjects = fetchedResultsController.fetchedObjects else { return }
        let start = max(index - cacheWindow, 0)
        let end = min(index + cacheWindow, fetchedObjects.count - 1)

        for i in start...end {
            let photo = fetchedObjects[i]
            if let data = photo.thumbnailData, thumbnailCache.object(forKey: photo.objectID) == nil,
               let image = UIImage(data: data) {
                thumbnailCache.setObject(image, forKey: photo.objectID)
                cachedKeys.insert(photo.objectID)
            }
        }

        for key in cachedKeys {
            if let idx = fetchedObjects.firstIndex(where: { $0.objectID == key }),
               idx < start || idx > end {
                thumbnailCache.removeObject(forKey: key)
                cachedKeys.remove(key)
            }
        }
    }

    // MARK: - Fullscreen Image VC
    class FullscreenImageViewController: UIViewController {
        private let imageView = UIImageView()
        private let image: UIImage

        init(image: UIImage) {
            self.image = image
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            imageView.contentMode = .scaleAspectFit
            imageView.image = image
            imageView.frame = view.bounds
            imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(imageView)
        }
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



//



//


class PhotoCollectionViewCell: UICollectionViewCell {
    
    let imageView = UIImageView()
    let overlayView = UIView()
    let checkmark = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // 画像
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        contentView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
        
        // 薄青オーバーレイ
        overlayView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.3)
        overlayView.isHidden = true
        overlayView.layer.cornerRadius = 8
        contentView.addSubview(overlayView)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: contentView.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            overlayView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
        
        // チェックマーク
        checkmark.tintColor = .white
        checkmark.isHidden = true
        contentView.addSubview(checkmark)
        checkmark.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            checkmark.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            checkmark.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -5),
            checkmark.widthAnchor.constraint(equalToConstant: 24),
            checkmark.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func setSelectedAppearance(_ selected: Bool) {
        overlayView.isHidden = !selected
        checkmark.isHidden = !selected
    }
}

// MARK: - SwiftUI Wrapper
