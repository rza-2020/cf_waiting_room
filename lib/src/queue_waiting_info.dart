/// Data extracted from the live Cloudflare Waiting Room page.
///
/// Passed to [CFWaitingRoomOverlayWidget.waitingOverlayBuilder] so callers
/// can render the CF-supplied ETA and last-updated text in their own UI.
class QueueWaitingInfo {
  /// The `<h1>` text extracted from the CF waiting room page, or `null` if
  /// extraction failed.
  final String? title;

  /// The ETA text extracted from the element identified by
  /// [WaitingRoomConfig.etaId], or `null` if not found.
  final String? eta;

  /// The last-updated text extracted from the element identified by
  /// [WaitingRoomConfig.lastUpdatedId], or `null` if not found.
  final String? lastUpdated;

  const QueueWaitingInfo({this.title, this.eta, this.lastUpdated});
}
