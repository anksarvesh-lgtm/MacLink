import Foundation

@_cdecl("maclink_init_isle_services")
public func maclink_init_isle_services() {
    IsleFinanceService.shared.start()
}

@_cdecl("maclink_get_isle_finance_json")
public func maclink_get_isle_finance_json(
    _ outBuf: UnsafeMutablePointer<CChar>,
    _ maxLen: Int
) -> Int {
    let json = IsleFinanceService.shared.getFinanceJson()
    guard let utf8 = json.data(using: .utf8) else { return 0 }
    let count = min(utf8.count, maxLen - 1)
    utf8.withUnsafeBytes { raw in
        if let base = raw.baseAddress {
            outBuf.initialize(from: base.assumingMemoryBound(to: CChar.self), count: count)
        }
    }
    outBuf[count] = 0
    return count
}

@_cdecl("maclink_refresh_isle_finance")
public func maclink_refresh_isle_finance() {
    IsleFinanceService.shared.fetchLiveQuotes()
}

@_cdecl("maclink_set_isle_symbol")
public func maclink_set_isle_symbol(_ symbolPtr: UnsafePointer<CChar>?) {
    guard let symbolPtr = symbolPtr else { return }
    let symbol = String(cString: symbolPtr)
    IsleFinanceService.shared.setPreferredSymbol(symbol)
}

@_cdecl("maclink_simulate_isle_quote")
public func maclink_simulate_isle_quote(
    _ symbolPtr: UnsafePointer<CChar>?,
    _ price: Double,
    _ change: Double
) {
    let symbol = symbolPtr != nil ? String(cString: symbolPtr!) : "BTC"
    IsleFinanceService.shared.simulateQuote(symbol: symbol, price: price, change: change)
}
