import Foundation

extension SessionSnapshot {
    init(session: LiveSession?, kindName: String) {
        self.init(
            isActive: session != nil,
            equivalent: session?.ledger.sojuEquivalent() ?? 0,
            limit: session?.limit ?? 8,
            kindName: kindName,
            updatedAt: Date()
        )
    }
}
