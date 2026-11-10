import 'package:dio/dio.dart';
import '../../core/api_client.dart';
import '../models/models.dart';

// All REST calls per SRS/SDD endpoint table. JSON in/out.
class ApiService {
  final ApiClient client;
  ApiService(this.client);
  Dio get _d => client.dio;

  Future<String> register(String email, String pw, String? name) async {
    final r = await _d.post('/auth/register',
        data: {'email': email, 'password': pw, 'name': name});
    final t = r.data['access_token'] as String;
    await client.saveToken(t);
    return t;
  }

  Future<String> login(String email, String pw) async {
    final r = await _d.post('/auth/login', data: {'email': email, 'password': pw});
    final t = r.data['access_token'] as String;
    await client.saveToken(t);
    return t;
  }

  Future<void> logout() async {
    try {
      await _d.post('/auth/logout');
    } catch (_) {
      // Always sign out locally, even if the server is unreachable.
    } finally {
      await client.clearToken();
    }
  }

  Future<void> resetPassword(String email) =>
      _d.post('/auth/reset-password', data: {'email': email});
  Future<Map<String, dynamic>> profile() async =>
      (await _d.get('/user/profile')).data;
  Future<void> updateProfile({String? name, String? email}) =>
      _d.put('/user/profile', data: {'name': name, 'email': email});
  Future<void> deleteAccount() => _d.delete('/user/account');

  Future<List<Category>> categories() async {
    final r = await _d.get('/categories');
    return (r.data as List).map((e) => Category.fromJson(e)).toList();
  }

  Future<void> addCategory(String name) =>
      _d.post('/categories', data: {'name': name});

  Future<List<Txn>> transactions({int limit = 100}) async {
    final r = await _d.get('/transactions', queryParameters: {'limit': limit});
    return (r.data as List).map((e) => Txn.fromJson(e)).toList();
  }

  Future<List<Txn>> search({String q = '', String? type, String? categoryId,
      String? start, String? end}) async {
    final r = await _d.get('/transactions/search', queryParameters: {
      'q': q, if (type != null) 'type': type,
      if (categoryId != null) 'category_id': categoryId,
      if (start != null) 'start': start, if (end != null) 'end': end,
    });
    return (r.data as List).map((e) => Txn.fromJson(e)).toList();
  }

  Future<void> addTxn(Map<String, dynamic> body) =>
      _d.post('/transactions', data: body);
  Future<void> updateTxn(String id, Map<String, dynamic> body) =>
      _d.put('/transactions/$id', data: body);
  Future<void> deleteTxn(String id) => _d.delete('/transactions/$id');

  Future<Summary> summary() async =>
      Summary.fromJson((await _d.get('/dashboard/summary')).data);
  Future<List<Map<String, dynamic>>> breakdown() async =>
      List<Map<String, dynamic>>.from(
          (await _d.get('/dashboard/expense-breakdown')).data);

  Future<List<Budget>> budgets() async {
    final r = await _d.get('/budgets');
    return (r.data as List).map((e) => Budget.fromJson(e)).toList();
  }

  Future<void> saveBudget(Map<String, dynamic> body, [String? id]) =>
      id == null ? _d.post('/budgets', data: body) : _d.put('/budgets/$id', data: body);

  Future<String> chat(String q) async {
    final r = await _d.post('/ai/chat', data: {'question': q});
    return r.data['answer'] as String;
  }

  Future<List<Map<String, dynamic>>> insights({bool refresh = false}) async {
    final r = await _d.get('/insights', queryParameters: {'refresh': refresh});
    return List<Map<String, dynamic>>.from(r.data);
  }

  Future<String> gmailConnect() async =>
      (await _d.post('/oauth/gmail/connect')).data['auth_url'] as String;
  Future<void> gmailRevoke() => _d.post('/oauth/gmail/revoke');
  Future<int> gmailImport() async =>
      (await _d.post('/gmail/import')).data['imported'] as int? ?? 0;
}
