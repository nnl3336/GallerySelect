//
//  ContentView.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/15.
//

import SwiftUI
import PhotosUI
import CoreData

import SwiftUI
import PhotosUI
import CoreData

import SwiftUI
import Photos

// MARK: - SwiftUI ContentView
struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @ObservedObject var photoController: PhotoController
    @ObservedObject var folderController: FolderController
    @State private var currentScreen: AppScreen = .photos

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch currentScreen {
                case .photos:
                    MainView(
                        photoController: photoController,
                        folderController: folderController
                    )
                case .albums:
                    FolderListView(
                        photoController: photoController,
                        folderController: folderController
                    )
                }
            }
            .transition(.opacity)
        }
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


extension ContentView {
    
    func deletePhoto(at index: Int) {
        let photo = photoController.photos[index]  // ← controller.photos に変更
        viewContext.delete(photo)
        
        do {
            try viewContext.save()
        } catch {
            print("削除エラー: \(error)")
        }
    }
    
    func saveImageToCameraRoll(_ image: UIImage, creationDate: Date? = nil) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else {
                print("権限なし")
                return
            }

            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
                if let date = creationDate {
                    request.creationDate = date
                }
            }) { success, error in
                DispatchQueue.main.async { // UI 更新は main thread
                    if success {
                        print("保存成功")
                    } else {
                        print("保存失敗: \(error?.localizedDescription ?? "")")
                    }
                }
            }
        }
    }
}

// MARK: - SwiftUI MainView
struct MainView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var photoController: PhotoController
    @ObservedObject var folderController: FolderController
    @State private var selectedIndex: Int? = nil
<<<<<<< HEAD
    /*@State private var selectedPhotos = Set<Int>()*/ @State private var selectedPhotos = Set<Int>()
=======
    //@State private var selectedPhotos = Set<Int>()
>>>>>>> f/14
    @State private var showPicker = false
    @State private var showSearch = false
    @State private var showFolderSheet = false
    @State private var showAlbum = false
    @State private var segmentSelection = 2

    let segments = ["後ろの月", "前の月", "すべての写真"]
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    
    // Core Data から直接フェッチ
    /*@FetchRequest(
        entity: Photo.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Photo.creationDate, ascending: false)]
    ) private var photos: FetchedResults<Photo>*/

    var filteredPhotos: [Photo] {
        switch segmentSelection {
        case 0:
            return photoController.photos.filter { photo in
                guard let date = photo.creationDate else { return false }
                return Calendar.current.isDate(date, equalTo: Date().addingTimeInterval(30*24*60*60), toGranularity: .month)
            }
        case 1:
            return photoController.photos.filter { photo in
                guard let date = photo.creationDate else { return false }
                return Calendar.current.isDate(date, equalTo: Date().addingTimeInterval(-30*24*60*60), toGranularity: .month)
            }
        default:
            return photoController.photos
        }
    }
    @StateObject var viewModel = PhotoFRCController(context: PersistenceController.shared.container.viewContext)
    @State private var selectedPhoto: Photo?
    @State private var selectedPhotos: [Photo] = []
    @State private var isSelectionMode = false

    var body: some View {
        NavigationView {
            VStack {
                ScrollViewReader { proxy in
                }

                if selectedIndex == nil {
                    Picker("", selection: $segmentSelection) {
                        ForEach(0..<segments.count, id: \.self) { i in
                            Text(segments[i])
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                }
            }
            .navigationTitle("写真")
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    if isSelectionMode {
                        Button("Cancel") {
                            selectedPhotos.removeAll()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            PhotoPicker { images, assets in
                for (i, image) in images.enumerated() {
                    let creationDate = (i < assets.count) ? assets[i].creationDate ?? Date() : Date()
                    photoController.addPhoto(image, creationDate: creationDate)
                }
            }
        }
        .sheet(isPresented: $showFolderSheet) {
            FloatingButtonPanel(
                photoController: photoController,
                folderController: folderController,
                selectedPhotos: $selectedPhotos,
                showPicker: $showPicker,
                showSearch: $showSearch,
                showFolderSheet: $showFolderSheet
            )
        }
        .fullScreenCover(isPresented: $showSearch) {
            SearchView(
                photoController: photoController,
                folderController: folderController,
                isPresented: $showSearch)
        }
        .fullScreenCover(isPresented: $showAlbum) {
            FolderListView(
                photoController: photoController,
                folderController: folderController)
        }
    }
}





struct FloatingButtonPanel: View {
    @ObservedObject var photoController: PhotoController
    @ObservedObject var folderController: FolderController
    @Binding var selectedPhotos: [Photo]
    @Binding var showPicker: Bool
    @Binding var showSearch: Bool
    @Binding var showFolderSheet: Bool

    var body: some View {
        VStack { Spacer()
            HStack {
                NavigationLink(destination: FolderListView(
                    photoController: photoController,
                    folderController: folderController
                )) {
                    Image(systemName: "photo.on.rectangle")
                        .floatingStyle(color: .blue)
                }
                Button { if !selectedPhotos.isEmpty { showFolderSheet = true } } label: {
                    Image(systemName: "folder.badge.plus")
                        .floatingStyle(color: .purple)
                }
                Spacer()
                Button { showSearch = true } label: {
                    Image(systemName: "magnifyingglass")
                        .floatingStyle(color: .green)
                }
                Button { showPicker = true } label: {
                    Image(systemName: "plus")
                        .floatingStyle(color: .orange)
                }
            }
            .padding(.bottom, 30)
        }
    }
}

//


struct PhotoContextMenu: View {
    var photo: Photo
    var isSelected: Bool
    var toggleSelection: (Bool) -> Void
    var deleteAction: () -> Void

    var body: some View {
        VStack {
            Button(action: { toggleSelection(!isSelected) }) {
                Label(isSelected ? "選択解除" : "選択", systemImage: isSelected ? "circle" : "checkmark.circle")
            }
            Button { UIImageWriteToSavedPhotosAlbum(UIImage(data: photo.imageData ?? Data())!, nil, nil, nil) } label: {
                Label("保存", systemImage: "square.and.arrow.down")
            }
            Button(action: deleteAction) {
                Label("削除", systemImage: "trash")
            }
        }
    }
}

//

extension UIImage {
    /// 長辺を targetLength に合わせて縮小
    func resizedMaintainingAspect(to targetLength: CGFloat) -> UIImage? {
        let maxSide = max(size.width, size.height)
        let scale = targetLength / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// サムネイル用JPEGデータ
    func jpegThumbnailData(maxLength: CGFloat = 200, compression: CGFloat = 0.7) -> Data? {
        return self.resizedMaintainingAspect(to: maxLength)?
            .jpegData(compressionQuality: compression)
    }
}


extension UIImage {
    func resized(to targetSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    func jpegData(resizedTo targetSize: CGSize, compression: CGFloat = 0.7) -> Data? {
        return self.resized(to: targetSize)?.jpegData(compressionQuality: compression)
    }
}

extension Photo {
    var thumbnail: UIImage? {
        guard let data = imageData else { return nil }
        return UIImage(data: data)?.resize(to: CGSize(width: 150, height: 150))
    }
}

extension UIImage {
    func resize(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}


struct FloatingButtonPanel: View {
    @Binding var selectedPhotos: Set<Int>
    @Binding var showPicker: Bool
    @Binding var showSearch: Bool
    @Binding var showFolderSheet: Bool
    var controller: PhotoController

    var body: some View {
        VStack { Spacer()
            HStack {
                NavigationLink(destination: FolderListView(controller: controller)) {
                    Image(systemName: "photo.on.rectangle")
                        .floatingStyle(color: .blue)
                }
                Button {
                    showFolderSheet = true   // 選択が空でもシート表示
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .floatingStyle(color: .purple)
                }

                Spacer()
                Button { showSearch = true } label: {
                    Image(systemName: "magnifyingglass")
                        .floatingStyle(color: .green)
                }
                Button { showPicker = true } label: {
                    Image(systemName: "plus")
                        .floatingStyle(color: .orange)
                }
            }
            .padding(.bottom, 30)
        }
    }
}

extension View {
    func floatingStyle(color: Color) -> some View {
        self.font(.title)
            .padding()
            .background(color.opacity(0.8))
            .foregroundColor(.white)
            .clipShape(Circle())
            .shadow(radius: 4)
            .padding(.horizontal, 20)
    }
}


//


// MARK: - PhotoPicker

struct PhotoPicker: UIViewControllerRepresentable {
    @Environment(\.managedObjectContext) private var viewContext   // ← ここで参照

    // completion に UIImage と PHAsset を渡す
    var completion: (_ images: [UIImage], _ assets: [PHAsset]) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0 // 複数選択
        
        // 画像と動画の両方を選択可能
        config.filter = PHPickerFilter.any(of: [.images, .videos])
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
            Coordinator(self, viewContext: viewContext)   // ← 渡す
        }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
            var parent: PhotoPicker
            var viewContext: NSManagedObjectContext   // ← ここで保持
            
            init(_ parent: PhotoPicker, viewContext: NSManagedObjectContext) {
                self.parent = parent
                self.viewContext = viewContext
            }
        
        //***

        func saveToCameraRoll(imageData: Data, creationDate: Date?) {
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                request.addResource(with: .photo, data: imageData, options: options)
                if let creationDate {
                    request.creationDate = creationDate   // ← ここでAppleの撮影日をセット
                }
            } completionHandler: { success, error in
                if success {
                    print("保存できました！")
                } else {
                    print("エラー: \(error?.localizedDescription ?? "不明")")
                }
            }
        }

        
        func didPickPhotos(images: [UIImage], assets: [PHAsset]) {
            for (index, image) in images.enumerated() {
                let asset = assets.indices.contains(index) ? assets[index] : nil
                let captureDate = asset?.creationDate ?? Date()

                let newPhoto = Photo(context: viewContext)
                
                // フル解像度
                newPhoto.imageData = image.jpegData(compressionQuality: 0.9)
                
                // サムネイル（縦横比維持・長辺200）
                newPhoto.thumbnailData = image.jpegThumbnailData(maxLength: 200)

                newPhoto.currentDate = captureDate
            }

            try? viewContext.save()
        }

        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            var images: [UIImage] = []
            var assets: [PHAsset] = []
            
            let group = DispatchGroup()
            
            for (index, result) in results.enumerated() {   // ← enumerated() で index 取得
                // PHAsset を取得
                if let assetId = result.assetIdentifier,
                   let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil).firstObject {
                    assets.append(asset)
                    print("📸 index \(index): captureDate = \(String(describing: asset.creationDate))")  // ← ここでデバッグ
                }
                
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    group.enter()
                    result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                        if let image = object as? UIImage { images.append(image) }
                        group.leave()
                    }
                }
            }
            
            group.notify(queue: .main) {
                self.parent.completion(images, assets)
            }
        }

    }
}
