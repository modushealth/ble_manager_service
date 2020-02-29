import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue/flutter_blue.dart';
import './utilities/crc.dart';
import './classes/stepwatch_exception.dart';
import './classes/command.dart';
import './classes/stepwatch.dart';

const SERVICE_UUID = '2456E1B9-26E2-8F83-E744-F34F01E9D701';
const FIFO_UUID = '2456E1B9-26E2-8F83-E744-F34F01E9D703';

const maxCommandLength = 20;

class ProgramVariableBlock {
  static const calibration = 0;
  static const participantInfo = 1;
  static const projectSecretKey = 2;
}

class RunMode {
  static const countdown = 1;
  static const deviceCal = 2;
  static const idle = 3;
  static const pause = 4;
  static const run = 5;
  static const sensorCal = 6;
  static const shutdown = 7;
}

class BLEManager {
  final Guid _serviceUuid = new Guid('{$SERVICE_UUID}');
  final Guid _characteristicUuid = Guid('{$FIFO_UUID}');

  bool get isConnected {
    return _device != null;
  }

  CommandSequence _sequence;

  bool _connecting = false;
  BluetoothDevice _device;
  BluetoothService _service;
  BluetoothCharacteristic _characteristic;
  StreamSubscription<List<int>> _valueStream;
  bool _hasInitialNotificationRun = false;

  Future connect(BluetoothDevice device) async {
    _device = device;
    _connecting = true;
    // TODO Add timer to cancel connection
    try {
      print('Connect to device: ${device.name}');
      // await _device.disconnect();
      if (_connecting) {
        await _device.connect();
      } else {
        return false;
      }
      print('after device connect');

      if (_connecting) {
        _service = await _getService();
      } else {
        return false;
      }
      print('after get service');

      if (_connecting) {
        _characteristic = await _getCharacteristic();
      } else {
        return false;
      }
      print('after get characteristic');

      if (_connecting) {
        await _listenForNotifications();
      } else {
        return false;
      }
      print('after listen for notifications');
      return true;
    } on TimeoutException catch (e) {
      print('Bluetooth timed out: $e');
      return e;
    } on Exception catch (e) {
      print('Unknown exception: $e');
      return e;
    } catch (e) {
      print('Something really unknown: $e');
      // return generic exception
      return Exception('A different error');
    }
  }

  void disconnect() async {
    _connecting = false;
    if (_sequence != null) {
      _sequence.clearCommandQueue();
    }
    _sequence = null;
    if (_valueStream != null) {
      await _valueStream.cancel();
    }
    if (_characteristic != null) {
      await _characteristic.setNotifyValue(false); // Do we need like in android?
    }
    await FlutterBlue.instance.stopScan();
    await _device.disconnect();
    _device = null;
  }

  void runNextCommand() {
    List<int> value = _sequence.getNextCommandValue();
    int parts = (value.length / maxCommandLength).ceil();
    print('Command parts: $parts');
    for (int i = 0; i < parts; i++) {
      int location = i * maxCommandLength;
      List<int> subValue;
      if (location + maxCommandLength <= value.length) {
        subValue = value.sublist(location, location + maxCommandLength);
      } else {
        subValue = value.sublist(location);
      }
      _characteristic.write(subValue, withoutResponse: true);
    }
  }

  /// Gets device service
  Future<BluetoothService> _getService() async {
    List<BluetoothService> services = await _device.discoverServices();
    // services.firstWhere((s) => s.uuid == _serviceUuid); // singleWhere?
    services = services.where((s) => s.uuid == _serviceUuid).toList();
    if (services.length == 0) {
      throw new Exception('Service with UUID $_serviceUuid not found');
    }
    return services.first;
  }

  /// Gets FIFO characteristic
  Future<BluetoothCharacteristic> _getCharacteristic() async {
    List<BluetoothCharacteristic> characteristics = _service.characteristics
        .where((c) => c.uuid == _characteristicUuid)
        .toList();
    if (characteristics.length == 0) {
      throw new Exception(
          'Characteristic with UUID $_characteristicUuid not found');
    }
    return characteristics.first;
  }

  /// Add stream subscription to characteristic notification
  Future _listenForNotifications() async {
    await _characteristic.setNotifyValue(true);

    _valueStream = _characteristic.value.listen((value) async {
      // print('_valueStream $value');
      if (!_hasInitialNotificationRun) {
        // Consume first characteristic value
        _hasInitialNotificationRun = true;
      } else {
        _handleCharacteristicValue(value);
      }
    });
  }

  // Send characteristic value to command sequence
  void _handleCharacteristicValue(List<int> value) {
    // Update current command with data
    // print('char value $value');
    bool complete = _sequence.updateCurrentCommand(value);
    // If command response is complete, run next command if it exists
    if (complete && _sequence.hasCommand) {
      runNextCommand();
    }
  }
}

class CommandSequence {
  BLEManager _manager;
  Function _sequenceCompleteCallback;
  List<Command> _commandQueue = [];

  StepWatch _stepWatch;
  List<int> _stepData = [];

  CommandSequence(manager) {
    this._manager = manager;
    _stepWatch = StepWatch(manager._device.name, manager._device.id);
  }

  Command get currentCommand {
    return _commandQueue[0];
  }

  bool get hasCommand {
    return _commandQueue.length > 0;
  }

  void addCommand(Command command) {
    command.sequence = this;
    _commandQueue.add(command);
  }

  void addCommands(List<Command> commands) {
    commands.forEach((command) => addCommand(command));
  }

  void commandComplete(Command command, [StepWatchException exception]) {
    // Remove completed command from queue
    _commandQueue.remove(command);

    // If command queue is empty, run callback
    if (_sequenceCompleteCallback != null) {
      if (exception != null) {
        _commandQueue.clear();
        _sequenceCompleteCallback(null, null, exception);
      } else if (!hasCommand) {
        var stepData = _stepData.length > 0 ? _stepData : null;
        _sequenceCompleteCallback(_stepWatch, stepData, null);
      }
    }
  }

  void clearCommandQueue() {
    if (hasCommand) {
      currentCommand.cancel();
    }
    _commandQueue.clear();
  }

  List<int> getNextCommandValue() {
    String commandString = '${currentCommand.start()}\r';
    List<int> bytes = List<int>.from(ascii.encode(commandString));
    String crcString = getCrc(bytes).toHex4();
    bytes.addAll(byteArrayFromHexString(crcString));
    return bytes;
  }

  bool updateCurrentCommand(List<int> value) {
    return currentCommand.update(value);
  }

  void runCommands([callback]) {
    _sequenceCompleteCallback = callback;
    _manager._sequence = this;
    _manager.runNextCommand();
  }
}

class Authenticate extends Command {
  Function _commandCompleteCallback;
  String _deviceName;
  Authenticate(this._deviceName, this._commandCompleteCallback)
      : super(r'^(.*)');

  @override
  String create() {
    String publicAccessCode = '74B8';
    String privateAccessCode = '513B';
    String deviceId = _deviceName.split('-')[1];
    String commandCrc = getHexStringCrc('$privateAccessCode$deviceId');
    return '#X $publicAccessCode$commandCrc';
  }

  @override
  void complete(Match match, StepWatchException exception) {
    if (match != null) {
      _commandCompleteCallback();
      sequence.commandComplete(this);
    } else {
      sequence.commandComplete(this, exception);
    }
  }

  @override
  String toString() {
    return 'Authenticate';
  }
}

class Snapshot extends Command {
  Function _commandCompleteCallback;
  Snapshot([this._commandCompleteCallback])
      : super(r'^(.{8}),(.{8}),(.{2}),(.{8}),(.{8})');

  @override
  String create() {
    return '#Z';
  }

  @override
  void complete(Match match, StepWatchException exception) {
    if (match != null) {
      // Create SnapshotData object
      var values = match
          .groups([1, 2, 3, 4, 5])
          .map((v) => int.parse(v, radix: 16))
          .toList();
      var snapshot = SnapshotData(
        values[0],
        values[1],
        values[2],
        values[3],
        values[4],
      );
      sequence._stepWatch.snapshot = snapshot;

      if (snapshot.mode == 0) {
        // StepWatch is on the charger
        var stepwatchException = StepWatchException(StepWatchException.p007);
        sequence.commandComplete(this, stepwatchException);
      } else {
        // Snapshot only has callback when step data will be read
        if (_commandCompleteCallback != null) {
          _commandCompleteCallback(snapshot);
        }
        sequence.commandComplete(this);
      }
    } else {
      sequence.commandComplete(this, exception);
    }
  }

  @override
  String toString() {
    return 'Snapshot';
  }
}

class DeviceInfo extends Command {
  DeviceInfo() : super(r'^(.{8}) (.{8}) (.{4}) (.{2}) (.{2})');

  @override
  String create() {
    return '#I 0';
  }

  @override
  void complete(Match match, StepWatchException exception) {
    if (match != null) {
      // Create DeviceInfoData object
      var values = match
          .groups([1, 2, 3, 4, 5])
          .map((v) => int.parse(v, radix: 16))
          .toList();
      var deviceInfo = DeviceInfoData(
        values[0],
        values[1],
        values[2],
        values[3],
        values[4],
      );
      sequence._stepWatch.deviceInfo = deviceInfo;
      sequence.commandComplete(this);
    } else {
      sequence.commandComplete(this, exception);
    }
  }

  @override
  String toString() {
    return 'DeviceInfo';
  }
}

class Configuration extends Command {
  Configuration()
      : super(
            r'^(.{8}) (.{4}) (.{4}) (.{1}) (.{2}) (.{8}) (.{2}) (.{2}) (.{2}) (.{1})');

  @override
  String create() {
    return '#C 0';
  }

  @override
  void complete(Match match, StepWatchException exception) {
    if (match != null) {
      // Create ConfigurationData object
      var values = match
          .groups([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
          .map((v) => int.parse(v, radix: 16))
          .toList();
      var configuration = ConfigurationData(
        values[0],
        values[1],
        values[2],
        values[3],
        values[4],
        values[5],
        values[6],
        values[7],
        values[8],
        values[9],
      );
      sequence._stepWatch.configuration = configuration;
      sequence.commandComplete(this);
    } else {
      sequence.commandComplete(this, exception);
    }
  }

  @override
  String toString() {
    return 'Configuration';
  }
}

class Battery extends Command {
  Battery() : super(r'^(.*)');

  @override
  String create() {
    return '#V';
  }

  @override
  void complete(Match match, StepWatchException exception) {
    if (match != null) {
      sequence._stepWatch.battery = int.parse(match.group(1), radix: 16);
      sequence.commandComplete(this);
    } else {
      sequence.commandComplete(this, exception);
    }
  }

  @override
  String toString() {
    return 'Battery';
  }
}

class ReadProgramVariable extends Command {
  final int block;
  // ReadProgramVariable(this.block) : super(r'^(.*)');
  ReadProgramVariable(this.block)
      : super(block == 0 ? r'^(.{4}) (.{2})' : r'^(.*)');

  @override
  String create() {
    return '#U 0 $block';
  }

  @override
  void complete(Match match, StepWatchException exception) {
    // TODO Handle empty stepwatch with no participant info
    if (exception != null) {
      sequence.commandComplete(this, exception);
    }
    if (match != null) {
      var value = match.group(0);
      var missingDataConditions = [
        value == '',
        (block == ProgramVariableBlock.participantInfo &&
            !value.startsWith('SW4')),
        (block == ProgramVariableBlock.participantInfo &&
            value.split(' ').length < 6),
      ];
      if (missingDataConditions.contains(true)) {
        var stepWatchException = StepWatchException(StepWatchException.p005, CommandCode.commandMissingData);
        sequence.commandComplete(this, stepWatchException);
      } else {
        if (block == ProgramVariableBlock.calibration) {
          // TODO Figure out calibration block issue
          var values = value.split(' ');
          sequence._stepWatch.calibration = CalibrationData(
            int.parse(values[0], radix: 16),
            int.parse(values[1], radix: 16),
          );
        } else if (block == ProgramVariableBlock.participantInfo) {
          var values = value.split(' ');
          sequence._stepWatch.participantInfo = ParticipantInfoData(
            values[0],
            values[1],
            values[2],
            values[3],
            values[4],
            values[5],
          );
        } else if (block == ProgramVariableBlock.projectSecretKey) {
          sequence._stepWatch.projectSecretKey = value;
        }
        sequence.commandComplete(this);
      }
    } else {
      // No data
      sequence.commandComplete(this);
    }
  }

  @override
  String toString() {
    return 'ReadProgramVariable $block';
  }
}

class WriteProgramVariable extends Command {
  final int block;
  final String value;

  WriteProgramVariable(this.block, this.value) : super(r'^(.*)');

  @override
  String create() {
    return '#U1 $block $value';
  }

  @override
  void complete(Match match, StepWatchException exception) {
    if (match != null) {
      sequence.commandComplete(this);
    } else {
      sequence.commandComplete(null, exception);
    }
  }

  @override
  String toString() {
    return 'WriteProgramVariable $block';
  }
}

class SetMode extends Command {
  final int mode;
  final int option;
  final bool setStartTime;

  SetMode(this.mode, [this.option, this.setStartTime = false])
      : super(r'^(.*)');

  @override
  String create() {
    String command = '#G $mode';
    if (option != null) {
      if (setStartTime) {
        int time = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        command += ' $option ${time.toRadixString(16).toUpperCase()}';
        print('#G command ${time.toRadixString(16)} --- $command');
      } else {
        command += ' $option';
      }
    }

    return command;
  }

  @override
  void complete(Match match, StepWatchException exception) {
    if (match != null) {
      sequence.commandComplete(this);
    } else {
      sequence.commandComplete(null, exception);
    }
  }

  @override
  String toString() {
    return 'SetMode';
  }
}

class WriteConfiguration extends Command {
  final ConfigurationData data;

  WriteConfiguration(this.data) : super(r'^(.*)');

  @override
  String create() {
    var parts = [
      data.startDelaySecs.toHex8(),
      data.timerSlowOneDelaySecs.toHex4(),
      data.timerSlowTwoDelaySecs.toHex4(),
      data.dataStorageMode.toHex(),
      data.binModeIntervalSecs.toHex2(),
      data.binModeIntervalLimit.toHex8(),
      data.numStartLedFlashes.toHex2(),
      data.cadence.toHex2(),
      data.sensitivity.toHex2(),
      data.blinkOnStart.toHex(),
    ];
    return '#C1 ${parts.join(' ')}';
  }

  @override
  void complete(Match match, StepWatchException exception) {
    sequence.commandComplete(this, exception);
  }

  @override
  String toString() {
    return 'WriteConfiguration';
  }
}
