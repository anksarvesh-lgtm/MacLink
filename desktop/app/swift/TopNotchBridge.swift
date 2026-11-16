import Foundation

@_cdecl("maclink_get_topnotch_focus_json")
public func maclink_get_topnotch_focus_json(buffer: UnsafeMutablePointer<CChar>, max_len: Int) -> Int {
    let json = TopNotchFocusService.shared.getFocusJson()
    guard let cStr = json.cString(using: .utf8) else { return 0 }
    let len = min(cStr.count - 1, max_len - 1)
    if len > 0 {
        memcpy(buffer, cStr, len)
        buffer[len] = 0
        return len
    }
    return 0
}

@_cdecl("maclink_topnotch_start_focus")
public func maclink_topnotch_start_focus(minutes: Int32) {
    DispatchQueue.main.async {
        TopNotchFocusService.shared.startFocus(minutes: minutes)
    }
}

@_cdecl("maclink_topnotch_pause_focus")
public func maclink_topnotch_pause_focus() {
    DispatchQueue.main.async {
        TopNotchFocusService.shared.pauseFocus()
    }
}

@_cdecl("maclink_topnotch_resume_focus")
public func maclink_topnotch_resume_focus() {
    DispatchQueue.main.async {
        TopNotchFocusService.shared.resumeFocus()
    }
}

@_cdecl("maclink_topnotch_skip_focus")
public func maclink_topnotch_skip_focus() {
    DispatchQueue.main.async {
        TopNotchFocusService.shared.skipFocus()
    }
}

@_cdecl("maclink_topnotch_reset_focus")
public func maclink_topnotch_reset_focus() {
    DispatchQueue.main.async {
        TopNotchFocusService.shared.resetFocus()
    }
}

@_cdecl("maclink_topnotch_save_note")
public func maclink_topnotch_save_note(title: UnsafePointer<CChar>, text: UnsafePointer<CChar>) {
    let titleStr = String(cString: title)
    let textStr = String(cString: text)
    DispatchQueue.main.async {
        TopNotchFocusService.shared.saveNote(title: titleStr, text: textStr)
    }
}

@_cdecl("maclink_topnotch_delete_note")
public func maclink_topnotch_delete_note(index: Int32) {
    DispatchQueue.main.async {
        TopNotchFocusService.shared.deleteNote(index: index)
    }
}
