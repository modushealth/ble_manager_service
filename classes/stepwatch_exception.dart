class CommandCode {
  static const bleStatusSuccess = 0;
  static const bleStatusRxedCmdPacket = 1;
  static const bleStatusRxedDlPacket = 2;
  static const bleStatusFail = 3;
  static const bleStatusRadioConfigFail = 4;
  static const bleStatusInvalidCmd = 5;
  static const bleStatusWrongNumArgs = 6;
  static const bleStatusInvalidAddr = 7;
  static const bleStatusInvalidLength = 8;
  static const bleStatusInvalidArgs = 9;
  static const bleStatusInvalidCrc = 10;
  static const bleStatusInvalidMode = 11;
  static const bleStatusNotAuthenticated = 12;
  static const commandCrcInvalid = 13;
  static const commandRegexInvalid = 14;
  static const commandMissingData = 15;
  static const commandTimeout = 16;

  final int commandCode;

  CommandCode(this.commandCode);

  String get message {
    return {
      0: 'Success',
      1: 'Successfully received command packet',
      2: 'Successfully received downlink packet',
      3: 'Generic failure',
      4: 'Failure to configure the radio',
      5: 'Command not valid (not allowed in current operating mode)',
      6: 'Command had wrong number of arguments',
      7: 'Returned if the memory offset specified in the command refers to an invalid address',
      8: 'Returned if the length of data requested to read from memory causes us to attempt to read an invalid memory location',
      9: 'Returned if the arguments are outside the allowable range',
      10: 'Received packet CRC failed',
      11: 'Command is not allowed while the device is in the current mode',
      12: 'Attempt to access restricted command. Authentication is required.',
      13: 'Command CRC does not match CRC calculated from response data',
      14: 'Command response does not match regex pattern',
      15: 'Command response data is missing required data',
      16: 'Command timeout after 30 seconds',
    }[commandCode];
  }

  @override
  String toString() {
    return message;
  }
}

class StepWatchException {
  static const p001 = 0;
  static const p002 = 1;
  static const p003 = 2;
  static const p004 = 3;
  static const p005 = 4;
  static const p006 = 5;
  static const p007 = 6;
  static const p008 = 7;
  static const p009 = 8;

  final int code;
  final int commandCode;

  StepWatchException(this.code, [this.commandCode]);

  String get displayCode {
    return {
      0: 'P001',
      1: 'P002',
      2: 'P003',
      3: 'P004',
      4: 'P005',
      5: 'P006',
      6: 'P007',
      7: 'P008',
      8: 'P009',
    }[code];
  }
  String get message {
    return {
      0: 'QR Scan Failed',
      1: 'Device Not Found',
      2: 'Cloud Error',
      3: 'Cloud Outage',
      4: 'Bluetooth Error',
      5: 'Bluetooth Loss',
      6: 'Charge Mode Error',
      7: 'Step Data Corrupted',
      8: 'Patient ID Mismatch',
    }[code];
  }

  @override
  String toString() {
    String string = 'StepWatchException $displayCode: $message';
    if (commandCode != null) {
      string += '\r\n\t${CommandCode(commandCode).message}';
    }
    return string;
  }
}
