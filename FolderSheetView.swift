//
//  FolderSheetView.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/18.
//

import SwiftUI

// MARK: - Folder
struct FolderSheetView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var isPresented: Bool
    @Binding var selectedPhotos: Set<Int>
    @State private var folderName = ""
    @FocusState private var isTextFieldFocused: Bool
    
    // 選択されている写真の配列
    var photos: [Photo]
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                    folderName = ""
                }
            
            VStack(spacing: 20) {
                Text("新しいフォルダ名を入力")
                    .font(.headline)
                
                TextField("フォルダ名", text: $folderName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        createFolder()
                    }
                
                HStack {
                    Button("キャンセル") {
                        isPresented = false
                        folderName = ""
                    }
                    Spacer()
                    Button("作成") {
                        createFolder()
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
        .onAppear {
            DispatchQueue.main.async {
                isTextFieldFocused = true
            }
        }
    }
    
    private func createFolder() {
        guard !folderName.isEmpty else { return }

        let newFolder = Folder(context: viewContext)
        newFolder.name = folderName
        
        for index in selectedPhotos {
            if index >= 0, index < photos.count {    // ← 安全チェック
                newFolder.addToPhotos(photos[index])
            }
        }
        
        do {
            try viewContext.save()
            print("フォルダ保存成功: \(folderName)")
        } catch {
            print("フォルダ保存失敗: \(error)")
        }
        
        // リセット
        selectedPhotos.removeAll()
        folderName = ""
        isPresented = false
    }

}
