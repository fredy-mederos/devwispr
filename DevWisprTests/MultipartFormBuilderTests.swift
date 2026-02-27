//
//  MultipartFormBuilderTests.swift
//  DevWisprTests
//

import Foundation
import Testing
@testable import DevWispr

@Suite("MultipartFormBuilder Tests")
struct MultipartFormBuilderTests {
    @Test("Single field format correct")
    func singleField() {
        var builder = MultipartFormBuilder(boundary: "TestBoundary")
        builder.field(name: "key", value: "value")
        let data = builder.finalize()
        let str = String(data: data, encoding: .utf8)!

        #expect(str.contains("--TestBoundary\r\n"))
        #expect(str.contains("Content-Disposition: form-data; name=\"key\"\r\n\r\nvalue\r\n"))
        #expect(str.contains("--TestBoundary--\r\n"))
    }

    @Test("File part headers and content correct")
    func filePart() {
        var builder = MultipartFormBuilder(boundary: "TestBoundary")
        let fileData = "file content".data(using: .utf8)!
        builder.file(name: "upload", filename: "test.txt", mimeType: "text/plain", data: fileData)
        let data = builder.finalize()
        let str = String(data: data, encoding: .utf8)!

        #expect(str.contains("Content-Disposition: form-data; name=\"upload\"; filename=\"test.txt\""))
        #expect(str.contains("Content-Type: text/plain\r\n\r\n"))
        #expect(str.contains("file content"))
    }

    @Test("Finalize includes closing boundary")
    func closingBoundary() {
        let builder = MultipartFormBuilder(boundary: "TestBoundary")
        let data = builder.finalize()
        let str = String(data: data, encoding: .utf8)!
        #expect(str.contains("--TestBoundary--\r\n"))
    }

    @Test("Multiple fields concatenate correctly")
    func multipleFields() {
        var builder = MultipartFormBuilder(boundary: "TestBoundary")
        builder.field(name: "a", value: "1")
        builder.field(name: "b", value: "2")
        let data = builder.finalize()
        let str = String(data: data, encoding: .utf8)!

        #expect(str.contains("name=\"a\"\r\n\r\n1\r\n"))
        #expect(str.contains("name=\"b\"\r\n\r\n2\r\n"))
    }

    @Test("contentType includes boundary")
    func contentType() {
        let builder = MultipartFormBuilder(boundary: "TestBoundary")
        #expect(builder.contentType == "multipart/form-data; boundary=TestBoundary")
    }
}
