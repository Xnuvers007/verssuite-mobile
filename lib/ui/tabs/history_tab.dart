import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/http_models.dart';
import '../../state/app_state.dart';
import '../pages/flow_detail_page.dart';

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final appState = context.watch<AppState>();
    final flows = appState.filteredFlows;

    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                Text(
                  l.tr('history'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (flows.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => appState.clearFlows(),
                    tooltip: l.tr('clear_history'),
                  ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: appState.setSearchQuery,
              decoration: InputDecoration(
                hintText: l.tr('search'),
                prefixIcon: Icon(Icons.search, size: 20, color: Colors.white.withValues(alpha: 0.4)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),

          // Flow list
          Expanded(
            child: flows.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.wifi_tethering_off,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l.tr('no_flows'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: flows.length,
                    itemBuilder: (context, index) {
                      return _FlowTile(flow: flows[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FlowTile extends StatelessWidget {
  final HttpFlow flow;
  const _FlowTile({required this.flow});

  Color _methodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET': return const Color(0xFF00D4AA);
      case 'POST': return const Color(0xFF6C63FF);
      case 'PUT': return const Color(0xFFFFAA33);
      case 'DELETE': return const Color(0xFFFF6B6B);
      case 'PATCH': return const Color(0xFF00BFFF);
      default: return Colors.white70;
    }
  }

  Color _statusColor(int? code) {
    if (code == null) return Colors.white38;
    if (code >= 200 && code < 300) return const Color(0xFF00D4AA);
    if (code >= 300 && code < 400) return const Color(0xFFFFAA33);
    if (code >= 400 && code < 500) return const Color(0xFFFF6B6B);
    if (code >= 500) return const Color(0xFFFF4444);
    return Colors.white38;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => FlowDetailPage(flow: flow)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Method badge
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: _methodColor(flow.request.method).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  flow.request.method,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _methodColor(flow.request.method),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // URL and host
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      flow.displayUrl,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (flow.isHttps)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(Icons.lock, size: 10, color: Colors.white.withValues(alpha: 0.3)),
                          ),
                        Text(
                          flow.request.host,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Status + size + time
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    flow.statusDisplay,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _statusColor(flow.response?.statusCode),
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${flow.sizeDisplay} · ${flow.durationDisplay}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
