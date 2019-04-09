import 'package:camera/camera.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:translator/translator.dart';

import 'utils.dart';

void main() => runApp(MaterialApp(home: _MyHomePage()));
enum Detector { label, cloudLabel }

class _MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<_MyHomePage> {
  dynamic _scanResults;
  CameraController _camera;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String text = "";
  String text2 = "";
  String text3 = "";
  String acc1 = "";
  GoogleTranslator translator = GoogleTranslator();

  Detector _currentDetector = Detector.label;
  bool _isDetecting = false;
  CameraLensDirection _direction = CameraLensDirection.back;
  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  void _initializeCamera() async {
    CameraDescription description = await getCamera(_direction);
    ImageRotation rotation = rotationIntToImageRotation(
      description.sensorOrientation,
    );

    _camera = CameraController(
      description,
      defaultTargetPlatform == TargetPlatform.iOS
          ? ResolutionPreset.low
          : ResolutionPreset.medium,
    );
    await _camera.initialize();

    _camera.startImageStream((CameraImage image) {
      if (_isDetecting) return;

      _isDetecting = true;

      detect(image, _getDetectionMethod(), rotation).then(
        (dynamic result) {
          setState(() {
            _scanResults = result;
          });

          _isDetecting = false;
        },
      ).catchError(
        (_) {
          _isDetecting = false;
        },
      );
    });
  }

  HandleDetection _getDetectionMethod() {
    final FirebaseVision mlVision = FirebaseVision.instance;

    switch (_currentDetector) {
      case Detector.label:
        return mlVision.labelDetector().detectInImage;

      default:
        assert(_currentDetector == Detector.cloudLabel);
        return mlVision.cloudLabelDetector().detectInImage;
    }
  }

  Widget _buildResults() {
    const Text noResultsText = const Text('No results!');
    GoogleTranslator translator = new GoogleTranslator();
    if (_scanResults == null ||
        _camera == null ||
        !_camera.value.isInitialized) {
      return noResultsText;
    }

    CustomPainter painter;

    final Size imageSize = Size(
      _camera.value.previewSize.height,
      _camera.value.previewSize.width,
    );

    switch (_currentDetector) {
      case Detector.label:
        if (_scanResults is! List<Label>) return noResultsText;
        // painter = LabelDetectorPainter(imageSize, _scanResults);
        detectLabels().then((_) {});
        break;
      default:
        assert(_currentDetector == Detector.cloudLabel);
        if (_scanResults is! VisionText) return noResultsText;
      //   painter = TextDetectorPainter(imageSize, _scanResults);
    }
    return CustomPaint(
      painter: painter,
    );
  }

  Future<void> detectLabels() async {
    text = _scanResults[0].label;
    if (_scanResults[1].label != null || !_scanResults[1].label.equals(""))
      text2 = _scanResults[1].label;
    if (_scanResults[2].label != null || !_scanResults[2].label.equals(""))
      text3 = _scanResults[2].label;
  }

  Widget _buildImage() {
    return Container(
      constraints: const BoxConstraints.expand(),
      child: _camera == null
          ? const Center(
              child: CircularProgressIndicator(
                backgroundColor: Colors.lightBlue,
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: <Widget>[
                CameraPreview(_camera),
                _buildResults(),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Reconhecimento de Imagens'),
        actions: <Widget>[
          PopupMenuButton<Detector>(
            onSelected: (Detector result) {
              _currentDetector = result;
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<Detector>>[
                  const PopupMenuItem<Detector>(
                    child: Text('Detect Label'),
                    value: Detector.label,
                  ),
                  const PopupMenuItem<Detector>(
                    child: Text('Detect Cloud Label'),
                    value: Detector.cloudLabel,
                  ),
                ],
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Container(
              child: Padding(
                padding: const EdgeInsets.all(1.0),
                child: Center(
                  child: _buildImage(),
                ),
              ),
            ),
          ),
          Text(
            text + '\n' + text2 + '\n' + text3,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}
