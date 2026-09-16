import 'package:flutter/material.dart';

/// Palette Meno Bible — dérivée de "Palette de couleur Meno Bible.pdf".
/// Règle de la maquette à respecter dans le code : bleuCiel ne porte jamais
/// de texte directement dessus (contraste insuffisant), utilisé en fond uniquement.
class AppColors {
  AppColors._();

  static const Color rougePrincipal = Color(0xFFA61B2B);   // Logo, boutons principaux, éléments actifs
  static const Color rougeSecondaire = Color(0xFFC83E4D);  // Accents, icônes, interactions
  static const Color bleuCiel = Color(0xFF87CEEB);         // Fond uniquement — jamais de texte dessus
  static const Color bleuCielDoux = Color(0xFFE6F5FA);     // Fonds de cartes, catégories, surbrillance
  static const Color rosePoudre = Color(0xFFF8E5E7);       // Mise en évidence de certaines notes
  static const Color ivoire = Color(0xFFFFF9F5);           // Arrière-plan principal
  static const Color bordeauxProfond = Color(0xFF541A24);  // Titres et textes importants
  static const Color grisDoux = Color(0xFF777477);         // Textes secondaires, métadonnées
}