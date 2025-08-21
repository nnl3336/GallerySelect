//
//  MyViewControllerRepresentable.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/21.
//

import SwiftUI

class MyViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    var collectionView: UICollectionView!
    var photos: [Photo] = []
    
    var selectedPhotos = Set<Int>()
    // ← ここに書く
    var selectedPhotosBinding: Binding<Set<Int>>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 2
        layout.minimumLineSpacing = 2

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .white
        collectionView.dataSource = self
        collectionView.delegate = self

        // カスタムセルを登録
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: PhotoCell.reuseIdentifier)

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    func photoCellDidSave(_ cell: PhotoCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else { return }
        let photo = photos[indexPath.item]
        if let data = photo.imageData, let uiImage = UIImage(data: data) {
            UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
        }
    }

    func photoCellDidDelete(_ cell: PhotoCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else { return }
        photos.remove(at: indexPath.item)
        collectionView.deleteItems(at: [indexPath])
    }


    // MARK: - DataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PhotoCell.reuseIdentifier, for: indexPath) as? PhotoCell else {
            return UICollectionViewCell()
        }

        let photo = photos[indexPath.item]
        cell.configure(with: photo, selected: selectedPhotos.contains(indexPath.item))
        cell.delegate = self  // ← 成功した場合に設定
        return cell
    }
    

    // MARK: - DelegateFlowLayout
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.bounds.width - 4) / 3  // 3列、隙間2px
        return CGSize(width: width, height: width)
    }
}

//

extension MyViewController: PhotoCellDelegate {
    func photoCellDidToggleSelection(_ cell: PhotoCell) {
           guard let indexPath = collectionView.indexPath(for: cell) else { return }
           if selectedPhotos.contains(indexPath.item) {
               selectedPhotos.remove(indexPath.item)
           } else {
               selectedPhotos.insert(indexPath.item)
           }

           // SwiftUI に反映
           selectedPhotosBinding?.wrappedValue = selectedPhotos

           if let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell {
               cell.configure(with: photos[indexPath.item], selected: selectedPhotos.contains(indexPath.item))
           }
       }

}

// MARK: - UICollectionViewDelegate
extension MyViewController {

    // MARK: - タップ
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if !selectedPhotos.isEmpty {
            // すでに選択中のセルなら解除、そうでなければ追加
            if selectedPhotos.contains(indexPath.item) {
                selectedPhotos.remove(indexPath.item)
            } else {
                selectedPhotos.insert(indexPath.item)
            }

            // 選択状態の更新
            if let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell {
                cell.configure(with: photos[indexPath.item], selected: selectedPhotos.contains(indexPath.item))
            }

        } else {
            // 単体タップ時のフルスクリーン表示など
            let selectedIndex = indexPath.item
            let photo = photos[selectedIndex]

            // ここでフルスクリーン表示用の処理を呼ぶ
            showPhotoFullScreen(at: selectedIndex)
        }
    }

    func showPhotoFullScreen(at index: Int) {
        // 例: PhotoSliderView を表示するなど
        print("Full screen photo at index \(index)")
    }
}

//

// SwiftUI 用のラッパー
struct MyViewControllerRepresentable: UIViewControllerRepresentable {
    var photos: [Photo]
    @Binding var selectedPhotos: Set<Int>   // ← SwiftUI 側から渡す

    func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

    func makeUIViewController(context: Context) -> MyViewController {
        let vc = MyViewController()
        vc.photos = photos
        vc.selectedPhotos = selectedPhotos   // ← UIViewController に渡す

        return vc
    }

    func updateUIViewController(_ uiViewController: MyViewController, context: Context) {
        uiViewController.photos = photos
        uiViewController.collectionView.reloadData()
    }
    
    class Coordinator: NSObject, PhotoCellDelegate {
        var parent: MyViewControllerRepresentable
        init(_ parent: MyViewControllerRepresentable) {
            self.parent = parent
        }

        func photoCellDidToggleSelection(_ cell: PhotoCell) {
            guard let vc = cell.superview?.next as? MyViewController,
                  let indexPath = vc.collectionView.indexPath(for: cell) else { return }

            if vc.selectedPhotos.contains(indexPath.item) {
                vc.selectedPhotos.remove(indexPath.item)
            } else {
                vc.selectedPhotos.insert(indexPath.item)
            }

            // SwiftUI 側に反映
            parent.selectedPhotos = vc.selectedPhotos

            // UICollectionView 更新
            vc.collectionView.reloadItems(at: [indexPath])
        }

        func photoCellDidSave(_ cell: PhotoCell) {
            guard let vc = cell.superview?.next as? MyViewController else { return }
            vc.photoCellDidSave(cell)
        }

        func photoCellDidDelete(_ cell: PhotoCell) {
            guard let vc = cell.superview?.next as? MyViewController else { return }
            vc.photoCellDidDelete(cell)
        }
    }
}

//
