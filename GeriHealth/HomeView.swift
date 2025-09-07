//
//  HomeView.swift
//  GeriHealth
//
//  Created by Lorenzo P on 9/6/25.
//

import SwiftUI
import Foundation
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profile: [UserModel]
    
    var body: some View {
    
            TabView {
                Tab("Navigate", systemImage: "house.fill") {
                    Text("Navigate")
                }
                
                Tab("Scan", systemImage: "camera.fill") {
                    DrugScanView()
                        .modelContext(modelContext)
                }
                
                Tab("My Drugs", systemImage: "pill.fill") {
                    MyDrugsView()
                        .modelContext(modelContext)
                }
            }
            
        
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Schema([
        UserModel.self,
        Drug.self
    ]), configurations: config)
    Drug.sampleData.forEach { contact in
        container.mainContext.insert(contact)
    }
    return HomeView()
        .modelContainer(container)
}
