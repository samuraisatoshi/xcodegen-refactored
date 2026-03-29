import Foundation
import Rainbow

/// Produces rich terminal output with box-drawing characters, status icons, and aligned tables.
struct RichFormatter {

    enum Icon: String {
        case ok      = "✓"
        case error   = "✗"
        case warning = "⚠"
        case info    = "○"

        var colored: String {
            switch self {
            case .ok:      return rawValue.green
            case .error:   return rawValue.red
            case .warning: return rawValue.yellow
            case .info:    return rawValue.cyan
            }
        }
    }

    // MARK: - Simple box with key-value rows

    /// Renders a box with a title and optional data rows.
    ///
    /// ```
    /// ┌─────────────────────────────┐
    /// │  ✓  MyApp.xcodeproj         │
    /// ├─────────────────────────────┤
    /// │  Targets   App · Tests      │
    /// │  Duration  0.8s             │
    /// └─────────────────────────────┘
    /// ⚠  Some warning here
    /// ```
    static func box(
        title: String,
        icon: Icon,
        rows: [(label: String, value: String)] = [],
        warnings: [String] = []
    ) -> String {
        let titleLine = "  \(icon.colored)  \(title)"
        // Strip color codes for width calculation
        let titleWidth = title.count + 5  // "  X  " prefix

        let labelWidth = rows.map { $0.label.count }.max() ?? 0
        let rowLines = rows.map { r in
            "  \(r.label.padding(toLength: labelWidth, withPad: " ", startingAt: 0))  \(r.value)"
        }

        let contentWidth = max(
            titleWidth,
            (rowLines.map { $0.count }.max() ?? 0)
        ) + 2  // +2 for "│ " padding

        let width = max(contentWidth, 20)

        var lines: [String] = []

        // Top border
        lines.append("┌" + String(repeating: "─", count: width) + "┐")
        // Title
        lines.append("│" + pad(titleLine, to: width) + "│")

        if !rows.isEmpty {
            // Separator
            lines.append("├" + String(repeating: "─", count: width) + "┤")
            for row in rowLines {
                lines.append("│" + pad(row, to: width) + "│")
            }
        }

        // Bottom border
        lines.append("└" + String(repeating: "─", count: width) + "┘")

        // Warnings below box
        for w in warnings {
            lines.append("\(Icon.warning.colored)  \(w)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Table with column headers

    /// Renders a titled table with auto-sized columns.
    ///
    /// ```
    /// ┌─────────────────────────────────────┐
    /// │  ○  targets (3)                     │
    /// ├──────────────┬──────────────┬───────┤
    /// │  Name        │  Type        │  Plt  │
    /// ├──────────────┼──────────────┼───────┤
    /// │  MyApp       │  application │  iOS  │
    /// └──────────────┴──────────────┴───────┘
    /// ```
    static func table(
        title: String,
        icon: Icon,
        headers: [String],
        rows: [[String]],
        warnings: [String] = []
    ) -> String {
        guard !headers.isEmpty else {
            return box(title: title, icon: icon, warnings: warnings)
        }

        // Calculate column widths (max of header or any data)
        var colWidths = headers.map { $0.count }
        for row in rows {
            for (i, cell) in row.enumerated() where i < colWidths.count {
                colWidths[i] = max(colWidths[i], cell.count)
            }
        }

        let titleLine = "  \(icon.colored)  \(title)"
        let titleWidth = title.count + 5

        // Total table width: sum of (colWidth + 2 padding) + (N-1 separators) + 2 outer │
        let tableWidth = colWidths.reduce(0) { $0 + $1 + 4 } + (colWidths.count - 1) - 1
        let width = max(tableWidth, titleWidth + 2, 20)

        var lines: [String] = []

        // Top border + title
        lines.append("┌" + String(repeating: "─", count: width) + "┐")
        lines.append("│" + pad(titleLine, to: width) + "│")

        // Column separator row (top of table)
        lines.append(hSep(colWidths: colWidths, left: "├", mid: "┬", right: "┤", fill: "─"))

        // Header row
        lines.append(dataRow(cells: headers, colWidths: colWidths))

        // Header / data separator
        lines.append(hSep(colWidths: colWidths, left: "├", mid: "┼", right: "┤", fill: "─"))

        // Data rows
        for row in rows {
            lines.append(dataRow(cells: row, colWidths: colWidths))
        }

        // Bottom border
        lines.append(hSep(colWidths: colWidths, left: "└", mid: "┴", right: "┘", fill: "─"))

        for w in warnings {
            lines.append("\(Icon.warning.colored)  \(w)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func pad(_ s: String, to width: Int) -> String {
        // Count visible chars (strip ANSI escape codes for length)
        let visible = s.replacingOccurrences(
            of: "\u{001B}\\[[0-9;]*m",
            with: "",
            options: .regularExpression
        )
        let needed = width - visible.count
        guard needed > 0 else { return s }
        return s + String(repeating: " ", count: needed)
    }

    private static func hSep(colWidths: [Int], left: String, mid: String, right: String, fill: String) -> String {
        let segments = colWidths.map { String(repeating: fill, count: $0 + 4) }
        return left + segments.joined(separator: mid) + right
    }

    private static func dataRow(cells: [String], colWidths: [Int]) -> String {
        var parts: [String] = []
        for (i, width) in colWidths.enumerated() {
            let cell = i < cells.count ? cells[i] : ""
            parts.append("  " + cell.padding(toLength: width, withPad: " ", startingAt: 0) + "  ")
        }
        return "│" + parts.joined(separator: "│") + "│"
    }
}
