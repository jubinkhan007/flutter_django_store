import 'package:flutter/material.dart';
import '../../data/models/ad_campaign_model.dart';
import '../../data/repositories/vendor_repository.dart';

class VendorAdsProvider extends ChangeNotifier {
  final VendorRepository _vendorRepository;

  VendorAdsProvider({required VendorRepository vendorRepository})
      : _vendorRepository = vendorRepository;

  AdStatsModel _stats = AdStatsModel.empty();
  List<AdCampaignModel> _campaigns = [];
  bool _isLoading = false;
  bool _isActionLoading = false;
  String? _error;

  AdStatsModel get stats => _stats;
  List<AdCampaignModel> get campaigns => _campaigns;
  bool get isLoading => _isLoading;
  bool get isActionLoading => _isActionLoading;
  String? get error => _error;

  Future<void> loadAdsData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _vendorRepository.getAdStats(),
        _vendorRepository.getAdCampaigns(),
      ]);

      _stats = results[0] as AdStatsModel;
      _campaigns = results[1] as List<AdCampaignModel>;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleCampaignStatus(int campaignId, bool activate) async {
    _isActionLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newStatus = activate ? 'ACTIVE' : 'PAUSED';
      final updated = await _vendorRepository.updateAdCampaignStatus(
        campaignId: campaignId,
        status: newStatus,
      );

      final index = _campaigns.indexWhere((c) => c.id == campaignId);
      if (index != -1) {
        _campaigns[index] = updated;
      }
      // Refresh stats
      _stats = await _vendorRepository.getAdStats();
      _isActionLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isActionLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> createCampaign({
    required int productId,
    required double budgetTotal,
    double? dailyBudget,
    required double costPerClick,
    List<String> keywords = const [],
    List<int> targetCategoryIds = const [],
  }) async {
    _isActionLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _vendorRepository.createAdCampaign(
        productId: productId,
        budgetTotal: budgetTotal,
        dailyBudget: dailyBudget,
        costPerClick: costPerClick,
        keywords: keywords,
        targetCategoryIds: targetCategoryIds,
      );

      await loadAdsData();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isActionLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> topUp(double amount) async {
    _isActionLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _vendorRepository.topUpAdCredits(amount: amount);
      await loadAdsData();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isActionLoading = false;
      notifyListeners();
      return false;
    }
  }
}
