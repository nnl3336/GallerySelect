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

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Photo.date, ascending: true)],
        animation: .default)
    private var photos: FetchedResults<Photo>
    
    @State private var showPicker = false
    @State private var selectedIndex: Int? = nil
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ZStack {
            VStack {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(photos.indices, id: \.self) { index in
                            if let imageData = photos[index].imageData,
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 100)
                                    .clipped()
                                    .cornerRadius(8)
                                    .onTapGesture {
                                        selectedIndex = index
                                    }
                                    .contextMenu {
                                        // 保存
                                        Button {
                                            saveImageToCameraRoll(uiImage)
                                        } label: {
                                            Label("保存", systemImage: "square.and.arrow.down")
                                        }

                                        // 削除
                                        Button(role: .destructive) {
                                            deletePhoto(at: index)
                                        } label: {
                                            Label("削除", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                    .padding()
                }
                
                Button("写真を選択") {
                    showPicker = true
                }
                .padding()
            }
            
            // オーバーレイ表示
            if let index = selectedIndex {
                PhotoSliderView(
                    photos: photos.compactMap { $0.imageData }.map { UIImage(data: $0)! },
                    selectedIndex: index,
                    onClose: { selectedIndex = nil }
                )
                .zIndex(1)
            }
        }
        .sheet(isPresented: $showPicker) {
            PhotoPicker { images, assets in
                for (index, image) in images.enumerated() {
                    let newPhoto = Photo(context: viewContext)
                    newPhoto.id = UUID()
                    
                    // PHAsset から creationDate を取得できれば使う
                    if index < assets.count, let creationDate = assets[index].creationDate {
                        newPhoto.date = creationDate
                    } else {
                        newPhoto.date = Date()
                    }
                    
                    newPhoto.imageData = image.jpegData(compressionQuality: 0.8)
                    
                    do {
                        try viewContext.save()
                    } catch {
                        print(error)
                    }
                }
            }
        }
    }
}

extension ContentView {
    
    // MARK: - func
    
    func deletePhoto(at index: Int) {
        let photo = photos[index]
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
                DispatchQueue.main.async { // UI 更新は必ず main thread
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

// MARK: - PhotoPicker

struct PhotoPicker: UIViewControllerRepresentable {
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
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: PhotoPicker
        init(_ parent: PhotoPicker) { self.parent = parent }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            var images: [UIImage] = []
            var assets: [PHAsset] = []
            
            let group = DispatchGroup()
            
            for result in results {
                // PHAsset を取得
                if let assetId = result.assetIdentifier,
                   let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil).firstObject {
                    assets.append(asset)
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
