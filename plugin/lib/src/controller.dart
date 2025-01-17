import 'dart:async';
import 'package:fijkplayer/fijkplayer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:meedu_player/meedu_player.dart' show MeeduPlayerProvider;
import 'package:meedu_player/src/helpers/custom_icons.dart';
import 'package:meedu_player/src/helpers/enabled_buttons.dart';
import 'package:meedu_player/src/helpers/meedu_player_status.dart';
import 'package:meedu_player/src/helpers/player_data_status.dart';
import 'package:meedu_player/src/helpers/screen_manager.dart';
import 'package:meedu_player/src/native/pip_manager.dart';
import 'package:meedu_player/src/widgets/fullscreen_page.dart';
import 'package:meedu/rx.dart';

enum ControlsStyle { primary, secondary }

class MeeduPlayerController {
  /// the video_player controller
  FijkPlayer _videoPlayerController;
  final _pipManager = PipManager();

  /// Screen Manager to define the overlays and device orientation when the player enters in fullscreen mode
  final ScreenManager screenManager;

  /// use this class to change the default icons with your custom icons
  CustomIcons customIcons;

  /// use this class to hide some buttons in the player
  EnabledButtons enabledButtons;

  /// the playerStatus to notify the player events like paused,playing or stopped
  /// [playerStatus] has a [status] observable
  final MeeduPlayerStatus playerStatus = MeeduPlayerStatus();

  /// the dataStatus to notify the load sources events
  /// [dataStatus] has a [status] observable
  final MeeduPlayerDataStatus dataStatus = MeeduPlayerDataStatus();
  final Color colorTheme;
  final bool controlsEnabled;
  String _errorText;
  String get errorText => _errorText;
  Widget loadingWidget, header, bottomRight;
  final ControlsStyle controlsStyle;
  final bool pipEnabled, showPipButton;
  BuildContext _pipContextToFullscreen;

  String tag;

  // OBSERVABLES
  Rx<Duration> _position = Rx(Duration.zero);
  Rx<Duration> _sliderPosition = Rx(Duration.zero);
  Rx<Duration> _duration = Rx(Duration.zero);
  Rx<Duration> _buffered = Rx(Duration.zero);
  Rx<bool> _closedCaptionEnabled = false.obs;

  Rx<bool> _mute = false.obs;
  Rx<bool> _fullscreen = false.obs;
  Rx<bool> _showControls = true.obs;
  Rx<bool> _pipAvailable = false.obs;

  // NO OBSERVABLES
  bool _isSliderMoving = false;
  bool _looping = false;
  bool _autoplay = false;
  double _volumeBeforeMute = 0;
  double _playbackSpeed = 1.0;
  Timer _timer;
  RxWorker _pipModeWorker;
  List<StreamSubscription> _oldSubscriptions = [];
  Duration _scheduleSeekTo;

  // GETS

  /// use this stream to listen the player data events like none, loading, loaded, error
  Stream<DataStatus> get onDataStatusChanged => dataStatus.status.stream;

  /// use this stream to listen the player data events like stopped, playing, paused
  Stream<PlayerStatus> get onPlayerStatusChanged => playerStatus.status.stream;

  /// current position of the player
  Rx<Duration> get position => _position;

  /// use this stream to listen the changes in the video position
  Stream<Duration> get onPositionChanged => _position.stream;

  /// duration of the video
  Rx<Duration> get duration => _duration;

  /// use this stream to listen the changes in the video duration
  Stream<Duration> get onDurationChanged => _duration.stream;

  /// [mute] is true if the player is muted
  Rx<bool> get mute => _mute;
  Stream<bool> get onMuteChanged => _mute.stream;

  /// [fullscreen] is true if the player is in fullscreen mode
  Rx<bool> get fullscreen => _fullscreen;
  Stream<bool> get onFullscreenChanged => _fullscreen.stream;

  /// [showControls] is true if the player controls are visible
  Rx<bool> get showControls => _showControls;
  Stream<bool> get onShowControlsChanged => _showControls.stream;

  /// [sliderPosition] the video slider position
  Rx<Duration> get sliderPosition => _sliderPosition;
  Stream<Duration> get onSliderPositionChanged => _sliderPosition.stream;

  /// [bufferedLoaded] buffered Loaded for network resources
  Rx<Duration> get buffered => _buffered;
  Stream<Duration> get onBufferedChanged => _buffered.stream;

  /// [videoPlayerController] instace of VideoPlayerController
  FijkPlayer get videoPlayerController => _videoPlayerController;

  /// the playback speed default value is 1.0
  double get playbackSpeed => _playbackSpeed;

  /// [looping] is true if the player is looping
  bool get looping => _looping;

  /// [autoPlay] is true if the player has enabled the autoplay
  bool get autoplay => _autoplay;

  Rx<bool> get closedCaptionEnabled => _closedCaptionEnabled;
  Stream<bool> get onClosedCaptionEnabledChanged =>
      _closedCaptionEnabled.stream;

  /// [isInPipMode] is true if pip mode is enabled
  Rx<bool> get isInPipMode => _pipManager.isInPipMode;
  Stream<bool> get onPipModeChanged => _pipManager.isInPipMode.stream;

  Rx<bool> isBuffering = true.obs;

  /// returns the os version
  Future<double> get osVersion async {
    return _pipManager.osVersion;
  }

  /// returns true if the pip mode can used on the current device, the initial value will be false after check if pip is available
  Rx<bool> get pipAvailable => _pipAvailable;

  /// creates an instance of [MeeduPlayerControlle]
  ///
  /// [screenManager] the device orientations and overlays
  /// [placeholder] widget to show when the player is loading a video
  /// [controlsEnabled] if the player must show the player controls
  /// [errorText] message to show when the load process failed
  MeeduPlayerController({
    this.screenManager = const ScreenManager(),
    this.colorTheme = Colors.redAccent,
    Widget loadingWidget,
    this.controlsEnabled = true,
    String errorText,
    this.controlsStyle = ControlsStyle.primary,
    this.header,
    this.bottomRight,
    this.pipEnabled = false,
    this.showPipButton = false,
    this.customIcons = const CustomIcons(),
    this.enabledButtons = const EnabledButtons(),
    FijkLogLevel logLevel = FijkLogLevel.Info,
  }) {
    FijkLog.setLevel(logLevel);
    _videoPlayerController = FijkPlayer();
    _errorText = errorText;
    this.tag = DateTime.now().microsecondsSinceEpoch.toString();
    this.loadingWidget = loadingWidget ??
        SpinKitWave(
          size: 30,
          color: this.colorTheme,
        );

    if (pipEnabled) {
      // get the OS version and check if pip is available
      this._pipManager.checkPipAvailable().then(
            (value) => _pipAvailable.value = value,
          );
      // listen the pip mode changes
      _pipModeWorker = _pipManager.isInPipMode.ever(this._onPipModeChanged);
    } else {
      _pipAvailable.value = false;
    }
  }

  /// initialize the video_player controller and load the data source
  Future<void> _initializePlayer(
    String dataSource, {
    Duration seekTo,
  }) async {
    if (_videoPlayerController.state != FijkState.idle)
      await _videoPlayerController.reset();
    await _videoPlayerController.setDataSource(
      dataSource,
      autoPlay: playerStatus.playing,
    );
    await _videoPlayerController.prepareAsync();

    if (seekTo != null && seekTo != Duration.zero) {
      await this.seekTo(seekTo);
    }

    // if the playbackSpeed is not the default value
    if (_playbackSpeed != 1.0) {
      await setPlaybackSpeed(_playbackSpeed);
    }

    if (_looping) {
      await setLooping(_looping);
    }

    if (_autoplay) {
      // if the autoplay is enabled
      await this.play();
    }
  }

  void _listener() {
    // save the volume value
    FijkVolume.getVol().then((volume) {
      if (!mute.value && _volumeBeforeMute != volume)
        _volumeBeforeMute = volume;
    });

    // run scheduled seek when controller is in playable state
    if (_scheduleSeekTo != null && _videoPlayerController.isPlayable())
      this.seekTo(_scheduleSeekTo);

    // check the player status
    switch (_videoPlayerController.state) {
      case FijkState.started:
        playerStatus.status.value = PlayerStatus.playing;
        break;
      case FijkState.completed:
      case FijkState.stopped:
      case FijkState.end:
        playerStatus.status.value = PlayerStatus.stopped;
        break;
      case FijkState.paused:
        playerStatus.status.value = PlayerStatus.paused;
        break;
      case FijkState.prepared:
        // reset buffering state when new source has prepared
        isBuffering.value = false;
        break;
      default:
    }

    // set the video duration
    _duration.value = _videoPlayerController.value.duration;
  }

  /// set the video data source
  ///
  /// [autoPlay] if this is true the video automatically start
  Future<void> setDataSource(
    String dataSource, {
    bool autoplay,
    bool looping,
    Duration seekTo,
  }) async {
    try {
      _autoplay = autoplay ?? this._autoplay;
      _looping = looping ?? this._looping;
      dataStatus.status.value = DataStatus.loading;

      // if we are playing a video
      if (_videoPlayerController.state == FijkState.started) {
        await this.pause(notify: false);
      }

      // Remove old listners and subscriptions
      _videoPlayerController.removeListener(this._listener);
      await Future.wait(_oldSubscriptions.map((sub) => sub.cancel()));
      _oldSubscriptions.clear();

      // set state to buffering
      isBuffering.value = true;

      // create a new video_player controller using the dataSource
      await _initializePlayer(dataSource, seekTo: seekTo);

      /// notify that video was loaded
      dataStatus.status.value = DataStatus.loaded;

      _oldSubscriptions.addAll([
        _videoPlayerController.onCurrentPosUpdate.listen((position) {
          // set the current video position
          _position.value = position;
          if (!_isSliderMoving) {
            _sliderPosition.value = position;
          }
        }),
        _videoPlayerController.onBufferPosUpdate.listen((buffered) {
          // set the video buffered loaded
          if (buffered.inSeconds > 0) _buffered.value = buffered;
        }),
        _videoPlayerController.onBufferStateUpdate.listen((_) {
          // update the video buffering state
          if (_buffered.value.inSeconds > 0)
            isBuffering.value = _videoPlayerController.isBuffering;
        }),
      ]);

      // listen the video player events
      _videoPlayerController.addListener(this._listener);
    } catch (e, s) {
      print(e);
      print(s);
      if (_errorText == null) {
        _errorText = 'Playback Error';
      }
      dataStatus.status.value = DataStatus.error;
    }
  }

  /// play the current video
  ///
  /// [repeat] if is true the player go to Duration.zero before play
  Future<void> play({bool repeat = false}) async {
    if (repeat) {
      await seekTo(Duration.zero);
    }
    await _videoPlayerController?.start();
    playerStatus.status.value = PlayerStatus.playing;

    _hideTaskControls();
  }

  /// pause the current video
  ///
  /// [notify] if is true and the events is not null we notifiy the event
  Future<void> pause({bool notify = true}) async {
    await _videoPlayerController?.pause();
    playerStatus.status.value = PlayerStatus.paused;
  }

  /// seek the current video position
  Future<void> seekTo(Duration position) async {
    if (_videoPlayerController.isPlayable()) {
      _scheduleSeekTo = null;
      await _videoPlayerController?.seekTo(position.inMilliseconds);
    } else
      _scheduleSeekTo = position;

    if (playerStatus.stopped || playerStatus.paused) {
      await play();
    }
  }

  /// Sets the playback speed of [this].
  ///
  /// [speed] indicates a speed value with different platforms accepting
  /// different ranges for speed values. The [speed] must be greater than 0.
  ///
  /// The values will be handled as follows:
  /// * On web, the audio will be muted at some speed when the browser
  ///   determines that the sound would not be useful anymore. For example,
  ///   "Gecko mutes the sound outside the range `0.25` to `5.0`" (see https://developer.mozilla.org/en-US/docs/Web/API/HTMLMediaElement/playbackRate).
  /// * On Android, some very extreme speeds will not be played back accurately.
  ///   Instead, your video will still be played back, but the speed will be
  ///   clamped by ExoPlayer (but the values are allowed by the player, like on
  ///   web).
  /// * On iOS, you can sometimes not go above `2.0` playback speed on a video.
  ///   An error will be thrown for if the option is unsupported. It is also
  ///   possible that your specific video cannot be slowed down, in which case
  ///   the plugin also reports errors.
  Future<void> setPlaybackSpeed(double speed) async {
    await _videoPlayerController?.setSpeed(speed);
    _playbackSpeed = speed;
  }

  /// Sets whether or not the video should loop after playing once
  Future<void> setLooping(bool looping) async {
    await _videoPlayerController?.setLoop(looping ? 0 : 1);
    _looping = looping;
  }

  /// Sets the audio volume
  /// [volume] indicates a value between 0.0 (silent) and 1.0 (full volume) on a
  /// linear scale.
  Future<void> setVolume(double volume) async {
    assert(volume >= 0.0 && volume <= 1.0); // validate the param
    _volumeBeforeMute = await FijkVolume.getVol();
    await _videoPlayerController?.setVolume(volume);
  }

  void onChangedSliderStart() {
    _isSliderMoving = true;
  }

  onChangedSlider(double v) {
    _sliderPosition.value = Duration(seconds: v.floor());
  }

  void onChangedSliderEnd() {
    _isSliderMoving = false;
  }

  /// set the video player to mute or sound
  ///
  /// [enabled] if is true the video player is muted
  Future<void> setMute(bool enabled) async {
    if (enabled) {
      _volumeBeforeMute = await FijkVolume.getVol();
    }
    _mute.value = enabled;
    await this.setVolume(enabled ? 0 : _volumeBeforeMute);
  }

  /// fast Forward (10 seconds)
  Future<void> fastForward() async {
    final to = position.value.inSeconds + 10;
    if (duration.value.inSeconds > to) {
      await seekTo(Duration(seconds: to));
    }
  }

  /// rewind (10 seconds)
  Future<void> rewind() async {
    final to = position.value.inSeconds - 10;
    await seekTo(Duration(seconds: to < 0 ? 0 : to));
  }

  /// show or hide the player controls
  set controls(bool visible) {
    _showControls.value = visible;
    if (_timer != null) {
      _timer.cancel();
    }
    if (visible) {
      _hideTaskControls();
    }
  }

  /// create a taks to hide controls after certain time
  void _hideTaskControls() {
    _timer = Timer(Duration(seconds: 5), () {
      this.controls = false;
      _timer = null;
    });
  }

  /// show the player in fullscreen mode
  Future<void> goToFullscreen(
    BuildContext context, {
    bool appliyOverlaysAndOrientations = true,
  }) async {
    if (appliyOverlaysAndOrientations) {
      await screenManager.setFullScreenOverlaysAndOrientations();
    }
    _fullscreen.value = true;
    final route = MaterialPageRoute(
      builder: (_) => MeeduPlayerFullscreenPage(controller: this),
    );

    await Navigator.push(context, route);
    await screenManager.setDefaultOverlaysAndOrientations();
    _fullscreen.value = false;
  }

  /// launch a video using the fullscreen apge
  ///
  /// [dataSource]
  /// [autoplay]
  /// [looping]
  Future<void> launchAsFullscreen(
    BuildContext context, {
    @required String dataSource,
    bool autoplay = false,
    bool looping = false,
    Widget header,
    Widget bottomRight,
    Duration seekTo,
  }) async {
    this.header = header;
    this.bottomRight = bottomRight;
    setDataSource(
      dataSource,
      autoplay: autoplay,
      looping: looping,
      seekTo: seekTo,
    );
    await goToFullscreen(context);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _position.value = Duration.zero;
      _timer?.cancel();
      await pause();
      _videoPlayerController?.removeListener(this._listener);
    });
  }

  /// dispose de video_player controller
  Future<void> dispose() async {
    if (_videoPlayerController != null) {
      await Future.wait(_oldSubscriptions.map((sub) => sub.cancel()));
      _timer?.cancel();
      _position.close();
      _sliderPosition.close();
      _duration.close();
      _buffered.close();
      _closedCaptionEnabled.close();
      _mute.close();
      _fullscreen.close();
      _showControls.close();
      _pipAvailable.close();
      _pipModeWorker?.dispose();
      _pipManager.dispose();
      playerStatus.status.close();
      dataStatus.status.close();
      _videoPlayerController?.removeListener(this._listener);

      await _videoPlayerController?.release();
    }
  }

  /// enable or diable the visibility of ClosedCaptionFile
  void onClosedCaptionEnabled(bool enabled) {
    _closedCaptionEnabled.value = enabled;
  }

  /// enter to picture in picture mode only Android
  ///
  /// only available since Android 7
  Future<void> enterPip(BuildContext context) async {
    if (this.pipAvailable.value && this.pipEnabled) {
      controls = false; // hide the controls
      if (!fullscreen.value) {
        // if the player is not in the fullscreen mode
        _pipContextToFullscreen = context;
        goToFullscreen(context, appliyOverlaysAndOrientations: false);
      }
      await _pipManager.enterPip();
    }
  }

  /// listener for pip changes
  void _onPipModeChanged(bool isInPipMode) {
    // if the pip mode was closed and before enter to pip mode the player was not in fullscreen
    if (!isInPipMode && _pipContextToFullscreen != null) {
      Navigator.pop(_pipContextToFullscreen); // close the fullscreen
      _pipContextToFullscreen = null;
    }
  }

  static MeeduPlayerController of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<MeeduPlayerProvider>()
        .controller;
  }
}
