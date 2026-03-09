import 'dart:io';

void main() {
  final file = File('epub_reader_view.dart');
  var content = file.readAsStringSync();
  
  // 1. Remove _server, _port, _htmlContent variables
  content = content.replaceFirst(
'''  HttpServer? _server;
  int _port = 0;
  String _htmlContent = '';''', '');

  // 2. Erase _startLocalServer block completely
  final startServerRegex = RegExp(r'  // ---------------------------------------------------------------------------\n.*?_startLocalServer\(\);\n  }\n\n  Future<void> _startLocalServer.*?void dispose\(\) \{\n.*?super\.dispose\(\);\n  }\n\n  // ---------------------------------------------------------------------------', dotAll: true);
  
  content = content.replaceFirst(startServerRegex, '''  // ---------------------------------------------------------------------------
    // _startLocalServer removed
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ---------------------------------------------------------------------------''');
  
  // 3. Remove `if (_port == 0)` in build method
  content = content.replaceFirst('''    if (_port == 0) {
      // Waiting for local server to start
      return const Center(child: CircularProgressIndicator());
    }''', '');
    
  file.writeAsStringSync(content);
  print('Patched successfully');
}
