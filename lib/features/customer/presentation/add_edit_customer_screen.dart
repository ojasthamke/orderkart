import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/customer_order_sync_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../domain/customer.dart';
import '../data/customer_dao.dart';
import '../../../core/constants/app_routes.dart';
import 'customer_provider.dart';
import '../../../core/utils/image_utils.dart';
import 'package:latlong2/latlong.dart';

class AddEditCustomerScreen extends ConsumerStatefulWidget {
  final String? streetId;
  final String? customerId;
  final String? initialHouseNumber;
  final String? initialAddress;
  final String? initialMapsLocation;
  final int? initialSerialNo;

  const AddEditCustomerScreen({
    super.key,
    this.streetId,
    this.customerId,
    this.initialHouseNumber,
    this.initialAddress,
    this.initialMapsLocation,
    this.initialSerialNo,
  });

  @override
  ConsumerState<AddEditCustomerScreen> createState() =>
      _AddEditCustomerScreenState();
}

class _AddEditCustomerScreenState extends ConsumerState<AddEditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCon = TextEditingController();
  final _phone1Con = TextEditingController();
  final _phone2Con = TextEditingController();
  final _waCon = TextEditingController();
  final _serialNoCon = TextEditingController(); // replaces main house number
  final _houseCon = TextEditingController(); // house/flat number
  final _addressCon = TextEditingController();
  final _notesCon = TextEditingController();
  final _mapsCon = TextEditingController();
  final _customerCodeCon = TextEditingController();

  String? _streetId;
  String _photoPath = '';
  bool _loading = false;
  bool _isEdit = false;
  String _dietaryPreference = '';
  bool _isGhostHouse = false;
  List<Customer> _existingHouseFamilies = [];

  // Dedicated Delivery Area & Road state
  String? _selectedAreaId;
  String? _selectedAreaName;
  String? _selectedRoadId;
  String? _selectedRoadName;
  String? _selectedSubRoadId;
  String? _selectedSubRoadName;
  List<Map<String, dynamic>> _availableAreas = [];
  List<Map<String, dynamic>> _availableRoads = [];
  List<Map<String, dynamic>> _availableSubRoads = [];
  bool _loadingLocations = true;

  // Custom Fields state
  List<Map<String, dynamic>> _customFields = [];
  final Map<String, TextEditingController> _customFieldControllers = {};

  @override
  void initState() {
    super.initState();
    _streetId = widget.streetId;
    _loadCustomFields();
    _loadAreasAndRoads();

    if (widget.initialHouseNumber != null && widget.initialHouseNumber!.isNotEmpty) {
      _houseCon.text = widget.initialHouseNumber!;
      if (widget.initialAddress != null) _addressCon.text = widget.initialAddress!;
      if (widget.initialMapsLocation != null) _mapsCon.text = widget.initialMapsLocation!;
      if (widget.initialSerialNo != null && widget.initialSerialNo! > 0) {
        _serialNoCon.text = '${widget.initialSerialNo}';
      }
      _checkHousehold(widget.initialHouseNumber!);
    }

    _houseCon.addListener(() {
      _checkHousehold(_houseCon.text);
    });

    if (widget.customerId != null) {
      _isEdit = true;
      _loadCustomer();
    }
  }

  Future<void> _loadAreasAndRoads() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Fetch root areas from locations table
      List<Map<String, dynamic>> areas = await db.query(
        'locations',
        where: "(parent_location_id IS NULL OR depth = 0) AND (is_archived IS NULL OR is_archived = 0)",
        orderBy: "sequence_key ASC, name ASC",
      );

      // Fallback to legacy areas table if locations table has no root areas
      if (areas.isEmpty) {
        final legacyAreas = await db.query('areas', orderBy: 'name ASC');
        areas = legacyAreas.map((a) => {
          'id': a['id'],
          'name': a['name'],
        }).toList();
      }

      // If still empty and Supabase is configured, pull from Supabase
      if (areas.isEmpty) {
        try {
          final rAreas = await Supabase.instance.client
              .from('areas')
              .select('id, name')
              .order('name');
          areas = List<Map<String, dynamic>>.from(rAreas);
        } catch (_) {}
      }

      String? targetAreaId;
      String? targetAreaName;
      String? targetRoadId;
      String? targetRoadName;
      String? targetSubRoadId;
      String? targetSubRoadName;

      // If _streetId is provided, resolve its ancestor tree
      if (_streetId != null && _streetId!.isNotEmpty) {
        final list = <Map<String, dynamic>>[];
        String? cur = _streetId;
        int maxD = 10;
        while (cur != null && maxD-- > 0) {
          final rows = await db.query('locations',
              where: 'id = ?', whereArgs: [cur], limit: 1);
          if (rows.isEmpty) break;
          list.insert(0, rows.first);
          cur = rows.first['parent_location_id'] as String?;
        }

        if (list.isNotEmpty) {
          targetAreaId = list[0]['id'] as String;
          targetAreaName = list[0]['name'] as String;
          if (list.length > 1) {
            targetRoadId = list[1]['id'] as String;
            targetRoadName = list[1]['name'] as String;
          }
          if (list.length > 2) {
            targetSubRoadId = list.last['id'] as String;
            targetSubRoadName = list.last['name'] as String;
          }
        } else {
          // Check legacy streets table
          final streetRows = await db.query('streets',
              where: 'id = ?', whereArgs: [_streetId], limit: 1);
          if (streetRows.isNotEmpty) {
            targetRoadId = streetRows.first['id'] as String;
            targetRoadName = streetRows.first['name'] as String;
            targetAreaId = streetRows.first['area_id'] as String?;
            if (targetAreaId != null) {
              final aRows = await db.query('areas',
                  where: 'id = ?', whereArgs: [targetAreaId], limit: 1);
              if (aRows.isNotEmpty) {
                targetAreaName = aRows.first['name'] as String;
              }
            }
          }
        }
      }

      // If targetAreaId is still not resolved, default to first available area
      if (targetAreaId == null && areas.isNotEmpty) {
        targetAreaId = areas.first['id'] as String;
        targetAreaName = areas.first['name'] as String;
      }

      // Now load roads for this targetAreaId
      List<Map<String, dynamic>> roads = [];
      if (targetAreaId != null) {
        roads = await _queryRoadsForArea(db, targetAreaId);
      }

      // If targetRoadId is not resolved, default to first available road
      if ((targetRoadId == null || !roads.any((r) => r['id'] == targetRoadId)) && roads.isNotEmpty) {
        targetRoadId = roads.first['id'] as String;
        targetRoadName = roads.first['name'] as String;
      }

      List<Map<String, dynamic>> subRoads = [];
      if (targetRoadId != null) {
        subRoads = await _querySubRoadsForRoad(db, targetRoadId);
      }

      if (mounted) {
        setState(() {
          _availableAreas = areas;
          _selectedAreaId = targetAreaId;
          _selectedAreaName = targetAreaName;
          _availableRoads = roads;
          _selectedRoadId = targetRoadId;
          _selectedRoadName = targetRoadName;
          _availableSubRoads = subRoads;
          _selectedSubRoadId = targetSubRoadId ?? '';
          _selectedSubRoadName = targetSubRoadName;
          _streetId = (_selectedSubRoadId != null && _selectedSubRoadId!.isNotEmpty)
              ? _selectedSubRoadId
              : (_selectedRoadId != null && _selectedRoadId!.isNotEmpty)
                  ? _selectedRoadId
                  : _selectedAreaId;
          _loadingLocations = false;
        });
      }
    } catch (e) {
      debugPrint('[AddEditCustomer] Error loading areas and roads: $e');
      if (mounted) setState(() => _loadingLocations = false);
    }
  }

  Future<List<Map<String, dynamic>>> _queryRoadsForArea(Database db, String areaId) async {
    List<Map<String, dynamic>> roads = await db.query(
      'locations',
      where: "parent_location_id = ? AND (is_archived IS NULL OR is_archived = 0)",
      whereArgs: [areaId],
      orderBy: "sequence_key ASC, name ASC",
    );
    if (roads.isEmpty) {
      final legacy = await db.query(
        'streets',
        where: "area_id = ?",
        whereArgs: [areaId],
        orderBy: "name ASC",
      );
      roads = legacy.map((s) => {'id': s['id'], 'name': s['name']}).toList();
    }
    if (roads.isEmpty) {
      try {
        final rRoads = await Supabase.instance.client
            .from('roads')
            .select('id, name')
            .eq('area_id', areaId)
            .order('name');
        roads = List<Map<String, dynamic>>.from(rRoads);
      } catch (_) {}
    }
    return roads;
  }

  Future<List<Map<String, dynamic>>> _querySubRoadsForRoad(Database db, String roadId) async {
    List<Map<String, dynamic>> subRoads = await db.query(
      'locations',
      where: "parent_location_id = ? AND (is_archived IS NULL OR is_archived = 0)",
      whereArgs: [roadId],
      orderBy: "sequence_key ASC, name ASC",
    );
    return subRoads;
  }

  Future<void> _onAreaChanged(String newAreaId) async {
    final areaMap = _availableAreas.firstWhere(
      (a) => a['id'] == newAreaId,
      orElse: () => {'name': ''},
    );
    final areaName = areaMap['name'] as String? ?? '';
    final db = await DatabaseHelper.instance.database;
    final roads = await _queryRoadsForArea(db, newAreaId);
    String? firstRoadId;
    String? firstRoadName;
    if (roads.isNotEmpty) {
      firstRoadId = roads.first['id'] as String;
      firstRoadName = roads.first['name'] as String;
    }

    setState(() {
      _selectedAreaId = newAreaId;
      _selectedAreaName = areaName;
      _availableRoads = roads;
      _selectedRoadId = firstRoadId;
      _selectedRoadName = firstRoadName;
      _availableSubRoads = [];
      _selectedSubRoadId = '';
      _selectedSubRoadName = null;
      _streetId = firstRoadId ?? newAreaId;
    });

    if (firstRoadId != null) {
      final subRoads = await _querySubRoadsForRoad(db, firstRoadId);
      if (mounted) {
        setState(() => _availableSubRoads = subRoads);
      }
    }
    _autoUpdateAddress();
  }

  Future<void> _onRoadChanged(String newRoadId) async {
    final roadMap = _availableRoads.firstWhere(
      (r) => r['id'] == newRoadId,
      orElse: () => {'name': ''},
    );
    final roadName = roadMap['name'] as String? ?? '';
    final db = await DatabaseHelper.instance.database;
    final subRoads = await _querySubRoadsForRoad(db, newRoadId);

    setState(() {
      _selectedRoadId = newRoadId;
      _selectedRoadName = roadName;
      _availableSubRoads = subRoads;
      _selectedSubRoadId = '';
      _selectedSubRoadName = null;
      _streetId = newRoadId;
    });
    _autoUpdateAddress();
  }

  void _onSubRoadChanged(String newSubRoadId) {
    String? subRoadName;
    if (newSubRoadId.isNotEmpty) {
      final srMap = _availableSubRoads.firstWhere(
        (sr) => sr['id'] == newSubRoadId,
        orElse: () => {'name': ''},
      );
      subRoadName = srMap['name'] as String?;
    }
    setState(() {
      _selectedSubRoadId = newSubRoadId;
      _selectedSubRoadName = subRoadName;
      _streetId = newSubRoadId.isNotEmpty ? newSubRoadId : _selectedRoadId;
    });
    _autoUpdateAddress();
  }

  void _autoUpdateAddress() {
    if (_addressCon.text.trim().isEmpty || _addressCon.text.contains(',')) {
      final parts = <String>[];
      if (_houseCon.text.trim().isNotEmpty) parts.add(_houseCon.text.trim());
      if (_selectedSubRoadName != null && _selectedSubRoadName!.trim().isNotEmpty) {
        parts.add(_selectedSubRoadName!.trim());
      }
      if (_selectedRoadName != null && _selectedRoadName!.trim().isNotEmpty) {
        parts.add(_selectedRoadName!.trim());
      }
      if (_selectedAreaName != null && _selectedAreaName!.trim().isNotEmpty) {
        parts.add(_selectedAreaName!.trim());
      }
      if (parts.isNotEmpty) {
        _addressCon.text = parts.join(', ');
      }
    }
  }

  Future<void> _showAddNewRoadDialog() async {
    if (_selectedAreaId == null) return;
    final nameCon = TextEditingController();
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Road / Street'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Area: ${_selectedAreaName ?? ""}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: nameCon,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Road Name *',
                hintText: 'e.g. Main Road, Galli 1',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add Road'),
          ),
        ],
      ),
    );

    if (res == true && nameCon.text.trim().isNotEmpty) {
      final roadName = nameCon.text.trim();
      final newRoadId = const Uuid().v4();
      final now = DateTime.now().toIso8601String();
      final db = await DatabaseHelper.instance.database;

      await db.insert('locations', {
        'id': newRoadId,
        'parent_location_id': _selectedAreaId,
        'name': roadName,
        'location_kind': 'road',
        'sequence_key': '001',
        'depth': 1,
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      try {
        await db.insert('streets', {
          'id': newRoadId,
          'area_id': _selectedAreaId,
          'name': roadName,
          'created_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (_) {}

      final roads = await _queryRoadsForArea(db, _selectedAreaId!);
      setState(() {
        _availableRoads = roads;
        _selectedRoadId = newRoadId;
        _selectedRoadName = roadName;
        _streetId = newRoadId;
      });
      _autoUpdateAddress();
      unawaited(CustomerOrderSyncService.instance.syncAreasAndRoads());
    }
  }

  void _checkHousehold(String houseNo) async {
    if (houseNo.trim().isEmpty) {
      if (mounted) setState(() => _existingHouseFamilies = []);
      return;
    }
    final dao = CustomerDao();
    final res = await dao.getCustomersInSameHouse(
      houseNo,
      streetId: _streetId,
      excludeCustomerId: widget.customerId,
    );
    if (mounted) {
      setState(() {
        _existingHouseFamilies = res;
      });
    }
  }

  Future<void> _loadCustomFields() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final fields = await db.query('custom_fields',
          where: 'entity_type = ?', whereArgs: ['customer']);

      final Map<String, String> values = {};
      if (widget.customerId != null) {
        final existingValues = await db.query(
          'custom_field_values',
          where: 'entity_id = ?',
          whereArgs: [widget.customerId],
        );
        for (final row in existingValues) {
          values[row['field_id'] as String] = row['value'] as String;
        }
      }

      if (mounted) {
        setState(() {
          _customFields = fields;
          for (final f in fields) {
            final fid = f['id'] as String;
            _customFieldControllers[fid] =
                TextEditingController(text: values[fid] ?? '');
          }
        });
      }
    } catch (_) {}
  }

  String _initialName = '';
  String _initialPhone = '';
  String _initialHouse = '';
  String _initialAddress = '';
  String _initialNotes = '';
  String _initialCustomerCode = '';

  Future<void> _loadCustomer() async {
    final customer = await ref
        .read(customerRepositoryProvider)
        .getCustomerById(widget.customerId!);
    if (customer != null && mounted) {
      // If editing a ghost house (e.g. from customer list prompt), auto-convert so input fields are visible
      final wasGhost = customer.isGhostHouse;
      setState(() {
        _streetId = customer.streetId;
        _isGhostHouse = wasGhost;
        _initialName = wasGhost ? '' : customer.name;
        _initialPhone = wasGhost ? '' : customer.phone1;
        _initialHouse = customer.houseNumber;
        _initialAddress = customer.address;
        _initialNotes = customer.notes;
        _initialCustomerCode = customer.customerCode;

        _nameCon.text = _initialName;
        _phone1Con.text = _initialPhone;
        _phone2Con.text = customer.phone2;
        _waCon.text = customer.whatsapp;
        _serialNoCon.text = customer.serialNo > 0 ? '${customer.serialNo}' : '';
        _houseCon.text = _initialHouse;
        _addressCon.text = _initialAddress;
        _notesCon.text = _initialNotes;
        _mapsCon.text = customer.mapsLocation;
        _photoPath = customer.photoPath;
        _dietaryPreference = customer.dietaryPreference;
        _customerCodeCon.text = _initialCustomerCode;
      });
      _checkHousehold(customer.houseNumber);
      _loadAreasAndRoads();
    }
  }

  bool _hasUnsavedChanges() {
    if (_isEdit) {
      return _nameCon.text != _initialName ||
          _phone1Con.text != _initialPhone ||
          _houseCon.text != _initialHouse ||
          _addressCon.text != _initialAddress ||
          _notesCon.text != _initialNotes ||
          _customerCodeCon.text != _initialCustomerCode;
    }
    return _nameCon.text.trim().isNotEmpty ||
        _phone1Con.text.trim().isNotEmpty ||
        _houseCon.text.trim().isNotEmpty ||
        _addressCon.text.trim().isNotEmpty ||
        _notesCon.text.trim().isNotEmpty ||
        _customerCodeCon.text.trim().isNotEmpty ||
        _photoPath.isNotEmpty;
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasUnsavedChanges()) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Discard Changes?'),
          ],
        ),
        content: const Text(
            'You have unsaved changes in this form. Are you sure you want to leave without saving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Editing'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  void dispose() {
    _nameCon.dispose();
    _phone1Con.dispose();
    _phone2Con.dispose();
    _waCon.dispose();
    _serialNoCon.dispose();
    _houseCon.dispose();
    _addressCon.dispose();
    _notesCon.dispose();
    _mapsCon.dispose();
    _customerCodeCon.dispose();
    for (final controller in _customFieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges(),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _confirmDiscard();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: AppScaffold(
        title: _isEdit ? 'Edit Customer' : 'Add Customer',
        onBack: () async {
          final shouldPop = await _confirmDiscard();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        },
        body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Photo picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryLight, width: 2),
                    image: _photoPath.isNotEmpty
                        ? DecorationImage(
                            image: _photoPath.startsWith('http')
                                ? NetworkImage(_photoPath) as ImageProvider
                                : FileImage(File(_photoPath)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _photoPath.isEmpty
                      ? const Icon(Icons.camera_alt_rounded,
                          size: 32, color: AppColors.primary)
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _photoPath.isEmpty ? 'Add Photo' : 'Change Photo',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),

              // ── Ghost / Blank House Toggle ──────────────────────────────
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _isGhostHouse
                      ? Colors.orange.withOpacity(0.10)
                      : Colors.transparent,
                  border: Border.all(
                    color: _isGhostHouse
                        ? Colors.orange.withOpacity(0.5)
                        : Colors.grey.withOpacity(0.25),
                    width: 1.2,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SwitchListTile(
                  value: _isGhostHouse,
                  onChanged: (val) {
                    setState(() {
                      _isGhostHouse = val;
                      if (val) {
                        _nameCon.text = '';
                        _phone1Con.text = '';
                      }
                    });
                  },
                  secondary: Icon(
                    Icons.home_work_outlined,
                    color: _isGhostHouse ? Colors.orange : AppColors.gray400,
                  ),
                  title: Text(
                    'Blank / Ghost House',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _isGhostHouse ? Colors.orange : null,
                    ),
                  ),
                  subtitle: Text(
                    _isGhostHouse
                        ? 'Placeholder slot — fill details when customer is known'
                        : 'Customer refused to share details — mark as placeholder',
                    style: const TextStyle(fontSize: 11),
                  ),
                  activeColor: Colors.orange,
                ),
              ),

              if (!_isGhostHouse) ...[
                // Hide photo & contact fields for ghost houses
                // Name
                TextFormField(
                  controller: _nameCon,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                  validator: _isGhostHouse
                      ? null
                      : (v) => AppValidators.nameField(v, field: 'Name'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),

                // Phone 1
                TextFormField(
                  controller: _phone1Con,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Primary Phone *',
                    prefixIcon: Icon(Icons.phone_rounded),
                  ),
                  validator: _isGhostHouse ? null : AppValidators.phoneRequired,
                ),
                const SizedBox(height: 8),

              ], // end !_isGhostHouse block

              // Phone 2
              TextFormField(
                controller: _phone2Con,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Secondary Phone (optional)',
                  prefixIcon: Icon(Icons.phone_iphone_rounded),
                ),
                validator: AppValidators.phone,
              ),
              const SizedBox(height: 16),

              // WhatsApp
              TextFormField(
                controller: _waCon,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp Number (optional)',
                  prefixIcon: Icon(Icons.chat_rounded),
                ),
                validator: AppValidators.phone,
              ),
              const SizedBox(height: 16),
              
              // Customer Code
              TextFormField(
                controller: _customerCodeCon,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Customer Code (OK2 Login)',
                  prefixIcon: const Icon(Icons.vpn_key_rounded),
                  hintText: 'e.g. OK1025, CUST001',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () {
                      if (_customerCodeCon.text.trim().isNotEmpty) {
                        Clipboard.setData(ClipboardData(text: _customerCodeCon.text.trim().toUpperCase()));
                        SnackbarHelper.showSuccess(context, 'Customer code copied');
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Shared Household Banner (Multiple Families in 1 House) ──────────
              if (_existingHouseFamilies.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.primary.withOpacity(0.25), width: 1.2),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.family_restroom_rounded,
                            color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Shared Household (House #${_houseCon.text.trim()})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Adding a new family to this house. Existing families residing here:',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _existingHouseFamilies
                                  .map((f) => Chip(
                                        avatar: const Icon(Icons.person_rounded,
                                            size: 14, color: AppColors.primary),
                                        label: Text(f.name,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold)),
                                        backgroundColor:
                                            Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.white10
                                                : Colors.black.withOpacity(0.04),
                                        padding: EdgeInsets.zero,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Delivery Area & Route Selector ─────────────────────────
              Builder(
                builder: (ctx) {
                  final isDark = Theme.of(ctx).brightness == Brightness.dark;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white12 : AppColors.primary.withOpacity(0.25),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.alt_route_rounded,
                                  color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Delivery Area & Route *',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (_loadingLocations)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Area Dropdown
                        DropdownButtonFormField<String>(
                          value: _selectedAreaId,
                          decoration: const InputDecoration(
                            labelText: 'Delivery Area *',
                            prefixIcon: Icon(Icons.location_city_rounded),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _availableAreas.map((a) {
                            return DropdownMenuItem<String>(
                              value: a['id'] as String,
                              child: Text(
                                a['name'] as String,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            );
                          }).toList(),
                          onChanged: (newAreaId) {
                            if (newAreaId != null && newAreaId != _selectedAreaId) {
                              _onAreaChanged(newAreaId);
                            }
                          },
                          validator: (v) => (v == null || v.isEmpty) ? 'Please select a delivery area' : null,
                        ),
                        const SizedBox(height: 12),

                        // Road Dropdown + Quick Add Road button
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _availableRoads.isEmpty
                                    ? (_selectedAreaId ?? '')
                                    : (_selectedRoadId != null &&
                                            _availableRoads.any((r) => r['id'] == _selectedRoadId)
                                        ? _selectedRoadId
                                        : (_availableRoads.isNotEmpty ? _availableRoads.first['id'] as String : null)),
                                decoration: InputDecoration(
                                  labelText: _availableRoads.isEmpty
                                      ? 'Delivery Road (Direct Area)'
                                      : 'Delivery Road / Street *',
                                  prefixIcon: const Icon(Icons.signpost_rounded),
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: _availableRoads.isEmpty
                                    ? [
                                        DropdownMenuItem<String>(
                                          value: _selectedAreaId ?? '',
                                          child: Text(
                                            _selectedAreaName != null && _selectedAreaName!.isNotEmpty
                                                ? 'Direct in $_selectedAreaName (No roads added)'
                                                : '-- Direct Area / No Roads --',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ]
                                    : _availableRoads.map((r) {
                                        return DropdownMenuItem<String>(
                                          value: r['id'] as String,
                                          child: Text(
                                            r['name'] as String,
                                            style: const TextStyle(fontWeight: FontWeight.w500),
                                          ),
                                        );
                                      }).toList(),
                                onChanged: (newRoadId) {
                                  if (newRoadId != null &&
                                      _availableRoads.isNotEmpty &&
                                      newRoadId != _selectedRoadId) {
                                    _onRoadChanged(newRoadId);
                                  }
                                },
                                validator: (v) {
                                  if (_availableRoads.isNotEmpty && (v == null || v.isEmpty)) {
                                    return 'Please select a road';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              onPressed: _selectedAreaId == null ? null : _showAddNewRoadDialog,
                              icon: const Icon(Icons.add_road_rounded),
                              tooltip: 'Add New Road',
                            ),
                          ],
                        ),

                        if (_availableSubRoads.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _selectedSubRoadId,
                            decoration: const InputDecoration(
                              labelText: 'Sub-Road / Colony (optional)',
                              prefixIcon: Icon(Icons.turn_slight_right_rounded),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: '',
                                child: Text('-- None --'),
                              ),
                              ..._availableSubRoads.map((sr) {
                                return DropdownMenuItem<String>(
                                  value: sr['id'] as String,
                                  child: Text(sr['name'] as String),
                                );
                              }),
                            ],
                            onChanged: (newSubRoadId) {
                              _onSubRoadChanged(newSubRoadId ?? '');
                            },
                          ),
                        ],

                        if (_selectedAreaName != null && _selectedRoadName != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.check_circle_outline_rounded,
                                  size: 14, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Route Assigned: $_selectedRoadName, $_selectedAreaName',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),

              Row(
                children: [
                  // Serial Number
                  SizedBox(
                    width: 120,
                    child: TextFormField(
                      controller: _serialNoCon,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Serial No.',
                        prefixIcon: Icon(Icons.format_list_numbered_rounded),
                        hintText: 'e.g. 1',
                      ),
                      validator: (v) {
                        if (v != null && v.trim().isNotEmpty) {
                          final parsed = int.tryParse(v.trim());
                          if (parsed == null) {
                            return 'Invalid number';
                          }
                          if (parsed < 1) {
                            return 'Must be ≥ 1';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _houseCon,
                      readOnly: (_isEdit && _existingHouseFamilies.isNotEmpty) ||
                          (widget.initialHouseNumber != null &&
                              widget.initialHouseNumber!.isNotEmpty),
                      decoration: InputDecoration(
                        labelText: 'House / Flat Number (optional)',
                        prefixIcon: const Icon(Icons.home_rounded),
                        suffixIcon: ((_isEdit && _existingHouseFamilies.isNotEmpty) ||
                                (widget.initialHouseNumber != null &&
                                    widget.initialHouseNumber!.isNotEmpty))
                            ? const Tooltip(
                                message: 'House Number is locked for shared household',
                                child: Icon(Icons.lock_outline_rounded,
                                    size: 18, color: AppColors.primary),
                              )
                            : null,
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Address
              TextFormField(
                controller: _addressCon,
                decoration: const InputDecoration(
                  labelText: 'Address Details',
                  prefixIcon: Icon(Icons.location_on_rounded),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Google Maps Location
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _mapsCon,
                      decoration: InputDecoration(
                        labelText: 'Location Coordinates (lat,lng) or Map Link',
                        prefixIcon: const Icon(Icons.location_on_rounded),
                        suffixIcon: _mapsCon.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded,
                                    color: AppColors.error),
                                onPressed: () {
                                  setState(() {
                                    _mapsCon.clear();
                                  });
                                },
                              )
                            : null,
                      ),
                      keyboardType: TextInputType.text,
                      onChanged: (v) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.gps_fixed_rounded),
                    tooltip: 'Set Coordinates',
                    onPressed: _showCoordinatesDialog,
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.map_rounded),
                    tooltip: 'Pick on Map',
                    onPressed: () async {
                      LatLng? currentPos;
                      final text = _mapsCon.text.trim();
                      if (text.isNotEmpty) {
                        final parts = text.split(',');
                        if (parts.length == 2) {
                          final lat = double.tryParse(parts[0]);
                          final lng = double.tryParse(parts[1]);
                          if (lat != null && lng != null) {
                            currentPos = LatLng(lat, lng);
                          }
                        }
                      }
                      final LatLng? picked = await Navigator.pushNamed(
                        context,
                        AppRoutes.mapPinPicker,
                        arguments: {'initialPosition': currentPos},
                      ) as LatLng?;
                      if (picked != null && mounted) {
                        setState(() {
                          _mapsCon.text =
                              '${picked.latitude},${picked.longitude}';
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesCon,
                decoration: const InputDecoration(
                  labelText: 'Additional Notes / Landmark',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Dietary Preference (Optional Veg / Non-Veg)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Dietary Preference (Optional)',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Builder(builder: (ctx) {
                      final isDark =
                          Theme.of(ctx).brightness == Brightness.dark;
                      final unselectedBorder =
                          isDark ? Colors.white24 : Colors.grey.shade300;
                      final unselectedText =
                          isDark ? Colors.white60 : Colors.grey.shade700;
                      final isSelected = _dietaryPreference == 'veg';
                      final activeColor = isDark
                          ? const Color(0xFF4ADE80)
                          : Colors.green.shade700;
                      final activeBorder =
                          isDark ? const Color(0xFF4ADE80) : Colors.green;

                      return OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _dietaryPreference = isSelected ? '' : 'veg';
                          });
                        },
                        icon: Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: isSelected ? activeBorder : unselectedText,
                        ),
                        label: const Text('Veg'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: isSelected ? activeBorder : unselectedBorder,
                            width: isSelected ? 2 : 1,
                          ),
                          foregroundColor:
                              isSelected ? activeColor : unselectedText,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Builder(builder: (ctx) {
                      final isDark =
                          Theme.of(ctx).brightness == Brightness.dark;
                      final unselectedBorder =
                          isDark ? Colors.white24 : Colors.grey.shade300;
                      final unselectedText =
                          isDark ? Colors.white60 : Colors.grey.shade700;
                      final isSelected = _dietaryPreference == 'non_veg';
                      final activeColor = isDark
                          ? const Color(0xFFF87171)
                          : Colors.red.shade700;
                      final activeBorder =
                          isDark ? const Color(0xFFF87171) : Colors.red;

                      return OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _dietaryPreference = isSelected ? '' : 'non_veg';
                          });
                        },
                        icon: Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: isSelected ? activeBorder : unselectedText,
                        ),
                        label: const Text('Non-Veg'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: isSelected ? activeBorder : unselectedBorder,
                            width: isSelected ? 2 : 1,
                          ),
                          foregroundColor:
                              isSelected ? activeColor : unselectedText,
                        ),
                      );
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Custom Fields Section
              if (_customFields.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Additional Custom Attributes',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 8),
                ..._customFields.map((field) {
                  final fid = field['id'] as String;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: _customFieldControllers[fid],
                      decoration: InputDecoration(
                        labelText: field['field_name'] ?? '',
                        prefixIcon: const Icon(Icons.star_outline_rounded),
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _save,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_isEdit ? 'Update Customer' : 'Add Customer'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final img = await ImageUtils.pickAndCompress(source: source);
      if (img != null) {
        setState(() => _photoPath = img.path);
      }
    }
  }

  void _showCoordinatesDialog() {
    final latCon = TextEditingController();
    final lngCon = TextEditingController();

    final current = _mapsCon.text.trim();
    if (current.isNotEmpty && !current.startsWith('http')) {
      final parts = current.split(',');
      if (parts.length == 2) {
        latCon.text = parts[0];
        lngCon.text = parts[1];
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter GPS Coordinates'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latCon,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              decoration: const InputDecoration(
                labelText: 'Latitude (e.g. 18.5204)',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lngCon,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              decoration: const InputDecoration(
                labelText: 'Longitude (e.g. 73.8567)',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final lat = double.tryParse(latCon.text.trim());
              final lng = double.tryParse(lngCon.text.trim());
              if (lat != null && lng != null) {
                setState(() {
                  _mapsCon.text = '$lat,$lng';
                });
                Navigator.pop(ctx);
              } else {
                SnackbarHelper.showError(ctx, 'Please enter valid coordinates');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_streetId == null || _streetId!.isEmpty) {
      if (_selectedSubRoadId != null && _selectedSubRoadId!.isNotEmpty) {
        _streetId = _selectedSubRoadId;
      } else if (_selectedRoadId != null && _selectedRoadId!.isNotEmpty) {
        _streetId = _selectedRoadId;
      } else if (_selectedAreaId != null && _selectedAreaId!.isNotEmpty) {
        _streetId = _selectedAreaId;
      } else {
        SnackbarHelper.showError(context, 'Delivery Area is required');
        return;
      }
    }
    setState(() => _loading = true);

    try {
      final now = DateTime.now();
      final customerId = widget.customerId ?? const Uuid().v4();
      final String codeRaw = _customerCodeCon.text.trim().toUpperCase();
      final db = await DatabaseHelper.instance.database;

      String finalCustomerCode = codeRaw;
      if (finalCustomerCode.isNotEmpty) {
        final RegExp allowedChars = RegExp(r'^[A-Z0-9\-]+$');
        if (!allowedChars.hasMatch(finalCustomerCode)) {
          throw Exception('Customer Code can only contain letters, numbers, and hyphens.');
        }
        if (finalCustomerCode.length < 3) {
          throw Exception('Customer Code must be at least 3 characters long.');
        }
        if (finalCustomerCode.length > 20) {
          throw Exception('Customer Code must be at most 20 characters long.');
        }
        final codeCheck = await db.query(
          'customers',
          columns: ['name'],
          where:
              'customer_code = ? AND id != ? AND (is_archived IS NULL OR is_archived = 0) AND id NOT IN (SELECT id FROM deleted_customers)',
          whereArgs: [finalCustomerCode, customerId],
        );
        if (codeCheck.isNotEmpty) {
          throw Exception('Customer code already assigned. Please enter another code.');
        }
      }

      // For ghost houses: auto-fill placeholder name and phone so DB constraints are satisfied
      final String finalName =
          _isGhostHouse ? '[Ghost House]' : _nameCon.text.trim();
      final String finalPhone =
          _isGhostHouse ? '0000000000' : _phone1Con.text.trim();

      // Auto-generate customer code in ABCDE125 format if blank on new customer creation
      if (finalCustomerCode.isEmpty && !_isGhostHouse && finalName.isNotEmpty) {
        final cleanLetters = finalName.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
        String prefix = cleanLetters;
        if (prefix.length < 5) {
          prefix = '${prefix}OKART'.substring(0, 5);
        } else {
          prefix = prefix.substring(0, 5);
        }
        final cleanDigits = finalPhone.replaceAll(RegExp(r'\D'), '');
        String suffix = cleanDigits.length >= 3 ? cleanDigits.substring(cleanDigits.length - 3) : '101';
        finalCustomerCode = '$prefix$suffix';

        int attempts = 0;
        while (attempts < 100) {
          final dupCheck = await db.query(
            'customers',
            where:
                'customer_code = ? AND id != ? AND (is_archived IS NULL OR is_archived = 0) AND id NOT IN (SELECT id FROM deleted_customers)',
            whereArgs: [finalCustomerCode, customerId],
          );
          if (dupCheck.isEmpty) break;
          final numVal = 100 + attempts;
          finalCustomerCode = '$prefix$numVal';
          attempts++;
        }
      }

      // Skip duplicate-phone check for ghost houses (they all share the same placeholder phone)
      if (!_isGhostHouse) {
        final duplicateCheck = await db.query(
          'customers',
          columns: ['name'],
          where:
              'phone1 = ? AND id != ? AND (is_archived IS NULL OR is_archived = 0) AND id NOT IN (SELECT id FROM deleted_customers)',
          whereArgs: [finalPhone, customerId],
        );
        if (duplicateCheck.isNotEmpty) {
          throw Exception(
              'A customer named "${duplicateCheck.first['name']}" already has this phone number ($finalPhone).');
        }
      }

      String finalPhotoPath = _photoPath;
      if (_photoPath.isNotEmpty) {
        final savedPath = await ImageUtils.saveImagePermanently(
          sourcePath: _photoPath,
          subFolder: 'customer_photos',
          fileName: customerId,
        );
        if (savedPath != null) {
          finalPhotoPath = savedPath;
        }
      }

      double latitude = 0.0;
      double longitude = 0.0;
      final text = _mapsCon.text.trim();
      if (text.isNotEmpty) {
        final regExp =
            RegExp(r'(?:q=|@|^|/|params=)(-?\d+\.\d+)\s*,\s*(-?\d+\.\d+)');
        final match = regExp.firstMatch(text);
        if (match != null) {
          latitude = double.tryParse(match.group(1) ?? '') ?? 0.0;
          longitude = double.tryParse(match.group(2) ?? '') ?? 0.0;
        }
      }

      final existing = _isEdit
          ? await ref
              .read(customerRepositoryProvider)
              .getCustomerById(customerId)
          : null;

      // Auto-compose delivery address if empty, using house number + road + area
      String resolvedAddress = _addressCon.text.trim();
      final String houseNo = _houseCon.text.trim();
      
      String supabaseAreaId = _selectedAreaId ?? '';
      String supabaseRoadId = _selectedRoadId ?? '';
      String supabaseSubRoadId = _selectedSubRoadId ?? '';
      String locationAreaName = _selectedAreaName ?? '';
      String locationRoadName = _selectedRoadName ?? '';
      String locationSubRoadName = _selectedSubRoadName ?? '';

      if (_streetId != null && _streetId!.isNotEmpty) {
        try {
          final locInfo = await ref.read(customerLocationProvider(_streetId!).future);
          if (locationRoadName.isEmpty) locationRoadName = locInfo['roadName'] ?? locInfo['street'] ?? '';
          if (locationAreaName.isEmpty) locationAreaName = locInfo['areaName'] ?? locInfo['area'] ?? '';
          if (locationSubRoadName.isEmpty) locationSubRoadName = locInfo['subRoadName'] ?? '';
        } catch (_) {}
      }

      // Resolve real dedicated IDs from Supabase if online, otherwise pass name for trigger resolution
      if (locationAreaName.isNotEmpty) {
        try {
          final areaRes = await Supabase.instance.client
              .from('areas')
              .select('id')
              .ilike('name', locationAreaName.trim())
              .limit(1)
              .maybeSingle();
          if (areaRes != null && areaRes['id'] != null) {
            supabaseAreaId = areaRes['id'].toString();
          }
        } catch (_) {}
        if (supabaseAreaId.isEmpty) {
          supabaseAreaId = locationAreaName.trim();
        }
      }

      if (locationRoadName.isNotEmpty) {
        try {
          var roadQuery = Supabase.instance.client
              .from('roads')
              .select('id')
              .ilike('name', locationRoadName.trim());
          if (supabaseAreaId.isNotEmpty && !supabaseAreaId.contains(' ')) {
            roadQuery = roadQuery.eq('area_id', supabaseAreaId);
          }
          final roadRes = await roadQuery.limit(1).maybeSingle();
          if (roadRes != null && roadRes['id'] != null) {
            supabaseRoadId = roadRes['id'].toString();
          }
        } catch (_) {}
        if (supabaseRoadId.isEmpty) {
          supabaseRoadId = locationRoadName.trim();
        }
      }

      if (locationSubRoadName.isNotEmpty) {
        try {
          var subRoadQuery = Supabase.instance.client
              .from('sub_roads')
              .select('id')
              .ilike('name', locationSubRoadName.trim());
          if (supabaseRoadId.isNotEmpty && !supabaseRoadId.contains(' ')) {
            subRoadQuery = subRoadQuery.eq('road_id', supabaseRoadId);
          }
          final srRes = await subRoadQuery.limit(1).maybeSingle();
          if (srRes != null && srRes['id'] != null) {
            supabaseSubRoadId = srRes['id'].toString();
          }
        } catch (_) {}
        if (supabaseSubRoadId.isEmpty) {
          supabaseSubRoadId = locationSubRoadName.trim();
        }
      }

      if (resolvedAddress.isEmpty) {
        final parts = <String>[];
        if (houseNo.isNotEmpty) parts.add(houseNo);
        if (locationSubRoadName.isNotEmpty) parts.add(locationSubRoadName);
        if (locationRoadName.isNotEmpty) parts.add(locationRoadName);
        if (locationAreaName.isNotEmpty) parts.add(locationAreaName);
        resolvedAddress = parts.join(', ');
      }

      final customer = existing != null
          ? existing.copyWith(
              streetId: _streetId!,
              name: finalName,
              phone1: finalPhone,
              phone2: _phone2Con.text.trim(),
              whatsapp: _waCon.text.trim(),
              houseNumber: _houseCon.text.trim(),
              serialNo: int.tryParse(_serialNoCon.text.trim()) ?? 0,
              address: resolvedAddress,
              notes: _notesCon.text.trim(),
              mapsLocation: _mapsCon.text.trim(),
              photoPath: finalPhotoPath,
              dietaryPreference: _dietaryPreference,
              latitude: latitude,
              longitude: longitude,
              customerCode: finalCustomerCode,
              updatedAt: now,
            )
          : Customer(
              id: customerId,
              streetId: _streetId!,
              name: finalName,
              phone1: finalPhone,
              phone2: _phone2Con.text.trim(),
              whatsapp: _waCon.text.trim(),
              houseNumber: _houseCon.text.trim(),
              serialNo: int.tryParse(_serialNoCon.text.trim()) ?? 0,
              address: resolvedAddress,
              notes: _notesCon.text.trim(),
              mapsLocation: _mapsCon.text.trim(),
              photoPath: finalPhotoPath,
              dietaryPreference: _dietaryPreference,
              latitude: latitude,
              longitude: longitude,
              customerSince: now,
              createdAt: now,
              updatedAt: now,
              customerCode: finalCustomerCode,
            );

      final notifier = ref.read(customerListProvider(_streetId!).notifier);
      if (_isEdit) {
        if (existing != null &&
            existing.photoPath.isNotEmpty &&
            existing.photoPath != finalPhotoPath) {
          final oldFile = File(existing.photoPath);
          if (oldFile.existsSync()) {
            try {
              oldFile.deleteSync();
            } catch (_) {}
          }
          final fallbackOld = AppConstants.resolveFile(existing.photoPath);
          if (fallbackOld.existsSync()) {
            try {
              fallbackOld.deleteSync();
            } catch (_) {}
          }
        }
        await notifier.update(customer);
      } else {
        await notifier.add(customer);
      }

      // Save custom field values
      for (final entry in _customFieldControllers.entries) {
        final fieldId = entry.key;
        final val = entry.value.text.trim();
        if (val.isNotEmpty) {
          await db.insert(
              'custom_field_values',
              {
                'entity_id': customerId,
                'field_id': fieldId,
                'value': val,
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
        } else {
          await db.delete('custom_field_values',
              where: 'entity_id = ? AND field_id = ?',
              whereArgs: [customerId, fieldId]);
        }
      }

      // Sync customer to Supabase in the background so local save is instant (<20ms)
      final bool isGhost = finalName.isEmpty ||
          finalName == '[Ghost House]' ||
          finalName.toLowerCase() == 'ghost house' ||
          finalName.startsWith('[Ghost House]') ||
          finalPhone == '0000000000' ||
          finalPhone.isEmpty;

      if (!isGhost) {
        // Fire and forget in background so UI pops immediately
        Future.microtask(() async {
          try {
            await CustomerOrderSyncService.instance.ensureSupabaseAuth();
            final client = Supabase.instance.client;
            final cleanId = _getValidUuid(customerId);
            try {
              await client.rpc('sync_customer_with_code', params: {
                'p_id': cleanId,
                'p_name': finalName,
                'p_phone': finalPhone,
                'p_email': '',
                'p_address': resolvedAddress,
                'p_customer_code': finalCustomerCode,
                'p_area_id': supabaseAreaId.isNotEmpty ? supabaseAreaId : null,
                'p_road_id': supabaseRoadId.isNotEmpty ? supabaseRoadId : null,
                'p_sub_road_id': supabaseSubRoadId.isNotEmpty ? supabaseSubRoadId : null,
              }).timeout(const Duration(seconds: 8));
            } catch (rpcErr) {
              debugPrint('CustomerCode: RPC sync_customer_with_code failed: $rpcErr. Falling back to direct upsert.');
              final row = <String, dynamic>{
                'id': cleanId,
                'name': finalName,
                'phone': finalPhone,
                'address': resolvedAddress,
                if (finalCustomerCode.isNotEmpty) 'customer_code': finalCustomerCode,
                if (supabaseAreaId.isNotEmpty) 'area_id': supabaseAreaId,
                if (supabaseRoadId.isNotEmpty) 'road_id': supabaseRoadId,
                if (supabaseSubRoadId.isNotEmpty) 'sub_road_id': supabaseSubRoadId,
              };
              await client.from('customers').upsert(row, onConflict: 'id');
            }
            // Mark customer as synced in settings with timestamp
            final nowMillis = DateTime.now().millisecondsSinceEpoch.toString();
            final dbLocal = await DatabaseHelper.instance.database;
            await dbLocal.insert(
              'settings',
              {'key': 'customer_sync_time:$customerId', 'value': nowMillis},
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            await dbLocal.insert(
              'settings',
              {'key': 'customer_sync_status:$customerId', 'value': '1'},
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            debugPrint('CustomerCode: Background synced customer $finalName ($customerId) to Supabase.');
          } catch (e) {
            debugPrint('CustomerCode: Supabase background sync failed (triggering sync service): $e');
            unawaited(CustomerOrderSyncService.instance.syncAllExistingCustomers());
          }
        });
      } else {
        debugPrint('CustomerCode: Skipping Supabase sync for ghost house $finalName ($customerId).');
      }

      if (!mounted) return;
      if (_isEdit) {
        SnackbarHelper.showSuccess(context, 'Customer details updated');
      } else {
        SnackbarHelper.showSuccess(context, 'Customer added successfully');
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to save customer: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _getValidUuid(String rawId) {
    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (uuidRegex.hasMatch(rawId)) {
      return rawId;
    }
    return const Uuid().v5(Uuid.NAMESPACE_DNS, 'aplibhaji.customer.$rawId');
  }
}
