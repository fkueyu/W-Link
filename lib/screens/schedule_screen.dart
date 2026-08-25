import 'nightlight_screen.dart';

/// 兼容旧入口；Nightlight 已不再冒充通用日程功能。
@Deprecated('Use NightlightScreen instead')
class ScheduleScreen extends NightlightScreen {
  const ScheduleScreen({super.key});
}
