import Foundation

@MainActor
enum SelfTestRunner {
    struct AssertionResult {
        let name: String
        let passed: Bool
        let detail: String
    }

    static func populateSandbox(at sandboxPath: String) {
        let fm = FileManager.default
        let sandboxURL = URL(fileURLWithPath: sandboxPath).standardizedFileURL
        setenv("BATHYS_SANDBOX_ROOT", sandboxURL.path, 1)
        try? fm.removeItem(at: sandboxURL)
        try? fm.createDirectory(at: sandboxURL, withIntermediateDirectories: true)

        func writeSynthetic(_ rel: String, mb: Int, modDate: Date? = nil) {
            let u = sandboxURL.appendingPathComponent(rel)
            try? fm.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = Data(repeating: 0x5A, count: mb * 1024 * 1024)
            try? data.write(to: u)
            if let modDate {
                try? fm.setAttributes([.modificationDate: modDate], ofItemAtPath: u.path)
            }
        }

        let oldDate = Date.now.addingTimeInterval(-7200)
        writeSynthetic("Library/Caches/com.bathystest.chrome/CacheData_01.bin", mb: 48)
        writeSynthetic("Library/Caches/com.bathystest.spotify/AudioStreamCache.dat", mb: 32)
        writeSynthetic("var/folders/T/FinalCut_Render_Temp_Orphan.mov", mb: 64, modDate: oldDate)
        writeSynthetic("var/folders/C/com.bathystest.metal/ShaderCache.bin", mb: 24)
        writeSynthetic(".npm/_cacache/content-v2/node_modules_bundle.tar", mb: 55)
        writeSynthetic("Library/Developer/Xcode/DerivedData/BathysTestProject-xyz/BuildIntermediates.o", mb: 70)
        writeSynthetic("Library/Logs/DiagnosticReports/SyntheticCrashReport_2026.ips", mb: 12)
        writeSynthetic(".Trash/Old_Project_Archive.zip", mb: 35)
        // Protected file that must remain untouched
        writeSynthetic("var/folders/T/ActiveSession_Live.tmp", mb: 4, modDate: Date.now)
    }

    static func runAll(sandboxPath: String) async -> Int32 {
        let fm = FileManager.default
        let sandboxURL = URL(fileURLWithPath: sandboxPath).standardizedFileURL
        setenv("BATHYS_SANDBOX_ROOT", sandboxURL.path, 1)

        print("================================================================================")
        print("🧪 BATHYS END-TO-END SELF-TEST SUITE")
        print("📂 Sandbox: \(sandboxURL.path)")
        print("================================================================================")

        // Reset sandbox
        try? fm.removeItem(at: sandboxURL)
        try? fm.createDirectory(at: sandboxURL, withIntermediateDirectories: true)

        var results: [AssertionResult] = []
        func check(_ name: String, _ condition: Bool, _ detail: String) {
            results.append(AssertionResult(name: name, passed: condition, detail: detail))
            let icon = condition ? "✅ PASS" : "❌ FAIL"
            print("\(icon) | \(name): \(detail)")
        }

        // Helper to write synthetic files
        func writeSyntheticFile(_ relativePath: String, sizeBytes: Int, modDate: Date? = nil) -> URL {
            let fileURL = sandboxURL.appendingPathComponent(relativePath)
            try? fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = Data(repeating: 0x42, count: sizeBytes)
            try? data.write(to: fileURL)
            if let modDate {
                try? fm.setAttributes([.modificationDate: modDate], ofItemAtPath: fileURL.path)
            }
            return fileURL
        }

        // -------------------------------------------------------------------------
        // PHASE 1: POPULATE SYNTHETIC SANDBOX FILES
        // -------------------------------------------------------------------------
        let twoHoursAgo = Date.now.addingTimeInterval(-7200)
        let fortyFiveDaysAgo = Date.now.addingTimeInterval(-45 * 24 * 3600)
        let twoDaysAgo = Date.now.addingTimeInterval(-2 * 24 * 3600)

        // 1A. Cleanable Deep Clean files
        let browserCacheFile = writeSyntheticFile("Library/Caches/com.bathystest.browser/cache_chunk.bin", sizeBytes: 4 * 1024 * 1024)
        let darwinOldTempFile = writeSyntheticFile("var/folders/T/orphan_video_export.mov", sizeBytes: 3 * 1024 * 1024, modDate: twoHoursAgo)
        let darwinCacheFile = writeSyntheticFile("var/folders/C/com.bathystest.shader/compiled.metal", sizeBytes: 2 * 1024 * 1024)
        let npmCacheFile = writeSyntheticFile(".npm/_cacache/content-v2/tarball.tgz", sizeBytes: 5 * 1024 * 1024)
        let xcodeDerivedFile = writeSyntheticFile("Library/Developer/Xcode/DerivedData/TestApp-abc/Intermediates.o", sizeBytes: 6 * 1024 * 1024)
        let crashLogFile = writeSyntheticFile("Library/Logs/DiagnosticReports/Crash_2026.ips", sizeBytes: 1 * 1024 * 1024)
        let savedStateFile = writeSyntheticFile("Library/Saved Application State/com.bathystest.legacy.savedState/windows.plist", sizeBytes: 512 * 1024, modDate: fortyFiveDaysAgo)
        if let savedStateDir = URL(string: savedStateFile.deletingLastPathComponent().AbsoluteStringSafe) {
            try? fm.setAttributes([.modificationDate: fortyFiveDaysAgo], ofItemAtPath: savedStateDir.path)
        }
        let trashFile = writeSyntheticFile(".Trash/old_archive.zip", sizeBytes: 2 * 1024 * 1024)

        // 1B. Protected / Active files that MUST NOT be deleted
        let activeTempFile = writeSyntheticFile("var/folders/T/active_recording.tmp", sizeBytes: 1 * 1024 * 1024, modDate: Date.now)
        let lockTempFile = writeSyntheticFile("var/folders/T/database.sqlite-wal", sizeBytes: 512 * 1024, modDate: twoHoursAgo)
        let darwinZeroProtectedFile = writeSyntheticFile("var/folders/0/kernel_sandbox_state.bin", sizeBytes: 1 * 1024 * 1024, modDate: twoHoursAgo)
        let cloudKitProtectedFile = writeSyntheticFile("Library/Caches/CloudKit/cloud_sync.db", sizeBytes: 1 * 1024 * 1024)

        // 1C. Recursive Symlink Loop inside Library/Caches
        let symlinkLoopURL = sandboxURL.appendingPathComponent("Library/Caches/com.bathystest.symlink_loop")
        try? fm.createSymbolicLink(at: symlinkLoopURL, withDestinationURL: sandboxURL.appendingPathComponent("Library/Caches"))

        // -------------------------------------------------------------------------
        // PHASE 2: TEST DEEP CLEAN SCANNER (PRE-DESELECTION + FULL SCAN + CLEAN)
        // -------------------------------------------------------------------------
        let scanner = Scanner()

        // Test Bug 1 fix: Deselect "trash" before scanning and verify it is skipped
        if let trashIdx = scanner.categories.firstIndex(where: { $0.id == "trash" }) {
            scanner.categories[trashIdx].isSelected = false
        }
        scanner.scan()
        while scanner.isScanning {
            try? await Task.sleep(for: .milliseconds(50))
        }

        let skippedTrashBytes = scanner.categories.first(where: { $0.id == "trash" })?.bytes ?? -1
        check(
            "DeepClean Pre-Scan Category Deselection",
            skippedTrashBytes == 0,
            "Unchecked 'trash' category had \(skippedTrashBytes) bytes scanned (expected 0)"
        )

        // Re-enable all categories and run full scan
        for i in scanner.categories.indices {
            scanner.categories[i].isSelected = true
        }
        scanner.scan()
        while scanner.isScanning {
            try? await Task.sleep(for: .milliseconds(50))
        }

        let totalDetected = scanner.totalBytes
        check(
            "DeepClean Full Scan Detection & Symlink Safety",
            totalDetected >= 20 * 1024 * 1024,
            "Detected \(ByteCountFormatter.string(fromByteCount: totalDetected, countStyle: .file)) without hanging on symlink loop"
        )

        // Verify safety exclusions were NOT queued into category topItems
        let allQueuedPaths = scanner.categories.flatMap { $0.topItems.flatMap { $0.targetPaths } }
        let hasActiveTemp = allQueuedPaths.contains(activeTempFile.path)
        let hasLockTemp = allQueuedPaths.contains(lockTempFile.path)
        let hasDarwinZero = allQueuedPaths.contains { $0.contains("/var/folders/0") }
        let hasCloudKit = allQueuedPaths.contains { $0.contains("CloudKit") }

        check(
            "MacSafetyIntelligence Exclusion (Active <15m Temp File)",
            !hasActiveTemp,
            "active_recording.tmp queued=\(hasActiveTemp) (expected false)"
        )
        check(
            "MacSafetyIntelligence Exclusion (SQLite WAL/Lock File)",
            !hasLockTemp,
            "database.sqlite-wal queued=\(hasLockTemp) (expected false)"
        )
        check(
            "MacSafetyIntelligence Exclusion (Darwin /var/folders/0 & CloudKit)",
            !hasDarwinZero && !hasCloudKit,
            "Darwin 0 queued=\(hasDarwinZero), CloudKit queued=\(hasCloudKit)"
        )

        // Execute Deep Clean deletion
        scanner.cleanSelectedItems()
        while scanner.isCleaning || scanner.isResurfacing {
            try? await Task.sleep(for: .milliseconds(50))
        }

        // Verify target junk files were deleted while protected files and structural parent folders survive
        let junkDeleted = !fm.fileExists(atPath: browserCacheFile.path)
            && !fm.fileExists(atPath: darwinOldTempFile.path)
            && !fm.fileExists(atPath: darwinCacheFile.path)
            && !fm.fileExists(atPath: npmCacheFile.path)
            && !fm.fileExists(atPath: xcodeDerivedFile.path)
            && !fm.fileExists(atPath: crashLogFile.path)
            && !fm.fileExists(atPath: trashFile.path)

        let protectedSurvived = fm.fileExists(atPath: activeTempFile.path)
            && fm.fileExists(atPath: lockTempFile.path)
            && fm.fileExists(atPath: darwinZeroProtectedFile.path)
            && fm.fileExists(atPath: cloudKitProtectedFile.path)
            && fm.fileExists(atPath: sandboxURL.appendingPathComponent("Library/Caches").path)
            && fm.fileExists(atPath: sandboxURL.appendingPathComponent("var/folders/T").path)
            && fm.fileExists(atPath: sandboxURL.appendingPathComponent("var/folders/C").path)

        check(
            "DeepClean File Deletion Execution",
            junkDeleted && scanner.lastCleanedBytes > 0,
            "All 7 synthetic junk categories deleted, freed \(ByteCountFormatter.string(fromByteCount: scanner.lastCleanedBytes, countStyle: .file))"
        )
        check(
            "DeepClean Safety Preservation After Clean",
            protectedSurvived,
            "Protected files (active temp, lock, Darwin 0, CloudKit) and parent containers C/T/Caches intact=\(protectedSurvived)"
        )

        // -------------------------------------------------------------------------
        // PHASE 3: TEST UNINSTALLER ENGINE (BUNDLE + RESIDUALS + RACE CONDITION)
        // -------------------------------------------------------------------------
        let appBundleURL = sandboxURL.appendingPathComponent("Applications/BathysDummyApp.app")
        let appInfoPlistURL = appBundleURL.appendingPathComponent("Contents/Info.plist")
        try? fm.createDirectory(at: appInfoPlistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let infoDict: [String: Any] = [
            "CFBundleIdentifier": "com.bathys.dummyapp",
            "CFBundleDisplayName": "BathysDummyApp",
            "CFBundleName": "BathysDummyApp",
            "CFBundleShortVersionString": "2.4.0"
        ]
        (infoDict as NSDictionary).write(to: appInfoPlistURL, atomically: true)
        _ = writeSyntheticFile("Applications/BathysDummyApp.app/Contents/MacOS/BathysDummyApp", sizeBytes: 3 * 1024 * 1024)

        // Create app residuals across Library
        let resSupport = writeSyntheticFile("Library/Application Support/BathysDummyApp/userdata.db", sizeBytes: 1 * 1024 * 1024)
        let resCache = writeSyntheticFile("Library/Caches/com.bathys.dummyapp/http_cache.db", sizeBytes: 512 * 1024)
        let resPrefs = writeSyntheticFile("Library/Preferences/com.bathys.dummyapp.plist", sizeBytes: 64 * 1024)
        let resState = writeSyntheticFile("Library/Saved Application State/com.bathys.dummyapp.savedState/state.bin", sizeBytes: 128 * 1024)

        let uninstaller = UninstallerEngine()
        uninstaller.loadInstalledApps()
        while uninstaller.isLoadingApps || uninstaller.isScanningResiduals {
            try? await Task.sleep(for: .milliseconds(50))
        }

        let foundDummyApp = uninstaller.apps.first(where: { $0.bundleId == "com.bathys.dummyapp" })
        check(
            "Uninstaller App Discovery & Residual Correlation",
            foundDummyApp != nil && uninstaller.residuals.count == 5,
            "Found app=\(foundDummyApp?.name ?? "nil") with \(uninstaller.residuals.count) correlated items (1 bundle + 4 Library residuals)"
        )

        // Test 1: Reset-Only Mode (preserves .app bundle, deletes only Library residuals)
        uninstaller.setUninstallScope(resetOnly: true)
        uninstaller.uninstallSelectedItems()
        let appBundleSurvivedReset = fm.fileExists(atPath: appBundleURL.path)
        let libraryResidualsClearedOnReset = !fm.fileExists(atPath: resSupport.deletingLastPathComponent().path)
            && !fm.fileExists(atPath: resCache.deletingLastPathComponent().path)
            && !fm.fileExists(atPath: resPrefs.path)
            && !fm.fileExists(atPath: resState.deletingLastPathComponent().path)

        check(
            "Uninstaller Safe Reset-Only Mode (Preserves .app Bundle)",
            appBundleSurvivedReset && libraryResidualsClearedOnReset,
            "appBundleSurvived=\(appBundleSurvivedReset), libraryResidualsCleared=\(libraryResidualsClearedOnReset)"
        )

        // Recreate 1 Library residual and test Complete Uninstall Mode
        let resCache2 = writeSyntheticFile("Library/Caches/com.bathys.dummyapp/shader.cache", sizeBytes: 512 * 1024)
        uninstaller.loadInstalledApps()
        while uninstaller.isLoadingApps || uninstaller.isScanningResiduals {
            try? await Task.sleep(for: .milliseconds(50))
        }
        uninstaller.setUninstallScope(resetOnly: false)
        uninstaller.uninstallSelectedItems()
        let allAppResidualsRemoved = !fm.fileExists(atPath: appBundleURL.path)
            && !fm.fileExists(atPath: resCache2.deletingLastPathComponent().path)

        check(
            "Uninstaller Complete Removal",
            allAppResidualsRemoved && uninstaller.lastFreedBytes >= 3 * 1024 * 1024,
            "App bundle + Library residuals deleted, freed \(ByteCountFormatter.string(fromByteCount: uninstaller.lastFreedBytes, countStyle: .file))"
        )

        // -------------------------------------------------------------------------
        // PHASE 4: TEST SONAR ENGINE (SUNBURST TREE + CONTAINER SAFETY RULES)
        // -------------------------------------------------------------------------
        let sonarTargetDir = writeSyntheticFile("Downloads/HugeVideoProject/raw_footage_4k.mov", sizeBytes: 8 * 1024 * 1024).deletingLastPathComponent()
        let sonarCacheInner = writeSyntheticFile("Library/Caches/SonarTempCache/blob.dat", sizeBytes: 3 * 1024 * 1024)

        let sonar = SonarEngine()
        sonar.refreshVolumes()
        sonar.scan(url: sandboxURL)
        while sonar.isScanning {
            try? await Task.sleep(for: .milliseconds(50))
        }

        let rootBytes = sonar.rootNode?.bytes ?? 0
        check(
            "Sonar Hierarchical Tree & Sunburst Generation",
            rootBytes >= 11 * 1024 * 1024 && !sonar.sunburstSegments.isEmpty,
            "Root tree bytes=\(ByteCountFormatter.string(fromByteCount: rootBytes, countStyle: .file)), sunburstSegments=\(sonar.sunburstSegments.count)"
        )

        // Verify DiskNode safety rules
        let zeroNode = DiskNode(name: "0", path: sandboxURL.appendingPathComponent("var/folders/0").path, bytes: 1024, isDirectory: true, colorIndex: 0, children: [])
        let cachesNode = DiskNode(name: "Caches", path: sandboxURL.appendingPathComponent("Library/Caches").path, bytes: 3 * 1024 * 1024, isDirectory: true, colorIndex: 1, children: [])
        let normalNode = DiskNode(name: "HugeVideoProject", path: sonarTargetDir.path, bytes: 8 * 1024 * 1024, isDirectory: true, colorIndex: 2, children: [])

        check(
            "Sonar NodeSafetyRule Classification",
            zeroNode.safetyRule == .systemProtected && cachesNode.safetyRule == .emptyContentsOnly && normalNode.safetyRule == .normal,
            "0=\(zeroNode.safetyRule), Caches=\(cachesNode.safetyRule), HugeVideoProject=\(normalNode.safetyRule)"
        )

        // Attempt to trash systemProtected node (must be blocked!)
        sonar.moveNodeToTrash(zeroNode)
        let zeroSurvived = fm.fileExists(atPath: darwinZeroProtectedFile.path)

        // Trash emptyContentsOnly node (must empty SonarTempCache inside Library/Caches, preserve Library/Caches and CloudKit!)
        sonar.moveNodeToTrash(cachesNode)
        let cachesContainerSurvived = fm.fileExists(atPath: sandboxURL.appendingPathComponent("Library/Caches").path)
        let cloudKitStillSurvived = fm.fileExists(atPath: cloudKitProtectedFile.path)
        let sonarCacheInnerRemoved = !fm.fileExists(atPath: sonarCacheInner.path)

        // Trash normal user folder node (must remove HugeVideoProject)
        sonar.moveNodeToTrash(normalNode)
        let normalFolderRemoved = !fm.fileExists(atPath: sonarTargetDir.path)

        check(
            "Sonar Safe Deletion & Container Preservation",
            zeroSurvived && cachesContainerSurvived && cloudKitStillSurvived && sonarCacheInnerRemoved && normalFolderRemoved,
            "zeroSurvived=\(zeroSurvived), cachesContainerSurvived=\(cachesContainerSurvived), cloudKitSurvived=\(cloudKitStillSurvived), innerRemoved=\(sonarCacheInnerRemoved), normalRemoved=\(normalFolderRemoved)"
        )

        // -------------------------------------------------------------------------
        // PHASE 5: TEST OPTIMIZER ENGINE (.DS_STORE, BROKEN PLIST, SAVED STATE, LAUNCH AGENTS)
        // -------------------------------------------------------------------------
        let dsStore1 = writeSyntheticFile("Downloads/.DS_Store", sizeBytes: 4096)
        let dsStore2 = writeSyntheticFile("Documents/.DS_Store", sizeBytes: 4096)
        let zeroPlist = writeSyntheticFile("Library/Preferences/com.bathystest.zero.plist", sizeBytes: 0)
        let malformedPlist = sandboxURL.appendingPathComponent("Library/Preferences/com.bathystest.malformed.plist")
        try? Data("<<<CORRUPTED_NOT_XML_PLIST>>>".utf8).write(to: malformedPlist)

        let validPlist = sandboxURL.appendingPathComponent("Library/Preferences/com.bathystest.valid.plist")
        (["Theme": "AbyssalDark", "Version": 2] as NSDictionary).write(to: validPlist, atomically: true)

        // Saved states: one 45 days old, one 2 days old
        let staleStateDir = sandboxURL.appendingPathComponent("Library/Saved Application State/com.bathystest.stale45d.savedState")
        try? fm.createDirectory(at: staleStateDir, withIntermediateDirectories: true)
        try? fm.setAttributes([.modificationDate: fortyFiveDaysAgo], ofItemAtPath: staleStateDir.path)

        let recentStateDir = sandboxURL.appendingPathComponent("Library/Saved Application State/com.bathystest.recent2d.savedState")
        try? fm.createDirectory(at: recentStateDir, withIntermediateDirectories: true)
        try? fm.setAttributes([.modificationDate: twoDaysAgo], ofItemAtPath: recentStateDir.path)

        // LaunchAgents: one orphaned (/nonexistent/binary), one valid (/bin/sh)
        let orphanAgentURL = sandboxURL.appendingPathComponent("Library/LaunchAgents/com.bathystest.orphan.plist")
        try? fm.createDirectory(at: orphanAgentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        ([
            "Label": "com.bathystest.orphan",
            "Program": "/nonexistent/bathys_missing_daemon",
            "RunAtLoad": true
        ] as NSDictionary).write(to: orphanAgentURL, atomically: true)

        let validAgentURL = sandboxURL.appendingPathComponent("Library/LaunchAgents/com.bathystest.valid.plist")
        ([
            "Label": "com.bathystest.valid",
            "Program": "/bin/sh",
            "RunAtLoad": false
        ] as NSDictionary).write(to: validAgentURL, atomically: true)

        let optimizer = OptimizerEngine()
        optimizer.scanLaunchAgents()
        while optimizer.isScanningAgents {
            try? await Task.sleep(for: .milliseconds(50))
        }

        let orphanAgent = optimizer.launchAgents.first(where: { $0.label == "com.bathystest.orphan" })
        let validAgent = optimizer.launchAgents.first(where: { $0.label == "com.bathystest.valid" })

        check(
            "Optimizer LaunchAgent Orphan Detection",
            orphanAgent?.isOrphaned == true && validAgent?.isOrphaned == false,
            "Orphan flagged=\(orphanAgent?.isOrphaned ?? false), Valid flagged=\(validAgent?.isOrphaned ?? true)"
        )

        if let orphanAgent {
            optimizer.removeLaunchAgent(orphanAgent)
        }
        check(
            "Optimizer Orphan LaunchAgent Removal",
            !fm.fileExists(atPath: orphanAgentURL.path) && fm.fileExists(atPath: validAgentURL.path),
            "Orphan plist removed, valid plist preserved"
        )

        optimizer.runSelectedOptimizations()
        while optimizer.isRunningTasks {
            try? await Task.sleep(for: .milliseconds(50))
        }

        let dsStoresRemoved = !fm.fileExists(atPath: dsStore1.path) && !fm.fileExists(atPath: dsStore2.path)
        let brokenPlistsRemoved = !fm.fileExists(atPath: zeroPlist.path) && !fm.fileExists(atPath: malformedPlist.path)
        let validPlistSurvived = fm.fileExists(atPath: validPlist.path)
        let staleStateRemoved = !fm.fileExists(atPath: staleStateDir.path)
        let recentStateSurvived = fm.fileExists(atPath: recentStateDir.path)

        check(
            "Optimizer Maintenance Tasks (.DS_Store, Corrupted Plists, Stale Window States)",
            dsStoresRemoved && brokenPlistsRemoved && validPlistSurvived && staleStateRemoved && recentStateSurvived,
            "dsStoresRemoved=\(dsStoresRemoved), brokenPlistsRemoved=\(brokenPlistsRemoved), validPlistSurvived=\(validPlistSurvived), staleStateRemoved=\(staleStateRemoved), recentStateSurvived=\(recentStateSurvived)"
        )

        // Clean up sandbox after verification unless --keep-sandbox is passed
        if !CommandLine.arguments.contains("--keep-sandbox") {
            try? fm.removeItem(at: sandboxURL)
        }

        let passedCount = results.filter(\.passed).count
        let totalCount = results.count
        print("================================================================================")
        print("🏁 SELF-TEST SUMMARY: \(passedCount)/\(totalCount) CHECKS PASSED")
        print("================================================================================")

        return passedCount == totalCount ? 0 : 1
    }
}

private extension URL {
    var AbsoluteStringSafe: String {
        self.absoluteString
    }
}
