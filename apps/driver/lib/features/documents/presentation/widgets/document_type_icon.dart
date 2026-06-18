import 'package:flutter/material.dart';
import 'package:milow_core/milow_core.dart';
import 'package:milow/core/constants/design_tokens.dart';

class DocumentTypeIcon extends StatelessWidget {
  final TripDocumentType type;
  final double size;

  const DocumentTypeIcon({
    required this.type, super.key,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DesignTokens>()!;
    
    IconData icon;
    Color color;

    switch (type) {
      case TripDocumentType.billOfLading:
        icon = Icons.receipt_long;
        color = Theme.of(context).colorScheme.primary;
        break;
      case TripDocumentType.proofOfDelivery:
      case TripDocumentType.proofOfPickup:
        icon = Icons.verified;
        color = tokens.success;
        break;
      case TripDocumentType.rateConfirmation:
      case TripDocumentType.quoteSheet:
        icon = Icons.request_quote;
        color = tokens.warning;
        break;
      case TripDocumentType.fuelReceipt:
        icon = Icons.local_gas_station;
        color = tokens.info;
        break;
      case TripDocumentType.bill:
      case TripDocumentType.invoice:
      case TripDocumentType.payStub:
        icon = Icons.payments;
        color = tokens.info;
        break;
      case TripDocumentType.complianceWSIP:
      case TripDocumentType.complianceDriver:
      case TripDocumentType.complianceAuto:
      case TripDocumentType.complianceCargo:
        icon = Icons.shield_outlined;
        color = tokens.error; 
        break;
      case TripDocumentType.scaleTicket:
        icon = Icons.monitor_weight;
        color = tokens.textSecondary;
        break;
      default:
        icon = Icons.description_outlined;
        color = Theme.of(context).colorScheme.primary;
    }

    return Container(
      width: size * 2,
      height: size * 2,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(tokens.shapeS),
      ),
      child: Icon(
        icon,
        color: color,
        size: size,
      ),
    );
  }
}
