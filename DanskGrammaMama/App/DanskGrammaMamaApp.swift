import SwiftUI

@main
struct DanskGrammaMamaApp: App {
    @State private var content = ContentStore()
    @State private var progress = ProgressStore()
    @State private var glossary = Glossary()
    @State private var flashcards = FlashcardStore()
    @State private var vocab = VocabStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(content)
                .environment(progress)
                .environment(glossary)
                .environment(flashcards)
                .environment(vocab)
        }
    }
}
