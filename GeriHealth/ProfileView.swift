//
//  ProfileView.swift
//  GeriHealth
//
//  Created by Lorenzo P on 9/6/25.
//

import SwiftUI
import PhotosUI
import MapKit
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [UserModel]
    
    // Keep a reference to the single user model we are editing
    @State private var user: UserModel?
    
    // State for the Photos picker (image is not yet part of the model)
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImageData: Data?
    
    // Computed property to calculate age from the birth date
    private var computedAge: Int {
        guard let dob = user?.dateOfBirth else { return 0 }
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: dob, to: Date())
        return ageComponents.year ?? 0
    }
    
    @State private var isShowingAddressPicker = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                        VStack {
                            if let imageData = profileImageData, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 150, height: 150)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                                    .shadow(radius: 5)
                            } else {
                                // Placeholder image
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 150, height: 150)
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                        }
                    }
                    .onChange(of: selectedPhoto) {
                        Task {
                            if let data = try? await selectedPhoto?.loadTransferable(type: Data.self) {
                                profileImageData = data
                                // If you later add an image property to UserModel, assign and persist here.
                            }
                        }
                    }
                    
                    Text("\(computedAge)")
                        .foregroundColor(.black)
                        .font(.headline)
                    
                    Form {
                        Section(header: Text("Personal Information")) {
                            TextField("First Name", text: Binding(
                                get: { user?.name ?? "" },
                                set: { newValue in user?.name = newValue }
                            ))
                            
                            TextField("Last Name", text: Binding(
                                get: { user?.surname ?? "" },
                                set: { newValue in user?.surname = newValue }
                            ))
                            
                            Button(action: {
                                isShowingAddressPicker.toggle()
                            }) {
                                HStack {
                                    Text("Location")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(user?.location ?? "")
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                        }
                        
                        Section(header: Text("Details")) {
                            DatePicker(
                                "Date of Birth",
                                selection: Binding(
                                    get: { user?.dateOfBirth ?? Date() },
                                    set: { newDate in
                                        user?.dateOfBirth = newDate
                                        // Keep age in sync with dateOfBirth if you want to store it
                                        user?.age = Self.calculateAge(from: newDate)
                                    }
                                ),
                                displayedComponents: .date
                            )
                        }
                    }
                    .frame(height: 500) // Adjust height to prevent excessive scrolling
                    .cornerRadius(12)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("My Profile")
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: $isShowingAddressPicker) {
                AddressPickerView(location: Binding(
                    get: { user?.location ?? "" },
                    set: { newValue in user?.location = newValue }
                ))
            }
            .onAppear {
                ensureUser()
            }
        }
    }
    
    private func ensureUser() {
        if let existing = users.first {
            user = existing
        } else {
            // Create a default user if none exists
            let defaultDOB = Calendar.current.date(from: DateComponents(year: 1945, month: 5, day: 20)) ?? Date()
            let newUser = UserModel(
                name: "John",
                surname: "Appleseed",
                dateOfBirth: defaultDOB,
                age: Self.calculateAge(from: defaultDOB),
                location: "Cupertino, CA"
            )
            modelContext.insert(newUser)
            user = newUser
        }
    }
    
    private static func calculateAge(from date: Date) -> Int {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: date, to: Date())
        return ageComponents.year ?? 0
    }
}

#Preview {
    // In-memory model container for preview
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Schema([
        UserModel.self
    ]), configurations: config)
    // Seed a user for preview
    let defaultDOB = Calendar.current.date(from: DateComponents(year: 1945, month: 5, day: 20)) ?? Date()
    let previewUser = UserModel(name: "John", surname: "Appleseed", dateOfBirth: defaultDOB, age: 80, location: "Cupertino, CA")
    container.mainContext.insert(previewUser)
    return ProfileView()
        .modelContainer(container)
}

struct AddressPickerView: View {
    @Binding var location: String
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    
    // Function to perform the address search
    private func searchAddress() {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let response = response else {
                print("Error searching for location: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            self.searchResults = response.mapItems
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("Search for a city or address", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .onChange(of: searchText) {
                        // Debounce or add a small delay if needed, but for simplicity we search directly
                        searchAddress()
                    }
                
                List(searchResults, id: \.self) { item in
                    VStack(alignment: .leading) {
                        Text(item.name ?? "Unknown place")
                            .font(.headline)
                        Text(item.placemark.title ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .onTapGesture {
                        // Use the placemark's title for a well-formatted address string
                        self.location = item.placemark.title ?? "Selected Location"
                        dismiss()
                    }
                }
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
