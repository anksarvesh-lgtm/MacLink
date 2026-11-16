// SPDX-License-Identifier: GPL-3.0-or-later
//
//  AgentHookRelay.swift
//  MacLink Native AI Agent Session Tracker & Hook Engine
//  Reverse-engineered and adapted from coucou (Louis-CFM/coucou)
//

import Cocoa
import Foundation

public final class AgentHookRelay {
    public static let shared = AgentHookRelay()

    public struct AgentState: Codable {
        public var hasSession: Bool
        public var agentName: String
        public var toolName: String
        public var targetPath: String
        public var diffAdded: Int
        public var diffRemoved: Int
        public var hasApproval: Bool
        public var approvalPrompt: String
    }

    public struct QuestionState: Codable {
        public var hasQuestion: Bool
        public var agentName: String
        public var question: String
        public var options: [String]
    }

    private var hasSession: Bool = false
    private var agentName: String = "Antigravity"
    private var toolName: String = ""
    private var targetPath: String = ""
    private var diffAdded: Int = 0
    private var diffRemoved: Int = 0
    private var hasApproval: Bool = false
    private var approvalPrompt: String = ""

    private var hasQuestion: Bool = false
    private var questionText: String = ""
    private var questionOptions: [String] = []
    private var pendingQuestionFD: Int32 = -1

    private var serverFD: Int32 = -1
    private var pendingClientFD: Int32 = -1
    private let lock = NSLock()

    private init() {}

    public func startSocketServer() {
        lock.lock()
        defer { lock.unlock() }
        guard serverFD == -1 else { return }

        let sockPath = "/tmp/maclink_hook.sock"
        unlink(sockPath)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = sockPath.utf8CString
        withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in
            pathBytes.withUnsafeBufferPointer { buf in
                _ = memcpy(ptr, buf.baseAddress!, min(buf.count, 104))
            }
        }

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bindRes = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                bind(fd, sa, addrLen)
            }
        }

        guard bindRes == 0, listen(fd, 8) == 0 else {
            close(fd)
            return
        }

        serverFD = fd

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            while let strongSelf = self, strongSelf.serverFD >= 0 {
                var clientAddr = sockaddr_un()
                var clientLen = socklen_t(MemoryLayout<sockaddr_un>.size)
                let cfd = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                        accept(strongSelf.serverFD, sa, &clientLen)
                    }
                }
                guard cfd >= 0 else { break }
                strongSelf.handleClient(cfd)
            }
        }
    }

    private func handleClient(_ cfd: Int32) {
        var buf = [UInt8](repeating: 0, count: 4096)
        let n = read(cfd, &buf, buf.count)
        guard n > 0, let str = String(bytes: buf.prefix(n), encoding: .utf8) else {
            close(cfd)
            return
        }

        guard let data = str.data(using: .utf8),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            close(cfd)
            return
        }

        let event = json["event"] as? String ?? ""
        if event == "approval" {
            let agent = json["agent"] as? String ?? "AI Agent"
            let prompt = json["prompt"] as? String ?? "Permission requested"
            lock.lock()
            if pendingClientFD >= 0 {
                close(pendingClientFD)
            }
            pendingClientFD = cfd
            lock.unlock()
            requestApproval(agent: agent, prompt: prompt)
        } else if event == "question" {
            let agent = json["agent"] as? String ?? "AI Agent"
            let q = json["question"] as? String ?? ""
            let opts = json["options"] as? [String] ?? []
            lock.lock()
            if pendingQuestionFD >= 0 {
                close(pendingQuestionFD)
            }
            pendingQuestionFD = cfd
            lock.unlock()
            requestQuestion(agent: agent, question: q, options: opts)
        } else if event == "tasks" {
            if let taskObjs = json["tasks"] as? [[String: Any]] {
                let items = taskObjs.map { obj in
                    AgentTaskProgressService.TaskItem(
                        title: obj["title"] as? String ?? "Task",
                        status: obj["status"] as? String ?? "pending",
                        activeForm: obj["activeForm"] as? String
                    )
                }
                AgentTaskProgressService.shared.setTasks(items)
            }
            let response = "{\"ok\":true}\n"
            _ = response.withCString { write(cfd, $0, strlen($0)) }
            close(cfd)
        } else if event == "tool" {
            let agent = json["agent"] as? String ?? "AI Agent"
            let tool = json["tool"] as? String ?? ""
            let target = json["target"] as? String ?? ""
            let added = json["added"] as? Int ?? 0
            let removed = json["removed"] as? Int ?? 0
            postAgentEvent(agent: agent, tool: tool, target: target, added: added, removed: removed)
            let response = "{\"ok\":true}\n"
            _ = response.withCString { write(cfd, $0, strlen($0)) }
            close(cfd)
        } else if event == "screenshot" {
            takeQuickScreenshot()
            let response = "{\"ok\":true}\n"
            _ = response.withCString { write(cfd, $0, strlen($0)) }
            close(cfd)
        } else {
            let response = "{\"status\":\"received\"}\n"
            _ = response.withCString { write(cfd, $0, strlen($0)) }
            close(cfd)
        }
    }

    public func postAgentEvent(agent: String, tool: String, target: String, added: Int, removed: Int) {
        self.hasSession = true
        self.agentName = agent
        self.toolName = tool
        self.targetPath = target
        self.diffAdded = added
        self.diffRemoved = removed
    }

    public func requestApproval(agent: String, prompt: String) {
        self.hasSession = true
        self.agentName = agent
        self.hasApproval = true
        self.approvalPrompt = prompt
        MochiEngine.shared.setMood(.approval)
        NSSound(named: "Basso")?.play()
    }

    public func respondApproval(allow: Bool) {
        self.hasApproval = false
        self.approvalPrompt = ""
        MochiEngine.shared.setMood(allow ? .happy : .idle)

        lock.lock()
        let cfd = pendingClientFD
        pendingClientFD = -1
        lock.unlock()

        if cfd >= 0 {
            let resp = "{\"allowed\":\(allow)}\n"
            _ = resp.withCString { write(cfd, $0, strlen($0)) }
            close(cfd)
        }
    }

    public func clearSession() {
        self.hasSession = false
        self.hasApproval = false
        self.toolName = ""
        self.targetPath = ""
        MochiEngine.shared.setMood(.idle)
    }

    public func getSnapshot() -> AgentState {
        return AgentState(
            hasSession: hasSession,
            agentName: agentName,
            toolName: toolName,
            targetPath: targetPath,
            diffAdded: diffAdded,
            diffRemoved: diffRemoved,
            hasApproval: hasApproval,
            approvalPrompt: approvalPrompt
        )
    }

    public func requestQuestion(agent: String, question: String, options: [String]) {
        self.hasSession = true
        self.agentName = agent
        self.hasQuestion = true
        self.questionText = question
        self.questionOptions = options
        MochiEngine.shared.setMood(.thinking)
        NSSound(named: "Ping")?.play()
    }

    public func answerQuestion(optionIndex: Int) {
        lock.lock()
        let cfd = pendingQuestionFD
        pendingQuestionFD = -1
        let optText = (optionIndex >= 0 && optionIndex < questionOptions.count) ? questionOptions[optionIndex] : ""
        self.hasQuestion = false
        self.questionText = ""
        self.questionOptions = []
        lock.unlock()

        MochiEngine.shared.setMood(.happy)

        if cfd >= 0 {
            let resp = "{\"optionIndex\":\(optionIndex),\"answer\":\"\(optText)\"}\n"
            _ = resp.withCString { write(cfd, $0, strlen($0)) }
            close(cfd)
        }
    }

    public func getQuestionSnapshot() -> QuestionState {
        lock.lock()
        defer { lock.unlock() }
        return QuestionState(
            hasQuestion: hasQuestion,
            agentName: agentName,
            question: questionText,
            options: questionOptions
        )
    }

    public func takeQuickScreenshot() {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            task.arguments = ["-i", "-c"] // Interactive capture directly to clipboard
            try? task.run()
        }
    }
}
