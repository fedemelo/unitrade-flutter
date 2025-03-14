import 'package:flutter/material.dart';
import 'package:unitrade/screens/home/models/product_model.dart';
import 'package:unitrade/screens/home/models/filter_model.dart';
import 'package:unitrade/screens/home/viewmodels/filter_viewmodel.dart';
import 'package:unitrade/screens/home/views/filter_section_view.dart';
import 'package:unitrade/utils/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:unitrade/utils/product_service.dart';
import 'package:unitrade/utils/connectivity_service.dart';

class HomeViewModel extends ChangeNotifier {
  String selectedCategory = 'For You';
  String searchValue = '';
  FilterModel filters = FilterModel();

  bool finishedGets = false;
  bool selectedFilters = false;
  bool currentConnection = false;
  bool isSnackBarVisible = false;

  List<String> favoriteProducts = [];

  List<String> categoryElementList = [];
  List<String> categoryGroupList = [
    'For You',
    'Study',
    'Tech',
    'Creative',
    'Others',
    'Lab',
    'Personal'
  ];
  List<String> categoryUserList = [];
  List<ProductModel> productElementList = [];

  final FirebaseFirestore _firestore = FirebaseService.instance.firestore;
  final FirebaseAuth _firebase = FirebaseService.instance.auth;

  List<ProductModel> filteredProducts = [];

  HomeViewModel() {
    fetchAllData();
    _filterProducts();
  }

  void updateScreen() {
    notifyListeners();
  }

  void updateFilterColor(bool filter) {
    selectedFilters = filter;
    notifyListeners();
  }

  void showFilterWidget(BuildContext context, HomeViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return FilterSectionView(
          actualFilters: viewModel.filters,
          onUpdateFilters: viewModel.updateFilters,
          selectedFilters: updateFilterColor,
        );
      },
    );
  }

  void _filterProducts() {
    filteredProducts = FilterViewModel.filterProducts(
      allProducts: productElementList,
      selectedCategory: selectedCategory,
      searchQuery: searchValue,
      filters: filters,
      userCategories: categoryUserList,
    );
    notifyListeners();
  }

  void clickCategory(String category) {
    selectedCategory = category;
    searchValue = '';
    _filterProducts();
  }

  void updateSearch(String value) {
    searchValue = value;
    selectedCategory = '';
    _filterProducts();
  }

  void updateFilters(FilterModel newFilters) {
    filters = newFilters;
    _filterProducts();
  }

  Future<void> fetchCategories() async {
    final categoriesDoc =
        await _firestore.collection('categories').doc('all').get();

    if (categoriesDoc.exists) {
      List<dynamic> categories = categoriesDoc.data()?['names'] ?? [];

      categoryElementList = List<String>.from(categories.map((category) {
        String lowerCased = category.toLowerCase();
        return '${lowerCased[0].toUpperCase()}${lowerCased.substring(1)}';
      }));

      categoryElementList.insert(0, 'For You');
    } else {
      throw Exception("Categories not found");
    }
  }

  Future<void> fetchUserCategories() async {
    final categoriesDoc = await _firestore
        .collection('users')
        .doc(_firebase.currentUser?.uid)
        .get();

    if (categoriesDoc.exists) {
      List<dynamic> categories = categoriesDoc.data()?['categories'] ?? [];

      categoryUserList = List<String>.from(categories.map((category) {
        String lowerCased = category.toLowerCase();
        return '${lowerCased[0].toUpperCase()}${lowerCased.substring(1)}';
      }));
    } else {
      categoryUserList = ["TEXTBOOKS", "ELECTRONICS"];
    }
  }

  Future<void> fetchFavorites() async {
    final favoritesDoc = await _firestore
        .collection('users')
        .doc(_firebase.currentUser?.uid)
        .get();

    if (favoritesDoc.exists) {
      List<dynamic> favorites = favoritesDoc.data()?['favorites'] ?? [];

      favoriteProducts = List<String>.from(favorites);
    } else {
      throw Exception("Favorites not found");
    }
  }

  Future<void> fetchProducts() async {
    final QuerySnapshot productsSnapshot =
        await _firestore.collection('products').get(); // .where('in_stock', isEqualTo: true).get();

    if (productsSnapshot.docs.isNotEmpty) {
      List<ProductModel> products = productsSnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return ProductModel(
          id: doc.id,
          name: data['name'] ?? '',
          description: data['description'] ?? '',
          price: double.tryParse(data['price'].toString()) ?? 0.0,
          categories:
              List<String>.from((data['categories'] ?? []).map((category) {
            String lowerCased = category.toLowerCase();
            return '${lowerCased[0].toUpperCase()}${lowerCased.substring(1)}';
          })),
          userId: data['user_id'] ?? '',
          type: data['type'] ?? '',
          imageUrl: data['image_url'] ?? '',
          favoritesForyou: data['favorites_foryou'] ?? 0,
          favoritesCategory: data['favorites_category'] ?? 0,
          condition: data['condition'] ?? '',
          rentalPeriod: data['rental_period'] ?? '',
        );
      }).toList();

      productElementList = products;
    } else {
      throw Exception("No products found");
    }
  }

  Future<void> fetchAllData() async {
    var connectivity = ConnectivityService();
    var hasConnection = await connectivity.checkConnectivity();

    if (!hasConnection) {
      currentConnection = false;
      finishedGets = true;
      notifyListeners();
      return;
    } else {
      currentConnection = true;
      notifyListeners();
    }

    try {
      await Future.wait([
        fetchCategories(),
        fetchUserCategories(),
        fetchFavorites(),
      ]);

      if (ProductService.instance.products != null) {
        productElementList = ProductService.instance.products!;
      } else {
        await Future.wait([fetchProducts()]);
        print("Error: Productos no cargados después de varios intentos.");
      }

      finishedGets = true;
      _filterProducts();
    } catch (e) {
      print("Error fetching data: $e");
    }
  }

  Future<void> refreshData(BuildContext context) async {
    var connectivity = ConnectivityService();
    var hasConnection = await connectivity.checkConnectivity();

    if (!hasConnection) {
      currentConnection = false;
      if (!isSnackBarVisible) {
        isSnackBarVisible = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "No internet connection. You can still see our products but you could see old information.",
            ),
            duration: const Duration(days: 1),
            action: SnackBarAction(
              label: "OK",
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                isSnackBarVisible = false;
              },
            ),
          ),
        );
      }
      notifyListeners();
      return;
    } else {
      currentConnection = true;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      isSnackBarVisible = false;
    }

    try {
      await Future.wait([
        fetchCategories(),
        fetchUserCategories(),
        fetchProducts(),
        fetchFavorites(),
      ]);
      print("Data refreshed");

      _filterProducts();
    } catch (e) {
      print("Error fetching data: $e");
    }
  }
}
