//
//  SearchView.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/17.
//

import SwiftUI

struct SearchView: View {
    var controller: PhotoController
    @Binding var isPresented: Bool
    
    @State private var keyword = ""
    @State private var showLikedOnly = false
    
    var body: some View {
        ZStack {
            // 背景の薄黒
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            // メインの検索パネル
            VStack(spacing: 20) {
                HStack {
                    Text("検索")
                        .font(.headline)
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .padding()
                
                TextField("検索ワードを入力", text: $keyword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .submitLabel(.search)
                    .onSubmit {
                        applyFilter()
                    }
                    .padding(.horizontal)
                
                Toggle("いいねのみ表示", isOn: $showLikedOnly)
                    .padding(.horizontal)
                
                Button(action: {
                    applyFilter()
                }) {
                    Text("適用")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .frame(height: 300) // ← ここで高さを小さく調整
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .padding(.horizontal, 20)
        }
        .animation(.easeInOut, value: isPresented)
    }
    
    private func applyFilter() {
        controller.applyFilter(keyword: keyword, likedOnly: showLikedOnly)
        isPresented = false
    }
}
