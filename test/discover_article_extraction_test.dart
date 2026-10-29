import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:lira/features/discover/data/discover_epub.dart';
import 'package:lira/features/discover/data/discover_feed_parser.dart';
import 'package:lira/features/discover/domain/discover_item.dart';

// Reduced raw publisher markup, fetched from the URLs below on 2026-10-29.
// Bodies, figure captions, chart selection queries and nuisance containers retain
// their published structure; image bytes are deterministic valid PNG resources.
const _urls = {
  'batrachospermum':
      'https://batrachospermum.ru/2026/08/acanthotrochus-verruciosseous/',
  'elementy':
      'https://elementy.ru/novosti_nauki/434442/Drevneyshiy_osminog_okazalsya_nautilusom',
  'our-world-in-data':
      'https://ourworldindata.org/how-much-development-aid-is-spent-on-climate-change',
  'jstor-daily': 'https://daily.jstor.org/londons-railway-for-the-dead/',
  'aeon':
      'https://aeon.co/essays/how-to-use-physics-to-make-sense-of-the-messiness-of-life',
  'mongabay':
      'https://news.mongabay.com/2026/10/between-revered-and-hunted-the-journey-of-human-otter-coexistence-in-the-amazon/',
};

const _batImage =
    'https://batrachospermum.ru/wp-content/uploads/2026/08/Acanthotrochus-verruciosseous.jpg';
const _elementyImage =
    'https://elementy.ru/images/news/synchrotron_data_reveal_nautiloid_characters_in_pohlsepia_mazonensis_0_703.jpg';
const _jstorImage =
    'https://daily.jstor.org/wp-content/uploads/2026/10/london_necropolis_1_1050.jpg';
const _aeonImage =
    'https://images.aeonmedia.co/user_image_upload/d7f9e604-cc15-471d-acaf-bb91effab751/inset-john-snow-map.jpg?width=3840&quality=75&format=auto';
const _mongabayImage =
    'https://imgs.mongabay.com/wp-content/uploads/sites/20/2026/10/29132036/48986521231_db81cc1534_k.jpg';
const _owidStaticImage =
    'https://ourworldindata.org/cdn-cgi/imagedelivery/qLq-8BTgXU8yG0N6HnOy8g/89f8a1db-ad3e-45a8-bcdc-d8d26cd9c600/w=1620';
const _relativeChart =
    'https://ourworldindata.org/grapher/aid-climate-mitigation-adaptation?stackMode=relative';
const _countryChart =
    'https://ourworldindata.org/grapher/share-foreign-aid-received-climate?country=IND~PHL~BGD~IDN~BRA~SLE~SEN~UGA~MDG';
const _podcast =
    'https://play.libsyn.com/embed/episode/id/43366819/height/128/theme/modern/size/standard/thumbnail/yes/custom-color/03755e/time-start/00:00:00/hide-playlist/yes/download/yes/font-color/FFFFFF';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGD4DwABBAEAX+XDSwAAAABJRU5ErkJggg==',
);

typedef _Built = ({
  Archive archive,
  dom.Document document,
  List<Uri> requested,
});

class _PublisherAdapter implements HttpClientAdapter {
  _PublisherAdapter(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);

  @override
  void close({bool force = false}) {}
}

Future<_Built> _build(
  String sourceId,
  Set<String> imageUrls, {
  String? markup,
}) async {
  final url = Uri.parse(_urls[sourceId]!);
  final requested = <Uri>[];
  final dio = Dio()
    ..httpClientAdapter = _PublisherAdapter((request) {
      requested.add(request.uri);
      if (request.uri == url) {
        return ResponseBody.fromString(markup ?? _markup[sourceId]!, 200);
      }
      if (imageUrls.contains(request.uri.toString())) {
        return ResponseBody.fromBytes(_png, 200);
      }
      throw StateError('Unexpected publisher resource: ${request.uri}');
    });
  late Uint8List bytes;
  try {
    bytes = await DiscoverEpubBuilder(dio).build(
      DiscoverItem(
        id: discoverMaterialId(url),
        sourceId: sourceId,
        title: sourceId,
        url: url,
        summary:
            'A feed summary must never replace the full publisher document.',
      ),
    );
  } finally {
    dio.close(force: true);
  }
  final archive = ZipDecoder().decodeBytes(bytes);
  final document = html.parse(
    utf8.decode(archive.findFile('EPUB/content.xhtml')!.content as List<int>),
  );
  for (final image in document.querySelectorAll('img')) {
    final src = image.attributes['src']!;
    expect(src, startsWith('images/'));
    expect(archive.findFile('EPUB/$src'), isNotNull);
  }
  expect(
    document.querySelector('script, iframe, [onclick], [onerror], [srcset]'),
    isNull,
  );
  expect(document.body!.text, isNot(contains('A feed summary')));
  return (archive: archive, document: document, requested: requested);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'OWID keeps its subtitle without repeating the title or citation controls',
    () async {
      final built = await _build(
        'our-world-in-data',
        {},
        markup: '''
<article><header class="centered-article-header">
<div class="centered-article-header__title-container"><h1>Publisher title</h1></div>
<h2 class="centered-article-header__subtitle">The question behind the data</h2>
<div class="centered-article-header__meta-container">By Publisher Author
<a href="#citation">Cite this article</a></div></header>
<p>This is a question I’ve had for a while. I care a lot about climate change.
I also care about basic health and development programs in the world’s poorest
countries, and how development aid is allocated between these priorities.</p>
</article>''',
      );
      expect(built.document.querySelectorAll('h1'), hasLength(1));
      expect(
        built.document.querySelector('h2')!.text,
        'The question behind the data',
      );
      expect(built.document.body!.text, isNot(contains('Publisher title')));
      expect(built.document.body!.text, isNot(contains('Cite this article')));
    },
  );

  test(
    'Batrachospermum retains Russian body, figure caption and research links',
    () async {
      final built = await _build('batrachospermum', {_batImage});
      expect(built.document.documentElement!.attributes['lang'], 'ru-RU');
      expect(built.document.body!.text, contains('Сантиметровая гантелька'));
      expect(
        built.document.querySelector('em')!.text,
        'Acanthotrochus verruciosseous',
      );
      expect(built.document.querySelectorAll('img'), hasLength(1));
      expect(
        built.document.querySelector('figcaption')!.text,
        contains('Безногая голотурия'),
      );
      expect(
        built.document.querySelector('a[href*="wikipedia.org"]'),
        isNotNull,
      );
      expect(built.document.body!.text, isNot(contains('Главная страничка')));
    },
  );

  test(
    'Elementy uses its document base and retains illustrations as captions',
    () async {
      final built = await _build('elementy', {_elementyImage});
      expect(built.document.body!.text, contains('Почти четверть века назад'));
      expect(built.document.querySelectorAll('figure'), hasLength(1));
      expect(built.document.querySelectorAll('img'), hasLength(1));
      expect(
        built.document.querySelector('figcaption')!.text,
        contains('Рисунок Франца Антони'),
      );
      expect(
        built.requested.map((url) => url.toString()),
        contains(_elementyImage),
      );
      expect(
        built.requested.any((url) => url.path.endsWith('zoomnw2.png')),
        isFalse,
      );
    },
  );

  test(
    'Elementy ignores credentialed and cross-publisher document bases',
    () async {
      for (final base in [
        'https://other.example/',
        'https://secret@elementy.ru/',
        'javascript:alert(1)',
      ]) {
        final markup = _markup['elementy']!.replaceFirst(
          '//elementy.ru/',
          base,
        );
        final image = Uri.parse(_urls['elementy']!).resolve(
          'images/news/synchrotron_data_reveal_nautiloid_characters_in_pohlsepia_mazonensis_0_703.jpg',
        );
        final built = await _build('elementy', {
          image.toString(),
        }, markup: markup);
        expect(
          built.requested.every((uri) => uri.host == 'elementy.ru'),
          isTrue,
        );
        expect(built.requested.every((uri) => uri.userInfo.isEmpty), isTrue);
      }
    },
  );

  test(
    'JSTOR excludes JPASS adverts, recirculation and signup before image fetch',
    () async {
      final built = await _build('jstor-daily', {_jstorImage});
      expect(built.document.body!.text, contains('London Necropolis Railway'));
      expect(
        built.document.querySelector('figcaption')!.text,
        contains('Enon Chapel was notorious'),
      );
      expect(built.document.querySelectorAll('img'), hasLength(1));
      for (final nuisance in [
        'More to Explore',
        'Weekly Newsletter',
        'JPASS',
      ]) {
        expect(built.document.body!.text, isNot(contains(nuisance)));
      }
      expect(built.requested, hasLength(2));
    },
  );

  test(
    'Aeon retains longform figures, captions, pull quotes and essay ending',
    () async {
      final built = await _build('aeon', {_aeonImage});
      expect(built.document.body!.text, contains('The senior partner'));
      expect(
        built.document.body!.text,
        contains('Physics shouldn’t be a shortcut'),
      );
      expect(
        built.document.querySelector('figcaption')!.text,
        contains('John Snow'),
      );
      expect(
        built.document.querySelector(
          'a[href="https://wellcomecollection.org/works/uxgfjt62"]',
        ),
        isNotNull,
      );
      expect(built.document.querySelectorAll('img'), hasLength(1));
      expect(
        built.document.body!.text,
        isNot(contains('Listen to this essay')),
      );
      expect(
        built.document.body!.text,
        isNot(contains('SYNDICATE THIS ESSAY')),
      );
    },
  );

  test(
    'Mongabay keeps headings, figures and media links, not editor avatars',
    () async {
      final built = await _build('mongabay', {_mongabayImage});
      expect(built.document.body!.text, contains('Baniwa men'));
      expect(built.document.querySelector('h2')!.text, contains('shamans'));
      expect(
        built.document.querySelector('figcaption')!.text,
        contains('Allan Hopkins'),
      );
      expect(built.document.querySelector('a[href="$_podcast"]'), isNotNull);
      expect(built.document.body!.text, isNot(contains('Credits')));
      expect(built.document.querySelectorAll('img'), hasLength(1));
      expect(built.requested, hasLength(2));
    },
  );

  test(
    'OWID charts keep offline pixels, chart state, source links and side notes',
    () async {
      final relativeImage = Uri.parse(
        _relativeChart,
      ).replace(path: '${Uri.parse(_relativeChart).path}.png').toString();
      final countryImage = Uri.parse(
        _countryChart,
      ).replace(path: '${Uri.parse(_countryChart).path}.png').toString();
      final built = await _build('our-world-in-data', {
        _owidStaticImage,
        relativeImage,
        countryImage,
      });
      expect(built.document.querySelectorAll('img'), hasLength(3));
      expect(
        built.document.querySelector(
          'h1#how-much-foreign-aid-is-climate-related',
        ),
        isNotNull,
      );
      expect(
        built.document.querySelector('blockquote')!.text,
        contains('official development assistance'),
      );
      final chartLinks = built.document
          .querySelectorAll('figcaption a[href]')
          .map((link) => Uri.parse(link.attributes['href']!));
      expect(
        chartLinks
            .singleWhere(
              (uri) => uri.path == '/grapher/aid-climate-mitigation-adaptation',
            )
            .queryParameters['stackMode'],
        'relative',
      );
      expect(
        chartLinks
            .singleWhere(
              (uri) =>
                  uri.path == '/grapher/share-foreign-aid-received-climate',
            )
            .queryParameters['country'],
        'IND~PHL~BGD~IDN~BRA~SLE~SEN~UGA~MDG',
      );
      expect(
        built.document.body!.text,
        isNot(contains('Continue reading on Our World in Data')),
      );
      expect(built.requested, hasLength(4));
    },
  );

  test('official OWID grapher iframes use publisher PNGs, other embeds stay links', () async {
    // The same published chart and state can also be embedded by its public URL.
    final chartImage = Uri.parse(
      _relativeChart,
    ).replace(path: '${Uri.parse(_relativeChart).path}.png').toString();
    final markup =
        '<article><p>'
        'This is a question I’ve had for a while. I care a lot about climate change. '
        'I also care a lot about basic health and development programs in the world’s '
        'poorest countries — vitamin supplementation, nutrition programs, antiretroviral '
        'treatment for HIV, and bed nets treated against malaria.</p>'
        '<iframe src="$_relativeChart" title="Foreign aid given for climate mitigation and adaptation"></iframe>'
        '<iframe src="https://ourworldindata.org/explorers/energy" title="Energy explorer"></iframe>'
        '<iframe src="https://ourworldindata.org.evil.example/grapher/aid" title="Other embed"></iframe>'
        '</article>';
    final built = await _build('our-world-in-data', {
      chartImage,
    }, markup: markup);
    expect(built.document.querySelectorAll('img'), hasLength(1));
    expect(
      built.document
          .querySelector('figcaption a[href="$_relativeChart"]')!
          .text,
      'Foreign aid given for climate mitigation and adaptation',
    );
    expect(
      built.document.querySelector(
        'a[href="https://ourworldindata.org/explorers/energy"]',
      ),
      isNotNull,
    );
    expect(built.requested, hasLength(2));
  });
}

const _markup = <String, String>{
  'batrachospermum':
      r'''<!doctype html><html lang="ru-RU"><head></head><body><nav>Главная страничка</nav><article><div class="entry-content"><p>Сантиметровая гантелька с колесиками обнаружена в тихоокеанской донной пучине на глубине более 5 км в районе Алеутского желоба – голотурия <em>Acanthotrochus verruciosseous</em>. У нее 12 щупалец с 5–6 пальцами на каждом, а кожа усеяна известковыми колесовидными косточками с наплывами и колючками. Красота!</p><figure aria-describedby="caption-attachment-8505" class="wp-caption aligncenter" id="attachment_8505" style="width: 700px"><img alt="" class="wp-image-8505 size-full" decoding="async" fetchpriority="high" height="588" sizes="(max-width: 700px) 100vw, 700px" src="https://batrachospermum.ru/wp-content/uploads/2026/08/Acanthotrochus-verruciosseous.jpg" srcset="https://batrachospermum.ru/wp-content/uploads/2026/08/Acanthotrochus-verruciosseous.jpg 700w, https://batrachospermum.ru/wp-content/uploads/2026/08/Acanthotrochus-verruciosseous-300x252.jpg 300w, https://batrachospermum.ru/wp-content/uploads/2026/08/Acanthotrochus-verruciosseous-357x300.jpg 357w" width="700"/><figcaption class="wp-caption-text" id="caption-attachment-8505">Безногая голотурия Acanthotrochus verruciosseous из Алеутского желоба на севере Тихого океана, а также покровные косточки отдельно и пример одной из них (акантотрохидной разновидности).</figcaption></figure><p>Голотурии, или <a href="https://ru.wikipedia.org/wiki/%D0%93%D0%BE%D0%BB%D0%BE%D1%82%D1%83%D1%80%D0%B8%D0%B8" rel="noopener" target="_blank">морские огурцы</a> (класс Holothuroidea), относятся к типу иглокожих, а <a href="https://ru.wikipedia.org/wiki/%D0%91%D0%B5%D0%B7%D0%BD%D0%BE%D0%B3%D0%B8%D0%B5_%D0%B3%D0%BE%D0%BB%D0%BE%D1%82%D1%83%D1%80%D0%B8%D0%B8" rel="noopener" target="_blank">безногие</a> (отряд Apodida) – самая древняя их эволюционная ветвь (к безногнм как раз и относится рассматриваемый огурчик), а семейство <a href="https://ru.wikipedia.org/wiki/Myriotrochidae" rel="noopener" target="_blank">Myriotrochidae</a> – обособленная веточка этого отряда, сестринская всем остальным семействам, а род <em>Acanthotrochus</em> – один из редчайших в семействе и весьма самобытный в плане морфологии.</p></div></article></body></html>''',
  'elementy':
      r'''<!doctype html><html lang="ru"><head><base href="//elementy.ru/"/></head><body><div class="itemblock"><div class="memo"><div class="ill_block ins_block center_ins_block ilarge cmt">
<a href="https://elementy.ru/images/news/synchrotron_data_reveal_nautiloid_characters_in_pohlsepia_mazonensis_0_1108.jpg" onclick="return pict_popup('https://elementy.ru/images/news/synchrotron_data_reveal_nautiloid_characters_in_pohlsepia_mazonensis_0_1108.jpg','Эту грустную картину можно было наблюдать на дне моря в каменноугольном периоде 310 млн лет назад: умерший головоногий моллюск выпал из своей раковины и тихо разлагается в донном иле')" target="_blank">
<div align="center" class="img"><span class="bcimg">
<img alt="Эту грустную картину можно было наблюдать на дне моря в каменноугольном периоде 310 млн лет назад: умерший головоногий моллюск выпал из своей раковины и тихо разлагается в донном иле" border="0" src="images/news/synchrotron_data_reveal_nautiloid_characters_in_pohlsepia_mazonensis_0_703.jpg"/>
<span class="zoom"><img alt="" border="0" height="27" src="images/eltnewdesign/zoomnw2.png" width="27"/></span>
</span></div>
</a>
<div align="left" class="comment"><p>Эту грустную картину можно было наблюдать на дне моря в каменноугольном периоде 310 млн лет назад: умерший головоногий моллюск выпал из своей раковины и тихо разлагается в донном иле. Однако разложение не зайдет слишком далеко, он станет окаменелостью и загадкой для палеонтологов. Рисунок Франца Антони (Franz Anthony) из обсуждаемой статьи</p></div>
</div><p class="intro">Почти четверть века назад, в 2000 году, на территории знаменитого местонахождения Мазон-Крик в США нашли хорошо сохранившийся отпечаток, похожий на небольшого осьминога. Отпечаток располагался в середине плоской сидеритовой конкреции и имел длину всего лишь 3,5 см. Однако на нем были хорошо видны округлое тело с небольшими щупальцами, челюсти, маленькие глаза и два небольших плавника в верхней части туловища. Находка получила имя <i>Pohlsepia mazonensis</i> и была отнесена к цирратным осьминогам. Действительно, многие глубоководные цирратные осьминоги имеют похожий план строения: «плавающий шарик» с небольшими руками-щупальцами и парой плавников на верхнем конце тела. Однако слои, в которых была сделана находка, датируются каменноугольным периодом и имеют возраст около 310 млн лет, а древнейший на тот момент ископаемый осьминог был известен из верхнего мела (85 млн лет). Новая находка расширяла эволюционную историю осьминогов на целых 225 миллионов лет. Палеонтологами такой громадный «временной скачок» был встречен настороженно, многие не признали <i>Pohlsepia</i> осьминогом. Однако биологи и специалисты по молекулярному датированию в основном приняли эту находку и использовали ее для калибровки своих датировок. К счастью, быстро развивающиеся современные технологии исследования окаменелостей позволили детально изучить единственный известный экземпляр <i>Pohlsepia</i> и обнаружить очень важные детали его строения, которые не удавалось заметить, используя менее совершенные методики. Благодаря этому исследователи установили, что <i>Pohlsepia</i> — вовсе не осьминог, а наутилус, выпавший из своей раковины до захоронения.</p></div></div></body></html>''',
  'jstor-daily':
      r'''<!doctype html><html lang="en"><head></head><body><article><div class="entry-content"><div class="j-icon">
								The <span class="jcitation"></span> icon indicates free access to the linked research on JSTOR.
							</div><p>The final journey for London’s dead, circa 1860, was a trip on the London Necropolis Railway. The train would take the corpse and the accompanying mourners out of the city to the sprawling Brookwood Cemetery, where they had their pick of <a class="jcitation" href="https://www.jstor.org/stable/1586489?mag=londons-railway-for-the-dead">two stations</a>: one for Anglicans, one for Non-Conformists. The deceased rode first, second, or third class (to avoid posthumous intermingling of rich and poor). But naturally, all coffin tickets were one way only.</p><p class='“jpass-incontent-banner"'><a href="https://www.jstor.org/action/jpass?lookupKey=SlBBU1MtSS1ZZWFy&amp;discountCode=SlNUT1JEQUlMWTI1&amp;utm_source=jstor_daily&amp;utm_campaign=daily_newsletter_annual_25"><img alt="“JPASS”" class="size-full wp-image-305864 show-for-large" decoding="async" height="196" src="https://daily.jstor.org/wp-content/uploads/2026/05/jpass_discount_25_desktop_2100.avif" width="800"/><img alt="“JPASS”" class="hide-for-large" src="https://daily.jstor.org/wp-content/uploads/2026/05/jpass_discount_25_mobile2.avif"/></a></p><figure aria-describedby="caption-attachment-338962" class="wp-caption aligncenter" id="attachment_338962" style="width: 1050px"><img alt="Enon Chapel was notorious for the reek of coffins just below the church floorboards" class="size-full wp-image-338962" decoding="async" fetchpriority="high" height="662" src="https://daily.jstor.org/wp-content/uploads/2026/10/london_necropolis_1_1050.jpg" width="1050"/><figcaption class="wp-caption-text" id="caption-attachment-338962">Enon Chapel was notorious for the reek of coffins just below the church floorboards. via <a href="https://commons.wikimedia.org/wiki/File:G.A._Walker,_Lectures_on_the_metropolitan_grave-yards._Wellcome_L0025698.jpg">Wikimedia Commons</a></figcaption></figure><div class="daily-explore story-list more-to-explore bg-color-gray">
<h2 class="story-list-header">More to Explore</h2>
<div class="article-tease image-left default">
<div class="article-tease__featured-image">
<a href="https://daily.jstor.org/a-mother-superiors-demons/">
<img alt="Soeur Jeanne by Charles Emmanuel Patas after Charles Monnet" class="wp-post-image" decoding="async" height="700" src="https://daily.jstor.org/wp-content/uploads/2024/10/a_mother_superiors_demons_1050x700.jpg" width="1050"/> </a>
</div>
<div class="article-tease__text">
<h3><a href="https://daily.jstor.org/a-mother-superiors-demons/">A Mother Superior’s Demons</a></h3> <div class="byline">
<a href="https://daily.jstor.org/daily-author/amelia-soth/">Amelia Soth</a>
</div> <div class="article-date">
					October 31, 2024				</div>
<div class="subtitle">What does it mean when an entire convent of Urusline nuns appears to be possessed by demons? Many things, as it turns out.</div> </div>
</div>
</div><div class="daily_email_signup weekly-digest"><h4>Weekly Newsletter</h4><input autocomplete="new-password" id="input_17_6" name="input_6" type="text" value=""/></div></div></article></body></html>''',
  'aeon':
      r'''<!doctype html><html lang="en"><head></head><body><div class="article-content" id="article-content"><audio></audio><div class="flex print:hidden"><button title="Play">Play</button><p>Listen to this essay</p></div><div class="has-dropcap"><p>The senior partner didn’t waste any time. ‘I’m sorry, Zahaan,’ he said, ‘your services are no longer required at the firm.’ We sometimes called him the Burger King behind his back, because he ate a Whopper Meal at his desk every day. I’d never spoken to him before, and now I never would again.</p><figure><img alt="Historic map of central London with marked locations, black and white with red dots, shows detailed street layout, 19th century." class="ld-image-block" data-nimg="1" decoding="async" height="880" loading="lazy" sizes="(max-width: 640px) 100vw, (max-width: 1440px) 60vw, 880px" src="https://images.aeonmedia.co/user_image_upload/d7f9e604-cc15-471d-acaf-bb91effab751/inset-john-snow-map.jpg?width=3840&amp;quality=75&amp;format=auto" srcset="https://images.aeonmedia.co/user_image_upload/d7f9e604-cc15-471d-acaf-bb91effab751/inset-john-snow-map.jpg?width=384&amp;quality=75&amp;format=auto 384w, https://images.aeonmedia.co/user_image_upload/d7f9e604-cc15-471d-acaf-bb91effab751/inset-john-snow-map.jpg?width=640&amp;quality=75&amp;format=auto 640w, https://images.aeonmedia.co/user_image_upload/d7f9e604-cc15-471d-acaf-bb91effab751/inset-john-snow-map.jpg?width=750&amp;quality=75&amp;format=auto 750w, https://images.aeonmedia.co/user_image_upload/d7f9e604-cc15-471d-acaf-bb91effab751/inset-john-snow-map.jpg?width=828&amp;quality=75&amp;format=auto 828w, https://images.aeonmedia.co/user_image_upload/d7f9e604-cc15-471d-acaf-bb91effab751/inset-john-snow-map.jpg?width=1080&amp;quality=75&amp;format=auto 1080w, https://images.aeonmedia.co/user_image_upload/d7f9e604-cc15-471d-acaf-bb91effab751/inset-john-snow-map.jpg?width=1200&amp;quality=75&amp;format=auto 1200w, https://images.aeonmedia.co/user_image_upload/d7f9e604-cc15-471d-acaf-bb91effab751/inset-john-snow-map.jpg?width=1920&amp;quality=75&amp;format=auto 1920w, https://images.aeonmedia.co/user_image_upload/d7f9e604-cc15-471d-acaf-bb91effab751/inset-john-snow-map.jpg?width=2048&amp;quality=75&amp;format=auto 2048w, https://images.aeonmedia.co/user_image_upload/d7f9e604-cc15-471d-acaf-bb91effab751/inset-john-snow-map.jpg?width=3840&amp;quality=75&amp;format=auto 3840w" style="color:transparent" width="880"/><figcaption class="ld-image-caption"><p>Map from <em>Report on the Cholera Outbreak in the Parish of St James, Westminster, During the Autumn of 1854 </em>by John Snow. Cholera cases are represented by black rectangles, with clusters of cases indicated by stacked rectangles. The contaminated water pump is marked in green, while surrounding water pumps are marked in red. Courtesy the <a href="https://wellcomecollection.org/works/uxgfjt62" rel="noreferrer noopener" target="_blank">Wellcome Collection</a>, London/colour annotations by Aeon</p></figcaption></figure><p class="pullquote">For the first time in years, physics seems to be at the heart of the cultural zeitgeist</p><p>I started this essay as a young man being shown the door by a superior. I ended it somewhere else entirely, with physics as a way of making sense of the messiest parts of life. But, really, what I’ve been edging up to is a story about how certain hardwon habits of mind can help us find meaning in the messiness and unpredictability of reality. For those of us who are not professional scientists, maybe the real task isn’t to love physics uncritically, or wield it carelessly, but to use it wisely. Physics shouldn’t be a shortcut to rock-solid certainty, so much as a way to live more humanely <span class="ld-nowrap">without it.</span></p></div><div class="no-pagemarks">SYNDICATE THIS ESSAY</div></div></body></html>''',
  'mongabay':
      r'''<!doctype html><html lang="en"><head></head><body><article id="post-334366"><p>On a warm, humid morning, along the Içana River in Brazil’s upper Rio Negro Basin, researchers observed a group of Baniwa men heading to the river to check the fishing traps they left in shallow, fast-moving waters.</p><p>Slightly further downstream, a group of giant otters (<em>Pteronura brasiliensis</em>) was also hunting.</p><figure class="wp-caption aligncenter" id="attachment_334372"><a data-wpel-link="external" href="https://imgs.mongabay.com/wp-content/uploads/sites/20/2026/10/29132036/48986521231_db81cc1534_k.jpg" rel="external" target="_blank"><img alt="Giant otters tend to live in groups of between nine and 12 family members. " class="size-full wp-image-334372" decoding="async" fetchpriority="high" height="1367" sizes="(max-width: 2048px) 100vw, 2048px" src="https://imgs.mongabay.com/wp-content/uploads/sites/20/2026/10/29132036/48986521231_db81cc1534_k.jpg" srcset="https://imgs.mongabay.com/wp-content/uploads/sites/20/2026/10/29132036/48986521231_db81cc1534_k.jpg 2048w, https://imgs.mongabay.com/wp-content/uploads/sites/20/2026/10/29132036/48986521231_db81cc1534_k-768x513.jpg 768w, https://imgs.mongabay.com/wp-content/uploads/sites/20/2026/10/29132036/48986521231_db81cc1534_k-1200x801.jpg 1200w, https://imgs.mongabay.com/wp-content/uploads/sites/20/2026/10/29132036/48986521231_db81cc1534_k-1536x1025.jpg 1536w, https://imgs.mongabay.com/wp-content/uploads/sites/20/2026/10/29132036/48986521231_db81cc1534_k-350x233.jpg 350w, https://imgs.mongabay.com/wp-content/uploads/sites/20/2026/10/29132036/48986521231_db81cc1534_k-610x407.jpg 610w" width="2048"/></a><figcaption class="wp-caption-text">Giant otters tend to live in groups of between nine and 12 family members. Image by Allan Hopkins via <a data-wpel-link="external" href="https://www.flickr.com/photos/hoppy1951/48986521231/" rel="external" target="_blank">Flickr</a> (<a data-wpel-link="external" href="https://creativecommons.org/licenses/by-nc-nd/2.0/deed.en" rel="external" target="_blank">CC BY-NC-ND 2.0</a>).</figcaption></figure><h2><strong>Otters, the ‘shamans’ of the rivers</strong></h2><iframe src="https://play.libsyn.com/embed/episode/id/43366819/height/128/theme/modern/size/standard/thumbnail/yes/custom-color/03755e/time-start/00:00:00/hide-playlist/yes/download/yes/font-color/FFFFFF" title="Embed Player"></iframe><div id="single-article-footer"><h4>Credits</h4><div class="author-avatar">
<img alt="" class="avatar avatar-32 photo" decoding="async" height="32" loading="lazy" src="https://secure.gravatar.com/avatar/9531f703a49264638b21e9cee471685031b1a88a2bad9fbe9fb1cc3a216071d4?s=32&amp;d=identicon&amp;r=g" srcset="https://secure.gravatar.com/avatar/9531f703a49264638b21e9cee471685031b1a88a2bad9fbe9fb1cc3a216071d4?s=64&amp;d=identicon&amp;r=g 2x" width="32"/> </div></div></article></body></html>''',
  'our-world-in-data':
      r'''<!doctype html><html lang="en"><head></head><body><article class="centered-article-container"><div class="centered-article-header__breadcrumbs-container col-start-4 span-cols-8 col-md-start-2 span-md-cols-12"><div class="centered-article-header__breadcrumbs breadcrumbs-blue"><a href="https://ourworldindata.org/">Home</a><span class="separator"><svg aria-hidden="true" class="svg-inline--fa fa-angle-right" data-icon="angle-right" data-prefix="fas" role="img" viewbox="0 0 256 512"><path d="M247.1 233.4c12.5 12.5 12.5 32.8 0 45.3l-160 160c-12.5 12.5-32.8 12.5-45.3 0s-12.5-32.8 0-45.3L179.2 256 41.9 118.6c-12.5-12.5-12.5-32.8 0-45.3s32.8-12.5 45.3 0l160 160z" fill="currentColor"></path></svg></span><a data-track-note="breadcrumb" href="https://ourworldindata.org/climate-change">Climate Change</a></div></div><p class="article-block__text col-start-5 span-cols-6 col-md-start-3 span-md-cols-10 span-sm-cols-12 col-sm-start-2"><span class="">This is a question I’ve had for a while. I care a lot about climate change. I also care a lot about basic health and development programs in the world’s poorest countries — vitamin supplementation, nutrition programs, antiretroviral treatment for HIV, and bed nets treated against malaria.</span></p><h1 class="h1-semibold article-block__heading col-start-5 span-cols-6 col-md-start-3 span-md-cols-10 span-sm-cols-12 col-sm-start-2" id="how-much-foreign-aid-is-climate-related"><span class="">How much foreign aid is climate-related?</span><a class="deep-link" href="#how-much-foreign-aid-is-climate-related"></a></h1><aside class="body-3-medium-italic article-block__aside article-block__aside--right col-start-11 span-cols-3 span-md-cols-10 col-md-start-3 span-sm-cols-12 col-sm-start-2"><span class="article-block__aside-label">Aside: </span><span class="">Throughout this article, “aid” refers to </span><span class="dod-span" data-id="oda" tabindex="0"><span class="">official development assistance (ODA)</span></span><span class="">.</span></aside><figure class="article-block__image article-block__image--narrow col-start-5 span-cols-6 col-md-start-3 span-md-cols-10 col-sm-start-2 span-sm-cols-12"><div class="image image--has-outline"><picture><img alt="Stacked bar chart of 2024 bilateral development aid where about a third of allocable aid, $50 billion of $145 billion, goes to climate-related projects. Of the $210 billion total, $65 billion is non-allocable. Climate-related aid is split among mitigation only, adaptation only, and projects that address both. Source: OECD Rio Markers and Creditor Reporting System. License: CC BY to Our World in Data." class="lightbox-image" height="1620" loading="lazy" src="https://ourworldindata.org/cdn-cgi/imagedelivery/qLq-8BTgXU8yG0N6HnOy8g/89f8a1db-ad3e-45a8-bcdc-d8d26cd9c600/w=1620" width="1620"/></picture><div class="article-block__image-download-button-container"><button aria-label="Download" class="article-block__image-download-button"><div class="article-block__image-download-button-background-layer"><svg aria-hidden="true" class="svg-inline--fa fa-download article-block__image-download-button-icon" data-icon="download" data-prefix="fas" role="img" viewbox="0 0 448 512"><path d="M256 32c0-17.7-14.3-32-32-32s-32 14.3-32 32l0 210.7-41.4-41.4c-12.5-12.5-32.8-12.5-45.3 0s-12.5 32.8 0 45.3l96 96c12.5 12.5 32.8 12.5 45.3 0l96-96c12.5-12.5 12.5-32.8 0-45.3s-32.8-12.5-45.3 0L256 242.7 256 32zM64 320c-35.3 0-64 28.7-64 64l0 32c0 35.3 28.7 64 64 64l320 0c35.3 0 64-28.7 64-64l0-32c0-35.3-28.7-64-64-64l-46.9 0-56.6 56.6c-31.2 31.2-81.9 31.2-113.1 0L110.9 320 64 320zm304 56a24 24 0 1 1 0 48 24 24 0 1 1 0-48z" fill="currentColor"></path></svg><span class="article-block__image-download-button-text">Download</span></div></button></div></div></figure><div class="article-block__chart article-block__chart--wide col-start-4 span-cols-8 col-md-start-3 span-md-cols-10 span-sm-cols-12 col-sm-start-2 full-width-on-mobile"><div class="owid-chart-frame"><div class="GrapherWithFallback full-width-on-mobile"><figure aria-hidden="false" class="chart GrapherWithFallback__fallback"><picture class="js--hide-if-js-enabled"><source id="grapher-preview-source" sizes="(max-width: 850px) 100vw, 850px" srcset="https://ourworldindata.org/grapher/aid-climate-mitigation-adaptation.png?stackMode=relative&amp;imWidth=850 850w, https://ourworldindata.org/grapher/aid-climate-mitigation-adaptation.png?stackMode=relative&amp;imWidth=1700 1700w"/><img class="GrapherImage" height="600" loading="lazy" src="https://ourworldindata.org/grapher/aid-climate-mitigation-adaptation.png?stackMode=relative" width="850"/></picture></figure></div></div></div><div class="article-block__chart article-block__chart--wide col-start-4 span-cols-8 col-md-start-3 span-md-cols-10 span-sm-cols-12 col-sm-start-2 full-width-on-mobile"><div class="owid-chart-frame"><div class="GrapherWithFallback full-width-on-mobile"><figure aria-hidden="false" class="chart GrapherWithFallback__fallback"><picture class="js--hide-if-js-enabled"><source id="grapher-preview-source" sizes="(max-width: 850px) 100vw, 850px" srcset="https://ourworldindata.org/grapher/share-foreign-aid-received-climate.png?country=IND~PHL~BGD~IDN~BRA~SLE~SEN~UGA~MDG&amp;imWidth=850 850w, https://ourworldindata.org/grapher/share-foreign-aid-received-climate.png?country=IND~PHL~BGD~IDN~BRA~SLE~SEN~UGA~MDG&amp;imWidth=1700 1700w"/><img class="GrapherImage" height="600" loading="lazy" src="https://ourworldindata.org/grapher/share-foreign-aid-received-climate.png?country=IND~PHL~BGD~IDN~BRA~SLE~SEN~UGA~MDG" width="850"/></picture></figure></div></div></div><div class="recirc"><span class="recirc__heading body-3-bold">Continue reading on Our World in Data</span><li class="hybrid-link-item"><a class="hybrid-link-item__link" href="https://ourworldindata.org/what-is-foreign-aid"><div class="image hybrid-link-thumbnail"><picture><source sizes="350px" srcset="https://ourworldindata.org/cdn-cgi/imagedelivery/qLq-8BTgXU8yG0N6HnOy8g/45c115b3-453b-4d01-6ded-31b0e8570700/w=48 48w, https://ourworldindata.org/cdn-cgi/imagedelivery/qLq-8BTgXU8yG0N6HnOy8g/45c115b3-453b-4d01-6ded-31b0e8570700/w=100 100w, https://ourworldindata.org/cdn-cgi/imagedelivery/qLq-8BTgXU8yG0N6HnOy8g/45c115b3-453b-4d01-6ded-31b0e8570700/w=350 350w, https://ourworldindata.org/cdn-cgi/imagedelivery/qLq-8BTgXU8yG0N6HnOy8g/45c115b3-453b-4d01-6ded-31b0e8570700/w=850 850w, https://ourworldindata.org/cdn-cgi/imagedelivery/qLq-8BTgXU8yG0N6HnOy8g/45c115b3-453b-4d01-6ded-31b0e8570700/w=1200 1200w"/><img alt="A line graph features multiple colored lines, each representing a different data set over a continuous variable. The x-axis displays a measurement scale, likely indicating time or categories, while the y-axis represents a quantitative value. Several lines fluctuate in varying patterns; one line, colored purple, shows a significant increase toward the end, peaking higher than the others. Other lines include shades of blue, green, orange, and brown, which display more stable or moderate increases and decreases. The overall trend indicates a divergence in the datasets, with some lines remaining relatively stable while others experience considerable changes." height="630" loading="lazy" src="https://ourworldindata.org/cdn-cgi/imagedelivery/qLq-8BTgXU8yG0N6HnOy8g/45c115b3-453b-4d01-6ded-31b0e8570700/w=1200" width="1200"/></picture></div><div class="hybrid-link-item-text"><h4>What is foreign aid? How “Official Development Assistance” is measured</h4><p>Foreign aid measurement is complicated — what exactly counts as Official Development Assistance, what doesn’t, and how much is actually spent abroad?</p></div></a></li></div></article></body></html>''',
};
