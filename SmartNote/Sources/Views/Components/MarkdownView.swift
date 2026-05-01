import SwiftUI

struct MarkdownText: View {
    let content: String
    
    init(_ content: String) {
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(parseMarkdown(content), id: \.self) { element in
                renderElement(element)
            }
        }
    }
    
    private func parseMarkdown(_ text: String) -> [MarkdownElement] {
        var elements: [MarkdownElement] = []
        let lines = text.components(separatedBy: "\n")
        
        for line in lines {
            if line.hasPrefix("### ") {
                elements.append(.heading3(String(line.dropFirst(4))))
            } else if line.hasPrefix("## ") {
                elements.append(.heading2(String(line.dropFirst(3))))
            } else if line.hasPrefix("# ") {
                elements.append(.heading1(String(line.dropFirst(2))))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                let itemText = String(line.dropFirst(2))
                elements.append(.listItem(itemText))
            } else if line.hasPrefix("1.") || line.hasPrefix("2.") || line.hasPrefix("3.") ||
                      line.hasPrefix("4.") || line.hasPrefix("5.") || line.hasPrefix("6.") ||
                      line.hasPrefix("7.") || line.hasPrefix("8.") || line.hasPrefix("9.") {
                elements.append(.numberedListItem(line))
            } else if line.contains("**") {
                elements.append(.bold(line))
            } else if line.contains("`") {
                elements.append(.code(line))
            } else if line.hasPrefix("---") || line.hasPrefix("***") {
                elements.append(.divider)
            } else if !line.isEmpty {
                elements.append(.paragraph(line))
            }
        }
        
        return elements
    }
    
    @ViewBuilder
    private func renderElement(_ element: MarkdownElement) -> some View {
        switch element {
        case .heading1(let text):
            Text(text)
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 8)
            
        case .heading2(let text):
            Text(text)
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 6)
            
        case .heading3(let text):
            Text(text)
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.top, 4)
            
        case .paragraph(let text):
            Text(attributedString(from: text))
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            
        case .listItem(let text):
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(.body)
                Text(attributedString(from: text))
                    .font(.body)
            }
            
        case .numberedListItem(let text):
            HStack(alignment: .top, spacing: 8) {
                if let number = text.prefix(1).first, number.isNumber {
                    Text(String(number) + ".")
                        .font(.body)
                }
                Text(attributedString(from: String(text.dropFirst(3))))
                    .font(.body)
            }
            
        case .code(let text):
            Text(text)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(4)
            
        case .bold(let text):
            Text(attributedString(from: text))
                .font(.body.weight(.bold))
            
        case .divider:
            Divider()
                .padding(.vertical, 4)
        }
    }
    
    private func attributedString(from text: String) -> AttributedString {
        var result = AttributedString(text)
        
        var searchStart = result.startIndex
        while searchStart < result.endIndex {
            if let boldStart = result[searchStart...].range(of: "**") {
                if let boldEnd = result[boldStart.upperBound...].range(of: "**") {
                    let boldRange = boldStart.lowerBound..<boldEnd.upperBound
                    result[boldRange].inlinePresentationIntent = .stronglyEmphasized
                    
                    let innerRange = boldStart.upperBound..<boldEnd.lowerBound
                    result[innerRange].font = .body.weight(.bold)
                    
                    searchStart = boldEnd.upperBound
                } else {
                    break
                }
            } else {
                break
            }
        }
        
        searchStart = result.startIndex
        while searchStart < result.endIndex {
            if let codeStart = result[searchStart...].range(of: "`") {
                if let codeEnd = result[codeStart.upperBound...].range(of: "`") {
                    let codeRange = codeStart.lowerBound..<codeEnd.upperBound
                    let innerRange = codeStart.upperBound..<codeEnd.lowerBound
                    
                    result[innerRange].font = .system(.body, design: .monospaced)
                    result[innerRange].backgroundColor = Color(nsColor: .controlBackgroundColor)
                    
                    searchStart = codeEnd.upperBound
                } else {
                    break
                }
            } else {
                break
            }
        }
        
        return result
    }
}

enum MarkdownElement: Hashable {
    case heading1(String)
    case heading2(String)
    case heading3(String)
    case paragraph(String)
    case listItem(String)
    case numberedListItem(String)
    case bold(String)
    case code(String)
    case divider
}

struct MarkdownTextField: View {
    @Binding var text: String
    var placeholder: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 150)
                .padding(4)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)
            
            HStack {
                Spacer()
                Text("支持 Markdown 格式")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct MarkdownPreview: View {
    let source: String
    @State private var isEditing = false
    @Binding var text: String
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("预览")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Toggle("编辑", isOn: $isEditing)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
            
            if isEditing {
                TextEditor(text: $text)
                    .font(.system(.body, design: .monospaced))
                    .padding(4)
            } else {
                ScrollView {
                    MarkdownText(text)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
}
