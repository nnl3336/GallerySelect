//
//  PhotoGridViewController.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/24.
//

import SwiftUI
import UIKit
import Photos

// MARK: - PhotoGridViewController
class PhotoGridViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    var photos: [Photo] = [] // Core Data などから取得
    var collectionView: UICollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Layout
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        let itemWidth = (view.frame.width - 30) / 3
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
        cell.configure(with: photo, selected: false)
        
        cell.actionHandler = { [weak self] (action: PhotoCellAction) in
            guard let self = self else { return }
            switch action {
            case .save:
                if let image = cell.imageView.image {
                    self.saveImageToCameraRoll(image)
                }
            case .delete:
                self.deletePhoto(photo)
            case .toggleSelection:
                cell.isSelectedPhoto.toggle()
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
        if let index = photos.firstIndex(where: { $0 == photo }) {
            photos.remove(at: index)
            collectionView.deleteItems(at: [IndexPath(item: index, section: 0)])
        }
    }
}

struct PhotoGridView: UIViewControllerRepresentable {
    @Binding var photos: [Photo] // SwiftUI 側のデータバインディング

    func makeUIViewController(context: Context) -> PhotoGridViewController {
        let vc = PhotoGridViewController()
        vc.photos = photos
        return vc
    }

    func updateUIViewController(_ uiViewController: PhotoGridViewController, context: Context) {
        uiViewController.photos = photos
        uiViewController.collectionView.reloadData()
    }
}
