import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

/// Helper to sanitize Excel (.xlsx) file bytes before parsing with the `excel` package.
///
/// Addresses known issues with the `excel` package (e.g. 4.0.6):
/// 1. `Null check operator used on a null value` in `Parser._parseTable`:
///    When Excel/WPS/LibreOffice saves relationship targets with leading slashes
///    or `xl/` prefixes (e.g. `Target="/xl/worksheets/sheet1.xml"`), `excel` looks for
///    `xl//xl/worksheets/sheet1.xml` which doesn't exist, leading to a null archive file.
/// 2. `Bad state: No element` in `Parser._parseCell`:
///    When cells have `t="inlineStr"` without a `<t>` tag (e.g. empty string cells saved by WPS),
///    `excel` calls `.findAllElements('t').first` without null/empty checks.
/// 3. Empty elements in `t="str"`, `t="b"`, `t="e"` without `<v>` tag.
class ExcelSafeHelper {
  ExcelSafeHelper._();

  /// Sanitizes raw XLSX bytes so they can be safely parsed by `Excel.decodeBytes`.
  static Uint8List sanitizeXlsxBytes(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final newArchive = Archive();
      bool modified = false;

      for (final file in archive.files) {
        if (!file.isFile) continue;

        var content = file.content as List<int>;

        // 1. Fix relationships:
        if (file.name.contains('xl/_rels') && file.name.endsWith('.rels')) {
          final str = utf8.decode(content, allowMalformed: true);
          final fixedStr = str
              .replaceAll('Target="/xl/', 'Target="')
              .replaceAll('Target="xl/', 'Target="')
              .replaceAll('Target="/', 'Target="');
          if (fixedStr != str) {
            modified = true;
            content = utf8.encode(fixedStr);
          }
        } else if (file.name.endsWith('.rels')) {
          final str = utf8.decode(content, allowMalformed: true);
          final fixedStr = str.replaceAll('Target="/', 'Target="');
          if (fixedStr != str) {
            modified = true;
            content = utf8.encode(fixedStr);
          }
        }

        // 2. Fix worksheet XML: inlineStr cells without <t>, str/b/e cells without <v>
        if (file.name.startsWith('xl/worksheets/') && file.name.endsWith('.xml')) {
          try {
            final str = utf8.decode(content, allowMalformed: true);
            if (str.contains('inlineStr') || str.contains('<c ')) {
              final doc = XmlDocument.parse(str);
              bool sheetModified = false;

              for (final c in doc.findAllElements('c')) {
                final t = c.getAttribute('t');
                if (t == 'inlineStr') {
                  final tNodes = c.findAllElements('t').toList();
                  if (tNodes.isEmpty) {
                    final isNodes = c.findElements('is').toList();
                    if (isNodes.isNotEmpty) {
                      isNodes.first.children.add(XmlElement(XmlName('t'), [], [XmlText('')]));
                    } else {
                      c.children.add(XmlElement(XmlName('is'), [], [
                        XmlElement(XmlName('t'), [], [XmlText('')])
                      ]));
                    }
                    sheetModified = true;
                  }
                } else if (t == 'str' || t == 'b' || t == 'e') {
                  final vNodes = c.findElements('v').toList();
                  if (vNodes.isEmpty) {
                    c.children.add(XmlElement(XmlName('v'), [], [XmlText('')]));
                    sheetModified = true;
                  }
                }
              }

              if (sheetModified) {
                modified = true;
                content = utf8.encode(doc.toXmlString());
              }
            }
          } catch (e) {
            debugPrint('[ExcelSafeHelper] Error inspecting worksheet xml: $e');
          }
        }

        newArchive.addFile(ArchiveFile(file.name, content.length, content));
      }

      if (modified) {
        final encoded = ZipEncoder().encode(newArchive);
        if (encoded != null) {
          return Uint8List.fromList(encoded);
        }
      }
    } catch (e) {
      debugPrint('[ExcelSafeHelper] Could not sanitize xlsx: $e');
    }
    return bytes;
  }
}
