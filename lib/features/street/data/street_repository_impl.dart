import '../domain/street.dart';
import '../domain/street_repository.dart';
import 'street_dao.dart';

class StreetRepositoryImpl implements StreetRepository {
  final StreetDao _dao;
  StreetRepositoryImpl(this._dao);

  @override
  Future<List<Street>> getStreetsByArea(String areaId, {String? searchQuery}) =>
      _dao.getStreetsByArea(areaId, searchQuery: searchQuery);

  @override
  Future<Street?> getStreetById(String id) => _dao.getStreetById(id);

  @override
  Future<String> addStreet(Street street) => _dao.insertStreet(street);

  @override
  Future<void> updateStreet(Street street) => _dao.updateStreet(street);

  @override
  Future<void> deleteStreet(String id) => _dao.deleteStreet(id);
}
