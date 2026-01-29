//
//  Patient.swift
//  caregiverapp
//
//  ═══════════════════════════════════════════════════════════════════════════════
//  SWIFT BASICS: DATA MODELS WITH STRUCTS
//  ═══════════════════════════════════════════════════════════════════════════════
//
//  Models are simple data structures that hold your app's information.
//  In Swift, we typically use STRUCTS for models because:
//    1. They're value types (copied when passed around = safer)
//    2. They're simple and lightweight
//    3. They get useful features for free (memberwise initializer)
//

import Foundation  // Provides UUID, Date, and other basic types

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ PROTOCOL CONFORMANCE: Identifiable, Codable                                 │
// │                                                                             │
// │ After the colon, you list protocols this struct conforms to.               │
// │ Multiple protocols are separated by commas.                                │
// │                                                                             │
// │ IDENTIFIABLE:                                                               │
// │   - Requires an 'id' property                                              │
// │   - Lets SwiftUI uniquely identify items in lists/loops                    │
// │   - Without it, ForEach needs: ForEach(items, id: \.someProperty)          │
// │   - With it: ForEach(items) { item in ... } just works                     │
// │                                                                             │
// │ CODABLE:                                                                    │
// │   - Combines 'Encodable' + 'Decodable'                                     │
// │   - Lets you convert to/from JSON, Property Lists, etc.                    │
// │   - Essential for saving data or fetching from APIs                        │
// │   - Swift auto-generates the encoding/decoding code!                       │
// │                                                                             │
// │   Example - converting to JSON:                                             │
// │     let patient = Patient(name: "Mom", age: 78)                            │
// │     let jsonData = try JSONEncoder().encode(patient)                        │
// │     let jsonString = String(data: jsonData, encoding: .utf8)               │
// │     // {"id":"...", "name":"Mom", "age":78, ...}                            │
// └─────────────────────────────────────────────────────────────────────────────┘
struct Patient: Identifiable, Codable {

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ UUID - UNIVERSALLY UNIQUE IDENTIFIER                                    │
    // │                                                                         │
    // │ UUID generates a unique ID like: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"│
    // │ The chance of collision is astronomically small.                       │
    // │                                                                         │
    // │ 'let' means this can't change after the Patient is created.            │
    // │ This makes sense - a patient's ID should never change.                 │
    // └─────────────────────────────────────────────────────────────────────────┘
    let id: UUID

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ 'var' vs 'let' IN STRUCTS                                               │
    // │                                                                         │
    // │ - 'let' properties are IMMUTABLE (can't be changed)                    │
    // │ - 'var' properties are MUTABLE (can be changed)                        │
    // │                                                                         │
    // │ 'name' is 'var' because a patient's name could be corrected/updated.   │
    // │ Even though structs are value types, their var properties CAN be       │
    // │ modified if the struct variable itself is declared with 'var'.         │
    // │                                                                         │
    // │   var patient = Patient(name: "Mom", age: 78)                          │
    // │   patient.name = "Mother"  // OK - patient is 'var', name is 'var'     │
    // │                                                                         │
    // │   let patient = Patient(name: "Mom", age: 78)                          │
    // │   patient.name = "Mother"  // ERROR - patient is 'let'                 │
    // └─────────────────────────────────────────────────────────────────────────┘
    var name: String
    var age: Int

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ OPTIONALS: String?                                                      │
    // │                                                                         │
    // │ The '?' makes this an OPTIONAL - it can hold a String OR nil (nothing).│
    // │ This is one of Swift's most important safety features.                 │
    // │                                                                         │
    // │ Non-optional String: MUST have a value, can never be nil               │
    // │ Optional String?: CAN be nil, meaning "no value"                       │
    // │                                                                         │
    // │ photoURL is optional because not every patient has a photo.            │
    // │                                                                         │
    // │ To use an optional, you must "unwrap" it:                              │
    // │                                                                         │
    // │   // 1. Optional binding (safest, most common)                          │
    // │   if let url = patient.photoURL {                                       │
    // │       print("Photo at: \(url)")  // url is String here, not String?    │
    // │   } else {                                                              │
    // │       print("No photo")                                                 │
    // │   }                                                                      │
    // │                                                                         │
    // │   // 2. Nil coalescing (provide default)                                │
    // │   let url = patient.photoURL ?? "default.jpg"                          │
    // │                                                                         │
    // │   // 3. Force unwrap (DANGEROUS - crashes if nil)                       │
    // │   let url = patient.photoURL!  // Don't do this unless 100% sure       │
    // │                                                                         │
    // │   // 4. Optional chaining (returns nil if any step is nil)             │
    // │   let length = patient.photoURL?.count  // Returns Int? not Int        │
    // └─────────────────────────────────────────────────────────────────────────┘
    var photoURL: String?

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ ARRAYS: [String]                                                        │
    // │                                                                         │
    // │ [String] is shorthand for Array<String>                                 │
    // │ Arrays are ordered collections that can grow/shrink                    │
    // │                                                                         │
    // │ Common array operations:                                                │
    // │   conditions.append("Diabetes")     // Add to end                      │
    // │   conditions.insert("X", at: 0)     // Add at position                 │
    // │   conditions.remove(at: 0)          // Remove at position              │
    // │   conditions.count                  // Number of items                 │
    // │   conditions.isEmpty                // True if empty                   │
    // │   conditions[0]                     // First item (crashes if empty!)  │
    // │   conditions.first                  // First item (returns optional)   │
    // └─────────────────────────────────────────────────────────────────────────┘
    var conditions: [String]
    var emergencyContacts: [EmergencyContact]

    // ┌─────────────────────────────────────────────────────────────────────────┐
    // │ CUSTOM INITIALIZER                                                      │
    // │                                                                         │
    // │ Structs get a FREE "memberwise initializer" that takes all properties. │
    // │ But we define our own for two reasons:                                  │
    // │   1. Provide DEFAULT VALUES for some parameters                         │
    // │   2. Auto-generate UUID if not provided                                 │
    // │                                                                         │
    // │ PARAMETER SYNTAX: "external internal: Type = default"                   │
    // │   - external: Name used when calling (can be omitted with _)           │
    // │   - internal: Name used inside the function                            │
    // │   - = default: Optional default value                                   │
    // │                                                                         │
    // │   init(id: UUID = UUID(), ...)                                          │
    // │         ↑    ↑        ↑                                                 │
    // │      external internal default                                          │
    // │                                                                         │
    // │ Usage examples:                                                         │
    // │   Patient(name: "Mom", age: 78)                    // Minimal           │
    // │   Patient(id: myUUID, name: "Mom", age: 78)        // Custom ID         │
    // │   Patient(name: "Mom", age: 78, conditions: [...]) // With conditions   │
    // └─────────────────────────────────────────────────────────────────────────┘
    init(
        id: UUID = UUID(),           // Default: generate new UUID
        name: String,                 // Required: no default
        age: Int,                     // Required: no default
        photoURL: String? = nil,      // Default: no photo
        conditions: [String] = [],    // Default: empty array
        emergencyContacts: [EmergencyContact] = []
    ) {
        // ┌─────────────────────────────────────────────────────────────────────┐
        // │ 'self' KEYWORD                                                      │
        // │                                                                     │
        // │ 'self' refers to the current instance being created/modified.      │
        // │ It's required here because parameter names match property names.   │
        // │ self.name = the property, name = the parameter                     │
        // │                                                                     │
        // │ If names were different (e.g., parameter 'n' for property 'name'), │
        // │ you wouldn't need self: name = n                                   │
        // └─────────────────────────────────────────────────────────────────────┘
        self.id = id
        self.name = name
        self.age = age
        self.photoURL = photoURL
        self.conditions = conditions
        self.emergencyContacts = emergencyContacts
    }
}

// ┌─────────────────────────────────────────────────────────────────────────────┐
// │ RELATED TYPES IN SAME FILE                                                  │
// │                                                                             │
// │ EmergencyContact is closely related to Patient, so it lives here.          │
// │ This keeps related code together and makes imports simpler.                │
// └─────────────────────────────────────────────────────────────────────────────┘
struct EmergencyContact: Identifiable, Codable {
    let id: UUID
    var name: String
    var relationship: String
    var phoneNumber: String

    init(id: UUID = UUID(), name: String, relationship: String, phoneNumber: String) {
        self.id = id
        self.name = name
        self.relationship = relationship
        self.phoneNumber = phoneNumber
    }
}
