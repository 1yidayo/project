import 'package:flutter/material.dart';

void main() {  //Dart程式的進入點
  runApp(const MyApp()); //用以啟動整個app
}
//以上為整個專案的開頭制式化格式,以下都只是範例寫法而已不一定要全用他們的變數名稱
//以下為app的主體程式碼
class MyApp extends StatelessWidget { //class用以定義自己的一個widget,statelessWidget代表這個widget沒狀態顯示內容不會自己更動
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp( //MateerialApp為整個app的外框(主題,首頁,設定...)
      title: 'Luminew',
      theme: ThemeData( //設定整體顏色風格
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 22, 16, 216)),
      ),
      home: const MyHomePage(title: 'Luminew'), //這裡的home控制的示app啟動後第一個要顯示的畫面,我們可以用我們自己的logo感覺不錯
    );
  }
}
//以下為主頁的Widget
class MyHomePage extends StatefulWidget { //StatefulWidget代表這個Widget可以在執行時改變
  const MyHomePage({super.key, required this.title}); //title為從外部傳來的文字參數

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState(); //createState為建立一個對應的狀態物件(有點抽象有點不懂要再理解)
}
//以下為狀態邏輯(有點不懂狀態邏輯要在多查)
class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0; //counter跟python一樣為計數值

  void _incrementCounter() { //incrementCounter是提示系統按鈕被按下後所要執行的函式
    setState(() { //非常重要!!!!!告訴系統資料變了畫面要重新畫了
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }
//以下為整個畫面的構成
  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold( //畫面骨架
      appBar: AppBar( //appbar為上方標題列,這裡的appbar是透過title外來值傳入(在上面)
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center( //內容置中,跟html一樣
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column( //垂直排列多個Widget,之前html好像也有類似語法
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('hello I am Luminew app nice to meet you!!!:'),
            Text( //Text就是單純顯示文字的語法
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton( //按鈕名稱而已可以自己再更改
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
