//
//  Language.swift
//  DevWispr
//

import Foundation

struct Language: Equatable, Hashable, Identifiable, Codable {
    let code: String
    let displayName: String

    var id: String { code }
}

extension Language {
    static let bulgarian   = Language(code: "bg", displayName: "Български")
    static let czech       = Language(code: "cs", displayName: "Česky")
    static let danish      = Language(code: "da", displayName: "Dansk")
    static let german      = Language(code: "de", displayName: "Deutsch")
    static let greek       = Language(code: "el", displayName: "Ελληνικά")
    static let estonian    = Language(code: "et", displayName: "Eesti")
    static let english     = Language(code: "en", displayName: "English")
    static let spanish     = Language(code: "es", displayName: "Español")
    static let french      = Language(code: "fr", displayName: "Français")
    static let croatian    = Language(code: "hr", displayName: "Hrvatski")
    static let italian     = Language(code: "it", displayName: "Italiano")
    static let lithuanian  = Language(code: "lt", displayName: "Lietuvių")
    static let latvian     = Language(code: "lv", displayName: "Latviešu")
    static let hungarian   = Language(code: "hu", displayName: "Magyar")
    static let dutch       = Language(code: "nl", displayName: "Nederlands")
    static let polish      = Language(code: "pl", displayName: "Polski")
    static let portuguese  = Language(code: "pt", displayName: "Portuguese")
    static let romanian    = Language(code: "ro", displayName: "Română")
    static let russian     = Language(code: "ru", displayName: "Русский")
    static let slovak      = Language(code: "sk", displayName: "Slovensko")
    static let serbian     = Language(code: "sr", displayName: "Srpski")
    static let swedish     = Language(code: "sv", displayName: "Svenska")
    static let finnish     = Language(code: "fi", displayName: "Suomi")
    static let ukrainian   = Language(code: "uk", displayName: "Українська")

    static let common: [Language] = [
        .english,
        .bulgarian,
        .czech,
        .danish,
        .german,
        .greek,
        .estonian,
        .spanish,
        .french,
        .croatian,
        .italian,
        .lithuanian,
        .latvian,
        .hungarian,
        .dutch,
        .polish,
        .portuguese,
        .romanian,
        .russian,
        .slovak,
        .serbian,
        .swedish,
        .finnish,
        .ukrainian,
    ]
}
