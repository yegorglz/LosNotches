import AppKit
import NookCore
import SwiftUI

@MainActor
@Observable
final class NotesStore {
    private(set) var book: NoteBook
    var selectedID: UUID?
    @ObservationIgnored private let store: JSONFileStore<NoteBook>
    @ObservationIgnored private lazy var saver = DebouncedSaver<NoteBook>(delay: 0.5) { [store] in try? store.save($0) }

    init(directory: URL) {
        store = JSONFileStore(url: directory.appendingPathComponent("notes.json")) { NoteBook() }
        book = store.load()
        selectedID = book.sorted().first?.id
    }

    var selected: Note? { book.notes.first { $0.id == selectedID } }

    func mutate(_ f: (inout NoteBook) -> Void) {
        f(&book)
        saver.submit(book)
    }

    func create() {
        var id: UUID?
        mutate { id = $0.create(now: Date()).id }
        selectedID = id
        saver.flush()
    }

    func deleteSelected() {
        guard let id = selectedID else { return }
        mutate { $0.delete(id: id) }
        selectedID = book.sorted().first?.id
        saver.flush()
    }

    func flush() { saver.flush() }
}

struct NotesWidgetView: View {
    let model: NotchViewModel
    private var store: NotesStore { AppServices.shared.notes }
    @State private var editor = RichTextController()

    var body: some View {
        HStack(spacing: 6) {
            VStack(spacing: 4) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(store.book.sorted()) { n in
                            Button { store.selectedID = n.id } label: {
                                Text(n.title).font(.system(size: 9, weight: .medium)).lineLimit(2).multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, minHeight: 28, alignment: .topLeading).padding(4)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(store.selectedID == n.id ? 0.18 : 0.06)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                HStack(spacing: 2) {
                    Button { store.create() } label: { Image(systemName: "plus") }
                    Button { store.deleteSelected() } label: { Image(systemName: "trash") }.disabled(store.selected == nil)
                }
                .buttonStyle(NookButtonStyle()).font(.system(size: 9))
            }
            .frame(width: 60)
            if let note = store.selected {
                VStack(spacing: 4) {
                    HStack(spacing: 2) {
                        if !note.isCodeMode {
                            Button { editor.toggle(.bold) } label: { Image(systemName: "bold") }
                            Button { editor.toggle(.italic) } label: { Image(systemName: "italic") }
                            Button { editor.toggle(.underline) } label: { Image(systemName: "underline") }
                        }
                        Spacer()
                        Button { store.mutate { $0.toggleCodeMode(id: note.id) } } label: { Image(systemName: "chevron.left.forwardslash.chevron.right") }
                            .help("Code mode")
                    }
                    .buttonStyle(NookButtonStyle()).font(.system(size: 9))
                    RichTextEditor(note: note, controller: editor,
                                   onChange: { rtf, text in store.mutate { $0.update(id: note.id, rtf: rtf, plainText: text, now: Date()) } },
                                   onFocus: { model.textFieldFocused($0) })
                        .id(note.id)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.06)))
                }
            } else {
                VStack(spacing: 6) {
                    Text("The note flew away.").font(.system(size: 10)).opacity(0.4)
                    Button("New note") { store.create() }.buttonStyle(NookButtonStyle()).font(.system(size: 10))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

/// Lets toolbar buttons reach the live NSTextView.
final class RichTextController {
    enum Style { case bold, italic, underline }
    weak var textView: NSTextView?

    func toggle(_ style: Style) {
        guard let tv = textView, tv.isRichText else { return }
        let range = tv.selectedRange()
        guard let storage = tv.textStorage else { return }
        if range.length == 0 {
            var attrs = tv.typingAttributes
            apply(style, to: &attrs)
            tv.typingAttributes = attrs
            return
        }
        storage.beginEditing()
        storage.enumerateAttributes(in: range) { attrs, sub, _ in
            var a = attrs
            apply(style, to: &a)
            storage.setAttributes(a, range: sub)
        }
        storage.endEditing()
        tv.didChangeText()
    }

    private func apply(_ style: Style, to a: inout [NSAttributedString.Key: Any]) {
        let font = a[.font] as? NSFont ?? .systemFont(ofSize: 12)
        let fm = NSFontManager.shared
        switch style {
        case .bold:
            a[.font] = fm.traits(of: font).contains(.boldFontMask) ? fm.convert(font, toNotHaveTrait: .boldFontMask) : fm.convert(font, toHaveTrait: .boldFontMask)
        case .italic:
            a[.font] = fm.traits(of: font).contains(.italicFontMask) ? fm.convert(font, toNotHaveTrait: .italicFontMask) : fm.convert(font, toHaveTrait: .italicFontMask)
        case .underline:
            let on = (a[.underlineStyle] as? Int ?? 0) != 0
            a[.underlineStyle] = on ? 0 : NSUnderlineStyle.single.rawValue
        }
    }
}

struct RichTextEditor: NSViewRepresentable {
    let note: Note
    let controller: RichTextController
    let onChange: (Data, String) -> Void
    let onFocus: (Bool) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = false
        let tv = FocusTextView(frame: .zero)
        tv.minSize = .zero
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        tv.onFocus = { [weak coordinator = context.coordinator] f in coordinator?.parent.onFocus(f) }
        scroll.documentView = tv
        tv.delegate = context.coordinator
        tv.allowsUndo = true
        tv.drawsBackground = false
        tv.textContainerInset = NSSize(width: 4, height: 4)
        tv.insertionPointColor = .white
        configure(tv)
        if !note.rtf.isEmpty, let s = NSAttributedString(rtf: note.rtf, documentAttributes: nil) {
            tv.textStorage?.setAttributedString(s)
        } else {
            tv.string = note.plainText
        }
        if note.isCodeMode { tv.font = Self.codeFont }
        controller.textView = tv
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let tv = scroll.documentView as? NSTextView else { return }
        context.coordinator.parent = self
        controller.textView = tv
        if tv.isRichText == note.isCodeMode {
            configure(tv)
            if note.isCodeMode { tv.font = Self.codeFont } else { tv.font = Self.textFont }
        }
    }

    private func configure(_ tv: NSTextView) {
        tv.isRichText = !note.isCodeMode
        tv.isAutomaticQuoteSubstitutionEnabled = !note.isCodeMode
        tv.isAutomaticDashSubstitutionEnabled = !note.isCodeMode
        tv.textColor = .white
        tv.typingAttributes = [.font: note.isCodeMode ? Self.codeFont : Self.textFont, .foregroundColor: NSColor.white]
    }

    static let textFont = NSFont.systemFont(ofSize: 12)
    static let codeFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditor
        init(_ p: RichTextEditor) { parent = p }

        func textDidChange(_ n: Notification) {
            guard let tv = n.object as? NSTextView, let storage = tv.textStorage else { return }
            let rtf = storage.rtf(from: NSRange(location: 0, length: storage.length), documentAttributes: [:]) ?? Data()
            parent.onChange(rtf, tv.string)
        }
    }
}

/// Reports focus changes so the Nook stays open while typing.
final class FocusTextView: NSTextView {
    var onFocus: ((Bool) -> Void)?
    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok { onFocus?(true) }
        return ok
    }
    override func resignFirstResponder() -> Bool {
        let ok = super.resignFirstResponder()
        if ok { onFocus?(false) }
        return ok
    }
}
