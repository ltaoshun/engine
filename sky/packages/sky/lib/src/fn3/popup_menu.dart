// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:sky' as sky;

import 'package:sky/animation.dart';
import 'package:sky/painting.dart';
import 'package:sky/material.dart';
import 'package:sky/src/fn3/basic.dart';
import 'package:sky/src/fn3/focus.dart';
import 'package:sky/src/fn3/framework.dart';
import 'package:sky/src/fn3/gesture_detector.dart';
import 'package:sky/src/fn3/navigator.dart';
import 'package:sky/src/fn3/popup_menu_item.dart';
import 'package:sky/src/fn3/scrollable.dart';
import 'package:sky/src/fn3/transitions.dart';

const Duration _kMenuDuration = const Duration(milliseconds: 300);
const double _kMenuCloseIntervalEnd = 2.0 / 3.0;
const double _kMenuWidthStep = 56.0;
const double _kMenuMargin = 16.0; // 24.0 on tablet
const double _kMenuMinWidth = 2.0 * _kMenuWidthStep;
const double _kMenuMaxWidth = 5.0 * _kMenuWidthStep;
const double _kMenuHorizontalPadding = 16.0;
const double _kMenuVerticalPadding = 8.0;

class PopupMenu extends StatefulComponent {
  PopupMenu({
    Key key,
    this.items,
    this.level: 4,
    this.navigator,
    this.performance
  }) : super(key: key) {
    assert(items != null);
    assert(performance != null);
  }

  final List<PopupMenuItem> items;
  final int level;
  final NavigatorState navigator;
  final WatchableAnimationPerformance performance;

  PopupMenuState createState() => new PopupMenuState(this);
}

class PopupMenuState extends ComponentState<PopupMenu> {
  PopupMenuState(PopupMenu config) : super(config) {
    _updateBoxPainter();
    config.performance.addListener(_performanceChanged);
  }

  BoxPainter _painter;

  void _updateBoxPainter() {
    _painter = new BoxPainter(
      new BoxDecoration(
        backgroundColor: Colors.grey[50],
        borderRadius: 2.0,
        boxShadow: shadows[config.level]
      )
    );
  }

  void didUpdateConfig(PopupMenu oldConfig) {
    if (config.level != config.level)
      _updateBoxPainter();
    if (config.performance != oldConfig.performance) {
      oldConfig.performance.removeListener(_performanceChanged);
      config.performance.addListener(_performanceChanged);
    }
  }

  void dispose() {
    config.performance.removeListener(_performanceChanged);
  }

  void _performanceChanged() {
    setState(() {
      // the performance changed, and our state is tied up with the performance
    });
  }

  Widget build(BuildContext context) {
    double unit = 1.0 / (config.items.length + 1.5); // 1.0 for the width and 0.5 for the last item's fade.
    List<Widget> children = [];
    for (int i = 0; i < config.items.length; ++i) {
      double start = (i + 1) * unit;
      double end = (start + 1.5 * unit).clamp(0.0, 1.0);
      children.add(new FadeTransition(
        performance: config.performance,
        opacity: new AnimatedValue<double>(0.0, end: 1.0, interval: new Interval(start, end)),
        child: new GestureDetector(
          onTap: () { config.navigator.pop(config.items[i].value); },
          child: config.items[i]
        ))
      );
    }
    final width = new AnimatedValue<double>(0.0, end: 1.0, interval: new Interval(0.0, unit));
    final height = new AnimatedValue<double>(0.0, end: 1.0, interval: new Interval(0.0, unit * config.items.length));
    return new FadeTransition(
      performance: config.performance,
      opacity: new AnimatedValue<double>(0.0, end: 1.0, interval: new Interval(0.0, 1.0 / 3.0)),
      child: new Container(
        margin: new EdgeDims.all(_kMenuMargin),
        child: new BuilderTransition(
          performance: config.performance,
          variables: [width, height],
          builder: (BuildContext context) {
            return new CustomPaint(
              callback: (sky.Canvas canvas, Size size) {
                double widthValue = width.value * size.width;
                double heightValue = height.value * size.height;
                _painter.paint(canvas, new Rect.fromLTWH(size.width - widthValue, 0.0, widthValue, heightValue));
              },
              child: new ConstrainedBox(
                constraints: new BoxConstraints(
                  minWidth: _kMenuMinWidth,
                  maxWidth: _kMenuMaxWidth
                ),
                child: new IntrinsicWidth(
                  stepWidth: _kMenuWidthStep,
                  child: new ScrollableViewport(
                    child: new Container(
                      padding: const EdgeDims.symmetric(
                        horizontal: _kMenuHorizontalPadding,
                        vertical: _kMenuVerticalPadding
                      ),
                      child: new BlockBody(children)
                    )
                  )
                )
              )
            );
          }
        )
      )
    );
  }
}

class MenuPosition {
  const MenuPosition({ this.top, this.right, this.bottom, this.left });
  final double top;
  final double right;
  final double bottom;
  final double left;
}

class MenuRoute extends RouteBase {
  MenuRoute({ this.completer, this.position, this.builder, this.level });

  final Completer completer;
  final MenuPosition position;
  final PopupMenuItemsBuilder builder;
  final int level;

  AnimationPerformance createPerformance() {
    AnimationPerformance result = super.createPerformance();
    AnimationTiming timing = new AnimationTiming();
    timing.reverseInterval = new Interval(0.0, _kMenuCloseIntervalEnd);
    result.timing = timing;
    return result;
  }

  Duration get transitionDuration => _kMenuDuration;
  bool get isOpaque => false;
  Widget build(Key key, NavigatorState navigator, WatchableAnimationPerformance performance) {
    return new Positioned(
      top: position?.top,
      right: position?.right,
      bottom: position?.bottom,
      left: position?.left,
      child: new Focus(
        key: new GlobalObjectKey(this),
        autofocus: true,
        child: new PopupMenu(
          key: key,
          items: builder != null ? builder(navigator) : const <PopupMenuItem>[],
          level: level,
          navigator: navigator,
          performance: performance
        )
      )
    );
  }

  void popState([dynamic result]) {
    completer.complete(result);
  }
}

typedef List<PopupMenuItem> PopupMenuItemsBuilder(NavigatorState navigator);

Future showMenu({ NavigatorState navigator, MenuPosition position, PopupMenuItemsBuilder builder, int level: 4 }) {
  Completer completer = new Completer();
  navigator.push(new MenuRoute(
    completer: completer,
    position: position,
    builder: builder,
    level: level
  ));
  return completer.future;
}
