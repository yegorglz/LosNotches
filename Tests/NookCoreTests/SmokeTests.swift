import Testing
@testable import NookCore

@Test func versionIsSet() { #expect(NookCore.version == "0.1.0") }
