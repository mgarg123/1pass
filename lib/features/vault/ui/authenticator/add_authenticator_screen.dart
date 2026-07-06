import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'save_authenticator_screen.dart';

class AddAuthenticatorScreen extends StatefulWidget {
  const AddAuthenticatorScreen({super.key});

  @override
  State<AddAuthenticatorScreen> createState() => _AddAuthenticatorScreenState();
}

class _AddAuthenticatorScreenState extends State<AddAuthenticatorScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isScanning = true;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null && barcode.rawValue!.startsWith('otpauth://')) {
        _isScanning = false;
        _scannerController.stop();
        _navigateToSave(barcode.rawValue!);
        break;
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      final BarcodeCapture? capture = await _scannerController.analyzeImage(image.path);
      if (capture != null && capture.barcodes.isNotEmpty) {
        for (final barcode in capture.barcodes) {
          if (barcode.rawValue != null && barcode.rawValue!.startsWith('otpauth://')) {
            _isScanning = false;
            _scannerController.stop();
            _navigateToSave(barcode.rawValue!);
            return;
          }
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid TOTP QR code found in the image.')),
        );
      }
    }
  }

  void _enterManually() {
    _isScanning = false;
    _scannerController.stop();
    _navigateToSave(null);
  }

  void _navigateToSave(String? secret) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SaveAuthenticatorScreen(initialSecret: secret),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),
          // Scanner overlay frame
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.primary, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          // Bottom controls
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Upload from Gallery'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _enterManually,
                  child: const Text('Enter Key Manually', style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
