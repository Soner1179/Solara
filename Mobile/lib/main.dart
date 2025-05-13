import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Provider paketi için import
import 'package:solara/services/api_service.dart'; // ApiService importu
import 'package:solara/services/theme_service.dart'; // ThemeService importu

// LoginPage'in bulunduğu doğru yolu import ettiğinizden emin olun.
// Örneğin: import 'package:solara/features/auth/presentation/pages/login_page.dart';
// veya projenizin yapısına göre: import 'package:solara/pages/login_page.dart';
import 'package:solara/pages/login_page.dart'; // Bu yolu kendi projenize göre güncelleyin
import 'package:solara/pages/home_page.dart'; // HomePage importu <--- EKLENDİ

// Uygulamanın ana giriş noktası. Flutter uygulamaları buradan başlar.
import 'package:solara/services/user_state.dart'; // UserState importu

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter binding is initialized

  final userState = UserState();
  await userState.loadCurrentUser(); // Load user data before running the app

  // MyApp widget'ını çalıştırarak uygulamayı başlatır.
  runApp(
    MultiProvider(
      providers: [
        // ChangeNotifierProvider ile ThemeService'ı tüm widget ağacına sağlarız.
        ChangeNotifierProvider(create: (context) => ThemeService()), // ThemeService örneğini oluştur
        // UserState'i de sağlayalım
        ChangeNotifierProvider.value(value: userState), // Provide the pre-loaded UserState
        // ApiService'i de sağlayalım
        Provider<ApiService>(create: (_) => ApiService()),
      ],
      child: const MyApp(), // MyApp widget'ını sarmala
    ),
  );
}

// MyApp: Uygulamanın kök widget'ıdır. Genellikle Stateful olur çünkü
// uygulamanın genel teması veya başlangıç ayarları gibi durumları değişebilir.
class MyApp extends StatelessWidget {
  // Kurucu metot (constructor). `key` parametresi widget ağacındaki
  // widget'ları tanımlamak ve yönetmek için kullanılır.
  const MyApp({super.key});

  @override
  // build metodu, bu widget'ın kullanıcı arayüzünü (UI) oluşturur.
  // Her build metodu bir Widget döndürmelidir.
  Widget build(BuildContext context) {
    // ThemeService'ı dinleyerek tema değişikliklerine tepki ver.
    final themeService = Provider.of<ThemeService>(context);

    // Önce renk şemasını tanımlayalım, böylece tema içinde tekrar kullanabiliriz.
    // Bu, kod tekrarını azaltır ve tutarlılığı artırır.
    // Açık ve koyu temalar için ayrı ColorScheme tanımlayabiliriz.
    final ColorScheme lightColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF244BE0), // Ana tema renginiz
      brightness: Brightness.light,
    );

     final ColorScheme darkColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF244BE0), // Ana tema renginiz (koyu tema için farklı olabilir)
      brightness: Brightness.dark,
      // Koyu tema için ek özelleştirmeler
      // primary: const Color(0xFF...),
      // onPrimary: const Color(0xFF...),
      // surface: const Color(0xFF121212), // Koyu tema arkaplanı
      // onSurface: const Color(0xFFE0E0E0), // Koyu tema metin rengi
    );


    // MaterialApp: Uygulamanın temelini oluşturan, Material Design prensiplerini
    // uygulayan ana widget'tır. Navigasyon, tema vb. temel işlevleri sağlar.
    return MaterialApp(
      // title: İşletim sistemi arayüzlerinde (örn: görev yöneticisi) görünen uygulama adı.
      title: 'Solara',
      // debugShowCheckedModeBanner: Geliştirme sırasında sağ üstte çıkan "DEBUG" etiketini kaldırır.
      // Genellikle yayın (release) sürümlerinde false yapılır.
      debugShowCheckedModeBanner: false,

      // themeMode: Uygulamanın hangi tema modunda olduğunu belirler (light, dark, system).
      // ThemeService'dan gelen değeri kullanıyoruz.
      themeMode: themeService.themeMode,

      // theme: Açık tema ayarları.
      theme: ThemeData(
        colorScheme: lightColorScheme,
        // inputDecorationTheme, elevatedButtonTheme vb. açık tema için burada tanımlanır.
        // Mevcut inputDecorationTheme, elevatedButtonTheme, outlinedButtonTheme, textButtonTheme, appBarTheme ayarları buraya taşınabilir veya ayrı ayrı tanımlanabilir.
        inputDecorationTheme: InputDecorationTheme(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: lightColorScheme.primary),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: lightColorScheme.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: lightColorScheme.error, width: 1.5),
          ),
        ),
         elevatedButtonTheme: ElevatedButtonThemeData(
           style: ElevatedButton.styleFrom(
             shape: RoundedRectangleBorder(
               borderRadius: BorderRadius.circular(8),
             ),
             padding: const EdgeInsets.symmetric(vertical: 14),
             textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
             backgroundColor: lightColorScheme.primary,
             foregroundColor: lightColorScheme.onPrimary,
           ),
         ),
         outlinedButtonTheme: OutlinedButtonThemeData(
           style: OutlinedButton.styleFrom(
             shape: RoundedRectangleBorder(
               borderRadius: BorderRadius.circular(8),
             ),
             side: BorderSide(color: lightColorScheme.primary),
             padding: const EdgeInsets.symmetric(vertical: 14),
             textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
             foregroundColor: lightColorScheme.primary,
           ),
         ),
         textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            foregroundColor: lightColorScheme.primary,
          )
         ),
         appBarTheme: AppBarTheme(
            elevation: 0.5,
            backgroundColor: lightColorScheme.surface,
            foregroundColor: lightColorScheme.onSurface,
            titleTextStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: lightColorScheme.onSurface,
            ),
            iconTheme: IconThemeData(
              color: lightColorScheme.onSurface,
              size: 24,
            ),
          ),


        useMaterial3: true,
      ),

      // darkTheme: Koyu tema ayarları.
      darkTheme: ThemeData(
        colorScheme: darkColorScheme,
         // inputDecorationTheme, elevatedButtonTheme vb. koyu tema için burada tanımlanır.
         // Açık temadan farklı olmasını istediğiniz ayarları buraya ekleyin.
         // Örneğin, koyu tema için TextField kenarlık renkleri veya buton renkleri farklı olabilir.
         inputDecorationTheme: InputDecorationTheme(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade700), // Koyu tema için daha koyu gri
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade700),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: darkColorScheme.primary),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: darkColorScheme.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: darkColorScheme.error, width: 1.5),
          ),
           hintStyle: TextStyle(color: Colors.grey.shade500), // Koyu tema için hint text rengi
        ),
         elevatedButtonTheme: ElevatedButtonThemeData(
           style: ElevatedButton.styleFrom(
             shape: RoundedRectangleBorder(
               borderRadius: BorderRadius.circular(8),
             ),
             padding: const EdgeInsets.symmetric(vertical: 14),
             textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
             backgroundColor: darkColorScheme.primary, // Koyu tema ana rengi
             foregroundColor: darkColorScheme.onPrimary, // Koyu tema üzerinde okunabilir renk
           ),
         ),
         outlinedButtonTheme: OutlinedButtonThemeData(
           style: OutlinedButton.styleFrom(
             shape: RoundedRectangleBorder(
               borderRadius: BorderRadius.circular(8),
             ),
             side: BorderSide(color: darkColorScheme.primary), // Koyu tema ana rengiyle kenarlık
             padding: const EdgeInsets.symmetric(vertical: 14),
             textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
             foregroundColor: darkColorScheme.primary,
           ),
         ),
         textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            foregroundColor: darkColorScheme.primary,
          )
         ),
         appBarTheme: AppBarTheme(
            elevation: 0.5,
            backgroundColor: darkColorScheme.surface, // Koyu tema arkaplanı
            foregroundColor: darkColorScheme.onSurface, // Koyu tema metin rengi
            titleTextStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkColorScheme.onSurface,
            ),
            iconTheme: IconThemeData(
              color: darkColorScheme.onSurface,
              size: 24,
            ),
          ),

        useMaterial3: true,
      ),


      home: const LoginPage(),
      routes: {
        '/login': (context) => const LoginPage(), // Define the /login route
        '/home': (context) => const HomePage(), // Define the /home route
        // You can define other routes here as needed
        // '/profile': (context) => const ProfilePage(), // Example for profile page if navigating by route
      },


    );
  }
}


class AppRoutes {
  static const String login = '/login'; // Giriş sayfası rotası
  static const String register = '/register'; // Kayıt sayfası rotası
  static const String home = '/home'; // Ana sayfa rotası
  static const String profile = '/profile'; // Profil sayfası rotası (örnek)
  // ... uygulamanızdaki diğer sayfalar için rotaları buraya ekleyebilirsiniz ...
}
