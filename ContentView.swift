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

enum Section {
    case main
}

class PhotoGalleryViewController: UIViewController, UICollectionViewDelegate, PHPickerViewControllerDelegate {

    var context: NSManagedObjectContext!
    var collectionView: UICollectionView!
    
    // DiffableDataSource
    var dataSource: UICollectionViewDiffableDataSource<Section, NSManagedObjectID>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        context = PersistenceController.shared.container.viewContext
        setupNavigationBar()
        setupCollectionView()
        setupDataSource()
        loadPhotos()
    }
    
    @objc func addPhotoTapped() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    // MARK: - Navigation Bar
    func setupNavigationBar() {
        title = "Photos"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add,
                                                            target: self,
                                                            action: #selector(addPhotoTapped))
    }

    func setupCollectionView() {
        // CompositionalLayout を使用
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: "PhotoCell")
        view.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    func createLayout() -> UICollectionViewLayout {
        // CompositionalLayout のサンプル
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.3),
                                              heightDimension: .fractionalWidth(0.3))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .fractionalWidth(0.3))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        return UICollectionViewCompositionalLayout(section: section)
    }

    func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, NSManagedObjectID>(collectionView: collectionView) {
            (collectionView, indexPath, objectID) -> UICollectionViewCell? in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCell
            if let photo = try? self.context.existingObject(with: objectID) as? Photo,
               let data = photo.imageData {
                cell.imageView.image = UIImage(data: data)
            }
            return cell
        }
    }
    
    func loadPhotos() {
        let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let photos = try? context.fetch(fetchRequest)
        
        var snapshot = NSDiffableDataSourceSnapshot<Section, NSManagedObjectID>()
        snapshot.appendSections([.main])
        snapshot.appendItems(photos?.map { $0.objectID } ?? [])
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    // PHPicker で追加後
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let result = results.first else { return }
        
        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] reading, error in
            guard let self = self, let image = reading as? UIImage else { return }
            DispatchQueue.main.async {
                let newPhoto = Photo(context: self.context)
                newPhoto.id = UUID()
                newPhoto.creationDate = Date()
                newPhoto.imageData = image.jpegData(compressionQuality: 0.8)
                try? self.context.save()
                
                // snapshot に追加
                var snapshot = self.dataSource.snapshot()
                snapshot.appendItems([newPhoto.objectID], toSection: .main)
                self.dataSource.apply(snapshot, animatingDifferences: true)
            }
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
