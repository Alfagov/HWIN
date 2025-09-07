//
//  UserModel.swift
//  GeriHealth
//
//  Created by Lorenzo P on 9/6/25.
//
import Foundation
import SwiftData

@Model
final class UserModel {
    var name: String
    var surname: String
    
    var dateOfBirth: Date
    var age: Int
    
    var location: String
        
    init(name: String, surname: String, dateOfBirth: Date, age: Int, location: String) {
        self.name = name
        self.surname = surname
        self.dateOfBirth = dateOfBirth
        self.age = age
        self.location = location
    }
}

@Model
final class Drug {
    var name: String
    var dose: String
    
    var admnistered: [String: [String]]
    
    init(name: String, dose: String, admnisteredOn: [String : [String]]) {
        self.name = name
        self.dose = dose
        self.admnistered = admnisteredOn
    }
}

extension Drug {
    static let sampleData: [Drug] = [
        Drug(name: "Ibuprofen", dose: "20mg", admnisteredOn: ["Monday": ["8:00 AM", "8:00 PM"], "Wensday": ["8:00 AM", "7:00 PM"], "Thursday": ["8:00 AM", "7:00 PM"]]),
        Drug(name: "Prozac", dose: "20mg", admnisteredOn: ["Monday": ["12:00 AM", "6:00 PM"]])
    ]
}
