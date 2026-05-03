import SwiftUI

struct FlashCardView: View {
    @StateObject private var cardService = FlashCardService.shared
    @State private var showAddSheet = false
    @State private var selectedCard: FlashCard?
    @State private var isFlipped = false
    
    @State private var newFront = ""
    @State private var newBack = ""
    @State private var newCategory = ""
    
    var cardsForReview: [FlashCard] {
        cardService.getCardsForReview()
    }
    
    var categories: [String] {
        Array(Set(cardService.cards.map { $0.category })).sorted()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider()
            
            if cardsForReview.isEmpty && cardService.cards.isEmpty {
                emptyStateView
            } else if cardService.cards.isEmpty {
                noCardsForReviewView
            } else {
                reviewModeView
            }
        }
        .sheet(isPresented: $showAddSheet) {
            addCardSheet
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("背诵卡片")
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            Text("\(cardService.cards.count) 张卡片")
                .foregroundColor(.secondary)
            
            Button {
                showAddSheet = true
            } label: {
                Label("添加", systemImage: "plus")
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "rectangle.stack")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("还没有背诵卡片")
                .font(.headline)
            
            Text("点击上方按钮添加卡片")
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    private var noCardsForReviewView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "checkmark.circle")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("太棒了！")
                .font(.headline)
            
            Text("今天的学习任务已完成")
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    private var reviewModeView: some View {
        VStack(spacing: 20) {
            if let card = selectedCard {
                cardFlashCardView(card)
            } else {
                cardListView
            }
        }
        .padding()
    }
    
    private func cardFlashCardView(_ card: FlashCard) -> some View {
        VStack(spacing: 20) {
            Button {
                withAnimation {
                    isFlipped.toggle()
                }
            } label: {
                VStack(spacing: 16) {
                    if isFlipped {
                        VStack {
                            Text("答案")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text(card.back)
                                .font(.title3)
                                .multilineTextAlignment(.center)
                        }
                    } else {
                        VStack {
                            Text("问题")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(card.front)
                                .font(.title3)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(16)
            }
            .buttonStyle(.plain)
            
            if isFlipped {
                masteryButtons(for: card)
            }
            
            Button("返回列表") {
                selectedCard = nil
                isFlipped = false
            }
            .buttonStyle(.bordered)
        }
    }
    
    private func masteryButtons(for card: FlashCard) -> some View {
        HStack(spacing: 12) {
            ForEach(MasteryLevel.allCases, id: \.self) { level in
                Button {
                    var updated = card
                    updated.updateMastery(level)
                    cardService.updateCard(updated)
                    isFlipped = false
                } label: {
                    Text(level.rawValue)
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var cardListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    DisclosureGroup(category) {
                        ForEach(cardService.getCardsByCategory(category)) { card in
                            FlashCardRow(card: card) {
                                selectedCard = card
                            } onDelete: {
                                cardService.deleteCard(card)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private var addCardSheet: some View {
        VStack(spacing: 20) {
            Text("添加背诵卡片")
                .font(.headline)
            
            Form {
                TextField("正面（问题/名词）", text: $newFront, axis: .vertical)
                    .lineLimit(2...4)
                
                TextField("背面（答案/解释）", text: $newBack, axis: .vertical)
                    .lineLimit(3...6)
                
                TextField("分类", text: $newCategory)
            }
            .formStyle(.grouped)
            
            HStack {
                Button("取消") {
                    resetForm()
                    showAddSheet = false
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("添加") {
                    addCard()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newFront.isEmpty || newBack.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 350)
    }
    
    private func addCard() {
        let card = FlashCard(
            front: newFront,
            back: newBack,
            category: newCategory.isEmpty ? "未分类" : newCategory
        )
        
        cardService.addCard(card)
        resetForm()
        showAddSheet = false
    }
    
    private func resetForm() {
        newFront = ""
        newBack = ""
        newCategory = ""
    }
}

struct FlashCardRow: View {
    let card: FlashCard
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(card.front)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(card.back)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(masteryText)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(masteryColor.opacity(0.2))
                .cornerRadius(4)
            
            Button {
                onTap()
            } label: {
                Image(systemName: "book")
            }
            .buttonStyle(.bordered)
            
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding(.vertical, 4)
    }
    
    private var masteryText: String {
        switch card.masteryLevel {
        case .notReviewed: return "未复习"
        case .completelyForgotten: return "忘记"
        case .rememberWithDifficulty: return "困难"
        case .rememberWithEase: return "记住"
        case .completelyMastered: return "掌握"
        }
    }
    
    private var masteryColor: Color {
        switch card.masteryLevel {
        case .notReviewed: return .gray
        case .completelyForgotten: return .red
        case .rememberWithDifficulty: return .orange
        case .rememberWithEase: return .blue
        case .completelyMastered: return .green
        }
    }
}
