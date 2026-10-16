import Foundation
import Testing
@testable import Strata

/// **A block reaches Some Wins, and a non-starter can block and leave**
/// (the compliance audit, 2026-10-15, §3.1).
@Suite("Block reaches Some Wins")
struct BlockReachesUsTests {
    @Test("every block files a report, and leaves on request where you did not start the crew")
    func blockFilesAReport() throws {
        let safety = SourceSweep.code(try SourceSweep.read("Strata/Social/CrewSafety.swift"))
        let block = try #require(safety.components(separatedBy: "static func block(").dropFirst().first)
        #expect(block.contains("report(.blocked(member), in: crew, reason: .harassment)"))
        #expect(block.contains("try await store.leave(crew)"))
        #expect(safety.contains("\"Blocked: \""), "a block's report cannot be told from any other")
        for path in ["Strata/Views/Crews/CrewChatSheet.swift", "Strata/Views/Crews/CrewInfoSheet.swift"] {
            let view = SourceSweep.code(try SourceSweep.read(path))
            #expect(view.contains("Button(\"Block and Leave\", role: .destructive)"), "\(path) has no Block and Leave")
            #expect(view.contains("Some Wins hears about it. They are not told."), "\(path) does not say who is told")
        }
    }
}
