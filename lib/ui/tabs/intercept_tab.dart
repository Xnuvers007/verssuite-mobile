import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/http_models.dart';
import '../../state/app_state.dart';

class InterceptTab extends StatefulWidget {
  const InterceptTab({super.key});

  @override
  State<InterceptTab> createState() => _InterceptTabState();
}

class _InterceptTabState extends State<InterceptTab> {
  final TextEditingController _editController = TextEditingController();

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final appState = context.watch<AppState>();
    final queue = appState.interceptQueue;

    return SafeArea(
      child: Column(
        children: [
          // Header with toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Text(
                  l.tr('intercept'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                // Intercept toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: appState.interceptEnabled
                        ? const Color(0xFFFF6B6B).withValues(alpha: 0.15)
                        : const Color(0xFF00D4AA).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: appState.interceptEnabled
                          ? const Color(0xFFFF6B6B).withValues(alpha: 0.3)
                          : const Color(0xFF00D4AA).withValues(alpha: 0.3),
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      appState.setInterceptEnabled(!appState.interceptEnabled);
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          appState.interceptEnabled
                              ? Icons.pause_circle
                              : Icons.play_circle,
                          size: 16,
                          color: appState.interceptEnabled
                              ? const Color(0xFFFF6B6B)
                              : const Color(0xFF00D4AA),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          appState.interceptEnabled
                              ? l.tr('intercept_on')
                              : l.tr('intercept_off'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: appState.interceptEnabled
                                ? const Color(0xFFFF6B6B)
                                : const Color(0xFF00D4AA),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Content
          Expanded(
            child: queue.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          appState.interceptEnabled
                              ? Icons.hourglass_empty
                              : Icons.pause_circle_outline,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          appState.interceptEnabled
                              ? l.tr('no_intercepted')
                              : l.tr('intercept_off'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : _InterceptedRequestView(
                    flow: queue.first,
                    editController: _editController,
                    l: l,
                  ),
          ),
        ],
      ),
    );
  }
}

class _InterceptedRequestView extends StatefulWidget {
  final HttpFlow flow;
  final TextEditingController editController;
  final AppLocalizations l;

  const _InterceptedRequestView({
    required this.flow,
    required this.editController,
    required this.l,
  });

  @override
  State<_InterceptedRequestView> createState() => _InterceptedRequestViewState();
}

class _InterceptedRequestViewState extends State<_InterceptedRequestView> {
  @override
  void initState() {
    super.initState();
    widget.editController.text = widget.flow.request.toRaw();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();

    return Column(
      children: [
        // Request info header
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.flow.request.method,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6C63FF),
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.flow.request.url,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Editable raw request
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: TextField(
                controller: widget.editController,
                maxLines: null,
                expands: true,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.5,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Forward / Drop buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      appState.dropIntercepted(widget.flow);
                    },
                    icon: const Icon(Icons.block, size: 18),
                    label: Text(widget.l.tr('drop')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B6B).withValues(alpha: 0.2),
                      foregroundColor: const Color(0xFFFF6B6B),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final modified = ProxyRequest.fromRaw(
                        widget.editController.text,
                      );
                      appState.forwardIntercepted(widget.flow, modified: modified);
                    },
                    icon: const Icon(Icons.send, size: 18),
                    label: Text(widget.l.tr('forward')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D4AA),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
