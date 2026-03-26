import Foundation
import AppKit

struct ActionResult {
    let success: Bool
    let output: String?
}

enum ActionExecutor {

    // MARK: - 웹사이트 열기

    static func openURL(_ urlString: String) {
        var clean = urlString.trimmingCharacters(in: .whitespaces)
        if !clean.hasPrefix("http://") && !clean.hasPrefix("https://") {
            clean = "https://" + clean
        }
        guard let url = URL(string: clean) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - 앱 실행

    static func openApp(_ name: String) {
        let clean = name.trimmingCharacters(in: .whitespaces)
        let paths = [
            "/Applications/\(clean).app",
            "/System/Applications/\(clean).app",
            "/Applications/Utilities/\(clean).app",
            "/System/Applications/Utilities/\(clean).app"
        ]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                NSWorkspace.shared.open(URL(fileURLWithPath: path))
                return
            }
        }
        // 폴백: open -a 명령
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", "open -a \"\(clean)\""]
        try? process.run()
    }

    // MARK: - Finder 열기

    static func openFinder(_ path: String) {
        let expanded = NSString(string: path.trimmingCharacters(in: .whitespaces)).expandingTildeInPath
        NSWorkspace.shared.open(URL(fileURLWithPath: expanded))
    }

    // MARK: - AppleScript 실행

    @discardableResult
    static func runAppleScript(_ source: String) -> ActionResult {
        guard let script = NSAppleScript(source: source) else {
            return ActionResult(success: false, output: "스크립트 생성 실패")
        }
        var errorDict: NSDictionary?
        let result = script.executeAndReturnError(&errorDict)
        if let error = errorDict {
            let msg = (error["NSAppleScriptErrorMessage"] as? String) ?? "AppleScript 오류"
            return ActionResult(success: false, output: msg)
        }
        return ActionResult(success: true, output: result.stringValue)
    }

    // MARK: - 쉘 명령 실행

    static func runShell(_ command: String) async -> ActionResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-c", command]
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    continuation.resume(returning: ActionResult(
                        success: process.terminationStatus == 0,
                        output: output.isEmpty ? nil : output
                    ))
                } catch {
                    continuation.resume(returning: ActionResult(
                        success: false,
                        output: error.localizedDescription
                    ))
                }
            }
        }
    }

    // MARK: - 파일 검색

    static func searchFiles(_ query: String) async -> ActionResult {
        let sanitized = query.replacingOccurrences(of: "'", with: "'\\''")
        return await runShell("mdfind -limit 10 '\(sanitized)'")
    }

    // MARK: - 웹 검색

    static func webSearch(_ query: String) async -> ActionResult {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let result = await runShell("""
            curl -s "https://html.duckduckgo.com/html/?q=\(encoded)" | \
            grep -oP '(?<=class="result__a"[^>]*>)[^<]+' | head -5 | \
            cat -n 2>/dev/null || \
            curl -s "https://api.duckduckgo.com/?q=\(encoded)&format=json&no_html=1" | \
            python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('AbstractText','') or d.get('Answer','') or '검색 결과 없음')" 2>/dev/null
            """)
        return result
    }

    // MARK: - 기억하기

    private static let memoryKey = "petMemories"

    static func saveMemory(_ value: String) {
        var memories = loadMemories()
        memories.append(value)
        if memories.count > 50 { memories = Array(memories.suffix(50)) }
        UserDefaults.standard.set(memories, forKey: memoryKey)
    }

    static func loadMemories() -> [String] {
        UserDefaults.standard.stringArray(forKey: memoryKey) ?? []
    }

    static func recallMemory(_ keyword: String) -> String? {
        let memories = loadMemories()
        let matches = memories.filter { $0.localizedCaseInsensitiveContains(keyword) }
        return matches.isEmpty ? nil : matches.joined(separator: "\n")
    }

    static func deleteMemory(_ keyword: String) -> Bool {
        var memories = loadMemories()
        let before = memories.count
        memories.removeAll { $0.localizedCaseInsensitiveContains(keyword) }
        UserDefaults.standard.set(memories, forKey: memoryKey)
        return memories.count < before
    }

    // MARK: - 리마인더

    static func addReminder(timeStr: String, message: String, petManager: PetManager?) {
        let now = Date()
        var targetDate: Date?

        // "5m", "10m", "1h" 같은 상대 시간
        if timeStr.hasSuffix("m"), let mins = Int(timeStr.dropLast()) {
            targetDate = now.addingTimeInterval(Double(mins) * 60)
        } else if timeStr.hasSuffix("h"), let hrs = Int(timeStr.dropLast()) {
            targetDate = now.addingTimeInterval(Double(hrs) * 3600)
        }
        // "15:00", "3:30" 같은 시간
        else if timeStr.contains(":") {
            let parts = timeStr.split(separator: ":")
            if parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) {
                let cal = Calendar.current
                var comps = cal.dateComponents([.year, .month, .day], from: now)
                comps.hour = h; comps.minute = m; comps.second = 0
                if let d = cal.date(from: comps) {
                    targetDate = d < now ? cal.date(byAdding: .day, value: 1, to: d) : d
                }
            }
        }

        guard let target = targetDate else { return }

        let id = UUID().uuidString
        let f = ISO8601DateFormatter()
        let reminder = ["id": id, "message": message, "time": f.string(from: target)]

        // 로컬 저장
        petManager?.reminders.append(reminder)

        // Firebase 저장
        guard let url = URL(string: "https://desktoppet-ba9ae-default-rtdb.firebaseio.com/reminders/\(id).json"),
              let body = try? JSONSerialization.data(withJSONObject: reminder) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.httpBody = body
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        URLSession.shared.dataTask(with: req).resume()
    }

    // MARK: - 태그 파싱 헬퍼

    static func extractAndRemoveTags(_ text: String, pattern: String, action: (String) -> Void) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        for match in matches {
            if match.numberOfRanges >= 2 {
                let content = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
                if !content.isEmpty {
                    action(content)
                }
            }
        }
        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(location: 0, length: (text as NSString).length),
            withTemplate: ""
        )
    }
}
