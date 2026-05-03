import SwiftUI

struct WrongQuestionView: View {
    @StateObject private var questionService = WrongQuestionService.shared
    @State private var showAddSheet = false
    @State private var selectedQuestion: WrongQuestion?
    @State private var isFlipped = false
    
    @State private var newQuestion = ""
    @State private var newCorrectAnswer = ""
    @State private var newStudentAnswer = ""
    @State private var newErrorReason = ""
    @State private var newKnowledgePoints = ""
    @State private var newSubject = ""
    
    var questionsForReview: [WrongQuestion] {
        questionService.getQuestionsForReview()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider()
            
            if questionsForReview.isEmpty {
                emptyStateView
            } else {
                reviewModeView
            }
        }
        .sheet(isPresented: $showAddSheet) {
            addQuestionSheet
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("错题本")
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            Text("\(questionService.questions.count) 道错题")
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
            
            Image(systemName: "checkmark.circle")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("太棒了！")
                .font(.headline)
            
            Text("当前没有需要复习的错题")
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    private var reviewModeView: some View {
        VStack(spacing: 20) {
            if let question = selectedQuestion {
                flashCardView(question)
            } else {
                questionListView
            }
        }
        .padding()
    }
    
    private func flashCardView(_ question: WrongQuestion) -> some View {
        VStack(spacing: 20) {
            Button {
                withAnimation {
                    isFlipped.toggle()
                }
            } label: {
                VStack {
                    if isFlipped {
                        VStack {
                            Text("正确答案")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text(question.correctAnswer)
                                .font(.title3)
                        }
                    } else {
                        VStack {
                            Text("题目")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(question.questionContent)
                                .font(.title3)
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
                masteryButtons(for: question)
            }
            
            Button("返回列表") {
                selectedQuestion = nil
                isFlipped = false
            }
            .buttonStyle(.bordered)
        }
    }
    
    private func masteryButtons(for question: WrongQuestion) -> some View {
        HStack(spacing: 12) {
            ForEach(MasteryLevel.allCases, id: \.self) { level in
                Button {
                    var updated = question
                    updated.updateMastery(level)
                    questionService.updateQuestion(updated)
                    isFlipped = false
                } label: {
                    Text(level.rawValue)
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var questionListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(questionsForReview) { question in
                    QuestionCard(question: question) {
                        selectedQuestion = question
                    } onDelete: {
                        questionService.deleteQuestion(question)
                    }
                }
            }
        }
    }
    
    private var addQuestionSheet: some View {
        VStack(spacing: 20) {
            Text("添加错题")
                .font(.headline)
            
            Form {
                TextField("题目内容", text: $newQuestion, axis: .vertical)
                    .lineLimit(3...6)
                
                TextField("正确答案", text: $newCorrectAnswer, axis: .vertical)
                    .lineLimit(2...4)
                
                TextField("学生答案（可选）", text: $newStudentAnswer, axis: .vertical)
                    .lineLimit(2...4)
                
                TextField("错误原因（可选）", text: $newErrorReason)
                
                TextField("知识点（逗号分隔）", text: $newKnowledgePoints)
                
                TextField("科目", text: $newSubject)
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
                    addQuestion()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newQuestion.isEmpty || newCorrectAnswer.isEmpty)
            }
        }
        .padding()
        .frame(width: 450, height: 500)
    }
    
    private func addQuestion() {
        let question = WrongQuestion(
            questionContent: newQuestion,
            correctAnswer: newCorrectAnswer,
            studentAnswer: newStudentAnswer,
            errorReason: newErrorReason,
            knowledgePoints: newKnowledgePoints.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) },
            subject: newSubject
        )
        
        questionService.addQuestion(question)
        resetForm()
        showAddSheet = false
    }
    
    private func resetForm() {
        newQuestion = ""
        newCorrectAnswer = ""
        newStudentAnswer = ""
        newErrorReason = ""
        newKnowledgePoints = ""
        newSubject = ""
    }
}

struct QuestionCard: View {
    let question: WrongQuestion
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(question.questionContent)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack {
                    if !question.subject.isEmpty {
                        Text(question.subject)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    Text("\(question.reviewCount) 次复习")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button {
                onTap()
            } label: {
                Label("复习", systemImage: "book")
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
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}
