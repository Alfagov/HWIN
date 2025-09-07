//
//  HomeBoardingView.swift
//  GeriHealth
//
//  Created by Lorenzo P on 9/6/25.
//

import SwiftUI
import SwiftData
import Foundation

struct HomeBoardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var name: String = ""
    @State private var surname: String = ""
    @State private var dateOfBirth: Date = Calendar.current.date(from: DateComponents(year: 1950, month: 1, day: 1)) ?? Date()
    @State private var location: String = ""
    @State private var showMedicalAlert = false
    @State private var showSavedAlert = false
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case name, surname, location
    }
    
    private var age: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: dateOfBirth, to: Date())
        return components.year ?? 0
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Blue-green gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.0, green: 0.6, blue: 1.0), // blue
                        Color(red: 0.0, green: 0.82, blue: 0.67), // teal/green
                        Color(red: 0.16, green: 0.95, blue: 0.72) // lighter green
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 36) {
                    VStack(spacing: 8) {
                        Text("Welcome to")
                            .font(.title2)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                        Text("HWIN")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.18), radius: 4, y: 3)
                    }
                    .padding(.top, 36)
                    
                    VStack(alignment: .leading, spacing: 22) {
                        CustomTextField(
                            label: "First Name",
                            text: $name,
                            systemImage: "person.fill",
                            field: .name,
                            returnKey: .next
                        )
                        
                        CustomTextField(
                            label: "Last Name",
                            text: $surname,
                            systemImage: "person.fill",
                            field: .surname,
                            returnKey: .next
                        )
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Date of Birth")
                                .font(.caption)
                                .padding(.leading, 10)
                                .foregroundStyle(.black)
                            HStack {
                                DatePicker(
                                    "",
                                    selection: $dateOfBirth,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                
                                Spacer()
                                Text("Age: ")
                                    .foregroundStyle(.black)
                                Text("\(age)")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                    .padding(.trailing, 10)
                            }
                            
                        }
                        
                        CustomTextField(
                            label: "Location (City, State)",
                            text: $location,
                            systemImage: "mappin.and.ellipse",
                            field: .location,
                            returnKey: .done
                        )
                    }
                    .padding(24)
                    .background(
                        Color.white.opacity(0.16)
                            .blur(radius: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal)
                    
                    VStack(spacing: 18) {
                        Button(action: saveUser) {
                            HStack {
                                Spacer()
                                Text("Add My Profile")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 14)
                                Spacer()
                            }
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color.blue.opacity(0.96),
                                        Color.green.opacity(0.86)
                                    ],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: Color.black.opacity(0.10), radius: 4, y: 2)
                        }
                        .disabled(!isFormValid)
                        .opacity(isFormValid ? 1.0 : 0.55)
                        .animation(.easeInOut, value: isFormValid)
                        
                        Button {
                            showMedicalAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "stethoscope")
                                Text("Connect to Medical Provider")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Color.black)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(.ultraThinMaterial)
                            .backgroundStyle(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .alert("Provider Connection", isPresented: $showMedicalAlert) {
                            Button("OK", role: .cancel) {}
                        } message: {
                            Text("This feature is coming soon")
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.bottom, 10)
                .navigationBarTitleDisplayMode(.inline)
                .alert("Saved!", isPresented: $showSavedAlert) {
                    Button("OK") { focusedField = nil }
                } message: {
                    Text("Your profile was saved successfully.")
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !surname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && age > 0
    }
    
    private func saveUser() {
        let newUser = UserModel(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            surname: surname.trimmingCharacters(in: .whitespacesAndNewlines),
            dateOfBirth: dateOfBirth,
            age: age,
            location: location.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        modelContext.insert(newUser)
        showSavedAlert = true
    }
}

// Custom styled text field with icon and focus support
struct CustomTextField: View {
    let label: String
    @Binding var text: String
    let systemImage: String
    let field: HomeBoardingView.Field
    var returnKey: UIReturnKeyType = .default
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 20)
                .foregroundStyle(.black)
            
            TextField(label, text: $text)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .padding(.vertical, 13)
                .submitLabel(field == .location ? .done : .next)
        }
        .padding(.horizontal, 14)
        
    }
}

#Preview {
    HomeBoardingView()
}
