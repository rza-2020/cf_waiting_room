/// Flutter widget for Cloudflare Waiting Room integration.
///
/// Provides a WebView-based queue gate with:
/// - Automatic waiting room detection via configurable keywords
/// - Native overlay with CF-extracted ETA text
/// - Session timeout callback
/// - Force re-queue flow
/// - Custom UI builder slots
///
/// See [CFWaitingRoomOverlayWidget] and [WaitingRoomConfig] to get started.
library cf_waiting_room;

export 'src/cf_waiting_room_overlay_widget.dart';
export 'src/queue_waiting_info.dart';
export 'src/waiting_room_config.dart';
