import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_strings.dart';
import '../models/activity.dart';
import '../services/pb_service.dart';
import '../utils/formatters.dart';

class ActivityLogScreen extends ConsumerStatefulWidget {
  final String bookId;
  final String bookName;
  const ActivityLogScreen({super.key, required this.bookId, required this.bookName});

  @override
  ConsumerState<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends ConsumerState<ActivityLogScreen> {
  final _scrollCtrl = ScrollController();
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  final _activities = <Activity>[];

  @override
  void initState() {
    super.initState();
    _load();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200 && _hasMore && !_loading) {
        _load();
      }
    });
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final result = await PbService.instance.getActivityLog(widget.bookId, page: _page);
      setState(() {
        _activities.addAll(result);
        _page++;
        _hasMore = _activities.length >= 50;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppStrings.tr('activity_log_unavailable').replaceAll('{error}', '$e')),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  IconData _iconFor(String entityType, String action) {
    if (action == 'deleted') return Icons.delete_outline;
    if (entityType == 'transaction') return Icons.receipt_long;
    if (entityType == 'book') return action == 'deleted' ? Icons.delete_outline : Icons.book;
    if (entityType == 'member') return Icons.person;
    if (entityType == 'category') return Icons.category;
    return Icons.circle;
  }

  Color _colorFor(String action) {
    if (action == 'created') return Colors.green;
    if (action == 'deleted') return Colors.red;
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr('activities_title').replaceAll('{book}', widget.bookName)),
      ),
      body: _activities.isEmpty && !_loading
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.history, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(AppStrings.tr('no_activities_yet'), style: TextStyle(color: Colors.grey.shade600)),
            ]))
          : ListView.builder(
              controller: _scrollCtrl,
              itemCount: _activities.length + (_loading ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i >= _activities.length) {
                  return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                }
                final a = _activities[i];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: _colorFor(a.action).withValues(alpha: 0.15),
                    child: Icon(_iconFor(a.entityType, a.action), size: 18, color: _colorFor(a.action)),
                  ),
                  title: Text('${a.entityLabel} ${a.actionLabel}', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                  subtitle: Text.rich(TextSpan(children: [
                    if (a.details.isNotEmpty)
                      TextSpan(text: a.details, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (a.details.isNotEmpty && a.userEmail.isNotEmpty)
                      const TextSpan(text: ' · '),
                    if (a.userEmail.isNotEmpty)
                      TextSpan(text: a.userEmail),
                    TextSpan(text: ' · ${_timeAgo(a.createdAt)}'),
                  ]), style: const TextStyle(fontSize: 12)),
                  dense: true,
                );
              },
            ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return AppStrings.tr('time_just_now');
    if (diff.inMinutes < 60) return AppStrings.tr('time_minutes_ago').replaceAll('{n}', '${diff.inMinutes}');
    if (diff.inHours < 24) return AppStrings.tr('time_hours_ago').replaceAll('{n}', '${diff.inHours}');
    if (diff.inDays < 7) return AppStrings.tr('time_days_ago').replaceAll('{n}', '${diff.inDays}');
    return formatDate(dt);
  }
}
