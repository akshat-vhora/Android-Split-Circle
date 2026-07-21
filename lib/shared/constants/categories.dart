import 'package:flutter/material.dart';

class CategoryInfo {
  final String name;
  final IconData icon;
  final Color color;

  const CategoryInfo({
    required this.name,
    required this.icon,
    required this.color,
  });
}

const List<CategoryInfo> kCategories = [
  CategoryInfo(name: 'Food', icon: Icons.restaurant, color: Color(0xFFFF7043)),
  CategoryInfo(name: 'Travel', icon: Icons.flight, color: Color(0xFF42A5F5)),
  CategoryInfo(name: 'Rent', icon: Icons.home, color: Color(0xFF66BB6A)),
  CategoryInfo(name: 'Utilities', icon: Icons.bolt, color: Color(0xFFFFCA28)),
  CategoryInfo(
    name: 'Entertainment',
    icon: Icons.movie,
    color: Color(0xFFAB47BC),
  ),
  CategoryInfo(
    name: 'Shopping',
    icon: Icons.shopping_bag,
    color: Color(0xFFEC407A),
  ),
  CategoryInfo(
    name: 'Health',
    icon: Icons.local_hospital,
    color: Color(0xFF26A69A),
  ),
  CategoryInfo(name: 'Other', icon: Icons.category, color: Color(0xFF78909C)),
];

CategoryInfo categoryFromName(String name) => kCategories.firstWhere(
  (c) => c.name == name,
  orElse: () => kCategories.last,
);
