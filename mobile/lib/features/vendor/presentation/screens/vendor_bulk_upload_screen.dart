import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_button.dart';
import '../providers/vendor_provider.dart';
import 'dart:async';

class VendorBulkUploadScreen extends StatefulWidget {
  const VendorBulkUploadScreen({super.key});

  @override
  State<VendorBulkUploadScreen> createState() => _VendorBulkUploadScreenState();
}

class _VendorBulkUploadScreenState extends State<VendorBulkUploadScreen> {
  String _selectedJobType = 'PRODUCT_UPLOAD';
  String? _selectedFilePath;
  String? _selectedFileName;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VendorProvider>().loadBulkJobs();
      _startPolling();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        context.read<VendorProvider>().loadBulkJobs();
      }
    });
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
    );

    if (result != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
        _selectedFileName = result.files.single.name;
      });
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file to upload')),
      );
      return;
    }

    final provider = context.read<VendorProvider>();
    final success = await provider.uploadBulkJob(_selectedJobType, _selectedFilePath!);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File uploaded successfully! Processing started.')),
        );
        setState(() {
          _selectedFilePath = null;
          _selectedFileName = null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error ?? 'Upload failed')),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'COMPLETED':
        return AppTheme.success;
      case 'PARTIAL_SUCCESS':
        return AppTheme.warning;
      case 'FAILED':
        return AppTheme.error;
      case 'PROCESSING':
      case 'PENDING':
        return AppTheme.primary;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Operations'),
        backgroundColor: AppTheme.surface,
        elevation: 0,
      ),
      backgroundColor: AppTheme.background,
      body: Consumer<VendorProvider>(
        builder: (context, vendorProvider, child) {
          final jobs = vendorProvider.bulkJobs;

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                color: AppTheme.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Upload Data',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedJobType,
                      decoration: const InputDecoration(
                        labelText: 'Operation Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'PRODUCT_UPLOAD',
                          child: Text('Product Upload'),
                        ),
                        DropdownMenuItem(
                          value: 'PRICE_UPDATE',
                          child: Text('Price Update'),
                        ),
                        DropdownMenuItem(
                          value: 'STOCK_UPDATE',
                          child: Text('Stock Update'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedJobType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickFile,
                            icon: const Icon(Icons.attach_file),
                            label: Text(_selectedFileName ?? 'Select CSV/Excel File'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    CustomButton(
                      text: 'Upload and Process',
                      isLoading: vendorProvider.isLoading,
                      onPressed: _uploadFile,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: jobs.isEmpty
                    ? const Center(child: Text('No recent bulk jobs.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(AppTheme.spacingMd),
                        itemCount: jobs.length,
                        itemBuilder: (context, index) {
                          final job = jobs[index];
                          final status = job['status'] ?? 'UNKNOWN';
                          final date = job['created_at'] != null 
                              ? DateTime.parse(job['created_at']).toLocal().toString().split('.')[0] 
                              : '';
                              
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        job['job_type'] ?? 'Unknown Job',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(status).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            color: _getStatusColor(status),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Submitted: $date', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                  const SizedBox(height: 8),
                                  if (job['result_report'] != null)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Divider(),
                                        Text('Processed: ${job['result_report']['processed'] ?? 0} rows'),
                                        Text('Success: ${job['result_report']['success'] ?? 0} rows'),
                                        if ((job['result_report']['errors'] as List?)?.isNotEmpty == true)
                                          Text(
                                            'Errors: ${(job['result_report']['errors'] as List).length}',
                                            style: const TextStyle(color: AppTheme.error),
                                          ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
