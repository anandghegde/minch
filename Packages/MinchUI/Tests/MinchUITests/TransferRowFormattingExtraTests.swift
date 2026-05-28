import Testing
@testable import MinchUI

import Foundation

@Suite("MinchTransferRow.etaText")
struct EtaTextTests {
    @Test func zeroSecondsIsOmitted() {
        #expect(MinchTransferRow.etaText(0) == nil)
    }

    @Test func negativeSecondsIsOmitted() {
        #expect(MinchTransferRow.etaText(-30) == nil)
    }

    @Test func subMinuteShowsLessThanOne() {
        #expect(MinchTransferRow.etaText(45) == "<1m left")
    }

    @Test func minutesFloor() {
        #expect(MinchTransferRow.etaText(195) == "3m left")
    }

    @Test func exactlyOneMinute() {
        #expect(MinchTransferRow.etaText(60) == "1m left")
    }

    @Test func hoursAndMinutes() {
        #expect(MinchTransferRow.etaText(4500) == "1h 15m left")
    }

    @Test func exactHourDropsMinuteSegment() {
        #expect(MinchTransferRow.etaText(7200) == "2h left")
    }
}


@Suite("MinchTransferRow.actionEnablement")
struct ActionEnablementTests {
    @Test func idlePhaseOnlyDeleteIsLive() {
        let a = MinchTransferRow.actionEnablement(phase: .idle, hasPlayableMedia: false)
        #expect(a == .init(play: false, reveal: false, copyLink: false, delete: true))
    }

    @Test func queuedPhaseHasCopyLinkAndDelete() {
        let a = MinchTransferRow.actionEnablement(phase: .queued, hasPlayableMedia: false)
        #expect(a == .init(play: false, reveal: false, copyLink: true, delete: true))
    }

    @Test func activePhaseHasCopyLinkAndDelete() {
        let a = MinchTransferRow.actionEnablement(phase: .active, hasPlayableMedia: false)
        #expect(a == .init(play: false, reveal: false, copyLink: true, delete: true))
    }

    @Test func pausedPhaseHasCopyLinkAndDelete() {
        let a = MinchTransferRow.actionEnablement(phase: .paused, hasPlayableMedia: false)
        #expect(a == .init(play: false, reveal: false, copyLink: true, delete: true))
    }

    @Test func errorPhaseHasCopyLinkAndDelete() {
        let a = MinchTransferRow.actionEnablement(phase: .error, hasPlayableMedia: false)
        #expect(a == .init(play: false, reveal: false, copyLink: true, delete: true))
    }

    @Test func donePhaseWithoutMediaDimsPlay() {
        let a = MinchTransferRow.actionEnablement(phase: .done, hasPlayableMedia: false)
        #expect(a == .init(play: false, reveal: true, copyLink: true, delete: true))
    }

    @Test func donePhaseWithMediaEnablesPlay() {
        let a = MinchTransferRow.actionEnablement(phase: .done, hasPlayableMedia: true)
        #expect(a == .init(play: true, reveal: true, copyLink: true, delete: true))
    }

    @Test func mediaFlagIsIgnoredOutsideDone() {
        let a = MinchTransferRow.actionEnablement(phase: .active, hasPlayableMedia: true)
        #expect(a.play == false)
    }
}


@Suite("MinchTransferRow.metaPlainText")
struct MetaPlainTextTests {
    @Test func idleShowsSizeOnly() {
        let s = MinchTransferRow.metaPlainText(
            phase: .idle, sizeBytes: 2_400_000_000, downloadSpeed: 0, progress: 0,
            etaSeconds: nil, queuePosition: nil, errorMessage: nil, addedAt: nil,
            now: Date(timeIntervalSince1970: 0)
        )
        #expect(s == "2.4 GB")
    }

    @Test func queuedWithPosition() {
        let s = MinchTransferRow.metaPlainText(
            phase: .queued, sizeBytes: 0, downloadSpeed: 0, progress: 0,
            etaSeconds: nil, queuePosition: 4, errorMessage: nil, addedAt: nil,
            now: Date(timeIntervalSince1970: 0)
        )
        #expect(s == "Queued · #4")
    }

    @Test func queuedWithoutPosition() {
        let s = MinchTransferRow.metaPlainText(
            phase: .queued, sizeBytes: 0, downloadSpeed: 0, progress: 0,
            etaSeconds: nil, queuePosition: nil, errorMessage: nil, addedAt: nil,
            now: Date(timeIntervalSince1970: 0)
        )
        #expect(s == "Queued")
    }

    @Test func queuedWithPositionAndProgress() {
        let s = MinchTransferRow.metaPlainText(
            phase: .queued, sizeBytes: 0, downloadSpeed: 0, progress: 0.8,
            etaSeconds: nil, queuePosition: 4, errorMessage: nil, addedAt: nil,
            now: Date(timeIntervalSince1970: 0)
        )
        #expect(s == "Queued · 80% · #4")
    }

    @Test func queuedWithProgressOnly() {
        let s = MinchTransferRow.metaPlainText(
            phase: .queued, sizeBytes: 0, downloadSpeed: 0, progress: 0.8,
            etaSeconds: nil, queuePosition: nil, errorMessage: nil, addedAt: nil,
            now: Date(timeIntervalSince1970: 0)
        )
        #expect(s == "Queued · 80%")
    }

    @Test func activeWithSpeedAndEta() {
        let s = MinchTransferRow.metaPlainText(
            phase: .active, sizeBytes: 2_400_000_000, downloadSpeed: 18_000_000, progress: 0.5,
            etaSeconds: 195, queuePosition: nil, errorMessage: nil, addedAt: nil,
            now: Date(timeIntervalSince1970: 0)
        )
        #expect(s.hasPrefix("2.4 GB · "))
        #expect(s.hasSuffix(" · 3m left"))
        #expect(s.contains("/s"))
    }

    @Test func activeOmitsZeroSpeedAndZeroEta() {
        let s = MinchTransferRow.metaPlainText(
            phase: .active, sizeBytes: 1_000_000, downloadSpeed: 0, progress: 0,
            etaSeconds: 0, queuePosition: nil, errorMessage: nil, addedAt: nil,
            now: Date(timeIntervalSince1970: 0)
        )
        #expect(s == "1 MB · 0%")
    }

    @Test func activeWithSeedsAndPeers() {
        let s = MinchTransferRow.metaPlainText(
            phase: .active, sizeBytes: 2_400_000_000, downloadSpeed: 18_000_000, progress: 0.5,
            etaSeconds: 195, queuePosition: nil, errorMessage: nil, addedAt: nil,
            seeds: 12, peers: 3,
            now: Date(timeIntervalSince1970: 0)
        )
        #expect(s.contains("12 seeders · 3 peers"))
    }

    @Test func activeWithSeedsOnly() {
        let s = MinchTransferRow.metaPlainText(
            phase: .active, sizeBytes: 2_400_000_000, downloadSpeed: 18_000_000, progress: 0.5,
            etaSeconds: 195, queuePosition: nil, errorMessage: nil, addedAt: nil,
            seeds: 12, peers: nil,
            now: Date(timeIntervalSince1970: 0)
        )
        #expect(s.contains("12 seeders"))
        #expect(!s.contains("peers"))
    }

    @Test func pausedShowsSizeAndPercent() {
        let s = MinchTransferRow.metaPlainText(
            phase: .paused, sizeBytes: 2_400_000_000, downloadSpeed: 0, progress: 0.42,
            etaSeconds: nil, queuePosition: nil, errorMessage: nil, addedAt: nil,
            now: Date(timeIntervalSince1970: 0)
        )
        #expect(s == "Paused · 2.4 GB · 42%")
    }

    @Test func errorShowsMessage() {
        let s = MinchTransferRow.metaPlainText(
            phase: .error, sizeBytes: 0, downloadSpeed: 0, progress: 0,
            etaSeconds: nil, queuePosition: nil, errorMessage: "Tracker unreachable", addedAt: nil,
            now: Date(timeIntervalSince1970: 0)
        )
        #expect(s == "Tracker unreachable")
    }

    @Test func errorFallsBackWhenMessageMissing() {
        let s = MinchTransferRow.metaPlainText(
            phase: .error, sizeBytes: 0, downloadSpeed: 0, progress: 0,
            etaSeconds: nil, queuePosition: nil, errorMessage: nil, addedAt: nil,
            now: Date(timeIntervalSince1970: 0)
        )
        #expect(s == "Error")
    }

    @Test func doneWithAddedAt() {
        let now = Date(timeIntervalSince1970: 10_000)
        let added = now.addingTimeInterval(-7_200) // 2h ago
        let s = MinchTransferRow.metaPlainText(
            phase: .done, sizeBytes: 18_300_000_000, downloadSpeed: 0, progress: 1.0,
            etaSeconds: nil, queuePosition: nil, errorMessage: nil, addedAt: added,
            now: now
        )
        #expect(s == "18.3 GB · added 2h ago")
    }

    @Test func doneWithoutAddedAt() {
        let s = MinchTransferRow.metaPlainText(
            phase: .done, sizeBytes: 18_300_000_000, downloadSpeed: 0, progress: 1.0,
            etaSeconds: nil, queuePosition: nil, errorMessage: nil, addedAt: nil,
            now: Date(timeIntervalSince1970: 0)
        )
        #expect(s == "18.3 GB")
    }
}

@Suite("MinchTransferRow.relativeAddedShort")
struct RelativeAddedShortTests {
    @Test func secondsBecomeJustNow() {
        let now = Date(timeIntervalSince1970: 10_000)
        let past = now.addingTimeInterval(-30)
        #expect(MinchTransferRow.relativeAddedShort(from: past, now: now) == "just now")
    }

    @Test func minutes() {
        let now = Date(timeIntervalSince1970: 10_000)
        let past = now.addingTimeInterval(-180)
        #expect(MinchTransferRow.relativeAddedShort(from: past, now: now) == "3m")
    }

    @Test func hours() {
        let now = Date(timeIntervalSince1970: 10_000)
        let past = now.addingTimeInterval(-3 * 3600)
        #expect(MinchTransferRow.relativeAddedShort(from: past, now: now) == "3h")
    }

    @Test func days() {
        let now = Date(timeIntervalSince1970: 86_400 * 10)
        let past = now.addingTimeInterval(-2 * 86_400)
        #expect(MinchTransferRow.relativeAddedShort(from: past, now: now) == "2d")
    }
}


@Suite("MinchTransferRow.dimmedSeparatorIndices")
struct DimmedSeparatorIndicesTests {
    @Test func emptyStringHasNoDims() {
        #expect(MinchTransferRow.dimmedSeparatorIndices("") == [])
    }

    @Test func noSeparatorsReturnsEmpty() {
        #expect(MinchTransferRow.dimmedSeparatorIndices("PlainName") == [])
    }

    @Test func dotsBetweenWordCharsAreDimmed() {
        #expect(MinchTransferRow.dimmedSeparatorIndices("a.b") == [1])
    }

    @Test func leadingSeparatorNotDimmed() {
        #expect(MinchTransferRow.dimmedSeparatorIndices(".foo") == [])
    }

    @Test func trailingSeparatorNotDimmed() {
        #expect(MinchTransferRow.dimmedSeparatorIndices("foo.") == [])
    }

    @Test func mixedSeparatorsAllDimmed() {
        let s = "The.Matrix_1999-2160p"
        let dims = MinchTransferRow.dimmedSeparatorIndices(s)
        #expect(dims == [3, 10, 15])
    }

    @Test func consecutiveSeparatorsOnlyDimWhenBothSidesAreWordChars() {
        #expect(MinchTransferRow.dimmedSeparatorIndices("a..b") == [])
    }
}

@Suite("MinchTransferRow.nameAttributedString")
struct NameAttributedStringTests {
    @Test func returnsAttributedStringMatchingInputCharacters() {
        let name = "a.b"
        let attr = MinchTransferRow.nameAttributedString(name)
        #expect(String(attr.characters) == name)
    }

    @Test func plainNameProducesAttributedString() {
        let name = "PlainName"
        let attr = MinchTransferRow.nameAttributedString(name)
        #expect(String(attr.characters) == name)
    }

    @Test func separatorBetweenWordCharsHasMutedForeground() {
        let attr = MinchTransferRow.nameAttributedString("a.b")
        var coloredRunCount = 0
        var aHasNoColor = false
        for run in attr.runs {
            let runText = String(attr[run.range].characters)
            if run.attributes.foregroundColor != nil {
                coloredRunCount += 1
            }
            if runText == "a" {
                aHasNoColor = (run.attributes.foregroundColor == nil)
            }
        }
        #expect(coloredRunCount >= 1)
        #expect(aHasNoColor)
    }
}


@Suite("MinchTransferRow.Content surface")
struct ContentSurfaceTests {
    @Test func existingInitStillCompilesWithDefaults() {
        let c = MinchTransferRow.Content(
            name: "Foo.mkv",
            phase: .active,
            sizeBytes: 100,
            downloadSpeed: 10,
            progress: 0.5
        )
        #expect(c.id == "")
        #expect(c.etaSeconds == nil)
        #expect(c.queuePosition == nil)
        #expect(c.errorMessage == nil)
        #expect(c.addedAt == nil)
        #expect(c.hasPlayableMedia == false)
        #expect(c.files.isEmpty)
    }

    @Test func newFieldsArePropagated() {
        let added = Date(timeIntervalSince1970: 1_000)
        let file = MinchTransferRow.Content.File(id: "f1", name: "a.mkv", sizeBytes: 42, isPlayable: true)
        let c = MinchTransferRow.Content(
            id: "t1",
            name: "Foo.mkv",
            phase: .done,
            sizeBytes: 100,
            downloadSpeed: 0,
            progress: 1.0,
            seeds: nil,
            peers: nil,
            etaSeconds: 0,
            queuePosition: nil,
            errorMessage: nil,
            addedAt: added,
            hasPlayableMedia: true,
            files: [file]
        )
        #expect(c.id == "t1")
        #expect(c.addedAt == added)
        #expect(c.hasPlayableMedia == true)
        #expect(c.files.count == 1)
        #expect(c.files[0].name == "a.mkv")
        #expect(c.files[0].isPlayable == true)
    }
}
