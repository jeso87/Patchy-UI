import PatchyKit

/// Text the app matches in what Patchy and Apache print. This is their own English, not copy:
/// never localize it, or matching silently stops working in every other language. Patchy's
/// failures are matched by `PatchyError` codes, which stay the same between releases; only log
/// lines are still matched as text.
enum PatchyOutput {
    // Log lines.
    static let fatal = "Fatal"

    static let all = [fatal]
}
