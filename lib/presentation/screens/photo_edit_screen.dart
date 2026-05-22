import 'dart:io';
import 'package:flutter/material.dart';

class PhotoEditScreen extends StatelessWidget {
  final String photoPath;

  const PhotoEditScreen({super.key, required this.photoPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Edit Foto', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.file(
              File(photoPath),
              height: 300,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            const Text(
              'Fitur Edit akan dikembangkan di sini',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
