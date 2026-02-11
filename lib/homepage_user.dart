import 'package:flutter/material.dart';

class HomepageUser extends StatefulWidget {
  const HomepageUser({super.key});

  @override
  State<HomepageUser> createState() => _HomepageUserState();
}

class _HomepageUserState extends State<HomepageUser> {
  @override

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("User Homepage",style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,color: Colors.black),),
      ),
      body: const Center(
        child: Text("Welcome to the User Homepage!",style: TextStyle(fontSize: 18, color: Colors.lightBlueAccent),),
      ),
    );
  }
}