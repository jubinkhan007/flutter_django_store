import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../products/data/models/product_model.dart';
import '../../../products/presentation/providers/product_provider.dart';
import '../providers/vendor_provider.dart';

class VendorAddProductScreen extends StatefulWidget {
  final ProductModel? initialProduct;

  const VendorAddProductScreen({super.key, this.initialProduct});

  @override
  State<VendorAddProductScreen> createState() => _VendorAddProductScreenState();
}

class _VendorAddProductScreenState extends State<VendorAddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  int? _selectedCategoryId;

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    if (widget.initialProduct != null) {
      final p = widget.initialProduct!;
      _nameController.text = p.name;
      _descriptionController.text = p.description;
      _priceController.text = p.price.toString();
      _stockController.text = p.stockQuantity.toString();
      _selectedCategoryId = p.categoryId;
    }

    // Load categories for the dropdown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadCategories();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }

    final vendor = context.read<VendorProvider>();

    final fields = {
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'price': _priceController.text.trim(),
      'stock_quantity': _stockController.text.trim(),
      'category': _selectedCategoryId.toString(),
      'is_available': 'true',
    };

    http.MultipartFile? imageFile;
    if (_selectedImage != null) {
      imageFile = await http.MultipartFile.fromPath(
        'image',
        _selectedImage!.path,
        contentType: MediaType('image', 'jpeg'),
      );
    }

    bool success;
    if (widget.initialProduct == null) {
      success = await vendor.addProduct(fields: fields, imageFile: imageFile);
    } else {
      success = await vendor.updateProduct(
        productId: widget.initialProduct!.id,
        fields: fields,
        imageFile: imageFile,
      );
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.initialProduct == null
                ? 'Product added successfully!'
                : 'Product updated successfully!',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialProduct == null ? 'Add Product' : 'Edit Product',
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Picker Section
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: AppColors.lightTextSecondary.withAlpha(50),
                        width: 1,
                      ),
                      image: _selectedImage != null
                          ? DecorationImage(
                              image: FileImage(_selectedImage!),
                              fit: BoxFit.cover,
                            )
                          : (widget.initialProduct?.image != null
                                ? DecorationImage(
                                    image: NetworkImage(
                                      widget.initialProduct!.image!,
                                    ),
                                    fit: BoxFit.cover,
                                  )
                                : null),
                    ),
                    child:
                        _selectedImage == null &&
                            widget.initialProduct?.image == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_outlined,
                                color: AppColors.lightTextSecondary,
                                size: 32,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Add Photo',
                                style: TextStyle(
                                  color: AppColors.lightTextSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              AppTextField(
                controller: _nameController,
                hintText: 'e.g., Wireless Headphones',
                labelText: 'Product Name',
                prefixIcon: Icons.shopping_bag_outlined,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a product name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              AppTextField(
                controller: _descriptionController,
                hintText: 'Describe your product...',
                labelText: 'Description',
                prefixIcon: Icons.description_outlined,
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _priceController,
                      hintText: '0.00',
                      labelText: 'Price (\$)',
                      prefixIcon: Icons.attach_money,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter price';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Invalid price';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _stockController,
                      hintText: '0',
                      labelText: 'Stock Qty',
                      prefixIcon: Icons.inventory,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter stock';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Invalid number';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Category Dropdown
              Consumer<ProductProvider>(
                builder: (context, productProvider, _) {
                  return DropdownButtonFormField<int>(
                    value: _selectedCategoryId,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      prefixIcon: const Icon(Icons.category_outlined, size: 20),
                      filled: true,
                      fillColor: AppColors.lightSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    dropdownColor: AppColors.lightSurface,
                    items: productProvider.categories
                        .map(
                          (cat) => DropdownMenuItem<int>(
                            value: cat.id,
                            child: Text(cat.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedCategoryId = value);
                    },
                    hint: const Text(
                      'Select a category',
                      style: TextStyle(color: AppColors.lightTextSecondary),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),

              // Error
              Consumer<VendorProvider>(
                builder: (context, vendor, _) {
                  if (vendor.error != null) {
                    return Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppSpacing.md,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withAlpha(25),
                          borderRadius: BorderRadius.circular(
                            AppRadius.sm,
                          ),
                        ),
                        child: Text(
                          vendor.error!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // Submit Button
              Consumer<VendorProvider>(
                builder: (context, vendor, _) {
                  return PrimaryButton(
                    text: 'Add Product',
                    isLoading: vendor.isLoading,
                    onPressed: _handleSubmit,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
