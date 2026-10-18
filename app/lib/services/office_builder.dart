import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// 手写的最小 OOXML 生成器（不引第三方 docx/xlsx 包，保持体积与可控性）。
///
/// - Word：`word/document.xml` + 最小包关系
/// - Excel：`xl/worksheets/sheet1.xml`，字符串用 inlineStr（免 sharedStrings）

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

enum DocStyle { title, meta, h2, h3, bullet, note }

class DocLine {
  const DocLine(this.style, this.text);
  final DocStyle style;
  final String text;
}

Uint8List _zip(Map<String, String> files) {
  final archive = Archive();
  for (final e in files.entries) {
    final bytes = utf8.encode(e.value);
    archive.addFile(ArchiveFile(e.key, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

String _paragraph(DocLine l) {
  final (size, bold, color, prefix) = switch (l.style) {
    DocStyle.title => (36, true, '000000', ''),
    DocStyle.meta => (18, false, '888888', ''),
    DocStyle.h2 => (28, true, '000000', ''),
    DocStyle.h3 => (22, true, '444444', ''),
    DocStyle.bullet => (21, false, '000000', '• '),
    DocStyle.note => (18, false, '777777', '    '),
  };
  final text = _esc('$prefix${l.text}');
  return '<w:p><w:pPr><w:spacing w:before="60" w:after="60"/></w:pPr>'
      '<w:r><w:rPr><w:rFonts w:ascii="Calibri" w:eastAsia="宋体" w:hAnsi="Calibri"/>'
      '${bold ? '<w:b/>' : ''}<w:sz w:val="$size"/><w:color w:val="$color"/></w:rPr>'
      '<w:t xml:space="preserve">$text</w:t></w:r></w:p>';
}

Uint8List buildDocx(List<DocLine> lines) {
  final body = lines.map(_paragraph).join();
  final document = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:body>$body'
      '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
      '<w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134"/>'
      '</w:sectPr></w:body></w:document>';

  return _zip({
    '[Content_Types].xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/word/document.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '</Types>',
    '_rels/.rels': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
        'Target="word/document.xml"/></Relationships>',
    'word/document.xml': document,
  });
}

String _col(int index) {
  var s = '';
  var n = index + 1;
  while (n > 0) {
    final r = (n - 1) % 26;
    s = String.fromCharCode(65 + r) + s;
    n = (n - 1) ~/ 26;
  }
  return s;
}

Uint8List buildXlsx({
  required String sheetName,
  required List<List<String>> rows,
}) {
  final sheetRows = <String>[];
  for (var r = 0; r < rows.length; r++) {
    final cells = <String>[];
    for (var c = 0; c < rows[r].length; c++) {
      cells.add('<c r="${_col(c)}${r + 1}" t="inlineStr">'
          '<is><t xml:space="preserve">${_esc(rows[r][c])}</t></is></c>');
    }
    sheetRows.add('<row r="${r + 1}">${cells.join()}</row>');
  }

  final safeName = _esc(sheetName.replaceAll(RegExp(r'[\\/*?:\[\]]'), ' '));

  return _zip({
    '[Content_Types].xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/worksheets/sheet1.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        '</Types>',
    '_rels/.rels': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
        'Target="xl/workbook.xml"/></Relationships>',
    'xl/workbook.xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<sheets><sheet name="$safeName" sheetId="1" r:id="rId1"/></sheets></workbook>',
    'xl/_rels/workbook.xml.rels':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" '
            'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
            'Target="worksheets/sheet1.xml"/></Relationships>',
    'xl/worksheets/sheet1.xml':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
            '<sheetData>${sheetRows.join()}</sheetData></worksheet>',
  });
}
