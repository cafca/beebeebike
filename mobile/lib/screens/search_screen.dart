import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final List<String> _results = <String>[];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search here...',
            border: InputBorder.none,
          ),
          onSubmitted: (value) {
            setState(() {
              _results
                ..clear()
                ..add('Home · Torstraße 12')
                ..add('Tempelhofer Feld');
            });
          },
        ),
      ),
      body: ListView.builder(
        itemCount: _results.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(_results[index]),
            onTap: () => Navigator.of(context).pop(_results[index]),
          );
        },
      ),
    );
  }
}
