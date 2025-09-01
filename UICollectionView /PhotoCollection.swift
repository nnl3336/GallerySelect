//
//  PhotoCollectionViewController.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/24.
//

import SwiftUI
import UIKit

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
                                  UICollectionViewDataSourcePrefetching,
                                  PHPickerViewControllerDelegate {

    var context: NSManagedObjectContext!
    var collectionView: UICollectionView!
    var fetchedResultsController: NSFetchedResultsController<Photo>!

    // サムネイルキャッシュ（表示中 + 前後100枚）
    var thumbnailCache: [NSManagedObjectID: UIImage] = [:]
    let cacheWindow = 100

    override func viewDidLoad() {
        super.viewDidLoad()
        context = PersistenceController.shared.container.viewContext
        setupNavigationBar()
        setupCollectionView()
        setupFetchedResultsController()
        try? fetchedResultsController.performFetch()
    }

    // MARK: - Navigation
    func setupNavigationBar() {
        title = "Photos"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add,
                                                            target: self,
                                                            action: #selector(addPhotoTapped))
    }

    @objc func addPhotoTapped() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    // MARK: - PHPicker Delegate
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        for result in results {
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] reading, _ in
                guard let self = self, let image = reading as? UIImage else { return }
                DispatchQueue.main.async {
                    let newPhoto = Photo(context: self.context)
                    newPhoto.id = UUID()
                    newPhoto.creationDate = Date()
                    newPhoto.imageData = image.jpegData(compressionQuality: 0.5)
                    do {
                        try self.context.save()
                    } catch {
                        print("CoreData save error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // MARK: - CollectionView Setup
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
        collectionView.prefetchDataSource = self

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
        updateCacheAround(index: indexPath.item) // キャッシュ範囲更新
        let photo = fetchedResultsController.object(at: indexPath)
        cell.imageView.image = thumbnailCache[photo.objectID]
        return cell
    }

    // MARK: - Prefetching
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        guard let fetchedObjects = fetchedResultsController.fetchedObjects else { return }
        let minIndex = max((indexPaths.map { $0.item }.min() ?? 0) - cacheWindow, 0)
        let maxIndex = min((indexPaths.map { $0.item }.max() ?? 0) + cacheWindow, fetchedObjects.count - 1)
        for i in minIndex...maxIndex {
            let photo = fetchedObjects[i]
            if thumbnailCache[photo.objectID] == nil, let data = photo.imageData, let image = UIImage(data: data) {
                thumbnailCache[photo.objectID] = image.resize(to: CGSize(width: 200, height: 200))
            }
        }
        // 範囲外キャッシュ削除
        thumbnailCache.keys.forEach { key in
            if let idx = fetchedObjects.firstIndex(where: { $0.objectID == key }), idx < minIndex || idx > maxIndex {
                thumbnailCache.removeValue(forKey: key)
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        // ここでも必要ならキャッシュ破棄可能
    }

    // MARK: - Helper
    private func updateCacheAround(index: Int) {
        guard let fetchedObjects = fetchedResultsController.fetchedObjects else { return }
        let start = max(index - cacheWindow, 0)
        let end = min(index + cacheWindow, fetchedObjects.count - 1)
        for i in start...end {
            let photo = fetchedObjects[i]
            if thumbnailCache[photo.objectID] == nil, let data = photo.imageData, let image = UIImage(data: data) {
                thumbnailCache[photo.objectID] = image.resize(to: CGSize(width: 200, height: 200))
            }
        }
        // 範囲外キャッシュ削除
        thumbnailCache.keys.forEach { key in
            if let idx = fetchedObjects.firstIndex(where: { $0.objectID == key }), idx < start || idx > end {
                thumbnailCache.removeValue(forKey: key)
            }
        }
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
        @unknown default: break
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




// MARK: - UICollectionViewController
class PhotoCollectionViewController: UIViewController,
                                     UICollectionViewDataSource,
                                     UICollectionViewDelegateFlowLayout {

    private var collectionView: UICollectionView!
    var viewModel: PhotoFRCController!

    // 選択状態
    private var isSelectionMode = false {
        didSet {
            onSelectionModeChanged?(isSelectionMode)
        }
    }
    private var selectedPhotos: [Photo] = []

    // コールバック
    var onSelectPhoto: ((Photo) -> Void)?
    var onSelectMultiple: (([Photo]) -> Void)?
    
    var onSelectionModeChanged: ((Bool) -> Void)?
    

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        // UICollectionView のレイアウト
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.itemSize = CGSize(width: 100, height: 100)
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10

        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = .white
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(PhotoCollectionViewCell.self, forCellWithReuseIdentifier: "Cell")
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.allowsMultipleSelection = true
        view.addSubview(collectionView)

        viewModel.attach(collectionView: collectionView)
    }
    
    private func notifySelectionChanged() {
        onSelectMultiple?(selectedPhotos)
        onSelectionModeChanged?(isSelectionMode)
        collectionView.reloadData()
        
        // selectedPhotos が空なら選択モードを終了
        if selectedPhotos.isEmpty {
            isSelectionMode = false
        }
    }

    // MARK: - UICollectionViewDataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.numberOfItems
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! PhotoCollectionViewCell
        if let photo = viewModel.photo(at: indexPath.item),
           let data = photo.imageData,
           let uiImage = UIImage(data: data) {
            cell.imageView.image = uiImage
            // 選択モード中は青いオーバーレイ表示
            cell.overlayView.isHidden = !selectedPhotos.contains(photo)
        }
        return cell
    }

    // MARK: - UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let photo = viewModel.photo(at: indexPath.item) else { return }

        if isSelectionMode {
            if let idx = selectedPhotos.firstIndex(of: photo) {
                selectedPhotos.remove(at: idx)
                collectionView.deselectItem(at: indexPath, animated: true)
            } else {
                selectedPhotos.append(photo)
            }
            notifySelectionChanged()
        } else {
            // 拡大表示にまとめる
            showPhotoFullScreen(at: indexPath.item)
        }
    }

    func showPhotoFullScreen(at index: Int) {
        var currentIndex = index
        let hosting = UIHostingController(
            rootView: PhotoDetailPager(
                photos: viewModel.photos,
                selectedIndex: Binding(
                    get: { currentIndex },
                    set: { newValue in currentIndex = newValue }
                ),
                onClose: { [weak self] in
                    self?.dismiss(animated: true, completion: nil)
                }
                // photoFRCController: viewModel // ←不要なら削除
            )
        )
        hosting.modalPresentationStyle = .fullScreen
        present(hosting, animated: true, completion: nil)
    }




    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if isSelectionMode {
            notifySelectionChanged()
        }
    }

    // MARK: - Context Menu (長押し)
    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {

        guard let photo = viewModel.photo(at: indexPath.item) else { return nil }

        return UIContextMenuConfiguration(identifier: indexPath as NSIndexPath, previewProvider: nil) { _ in
            let select = UIAction(title: "選択モードに入る", image: UIImage(systemName: "checkmark.circle")) { _ in
                self.isSelectionMode = true
                self.selectedPhotos.append(photo)
                collectionView.selectItem(at: indexPath, animated: true, scrollPosition: [])
                self.notifySelectionChanged()
            }
            let delete = UIAction(title: "削除", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                self.viewModel.delete(photo)
            }
            return UIMenu(title: "", children: [select, delete])
        }
    }

    // MARK: - 選択モード終了
    func exitSelectionMode() {
        isSelectionMode = false
        selectedPhotos.removeAll()
        collectionView.indexPathsForSelectedItems?.forEach { collectionView.deselectItem(at: $0, animated: false) }
        notifySelectionChanged()
    }
}

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
