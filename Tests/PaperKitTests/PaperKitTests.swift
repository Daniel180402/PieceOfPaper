import Testing
@testable import PaperKit

@Test func versionIsSet() {
    #expect(!PaperKit.version.isEmpty)
}
