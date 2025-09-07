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
import AVFoundation
import SwiftData

struct DrugScanView: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var recognizedText = "Tap 'Take Picture' to begin."
    @State private var image: UIImage?
    @State private var isShowingCamera = false
    @State private var medicationName = ""
    @State private var medicationData = ""
    
    // Schedule derived from SwiftData Drug matches
    @State private var scheduleItems: [(day: String, time: String)] = []
    
    // Text-to-Speech
    @State private var synthesizer = AVSpeechSynthesizer()
    @State private var isPaused = false
    
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
                    
                    // Your Schedule
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Schedule")
                            .font(.headline)
                        
                        if scheduleItems.isEmpty {
                            Text("No schedule found for \(medicationName.isEmpty ? "this medication" : medicationName).")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(Array(scheduleItems.enumerated()), id: \.offset) { _, item in
                                        HStack(spacing: 6) {
                                            Text(shortWeekdayName(for: item.day))
                                                .font(.subheadline).bold()
                                            Text("•")
                                            Text(item.time)
                                                .font(.subheadline)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color(UIColor.systemGray6))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    Text("General Info")
                        .font(.headline)
                    
                    // TTS controls
                    HStack(spacing: 16) {
                        Button {
                            handleSpeakButton()
                        } label: {
                            Label(speakButtonTitle, systemImage: speakButtonSystemImage)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(medicationData.trimmingCharacters(in: .newlines).isEmpty)
                        
                        Button {
                            stopSpeaking()
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!synthesizer.isSpeaking && !isPaused)
                    }
                    .padding(.horizontal)
                    
                    // Read-only medication data
                    ScrollView {
                        Text(medicationData)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(height: 150)
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ProfileView()) {
                        Image(systemName: "person.crop.circle")
                            .font(.title2)
                    }
                }
                
            }
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
            .onDisappear {
                // Ensure speech stops when leaving the screen
                stopSpeaking()
            }
            .onChange(of: medicationName) { _, newValue in
                Task { await loadSchedule(for: newValue) }
            }
        }
        
    }
    
    
    private var speakButtonTitle: String {
        if synthesizer.isSpeaking && !isPaused { return "Pause" }
        if isPaused { return "Resume" }
        return "Speak"
    }
    
    private var speakButtonSystemImage: String {
        if synthesizer.isSpeaking && !isPaused { return "pause.fill" }
        if isPaused { return "play.fill" }
        return "speaker.wave.2.fill"
    }
    
    private func handleSpeakButton() {
        if synthesizer.isSpeaking && !isPaused {
            synthesizer.pauseSpeaking(at: .immediate)
            isPaused = true
        } else if isPaused {
            synthesizer.continueSpeaking()
            isPaused = false
        } else {
            speakMedication()
        }
    }
    
    private func speakMedication() {
        let text = medicationData.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // Stop any ongoing speech before starting new
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isPaused = false
        
        let utterance = AVSpeechUtterance(string: text)
        // Configure voice for US English and comfortable rate for elderly users
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.8
        utterance.pitchMultiplier = 1.0
        utterance.postUtteranceDelay = 0.2
        
        synthesizer.speak(utterance)
    }
    
    private func stopSpeaking() {
        if synthesizer.isSpeaking || isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isPaused = false
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
    
    // MARK: - Schedule loading
    
    private func loadSchedule(for name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            await MainActor.run { scheduleItems = [] }
            return
        }
        do {
            let orderedSame = ComparisonResult.orderedSame

            let descriptor = FetchDescriptor<Drug>(
                predicate: #Predicate<Drug> { drug in
                    drug.name.caseInsensitiveCompare(trimmed) == orderedSame
                }
            )
            
            let matches = try modelContext.fetch(descriptor)
            let flattened = flattenSchedules(from: matches)
            await MainActor.run {
                self.scheduleItems = flattened
            }
        } catch {
            await MainActor.run { self.scheduleItems = [] }
        }
    }
    
    private func flattenSchedules(from drugs: [Drug]) -> [(day: String, time: String)] {
        // Merge all schedules from matching drugs
        var pairs: [(String, String)] = []
        for drug in drugs {
            for (day, times) in drug.admnistered {
                for t in times {
                    pairs.append((day, t))
                }
            }
        }
        // Sort by weekday order then by time if possible
        pairs.sort { lhs, rhs in
            let lDay = weekdayIndex(for: lhs.0)
            let rDay = weekdayIndex(for: rhs.0)
            if lDay != rDay { return lDay < rDay }
            // Try to parse times to sort; fallback to string compare
            if let lt = parsedTime(lhs.1), let rt = parsedTime(rhs.1) {
                return lt < rt
            }
            return lhs.1 < rhs.1
        }
        return pairs
    }
    
    private func weekdayIndex(for name: String) -> Int {
        // Support common spellings, fallback to end
        let order = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
        // Also handle potential misspelling "Wensday" found in sample data
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.caseInsensitiveCompare("Wensday") == .orderedSame {
            return 3 // Wednesday index
        }
        if let idx = order.firstIndex(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame }) {
            return idx
        }
        return Int.max
    }
    
    private func shortWeekdayName(for name: String) -> String {
        let map: [String: String] = [
            "Sunday": "Sun",
            "Monday": "Mon",
            "Tuesday": "Tue",
            "Wednesday": "Wed",
            "Wensday": "Wed",
            "Thursday": "Thu",
            "Friday": "Fri",
            "Saturday": "Sat"
        ]
        // Default to first three chars capitalized
        let key = map.keys.first { $0.caseInsensitiveCompare(name) == .orderedSame }
        if let key = key, let short = map[key] { return short }
        return String(name.prefix(3)).capitalized
    }
    
    private func parsedTime(_ timeString: String) -> Date? {
        // Parse strings like "8:00 AM" into a Date anchored to today just for sorting
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter.date(from: timeString.trimmingCharacters(in: .whitespaces))
    }
}

#Preview {
    DrugScanView()
}
