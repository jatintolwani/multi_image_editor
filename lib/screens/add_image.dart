import 'dart:io';
import 'package:flutter/material.dart';

import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:path/path.dart' as Path;

class AddImage extends StatefulWidget {
  const AddImage({Key? key}) : super(key: key);

  @override
  _AddImageState createState() => _AddImageState();
}

enum AppState {
  free,
  picked,
  cropped,
}

class _AddImageState extends State<AddImage> {
  late AppState state;
  File? imageFile;
  var cropped = [];
  late CollectionReference imgRef;
  late firebase_storage.Reference ref;
  bool uploading = false;
  double val = 0;

  @override
  void initState() {
    super.initState();
    state = AppState.free;
  }

  var pickedImage;

  Widget _buildButtonIcon() {
    if (state == AppState.free) {
      return const Icon(Icons.add);
    } else if (state == AppState.picked) {
      return const Icon(Icons.crop);
    } else if (state == AppState.cropped) {
      return const Icon(Icons.clear);
    } else {
      return Container();
    }
  }

  var imgs = [];
  Future<void> _pickImage() async {
    pickedImage = await ImagePicker().pickMultiImage();
    for (var i = 0; i < pickedImage!.length; i++) {
      imageFile = File(pickedImage[i].path);
      imgs.add(imageFile);
    }
    if (imageFile != null) {
      setState(() {
        state = AppState.picked;
      });
    }
  }

  _cropImage(img) async {
    File? croppedFile = await ImageCropper.cropImage(
        sourcePath: img.path,
        aspectRatioPresets: Platform.isAndroid
            ? [
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.ratio3x2,
                CropAspectRatioPreset.original,
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.ratio16x9
              ]
            : [
                CropAspectRatioPreset.original,
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.ratio3x2,
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.ratio5x3,
                CropAspectRatioPreset.ratio5x4,
                CropAspectRatioPreset.ratio7x5,
                CropAspectRatioPreset.ratio16x9
              ],
        androidUiSettings: const AndroidUiSettings(
            toolbarTitle: 'Cropper',
            toolbarColor: Colors.blue,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false),
        iosUiSettings: const IOSUiSettings(
          title: 'Cropper',
        ));
    if (croppedFile != null) {
      img = croppedFile;
      setState(() {
        state = AppState.cropped;
      });
    }
    return File(croppedFile!.path);
  }

  void _clearImage() {
    imageFile = null;
    cropped = [];
    imgs = [];

    setState(() {
      state = AppState.free;
    });
  }

  Future uploadFile() async {
    for (var img in cropped) {
      var imagePath = File(img.path);
      ref = firebase_storage.FirebaseStorage.instance
          .ref()
          .child('images/${Path.basename(img.path)}');
      await ref.putFile(imagePath).whenComplete(
        () async {
          await ref.getDownloadURL().then(
            (value) {
              FirebaseFirestore.instance.collection('imagesURL').doc().set(
                {
                  "url": value.toString(),
                },
              );
            },
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(
                () {
                  uploading = true;
                },
              );
              uploadFile().whenComplete(
                () => Navigator.of(context).pop(),
              );
            },
            child: const Text(
              'upload',
              style: TextStyle(color: Colors.white),
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          Container(
            child: GridView.builder(
              itemCount: cropped.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3),
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    image: DecorationImage(
                        image: FileImage(
                          File(cropped[index].path),
                        ),
                        fit: BoxFit.cover),
                  ),
                );
              },
            ),
          ),
          uploading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'uploading...',
                        style: TextStyle(fontSize: 20),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      LinearProgressIndicator(
                        value: val,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.green),
                      )
                    ],
                  ),
                )
              : Container(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepOrange,
        onPressed: () async {
          if (state == AppState.free) {
            _pickImage();
          } else if (state == AppState.picked) {
            for (var i = 0; i < imgs.length; i++) {
              var cImg = await _cropImage(imgs[i]);
              cropped.add(cImg);
            }
          } else if (state == AppState.cropped) {
            _clearImage();
          }
        },
        child: _buildButtonIcon(),
      ),
    );
  }
}
