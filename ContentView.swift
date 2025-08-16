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
import CoreData
import PhotosUI

import SwiftUI
import PhotosUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Photo.date, ascending: true)],
        animation: .default)
    private var photos: FetchedResults<Photo>
    
    @State private var showPicker = false
    
    // グリッド列の設定
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
                        if let imageData = photo.imageData, let uiImage = UIImage(data: imageData) {
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
                    let newPhoto = Photo(context: viewContext)
                    newPhoto.id = UUID()
                    newPhoto.date = Date()
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
