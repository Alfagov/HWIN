//
//  ProfileView.swift
//  GeriHealth
//
//  Created by Lorenzo P on 9/6/25.
//

import SwiftUI
import PhotosUI
import MapKit

struct ProfileView: View {
    // State for user's personal information
    @State private var firstName: String = "John"
    @State private var lastName: String = "Appleseed"
    @State private var birthDate: Date = Calendar.current.date(from: DateComponents(year: 1945, month: 5, day: 20)) ?? Date()
    @State private var location: String = "Cupertino, CA"
    @State private var isShowingAddressPicker = false
    
    // State for the Photos picker
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImageData: Data?

    // Computed property to calculate age from the birth date
    private var age: Int {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
        return ageComponents.year ?? 0
    }
        
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
                            }
                        }
                    }
                    
                    Text("\(age)")
                        .foregroundColor(.black)
                        .font(.headline)
                    
                    Form {
                        Section(header: Text("Personal Information")) {
                            TextField("First Name", text: $firstName)
                            TextField("Last Name", text: $lastName)
                            Button(action: {
                                isShowingAddressPicker.toggle()
                            }) {
                                HStack {
                                    Text("Location")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(location)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                        }
                        
                        Section(header: Text("Details")) {
                            DatePicker("Date of Birth", selection: $birthDate, displayedComponents: .date)
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
                AddressPickerView(location: $location)
            }
        }
    }
}

#Preview {
    ProfileView()
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
