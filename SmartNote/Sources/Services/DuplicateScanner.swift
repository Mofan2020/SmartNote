import Foundation
import AppKit

class DuplicateScanner: ObservableObject {
    @Published var isScanning = false
    @Published var duplicates: [DuplicateGroup] = []
    @Published var scanProgress: Double = 0
    
    struct DuplicateGroup: Identifiable {
        let id = UUID()
        let fileName: String
        let files: [DuplicateFile]
        
        var totalSize: Int64 {
            files.reduce(0) { $0 + $1.size }
        }
    }
    
    struct DuplicateFile: Identifiable {
        let id = UUID()
        let url: URL
        let size: Int64
        let modifiedDate: Date
        let hash: String
    }
    
    func scanDirectory(_ directoryURL: URL, extensions: [String] = ["pdf", "doc", "docx", "txt", "md", "ppt", "pptx"]) async {
        await MainActor.run {
            isScanning = true
            duplicates = []
            scanProgress = 0
        }
        
        var fileInfos: [(url: URL, size: Int64, date: Date, hash: String)] = []
        
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            await MainActor.run { isScanning = false }
            return
        }
        
        var allFiles: [URL] = []
        
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if extensions.contains(ext) {
                allFiles.append(fileURL)
            }
        }
        
        let total = allFiles.count
        var processed = 0
        
        for fileURL in allFiles {
            do {
                let attributes = try fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                let size = Int64(attributes.fileSize ?? 0)
                let date = attributes.contentModificationDate ?? Date()
                
                let hash = await computeFileHash(fileURL)
                
                fileInfos.append((fileURL, size, date, hash))
            } catch {
                print("Error reading file \(fileURL): \(error)")
            }
            
            processed += 1
            let progress = Double(processed) / Double(total)
            await MainActor.run { scanProgress = progress }
        }
        
        let grouped = Dictionary(grouping: fileInfos) { $0.hash }
        
        var duplicateGroups: [DuplicateGroup] = []
        
        for (hash, files) in grouped where files.count > 1 {
            let sortedFiles = files.sorted { $0.date > $1.date }
            let duplicateFiles = sortedFiles.map { DuplicateFile(url: $0.url, size: $0.size, modifiedDate: $0.date, hash: $0.hash) }
            
            let group = DuplicateGroup(
                fileName: sortedFiles.first?.url.lastPathComponent ?? "Unknown",
                files: duplicateFiles
            )
            duplicateGroups.append(group)
        }
        
        duplicateGroups.sort { $0.totalSize > $1.totalSize }
        
        await MainActor.run {
            duplicates = duplicateGroups
            isScanning = false
        }
    }
    
    private func computeFileHash(_ url: URL) async -> String {
        do {
            let data = try Data(contentsOf: url)
            var hash = 0
            
            for byte in data {
                hash = hash &+ Int(byte)
            }
            
            return "\(hash)-\(data.count)"
        } catch {
            return UUID().uuidString
        }
    }
    
    func deleteDuplicates(keepNewest: Bool, in group: DuplicateGroup) {
        let filesToDelete: [DuplicateFile]
        
        if keepNewest {
            filesToDelete = Array(group.files.dropFirst())
        } else {
            filesToDelete = Array(group.files.dropLast())
        }
        
        for file in filesToDelete {
            do {
                try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
            } catch {
                print("Error deleting \(file.url): \(error)")
            }
        }
    }
    
    func deleteAllDuplicates(keepNewest: Bool) {
        for group in duplicates {
            deleteDuplicates(keepNewest: keepNewest, in: group)
        }
    }
}
