import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

const _serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
const _charUuid    = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
const _piName      = 'NaGaJa-Pi';

enum BleState { idle, scanning, connecting, connected, failed }

class BleService extends ChangeNotifier {
  BleService._();
  static final instance = BleService._();

  BleState _state = BleState.idle;
  BluetoothDevice? _device;
  String? _deviceName;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  BleState get state => _state;
  String? get deviceName => _deviceName;
  bool get isConnected => _state == BleState.connected;

  Future<bool> _requestPermissions() async {
    if (!Platform.isAndroid) return true;
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    return statuses.values.every((s) => s.isGranted);
  }

  Future<void> scanAndConnect() async {
    if (_state == BleState.scanning || _state == BleState.connecting) return;

    final granted = await _requestPermissions();
    if (!granted) {
      _setState(BleState.failed);
      return;
    }

    _setState(BleState.scanning);

    try {
      BluetoothDevice? found;

      final sub = FlutterBluePlus.onScanResults.listen((results) {
        for (final r in results) {
          if (r.device.platformName == _piName && found == null) {
            found = r.device;
            FlutterBluePlus.stopScan();
          }
        }
      });

      await FlutterBluePlus.startScan(
        withServices: [Guid(_serviceUuid)],
        timeout: const Duration(seconds: 10),
      );
      await FlutterBluePlus.isScanning.where((s) => !s).first;
      await sub.cancel();

      if (found == null) {
        _setState(BleState.failed);
        return;
      }

      _setState(BleState.connecting);
      _device = found;
      await _device!.connect(timeout: const Duration(seconds: 10));

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) await _writeUserId(_device!, uid);

      _deviceName = _device!.platformName;
      _setState(BleState.connected);

      _connSub = _device!.connectionState.listen((cs) {
        if (cs == BluetoothConnectionState.disconnected) {
          _deviceName = null;
          _device = null;
          _setState(BleState.idle);
        }
      });
    } catch (e) {
      debugPrint('[BleService] error: $e');
      _device = null;
      _setState(BleState.failed);
    }
  }

  Future<void> _writeUserId(BluetoothDevice device, String userId) async {
    final services = await device.discoverServices();
    for (final svc in services) {
      if (svc.serviceUuid == Guid(_serviceUuid)) {
        for (final char in svc.characteristics) {
          if (char.characteristicUuid == Guid(_charUuid)) {
            await char.write(utf8.encode(userId));
            debugPrint('[BleService] userId 전송 완료: $userId');
            return;
          }
        }
      }
    }
    debugPrint('[BleService] 특성을 찾지 못했습니다');
  }

  Future<void> disconnect() async {
    await _connSub?.cancel();
    _connSub = null;
    await _device?.disconnect();
    _device = null;
    _deviceName = null;
    _setState(BleState.idle);
  }

  void _setState(BleState s) {
    _state = s;
    notifyListeners();
  }
}
