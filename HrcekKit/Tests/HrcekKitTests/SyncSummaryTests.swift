import Testing

@testable import HrcekKit

@Suite struct SyncSummaryTests {
    @Test(arguments: [
        (SyncResult(saved: 1), "1 entry saved."),
        (SyncResult(saved: 3), "3 entries saved."),
        (
            SyncResult(saved: 1, held: 2),
            "1 entry saved. 2 already on Hrček; choose which to keep."
        ),
        (SyncResult(refused: 1), "Hrček refused 1 entry."),
        (
            SyncResult(saved: 1, withoutPicture: ["Cats"]),
            "1 entry saved. Saved without its picture: Cats"
        ),
        (SyncResult(stopped: .unavailable), "Hrček can't be reached."),
        (
            SyncResult(saved: 2, stopped: .unavailable),
            "2 entries saved. Hrček can't be reached."
        ),
        (SyncResult(stopped: .unauthorized), "Hrček no longer accepts this phone's sign-in."),
        (SyncResult(stopped: .failed), "Hrček couldn't be asked. Try again later."),
        (SyncResult(stopped: .interrupted), "Not finished. The rest will be sent later."),
    ])
    func saysWhatHappened(result: SyncResult, expected: String) {
        #expect(result.summary == expected)
    }

    @Test func saysNothingWhenAnotherSyncWasRunning() {
        #expect(SyncResult(stopped: .busy).summary == nil)
        #expect(SyncResult().summary == nil)
    }

    @Test func speaksSlovenian() {
        #expect(
            SyncResult(saved: 3).summary(language: "sl") == "Shranjeni so 3 vnosi.")
    }
}
