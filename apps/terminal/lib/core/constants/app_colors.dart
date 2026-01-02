import 'package:fluent_ui/fluent_ui.dart';

class AppColors {
  // Status Colors
  // Status Colors (Fluent Standard)
  static const Color success = Color(0xFF107C10);
  static const Color error = Color(0xFFE81123);
  static const Color warning = Color(0xFFCA5010);
  static const Color info = Color(0xFF0078D7);
  static const Color neutral = Color(0xFF737373);
  static const Color teal = Color(0xFF008272);
  static const Color purple = Color(0xFF881798);

  // Role Colors
  static const Color roleAdmin = error;
  static const Color roleDispatcher = warning;
  static const Color roleSafetyOfficer = purple;
  static const Color roleDriver = success;
  static const Color roleAssistant = info;
  static const Color rolePending = neutral;
  static const Color roleAccountant = teal;

  // VS Code Theme (UserForm)
  static const Color vsCodeSidebar = Color(0xFF252526);
  static const Color vsCodeBorder = Color(0xFF333333);
  static const Color vsCodeWidgetBg = Color(0xFF3C3C3C);
  static const Color vsCodeText = Color(0xFFCCCCCC);
  static const Color vsCodeBlue = Color(0xFF007ACC);
}
