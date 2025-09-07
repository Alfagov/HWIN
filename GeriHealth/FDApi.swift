//
//  FDApi.swift
//  GeriHealth
//
//  Created by Lorenzo P on 9/6/25.
//

import Foundation

struct APIResponse: Codable {
    let meta: Meta
    let results: [DrugLabel]
}

struct Meta: Codable {
    let disclaimer: String
    let terms, license: String
    let lastUpdated: String
    let results: MetaResults

    // We can use CodingKeys to map the JSON's "last_updated" to our "lastUpdated" property.
    enum CodingKeys: String, CodingKey {
        case disclaimer, terms, license
        case lastUpdated = "last_updated"
        case results
    }
}

struct MetaResults: Codable {
    let skip, limit, total: Int
}

struct DrugLabel: Codable, Identifiable {
    // The 'id' from the result object makes this struct Identifiable.
    let id: String
    let setId: String
    let version: String
    let effectiveTime: String
    let openfda: OpenFDA

    // The following properties are often present and contain detailed drug information.
    // They are marked as optional as they may not be in every record.
    let description: [String]?
    let clinicalPharmacology: [String]?
    let indicationsAndUsage: [String]?
    let contraindications: [String]?
    let warnings: [String]?
    let precautions: [String]?
    let adverseReactions: [String]?
    let overdosage: [String]?
    let dosageAndAdministration: [String]?
    let howSupplied: [String]?
    let splProductDataElements: [String]?
    let packageLabelPrincipalDisplayPanel: [String]?


    enum CodingKeys: String, CodingKey {
        case id
        case setId = "set_id"
        case version
        case effectiveTime = "effective_time"
        case openfda
        case description
        case clinicalPharmacology = "clinical_pharmacology"
        case indicationsAndUsage = "indications_and_usage"
        case contraindications
        case warnings
        case precautions
        case adverseReactions = "adverse_reactions"
        case overdosage
        case dosageAndAdministration = "dosage_and_administration"
        case howSupplied = "how_supplied"
        case splProductDataElements = "spl_product_data_elements"
        case packageLabelPrincipalDisplayPanel = "package_label_principal_display_panel"
    }
}

struct OpenFDA: Codable {
    let applicationNumber, brandName, genericName, manufacturerName: [String]
    let productNdc, productType, route, substanceName: [String]
    let rxcui, splId, splSetId, packageNdc: [String]
    let isOriginalPackager: [Bool]?
    let upc: [String]?
    let unii: [String]?

    enum CodingKeys: String, CodingKey {
        case applicationNumber = "application_number"
        case brandName = "brand_name"
        case genericName = "generic_name"
        case manufacturerName = "manufacturer_name"
        case productNdc = "product_ndc"
        case productType = "product_type"
        case route
        case substanceName = "substance_name"
        case rxcui
        case splId = "spl_id"
        case splSetId = "spl_set_id"
        case packageNdc = "package_ndc"
        case isOriginalPackager = "is_original_packager"
        case upc
        case unii
    }
}

class FDApi {
    func fetchDrugData(name: String) async -> String {
        let urlString = "https://api.fda.gov/drug/label.json?search=openfda.generic_name:\"\(name)\""
        guard let url = URL(string: urlString) else {
            print("Error: Invalid URL")
            return "Error fetching data. Check the URL."
        }
        
        do {
            // 'await' pauses execution until the data task is complete.
            let (data, response) = try await URLSession.shared.data(from: url)

            // Check for a successful HTTP response
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Error: Invalid HTTP response.")
                return "Error fetching data. Check the URL."
            }
            
            // 3. Decode the JSON data
            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(APIResponse.self, from: data)

            // 4. Print the results to the console
            print("Successfully fetched \(apiResponse.results.count) drug labels.")
            for label in apiResponse.results {
                print("---")
                print("Brand Name: \(label.openfda.brandName.first ?? "N/A")")
                print("Generic Name: \(label.openfda.genericName.first ?? "N/A")")
                print("Manufacturer: \(label.openfda.manufacturerName.first ?? "N/A")")
                // Print the first 150 characters of the description, if available.
                print("Description: \((label.description?.first ?? "N/A").prefix(150))...")
            }
            
            return apiResponse.results[0].clinicalPharmacology?.first ?? apiResponse.results[0].indicationsAndUsage?.first ?? "No clinical pharmacology data available."

        } catch {
            // Handle potential errors from the network request or JSON decoding
            print("An error occurred: \(error.localizedDescription)")
            return "Error fetching data. Check the URL."
        }
    }
}

let fdaService = FDApi()
