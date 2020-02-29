import 'dart:async';
import 'dart:convert';
import 'package:convert/convert.dart';

import '../utilities/crc.dart';
import '../service.dart';
import './stepwatch_exception.dart';

const COMMAND_ERROR_STRING = '?';
const COMMAND_COMPLETE_STRING = '>';

abstract class Command {
  CommandSequence sequence;

  String _regex;
  String _commandText;
  List<int> _bytes = [];
  Timer _connectionTimer;

  Command(this._regex);

  // Is command complete character in bytes
  bool get _isCommandComplete {
    int index = _bytes.indexOf(ascii.encode(COMMAND_COMPLETE_STRING)[0]);
    return index != -1 && index == _bytes.length - 3;
  }

  // Do CRC bytes match data
  bool get _isCrcValid {
    var crcBytes = _bytes.getRange(_bytes.length - 2, _bytes.length).toList();
    String crc = hex.encode(crcBytes);
    var commandBytes = _bytes.getRange(0, _bytes.length - 2).toList();
    String calculatedCrc = getCrcString(commandBytes);
    if (crc != calculatedCrc) {
      print('$this CRC: $crc, calculated CRC: $calculatedCrc');
    }
    return crc == calculatedCrc;
  }

  // Required to create the command string sent to StepWatch
  String create();
  // Required to parse regex response and maybe run callback
  void complete(Match match, StepWatchException exception);

  String start() {
    // Use start function
    _connectionTimer =
        Timer.periodic(const Duration(seconds: 30), (Timer t) {
          completeCommand(null, _getException(CommandCode.commandTimeout));
        });
    _commandText = create();
    print('Next Command: $_commandText');
    return _commandText;
  }

  bool update(List<int> value) {
    _bytes.addAll(value);
    if (_isCommandComplete) {
      _handleCompleteResponse();
      return true;
    }
    print('$this: Continue receiving command ${_bytes.length}');
    return false;
  }

  void cancel() {
    _connectionTimer.cancel();
  }

  void completeCommand(Match match, StepWatchException exception) {
    _connectionTimer.cancel();
    complete(match, exception);
  }

  void _handleCompleteResponse() {
    // Check CRC
    if (!_isCrcValid) {
      print('CRC is invalid');
      completeCommand(null, _getException(CommandCode.commandCrcInvalid)); // CRC exception
    } else {
      // Check if error response
      final response = _parseResponse();
      if (response.startsWith('?')) {
        // Handle error response from StepWatch
        print('Error response from StepWatch $response');
        int code = int.parse(response.replaceFirst('?', ''), radix: 16);
        completeCommand(null, _getException(code));
      } else {
        // Get regex match from command response
        if (response == '') {
          completeCommand(null, null);
        } else {
          RegExp exp = new RegExp(_regex);
          Iterable<Match> matches = exp.allMatches(response);
          print('$this: Response $response');
          if (matches.length > 0) {
            completeCommand(matches.first, null);
          } else {
            // Throw malformed response error
            completeCommand(null, _getException(CommandCode.commandRegexInvalid));
          }
        }
      }
    }
  }

  String _parseResponse() {
    var response = ascii.decode(_bytes.getRange(0, _bytes.length - 5).toList());
    return response.substring(1, response.length - 1);
  }

  StepWatchException _getException(int commandCode) {
    switch (commandCode) {
      case CommandCode.bleStatusInvalidCrc:
        return StepWatchException(StepWatchException.p008, commandCode);
        break;
      case CommandCode.commandTimeout:
        return StepWatchException(StepWatchException.p006, commandCode);
        break;
      default:
        return StepWatchException(StepWatchException.p005, commandCode);
    }
  }
}
