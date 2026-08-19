import CoreLocation
import Foundation

/// 座標解析工具
enum CoordinateParser {
    private static let numberExpression = try! NSRegularExpression(
        pattern: #"[-+]?(?:\d+(?:\.\d*)?|\.\d+)"#
    )

    /// 判斷文本是否可解析為座標
    /// - Parameter text: 待解析的文本
    /// - Returns: 若能解析為有效座標則返回true
    static func canParse(_ text: String) -> Bool {
        parse(text) != nil
    }
    
    /// 解析座標字符串
    /// 支援格式: "latitude,longitude"
    /// - Parameter text: 待解析的文本
    /// - Returns: 若解析成功則返回座標，否則返回nil
    static func parse(_ text: String) -> CLLocationCoordinate2D? {
        let expression = Self.numberExpression
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let values = expression.matches(in: text, range: range).compactMap { match -> Double? in
            guard let matchRange = Range(match.range, in: text) else { return nil }
            return Double(text[matchRange])
        }
        
        guard values.count == 2 else { return nil }
        
        let coordinate = CLLocationCoordinate2D(latitude: values[0], longitude: values[1])
        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
        
        return coordinate
    }
}
