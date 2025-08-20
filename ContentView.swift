//
//  ContentView.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/15.
//

import SwiftUI
import PhotosUI
import CoreData
import Photos

// MARK: - SwiftUI ContentView
struct ContentView: View  {
    @Environment(\.managedObjectContext) private var viewContext
    
    @ObservedObject var photocontroller: PhotoController
    @ObservedObject var foldercontroller: FolderController
    @State private var currentScreen: AppScreen = .photos

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch currentScreen {
                case .photos:
                    MainView(photocontroller: photocontroller, foldercontroller: foldercontroller)
                case .albums:
                    FolderListView(photocontroller: photocontroller,
                                   foldercontroller: foldercontroller)
                }
            }
            .transition(.opacity)
        }
    }
    
    func deletePhoto(at index: Int) {
        let photo = photocontroller.photos[index]  // ← controller.photos に変更
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


// MARK: - SwiftUI MainView
struct MainView: View {
    @ObservedObject var photocontroller: PhotoController
    @ObservedObject var foldercontroller: FolderController

    @StateObject var selectionManager = PhotoSelectionManager()
    
    @State private var selectedIndex: Int? = nil
    @State private var selectedPhotos: Set<Int> = []
    @State private var showPicker: Bool = false
    @State private var showSearch: Bool = false
    @State private var showFolderSheet: Bool = false
    @State private var showAlbum: Bool = false
    @State private var segmentSelection: Int = 2
    @State private var showFastScroll: Bool = false
    @State private var dragPosition: CGFloat = 0

    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    let segments = ["後ろの月", "前の月", "すべての写真"]

    // MARK: - フィルタリング・グループ化
    var filteredPhotos: [Photo] {
        switch segmentSelection {
        case 0: // 後ろの月
            return photocontroller.photos.filter { photo in
                guard let date = photo.creationDate else { return false }
                return Calendar.current.isDate(date, equalTo: Date().addingTimeInterval(30*24*60*60), toGranularity: .month)
            }
        case 1: // 前の月
            return photocontroller.photos.filter { photo in
                guard let date = photo.creationDate else { return false }
                return Calendar.current.isDate(date, equalTo: Date().addingTimeInterval(-30*24*60*60), toGranularity: .month)
            }
        default: // すべての写真
            return photocontroller.photos
        }
    }

    var groupedByMonth: [String: [Photo]] {
        Dictionary(grouping: filteredPhotos) { photo in
            let date = photo.creationDate ?? Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM"
            return formatter.string(from: date)
        }
    }

    var monthStartIndex: [String: Int] {
        var dict: [String: Int] = [:]
        let sortedMonths = groupedByMonth.keys.sorted(by: >)
        for month in sortedMonths {
            if let firstPhoto = groupedByMonth[month]?.first,
               let index = filteredPhotos.firstIndex(of: firstPhoto) {
                dict[month] = index
            }
        }
        return dict
    }

    func scrollIndex(fromDrag value: CGFloat, totalHeight: CGFloat) -> Int {
        let y = min(max(value, 0), totalHeight)
        let ratio = y / totalHeight
        return Int(ratio * CGFloat(max(filteredPhotos.count-1, 0)))
    }

    var body: some View {
        NavigationView {
            VStack {
                ScrollViewReader { proxy in
                    ZStack(alignment: .trailing) {
                        GeometryReader { geo in
                            PhotoView(photocontroller: photocontroller)
                            .frame(width: geo.size.width, height: geo.size.height)
                        }

                        if showFastScroll {
                            VStack {
                                Spacer()
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 30, height: 150)
                                    .cornerRadius(15)
                                    .overlay(
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 30, height: 30)
                                            .offset(y: dragPosition)
                                            .gesture(
                                                DragGesture()
                                                    .onChanged { value in
                                                        dragPosition = value.location.y - 75
                                                        let index = scrollIndex(fromDrag: value.location.y, totalHeight: 150)
                                                        withAnimation(.linear(duration: 0.05)) {
                                                            proxy.scrollTo(index, anchor: .top)
                                                        }
                                                    }
                                            )
                                    )
                                Spacer()
                            }
                            .frame(width: 40)
                            .padding(.trailing, 8)
                        }

                        if let index = selectedIndex {
                            PhotoSliderView(
                                fetchController: photocontroller,
                                selectedIndex: index,
                                onClose: { selectedIndex = nil }
                            )
                            .zIndex(1)
                        }

                        FloatingButtonPanel(
                            selectedPhotos: $selectedPhotos,
                            showPicker: $showPicker,
                            showSearch: $showSearch,
                            showFolderSheet: $showFolderSheet,
                            photocontroller: photocontroller,       // ← PhotoController を渡す
                            foldercontroller: foldercontroller // ← FolderController を渡す
                        )


                    }
                    .onAppear {
                        if let lastIndex = filteredPhotos.indices.last {
                            proxy.scrollTo(lastIndex, anchor: .bottom)
                        }
                    }

                    if selectedIndex == nil {
                        Picker("", selection: $segmentSelection) {
                            ForEach(0..<segments.count, id: \.self) { i in
                                Text(segments[i])
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding()
                        .background(.ultraThinMaterial)
                        .onChange(of: segmentSelection) { newValue in
                            let month = segments[newValue]
                            if let index = monthStartIndex[month] {
                                withAnimation { proxy.scrollTo(index, anchor: .top) }
                            } else if month == "すべての写真" {
                                proxy.scrollTo(0, anchor: .top)
                            }
                        }
                    }
                }

                if !selectedPhotos.isEmpty {
                    HStack {
                        Spacer()
                        Button("cancel") { selectedPhotos.removeAll() }
                            .padding(.leading)
                        Spacer()
                    }
                }
            }
            .navigationTitle("写真")
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            PhotoPicker { images, assets in
                for (i, image) in images.enumerated() {
                    let creationDate = (i < assets.count) ? assets[i].creationDate ?? Date() : Date()
                    photocontroller.addPhoto(image, creationDate: creationDate)
                }
            }
        }
        .sheet(isPresented: $showFolderSheet) {
            FolderSheetView(
                isPresented: $showFolderSheet,
                selectedPhotos: .constant([]),
                photos: photocontroller.photos
            )
        }
        .fullScreenCover(isPresented: $showSearch) {
            SearchView(controller: photocontroller, isPresented: $showSearch)
        }
        .fullScreenCover(isPresented: $showAlbum) {
            FolderListView(photocontroller: photocontroller, foldercontroller: foldercontroller)
        }
    }
}

// MARK: - PhotoView (UICollectionView wrapped)
struct PhotoView: UIViewRepresentable {
    @ObservedObject var photocontroller: PhotoController

    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 5
        layout.minimumInteritemSpacing = 5
        layout.scrollDirection = .vertical

        // 3列で画面幅に収める
        let numberOfColumns: CGFloat = 3
        let totalSpacing = layout.minimumInteritemSpacing * (numberOfColumns - 1)
        let width = (UIScreen.main.bounds.width - totalSpacing) / numberOfColumns
        layout.itemSize = CGSize(width: width, height: width)

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .white
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.allowsMultipleSelection = true
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: "PhotoCell")
        return collectionView
    }



    func updateUIView(_ uiView: UICollectionView, context: Context) {
        uiView.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: photocontroller)
    }

    // MARK: - Coordinator
    class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
        var controller: PhotoController
        var selectedPhotos: Set<UUID> = []   // ← ここで追加

        init(controller: PhotoController) {
            self.controller = controller
        }
        
        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            let photo = controller.photos[indexPath.item]
            guard let id = photo.id else { return }   // ← アンラップ
            if selectedPhotos.contains(id) {
                selectedPhotos.remove(id)
                collectionView.deselectItem(at: indexPath, animated: true)
            } else {
                selectedPhotos.insert(id)
            }
            print("Selected photos: \(selectedPhotos)")
        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            controller.photos.count
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCell
            let photo = controller.photos[indexPath.item]
            cell.configure(with: photo)
            return cell
        }
    }
}

// MARK: - UICollectionViewCell
class PhotoCell: UICollectionViewCell {
    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with photo: Photo) {
        if let data = photo.imageData, let uiImage = UIImage(data: data) {
            imageView.image = uiImage
        } else {
            imageView.image = nil
        }
    }
}



class PhotoCollectionViewController: UICollectionViewController {

    var photos: [Photo] = []

    init() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 5
        layout.minimumInteritemSpacing = 5
        super.init(collectionViewLayout: layout)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.backgroundColor = .white
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: "PhotoCell")
        collectionView.allowsMultipleSelection = true
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCell
        cell.configure(with: photos[indexPath.item])
        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("Selected photo at \(indexPath.item)")
    }
}




/*struct PhotoGridCell: View {
    var photo: Photo
    var isSelected: Bool

    @State private var uiImage: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let image = uiImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 100)
                    .clipped()
            } else {
                Color.gray.opacity(0.1)
                    .frame(height: 100)
                    .onAppear {
                        DispatchQueue.global(qos: .userInitiated).async {
                            if let data = photo.imageData,
                               let loaded = UIImage(data: data) {
                                DispatchQueue.main.async {
                                    uiImage = loaded
                                }
                            }
                        }
                    }
            }

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .padding(5)
            }
        }
        .cornerRadius(8)
    }
}*/

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
    var photocontroller: PhotoController
    var foldercontroller: FolderController

    var body: some View {
        VStack { Spacer()
            HStack {
                NavigationLink(destination: FolderListView(photocontroller: photocontroller,
                                                           foldercontroller: foldercontroller)) {
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
                let captureDate = asset?.creationDate ?? Date()  // 撮影日がなければ現在日付で代用

                // Core Data へ保存
                let newPhoto = Photo(context: viewContext)
                newPhoto.imageData = image.jpegData(compressionQuality: 0.9)
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
