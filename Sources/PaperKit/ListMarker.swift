import Foundation

/// The marker at the start of a Markdown list item: `- `, `1. `, `- [ ] `, …
public struct ListMarker: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case bullet(Character)
        case ordered(Int, delimiter: Character)
        case task(bullet: Character, checked: Bool)
    }

    /// Leading spaces and tabs.
    public let indent: String
    public let kind: Kind
    /// Length of indentation, marker and the whitespace after it. The prefix is
    /// pure ASCII, so this is valid both as a `Character` and a UTF-16 count.
    public let prefixLength: Int
    /// The text after the marker.
    public let content: String

    public var isTask: Bool {
        if case .task = kind { return true }
        return false
    }

    /// Offset (from the start of the line) of the `[` of a task checkbox.
    public var checkboxOffset: Int? {
        guard case .task = kind else { return nil }
        return indent.count + 2
    }

    /// The prefix to start the next list item with when pressing Return.
    public var continuation: String {
        switch kind {
        case .bullet(let bullet):
            return "\(indent)\(bullet) "
        case .ordered(let number, let delimiter):
            return "\(indent)\(number + 1)\(delimiter) "
        case .task(let bullet, _):
            return "\(indent)\(bullet) [ ] "
        }
    }

    public static func parse(_ line: String) -> ListMarker? {
        let chars = Array(line)
        var index = 0
        while index < chars.count, chars[index] == " " || chars[index] == "\t" {
            index += 1
        }
        let indent = String(chars[..<index])
        guard index < chars.count else { return nil }

        func isSpace(_ i: Int) -> Bool { i < chars.count && (chars[i] == " " || chars[i] == "\t") }
        func skipSpaces(from i: Int) -> Int {
            var j = i
            while isSpace(j) { j += 1 }
            return j
        }

        let kind: Kind
        var end: Int

        if "-*+".contains(chars[index]) {
            let bullet = chars[index]
            // `-` alone at the end of the line is not (yet) a list item.
            guard isSpace(index + 1) else { return nil }
            end = skipSpaces(from: index + 1)
            if end + 2 < chars.count,
               chars[end] == "[",chars[end + 2] == "]",
               " xX".contains(chars[end + 1]),
               end + 3 == chars.count || isSpace(end + 3) {
                kind = .task(bullet: bullet, checked: chars[end + 1] != " ")
                end = skipSpaces(from: end + 3)
            } else {
                kind = .bullet(bullet)
            }
        } else if chars[index].isASCII, chars[index].isNumber {
            var digitsEnd = index
            while digitsEnd < chars.count, chars[digitsEnd].isASCII, chars[digitsEnd].isNumber {
                digitsEnd += 1
            }
            guard digitsEnd - index <= 9,
                  digitsEnd < chars.count,
                  chars[digitsEnd] == "." || chars[digitsEnd] == ")",
                  isSpace(digitsEnd + 1),
                  let number = Int(String(chars[index..<digitsEnd])) else { return nil }
            kind = .ordered(number, delimiter: chars[digitsEnd])
            end = skipSpaces(from: digitsEnd + 1)
        } else {
            return nil
        }

        return ListMarker(
            indent: indent,
            kind: kind,
            prefixLength: end,
            content: String(chars[end...])
        )
    }
}
