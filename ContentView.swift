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
    
    @ObservedObject var controller: PhotoController
    @State private var currentScreen: AppScreen = .photos

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch currentScreen {
                case .photos:
                    MainView(controller: controller)
                case .albums:
                    FolderListView(controller: controller)
                }
            }
            .transition(.opacity)

            // 画面下の切り替えボタン
            /*HStack {
                Button {
                    withAnimation { currentScreen = .photos }
                } label: {
                    Label("写真", systemImage: "photo")
                        .padding()
                }

                Spacer()

                Button {
                    withAnimation { currentScreen = .albums }
                } label: {
                    Label("アルバム", systemImage: "rectangle.stack")
                        .padding()
                }
            }
            .padding()
            .background(.ultraThinMaterial)*/
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
        let photo = controller.photos[index]  // ← controller.photos に変更
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
    @ObservedObject var controller: PhotoController
    @State private var selectedIndex: Int? = nil
    @State private var selectedPhotos = Set<Int>()
    @State private var showPicker = false
    @State private var showSearch = false
    @State private var showFolderSheet = false
    @State private var showAlbum = false
    // セグメント
    @State private var segmentSelection = 2
    // 以前
    //let segments = ["すべての写真", "前の月", "後ろの月"]

    // 逆順に
    let segments = ["後ろの月", "前の月", "すべての写真"]
    // 右端スクロールバー
    @State private var showFastScroll = false
    @State private var dragPosition: CGFloat = 0

    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var filteredPhotos: [Photo] {
        switch segmentSelection {
        case 0: // 後ろの月
            return controller.photos.filter { photo in
                guard let date = photo.creationDate else { return false }
                return Calendar.current.isDate(date, equalTo: Date().addingTimeInterval(30*24*60*60), toGranularity: .month)
            }
        case 1: // 前の月
            return controller.photos.filter { photo in
                guard let date = photo.creationDate else { return false }
                return Calendar.current.isDate(date, equalTo: Date().addingTimeInterval(-30*24*60*60), toGranularity: .month)
            }
        case 2: // すべての写真
            return controller.photos
        default:
            return controller.photos
        }
    }

    var body: some View {
        NavigationView {
            VStack {

                // 写真グリッド + 右端スクロール
                ScrollViewReader { proxy in
                    ZStack(alignment: .trailing) {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(filteredPhotos.indices, id: \.self) { index in
                                    let photo = filteredPhotos[index]
                                    let isSelected = selectedPhotos.contains(index)
                                    
                                    PhotoGridCell(photo: photo, isSelected: isSelected)
                                        .id(index)
                                        .onTapGesture {
                                            if !selectedPhotos.isEmpty {
                                                if isSelected {
                                                    selectedPhotos.remove(index)
                                                } else {
                                                    selectedPhotos.insert(index)
                                                }
                                            } else {
                                                selectedIndex = index
                                            }
                                        }
                                        .contextMenu {
                                            Button(isSelected ? "選択解除" : "選択") {
                                                if isSelected { selectedPhotos.remove(index) }
                                                else { selectedPhotos.insert(index) }
                                            }

                                            if let uiImage = photo.thumbnail {
                                                Button {
                                                    controller.saveImageToCameraRoll(uiImage)
                                                } label: {
                                                    Label("保存", systemImage: "square.and.arrow.down")
                                                }
                                            }

                                            Button {
                                                controller.deletePhoto(at: index)
                                            } label: {
                                                Label("削除", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                            .padding()
                            .gesture(DragGesture()
                                        .onChanged { _ in
                                            showFastScroll = true
                                        }
                                        .onEnded { _ in
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                                showFastScroll = false
                                            }
                                        }
                            )
                        }

                        // 右端スクロールハンドル
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
                                                        let totalHeight: CGFloat = 150
                                                        let y = min(max(value.location.y, 0), totalHeight)
                                                        dragPosition = y - totalHeight/2
                                                        let ratio = y / totalHeight
                                                        let index = Int(ratio * CGFloat(max(filteredPhotos.count-1, 0)))
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
                            .transition(.opacity)
                            .animation(.easeInOut, value: showFastScroll)
                        }

                        // フルスクリーンスライダー
                        if let index = selectedIndex {
                            PhotoSliderView(
                                fetchController: controller,
                                selectedIndex: index,
                                onClose: { selectedIndex = nil }
                            )
                            .zIndex(1)
                        }

                        // フローティングボタン
                        FloatingButtonPanel(
                            selectedPhotos: $selectedPhotos,
                            showPicker: $showPicker,
                            showSearch: $showSearch,
                            showFolderSheet: $showFolderSheet,
                            controller: controller
                        )
                    }
                }
                
                // ↓ここにセグメントを下部に置く
                    if selectedIndex == nil {
                        Picker("", selection: $segmentSelection) {
                            ForEach(0..<segments.count, id: \.self) { i in
                                Text(segments[i])
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding()
                    }
                
                // 選択中ならCancelボタンを表示
                        if !selectedPhotos.isEmpty {
                            HStack {
                                Spacer()
                                Button("cancel") {
                                    selectedPhotos.removeAll()
                                }
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
                    controller.addPhoto(image, creationDate: creationDate)
                }
            }
        }
        .sheet(isPresented: $showFolderSheet) {
            FolderSheetView(
                isPresented: $showFolderSheet,
                selectedPhotos: $selectedPhotos,
                photos: controller.photos   // ← ここで配列を渡す
            )
        }
        
        
        .fullScreenCover(isPresented: $showSearch) {
            SearchView(controller: controller, isPresented: $showSearch)
        }
        .fullScreenCover(isPresented: $showAlbum) {
            FolderListView(controller: controller) // ← 仮のアルバム画面
        }
    }
}

struct PhotoGridCell: View {
    var photo: Photo
    var isSelected: Bool
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let thumb = thumbnail {
                Image(uiImage: thumb)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 100)
                    .clipped()
                    .cornerRadius(8)
                    .overlay(
                        isSelected ? Color.blue.opacity(0.3).cornerRadius(8) : nil
                    )
                    .contentShape(Rectangle())
            } else {
                Color.gray.frame(height: 100).cornerRadius(8)
            }

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
                    .padding(5)
            }
        }
        .onAppear {
            if thumbnail == nil, let data = photo.imageData,
               let uiImage = UIImage(data: data) {
                DispatchQueue.global(qos: .userInitiated).async {
                    let resized = uiImage.resize(to: CGSize(width: 150, height: 150))
                    DispatchQueue.main.async {
                        thumbnail = resized
                    }
                }
            }
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
