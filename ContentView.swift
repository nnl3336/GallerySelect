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
                    AlbumView(controller: controller)
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

    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationView {
            ZStack {
                // 背景グリッド
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(controller.photos.indices, id: \.self) { index in
                            PhotoGridCell(
                                photo: controller.photos[index],
                                isSelected: selectedPhotos.contains(index)
                            )
                            .onTapGesture {
                                if !selectedPhotos.isEmpty {
                                    // 選択モード
                                    if selectedPhotos.contains(index) {
                                        selectedPhotos.remove(index)
                                    } else {
                                        selectedPhotos.insert(index)
                                    }
                                } else {
                                    // 通常モード
                                    selectedIndex = index
                                }
                            }
                            .contextMenu {
                                PhotoContextMenu(
                                    photo: controller.photos[index],
                                    isSelected: selectedPhotos.contains(index)
                                ) { toggle in
                                    if toggle {
                                        selectedPhotos.insert(index)
                                    } else {
                                        selectedPhotos.remove(index)
                                    }
                                } deleteAction: {
                                    controller.deletePhoto(at: index)
                                }
                            }
                        }
                    }
                    .padding()
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
            .navigationTitle("写真")
            .toolbar {
                // 選択モード中のみ Cancel ボタン
                if !selectedPhotos.isEmpty {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Cancel") {
                            selectedPhotos.removeAll()
                        }
                    }
                }
            }
            .sheet(isPresented: $showPicker) {
                PhotoPicker { images, assets in
                    for (i, image) in images.enumerated() {
                        let creationDate = (i < assets.count) ? assets[i].creationDate ?? Date() : Date()
                        controller.addPhoto(image, creationDate: creationDate)
                    }
                }
            }
            .sheet(isPresented: $showFolderSheet) {
                FolderSheetView(isPresented: $showFolderSheet, selectedPhotos: $selectedPhotos) { selectedPhotos, name in
                    // CoreData に保存
                }
            }
            .fullScreenCover(isPresented: $showSearch) {
                SearchView(controller: controller, isPresented: $showSearch)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PhotoGridCell: View {
    var photo: Photo
    var isSelected: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let data = photo.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 100)
                    .clipped()
                    .cornerRadius(8)
                    .overlay(
                        isSelected ? Color.blue.opacity(0.3).cornerRadius(8) : nil
                    )
            }
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
                    .padding(5)
            }
        }
    }
}

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

struct FloatingButtonPanel: View {
    @Binding var selectedPhotos: Set<Int>
    @Binding var showPicker: Bool
    @Binding var showSearch: Bool
    @Binding var showFolderSheet: Bool
    var controller: PhotoController

    var body: some View {
        VStack { Spacer()
            HStack {
                NavigationLink(destination: AlbumView(controller: controller)) {
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


// MARK: - Folder

struct FolderSheetView: View {
    @Binding var isPresented: Bool
    @Binding var selectedPhotos: Set<Int>
    @State private var folderName = ""
    
    var onCreate: (_ selected: Set<Int>, _ name: String) -> Void
    
    var body: some View {
        ZStack {
            // 背景の半透明レイヤー
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            // フォルダ作成シート本体
            VStack(spacing: 20) {
                Text("新しいフォルダ名を入力")
                    .font(.headline)
                
                TextField("フォルダ名", text: $folderName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                HStack {
                    Button("キャンセル") {
                        isPresented = false
                        folderName = ""
                    }
                    Spacer()
                    Button("作成") {
                        onCreate(selectedPhotos, folderName)
                        selectedPhotos.removeAll()
                        folderName = ""
                        isPresented = false
                    }
                }
                .padding(.horizontal)
                Spacer()
            }
            .padding()
            .frame(height: 250)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .padding(.horizontal, 20)
        }
        .animation(.easeInOut, value: isPresented)
    }
}


// MARK: - PhotoPicker

struct PhotoPicker: UIViewControllerRepresentable {
    @Environment(\.managedObjectContext) private var viewContext   // ← ここで参照

    // completion に UIImage と PHAsset を渡す
    var completion: (_ images: [UIImage], _ assets: [PHAsset]) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0 // 複数選択
        config.filter = .images   // 画像のみ
        
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
