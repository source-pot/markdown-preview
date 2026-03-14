import Foundation
import Markdown

struct MarkdownRenderer {
    static func render(_ markdown: String, theme: Theme) -> String {
        let document = Document(parsing: markdown)
        var visitor = HTMLVisitor()
        let htmlContent = visitor.visit(document)

        let themeAttribute = theme == .auto ? "auto" : (theme == .dark ? "dark" : "light")

        return """
        <!DOCTYPE html>
        <html data-theme="\(themeAttribute)">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>\(css)</style>
            <script>\(highlightJS)</script>
        </head>
        <body>
            <article class="markdown-body">
                \(htmlContent)
            </article>
            <script>hljs.highlightAll();</script>
        </body>
        </html>
        """
    }

    private static var css: String {
        if let url = Bundle.module.url(forResource: "style", withExtension: "css", subdirectory: "Resources"),
           let content = try? String(contentsOf: url, encoding: .utf8) {
            return content
        }
        return defaultCSS
    }

    private static var highlightJS: String {
        if let url = Bundle.module.url(forResource: "highlight.min", withExtension: "js", subdirectory: "Resources"),
           let content = try? String(contentsOf: url, encoding: .utf8) {
            return content
        }
        return ""
    }

    private static let defaultCSS = """
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
            line-height: 1.6;
            padding: 20px;
            max-width: 900px;
            margin: 0 auto;
        }
        pre { background: #f6f8fa; padding: 16px; border-radius: 6px; overflow-x: auto; }
        code { font-family: 'SF Mono', Consolas, monospace; }
        """
}

// MARK: - HTML Visitor

struct HTMLVisitor: MarkupVisitor {
    typealias Result = String

    mutating func defaultVisit(_ markup: any Markup) -> String {
        markup.children.map { visit($0) }.joined()
    }

    mutating func visitDocument(_ document: Document) -> String {
        document.children.map { visit($0) }.joined()
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> String {
        "<p>\(paragraph.children.map { visit($0) }.joined())</p>\n"
    }

    mutating func visitText(_ text: Text) -> String {
        escapeHTML(text.string)
    }

    mutating func visitHeading(_ heading: Heading) -> String {
        let level = heading.level
        let content = heading.children.map { visit($0) }.joined()
        return "<h\(level)>\(content)</h\(level)>\n"
    }

    mutating func visitStrong(_ strong: Strong) -> String {
        "<strong>\(strong.children.map { visit($0) }.joined())</strong>"
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> String {
        "<em>\(emphasis.children.map { visit($0) }.joined())</em>"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> String {
        "<code>\(escapeHTML(inlineCode.code))</code>"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
        let language = codeBlock.language ?? ""
        let langClass = language.isEmpty ? "" : " class=\"language-\(language)\""
        return "<pre><code\(langClass)>\(escapeHTML(codeBlock.code))</code></pre>\n"
    }

    mutating func visitLink(_ link: Link) -> String {
        let href = link.destination ?? ""
        let content = link.children.map { visit($0) }.joined()
        return "<a href=\"\(escapeHTML(href))\">\(content)</a>"
    }

    mutating func visitImage(_ image: Image) -> String {
        let src = image.source ?? ""
        let alt = image.children.map { visit($0) }.joined()
        return "<img src=\"\(escapeHTML(src))\" alt=\"\(escapeHTML(alt))\">"
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> String {
        "<ul>\n\(unorderedList.children.map { visit($0) }.joined())</ul>\n"
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) -> String {
        "<ol>\n\(orderedList.children.map { visit($0) }.joined())</ol>\n"
    }

    mutating func visitListItem(_ listItem: ListItem) -> String {
        "<li>\(listItem.children.map { visit($0) }.joined())</li>\n"
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> String {
        "<blockquote>\n\(blockQuote.children.map { visit($0) }.joined())</blockquote>\n"
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> String {
        "<hr>\n"
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> String {
        "<br>\n"
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> String {
        "\n"
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> String {
        "<del>\(strikethrough.children.map { visit($0) }.joined())</del>"
    }

    mutating func visitTable(_ table: Table) -> String {
        "<table>\n\(table.children.map { visit($0) }.joined())</table>\n"
    }

    mutating func visitTableHead(_ tableHead: Table.Head) -> String {
        "<thead>\n<tr>\(tableHead.children.map { visit($0) }.joined())</tr>\n</thead>\n"
    }

    mutating func visitTableBody(_ tableBody: Table.Body) -> String {
        "<tbody>\n\(tableBody.children.map { visit($0) }.joined())</tbody>\n"
    }

    mutating func visitTableRow(_ tableRow: Table.Row) -> String {
        "<tr>\(tableRow.children.map { visit($0) }.joined())</tr>\n"
    }

    mutating func visitTableCell(_ tableCell: Table.Cell) -> String {
        let tag = tableCell.parent is Table.Head ? "th" : "td"
        return "<\(tag)>\(tableCell.children.map { visit($0) }.joined())</\(tag)>"
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) -> String {
        html.rawHTML
    }

    mutating func visitInlineHTML(_ html: InlineHTML) -> String {
        html.rawHTML
    }

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
