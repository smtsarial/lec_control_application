import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/container.dart';
import 'package:flutter/src/widgets/framework.dart';

class FilePartTone extends StatefulWidget {
  const FilePartTone({super.key, required this.file, required this.selected});
  final PlatformFile file;
  final bool selected;
  @override
  State<FilePartTone> createState() => _FilePartToneState();
}

class _FilePartToneState extends State<FilePartTone> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(width: 2, color: Colors.white))
          // color: const Color(0xFF343145),
          ),
      child: ListTile(
          title: Text(widget.file.name.substring(0, 20)),
          subtitle: Text(widget.file.name),
          trailing: Text(widget.file.size.toString())),
    );
  }
}
