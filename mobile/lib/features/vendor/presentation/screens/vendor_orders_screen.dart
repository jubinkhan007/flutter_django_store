import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../logistics/data/models/logistics_area_model.dart';
import '../../../logistics/data/models/logistics_store_model.dart';
import '../../../logistics/data/repositories/logistics_repository.dart';
import '../providers/vendor_provider.dart';

class VendorOrdersScreen extends StatefulWidget {
  const VendorOrdersScreen({super.key});

  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends State<VendorOrdersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VendorProvider>().loadOrders();
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return AppColors.warning;
      case 'PAID':
        return Colors.blue;
      case 'SHIPPED':
        return Colors.cyan;
      case 'DELIVERED':
        return AppColors.success;
      case 'CANCELED':
        return AppColors.error;
      default:
        return AppColors.lightTextSecondary;
    }
  }

  Color _paymentColor(String status) {
    switch (status) {
      case 'PAID':
        return AppColors.success;
      case 'REFUNDED':
        return AppColors.warning;
      case 'UNPAID':
      default:
        return AppColors.error;
    }
  }

  String? _nextStatus(String currentStatus) {
    switch (currentStatus) {
      case 'PENDING':
        return 'SHIPPED';
      case 'SHIPPED':
        return 'DELIVERED';
      default:
        return null; // DELIVERED and CANCELED are terminal
    }
  }

  String _nextStatusLabel(String nextStatus) {
    switch (nextStatus) {
      case 'SHIPPED':
        return 'Mark Shipped';
      case 'DELIVERED':
        return 'Mark Delivered';
      default:
        return 'Update';
    }
  }

  /// Shows a bottom sheet to collect courier details, then calls fulfill endpoint.
  Future<void> _showFulfillSheet(BuildContext context, int subOrderId) async {
    final vendor = context.read<VendorProvider>();
    final logistics = context.read<LogisticsRepository>();
    final courierController = TextEditingController();
    final trackingController = TextEditingController();
    final urlController = TextEditingController();
    final weightController = TextEditingController();
    final instructionController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    String courier = 'PATHAO'; // PATHAO / STEADFAST / REDX / MANUAL
    String mode = 'SANDBOX';

    bool didInit = false;
    bool loadingStores = false;
    bool loadingCities = false;
    bool loadingZones = false;
    bool loadingAreas = false;

    List<LogisticsStoreModel> stores = const [];
    LogisticsStoreModel? store;

    List<LogisticsAreaModel> cities = const [];
    LogisticsAreaModel? city;
    List<LogisticsAreaModel> zones = const [];
    LogisticsAreaModel? zone;
    List<LogisticsAreaModel> areas = const [];
    LogisticsAreaModel? area;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            Future<void> ensurePathaoLists() async {
              if (courier != 'PATHAO') return;
              if (stores.isEmpty && !loadingStores) {
                setSheetState(() => loadingStores = true);
                try {
                  final res = await logistics.pathaoStores(mode: mode);
                  setSheetState(() => stores = res);
                } catch (_) {
                  // ignore
                } finally {
                  setSheetState(() => loadingStores = false);
                }
              }
              if (cities.isEmpty && !loadingCities) {
                setSheetState(() => loadingCities = true);
                try {
                  final res = await logistics.pathaoCities(mode: mode);
                  setSheetState(() => cities = res);
                } catch (_) {
                  // ignore
                } finally {
                  setSheetState(() => loadingCities = false);
                }
              }
            }

            Future<void> loadZonesForCity(LogisticsAreaModel selected) async {
              setSheetState(() {
                city = selected;
                zone = null;
                area = null;
                zones = const [];
                areas = const [];
                loadingZones = true;
              });
              try {
                final res = await logistics.pathaoZones(
                  cityId: selected.externalId,
                  mode: mode,
                );
                setSheetState(() => zones = res);
              } catch (_) {
                // ignore
              } finally {
                setSheetState(() => loadingZones = false);
              }
            }

            Future<void> loadAreasForZone(LogisticsAreaModel selected) async {
              setSheetState(() {
                zone = selected;
                area = null;
                areas = const [];
                loadingAreas = true;
              });
              try {
                final res = await logistics.pathaoAreas(
                  zoneId: selected.externalId,
                  mode: mode,
                );
                setSheetState(() => areas = res);
              } catch (_) {
                // ignore
              } finally {
                setSheetState(() => loadingAreas = false);
              }
            }

            if (!didInit) {
              didInit = true;
              Future.microtask(ensurePathaoLists);
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom:
                    MediaQuery.of(sheetCtx).viewInsets.bottom +
                    MediaQuery.of(sheetCtx).padding.bottom +
                    24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.local_shipping_outlined,
                            color: AppColors.lightPrimary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Provide Tracking Details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(sheetCtx),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: courier,
                        decoration: InputDecoration(
                          labelText: 'Courier',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'PATHAO', child: Text('Pathao (Auto)')),
                          DropdownMenuItem(value: 'STEADFAST', child: Text('Steadfast (Auto)')),
                          DropdownMenuItem(value: 'REDX', child: Text('RedX (Auto)')),
                          DropdownMenuItem(value: 'MANUAL', child: Text('Manual / Other')),
                        ],
                        onChanged: (v) {
                          setSheetState(() {
                            courier = v ?? 'PATHAO';
                          });
                          Future.microtask(ensurePathaoLists);
                        },
                      ),
                      const SizedBox(height: 12),
                      if (courier == 'PATHAO') ...[
                        DropdownButtonFormField<LogisticsStoreModel>(
                          value: store,
                          decoration: InputDecoration(
                            labelText: 'Pickup store',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                          ),
                          items: stores
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s.name),
                                ),
                              )
                              .toList(),
                          onChanged: loadingStores ? null : (v) => setSheetState(() => store = v),
                          validator: (_) => store == null ? 'Select a store' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<LogisticsAreaModel>(
                          value: city,
                          decoration: InputDecoration(
                            labelText: 'City',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                          ),
                          items: cities
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c.name),
                                ),
                              )
                              .toList(),
                          onChanged: loadingCities ? null : (v) {
                            if (v == null) return;
                            loadZonesForCity(v);
                          },
                          validator: (_) => city == null ? 'Select a city' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<LogisticsAreaModel>(
                          value: zone,
                          decoration: InputDecoration(
                            labelText: 'Zone',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                          ),
                          items: zones
                              .map(
                                (z) => DropdownMenuItem(
                                  value: z,
                                  child: Text(z.name),
                                ),
                              )
                              .toList(),
                          onChanged: loadingZones || city == null ? null : (v) {
                            if (v == null) return;
                            loadAreasForZone(v);
                          },
                          validator: (_) => zone == null ? 'Select a zone' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<LogisticsAreaModel>(
                          value: area,
                          decoration: InputDecoration(
                            labelText: 'Area',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                          ),
                          items: areas
                              .map(
                                (a) => DropdownMenuItem(
                                  value: a,
                                  child: Text(a.name),
                                ),
                              )
                              .toList(),
                          onChanged: loadingAreas || zone == null ? null : (v) => setSheetState(() => area = v),
                          validator: (_) => area == null ? 'Select an area' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: weightController,
                          decoration: InputDecoration(
                            labelText: 'Weight (kg) *',
                            hintText: 'e.g. 0.5',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) {
                            final val = double.tryParse((v ?? '').trim());
                            if (val == null || val <= 0) return 'Enter a valid weight';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: instructionController,
                          decoration: InputDecoration(
                            labelText: 'Special instruction (optional)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'If the order is COD, the amount-to-collect is set automatically.',
                          style: TextStyle(
                            color: AppColors.lightTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (courier == 'STEADFAST' || courier == 'REDX') ...[
                        const Text(
                          'This will request automatic courier provisioning. You can monitor status from the order card once tracking is assigned.',
                          style: TextStyle(
                            color: AppColors.lightTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (courier == 'MANUAL') ...[
                        TextFormField(
                          controller: courierController,
                          decoration: InputDecoration(
                            labelText: 'Courier Name *',
                            hintText: 'e.g. Pathao, RedX, Sundarban',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: trackingController,
                          decoration: InputDecoration(
                            labelText: 'Tracking Number *',
                            hintText: 'e.g. PH-12345678',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: urlController,
                          keyboardType: TextInputType.url,
                          decoration: InputDecoration(
                            labelText: 'Tracking URL (optional)',
                            hintText: 'https://track.pathao.com/...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setSheetState(() => isSaving = true);
                                  final isAuto = courier != 'MANUAL';
                                  final success = await vendor.fulfillSubOrder(
                                    subOrderId,
                                    autoProvision: isAuto,
                                    courierCode: courier.toLowerCase(),
                                    courierName: courierController.text.trim(),
                                    trackingNumber: trackingController.text.trim(),
                                    trackingUrl: urlController.text.trim(),
                                    mode: mode,
                                    provisionRequest: isAuto
                                        ? {
                                            if (courier == 'PATHAO') ...{
                                              'store_id': int.tryParse(store!.externalStoreId) ?? store!.id,
                                              'recipient_city': int.parse(city!.externalId),
                                              'recipient_zone': int.parse(zone!.externalId),
                                              'recipient_area': int.parse(area!.externalId),
                                              'item_weight': double.parse(weightController.text.trim()),
                                              'special_instruction': instructionController.text.trim(),
                                            },
                                          }
                                        : null,
                                  );
                                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          success
                                              ? (isAuto
                                                    ? 'Provision requested. Tracking will appear soon.'
                                                    : 'Order marked as shipped!')
                                              : vendor.error ??
                                                    'Failed to update',
                                        ),
                                        backgroundColor: success
                                            ? AppColors.success
                                            : AppColors.error,
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.lightPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Confirm Shipment',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Text(
              'Incoming Orders',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.lightTextPrimary,
              ),
            ),
          ),
          Expanded(
            child: Consumer<VendorProvider>(
              builder: (context, vendor, _) {
                if (vendor.isLoading) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).primaryColor,
                    ),
                  );
                }

                if (vendor.orders.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          color: AppColors.lightTextSecondary,
                          size: 48,
                        ),
                        SizedBox(height: AppSpacing.md),
                        Text(
                          'No orders yet',
                          style: TextStyle(
                            color: AppColors.lightTextSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: Theme.of(context).primaryColor,
                  onRefresh: () => vendor.loadOrders(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    itemCount: vendor.orders.length,
                    itemBuilder: (context, index) {
                      final order = vendor.orders[index];
                      final statusColor = _statusColor(order.status);
                      final paymentColor = _paymentColor(order.paymentStatus);
                      final nextStatus = _nextStatus(order.status);

                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Order #${order.parentOrderId ?? order.id}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (order.parentOrderId != null &&
                                        order.parentOrderId != order.id)
                                      Text(
                                        'SubOrder #${order.id}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.lightTextSecondary,
                                        ),
                                      ),
                                    Text(
                                      'Payment: ${order.paymentStatus}',
                                      style: TextStyle(
                                        color: paymentColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withAlpha(30),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    order.status,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...order.items.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.circle,
                                      size: 5,
                                      color: AppColors.lightTextSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${item.productName ?? 'Product'} × ${item.quantity}',
                                        style: const TextStyle(
                                          color: AppColors.lightTextSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: AppColors.lightTextSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text(
                                  'Total: \$${order.totalAmount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                const Spacer(),
                                if (order.status == 'PENDING' ||
                                    (order.paymentStatus == 'PAID' &&
                                        order.status != 'DELIVERED' &&
                                        order.status != 'CANCELED'))
                                  TextButton(
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Cancel & Refund'),
                                          content: const Text(
                                            'Are you sure you want to cancel and refund this order?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('No'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text(
                                                'Yes',
                                                style: TextStyle(
                                                  color: AppColors.error,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true &&
                                          context.mounted) {
                                        await vendor.cancelOrder(order.id);
                                      }
                                    },
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color: AppColors.error,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                if (nextStatus != null)
                                  Builder(
                                    builder: (context) {
                                      final provision =
                                          (order.provisionStatus ?? 'NOT_STARTED')
                                              .toUpperCase();
                                      final isProvisioning =
                                          provision == 'REQUESTED';
                                      final isFailed = provision == 'FAILED';

                                      if (nextStatus == 'SHIPPED' &&
                                          isProvisioning) {
                                        return ElevatedButton(
                                          onPressed: null,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Theme.of(context).primaryColor,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 0,
                                            ),
                                            textStyle: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          child: const Text('Provisioning…'),
                                        );
                                      }

                                      if (nextStatus == 'SHIPPED' && isFailed) {
                                        return OutlinedButton(
                                          onPressed: () async {
                                            try {
                                              await context
                                                  .read<LogisticsRepository>()
                                                  .retryProvision(order.id);
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Retry requested. Tracking will appear soon.',
                                                    ),
                                                  ),
                                                );
                                              }
                                              await vendor.loadOrders();
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      e
                                                          .toString()
                                                          .replaceAll(
                                                            'Exception: ',
                                                            '',
                                                          ),
                                                    ),
                                                    backgroundColor:
                                                        AppColors.error,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                          child: const Text('Retry'),
                                        );
                                      }

                                      return ElevatedButton(
                                        onPressed: () async {
                                          if (nextStatus == 'SHIPPED') {
                                            await _showFulfillSheet(
                                              context,
                                              order.id,
                                            );
                                          } else {
                                            await vendor.updateOrderStatus(
                                              order.id,
                                              nextStatus,
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Theme.of(context).primaryColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 0,
                                          ),
                                          textStyle: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        child:
                                            Text(_nextStatusLabel(nextStatus)),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
