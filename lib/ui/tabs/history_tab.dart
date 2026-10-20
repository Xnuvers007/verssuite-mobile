import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/http_models.dart';
import '../../state/app_state.dart';
import '../pages/flow_detail_page.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  HttpFlow? _selectedFlow;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final appState = context.watch<AppState>();
    final flows = appState.filteredFlows;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;

        // Automatically sync selectedFlow if list changed
        if (_selectedFlow != null && !flows.contains(_selectedFlow)) {
          _selectedFlow = flows.isNotEmpty ? flows.first : null;
        }

        final flowListView = Column(
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
                  const SizedBox(width: 8),
                  if (flows.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${flows.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6C63FF),
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (flows.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () {
                        setState(() => _selectedFlow = null);
                        appState.clearFlows();
                      },
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
                        final flow = flows[index];
                        final isSelected = isWide && _selectedFlow == flow;
                        return _FlowTile(
                          flow: flow,
                          isSelected: isSelected,
                          onTap: () {
                            if (isWide) {
                              setState(() => _selectedFlow = flow);
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FlowDetailPage(flow: flow),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        );

        if (!isWide) {
          return SafeArea(child: flowListView);
        }

        // ─── Tablet / iPad / Laptop / TV Master-Detail Layout ───
        return SafeArea(
          child: Row(
            children: [
              // Left Column: Master list
              SizedBox(
                width: 360,
                child: flowListView,
              ),
              const VerticalDivider(thickness: 1, width: 1, color: Colors.white10),
              // Right Column: Detail Inspector
              Expanded(
                child: _selectedFlow != null
                    ? FlowDetailPage(
                        key: ValueKey(_selectedFlow!.id),
                        flow: _selectedFlow!,
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
                              ),
                              child: const Icon(
                                Icons.ads_click,
                                size: 32,
                                color: Color(0xFF6C63FF),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l.tr('master_detail_detail'),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FlowTile extends StatelessWidget {
  final HttpFlow flow;
  final bool isSelected;
  final VoidCallback onTap;

  const _FlowTile({
    required this.flow,
    this.isSelected = false,
    required this.onTap,
  });

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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected
              ? const Color(0xFF6C63FF)
              : Colors.white.withValues(alpha: 0.06),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      color: isSelected
          ? const Color(0xFF6C63FF).withValues(alpha: 0.12)
          : const Color(0xFF1A1A2E),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
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

              // Host & Path
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (flow.isHttps)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.lock, size: 11, color: Color(0xFF00D4AA)),
                          ),
                        Expanded(
                          child: Text(
                            flow.request.host,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      flow.request.path.isEmpty ? '/' : flow.request.path,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.5),
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Status & Size
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (flow.response != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _statusColor(flow.response!.statusCode).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${flow.response!.statusCode}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _statusColor(flow.response!.statusCode),
                          fontFamily: 'monospace',
                        ),
                      ),
                    )
                  else if (flow.state == FlowState.intercepted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFAA33).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PAUSED',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFFAA33),
                        ),
                      ),
                    )
                  else
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF6C63FF)),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    flow.response?.formattedSize ?? '',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.4),
                      fontFamily: 'monospace',
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
