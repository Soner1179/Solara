// lib/pages/widgets/sliver_app_bar_delegate.dart
import 'package:flutter/material.dart'; // Flutter'ın temel Material Design widget'ları.

// NestedScrollView içinde TabBar'ı yapışkan (sticky) yapmak için yardımcı sınıf.
// Bu sınıf, bir başlığın (header) kaydırılırken nasıl davranacağını tanımlar.
class SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  // Kurucu metot: Sabit kalması istenen TabBar widget'ını alır.
  SliverAppBarDelegate(this._tabBar);

  // Sabit kalacak olan TabBar widget'ı.
  final TabBar _tabBar;

  @override
  // Bu başlığın minimum alabileceği yükseklik. TabBar'ın tercih edilen yüksekliği kadar.
  double get minExtent => _tabBar.preferredSize.height;
  @override
  // Bu başlığın maksimum alabileceği yükseklik. TabBar'ın tercih edilen yüksekliği kadar.
  // minExtent ve maxExtent aynı olduğu için başlık sabit boyutta kalır.
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  // Bu başlığın (sabit kalan TabBar'ın) nasıl görüneceğini oluşturan metot.
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Kaydırma sırasında alttaki içeriğin TabBar'ın arkasından görünmesini
    // engellemek için bir Container ile sarmalayıp arka plan rengi veriyoruz.
    return Container(
      // Sayfanın arka plan rengiyle veya istenen başka bir renkle aynı olmalı.
      color: Colors.white,
      // İçerik olarak dışarıdan alınan TabBar widget'ını gösterir.
      child: _tabBar,
    );
  }

  @override
  // Delegate'in yeniden çizilip çizilmeyeceğini kontrol eder.
  // Genellikle TabBar içeriği değişmiyorsa false döndürmek performansı artırır.
  // Eğer TabBar dinamik olarak değişiyorsa burayı true yapıp kontrol eklemek gerekebilir.
  bool shouldRebuild(SliverAppBarDelegate oldDelegate) {
    // Şimdilik basit tutuyoruz, yeniden çizime gerek yok.
    return false;
  }
}