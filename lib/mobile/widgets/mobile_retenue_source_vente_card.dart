import 'package:flutter/material.dart';
import '../../models/retenue_source_vente.dart';
import 'mobile_generic_card.dart';

class MobileRetenueSourceVenteCard extends StatelessWidget {
  final RetenueSourceVente retenue;
  final VoidCallback onTap;
  final bool isSales;

  const MobileRetenueSourceVenteCard({
    super.key,
    required this.retenue,
    required this.onTap,
    this.isSales = true,
  });

  @override
  Widget build(BuildContext context) {
    return MobileGenericCard(
      reference: retenue.invoiceReference,
      status: retenue.status,
      name: retenue.clientName.isNotEmpty ? retenue.clientName : 'Inconnu',
      nameIcon: isSales ? Icons.person_outline : Icons.business_outlined,
      date: retenue.date,
      amount: retenue.amount,
      onTap: onTap,
    );
  }
}
