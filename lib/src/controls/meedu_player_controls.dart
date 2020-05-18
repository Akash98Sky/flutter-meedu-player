import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../colors.dart';
import '../meedu_video_player_controller.dart';
import 'player_button.dart';
import 'video_bottom_controls.dart';

class MeeduPlayerControls extends StatefulWidget {
  @override
  _MeeduPlayerControlsState createState() => _MeeduPlayerControlsState();
}

class _MeeduPlayerControlsState extends State<MeeduPlayerControls>
    with SingleTickerProviderStateMixin {
  Timer _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    // _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MeeduPlayerController>(
      builder: (_, controller, __) {
        if (controller.loading || controller.error) return Container(height: 0);

        final visible = _visible ||
            (controller.loaded && !controller.autoPlay) ||
            controller.finished;

        return Positioned.fill(
          child: GestureDetector(
            onTap: () {
              _visible = !_visible;
              setState(() {});
            },
            child: AnimatedContainer(
              color: controller.backgroundColor.withOpacity(
                visible ? 0.6 : 0,
              ),
              height: double.infinity,
              duration: Duration(milliseconds: 300),
              child: LayoutBuilder(
                builder: (_, constraints) {
                  return Stack(
                    alignment: Alignment.bottomCenter,
                    children: <Widget>[
                      //START HEADER
                      AnimatedPositioned(
                        duration: Duration(milliseconds: 300),
                        left: 0,
                        right: 0,
                        top: _visible ? 0 : -100,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                controller.backgroundColor,
                                controller.backgroundColor.withOpacity(0.3),
                                Colors.transparent,
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              controller.title != null
                                  ? Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: controller.title,
                                      ),
                                    )
                                  : Container(),
                            ],
                          ),
                        ),
                      ),
                      // END HEADER

                      AnimatedPositioned(
                        top:
                            (visible ? 1 : -1) * constraints.maxHeight / 2 - 40,
                        duration: Duration(milliseconds: 300),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            PlayerButton(
                              size: 50,
                              onPressed: () {
                                final to =
                                    controller.position.value.inSeconds - 10;
                                if (to >= 0) {
                                  controller.seekTo(Duration(seconds: to));
                                }
                              },
                              asset: 'assets/icons/fast-rewind.svg',
                            ),
                            SizedBox(width: 25),
                            PlayerButton(
                              onPressed: () {
                                if (controller.playing) {
                                  controller.pause();
                                } else if (controller.paused) {
                                  controller.resume();
                                } else {
                                  controller.repeat();
                                }
                              },
                              asset: controller.finished
                                  ? 'assets/icons/repeat.svg'
                                  : (controller.playing
                                      ? 'assets/icons/paused.svg'
                                      : 'assets/icons/play.svg'),
                            ),
                            SizedBox(width: 25),
                            PlayerButton(
                              size: 50,
                              onPressed: () {
                                final to =
                                    controller.position.value.inSeconds + 10;
                                if (to < controller.duration.value.inSeconds) {
                                  controller.seekTo(Duration(seconds: to));
                                }
                              },
                              asset: 'assets/icons/fast-forward.svg',
                            )
                          ],
                        ),
                      ),
                      AnimatedPositioned(
                        left: 0,
                        right: 0,
                        bottom: visible ? 0 : -100,
                        duration: Duration(milliseconds: 300),
                        child: VideoBottomControls(
                          controller: controller,
                        ),
                      )
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}