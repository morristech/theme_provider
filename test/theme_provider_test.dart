import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theme_provider/src/controller/save_adapter.dart';
import 'package:theme_provider/src/controller/shared_preferneces_adapter.dart';
import 'package:theme_provider/theme_provider.dart';

void main() {
  test('ThemeProvider constructor theme list test', () {
    var buildWidgetTree = (List<AppTheme> appThemes) async => ThemeProvider(
          builder: (_, theme) => Container(),
          themes: appThemes,
        );

    expect(() => buildWidgetTree(null), isNotNull);
    expect(() => buildWidgetTree([AppTheme.light()]), throwsAssertionError);
    expect(buildWidgetTree([AppTheme.light(), AppTheme.light()]), isNotNull);
  });

  testWidgets('ThemeProvider ancestor test', (tester) async {
    final Key scaffoldKey = UniqueKey();

    await tester.pumpWidget(
      ThemeProvider(
        builder: (context, theme) => MaterialApp(
              theme: theme,
              home: Scaffold(key: scaffoldKey),
            ),
      ),
    );

    await tester.pump();
    expect(
        find.ancestor(
          of: find.byKey(scaffoldKey),
          matching: find.byType(ThemeProvider),
        ),
        findsWidgets);
  });

  testWidgets('Basic Theme Change test', (tester) async {
    final Key buttonKey = UniqueKey();

    await tester.pumpWidget(
      ThemeProvider(
        builder: (context, theme) => MaterialApp(
              theme: theme,
              home: Scaffold(
                body: FlatButton(
                  key: buttonKey,
                  child: Text("Press Me"),
                  onPressed: () {
                    ThemeCommand themeCommand =
                        ThemeProvider.controllerOf(context);
                    assert(themeCommand != null);
                    themeCommand.nextTheme();
                  },
                ),
              ),
            ),
      ),
    );

    await tester.pump();

    expect(Theme.of(tester.element(find.byKey(buttonKey))).brightness,
        equals(Brightness.light));

    await tester.tap(find.byKey(buttonKey));
    await tester.pumpAndSettle();

    expect(Theme.of(tester.element(find.byKey(buttonKey))).brightness,
        equals(Brightness.dark));
  });

  testWidgets('Basic Theme Change test', (tester) async {
    final Key scaffoldKey = UniqueKey();

    await tester.pumpWidget(
      ThemeProvider(
        builder: (context, theme) => MaterialApp(
              theme: theme,
              home: Scaffold(key: scaffoldKey),
            ),
        themes: [
          AppTheme<String>.light().copyWith(
            id: "light_theme",
            options: "Hello",
          ),
          AppTheme<String>.dark().copyWith(
            id: "dark_theme",
            options: "Bye",
          )
        ],
      ),
    );

    await tester.pump();

    expect(
        ThemeProvider.optionsOf<String>(
            tester.element(find.byKey(scaffoldKey))),
        isNot("Bye"));
    expect(
        ThemeProvider.optionsOf<String>(
            tester.element(find.byKey(scaffoldKey))),
        equals("Hello"));
  });

  testWidgets('Default Theme Id Test', (tester) async {
    final Key scaffoldKey = UniqueKey();

    await tester.pumpWidget(
      ThemeProvider(
        builder: (context, theme) => MaterialApp(
              theme: theme,
              home: Scaffold(key: scaffoldKey),
            ),
      ),
    );

    await tester.pump();

    expect(ThemeProvider.themeOf(tester.element(find.byKey(scaffoldKey))).id,
        startsWith("default_"));
  });

  testWidgets('Duplicate Theme Id Test', (tester) async {
    final errorHandled = expectAsync0(() {});

    FlutterError.onError = (errorDetails) {
      errorHandled();
    };

    await tester.pumpWidget(
      ThemeProvider(
        builder: (context, theme) => MaterialApp(
              theme: theme,
              home: Scaffold(),
            ),
        themes: [
          AppTheme.light(),
          AppTheme.light(id: "test_theme"),
          AppTheme.light(id: "test_theme"),
        ],
      ),
    );
  });

  testWidgets('Select by Theme Id Test', (tester) async {
    final Key scaffoldKey = UniqueKey();

    var fetchCommand = () =>
        ThemeProvider.controllerOf(tester.element(find.byKey(scaffoldKey)));
    var fetchTheme =
        () => ThemeProvider.themeOf(tester.element(find.byKey(scaffoldKey)));

    await tester.pumpWidget(
      ThemeProvider(
        builder: (context, theme) => MaterialApp(
              theme: theme,
              home: Scaffold(key: scaffoldKey),
            ),
        themes: [
          AppTheme.light(),
          AppTheme.light(id: "test_theme_1"),
          AppTheme.light(id: "test_theme_2"),
          AppTheme.light(id: "test_theme_random"),
        ],
      ),
    );
    expect(fetchTheme().id, equals("default_light_theme"));

    fetchCommand().nextTheme();
    expect(fetchTheme().id, equals("test_theme_1"));

    fetchCommand().setTheme("test_theme_random");
    expect(fetchTheme().id, equals("test_theme_random"));
  });
  testWidgets('Set default theme id test', (tester) async {
    final Key scaffoldKey = UniqueKey();

    var getCurrentThemeId =
        () => ThemeProvider.themeOf(tester.element(find.byKey(scaffoldKey))).id;

    var widgetTreeWithDefaultTheme =
        ({String defaultTheme}) async => await tester.pumpWidget(
              ThemeProvider(
                builder: (context, theme) => MaterialApp(
                      theme: theme,
                      home: Scaffold(key: scaffoldKey),
                    ),
                defaultThemeId: defaultTheme,
                themes: [
                  AppTheme.light(),
                  AppTheme.light(id: "test_theme_1"),
                  AppTheme.light(id: "test_theme_2"),
                  AppTheme.light(id: "test_theme_3"),
                  AppTheme.light(id: "test_theme_4"),
                ],
              ),
            );

    await widgetTreeWithDefaultTheme();
    expect(getCurrentThemeId(), equals("default_light_theme"));

    await widgetTreeWithDefaultTheme(defaultTheme: "test_theme_3");
    expect(getCurrentThemeId(), equals("test_theme_3"));

    final errorHandled = expectAsync0(() {});

    FlutterError.onError = (errorDetails) {
      errorHandled();
    };

    await widgetTreeWithDefaultTheme(defaultTheme: "no_theme");
  });

  testWidgets('Persistency test', (tester) async {
    Map<String, dynamic> testStorage = Map();

    const MethodChannel('plugins.flutter.io/shared_preferences')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getAll') {
        return testStorage;
      } else if (methodCall.method == 'setString') {
        var args = methodCall.arguments;
        String key = args['key'];
        String value = args['value'];
        testStorage[key] = value;
      } else {
        throw AssertionError("Invalid methid call: $methodCall");
      }
    });

    String saveKey = 'theme_provider.theme';

    SaveAdapter theme = SharedPreferenceAdapter();
    expect(testStorage, isNot(contains(saveKey)));
    expect(
        await theme.loadTheme(defaultId: "load_failed"), equals("load_failed"));

    await theme.saveTheme("theme");
    expect(testStorage.keys, contains("flutter.$saveKey"));
    expect(await theme.loadTheme(), equals("theme"));
  });
}
