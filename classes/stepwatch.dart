class DeviceData {
  String name;
  String id;

  DeviceData(this.name, this.id);

  @override
  String toString() {
    return '$name, $id';
  }
}

class SnapshotData {
  final int totalStepCount;
  final int totalSecCount;
  final int mode;
  final int totalStepDataBytes;
  final int startTimestamp;

  SnapshotData(
    this.totalStepCount,
    this.totalSecCount,
    this.mode,
    this.totalStepDataBytes,
    this.startTimestamp,
  );

  @override
  String toString() {
    return [
      totalStepCount,
      totalSecCount,
      mode,
      totalStepDataBytes,
      startTimestamp
    ].join(', ');
  }
}

class DeviceInfoData {
  final int serialNumber;
  final int firmwareVersion;
  final int sensorEx;
  final int deviceType;
  final int hardwareRev;

  DeviceInfoData(
    this.serialNumber,
    this.firmwareVersion,
    this.sensorEx,
    this.deviceType,
    this.hardwareRev,
  );

  @override
  String toString() {
    return [
      serialNumber,
      firmwareVersion,
      sensorEx,
      deviceType,
      hardwareRev,
    ].join(', ');
  }
}

class ConfigurationData {
  final int startDelaySecs;
  final int timerSlowOneDelaySecs;
  final int timerSlowTwoDelaySecs;
  final int dataStorageMode;
  final int binModeIntervalSecs;
  final int binModeIntervalLimit;
  int numStartLedFlashes;
  int cadence;
  int sensitivity;
  final int blinkOnStart;

  ConfigurationData(
    this.startDelaySecs,
    this.timerSlowOneDelaySecs,
    this.timerSlowTwoDelaySecs,
    this.dataStorageMode,
    this.binModeIntervalSecs,
    this.binModeIntervalLimit,
    this.numStartLedFlashes,
    this.cadence,
    this.sensitivity,
    this.blinkOnStart,
  );

  @override
  String toString() {
    return [
      startDelaySecs,
      timerSlowOneDelaySecs,
      timerSlowTwoDelaySecs,
      dataStorageMode,
      binModeIntervalSecs,
      binModeIntervalLimit,
      numStartLedFlashes,
      cadence,
      sensitivity,
      blinkOnStart,
    ].join(', ');
  }
}

class CalibrationData {
  final int value;
  final int year;

  CalibrationData(this.value, this.year);

  @override
  String toString() {
    return [
      this.value,
      this.year,
    ].join(' ');
  }
}

class ParticipantInfoData {
  final String stepwatchId;
  final String participantId;
  final String siteId;
  final String siteSlug;
  final String devicePairTid;
  final String randomCodeForQRScreen;

  ParticipantInfoData(
    this.stepwatchId,
    this.participantId,
    this.siteId,
    this.siteSlug,
    this.devicePairTid,
    this.randomCodeForQRScreen,
  );

  @override
  String toString() {
    return [
      stepwatchId,
      participantId,
      siteId,
      siteSlug,
      devicePairTid,
      randomCodeForQRScreen,
    ].join(', ');
  }
}

class StepWatch {
  DeviceData device;
  int battery;
  String projectSecretKey;
  SnapshotData snapshot;
  DeviceInfoData deviceInfo;
  ConfigurationData configuration;
  CalibrationData calibration;
  ParticipantInfoData participantInfo;

  StepWatch(name, id) {
    device = DeviceData(name, id.toString());
  }

  @override
  String toString() {
    return '''StepWatch(
      Device: $device
      Battery: $battery,
      ProjectSecretKey: $projectSecretKey
      Snapshot: $snapshot
      DeviceInfo: $deviceInfo
      Configuration: $configuration
      Calibration: $calibration
      ParticipantInfo: $participantInfo
    )''';
  }
}
