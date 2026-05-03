import SwiftUI
import UniformTypeIdentifiers

struct DuplicateScannerView: View {
    @StateObject private var scanner = DuplicateScanner()
    @State private var showDirectoryPicker = false
    @State private var selectedDirectory: URL?
    @State private var keepNewest = true
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider()
            
            if scanner.isScanning {
                scanningView
            } else if scanner.duplicates.isEmpty {
                emptyStateView
            } else {
                resultsView
            }
        }
        .fileImporter(
            isPresented: $showDirectoryPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleDirectorySelection(result)
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("重复文件清理")
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            Button {
                showDirectoryPicker = true
            } label: {
                Label("选择文件夹", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.bordered)
            .disabled(scanner.isScanning)
        }
        .padding()
    }
    
    private var scanningView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView(value: scanner.scanProgress)
                .progressViewStyle(.linear)
                .frame(width: 300)
            
            Text("正在扫描... \(Int(scanner.scanProgress * 100))%")
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "doc.on.doc")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("点击上方按钮选择要扫描的文件夹")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("支持 PDF、DOC、DOCX、TXT、MD、PPT、PPTX")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    private var resultsView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("发现 \(scanner.duplicates.count) 组重复文件")
                    .font(.headline)
                
                Spacer()
                
                Picker("保留", selection: $keepNewest) {
                    Text("最新").tag(true)
                    Text("最旧").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
                
                Button {
                    scanner.deleteAllDuplicates(keepNewest: keepNewest)
                } label: {
                    Label("一键清理", systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .padding(.horizontal)
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(scanner.duplicates) { group in
                        DuplicateGroupCard(
                            group: group,
                            keepNewest: keepNewest,
                            onDelete: {
                                scanner.deleteDuplicates(keepNewest: keepNewest, in: group)
                            }
                        )
                    }
                }
                .padding()
            }
        }
    }
    
    private func handleDirectorySelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                selectedDirectory = url
                Task {
                    await scanner.scanDirectory(url)
                }
            }
        case .failure(let error):
            print("Error selecting directory: \(error)")
        }
    }
}

struct DuplicateGroupCard: View {
    let group: DuplicateScanner.DuplicateGroup
    let keepNewest: Bool
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.fill")
                    .foregroundColor(.accentColor)
                
                Text(group.fileName)
                    .font(.headline)
                
                Spacer()
                
                Text(formatSize(group.totalSize))
                    .foregroundColor(.secondary)
                
                Button {
                    onDelete()
                } label: {
                    Label("清理", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            
            ForEach(group.files) { file in
                HStack {
                    Image(systemName: isKept(file) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isKept(file) ? .green : .gray)
                    
                    VStack(alignment: .leading) {
                        Text(file.url.lastPathComponent)
                            .font(.subheadline)
                        
                        Text("\(formatSize(file.size)) • \(formatDate(file.modifiedDate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(isKept(file) ? "保留" : "将删除")
                        .font(.caption)
                        .foregroundColor(isKept(file) ? .green : .red)
                }
                .padding(.leading, 20)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func isKept(_ file: DuplicateScanner.DuplicateFile) -> Bool {
        if keepNewest {
            return file.id == group.files.first?.id
        } else {
            return file.id == group.files.last?.id
        }
    }
    
    private func formatSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
