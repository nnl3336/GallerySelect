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
        PhotoCollectionViewRepresentable()
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



class PhotoGalleryViewController: UIViewController {

    var photoController: PhotoController
    var folderController: FolderController

    private var collectionView: UICollectionView!
    private var cancellables = Set<AnyCancellable>()

    private var selectedPhotos: [Photo] = []
    private var isSelectionMode: Bool { !selectedPhotos.isEmpty }
    
    private let context: NSManagedObjectContext

        // ここを追加
        var viewContext: NSManagedObjectContext { context }

    // MARK: - 初期化
        init(photoController: PhotoController, folderController: FolderController, context: NSManagedObjectContext) {
            self.photoController = photoController
            self.folderController = folderController
            self.context = context   // ← super.init の前に初期化
            super.init(nibName: nil, bundle: nil)
        }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupCollectionView()
        setupNavigationBar()
        observePhotos()
    }

    // MARK: - CollectionView
    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 2
        layout.minimumInteritemSpacing = 2
        layout.itemSize = CGSize(width: 100, height: 100)

        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: "PhotoCell")
        view.addSubview(collectionView)
    }

    // MARK: - NavigationBar / Toolbar
    private func setupNavigationBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add,
                                                            target: self,
                                                            action: #selector(addPhotos))
    }

    // MARK: - PhotoController Changes
    private func observePhotos() {
        photoController.$photos
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.collectionView.reloadData()
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions
    @objc private func addPhotos() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0
        config.filter = .images

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func deleteSelectedPhotos() {
        for photo in selectedPhotos {
            photoController.context.delete(photo)
        }
        try? photoController.context.save()
        selectedPhotos.removeAll()
        collectionView.reloadData()
    }
}

// MARK: - UICollectionView
extension PhotoGalleryViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        photoController.photos.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCell
        let photo = photoController.photos[indexPath.item]
        cell.configure(with: photo)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let photo = photoController.photos[indexPath.item]
        if selectedPhotos.contains(photo) {
            selectedPhotos.removeAll { $0 == photo }
        } else {
            selectedPhotos.append(photo)
        }
        collectionView.reloadItems(at: [indexPath])
    }
}

// MARK: - PHPicker
extension PhotoGalleryViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        for result in results {
            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                    guard let self = self, let image = object as? UIImage else { return }
                    DispatchQueue.main.async {
                        self.photoController.addPhoto(image)
                    }
                }
            }
        }
    }
}

//

struct PhotoCollectionViewRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> MyViewController {
        let vc = MyViewController()
        // 必要なら photos や delegate をセット
        return vc
    }

    func updateUIViewController(_ uiViewController: MyViewController, context: Context) {
        // データ更新時の処理
        uiViewController.collectionView.reloadData()
    }
}


// MARK: - PhotoCell
class PhotoCell: UICollectionViewCell {
    static let reuseIdentifier = "PhotoCell"  // ← ここを static に
    weak var delegate: PhotoCellDelegate?
    
    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        imageView.frame = contentView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with photo: Photo) {
        imageView.image = photo.thumbnailImage ?? UIImage(systemName: "photo")
    }
}

extension Photo {
    var thumbnailImage: UIImage? {
        guard let data = thumbnail else { return nil }
        return UIImage(data: data)
    }
}
