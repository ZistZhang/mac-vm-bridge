import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';
import '../models/document_job.dart';
import '../widgets/job_card.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final theme = Theme.of(context);
    final jobs = controller.jobs.where((job) {
      return switch (_filter) {
        'active' => !{JobStatus.completed, JobStatus.failed, JobStatus.cancelled}.contains(job.status),
        'completed' => job.status == JobStatus.completed,
        'failed' => job.status == JobStatus.failed,
        _ => true,
      };
    }).toList();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 18),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 18,
                      runSpacing: 12,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '任务中心',
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${controller.jobs.length} 个任务 · ${controller.runningCount} 个正在运行',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'all', label: Text('全部')),
                            ButtonSegment(value: 'active', label: Text('进行中')),
                            ButtonSegment(value: 'completed', label: Text('完成')),
                            ButtonSegment(value: 'failed', label: Text('失败')),
                          ],
                          selected: {_filter},
                          onSelectionChanged: (value) => setState(() => _filter = value.first),
                          showSelectedIcon: false,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: jobs.isEmpty
                ? _EmptyJobs(hasAny: controller.jobs.isNotEmpty)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 42),
                    itemCount: jobs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1120),
                          child: JobCard(job: jobs[index]),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyJobs extends StatelessWidget {
  const _EmptyJobs({required this.hasAny});

  final bool hasAny;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 58, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              hasAny ? '当前筛选没有任务' : '尚未创建转换任务',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.read<AppController>().setNavigationIndex(0),
              child: const Text('返回导入文档'),
            ),
          ],
        ),
      ),
    );
  }
}
