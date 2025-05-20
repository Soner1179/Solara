import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import provider
import 'package:solara/services/theme_service.dart'; // Import ThemeService

class ContestResultsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>( // Wrap with Consumer
      builder: (context, themeService, child) {
        final isLightMode = themeService.themeMode == ThemeMode.light;
        final bgColor = isLightMode ? Colors.white : Colors.black;
        final appBarColor = isLightMode ? Colors.blue : Colors.grey[900];
        final appBarTextColor = isLightMode ? Colors.white : Colors.white;
        final appBarIconColor = isLightMode ? Colors.white : Colors.white;
        final primaryTextColor = isLightMode ? Colors.black87 : Colors.white;
        final secondaryTextColor = isLightMode ? Colors.grey[700] : Colors.grey[300];
        final tertiaryTextColor = isLightMode ? Colors.grey[600] : Colors.grey[400];
        final winnerCardColor = isLightMode ? Colors.grey[200] : Colors.grey[700];
        final winnerCardTextColorPrimary = isLightMode ? Colors.black87 : Colors.white;
        final winnerCardTextColorSecondary = isLightMode ? Colors.grey[700] : Colors.grey[400];
        final buttonBgColor = isLightMode ? Colors.blue : Colors.grey[300];
        final buttonTextColor = isLightMode ? Colors.white : Colors.black87;


        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: Text('Yarışma Sonuçları', style: TextStyle(color: appBarTextColor)),
            backgroundColor: appBarColor,
            iconTheme: IconThemeData(color: appBarIconColor),
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Haftalık Yarışma Kazananları',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryTextColor),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 25),
                  _buildWinnerCard('1', 'ZeynepDemir', 'Şehrin ışıkları ve gökyüzünün yıldızları...', '1000 Solara', winnerCardColor!, Colors.amber.shade600, isLightMode),
                  SizedBox(height: 15),
                  _buildWinnerCard('2', 'MehmetKaya', 'Modern mimari ve yeşil alanların uyumu.', '750 Solara', winnerCardColor!, Colors.blueGrey.shade300, isLightMode),
                  SizedBox(height: 15),
                  _buildWinnerCard('3', 'AyşeYılmaz', 'Şehir merkezinde gizli kalmış doğal bir cennet.', '500 Solara', winnerCardColor!, Colors.brown.shade300, isLightMode),
                  SizedBox(height: 30),
                  Text(
                    'Diğer Katılımcılar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: secondaryTextColor),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Tüm katılımcılar 100 Solara puanı kazandı.',
                    style: TextStyle(fontSize: 15, color: tertiaryTextColor),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Toplam 24 katılımcı bu haftaki yarışmaya katıldı.',
                    style: TextStyle(fontSize: 15, color: tertiaryTextColor),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 30),
                  ElevatedButton(
                     style: ElevatedButton.styleFrom(
                      backgroundColor: buttonBgColor,
                      foregroundColor: buttonTextColor,
                      padding: EdgeInsets.symmetric(vertical: 15),
                       shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      // TODO: Implement yeni yarışmaya katıl action
                    },
                    child: Text('Yeni Yarışmaya Katıl', style: TextStyle(fontSize: 16)),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWinnerCard(String rank, String userName, String description, String solaraPoints, Color cardColor, Color accentColor, bool isLightMode) {
    final winnerCardTextColorPrimary = isLightMode ? Colors.black87 : Colors.white;
    final winnerCardTextColorSecondary = isLightMode ? Colors.grey[700] : Colors.grey[400];

    return Card(
      color: cardColor,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              backgroundColor: accentColor,
              child: Text(rank, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              radius: 20,
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    userName,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: winnerCardTextColorPrimary),
                  ),
                  SizedBox(height: 4),
                  Text(description, style: TextStyle(color: winnerCardTextColorSecondary)),
                  SizedBox(height: 8),
                  Text(
                    solaraPoints,
                    style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
            ),
            SizedBox(width: 15),
            Icon(Icons.emoji_events, size: 30, color: accentColor),
          ],
        ),
      ),
    );
  }
}
