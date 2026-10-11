/// 把"识别到的文字"合并进已有标题。
///
/// - 识别结果为空 → 原样返回已有内容；
/// - 已有内容为空 → 返回识别结果；
/// - 否则用单个空格连接（去掉尾部空白，避免累积空格）。
String mergeDictation(String base, String recognized) {
  final existing = base.trimRight();
  final spoken = recognized.trim();
  if (spoken.isEmpty) return existing;
  if (existing.isEmpty) return spoken;
  return '$existing $spoken';
}
