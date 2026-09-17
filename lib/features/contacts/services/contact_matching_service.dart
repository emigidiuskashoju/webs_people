import '../models/contact_match.dart';
import 'contact_api_service.dart';
import 'contact_service.dart';
import 'phone_number_service.dart';

class ContactMatchingService {
  final ContactService _contactService;
  final PhoneNumberService _phoneNumberService;
  final ContactApiService _apiService;

  ContactMatchingService({
    ContactService? contactService,
    PhoneNumberService? phoneNumberService,
    ContactApiService? apiService,
  })  : _contactService =
            contactService ??
                ContactService(),
        _phoneNumberService =
            phoneNumberService ??
                PhoneNumberService(),
        _apiService =
            apiService ??
                ContactApiService();

  Future<List<ContactMatch>>
      findWebsPeople() async {
    final phoneNumbers =
        await _contactService
            .getPhoneNumbers();

    final normalized =
        _phoneNumberService
            .normalizeMany(
      phoneNumbers,
    );

    if (normalized.isEmpty) {
      return [];
    }

    return _apiService
        .matchContacts(
      normalized,
    );
  }
}