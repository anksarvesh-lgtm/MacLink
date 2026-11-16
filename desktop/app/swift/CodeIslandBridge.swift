// SPDX-License-Identifier: GPL-3.0-or-later
//
//  CodeIslandBridge.swift
//  MacLink Native CodeIsland C-ABI Exports
//  Connects AgentTaskProgressService and Question Answering to Rust & QML
//

import Cocoa
import Foundation

@_cdecl("maclink_get_agent_tasks_json")
public func maclink_get_agent_tasks_json(buffer: UnsafeMutablePointer<CChar>, maxLen: Int) -> Int {
    let snap = AgentTaskProgressService.shared.getSnapshot()
    guard let data = try? JSONEncoder().encode(snap),
          let str = String(data: data, encoding: .utf8) else {
        return 0
    }
    let count = str.utf8.count
    if count < maxLen {
        str.withCString { ptr in
            buffer.initialize(from: ptr, count: count + 1)
        }
        return count
    }
    return 0
}

@_cdecl("maclink_get_agent_question_json")
public func maclink_get_agent_question_json(buffer: UnsafeMutablePointer<CChar>, maxLen: Int) -> Int {
    let snap = AgentHookRelay.shared.getQuestionSnapshot()
    guard let data = try? JSONEncoder().encode(snap),
          let str = String(data: data, encoding: .utf8) else {
        return 0
    }
    let count = str.utf8.count
    if count < maxLen {
        str.withCString { ptr in
            buffer.initialize(from: ptr, count: count + 1)
        }
        return count
    }
    return 0
}

@_cdecl("maclink_answer_agent_question")
public func maclink_answer_agent_question(optionIndex: Int32) {
    AgentHookRelay.shared.answerQuestion(optionIndex: Int(optionIndex))
}

@_cdecl("maclink_clear_agent_tasks")
public func maclink_clear_agent_tasks() {
    AgentTaskProgressService.shared.clearTasks()
}
