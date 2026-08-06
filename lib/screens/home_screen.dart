import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';
import '../models/document_job.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _dragging = false;

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'doc',
        'docx',
        'ppt',
        'pptx',
        'xls',
        'xlsx',
        'png',
        'jpg',
        'jpeg',
        'webp',
        'bmp',
        'gif',
        'html',
      ],
      withData: false,
    );
    final paths = result?.files.map((file) => file.path).whereType<String>().toList();
    if (paths != null && paths.isNotEmpty && mounted) {
      await context.read<AppController>().importPaths(paths);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final theme = Theme.of(context);
    final recent = controller.jobs.take(3).toList();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 42),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '文档直接交给 Agent',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '自动拆分超长 PDF、可靠调用 MinerU、合并 Markdown 与图片。',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    _StatusPill(
                      icon: controller.tokens.isEmpty
                          ? Icons.key_off_outlined
                          : Icons.verified_user_outlined,
                      text: controller.tokens.isEmpty
                          ? '尚未配置 Token'
                          : '${controller.tokens.length} 个 Token 可用',
                      warning: controller.tokens.isEmpty,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                DropTarget(
                  onDragEntered: (_) => setState(() => _dragging = true),
                  onDragExited: (_) => setState(() => _dragging = false),
                  onDragDone: (detail) async {
                    setState(() => _dragging = false);
                    await context
                        .read<AppController>()
                        .importPaths(detail.files.map((file) => file.path).toList());
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 54),
                    decoration: BoxDecoration(
                      color: _dragging
                          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.7)
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: _dragging
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        width: _dragging ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 32,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F766E), Color(0xFF2DD4BF)],
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(
                            Icons.upload_file_rounded,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          _dragging ? '松开以导入文件' : '拖入文档，或从设备选择',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'PDF、Office、图片与 HTML；PDF 超过 200 页会自动拆分。',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: controller.importing ? null : _pickFiles,
                          icon: controller.importing
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.folder_open_rounded),
                          label: Text(controller.importing ? '正在导入' : '选择文件'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 760;
                    final cards = [
                      const _FeatureCard(
                        icon: Icons.cut_rounded,
                        title: '双限制拆分',
                        text: '同时控制页数和实际文件体积；超大分片会继续二分。',
                      ),
                      const _FeatureCard(
                        icon: Icons.restart_alt_rounded,
                        title: '断点恢复',
                        text: '保存 batch ID、Token 归属和每个分片状态，重启后继续。',
                      ),
                      const _FeatureCard(
                        icon: Icons.auto_awesome_rounded,
                        title: 'Agent 成品包',
                        text: '输出合并 Markdown、图片、清单和读取说明，可直接分享。',
                      ),
                    ];
                    if (narrow) {
                      return Column(
                        children: cards
                            .map(
                              (card) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: card,
                              ),
                            )
                            .toList(),
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: cards
                          .map(
                            (card) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: card,
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                if (recent.isNotEmpty) ...[
                  const SizedBox(height: 34),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '最近任务',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      TextButton(
                        onPressed: () => controller.setNavigationIndex(1),
                        child: const Text('查看全部'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...recent.map((job) => _RecentJob(job: job)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.text, required this.warning});

  final IconData icon;
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = warning ? theme.colorScheme.error : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    text,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.45),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentJob extends StatelessWidget {
  const _RecentJob({required this.job});

  final DocumentJob job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(Icons.description_outlined, color: theme.colorScheme.primary),
          ),
          title: Text(job.originalName, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: LinearProgressIndicator(value: job.progress),
          ),
          trailing: Text(_statusLabel(job.status)),
          onTap: () => context.read<AppController>().setNavigationIndex(1),
        ),
      ),
    );
  }
}

String _statusLabel(JobStatus status) => switch (status) {
      JobStatus.queued => '等待',
      JobStatus.preparing => '准备中',
      JobStatus.uploading => '上传中',
      JobStatus.parsing => '解析中',
      JobStatus.downloading => '下载中',
      JobStatus.merging => '合并中',
      JobStatus.completed => '已完成',
      JobStatus.paused => '可继续',
      JobStatus.failed => '失败',
      JobStatus.cancelled => '已取消',
    };
