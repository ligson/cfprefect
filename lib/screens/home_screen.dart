import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/cloudflare_service.dart';
import '../services/ping_service.dart';
import '../services/clash_config_service.dart';
import '../widgets/ip_list_widget.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<IPLatency> _ipList = [];
  String? _selectedIP;
  bool _isLoading = false;
  String _statusMessage = '点击 "优选IP" 按钮开始';

  // Clash 配置文件路径
  String? _clashConfigPath;

  // 配置参数
  int _timeoutSeconds = 1;
  int _ipsPerCidr = 100;

  // 进度相关
  int _progressCurrent = 0;
  int _progressTotal = 0;
  String _progressIP = '';
  List<String> _scanLog = [];
  DateTime? _startTime;
  String _estimatedTimeRemaining = '';
  bool _isCancelled = false;

  void _startOptimization() async {
    setState(() {
      _isLoading = true;
      _isCancelled = false;
      _statusMessage = '正在获取 Cloudflare IP 列表...';
      _ipList = [];
      _progressCurrent = 0;
      _progressTotal = 0;
      _progressIP = '';
      _scanLog = [];
      _startTime = null;
      _estimatedTimeRemaining = '';
    });

    try {
      debugPrint('[HomeScreen] 开始获取 IP...');
      final cidrs = await CloudflareService.fetchCloudflareIPs();
      debugPrint('[HomeScreen] 获取到 ${cidrs.length} 个 CIDR');

      if (_isCancelled) {
        _handleCancellation();
        return;
      }

      setState(() {
        _statusMessage = '正在生成 IP 地址...';
      });

      final ips = await CloudflareService.extractBaseIPs(cidrs, maxPerCidr: _ipsPerCidr);
      debugPrint('[HomeScreen] 生成 ${ips.length} 个 IP');

      if (_isCancelled) {
        _handleCancellation();
        return;
      }

      // 计算预计时间
      const concurrentLimit = 100;
      final batches = (ips.length / concurrentLimit).ceil();
      final estimatedSeconds = batches * _timeoutSeconds;
      final estimatedMinutes = estimatedSeconds ~/ 60;
      final estimatedSecs = estimatedSeconds % 60;

      setState(() {
        _progressTotal = ips.length;
        _startTime = DateTime.now();
        _statusMessage = '开始扫描...';
        _scanLog.add('📊 共 ${ips.length} 个 IP 待测试');
        _scanLog.add('⏱️ 超时设置: ${_timeoutSeconds}s');
        _scanLog.add('⏳ 预计时间: ${estimatedMinutes > 0 ? '$estimatedMinutes 分 ' : ''}$estimatedSecs 秒');
      });

      final results = await PingService.testMultipleIPs(
        ips,
        timeout: Duration(seconds: _timeoutSeconds),
        onProgress: (completed, total, currentIP) {
          if (_isCancelled) return;
          if (mounted) {
            String estimatedTime = '';
            if (completed > 0 && _startTime != null) {
              final elapsed = DateTime.now().difference(_startTime!);
              final avgTimePerIP = elapsed.inMilliseconds / completed;
              final remainingIPs = total - completed;
              final remainingMs = (avgTimePerIP * remainingIPs).round();
              final remainingMin = remainingMs ~/ 60000;
              final remainingSec = (remainingMs % 60000) ~/ 1000;

              estimatedTime = remainingMin > 0
                  ? '剩余约 $remainingMin 分 $remainingSec 秒'
                  : '剩余约 $remainingSec 秒';
            }

            setState(() {
              _progressCurrent = completed;
              _progressIP = currentIP;
              _statusMessage = '扫描中... $completed/$total';
              _estimatedTimeRemaining = estimatedTime;
            });
          }
        },
        onResult: (result) {
          if (_isCancelled) return;
          if (mounted && result.success) {
            setState(() {
              _scanLog.insert(0, '${result.ip} - ${result.latency}ms');
              if (_scanLog.length > 20) _scanLog.removeLast();
            });
          }
        },
      );

      if (_isCancelled) {
        _handleCancellation();
        return;
      }

      if (mounted) {
        final totalTime = DateTime.now().difference(_startTime!);
        final totalMin = totalTime.inMinutes;
        final totalSec = totalTime.inSeconds % 60;

        setState(() {
          _ipList = results;
          _statusMessage = '扫描完成！找到 ${results.length} 个可用 IP\n耗时: ${totalMin > 0 ? '$totalMin 分 ' : ''}$totalSec 秒';
          _isLoading = false;
          _estimatedTimeRemaining = '';
        });
      }
    } catch (e) {
      debugPrint('IP 获取错误: $e');
      if (mounted) {
        setState(() {
          _statusMessage = '获取失败: $e';
          _isLoading = false;
          _estimatedTimeRemaining = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('获取 IP 失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _cancelScan() {
    setState(() {
      _isCancelled = true;
      _statusMessage = '正在取消扫描...';
    });
  }

  void _handleCancellation() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 8),
              Text('扫描已取消'),
            ],
          ),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 2),
        ),
      );

      setState(() {
        _isLoading = false;
        _statusMessage = '点击 "优选IP" 按钮开始';
        _ipList = [];
        _progressCurrent = 0;
        _progressTotal = 0;
        _estimatedTimeRemaining = '';
        _scanLog = [];
      });
    }
  }

  void _showSettingsDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        int tempTimeout = _timeoutSeconds;
        int tempIpsPerCidr = _ipsPerCidr;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('扫描设置'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 超时时间
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCardBackground : AppColors.infoLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer, color: AppColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '超时时间 (秒)',
                            style: TextStyle(
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        _buildNumberControl(
                          value: tempTimeout,
                          onDecrease: tempTimeout > 1
                              ? () => setDialogState(() => tempTimeout--)
                              : null,
                          onIncrease: tempTimeout < 10
                              ? () => setDialogState(() => tempTimeout++)
                              : null,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 每个 CIDR 的 IP 数量
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCardBackground : AppColors.successLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.dns, color: AppColors.success, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '每段扫描数量',
                            style: TextStyle(
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        _buildNumberControl(
                          value: tempIpsPerCidr,
                          onDecrease: tempIpsPerCidr > 10
                              ? () => setDialogState(() => tempIpsPerCidr -= 10)
                              : null,
                          onIncrease: tempIpsPerCidr < 1000
                              ? () => setDialogState(() => tempIpsPerCidr += 10)
                              : null,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 预计总数
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calculate, size: 16, color: isDark ? Colors.grey[400] : AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          '预计总 IP 数: ${tempIpsPerCidr * 15}',
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _timeoutSeconds = tempTimeout;
                      _ipsPerCidr = tempIpsPerCidr;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildNumberControl({
    required int value,
    VoidCallback? onDecrease,
    VoidCallback? onIncrease,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[700] : Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildControlButton(Icons.remove, onDecrease, isDark),
          Container(
            width: 40,
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
          _buildControlButton(Icons.add, onIncrease, isDark),
        ],
      ),
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback? onPressed, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: onPressed != null
                ? AppColors.primary
                : (isDark ? Colors.grey[600] : Colors.grey[400]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('IP优选工具'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _isLoading ? null : _showSettingsDialog,
            tooltip: '扫描设置',
          ),
        ],
      ),
      body: _ipList.isEmpty
          ? _buildEmptyState(isDark)
          : _buildMainContent(isDark),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 状态图标
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _isLoading ? AppColors.infoLight : AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isLoading ? Icons.wifi_find : Icons.wifi,
                size: 48,
                color: _isLoading ? AppColors.info : AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),

            // 状态消息
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),

            // 进度条
            if (_isLoading && _progressTotal > 0) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCardBackground : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _progressCurrent / _progressTotal,
                        minHeight: 8,
                        backgroundColor: isDark ? Colors.grey[700] : Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$_progressCurrent / $_progressTotal',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_estimatedTimeRemaining.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.infoLight,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.timer_outlined, size: 14, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  _estimatedTimeRemaining,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // 扫描日志
            if (_isLoading && _scanLog.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                height: 180,
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey[700]! : AppColors.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.history, size: 16, color: isDark ? Colors.grey[400] : AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          '扫描日志',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[400] : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Divider(
                      height: 16,
                      color: isDark ? Colors.grey[700] : AppColors.divider,
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _scanLog.length,
                        itemBuilder: (context, index) {
                          final log = _scanLog[index];
                          final isSuccess = log.contains('ms');
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Icon(
                                  isSuccess ? Icons.check_circle : Icons.info_outline,
                                  size: 14,
                                  color: isSuccess ? AppColors.success : (isDark ? Colors.grey[500] : AppColors.textSecondary),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    log,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                      color: isSuccess
                                          ? AppColors.success
                                          : (isDark ? Colors.grey[300] : AppColors.textPrimary),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // 按钮
            if (_isLoading)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _cancelScan,
                  icon: const Icon(Icons.cancel),
                  label: const Text('取消扫描'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? AppColors.error.withOpacity(0.8)
                        : AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startOptimization,
                  icon: const Icon(Icons.search),
                  label: const Text('优选 IP'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(bool isDark) {
    return Column(
      children: [
        // 统计信息
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.success.withOpacity(0.15)
                : AppColors.successLight,
            border: Border(
              bottom: BorderSide(color: isDark ? Colors.grey[700]! : AppColors.border),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.success.withOpacity(0.2) : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '找到 ${_ipList.length} 个可用 IP',
                style: TextStyle(
                  color: isDark ? AppColors.success : AppColors.success,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: IPListWidget(
            ipList: _ipList,
            onIPSelected: (ip) {
              setState(() {
                _selectedIP = ip;
              });
            },
          ),
        ),

        // 底部操作区
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCardBackground : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Clash 配置文件选择
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.settings_ethernet,
                        size: 20,
                        color: _clashConfigPath != null
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _clashConfigPath ?? '选择 Clash 配置文件 (.yaml/.yml)',
                          style: TextStyle(
                            fontSize: 13,
                            color: _clashConfigPath != null
                                ? AppColors.success
                                : AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _pickClashConfig,
                        icon: const Icon(Icons.folder_open, size: 18),
                        label: const Text('选择'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _selectedIP != null && _clashConfigPath != null
                            ? _applyToClashConfig
                            : null,
                        icon: const Icon(Icons.done),
                        label: const Text('更新配置'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _ipList = [];
                            _selectedIP = null;
                            _clashConfigPath = null;
                            _statusMessage = '点击 "优选IP" 按钮开始';
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('重新扫描'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 选择 Clash 配置文件
  Future<void> _pickClashConfig() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _clashConfigPath = result.files.single.path;
          _statusMessage = '已选择: ${result.files.single.name}';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件失败: $e')),
        );
      }
    }
  }

  /// 应用优选 IP 到 Clash 配置文件
  Future<void> _applyToClashConfig() async {
    if (_selectedIP == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择一个 IP')),
      );
      return;
    }

    if (_clashConfigPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择 Clash 配置文件')),
      );
      return;
    }

    try {
      setState(() {
        _statusMessage = '正在更新 Clash 配置...';
      });

      // 更新配置文件
      await ClashConfigService.updateConfigDirectly(
        _clashConfigPath!,
        _selectedIP!,
      );

      if (mounted) {
        setState(() {
          _statusMessage = 'Clash 配置已更新: $_selectedIP';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已将优选 IP $_selectedIP 写入配置文件\n请重新加载 Clash 配置'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = '更新失败: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('更新失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
