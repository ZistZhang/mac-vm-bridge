import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';
import '../models/app_settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final settings = controller.settings;
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '设置',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Token 只保存在当前设备的安全凭据库中。',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 22),
                _Section(
                  title: 'MinerU API Token',
                  subtitle: '支持多个 Token。认证失败或限流时按顺序切换。',
                  child: Column(
                    children: [
                      if (controller.tokens.isEmpty)
                        const _EmptyToken()
                      else
                        ...List.generate(controller.tokens.length, (index) {
                          final token = controller.tokens[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.primaryContainer,
                              child: Icon(Icons.key_rounded, color: theme.colorScheme.primary),
                            ),
                            title: Text(token.label),
                            subtitle: Text(_masked(token.value)),
                            trailing: IconButton(
                              tooltip: '移除',
                              onPressed: () => controller.removeToken(index),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          );
                        }),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: () => _showAddToken(context),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('添加 Token'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: '解析参数',
                  subtitle: '这些参数会随每个分片提交给 MinerU v4 API。',
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: settings.modelVersion,
                        decoration: const InputDecoration(labelText: '模型'),
                        items: const [
                          DropdownMenuItem(value: 'vlm', child: Text('VLM（推荐）')),
                          DropdownMenuItem(value: 'pipeline', child: Text('Pipeline')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            controller.updateSettings(settings.copyWith(modelVersion: value));
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: settings.language,
                        decoration: const InputDecoration(labelText: '文档语言'),
                        items: const [
                          DropdownMenuItem(value: 'ch', child: Text('中文 / 混合中文')),
                          DropdownMenuItem(value: 'en', child: Text('English')),
                          DropdownMenuItem(value: 'ja', child: Text('日本語')),
                          DropdownMenuItem(value: 'ko', child: Text('한국어')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            controller.updateSettings(settings.copyWith(language: value));
                          }
                        },
                      ),
                      const SizedBox(height: 4),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('OCR'),
                        subtitle: const Text('扫描件或异常字体文档开启；普通可复制 PDF 通常关闭。'),
                        value: settings.enableOcr,
                        onChanged: (value) =>
                            controller.updateSettings(settings.copyWith(enableOcr: value)),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('公式识别'),
                        value: settings.enableFormula,
                        onChanged: (value) =>
                            controller.updateSettings(settings.copyWith(enableFormula: value)),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('表格识别'),
                        value: settings.enableTable,
                        onChanged: (value) =>
                            controller.updateSettings(settings.copyWith(enableTable: value)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: '长文档与可靠性',
                  subtitle: '默认值给 MinerU 的 200 页 / 200 MB 上限预留约 10% 余量。',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _NumberSetting(
                        label: '每个 PDF 分片页数',
                        value: settings.maxPagesPerChunk,
                        minimum: 20,
                        maximum: 190,
                        suffix: '页',
                        onChanged: (value) => controller.updateSettings(
                          settings.copyWith(maxPagesPerChunk: value),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _NumberSetting(
                        label: '每个分片最大体积',
                        value: settings.maxChunkMiB,
                        minimum: 20,
                        maximum: 190,
                        suffix: 'MiB',
                        onChanged: (value) => controller.updateSettings(
                          settings.copyWith(maxChunkMiB: value),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _NumberSetting(
                        label: '并发分片数',
                        value: settings.concurrency,
                        minimum: 1,
                        maximum: 4,
                        suffix: '个',
                        onChanged: (value) => controller.updateSettings(
                          settings.copyWith(concurrency: value),
                        ),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('保留 MinerU 原始分片结果'),
                        subtitle: const Text('便于审计和修复；会增加最终 ZIP 大小。'),
                        value: settings.keepRawChunks,
                        onChanged: (value) => controller.updateSettings(
                          settings.copyWith(keepRawChunks: value),
                        ),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('导入后自动开始'),
                        value: settings.autoStart,
                        onChanged: (value) => controller.updateSettings(
                          settings.copyWith(autoStart: value),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: '关于',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MinerU Flow 0.1.0',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '本应用不是 MinerU 官方产品。文件会直接上传到 MinerU 提供的签名地址；应用本身没有中转服务器，也不收集遥测。',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddToken(BuildContext context) async {
    final label = TextEditingController();
    final token = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加 MinerU Token'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: label,
                decoration: const InputDecoration(labelText: '名称', hintText: '主 Token'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: token,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Token'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
        ],
      ),
    );
    if (accepted == true && context.mounted) {
      await context.read<AppController>().addToken(label.text, token.text);
    }
    label.dispose();
    token.dispose();
  }

  String _masked(String token) {
    if (token.length <= 8) return '••••••••';
    return '${token.substring(0, 4)}••••••••${token.substring(token.length - 4)}';
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            if (subtitle != null) ...[
              const SizedBox(height: 5),
              Text(subtitle!, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyToken extends StatelessWidget {
  const _EmptyToken();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
          const SizedBox(width: 12),
          const Expanded(child: Text('尚未配置 Token，任务可以导入但不能提交解析。')),
        ],
      ),
    );
  }
}

class _NumberSetting extends StatelessWidget {
  const _NumberSetting({
    required this.label,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.suffix,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int minimum;
  final int maximum;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          onPressed: value <= minimum ? null : () => onChanged(value - 1),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 76,
          child: Text(
            '$value $suffix',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          onPressed: value >= maximum ? null : () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
