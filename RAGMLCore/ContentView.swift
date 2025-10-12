//
//  ContentView.swift
//  RAGMLCore
//
//  Created by Gunnar Hostetler on 10/9/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var ragService = RAGService()
    @State private var selectedTab: Tab = .chat
    
    enum Tab {
        case chat, documents, tests, models, settings
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                ChatView(ragService: ragService)
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("Chat", systemImage: "bubble.left.and.bubble.right")
            }
            .tag(Tab.chat)
            
            NavigationView {
                DocumentLibraryView(ragService: ragService)
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("Documents", systemImage: "doc.text.magnifyingglass")
            }
            .tag(Tab.documents)
            
            NavigationView {
                CoreValidationView(ragService: ragService)
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("Tests", systemImage: "checkmark.circle")
            }
            .tag(Tab.tests)
            
            NavigationView {
                ModelManagerView(ragService: ragService)
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("Models", systemImage: "brain.head.profile")
            }
            .tag(Tab.models)
            
            NavigationView {
                SettingsView(ragService: ragService)
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(Tab.settings)
        }
    }
}

#Preview {
    ContentView()
}
