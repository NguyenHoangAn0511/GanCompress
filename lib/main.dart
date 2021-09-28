import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import 'package:image/image.dart' as img;
// import 'package:image_cropper/image_cropper.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage(

      ),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  img.Image aimage;
  File _image;
  final imagePicker = ImagePicker();


  List generate4dList(List<double> fList) {
    //this function will return 4D Array made by a flatten array
    // print(fList.shape);
    var list = List.generate(
        1,
            (i) => List.generate(3,
                (j) => List.generate(256, (k) => List.generate(256, (l) => 0.0))));
    int y = 0;
    for (int j = 0; j < 256; j++) {
      for (int k = 0; k < 256; k++) {
        list[0][0][j][k] = fList[y];
        list[0][1][j][k] = fList[y+1];
        list[0][2][j][k] = fList[y+2];
        y+=3;
      }
    }
    return list;
  }

  img.Image createImage(List list, int inputSize) {
    img.Image image = img.Image(inputSize, inputSize);
    img.fill(image, img.getColor(0, 0, 0));
    for (int i = 0; i < inputSize; i++) {
      for (int j = 0; j < inputSize; j++) {
        double redValue = list[0][0][j][i];
        double greenValue = list[0][1][j][i];
        double blueValue = list[0][2][j][i];
        img.drawPixel(
            image,
            i,
            j,
            img.getColor((((redValue+1)/2.0) * 255).round(), (((greenValue+1)/2.0) * 255).round(),
                (((blueValue+1)/2.0) * 255).round()));
      }
    }
    return image;
  }

  Future loadModel (File _image) async{

    ImageProcessor imageProcessor = ImageProcessorBuilder()
        .add(ResizeOp(256, 256, ResizeMethod.NEAREST_NEIGHBOUR))
        .add(new NormalizeOp(0, 255))
        .add(new NormalizeOp(0.5, 0.5))
        .build();
    img.Image imageInput = img.decodeImage(_image.readAsBytesSync());

    TensorImage tensorImage;
    tensorImage = TensorImage(TfLiteType.float32);
    tensorImage.loadImage(imageInput);
    try {
      // Create interpreter from asset.
      tensorImage = imageProcessor.process(tensorImage);

      Interpreter interpreter = await Interpreter.fromAsset("model_float32.tflite");
      var _outputShape = interpreter.getOutputTensor(0).shape;
      var _outputType = interpreter.getOutputTensor(0).type;

      TensorBuffer probabilityBuffer = TensorBuffer.createFixedSize(_outputShape, _outputType);
      interpreter.run(tensorImage.buffer, probabilityBuffer.buffer);
      List<List<List<List<double>>>> lis = generate4dList(probabilityBuffer.getDoubleList());
      img.Image image = createImage(lis, 256);
      aimage = image;
    }
    catch (e) {
      print('Error loading model: ' + e.toString());
    }
  }

  Uint8List loadImage() {
    if (aimage == null) {
      img.Image image = img.Image(256, 256);
      img.fill(image, img.getColor(0, 0, 0));
      img.Image resizeImageContent =
      img.copyResize(image, height: 256, width: 256);

      return img.encodeJpg(resizeImageContent);
    } else {
      return img.encodeJpg(aimage);
    }
  }

  Future getImageCamera() async{
    final image = await imagePicker.pickImage(source: ImageSource.camera, maxWidth: 1800, maxHeight: 1800, imageQuality: 100);
    setState(() {
      _image = File(image.path);
      // _cropImage(image.path);
      loadModel(_image);
    });
  }

  // _cropImage(filePath) async {
  //   File croppedImage = await ImageCropper.cropImage(
  //     sourcePath: filePath,
  //     maxWidth: 1080,
  //     maxHeight: 1080,
  //   );
  //   if (croppedImage != null) {
  //     _image = croppedImage;
  //     setState(() {});
  //   }
  // }

  Future getImageGallery() async {

    final image = await imagePicker.pickImage(source: ImageSource.gallery,
    imageQuality: 100);

    setState(() {
      _image = File(image.path);
      // _cropImage(image.path);
    });
    loadModel(_image);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xff112232),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _image != null ? Image.file(_image, width: 256, height: 256,) : Text("data"),
            ),
            Container(child: aimage != null ? Image.memory(loadImage()) : Text("data"),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20.0, vertical: 30.0),
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.red,
                ),
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Column(
                children: [
                  Text("Add image", style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  ),
                  SizedBox(height: 15.0,),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          RawMaterialButton(
                            onPressed: () {
                              getImageGallery();
                            },
                            fillColor: Colors.red,
                            elevation: 0.0,
                            padding: const EdgeInsets.all(15.0),
                            shape: CircleBorder(),
                            constraints: BoxConstraints(),
                            child: Icon(Icons.image, size: 20),
                          ),
                          SizedBox(
                            height: 5,
                          ),
                          Text('Image', style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold
                          ),)
                        ],
                      )
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

