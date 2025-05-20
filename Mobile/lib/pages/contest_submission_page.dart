import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import provider
import 'package:solara/services/theme_service.dart'; // Import ThemeService

class ContestSubmissionPage extends StatelessWidget {
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
        final containerColor = isLightMode ? Colors.grey[200] : Colors.grey[800];
        final containerBorderColor = isLightMode ? Colors.grey[400] : Colors.grey[700];
        final containerIconColor = isLightMode ? Colors.grey[700] : Colors.grey[400];
        final containerTextColor = isLightMode ? Colors.grey[700] : Colors.grey[400];
        final textFieldTextColor = isLightMode ? Colors.black87 : Colors.white;
        final textFieldLabelColor = isLightMode ? Colors.grey[700] : Colors.grey[400];
        final textFieldBorderColor = isLightMode ? Colors.grey[400] : Colors.grey[700];
        final textFieldFocusedBorderColor = isLightMode ? Colors.blue : Colors.grey[500];
        final textFieldCursorColor = isLightMode ? Colors.grey[700] : Colors.grey[400];
        final buttonBgColorCancel = isLightMode ? Colors.grey[400] : Colors.grey[700];
        final buttonTextColorCancel = isLightMode ? Colors.black87 : Colors.white;
        final buttonBgColorShare = isLightMode ? Colors.blue : Colors.grey[300];
        final buttonTextColorShare = isLightMode ? Colors.white : Colors.black87;


        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: Text('Yarışmaya Katıl', style: TextStyle(color: appBarTextColor)),
            backgroundColor: appBarColor,
            iconTheme: IconThemeData(color: appBarIconColor),
          ),
          body: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Fotoğraf veya Video Yükle',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryTextColor),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 30),
                // TODO: Implement image/video upload functionality
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: containerBorderColor!, width: 2),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload_outlined, size: 50, color: containerIconColor),
                        SizedBox(height: 10),
                        Text(
                          'Yükleme Alanı',
                          style: TextStyle(fontSize: 18, color: containerTextColor),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 30),
                TextFormField(
                  style: TextStyle(color: textFieldTextColor),
                  decoration: InputDecoration(
                    labelText: 'Kısa Açıklama',
                    labelStyle: TextStyle(color: textFieldLabelColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: textFieldBorderColor!),
                    ),
                    focusedBorder: OutlineInputBorder(
                       borderRadius: BorderRadius.circular(12),
                       borderSide: BorderSide(color: textFieldFocusedBorderColor!, width: 2),
                    ),
                     enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: textFieldBorderColor!),
                    ),
                  ),
                  maxLength: 100,
                  cursorColor: textFieldCursorColor,
                ),
                SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: buttonBgColorCancel,
                            foregroundColor: buttonTextColorCancel,
                            padding: EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context); // Close the modal
                          },
                          child: Text('İptal', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: ElevatedButton(
                           style: ElevatedButton.styleFrom(
                            backgroundColor: buttonBgColorShare,
                            foregroundColor: buttonTextColorShare,
                            padding: EdgeInsets.symmetric(vertical: 15),
                             shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            // TODO: Implement paylaşımı onayla action
                          },
                          child: Text('Paylaş', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
