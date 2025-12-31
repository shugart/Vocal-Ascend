import SwiftUI

struct TargetNotePickerView: View {
    @Binding var selectedNote: Note

    private let visibleNotes: [Note] = Note.supportedRange

    var body: some View {
        VStack(spacing: 8) {
            Text("Target Note")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(visibleNotes, id: \.self) { note in
                        NoteKeyView(
                            note: note,
                            isSelected: note == selectedNote,
                            isSharp: note.isSharp
                        )
                        .onTapGesture {
                            selectedNote = note
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct NoteKeyView: View {
    let note: Note
    let isSelected: Bool
    let isSharp: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(note.displayName)
                .font(.system(size: isSharp ? 12 : 14, weight: isSelected ? .bold : .medium))

            Text("\(note.octave)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: isSharp ? 36 : 44, height: 60)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.2)
        } else if isSharp {
            return Color(.systemGray3)
        } else {
            return Color(.systemGray5)
        }
    }
}

#Preview {
    TargetNotePickerView(selectedNote: .constant(.A4))
        .padding()
}
