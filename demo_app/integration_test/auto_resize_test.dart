import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fwfh_chewie/fwfh_chewie.dart';
import 'package:fwfh_webview/fwfh_webview.dart';
import 'package:integration_test/integration_test.dart';
import 'package:measurer/measurer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('VideoPlayer', (WidgetTester tester) async {
    final key = GlobalKey<_AspectRatioTestState>();
    final test = _AspectRatioTest(
      key: key,
      tester: tester,
      child: VideoPlayer(
        'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
        aspectRatio: 1,
        loadingBuilder: (_a, _b, _c) =>
            const Center(child: CircularProgressIndicator()),
      ),
    );

    runApp(test);
    await tester.pumpAndSettle();

    key.currentState.expectValueEquals(16 / 9);
  });

  final webViewTestCases = ValueVariant(const {
    WebViewTestCase(0.5, false),
    WebViewTestCase(1.0, false),
    WebViewTestCase(2.0, false),
    WebViewTestCase(1.0, true),
  });

  testWidgets(
    'WebView',
    (WidgetTester tester) async {
      final testCase = webViewTestCases.currentValue;
      final key = await testCase.run(tester);
      key.currentState.expectValueEquals(testCase.input);
    },
    variant: webViewTestCases,
  );
}

class WebViewTestCase {
  final double input;
  final bool issue375;

  // ignore: avoid_positional_boolean_parameters
  const WebViewTestCase(this.input, this.issue375);

  Future<GlobalKey<_AspectRatioTestState>> run(WidgetTester tester) async {
    final html = '''
<!doctype html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
</head>

<body style="background: gray; margin: 0">
  <div id="block" style="background: black; color: white;">&nbsp;</div>
  <script>
    let attempts = 0;
    const block = document.getElementById('block');

    function resize() {
      attempts++;

      const width = window.innerWidth;
      if (width === 0) {
        return setTimeout(resize, 10);
      }

      const height = width / $input;
      block.style.height = height + 'px';
      block.innerHTML = 'input=$input, attempts=' + attempts;

      return setTimeout(resize, 100);
    }

    resize();
  </script>
</body>
''';

    const interval = Duration(seconds: 2);
    final webView = WebView(
      Uri.dataFromString(html, mimeType: 'text/html').toString(),
      aspectRatio: 16 / 9,
      autoResize: true,
      autoResizeIntervals: [interval, interval * 2, interval * 3],
      debuggingEnabled: true,
      unsupportedWorkaroundForIssue375: issue375,
    );

    final key = GlobalKey<_AspectRatioTestState>();

    runApp(
      _AspectRatioTest(
        key: key,
        tester: tester,
        child: webView,
      ),
    );

    for (var i = 0; i < 7; i++) {
      await tester.pump();
      await tester.runAsync(() => Future.delayed(interval));
    }

    return key;
  }

  @override
  String toString() {
    return 'input=$input issue375=$issue375';
  }
}

class _AspectRatioTest extends StatefulWidget {
  static final _value = Expando<double>();

  final Widget child;
  final WidgetTester tester;

  const _AspectRatioTest({
    @required this.child,
    Key key,
    @required this.tester,
  }) : super(key: key);

  @override
  State<_AspectRatioTest> createState() => _AspectRatioTestState();
}

class _AspectRatioTestState extends State<_AspectRatioTest> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Measurer(
            onMeasure: (size, _) {
              debugPrint(
                '${widget.tester.testDescription}.onMeasure: size=$size',
              );
              _AspectRatioTest._value[this] = size.width / size.height;
            },
            child: widget.child,
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    debugPrint('${widget.tester.testDescription}.initState');
  }

  @override
  void dispose() {
    debugPrint('${widget.tester.testDescription}.dispose');
    super.dispose();
  }

  void expectValueEquals(double expected) {
    const fractionDigits = 2;
    final powerOfTen = pow(10, fractionDigits);
    final actual = _AspectRatioTest._value[this] ?? .0;
    debugPrint(
      '${widget.tester.testDescription}: actual=$actual expected=$expected',
    );
    expect(
      (actual * powerOfTen).floorToDouble() / powerOfTen,
      (expected * powerOfTen).floorToDouble() / powerOfTen,
    );
  }
}
