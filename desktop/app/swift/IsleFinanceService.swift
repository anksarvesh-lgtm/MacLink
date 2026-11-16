import Foundation

@objc public final class IsleFinanceService: NSObject, @unchecked Sendable {
    public static let shared = IsleFinanceService()

    public struct MarketQuote: Sendable {
        public let symbol: String
        public let name: String
        public let price: Double
        public let pctChange: Double
        public let formattedPrice: String
        public let isUp: Bool
    }

    private var quotes: [String: MarketQuote] = [:]
    private var preferredSymbol: String = "BTC"
    private var pollTimer: Timer?
    private var lastUpdatedTime: TimeInterval = 0

    private override init() {
        super.init()
        initDefaultQuotes()
    }

    private func initDefaultQuotes() {
        quotes["BTC"] = MarketQuote(symbol: "BTC", name: "Bitcoin", price: 91420.0, pctChange: 3.14, formattedPrice: "$91,420", isUp: true)
        quotes["ETH"] = MarketQuote(symbol: "ETH", name: "Ethereum", price: 3125.50, pctChange: 1.85, formattedPrice: "$3,125.50", isUp: true)
        quotes["SOL"] = MarketQuote(symbol: "SOL", name: "Solana", price: 212.80, pctChange: -0.92, formattedPrice: "$212.80", isUp: false)
        quotes["EUR"] = MarketQuote(symbol: "EUR", name: "Euro / USD", price: 1.085, pctChange: 0.22, formattedPrice: "1.085", isUp: true)
        quotes["USD"] = MarketQuote(symbol: "USD", name: "USD Index", price: 104.2, pctChange: -0.15, formattedPrice: "104.20", isUp: false)
    }

    public func start() {
        fetchLiveQuotes()
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 120.0, repeats: true) { [weak self] _ in
            self?.fetchLiveQuotes()
        }
    }

    public func setPreferredSymbol(_ symbol: String) {
        let upper = symbol.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if !upper.isEmpty {
            self.preferredSymbol = upper
        }
    }

    public func simulateQuote(symbol: String, price: Double, change: Double) {
        let sym = symbol.uppercased()
        let isUp = change >= 0
        let formatted = price >= 1000 ? String(format: "$%.0f", price) : String(format: "$%.2f", price)
        quotes[sym] = MarketQuote(symbol: sym, name: sym, price: price, pctChange: change, formattedPrice: formatted, isUp: isUp)
        self.lastUpdatedTime = Date().timeIntervalSince1970
    }

    public func fetchLiveQuotes() {
        guard let url = URL(string: "https://api.coincap.io/v2/assets?limit=5") else { return }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8.0
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data, error == nil else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let list = json["data"] as? [[String: Any]] {
                    for item in list {
                        if let sym = item["symbol"] as? String,
                           let priceUsdStr = item["priceUsd"] as? String,
                           let changeStr = item["changePercent24Hr"] as? String,
                           let price = Double(priceUsdStr),
                           let change = Double(changeStr) {
                            let isUp = change >= 0
                            let formatted = price >= 1000 ? String(format: "$%.0f", price) : String(format: "$%.2f", price)
                            let name = (item["name"] as? String) ?? sym
                            self?.quotes[sym] = MarketQuote(symbol: sym, name: name, price: price, pctChange: change, formattedPrice: formatted, isUp: isUp)
                        }
                    }
                    self?.lastUpdatedTime = Date().timeIntervalSince1970
                }
            } catch {
                // Keep cached/default quotes
            }
        }.resume()
    }

    public func getFinanceJson() -> String {
        let targetQuote = quotes[preferredSymbol] ?? quotes["BTC"] ?? MarketQuote(symbol: "BTC", name: "Bitcoin", price: 91420.0, pctChange: 3.14, formattedPrice: "$91,420", isUp: true)

        let allQuotesJson = quotes.values.map { q in
            """
            {"symbol":"\(q.symbol)","name":"\(q.name)","price":\(q.price),"formattedPrice":"\(q.formattedPrice)","pctChange":\(q.pctChange),"isUp":\(q.isUp)}
            """
        }.joined(separator: ",")

        return """
        {"symbol":"\(targetQuote.symbol)","name":"\(targetQuote.name)","price":\(targetQuote.price),"formattedPrice":"\(targetQuote.formattedPrice)","pctChange":\(targetQuote.pctChange),"isUp":\(targetQuote.isUp),"lastUpdated":\(lastUpdatedTime),"quotes":[\(allQuotesJson)]}
        """
    }
}
