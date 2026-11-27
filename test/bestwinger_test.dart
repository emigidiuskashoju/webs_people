import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webs_people/features/bestwinger/bw_api.dart';
import 'package:webs_people/features/bestwinger/bw_delivery_screen.dart';
import 'package:webs_people/features/bestwinger/bw_links.dart';
import 'package:webs_people/features/bestwinger/bw_track_screen.dart';

// Real JSON produced by the Shopicky website (tests/Feature/WebsAppApiTest.php)
Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Map<String, dynamic>;

const _sellerLink =
    'https://shopicky.webzapp.org/orders/12/respond?by=seller&decision=deliver&expires=1796739641&signature=abc123';

void main() {
  group('Reading Shopicky orders', () {
    test('buyer view (/track?code=)', () {
      final o = BwOrder.fromJson(_fixture('bestwinger_track.json')['order'] as Map<String, dynamic>);
      expect(o.code, 'BW-3FLKNE');
      expect(o.product, 'Red Sneakers');
      expect(o.trackable, isTrue);
      expect(o.quantity, 2);
      expect(o.shop.name, 'Fave Collection');
      expect(o.shop.point!.latitude, closeTo(-6.7735, 1e-6));
      expect(o.buyer.point!.longitude, closeTo(39.212, 1e-6));
      expect(o.buyer.live, isTrue);
      expect(o.courier!.point!.latitude, closeTo(-6.752, 1e-6));
      expect(o.courier!.moving, isFalse); // accepted: "seller's location", not yet on the way
      expect(o.courier!.photoUrl, startsWith('http'));
    });

    test('seller view (secure email link)', () {
      final body = _fixture('bestwinger_seller.json');
      expect(body['by'], 'seller');
      final o = BwOrder.fromJson(body['order'] as Map<String, dynamic>);
      expect(o.product, 'Red Sneakers'); // "product" key on this page
      expect(o.buyerPhone, '0655 111 222');
      expect(o.shopName, 'Fave Collection');
      expect(o.trackable, isTrue);
    });

    test('missing positions are simply empty', () {
      final o = BwOrder.fromJson({
        'code': 'BW-AAAAAA',
        'status': 'accepted',
        'map': {'shop': {'name': 'S', 'lat': null, 'lng': null}, 'buyer': {'name': 'B'}, 'courier': null},
      });
      expect(o.shop.point, isNull);
      expect(o.buyer.point, isNull);
      expect(o.courier, isNull);
    });
  });

  group('Links', () {
    test('only secure Shopicky order links are accepted', () {
      // links in emails sent before the rename still work
      expect(BwApi.isSellerLink(_sellerLink.replaceFirst('shopicky.webzapp.org', 'bestwinger.webzapp.org')), isTrue);
      expect(BwApi.isSellerLink(_sellerLink.replaceFirst('shopicky.webzapp.org', 'shoopicky.webzapp.org')), isTrue);
      expect(BwApi.isSellerLink(_sellerLink), isTrue);
      expect(BwApi.isSellerLink(_sellerLink.replaceFirst('https', 'http')), isFalse);
      expect(BwApi.isSellerLink(_sellerLink.replaceFirst('shopicky.webzapp.org', 'evil.example.com')), isFalse);
      expect(BwApi.isSellerLink('https://shopicky.webzapp.org/orders/12/respond?by=seller'), isFalse); // no signature
      expect(BwApi.isSellerLink('https://shopicky.webzapp.org/admin/orders?signature=x'), isFalse);
    });

    test('"Track in Webs" links open the right screen', () {
      final buyer = BwLinks.screenFor(Uri.parse('webs://bw/track?code=bw-3flkne'));
      expect(buyer, isA<BwDeliveryScreen>());
      expect((buyer as BwDeliveryScreen).code, 'BW-3FLKNE');
      expect(buyer.isSeller, isFalse);

      final seller = BwLinks.screenFor(Uri.parse('webs://bw/deliver?link=${Uri.encodeComponent(_sellerLink)}'));
      expect((seller as BwDeliveryScreen).isSeller, isTrue);
      expect(seller.link, _sellerLink);

      final https = BwLinks.screenFor(Uri.parse('https://webzapp.org/p/bw/track?code=BW-3FLKNE'));
      expect((https as BwDeliveryScreen).code, 'BW-3FLKNE');
      // new SP- codes open too
      final sp = BwLinks.screenFor(Uri.parse('webs://bw/track?code=SP-7Q3K9P'));
      expect((sp as BwDeliveryScreen).code, 'SP-7Q3K9P');
    });

    test('other links are ignored', () {
      expect(BwLinks.screenFor(Uri.parse('webs://bw/track?code=hello')), isNull);
      expect(BwLinks.screenFor(Uri.parse('webs://bw/deliver?link=https://evil.example.com/x')), isNull);
      expect(BwLinks.screenFor(Uri.parse('https://webzapp.org/p/somebody')), isNull);
      expect(BwLinks.screenFor(Uri.parse('webs://other/track?code=BW-3FLKNE')), isNull);
    });

    test('website link for the same order', () {
      expect(BwApi.websiteTrackUrl(' bw-3flkne'), 'https://shopicky.webzapp.org/track?code=BW-3FLKNE&map=1');
    });
  });

  group('Screens', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('Track tab: code box, Visit Shopicky, validation', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: BwTrackScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Track'), findsOneWidget);
      expect(find.text('Meet on the map'), findsOneWidget);
      expect(find.text('Track on the map'), findsOneWidget);
      await tester.dragUntilVisible(find.text('Visit Shopicky'), find.byType(ListView), const Offset(0, -200));
      expect(find.text('Visit Shopicky'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.tap(find.text('Track on the map'));
      await tester.pump();
      expect(find.text('Enter your tracking code, like SP-7Q3K9P'), findsOneWidget);
    });

    testWidgets('Delivery screen shows the same order as the website', (tester) async {
      final client = MockClient((req) async {
        if (req.url.host == 'shopicky.webzapp.org' && req.url.path == '/track') {
          expect(req.url.queryParameters['code'], 'BW-3FLKNE');
          expect(req.headers['Accept'], 'application/json');
          return http.Response(File('test/fixtures/bestwinger_track.json').readAsStringSync(), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('', 404); // map tiles, directions: offline in tests
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: BwDeliveryScreen.buyer(code: 'BW-3FLKNE')));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
      }, () => client);

      expect(find.text('Order BW-3FLKNE'), findsOneWidget);
      expect(find.text('2 × Red Sneakers'), findsOneWidget);
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.textContaining("Seller's location"), findsOneWidget);
      expect(find.text('Share my live location with the seller'), findsOneWidget);
      expect(find.text('Open on the Shopicky website'), findsOneWidget);

      // Leave the screen so its 10-second refresh timer stops
      await tester.pumpWidget(const SizedBox());
    });
  });
}
