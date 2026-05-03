import Foundation
import AppKit

class ExportService {
    static let shared = ExportService()
    
    private init() {}
    
    enum ExportContentType {
        case keyPoints(keywords: [String], content: String)
        case notes(content: String, title: String)
        case annotations(annotations: String)
        case reviewPlan(plan: ReviewPlan)
    }
    
    enum ExportFormat: String, CaseIterable {
        case text = "纯文本"
        case markdown = "Markdown"
        case pdf = "PDF"
    }
    
    func exportToText(_ content: String, title: String) -> URL? {
        var text = "\(title)\n"
        text += String(repeating: "=", count: 30) + "\n\n"
        text += content
        
        let fileName = "\(title)_\(formattedDate()).txt"
        return saveToDownloads(text, fileName: fileName)
    }
    
    func exportToMarkdown(_ content: String, title: String) -> URL? {
        var md = "# \(title)\n\n"
        md += content
        
        let fileName = "\(title)_\(formattedDate()).md"
        return saveToDownloads(md, fileName: fileName)
    }
    
    func exportToPDF(_ content: String, title: String, subject: String = "学习资料") -> URL? {
        return PDFService.generateSummaryPDF(content: content, title: title, subject: subject, keywords: [])
    }
    
    func exportToWord(_ content: String, title: String) -> URL? {
        let html = """
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                body { font-family: 'Times New Roman', serif; font-size: 12pt; }
                h1 { font-size: 18pt; text-align: center; }
                p { line-height: 1.5; }
            </style>
        </head>
        <body>
            <h1>\(title)</h1>
            \(convertMarkdownToHTML(content))
        </body>
        </html>
        """
        
        let fileName = "\(title)_\(formattedDate()).doc"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try html.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }
    
    func exportToNotes(_ content: String, title: String) async -> Bool {
        let notesScript = """
        tell application "Notes"
            activate
            tell account "iCloud"
                make new note at folder "Notes" with properties {name:"\(title)", body:"\(escapeForAppleScript(content))"}
            end tell
        end tell
        """
        
        return await withCheckedContinuation { continuation in
            var error: NSDictionary?
            if let script = NSAppleScript(source: notesScript) {
                script.executeAndReturnError(&error)
                continuation.resume(returning: error == nil)
            } else {
                continuation.resume(returning: false)
            }
        }
    }
    
    func exportContent(_ content: ExportContentType, format: ExportFormat) -> URL? {
        switch content {
        case .keyPoints(let keywords, let content):
            return exportKeyPoints(keywords: keywords, content: content, format: format)
        case .notes(let content, let title):
            return exportNotes(content: content, title: title, format: format)
        case .annotations(let annotations):
            return exportAnnotations(annotations: annotations, format: format)
        case .reviewPlan(let plan):
            return exportReviewPlan(plan: plan, format: format)
        }
    }
    
    private func exportKeyPoints(keywords: [String], content: String, format: ExportFormat) -> URL? {
        var fullContent = "核心考点：\n"
        fullContent += keywords.joined(separator: ", ")
        fullContent += "\n\n详细内容：\n"
        fullContent += content
        
        switch format {
        case .text:
            return exportToText(fullContent, title: "考点提取")
        case .markdown:
            return exportToMarkdown(fullContent, title: "考点提取")
        case .pdf:
            return exportToPDF(fullContent, title: "考点提取")
        }
    }
    
    private func exportNotes(content: String, title: String, format: ExportFormat) -> URL? {
        switch format {
        case .text:
            return exportToText(content, title: title)
        case .markdown:
            return exportToMarkdown(content, title: title)
        case .pdf:
            return exportToPDF(content, title: title)
        }
    }
    
    private func exportAnnotations(annotations: String, format: ExportFormat) -> URL? {
        let content = "PDF 批注导出\n\n\(annotations)"
        
        switch format {
        case .text:
            return exportToText(content, title: "批注导出")
        case .markdown:
            return exportToMarkdown(content, title: "批注导出")
        case .pdf:
            return exportToPDF(content, title: "批注导出")
        }
    }
    
    private func exportReviewPlan(plan: ReviewPlan, format: ExportFormat) -> URL? {
        var content = "复习计划：\(plan.subject)\n\n"
        content += "创建日期：\(formatDate(plan.createdAt))\n"
        content += "考试日期：\(formatDate(plan.examDate))\n\n"
        content += "每日任务：\n"
        
        for dailyPlan in plan.dailyPlans {
            content += "\n日期：\(formatDate(dailyPlan.date))\n"
            for task in dailyPlan.tasks {
                let status = task.isCompleted ? "✓" : "○"
                content += "\(status) \(task.title)\n"
            }
        }
        
        switch format {
        case .text:
            return exportToText(content, title: "复习计划")
        case .markdown:
            return exportToMarkdown(content, title: "复习计划")
        case .pdf:
            return exportToPDF(content, title: "复习计划")
        }
    }
    
    private func convertMarkdownToHTML(_ markdown: String) -> String {
        var html = markdown
        html = html.replacingOccurrences(of: "# ", with: "<h2>")
        html = html.replacingOccurrences(of: "## ", with: "<h3>")
        html = html.replacingOccurrences(of: "### ", with: "<h4>")
        html = html.replacingOccurrences(of: "\n\n", with: "</p><p>")
        html = html.replacingOccurrences(of: "- ", with: "<li>")
        html = html.replacingOccurrences(of: "*", with: "")
        return "<p>\(html)</p>"
    }
    
    private func escapeForAppleScript(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
    
    private func saveToDownloads(_ content: String, fileName: String) -> URL? {
        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let fileURL = downloadsDir.appendingPathComponent(fileName)
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
