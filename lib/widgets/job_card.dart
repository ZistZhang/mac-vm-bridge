import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../controllers/app_controller.dart';
import '../models/document_job.dart';
import '../utils/file_utils.dart';

class JobCard extends StatefulWidget {
  const JobCard({super.key, required this.job});

  final DocumentJob job;

  @override
  State<JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<JobCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final theme = Theme.of(context);
    final controller = context.read<AppController>();
    final running = controller.runningCount > 0 &&
        !{JobStatus.completed, JobStatus.failed, JobStatus.cancelled, JobStatus.paused}.contains(job.status);
    final statusColor = _statusColor(theme, job.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(_fileIcon(job.originalName), color: statusColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.originalName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Text(
                            _statusLabel(job.status),
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.w700),
                          ),
                          if (job.totalPages != null) Text('${job.totalPages} 页'),
                          if (job.chunks.isNotEmpty)
                            Text('${job.completedChunks}/${job.chunks.length} 分片'),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'delete') await controller.deleteJob(job.id);
                    if (value == 'cancel') await controller.cancelJob(job.id);
                  },
                  itemBuilder: (context) => [
                    if (running) const PopupMenuItem(value: 'cancel', child: Text('取消任务')),
                    const PopupMenuItem(value: 'delete', child: Text('删除记录和本地文件')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: job.progress,
                minHeight: 9,
                color: statusColor,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            if (job.error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  job.error!,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 9,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if ({JobStatus.queued, JobStatus.paused, JobStatus.cancelled}.contains(job.status))
                  FilledButton.icon(
                    onPressed: () => controller.startJob(job.id),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('开始/继续'),
                  ),
                if (job.status == JobStatus.failed)
                  FilledButton.icon(
                    onPressed: () => controller.retryJob(job.id),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('重试失败分片'),
                  ),
                if (job.status == JobStatus.completed && job.packageZipPath != null) ...[
                  FilledButton.icon(
                    onPressed: () => _share(context, job.packageZipPath!),
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('分享 Agent 包'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => OpenFilex.open(job.packageZipPath!),
                    icon: const Icon(Icons.folder_zip_outlined),
                    label: const Text('打开 ZIP'),
                  ),
                  if (job.outputDirectory != null)
                    OutlinedButton.icon(
                      onPressed: () => OpenFilex.open(
                        p.join(job.outputDirectory!, 'document.md'),
                      ),
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('打开 Markdown'),
                    ),
                ],
                TextButton.icon(
                  onPressed: job.chunks.isEmpty
                      ? null
                      : () => setState(() => _expanded = !_expanded),
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  label: Text(_expanded ? '收起详情' : '分片详情'),
                ),
              ],
            ),
            if (_expanded) ...[
              const Divider(height: 28),
              ...job.chunks.map((chunk) => _ChunkRow(chunk: chunk)),
              if (job.log.isNotEmpty) ...[
                const SizedBox(height: 12),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('运行日志'),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SelectableText(
                        job.log.reversed.take(50).toList().reversed.join('\n'),
                        style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context, String path) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        text: 'MinerU Flow 生成的 Agent 文档包',
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }
}

class _ChunkRow extends StatelessWidget {
  const _ChunkRow({required this.chunk});

  final DocumentChunk chunk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (chunk.status) {
      ChunkStatus.completed => Colors.green,
      ChunkStatus.failed => theme.colorScheme.error,
      ChunkStatus.uploading || ChunkStatus.waiting || ChunkStatus.parsing || ChunkStatus.downloading =>
        theme.colorScheme.primary,
      ChunkStatus.pending => theme.colorScheme.outline,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: chunk.status == ChunkStatus.completed
                ? Icon(Icons.check_circle, color: color, size: 21)
                : chunk.status == ChunkStatus.failed
                    ? Icon(Icons.error, color: color, size: 21)
                    : CircularProgressIndicator(
                        value: chunk.status == ChunkStatus.pending ? 0 : chunk.progress,
                        strokeWidth: 2.5,
                        color: color,
                      ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '分片 ${chunk.index + 1} · 原始 ${chunk.startPage}-${chunk.endPage} 页 · ${humanBytes(chunk.sizeBytes)}',
            ),
          ),
          Text(_chunkLabel(chunk.status), style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

IconData _fileIcon(String name) {
  final extension = p.extension(name).toLowerCase();
  if (extension == '.pdf') return Icons.picture_as_pdf_outlined;
  if ({'.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp'}.contains(extension)) {
    return Icons.image_outlined;
  }
  if ({'.xls', '.xlsx'}.contains(extension)) return Icons.table_chart_outlined;
  if ({'.ppt', '.pptx'}.contains(extension)) return Icons.slideshow_outlined;
  return Icons.description_outlined;
}

String _statusLabel(JobStatus status) => switch (status) {
      JobStatus.queued => '等待处理',
      JobStatus.preparing => '检查并拆分',
      JobStatus.uploading => '正在上传',
      JobStatus.parsing => 'MinerU 正在解析',
      JobStatus.downloading => '正在下载结果',
      JobStatus.merging => '正在合并 Markdown',
      JobStatus.completed => '处理完成',
      JobStatus.paused => '已保存，可继续',
      JobStatus.failed => '处理失败',
      JobStatus.cancelled => '已取消',
    };

String _chunkLabel(ChunkStatus status) => switch (status) {
      ChunkStatus.pending => '等待',
      ChunkStatus.uploading => '上传',
      ChunkStatus.waiting => '排队',
      ChunkStatus.parsing => '解析',
      ChunkStatus.downloading => '下载',
      ChunkStatus.completed => '完成',
      ChunkStatus.failed => '失败',
    };

Color _statusColor(ThemeData theme, JobStatus status) => switch (status) {
      JobStatus.completed => Colors.green.shade600,
      JobStatus.failed => theme.colorScheme.error,
      JobStatus.cancelled || JobStatus.paused => Colors.orange.shade700,
      _ => theme.colorScheme.primary,
    };
