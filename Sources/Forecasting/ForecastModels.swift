import Foundation

struct ForecastPoint: Sendable {
    let date: Date
    let value: Double
}

struct ForecastResult: Sendable {
    let points: [ForecastPoint]
    let summary: String
}
