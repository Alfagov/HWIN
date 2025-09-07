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
    @State private var showingAddSheet = false
    
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
            .navigationTitle("My Drugs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Drug")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ProfileView()) {
                        Image(systemName: "person.crop.circle")
                            .font(.title2)
                    }
                }
                
            }
            .sheet(isPresented: $showingAddSheet) {
                AddDrugView { name, dose, schedule in
                    // Create and insert a new Drug using the provided initializer.
                    let newDrug = Drug(name: name, dose: dose, admnisteredOn: schedule)
                    modelContext.insert(newDrug)
                }
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

private struct AddDrugView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Basic fields
    @State private var name: String = ""
    @State private var dose: String = ""
    
    // Simple schedule builder: choose a day and add times as free text
    @State private var selectedDay: String = "Monday"
    @State private var timeText: String = ""
    @State private var schedule: [String: [String]] = [:]
    
    let onSave: (_ name: String, _ dose: String, _ schedule: [String: [String]]) -> Void
    
    private let daysOfWeek = [
        "Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Drug")) {
                    TextField("Name", text: $name)
                    TextField("Dose (e.g., 20mg)", text: $dose)
                        .textInputAutocapitalization(.never)
                }
                
                Section(header: Text("Schedule")) {
                    Picker("Day", selection: $selectedDay) {
                        ForEach(daysOfWeek, id: \.self) { day in
                            Text(day).tag(day)
                        }
                    }
                    HStack {
                        TextField("Time (e.g., 8:00 AM)", text: $timeText)
                            .textInputAutocapitalization(.never)
                        Button("Add") {
                            let trimmed = timeText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            var times = schedule[selectedDay] ?? []
                            times.append(trimmed)
                            schedule[selectedDay] = times
                            timeText = ""
                        }
                    }
                    
                    if !schedule.isEmpty {
                        ForEach(schedule.keys.sorted(), id: \.self) { day in
                            if let times = schedule[day], !times.isEmpty {
                                VStack(alignment: .leading) {
                                    Text(day).font(.headline)
                                    ForEach(times, id: \.self) { t in
                                        Text("• \(t)")
                                    }
                                }
                            }
                        }
                    } else {
                        Text("No times added yet.")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Add Drug")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let finalSchedule = schedule
                        onSave(name, dose, finalSchedule)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              dose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
