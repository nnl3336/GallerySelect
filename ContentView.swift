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
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(photos) { photo in
                        if let imageData = photo.imageData,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 100)
                                .clipped()
                                .cornerRadius(8)
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
        .sheet(isPresented: $showPicker) {
            PhotoPicker { images in
                for image in images {
                    let now = Date() // アプリ内での撮影日
                    saveToCoreDataAndCameraRoll(image: image, date: now)
                }
            }
        }
    }
    
    // Core Data とカメラロールに保存
    func saveToCoreDataAndCameraRoll(image: UIImage, date: Date) {
        // 1. Core Data 保存
        let newPhoto = Photo(context: viewContext)
        newPhoto.id = UUID()
        newPhoto.date = date
        newPhoto.imageData = image.jpegData(compressionQuality: 0.8)
        
        do {
            try viewContext.save()
        } catch {
            print("Core Data 保存エラー: \(error)")
        }
        
        // 2. カメラロールに保存（creationDate 指定）
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else { return }
            
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
                request.creationDate = date
            }) { success, error in
                if success {
                    print("カメラロール保存成功: \(date)")
                } else {
                    print("カメラロール保存失敗: \(error?.localizedDescription ?? "")")
                }
            }
        }
    }
}

struct PhotoPicker: UIViewControllerRepresentable {
    var completion: ([UIImage]) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0
        config.filter = .images
        
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
            
            let group = DispatchGroup()
            
            for result in results {
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    group.enter()
                    result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                        if let image = object as? UIImage { images.append(image) }
                        group.leave()
                    }
                }
            }
            
            group.notify(queue: .main) {
                self.parent.completion(images)
            }
        }
    }
}
