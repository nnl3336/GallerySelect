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

class PhotoGalleryViewController: UIViewController,
                                  UICollectionViewDataSource,
                                  UICollectionViewDelegate,
                                  NSFetchedResultsControllerDelegate,
                                  UICollectionViewDataSourcePrefetching,
                                  PHPickerViewControllerDelegate {

    // MARK: - Properties
    var context: NSManagedObjectContext!
    var collectionView: UICollectionView!
    var fetchedResultsController: NSFetchedResultsController<Photo>!

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
        setupFetchedResultsController()

        do {
            try fetchedResultsController.performFetch()
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
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.prefetchDataSource = self
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: "PhotoCell")
        view.addSubview(collectionView)
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

    // MARK: - PHPicker
    @objc func addPhotoTapped() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        for result in results {
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] reading, _ in
                guard let self = self, let image = reading as? UIImage else { return }
                DispatchQueue.main.async {
                    let newPhoto = Photo(context: self.context)
                    newPhoto.id = UUID()
                    newPhoto.creationDate = Date()
                    newPhoto.fullImageData = image.jpegData(compressionQuality: 0.9)
                    let thumb = image.resize(to: CGSize(width: 200, height: 200))
                    newPhoto.thumbnailData = thumb.jpegData(compressionQuality: 0.7)
                    do {
                        try self.context.save()
                    } catch {
                        print("CoreData save error: \(error)")
                    }
                }
            }
        }
    }

    // MARK: - UICollectionViewDataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fetchedResultsController.fetchedObjects?.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCell
        let photo = fetchedResultsController.object(at: indexPath)

        if let thumb = thumbnailCache.object(forKey: photo.objectID) {
            cell.imageView.image = thumb
        } else if let data = photo.thumbnailData, let image = UIImage(data: data) {
            cell.imageView.image = image
            thumbnailCache.setObject(image, forKey: photo.objectID)
        } else {
            cell.imageView.image = nil
        }

        // キャッシュ範囲更新
        updateCacheAround(index: indexPath.item)

        return cell
    }

    // MARK: - UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let photo = fetchedResultsController.object(at: indexPath)
        if let data = photo.fullImageData, let fullImage = UIImage(data: data) {
            let vc = FullscreenImageViewController(image: fullImage)
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    // MARK: - Prefetching
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        guard let fetchedObjects = fetchedResultsController.fetchedObjects else { return }
        let minIndex = max((indexPaths.map { $0.item }.min() ?? 0) - cacheWindow, 0)
        let maxIndex = min((indexPaths.map { $0.item }.max() ?? 0) + cacheWindow, fetchedObjects.count - 1)

        for i in minIndex...maxIndex {
            let photo = fetchedObjects[i]
            if thumbnailCache.object(forKey: photo.objectID) == nil,
               let data = photo.thumbnailData,
               let image = UIImage(data: data) {
                thumbnailCache.setObject(image, forKey: photo.objectID)
                cachedKeys.insert(photo.objectID)
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        // 必要ならプリフェッチキャンセル処理
    }

    // MARK: - Cache Helper
    private func updateCacheAround(index: Int) {
        guard let fetchedObjects = fetchedResultsController.fetchedObjects else { return }
        let start = max(index - cacheWindow, 0)
        let end = min(index + cacheWindow, fetchedObjects.count - 1)

        for i in start...end {
            let photo = fetchedObjects[i]
            if thumbnailCache.object(forKey: photo.objectID) == nil,
               let data = photo.thumbnailData,
               let image = UIImage(data: data) {
                thumbnailCache.setObject(image, forKey: photo.objectID)
                cachedKeys.insert(photo.objectID)
            }
        }

        // 範囲外キャッシュ削除
        for key in cachedKeys {
            if let idx = fetchedObjects.firstIndex(where: { $0.objectID == key }),
               idx < start || idx > end {
                thumbnailCache.removeObject(forKey: key)
                cachedKeys.remove(key)
            }
        }
    }

    // MARK: - NSFetchedResultsControllerDelegate
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
