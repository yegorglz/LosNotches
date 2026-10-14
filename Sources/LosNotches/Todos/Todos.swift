import NookCore
import SwiftUI

@MainActor
@Observable
final class TodoStore {
    private(set) var list: TodoList
    @ObservationIgnored private let store: JSONFileStore<TodoList>
    @ObservationIgnored private var timer: Timer?

    init(directory: URL) {
        store = JSONFileStore(url: directory.appendingPathComponent("todos.json")) { TodoList() }
        list = store.load()
        archive()
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.archive() } }
    }

    func mutate(_ f: (inout TodoList) -> Void) {
        f(&list)
        try? store.save(list)
    }

    private func archive() { mutate { $0.archiveCompleted(now: Date()) } }
}

struct TodoWidgetView: View {
    let model: NotchViewModel
    private var store: TodoStore { AppServices.shared.todos }
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { WidgetHeader(title: "To-dos"); Spacer() }
            TextField("Add a to-do", text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 7).fill(.white.opacity(0.08)))
                .focused($focused)
                .onSubmit {
                    store.mutate { $0.add(title: draft, now: Date()) }
                    draft = ""
                    focused = true
                }
                .onChange(of: focused) { _, f in model.textFieldFocused(f) }
            let items = store.list.visible()
            if items.isEmpty {
                Text("Nothing to do. Enjoy!").font(.system(size: 10)).opacity(0.4).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 4) { ForEach(items) { TodoRow(item: $0) } }
                }
            }
        }
    }
}

struct TodoRow: View {
    let item: TodoItem
    private var store: TodoStore { AppServices.shared.todos }

    var body: some View {
        let done = item.completedAt != nil
        HStack(spacing: 6) {
            Button { withAnimation(.nook) { store.mutate { $0.toggleComplete(id: item.id, now: Date()) } } } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle").font(.system(size: 12))
            }
            Text(item.title).font(.system(size: 11)).strikethrough(done).opacity(done ? 0.45 : 1).lineLimit(1)
            Spacer(minLength: 0)
            Button { store.mutate { $0.toggleStar(id: item.id) } } label: {
                Image(systemName: item.isStarred ? "star.fill" : "star").font(.system(size: 10))
                    .foregroundStyle(item.isStarred ? .yellow : .white.opacity(0.4))
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .contextMenu {
            Button(item.isStarred ? "Unstar" : "Star") { store.mutate { $0.toggleStar(id: item.id) } }
            Button("Delete", role: .destructive) { withAnimation(.nook) { store.mutate { $0.delete(id: item.id) } } }
        }
    }
}
