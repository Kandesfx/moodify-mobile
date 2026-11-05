import 'package:flutter/material.dart';

import 'app_motion.dart';

/// Quy tắc phân lớp hiển thị của Moodify (từ dưới lên trên):
///
/// 1. Nội dung tab — body của branch navigator trong `MainShell`.
/// 2. Chrome cố định — mini player + thanh điều hướng trong
///    `MainShell.bottomNavigationBar`, luôn đè nội dung tab.
/// 3. Route/modal đẩy lên root navigator — luôn đè cả nhóm 1 và 2;
///    thứ tự mở quyết định lớp trên dưới giữa chúng:
///    bottom sheet (qua [showAppModalSheet]), player toàn màn hình,
///    dialog, snackbar.
///
/// Flutter mặc định mở modal bottom sheet trên navigator gần nhất (branch),
/// nên sheet bị chrome ở nhóm 2 đè lên và bị cắt mất phần dưới. Helper này
/// khoá `useRootNavigator: true` cho mọi sheet của app để loại trừ chồng
/// chéo đó; sheet luôn trượt lên trên chrome kèm scrim toàn màn hình.
Future<T?> showAppModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool showDragHandle = false,
  Color? backgroundColor,
  AnimationStyle? sheetAnimationStyle,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    backgroundColor: backgroundColor,
    sheetAnimationStyle: sheetAnimationStyle ?? AnimationStyle(
      duration: AppMotion.duration(context, 280),
      reverseDuration: AppMotion.duration(context, 220),
    ),
    builder: builder,
  );
}
