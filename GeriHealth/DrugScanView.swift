//
//  DrugScanView.swift
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


struct DrugScanView: View {
    @State private var recognizedText = "Tap 'Take Picture' to begin."
    @State private var image: UIImage?
    @State private var isShowingCamera = false
    @State private var medicationName = ""
    @State private var medicationData = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 25) {
                if let uiImage = image {
                    Group {
                        if let uiImage = image {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(radius: 8)
                        }
                    }
                    .padding(.horizontal)
                    .onTapGesture {
                        self.isShowingCamera = true
                    }
                    
                    Text("Your Schedule")
                        .font(.headline)
                    
                    Text("General Info")
                        .font(.headline)
                    TextEditor(text: $medicationData)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        )
                        .shadow(radius: 5)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.systemGray6))
                        .overlay(
                            VStack(spacing: 15) {
                                Image(systemName: "camera.viewfinder")
                                    .font(.largeTitle)
                                Text("Take a picture")
                                    .font(.largeTitle)
                            }
                            .foregroundStyle(.secondary)
                        )
                        .onTapGesture {
                            self.isShowingCamera = true
                        }
                        .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Scan")
            .fullScreenCover(isPresented: $isShowingCamera) {
                CameraView(
                    selectedImage: $image,
                    onImagePicked: { pickedImage in
                        // When an image is picked, update the state and perform OCR
                        self.image = pickedImage
                        Task {
                            let medName = await performOCR(on: pickedImage)
                            
                            let data = await fdaService.fetchDrugData(name: medName)
                            
                            let summaryInstructions = """
                            You are an expert summarizer assistant. From the following text summuarize in 2 sentences the informations given about the drug into information usable for an elderly person in the US. BE FACTUAL AND OBJECTIVE
                            
                            DO NOT INCLUDE INFORMATION THAT IS NOT USEFUL. JUST RESPOND WITH THE SUMMARIZED RESULT.
                            """
                            
                            let ai = FirebaseAI.firebaseAI(backend: .googleAI())

                            // Create a `GenerativeModel` instance with a model that supports your use case
                            let model = ai.generativeModel(modelName: "gemini-2.5-flash", generationConfig: .init(temperature: 0.1))
                            
                            do {
                                let resp = try await model.generateContent("\(summaryInstructions): \(data)")
                                medicationData = resp.text ?? "GEMINI ERROR"
                            } catch {
                                medicationData = "GEMINI ERROR"
                            }
                        }
                    }
                )
            }
        }
        
    }
    
    /// Performs OCR on the provided UIImage.
    /// - Parameter image: The UIImage to process for text recognition.
    private func performOCR(on image: UIImage) async -> String {
        guard let cgImage = image.cgImage else {
            updateRecognizedText("Error: Could not process the image.")
            return ""
        }
        
        updateRecognizedText("1. Recognizing text...")
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        
        let handler = VNImageRequestHandler(cgImage: cgImage)
        
        do {
            try handler.perform([request])
            guard let observations = request.results else {
                updateRecognizedText("Error: Text recognition failed.")
                return ""
            }
            
            let ocrText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            
            if ocrText.isEmpty {
                updateRecognizedText("No text found in the image.")
                return ""
            }
            
            // Now, pass the raw text to the extraction function
            updateRecognizedText("\(ocrText)")
            let medicationName = await extractMedicationName(from: ocrText)
            
            // Display the final result
            updateRecognizedText("Medication Name:\n\n\(ocrText)")
            updateMedicationText(medicationName)
            
            return medicationName
            
        } catch {
            updateRecognizedText("Error: \(error.localizedDescription)")
            return ""
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
        
        let instructions = """
        You are an expert pharmacist assistant. From the following text, which was scanned from a medication label, extract ONLY the primary name of the drug or medication.

        Do not include the dosage, quantity, instructions, brand name if a generic is present, or any other information. Just return the medication name. For example, from "ATORVASTATIN 10 MG TABLET", you should return "ATORVASTATIN". From "Take one tablet of Lisinopril 20mg daily", you should return "Lisinopril".
        """
        

            // Use the powerful on-device LLM on iOS 18 and later
        if #available(iOS 26.0, *) {
                // Define instructions for the LLM
               
                do {
                    let session = LanguageModelSession(instructions: instructions)
                    let response = try await session.respond(to: text)
                    
                    // Clean up the response, as it might have extra whitespace
                    return response.rawContent.jsonString
                } catch {
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
        }
}

#Preview {
    DrugScanView()
}
