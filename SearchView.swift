//
//  SearchView.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/17.
//

import SwiftUI

struct SearchView: View {
    var controller: PhotoController        // ← @ObservedObject じゃなくてOK
    @Binding var isPresented: Bool
    
    @State private var keyword = ""
    @State private var showLikedOnly = false
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("検索ワードを入力", text: $keyword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Toggle("いいねのみ表示", isOn: $showLikedOnly)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("検索")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("適用") {
                        controller.applyFilter(keyword: keyword, likedOnly: showLikedOnly)
                        isPresented = false
                    }
                }
            }
        }
    }
}
