import '../../location/services/location_tracking_service.dart';
import '../../location/services/locations_service.dart';
import '../services/device_command_service.dart';
import '../services/device_service.dart';

class DeviceCommandProcessor {
  final DeviceCommandService _commandService;
  final DeviceService _deviceService;
  final LocationsService _locationService;
  final LocationTrackingService _trackingService;

  DeviceCommandProcessor({
    DeviceCommandService? commandService,
    DeviceService? deviceService,
    LocationsService? locationService,
    LocationTrackingService? trackingService,
  }) : _commandService = commandService ?? DeviceCommandService(),
       _deviceService = deviceService ?? DeviceService(),
       _locationService = locationService ?? LocationsService(),
       _trackingService = trackingService ?? LocationTrackingService();

  Future<void> process({required int deviceId}) async {
    final commands = await _commandService.getPendingCommands(
      deviceId: deviceId,
    );

    for (final command in commands) {
      final commandId = int.parse(command['id'].toString());

      final commandName = command['command'].toString();

      try {
        await _executeCommand(deviceId: deviceId, command: commandName);

        await _commandService.acknowledgeCommand(
          deviceId: deviceId,
          commandId: commandId,
          status: 'executed',
        );
      } catch (e) {
        await _commandService.acknowledgeCommand(
          deviceId: deviceId,
          commandId: commandId,
          status: 'failed',
          errorMessage: e.toString(),
        );
      }
    }
  }

  Future<void> _executeCommand({
    required int deviceId,
    required String command,
  }) async {
    switch (command) {
      case 'request_location':
        final location = await _locationService.getCurrentLocation();

        await _deviceService.sendLocation(
          deviceId: deviceId,
          location: location,
        );

        break;

      case 'enable_lost_mode':
        await _trackingService.start(deviceId: deviceId);

        break;

      case 'disable_lost_mode':
        await _trackingService.stop();

        break;

      case 'start_tracking':
        await _trackingService.start(deviceId: deviceId);

        break;

      case 'stop_tracking':
        await _trackingService.stop();

        break;

      default:
        throw Exception('Unknown command: $command');
    }
  }
}
