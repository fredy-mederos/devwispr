//
//  MultipartFormBuilder.swift
//  DevWispr
//

import Foundation

struct MultipartFormBuilder {
    private let boundary: String
    private var body = Data()

    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    init(boundary: String = "Boundary-\(UUID().uuidString)") {
        self.boundary = boundary
    }

    mutating func field(name: String, value: String) {
        var part = ""
        part += "--\(boundary)\r\n"
        part += "Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n"
        part += "\(value)\r\n"
        body.append(part.data(using: .utf8) ?? Data())
    }

    mutating func file(name: String, filename: String, mimeType: String, data: Data) {
        var header = ""
        header += "--\(boundary)\r\n"
        header += "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n"
        header += "Content-Type: \(mimeType)\r\n\r\n"

        body.append(header.data(using: .utf8) ?? Data())
        body.append(data)
        body.append("\r\n".data(using: .utf8) ?? Data())
    }

    func finalize() -> Data {
        var result = body
        result.append("--\(boundary)--\r\n".data(using: .utf8) ?? Data())
        return result
    }
}
