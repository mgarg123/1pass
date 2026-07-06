import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/utils/clipboard_util.dart';

enum CardNetwork { visa, mastercard, amex, discover, rupay, dinersClub, unknown }

class CreditCardWidget extends StatelessWidget {
  final String? bankName;
  final String cardNumber;
  final String cardholderName;
  final String expiryDate;
  final String cvv;
  final bool obscureCvv;
  final VoidCallback? onCvvToggle;

  const CreditCardWidget({
    super.key,
    this.bankName,
    required this.cardNumber,
    required this.cardholderName,
    required this.expiryDate,
    required this.cvv,
    this.obscureCvv = true,
    this.onCvvToggle,
  });

  CardNetwork _detectNetwork(String number) {
    final clean = number.replaceAll(RegExp(r'\s+'), '');
    if (clean.isEmpty) return CardNetwork.unknown;

    if (clean.startsWith('4')) return CardNetwork.visa;
    if (clean.startsWith('34') || clean.startsWith('37')) return CardNetwork.amex;
    
    // Diners Club
    if (clean.startsWith('36') || clean.startsWith('38') || clean.startsWith('39')) {
      return CardNetwork.dinersClub;
    }
    if (clean.length >= 3) {
      final prefix = int.tryParse(clean.substring(0, 3));
      if (prefix != null && prefix >= 300 && prefix <= 305) {
        return CardNetwork.dinersClub;
      }
    }

    // RuPay
    if (clean.startsWith('60') || clean.startsWith('65') || clean.startsWith('81') || clean.startsWith('82') || clean.startsWith('508')) {
      return CardNetwork.rupay;
    }

    // Discover
    if (clean.startsWith('6')) return CardNetwork.discover;

    // Mastercard (simplified)
    if (clean.startsWith('5') || clean.startsWith('2')) return CardNetwork.mastercard;

    return CardNetwork.unknown;
  }

  Widget _getNetworkLogo(CardNetwork network) {
    IconData iconData;
    Color iconColor = Colors.white;
    switch (network) {
      case CardNetwork.visa:
        return const Text('VISA', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic));
      case CardNetwork.mastercard:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 24, height: 24, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red)),
            Transform.translate(offset: const Offset(-8, 0), child: Container(width: 24, height: 24, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.orange))),
          ],
        );
      case CardNetwork.amex:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          color: Colors.blue[800],
          child: const Text('AMEX', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        );
      case CardNetwork.rupay:
        return const Text('RuPay', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic));
      case CardNetwork.discover:
        return const Text('DISCOVER', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold));
      case CardNetwork.dinersClub:
        return const Text('Diners Club', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500));
      case CardNetwork.unknown:
        iconData = Icons.credit_card;
        return Icon(iconData, color: iconColor, size: 32);
    }
  }

  List<Color> _getNetworkColors(CardNetwork network) {
    switch (network) {
      case CardNetwork.visa:
        return [Colors.blue.shade800, Colors.blue.shade900];
      case CardNetwork.mastercard:
        return [Colors.blueGrey.shade900, Colors.black87];
      case CardNetwork.amex:
        return [Colors.cyan.shade700, Colors.blue.shade800];
      case CardNetwork.discover:
        return [Colors.orange.shade600, Colors.deepOrange.shade800];
      case CardNetwork.rupay:
        return [Colors.green.shade700, Colors.teal.shade900];
      case CardNetwork.dinersClub:
        return [Colors.grey.shade800, Colors.black87];
      case CardNetwork.unknown:
      default:
        return [Colors.grey.shade800, Colors.grey.shade900];
    }
  }

  String _formatCardNumber(String number) {
    final clean = number.replaceAll(RegExp(r'\s+'), '');
    if (clean.isEmpty) return '•••• •••• •••• ••••';
    
    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(clean[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final network = _detectNetwork(cardNumber);
    final colors = _getNetworkColors(network);

    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (bankName != null && bankName!.isNotEmpty) ...[
                    Text(
                      bankName!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 2)],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Chip placeholder
                  Container(
                    width: 45,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade200, Colors.amber.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.shade700.withOpacity(0.5), width: 0.5),
                    ),
                    child: CustomPaint(
                      painter: _EMVChipPainter(),
                    ),
                  ),
                ],
              ),
              _getNetworkLogo(network),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _formatCardNumber(cardNumber),
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    letterSpacing: 2,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (cardNumber.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () {
                      ClipboardUtil.copyTemporary(cardNumber);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Card number copied to clipboard'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.copy, color: Colors.white70, size: 20),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CARDHOLDER', style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(
                      cardholderName.isEmpty ? 'NAME' : cardholderName.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('EXPIRES', style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(
                      expiryDate.isEmpty ? 'MM/YY' : expiryDate,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('CVV', style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: onCvvToggle,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            cvv.isEmpty ? '•••' : (obscureCvv ? '•••' : cvv),
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            obscureCvv ? Icons.visibility_off : Icons.visibility,
                            color: Colors.white54,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EMVChipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final w = size.width;
    final h = size.height;

    // Center oval/rectangle
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w / 2, h / 2), width: w * 0.45, height: h * 0.6),
        const Radius.circular(4),
      ),
      paint,
    );

    // Horizontal lines
    canvas.drawLine(Offset(0, h * 0.3), Offset(w * 0.275, h * 0.3), paint);
    canvas.drawLine(Offset(w * 0.725, h * 0.3), Offset(w, h * 0.3), paint);
    canvas.drawLine(Offset(0, h * 0.7), Offset(w * 0.275, h * 0.7), paint);
    canvas.drawLine(Offset(w * 0.725, h * 0.7), Offset(w, h * 0.7), paint);

    // Vertical arcs/lines
    canvas.drawLine(Offset(w * 0.275, 0), Offset(w * 0.275, h * 0.2), paint);
    canvas.drawLine(Offset(w * 0.725, 0), Offset(w * 0.725, h * 0.2), paint);
    canvas.drawLine(Offset(w * 0.275, h * 0.8), Offset(w * 0.275, h), paint);
    canvas.drawLine(Offset(w * 0.725, h * 0.8), Offset(w * 0.725, h), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
