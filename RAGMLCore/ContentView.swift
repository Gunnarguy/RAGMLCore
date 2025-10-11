//
//  ContentView.swift
//  RAGMLCore
//
//  Created by Gunnar Hostetler on 10/9/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var ragService = RAGService()
    
    var body: some View {
        TabView {
            ChatView(ragService: ragService)
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }
            
            DocumentLibraryView(ragService: ragService)
                .tabItem {
                    Label("Documents", systemImage: "doc.text.magnifyingglass")
                }
            
            CoreValidationView(ragService: ragService)
                .tabItem {
                    Label("Tests", systemImage: "checkmark.circle")
                }
            
            ModelManagerView(ragService: ragService)
                .tabItem {
                    Label("Models", systemImage: "brain.head.profile")
                }
            
            NavigationView {
                SettingsView(ragService: ragService)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}

#Preview {
    ContentView()
}
