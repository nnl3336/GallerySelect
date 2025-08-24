//
//  PhotoCell.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/21.
//

import SwiftUI


// MARK: - PhotoCellAction
enum PhotoCellAction {
    case save
    case delete
    case toggleSelection
}

// MARK: - PhotoCellDelegate
protocol PhotoCellDelegate: AnyObject {
    func photoCellDidToggleSelection(_ cell: PhotoCell)
    func photoCellDidSave(_ cell: PhotoCell)
    func photoCellDidDelete(_ cell: PhotoCell)
}

// MARK: - PhotoCell
class PhotoCell: UICollectionViewCell {
    
    static let reuseIdentifier = "PhotoCell"
    let imageView = UIImageView()
    private let overlayView = UIView() // 選択時カバー
    weak var delegate: PhotoCellDelegate?
    
    var isSelectedPhoto: Bool = false {
        didSet {
            overlayView.isHidden = !isSelectedPhoto
            contentView.bringSubviewToFront(overlayView)
        }
    }
    
    // クロージャ方式でも対応可能
    var actionHandler: ((PhotoCellAction) -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // 画像表示
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
        
        // オーバーレイ
        overlayView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.3)
        overlayView.isHidden = true
        overlayView.layer.cornerRadius = 5
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(overlayView)
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: contentView.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            overlayView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
        
        // 長押しメニュー
        let interaction = UIContextMenuInteraction(delegate: self)
        self.addInteraction(interaction)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // 画像セット + 選択状態セット
    func configure(with photo: Photo, selected: Bool) {
        isSelectedPhoto = selected
        if let data = photo.imageData {
            DispatchQueue.global(qos: .userInitiated).async {
                let uiImage = UIImage(data: data)
                DispatchQueue.main.async {
                    self.imageView.image = uiImage
                }
            }
        } else {
            imageView.image = nil
        }
    }
}

// MARK: - UIContextMenuInteractionDelegate
@available(iOS 13.0, *)
extension PhotoCell: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let toggleSelection = UIAction(
                title: self.isSelectedPhoto ? "選択解除" : "選択",
                image: UIImage(systemName: "checkmark.circle")
            ) { [weak self] _ in
                self?.actionHandler?(.toggleSelection)
            }
            
            let save = UIAction(
                title: "保存",
                image: UIImage(systemName: "square.and.arrow.down")
            ) { [weak self] _ in
                self?.actionHandler?(.save)
            }
            
            let delete = UIAction(
                title: "削除",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.actionHandler?(.delete)
            }
            
            return UIMenu(title: "", children: [toggleSelection, save, delete])
        }
    }
}
