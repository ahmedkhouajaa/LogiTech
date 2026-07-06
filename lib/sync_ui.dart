import 'dart:io';

void main() {
  final invoiceContent = File('d:\\LogiTech\\lib\\screens\\create_invoice_screen.dart').readAsStringSync();
  var quoteContent = File('d:\\LogiTech\\lib\\screens\\create_quote_screen.dart').readAsStringSync();

  String extractFunction(String content, String functionName) {
    int startIndex = content.indexOf('Widget $functionName(');
    if (startIndex == -1) return '';
    int count = 0;
    int endIndex = -1;
    for (int i = startIndex; i < content.length; i++) {
      if (content[i] == '{') count++;
      if (content[i] == '}') {
        count--;
        if (count == 0) {
          endIndex = i + 1;
          break;
        }
      }
    }
    return content.substring(startIndex, endIndex);
  }

  final formCard = extractFunction(invoiceContent, '_buildFormCard');
  final totalsSection = extractFunction(invoiceContent, '_buildTotalsSection');
  final totalLine = extractFunction(invoiceContent, '_buildTotalLine');
  final notesSection = extractFunction(invoiceContent, '_buildNotesSection');
  final inputDeco = extractFunction(invoiceContent, '_formInputDecoration');
  final articlesSection = extractFunction(invoiceContent, '_buildArticlesSection');
  final articleActions = extractFunction(invoiceContent, '_buildArticleActions');

  // Replace functions in quote content
  String replaceFunction(String content, String functionName, String newFunction) {
    if (newFunction.isEmpty) return content;
    int startIndex = content.indexOf('Widget $functionName(');
    if (startIndex == -1) {
      // maybe it's not a widget (like _formInputDecoration)
      startIndex = content.indexOf('InputDecoration $functionName(');
      if (startIndex == -1) return content;
    }
    int count = 0;
    int endIndex = -1;
    for (int i = startIndex; i < content.length; i++) {
      if (content[i] == '{') count++;
      if (content[i] == '}') {
        count--;
        if (count == 0) {
          endIndex = i + 1;
          break;
        }
      }
    }
    return content.replaceRange(startIndex, endIndex, newFunction);
  }

  quoteContent = replaceFunction(quoteContent, '_buildFormCard', formCard);
  quoteContent = replaceFunction(quoteContent, '_buildTotalsSection', totalsSection);
  
  int totalRowIndex = quoteContent.indexOf('Widget _buildTotalRow(');
  if (totalRowIndex != -1) {
      int count = 0;
      int endIndex = -1;
      for (int i = totalRowIndex; i < quoteContent.length; i++) {
        if (quoteContent[i] == '{') count++;
        if (quoteContent[i] == '}') {
          count--;
          if (count == 0) {
            endIndex = i + 1;
            break;
          }
        }
      }
      quoteContent = quoteContent.replaceRange(totalRowIndex, endIndex, totalLine);
  } else {
     quoteContent = replaceFunction(quoteContent, '_buildTotalLine', totalLine);
  }

  quoteContent = replaceFunction(quoteContent, '_buildNotesSection', notesSection);
  quoteContent = replaceFunction(quoteContent, '_formInputDecoration', inputDeco);
  quoteContent = replaceFunction(quoteContent, '_buildArticlesSection', articlesSection);
  quoteContent = replaceFunction(quoteContent, '_buildArticleActions', articleActions);

  File('d:\\LogiTech\\lib\\screens\\create_quote_screen.dart').writeAsStringSync(quoteContent);
  print('Done syncing UI');
}
