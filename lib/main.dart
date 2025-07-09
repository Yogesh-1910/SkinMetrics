
import 'package:flutter/material.dart';
import 'package:flutter_tflite/flutter_tflite.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:percent_indicator/percent_indicator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skin Analyzer',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.teal,
        fontFamily: 'Roboto',
      ),
      debugShowCheckedModeBanner: false,
      home: const SkinAnalyzerHome(),
    );
  }
}

class SkinAnalyzerHome extends StatefulWidget {
  const SkinAnalyzerHome({super.key});

  @override
  State<SkinAnalyzerHome> createState() => _SkinAnalyzerHomeState();
}

class _SkinAnalyzerHomeState extends State<SkinAnalyzerHome> {
  File? _image;
  List? _recognitions;
  bool _isLoading = false;
  bool _modelLoaded = false;

  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    loadModel().then((value) {
      setState(() {
        _modelLoaded = true;
      });
    });
  }

  Future<void> loadModel() async {
    Tflite.close();
    try {
      String? res = await Tflite.loadModel(
        model: "assets/skin_model.tflite", // <-- IMPORTANT: Check this name
        labels: "assets/labels.txt",
      );
      print("Model loaded: $res");
    } catch (e) {
      print("Failed to load model: $e");
    }
  }

  // THE FIX: This function is now called by the "Analyze" button
  Future<void> predictImage(File image) async {
    setState(() => _isLoading = true);

    var recognitions = await Tflite.runModelOnImage(
      path: image.path,
      numResults: 5,
      threshold: 0.05,
      imageMean: 127.5,
      imageStd: 127.5,
    );

    setState(() {
      _recognitions = recognitions;
      _isLoading = false;
    });
  }

  // THE FIX: This function now ONLY picks the image
  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await picker.pickImage(source: source);
    if (image == null) return;
    setState(() {
      _image = File(image.path);
      _recognitions = null; // Clear previous results
      _isLoading = false;   // Ensure loading is off
    });
  }

  @override
  void dispose() {
    Tflite.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skin Lesion Analyzer'),
        centerTitle: true,
      ),
      body: !_modelLoaded
          ? _buildLoadingModelScreen()
          : _buildMainUI(),
      floatingActionButton: _modelLoaded ? _buildFloatingActionButton() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildLoadingModelScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text("Loading Model...", style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
  
  Widget _buildMainUI() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          if (_image == null)
            const Center(child: Text("Select an image to analyze", style: TextStyle(fontSize: 18)))
          else
            _buildImageAndResults(), // The main display widget
          const SizedBox(height: 100), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildImageAndResults() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(_image!),
          ),
        ),
        const SizedBox(height: 20),

        // Show loading indicator OR results OR the analyze button
        _isLoading
            ? const CircularProgressIndicator()
            : _recognitions != null
                ? _buildResultsList()
                : ElevatedButton.icon( // THE NEW "ANALYZE" BUTTON
                    icon: const Icon(Icons.analytics),
                    label: const Text("Analyze Image"),
                    onPressed: () => predictImage(_image!),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
                  ),
      ],
    );
  }

  Widget _buildResultsList() {
    return Column(
      children: _recognitions!.map((res) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      res['label'],
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: LinearPercentIndicator(
                      lineHeight: 20.0,
                      percent: res['confidence'],
                      center: Text(
                        "${(res['confidence'] * 100).toStringAsFixed(0)}%",
                        style: const TextStyle(fontSize: 14.0, color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                      barRadius: const Radius.circular(10),
                      backgroundColor: Colors.grey.shade700,
                      progressColor: Colors.tealAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFloatingActionButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        FloatingActionButton.extended(
          heroTag: 'camera_fab',
          onPressed: () => _pickImage(ImageSource.camera),
          label: const Text("Camera"),
          icon: const Icon(Icons.camera_alt),
        ),
        FloatingActionButton.extended(
          heroTag: 'gallery_fab',
          onPressed: () => _pickImage(ImageSource.gallery),
          label: const Text("Gallery"),
          icon: const Icon(Icons.photo_library),
        ),
      ],
    );
  }
}