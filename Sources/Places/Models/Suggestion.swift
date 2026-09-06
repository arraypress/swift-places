//
//  Suggestion.swift
//  Places
//
//  Created by David Sherlock on 2026.
//
//  What a half-typed query completes to.
//

import Foundation
import MapKit

/// One autocomplete suggestion — what a search field offers as you type.
///
/// A suggestion is **not** a place: it carries no coordinate. It is the text
/// of a query that MapKit knows will find something. Feed ``searchText`` back
/// into ``Places/search(_:near:radiusMetres:categories:excluding:resultTypes:limit:)``
/// to turn it into real results.
public struct Suggestion: Sendable, Codable, Equatable {

    /// The main line — "Trafalgar Square".
    public let title: String
    /// The qualifying line — "London, England". Empty for many results.
    public let subtitle: String
    /// What to search for to get this. Title and subtitle joined is NOT
    /// reliably the same string.
    public let searchText: String
    /// Where the typed fragment matched inside ``title`` — what a search
    /// field emboldens. Character offsets into the title.
    public let titleHighlights: [Highlight]
    /// The same for ``subtitle``.
    public let subtitleHighlights: [Highlight]

    /// A run of matched characters.
    public struct Highlight: Sendable, Codable, Equatable {
        /// Where the matched run starts in the title, in characters.
        public let location: Int
        /// How many characters it covers.
        public let length: Int
        public init(location: Int, length: Int) { self.location = location; self.length = length }
        /// The matched run as a range, for highlighting.
        public var range: Range<Int> { location..<(location + length) }
    }

    init(_ completion: MKLocalSearchCompletion) {
        self.title = completion.title
        self.subtitle = completion.subtitle
        self.titleHighlights = completion.titleHighlightRanges.map { Highlight(location: $0.rangeValue.location, length: $0.rangeValue.length) }
        self.subtitleHighlights = completion.subtitleHighlightRanges.map { Highlight(location: $0.rangeValue.location, length: $0.rangeValue.length) }
        // MapKit does not expose a "query" property; the title is what its own
        // search field submits, with the subtitle used only for display.
        self.searchText = completion.subtitle.isEmpty
            ? completion.title
            : "\(completion.title), \(completion.subtitle)"
    }

    public init(title: String, subtitle: String = "", searchText: String? = nil,
                titleHighlights: [Highlight] = [], subtitleHighlights: [Highlight] = []) {
        self.title = title
        self.subtitle = subtitle
        self.searchText = searchText ?? (subtitle.isEmpty ? title : "\(title), \(subtitle)")
        self.titleHighlights = titleHighlights
        self.subtitleHighlights = subtitleHighlights
    }

    /// The title with matched runs wrapped — `**Trafalg**ar Square` by default.
    public func markedTitle(open: String = "**", close: String = "**") -> String {
        Suggestion.mark(title, titleHighlights, open: open, close: close)
    }

    static func mark(_ text: String, _ highlights: [Highlight], open: String, close: String) -> String {
        let chars = Array(text)
        var out = ""
        var i = 0
        for h in highlights.sorted(by: { $0.location < $1.location }) where h.location >= i && h.location + h.length <= chars.count {
            out += String(chars[i..<h.location]) + open + String(chars[h.location..<(h.location + h.length)]) + close
            i = h.location + h.length
        }
        return out + String(chars[i...])
    }

    /// Both lines as one, for a plain list.
    public var displayText: String {
        subtitle.isEmpty ? title : "\(title) — \(subtitle)"
    }
}
