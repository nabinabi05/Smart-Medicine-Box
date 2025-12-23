class FirestorePaths {
  // Root collections
  static const devices = 'devices';
  static const users = 'users';
  static const doseHistory = 'doseHistory';

  // Subcollections
  static const liveData = 'liveData';
  static const config = 'config';
  static const schedules = 'schedules';

  // Builders
  static String device(String deviceId) => '$devices/$deviceId';
  static String deviceLive(String deviceId) => '${device(deviceId)}/$liveData';
  static String deviceLiveSensor(String deviceId, String sensorId) =>
      '${deviceLive(deviceId)}/$sensorId';
  static String deviceConfig(String deviceId) => '${device(deviceId)}/$config';
  static String deviceConfigSensor(String deviceId, String sensorId) =>
      '${deviceConfig(deviceId)}/$sensorId';

  static String user(String userId) => '$users/$userId';
  static String userSchedules(String userId) => '${user(userId)}/$schedules';
  static String userSchedule(String userId, String scheduleId) =>
      '${userSchedules(userId)}/$scheduleId';
  static String historyDoc(String historyId) => '$doseHistory/$historyId';
}
