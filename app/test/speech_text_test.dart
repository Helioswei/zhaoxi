import 'package:flutter_test/flutter_test.dart';
import 'package:zhaoxi/domain/speech_text.dart';

void main() {
  group('mergeDictation', () {
    test('已有内容为空时直接采用识别结果', () {
      expect(mergeDictation('', '买盐'), '买盐');
      expect(mergeDictation('   ', '买盐'), '买盐');
    });

    test('识别结果为空时保留已有内容', () {
      expect(mergeDictation('交材料', ''), '交材料');
      expect(mergeDictation('交材料', '   '), '交材料');
    });

    test('两端都有内容时用单个空格连接', () {
      expect(mergeDictation('买盐', '顺便买酱油'), '买盐 顺便买酱油');
    });

    test('不会累积尾部空格', () {
      expect(mergeDictation('买盐  ', ' 买醋 '), '买盐 买醋');
    });
  });
}
