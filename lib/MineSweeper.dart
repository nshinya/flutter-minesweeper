import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';

enum TileState { opened, closed, flagged }

class MineTile {
  bool hasBomb = false;
  int numBombs = 0;
  bool exploded = false;
  TileState state = TileState.closed;
}

enum FieldState { waiting, playing, won, lost }

class MineField {
  List<MineTile> _tiles;
  MineSweeperSettings _setting;
  FieldState _state = FieldState.waiting;
  Stopwatch _stopwatch = Stopwatch();

  FieldState get state {
    return _state;
  }

  int get width {
    return _setting.width;
  }

  int get height {
    return _setting.height;
  }

  int get bombs {
    return _setting.bombs;
  }

  int get playingTime {
    return _stopwatch.elapsedMilliseconds ~/ 1000;
  }

  MineField(this._setting) {
    resetField();
  }

  MineTile tileAt(int row, int col) {
    return _tiles[_getIndex(row, col)];
  }

  int countTiles({TileState state}) {
    if (state != null) {
      return _tiles.where((v) => v.state == state).length;
    } else {
      return _tiles.length;
    }
  }

  int _getIndex(int row, int col) {
    return row * width + col;
  }

  bool _isin(int row, int col) {
    return 0 <= row && row < height && 0 <= col && col < width;
  }

  void resetField() {
    _stopwatch.reset();
    _state = FieldState.waiting;
    _tiles = List.generate(width * height, (_) => MineTile());
  }

  void startGame(int row, int col) {
    if (_state == FieldState.waiting) {
      _placeBombs(row, col);
      _stopwatch.start();
      _state = FieldState.playing;
    }
  }

  void _placeBombs(int row, int col) {
    List<int> bombIndex = _generateUniqueRandomInt(bombs, width * height,
        excludeIndex: _getIndex(row, col));
    bombIndex.forEach((i) => _tiles[i].hasBomb = true);
    for (int i = 0; i < height; i++) {
      for (int j = 0; j < width; j++) {
        int idx = _getIndex(i, j);
        _tiles[idx].numBombs = _calcBombs(i, j);
      }
    }
  }

  int _calcBombs(int row, int col) {
    int count = 0;
    for (int i = row - 1; i <= row + 1; i++) {
      for (int j = col - 1; j <= col + 1; j++) {
        if (_isin(i, j)) {
          int idx = _getIndex(i, j);
          if (_tiles[idx].hasBomb) {
            count++;
          }
        }
      }
    }
    return count;
  }

  List<int> _generateUniqueRandomInt(int length, int maxSize,
      {int excludeIndex}) {
    List<int> list = [];
    Random rnd = Random();
    while (true) {
      int idx = rnd.nextInt(maxSize);
      if (excludeIndex != null && idx == excludeIndex) {
        continue;
      }
      if (!list.contains(idx)) {
        list.add(idx);
      }
      if (list.length == length) {
        break;
      }
    }
    return list;
  }

  void openTile(int row, int col) {
    if (!_isin(row, col)) return;

    if (_state != FieldState.playing) return;

    MineTile tile = _tiles[_getIndex(row, col)];

    if (tile.state == TileState.opened || tile.state == TileState.flagged)
      return;

    tile.state = TileState.opened;

    if (tile.hasBomb) {
      _stopwatch.stop();
      openAllBombs();
      tile.exploded = true;
      _state = FieldState.lost;
    }

    if (countTiles() - countTiles(state: TileState.opened) == bombs) {
      _stopwatch.stop();
      flagAllBombs();
      _state = FieldState.won;
    }

    if (tile.numBombs == 0) {
      // open around tiles
      openTile(row - 1, col - 1);
      openTile(row - 1, col);
      openTile(row - 1, col + 1);
      openTile(row, col - 1);
      openTile(row, col + 1);
      openTile(row + 1, col - 1);
      openTile(row + 1, col);
      openTile(row + 1, col + 1);
    }
  }

  void openAllBombs() {
    _tiles.where((v) => v.hasBomb).forEach((v) => v.state = TileState.opened);
  }

  void flagAllBombs() {
    _tiles
        .where((v) => v.hasBomb && v.state != TileState.opened)
        .forEach((v) => v.state = TileState.flagged);
  }
}

class MineSweeperSettings {
  final int width;
  final int height;
  final int bombs;
  final String level;

  String get description {
    return "$level ($width x $height / Mines x $bombs)";
  }

  const MineSweeperSettings.beginner()
      : width = 9,
        height = 9,
        bombs = 10,
        level = "Beginner";

  const MineSweeperSettings.intermediate()
      : width = 16,
        height = 16,
        bombs = 40,
        level = "Intermediate";

  const MineSweeperSettings.expert()
      : width = 30,
        height = 16,
        bombs = 99,
        level = "Expert";

  MineSweeperSettings(this.width, this.height, this.bombs) : level = "Custom";
}

class MineSweeperGame extends StatefulWidget {
  MineSweeperGame({Key key}) : super(key: key);

  @override
  _MineSweeperGameState createState() => _MineSweeperGameState();
}

class _MineSweeperGameState extends State<MineSweeperGame> {
  MineSweeperSettings setting = const MineSweeperSettings.beginner();
  MineField field;
  Timer timer;

  _MineSweeperGameState() {
    field = MineField(setting);
    timer = Timer.periodic(Duration(seconds: 1), (t) => setState(() {}));
  }

  Widget _buildTile(int row, int col) {
    MineTile mineTile = field.tileAt(row, col);

    return GestureDetector(
        child: MineTileWidget(mineTile),
        onTap: () => setState(() {
              field.startGame(row, col);
              field.openTile(row, col);
            }),
        onLongPress: () => setState(() {
              if (field.state != FieldState.playing) return;
              if (mineTile.state == TileState.opened) return;
              if (mineTile.state == TileState.closed) {
                mineTile.state = TileState.flagged;
              } else {
                mineTile.state = TileState.closed;
              }
            }));
  }

  Widget _buildField() {
    return Column(
        children: List.generate(
            field.height,
            (i) => Row(
                children:
                    List.generate(field.width, (j) => _buildTile(i, j)))));
  }

  Widget _buildMineField() {
    return SingleChildScrollView(
      child: SingleChildScrollView(
        child: Container(
            decoration: BoxDecoration(
                border: Border.all(width: 10.0, color: Colors.grey[400])),
            child: _buildField()),
        scrollDirection: Axis.horizontal,
      ),
      scrollDirection: Axis.vertical,
    );
  }

  Icon _buildTopIcon() {
    switch (field.state) {
      case FieldState.won:
        return Icon(Icons.sentiment_very_satisfied);
      case FieldState.lost:
        return Icon(Icons.sentiment_very_dissatisfied);
      case FieldState.waiting:
        return Icon(Icons.sentiment_neutral);
      case FieldState.playing:
      default:
        return Icon(Icons.sentiment_satisfied);
    }
  }

  @override
  Widget build(BuildContext context) {
    double barHeight = 35.0;
    return Column(children: [
      Container(
          color: Colors.grey[300],
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            NumberText(field.playingTime, height: barHeight),
            IconButton(
              icon: _buildTopIcon(),
              iconSize: barHeight,
              color: Colors.black,
              onPressed: () {
                setState(() {
                  field.resetField();
                });
              },
            ),
            NumberText(field.bombs - field.countTiles(state: TileState.flagged),
                height: barHeight),
          ])),
      Expanded(
        child: _buildMineField(),
      ),
      Container(
          child: IconButton(
            icon: Icon(Icons.settings),
            onPressed: () async {
              setting = await Navigator.push(context,
                  MaterialPageRoute(builder: (context) => SettingPage()));
              if (setting != null) {
                setState(() {
                  field = MineField(setting);
                });
              }
            },
          ),
          alignment: Alignment.centerRight)
    ]);
  }
}

class MineTileWidget extends StatelessWidget {
  final MineTile mineTile;
  final double size;

  final Border _openedBorder = Border.all(color: Colors.grey[600], width: 1);

  final Border _closedBorder = Border(
    top: BorderSide(color: Colors.grey[200], width: 4),
    right: BorderSide(color: Colors.grey[600], width: 4),
    bottom: BorderSide(color: Colors.grey[600], width: 4),
    left: BorderSide(color: Colors.grey[200], width: 4),
  );

  final List<Color> _tileColor = [
    Colors.blue[500],
    Colors.green[500],
    Colors.red[500],
    Colors.green[800],
    Colors.red[800],
    Colors.teal[600],
    Colors.black,
    Colors.grey[700],
  ];

  MineTileWidget(this.mineTile, {this.size: 30.0});

  Border _createBorder() {
    switch (mineTile.state) {
      case TileState.opened:
        return _openedBorder;
      case TileState.flagged:
      case TileState.closed:
      default:
        return _closedBorder;
    }
  }

  Widget _createInnerWidget() {
    switch (mineTile.state) {
      case TileState.opened:
        if (mineTile.hasBomb) {
          return Image(image: AssetImage("assets/bomb.png"));
        }
        if (mineTile.numBombs == 0) {
          return Text("");
        } else {
          return Text("${mineTile.numBombs}",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _tileColor[mineTile.numBombs - 1],
                  fontSize: size * 0.8,
                  fontWeight: FontWeight.bold));
        }
        break;
      case TileState.flagged:
        return Image(image: AssetImage("assets/flag.png"));
      case TileState.closed:
      default:
        return Text("");
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: size,
        height: size,
        child: Container(
          child: Center(child: _createInnerWidget()),
          decoration: BoxDecoration(
              border: _createBorder(),
              color: mineTile.exploded ? Colors.red : Colors.grey[300]),
        ));
  }
}

class NumberText extends StatelessWidget {
  final int number;
  final int letters;
  final double width;
  final double height;
  NumberText(this.number,
      {this.letters: 3, this.width: 60.0, this.height: 30.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Text(
        number.toString().padLeft(letters, "0"),
        textAlign: TextAlign.center,
        style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: height * 0.7),
      ),
      color: Colors.black,
      width: width,
      height: height,
      padding: EdgeInsets.all(height * 0.1),
    );
  }
}

class SettingPage extends StatefulWidget {
  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  List<MineSweeperSettings> _settingList = [
    MineSweeperSettings.beginner(),
    MineSweeperSettings.intermediate(),
    MineSweeperSettings.expert(),
  ];
  int _curRadio;

  void _handleRadio(int newValue) {
    setState(() {
      _curRadio = newValue;
    });
  }

  Widget _createRadio(int radioNum) {
    return Row(
      children: <Widget>[
        Radio(
          groupValue: _curRadio,
          value: radioNum,
          onChanged: _handleRadio,
        ),
        Text(_settingList[radioNum].description),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("settings")),
        body: Column(children: <Widget>[
          _createRadio(0),
          _createRadio(1),
          _createRadio(2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              RaisedButton(
                  child: Text("OK"),
                  onPressed: () {
                    Navigator.pop(context, _settingList[_curRadio]);
                  }),
              RaisedButton(
                  child: Text("Cancel"),
                  onPressed: () {
                    Navigator.pop(context);
                  })
            ],
          )
        ]));
  }
}
