import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api.dart';

enum AppPage {
  overview,
  contacts,
  groups,
  campaigns,
  templates,
  analytics,
  settings
}

class AppController extends ChangeNotifier {
  final Api api = Api();
  Map<String, dynamic>? user;
  Map<String, dynamic> dashboard = {};
  Map<String, dynamic> contactData = {'items': [], 'total': 0, 'counts': {}};
  Map<String, dynamic> integration = {};
  List<dynamic> groups = [], campaigns = [], templates = [], activities = [];
  final Set<int> selectedContacts = {};
  AppPage page = AppPage.overview;
  bool booting = true, refreshing = false, contactsLoading = false;
  String? bootError, contactsError;
  int days = 7, contactPage = 1;
  String contactSearch = '', contactStatus = '';
  int? contactGroup;
  Timer? _searchTimer, _pollTimer;
  int _contactRequest = 0;

  Future<void> boot() async {
    booting = true;
    bootError = null;
    notifyListeners();
    try {
      final signedOut = await api.restore();
      if (api.token != null) {
        try {
          user = Map<String, dynamic>.from(await api.get('/auth/me'));
        } on ApiException catch (e) {
          if (e.status != 401) rethrow;
          await api.clearSession();
        }
      } else if (!signedOut) {
        try {
          await authenticate('/auth/demo', {});
        } on ApiException catch (e) {
          if (e.status != 403) rethrow; // Production can disable demo access.
        }
      }
      if (user != null) {
        await loadCore();
        await loadContacts();
        _startPolling();
      }
    } catch (e) {
      bootError = e.toString();
    }
    booting = false;
    notifyListeners();
  }

  Future<void> authenticate(
      String endpoint, Map<String, dynamic> payload) async {
    final result = await api.post(endpoint, payload);
    await api.saveSession(result['token']);
    user = Map<String, dynamic>.from(result['user']);
  }

  Future<void> login(String endpoint, Map<String, dynamic> payload) async {
    await authenticate(endpoint, payload);
    page = AppPage.overview;
    contactGroup = null;
    contactSearch = '';
    contactStatus = '';
    contactPage = 1;
    bootError = null;
    await loadCore();
    await loadContacts();
    _startPolling();
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await api.post('/auth/logout');
    } catch (_) {/* Local sign-out still applies if offline. */}
    _pollTimer?.cancel();
    await api.clearSession();
    user = null;
    selectedContacts.clear();
    notifyListeners();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      final sending = campaigns.any((c) => c['status'] == 'Sending');
      final scheduled = timer.tick % 6 == 0 &&
          campaigns.any((c) => c['status'] == 'Scheduled');
      if (user != null && !refreshing && (sending || scheduled)) {
        try {
          await loadCore();
        } catch (_) {/* Explicit refresh surfaces network errors. */}
      }
    });
  }

  Future<void> loadCore() async {
    final results = await Future.wait([
      api.get('/dashboard', {'days': '$days'}),
      api.get('/groups'),
      api.get('/campaigns'),
      api.get('/templates'),
      api.get('/activities'),
      api.get('/integrations/whatsapp'),
    ]);
    dashboard = Map<String, dynamic>.from(results[0]);
    groups = results[1]['items'];
    campaigns = results[2]['items'];
    templates = results[3]['items'];
    activities = results[4]['items'];
    integration = Map<String, dynamic>.from(results[5]);
    notifyListeners();
  }

  Future<void> refresh() async {
    refreshing = true;
    notifyListeners();
    try {
      await Future.wait([loadCore(), loadContacts()]);
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }

  Future<void> loadContacts() async {
    final request = ++_contactRequest;
    contactsLoading = true;
    contactsError = null;
    notifyListeners();
    try {
      final data = await api.get('/contacts', {
        'q': contactSearch,
        'status': contactStatus,
        'page': '$contactPage',
        'limit': '12',
        if (contactGroup != null) 'group_id': '$contactGroup',
      });
      if (request == _contactRequest) {
        final maxPage = ((data['total'] as int) / 12).ceil();
        if (contactPage > (maxPage < 1 ? 1 : maxPage)) {
          contactPage = maxPage < 1 ? 1 : maxPage;
          await loadContacts();
          return;
        }
        contactData = Map<String, dynamic>.from(data);
      }
    } catch (e) {
      if (request == _contactRequest) contactsError = e.toString();
      rethrow;
    } finally {
      if (request == _contactRequest) {
        contactsLoading = false;
        notifyListeners();
      }
    }
  }

  void searchContacts(String value) {
    contactSearch = value;
    contactPage = 1;
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        await loadContacts();
      } catch (_) {
        notifyListeners();
      }
    });
  }

  Future<void> filterContacts(
      {String? status, int? groupId, bool clearGroup = false}) async {
    if (status != null) contactStatus = status;
    if (clearGroup) {
      contactGroup = null;
    } else if (groupId != null) {
      contactGroup = groupId;
    }
    contactPage = 1;
    selectedContacts.clear();
    await loadContacts();
  }

  void navigate(AppPage value) {
    page = value;
    notifyListeners();
  }

  Future<void> openGroup(int id) async {
    page = AppPage.contacts;
    contactGroup = id;
    contactSearch = '';
    contactStatus = '';
    contactPage = 1;
    selectedContacts.clear();
    notifyListeners();
    await loadContacts();
  }

  void toggleContact(int id) {
    selectedContacts.contains(id)
        ? selectedContacts.remove(id)
        : selectedContacts.add(id);
    notifyListeners();
  }

  void toggleAllContacts() {
    final ids =
        (contactData['items'] as List).map<int>((c) => c['id'] as int).toSet();
    if (ids.every(selectedContacts.contains)) {
      selectedContacts.removeAll(ids);
    } else {
      selectedContacts.addAll(ids);
    }
    notifyListeners();
  }

  Future<void> remove(String resource, int id) async {
    // Optimistic removal; restore the authoritative list if the mutation fails.
    final previousGroup = contactGroup;
    if (resource == "groups" && contactGroup == id) contactGroup = null;
    final previousContacts = Map<String, dynamic>.from(contactData);
    final previousGroups = List.of(groups),
        previousCampaigns = List.of(campaigns),
        previousTemplates = List.of(templates);
    if (resource == 'contacts') {
      contactData = {
        ...contactData,
        'items':
            (contactData['items'] as List).where((c) => c['id'] != id).toList(),
        'total': (contactData['total'] as int) - 1
      };
      selectedContacts.remove(id);
    }
    if (resource == 'groups') {
      groups = groups.where((c) => c['id'] != id).toList();
    }
    if (resource == 'campaigns') {
      campaigns = campaigns.where((c) => c['id'] != id).toList();
    }
    if (resource == 'templates') {
      templates = templates.where((c) => c['id'] != id).toList();
    }
    notifyListeners();
    try {
      await api.delete('/$resource/$id');
      await refresh();
    } catch (_) {
      contactGroup = previousGroup;
      contactData = previousContacts;
      groups = previousGroups;
      campaigns = previousCampaigns;
      templates = previousTemplates;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setDays(int value) async {
    days = value;
    refreshing = true;
    notifyListeners();
    try {
      await loadCore();
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }

  bool activityVisible(dynamic a) {
    final prefs = user?['settings'] as Map? ?? {};
    if (['campaign', 'schedule'].contains(a['kind'])) {
      return prefs['delivery_notifications'] != false;
    }
    if (['contact', 'group'].contains(a['kind'])) {
      return prefs['email_notifications'] != false;
    }
    return true;
  }

  List<dynamic> get visibleActivities =>
      activities.where(activityVisible).toList();
  void changed() => notifyListeners();

  @override
  void dispose() {
    _searchTimer?.cancel();
    _pollTimer?.cancel();
    api.client.close();
    super.dispose();
  }
}
