//
//  PhotoGridViewController.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/24.
//

import SwiftUI
import UIKit
import Photos

class PhotoGridViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    var photos: [Photo] = [] // Core Data などから取得
    
    private var collectionView: UICollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Layout
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        let itemWidth = (view.frame.width - 30) / 3 // 3列の場合
        layout.itemSize = CGSize(width: itemWidth, height: 100)
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: "PhotoCell")
        view.addSubview(collectionView)
    }
    
    // MARK: UICollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let photo = photos[indexPath.item]
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCell
        if let data = photo.imageData, let image = UIImage(data: data) {
            cell.imageView.image = image
        } else {
            cell.imageView.image = UIImage(systemName: "photo")
        }
        cell.configureContextMenu { [weak self] action in
            guard let self = self else { return }
            switch action {
            case .save:
                if let image = cell.imageView.image {
                    self.saveImageToCameraRoll(image)
                }
            case .delete:
                self.deletePhoto(photo)
            }
        }
        return cell
    }
    
    // MARK: 保存 / 削除
    
    func saveImageToCameraRoll(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
    
    func deletePhoto(_ photo: Photo) {
        // Core Data から削除処理
    }
}

// MARK: - PhotoCell

@available(iOS 13.0, *)
extension PhotoCell: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let save = UIAction(title: "保存", image: UIImage(systemName: "square.and.arrow.down")) { [weak self] _ in
                self?.actionHandler?(.save)
            }
            let delete = UIAction(title: "削除", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.actionHandler?(.delete)
            }
            return UIMenu(title: "", children: [save, delete])
        }
    }
}

//

struct PhotoGridView: UIViewControllerRepresentable {
    
    var photos: [Photo]
    var onSelectPhoto: ((Photo) -> Void)?
    var onDeletePhoto: ((Photo) -> Void)?
    
    func makeUIViewController(context: Context) -> PhotoGridViewController {
        let vc = PhotoGridViewController()
        vc.photos = photos
        vc.onSelectPhoto = onSelectPhoto
        vc.onDeletePhoto = onDeletePhoto
        return vc
    }
    
    func updateUIViewController(_ uiViewController: PhotoGridViewController, context: Context) {
        uiViewController.photos = photos
        uiViewController.collectionView.reloadData()
    }
}

