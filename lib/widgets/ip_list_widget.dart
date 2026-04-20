import 'package:flutter/material.dart';
import '../services/ping_service.dart';
import '../theme/app_theme.dart';

class IPListWidget extends StatefulWidget {
  final List<IPLatency> ipList;
  final Function(String) onIPSelected;

  const IPListWidget({
    super.key,
    required this.ipList,
    required this.onIPSelected,
  });

  @override
  State<IPListWidget> createState() => _IPListWidgetState();
}

class _IPListWidgetState extends State<IPListWidget> {
  String? _selectedIP;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 列表标题
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCardBackground : Colors.white,
            border: Border(
              bottom: BorderSide(color: AppColors.border),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.list_alt, color: AppColors.textSecondary, size: 18),
              const SizedBox(width: 8),
              Text(
                '优选 IP 列表',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '按延迟排序',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        // IP 列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: widget.ipList.length,
            itemBuilder: (context, index) {
              final ipData = widget.ipList[index];
              final isSelected = _selectedIP == ipData.ip;

              // 根据延迟设置颜色 - 全部使用绿色系
              Color latencyColor = AppColors.success;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryLight
                      : isDark
                          ? AppColors.darkCardBackground
                          : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: latencyColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '#${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: latencyColor,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    ipData.ip,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: latencyColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '延迟: ${ipData.latency}ms',
                      style: TextStyle(
                        color: latencyColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  trailing: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                  onTap: () {
                    setState(() {
                      _selectedIP = ipData.ip;
                    });
                    widget.onIPSelected(ipData.ip);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
