import 'package:http/http.dart' as http;
void main() async {
  var url = Uri.parse('https://z-library.sk/dl/lZl6zzR4BK'); 
  var request = http.Request('GET', url)..followRedirects = false;
  request.headers['Cookie'] = 'c_token=2D8669EA241AC6E951E18E37B071D170E60B6BE227442'; // fake cookie just to check
  var resp = await http.Client().send(request);
  print(resp.statusCode);
  print(resp.headers);
}
