import 'dart:io';

void main() {
  final file = File(r"c:\Users\SamDa\arion_daq\lib\views\analysis_tab.dart");
  final content = file.readAsStringSync();
  
  final stack = <Map<String, dynamic>>[];
  final lines = content.split('\n');
  
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    for (var j = 0; j < line.length; j++) {
      final char = line[j];
      if (char == '(' || char == '{' || char == '[') {
        stack.add({
          'char': char,
          'line': i + 1,
          'col': j + 1,
        });
      } else if (char == ')' || char == '}' || char == ']') {
        if (stack.isEmpty) {
          print("Extra closing $char at line ${i+1}, col ${j+1}");
          continue;
        }
        final top = stack.removeLast();
        final topChar = top['char'];
        if ((char == ')' && topChar != '(') || 
            (char == '}' && topChar != '{') || 
            (char == ']' && topChar != '[')) {
          print("Mismatched $char at line ${i+1}, col ${j+1} (opened with $topChar at line ${top['line']}, col ${top['col']})");
        }
      }
    }
  }
  
  if (stack.isNotEmpty) {
    print("Unclosed brackets:");
    for (var item in stack) {
      print("  ${item['char']} at line ${item['line']}, col ${item['col']}");
    }
  } else {
    print("All brackets match perfectly!");
  }
}
