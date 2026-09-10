import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager_pro/models/document_template.dart';
import 'package:business_manager_pro/models/enterprise.dart';
import 'package:business_manager_pro/models/project.dart';
import 'package:business_manager_pro/utils/company_logo_helper.dart';

void main() {
  group('CompanyLogoHelper Tests', () {
    test('decodeBase64Logo returns null on null or empty input', () {
      expect(CompanyLogoHelper.decodeBase64Logo(null), isNull);
      expect(CompanyLogoHelper.decodeBase64Logo(''), isNull);
      expect(CompanyLogoHelper.decodeBase64Logo('   '), isNull);
    });

    test('decodeBase64Logo decodes standard base64 strings', () {
      final original = [1, 2, 3, 4, 5, 255];
      final encoded = base64Encode(Uint8List.fromList(original));
      final decoded = CompanyLogoHelper.decodeBase64Logo(encoded);

      expect(decoded, isNotNull);
      expect(decoded, equals(Uint8List.fromList(original)));
    });

    test('decodeBase64Logo decodes data:image/png;base64 URIs', () {
      final original = [10, 20, 30, 40];
      final rawBase64 = base64Encode(Uint8List.fromList(original));
      final dataUri = 'data:image/png;base64,$rawBase64';
      final decoded = CompanyLogoHelper.decodeBase64Logo(dataUri);

      expect(decoded, isNotNull);
      expect(decoded, equals(Uint8List.fromList(original)));
    });

    test('decodeBase64Logo decodes data URIs with newlines/whitespace', () {
      final original = [7, 8, 9];
      final rawBase64 = base64Encode(Uint8List.fromList(original));
      final dataUri = 'data:image/jpeg;base64,\n $rawBase64 \r\n';
      final decoded = CompanyLogoHelper.decodeBase64Logo(dataUri);

      expect(decoded, isNotNull);
      expect(decoded, equals(Uint8List.fromList(original)));
    });

    test('decodeBase64Logo handles invalid strings gracefully without throwing', () {
      final decoded = CompanyLogoHelper.decodeBase64Logo('!!!not_base64!!!');
      expect(decoded, isNull);
    });
  });

  group('Enterprise logo serialization tests', () {
    test('Enterprise serializes and deserializes logoUrl in toMap and fromMap', () {
      final sampleLogo = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
      final ent = Enterprise(
        id: 'ent_1',
        name: 'Tech Corp',
        ownerId: 'owner_1',
        logoUrl: sampleLogo,
      );

      final map = ent.toMap();
      expect(map['logoUrl'], equals(sampleLogo));
      expect(map['logo_url'], equals(sampleLogo));

      final restored = Enterprise.fromMap(map);
      expect(restored.logoUrl, equals(sampleLogo));
    });

    test('Enterprise parses logoUrl from alternative keys (logoPath, logo_url)', () {
      final sampleLogo = 'data:image/png;base64,sample123';
      final fromSnake = Enterprise.fromMap({
        'id': 'ent_1',
        'name': 'Test Snake',
        'owner_id': 'owner_1',
        'logo_url': sampleLogo,
      });
      expect(fromSnake.logoUrl, equals(sampleLogo));

      final fromPath = Enterprise.fromMap({
        'id': 'ent_2',
        'name': 'Test Path',
        'owner_id': 'owner_1',
        'logoPath': sampleLogo,
      });
      expect(fromPath.logoUrl, equals(sampleLogo));
    });

    test('Enterprise copyWith correctly updates and clears logoUrl', () {
      final ent = Enterprise(id: 'ent_1', name: 'Original', ownerId: 'owner_1', logoUrl: null);
      final updated = ent.copyWith(logoUrl: 'data:image/png;base64,newLogo');
      expect(updated.logoUrl, equals('data:image/png;base64,newLogo'));

      final cleared = updated.copyWith(clearLogo: true);
      expect(cleared.logoUrl, isNull);
    });
  });

  group('DocumentTemplate showLogo default tests', () {
    test('defaultCompanyInfo has showLogo set to true', () {
      final info = DocumentTemplate.defaultCompanyInfo();
      expect(info['showLogo'], isTrue);
    });

    test('All 5 preset configurations have showLogo set to true by default', () {
      expect(DocumentTemplate.classicConfig()['companyInfo']['showLogo'], isTrue);
      expect(DocumentTemplate.modernConfig()['companyInfo']['showLogo'], isTrue);
      expect(DocumentTemplate.minimalistConfig()['companyInfo']['showLogo'], isTrue);
      expect(DocumentTemplate.professionalConfig()['companyInfo']['showLogo'], isTrue);
      expect(DocumentTemplate.colorfulConfig()['companyInfo']['showLogo'], isTrue);
    });

    test('DocumentTemplate.fromMap defaults showLogo to true for default templates', () {
      final tpl = DocumentTemplate.fromMap({
        'id': 'tpl_test',
        'name': 'Test Default',
        'is_default': true,
        'config': {
          'companyInfo': {
            'showName': true,
            'showLogo': false, // legacy default
          },
        },
      });
      expect(tpl.companyInfoConfig['showLogo'], isTrue);
    });

    test('DocumentTemplate.companyInfoConfig respects explicitly disabled logo', () {
      final tpl = DocumentTemplate.fromMap({
        'id': 'tpl_test_2',
        'name': 'Test Explicit Off',
        'is_default': false,
        'config': {
          'companyInfo': {
            'showName': true,
            'showLogo': false,
            'logoExplicitlyDisabled': true,
          },
        },
      });
      expect(tpl.companyInfoConfig['showLogo'], isFalse);
    });
  });
}
