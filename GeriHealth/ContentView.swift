//
//  ContentView.swift
//  GeriHealth
//
//  Created by Lorenzo P on 9/6/25.
//

import SwiftUI
import Vision
import VisionKit
import FoundationModels
import CoreML
import FirebaseCore
import FirebaseAI

struct ContentView: View {
    @State private var recognizedText = "Tap 'Take Picture' to begin."
    @State private var image: UIImage?
    @State private var isShowingCamera = false
    @State private var medicationName = ""
    @State private var medicationData = ""
    
    var body: some View {
        VStack(spacing: 25) {
            Text("Medication OCR")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)

            // Display the captured image or a placeholder
            Group {
                if let uiImage = image {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 350)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 8)
                } else {
                    // Placeholder view
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.systemGray6))
                        .frame(height: 300)
                        .overlay(
                            VStack(spacing: 15) {
                                Image(systemName: "camera.viewfinder")
                                    .font(.largeTitle)
                                Text("Image will appear here")
                                    .font(.headline)
                            }
                            .foregroundStyle(.secondary)
                        )
                }
            }

            // Text editor to show the results
            TextEditor(text: $recognizedText)
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
                .shadow(radius: 5)
            
            Text("Medication Name")
            TextEditor(text: $medicationName)
                .frame(height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
                .shadow(radius: 5)
            
            Text("Drug Info")
                .font(.headline)
                .padding(.top, 10)
            
            TextEditor(text: $medicationData)
                .frame(height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
                .shadow(radius: 5)
            
            Button("Get Medication Info") {
                Task {
                    let data = await fdaService.fetchDrugData(name: medicationName)
                    medicationData = data
                }
            }
            
            // The single button to launch the camera
            Button(action: {
                self.isShowingCamera = true
            }) {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Take Picture")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(Capsule())
            }
        }
        .padding()
        // Present the Camera using a full screen cover for a direct experience
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraView(
                selectedImage: $image,
                onImagePicked: { pickedImage in
                    // When an image is picked, update the state and perform OCR
                    self.image = pickedImage
                    Task {
                        await performOCR(on: pickedImage)
                    }
                }
            )
        }
    }

    /// Performs OCR on the provided UIImage.
    /// - Parameter image: The UIImage to process for text recognition.
    private func performOCR(on image: UIImage) async {
        guard let cgImage = image.cgImage else {
            updateRecognizedText("Error: Could not process the image.")
            return
        }
        
        updateRecognizedText("1. Recognizing text...")
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        
        let handler = VNImageRequestHandler(cgImage: cgImage)
        
        do {
            try handler.perform([request])
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                updateRecognizedText("Error: Text recognition failed.")
                return
            }
            
            let ocrText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            
            if ocrText.isEmpty {
                updateRecognizedText("No text found in the image.")
                return
            }
            
            // Now, pass the raw text to the extraction function
            updateRecognizedText("\(ocrText)")
            let medicationName = await extractMedicationName(from: ocrText)
            
            // Display the final result
            updateRecognizedText("Medication Name:\n\n\(ocrText)")
            updateMedicationText(medicationName)
            
        } catch {
            updateRecognizedText("Error: \(error.localizedDescription)")
        }
    }
    
    private func updateRecognizedText(_ text: String) {
        DispatchQueue.main.async {
            self.recognizedText = text
        }
    }
    
    private func updateMedicationText(_ text: String) {
        DispatchQueue.main.async {
            self.medicationName = text
        }
    }
    
    private func extractMedicationName(from text: String) async -> String {
            // Use the powerful on-device LLM on iOS 18 and later
        if #available(iOS 26.0, *) {
                // Define instructions for the LLM
                let instructions = """
                You are an expert pharmacist assistant. From the following text, which was scanned from a medication label, extract ONLY the primary name of the drug or medication.

                Do not include the dosage, quantity, instructions, brand name if a generic is present, or any other information. Just return the medication name. For example, from "ATORVASTATIN 10 MG TABLET", you should return "ATORVASTATIN". From "Take one tablet of Lisinopril 20mg daily", you should return "Lisinopril".
                """
                
                do {
                    let session = LanguageModelSession(instructions: instructions)
                    let response = try await session.respond(to: text)
                    
                    // Clean up the response, as it might have extra whitespace
                    return response.rawContent.jsonString
                } catch {
                    // If the LLM fails for any reason, use the simpler fallback method
                    // Initialize the Gemini Developer API backend service
                    let ai = FirebaseAI.firebaseAI(backend: .googleAI())

                    // Create a `GenerativeModel` instance with a model that supports your use case
                    let model = ai.generativeModel(modelName: "gemini-2.5-flash", generationConfig: .init(temperature: 0.1))
                    
                    do {
                        let resp = try await model.generateContent("\(instructions): \(text)")
                        return resp.text ?? "GEMINI ERROR"
                    } catch {
                        return "GEMINI ERROR"
                    }
                }
                
            } else {
                // Fallback for older iOS versions that don't have the LLM
                return "ERROR"
            }
        }
}

/// A helper view to wrap UIImagePickerController for direct camera access.
struct CameraView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    ContentView()
}
