import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ArenaWidget(),
    );
  }
}

class ArenaWidget extends StatefulWidget {
  const ArenaWidget({super.key});

  @override
  _ArenaWidgetState createState() => _ArenaWidgetState();
}

class _ArenaWidgetState extends State<ArenaWidget>
    with SingleTickerProviderStateMixin {
  List<Element> players = [];
  Timer? _timer;
  List<Color> elementColors = [
    Colors.black,
    Colors.blue,
    Colors.green,
  ];
  late AnimationController controller;
  @override
  void initState() {
    super.initState();
    spawnElements();
    controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
  }

  void spawnElements() {
    gameOver = false;
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      final size = MediaQuery.of(context).size;
      final random = Random();
      players = List.generate(10, (index) {
        final randomI = random.nextInt(3);
        final position = Position(
          random.nextInt(size.width.toInt() - 100) + 10,
          random.nextInt(size.height.toInt() - 100) + 10,
        );
        return Element(
            // random element type
            ElementType.values[randomI],
            'Player $index',
            icons[randomI],
            position,
            speed: Random().nextDouble() * 2,
            elementColors[randomI]);
      });
    });
  }

  List<IconData> icons = [
    Icons.emoji_objects, //rock
    Icons.file_present_rounded, //paper
    Icons.cut, // scissor
  ];

  void battle() {
    isPlaying = true;
    controller.forward();
    _timer = Timer.periodic(Duration(milliseconds: 1000 ~/ frameRate),
        (timer) async {
      setState(() {});
    });
  }

  void holdBattle() {
    _timer?.cancel();
    isPlaying = false;
    controller.reverse();
  }

  String gWinner = '';
  @override
  void dispose() {
    _timer!.cancel();
    super.dispose();
  }

  bool gameOver = false;
  int frameRate = 100;
  bool isPlaying = false;
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Material(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: ArenaPainter(players,
                onCollison: () {
                  SystemSound.play(SystemSoundType.click);
                },
                moving: () async {},
                gameOver: (ElementType winner) {
                  holdBattle();
                  SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
                    setState(() {
                      players.clear();
                      gameOver = true;
                      gWinner = winner.name;
                      isPlaying = false;
                    });
                  });
                  print("Game Over: ${winner.name} won");
                }),
            size: Size(
              size.width - 100,
              size.height - 100,
            ),
          ),
          Positioned(
              top: 50,
              right: 20,
              child: IconButton(
                  onPressed: () {
                    if (isPlaying) {
                      // stop the Game
                      holdBattle();
                    } else {
                      // start the game
                      if (gameOver) {
                        spawnElements();
                        battle();
                      } else {
                        battle();
                      }
                    }
                  },
                  icon: AnimatedIcon(
                      size: 48,
                      color: isPlaying ? Colors.red : Colors.green,
                      icon: AnimatedIcons.play_pause,
                      progress: controller))),
          !gameOver
              ? const SizedBox.shrink()
              : Align(
                  alignment: Alignment.center,
                  child: Text('Winner: $gWinner',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 30,
                      )),
                )
        ],
      ),
    );
  }
}

class ArenaPainter extends CustomPainter {
  final List<Element> elements;
  Function(ElementType)? gameOver;
  final VoidCallback? onCollison;
  final VoidCallback? moving;
  ElementType? winner;
  int elementSize = 32;
  Offset arenaX = Offset.zero;
  Offset arenaY = Offset.zero;
  ArenaPainter(this.elements, {this.gameOver, this.onCollison, this.moving});
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    arenaX = Offset(10, size.width - 50);
    arenaY = Offset(50, size.height - 100);
    // draw arena border
    canvas.drawRect(
        Rect.fromLTWH(10, 50, size.width - 20, size.height - 100), paint);

    layout(canvas, size);
    moveElements(canvas, size);
    layout(canvas, size);
    winner = isGameover();
    if (winner != null) {
      //    layout(canvas, size);
      /// paint game over text
      // const textSpan = TextSpan(
      //     text: 'Game Over',
      //     style: TextStyle(
      //       color: Colors.red,
      //       fontSize: 30,
      //     ));
      // final textPainter = TextPainter(
      //   text: textSpan,
      //   textDirection: TextDirection.ltr,
      // );
      // textPainter.layout();
      // textPainter.paint(
      //     canvas, Offset(size.width / 2 - textPainter.width / 2, size.height / 2));
      gameOver?.call(winner!);
    }
    printElementCounts();
  }

  ElementType? isGameover() {
    // if all elements are same type
    int length = elements.length;

    var rockCount = elements.where((element) => element.isRock).length;
    var paperCount = elements.where((element) => element.isPaper).length;
    var scissorCount = elements.where((element) => element.isScissor).length;

    // elements will be empty during initialization
    if (elements.isNotEmpty) {
      // return winner
      if (rockCount == length) {
        return ElementType.rock;
      } else if (paperCount == length) {
        return ElementType.paper;
      } else if (scissorCount == length) {
        return ElementType.scissor;
      }
    }
    return null;
  }

  // move elements to nearest element of different type
  // when two elements are in the same position, fight
  // if one element losed, it is replaced by the winner
  void moveElements(Canvas canvas, Size size) {
    moving?.call();
    for (var i = 0; i < elements.length; i++) {
      var element = elements[i];
      moveTowardsTarget(element);
      // if two elements are close enough to fight in the same position, fight
      for (int j = 0; j < elements.length; j++) {
        var other = elements[j];
        if (readyToFight(element, other)) {
          printElementCounts();
          var winner = fight(element, other);
          onCollison!.call();
          if (winner != other) {
            int index = elements.indexOf(other);
            final replaceElement = element.fromOther(other);
            elements[index] = replaceElement;
            // replace other with element
            // elements.remove(other);
          } else {
            // replace element with other
            int index = elements.indexOf(element);
            if (index >= 0) {
              elements[index] = other;
            }
          }
        }
      }
    }
  }

  Element findTargetELement(Element element) {
    Element targetElement = element;
    int nearestDistance = 100000;
    for (int j = 0; j < elements.length; j++) {
      var other = elements[j];
      int distance = element.distanceTo(other);
      if (distance < nearestDistance && element.isTarget(other)) {
        nearestDistance = distance;
        targetElement = other;
      }
    }
    return targetElement;
  }

  void moveTowardsTarget(Element element) {
    Element targetElement = findTargetELement(element);
    final dx = targetElement.position.dx(element.position);
    final dy = targetElement.position.dy(element.position);
    final distanceToTarget = element.distanceTo(targetElement);
    if (distanceToTarget > 0) {
      // move element to _targetElement based on speed
      final newPosition = Position(
        element.position.x + dx * element.speed ~/ distanceToTarget,
        element.position.y + dy * element.speed ~/ distanceToTarget,
      );

      // if element is out of arena, move it back
      if (newPosition.x < arenaX.dx) {
        newPosition.x = arenaX.dx.toInt();
        element.speed = -element.speed;
      } else if (newPosition.x > arenaX.dy) {
        element.speed = -element.speed;
        newPosition.x = arenaX.dy.toInt();
      }
      if (newPosition.y < arenaY.dx) {
        newPosition.y = arenaY.dx.toInt();
        element.speed = -element.speed;
      } else if (newPosition.y >= arenaY.dy) {
        element.speed = -element.speed;
        newPosition.y = arenaY.dy.toInt();
      }
      element.position = newPosition;
    }
  }

  // step to target
  Position moveDirection(Element element, Element target) {
    var dx = target.position.x - element.position.x;
    var dy = target.position.y - element.position.y;
    var distance = element.distanceTo(target);
    var x = element.position.x + dx * element.speed / distance;
    var y = element.position.y + dy * element.speed / distance;
    return Position(x.toInt(), y.toInt());
  }

  bool readyToFight(Element a, Element b) {
    // if positions are nearby in 5 pixels
    return isNearBy(a, b) && a.type != b.type;
  }

  bool isNearBy(Element a, Element b) {
    return a.distanceTo(b) < 10;
  }

  void printElementCounts() {
    var rockCount = elements.where((element) => element.isRock).length;
    var paperCount = elements.where((element) => element.isPaper).length;
    var scissorCount = elements.where((element) => element.isScissor).length;
    debugPrint('rock: $rockCount, paper: $paperCount, scissor: $scissorCount');
  }

  void layout(Canvas canvas, Size size) {
    for (var i = 0; i < elements.length; i++) {
      var element = elements[i];
      // icon painter
      final iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(element.icon.codePoint),
          style: TextStyle(
            fontSize: 32,
            color: element.color,
            fontFamily: element.icon.fontFamily,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      iconPainter.layout();
      iconPainter.paint(canvas, element.position.toOffset());
    }
  }

  @override
  bool shouldRepaint(ArenaPainter oldDelegate) {
    return listEquals(oldDelegate.elements, elements);
  }

  Element fight(Element a, Element b) {
    if (a.competes(b)) {
      return a;
    } else {
      return b;
    }
  }
}

enum ElementType { rock, paper, scissor }

class Element {
  final ElementType type;
  Position position;
  final String name;
  final IconData icon;
  double speed;
  final Color color;

  /// The element this element is moving towards
  /// this is calculated by determining the nearest element of different type

  Element(this.type, this.name, this.icon, this.position, this.color,
      {this.speed = 5});

  @override
  String toString() {
    return 'Element{type: $type, position: $position, name: $name, icon: $icon, speed: $speed}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Element &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          position == other.position &&
          speed == other.speed &&
          name == other.name &&
          icon == other.icon;

  @override
  int get hashCode =>
      type.hashCode ^ position.hashCode ^ name.hashCode ^ icon.hashCode;
}

// Paper beats rock
// Rock beats scissor
// Scissor beats paper
// e.g rock.isWinner(scissor) => true
extension ElementExtension on Element {
  bool competes(Element other) {
    if (isRock && other.isScissor) {
      return true;
    } else if (isPaper && other.isRock) {
      return true;
    } else if (isScissor && other.isPaper) {
      return true;
    }
    return false;
  }

  bool get isRock => type == ElementType.rock;
  bool get isPaper => type == ElementType.paper;
  bool get isScissor => type == ElementType.scissor;

  // distance between two elements
  int distanceTo(Element other) {
    int dx = position.x - other.position.x;
    int dy = position.y - other.position.y;
    return sqrt(pow(dx, 2) + pow(dy, 2)).toInt();
  }

  // is this element a target
  // e.g. if this is rock, then paper is a target
  // if this is paper, then scissor is a target
  // if this is scissor, then rock is a target
  bool isTarget(Element e) {
    if (isRock && e.isPaper) {
      return true;
    } else if (isPaper && e.isScissor) {
      return true;
    } else if (isScissor && e.isRock) {
      return true;
    }
    return false;
  }

  // replace other with this
  Element fromOther(Element other) {
    return Element(type, name, icon, other.position, color, speed: speed);
  }
}

class Position {
  int x;
  int y;
  Position(this.x, this.y);

  Offset toOffset() {
    return Offset(x.toDouble(), y.toDouble());
  }

  int dx(Position other) {
    return (x - other.x).abs();
  }

  int dy(Position other) {
    return (y - other.y).abs();
  }

  @override
  String toString() {
    return 'Position{x: $x, dy: $y}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Position &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;
}
