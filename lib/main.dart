import 'dart:io';
import 'package:imageview360/imageview360.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';

void main() {
  final String outputPath = '/storage/emulated/0/Download/FrameExtracted/';
  runApp(FrameExtractionApp(outputPath: outputPath));
}

class FrameExtractionApp extends StatelessWidget {
  final String outputPath;

  FrameExtractionApp({required this.outputPath});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Frame Extraction App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: FrameExtractionPage(outputPath: outputPath),
    );
  }
}

class FrameExtractionPage extends StatefulWidget {
  final String outputPath;

  FrameExtractionPage({required this.outputPath});

  @override
  _FrameExtractionPageState createState() => _FrameExtractionPageState();
}

class _FrameExtractionPageState extends State<FrameExtractionPage> {
  File? _selectedVideo;
  String? _directoryName;
  bool _isExtractingFrames = false;
  List<String> _directories = [];

  Future<void> _chooseFromGallery() async {
    final pickedFile = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedVideo = File(pickedFile.path);
      });
    }
  }

  Future<void> _recordVideo() async {
    final pickedFile = await ImagePicker().pickVideo(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _selectedVideo = File(pickedFile.path);
      });
    }
  }

  Future<void> _showVideoSourceDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Video Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _chooseFromGallery();
              },
              child: Text('Choose from Gallery'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _recordVideo();
              },
              child: Text('Record Video'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDirectoryNameDialog() async {
    final textEditingController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter Directory Name'),
        content: TextField(
          controller: textEditingController,
          decoration: InputDecoration(hintText: 'Directory Name'),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() {
                _directoryName = textEditingController.text;
              });
              Navigator.pop(context);
              _extractFrames();
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool> _checkDirectoryExists(String directoryPath) async {
    final directory = Directory(directoryPath);
    return directory.exists();
  }

  Future<void> _extractFrames() async {
    if (_selectedVideo == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('No Video Selected'),
          content: Text('Please select a video file first.'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (_directoryName == null || _directoryName!.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('No Directory Name'),
          content: Text('Please enter a directory name first.'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      _isExtractingFrames = true;
    });

    final outputPath = '${widget.outputPath}/$_directoryName/';

    final directoryExists = await _checkDirectoryExists(outputPath);
    if (directoryExists) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Directory Already Exists'),
          content: Text('A directory with the same name already exists. Do you want to overwrite it?'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteExistingDirectoryAndExtractFrames(outputPath);
              },
              child: Text('Overwrite'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showDirectoryNameDialog();
              },
              child: Text('Rename'),
            ),
          ],
        ),
      );
      setState(() {
        _isExtractingFrames = false;
      });
      return;
    }

    final outputDirectory = Directory(outputPath);
    await outputDirectory.create(recursive: true);

    final session = await FFmpegKit.execute('-i ${_selectedVideo!.path} -vf "fps=4" ${outputPath}%1d.png');
    final returnCode = await session.getReturnCode();

    setState(() {
      _isExtractingFrames = false;
    });

    if (ReturnCode.isSuccess(returnCode)) {
      setState(() {
        _isExtractingFrames = false;
      });

      await _updateDirectoriesList();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Extraction Complete'),
          content: Text('Frames extracted successfully.'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DirectorySelectionPage(directories: _directories),
                  ),
                );
              },
              child: Text('Proceed'),
            ),
          ],
        ),
      );
    } else if (ReturnCode.isCancel(returnCode)) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Extraction Cancelled'),
          content: Text('The frame extraction process was cancelled.'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Extraction Failed'),
          content: Text('An error occurred during frame extraction.'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _deleteExistingDirectoryAndExtractFrames(String directoryPath) async {
    final Directory directory = Directory(directoryPath);

    if (directory.existsSync()) {
      setState(() {
        _isExtractingFrames = true;
      });

      await directory.delete(recursive: true);

      setState(() {
        _isExtractingFrames = false;
      });

      setState(() {
        _isExtractingFrames = true;
      });

      await _extractFrames();

      setState(() {
        _isExtractingFrames = false;
      });
    }
  }


  Future<void> _updateDirectoriesList() async {
    final directory = Directory(widget.outputPath);
    final directories = directory.listSync().whereType<Directory>().map((dir) => dir.path).toList();

    setState(() {
      _directories = directories;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Frame Extraction App')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _showVideoSourceDialog,
              child: Text('Select Video'),
            ),
            SizedBox(height: 16),
            Text(_selectedVideo != null ? 'Selected Video: ${_selectedVideo!.path}' : 'No Video Selected'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _showDirectoryNameDialog,
              child: Text('Extract Frames'),
            ),
            SizedBox(height: 16),
            Text(_directoryName != null ? 'Directory Name: $_directoryName' : 'No Directory Name'),
            SizedBox(height: 32),
            if (_isExtractingFrames)
              CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class DirectorySelectionPage extends StatelessWidget {
  final List<String> directories;

  DirectorySelectionPage({required this.directories});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Select Directory')),
      body: ListView.builder(
        itemCount: directories.length,
        itemBuilder: (context, index) {
          final directoryPath = directories[index];
          final directory = Directory(directoryPath);
          final files = directory.listSync();
          final imageFiles = files.where((file) => file is File && file.path.toLowerCase().endsWith('.png')).toList();
          final directoryName = directoryPath.split('/').last;

          if (imageFiles.isEmpty) {
            return SizedBox.shrink(); // Skip rendering if the directory has no image files
          }

          final imageFile = imageFiles.first as File?;

          return GestureDetector(
            onTap: () {
              if (imageFile != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Image360ViewPage(directoryPath: directoryPath),
                  ),
                );
              } else {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('No Image Found'),
                    content: Text('No image found in this directory.'),
                    actions: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            },
            child: Column(
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  margin: EdgeInsets.all(16),
                  color: Colors.blue,
                  child: imageFile != null
                      ? Image.file(
                    imageFile,
                    fit: BoxFit.cover,
                  )
                      : Center(
                    child: Text(
                      'No Image',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                ),
                Text(
                  directoryName,
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class Image360ViewPage extends StatefulWidget {
  final String directoryPath;

  Image360ViewPage({required this.directoryPath});

  @override
  _Image360ViewPageState createState() => _Image360ViewPageState();
}

class _Image360ViewPageState extends State<Image360ViewPage> {
  List<ImageProvider> imageList = [];
  bool imagePrecached = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addPostFrameCallback((_) => updateImageList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Image360View')),
      body: Stack(
        children: [
          (imagePrecached == true)
              ? ImageView360(
                  key: UniqueKey(),
                  imageList: imageList,
                )
              : Center(child: CircularProgressIndicator()),
          Container(
            margin: EdgeInsets.only(left: 20, top: 10),
            child: Text(
              "Car",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

void updateImageList() async {
  String directoryPath = widget.directoryPath;

  final framesDirectory = Directory(directoryPath);
  final files = framesDirectory.listSync();

  for (var file in files) {
    if (file is File) {
      String imagePath = file.path;
      if (imagePath.toLowerCase().endsWith('.png')) {
        print('Image exists: $imagePath');
        imageList.add(FileImage(file));
        await precacheImage(FileImage(file), context);
      }
    }
  }

  setState(() {
    imagePrecached = true;
  });
}

}
