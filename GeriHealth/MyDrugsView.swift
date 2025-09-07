//
//  MyDrugsView.swift
//  GeriHealth
//
//  Created by Lorenzo P on 9/6/25.
//

import SwiftUI
import SwiftData

struct MyDrugsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var drugs: [Drug]
    
    var body: some View {
        NavigationStack {
            List(drugs) { drug in
                NavigationLink(destination: DrugView(drug: drug)) {
                    HStack {
                        Text(drug.name)
                            .font(.title)
                        Spacer()
                        Text(drug.dose)
                            .font(.headline)
                    }
                   
                }
                .padding()
            }
        }
    }
}

struct DrugView: View {
    let drug: Drug
    
    // Sort the dictionary keys to ensure the days are listed in order
    private var sortedDays: [String] {
        drug.admnistered.keys.sorted()
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // MARK: - Header
                VStack(alignment: .leading) {
                    Text(drug.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(drug.dose)
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                Divider()
                
                // MARK: - Schedule Section
                VStack(alignment: .leading, spacing: 15) {
                    Text("Administration Schedule")
                        .font(.title)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                        .padding(.bottom)
                    
                    // Create a view for each day in the schedule
                    
                    ForEach(sortedDays, id: \.self) { day in
                        if let times = drug.admnistered[day] {
                            HStack {
                                Spacer()
                                DayScheduleView(day: day, times: times)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        // Recommended to embed in a NavigationView for a title bar
        .navigationTitle("Drug Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem {
                Button("Edit") {
                    
                }
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Drug.self, configurations: config)
    Drug.sampleData.forEach { contact in
        container.mainContext.insert(contact)
    }
    return MyDrugsView()
        .modelContainer(container)
}

struct DayScheduleView: View {
    let day: String
    let times: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // MARK: - Day Header
            HStack {
                Image(systemName: "calendar")
                    .font(.headline)
                    .foregroundColor(.accentColor)
                Text(day)
                    .font(.headline)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(times, id: \.self) { time in
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.secondary.opacity(0.7))
                        Text(time)
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6)) // Soft background for the card
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
