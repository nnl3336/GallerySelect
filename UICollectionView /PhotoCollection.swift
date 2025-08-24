//
//  PhotoCollectionViewController.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/24.
//

import SwiftUI
import UIKit

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
    
    private var photos: [Photo]         // 表示する画像の配列
        private var currentIndex: Int       // 現在表示中のインデックス
        let tappedIndex = 3                 // サンプルで固定してる開始インデックス

        var onClose: (() -> Void)?

        // MARK: - イニシャライザ
    init(photos: [Photo], startIndex: Int = 0) {
        self.photos = photos
        self.currentIndex = startIndex
        super.init(nibName: nil, bundle: nil)  // ← UIViewController用
        modalPresentationStyle = .overFullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    
    //***
    
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
            // 選択モード中 → 選択/解除
            if let idx = selectedPhotos.firstIndex(of: photo) {
                selectedPhotos.remove(at: idx)
                collectionView.deselectItem(at: indexPath, animated: true)
            } else {
                selectedPhotos.append(photo)
            }
            notifySelectionChanged()
        } else {
            // 拡大表示
            let detailVC = PhotoDetailViewController(photos: photos, startIndex: tappedIndex)
            detailVC.onClose = { print("閉じた") }
            present(detailVC, animated: true)
        }
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

    // MARK: - 選択通知
    private func notifySelectionChanged() {
        onSelectMultiple?(selectedPhotos)
        collectionView.reloadData()
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
struct PhotoCollectionViewRepresentable: UIViewControllerRepresentable {
    @ObservedObject var viewModel: PhotoFRCController
    var onSelectPhoto: ((Photo) -> Void)?
    var onSelectMultiple: (([Photo]) -> Void)?

    func makeUIViewController(context: Context) -> PhotoCollectionViewController {
        let allPhotos = viewModel.frc.fetchedObjects ?? [] // FRC から配列を取得
        let vc = PhotoCollectionViewController(photos: allPhotos)
        vc.viewModel = viewModel
        vc.onSelectPhoto = onSelectPhoto
        vc.onSelectMultiple = onSelectMultiple
        return vc
    }

    func updateUIViewController(_ uiViewController: PhotoCollectionViewController, context: Context) {}
}
