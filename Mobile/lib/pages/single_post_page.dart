// lib/pages/single_post_page.dart
import 'package:flutter/material.dart';

class SinglePostPage extends StatelessWidget {
  final int postId;

  const SinglePostPage({Key? key, required this.postId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gönderi #$postId'),
      ),
      body: Center(
        child: Text('Gönderi ID: $postId için detaylar burada gösterilecek.'),
      ),
    );
  }
}
