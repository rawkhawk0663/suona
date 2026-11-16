import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:suona/core/character/character_art.dart';
import 'package:suona/core/game/adventure.dart';
import 'package:suona/core/game/badges.dart';
import 'package:suona/core/game/difficulty.dart';
import 'package:suona/core/game/question.dart';
import 'package:suona/core/game/shop.dart';
import 'package:suona/core/music/curriculum.dart';
import 'package:suona/core/music/note_names.dart';
import 'package:suona/core/profiles/profile.dart';

void main() {
  group('Stationen und Lehrplan', () {
    test('9 Schritte auf 8 Stationen: alles verteilt, nichts doppelt', () {
      final ranges = [for (var s = 0; s < 8; s++) Adventure.stepsOf(s, 9)];
      expect(ranges.first, (0, 0));
      expect(ranges.last, (7, 8));
      for (var s = 1; s < 8; s++) {
        expect(ranges[s].$1, ranges[s - 1].$2 + 1);
      }
    });

    test('Wenige Schritte: Stationen wiederholen', () {
      for (var s = 0; s < 8; s++) {
        final (a, b) = Adventure.stepsOf(s, 3);
        expect(a, inInclusiveRange(0, 2));
        expect(b, greaterThanOrEqualTo(a));
      }
      expect(Adventure.stepsOf(7, 3).$2, 2);
    });

    test('Freischalten: Auftritt und Lehrplan-Schritt', () {
      final c = BuiltInCurricula.guitarTalks;
      final p = Profile(id: 'x', nickname: 'Mia', character: Character.luna, step: 0);
      expect(Adventure.levelOpen(p, c, 0, 0), isTrue);
      expect(Adventure.levelOpen(p, c, 0, 1), isFalse);
      for (var l = 0; l < 6; l++) {
        Adventure.record(p, c.id, 0, l, 2);
      }
      // Station 1 braucht Schritt 1 im Lehrplan.
      expect(Adventure.lockOf(p, c, 1), StationLock.teacher);
      p.step = 1;
      expect(Adventure.lockOf(p, c, 1), isNull);
      expect(Adventure.lockOf(p, c, 2), StationLock.previous);
    });

    test('Bestes Ergebnis zählt, erstes Schaffen gibt Bonus', () {
      final p = Profile(id: 'x', nickname: 'Mia', character: Character.luna);
      expect(Adventure.record(p, 'c', 0, 0, 1), isTrue);
      expect(Adventure.record(p, 'c', 0, 0, 3), isFalse);
      expect(Adventure.record(p, 'c', 0, 0, 2), isFalse);
      expect(Adventure.stars(p, 'c', 0, 0), 3);
      expect(Adventure.record(p, 'c', 0, 1, 0), isFalse);
      // Hin und zurück als Datei.
      final again = Profile.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
      expect(Adventure.stars(again, 'c', 0, 0), 3);
    });

    test('Level-Plan: Aufwärmen mit neuen Tönen, Auftritt gemischt mit Zeit', () {
      final c = BuiltInCurricula.guitarTalks;
      final warm = Adventure.plan(c, AccidentalStyle.mixed, 1, 0);
      expect(warm.pool.map((p) => p.key).toSet(), {'B3', 'C4', 'D4'});
      expect(warm.timeLimit, isNull);
      expect(warm.types, [QuestionType.nameFromStaff]);
      final concert = Adventure.plan(c, AccidentalStyle.mixed, 1, Adventure.concertLevel);
      expect(concert.pool.length, 6);
      expect(concert.length, 15);
      expect(concert.types.length, 4);
      expect(concert.timeLimit, isNotNull);
      // Zeitdruck wird mit jeder Station knapper.
      expect(Adventure.timeFor(7, 4)!.inSeconds, lessThan(Adventure.timeFor(2, 4)!.inSeconds));
    });

    test('Stufen: Mini hat mehr Zeit und ein geduldigeres Publikum als Profi', () {
      final c = BuiltInCurricula.guitarTalks;
      final mini = Adventure.plan(c, AccidentalStyle.mixed, 4, 4, Difficulty.mini);
      final pro = Adventure.plan(c, AccidentalStyle.mixed, 4, 4, Difficulty.pro);
      expect(mini.timeLimit!.inSeconds, greaterThan(pro.timeLimit!.inSeconds));
      expect(mini.crowdLoss, lessThan(pro.crowdLoss));
      expect(mini.crowdGain, greaterThan(pro.crowdGain));
      expect(mini.length, lessThan(pro.length));
      // Die Probe läuft für die Jüngsten länger ohne Zeit.
      expect(Adventure.timeFor(3, 1, Difficulty.mini), isNull);
      expect(Adventure.timeFor(3, 1, Difficulty.pro), isNotNull);
      // Nie weniger als 3 Sekunden.
      expect(Adventure.timeFor(7, 5, Difficulty.pro)!.inSeconds, greaterThanOrEqualTo(3));
      // Die Stufe wird gespeichert, ältere Spielstände bekommen Junior.
      final p = Profile(id: 'x', nickname: 'Mia', character: Character.luna, difficulty: Difficulty.mini);
      expect(Profile.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>).difficulty, Difficulty.mini);
      expect(Profile.fromJson({'id': 'y'}).difficulty, Difficulty.junior);
    });

    test('Sterne im Abenteuer', () {
      expect(Adventure.starsForRound(9, 10), 3);
      expect(Adventure.starsForRound(8, 10), 2);
      expect(Adventure.starsForRound(6, 10), 1);
      expect(Adventure.starsForRound(5, 10), 0);
    });
  });

  group('Shop', () {
    test('Kaufen kostet Münzen, nur einmal', () {
      final p = Profile(id: 'x', nickname: 'Mia', character: Character.luna, coins: 100);
      final beanie = Shop.byId('hat_beanie')!;
      expect(Shop.owns(p, beanie), isFalse);
      expect(Shop.buy(p, beanie), isTrue);
      expect(p.coins, 20);
      expect(Shop.buy(p, beanie), isFalse);
      expect(Shop.buy(p, Shop.byId('vest_leather')!), isFalse); // zu teuer
      expect(Shop.owns(p, Shop.byId('g_double')!), isTrue); // Grundgitarren gratis
    });
  });

  group('Aussehen', () {
    test('Als Datei, Figurwechsel gibt Grund-Look', () {
      final p = Profile(id: 'x', nickname: 'Mia', character: Character.luna);
      p.look = p.look.copyWith(hair: 'blue', hat: 'hat_beanie');
      final again = Profile.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
      expect(again.look.hair, 'blue');
      expect(again.look.hat, 'hat_beanie');
      again.character = Character.fuzz;
      expect(again.look.character, Character.fuzz);
      expect(again.look.hair, CharacterLook.defaults(Character.fuzz).hair);
    });

    test('Figur zusammensetzen: Farben und Teile eingesetzt', () {
      CharacterArt.loadFrom({
        for (final c in Character.values) c: File('assets/characters/${c.name}_template.svg').readAsStringSync(),
      }, jsonDecode(File('assets/characters/items.json').readAsStringSync()) as Map<String, dynamic>);
      final art = CharacterArt.instance;
      for (final c in Character.values) {
        final look = CharacterLook.defaults(c)
            .copyWith(hat: 'hat_crown', glasses: 'glasses_sun', vest: 'vest_jeans', guitar: 'g_star');
        final svg = art.svg(look);
        expect(svg.contains('{{'), isFalse, reason: 'alle Farben ersetzt');
        expect(svg.contains('<!--slot:guitar-->'), isFalse);
        expect(svg.contains('<!--slot:hat-->'), isFalse);
        expect(svg.contains('#8E6CEF'), isTrue); // Sternen-Gitarre
        expect(art.svg(look, face: true).contains('viewBox="5'), isTrue);
        // Jedes Shop-Teil (ausser Pedalen) gibt es für beide Figuren.
        for (final item in Shop.items.where((i) => i.slot != ShopSlot.pedal)) {
          final ok = switch (item.slot) {
            ShopSlot.guitar => art.hasGuitar(item.id),
            ShopSlot.amp => art.hasAmp(item.id),
            _ => art.hasItem(c, item.id),
          };
          expect(ok, isTrue, reason: '${item.id} für ${c.name}');
        }
        // Amp nur mit E-Gitarre, Halsschmuck wird eingesetzt.
        final rock = CharacterLook.defaults(c).copyWith(amp: 'amp_stack', neck: 'neck_chain');
        expect(art.svg(rock).contains('<!--slot:amp-->'), isFalse);
        expect(art.svg(rock).contains('<!--slot:neck-->'), isFalse);
        expect(art.svg(rock.copyWith(guitar: 'g_classic')).contains('<!--slot:amp-->'), isTrue);
        // Kette verdeckt das Shirt-Bild, Halstuch-freie Figur behält es.
        expect(art.svg(rock).contains('<!--slot:logo-->'), isFalse);
        expect(art.svg(CharacterLook.defaults(c)).contains('<!--slot:logo-->'), isTrue);
        // Unter grossen Hüten trägt Fuzz die flache Frisur, unter der Krone nicht.
        final cowboy = art.svg(CharacterLook.defaults(c).copyWith(hat: 'hat_cowboy'));
        final crown = art.svg(CharacterLook.defaults(c).copyWith(hat: 'hat_crown'));
        if (c == Character.fuzz) {
          expect(cowboy.contains('<!--slot:hairtop-->'), isFalse);
          expect(crown.contains('<!--slot:hairtop-->'), isTrue);
        }
      }
      // Akustisch laut Shop = akustisch laut Zeichnung.
      for (final g in Shop.inSlot(ShopSlot.guitar)) {
        expect(g.acoustic, art.isAcoustic(g.id), reason: g.id);
      }
    });

    test('Sets: jedes Teil gibt es im Shop, kein Teil in zwei Sets', () {
      final seen = <String>{};
      for (final set in Shop.sets) {
        expect(set.items.length, greaterThanOrEqualTo(3));
        for (final id in set.items) {
          expect(Shop.byId(id), isNotNull, reason: id);
          expect(seen.add(id), isTrue, reason: '$id doppelt');
        }
      }
      final p = Profile(id: 'x', nickname: 'Mia', character: Character.fuzz, coins: 10000);
      final beach = Shop.sets.firstWhere((s) => s.id == 'beach');
      expect(beach.completeFor(p), isFalse);
      for (final i in beach.parts) {
        Shop.buy(p, i);
      }
      expect(beach.completeFor(p), isTrue);
      expect(badgesOf(p).firstWhere((b) => b.id == 'set_beach').earned, isTrue);
      final look = Shop.wearSet(p, beach);
      expect([look.hat, look.glasses, look.neck, look.vest], ['hat_straw', 'glasses_heart', 'neck_lei', 'vest_hawaii']);
      expect(CharacterLook.fromJson(look.toJson(), Character.fuzz).neck, 'neck_lei');
    });
  });
}
