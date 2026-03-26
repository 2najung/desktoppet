import SwiftUI

struct TodoView: View {
    @ObservedObject var todoStore: TodoStore
    @ObservedObject var petManager: PetManager
    @State private var newTodoText = ""
    var onBack: () -> Void

    var pending: [TodoItem] { todoStore.items.filter { !$0.isDone } }
    var done: [TodoItem] { todoStore.items.filter { $0.isDone } }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12))
                        Text("뒤로")
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Text("할 일")
                    .font(.system(size: 13, weight: .bold, design: .rounded))

                Spacer()

                Text(todoStore.pendingCount > 0 ? "\(todoStore.pendingCount)개 남음" : "모두 완료!")
                    .font(.system(size: 10))
                    .foregroundColor(todoStore.pendingCount == 0 ? .green : .secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // 입력창
            HStack(spacing: 8) {
                TextField("새 할 일 추가...", text: $newTodoText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onSubmit { addTodo() }

                Button(action: addTodo) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(newTodoText.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue)
                }
                .buttonStyle(.plain)
                .disabled(newTodoText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider()

            // 목록
            if todoStore.items.isEmpty {
                VStack(spacing: 8) {
                    Text("😊")
                        .font(.system(size: 36))
                    Text("할 일이 없어요!")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(pending) { item in
                            TodoRow(item: item, todoStore: todoStore, petManager: petManager)
                        }

                        if !done.isEmpty {
                            HStack(spacing: 6) {
                                Text("완료됨")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.3))
                                    .frame(height: 0.5)
                            }
                            .padding(.horizontal, 4)
                            .padding(.top, 8)

                            ForEach(done) { item in
                                TodoRow(item: item, todoStore: todoStore, petManager: petManager)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    func addTodo() {
        let text = newTodoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        todoStore.add(title: text)
        newTodoText = ""
    }
}

struct TodoRow: View {
    let item: TodoItem
    @ObservedObject var todoStore: TodoStore
    @ObservedObject var petManager: PetManager

    var body: some View {
        HStack(spacing: 10) {
            Button(action: {
                let wasDone = item.isDone
                todoStore.toggle(id: item.id)
                if !wasDone {
                    petManager.completedTodo()
                }
            }) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(item.isDone ? .green : .gray)
            }
            .buttonStyle(.plain)

            Text(item.title)
                .font(.system(size: 12))
                .foregroundColor(item.isDone ? .secondary : .primary)
                .strikethrough(item.isDone)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: { todoStore.delete(id: item.id) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(item.isDone ? Color.green.opacity(0.05) : Color.gray.opacity(0.04))
        )
    }
}
