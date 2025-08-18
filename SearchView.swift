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
    @FocusState private var isTextFieldFocused: Bool   // ← フォーカス管理
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
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
                    .focused($isTextFieldFocused) // ← フォーカス状態に紐付け
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
            .frame(height: 300)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .padding(.horizontal, 20)
            .onAppear {
                // 表示されたら自動でフォーカス
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTextFieldFocused = true
                }
            }
        }
        .animation(.easeInOut, value: isPresented)
    }
    
    private func applyFilter() {
        controller.applyFilter(keyword: keyword, likedOnly: showLikedOnly)
        isPresented = false
    }
}
