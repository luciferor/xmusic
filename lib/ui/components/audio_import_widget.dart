import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:xmusic/services/local_audio_service.dart';
import 'dart:io';

class AudioImportWidget extends StatefulWidget {
  const AudioImportWidget({Key? key}) : super(key: key);

  @override
  State<AudioImportWidget> createState() => _AudioImportWidgetState();
}

class _AudioImportWidgetState extends State<AudioImportWidget> {
  final LocalAudioService _audioService = LocalAudioService.instance;
  bool _isImporting = false;
  Map<String, dynamic>? _lastImportResult;
  Map<String, dynamic>? _importStats;

  @override
  void initState() {
    super.initState();
    _loadImportStats();
  }

  Future<void> _loadImportStats() async {
    final stats = await _audioService.getImportResultSummary();
    setState(() {
      _importStats = stats;
    });
  }

  Future<void> _importAudioFiles() async {
    setState(() {
      _isImporting = true;
    });

    try {
      final result = await _audioService.importAudioFiles();

      setState(() {
        _lastImportResult = {'imported': result, 'timestamp': DateTime.now()};
        _isImporting = false;
      });

      // 重新加载统计信息
      await _loadImportStats();

      // 显示导入结果
      if (mounted) {
        _showImportResultDialog(result);
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
      });

      if (mounted) {
        Fluttertoast.showToast(
          msg: '导入失败',
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.white,
          textColor: Colors.black,
        );
      }
    }
  }

  void _showImportResultDialog(List<Map<String, dynamic>> importedFiles) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('音频导入结果'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('成功导入: ${importedFiles.length} 个文件'),
            if (_importStats != null) ...[
              const SizedBox(height: 8),
              Text('跳过重复: ${_importStats!['skipped_count']} 个文件'),
              Text('警告文件: ${_importStats!['warning_count']} 个文件'),
            ],
            if (importedFiles.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('导入的文件:'),
              const SizedBox(height: 4),
              ...importedFiles
                  .take(5)
                  .map(
                    (file) => Text(
                      '• ${file['name']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              if (importedFiles.length > 5)
                Text(
                  '... 还有 ${importedFiles.length - 5} 个文件',
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkDuplicateFile() async {
    // 这里可以添加文件选择逻辑来演示重复检测
    // 为了演示，我们使用一个示例文件
    final exampleFile = File('/path/to/example.mp3');
    if (await exampleFile.exists()) {
      final duplicateInfo = await _audioService.getDuplicateDetectionInfo(
        exampleFile,
        'example.mp3',
      );

      if (mounted) {
        _showDuplicateInfoDialog(duplicateInfo);
      }
    }
  }

  void _showDuplicateInfoDialog(Map<String, dynamic> duplicateInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重复文件检测结果'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('检测结果: ${duplicateInfo['message']}'),
            const SizedBox(height: 8),
            Text('重复类型: ${duplicateInfo['duplicateType']}'),
            if (duplicateInfo['existingFiles']?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              const Text('已存在的文件:'),
              ...(duplicateInfo['existingFiles'] as List).map(
                (file) => Text(
                  '• ${file['name']}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearStats() async {
    await _audioService.clearImportResultStats();
    await _loadImportStats();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('统计信息已清除')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '音频导入管理',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // 导入按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isImporting ? null : _importAudioFiles,
                icon: _isImporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(_isImporting ? '导入中...' : '选择并导入音频文件'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 统计信息
            if (_importStats != null) ...[
              const Text(
                '导入统计',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: '成功导入',
                      value: '${_importStats!['imported_count']}',
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      title: '跳过重复',
                      value: '${_importStats!['skipped_count']}',
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      title: '警告文件',
                      value: '${_importStats!['warning_count']}',
                      color: Colors.yellow,
                    ),
                  ),
                ],
              ),

              if (_importStats!['last_import_time'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  '最后导入: ${_formatDateTime(_importStats!['last_import_time'])}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],

              const SizedBox(height: 16),
            ],

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _checkDuplicateFile,
                    icon: const Icon(Icons.search),
                    label: const Text('检测重复'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _clearStats,
                    icon: const Icon(Icons.clear),
                    label: const Text('清除统计'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dateTime = DateTime.parse(isoString);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoString;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha((0.3 * 255).round())),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withAlpha((0.8 * 255).round()),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
