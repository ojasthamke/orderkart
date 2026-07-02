import 'street.dart';

abstract class StreetRepository {
  Future<List<Street>> getStreetsByArea(String areaId, {String? searchQuery});
  Future<Street?> getStreetById(String id);
  Future<String> addStreet(Street street);
  Future<void> updateStreet(Street street);
  Future<void> deleteStreet(String id);
}
