import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import provider
import 'package:solara/pages/contest_submission_page.dart';
import 'package:solara/pages/contest_results_page.dart';
import 'package:solara/services/theme_service.dart'; // Import ThemeService

class ContestMainPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>( // Wrap with Consumer
      builder: (context, themeService, child) {
        final isLightMode = themeService.themeMode == ThemeMode.light;
        final bgColor = isLightMode ? Colors.white : Colors.black;
        final appBarColor = isLightMode ? Colors.blue : Colors.grey[900];
        final appBarTextColor = isLightMode ? Colors.white : Colors.white;
        final cardColor = isLightMode ? Colors.grey[200] : Colors.grey[800];
        final primaryTextColor = isLightMode ? Colors.black87 : Colors.white;
        final secondaryTextColor = isLightMode ? Colors.grey[700] : Colors.grey[400];
        final tertiaryTextColor = isLightMode ? Colors.grey[600] : Colors.grey[500];
        final timeBoxColor = isLightMode ? Colors.grey[300] : Colors.grey[800];
        final timeBoxTextColor = isLightMode ? Colors.black87 : Colors.grey[300];
        final timeBoxLabelColor = isLightMode ? Colors.grey[700] : Colors.grey[500];
        final buttonBgColorPrimary = isLightMode ? Colors.blue : Colors.grey[300];
        final buttonTextColorPrimary = isLightMode ? Colors.white : Colors.black87;
        final buttonBgColorSecondary = isLightMode ? Colors.grey[400] : Colors.grey[700];
        final buttonTextColorSecondary = isLightMode ? Colors.black87 : Colors.white;
        final postCardColor = isLightMode ? Colors.grey[200] : Colors.grey[800];
        final postCardTextColorPrimary = isLightMode ? Colors.black87 : Colors.grey[300];
        final postCardTextColorSecondary = isLightMode ? Colors.grey[700] : Colors.grey[400];
        final postCardButtonBg = isLightMode ? Colors.grey[400] : Colors.grey[700];
        final postCardButtonText = isLightMode ? Colors.black87 : Colors.white;
        final postCardButtonIcon = isLightMode ? Colors.black87 : Colors.white;
        final postCardTotalVoteColor = isLightMode ? Colors.grey[700] : Colors.grey[400];


        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: Text('Haftalık Yarışma', style: TextStyle(color: appBarTextColor)),
            backgroundColor: appBarColor,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Card(
                  margin: EdgeInsets.only(bottom: 20),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Bu Haftanın Konusu',
                          style: TextStyle(fontSize: 18, color: secondaryTextColor),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Doğa ve Şehir Hayatı',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryTextColor),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  'Yarışma Bitimine Kalan Süre',
                  style: TextStyle(fontSize: 16, color: tertiaryTextColor),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    _buildTimeBox('2', 'GÜN', isLightMode),
                    SizedBox(width: 8),
                    _buildTimeBox('4', 'SAAT', isLightMode),
                    SizedBox(width: 8),
                    _buildTimeBox('48', 'DAKİKA', isLightMode),
                    SizedBox(width: 8),
                    _buildTimeBox('17', 'SANİYE', isLightMode),
                  ],
                ),
                SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonBgColorPrimary,
                    foregroundColor: buttonTextColorPrimary,
                    padding: EdgeInsets.symmetric(vertical: 15),
                     shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ContestSubmissionPage()),
                    );
                  },
                  child: Text('Yarışmaya Katıl', style: TextStyle(fontSize: 16)),
                ),
                SizedBox(height: 15),
                ElevatedButton(
                   style: ElevatedButton.styleFrom(
                    backgroundColor: buttonBgColorSecondary,
                    foregroundColor: buttonTextColorSecondary,
                    padding: EdgeInsets.symmetric(vertical: 15),
                     shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ContestResultsPage()),
                    );
                  },
                  child: Text('Yarışma Sonuçları', style: TextStyle(fontSize: 16)),
                ),
                SizedBox(height: 30),
                Expanded(
                  child: ListView.builder(
                    itemCount: 5, // Dummy data
                    itemBuilder: (context, index) {
                      return _buildPostCard(isLightMode);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeBox(String time, String label, bool isLightMode) {
    final timeBoxColor = isLightMode ? Colors.grey[300] : Colors.grey[800];
    final timeBoxTextColor = isLightMode ? Colors.black87 : Colors.grey[300];
    final timeBoxLabelColor = isLightMode ? Colors.grey[700] : Colors.grey[500];
    final boxShadowColor = isLightMode ? Colors.grey[400] : Colors.black54;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: timeBoxColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: boxShadowColor!,
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            time,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: timeBoxTextColor),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: timeBoxLabelColor),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(bool isLightMode) {
    final postCardColor = isLightMode ? Colors.grey[200] : Colors.grey[800];
    final postCardTextColorPrimary = isLightMode ? Colors.black87 : Colors.grey[300];
    final postCardTextColorSecondary = isLightMode ? Colors.grey[700] : Colors.grey[400];
    final postCardButtonBg = isLightMode ? Colors.grey[400] : Colors.grey[700];
    final postCardButtonText = isLightMode ? Colors.black87 : Colors.white;
    final postCardButtonIcon = isLightMode ? Colors.black87 : Colors.white;
    final postCardTotalVoteColor = isLightMode ? Colors.grey[700] : Colors.grey[400];


    return Card(
      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: postCardColor,
      child: Padding(
        padding: EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                'https://via.placeholder.com/400x200', // Dummy image
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            SizedBox(height: 15),
            Text(
              'Kullanıcı Adı',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: postCardTextColorPrimary),
            ),
            SizedBox(height: 5),
            Text('Kısa açıklama...', style: TextStyle(color: postCardTextColorSecondary)),
            SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: postCardButtonBg,
                    foregroundColor: postCardButtonText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    // TODO: Implement oy verme action
                  },
                  icon: Icon(Icons.thumb_up_alt_outlined, size: 18, color: postCardButtonIcon),
                  label: Text('Oy Ver'),
                ),
                Text('Toplam Oy: 100', style: TextStyle(fontWeight: FontWeight.bold, color: postCardTotalVoteColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
