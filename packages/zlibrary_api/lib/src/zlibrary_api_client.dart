import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'dart:convert';

import 'models/zlibrary_book.dart';
import 'browser_check_solver.dart';

class ZLibraryApi {
  final List<String> mirrors;
  final http.Client _client = http.Client();
  Map<String, String> _cookies = {};

  ZLibraryApi({
    this.mirrors = const [
      'https://z-lib.sk',
      'https://z-library.sk',
    ],
    Map<String, String>? cookies,
  }) {
    if (cookies != null) {
      _cookies = Map.from(cookies);
    }
  }

  Map<String, String> get cookies => Map.unmodifiable(_cookies);

  /// Login to Z-Library to obtain cookies
  Future<void> login(String email, String password) async {
    Exception? lastException;
    for (final mirror in mirrors) {
      try {
        final loginUrl = '$mirror/rpc.php';
        final response = await _client.post(
          Uri.parse(loginUrl),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'isModal': 'true',
            'email': email,
            'password': password,
            'site_mode': 'books',
            'action': 'login',
            'isSingleLogin': '1',
            'redirectUrl': '',
            'gg_json_mode': '1',
          },
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          if (data['response']?['validationError'] != null) {
            throw Exception(
                'Login failed: ${data['response']['validationError']}');
          }
          _updateCookies(response);
          return; // Success
        }
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
      }
    }
    throw lastException ?? Exception('All mirrors failed to login');
  }

  void _updateCookies(http.Response response) {
    String? rawCookie = response.headers['set-cookie'];
    if (rawCookie != null) {
      List<String> cookies = rawCookie.split(RegExp(r',(?=[^ ])'));
      for (var cookie in cookies) {
        var parts = cookie.split(';');
        if (parts.isNotEmpty) {
          var keyValue = parts[0].split('=');
          if (keyValue.length >= 2) {
            _cookies[keyValue[0].trim()] = keyValue[1].trim();
          }
        }
      }
    }
  }

  String get _cookieHeader {
    return _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  /// Search books
  Future<List<ZLibraryBook>> search({
    required String query,
    List<String> extensions = const [],
    int page = 1,
  }) async {
    final List<String> params = [];
    params.add('page=$page');

    for (var i = 0; i < extensions.length; i++) {
      params.add('extensions%5B$i%5D=${extensions[i].toUpperCase()}');
    }

    final queryStr = params.join('&');

    Exception? lastException;
    for (final mirror in mirrors) {
      try {
        String urlString = '$mirror/s/${Uri.encodeComponent(query)}?$queryStr';

        print('ZLibraryApi: Requesting search -> $urlString');
        http.Response response = await _client.get(
          Uri.parse(urlString),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36',
            'Cookie': _cookieHeader,
          },
        );
        print('ZLibraryApi: Response status: ${response.statusCode}');

        if (response.statusCode == 503 &&
            response.body.contains('Checking your browser')) {
          print('ZLibraryApi: Encountered JS challenge, solving...');
          final token = BrowserCheckSolver.solve(response.body);
          if (token != null) {
            print('ZLibraryApi: Solved challenge. c_token=$token');
            _cookies['c_token'] = token;

            // Retry request
            response = await _client.get(
              Uri.parse(urlString),
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36',
                'Cookie': _cookieHeader,
              },
            );
            print('ZLibraryApi: Retry response status: ${response.statusCode}');
          } else {
            print('ZLibraryApi: Failed to solve challenge.');
          }
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          _updateCookies(response);
          return _parseSearchResults(response.body, mirror);
        }
      } catch (e) {
        print('ZLibraryApi: Error on mirror $mirror - $e');
        lastException = e is Exception ? e : Exception(e.toString());
      }
    }
    throw lastException ?? Exception('All search mirrors failed');
  }

  List<ZLibraryBook> _parseSearchResults(String htmlBody, String mirror) {
    final document = html_parser.parse(htmlBody);

    // Check if the page explicitly says "nothing found"
    final notFoundNode = document.querySelector('.notFound');
    if (notFoundNode != null) {
      return [];
    }

    final box = document.getElementById('searchResultBox');

    if (box == null) {
      throw Exception(
          'Invalid page format: missing searchResultBox and notFound marker.');
    }

    final bookElements = box.querySelectorAll('.book-item');
    final List<ZLibraryBook> results = [];

    for (var element in bookElements) {
      final zBookcard = element.querySelector('z-bookcard');
      if (zBookcard == null) continue;

      final id = zBookcard.attributes['id'] ?? '';
      final isbn = zBookcard.attributes['isbn'] ?? '';
      final urlPath = zBookcard.attributes['href'] ?? '';

      String cover = '';
      final img = zBookcard.querySelector('img');
      if (img != null) {
        cover = img.attributes['data-src'] ?? img.attributes['src'] ?? '';
      }

      final publisher = zBookcard.attributes['publisher'] ?? '';
      final year = zBookcard.attributes['year'] ?? '';
      final language = zBookcard.attributes['language'] ?? '';
      final extension = zBookcard.attributes['extension'] ?? '';
      final size = zBookcard.attributes['filesize'] ?? '';
      final rating = zBookcard.attributes['rating'] ?? '';

      String title = '';
      final titleSlot = zBookcard.querySelector('div[slot="title"]');
      if (titleSlot != null) {
        title = titleSlot.text.trim();
      }

      String author = '';
      final authorSlot = zBookcard.querySelector('div[slot="author"]');
      if (authorSlot != null) {
        author = authorSlot.text
            .trim()
            .split(';')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .join(', ');
      }

      final downloadPath = zBookcard.attributes['download'] ?? '';
      final downloadUrl =
          downloadPath.isNotEmpty ? '$mirror$downloadPath' : null;

      results.add(ZLibraryBook(
        id: id,
        isbn: isbn,
        title: title,
        author: author,
        coverUrl: cover,
        publisher: publisher,
        year: year,
        language: language,
        extension: extension,
        size: size,
        rating: rating,
        url: urlPath.isNotEmpty ? '$mirror$urlPath' : '',
        downloadUrl: downloadUrl,
      ));
    }

    return results;
  }

  /// Get download link for a specific book
  Future<ZLibraryBook> fetchBookDetails(ZLibraryBook book) async {
    if (book.url.isEmpty) {
      throw Exception('Book URL is empty');
    }

    print('ZLibraryApi: Fetching book details -> ${book.url}');
    http.Response response = await _client.get(
      Uri.parse(book.url),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36',
        'Cookie': _cookieHeader,
      },
    );
    print('ZLibraryApi: Response status: ${response.statusCode}');

    if (response.statusCode == 503 &&
        response.body.contains('Checking your browser')) {
      print('ZLibraryApi: Encountered JS challenge, solving...');
      final token = BrowserCheckSolver.solve(response.body);
      if (token != null) {
        print('ZLibraryApi: Solved challenge. c_token=$token');
        _cookies['c_token'] = token;

        // Retry request
        response = await _client.get(
          Uri.parse(book.url),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36',
            'Cookie': _cookieHeader,
          },
        );
        print('ZLibraryApi: Retry response status: ${response.statusCode}');
      } else {
        print('ZLibraryApi: Failed to solve challenge.');
      }
    }

    _updateCookies(response);

    final document = html_parser.parse(response.body);
    final dlBtn = document.querySelector('a.btn.btn-default.addDownloadedBook');

    String? downloadUrl;
    if (dlBtn != null) {
      final href = dlBtn.attributes['href'];
      if (href != null && !dlBtn.text.toLowerCase().contains('unavailable')) {
        // Find which mirror this book URL uses
        final uri = Uri.parse(book.url);
        final mirror = '${uri.scheme}://${uri.host}';
        downloadUrl = '$mirror$href';
      }
    }

    return book.copyWith(downloadUrl: downloadUrl);
  }

  /// Resolve the browser check challenge for a download URL.
  /// Returns cookies (including c_token) to use in the actual download request.
  Future<Map<String, String>> resolveDownloadCookies(String downloadUrl) async {
    print('ZLibraryApi: Resolving download cookies for $downloadUrl');
    final response = await _client.get(
      Uri.parse(downloadUrl),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36',
        'Cookie': _cookieHeader,
      },
    );

    if (response.statusCode == 503 &&
        response.body.contains('Checking your browser')) {
      print('ZLibraryApi: Download challenge encountered, solving...');
      final token = BrowserCheckSolver.solve(response.body);
      if (token != null) {
        print('ZLibraryApi: Download challenge solved. c_token=$token');
        _cookies['c_token'] = token;

        // Retry with c_token to validate it (streamed to avoid downloading the file)
        final retryRequest = http.Request('GET', Uri.parse(downloadUrl));
        retryRequest.headers['User-Agent'] =
            'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36';
        retryRequest.headers['Cookie'] = _cookieHeader;
        final retryResponse = await _client.send(retryRequest);
        print(
            'ZLibraryApi: Download retry status: ${retryResponse.statusCode}');

        // Update cookies from retry response
        final setCookie = retryResponse.headers['set-cookie'];
        if (setCookie != null) {
          final mockResponse = http.Response('', retryResponse.statusCode,
              headers: {'set-cookie': setCookie});
          _updateCookies(mockResponse);
        }

        // Drain the stream immediately — we don't need the file body here
        await retryResponse.stream.drain();
      } else {
        print('ZLibraryApi: Failed to solve download challenge.');
      }
    } else {
      _updateCookies(response);
    }

    return Map<String, String>.from(_cookies);
  }
}
